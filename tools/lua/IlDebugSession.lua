-- Read-only MAME 0.281 paused IL debugger session.
--
-- Run control only: native breakpoints, cpu.debug:step(1), go and stop.  This
-- script never writes CPU registers, RAM, ROM, save states or the VM stack.
-- Requests and responses are strict key=value files; no request value is ever
-- executed as a debugger or Lua command.
--
-- Exact boundaries come from the native debugger.  A Lua periodic callback is
-- used only as the paused command/step driver; it is not an instruction
-- boundary.  The callback is also called every frame while running, so it
-- ignores all work unless manager.machine.debugger.execution_state == "stop".

local PROTOCOL = "il-debug-session-v1"
local MAX_REQUEST_BYTES = 4096
local MAX_STEPS_PER_NODE = 500
local MAX_SEQUENCE_GAP = 8

local m = manager.machine
local cpu = m.devices[":maincpu"]
local mem = cpu.spaces["program"]
local dbg = m.debugger

local function hex16(v) return string.format("%04X", v & 0xFFFF) end
local function hex8(v) return string.format("%08X", v & 0xFFFFFFFF) end
local function hex2(v) return string.format("%02X", v & 0xFF) end
local function readw(addr) return mem:read_u16(addr & 0xFFFF) end
local function readb(addr) return mem:read_u8(addr & 0xFFFF) end

local events = assert(io.open("events.jsonl", "a"))
events:setvbuf("no")

-- BEGIN-EVENT-JSON-SERIALIZER
-- Tests extract this block to exercise the real serializer without starting a
-- debugger session.  Every control byte U+0000..U+001F, quote and backslash is
-- escaped; no input byte is dropped.
local function jsonValue(v)
    if type(v) == "number" then return string.format("%.0f", math.floor(v)) end
    if type(v) == "boolean" then return v and "true" or "false" end
    local s = tostring(v)
    s = s:gsub('[%c\\"]', function(c)
        if c == '"' then return '\\"' end
        if c == "\\" then return "\\\\" end
        if c == "\b" then return "\\b" end
        if c == "\f" then return "\\f" end
        if c == "\n" then return "\\n" end
        if c == "\r" then return "\\r" end
        if c == "\t" then return "\\t" end
        return string.format("\\u%04x", c:byte())
    end)
    return '"' .. s .. '"'
end

local function logEvent(kind, fields)
    local parts = { '{"event":' .. jsonValue(kind) }
    if fields then
        local keys = {}
        for k, _ in pairs(fields) do keys[#keys + 1] = k end
        table.sort(keys)
        for _, k in ipairs(keys) do
            parts[#parts + 1] = "," .. jsonValue(k) .. ":" .. jsonValue(fields[k])
        end
    end
    parts[#parts + 1] = "}\n"
    events:write(table.concat(parts))
    events:flush()
end
-- END-EVENT-JSON-SERIALIZER

local function startupFailure(code, message)
    local f = io.open("ready.tmp", "w")
    if f then
        f:write("protocol=" .. PROTOCOL .. "\n")
        f:write("session=" .. tostring(os.getenv("FML_IL_DEBUG_SESSION_ID") or "") .. "\n")
        f:write("variant=" .. tostring(os.getenv("FML_IL_DEBUG_VARIANT") or "") .. "\n")
        f:write("map=fail\n")
        f:write("exec=" .. tostring(dbg and dbg.execution_state or "unavailable") .. "\n")
        f:write("lfs=unknown\n")
        f:write("error=" .. tostring(code) .. "\n")
        f:write("message=" .. tostring(message):gsub("[\r\n]", " ") .. "\n")
        f:close()
        os.rename("ready.tmp", "ready.txt")
    end
    logEvent("startup_failure", { code = code, message = message })
    pcall(function() m:exit() end)
    pcall(function() cpu.debug:go() end)
    error(code .. ": " .. tostring(message))
end

if not dbg then startupFailure("no_debugger", "manager.machine.debugger is nil; -debug is required") end
if not cpu.debug then startupFailure("no_cpu_debug", "maincpu debug interface is unavailable") end
if os.getenv("FML_IL_DEBUG_SESSION") ~= "1" then startupFailure("no_session_env", "FML_IL_DEBUG_SESSION is not 1") end
local envSession = os.getenv("FML_IL_DEBUG_SESSION_ID")
if not envSession then startupFailure("no_session_id", "FML_IL_DEBUG_SESSION_ID is missing") end

local okConfig, config = pcall(dofile, "session-config.lua")
if not okConfig or type(config) ~= "table" then startupFailure("config", "session-config.lua could not be loaded") end
if config.schemaVersion ~= 1 or config.protocol ~= PROTOCOL then startupFailure("config_schema", "session config schema/protocol mismatch") end
if config.sessionId ~= envSession then startupFailure("config_session", "session config and environment session differ") end
if config.cpuTag ~= ":maincpu" then startupFailure("config_cpu", "unsupported CPU tag") end
if type(config.secondsToRun) ~= "number" or config.secondsToRun < 1 or config.secondsToRun > 120 then startupFailure("config_seconds", "emulated seconds out of range") end
if type(config.wallTimeoutSeconds) ~= "number" or config.wallTimeoutSeconds < 30 or config.wallTimeoutSeconds > 600 then startupFailure("config_wall", "wall timeout out of range") end

local okMap, map = pcall(dofile, "session-map.lua")
if not okMap or type(map) ~= "table" then startupFailure("map", "session-map.lua could not be loaded") end
if map.schemaVersion ~= 1 or map.protocol ~= PROTOCOL then startupFailure("map_schema", "map schema/protocol mismatch") end
if map.variant ~= config.variant then startupFailure("map_variant", "map variant differs from session variant") end
if map.imageSha256 ~= config.expectedImageSha256 then startupFailure("map_image", "map image identity differs from session") end
if map.originalRomSha256 ~= config.expectedOriginalRomSha256 then startupFailure("map_original", "map original identity differs from session") end
if type(map.bodyStart) ~= "number" or type(map.bodyEndExclusive) ~= "number" or map.bodyEndExclusive <= map.bodyStart then startupFailure("map_body", "map body span is malformed") end
if type(map.nodes) ~= "table" or #map.nodes < 1 then startupFailure("map_nodes", "map does not contain nodes") end
if type(map.entries) ~= "table" or #map.entries ~= (map.bodyEndExclusive - map.bodyStart) then startupFailure("map_entries", "map entries do not cover the declared body span") end
if type(map.returnNodeIndex) ~= "number" or map.returnNodeIndex < 0 or map.returnNodeIndex >= #map.nodes then startupFailure("map_return", "return node index is out of range") end

local lastNodeIndex = #map.nodes - 1
local nodeByAddress = {}
local nodeByIndex = {}
for _, node in ipairs(map.nodes) do
    if type(node.index) ~= "number" or node.index < 0 or node.index > lastNodeIndex then startupFailure("map_node_index", "node index is out of range") end
    if type(node.address) ~= "number" or type(node.token) ~= "number" or type(node.handlerPc) ~= "number" then startupFailure("map_node", "node fields are malformed") end
    if type(node.bytes) ~= "table" or #node.bytes < 2 then startupFailure("map_node_bytes", "node bytes are missing") end
    if nodeByIndex[node.index] then startupFailure("map_node_duplicate", "duplicate node index") end
    if nodeByAddress[node.address] then startupFailure("map_node_address", "duplicate node address") end
    nodeByIndex[node.index] = node
    nodeByAddress[node.address] = node
end
for i = 0, lastNodeIndex do
    if not nodeByIndex[i] then startupFailure("map_node_missing", "missing node index " .. tostring(i)) end
end
if nodeByIndex[0].address ~= map.bodyStart then startupFailure("map_start", "first node is not the body start") end

local expectedAddress = map.bodyStart
local lastNode = -1
for index, entry in ipairs(map.entries) do
    if type(entry.address) ~= "number" or entry.address ~= expectedAddress then startupFailure("map_contiguous", "map entry is not contiguous at index " .. tostring(index)) end
    if type(entry.nodeIndex) ~= "number" or entry.nodeIndex < lastNode then startupFailure("map_order", "map node order is ambiguous") end
    if entry.nodeIndex > lastNode then
        if entry.nodeIndex ~= lastNode + 1 then startupFailure("map_gap", "map node index gap") end
        lastNode = entry.nodeIndex
    end
    local live = readb(entry.address)
    if live ~= entry.imageByte then startupFailure("map_live_byte", string.format("live byte %02X differs from map byte %02X at %04X", live, entry.imageByte, entry.address)) end
    expectedAddress = expectedAddress + 1
end
if expectedAddress ~= map.bodyEndExclusive then startupFailure("map_body_end", "map does not cover the declared body end") end
if lastNode ~= lastNodeIndex then startupFailure("map_last_node", "map does not end at the last node") end

local branchByIndex = {}
for _, node in ipairs(map.nodes) do
    local liveToken = readw(node.address)
    if liveToken ~= node.token then startupFailure("map_token", string.format("live token %04X differs from map token %04X at %04X", liveToken, node.token, node.address)) end
    for offset, byte in ipairs(node.bytes or {}) do
        local live = readb(node.address + offset - 1)
        if live ~= byte then startupFailure("map_node_byte", string.format("live node byte %02X differs from map byte %02X at %04X", live, byte, node.address + offset - 1)) end
    end
    if node.branch ~= nil then
        local branch = node.branch
        if type(branch.operandAddress) ~= "number" or type(branch.operandByte) ~= "number" or type(branch.targetAddress) ~= "number" then startupFailure("map_branch", "branch fields are malformed") end
        if branch.tokenAddress ~= node.address then startupFailure("map_branch_token_address", "branch tokenAddress is not the node address") end
        if branch.operandAddress ~= ((node.address + 2) & 0xFFFF) then startupFailure("map_branch_operand", "branch operand does not follow the token") end
        if #node.bytes ~= 3 then startupFailure("map_branch_width", "branch node does not have a one-byte operand") end
        local liveOperand = readb(branch.operandAddress)
        if liveOperand ~= branch.operandByte then startupFailure("map_branch_byte", string.format("live branch operand %02X differs from map byte %02X at %04X", liveOperand, branch.operandByte, branch.operandAddress)) end
        if ((branch.operandAddress + branch.operandByte) & 0xFFFF) ~= branch.targetAddress then startupFailure("map_branch_target", "branch target arithmetic does not hold") end
        if not nodeByAddress[branch.targetAddress] then startupFailure("map_branch_boundary", "branch target is not a node boundary") end
        if branch.condition ~= "IfZero" and branch.condition ~= "Always" then startupFailure("map_branch_condition", "branch condition is unsupported") end
        if branch.condition == "IfZero" and not nodeByIndex[node.index + 1] then startupFailure("map_branch_fallthrough", "conditional branch has no fall-through node") end
        if branch.handlerAddress ~= ((node.token + 2) & 0xFFFF) then startupFailure("map_branch_handler", "branch handler address is not the token code field") end
        if node.handlerPc ~= branch.handlerAddress then startupFailure("map_branch_handler_pc", "branch handler PC differs from the token code field") end
        branchByIndex[node.index] = branch
    end
end

local callerByIndex = {}
local callerByAddress = {}
local function validateCaller(caller, expectedIndex)
    if type(caller) ~= "table" then startupFailure("map_caller", "caller record is malformed") end
    for _, name in ipairs({ "index", "callerTokenAddress", "callerToken", "calleeHeaderAddress", "headerValue",
        "calleeBodyStart", "calleeBodyEndExclusive", "callerSuccessor", "postReturnToken" }) do
        if type(caller[name]) ~= "number" then startupFailure("map_caller", "caller field is missing or not numeric: " .. name) end
    end
    if caller.index ~= expectedIndex then startupFailure("map_caller_index", "caller index is not the expected explicit position") end
    if caller.headerValue ~= 0x00F8 then startupFailure("map_caller_header", "caller header value is not 00F8") end
    if caller.calleeHeaderAddress + 2 ~= caller.calleeBodyStart then startupFailure("map_caller_body", "callee header+2 is not the body start") end
    if caller.callerTokenAddress + 2 ~= caller.callerSuccessor then startupFailure("map_caller_successor", "caller token+2 is not the successor") end
    if caller.calleeBodyStart ~= map.bodyStart or caller.calleeBodyEndExclusive ~= map.bodyEndExclusive then
        startupFailure("map_caller_span", "caller callee span differs from the mapped body")
    end
    if readw(caller.callerTokenAddress) ~= caller.callerToken then startupFailure("map_caller_token", "live caller token differs from the caller record") end
    if readw(caller.calleeHeaderAddress) ~= caller.headerValue then startupFailure("map_caller_header_live", "live callee header differs from the caller record") end
    if readw(caller.callerSuccessor) ~= caller.postReturnToken then startupFailure("map_caller_continuation", "live caller successor token differs from the caller record") end
    if readw(caller.calleeBodyStart) ~= nodeByIndex[0].token then startupFailure("map_caller_body_token", "live callee first token differs from the mapped first node") end
    if callerByIndex[caller.index] then startupFailure("map_caller_duplicate", "duplicate caller index") end
    if callerByAddress[caller.callerTokenAddress] then startupFailure("map_caller_address", "duplicate caller token address") end
    callerByIndex[caller.index] = caller
    callerByAddress[caller.callerTokenAddress] = caller
end
if type(map.callers) ~= "table" or #map.callers < 1 then startupFailure("map_callers", "map does not contain explicit caller records") end
for index, caller in ipairs(map.callers) do validateCaller(caller, index - 1) end

local okLfs, lfs = pcall(require, "lfs")
if not okLfs then startupFailure("no_lfs", "lfs directory enumeration is unavailable") end
local okDir, dirIter, dirObject = pcall(lfs.dir, "commands")
if not okDir then startupFailure("no_commands_dir", "commands directory is unavailable") end
pcall(function() for _ in dirIter, dirObject do end end)

local session = {
    phase = "starting",
    current = nil,
    pause = nil,
    step = nil,
    lastSeq = 0,
    lastRequestId = nil,
    postReturnContext = nil,
    inspectionCount = 0,
    startWall = os.time(),
    timeout = false,
    stopping = false,
    readyWritten = false,
    initialBreakpoint = nil,
    resetPc = readw(0xFFFE)
}

local function snapshot()
    return {
        pc = cpu.state["PC"].value,
        curpc = cpu.state["CURPC"].value,
        x = cpu.state["X"].value,
        y = cpu.state["Y"].value,
        u = cpu.state["U"].value,
        s = cpu.state["S"].value,
        time = m.time:as_double(),
        exec = dbg.execution_state
    }
end

local function words(addr, count)
    local out = {}
    for i = 0, count - 1 do out[i] = readw(addr + i * 2) end
    return out
end

local function stateFields(state, prefix, target)
    local p = prefix or ""
    target[#target + 1] = p .. "pc=" .. hex16(state.pc)
    target[#target + 1] = p .. "curpc=" .. hex16(state.curpc)
    target[#target + 1] = p .. "x=" .. hex16(state.x)
    target[#target + 1] = p .. "y=" .. hex16(state.y)
    target[#target + 1] = p .. "u=" .. hex16(state.u)
    target[#target + 1] = p .. "s=" .. hex16(state.s)
    target[#target + 1] = p .. "emulatedTime=" .. string.format("%.9f", state.time)
    target[#target + 1] = p .. "execState=" .. tostring(state.exec)
    local d = words(state.u, 4)
    local c = words(state.s, 2)
    for i = 0, 3 do target[#target + 1] = p .. "dataStack" .. tostring(i) .. "=" .. hex16(d[i]) end
    for i = 0, 1 do target[#target + 1] = p .. "controlStack" .. tostring(i) .. "=" .. hex16(c[i]) end
end

local function resolveBoundary(state)
    if state.pc == 0x00FC then
        local caller = callerByAddress[state.y]
        if caller then
            local token = readw(state.y)
            if token ~= caller.callerToken then return nil, "caller_token_mismatch" end
            if readw(caller.callerSuccessor) ~= caller.postReturnToken then return nil, "caller_successor_mismatch" end
            return { phase = "caller-prefetch", caller = caller, token = token }
        end
        local node = nodeByAddress[state.y]
        if node then
            local token = readw(state.y)
            if token ~= node.token then return nil, "token_mismatch" end
            return { phase = "prefetch", node = node, token = token }
        end
        if session.postReturnContext and state.y == session.postReturnContext.savedCursor then
            if state.s == ((session.postReturnContext.returnS + 2) & 0xFFFF) then
                return {
                    phase = "post-return",
                    node = nodeByIndex[map.returnNodeIndex],
                    token = readw(state.y),
                    savedCursor = session.postReturnContext.savedCursor,
                    returnS = session.postReturnContext.returnS
                }
            end
        end
        return nil, "unsupported_prefetch"
    end
    for _, node in ipairs(map.nodes) do
        if state.y == ((node.address + 2) & 0xFFFF) and state.pc == node.handlerPc then
            local token = readw(node.address)
            if token ~= node.token then return nil, "token_mismatch" end
            local expectedX = (token + 2) & 0xFFFF
            if state.x ~= expectedX then return nil, "handler_x_mismatch" end
            local boundary = { node = node, token = token, uAtHandler = state.u }
            if node.index == map.returnNodeIndex then
                boundary.phase = "return-handler"
                boundary.savedCursor = readw(state.s)
                boundary.returnS = state.s
            else
                boundary.phase = "handler"
            end
            local branch = branchByIndex[node.index]
            if branch then
                boundary.branch = branch
                if branch.condition == "IfZero" then
                    boundary.conditionCell = readw(state.u)
                    boundary.branchPath = boundary.conditionCell == 0 and "zero" or "nonzero"
                else
                    boundary.branchPath = "always"
                end
            end
            return boundary
        end
    end
    return nil, "unsupported_location"
end

local function callerFields(caller, target)
    target[#target + 1] = "callerIndex=" .. tostring(caller.index)
    target[#target + 1] = "callerTokenAddress=" .. hex16(caller.callerTokenAddress)
    target[#target + 1] = "callerToken=" .. hex16(caller.callerToken)
    target[#target + 1] = "calleeHeaderAddress=" .. hex16(caller.calleeHeaderAddress)
    target[#target + 1] = "calleeHeaderValue=" .. hex16(caller.headerValue)
    target[#target + 1] = "calleeBodyStart=" .. hex16(caller.calleeBodyStart)
    target[#target + 1] = "calleeBodyEndExclusive=" .. hex16(caller.calleeBodyEndExclusive)
    target[#target + 1] = "callerSuccessor=" .. hex16(caller.callerSuccessor)
    target[#target + 1] = "postReturnToken=" .. hex16(caller.postReturnToken)
    target[#target + 1] = "calleeNodeIndex=0"
    target[#target + 1] = "calleeFirstToken=" .. hex16(nodeByIndex[0].token)
end

local function boundaryFields(boundary, target)
    if not boundary then return end
    if boundary.phase == "caller-prefetch" then
        target[#target + 1] = "boundaryPhase=caller-prefetch"
        callerFields(boundary.caller, target)
        return
    end
    local node = boundary.node
    target[#target + 1] = "boundaryPhase=" .. boundary.phase
    target[#target + 1] = "nodeIndex=" .. tostring(node.index)
    target[#target + 1] = "nodeAddress=" .. hex16(node.address)
    target[#target + 1] = "token=" .. hex16(node.token)
    target[#target + 1] = "operation=" .. tostring(node.operation)
    target[#target + 1] = "handlerPc=" .. hex16(node.handlerPc)
    target[#target + 1] = "ilNode=" .. tostring(node.index)
    target[#target + 1] = "ilAddress=" .. hex16(node.address)
    target[#target + 1] = "ilToken=" .. hex16(node.token)
    target[#target + 1] = "ilOperation=" .. tostring(node.operation)
    local branch = branchByIndex[node.index]
    if branch then
        -- A branch operand is a one-byte stream operand, never a word literal.
        target[#target + 1] = "ilOperand="
        target[#target + 1] = "ilBranchTokenAddress=" .. hex16(branch.tokenAddress)
        target[#target + 1] = "ilBranchOperandAddress=" .. hex16(branch.operandAddress)
        target[#target + 1] = "ilBranchOperandByte=" .. hex2(branch.operandByte)
        target[#target + 1] = "ilBranchTargetAddress=" .. hex16(branch.targetAddress)
        target[#target + 1] = "ilBranchCondition=" .. tostring(branch.condition)
        if boundary.conditionCell then target[#target + 1] = "ilBranchConditionCell=" .. hex16(boundary.conditionCell) end
        if boundary.branchPath then target[#target + 1] = "ilBranchPath=" .. boundary.branchPath end
    elseif #(node.bytes or {}) == 4 then
        -- Only a four-byte node carries a two-byte word literal after the token.
        target[#target + 1] = "ilOperand=" .. hex16(readw(node.address + 2))
    else
        target[#target + 1] = "ilOperand="
    end
    if boundary.savedCursor then target[#target + 1] = "savedCursor=" .. hex16(boundary.savedCursor) end
    if boundary.returnS then target[#target + 1] = "returnS=" .. hex16(boundary.returnS) end
end

local function responsePath(seq)
    return string.format("responses/request-%06d.resp", seq)
end

local function writeResponse(req, status, kind, proof, fields)
    local target = responsePath(req.sequence)
    local probe = io.open(target, "r")
    if probe then
        probe:close()
        logEvent("response_collision", { sequence = req.sequence, requestId = req.requestId })
        local moved = os.rename(req.path, "commands/processed-collision-" .. string.format("%06d", req.sequence) .. ".req")
        if not moved then os.remove(req.path) end
        return false
    end
    local lines = {
        "protocol=" .. PROTOCOL,
        "session=" .. config.sessionId,
        "sequence=" .. string.format("%06d", req.sequence),
        "requestId=" .. req.requestId,
        "nonce=" .. req.nonce,
        "command=" .. req.command,
        "status=" .. status,
        "kind=" .. kind,
        "proof=" .. tostring(proof or ""),
        "acknowledged=" .. tostring(status == "ok" and "yes" or "no"),
        "phase=" .. session.phase
    }
    if fields then
        for _, line in ipairs(fields) do lines[#lines + 1] = line end
    end
    local tmp = string.format("responses/.tmp-%06d-%s", req.sequence, req.nonce)
    local f = io.open(tmp, "w")
    if not f then
        logEvent("response_open_failure", { sequence = req.sequence, requestId = req.requestId })
        return false
    end
    f:write(table.concat(lines, "\n") .. "\n")
    f:close()
    local renamed, renameError = os.rename(tmp, target)
    if not renamed then
        os.remove(tmp)
        logEvent("response_rename_failure", { line = tostring(renameError), sequence = req.sequence, requestId = req.requestId })
        return false
    end
    logEvent("command_response", {
        sequence = req.sequence,
        requestId = req.requestId,
        command = req.command,
        status = status,
        kind = kind,
        proof = proof or "",
        errorCode = req.errorCode or ""
    })
    os.remove(req.path)
    return true
end

local function errorResponse(req, code, message)
    req.errorCode = code
    local fields = { "errorCode=" .. code, "message=" .. tostring(message):gsub("[\r\n]", " ") }
    stateFields(snapshot(), "", fields)
    return writeResponse(req, "error", "error", "none", fields)
end

local function parseRequest(path, filenameSeq)
    local f = io.open(path, "r")
    if not f then return nil, "missing", "request file could not be opened" end
    local data = f:read("*a")
    f:close()
    if not data or #data > MAX_REQUEST_BYTES then return nil, "oversize", "request file is empty or too large" end
    if data:find("\r", 1, true) then return nil, "carriage_return", "request file contains a carriage return" end
    local allowed = {
        protocol = true, session = true, sequence = true, requestId = true,
        nonce = true, command = true, node = true, caller = true
    }
    local req = { path = path }
    for line in data:gmatch("[^\n]+") do
        local key, value = line:match("^([a-zA-Z][a-zA-Z0-9]*)=(.*)$")
        if not key then return nil, "malformed_line", "request line is not key=value" end
        if not allowed[key] then return nil, "unknown_field", "request field is not allowed: " .. key end
        if req[key] ~= nil then return nil, "duplicate_field", "request field is duplicated: " .. key end
        req[key] = value
    end
    local missing = {}
    for _, key in ipairs({ "protocol", "session", "sequence", "requestId", "nonce", "command" }) do
        if req[key] == nil then missing[#missing + 1] = key end
    end
    if #missing > 0 then
        return nil, "missing_field", "request is missing: " .. table.concat(missing, ",")
    end
    if req.protocol ~= PROTOCOL then return nil, "protocol", "request protocol mismatch" end
    if req.session ~= config.sessionId then return nil, "session", "request session mismatch" end
    if not req.sequence:match("^%d+$") then return nil, "sequence_format", "sequence is not decimal" end
    req.sequence = tonumber(req.sequence)
    if not req.sequence or req.sequence < 1 or req.sequence > 999999 then return nil, "sequence_range", "sequence is out of range" end
    if filenameSeq ~= req.sequence then return nil, "sequence_filename", "request filename and sequence differ" end
    local ridSeq, ridNonce = req.requestId:match("^r(%d+)-([0-9a-f]+)$")
    if not ridSeq or tonumber(ridSeq) ~= req.sequence or ridNonce ~= req.nonce then return nil, "request_id", "requestId does not bind sequence and nonce" end
    if not req.nonce:match("^[0-9a-f]+$") then return nil, "nonce_format", "nonce is not lowercase hex" end
    local commands = {
        ["pause-at-mapped-node"] = true,
        ["pause-at-caller-token"] = true,
        ["inspect"] = true,
        ["step-one-IL-node"] = true,
        ["step-into-mapped-call"] = true,
        ["resume-to-supported-boundary"] = true,
        ["stop"] = true
    }
    if not commands[req.command] then return nil, "unknown_command", "command is not in the supported vocabulary" end
    if req.node == nil then req.node = "" end
    if req.node ~= "" then
        if not req.node:match("^%d+$") then return nil, "node", "node is not a decimal index" end
        local nodeIndex = tonumber(req.node)
        if not nodeIndex or nodeIndex < 0 or nodeIndex > lastNodeIndex then return nil, "node", "node index is out of range" end
        req.node = nodeIndex
    end
    if req.caller == nil then req.caller = "" end
    if req.caller ~= "" then
        if not req.caller:match("^%d+$") then return nil, "caller", "caller is not a decimal index" end
        local callerIndex = tonumber(req.caller)
        if not callerIndex or not callerByIndex[callerIndex] then return nil, "caller", "caller index is out of range" end
        req.caller = callerIndex
    end
    if req.node ~= "" and req.command ~= "pause-at-mapped-node" then return nil, "node_not_allowed", "node is only valid for pause-at-mapped-node" end
    if req.caller ~= "" and req.command ~= "pause-at-caller-token" then return nil, "caller_not_allowed", "caller is only valid for pause-at-caller-token" end
    return req
end

local function sequenceAllowed(req)
    if req.sequence <= session.lastSeq then return false, "stale_sequence" end
    if req.sequence > session.lastSeq + MAX_SEQUENCE_GAP then return false, "out_of_order" end
    if session.lastRequestId == req.requestId then return false, "duplicate_request" end
    return true
end

local function clearBreakpoints()
    pcall(function() cpu.debug:bpclear() end)
end

local function expectedBranchSuccessor(branch, boundary)
    if branch.condition == "Always" then
        return nodeByAddress[branch.targetAddress], "always"
    end
    if branch.condition == "IfZero" then
        if boundary.conditionCell == 0 then
            return nodeByAddress[branch.targetAddress], "zero"
        end
        local fallThrough = nodeByIndex[boundary.node.index + 1]
        return fallThrough, "nonzero"
    end
    return nil, nil
end

local function completeStep(state)
    local step = session.step
    local boundary = session.current
    local fields = {}
    local transitions = step.transitions
    fields[#fields + 1] = "fromBoundaryPhase=" .. step.from.phase
    fields[#fields + 1] = "fromNodeIndex=" .. tostring(step.from.node.index)
    fields[#fields + 1] = "toBoundaryPhase=" .. boundary.phase
    fields[#fields + 1] = "toNodeIndex=" .. tostring(boundary.node.index)
    fields[#fields + 1] = "steps=" .. tostring(step.count)
    fields[#fields + 1] = "transitionCount=" .. tostring(#transitions)
    for index, transition in ipairs(transitions) do
        fields[#fields + 1] = string.format("transition.%d=%s", index - 1, transition)
    end
    boundaryFields(boundary, fields)
    stateFields(state, "", fields)
    local branchInfo = step.branchInfo
    if branchInfo then
        local branch = branchInfo.branch
        local liveOperand = readb(branch.operandAddress)
        local uAdvance = (state.u - branchInfo.uAtHandler) & 0xFFFF
        fields[#fields + 1] = "branchNodeIndex=" .. tostring(branchInfo.node.index)
        fields[#fields + 1] = "branchCondition=" .. tostring(branch.condition)
        fields[#fields + 1] = "branchPath=" .. tostring(branchInfo.path)
        if branch.condition == "IfZero" then
            fields[#fields + 1] = "branchConditionCell=" .. hex16(branchInfo.conditionCell)
        else
            fields[#fields + 1] = "branchConditionCell="
        end
        fields[#fields + 1] = "branchTokenAddress=" .. hex16(branch.tokenAddress)
        fields[#fields + 1] = "branchOperandAddress=" .. hex16(branch.operandAddress)
        fields[#fields + 1] = "branchOperandByte=" .. hex2(branch.operandByte)
        fields[#fields + 1] = "branchLiveOperandByte=" .. hex2(liveOperand)
        fields[#fields + 1] = "branchTargetAddress=" .. hex16(branch.targetAddress)
        fields[#fields + 1] = "branchExpectedNextY=" .. hex16(branchInfo.expectedNode.address)
        fields[#fields + 1] = "branchObservedNextY=" .. hex16(state.y)
        fields[#fields + 1] = "branchUAtHandler=" .. hex16(branchInfo.uAtHandler)
        fields[#fields + 1] = "branchUNext=" .. hex16(state.u)
        fields[#fields + 1] = "branchUAdvance=" .. hex16(uAdvance)
    end
    local resultObserved = nil
    if map.expectedResult then
        fields[#fields + 1] = "resultExpected=" .. hex16(map.expectedResult)
        if boundary.phase == "prefetch" and boundary.node.index == map.returnNodeIndex then resultObserved = readw(state.u) end
        if boundary.phase == "post-return" and step.from.node.index == map.returnNodeIndex then resultObserved = readw(step.fromState.u) end
        if resultObserved then fields[#fields + 1] = "resultObserved=" .. hex16(resultObserved) else fields[#fields + 1] = "resultObserved=" end
    end
    if boundary.phase == "post-return" then
        fields[#fields + 1] = "postReturnS=" .. hex16(state.s)
        fields[#fields + 1] = "callerCursor=" .. hex16(state.y)
        fields[#fields + 1] = "postReturnToken=" .. hex16(readw(state.y))
    end
    fields[#fields + 1] = "timeBefore=" .. string.format("%.9f", step.fromState.time)
    fields[#fields + 1] = "timeAfter=" .. string.format("%.9f", state.time)
    local req = step.request
    session.step = nil
    session.phase = "paused"
    local kind = step.kind == "resume" and "resumed-to-boundary" or "node-stepped"
    writeResponse(req, "ok", kind, "boundary_reached", fields)
    logEvent(kind == "node-stepped" and "node_step_complete" or "resume_complete", {
        sequence = req.sequence,
        requestId = req.requestId,
        fromNode = step.from.node.index,
        toNode = boundary.node.index,
        toPhase = boundary.phase,
        steps = step.count,
        branchPath = branchInfo and branchInfo.path or "",
        branchConditionCell = branchInfo and branchInfo.conditionCell and hex16(branchInfo.conditionCell) or "",
        branchNextY = branchInfo and hex16(state.y) or "",
        branchUAdvance = branchInfo and hex16((state.u - branchInfo.uAtHandler) & 0xFFFF) or "",
        resultObserved = resultObserved and hex16(resultObserved) or ""
    })
end

local function failStep(req, code, message, state)
    local step = session.step
    session.step = nil
    session.phase = "error"
    session.current = nil
    local fields = {}
    if step then
        fields[#fields + 1] = "fromNodeIndex=" .. tostring(step.from.node.index)
        fields[#fields + 1] = "steps=" .. tostring(step.count)
        fields[#fields + 1] = "timeBefore=" .. string.format("%.9f", step.fromState.time)
        fields[#fields + 1] = "timeAfter=" .. string.format("%.9f", state.time)
    end
    stateFields(state, "", fields)
    logEvent("step_failure", { sequence = req.sequence, requestId = req.requestId, code = code })
    writeResponse(req, "error", "error", "none", { "errorCode=" .. code, "message=" .. tostring(message) } )
end

local function beginStep(req, kind, targetType, targetNode, acceptableNodes, branchInfo)
    local state = snapshot()
    local boundary = session.current
    if not boundary then
        errorResponse(req, "no_current_boundary", "no supported boundary is current")
        return
    end
    local acceptable = acceptableNodes
    if targetType == "prefetch" and not acceptable then
        acceptable = { [targetNode] = true }
    end
    local step = {
        request = req,
        kind = kind,
        targetType = targetType,
        targetNode = targetNode,
        acceptableNodes = acceptable,
        branchInfo = branchInfo,
        expectedSuccessor = branchInfo and branchInfo.expectedNode.index or nil,
        from = boundary,
        fromState = state,
        count = 0,
        transitions = {},
        handlerSeen = boundary.phase ~= "prefetch",
        savedCursor = boundary.savedCursor,
        returnS = boundary.returnS,
        lastPc = nil,
        lastTime = nil
    }
    session.step = step
    session.phase = "stepping"
    logEvent("step_start", { sequence = req.sequence, requestId = req.requestId, kind = kind, fromNode = boundary.node.index, fromPhase = boundary.phase })
    cpu.debug:step(1)
end

local function processStep(state)
    local step = session.step
    if not step then session.phase = "error"; return end
    if state.exec ~= "stop" then return end
    step.count = step.count + 1
    if step.count > MAX_STEPS_PER_NODE then
        failStep(step.request, "step_budget", "node step exceeded the instruction budget", state)
        return
    end
    if step.lastPc ~= nil and state.pc == step.lastPc and state.time <= step.lastTime then
        failStep(step.request, "step_no_advance", "CPU step returned without an observed location/time advance", state)
        return
    end
    logEvent("native_step", {
        sequence = step.request.sequence,
        step = step.count,
        pc = hex16(state.pc),
        y = hex16(state.y),
        x = hex16(state.x),
        s = hex16(state.s),
        time = string.format("%.9f", state.time)
    })
    local boundary, reason = resolveBoundary(state)
    if boundary and boundary.phase == "return-handler" and boundary.node.index == map.returnNodeIndex then
        session.postReturnContext = { savedCursor = boundary.savedCursor, returnS = boundary.returnS }
        step.savedCursor = boundary.savedCursor
        step.returnS = boundary.returnS
    end
    local isTarget = false
    if step.targetType == "handler" then
        isTarget = boundary and boundary.node.index == step.targetNode and
            (boundary.phase == "handler" or boundary.phase == "return-handler")
    elseif step.targetType == "prefetch" then
        isTarget = boundary and boundary.phase == "prefetch" and step.acceptableNodes[boundary.node.index] and
            (not step.expectedSuccessor or boundary.node.index == step.expectedSuccessor)
    elseif step.targetType == "post-return" then
        isTarget = boundary and boundary.phase == "post-return" and step.savedCursor and
            state.y == step.savedCursor and state.s == ((step.returnS + 2) & 0xFFFF)
    end
    if isTarget then
        if boundary.phase == "prefetch" and step.branchInfo then
            local branch = step.branchInfo.branch
            if boundary.node.index ~= step.branchInfo.expectedNode.index then
                failStep(step.request, "wrong_branch_target", "observed prefetch does not match the branch condition successor", state)
                return
            end
            if readb(branch.operandAddress) ~= branch.operandByte then
                failStep(step.request, "branch_operand_mismatch", "live branch operand byte differs from the map", state)
                return
            end
            if branch.condition == "IfZero" then
                if state.u ~= ((step.branchInfo.uAtHandler + 2) & 0xFFFF) then
                    failStep(step.request, "branch_u_mismatch", "conditional branch did not advance U by exactly two", state)
                    return
                end
            elseif state.u ~= step.branchInfo.uAtHandler then
                failStep(step.request, "branch_u_mismatch", "unconditional branch changed U unexpectedly", state)
                return
            end
        end
        local transition = string.format("type=%s;pc=%s;y=%s;x=%s;u=%s;s=%s;node=%d;token=%s",
            boundary.phase, hex16(state.pc), hex16(state.y), hex16(state.x), hex16(state.u), hex16(state.s),
            boundary.node.index, hex16(boundary.token))
        if boundary.phase == "post-return" then
            transition = transition .. string.format(";savedCursor=%s;returnS=%s", hex16(boundary.savedCursor), hex16(boundary.returnS))
        end
        step.transitions[#step.transitions + 1] = transition
        session.current = boundary
        completeStep(state)
        return
    end
    if boundary and boundary.node.index == step.from.node.index and
        (boundary.phase == "handler" or boundary.phase == "return-handler") then
        if not step.handlerSeen then
            step.handlerSeen = true
            local transition = string.format("type=%s;pc=%s;y=%s;x=%s;u=%s;s=%s;node=%d;token=%s",
                boundary.phase, hex16(state.pc), hex16(state.y), hex16(state.x), hex16(state.u), hex16(state.s),
                boundary.node.index, hex16(boundary.token))
            if boundary.phase == "return-handler" then
                transition = transition .. string.format(";savedCursor=%s;returnS=%s", hex16(boundary.savedCursor), hex16(boundary.returnS))
            end
            step.transitions[#step.transitions + 1] = transition
            if step.targetType == "prefetch" and branchByIndex[step.from.node.index] then
                local branch = branchByIndex[step.from.node.index]
                local expectedNode, path = expectedBranchSuccessor(branch, boundary)
                if not expectedNode then
                    failStep(step.request, "branch_successor", "branch condition has no mapped successor", state)
                    return
                end
                step.branchInfo = {
                    node = boundary.node,
                    branch = branch,
                    conditionCell = boundary.conditionCell,
                    path = path,
                    uAtHandler = boundary.uAtHandler,
                    expectedNode = expectedNode
                }
                step.expectedSuccessor = expectedNode.index
                step.acceptableNodes = { [expectedNode.index] = true }
            end
        else
            failStep(step.request, "reentered_handler", "handler was entered again during the same node step", state)
            return
        end
    elseif boundary and boundary.phase == "prefetch" then
        failStep(step.request, "wrong_successor", "a different node prefetch was reached before the target", state)
        return
    elseif boundary and boundary.phase == "post-return" then
        failStep(step.request, "unexpected_post_return", "caller continuation was reached before the target", state)
        return
    elseif reason == "handler_x_mismatch" or reason == "token_mismatch" then
        failStep(step.request, reason, "map validation failed at a native boundary", state)
        return
    end
    step.lastPc = state.pc
    step.lastTime = state.time
    cpu.debug:step(1)
end

local ENTRY_STEPS = {
    { pc = 0x00FE, name = "ldx-y-increment" },
    { pc = 0x00F8, name = "jmp-indirect" },
    { pc = 0x00FA, name = "pshs-y" },
    { pc = 0x00FC, name = "leay-x" }
}

local function failEntry(req, code, message, state)
    local entry = session.entry
    session.entry = nil
    session.phase = "error"
    session.current = nil
    local fields = { "errorCode=" .. code, "message=" .. tostring(message):gsub("[\r\n]", " ") }
    if entry then
        fields[#fields + 1] = "callerIndex=" .. tostring(entry.caller.index)
        fields[#fields + 1] = "steps=" .. tostring(entry.count)
        fields[#fields + 1] = "timeBefore=" .. string.format("%.9f", entry.fromState.time)
    end
    stateFields(state, "", fields)
    logEvent("call_enter_failure", { sequence = req.sequence, requestId = req.requestId, code = code })
    writeResponse(req, "error", "error", "none", fields)
end

local function completeEntry(state)
    local entry = session.entry
    local boundary = session.current
    local caller = entry.caller
    local fields = {}
    fields[#fields + 1] = "fromBoundaryPhase=caller-prefetch"
    fields[#fields + 1] = "toBoundaryPhase=prefetch"
    fields[#fields + 1] = "toNodeIndex=0"
    fields[#fields + 1] = "steps=" .. tostring(entry.count)
    fields[#fields + 1] = "transitionCount=" .. tostring(#entry.transitions)
    for index, transition in ipairs(entry.transitions) do
        fields[#fields + 1] = string.format("transition.%d=%s", index - 1, transition)
    end
    callerFields(caller, fields)
    boundaryFields(boundary, fields)
    stateFields(state, "", fields)
    fields[#fields + 1] = "entrySPre=" .. hex16(entry.callerS)
    fields[#fields + 1] = "entryS=" .. hex16(state.s)
    fields[#fields + 1] = "entryDeltaS=" .. hex16((entry.callerS - state.s) & 0xFFFF)
    fields[#fields + 1] = "entryX=" .. hex16(state.x)
    fields[#fields + 1] = "entryY=" .. hex16(state.y)
    fields[#fields + 1] = "entryU=" .. hex16(state.u)
    fields[#fields + 1] = "entryUAtBoundary=" .. hex16(entry.callerU)
    fields[#fields + 1] = "savedCursor=" .. hex16(caller.callerSuccessor)
    fields[#fields + 1] = "timeBefore=" .. string.format("%.9f", entry.fromState.time)
    fields[#fields + 1] = "timeAfter=" .. string.format("%.9f", state.time)
    session.entry = nil
    session.phase = "paused"
    writeResponse(entry.request, "ok", "call-entered", "boundary_reached", fields)
    logEvent("call_enter_complete", {
        sequence = entry.request.sequence,
        requestId = entry.request.requestId,
        callerIndex = caller.index,
        steps = entry.count,
        pc = hex16(state.pc),
        x = hex16(state.x),
        y = hex16(state.y),
        u = hex16(state.u),
        s = hex16(state.s),
        savedCursor = hex16(caller.callerSuccessor),
        entryDeltaS = hex16((entry.callerS - state.s) & 0xFFFF)
    })
end

local function processEntry(state)
    local entry = session.entry
    local req = entry.request
    if state.exec ~= "stop" then return end
    entry.count = entry.count + 1
    local expected = ENTRY_STEPS[entry.count]
    if not expected then
        failEntry(req, "entry_step_budget", "call entry exceeded the exact four-instruction chain", state)
        return
    end
    if state.pc ~= expected.pc then
        failEntry(req, "unexpected_entry_stop",
            string.format("entry step %d stopped at PC %s, expected %s", entry.count, hex16(state.pc), hex16(expected.pc)), state)
        return
    end
    local caller = entry.caller
    local entryS = (entry.callerS - 2) & 0xFFFF
    local expectedS = entry.count <= 2 and entry.callerS or entryS
    if state.s ~= expectedS then
        failEntry(req, "entry_s_mismatch", "control stack does not match the entry chain", state)
        return
    end
    if state.u ~= entry.callerU then
        failEntry(req, "entry_u_mismatch", "data stack changed during the call entry", state)
        return
    end
    if entry.count == 1 then
        if state.y ~= caller.callerSuccessor then
            failEntry(req, "entry_y_mismatch", "Y is not the caller successor after LDX ,Y++", state)
            return
        end
        if state.x ~= caller.callerToken then
            failEntry(req, "entry_x_mismatch", "X is not the caller token after LDX ,Y++", state)
            return
        end
    elseif entry.count == 2 then
        if state.y ~= caller.callerSuccessor then
            failEntry(req, "entry_y_mismatch", "Y is not the caller successor at the JMP target", state)
            return
        end
        if state.x ~= caller.calleeBodyStart then
            failEntry(req, "entry_x_mismatch", "X is not the callee body start at the JMP target", state)
            return
        end
    elseif entry.count == 3 then
        if state.x ~= caller.calleeBodyStart or state.y ~= caller.callerSuccessor then
            failEntry(req, "entry_register_mismatch", "X/Y differ from the PSHS Y entry state", state)
            return
        end
        if readw(state.s) ~= caller.callerSuccessor then
            failEntry(req, "entry_saved_cursor_mismatch", "w@S is not the caller successor after PSHS Y", state)
            return
        end
    else
        if state.x ~= caller.calleeBodyStart or state.y ~= caller.calleeBodyStart then
            failEntry(req, "entry_register_mismatch", "X/Y are not the callee body start at the first prefetch", state)
            return
        end
        if readw(state.s) ~= caller.callerSuccessor then
            failEntry(req, "entry_saved_cursor_mismatch", "w@S is not the caller successor at the first prefetch", state)
            return
        end
        local node = nodeByIndex[0]
        local liveToken = readw(caller.calleeBodyStart)
        if liveToken ~= node.token then
            failEntry(req, "entry_token_mismatch", "live callee first token differs from the mapped node", state)
            return
        end
        local transition = string.format("type=%s;pc=%s;y=%s;x=%s;u=%s;s=%s;callerIndex=%d;savedCursor=%s",
            expected.name, hex16(state.pc), hex16(state.y), hex16(state.x), hex16(state.u), hex16(state.s),
            caller.index, hex16(caller.callerSuccessor))
        entry.transitions[#entry.transitions + 1] = transition
        session.current = { phase = "prefetch", node = node, token = liveToken }
        completeEntry(state)
        return
    end
    local transition = string.format("type=%s;pc=%s;y=%s;x=%s;u=%s;s=%s;callerIndex=%d",
        expected.name, hex16(state.pc), hex16(state.y), hex16(state.x), hex16(state.u), hex16(state.s), caller.index)
    if entry.count >= 3 then
        transition = transition .. ";savedCursor=" .. hex16(readw(state.s))
    end
    entry.transitions[#entry.transitions + 1] = transition
    logEvent("native_step", {
        sequence = req.sequence,
        step = entry.count,
        phase = "entry",
        pc = hex16(state.pc),
        y = hex16(state.y),
        x = hex16(state.x),
        u = hex16(state.u),
        s = hex16(state.s),
        time = string.format("%.9f", state.time)
    })
    cpu.debug:step(1)
end

local function handlePauseStop(state)
    local pause = session.pause
    session.pause = nil
    pcall(function() cpu.debug:bpclear(pause.breakpoint) end)
    local boundary, reason = resolveBoundary(state)
    if pause.caller then
        if boundary and boundary.phase == "caller-prefetch" and boundary.caller.index == pause.caller.index and
            state.pc == 0x00FC and state.y == pause.caller.callerTokenAddress and
            readw(pause.caller.callerTokenAddress) == pause.caller.callerToken then
            session.current = boundary
            session.postReturnContext = nil
            session.phase = "paused"
            local fields = {}
            boundaryFields(boundary, fields)
            stateFields(state, "", fields)
            logEvent("caller_pause_hit", { sequence = pause.request.sequence, requestId = pause.request.requestId, caller = pause.caller.index })
            writeResponse(pause.request, "ok", "paused-at-caller", "boundary_reached", fields)
            return
        end
    elseif boundary and boundary.phase == "prefetch" and boundary.node.index == pause.node.index and
        state.pc == 0x00FC and state.y == pause.node.address then
        session.current = boundary
        session.postReturnContext = nil
        session.phase = "paused"
        local fields = {}
        boundaryFields(boundary, fields)
        stateFields(state, "", fields)
        logEvent("pause_hit", { sequence = pause.request.sequence, requestId = pause.request.requestId, node = pause.node.index })
        writeResponse(pause.request, "ok", "paused-at-node", "boundary_reached", fields)
        return
    end
    session.phase = "error"
    session.current = nil
    local message = "stopped at an unexpected location: " .. tostring(reason or "not a mapped node")
    logEvent("pause_failure", { sequence = pause.request.sequence, requestId = pause.request.requestId, reason = message })
    errorResponse(pause.request, "unexpected_stop", message)
end

local function commandPause(req)
    local rearm = session.phase == "paused" and session.current and session.current.phase == "post-return"
    if session.phase ~= "initial" and not rearm then
        errorResponse(req, "wrong_phase", "pause-at-mapped-node is only valid from the initial stopped state or after a post-return boundary")
        return
    end
    if type(req.node) ~= "number" then
        errorResponse(req, "node_required", "pause-at-mapped-node requires a mapped node index")
        return
    end
    local node = nodeByIndex[req.node]
    if not node then errorResponse(req, "node", "node is not mapped"); return end
    if rearm then
        local current, reason = resolveBoundary(snapshot())
        if not current or current.phase ~= "post-return" then
            errorResponse(req, "unsupported_boundary", tostring(reason or "post-return boundary is no longer current"))
            return
        end
        session.current = nil
        session.postReturnContext = nil
        session.inspectionCount = 0
    end
    clearBreakpoints()
    local okBp, breakpoint = pcall(function()
        return cpu.debug:bpset(0x00FC, string.format("y==0x%04x", node.address), "")
    end)
    if not okBp then errorResponse(req, "breakpoint", tostring(breakpoint)); return end
    session.pause = { request = req, node = node, breakpoint = breakpoint }
    session.phase = "running"
    logEvent("pause_armed", { sequence = req.sequence, requestId = req.requestId, node = req.node, breakpoint = breakpoint })
    cpu.debug:go()
end

local function commandPauseAtCaller(req)
    local rearm = session.phase == "paused" and session.current and session.current.phase == "post-return"
    if session.phase ~= "initial" and not rearm then
        errorResponse(req, "wrong_phase", "pause-at-caller-token is only valid from the initial stopped state or after a post-return boundary")
        return
    end
    if type(req.caller) ~= "number" then
        errorResponse(req, "caller_required", "pause-at-caller-token requires an explicit caller index")
        return
    end
    local caller = callerByIndex[req.caller]
    if not caller then errorResponse(req, "caller", "caller is not mapped"); return end
    if rearm then
        local current, reason = resolveBoundary(snapshot())
        if not current or current.phase ~= "post-return" then
            errorResponse(req, "unsupported_boundary", tostring(reason or "post-return boundary is no longer current"))
            return
        end
        session.current = nil
        session.postReturnContext = nil
        session.inspectionCount = 0
    end
    clearBreakpoints()
    local okBp, breakpoint = pcall(function()
        return cpu.debug:bpset(0x00FC, string.format("y==0x%04x", caller.callerTokenAddress), "")
    end)
    if not okBp then errorResponse(req, "breakpoint", tostring(breakpoint)); return end
    session.pause = { request = req, caller = caller, breakpoint = breakpoint }
    session.phase = "running"
    logEvent("caller_pause_armed", { sequence = req.sequence, requestId = req.requestId, caller = req.caller, breakpoint = breakpoint })
    cpu.debug:go()
end

local function commandInspect(req)
    if session.phase ~= "paused" then
        errorResponse(req, "wrong_phase", "inspect requires a paused supported boundary")
        return
    end
    local before = snapshot()
    if before.exec ~= "stop" then
        errorResponse(req, "not_stopped", "inspect requires stopped execution")
        return
    end
    local boundary, reason = resolveBoundary(before)
    if not boundary then
        errorResponse(req, "unsupported_boundary", tostring(reason or "location is not a supported boundary"))
        return
    end
    local fields = {}
    boundaryFields(boundary, fields)
    stateFields(before, "", fields)
    local after = snapshot()
    local unchanged = before.pc == after.pc and before.curpc == after.curpc and before.x == after.x and
        before.y == after.y and before.u == after.u and before.s == after.s and before.time == after.time
    session.inspectionCount = session.inspectionCount + 1
    fields[#fields + 1] = "inspectSequence=" .. tostring(session.inspectionCount)
    fields[#fields + 1] = "timeBefore=" .. string.format("%.9f", before.time)
    fields[#fields + 1] = "timeAfter=" .. string.format("%.9f", after.time)
    fields[#fields + 1] = "stateUnchanged=" .. (unchanged and "yes" or "no")
    writeResponse(req, "ok", "inspection", "stopped_read_only", fields)
end

local function beginPrefetchSuccessor(req, kind, boundary)
    local node = boundary.node
    if node.index == map.returnNodeIndex then
        beginStep(req, kind, "post-return", node.index)
        return
    end
    local branch = branchByIndex[node.index]
    if branch then
        local acceptable = {}
        local targetNode = nodeByAddress[branch.targetAddress]
        if not targetNode then
            errorResponse(req, "branch_target", "branch target is not a mapped node")
            return
        end
        acceptable[targetNode.index] = true
        if branch.condition == "IfZero" then
            local fallThrough = nodeByIndex[node.index + 1]
            if not fallThrough then
                errorResponse(req, "branch_successor", "conditional branch has no fall-through node")
                return
            end
            acceptable[fallThrough.index] = true
        end
        beginStep(req, kind, "prefetch", nil, acceptable, nil)
        return
    end
    local nextNode = nodeByIndex[node.index + 1]
    if not nextNode then
        errorResponse(req, "no_successor", "the current node has no mapped successor")
        return
    end
    beginStep(req, kind, "prefetch", nextNode.index)
end

local function beginHandlerSuccessor(req, kind, boundary)
    local node = boundary.node
    if node.index == map.returnNodeIndex then
        beginStep(req, kind, "post-return", node.index)
        return
    end
    local branch = branchByIndex[node.index]
    if branch then
        local expectedNode, path = expectedBranchSuccessor(branch, boundary)
        if not expectedNode then
            errorResponse(req, "branch_successor", "branch condition has no mapped successor")
            return
        end
        beginStep(req, kind, "prefetch", expectedNode.index, { [expectedNode.index] = true }, {
            node = node,
            branch = branch,
            conditionCell = boundary.conditionCell,
            path = path,
            uAtHandler = boundary.uAtHandler,
            expectedNode = expectedNode
        })
        return
    end
    local nextNode = nodeByIndex[node.index + 1]
    if not nextNode then
        errorResponse(req, "no_successor", "the current node has no mapped successor")
        return
    end
    beginStep(req, kind, "prefetch", nextNode.index)
end

local function commandStepInto(req)
    if session.phase ~= "paused" then
        errorResponse(req, "wrong_phase", "step-into-mapped-call requires a paused caller boundary")
        return
    end
    local boundary = session.current
    if not boundary then errorResponse(req, "no_current_boundary", "no supported boundary is current"); return end
    if boundary.phase ~= "caller-prefetch" then
        errorResponse(req, "not_caller_boundary", "step-into-mapped-call requires the current caller-token prefetch boundary")
        return
    end
    local caller = boundary.caller
    local state = snapshot()
    if state.exec ~= "stop" then
        errorResponse(req, "not_stopped", "step-into-mapped-call requires stopped execution")
        return
    end
    if state.pc ~= 0x00FC or state.y ~= caller.callerTokenAddress then
        errorResponse(req, "caller_boundary_mismatch", "caller-token boundary registers do not match the caller record")
        return
    end
    if readw(caller.callerTokenAddress) ~= caller.callerToken then
        errorResponse(req, "caller_token_mismatch", "live caller token differs from the caller record")
        return
    end
    if readw(caller.callerSuccessor) ~= caller.postReturnToken then
        errorResponse(req, "caller_successor_mismatch", "live caller successor token differs from the caller record")
        return
    end
    session.entry = {
        request = req,
        caller = caller,
        from = boundary,
        fromState = state,
        callerS = state.s,
        callerU = state.u,
        count = 0,
        transitions = {}
    }
    session.phase = "entering"
    logEvent("call_enter_start", {
        sequence = req.sequence,
        requestId = req.requestId,
        callerIndex = caller.index,
        pc = hex16(state.pc),
        y = hex16(state.y),
        x = hex16(state.x),
        u = hex16(state.u),
        s = hex16(state.s)
    })
    cpu.debug:step(1)
end

local function commandStep(req)
    if session.phase ~= "paused" then
        errorResponse(req, "wrong_phase", "step-one-IL-node requires a paused supported boundary")
        return
    end
    local boundary = session.current
    if not boundary then errorResponse(req, "no_current_boundary", "no supported boundary is current"); return end
    if boundary.phase == "caller-prefetch" then
        errorResponse(req, "step_into_required", "a caller-token prefetch requires step-into-mapped-call")
        return
    end
    if boundary.phase == "post-return" then
        errorResponse(req, "no_successor", "the caller continuation has no further mapped node")
        return
    end
    if boundary.phase == "prefetch" then
        beginPrefetchSuccessor(req, "step", boundary)
    else
        beginHandlerSuccessor(req, "step", boundary)
    end
end

local function commandResume(req)
    if session.phase ~= "paused" then
        errorResponse(req, "wrong_phase", "resume-to-supported-boundary requires a paused supported boundary")
        return
    end
    local boundary = session.current
    if not boundary then errorResponse(req, "no_current_boundary", "no supported boundary is current"); return end
    if boundary.phase == "prefetch" then
        beginStep(req, "resume", "handler", boundary.node.index)
    elseif boundary.phase == "handler" or boundary.phase == "return-handler" then
        beginHandlerSuccessor(req, "resume", boundary)
    elseif boundary.phase == "post-return" then
        errorResponse(req, "no_successor", "the caller continuation has no further supported boundary")
    else
        errorResponse(req, "wrong_phase", "current boundary phase is not supported")
    end
end

local function commandStop(req)
    if session.phase ~= "initial" and session.phase ~= "paused" and session.phase ~= "error" then
        errorResponse(req, "wrong_phase", "stop requires initial, paused or error state")
        return
    end
    local fields = { "exitScheduled=yes" }
    stateFields(snapshot(), "", fields)
    session.phase = "stopped"
    writeResponse(req, "ok", "stopped", "exit_scheduled", fields)
    logEvent("session_stopped", { sequence = req.sequence, requestId = req.requestId })
    session.stopping = true
    pcall(function() m:exit() end)
    pcall(function() cpu.debug:go() end)
end

local function dispatch(req)
    local allowed, sequenceCode = sequenceAllowed(req)
    if not allowed then
        errorResponse(req, sequenceCode, "request sequence is stale or out of order")
        return
    end
    session.lastSeq = req.sequence
    session.lastRequestId = req.requestId
    logEvent("command_accepted", { sequence = req.sequence, requestId = req.requestId, command = req.command, node = req.node or "" })
    if req.command == "pause-at-mapped-node" then commandPause(req)
    elseif req.command == "pause-at-caller-token" then commandPauseAtCaller(req)
    elseif req.command == "inspect" then commandInspect(req)
    elseif req.command == "step-one-IL-node" then commandStep(req)
    elseif req.command == "step-into-mapped-call" then commandStepInto(req)
    elseif req.command == "resume-to-supported-boundary" then commandResume(req)
    elseif req.command == "stop" then commandStop(req)
    else errorResponse(req, "unknown_command", "command is not supported") end
end

local function processOneRequest()
    local candidates = {}
    local okDir, iter, dirObject = pcall(lfs.dir, "commands")
    if not okDir then return end
    for name in iter, dirObject do
        local seq = name:match("^request%-(%d+)%.req$")
        if seq then candidates[#candidates + 1] = { name = name, seq = tonumber(seq) } end
    end
    table.sort(candidates, function(a, b) return a.seq < b.seq end)
    for _, candidate in ipairs(candidates) do
        local path = "commands/" .. candidate.name
        local req, code, message = parseRequest(path, candidate.seq)
        if req then
            if req.command == "stop" or req.command == "inspect" or req.command == "step-one-IL-node" or
                req.command == "resume-to-supported-boundary" or req.command == "pause-at-mapped-node" or
                req.command == "pause-at-caller-token" or req.command == "step-into-mapped-call" then
                if session.phase == "stepping" then return end
                dispatch(req)
                return
            end
        else
            if code == "missing" then
                -- The request was renamed into place while the directory was being
                -- enumerated. Do not fabricate a malformed response or delete it;
                -- retry on the next stopped callback.
                logEvent("request_open_retry", { sequence = candidate.seq })
                return
            end
            local fallback = {
                path = path,
                sequence = candidate.seq,
                requestId = "invalid",
                nonce = "00000000",
                command = "invalid"
            }
            local rid = "invalid"
            local nonce = "00000000"
            local f = io.open(path, "r")
            if f then
                local data = f:read("*a") or ""
                f:close()
                rid = data:match("requestId=([A-Za-z0-9%-]+)") or rid
                nonce = data:match("nonce=([A-Za-z0-9]+)") or nonce
            end
            fallback.requestId = rid
            fallback.nonce = nonce
            errorResponse(fallback, code, message)
            return
        end
    end
end

local function writeReady(execState)
    if session.readyWritten then return end
    local ready = io.open("ready.tmp", "w")
    if not ready then startupFailure("ready_open", "could not create ready file") end
    ready:write("protocol=" .. PROTOCOL .. "\n")
    ready:write("session=" .. config.sessionId .. "\n")
    ready:write("variant=" .. config.variant .. "\n")
    ready:write("map=ok\n")
    ready:write("exec=" .. tostring(execState) .. "\n")
    ready:write("lfs=ok\n")
    ready:write("nodes=" .. tostring(#map.nodes) .. "\n")
    ready:write("callers=" .. tostring(#map.callers) .. "\n")
    if map.expectedResult then ready:write("expectedResult=" .. hex16(map.expectedResult) .. "\n") else ready:write("expectedResult=\n") end
    ready:write("hold=" .. hex16(session.resetPc) .. "\n")
    ready:close()
    os.rename("ready.tmp", "ready.txt")
    session.readyWritten = true
    logEvent("session_ready", {
        variant = config.variant,
        session = config.sessionId,
        image = config.expectedImageSha256,
        expectedResult = map.expectedResult and hex16(map.expectedResult) or "",
        resetPc = hex16(session.resetPc)
    })
end

emu.register_periodic(function()
    if session.stopping then return end
    if not session.timeout and (os.time() - session.startWall) >= config.wallTimeoutSeconds then
        session.timeout = true
        session.phase = "error"
        logEvent("session_timeout", { wallSeconds = os.time() - session.startWall, emulatedTime = string.format("%.9f", m.time:as_double()) })
        local f = io.open("session-timeout.txt", "w")
        if f then f:write("wall timeout\n"); f:close() end
        pcall(function() m:exit() end)
        pcall(function() cpu.debug:go() end)
        return
    end
    if dbg.execution_state ~= "stop" then return end
    local state = snapshot()
    if session.phase == "starting" then
        if state.pc == session.resetPc then
            pcall(function() cpu.debug:bpclear() end)
            session.initialBreakpoint = nil
            session.phase = "initial"
            writeReady("stop")
        else
            startupFailure("initial_stop", string.format("stopped at %04X instead of reset entry %04X", state.pc, session.resetPc))
        end
        return
    end
    if session.phase == "running" and session.pause then
        handlePauseStop(state)
        return
    end
    if session.phase == "stepping" then
        processStep(state)
        return
    end
    if session.phase == "entering" then
        processEntry(state)
        return
    end
    if session.phase == "initial" or session.phase == "paused" or session.phase == "error" then
        processOneRequest()
        return
    end
end, "periodic")

if session.resetPc == 0 or session.resetPc == 0xFFFF then
    startupFailure("reset_vector", string.format("unsupported reset vector %04X", session.resetPc))
end
if dbg.execution_state ~= "stop" then
    startupFailure("start_not_stopped", "session did not load while the debugger was stopped")
end
local okInitial, initialBp = pcall(function() return cpu.debug:bpset(session.resetPc, "1", "") end)
if not okInitial then startupFailure("initial_breakpoint", tostring(initialBp)) end
session.initialBreakpoint = initialBp
cpu.debug:go()

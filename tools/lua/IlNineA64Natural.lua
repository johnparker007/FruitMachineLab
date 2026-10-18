-- Read-only MAME 0.281 natural 9A64 boundary observer.
--
-- Exact instruction boundaries come from native debugger breakpoints.  The Lua
-- periodic callback is only the stopped-state driver; it is never treated as an
-- instruction observation source.  This script never writes PC, registers, RAM,
-- ROM, save states or the VM stacks.  It records strict JSONL only.

local PROTOCOL = "il-9a64-natural-v1"
local MAX_BREAKPOINT_STEPS = 100000
local MEMORY_WORD_ADDRESS = 0x00A0
local MEMORY_MASK = 0x4000
local CALLER_SITE = 0xEF9C
local OR_HANDLER_AFTER_STD = 0x766F
local CLEAR_HANDLER_AFTER_STD = 0x767D

local m = manager.machine
local cpu = m.devices[":maincpu"]
local mem = cpu.spaces["program"]
local dbg = m.debugger

local function hex16(v) return string.format("%04X", v & 0xFFFF) end
local function hex8(v) return string.format("%02X", v & 0xFF) end
local function readw(addr) return mem:read_u16(addr & 0xFFFF) end
local function readb(addr) return mem:read_u8(addr & 0xFFFF) end
local function sameHex(a, b)
    return type(a) == "string" and type(b) == "string" and a:upper() == b:upper()
end

local events = io.open("events.jsonl", "a")
if not events then error("events.jsonl could not be opened") end
events:setvbuf("no")

-- BEGIN-EVENT-JSON-SERIALIZER
-- Tests extract this block to exercise the real serializer.  Every control
-- byte U+0000..U+001F, quote and backslash is escaped; no input byte is dropped.
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
    logEvent("startup_failure", { code = code, message = tostring(message) })
    local f = io.open("startup-failure.txt", "w")
    if f then
        f:write("code=" .. tostring(code) .. "\n")
        f:write("message=" .. tostring(message):gsub("[\r\n]", " ") .. "\n")
        f:close()
    end
    pcall(function() m:exit() end)
    pcall(function() cpu.debug:go() end)
    error(code .. ": " .. tostring(message))
end

if not dbg then startupFailure("no_debugger", "manager.machine.debugger is nil; -debug and -debugger windows are required") end
if not cpu or not cpu.debug then startupFailure("no_cpu_debug", "maincpu debug interface is unavailable") end

local mapPath = os.getenv("FML_IL_9A64_MAP") or "a64-map.lua"
local configPath = os.getenv("FML_IL_9A64_CONFIG") or "session-config.lua"
local okMap, map = pcall(dofile, mapPath)
if not okMap or type(map) ~= "table" then startupFailure("map", "9A64 map could not be loaded") end
local okConfig, config = pcall(dofile, configPath)
if not okConfig or type(config) ~= "table" then startupFailure("config", "session config could not be loaded") end

if map.schemaVersion ~= 1 or config.schemaVersion ~= 1 then startupFailure("schema", "map/config schema mismatch") end
if map.protocol ~= PROTOCOL or config.protocol ~= PROTOCOL then startupFailure("protocol", "map/config protocol mismatch") end
if type(config.sessionId) ~= "string" or config.sessionId == "" then startupFailure("session", "session id is missing") end
if type(config.secondsToRun) ~= "number" or config.secondsToRun < 1 or config.secondsToRun > 120 then startupFailure("seconds", "emulated seconds are out of range") end
if type(config.wallTimeoutSeconds) ~= "number" or config.wallTimeoutSeconds < 30 or config.wallTimeoutSeconds > 600 then startupFailure("wall", "wall timeout is out of range") end
if type(config.maxCalls) ~= "number" or config.maxCalls < 1 or config.maxCalls > 8 then startupFailure("max_calls", "maxCalls is out of range") end
if not sameHex(map.imageSha256, config.expectedImageSha256) then startupFailure("map_image", "map image differs from the session image") end
if not sameHex(map.originalRomSha256, config.expectedOriginalRomSha256) then startupFailure("map_original", "map original differs from the session original") end
if map.bodyStart ~= 0x9A64 or map.bodyEndExclusive ~= 0x9A72 then startupFailure("map_body", "map body is not 9A64..9A72") end
if type(map.nodes) ~= "table" or #map.nodes ~= 6 then startupFailure("map_nodes", "map does not contain six nodes") end
if type(map.entries) ~= "table" or #map.entries ~= 14 then startupFailure("map_entries", "map does not contain fourteen entries") end

local nodeByAddress = {}
local nodeByIndex = {}
local handlerByPc = {}
for _, node in ipairs(map.nodes) do
    if type(node.index) ~= "number" or node.index < 0 or node.index > 5 then startupFailure("map_node_index", "node index is out of range") end
    if type(node.address) ~= "number" or type(node.token) ~= "number" or type(node.handlerPc) ~= "number" then startupFailure("map_node", "node fields are malformed") end
    if nodeByIndex[node.index] then startupFailure("map_node_duplicate", "duplicate node index") end
    if nodeByAddress[node.address] then startupFailure("map_node_address", "duplicate node address") end
    if handlerByPc[node.handlerPc] then startupFailure("map_handler_duplicate", "duplicate handler PC") end
    nodeByIndex[node.index] = node
    nodeByAddress[node.address] = node
    handlerByPc[node.handlerPc] = node
end
for i = 0, 5 do
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
    if live ~= entry.imageByte then
        startupFailure("map_live_byte", string.format("live byte %02X differs from map byte %02X at %04X", live, entry.imageByte, entry.address))
    end
    expectedAddress = expectedAddress + 1
end
if expectedAddress ~= map.bodyEndExclusive then startupFailure("map_body_end", "map does not cover the declared body end") end
if lastNode ~= 5 then startupFailure("map_last_node", "map does not end at node five") end

for _, node in ipairs(map.nodes) do
    local liveToken = readw(node.address)
    if liveToken ~= node.token then
        startupFailure("map_token", string.format("live token %04X differs from map token %04X at %04X", liveToken, node.token, node.address))
    end
    local liveHandler = readw(node.token)
    if liveHandler ~= node.handlerPc then
        startupFailure("map_handler", string.format("token %04X points at %04X, expected handler %04X", node.token, liveHandler, node.handlerPc))
    end
    for offset, byte in ipairs(node.bytes or {}) do
        local live = readb(node.address + offset - 1)
        if live ~= byte then
            startupFailure("map_node_byte", string.format("live node byte %02X differs from map byte %02X at %04X", live, byte, node.address + offset - 1))
        end
    end
end

for _, branch in ipairs(map.branches or {}) do
    local node = nodeByIndex[branch.nodeIndex]
    if not node then startupFailure("map_branch_node", "branch node is missing") end
    if type(branch.operandAddress) ~= "number" or type(branch.operandByte) ~= "number" or type(branch.targetAddress) ~= "number" then
        startupFailure("map_branch_fields", "branch fields are malformed")
    end
    if branch.operandAddress ~= node.address + 2 then startupFailure("map_branch_operand", "branch operand does not follow the token") end
    if readb(branch.operandAddress) ~= branch.operandByte then startupFailure("map_branch_live", "branch operand differs from the live ROM") end
    if ((branch.operandAddress + branch.operandByte) & 0xFFFF) ~= branch.targetAddress then startupFailure("map_branch_target", "branch target is not operand-address plus unsigned byte") end
    if branch.offsetBase ~= "operand-address" or branch.offsetUnsigned ~= true or branch.operandWidthBytes ~= 1 then startupFailure("map_branch_semantics", "branch offset semantics differ from the checked model") end
    local target = nodeByAddress[branch.targetAddress]
    if not target then startupFailure("map_branch_boundary", "branch target is not a node boundary") end
end
if #map.branches ~= 2 then startupFailure("map_branches", "map does not contain two checked branches") end

local function snapshot()
    local a = cpu.state["A"].value
    local b = cpu.state["B"].value
    return {
        pc = cpu.state["PC"].value,
        curpc = cpu.state["CURPC"].value,
        a = a,
        b = b,
        d = ((a << 8) | b) & 0xFFFF,
        cc = cpu.state["CC"].value,
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

local function stateFields(state, fields, prefix)
    local p = prefix or ""
    fields[p .. "pc"] = hex16(state.pc)
    fields[p .. "curpc"] = hex16(state.curpc)
    fields[p .. "a"] = hex8(state.a)
    fields[p .. "b"] = hex8(state.b)
    fields[p .. "d"] = hex16(state.d)
    fields[p .. "cc"] = hex8(state.cc)
    fields[p .. "x"] = hex16(state.x)
    fields[p .. "y"] = hex16(state.y)
    fields[p .. "u"] = hex16(state.u)
    fields[p .. "s"] = hex16(state.s)
    fields[p .. "emulatedTime"] = string.format("%.9f", state.time)
    local d = words(state.u, 4)
    local c = words(state.s, 2)
    for i = 0, 3 do fields[p .. "dataStack" .. tostring(i)] = hex16(d[i]) end
    for i = 0, 1 do fields[p .. "controlStack" .. tostring(i)] = hex16(c[i]) end
end

local session = {
    phase = "starting",
    callsStarted = 0,
    callsCompleted = 0,
    active = nil,
    post = nil,
    startWall = os.time(),
    stopping = false,
    readyWritten = false,
    bps = {},
    lastStopKey = nil,
    resetPc = readw(0xFFFE)
}

local function writeReady()
    if session.readyWritten then return end
    local f = io.open("ready.tmp", "w")
    if not f then startupFailure("ready_open", "could not create ready file") end
    f:write("protocol=" .. PROTOCOL .. "\n")
    f:write("session=" .. config.sessionId .. "\n")
    f:write("map=ok\n")
    f:write("exec=" .. tostring(dbg.execution_state) .. "\n")
    f:write("bodyStart=9A64\n")
    f:write("bodyEndExclusive=9A72\n")
    f:write("maxCalls=" .. tostring(config.maxCalls) .. "\n")
    f:write("hold=" .. hex16(session.resetPc) .. "\n")
    f:close()
    os.rename("ready.tmp", "ready.txt")
    session.readyWritten = true
end

local function finish(reason)
    if session.stopping then return end
    session.stopping = true
    session.phase = "stopped"
    local state = snapshot()
    logEvent("session_complete", {
        reason = tostring(reason),
        callsStarted = tostring(session.callsStarted),
        callsCompleted = tostring(session.callsCompleted),
        maxCalls = tostring(config.maxCalls),
        emulatedTime = string.format("%.9f", state.time),
        wallSeconds = tostring(os.time() - session.startWall),
        emulatedBudget = tostring(config.secondsToRun),
        wallBudget = tostring(config.wallTimeoutSeconds),
        pc = hex16(state.pc),
        y = hex16(state.y),
        u = hex16(state.u),
        s = hex16(state.s)
    })
    local f = io.open("session-complete.txt", "w")
    if f then
        f:write("reason=" .. tostring(reason) .. "\n")
        f:write("callsStarted=" .. tostring(session.callsStarted) .. "\n")
        f:write("callsCompleted=" .. tostring(session.callsCompleted) .. "\n")
        f:write("emulatedTime=" .. string.format("%.9f", state.time) .. "\n")
        f:write("wallSeconds=" .. tostring(os.time() - session.startWall) .. "\n")
        f:close()
    end
    pcall(function() m:exit() end)
    pcall(function() cpu.debug:go() end)
end

local function protocolFailure(code, message)
    logEvent("protocol_failure", {
        code = tostring(code),
        message = tostring(message),
        callsStarted = tostring(session.callsStarted),
        callsCompleted = tostring(session.callsCompleted)
    })
    finish("protocol_failure")
end

local function checkBudget()
    if session.stopping then return true end
    local wall = os.time() - session.startWall
    local emulated = m.time:as_double()
    if wall >= config.wallTimeoutSeconds then
        logEvent("session_timeout", { kind = "wall", wallSeconds = tostring(wall), emulatedTime = string.format("%.9f", emulated) })
        finish("wall_timeout")
        return true
    end
    if emulated >= config.secondsToRun then
        logEvent("session_timeout", { kind = "emulated", wallSeconds = tostring(wall), emulatedTime = string.format("%.9f", emulated) })
        finish("emulated_budget")
        return true
    end
    return false
end

local function setObservationBreakpoints()
    local function setBp(addr, condition, name)
        local ok, bp = pcall(function() return cpu.debug:bpset(addr, condition, "") end)
        if not ok then startupFailure("breakpoint", name .. ": " .. tostring(bp)) end
        session.bps[#session.bps + 1] = bp
    end
    setBp(0x00FC,
        "(w@y==0x9a62)||(y==0x9a64)||(y==0x9a66)||(y==0x9a69)||(y==0x9a6b)||(y==0x9a6e)||(y==0x9a70)",
        "call-and-nodes")
    setBp(0x00F8, "x==0x9a64", "composite-entry")
    setBp(0x7B6F, "y==0x9a66 && x==0x7b6f", "rotate-handler")
    setBp(0x7984, "y==0x9a68 && x==0x7984", "branch-if-zero-handler")
    setBp(0x7667, "y==0x9a6b && x==0x7667", "or-handler")
    setBp(0x766F, "y==0x9a6b && x==0x00a0", "or-after-std")
    setBp(0x797B, "y==0x9a6d && x==0x797b", "branch-always-handler")
    setBp(0x7673, "y==0x9a70 && x==0x7673", "clear-handler")
    setBp(0x767D, "y==0x9a70 && x==0x00a0", "clear-after-std")
    setBp(0x7931, "y==0x9a72 && x==0x7931", "return-handler")
end

local function beginCall(state)
    if session.active then
        protocolFailure("nested_call", "a second 9A64 call started before the previous return completed")
        return
    end
    if session.callsStarted >= config.maxCalls then
        logEvent("call_entry_suppressed", {
            callsStarted = tostring(session.callsStarted),
            y = hex16(state.y),
            token = hex16(readw(state.y))
        })
        return
    end
    session.callsStarted = session.callsStarted + 1
    session.active = {
        id = session.callsStarted,
        siteY = state.y,
        callerSuccessor = nil,
        nodes = {},
        handlers = {},
        postReturn = nil
    }
    local fields = {
        callId = tostring(session.callsStarted),
        siteY = hex16(state.y),
        token = hex16(readw(state.y)),
        phase = "call-entry-prefetch"
    }
    stateFields(state, fields)
    logEvent("call_entry", fields)
end

local function completeCall(state)
    local active = session.active
    if not active then return end
    if not active.memory or not active.memory.afterEventLogged then
        protocolFailure("memory_incomplete", "call completed without a bounded memory entry and after-STD observation")
        return
    end
    local nodeSequence = {}
    for _, node in ipairs(active.nodes) do nodeSequence[#nodeSequence + 1] = tostring(node.index) end
    local handlerSequence = {}
    for _, handler in ipairs(active.handlers) do handlerSequence[#handlerSequence + 1] = handler.pc end
    local fields = {
        callId = tostring(active.id),
        callerSuccessor = active.callerSuccessor and hex16(active.callerSuccessor) or "",
        nodeSequence = table.concat(nodeSequence, ","),
        handlerSequence = table.concat(handlerSequence, ","),
        nodeCount = tostring(#active.nodes),
        handlerCount = tostring(#active.handlers),
        postReturnY = active.postReturn and active.postReturn.y or "",
        postReturnS = active.postReturn and active.postReturn.s or "",
        postReturnToken = active.postReturn and active.postReturn.token or "",
        complete = "true"
    }
    stateFields(state, fields)
    logEvent("call_complete", fields)
    session.callsCompleted = session.callsCompleted + 1
    session.active = nil
    session.post = nil
    if session.callsCompleted >= config.maxCalls then
        finish("max_complete_calls")
    end
end

local function handlePrefetch(state)
    local y = state.y
    local token = readw(y)
    if session.post and session.post.armed and y == session.post.cursor then
        local active = session.active
        if not active then protocolFailure("post_return_without_call", "post-return prefetch has no active call"); return end
        local fields = {
            callId = tostring(active.id),
            y = hex16(y),
            token = hex16(token),
            savedCursor = hex16(session.post.cursor),
            returnS = hex16(session.post.returnS),
            phase = "post-return-prefetch"
        }
        stateFields(state, fields)
        logEvent("post_return_prefetch", fields)
        active.postReturn = { y = hex16(y), s = hex16(state.s), token = hex16(token) }
        local bp = session.post.bp
        session.post = nil
        if bp then pcall(function() cpu.debug:bpclear(bp) end) end
        completeCall(state)
        if session.stopping then return end
        if token == 0x9A62 then beginCall(state) end
        return
    end
    if token == 0x9A62 then
        beginCall(state)
        return
    end
    if not session.active then return end
    local node = nodeByAddress[y]
    if not node then
        protocolFailure("unexpected_prefetch", string.format("Y=%04X token=%04X is not a mapped 9A64 node", y, token))
        return
    end
    if token ~= node.token then
        protocolFailure("token_mismatch", string.format("Y=%04X token=%04X differs from map token %04X", y, token, node.token))
        return
    end
    local fields = {
        callId = tostring(session.active.id),
        nodeIndex = tostring(node.index),
        nodeAddress = hex16(node.address),
        token = hex16(token),
        operation = node.operation,
        phase = "prefetch"
    }
    stateFields(state, fields)
    logEvent("node_prefetch", fields)
    session.active.nodes[#session.active.nodes + 1] = {
        index = node.index,
        address = node.address,
        y = hex16(y),
        token = hex16(token),
        u = hex16(state.u),
        s = hex16(state.s)
    }
end

local function handleComposite(state)
    if not session.active then return end
    if state.x ~= 0x9A64 then
        protocolFailure("composite_mismatch", string.format("PC=00F8 X=%04X is not the 9A64 body", state.x))
        return
    end
    session.active.callerSuccessor = state.y
    local fields = {
        callId = tostring(session.active.id),
        pc = hex16(state.pc),
        x = hex16(state.x),
        callerSuccessor = hex16(state.y),
        phase = "composite-entry"
    }
    stateFields(state, fields)
    logEvent("composite_entry", fields)
end

local function memoryEntryFields(state, kind, node)
    local mask = readw(state.u)
    local address = readw((state.u + 2) & 0xFFFF)
    if session.active.siteY ~= CALLER_SITE then
        protocolFailure("memory_caller", string.format("memory handler reached from caller site %04X, not the accepted EF9C site", session.active.siteY))
        return nil
    end
    if address ~= MEMORY_WORD_ADDRESS then
        protocolFailure("memory_address", string.format("memory handler stack address is %04X, not the bounded 00A0 word", address))
        return nil
    end
    if mask ~= MEMORY_MASK then
        protocolFailure("memory_mask", string.format("memory handler stack mask is %04X, not the accepted 4000 mask", mask))
        return nil
    end
    local before = readw(MEMORY_WORD_ADDRESS)
    local expected
    if kind == "or" then
        expected = (before | mask) & 0xFFFF
    else
        expected = before & ((~mask) & 0xFFFF)
    end
    local fields = {
        callId = tostring(session.active.id),
        nodeIndex = tostring(node.index),
        nodeAddress = hex16(node.address),
        token = hex16(node.token),
        operation = node.operation,
        memoryKind = kind,
        memoryAddress = hex16(address),
        maskWord = hex16(mask),
        beforeWord = hex16(before),
        expectedAfterWord = hex16(expected),
        entryU = hex16(state.u),
        entryS = hex16(state.s),
        entryY = hex16(state.y),
        entryX = hex16(state.x),
        entryCC = hex8(state.cc),
        entryD = hex16(state.d),
        stackMaskWord = hex16(mask),
        stackAddressWord = hex16(address),
        phase = "memory-entry"
    }
    stateFields(state, fields)
    logEvent("memory_entry", fields)
    return {
        kind = kind,
        nodeIndex = node.index,
        token = node.token,
        mask = mask,
        address = address,
        before = before,
        expected = expected,
        entryU = state.u,
        entryS = state.s,
        entryY = state.y,
        entryX = state.x,
        entryCC = state.cc,
        entryD = state.d
    }
end

local function handleMemoryEntry(state, node)
    if session.active.memory then
        protocolFailure("memory_duplicate", "a second memory effect stopped before the first after-STD boundary")
        return
    end
    local kind
    if node.token == 0x7665 then kind = "or"
    elseif node.token == 0x7671 then kind = "clear"
    else return end
    local record = memoryEntryFields(state, kind, node)
    if record then session.active.memory = record end
end

local function handleMemoryAfterStd(state)
    local active = session.active
    if not active then
        protocolFailure("memory_without_call", "a memory after-STD stop arrived with no active call")
        return
    end
    local memory = active.memory
    if not memory then
        protocolFailure("memory_missing_entry", "an after-STD stop arrived without a bounded memory entry")
        return
    end
    local expectedPc = memory.kind == "or" and OR_HANDLER_AFTER_STD or CLEAR_HANDLER_AFTER_STD
    if state.pc ~= expectedPc then
        protocolFailure("memory_phase", string.format("memory after-STD PC %04X is not %04X for the %s handler", state.pc, expectedPc, memory.kind))
        return
    end
    if state.x ~= MEMORY_WORD_ADDRESS then
        protocolFailure("memory_after_x", string.format("memory after-STD X is %04X, not the bounded 00A0 word", state.x))
        return
    end
    if ((memory.entryU + 4) & 0xFFFF) ~= state.u then
        protocolFailure("memory_u", string.format("memory handler U advanced to %04X, expected entry %04X plus four", state.u, memory.entryU))
        return
    end
    if memory.entryS ~= state.s then
        protocolFailure("memory_s", string.format("memory handler changed S from %04X to %04X", memory.entryS, state.s))
        return
    end
    if memory.entryY ~= state.y then
        protocolFailure("memory_y", string.format("memory handler changed Y from %04X to %04X", memory.entryY, state.y))
        return
    end
    local after = readw(MEMORY_WORD_ADDRESS)
    if after ~= memory.expected then
        protocolFailure("memory_effect", string.format("%s at 00A0 produced %04X, expected %04X from %04X",
            memory.kind, after, memory.expected, memory.before))
        return
    end
    local expectedD = after
    if state.d ~= expectedD or state.a ~= ((after >> 8) & 0xFF) or state.b ~= (after & 0xFF) then
        protocolFailure("memory_d", string.format("memory handler D=%04X A=%02X B=%02X after STD, expected %04X", state.d, state.a, state.b, expectedD))
        return
    end
    local entryCarry = memory.entryCC & 1
    local exitCarry = state.cc & 1
    local ccContract
    if memory.kind == "clear" then
        if exitCarry ~= 1 then
            protocolFailure("memory_carry", string.format("clear handler exit CC %02X does not assert C after COMA/COMB", state.cc))
            return
        end
        ccContract = "clear: C=1 (COMA/COMB set carry; AND leaves C unchanged)"
    else
        if exitCarry ~= entryCarry then
            protocolFailure("memory_carry", string.format("OR handler changed carry from %d to %d", entryCarry, exitCarry))
            return
        end
        ccContract = "or: C unchanged from entry (ORA/ORB preserve carry)"
    end
    local fields = {
        callId = tostring(active.id),
        nodeIndex = tostring(memory.nodeIndex),
        token = hex16(active.memory.token or 0),
        operation = memory.kind == "or" and "vm_or_word_memory" or "vm_clear_word_memory_bits",
        memoryKind = memory.kind,
        memoryAddress = hex16(memory.address),
        maskWord = hex16(memory.mask),
        beforeWord = hex16(memory.before),
        afterWord = hex16(after),
        expectedAfterWord = hex16(memory.expected),
        uAdvance = "0004",
        sUnchanged = "true",
        yUnchanged = "true",
        xExact = hex16(state.x),
        dAfter = hex16(state.d),
        entryCC = hex8(memory.entryCC),
        exitCC = hex8(state.cc),
        ccContract = ccContract,
        phase = "memory-after-std"
    }
    stateFields(state, fields)
    logEvent("memory_after_std", fields)
    memory.after = after
    memory.afterEventLogged = true
end

local function handleHandler(state)
    if not session.active then
        protocolFailure("handler_without_call", "a 9A64 handler stop arrived with no active call")
        return
    end
    local node = nodeByAddress[(state.y - 2) & 0xFFFF]
    if not node then
        protocolFailure("handler_y", string.format("handler Y=%04X is not node+2 for a mapped node", state.y))
        return
    end
    if state.pc ~= node.handlerPc then
        protocolFailure("handler_pc", string.format("handler PC=%04X is not %04X", state.pc, node.handlerPc))
        return
    end
    if state.x ~= ((node.token + 2) & 0xFFFF) then
        protocolFailure("handler_x", string.format("handler X=%04X is not token pointer+2 %04X", state.x, (node.token + 2) & 0xFFFF))
        return
    end
    local fields = {
        callId = tostring(session.active.id),
        nodeIndex = tostring(node.index),
        nodeAddress = hex16(node.address),
        pc = hex16(state.pc),
        token = hex16(node.token),
        operation = node.operation,
        phase = "handler"
    }
    if node.branch then
        local operandByte = readb(state.y)
        fields.branchCondition = node.branch.condition
        fields.conditionCell = hex16(readw(state.u))
        fields.operandAddress = hex16(state.y)
        fields.operandByte = hex8(operandByte)
        fields.targetAddress = hex16((state.y + operandByte) & 0xFFFF)
    end
    if node.token == 0x792F then
        local savedCursor = readw(state.s)
        fields.savedCursor = hex16(savedCursor)
        fields.returnS = hex16(state.s)
        session.post = {
            callId = session.active.id,
            cursor = savedCursor,
            returnS = state.s,
            armed = true
        }
        local ok, bp = pcall(function()
            return cpu.debug:bpset(0x00FC, "y==0x" .. string.format("%04x", savedCursor), "")
        end)
        if not ok then
            protocolFailure("post_return_breakpoint", tostring(bp))
            return
        end
        session.post.bp = bp
    end
    stateFields(state, fields)
    logEvent("handler_entry", fields)
    session.active.handlers[#session.active.handlers + 1] = {
        index = node.index,
        pc = hex16(state.pc),
        y = hex16(state.y),
        u = hex16(state.u),
        s = hex16(state.s)
    }
    if node.token == 0x7665 or node.token == 0x7671 then
        handleMemoryEntry(state, node)
    end
end

local function handleStop(state)
    local key = string.format("%04X:%04X:%04X:%04X:%04X:%04X:%.9f", state.pc, state.curpc, state.x, state.y, state.u, state.s, state.time)
    if session.lastStopKey == key then
        pcall(function() cpu.debug:go() end)
        return
    end
    session.lastStopKey = key
    local handled = false
    if state.pc == 0x00FC then
        handlePrefetch(state)
        handled = true
    elseif state.pc == 0x00F8 then
        handleComposite(state)
        handled = true
    elseif state.pc == OR_HANDLER_AFTER_STD or state.pc == CLEAR_HANDLER_AFTER_STD then
        handleMemoryAfterStd(state)
        handled = true
    elseif handlerByPc[state.pc] then
        handleHandler(state)
        handled = true
    end
    if not handled then
        protocolFailure("unexpected_stop", string.format("stopped at PC=%04X Y=%04X X=%04X", state.pc, state.y, state.x))
        return
    end
    if not session.stopping then
        pcall(function() cpu.debug:go() end)
    end
end

if session.resetPc == 0 or session.resetPc == 0xFFFF then startupFailure("reset_vector", string.format("unsupported reset vector %04X", session.resetPc)) end
if dbg.execution_state ~= "stop" then startupFailure("start_not_stopped", "session did not load while the debugger was stopped") end

local okInitial, initialBp = pcall(function() return cpu.debug:bpset(session.resetPc, "1", "") end)
if not okInitial then startupFailure("initial_breakpoint", tostring(initialBp)) end
cpu.debug:go()

emu.register_periodic(function()
    if session.stopping then return end
    if checkBudget() then return end
    if dbg.execution_state ~= "stop" then return end
    local state = snapshot()
    if session.phase == "starting" then
        if state.pc == session.resetPc then
            pcall(function() cpu.debug:bpclear() end)
            setObservationBreakpoints()
            session.phase = "running"
            writeReady()
            logEvent("session_ready", {
                session = config.sessionId,
                imageSha256 = config.expectedImageSha256,
                originalRomSha256 = config.expectedOriginalRomSha256,
                sourceMapSha256 = config.expectedSourceMapSha256,
                buildReportSha256 = config.expectedBuildReportSha256,
                replaySha256 = config.expectedReplaySha256,
                inputLuaSha256 = config.expectedInputLuaSha256,
                mameSha256 = config.expectedMameSha256,
                resetPc = hex16(session.resetPc),
                secondsToRun = tostring(config.secondsToRun),
                wallTimeoutSeconds = tostring(config.wallTimeoutSeconds),
                maxCalls = tostring(config.maxCalls),
                bodyStart = hex16(map.bodyStart),
                bodyEndExclusive = hex16(map.bodyEndExclusive),
                debuggerType = type(dbg),
                cpuDebugType = type(cpu.debug),
                luaVersion = tostring(_VERSION),
                luaInstructionCallback = "unsupported",
                boundarySource = "native_debugger_bpset"
            })
            cpu.debug:go()
            return
        end
        startupFailure("initial_stop", string.format("stopped at %04X instead of reset entry %04X", state.pc, session.resetPc))
        return
    end
    if session.phase == "running" then
        handleStop(state)
    end
end, "periodic")

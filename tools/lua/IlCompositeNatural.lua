local PROTOCOL = "il-composite-natural-v1"

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

if not dbg then startupFailure("no_debugger", "manager.machine.debugger is nil") end
if not cpu or not cpu.debug then startupFailure("no_cpu_debug", "maincpu debug interface is unavailable") end

local mapPath = os.getenv("FML_IL_COMPOSITE_MAP") or "composite-map.lua"
local configPath = os.getenv("FML_IL_COMPOSITE_CONFIG") or "session-config.lua"
local okMap, map = pcall(dofile, mapPath)
if not okMap or type(map) ~= "table" then startupFailure("map", "composite map could not be loaded") end
local okConfig, config = pcall(dofile, configPath)
if not okConfig or type(config) ~= "table" then startupFailure("config", "session config could not be loaded") end

if map.schemaVersion ~= 1 or config.schemaVersion ~= 1 then startupFailure("schema", "map/config schema mismatch") end
if map.protocol ~= PROTOCOL or config.protocol ~= PROTOCOL then startupFailure("protocol", "map/config protocol mismatch") end
if type(config.sessionId) ~= "string" or config.sessionId == "" then startupFailure("session", "session id is missing") end
if type(config.secondsToRun) ~= "number" or config.secondsToRun < 1 or config.secondsToRun > 180 then startupFailure("seconds", "emulated seconds are out of range") end
if type(config.wallTimeoutSeconds) ~= "number" or config.wallTimeoutSeconds < 30 or config.wallTimeoutSeconds > 600 then startupFailure("wall", "wall timeout is out of range") end
if config.inputPolicy ~= "tracked_physical_replay" then startupFailure("input_policy", "input policy is not tracked physical replay") end
if type(config.expectedReplaySha256) ~= "string" or #config.expectedReplaySha256 ~= 64 then startupFailure("input_replay", "replay hash is missing") end
if type(config.expectedInputLuaSha256) ~= "string" or #config.expectedInputLuaSha256 ~= 64 then startupFailure("input_lua", "input Lua hash is missing") end
if not sameHex(map.imageSha256, config.expectedImageSha256) then startupFailure("map_image", "map image differs from the session image") end
if not sameHex(map.originalRomSha256, config.expectedOriginalRomSha256) then startupFailure("map_original", "map original differs from the session original") end
if map.headerAddress ~= 0x1010 then startupFailure("map_header_address", "map header address is not 1010") end
if map.headerValue ~= 0x00F8 then startupFailure("map_header_value", "map header cell is not 00F8") end
if map.bodyStart ~= 0x1012 then startupFailure("map_body_start", "map body start is not 1012") end
if map.bodyEndExclusive ~= 0x1020 then startupFailure("map_body_end", "map body end is not 1020") end
if type(map.nodes) ~= "table" or #map.nodes ~= 5 then startupFailure("map_nodes", "map does not contain five nodes") end
if type(map.phases) ~= "table" or #map.phases ~= 13 then startupFailure("map_phases", "map does not contain thirteen phases") end
if type(map.caller) ~= "table" or map.caller.address ~= 0x9F14 then startupFailure("map_caller", "map caller is not 9F14") end
if map.caller.replacementToken ~= 0x1010 then startupFailure("map_caller_token", "map caller replacement is not 1010") end
if map.caller.savedCursor ~= 0x9F16 then startupFailure("map_saved_cursor", "map saved cursor is not 9F16") end
if map.caller.postReturnToken ~= 0x75A9 then startupFailure("map_post_token", "map post-return token is not 75A9") end

for _, node in ipairs(map.nodes) do
    if type(node.index) ~= "number" or type(node.address) ~= "number" or type(node.token) ~= "number" or type(node.handlerAddress) ~= "number" then
        startupFailure("map_node", "node fields are malformed")
    end
    if readw(node.address) ~= node.token then
        startupFailure("map_node_token", string.format("live token at %04X differs from node token %04X", node.address, node.token))
    end
    if readw(node.token) ~= node.handlerAddress then
        startupFailure("map_handler", string.format("token %04X points at %04X, expected %04X", node.token, readw(node.token), node.handlerAddress))
    end
    for offset, byte in ipairs(node.bytes or {}) do
        if readb(node.address + offset - 1) ~= byte then
            startupFailure("map_node_byte", string.format("live byte at %04X differs from map", node.address + offset - 1))
        end
    end
end

if readw(0x1010) ~= 0x00F8 then startupFailure("header_live", "live header cell at 1010 is not 00F8") end
if readw(0x9F14) ~= 0x1010 then startupFailure("caller_live", "live caller token at 9F14 is not 1010") end
if readw(0x9F16) ~= 0x75A9 then startupFailure("post_live", "live post-return token at 9F16 is not 75A9") end
if readw(0x9ED7) ~= 0x00F8 then startupFailure("original_header", "original 9ED7 header is not 00F8") end
local originalBody = { 0x79, 0x5B, 0xFF, 0x80, 0x78, 0x7E, 0x79, 0x5B, 0xFF, 0x80, 0x7A, 0xAF, 0x79, 0x2F }
for i, byte in ipairs(originalBody) do
    if readb(0x9ED9 + i - 1) ~= byte then startupFailure("original_body", "original 9ED9 body differs from the certified bytes") end
end
for address = 0x1000, 0x100F do
    if readb(address) ~= 0xFF then startupFailure("guard_low", string.format("guard byte at %04X is not FF", address)) end
end
for address = 0x13F0, 0x13FF do
    if readb(address) ~= 0xFF then startupFailure("guard_high", string.format("guard byte at %04X is not FF", address)) end
end

local function tokenAddressFor(phase)
    if phase.name == "header-trampoline-entry" then return map.headerAddress end
    if phase.handlerAddress and phase.handlerAddress > 0 and phase.pc == phase.handlerAddress then return (phase.y - 2) & 0xFFFF end
    return phase.y
end

local function effectiveToken(phase)
    if phase.replacementToken and phase.replacementToken > 0 then return phase.replacementToken end
    return phase.token
end

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

local function stackWords(addr, count)
    local out = {}
    for i = 0, count - 1 do out[i] = readw(addr + i * 2) end
    return out
end

local function stateFields(state, fields)
    fields.pc = hex16(state.pc)
    fields.curpc = hex16(state.curpc)
    fields.a = hex8(state.a)
    fields.b = hex8(state.b)
    fields.d = hex16(state.d)
    fields.cc = hex8(state.cc)
    fields.x = hex16(state.x)
    fields.y = hex16(state.y)
    fields.u = hex16(state.u)
    fields.s = hex16(state.s)
    fields.emulatedTime = string.format("%.9f", state.time)
    local d = stackWords(state.u, 4)
    local c = stackWords(state.s, 4)
    for i = 0, 3 do fields["dataStack" .. i] = hex16(d[i]) end
    for i = 0, 3 do fields["controlStack" .. i] = hex16(c[i]) end
    pcall(function()
        fields.aux2 = hex8(m.ioport.ports[":AUX2"]:read())
        fields.black2 = hex8(m.ioport.ports[":BLACK2"]:read())
        fields.inputPolicy = config.inputPolicy
    end)
end

local session = {
    phase = "starting",
    index = 0,
    observed = {},
    startWall = os.time(),
    stopping = false,
    readyWritten = false,
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
    f:write("header=1010\n")
    f:write("body=1012..1020\n")
    f:write("caller=9F14\n")
    f:write("hold=" .. hex16(session.resetPc) .. "\n")
    f:close()
    os.rename("ready.tmp", "ready.txt")
    session.readyWritten = true
end

local function summaryFields()
    local first = session.observed[1]
    local last = session.observed[#session.observed]
    local fields = {
        observed = tostring(#session.observed),
        expected = tostring(#map.phases),
        sessionId = config.sessionId,
        inputPolicy = config.inputPolicy,
        replaySha256 = config.expectedReplaySha256,
        inputLuaSha256 = config.expectedInputLuaSha256,
        buildSha256 = config.expectedImageSha256,
        mapSha256 = config.expectedSourceMapSha256,
        mameSha256 = config.expectedMameSha256,
        luaSha256 = config.expectedLuaSha256
    }
    if first then
        fields.callerU = first.u
        fields.callerS = first.s
        fields.inputWord = first.dataStack0
    end
    if last then
        fields.lastPhase = last.phase
    end
    local returned = first and last and (#session.observed == #map.phases) and last.phase == "post-return-prefetch"
    if returned then
        fields.resultWord = last.dataStack0
        fields.postY = last.y
        fields.postS = last.s
        fields.postToken = last.token
        fields.netU = hex16((last.uValue - first.uValue) & 0xFFFF)
        fields.netS = hex16((last.sValue - first.sValue) & 0xFFFF)
    end
    return fields
end

local function finish(reason)
    if session.stopping then return end
    session.stopping = true
    session.phase = "stopped"
    local state = snapshot()
    local complete = (#session.observed == #map.phases)
    local fields = summaryFields()
    fields.reason = tostring(reason)
    fields.complete = complete and "true" or "false"
    fields.emulatedTime = string.format("%.9f", state.time)
    fields.wallSeconds = tostring(os.time() - session.startWall)
    logEvent("session_complete", fields)
    local f = io.open("session-complete.txt", "w")
    if f then
        f:write("reason=" .. tostring(reason) .. "\n")
        f:write("observed=" .. tostring(#session.observed) .. "\n")
        f:write("expected=" .. tostring(#map.phases) .. "\n")
        f:write("complete=" .. tostring(complete) .. "\n")
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
        observed = tostring(#session.observed),
        expected = tostring(#map.phases)
    })
    finish("protocol_failure")
end

local function checkBudget()
    if session.stopping then return true end
    local wall = os.time() - session.startWall
    local emulated = m.time:as_double()
    if wall >= config.wallTimeoutSeconds then
        logEvent("session_timeout", { kind = "wall", wallSeconds = tostring(wall), emulatedTime = string.format("%.9f", emulated), observed = tostring(#session.observed) })
        finish("wall_timeout")
        return true
    end
    if emulated >= config.secondsToRun then
        logEvent("session_timeout", { kind = "emulated", wallSeconds = tostring(wall), emulatedTime = string.format("%.9f", emulated), observed = tostring(#session.observed) })
        finish("emulated_budget")
        return true
    end
    return false
end

local function setObservationBreakpoints()
    for _, phase in ipairs(map.phases) do
        local terms = {}
        if phase.x and phase.x >= 0 then terms[#terms + 1] = string.format("x==0x%x", phase.x) end
        terms[#terms + 1] = string.format("y==0x%x", phase.y)
        local condition = table.concat(terms, " && ")
        local ok, bp = pcall(function() return cpu.debug:bpset(phase.pc, condition, "") end)
        if not ok then startupFailure("breakpoint", phase.name .. ": " .. tostring(bp)) end
    end
end

local function handlePhase(state)
    local expected = map.phases[session.index + 1]
    if not expected then protocolFailure("unexpected_phase", "a stop arrived after all phases were observed"); return end
    if state.pc ~= expected.pc then protocolFailure("phase_pc", string.format("%s PC %04X is not %04X", expected.name, state.pc, expected.pc)); return end
    if expected.x and expected.x >= 0 and state.x ~= expected.x then protocolFailure("phase_x", string.format("%s X %04X is not %04X", expected.name, state.x, expected.x)); return end
    if state.y ~= expected.y then protocolFailure("phase_y", string.format("%s Y %04X is not %04X", expected.name, state.y, expected.y)); return end
    local tokenAddress = tokenAddressFor(expected)
    local token = readw(tokenAddress)
    local wantedToken = effectiveToken(expected)
    if token ~= wantedToken then protocolFailure("phase_token", string.format("%s token %04X at %04X is not %04X", expected.name, token, tokenAddress, wantedToken)); return end
    if expected.handlerAddress and expected.handlerAddress > 0 and expected.pc == expected.handlerAddress and state.pc ~= expected.handlerAddress then
        protocolFailure("phase_handler", string.format("%s handler PC %04X is not %04X", expected.name, state.pc, expected.handlerAddress)); return
    end
    local inlineAddress = expected.inlineOperandAddress or -1
    local inlineValue = expected.inlineOperandValue or -1
    if inlineAddress >= 0 then
        local live = readw(inlineAddress)
        if live ~= inlineValue then protocolFailure("phase_inline", string.format("%s inline operand %04X at %04X is not %04X", expected.name, live, inlineAddress, inlineValue)); return end
    end
    local savedCursor = -1
    if expected.name == "body-prefetch-0" or expected.name == "return-handler" then
        local live = readw(state.s)
        if live ~= 0x9F16 then protocolFailure("phase_saved_cursor", string.format("%s saved cursor %04X is not 9F16", expected.name, live)); return end
        savedCursor = live
    end
    local fields = {
        phase = expected.name,
        phaseIndex = tostring(session.index),
        tokenAddress = hex16(tokenAddress),
        token = hex16(token),
        handlerAddress = expected.handlerAddress and expected.handlerAddress > 0 and hex16(expected.handlerAddress) or "",
        inlineOperandAddress = inlineAddress >= 0 and hex16(inlineAddress) or "",
        inlineOperandValue = inlineValue >= 0 and hex16(inlineValue) or "",
        savedCursor = savedCursor >= 0 and hex16(savedCursor) or "",
        savedCursorSource = savedCursor >= 0 and "live_control_stack_top" or "",
        buildSha256 = config.expectedImageSha256,
        mapSha256 = config.expectedSourceMapSha256,
        mameSha256 = config.expectedMameSha256,
        luaSha256 = config.expectedLuaSha256,
        sessionId = config.sessionId
    }
    stateFields(state, fields)
    logEvent("phase", fields)
    local record = {
        phase = expected.name,
        pc = hex16(state.pc),
        x = hex16(state.x),
        y = hex16(state.y),
        u = hex16(state.u),
        s = hex16(state.s),
        uValue = state.u,
        sValue = state.s,
        token = hex16(token),
        dataStack0 = hex16(readw(state.u)),
        dataStack1 = hex16(readw((state.u + 2) & 0xFFFF)),
        dataStack2 = hex16(readw((state.u + 4) & 0xFFFF)),
        dataStack3 = hex16(readw((state.u + 6) & 0xFFFF)),
        controlStack0 = hex16(readw(state.s)),
        controlStack1 = hex16(readw((state.s + 2) & 0xFFFF)),
        controlStack2 = hex16(readw((state.s + 4) & 0xFFFF)),
        controlStack3 = hex16(readw((state.s + 6) & 0xFFFF))
    }
    session.observed[#session.observed + 1] = record
    session.index = session.index + 1
    if session.index == #map.phases then
        finish("composite_call_complete")
    end
end

local function handleStop(state)
    local key = string.format("%04X:%04X:%04X:%04X:%04X:%04X:%.9f", state.pc, state.curpc, state.x, state.y, state.u, state.s, state.time)
    if session.lastStopKey == key then
        pcall(function() cpu.debug:go() end)
        return
    end
    session.lastStopKey = key
    handlePhase(state)
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
                sessionId = config.sessionId,
                imageSha256 = config.expectedImageSha256,
                originalRomSha256 = config.expectedOriginalRomSha256,
                sourceMapSha256 = config.expectedSourceMapSha256,
                buildReportSha256 = config.expectedBuildReportSha256,
                luaSha256 = config.expectedLuaSha256,
                mameSha256 = config.expectedMameSha256,
                resetPc = hex16(session.resetPc),
                secondsToRun = tostring(config.secondsToRun),
                wallTimeoutSeconds = tostring(config.wallTimeoutSeconds),
                headerAddress = hex16(map.headerAddress),
                headerValue = hex16(map.headerValue),
                bodyStart = hex16(map.bodyStart),
                bodyEndExclusive = hex16(map.bodyEndExclusive),
                callerAddress = hex16(map.caller.address),
                callerToken = hex16(map.caller.replacementToken),
                inputPolicy = config.inputPolicy,
                replaySha256 = config.expectedReplaySha256,
                inputLuaSha256 = config.expectedInputLuaSha256,
                debuggerType = type(dbg),
                cpuDebugType = type(cpu.debug),
                luaVersion = tostring(_VERSION),
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

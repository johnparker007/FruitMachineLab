local PROTOCOL = "il-native-primitive-natural-v1"

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

local mapPath = os.getenv("FML_IL_NATIVE_PRIMITIVE_MAP") or "native-primitive-map.lua"
local configPath = os.getenv("FML_IL_NATIVE_PRIMITIVE_CONFIG") or "session-config.lua"
local okMap, map = pcall(dofile, mapPath)
if not okMap or type(map) ~= "table" then startupFailure("map", "native primitive map could not be loaded") end
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
if map.tokenAddress ~= 0x1010 then startupFailure("map_token_address", "map token address is not 1010") end
if map.tokenValue ~= 0x1012 then startupFailure("map_token_value", "map token value is not 1012") end
if map.tokenValue == 0x00F8 then startupFailure("map_composite_header", "map token cell is the old composite 00F8 header") end
if map.handlerStart ~= 0x1012 then startupFailure("map_handler_start", "map handler start is not 1012") end
if map.handlerEndExclusive ~= 0x101B then startupFailure("map_handler_end", "map handler end is not 101B") end
if map.callerAddress ~= 0x9F14 then startupFailure("map_caller", "map caller is not 9F14") end
if map.callerToken ~= 0x1010 then startupFailure("map_caller_token", "map caller token is not 1010") end
if map.successorAddress ~= 0x9F16 then startupFailure("map_successor", "map successor is not 9F16") end
if map.successorToken ~= 0x75A9 then startupFailure("map_successor_token", "map successor token is not 75A9") end
if map.controlTop ~= 0x9F3F then startupFailure("map_control_top", "map control top is not 9F3F") end
if type(map.phases) ~= "table" or #map.phases ~= 12 then startupFailure("map_phases", "map does not contain twelve phases") end

local handlerBytes = { 0xEC, 0xC4, 0xC3, 0x80, 0x00, 0xED, 0xC4, 0x0E, 0xFC }
if type(map.handlerBytes) ~= "table" or #map.handlerBytes ~= #handlerBytes then startupFailure("map_handler_bytes", "map handler bytes are malformed") end
for i, byte in ipairs(handlerBytes) do
    if map.handlerBytes[i] ~= byte then startupFailure("map_handler_bytes", "map handler byte table differs from the direct native handler") end
end
for i, byte in ipairs(handlerBytes) do
    if readb(0x1012 + i - 1) ~= byte then startupFailure("handler_live", string.format("live handler byte at %04X differs from the direct native handler", 0x1012 + i - 1)) end
    if byte == 0x34 or byte == 0x35 then startupFailure("handler_frame", "handler contains PSHS or PULS") end
end
local handlerHex = ""
for i, byte in ipairs(handlerBytes) do handlerHex = handlerHex .. hex8(byte) end
if handlerHex:find("792F", 1, true) then startupFailure("handler_return", "handler contains the 792F return token") end
if readw(0x1010) ~= 0x1012 then startupFailure("header_live", "live token cell at 1010 is not 1012") end
if readw(0x1010) == 0x00F8 then startupFailure("header_composite", "live token cell at 1010 is the old composite 00F8 header") end
if readw(0x9F14) ~= 0x1010 then startupFailure("caller_live", "live caller token at 9F14 is not 1010") end
if readw(0x9F16) ~= 0x75A9 then startupFailure("successor_live", "live successor token at 9F16 is not 75A9") end
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
for i, phase in ipairs(map.phases) do
    if type(phase.name) ~= "string" or type(phase.pc) ~= "number" or type(phase.y) ~= "number" then
        startupFailure("map_phase", string.format("phase %d fields are malformed", i - 1))
    end
    if type(phase.u) ~= "number" or type(phase.s) ~= "number" or type(phase.top) ~= "number" then
        startupFailure("map_phase", string.format("phase %s stack fields are malformed", phase.name))
    end
    if type(phase.token) ~= "number" or type(phase.tokenAddress) ~= "number" then
        startupFailure("map_phase", string.format("phase %s token fields are malformed", phase.name))
    end
    if phase.x ~= nil and type(phase.x) ~= "number" then startupFailure("map_phase", string.format("phase %s X is malformed", phase.name)) end
    if phase.d ~= nil and type(phase.d) ~= "number" then startupFailure("map_phase", string.format("phase %s D is malformed", phase.name)) end
    if phase.control0 ~= nil and type(phase.control0) ~= "number" then startupFailure("map_phase", string.format("phase %s control top is malformed", phase.name)) end
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
    f:write("token=1010\n")
    f:write("handler=1012..101B\n")
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
    local returned = first and last and (#session.observed == #map.phases) and last.phase == "9f12-post-return"
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

local function protocolFailure(code, message, expected)
    if session.stopping then return end
    logEvent("protocol_failure", {
        code = tostring(code),
        message = tostring(message),
        expected = expected ~= nil and tostring(expected) or "",
        observed = tostring(#session.observed),
        expectedCount = tostring(#map.phases)
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
        local terms = { string.format("y==0x%x", phase.y) }
        if phase.requireX and phase.x ~= nil then terms[#terms + 1] = string.format("x==0x%x", phase.x) end
        local condition = table.concat(terms, " && ")
        local ok, bp = pcall(function() return cpu.debug:bpset(phase.pc, condition, "") end)
        if not ok then startupFailure("breakpoint", phase.name .. ": " .. tostring(bp)) end
    end
end

local function mismatch(code, phase, field, actual, expected)
    protocolFailure(code, string.format("%s %s is %s, expected %s", phase.name, field, tostring(actual), tostring(expected)), expected)
end

local function handlePhase(state)
    local expected = map.phases[session.index + 1]
    if not expected then protocolFailure("unexpected_phase", "a stop arrived after all phases were observed", ""); return end
    if state.pc ~= expected.pc then mismatch("phase_pc", expected, "PC", hex16(state.pc), hex16(expected.pc)); return end
    if state.y ~= expected.y then mismatch("phase_y", expected, "Y", hex16(state.y), hex16(expected.y)); return end
    if expected.requireX and expected.x ~= nil and state.x ~= expected.x then mismatch("phase_x", expected, "X", hex16(state.x), hex16(expected.x)); return end
    if expected.requireD and expected.d ~= nil and state.d ~= expected.d then mismatch("phase_d", expected, "D", hex16(state.d), hex16(expected.d)); return end
    if state.u ~= expected.u then mismatch("phase_u", expected, "U", hex16(state.u), hex16(expected.u)); return end
    if state.s ~= expected.s then mismatch("phase_s", expected, "S", hex16(state.s), hex16(expected.s)); return end
    local top = readw(state.u)
    if top ~= expected.top then mismatch("phase_top", expected, "top cell", hex16(top), hex16(expected.top)); return end
    local control0 = readw(state.s)
    if expected.control0 ~= nil and control0 ~= expected.control0 then
        mismatch("phase_control", expected, "control stack top", hex16(control0), hex16(expected.control0)); return
    end
    local token = readw(expected.tokenAddress)
    if token ~= expected.token then
        protocolFailure("phase_token", string.format("%s token %s at %s is not %s", expected.name, hex16(token), hex16(expected.tokenAddress), hex16(expected.token)), hex16(expected.token))
        return
    end
    local savedCursor = ""
    if expected.savedCursorFromControl then savedCursor = hex16(control0) end
    local fields = {
        phase = expected.name,
        phaseIndex = tostring(session.index),
        tokenAddress = hex16(expected.tokenAddress),
        token = hex16(token),
        handlerAddress = expected.handlerAddress and hex16(expected.handlerAddress) or "",
        savedCursor = savedCursor,
        savedCursorSource = expected.savedCursorFromControl and "live_control_stack_top" or "",
        controlTopExpected = expected.control0 ~= nil and hex16(expected.control0) or "",
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
        d = hex16(state.d),
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
        finish("native_primitive_complete")
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
                tokenAddress = hex16(map.tokenAddress),
                tokenValue = hex16(map.tokenValue),
                handlerStart = hex16(map.handlerStart),
                handlerEndExclusive = hex16(map.handlerEndExclusive),
                callerAddress = hex16(map.callerAddress),
                callerToken = hex16(map.callerToken),
                successorAddress = hex16(map.successorAddress),
                successorToken = hex16(map.successorToken),
                controlTop = hex16(map.controlTop),
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

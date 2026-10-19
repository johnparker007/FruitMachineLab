local PROTOCOL = "il-larger-replacement-natural-v1"

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

local mapPath = os.getenv("FML_IL_LARGER_REPLACEMENT_MAP") or "larger-replacement-map.lua"
local configPath = os.getenv("FML_IL_LARGER_REPLACEMENT_CONFIG") or "session-config.lua"
local okMap, map = pcall(dofile, mapPath)
if not okMap or type(map) ~= "table" then startupFailure("map", "larger replacement map could not be loaded") end
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
if map.headerValue ~= 0x00F8 then startupFailure("map_header_value", "map header value is not 00F8") end
if map.bodyStart ~= 0x1012 then startupFailure("map_body_start", "map body start is not 1012") end
if map.bodyEndExclusive ~= 0x1026 then startupFailure("map_body_end", "map body end is not 1026") end
if map.callerAddress ~= 0x9F14 then startupFailure("map_caller", "map caller is not 9F14") end
if map.callerToken ~= 0x1010 then startupFailure("map_caller_token", "map caller token is not 1010") end
if map.successorAddress ~= 0x9F16 then startupFailure("map_successor", "map successor is not 9F16") end
if map.successorToken ~= 0x75A9 then startupFailure("map_successor_token", "map successor token is not 75A9") end
if map.controlTop ~= 0x9F3F then startupFailure("map_control_top", "map control top is not 9F3F") end
if map.basePhaseCount ~= 17 then startupFailure("map_base_phases", "map does not declare seventeen base phases") end
if type(map.phases) ~= "table" or #map.phases ~= (map.basePhaseCount + 1) then startupFailure("map_phases", "map does not contain the seventeen map phases plus one optional successor") end
if type(map.handlers) ~= "table" or #map.handlers < 5 then startupFailure("map_handlers", "map handler byte table is missing") end
if type(map.bodyBytes) ~= "table" or #map.bodyBytes ~= 20 then startupFailure("map_body_bytes", "map body byte table is malformed") end
if type(map.originalBodyBytes) ~= "table" or #map.originalBodyBytes ~= 14 then startupFailure("map_original_body", "map original body byte table is malformed") end

local function checkLiveBytes(address, expected, label)
    for i, byte in ipairs(expected) do
        local actual = readb(address + i - 1)
        if actual ~= byte then
            startupFailure(label, string.format("live byte at %04X is %02X, expected %02X", address + i - 1, actual, byte))
        end
    end
end

local function checkWord(address, expected, label)
    local actual = readw(address)
    if actual ~= expected then
        startupFailure(label, string.format("live word at %04X is %04X, expected %04X", address, actual, expected))
    end
end

checkWord(map.headerAddress, map.headerValue, "header_live")
checkWord(map.callerAddress, map.callerToken, "caller_live")
checkWord(map.successorAddress, map.successorToken, "successor_live")
checkWord(map.originalHeaderAddress, map.originalHeaderValue, "original_header_live")
checkLiveBytes(map.bodyStart, map.bodyBytes, "body_live")
checkLiveBytes(map.originalBodyAddress, map.originalBodyBytes, "original_body_live")
for address = map.guardLowStart, map.guardLowEnd do
    if readb(address) ~= 0xFF then startupFailure("guard_low", string.format("guard byte at %04X is not FF", address)) end
end
for address = map.guardHighStart, map.guardHighEnd do
    if readb(address) ~= 0xFF then startupFailure("guard_high", string.format("guard byte at %04X is not FF", address)) end
end
for address = map.unallocatedStart, map.unallocatedEndInclusive do
    if readb(address) ~= 0xFF then startupFailure("unallocated_extension", string.format("unallocated extension byte at %04X is not FF", address)) end
end
for _, handler in ipairs(map.handlers) do
    if type(handler.address) ~= "number" or type(handler.bytes) ~= "table" then startupFailure("handler_table", "handler byte entry is malformed") end
    checkLiveBytes(handler.address, handler.bytes, "handler_live")
end

for index, phase in ipairs(map.phases) do
    if type(phase.name) ~= "string" or phase.name == "" then startupFailure("map_phase", string.format("phase %d name is malformed", index - 1)) end
    if type(phase.pc) ~= "number" or type(phase.y) ~= "number" then startupFailure("map_phase", string.format("phase %s address fields are malformed", phase.name)) end
    if type(phase.u) ~= "number" or type(phase.s) ~= "number" or type(phase.top) ~= "number" then startupFailure("map_phase", string.format("phase %s stack fields are malformed", phase.name)) end
    if type(phase.token) ~= "number" or type(phase.tokenAddress) ~= "number" then startupFailure("map_phase", string.format("phase %s token fields are malformed", phase.name)) end
    if type(phase.control0) ~= "number" then startupFailure("map_phase", string.format("phase %s control field is malformed", phase.name)) end
    if phase.x ~= nil and type(phase.x) ~= "number" then startupFailure("map_phase", string.format("phase %s X is malformed", phase.name)) end
    if phase.d ~= nil and type(phase.d) ~= "number" then startupFailure("map_phase", string.format("phase %s D is malformed", phase.name)) end
    if phase.dataStack1 ~= nil and type(phase.dataStack1) ~= "number" then startupFailure("map_phase", string.format("phase %s dataStack1 is malformed", phase.name)) end
    if phase.inlineOperandAddress ~= nil and type(phase.inlineOperandAddress) ~= "number" then startupFailure("map_phase", string.format("phase %s inline operand address is malformed", phase.name)) end
    if phase.inlineOperandValue ~= nil and type(phase.inlineOperandValue) ~= "number" then startupFailure("map_phase", string.format("phase %s inline operand value is malformed", phase.name)) end
    if phase.handlerAddress ~= nil and type(phase.handlerAddress) ~= "number" then startupFailure("map_phase", string.format("phase %s handler address is malformed", phase.name)) end
    if phase.required == nil then startupFailure("map_phase", string.format("phase %s required flag is missing", phase.name)) end
    if index <= map.basePhaseCount and phase.required ~= true then startupFailure("map_phase", string.format("map phase %s is not required", phase.name)) end
    if index > map.basePhaseCount and phase.required ~= false then startupFailure("map_phase", string.format("optional phase %s is not optional", phase.name)) end
end

-- DP is a required live register. Probe the installed 0.281 CPU state API once;
-- if it is unavailable, preserve the reason and continue honestly rather than
-- fabricating a value.
local dpState = nil
local dpProbe = nil
local function probeDpState()
    local okEntry, entry = pcall(function() return cpu.state["DP"] end)
    if not okEntry or entry == nil then return nil end
    local okValue, value = pcall(function() return entry.value end)
    if not okValue then
        if type(entry) == "number" then
            return { entry = nil, constant = entry, widthBits = nil, widthSource = "state_entry_number" }
        end
        return nil
    end
    if type(value) ~= "number" then return nil end
    local widthBits = nil
    local widthSource = "state_entry_exposes_only_value"
    local probes = {
        { name = "size", source = "state_entry_size_bytes", multiplier = 8 },
        { name = "width", source = "state_entry_width_bits", multiplier = 1 },
        { name = "bits", source = "state_entry_bits", multiplier = 1 }
    }
    for _, probe in ipairs(probes) do
        local ok, probeValue = pcall(function() return entry[probe.name] end)
        if ok and type(probeValue) == "number" and probeValue > 0 then
            widthBits = probeValue * probe.multiplier
            widthSource = probe.source
            break
        end
    end
    if widthBits == nil then
        local okMask, mask = pcall(function() return entry.mask end)
        if okMask and type(mask) == "number" and mask > 0 then
            local bits = 0
            local remaining = mask
            while remaining > 0 do bits = bits + 1; remaining = remaining >> 1 end
            widthBits = bits
            widthSource = "state_entry_mask_bits"
        end
    end
    return { entry = entry, constant = nil, widthBits = widthBits, widthSource = widthSource }
end

local function rawBitLength(value)
    local remaining = math.floor(value)
    if remaining == 0 then return 1 end
    local bits = 0
    while remaining > 0 do bits = bits + 1; remaining = remaining >> 1 end
    return bits
end

local function sampleDp()
    if dpProbe == nil then return nil end
    local raw = nil
    if dpProbe.constant ~= nil then
        raw = dpProbe.constant
    else
        local ok, value = pcall(function() return dpProbe.entry.value end)
        if not ok or type(value) ~= "number" then return nil end
        raw = value
    end
    local widthBits = dpProbe.widthBits
    if widthBits == nil then widthBits = "unknown" end
    return {
        raw = raw,
        normalized = raw & 0xFF,
        widthBits = widthBits,
        widthSource = dpProbe.widthSource,
        rawBitLength = rawBitLength(raw)
    }
end

dpProbe = probeDpState()
local dpUnavailableReason = ""
if dpProbe == nil then
    dpUnavailableReason = "cpu.state DP is not exposed by the installed CPU state API; not measured and not fabricated"
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
        dp = sampleDp(),
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
    if state.dp ~= nil then
        fields.dpAvailable = "true"
        fields.dpRaw = string.format("%.0f", math.floor(state.dp.raw))
        fields.dp = hex8(state.dp.normalized)
        fields.dpWidthBits = tostring(state.dp.widthBits)
        fields.dpWidthSource = tostring(state.dp.widthSource)
        fields.dpNormalizedMask = "00FF"
        fields.dpRawBitLength = tostring(state.dp.rawBitLength)
    else
        fields.dpAvailable = "false"
        fields.dpRaw = ""
        fields.dp = ""
        fields.dpWidthBits = ""
        fields.dpWidthSource = ""
        fields.dpNormalizedMask = ""
        fields.dpRawBitLength = ""
    end
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
    baseObserved = {},
    allObserved = {},
    optionalObserved = false,
    optionalRecord = nil,
    baseComplete = false,
    baseCompleteTime = nil,
    startWall = os.time(),
    stopping = false,
    readyWritten = false,
    lastStopKey = nil,
    resetPc = readw(0xFFFE),
    dpAvailable = (dpProbe ~= nil)
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
    f:write("body=1012..1025\n")
    f:write("caller=9F14\n")
    f:write("successor=9F16\n")
    f:write("basePhases=" .. tostring(map.basePhaseCount) .. "\n")
    f:write("optionalSuccessor=" .. tostring(map.phases[map.basePhaseCount + 1].name) .. "\n")
    f:write("dpAvailable=" .. tostring(session.dpAvailable) .. "\n")
    f:write("hold=" .. hex16(session.resetPc) .. "\n")
    f:close()
    os.rename("ready.tmp", "ready.txt")
    session.readyWritten = true
end

local function summaryFields()
    local first = session.baseObserved[1]
    local last = session.baseObserved[#session.baseObserved]
    local optional = session.optionalRecord
    local fields = {
        observed = tostring(#session.baseObserved),
        expected = tostring(map.basePhaseCount),
        observedTotal = tostring(#session.allObserved),
        baseComplete = session.baseComplete and "true" or "false",
        successorObserved = session.optionalObserved and "true" or "false",
        sessionId = config.sessionId,
        inputPolicy = config.inputPolicy,
        replaySha256 = config.expectedReplaySha256,
        inputLuaSha256 = config.expectedInputLuaSha256,
        buildSha256 = config.expectedImageSha256,
        mapSha256 = config.expectedSourceMapSha256,
        mameSha256 = config.expectedMameSha256,
        luaSha256 = config.expectedLuaSha256,
        dpAvailable = session.dpAvailable and "true" or "false"
    }
    if first then
        fields.callerU = first.u
        fields.callerS = first.s
        fields.inputWord = first.dataStack0
        fields.callerControlTop = first.controlStack0
    end
    if last then
        fields.lastBasePhase = last.phase
        fields.calleeExitWord = last.dataStack0
        fields.postY = last.y
        fields.postS = last.s
        fields.postToken = last.token
        fields.netU = hex16((last.uValue - first.uValue) & 0xFFFF)
        fields.netS = hex16((last.sValue - first.sValue) & 0xFFFF)
        if last.dpAvailable == "true" then fields.dp = last.dp else fields.dp = "" end
    end
    if optional then
        fields.lastPhase = optional.phase
        fields.resultWord = optional.dataStack0
        fields.optionalY = optional.y
        fields.optionalS = optional.s
        fields.optionalToken = optional.token
        if optional.dpAvailable == "true" then fields.optionalDp = optional.dp else fields.optionalDp = "" end
    elseif last then
        fields.lastPhase = last.phase
        fields.resultWord = ""
    end
    return fields
end

local function finish(reason)
    if session.stopping then return end
    session.stopping = true
    session.phase = "stopped"
    local state = snapshot()
    local fields = summaryFields()
    fields.reason = tostring(reason)
    fields.complete = session.baseComplete and "true" or "false"
    fields.emulatedTime = string.format("%.9f", state.time)
    fields.wallSeconds = tostring(os.time() - session.startWall)
    logEvent("session_complete", fields)
    local f = io.open("session-complete.txt", "w")
    if f then
        f:write("reason=" .. tostring(reason) .. "\n")
        f:write("observed=" .. tostring(#session.baseObserved) .. "\n")
        f:write("expected=" .. tostring(map.basePhaseCount) .. "\n")
        f:write("observedTotal=" .. tostring(#session.allObserved) .. "\n")
        f:write("baseComplete=" .. tostring(session.baseComplete) .. "\n")
        f:write("successorObserved=" .. tostring(session.optionalObserved) .. "\n")
        f:write("calleeExitWord=" .. tostring(fields.calleeExitWord or "") .. "\n")
        f:write("resultWord=" .. tostring(fields.resultWord or "") .. "\n")
        f:write("dpAvailable=" .. tostring(session.dpAvailable) .. "\n")
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
        observed = tostring(#session.allObserved),
        expectedCount = tostring(map.basePhaseCount)
    })
    finish("protocol_failure")
end

local function checkBudget()
    if session.stopping then return true end
    local wall = os.time() - session.startWall
    local emulated = m.time:as_double()
    if wall >= config.wallTimeoutSeconds then
        logEvent("session_timeout", { kind = "wall", wallSeconds = tostring(wall), emulatedTime = string.format("%.9f", emulated), observed = tostring(#session.allObserved) })
        finish("wall_timeout")
        return true
    end
    if session.baseComplete and not session.optionalObserved and session.baseCompleteTime ~= nil and emulated >= (session.baseCompleteTime + 1.0) then
        finish("larger_replacement_complete_without_successor")
        return true
    end
    if emulated >= config.secondsToRun then
        logEvent("session_timeout", { kind = "emulated", wallSeconds = tostring(wall), emulatedTime = string.format("%.9f", emulated), observed = tostring(#session.allObserved) })
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
    if expected.required == false and not session.baseComplete then
        protocolFailure("optional_before_base", "the optional successor arrived before the base phases completed", "")
        return
    end
    if state.pc ~= expected.pc then mismatch("phase_pc", expected, "PC", hex16(state.pc), hex16(expected.pc)); return end
    if state.y ~= expected.y then mismatch("phase_y", expected, "Y", hex16(state.y), hex16(expected.y)); return end
    if expected.requireX and expected.x ~= nil and state.x ~= expected.x then mismatch("phase_x", expected, "X", hex16(state.x), hex16(expected.x)); return end
    if expected.requireD and expected.d ~= nil and state.d ~= expected.d then mismatch("phase_d", expected, "D", hex16(state.d), hex16(expected.d)); return end
    if state.u ~= expected.u then mismatch("phase_u", expected, "U", hex16(state.u), hex16(expected.u)); return end
    if state.s ~= expected.s then mismatch("phase_s", expected, "S", hex16(state.s), hex16(expected.s)); return end
    local top = readw(state.u)
    if top ~= expected.top then mismatch("phase_top", expected, "top cell", hex16(top), hex16(expected.top)); return end
    if expected.dataStack1 ~= nil then
        local nextCell = readw((state.u + 2) & 0xFFFF)
        if nextCell ~= expected.dataStack1 then mismatch("phase_data_stack1", expected, "second data cell", hex16(nextCell), hex16(expected.dataStack1)); return end
    end
    local control0 = readw(state.s)
    if control0 ~= expected.control0 then
        mismatch("phase_control", expected, "control stack top", hex16(control0), hex16(expected.control0)); return
    end
    local token = readw(expected.tokenAddress)
    if token ~= expected.token then
        protocolFailure("phase_token", string.format("%s token %s at %s is not %s", expected.name, hex16(token), hex16(expected.tokenAddress), hex16(expected.token)), hex16(expected.token))
        return
    end
    local inlineOperand = ""
    if expected.inlineOperandAddress ~= nil then
        local operand = readw(expected.inlineOperandAddress)
        if operand ~= expected.inlineOperandValue then
            protocolFailure("phase_inline_operand", string.format("%s inline operand %s at %s is not %s", expected.name, hex16(operand), hex16(expected.inlineOperandAddress), hex16(expected.inlineOperandValue)), hex16(expected.inlineOperandValue))
            return
        end
        inlineOperand = hex16(operand)
    end
    if expected.dpAvailable ~= nil and state.dp == nil then
        protocolFailure("dp_unavailable_phase", string.format("%s could not sample cpu.state DP", expected.name), "live DP")
        return
    end
    local savedCursor = ""
    local savedCursorSource = ""
    if expected.savedCursorFromControl then
        savedCursor = hex16(control0)
        savedCursorSource = "live_control_stack_top"
    end
    local fields = {
        phase = expected.name,
        phaseIndex = tostring(session.index),
        phaseClass = expected.required and "map_static_phase" or "optional_post_successor_contract",
        required = expected.required and "true" or "false",
        tokenAddress = hex16(expected.tokenAddress),
        token = hex16(token),
        handlerAddress = expected.handlerAddress and hex16(expected.handlerAddress) or "",
        inlineOperandAddress = expected.inlineOperandAddress and hex16(expected.inlineOperandAddress) or "",
        inlineOperand = inlineOperand,
        savedCursor = savedCursor,
        savedCursorSource = savedCursorSource,
        controlTopExpected = hex16(expected.control0),
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
        phaseClass = expected.required and "map_static_phase" or "optional_post_successor_contract",
        required = expected.required,
        pc = hex16(state.pc),
        curpc = hex16(state.curpc),
        x = hex16(state.x),
        y = hex16(state.y),
        u = hex16(state.u),
        s = hex16(state.s),
        uValue = state.u,
        sValue = state.s,
        a = hex8(state.a),
        b = hex8(state.b),
        d = hex16(state.d),
        cc = hex8(state.cc),
        dpAvailable = state.dp ~= nil and "true" or "false",
        dpRaw = state.dp ~= nil and string.format("%.0f", math.floor(state.dp.raw)) or "",
        dp = state.dp ~= nil and hex8(state.dp.normalized) or "",
        dpWidthBits = state.dp ~= nil and tostring(state.dp.widthBits) or "",
        dpWidthSource = state.dp ~= nil and tostring(state.dp.widthSource) or "",
        token = hex16(token),
        tokenAddress = hex16(expected.tokenAddress),
        inlineOperandAddress = expected.inlineOperandAddress and hex16(expected.inlineOperandAddress) or "",
        inlineOperand = inlineOperand,
        dataStack0 = hex16(readw(state.u)),
        dataStack1 = hex16(readw((state.u + 2) & 0xFFFF)),
        dataStack2 = hex16(readw((state.u + 4) & 0xFFFF)),
        dataStack3 = hex16(readw((state.u + 6) & 0xFFFF)),
        controlStack0 = hex16(readw(state.s)),
        controlStack1 = hex16(readw((state.s + 2) & 0xFFFF)),
        controlStack2 = hex16(readw((state.s + 4) & 0xFFFF)),
        controlStack3 = hex16(readw((state.s + 6) & 0xFFFF)),
        savedCursor = savedCursor,
        savedCursorSource = savedCursorSource,
        emulatedTime = string.format("%.9f", state.time)
    }
    session.allObserved[#session.allObserved + 1] = record
    session.index = session.index + 1
    if expected.required then
        session.baseObserved[#session.baseObserved + 1] = record
        if session.index == map.basePhaseCount then
            session.baseComplete = true
            session.baseCompleteTime = state.time
        end
    else
        session.optionalObserved = true
        session.optionalRecord = record
        finish("larger_replacement_complete_with_successor")
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
                callerAddress = hex16(map.callerAddress),
                callerToken = hex16(map.callerToken),
                successorAddress = hex16(map.successorAddress),
                successorToken = hex16(map.successorToken),
                controlTop = hex16(map.controlTop),
                basePhaseCount = tostring(map.basePhaseCount),
                optionalSuccessor = map.phases[map.basePhaseCount + 1].name,
                dpAvailable = session.dpAvailable and "true" or "false",
                dpUnavailableReason = dpUnavailableReason,
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

local PROTOCOL = "il-lamp-clear-natural-v1"

local m = manager.machine
local cpu = m.devices[":maincpu"]
local mem = cpu.spaces["program"]
local dbg = m.debugger

local function hex16(v) return string.format("%04X", v & 0xFFFF) end
local function hex8(v) return string.format("%02X", v & 0xFF) end
local function oom(v)
    if type(v) ~= "number" then return false end
    return v >= 0x0800 and v <= 0x08FF
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

local function byteList(values)
    local parts = {}
    for i = 1, #values do parts[i] = hex8(values[i]) end
    return table.concat(parts, " ")
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

local mapPath = os.getenv("FML_IL_LAMP_CLEAR_MAP") or "lamp-clear-natural-map.lua"
local configPath = os.getenv("FML_IL_LAMP_CLEAR_CONFIG") or "session-config.lua"
local okMap, map = pcall(dofile, mapPath)
if not okMap or type(map) ~= "table" then startupFailure("map", "lamp natural map could not be loaded") end
local okConfig, config = pcall(dofile, configPath)
if not okConfig or type(config) ~= "table" then startupFailure("config", "session config could not be loaded") end

if map.schemaVersion ~= 1 or config.schemaVersion ~= 1 then startupFailure("schema", "map/config schema mismatch") end
if map.protocol ~= PROTOCOL or config.protocol ~= PROTOCOL then startupFailure("protocol", "map/config protocol mismatch") end
if type(config.sessionId) ~= "string" or config.sessionId == "" then startupFailure("session", "session id is missing") end
if type(config.secondsToRun) ~= "number" or config.secondsToRun < 1 or config.secondsToRun > 180 then startupFailure("seconds", "emulated seconds are out of range") end
if type(config.wallTimeoutSeconds) ~= "number" or config.wallTimeoutSeconds < 60 or config.wallTimeoutSeconds > 1800 then startupFailure("wall", "wall timeout is out of range") end
if config.inputPolicy ~= "tracked_physical_replay" then startupFailure("input_policy", "input policy is not tracked physical replay") end
if type(config.expectedReplaySha256) ~= "string" or #config.expectedReplaySha256 ~= 64 then startupFailure("input_replay", "replay hash is missing") end
if type(config.expectedInputLuaSha256) ~= "string" or #config.expectedInputLuaSha256 ~= 64 then startupFailure("input_lua", "input Lua hash is missing") end

local function sameHex(a, b)
    return type(a) == "string" and type(b) == "string" and a:upper() == b:upper()
end
if not sameHex(map.imageSha256, config.expectedImageSha256) then startupFailure("map_image", "map image differs from the session image") end
if not sameHex(map.originalRomSha256, config.expectedOriginalRomSha256) then startupFailure("map_original", "map original differs from the session original") end
if not sameHex(map.sourceMapSha256, config.expectedSourceMapSha256) then startupFailure("map_source", "map source hash differs from the session map") end
if not sameHex(map.buildReportSha256, config.expectedBuildReportSha256) then startupFailure("map_report", "map build report differs from the session report") end
if not sameHex(map.luaSha256, config.expectedLuaSha256) then startupFailure("map_lua", "map Lua identity differs from the session Lua") end

if type(map.phases) ~= "table" or #map.phases ~= 43 then startupFailure("map_phases", "map does not contain exactly forty-three VM phases") end
if type(map.boundaries) ~= "table" or #map.boundaries ~= 14 then startupFailure("map_boundaries", "map does not contain exactly fourteen reviewed runtime boundary records") end
if type(map.safeRam) ~= "table" or #map.safeRam == 0 then startupFailure("map_safe_ram", "map safe RAM allowlist is missing") end
if type(map.romRanges) ~= "table" or #map.romRanges == 0 then startupFailure("map_rom_ranges", "map ROM allowlist is missing") end
if type(map.frameBank) ~= "table" or map.frameBank.start ~= 0x0100 or map.frameBank.endInclusive ~= 0x013F then startupFailure("map_frame", "map frame bank is not 0100..013F") end
if map.frameBase ~= 0x0100 then startupFailure("map_frame_base", "map frame base is not the dynamic 0100 base") end
if map.expectedPatternHex ~= "80" then startupFailure("map_pattern", "map does not bind the clear pattern 80") end
if map.expectedLogicalIdHex ~= "78" then startupFailure("map_logical_id", "map does not bind the clear logical id 78") end
if map.expectedMaskHex ~= "01" then startupFailure("map_mask", "map does not bind the clear mask 01") end
if map.clearAlgebra ~= "after = before & ~mask" then startupFailure("map_clear_algebra", "map does not bind the reviewed clear algebra") end

local function inRanges(addr, ranges)
    for _, r in ipairs(ranges) do
        if addr >= r.start and addr <= r.endInclusive then return true end
    end
    return false
end

-- Central read boundary. No generic mem read is used anywhere else. Every RAM
-- or ROM access must fall inside an explicit allowlist and outside active I/O.
local function readRam8(addr)
    addr = addr & 0xFFFF
    if oom(addr) then startupFailure("io_read_forbidden", string.format("attempted active I/O read at %04X", addr)) end
    if not inRanges(addr, map.safeRam) then startupFailure("ram_read_forbidden", string.format("RAM address %04X is outside the strict allowlist", addr)) end
    return mem:read_u8(addr)
end

local function readRam16(addr)
    addr = addr & 0xFFFF
    if not inRanges(addr, map.safeRam) or not inRanges((addr + 1) & 0xFFFF, map.safeRam) then
        startupFailure("ram_read_forbidden", string.format("RAM word %04X crosses the strict allowlist", addr))
    end
    return (readRam8(addr) << 8) | readRam8((addr + 1) & 0xFFFF)
end

local function readRom8(addr)
    addr = addr & 0xFFFF
    if oom(addr) then startupFailure("io_read_forbidden", string.format("attempted active I/O read at %04X", addr)) end
    if not inRanges(addr, map.romRanges) then startupFailure("rom_read_forbidden", string.format("ROM address %04X is outside the strict allowlist", addr)) end
    return mem:read_u8(addr)
end

local function readRom16(addr)
    addr = addr & 0xFFFF
    if not inRanges(addr, map.romRanges) or not inRanges((addr + 1) & 0xFFFF, map.romRanges) then
        startupFailure("rom_read_forbidden", string.format("ROM word %04X crosses the strict allowlist", addr))
    end
    return (readRom8(addr) << 8) | readRom8((addr + 1) & 0xFFFF)
end

local function checkRomBytes(address, hexText, label)
    local count = #hexText // 2
    for i = 0, count - 1 do
        local expected = tonumber(hexText:sub(i * 2 + 1, i * 2 + 2), 16)
        local actual = readRom8(address + i)
        if actual ~= expected then
            startupFailure(label, string.format("live ROM byte at %04X is %02X, expected %02X", (address + i) & 0xFFFF, actual, expected))
        end
    end
end

local function checkRomWord(address, expected, label)
    local actual = readRom16(address)
    if actual ~= expected then
        startupFailure(label, string.format("live ROM word at %04X is %04X, expected %04X", address & 0xFFFF, actual, expected))
    end
end

-- Frozen-image preflight inside the emulator, using only allowlisted ROM reads.
checkRomWord(map.headerAddress, map.headerValue, "header_live")
checkRomWord(map.callerAddress, map.callerLiveToken, "caller_live")
checkRomWord(map.successorAddress, map.successorToken, "successor_live")
checkRomBytes(map.bodyStart, map.bodyHex, "body_live")
checkRomBytes(map.originalDefinitionAddress, map.originalDefinitionHex, "original_definition_live")
checkRomBytes(map.sharedCallAddress, map.sharedCallHex, "shared_call_live")
checkRomBytes(map.sharedHandlerAddress, map.sharedHandlerHex, "shared_handler_live")
checkRomBytes(map.sharedBodyAddress, map.sharedBodyHex, "shared_body_live")
checkRomBytes(map.trampolineAddress, map.trampolineHex, "trampoline_live")
checkRomBytes(map.bridgeCellAddress, map.bridgeCellHex, "bridge_cell_live")
checkRomBytes(map.bridgeEntryAddress, map.bridgeEntryHex, "bridge_entry_live")
checkRomBytes(map.bridgeContinuationAddress, map.bridgeContinuationHex, "bridge_continuation_live")
checkRomBytes(map.nativeServiceAddress, map.nativeServiceHex, "native_service_live")
checkRomBytes(map.byteLiteralCellAddress, map.byteLiteralCellHex, "byte_literal_cell_live")
checkRomBytes(map.lampTableAddress, map.lampTableHex, "lamp_table_live")
for address = map.guardLowStart, map.guardLowEnd do
    if readRom8(address) ~= 0xFF then startupFailure("guard_low", string.format("guard byte at %04X is not FF", address & 0xFFFF)) end
end
for address = map.guardHighStart, map.guardHighEnd do
    if readRom8(address) ~= 0xFF then startupFailure("guard_high", string.format("guard byte at %04X is not FF", address & 0xFFFF)) end
end
for address = map.unallocatedStart, map.unallocatedEndInclusive do
    if readRom8(address) ~= 0xFF then startupFailure("unallocated_extension", string.format("unallocated extension byte at %04X is not FF", address & 0xFFFF)) end
end

-- DP is a required live register. Probe the installed 0.281 CPU state API once;
-- if it is unavailable, preserve the reason instead of fabricating a value.
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
    for i = 0, count - 1 do out[i] = readRam16((addr + i * 2) & 0xFFFF) end
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
end

local function frameSnapshot()
    local out = {}
    for address = map.frameBank.start, map.frameBank.endInclusive do
        out[#out + 1] = readRam8(address)
    end
    return out
end

if type(map.stages) ~= "table" or #map.stages == 0 then startupFailure("map_stages", "ordered stage plan is missing") end
if type(map.nativeFrame) ~= "table" or type(map.nativeFrame.steps) ~= "table" then startupFailure("map_native_frame", "native frame model is missing") end

for _, boundary in ipairs(map.boundaries) do
    if type(boundary.u) ~= "number" or type(boundary.s) ~= "number" then
        startupFailure("boundary_schema", "boundary U/S missing: " .. tostring(boundary.id))
    end
end

local phaseByName = {}
for _, phase in ipairs(map.phases) do phaseByName[phase.name] = phase end
local boundaryById = {}
for _, boundary in ipairs(map.boundaries) do boundaryById[boundary.id] = boundary end

local session = {
    phase = "starting",
    stageIndex = 1,
    physicalStops = 0,
    phaseCount = 0,
    boundaryCount = 0,
    skippedCount = 0,
    skippedBoundaries = {},
    stopRecords = {},
    phaseRecords = {},
    boundaryRecords = {},
    stopping = false,
    readyWritten = false,
    startWall = os.time(),
    lastStopTime = -1,
    processedStopKeys = {},
    entryA = nil,
    entryB = nil,
    entryX = nil,
    entryS = nil,
    maskValue = nil,
    ccAt49D0 = nil,
    f1Entry = nil,
    f1Exit = nil,
    response0803 = nil,
    column = nil,
    savedMask = nil,
    savedLogicalIndex = nil,
    expectedLogicalIndex = tonumber(map.expectedLogicalIdHex, 16),
    expectedPattern = tonumber(map.expectedPatternHex, 16),
    expectedMask = tonumber(map.expectedMaskHex, 16),
    clearTransitions = 0,
    frameBefore = nil,
    frameFinalNative = nil,
    frameAfter = nil,
    pendingWrites = {},
    resetPc = readRom16(0xFFFE),
    dpAvailable = (dpProbe ~= nil),
    armedStage = nil,
    armedPc = nil,
    armedCondition = nil
}

local function identityFields()
    return {
        sessionId = config.sessionId,
        buildSha256 = config.expectedImageSha256,
        originalRomSha256 = config.expectedOriginalRomSha256,
        sourceMapSha256 = config.expectedSourceMapSha256,
        buildReportSha256 = config.expectedBuildReportSha256,
        luaSha256 = config.expectedLuaSha256,
        mameSha256 = config.expectedMameSha256,
        replaySha256 = config.expectedReplaySha256,
        inputLuaSha256 = config.expectedInputLuaSha256
    }
end

local function copyFields(fields)
    local out = {}
    for k, v in pairs(fields) do out[k] = v end
    return out
end

local function writeReady()
    if session.readyWritten then return end
    local stage = map.stages[1]
    local f = io.open("ready.tmp", "w")
    if not f then startupFailure("ready_open", "could not create ready file") end
    f:write("protocol=" .. PROTOCOL .. "\n")
    f:write("session=" .. config.sessionId .. "\n")
    f:write("map=ok\n")
    f:write("exec=" .. tostring(dbg.execution_state) .. "\n")
    f:write("header=1010\n")
    f:write("body=1012..1027\n")
    f:write("caller=9F14\n")
    f:write("successor=9F16\n")
    f:write("phases=43\n")
    f:write("boundaries=14\n")
    f:write("stages=" .. tostring(#map.stages) .. "\n")
    f:write("firstStage=" .. tostring(stage.id) .. "\n")
    f:write("firstPc=" .. hex16(stage.pc) .. "\n")
    f:write("firstCondition=" .. tostring(stage.condition) .. "\n")
    f:write("physicalStops=0\n")
    f:write("dpAvailable=" .. tostring(session.dpAvailable) .. "\n")
    f:write("hold=" .. hex16(session.resetPc) .. "\n")
    f:close()
    os.rename("ready.tmp", "ready.txt")
    session.readyWritten = true
end

local function finish(reason, status)
    if session.stopping then return end
    session.stopping = true
    session.phase = "stopped"
    local state = snapshot()
    local fields = identityFields()
    fields.reason = tostring(reason)
    fields.status = tostring(status or "blocked_incomplete")
    fields.phaseCount = tostring(session.phaseCount)
    fields.expectedPhaseCount = tostring(#map.phases)
    fields.boundaryCount = tostring(session.boundaryCount)
    fields.expectedBoundaryCount = tostring(#map.boundaries)
    fields.skippedBoundaryCount = tostring(session.skippedCount)
    fields.physicalStopCount = tostring(session.physicalStops)
    fields.stageCount = tostring(#map.stages)
    fields.stageIndex = tostring(session.stageIndex)
    fields.armedStage = tostring(session.armedStage or "")
    fields.armedPc = session.armedPc ~= nil and hex16(session.armedPc) or ""
    fields.emulatedTime = string.format("%.9f", state.time)
    fields.wallSeconds = tostring(os.time() - session.startWall)
    fields.column = session.column ~= nil and tostring(session.column) or ""
    fields.response0803 = session.response0803 ~= nil and hex8(session.response0803) or ""
    fields.f1Entry = session.f1Entry ~= nil and hex8(session.f1Entry) or ""
    fields.f1Exit = session.f1Exit ~= nil and hex8(session.f1Exit) or ""
    fields.clearTransitionCount = tostring(session.clearTransitions)
    fields.complete = tostring(session.stageIndex > #map.stages and session.phaseCount == #map.phases)
    logEvent("session_complete", fields)
    local f = io.open("session-complete.txt", "w")
    if f then
        f:write("reason=" .. tostring(reason) .. "\n")
        f:write("status=" .. tostring(status or "blocked_incomplete") .. "\n")
        f:write("phases=" .. tostring(session.phaseCount) .. "/" .. tostring(#map.phases) .. "\n")
        f:write("boundaries=" .. tostring(session.boundaryCount) .. "/" .. tostring(#map.boundaries) .. "\n")
        f:write("skippedBoundaries=" .. tostring(session.skippedCount) .. "\n")
        f:write("physicalStops=" .. tostring(session.physicalStops) .. "\n")
        f:write("stages=" .. tostring(session.stageIndex - 1) .. "/" .. tostring(#map.stages) .. "\n")
        f:write("emulatedTime=" .. string.format("%.9f", state.time) .. "\n")
        f:close()
    end
    pcall(function() cpu.debug:bpclear() end)
    pcall(function() m:exit() end)
    pcall(function() cpu.debug:go() end)
end

local function protocolFailure(code, message, expected, observed)
    if session.stopping then return end
    logEvent("protocol_failure", {
        code = tostring(code),
        message = tostring(message),
        expected = expected ~= nil and tostring(expected) or "",
        observed = observed ~= nil and tostring(observed) or "",
        phaseCount = tostring(session.phaseCount),
        boundaryCount = tostring(session.boundaryCount),
        skippedBoundaryCount = tostring(session.skippedCount),
        physicalStopCount = tostring(session.physicalStops),
        stageIndex = tostring(session.stageIndex),
        armedStage = tostring(session.armedStage or ""),
        armedPc = session.armedPc ~= nil and hex16(session.armedPc) or ""
    })
    finish("protocol_failure", "blocked_protocol_failure")
end

local function checkBudget()
    if session.stopping then return true end
    local wall = os.time() - session.startWall
    local emulated = m.time:as_double()
    if wall >= config.wallTimeoutSeconds then
        logEvent("session_timeout", { kind = "wall", wallSeconds = tostring(wall), emulatedTime = string.format("%.9f", emulated) })
        finish("wall_timeout", "blocked_not_reached")
        return true
    end
    if emulated >= config.secondsToRun then
        logEvent("session_timeout", { kind = "emulated", wallSeconds = tostring(wall), emulatedTime = string.format("%.9f", emulated) })
        finish("emulated_budget", "blocked_not_reached")
        return true
    end
    return false
end

local function resolvePendingWrites()
    for _, write in ipairs(session.pendingWrites) do
        if write.postValue == nil then write.postValue = readRam8(write.target) end
    end
end

local function assertDp(state, label)
    if state.dp == nil then
        protocolFailure("dp_unavailable", label .. " could not sample cpu.state DP", "live DP", "")
        return false
    end
    if state.dp.normalized ~= map.requiredDp then
        protocolFailure("dp_value", string.format("%s DP is %s, expected %s", label, hex8(state.dp.normalized), hex8(map.requiredDp)), hex8(map.requiredDp), hex8(state.dp.normalized))
        return false
    end
    return true
end

local function readMaskForEntry()
    local index = (session.entryA ~= nil) and (session.entryA & 0x07) or nil
    if index == nil then return nil end
    return readRom8(map.nativeFrame.maskTableAddress + index)
end

local function nativeWord(kind)
    if kind == "entryAB" then return ((session.entryA << 8) | session.entryB) & 0xFFFF end
    if kind == "maskEntryA" then return ((session.maskValue << 8) | session.entryA) & 0xFFFF end
    if kind == "ccMask" then return ((session.ccAt49D0 << 8) | session.maskValue) & 0xFFFF end
    if kind == "y" then return 0x9B24 end
    return nil
end

local function checkNativeFrame(state, phase)
    local stageName = phase.nativeStage
    if stageName == nil and phase.name == "native-return" then stageName = "nativeReturn" end
    if stageName == nil then return true end
    local step = map.nativeFrame.steps[stageName]
    if step == nil then
        protocolFailure("phase_native_frame", "native stage " .. tostring(stageName) .. " is not in the map", "", "")
        return false
    end
    local expectedS = (session.entryS + step.sOffset) & 0xFFFF
    if state.s ~= expectedS then
        protocolFailure("phase_native_frame", string.format("%s S is %s, expected entryS%+d=%s", phase.name, hex16(state.s), step.sOffset, hex16(expectedS)), hex16(expectedS), hex16(state.s))
        return false
    end
    local top = nativeWord(step.topWord)
    if top == nil then
        protocolFailure("phase_native_frame", "unknown native top word kind " .. tostring(step.topWord), "", "")
        return false
    end
    local observedTop = readRam16(state.s)
    local fieldsTop = observedTop
    if observedTop ~= top then
        protocolFailure("phase_native_frame", string.format("%s w@S is %s, expected %s from the live entry frame", phase.name, hex16(observedTop), hex16(top)), hex16(top), hex16(observedTop))
        return false
    end
    if top == 0x777E then
        protocolFailure("phase_native_frame", phase.name .. " collapsed to the native return slot 777E", "not 777E", hex16(top))
        return false
    end
    local returnSlot = nil
    if step.returnOffset ~= nil then
        returnSlot = readRam16((state.s + step.returnOffset) & 0xFFFF)
        if returnSlot ~= 0x777E then
            protocolFailure("phase_native_frame", string.format("%s return slot at S+%d is %s, expected 777E", phase.name, step.returnOffset, hex16(returnSlot)), "777E", hex16(returnSlot))
            return false
        end
    end
    local ySlot = readRam16((state.s + step.yOffset) & 0xFFFF)
    if ySlot ~= 0x9B24 then
        protocolFailure("phase_native_frame", string.format("%s saved-Y slot at S+%d is %s, expected 9B24", phase.name, step.yOffset, hex16(ySlot)), "9B24", hex16(ySlot))
        return false
    end
    if step.sharedCursorOffset ~= nil then
        local shared = readRam16((state.s + step.sharedCursorOffset) & 0xFFFF)
        if shared ~= 0x1026 then
            protocolFailure("phase_native_frame", string.format("%s shared cursor at S+%d is %s, expected 1026", phase.name, step.sharedCursorOffset, hex16(shared)), "1026", hex16(shared))
            return false
        end
    end
    if stageName == "afterCc" then
        local ccByte = readRam8(state.s)
        if session.ccAt49D0 == nil or ccByte ~= (session.ccAt49D0 & 0xFF) then
            protocolFailure("phase_native_frame", string.format("%s saved CC byte is %s, expected the live 49D0 CC %s", phase.name, hex8(ccByte), session.ccAt49D0 ~= nil and hex8(session.ccAt49D0) or "<missing>"), session.ccAt49D0 ~= nil and hex8(session.ccAt49D0) or "", hex8(ccByte))
            return false
        end
    end
    return true, {
        nativeStage = stageName,
        nativeFrameTop = hex16(observedTop),
        nativeReturnSlot = returnSlot ~= nil and hex16(returnSlot) or "",
        nativeYSlot = hex16(ySlot)
    }
end

local function recordPhase(stopId, stopTime, state, phase)
    if not assertDp(state, phase.name) then return false end
    if state.pc ~= phase.pc then
        protocolFailure("phase_pc", string.format("%s PC is %s, expected %s", phase.name, hex16(state.pc), hex16(phase.pc)), hex16(phase.pc), hex16(state.pc))
        return false
    end
    if state.y ~= phase.y then
        protocolFailure("phase_y", string.format("%s Y is %s, expected %s", phase.name, hex16(state.y), hex16(phase.y)), hex16(phase.y), hex16(state.y))
        return false
    end
    if state.u ~= phase.u then
        protocolFailure("phase_u", string.format("%s U is %s, expected %s", phase.name, hex16(state.u), hex16(phase.u)), hex16(phase.u), hex16(state.u))
        return false
    end
    if state.s ~= phase.s then
        protocolFailure("phase_s", string.format("%s S is %s, expected %s", phase.name, hex16(state.s), hex16(phase.s)), hex16(phase.s), hex16(state.s))
        return false
    end
    if phase.requireX and phase.x ~= nil and state.x ~= phase.x then
        protocolFailure("phase_x", string.format("%s X is %s, expected %s", phase.name, hex16(state.x), hex16(phase.x)), hex16(phase.x), hex16(state.x))
        return false
    end
    local token = readRom16(phase.tokenAddress)
    if token ~= phase.liveToken then
        protocolFailure("phase_token", string.format("%s live token %s at %s is not %s", phase.name, hex16(token), hex16(phase.tokenAddress), hex16(phase.liveToken)), hex16(phase.liveToken), hex16(token))
        return false
    end
    local operand = ""
    if phase.operandWidth ~= nil and phase.operandWidth > 0 and phase.operandAddress ~= nil then
        if phase.operandWidth == 2 then operand = hex16(readRom16(phase.operandAddress))
        else operand = hex8(readRom8(phase.operandAddress)) end
        local operandValue = tonumber(operand, 16)
        if operandValue ~= phase.operandValue then
            protocolFailure("phase_operand", string.format("%s inline operand is %s, expected %s", phase.name, operand, phase.operandText), phase.operandText, operand)
            return false
        end
    end
    if phase.controlTop ~= nil then
        local control0 = readRam16(state.s)
        if control0 ~= phase.controlTop then
            protocolFailure("phase_cursor", string.format("%s control top is %s, expected %s", phase.name, hex16(control0), hex16(phase.controlTop)), hex16(phase.controlTop), hex16(control0))
            return false
        end
    end
    local nativeFields = nil
    if phase.nativeStage ~= nil or phase.name == "native-return" then
        local ok, fields = checkNativeFrame(state, phase)
        if not ok then return false end
        nativeFields = fields
    end
    local savedCursor = ""
    if phase.savedCursor ~= nil then
        local addr = (state.s + phase.savedCursorOffset) & 0xFFFF
        local value = phase.savedCursorRole == "pending-y-before-pshs" and state.y or readRam16(addr)
        if value ~= phase.savedCursor then
            protocolFailure("phase_saved_cursor", string.format("%s saved cursor at S+%d is %s, expected %s", phase.name, phase.savedCursorOffset, hex16(value), hex16(phase.savedCursor)), hex16(phase.savedCursor), hex16(value))
            return false
        end
        savedCursor = hex16(value)
    end
    local fields = identityFields()
    fields.recordType = "phase"
    fields.stopId = tostring(stopId)
    fields.phase = phase.name
    fields.phaseIndex = tostring(session.phaseCount)
    fields.required = "true"
    fields.tokenAddress = hex16(phase.tokenAddress)
    fields.token = hex16(token)
    fields.handlerAddress = phase.handlerAddress ~= nil and hex16(phase.handlerAddress) or ""
    fields.operandAddress = phase.operandAddress ~= nil and hex16(phase.operandAddress) or ""
    fields.operandWidth = phase.operandWidth ~= nil and tostring(phase.operandWidth) or ""
    fields.operand = operand
    fields.savedCursor = savedCursor
    fields.savedCursorOffset = tostring(phase.savedCursorOffset)
    fields.savedCursorRole = phase.savedCursorRole
    fields.controlTopSource = phase.controlTopSource
    if phase.controlTop ~= nil then fields.controlTopExpected = hex16(phase.controlTop) end
    if nativeFields ~= nil then
        fields.nativeStage = nativeFields.nativeStage
        fields.nativeFrameTop = nativeFields.nativeFrameTop
        fields.nativeReturnSlot = nativeFields.nativeReturnSlot
        fields.nativeYSlot = nativeFields.nativeYSlot
        fields.nativeEntryA = hex8(session.entryA)
        fields.nativeEntryB = hex8(session.entryB)
        fields.nativeEntryX = hex16(session.entryX)
        fields.nativeMask = hex8(session.maskValue)
        if session.ccAt49D0 ~= nil then fields.nativeSavedCc = hex8(session.ccAt49D0) end
    end
    stateFields(state, fields)
    if phase.name == "bridge-jsr-entry" then
        session.entryA = state.a
        session.entryB = state.b
        session.entryX = state.x
        session.entryS = state.s
        session.maskValue = readMaskForEntry()
        if session.entryA ~= session.expectedLogicalIndex then
            protocolFailure("native_entry_a", string.format("native entry A is %s, expected the clear logical id %s", hex8(session.entryA), hex8(session.expectedLogicalIndex)), hex8(session.expectedLogicalIndex), hex8(session.entryA))
            return false
        end
        if session.entryB ~= session.expectedPattern then
            protocolFailure("native_entry_b", string.format("native entry B is %s, expected the clear pattern %s", hex8(session.entryB), hex8(session.expectedPattern)), hex8(session.expectedPattern), hex8(session.entryB))
            return false
        end
        fields.nativeEntryA = hex8(session.entryA)
        fields.nativeEntryB = hex8(session.entryB)
        fields.nativeEntryX = hex16(session.entryX)
        fields.nativeMask = hex8(session.maskValue)
        fields.nativeSavedRegWord = hex16(((session.entryA << 8) | session.entryB) & 0xFFFF)
        session.frameBefore = frameSnapshot()
        fields.frameBefore = byteList(session.frameBefore)
    elseif phase.name == "native-prologue-save-mask" then
        session.ccAt49D0 = state.cc
        fields.ccSaved49D0 = hex8(state.cc)
    elseif phase.name == "native-epilogue-puls-cc" then
        if session.ccAt49D0 == nil then
            protocolFailure("cc_not_saved", "49D0 CC was not observed before the 49E2 restore", "", "")
            return false
        end
        if state.cc ~= session.ccAt49D0 then
            protocolFailure("cc_restore_mismatch", string.format("49E2 CC is %s, expected the 49D0 saved value %s", hex8(state.cc), hex8(session.ccAt49D0)), hex8(session.ccAt49D0), hex8(state.cc))
            return false
        end
        local savedIndex = readRam8((state.s + 1) & 0xFFFF)
        local mask = readRam8(state.s)
        local response = session.response0803
        if response == nil then
            protocolFailure("response_missing", "49E0 response was not observed before 49E2", "", "")
            return false
        end
        local column = (((response ~ savedIndex) & 0x78) >> 3) & 0xFF
        session.savedLogicalIndex = savedIndex
        session.savedMask = mask
        session.column = column
        fields.ccSaved49D0 = hex8(session.ccAt49D0)
        fields.ccRestored = hex8(state.cc)
        fields.savedLogicalIndex = hex8(savedIndex)
        fields.savedMask = hex8(mask)
        fields.response0803 = hex8(response)
        fields.column = tostring(column)
        fields.frameBase = hex16((map.frameBase + column) & 0xFFFF)
        fields.columnFormula = "((response0803 XOR savedLogicalIndex) & 0x78) >> 3"
        fields.columnSource = "actual_post_LDB_B_at_49E0_not_a_static_map_prediction"
        if savedIndex ~= session.expectedLogicalIndex then
            protocolFailure("logical_index", string.format("saved logical index is %s, expected the clear id %s", hex8(savedIndex), hex8(session.expectedLogicalIndex)), hex8(session.expectedLogicalIndex), hex8(savedIndex))
            return false
        end
        if mask ~= session.expectedMask then
            protocolFailure("mask_value", string.format("saved mask is %s, expected the clear mask %s", hex8(mask), hex8(session.expectedMask)), hex8(session.expectedMask), hex8(mask))
            return false
        end
        if mask ~= session.maskValue then
            protocolFailure("mask_value", string.format("saved mask is %s, expected the ROM-derived mask %s", hex8(mask), hex8(session.maskValue)), hex8(session.maskValue), hex8(mask))
            return false
        end
    elseif phase.name == "native-epilogue-puls-a" then
        session.frameFinalNative = frameSnapshot()
        fields.frameFinalNative = byteList(session.frameFinalNative)
    elseif phase.name == "native-return" then
        session.frameAfter = frameSnapshot()
        fields.frameAfter = byteList(session.frameAfter)
    elseif phase.name == "bridge-restores-y" then
        session.f1Exit = readRam8(0x00F1)
        fields.f1AtClearRead = hex8(session.f1Exit)
        fields.clearBranchByteZero = tostring(session.f1Exit == 0)
    elseif phase.name == "bridge-load-index" then
        if session.f1Entry == nil then
            protocolFailure("branch_proof_missing", "779E was reached before the 7793 00F1 arm decision", "7793 first", "779E")
            return false
        end
        local expectedA = 0
        if session.f1Entry ~= 0 then expectedA = (session.f1Entry | 0x01) & 0xFF end
        if state.a ~= expectedA then
            protocolFailure("branch_proof", string.format("779E A is %s, expected %s from the actual 7795 BEQ path for the 7793 00F1 byte %s", hex8(state.a), hex8(expectedA), hex8(session.f1Entry)), hex8(expectedA), hex8(state.a))
            return false
        end
        fields.branchProofA = hex8(state.a)
        fields.branchProofSource = "actual_A_before_LDA_41_at_779E_after_the_7795_BEQ"
    elseif phase.name == "shared-prefetch-return" then
        if session.f1Exit == nil then
            protocolFailure("branch_proof_missing", "00FC was reached before the 7780 00F1 arm decision", "7780 first", "00FC")
            return false
        end
        local expectedA = 0
        if session.f1Exit ~= 0 then expectedA = session.f1Exit & 0xFE end
        if state.a ~= expectedA then
            protocolFailure("branch_proof", string.format("00FC A is %s, expected %s from the actual 7782 BEQ path for the 7780 00F1 byte %s", hex8(state.a), hex8(expectedA), hex8(session.f1Exit)), hex8(expectedA), hex8(state.a))
            return false
        end
        fields.branchProofA = hex8(state.a)
        fields.branchProofSource = "actual_A_at_00FC_after_the_7782_BEQ"
    elseif phase.name == "outer-returned-to-9F16" then
        fields.finalResultTop = hex16(readRam16(state.u))
        fields.successorWord = hex16(readRom16(map.successorAddress))
    end
    logEvent("phase", fields)
    session.phaseRecords[#session.phaseRecords + 1] = copyFields(fields)
    session.phaseCount = session.phaseCount + 1
    return true
end

local function recordBoundary(stopId, stopTime, state, boundary)
    if not assertDp(state, boundary.id) then return false end
    if state.y ~= 0x9B24 then
        protocolFailure("boundary_y", string.format("%s Y is %s, expected 9B24", boundary.id, hex16(state.y)), "9B24", hex16(state.y))
        return false
    end
    if state.u ~= boundary.u or state.s ~= boundary.s then
        protocolFailure("boundary_stack", string.format("%s U/S is %s/%s, expected %s/%s", boundary.id, hex16(state.u), hex16(state.s), hex16(boundary.u), hex16(boundary.s)), string.format("%s/%s", hex16(boundary.u), hex16(boundary.s)), string.format("%s/%s", hex16(state.u), hex16(state.s)))
        return false
    end
    local fields = identityFields()
    fields.recordType = "boundary"
    fields.stopId = tostring(stopId)
    fields.boundary = boundary.id
    fields.boundaryIndex = tostring(session.boundaryCount)
    fields.kind = boundary.kind
    fields.instruction = boundary.instruction
    fields.bytes = boundary.bytes
    stateFields(state, fields)
    if boundary.kind == "port_safe" then
        fields.a = hex8(state.a)
        fields.b = hex8(state.b)
        fields.cc = hex8(state.cc)
        if boundary.id == "port-orcc50" then
            fields.ccPreOrcc50 = hex8(state.cc)
        elseif boundary.id == "port-sta-0801" then
            if (state.cc & 0x50) ~= 0x50 then
                protocolFailure("orcc_mask", string.format("49D7 CC is %s, expected I=1,F=1", hex8(state.cc)), "I=1,F=1", hex8(state.cc))
                return false
            end
            fields.preWriteA = hex8(state.a)
        elseif boundary.id == "port-stb-0802" then
            if (state.cc & 0x50) ~= 0x50 then
                protocolFailure("orcc_mask", string.format("49DA CC is %s, expected I=1,F=1", hex8(state.cc)), "I=1,F=1", hex8(state.cc))
                return false
            end
            fields.preWriteB = hex8(state.b)
        elseif boundary.id == "port-ldb-0803-preread" then
            if (state.cc & 0x50) ~= 0x50 then
                protocolFailure("orcc_mask", string.format("49DD CC is %s, expected I=1,F=1", hex8(state.cc)), "I=1,F=1", hex8(state.cc))
                return false
            end
            fields.preReadA = hex8(state.a)
            fields.preReadB = hex8(state.b)
        elseif boundary.id == "port-pulscc-pre" then
            if (state.cc & 0x50) ~= 0x50 then
                protocolFailure("orcc_mask", string.format("49E0 CC is %s, expected I=1,F=1", hex8(state.cc)), "I=1,F=1", hex8(state.cc))
                return false
            end
            session.response0803 = state.b
            fields.response0803 = hex8(state.b)
            fields.ccPrePuls = hex8(state.cc)
        elseif boundary.id == "port-f1-set-read" then
            if session.f1Entry == nil then session.f1Entry = readRam8(0x00F1) end
            fields.f1AtSetRead = hex8(session.f1Entry)
            fields.setBranchByteZero = tostring(session.f1Entry == 0)
            fields.branchTaken = tostring(session.f1Entry == 0)
            fields.branchProof = "entire_00F1_byte_at_7793"
        elseif boundary.id == "port-f1-set-write" then
            local expectedA = (session.f1Entry | 0x01) & 0xFF
            if state.a ~= expectedA then
                protocolFailure("f1_set_write", string.format("7799 A is %s, expected %s from measured F1 %s", hex8(state.a), hex8(expectedA), hex8(session.f1Entry)), hex8(expectedA), hex8(state.a))
                return false
            end
            fields.preWriteA = hex8(state.a)
        elseif boundary.id == "port-080c-set-write" then
            local expectedA = (session.f1Entry | 0x01) & 0xFF
            if state.a ~= expectedA then
                protocolFailure("f1_set_write", string.format("779B A is %s, expected %s from measured F1 %s", hex8(state.a), hex8(expectedA), hex8(session.f1Entry)), hex8(expectedA), hex8(state.a))
                return false
            end
            fields.preWriteA = hex8(state.a)
            fields.f1AfterSetWrite = hex8(readRam8(0x00F1))
        elseif boundary.id == "port-f1-clear-write" then
            local expectedA = (session.f1Exit & 0xFE) & 0xFF
            if state.a ~= expectedA then
                protocolFailure("f1_clear_write", string.format("7786 A is %s, expected %s from measured F1 %s", hex8(state.a), hex8(expectedA), hex8(session.f1Exit)), hex8(expectedA), hex8(state.a))
                return false
            end
            fields.preWriteA = hex8(state.a)
        elseif boundary.id == "port-080c-clear-write" then
            local expectedA = (session.f1Exit & 0xFE) & 0xFF
            if state.a ~= expectedA then
                protocolFailure("f1_clear_write", string.format("7788 A is %s, expected %s from measured F1 %s", hex8(state.a), hex8(expectedA), hex8(session.f1Exit)), hex8(expectedA), hex8(state.a))
                return false
            end
            fields.preWriteA = hex8(state.a)
            fields.f1AfterClearWrite = hex8(readRam8(0x00F1))
        end
    elseif boundary.kind == "frame_write" then
        if session.column == nil then
            protocolFailure("column_missing", string.format("%s was reached before the actual 0803 response-derived column", boundary.id), "column", "")
            return false
        end
        local expectedBase = (map.frameBase + session.column) & 0xFFFF
        local target = (state.x + boundary.offset) & 0xFFFF
        if target < map.frameBank.start or target > map.frameBank.endInclusive then
            protocolFailure("frame_target", string.format("%s target %s is outside the frame bank", boundary.id, hex16(target)), "0100..013F", hex16(target))
            return false
        end
        if state.x ~= expectedBase then
            protocolFailure("frame_base", string.format("%s X is %s, expected the live response-derived base %s for column %d", boundary.id, hex16(state.x), hex16(expectedBase), session.column), hex16(expectedBase), hex16(state.x))
            return false
        end
        local mask = readRam8(state.s)
        if mask ~= session.expectedMask then
            protocolFailure("frame_mask", string.format("%s mask is %s, expected the clear mask %s", boundary.id, hex8(mask), hex8(session.expectedMask)), hex8(session.expectedMask), hex8(mask))
            return false
        end
        local preValue = readRam8(target)
        local expectedB = (preValue & ((~mask) & 0xFF)) & 0xFF
        if state.b ~= expectedB then
            protocolFailure("frame_write_value", string.format("%s B is %s, expected pre %s & ~mask %s = %s", boundary.id, hex8(state.b), hex8(preValue), hex8(mask), hex8(expectedB)), hex8(expectedB), hex8(state.b))
            return false
        end
        local cleared = ((preValue & mask) ~= 0)
        local write = {
            id = boundary.id,
            target = target,
            x = state.x,
            b = state.b,
            mask = mask,
            preValue = preValue,
            expectedB = expectedB,
            cleared = cleared,
            postValue = nil
        }
        session.pendingWrites[#session.pendingWrites + 1] = write
        if cleared then session.clearTransitions = session.clearTransitions + 1 end
        fields.target = hex16(target)
        fields.frameBase = hex16(expectedBase)
        fields.preValue = hex8(preValue)
        fields.mask = hex8(mask)
        fields.preWriteB = hex8(state.b)
        fields.expectedB = hex8(expectedB)
        fields.clearAlgebra = "after = before & ~mask"
        fields.cleared = tostring(write.cleared)
        fields.alreadyClear = tostring(not write.cleared)
        fields.visibleTransition = tostring(write.cleared)
        fields.frameRamNotPhysicalLamp = "frame RAM change is not photographed physical lamp output"
    end
    logEvent("boundary", fields)
    session.boundaryRecords[#session.boundaryRecords + 1] = copyFields(fields)
    session.boundaryCount = session.boundaryCount + 1
    return true
end

local function stageConditionValue(stage)
    if stage.onlyIf == nil or stage.onlyIf == "" or stage.onlyIf == "nil" then return true end
    if stage.onlyIf == "f1EntryNonZero" then return session.f1Entry ~= nil and session.f1Entry ~= 0 end
    if stage.onlyIf == "f1ExitNonZero" then return session.f1Exit ~= nil and session.f1Exit ~= 0 end
    startupFailure("stage_condition", "unknown stage condition " .. tostring(stage.onlyIf))
    return false
end

local function skipStage(stage, stopTime)
    local reason = "conditional " .. tostring(stage.onlyIf) .. " not taken by the measured whole 00F1 byte"
    for _, boundaryId in ipairs(stage.boundaryIds) do
        session.skippedCount = session.skippedCount + 1
        session.skippedBoundaries[#session.skippedBoundaries + 1] = boundaryId
        logEvent("boundary_skipped", {
            boundary = boundaryId,
            reason = reason,
            stopId = "",
            emulatedTime = string.format("%.9f", stopTime),
            stageId = stage.id,
            onlyIf = tostring(stage.onlyIf),
            f1Entry = session.f1Entry ~= nil and hex8(session.f1Entry) or "",
            f1Exit = session.f1Exit ~= nil and hex8(session.f1Exit) or "",
            phaseCount = tostring(session.phaseCount),
            boundaryCount = tostring(session.boundaryCount),
            skippedCount = tostring(session.skippedCount)
        })
    end
end

local function resolveNextStageIndex(index, stopTime)
    while index <= #map.stages do
        local stage = map.stages[index]
        if stageConditionValue(stage) then return index end
        skipStage(stage, stopTime)
        index = index + 1
    end
    return index
end

local function armStage(stage)
    pcall(function() cpu.debug:bpclear() end)
    local ok, bp = pcall(function() return cpu.debug:bpset(stage.pc, stage.condition, "") end)
    if not ok then startupFailure("breakpoint", string.format("PC %04X condition %s: %s", stage.pc, stage.condition, tostring(bp))) end
    session.armedStage = stage.id
    session.armedPc = stage.pc
    session.armedCondition = stage.condition
end

local function processStop(state)
    local stage = map.stages[session.stageIndex]
    if stage == nil then
        protocolFailure("unexpected_stop", string.format("stop at PC %s after the ordered plan completed", hex16(state.pc)), "no stop", hex16(state.pc))
        return
    end
    if state.pc ~= stage.pc then
        protocolFailure("unexpected_stop", string.format("stop at PC %s does not match armed stage %s at %s", hex16(state.pc), stage.id, hex16(stage.pc)), hex16(stage.pc), hex16(state.pc))
        return
    end
    if #stage.phaseNames > 0 then
        local firstPhase = phaseByName[stage.phaseNames[1]]
        if firstPhase ~= nil and firstPhase.y ~= nil and state.y ~= firstPhase.y then
            protocolFailure("unexpected_stop", string.format("stage %s Y is %s, expected %s", stage.id, hex16(state.y), hex16(firstPhase.y)), hex16(firstPhase.y), hex16(state.y))
            return
        end
    end
    if stage.branch == "f1-entry" then
        session.f1Entry = readRam8(0x00F1)
    elseif stage.branch == "f1-exit" then
        session.f1Exit = readRam8(0x00F1)
    end
    session.physicalStops = session.physicalStops + 1
    local stopId = session.physicalStops
    local stopTime = state.time
    local matched = {}
    for _, phaseName in ipairs(stage.phaseNames) do
        matched[#matched + 1] = "phase:" .. phaseName
    end
    for _, boundaryId in ipairs(stage.boundaryIds) do
        matched[#matched + 1] = "boundary:" .. boundaryId
    end
    logEvent("physical_stop", {
        stopId = tostring(stopId),
        pc = hex16(state.pc),
        emulatedTime = string.format("%.9f", stopTime),
        matched = table.concat(matched, ","),
        stageId = stage.id,
        stageOrdinal = tostring(stage.ordinal),
        armedPc = hex16(session.armedPc),
        armedCondition = tostring(session.armedCondition),
        phaseCount = tostring(session.phaseCount),
        boundaryCount = tostring(session.boundaryCount),
        skippedCount = tostring(session.skippedCount)
    })
    session.stopRecords[#session.stopRecords + 1] = { id = stopId, time = stopTime, pc = state.pc, stage = stage.id, matched = table.concat(matched, ",") }
    for _, phaseName in ipairs(stage.phaseNames) do
        local phase = phaseByName[phaseName]
        if phase == nil then startupFailure("stage_phase", "unknown phase " .. tostring(phaseName)) end
        if not recordPhase(stopId, stopTime, state, phase) then return end
    end
    for _, boundaryId in ipairs(stage.boundaryIds) do
        local boundary = boundaryById[boundaryId]
        if boundary == nil then startupFailure("stage_boundary", "unknown boundary " .. tostring(boundaryId)) end
        if not recordBoundary(stopId, stopTime, state, boundary) then return end
    end
    local nextIndex = resolveNextStageIndex(session.stageIndex + 1, stopTime)
    session.stageIndex = nextIndex
    if nextIndex > #map.stages then
        if session.phaseCount ~= #map.phases then
            protocolFailure("missing_phase", string.format("plan completed with %d/%d phase records", session.phaseCount, #map.phases), tostring(#map.phases), tostring(session.phaseCount))
            return
        end
        finish("lamp_natural_complete", "complete_natural_observation_pending_review")
        return
    end
    armStage(map.stages[nextIndex])
    pcall(function() cpu.debug:go() end)
end

if session.resetPc == 0 or session.resetPc == 0xFFFF then startupFailure("reset_vector", string.format("unsupported reset vector %04X", session.resetPc)) end
if dbg.execution_state ~= "stop" then startupFailure("start_not_stopped", "session did not load while the debugger was stopped") end

local firstStage = map.stages[1]
if firstStage.pc ~= 0x00FC or firstStage.phaseNames[1] ~= "caller-dispatch" then
    startupFailure("first_stage", "the ordered plan must begin with the caller-dispatch PC=00FC/Y=9F14 stage")
end
if firstStage.condition ~= "y==0x9f14" then
    startupFailure("first_stage_condition", "the first armed predicate is not the target caller Y=9F14")
end

local expectedSafeRam = {
    { start = 0x00F1, endInclusive = 0x00F2 },
    { start = 0x0100, endInclusive = 0x013F },
    { start = 0x0668, endInclusive = 0x0675 },
    { start = 0x078A, endInclusive = 0x079F }
}
for _, required in ipairs(expectedSafeRam) do
    local found = false
    for _, allowed in ipairs(map.safeRam) do
        if allowed.start == required.start and allowed.endInclusive == required.endInclusive then found = true end
    end
    if not found then startupFailure("safe_ram_contract", string.format("safe RAM range %04X..%04X is not present", required.start, required.endInclusive)) end
end
for _, r in ipairs(map.safeRam) do
    if r.start >= 0x0800 or r.endInclusive >= 0x0800 then startupFailure("safe_ram_io_overlap", "safe RAM range reaches active I/O space") end
    if r.start > r.endInclusive then startupFailure("safe_ram_order", "safe RAM range is inverted") end
end

local okInitial, initialBp = pcall(function() return cpu.debug:bpset(session.resetPc, "1", "") end)
if not okInitial then startupFailure("initial_breakpoint", tostring(initialBp)) end
cpu.debug:go()

local function driveObserver()
    if session.stopping then return end
    if checkBudget() then return end
    if dbg.execution_state ~= "stop" then return end
    local state = snapshot()
    if session.phase == "starting" then
        if state.pc ~= session.resetPc then
            startupFailure("initial_stop", string.format("stopped at %04X instead of reset entry %04X", state.pc, session.resetPc))
            return
        end
        resolvePendingWrites()
        armStage(firstStage)
        session.phase = "running"
        writeReady()
        local fields = identityFields()
        fields.resetPc = hex16(session.resetPc)
        fields.secondsToRun = tostring(config.secondsToRun)
        fields.wallTimeoutSeconds = tostring(config.wallTimeoutSeconds)
        fields.headerAddress = hex16(map.headerAddress)
        fields.bodyStart = hex16(map.bodyStart)
        fields.bodyEndExclusive = hex16(map.bodyEndExclusive)
        fields.callerAddress = hex16(map.callerAddress)
        fields.callerLiveToken = hex16(map.callerLiveToken)
        fields.successorAddress = hex16(map.successorAddress)
        fields.successorToken = hex16(map.successorToken)
        fields.phaseCount = tostring(#map.phases)
        fields.boundaryCount = tostring(#map.boundaries)
        fields.stageCount = tostring(#map.stages)
        fields.firstStage = firstStage.id
        fields.firstArmedPc = hex16(firstStage.pc)
        fields.firstArmedCondition = firstStage.condition
        fields.orderedArming = "target_dispatch_first_then_next_reachable_stage_only"
        fields.dpAvailable = session.dpAvailable and "true" or "false"
        fields.dpUnavailableReason = dpUnavailableReason
        fields.inputPolicy = config.inputPolicy
        fields.boundarySource = "native_debugger_bpset"
        fields.driver = "emu.register_periodic_stopped_state_only"
        fields.ioReadPolicy = "strict_allowlist_no_active_io_reads"
        logEvent("session_ready", fields)
        cpu.debug:go()
        return
    end
    if session.phase == "running" then
        local key = string.format("%04X:%04X:%.9f", state.pc, state.curpc, state.time)
        if session.processedStopKeys[key] then
            pcall(function() cpu.debug:go() end)
            return
        end
        session.processedStopKeys[key] = true
        if state.time <= session.lastStopTime then
            protocolFailure("non_monotonic_stop", string.format("stop time %.9f is not after the previous stop %.9f", state.time, session.lastStopTime), "", string.format("%.9f", state.time))
            return
        end
        session.lastStopTime = state.time
        resolvePendingWrites()
        processStop(state)
    end
end

emu.register_periodic(function()
    if session.stopping then return end
    local ok, err = xpcall(driveObserver, function(message)
        if debug and debug.traceback then return debug.traceback(tostring(message), 2) end
        return tostring(message)
    end)
    if not ok then protocolFailure("observer_exception", err, "valid observer state", "exception") end
end, "periodic")

-- Read-only feature observer with a bounded throttle handover and an optional
-- input-ownership handover for manual play. No CPU/RAM/register writes, no
-- save states, no input bindings changed.
dofile('input.lua')

local m = manager.machine
local cpu = m.devices[":maincpu"]
local mem = cpu.spaces["program"]
local dbg = m.debugger

local function envNumber(name, fallback)
    local value = tonumber(os.getenv(name) or "")
    if value == nil then return fallback end
    return value
end
local function envHex(name, fallback)
    local raw = os.getenv(name)
    if raw == nil or raw == "" then return fallback end
    local value = tonumber(raw, 16)
    if value == nil then return fallback end
    return value
end
local function envFlag(name)
    local value = (os.getenv(name) or "0"):lower()
    return value == "1" or value == "true" or value == "yes"
end

local TARGET_Y = math.floor(envHex("FML_FEATURE_TARGET", 0x1012))
local POST_Y = math.floor(envHex("FML_FEATURE_POST", 0xD003))
local RETURN_Y = math.floor(envHex("FML_RETURN_Y", 0xE243))
local THROTTLE_T = envNumber("FML_THROTTLE_T", 538.0)
local POST_RETURN_SECONDS = envNumber("FML_POST_RETURN_SECONDS", 1.5)
local MANUAL = envFlag("FML_MANUAL")
local MANUAL_SECONDS = envNumber("FML_MANUAL_SECONDS", 60.0)
local DENSE_FROM = math.floor(envNumber("FML_DENSE_FROM", 32580))
local MAX_FRAMES = math.floor(envNumber("FML_MAX_FRAMES", 40000))

local events = assert(io.open("ball-events.jsonl", "w"))
local frames = assert(io.open("ball-frames.csv", "w"))
frames:write("frame,t,pc,y,u,s,display,c9,ram0002,ram0003,grid\n")
frames:flush()

local frameCount = 0
local stage = 0
local entryTime = nil
local returnTime = nil
local stopKey = nil
local exited = false
local throttledOn = false
local throttleReadback = "not-attempted"
local speedReadback = ""
local handoverResult = "not-requested"

local function hex16(v) return string.format("%04X", v & 0xFFFF) end
local function writeMarker(name)
    local f = io.open(name, "w")
    if f then
        f:write(string.format("time=%d t=%.9f frame=%d\n", os.time(), m.time:as_double(), frameCount))
        f:close()
    end
end
local function displayText()
    local out = {}
    for a = 0x58, 0x67 do
        local c = mem:read_u8(a) & 63
        if c < 32 then c = c + 64 end
        out[#out + 1] = string.char(c)
    end
    return table.concat(out)
end
local function lampv(n)
    local ok, value = pcall(function() return m.output:get_value("lamp" .. n) end)
    if ok and type(value) == "number" then return value end
    return -1
end
local function gridText()
    local rows = {}
    for r = 0, 7 do
        local cells = {}
        for c = 0, 5 do
            local v = lampv(64 + 8 * r + c)
            cells[#cells + 1] = (v > 0) and "1" or "0"
        end
        rows[#rows + 1] = table.concat(cells)
    end
    return table.concat(rows, "/")
end
local function logEvent(tag, fields)
    local parts = { '{"event":"' .. tag .. '"' }
    if fields then
        local keys = {}
        for k, _ in pairs(fields) do keys[#keys + 1] = k end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local v = fields[k]
            if type(v) == "number" then
                parts[#parts + 1] = ',"' .. k .. '":' .. string.format("%.0f", math.floor(v))
            else
                local s = tostring(v):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('[\r\n]', ' ')
                parts[#parts + 1] = ',"' .. k .. '":"' .. s .. '"'
            end
        end
    end
    parts[#parts + 1] = "}\n"
    events:write(table.concat(parts))
    events:flush()
end
local function snapshot()
    return {
        pc = cpu.state["PC"].value,
        y = cpu.state["Y"].value,
        u = cpu.state["U"].value,
        s = cpu.state["S"].value,
        x = cpu.state["X"].value,
        t = m.time:as_double()
    }
end
local function closeAll()
    pcall(function() frames:flush(); frames:close() end)
    pcall(function() events:flush(); events:close() end)
end
local function finish(reason)
    if exited then return end
    exited = true
    throttleReadback = tostring(m.video.throttled)
    speedReadback = tostring(m.video.speed_percent)
    writeMarker("marker-05-finish")
    logEvent("finish", {
        reason = reason,
        frame = frameCount,
        stage = stage,
        t = string.format("%.9f", m.time:as_double()),
        throttle_readback = throttleReadback,
        throttle_rate = tostring(m.video.throttle_rate),
        speed_percent = speedReadback,
        manual = tostring(MANUAL),
        handover = handoverResult
    })
    closeAll()
    pcall(function() cpu.debug:bpclear() end)
    pcall(function() m:exit() end)
end
local function recordStop(state, tag)
    logEvent(tag, {
        frame = frameCount,
        t = string.format("%.9f", state.t),
        pc = hex16(state.pc),
        y = hex16(state.y),
        u = hex16(state.u),
        s = hex16(state.s),
        x = hex16(state.x),
        display = displayText(),
        c9 = mem:read_u8(0xc9),
        ram0002 = string.format("%02X", mem:read_u8(0x0002)),
        ram0003 = string.format("%02X", mem:read_u8(0x0003)),
        grid = gridText()
    })
end
local function arm(stageIndex, targetY)
    cpu.debug:bpclear()
    cpu.debug:bpset(0x00FC, string.format("y==0x%04x", targetY), "")
    stage = stageIndex
    logEvent("arm", { stage = stageIndex, targetY = hex16(targetY) })
    cpu.debug:go()
end

-- Start the known route as fast as possible. -nothrottle is also passed on the
-- command line; this explicit runtime write and readback keeps ownership clear.
local throttleOk, throttleErr = pcall(function()
    m.video.throttle_rate = 1.0
    m.video.throttled = false
end)
writeMarker("marker-00-fast-start")
logEvent("fast_start", {
    frame = frameCount,
    t = string.format("%.9f", m.time:as_double()),
    ok = tostring(throttleOk),
    throttled = tostring(m.video.throttled),
    rate = tostring(m.video.throttle_rate),
    error = tostring(throttleErr or "")
})

emu.register_frame_done(function()
    if exited then return end
    frameCount = frameCount + 1
    local t = m.time:as_double()

    if not throttledOn and t >= THROTTLE_T then
        local ok, err = pcall(function()
            m.video.throttle_rate = 1.0
            m.video.throttled = true
        end)
        throttledOn = true
        throttleReadback = tostring(m.video.throttled)
        writeMarker("marker-01-throttle-on")
        logEvent("throttle_on", {
            frame = frameCount,
            t = string.format("%.9f", t),
            ok = tostring(ok),
            throttled = throttleReadback,
            rate = tostring(m.video.throttle_rate),
            error = tostring(err or "")
        })
        if not ok or throttleReadback ~= "true" then
            finish("throttle_write_failed")
            return
        end
    end

    if frameCount >= DENSE_FROM then
        frames:write(string.format("%d,%.9f,%04X,%04X,%04X,%04X,%s,%d,%02X,%02X,%s\n",
            frameCount, t,
            cpu.state["PC"].value, cpu.state["Y"].value,
            cpu.state["U"].value, cpu.state["S"].value,
            displayText(), mem:read_u8(0xc9),
            mem:read_u8(0x0002), mem:read_u8(0x0003), gridText()))
        if frameCount % 30 == 0 then frames:flush() end
    end

    if returnTime and t >= returnTime + POST_RETURN_SECONDS then
        finish("return_window")
        return
    end
    if MANUAL and entryTime and t >= entryTime + MANUAL_SECONDS then
        finish("manual_window")
        return
    end
    if frameCount >= MAX_FRAMES then
        finish("frame_cap")
    end
end, "snakebite-frames")

local function driveObserver()
    if exited then return end
    if dbg.execution_state ~= "stop" then return end
    local state = snapshot()
    local key = string.format("%04X:%04X:%.9f", state.pc, state.y, state.t)
    if key == stopKey then pcall(function() cpu.debug:go() end) return end
    stopKey = key
    if state.pc ~= 0x00FC then
        pcall(function() cpu.debug:go() end)
        return
    end
    if stage == 0 and state.y == TARGET_Y then
        entryTime = state.t
        recordStop(state, "cave_entry")
        writeMarker("marker-02-cave-entry")
        if MANUAL then
            local supported = type(MPU4InputReleaseAll) == "function"
            local ok, first, second = false, nil, nil
            if supported then
                ok, first, second = pcall(MPU4InputReleaseAll, "feature-cave-entry")
            end
            writeMarker("marker-02b-handover")
            handoverResult = string.format("supported=%s ok=%s first=%s second=%s",
                tostring(supported), tostring(ok), tostring(first), tostring(second))
            logEvent("handover", {
                frame = frameCount,
                t = string.format("%.9f", state.t),
                supported = tostring(supported),
                ok = tostring(ok),
                first = tostring(first),
                second = tostring(second)
            })
            if not (supported and ok and first == true) then
                finish("manual_handover_failed")
                return
            end
        end
        arm(1, POST_Y)
        return
    end
    if stage == 1 and state.y == POST_Y then
        recordStop(state, "original_body_entry")
        writeMarker("marker-03-body")
        arm(2, RETURN_Y)
        return
    end
    if stage == 2 and state.y == RETURN_Y then
        recordStop(state, "feature_return")
        writeMarker("marker-04-return")
        returnTime = state.t
        pcall(function() cpu.debug:bpclear() end)
        pcall(function() cpu.debug:go() end)
        return
    end
    pcall(function() cpu.debug:go() end)
end

emu.register_periodic(function()
    local ok, err = xpcall(driveObserver, function(message) return tostring(message) end)
    if not ok then
        logEvent("observer_error", { message = err })
        finish("observer_error")
    end
end, "snakebite-observer")

arm(0, TARGET_Y)

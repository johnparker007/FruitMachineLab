-- Read-only six-brick feature observer. No CPU/RAM/register writes, no save
-- states and no input bindings changed. Samples VM stack cells at the custom
-- loop, records MAME lamp outputs, and performs the bounded throttle handover.
dofile('input.lua')
local m = manager.machine
local cpu = m.devices[":maincpu"]
local mem = cpu.spaces["program"]
local dbg = m.debugger

local function envNumber(name, fallback)
    local v = tonumber(os.getenv(name) or "")
    if v == nil then return fallback end
    return v
end
local function envHex(name, fallback)
    local raw = os.getenv(name)
    if raw == nil or raw == "" then return fallback end
    local v = tonumber(raw, 16)
    if v == nil then return fallback end
    return v
end
local function envFlag(name)
    local v = (os.getenv(name) or "0"):lower()
    return v == "1" or v == "true" or v == "yes"
end

local TARGET_Y = math.floor(envHex("FML_FEATURE_TARGET", 0x1012))
local LOOP_Y = math.floor(envHex("FML_FEATURE_LOOP", 0x1052))
local POST_Y = math.floor(envHex("FML_FEATURE_POST", 0xD086))
local RETURN_Y = math.floor(envHex("FML_RETURN_Y", 0xE243))
local WIN_Y = math.floor(envHex("FML_FEATURE_WIN", 0x12E6))
local LOSS_Y = math.floor(envHex("FML_FEATURE_LOSS", 0x1294))
local THROTTLE_T = envNumber("FML_THROTTLE_T", 538.0)
local POST_RETURN_SECONDS = envNumber("FML_POST_RETURN_SECONDS", 1.5)
local DENSE_FROM = math.floor(envNumber("FML_DENSE_FROM", 32580))
local MAX_FRAMES = math.floor(envNumber("FML_MAX_FRAMES", 46000))
local MANUAL = envFlag("FML_MANUAL")
local MANUAL_SECONDS = envNumber("FML_MANUAL_SECONDS", 120.0)

local events = assert(io.open("ball-events.jsonl", "w"))
local frames = assert(io.open("ball-frames.csv", "w"))
frames:write("frame,t,pc,y,u,s,display,c9,ram0002,ram0003,grid\n")
frames:flush()
local masks = assert(io.open("mask-events.csv", "w"))
masks:write("frame,t,y,u,s,c9,u0,u2,u4,u6,grid\n")
masks:flush()

local frameCount = 0
local entrySeen = false
local postSeen = false
local returnSeen = false
local entryTime, returnTime = nil, nil
local exited = false
local throttledOn = false
local lastMask = nil
local handoverResult = "not-requested"
local manualEntryTime = nil
local winSeen = false
local lossSeen = false

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
            cells[#cells + 1] = (lampv(64 + 8 * r + c) > 0) and "1" or "0"
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
    pcall(function() masks:flush(); masks:close() end)
    pcall(function() events:flush(); events:close() end)
end
local function finish(reason)
    if exited then return end
    exited = true
    writeMarker("marker-05-finish")
    logEvent("finish", {
        reason = reason,
        frame = frameCount,
        t = string.format("%.9f", m.time:as_double()),
        throttle_readback = tostring(m.video.throttled),
        throttle_rate = tostring(m.video.throttle_rate),
        speed_percent = tostring(m.video.speed_percent),
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
        saved02fe = hex16(mem:read_u16(0x02fe)), saved0300 = hex16(mem:read_u16(0x0300)),
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
local function read16(addr)
    if addr < 0 or addr > 0xFFFE then return -1 end
    return mem:read_u16(addr)
end
local function maskSample(state)
    local u0 = read16(state.u)
    local u2 = read16(state.u + 2)
    local u4 = read16(state.u + 4)
    local u6 = read16(state.u + 6)
    local grid = gridText()
    if u2 ~= lastMask then
        lastMask = u2
        masks:write(string.format("%d,%.9f,%04X,%04X,%04X,%d,%04X,%04X,%04X,%04X,%s\n",
            frameCount, state.t, state.y, state.u, state.s, mem:read_u8(0xc9),
            u0, u2, u4, u6, grid))
        masks:flush()
        logEvent("mask_change", {
            frame = frameCount,
            t = string.format("%.9f", state.t),
            u = hex16(state.u),
            s = hex16(state.s),
            c9 = mem:read_u8(0xc9),
            u0 = hex16(u0),
            u2 = hex16(u2),
            u4 = hex16(u4),
            grid = grid
        })
    end
end

local throttleOk, throttleErr = pcall(function()
    m.video.throttle_rate = 1.0
    m.video.throttled = false
end)
writeMarker("marker-00-fast-start")
logEvent("fast_start", {
    frame = 0,
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
        writeMarker("marker-01-throttle-on")
        logEvent("throttle_on", {
            frame = frameCount,
            t = string.format("%.9f", t),
            ok = tostring(ok),
            throttled = tostring(m.video.throttled),
            rate = tostring(m.video.throttle_rate),
            error = tostring(err or "")
        })
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

    if MANUAL and manualEntryTime and t >= manualEntryTime + MANUAL_SECONDS then
        finish("manual_window")
        return
    end
    if returnTime and t >= returnTime + POST_RETURN_SECONDS then
        finish("return_window")
        return
    end
    if frameCount >= MAX_FRAMES then
        finish("frame_cap")
    end
end, "six-brick-frames")

local function go()
    cpu.debug:go()
end
local function sampleStops()
    if exited then return end
    if dbg.execution_state ~= "stop" then return end
    local state = snapshot()
    if state.pc ~= 0x00FC then go(); return end
    if state.y == LOOP_Y then
        maskSample(state)
        go()
        return
    end
    if state.y == TARGET_Y and not entrySeen then
        entrySeen = true
        entryTime = state.t
        manualEntryTime = state.t
        recordStop(state, "cave_entry")
        writeMarker("marker-02-cave-entry")
        if MANUAL then
            local supported = type(MPU4InputReleaseAll) == "function"
            local ok, first, second = false, nil, nil
            if supported then ok, first, second = pcall(MPU4InputReleaseAll, "six-brick-entry") end
            handoverResult = string.format("supported=%s ok=%s first=%s second=%s",
                tostring(supported), tostring(ok), tostring(first), tostring(second))
            writeMarker("marker-02b-handover")
            logEvent("handover", {
                frame = frameCount,
                t = string.format("%.9f", state.t),
                supported = tostring(supported),
                ok = tostring(ok),
                first = tostring(first),
                second = tostring(second)
            })
        end
        go()
        return
    end
    if state.y == WIN_Y and not winSeen then
        winSeen = true
        recordStop(state, "win_state")
        logEvent("win_state", {
            frame = frameCount,
            t = string.format("%.9f", state.t),
            u = hex16(state.u),
            s = hex16(state.s),
            c9 = mem:read_u8(0xc9),
            u0 = hex16(read16(state.u)),
            u2 = hex16(read16(state.u + 2)),
            u4 = hex16(read16(state.u + 4)),
            grid = gridText()
        })
        go()
        return
    end
    if state.y == LOSS_Y and not lossSeen then
        lossSeen = true
        recordStop(state, "loss_state")
        logEvent("loss_state", {
            frame = frameCount,
            t = string.format("%.9f", state.t),
            u = hex16(state.u),
            s = hex16(state.s),
            c9 = mem:read_u8(0xc9),
            u0 = hex16(read16(state.u)),
            u2 = hex16(read16(state.u + 2)),
            u4 = hex16(read16(state.u + 4)),
            grid = gridText()
        })
        go()
        return
    end
    if state.y == POST_Y and entrySeen and not postSeen then
        postSeen = true
        recordStop(state, "original_body_entry")
        writeMarker("marker-03-body")
        go()
        return
    end
    if state.y == RETURN_Y and postSeen and not returnSeen then
        returnSeen = true
        returnTime = state.t
        recordStop(state, "feature_return")
        writeMarker("marker-04-return")
        go()
        return
    end
    go()
end

local bpInstalled = false
local function installBreakpoint()
    if bpInstalled then return true end
    local condition = string.format(
        "y==0x%04x or y==0x%04x or y==0x%04x or y==0x%04x or y==0x%04x or y==0x%04x",
        LOOP_Y, TARGET_Y, POST_Y, RETURN_Y, WIN_Y, LOSS_Y)
    local ok, err = pcall(function()
        cpu.debug:bpclear()
        cpu.debug:bpset(0x00FC, condition, "")
    end)
    bpInstalled = ok
    logEvent("breakpoint", {
        installed = tostring(ok),
        condition = condition,
        error = tostring(err or "")
    })
    return ok
end
installBreakpoint()
emu.register_periodic(function()
    if not exited and not bpInstalled then installBreakpoint() end
end, "six-brick-bp-retry")
emu.register_periodic(sampleStops, "six-brick-stops")
go()

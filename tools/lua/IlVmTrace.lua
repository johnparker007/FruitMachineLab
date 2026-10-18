-- Read-only MAME 0.281 Lua observer paired with a native debugger capture.
--
-- MAME 0.281 exposes a Lua debugger API when the debugger is enabled:
-- manager.machine.debugger and devices[tag].debug are userdata under -debug.
-- This observer records that capability, validates the checked source map
-- against live bytes, records frame-sampled state and read-tap diagnostics, and
-- names the native debugger as the exact-boundary source.  It does not claim a
-- Lua instruction callback and does not relabel frame samples as boundaries.
--
-- Required environment variables:
--   FML_IL_MAP_TABLE       path to a generated Lua map table
--   FML_IL_VARIANT         Original or Changed
--   FML_IL_IMAGE_SHA256    expected variant image SHA256
--   FML_IL_ORIGINAL_SHA256 expected original ROM SHA256
--   FML_IL_SECONDS         emulated seconds to observe (1..120)

local m = manager.machine
local cpu = m.devices[":maincpu"]
local mem = cpu.spaces["program"]
local mapPath = assert(os.getenv("FML_IL_MAP_TABLE"), "FML_IL_MAP_TABLE is required")
local variant = assert(os.getenv("FML_IL_VARIANT"), "FML_IL_VARIANT is required")
local expectedImage = assert(os.getenv("FML_IL_IMAGE_SHA256"), "FML_IL_IMAGE_SHA256 is required")
local expectedOriginal = assert(os.getenv("FML_IL_ORIGINAL_SHA256"), "FML_IL_ORIGINAL_SHA256 is required")
local seconds = tonumber(os.getenv("FML_IL_SECONDS") or "120")
assert(seconds and seconds >= 1 and seconds <= 120, "FML_IL_SECONDS out of supported range")

local cap = assert(io.open("lua-capability.csv", "w"))
cap:setvbuf("no")
local samples = assert(io.open("lua-samples.csv", "w"))
samples:setvbuf("no")
local taps = assert(io.open("lua-boundary-taps.csv", "w"))
taps:setvbuf("no")

local dbg = m.debugger
local dbgType = type(dbg)
local cpuDebugType = type(cpu.debug)
cap:write("probe,readonly_lua_observer_with_native_debugger\n")
cap:write("manager_machine_debugger_type," .. dbgType .. "\n")
cap:write("cpu_debug_type," .. cpuDebugType .. "\n")
if dbg ~= nil then
    cap:write("debugger_execution_state," .. tostring(dbg.execution_state) .. "\n")
    cap:write("debugger_visible_cpu," .. tostring(dbg.visible_cpu) .. "\n")
else
    cap:write("debugger_execution_state,unavailable\n")
end
cap:write("lua_version," .. tostring(_VERSION) .. "\n")
cap:write("frame_callback," .. tostring(type(emu.register_frame_done)) .. "\n")
cap:write("periodic_callback," .. tostring(type(emu.register_periodic)) .. "\n")
cap:write("lua_instruction_callback,supported=false\n")
cap:write("BOUNDARY_SUPPORT=native_debugger_breakpoints,lua_instruction_callback=false\n")
samples:write("frame,t,pc,x,y,u,s,phase\n")
taps:write("tag,address,data,pc,curpc,x,y,u,s,w_at_y,w_at_s,t,phase\n")

local function fail(message)
    cap:write("MAP_FAIL," .. tostring(message) .. "\n")
    cap:flush()
    error(message)
end

local map = dofile(mapPath)
if type(map) ~= "table" then fail("map table is not a table") end
if map.schemaVersion ~= 1 then fail("map schemaVersion is not 1") end
if map.variant ~= variant then fail("map variant " .. tostring(map.variant) .. " is not " .. variant) end
if map.imageSha256 ~= expectedImage then fail("map image identity differs from expected variant") end
if map.originalRomSha256 ~= expectedOriginal then fail("map original identity differs from expected original") end
if map.bodyStart ~= 0x9ED9 or map.bodyEndExclusive ~= 0x9EE7 then
    fail("map body span is not 9ED9..9EE7")
end
if type(map.entries) ~= "table" or #map.entries == 0 then fail("map has no entries") end
if type(map.nodes) ~= "table" or #map.nodes == 0 then fail("map has no nodes") end

local expectedAddress = map.bodyStart
local lastNode = -1
for index, entry in ipairs(map.entries) do
    if type(entry.address) ~= "number" or entry.address ~= expectedAddress then
        fail("map entry " .. index .. " is not contiguous at " .. string.format("%04X", expectedAddress))
    end
    if type(entry.nodeIndex) ~= "number" or entry.nodeIndex < lastNode then
        fail("map node order is ambiguous or reordered at " .. string.format("%04X", entry.address))
    end
    if entry.nodeIndex > lastNode then
        if entry.nodeIndex ~= lastNode + 1 then fail("map node index gap at " .. string.format("%04X", entry.address)) end
        lastNode = entry.nodeIndex
    end
    local live = mem:read_u8(entry.address)
    if live ~= entry.imageByte then
        fail(string.format("live byte %02X differs from map byte %02X at %04X", live, entry.imageByte, entry.address))
    end
    expectedAddress = expectedAddress + 1
end
if expectedAddress ~= map.bodyEndExclusive then fail("map does not cover the declared body end") end
if lastNode ~= 4 then fail("map does not contain the five checked node indices 0..4") end

for _, node in ipairs(map.nodes) do
    if type(node.address) ~= "number" or type(node.token) ~= "number" then fail("node is malformed") end
    local liveToken = mem:read_u16(node.address)
    if liveToken ~= node.token then
        fail(string.format("live token %04X differs from map token %04X at %04X", liveToken, node.token, node.address))
    end
    for offset, byte in ipairs(node.bytes) do
        local live = mem:read_u8(node.address + offset - 1)
        if live ~= byte then
            fail(string.format("live node byte %02X differs from map byte %02X at %04X", live, byte, node.address + offset - 1))
        end
    end
end
cap:write(string.format("MAP_OK,variant=%s,image=%s,original=%s,entries=%d,nodes=%d\n",
    variant, expectedImage, expectedOriginal, #map.entries, #map.nodes))

local guard = false
local counts = {}
local boundaryHits = 0
local positiveHits = 0
local sampleCount = 0

local function recordTap(tag, address, data, phase)
    if guard then return end
    guard = true
    local pc = cpu.state["PC"].value
    local curpc = cpu.state["CURPC"].value
    local x = cpu.state["X"].value
    local y = cpu.state["Y"].value
    local u = cpu.state["U"].value
    local s = cpu.state["S"].value
    local wy = mem:read_u16(y)
    local ws = mem:read_u16(s)
    taps:write(string.format("%s,%04X,%02X,%04X,%04X,%04X,%04X,%04X,%04X,%04X,%04X,%.9f,%s\n",
        tag, address, data, pc, curpc, x, y, u, s, wy, ws, m.time:as_double(), phase))
    taps:flush()
    guard = false
end

local function installTap(tag, startAddress, stopAddress, phase, counter)
    local ok, err = pcall(function()
        mem:install_read_tap(startAddress, stopAddress, "iltrace-" .. tag, function(address, data)
            counts[tag] = (counts[tag] or 0) + 1
            if counter == "positive" then positiveHits = positiveHits + 1 else boundaryHits = boundaryHits + 1 end
            if counts[tag] <= 8 then recordTap(tag, address, data, phase) end
        end)
    end)
    if not ok then
        cap:write("TAP_FAIL," .. tag .. "," .. tostring(err) .. "\n")
    else
        cap:write(string.format("TAP_INSTALLED,%s,%04X,%04X,%s\n", tag, startAddress, stopAddress, phase))
    end
end

local positive = map.positiveControl or { start = 0x66A0, stop = 0x66F0 }
installTap("positive-control", positive.start, positive.stop, "capability-positive-control-not-il", "positive")
for _, node in ipairs(map.nodes) do
    installTap(string.format("node-%d", node.index), node.address, node.address + 1, "data-tap-at-il-node-not-instruction-boundary", "boundary")
end
for _, handler in ipairs(map.handlers or {}) do
    installTap("handler-" .. string.format("%04X", handler.address), handler.address, handler.address + 1, "data-tap-at-handler-opcode-not-instruction-boundary", "boundary")
end

local finished = false
local nextSample = 0.0
emu.register_frame_done(function()
    local t = m.time:as_double()
    if t >= nextSample then
        nextSample = nextSample + 1.0
        sampleCount = sampleCount + 1
        samples:write(string.format("%d,%.9f,%04X,%04X,%04X,%04X,%04X,frame-sampled-not-instruction-boundary\n",
            sampleCount, t, cpu.state["PC"].value, cpu.state["X"].value, cpu.state["Y"].value,
            cpu.state["U"].value, cpu.state["S"].value))
        samples:flush()
    end
    if not finished and t >= seconds - 0.5 then
        finished = true
        cap:write(string.format("SUMMARY,positive_control_hits=%d,boundary_tap_hits=%d,frame_samples=%d\n",
            positiveHits, boundaryHits, sampleCount))
        cap:write("COMPLETE_CALL_PROOF=native_debugger_separate,lua_instruction_boundary=false\n")
        cap:write("BOUNDARY_SUPPORT=native_debugger_breakpoints,lua_instruction_callback=false\n")
        cap:flush()
        samples:close()
        taps:close()
        cap:close()
        pcall(function() m:exit() end)
    end
end, "frame")

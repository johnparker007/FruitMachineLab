-- Private derivative of evidence/mpu4/skill-cash/input.lua for the Snake Bite
-- demo launcher. Adds bounded handover: the provider stops writing physical
-- field overrides and clears every override exactly once when the observer
-- calls MPU4InputReleaseAll(). The tracked provider is not modified.
local m = manager.machine
local cpu = m.devices[":maincpu"]
local mem = cpu.spaces["program"]

local inventory = assert(io.open("input-fields.txt", "w"))
for tag, port in pairs(m.ioport.ports) do
    for name, field in pairs(port.fields) do
        inventory:write(tag, " ", name, " mask=", tostring(field.mask), "\n")
    end
end
inventory:close()

local replay = os.getenv("MPU4_REPLAY")
local events = {}
if replay then
    for line in io.lines(replay) do
        local f, l, p, k = line:match("^(%d+),(%d+),([^,]+),(%d+),")
        if f then
            table.insert(events, { first = tonumber(f), last = tonumber(l), port = p, mask = tonumber(k) })
        end
    end
end

local controls = {}
local ownedKeys = {}
for _, mask in ipairs({ 1, 2, 4, 8, 16, 32, 64, 128 }) do
    local key = ":BLACK2:" .. mask
    controls[key] = assert(m.ioport.ports[":BLACK2"]:field(mask))
    ownedKeys[#ownedKeys + 1] = key
end
controls[":AUX2:128"] = assert(m.ioport.ports[":AUX2"]:field(128))
ownedKeys[#ownedKeys + 1] = ":AUX2:128"
table.sort(ownedKeys)

local function seqText(field, kind, seqType)
    local ok, seq
    if kind == "input_seq" then
        ok, seq = pcall(function() return field:input_seq(seqType) end)
    else
        ok, seq = pcall(function() return field:default_input_seq(seqType) end)
    end
    if not ok then return "ERROR:" .. tostring(seq) end
    local nameOk, name = pcall(function() return m.input:seq_name(seq) end)
    local tokenOk, tokens = pcall(function() return m.input:seq_to_tokens(seq) end)
    local lengthOk, length = pcall(function() return seq.length end)
    local emptyOk, empty = pcall(function() return seq.empty end)
    return string.format("name=%s tokens=%s length=%s empty=%s",
        nameOk and tostring(name) or "ERROR",
        tokenOk and tostring(tokens) or "ERROR",
        lengthOk and tostring(length) or "ERROR",
        emptyOk and tostring(empty) or "ERROR")
end

local bindings = assert(io.open("input-bindings.txt", "w"))
bindings:write("owned fields with actual/default input bindings (read-only; no bindings are changed)\n")
for _, key in ipairs(ownedKeys) do
    local field = controls[key]
    bindings:write(string.format("%s name=%s mask=%s type_class=%s\n",
        key, tostring(field.name), string.format("%X", field.mask), tostring(field.type_class)))
    bindings:write("  standard " .. seqText(field, "input_seq", "standard") .. "\n")
    bindings:write("  default  " .. seqText(field, "default_input_seq", "standard") .. "\n")
end
bindings:close()

local writes = assert(io.open("input-writes.csv", "w"))
writes:write("frame,t,op,key,value_or_ok\n")
local levels = assert(io.open("input-levels.csv", "w"))
levels:write("frame,t,aux2,black2,active_overrides,handover\n")

local frame = 0
local handover = false
local handoverReason = ""
local last = {}
local writeCount = 0

local function recordWrite(op, key, value)
    writes:write(string.format("%d,%.9f,%s,%s,%s\n", frame, m.time:as_double(), op, key, tostring(value)))
    writes:flush()
    writeCount = writeCount + 1
end

for _, key in ipairs(ownedKeys) do
    local ok, err = pcall(function() controls[key]:set_value(0) end)
    recordWrite("set_initial", key, ok and 0 or ("ERROR:" .. tostring(err)))
    if ok then last[key] = 0 end
end

local ownership = assert(io.open("input-ownership.json", "w"))
ownership:write(string.format('{"provider":"ReplayInput.lua","replay":"%s","owned":%d,"handover":false,"writes":%d}\n',
    tostring(replay):gsub("\\", "\\\\"):gsub('"', '\\"'), #ownedKeys, writeCount))
ownership:close()

function MPU4InputHandoverSupported()
    return true
end

function MPU4InputReleaseAll(reason)
    if handover then return true, "already-cleared" end
    handoverReason = tostring(reason or "")
    local cleared = 0
    for _, key in ipairs(ownedKeys) do
        local ok, err = pcall(function() controls[key]:clear_value() end)
        recordWrite("clear", key, ok and "ok" or ("ERROR:" .. tostring(err)))
        if ok then
            cleared = cleared + 1
            last[key] = nil
        end
    end
    handover = true
    levels:flush()
    local after = assert(io.open("input-ownership-after-handover.json", "w"))
    after:write(string.format('{"provider":"ReplayInput.lua","reason":"%s","handover":true,"cleared":%d,"owned":%d,"frame":%d,"t":%.9f}\n',
        handoverReason:gsub("\\", "\\\\"):gsub('"', '\\"'), cleared, #ownedKeys, frame, m.time:as_double()))
    after:close()
    return true, cleared
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

emu.register_frame_done(function()
    local t = m.time:as_double()
    frame = frame + 1
    if not handover then
        local desired = {}
        for _, e in ipairs(events) do
            if frame >= e.first and frame < e.last then
                desired[e.port .. ":" .. e.mask] = true
            end
        end
        for _, key in ipairs(ownedKeys) do
            local want = desired[key] and 1 or 0
            if last[key] ~= want then
                local field = controls[key]
                local ok, err = pcall(function() field:set_value(want) end)
                recordWrite(ok and "set" or "set_error", key, ok and want or ("ERROR:" .. tostring(err)))
                if ok then last[key] = want end
            end
        end
    end
    local active = 0
    for _, key in ipairs(ownedKeys) do
        if last[key] ~= nil then active = active + 1 end
    end
    levels:write(string.format("%d,%.9f,%02X,%02X,%d,%d\n",
        frame, t, m.ioport.ports[":AUX2"]:read(), m.ioport.ports[":BLACK2"]:read(), active, handover and 1 or 0))
    if frame % 30 == 0 then levels:flush() end
end, "replay-input")

-- Keep the display observation available to downstream scripts without writing
-- a second copy of the original bulky state logs.
function MPU4InputDisplay()
    return displayText()
end

local taskId = "il-lamp-output-api-window-86"
local callbackName = "emu.register_frame_done"
local lampName = "lamp120"
local lampBase = "lamp"
local lampIndex = 120
local missingName = "fruitmachinelab_missing_output_85"
local samplePath = "api-probe-samples.jsonl"
local resultPath = "api-probe-result.json"
local minimumObservationSeconds = 0.05
local maximumEmulatedSeconds = 2.0
local maximumSamples = 121

local jsonNull = setmetatable({}, { __jsontype = "null" })

local function jsonArray(items)
    return setmetatable({ items = items or {} }, { __jsontype = "array" })
end

local function jsonQuote(value)
    local text = tostring(value)
    text = text:gsub("\\", "\\\\")
    text = text:gsub("\"", "\\\"")
    text = text:gsub("\n", "\\n")
    text = text:gsub("\r", "\\r")
    text = text:gsub("\t", "\\t")
    text = text:gsub("%c", function(character)
        return string.format("\\u%04x", string.byte(character))
    end)
    text = text:gsub("[\128-\255]", function(character)
        return string.format("\\u%04x", string.byte(character))
    end)
    return "\"" .. text .. "\""
end

local function finiteNumber(value)
    if type(value) ~= "number" then
        return false
    end
    if value ~= value then
        return false
    end
    if value == math.huge or value == -math.huge then
        return false
    end
    return true
end

local function encode(value, seen)
    if value == jsonNull then
        return "null"
    end
    local kind = type(value)
    if kind == "nil" then
        return "null"
    end
    if kind == "boolean" then
        if value then
            return "true"
        end
        return "false"
    end
    if kind == "number" then
        if not finiteNumber(value) then
            return "null"
        end
        if value ~= math.floor(value) then
            return string.format("%.9f", value)
        end
        return string.format("%.0f", value)
    end
    if kind == "string" then
        return jsonQuote(value)
    end
    if kind == "table" then
        local metatable = getmetatable(value)
        local jsonType = metatable and metatable.__jsontype or nil
        if jsonType == "null" then
            return "null"
        end
        seen = seen or {}
        if seen[value] then
            return jsonQuote("<cycle>")
        end
        seen[value] = true
        if jsonType == "array" then
            local items = value.items or {}
            local parts = {}
            for index = 1, #items do
                parts[#parts + 1] = encode(items[index], seen)
            end
            seen[value] = nil
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local keys = {}
        for key in pairs(value) do
            if type(key) == "string" then
                keys[#keys + 1] = key
            end
        end
        table.sort(keys)
        local parts = {}
        for _, key in ipairs(keys) do
            parts[#parts + 1] = jsonQuote(key) .. ":" .. encode(value[key], seen)
        end
        seen[value] = nil
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return jsonQuote("<unsupported " .. kind .. ">")
end

local function typeName(value)
    if value == nil then
        return "nil"
    end
    return type(value)
end

local function subtypeName(value)
    if type(value) ~= "number" then
        return "none"
    end
    if math.type then
        local subtype = math.type(value)
        if subtype then
            return subtype
        end
    end
    if finiteNumber(value) and value == math.floor(value) then
        return "integer"
    end
    return "float"
end

local function captureValue(value)
    local record = {
        present = true,
        type = typeName(value),
        subtype = subtypeName(value),
        value = jsonNull,
        finite = jsonNull,
        serializable = true,
        error = jsonNull,
        errorType = jsonNull
    }
    if value == nil then
        record.present = false
        record.serializable = false
        return record
    end
    local kind = type(value)
    if kind == "boolean" then
        record.value = value
    elseif kind == "string" then
        record.value = value
    elseif kind == "number" then
        if finiteNumber(value) then
            record.value = value
            record.finite = true
        else
            record.finite = false
            record.serializable = false
            record.error = "nonfinite number"
            record.errorType = "number"
        end
    else
        record.serializable = false
        record.error = "non-serializable " .. kind .. " value"
        record.errorType = kind
    end
    return record
end

local function errorReturnedValue()
    return {
        present = false,
        type = "error",
        subtype = "none",
        value = jsonNull,
        finite = jsonNull,
        serializable = false,
        error = jsonNull,
        errorType = jsonNull
    }
end

local function callRecord(ok, value)
    if not ok then
        return {
            called = true,
            pcallOk = false,
            error = tostring(value),
            returned = errorReturnedValue()
        }
    end
    return {
        called = true,
        pcallOk = true,
        error = jsonNull,
        returned = captureValue(value)
    }
end

local function notCalledRecord(reason)
    return {
        called = false,
        pcallOk = false,
        error = reason,
        returned = errorReturnedValue()
    }
end

local function rawNumber(record)
    if not record or not record.pcallOk then
        return nil
    end
    local value = record.returned.value
    if type(value) == "number" and finiteNumber(value) then
        return value
    end
    return nil
end

local function describeRecord(record)
    if not record then
        return "missing record"
    end
    if not record.pcallOk then
        return "call error " .. tostring(record.error)
    end
    local returned = record.returned
    if returned.value == jsonNull then
        if returned.error ~= jsonNull then
            return returned.type .. " " .. tostring(returned.error)
        end
        return returned.type .. " null"
    end
    return returned.type .. " " .. tostring(returned.value)
end

local function integralId(record)
    local value = rawNumber(record)
    if value == nil then
        return nil
    end
    if value ~= math.floor(value) then
        return nil
    end
    if value < 1 or value > 4294967295 then
        return nil
    end
    return value
end

local function binaryValue(record)
    local value = rawNumber(record)
    if value == nil then
        return nil
    end
    if value ~= math.floor(value) then
        return nil
    end
    if value == 0 or value == 1 then
        return value
    end
    return nil
end

local function emptySample(seq, emulatedTime)
    return {
        seq = seq,
        taskId = taskId,
        schemaVersion = 1,
        naturalProof = false,
        callback = callbackName,
        emulatedTimeSeconds = finiteNumber(emulatedTime) and emulatedTime or jsonNull,
        emulatedTime = captureValue(emulatedTime),
        outputApiPresent = false,
        lamp = {
            requestedName = lampName,
            nameToId = notCalledRecord("not called"),
            idToName = notCalledRecord("not called"),
            getValue = notCalledRecord("not called"),
            getIndexedValue = notCalledRecord("not called"),
            binary = false,
            binaryReason = "not evaluated"
        },
        missingName = {
            requestedName = missingName,
            nameToId = notCalledRecord("not called"),
            getValue = notCalledRecord("not called"),
            nameToIdZero = false,
            countsAsExistingOutput = false
        },
        opaqueId = jsonNull,
        identity = {
            firstId = jsonNull,
            currentId = jsonNull,
            stable = jsonNull,
            changed = jsonNull
        },
        errors = jsonArray({}),
        status = "observed"
    }
end

local function nonBinarySummary(sample)
    if not sample then
        return jsonNull
    end
    return {
        seq = sample.seq,
        emulatedTimeSeconds = sample.emulatedTimeSeconds,
        opaqueId = sample.opaqueId,
        getValue = sample.lamp.getValue.returned,
        getIndexedValue = sample.lamp.getIndexedValue.returned,
        reason = sample.lamp.binaryReason
    }
end

local samples = 0
local nonBinaryCount = 0
local firstId = nil
local firstNonBinary = nil
local lastSample = nil
local sampleHandle = nil
local sampleFileCreated = false
local finished = false

local function closeSamples()
    if sampleHandle then
        pcall(function()
            sampleHandle:flush()
            sampleHandle:close()
        end)
        sampleHandle = nil
    end
end

local function appendSample(sample)
    if not sampleHandle then
        local handle, openError = io.open(samplePath, "w")
        if not handle then
            return false, tostring(openError)
        end
        sampleHandle = handle
        sampleFileCreated = true
    end
    local ok, writeError = pcall(function()
        sampleHandle:write(encode(sample))
        sampleHandle:write("\n")
        sampleHandle:flush()
    end)
    if not ok then
        return false, tostring(writeError)
    end
    return true, nil
end

local function writeFinal(result)
    local handle, openError = io.open(resultPath, "w")
    if not handle then
        print("WINDOW_RESULT_WRITE_FAILED=" .. tostring(openError))
        return false
    end
    local ok, writeError = pcall(function()
        handle:write(encode(result))
        handle:write("\n")
        handle:flush()
    end)
    pcall(function()
        handle:close()
    end)
    if not ok then
        print("WINDOW_RESULT_WRITE_FAILED=" .. tostring(writeError))
        return false
    end
    print("WINDOW_RESULT_CLASSIFICATION=" .. tostring(result.classification))
    print("WINDOW_RESULT_SAMPLE_COUNT=" .. tostring(result.window.observedSampleCount))
    print("WINDOW_RESULT_PATH=" .. resultPath)
    return true
end

local function requestExit(machine)
    if machine then
        pcall(function()
            machine:exit()
        end)
    end
end

local function finish(machine, classification, rawError, emulatedTime, stopReason)
    if finished then
        return
    end
    finished = true
    closeSamples()
    local finalErrors = {}
    if rawError ~= nil then
        finalErrors[#finalErrors + 1] = tostring(rawError)
    end
    local lastId = nil
    if lastSample and lastSample.opaqueId ~= jsonNull then
        lastId = rawNumber({ pcallOk = true, returned = lastSample.opaqueId })
        if lastId ~= nil and lastId ~= math.floor(lastId) then
            lastId = nil
        end
    end
    local identityStable = jsonNull
    if firstId ~= nil and lastId ~= nil then
        identityStable = firstId == lastId
    end
    local precedingSampleCount = samples
    if samples > 0 and classification ~= "inconclusive_no_binary_in_window" then
        precedingSampleCount = samples - 1
    end
    local timeCapReached = false
    if classification == "inconclusive_no_binary_in_window" and finiteNumber(emulatedTime) and emulatedTime >= maximumEmulatedSeconds then
        timeCapReached = true
    end
    local final = {
        taskId = taskId,
        schemaVersion = 1,
        resultSchema = 1,
        naturalProof = false,
        callback = callbackName,
        classification = classification,
        stopReason = stopReason or jsonNull,
        rawError = rawError ~= nil and tostring(rawError) or jsonNull,
        emulatedTimeSeconds = finiteNumber(emulatedTime) and emulatedTime or jsonNull,
        emulatedTime = captureValue(emulatedTime),
        sampleFile = samplePath,
        resultFile = resultPath,
        window = {
            minimumObservationSeconds = minimumObservationSeconds,
            maximumEmulatedSeconds = maximumEmulatedSeconds,
            maximumSamples = maximumSamples,
            observedSampleCount = samples,
            nonBinarySampleCount = nonBinaryCount,
            precedingSampleCount = precedingSampleCount,
            precedingNonBinarySampleCount = nonBinaryCount,
            sampleCapReached = samples >= maximumSamples,
            timeCapReached = timeCapReached,
            sampleFileCreated = sampleFileCreated
        },
        firstSampleOpaqueId = firstId ~= nil and captureValue(firstId) or jsonNull,
        lastSampleOpaqueId = lastSample and lastSample.opaqueId or jsonNull,
        identityStable = identityStable,
        firstNonBinaryValue = nonBinarySummary(firstNonBinary),
        lastSample = lastSample or jsonNull,
        errors = jsonArray(finalErrors),
        limitations = {
            readOnlyOutputApiCallsOnly = true,
            cpuReads = false,
            memoryReads = false,
            inputReads = false,
            debugAccess = false,
            mutationCalls = false,
            naturalProof = false
        },
        note = "Bounded read-only output API observation only; naturalProof=false. No lamp transition, natural game, ROM behaviour, compiled change or hardware proof is claimed."
    }
    writeFinal(final)
    requestExit(machine)
end

local function observe(machine, emulatedTime, seq)
    local errors = {}
    local sample = emptySample(seq, emulatedTime)
    local function fail(classification, message)
        errors[#errors + 1] = message
        sample.errors = jsonArray(errors)
        sample.status = "error"
        return sample, { classification = classification, rawError = message }
    end
    local outputOk, output = pcall(function()
        return machine.output
    end)
    if not outputOk then
        return fail("inconclusive_output_api_unavailable", "manager.machine.output access failed: " .. tostring(output))
    end
    if output == nil then
        return fail("inconclusive_output_api_unavailable", "manager.machine.output is nil")
    end
    sample.outputApiPresent = true
    local methodNames = { "name_to_id", "id_to_name", "get_value", "get_indexed_value" }
    local missingMethods = {}
    for _, name in ipairs(methodNames) do
        local methodOk, method = pcall(function()
            return output[name]
        end)
        if not methodOk then
            return fail("inconclusive_output_api_unavailable", "output." .. name .. " access failed: " .. tostring(method))
        end
        if method == nil then
            missingMethods[#missingMethods + 1] = name
        end
    end
    if #missingMethods > 0 then
        return fail("inconclusive_output_api_unavailable", "missing output methods: " .. table.concat(missingMethods, ","))
    end
    local nameOk, nameValue = pcall(function()
        return output:name_to_id(lampName)
    end)
    sample.lamp.nameToId = callRecord(nameOk, nameValue)
    if not nameOk then
        return fail("inconclusive_api_error", "name_to_id(" .. lampName .. ") call failed: " .. tostring(nameValue))
    end
    local currentId = integralId(sample.lamp.nameToId)
    if firstId == nil then
        if currentId == nil then
            sample.opaqueId = sample.lamp.nameToId.returned
            return fail("inconclusive_name_identity", "name_to_id(" .. lampName .. ") did not return a nonzero 32-bit integer: " .. describeRecord(sample.lamp.nameToId))
        end
        firstId = currentId
    else
        local rawId = rawNumber(sample.lamp.nameToId)
        if rawId == nil or rawId ~= firstId then
            sample.opaqueId = sample.lamp.nameToId.returned
            return fail("inconclusive_identity_changed", "opaque output ID changed from " .. tostring(firstId) .. " to " .. describeRecord(sample.lamp.nameToId))
        end
        currentId = firstId
    end
    sample.opaqueId = sample.lamp.nameToId.returned
    sample.identity.firstId = captureValue(firstId)
    sample.identity.currentId = sample.opaqueId
    sample.identity.stable = true
    sample.identity.changed = false
    local roundtripOk, roundtripValue = pcall(function()
        return output:id_to_name(currentId)
    end)
    sample.lamp.idToName = callRecord(roundtripOk, roundtripValue)
    if not roundtripOk then
        return fail("inconclusive_api_error", "id_to_name(" .. tostring(currentId) .. ") call failed: " .. tostring(roundtripValue))
    end
    local roundtrip = sample.lamp.idToName.returned.value
    if type(roundtrip) ~= "string" or roundtrip ~= lampName then
        return fail("inconclusive_name_identity", "id_to_name(" .. tostring(currentId) .. ") returned " .. describeRecord(sample.lamp.idToName) .. ", expected exact " .. lampName)
    end
    local getOk, getValue = pcall(function()
        return output:get_value(lampName)
    end)
    sample.lamp.getValue = callRecord(getOk, getValue)
    if not getOk then
        return fail("inconclusive_api_error", "get_value(" .. lampName .. ") call failed: " .. tostring(getValue))
    end
    local indexedOk, indexedValue = pcall(function()
        return output:get_indexed_value(lampBase, lampIndex)
    end)
    sample.lamp.getIndexedValue = callRecord(indexedOk, indexedValue)
    if not indexedOk then
        return fail("inconclusive_api_error", "get_indexed_value(" .. lampBase .. "," .. tostring(lampIndex) .. ") call failed: " .. tostring(indexedValue))
    end
    local missingOk, missingValue = pcall(function()
        return output:name_to_id(missingName)
    end)
    sample.missingName.nameToId = callRecord(missingOk, missingValue)
    if not missingOk then
        return fail("inconclusive_api_error", "name_to_id(" .. missingName .. ") call failed: " .. tostring(missingValue))
    end
    local missingGetOk, missingGetValue = pcall(function()
        return output:get_value(missingName)
    end)
    sample.missingName.getValue = callRecord(missingGetOk, missingGetValue)
    if not missingGetOk then
        return fail("inconclusive_api_error", "get_value(" .. missingName .. ") call failed: " .. tostring(missingGetValue))
    end
    local missingId = rawNumber(sample.missingName.nameToId)
    if missingId == nil or missingId ~= 0 then
        sample.missingName.nameToIdZero = false
        return fail("inconclusive_missing_negative_control", "name_to_id(" .. missingName .. ") returned " .. describeRecord(sample.missingName.nameToId) .. ", expected 0")
    end
    sample.missingName.nameToIdZero = true
    sample.missingName.countsAsExistingOutput = false
    local getNumber = binaryValue(sample.lamp.getValue)
    local indexedNumber = binaryValue(sample.lamp.getIndexedValue)
    if getNumber ~= nil and indexedNumber ~= nil and getNumber == indexedNumber then
        sample.lamp.binary = true
        sample.lamp.binaryReason = "get_value and get_indexed_value are equal integral 0 or 1"
        sample.status = "binary_observed"
    else
        sample.lamp.binary = false
        if getNumber == nil and indexedNumber == nil then
            sample.lamp.binaryReason = "get_value and get_indexed_value are not integral 0 or 1"
        elseif getNumber == nil then
            sample.lamp.binaryReason = "get_value is not an integral 0 or 1"
        elseif indexedNumber == nil then
            sample.lamp.binaryReason = "get_indexed_value is not an integral 0 or 1"
        else
            sample.lamp.binaryReason = "get_value and get_indexed_value disagree"
        end
        sample.status = "nonbinary_observed"
    end
    sample.errors = jsonArray(errors)
    return sample, nil
end

emu.register_frame_done(function()
    if finished then
        return
    end
    local machine = manager and manager.machine
    if not machine then
        finish(nil, "inconclusive_machine_unavailable", "manager.machine is unavailable", nil, "machine unavailable")
        return
    end
    local timeOk, timeValue = pcall(function()
        return machine.time:as_double()
    end)
    if not timeOk then
        finish(machine, "inconclusive_time_error", "emulated time read failed: " .. tostring(timeValue), nil, "emulated time read failed")
        return
    end
    if not finiteNumber(timeValue) then
        finish(machine, "inconclusive_time_error", "emulated time is not finite: " .. tostring(timeValue), timeValue, "nonfinite emulated time")
        return
    end
    if timeValue < minimumObservationSeconds then
        return
    end
    if timeValue > maximumEmulatedSeconds then
        finish(machine, "inconclusive_no_binary_in_window", nil, timeValue, "emulated time cap reached before a binary sample")
        return
    end
    if samples >= maximumSamples then
        finish(machine, "inconclusive_no_binary_in_window", nil, timeValue, "sample cap reached before a binary sample")
        return
    end
    local observed, sample, fatal = pcall(observe, machine, timeValue, samples + 1)
    if not observed then
        local errorSample = emptySample(samples + 1, timeValue)
        errorSample.errors = jsonArray({ "observation exception: " .. tostring(sample) })
        errorSample.status = "error"
        samples = samples + 1
        lastSample = errorSample
        local wrote, writeError = appendSample(errorSample)
        if not wrote then
            print("WINDOW_SAMPLE_WRITE_FAILED=" .. tostring(writeError))
            finish(machine, "inconclusive_sample_write_failed", "sample write failed: " .. tostring(writeError), timeValue, "sample write failed")
            return
        end
        finish(machine, "inconclusive_observation_exception", "observation exception: " .. tostring(sample), timeValue, "observation exception")
        return
    end
    samples = samples + 1
    lastSample = sample
    local wrote, writeError = appendSample(sample)
    if not wrote then
        print("WINDOW_SAMPLE_WRITE_FAILED=" .. tostring(writeError))
        finish(machine, "inconclusive_sample_write_failed", "sample write failed: " .. tostring(writeError), timeValue, "sample write failed")
        return
    end
    if fatal then
        finish(machine, fatal.classification, fatal.rawError, timeValue, fatal.rawError)
        return
    end
    if sample.lamp.binary then
        finish(machine, "capability_binary_observed", nil, timeValue, "first sample with valid identity, exact roundtrip name, binary get==indexed and missing name ID 0")
        return
    end
    nonBinaryCount = nonBinaryCount + 1
    if firstNonBinary == nil then
        firstNonBinary = sample
    end
    if samples >= maximumSamples then
        finish(machine, "inconclusive_no_binary_in_window", nil, timeValue, "sample cap reached after the final allowed nonbinary sample")
        return
    end
    if timeValue >= maximumEmulatedSeconds then
        finish(machine, "inconclusive_no_binary_in_window", nil, timeValue, "emulated time cap reached after the final nonbinary sample")
        return
    end
end, "il-lamp-output-api-window-86")

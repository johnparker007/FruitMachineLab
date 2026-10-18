[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('Parse','Negative','Serializer')][string]$Mode,
    [string]$EventsPath,
    [string]$OutputPath,
    [string]$SourcePath,
    [string]$MameExecutable,
    [string]$RomDirectory,
    [string]$RunDirectory,
    [string]$LegacyEventsPath,
    [string]$ExpectedMameSha256,
    [ValidateRange(10,600)][int]$TimeoutSeconds = 120
)
$ErrorActionPreference = 'Stop'
$script:Utf8 = New-Object System.Text.UTF8Encoding($false)

function Get-Sha256([string]$Path) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [IO.File]::ReadAllBytes($Path)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()
    }
    finally { $sha.Dispose() }
}

function Write-JsonFile([string]$Path,$Object) {
    $parent = Split-Path -Parent $Path
    if (![string]::IsNullOrWhiteSpace($parent) -and !(Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $json = ConvertTo-Json -InputObject $Object -Depth 30
    [IO.File]::WriteAllText($Path, $json, $script:Utf8)
}

function Read-StrictDocument([string]$Text) {
    $options = [System.Text.Json.JsonDocumentOptions]::new()
    $options.AllowTrailingCommas = $false
    $options.CommentHandling = [System.Text.Json.JsonCommentHandling]::Disallow
    return [System.Text.Json.JsonDocument]::Parse($Text, $options)
}

function Test-StrictObjectLine([string]$Text) {
    $doc = $null
    try {
        $doc = Read-StrictDocument $Text
        if ($doc.RootElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
            return [ordered]@{ ok = $false; error = 'root is not a JSON object' }
        }
        $eventCount = 0
        $eventName = $null
        foreach ($prop in $doc.RootElement.EnumerateObject()) {
            if ($prop.Name -ceq 'event') {
                $eventCount++
                if ($prop.Value.ValueKind -ne [System.Text.Json.JsonValueKind]::String) {
                    return [ordered]@{ ok = $false; error = 'event is not a string' }
                }
                $eventName = $prop.Value.GetString()
            }
        }
        if ($eventCount -ne 1) {
            return [ordered]@{ ok = $false; error = "expected exactly one event property, found $eventCount" }
        }
        return [ordered]@{ ok = $true; error = ''; event = $eventName }
    }
    catch {
        return [ordered]@{ ok = $false; error = $_.Exception.Message }
    }
    finally {
        if ($null -ne $doc) { $doc.Dispose() }
    }
}

function Read-EventLines([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $text = [Text.Encoding]::UTF8.GetString($bytes)
    if ($text.Length -gt 0 -and [int][char]$text[0] -eq 0xFEFF) { throw "Events file has a BOM: $Path" }
    return [ordered]@{ bytes = $bytes.Length; text = $text; lines = @($text -split "`n") }
}

function Invoke-ParseMode {
    if ([string]::IsNullOrWhiteSpace($EventsPath)) { throw 'EventsPath is required for Parse mode' }
    if ([string]::IsNullOrWhiteSpace($OutputPath)) { throw 'OutputPath is required for Parse mode' }
    $file = Read-EventLines $EventsPath
    $records = New-Object 'System.Collections.Generic.List[object]'
    $failures = New-Object 'System.Collections.Generic.List[object]'
    $eventCounts = [ordered]@{}
    $nonblank = 0
    $lineNumber = 0
    foreach ($line in $file.lines) {
        $lineNumber++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $nonblank++
        $checked = Test-StrictObjectLine $line
        if (!$checked.ok) {
            $failures.Add([ordered]@{ line = $lineNumber; error = $checked.error; text = $line })
            continue
        }
        try {
            $record = $line | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            $failures.Add([ordered]@{ line = $lineNumber; error = ('ConvertFrom-Json: ' + $_.Exception.Message); text = $line })
            continue
        }
        $records.Add($record)
        if ($eventCounts.Contains($checked.event)) { $eventCounts[$checked.event] = [int]$eventCounts[$checked.event] + 1 }
        else { $eventCounts[$checked.event] = 1 }
    }
    $summary = [ordered]@{
        mode = 'parse'
        path = [IO.Path]::GetFullPath($EventsPath)
        sha256 = Get-Sha256 $EventsPath
        bytes = $file.bytes
        nonblank = $nonblank
        recordCount = $records.Count
        eventCounts = $eventCounts
        records = $records.ToArray()
        failures = $failures.ToArray()
        pass = ($failures.Count -eq 0 -and $nonblank -eq $records.Count)
    }
    Write-JsonFile $OutputPath $summary
    if (!$summary.pass) {
        foreach ($failure in $summary.failures) { Write-Output ("INVALID line {0}: {1}" -f $failure.line, $failure.error) }
        throw "Strict JSONL parse rejected $($failures.Count) record(s) in $EventsPath"
    }
}

function Invoke-NegativeMode {
    if ([string]::IsNullOrWhiteSpace($OutputPath)) { throw 'OutputPath is required for Negative mode' }
    $cases = New-Object 'System.Collections.Generic.List[object]'
    function Add-Negative([string]$Name,[string]$Text,[string]$Reason) {
        $checked = Test-StrictObjectLine $Text
        $cases.Add([ordered]@{
            name = $Name
            expected = 'rejected'
            rejected = (-not $checked.ok)
            reason = $Reason
            parserError = $checked.error
            text = $Text
        })
    }
    Add-Negative 'trailing_comma' '{"event":"probe","value":1,}' 'trailing comma before object close'
    Add-Negative 'trailing_comma_no_fields' '{"event":"probe",}' 'trailing comma with no fields'
    Add-Negative 'raw_tab' ('{"event":"probe","text":"a' + [char]9 + 'b"}') 'unescaped U+0009 inside a string'
    Add-Negative 'raw_lf' ('{"event":"probe","text":"a' + [char]10 + 'b"}') 'unescaped U+000A inside a string'
    Add-Negative 'raw_cr' ('{"event":"probe","text":"a' + [char]13 + 'b"}') 'unescaped U+000D inside a string'
    Add-Negative 'raw_nul' ('{"event":"probe","text":"a' + [char]0 + 'b"}') 'unescaped U+0000 inside a string'
    Add-Negative 'raw_control_1f' ('{"event":"probe","text":"a' + [char]31 + 'b"}') 'unescaped U+001F inside a string'
    Add-Negative 'raw_backspace' ('{"event":"probe","text":"a' + [char]8 + 'b"}') 'unescaped U+0008 inside a string'

    $positiveText = '{"event":"probe","text":"a\tb\nc\rd\u0000e\u001ff\"g\\h"}'
    $expectedText = "a`tb`nc`rd$([char]0)e$([char]0x1f)f`"g\h"
    $positiveChecked = Test-StrictObjectLine $positiveText
    $positiveOk = $false
    $positiveDecoded = $null
    $positiveError = ''
    if ($positiveChecked.ok) {
        $doc = $null
        try {
            $doc = Read-StrictDocument $positiveText
            $positiveDecoded = $doc.RootElement.GetProperty('text').GetString()
            $positiveOk = ($positiveDecoded -ceq $expectedText)
        }
        catch { $positiveError = $_.Exception.Message }
        finally { if ($null -ne $doc) { $doc.Dispose() } }
    }
    else { $positiveError = $positiveChecked.error }

    $legacy = $null
    if (![string]::IsNullOrWhiteSpace($LegacyEventsPath) -and (Test-Path -LiteralPath $LegacyEventsPath -PathType Leaf)) {
        $legacyFile = Read-EventLines $LegacyEventsPath
        $legacyLines = 0
        $legacyRejected = 0
        $legacyFirstError = ''
        foreach ($line in $legacyFile.lines) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $legacyLines++
            $checked = Test-StrictObjectLine $line
            if (!$checked.ok) {
                $legacyRejected++
                if ([string]::IsNullOrWhiteSpace($legacyFirstError)) { $legacyFirstError = $checked.error }
            }
        }
        $legacy = [ordered]@{
            path = [IO.Path]::GetFullPath($LegacyEventsPath)
            sha256 = Get-Sha256 $LegacyEventsPath
            nonblank = $legacyLines
            rejected = $legacyRejected
            firstError = $legacyFirstError
            pass = ($legacyLines -gt 0 -and $legacyRejected -eq $legacyLines)
        }
        $cases.Add([ordered]@{
            name = 'preserved_step10_events'
            expected = 'rejected'
            rejected = $legacy.pass
            reason = 'prior serializer output with trailing commas'
            parserError = $legacy.firstError
            text = ''
        })
    }
    elseif (![string]::IsNullOrWhiteSpace($LegacyEventsPath)) {
        $legacy = [ordered]@{ path = [IO.Path]::GetFullPath($LegacyEventsPath); pass = $false; error = 'file missing' }
    }

    $allRejected = $true
    foreach ($case in $cases) { if (!$case.rejected) { $allRejected = $false } }
    $summary = [ordered]@{
        mode = 'negative'
        negativeCount = $cases.Count
        allRejected = $allRejected
        positiveAccepted = $positiveChecked.ok
        positiveDecoded = $positiveOk
        expectedTextLength = $expectedText.Length
        decodedTextLength = if ($null -ne $positiveDecoded) { $positiveDecoded.Length } else { -1 }
        positiveError = $positiveError
        legacy = $legacy
        cases = $cases.ToArray()
        pass = ($allRejected -and $positiveChecked.ok -and $positiveOk)
    }
    Write-JsonFile $OutputPath $summary
    if (!$summary.pass) { throw 'Strict JSON negative controls did not all pass' }
}

function ConvertTo-LuaString([string]$Text) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"')
    foreach ($b in [Text.Encoding]::UTF8.GetBytes($Text)) {
        if ($b -eq 0x22) { [void]$sb.Append('\"') }
        elseif ($b -eq 0x5C) { [void]$sb.Append('\\') }
        elseif ($b -ge 0x20 -and $b -le 0x7E) { [void]$sb.Append([char]$b) }
        else { [void]$sb.Append('\' + ([int]$b).ToString('000')) }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}

function Quote-Argument([string]$Text) {
    if ($Text -match '[\s"]') { return '"' + $Text.Replace('"','\"') + '"' }
    return $Text
}

function Invoke-SerializerMode {
    foreach ($required in @('SourcePath','MameExecutable','RomDirectory','RunDirectory','OutputPath')) {
        if ([string]::IsNullOrWhiteSpace((Get-Variable -Name $required -ValueOnly))) { throw "$required is required for Serializer mode" }
    }
    if (!(Test-Path -LiteralPath $SourcePath -PathType Leaf)) { throw "Serializer source is missing: $SourcePath" }
    if (!(Test-Path -LiteralPath $MameExecutable -PathType Leaf)) { throw "MAME executable is missing: $MameExecutable" }
    if (!(Test-Path -LiteralPath $RomDirectory -PathType Container)) { throw "ROM directory is missing: $RomDirectory" }
    $mameSha = Get-Sha256 $MameExecutable
    if (![string]::IsNullOrWhiteSpace($ExpectedMameSha256) -and $mameSha -ine $ExpectedMameSha256) {
        throw "MAME SHA256 is $mameSha, expected $ExpectedMameSha256"
    }
    $run = [IO.Path]::GetFullPath($RunDirectory)
    if (Test-Path -LiteralPath $run) { throw "Serializer run directory must be fresh: $run" }
    foreach ($name in @('cfg','nvram','inp','snap','comments','state','diff')) {
        New-Item -ItemType Directory -Path (Join-Path $run $name) -Force | Out-Null
    }

    $cases = New-Object 'System.Collections.Generic.List[object]'
    $cases.Add([ordered]@{ id = 'plain'; text = 'plain ASCII' })
    $cases.Add([ordered]@{ id = 'quote'; text = 'he said "hi"' })
    $cases.Add([ordered]@{ id = 'backslash'; text = 'C:\temp\a\\b' })
    $cases.Add([ordered]@{ id = 'crlf'; text = "line1`r`nline2" })
    $cases.Add([ordered]@{ id = 'tab'; text = "a`tb" })
    $cases.Add([ordered]@{ id = 'nul'; text = ('a' + [char]0 + 'b') })
    $cases.Add([ordered]@{ id = 'controls'; text = (-join (0..31 | ForEach-Object { [char]$_ })) })
    $cases.Add([ordered]@{ id = 'del'; text = ('a' + [char]127 + 'b') })
    $cases.Add([ordered]@{ id = 'mixed'; text = ('"' + '\' + "`r`n`t" + [char]0 + [char]31 + 'é') })

    $casesPath = Join-Path $run 'serializer-cases.lua'
    $casesBuilder = New-Object System.Text.StringBuilder
    [void]$casesBuilder.AppendLine('return {')
    foreach ($case in $cases) {
        [void]$casesBuilder.AppendLine(('  {{ id = {0}, text = {1} }},' -f (ConvertTo-LuaString $case.id), (ConvertTo-LuaString $case.text)))
    }
    [void]$casesBuilder.AppendLine('}')
    [IO.File]::WriteAllText($casesPath, $casesBuilder.ToString(), $script:Utf8)

    $harnessPath = Join-Path $run 'serializer-probe.lua'
    $harness = @'
local function writeText(path, text)
    local f = assert(io.open(path, "wb"))
    f:write(text)
    f:close()
end
local result = {}
local function finish(ok, message)
    result[#result + 1] = "status=" .. (ok and "ok" or "error")
    result[#result + 1] = "luaVersion=" .. tostring(_VERSION)
    if message then result[#result + 1] = "message=" .. tostring(message):gsub("[\r\n]", " ") end
    local path = os.getenv("FML_SERIALIZER_RESULT")
    if path then
        local f = io.open(path, "wb")
        if f then f:write(table.concat(result, "\n") .. "\n"); f:close() end
    end
    if manager and manager.machine then manager.machine:exit() end
end

local ok, err = pcall(function()
    local sourcePath = assert(os.getenv("FML_SERIALIZER_SOURCE"), "source path missing")
    local outputPath = assert(os.getenv("FML_SERIALIZER_OUTPUT"), "output path missing")
    local casesPath = assert(os.getenv("FML_SERIALIZER_CASES"), "cases path missing")
    local f = assert(io.open(sourcePath, "rb"))
    local source = f:read("*a")
    f:close()
    local beginMarker = "-- BEGIN-EVENT-JSON-SERIALIZER"
    local endMarker = "-- END-EVENT-JSON-SERIALIZER"
    local s = source:find(beginMarker, 1, true)
    local e = source:find(endMarker, 1, true)
    assert(s and e and e > s, "serializer markers are missing")
    local block = source:sub(s + #beginMarker, e - 1)
    local writes = {}
    local events = {
        write = function(self, text) writes[#writes + 1] = text end,
        flush = function(self) end
    }
    local env = {
        events = events, string = string, table = table, math = math,
        type = type, tostring = tostring, pairs = pairs, ipairs = ipairs
    }
    local chunk, loadError
    if _VERSION == "Lua 5.1" then
        chunk, loadError = loadstring(block .. "\nreturn jsonValue, logEvent\n")
        if chunk then setfenv(chunk, env) end
    else
        chunk, loadError = load(block .. "\nreturn jsonValue, logEvent\n", "@event-serializer", "t", env)
    end
    assert(chunk, tostring(loadError))
    local jsonValue, logEvent = chunk()
    assert(type(jsonValue) == "function" and type(logEvent) == "function", "serializer functions missing")
    local cases = dofile(casesPath)
    assert(type(cases) == "table" and #cases > 0, "cases are missing")
    for _, case in ipairs(cases) do
        logEvent("serializer_probe", { probeId = case.id, text = case.text })
    end
    logEvent("serializer_probe_empty", {})
    logEvent("serializer_probe_nil")
    local specialKey = 'key"\\\t\1end'
    logEvent("serializer_probe_key", { probeId = "special-key", [specialKey] = "key-value" })
    writeText(outputPath, table.concat(writes))
    result[#result + 1] = "writes=" .. tostring(#writes)
    result[#result + 1] = "caseCount=" .. tostring(#cases)
end)
finish(ok, err)
'@
    [IO.File]::WriteAllText($harnessPath, $harness, $script:Utf8)

    $outputEvents = Join-Path $run 'serializer-events.jsonl'
    $resultPath = Join-Path $run 'serializer-result.txt'
    $consolePath = Join-Path $run 'serializer-console.txt'
    $consoleErrorPath = Join-Path $run 'serializer-console.err.txt'
    $arguments = @('m4addr','-noreadconfig','-rompath',$RomDirectory,
        '-cfg_directory',(Join-Path $run 'cfg'),'-nvram_directory',(Join-Path $run 'nvram'),
        '-input_directory',(Join-Path $run 'inp'),'-snapshot_directory',(Join-Path $run 'snap'),
        '-comment_directory',(Join-Path $run 'comments'),'-state_directory',(Join-Path $run 'state'),
        '-diff_directory',(Join-Path $run 'diff'),'-video','none','-sound','none','-window',
        '-skip_gameinfo','-nothrottle','-seconds_to_run','2','-autoboot_delay','0',
        '-autoboot_script',$harnessPath)
    $argumentString = ($arguments | ForEach-Object { Quote-Argument ([string]$_) }) -join ' '
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = [IO.Path]::GetFullPath($MameExecutable)
    $info.Arguments = $argumentString
    $info.WorkingDirectory = $run
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.EnvironmentVariables['FML_SERIALIZER_SOURCE'] = [IO.Path]::GetFullPath($SourcePath)
    $info.EnvironmentVariables['FML_SERIALIZER_CASES'] = $casesPath
    $info.EnvironmentVariables['FML_SERIALIZER_OUTPUT'] = $outputEvents
    $info.EnvironmentVariables['FML_SERIALIZER_RESULT'] = $resultPath
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $info
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (!$process.WaitForExit($TimeoutSeconds * 1000)) {
        & "$env:SystemRoot\System32\taskkill.exe" /PID $process.Id /T /F 2>&1 | Out-Null
        throw "Serializer probe MAME run exceeded $TimeoutSeconds wall seconds"
    }
    $stdoutText = $stdout.GetAwaiter().GetResult()
    $stderrText = $stderr.GetAwaiter().GetResult()
    $exitCode = $process.ExitCode
    $process.Dispose()
    [IO.File]::WriteAllText($consolePath, $stdoutText, $script:Utf8)
    [IO.File]::WriteAllText($consoleErrorPath, $stderrText, $script:Utf8)
    if ($exitCode -ne 0) { throw "Serializer probe MAME exit code was $exitCode" }
    if (!(Test-Path -LiteralPath $resultPath -PathType Leaf)) { throw 'Serializer probe did not write its result file' }
    if (!(Test-Path -LiteralPath $outputEvents -PathType Leaf)) { throw 'Serializer probe did not write its event output' }
    $resultLines = @{}
    foreach ($line in (Get-Content -LiteralPath $resultPath)) {
        if ($line -match '^([a-zA-Z]+)=(.*)$') { $resultLines[$Matches[1]] = $Matches[2] }
    }
    if ($resultLines['status'] -ne 'ok') { throw "Serializer probe harness failed: $($resultLines['message'])" }

    $file = Read-EventLines $outputEvents
    $records = New-Object 'System.Collections.Generic.List[object]'
    $failures = New-Object 'System.Collections.Generic.List[object]'
    $lineNumber = 0
    $docs = New-Object 'System.Collections.Generic.List[object]'
    try {
        foreach ($line in $file.lines) {
            $lineNumber++
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try {
                $doc = Read-StrictDocument $line
                if ($doc.RootElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) { throw 'record is not an object' }
                $record = $line | ConvertFrom-Json -ErrorAction Stop
                $records.Add($record)
                $docs.Add($doc)
            }
            catch {
                $failures.Add([ordered]@{ line = $lineNumber; error = $_.Exception.Message; text = $line })
            }
        }
        $specialKey = 'key"\' + "`t" + [char]1 + 'end'
        $caseResults = New-Object 'System.Collections.Generic.List[object]'
        $caseById = @{}
        foreach ($record in $records) {
            if ($record.event -eq 'serializer_probe' -and $null -ne $record.probeId) {
                $caseById[[string]$record.probeId] = $record
            }
        }
        foreach ($case in $cases) {
            $match = @($records | Where-Object { $_.event -eq 'serializer_probe' -and $_.probeId -eq $case.id })
            $ok = ($match.Count -eq 1 -and ([string]$match[0].text) -ceq ([string]$case.text))
            $caseResults.Add([ordered]@{ id = $case.id; expectedLength = ([string]$case.text).Length; records = $match.Count; pass = $ok })
            if (!$ok) { $failures.Add([ordered]@{ line = 0; error = "case $($case.id) did not round-trip"; text = '' }) }
        }
        $empty = @($records | Where-Object { $_.event -eq 'serializer_probe_empty' })
        $nil = @($records | Where-Object { $_.event -eq 'serializer_probe_nil' })
        $special = @($records | Where-Object { $_.event -eq 'serializer_probe_key' })
        $emptyProperties = 0
        $nilProperties = 0
        $specialValue = $null
        if ($empty.Count -eq 1) { $emptyProperties = @($empty[0].PSObject.Properties).Count }
        if ($nil.Count -eq 1) { $nilProperties = @($nil[0].PSObject.Properties).Count }
        if ($special.Count -eq 1) {
            $specialProperty = @($special[0].PSObject.Properties | Where-Object { $_.Name -ceq $specialKey })
            if ($specialProperty.Count -eq 1) { $specialValue = [string]$specialProperty[0].Value }
        }
        $quoteRecord = $caseById['quote']
        $backslashRecord = $caseById['backslash']
        $crlfRecord = $caseById['crlf']
        $tabRecord = $caseById['tab']
        $nulRecord = $caseById['nul']
        $escapeChecks = [ordered]@{
            quote = ($null -ne $quoteRecord -and [string]$quoteRecord.text -ceq 'he said "hi"')
            backslash = ($null -ne $backslashRecord -and [string]$backslashRecord.text -ceq 'C:\temp\a\\b')
            crlf = ($null -ne $crlfRecord -and [string]$crlfRecord.text -ceq "line1`r`nline2")
            tab = ($null -ne $tabRecord -and [string]$tabRecord.text -ceq "a`tb")
            nul = ($null -ne $nulRecord -and [string]$nulRecord.text -ceq ('a' + [char]0 + 'b'))
        }
        $rawText = $file.text
        $rawChecks = [ordered]@{
            hasEscapedQuote = $rawText.Contains('he said \"hi\"')
            hasEscapedBackslash = $rawText.Contains('C:\\temp\\a\\\\b')
            hasEscapedCrLf = $rawText.Contains('line1\r\nline2')
            hasEscapedTab = $rawText.Contains('a\tb')
            hasEscapedNul = $rawText.Contains('a\u0000b')
            hasEscapedUnitSeparator = $rawText.Contains('\u001f')
            hasNoRawCarriageReturn = !($rawText.Contains("`r"))
            hasNoRawTab = !($rawText.Contains("`t"))
            hasNoRawNul = !($rawText.Contains([string][char]0))
        }
        $expectedCount = $cases.Count + 3
        $structureOk = ($empty.Count -eq 1 -and $nil.Count -eq 1 -and $special.Count -eq 1 -and
            $emptyProperties -eq 1 -and $nilProperties -eq 1 -and $specialValue -ceq 'key-value')
        if (!$structureOk) { $failures.Add([ordered]@{ line = 0; error = 'empty/nil/special-key structure check failed'; text = '' }) }
        foreach ($key in $escapeChecks.Keys) {
            if (!$escapeChecks[$key]) { $failures.Add([ordered]@{ line = 0; error = "decoded escape check failed: $key"; text = '' }) }
        }
        foreach ($key in $rawChecks.Keys) {
            if (!$rawChecks[$key]) { $failures.Add([ordered]@{ line = 0; error = "raw escape check failed: $key"; text = '' }) }
        }
        if ($records.Count -ne $expectedCount) {
            $failures.Add([ordered]@{ line = 0; error = "expected $expectedCount records, found $($records.Count)"; text = '' })
        }
        $summary = [ordered]@{
            mode = 'serializer'
            sourcePath = [IO.Path]::GetFullPath($SourcePath)
            sourceSha256 = Get-Sha256 $SourcePath
            mameExecutable = [IO.Path]::GetFullPath($MameExecutable)
            mameSha256 = $mameSha
            runDirectory = $run
            luaVersion = $resultLines['luaVersion']
            mameExitCode = $exitCode
            outputPath = $outputEvents
            outputSha256 = Get-Sha256 $outputEvents
            recordCount = $records.Count
            expectedCount = $expectedCount
            caseCount = $cases.Count
            cases = $caseResults.ToArray()
            emptyFieldRecord = ($empty.Count -eq 1 -and $emptyProperties -eq 1)
            nilFieldRecord = ($nil.Count -eq 1 -and $nilProperties -eq 1)
            specialKeyRecord = ($specialValue -ceq 'key-value')
            escapeChecks = $escapeChecks
            rawChecks = $rawChecks
            failures = $failures.ToArray()
            pass = ($failures.Count -eq 0 -and $records.Count -eq $expectedCount)
        }
        Write-JsonFile $OutputPath $summary
        if (!$summary.pass) {
            foreach ($failure in $summary.failures) { Write-Output ("SERIALIZER FAIL: {0}" -f $failure.error) }
            throw 'Serializer escaping probe did not pass'
        }
    }
    finally {
        foreach ($doc in $docs) { $doc.Dispose() }
    }
}

switch ($Mode) {
    'Parse' { Invoke-ParseMode }
    'Negative' { Invoke-NegativeMode }
    'Serializer' { Invoke-SerializerMode }
}

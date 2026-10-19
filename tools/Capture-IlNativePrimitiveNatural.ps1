[CmdletBinding()]
param(
    [ValidateSet('Capture','Analyze','Verify')][string]$Mode = 'Capture',
    [string]$MameExecutable = 'E:\Arcade\MAME0266\mame281.exe',
    [string]$RomDirectory = 'E:\Arcade\MAME0266\roms',
    [string]$BuiltRom,
    [string]$SourceMapPath,
    [string]$BuildReportPath,
    [string]$OriginalRom,
    [string]$RunDirectory,
    [string]$EvidencePath,
    [string]$ReplayPath,
    [string]$InputLuaPath,
    [string]$ReanalysisSourceRun,
    [ValidateRange(1,180)][int]$SecondsToRun = 180,
    [ValidateRange(30,600)][int]$WallTimeoutSeconds = 600,
    [switch]$LibraryOnly
)
$ErrorActionPreference = 'Stop'

$script:Protocol = 'il-native-primitive-natural-v1'
$script:Root = Split-Path $PSScriptRoot -Parent
$script:Utf8 = New-Object System.Text.UTF8Encoding($false)
$script:OriginalSha1 = '402D1518BB78FDC489B06C2AABC771E5CE151847'
$script:OriginalSha256 = 'EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C'
$script:BuiltSha1 = '22BF419CF68F243169F05193B0E1AAF708D07707'
$script:BuiltSha256 = '67E9390B8CD5EB941E1928F5E38129DF265207536002B6304C2A3B413E9B3AA8'
$script:MapSha256 = '9BC2112CA0E4B427804BA2FB27F64F52338055F161E631999FD584B4FCD2A8E0'
$script:FieldsHex = 'E93F3C61B5'
$script:OriginalFieldsHex = '3E761E2605'
$script:MameSha256 = '0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A'
$script:HandlerHex = 'ECC4C38000EDC40EFC'
$script:AllocationHex = '1012ECC4C38000EDC40EFC'
$script:CallerHex = '101075A9'
$script:OriginalBodyHex = '795BFF80787E795BFF807AAF792F'
$script:ExpectedDiff = @(4112,4113,4114,4115,4116,4117,4118,4119,4120,4121,4122,40724,40725,65489,65490,65491,65492,65493)
$script:UnrepairedDiff = @(4112,4113,4114,4115,4116,4117,4118,4119,4120,4121,4122,40724,40725)
$script:ReplaySha256 = '4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D'
$script:InputLuaSha256 = '23099F8888AF8DB353253E0DF97638320DC59CA9A47371723A380E0C4EE85C94'
$script:CoinPulseFrames = @(2100,2101,2102,2103)
$script:StartPulseFrames = @(2221,2222,2223,2224)
$script:NextFixtureActionFrame = 2400
$script:ControlTop = 0x9F3F

$script:Phases = @(
    [ordered]@{ name='caller-prefetch'; pc=0x00FC; x=$null; y=0x9F14; u=0x066E; s=0x0798; top=0x0000; d=$null; token=0x1010; tokenAddress=0x9F14; control0=0x9F3F; requireX=$false; requireD=$false; savedCursorFromControl=$false },
    [ordered]@{ name='direct-handler-entry'; pc=0x1012; x=0x1012; y=0x9F16; u=0x066E; s=0x0798; top=0x0000; d=0x0000; token=0x1012; tokenAddress=0x1010; control0=0x9F3F; requireX=$true; requireD=$true; savedCursorFromControl=$false },
    [ordered]@{ name='after-ldd'; pc=0x1014; x=0x1012; y=0x9F16; u=0x066E; s=0x0798; top=0x0000; d=0x0000; token=0x1012; tokenAddress=0x1010; control0=0x9F3F; requireX=$false; requireD=$true; savedCursorFromControl=$false },
    [ordered]@{ name='after-addd'; pc=0x1017; x=0x1012; y=0x9F16; u=0x066E; s=0x0798; top=0x0000; d=0x8000; token=0x1012; tokenAddress=0x1010; control0=0x9F3F; requireX=$false; requireD=$true; savedCursorFromControl=$false },
    [ordered]@{ name='after-std'; pc=0x1019; x=0x1012; y=0x9F16; u=0x066E; s=0x0798; top=0x8000; d=$null; token=0x1012; tokenAddress=0x1010; control0=0x9F3F; requireX=$false; requireD=$false; savedCursorFromControl=$false },
    [ordered]@{ name='post-handler-prefetch'; pc=0x00FC; x=0x1012; y=0x9F16; u=0x066E; s=0x0798; top=0x8000; d=$null; token=0x75A9; tokenAddress=0x9F16; control0=0x9F3F; requireX=$false; requireD=$false; savedCursorFromControl=$false },
    [ordered]@{ name='75ab-entry'; pc=0x75AB; x=0x75AB; y=0x9F18; u=0x066E; s=0x0798; top=0x8000; d=$null; token=0x75A9; tokenAddress=0x9F16; control0=0x9F3F; requireX=$false; requireD=$false; savedCursorFromControl=$false },
    [ordered]@{ name='negative-arm'; pc=0x75B6; x=0x75AB; y=0x9F18; u=0x066E; s=0x0798; top=0x8000; d=0x8000; token=0x75A9; tokenAddress=0x9F16; control0=0x9F3F; requireX=$false; requireD=$true; savedCursorFromControl=$false },
    [ordered]@{ name='post-75a9'; pc=0x00FC; x=0x75AB; y=0x9F18; u=0x066E; s=0x0798; top=0xFFFF; d=$null; token=0x7B7D; tokenAddress=0x9F18; control0=0x9F3F; requireX=$false; requireD=$false; savedCursorFromControl=$false },
    [ordered]@{ name='after-swap-drop'; pc=0x00FC; x=0x7B3F; y=0x9F1C; u=0x0670; s=0x0798; top=0xFFFF; d=$null; token=0x792F; tokenAddress=0x9F1C; control0=0x9F3F; requireX=$false; requireD=$false; savedCursorFromControl=$true },
    [ordered]@{ name='return-handler'; pc=0x7931; x=0x7931; y=0x9F1E; u=0x0670; s=0x0798; top=0xFFFF; d=$null; token=0x792F; tokenAddress=0x9F1C; control0=0x9F3F; requireX=$false; requireD=$false; savedCursorFromControl=$true },
    [ordered]@{ name='9f12-post-return'; pc=0x00FC; x=0x7931; y=0x9F3F; u=0x0670; s=0x079A; top=0xFFFF; d=$null; token=0x792F; tokenAddress=0x9F3F; control0=$null; requireX=$false; requireD=$false; savedCursorFromControl=$false }
)

if ([string]::IsNullOrWhiteSpace($BuiltRom)) { $BuiltRom = Join-Path $script:Root 'artifacts/deepseek/il-native-primitive-build-45/cli-test-01/positive/native-repaired.p1' }
if ([string]::IsNullOrWhiteSpace($SourceMapPath)) { $SourceMapPath = Join-Path (Split-Path $BuiltRom -Parent) 'native-primitive-source-map.json' }
if ([string]::IsNullOrWhiteSpace($BuildReportPath)) { $BuildReportPath = Join-Path (Split-Path $BuiltRom -Parent) 'build-report.json' }
if ([string]::IsNullOrWhiteSpace($OriginalRom)) { $OriginalRom = Join-Path $script:Root 'artifacts/deepseek/general-14/roms/original.p1' }
if ([string]::IsNullOrWhiteSpace($EvidencePath)) { $EvidencePath = Join-Path $script:Root 'evidence/mpu4/integrity/il-native-primitive-natural.json' }
if ([string]::IsNullOrWhiteSpace($ReplayPath)) { $ReplayPath = Join-Path $script:Root 'evidence/mpu4/skill-cash/actions.csv' }
if ([string]::IsNullOrWhiteSpace($InputLuaPath)) { $InputLuaPath = Join-Path $script:Root 'evidence/mpu4/skill-cash/input.lua' }

function Get-HashValue {
    param([string]$Path,[string]$Algorithm)
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        try { return ([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-','').ToUpperInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Get-StringSha256 {
    param([string]$Text)
    $hash = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hash.ComputeHash($script:Utf8.GetBytes($Text)))).Replace('-','').ToUpperInvariant() }
    finally { $hash.Dispose() }
}

function Write-JsonFile {
    param([string]$Path,$Object,[int]$Depth = 30)
    $parent = Split-Path -Parent $Path
    if (![string]::IsNullOrWhiteSpace($parent) -and !(Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [IO.File]::WriteAllText($Path,(ConvertTo-Json -InputObject $Object -Depth $Depth),$script:Utf8)
}

function Read-JsonFile {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required JSON file is missing: $Path" }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Format-Hex16 {
    param([int]$Value)
    return ('{0:X4}' -f ($Value -band 0xFFFF))
}

function Format-Hex8 {
    param([int]$Value)
    return ('{0:X2}' -f ($Value -band 0xFF))
}

function ConvertTo-HexInt {
    param([string]$Text)
    return [Convert]::ToInt32($Text,16)
}

function ConvertTo-HexBytes {
    param([byte[]]$Bytes,[int]$Address,[int]$Length)
    $parts = New-Object 'System.Collections.Generic.List[string]'
    for ($i = 0; $i -lt $Length; $i++) { $parts.Add((Format-Hex8 $Bytes[($Address + $i) -band 0xFFFF])) }
    return ($parts -join '')
}

function Assert-FileIdentity {
    param([string]$Path,[string]$Sha1,[string]$Sha256,[string]$Label,[int]$Length = 65536)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label is missing: $Path" }
    $actualLength = (Get-Item -LiteralPath $Path).Length
    if ($actualLength -ne $Length) { throw "$Label length is $actualLength, expected $Length" }
    $actualSha1 = Get-HashValue $Path 'SHA1'
    $actualSha256 = Get-HashValue $Path 'SHA256'
    if ($actualSha1 -ine $Sha1) { throw "$Label SHA1 is $actualSha1, expected $Sha1" }
    if ($actualSha256 -ine $Sha256) { throw "$Label SHA256 is $actualSha256, expected $Sha256" }
    return [ordered]@{ path=[IO.Path]::GetFullPath($Path); length=$actualLength; sha1=$actualSha1; sha256=$actualSha256 }
}

function Assert-FileHashIdentity {
    param([string]$Path,[string]$Sha256,[string]$Label)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label is missing: $Path" }
    $actualSha256 = Get-HashValue $Path 'SHA256'
    if ($actualSha256 -ine $Sha256) { throw "$Label SHA256 is $actualSha256, expected $Sha256" }
    return [ordered]@{
        path = [IO.Path]::GetFullPath($Path)
        length = (Get-Item -LiteralPath $Path).Length
        sha256 = $actualSha256
    }
}

function Get-ReplaySchedule {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Replay fixture is missing: $Path" }
    $coin = $null
    $start = $null
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^(\d+),(\d+),([^,]+),(\d+),([^,]+),') {
            $entry = [ordered]@{
                firstFrame = [int]$Matches[1]
                lastFrame = [int]$Matches[2]
                port = [string]$Matches[3]
                mask = [int]$Matches[4]
                reason = [string]$Matches[5]
            }
            if ($null -eq $coin -and $entry.reason -eq 'short_coin') { $coin = $entry }
            if ($null -eq $start -and $entry.reason -eq 'start_probe') { $start = $entry }
        }
    }
    if ($null -eq $coin) { throw 'Replay fixture has no short_coin event' }
    if ($null -eq $start) { throw 'Replay fixture has no start_probe event' }
    if ($coin.firstFrame -ne 2100 -or $coin.lastFrame -ne 2103 -or $coin.port -ne ':AUX2' -or $coin.mask -ne 128) {
        throw "Replay fixture coin event is $($coin.firstFrame)-$($coin.lastFrame) $($coin.port) mask=$($coin.mask), expected 2100-2103 :AUX2 mask=128"
    }
    if ($start.firstFrame -ne 2220 -or $start.lastFrame -ne 2232 -or $start.port -ne ':BLACK2' -or $start.mask -ne 128) {
        throw "Replay fixture start event is $($start.firstFrame)-$($start.lastFrame) $($start.port) mask=$($start.mask), expected the prior 2220-2232 :BLACK2 mask=128 schedule whose effective frames are 2221-2224"
    }
    return [ordered]@{ coin = $coin; start = $start }
}

function Get-RecordedStopTimes {
    param([string]$Run)
    $eventsPath = Join-Path $Run 'events.jsonl'
    if (!(Test-Path -LiteralPath $eventsPath -PathType Leaf)) { throw 'Recorded event log is missing for stop-time provenance' }
    $phaseTimes = New-Object 'System.Collections.Generic.List[double]'
    $terminalTime = $null
    foreach ($line in Get-Content -LiteralPath $eventsPath) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $record = $line | ConvertFrom-Json -ErrorAction Stop
        $type = [string]$record.event
        if ($type -ne 'phase' -and $type -ne 'session_complete') { continue }
        $timeText = [string]$record.emulatedTime
        if ([string]::IsNullOrWhiteSpace($timeText)) { throw "Recorded $type event has no emulatedTime" }
        $time = [double]::Parse($timeText, [Globalization.CultureInfo]::InvariantCulture)
        if ([double]::IsNaN($time) -or [double]::IsInfinity($time) -or $time -lt 0) { throw "Recorded $type emulatedTime is not a finite non-negative value: $timeText" }
        if ($type -eq 'phase') {
            if ($phaseTimes.Count -gt 0 -and $time -le $phaseTimes[$phaseTimes.Count - 1]) {
                throw 'Recorded phase stop times are not strictly increasing'
            }
            $phaseTimes.Add($time)
        }
        else {
            $terminalTime = $time
        }
    }
    if ($phaseTimes.Count -eq 0 -and $null -eq $terminalTime) { throw 'No recorded phase or terminal stop time is available' }
    $stopTimes = New-Object 'System.Collections.Generic.List[double]'
    foreach ($time in $phaseTimes) { [void]$stopTimes.Add($time) }
    if ($null -ne $terminalTime) {
        if ($stopTimes.Count -eq 0) { [void]$stopTimes.Add([double]$terminalTime) }
        elseif ([double]$terminalTime -gt ($stopTimes[$stopTimes.Count - 1] + 0.000001)) { [void]$stopTimes.Add([double]$terminalTime) }
        elseif ([double]$terminalTime -lt ($stopTimes[$stopTimes.Count - 1] - 0.000001)) { throw 'Recorded session-complete time precedes the last recorded phase stop' }
    }
    return [ordered]@{
        eventsPath = [IO.Path]::GetFullPath($eventsPath)
        eventsSha256 = Get-HashValue $eventsPath 'SHA256'
        phaseStopTimes = $phaseTimes.ToArray()
        terminalStopTime = $terminalTime
        stopTimes = $stopTimes.ToArray()
    }
}

function Get-DebugStopEvidence {
    param([string]$Run)
    $path = Join-Path $Run 'debug.log'
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
        return [ordered]@{
            present = $false
            debugLogPath = ''
            debugLogSha256 = ''
            stopLineCount = 0
            phaseStopCount = 0
        }
    }
    $stopLineCount = @(Get-Content -LiteralPath $path | Where-Object { $_ -match '^Stopped at breakpoint\b' }).Count
    return [ordered]@{
        present = $true
        debugLogPath = [IO.Path]::GetFullPath($path)
        debugLogSha256 = Get-HashValue $path 'SHA256'
        stopLineCount = $stopLineCount
        phaseStopCount = [Math]::Max(0, $stopLineCount - 1)
    }
}

function Get-InputProvenance {
    param([string]$Run,$ReplaySchedule)
    $levelsPath = Join-Path $Run 'input-levels.csv'
    if (!(Test-Path -LiteralPath $levelsPath -PathType Leaf)) { throw 'Tracked replay did not produce input-levels.csv' }
    $lines = @(Get-Content -LiteralPath $levelsPath)
    if ($lines.Count -lt 2) { throw 'input-levels.csv has no samples' }
    if ($lines[0] -ne 'frame,t,aux2,black2,coin_override') { throw "input-levels.csv header is not the tracked replay header: $($lines[0])" }
    $rows = New-Object 'System.Collections.Generic.List[object]'
    foreach ($line in $lines[1..($lines.Count - 1)]) {
        if ($line -notmatch '^(\d+),([0-9.]+),([0-9A-Fa-f]{2}),([0-9A-Fa-f]{2}),(\d+)$') { throw "input-levels.csv row is malformed: $line" }
        $rowTime = [double]::Parse($Matches[2], [Globalization.CultureInfo]::InvariantCulture)
        if ([double]::IsNaN($rowTime) -or [double]::IsInfinity($rowTime) -or $rowTime -lt 0) { throw "input-levels.csv row has a non-finite time: $line" }
        $rows.Add([ordered]@{
            frame = [int]$Matches[1]
            time = $rowTime
            aux2 = [Convert]::ToInt32($Matches[3],16)
            black2 = [Convert]::ToInt32($Matches[4],16)
            coinOverride = [int]$Matches[5]
        })
    }
    if ($rows.Count -eq 0) { throw 'input-levels.csv has no parsed samples' }

    for ($i = 1; $i -lt $rows.Count; $i++) {
        if ($rows[$i].frame -le $rows[$i - 1].frame) { throw "input-levels.csv frame counter is not strictly increasing at $($rows[$i].frame)" }
        if ($rows[$i].time -le $rows[$i - 1].time) { throw "input-levels.csv emulated time is not strictly increasing at frame $($rows[$i].frame)" }
    }

    $framePeriod = 1.0 / 60.0
    $gridTolerance = $framePeriod / 8.0
    $gridOrigin = $rows[0].time
    foreach ($row in $rows) {
        $derivedIndex = [int][Math]::Floor((($row.time - $gridOrigin) / $framePeriod) + 0.5)
        $gridTime = $gridOrigin + ($derivedIndex * $framePeriod)
        $gridError = $row.time - $gridTime
        $row.derivedRealFrameIndex = $derivedIndex
        $row.gridErrorSeconds = $gridError
        $row.frameCounterMatchesDerived = ($row.frame -eq ($derivedIndex + 1))
        $row.classification = if ([Math]::Abs($gridError) -le $gridTolerance) { 'real_60hz' } else { 'off_grid' }
    }

    $coinRows = @($rows | Where-Object { $_.aux2 -ne 0 -or $_.coinOverride -ne 0 })
    if ($coinRows.Count -lt 4) { throw "input-levels.csv recorded only $($coinRows.Count) coin-active frames" }
    for ($i = 1; $i -lt $coinRows.Count; $i++) {
        if ($coinRows[$i].frame -le $coinRows[$i - 1].frame) { throw 'input-levels.csv coin-active rows are not strictly ordered' }
    }
    $coinFrames = @($coinRows | ForEach-Object { $_.frame })
    $expectedCoinFrames = @(2100,2101,2102,2103)
    if (($coinFrames -join ',') -ne ($expectedCoinFrames -join ',')) {
        throw "Tracked replay coin activity is '$($coinFrames -join ',')', expected the complete 2100,2101,2102,2103 window"
    }
    $coinOffGridRows = @($coinRows | Where-Object { $_.classification -ne 'real_60hz' })
    if ($coinOffGridRows.Count -gt 0) {
        throw "Coin-active frame $($coinOffGridRows[0].frame) is off the known 60 Hz grid and is not a start-window debug-stop callback"
    }

    $startRows = @($rows | Where-Object { $_.black2 -ne 0 })
    if ($startRows.Count -eq 0) { throw 'input-levels.csv has no start-active rows' }
    $realStartRows = @($startRows | Where-Object { $_.classification -eq 'real_60hz' })
    $offGridStartRows = @($startRows | Where-Object { $_.classification -ne 'real_60hz' })
    $requiredStartFrames = @(2221,2222,2223,2224)
    if ($realStartRows.Count -lt $requiredStartFrames.Count) {
        throw "input-levels.csv recorded only $($realStartRows.Count) 60 Hz start-active frames, expected at least 2221,2222,2223,2224"
    }
    $fixtureFirstFrame = [int]$ReplaySchedule.start.firstFrame
    $fixtureLastExclusive = [int]$ReplaySchedule.start.lastFrame
    $effectiveFirstFrame = $fixtureFirstFrame + 1
    if ($realStartRows[0].frame -ne $effectiveFirstFrame) {
        throw "The 60 Hz start-active window begins at $($realStartRows[0].frame), expected the prior effective frame $effectiveFirstFrame"
    }
    for ($i = 0; $i -lt $requiredStartFrames.Count; $i++) {
        if ($realStartRows[$i].frame -ne $requiredStartFrames[$i]) {
            throw "The 60 Hz start-active window is '$((@($realStartRows | ForEach-Object { $_.frame })) -join ',')', expected the complete required prefix 2221,2222,2223,2224"
        }
    }
    for ($i = 1; $i -lt $realStartRows.Count; $i++) {
        if ($realStartRows[$i].frame -ne $realStartRows[$i - 1].frame + 1) {
            throw "The 60 Hz start-active window is not contiguous: '$((@($realStartRows | ForEach-Object { $_.frame })) -join ',')'"
        }
    }
    $lastRealStartFrame = $realStartRows[$realStartRows.Count - 1].frame
    if ($lastRealStartFrame -ge $fixtureLastExclusive) {
        throw "A 60 Hz start-active frame at $lastRealStartFrame is at or after the replay fixture's $fixtureFirstFrame-$fixtureLastExclusive start probe"
    }
    $firstOffGridStartIndex = -1
    for ($i = 0; $i -lt $startRows.Count; $i++) {
        if ($startRows[$i].classification -ne 'real_60hz') { $firstOffGridStartIndex = $i; break }
    }
    if ($firstOffGridStartIndex -ge 0) {
        for ($i = $firstOffGridStartIndex; $i -lt $startRows.Count; $i++) {
            if ($startRows[$i].classification -eq 'real_60hz') {
                throw "A 60 Hz start-active frame at $($startRows[$i].frame) appears after a debug-stop callback"
            }
        }
    }

    $recorded = Get-RecordedStopTimes $Run
    $debugStops = Get-DebugStopEvidence $Run
    $stopGaps = New-Object 'System.Collections.Generic.List[double]'
    for ($i = 1; $i -lt $recorded.stopTimes.Count; $i++) { $stopGaps.Add([double]$recorded.stopTimes[$i] - [double]$recorded.stopTimes[$i - 1]) }
    $minimumStopGap = if ($stopGaps.Count -gt 0) { ($stopGaps | Measure-Object -Minimum).Minimum } else { 0.000010 }
    $stopMatchTolerance = [Math]::Min(0.000001, ([double]$minimumStopGap / 4.0))
    if ($stopMatchTolerance -le 0) { $stopMatchTolerance = 0.0000001 }
    if ($offGridStartRows.Count -gt 0) {
        if (-not [bool]$debugStops.present) { throw 'Off-grid start-active rows require the recorded debugger stop log' }
        if ($offGridStartRows.Count -ne [int]$debugStops.phaseStopCount) {
            throw "Recorded $($debugStops.phaseStopCount) native phase debugger stops but observed $($offGridStartRows.Count) off-grid start-active callbacks"
        }
        if ($offGridStartRows.Count -gt $recorded.stopTimes.Count) {
            throw "Observed $($offGridStartRows.Count) off-grid start-active callbacks but only $($recorded.stopTimes.Count) recorded phase/session stop times"
        }
        for ($i = 0; $i -lt $offGridStartRows.Count; $i++) {
            $row = $offGridStartRows[$i]
            $expectedFrame = $lastRealStartFrame + 1 + $i
            if ($row.frame -ne $expectedFrame) {
                throw "Debug-stop callback row $($row.frame) is not contiguous with the 60 Hz start window (expected $expectedFrame)"
            }
            $recordedStopTime = [double]$recorded.stopTimes[$i]
            $difference = [Math]::Abs([double]$row.time - $recordedStopTime)
            if ($difference -gt $stopMatchTolerance) {
                throw "Off-grid start-active row $($row.frame) at $('{0:F9}' -f $row.time) does not match recorded phase/session stop $('{0:F9}' -f $recordedStopTime)"
            }
            $row.classification = 'debug_stop_callback'
            $row.recordedStopIndex = $i
            $row.recordedStopTime = ('{0:F9}' -f $recordedStopTime)
        }
    }

    $startFrames = @($startRows | ForEach-Object { $_.frame })
    $realFrameStartFrames = @($realStartRows | ForEach-Object { $_.frame })
    $debugStopStartFrames = @($offGridStartRows | ForEach-Object { $_.frame })
    $startRowDetails = @($startRows | ForEach-Object {
        [ordered]@{
            frame = $_.frame
            emulatedTime = ('{0:F9}' -f $_.time)
            aux2 = Format-Hex8 $_.aux2
            black2 = Format-Hex8 $_.black2
            coinOverride = $_.coinOverride
            classification = $_.classification
            derivedRealFrameIndex = $_.derivedRealFrameIndex
            gridErrorSeconds = ('{0:F9}' -f $_.gridErrorSeconds)
            frameCounterMatchesDerived = $_.frameCounterMatchesDerived
            recordedStopIndex = if ($_.classification -eq 'debug_stop_callback') { $_.recordedStopIndex } else { -1 }
            recordedStopTime = if ($_.classification -eq 'debug_stop_callback') { $_.recordedStopTime } else { '' }
        }
    })
    $last = $rows[$rows.Count - 1]
    if ($last.frame -ge $script:NextFixtureActionFrame) {
        throw "The capture applied a fixture action at frame $($last.frame), at or after $($script:NextFixtureActionFrame); it should exit at the first complete call"
    }
    $realStartRowsCount = $realStartRows.Count
    $offGridStartRowsCount = $offGridStartRows.Count
    return [ordered]@{
        levelsPath = [IO.Path]::GetFullPath($levelsPath)
        levelsSha256 = Get-HashValue $levelsPath 'SHA256'
        sampleCount = $rows.Count
        firstFrame = $rows[0].frame
        lastFrame = $last.frame
        minEmulatedTime = ('{0:F9}' -f $rows[0].time)
        maxEmulatedTime = ('{0:F9}' -f $last.time)
        coinFrames = $coinFrames
        coinWindow = [ordered]@{
            first = $coinFrames[0]
            last = $coinFrames[$coinFrames.Count - 1]
            frames = $coinFrames
            requiredFrames = $expectedCoinFrames
        }
        coinStartTime = ('{0:F9}' -f $coinRows[0].time)
        startFrames = $startFrames
        realFrameStartFrames = $realFrameStartFrames
        debugStopStartFrames = $debugStopStartFrames
        requiredStartFrames = $requiredStartFrames
        startRows = $startRowDetails
        startWindow = [ordered]@{
            first = $realFrameStartFrames[0]
            last = $startFrames[$startFrames.Count - 1]
            lastRealFrame = $lastRealStartFrame
            frames = $startFrames
            realFrames = $realFrameStartFrames
            debugStopFrames = $debugStopStartFrames
            requiredFrames = $requiredStartFrames
            fixtureProbeFirst = $fixtureFirstFrame
            fixtureProbeLastExclusive = $fixtureLastExclusive
            firstEmulatedTime = ('{0:F9}' -f $realStartRows[0].time)
            lastRealEmulatedTime = ('{0:F9}' -f $realStartRows[$realStartRows.Count - 1].time)
            lastActiveEmulatedTime = ('{0:F9}' -f $startRows[$startRows.Count - 1].time)
            minActiveEmulatedTime = ('{0:F9}' -f $startRows[0].time)
            maxActiveEmulatedTime = ('{0:F9}' -f $startRows[$startRows.Count - 1].time)
        }
        startStartTime = ('{0:F9}' -f $realStartRows[0].time)
        nextFixtureActionFrame = $script:NextFixtureActionFrame
        laterFixtureActionsUnused = ($last.frame -lt $script:NextFixtureActionFrame)
        sampleContract = [ordered]@{
            source = 'input.lua emu.register_frame_done rows with native debugger-stop callbacks'
            framePeriodSeconds = ('{0:F9}' -f $framePeriod)
            gridOriginSeconds = ('{0:F9}' -f $gridOrigin)
            gridToleranceSeconds = ('{0:F9}' -f $gridTolerance)
            stopMatchToleranceSeconds = ('{0:F9}' -f $stopMatchTolerance)
            classificationRule = 'A row is real_60hz when its emulated time is within one eighth of the known 60 Hz frame period of the derived grid. An off-grid start-active row is accepted only when it is contiguous with the real 60 Hz start rows, matches the ordered recorded phase/session stop time, and equals the recorded native phase debugger stop count. Any other off-grid active row is rejected.'
            totalRows = $rows.Count
            frameCounterFirst = $rows[0].frame
            frameCounterLast = $last.frame
            minEmulatedTime = ('{0:F9}' -f $rows[0].time)
            maxEmulatedTime = ('{0:F9}' -f $last.time)
            realFrameRowCount = @($rows | Where-Object { $_.classification -eq 'real_60hz' }).Count
            offGridRowCount = @($rows | Where-Object { $_.classification -ne 'real_60hz' }).Count
            coinActiveRowCount = $coinRows.Count
            startActiveRowCount = $startRows.Count
            startRealFrameRowCount = $realStartRowsCount
            startDebugStopCallbackCount = $offGridStartRowsCount
        }
        debugStopEvidence = [ordered]@{
            debugLogPath = $debugStops.debugLogPath
            debugLogSha256 = $debugStops.debugLogSha256
            stopLineCount = $debugStops.stopLineCount
            phaseStopCount = $debugStops.phaseStopCount
            recordedPhaseStopTimes = @($recorded.phaseStopTimes | ForEach-Object { '{0:F9}' -f $_ })
            recordedStopTimes = @($recorded.stopTimes | ForEach-Object { '{0:F9}' -f $_ })
            recordedStopCount = $recorded.stopTimes.Count
        }
    }
}

function Get-DiffOffsets {
    param([byte[]]$A,[byte[]]$B)
    if ($A.Length -ne $B.Length) { throw 'Cannot compare images of different length' }
    $offsets = New-Object 'System.Collections.Generic.List[int]'
    for ($i = 0; $i -lt $A.Length; $i++) { if ($A[$i] -ne $B[$i]) { [void]$offsets.Add($i) } }
    return $offsets.ToArray()
}

function Assert-ImageByte {
    param([byte[]]$Image,[int]$Address,[int]$Expected,[string]$Label)
    if ($Image[$Address] -ne $Expected) { throw "$Label at $(Format-Hex16 $Address) is $(Format-Hex8 $Image[$Address]), expected $(Format-Hex8 $Expected)" }
}

function Test-NativeMapContract {
    param($Map,$Build,[byte[]]$Built,[byte[]]$Original)

    if ([int]$Map.SchemaVersion -ne 1 -and $null -ne $Map.SchemaVersion) { throw 'Source map schemaVersion is not 1' }
    if ([string]$Map.OriginalRomSha1 -ine $script:OriginalSha1) { throw 'Source map original SHA1 is wrong' }
    if ([string]$Map.OriginalRomSha256 -ine $script:OriginalSha256) { throw 'Source map original SHA256 is wrong' }
    if ([string]$Map.OutputImageSha1 -ine $script:BuiltSha1) { throw 'Source map output SHA1 is wrong' }
    if ([string]$Map.OutputImageSha256 -ine $script:BuiltSha256) { throw 'Source map output SHA256 is wrong' }
    if ([string]$Map.BuildId -ine $script:BuiltSha256) { throw 'Source map BuildId is not the exact built image SHA256' }
    if ([int]$Map.TokenAddress -ne 0x1010) { throw 'Source map token address is not 1010' }
    if ([int]$Map.TokenValue -ne 0x1012) { throw 'Source map token value is not 1012' }
    if ([int]$Map.HandlerStart -ne 0x1012) { throw 'Source map handler start is not 1012' }
    if ([int]$Map.HandlerEndExclusive -ne 0x101B) { throw 'Source map handler end is not 101B' }
    if ([bool]$Map.IsDefinitionHeader) { throw 'Source map still classifies the token cell as a 00F8 definition header' }
    if (([string]$Map.PointerCellClassification) -notmatch 'direct_native_handler_pointer_not_00f8_definition_header') { throw 'Source map pointer-cell classification is not the direct native class' }
    if (([string]$Map.Classification) -notmatch 'static_native_primitive_map_bound_to_exact_output_sha256') { throw 'Source map classification is not the static native-primitive class' }

    if ([string]$Build.original.sha1 -ine $script:OriginalSha1) { throw 'Build report original SHA1 is wrong' }
    if ([string]$Build.original.sha256 -ine $script:OriginalSha256) { throw 'Build report original SHA256 is wrong' }
    if ([string]$Build.repaired.sha1 -ine $script:BuiltSha1) { throw 'Build report output SHA1 is wrong' }
    if ([string]$Build.repaired.sha256 -ine $script:BuiltSha256) { throw 'Build report output SHA256 is wrong' }
    if ([string]$Build.allocation.tokenHex -ine '1012') { throw 'Build report token is not 1012' }
    if ([string]$Build.allocation.handlerStart -ine '1012') { throw 'Build report handler start is not 1012' }
    if ([string]$Build.allocation.handlerEndInclusive -ine '101A') { throw 'Build report handler end is not 101A' }
    if ([string]$Build.allocation.handlerHex -ine $script:HandlerHex) { throw 'Build report handler bytes differ from the certified handler' }
    if ([string]$Build.allocation.payloadHex -ine $script:AllocationHex) { throw 'Build report allocation payload differs from the certified allocation' }
    if ([string]$Build.caller.address -ine '9F14') { throw 'Build report caller address is not 9F14' }
    if ([string]$Build.caller.expectedToken -ine '9ED7') { throw 'Build report expected caller token is not 9ED7' }
    if ([string]$Build.caller.replacementToken -ine '1010') { throw 'Build report replacement caller token is not 1010' }
    if ([string]$Build.caller.successorAddress -ine '9F16') { throw 'Build report successor address is not 9F16' }
    if ([string]$Build.caller.successorToken -ine '75A9') { throw 'Build report successor token is not 75A9' }
    if ([string]$Build.integrity.repairedFieldsHex -ine $script:FieldsHex) { throw 'Build report integrity fields are wrong' }
    if ([string]$Build.integrity.originalFieldsHex -ine $script:OriginalFieldsHex) { throw 'Build report original integrity fields are wrong' }
    if ([bool]$Build.staticOnly -ne $true) { throw 'Build report is not marked static-only' }
    if ([bool]$Build.executionClaimed) { throw 'Build report wrongly claims execution' }

    $actualDiff = @(Get-DiffOffsets $Original $Built)
    if (($actualDiff -join ',') -ne ($script:ExpectedDiff -join ',')) { throw "Built image diff is not the accepted 18-byte set: $($actualDiff -join ',')" }
    $buildDiff = @($Build.repaired.changedOffsets | ForEach-Object { [int]$_ })
    if (($buildDiff -join ',') -ne ($script:ExpectedDiff -join ',')) { throw 'Build report changedOffsets differ from the accepted 18-offset set' }
    $unrepairedDiff = @($Build.unrepaired.changedOffsets | ForEach-Object { [int]$_ })
    if (($unrepairedDiff -join ',') -ne ($script:UnrepairedDiff -join ',')) { throw 'Build report unrepaired changedOffsets differ from the accepted 13-offset set' }
    $repairDiff = @($Build.integrity.repairChangedOffsets | ForEach-Object { [int]$_ })
    if (($repairDiff -join ',') -ne ((@(65489,65490,65491,65492,65493)) -join ',')) { throw 'Build report repairChangedOffsets are not FFD1-FFD5' }

    if ((ConvertTo-HexBytes $Built 0x1010 11) -ine $script:AllocationHex) { throw 'Built token/handler allocation is not the accepted extension content' }
    if ((ConvertTo-HexBytes $Built 0x9F14 4) -ine $script:CallerHex) { throw 'Built caller/successor bytes are not 1010/75A9' }
    if ((ConvertTo-HexBytes $Built 0x9ED7 16) -ine ('00F8' + $script:OriginalBodyHex)) { throw 'Original 9ED7/9ED9 definition was not preserved' }
    if ((ConvertTo-HexBytes $Built 0xFFD1 5) -ine $script:FieldsHex) { throw 'Built integrity fields are not E93F3C61B5' }
    if ((ConvertTo-HexBytes $Original 0xFFD1 5) -ine $script:OriginalFieldsHex) { throw 'Original integrity fields are not 3E761E2605' }
    if ((ConvertTo-HexBytes $Built 0x1012 9) -ine $script:HandlerHex) { throw 'Built handler bytes are not the certified direct native handler' }
    if ((ConvertTo-HexBytes $Built 0x1010 2) -ine '1012') { throw 'Built token cell is not 1012' }
    if ((ConvertTo-HexBytes $Built 0x9ED7 2) -ine '00F8') { throw 'Original 9ED7 is still not a 00F8 definition header' }
    for ($address = 0x1000; $address -le 0x100F; $address++) { Assert-ImageByte $Built $address 0xFF 'low guard' }
    for ($address = 0x13F0; $address -le 0x13FF; $address++) { Assert-ImageByte $Built $address 0xFF 'high guard' }

    $entries = @($Map.Entries)
    if ($entries.Count -ne 15) { throw "Source map has $($entries.Count) entries, expected 15" }
    foreach ($entry in $entries) {
        $address = [int]$entry.Address
        if ([int]$entry.ImageByte -ne [int]$Built[$address]) { throw "Source map entry byte differs at $(Format-Hex16 $address)" }
    }
    $instructions = @($Map.Instructions)
    if ($instructions.Count -ne 4) { throw "Source map has $($instructions.Count) instructions, expected 4" }
    $expectedInstructions = @(
        @{ Address=0x1012; Next=0x1014; Bytes='ECC4'; Operation='LDD ,U' },
        @{ Address=0x1014; Next=0x1017; Bytes='C38000'; Operation='ADDD #$8000' },
        @{ Address=0x1017; Next=0x1019; Bytes='EDC4'; Operation='STD ,U' },
        @{ Address=0x1019; Next=0x101B; Bytes='0EFC'; Operation='JMP $00FC' }
    )
    for ($i = 0; $i -lt $expectedInstructions.Count; $i++) {
        $actual = $instructions[$i]
        $expected = $expectedInstructions[$i]
        if ([int]$actual.Address -ne $expected.Address) { throw "Source map instruction $i address is wrong" }
        if ([int]$actual.NextAddress -ne $expected.Next) { throw "Source map instruction $i next address is wrong" }
        if ([string]$actual.BytesHex -ine $expected.Bytes) { throw "Source map instruction $i bytes are wrong" }
        if ([string]$actual.Operation -ine $expected.Operation) { throw "Source map instruction $i operation is wrong" }
    }

    $phases = @($Map.Phases)
    if ($phases.Count -ne $script:Phases.Count) { throw "Source map has $($phases.Count) phases, expected $($script:Phases.Count)" }
    for ($i = 0; $i -lt $script:Phases.Count; $i++) {
        $actual = $phases[$i]
        $expected = $script:Phases[$i]
        if ([string]$actual.Phase -ne $expected.name) { throw "Source map phase $i is $($actual.Phase), expected $($expected.name)" }
        if ([int]$actual.Pc -ne $expected.pc) { throw "Source map phase $($expected.name) PC is $($actual.Pc)" }
        if ([int]$actual.Y -ne $expected.y) { throw "Source map phase $($expected.name) Y is $($actual.Y)" }
        if ([int]$actual.U -ne $expected.u) { throw "Source map phase $($expected.name) U is $($actual.U)" }
        if ([int]$actual.S -ne $expected.s) { throw "Source map phase $($expected.name) S is $($actual.S)" }
        if ([int]$actual.TopCell -ne $expected.top) { throw "Source map phase $($expected.name) top cell is $($actual.TopCell)" }
        if ($null -ne $expected.x) {
            if ($null -eq $actual.X) { throw "Source map phase $($expected.name) X is null, expected $(Format-Hex16 $expected.x)" }
            if ([int]$actual.X -ne $expected.x) { throw "Source map phase $($expected.name) X is $($actual.X)" }
        }
        if (([string]$actual.Classification) -notmatch 'static_prediction_not_execution') { throw "Source map phase $($expected.name) is not classified static prediction" }
    }

    $dispatch = $Map.Dispatch
    if ([int]$dispatch.StreamAddressC -ne 0x9F14) { throw 'Source map stream address C is not 9F14' }
    if ([int]$dispatch.TokenCellT -ne 0x1010) { throw 'Source map token cell T is not 1010' }
    if ([int]$dispatch.HandlerAddressH -ne 0x1012) { throw 'Source map handler H is not 1012' }
    if ([int]$dispatch.TokenValue -ne 0x1012) { throw 'Source map token value is not 1012' }
    if ([int]$dispatch.HandlerValue -ne 0x1012) { throw 'Source map handler value is not 1012' }
    if ([int]$dispatch.AfterDispatchPc -ne 0x1012) { throw 'Source map after-dispatch PC is not 1012' }
    if ([int]$dispatch.AfterDispatchX -ne 0x1012) { throw 'Source map after-dispatch X is not 1012' }
    if ([int]$dispatch.AfterDispatchY -ne 0x9F16) { throw 'Source map after-dispatch Y is not 9F16' }
    if ([int]$dispatch.OriginalCallerToken -ne 0x9ED7) { throw 'Source map original caller token is not 9ED7' }
    if ([int]$dispatch.ReplacementCallerToken -ne 0x1010) { throw 'Source map replacement caller token is not 1010' }
    if ([int]$dispatch.SuccessorAddress -ne 0x9F16) { throw 'Source map successor address is not 9F16' }
    if ([int]$dispatch.SuccessorToken -ne 0x75A9) { throw 'Source map successor token is not 75A9' }
    if ([int]$dispatch.RejoinAddress -ne 0x00FC) { throw 'Source map rejoin address is not 00FC' }
    if ([int]$dispatch.RejoinY -ne 0x9F16) { throw 'Source map rejoin Y is not 9F16' }
    if ([int]$dispatch.ParentTokenAddress -ne 0x9F3D) { throw 'Source map parent token address is not 9F3D' }
    if ([int]$dispatch.ParentToken -ne 0x9F10) { throw 'Source map parent token is not 9F10' }
    if ([int]$dispatch.ParentSuccessorAddress -ne 0x9F3F) { throw 'Source map parent successor address is not 9F3F' }
    if ([int]$dispatch.ParentSuccessorToken -ne 0x792F) { throw 'Source map parent successor token is not 792F' }

    $semantics = $Map.Semantics
    if ([bool]$semantics.DataStackPointerUnchanged -ne $true) { throw 'Source map does not preserve U' }
    if ([bool]$semantics.ControlStackPointerUnchanged -ne $true) { throw 'Source map does not preserve S' }
    if ([bool]$semantics.CursorUnchanged -ne $true) { throw 'Source map does not preserve Y' }
    if ([bool]$semantics.DClobbered -ne $true) { throw 'Source map does not mark D clobbered' }
    if ([bool]$semantics.HDefinedOutput) { throw 'Source map wrongly defines an H output' }
    if (([string]$semantics.Classification) -notmatch 'static_prediction_not_execution') { throw 'Source map semantics are not static-only' }
    if ([int]$Map.OuterReturn.TokenAddress -ne 0x9F3D) { throw 'Source map outer return token address is not 9F3D' }
    if ([int]$Map.OuterReturn.Token -ne 0x9F10) { throw 'Source map outer return token is not 9F10' }
    if ([int]$Map.OuterReturn.SuccessorAddress -ne 0x9F3F) { throw 'Source map outer return successor address is not 9F3F' }
    if ([int]$Map.OuterReturn.SuccessorToken -ne 0x792F) { throw 'Source map outer return successor token is not 792F' }

    return [ordered]@{
        mapSha256 = $script:MapSha256
        builtSha256 = $script:BuiltSha256
        entryCount = $entries.Count
        instructionCount = $instructions.Count
        phaseCount = $phases.Count
        changedOffsetCount = $actualDiff.Count
        integrityFields = $script:FieldsHex
        controlTop = Format-Hex16 $script:ControlTop
    }
}

function ConvertTo-LuaString {
    param([string]$Text)
    return '"' + $Text.Replace('\','\\').Replace('"','\"') + '"'
}

function ConvertTo-LuaInt {
    param($Value)
    if ($null -eq $Value) { return 'nil' }
    return ('0x{0:X}' -f [int]$Value)
}

function Get-NativeMapLuaText {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('return {')
    [void]$sb.AppendLine('  schemaVersion = 1,')
    [void]$sb.AppendLine(('  protocol = "{0}",' -f $script:Protocol))
    [void]$sb.AppendLine(('  imageSha256 = "{0}",' -f $script:BuiltSha256))
    [void]$sb.AppendLine(('  originalRomSha256 = "{0}",' -f $script:OriginalSha256))
    [void]$sb.AppendLine('  tokenAddress = 0x1010,')
    [void]$sb.AppendLine('  tokenValue = 0x1012,')
    [void]$sb.AppendLine('  handlerStart = 0x1012,')
    [void]$sb.AppendLine('  handlerEndExclusive = 0x101B,')
    $handlerBytes = New-Object 'System.Collections.Generic.List[string]'
    for ($i = 0; $i -lt $script:HandlerHex.Length; $i += 2) { $handlerBytes.Add(('0x{0}' -f $script:HandlerHex.Substring($i,2))) }
    [void]$sb.AppendLine(('  handlerBytes = {{ {0} }},' -f ($handlerBytes -join ', ')))
    [void]$sb.AppendLine('  callerAddress = 0x9F14,')
    [void]$sb.AppendLine('  callerToken = 0x1010,')
    [void]$sb.AppendLine('  successorAddress = 0x9F16,')
    [void]$sb.AppendLine('  successorToken = 0x75A9,')
    [void]$sb.AppendLine('  controlTop = 0x9F3F,')
    [void]$sb.AppendLine('  phases = {')
    foreach ($phase in $script:Phases) {
        [void]$sb.AppendLine('    {')
        [void]$sb.AppendLine(('      name = {0},' -f (ConvertTo-LuaString $phase.name)))
        [void]$sb.AppendLine(('      pc = 0x{0:X},' -f $phase.pc))
        [void]$sb.AppendLine(('      x = {0},' -f (ConvertTo-LuaInt $phase.x)))
        [void]$sb.AppendLine(('      y = 0x{0:X},' -f $phase.y))
        [void]$sb.AppendLine(('      u = 0x{0:X},' -f $phase.u))
        [void]$sb.AppendLine(('      s = 0x{0:X},' -f $phase.s))
        [void]$sb.AppendLine(('      top = 0x{0:X},' -f $phase.top))
        [void]$sb.AppendLine(('      d = {0},' -f (ConvertTo-LuaInt $phase.d)))
        [void]$sb.AppendLine(('      token = 0x{0:X},' -f $phase.token))
        [void]$sb.AppendLine(('      tokenAddress = 0x{0:X},' -f $phase.tokenAddress))
        [void]$sb.AppendLine(('      control0 = {0},' -f (ConvertTo-LuaInt $phase.control0)))
        [void]$sb.AppendLine(('      requireX = {0},' -f ($(if ($phase.requireX) { 'true' } else { 'false' }))))
        [void]$sb.AppendLine(('      requireD = {0},' -f ($(if ($phase.requireD) { 'true' } else { 'false' }))))
        [void]$sb.AppendLine(('      savedCursorFromControl = {0}' -f ($(if ($phase.savedCursorFromControl) { 'true' } else { 'false' }))))
        [void]$sb.AppendLine('    },')
    }
    [void]$sb.AppendLine('  }')
    [void]$sb.AppendLine('}')
    return $sb.ToString()
}

function Write-NativeMapLua {
    param([string]$Path)
    [IO.File]::WriteAllText($Path,(Get-NativeMapLuaText),$script:Utf8)
}

function Get-NativeConfigLuaText {
    param($Config)
    $entries = New-Object 'System.Collections.Generic.List[object]'
    if ($Config -is [System.Collections.IDictionary]) {
        foreach ($key in $Config.Keys) { $entries.Add([ordered]@{ key=[string]$key; value=$Config[$key] }) }
    }
    else {
        foreach ($property in $Config.PSObject.Properties) { $entries.Add([ordered]@{ key=[string]$property.Name; value=$property.Value }) }
    }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('return {')
    foreach ($entry in $entries) {
        $key = $entry.key
        $value = $entry.value
        if ($value -is [int] -or $value -is [long]) { [void]$sb.AppendLine(('  {0} = {1},' -f $key,$value)) }
        else { [void]$sb.AppendLine(('  {0} = {1},' -f $key,(ConvertTo-LuaString ([string]$value)))) }
    }
    [void]$sb.AppendLine('}')
    return $sb.ToString()
}

function Write-NativeConfigLua {
    param([string]$Path,$Config)
    [IO.File]::WriteAllText($Path,(Get-NativeConfigLuaText $Config),$script:Utf8)
}

function Invoke-ProcessRecord {
    param([string]$FilePath,[string[]]$Arguments,[string]$WorkingDirectory,[string]$StdOutPath,[string]$StdErrPath,[int]$TimeoutSeconds)
    $quoted = foreach ($arg in $Arguments) {
        $text = [string]$arg
        if ($text -match '[\s"]') { '"' + $text.Replace('"','\"') + '"' } else { $text }
    }
    $argumentString = ($quoted -join ' ')
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = [IO.Path]::GetFullPath($FilePath)
    $startInfo.Arguments = $argumentString
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    $startUtc = [DateTime]::UtcNow
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    if (-not $process.Start()) { throw "Failed to start process: $FilePath" }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = $false
    $exitCode = $null
    try {
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $timedOut = $true
            & "$env:SystemRoot\System32\taskkill.exe" /PID $process.Id /T /F 2>&1 | Out-Null
            $process.WaitForExit(30000) | Out-Null
        }
        if ($process.HasExited) { $exitCode = $process.ExitCode }
        [IO.File]::WriteAllText($StdOutPath,$stdoutTask.GetAwaiter().GetResult(),$script:Utf8)
        [IO.File]::WriteAllText($StdErrPath,$stderrTask.GetAwaiter().GetResult(),$script:Utf8)
    }
    finally {
        $stopwatch.Stop()
        if (-not $process.HasExited) {
            & "$env:SystemRoot\System32\taskkill.exe" /PID $process.Id /T /F 2>&1 | Out-Null
            $process.WaitForExit(30000) | Out-Null
            if ($process.HasExited) { $exitCode = $process.ExitCode }
        }
        $process.Dispose()
    }
    return [ordered]@{
        commandLine = $argumentString
        startUtc = $startUtc.ToString('o')
        endUtc = [DateTime]::UtcNow.ToString('o')
        wallSeconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds,3)
        timeoutSeconds = $TimeoutSeconds
        timedOut = $timedOut
        exitCode = $exitCode
    }
}

function Invoke-StrictEventsParse {
    param([string]$EventsPath,[string]$OutputPath)
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $pwsh) { throw 'pwsh is required for strict System.Text.Json event validation' }
    $helper = Join-Path $script:Root 'tests/worker/Test-IlEventJson.ps1'
    if (!(Test-Path -LiteralPath $helper -PathType Leaf)) { throw "Strict JSON helper is missing: $helper" }
    $record = Invoke-ProcessRecord -FilePath $pwsh.Source -Arguments @('-NoProfile','-File',$helper,'-Mode','Parse','-EventsPath',$EventsPath,'-OutputPath',$OutputPath) -WorkingDirectory $script:Root -StdOutPath ($OutputPath + '.stdout.log') -StdErrPath ($OutputPath + '.stderr.log') -TimeoutSeconds 120
    if ($record.timedOut -or $record.exitCode -ne 0) {
        $stderr = if (Test-Path -LiteralPath ($OutputPath + '.stderr.log')) { Get-Content -LiteralPath ($OutputPath + '.stderr.log') -Raw } else { '' }
        throw "Strict JSONL parse failed (exit=$($record.exitCode) timedOut=$($record.timedOut)): $stderr"
    }
    if (!(Test-Path -LiteralPath $OutputPath -PathType Leaf)) { throw 'Strict JSONL parser did not write a summary' }
    $summary = Get-Content -LiteralPath $OutputPath -Raw | ConvertFrom-Json
    if (-not [bool]$summary.pass) { throw 'Strict JSONL parser reported a failure' }
    return [ordered]@{ summary=$summary; sha256=(Get-HashValue $EventsPath 'SHA256'); recordCount=[int]$summary.nonblank }
}

function Invoke-StrictDuplicateKeyCheck {
    param([string]$EventsPath)
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $pwsh) { throw 'pwsh is required for strict duplicate-key validation' }
    $path = [IO.Path]::GetFullPath($EventsPath)
    $scriptText = @"
`$path = '$($path.Replace("'","''"))'
`$options = [System.Text.Json.JsonDocumentOptions]::new()
`$options.AllowTrailingCommas = `$false
`$options.CommentHandling = [System.Text.Json.JsonCommentHandling]::Disallow
`$lineNo = 0
foreach (`$line in [IO.File]::ReadAllLines(`$path)) {
    `$lineNo++
    if ([string]::IsNullOrWhiteSpace(`$line)) { continue }
    `$doc = `$null
    try {
        `$doc = [System.Text.Json.JsonDocument]::Parse(`$line, `$options)
        `$seen = @{}
        foreach (`$prop in `$doc.RootElement.EnumerateObject()) {
            if (`$seen.ContainsKey(`$prop.Name)) { Write-Output ('duplicate:{0}:{1}' -f `$lineNo,`$prop.Name); exit 3 }
            `$seen[`$prop.Name] = `$true
        }
    }
    finally { if (`$null -ne `$doc) { `$doc.Dispose() } }
}
exit 0
"@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($scriptText))
    $token = [guid]::NewGuid().ToString('N')
    $stdoutPath = Join-Path ([IO.Path]::GetTempPath()) ("il-native-dup-$token.stdout.log")
    $stderrPath = Join-Path ([IO.Path]::GetTempPath()) ("il-native-dup-$token.stderr.log")
    try {
        $record = Invoke-ProcessRecord -FilePath $pwsh.Source -Arguments @('-NoProfile','-NonInteractive','-EncodedCommand',$encoded) -WorkingDirectory $script:Root -StdOutPath $stdoutPath -StdErrPath $stderrPath -TimeoutSeconds 120
        if ($record.timedOut -or $record.exitCode -ne 0) {
            $detail = if (Test-Path -LiteralPath $stdoutPath) { (Get-Content -LiteralPath $stdoutPath -Raw).Trim() } else { '' }
            $stderr = if (Test-Path -LiteralPath $stderrPath) { (Get-Content -LiteralPath $stderrPath -Raw).Trim() } else { '' }
            throw "Strict JSON duplicate-key validation failed (exit=$($record.exitCode) timedOut=$($record.timedOut)): $detail $stderr"
        }
    }
    finally {
        Remove-Item -LiteralPath $stdoutPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Get-ArgumentValues {
    param([string[]]$Arguments,[string]$Name)
    $values = New-Object 'System.Collections.Generic.List[string]'
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        if ($Arguments[$i] -ieq $Name) {
            if ($i + 1 -ge $Arguments.Count) { throw "MAME argument $Name has no value" }
            $values.Add([string]$Arguments[$i + 1])
            $i++
        }
    }
    return $values.ToArray()
}

function Assert-MameInvocationIsolation {
    param([string]$LaunchRun)
    $launch = [IO.Path]::GetFullPath($LaunchRun).TrimEnd('\')
    $argumentsPath = Join-Path $launch 'arguments.json'
    if (!(Test-Path -LiteralPath $argumentsPath -PathType Leaf)) { throw 'MAME invocation record is missing: arguments.json' }
    $raw = Get-Content -LiteralPath $argumentsPath -Raw | ConvertFrom-Json
    $arguments = @($raw | ForEach-Object { [string]$_ })
    if ($arguments.Count -lt 2) { throw 'MAME invocation record is empty or malformed' }
    if ($arguments[0] -ine 'm4addr') { throw "MAME invocation system is $($arguments[0]), expected m4addr" }
    foreach ($switch in @('-noreadconfig','-debug','-debuglog','-skip_gameinfo','-nothrottle')) {
        if (-not ($arguments -contains $switch)) { throw "MAME invocation is missing $switch" }
    }
    $pairs = [ordered]@{
        '-debugger' = 'imgui'
        '-video' = 'bgfx'
        '-sound' = 'none'
        '-autoboot_delay' = '0'
    }
    foreach ($key in $pairs.Keys) {
        $values = @(Get-ArgumentValues $arguments $key)
        if ($values.Count -ne 1) { throw "MAME invocation has $($values.Count) $key values, expected 1" }
        if ($values[0] -ine $pairs[$key]) { throw "MAME invocation $key is $($values[0]), expected $($pairs[$key])" }
    }
    $seconds = @(Get-ArgumentValues $arguments '-seconds_to_run')
    if ($seconds.Count -ne 1) { throw "MAME invocation has $($seconds.Count) -seconds_to_run values, expected 1" }
    $secondsValue = 0
    if (![int]::TryParse($seconds[0], [ref]$secondsValue) -or $secondsValue -lt 1 -or $secondsValue -gt 180) {
        throw "MAME invocation -seconds_to_run is $($seconds[0]), expected 1..180"
    }
    $directoryMap = [ordered]@{
        '-cfg_directory' = 'cfg'
        '-nvram_directory' = 'nvram'
        '-input_directory' = 'inp'
        '-snapshot_directory' = 'snap'
        '-comment_directory' = 'comments'
        '-state_directory' = 'state'
        '-diff_directory' = 'diff'
    }
    foreach ($key in $directoryMap.Keys) {
        $values = @(Get-ArgumentValues $arguments $key)
        if ($values.Count -ne 1) { throw "MAME invocation has $($values.Count) $key values, expected 1" }
        $actual = [IO.Path]::GetFullPath($values[0]).TrimEnd('\')
        $expected = [IO.Path]::GetFullPath((Join-Path $launch $directoryMap[$key])).TrimEnd('\')
        if ($actual -ine $expected) { throw "MAME invocation $key is $actual, expected isolated $expected" }
    }
    $romPaths = @(Get-ArgumentValues $arguments '-rompath')
    if ($romPaths.Count -ne 1) { throw "MAME invocation has $($romPaths.Count) -rompath values, expected 1" }
    $romParts = @($romPaths[0].Split(';'))
    $expectedRunRoms = [IO.Path]::GetFullPath((Join-Path $launch 'roms')).TrimEnd('\')
    $actualFirstRom = [IO.Path]::GetFullPath($romParts[0]).TrimEnd('\')
    if ($actualFirstRom -ine $expectedRunRoms) { throw "MAME invocation first ROM path is $actualFirstRom, expected isolated $expectedRunRoms" }
    $observer = @(Get-ArgumentValues $arguments '-autoboot_script')
    if ($observer.Count -ne 1) { throw "MAME invocation has $($observer.Count) -autoboot_script values, expected 1" }
    $expectedObserver = [IO.Path]::GetFullPath((Join-Path $launch 'observer.lua')).TrimEnd('\')
    $actualObserver = [IO.Path]::GetFullPath($observer[0]).TrimEnd('\')
    if ($actualObserver -ine $expectedObserver) { throw "MAME invocation autoboot script is $actualObserver, expected run-local $expectedObserver" }
    $forbidden = @('-playback','-record','-state','-loadstate','-autosave','-debugscript','-snapshot','-aviwrite','-mngwrite','-wavwrite')
    foreach ($switch in $forbidden) {
        if ($arguments -contains $switch) { throw "MAME invocation contains forbidden $switch" }
    }
    return [ordered]@{
        launchRunDirectory = $launch
        argumentsPath = [IO.Path]::GetFullPath($argumentsPath)
        argumentsSha256 = Get-HashValue $argumentsPath 'SHA256'
        secondsToRun = $secondsValue
        romPath = $romPaths[0]
        observer = $actualObserver
        isolatedDirectories = @($directoryMap.Keys)
        forbiddenSwitchesAbsent = $forbidden
    }
}

function Get-MetadataPath {
    param([string]$Run,[string]$Name)
    return (Join-Path $Run $Name)
}

function Assert-EventIdentity {
    param($Event,[string]$BuildSha,[string]$MapSha,[string]$LuaSha,[string]$MameSha,[string]$SessionId)
    if ([string]$Event.buildSha256 -ine $BuildSha) { throw "Event $($Event.event) build identity is wrong" }
    if ([string]$Event.mapSha256 -ine $MapSha) { throw "Event $($Event.event) map identity is wrong" }
    if ([string]$Event.luaSha256 -ine $LuaSha) { throw "Event $($Event.event) Lua identity is wrong" }
    if ([string]$Event.mameSha256 -ine $MameSha) { throw "Event $($Event.event) MAME identity is wrong" }
    if ([string]$Event.sessionId -ine $SessionId) { throw "Event $($Event.event) session id is wrong" }
}

function Assert-RunLocalAssets {
    param([string]$Run,$Metadata,$ConfigJson)
    $luaPath = Join-Path $Run 'IlNativePrimitiveNatural.lua'
    $mapLuaPath = Join-Path $Run 'native-primitive-map.lua'
    $configLuaPath = Join-Path $Run 'session-config.lua'
    $configJsonPath = Join-Path $Run 'session-config.json'
    $observerPath = Join-Path $Run 'observer.lua'

    $luaIdentity = Assert-FileHashIdentity $luaPath ([string]$Metadata.lua.capturedSha256) 'run-local observer Lua'
    $mapLuaHash = Get-HashValue $mapLuaPath 'SHA256'
    $expectedMapLuaHash = Get-StringSha256 (Get-NativeMapLuaText)
    if ($mapLuaHash -ine $expectedMapLuaHash) { throw "Run-local native-primitive-map.lua SHA256 is $mapLuaHash, expected canonical $expectedMapLuaHash" }
    $configJsonHash = Get-HashValue $configJsonPath 'SHA256'
    $configLuaHash = Get-HashValue $configLuaPath 'SHA256'
    $expectedConfigLuaHash = Get-StringSha256 (Get-NativeConfigLuaText $ConfigJson)
    if ($configLuaHash -ine $expectedConfigLuaHash) { throw "Run-local session-config.lua SHA256 is $configLuaHash, expected canonical $expectedConfigLuaHash" }
    $observerHash = Get-HashValue $observerPath 'SHA256'
    $observerText = [IO.File]::ReadAllText($observerPath,$script:Utf8)
    $expectedObserverText = "dofile('input.lua')`ndofile('IlNativePrimitiveNatural.lua')`n"
    if ($observerText -cne $expectedObserverText) { throw 'Run-local observer.lua is not the canonical tracked-replay observer composition' }

    if ([string]$ConfigJson.protocol -ne $script:Protocol) { throw 'Run-local session-config.json protocol mismatch' }
    if ([string]$ConfigJson.sessionId -ine [string]$Metadata.sessionId) { throw 'Run-local session-config.json session id differs from metadata' }
    if ([string]$ConfigJson.inputPolicy -ne 'tracked_physical_replay') { throw 'Run-local session-config.json input policy differs from metadata' }
    if ([string]$ConfigJson.expectedImageSha256 -ine $script:BuiltSha256) { throw 'Run-local session-config.json image identity is wrong' }
    if ([string]$ConfigJson.expectedOriginalRomSha256 -ine $script:OriginalSha256) { throw 'Run-local session-config.json original identity is wrong' }
    if ([string]$ConfigJson.expectedSourceMapSha256 -ine $script:MapSha256) { throw 'Run-local session-config.json map identity is wrong' }
    if ([string]$ConfigJson.expectedMameSha256 -ine $script:MameSha256) { throw 'Run-local session-config.json MAME identity is wrong' }
    if ([string]$ConfigJson.expectedLuaSha256 -ine [string]$Metadata.lua.capturedSha256) { throw 'Run-local session-config.json Lua identity differs from the captured observer' }
    if ([int]$ConfigJson.secondsToRun -ne [int]$Metadata.seconds_to_run) { throw 'Run-local session-config.json seconds do not match metadata' }
    if ([int]$ConfigJson.wallTimeoutSeconds -ne [int]$Metadata.wall_timeout_seconds) { throw 'Run-local session-config.json wall timeout does not match metadata' }
    if ([string]$ConfigJson.expectedReplaySha256 -ine $script:ReplaySha256) { throw 'Run-local session-config.json replay identity is wrong' }
    if ([string]$ConfigJson.expectedInputLuaSha256 -ine $script:InputLuaSha256) { throw 'Run-local session-config.json input Lua identity is wrong' }

    $legacyAbsent = $null -eq $Metadata.run_local_assets
    if (-not $legacyAbsent) {
        if ([string]$Metadata.run_local_assets.lua -ine $luaIdentity.sha256) { throw 'Metadata run-local Lua hash differs from the actual observer copy' }
        if ([string]$Metadata.run_local_assets.map_lua -ine $mapLuaHash) { throw 'Metadata run-local map Lua hash differs from the actual copy' }
        if ([string]$Metadata.run_local_assets.config_lua -ine $configLuaHash) { throw 'Metadata run-local config Lua hash differs from the actual copy' }
        if ([string]$Metadata.run_local_assets.config_json -ine $configJsonHash) { throw 'Metadata run-local config JSON hash differs from the actual copy' }
        if ([string]$Metadata.run_local_assets.observer -ine $observerHash) { throw 'Metadata run-local observer hash differs from the actual copy' }
    }

    return [ordered]@{
        lua = $luaIdentity
        mapLua = [ordered]@{ path=[IO.Path]::GetFullPath($mapLuaPath); sha256=$mapLuaHash; canonicalSha256=$expectedMapLuaHash }
        configLua = [ordered]@{ path=[IO.Path]::GetFullPath($configLuaPath); sha256=$configLuaHash; canonicalSha256=$expectedConfigLuaHash }
        configJson = [ordered]@{ path=[IO.Path]::GetFullPath($configJsonPath); sha256=$configJsonHash }
        observer = [ordered]@{ path=[IO.Path]::GetFullPath($observerPath); sha256=$observerHash; canonicalText=$expectedObserverText }
        metadataBinding = if ($legacyAbsent) { 'metadata_assets_absent_recomputed_from_run' } else { 'metadata_run_local_assets_match' }
        legacyMetadataAssetsAbsent = $legacyAbsent
        currentSourceLuaDiffers = ((Get-HashValue (Join-Path $script:Root 'tools/lua/IlNativePrimitiveNatural.lua') 'SHA256') -ine $luaIdentity.sha256)
    }
}

function Get-NativeAnalysis {
    param([string]$Run,[string]$BuiltPath,[string]$SourceMapPath,[string]$BuildReportPath,[string]$OriginalPath,[string]$ReanalysisSourceRun,[switch]$SkipStrictParse)

    $run = [IO.Path]::GetFullPath($Run)
    if (!(Test-Path -LiteralPath $run -PathType Container)) { throw "Run directory is missing: $run" }
    $metadataPath = Get-MetadataPath $run 'session-metadata.json'
    $metadata = Read-JsonFile $metadataPath
    if ([string]$metadata.protocol -ne $script:Protocol) { throw 'Session metadata protocol mismatch' }

    $builtPath = if ([string]::IsNullOrWhiteSpace($BuiltPath)) { [string]$metadata.built_rom.path } else { $BuiltPath }
    $sourceMapPath = if ([string]::IsNullOrWhiteSpace($SourceMapPath)) { [string]$metadata.source_map.path } else { $SourceMapPath }
    $buildReportPath = if ([string]::IsNullOrWhiteSpace($BuildReportPath)) { [string]$metadata.build_report.path } else { $BuildReportPath }
    $originalPath = if ([string]::IsNullOrWhiteSpace($OriginalPath)) { [string]$metadata.original_rom.path } else { $OriginalPath }

    $originalIdentity = Assert-FileIdentity $originalPath $script:OriginalSha1 $script:OriginalSha256 'analysis original ROM'
    $builtIdentity = Assert-FileIdentity $builtPath $script:BuiltSha1 $script:BuiltSha256 'analysis built ROM'
    $mapHash = Get-HashValue $sourceMapPath 'SHA256'
    if ($mapHash -ine $script:MapSha256) { throw "Source map SHA256 is $mapHash, expected $script:MapSha256" }
    $buildHash = Get-HashValue $buildReportPath 'SHA256'
    if ($buildHash -ine [string]$metadata.build_report.sha256) { throw "Build report SHA256 is $buildHash, expected $($metadata.build_report.sha256)" }
    if ([string]$metadata.source_map.sha256 -ine $mapHash) { throw 'Session metadata source map hash differs from the analysed map' }
    if ([string]$metadata.built_rom.sha256 -ine $script:BuiltSha256) { throw 'Session metadata built ROM hash is wrong' }
    if ([string]$metadata.original_rom.sha256 -ine $script:OriginalSha256) { throw 'Session metadata original ROM hash is wrong' }

    $built = [IO.File]::ReadAllBytes($builtPath)
    $original = [IO.File]::ReadAllBytes($originalPath)
    $map = Read-JsonFile $sourceMapPath
    $build = Read-JsonFile $buildReportPath
    $contract = Test-NativeMapContract $map $build $built $original

    $runRomPath = Join-Path $run 'roms/m4addr/a6ls.p1'
    $runRomIdentity = Assert-FileIdentity $runRomPath $script:BuiltSha1 $script:BuiltSha256 'isolated run ROM after execution'
    $stateFiles = @(Get-ChildItem -LiteralPath (Join-Path $run 'state') -Recurse -File -ErrorAction SilentlyContinue)
    if ($stateFiles.Count -ne 0) { throw 'State directory contains files; a save state may have been loaded or written' }
    foreach ($sideEffectDir in @('inp','snap','comments','diff')) {
        $sideEffectFiles = @(Get-ChildItem -LiteralPath (Join-Path $run $sideEffectDir) -Recurse -File -ErrorAction SilentlyContinue)
        if ($sideEffectFiles.Count -ne 0) { throw "Side-effect directory $sideEffectDir contains files; the run was not observation-only" }
    }

    if ([bool]$metadata.save_state_loaded) { throw 'Session metadata claims a save state was loaded' }
    if ([bool]$metadata.state_injection) { throw 'Session metadata claims state injection' }
    if ([bool]$metadata.input_injection) { throw 'Session metadata claims input injection' }
    if ([bool]$metadata.debugger_writes) { throw 'Session metadata claims debugger writes' }
    if ([string]$metadata.starting_nvram -ne 'absent') { throw 'Session did not start with absent NVRAM' }
    if ([string]$metadata.starting_configuration -notmatch 'absent') { throw 'Session did not start with absent configuration' }
    $evidenceClass = if ($null -eq $metadata.evidence_class) { 'natural' } else { [string]$metadata.evidence_class }
    if ($evidenceClass -notin @('natural','synthetic_checker_fixture')) { throw "Session evidence class is not supported: $evidenceClass" }
    if ([string]$metadata.input_policy -ne 'tracked_physical_replay') { throw 'Session input policy is not tracked_physical_replay' }
    $mameInvocation = $null
    if ($evidenceClass -eq 'natural') {
        $launchRun = if (![string]::IsNullOrWhiteSpace($ReanalysisSourceRun)) { [IO.Path]::GetFullPath($ReanalysisSourceRun) } else { $run }
        $mameInvocation = Assert-MameInvocationIsolation $launchRun
    }

    if (-not [bool]$metadata.input_replay_used) { throw 'Session metadata does not claim tracked physical input replay' }
    $replayPath = Join-Path $run 'replay-actions.csv'
    $inputLuaPath = Join-Path $run 'input.lua'
    $replayIdentity = Assert-FileHashIdentity $replayPath $script:ReplaySha256 'tracked replay fixture'
    $inputLuaIdentity = Assert-FileHashIdentity $inputLuaPath $script:InputLuaSha256 'tracked input Lua'
    if ($null -eq $metadata.input_replay) { throw 'Session metadata is missing the input replay provenance block' }
    if ([string]$metadata.input_replay.sha256 -ine $script:ReplaySha256) { throw 'Session metadata replay hash is not the prior tracked fixture' }
    if ([string]$metadata.input_replay.input_lua_sha256 -ine $script:InputLuaSha256) { throw 'Session metadata input Lua hash is not the prior tracked script' }
    if ([string]$metadata.input_replay.classification -ne 'tracked_physical_input_replay_no_state_injection') { throw 'Session metadata input replay classification is wrong' }
    $replaySchedule = Get-ReplaySchedule $replayPath
    $levelProvenance = Get-InputProvenance $run $replaySchedule
    $inputProvenance = [ordered]@{
        policy = 'tracked_physical_replay'
        used = $true
        classification = 'tracked_physical_input_replay_no_state_injection'
        replay = [ordered]@{
            path = $replayIdentity.path
            length = $replayIdentity.length
            sha256 = $replayIdentity.sha256
            coinEvent = $replaySchedule.coin
            startEvent = $replaySchedule.start
        }
        inputLua = $inputLuaIdentity
        observed = $levelProvenance
        stateInjection = $false
        inputInjection = $false
    }

    $runConfigJson = Read-JsonFile (Join-Path $run 'session-config.json')
    $runLocalAssets = Assert-RunLocalAssets $run $metadata $runConfigJson

    $eventsPath = Join-Path $run 'events.jsonl'
    if (!(Test-Path -LiteralPath $eventsPath -PathType Leaf)) { throw "Event log is missing: $eventsPath" }
    Invoke-StrictDuplicateKeyCheck $eventsPath
    $parseInfo = $null
    if ($SkipStrictParse) {
        $records = New-Object 'System.Collections.Generic.List[object]'
        foreach ($line in Get-Content -LiteralPath $eventsPath) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $records.Add(($line | ConvertFrom-Json -ErrorAction Stop))
        }
        $parseInfo = [ordered]@{ sha256=(Get-HashValue $eventsPath 'SHA256'); recordCount=$records.Count; strict=$false }
    }
    else {
        $strictPath = Join-Path $run 'events-strict.json'
        $strict = Invoke-StrictEventsParse $eventsPath $strictPath
        $records = New-Object 'System.Collections.Generic.List[object]'
        foreach ($record in @($strict.summary.records)) { $records.Add($record) }
        $parseInfo = [ordered]@{ sha256=$strict.sha256; recordCount=$strict.recordCount; strict=$true; summaryPath=[IO.Path]::GetFullPath($strictPath); summarySha256=(Get-HashValue $strictPath 'SHA256') }
    }
    if ($records.Count -eq 0) { throw 'Event log is empty' }
    foreach ($record in $records) {
        if (@($record.PSObject.Properties.Name) -contains 'dp') { throw "Event $($record.event) contains an unsupported DP field; the captured observer did not sample DP" }
    }

    $ready = @($records | Where-Object { [string]$_.event -eq 'session_ready' })
    if ($ready.Count -ne 1) { throw "Event log has $($ready.Count) session_ready records, expected 1" }
    $readyEvent = $ready[0]
    if ([string]$readyEvent.imageSha256 -ine $script:BuiltSha256) { throw 'Session ready image identity is wrong' }
    if ([string]$readyEvent.originalRomSha256 -ine $script:OriginalSha256) { throw 'Session ready original identity is wrong' }
    if ([string]$readyEvent.sourceMapSha256 -ine $mapHash) { throw 'Session ready map identity is wrong' }
    if ([string]$readyEvent.buildReportSha256 -ine $buildHash) { throw 'Session ready build report identity is wrong' }
    if ([string]$readyEvent.luaSha256 -ine [string]$metadata.lua.capturedSha256) { throw 'Session ready Lua identity is wrong' }
    if ([string]$readyEvent.mameSha256 -ine $script:MameSha256) { throw 'Session ready MAME identity is wrong' }
    if ([string]$readyEvent.inputPolicy -ne 'tracked_physical_replay') { throw 'Session ready input policy is wrong' }
    if ([string]$readyEvent.replaySha256 -ine $script:ReplaySha256) { throw 'Session ready replay identity is wrong' }
    if ([string]$readyEvent.inputLuaSha256 -ine $script:InputLuaSha256) { throw 'Session ready input Lua identity is wrong' }
    if ([string]$readyEvent.boundarySource -ne 'native_debugger_bpset') { throw 'Session boundaries are not native debugger breakpoints' }
    if ((ConvertTo-HexInt ([string]$readyEvent.tokenAddress)) -ne 0x1010) { throw 'Session ready token address is not 1010' }
    if ((ConvertTo-HexInt ([string]$readyEvent.tokenValue)) -ne 0x1012) { throw 'Session ready token value is not 1012' }
    if ((ConvertTo-HexInt ([string]$readyEvent.handlerStart)) -ne 0x1012) { throw 'Session ready handler start is not 1012' }
    if ((ConvertTo-HexInt ([string]$readyEvent.handlerEndExclusive)) -ne 0x101B) { throw 'Session ready handler end is not 101B' }
    if ((ConvertTo-HexInt ([string]$readyEvent.callerAddress)) -ne 0x9F14) { throw 'Session ready caller is not 9F14' }
    if ((ConvertTo-HexInt ([string]$readyEvent.callerToken)) -ne 0x1010) { throw 'Session ready caller token is not 1010' }
    if ((ConvertTo-HexInt ([string]$readyEvent.successorAddress)) -ne 0x9F16) { throw 'Session ready successor is not 9F16' }
    if ((ConvertTo-HexInt ([string]$readyEvent.successorToken)) -ne 0x75A9) { throw 'Session ready successor token is not 75A9' }
    if ((ConvertTo-HexInt ([string]$readyEvent.controlTop)) -ne 0x9F3F) { throw 'Session ready control top is not 9F3F' }

    $complete = @($records | Where-Object { [string]$_.event -eq 'session_complete' })
    if ($complete.Count -ne 1) { throw "Event log has $($complete.Count) session_complete records, expected 1" }
    $completeEvent = $complete[0]
    $timeouts = @($records | Where-Object { [string]$_.event -eq 'session_timeout' })
    $failures = @($records | Where-Object { [string]$_.event -in @('startup_failure','protocol_failure') })
    $failure = if ($failures.Count -gt 0) { $failures[0] } else { $null }
    if ($failures.Count -gt 1) { throw "Event log contains $($failures.Count) failure records" }

    $phaseEvents = @($records | Where-Object { [string]$_.event -eq 'phase' })
    if ($phaseEvents.Count -gt $script:Phases.Count) { throw "Event log has $($phaseEvents.Count) phase records, expected at most $($script:Phases.Count)" }

    $allowedEventTypes = @('session_ready','phase','session_timeout','startup_failure','protocol_failure','session_complete')
    $readyIndex = -1
    $completeIndex = -1
    $phaseIndexes = New-Object 'System.Collections.Generic.List[int]'
    $terminalIndex = -1
    for ($i = 0; $i -lt $records.Count; $i++) {
        $type = [string]$records[$i].event
        if ($type -notin $allowedEventTypes) { throw "Event log contains unexpected event type '$type' at record $i" }
        if ($type -eq 'session_ready') {
            if ($readyIndex -ge 0) { throw 'Event log contains duplicate session_ready records' }
            $readyIndex = $i
        }
        elseif ($type -eq 'session_complete') {
            if ($completeIndex -ge 0) { throw 'Event log contains duplicate session_complete records' }
            $completeIndex = $i
        }
        elseif ($type -eq 'phase') { [void]$phaseIndexes.Add($i) }
        else { $terminalIndex = $i }
    }
    if ($readyIndex -ne 0) { throw "session_ready is at record $readyIndex, expected the first record" }
    if ($completeIndex -ne $records.Count - 1) { throw "session_complete is at record $completeIndex, expected the last record" }
    if ($timeouts.Count -gt 1) { throw "Event log contains $($timeouts.Count) session_timeout records" }
    if ($failures.Count -gt 1) { throw "Event log contains $($failures.Count) failure records" }
    if (($timeouts.Count + $failures.Count) -gt 1) { throw 'Event log contains more than one terminal failure/timeout record' }
    if ($phaseIndexes.Count -gt 0) {
        if ($phaseIndexes[0] -ne 1) { throw "The first phase record is at index $($phaseIndexes[0]), expected immediately after session_ready" }
        for ($i = 0; $i -lt $phaseIndexes.Count; $i++) {
            if ($phaseIndexes[$i] -ne (1 + $i)) { throw "Phase records are not contiguous at record $($phaseIndexes[$i])" }
        }
    }
    $lastPhaseIndex = if ($phaseIndexes.Count -gt 0) { $phaseIndexes[$phaseIndexes.Count - 1] } else { 0 }
    if ($terminalIndex -ge 0) {
        if ($terminalIndex -le $lastPhaseIndex) { throw "Terminal failure/timeout at record $terminalIndex precedes the last observed phase at record $lastPhaseIndex" }
        if ($terminalIndex -ge $completeIndex) { throw "Terminal failure/timeout at record $terminalIndex is not before session_complete" }
    }
    $completeClaim = ([string]$completeEvent.complete -eq 'true')
    $reason = [string]$completeEvent.reason
    if ($completeClaim -and $terminalIndex -ge 0) { throw 'Session claims completion despite a terminal failure/timeout record' }

    $phaseRecords = New-Object 'System.Collections.Generic.List[object]'
    $u0 = $null
    $s0 = $null
    $inputWord = $null
    $handlerWord = $null
    $resultWord = $null
    for ($i = 0; $i -lt $phaseEvents.Count; $i++) {
        $event = $phaseEvents[$i]
        $expected = $script:Phases[$i]
        $name = $expected.name
        Assert-EventIdentity $event $script:BuiltSha256 $mapHash ([string]$metadata.lua.capturedSha256) $script:MameSha256 ([string]$metadata.sessionId)
        if ([string]$event.phase -ne $name) { throw "Phase $i is $($event.phase), expected $name" }
        if ([int]$event.phaseIndex -ne $i) { throw "Phase $name index is $($event.phaseIndex)" }
        if ($event.PSObject.Properties.Name -contains 'dp') { throw "Phase $name contains an unsupported DP field; the captured observer did not sample DP" }
        foreach ($field in @('pc','x','y','u','s','d','a','b','token','tokenAddress','dataStack0','dataStack1','dataStack2','dataStack3','controlStack0','controlStack1','controlStack2','controlStack3','cc','emulatedTime')) {
            $value = [string]$event.$field
            if ([string]::IsNullOrWhiteSpace($value)) { throw "Phase $name field $field is missing or null" }
        }
        foreach ($field in @('savedCursor','savedCursorSource')) {
            if (@($event.PSObject.Properties.Name) -notcontains $field) { throw "Phase $name field $field is missing" }
        }
        if ($event.PSObject.Properties.Name -contains 'h') { throw "Phase $name outputs an H field; H must not be asserted" }
        foreach ($field in @('dataStack0','dataStack1','dataStack2','dataStack3','controlStack0','controlStack1','controlStack2','controlStack3','cc')) {
            [void](ConvertTo-HexInt ([string]$event.$field))
        }
        $eventA = ConvertTo-HexInt ([string]$event.a)
        $eventB = ConvertTo-HexInt ([string]$event.b)
        $eventD = ConvertTo-HexInt ([string]$event.d)
        if (($eventD -band 0xFFFF) -ne (((($eventA -band 0xFF) -shl 8) -bor ($eventB -band 0xFF)) -band 0xFFFF)) {
            throw "Phase $name D $($event.d) is not the live A/B pair $($event.a)/$($event.b)"
        }
        if ((ConvertTo-HexInt ([string]$event.pc)) -ne $expected.pc) { throw "Phase $name PC $($event.pc) is not $(Format-Hex16 $expected.pc)" }
        if ((ConvertTo-HexInt ([string]$event.y)) -ne $expected.y) { throw "Phase $name Y $($event.y) is not $(Format-Hex16 $expected.y)" }
        if ($expected.requireX) {
            if ((ConvertTo-HexInt ([string]$event.x)) -ne $expected.x) { throw "Phase $name X $($event.x) is not $(Format-Hex16 $expected.x)" }
        }
        if ((ConvertTo-HexInt ([string]$event.u)) -ne $expected.u) { throw "Phase $name U $($event.u) is not $(Format-Hex16 $expected.u)" }
        if ((ConvertTo-HexInt ([string]$event.s)) -ne $expected.s) { throw "Phase $name S $($event.s) is not $(Format-Hex16 $expected.s)" }
        if ($expected.requireD) {
            if ((ConvertTo-HexInt ([string]$event.d)) -ne $expected.d) { throw "Phase $name D $($event.d) is not $(Format-Hex16 $expected.d)" }
        }
        if ((ConvertTo-HexInt ([string]$event.dataStack0)) -ne $expected.top) { throw "Phase $name top stack word $($event.dataStack0) is not $(Format-Hex16 $expected.top)" }
        if ((ConvertTo-HexInt ([string]$event.token)) -ne $expected.token) { throw "Phase $name token $($event.token) is not $(Format-Hex16 $expected.token)" }
        if ((ConvertTo-HexInt ([string]$event.tokenAddress)) -ne $expected.tokenAddress) { throw "Phase $name token address $($event.tokenAddress) is not $(Format-Hex16 $expected.tokenAddress)" }
        if ($null -ne $expected.control0) {
            if ((ConvertTo-HexInt ([string]$event.controlStack0)) -ne $expected.control0) { throw "Phase $name control stack top $($event.controlStack0) is not $(Format-Hex16 $expected.control0)" }
            if ([string]$event.controlStack0 -ieq '9F16') { throw "Phase $name uses the old composite saved cursor 9F16" }
        }
        if ($expected.savedCursorFromControl) {
            if ([string]$event.savedCursor -ine (Format-Hex16 $expected.control0)) { throw "Phase $name saved cursor $($event.savedCursor) is not the live control top $(Format-Hex16 $expected.control0)" }
            if ([string]$event.savedCursorSource -ne 'live_control_stack_top') { throw "Phase $name saved cursor is not marked as the live control stack top" }
        }
        else {
            if (-not [string]::IsNullOrWhiteSpace([string]$event.savedCursor)) { throw "Phase $name has a saved cursor where no new save frame exists" }
        }
        if ($null -eq $u0) {
            $u0 = ConvertTo-HexInt ([string]$event.u)
            $s0 = ConvertTo-HexInt ([string]$event.s)
            $inputWord = ConvertTo-HexInt ([string]$event.dataStack0)
            if ($inputWord -ne 0x0000) { throw ("Observed input word is $(Format-Hex16 $inputWord), expected 0000") }
        }
        if ($name -eq 'after-std') { $handlerWord = ConvertTo-HexInt ([string]$event.dataStack0) }
        if ($name -eq 'post-75a9') { $resultWord = ConvertTo-HexInt ([string]$event.dataStack0) }
        $phaseRecords.Add([ordered]@{
            phase = $name
            pc = [string]$event.pc
            x = [string]$event.x
            y = [string]$event.y
            u = [string]$event.u
            s = [string]$event.s
            a = [string]$event.a
            b = [string]$event.b
            d = [string]$event.d
            cc = [string]$event.cc
            token = [string]$event.token
            tokenAddress = [string]$event.tokenAddress
            dataStack0 = [string]$event.dataStack0
            dataStack1 = [string]$event.dataStack1
            dataStack2 = [string]$event.dataStack2
            dataStack3 = [string]$event.dataStack3
            controlStack0 = [string]$event.controlStack0
            controlStack1 = [string]$event.controlStack1
            controlStack2 = [string]$event.controlStack2
            controlStack3 = [string]$event.controlStack3
            savedCursor = [string]$event.savedCursor
            savedCursorSource = [string]$event.savedCursorSource
            emulatedTime = [string]$event.emulatedTime
        })
    }

    $postHandlerPhase = $phaseRecords | Where-Object { $_.phase -eq 'post-handler-prefetch' } | Select-Object -First 1
    $handlerJmpBytes = $script:HandlerHex.Substring($script:HandlerHex.Length - 4)
    $observedPostHandlerPc = if ($null -ne $postHandlerPhase) { [string]$postHandlerPhase.pc } else { '' }
    $dpDeduced = ($observedPostHandlerPc -ieq '00FC') -and ($handlerJmpBytes -ieq '0EFC')
    $dpStatus = if ($dpDeduced) { 'deduced_zero_not_directly_measured' } elseif ($null -eq $postHandlerPhase) { 'not_observed' } else { 'not_deduced' }
    $registerEvidence = [ordered]@{
        liveFields = @('PC','X','Y','U','S','D (derived from live A/B)','CC','token','tokenAddress','dataStack0..3','controlStack0..3')
        savedCursor = [ordered]@{
            source = 'live_control_stack_top_only_when_a_save_frame_exists'
            invented = $false
        }
        dp = [ordered]@{
            directObservation = $false
            status = $dpStatus
            classification = 'static_deduction_from_live_pc_and_exact_handler_bytes'
            handlerJmpBytes = $handlerJmpBytes
            observedPostHandlerPc = $observedPostHandlerPc
            reasoning = 'The captured Lua snapshot has no DP sample. The built handler ends in 0E FC, the M6809 JMP direct-page opcode with an 8-bit target FC. At the post-handler breakpoint the live PC is 00FC. A direct-page JMP would target DP:00FC, so observed PC=00FC implies DP=0. LDD, ADDD, STD and JMP do not write DP, so the same DP holds at handler entry 1012. This is a static deduction from exact bytes plus a live PC, not a direct DP measurement.'
            appliesTo = 'this call/boundary only'
            directObservationRemainsUnfulfilled = $true
        }
        h = [ordered]@{
            status = 'not_defined_not_asserted'
            directObservation = $false
        }
    }

    $runRecordPath = Join-Path $run 'run-record.json'
    if (!(Test-Path -LiteralPath $runRecordPath -PathType Leaf)) { throw "MAME run record is missing: $runRecordPath" }
    $runRecord = Read-JsonFile $runRecordPath
    if ($null -eq $runRecord.exitCode) { throw 'MAME run record has no exit code' }
    if ($null -eq $runRecord.timedOut) { throw 'MAME run record has no timeout flag' }
    if ([bool]$runRecord.timedOut) { throw 'MAME run record reports a wall timeout; no complete claim is allowed' }
    if ([int]$runRecord.exitCode -ne 0) { throw "MAME run record exit code is $($runRecord.exitCode); no complete claim is allowed" }
    $exitCodePath = Join-Path $run 'exit-code.txt'
    if (!(Test-Path -LiteralPath $exitCodePath -PathType Leaf)) { throw "MAME exit-code.txt is missing: $exitCodePath" }
    $exitCodeText = (Get-Content -LiteralPath $exitCodePath -Raw).Trim()
    if ($exitCodeText -ne [string][int]$runRecord.exitCode) { throw "exit-code.txt is '$exitCodeText', expected $($runRecord.exitCode)" }

    $phaseComplete = ($phaseEvents.Count -eq $script:Phases.Count -and $completeClaim -and $reason -eq 'native_primitive_complete')
    if ($completeClaim -and $phaseEvents.Count -ne $script:Phases.Count) { throw 'Session claims completion without all ordered phases' }
    if ($phaseComplete) {
        if ([int]$completeEvent.observed -ne $script:Phases.Count) { throw 'Session complete observed count is wrong' }
        if ([int]$completeEvent.expected -ne $script:Phases.Count) { throw 'Session complete expected count is wrong' }
        if ([string]$completeEvent.inputWord -ine '0000') { throw 'Session complete input word is not 0000' }
        if ([string]$completeEvent.resultWord -ine 'FFFF') { throw 'Session complete result word is not FFFF' }
        if ([string]$completeEvent.postY -ine '9F3F') { throw 'Session complete post-return Y is not 9F3F' }
        if ([string]$completeEvent.postS -ine '079A') { throw 'Session complete post-return S is not 079A' }
        if ([string]$completeEvent.postToken -ine '792F') { throw 'Session complete post-return token is not 792F' }
        if ([string]$completeEvent.netU -ine '0002') { throw 'Session complete U delta is not 0002' }
        if ([string]$completeEvent.netS -ine '0002') { throw 'Session complete S delta is not 0002' }
        if ($null -eq $handlerWord -or $handlerWord -ne 0x8000) { throw 'Observed handler result is not 8000' }
        if ($null -eq $resultWord -or $resultWord -ne 0xFFFF) { throw 'Observed post-75A9 result is not FFFF' }
        $last = $phaseRecords[$phaseRecords.Count - 1]
        if ($last.phase -ne '9f12-post-return') { throw 'Final observed phase is not 9f12-post-return' }
        if ($last.u -ine '0670' -or $last.s -ine '079A' -or $last.y -ine '9F3F' -or $last.dataStack0 -ine 'FFFF' -or $last.token -ine '792F') { throw 'Final post-return phase does not restore the expected parent context' }
        $first = $phaseRecords[0]
        if ($first.u -ine '066E' -or $first.s -ine '0798' -or $first.y -ine '9F14' -or $first.dataStack0 -ine '0000' -or $first.token -ine '1010') { throw 'Caller phase is not the required 9F14/1010/0000 boundary' }
    }
    $status = 'blocked_incomplete'
    if ($phaseComplete) {
        if ($evidenceClass -eq 'natural') { $status = 'complete_natural_native_primitive' }
        else { $status = 'synthetic_fixture_complete_not_evidence' }
    }
    elseif ($reason -eq 'emulated_budget' -or $reason -eq 'wall_timeout') {
        $status = 'blocked_not_reached'
    }

    $currentLuaSha256 = Get-HashValue (Join-Path $script:Root 'tools/lua/IlNativePrimitiveNatural.lua') 'SHA256'
    $currentToolSha256 = Get-HashValue $PSCommandPath 'SHA256'
    $capturedLuaSha256 = [string]$metadata.lua.capturedSha256
    $capturedToolSha256 = [string]$metadata.capture_tool.sha256
    $verificationGap = [ordered]@{
        present = ($currentLuaSha256 -ine $capturedLuaSha256) -or ($currentToolSha256 -ine $capturedToolSha256)
        capturedLuaSha256 = $capturedLuaSha256
        currentLuaSha256 = $currentLuaSha256
        luaChangedAfterCapture = ($currentLuaSha256 -ine $capturedLuaSha256)
        capturedToolSha256 = $capturedToolSha256
        currentToolSha256 = $currentToolSha256
        toolChangedAfterCapture = ($currentToolSha256 -ine $capturedToolSha256)
        luaExecutedForAnalysis = $false
        rerunPerformed = $false
        note = 'The raw capture is not rerun. Any observer/checker change after capture is reported as a verification gap, not substituted for the captured bytes.'
    }

    $reanalysis = $null
    if (![string]::IsNullOrWhiteSpace($ReanalysisSourceRun)) {
        $sourceRun = [IO.Path]::GetFullPath($ReanalysisSourceRun)
        $sourceEvents = Join-Path $sourceRun 'events.jsonl'
        if (!(Test-Path -LiteralPath $sourceEvents -PathType Leaf)) { throw "Reanalysis source run has no events.jsonl: $sourceRun" }
        $reanalysis = [ordered]@{
            classification = 'read_only_private_copy_reanalysis'
            sourceRunDirectory = $sourceRun
            sourceEventsSha256 = Get-HashValue $sourceEvents 'SHA256'
            analysisRunDirectory = $run
            rawArtifactModified = $false
            luaExecuted = $false
            note = 'The original raw run was copied and reanalysed offline. No raw file was edited and no MAME or Lua process was started.'
        }
    }

    $debugLogPath = Join-Path $run 'debug.log'
    $consolePath = Join-Path $run 'console.txt'
    $readyPath = Join-Path $run 'ready.txt'
    $completePath = Join-Path $run 'session-complete.txt'
    $analysis = [ordered]@{
        status = $status
        evidenceClass = $evidenceClass
        classification = if ($evidenceClass -eq 'natural') { 'Natural fresh-boot MAME 0.281 observation of the exact compiled direct native primitive image using the existing tracked physical coin/start replay. Boundaries come only from native debugger breakpoints; the Lua periodic callback is the stopped-state driver. No save/load state, PC/register/RAM seed, debugger write or synthetic state injection.' } else { 'Synthetic checker fixture. This is not natural execution evidence and cannot satisfy the native-primitive acceptance.' }
        supervisorAcceptance = [ordered]@{
            status = 'not_claimed'
            note = 'This record documents a completed worker capture and offline audit; it does not assert supervisor acceptance or publication.'
        }
        protocol = $script:Protocol
        boundary = [ordered]@{
            id = 'natural-fresh-boot-native-primitive-1012-observation'
            attempt = 1
            tokenAddress = '1010'
            tokenValue = '1012'
            handlerStart = '1012'
            handlerEndExclusive = '101B'
            callerAddress = '9F14'
            callerToken = '1010'
            successorAddress = '9F16'
            successorToken = '75A9'
            controlTop = '9F3F'
        }
        sessionId = [string]$metadata.sessionId
        originalRom = $originalIdentity
        builtRom = $builtIdentity
        runRom = $runRomIdentity
        sourceMap = [ordered]@{ path=[IO.Path]::GetFullPath($sourceMapPath); sha256=$mapHash; contract=$contract }
        buildReport = [ordered]@{ path=[IO.Path]::GetFullPath($buildReportPath); sha256=$buildHash }
        lua = $metadata.lua
        mame = $metadata.mame
        mameInvocation = $mameInvocation
        frontend = $metadata.frontend
        run = [ordered]@{
            directory = $run
            mameRecord = $runRecord
            exitCode = if ($null -ne $runRecord) { $runRecord.exitCode } else { $null }
            timedOut = if ($null -ne $runRecord) { $runRecord.timedOut } else { $null }
            strictJsonPass = [bool]$parseInfo.strict
            eventRecordCount = $parseInfo.recordCount
            eventsSha256 = $parseInfo.sha256
            strictSummaryPath = $parseInfo.summaryPath
            strictSummarySha256 = $parseInfo.summarySha256
            debugLogSha256 = if (Test-Path -LiteralPath $debugLogPath) { Get-HashValue $debugLogPath 'SHA256' } else { '' }
            consoleSha256 = if (Test-Path -LiteralPath $consolePath) { Get-HashValue $consolePath 'SHA256' } else { '' }
            readySha256 = if (Test-Path -LiteralPath $readyPath) { Get-HashValue $readyPath 'SHA256' } else { '' }
            sessionCompleteSha256 = if (Test-Path -LiteralPath $completePath) { Get-HashValue $completePath 'SHA256' } else { '' }
            stateFiles = $stateFiles.Count
            inputPolicy = 'tracked_physical_replay'
            inputReplayUsed = $true
            saveStateLoaded = [bool]$metadata.save_state_loaded
            inputInjection = [bool]$metadata.input_injection
            stateInjection = [bool]$metadata.state_injection
            debuggerWrites = [bool]$metadata.debugger_writes
            startingNvram = [string]$metadata.starting_nvram
            startingConfiguration = [string]$metadata.starting_configuration
        }
        inputProvenance = $inputProvenance
        runLocalAssets = $runLocalAssets
        reanalysis = $reanalysis
        failure = if ($null -eq $failure) { $null } else { [ordered]@{
            event = [string]$failure.event
            code = [string]$failure.code
            message = [string]$failure.message
            observed = [string]$failure.observed
            expected = [string]$failure.expected
        } }
        verificationGap = $verificationGap
        session = [ordered]@{
            reason = $reason
            failureCode = if ($null -ne $failure) { [string]$failure.code } else { '' }
            completeClaim = $completeClaim
            timeoutRecords = $timeouts.Count
            terminalRecordCount = $timeouts.Count + $failures.Count
            eventSequenceValidated = $true
            readyIsFirst = ($readyIndex -eq 0)
            completeIsLast = ($completeIndex -eq $records.Count - 1)
            phaseCount = $phaseEvents.Count
            expectedPhaseCount = $script:Phases.Count
        }
        blocker = if ($phaseComplete) { $null } else { [ordered]@{
            status = if ($null -ne $failure) { 'protocol_failure' } else { 'not_reached' }
            reason = $reason
            observedPhaseCount = $phaseEvents.Count
            expectedPhaseCount = $script:Phases.Count
            emulatedSeconds = [string]$completeEvent.emulatedTime
            failureCode = if ($null -ne $failure) { [string]$failure.code } else { '' }
            note = 'One bounded tracked physical-input replay run. No retry, save state, PC/register/RAM seed or debugger state write was made.'
        } }
        phases = $phaseRecords.ToArray()
        call = [ordered]@{
            callerAddress = '9F14'
            callerToken = '1010'
            tokenAddress = '1010'
            tokenValue = '1012'
            handlerStart = '1012'
            handlerEndExclusive = '101B'
            handlerHex = $script:HandlerHex
            directEntryPc = '1012'
            directEntryX = '1012'
            rejoinPc = '00FC'
            rejoinY = '9F16'
            controlTop = '9F3F'
            inputWord = if ($null -ne $inputWord) { Format-Hex16 $inputWord } else { '' }
            handlerWord = if ($null -ne $handlerWord) { Format-Hex16 $handlerWord } else { '' }
            downstreamWord = if ($null -ne $resultWord) { Format-Hex16 $resultWord } else { '' }
            resultWord = if ($phaseComplete) { 'FFFF' } else { '' }
            postY = if ($phaseComplete) { '9F3F' } else { '' }
            postS = if ($phaseComplete) { '079A' } else { '' }
            postToken = if ($phaseComplete) { '792F' } else { '' }
            netU = if ($phaseComplete) { '0002' } else { '' }
            netS = if ($phaseComplete) { '0002' } else { '' }
            complete = $phaseComplete
            returnObserved = ($phaseRecords.Count -gt 0 -and $phaseRecords[$phaseRecords.Count - 1].phase -eq '9f12-post-return')
        }
        registerEvidence = $registerEvidence
        provenanceClasses = @(
            'measured_live_native_phase_values',
            'static_source_map_binding_only',
            'dp_zero_static_deduction_not_direct_measurement',
            'tracked_physical_input_replay_no_state_injection',
            'fresh_isolated_config_nvram_state_directories',
            'natural_fresh_boot_mame_0_281',
            'not_physical_hardware_compatibility'
        )
        limitations = @(
            'MAME success is not physical MPU4 hardware compatibility.',
            'DP was not directly sampled by the captured observer. DP=0 is a static deduction from the exact 0EFC direct JMP and the live PC=00FC; it is not a direct DP measurement. Direct DP observation remains unfulfilled for this capture.',
            'Only the single direct native primitive reached from the naturally observed 9F14 caller site is claimed.',
            'The broader purpose of the 9F12 caller and all downstream consumers remains unresolved.',
            'The intentional 0000 -> 8000 -> FFFF behaviour change is not original 9ED9 preservation or a full-game proof.',
            'H is not defined, output or asserted; CC values are recorded as diagnostics only.',
            'No paid-gate, full-game or hardware claim is made.'
        )
    }
    return $analysis
}

function Write-EvidenceSummary {
    param([string]$Path,$Analysis)
    $evidence = [ordered]@{
        taskId = 'il-native-primitive-natural-46'
        schemaVersion = 1
        resultStatus = $Analysis.status
        evidenceClass = $Analysis.evidenceClass
        classification = $Analysis.classification
        supervisorAcceptance = $Analysis.supervisorAcceptance
        boundary = $Analysis.boundary
        originalRom = $Analysis.originalRom
        builtRom = $Analysis.builtRom
        sourceMap = $Analysis.sourceMap
        buildReport = $Analysis.buildReport
        lua = $Analysis.lua
        mame = $Analysis.mame
        mameInvocation = $Analysis.mameInvocation
        frontend = $Analysis.frontend
        inputProvenance = $Analysis.inputProvenance
        runLocalAssets = $Analysis.runLocalAssets
        reanalysis = $Analysis.reanalysis
        failure = $Analysis.failure
        verificationGap = $Analysis.verificationGap
        run = $Analysis.run
        session = $Analysis.session
        blocker = $Analysis.blocker
        call = $Analysis.call
        registerEvidence = $Analysis.registerEvidence
        phases = $Analysis.phases
        provenanceClasses = $Analysis.provenanceClasses
        limitations = $Analysis.limitations
        generatedUtc = [DateTime]::UtcNow.ToString('o')
    }
    Write-JsonFile $Path $evidence 40
}

function Write-CaptureFailure {
    param([string]$Run,[string]$Reason,$MameRecord)
    $bestEffort = [ordered]@{
        taskId = 'il-native-primitive-natural-46'
        status = 'capture_failed'
        reason = $Reason
        runDirectory = [IO.Path]::GetFullPath($Run)
        mameRecord = $MameRecord
        wrapperExit = 1
        phases = @()
        eventsSha256 = ''
        inputLevelsSha256 = ''
        debugLogSha256 = ''
        stateDirectoryFileCount = $null
        note = 'The single permitted capture failed or its record could not be accepted. Raw files are preserved; no rerun was attempted.'
    }
    $eventsPath = Join-Path $Run 'events.jsonl'
    if (Test-Path -LiteralPath $eventsPath -PathType Leaf) {
        $bestEffort.eventsSha256 = Get-HashValue $eventsPath 'SHA256'
        $phaseNames = New-Object 'System.Collections.Generic.List[string]'
        foreach ($line in Get-Content -LiteralPath $eventsPath) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try {
                $record = $line | ConvertFrom-Json -ErrorAction Stop
                if ([string]$record.event -eq 'phase') { $phaseNames.Add([string]$record.phase) }
            }
            catch {}
        }
        $bestEffort.phases = $phaseNames.ToArray()
    }
    $levelsPath = Join-Path $Run 'input-levels.csv'
    if (Test-Path -LiteralPath $levelsPath -PathType Leaf) { $bestEffort.inputLevelsSha256 = Get-HashValue $levelsPath 'SHA256' }
    $debugPath = Join-Path $Run 'debug.log'
    if (Test-Path -LiteralPath $debugPath -PathType Leaf) { $bestEffort.debugLogSha256 = Get-HashValue $debugPath 'SHA256' }
    $statePath = Join-Path $Run 'state'
    if (Test-Path -LiteralPath $statePath -PathType Container) { $bestEffort.stateDirectoryFileCount = @(Get-ChildItem -LiteralPath $statePath -Recurse -File -ErrorAction SilentlyContinue).Count }
    Write-JsonFile (Join-Path $Run 'capture-failure.json') $bestEffort 20
}

function Invoke-Capture {
    param([string]$Run)
    $run = [IO.Path]::GetFullPath($Run)
    if (Test-Path -LiteralPath $run) { throw "Use a fresh create-only run directory: $run" }
    foreach ($path in @($MameExecutable,$RomDirectory,$BuiltRom,$SourceMapPath,$BuildReportPath,$OriginalRom,$ReplayPath,$InputLuaPath)) {
        if (!(Test-Path -LiteralPath $path)) { throw "Required input is missing: $path" }
    }
    $originalIdentity = Assert-FileIdentity $OriginalRom $script:OriginalSha1 $script:OriginalSha256 'original ROM'
    $builtIdentity = Assert-FileIdentity $BuiltRom $script:BuiltSha1 $script:BuiltSha256 'built ROM'
    $replaySourceIdentity = Assert-FileHashIdentity $ReplayPath $script:ReplaySha256 'tracked replay fixture'
    $inputLuaSourceIdentity = Assert-FileHashIdentity $InputLuaPath $script:InputLuaSha256 'tracked input Lua'
    $replaySchedule = Get-ReplaySchedule $ReplayPath
    $mameHash = Get-HashValue $MameExecutable 'SHA256'
    if ($mameHash -ine $script:MameSha256) { throw "MAME SHA256 is $mameHash, expected $script:MameSha256" }
    $mapHash = Get-HashValue $SourceMapPath 'SHA256'
    if ($mapHash -ine $script:MapSha256) { throw "Source map SHA256 is $mapHash, expected $script:MapSha256" }
    $buildHash = Get-HashValue $BuildReportPath 'SHA256'
    $built = [IO.File]::ReadAllBytes($BuiltRom)
    $original = [IO.File]::ReadAllBytes($OriginalRom)
    $map = Read-JsonFile $SourceMapPath
    $build = Read-JsonFile $BuildReportPath
    $contract = Test-NativeMapContract $map $build $built $original

    New-Item -ItemType Directory -Path $run -ErrorAction Stop | Out-Null
    foreach ($name in @('roms/m4addr','cfg','nvram','inp','snap','comments','state','diff')) {
        New-Item -ItemType Directory -Path (Join-Path $run $name) -ErrorAction Stop | Out-Null
    }
    $runRom = Join-Path $run 'roms/m4addr/a6ls.p1'
    Copy-Item -LiteralPath $BuiltRom -Destination $runRom -ErrorAction Stop
    $runRomIdentity = Assert-FileIdentity $runRom $script:BuiltSha1 $script:BuiltSha256 'isolated run ROM before launch'
    Copy-Item -LiteralPath $SourceMapPath -Destination (Join-Path $run 'native-primitive-source-map.json') -ErrorAction Stop
    Copy-Item -LiteralPath $BuildReportPath -Destination (Join-Path $run 'build-report.json') -ErrorAction Stop
    $runReplayPath = Join-Path $run 'replay-actions.csv'
    $runInputLuaPath = Join-Path $run 'input.lua'
    Copy-Item -LiteralPath $ReplayPath -Destination $runReplayPath -ErrorAction Stop
    Copy-Item -LiteralPath $InputLuaPath -Destination $runInputLuaPath -ErrorAction Stop
    $runReplayIdentity = Assert-FileHashIdentity $runReplayPath $script:ReplaySha256 'isolated replay fixture copy'
    $runInputLuaIdentity = Assert-FileHashIdentity $runInputLuaPath $script:InputLuaSha256 'isolated input Lua copy'
    Copy-Item -LiteralPath (Join-Path $script:Root 'tools/lua/IlNativePrimitiveNatural.lua') -Destination (Join-Path $run 'IlNativePrimitiveNatural.lua') -ErrorAction Stop
    [IO.File]::WriteAllText((Join-Path $run 'observer.lua'),"dofile('input.lua')`ndofile('IlNativePrimitiveNatural.lua')`n",$script:Utf8)
    $capturedLuaPath = Join-Path $run 'IlNativePrimitiveNatural.lua'
    $luaSourcePath = Join-Path $script:Root 'tools/lua/IlNativePrimitiveNatural.lua'
    $luaSourceHash = Get-HashValue $luaSourcePath 'SHA256'
    $luaCapturedHash = Get-HashValue $capturedLuaPath 'SHA256'
    if ($luaSourceHash -ine $luaCapturedHash) { throw 'Captured Lua hash differs from the tracked Lua source' }
    $toolHash = Get-HashValue $PSCommandPath 'SHA256'
    Write-NativeMapLua (Join-Path $run 'native-primitive-map.lua')

    $sessionId = [guid]::NewGuid().ToString('D')
    $config = [ordered]@{
        schemaVersion = 1
        protocol = $script:Protocol
        sessionId = $sessionId
        secondsToRun = $SecondsToRun
        wallTimeoutSeconds = $WallTimeoutSeconds
        inputPolicy = 'tracked_physical_replay'
        expectedReplaySha256 = $script:ReplaySha256
        expectedInputLuaSha256 = $script:InputLuaSha256
        expectedImageSha256 = $script:BuiltSha256
        expectedOriginalRomSha256 = $script:OriginalSha256
        expectedSourceMapSha256 = $mapHash
        expectedBuildReportSha256 = $buildHash
        expectedLuaSha256 = $luaCapturedHash
        expectedMameSha256 = $mameHash
    }
    Write-NativeConfigLua (Join-Path $run 'session-config.lua') $config
    Write-JsonFile (Join-Path $run 'session-config.json') $config 8
    $runLocalAssets = [ordered]@{
        lua = $luaCapturedHash
        map_lua = Get-HashValue (Join-Path $run 'native-primitive-map.lua') 'SHA256'
        config_lua = Get-HashValue (Join-Path $run 'session-config.lua') 'SHA256'
        config_json = Get-HashValue (Join-Path $run 'session-config.json') 'SHA256'
        observer = Get-HashValue (Join-Path $run 'observer.lua') 'SHA256'
    }
    if ($runLocalAssets.map_lua -ine (Get-StringSha256 (Get-NativeMapLuaText))) { throw 'Captured native-primitive-map.lua is not the canonical rendering of the phase contract' }
    if ($runLocalAssets.config_lua -ine (Get-StringSha256 (Get-NativeConfigLuaText $config))) { throw 'Captured session-config.lua is not the canonical rendering of the session config' }

    $preRunCounts = [ordered]@{}
    foreach ($name in @('cfg','nvram','inp','snap','comments','state','diff')) {
        $preRunCounts[$name] = @(Get-ChildItem -LiteralPath (Join-Path $run $name) -Recurse -File -ErrorAction SilentlyContinue).Count
        if ($preRunCounts[$name] -ne 0) { throw "Pre-run directory $name is not empty" }
    }
    $preRunRomFiles = @(Get-ChildItem -LiteralPath (Join-Path $run 'roms/m4addr') -File | ForEach-Object { $_.Name } | Sort-Object)
    if (($preRunRomFiles -join ',') -ne 'a6ls.p1') { throw 'Isolated ROM directory must contain exactly a6ls.p1 before launch' }
    Write-JsonFile (Join-Path $run 'pre-run-empty.json') $preRunCounts 6

    $bgfxPath = [IO.Path]::GetFullPath((Join-Path (Split-Path ([IO.Path]::GetFullPath($MameExecutable)) -Parent) 'bgfx'))
    if (!(Test-Path -LiteralPath $bgfxPath -PathType Container)) { throw "Installed BGFX asset directory is missing: $bgfxPath" }
    $mameVersion = '0.281 (hash-pinned; -version not launched to preserve the single fresh capture boundary)'

    $arguments = @('m4addr','-noreadconfig','-rompath',((Join-Path $run 'roms')+';'+$RomDirectory),
        '-cfg_directory',(Join-Path $run 'cfg'),'-nvram_directory',(Join-Path $run 'nvram'),
        '-input_directory',(Join-Path $run 'inp'),'-snapshot_directory',(Join-Path $run 'snap'),
        '-comment_directory',(Join-Path $run 'comments'),'-state_directory',(Join-Path $run 'state'),
        '-diff_directory',(Join-Path $run 'diff'),'-debug','-debugger','imgui','-debuglog',
        '-video','bgfx','-sound','none','-window','-skip_gameinfo','-nothrottle',
        '-seconds_to_run',[string]$SecondsToRun,'-autoboot_delay','0',
        '-autoboot_script',(Join-Path $run 'observer.lua'),
        '-bgfx_path',$bgfxPath)
    Write-JsonFile (Join-Path $run 'arguments.json') @($arguments) 6
    $metadata = [ordered]@{
        protocol = $script:Protocol
        sessionId = $sessionId
        original_rom = $originalIdentity
        built_rom = $builtIdentity
        run_rom_before = $runRomIdentity
        source_map = [ordered]@{ path=[IO.Path]::GetFullPath((Join-Path $run 'native-primitive-source-map.json')); sha256=$mapHash }
        build_report = [ordered]@{ path=[IO.Path]::GetFullPath((Join-Path $run 'build-report.json')); sha256=$buildHash }
        lua = [ordered]@{
            sourcePath = [IO.Path]::GetFullPath($luaSourcePath)
            sourceSha256 = $luaSourceHash
            capturedPath = [IO.Path]::GetFullPath($capturedLuaPath)
            capturedSha256 = $luaCapturedHash
        }
        capture_tool = [ordered]@{ path=[IO.Path]::GetFullPath($PSCommandPath); sha256=$toolHash }
        run_local_assets = $runLocalAssets
        input_replay = [ordered]@{
            path = $runReplayIdentity.path
            length = $runReplayIdentity.length
            sha256 = $runReplayIdentity.sha256
            input_lua_path = $runInputLuaIdentity.path
            input_lua_sha256 = $runInputLuaIdentity.sha256
            coin_event = $replaySchedule.coin
            start_event = $replaySchedule.start
            classification = 'tracked_physical_input_replay_no_state_injection'
        }
        mame = [ordered]@{ executable=[IO.Path]::GetFullPath($MameExecutable); sha256=$mameHash; version=$mameVersion }
        frontend = [ordered]@{ debugger = 'imgui'; video = 'bgfx'; bgfx_path = $bgfxPath; focus_stealing = $false }
        contract = $contract
        seconds_to_run = $SecondsToRun
        wall_timeout_seconds = $WallTimeoutSeconds
        starting_nvram = 'absent'
        starting_configuration = 'absent; -noreadconfig'
        save_state_loaded = $false
        state_injection = $false
        input_injection = $false
        input_replay_used = $true
        input_policy = 'tracked_physical_replay'
        evidence_class = 'natural'
        debugger_writes = $false
        classification = 'Fresh-isolated natural direct native primitive run using the existing tracked physical coin/start replay with read-only native debugger boundary stops. No save state, PC/register/RAM seed, debugger write or synthetic state injection.'
    }
    Write-JsonFile (Join-Path $run 'session-metadata.json') $metadata 30

    $previousMap = $env:FML_IL_NATIVE_PRIMITIVE_MAP
    $previousConfig = $env:FML_IL_NATIVE_PRIMITIVE_CONFIG
    $previousReplay = $env:MPU4_REPLAY
    $previousPolicy = $env:MPU4_POLICY
    try {
        $env:FML_IL_NATIVE_PRIMITIVE_MAP = 'native-primitive-map.lua'
        $env:FML_IL_NATIVE_PRIMITIVE_CONFIG = 'session-config.lua'
        $env:MPU4_REPLAY = $runReplayPath
        $env:MPU4_POLICY = '7'
        $runRecord = Invoke-ProcessRecord -FilePath $MameExecutable -Arguments $arguments -WorkingDirectory $run -StdOutPath (Join-Path $run 'console.txt') -StdErrPath (Join-Path $run 'console.err.txt') -TimeoutSeconds $WallTimeoutSeconds
    }
    finally {
        $env:FML_IL_NATIVE_PRIMITIVE_MAP = $previousMap
        $env:FML_IL_NATIVE_PRIMITIVE_CONFIG = $previousConfig
        $env:MPU4_REPLAY = $previousReplay
        $env:MPU4_POLICY = $previousPolicy
    }
    $runRecord.commandId = 'il-native-primitive-natural-46-capture-01'
    $runRecord.description = 'One fresh-boot direct native primitive MAME observation at native boundaries with the existing tracked physical coin/start replay'
    Write-JsonFile (Join-Path $run 'run-record.json') $runRecord 8
    [IO.File]::WriteAllText((Join-Path $run 'exit-code.txt'),[string]$runRecord.exitCode,$script:Utf8)

    if ($runRecord.timedOut) {
        Write-CaptureFailure $run "MAME exceeded the ${WallTimeoutSeconds}s wall cap" $runRecord
        throw "MAME exceeded the ${WallTimeoutSeconds}s wall cap; partial run preserved at $run"
    }
    if ($runRecord.exitCode -ne 0) {
        Write-CaptureFailure $run "MAME exited $($runRecord.exitCode)" $runRecord
        throw "MAME exited $($runRecord.exitCode); inspect $run"
    }
    if (!(Test-Path -LiteralPath (Join-Path $run 'events.jsonl') -PathType Leaf)) {
        Write-CaptureFailure $run 'Lua observer did not produce events.jsonl' $runRecord
        throw "Lua observer did not produce events.jsonl; inspect $run"
    }

    try {
        $analysis = Get-NativeAnalysis -Run $run -BuiltPath $runRom -SourceMapPath (Join-Path $run 'native-primitive-source-map.json') -BuildReportPath (Join-Path $run 'build-report.json') -OriginalPath $OriginalRom
        Write-JsonFile (Join-Path $run 'observation.json') $analysis 40
        Write-EvidenceSummary $EvidencePath $analysis
    }
    catch {
        Write-CaptureFailure $run $_.Exception.Message $runRecord
        throw
    }
    return [ordered]@{
        run = $run
        status = $analysis.status
        complete = $analysis.call.complete
        phases = $analysis.session.phaseCount
        expectedPhases = $analysis.session.expectedPhaseCount
        strictJsonPass = $analysis.run.strictJsonPass
        mameExitCode = $runRecord.exitCode
        mameTimedOut = $runRecord.timedOut
        inputPolicy = $analysis.inputProvenance.policy
        inputReplayUsed = $analysis.inputProvenance.used
        coinFrames = $analysis.inputProvenance.observed.coinFrames
        startFrames = $analysis.inputProvenance.observed.startFrames
        realFrameStartFrames = $analysis.inputProvenance.observed.realFrameStartFrames
        debugStopStartFrames = $analysis.inputProvenance.observed.debugStopStartFrames
        sampleContract = $analysis.inputProvenance.observed.sampleContract
        failureCode = $analysis.session.failureCode
        evidence = [IO.Path]::GetFullPath($EvidencePath)
        evidenceSha256 = Get-HashValue $EvidencePath 'SHA256'
        eventsSha256 = $analysis.run.eventsSha256
        handlerWord = $analysis.call.handlerWord
        downstreamWord = $analysis.call.downstreamWord
        resultWord = $analysis.call.resultWord
        dpStatus = $analysis.registerEvidence.dp.status
        netU = $analysis.call.netU
        netS = $analysis.call.netS
    }
}

function Invoke-Analyze {
    param([string]$Run)
    if ([string]::IsNullOrWhiteSpace($Run)) { throw 'RunDirectory is required for Analyze and Verify' }
    $analysis = Get-NativeAnalysis -Run $Run -BuiltPath '' -SourceMapPath '' -BuildReportPath '' -OriginalPath '' -ReanalysisSourceRun $ReanalysisSourceRun
    if ($Mode -ne 'Verify') {
        Write-JsonFile (Join-Path ([IO.Path]::GetFullPath($Run)) 'observation.json') $analysis 40
        Write-EvidenceSummary $EvidencePath $analysis
    }
    return [ordered]@{
        run = [IO.Path]::GetFullPath($Run)
        status = $analysis.status
        complete = $analysis.call.complete
        phases = $analysis.session.phaseCount
        expectedPhases = $analysis.session.expectedPhaseCount
        strictJsonPass = $analysis.run.strictJsonPass
        eventRecordCount = $analysis.run.eventRecordCount
        eventsSha256 = $analysis.run.eventsSha256
        mameExitCode = $analysis.run.exitCode
        mameTimedOut = $analysis.run.timedOut
        inputPolicy = $analysis.inputProvenance.policy
        inputReplayUsed = $analysis.inputProvenance.used
        coinFrames = $analysis.inputProvenance.observed.coinFrames
        startFrames = $analysis.inputProvenance.observed.startFrames
        realFrameStartFrames = $analysis.inputProvenance.observed.realFrameStartFrames
        debugStopStartFrames = $analysis.inputProvenance.observed.debugStopStartFrames
        sampleContract = $analysis.inputProvenance.observed.sampleContract
        failureCode = $analysis.session.failureCode
        handlerWord = $analysis.call.handlerWord
        downstreamWord = $analysis.call.downstreamWord
        resultWord = $analysis.call.resultWord
        dpStatus = $analysis.registerEvidence.dp.status
        netU = $analysis.call.netU
        netS = $analysis.call.netS
    }
}

if (-not $LibraryOnly) {
    try {
        if ($Mode -eq 'Capture') {
            if ([string]::IsNullOrWhiteSpace($RunDirectory)) { throw 'RunDirectory is required for Capture' }
            $result = Invoke-Capture $RunDirectory
        }
        else {
            $result = Invoke-Analyze $RunDirectory
        }
        Write-Output (ConvertTo-Json -InputObject $result -Depth 8)
        exit 0
    }
    catch {
        $message = $_.Exception.Message
        Write-Output (ConvertTo-Json -InputObject ([ordered]@{
            status = 'failed'
            error = $message
            mode = $Mode
            run = $RunDirectory
            mameLaunched = ($Mode -eq 'Capture')
        }) -Depth 5)
        [Console]::Error.WriteLine($message)
        exit 1
    }
}

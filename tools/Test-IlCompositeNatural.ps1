[CmdletBinding()]
param(
    [string]$OriginalRom = 'C:\projects\GitRepos\FruitMachineLab\artifacts\deepseek\general-14\roms\original.p1',
    [string]$RunDirectory = 'C:\projects\GitRepos\FruitMachineLab\artifacts\deepseek\il-composite-replay-36\run-01',
    [string]$NoInputRunDirectory = 'C:\projects\GitRepos\FruitMachineLab\artifacts\deepseek\il-composite-natural-35\run-01',
    [string]$EvidencePath = 'C:\projects\GitRepos\FruitMachineLab\evidence\mpu4\integrity\il-composite-natural.json'
)
$ErrorActionPreference = 'Stop'

$script:Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:Tool = Join-Path $script:Root 'tools/Capture-IlCompositeNatural.ps1'
$script:Lua = Join-Path $script:Root 'tools/lua/IlCompositeNatural.lua'
$script:InputLua = Join-Path $script:Root 'evidence/mpu4/skill-cash/input.lua'
$script:Replay = Join-Path $script:Root 'evidence/mpu4/skill-cash/actions.csv'
$script:Doc = Join-Path $script:Root 'docs/recovery/IL-COMPOSITE-NATURAL.md'
$script:ManifestTool = Join-Path $script:Root 'tools/Update-CuratedManifest.ps1'
$script:JsonHelper = Join-Path $script:Root 'tests/worker/Test-IlEventJson.ps1'
$script:AuthorizedRunSource = Join-Path $script:Root 'artifacts/deepseek/il-composite-input-time-41/reanalysis/attempt-40-run-01'
$script:AuthorizedRawRun = Join-Path $script:Root 'artifacts/deepseek/il-composite-authorized-capture-40/run-01'
$script:ReplaySha256 = '4a051da15264842697879eff396b34a789f5d80623f9a2e749c244e6a80e721d'
$script:InputLuaSha256 = '23099f8888af8db353253e0df97638320dc59ca9a47371723a380e0c4ee85c94'
$script:Checks = 0
$script:Failures = 0

function Write-Pass([string]$Message) { $script:Checks++; Write-Output "PASS: $Message" }
function Write-Fail([string]$Message) { $script:Checks++; $script:Failures++; Write-Output "FAIL: $Message" }
function Assert-True([bool]$Condition,[string]$Message) { if ($Condition) { Write-Pass $Message } else { Write-Fail $Message } }
function Assert-Equal($Actual,$Expected,[string]$Message) {
    if ([string]$Actual -eq [string]$Expected) { Write-Pass $Message }
    else { Write-Fail "$Message (actual '$Actual', expected '$Expected')" }
}
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
        finally { $sha.Dispose() }
    }
    finally { $stream.Dispose() }
}
function Invoke-Tool([string[]]$Arguments) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:Tool @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previous }
    return [ordered]@{ exitCode=$exitCode; text=($output | Out-String) }
}
function Write-JsonFile([string]$Path,$Object,[int]$Depth = 30) {
    $parent = Split-Path -Parent $Path
    if (![string]::IsNullOrWhiteSpace($parent) -and !(Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($Path,(ConvertTo-Json -InputObject $Object -Depth $Depth),(New-Object System.Text.UTF8Encoding($false)))
}
function Read-JsonFile([string]$Path) { return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
function Format-Hex16([int]$Value) { return ('{0:X4}' -f ($Value -band 0xFFFF)) }
function Format-Hex8([int]$Value) { return ('{0:X2}' -f ($Value -band 0xFF)) }
function Read-EventRecords([string]$Path) {
    $list = New-Object 'System.Collections.Generic.List[object]'
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $list.Add(($line | ConvertFrom-Json -ErrorAction Stop))
    }
    return $list
}
function Write-EventRecords([string]$Path,$Records) {
    $lines = New-Object 'System.Collections.Generic.List[string]'
    foreach ($record in $Records) { $lines.Add((ConvertTo-Json -InputObject $record -Depth 20 -Compress)) }
    [IO.File]::WriteAllText($Path,(($lines -join "`n") + "`n"),(New-Object System.Text.UTF8Encoding($false)))
}
function New-RunCopy([string]$Source,[string]$Destination) {
    if (Test-Path -LiteralPath $Destination) { throw "Negative-control directory already exists: $Destination" }
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -ErrorAction Stop
    return $Destination
}
function Set-MetadataField([string]$Run,[string]$Name,$Value) {
    $metadataPath = Join-Path $Run 'session-metadata.json'
    $metadata = Read-JsonFile $metadataPath
    $metadata | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
    Write-JsonFile $metadataPath $metadata 40
}
function Edit-InputLevels([string]$Run,[int]$FirstFrame,[int]$LastFrame,[string]$Column) {
    $path = Join-Path $Run 'input-levels.csv'
    $lines = New-Object 'System.Collections.Generic.List[string]'
    foreach ($line in Get-Content -LiteralPath $path) {
        if ($line -match '^(\d+),([0-9.]+),([0-9A-Fa-f]{2}),([0-9A-Fa-f]{2}),(\d+)$') {
            $frame = [int]$Matches[1]
            $aux2 = $Matches[3]
            $black2 = $Matches[4]
            $coin = $Matches[5]
            if ($frame -ge $FirstFrame -and $frame -le $LastFrame) {
                if ($Column -eq 'aux2') { $aux2 = '00'; $coin = '0' }
                if ($Column -eq 'black2') { $black2 = '00' }
            }
            $lines.Add(('{0},{1},{2},{3},{4}' -f $frame,$Matches[2],$aux2,$black2,$coin))
        }
        else { $lines.Add($line) }
    }
    [IO.File]::WriteAllText($path,(($lines -join "`n") + "`n"),(New-Object System.Text.UTF8Encoding($false)))
}
function Set-InputLevel([string]$Run,[int]$Frame,[string]$Column,[string]$Value) {
    $path = Join-Path $Run 'input-levels.csv'
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $changed = $false
    foreach ($line in Get-Content -LiteralPath $path) {
        if ($line -match '^(\d+),([0-9.]+),([0-9A-Fa-f]{2}),([0-9A-Fa-f]{2}),(\d+)$') {
            $frame = [int]$Matches[1]
            $aux2 = $Matches[3]
            $black2 = $Matches[4]
            $coin = $Matches[5]
            if ($frame -eq $Frame) {
                $changed = $true
                if ($Column -eq 'aux2') { $aux2 = $Value; if ($Value -ne '00') { $coin = '1' } }
                if ($Column -eq 'black2') { $black2 = $Value }
            }
            $lines.Add(('{0},{1},{2},{3},{4}' -f $frame,$Matches[2],$aux2,$black2,$coin))
        }
        else { $lines.Add($line) }
    }
    if (-not $changed) { throw "input-levels.csv has no frame $Frame to edit" }
    [IO.File]::WriteAllText($path,(($lines -join "`n") + "`n"),(New-Object System.Text.UTF8Encoding($false)))
}
function Append-InputLevel([string]$Run,[int]$Frame,[string]$Time,[string]$Aux2,[string]$Black2,[string]$Coin) {
    $path = Join-Path $Run 'input-levels.csv'
    $line = ('{0},{1},{2},{3},{4}' -f $Frame,$Time,$Aux2,$Black2,$Coin)
    [IO.File]::AppendAllText($path,($line + "`n"),(New-Object System.Text.UTF8Encoding($false)))
}
function Set-JsonField([string]$Path,[string]$Name,$Value) {
    $json = Read-JsonFile $Path
    $json | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
    Write-JsonFile $Path $json 40
}

function New-SyntheticFixture {
    param([string]$SourceRun,[string]$Destination)
    if (Test-Path -LiteralPath $Destination) { throw "Fixture directory already exists: $Destination" }
    Copy-Item -LiteralPath $SourceRun -Destination $Destination -Recurse -ErrorAction Stop
    $metadataPath = Join-Path $Destination 'session-metadata.json'
    $metadata = Read-JsonFile $metadataPath
    $metadata | Add-Member -NotePropertyName evidence_class -NotePropertyValue 'synthetic_checker_fixture' -Force
    Write-JsonFile $metadataPath $metadata 40
    $mapPath = Join-Path $Destination 'composite-source-map.json'
    $map = Read-JsonFile $mapPath
    $records = New-Object 'System.Collections.Generic.List[object]'
    $luaSha = [string]$metadata.lua.capturedSha256
    $mameSha = [string]$metadata.mame.sha256
    $buildSha = [string]$metadata.built_rom.sha256
    $mapSha = [string]$metadata.source_map.sha256
    $sessionId = [string]$metadata.sessionId
    $records.Add([ordered]@{
        event='session_ready'
        sessionId=$sessionId
        imageSha256=$buildSha
        originalRomSha256=[string]$metadata.original_rom.sha256
        sourceMapSha256=$mapSha
        buildReportSha256=[string]$metadata.build_report.sha256
        luaSha256=$luaSha
        mameSha256=$mameSha
        resetPc='7CCF'
        secondsToRun='180'
        wallTimeoutSeconds='600'
        headerAddress='1010'
        headerValue='00F8'
        bodyStart='1012'
        bodyEndExclusive='1020'
        callerAddress='9F14'
        callerToken='1010'
        inputPolicy=[string]$metadata.input_policy
        replaySha256=[string]$metadata.input_replay.sha256
        inputLuaSha256=[string]$metadata.input_replay.input_lua_sha256
        boundarySource='native_debugger_bpset'
    })
    $u0 = 0x066E
    $s0 = 0x0798
    $input = 0x0000
    $sum = (($input + 0xFF80) -band 0xFFFF)
    $result = ($sum -bxor 0xFF80)
    $control0 = '9F3F'
    $control1 = 'AB44'
    $phases = @($map.Phases)
    $syntheticStopTimes = New-Object 'System.Collections.Generic.List[double]'
    for ($i = 0; $i -lt $phases.Count; $i++) {
        $syntheticStopTimes.Add(37.076457558 + ($i * 0.00001))
    }
    for ($i = 0; $i -lt $phases.Count; $i++) {
        $phase = $phases[$i]
        $name = [string]$phase.Phase
        $u = $u0
        $s = $s0
        $top = $input
        $second = 0
        $isHandler = ($null -ne $phase.HandlerAddress -and [int]$phase.Pc -eq [int]$phase.HandlerAddress)
        switch ($name) {
            'caller-dispatch' { $u=$u0; $s=$s0; $top=$input }
            'header-trampoline-entry' { $u=$u0; $s=$s0; $top=$input }
            'body-prefetch-0' { $u=$u0; $s=$s0-2; $top=$input }
            'handler-0' { $u=$u0; $s=$s0-2; $top=$input }
            'body-prefetch-1' { $u=$u0-2; $s=$s0-2; $top=0xFF80 }
            'handler-1' { $u=$u0-2; $s=$s0-2; $top=0xFF80 }
            'body-prefetch-2' { $u=$u0; $s=$s0-2; $top=$sum }
            'handler-2' { $u=$u0; $s=$s0-2; $top=$sum }
            'body-prefetch-3' { $u=$u0-2; $s=$s0-2; $top=0xFF80; $second=$sum }
            'handler-3' { $u=$u0-2; $s=$s0-2; $top=0xFF80; $second=$sum }
            'body-prefetch-4' { $u=$u0; $s=$s0-2; $top=$result }
            'return-handler' { $u=$u0; $s=$s0-2; $top=$result }
            'post-return-prefetch' { $u=$u0; $s=$s0; $top=$result }
            default { throw "Unsupported phase $name" }
        }
        $expectedToken = if ($null -ne $phase.ReplacementToken) { [int]$phase.ReplacementToken } else { [int]$phase.Token }
        $tokenAddress = if ($name -eq 'header-trampoline-entry') { 0x1010 } elseif ($isHandler) { (([int]$phase.Y) - 2) -band 0xFFFF } else { [int]$phase.Y }
        $handlerAddress = if ($null -ne $phase.HandlerAddress) { Format-Hex16 ([int]$phase.HandlerAddress) } else { '' }
        $inlineAddress = if ($null -ne $phase.InlineOperandAddress) { Format-Hex16 ([int]$phase.InlineOperandAddress) } else { '' }
        $inlineValue = if ($null -ne $phase.InlineOperandValue) { Format-Hex16 ([int]$phase.InlineOperandValue) } else { '' }
        $savedCursor = if ($name -eq 'body-prefetch-0' -or $name -eq 'return-handler') { '9F16' } else { '' }
        $control0 = if ($name -eq 'caller-dispatch' -or $name -eq 'header-trampoline-entry' -or $name -eq 'post-return-prefetch') { '9F3F' } else { '9F16' }
        $x = if ($null -ne $phase.X) { Format-Hex16 ([int]$phase.X) } else { '0000' }
        $records.Add([ordered]@{
            event='phase'
            phase=$name
            phaseIndex=[string]$i
            pc=(Format-Hex16 ([int]$phase.Pc))
            curpc=(Format-Hex16 ([int]$phase.Pc))
            a='00'
            b='00'
            d=(Format-Hex16 $top)
            cc='00'
            x=$x
            y=(Format-Hex16 ([int]$phase.Y))
            u=(Format-Hex16 $u)
            s=(Format-Hex16 $s)
            emulatedTime=('{0:F9}' -f $syntheticStopTimes[$i])
            token=(Format-Hex16 $expectedToken)
            tokenAddress=(Format-Hex16 $tokenAddress)
            handlerAddress=$handlerAddress
            inlineOperandAddress=$inlineAddress
            inlineOperandValue=$inlineValue
            savedCursor=$savedCursor
            dataStack0=(Format-Hex16 $top)
            dataStack1=(Format-Hex16 $second)
            dataStack2='0000'
            dataStack3='0000'
            controlStack0=$control0
            controlStack1=$control1
            controlStack2='0000'
            controlStack3='0000'
            buildSha256=$buildSha
            mapSha256=$mapSha
            mameSha256=$mameSha
            luaSha256=$luaSha
            sessionId=$sessionId
        })
    }
    $records.Add([ordered]@{
        event='session_complete'
        reason='composite_call_complete'
        complete='true'
        observed='13'
        expected='13'
        inputWord=(Format-Hex16 $input)
        resultWord=(Format-Hex16 $result)
        netU='0000'
        netS='0000'
        postY='9F16'
        postToken='75A9'
        callerU=(Format-Hex16 $u0)
        callerS=(Format-Hex16 $s0)
        lastPhase='post-return-prefetch'
        emulatedTime=('{0:F9}' -f $syntheticStopTimes[$syntheticStopTimes.Count - 1])
        wallSeconds='1'
        inputPolicy=[string]$metadata.input_policy
        replaySha256=[string]$metadata.input_replay.sha256
        inputLuaSha256=[string]$metadata.input_replay.input_lua_sha256
        buildSha256=$buildSha
        mapSha256=$mapSha
        mameSha256=$mameSha
        luaSha256=$luaSha
        sessionId=$sessionId
    })
    $eventsPath = Join-Path $Destination 'events.jsonl'
    Write-EventRecords $eventsPath $records
    $invariant = [Globalization.CultureInfo]::InvariantCulture
    $levelLines = New-Object 'System.Collections.Generic.List[string]'
    $levelLines.Add('frame,t,aux2,black2,coin_override')
    for ($frame = 1; $frame -le 2238; $frame++) {
        $time = ($frame - 1) / 60.0
        $aux2 = '00'
        $black2 = '00'
        $coin = '0'
        if ($frame -eq 2100) { $coin = '1' }
        if ($frame -eq 2101 -or $frame -eq 2102) { $aux2 = '80'; $coin = '1' }
        if ($frame -eq 2103) { $aux2 = '80' }
        if ($frame -ge 2221 -and $frame -le 2225) { $black2 = '80' }
        if ($frame -ge 2226 -and $frame -le 2238) {
            $black2 = '80'
            $time = $syntheticStopTimes[$frame - 2226]
        }
        $levelLines.Add([string]::Format($invariant, '{0},{1:F9},{2},{3},{4}', $frame, $time, $aux2, $black2, $coin))
    }
    [IO.File]::WriteAllText((Join-Path $Destination 'input-levels.csv'), (($levelLines -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
    $debugLines = New-Object 'System.Collections.Generic.List[string]'
    $debugLines.Add('MAME debugger synthetic fixture')
    for ($stop = 1; $stop -le 14; $stop++) { $debugLines.Add("Stopped at breakpoint $stop") }
    [IO.File]::WriteAllText((Join-Path $Destination 'debug.log'), (($debugLines -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
    return $Destination
}

$tempRoot = Join-Path $script:Root ('artifacts/deepseek/il-composite-evidence-repair-38/test-runs/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$rawRunSource = $RunDirectory
$rawNoInputSource = $NoInputRunDirectory
$authorizedRunSource = $script:AuthorizedRunSource
$authorizedRawRun = $script:AuthorizedRawRun
$RunDirectory = Join-Path $tempRoot 'attempt-36-raw-copy'
$NoInputRunDirectory = Join-Path $tempRoot 'attempt-35-raw-copy'
$AuthorizedRunDirectory = Join-Path $tempRoot 'attempt-40-private-copy'
Copy-Item -LiteralPath $rawRunSource -Destination $RunDirectory -Recurse -ErrorAction Stop
Copy-Item -LiteralPath $rawNoInputSource -Destination $NoInputRunDirectory -Recurse -ErrorAction Stop
Copy-Item -LiteralPath $authorizedRunSource -Destination $AuthorizedRunDirectory -Recurse -ErrorAction Stop
try {
    Assert-True (Test-Path -LiteralPath $script:Tool -PathType Leaf) 'capture/analyze/verify tool exists'
    Assert-True (Test-Path -LiteralPath $script:Lua -PathType Leaf) 'Lua observer exists'
    Assert-True (Test-Path -LiteralPath $script:InputLua -PathType Leaf) 'existing tracked input Lua exists'
    Assert-True (Test-Path -LiteralPath $script:Replay -PathType Leaf) 'existing tracked replay fixture exists'
    Assert-True (Test-Path -LiteralPath $script:Doc -PathType Leaf) 'composite natural document exists'
    Assert-True (Test-Path -LiteralPath $EvidencePath -PathType Leaf) 'curated composite natural evidence exists'
    Assert-True (Test-Path -LiteralPath $OriginalRom -PathType Leaf) 'strict original ROM exists'
    Assert-True (Test-Path -LiteralPath $RunDirectory -PathType Container) 'revised tracked-replay capture run exists'
    Assert-True (Test-Path -LiteralPath $NoInputRunDirectory -PathType Container) 'preserved no-input attempt exists'
    Assert-True (Test-Path -LiteralPath $AuthorizedRunDirectory -PathType Container) 'authorized attempt-40 private copy exists'
    Assert-True (Test-Path -LiteralPath (Join-Path $authorizedRawRun 'events.jsonl') -PathType Leaf) 'authorized attempt-40 raw event log exists'
    Assert-Equal (Get-Sha256 (Join-Path $authorizedRawRun 'events.jsonl')) 'ea4fae8345ccbb25d6921628c0b8eb869b8c4fa60ecf0b44b25a2d2cf185c353' 'authorized attempt-40 raw events retain their hash'
    Assert-Equal (Get-Sha256 (Join-Path $authorizedRawRun 'input-levels.csv')) 'd118902e7affb8b86d3c0b7fbcc92093205d228c91ffff08bb0beb6855ccf053' 'authorized attempt-40 input levels retain their hash'
    Assert-Equal (Get-Sha256 $script:Replay) $script:ReplaySha256 'tracked replay fixture has the prior provenance hash'
    Assert-Equal (Get-Sha256 $script:InputLua) $script:InputLuaSha256 'tracked input Lua has the prior provenance hash'

    $luaText = Get-Content -LiteralPath $script:Lua -Raw
    $inputLuaText = Get-Content -LiteralPath $script:InputLua -Raw
    $toolText = Get-Content -LiteralPath $script:Tool -Raw
    Assert-True ($luaText -match 'cpu\.debug:bpset') 'observer uses native debugger breakpoints'
    Assert-True ($luaText -match 'emu\.register_periodic') 'periodic callback is only the stopped-state driver'
    Assert-True ($luaText -match 'boundarySource = "native_debugger_bpset"') 'observer labels boundaries as native debugger breaks'
    Assert-True ($luaText -notmatch 'mem:write|:write_u8|:write_u16|state\[[^\]]+\]\.value\s*=') 'observer has no memory or register writes'
    Assert-True ($luaText -notmatch 'field:set_value|MPU4_REPLAY') 'composite observer does not inject inputs'
    Assert-True ($luaText -notmatch '(?i)playback|:save\b|:load\b') 'observer has no save/load state path'
    Assert-True ($luaText -match 'tracked_physical_replay') 'observer requires the tracked physical input policy'
    Assert-True ($luaText -match 'aux2|black2') 'observer records physical input port levels at bounded phases'
    Assert-True ($inputLuaText -match 'MPU4_REPLAY') 'existing input Lua consumes the tracked replay fixture'
    Assert-True ($inputLuaText -match 'field:set_value') 'existing input Lua applies physical port overrides'
    Assert-True ($inputLuaText -match 'input-levels\.csv') 'existing input Lua logs observed input levels'
    foreach ($token in @('0x1010','0x1012','0x00F8','0x9F14','0x9F16','0x75A9')) {
        Assert-True ($luaText -match [regex]::Escape($token)) "observer binds boundary $token"
    }
    Assert-True ($luaText -match 'handlerAddress') 'observer binds mapped native handler addresses'
    $sourceMap = Read-JsonFile (Join-Path $RunDirectory 'composite-source-map.json')
    $handlers = @(@($sourceMap.Nodes) | ForEach-Object { Format-Hex16 ([int]$_.HandlerAddress) })
    foreach ($handler in @('795D','7880','7AB1','7931')) {
        Assert-True ($handlers -contains $handler) "source map binds native handler $handler"
    }
    Assert-True ($luaText -match 'dataStack0|controlStack0') 'observer records bounded stack windows'
    Assert-True ($luaText -match 'savedCursor') 'observer records the saved caller cursor'

    Assert-True ($toolText -match "ValidateSet\('Capture','Analyze','Verify'\)") 'tool exposes Capture, Analyze and Verify modes'
    Assert-True ($toolText -match '-noreadconfig') 'tool launches MAME without reading configuration'
    Assert-True ($toolText -match "'-debugger','imgui'") 'tool pins the accepted imgui debugger'
    Assert-True ($toolText -match "'-video','bgfx'") 'tool pins the BGFX renderer'
    Assert-True ($toolText.Contains("'-bgfx_path',")) 'tool passes the installed BGFX asset path'
    Assert-True ($toolText.Contains('$bgfxPath')) 'tool uses the derived BGFX path variable'
    Assert-True ($toolText -notmatch "'-debugger','windows'") 'tool does not use the stalled Windows debugger'
    Assert-True ($toolText -match 'MPU4_REPLAY') 'tool wires the existing tracked replay through the proven autoboot pattern'
    Assert-True ($toolText -match "dofile\('input\.lua'\)") 'tool loads the existing input script before the observer'
    Assert-True ($toolText -match 'tracked_physical_replay') 'tool records the tracked physical input policy'
    Assert-True ($toolText -match 'Get-InputProvenance') 'tool validates observed input provenance'
    Assert-True ($toolText -match 'Test-IlEventJson\.ps1') 'tool uses the strict JSON helper'
    Assert-True ($toolText -match 'Get-CompositeAnalysis') 'tool has a reusable checker path'
    Assert-True ($toolText -match 'wrong image|Source map output SHA256|Source map BuildId') 'tool validates exact image/map binding'

    $noInput = Invoke-Tool @('-Mode','Verify','-RunDirectory',$NoInputRunDirectory)
    Assert-Equal $noInput.exitCode 0 'preserved no-input attempt still verifies without launching MAME'
    $ni = $noInput.text | ConvertFrom-Json
    Assert-Equal $ni.status 'blocked_not_reached' 'preserved no-input attempt keeps its original blocked status'
    Assert-Equal $ni.complete $false 'preserved no-input attempt is not a complete composite call'
    Assert-Equal $ni.phases 0 'preserved no-input attempt observed no composite phase'
    Assert-Equal $ni.expectedPhases 13 'checker retains all thirteen ordered phases'
    Assert-Equal $ni.strictJsonPass $true 'preserved events pass strict System.Text.Json parsing'
    Assert-Equal $ni.eventRecordCount 3 'preserved no-input event log has ready, timeout and complete records'
    Assert-Equal $ni.inputPolicy 'none' 'preserved no-input attempt records its no-input policy'
    Assert-Equal $ni.inputReplayUsed $false 'preserved no-input attempt records no replay'

    $verify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$RunDirectory)
    Assert-Equal $verify.exitCode 0 'revised tracked-replay run verifies without launching MAME'
    $v = $verify.text | ConvertFrom-Json
    Assert-Equal $v.status 'blocked_incomplete' 'revised run records an incomplete natural observation'
    Assert-Equal $v.complete $false 'revised run did not complete all phases'
    Assert-Equal $v.phases 2 'revised run observed caller and trampoline phases only'
    Assert-Equal $v.expectedPhases 13 'revised run retains the expected phase count'
    Assert-Equal $v.eventRecordCount 5 'revised event log has ready, two phases, failure and complete records'
    Assert-Equal $v.strictJsonPass $true 'revised events pass strict System.Text.Json parsing'
    Assert-Equal $v.inputPolicy 'tracked_physical_replay' 'revised run records tracked physical input replay'
    Assert-Equal $v.inputReplayUsed $true 'revised run records replay use'
    Assert-Equal (($v.coinFrames -join ',') -replace ' ','') '2100,2101,2102,2103' 'revised run observed the prior coin pulse frames'
    Assert-Equal (($v.startFrames -join ',') -replace ' ','') '2221,2222,2223,2224,2225,2226,2227,2228' 'revised run reports the full observed start-active window'
    Assert-Equal $v.failureCode 'phase_saved_cursor' 'revised run records the observer protocol failure'
    Assert-Equal $v.resultWord '' 'revised run does not claim an unobserved result word'
    Assert-Equal $v.netU '' 'revised run does not claim an unobserved U delta'
    Assert-Equal $v.netS '' 'revised run does not claim an unobserved S delta'
    Assert-Equal (($v.realFrameStartFrames -join ',') -replace ' ','') '2221,2222,2223,2224,2225' 'revised run separates the five real 60 Hz start samples'
    Assert-Equal (($v.debugStopStartFrames -join ',') -replace ' ','') '2226,2227,2228' 'revised run identifies debugger-stop callbacks after the real samples'

    $authorized = Invoke-Tool @('-Mode','Verify','-RunDirectory',$AuthorizedRunDirectory,'-ReanalysisSourceRun',$authorizedRawRun)
    Assert-Equal $authorized.exitCode 0 'authorized attempt-40 private copy verifies complete'
    $a = $authorized.text | ConvertFrom-Json
    Assert-Equal $a.status 'complete_natural_composite_call' 'authorized attempt-40 is accepted as a complete natural composite call'
    Assert-Equal $a.complete $true 'authorized attempt-40 claims a complete call'
    Assert-Equal $a.phases 13 'authorized attempt-40 observed all thirteen phases'
    Assert-Equal $a.expectedPhases 13 'authorized attempt-40 retains the thirteen-phase contract'
    Assert-Equal $a.eventRecordCount 15 'authorized attempt-40 has ready, thirteen phases and complete records'
    Assert-Equal $a.strictJsonPass $true 'authorized attempt-40 events pass strict System.Text.Json parsing'
    Assert-Equal $a.inputPolicy 'tracked_physical_replay' 'authorized attempt-40 records tracked physical replay'
    Assert-Equal $a.inputReplayUsed $true 'authorized attempt-40 records replay use'
    Assert-Equal (($a.coinFrames -join ',') -replace ' ','') '2100,2101,2102,2103' 'authorized attempt-40 observed the complete coin pulse'
    Assert-Equal (($a.startFrames -join ',') -replace ' ','') '2221,2222,2223,2224,2225,2226,2227,2228,2229,2230,2231,2232,2233,2234,2235,2236,2237,2238' 'authorized attempt-40 records every start-active row'
    Assert-Equal (($a.realFrameStartFrames -join ',') -replace ' ','') '2221,2222,2223,2224,2225' 'authorized attempt-40 derives five real 60 Hz start samples'
    Assert-Equal (($a.debugStopStartFrames -join ',') -replace ' ','') '2226,2227,2228,2229,2230,2231,2232,2233,2234,2235,2236,2237,2238' 'authorized attempt-40 classifies thirteen debugger-stop callbacks'
    Assert-Equal $a.failureCode '' 'authorized attempt-40 has no protocol failure'
    Assert-Equal $a.resultWord '0000' 'authorized attempt-40 result word is 0000'
    Assert-Equal $a.netU '0000' 'authorized attempt-40 net U is zero'
    Assert-Equal $a.netS '0000' 'authorized attempt-40 net S is zero'
    Assert-Equal $a.sampleContract.framePeriodSeconds '0.016666667' 'authorized attempt-40 derives the known 60 Hz frame period'
    Assert-Equal $a.sampleContract.gridToleranceSeconds '0.002083333' 'authorized attempt-40 derives an eighth-frame grid tolerance'
    Assert-Equal $a.sampleContract.startRealFrameRowCount 5 'authorized attempt-40 sample contract records five real start rows'
    Assert-Equal $a.sampleContract.startDebugStopCallbackCount 13 'authorized attempt-40 sample contract records thirteen debugger callbacks'

    $attempt40Observation = Read-JsonFile (Join-Path $AuthorizedRunDirectory 'observation.json')
    Assert-Equal $attempt40Observation.call.complete $true 'authorized attempt-40 call is complete'
    Assert-Equal $attempt40Observation.call.savedCursor '9F16' 'authorized attempt-40 derives the saved cursor live'
    Assert-Equal $attempt40Observation.call.savedCursorAuthority 'return-handler live controlStack0' 'authorized attempt-40 saved cursor authority is the live return handler'
    Assert-Equal $attempt40Observation.call.postReturnY '9F16' 'authorized attempt-40 post-return Y is 9F16'
    Assert-Equal $attempt40Observation.call.postReturnToken '75A9' 'authorized attempt-40 post-return token is 75A9'
    Assert-Equal $attempt40Observation.call.inputWord '0000' 'authorized attempt-40 input word is 0000'
    Assert-Equal $attempt40Observation.call.resultWord '0000' 'authorized attempt-40 result word is 0000'
    Assert-Equal $attempt40Observation.call.netU '0000' 'authorized attempt-40 net U is zero'
    Assert-Equal $attempt40Observation.call.netS '0000' 'authorized attempt-40 net S is zero'
    Assert-Equal $attempt40Observation.phases.Count 13 'authorized attempt-40 observation contains thirteen phases'
    Assert-Equal $attempt40Observation.phases[0].phase 'caller-dispatch' 'authorized attempt-40 first phase is caller-dispatch'
    Assert-Equal $attempt40Observation.phases[12].phase 'post-return-prefetch' 'authorized attempt-40 last phase is post-return-prefetch'
    Assert-Equal $attempt40Observation.phases[2].controlStack0 '9F16' 'authorized attempt-40 body saved cursor is live 9F16'
    Assert-Equal $attempt40Observation.phases[11].controlStack0 '9F16' 'authorized attempt-40 return saved cursor is live 9F16'
    $attempt40Handlers = (@($attempt40Observation.phases | Where-Object { $_.handlerAddress -ne '' -and $_.pc -eq $_.handlerAddress } | ForEach-Object { $_.pc }) -join ',')
    Assert-Equal $attempt40Handlers '795D,7880,795D,7AB1,7931' 'authorized attempt-40 handler sequence is exact'
    Assert-Equal $attempt40Observation.inputProvenance.observed.startRows.Count 18 'authorized attempt-40 records all start-active rows'
    Assert-Equal $attempt40Observation.inputProvenance.observed.startRows[0].frame 2221 'authorized attempt-40 first start row is frame 2221'
    Assert-Equal $attempt40Observation.inputProvenance.observed.startRows[0].classification 'real_60hz' 'authorized attempt-40 frame 2221 is a real 60 Hz sample'
    Assert-Equal $attempt40Observation.inputProvenance.observed.startRows[0].emulatedTime '37.000000000' 'authorized attempt-40 real start begins at 37.000000000 s'
    Assert-Equal $attempt40Observation.inputProvenance.observed.startRows[4].frame 2225 'authorized attempt-40 last real start row is frame 2225'
    Assert-Equal $attempt40Observation.inputProvenance.observed.startRows[4].classification 'real_60hz' 'authorized attempt-40 frame 2225 is a real 60 Hz sample'
    Assert-Equal $attempt40Observation.inputProvenance.observed.startRows[4].emulatedTime '37.066666667' 'authorized attempt-40 real start ends at 37.066666667 s'
    Assert-Equal $attempt40Observation.inputProvenance.observed.startRows[5].frame 2226 'authorized attempt-40 first debug callback row is 2226'
    Assert-Equal $attempt40Observation.inputProvenance.observed.startRows[5].classification 'debug_stop_callback' 'authorized attempt-40 frame 2226 is a debugger-stop callback'
    Assert-Equal $attempt40Observation.inputProvenance.observed.startRows[5].recordedStopIndex 0 'authorized attempt-40 frame 2226 matches the first recorded stop'
    Assert-Equal $attempt40Observation.inputProvenance.observed.startRows[5].emulatedTime '37.076457558' 'authorized attempt-40 first debug callback time is 37.076457558 s'
    Assert-Equal $attempt40Observation.inputProvenance.observed.startRows[17].frame 2238 'authorized attempt-40 last debug callback row is 2238'
    Assert-Equal $attempt40Observation.inputProvenance.observed.startRows[17].classification 'debug_stop_callback' 'authorized attempt-40 frame 2238 is a debugger-stop callback'
    Assert-Equal $attempt40Observation.inputProvenance.observed.startRows[17].recordedStopIndex 12 'authorized attempt-40 frame 2238 matches the thirteenth recorded stop'
    Assert-Equal $attempt40Observation.inputProvenance.observed.startRows[17].emulatedTime '37.076576163' 'authorized attempt-40 last debug callback time is 37.076576163 s'
    Assert-Equal $attempt40Observation.inputProvenance.observed.startWindow.first 2221 'authorized attempt-40 start window first real frame is 2221'
    Assert-Equal $attempt40Observation.inputProvenance.observed.startWindow.last 2238 'authorized attempt-40 full active window ends at row 2238'
    Assert-Equal $attempt40Observation.inputProvenance.observed.startWindow.lastRealFrame 2225 'authorized attempt-40 real start window ends at frame 2225'
    Assert-Equal $attempt40Observation.inputProvenance.observed.startWindow.fixtureProbeLastExclusive 2232 'authorized attempt-40 fixture probe bound is 2232 exclusive'
    Assert-Equal $attempt40Observation.inputProvenance.observed.sampleContract.totalRows 2238 'authorized attempt-40 sample contract records all 2238 raw rows'
    Assert-Equal $attempt40Observation.inputProvenance.observed.sampleContract.minEmulatedTime '0.000002326' 'authorized attempt-40 minimum emulated time is recorded'
    Assert-Equal $attempt40Observation.inputProvenance.observed.sampleContract.maxEmulatedTime '37.076576163' 'authorized attempt-40 maximum emulated time is recorded'
    Assert-Equal $attempt40Observation.inputProvenance.observed.sampleContract.frameCounterFirst 1 'authorized attempt-40 first frame counter is 1'
    Assert-Equal $attempt40Observation.inputProvenance.observed.sampleContract.frameCounterLast 2238 'authorized attempt-40 last frame counter is 2238'
    Assert-Equal $attempt40Observation.inputProvenance.observed.debugStopEvidence.stopLineCount 14 'authorized attempt-40 debug log records fourteen stops'
    Assert-Equal $attempt40Observation.inputProvenance.observed.debugStopEvidence.compositeStopCount 13 'authorized attempt-40 debug log records thirteen composite stops'
    Assert-Equal $attempt40Observation.inputProvenance.observed.debugStopEvidence.recordedStopCount 13 'authorized attempt-40 has thirteen recorded phase stop times'
    Assert-Equal $attempt40Observation.reanalysis.classification 'read_only_private_copy_reanalysis' 'authorized attempt-40 is a read-only private-copy reanalysis'
    Assert-Equal $attempt40Observation.reanalysis.sourceEventsSha256 'EA4FAE8345CCBB25D6921628C0B8EB869B8C4FA60ECF0B44B25A2D2CF185C353' 'authorized attempt-40 binds the raw source event hash'
    Assert-Equal $attempt40Observation.reanalysis.rawArtifactModified $false 'authorized attempt-40 raw artifact was not modified'
    Assert-Equal $attempt40Observation.reanalysis.luaExecuted $false 'authorized attempt-40 analysis did not execute Lua'
    Assert-Equal $attempt40Observation.verificationGap.luaChangedAfterCapture $false 'authorized attempt-40 captured observer Lua is unchanged'
    Assert-Equal $attempt40Observation.verificationGap.toolChangedAfterCapture $true 'authorized attempt-40 records the post-capture analyzer change'
    Assert-Equal $attempt40Observation.verificationGap.rerunPerformed $false 'authorized attempt-40 was not rerun'
    Assert-Equal $attempt40Observation.run.eventsSha256 'EA4FAE8345CCBB25D6921628C0B8EB869B8C4FA60ECF0B44B25A2D2CF185C353' 'authorized attempt-40 run binds the raw event hash'
    Assert-Equal $attempt40Observation.run.eventRecordCount 15 'authorized attempt-40 run records fifteen events'
    Assert-Equal $attempt40Observation.run.stateFiles 0 'authorized attempt-40 records no state files'
    Assert-Equal $attempt40Observation.priorTraceComparison.postReturnTokenMatches $true 'authorized attempt-40 post-return token matches the prior trace'
    Assert-Equal $attempt40Observation.priorTraceComparison.savedCursorMatches $true 'authorized attempt-40 saved cursor matches the prior trace'

    $evidence = Read-JsonFile $EvidencePath
    Assert-Equal $evidence.taskId 'il-composite-authorized-capture-40' 'evidence task id is the accepted authorized capture'
    Assert-Equal $evidence.curationTaskId 'il-composite-input-time-41' 'evidence records the offline curation task'
    Assert-Equal $evidence.resultStatus 'complete_natural_composite_call' 'evidence records the accepted complete natural composite call'
    Assert-Equal $evidence.evidenceClass 'natural' 'evidence is natural-run evidence, not a synthetic fixture'
    Assert-Equal $evidence.builtRom.sha256 '761F34BAAC06C6F8F5DA963CCADEB276FAE9196EE1C4D9060BC915A314E3903D' 'evidence binds the exact built image'
    Assert-Equal $evidence.sourceMap.sha256 '9A560CA7818C7A8F56AC4E314BB5DF19E81F4EFABB23982CCC092CA648B5BCF8' 'evidence binds the final compiled map'
    Assert-Equal $evidence.sourceMap.contract.changedOffsetCount 21 'evidence records the 21-byte diff'
    Assert-Equal $evidence.sourceMap.contract.integrityFields 'E93F3C61B5' 'evidence records the repaired fields'
    Assert-Equal $evidence.boundaryHistory.boundary 'natural-composite-1010-call-from-9F14' 'evidence keeps the same natural composite boundary'
    Assert-Equal $evidence.boundaryHistory.attempts 3 'evidence records all three attempts'
    Assert-Equal $evidence.boundaryHistory.unsuccessfulAttempts 2 'both earlier attempts remain counted as unsuccessful'
    Assert-Equal $evidence.boundaryHistory.successfulAttempts 1 'one natural composite call is accepted'
    Assert-Equal $evidence.boundaryHistory.attempt1.inputPolicy 'none' 'attempt 1 remains the no-input failure'
    Assert-Equal $evidence.boundaryHistory.attempt1.phaseCount 0 'attempt 1 still records zero phases'
    Assert-Equal $evidence.boundaryHistory.attempt1.eventsSha256 '912CD4442EB623B59A8786386D0D937D0343AF61C1EA758D6D6743AC16CF86F3' 'attempt 1 raw event hash is preserved'
    Assert-Equal $evidence.boundaryHistory.attempt2.inputPolicy 'tracked_physical_replay' 'attempt 2 remains the tracked-replay attempt'
    Assert-Equal $evidence.boundaryHistory.attempt2.phaseCount 2 'attempt 2 still records the two reached phases'
    Assert-Equal $evidence.boundaryHistory.attempt2.failure.code 'phase_saved_cursor' 'attempt 2 still records the concrete observer failure'
    Assert-Equal $evidence.boundaryHistory.attempt2.eventsSha256 '4D545B1FB933A2585FB3B2233C1F429EF9B264BF1B2D7A380010341D4D0BC45D' 'attempt 2 raw event hash is preserved'
    Assert-Equal $evidence.boundaryHistory.attempt3.resultStatus 'complete_natural_composite_call' 'attempt 3 records the accepted complete call'
    Assert-Equal $evidence.boundaryHistory.attempt3.phaseCount 13 'attempt 3 records all thirteen phases'
    Assert-Equal $evidence.boundaryHistory.attempt3.eventsSha256 'EA4FAE8345CCBB25D6921628C0B8EB869B8C4FA60ECF0B44B25A2D2CF185C353' 'attempt 3 binds the raw event hash'
    Assert-Equal $evidence.boundaryHistory.attempt3.inputLevelsSha256 'D118902E7AFFB8B86D3C0B7FBCC92093205D228C91FFFF08BB0BEB6855CCF053' 'attempt 3 binds the raw input-levels hash'
    Assert-Equal $evidence.boundaryHistory.attempt3.call.complete $true 'attempt 3 call is complete'
    Assert-Equal $evidence.boundaryHistory.attempt3.call.resultWord '0000' 'attempt 3 result word is 0000'
    Assert-Equal $evidence.inputProvenance.used $true 'evidence records replay provenance use'
    Assert-Equal $evidence.inputProvenance.replay.sha256 '4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D' 'evidence binds the tracked replay fixture hash'
    Assert-Equal $evidence.inputProvenance.inputLua.sha256 '23099F8888AF8DB353253E0DF97638320DC59CA9A47371723A380E0C4EE85C94' 'evidence binds the tracked input Lua hash'
    Assert-Equal (($evidence.inputProvenance.observed.coinFrames -join ',') -replace ' ','') '2100,2101,2102,2103' 'evidence records observed coin frames'
    Assert-Equal (($evidence.inputProvenance.observed.startFrames -join ',') -replace ' ','') '2221,2222,2223,2224,2225,2226,2227,2228,2229,2230,2231,2232,2233,2234,2235,2236,2237,2238' 'evidence records every start-active row'
    Assert-Equal (($evidence.inputProvenance.observed.realFrameStartFrames -join ',') -replace ' ','') '2221,2222,2223,2224,2225' 'evidence records the five real 60 Hz start samples'
    Assert-Equal (($evidence.inputProvenance.observed.debugStopStartFrames -join ',') -replace ' ','') '2226,2227,2228,2229,2230,2231,2232,2233,2234,2235,2236,2237,2238' 'evidence records the thirteen debugger-stop callbacks'
    Assert-Equal (($evidence.inputProvenance.observed.requiredStartFrames -join ',') -replace ' ','') '2221,2222,2223,2224' 'evidence records the required effective start frames'
    Assert-Equal $evidence.inputProvenance.observed.startWindow.last 2238 'evidence records the full observed start-active window'
    Assert-Equal $evidence.inputProvenance.observed.startWindow.lastRealFrame 2225 'evidence distinguishes the last real start frame'
    Assert-Equal $evidence.inputProvenance.observed.startWindow.fixtureProbeLastExclusive 2232 'evidence records the fixture start probe bound'
    Assert-Equal $evidence.inputProvenance.observed.laterFixtureActionsUnused $true 'evidence records that later fixture actions were unused'
    Assert-Equal $evidence.inputProvenance.observed.sampleContract.framePeriodSeconds '0.016666667' 'evidence records the known 60 Hz period'
    Assert-Equal $evidence.inputProvenance.observed.sampleContract.gridToleranceSeconds '0.002083333' 'evidence records the eighth-frame grid tolerance'
    Assert-Equal $evidence.inputProvenance.observed.sampleContract.totalRows 2238 'evidence records the total raw sample-row count'
    Assert-Equal $evidence.inputProvenance.observed.debugStopEvidence.stopLineCount 14 'evidence records fourteen debugger stop lines'
    Assert-Equal $evidence.inputProvenance.observed.debugStopEvidence.compositeStopCount 13 'evidence records thirteen composite debugger stops'
    Assert-Equal $evidence.call.callerAddress '9F14' 'evidence binds the caller fetch'
    Assert-Equal $evidence.call.callerReplacementToken '1010' 'evidence binds token 1010'
    Assert-Equal $evidence.call.trampolinePc '00F8' 'evidence binds the trampoline PC'
    Assert-Equal $evidence.call.trampolineX '1012' 'evidence binds trampoline X'
    Assert-Equal $evidence.call.savedCursor '9F16' 'evidence records the live saved cursor'
    Assert-Equal $evidence.call.savedCursorAuthority 'return-handler live controlStack0' 'saved cursor authority is the live return handler'
    Assert-Equal $evidence.call.complete $true 'evidence claims the composite call completed'
    Assert-Equal $evidence.call.returnObserved $true 'evidence claims the actual PULS return'
    Assert-Equal $evidence.call.postReturnY '9F16' 'evidence records post-return Y 9F16'
    Assert-Equal $evidence.call.postReturnToken '75A9' 'evidence records post-return token 75A9'
    Assert-Equal $evidence.call.inputWord '0000' 'evidence records input word 0000'
    Assert-Equal $evidence.call.resultWord '0000' 'evidence records result word 0000'
    Assert-Equal $evidence.call.netU '0000' 'evidence records net U 0000'
    Assert-Equal $evidence.call.netS '0000' 'evidence records net S 0000'
    Assert-Equal $evidence.phases.Count 13 'evidence records all thirteen phases'
    Assert-Equal $evidence.phases[0].phase 'caller-dispatch' 'first observed phase is the caller fetch'
    Assert-Equal $evidence.phases[0].token '1010' 'caller fetch token is 1010'
    Assert-Equal $evidence.phases[0].y '9F14' 'caller fetch Y is 9F14'
    Assert-Equal $evidence.phases[1].phase 'header-trampoline-entry' 'second observed phase is the trampoline entry'
    Assert-Equal $evidence.phases[1].x '1012' 'trampoline X is 1012'
    Assert-Equal $evidence.phases[1].y '9F16' 'trampoline Y is 9F16'
    Assert-Equal $evidence.phases[11].phase 'return-handler' 'twelfth observed phase is the return handler'
    Assert-Equal $evidence.phases[11].controlStack0 '9F16' 'return handler live saved cursor is 9F16'
    Assert-Equal $evidence.phases[12].phase 'post-return-prefetch' 'final observed phase is the post-return prefetch'
    Assert-Equal $evidence.phases[12].token '75A9' 'post-return token is 75A9'
    Assert-True ($null -eq $evidence.failure) 'accepted evidence has no failure record'
    Assert-True ($null -eq $evidence.blocker) 'accepted evidence has no blocker record'
    Assert-Equal $evidence.verificationGap.present $true 'evidence reports the post-capture analyzer verification gap'
    Assert-Equal $evidence.verificationGap.luaChangedAfterCapture $false 'evidence records that the observer Lua was unchanged after capture'
    Assert-Equal $evidence.verificationGap.observerLuaUnchanged $true 'evidence records the observer is identical to the current tracked Lua'
    Assert-Equal $evidence.verificationGap.toolChangedAfterCapture $true 'evidence records that the analyzer changed after capture'
    Assert-Equal $evidence.verificationGap.rerunPerformed $false 'evidence records that no MAME rerun was performed'
    Assert-Equal $evidence.run.inputPolicy 'tracked_physical_replay' 'evidence records the tracked input policy'
    Assert-Equal $evidence.run.inputReplayUsed $true 'evidence records replay use'
    Assert-Equal $evidence.run.saveStateLoaded $false 'evidence records no save-state load'
    Assert-Equal $evidence.run.inputInjection $false 'evidence records no state injection disguised as input injection'
    Assert-Equal $evidence.run.stateInjection $false 'evidence records no state injection'
    Assert-Equal $evidence.run.stateFiles 0 'evidence records no state files'
    Assert-Equal $evidence.run.eventRecordCount 15 'evidence records fifteen strict raw events'
    Assert-Equal $evidence.run.eventsSha256 'EA4FAE8345CCBB25D6921628C0B8EB869B8C4FA60ECF0B44B25A2D2CF185C353' 'evidence event hash matches the raw capture'
    Assert-Equal $evidence.priorTraceComparison.prior.sha256 '39A1CB2FD46FA36D66C6C4B261483D298644A22FC2690BF95C4A9697265917D9' 'evidence labels the prior original trace by hash'
    Assert-Equal $evidence.priorTraceComparison.prior.classification 'prior_trace_comparison_not_new_control_run' 'prior trace is not relabelled as a new control run'
    Assert-Equal $evidence.priorTraceComparison.prior.postReturnToken '75A9' 'prior trace post-return token is recorded for comparison'
    Assert-Equal $evidence.priorTraceComparison.postReturnTokenMatches $true 'observed post-return token matches the prior trace'
    Assert-Equal $evidence.priorTraceComparison.observedSavedCursor '9F16' 'observed saved cursor is taken from the live return handler'
    Assert-Equal $evidence.priorTraceComparison.savedCursorMatches $true 'observed saved cursor matches the prior trace'
    Assert-Equal $evidence.runLocalAssets.lua.sha256 '2A97FF58C2C6124C7D657D8387F61D58C55D328F39ED3FA71D2A740E9AF76C70' 'evidence rehashes the actual run-local observer'
    Assert-Equal $evidence.runLocalAssets.mapLua.sha256 $evidence.runLocalAssets.mapLua.canonicalSha256 'run-local map Lua matches the canonical source-map rendering'
    Assert-Equal $evidence.runLocalAssets.configLua.sha256 $evidence.runLocalAssets.configLua.canonicalSha256 'run-local config Lua matches the canonical config rendering'
    Assert-Equal $evidence.runLocalAssets.metadataBinding 'metadata_run_local_assets_match' 'capture metadata binds the actual run-local assets'
    Assert-Equal $evidence.reanalysis.classification 'read_only_private_copy_reanalysis' 'evidence records read-only private-copy reanalysis'
    Assert-Equal $evidence.reanalysis.sourceEventsSha256 'EA4FAE8345CCBB25D6921628C0B8EB869B8C4FA60ECF0B44B25A2D2CF185C353' 'evidence binds the source raw event hash'
    Assert-Equal $evidence.reanalysis.rawArtifactModified $false 'evidence records that the raw artifact was not modified'
    Assert-Equal $evidence.reanalysis.luaExecuted $false 'evidence records that no Lua was executed for analysis'
    Assert-Equal $evidence.reanalysisHistory.attempt1.sourceEventsSha256 '912CD4442EB623B59A8786386D0D937D0343AF61C1EA758D6D6743AC16CF86F3' 'prior attempt-1 reanalysis hash is preserved'
    Assert-Equal $evidence.reanalysisHistory.attempt2.sourceEventsSha256 '4D545B1FB933A2585FB3B2233C1F429EF9B264BF1B2D7A380010341D4D0BC45D' 'prior attempt-2 reanalysis hash is preserved'
    Assert-Equal $evidence.reanalysisHistory.attempt3.status 'complete_natural_composite_call' 'attempt-3 reanalysis records the accepted call'
    Assert-Equal $evidence.task40AuthorizedCapture.status 'complete_natural_composite_call' 'the preserved task-40 capture block records the accepted resolution'
    Assert-Equal $evidence.task40AuthorizedCapture.acceptedComplete $true 'the preserved task-40 capture block is accepted after reanalysis'
    Assert-Equal $evidence.task40AuthorizedCapture.analyzerRejection.failure 'The start-active window ends at 2238, beyond the replay fixture''s 2220-2232 start probe' 'the original analyzer rejection remains recorded verbatim'
    Assert-Equal $evidence.task40AuthorizedCapture.analyzerRejectionResolvedBy 'il-composite-input-time-41' 'the original rejection records its offline resolution task'
    Assert-Equal (($evidence.task40AuthorizedCapture.realFrameStartRows -join ',') -replace ' ','') '2221,2222,2223,2224,2225' 'the task-40 block records the real 60 Hz start rows'
    Assert-Equal (($evidence.task40AuthorizedCapture.debugStopStartRows -join ',') -replace ' ','') '2226,2227,2228,2229,2230,2231,2232,2233,2234,2235,2236,2237,2238' 'the task-40 block records the debugger-stop rows'
    Assert-Equal $evidence.task40AuthorizedCapture.stopPseudoRows 13 'the task-40 block records thirteen stop pseudo rows'
    Assert-Equal $evidence.analyzerCorrection.classification 'offline_input_sampling_evidence_boundary_repair_no_mame_no_lua_execution' 'evidence records the offline sample-contract repair'
    Assert-Equal $evidence.analyzerCorrection.mameLaunches 0 'the repair performed no MAME launch'
    Assert-Equal $evidence.analyzerCorrection.luaExecutions 0 'the repair executed no Lua'
    Assert-Equal $evidence.analyzerCorrection.startRows.Count 18 'the repair records all start-active row classifications'
    Assert-Equal $evidence.analyzerCorrection.rawHashes.eventsSha256 'EA4FAE8345CCBB25D6921628C0B8EB869B8C4FA60ECF0B44B25A2D2CF185C353' 'the repair records the exact raw event hash'
    Assert-Equal $evidence.analyzerCorrection.rawHashes.inputLevelsSha256 'D118902E7AFFB8B86D3C0B7FBCC92093205D228C91FFFF08BB0BEB6855CCF053' 'the repair records the exact raw input-levels hash'
    Assert-Equal $evidence.analyzerCorrection.rawHashes.runLuaSha256 '2A97FF58C2C6124C7D657D8387F61D58C55D328F39ED3FA71D2A740E9AF76C70' 'the repair records the exact raw observer hash'
    Assert-Equal $evidence.analyzerCorrection.rawHashes.runRomSha256 '761F34BAAC06C6F8F5DA963CCADEB276FAE9196EE1C4D9060BC915A314E3903D' 'the repair records the exact raw ROM hash'

    $fixture = New-SyntheticFixture -SourceRun $RunDirectory -Destination (Join-Path $tempRoot 'synthetic-complete')
    $fixtureVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$fixture)
    Assert-Equal $fixtureVerify.exitCode 0 'synthetic checker fixture passes ordered phase validation'
    $fv = $fixtureVerify.text | ConvertFrom-Json
    Assert-Equal $fv.status 'synthetic_fixture_complete_not_evidence' 'synthetic fixture cannot satisfy natural acceptance'
    Assert-Equal $fv.complete $true 'synthetic fixture exercises the complete phase chain'
    Assert-Equal $fv.phases 13 'synthetic fixture contains all thirteen ordered phases'
    Assert-Equal $fv.resultWord '0000' 'synthetic fixture result word is the map-derived 0000'
    Assert-Equal $fv.netU '0000' 'synthetic fixture U delta is zero'
    Assert-Equal $fv.netS '0000' 'synthetic fixture S delta is zero'
    $fixtureObservation = Read-JsonFile (Join-Path $fixture 'observation.json')
    Assert-Equal $fixtureObservation.call.savedCursor '9F16' 'complete fixture derives saved cursor from the live return handler'
    Assert-Equal $fixtureObservation.call.savedCursorAuthority 'return-handler live controlStack0' 'complete fixture labels the live saved-cursor authority'
    Assert-Equal $fixtureObservation.priorTraceComparison.savedCursorMatches $true 'complete fixture compares the live saved cursor only'
    Assert-Equal $fixtureObservation.phases[1].controlStack0 '9F3F' 'pre-PSHS trampoline control stack top is 9F3F'
    Assert-Equal $fixtureObservation.phases[1].savedCursor '' 'pre-PSHS trampoline does not claim a saved cursor'
    Assert-Equal $fixtureObservation.phases[2].controlStack0 '9F16' 'post-PSHS body control stack top is 9F16'
    Assert-Equal $fixtureObservation.phases[11].controlStack0 '9F16' 'return handler live control stack top is 9F16'
    Assert-Equal $fixtureObservation.verificationGap.luaExecutedForAnalysis $false 'synthetic fixture is checker-only; it does not execute Lua'

    $wrongY = New-RunCopy $fixture (Join-Path $tempRoot 'negative-wrong-y')
    $wrongYEvents = Join-Path $wrongY 'events.jsonl'
    $records = Read-EventRecords $wrongYEvents
    foreach ($record in $records) { if ([string]$record.event -eq 'phase' -and [string]$record.phase -eq 'caller-dispatch') { $record.y = '9F16' } }
    Write-EventRecords $wrongYEvents $records
    $wrongYVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$wrongY)
    Assert-True ($wrongYVerify.exitCode -ne 0) 'wrong Y phase is rejected'

    $missingReturn = New-RunCopy $fixture (Join-Path $tempRoot 'negative-missing-return')
    $missingReturnEvents = Join-Path $missingReturn 'events.jsonl'
    $records = Read-EventRecords $missingReturnEvents
    $kept = New-Object 'System.Collections.Generic.List[object]'
    foreach ($record in $records) { if (!([string]$record.event -eq 'phase' -and [string]$record.phase -eq 'post-return-prefetch')) { $kept.Add($record) } }
    Write-EventRecords $missingReturnEvents $kept
    $missingReturnVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$missingReturn)
    Assert-True ($missingReturnVerify.exitCode -ne 0) 'missing actual post-PULS return is rejected'

    $wrongCursor = New-RunCopy $fixture (Join-Path $tempRoot 'negative-wrong-cursor')
    $wrongCursorEvents = Join-Path $wrongCursor 'events.jsonl'
    $records = Read-EventRecords $wrongCursorEvents
    foreach ($record in $records) {
        if ([string]$record.event -eq 'phase' -and [string]$record.phase -eq 'return-handler') { $record.savedCursor = '9F14'; $record.controlStack0 = '9F14' }
    }
    Write-EventRecords $wrongCursorEvents $records
    $wrongCursorVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$wrongCursor)
    Assert-True ($wrongCursorVerify.exitCode -ne 0) 'wrong saved return cursor is rejected'

    $stackDelta = New-RunCopy $fixture (Join-Path $tempRoot 'negative-stack-delta')
    $stackDeltaEvents = Join-Path $stackDelta 'events.jsonl'
    $records = Read-EventRecords $stackDeltaEvents
    foreach ($record in $records) { if ([string]$record.event -eq 'phase' -and [string]$record.phase -eq 'body-prefetch-0') { $record.s = '0798' } }
    Write-EventRecords $stackDeltaEvents $records
    $stackDeltaVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$stackDelta)
    Assert-True ($stackDeltaVerify.exitCode -ne 0) 'wrong S delta at the body prefetch is rejected'

    $syntheticClaim = New-RunCopy $fixture (Join-Path $tempRoot 'negative-synthetic-state')
    Set-MetadataField $syntheticClaim 'input_injection' $true
    $syntheticVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$syntheticClaim)
    Assert-True ($syntheticVerify.exitCode -ne 0) 'forged natural state/input-injection claim is rejected'

    $stateClaim = New-RunCopy $fixture (Join-Path $tempRoot 'negative-state-injection')
    Set-MetadataField $stateClaim 'state_injection' $true
    $stateVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$stateClaim)
    Assert-True ($stateVerify.exitCode -ne 0) 'forged state-injection claim is rejected'

    $noReplayClaim = New-RunCopy $fixture (Join-Path $tempRoot 'negative-no-input-complete')
    Set-MetadataField $noReplayClaim 'input_policy' 'none'
    $noReplayEvents = Join-Path $noReplayClaim 'events.jsonl'
    $records = Read-EventRecords $noReplayEvents
    foreach ($record in $records) { if ([string]$record.event -eq 'session_ready') { $record.inputPolicy = 'none' } }
    Write-EventRecords $noReplayEvents $records
    $noReplayVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$noReplayClaim)
    Assert-True ($noReplayVerify.exitCode -ne 0) 'natural completion without tracked replay provenance is rejected'

    $wrongReplay = New-RunCopy $fixture (Join-Path $tempRoot 'negative-wrong-replay-hash')
    Set-MetadataField $wrongReplay 'input_replay' ([ordered]@{
        path = (Join-Path $wrongReplay 'replay-actions.csv')
        length = (Get-Item -LiteralPath (Join-Path $wrongReplay 'replay-actions.csv')).Length
        sha256 = '0000000000000000000000000000000000000000000000000000000000000000'
        input_lua_path = (Join-Path $wrongReplay 'input.lua')
        input_lua_sha256 = $script:InputLuaSha256
        classification = 'tracked_physical_input_replay_no_state_injection'
    })
    $wrongReplayVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$wrongReplay)
    Assert-True ($wrongReplayVerify.exitCode -ne 0) 'wrong replay provenance hash is rejected'

    $missingReplay = New-RunCopy $fixture (Join-Path $tempRoot 'negative-missing-replay-file')
    Remove-Item -LiteralPath (Join-Path $missingReplay 'replay-actions.csv') -Force
    $missingReplayVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$missingReplay)
    Assert-True ($missingReplayVerify.exitCode -ne 0) 'missing tracked replay file is rejected'

    $wrongInputLua = New-RunCopy $fixture (Join-Path $tempRoot 'negative-wrong-input-lua')
    $wrongInputLuaMeta = Read-JsonFile (Join-Path $wrongInputLua 'session-metadata.json')
    $wrongInputLuaMeta.input_replay.input_lua_sha256 = '0000000000000000000000000000000000000000000000000000000000000000'
    Write-JsonFile (Join-Path $wrongInputLua 'session-metadata.json') $wrongInputLuaMeta 40
    $wrongInputLuaVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$wrongInputLua)
    Assert-True ($wrongInputLuaVerify.exitCode -ne 0) 'wrong input Lua provenance hash is rejected'

    $wrongCoin = New-RunCopy $fixture (Join-Path $tempRoot 'negative-missing-coin')
    Edit-InputLevels $wrongCoin 2101 2103 'aux2'
    $wrongCoinVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$wrongCoin)
    Assert-True ($wrongCoinVerify.exitCode -ne 0) 'missing coin input pulse is rejected'

    $wrongStart = New-RunCopy $fixture (Join-Path $tempRoot 'negative-missing-start')
    Edit-InputLevels $wrongStart 2221 2224 'black2'
    $wrongStartVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$wrongStart)
    Assert-True ($wrongStartVerify.exitCode -ne 0) 'missing start input pulse is rejected'

    $wrongMap = New-RunCopy $fixture (Join-Path $tempRoot 'negative-wrong-map')
    $wrongMapPath = Join-Path $wrongMap 'composite-source-map.json'
    $wrongMapJson = Read-JsonFile $wrongMapPath
    $wrongMapJson.OutputImageSha256 = '0000000000000000000000000000000000000000000000000000000000000000'
    Write-JsonFile $wrongMapPath $wrongMapJson 40
    $wrongMapSha = Get-Sha256 $wrongMapPath
    $wrongMapMeta = Join-Path $wrongMap 'session-metadata.json'
    $metadata = Read-JsonFile $wrongMapMeta
    $metadata.source_map.sha256 = $wrongMapSha
    Write-JsonFile $wrongMapMeta $metadata 40
    $wrongMapVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$wrongMap)
    Assert-True ($wrongMapVerify.exitCode -ne 0) 'wrong image/map binding is rejected'

    $missingRecord = New-RunCopy $fixture (Join-Path $tempRoot 'negative-missing-runrecord')
    Remove-Item -LiteralPath (Join-Path $missingRecord 'run-record.json') -Force
    $missingRecordVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$missingRecord)
    Assert-True ($missingRecordVerify.exitCode -ne 0) 'missing MAME run record is rejected'

    $nonzeroExit = New-RunCopy $fixture (Join-Path $tempRoot 'negative-nonzero-exit')
    $nonzeroJson = Read-JsonFile (Join-Path $nonzeroExit 'run-record.json')
    $nonzeroJson.exitCode = 1
    $nonzeroJson.timedOut = $false
    Write-JsonFile (Join-Path $nonzeroExit 'run-record.json') $nonzeroJson 8
    [IO.File]::WriteAllText((Join-Path $nonzeroExit 'exit-code.txt'),'1',(New-Object System.Text.UTF8Encoding($false)))
    $nonzeroVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$nonzeroExit)
    Assert-True ($nonzeroVerify.exitCode -ne 0) 'nonzero MAME exit is rejected'

    $timedOutExit = New-RunCopy $fixture (Join-Path $tempRoot 'negative-timed-out')
    $timedOutJson = Read-JsonFile (Join-Path $timedOutExit 'run-record.json')
    $timedOutJson.exitCode = 0
    $timedOutJson.timedOut = $true
    Write-JsonFile (Join-Path $timedOutExit 'run-record.json') $timedOutJson 8
    [IO.File]::WriteAllText((Join-Path $timedOutExit 'exit-code.txt'),'0',(New-Object System.Text.UTF8Encoding($false)))
    $timedOutVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$timedOutExit)
    Assert-True ($timedOutVerify.exitCode -ne 0) 'MAME wall timeout is rejected'

    $exitMismatch = New-RunCopy $fixture (Join-Path $tempRoot 'negative-exit-mismatch')
    [IO.File]::WriteAllText((Join-Path $exitMismatch 'exit-code.txt'),'1',(New-Object System.Text.UTF8Encoding($false)))
    $exitMismatchVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$exitMismatch)
    Assert-True ($exitMismatchVerify.exitCode -ne 0) 'run-record/exit-code.txt mismatch is rejected'

    $reordered = New-RunCopy $fixture (Join-Path $tempRoot 'negative-reordered-events')
    $reorderedEvents = Join-Path $reordered 'events.jsonl'
    $records = Read-EventRecords $reorderedEvents
    $completeRecord = @($records | Where-Object { [string]$_.event -eq 'session_complete' })[0]
    $others = New-Object 'System.Collections.Generic.List[object]'
    foreach ($record in $records) { if ([string]$record.event -ne 'session_complete') { $others.Add($record) } }
    $reorderedRecords = New-Object 'System.Collections.Generic.List[object]'
    $reorderedRecords.Add($completeRecord)
    foreach ($record in $others) { $reorderedRecords.Add($record) }
    Write-EventRecords $reorderedEvents $reorderedRecords
    $reorderedVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$reordered)
    Assert-True ($reorderedVerify.exitCode -ne 0) 'session_complete before ready is rejected'

    $failureWithComplete = New-RunCopy $fixture (Join-Path $tempRoot 'negative-failure-with-complete')
    $fxEvents = Join-Path $failureWithComplete 'events.jsonl'
    $records = Read-EventRecords $fxEvents
    $withFailure = New-Object 'System.Collections.Generic.List[object]'
    foreach ($record in @($records[0..($records.Count - 2)])) { $withFailure.Add($record) }
    $withFailure.Add([ordered]@{ event='protocol_failure'; code='forged_audit_control'; message='forged failure with complete claim'; observed='13'; expected='13' })
    $withFailure.Add($records[$records.Count - 1])
    Write-EventRecords $fxEvents $withFailure
    $failureWithCompleteVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$failureWithComplete)
    Assert-True ($failureWithCompleteVerify.exitCode -ne 0) 'failure plus complete claim is rejected'

    $duplicateReady = New-RunCopy $fixture (Join-Path $tempRoot 'negative-duplicate-ready')
    $dupEvents = Join-Path $duplicateReady 'events.jsonl'
    $records = Read-EventRecords $dupEvents
    $dupRecords = New-Object 'System.Collections.Generic.List[object]'
    $dupRecords.Add($records[0])
    foreach ($record in $records) { $dupRecords.Add($record) }
    Write-EventRecords $dupEvents $dupRecords
    $duplicateReadyVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$duplicateReady)
    Assert-True ($duplicateReadyVerify.exitCode -ne 0) 'duplicate session_ready is rejected'

    $phaseGap = New-RunCopy $fixture (Join-Path $tempRoot 'negative-phase-gap')
    $gapEvents = Join-Path $phaseGap 'events.jsonl'
    $records = Read-EventRecords $gapEvents
    $gapRecords = New-Object 'System.Collections.Generic.List[object]'
    foreach ($record in $records) { if (!([string]$record.event -eq 'phase' -and [string]$record.phase -eq 'handler-1')) { $gapRecords.Add($record) } }
    Write-EventRecords $gapEvents $gapRecords
    $phaseGapVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$phaseGap)
    Assert-True ($phaseGapVerify.exitCode -ne 0) 'missing middle phase is rejected'

    $earlyCoin = New-RunCopy $fixture (Join-Path $tempRoot 'negative-extra-early-coin')
    Set-InputLevel $earlyCoin 1000 'aux2' '80'
    $earlyCoinVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$earlyCoin)
    Assert-True ($earlyCoinVerify.exitCode -ne 0) 'extra coin activity before the coin window is rejected'

    $lateStart = New-RunCopy $fixture (Join-Path $tempRoot 'negative-extra-late-start')
    Append-InputLevel $lateStart 2350 '39.166666667' '00' '80' '0'
    $lateStartVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$lateStart)
    Assert-True ($lateStartVerify.exitCode -ne 0) 'extra start activity after the start window is rejected'

    $debugSpoof = New-RunCopy $fixture (Join-Path $tempRoot 'negative-debug-callback-spoof')
    Append-InputLevel $debugSpoof 2239 '37.076580000' '00' '80' '0'
    $debugSpoofVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$debugSpoof)
    Assert-True ($debugSpoofVerify.exitCode -ne 0) 'unsupported debug-callback spoof is rejected'

    $duplicateTime = New-RunCopy $fixture (Join-Path $tempRoot 'negative-duplicate-sample-time')
    Append-InputLevel $duplicateTime 2239 '37.076577558' '00' '80' '0'
    $duplicateTimeVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$duplicateTime)
    Assert-True ($duplicateTimeVerify.exitCode -ne 0) 'duplicate sample time is rejected'

    $nonMonotonicTime = New-RunCopy $fixture (Join-Path $tempRoot 'negative-nonmonotonic-sample-time')
    Append-InputLevel $nonMonotonicTime 2239 '37.076500000' '00' '80' '0'
    $nonMonotonicTimeVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$nonMonotonicTime)
    Assert-True ($nonMonotonicTimeVerify.exitCode -ne 0) 'non-monotonic sample time is rejected'

    $malformedTime = New-RunCopy $fixture (Join-Path $tempRoot 'negative-malformed-sample-time')
    [IO.File]::AppendAllText((Join-Path $malformedTime 'input-levels.csv'),"2239,bad,00,80,0`n",(New-Object System.Text.UTF8Encoding($false)))
    $malformedTimeVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$malformedTime)
    Assert-True ($malformedTimeVerify.exitCode -ne 0) 'malformed sample time is rejected'

    $runLuaChanged = New-RunCopy $fixture (Join-Path $tempRoot 'negative-run-lua-changed')
    [IO.File]::AppendAllText((Join-Path $runLuaChanged 'IlCompositeNatural.lua'),"-- mutated run-local observer`n",(New-Object System.Text.UTF8Encoding($false)))
    $runLuaChangedVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$runLuaChanged)
    Assert-True ($runLuaChangedVerify.exitCode -ne 0) 'mutated run-local observer Lua is rejected'

    $mapLuaChanged = New-RunCopy $fixture (Join-Path $tempRoot 'negative-run-map-lua-changed')
    [IO.File]::AppendAllText((Join-Path $mapLuaChanged 'composite-map.lua'),"-- mutated run-local map`n",(New-Object System.Text.UTF8Encoding($false)))
    $mapLuaChangedVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$mapLuaChanged)
    Assert-True ($mapLuaChangedVerify.exitCode -ne 0) 'mutated run-local map Lua is rejected'

    $configLuaChanged = New-RunCopy $fixture (Join-Path $tempRoot 'negative-run-config-lua-changed')
    [IO.File]::AppendAllText((Join-Path $configLuaChanged 'session-config.lua'),"-- mutated run-local config`n",(New-Object System.Text.UTF8Encoding($false)))
    $configLuaChangedVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$configLuaChanged)
    Assert-True ($configLuaChangedVerify.exitCode -ne 0) 'mutated run-local config Lua is rejected'

    $metadataAssets = New-RunCopy $fixture (Join-Path $tempRoot 'positive-metadata-assets')
    $metadataAssetsPath = Join-Path $metadataAssets 'session-metadata.json'
    $metadataAssetsJson = Read-JsonFile $metadataAssetsPath
    $metadataAssetsJson | Add-Member -NotePropertyName run_local_assets -NotePropertyValue ([ordered]@{
        lua = Get-Sha256 (Join-Path $metadataAssets 'IlCompositeNatural.lua')
        map_lua = Get-Sha256 (Join-Path $metadataAssets 'composite-map.lua')
        config_lua = Get-Sha256 (Join-Path $metadataAssets 'session-config.lua')
        config_json = Get-Sha256 (Join-Path $metadataAssets 'session-config.json')
        observer = Get-Sha256 (Join-Path $metadataAssets 'observer.lua')
    }) -Force
    Write-JsonFile $metadataAssetsPath $metadataAssetsJson 40
    $metadataAssetsVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$metadataAssets)
    Assert-Equal $metadataAssetsVerify.exitCode 0 'metadata run-local asset hashes bind the actual run copies'
    $metadataAssetsObservation = Read-JsonFile (Join-Path $metadataAssets 'observation.json')
    Assert-Equal $metadataAssetsObservation.runLocalAssets.metadataBinding 'metadata_run_local_assets_match' 'metadata run-local asset binding is positively exercised'

    $metadataAssetsForged = New-RunCopy $metadataAssets (Join-Path $tempRoot 'negative-forged-metadata-assets')
    $forgedMetaPath = Join-Path $metadataAssetsForged 'session-metadata.json'
    $forgedMeta = Read-JsonFile $forgedMetaPath
    $forgedMeta.run_local_assets.lua = '0000000000000000000000000000000000000000000000000000000000000000'
    Write-JsonFile $forgedMetaPath $forgedMeta 40
    $forgedMetaVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$metadataAssetsForged)
    Assert-True ($forgedMetaVerify.exitCode -ne 0) 'forged metadata run-local asset hashes are rejected'

    $observerChanged = New-RunCopy $fixture (Join-Path $tempRoot 'negative-run-observer-changed')
    [IO.File]::AppendAllText((Join-Path $observerChanged 'observer.lua'),"-- mutated observer`n",(New-Object System.Text.UTF8Encoding($false)))
    $observerChangedVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$observerChanged)
    Assert-True ($observerChangedVerify.exitCode -ne 0) 'mutated run-local observer composition is rejected'

    $wrongHeaderCursor = New-RunCopy $fixture (Join-Path $tempRoot 'negative-header-savedcursor')
    $headerEvents = Join-Path $wrongHeaderCursor 'events.jsonl'
    $records = Read-EventRecords $headerEvents
    foreach ($record in $records) { if ([string]$record.event -eq 'phase' -and [string]$record.phase -eq 'header-trampoline-entry') { $record.savedCursor = '9F14' } }
    Write-EventRecords $headerEvents $records
    $wrongHeaderCursorVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$wrongHeaderCursor)
    Assert-True ($wrongHeaderCursorVerify.exitCode -ne 0) 'wrong header saved-cursor claim is rejected'

    $impossibleHeaderStack = New-RunCopy $fixture (Join-Path $tempRoot 'negative-header-preshs-stack')
    $headerStackEvents = Join-Path $impossibleHeaderStack 'events.jsonl'
    $records = Read-EventRecords $headerStackEvents
    foreach ($record in $records) { if ([string]$record.event -eq 'phase' -and [string]$record.phase -eq 'header-trampoline-entry') { $record.controlStack0 = '9F16' } }
    Write-EventRecords $headerStackEvents $records
    $impossibleHeaderStackVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$impossibleHeaderStack)
    Assert-True ($impossibleHeaderStackVerify.exitCode -ne 0) 'impossible pre-PSHS control-stack state is rejected'

    $strictNegative = Join-Path $tempRoot 'strict-negative.json'
    $pwsh = Get-Command pwsh -ErrorAction Stop | Select-Object -First 1
    & $pwsh.Source -NoProfile -File $script:JsonHelper -Mode Negative -OutputPath $strictNegative 2>&1 | Out-Null
    Assert-Equal $LASTEXITCODE 0 'strict JSON negative controls reject malformed records'

    $manifest = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:ManifestTool -Verify 2>&1
    Assert-Equal $LASTEXITCODE 0 'curated manifest verifies'
    Assert-True (($manifest | Out-String) -match 'Verified \d+ curated entries') 'curated manifest verification reports entries'

    Write-Output ("RESULT: {0} checks, {1} failures" -f $script:Checks,$script:Failures)
    if ($script:Failures -ne 0) { exit 1 }
}
finally {
    Write-Output ("TEST-RUN-ROOT: {0}" -f $tempRoot)
}

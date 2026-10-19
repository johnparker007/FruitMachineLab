[CmdletBinding()]
param(
    [string]$OriginalRom = 'C:\projects\GitRepos\FruitMachineLab\artifacts\deepseek\general-14\roms\original.p1',
    [string]$BuiltRom = 'C:\projects\GitRepos\FruitMachineLab\artifacts\deepseek\il-larger-replacement-build-50\cli-check-03\positive-01\larger-repaired.p1',
    [string]$SourceMapPath = 'C:\projects\GitRepos\FruitMachineLab\artifacts\deepseek\il-larger-replacement-build-50\cli-check-03\positive-01\larger-replacement-source-map.json',
    [string]$BuildReportPath = 'C:\projects\GitRepos\FruitMachineLab\artifacts\deepseek\il-larger-replacement-build-50\cli-check-03\positive-01\build-report.json',
    [string]$ReplayPath = 'C:\projects\GitRepos\FruitMachineLab\evidence\mpu4\skill-cash\actions.csv',
    [string]$InputLuaPath = 'C:\projects\GitRepos\FruitMachineLab\evidence\mpu4\skill-cash\input.lua',
    [string]$OutputRoot
)
$ErrorActionPreference = 'Stop'

$script:Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script:Tool = Join-Path $script:Root 'tools/Capture-IlLargerReplacementNatural.ps1'
$script:Lua = Join-Path $script:Root 'tools/lua/IlLargerReplacementNatural.lua'
$script:JsonHelper = Join-Path $script:Root 'tests/worker/Test-IlEventJson.ps1'
$script:Checks = 0
$script:Failures = 0
$script:Utf8 = New-Object System.Text.UTF8Encoding($false)

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
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToUpperInvariant() }
        finally { $sha.Dispose() }
    }
    finally { $stream.Dispose() }
}
function Write-JsonFile([string]$Path,$Object,[int]$Depth = 40) {
    $parent = Split-Path -Parent $Path
    if (![string]::IsNullOrWhiteSpace($parent) -and !(Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($Path,(ConvertTo-Json -InputObject $Object -Depth $Depth),$script:Utf8)
}
function Read-JsonFile([string]$Path) { return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
function Format-Hex16([int]$Value) { return ('{0:X4}' -f ($Value -band 0xFFFF)) }
function Format-Hex8([int]$Value) { return ('{0:X2}' -f ($Value -band 0xFF)) }
function ConvertTo-HexInt([string]$Text) { return [Convert]::ToInt32($Text,16) }

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $script:Root ('artifacts/deepseek/il-larger-replacement-natural-51/offline/' + [guid]::NewGuid().ToString('N'))
}
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null

. $script:Tool -LibraryOnly

function Get-FixtureContract {
    $built = [IO.File]::ReadAllBytes($BuiltRom)
    $original = [IO.File]::ReadAllBytes($OriginalRom)
    $map = Read-JsonFile $SourceMapPath
    $build = Read-JsonFile $BuildReportPath
    return Test-LargerMapContract $map $build $built $original
}

function New-Events {
    param([string]$SessionId,[string]$BuildSha,[string]$MapSha,[string]$BuildHash,[string]$LuaSha,[string]$MameSha,[string]$OriginalSha)
    $records = New-Object 'System.Collections.Generic.List[object]'
    $records.Add([ordered]@{
        event='session_ready'
        sessionId=$SessionId
        imageSha256=$BuildSha
        originalRomSha256=$OriginalSha
        sourceMapSha256=$MapSha
        buildReportSha256=$BuildHash
        luaSha256=$LuaSha
        mameSha256=$MameSha
        resetPc='7CCF'
        secondsToRun='180'
        wallTimeoutSeconds='600'
        headerAddress='1010'
        headerValue='00F8'
        bodyStart='1012'
        bodyEndExclusive='1026'
        callerAddress='9F14'
        callerToken='1010'
        successorAddress='9F16'
        successorToken='75A9'
        controlTop='9F3F'
        basePhaseCount='17'
        optionalSuccessor='post-75a9-successor'
        dpAvailable='true'
        dpUnavailableReason=''
        inputPolicy='tracked_physical_replay'
        replaySha256=$script:ReplaySha256
        inputLuaSha256=$script:InputLuaSha256
        boundarySource='native_debugger_bpset'
    })
    $stopTimes = New-Object 'System.Collections.Generic.List[double]'
    for ($i = 0; $i -lt $script:Phases.Count; $i++) { $stopTimes.Add(37.076457558 + ($i * 0.000010)) }
    for ($i = 0; $i -lt $script:Phases.Count; $i++) {
        $phase = $script:Phases[$i]
        $d = if ($null -ne $phase.d) { Format-Hex16 $phase.d } else { '0000' }
        $a = $d.Substring(0,2)
        $b = $d.Substring(2,2)
        $saved = if ($phase.savedCursorFromControl) { Format-Hex16 $phase.control0 } else { '' }
        $savedSource = if ($phase.savedCursorFromControl) { 'live_control_stack_top' } else { '' }
        $handler = if ($null -ne $phase.handlerAddress) { Format-Hex16 $phase.handlerAddress } else { '' }
        $inlineAddress = if ($null -ne $phase.inlineOperandAddress) { Format-Hex16 $phase.inlineOperandAddress } else { '' }
        $inlineValue = if ($null -ne $phase.inlineOperandValue) { Format-Hex16 $phase.inlineOperandValue } else { '' }
        $dataStack1 = if ($null -ne $phase.dataStack1) { Format-Hex16 $phase.dataStack1 } else { '0000' }
        $records.Add([ordered]@{
            event='phase'
            phase=$phase.name
            phaseIndex=[string]$i
            phaseClass=$(if ($i -lt $script:BasePhaseCount) { 'map_static_phase' } else { 'optional_post_successor_contract' })
            required=$(if ($i -lt $script:BasePhaseCount) { 'true' } else { 'false' })
            pc=(Format-Hex16 $phase.pc)
            curpc=(Format-Hex16 $phase.pc)
            a=$a
            b=$b
            d=$d
            cc='C4'
            x=(Format-Hex16 $(if ($null -ne $phase.x) { $phase.x } else { 0 }))
            y=(Format-Hex16 $phase.y)
            u=(Format-Hex16 $phase.u)
            s=(Format-Hex16 $phase.s)
            dpAvailable='true'
            dpRaw='0'
            dp='00'
            dpWidthBits='8'
            dpWidthSource='state_entry_size_bytes'
            dpNormalizedMask='00FF'
            emulatedTime=('{0:F9}' -f $stopTimes[$i])
            token=(Format-Hex16 $phase.token)
            tokenAddress=(Format-Hex16 $phase.tokenAddress)
            handlerAddress=$handler
            inlineOperandAddress=$inlineAddress
            inlineOperand=$inlineValue
            savedCursor=$saved
            savedCursorSource=$savedSource
            controlTopExpected=(Format-Hex16 $phase.control0)
            dataStack0=(Format-Hex16 $phase.top)
            dataStack1=$dataStack1
            dataStack2='0000'
            dataStack3='0000'
            controlStack0=(Format-Hex16 $phase.control0)
            controlStack1='0000'
            controlStack2='0000'
            controlStack3='0000'
            buildSha256=$BuildSha
            mapSha256=$MapSha
            mameSha256=$MameSha
            luaSha256=$LuaSha
            sessionId=$SessionId
            aux2='00'
            black2='80'
            inputPolicy='tracked_physical_replay'
        })
    }
    $records.Add([ordered]@{
        event='session_complete'
        reason='larger_replacement_complete_with_successor'
        complete='true'
        baseComplete='true'
        successorObserved='true'
        observed='17'
        expected='17'
        observedTotal='18'
        inputWord='0000'
        calleeExitWord='0001'
        resultWord='0000'
        postY='9F16'
        postS='0798'
        postToken='75A9'
        netU='0000'
        netS='0000'
        callerU='066E'
        callerS='0798'
        callerControlTop='9F3F'
        lastBasePhase='post-return-prefetch'
        lastPhase='post-75a9-successor'
        dpAvailable='true'
        dp='00'
        emulatedTime=('{0:F9}' -f $stopTimes[$stopTimes.Count - 1])
        wallSeconds='1'
        inputPolicy='tracked_physical_replay'
        replaySha256=$script:ReplaySha256
        inputLuaSha256=$script:InputLuaSha256
        buildSha256=$BuildSha
        mapSha256=$MapSha
        mameSha256=$MameSha
        luaSha256=$LuaSha
        sessionId=$SessionId
    })
    return [ordered]@{ records=$records; stopTimes=$stopTimes }
}

function New-InputLevels {
    param([double[]]$StopTimes)
    $invariant = [Globalization.CultureInfo]::InvariantCulture
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.Add('frame,t,aux2,black2,coin_override')
    $lastFrame = 2226 + $StopTimes.Count - 1
    for ($frame = 1; $frame -le $lastFrame; $frame++) {
        $time = ($frame - 1) / 60.0
        $aux2 = '00'
        $black2 = '00'
        $coin = '0'
        if ($frame -eq 2100) { $coin = '1' }
        if ($frame -eq 2101 -or $frame -eq 2102) { $aux2 = '80'; $coin = '1' }
        if ($frame -eq 2103) { $aux2 = '80' }
        if ($frame -ge 2221 -and $frame -le 2225) { $black2 = '80' }
        if ($frame -ge 2226 -and $frame -le $lastFrame) {
            $black2 = '80'
            $time = $StopTimes[$frame - 2226]
        }
        $lines.Add([string]::Format($invariant, '{0},{1:F9},{2},{3},{4}', $frame, $time, $aux2, $black2, $coin))
    }
    return ($lines -join "`n") + "`n"
}

function New-ValidInvocationArguments {
    param([string]$Run)
    return @('m4addr','-noreadconfig','-rompath',((Join-Path $Run 'roms')+';E:\Arcade\MAME0266\roms'),
        '-cfg_directory',(Join-Path $Run 'cfg'),'-nvram_directory',(Join-Path $Run 'nvram'),
        '-input_directory',(Join-Path $Run 'inp'),'-snapshot_directory',(Join-Path $Run 'snap'),
        '-comment_directory',(Join-Path $Run 'comments'),'-state_directory',(Join-Path $Run 'state'),
        '-diff_directory',(Join-Path $Run 'diff'),'-debug','-debugger','imgui','-debuglog',
        '-video','bgfx','-sound','none','-window','-skip_gameinfo','-nothrottle',
        '-seconds_to_run','180','-autoboot_delay','0',
        '-autoboot_script',(Join-Path $Run 'observer.lua'))
}

function New-Fixture {
    param([string]$Directory)
    if (Test-Path -LiteralPath $Directory) { throw "Fixture directory already exists: $Directory" }
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    foreach ($name in @('roms/m4addr','cfg','nvram','inp','snap','comments','state','diff')) { New-Item -ItemType Directory -Path (Join-Path $Directory $name) -Force | Out-Null }
    Copy-Item -LiteralPath $BuiltRom -Destination (Join-Path $Directory 'roms/m4addr/a6ls.p1')
    Copy-Item -LiteralPath $SourceMapPath -Destination (Join-Path $Directory 'larger-replacement-source-map.json')
    Copy-Item -LiteralPath $BuildReportPath -Destination (Join-Path $Directory 'build-report.json')
    Copy-Item -LiteralPath $ReplayPath -Destination (Join-Path $Directory 'replay-actions.csv')
    Copy-Item -LiteralPath $InputLuaPath -Destination (Join-Path $Directory 'input.lua')
    Copy-Item -LiteralPath $script:Lua -Destination (Join-Path $Directory 'IlLargerReplacementNatural.lua')
    [IO.File]::WriteAllText((Join-Path $Directory 'observer.lua'),"dofile('input.lua')`ndofile('IlLargerReplacementNatural.lua')`n",$script:Utf8)
    Write-LargerMapLua (Join-Path $Directory 'larger-replacement-map.lua')

    $contract = Get-FixtureContract
    $replaySchedule = Get-ReplaySchedule (Join-Path $Directory 'replay-actions.csv')
    $sessionId = [guid]::NewGuid().ToString('D')
    $luaSha = Get-Sha256 (Join-Path $Directory 'IlLargerReplacementNatural.lua')
    $mapSha = Get-Sha256 (Join-Path $Directory 'larger-replacement-source-map.json')
    $buildHash = Get-Sha256 (Join-Path $Directory 'build-report.json')
    $toolSha = Get-Sha256 $script:Tool
    $config = [ordered]@{
        schemaVersion = 1
        protocol = $script:Protocol
        sessionId = $sessionId
        secondsToRun = 180
        wallTimeoutSeconds = 600
        inputPolicy = 'tracked_physical_replay'
        expectedReplaySha256 = $script:ReplaySha256
        expectedInputLuaSha256 = $script:InputLuaSha256
        expectedImageSha256 = $script:BuiltSha256
        expectedOriginalRomSha256 = $script:OriginalSha256
        expectedSourceMapSha256 = $script:MapSha256
        expectedBuildReportSha256 = $buildHash
        expectedLuaSha256 = $luaSha
        expectedMameSha256 = $script:MameSha256
    }
    Write-LargerConfigLua (Join-Path $Directory 'session-config.lua') $config
    Write-JsonFile (Join-Path $Directory 'session-config.json') $config 8
    $runLocalAssets = [ordered]@{
        lua = $luaSha
        map_lua = Get-Sha256 (Join-Path $Directory 'larger-replacement-map.lua')
        config_lua = Get-Sha256 (Join-Path $Directory 'session-config.lua')
        config_json = Get-Sha256 (Join-Path $Directory 'session-config.json')
        observer = Get-Sha256 (Join-Path $Directory 'observer.lua')
    }
    $metadata = [ordered]@{
        protocol = $script:Protocol
        sessionId = $sessionId
        original_rom = [ordered]@{ path=[IO.Path]::GetFullPath($OriginalRom); length=65536; sha1=$script:OriginalSha1; sha256=$script:OriginalSha256 }
        built_rom = [ordered]@{ path=[IO.Path]::GetFullPath($BuiltRom); length=65536; sha1=$script:BuiltSha1; sha256=$script:BuiltSha256 }
        run_rom_before = [ordered]@{ path=[IO.Path]::GetFullPath((Join-Path $Directory 'roms/m4addr/a6ls.p1')); length=65536; sha1=$script:BuiltSha1; sha256=$script:BuiltSha256 }
        source_map = [ordered]@{ path=[IO.Path]::GetFullPath((Join-Path $Directory 'larger-replacement-source-map.json')); sha256=$mapSha }
        build_report = [ordered]@{ path=[IO.Path]::GetFullPath((Join-Path $Directory 'build-report.json')); sha256=$buildHash }
        lua = [ordered]@{ sourcePath=[IO.Path]::GetFullPath($script:Lua); sourceSha256=$luaSha; capturedPath=[IO.Path]::GetFullPath((Join-Path $Directory 'IlLargerReplacementNatural.lua')); capturedSha256=$luaSha }
        capture_tool = [ordered]@{ path=[IO.Path]::GetFullPath($script:Tool); sha256=$toolSha }
        run_local_assets = $runLocalAssets
        input_replay = [ordered]@{
            path=[IO.Path]::GetFullPath((Join-Path $Directory 'replay-actions.csv'))
            length=(Get-Item (Join-Path $Directory 'replay-actions.csv')).Length
            sha256=$script:ReplaySha256
            input_lua_path=[IO.Path]::GetFullPath((Join-Path $Directory 'input.lua'))
            input_lua_sha256=$script:InputLuaSha256
            coin_event=$replaySchedule.coin
            start_event=$replaySchedule.start
            classification='tracked_physical_input_replay_no_state_injection'
        }
        mame = [ordered]@{ executable='E:\Arcade\MAME0266\mame281.exe'; sha256=$script:MameSha256; version='0.281 (synthetic fixture)' }
        frontend = [ordered]@{ debugger='imgui'; video='bgfx'; bgfx_path='E:\Arcade\MAME0266\bgfx'; focus_stealing=$false }
        contract = $contract
        seconds_to_run = 180
        wall_timeout_seconds = 600
        starting_nvram = 'absent'
        starting_configuration = 'absent; -noreadconfig'
        save_state_loaded = $false
        state_injection = $false
        input_injection = $false
        input_replay_used = $true
        input_policy = 'tracked_physical_replay'
        evidence_class = 'synthetic_checker_fixture'
        debugger_writes = $false
        classification = 'Synthetic checker fixture for the larger-replacement offline verifier. This is not natural execution evidence.'
    }
    Write-JsonFile (Join-Path $Directory 'session-metadata.json') $metadata 40

    $events = New-Events $sessionId $script:BuiltSha256 $mapSha $buildHash $luaSha $script:MameSha256 $script:OriginalSha256
    $eventLines = New-Object 'System.Collections.Generic.List[string]'
    foreach ($record in $events.records) { $eventLines.Add((ConvertTo-Json -InputObject $record -Depth 20 -Compress)) }
    [IO.File]::WriteAllText((Join-Path $Directory 'events.jsonl'),(($eventLines -join "`n") + "`n"),$script:Utf8)
    [IO.File]::WriteAllText((Join-Path $Directory 'input-levels.csv'),(New-InputLevels $events.stopTimes.ToArray()),$script:Utf8)

    $debugLines = New-Object 'System.Collections.Generic.List[string]'
    $debugLines.Add('MAME debugger synthetic fixture')
    for ($stop = 1; $stop -le ($script:Phases.Count + 1); $stop++) { $debugLines.Add("Stopped at breakpoint $stop") }
    [IO.File]::WriteAllText((Join-Path $Directory 'debug.log'),(($debugLines -join "`n") + "`n"),$script:Utf8)
    [IO.File]::WriteAllText((Join-Path $Directory 'exit-code.txt'),'0',$script:Utf8)
    Write-JsonFile (Join-Path $Directory 'run-record.json') ([ordered]@{
        commandId='synthetic-offline-fixture'
        description='Synthetic checker fixture; not a MAME run.'
        exitCode=0
        timedOut=$false
        wallSeconds=0
        timeoutSeconds=600
    }) 8
    [IO.File]::WriteAllText((Join-Path $Directory 'session-complete.txt'),("reason=larger_replacement_complete_with_successor`nobserved=17`nexpected=17`nobservedTotal=18`nbaseComplete=True`nsuccessorObserved=True`ncalleeExitWord=0001`nresultWord=0000`ndpAvailable=True`nemulatedTime={0}`nwallSeconds=1`n" -f ('{0:F9}' -f $events.stopTimes[$events.stopTimes.Count - 1])),$script:Utf8)
    [IO.File]::WriteAllText((Join-Path $Directory 'ready.txt'),"protocol=$($script:Protocol)`nsession=$sessionId`nmap=ok`n",$script:Utf8)
    return [ordered]@{ directory=$Directory; sessionId=$sessionId; events=$events }
}

function Invoke-Verify {
    param([string]$Run)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:Tool -Mode Verify -RunDirectory $Run -BuiltRom $BuiltRom -SourceMapPath $SourceMapPath -BuildReportPath $BuildReportPath -OriginalRom $OriginalRom -ReplayPath $ReplayPath -InputLuaPath $InputLuaPath 2>&1
        $exit = $LASTEXITCODE
        $text = ($output | Out-String)
    }
    finally { $ErrorActionPreference = $previous }
    $json = $null
    try { $json = $text | ConvertFrom-Json -ErrorAction Stop } catch {}
    return [ordered]@{ exitCode=$exit; text=$text; json=$json }
}

function Assert-VerifyAccept {
    param([string]$Run,[string]$Label)
    $result = Invoke-Verify $Run
    Assert-Equal $result.exitCode 0 "$Label verifies offline"
    Assert-True ($null -ne $result.json) "$Label returns a JSON summary"
    if ($null -ne $result.json) {
        Assert-Equal $result.json.status 'synthetic_fixture_complete_larger_replacement_with_optional_successor' "$Label reports the synthetic status"
        Assert-Equal $result.json.complete $true "$Label reports all seventeen base phases complete"
        Assert-Equal $result.json.phases 18 "$Label reports seventeen base phases plus the optional successor"
        Assert-Equal $result.json.basePhases 17 "$Label reports seventeen base phases"
        Assert-Equal $result.json.successorObserved $true "$Label records the optional successor"
        Assert-Equal $result.json.mameExitCode 0 "$Label records MAME exit 0"
        Assert-Equal $result.json.mameTimedOut $false "$Label records no MAME timeout"
        Assert-Equal $result.json.calleeExitWord '0001' "$Label records the callee exit 0001"
        Assert-Equal $result.json.resultWord '0000' "$Label records the post-75A9 normalized result 0000"
        Assert-Equal $result.json.dpStatus 'measured_live_cpu_state_dp' "$Label records directly measured DP"
    }
}

function Assert-VerifyReject {
    param([string]$Run,[string]$Label,[string]$Pattern = '')
    $result = Invoke-Verify $Run
    $rejected = ($result.exitCode -ne 0) -or ($null -eq $result.json) -or ($result.json.complete -ne $true) -or ([string]$result.json.status -notmatch '^synthetic_fixture_complete_')
    Assert-True $rejected "$Label is rejected or is not complete evidence"
    if (![string]::IsNullOrWhiteSpace($Pattern) -and $result.exitCode -ne 0) {
        Assert-True ($result.text -match $Pattern) "$Label reports the expected rejection reason"
    }
}

function Copy-Fixture {
    param([string]$Source,[string]$Name)
    $destination = Join-Path $OutputRoot $Name
    if (Test-Path -LiteralPath $destination) { throw "Negative fixture already exists: $destination" }
    Copy-Item -LiteralPath $Source -Destination $destination -Recurse -ErrorAction Stop
    $metadataPath = Join-Path $destination 'session-metadata.json'
    $metadata = Read-JsonFile $metadataPath
    $metadata.source_map.path = [IO.Path]::GetFullPath((Join-Path $destination 'larger-replacement-source-map.json'))
    $metadata.build_report.path = [IO.Path]::GetFullPath((Join-Path $destination 'build-report.json'))
    $metadata.run_rom_before.path = [IO.Path]::GetFullPath((Join-Path $destination 'roms/m4addr/a6ls.p1'))
    $metadata.lua.capturedPath = [IO.Path]::GetFullPath((Join-Path $destination 'IlLargerReplacementNatural.lua'))
    $metadata.input_replay.path = [IO.Path]::GetFullPath((Join-Path $destination 'replay-actions.csv'))
    $metadata.input_replay.input_lua_path = [IO.Path]::GetFullPath((Join-Path $destination 'input.lua'))
    Write-JsonFile $metadataPath $metadata 40
    return $destination
}

function Get-EventRecords([string]$Run) {
    $list = New-Object 'System.Collections.Generic.List[object]'
    foreach ($line in Get-Content -LiteralPath (Join-Path $Run 'events.jsonl')) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $list.Add(($line | ConvertFrom-Json -ErrorAction Stop))
    }
    return ,$list
}
function Write-EventRecords([string]$Run,$Records) {
    $lines = New-Object 'System.Collections.Generic.List[string]'
    foreach ($record in $Records) { $lines.Add((ConvertTo-Json -InputObject $record -Depth 20 -Compress)) }
    [IO.File]::WriteAllText((Join-Path $Run 'events.jsonl'),(($lines -join "`n") + "`n"),$script:Utf8)
}
function Edit-PhaseEvent([string]$Run,[string]$Name,[scriptblock]$Mutation) {
    $records = Get-EventRecords $Run
    $changed = $false
    foreach ($record in $records) {
        if ([string]$record.event -eq 'phase' -and [string]$record.phase -eq $Name) {
            & $Mutation $record
            $changed = $true
        }
    }
    if (-not $changed) { throw "No phase event named $Name" }
    Write-EventRecords $Run $records
}
function Edit-CompleteEvent([string]$Run,[scriptblock]$Mutation) {
    $records = Get-EventRecords $Run
    $changed = $false
    foreach ($record in $records) {
        if ([string]$record.event -eq 'session_complete') { & $Mutation $record; $changed = $true }
    }
    if (-not $changed) { throw 'No session_complete event' }
    Write-EventRecords $Run $records
}
function Edit-Metadata([string]$Run,[scriptblock]$Mutation) {
    $path = Join-Path $Run 'session-metadata.json'
    $metadata = Read-JsonFile $path
    & $Mutation $metadata
    Write-JsonFile $path $metadata 40
}
function Edit-Json([string]$Path,[scriptblock]$Mutation) {
    $json = Read-JsonFile $Path
    & $Mutation $json
    Write-JsonFile $Path $json 40
}

$positiveRun = $null
try {
    Assert-True (Test-Path -LiteralPath $script:Tool -PathType Leaf) 'capture/analyze/verify wrapper exists'
    Assert-True (Test-Path -LiteralPath $script:Lua -PathType Leaf) 'read-only Lua observer exists'
    Assert-True (Test-Path -LiteralPath $script:JsonHelper -PathType Leaf) 'strict JSON helper exists'
    Assert-True (Test-Path -LiteralPath $OriginalRom -PathType Leaf) 'strict original ROM exists'
    Assert-True (Test-Path -LiteralPath $BuiltRom -PathType Leaf) 'repaired larger-replacement ROM exists'
    Assert-Equal (Get-Sha256 $BuiltRom) $script:BuiltSha256 'repaired larger-replacement ROM hash is exact'
    Assert-Equal (Get-Sha256 $OriginalRom) $script:OriginalSha256 'original ROM hash is exact'
    Assert-Equal (Get-Sha256 $SourceMapPath) $script:MapSha256 'source map hash is exact'
    Assert-Equal (Get-Sha256 $BuildReportPath) $script:ReportSha256 'build report hash is exact'
    Assert-Equal (Get-Sha256 $ReplayPath) $script:ReplaySha256 'tracked replay hash is exact'
    Assert-Equal (Get-Sha256 $InputLuaPath) $script:InputLuaSha256 'tracked input Lua hash is exact'

    $luaText = Get-Content -LiteralPath $script:Lua -Raw
    $toolText = Get-Content -LiteralPath $script:Tool -Raw
    Assert-True ($luaText -match 'cpu\.debug:bpset') 'observer uses native debugger breakpoints'
    Assert-True ($luaText -match 'emu\.register_periodic') 'periodic callback is only the stopped-state driver'
    Assert-True ($luaText -match 'boundarySource = "native_debugger_bpset"') 'observer labels boundaries as native debugger breaks'
    Assert-True ($luaText -match 'cpu\.state\["DP"\]') 'observer samples cpu.state DP directly'
    Assert-True ($luaText -match 'dpRaw' -and $luaText -match 'dpNormalizedMask') 'observer records DP raw and normalized fields'
    Assert-True ($luaText -notmatch 'mem:write|:write_u8|:write_u16|state\[[^\]]+\]\.value\s*=') 'observer has no memory or register writes'
    Assert-True ($luaText -notmatch 'field:set_value|MPU4_REPLAY') 'observer does not inject inputs'
    Assert-True ($luaText -notmatch '(?i)playback|:save\b|:load\b') 'observer has no save/load state path'
    Assert-True ($luaText -match 'tracked_physical_replay') 'observer requires the tracked physical input policy'
    Assert-True ($luaText -match 'controlStack0') 'observer records live control-stack words'
    Assert-True ($luaText -match 'savedCursor') 'observer records the live saved cursor'
    Assert-True ($luaText -match 'post-75a9-successor' -or $toolText -match 'post-75a9-successor') 'optional post-75A9 successor is explicitly represented'
    Assert-True ($luaText -notmatch 'fields\.h\s*=|fields\["h"\]|\\"h\\"\s*:') 'observer does not output an H field'
    $mapText = Get-LargerMapLuaText
    foreach ($token in @('0x1010','0x1012','0x1014','0x101A','0x1020','0x1024','0x7931','0x9F14','0x9F16','0x9F18','0x75A9','0x7B7D')) {
        Assert-True ($mapText -match [regex]::Escape($token)) "phase map binds boundary $token"
    }
    Assert-True ($toolText -match "ValidateSet\('Capture','Analyze','Verify'\)") 'wrapper exposes Capture, Analyze and Verify modes'
    Assert-True ($toolText -match '-noreadconfig') 'wrapper launches MAME without reading configuration'
    Assert-True ($toolText -match "'-debugger','imgui'") 'wrapper pins the accepted imgui debugger'
    Assert-True ($toolText -match "'-video','bgfx'") 'wrapper pins the BGFX renderer'
    Assert-True ($toolText -match 'Get-LargerAnalysis') 'wrapper has a reusable offline checker path'
    Assert-True ($toolText -match 'Test-IlEventJson\.ps1') 'wrapper uses the strict JSON helper'
    Assert-True ($toolText -match 'Test-LargerMapContract') 'wrapper validates the exact source-map binding'
    Assert-True ($toolText -match 'Write-CaptureFailure') 'wrapper preserves a failed single-capture record'
    Assert-True ($toolText -match 'Invoke-StrictDuplicateKeyCheck') 'wrapper rejects duplicate JSON keys'
    Assert-True ($toolText -match 'larger-replacement-map\.lua') 'wrapper binds the run-local map Lua'

    $fixture = New-Fixture (Join-Path $OutputRoot 'positive-synthetic')
    $positiveRun = $fixture.directory
    Write-JsonFile -Path (Join-Path $positiveRun 'arguments.json') -Object @(New-ValidInvocationArguments $positiveRun) -Depth 6
    Assert-VerifyAccept $positiveRun 'synthetic positive fixture'
    Assert-True ($fixture.events.stopTimes.Count -eq 18) 'synthetic positive fixture has eighteen distinct stop times'
    $strict = Get-Content -LiteralPath (Join-Path $positiveRun 'events.jsonl') -Raw
    Assert-True ($strict -notmatch ',\s*[}\]]') 'synthetic event JSON has no trailing commas'

    $beforeEvents = Get-Sha256 (Join-Path $positiveRun 'events.jsonl')
    $positiveAnalysis = Get-LargerAnalysis -Run $positiveRun -BuiltPath '' -SourceMapPath '' -BuildReportPath '' -OriginalPath '' -ReanalysisSourceRun ''
    $afterEvents = Get-Sha256 (Join-Path $positiveRun 'events.jsonl')
    Assert-Equal $beforeEvents $afterEvents 'Verify/Analyze does not modify the raw events'
    Assert-Equal $positiveAnalysis.registerEvidence.dp.directObservation $true 'analysis records a direct DP measurement'
    Assert-Equal $positiveAnalysis.registerEvidence.dp.status 'measured_live_cpu_state_dp' 'analysis records DP as measured'
    Assert-Equal $positiveAnalysis.supervisorAcceptance.status 'not_claimed' 'analysis does not claim supervisor acceptance'
    Assert-True ($null -eq $positiveAnalysis.mameInvocation) 'synthetic fixture is not treated as a natural MAME invocation'
    Assert-Equal $positiveAnalysis.call.calleeExitWord '0001' 'analysis records the observed callee exit 0001'
    Assert-Equal $positiveAnalysis.call.resultWord '0000' 'analysis records the optional successor result 0000'
    Assert-Equal $positiveAnalysis.parentResult.claim 'not_claimed' 'analysis does not claim the parent result'
    Assert-Equal $positiveAnalysis.session.basePhaseCountObserved 17 'analysis separates seventeen base phases from the optional successor'
    Assert-Equal $positiveAnalysis.session.successorObserved $true 'analysis records the optional successor separately'
    $validInvocation = Assert-MameInvocationIsolation $positiveRun
    Assert-Equal $validInvocation.launchRunDirectory ([IO.Path]::GetFullPath($positiveRun).TrimEnd('\')) 'valid isolated MAME invocation is accepted'

    function Test-InvocationReject([string]$Label,[scriptblock]$Mutation,[string]$Pattern) {
        $temp = Join-Path $OutputRoot ('invocation-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $temp -Force | Out-Null
        $list = New-Object 'System.Collections.Generic.List[string]'
        $sourceArguments = Read-JsonFile (Join-Path $positiveRun 'arguments.json')
        foreach ($item in $sourceArguments) { $list.Add([string]$item) }
        $sourcePrefix = [IO.Path]::GetFullPath($positiveRun).TrimEnd('\')
        $targetPrefix = [IO.Path]::GetFullPath($temp).TrimEnd('\')
        for ($i = 0; $i -lt $list.Count; $i++) { $list[$i] = $list[$i].Replace($sourcePrefix,$targetPrefix) }
        & $Mutation $list
        Write-JsonFile -Path (Join-Path $temp 'arguments.json') -Object $list.ToArray() -Depth 6
        $threw = $false
        $message = ''
        try { Assert-MameInvocationIsolation $temp | Out-Null } catch { $threw = $true; $message = $_.Exception.Message }
        Assert-True $threw "$Label is rejected by the MAME invocation guard"
        if ($threw -and -not [string]::IsNullOrWhiteSpace($Pattern)) { Assert-True ($message -match $Pattern) "$Label reports the expected invocation rejection" }
    }
    Test-InvocationReject 'playback input' { param($a) $a.Add('-playback') } 'forbidden -playback'
    Test-InvocationReject 'save-state load' { param($a) $a.Add('-state') } 'forbidden -state'
    Test-InvocationReject 'missing -noreadconfig' { param($a) [void]$a.Remove('-noreadconfig') } 'missing -noreadconfig'
    Test-InvocationReject 'external first ROM path' { param($a) $index = $a.IndexOf('-rompath'); $a[$index + 1] = 'E:\Arcade\MAME0266\roms' } 'first ROM path'
    Test-InvocationReject 'non-isolated cfg directory' { param($a) $index = $a.IndexOf('-cfg_directory'); $a[$index + 1] = 'C:\Windows\Temp\cfg' } 'cfg_directory'

    $builtBytes = [IO.File]::ReadAllBytes($BuiltRom)
    $originalBytes = [IO.File]::ReadAllBytes($OriginalRom)
    $baseMap = Read-JsonFile $SourceMapPath
    $baseBuild = Read-JsonFile $BuildReportPath
    function Test-MapReject([string]$Label,[scriptblock]$Mutation,[string]$Pattern) {
        $mapCopy = $baseMap | ConvertTo-Json -Depth 40 | ConvertFrom-Json
        & $Mutation $mapCopy
        $threw = $false
        $message = ''
        try { Test-LargerMapContract $mapCopy $baseBuild $builtBytes $originalBytes | Out-Null }
        catch { $threw = $true; $message = $_.Exception.Message }
        Assert-True $threw "$Label is rejected by the map contract"
        if ($threw -and -not [string]::IsNullOrWhiteSpace($Pattern)) { Assert-True ($message -match $Pattern) "$Label reports the expected map rejection" }
    }
    Test-MapReject 'native header 1012' { param($m) $m.HeaderHex = '1012' } 'header'
    Test-MapReject 'old composite body' { param($m) $m.BodyEndExclusive = 0x1020 } 'body end'
    Test-MapReject 'wrong added operand' { param($m) $m.Nodes[4].OperandValue = 0x0002 } 'operand value'
    Test-MapReject 'early task48 return' { param($m) $m.Nodes[6].Address = 0x101E } 'node 6 address'
    Test-MapReject 'wrong phase name' { param($m) $m.Phases[2].Phase = 'body-prefetch-x' } 'phase 2'
    Test-MapReject 'wrong phase PC' { param($m) $m.Phases[2].Pc = 0x1015 } 'PC is|phase .* PC'
    Test-MapReject 'wrong phase Y' { param($m) $m.Phases[1].Y = 0x9F18 } 'Y is|phase .* Y'
    Test-MapReject 'wrong phase token' { param($m) $m.Phases[14].Token = 0x792E } 'token is|phase .* token'
    Test-MapReject 'null phase X' { param($m) $m.Phases[1].X = $null } 'X is null'
    Test-MapReject 'wrong static vector' { param($m) $m.StaticContract.Vectors[0].CalleeExit = 2 } 'vector 0 callee exit'
    Test-MapReject 'wrong whole-call S net' { param($m) $m.Semantics.WholeCallSNet = 2 } 'whole-call S net'

    $neg = Copy-Fixture $positiveRun 'wrong-run-rom'
    $rom = [IO.File]::ReadAllBytes((Join-Path $neg 'roms/m4addr/a6ls.p1'))
    $rom[0x1012] = $rom[0x1012] -bxor 0xFF
    [IO.File]::WriteAllBytes((Join-Path $neg 'roms/m4addr/a6ls.p1'),$rom)
    Assert-VerifyReject $neg 'mutated run ROM' 'run ROM'

    $neg = Copy-Fixture $positiveRun 'wrong-image-metadata'
    Edit-Metadata $neg { param($m) $m.built_rom.sha256 = ('0' * 64) }
    Assert-VerifyReject $neg 'wrong image metadata' 'built ROM|image identity'

    $neg = Copy-Fixture $positiveRun 'wrong-source-map'
    Add-Content -LiteralPath (Join-Path $neg 'larger-replacement-source-map.json') -Value ' '
    Assert-VerifyReject $neg 'wrong source map hash' 'Source map SHA256'

    $neg = Copy-Fixture $positiveRun 'wrong-build-report'
    Edit-Json (Join-Path $neg 'build-report.json') { param($b) $b.repaired.sha256 = ('0' * 64) }
    Assert-VerifyReject $neg 'wrong build report' 'build report|Build report'

    $neg = Copy-Fixture $positiveRun 'wrong-map-lua'
    Add-Content -LiteralPath (Join-Path $neg 'larger-replacement-map.lua') -Value '-- changed'
    Assert-VerifyReject $neg 'wrong run-local map Lua' 'larger-replacement-map'

    $neg = Copy-Fixture $positiveRun 'wrong-config'
    Edit-Json (Join-Path $neg 'session-config.json') { param($c) $c.expectedImageSha256 = ('0' * 64) }
    Assert-VerifyReject $neg 'wrong session config' 'session-config|config'

    $neg = Copy-Fixture $positiveRun 'wrong-observer'
    Add-Content -LiteralPath (Join-Path $neg 'observer.lua') -Value '-- changed'
    Assert-VerifyReject $neg 'wrong observer composition' 'observer'

    $neg = Copy-Fixture $positiveRun 'wrong-input-lua'
    Add-Content -LiteralPath (Join-Path $neg 'input.lua') -Value '-- changed'
    Assert-VerifyReject $neg 'wrong input Lua' 'input Lua'

    $neg = Copy-Fixture $positiveRun 'wrong-replay'
    Add-Content -LiteralPath (Join-Path $neg 'replay-actions.csv') -Value '9999,9999,:AUX2,128,extra,  000,0,0'
    Assert-VerifyReject $neg 'wrong replay fixture' 'replay'

    $neg = Copy-Fixture $positiveRun 'wrong-phase-pc'
    Edit-PhaseEvent $neg 'body-prefetch-0' { param($e) $e.pc = '00FD' }
    Assert-VerifyReject $neg 'wrong phase PC' 'phase PC|PC'

    $neg = Copy-Fixture $positiveRun 'wrong-phase-y'
    Edit-PhaseEvent $neg 'handler-1' { param($e) $e.y = '9F18' }
    Assert-VerifyReject $neg 'wrong phase Y' 'phase Y|Y '

    $neg = Copy-Fixture $positiveRun 'wrong-phase-x'
    Edit-PhaseEvent $neg 'handler-2' { param($e) $e.x = '795E' }
    Assert-VerifyReject $neg 'wrong phase X' 'phase X|X '

    $neg = Copy-Fixture $positiveRun 'wrong-phase-u'
    Edit-PhaseEvent $neg 'body-prefetch-5' { param($e) $e.u = '066E' }
    Assert-VerifyReject $neg 'wrong phase U' 'phase U|U '

    $neg = Copy-Fixture $positiveRun 'wrong-phase-s'
    Edit-PhaseEvent $neg 'return-handler' { param($e) $e.s = '0798' }
    Assert-VerifyReject $neg 'wrong phase S' 'phase S|S '

    $neg = Copy-Fixture $positiveRun 'wrong-phase-top'
    Edit-PhaseEvent $neg 'body-prefetch-5' { param($e) $e.dataStack0 = '0000' }
    Assert-VerifyReject $neg 'wrong phase top' 'top stack|top'

    $neg = Copy-Fixture $positiveRun 'wrong-added-literal-top'
    Edit-PhaseEvent $neg 'body-prefetch-5' { param($e) $e.dataStack1 = '0001' }
    Assert-VerifyReject $neg 'wrong next data cell after the added literal' 'second data stack|dataStack1'

    $neg = Copy-Fixture $positiveRun 'wrong-phase-d'
    Edit-PhaseEvent $neg 'body-prefetch-5' { param($e) $e.d = '0000'; $e.a = '00'; $e.b = '00' }
    Assert-VerifyReject $neg 'wrong phase D' 'phase D|D '

    $neg = Copy-Fixture $positiveRun 'wrong-inline-operand'
    Edit-PhaseEvent $neg 'handler-4' { param($e) $e.inlineOperand = '0002' }
    Assert-VerifyReject $neg 'wrong added inline operand' 'inline operand'

    $neg = Copy-Fixture $positiveRun 'wrong-control-top'
    Edit-PhaseEvent $neg 'body-prefetch-0' { param($e) $e.controlStack0 = '9F3F' }
    Assert-VerifyReject $neg 'wrong control top' 'control stack top|9F3F'

    $neg = Copy-Fixture $positiveRun 'wrong-saved-cursor'
    Edit-PhaseEvent $neg 'return-handler' { param($e) $e.savedCursor = '9F3F' }
    Assert-VerifyReject $neg 'wrong saved cursor' 'saved cursor'

    $neg = Copy-Fixture $positiveRun 'invented-saved-cursor'
    Edit-PhaseEvent $neg 'header-trampoline-entry' { param($e) $e.savedCursor = '9F16' }
    Assert-VerifyReject $neg 'invented saved cursor on the pre-PSHS trampoline phase' 'saved cursor'

    $neg = Copy-Fixture $positiveRun 'missing-control-field'
    Edit-PhaseEvent $neg 'handler-0' { param($e) $e.PSObject.Properties.Remove('controlStack0') }
    Assert-VerifyReject $neg 'missing control-stack field' 'controlStack0|missing'

    $neg = Copy-Fixture $positiveRun 'null-phase-field'
    Edit-PhaseEvent $neg 'handler-0' { param($e) $e.token = $null }
    Assert-VerifyReject $neg 'null phase token field' 'token|missing'

    $neg = Copy-Fixture $positiveRun 'h-output'
    Edit-PhaseEvent $neg 'handler-0' { param($e) $e | Add-Member -NotePropertyName h -NotePropertyValue '00' -Force }
    Assert-VerifyReject $neg 'H output assertion' 'H field'

    $neg = Copy-Fixture $positiveRun 'missing-dp-field'
    Edit-PhaseEvent $neg 'handler-0' { param($e) $e.PSObject.Properties.Remove('dpRaw') }
    Assert-VerifyReject $neg 'missing DP raw field' 'DP field|dpRaw|missing'

    $neg = Copy-Fixture $positiveRun 'inconsistent-dp-field'
    Edit-PhaseEvent $neg 'handler-0' { param($e) $e.dp = '05' }
    Assert-VerifyReject $neg 'DP inconsistent with raw value' 'normalized raw value|DP'

    $neg = Copy-Fixture $positiveRun 'dp-unavailable'
    Edit-PhaseEvent $neg 'handler-0' { param($e) $e.dpAvailable = 'false'; $e.dpRaw = ''; $e.dp = ''; $e.dpWidthBits = ''; $e.dpWidthSource = '' }
    Assert-VerifyReject $neg 'DP unavailable is not accepted as a complete natural proof' 'DP|dpAvailability|unavailable'

    $neg = Copy-Fixture $positiveRun 'reordered-phases'
    $records = Get-EventRecords $neg
    $phaseRecords = @($records | Where-Object { [string]$_.event -eq 'phase' })
    $temp = $phaseRecords[1].phase
    $phaseRecords[1].phase = $phaseRecords[2].phase
    $phaseRecords[2].phase = $temp
    Write-EventRecords $neg $records
    Assert-VerifyReject $neg 'reordered phases' 'Phase 1|Phase 2|expected'

    $neg = Copy-Fixture $positiveRun 'extra-phase-event'
    $records = Get-EventRecords $neg
    $records.Add(($records | Where-Object { [string]$_.event -eq 'phase' } | Select-Object -Last 1))
    Write-EventRecords $neg $records
    Assert-VerifyReject $neg 'extra phase event' 'session_complete|phase records|expected|strictly increasing'

    $neg = Copy-Fixture $positiveRun 'unknown-event'
    $records = Get-EventRecords $neg
    $records.Insert(1, [ordered]@{ event='probe'; value='1' })
    Write-EventRecords $neg $records
    Assert-VerifyReject $neg 'unexpected event type' 'unexpected event'

    $neg = Copy-Fixture $positiveRun 'partial-completion'
    $records = Get-EventRecords $neg
    $phaseRecords = @($records | Where-Object { [string]$_.event -eq 'phase' })
    [void]$records.Remove($phaseRecords[$phaseRecords.Count - 1])
    Write-EventRecords $neg $records
    Assert-VerifyReject $neg 'completion claim with a missing phase' 'without all ordered base phases|completion'

    $neg = Copy-Fixture $positiveRun 'forged-callee-exit'
    Edit-CompleteEvent $neg { param($e) $e.calleeExitWord = '0002' }
    Assert-VerifyReject $neg 'forged callee exit word' 'callee exit word'

    $neg = Copy-Fixture $positiveRun 'forged-result-word'
    Edit-CompleteEvent $neg { param($e) $e.resultWord = '0001' }
    Assert-VerifyReject $neg 'forged post-75A9 result word' 'result word'

    $neg = Copy-Fixture $positiveRun 'forged-run-exit'
    Edit-Json (Join-Path $neg 'run-record.json') { param($r) $r.exitCode = 1 }
    Assert-VerifyReject $neg 'forged MAME exit code' 'exit code'

    $neg = Copy-Fixture $positiveRun 'forged-run-timeout'
    Edit-Json (Join-Path $neg 'run-record.json') { param($r) $r.timedOut = $true }
    Assert-VerifyReject $neg 'forged MAME timeout' 'timeout'

    $neg = Copy-Fixture $positiveRun 'state-file-present'
    [IO.File]::WriteAllText((Join-Path $neg 'state/forbidden.sta'),'not a state')
    Assert-VerifyReject $neg 'state file present' 'State directory'

    $neg = Copy-Fixture $positiveRun 'side-effect-snapshot-file'
    [IO.File]::WriteAllText((Join-Path $neg 'snap/forbidden.png'),'not a snapshot')
    Assert-VerifyReject $neg 'side-effect snapshot file' 'Side-effect directory snap|snap'

    $neg = Copy-Fixture $positiveRun 'malformed-input-row'
    $lines = Get-Content -LiteralPath (Join-Path $neg 'input-levels.csv')
    $lines[10] = 'not,a,valid,row'
    [IO.File]::WriteAllLines((Join-Path $neg 'input-levels.csv'),$lines,$script:Utf8)
    Assert-VerifyReject $neg 'malformed input row' 'malformed|input-levels'

    $neg = Copy-Fixture $positiveRun 'nonmonotonic-input-time'
    $lines = Get-Content -LiteralPath (Join-Path $neg 'input-levels.csv')
    $lines[10] = '10,0.000000000,00,00,0'
    [IO.File]::WriteAllLines((Join-Path $neg 'input-levels.csv'),$lines,$script:Utf8)
    Assert-VerifyReject $neg 'nonmonotonic input time' 'not strictly increasing|nonmonotonic'

    $neg = Copy-Fixture $positiveRun 'duplicate-input-frame'
    $lines = Get-Content -LiteralPath (Join-Path $neg 'input-levels.csv')
    $lines[10] = $lines[9]
    [IO.File]::WriteAllLines((Join-Path $neg 'input-levels.csv'),$lines,$script:Utf8)
    Assert-VerifyReject $neg 'duplicate input frame' 'not strictly increasing|duplicate'

    $neg = Copy-Fixture $positiveRun 'offwindow-coin-input'
    $lines = Get-Content -LiteralPath (Join-Path $neg 'input-levels.csv')
    $lines[100] = '100,1.650000000,80,00,1'
    [IO.File]::WriteAllLines((Join-Path $neg 'input-levels.csv'),$lines,$script:Utf8)
    Assert-VerifyReject $neg 'off-window coin activity' 'coin-active|coin activity'

    $neg = Copy-Fixture $positiveRun 'extra-start-activity'
    $lines = Get-Content -LiteralPath (Join-Path $neg 'input-levels.csv')
    $lines[100] = '100,1.650000000,00,80,0'
    [IO.File]::WriteAllLines((Join-Path $neg 'input-levels.csv'),$lines,$script:Utf8)
    Assert-VerifyReject $neg 'extra start activity outside the window' 'start-active|start window'

    $neg = Copy-Fixture $positiveRun 'invented-stop-context'
    $debug = Get-Content -LiteralPath (Join-Path $neg 'debug.log')
    $debug = @($debug | Select-Object -First ($debug.Count - 1))
    [IO.File]::WriteAllLines((Join-Path $neg 'debug.log'),$debug,$script:Utf8)
    Assert-VerifyReject $neg 'missing debugger stop context' 'debugger stop|phase debugger|off-grid'

    $neg = Copy-Fixture $positiveRun 'replay-coin-window'
    $lines = Get-Content -LiteralPath (Join-Path $neg 'input-levels.csv')
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^2103,') { $lines[$i] = '2103,35.033333333,00,00,0' }
    }
    [IO.File]::WriteAllLines((Join-Path $neg 'input-levels.csv'),$lines,$script:Utf8)
    Assert-VerifyReject $neg 'coin window missing 2103' 'coin activity|coin-active'

    $neg = Copy-Fixture $positiveRun 'extra-coin-activity'
    $lines = Get-Content -LiteralPath (Join-Path $neg 'input-levels.csv')
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^2104,') { $lines[$i] = '2104,35.050000000,80,00,1' }
    }
    [IO.File]::WriteAllLines((Join-Path $neg 'input-levels.csv'),$lines,$script:Utf8)
    Assert-VerifyReject $neg 'extra coin override activity' 'coin activity|coin-active'

    $neg = Copy-Fixture $positiveRun 'ab-d-mismatch'
    Edit-PhaseEvent $neg 'handler-0' { param($e) $e.a = '81' }
    Assert-VerifyReject $neg 'D inconsistent with live A/B' 'live A/B|A/B'

    $neg = Copy-Fixture $positiveRun 'duplicate-json-key'
    $eventPath = Join-Path $neg 'events.jsonl'
    $eventText = [IO.File]::ReadAllText($eventPath)
    $needle = '"pc":"00FC"'
    if ([regex]::Matches($eventText,[regex]::Escape($needle)).Count -lt 1) { throw 'Duplicate-key fixture needle is not present' }
    $eventText = [regex]::Replace($eventText, [regex]::Escape($needle), '"pc":"00FC","pc":"00FD"', 1)
    [IO.File]::WriteAllText($eventPath,$eventText,$script:Utf8)
    Assert-VerifyReject $neg 'duplicate JSON key' 'duplicate'

    Assert-True ($script:Failures -eq 0) "offline checker negative controls all behaved as expected ($($script:Checks) checks)"
}
catch {
    Write-Fail ("unexpected verifier exception: " + $_.Exception.Message)
}
finally {
    Write-Output ("SUMMARY: checks={0} failures={1} outputRoot={2} positiveRun={3}" -f $script:Checks,$script:Failures,$OutputRoot,$positiveRun)
    if ($script:Failures -ne 0) { exit 1 }
    exit 0
}

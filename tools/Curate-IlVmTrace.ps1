[CmdletBinding()]
param(
    [string]$OriginalRunDirectory,
    [string]$ChangedRunDirectory,
    [string]$OriginalRom,
    [string]$RepairedRom,
    [string]$SourceMapPath,
    [string]$BuildReportPath,
    [string]$PlanPath,
    [string]$ReplayPath,
    [string]$OutputPath,
    [switch]$RequireBoundaryTrace,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'

$script:LtOriginalSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$script:LtOriginalSha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
$script:LtRepairedSha1 = 'e1a42dccd304b7b175aabac99e8400cdad04cf69'
$script:LtRepairedSha256 = '577f76bd36dfca04dfb01b5f5d0be93e16572f8617c7ca906397c98df36e5107'
$script:LtSourceMapSha256 = '0c39a6d0d1beac32ca0f64bfec5ce848b2297be41180d0234d2bfdf491df21a9'
$script:LtBuildReportSha256 = 'ae7e0fb2c0121e0b4e62d38e82511841644fcdf922b2d9e54de79b3d7e57f61a'
$script:LtReplaySha256 = '4a051da15264842697879eff396b34a789f5d80623f9a2e749c244e6a80e721d'
$script:LtMameSha256 = '0fce5a88df4f9d9b1fbf1405812c00848036e615993780978d967da34204cb7a'
$script:LtExpectedChangedOffsets = @(0x9EDC,0xFFD1,0xFFD2,0xFFD3,0xFFD4,0xFFD5)
$script:LtRoot = Split-Path $PSScriptRoot -Parent
if ([string]::IsNullOrWhiteSpace($SourceMapPath)) { $SourceMapPath = Join-Path $script:LtRoot 'artifacts/deepseek/il-boot-04/build-01/source-map.json' }
if ([string]::IsNullOrWhiteSpace($BuildReportPath)) { $BuildReportPath = Join-Path $script:LtRoot 'artifacts/deepseek/il-boot-04/build-01/build-report.json' }
if ([string]::IsNullOrWhiteSpace($PlanPath)) { $PlanPath = Join-Path $script:LtRoot 'evidence/mpu4/integrity/il-natural-reachability-plan.json' }
if ([string]::IsNullOrWhiteSpace($ReplayPath)) { $ReplayPath = Join-Path $script:LtRoot 'evidence/mpu4/skill-cash/actions.csv' }
$script:LtPlanPath = $PlanPath

function Get-LtHash {
    param([string]$Path,[string]$Algorithm)
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        try { return ([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Read-LtJson {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing JSON: $Path" }
    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function Write-LtJson {
    param([string]$Path,$Object,[int]$Depth=18)
    [IO.File]::WriteAllText($Path,(ConvertTo-Json -InputObject $Object -Depth $Depth),(New-Object System.Text.UTF8Encoding($false)))
}

function ConvertTo-LtInt {
    param([string]$Text)
    return [Convert]::ToInt32($Text,16)
}

function Format-LtOffsets {
    param([int[]]$Offsets)
    return (($Offsets | ForEach-Object { '{0:X4}' -f $_ }) -join ',')
}

function Get-LtChangedOffsets {
    param([byte[]]$A,[byte[]]$B)
    if ($A.Length -ne $B.Length) { throw 'Cannot compare different-length images' }
    $list = New-Object 'System.Collections.Generic.List[int]'
    for ($i=0;$i -lt $A.Length;$i++) { if ($A[$i] -ne $B[$i]) { [void]$list.Add($i) } }
    return $list.ToArray()
}

function Assert-LtRomFile {
    param([string]$Path,[string]$Sha1,[string]$Sha256,[string]$Label)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label is missing: $Path" }
    $length = (Get-Item -LiteralPath $Path).Length
    if ($length -ne 65536) { throw "$Label length is $length, expected 65536" }
    $actualSha1 = Get-LtHash $Path 'SHA1'
    $actualSha256 = Get-LtHash $Path 'SHA256'
    if ($actualSha1 -ine $Sha1) { throw "$Label SHA1 is $actualSha1, expected $Sha1" }
    if ($actualSha256 -ine $Sha256) { throw "$Label SHA256 is $actualSha256, expected $Sha256" }
    return [ordered]@{length=$length;sha1=$actualSha1;sha256=$actualSha256}
}

function Assert-LtArguments {
    param([string[]]$RunArgs,[string]$RunDirectory)
    $RunArgs = @($RunArgs)
    if ($RunArgs -notcontains '-noreadconfig') { throw 'Run arguments do not disable configuration reads' }
    foreach ($required in @('-debug','-debugscript','-debuglog')) {
        if ($RunArgs -notcontains $required) { throw "Run arguments do not include required option $required" }
    }
    $debuggerIndex = [Array]::IndexOf($RunArgs,'-debugger')
    if ($debuggerIndex -lt 0 -or $debuggerIndex + 1 -ge $RunArgs.Count -or $RunArgs[$debuggerIndex+1] -ne 'windows') { throw 'Run arguments do not use the native debugger console' }
    foreach ($bad in @('-playback','-state','-load','-autosave','-state_directory_load')) {
        if ($RunArgs -contains $bad) { throw "Run arguments contain forbidden option $bad" }
    }
    $romIndex = [Array]::IndexOf($RunArgs,'-rompath')
    if ($romIndex -lt 0 -or $romIndex + 1 -ge $RunArgs.Count) { throw 'Run arguments have no ROM path' }
    $runRoms = [IO.Path]::GetFullPath((Join-Path $RunDirectory 'roms'))
    if ([IO.Path]::GetFullPath($RunArgs[$romIndex+1].Split(';')[0]) -ine $runRoms) { throw 'Run arguments do not isolate the ROM path' }
    $scriptIndex = [Array]::IndexOf($RunArgs,'-debugscript')
    if ($scriptIndex -lt 0 -or $scriptIndex + 1 -ge $RunArgs.Count) { throw 'Run arguments have no debugger script' }
    if ([IO.Path]::GetFullPath($RunArgs[$scriptIndex+1]) -ine [IO.Path]::GetFullPath((Join-Path $RunDirectory 'debugger.cmd'))) { throw 'Run arguments do not use the run-local debugger script' }
    $observerIndex = [Array]::IndexOf($RunArgs,'-autoboot_script')
    if ($observerIndex -lt 0 -or $observerIndex + 1 -ge $RunArgs.Count) { throw 'Run arguments have no autoboot observer' }
    if ([IO.Path]::GetFullPath($RunArgs[$observerIndex+1]) -ine [IO.Path]::GetFullPath((Join-Path $RunDirectory 'observer.lua'))) { throw 'Run arguments do not use the run-local Lua observer' }
    $secondsIndex = [Array]::IndexOf($RunArgs,'-seconds_to_run')
    if ($secondsIndex -lt 0 -or $secondsIndex + 1 -ge $RunArgs.Count) { throw 'Run arguments have no emulated-time bound' }
    if ([int]$RunArgs[$secondsIndex+1] -gt 120) { throw 'Run arguments exceed the 120 emulated-second bound' }
}

function Assert-LtPreRun {
    param([string]$RunDirectory)
    $pre = Read-LtJson (Join-Path $RunDirectory 'pre-run-empty.json')
    foreach ($property in $pre.PSObject.Properties) {
        if ([int]$property.Value -ne 0) { throw "Pre-run directory $($property.Name) was not empty" }
    }
    $romFiles = @(Get-ChildItem -LiteralPath (Join-Path $RunDirectory 'roms/m4addr') -File | ForEach-Object { $_.Name } | Sort-Object)
    if (($romFiles -join ',') -ne 'a6ls.p1') { throw 'Isolated ROM directory does not contain exactly a6ls.p1' }
    $stateFiles = @(Get-ChildItem -LiteralPath (Join-Path $RunDirectory 'state') -Recurse -File -ErrorAction SilentlyContinue)
    if ($stateFiles.Count -ne 0) { throw 'State directory contains files; a save state may have been seeded or written' }
}

function Assert-LtVariantMap {
    param($Map,[string]$Variant,[string]$ImageSha,[string]$RomPath)
    if ($Map.schemaVersion -ne 1) { throw 'Variant map schemaVersion is not 1' }
    if ($Map.variant -ne $Variant) { throw 'Variant map variant differs from the run' }
    if ($Map.outputImageSha256 -ine $ImageSha) { throw 'Variant map image identity is stale or wrong' }
    if ($Map.originalRomSha256 -ine $script:LtOriginalSha256) { throw 'Variant map original identity is stale or wrong' }
    if ($Map.bodyStart -ne '9ED9' -or $Map.bodyEndExclusive -ne '9EE7') { throw 'Variant map body span is not 9ED9..9EE7' }
    $entries = @($Map.entries)
    if ($entries.Count -ne 14) { throw "Variant map has $($entries.Count) entries, expected 14" }
    $rom = [IO.File]::ReadAllBytes($RomPath)
    $expectedAddress = 0x9ED9
    $lastNode = -1
    foreach ($entry in $entries) {
        $address = ConvertTo-LtInt $entry.address
        if ($address -ne $expectedAddress) { throw "Variant map is not contiguous at $($entry.address)" }
        if ($entry.nodeIndex -lt $lastNode) { throw "Variant map node order is reordered at $($entry.address)" }
        if ($entry.nodeIndex -gt $lastNode) {
            if ($entry.nodeIndex -ne ($lastNode + 1)) { throw "Variant map node index gap at $($entry.address)" }
            $lastNode = $entry.nodeIndex
        }
        if ([Convert]::ToInt32($entry.imageByte,16) -ne $rom[$address]) { throw "Variant map byte at $($entry.address) differs from the run ROM" }
        $expectedAddress++
    }
    if ($expectedAddress -ne 0x9EE7) { throw 'Variant map does not cover the declared body end' }
    if ($lastNode -ne 4) { throw 'Variant map does not contain the five checked node indices 0..4' }
    $nodes = @($Map.nodes)
    if ($nodes.Count -ne 5) { throw "Variant map has $($nodes.Count) nodes, expected 5" }
    foreach ($node in $nodes) {
        $address = ConvertTo-LtInt $node.address
        $token = ConvertTo-LtInt $node.token
        $liveToken = ([int]$rom[$address] -shl 8) -bor [int]$rom[$address+1]
        if ($liveToken -ne $token) { throw "Variant map token at $($node.address) differs from the run ROM" }
        $bytes = @($node.bytes)
        for ($i=0;$i -lt $bytes.Count;$i++) {
            if ([int]$bytes[$i] -ne $rom[$address+$i]) { throw "Variant map node bytes differ at $($node.address)" }
        }
    }
}

function ConvertTo-LtEvent {
    param([string]$Line)
    if ($Line -notmatch '^EVENT\s+(\S+)\s+(.*)$') { return $null }
    $name = $Matches[1]
    $rest = $Matches[2]
    $fields = [ordered]@{ event = $name }
    foreach ($match in [regex]::Matches($rest, '([A-Za-z_][A-Za-z0-9_]*)=([0-9A-Fa-f]+)')) {
        $fields[$match.Groups[1].Value] = $match.Groups[2].Value
    }
    return $fields
}

function Read-LtBoundaryEvents {
    param([string]$DebugLogPath)
    if (!(Test-Path -LiteralPath $DebugLogPath -PathType Leaf)) { throw "debug log is missing: $DebugLogPath" }
    $events = New-Object 'System.Collections.Generic.List[object]'
    foreach ($line in Get-Content -LiteralPath $DebugLogPath) {
        $event = ConvertTo-LtEvent $line
        if ($null -ne $event) { $events.Add($event) }
    }
    return $events.ToArray()
}

function Assert-LtBoundaryClaims {
    param($Events)
    $Events = @($Events)
    if ($Events.Count -ne 11) { throw "Boundary event count $($Events.Count) differs from expected 11" }
    $expected = @(
        @{event='NODE_PREFETCH';index=0;y='9ED9'},
        @{event='HANDLER_ENTRY';index=0;y='9EDB';pc='795D';x='795D';s='0796'},
        @{event='NODE_PREFETCH';index=1;y='9EDD'},
        @{event='HANDLER_ENTRY';index=1;y='9EDF';pc='7880';x='7880';s='0796'},
        @{event='NODE_PREFETCH';index=2;y='9EDF'},
        @{event='HANDLER_ENTRY';index=2;y='9EE1';pc='795D';x='795D';s='0796'},
        @{event='NODE_PREFETCH';index=3;y='9EE3'},
        @{event='HANDLER_ENTRY';index=3;y='9EE5';pc='7AB1';x='7AB1';s='0796'},
        @{event='NODE_PREFETCH';index=4;y='9EE5'},
        @{event='RETURN_HANDLER';index=4;y='9EE7';pc='7931';x='7931';s='0796'},
        @{event='POST_RETURN_CALLER_PREFETCH';y='9F16';s='0798'}
    )
    for ($i=0;$i -lt $expected.Count;$i++) {
        $actual = $Events[$i]
        $want = $expected[$i]
        if ([string]$actual.event -ne $want.event) { throw "Boundary event $i is $($actual.event), expected $($want.event)" }
        if ($want.ContainsKey('index') -and [int]$actual.index -ne [int]$want.index) { throw "Boundary event $i index is $($actual.index), expected $($want.index)" }
        if ([string]$actual.y -ine $want.y) { throw "Boundary event $i Y is $($actual.y), expected $($want.y)" }
        if ($want.ContainsKey('pc') -and [string]$actual.pc -ine $want.pc) { throw "Boundary event $i PC is $($actual.pc), expected $($want.pc)" }
        if ($want.ContainsKey('x') -and [string]$actual.x -ine $want.x) { throw "Boundary event $i X is $($actual.x), expected $($want.x)" }
        if ($want.ContainsKey('s') -and [string]$actual.s -ine $want.s) { throw "Boundary event $i S is $($actual.s), expected $($want.s)" }
    }
    $returnEvent = $Events[9]
    $saved = [string]$returnEvent.saved_cursor
    if ([string]::IsNullOrWhiteSpace($saved)) { throw 'RETURN_HANDLER has no saved caller cursor' }
    if ([string]$Events[10].y -ine $saved) { throw "post-return Y is $($Events[10].y), expected saved caller cursor $saved" }
    $returnS = ConvertTo-LtInt ([string]$returnEvent.s)
    $postS = ConvertTo-LtInt ([string]$Events[10].s)
    if ($postS -ne $returnS + 2) { throw 'post-return S does not reflect the PULS increment' }
    return [ordered]@{
        saved_cursor = $saved
        return_s = ('{0:X4}' -f $returnS)
        post_s = ('{0:X4}' -f $postS)
    }
}

function Get-LtRunFacts {
    param([string]$RunDirectory,[string]$Variant)
    $run = [IO.Path]::GetFullPath($RunDirectory)
    if (!(Test-Path -LiteralPath $run -PathType Container)) { throw "Run directory is missing: $run" }
    $observation = Read-LtJson (Join-Path $run 'observation.json')
    $provenance = Read-LtJson (Join-Path $run 'provenance.json')
    $runArgs = @(Read-LtJson (Join-Path $run 'arguments.json'))
    if ($observation.variant -ne $Variant) { throw "Run variant is $($observation.variant), expected $Variant" }
    if ($observation.exit_code -ne 0) { throw "Run exit code is $($observation.exit_code)" }
    if ($observation.timed_out) { throw 'Run timed out' }
    if (!$observation.rom_unchanged) { throw 'Run ROM changed during the observation' }
    if (!$observation.map_live_bytes_ok) { throw 'Lua map/live-byte validation did not pass' }
    if ($observation.manager_machine_debugger -ne 'userdata') { throw 'Run did not record manager.machine.debugger=userdata' }
    if ($observation.cpu_debug -ne 'userdata') { throw 'Run did not record cpu.debug=userdata' }
    if (!$observation.native_debugger_exact_boundaries) { throw 'Run does not claim native debugger exact boundaries' }
    if (!$observation.complete_call_proof) { throw 'Run does not claim a complete call' }
    if (!$observation.debugger_used) { throw 'Run did not use the debugger for exact boundaries' }
    if ($observation.debugger_writes) { throw 'Run used debugger state writes' }
    if ($observation.save_state_loaded) { throw 'Run loaded a save state' }
    if ($observation.source_map_sha256 -ine $script:LtSourceMapSha256) { throw 'Run source-map identity is stale or wrong' }
    if ($observation.build_report_sha256 -ine $script:LtBuildReportSha256) { throw 'Run build-report identity is stale or wrong' }
    if ($observation.replay_sha256 -ine $script:LtReplaySha256) { throw 'Run replay identity is stale or wrong' }
    if ($observation.mame_sha256 -ine $script:LtMameSha256) { throw 'Run MAME identity is stale or wrong' }
    $planHash = Get-LtHash $script:LtPlanPath 'SHA256'
    if ($observation.plan_sha256 -ine $planHash) { throw 'Run plan identity is stale or wrong' }
    Assert-LtArguments $runArgs $run
    Assert-LtPreRun $run
    $expectedSha = if ($Variant -eq 'Original') { $script:LtOriginalSha256 } else { $script:LtRepairedSha256 }
    $expectedSha1 = if ($Variant -eq 'Original') { $script:LtOriginalSha1 } else { $script:LtRepairedSha1 }
    $runRom = Join-Path $run 'roms/m4addr/a6ls.p1'
    $rom = Assert-LtRomFile $runRom $expectedSha1 $expectedSha "$Variant run ROM"
    $variantMap = Read-LtJson (Join-Path $run 'variant-map.json')
    Assert-LtVariantMap $variantMap $Variant $expectedSha $runRom
    if ($observation.variant_map_sha256 -ine (Get-LtHash (Join-Path $run 'variant-map.json') 'SHA256')) { throw 'Variant map hash does not match observation.json' }
    if ($observation.trace_map_sha256 -ine (Get-LtHash (Join-Path $run 'trace-map.lua') 'SHA256')) { throw 'Trace map hash does not match observation.json' }
    if ($observation.debugger_commands_sha256 -ine (Get-LtHash (Join-Path $run 'debugger.cmd') 'SHA256')) { throw 'Debugger command hash does not match observation.json' }
    if ($observation.observer_sha256 -ine (Get-LtHash (Join-Path $run 'IlVmTrace.lua') 'SHA256')) { throw 'Observer hash does not match observation.json' }
    if ($observation.input_lua_sha256 -ine (Get-LtHash (Join-Path $run 'input.lua') 'SHA256')) { throw 'Input Lua hash does not match observation.json' }
    if ($observation.lua_capability_sha256 -ine (Get-LtHash (Join-Path $run 'lua-capability.csv') 'SHA256')) { throw 'Lua capability log was altered' }
    if ($observation.debug_log_sha256 -ine (Get-LtHash (Join-Path $run 'debug.log') 'SHA256')) { throw 'Debug log was altered' }
    $capLines = @(Get-Content -LiteralPath (Join-Path $run 'lua-capability.csv'))
    if (@($capLines | Where-Object { $_ -like 'MAP_OK,*' }).Count -ne 1) { throw 'Capability log has no MAP_OK' }
    if (@($capLines | Where-Object { $_ -eq 'manager_machine_debugger_type,userdata' }).Count -ne 1) { throw 'Capability log does not record manager.machine.debugger=userdata' }
    if (@($capLines | Where-Object { $_ -eq 'cpu_debug_type,userdata' }).Count -ne 1) { throw 'Capability log does not record cpu.debug=userdata' }
    if (@($capLines | Where-Object { $_ -like 'BOUNDARY_SUPPORT=native_debugger_breakpoints*' }).Count -lt 1) { throw 'Capability log does not name native debugger breakpoints' }
    $events = @(Read-LtBoundaryEvents (Join-Path $run 'debug.log'))
    $claims = Assert-LtBoundaryClaims $events
    $nodePrefetches = @($events | Where-Object { $_.event -eq 'NODE_PREFETCH' })
    $firstLiteral = ([int][IO.File]::ReadAllBytes($runRom)[0x9EDB] -shl 8) -bor [int][IO.File]::ReadAllBytes($runRom)[0x9EDC]
    $secondLiteral = ([int][IO.File]::ReadAllBytes($runRom)[0x9EE1] -shl 8) -bor [int][IO.File]::ReadAllBytes($runRom)[0x9EE2]
    $expectedResult = $firstLiteral -bxor $secondLiteral
    if ([Convert]::ToInt32([string]$nodePrefetches[1].top,16) -ne $firstLiteral) { throw 'Node 1 top does not match the first inline literal' }
    if ([Convert]::ToInt32([string]$nodePrefetches[3].top,16) -ne $secondLiteral) { throw 'Node 3 top does not match the second inline literal' }
    if ([Convert]::ToInt32([string]$nodePrefetches[4].top,16) -ne $expectedResult) { throw 'Node 4 result does not match the inline-literal XOR' }
    if ($Variant -eq 'Original') {
        if ($firstLiteral -ne 0xFF80 -or $expectedResult -ne 0x0000) { throw 'Original first call is not FF80 -> 0000' }
    } else {
        if ($firstLiteral -ne 0xFF00 -or $expectedResult -ne 0x0080) { throw 'Changed first call is not FF00 -> 0080' }
    }
    return [ordered]@{
        directory = $run
        observation = $observation
        provenance = $provenance
        run_rom = $rom
        variant_map = $variantMap
        events = $events
        claims = $claims
        first_literal = '{0:X4}' -f $firstLiteral
        second_literal = '{0:X4}' -f $secondLiteral
        result = '{0:X4}' -f $expectedResult
        replay_sha256 = Get-LtHash (Join-Path $run 'replay-actions.csv') 'SHA256'
        input_lua_sha256 = Get-LtHash (Join-Path $run 'input.lua') 'SHA256'
        actions_sha256 = if (Test-Path -LiteralPath (Join-Path $run 'actions.csv') -PathType Leaf) { Get-LtHash (Join-Path $run 'actions.csv') 'SHA256' } else { '' }
        mame_sha256 = $observation.mame_sha256
        mame_version = $observation.mame_version
    }
}

function Invoke-LtCuration {
    param(
        [string]$OriginalRunDirectory,
        [string]$ChangedRunDirectory,
        [string]$OriginalRom,
        [string]$RepairedRom,
        [string]$SourceMapPath,
        [string]$BuildReportPath,
        [string]$PlanPath,
        [string]$ReplayPath,
        [string]$OutputPath,
        [switch]$RequireBoundaryTrace,
        [switch]$Force
    )
    if (![string]::IsNullOrWhiteSpace($OutputPath) -and (Test-Path -LiteralPath $OutputPath) -and !$Force) {
        throw "Output already exists: $OutputPath"
    }
    if ([string]::IsNullOrWhiteSpace($PlanPath)) { $PlanPath = $script:LtPlanPath }
    $script:LtPlanPath = $PlanPath
    $original = Assert-LtRomFile $OriginalRom $script:LtOriginalSha1 $script:LtOriginalSha256 'original ROM'
    $repaired = Assert-LtRomFile $RepairedRom $script:LtRepairedSha1 $script:LtRepairedSha256 'repaired ROM'
    if ((Get-LtHash $SourceMapPath 'SHA256') -ine $script:LtSourceMapSha256) { throw 'Source map identity is stale or wrong' }
    if ((Get-LtHash $BuildReportPath 'SHA256') -ine $script:LtBuildReportSha256) { throw 'Build report identity is stale or wrong' }
    if ((Get-LtHash $ReplayPath 'SHA256') -ine $script:LtReplaySha256) { throw 'Replay identity is stale or wrong' }
    $originalBytes = [IO.File]::ReadAllBytes($OriginalRom)
    $repairedBytes = [IO.File]::ReadAllBytes($RepairedRom)
    $changedOffsets = Get-LtChangedOffsets $originalBytes $repairedBytes
    if (($changedOffsets -join ',') -ne ($script:LtExpectedChangedOffsets -join ',')) {
        throw "Original/repaired diff is $(Format-LtOffsets $changedOffsets), expected 9EDC,FFD1,FFD2,FFD3,FFD4,FFD5"
    }
    $originalFacts = Get-LtRunFacts $OriginalRunDirectory 'Original'
    $changedFacts = Get-LtRunFacts $ChangedRunDirectory 'Changed'
    if ($originalFacts.replay_sha256 -ine $changedFacts.replay_sha256) { throw 'Original and changed runs used different physical-input replays' }
    if ($originalFacts.input_lua_sha256 -ine $changedFacts.input_lua_sha256) { throw 'Original and changed runs used different input scripts' }
    if ($originalFacts.actions_sha256 -ne $changedFacts.actions_sha256) { throw 'Original and changed runs recorded different scripted physical inputs' }
    if ($originalFacts.mame_sha256 -ine $changedFacts.mame_sha256) { throw 'Original and changed runs used different MAME builds' }
    if ($originalFacts.mame_version -ne $changedFacts.mame_version) { throw 'Original and changed runs used different MAME versions' }
    foreach ($phase in @('node_prefetches','handler_entries')) {
        for ($i=0;$i -lt 5;$i++) {
            $a = @($originalFacts.events | Where-Object { $_.event -eq $(if ($phase -eq 'node_prefetches') { 'NODE_PREFETCH' } else { if ($i -eq 4) { 'RETURN_HANDLER' } else { 'HANDLER_ENTRY' } }) -and [int]$_.index -eq $i })[0]
            $b = @($changedFacts.events | Where-Object { $_.event -eq $(if ($phase -eq 'node_prefetches') { 'NODE_PREFETCH' } else { if ($i -eq 4) { 'RETURN_HANDLER' } else { 'HANDLER_ENTRY' } }) -and [int]$_.index -eq $i })[0]
            if ([string]$a.y -ine [string]$b.y) { throw "Original/changed boundary $phase $i Y differs" }
            if ([string]$a.x -ine [string]$b.x) { throw "Original/changed boundary $phase $i X differs" }
            if ([string]$a.u -ine [string]$b.u) { throw "Original/changed boundary $phase $i U differs" }
            if ([string]$a.s -ine [string]$b.s) { throw "Original/changed boundary $phase $i S differs" }
        }
    }
    if ($originalFacts.claims.saved_cursor -ne $changedFacts.claims.saved_cursor) { throw 'Original/changed saved caller cursors differ' }
    if ($originalFacts.claims.post_s -ne $changedFacts.claims.post_s) { throw 'Original/changed post-return S differ' }
    if ($originalFacts.first_literal -ne 'FF80' -or $changedFacts.first_literal -ne 'FF00') { throw 'Original/changed first inline literals are not FF80/FF00' }
    if ($originalFacts.result -ne '0000' -or $changedFacts.result -ne '0080') { throw 'Original/changed XOR results are not 0000/0080' }
    if ($RequireBoundaryTrace -and (!$originalFacts.observation.complete_call_proof -or !$changedFacts.observation.complete_call_proof)) {
        throw 'Complete boundary proof is required but missing'
    }

    $generated = [DateTime]::UtcNow.ToString('o')
    $result = [ordered]@{
        schema_version = 1
        task = 'il-lua-api-09'
        generated_utc = $generated
        classification = 'Read-only MAME 0.281 Lua debugger capability plus native exact-boundary capture. manager.machine.debugger and cpu.debug are available under -debug; source-map/plan-derived breakpoints captured a complete first natural 9ED9 call and the actual post-PULS caller continuation for original and repaired images. Lua supplied map/live-byte checks, physical input and frame-sampled state; it did not supply instruction boundaries.'
        result_status = 'complete_early_natural_9ed9_call_native_debugger_hooks'
        target_classification = 'natural exact-boundary capability and complete early call'
        complete_call_proof = $true
        identities = [ordered]@{
            original = $original
            repaired = $repaired
            changed_offsets_hex = Format-LtOffsets $changedOffsets
            original_run_rom = $originalFacts.run_rom
            changed_run_rom = $changedFacts.run_rom
        }
        build_binding = [ordered]@{
            source_map_sha256 = $script:LtSourceMapSha256
            build_report_sha256 = $script:LtBuildReportSha256
            plan_sha256 = Get-LtHash $PlanPath 'SHA256'
            original_map_bound = $true
            repaired_map_bound = $true
            body_start = '9ED9'
            body_end_exclusive = '9EE7'
            entries = 14
            nodes = 5
        }
        mame = [ordered]@{
            executable = 'E:\Arcade\MAME0266\mame281.exe'
            version = $originalFacts.mame_version
            sha256 = $originalFacts.mame_sha256
            manager_machine_debugger = 'userdata under -debug'
            cpu_debug = 'userdata under -debug'
            global_debugger_name = 'nil; the earlier global-name probe was the wrong object path and is not evidence of absence'
            lua_instruction_callback = 'unsupported'
            exact_boundary_source = 'native MAME debugger bpset/printf actions generated from the checked source map and handler plan'
        }
        capability_evidence = [ordered]@{
            positive_control = 'manager.machine.debugger and cpu.debug userdata; bpset/bplist/go/execution_state exercised; reset and 00FC breakpoints hit (see artifacts/deepseek/il-lua-api-09/probe-01/run-capability-02)'
            read_tap_positive_control_hits_original = $originalFacts.observation.positive_control_tap_hits
            read_tap_positive_control_hits_changed = $changedFacts.observation.positive_control_tap_hits
            frame_samples_original = $originalFacts.observation.frame_sample_count
            frame_samples_changed = $changedFacts.observation.frame_sample_count
            conclusion = 'Lua can configure and inspect debugger breakpoints and run control; exact instruction boundaries are supplied by the native debugger, not by a Lua instruction callback.'
        }
        early_call = [ordered]@{
            original = [ordered]@{
                first_literal = $originalFacts.first_literal
                second_literal = $originalFacts.second_literal
                result = $originalFacts.result
                saved_cursor = $originalFacts.claims.saved_cursor
                return_s = $originalFacts.claims.return_s
                post_return_s = $originalFacts.claims.post_s
                events = @($originalFacts.events)
            }
            changed = [ordered]@{
                first_literal = $changedFacts.first_literal
                second_literal = $changedFacts.second_literal
                result = $changedFacts.result
                saved_cursor = $changedFacts.claims.saved_cursor
                return_s = $changedFacts.claims.return_s
                post_return_s = $changedFacts.claims.post_s
                events = @($changedFacts.events)
            }
            matched_entry_state = $true
            actual_post_puls_continuation = $true
        }
        runs = [ordered]@{
            original = [ordered]@{
                directory = $originalFacts.directory
                observation = $originalFacts.observation
                provenance = $originalFacts.provenance
                replay_sha256 = $originalFacts.replay_sha256
                input_lua_sha256 = $originalFacts.input_lua_sha256
                actions_sha256 = $originalFacts.actions_sha256
            }
            changed = [ordered]@{
                directory = $changedFacts.directory
                observation = $changedFacts.observation
                provenance = $changedFacts.provenance
                replay_sha256 = $changedFacts.replay_sha256
                input_lua_sha256 = $changedFacts.input_lua_sha256
                actions_sha256 = $changedFacts.actions_sha256
            }
            physical_inputs_identical = ($originalFacts.replay_sha256 -ieq $changedFacts.replay_sha256 -and $originalFacts.input_lua_sha256 -ieq $changedFacts.input_lua_sha256 -and $originalFacts.actions_sha256 -eq $changedFacts.actions_sha256)
        }
        component_provenance = [ordered]@{
            lua = 'manager.machine.debugger/cpu.debug capability record, map/live-byte validation, tracked physical inputs, frame-sampled PC/X/Y/U/S and read-tap diagnostics'
            powershell = 'map rebinding, source-map/plan-derived hook generation, identity/staleness checks, run isolation, hashes and curation'
            native_debugger = 'exact PC=00FC prefetches, handler entries, PULS return, saved caller cursor and post-return continuation'
            not_lua_sourced = @('instruction boundaries','complete 9ED9 call','post-PULS continuation','frame samples as boundaries')
        }
        paid_window_gate = [ordered]@{
            status = 'unchanged'
            attempted = $false
            note = 'The separate EE16/EE22 paid-window gate from il-natural-06 is neither bypassed nor relabelled. This early call is independent.'
        }
        negative_checks = [ordered]@{
            wrong_image_or_map = 'rejected by strict original/repaired/source-map/build/replay/plan hashes and variant binding'
            ambiguous_or_reordered_node = 'rejected by contiguous address and node-index checks'
            forged_boundary_trace = 'rejected by Assert-LtBoundaryClaims and raw debug-log hash checks'
            wrong_y_phase = 'rejected by Assert-LtBoundaryClaims'
            forged_return = 'rejected by saved-S/post-return checks'
            mismatched_entry_state = 'rejected by same-node U/S comparisons across original/changed'
            seeded_state_or_debugger_writes = 'rejected by pre-run emptiness, state directory, argument and observation checks'
            altered_raw_logs = 'rejected by hash cross-checks in observation.json'
            output_collision = 'rejected by create-only run directories and curator output path checks'
        }
        limitations = @(
            'The complete call is the first natural 9ED9 call reached with the tracked replay, not the later EE16/EE22 paid window.',
            'Lua has no instruction callback; the exact boundaries are native debugger observations.',
            'Physical MPU4 hardware compatibility remains separate.'
        )
    }
    if (![string]::IsNullOrWhiteSpace($OutputPath)) { Write-LtJson $OutputPath $result 24 }
    return $result
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-LtCuration -OriginalRunDirectory $OriginalRunDirectory -ChangedRunDirectory $ChangedRunDirectory -OriginalRom $OriginalRom -RepairedRom $RepairedRom -SourceMapPath $SourceMapPath -BuildReportPath $BuildReportPath -PlanPath $PlanPath -ReplayPath $ReplayPath -OutputPath $OutputPath -RequireBoundaryTrace:$RequireBoundaryTrace -Force:$Force | Out-Null
    Write-Output $OutputPath
}


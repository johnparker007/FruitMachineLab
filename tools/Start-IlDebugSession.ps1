[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$MameExecutable,
    [Parameter(Mandatory=$true)][string]$RomDirectory,
    [Parameter(Mandatory=$true)][string]$OriginalRom,
    [Parameter(Mandatory=$true)][string]$RepairedRom,
    [Parameter(Mandatory=$true)][ValidateSet('Original','Changed')][string]$Variant,
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [string]$SourceMapPath,
    [string]$BuildReportPath,
    [string]$PlanPath,
    [string]$ReplayPath,
    [string]$InputLuaPath,
    [ValidateRange(1,120)][int]$SecondsToRun = 120,
    [ValidateRange(30,600)][int]$WallTimeoutSeconds = 600
)
$ErrorActionPreference = 'Stop'

$script:DsOriginalSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$script:DsOriginalSha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
$script:DsRepairedSha1 = 'e1a42dccd304b7b175aabac99e8400cdad04cf69'
$script:DsRepairedSha256 = '577f76bd36dfca04dfb01b5f5d0be93e16572f8617c7ca906397c98df36e5107'
$script:DsSourceMapSha256 = '0c39a6d0d1beac32ca0f64bfec5ce848b2297be41180d0234d2bfdf491df21a9'
$script:DsBuildReportSha256 = 'ae7e0fb2c0121e0b4e62d38e82511841644fcdf922b2d9e54de79b3d7e57f61a'
$script:DsReplaySha256 = '4a051da15264842697879eff396b34a789f5d80623f9a2e749c244e6a80e721d'
$script:DsMameSha256 = '0fce5a88df4f9d9b1fbf1405812c00848036e615993780978d967da34204cb7a'
$script:DsExpectedChangedOffsets = @(0x9EDC,0xFFD1,0xFFD2,0xFFD3,0xFFD4,0xFFD5)
$script:DsProtocol = 'il-debug-session-v1'
$script:DsRoot = Split-Path $PSScriptRoot -Parent
if ([string]::IsNullOrWhiteSpace($SourceMapPath)) { $SourceMapPath = Join-Path $script:DsRoot 'artifacts/deepseek/il-boot-04/build-01/source-map.json' }
if ([string]::IsNullOrWhiteSpace($BuildReportPath)) { $BuildReportPath = Join-Path $script:DsRoot 'artifacts/deepseek/il-boot-04/build-01/build-report.json' }
if ([string]::IsNullOrWhiteSpace($PlanPath)) { $PlanPath = Join-Path $script:DsRoot 'evidence/mpu4/integrity/il-natural-reachability-plan.json' }
if ([string]::IsNullOrWhiteSpace($ReplayPath)) { $ReplayPath = Join-Path $script:DsRoot 'evidence/mpu4/skill-cash/actions.csv' }
if ([string]::IsNullOrWhiteSpace($InputLuaPath)) { $InputLuaPath = Join-Path $script:DsRoot 'evidence/mpu4/skill-cash/input.lua' }

function Get-DsHash {
    param([string]$Path,[string]$Algorithm)
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        try { return ([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Write-DsJson {
    param([string]$Path,$Object,[int]$Depth = 14)
    [IO.File]::WriteAllText($Path,(ConvertTo-Json -InputObject $Object -Depth $Depth),(New-Object System.Text.UTF8Encoding($false)))
}

function ConvertTo-DsInt {
    param([string]$Text)
    return [Convert]::ToInt32($Text,16)
}

function Format-DsHex16 {
    param([int]$Value)
    return ('{0:X4}' -f ($Value -band 0xFFFF))
}

function Get-DsOffsets {
    param([byte[]]$A,[byte[]]$B)
    if ($A.Length -ne $B.Length) { throw 'Cannot compare different-length images' }
    $list = New-Object 'System.Collections.Generic.List[int]'
    for ($i=0;$i -lt $A.Length;$i++) { if ($A[$i] -ne $B[$i]) { [void]$list.Add($i) } }
    return $list.ToArray()
}

function Assert-DsRom {
    param([string]$Path,[int]$Length,[string]$Sha1,[string]$Sha256,[string]$Label)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label is missing: $Path" }
    $actualLength = (Get-Item -LiteralPath $Path).Length
    if ($actualLength -ne $Length) { throw "$Label length is $actualLength, expected $Length" }
    $actualSha1 = Get-DsHash $Path 'SHA1'
    $actualSha256 = Get-DsHash $Path 'SHA256'
    if ($actualSha1 -ine $Sha1) { throw "$Label SHA1 is $actualSha1, expected $Sha1" }
    if ($actualSha256 -ine $Sha256) { throw "$Label SHA256 is $actualSha256, expected $Sha256" }
    return [ordered]@{path=[IO.Path]::GetFullPath($Path);length=$actualLength;sha1=$actualSha1;sha256=$actualSha256}
}

function Get-DsVariantEntries {
    param($SourceMap,[byte[]]$RepairedBytes,[byte[]]$VariantBytes,[string]$Variant)
    if ($SourceMap.schemaVersion -ne 1) { throw 'Source map schemaVersion is not 1' }
    if ($SourceMap.originalRomSha256 -ine $script:DsOriginalSha256) { throw 'Source map original identity is stale or wrong' }
    if ($SourceMap.outputImageSha256 -ine $script:DsRepairedSha256) { throw 'Source map is not bound to the accepted repaired image' }
    if ($SourceMap.bodyStart -ne '9ED9' -or $SourceMap.bodyEndExclusive -ne '9EE7') { throw 'Source map body span is not 9ED9..9EE7' }
    $entries = @($SourceMap.entries)
    if ($entries.Count -ne 14) { throw "Source map has $($entries.Count) entries, expected 14" }
    $expectedAddress = ConvertTo-DsInt $SourceMap.bodyStart
    $spanEnd = ConvertTo-DsInt $SourceMap.bodyEndExclusive
    $lastNode = -1
    foreach ($entry in $entries) {
        $address = ConvertTo-DsInt $entry.address
        if ($address -ne $expectedAddress) { throw "Source map is not contiguous at $($entry.address)" }
        if ($entry.nodeIndex -lt $lastNode) { throw "Source map node order is reordered at $($entry.address)" }
        if ($entry.nodeIndex -gt $lastNode) {
            if ($entry.nodeIndex -ne ($lastNode + 1)) { throw "Source map node index gap at $($entry.address)" }
            $lastNode = $entry.nodeIndex
        }
        $imageByte = [Convert]::ToInt32($entry.imageByte,16)
        if ($imageByte -ne $RepairedBytes[$address]) { throw "Source map byte at $($entry.address) differs from the repaired image" }
        $expectedAddress++
    }
    if ($expectedAddress -ne $spanEnd) { throw 'Source map does not cover the declared body end' }
    if ($lastNode -ne 4) { throw 'Source map does not contain the five checked node indices 0..4' }

    $differences = Get-DsOffsets $script:DsOriginalBytes $RepairedBytes
    if (($differences -join ',') -ne ($script:DsExpectedChangedOffsets -join ',')) {
        throw "Original/repaired diff is $(($differences | ForEach-Object { '{0:X4}' -f $_ }) -join ','), expected 9EDC,FFD1,FFD2,FFD3,FFD4,FFD5"
    }
    $spanDifference = @($differences | Where-Object { $_ -ge (ConvertTo-DsInt $SourceMap.bodyStart) -and $_ -lt (ConvertTo-DsInt $SourceMap.bodyEndExclusive) })
    if (($spanDifference -join ',') -ne '40668') { throw "The only source-map span difference must be 9EDC, found $(($spanDifference | ForEach-Object { '{0:X4}' -f $_ }) -join ',')" }

    $list = New-Object 'System.Collections.Generic.List[object]'
    foreach ($entry in $entries) {
        $address = ConvertTo-DsInt $entry.address
        $list.Add([ordered]@{
            address = Format-DsHex16 $address
            nodeIndex = [int]$entry.nodeIndex
            token = [string]$entry.token
            operation = [string]$entry.operation
            imageByte = '{0:X2}' -f $VariantBytes[$address]
        })
    }
    return $list.ToArray()
}

function Get-DsNodes {
    param($VariantEntries,[string[]]$HandlersByOperation)
    $nodes = New-Object 'System.Collections.Generic.List[object]'
    $byIndex = @{}
    foreach ($entry in @($VariantEntries)) {
        $index = [int]$entry.nodeIndex
        if (!$byIndex.ContainsKey($index)) {
            $byIndex[$index] = [ordered]@{
                index = $index
                address = $entry.address
                token = $entry.token
                operation = $entry.operation
                handlerPc = $HandlersByOperation[$index]
                bytes = New-Object 'System.Collections.Generic.List[int]'
            }
            $nodes.Add($byIndex[$index])
        }
        [void]$byIndex[$index].bytes.Add([Convert]::ToInt32($entry.imageByte,16))
    }
    if ($nodes.Count -ne 5) { throw "Expected five source-map nodes, found $($nodes.Count)" }
    return $nodes.ToArray()
}

function Get-DsPlan {
    param([string]$Path)
    $plan = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    $handlers = @($plan.vm_observation_boundaries.handler_entries)
    if ($handlers.Count -lt 4) { throw 'handler-entry plan is incomplete' }
    $byOperation = @{}
    foreach ($handler in $handlers) { $byOperation[[string]$handler.operation] = [string]$handler.pc }
    return [ordered]@{ plan=$plan; handlers=$handlers; byOperation=$byOperation }
}

function Write-DsMap {
    param([string]$Path,$VariantMap,$Nodes,$PlanInfo,[byte[]]$VariantBytes)
    $handlerByIndex = @{}
    foreach ($node in $Nodes) {
        if (!$PlanInfo.byOperation.ContainsKey([string]$node.operation)) { throw "no handler entry for operation $($node.operation)" }
        $handlerPc = [string]$PlanInfo.byOperation[[string]$node.operation]
        if ($handlerPc -notmatch '^[0-9A-Fa-f]{4}$') { throw "handler entry for $($node.operation) is not a 4-digit hex address" }
        $handlerByIndex[[int]$node.index] = $handlerPc.ToUpperInvariant()
    }
    $firstAddress = ConvertTo-DsInt $Nodes[0].address
    $secondAddress = ConvertTo-DsInt $Nodes[2].address
    $firstLiteral = ([int]$VariantBytes[$firstAddress+2] -shl 8) -bor [int]$VariantBytes[$firstAddress+3]
    $secondLiteral = ([int]$VariantBytes[$secondAddress+2] -shl 8) -bor [int]$VariantBytes[$secondAddress+3]
    $expectedResult = $firstLiteral -bxor $secondLiteral
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('return {')
    [void]$sb.AppendLine('  schemaVersion = 1,')
    [void]$sb.AppendLine(('  protocol = "{0}",' -f $script:DsProtocol))
    [void]$sb.AppendLine(('  variant = "{0}",' -f $VariantMap.variant))
    [void]$sb.AppendLine(('  imageSha256 = "{0}",' -f $VariantMap.imageSha256))
    [void]$sb.AppendLine(('  originalRomSha256 = "{0}",' -f $VariantMap.originalRomSha256))
    [void]$sb.AppendLine(('  bodyStart = 0x{0},' -f $VariantMap.bodyStart))
    [void]$sb.AppendLine(('  bodyEndExclusive = 0x{0},' -f $VariantMap.bodyEndExclusive))
    [void]$sb.AppendLine(('  expectedFirstLiteral = 0x{0:X4},' -f $firstLiteral))
    [void]$sb.AppendLine(('  expectedSecondLiteral = 0x{0:X4},' -f $secondLiteral))
    [void]$sb.AppendLine(('  expectedResult = 0x{0:X4},' -f $expectedResult))
    [void]$sb.AppendLine('  returnNodeIndex = 4,')
    [void]$sb.AppendLine('  nodes = {')
    foreach ($node in $Nodes) {
        $bytes = (@($node.bytes) | ForEach-Object { '0x{0:X2}' -f $_ }) -join ','
        [void]$sb.AppendLine(('    {{ index = {0}, address = 0x{1}, token = 0x{2}, operation = "{3}", handlerPc = 0x{4}, bytes = {{{5}}} }},' -f $node.index,$node.address,$node.token,$node.operation,$handlerByIndex[[int]$node.index],$bytes))
    }
    [void]$sb.AppendLine('  },')
    [void]$sb.AppendLine('  entries = {')
    foreach ($entry in @($VariantMap.entries)) {
        [void]$sb.AppendLine(('    {{ address = 0x{0}, nodeIndex = {1}, token = 0x{2}, operation = "{3}", imageByte = 0x{4} }},' -f $entry.address,$entry.nodeIndex,$entry.token,$entry.operation,$entry.imageByte))
    }
    [void]$sb.AppendLine('  },')
    [void]$sb.AppendLine('}')
    [IO.File]::WriteAllText($Path,$sb.ToString(),(New-Object System.Text.UTF8Encoding($false)))
    return [ordered]@{
        firstLiteral = Format-DsHex16 $firstLiteral
        secondLiteral = Format-DsHex16 $secondLiteral
        expectedResult = Format-DsHex16 $expectedResult
        handlerByIndex = $handlerByIndex
    }
}

function Write-DsConfigLua {
    param([string]$Path,$Config)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('return {')
    foreach ($key in $Config.Keys) {
        $value = $Config[$key]
        if ($value -is [int] -or $value -is [long]) { [void]$sb.AppendLine(('  {0} = {1},' -f $key,$value)) }
        else { [void]$sb.AppendLine(('  {0} = "{1}",' -f $key,$value)) }
    }
    [void]$sb.AppendLine('}')
    [IO.File]::WriteAllText($Path,$sb.ToString(),(New-Object System.Text.UTF8Encoding($false)))
}

# Validate inputs before creating the session directory.
$run = [IO.Path]::GetFullPath($RunDirectory)
if (Test-Path -LiteralPath $run) { throw "Use a fresh create-only session directory: $run" }
foreach ($path in @($MameExecutable,$SourceMapPath,$BuildReportPath,$PlanPath,$ReplayPath,$InputLuaPath)) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file is missing: $path" }
}
if (!(Test-Path -LiteralPath $RomDirectory -PathType Container)) { throw "Installed ROM directory is missing: $RomDirectory" }
$mameHash = Get-DsHash $MameExecutable 'SHA256'
if ($mameHash -ine $script:DsMameSha256) { throw "MAME SHA256 is $mameHash, expected $($script:DsMameSha256)" }
$sourceMapHash = Get-DsHash $SourceMapPath 'SHA256'
if ($sourceMapHash -ine $script:DsSourceMapSha256) { throw "Source map SHA256 is $sourceMapHash, expected $($script:DsSourceMapSha256)" }
$buildReportHash = Get-DsHash $BuildReportPath 'SHA256'
if ($buildReportHash -ine $script:DsBuildReportSha256) { throw "Build report SHA256 is $buildReportHash, expected $($script:DsBuildReportSha256)" }
$replayHash = Get-DsHash $ReplayPath 'SHA256'
if ($replayHash -ine $script:DsReplaySha256) { throw "Replay SHA256 is $replayHash, expected $($script:DsReplaySha256)" }
$planHash = Get-DsHash $PlanPath 'SHA256'
$inputLuaHash = Get-DsHash $InputLuaPath 'SHA256'

$originalIdentity = Assert-DsRom $OriginalRom 65536 $script:DsOriginalSha1 $script:DsOriginalSha256 'original ROM'
$repairedIdentity = Assert-DsRom $RepairedRom 65536 $script:DsRepairedSha1 $script:DsRepairedSha256 'repaired ROM'
$expectedVariant = if ($Variant -eq 'Original') { @{ Sha1=$script:DsOriginalSha1; Sha256=$script:DsOriginalSha256 } } else { @{ Sha1=$script:DsRepairedSha1; Sha256=$script:DsRepairedSha256 } }
$variantPath = if ($Variant -eq 'Original') { $OriginalRom } else { $RepairedRom }
$variantIdentity = Assert-DsRom $variantPath 65536 $expectedVariant.Sha1 $expectedVariant.Sha256 "$Variant ROM"
$script:DsOriginalBytes = [IO.File]::ReadAllBytes($OriginalRom)
$repairedBytes = [IO.File]::ReadAllBytes($RepairedRom)
$variantBytes = [IO.File]::ReadAllBytes($variantPath)
$actualChanged = Get-DsOffsets $script:DsOriginalBytes $repairedBytes
if (($actualChanged -join ',') -ne ($script:DsExpectedChangedOffsets -join ',')) { throw 'Original/repaired diff is not the accepted six-byte edit' }

$sourceMap = Get-Content -LiteralPath $SourceMapPath -Raw | ConvertFrom-Json
$buildReport = Get-Content -LiteralPath $BuildReportPath -Raw | ConvertFrom-Json
if ($buildReport.original.sha256 -ine $script:DsOriginalSha256) { throw 'Build report original identity is wrong' }
if ($buildReport.repaired.sha256 -ine $script:DsRepairedSha256) { throw 'Build report repaired identity is wrong' }
if ($buildReport.sourceMap.outputImageSha256 -ine $script:DsRepairedSha256) { throw 'Build report source map is not bound to the repaired image' }
if ($buildReport.sourceMap.originalRomSha256 -ine $script:DsOriginalSha256) { throw 'Build report source map original identity is wrong' }
if ($buildReport.edit.nodeIndex -ne 0) { throw 'Build report edit node is not zero' }
if ($buildReport.edit.operandAddress -ne '9EDB') { throw 'Build report operand address is not 9EDB' }
if ($buildReport.edit.replacementValue -ne 'FF00') { throw 'Build report replacement is not FF00' }
if (!$buildReport.checks.sourceMapBoundToRepairedSha256) { throw 'Build report does not assert source-map binding' }

$planInfo = Get-DsPlan $PlanPath
$variantEntries = Get-DsVariantEntries $sourceMap $repairedBytes $variantBytes $Variant
$variantMap = [ordered]@{
    variant = $Variant
    imageSha256 = $expectedVariant.Sha256
    originalRomSha256 = $script:DsOriginalSha256
    bodyStart = '9ED9'
    bodyEndExclusive = '9EE7'
    entries = @($variantEntries)
}
$handlerByOperation = $planInfo.byOperation
$handlerByIndex = @{}
$nodeOperations = @{}
foreach ($entry in $variantEntries) { $nodeOperations[[int]$entry.nodeIndex] = [string]$entry.operation }
foreach ($index in $nodeOperations.Keys) {
    $operation = $nodeOperations[$index]
    if (!$handlerByOperation.ContainsKey($operation)) { throw "no handler entry for operation $operation" }
    $handlerByIndex[[int]$index] = [string]$handlerByOperation[$operation]
}
$nodes = Get-DsNodes $variantEntries $handlerByIndex
$sessionId = [guid]::NewGuid().ToString('D')
$config = [ordered]@{
    schemaVersion = 1
    protocol = $script:DsProtocol
    sessionId = $sessionId
    variant = $Variant
    cpuTag = ':maincpu'
    secondsToRun = $SecondsToRun
    wallTimeoutSeconds = $WallTimeoutSeconds
    expectedOriginalRomSha256 = $script:DsOriginalSha256
    expectedImageSha256 = $expectedVariant.Sha256
    expectedSourceMapSha256 = $sourceMapHash
    expectedBuildReportSha256 = $buildReportHash
    expectedPlanSha256 = $planHash
    expectedReplaySha256 = $replayHash
    expectedInputLuaSha256 = $inputLuaHash
    expectedMameSha256 = $mameHash
}

# Create the fresh isolated session directory and immutable copies.
New-Item -ItemType Directory -Path $run -ErrorAction Stop | Out-Null
foreach ($name in @('roms/m4addr','cfg','nvram','inp','snap','comments','state','diff','commands','responses','protocol')) {
    New-Item -ItemType Directory -Path (Join-Path $run $name) -ErrorAction Stop | Out-Null
}
$runRom = Join-Path $run 'roms/m4addr/a6ls.p1'
Copy-Item -LiteralPath $variantPath -Destination $runRom -ErrorAction Stop
$runRomIdentity = Assert-DsRom $runRom 65536 $expectedVariant.Sha1 $expectedVariant.Sha256 'isolated run ROM copy'
Copy-Item -LiteralPath $ReplayPath -Destination (Join-Path $run 'replay-actions.csv') -ErrorAction Stop
Copy-Item -LiteralPath $InputLuaPath -Destination (Join-Path $run 'input.lua') -ErrorAction Stop
Copy-Item -LiteralPath (Join-Path $script:DsRoot 'tools/lua/IlDebugSession.lua') -Destination (Join-Path $run 'IlDebugSession.lua') -ErrorAction Stop
[IO.File]::WriteAllText((Join-Path $run 'observer.lua'),"dofile('input.lua')`ndofile('IlDebugSession.lua')`n",(New-Object System.Text.UTF8Encoding($false)))
$mapInfo = Write-DsMap (Join-Path $run 'session-map.lua') $variantMap $nodes $planInfo $variantBytes
Write-DsConfigLua (Join-Path $run 'session-config.lua') $config
Write-DsJson (Join-Path $run 'session-config.json') $config 8
Write-DsJson (Join-Path $run 'variant-map.json') ([ordered]@{
    schemaVersion = 1
    variant = $Variant
    originalRomSha256 = $script:DsOriginalSha256
    outputImageSha256 = $expectedVariant.Sha256
    bodyStart = '9ED9'
    bodyEndExclusive = '9EE7'
    entries = @($variantEntries)
    nodes = @($nodes)
}) 12
Write-DsJson (Join-Path $run 'session-metadata.json') ([ordered]@{
    sessionId = $sessionId
    protocol = $script:DsProtocol
    variant = $Variant
    original_rom = $originalIdentity
    repaired_rom = $repairedIdentity
    variant_rom = $variantIdentity
    run_rom_before = $runRomIdentity
    source_map_path = [IO.Path]::GetFullPath($SourceMapPath)
    source_map_sha256 = $sourceMapHash
    build_report_path = [IO.Path]::GetFullPath($BuildReportPath)
    build_report_sha256 = $buildReportHash
    plan_path = [IO.Path]::GetFullPath($PlanPath)
    plan_sha256 = $planHash
    replay_sha256 = $replayHash
    input_lua_sha256 = $inputLuaHash
    mame_executable = [IO.Path]::GetFullPath($MameExecutable)
    mame_sha256 = $mameHash
    seconds_to_run = $SecondsToRun
    wall_timeout_seconds = $WallTimeoutSeconds
    expected_first_literal = $mapInfo.firstLiteral
    expected_second_literal = $mapInfo.secondLiteral
    expected_result = $mapInfo.expectedResult
    handler_by_index = [ordered]@{ '0'=$mapInfo.handlerByIndex[0]; '1'=$mapInfo.handlerByIndex[1]; '2'=$mapInfo.handlerByIndex[2]; '3'=$mapInfo.handlerByIndex[3]; '4'=$mapInfo.handlerByIndex[4] }
    changed_offsets_hex = (($actualChanged | Sort-Object | ForEach-Object { '{0:X4}' -f $_ }) -join ',')
    starting_nvram = 'absent'
    starting_configuration = 'absent; -noreadconfig'
    save_state_loaded = $false
    debugger_writes = $false
    classification = 'Fresh-isolated natural run with read-only Lua run-control and bounded IL-node stepping.'
}) 14

$preRunCounts = [ordered]@{}
foreach ($name in @('cfg','nvram','inp','snap','comments','state','diff')) { $preRunCounts[$name] = @(Get-ChildItem -LiteralPath (Join-Path $run $name) -Recurse -File -ErrorAction SilentlyContinue).Count }
foreach ($key in $preRunCounts.Keys) { if ($preRunCounts[$key] -ne 0) { throw "Pre-run directory $key is not empty" } }
$preRunRomFiles = @(Get-ChildItem -LiteralPath (Join-Path $run 'roms/m4addr') -File | ForEach-Object { $_.Name } | Sort-Object)
if (($preRunRomFiles -join ',') -ne 'a6ls.p1') { throw 'Isolated ROM directory must contain exactly a6ls.p1 before launch' }
Write-DsJson (Join-Path $run 'pre-run-empty.json') $preRunCounts 6

# Version check, then asynchronous launch. The session exits only by the stop command or its wall bound.
$versionOut = Join-Path $run 'mame-version.txt'
$versionErr = Join-Path $run 'mame-version.err.txt'
$versionInfo = New-Object System.Diagnostics.ProcessStartInfo
$versionInfo.FileName = [IO.Path]::GetFullPath($MameExecutable)
$versionInfo.Arguments = '-version'
$versionInfo.WorkingDirectory = $run
$versionInfo.UseShellExecute = $false
$versionInfo.CreateNoWindow = $true
$versionInfo.RedirectStandardOutput = $true
$versionInfo.RedirectStandardError = $true
$versionProcess = New-Object System.Diagnostics.Process
$versionProcess.StartInfo = $versionInfo
[void]$versionProcess.Start()
$versionStdout = $versionProcess.StandardOutput.ReadToEndAsync()
$versionStderr = $versionProcess.StandardError.ReadToEndAsync()
if (-not $versionProcess.WaitForExit(60000)) { & "$env:SystemRoot\System32\taskkill.exe" /PID $versionProcess.Id /T /F | Out-Null; throw 'MAME -version timed out' }
[IO.File]::WriteAllText($versionOut,$versionStdout.GetAwaiter().GetResult(),(New-Object System.Text.UTF8Encoding($false)))
[IO.File]::WriteAllText($versionErr,$versionStderr.GetAwaiter().GetResult(),(New-Object System.Text.UTF8Encoding($false)))
if ($versionProcess.ExitCode -ne 0) { throw "MAME -version failed: exit=$($versionProcess.ExitCode)" }
$versionProcess.Dispose()
$mameVersion = ((Get-Content -LiteralPath $versionOut -Raw).Trim() -split "\r?\n")[0]
if ($mameVersion -notmatch '^0\.281\b') { throw "Unexpected MAME version: $mameVersion" }

$arguments = @('m4addr','-noreadconfig','-rompath',((Join-Path $run 'roms')+';'+$RomDirectory),
    '-cfg_directory',(Join-Path $run 'cfg'),'-nvram_directory',(Join-Path $run 'nvram'),
    '-input_directory',(Join-Path $run 'inp'),'-snapshot_directory',(Join-Path $run 'snap'),
    '-comment_directory',(Join-Path $run 'comments'),'-state_directory',(Join-Path $run 'state'),
    '-diff_directory',(Join-Path $run 'diff'),'-debug','-debugger','windows','-debuglog',
    '-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle',
    '-seconds_to_run',[string]$SecondsToRun,'-autoboot_delay','0',
    '-autoboot_script',(Join-Path $run 'observer.lua'))
$quotedArguments = foreach ($arg in $arguments) {
    $text = [string]$arg
    if ($text -match '[\s"]') { '"' + $text.Replace('"','\"') + '"' } else { $text }
}
$argumentString = ($quotedArguments -join ' ')
$consolePath = Join-Path $run 'console.txt'
$consoleErrorPath = Join-Path $run 'console.err.txt'
$wrapperPath = Join-Path $run 'launch.cmd'
$wrapperLines = @(
    '@echo off',
    ('set "MPU4_REPLAY={0}"' -f (Join-Path $run 'replay-actions.csv')),
    'set "MPU4_POLICY=7"',
    'set "FML_IL_DEBUG_SESSION=1"',
    ('set "FML_IL_DEBUG_SESSION_ID={0}"' -f $sessionId),
    ('"{0}" {1} > "{2}" 2> "{3}"' -f ([IO.Path]::GetFullPath($MameExecutable)), $argumentString, $consolePath, $consoleErrorPath),
    'set "MAME_EXIT=%ERRORLEVEL%"',
    ('echo %MAME_EXIT% > "{0}"' -f (Join-Path $run 'mame-exit-code.txt')),
    'exit /b %MAME_EXIT%'
)
[IO.File]::WriteAllLines($wrapperPath, $wrapperLines, (New-Object System.Text.UTF8Encoding($false)))
$wrapperCommand = 'cmd.exe /c ""' + [IO.Path]::GetFullPath($wrapperPath) + '""'
$createResult = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $wrapperCommand; CurrentDirectory = $run }
if ($createResult.ReturnValue -ne 0) { throw "Failed to create the detached MAME launcher (WMI return $($createResult.ReturnValue))" }
$launchPid = [int]$createResult.ProcessId
$startUtc = [DateTime]::UtcNow
$readyPath = Join-Path $run 'ready.txt'
$readyDeadline = [DateTime]::UtcNow.AddSeconds([Math]::Min($WallTimeoutSeconds, 60))
while (!(Test-Path -LiteralPath $readyPath -PathType Leaf)) {
    if ($null -eq (Get-Process -Id $launchPid -ErrorAction SilentlyContinue)) {
        $consoleText = if (Test-Path -LiteralPath $consoleErrorPath) { Get-Content -LiteralPath $consoleErrorPath -Raw } else { '' }
        throw "MAME launcher exited before the session became ready: $consoleText"
    }
    if ([DateTime]::UtcNow -gt $readyDeadline) {
        & "$env:SystemRoot\System32\taskkill.exe" /PID $launchPid /T /F | Out-Null
        throw "Session did not become ready within $([Math]::Min($WallTimeoutSeconds,60)) wall seconds"
    }
    Start-Sleep -Milliseconds 200
}
$readyLines = @(Get-Content -LiteralPath $readyPath)
$ready = @{}
foreach ($line in $readyLines) {
    if ($line -match '^([a-zA-Z0-9]+)=(.*)$') { $ready[$Matches[1]] = $Matches[2] }
}
if ($ready['protocol'] -ne $script:DsProtocol) { throw 'Ready file protocol mismatch' }
if ($ready['session'] -ne $sessionId) { throw 'Ready file session mismatch' }
if ($ready['variant'] -ne $Variant) { throw 'Ready file variant mismatch' }
if ($ready['map'] -ne 'ok') { throw 'Lua map validation did not pass' }
if ($ready['exec'] -ne 'stop') { throw "Session did not start stopped (exec=$($ready['exec']))" }
if ($ready['lfs'] -ne 'ok') { throw 'Lua lfs directory enumeration is unavailable' }
Write-DsJson (Join-Path $run 'session-launch.json') ([ordered]@{
    sessionId = $sessionId
    variant = $Variant
    protocol = $script:DsProtocol
    process_id = $launchPid
    start_utc = $startUtc.ToString('o')
    command_line = $argumentString
    mame_version = $mameVersion
    mame_sha256 = $mameHash
    launch_wrapper = $wrapperPath
    ready = $ready
    seconds_to_run = $SecondsToRun
    wall_timeout_seconds = $WallTimeoutSeconds
}) 10
$launchRecord = [ordered]@{
    sessionId = $sessionId
    variant = $Variant
    session_directory = $run
    process_id = $launchPid
    mame_version = $mameVersion
    ready = $ready
}
Write-Output (ConvertTo-Json -InputObject $launchRecord -Depth 6)

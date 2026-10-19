[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OriginalRom,
    [Parameter(Mandatory = $true)]
    [string]$OutputRoot,
    [string]$RepositoryRoot = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}
$repo = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$rom = (Resolve-Path -LiteralPath $OriginalRom).Path
$out = [IO.Path]::GetFullPath($OutputRoot)
if (Test-Path -LiteralPath $out) {
    throw "OutputRoot already exists and must be fresh: $out"
}
New-Item -ItemType Directory -Path $out -Force | Out-Null

$cliProject = Join-Path $repo 'tools/FruitMachineLab.IlLampPatternBuild/FruitMachineLab.IlLampPatternBuild.csproj'
$ilProject = Join-Path $repo 'tests/FruitMachineLab.IlVerification/FruitMachineLab.IlVerification.csproj'
$logRoot = Join-Path $out 'logs'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

$expectedOriginalSha1 = '402D1518BB78FDC489B06C2AABC771E5CE151847'
$expectedOriginalSha256 = 'EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C'
$expectedUnrepairedSha1 = 'FED6058A6BF8D2627068BAC01D77EE0D279B5E46'
$expectedUnrepairedSha256 = '3D94F6E2908D9C57C2C20EEDE897A0A19D4C74BA88464053554C0558C25ADDE3'
$expectedOutputSha1 = '9F060102692BB31E03F992E95E38F4F59BEE1129'
$expectedOutputSha256 = '631F6C252A5DF359525553F7D14A4FC8CEF965C76BBECA759EAAA862A3FAD4DE'
$expectedFields = 'E93F3C61B5'
$expectedUnrepairedOffsets = @(
    0x1010, 0x1011, 0x1012, 0x1013, 0x1015, 0x1016, 0x1017, 0x1018,
    0x1019, 0x101B, 0x101C, 0x101D, 0x101E, 0x101F, 0x1020, 0x1021,
    0x1022, 0x1023, 0x1024, 0x1025, 0x1026, 0x1027, 0x9F14, 0x9F15
)
$expectedFinalOffsets = @($expectedUnrepairedOffsets + @(0xFFD1, 0xFFD2, 0xFFD3, 0xFFD4, 0xFFD5))

$log = New-Object System.Collections.Generic.List[string]
$checks = New-Object System.Collections.ArrayList
$script:failed = $false

function Write-Log([string]$text) {
    $log.Add($text) | Out-Null
    Write-Output $text
}

function Add-Check([string]$id, [bool]$ok, [string]$detail) {
    $checks.Add([ordered]@{ id = $id; ok = $ok; detail = $detail }) | Out-Null
    $tag = if ($ok) { 'PASS' } else { 'FAIL' }
    Write-Log ("{0} {1}: {2}" -f $tag, $id, $detail)
    if (-not $ok) { $script:failed = $true }
}

function Get-HashHex([byte[]]$bytes, [string]$algorithm) {
    $hashAlgorithm = [System.Security.Cryptography.HashAlgorithm]::Create($algorithm)
    try {
        $hash = $hashAlgorithm.ComputeHash($bytes)
    }
    finally {
        $hashAlgorithm.Dispose()
    }
    return ([BitConverter]::ToString($hash)).Replace('-', '')
}

function Get-DiffOffsets([byte[]]$before, [byte[]]$after) {
    if ($before.Length -ne $after.Length) { throw 'Image lengths differ' }
    $offsets = New-Object System.Collections.ArrayList
    for ($index = 0; $index -lt $before.Length; $index++) {
        if ($before[$index] -ne $after[$index]) {
            [void]$offsets.Add($index)
        }
    }
    return @($offsets.ToArray())
}

function Format-Offsets($offsets) {
    return (@($offsets) | ForEach-Object { '{0:X4}' -f [int]$_ }) -join ','
}

function Test-BytesEqual([byte[]]$first, [byte[]]$second) {
    if ($first.Length -ne $second.Length) { return $false }
    for ($index = 0; $index -lt $first.Length; $index++) {
        if ($first[$index] -ne $second[$index]) { return $false }
    }
    return $true
}

function Assert-Equal($actual, $expected, [string]$message) {
    if ($actual -ne $expected) {
        throw ("{0}: expected {1}, got {2}" -f $message, $expected, $actual)
    }
}

function Invoke-DotNet([string[]]$arguments, [string]$logPath) {
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & dotnet @arguments 2>&1
        $exit = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
    $text = (@($output) | ForEach-Object { [string]$_ }) -join "`n"
    [IO.File]::WriteAllText($logPath, $text + "`n", (New-Object System.Text.UTF8Encoding($false)))
    return [pscustomobject]@{ Exit = $exit; Output = $text }
}

function Invoke-Cli([string]$inputRom, [string]$outputDirectory, [string]$logName) {
    $args = @('run', '--project', $cliProject, '--no-build', '--', $inputRom, $outputDirectory)
    return Invoke-DotNet $args (Join-Path $logRoot $logName)
}

function Test-OutputFiles([string]$directory) {
    foreach ($name in @(
        'lamp-unrepaired.p1',
        'lamp-repaired.p1',
        'lamp-pattern-source-map.json',
        'build-report.json')) {
        if (-not (Test-Path -LiteralPath (Join-Path $directory $name) -PathType Leaf)) {
            throw "missing output file $name"
        }
    }
}

# ---------------------------------------------------------------------------
# Build the standalone CLI and the independent IL verifier.
# ---------------------------------------------------------------------------
$build = Invoke-DotNet @('build', $cliProject, '--ignore-failed-sources') (Join-Path $logRoot 'build-cli.log')
Add-Check 'build-standalone-cli' ($build.Exit -eq 0) "exit=$($build.Exit)"
$buildIl = Invoke-DotNet @('build', $ilProject, '--ignore-failed-sources') (Join-Path $logRoot 'build-il-verifier.log')
Add-Check 'build-il-verifier' ($buildIl.Exit -eq 0) "exit=$($buildIl.Exit)"

# ---------------------------------------------------------------------------
# Positive fresh build.
# ---------------------------------------------------------------------------
$positive = Join-Path $out 'positive-01'
$positiveRun = Invoke-Cli $rom $positive 'cli-positive-01.log'
Add-Check 'positive-cli-exit' ($positiveRun.Exit -eq 0) "exit=$($positiveRun.Exit)"
Test-OutputFiles $positive
$originalBytes = [IO.File]::ReadAllBytes($rom)
$unrepairedBytes = [IO.File]::ReadAllBytes((Join-Path $positive 'lamp-unrepaired.p1'))
$repairedBytes = [IO.File]::ReadAllBytes((Join-Path $positive 'lamp-repaired.p1'))
Assert-Equal (Get-HashHex $originalBytes 'SHA1') $expectedOriginalSha1 'original SHA1'
Assert-Equal (Get-HashHex $originalBytes 'SHA256') $expectedOriginalSha256 'original SHA256'
Assert-Equal (Get-HashHex $unrepairedBytes 'SHA1') $expectedUnrepairedSha1 'unrepaired SHA1'
Assert-Equal (Get-HashHex $unrepairedBytes 'SHA256') $expectedUnrepairedSha256 'unrepaired SHA256'
Assert-Equal (Get-HashHex $repairedBytes 'SHA1') $expectedOutputSha1 'repaired SHA1'
Assert-Equal (Get-HashHex $repairedBytes 'SHA256') $expectedOutputSha256 'repaired SHA256'
Add-Check 'positive-exact-hashes' $true 'original, unrepaired and repaired SHA1/SHA256 match the reviewed contract'

$unrepairedDiff = Get-DiffOffsets $originalBytes $unrepairedBytes
$finalDiff = Get-DiffOffsets $originalBytes $repairedBytes
Assert-Equal $unrepairedDiff.Count 24 'unrepaired diff count'
Assert-Equal $finalDiff.Count 29 'final diff count'
Assert-Equal (Format-Offsets $unrepairedDiff) (Format-Offsets $expectedUnrepairedOffsets) 'unrepaired diff offsets'
Assert-Equal (Format-Offsets $finalDiff) (Format-Offsets $expectedFinalOffsets) 'final diff offsets'
Assert-Equal $unrepairedBytes[0x1014] 0xFF '1014 remains FF'
Assert-Equal $unrepairedBytes[0x101A] 0xFF '101A remains FF'
Assert-Equal $repairedBytes[0x1014] 0xFF 'final 1014 remains FF'
Assert-Equal $repairedBytes[0x101A] 0xFF 'final 101A remains FF'
$fields = ([BitConverter]::ToString($repairedBytes[0xFFD1..0xFFD5])).Replace('-', '')
Assert-Equal $fields $expectedFields 'repaired fields'
Add-Check 'positive-diff-and-fields' $true '24 unrepaired and 29 final offsets; 1014/101A remain FF; fields E93F3C61B5'

$report = Get-Content -LiteralPath (Join-Path $positive 'build-report.json') -Raw | ConvertFrom-Json
Assert-Equal ([bool]$report.staticOnly) $true 'staticOnly'
Assert-Equal ([bool]$report.executionClaimed) $false 'executionClaimed'
Assert-Equal ([int]$report.allocation.length) 24 'allocation length'
Assert-Equal ([int]$report.allocation.remainingApprovedBytes) 968 'remaining approved bytes'
Assert-Equal ([int]$report.unrepaired.changedCount) 24 'report unrepaired count'
Assert-Equal ([int]$report.repaired.changedCount) 29 'report final count'
Assert-Equal ([string]$report.integrity.repairedFieldsHex) $expectedFields 'report fields'
Assert-Equal ([string]$report.repaired.sha256) $expectedOutputSha256 'report repaired SHA256'
Assert-Equal ([string]$report.sharedCall.handler) '9B15' 'report shared handler'
Assert-Equal ([string]$report.sharedCall.servicePointerValue) '72BF' 'report service pointer'
Assert-Equal ([bool]$report.sharedCall.handlerIsTokenPlusTwo) $false 'report token+2 flag'
Assert-Equal ([int]$report.sharedCall.callerOperandBytes) 0 'report caller operand bytes'
$map = Get-Content -LiteralPath (Join-Path $positive 'lamp-pattern-source-map.json') -Raw | ConvertFrom-Json
Assert-Equal ([string]$map.OutputImageSha256) $expectedOutputSha256 'map build binding'
Assert-Equal ([int]@($map.Entries).Count) 44 'map entries'
Assert-Equal ([int]@($map.InlineOperands).Count) 4 'map inline operands'
Assert-Equal ([int]@($map.Phases).Count) 43 'map phases'
Assert-Equal ([int]@($map.Boundaries).Count) 12 'map boundaries'
Assert-Equal ([int]@($map.Nodes).Count) 8 'map nodes'
$handler0 = @($map.Phases | Where-Object { $_.Phase -eq 'handler-0' })[0]
$handler1 = @($map.Phases | Where-Object { $_.Phase -eq 'handler-1' })[0]
$sharedHandler = @($map.Phases | Where-Object { $_.Phase -eq 'shared-handler-entry' })[0]
$trampolineJsr = @($map.Phases | Where-Object { $_.Phase -eq 'service-trampoline-jrs-entry' })[0]
$trampolinePshu = @($map.Phases | Where-Object { $_.Phase -eq 'service-trampoline-pshu' })[0]
$prologue0 = @($map.Phases | Where-Object { $_.Phase -eq 'native-prologue-save-regs' })[0]
$prologue1 = @($map.Phases | Where-Object { $_.Phase -eq 'native-prologue-save-mask' })[0]
$prologue2 = @($map.Phases | Where-Object { $_.Phase -eq 'native-prologue-deepest' })[0]
$nativeReturn = @($map.Phases | Where-Object { $_.Phase -eq 'native-return' })[0]
$sharedReturn = @($map.Phases | Where-Object { $_.Phase -eq 'shared-return-handler' })[0]
$outerReturn = @($map.Phases | Where-Object { $_.Phase -eq 'outer-return-handler' })[0]
$sharedBodyEntry = @($map.Phases | Where-Object { $_.Phase -eq 'shared-body-entry' })[0]
$sharedAfterWord = @($map.Phases | Where-Object { $_.Phase -eq 'shared-after-fetch-word' })[0]
$sharedReturned = @($map.Phases | Where-Object { $_.Phase -eq 'shared-returned-to-1026' })[0]
$outerReturned = @($map.Phases | Where-Object { $_.Phase -eq 'outer-returned-to-9F16' })[0]
Assert-Equal ([int]$handler0.U) 0x066E 'handler-0 PRE U'
Assert-Equal ([int]$handler0.X) 0x795D 'handler-0 dispatch X'
Assert-Equal ([int]$handler1.U) 0x066C 'handler-1 PRE U'
Assert-Equal ([int]$sharedHandler.U) 0x066A 'shared handler PRE-JSR U'
Assert-Equal ([int]$sharedHandler.S) 0x0796 'shared handler PRE-JSR S'
Assert-Equal ([int]$sharedHandler.X) 0x9C46 'shared handler dispatch X'
Assert-Equal ([int]$trampolineJsr.U) 0x066A '796E pre-PSHU U'
Assert-Equal ([int]$trampolineJsr.S) 0x0794 '796E pre-PSHU S'
Assert-Equal ([int]$trampolinePshu.U) 0x0668 '796E post-PSHU U'
Assert-Equal ([int]$sharedBodyEntry.Pc) 0x00FC 'shared body entry prefetch PC'
Assert-Equal ([int]$sharedBodyEntry.X) 0x9B18 'shared body entry X'
Assert-Equal ([int]$sharedBodyEntry.Y) 0x9B18 'shared body entry Y'
Assert-Equal ([int]$sharedAfterWord.Pc) 0x00FC 'shared after-word prefetch PC'
Assert-Equal ([int]$sharedAfterWord.X) 0x790F 'shared after-word handler X'
Assert-Equal ([int]$sharedAfterWord.Y) 0x9B1A 'shared after-word next Y'
Assert-Equal ([int]$prologue0.Pc) 0x49C7 '49C5 post-instruction PC'
Assert-Equal ([int]$prologue1.Pc) 0x49D0 '49CE post-instruction PC'
Assert-Equal ([int]$prologue2.Pc) 0x49D2 '49D0 post-instruction PC'
Assert-Equal ([int]$prologue0.S) 0x078C '49C5 PSHS A,B,X S'
Assert-Equal ([int]$prologue1.S) 0x078B '49CE PSHS B S'
Assert-Equal ([int]$prologue2.S) 0x078A '49D0 PSHS CC deepest S'
Assert-Equal ([int]$nativeReturn.Pc) 0x777E 'native return PC'
Assert-Equal ([int]$nativeReturn.S) 0x0792 'native return S'
Assert-Equal ([int]$sharedReturn.Pc) 0x7931 'shared return handler PC'
Assert-Equal ([int]$sharedReturn.X) 0x7931 'shared return handler X'
Assert-Equal ([int]$sharedReturn.Y) 0x9B26 'shared return handler Y'
Assert-Equal ([int]$outerReturn.X) 0x7931 'outer return handler X'
Assert-Equal ([int]$outerReturn.Y) 0x1028 'outer return handler Y'
Assert-Equal ([int]$sharedReturned.X) 0x7931 'shared resumed prefetch X'
Assert-Equal ([int]$outerReturned.X) 0x7931 'outer resumed prefetch X'
Assert-Equal ([int]$sharedReturn.SavedCursor) 0x1026 'shared saved cursor'
Assert-Equal ([int]$outerReturn.SavedCursor) 0x9F16 'outer saved cursor'
Assert-Equal ([int]@($map.Phases | Where-Object { $_.S -eq 0x0778 }).Count) 0 'no transplanted B951 S'
Add-Check 'positive-phase-boundaries' $true 'handler PRE states, 9B15/796E, split native prologue and saved cursors match the ROM instruction order'
Add-Check 'positive-report-and-map' $true 'report is static-only; allocation is 24 with 968 remaining; map binds the exact SHA256 with 44 entries, 4 operands, 43 phases, 12 boundaries and 8 nodes'

Assert-Equal (Get-HashHex ([IO.File]::ReadAllBytes($rom)) 'SHA256') $expectedOriginalSha256 'original unchanged after positive build'
Add-Check 'positive-original-read-only' $true 'original ROM hash is unchanged after the build'

# ---------------------------------------------------------------------------
# Repeated deterministic build.
# ---------------------------------------------------------------------------
$repeat = Join-Path $out 'positive-02'
$repeatRun = Invoke-Cli $rom $repeat 'cli-positive-02.log'
Add-Check 'repeat-cli-exit' ($repeatRun.Exit -eq 0) "exit=$($repeatRun.Exit)"
Test-OutputFiles $repeat
foreach ($name in @(
    'lamp-unrepaired.p1',
    'lamp-repaired.p1',
    'lamp-pattern-source-map.json',
    'build-report.json')) {
    $first = [IO.File]::ReadAllBytes((Join-Path $positive $name))
    $second = [IO.File]::ReadAllBytes((Join-Path $repeat $name))
    if (-not (Test-BytesEqual $first $second)) {
        throw "repeated output differs: $name"
    }
}
Add-Check 'repeat-deterministic' $true 'a second fresh output directory is byte-identical for all four files'

# ---------------------------------------------------------------------------
# Missing arguments.
# ---------------------------------------------------------------------------
$missingLog = Join-Path $logRoot 'cli-missing-args.log'
$missing = Invoke-DotNet @('run', '--project', $cliProject, '--no-build', '--') $missingLog
Add-Check 'negative-missing-arguments' ($missing.Exit -eq 2) "exit=$($missing.Exit)"

# ---------------------------------------------------------------------------
# Wrong identity and wrong length.
# ---------------------------------------------------------------------------
$inputs = Join-Path $out 'inputs'
New-Item -ItemType Directory -Path $inputs -Force | Out-Null
$wrongIdentityPath = Join-Path $inputs 'wrong-identity.p1'
$wrongIdentity = [byte[]]$originalBytes.Clone()
$wrongIdentity[0x1400] = $wrongIdentity[0x1400] -bxor 1
[IO.File]::WriteAllBytes($wrongIdentityPath, $wrongIdentity)
$wrongIdentityOut = Join-Path $out 'negative-wrong-identity'
$wrongIdentityRun = Invoke-Cli $wrongIdentityPath $wrongIdentityOut 'cli-wrong-identity.log'
Add-Check 'negative-wrong-identity-exit' ($wrongIdentityRun.Exit -eq 1) "exit=$($wrongIdentityRun.Exit)"
Add-Check 'negative-wrong-identity-no-output' (-not (Test-Path -LiteralPath $wrongIdentityOut)) 'no output directory was created'

$wrongLengthPath = Join-Path $inputs 'wrong-length.p1'
$wrongLengthBytes = New-Object byte[] 65535
[Array]::Copy($originalBytes, 0, $wrongLengthBytes, 0, 65535)
[IO.File]::WriteAllBytes($wrongLengthPath, $wrongLengthBytes)
$wrongLengthOut = Join-Path $out 'negative-wrong-length'
$wrongLengthRun = Invoke-Cli $wrongLengthPath $wrongLengthOut 'cli-wrong-length.log'
Add-Check 'negative-wrong-length-exit' ($wrongLengthRun.Exit -eq 1) "exit=$($wrongLengthRun.Exit)"
Add-Check 'negative-wrong-length-no-output' (-not (Test-Path -LiteralPath $wrongLengthOut)) 'no output directory was created'

# ---------------------------------------------------------------------------
# Existing output and input/output alias.
# ---------------------------------------------------------------------------
$existingOut = Join-Path $out 'negative-existing-output'
New-Item -ItemType Directory -Path $existingOut -Force | Out-Null
$existingRun = Invoke-Cli $rom $existingOut 'cli-existing-output.log'
Add-Check 'negative-existing-output-exit' ($existingRun.Exit -eq 1) "exit=$($existingRun.Exit)"
Add-Check 'negative-existing-output-preserved' (@(Get-ChildItem -LiteralPath $existingOut -Force).Count -eq 0) 'the existing output directory was not replaced'

$aliasRun = Invoke-Cli $rom $rom 'cli-input-output-alias.log'
Add-Check 'negative-input-output-alias-exit' ($aliasRun.Exit -eq 1) "exit=$($aliasRun.Exit)"

# ---------------------------------------------------------------------------
# Full independent IL verifier, including the new lamp-pattern groups.
# ---------------------------------------------------------------------------
$verifyOut = Join-Path $out 'il-verifier'
$verifyRun = Invoke-DotNet @(
    'run', '--project', $ilProject, '--no-build', '--', $rom, $verifyOut
) (Join-Path $logRoot 'il-verifier.log')
Add-Check 'il-verifier-exit' ($verifyRun.Exit -eq 0) "exit=$($verifyRun.Exit)"
$verifyReportPath = Join-Path $verifyOut 'lamp-pattern/verification-report.json'
if (-not (Test-Path -LiteralPath $verifyReportPath -PathType Leaf)) {
    Add-Check 'il-lamp-pattern-groups' $false 'lamp-pattern verification report is missing'
}
else {
    $verifyReport = Get-Content -LiteralPath $verifyReportPath -Raw | ConvertFrom-Json
    $failedChecks = @($verifyReport.Checks | Where-Object { -not [bool]$_.Passed })
    $checkCount = @($verifyReport.Checks).Count
    Add-Check 'il-lamp-pattern-groups' ($failedChecks.Count -eq 0 -and $checkCount -eq 26) "checks=$checkCount, failed=$($failedChecks.Count)"
    Add-Check 'il-lamp-pattern-status' ([string]$verifyReport.Status -eq 'pass') "status=$($verifyReport.Status)"
    Add-Check 'il-lamp-pattern-stack' ([int]$verifyReport.MapEntryU -eq 0x066E -and [int]$verifyReport.MapEntryS -eq 0x0798 -and [int]$verifyReport.MapDeepestS -eq 0x078A) "entry=$('{0:X4}' -f [int]$verifyReport.MapEntryU)/$('{0:X4}' -f [int]$verifyReport.MapEntryS), deepest=$('{0:X4}' -f [int]$verifyReport.MapDeepestS)"
    Add-Check 'il-lamp-pattern-map-counts' ([int]$verifyReport.MapEntryCount -eq 44 -and [int]$verifyReport.MapInlineOperandCount -eq 4 -and [int]$verifyReport.MapPhaseCount -eq 43 -and [int]$verifyReport.MapBoundaryCount -eq 12) "entries=$($verifyReport.MapEntryCount), operands=$($verifyReport.MapInlineOperandCount), phases=$($verifyReport.MapPhaseCount), boundaries=$($verifyReport.MapBoundaryCount)"
}

# ---------------------------------------------------------------------------
# Final atomicity and provenance summary.
# ---------------------------------------------------------------------------
Assert-Equal (Get-HashHex ([IO.File]::ReadAllBytes($rom)) 'SHA256') $expectedOriginalSha256 'original unchanged after all controls'
Add-Check 'all-controls-leave-original-read-only' $true 'the private original ROM hash is unchanged after every control'

if ($script:failed) {
    Write-Log 'RESULT: FAIL'
}
else {
    Write-Log 'RESULT: PASS'
}

$reportObject = [ordered]@{
    schemaVersion = 1
    taskId = 'il-lamp-pattern-repair-60'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    result = if ($script:failed) { 'fail' } else { 'pass' }
    romPath = $rom
    romSha1 = Get-HashHex $originalBytes 'SHA1'
    romSha256 = Get-HashHex $originalBytes 'SHA256'
    outputRoot = $out
    checks = @($checks.ToArray())
    summary = [ordered]@{
        total = $checks.Count
        passed = @($checks | Where-Object { $_.ok }).Count
        failed = @($checks | Where-Object { -not $_.ok }).Count
    }
    boundaries = [ordered]@{
        trackedRomWritten = $false
        mameRun = $false
        hardwareTested = $false
        executionClaimed = $false
        classification = 'STATIC lamp-pattern builder, map, CLI and relative-stack controls only'
    }
}
$reportJson = ConvertTo-Json -InputObject $reportObject -Depth 8
$reportJson = $reportJson.Replace("`r`n", "`n")
[IO.File]::WriteAllText(
    (Join-Path $out 'checker-report.json'),
    $reportJson + "`n",
    (New-Object System.Text.UTF8Encoding($false)))
[IO.File]::WriteAllText(
    (Join-Path $out 'checker-log.txt'),
    (($log -join "`n") + "`n"),
    (New-Object System.Text.UTF8Encoding($false)))

if ($script:failed) { exit 1 }
exit 0

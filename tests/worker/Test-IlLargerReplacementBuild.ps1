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

$cliProject = Join-Path $repo 'tools/FruitMachineLab.IlLargerReplacementBuild/FruitMachineLab.IlLargerReplacementBuild.csproj'
$ilProject = Join-Path $repo 'tests/FruitMachineLab.IlVerification/FruitMachineLab.IlVerification.csproj'
$logRoot = Join-Path $out 'logs'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

$expectedOriginalSha1 = '402D1518BB78FDC489B06C2AABC771E5CE151847'
$expectedOriginalSha256 = 'EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C'
$expectedUnrepairedSha1 = '5ACD11F897005A9C80C4931460847BC4E6414FA5'
$expectedUnrepairedSha256 = 'F8B0CAAEFF6EA6ACF9B11F9E9CEF39D2F9A4346EBC11C5FB8245D76D40E235B9'
$expectedOutputSha1 = '7D81C9828A8A8C882861151E84B676AE05D272BF'
$expectedOutputSha256 = 'F693D70A73F1C12857CD64CA9DB9D68DE9BBC1888101ABC283FA2752C094B523'
$expectedFields = 'E93F3C61B5'
$expectedUnrepairedOffsets = @(
    0x1010, 0x1011, 0x1012, 0x1013, 0x1015, 0x1016, 0x1017, 0x1018,
    0x1019, 0x101B, 0x101C, 0x101D, 0x101E, 0x101F, 0x1020, 0x1021,
    0x1022, 0x1023, 0x1024, 0x1025, 0x9F14, 0x9F15
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
        'larger-unrepaired.p1',
        'larger-repaired.p1',
        'larger-replacement-source-map.json',
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
$unrepairedBytes = [IO.File]::ReadAllBytes((Join-Path $positive 'larger-unrepaired.p1'))
$repairedBytes = [IO.File]::ReadAllBytes((Join-Path $positive 'larger-repaired.p1'))
Assert-Equal (Get-HashHex $originalBytes 'SHA1') $expectedOriginalSha1 'original SHA1'
Assert-Equal (Get-HashHex $originalBytes 'SHA256') $expectedOriginalSha256 'original SHA256'
Assert-Equal (Get-HashHex $unrepairedBytes 'SHA1') $expectedUnrepairedSha1 'unrepaired SHA1'
Assert-Equal (Get-HashHex $unrepairedBytes 'SHA256') $expectedUnrepairedSha256 'unrepaired SHA256'
Assert-Equal (Get-HashHex $repairedBytes 'SHA1') $expectedOutputSha1 'repaired SHA1'
Assert-Equal (Get-HashHex $repairedBytes 'SHA256') $expectedOutputSha256 'repaired SHA256'
Add-Check 'positive-exact-hashes' $true 'original, unrepaired and repaired SHA1/SHA256 match the reviewed contract'

$unrepairedDiff = Get-DiffOffsets $originalBytes $unrepairedBytes
$finalDiff = Get-DiffOffsets $originalBytes $repairedBytes
Assert-Equal $unrepairedDiff.Count 22 'unrepaired diff count'
Assert-Equal $finalDiff.Count 27 'final diff count'
Assert-Equal (Format-Offsets $unrepairedDiff) (Format-Offsets $expectedUnrepairedOffsets) 'unrepaired diff offsets'
Assert-Equal (Format-Offsets $finalDiff) (Format-Offsets $expectedFinalOffsets) 'final diff offsets'
Assert-Equal $unrepairedBytes[0x1014] 0xFF '1014 remains FF'
Assert-Equal $unrepairedBytes[0x101A] 0xFF '101A remains FF'
Assert-Equal $repairedBytes[0x1014] 0xFF 'final 1014 remains FF'
Assert-Equal $repairedBytes[0x101A] 0xFF 'final 101A remains FF'
$fields = ([BitConverter]::ToString($repairedBytes[0xFFD1..0xFFD5])).Replace('-', '')
Assert-Equal $fields $expectedFields 'repaired fields'
Add-Check 'positive-diff-and-fields' $true '22 unrepaired and 27 final offsets; 1014/101A remain FF; fields E93F3C61B5'

$report = Get-Content -LiteralPath (Join-Path $positive 'build-report.json') -Raw | ConvertFrom-Json
Assert-Equal ([bool]$report.staticOnly) $true 'staticOnly'
Assert-Equal ([bool]$report.executionClaimed) $false 'executionClaimed'
Assert-Equal ([int]$report.unrepaired.changedCount) 22 'report unrepaired count'
Assert-Equal ([int]$report.repaired.changedCount) 27 'report final count'
Assert-Equal ([string]$report.integrity.repairedFieldsHex) $expectedFields 'report fields'
Assert-Equal ([string]$report.repaired.sha256) $expectedOutputSha256 'report repaired SHA256'
$map = Get-Content -LiteralPath (Join-Path $positive 'larger-replacement-source-map.json') -Raw | ConvertFrom-Json
Assert-Equal ([string]$map.OutputImageSha256) $expectedOutputSha256 'map build binding'
Assert-Equal ([int]@($map.Entries).Count) 30 'map entries'
Assert-Equal ([int]@($map.InlineOperands).Count) 3 'map inline operands'
Assert-Equal ([int]@($map.Phases).Count) 17 'map phases'
Add-Check 'positive-report-and-map' $true 'report is static-only and the map binds the exact repaired SHA256 with 30 entries, 3 operands and 17 phases'

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
    'larger-unrepaired.p1',
    'larger-repaired.p1',
    'larger-replacement-source-map.json',
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
# Negative payload/reachability control through the IL verifier.
# ---------------------------------------------------------------------------
$verifyOut = Join-Path $out 'il-verifier'
$verifyRun = Invoke-DotNet @(
    'run', '--project', $ilProject, '--no-build', '--', $rom, $verifyOut
) (Join-Path $logRoot 'il-verifier.log')
Add-Check 'il-verifier-exit' ($verifyRun.Exit -eq 0) "exit=$($verifyRun.Exit)"
$verifyReportPath = Join-Path $verifyOut 'larger-replacement/verification-report.json'
if (-not (Test-Path -LiteralPath $verifyReportPath -PathType Leaf)) {
    Add-Check 'negative-task48-reachability' $false 'larger-replacement verification report is missing'
}
else {
    $verifyReport = Get-Content -LiteralPath $verifyReportPath -Raw | ConvertFrom-Json
    $task48 = @($verifyReport.Checks) | Where-Object {
        [string]$_.Name -eq 'Task48 append-after-return is rejected by reachability'
    } | Select-Object -First 1
    if ($null -eq $task48 -or -not [bool]$task48.Passed) {
        Add-Check 'negative-task48-reachability' $false 'task48 reachability check did not pass'
    }
    else {
        Add-Check 'negative-task48-reachability' $true 'task48 early return is rejected by the flat reachability rule, not a hash mismatch'
    }
    $failedChecks = @($verifyReport.Checks | Where-Object { -not [bool]$_.Passed })
    Add-Check 'il-verifier-groups' ($failedChecks.Count -eq 0 -and @($verifyReport.Checks).Count -eq 11) "checks=$(@($verifyReport.Checks).Count), failed=$($failedChecks.Count)"
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
    taskId = 'il-larger-replacement-build-50'
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
        classification = 'STATIC builder, map, CLI and reachability controls only'
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

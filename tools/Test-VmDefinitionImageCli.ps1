param(
    [Parameter(Mandatory=$true)][string]$OriginalRom,
    [string]$RepositoryRoot = ''
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$original = [IO.Path]::GetFullPath($OriginalRom)
$definition = Join-Path $root 'evidence/mpu4/definitions/bias-word-signed-value-9ed9.vm.json'
$dll = Join-Path $root 'tools/FruitMachineLab.VmDefinitionImage/bin/Debug/net8.0/FruitMachineLab.VmDefinitionImage.dll'
if (!(Test-Path -LiteralPath $dll)) { throw "Build the emitter first: $dll" }
$expectedOriginalSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$expectedOriginalSha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
$expectedChangedSha1 = '51e81cc5f41da2aa659a4d14d277e9e78614eb6b'
$expectedChangedSha256 = 'a99d96f8ea8b4770d2d3828125f25894e831726fe44a79a37e0871faba135ed2'

function Get-HashHex([string]$Path, [string]$Algorithm) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        try { return [BitConverter]::ToString($hash.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}
function Invoke-Emitter([string]$Definition, [string]$Rom, [string]$Output, [string]$Log) {
    $ErrorActionPreference = 'Continue'
    & dotnet $dll $Definition $Rom $Output 2>&1 | Out-File -LiteralPath $Log -Encoding utf8
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    return $code
}
function Assert-Rejected([string]$Label, [string]$DefinitionPath, [string]$RomPath, [string]$Output, [string]$Log, [string]$ExpectedText, [string[]]$AllowedExisting = @()) {
    $code = Invoke-Emitter $DefinitionPath $RomPath $Output $Log
    if ($code -eq 0) { throw "$Label was accepted" }
    $unexpected = @(Get-ChildItem -LiteralPath $Output -File -ErrorAction SilentlyContinue |
        Where-Object { $AllowedExisting -notcontains $_.Name })
    if ($unexpected.Count -ne 0) {
        throw "$Label created early output: $($unexpected.Name -join ',')"
    }
    $text = Get-Content -LiteralPath $Log -Raw
    if (!$text.Contains($ExpectedText)) {
        throw "$Label rejection did not mention '$ExpectedText': $text"
    }
    if ($text.Contains('Unhandled exception')) { throw "$Label did not exit cleanly" }
    return $text
}

$run = Join-Path $root ('artifacts/vm-definition-image-cli-' + [Guid]::NewGuid().ToString('N'))
$logs = Join-Path $run 'logs'
New-Item -ItemType Directory $run, $logs | Out-Null
$originalSha1Before = Get-HashHex $original 'SHA1'
$originalSha256Before = Get-HashHex $original 'SHA256'
$definitionSha256Before = Get-HashHex $definition 'SHA256'
if ($originalSha1Before -ne $expectedOriginalSha1 -or $originalSha256Before -ne $expectedOriginalSha256) {
    throw 'Supplied original ROM is not the accepted original'
}

$valid = Join-Path $run 'valid'
New-Item -ItemType Directory $valid | Out-Null
$validLog = Join-Path $logs 'valid.txt'
$code = Invoke-Emitter $definition $original $valid $validLog
if ($code -ne 0) { throw "Valid emission failed: $(Get-Content -LiteralPath $validLog -Raw)" }
$originalOutput = Join-Path $valid 'original.p1'
$changedOutput = Join-Path $valid 'changed-9edc.p1'
$reportPath = Join-Path $valid 'emission.json'
foreach ($path in @($originalOutput, $changedOutput, $reportPath)) {
    if (!(Test-Path -LiteralPath $path)) { throw "Valid emission is missing $path" }
}
if ((Get-HashHex $originalOutput 'SHA1') -ne $expectedOriginalSha1 -or
    (Get-HashHex $originalOutput 'SHA256') -ne $expectedOriginalSha256) {
    throw 'Original output identity differs'
}
if ((Get-HashHex $changedOutput 'SHA1') -ne $expectedChangedSha1 -or
    (Get-HashHex $changedOutput 'SHA256') -ne $expectedChangedSha256) {
    throw 'Changed output hashes differ'
}
[byte[]]$originalBytes = [IO.File]::ReadAllBytes($originalOutput)
[byte[]]$changedBytes = [IO.File]::ReadAllBytes($changedOutput)
if ($originalBytes.Length -ne 65536 -or $changedBytes.Length -ne 65536) { throw 'Output length differs' }
$offsets = New-Object System.Collections.Generic.List[int]
for ($i = 0; $i -lt $originalBytes.Length; $i++) {
    if ($originalBytes[$i] -ne $changedBytes[$i]) { $offsets.Add($i) }
}
if ($offsets.Count -ne 1 -or $offsets[0] -ne 0x9EDC) { throw "Changed offsets are not only 9EDC: $($offsets -join ',')" }
if ($originalBytes[0x9EDC] -ne 0x80 -or $changedBytes[0x9EDC] -ne 0x00) {
    throw 'Changed operand byte is not 80 -> 00'
}
$report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
if ($report.definition.address -ne '9ED9' -or $report.original.length -ne 65536 -or
    $report.changed.length -ne 65536 -or $report.changed.changed_offsets.Count -ne 1 -or
    [int]$report.changed.changed_offsets[0] -ne 0x9EDC -or
    $report.changed.changed_offsets_hex[0] -ne '9EDC' -or
    $report.literal.original -ne 'FF80' -or $report.literal.replacement -ne 'FF00') {
    throw 'Emission report contract differs'
}
foreach ($name in @('original_length_matches_fixed','original_sha1_matches_fixed','original_sha256_matches_fixed',
                    'definition_token_contract','definition_original_span','reference_unchanged',
                    'exactly_one_changed_offset','changed_offset_is_9edc',
                    'changed_sha1_matches_fixed','changed_sha256_matches_fixed',
                    'checksum_fields_unchanged','original_readback','changed_readback','inputs_preserved')) {
    if ($report.checks.$name -ne $true) { throw "Emission report check differs: $name" }
}

$repeat = Join-Path $run 'repeat'
New-Item -ItemType Directory $repeat | Out-Null
$repeatLog = Join-Path $logs 'repeat.txt'
$code = Invoke-Emitter $definition $original $repeat $repeatLog
if ($code -ne 0 -or (Get-HashHex (Join-Path $repeat 'changed-9edc.p1') 'SHA1') -ne $expectedChangedSha1) {
    throw 'Emission is not reproducible'
}

$existingReport = Join-Path $run 'existing-report'
New-Item -ItemType Directory $existingReport | Out-Null
$sentinelReport = Join-Path $existingReport 'emission.json'
Set-Content -LiteralPath $sentinelReport -Value 'sentinel-report' -NoNewline
Assert-Rejected 'Existing report' $definition $original $existingReport (Join-Path $logs 'existing-report.txt') 'target already exists' @('emission.json') | Out-Null
if ((Get-Content -LiteralPath $sentinelReport -Raw) -ne 'sentinel-report') { throw 'Existing report was overwritten' }
foreach ($path in @((Join-Path $existingReport 'original.p1'), (Join-Path $existingReport 'changed-9edc.p1'))) {
    if (Test-Path -LiteralPath $path) { throw 'Existing report produced an early output' }
}

$existingSecond = Join-Path $run 'existing-second'
New-Item -ItemType Directory $existingSecond | Out-Null
$sentinelSecond = Join-Path $existingSecond 'changed-9edc.p1'
[IO.File]::WriteAllBytes($sentinelSecond, [byte[]](1, 2, 3))
$secondHash = Get-HashHex $sentinelSecond 'SHA256'
Assert-Rejected 'Existing second output' $definition $original $existingSecond (Join-Path $logs 'existing-second.txt') 'target already exists' @('changed-9edc.p1') | Out-Null
if ((Get-HashHex $sentinelSecond 'SHA256') -ne $secondHash) { throw 'Existing second output was overwritten' }
foreach ($path in @((Join-Path $existingSecond 'original.p1'), (Join-Path $existingSecond 'emission.json'))) {
    if (Test-Path -LiteralPath $path) { throw 'Existing second output produced an early output' }
}

$wrongRom = Join-Path $run 'wrong-original.p1'
[byte[]]$wrongBytes = [IO.File]::ReadAllBytes($original)
$wrongBytes[0] = $wrongBytes[0] -bxor 0xFF
[IO.File]::WriteAllBytes($wrongRom, $wrongBytes)
$wrongRomOutput = Join-Path $run 'wrong-rom-output'
New-Item -ItemType Directory $wrongRomOutput | Out-Null
Assert-Rejected 'Wrong image identity' $definition $wrongRom $wrongRomOutput (Join-Path $logs 'wrong-rom.txt') 'original ROM SHA1' | Out-Null

$wrongDefinition = Join-Path $run 'wrong-definition.vm.json'
$wrongJson = (Get-Content -LiteralPath $definition -Raw).Replace(
    '402D1518BB78FDC489B06C2AABC771E5CE151847', '0000000000000000000000000000000000000000')
if ($wrongJson -eq (Get-Content -LiteralPath $definition -Raw)) { throw 'Wrong-definition fixture did not change' }
Set-Content -LiteralPath $wrongDefinition -Value $wrongJson -NoNewline
$wrongDefinitionOutput = Join-Path $run 'wrong-definition-output'
New-Item -ItemType Directory $wrongDefinitionOutput | Out-Null
Assert-Rejected 'Wrong definition identity' $wrongDefinition $original $wrongDefinitionOutput (Join-Path $logs 'wrong-definition.txt') 'definition ROM SHA1' | Out-Null

$wrongPairRom = Join-Path $run 'wrong-pair.p1'
[byte[]]$wrongPairBytes = [IO.File]::ReadAllBytes($original)
$wrongPairBytes[$wrongPairBytes.Length - 1] = $wrongPairBytes[$wrongPairBytes.Length - 1] -bxor 0xFF
[IO.File]::WriteAllBytes($wrongPairRom, $wrongPairBytes)
$wrongPairSha1 = (Get-HashHex $wrongPairRom 'SHA1').ToUpperInvariant()
$wrongPairDefinition = Join-Path $run 'wrong-pair.vm.json'
$wrongPairJson = (Get-Content -LiteralPath $definition -Raw).Replace(
    '402D1518BB78FDC489B06C2AABC771E5CE151847', $wrongPairSha1)
Set-Content -LiteralPath $wrongPairDefinition -Value $wrongPairJson -NoNewline
$wrongPairOutput = Join-Path $run 'wrong-pair-output'
New-Item -ItemType Directory $wrongPairOutput | Out-Null
Assert-Rejected 'Self-consistent wrong pair' $wrongPairDefinition $wrongPairRom $wrongPairOutput (Join-Path $logs 'wrong-pair.txt') 'original ROM SHA1' | Out-Null

$shortRom = Join-Path $run 'short.p1'
$shortBytes = New-Object byte[] ($wrongBytes.Length - 1)
[Array]::Copy($wrongBytes, $shortBytes, $shortBytes.Length)
[IO.File]::WriteAllBytes($shortRom, $shortBytes)
$shortOutput = Join-Path $run 'short-output'
New-Item -ItemType Directory $shortOutput | Out-Null
Assert-Rejected 'Wrong original length' $definition $shortRom $shortOutput (Join-Path $logs 'short.txt') 'original ROM length' | Out-Null

if ((Get-HashHex $original 'SHA1') -ne $originalSha1Before -or
    (Get-HashHex $original 'SHA256') -ne $originalSha256Before -or
    (Get-HashHex $definition 'SHA256') -ne $definitionSha256Before) {
    throw 'Input ROM or definition was modified'
}

Write-Output 'PASS emitter exact identity/span/token preflight, only9EDC checksum preservation, create-new report/second-output rejection, no early outputs, input preservation and valid exact hashes'

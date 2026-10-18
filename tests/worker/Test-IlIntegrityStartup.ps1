$ErrorActionPreference = 'Stop'

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$captureScript = Join-Path $repo 'tools/Capture-IlIntegrityStartup.ps1'
$curatorScript = Join-Path $repo 'tools/Curate-IlIntegrityStartup.ps1'
. $captureScript
. $curatorScript

$script:Failures = 0
$script:Checks = 0

function Write-Pass([string]$Message) {
    $script:Checks++
    Write-Output "PASS: $Message"
}

function Write-Fail([string]$Message) {
    $script:Checks++
    $script:Failures++
    Write-Output "FAIL: $Message"
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { Write-Pass $Message } else { Write-Fail $Message }
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ([string]$Actual -eq [string]$Expected) { Write-Pass $Message }
    else { Write-Fail "$Message (actual '$Actual', expected '$Expected')" }
}

function Assert-Throws {
    param([string]$Name, [scriptblock]$Block, [string]$Pattern)
    try {
        & $Block | Out-Null
        Write-Fail "$Name was not rejected"
    }
    catch {
        $message = $_.Exception.Message
        if ($message -match $Pattern) { Write-Pass "$Name rejected: $message" }
        else { Write-Fail "$Name rejected with unexpected message: $message" }
    }
}

function New-Log {
    param([string]$Fields = 'BEF69E7CC7')
    $sum = $Fields.Substring(0, 2)
    $xor = $Fields.Substring(2, 2)
    $rotateAdd = $Fields.Substring(4, 2)
    $rotateSubA = $Fields.Substring(6, 2)
    $rotateSubB = $Fields.Substring(8, 2)
    return @(
        'ILBOOT_RESET pc=7CD1 s=07C2 cc=D0',
        'ILBOOT_INIT_ENTRY pc=6750 u=0672',
        'ILBOOT_ROM_CHECK_ENTRY pc=66A5 u=0672 gate719b=00',
        "ILBOOT_ROM_VERIFY_ENTRY pc=66DB u=066A expected=$Fields start=1400 end=FFFF error=12",
        "ILBOOT_SUM_XOR sum=$sum xor=$xor",
        "ILBOOT_ROTATE_ADD value=$rotateAdd",
        "ILBOOT_ROTATE_SUB_XOR a=$rotateSubA b=$rotateSubB",
        'ILBOOT_ROM_CHECK_RETURN pc=677E y=FFFF u=0672',
        'ILBOOT_INIT_TAIL_JMP pc=67B3 y=0000 u=0672',
        'ILBOOT_INIT_TAIL_ENTRY pc=3B1A y=0000 u=0672',
        'ILBOOT_VM_CALL pc=7CF6 x=FDF0 y=02DA u=0672',
        'ILBOOT_VM_ENTRY pc=76C7 x=FDF0 y=02DA u=0672 s=07C6 first_word=76ED',
        'ILBOOT_CAPTURE_END pc=76C7 x=FDF0 y=02DA u=0672 s=07C6 first_word=76ED'
    ) -join "`r`n"
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('fm-ilboot04-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    $valid = New-Log
    $facts = Test-IlStartupLog $valid 'BEF69E7CC7'
    Assert-Equal $facts.expected_fields 'BEF69E7CC7' 'valid repaired log yields the expected fields'
    Assert-Equal $facts.computed_fields 'BEF69E7CC7' 'valid repaired log yields matching computed fields'
    Assert-Equal $facts.initial_stream_pointer 'FDF0' 'valid repaired log yields X=FDF0 at VM entry'
    Assert-Equal $facts.first_stream_word '76ED' 'valid repaired log records the unfetched stream head'

    $originalFacts = Test-IlStartupLog (New-Log '3E761E2605') '3E761E2605'
    Assert-Equal $originalFacts.expected_fields '3E761E2605' 'valid original log yields the original fields'

    $missingReset = [regex]::Replace($valid, '(?m)^ILBOOT_RESET[^\r\n]*\r?\n', '')
    Assert-Throws 'missing reset marker' { Test-IlStartupLog $missingReset 'BEF69E7CC7' } 'Missing reset marker'

    $missingRotate = [regex]::Replace($valid, '(?m)^ILBOOT_ROTATE_SUB_XOR[^\r\n]*\r?\n', '')
    Assert-Throws 'missing rotate-sub marker' { Test-IlStartupLog $missingRotate 'BEF69E7CC7' } 'before rotate-sub-XOR|missing or out of order|Incomplete'

    $missingVm = [regex]::Replace($valid, '(?m)^ILBOOT_VM_ENTRY[^\r\n]*\r?\n', '')
    Assert-Throws 'missing VM entry marker' { Test-IlStartupLog $missingVm 'BEF69E7CC7' } 'Expected exactly one VM entry|missing or out of order'

    $failure = $valid.Replace('ILBOOT_INIT_TAIL_JMP', "ILBOOT_ROM_VERIFY_FAILED error=12`r`nILBOOT_INIT_TAIL_JMP")
    Assert-Throws 'firmware failure marker' { Test-IlStartupLog $failure 'BEF69E7CC7' } 'failure marker'

    $sumLine = 'ILBOOT_SUM_XOR sum=BE xor=F6'
    $rotateLine = 'ILBOOT_ROTATE_ADD value=9E'
    $unordered = $valid.Replace($sumLine, '__SUM__').Replace($rotateLine, $sumLine).Replace('__SUM__', $rotateLine)
    Assert-Throws 'unordered checksum phases' { Test-IlStartupLog $unordered 'BEF69E7CC7' } 'before sum/XOR|missing or out of order'

    $firstMismatch = $valid.Replace('ILBOOT_SUM_XOR sum=BE xor=F6', 'ILBOOT_SUM_XOR sum=00 xor=F6')
    Assert-Throws 'first checksum mismatch' { Test-IlStartupLog $firstMismatch 'BEF69E7CC7' } 'first mismatch'

    $wrongExpected = $valid.Replace('expected=BEF69E7CC7', 'expected=3E761E2605')
    Assert-Throws 'wrong expected fields' { Test-IlStartupLog $wrongExpected 'BEF69E7CC7' } 'first mismatch'

    $afterEnd = $valid + "`r`nILBOOT_VM_CALL pc=7CF6 x=FDF0 y=02DA u=0672"
    Assert-Throws 'marker after capture end' { Test-IlStartupLog $afterEnd 'BEF69E7CC7' } 'after ILBOOT_CAPTURE_END'

    $fields = $script:IlCurationVariants['Repaired']
    $goodProvenance = [pscustomobject]@{
        original_rom_sha1 = $script:IlCurationOriginalSha1
        original_rom_sha256 = $script:IlCurationOriginalSha256
        expected_variant_sha1 = $fields.Sha1
        expected_variant_sha256 = $fields.Sha256
        run_rom_sha1 = $fields.Sha1
        run_rom_sha256 = $fields.Sha256
    }
    $goodObservation = [pscustomobject]@{
        original_rom_sha1 = $script:IlCurationOriginalSha1
        original_rom_sha256 = $script:IlCurationOriginalSha256
        expected_variant_sha1 = $fields.Sha1
        expected_variant_sha256 = $fields.Sha256
        run_rom_sha1_after = $fields.Sha1
        run_rom_sha256_after = $fields.Sha256
    }
    Assert-IlCurationIdentityRecord $goodProvenance $goodObservation $fields.Sha1 $fields.Sha256
    Write-Pass 'matching provenance/observation identity is accepted'

    $staleObservation = [pscustomobject]@{
        original_rom_sha1 = ('0' * 40)
        original_rom_sha256 = $script:IlCurationOriginalSha256
        expected_variant_sha1 = $fields.Sha1
        expected_variant_sha256 = $fields.Sha256
        run_rom_sha1_after = $fields.Sha1
        run_rom_sha256_after = $fields.Sha256
    }
    Assert-Throws 'stale observation identity' { Assert-IlCurationIdentityRecord $goodProvenance $staleObservation $fields.Sha1 $fields.Sha256 } 'Observation original ROM SHA1'

    $syntheticRom = Join-Path $tempRoot 'synthetic.p1'
    $romBytes = New-Object byte[] 65536
    for ($i = 0; $i -lt $romBytes.Length; $i++) { $romBytes[$i] = [byte]($i % 251) }
    [IO.File]::WriteAllBytes($syntheticRom, $romBytes)
    $syntheticSha1 = Get-IlCurationHashHex $syntheticRom 'SHA1'
    $syntheticSha256 = Get-IlCurationHashHex $syntheticRom 'SHA256'
    Assert-IlCurationRomIdentity $syntheticRom $syntheticSha1 $syntheticSha256 'synthetic ROM' | Out-Null
    Write-Pass 'synthetic ROM identity is accepted when the hashes match'
    Assert-Throws 'wrong ROM identity' { Assert-IlCurationRomIdentity $syntheticRom ('0' * 40) $syntheticSha256 'synthetic ROM' } 'SHA1'

    $a = New-Object byte[] 8
    $b = New-Object byte[] 8
    $b[2] = 1
    $b[5] = 2
    $changed = Get-IlCurationChangedOffsets $a $b
    Assert-Equal (Format-IlCurationOffsets $changed) '0002,0005' 'changed-offset helper finds exact offsets'
    Assert-IlCurationChangedOffsets $changed @(2,5) 'synthetic image'
    Write-Pass 'matching changed-offset set is accepted'
    Assert-Throws 'wrong changed-offset set' { Assert-IlCurationChangedOffsets $changed @(2,6) 'synthetic image' } 'changed offsets differ'
    Assert-IlBootChangedOffsets (Get-IlBootChangedOffsets $a $b) @(2,5) 'synthetic capture image'
    Write-Pass 'capture changed-offset helper agrees with the curator helper'

    $existingRun = Join-Path $tempRoot 'existing-run'
    New-Item -ItemType Directory -Path $existingRun | Out-Null
    Assert-Throws 'create-only run directory collision' { New-IlBootRunDirectory $existingRun } 'create-only'
    $newRun = Join-Path $tempRoot 'new-run'
    $created = New-IlBootRunDirectory $newRun
    Assert-True (Test-Path -LiteralPath (Join-Path $created 'roms/m4addr') -PathType Container) 'fresh run directory creates isolated subdirectories'
    Assert-Throws 'second create-only run collision' { New-IlBootRunDirectory $newRun } 'create-only'

    $existingOutput = Join-Path $tempRoot 'existing-output.json'
    Set-Content -LiteralPath $existingOutput -Value 'synthetic'
    Assert-Throws 'create-only curated output collision' { Assert-IlCurationOutputAvailable $existingOutput } 'create-only'
    $newOutput = Assert-IlCurationOutputAvailable (Join-Path $tempRoot 'new-output.json')
    Assert-True ($newOutput.EndsWith('new-output.json')) 'fresh curated output path is accepted'
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output ("{0} checks, {1} failures" -f $script:Checks, $script:Failures)
if ($script:Failures -ne 0) { exit 1 }
exit 0

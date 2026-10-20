param(
    [Parameter(Mandatory=$true)][string]$OriginalRom,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [int]$DelayCount = 3000
)
$ErrorActionPreference = 'Stop'

$ExpectedOriginalSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$ExpectedOriginalSha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
$OriginalLength = 65536
$FieldBase = 0xFFD1
$RangeStart = 0x1400
$RangeEnd = 0xFFFF
$AllocationStart = 0x1010
$AllocationLimit = 0x13EF
$TableEntryAddresses = @(0xE211, 0xE217, 0xE21F)
$ExpectedTableEntry = 'D001'
$ReplacementTableEntry = '1010'

$bottomRow = @(0,1,2,3,4,5)
$topRow = @(42,43,44,45,46,47)
$middleUpper = @(18,19,20,21,22,23)
$middleLower = @(24,25,26,27,28,29)

function Get-Sha([byte[]]$Bytes, [string]$Algorithm) {
    $h = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
    try { return ([BitConverter]::ToString($h.ComputeHash($Bytes))).Replace('-','').ToUpperInvariant() }
    finally { $h.Dispose() }
}
function Get-ShaFile([string]$Path, [string]$Algorithm) {
    $h = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
    $s = [IO.File]::OpenRead($Path)
    try { return ([BitConverter]::ToString($h.ComputeHash($s))).Replace('-','').ToUpperInvariant() }
    finally { $s.Dispose(); $h.Dispose() }
}
function Convert-HexToBytes([string]$Hex) {
    if (($Hex.Length % 2) -ne 0) { throw 'Hex text has odd length' }
    $b = New-Object byte[] ($Hex.Length / 2)
    for ($i = 0; $i -lt $b.Length; $i++) { $b[$i] = [Convert]::ToByte($Hex.Substring($i * 2, 2), 16) }
    return ,$b
}
function Get-Hex([byte[]]$Bytes) { return (($Bytes | ForEach-Object { $_.ToString('X2') }) -join '') }
function Get-ChangedOffsets([byte[]]$Before, [byte[]]$After) {
    $changed = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -lt $Before.Length; $i++) { if ($Before[$i] -ne $After[$i]) { $changed.Add($i) } }
    return $changed.ToArray()
}
function Invoke-SumXor([byte[]]$Bytes, [int]$Start, [int]$End) {
    [int]$sum = 0; [int]$xor = 0; [int]$p = $Start
    while ($true) {
        [int]$v = $Bytes[$p]
        $sum = ($sum + $v) -band 0xFF
        $xor = $xor -bxor $v
        if ($p -eq $End) { break }
        $p++
        if ($p -eq 0xFFD1) { $p = 0xFFD6 }
    }
    return @($sum, $xor)
}
function Invoke-RotateAdd([byte[]]$Bytes, [int]$Start, [int]$End) {
    [int]$a = 0; [int]$b = 0; [int]$c = 0; [int]$p = $Start
    while ($true) {
        [int]$v = $Bytes[$p]
        $n = ($b -shr 7) -band 1
        $b = (($b -shl 1) -bor $c) -band 0xFF
        $c = $n
        $t = $a + $v + $c
        $a = $t -band 0xFF
        $c = ($t -shr 8) -band 1
        $n = $b -band 1
        $b = (($c -shl 7) -bor ($b -shr 1)) -band 0xFF
        $c = $n
        if ($p -eq $End) { break }
        $p++
        if ($p -eq 0xFFD3) { $p = 0xFFD6 }
        if ($p -lt 0xFFD3) { $c = 1 } else { $c = 0 }
    }
    return $a
}
function Invoke-RotateSubXor([byte[]]$Bytes, [int]$Start, [int]$End) {
    [int]$a = 0; [int]$b = 0; [int]$c = 0; [int]$p = $Start
    while ($true) {
        [int]$v = $Bytes[$p]
        $n = ($b -shr 7) -band 1
        $b = ($b -shl 1) -band 0xFF
        $c = $n
        $t = $b + $c
        $b = $t -band 0xFF
        $c = ($t -shr 8) -band 1
        $t = $b - $v
        $b = $t -band 0xFF
        if ($t -lt 0) { $c = 1 } else { $c = 0 }
        $savedB = $b
        $b = $a
        for ($i = 0; $i -lt 3; $i++) {
            $c = $b -band 1
            $b = (($b -shr 1) -bor ($b -band 0x80)) -band 0xFF
            $a = (($c -shl 7) -bor ($a -shr 1)) -band 0xFF
        }
        $b = $savedB
        $a = $a -bxor $v
        if ($p -eq $End) { break }
        $p++
        if ($p -eq 0xFFD4) { $p = 0xFFD6 }
    }
    return @($a, $b)
}
function Get-Fields([byte[]]$Bytes) {
    $s = Invoke-SumXor $Bytes $RangeStart $RangeEnd
    $r = Invoke-RotateAdd $Bytes $RangeStart $RangeEnd
    $t = Invoke-RotateSubXor $Bytes $RangeStart $RangeEnd
    return ('{0:X2}{1:X2}{2:X2}{3:X2}{4:X2}' -f $s[0], $s[1], $r, $t[0], $t[1])
}
function Get-Word([byte[]]$Bytes, [int]$Address) { return [int]$Bytes[$Address] * 256 + [int]$Bytes[$Address + 1] }
function Assert-Span([byte[]]$Bytes, [int]$Address, [string]$ExpectedHex, [string]$Label) {
    $expected = Convert-HexToBytes $ExpectedHex
    for ($i = 0; $i -lt $expected.Length; $i++) {
        if ($Bytes[$Address + $i] -ne $expected[$i]) {
            throw ('{0} at 0x{1:X4} is {2}, expected {3}' -f $Label, ($Address + $i), $Bytes[$Address + $i].ToString('X2'), $expected[$i].ToString('X2'))
        }
    }
}

if (!(Test-Path -LiteralPath $OriginalRom)) { throw "original ROM not found: $OriginalRom" }
$original = [IO.File]::ReadAllBytes(([IO.Path]::GetFullPath($OriginalRom)))
if ($original.Length -ne $OriginalLength) { throw "unexpected original length $($original.Length)" }
$sha1 = Get-Sha $original 'SHA1'
$sha256 = Get-Sha $original 'SHA256'
if ($sha1 -ne $ExpectedOriginalSha1.ToUpperInvariant() -or $sha256 -ne $ExpectedOriginalSha256.ToUpperInvariant()) {
    throw "original identity mismatch sha1=$sha1 sha256=$sha256"
}
$originalFields = Get-Fields $original
if ($originalFields -ne '3E761E2605') { throw "original fields $originalFields differ from 3E761E2605" }
$storedFields = Get-Hex $original[$FieldBase..($FieldBase+4)]
if ($storedFields -ne $originalFields) { throw "original stored fields $storedFields differ from computed $originalFields" }

Assert-Span $original 0x9C44 '9B1572BF' '9C44 lamp call cell'
Assert-Span $original 0x72BF '78191A3B3C1D70111233341568090A2B2C0D60010223240558393A1B1C3D50313213143548292A0B0C2D402122030425' '72BF lamp table'
foreach ($a in $TableEntryAddresses) {
    $actual = Get-Hex $original[$a..($a+1)]
    if ($actual -ne $ExpectedTableEntry) { throw ('table entry at 0x{0:X4} is {1}, expected {2}' -f $a, $actual, $ExpectedTableEntry) }
}
for ($i = 0x1000; $i -le 0x100F; $i++) { if ($original[$i] -ne 0xFF) { throw ('left guard byte at 0x{0:X4} is not FF' -f $i) } }
for ($i = 0x13F0; $i -le 0x13FF; $i++) { if ($original[$i] -ne 0xFF) { throw ('right guard byte at 0x{0:X4} is not FF' -f $i) } }

function Add-TokenTo($list, [int]$Token) { $list.Add([byte]($Token -shr 8)); $list.Add([byte]($Token -band 0xFF)) }
function Add-ByteLiteralTo($list, [int]$Value) { Add-TokenTo $list 0x7963; $list.Add([byte]$Value) }
function Add-WordLiteralTo($list, [int]$Value) { Add-TokenTo $list 0x795B; $list.Add([byte](($Value -shr 8) -band 0xFF)); $list.Add([byte]($Value -band 0xFF)) }
function Add-LampTo($list, [int]$Index, [int]$Pattern) { Add-ByteLiteralTo $list $Index; Add-ByteLiteralTo $list $Pattern; Add-TokenTo $list 0x9C44 }
function Add-CountdownWaitTo($list, [int]$Iterations) {
    Add-WordLiteralTo $list $Iterations
    foreach ($v in @(0x78,0xD3,0x7B,0x51,0x7A,0x46,0x79,0xA6,0xF8,0x7B,0x3D)) { $list.Add([byte]$v) }
}
function Add-RowOnTo($list, [int[]]$Row) { foreach ($i in $Row) { Add-LampTo $list $i 0x8F } }
function Add-RowOffTo($list, [int[]]$Row) { foreach ($i in $Row) { Add-LampTo $list $i 0x80 } }

$bBody = New-Object System.Collections.Generic.List[byte]
Add-RowOnTo $bBody $middleUpper
Add-CountdownWaitTo $bBody $DelayCount
Add-RowOffTo $bBody $middleUpper
Add-RowOnTo $bBody $middleLower
Add-CountdownWaitTo $bBody $DelayCount

$aBody = New-Object System.Collections.Generic.List[byte]
Add-RowOnTo $aBody $topRow
Add-CountdownWaitTo $aBody $DelayCount
Add-RowOffTo $aBody $topRow
Add-RowOnTo $aBody $bottomRow
Add-CountdownWaitTo $aBody $DelayCount

$payload = New-Object System.Collections.Generic.List[byte]
$codeLog = New-Object System.Collections.Generic.List[string]
Add-TokenTo $payload 0x00F8
$codeLog.Add('1010 00F8 word header')
$clearStart = 0x1010 + $payload.Count
foreach ($row in @($bottomRow, $topRow, $middleUpper, $middleLower)) { Add-RowOffTo $payload $row }
$codeLog.Add(('common clear rows 0..5,18..23,24..29,42..47 (0x{0:X4}..0x{1:X4})' -f $clearStart, (0x1010 + $payload.Count - 1)))

Add-TokenTo $payload 0x83FC
$codeLog.Add(('0x{0:X4} 83FC original Start input test (selector 0x12, mask 0x80, sampled RAM 0003)' -f (0x1010 + $payload.Count - 2)))
Add-TokenTo $payload 0x7982
$branchOperandAddress = 0x1010 + $payload.Count
$payload.Add(0x05)
$codeLog.Add(('0x{0:X4} 7982 branch +5 if Start not pressed (result 0000) to unpressed trampoline' -f ($branchOperandAddress - 2)))

Add-TokenTo $payload 0x79B0
$pressedTargetOperandAddress = 0x1010 + $payload.Count
$payload.Add(0x00); $payload.Add(0x00)
Add-TokenTo $payload 0x79B0
$unpressedTargetOperandAddress = 0x1010 + $payload.Count
$payload.Add(0x00); $payload.Add(0x00)

$bStart = 0x1010 + $payload.Count
foreach ($v in $bBody) { $payload.Add($v) }
$bJumpOperandAddress = 0x1010 + $payload.Count + 2
Add-TokenTo $payload 0x79B0
$payload.Add(0x00); $payload.Add(0x00)

$aStart = 0x1010 + $payload.Count
foreach ($v in $aBody) { $payload.Add($v) }
$cleanupStart = 0x1010 + $payload.Count
foreach ($row in @($bottomRow, $topRow, $middleUpper, $middleLower)) { Add-RowOffTo $payload $row }
$codeLog.Add(('final clear rows 0..5,18..23,24..29,42..47 (0x{0:X4}..0x{1:X4})' -f $cleanupStart, (0x1010 + $payload.Count - 1)))
Add-TokenTo $payload 0x79B0
$payload.Add(0xD0); $payload.Add(0x03)
$codeLog.Add(('branch to original Snake Bite body D003 at 0x{0:X4}' -f (0x1010 + $payload.Count - 4)))

$allocationLength = $payload.Count
$allocationEnd = $AllocationStart + $allocationLength - 1
if ($allocationEnd -gt $AllocationLimit) { throw ('allocation overflow: 0x{0:X4}..0x{1:X4} exceeds 0x{2:X4}' -f $AllocationStart, $allocationEnd, $AllocationLimit) }
for ($i = $AllocationStart; $i -le $allocationEnd; $i++) {
    if ($original[$i] -ne 0xFF) { throw ('allocation byte at 0x{0:X4} is {1}, expected FF' -f $i, $original[$i].ToString('X2')) }
}
$payloadBytes = $payload.ToArray()
if ($payloadBytes[0] -ne 0x00 -or $payloadBytes[1] -ne 0xF8) { throw 'payload header is not 00F8' }
if ((Get-Hex $payloadBytes[($payloadBytes.Length-4)..($payloadBytes.Length-1)]) -ne '79B0D003') { throw 'payload does not end with 79B0 D003' }
if ($bStart -ne ($branchOperandAddress + 0x05 + 4)) { throw ('pressed trampoline target mismatch: bStart=0x{0:X4}' -f $bStart) }
if ($aStart -ne ($bStart + $bBody.Count + 4)) { throw ('unpressed trampoline target mismatch: aStart=0x{0:X4}' -f $aStart) }
$pressedIndex = $pressedTargetOperandAddress - 0x1010
$unpressedIndex = $unpressedTargetOperandAddress - 0x1010
$bJumpIndex = $bJumpOperandAddress - 0x1010
$payload[$pressedIndex] = [byte]($bStart -shr 8); $payload[$pressedIndex+1] = [byte]($bStart -band 0xFF)
$payload[$unpressedIndex] = [byte]($aStart -shr 8); $payload[$unpressedIndex+1] = [byte]($aStart -band 0xFF)
$payload[$bJumpIndex] = [byte]($cleanupStart -shr 8); $payload[$bJumpIndex+1] = [byte]($cleanupStart -band 0xFF)
$payloadBytes = $payload.ToArray()

$out = [IO.Path]::GetFullPath($OutputDirectory)
if ([IO.File]::Exists($out)) { throw "output path is a file: $out" }
if (![IO.Directory]::Exists($out)) { New-Item -ItemType Directory -Path $out | Out-Null }
$unrepairedPath = Join-Path $out 'input-switch-unrepaired.p1'
$repairedPath = Join-Path $out 'input-switch-repaired.p1'
$recordPath = Join-Path $out 'patch-record.json'
foreach ($p in @($unrepairedPath, $repairedPath, $recordPath)) { if ([IO.File]::Exists($p) -or [IO.Directory]::Exists($p)) { throw "output already exists: $p" } }

$image = [byte[]]$original.Clone()
for ($i = 0; $i -lt $allocationLength; $i++) { $image[$AllocationStart + $i] = $payloadBytes[$i] }
$replacement = Convert-HexToBytes $ReplacementTableEntry
foreach ($a in $TableEntryAddresses) { $image[$a] = $replacement[0]; $image[$a+1] = $replacement[1] }

$changed = Get-ChangedOffsets $original $image
$expectedChanged = @()
for ($i = 0; $i -lt $allocationLength; $i++) { $expectedChanged += ($AllocationStart + $i) }
foreach ($a in $TableEntryAddresses) { $expectedChanged += $a; $expectedChanged += ($a + 1) }
$expectedChanged = @($expectedChanged | Sort-Object)
if ((Compare-Object $changed $expectedChanged)) { throw 'unrepaired changed offsets differ from the reviewed patch' }
foreach ($i in $changed) {
    if ($i -ge 0x1000 -and $i -le 0x100F) { throw 'patch touched left guard' }
    if ($i -ge 0x13F0 -and $i -le 0x13FF) { throw 'patch touched right guard' }
}
if ((Get-Hex $image[$FieldBase..($FieldBase+4)]) -ne $originalFields) { throw 'unrepaired patch pre-modified integrity fields' }

[IO.File]::WriteAllBytes($unrepairedPath, $image)
$repaired = [byte[]]$image.Clone()
$sx = Invoke-SumXor $repaired $RangeStart $RangeEnd
$repaired[$FieldBase] = [byte]$sx[0]
$repaired[$FieldBase + 1] = [byte]$sx[1]
$ra = Invoke-RotateAdd $repaired $RangeStart $RangeEnd
$repaired[$FieldBase + 2] = [byte]$ra
$rs = Invoke-RotateSubXor $repaired $RangeStart $RangeEnd
$repaired[$FieldBase + 3] = [byte]$rs[0]
$repaired[$FieldBase + 4] = [byte]$rs[1]
$computed = ('{0:X2}{1:X2}{2:X2}{3:X2}{4:X2}' -f $sx[0],$sx[1],$ra,$rs[0],$rs[1])
[IO.File]::WriteAllBytes($repairedPath, $repaired)

$verify = Get-Fields $repaired
$stored = Get-Hex $repaired[$FieldBase..($FieldBase+4)]
if ($stored -ne $verify) { throw "repaired stored fields $stored differ from computed $verify" }
if ($stored -ne $computed) { throw "repaired stored fields $stored differ from the ordered computation $computed" }
if ((Get-Hex $repaired[$AllocationStart..$allocationEnd]) -ne (Get-Hex $payloadBytes)) { throw 'repaired allocation differs' }
foreach ($a in $TableEntryAddresses) { if ((Get-Hex $repaired[$a..($a+1)]) -ne $ReplacementTableEntry) { throw 'repaired table entry differs' } }
for ($i = 0x1000; $i -le 0x100F; $i++) { if ($repaired[$i] -ne $original[$i]) { throw 'left guard changed after repair' } }
for ($i = 0x13F0; $i -le 0x13FF; $i++) { if ($repaired[$i] -ne $original[$i]) { throw 'right guard changed after repair' } }
$repairedDiff = Get-ChangedOffsets $original $repaired
$expectedRepairedDiff = @($expectedChanged + @(0xFFD1,0xFFD2,0xFFD3,0xFFD4,0xFFD5) | Sort-Object)
if ((Compare-Object $repairedDiff $expectedRepairedDiff)) { throw 'repaired changed offsets differ from patch plus FFD1-FFD5' }
$repairOnly = Get-ChangedOffsets $image $repaired
$expectedRepairOnly = @(0xFFD1,0xFFD2,0xFFD3,0xFFD4,0xFFD5)
if ((Compare-Object @($repairOnly | Sort-Object) $expectedRepairOnly)) { throw "repair changed bytes outside FFD1-FFD5: $($repairOnly -join ',')" }

$unrepairedSha256 = Get-Sha $image 'SHA256'
$repairedSha256 = Get-Sha $repaired 'SHA256'
$record = [ordered]@{
    task = 'feature-animation-continuation-103'
    mode = 'input-switch'
    originalRom = [IO.Path]::GetFullPath($OriginalRom)
    originalSha1 = $sha1
    originalSha256 = $sha256
    headerAddress = '1010'
    headerBytes = '00F8'
    bodyAddress = '1012'
    allocationStart = '1010'
    allocationEnd = ('{0:X4}' -f $allocationEnd)
    allocationBytes = $allocationLength
    allocationHex = (Get-Hex $payloadBytes)
    caveBytesUsed = $allocationLength
    caveBytesRemaining = 992 - $allocationLength
    delayCount = $DelayCount
    waitMechanism = 'bounded VM countdown loop: push word iterations; 78D3 vm_decrement_word, 7B51 duplicate, 7A46 test_zero, 79A6 branch backward if the flag is false, 7B3D drop; delays by VM execution time and does not depend on the 002D IRQ counter'
    inputToken = '83FC'
    inputSelector = '0x12'
    inputMask = '00000080'
    inputSampleRam = '0003'
    physicalPort = ':BLACK2'
    physicalMask = '128'
    inputSemantics = 'token 83FC is the original Start-input condition wrapper 7721/selector 12; it pushes 0000 when the sampled Start bit is clear and FFFF when set; 7982 consumes the word and branches when zero'
    pressedPattern = 'middle rows: indices 18..23 (MAME lamp96..lamp101) then 24..29 (lamp88..lamp93), one alternating cycle'
    unpressedPattern = 'outer rows: indices 42..47 (lamp64..lamp69) then 0..5 (lamp120..lamp125), one alternating cycle'
    patternSelection = 'Start pressed at custom entry selects the middle-row animation; Start not pressed selects the outer-row animation; no time-based pattern toggle'
    finalCleanup = 'rows 0..5,18..23,24..29,42..47 cleared before branching to original feature'
    tableEntryAddresses = $TableEntryAddresses | ForEach-Object { $_.ToString('X4') }
    expectedTableEntry = $ExpectedTableEntry
    replacementTableEntry = $ReplacementTableEntry
    originalIntegrityFields = $originalFields
    unrepairedIntegrityFields = $originalFields
    repairedIntegrityFields = $computed
    unrepairedChangedOffsets = $changed | ForEach-Object { $_.ToString('X4') }
    repairedChangedOffsets = $repairedDiff | ForEach-Object { $_.ToString('X4') }
    unrepairedPath = $unrepairedPath
    unrepairedSha256 = $unrepairedSha256
    repairedPath = $repairedPath
    repairedSha256 = $repairedSha256
    guards = '1000-100F and 13F0-13FF preserved'
    bStart = $bStart.ToString('X4')
    aStart = $aStart.ToString('X4')
    cleanupStart = $cleanupStart.ToString('X4')
    codeLog = $codeLog
    semantics = 'redirected Snake Bite entry clears the custom lamp rows, reads the original Start input token 83FC, selects one of two one-cycle two-row animations, clears the rows and branches to original Snake Bite body D003'
}
$record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $recordPath -Encoding UTF8
Write-Output ("original={0} fields={1} unrepaired={2} repaired={3} fields={4} changed={5} length={6} remaining={7}" -f $sha1, $originalFields, $unrepairedSha256, $repairedSha256, $computed, $repairedDiff.Count, $allocationLength, (992 - $allocationLength))
Write-Output ('allocation=1010-{0:X4} bStart={1:X4} aStart={2:X4} cleanup={3:X4}' -f $allocationEnd, $bStart, $aStart, $cleanupStart)

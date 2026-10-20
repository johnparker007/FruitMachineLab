param(
    [Parameter(Mandatory=$true)][string]$OriginalRom,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [int]$Iterations = 18,
    [int]$DelayCount = 1000
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

$rowU = @(18,19,20,21,22,23)
$rowL = @(24,25,26,27,28,29)
$rowT = @(42,43,44,45,46,47)
$rowB = @(0,1,2,3,4,5)

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

$payload = New-Object System.Collections.Generic.List[byte]
$codeLog = New-Object System.Collections.Generic.List[string]
Add-TokenTo $payload 0x00F8
$codeLog.Add('1010 00F8 word header')

Add-WordLiteralTo $payload $Iterations
$iterationsAddress = 0x1010 + $payload.Count - 4
$loopStart = 0x1010 + $payload.Count
$codeLog.Add(('{0:X4} push iteration count {1}; loop starts {2:X4}' -f $iterationsAddress, $Iterations, $loopStart))

Add-TokenTo $payload 0x83FC
$codeLog.Add(('{0:X4} 83FC original Start input test (selector 0x12, mask 0x80, sampled RAM 0003)' -f (0x1010 + $payload.Count - 2)))
Add-TokenTo $payload 0x7982
$branchOperandAddress = 0x1010 + $payload.Count
$payload.Add(0x05)
$codeLog.Add(('{0:X4} 7982 +5: zero result (Start not pressed) to unpressed trampoline' -f ($branchOperandAddress - 2)))

Add-TokenTo $payload 0x79B0
$pressedTargetOperandAddress = 0x1010 + $payload.Count
$payload.Add(0x00); $payload.Add(0x00)
Add-TokenTo $payload 0x79B0
$unpressedTargetOperandAddress = 0x1010 + $payload.Count
$payload.Add(0x00); $payload.Add(0x00)

$pressedStart = 0x1010 + $payload.Count
Add-RowOffTo $payload $rowT
Add-RowOffTo $payload $rowB
Add-RowOnTo $payload $rowU
Add-RowOffTo $payload $rowL
Add-CountdownWaitTo $payload $DelayCount
Add-RowOffTo $payload $rowU
Add-RowOnTo $payload $rowL
Add-CountdownWaitTo $payload $DelayCount
$codeLog.Add(('{0:X4} pressed pattern: clear rows 42..47,0..5; rows 18..23 on/24..29 off, wait; rows 18..23 off/24..29 on, wait' -f $pressedStart))
Add-TokenTo $payload 0x79B0
$pressedJumpOperandAddress = 0x1010 + $payload.Count
$payload.Add(0x00); $payload.Add(0x00)
$codeLog.Add(('{0:X4} 79B0 absolute branch to shared loop tail' -f ($pressedJumpOperandAddress - 2)))

$unpressedStart = 0x1010 + $payload.Count
Add-RowOffTo $payload $rowU
Add-RowOffTo $payload $rowL
Add-RowOnTo $payload $rowT
Add-RowOffTo $payload $rowB
Add-CountdownWaitTo $payload $DelayCount
Add-RowOffTo $payload $rowT
Add-RowOnTo $payload $rowB
Add-CountdownWaitTo $payload $DelayCount
$codeLog.Add(('{0:X4} unpressed pattern: clear rows 18..23,24..29; rows 42..47 on/0..5 off, wait; rows 42..47 off/0..5 on, wait' -f $unpressedStart))

$tailStart = 0x1010 + $payload.Count
Add-TokenTo $payload 0x78D3
Add-TokenTo $payload 0x7B51
Add-TokenTo $payload 0x7A46
Add-TokenTo $payload 0x7ABB
Add-TokenTo $payload 0x79B9
$exitOperandAddress = 0x1010 + $payload.Count
$payload.Add(0x00); $payload.Add(0x00)
Add-TokenTo $payload 0x79B0
$loopOperandAddress = 0x1010 + $payload.Count
$payload.Add(0x00); $payload.Add(0x00)
$codeLog.Add(('{0:X4} loop tail: decrement count, duplicate, test zero, 7ABB invert flag, 79B9 absolute exit-if-zero (counter retained for continue), 79B0 back to loop start' -f $tailStart))

$exitStart = 0x1010 + $payload.Count
Add-TokenTo $payload 0x7B3D
$cleanupStart = 0x1010 + $payload.Count
foreach ($row in @($rowU,$rowL,$rowT,$rowB)) { Add-RowOffTo $payload $row }
$codeLog.Add(('{0:X4} exit drop count and clear rows 18..23,24..29,42..47,0..5 ({1:X4}..{2:X4})' -f $exitStart, $cleanupStart, (0x1010 + $payload.Count - 1)))
Add-TokenTo $payload 0x79B0
$payload.Add(0xD0); $payload.Add(0x03)
$codeLog.Add(('{0:X4} branch to original Snake Bite body D003' -f (0x1010 + $payload.Count - 4)))

$allocationLength = $payload.Count
$allocationEnd = $AllocationStart + $allocationLength - 1
if ($allocationEnd -gt $AllocationLimit) { throw ('allocation overflow: 0x{0:X4}..0x{1:X4} exceeds 0x{2:X4}' -f $AllocationStart, $allocationEnd, $AllocationLimit) }
for ($i = $AllocationStart; $i -le $allocationEnd; $i++) {
    if ($original[$i] -ne 0xFF) { throw ('allocation byte at 0x{0:X4} is {1}, expected FF' -f $i, $original[$i].ToString('X2')) }
}

$payloadBytes = $payload.ToArray()
if ((Get-Hex $payloadBytes[0..1]) -ne '00F8') { throw 'payload header is not 00F8' }
if ((Get-Hex $payloadBytes[($payloadBytes.Length-4)..($payloadBytes.Length-1)]) -ne '79B0D003') { throw 'payload does not end with 79B0 D003' }
if ($pressedStart -ne ($branchOperandAddress + 0x05 + 4)) { throw ('pressed trampoline target mismatch: pressedStart=0x{0:X4}' -f $pressedStart) }
if ($unpressedStart -ne ($pressedJumpOperandAddress + 2)) { throw ('unpressed target mismatch: unpressedStart=0x{0:X4}' -f $unpressedStart) }
if ($payloadBytes[$branchOperandAddress - 0x1010] -ne 0x05) { throw 'input branch displacement is not 05' }
if ((Get-Hex $payloadBytes[($branchOperandAddress - 0x1010 + 1)..($branchOperandAddress - 0x1010 + 2)]) -ne '79B0') { throw 'pressed trampoline token is not 79B0' }
if ((Get-Hex $payloadBytes[($branchOperandAddress - 0x1010 + 5)..($branchOperandAddress - 0x1010 + 6)]) -ne '79B0') { throw 'unpressed trampoline token is not 79B0' }
if ((Get-Hex $payloadBytes[($tailStart - 0x1010)..($tailStart - 0x1010 + 9)]) -ne '78D37B517A467ABB79B9') { throw 'loop tail bytes differ from expected decrement/dup/test/invert/branch sequence' }
if ((Get-Hex $payloadBytes[($tailStart - 0x1010 + 12)..($tailStart - 0x1010 + 13)]) -ne '79B0') { throw 'loop tail missing absolute loop branch' }
$unpressedBodyLength = $tailStart - $unpressedStart
$tailLength = $exitStart - $tailStart

function Set-OperandWord([System.Collections.Generic.List[byte]]$List, [int]$Address, [int]$Value) {
    $index = $Address - 0x1010
    $List[$index] = [byte](($Value -shr 8) -band 0xFF)
    $List[$index + 1] = [byte]($Value -band 0xFF)
}
Set-OperandWord $payload $pressedTargetOperandAddress $pressedStart
Set-OperandWord $payload $unpressedTargetOperandAddress $unpressedStart
Set-OperandWord $payload $pressedJumpOperandAddress $tailStart
Set-OperandWord $payload $exitOperandAddress $exitStart
Set-OperandWord $payload $loopOperandAddress $loopStart

$payloadBytes = $payload.ToArray()

$out = [IO.Path]::GetFullPath($OutputDirectory)
if ([IO.File]::Exists($out)) { throw "output path is a file: $out" }
if (![IO.Directory]::Exists($out)) { New-Item -ItemType Directory -Path $out | Out-Null }
$unrepairedPath = Join-Path $out 'live-pattern-unrepaired.p1'
$repairedPath = Join-Path $out 'live-pattern-repaired.p1'
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
    task = 'feature-live-pattern-experiment-104'
    mode = 'live-input-pattern'
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
    iterations = $Iterations
    delayCount = $DelayCount
    waitMechanism = 'bounded VM countdown loop: push word iterations; 78D3 vm_decrement_word, 7B51 duplicate, 7A46 test_zero, 79A6 branch backward if the flag is false, 7B3D drop; delay depends on VM execution time, not the 002D IRQ counter'
    loopMechanism = 'outer bounded loop: decrement, duplicate, test zero, invert flag with 7ABB, 79B9 absolute exit-if-zero; retain counter on continue, 79B0 branch back; drop counter only at exit'
    inputToken = '83FC'
    inputSelector = '0x12'
    inputMask = '00000080'
    inputSampleRam = '0003'
    physicalPort = ':BLACK2'
    physicalMask = '128'
    inputSemantics = 'token 83FC pushes 0000 when the sampled Start bit is clear and FFFF when set; sampled once per outer iteration, so a changed cabinet input selects the other pattern on the next iteration'
    pressedPattern = 'rows 18..23 (lamp96..lamp101) and 24..29 (lamp88..lamp93) alternate on/off'
    unpressedPattern = 'rows 42..47 (lamp64..lamp69) and 0..5 (lamp120..lamp125) alternate on/off'
    patternSelection = 'sampled repeatedly at the top of every outer iteration after custom entry; Start pressed selects the middle-row pair, Start released selects the outer-row pair; each iteration also waits twice, so a held input is reflected within about one iteration'
    finalCleanup = 'drop loop counter, clear rows 0..5,18..23,24..29,42..47, branch to original D003'
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
    loopStart = $loopStart.ToString('X4')
    pressedStart = $pressedStart.ToString('X4')
    unpressedStart = $unpressedStart.ToString('X4')
    tailStart = $tailStart.ToString('X4')
    exitStart = $exitStart.ToString('X4')
    cleanupStart = $cleanupStart.ToString('X4')
    branchOperandAddress = $branchOperandAddress.ToString('X4')
    unpressedBodyBytes = $unpressedBodyLength
    loopTailBytes = $tailLength
    codeLog = $codeLog
    semantics = 'redirected Snake Bite entry loops a bounded number of times; each iteration samples original Start token 83FC, clears the other pattern pair, displays one of two two-row alternating lamp patterns, then decrements a counter and repeats; on exhaustion it drops the counter, clears the rows and branches to original Snake Bite body D003'
}
$record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $recordPath -Encoding UTF8
Write-Output ("original={0} fields={1} unrepaired={2} repaired={3} fields={4} changed={5} length={6} remaining={7}" -f $sha1, $originalFields, $unrepairedSha256, $repairedSha256, $computed, $repairedDiff.Count, $allocationLength, (992 - $allocationLength))
Write-Output ('allocation=1010-{0:X4} loop={1:X4} pressed={2:X4} unpressed={3:X4} tail={4:X4} exit={5:X4}' -f $allocationEnd, $loopStart, $pressedStart, $unpressedStart, $tailStart, $exitStart)

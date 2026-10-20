param(
    [Parameter(Mandatory=$true)][string]$OriginalRom,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [int]$Iterations = 40,
    [int]$DelayCount = 600,
    [int]$InitialPaddle = 2,
    [int]$InitialBallX = 2,
    [int]$InitialBallY = 1,
    [switch]$InitialBallMoveLeft,
    [switch]$InitialBallMoveUp
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

$rowAll = @(0,1,2,3,4,5)

# Packed ball/paddle state, 11 bits:
#   bits 0-2  paddle column (0..5)
#   bits 3-5  ball column   (0..5)
#   bits 6-8  ball row      (0=top .. 7=bottom)
#   bit  9    horizontal direction (0=right, 1=left)
#   bit  10   vertical direction   (0=down,  1=up)
$MaskPaddle = 0x0007
$MaskBallX = 0x0038
$MaskBallY = 0x01C0
$MaskDX = 0x0200
$MaskDY = 0x0400
$StepBallX = 0x0008
$StepBallY = 0x0040
$StateInitial = (($InitialPaddle -band 7) -bor
    (($InitialBallX -band 7) -shl 3) -bor
    (($InitialBallY -band 7) -shl 6) -bor
    ($(if ($InitialBallMoveLeft) { $MaskDX } else { 0 })) -bor
    ($(if ($InitialBallMoveUp) { $MaskDY } else { 0 })))

if ($Iterations -lt 1 -or $Iterations -gt 60000) { throw 'Iterations out of range' }
if ($DelayCount -lt 1 -or $DelayCount -gt 60000) { throw 'DelayCount out of range' }
if ($InitialPaddle -lt 0 -or $InitialPaddle -gt 5) { throw 'InitialPaddle out of range 0..5' }
if ($InitialBallX -lt 0 -or $InitialBallX -gt 5) { throw 'InitialBallX out of range 0..5' }
if ($InitialBallY -lt 0 -or $InitialBallY -gt 6) { throw 'InitialBallY out of range 0..6' }

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

Assert-Span $original 0x83B1 '77211A' 'Hold 1/Nudge 1 input word 83B1'
Assert-Span $original 0x83B4 '772118' 'Hold 2/Nudge 2 input word 83B4'

$payload = New-Object System.Collections.Generic.List[byte]
$codeLog = New-Object System.Collections.Generic.List[string]
$labels = @{}
$branches = New-Object System.Collections.Generic.List[object]

function Address { return (0x1010 + $payload.Count) }
function Add-TokenTo([int]$Token) { $payload.Add([byte]($Token -shr 8)); $payload.Add([byte]($Token -band 0xFF)) }
function Add-ByteLiteralTo([int]$Value) { Add-TokenTo 0x7963; $payload.Add([byte]($Value -band 0xFF)) }
function Add-WordLiteralTo([int]$Value) { Add-TokenTo 0x795B; $payload.Add([byte](($Value -shr 8) -band 0xFF)); $payload.Add([byte]($Value -band 0xFF)) }
function Add-LampTo([int]$Index, [int]$Pattern) { Add-ByteLiteralTo $Index; Add-ByteLiteralTo $Pattern; Add-TokenTo 0x9C44 }
function Add-RowOnTo([int[]]$Row) { foreach ($i in $Row) { Add-LampTo $i 0x8F } }
function Add-RowOffTo([int[]]$Row) { foreach ($i in $Row) { Add-LampTo $i 0x80 } }
function Add-CountdownWaitTo([int]$WaitIterations) {
    Add-WordLiteralTo $WaitIterations
    foreach ($v in @(0x78,0xD3,0x7B,0x51,0x7A,0x46,0x79,0xA6,0xF8,0x7B,0x3D)) { $payload.Add([byte]$v) }
}
function Set-Label([string]$Name) {
    if ($labels.ContainsKey($Name)) { throw "duplicate label $Name" }
    $labels[$Name] = Address
}
function Add-BranchIfZeroTo([string]$Target) {
    Add-TokenTo 0x79B9
    $operand = Address
    $payload.Add(0x00); $payload.Add(0x00)
    $branches.Add([pscustomobject]@{ Operand = $operand; Target = $Target; Kind = 'zero' })
}
function Add-BranchTo([string]$Target) {
    Add-TokenTo 0x79B0
    $operand = Address
    $payload.Add(0x00); $payload.Add(0x00)
    $branches.Add([pscustomobject]@{ Operand = $operand; Target = $Target; Kind = 'always' })
}
function Add-DupAndMask([int]$Mask, [string]$Text) {
    Add-TokenTo 0x7B51
    if ($Mask -le 0xFF) { Add-ByteLiteralTo $Mask } else { Add-WordLiteralTo $Mask }
    Add-TokenTo 0x7A97
    if ($Text) { $codeLog.Add(('{0:X4} duplicate state and mask {1:X4} ({2})' -f (Address), $Mask, $Text)) }
}
function Add-ShiftRightTo([int]$Count) { for ($i = 0; $i -lt $Count; $i++) { Add-TokenTo 0x7905 } }
function Add-ShiftLeftTo([int]$Count) { for ($i = 0; $i -lt $Count; $i++) { Add-TokenTo 0x78FD } }

# Stack model for the whole custom body:
#   [outer counter, packed ball/paddle state] with state on top.
#   The miss and normal exits remove the counter, then the state, before D003.

Add-TokenTo 0x00F8
$codeLog.Add('1010 00F8 word header')
Add-WordLiteralTo $Iterations
$codeLog.Add(('{0:X4} push outer iteration count {1}' -f (Address - 4), $Iterations))
Add-WordLiteralTo $StateInitial
$codeLog.Add(('{0:X4} push packed state {1:X4}: paddle={2} ball=({3},{4}) dx={5} dy={6}' -f (Address - 4), $StateInitial, $InitialPaddle, $InitialBallX, $InitialBallY, ($(if ($InitialBallMoveLeft) {'left'} else {'right'})), ($(if ($InitialBallMoveUp) {'up'} else {'down'}))))

Set-Label 'loop'
$loopAddress = Address
$codeLog.Add(('{0:X4} loop start: clear previous ball cell, poll both paddle buttons, redraw paddle, move ball, draw ball, wait, bound' -f $loopAddress))

# ---- Clear the ball at its previous position (state is top). ----
$clearBallStart = Address
Add-TokenTo 0x7B51   # preserve one state copy for drawing below the computed index
Add-DupAndMask $MaskBallX 'ball column'
Add-ShiftRightTo 3
Add-TokenTo 0x7B7D   # swap: [bx, state]
Add-DupAndMask $MaskBallY 'ball row'
Add-ShiftRightTo 6
# stack: [bx, state, by]
Add-TokenTo 0x7B51
Add-TokenTo 0x78FD   # 2*by
Add-TokenTo 0x7B51
Add-TokenTo 0x78FD   # 4*by
Add-TokenTo 0x787E   # 6*by
Add-ByteLiteralTo 42
Add-TokenTo 0x7B7D
Add-TokenTo 0x78A0   # 42 - 6*by
Add-TokenTo 0x7B7D
Add-TokenTo 0x7B3D   # drop by
Add-TokenTo 0x7B7D
Add-TokenTo 0x7B3D   # drop state
Add-TokenTo 0x787E   # bx + (42 - 6*by)
Add-ByteLiteralTo 0x80
Add-TokenTo 0x9C44
$codeLog.Add(('{0:X4} compute previous logical lamp index and clear it with pattern 80' -f $clearBallStart))

# ---- Paddle input. The paddle column is the low three bits of state. ----
$leftTokenAddress = Address
Add-TokenTo 0x83B1
Add-BranchIfZeroTo 'left_skip'
Add-DupAndMask $MaskPaddle 'paddle column'
Add-TokenTo 0x7A46
Add-BranchIfZeroTo 'left_decrement'
Add-BranchTo 'left_skip'
Set-Label 'left_decrement'
Add-ByteLiteralTo 1
Add-TokenTo 0x78A0   # paddle > 0: decrement the low field
$codeLog.Add(('{0:X4} Hold 1/Nudge 1 (83B1) decrements paddle, bounded at 0' -f $leftTokenAddress))
Set-Label 'left_skip'
$rightTokenAddress = Address
Add-TokenTo 0x83B4
Add-BranchIfZeroTo 'right_skip'
Add-DupAndMask $MaskPaddle 'paddle column'
Add-ByteLiteralTo 5
Add-TokenTo 0x7A6F
Add-BranchIfZeroTo 'right_increment'
Add-BranchTo 'right_skip'
Set-Label 'right_increment'
Add-ByteLiteralTo 1
Add-TokenTo 0x787E   # paddle < 5: increment the low field
$codeLog.Add(('{0:X4} Hold 2/Nudge 2 (83B4) increments paddle, bounded at 5' -f $rightTokenAddress))
Set-Label 'right_skip'

# Redraw bottom row and paddle. State remains on the stack.
$paddleDrawStart = Address
Add-RowOffTo $rowAll
Add-DupAndMask $MaskPaddle 'paddle column'
Add-ByteLiteralTo 0x8F
Add-TokenTo 0x9C44
$codeLog.Add(('{0:X4} clear bottom row 0..5, duplicate paddle, light selected bottom lamp' -f $paddleDrawStart))

# ---- Horizontal ball movement (state top). ----
$horizontalStart = Address
Add-DupAndMask $MaskDX 'horizontal direction'
Add-BranchIfZeroTo 'move_right'
# moving left: reflect at column 0
Add-DupAndMask $MaskBallX 'ball column'
Add-TokenTo 0x7A46   # test zero
Add-BranchIfZeroTo 'left_normal'
Add-ByteLiteralTo $StepBallX
Add-TokenTo 0x787E   # 0 -> 1
Add-WordLiteralTo $MaskDX
Add-TokenTo 0x7AAF   # reverse direction
Add-BranchTo 'horizontal_done'
Set-Label 'left_normal'
Add-ByteLiteralTo $StepBallX
Add-TokenTo 0x78A0   # decrement column
Add-BranchTo 'horizontal_done'
Set-Label 'move_right'
Add-DupAndMask $MaskBallX 'ball column'
Add-ByteLiteralTo 0x28
Add-TokenTo 0x7A6F   # == 5 ?
Add-BranchIfZeroTo 'right_normal'
Add-ByteLiteralTo $StepBallX
Add-TokenTo 0x78A0   # 5 -> 4
Add-WordLiteralTo $MaskDX
Add-TokenTo 0x7AAF
Add-BranchTo 'horizontal_done'
Set-Label 'right_normal'
Add-ByteLiteralTo $StepBallX
Add-TokenTo 0x787E
Set-Label 'horizontal_done'
$codeLog.Add(('{0:X4} horizontal movement with deterministic wall reflection at columns 0 and 5' -f $horizontalStart))

# ---- Vertical ball movement (state top). ----
$verticalStart = Address
Add-DupAndMask $MaskDY 'vertical direction'
Add-BranchIfZeroTo 'move_down'
# moving up: reflect at top row 0
Add-DupAndMask $MaskBallY 'ball row'
Add-TokenTo 0x7A46
Add-BranchIfZeroTo 'up_normal'
Add-ByteLiteralTo $StepBallY
Add-TokenTo 0x787E   # row 0 -> 1
Add-WordLiteralTo $MaskDY
Add-TokenTo 0x7AAF
Add-BranchTo 'vertical_done'
Set-Label 'up_normal'
Add-ByteLiteralTo $StepBallY
Add-TokenTo 0x78A0
Add-BranchTo 'vertical_done'
Set-Label 'move_down'
Add-ByteLiteralTo $StepBallY
Add-TokenTo 0x787E   # enter the next row first
Add-DupAndMask $MaskBallY 'ball row'
Add-WordLiteralTo $MaskBallY
Add-TokenTo 0x7A6F   # new row == 7 ?
Add-BranchIfZeroTo 'vertical_done'
# Paddle row: compare ball column with paddle column.
Add-TokenTo 0x7B51   # preserve state for the hit or miss path
Add-TokenTo 0x7B51   # second copy for the shifted alignment
Add-ShiftRightTo 3
Add-TokenTo 0x7AAF   # state XOR (state>>3): low 3 bits are paddle XOR ball column
Add-ByteLiteralTo $MaskPaddle
Add-TokenTo 0x7A97
Add-TokenTo 0x7A46   # test zero
Add-BranchIfZeroTo 'collision_miss'
# Hit: row 7 -> 6 and reverse vertical direction.
Add-ByteLiteralTo $StepBallY
Add-TokenTo 0x78A0
Add-WordLiteralTo $MaskDY
Add-TokenTo 0x7AAF
Set-Label 'vertical_done'
$codeLog.Add(('{0:X4} vertical movement; row 7 compares ball column to paddle column, hit reflects up, miss branches to flash' -f $verticalStart))

# ---- Draw the ball at its new position. ----
$ballDrawStart = Address
Add-TokenTo 0x7B51   # preserve one state copy for the next loop iteration
Add-DupAndMask $MaskBallX 'ball column'
Add-ShiftRightTo 3
Add-TokenTo 0x7B7D
Add-DupAndMask $MaskBallY 'ball row'
Add-ShiftRightTo 6
Add-TokenTo 0x7B51
Add-TokenTo 0x78FD
Add-TokenTo 0x7B51
Add-TokenTo 0x78FD
Add-TokenTo 0x787E
Add-ByteLiteralTo 42
Add-TokenTo 0x7B7D
Add-TokenTo 0x78A0
Add-TokenTo 0x7B7D
Add-TokenTo 0x7B3D
Add-TokenTo 0x7B7D
Add-TokenTo 0x7B3D
Add-TokenTo 0x787E
Add-ByteLiteralTo 0x8F
Add-TokenTo 0x9C44
$codeLog.Add(('{0:X4} compute new logical lamp index and light the ball' -f $ballDrawStart))

$waitStart = Address
Add-CountdownWaitTo $DelayCount
Add-CountdownWaitTo $DelayCount
$codeLog.Add(('{0:X4} two bounded VM countdown waits ({1} each)' -f $waitStart, $DelayCount))

# ---- Bounded outer loop. ----
Add-TokenTo 0x7B7D   # [state, counter]
Add-TokenTo 0x78D3
Add-TokenTo 0x7B51
Add-TokenTo 0x7A46
Add-TokenTo 0x7ABB
Add-BranchIfZeroTo 'exit_normal'
Add-TokenTo 0x7B7D   # [counter, state]
Add-BranchTo 'loop'
$codeLog.Add(('{0:X4} decrement counter, exit when zero, otherwise restore [counter,state] and repeat' -f (Address - 20)))

# ---- Miss: full bottom-row flash, then bounded exit. ----
Set-Label 'collision_miss'
$missStart = Address
Add-TokenTo 0x7B7D   # [state, counter]
Add-TokenTo 0x7B3D   # drop counter
Add-RowOnTo $rowAll
Add-CountdownWaitTo $DelayCount
Add-CountdownWaitTo $DelayCount
Add-RowOffTo $rowAll
Add-CountdownWaitTo $DelayCount
Add-TokenTo 0x7B3D   # drop state
Add-BranchTo 'd003'
$codeLog.Add(('{0:X4} miss: drop counter, light all bottom-row lamps, wait, clear, wait, drop state' -f $missStart))

# ---- Normal bounded exit. ----
Set-Label 'exit_normal'
$exitStart = Address
Add-TokenTo 0x7B3D   # drop counter
Add-RowOffTo $rowAll
Add-TokenTo 0x7B3D   # drop state
Add-BranchTo 'd003'
$codeLog.Add(('{0:X4} normal exit: drop counter, clear bottom row, drop state' -f $exitStart))

Set-Label 'd003'
$d003BranchAddress = Address
Add-TokenTo 0x79B0
$payload.Add(0xD0); $payload.Add(0x03)
$codeLog.Add(('{0:X4} branch to original Snake Bite body D003' -f $d003BranchAddress))

$allocationLength = $payload.Count
$allocationEnd = $AllocationStart + $allocationLength - 1
if ($allocationEnd -gt $AllocationLimit) { throw ('allocation overflow: 0x{0:X4}..0x{1:X4} exceeds 0x{2:X4}' -f $AllocationStart, $allocationEnd, $AllocationLimit) }
for ($i = $AllocationStart; $i -le $allocationEnd; $i++) {
    if ($original[$i] -ne 0xFF) { throw ('allocation byte at 0x{0:X4} is {1}, expected FF' -f $i, $original[$i].ToString('X2')) }
}

foreach ($b in $branches) {
    if (!$labels.ContainsKey($b.Target)) { throw "unresolved label $($b.Target)" }
    $target = $labels[$b.Target]
    $index = $b.Operand - 0x1010
    $payload[$index] = [byte](($target -shr 8) -band 0xFF)
    $payload[$index + 1] = [byte]($target -band 0xFF)
}

$payloadBytes = $payload.ToArray()
if ((Get-Hex $payloadBytes[0..1]) -ne '00F8') { throw 'payload header is not 00F8' }
if ((Get-Hex $payloadBytes[($payloadBytes.Length-4)..($payloadBytes.Length-1)]) -ne '79B0D003') { throw 'payload does not end with 79B0 D003' }
$labelText = ($labels.GetEnumerator() | Sort-Object Value | ForEach-Object { '{0:X4}={1}' -f $_.Value, $_.Key }) -join ' '

$out = [IO.Path]::GetFullPath($OutputDirectory)
if ([IO.File]::Exists($out)) { throw "output path is a file: $out" }
if (![IO.Directory]::Exists($out)) { New-Item -ItemType Directory -Path $out | Out-Null }
$unrepairedPath = Join-Path $out 'ball-unrepaired.p1'
$repairedPath = Join-Path $out 'ball-repaired.p1'
$recordPath = Join-Path $out 'patch-record.json'
$payloadPath = Join-Path $out 'ball-payload.bin'
foreach ($p in @($unrepairedPath, $repairedPath, $recordPath, $payloadPath)) { if ([IO.File]::Exists($p) -or [IO.Directory]::Exists($p)) { throw "output already exists: $p" } }

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
[IO.File]::WriteAllBytes($payloadPath, $payloadBytes)
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
    task = 'feature-ball-experiment-106'
    mode = 'live-input-ball-and-paddle'
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
    initialPaddle = $InitialPaddle
    initialBallX = $InitialBallX
    initialBallY = $InitialBallY
    initialBallMoveLeft = [bool]$InitialBallMoveLeft
    initialBallMoveUp = [bool]$InitialBallMoveUp
    packedState = ('{0:X4}' -f $StateInitial)
    stateLayout = 'bits 0-2 paddle column, 3-5 ball column, 6-8 ball row, 9 horizontal direction (0 right, 1 left), 10 vertical direction (0 down, 1 up)'
    maskPaddle = ('{0:X4}' -f $MaskPaddle)
    maskBallX = ('{0:X4}' -f $MaskBallX)
    maskBallY = ('{0:X4}' -f $MaskBallY)
    maskDX = ('{0:X4}' -f $MaskDX)
    maskDY = ('{0:X4}' -f $MaskDY)
    stepBallX = ('{0:X4}' -f $StepBallX)
    stepBallY = ('{0:X4}' -f $StepBallY)
    waitMechanism = 'two bounded VM countdown loops per visible frame (795B word, 78D3 decrement, 7B51 duplicate, 7A46 test-zero, 79A6 F8 backward, 7B3D drop); delay is VM execution time, not the 002D IRQ counter'
    loopMechanism = 'outer bounded loop on a second stack cell: swap to counter, decrement, duplicate, test zero, invert with 7ABB, 79B9 absolute exit-if-zero; continue restores [counter,state] with 7B7D and 79B0 branches back; exit drops both cells'
    inputTokenLeft = '83B1'
    inputSelectorLeft = '0x1A'
    inputPhysicalLeft = ':BLACK2 mask 2 (MAME field Hold 1/Nudge 1)'
    inputTokenRight = '83B4'
    inputSelectorRight = '0x18'
    inputPhysicalRight = ':BLACK2 mask 4 (MAME field Hold 2/Nudge 2)'
    inputSemantics = '83B1 and 83B4 push 0000 when the sampled physical bit is clear and FFFF when set; each is sampled once per iteration before the paddle is redrawn; held buttons move the paddle one cell per iteration within 0..5'
    paddleWidth = 1
    ballRepresentation = 'single logical lamp cell; logical index = 6*(7-row)+column; row 0 is top and row 7 is the paddle row'
    collisionMechanism = 'when the descending ball reaches row 7, state XOR (state>>3) masked to 3 bits is zero only when the ball column equals the paddle column; equal reflects to row 6 and reverses vertical direction, unequal branches to the miss flash'
    missMechanism = 'drop counter, light all six bottom-row lamps, wait two countdowns, clear them, wait one countdown, drop state and branch to D003'
    finalCleanup = 'normal exit drops counter, clears bottom row 0..5, drops state and branches to D003; miss also clears the row after its flash'
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
    loopAddress = $loopAddress.ToString('X4')
    labels = $labelText
    codeLog = $codeLog
    semantics = 'redirected Snake Bite entry runs a bounded ball-and-paddle lamp demo on the 6x8 grid: each iteration clears the previous ball, samples Hold 1 and Hold 2 to move a one-lamp bottom-row paddle, advances a diagonally moving ball with wall reflection, compares the ball column to the paddle column on the bottom row, reflects a hit upward, flashes the whole bottom row on a miss, then continues or branches to the original Snake Bite body D003'
}
$record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $recordPath -Encoding UTF8
Write-Output ("original={0} fields={1} unrepaired={2} repaired={3} fields={4} changed={5} length={6} remaining={7}" -f $sha1, $originalFields, $unrepairedSha256, $repairedSha256, $computed, $repairedDiff.Count, $allocationLength, (992 - $allocationLength))
Write-Output ('allocation=1010-{0:X4} loop={1:X4} labels={2}' -f $allocationEnd, $loopAddress, $labelText)

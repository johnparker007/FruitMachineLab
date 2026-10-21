param(
    [Parameter(Mandatory=$true)][string]$OriginalRom,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [int]$DelayCount = 600,
    [int]$InitialPaddle = 2,
    [int]$InitialBallX = 0,
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

# Packed geometry (11 bits), with the six-brick mask kept in a second VM data
# stack cell:
#   bits 0-2  paddle left column (0..4); the two lamps are p and p+1
#   bits 3-5  ball column (0..5)
#   bits 6-8  ball row    (0=top .. 7=paddle row)
#   bit  9    horizontal direction (0=right, 1=left)
#   bit  10   vertical direction   (0=down, 1=up)
$MaskPaddle = 0x0007
$MaskBallX = 0x0038
$MaskBallY = 0x01C0
$MaskDX = 0x0200
$MaskDY = 0x0400
$StepBallX = 0x0008
$StepBallY = 0x0040
$MaskBricks = 0x003F

$BottomLamps = @(0,1,2,3,4,5)
$TopLamps = @(42,43,44,45,46,47)
$CornerLamps = @(42,47)
$BrickBits = @(0x01,0x02,0x04,0x08,0x10,0x20)

$StateInitial = (($InitialPaddle -band 7) -bor
    (($InitialBallX -band 7) -shl 3) -bor
    (($InitialBallY -band 7) -shl 6) -bor
    ($(if ($InitialBallMoveLeft) { $MaskDX } else { 0 })) -bor
    ($(if ($InitialBallMoveUp) { $MaskDY } else { 0 })))

if ($DelayCount -lt 1 -or $DelayCount -gt 60000) { throw 'DelayCount out of range' }
if ($InitialPaddle -lt 0 -or $InitialPaddle -gt 4) { throw 'InitialPaddle out of range 0..4 (left endpoint of a two-lamp paddle)' }
if ($InitialBallX -lt 0 -or $InitialBallX -gt 5) { throw 'InitialBallX out of range 0..5' }
if ($InitialBallY -lt 1 -or $InitialBallY -gt 6) { throw 'InitialBallY out of range 1..6' }

function Get-Sha([byte[]]$Bytes, [string]$Algorithm) {
    $h = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
    try { return ([BitConverter]::ToString($h.ComputeHash($Bytes))).Replace('-','').ToUpperInvariant() }
    finally { $h.Dispose() }
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
Assert-Span $original 0x9ADB '79157B6D832B792F' 'original lamp range body 9ADB'
Assert-Span $original 0xD086 '84D4767180A0A8F7822278748128822678748128792F' 'original feature completion tail D086'

$payload = New-Object System.Collections.Generic.List[byte]
$codeLog = New-Object System.Collections.Generic.List[string]
$labels = @{}
$branches = New-Object System.Collections.Generic.List[object]
$labelWordRefs = New-Object System.Collections.Generic.List[object]

function Address { return (0x1010 + $payload.Count) }
function Add-TokenTo([int]$Token) { $payload.Add([byte]($Token -shr 8)); $payload.Add([byte]($Token -band 0xFF)) }
function Add-ByteLiteralTo([int]$Value) { Add-TokenTo 0x7963; $payload.Add([byte]($Value -band 0xFF)) }
function Add-WordLiteralTo([int]$Value) { Add-TokenTo 0x795B; $payload.Add([byte](($Value -shr 8) -band 0xFF)); $payload.Add([byte]($Value -band 0xFF)) }
function Add-LabelWordTo([string]$Target) {
    $labelWordRefs.Add([pscustomobject]@{ Operand = Address; Target = $Target })
    $payload.Add(0x00); $payload.Add(0x00)
}
function Add-WordLiteralLabelTo([string]$Target) { Add-TokenTo 0x795B; Add-LabelWordTo $Target }
function Add-LampTo([int]$Index, [int]$Pattern) { Add-ByteLiteralTo $Index; Add-ByteLiteralTo $Pattern; Add-TokenTo 0x9C44 }
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
    if ($Text) { $codeLog.Add(('{0:X4} duplicate geometry and mask {1:X4} ({2})' -f (Address), $Mask, $Text)) }
}
function Add-ShiftRightTo([int]$Count) { for ($i = 0; $i -lt $Count; $i++) { Add-TokenTo 0x7905 } }

# Stack model for the whole custom body:
#   [six-brick mask, packed geometry] with geometry on top.
#   There is no round counter, no step cap and no auto-restart.  The one game
#   ends only on a brick hit that clears the mask (win) or a paddle-row miss
#   (loss).  A real ball collision is the only way a brick bit can clear.

Add-TokenTo 0x00F8
$codeLog.Add('1010 00F8 word header')
# Preserve the two words restored by D08E-D098, in original D030-D036 order.
Add-TokenTo 0x8226 # address 0300
Add-TokenTo 0x790D # saved word
Add-TokenTo 0x8222 # address 02FE
Add-TokenTo 0x790D # saved word
Add-WordLiteralTo $MaskBricks
$codeLog.Add(('{0:X4} push six-brick mask {1:X4}' -f (Address - 4), $MaskBricks))
Add-WordLiteralTo $StateInitial
$codeLog.Add(('{0:X4} push packed geometry {1:X4}: paddle={2} ball=({3},{4}) dx={5} dy={6}' -f (Address - 4), $StateInitial, $InitialPaddle, $InitialBallX, $InitialBallY, ($(if ($InitialBallMoveLeft) {'left'} else {'right'})), ($(if ($InitialBallMoveUp) {'up'} else {'down'}))))

$brickDrawStart = Address
foreach ($lamp in $TopLamps) { Add-LampTo $lamp 0x8F }
$codeLog.Add(('{0:X4} light all six top-row bricks 42..47 with original lamp call 9C44' -f $brickDrawStart))

Set-Label 'loop'
$loopAddress = Address
$codeLog.Add(('{0:X4} loop start: sample both paddle buttons, redraw paddle, move ball both axes, collide, test six bricks, draw/wait/clear' -f $loopAddress))

# ---- Paddle input. The paddle left endpoint is the low three bits of state. ----
$leftTokenAddress = Address
Add-TokenTo 0x83B1
Add-BranchIfZeroTo 'left_skip'
Add-DupAndMask $MaskPaddle 'paddle left column'
Add-TokenTo 0x7A46
Add-BranchIfZeroTo 'left_decrement'
Add-BranchTo 'left_skip'
Set-Label 'left_decrement'
Add-ByteLiteralTo 1
Add-TokenTo 0x78A0
$codeLog.Add(('{0:X4} Hold 1/Nudge 1 (83B1) decrements paddle, bounded at 0' -f $leftTokenAddress))
Set-Label 'left_skip'
$rightTokenAddress = Address
Add-TokenTo 0x83B4
Add-BranchIfZeroTo 'right_skip'
Add-DupAndMask $MaskPaddle 'paddle left column'
Add-ByteLiteralTo 4
Add-TokenTo 0x7A6F
Add-BranchIfZeroTo 'right_increment'
Add-BranchTo 'right_skip'
Set-Label 'right_increment'
Add-ByteLiteralTo 1
Add-TokenTo 0x787E
$codeLog.Add(('{0:X4} Hold 2/Nudge 2 (83B4) increments the left endpoint, bounded at 4' -f $rightTokenAddress))
Set-Label 'right_skip'

$paddleDrawStart = Address
foreach ($lamp in $BottomLamps) { Add-LampTo $lamp 0x80 }
Add-DupAndMask $MaskPaddle 'paddle left column'
Add-ByteLiteralTo 0x8F
Add-TokenTo 0x9C44
Add-DupAndMask $MaskPaddle 'paddle left column'
Add-ByteLiteralTo 1
Add-TokenTo 0x787E
Add-ByteLiteralTo 0x8F
Add-TokenTo 0x9C44
$codeLog.Add(('{0:X4} clear bottom row 0..5, light paddle lamps p and p+1 (p clamped 0..4)' -f $paddleDrawStart))

# ---- Horizontal ball movement (geometry top). ----
$horizontalStart = Address
Add-DupAndMask $MaskDX 'horizontal direction'
Add-BranchIfZeroTo 'move_right'
Add-DupAndMask $MaskBallX 'ball column'
Add-TokenTo 0x7A46
Add-BranchIfZeroTo 'left_normal'
Add-ByteLiteralTo $StepBallX
Add-TokenTo 0x787E
Add-WordLiteralTo $MaskDX
Add-TokenTo 0x7AAF
Add-BranchTo 'horizontal_done'
Set-Label 'left_normal'
Add-ByteLiteralTo $StepBallX
Add-TokenTo 0x78A0
Add-BranchTo 'horizontal_done'
Set-Label 'move_right'
Add-DupAndMask $MaskBallX 'ball column'
Add-ByteLiteralTo 0x28
Add-TokenTo 0x7A6F
Add-BranchIfZeroTo 'right_normal'
Add-ByteLiteralTo $StepBallX
Add-TokenTo 0x78A0
Add-WordLiteralTo $MaskDX
Add-TokenTo 0x7AAF
Add-BranchTo 'horizontal_done'
Set-Label 'right_normal'
Add-ByteLiteralTo $StepBallX
Add-TokenTo 0x787E
Set-Label 'horizontal_done'
$codeLog.Add(('{0:X4} horizontal movement with deterministic wall reflection at columns 0 and 5' -f $horizontalStart))

# ---- Two-way vertical movement (geometry top). ----
$verticalStart = Address
Add-DupAndMask $MaskDY 'vertical direction'
Add-BranchIfZeroTo 'move_down'
Add-DupAndMask $MaskBallY 'ball row'
Add-TokenTo 0x7A46
Add-BranchIfZeroTo 'up_normal'
Add-ByteLiteralTo $StepBallY
Add-TokenTo 0x787E
Add-WordLiteralTo $MaskDY
Add-TokenTo 0x7AAF
Add-BranchTo 'vertical_done'
Set-Label 'up_normal'
Add-ByteLiteralTo $StepBallY
Add-TokenTo 0x78A0
Add-BranchTo 'vertical_done'
Set-Label 'move_down'
Add-ByteLiteralTo $StepBallY
Add-TokenTo 0x787E
Add-DupAndMask $MaskBallY 'ball row'
Add-WordLiteralTo $MaskBallY
Add-TokenTo 0x7A6F
Add-BranchIfZeroTo 'vertical_done'
# Paddle row: exact membership ball column in {p, p+1}.
$collisionStart = Address
Add-TokenTo 0x7B51
Add-TokenTo 0x7B51
Add-WordLiteralTo $MaskBallX
Add-TokenTo 0x7A97
Add-ShiftRightTo 3
Add-TokenTo 0x7B7D
Add-WordLiteralTo $MaskPaddle
Add-TokenTo 0x7A97
Add-TokenTo 0x78A0
Add-TokenTo 0x7B51
Add-WordLiteralTo 0xFFFE
Add-TokenTo 0x7A97
Add-TokenTo 0x7A46
$collisionBranchAddress = Address
Add-BranchIfZeroTo 'collision_miss'
Add-TokenTo 0x7B3D
Add-ByteLiteralTo $StepBallY
Add-TokenTo 0x78A0
Add-WordLiteralTo $MaskDY
Add-TokenTo 0x7AAF
Add-BranchTo 'vertical_done'
Set-Label 'collision_miss'
Add-TokenTo 0x7B3D
Add-BranchTo 'loss'
$codeLog.Add(('{0:X4} vertical movement; row 7 computes d=ball-p, accepts exact d in {{0,1}}, hit reflects upward, miss continues to the loss delay' -f $verticalStart))

Set-Label 'vertical_done'
# ---- Six-brick check.  The mask and geometry are tested at row 0 only. ----
$brickCheckStart = Address
Add-DupAndMask $MaskBallY 'ball row'
Add-ByteLiteralTo 0
Add-TokenTo 0x7A6F
Add-BranchIfZeroTo 'brick_check_done'
# Compute bit = 1 << ball column in the VM (no table or unproved helper token).
Add-TokenTo 0x7B51              # duplicate top geometry -> [mask,geometry,geometry]
Add-WordLiteralTo $MaskBallX
Add-TokenTo 0x7A97              # [mask,geometry,columnField]
Add-ShiftRightTo 3              # [mask,geometry,column]
Add-ByteLiteralTo 1             # [mask,geometry,column,1]
Set-Label 'bit_loop'
Add-TokenTo 0x7B59              # copy column -> [.., column, 1, column]
Add-TokenTo 0x7A53              # test_nonzero
Add-BranchIfZeroTo 'bit_done'
Add-TokenTo 0x7B7D              # [..,1,column]
Add-ByteLiteralTo 1
Add-TokenTo 0x78A0              # [..,1,column-1]
Add-TokenTo 0x7B7D              # [..,column-1,1]
Add-TokenTo 0x78FD              # [..,column-1,2]
Add-BranchTo 'bit_loop'
Set-Label 'bit_done'
Add-TokenTo 0x7B7D              # [mask,geometry,bit,zeroColumn]
Add-TokenTo 0x7B3D              # drop zero column -> [mask,geometry,bit]
Add-TokenTo 0x7B6D              # rotate (checked order): [mask,geometry,bit] -> [geometry,bit,mask]
Add-TokenTo 0x7B7D              # swap -> [geometry,mask,bit]
Add-TokenTo 0x7B59              # over: duplicate mask -> [geometry,mask,bit,mask]
Add-TokenTo 0x7A97              # AND -> [geometry,mask,and]
Add-TokenTo 0x7B51              # keep AND for the hit path
Add-TokenTo 0x7A53              # test_nonzero
Add-BranchIfZeroTo 'brick_miss'
# Hit: AND equals the bit here; mask XOR bit clears exactly that brick.
Add-TokenTo 0x7AAF              # [geometry,newMask]
Add-TokenTo 0x7B51              # test newMask before touching geometry
Add-TokenTo 0x7A53
Add-BranchIfZeroTo 'win'
Add-TokenTo 0x7B7D              # [newMask,geometry]
Add-WordLiteralTo $MaskDY
Add-TokenTo 0x7AAF
Add-BranchTo 'brick_check_done'
Set-Label 'brick_miss'
Add-TokenTo 0x7B3D              # drop the zero AND -> [geometry,mask]
Add-TokenTo 0x7B7D              # [mask,geometry]
Add-BranchTo 'brick_check_done'
$codeLog.Add(('{0:X4} six-brick collision: row 0, bit = 1 << ball column, mask AND bit, clear only that bit, reflect; mask zero -> win' -f $brickCheckStart))

Set-Label 'brick_check_done'
# Keep one geometry copy for the next iteration, compute the logical lamp index,
# draw the ball, wait, then clear the same lamp.  The saved index is dropped.
$ballDrawStart = Address
Add-TokenTo 0x7B51
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
Add-TokenTo 0x7B51
Add-ByteLiteralTo 0x8F
Add-TokenTo 0x9C44
$codeLog.Add(('{0:X4} compute logical lamp index and light the ball, keeping one index copy' -f $ballDrawStart))

$waitStart = Address
Add-CountdownWaitTo $DelayCount
Add-CountdownWaitTo $DelayCount
$codeLog.Add(('{0:X4} two bounded VM countdown waits ({1} each); the saved index remains below them' -f $waitStart, $DelayCount))

$clearBallStart = Address
Add-TokenTo 0x7B51
Add-ByteLiteralTo 0x80
Add-TokenTo 0x9C44
Add-TokenTo 0x7B3D
$codeLog.Add(('{0:X4} clear the drawn ball and drop the saved index; [mask,geometry] remains' -f $clearBallStart))

Add-BranchTo 'loop'

# ---- Loss: real paddle-row miss, short bottom-row flash, then exit feature. ----
Set-Label 'loss'
$lossStart = Address
foreach ($lamp in $BottomLamps) { Add-LampTo $lamp 0x8F }
Add-CountdownWaitTo $DelayCount
Add-CountdownWaitTo $DelayCount
Add-BranchTo 'exit_feature'
$codeLog.Add(('{0:X4} loss: bottom-row 111111 flash for two bounded waits, then exit feature cleanup' -f $lossStart))

# ---- Win: mask became zero only through brick collisions. ----
Set-Label 'win'
$winStart = Address
Add-LampTo 42 0x8F
Add-LampTo 47 0x8F
Add-CountdownWaitTo $DelayCount
Add-CountdownWaitTo $DelayCount
Add-BranchTo 'exit_feature'
$codeLog.Add(('{0:X4} win: only after mask zero, top-corner flash for two bounded waits, then exit feature cleanup' -f $winStart))

# ---- Original feature completion bookkeeping and balanced return. ----
Set-Label 'exit_feature'
$exitStart = Address
Add-TokenTo 0x7B3D          # drop geometry
Add-TokenTo 0x7B3D          # drop six-brick mask
Add-TokenTo 0x78AA          # push true (-1) destination
Add-TokenTo 0xCB1B          # original set_feature_destination_with_minus_one_reset (CB1D)
foreach ($lamp in $TopLamps) { Add-LampTo $lamp 0x80 }
foreach ($lamp in $BottomLamps) { Add-LampTo $lamp 0x80 }
# The original D086 tail is entered from D003 with four bytes of feature-local
# frame still on the data stack and restores U by four on return.  Preserve that
# same precondition with the entry-saved words so values and stack are restored.
# Entry-saved words remain for original restoration.
$completionBranchAddress = Address
Add-BranchTo 'd086'
$codeLog.Add(('{0:X4} exit: drop both custom cells, call original CB1D reset with -1, clean custom rows, continue original completion tail D086' -f $exitStart))

Set-Label 'd086'
$d086BranchAddress = Address
Add-TokenTo 0x79B0
$payload.Add(0xD0); $payload.Add(0x86)
$codeLog.Add(('{0:X4} branch to original completion tail D086 (not the D003 feature body); D09A returns to E243' -f $d086BranchAddress))

$codeEnd = Address
$codeLength = $payload.Count

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
foreach ($r in $labelWordRefs) {
    if (!$labels.ContainsKey($r.Target)) { throw "unresolved data label $($r.Target)" }
    $target = $labels[$r.Target]
    $index = $r.Operand - 0x1010
    $payload[$index] = [byte](($target -shr 8) -band 0xFF)
    $payload[$index + 1] = [byte]($target -band 0xFF)
}

$payloadBytes = $payload.ToArray()
if ((Get-Hex $payloadBytes[0..1]) -ne '00F8') { throw 'payload header is not 00F8' }
if ((Get-Hex $payloadBytes[($d086BranchAddress - 0x1010)..($d086BranchAddress - 0x1010 + 3)]) -ne '79B0D086') { throw 'completion branch is not 79B0 D086' }
$labelText = ($labels.GetEnumerator() | Sort-Object Value | ForEach-Object { '{0:X4}={1}' -f $_.Value, $_.Key }) -join ' '

$out = [IO.Path]::GetFullPath($OutputDirectory)
if ([IO.File]::Exists($out)) { throw "output path is a file: $out" }
if (![IO.Directory]::Exists($out)) { New-Item -ItemType Directory -Path $out | Out-Null }
$unrepairedPath = Join-Path $out 'sixbrick-unrepaired.p1'
$repairedPath = Join-Path $out 'sixbrick-repaired.p1'
$recordPath = Join-Path $out 'patch-record.json'
$payloadPath = Join-Path $out 'sixbrick-payload.bin'
foreach ($p in @($unrepairedPath, $repairedPath, $recordPath, $payloadPath)) { if ([IO.File]::Exists($p) -or [IO.Directory]::Exists($p)) { throw "output already exists: $p" } }

$image = [byte[]]$original.Clone()
for ($i = 0; $i -lt $allocationLength; $i++) { $image[$AllocationStart + $i] = $payloadBytes[$i] }
$replacement = Convert-HexToBytes $ReplacementTableEntry
foreach ($a in $TableEntryAddresses) { $image[$a] = $replacement[0]; $image[$a+1] = $replacement[1] }

$changed = Get-ChangedOffsets $original $image
$expectedChanged = @()
for ($i = 0; $i -lt $allocationLength; $i++) {
    if ($original[$AllocationStart + $i] -ne $payloadBytes[$i]) { $expectedChanged += ($AllocationStart + $i) }
}
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
    task = 'feature-six-brick-final-continuation-116'
    mode = 'one-continuous-six-brick-game-then-original-feature-completion'
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
    codeBytes = $codeLength
    delayCount = $DelayCount
    initialPaddle = $InitialPaddle
    initialBallX = $InitialBallX
    initialBallY = $InitialBallY
    initialBallMoveLeft = [bool]$InitialBallMoveLeft
    initialBallMoveUp = [bool]$InitialBallMoveUp
    packedGeometry = ('{0:X4}' -f $StateInitial)
    stateLayout = 'bits 0-2 paddle left column (0..4, lamps p and p+1), 3-5 ball column, 6-8 ball row, 9 horizontal direction (0 right, 1 left), 10 vertical direction (0 down, 1 up); six-brick mask is the lower data-stack cell'
    maskBricks = ('{0:X4}' -f $MaskBricks)
    brickRow = 0
    brickLamps = $TopLamps -join ','
    maskPaddle = ('{0:X4}' -f $MaskPaddle)
    maskBallX = ('{0:X4}' -f $MaskBallX)
    maskBallY = ('{0:X4}' -f $MaskBallY)
    maskDX = ('{0:X4}' -f $MaskDX)
    maskDY = ('{0:X4}' -f $MaskDY)
    stepBallX = ('{0:X4}' -f $StepBallX)
    stepBallY = ('{0:X4}' -f $StepBallY)
    waitMechanism = 'two bounded VM countdown loops per visible step (795B word, 78D3 decrement, 7B51 duplicate, 7A46 test-zero, 79A6 F8 backward branch, 7B3D drop); delay is VM execution time, not the 002D IRQ counter'
    roundMechanism = 'none: exactly one continuous game; no round counter, no restart, no step cap and no automatic round-limit end'
    inputTokenLeft = '83B1'
    inputPhysicalLeft = ':BLACK2 mask 2 (MAME field Hold 1/Nudge 1)'
    inputTokenRight = '83B4'
    inputPhysicalRight = ':BLACK2 mask 4 (MAME field Hold 2/Nudge 2)'
    inputSemantics = '83B1 and 83B4 push 0000 when the sampled physical bit is clear and nonzero when set; each is sampled once per visible step; held buttons move the two-lamp paddle left endpoint one cell per step within 0..4'
    paddleWidth = 2
    paddleRepresentation = 'single packed left endpoint p clamped to 0..4; both lamps p and p+1 are always lit'
    ballRepresentation = 'single logical lamp cell; logical index = 6*(7-row)+column; row 0 is top and row 7 is the paddle row'
    collisionMechanism = 'when the descending ball reaches row 7, d = ball column - paddle left column is computed as an unsigned word; testing (d AND FFFE) == 0 accepts exactly d in {0,1}; a hit reflects upward, otherwise the natural loss delay runs'
    brickMechanism = 'the six-brick mask 003F is a separate lower VM data-stack cell; after a vertical move, row 0 fetches brickBits[column] from a cave table with original helper 996F, tests mask AND bit, clears only that bit, clears the same lamp through the ball draw/clear cycle, and reflects the ball. A cleared bit cannot collide again.'
    winMechanism = 'win is taken only when a real ball collision makes the six-brick mask exactly zero'
    lossMechanism = 'loss is taken only when the descending ball reaches paddle row 7 with ball column not in {p,p+1}; a short bottom-row flash precedes exit'
    finalCleanup = 'both custom stack cells are dropped, retaining entry-saved 0300/02FE words, custom rows are cleared, the original CB1B word (body CB1D) is called with -1 exactly as the original D003 body does at D00E, then the original completion tail D086 runs its bookkeeping and D09A returns to E243; C9 is observed 0 at D086 and E243 through that original tail. D003 feature gameplay is not entered.'
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
    collisionStart = $collisionStart.ToString('X4')
    collisionBranchAddress = $collisionBranchAddress.ToString('X4')
    brickCheckStart = $brickCheckStart.ToString('X4')
    exitStart = $exitStart.ToString('X4')
    completionBranch = ('{0:X4}: 79B0 D086' -f $d086BranchAddress)
    labels = $labelText
    codeLog = $codeLog
    semantics = 'redirected Snake Bite feature entry runs one continuous six-brick game on the 6x8 lamp grid, using real ball movement, wall reflection, two-lamp paddle collision and a six-bit brick mask; each brick disappears only on a real ball collision and cleared cells never collide again; mask zero wins, a real bottom miss loses, and either short outcome delay exits through original feature reset/completion bookkeeping without entering the original D003 feature body'
}
$record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $recordPath -Encoding UTF8
Write-Output ("original={0} fields={1} unrepaired={2} repaired={3} fields={4} changed={5} length={6} remaining={7}" -f $sha1, $originalFields, $unrepairedSha256, $repairedSha256, $computed, $repairedDiff.Count, $allocationLength, (992 - $allocationLength))
Write-Output ('allocation=1010-{0:X4} code=1010-{1:X4} data={2:X4}-{3:X4} loop={4:X4} collision={5:X4} exit={6:X4} labels={7}' -f $allocationEnd, ($codeEnd-1), $codeEnd, $allocationEnd, $loopAddress, $collisionStart, $exitStart, $labelText)

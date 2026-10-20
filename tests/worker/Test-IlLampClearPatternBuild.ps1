[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OriginalRom,
    [Parameter(Mandatory = $true)]
    [string]$OutputRoot,
    [string]$RepositoryRoot = '',
    [string]$MameExecutable = 'E:\Arcade\MAME0266\mame281.exe',
    [string]$RomDirectory = 'E:\Arcade\MAME0266\roms',
    [string]$ReplayPath = '',
    [string]$InputLuaPath = ''
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

$clearCliProject = Join-Path $repo 'tools/FruitMachineLab.IlLampClearPatternBuild/FruitMachineLab.IlLampClearPatternBuild.csproj'
$oldCliProject = Join-Path $repo 'tools/FruitMachineLab.IlLampPatternBuild/FruitMachineLab.IlLampPatternBuild.csproj'
$ilProject = Join-Path $repo 'tests/FruitMachineLab.IlVerification/FruitMachineLab.IlVerification.csproj'
$legacyObserver = Join-Path $repo 'tools/Capture-IlLampNatural.ps1'
if ([string]::IsNullOrWhiteSpace($ReplayPath)) {
    $ReplayPath = Join-Path $repo 'evidence/mpu4/skill-cash/actions.csv'
}
if ([string]::IsNullOrWhiteSpace($InputLuaPath)) {
    $InputLuaPath = Join-Path $repo 'evidence/mpu4/skill-cash/input.lua'
}
$ReplayPath = [IO.Path]::GetFullPath($ReplayPath)
$InputLuaPath = [IO.Path]::GetFullPath($InputLuaPath)
$MameExecutable = [IO.Path]::GetFullPath($MameExecutable)
$RomDirectory = [IO.Path]::GetFullPath($RomDirectory)

$logRoot = Join-Path $out 'logs'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

$expectedOriginalSha1 = '402D1518BB78FDC489B06C2AABC771E5CE151847'
$expectedOriginalSha256 = 'EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C'
$clearPayloadHex = '00F8795BFF80787E795BFF807AAF7963007963809C44792F'
$old8FPayloadHex = '00F8795BFF80787E795BFF807AAF79630079638F9C44792F'
$clearCallerHex = '1010'
$clearSuccessorHex = '75A9'
$old8FUnrepairedSha1 = 'FED6058A6BF8D2627068BAC01D77EE0D279B5E46'
$old8FUnrepairedSha256 = '3D94F6E2908D9C57C2C20EEDE897A0A19D4C74BA88464053554C0558C25ADDE3'
$old8FSha1 = '9F060102692BB31E03F992E95E38F4F59BEE1129'
$old8FSha256 = '631F6C252A5DF359525553F7D14A4FC8CEF965C76BBECA759EAAA862A3FAD4DE'
$old8FFields = 'E93F3C61B5'

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

function Get-BytesFromHex([string]$hex) {
    $bytes = New-Object byte[] ($hex.Length / 2)
    for ($index = 0; $index -lt $bytes.Length; $index++) {
        $bytes[$index] = [Convert]::ToByte($hex.Substring($index * 2, 2), 16)
    }
    return ,$bytes
}

function Get-FieldsHex([byte[]]$image) {
    return ([BitConverter]::ToString($image[0xFFD1..0xFFD5])).Replace('-', '')
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

function Assert-RangeEqual([byte[]]$first, [byte[]]$second, [int]$start, [int]$end, [string]$label) {
    for ($offset = $start; $offset -le $end; $offset++) {
        if ($first[$offset] -ne $second[$offset]) {
            throw ("{0} differs at {1:X4}: {2:X2} vs {3:X2}" -f $label, $offset, $first[$offset], $second[$offset])
        }
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

function Invoke-Cli([string]$project, [string]$inputRom, [string]$outputDirectory, [string]$logName) {
    $args = @('run', '--project', $project, '--no-build', '--', $inputRom, $outputDirectory)
    return Invoke-DotNet $args (Join-Path $logRoot $logName)
}

function Test-OutputFiles([string]$directory, [string[]]$names) {
    foreach ($name in $names) {
        if (-not (Test-Path -LiteralPath (Join-Path $directory $name) -PathType Leaf)) {
            throw "missing output file $name"
        }
    }
}

function Get-LiteralUnrepairedOffsets([byte[]]$original, [byte[]]$payload) {
    $offsets = New-Object System.Collections.ArrayList
    for ($index = 0; $index -lt $payload.Length; $index++) {
        $offset = 0x1010 + $index
        if ($original[$offset] -ne $payload[$index]) {
            [void]$offsets.Add($offset)
        }
    }
    for ($index = 0; $index -lt 2; $index++) {
        $offset = 0x9F14 + $index
        if ($original[$offset] -ne 0x10) {
            [void]$offsets.Add($offset)
        }
    }
    return @($offsets | Sort-Object)
}

# Independent ordered integrity recomputation. It walks 1400-FFFF skipping the
# active field locations, writes sum/xor, then rotate-add, then rotate-sub-xor.
function Get-IntegrityFields([byte[]]$image) {
    $working = [byte[]]$image.Clone()
    $sum = 0
    $xor = 0
    $pointer = 0x1400
    while ($true) {
        $value = [int]$working[$pointer]
        $sum = ($sum + $value) -band 0xFF
        $xor = $xor -bxor $value
        if ($pointer -eq 0xFFFF) { break }
        $pointer++
        if ($pointer -eq 0xFFD1) { $pointer = 0xFFD6 }
    }
    $working[0xFFD1] = [byte]$sum
    $working[0xFFD2] = [byte]$xor

    $a = 0
    $b = 0
    $carry = 0
    $pointer = 0x1400
    while ($true) {
        $value = [int]$working[$pointer]
        $next = ($b -shr 7) -band 1
        $b = (($b -shl 1) -bor $carry) -band 0xFF
        $carry = $next
        $total = $a + $value + $carry
        $a = $total -band 0xFF
        $carry = ($total -shr 8) -band 1
        $next = $b -band 1
        $b = ((($carry -shl 7) -bor ($b -shr 1)) -band 0xFF)
        $carry = $next
        if ($pointer -eq 0xFFFF) { break }
        $pointer++
        if ($pointer -eq 0xFFD3) { $pointer = 0xFFD6 }
        if ($pointer -lt 0xFFD3) { $carry = 1 } else { $carry = 0 }
    }
    $rotateAdd = $a
    $working[0xFFD3] = [byte]$rotateAdd

    $a = 0
    $b = 0
    $carry = 0
    $pointer = 0x1400
    while ($true) {
        $value = [int]$working[$pointer]
        $next = ($b -shr 7) -band 1
        $b = ($b -shl 1) -band 0xFF
        $carry = $next
        $total = $b + $carry
        $b = $total -band 0xFF
        $carry = ($total -shr 8) -band 1
        $total = $b - $value
        $b = $total -band 0xFF
        if ($total -lt 0) { $carry = 1 } else { $carry = 0 }
        $savedB = $b
        $b = $a
        for ($index = 0; $index -lt 3; $index++) {
            $carry = $b -band 1
            $b = ((($b -shr 1) -bor ($b -band 0x80)) -band 0xFF)
            $a = ((($carry -shl 7) -bor ($a -shr 1)) -band 0xFF)
        }
        $b = $savedB
        $a = $a -bxor $value
        if ($pointer -eq 0xFFFF) { break }
        $pointer++
        if ($pointer -eq 0xFFD4) { $pointer = 0xFFD6 }
    }
    $rotateSubA = $a
    $rotateSubB = $b
    $working[0xFFD4] = [byte]$rotateSubA
    $working[0xFFD5] = [byte]$rotateSubB

    $hex = ('{0:X2}{1:X2}{2:X2}{3:X2}{4:X2}' -f $sum, $xor, $rotateAdd, $rotateSubA, $rotateSubB)
    return [pscustomobject]@{
        Sum = $sum
        Xor = $xor
        RotateAdd = $rotateAdd
        RotateSubA = $rotateSubA
        RotateSubB = $rotateSubB
        Hex = $hex
        Working = $working
    }
}

function Assert-PreservedSpans([byte[]]$original, [byte[]]$repaired) {
    $spans = @(
        @(0x1000, 0x100F, 'left guard'),
        @(0x1000, 0x1003, 'protected cells'),
        @(0x13F0, 0x13FF, 'right guard'),
        @(0x1400, 0x140F, 'integrity neighbour'),
        @(0x9ED7, 0x9EE6, 'original 9ED7/9ED9'),
        @(0x1028, 0x13EF, 'unallocated extension'),
        @(0x9C44, 0x9C47, 'shared service cell'),
        @(0x9B15, 0x9B25, 'shared service body'),
        @(0x796E, 0x7978, 'trampoline'),
        @(0x7963, 0x796B, 'byte literal cell'),
        @(0x8050, 0x8053, 'bridge cell'),
        @(0x7791, 0x77A3, 'bridge entry'),
        @(0x777A, 0x778C, 'bridge continuation'),
        @(0x49C5, 0x4A24, 'native service'),
        @(0x72BF, 0x72EE, 'lamp table'),
        @(0x9F10, 0x9F13, 'caller header/body'),
        @(0x9F16, 0x9F1D, 'caller successor suffix'),
        @(0x9F3B, 0x9F40, 'parent context')
    )
    foreach ($span in $spans) {
        Assert-RangeEqual $original $repaired ([int]$span[0]) ([int]$span[1]) ([string]$span[2])
    }
}

function Assert-ClearAlgebra([byte[]]$romBytes) {
    Assert-Equal ([int]$romBytes[0x72BF]) 0x78 '72BF index 0 logical ID'
    $maskTable = @(0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80)
    for ($index = 0; $index -lt $maskTable.Count; $index++) {
        Assert-Equal ([int]$romBytes[0x49BD + $index]) $maskTable[$index] ('mask table at {0:X4}' -f (0x49BD + $index))
    }
    $mask = 0x01
    for ($before = 0; $before -le 0xFF; $before++) {
        $after = $before -band (-bnot $mask -band 0xFF)
        if (($after -band (-bnot $mask -band 0xFF)) -ne ($before -band (-bnot $mask -band 0xFF))) {
            throw 'clear algebra changed a non-mask bit'
        }
        if (($before -band $mask) -ne 0) {
            Assert-Equal $after ($before -bxor $mask) 'clear algebra did not clear an on bit'
        }
        else {
            Assert-Equal $after $before 'clear algebra changed an already-clear bit'
        }
    }
}

# ---------------------------------------------------------------------------
# Build the standalone CLIs and the independent IL verifier.
# ---------------------------------------------------------------------------
$build = Invoke-DotNet @('build', $clearCliProject, '--ignore-failed-sources') (Join-Path $logRoot 'build-clear-cli.log')
Add-Check 'build-clear-cli' ($build.Exit -eq 0) "exit=$($build.Exit)"
$buildOld = Invoke-DotNet @('build', $oldCliProject, '--ignore-failed-sources') (Join-Path $logRoot 'build-old-cli.log')
Add-Check 'build-old-cli' ($buildOld.Exit -eq 0) "exit=$($buildOld.Exit)"
$buildIl = Invoke-DotNet @('build', $ilProject, '--ignore-failed-sources') (Join-Path $logRoot 'build-il-verifier.log')
Add-Check 'build-il-verifier' ($buildIl.Exit -eq 0) "exit=$($buildIl.Exit)"

# ---------------------------------------------------------------------------
# Positive clear build.
# ---------------------------------------------------------------------------
$positive = Join-Path $out 'positive-01'
$positiveRun = Invoke-Cli $clearCliProject $rom $positive 'cli-clear-positive-01.log'
Add-Check 'clear-positive-cli-exit' ($positiveRun.Exit -eq 0) "exit=$($positiveRun.Exit)"
Test-OutputFiles $positive @('lamp-clear-unrepaired.p1', 'lamp-clear-repaired.p1', 'lamp-clear-pattern-source-map.json', 'build-report.json')

$originalBytes = [IO.File]::ReadAllBytes($rom)
$unrepairedBytes = [IO.File]::ReadAllBytes((Join-Path $positive 'lamp-clear-unrepaired.p1'))
$repairedBytes = [IO.File]::ReadAllBytes((Join-Path $positive 'lamp-clear-repaired.p1'))
$payloadBytes = Get-BytesFromHex $clearPayloadHex
$old8FPayloadBytes = Get-BytesFromHex $old8FPayloadHex

Assert-Equal (Get-HashHex $originalBytes 'SHA1') $expectedOriginalSha1 'original SHA1'
Assert-Equal (Get-HashHex $originalBytes 'SHA256') $expectedOriginalSha256 'original SHA256'
Add-Check 'clear-original-identity' $true 'original ROM length/SHA1/SHA256 match the exact a6ls.p1 revision'

for ($index = 0; $index -lt $payloadBytes.Length; $index++) {
    Assert-Equal ([int]$unrepairedBytes[0x1010 + $index]) ([int]$payloadBytes[$index]) ('literal clear payload at {0:X4}' -f (0x1010 + $index))
}
Assert-Equal ([int]$unrepairedBytes[0x1014]) 0xFF 'unrepaired 1014'
Assert-Equal ([int]$unrepairedBytes[0x101A]) 0xFF 'unrepaired 101A'
Assert-Equal ([int]$unrepairedBytes[0x1023]) 0x80 'literal pattern 80 at 1023'
Assert-Equal ([int]$unrepairedBytes[0x9F14]) 0x10 'caller high byte'
Assert-Equal ([int]$unrepairedBytes[0x9F15]) 0x10 'caller low byte'
Assert-RangeEqual $originalBytes $unrepairedBytes 0x9F16 0x9F17 'caller successor'
Add-Check 'clear-literal-payload-and-caller' $true '1010-1027 is the literal pattern-80 payload, 1023 is 80, 1014/101A stay FF, and 9F14-9F15 is 1010 with successor 75A9'

$clearDifferences = 0
for ($index = 0; $index -lt $payloadBytes.Length; $index++) {
    if ($payloadBytes[$index] -ne $old8FPayloadBytes[$index]) {
        $clearDifferences++
        Assert-Equal $index (0x1023 - 0x1010) 'clear vs 8F payload difference index'
        Assert-Equal ([int]$old8FPayloadBytes[$index]) 0x8F 'old 8F operand'
        Assert-Equal ([int]$payloadBytes[$index]) 0x80 'clear operand'
    }
}
Assert-Equal $clearDifferences 1 'clear vs 8F payload difference count'
Add-Check 'clear-single-operand-difference' $true 'the clear payload differs from the 8F payload only at 1023 (8F -> 80)'

$expectedUnrepairedOffsets = @(Get-LiteralUnrepairedOffsets $originalBytes $payloadBytes)
$actualUnrepairedOffsets = @(Get-DiffOffsets $originalBytes $unrepairedBytes)
Assert-Equal (Format-Offsets $actualUnrepairedOffsets) (Format-Offsets $expectedUnrepairedOffsets) 'unrepaired literal diff'
Add-Check 'clear-unrepaired-literal-diff' $true ("{0} literal unrepaired offsets: {1}" -f $actualUnrepairedOffsets.Count, (Format-Offsets $actualUnrepairedOffsets))

$originalFields = Get-IntegrityFields $originalBytes
Assert-Equal $originalFields.Hex '3E761E2605' 'original ordered fields'
$computed = Get-IntegrityFields $unrepairedBytes
$storedFields = Get-FieldsHex $repairedBytes
Assert-Equal $storedFields $computed.Hex 'repaired fields versus independent ordered recomputation'
$repairChanged = @(Get-DiffOffsets $unrepairedBytes $repairedBytes)
foreach ($offset in $repairChanged) {
    if ($offset -lt 0xFFD1 -or $offset -gt 0xFFD5) {
        throw ('repair changed a byte outside FFD1-FFD5 at {0:X4}' -f $offset)
    }
}
$expectedRepairChanged = @(0xFFD1..0xFFD5 | Where-Object { $unrepairedBytes[$_] -ne $repairedBytes[$_] })
Assert-Equal (Format-Offsets $repairChanged) (Format-Offsets $expectedRepairChanged) 'repair-only diff'
if (-not (Test-BytesEqual $computed.Working $repairedBytes)) {
    throw 'independent ordered recomputation working image differs from the CLI repaired image'
}
$expectedFinalOffsets = @(($expectedUnrepairedOffsets + $repairChanged) | Sort-Object)
$actualFinalOffsets = @(Get-DiffOffsets $originalBytes $repairedBytes)
Assert-Equal (Format-Offsets $actualFinalOffsets) (Format-Offsets $expectedFinalOffsets) 'final derived diff'
Add-Check 'clear-independent-integrity' $true ("fields={0}; repair offsets={1}; final offsets={2}; recomputed working image matches the CLI output" -f $storedFields, (Format-Offsets $repairChanged), (Format-Offsets $actualFinalOffsets))

Assert-PreservedSpans $originalBytes $repairedBytes
Add-Check 'clear-preserved-spans' $true 'guards, unallocated 1028-13EF, original 9ED7/9ED9, service, table, caller prefix/successor and parent context are unchanged'

Assert-ClearAlgebra $originalBytes
Add-Check 'clear-algebra-256' $true 'for all 256 before-byte values, mask 01 is cleared in each of four banks and no other bit changes'

# ---------------------------------------------------------------------------
# Report and map identity.
# ---------------------------------------------------------------------------
$report = Get-Content -LiteralPath (Join-Path $positive 'build-report.json') -Raw | ConvertFrom-Json
$map = Get-Content -LiteralPath (Join-Path $positive 'lamp-clear-pattern-source-map.json') -Raw | ConvertFrom-Json
$outputSha1 = Get-HashHex $repairedBytes 'SHA1'
$outputSha256 = Get-HashHex $repairedBytes 'SHA256'
$unrepairedSha1 = Get-HashHex $unrepairedBytes 'SHA1'
$unrepairedSha256 = Get-HashHex $unrepairedBytes 'SHA256'

Assert-Equal ([bool]$report.staticOnly) $true 'report staticOnly'
Assert-Equal ([bool]$report.executionClaimed) $false 'report executionClaimed'
Assert-Equal ([int]$report.allocation.length) 24 'report allocation length'
Assert-Equal ([int]$report.allocation.remainingApprovedBytes) 968 'report remaining approved bytes'
Assert-Equal ([string]$report.allocation.payloadHex) $clearPayloadHex 'report clear payload hex'
Assert-Equal ([string]$report.allocation.bodyHex) '795BFF80787E795BFF807AAF7963007963809C44792F' 'report clear body hex'
Assert-Equal ([int]$report.unrepaired.changedCount) $actualUnrepairedOffsets.Count 'report unrepaired count'
Assert-Equal ([int]$report.repaired.changedCount) $actualFinalOffsets.Count 'report final count'
Assert-Equal ([string]$report.integrity.repairedFieldsHex) $storedFields 'report repaired fields'
Assert-Equal ([int]$report.integrity.repairChangedCount) $repairChanged.Count 'report repair count'
Assert-Equal ([string]$report.repaired.sha256) $outputSha256 'report output SHA256'
Assert-Equal ([string]$report.repaired.sha1) $outputSha1 'report output SHA1'
Assert-Equal ([string]$report.predictedLampEffect.patternHex) '80' 'report pattern'
Assert-Equal ([string]$report.predictedLampEffect.maskHex) '01' 'report mask'
Assert-Equal ([string]$report.predictedLampEffect.logicalId) '78' 'report logical ID'
Assert-Equal ([int]$report.predictedLampEffect.observedColumn) 15 'report observed column'
Assert-Equal ([bool]$report.predictedLampEffect.futureResponseUnknown) $true 'report future response flag'
Assert-Equal ([bool]$report.predictedLampEffect.physicalLampOutputClaimed) $false 'report physical lamp flag'
Assert-Equal ([int]$report.predictedLampEffect.clearAlgebraCoveredBeforeValues) 256 'report clear algebra coverage'
Assert-Equal ([string]$report.sharedCall.handler) '9B15' 'report shared handler'
Assert-Equal ([string]$report.sharedCall.servicePointerValue) '72BF' 'report service pointer'
Assert-Equal ([bool]$report.sharedCall.handlerIsTokenPlusTwo) $false 'report token+2 flag'
Assert-Equal ([int]$report.sharedCall.callerOperandBytes) 0 'report caller operand bytes'
Add-Check 'clear-report-identity' $true 'report is static-only, records the clear payload/pattern/fields/diffs and binds the exact output hashes'

Assert-Equal ([string]$map.OutputImageSha256) $outputSha256 'map build binding'
Assert-Equal ([string]$map.Classification) 'static_lamp_clear_pattern_map_bound_to_exact_output_sha256' 'map classification'
Assert-Equal ([int]@($map.Entries).Count) 44 'map entries'
Assert-Equal ([int]@($map.Nodes).Count) 8 'map nodes'
Assert-Equal ([int]@($map.InlineOperands).Count) 4 'map inline operands'
Assert-Equal ([int]@($map.Phases).Count) 43 'map phases'
Assert-Equal ([int]@($map.Boundaries).Count) 12 'map boundaries'
$operand1023 = @($map.InlineOperands | Where-Object { [int]$_.Address -eq 0x1023 })[0]
Assert-Equal ([int]$operand1023.Value) 0x80 'map operand 1023'
Assert-Equal ([int]$operand1023.Width) 1 'map operand 1023 width'
$patternNode = @($map.Nodes | Where-Object { [int]$_.Index -eq 5 })[0]
Assert-Equal ([int]$patternNode.OperandValue) 0x80 'map pattern node operand'
Assert-Equal ([string]$patternNode.BytesHex) '796380' 'map pattern node bytes'
$handler0 = @($map.Phases | Where-Object { $_.Phase -eq 'handler-0' })[0]
$handler5 = @($map.Phases | Where-Object { $_.Phase -eq 'handler-5' })[0]
$sharedHandler = @($map.Phases | Where-Object { $_.Phase -eq 'shared-handler-entry' })[0]
$rotate = @($map.Phases | Where-Object { $_.Phase -eq 'shared-after-rotate' })[0]
$swap = @($map.Phases | Where-Object { $_.Phase -eq 'shared-after-swap' })[0]
$sharedBody = @($map.Phases | Where-Object { $_.Phase -eq 'shared-body-entry' })[0]
$sharedReturn = @($map.Phases | Where-Object { $_.Phase -eq 'shared-return-handler' })[0]
$outerReturn = @($map.Phases | Where-Object { $_.Phase -eq 'outer-return-handler' })[0]
Assert-Equal ([int]$handler0.X) 0x795D 'handler-0 dispatch X'
Assert-Equal ([int]$handler5.X) 0x7965 'handler-5 dispatch X'
Assert-Equal ([int]$handler5.OperandValue) 0x80 'handler-5 operand'
Assert-Equal ([int]$sharedHandler.X) 0x9C46 'shared handler X'
Assert-Equal ([int]$sharedHandler.U) 0x066A 'shared handler PRE-JSR U'
Assert-Equal ([int]$rotate.X) 0x80 'shared-after-rotate X'
Assert-Equal ([int]$swap.X) 0x80 'shared-after-swap X'
Assert-Equal ([int]$sharedBody.Pc) 0x00FC 'shared body prefetch PC'
Assert-Equal ([int]$sharedBody.X) 0x9B18 'shared body X'
Assert-Equal ([int]$sharedBody.Y) 0x9B18 'shared body Y'
Assert-Equal ([int]$sharedReturn.X) 0x7931 'shared return X'
Assert-Equal ([int]$sharedReturn.Y) 0x9B26 'shared return Y'
Assert-Equal ([int]$outerReturn.X) 0x7931 'outer return X'
Assert-Equal ([int]$outerReturn.Y) 0x1028 'outer return Y'
Assert-Equal ([int]$sharedReturn.SavedCursor) 0x1026 'shared saved cursor'
Assert-Equal ([int]$outerReturn.SavedCursor) 0x9F16 'outer saved cursor'
Assert-Equal (@($map.Phases | Where-Object { [int]$_.S -eq 0x0778 }).Count) 0 'no transplanted B951 S'
Add-Check 'clear-map-identity' $true 'map binds the final SHA256, records 44/8/4/43/12, operand 1023=0080, clear ROT/SWAP X=0080 and the accepted stack/saved-cursor boundaries'

# ---------------------------------------------------------------------------
# Repeated deterministic build.
# ---------------------------------------------------------------------------
$repeat = Join-Path $out 'positive-02'
$repeatRun = Invoke-Cli $clearCliProject $rom $repeat 'cli-clear-positive-02.log'
Add-Check 'clear-repeat-cli-exit' ($repeatRun.Exit -eq 0) "exit=$($repeatRun.Exit)"
Test-OutputFiles $repeat @('lamp-clear-unrepaired.p1', 'lamp-clear-repaired.p1', 'lamp-clear-pattern-source-map.json', 'build-report.json')
foreach ($name in @('lamp-clear-unrepaired.p1', 'lamp-clear-repaired.p1', 'lamp-clear-pattern-source-map.json', 'build-report.json')) {
    $first = [IO.File]::ReadAllBytes((Join-Path $positive $name))
    $second = [IO.File]::ReadAllBytes((Join-Path $repeat $name))
    if (-not (Test-BytesEqual $first $second)) {
        throw "repeated clear output differs: $name"
    }
}
Add-Check 'clear-repeat-deterministic' $true 'a second fresh output directory is byte-identical for all four files'

# ---------------------------------------------------------------------------
# Legacy 8F CLI remains unchanged.
# ---------------------------------------------------------------------------
$oldOut = Join-Path $out 'old-8f-cli'
$oldRun = Invoke-Cli $oldCliProject $rom $oldOut 'cli-old-8f.log'
Add-Check 'old-8f-cli-exit' ($oldRun.Exit -eq 0) "exit=$($oldRun.Exit)"
Test-OutputFiles $oldOut @('lamp-unrepaired.p1', 'lamp-repaired.p1', 'lamp-pattern-source-map.json', 'build-report.json')
$oldUnrepaired = [IO.File]::ReadAllBytes((Join-Path $oldOut 'lamp-unrepaired.p1'))
$oldRepaired = [IO.File]::ReadAllBytes((Join-Path $oldOut 'lamp-repaired.p1'))
Assert-Equal (Get-HashHex $oldUnrepaired 'SHA1') $old8FUnrepairedSha1 'old 8F unrepaired SHA1'
Assert-Equal (Get-HashHex $oldUnrepaired 'SHA256') $old8FUnrepairedSha256 'old 8F unrepaired SHA256'
Assert-Equal (Get-HashHex $oldRepaired 'SHA1') $old8FSha1 'old 8F repaired SHA1'
Assert-Equal (Get-HashHex $oldRepaired 'SHA256') $old8FSha256 'old 8F repaired SHA256'
Assert-Equal (Get-FieldsHex $oldRepaired) $old8FFields 'old 8F fields'
Assert-Equal ([int](Get-DiffOffsets $originalBytes $oldRepaired).Count) 29 'old 8F final diff count'
$oldMap = Get-Content -LiteralPath (Join-Path $oldOut 'lamp-pattern-source-map.json') -Raw | ConvertFrom-Json
Assert-Equal ([string]$oldMap.OutputImageSha256) $old8FSha256 'old 8F map binding'
Assert-Equal ([string]$oldMap.Classification) 'static_lamp_pattern_map_bound_to_exact_output_sha256' 'old 8F map classification'
Add-Check 'old-8f-cli-goldens-preserved' $true 'the old 8F CLI still emits the unchanged unrepaired/repaired hashes, fields, 29-offset diff and map identity'

# ---------------------------------------------------------------------------
# Full independent IL verifier, including both lamp groups.
# ---------------------------------------------------------------------------
$verifyOut = Join-Path $out 'il-verifier'
$verifyRun = Invoke-DotNet @(
    'run', '--project', $ilProject, '--no-build', '--', $rom, $verifyOut
) (Join-Path $logRoot 'il-verifier.log')
Add-Check 'il-verifier-exit' ($verifyRun.Exit -eq 0) "exit=$($verifyRun.Exit)"
$clearReportPath = Join-Path $verifyOut 'lamp-clear-pattern/verification-report.json'
$oldReportPath = Join-Path $verifyOut 'lamp-pattern/verification-report.json'
if (-not (Test-Path -LiteralPath $clearReportPath -PathType Leaf)) {
    Add-Check 'il-clear-group' $false 'lamp-clear verification report is missing'
}
else {
    $clearReport = Get-Content -LiteralPath $clearReportPath -Raw | ConvertFrom-Json
    $failedChecks = @($clearReport.Checks | Where-Object { -not [bool]$_.Passed })
    $checkCount = @($clearReport.Checks).Count
    Add-Check 'il-clear-group' ($failedChecks.Count -eq 0 -and $checkCount -eq 21) "checks=$checkCount, failed=$($failedChecks.Count)"
    Add-Check 'il-clear-status' ([string]$clearReport.Status -eq 'pass') "status=$($clearReport.Status)"
    Add-Check 'il-clear-identity' ([string]$clearReport.OutputSha256 -eq $outputSha256 -and [string]$clearReport.IntegrityRepairedFieldsHex -eq $storedFields) "output=$($clearReport.OutputSha256), fields=$($clearReport.IntegrityRepairedFieldsHex)"
    Add-Check 'il-clear-map-counts' ([int]$clearReport.MapEntryCount -eq 44 -and [int]$clearReport.MapInlineOperandCount -eq 4 -and [int]$clearReport.MapPhaseCount -eq 43 -and [int]$clearReport.MapBoundaryCount -eq 12 -and [int]$clearReport.PatternOperandValue -eq 0x80) "entries=$($clearReport.MapEntryCount), operands=$($clearReport.MapInlineOperandCount), phases=$($clearReport.MapPhaseCount), boundaries=$($clearReport.MapBoundaryCount), pattern=$($clearReport.PatternOperandValue)"
    $requiredChecks = @(
        'Clear algebra covers all 256 before-byte values',
        'Wrong header/index/pattern and old 8F payload are rejected',
        'Wrong expected bytes/caller/range are rejected',
        'Stale 8F map/build identity is rejected',
        'Build result, map and frame views are immutable'
    )
    $missing = @()
    foreach ($name in $requiredChecks) {
        $check = @($clearReport.Checks | Where-Object { $_.Name -eq $name })
        if ($check.Count -ne 1 -or -not [bool]$check[0].Passed) { $missing += $name }
    }
    Add-Check 'il-clear-negative-and-immutability-groups' ($missing.Count -eq 0) ("missing/failed: " + ($missing -join '; '))
}
if (-not (Test-Path -LiteralPath $oldReportPath -PathType Leaf)) {
    Add-Check 'il-old-8f-group' $false 'lamp-pattern verification report is missing'
}
else {
    $oldReport = Get-Content -LiteralPath $oldReportPath -Raw | ConvertFrom-Json
    $oldFailed = @($oldReport.Checks | Where-Object { -not [bool]$_.Passed })
    Add-Check 'il-old-8f-group' ($oldFailed.Count -eq 0 -and @($oldReport.Checks).Count -eq 26 -and [string]$oldReport.Status -eq 'pass') "checks=$(@($oldReport.Checks).Count), failed=$($oldFailed.Count), status=$($oldReport.Status)"
    Add-Check 'il-old-8f-identity' ([string]$oldReport.OutputSha256 -eq $old8FSha256 -and [string]$oldReport.IntegrityRepairedFieldsHex -eq $old8FFields) "output=$($oldReport.OutputSha256), fields=$($oldReport.IntegrityRepairedFieldsHex)"
}

# ---------------------------------------------------------------------------
# Legacy observer must reject the clear image before any launch.
# ---------------------------------------------------------------------------
$legacyRunDir = Join-Path $out 'legacy-prepare-only-run'
$legacyLogPath = Join-Path $logRoot 'legacy-prepare-only.log'
$legacyArgs = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $legacyObserver,
    '-Mode', 'PrepareOnly',
    '-MameExecutable', $MameExecutable,
    '-RomDirectory', $RomDirectory,
    '-OriginalRom', $rom,
    '-BuiltRom', (Join-Path $positive 'lamp-clear-repaired.p1'),
    '-SourceMapPath', (Join-Path $positive 'lamp-clear-pattern-source-map.json'),
    '-BuildReportPath', (Join-Path $positive 'build-report.json'),
    '-CheckerReportPath', (Join-Path $positive 'build-report.json'),
    '-ReplayPath', $ReplayPath,
    '-InputLuaPath', $InputLuaPath,
    '-RunDirectory', $legacyRunDir
)
$previousErrorAction = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $legacyOutput = & powershell @legacyArgs 2>&1
    $legacyExit = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorAction
}
$legacyText = (@($legacyOutput) | ForEach-Object { [string]$_ }) -join "`n"
[IO.File]::WriteAllText($legacyLogPath, $legacyText + "`n", (New-Object System.Text.UTF8Encoding($false)))
$legacyRejected = ($legacyExit -ne 0) -and ($legacyText -match 'built lamp image')
Add-Check 'legacy-prepare-only-rejects-clear-image' $legacyRejected "exit=$legacyExit; expected the frozen 8F built-image identity rejection"
Add-Check 'legacy-prepare-only-did-not-create-run' (-not (Test-Path -LiteralPath $legacyRunDir)) 'the legacy PrepareOnly gate failed before creating a run directory or launching MAME'

# ---------------------------------------------------------------------------
# CLI negative controls.
# ---------------------------------------------------------------------------
$inputs = Join-Path $out 'inputs'
New-Item -ItemType Directory -Path $inputs -Force | Out-Null
$wrongIdentityPath = Join-Path $inputs 'wrong-identity.p1'
$wrongIdentity = [byte[]]$originalBytes.Clone()
$wrongIdentity[0x1400] = $wrongIdentity[0x1400] -bxor 1
[IO.File]::WriteAllBytes($wrongIdentityPath, $wrongIdentity)
$wrongIdentityOut = Join-Path $out 'negative-wrong-identity'
$wrongIdentityRun = Invoke-Cli $clearCliProject $wrongIdentityPath $wrongIdentityOut 'cli-clear-wrong-identity.log'
Add-Check 'negative-wrong-identity' (($wrongIdentityRun.Exit -eq 1) -and -not (Test-Path -LiteralPath $wrongIdentityOut)) "exit=$($wrongIdentityRun.Exit); no output directory"

$wrongLengthPath = Join-Path $inputs 'wrong-length.p1'
$wrongLengthBytes = New-Object byte[] 65535
[Array]::Copy($originalBytes, 0, $wrongLengthBytes, 0, 65535)
[IO.File]::WriteAllBytes($wrongLengthPath, $wrongLengthBytes)
$wrongLengthOut = Join-Path $out 'negative-wrong-length'
$wrongLengthRun = Invoke-Cli $clearCliProject $wrongLengthPath $wrongLengthOut 'cli-clear-wrong-length.log'
Add-Check 'negative-wrong-length' (($wrongLengthRun.Exit -eq 1) -and -not (Test-Path -LiteralPath $wrongLengthOut)) "exit=$($wrongLengthRun.Exit); no output directory"

$existingOut = Join-Path $out 'negative-existing-output'
New-Item -ItemType Directory -Path $existingOut -Force | Out-Null
$existingRun = Invoke-Cli $clearCliProject $rom $existingOut 'cli-clear-existing-output.log'
Add-Check 'negative-existing-output' (($existingRun.Exit -eq 1) -and @(Get-ChildItem -LiteralPath $existingOut -Force).Count -eq 0) "exit=$($existingRun.Exit); existing directory preserved"

$aliasRun = Invoke-Cli $clearCliProject $rom $rom 'cli-clear-input-output-alias.log'
Add-Check 'negative-input-output-alias' ($aliasRun.Exit -eq 1) "exit=$($aliasRun.Exit)"

$missingRun = Invoke-DotNet @('run', '--project', $clearCliProject, '--no-build', '--') (Join-Path $logRoot 'cli-clear-missing-args.log')
Add-Check 'negative-missing-arguments' ($missingRun.Exit -eq 2) "exit=$($missingRun.Exit)"

Assert-Equal (Get-HashHex ([IO.File]::ReadAllBytes($rom)) 'SHA256') $expectedOriginalSha256 'original unchanged after all controls'
Add-Check 'all-controls-leave-original-read-only' $true 'the original ROM hash is unchanged after every control'

if ($script:failed) {
    Write-Log 'RESULT: FAIL'
}
else {
    Write-Log 'RESULT: PASS'
}

$reportObject = [ordered]@{
    schemaVersion = 1
    taskId = 'il-lamp-clear-build-71'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    result = if ($script:failed) { 'fail' } else { 'pass' }
    romPath = $rom
    romSha1 = Get-HashHex $originalBytes 'SHA1'
    romSha256 = Get-HashHex $originalBytes 'SHA256'
    outputRoot = $out
    clear = [ordered]@{
        payloadHex = $clearPayloadHex
        unrepairedSha1 = $unrepairedSha1
        unrepairedSha256 = $unrepairedSha256
        outputSha1 = $outputSha1
        outputSha256 = $outputSha256
        repairedFieldsHex = $storedFields
        unrepairedChangedCount = $actualUnrepairedOffsets.Count
        finalChangedCount = $actualFinalOffsets.Count
        repairChangedCount = $repairChanged.Count
        repairChangedOffsets = @($repairChanged | ForEach-Object { '{0:X4}' -f [int]$_ })
        mapBuildId = [string]$map.OutputImageSha256
        mapClassification = [string]$map.Classification
        patternOperandValue = [int]$operand1023.Value
        observedResponseColumn = 15
        clearAlgebraBeforeValues = 256
    }
    old8F = [ordered]@{
        outputSha1 = $old8FSha1
        outputSha256 = $old8FSha256
        repairedFieldsHex = $old8FFields
    }
    legacyPrepareOnly = [ordered]@{
        exit = $legacyExit
        rejectedClearImage = $legacyRejected
        runDirectoryCreated = (Test-Path -LiteralPath $legacyRunDir)
        log = $legacyLogPath
    }
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
        classification = 'STATIC clear-variant builder, map, CLI, independent integrity and legacy identity-gate controls only'
    }
}
$reportJson = ConvertTo-Json -InputObject $reportObject -Depth 10
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

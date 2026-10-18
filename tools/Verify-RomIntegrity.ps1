param(
    [Parameter(Mandatory = $true)][string]$RomPath,
    [string]$ReportPath,
    [switch]$NegativeControl
)
$ErrorActionPreference = 'Stop'

function Get-Sha1Hex([byte[]]$Bytes) {
    $sha = [System.Security.Cryptography.SHA1]::Create()
    try { return (($sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString('x2') }) -join '') }
    finally { $sha.Dispose() }
}

function Read-BigEndianWord([byte[]]$Bytes, [int]$Offset) {
    return (([int]$Bytes[$Offset] -shl 8) -bor [int]$Bytes[$Offset + 1])
}

function Invoke-SumXor([byte[]]$Bytes, [int]$Start, [int]$End) {
    [int]$sum = 0
    [int]$xor = 0
    [int]$p = $Start
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
    [int]$a = 0
    [int]$b = 0
    [int]$c = 0
    [int]$p = $Start
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
    [int]$a = 0
    [int]$b = 0
    [int]$c = 0
    [int]$p = $Start
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

function Expect([object]$Actual, [object]$Expected, [string]$Label) {
    if ([string]$Actual -ne [string]$Expected) {
        throw "Report mismatch: $Label actual=$Actual expected=$Expected"
    }
}

try {
    $rom = [System.IO.File]::ReadAllBytes([System.IO.Path]::GetFullPath($RomPath))
    if ($rom.Length -ne 65536) { throw "Unexpected ROM length: $($rom.Length)" }
    $sha1 = Get-Sha1Hex $rom
    $expectedSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
    if ($sha1 -ne $expectedSha1) { throw "Unexpected ROM identity: SHA1 $sha1" }

    $outerGate = [int]$rom[0x719B]
    if (($outerGate -band 0x02) -ne 0) {
        throw "Startup ROM self-check disabled by ROM 719B bit1"
    }
    Write-Output ('startup gate 719B={0:X2} bit1=0 enabled' -f $outerGate)

    $tableBase = 0xFFB0
    $recordSize = 11
    $recordCount = 4
    $termination = 0xFFDC
    if ($tableBase + $recordCount * $recordSize -ne $termination) {
        throw 'Recovered table layout is inconsistent'
    }

    $records = @()
    for ($i = 0; $i -lt $recordCount; $i++) {
        $offset = $tableBase + $i * $recordSize
        $expectedHex = (($rom[$offset..($offset + 4)] | ForEach-Object { $_.ToString('X2') }) -join '')
        $start = Read-BigEndianWord $rom ($offset + 5)
        $end = Read-BigEndianWord $rom ($offset + 7)
        $errorCode = [int]$rom[$offset + 9]
        $gate = [int]$rom[$offset + 10]
        $records += [pscustomobject]@{
            Base = $offset
            Start = $start
            End = $end
            ErrorCode = $errorCode
            Gate = $gate
            Enabled = ($gate -eq 0)
            ExpectedHex = $expectedHex
        }
    }

    Write-Output ('ROM a6ls.p1 length={0} sha1={1} OK' -f $rom.Length, $sha1)
    Write-Output ('table base=FFB0 record_size={0} records={1} termination=FFDC' -f $recordSize, $recordCount)

    $enabled = 0
    $verified = 0
    foreach ($record in $records) {
        $state = if ($record.Enabled) { 'enabled' } else { 'disabled' }
        Write-Output ('record {0:X4} start={1:X4} end={2:X4} gate={3:X2} error={4:X2} {5}' -f `
            $record.Base, $record.Start, $record.End, $record.Gate, $record.ErrorCode, $state)
        if (-not $record.Enabled) { continue }

        $enabled++
        $sumXor = Invoke-SumXor $rom $record.Start $record.End
        $rotateAdd = Invoke-RotateAdd $rom $record.Start $record.End
        $rotateSubXor = Invoke-RotateSubXor $rom $record.Start $record.End
        $expected = $record.ExpectedHex
        $fields = @(
            @{ Name = 'sum_xor.sum'; Actual = $sumXor[0]; Expected = [Convert]::ToInt32($expected.Substring(0, 2), 16); Skip = 'FFD1-FFD5' },
            @{ Name = 'sum_xor.xor'; Actual = $sumXor[1]; Expected = [Convert]::ToInt32($expected.Substring(2, 2), 16); Skip = 'FFD1-FFD5' },
            @{ Name = 'rotate_add'; Actual = $rotateAdd; Expected = [Convert]::ToInt32($expected.Substring(4, 2), 16); Skip = 'FFD3-FFD5' },
            @{ Name = 'rotate_sub_xor.a'; Actual = $rotateSubXor[0]; Expected = [Convert]::ToInt32($expected.Substring(6, 2), 16); Skip = 'FFD4-FFD5' },
            @{ Name = 'rotate_sub_xor.b'; Actual = $rotateSubXor[1]; Expected = [Convert]::ToInt32($expected.Substring(8, 2), 16); Skip = 'FFD4-FFD5' }
        )
        $failed = @($fields | Where-Object { $_.Actual -ne $_.Expected })
        foreach ($field in $fields) {
            $status = if ($field.Actual -eq $field.Expected) { 'OK' } else { 'FAIL' }
            Write-Output ('  {0} expected={1:X2} computed={2:X2} {3} skip={4}' -f `
                $field.Name, $field.Expected, $field.Actual, $status, $field.Skip)
        }
        if ($failed.Count -eq 0) { $verified++ }
    }

    if ($enabled -eq 0) { throw 'No enabled ROM integrity record was found' }
    if ($verified -ne $enabled) { throw "ROM integrity verification failed for $($enabled - $verified) record(s)" }
    Write-Output ("enabled={0} verified={1} failed={2}" -f $enabled, $verified, ($enabled - $verified))

    if ($ReportPath) {
        $report = Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
        Expect $report.schema_version 1 'schema_version'
        Expect $report.rom.sha1 $sha1 'rom.sha1'
        Expect $report.table.base 'FFB0' 'table.base'
        Expect $report.table.record_size $recordSize 'table.record_size'
        Expect $report.table.record_count $recordCount 'table.record_count'
        Expect $report.table.termination 'FFDC' 'table.termination'
        Expect $report.routine.outer_gate.address '719B' 'routine.outer_gate.address'
        Expect $report.routine.outer_gate.mask '02' 'routine.outer_gate.mask'
        Expect $report.routine.outer_gate.value ('{0:X2}' -f $outerGate) 'routine.outer_gate.value'
        if ([bool]$report.routine.outer_gate.enabled -ne $true) {
            throw 'Report mismatch: routine.outer_gate.enabled expected=true'
        }
        if (@($report.records).Count -ne $recordCount) { throw 'Report record count differs' }
        for ($i = 0; $i -lt $recordCount; $i++) {
            $actual = $records[$i]
            $field = $report.records[$i]
            Expect $field.base ('{0:X4}' -f $actual.Base) "records[$i].base"
            Expect $field.start ('{0:X4}' -f $actual.Start) "records[$i].start"
            Expect $field.end ('{0:X4}' -f $actual.End) "records[$i].end"
            Expect $field.expected_hex $actual.ExpectedHex "records[$i].expected_hex"
            Expect $field.error_code ('{0:X2}' -f $actual.ErrorCode) "records[$i].error_code"
            Expect $field.gate ('{0:X2}' -f $actual.Gate) "records[$i].gate"
            if ([bool]$field.enabled -ne [bool]$actual.Enabled) {
                throw "Report mismatch: records[$i].enabled actual=$($field.enabled) expected=$($actual.Enabled)"
            }
        }
        $active = $records | Where-Object { $_.Enabled } | Select-Object -First 1
        $activeReport = $report.records | Where-Object { $_.enabled -eq $true } | Select-Object -First 1
        $activeExpected = $active.ExpectedHex
        $sumXor = Invoke-SumXor $rom $active.Start $active.End
        $rotateAdd = Invoke-RotateAdd $rom $active.Start $active.End
        $rotateSubXor = Invoke-RotateSubXor $rom $active.Start $active.End
        Expect $activeReport.verified.sum_xor.expected.sum $activeExpected.Substring(0, 2) 'verified.sum_xor.expected.sum'
        Expect $activeReport.verified.sum_xor.expected.xor $activeExpected.Substring(2, 2) 'verified.sum_xor.expected.xor'
        Expect $activeReport.verified.sum_xor.computed.sum ('{0:X2}' -f $sumXor[0]) 'verified.sum_xor.computed.sum'
        Expect $activeReport.verified.sum_xor.computed.xor ('{0:X2}' -f $sumXor[1]) 'verified.sum_xor.computed.xor'
        Expect $activeReport.verified.rotate_add.expected $activeExpected.Substring(4, 2) 'verified.rotate_add.expected'
        Expect $activeReport.verified.rotate_add.computed ('{0:X2}' -f $rotateAdd) 'verified.rotate_add.computed'
        Expect $activeReport.verified.rotate_sub_xor.expected.a $activeExpected.Substring(6, 2) 'verified.rotate_sub_xor.expected.a'
        Expect $activeReport.verified.rotate_sub_xor.expected.b $activeExpected.Substring(8, 2) 'verified.rotate_sub_xor.expected.b'
        Expect $activeReport.verified.rotate_sub_xor.computed.a ('{0:X2}' -f $rotateSubXor[0]) 'verified.rotate_sub_xor.computed.a'
        Expect $activeReport.verified.rotate_sub_xor.computed.b ('{0:X2}' -f $rotateSubXor[1]) 'verified.rotate_sub_xor.computed.b'
        Write-Output ("report {0} OK" -f $ReportPath)
    }

    if ($NegativeControl) {
        $active = $records | Where-Object { $_.Enabled } | Select-Object -First 1
        [byte[]]$tampered = $rom.Clone()
        $tampered[$active.Start] = $tampered[$active.Start] -bxor 0x01
        $changed = Invoke-SumXor $tampered $active.Start $active.End
        $expectedSum = [Convert]::ToInt32($active.ExpectedHex.Substring(0, 2), 16)
        $expectedXor = [Convert]::ToInt32($active.ExpectedHex.Substring(2, 2), 16)
        if ($changed[0] -eq $expectedSum -and $changed[1] -eq $expectedXor) {
            throw 'Synthetic negative control was not detected'
        }
        Write-Output ('synthetic negative control: in-memory byte {0:X4} change detected (sum {1:X2}, xor {2:X2})' -f `
            $active.Start, $changed[0], $changed[1])
    }

    exit 0
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}

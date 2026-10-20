param(
    [Parameter(Mandatory = $true, Position = 0)][string]$InputPath,
    [Parameter(Mandatory = $true, Position = 1)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'

$script:reasons = [System.Collections.Generic.List[object]]::new()
$script:flags = @{
    structure = $false
    unsupportedColumn = $false
    unsupportedMask = $false
    noBaselineOne = $false
    clearReturnNotOne = $false
    preZero = $false
    overwrite = $false
    noTransition = $false
    diagnostic = $false
}
$script:synthetic = $null
$script:writeData = @{}

function Add-Reason {
    param(
        [string]$Code,
        [string]$Message,
        [string]$Kind,
        [int]$Line,
        [object]$Seq,
        [string]$Phase
    )
    $script:flags[$Kind] = $true
    $script:reasons.Add([ordered]@{
        code = $Code
        message = $Message
        kind = $Kind
        line = $Line
        seq = $Seq
        phase = $Phase
    })
}

function Test-Integer {
    param($Value)
    if ($null -eq $Value) { return $false }
    return ($Value -is [int] -or $Value -is [long] -or $Value -is [int16] -or
        $Value -is [uint16] -or $Value -is [uint32] -or $Value -is [uint64] -or
        $Value -is [byte] -or $Value -is [sbyte])
}

function Test-FiniteNumber {
    param($Value)
    if (Test-Integer $Value) { return $true }
    if ($Value -is [decimal]) { return $true }
    if ($Value -is [double]) {
        $d = [double]$Value
        return (-not [double]::IsNaN($d) -and -not [double]::IsInfinity($d))
    }
    if ($Value -is [single]) {
        $d = [double]$Value
        return (-not [double]::IsNaN($d) -and -not [double]::IsInfinity($d))
    }
    return $false
}

function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return $null }
    $p = $Obj.PSObject.Properties[$Name]
    if ($null -eq $p) { return $null }
    return $p.Value
}

function Check-Keys {
    param($Obj, [string[]]$Expected, [int]$Line, [object]$Seq, [string]$Phase)
    $actual = @($Obj.PSObject.Properties.Name)
    foreach ($e in $Expected) {
        if ($actual -notcontains $e) {
            Add-Reason 'missing_field' ("Missing required field '$e'") 'structure' $Line $Seq $Phase
        }
    }
    foreach ($a in $actual) {
        if ($Expected -notcontains $a) {
            Add-Reason 'unknown_field' ("Unknown field '$a'") 'structure' $Line $Seq $Phase
        }
    }
}

function Get-Int {
    param($Obj, [string]$Name, [int]$Line, [object]$Seq, [string]$Phase, [long]$Min, [long]$Max)
    $p = $Obj.PSObject.Properties[$Name]
    if ($null -eq $p) { return $null }
    $v = $p.Value
    if (-not (Test-Integer $v)) {
        Add-Reason ('field_type_' + $Name) ("Field '$Name' must be a JSON integer") 'structure' $Line $Seq $Phase
        return $null
    }
    $d = [decimal]$v
    if ($d -lt $Min -or $d -gt $Max) {
        Add-Reason ('field_range_' + $Name) ("Field '$Name' out of range $Min..$Max") 'structure' $Line $Seq $Phase
        return $null
    }
    return $v
}

function Get-Time {
    param($Obj, [int]$Line, [object]$Seq, [string]$Phase)
    $p = $Obj.PSObject.Properties['time']
    if ($null -eq $p) { return $null }
    $v = $p.Value
    if (-not (Test-FiniteNumber $v)) {
        Add-Reason 'field_type_time' "Field 'time' must be a finite JSON number" 'structure' $Line $Seq $Phase
        return $null
    }
    $d = [double]$v
    if ([double]::IsNaN($d) -or [double]::IsInfinity($d) -or $d -lt 0) {
        Add-Reason 'field_range_time' "Field 'time' must be finite and nonnegative" 'structure' $Line $Seq $Phase
        return $null
    }
    return $d
}

function Get-NestedObject {
    param($Obj, [string]$Name, [int]$Line, [object]$Seq, [string]$Phase)
    $p = $Obj.PSObject.Properties[$Name]
    if ($null -eq $p) { return $null }
    $v = $p.Value
    if (-not ($v -is [pscustomobject])) {
        Add-Reason ('field_type_' + $Name) ("Field '$Name' must be a JSON object") 'structure' $Line $Seq $Phase
        return $null
    }
    return $v
}

function Get-ByteArray4 {
    param($Obj, [string]$Name, [int]$Line, [object]$Seq, [string]$Phase)
    $p = $Obj.PSObject.Properties[$Name]
    if ($null -eq $p) { return $null }
    $v = $p.Value
    if (-not ($v -is [array])) {
        Add-Reason ('field_type_' + $Name) ("Field '$Name' must be a four-byte JSON array") 'structure' $Line $Seq $Phase
        return $null
    }
    $arr = @($v)
    if ($arr.Count -ne 4) {
        Add-Reason ('field_length_' + $Name) ("Field '$Name' must contain exactly four bytes") 'structure' $Line $Seq $Phase
        return $null
    }
    $out = New-Object 'int[]' 4
    for ($i = 0; $i -lt 4; $i++) {
        if (-not (Test-Integer $arr[$i])) {
            Add-Reason ('field_type_' + $Name) ("Field '$Name[$i]' must be a JSON integer") 'structure' $Line $Seq $Phase
            return $null
        }
        $n = [int]$arr[$i]
        if ($n -lt 0 -or $n -gt 255) {
            Add-Reason ('field_range_' + $Name) ("Field '$Name[$i]' must be 0..255") 'structure' $Line $Seq $Phase
            return $null
        }
        $out[$i] = $n
    }
    return ,$out
}

function Validate-Begin {
    param($Obj, [int]$Line, [object]$Seq, [string]$Phase)
    $schema = Get-Int $Obj 'schema' $Line $Seq $Phase 0 100
    if ($null -ne $schema -and $schema -ne 1) {
        Add-Reason 'schema_version_mismatch' ("Unsupported schema $schema; expected 1") 'structure' $Line $Seq $Phase
    }
    $p = $Obj.PSObject.Properties['synthetic']
    if ($null -ne $p) {
        if ($p.Value -is [bool]) {
            $script:synthetic = [bool]$p.Value
        } else {
            Add-Reason 'field_type_synthetic' "Field 'synthetic' must be a JSON boolean" 'structure' $Line $Seq $Phase
        }
    }
}

function Validate-Output {
    param($Parent, [int]$Line, [object]$Seq, [string]$Phase)
    $out = Get-NestedObject $Parent 'output' $Line $Seq $Phase
    if ($null -eq $out) { return }
    Check-Keys $out @('id', 'name', 'roundtripName', 'get', 'indexed') $Line $Seq $Phase
    $id = Get-Int $out 'id' $Line $Seq $Phase 0 4294967295
    $get = Get-Int $out 'get' $Line $Seq $Phase 0 255
    $indexed = Get-Int $out 'indexed' $Line $Seq $Phase 0 255
    $nameProp = $out.PSObject.Properties['name']
    $roundProp = $out.PSObject.Properties['roundtripName']
    $name = $null
    $round = $null
    if ($null -ne $nameProp) {
        if ($nameProp.Value -is [string]) { $name = [string]$nameProp.Value }
        else { Add-Reason 'field_type_name' "Field 'output.name' must be a string" 'structure' $Line $Seq $Phase }
    }
    if ($null -ne $roundProp) {
        if ($roundProp.Value -is [string]) { $round = [string]$roundProp.Value }
        else { Add-Reason 'field_type_roundtripName' "Field 'output.roundtripName' must be a string" 'structure' $Line $Seq $Phase }
    }
    $idOk = $null -ne $id
    $getOk = $null -ne $get
    $indexedOk = $null -ne $indexed
    $getBinary = $false
    $indexedBinary = $false
    if ($getOk) {
        $getBinary = ($get -eq 0 -or $get -eq 1)
        if (-not $getBinary) { Add-Reason 'output_nonbinary' "Field 'output.get' must be binary 0 or 1" 'structure' $Line $Seq $Phase }
    }
    if ($indexedOk) {
        $indexedBinary = ($indexed -eq 0 -or $indexed -eq 1)
        if (-not $indexedBinary) { Add-Reason 'output_nonbinary' "Field 'output.indexed' must be binary 0 or 1" 'structure' $Line $Seq $Phase }
    }
    if ($idOk -and $id -eq 0) {
        Add-Reason 'output_id_zero' "Output id must be > 0; id 0 means the output name is missing" 'diagnostic' $Line $Seq $Phase
    }
    if ($getOk -and $indexedOk -and $getBinary -and $indexedBinary -and $get -ne $indexed) {
        Add-Reason 'output_get_indexed_mismatch' ("Output get/indexed disagree: $get/$indexed") 'diagnostic' $Line $Seq $Phase
    }
    if ($null -ne $name -and $null -ne $round -and $name -cne $round) {
        Add-Reason 'output_name_roundtrip_mismatch' ("Output name '$name' != roundtrip '$round'") 'diagnostic' $Line $Seq $Phase
    }

    if ($null -ne $name -and $name -cne 'lamp120') {
        Add-Reason 'output_name_mismatch' ("Output name '$name' is not lamp120") 'diagnostic' $Line $Seq $Phase
    }
    $identityOk = ($idOk -and $id -gt 0 -and $null -ne $name -and $name -ceq 'lamp120' -and
        $null -ne $round -and $round -ceq 'lamp120')
    if ($identityOk -and $getOk -and $indexedOk -and $getBinary -and $indexedBinary) {
        $isOne = ($get -eq 1 -and $indexed -eq 1)
        $isZero = ($get -eq 0 -and $indexed -eq 0)
        if ($Phase -eq 'baseline' -and -not $isOne) {
            Add-Reason 'baseline_output_not_one' ("Baseline output must be 1; observed $get/$indexed") 'inconclusive' $Line $Seq $Phase
            $script:flags.noBaselineOne = $true
        } elseif ($Phase -eq 'clear-return' -and -not $isOne) {
            Add-Reason 'clear_return_output_not_one' ("Clear-return output must be 1; observed $get/$indexed") 'inconclusive' $Line $Seq $Phase
            $script:flags.clearReturnNotOne = $true
        } elseif ($Phase -eq 'write-pre' -and -not $isOne) {
            Add-Reason 'pre_output_not_one' ("Immediate pre-write output must be 1; observed $get/$indexed") 'inconclusive' $Line $Seq $Phase
            $script:flags.preZero = $true
        } elseif ($Phase -eq 'write-post' -and -not $isZero) {
            Add-Reason 'post_output_not_zero' ("Immediate post-write output must be 0; observed $get/$indexed") 'inconclusive' $Line $Seq $Phase
            $script:flags.noTransition = $true
        }
    }
}

function Validate-Cpu {
    param($Parent, [int]$Line, [object]$Seq, [string]$Phase)
    $cpu = Get-NestedObject $Parent 'cpu' $Line $Seq $Phase
    if ($null -eq $cpu) { return }
    Check-Keys $cpu @('pc', 'y', 'u', 's', 'cc') $Line $Seq $Phase
    $pc = Get-Int $cpu 'pc' $Line $Seq $Phase 0 65535
    $y = Get-Int $cpu 'y' $Line $Seq $Phase 0 65535
    $u = Get-Int $cpu 'u' $Line $Seq $Phase 0 65535
    $s = Get-Int $cpu 's' $Line $Seq $Phase 0 65535
    $null = Get-Int $cpu 'cc' $Line $Seq $Phase 0 255
    if ($Phase -eq 'clear-return') {
        if ($null -ne $pc -and $pc -ne 252) { Add-Reason 'cpu_clear_return_pc_mismatch' ("Clear-return PC $pc != 252 (0x00FC)") 'diagnostic' $Line $Seq $Phase }
        if ($null -ne $y -and $y -ne 40726) { Add-Reason 'cpu_clear_return_y_mismatch' ("Clear-return Y $y != 40726 (0x9F16)") 'diagnostic' $Line $Seq $Phase }
        if ($null -ne $u -and $u -ne 1646) { Add-Reason 'cpu_clear_return_u_mismatch' ("Clear-return U $u != 1646 (0x066E)") 'diagnostic' $Line $Seq $Phase }
        if ($null -ne $s -and $s -ne 1944) { Add-Reason 'cpu_clear_return_s_mismatch' ("Clear-return S $s != 1944 (0x0798)") 'diagnostic' $Line $Seq $Phase }
    } elseif ($Phase -eq 'write-pre') {
        if ($null -ne $pc -and $pc -ne 10631) { Add-Reason 'write_pre_pc_mismatch' ("write-pre PC $pc != 10631 (0x2987)") 'diagnostic' $Line $Seq $Phase }
    } elseif ($Phase -eq 'write-post') {
        if ($null -ne $pc -and $pc -ne 10634) { Add-Reason 'write_post_pc_mismatch' ("write-post PC $pc != 10634 (0x298A)") 'diagnostic' $Line $Seq $Phase }
    }
}

function Validate-Frames {
    param($Parent, [int]$Line, [object]$Seq, [string]$Phase)
    $frames = Get-NestedObject $Parent 'frames' $Line $Seq $Phase
    if ($null -eq $frames) { return }
    Check-Keys $frames @('before', 'after') $Line $Seq $Phase
    $before = Get-ByteArray4 $frames 'before' $Line $Seq $Phase
    $after = Get-ByteArray4 $frames 'after' $Line $Seq $Phase
    if ($null -ne $before) {
        $ok = ($before[0] -eq 63 -and $before[1] -eq 63 -and $before[2] -eq 63 -and $before[3] -eq 63)
        if (-not $ok) {
            Add-Reason 'frame_before_mismatch' ("Frame before must be [63,63,63,63]; observed [$($before -join ',')]") 'diagnostic' $Line $Seq $Phase
        }
    }
    if ($null -ne $after) {
        $ok = ($after[0] -eq 62 -and $after[1] -eq 62 -and $after[2] -eq 62 -and $after[3] -eq 62)
        if (-not $ok) {
            Add-Reason 'frame_after_mismatch' ("Frame after must be [62,62,62,62]; observed [$($after -join ',')]") 'diagnostic' $Line $Seq $Phase
        }
    }
}

function Validate-BaselineOrClear {
    param($Record, [int]$Line, [object]$Seq, [string]$Phase)
    $column = Get-Int $Record 'column' $Line $Seq $Phase 0 255
    $mask = Get-Int $Record 'mask' $Line $Seq $Phase 0 255
    if ($null -ne $column -and $column -ne 15) {
        Add-Reason 'unsupported_column' ("Column $column is outside the proved column-15 slice") 'inconclusive' $Line $Seq $Phase
        $script:flags.unsupportedColumn = $true
    }
    if ($null -ne $mask -and $mask -ne 1) {
        Add-Reason 'unsupported_mask' ("Mask $mask is outside the proved mask-1 slice") 'inconclusive' $Line $Seq $Phase
        $script:flags.unsupportedMask = $true
    }
    Validate-Output $Record $Line $Seq $Phase
    Validate-Cpu $Record $Line $Seq $Phase
    Validate-Frames $Record $Line $Seq $Phase
}

function Validate-Write {
    param($Record, [int]$Line, [object]$Seq, [string]$Phase)
    $dp = Get-Int $Record 'dp' $Line $Seq $Phase 0 255
    $muxWord = Get-Int $Record 'muxWord' $Line $Seq $Phase 0 65535
    $frame = Get-Int $Record 'frame' $Line $Seq $Phase 0 3
    $sample = Get-Int $Record 'sample' $Line $Seq $Phase 0 3
    $x = Get-Int $Record 'x' $Line $Seq $Phase 0 65535
    $b = Get-Int $Record 'b' $Line $Seq $Phase 0 255
    $selectedRam = Get-Int $Record 'selectedRam' $Line $Seq $Phase 0 255
    if ($null -ne $dp -and $dp -ne 0) {
        Add-Reason 'bad_dp' ("DP $dp != 0") 'diagnostic' $Line $Seq $Phase
    }
    if ($null -ne $muxWord -and $muxWord -ne 7) {
        Add-Reason 'bad_muxWord' ("Mux word $muxWord != 7") 'diagnostic' $Line $Seq $Phase
    }
    if ($null -ne $frame -and $null -ne $x) {
        $expectedX = 7 + (16 * $frame)
        if ($x -ne $expectedX) {
            Add-Reason 'bad_x' ("X $x != 7+16*frame ($expectedX)") 'diagnostic' $Line $Seq $Phase
        }
    }
    if ($null -ne $b -and $b -ne 62) {
        Add-Reason 'bad_b' ("B $b != 62 (0x3E)") 'diagnostic' $Line $Seq $Phase
    }
    if ($null -ne $selectedRam -and $selectedRam -ne 62) {
        Add-Reason 'selected_ram_overwritten' ("Selected RAM $selectedRam != 62 (0x3E); frame byte was altered or overwritten") 'inconclusive' $Line $Seq $Phase
        $script:flags.overwrite = $true
    }
    Validate-Output $Record $Line $Seq $Phase
    Validate-Cpu $Record $Line $Seq $Phase
    return [ordered]@{
        dp = $dp
        muxWord = $muxWord
        frame = $frame
        sample = $sample
        x = $x
        b = $b
        selectedRam = $selectedRam
    }
}

$inputSha = $null
$ioError = $false
$records = [System.Collections.Generic.List[object]]::new()

try {
    if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
        Add-Reason 'input_not_found' ("Input JSONL not found: $InputPath") 'structure' -1 $null $null
        $ioError = $true
    } else {
        $bytes = [System.IO.File]::ReadAllBytes($InputPath)
        $sha = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
        $inputSha = ([System.BitConverter]::ToString($sha) -replace '-', '')
        $lines = [System.IO.File]::ReadAllLines($InputPath)
        if ($lines.Count -eq 0) {
            Add-Reason 'empty_input' 'Input JSONL is empty' 'structure' 0 $null $null
        }
        $lineNo = 0
        foreach ($line in $lines) {
            $lineNo++
            if ([string]::IsNullOrWhiteSpace($line)) {
                Add-Reason 'blank_line' "Blank JSONL line $lineNo" 'structure' $lineNo $null $null
                $records.Add([ordered]@{ phase = $null; seq = $null; time = $null; line = $lineNo; obj = $null })
                continue
            }
            try {
                $obj = $line | ConvertFrom-Json
            } catch {
                Add-Reason 'json_parse' ("Invalid JSON at line $lineNo`: " + $_.Exception.Message) 'structure' $lineNo $null $null
                $records.Add([ordered]@{ phase = $null; seq = $null; time = $null; line = $lineNo; obj = $null })
                continue
            }
            if (-not ($obj -is [pscustomobject])) {
                Add-Reason 'record_not_object' "Line $lineNo is not a JSON object" 'structure' $lineNo $null $null
                $records.Add([ordered]@{ phase = $null; seq = $null; time = $null; line = $lineNo; obj = $null })
                continue
            }
            $phase = $null
            $typeProp = $obj.PSObject.Properties['type']
            if ($null -ne $typeProp) {
                if ($typeProp.Value -is [string]) {
                    $phase = [string]$typeProp.Value
                } else {
                    Add-Reason 'field_type_type' "Field 'type' must be a string" 'structure' $lineNo $null $null
                }
            }
            $seq = Get-Int $obj 'seq' $lineNo $null $phase 0 2147483647
            $time = Get-Time $obj $lineNo $seq $phase
            $expected = @('seq', 'time', 'type')
            $known = $false
            switch -CaseSensitive ($phase) {
                'begin' { $expected += @('schema', 'synthetic'); $known = $true }
                'baseline' { $expected += @('output', 'cpu', 'frames', 'column', 'mask'); $known = $true }
                'clear-return' { $expected += @('output', 'cpu', 'frames', 'column', 'mask'); $known = $true }
                'write-pre' { $expected += @('output', 'cpu', 'dp', 'muxWord', 'frame', 'sample', 'x', 'b', 'selectedRam'); $known = $true }
                'write-post' { $expected += @('output', 'cpu', 'dp', 'muxWord', 'frame', 'sample', 'x', 'b', 'selectedRam'); $known = $true }
            }
            if ($null -ne $phase -and -not $known) {
                Add-Reason 'unknown_phase' ("Unknown phase '$phase'") 'structure' $lineNo $seq $phase
            }
            Check-Keys $obj $expected $lineNo $seq $phase
            switch -CaseSensitive ($phase) {
                'begin' { Validate-Begin $obj $lineNo $seq $phase }
                'baseline' { Validate-BaselineOrClear $obj $lineNo $seq $phase }
                'clear-return' { Validate-BaselineOrClear $obj $lineNo $seq $phase }
                'write-pre' { $script:writeData['write-pre'] = Validate-Write $obj $lineNo $seq $phase }
                'write-post' { $script:writeData['write-post'] = Validate-Write $obj $lineNo $seq $phase }
            }
            $records.Add([ordered]@{ phase = $phase; seq = $seq; time = $time; line = $lineNo; obj = $obj })
        }
    }
} catch {
    Add-Reason 'internal_error' ("Checker internal error: " + $_.Exception.Message) 'structure' 0 $null $null
    $ioError = $true
}

$expectedPhases = @('begin', 'baseline', 'clear-return', 'write-pre', 'write-post')
$observed = @($records | ForEach-Object { $_.phase })
$countsOk = $true
foreach ($p in $expectedPhases) {
    $count = @($observed | Where-Object { $_ -eq $p }).Count
    if ($count -eq 0) {
        Add-Reason 'missing_phase' ("Missing phase '$p'") 'structure' 0 $null $p
        $countsOk = $false
    } elseif ($count -gt 1) {
        Add-Reason 'duplicate_phase' ("Duplicate phase '$p' ($count records)") 'structure' 0 $null $p
        $countsOk = $false
    }
}
if ($records.Count -ne $expectedPhases.Count) {
    Add-Reason 'phase_count' ("Expected 5 records, observed $($records.Count)") 'structure' 0 $null $null
}
$obsCompare = (($observed | ForEach-Object { if ($null -eq $_) { '<null>' } else { [string]$_ } }) -join '|')
$expCompare = ($expectedPhases -join '|')
if ($countsOk -and $obsCompare -ne $expCompare) {
    Add-Reason 'phase_order' ("Phase order '$obsCompare' != '$expCompare'") 'structure' 0 $null $null
}

$prevSeq = $null
$prevTime = $null
foreach ($r in $records) {
    if ($null -ne $r.seq) {
        if ($null -ne $prevSeq -and [decimal]$r.seq -le [decimal]$prevSeq) {
            Add-Reason 'seq_order' ("seq $($r.seq) is not strictly greater than previous $prevSeq") 'structure' $r.line $r.seq $r.phase
        }
        $prevSeq = $r.seq
    }
    if ($null -ne $r.time) {
        if ($null -ne $prevTime -and [double]$r.time -lt [double]$prevTime) {
            Add-Reason 'time_order' ("time $($r.time) is less than previous $prevTime") 'structure' $r.line $r.seq $r.phase
        }
        $prevTime = $r.time
    }
}

if ($script:writeData.ContainsKey('write-pre') -and $script:writeData.ContainsKey('write-post')) {
    $pre = $script:writeData['write-pre']
    $post = $script:writeData['write-post']
    foreach ($f in @('dp', 'muxWord', 'frame', 'sample', 'x', 'b', 'selectedRam')) {
        $a = $pre[$f]
        $b = $post[$f]
        if ($null -ne $a -and $null -ne $b -and $a -ne $b) {
            Add-Reason ('write_pair_mismatch_' + $f) ("write-pre/write-post $f differ: $a/$b; the immediate pair must describe one write") 'diagnostic' 0 $null 'write-post'
        }
    }
}

# Output-manager IDs are opaque u32 values, separate from the lamp's name suffix.
$identityRecords = @($records | Where-Object { $_.phase -in @('baseline','clear-return','write-pre','write-post') })
$firstId = $null
foreach ($r in $identityRecords) {
    $out = Get-Prop $r.obj 'output'
    $id = Get-Prop $out 'id'
    if (Test-Integer $id) {
        if ($null -eq $firstId) { $firstId = $id }
        elseif ($id -ne $firstId) { Add-Reason 'output_id_changed' 'Output-manager ID changed between observations' 'diagnostic' $r.line $r.seq $r.phase }
    }
}
$preRecords = @($records | Where-Object { $_.phase -ceq 'write-pre' })
$postRecords = @($records | Where-Object { $_.phase -ceq 'write-post' })
if ($preRecords.Count -eq 1 -and $postRecords.Count -eq 1) {
    foreach ($field in @('y','u','s')) {
        $a = Get-Prop (Get-Prop $preRecords[0].obj 'cpu') $field
        $b = Get-Prop (Get-Prop $postRecords[0].obj 'cpu') $field
        if ((Test-Integer $a) -and (Test-Integer $b) -and $a -ne $b) {
            Add-Reason ('write_pair_cpu_' + $field) ('STB does not modify ' + $field) 'diagnostic' 0 $null 'write-post'
        }
    }
}
$validationPassed = ($script:reasons.Count -eq 0)
if ($script:flags.structure) {
    $classification = 'invalid_structure'
} elseif ($script:flags.unsupportedColumn) {
    $classification = 'inconclusive_unsupported_column'
} elseif ($script:flags.unsupportedMask) {
    $classification = 'inconclusive_unsupported_mask'
} elseif ($script:flags.noBaselineOne) {
    $classification = 'inconclusive_no_baseline_one'
} elseif ($script:flags.clearReturnNotOne) {
    $classification = 'inconclusive_clear_return_output_not_one'
} elseif ($script:flags.preZero) {
    $classification = 'inconclusive_pre_already_zero'
} elseif ($script:flags.overwrite) {
    $classification = 'inconclusive_overwritten_before_output'
} elseif ($script:flags.noTransition) {
    $classification = 'inconclusive_no_output_transition'
} elseif ($script:flags.diagnostic) {
    $classification = 'invalid_diagnostic'
} elseif ($validationPassed -and $script:synthetic -eq $true) {
    $classification = 'valid_diagnostic_synthetic'
} elseif ($validationPassed) {
    $classification = 'valid_diagnostic_unverified_provenance'
} else {
    $classification = 'invalid_structure'
}

$exitCode = 1
if ($validationPassed) { $exitCode = 0 }
if ($ioError) { $exitCode = 2 }

$script:result = [ordered]@{
    taskId = 'il-lamp-output-sequence-checker'
    sourceTaskId = 'il-lamp-output-sequence-checker-82'
    supervisorRepairTaskId = 'il-lamp-output-supervisor-83'
    sourceCheckerSha256 = '017AB36C190E5C8CAF11585B92F4C0E6DA06040D636430520FCCED60F85D72C8'
    resultSchema = 1
    inputPath = $InputPath
    inputSha256 = $inputSha
    outputPath = $OutputPath
    recordCount = $records.Count
    validationPassed = $validationPassed
    naturalProof = $false
    synthetic = $script:synthetic
    classification = $classification
    reasonCount = $script:reasons.Count
    reasons = @($script:reasons.ToArray())
    exitCode = $exitCode
    scopeNote = 'Offline normalized-record diagnostic only. No capture, source-map, raw-provenance, MAME, compilation, timing or hardware proof.'
}

try {
    $json = $script:result | ConvertTo-Json -Depth 12
    $parent = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrEmpty($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($OutputPath, $json, (New-Object System.Text.UTF8Encoding($false)))
} catch {
    [Console]::Error.WriteLine('CHECKER_OUTPUT_WRITE_ERROR ' + $_.Exception.Message)
    exit 2
}

if ($exitCode -eq 0) {
    Write-Output ('CHECK_PASS classification=' + $classification + ' validationPassed=true naturalProof=false')
} else {
    Write-Output ('CHECK_FAIL classification=' + $classification + ' validationPassed=false naturalProof=false reasons=' + $script:reasons.Count)
}
exit $exitCode

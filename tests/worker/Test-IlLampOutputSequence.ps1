[CmdletBinding()]
param(
    [string]$OutDir
)
$ErrorActionPreference = 'Stop'
$script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$checkerPath = Join-Path $script:RepositoryRoot 'tools/Test-IlLampOutputSequence.ps1'
if (-not (Test-Path -LiteralPath $checkerPath -PathType Leaf)) {
    throw "Tracked checker not found: $checkerPath"
}
$defaultOutputRoot = Join-Path $script:RepositoryRoot 'artifacts/deepseek/il-lamp-output-checker-curation-84'
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
    $OutDir = Join-Path $defaultOutputRoot ('selftest-' + $stamp + '-' + [guid]::NewGuid().ToString('N'))
}
if (-not [IO.Path]::IsPathRooted($OutDir)) {
    throw "OutDir must be an absolute path: $OutDir"
}
$script:OutRoot = [IO.Path]::GetFullPath($OutDir)
if (Test-Path -LiteralPath $script:OutRoot) {
    throw "Output directory already exists; choose a fresh path: $script:OutRoot"
}
$script:OutRootPrefix = $script:OutRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$casesDir = Join-Path $script:OutRoot 'cases'
$outDir = Join-Path $script:OutRoot 'out'
$resultsPath = Join-Path $script:OutRoot 'selftest-results.json'
$inventoryPath = Join-Path $script:OutRoot 'inventory.json'
$finalHashesPath = Join-Path $script:OutRoot 'final-hashes.json'
$runPath = Join-Path $script:OutRoot 'run.json'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$script:powershellExe = Join-Path $PSHOME 'powershell.exe'
if (-not (Test-Path -LiteralPath $script:powershellExe)) { $script:powershellExe = 'powershell.exe' }

function Resolve-OutputPath {
    param([string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($script:OutRootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing path outside the output root: $full"
    }
    return $full
}

$null = Resolve-OutputPath $casesDir
$null = Resolve-OutputPath $outDir
$null = Resolve-OutputPath $resultsPath
$null = Resolve-OutputPath $inventoryPath
$null = Resolve-OutputPath $finalHashesPath
$null = Resolve-OutputPath $runPath
New-Item -ItemType Directory -Path $script:OutRoot | Out-Null
New-Item -ItemType Directory -Path $casesDir | Out-Null
New-Item -ItemType Directory -Path $outDir | Out-Null
$startedUtc = [DateTime]::UtcNow.ToString('o')

$script:cases = [System.Collections.Generic.List[object]]::new()
$script:results = [System.Collections.Generic.List[object]]::new()
$script:checks = [System.Collections.Generic.List[object]]::new()
$script:failures = [System.Collections.Generic.List[string]]::new()

function Add-Check {
    param([string]$Id, [bool]$Ok, [string]$Detail)
    $script:checks.Add([ordered]@{ id = $Id; pass = $Ok; detail = $Detail })
    if (-not $Ok) { $script:failures.Add($Id) }
}

function Add-CaseCheck {
    param([string]$CaseId, $CaseChecks, [string]$Name, [bool]$Ok, [string]$Detail)
    $CaseChecks.Add([ordered]@{ id = $Name; pass = $Ok; detail = $Detail })
    Add-Check ($CaseId + '/' + $Name) $Ok $Detail
}

function Get-Sha256 {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $sha = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    return ([System.BitConverter]::ToString($sha) -replace '-', '')
}

$runRecord = [ordered]@{
    taskId = 'il-lamp-output-sequence-checker'
    sourceTaskId = 'il-lamp-output-sequence-checker-82'
    supervisorRepairTaskId = 'il-lamp-output-supervisor-83'
    resultSchema = 1
    startedUtc = $startedUtc
    outputRoot = $script:OutRoot
    checkerPath = $checkerPath
    checkerSha256 = (Get-Sha256 $checkerPath)
    createOnly = $true
    recursiveDelete = $false
    scope = 'Offline checker selftest only. No MAME, capture, ROM, settings, network or native execution.'
}
[System.IO.File]::WriteAllText($runPath, ($runRecord | ConvertTo-Json -Depth 8), $utf8)

function New-BaseRecords {
    $output1 = [pscustomobject][ordered]@{ id = 120; name = 'lamp120'; roundtripName = 'lamp120'; get = 1; indexed = 1 }
    $output0 = [pscustomobject][ordered]@{ id = 120; name = 'lamp120'; roundtripName = 'lamp120'; get = 0; indexed = 0 }
    $frames = [pscustomobject][ordered]@{ before = @(63, 63, 63, 63); after = @(62, 62, 62, 62) }
    $cpuBaseline = [pscustomobject][ordered]@{ pc = 100; y = 200; u = 300; s = 400; cc = 10 }
    $cpuClear = [pscustomobject][ordered]@{ pc = 252; y = 40726; u = 1646; s = 1944; cc = 208 }
    $cpuPre = [pscustomobject][ordered]@{ pc = 10631; y = 1000; u = 2000; s = 3000; cc = 80 }
    $cpuPost = [pscustomobject][ordered]@{ pc = 10634; y = 1000; u = 2000; s = 3000; cc = 209 }
    return @(
        [pscustomobject][ordered]@{ seq = 0; time = [double]0.0; type = 'begin'; schema = 1; synthetic = $true },
        [pscustomobject][ordered]@{ seq = 1; time = [double]0.5; type = 'baseline'; output = $output1; cpu = $cpuBaseline; frames = $frames; column = 15; mask = 1 },
        [pscustomobject][ordered]@{ seq = 2; time = [double]1.25; type = 'clear-return'; output = $output1; cpu = $cpuClear; frames = $frames; column = 15; mask = 1 },
        [pscustomobject][ordered]@{ seq = 3; time = [double]2.5; type = 'write-pre'; output = $output1; cpu = $cpuPre; dp = 0; muxWord = 7; frame = 1; sample = 1; x = 23; b = 62; selectedRam = 62 },
        [pscustomobject][ordered]@{ seq = 4; time = [double]2.75; type = 'write-post'; output = $output0; cpu = $cpuPost; dp = 0; muxWord = 7; frame = 1; sample = 1; x = 23; b = 62; selectedRam = 62 }
    )
}

function Clone-Records {
    param($Records)
    return @($Records | ForEach-Object { $_ | ConvertTo-Json -Depth 20 | ConvertFrom-Json })
}

function Write-Jsonl {
    param([string]$Path, $Records)
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($r in @($Records)) { $lines.Add(($r | ConvertTo-Json -Compress -Depth 20)) }
    [System.IO.File]::WriteAllLines($Path, $lines.ToArray(), $utf8)
}

function Register-Case {
    param([hashtable]$Spec)
    $script:cases.Add($Spec)
}

function Invoke-Checker {
    param([string]$Id, [string]$InputPath, [string]$OutputPath)
    $InputPath = Resolve-OutputPath $InputPath
    $OutputPath = Resolve-OutputPath $OutputPath
    $stdoutPath = Resolve-OutputPath (Join-Path $outDir ($Id + '.stdout.txt'))
    $stderrPath = Resolve-OutputPath (Join-Path $outDir ($Id + '.stderr.txt'))
    $exitPath = Resolve-OutputPath (Join-Path $outDir ($Id + '.exit.txt'))
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $script:powershellExe
    $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $checkerPath + '" -InputPath "' + $InputPath + '" -OutputPath "' + $OutputPath + '"'
    $psi.WorkingDirectory = $script:RepositoryRoot
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $startError = $null
    $stdout = ''
    $stderr = ''
    $exitCode = -1
    try {
        $null = $process.Start()
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        $exitCode = $process.ExitCode
    } catch {
        $startError = $_.Exception.Message
        $stderr = $startError
    }
    [System.IO.File]::WriteAllText($stdoutPath, $stdout, $utf8)
    [System.IO.File]::WriteAllText($stderrPath, $stderr, $utf8)
    [System.IO.File]::WriteAllText($exitPath, [string]$exitCode, $utf8)
    $json = $null
    $jsonError = $null
    if (Test-Path -LiteralPath $OutputPath -PathType Leaf) {
        try { $json = Get-Content -LiteralPath $OutputPath -Raw | ConvertFrom-Json }
        catch { $jsonError = $_.Exception.Message }
    } else {
        $jsonError = 'Output JSON was not written'
    }
    return [ordered]@{
        exitCode = $exitCode
        stdout = $stdout
        stderr = $stderr
        stdoutPath = $stdoutPath
        stderrPath = $stderrPath
        exitPath = $exitPath
        outputPath = $OutputPath
        json = $json
        jsonError = $jsonError
        startError = $startError
    }
}

$base = @(New-BaseRecords)

Register-Case @{
    id = 'positive_synthetic'
    records = Clone-Records $base
    expect = 'pass'
    validation = $true
    classification = 'valid_diagnostic_synthetic'
    reasons = @()
    synthetic = $true
    supervisorRole = 'positive synthetic diagnostic'
    note = 'Complete synthetic transition must validate while naturalProof stays false.'
}

$r = Clone-Records $base
$r[0].synthetic = $false
Register-Case @{
    id = 'positive_nonsynthetic_unverified'
    records = $r
    expect = 'pass'
    validation = $true
    classification = 'valid_diagnostic_unverified_provenance'
    reasons = @()
    synthetic = $false
    supervisorRole = 'non-synthetic stream validates without natural proof'
    note = 'A standalone stream cannot establish raw MAME provenance even when marked non-synthetic.'
}

$r = Clone-Records $base
$tmp = $r[3]
$r[3] = $r[4]
$r[4] = $tmp
Register-Case @{
    id = 'negative_swapped_phases'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('phase_order')
    supervisorRole = 'swapped phases'
    note = 'write-post appears before write-pre.'
}

$r = Clone-Records $base
$dup = Clone-Records @($r[1])
$r = @($r[0], $r[1], $r[2], $r[3], $r[4], $dup[0])
Register-Case @{
    id = 'negative_duplicate_phase'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('duplicate_phase')
    supervisorRole = 'duplicate phases'
    note = 'baseline appears twice.'
}

$r = @(Clone-Records $base | Where-Object { $_.type -ne 'baseline' })
Register-Case @{
    id = 'negative_missing_phase'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('missing_phase')
    supervisorRole = 'missing phases'
    note = 'baseline is absent.'
}

$r = Clone-Records $base
$r[3].cpu.pc = 10634
Register-Case @{
    id = 'negative_pre_pc_298a'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_diagnostic'
    reasons = @('write_pre_pc_mismatch')
    supervisorRole = 'prePC298A'
    note = 'write-pre uses the post-STB PC.'
}

$r = Clone-Records $base
$r[4].cpu.pc = 10631
Register-Case @{
    id = 'negative_post_pc_2987'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_diagnostic'
    reasons = @('write_post_pc_mismatch')
    supervisorRole = 'postPC2987'
    note = 'write-post uses the pre-STB PC.'
}

$r = Clone-Records $base
$r[1].output.get = 0
$r[1].output.indexed = 0
Register-Case @{
    id = 'negative_no_baseline_one'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'inconclusive_no_baseline_one'
    reasons = @('baseline_output_not_one')
    supervisorRole = 'no baseline1'
    note = 'baseline lamp120 value is zero.'
}

$r = Clone-Records $base
$r[3].output.get = 0
$r[3].output.indexed = 0
Register-Case @{
    id = 'negative_pre_already_zero'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'inconclusive_pre_already_zero'
    reasons = @('pre_output_not_one')
    supervisorRole = 'prior1 but immediatepre0'
    note = 'baseline is one but the immediate pre-write output is zero.'
}

$r = Clone-Records $base
$r[1].output.id = 0
$r[1].output.get = 0
$r[1].output.indexed = 0
Register-Case @{
    id = 'negative_id_zero_returning_zero'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_diagnostic'
    reasons = @('output_id_zero')
    supervisorRole = 'missing name id0 returning0'
    note = 'Missing output name is represented by id 0 and get/indexed 0.'
}

$r = Clone-Records $base
$r[1].output.PSObject.Properties.Remove('name')
Register-Case @{
    id = 'negative_missing_name'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('missing_field')
    supervisorRole = 'missing name field'
    note = 'Required output.name is absent.'
}

$r = Clone-Records $base
$r[1].output.roundtripName = 'lamp121'
Register-Case @{
    id = 'negative_roundtrip_mismatch'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_diagnostic'
    reasons = @('output_name_roundtrip_mismatch')
    supervisorRole = 'mismatchedname/id (roundtrip)'
    note = 'id_to_name roundtrip does not match name_to_id name.'
}

$r = Clone-Records $base
$r[1].output.id = 121
$r[1].output.name = 'lamp121'
$r[1].output.roundtripName = 'lamp121'
Register-Case @{
    id = 'negative_id_name_mismatch'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_diagnostic'
    reasons = @('output_id_changed', 'output_name_mismatch')
    supervisorRole = 'mismatchedname/id'
    note = 'Output identity is not the proved lamp120 id/name.'
}

$r = Clone-Records $base
$r[1].output.indexed = 0
Register-Case @{
    id = 'negative_get_index_disagreement'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'inconclusive_no_baseline_one'
    reasons = @('output_get_indexed_mismatch')
    supervisorRole = 'get/index disagreement'
    note = 'get_value and get_indexed_value disagree.'
}

$r = Clone-Records $base
$r[1].output.get = 2
$r[1].output.indexed = 2
Register-Case @{
    id = 'negative_nonbinary'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('output_nonbinary')
    supervisorRole = 'nonbinary'
    note = 'Output values are not binary.'
}

$r = Clone-Records $base
$r[1].frames.before[0] = 62
Register-Case @{
    id = 'negative_frame_before_altered'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_diagnostic'
    reasons = @('frame_before_mismatch')
    supervisorRole = 'altered/missing frame byte'
    note = 'Before byte at 010F is altered.'
}

$r = Clone-Records $base
$r[2].frames.after[0] = 61
Register-Case @{
    id = 'negative_frame_after_altered'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_diagnostic'
    reasons = @('frame_after_mismatch')
    supervisorRole = 'altered/missing frame byte'
    note = 'After byte at 010F is altered.'
}

$r = Clone-Records $base
$r[2].frames.PSObject.Properties.Remove('after')
Register-Case @{
    id = 'negative_frame_missing'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('missing_field')
    supervisorRole = 'altered/missing frame byte'
    note = 'frames.after is absent.'
}

$r = Clone-Records $base
$r[1].column = 14
Register-Case @{
    id = 'negative_wrong_column'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'inconclusive_unsupported_column'
    reasons = @('unsupported_column')
    supervisorRole = 'wrong column/bit'
    note = 'Column 14 is outside the proved column-15 slice.'
}

$r = Clone-Records $base
$r[1].mask = 2
Register-Case @{
    id = 'negative_wrong_mask'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'inconclusive_unsupported_mask'
    reasons = @('unsupported_mask')
    supervisorRole = 'wrong column/bit'
    note = 'Mask 2 is outside the proved mask-1 slice.'
}

$r = Clone-Records $base
$r[3].frame = 4
Register-Case @{
    id = 'negative_frame_out_of_range'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('field_range_frame')
    supervisorRole = 'out-of-rangeframe/sample'
    note = 'Frame index is 4.'
}

$r = Clone-Records $base
$r[3].sample = 4
Register-Case @{
    id = 'negative_sample_out_of_range'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('field_range_sample')
    supervisorRole = 'out-of-rangeframe/sample'
    note = 'Sample index is 4.'
}

$r = Clone-Records $base
$r[3].x = 22
Register-Case @{
    id = 'negative_bad_x'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_diagnostic'
    reasons = @('bad_x')
    supervisorRole = 'badX/DP/B'
    note = 'X is not 7+16*frame.'
}

$r = Clone-Records $base
$r[3].dp = 1
Register-Case @{
    id = 'negative_bad_dp'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_diagnostic'
    reasons = @('bad_dp')
    supervisorRole = 'badX/DP/B'
    note = 'DP is not zero.'
}

$r = Clone-Records $base
$r[3].b = 63
Register-Case @{
    id = 'negative_bad_b'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_diagnostic'
    reasons = @('bad_b')
    supervisorRole = 'badX/DP/B'
    note = 'B is not 0x3E.'
}

$r = Clone-Records $base
$r[4].seq = 3
Register-Case @{
    id = 'negative_backward_seq'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('seq_order')
    supervisorRole = 'backward time/seq'
    note = 'write-post seq is not strictly greater than write-pre.'
}

$r = Clone-Records $base
$r[4].time = [double]0.25
Register-Case @{
    id = 'negative_backward_time'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('time_order')
    supervisorRole = 'backward time/seq'
    note = 'write-post time is earlier than write-pre.'
}

$r = Clone-Records $base
$r[0] | Add-Member -NotePropertyName naturalProof -NotePropertyValue $true
Register-Case @{
    id = 'negative_synthetic_claims_natural'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('unknown_field')
    supervisorRole = 'claims from synthetic records'
    note = 'A synthetic input may not add a naturalProof claim.'
}

$r = Clone-Records $base
$r[3].output.get = 0
$r[3].output.indexed = 0
$r[4].output.get = 0
$r[4].output.indexed = 0
Register-Case @{
    id = 'negative_pre_zero_post_zero'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'inconclusive_pre_already_zero'
    reasons = @('pre_output_not_one')
    supervisorRole = 'source control: pre zero/post zero after baseline one'
    note = 'An earlier baseline one does not excuse an already-zero immediate pre-write value.'
}

$r = Clone-Records $base
$r[4].output.get = 1
$r[4].output.indexed = 1
Register-Case @{
    id = 'negative_same_strobe_no_change'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'inconclusive_no_output_transition'
    reasons = @('post_output_not_zero')
    supervisorRole = 'source control: same-strobe portwrite no output change'
    note = 'PRE and POST remain one; a port write alone is not an output transition.'
}

$r = Clone-Records @($base[2])
Register-Case @{
    id = 'negative_clearreturn_only'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('missing_phase')
    supervisorRole = 'source control: clearreturn event alone'
    note = 'A clear-return record without begin/baseline/write pair fails.'
}

$r = Clone-Records $base
$r[1].time = 'NaN'
Register-Case @{
    id = 'negative_time_nan_string'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('field_type_time')
    supervisorRole = 'source control: nonfinite time'
    note = 'A nonfinite time token is not a JSON number and is rejected.'
}

Register-Case @{
    id = 'negative_time_huge_exponent'
    rawLines = @('{"seq":0,"time":1e999,"type":"begin","schema":1,"synthetic":true}')
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('json_parse')
    supervisorRole = 'source control: nonfinite time'
    note = 'A nonfinite numeric representation is rejected by strict JSON parsing.'
}

$r = Clone-Records $base
$r[2].cpu.pc = 252.5
Register-Case @{
    id = 'negative_fractional_cpu'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('field_type_pc')
    supervisorRole = 'source control: CPUinteger'
    note = 'A fractional CPU register is not a JSON integer.'
}

$r = Clone-Records $base
$r[0].seq = '0'
Register-Case @{
    id = 'negative_string_seq'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('field_type_seq')
    supervisorRole = 'source control: type coercion'
    note = 'A string seq is not coerced to an integer.'
}

$r = Clone-Records $base
$r[1].output.get = '1'
Register-Case @{
    id = 'negative_string_output_get'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('field_type_get')
    supervisorRole = 'source control: type coercion'
    note = 'A string output value is not coerced to an integer.'
}

$r = Clone-Records $base
$r[0] | Add-Member -NotePropertyName extra -NotePropertyValue $true
Register-Case @{
    id = 'negative_unknown_field'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('unknown_field')
    supervisorRole = 'unknown field'
    note = 'Unknown fields fail closed.'
}

$r = Clone-Records $base
$r[0].PSObject.Properties.Remove('synthetic')
Register-Case @{
    id = 'negative_missing_begin_field'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('missing_field')
    supervisorRole = 'missing required field'
    note = 'begin.synthetic is absent.'
}

$r = Clone-Records $base
$r[0].schema = 2
Register-Case @{
    id = 'negative_schema_version'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('schema_version_mismatch')
    supervisorRole = 'unknown schema'
    note = 'Only schema 1 is accepted.'
}

$r = Clone-Records $base
$r[0].synthetic = 'true'
Register-Case @{
    id = 'negative_synthetic_type'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('field_type_synthetic')
    supervisorRole = 'synthetic boolean type'
    note = 'synthetic must be a JSON boolean, not a string.'
}

$r = Clone-Records $base
$r[1].type = 'foo'
Register-Case @{
    id = 'negative_unknown_phase'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_structure'
    reasons = @('unknown_phase')
    supervisorRole = 'unknown phase'
    note = 'A phase outside the fixed five is rejected.'
}

$r = Clone-Records $base
$r[4].selectedRam = 63
Register-Case @{
    id = 'negative_selected_ram_overwrite'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'inconclusive_overwritten_before_output'
    reasons = @('selected_ram_overwritten')
    supervisorRole = 'altered/missing frame byte'
    note = 'The selected frame byte was overwritten before the measured write.'
}

$r = Clone-Records $base
$r[4].frame = 2
$r[4].x = 39
Register-Case @{
    id = 'negative_write_pair_frame_mismatch'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_diagnostic'
    reasons = @('write_pair_mismatch_frame', 'write_pair_mismatch_x')
    supervisorRole = 'unobserved overwrite between immediate pair'
    note = 'The immediate pair does not describe one scanner write.'
}

$r = Clone-Records $base
$r[2].output.get = 0
$r[2].output.indexed = 0
Register-Case @{
    id = 'negative_clear_return_output_zero'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'inconclusive_clear_return_output_not_one'
    reasons = @('clear_return_output_not_one')
    supervisorRole = 'clear-return baseline value'
    note = 'The return boundary does not observe lamp120=1.'
}

Register-Case @{
    id = 'negative_input_missing'
    missingInput = $true
    expect = 'fail'
    exitCode = 2
    validation = $false
    classification = 'invalid_structure'
    reasons = @('input_not_found')
    supervisorRole = 'invocation/IO fail closed'
    note = 'A missing JSONL path exits 2 and writes a diagnostic result.'
}

$r = Clone-Records $base
foreach ($i in 1, 2, 3, 4) { $r[$i].output.id = 70001 }
Register-Case @{
    id = 'positive_opaque_id'
    records = $r
    expect = 'pass'
    validation = $true
    classification = 'valid_diagnostic_synthetic'
    reasons = @()
    synthetic = $true
    supervisorRole = '83 independent control: opaque ID 70001'
    note = 'Opaque nonzero u32 output id 70001 is accepted when stable and the lamp120 names match exactly.'
}

$r = Clone-Records $base
foreach ($i in 1, 2, 3, 4) { $r[$i].output.id = 70001 }
$r[4].output.id = 70002
Register-Case @{
    id = 'negative_changed_id'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_diagnostic'
    reasons = @('output_id_changed')
    synthetic = $true
    supervisorRole = '83 independent control: changed ID'
    note = 'The opaque output id must stay stable across observations.'
}

$r = Clone-Records $base
foreach ($i in 1, 2, 3, 4) { $r[$i].output.id = 70001 }
$r[4].cpu.u = 2001
Register-Case @{
    id = 'negative_stb_cpu_u'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_diagnostic'
    reasons = @('write_pair_cpu_u')
    synthetic = $true
    supervisorRole = '83 independent control: STB U corruption'
    note = 'The immediate STB pair must preserve U.'
}

$r = Clone-Records $base
foreach ($i in 1, 2, 3, 4) { $r[$i].output.id = 70001 }
$r[4].cpu.s = 3001
Register-Case @{
    id = 'negative_stb_cpu_s'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_diagnostic'
    reasons = @('write_pair_cpu_s')
    synthetic = $true
    supervisorRole = '83 independent control: STB S corruption'
    note = 'The immediate STB pair must preserve S.'
}

$r = Clone-Records $base
foreach ($i in 1, 2, 3, 4) { $r[$i].output.id = 70001 }
$r[4].cpu.y = 1001
Register-Case @{
    id = 'negative_stb_cpu_y'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_diagnostic'
    reasons = @('write_pair_cpu_y')
    synthetic = $true
    supervisorRole = '83 independent control: STB Y corruption'
    note = 'The immediate STB pair must preserve Y.'
}

$r = Clone-Records $base
foreach ($i in 1, 2, 3, 4) { $r[$i].output.id = 70001 }
$r[4].output.name = 'Lamp120'
$r[4].output.roundtripName = 'Lamp120'
Register-Case @{
    id = 'negative_case_name'
    records = $r
    expect = 'fail'
    validation = $false
    classification = 'invalid_diagnostic'
    reasons = @('output_name_mismatch')
    synthetic = $true
    supervisorRole = '83 independent control: wrong case lamp name'
    note = 'The lamp name comparison is exact and case-sensitive: Lamp120 is rejected.'
}

foreach ($spec in $script:cases) {
    $id = [string]$spec.id
    $inputPath = Resolve-OutputPath (Join-Path $casesDir ($id + '.jsonl'))
    $outputPath = Resolve-OutputPath (Join-Path $outDir ($id + '.json'))
    if (-not $spec.ContainsKey('missingInput')) {
        if ($spec.ContainsKey('rawLines')) {
            [System.IO.File]::WriteAllLines($inputPath, @($spec.rawLines), $utf8)
        } else {
            Write-Jsonl $inputPath $spec.records
        }
    }
    $run = Invoke-Checker -Id $id -InputPath $inputPath -OutputPath $outputPath
    $caseChecks = [System.Collections.Generic.List[object]]::new()
    $expectedExit = 1
    if ($spec.expect -eq 'pass') { $expectedExit = 0 }
    if ($spec.ContainsKey('exitCode')) { $expectedExit = [int]$spec.exitCode }
    Add-CaseCheck -CaseId $id -CaseChecks $caseChecks -Name 'exit' -Ok ($run.exitCode -eq $expectedExit) -Detail ("expected exit $expectedExit, observed $($run.exitCode)")
    Add-CaseCheck -CaseId $id -CaseChecks $caseChecks -Name 'stderr_empty' -Ok ([string]::IsNullOrEmpty($run.stderr)) -Detail ("stderr: " + $run.stderr)
    $json = $run.json
    Add-CaseCheck -CaseId $id -CaseChecks $caseChecks -Name 'output_json' -Ok ($null -ne $json) -Detail ("output parse: " + $run.jsonError)
    if ($null -ne $json) {
        Add-CaseCheck -CaseId $id -CaseChecks $caseChecks -Name 'exit_output_agrees' -Ok ($json.exitCode -eq $run.exitCode) -Detail ("output exit $($json.exitCode), process exit $($run.exitCode)")
        Add-CaseCheck -CaseId $id -CaseChecks $caseChecks -Name 'validation' -Ok ($json.validationPassed -eq $spec.validation) -Detail ("expected validationPassed $($spec.validation), observed $($json.validationPassed)")
        Add-CaseCheck -CaseId $id -CaseChecks $caseChecks -Name 'naturalProof_false' -Ok ($json.naturalProof -eq $false) -Detail ("naturalProof=$($json.naturalProof)")
        $classifications = @($spec.classification)
        Add-CaseCheck -CaseId $id -CaseChecks $caseChecks -Name 'classification' -Ok ($classifications -contains [string]$json.classification) -Detail ("expected $($classifications -join '|'), observed $($json.classification)")
        if ($spec.ContainsKey('synthetic')) {
            Add-CaseCheck -CaseId $id -CaseChecks $caseChecks -Name 'synthetic' -Ok ($json.synthetic -eq $spec.synthetic) -Detail ("expected synthetic $($spec.synthetic), observed $($json.synthetic)")
        }
        $observedCodes = @($json.reasons | ForEach-Object { [string]$_.code })
        if ($spec.expect -eq 'pass') {
            Add-CaseCheck -CaseId $id -CaseChecks $caseChecks -Name 'no_reasons' -Ok ($observedCodes.Count -eq 0) -Detail ("unexpected reasons: " + ($observedCodes -join ','))
        } else {
            foreach ($code in @($spec.reasons)) {
                Add-CaseCheck -CaseId $id -CaseChecks $caseChecks -Name ('reason_' + $code) -Ok ($observedCodes -contains $code) -Detail ("expected reason $code; observed " + ($observedCodes -join ','))
            }
        }
    }
    $casePass = $true
    foreach ($c in $caseChecks) { if (-not $c.pass) { $casePass = $false } }
    $observedClassification = $null
    $observedReasonCodes = @()
    $observedValidation = $null
    $observedNaturalProof = $null
    $observedSynthetic = $null
    if ($null -ne $json) {
        $observedClassification = $json.classification
        $observedReasonCodes = @($json.reasons | ForEach-Object { [string]$_.code })
        $observedValidation = $json.validationPassed
        $observedNaturalProof = $json.naturalProof
        $observedSynthetic = $json.synthetic
    }
    $script:results.Add([ordered]@{
        id = $id
        supervisorRole = $spec.supervisorRole
        note = $spec.note
        expect = $spec.expect
        inputPath = $inputPath
        inputSha256 = (Get-Sha256 $inputPath)
        outputPath = $outputPath
        outputSha256 = (Get-Sha256 $outputPath)
        stdoutPath = $run.stdoutPath
        stdoutSha256 = (Get-Sha256 $run.stdoutPath)
        stderrPath = $run.stderrPath
        stderrSha256 = (Get-Sha256 $run.stderrPath)
        exitPath = $run.exitPath
        exitCode = $run.exitCode
        expectedExitCode = $expectedExit
        expectedClassification = @($spec.classification)
        expectedReasonCodes = @($spec.reasons)
        observedClassification = $observedClassification
        observedReasonCodes = $observedReasonCodes
        validationPassed = $observedValidation
        naturalProof = $observedNaturalProof
        synthetic = $observedSynthetic
        pass = $casePass
        checks = $caseChecks.ToArray()
    })
}

$supervisorNegatives = [ordered]@{
    'swapped/duplicate/missing phases' = @('negative_swapped_phases', 'negative_duplicate_phase', 'negative_missing_phase')
    'prePC298A' = @('negative_pre_pc_298a')
    'postPC2987' = @('negative_post_pc_2987')
    'no baseline1' = @('negative_no_baseline_one')
    'prior1 but immediatepre0' = @('negative_pre_already_zero')
    'missing name id0 returning0' = @('negative_id_zero_returning_zero', 'negative_missing_name')
    'mismatchedname/id' = @('negative_roundtrip_mismatch', 'negative_id_name_mismatch')
    'get/index disagreement' = @('negative_get_index_disagreement')
    'nonbinary' = @('negative_nonbinary')
    'altered/missing frame byte' = @('negative_frame_before_altered', 'negative_frame_after_altered', 'negative_frame_missing', 'negative_selected_ram_overwrite')
    'wrong column/bit' = @('negative_wrong_column', 'negative_wrong_mask')
    'out-of-rangeframe/sample' = @('negative_frame_out_of_range', 'negative_sample_out_of_range')
    'badX/DP/B' = @('negative_bad_x', 'negative_bad_dp', 'negative_bad_b')
    'backward time/seq' = @('negative_backward_time', 'negative_backward_seq')
    'claims from synthetic records' = @('negative_synthetic_claims_natural')
    'source controls' = @('negative_pre_zero_post_zero', 'negative_same_strobe_no_change', 'negative_clearreturn_only', 'negative_time_nan_string', 'negative_time_huge_exponent', 'negative_fractional_cpu', 'negative_string_seq', 'negative_string_output_get')
    '83 independent controls' = @('positive_opaque_id', 'negative_changed_id', 'negative_stb_cpu_u', 'negative_stb_cpu_s', 'negative_stb_cpu_y', 'negative_case_name')
}

$result = [ordered]@{
    taskId = 'il-lamp-output-sequence-checker'
    sourceTaskId = 'il-lamp-output-sequence-checker-82'
    supervisorRepairTaskId = 'il-lamp-output-supervisor-83'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    outputRoot = $script:OutRoot
    createOnly = $true
    recursiveDelete = $false
    checkerPath = $checkerPath
    checkerSha256 = (Get-Sha256 $checkerPath)
    sourceCheckerSha256 = '017AB36C190E5C8CAF11585B92F4C0E6DA06040D636430520FCCED60F85D72C8'
    baseRecords = 'synthetic normalized JSONL generated in tests/worker/Test-IlLampOutputSequence.ps1'
    scope = 'Offline checker selftest only. No MAME, capture, ROM, settings, network or native execution.'
    caseCount = $script:cases.Count
    checkCount = $script:checks.Count
    failureCount = $script:failures.Count
    pass = ($script:failures.Count -eq 0)
    failures = @($script:failures.ToArray())
    supervisorNegatives = $supervisorNegatives
    cases = @($script:results.ToArray())
    checks = @($script:checks.ToArray())
}
[System.IO.File]::WriteAllText($resultsPath, ($result | ConvertTo-Json -Depth 20), $utf8)

$docsPath = Join-Path $script:RepositoryRoot 'docs/recovery/IL-LAMP-OUTPUT-SEQUENCE.md'
$repositoryPrefix = $script:RepositoryRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
function Get-DisplayPath {
    param([string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    if ($full.StartsWith($repositoryPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($repositoryPrefix.Length)
    }
    return $full
}

$inventoryFiles = [System.Collections.Generic.List[object]]::new()
$inventoryPaths = @()
$inventoryPaths += Get-ChildItem -LiteralPath $script:OutRoot -Recurse -File | Where-Object { $_.FullName -ne $inventoryPath -and $_.FullName -ne $finalHashesPath }
$inventoryPaths += Get-Item -LiteralPath $checkerPath
$inventoryPaths += Get-Item -LiteralPath $PSCommandPath
if (Test-Path -LiteralPath $docsPath -PathType Leaf) { $inventoryPaths += Get-Item -LiteralPath $docsPath }
foreach ($file in $inventoryPaths) {
    $inventoryFiles.Add([ordered]@{
        path = Get-DisplayPath $file.FullName
        bytes = $file.Length
        sha256 = (Get-Sha256 $file.FullName)
    })
}
$inventory = [ordered]@{
    taskId = 'il-lamp-output-sequence-checker'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    root = $script:OutRoot
    repositoryRoot = $script:RepositoryRoot
    note = 'Inventory excludes itself and final-hashes.json; those hashes are recorded in final-hashes.json.'
    files = @($inventoryFiles.ToArray())
}
[System.IO.File]::WriteAllText($inventoryPath, ($inventory | ConvertTo-Json -Depth 8), $utf8)

$finalHashes = [ordered]@{
    taskId = 'il-lamp-output-sequence-checker'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    outputRoot = $script:OutRoot
    checkerPs1 = (Get-Sha256 $checkerPath)
    selftestPs1 = (Get-Sha256 $PSCommandPath)
    docsMd = (Get-Sha256 $docsPath)
    sourceCheckerSha256 = '017AB36C190E5C8CAF11585B92F4C0E6DA06040D636430520FCCED60F85D72C8'
    selftestResultsJson = (Get-Sha256 $resultsPath)
    inventoryJson = (Get-Sha256 $inventoryPath)
    runJson = (Get-Sha256 $runPath)
}
[System.IO.File]::WriteAllText($finalHashesPath, ($finalHashes | ConvertTo-Json -Depth 6), $utf8)
$finalHashes.hashesJson = (Get-Sha256 $finalHashesPath)

Write-Output ('SELFTEST cases=' + $result.caseCount + ' checks=' + $result.checkCount + ' failures=' + $result.failureCount + ' pass=' + $result.pass)
foreach ($r in $script:results) {
    Write-Output ('CASE ' + $r.id + ' exit=' + $r.exitCode + ' expected=' + $r.expectedExitCode + ' class=' + $r.observedClassification + ' pass=' + $r.pass)
}
Write-Output ('HASH tools/Test-IlLampOutputSequence.ps1 ' + $finalHashes.checkerPs1)
Write-Output ('HASH tests/worker/Test-IlLampOutputSequence.ps1 ' + $finalHashes.selftestPs1)
Write-Output ('HASH docs/recovery/IL-LAMP-OUTPUT-SEQUENCE.md ' + $finalHashes.docsMd)
Write-Output ('HASH selftest-results.json ' + $finalHashes.selftestResultsJson)
Write-Output ('HASH inventory.json ' + $finalHashes.inventoryJson)
Write-Output ('HASH run.json ' + $finalHashes.runJson)
Write-Output ('HASH final-hashes.json ' + $finalHashes.hashesJson)
if ($script:failures.Count -ne 0) { exit 1 }
exit 0


param(
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [Parameter(Mandatory=$true)][string]$OriginalRom,
    [Parameter(Mandatory=$true)][string]$ChangedRom,
    [Parameter(Mandatory=$true)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'

function Get-HashHex([string]$Path, [string]$Algorithm) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        try { return [BitConverter]::ToString($hash.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Get-BytesHashHex([byte[]]$Bytes, [string]$Algorithm) {
    $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
    try { return [BitConverter]::ToString($hash.ComputeHash($Bytes)).Replace('-','').ToLowerInvariant() }
    finally { $hash.Dispose() }
}

function Assert-SyntheticClassification([string]$Text) {
    if ($Text -notmatch '^Synthetic isolated original-VM invocation') { throw 'Classification is not the declared synthetic invocation' }
}

function Assert-ExpectedResult([string]$Variant, [string]$InputValue, [string]$Result, $Expected) {
    $actual = $Expected[$Variant][$InputValue]
    if ($null -eq $actual) { throw "No C# documented result for $Variant/$InputValue" }
    if ($Result -ne $actual) { throw "Observed $Variant/$InputValue result $Result differs from documented C# $actual" }
}

function Assert-ChangedOffsets([byte[]]$Original, [byte[]]$Changed, [int[]]$ExpectedOffsets) {
    $offsets = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -lt $Original.Length; $i++) {
        if ($Original[$i] -ne $Changed[$i]) { $offsets.Add($i) }
    }
    if ($offsets.Count -ne $ExpectedOffsets.Count) { throw "Changed offset count is $($offsets.Count), expected $($ExpectedOffsets.Count)" }
    for ($i = 0; $i -lt $ExpectedOffsets.Count; $i++) {
        if ($offsets[$i] -ne $ExpectedOffsets[$i]) { throw "Changed offset $($offsets[$i]) is not $($ExpectedOffsets[$i])" }
    }
    return $offsets.ToArray()
}

$Expected = @{
    Original = @{ '0000'='0000'; '0080'='FF80'; '0100'='FF00'; 'FFFF'='00FF'; '8000'='8000' }
    Changed  = @{ '0000'='0080'; '0080'='0000'; '0100'='FF80'; 'FFFF'='017F'; '8000'='8080' }
}
$Inputs = @('0000','0080','0100','FFFF','8000')
$ExpectedOriginalSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$ExpectedChangedSha1 = '51e81cc5f41da2aa659a4d14d277e9e78614eb6b'
$ExpectedOriginalSpan = '795BFF80787E795BFF807AAF792F'
$ExpectedChangedSpan = '795BFF00787E795BFF807AAF792F'

$run = [IO.Path]::GetFullPath($RunDirectory)
if (![IO.Directory]::Exists($run)) { throw "Run directory does not exist: $run" }
$capturePath = Join-Path $run 'capture.json'
$capture = Get-Content -LiteralPath $capturePath -Raw | ConvertFrom-Json

$originalSha1 = Get-HashHex $OriginalRom 'SHA1'
$changedSha1 = Get-HashHex $ChangedRom 'SHA1'
if ($originalSha1 -ne $ExpectedOriginalSha1) { throw "Unexpected original SHA1: $originalSha1" }
if ($changedSha1 -ne $ExpectedChangedSha1) { throw "Unexpected changed SHA1: $changedSha1" }
if ($capture.original_rom.sha1 -ne $originalSha1) { throw 'Capture original SHA1 differs from supplied original' }
if ($capture.changed_rom.sha1 -ne $changedSha1) { throw 'Capture changed SHA1 differs from supplied changed image' }
if ($capture.original_rom.span -ne $ExpectedOriginalSpan) { throw 'Capture original span differs' }
if ($capture.changed_rom.span -ne $ExpectedChangedSpan) { throw 'Capture changed span differs' }
if ([int]$capture.case_count -ne 10) { throw "Unexpected case count: $($capture.case_count)" }
if (@($capture.cases).Count -ne 10) { throw 'Capture case rows differ from case_count' }

$originalBytes = [IO.File]::ReadAllBytes($OriginalRom)
$changedBytes = [IO.File]::ReadAllBytes($ChangedRom)
$offsets = Assert-ChangedOffsets $originalBytes $changedBytes @(0x9EDC)
if ($originalBytes[0x9EDC] -ne 0x80 -or $changedBytes[0x9EDC] -ne 0x00) { throw 'Changed operand byte is not 80 -> 00' }

$observed = @{}
$casesOut = New-Object System.Collections.Generic.List[object]
foreach ($case in $capture.cases) {
    $name = [string]$case.name
    $caseRun = Join-Path $run $name
    if (![IO.Directory]::Exists($caseRun)) { throw "Missing case directory: $name" }
    $logPath = Join-Path $caseRun 'debug.log'
    $exitCode = [int](Get-Content -LiteralPath (Join-Path $caseRun 'exit-code.txt') -Raw)
    if ($exitCode -ne 0) { throw "Case $name exit code is $exitCode" }
    $logSha256 = Get-HashHex $logPath 'SHA256'
    if ($logSha256 -ne $case.debug_log_sha256) { throw "Case $name debug log hash differs" }
    $provenance = Get-Content -LiteralPath (Join-Path $caseRun 'provenance.json') -Raw | ConvertFrom-Json
    Assert-SyntheticClassification ([string]$provenance.classification)
    if ($provenance.rom_sha1 -ne $(if ($case.variant -eq 'Original') { $originalSha1 } else { $changedSha1 })) { throw "Case $name provenance identity differs" }
    $runRomSha1 = Get-HashHex (Join-Path $caseRun 'roms/m4addr/a6ls.p1') 'SHA1'
    if ($runRomSha1 -ne $provenance.rom_sha1) { throw "Case $name run ROM identity differs" }

    $log = Get-Content -LiteralPath $logPath -Raw
    $markers = @(
        [regex]::Match($log, 'VM9_RESULT pc=([0-9A-F]{4}) y=([0-9A-F]{4}) u=([0-9A-F]{4}) s=([0-9A-F]{4}) result=([0-9A-F]{4}) frame=([0-9A-F]{4})'),
        [regex]::Match($log, 'VM9_FIRST y=([0-9A-F]{4}) x=([0-9A-F]{4}) u=([0-9A-F]{4}) s=([0-9A-F]{4})'),
        [regex]::Match($log, 'VM9_SPAN bytes=([0-9A-F]{28})'),
        [regex]::Match($log, 'VM9_HEADERS body=([0-9A-F]{4}) litword=([0-9A-F]{4}) add=([0-9A-F]{4}) xor=([0-9A-F]{4}) ret=([0-9A-F]{4})'),
        [regex]::Match($log, 'VM9_TEMPLATE f8=([0-9A-F]{4}) fa=([0-9A-F]{4}) fc=([0-9A-F]{4}) fe=([0-9A-F]{4})')
    )
    foreach ($marker in $markers) { if (!$marker.Success) { throw "Case $name is missing a required marker" } }
    if ($markers[0].Groups[1].Value -ne '7933') { throw "Case $name did not stop after return" }
    if ($markers[0].Groups[2].Value -ne '0782') { throw "Case $name return cursor differs" }
    if ($markers[0].Groups[3].Value -ne '0600') { throw "Case $name U pointer differs" }
    if ($markers[0].Groups[4].Value -ne '0700') { throw "Case $name S pointer differs" }
    if ($markers[0].Groups[6].Value -ne '0782') { throw "Case $name return frame word differs" }
    if ($markers[1].Groups[1].Value -ne '9EDB' -or $markers[1].Groups[2].Value -ne '795D') { throw "Case $name did not enter the original body through header 9ED7" }
    $expectedSpan = if ($case.variant -eq 'Original') { $ExpectedOriginalSpan } else { $ExpectedChangedSpan }
    if ($markers[2].Groups[1].Value -ne $expectedSpan) { throw "Case $name runtime span differs" }
    if ($markers[3].Groups[1].Value -ne '00F8' -or $markers[3].Groups[2].Value -ne '795D' -or
        $markers[3].Groups[3].Value -ne '7880' -or $markers[3].Groups[4].Value -ne '7AB1' -or
        $markers[3].Groups[5].Value -ne '7931') { throw "Case $name original headers differ" }
    if ($markers[4].Groups[1].Value -ne '3420' -or $markers[4].Groups[2].Value -ne '3184' -or
        $markers[4].Groups[3].Value -ne 'AEA1' -or $markers[4].Groups[4].Value -ne '6E91') { throw "Case $name dispatch template differs" }

    if ([string]$case.result -ne $markers[0].Groups[5].Value) { throw "Case $name capture result differs from raw log" }
    if ([string]$case.return_frame -ne $markers[0].Groups[6].Value) { throw "Case $name capture frame differs from raw log" }
    Assert-ExpectedResult ([string]$case.variant) ([string]$case.input) ([string]$case.result) $Expected

    $key = '{0}/{1}' -f $case.variant,$case.input
    if ($observed.ContainsKey($key)) { throw "Duplicate case $key" }
    $observed[$key] = [string]$case.result
    $casesOut.Add([pscustomobject][ordered]@{
        variant = $case.variant
        input = $case.input
        result = $case.result
        documented_csharp_result = $Expected[$case.variant][$case.input]
        u = $case.u
        s = $case.s
        return_frame = $case.return_frame
        pc = $case.pc
        y = $case.y
        first_dispatch = ('{0}/{1}' -f $case.first_dispatch_y,$case.first_dispatch_x)
        runtime_span = $case.runtime_span
        exit_code = $exitCode
        debug_log_sha256 = $logSha256
    })
}
foreach ($variant in @('Original','Changed')) {
    foreach ($input in $Inputs) {
        if (!$observed.ContainsKey(('{0}/{1}' -f $variant,$input))) { throw "Missing case $variant/$input" }
    }
}
$changedDifferenceCount = 0
foreach ($input in $Inputs) {
    if ($observed[('Original/' + $input)] -ne $observed[('Changed/' + $input)]) { $changedDifferenceCount++ }
}
if ($changedDifferenceCount -ne 5) { throw "Expected five original/changed result differences, found $changedDifferenceCount" }

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('fm-general14-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($tempRoot) | Out-Null
try {
    try {
        Assert-ExpectedResult 'Original' '0080' '0000' $Expected
        throw 'Wrong result negative control was accepted'
    }
    catch {
        if ($_.Exception.Message -eq 'Wrong result negative control was accepted') { throw }
        Write-Output ('Negative control rejected wrong result: ' + $_.Exception.Message)
    }
    $badChanged = [byte[]]$changedBytes.Clone()
    $badOffset = 0x9ED9
    $badChanged[$badOffset] = $badChanged[$badOffset] -bxor 0xFF
    try {
        Assert-ChangedOffsets $originalBytes $badChanged @(0x9EDC) | Out-Null
        throw 'Extra changed byte negative control was accepted'
    }
    catch {
        if ($_.Exception.Message -eq 'Extra changed byte negative control was accepted') { throw }
        Write-Output ('Negative control rejected extra changed byte: ' + $_.Exception.Message)
    }
    try {
        Assert-SyntheticClassification 'Natural reset boot observation'
        throw 'Natural classification negative control was accepted'
    }
    catch {
        if ($_.Exception.Message -eq 'Natural classification negative control was accepted') { throw }
        Write-Output ('Negative control rejected natural classification: ' + $_.Exception.Message)
    }
}
finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }

$output = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = [IO.Path]::GetDirectoryName($output)
if (![IO.Directory]::Exists($outputDirectory)) { throw "Output directory does not exist: $outputDirectory" }
if ([IO.File]::Exists($output) -or [IO.Directory]::Exists($output)) { throw "Output already exists: $output" }

$report = [ordered]@{
    schema_version = 1
    classification = 'Independent MAME original-threaded-interpreter observation of checked 9ED9 original and changed definitions. Synthetic isolated invocation with explicit PC/register/RAM stack and caller-stream seeding; no natural reset, gameplay or hardware claim.'
    evidence_class = @{
        mame = 'Synthetic original-ROM execution through the original 6809 threaded interpreter, word headers and return frame'
        emitted_image = 'Changed image emitted by the existing C# Mpu4VmDefinition.WithLiteral(0, FF00).Apply(original) path'
        comparison = 'C# documented results are used only after the MAME observation for comparison'
        not_claimed = @('natural reset', 'gameplay', 'firmware integrity repair', 'relocation', 'general editor', 'physical hardware')
    }
    source = @{
        definition = 'evidence/mpu4/definitions/bias-word-signed-value-9ed9.vm.json'
        original_rom = @{ length=65536; sha1=$originalSha1; sha256=(Get-HashHex $OriginalRom 'SHA256'); span=$ExpectedOriginalSpan }
        changed_rom = @{ length=65536; sha1=$changedSha1; sha256=(Get-HashHex $ChangedRom 'SHA256'); span=$ExpectedChangedSpan; changed_offsets=@(0x9EDC); changed_offsets_hex=@('9EDC') }
        emitted_original_sha1_matches = ($capture.original_rom.sha1 -eq $originalSha1)
        emitted_changed_sha1_matches = ($capture.changed_rom.sha1 -eq $changedSha1)
    }
    mame = $capture.mame
    seeding = $capture.seeding
    contract = $capture.contract
    headers = @{ body='00F8'; litword='795D'; add='7880'; xor='7AB1'; ret='7931' }
    dispatch_template = @{ f8='3420'; fa='3184'; fc='AEA1'; fe='6E91' }
    case_count = $casesOut.Count
    matched_case_count = $casesOut.Count
    original_changed_difference_count = $changedDifferenceCount
    cases = $casesOut
    checks = [ordered]@{
        original_identity = $true
        changed_only_at_9edc = $true
        original_span_matches_definition = $true
        changed_span_matches_definition = $true
        original_headers_and_template = $true
        body_entered_through_word_header = $true
        result_observed_at_u_with_input_consumed = $true
        return_frame_observed = $true
        all_ten_mame_results_match_documented_csharp = $true
        five_original_changed_result_differences = $true
        wrong_result_negative_rejected = $true
        extra_changed_byte_negative_rejected = $true
        natural_classification_negative_rejected = $true
    }
    negative_controls = @(
        'In-memory wrong result Original/0080=0000 rejected against documented FF80.',
        'Temporary changed image with an extra 9ED9 byte rejected by exact changed-offset checking.',
        'Natural-reset classification rejected by the synthetic-only classification guard.'
    )
    raw_run = @{ path = $run; capture_sha256 = (Get-HashHex $capturePath 'SHA256') }
}
$json = $report | ConvertTo-Json -Depth 12
$stream = New-Object System.IO.FileStream -ArgumentList @($output,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
try {
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $stream.Write($bytes,0,$bytes.Length)
}
finally { $stream.Dispose() }
Write-Output $output

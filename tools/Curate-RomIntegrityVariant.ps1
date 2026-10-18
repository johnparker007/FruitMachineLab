param(
    [Parameter(Mandatory=$true)][ValidateSet('Original','UnrepairedPatch','RepairedPatch')][string]$Variant,
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [Parameter(Mandatory=$true)][string]$ExpectedRomSha1,
    [Parameter(Mandatory=$true)][string]$ExpectedRomSha256,
    [switch]$NegativeControl
)
$ErrorActionPreference = 'Stop'

$OriginalSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$ExpectedOriginalFields = '3E761E2605'
$ExpectedRepairedFields = '40701CFA02'
$ExpectedBpsetAddresses = @('7cd1','6750','66a5','66db','66f3','6715','674c','674f','677e','67b3','3b1a','7cf6','76c7')

function Get-HashHex([string]$Path, [string]$Algorithm) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        try { return [BitConverter]::ToString($hash.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Read-Json([string]$Path) { return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json) }

function Get-Field([string]$Line, [string]$Name) {
    $m = [regex]::Match($Line, ('\b' + [regex]::Escape($Name) + '=([0-9A-Fa-f]+)'))
    if (!$m.Success) { throw "Missing field $Name in: $Line" }
    return $m.Groups[1].Value.ToUpperInvariant()
}

function Find-MarkerIndex([string[]]$Lines, [string]$Pattern, [int]$Start = 0) {
    for ($i = $Start; $i -lt $Lines.Count; $i++) { if ($Lines[$i] -match $Pattern) { return $i } }
    return -1
}

function Find-MarkerIndexBackward([string[]]$Lines, [string]$Pattern, [int]$Start) {
    for ($i = $Start; $i -ge 0; $i--) { if ($Lines[$i] -match $Pattern) { return $i } }
    return -1
}

function Get-ArgValue([string[]]$Values, [string]$Name) {
    for ($i = 0; $i -lt $Values.Count; $i++) {
        if ($Values[$i] -ieq $Name) {
            if ($i + 1 -ge $Values.Count) { throw "Missing value for argument $Name" }
            return $Values[$i + 1]
        }
    }
    throw "Missing argument $Name"
}

function Test-SuccessLog([string]$Log, [string]$ExpectedFields) {
    $lines = @($Log -split "\r?\n")
    if ($Log -match '(?m)^VARIANT_ROM_VERIFY_FAILED ') { throw 'Verifier failure marker is present' }
    if (@($lines | Where-Object { $_ -match '^VARIANT_RESET pc=7CD1\b' }).Count -eq 0) { throw 'Missing reset marker' }
    if (@($lines | Where-Object { $_ -match '^VARIANT_INIT_ENTRY pc=6750\b' }).Count -eq 0) { throw 'Missing init marker' }

    $tailIndex = Find-MarkerIndex $lines '^VARIANT_INIT_TAIL_JMP pc=67B3\b' 0
    if ($tailIndex -lt 0) { throw 'Missing init-tail marker' }
    if (@($lines | Where-Object { $_ -match '^VARIANT_INIT_TAIL_JMP pc=67B3\b' }).Count -ne 1) { throw 'Expected exactly one init-tail marker' }
    if (@($lines | Where-Object { $_ -match '^VARIANT_VM_ENTRY pc=76C7\b' }).Count -ne 1) { throw 'Expected exactly one VM entry marker' }

    $backSpecs = @(
        @{ Key = 'return'; Pattern = '^VARIANT_ROM_CHECK_RETURN pc=677E\b' },
        @{ Key = 'rotate_sub'; Pattern = '^VARIANT_ROTATE_SUB_XOR ' },
        @{ Key = 'rotate_add'; Pattern = '^VARIANT_ROTATE_ADD ' },
        @{ Key = 'sum'; Pattern = '^VARIANT_SUM_XOR ' },
        @{ Key = 'verify'; Pattern = '^VARIANT_ROM_VERIFY_ENTRY pc=66DB\b' },
        @{ Key = 'check'; Pattern = '^VARIANT_ROM_CHECK_ENTRY pc=66A5\b' }
    )
    $ordered = [ordered]@{}
    $cursor = $tailIndex
    foreach ($spec in $backSpecs) {
        $index = Find-MarkerIndexBackward $lines $spec.Pattern ($cursor - 1)
        if ($index -lt 0) { throw ('Checksum marker missing or out of order before init tail: ' + $spec.Key) }
        $ordered[$spec.Key] = [ordered]@{ index = $index; line = $lines[$index] }
        $cursor = $index
    }
    $ordered['init_tail_jmp'] = [ordered]@{ index = $tailIndex; line = $lines[$tailIndex] }
    $start = $tailIndex + 1
    $forwardSpecs = @(
        @{ Key = 'init_tail_entry'; Pattern = '^VARIANT_INIT_TAIL_ENTRY pc=3B1A\b' },
        @{ Key = 'vm_call'; Pattern = '^VARIANT_VM_CALL pc=7CF6\b' },
        @{ Key = 'vm_entry'; Pattern = '^VARIANT_VM_ENTRY pc=76C7\b' },
        @{ Key = 'end'; Pattern = '^VARIANT_CAPTURE_END pc=76C7\b' }
    )
    foreach ($spec in $forwardSpecs) {
        $index = Find-MarkerIndex $lines $spec.Pattern $start
        if ($index -lt 0) { throw ('Chronological startup marker missing or out of order: ' + $spec.Key) }
        $ordered[$spec.Key] = [ordered]@{ index = $index; line = $lines[$index] }
        $start = $index + 1
    }
    for ($i = $ordered['end'].index + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^VARIANT_') { throw "Capture marker after VARIANT_CAPTURE_END: $($lines[$i])" }
    }

    $verify = $ordered['verify'].line
    $sum = $ordered['sum'].line
    $rotateAdd = $ordered['rotate_add'].line
    $rotateSub = $ordered['rotate_sub'].line
    $vmCall = $ordered['vm_call'].line
    $vmEntry = $ordered['vm_entry'].line
    $end = $ordered['end'].line
    $expected = Get-Field $verify 'expected'
    $startAddr = Get-Field $verify 'start'
    $endAddr = Get-Field $verify 'end'
    $errorCode = Get-Field $verify 'error'
    $sumValue = Get-Field $sum 'sum'
    $xorValue = Get-Field $sum 'xor'
    $rotateAddValue = Get-Field $rotateAdd 'value'
    $rotateSubA = Get-Field $rotateSub 'a'
    $rotateSubB = Get-Field $rotateSub 'b'
    $computed = $sumValue + $xorValue + $rotateAddValue + $rotateSubA + $rotateSubB
    $failed = @()
    if ($expected -ne $ExpectedFields) { $failed += "expected=$expected" }
    if ($computed -ne $ExpectedFields) { $failed += "computed=$computed" }
    if ($startAddr -ne '1400') { $failed += "start=$startAddr" }
    if ($endAddr -ne 'FFFF') { $failed += "end=$endAddr" }
    if ($errorCode -ne '12') { $failed += "error=$errorCode" }
    if ((Get-Field $vmCall 'x') -ne 'FDF0') { $failed += 'vm_call_x' }
    if ((Get-Field $vmEntry 'x') -ne 'FDF0') { $failed += 'vm_entry_x' }
    if ((Get-Field $end 'x') -ne 'FDF0') { $failed += 'end_x' }
    if ($failed.Count -gt 0) { throw ('Captured success result differs: ' + ($failed -join ', ')) }

    return [ordered]@{
        outcome = 'passed'
        check_entry = $ordered['check'].line
        verify_entry = $verify
        sum_xor = $sum
        rotate_add = $rotateAdd
        rotate_sub_xor = $rotateSub
        checksum_return = $ordered['return'].line
        init_tail_jump = $ordered['init_tail_jmp'].line
        init_tail_entry = $ordered['init_tail_entry'].line
        vm_call = $vmCall
        vm_entry = $vmEntry
        capture_end = $end
        expected_fields = $expected
        computed_fields = $computed
        initial_stream_pointer = Get-Field $vmEntry 'x'
        marker_order = '66A5 -> 66DB -> 66F3 -> 6715 -> 674C -> 677E -> 67B3 -> 3B1A -> 7CF6 -> 76C7 -> end'
    }
}

function Test-FailureLog([string]$Log) {
    $lines = @($Log -split "\r?\n")
    $failureIndex = Find-MarkerIndex $lines '^VARIANT_ROM_VERIFY_FAILED ' 0
    if ($failureIndex -lt 0) { throw 'Missing verifier failure marker' }
    for ($i = 0; $i -lt $failureIndex; $i++) {
        if ($lines[$i] -match '^VARIANT_(ROTATE_ADD|ROTATE_SUB_XOR|ROM_CHECK_RETURN|INIT_TAIL_JMP|INIT_TAIL_ENTRY|VM_CALL|VM_ENTRY)') {
            throw "Success marker before first failure: $($lines[$i])"
        }
    }
    $sumIndex = Find-MarkerIndexBackward $lines '^VARIANT_SUM_XOR ' ($failureIndex - 1)
    if ($sumIndex -lt 0) { throw 'Missing sum/xor result before failure' }
    $verifyIndex = Find-MarkerIndexBackward $lines '^VARIANT_ROM_VERIFY_ENTRY ' ($sumIndex - 1)
    if ($verifyIndex -lt 0) { throw 'Missing verifier entry before sum/xor result' }
    $checkIndex = Find-MarkerIndexBackward $lines '^VARIANT_ROM_CHECK_ENTRY ' ($verifyIndex - 1)
    if ($checkIndex -lt 0) { throw 'Missing check entry before verifier entry' }
    $endIndex = Find-MarkerIndex $lines '^VARIANT_CAPTURE_END pc=674F\b' ($failureIndex + 1)
    if ($endIndex -lt 0) { throw 'Missing capture end at the failure boundary' }
    for ($i = $endIndex + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^VARIANT_') { throw "Capture marker after VARIANT_CAPTURE_END: $($lines[$i])" }
    }

    $verify = $lines[$verifyIndex]
    $sum = $lines[$sumIndex]
    $failure = $lines[$failureIndex]
    $end = $lines[$endIndex]
    $expected = Get-Field $verify 'expected'
    $sumValue = Get-Field $sum 'sum'
    $xorValue = Get-Field $sum 'xor'
    $errorCode = Get-Field $failure 'error'
    $failed = @()
    if ($expected -ne $ExpectedOriginalFields) { $failed += "expected=$expected" }
    if ($sumValue -ne '40') { $failed += "sum=$sumValue" }
    if ($xorValue -ne '70') { $failed += "xor=$xorValue" }
    if ($errorCode -ne '12') { $failed += "error=$errorCode" }
    if ($failed.Count -gt 0) { throw ('Captured failure result differs: ' + ($failed -join ', ')) }

    return [ordered]@{
        outcome = 'failed'
        first_failure = $failure
        failure_pc = '674F'
        error_code = $errorCode
        check_entry = $lines[$checkIndex]
        verify_entry = $verify
        sum_xor = $sum
        capture_end = $end
        expected_fields = $expected
        computed_sum_xor = $sumValue + $xorValue
        marker_order = '66A5 -> 66DB -> 66F3 -> 674F -> end; no later-success marker'
    }
}

function Test-CaptureRun([string]$Run) {
    $paths = [ordered]@{
        log = Join-Path $Run 'debug.log'
        console = Join-Path $Run 'console.txt'
        provenance = Join-Path $Run 'provenance.json'
        observation = Join-Path $Run 'observation.json'
        exit = Join-Path $Run 'exit-code.txt'
        arguments = Join-Path $Run 'arguments.json'
        debugger = Join-Path $Run 'debugger.cmd'
        runRom = Join-Path $Run 'roms/m4addr/a6ls.p1'
    }
    foreach ($key in $paths.Keys) { if (!(Test-Path -LiteralPath $paths[$key])) { throw "Missing capture file: $($paths[$key])" } }

    $log = Get-Content -LiteralPath $paths.log -Raw
    $facts = if ($Variant -eq 'UnrepairedPatch') { Test-FailureLog $log } else { Test-SuccessLog $log $(if ($Variant -eq 'Original') { $ExpectedOriginalFields } else { $ExpectedRepairedFields }) }
    $provenance = Read-Json $paths.provenance
    $observation = Read-Json $paths.observation

    if ([string]$provenance.mode -ne 'Natural ROM integrity variant reset') { throw "Unsupported capture mode: $($provenance.mode)" }
    if ([string]$provenance.variant -ne $Variant) { throw "Provenance variant differs: $($provenance.variant)" }
    if ([string]$provenance.original_rom_sha1 -ine $OriginalSha1) { throw 'Provenance original ROMP SHA1 is not the accepted original' }
    if ([string]$provenance.expected_rom_sha1 -ine $ExpectedRomSha1) { throw 'Provenance expected ROM SHA1 differs' }
    if ([string]$provenance.expected_rom_sha256 -ine $ExpectedRomSha256) { throw 'Provenance expected ROM SHA256 differs' }
    if ([string]$provenance.run_rom_sha1 -ine $ExpectedRomSha1) { throw 'Provenance run-copy SHA1 differs' }
    if ([string]$provenance.run_rom_sha256 -ine $ExpectedRomSha256) { throw 'Provenance run-copy SHA256 differs' }
    if ([string]$provenance.starting_nvram -ne 'absent') { throw 'Unsupported starting NVRAM claim' }
    if ([string]$provenance.starting_configuration -notmatch '^absent;\s*-noreadconfig$') { throw 'Unsupported starting configuration claim' }
    if ([string]$provenance.user_inputs -ne 'none') { throw 'Unsupported user-input claim' }

    if ([string]$observation.variant -ne $Variant) { throw 'Observation variant differs' }
    if ([string]$observation.original_rom_sha1 -ine $OriginalSha1) { throw 'Observation original ROM SHA1 differs' }
    if ([string]$observation.expected_rom_sha1 -ine $ExpectedRomSha1 -or [string]$observation.expected_rom_sha256 -ine $ExpectedRomSha256) { throw 'Observation expected ROM identity differs' }
    if ([string]$observation.run_rom_sha1_after -ine $ExpectedRomSha1 -or [string]$observation.run_rom_sha256_after -ine $ExpectedRomSha256) { throw 'Observation run-copy identity differs' }
    if (-not ($observation.rom_unchanged -is [bool]) -or -not $observation.rom_unchanged) { throw 'Observation rom_unchanged is not boolean true' }
    if ($null -eq $observation.exit_code -or [int]$observation.exit_code -ne 0) { throw 'Observation exit_code is not 0' }
    $rawExit = (Get-Content -LiteralPath $paths.exit -Raw).Trim()
    if ($rawExit -ne '0') { throw "Capture exit-code.txt was $rawExit" }

    $actualFlags = if ($Variant -eq 'UnrepairedPatch') {
        [ordered]@{
            failure_reached = $true; checksum_returned = $false; init_tail_jmp_reached = $false
            init_tail_entry_reached = $false; vm_call_reached = $false; vm_entry_reached = $false
            stopped_at_failure = $true; stopped_at_vm_entry = $false
        }
    } else {
        [ordered]@{
            failure_reached = $false; checksum_returned = $true; init_tail_jmp_reached = $true
            init_tail_entry_reached = $true; vm_call_reached = $true; vm_entry_reached = $true
            stopped_at_failure = $false; stopped_at_vm_entry = $true
        }
    }
    foreach ($key in $actualFlags.Keys) {
        if (-not ($observation.PSObject.Properties.Name -contains $key)) { throw "Observation is missing $key" }
        if (-not ($observation.$key -is [bool])) { throw "Observation $key is not boolean" }
        if ($observation.$key -ne $actualFlags[$key]) { throw "Observation $key differs from the raw log" }
    }
    if ([string]$observation.expected_fields -ine $facts.expected_fields) { throw 'Observation expected_fields differs from the raw log' }
    if ($Variant -ne 'UnrepairedPatch') {
        if ([string]$observation.initial_stream_pointer -ine 'FDF0') { throw 'Observation initial_stream_pointer is not FDF0' }
    }

    $runRomLength = (Get-Item -LiteralPath $paths.runRom).Length
    if ($runRomLength -ne 65536) { throw "Isolated ROM copy length is $runRomLength" }
    if ((Get-HashHex $paths.runRom 'SHA1') -ine $ExpectedRomSha1) { throw 'Isolated ROM copy SHA1 differs' }
    if ((Get-HashHex $paths.runRom 'SHA256') -ine $ExpectedRomSha256) { throw 'Isolated ROM copy SHA256 differs' }
    $actualLogSha256 = Get-HashHex $paths.log 'SHA256'
    $actualConsoleSha256 = Get-HashHex $paths.console 'SHA256'
    if ([string]$observation.debug_log_sha256 -ine $actualLogSha256) { throw 'Observation debug_log_sha256 differs from the raw log' }
    if ([string]$observation.console_sha256 -ine $actualConsoleSha256) { throw 'Observation console_sha256 differs from the raw console' }

    $mameArgs = @((Get-Content -LiteralPath $paths.arguments -Raw | ConvertFrom-Json))
    foreach ($bad in @('-state','-playback','-autoboot_script','-autoboot_delay','-cheat','-nvram','-load')) {
        foreach ($arg in $mameArgs) {
            if ([string]$arg -ieq $bad -or [string]$arg -like "$bad=*") { throw "Unsupported state or injection argument: $arg" }
        }
    }
    if ($mameArgs -notcontains 'm4addr') { throw 'Arguments do not select m4addr' }
    if ($mameArgs -notcontains '-noreadconfig') { throw 'Arguments do not disable configuration reading' }
    foreach ($required in @('-debug','-debugger','-debugscript','-debuglog')) { if ($mameArgs -notcontains $required) { throw "Missing required argument: $required" } }
    if ([IO.Path]::GetFullPath((Get-ArgValue $mameArgs '-debugscript')) -ne [IO.Path]::GetFullPath($paths.debugger)) { throw 'Debugger script argument differs' }
    $firstRomPath = ((Get-ArgValue $mameArgs '-rompath') -split ';')[0]
    if ([IO.Path]::GetFullPath($firstRomPath) -ne [IO.Path]::GetFullPath((Join-Path $Run 'roms'))) { throw 'First ROM path is not the isolated run roms directory' }
    $runRoot = [IO.Path]::GetFullPath($Run).TrimEnd('\') + '\'
    foreach ($dirArg in @('-cfg_directory','-nvram_directory','-input_directory','-snapshot_directory','-comment_directory','-state_directory','-diff_directory')) {
        $dirFull = [IO.Path]::GetFullPath((Get-ArgValue $mameArgs $dirArg))
        if (!($dirFull.StartsWith($runRoot, [StringComparison]::OrdinalIgnoreCase))) { throw "Directory argument $dirArg is outside the isolated run directory" }
    }
    $inputDirectory = Get-ArgValue $mameArgs '-input_directory'
    if (Test-Path -LiteralPath $inputDirectory) {
        if (@(Get-ChildItem -LiteralPath $inputDirectory -Recurse -File -ErrorAction SilentlyContinue).Count -gt 0) { throw 'Input playback files are present' }
    }

    $bpsetAddresses = @()
    foreach ($line in (Get-Content -LiteralPath $paths.debugger)) {
        $trim = $line.Trim()
        if ($trim -eq '') { continue }
        if ($trim -match '^bpset\s+([0-9A-Fa-f]+),1,\{printf\s+"[^"]*"(,[^;]*)?(;go)?\}$') { $bpsetAddresses += $Matches[1].ToLowerInvariant(); continue }
        if ($trim -match '^printf\s+"[^"]*"(,[^;]*)?$') { continue }
        if ($trim -match '^go\s*$' -or $trim -eq 'quit') { continue }
        throw "Unsupported debugger command: $trim"
    }
    foreach ($address in $ExpectedBpsetAddresses) { if ($bpsetAddresses -notcontains $address) { throw "Missing expected breakpoint address: $address" } }

    return [ordered]@{
        run_directory = $Run
        facts = $facts
        provenance = $provenance
        observation = $observation
        actual_log_sha256 = $actualLogSha256
        actual_console_sha256 = $actualConsoleSha256
        actual_run_rom_sha1 = $ExpectedRomSha1
        actual_run_rom_sha256 = $ExpectedRomSha256
        run_rom_length = $runRomLength
        debug_log = $log
    }
}

function Update-ObservationLogHash([string]$Run) {
    $path = Join-Path $Run 'observation.json'
    $observation = Read-Json $path
    $observation.debug_log_sha256 = Get-HashHex (Join-Path $Run 'debug.log') 'SHA256'
    $observation | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path
}

function Copy-RunForTamper([string]$Source, [string]$Destination) {
    New-Item -ItemType Directory -Path $Destination | Out-Null
    Copy-Item -Path (Join-Path $Source '*') -Destination $Destination -Recurse
    $argumentsPath = Join-Path $Destination 'arguments.json'
    $arguments = @((Get-Content -LiteralPath $argumentsPath -Raw | ConvertFrom-Json) | ForEach-Object { if ($_ -is [string]) { $_.Replace($Source, $Destination) } else { $_ } })
    ConvertTo-Json -InputObject $arguments | Set-Content -LiteralPath $argumentsPath
}

function Test-NegativeControl([string]$Name, [string]$Run, [string]$Pattern) {
    try { Test-CaptureRun $Run | Out-Null; throw "Negative control '$Name' was not rejected" }
    catch {
        $message = $_.Exception.Message
        if ($message -eq "Negative control '$Name' was not rejected") { throw }
        if ($message -notmatch $Pattern) { throw "Negative control '$Name' was rejected with unexpected message: $message" }
        Write-Output ("Negative control rejected {0}: {1}" -f $Name, $message)
    }
}

$run = [IO.Path]::GetFullPath($RunDirectory)
$capture = Test-CaptureRun $run

if ($NegativeControl) {
    $tamperRoot = Join-Path ([IO.Path]::GetTempPath()) ('fm-general07-curate-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tamperRoot | Out-Null
    try {
        $tampered = Join-Path $tamperRoot 'identity'
        Copy-RunForTamper $run $tampered
        $provenance = Read-Json (Join-Path $tampered 'provenance.json')
        $provenance.expected_rom_sha1 = ('0' * 40)
        $provenance | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $tampered 'provenance.json')
        Test-NegativeControl 'tampered variant identity' $tampered 'expected ROM SHA1'

        $tampered = Join-Path $tamperRoot 'rom'
        Copy-RunForTamper $run $tampered
        $runRomPath = Join-Path $tampered 'roms/m4addr/a6ls.p1'
        $bytes = [IO.File]::ReadAllBytes($runRomPath)
        $bytes[0] = $bytes[0] -bxor 0xFF
        [IO.File]::WriteAllBytes($runRomPath, $bytes)
        Test-NegativeControl 'changed isolated ROM copy' $tampered 'Isolated ROM copy'

        $tampered = Join-Path $tamperRoot 'loghash'
        Copy-RunForTamper $run $tampered
        $observation = Read-Json (Join-Path $tampered 'observation.json')
        $observation.debug_log_sha256 = ('0' * 64)
        $observation | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $tampered 'observation.json')
        Test-NegativeControl 'tampered log hash' $tampered 'debug_log_sha256'

        $tampered = Join-Path $tamperRoot 'injection'
        Copy-RunForTamper $run $tampered
        Add-Content -LiteralPath (Join-Path $tampered 'debugger.cmd') -Value 'set pc=76c7'
        Test-NegativeControl 'debugger state injection' $tampered 'Unsupported debugger'

        $tampered = Join-Path $tamperRoot 'outcome'
        Copy-RunForTamper $run $tampered
        $observation = Read-Json (Join-Path $tampered 'observation.json')
        if ($Variant -eq 'UnrepairedPatch') { $observation.failure_reached = $false } else { $observation.failure_reached = $true }
        $observation | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $tampered 'observation.json')
        Test-NegativeControl 'altered outcome flag' $tampered 'differs from the raw log'
    }
    finally { Remove-Item -LiteralPath $tamperRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

$facts = $capture.facts
$provenance = $capture.provenance
$observation = $capture.observation
$result = [ordered]@{
    schema_version = 1
    classification = 'Natural MAME 0.281 reset observation of one identity-checked ROM variant. The original checker code, gate, ranges and disabled records are unchanged; the unrepaired and repaired variants differ only in the shared award byte and the five active expected fields.'
    variant = $Variant
    rom = [ordered]@{
        name = 'a6ls.p1'
        length = $capture.run_rom_length
        sha1 = $capture.actual_run_rom_sha1
        sha256 = $capture.actual_run_rom_sha256
        original_sha1 = $OriginalSha1
        run_copy_sha1_after = $observation.run_rom_sha1_after
        run_copy_sha256_after = $observation.run_rom_sha256_after
        unchanged = $true
    }
    starting_contract = [ordered]@{
        mode = $provenance.mode
        declared_starting_nvram = $provenance.starting_nvram
        declared_starting_configuration = $provenance.starting_configuration
        declared_user_inputs = $provenance.user_inputs
        configuration_read_disabled = $true
        isolated_rom_copy = ('verified: length 65536; SHA1 {0}; SHA256 {1}' -f $capture.actual_run_rom_sha1, $capture.actual_run_rom_sha256)
        user_inputs = 'none; no input playback files and no playback argument'
        pc_ram_input_or_rom_injection = 'none; debugger script contains only bpset/printf/go/quit and arguments contain no state load, playback, autoboot or cheat option'
        mame_sha256 = $provenance.mame_sha256
        mame_exit_code = [int]$observation.exit_code
        debug_log_sha256 = $capture.actual_log_sha256
        console_sha256 = $capture.actual_console_sha256
        debug_log_sha256_source = 'recomputed from raw debug.log'
        console_sha256_source = 'recomputed from raw console.txt'
    }
    observed = $facts
    verification = [ordered]@{
        original_rom_identity = $true
        variant_identity_sha1_sha256 = $true
        run_copy_identity = $true
        isolated_rom_copy_length = $capture.run_rom_length
        exit_code_consistent = $true
        debug_log_hash_matches_observation = $true
        console_hash_matches_observation = $true
        observation_booleans_match_log = $true
        marker_order_enforced = $true
        required_breakpoint_addresses = $ExpectedBpsetAddresses
        injection_claim_supported = $true
        starting_nvram_verification = 'declared by capture provenance; pre-run emptiness is not reconstructable from the post-run directory'
        checker_code_gate_ranges_disabled_records = 'unchanged from the original image; only the shared award byte and active expected fields differ'
    }
    provenance = [ordered]@{
        capture_script = 'tools/Capture-RomIntegrityVariant.ps1'
        curator_script = 'tools/Curate-RomIntegrityVariant.ps1'
        raw_run_directory = $(if ($run.StartsWith((Get-Location).Path, [StringComparison]::OrdinalIgnoreCase)) { $run.Substring((Get-Location).Path.Length).TrimStart('\','/').Replace('\','/') } else { $run.Replace('\','/') })
        original_oracle = 'evidence/mpu4/integrity/original-startup-vm-entry.json'
        static_evidence = @('evidence/mpu4/maps/rom-integrity.json','evidence/mpu4/native/66a5.json','evidence/mpu4/native/66db.json')
    }
    limitations = @(
        'This is one natural cold reset observation per variant in MAME 0.281, stopping at the first failure or the first 76C7 entry.',
        'The unrepaired variant is expected to fail the original sum/xor check first; the first-failure line records the actual observed result.',
        'The repaired variant passes the original checker and reaches the same VM entry/stream pointer, but later token dispatch, gameplay, randomness, timing equivalence and physical hardware are not claimed.',
        'MAME loader hash warnings for modified images remain expected and are not firmware-integrity repair.',
        'Starting NVRAM/configuration absence remains a capture declaration; configuration reading is verifiably disabled.',
        'Negative controls are synthetic tampering of copied raw artifacts, not natural execution evidence.'
    )
}
$out = [IO.Path]::GetFullPath($OutputPath)
$outDir = [IO.Path]::GetDirectoryName($out)
if (!(Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $out
$compactLog = [IO.Path]::ChangeExtension($out, '.txt')
$lines = @($capture.debug_log -split "`r?`n" | Where-Object { $_ -match '^(VARIANT_|MAME debugger|Currently targeting|>bpset|>go|>quit|Stopped|Breakpoint|Cleared)' })
$lines | Set-Content -LiteralPath $compactLog
Write-Output "Curated $out"
Write-Output "Curated $compactLog"

param(
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [switch]$NegativeControl
)
$ErrorActionPreference = 'Stop'

$ExpectedRomSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$ExpectedRomLength = 65536
$ExpectedBpsetAddresses = @('7cd1','6750','66a5','66db','66f3','6715','674c','674d','677e')

function Get-HashHex([string]$Path, [string]$Algorithm) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        try { return [BitConverter]::ToString($hash.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Read-Json([string]$Path) {
    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function Get-Field([string]$Line, [string]$Name) {
    $m = [regex]::Match($Line, ('\b' + [regex]::Escape($Name) + '=([0-9A-Fa-f]+)'))
    if (!$m.Success) { throw "Missing field $Name in: $Line" }
    return $m.Groups[1].Value.ToUpperInvariant()
}

function Find-MarkerIndex([string[]]$Lines, [string]$Pattern, [int]$Start = 0) {
    for ($i = $Start; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match $Pattern) { return $i }
    }
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

function Test-CaptureLog([string]$Log) {
    $lines = @($Log -split "\r?\n")
    if ($Log -match '(?m)^BOOT_ROM_VERIFY_FAILED ') { throw 'Verifier failure marker is present' }

    $resetCount = @($lines | Where-Object { $_ -match '^BOOT_RESET pc=7CD1\b' }).Count
    $initCount = @($lines | Where-Object { $_ -match '^BOOT_INIT_ENTRY pc=6750\b' }).Count
    if ($resetCount -eq 0) { throw 'Missing reset marker pc=7CD1' }
    if ($initCount -eq 0) { throw 'Missing init marker pc=6750' }

    $ordered = [ordered]@{}
    $specs = @(
        @{ Key = 'check'; Pattern = '^BOOT_ROM_CHECK_ENTRY pc=66A5\b' },
        @{ Key = 'verify'; Pattern = '^BOOT_ROM_VERIFY_ENTRY pc=66DB\b' },
        @{ Key = 'sum'; Pattern = '^BOOT_SUM_XOR ' },
        @{ Key = 'rotate_add'; Pattern = '^BOOT_ROTATE_ADD ' },
        @{ Key = 'rotate_sub'; Pattern = '^BOOT_ROTATE_SUB_XOR ' },
        @{ Key = 'return'; Pattern = '^BOOT_ROM_CHECK_RETURN pc=677E\b' },
        @{ Key = 'end'; Pattern = '^BOOT_CAPTURE_END pc=677E\b' }
    )
    $start = 0
    foreach ($spec in $specs) {
        $index = Find-MarkerIndex $lines $spec.Pattern $start
        if ($index -lt 0) {
            throw ('Chronological checksum marker missing or out of order: ' + $spec.Key)
        }
        $ordered[$spec.Key] = [ordered]@{ index = $index; line = $lines[$index] }
        $start = $index + 1
    }

    $checkIndex = $ordered['check'].index
    $resetIndex = Find-MarkerIndex $lines '^BOOT_RESET pc=7CD1\b' 0
    $initIndex = Find-MarkerIndex $lines '^BOOT_INIT_ENTRY pc=6750\b' 0
    if ($resetIndex -ge $checkIndex -or $initIndex -ge $checkIndex) {
        throw 'Reset/init markers do not precede the checksum entry'
    }
    for ($i = $ordered['end'].index + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^BOOT_') { throw "Capture marker after BOOT_CAPTURE_END: $($lines[$i])" }
    }

    $check = $ordered['check'].line
    $verify = $ordered['verify'].line
    $sum = $ordered['sum'].line
    $rotateAdd = $ordered['rotate_add'].line
    $rotateSubXor = $ordered['rotate_sub'].line
    $checkReturn = $ordered['return'].line
    $end = $ordered['end'].line

    $gate = Get-Field $check 'gate719b'
    $expected = Get-Field $verify 'expected'
    $startAddr = Get-Field $verify 'start'
    $endAddr = Get-Field $verify 'end'
    $errorCode = Get-Field $verify 'error'
    $sumValue = Get-Field $sum 'sum'
    $xorValue = Get-Field $sum 'xor'
    $rotateAddValue = Get-Field $rotateAdd 'value'
    $rotateSubA = Get-Field $rotateSubXor 'a'
    $rotateSubB = Get-Field $rotateSubXor 'b'

    $failed = @()
    if ($gate -ne '00') { $failed += "gate719b=$gate" }
    if ($expected -ne '3E761E2605') { $failed += "expected=$expected" }
    if ($startAddr -ne '1400') { $failed += "start=$startAddr" }
    if ($endAddr -ne 'FFFF') { $failed += "end=$endAddr" }
    if ($errorCode -ne '12') { $failed += "error=$errorCode" }
    if ($sumValue -ne '3E') { $failed += "sum=$sumValue" }
    if ($xorValue -ne '76') { $failed += "xor=$xorValue" }
    if ($rotateAddValue -ne '1E') { $failed += "rotate_add=$rotateAddValue" }
    if ($rotateSubA -ne '26') { $failed += "rotate_sub_a=$rotateSubA" }
    if ($rotateSubB -ne '05') { $failed += "rotate_sub_b=$rotateSubB" }
    if ($failed.Count -gt 0) { throw ('Captured checksum result differs: ' + ($failed -join ', ')) }

    return [ordered]@{
        reset = $lines[$resetIndex]
        init = $lines[$initIndex]
        reset_count = $resetCount
        init_count = $initCount
        check_entry = $check
        verify_entry = $verify
        sum_xor = $sum
        rotate_add = $rotateAdd
        rotate_sub_xor = $rotateSubXor
        checksum_return = $checkReturn
        next_startup_boundary = $end
        order = '66A5 -> 66DB -> 66F3 -> 6715 -> 674C -> 677E -> end'
    }
}

function Test-CaptureRun([string]$Run) {
    $logPath = Join-Path $Run 'debug.log'
    $consolePath = Join-Path $Run 'console.txt'
    $provenancePath = Join-Path $Run 'provenance.json'
    $observationPath = Join-Path $Run 'observation.json'
    $exitPath = Join-Path $Run 'exit-code.txt'
    $argumentsPath = Join-Path $Run 'arguments.json'
    $debuggerPath = Join-Path $Run 'debugger.cmd'
    $runRomPath = Join-Path $Run 'roms/m4addr/a6ls.p1'
    foreach ($path in @($logPath, $consolePath, $provenancePath, $observationPath, $exitPath, $argumentsPath, $debuggerPath)) {
        if (!(Test-Path -LiteralPath $path)) { throw "Missing capture file: $path" }
    }

    $log = Get-Content -LiteralPath $logPath -Raw
    $facts = Test-CaptureLog $log
    $provenance = Read-Json $provenancePath
    $observation = Read-Json $observationPath

    if ([string]$provenance.original_rom_sha1 -ine $ExpectedRomSha1) {
        throw "Original ROM identity in provenance is not $ExpectedRomSha1"
    }
    if ([string]$provenance.run_rom_sha1 -ine $ExpectedRomSha1) {
        throw "Run-copy ROM identity in provenance is not $ExpectedRomSha1"
    }
    if ([string]$provenance.mode -ne 'Natural original reset boot') {
        throw "Unsupported capture mode: $($provenance.mode)"
    }
    if ([string]$provenance.starting_nvram -ne 'absent') {
        throw "Unsupported starting NVRAM claim: $($provenance.starting_nvram)"
    }
    if ([string]$provenance.starting_configuration -notmatch '^absent;\s*-noreadconfig$') {
        throw "Unsupported starting configuration claim: $($provenance.starting_configuration)"
    }
    if ([string]$provenance.user_inputs -ne 'none') {
        throw "Unsupported user-input claim: $($provenance.user_inputs)"
    }

    if ([string]$observation.original_rom_sha1 -ine $ExpectedRomSha1) {
        throw "Original ROM identity in observation is not $ExpectedRomSha1"
    }
    if ([string]$observation.run_rom_sha1_after -ine $ExpectedRomSha1) {
        throw "Run-copy ROM identity in observation is not $ExpectedRomSha1"
    }
    if (-not ($observation.rom_unchanged -is [bool]) -or -not $observation.rom_unchanged) {
        throw 'Observation rom_unchanged is not boolean true'
    }
    if ($null -eq $observation.exit_code -or [int]$observation.exit_code -ne 0) {
        throw "Observation exit_code is not 0: $($observation.exit_code)"
    }
    $rawExit = (Get-Content -LiteralPath $exitPath -Raw).Trim()
    if ($rawExit -ne '0') { throw "Capture exit-code.txt was $rawExit" }
    if ([int]$rawExit -ne [int]$observation.exit_code) { throw 'Observation exit_code differs from exit-code.txt' }

    $actualFlags = [ordered]@{
        reset_reached = ($facts.reset_count -gt 0)
        init_reached = ($facts.init_count -gt 0)
        rom_check_reached = $true
        rom_verify_reached = $true
        rom_check_returned = $true
        stopped_at_checksum_return = $true
        verify_failed = $false
    }
    foreach ($key in $actualFlags.Keys) {
        if (-not ($observation.PSObject.Properties.Name -contains $key)) { throw "Observation is missing $key" }
        $recorded = $observation.$key
        if (-not ($recorded -is [bool])) { throw "Observation $key is not boolean" }
        if ($recorded -ne $actualFlags[$key]) { throw "Observation $key differs from the raw log" }
    }

    if (!(Test-Path -LiteralPath $runRomPath)) { throw "Missing isolated ROM copy: $runRomPath" }
    $runRomLength = (Get-Item -LiteralPath $runRomPath).Length
    if ($runRomLength -ne $ExpectedRomLength) { throw "Isolated ROM copy length is $runRomLength, not $ExpectedRomLength" }
    $actualRunRomSha1 = Get-HashHex $runRomPath 'SHA1'
    if ($actualRunRomSha1 -ine $ExpectedRomSha1) { throw "Isolated ROM copy SHA1 is $actualRunRomSha1" }

    $actualLogSha256 = Get-HashHex $logPath 'SHA256'
    $actualConsoleSha256 = Get-HashHex $consolePath 'SHA256'
    if (!($observation.debug_log_sha256 -is [string]) -or $observation.debug_log_sha256.ToLowerInvariant() -ne $actualLogSha256) {
        throw 'Observation debug_log_sha256 does not match the raw debug.log'
    }
    if (!($observation.console_sha256 -is [string]) -or $observation.console_sha256.ToLowerInvariant() -ne $actualConsoleSha256) {
        throw 'Observation console_sha256 does not match the raw console.txt'
    }

    $mameArgs = @((Get-Content -LiteralPath $argumentsPath -Raw | ConvertFrom-Json))
    $forbidden = @('-state','-playback','-autoboot_script','-autoboot_delay','-cheat','-nvram','-load')
    foreach ($arg in $mameArgs) {
        foreach ($bad in $forbidden) {
            if ([string]$arg -ieq $bad -or [string]$arg -like "$bad=*") {
                throw "Unsupported state or injection argument: $arg"
            }
        }
    }
    if ($mameArgs -notcontains 'm4addr') { throw 'Arguments do not select m4addr' }
    if ($mameArgs -notcontains '-noreadconfig') { throw 'Arguments do not disable configuration reading' }
    foreach ($required in @('-debug','-debugger','-debugscript','-debuglog')) {
        if ($mameArgs -notcontains $required) { throw "Missing required argument: $required" }
    }
    $debugScript = Get-ArgValue $mameArgs '-debugscript'
    if ([IO.Path]::GetFullPath($debugScript) -ne [IO.Path]::GetFullPath($debuggerPath)) {
        throw 'Debugger script argument does not point at the captured debugger.cmd'
    }
    $romPath = Get-ArgValue $mameArgs '-rompath'
    $firstRomPath = ($romPath -split ';')[0]
    if ([IO.Path]::GetFullPath($firstRomPath) -ne [IO.Path]::GetFullPath((Join-Path $Run 'roms'))) {
        throw 'First ROM path is not the isolated run roms directory'
    }
    $inputDirectory = Get-ArgValue $mameArgs '-input_directory'
    if (Test-Path -LiteralPath $inputDirectory) {
        $inputFiles = @(Get-ChildItem -LiteralPath $inputDirectory -Recurse -File -ErrorAction SilentlyContinue)
        if ($inputFiles.Count -gt 0) { throw "Input playback files are present: $($inputFiles.Count)" }
    }

    $bpsetAddresses = @()
    foreach ($line in (Get-Content -LiteralPath $debuggerPath)) {
        $trim = $line.Trim()
        if ($trim -eq '') { continue }
        if ($trim -match '^bpset\s+([0-9A-Fa-f]+),1,\{printf\s+"[^"]*"(,[^;]*)?(;go)?\}$') {
            $bpsetAddresses += $Matches[1].ToLowerInvariant()
            continue
        }
        if ($trim -match '^printf\s+"[^"]*"(,[^;]*)?$') { continue }
        if ($trim -match '^go\s*$' -or $trim -eq 'quit') { continue }
        throw "Unsupported debugger command: $trim"
    }
    foreach ($address in $ExpectedBpsetAddresses) {
        if ($bpsetAddresses -notcontains $address) { throw "Missing expected breakpoint address: $address" }
    }

    return [ordered]@{
        run_directory = $Run
        facts = $facts
        provenance = $provenance
        observation = $observation
        mame_args = $mameArgs
        bpset_addresses = $bpsetAddresses
        actual_log_sha256 = $actualLogSha256
        actual_console_sha256 = $actualConsoleSha256
        actual_run_rom_sha1 = $actualRunRomSha1
        run_rom_length = $runRomLength
        debug_log = $log
    }
}

function Update-ObservationLogHash([string]$Run) {
    $observationPath = Join-Path $Run 'observation.json'
    $observation = Read-Json $observationPath
    $observation.debug_log_sha256 = Get-HashHex (Join-Path $Run 'debug.log') 'SHA256'
    $observation | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $observationPath
}

function Copy-RunForTamper([string]$Source, [string]$Destination) {
    New-Item -ItemType Directory -Path $Destination | Out-Null
    Copy-Item -Path (Join-Path $Source '*') -Destination $Destination -Recurse
    $argumentsPath = Join-Path $Destination 'arguments.json'
    $arguments = @((Get-Content -LiteralPath $argumentsPath -Raw | ConvertFrom-Json) | ForEach-Object {
        if ($_ -is [string]) { $_.Replace($Source, $Destination) } else { $_ }
    })
    ConvertTo-Json -InputObject $arguments | Set-Content -LiteralPath $argumentsPath
}

function Test-NegativeControl([string]$Name, [string]$Run, [string]$ExpectedPattern) {
    try {
        Test-CaptureRun $Run | Out-Null
        throw "Negative control '$Name' was not rejected"
    }
    catch {
        $message = $_.Exception.Message
        if ($message -eq "Negative control '$Name' was not rejected") { throw }
        if ($message -notmatch $ExpectedPattern) {
            throw "Negative control '$Name' was rejected with unexpected message: $message"
        }
        Write-Output ("Negative control rejected {0}: {1}" -f $Name, $message)
    }
}

$run = [IO.Path]::GetFullPath($RunDirectory)
$capture = Test-CaptureRun $run

if ($NegativeControl) {
    $tamperRoot = Join-Path ([IO.Path]::GetTempPath()) ('fm-review05-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tamperRoot | Out-Null
    try {
        $tamperedRun = Join-Path $tamperRoot 'sum'
        Copy-RunForTamper $run $tamperedRun
        $logPath = Join-Path $tamperedRun 'debug.log'
        $log = Get-Content -LiteralPath $logPath -Raw
        $changed = $log.Replace('BOOT_SUM_XOR sum=3E xor=76', 'BOOT_SUM_XOR sum=3F xor=76')
        if ($changed -eq $log) { throw 'Sum negative control did not alter the log' }
        [IO.File]::WriteAllText($logPath, $changed)
        Update-ObservationLogHash $tamperedRun
        Test-NegativeControl 'altered sum' $tamperedRun 'sum='

        $tamperedRun = Join-Path $tamperRoot 'order'
        Copy-RunForTamper $run $tamperedRun
        $logPath = Join-Path $tamperedRun 'debug.log'
        $log = Get-Content -LiteralPath $logPath -Raw
        $verifyLine = ([regex]::Match($log, '(?m)^BOOT_ROM_VERIFY_ENTRY .*$')).Value
        $endLine = ([regex]::Match($log, '(?m)^BOOT_CAPTURE_END .*$')).Value
        if (!$verifyLine -or !$endLine) { throw 'Order negative control could not find markers' }
        $changed = [regex]::Replace($log, '(?m)^BOOT_ROM_VERIFY_ENTRY[^\r\n]*\r?\n', '')
        $changed = $changed.Replace($endLine, $verifyLine + "`r`n" + $endLine)
        [IO.File]::WriteAllText($logPath, $changed)
        Update-ObservationLogHash $tamperedRun
        Test-NegativeControl 'checksum marker order' $tamperedRun 'Chronological checksum marker'

        $tamperedRun = Join-Path $tamperRoot 'provenance'
        Copy-RunForTamper $run $tamperedRun
        $provenancePath = Join-Path $tamperedRun 'provenance.json'
        $provenance = Read-Json $provenancePath
        $provenance.original_rom_sha1 = ('0' * 40)
        $provenance | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $provenancePath
        Test-NegativeControl 'tampered provenance identity' $tamperedRun 'Original ROM identity in provenance'

        $tamperedRun = Join-Path $tamperRoot 'startcontract'
        Copy-RunForTamper $run $tamperedRun
        $provenancePath = Join-Path $tamperedRun 'provenance.json'
        $provenance = Read-Json $provenancePath
        $provenance.starting_nvram = 'present'
        $provenance | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $provenancePath
        Test-NegativeControl 'unsupported starting NVRAM claim' $tamperedRun 'Unsupported starting NVRAM claim'

        $tamperedRun = Join-Path $tamperRoot 'romflag'
        Copy-RunForTamper $run $tamperedRun
        $observationPath = Join-Path $tamperedRun 'observation.json'
        $observation = Read-Json $observationPath
        $observation.rom_unchanged = $false
        $observation | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $observationPath
        Test-NegativeControl 'false rom_unchanged flag' $tamperedRun 'rom_unchanged'

        $tamperedRun = Join-Path $tamperRoot 'loghash'
        Copy-RunForTamper $run $tamperedRun
        $observationPath = Join-Path $tamperedRun 'observation.json'
        $observation = Read-Json $observationPath
        $observation.debug_log_sha256 = ('0' * 64)
        $observation | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $observationPath
        Test-NegativeControl 'tampered log hash' $tamperedRun 'debug_log_sha256'

        $tamperedRun = Join-Path $tamperRoot 'romchanged'
        Copy-RunForTamper $run $tamperedRun
        $runRomPath = Join-Path $tamperedRun 'roms/m4addr/a6ls.p1'
        $bytes = [IO.File]::ReadAllBytes($runRomPath)
        $bytes[0] = $bytes[0] -bxor 0xFF
        [IO.File]::WriteAllBytes($runRomPath, $bytes)
        Test-NegativeControl 'changed isolated ROM copy' $tamperedRun 'Isolated ROM copy SHA1'

        $tamperedRun = Join-Path $tamperRoot 'romlength'
        Copy-RunForTamper $run $tamperedRun
        $runRomPath = Join-Path $tamperedRun 'roms/m4addr/a6ls.p1'
        $bytes = [IO.File]::ReadAllBytes($runRomPath)
        [IO.File]::WriteAllBytes($runRomPath, $bytes[0..($bytes.Length - 2)])
        Test-NegativeControl 'truncated isolated ROM copy' $tamperedRun 'Isolated ROM copy length'

        $tamperedRun = Join-Path $tamperRoot 'exit'
        Copy-RunForTamper $run $tamperedRun
        Set-Content -LiteralPath (Join-Path $tamperedRun 'exit-code.txt') -Value '1' -NoNewline
        Test-NegativeControl 'nonzero capture exit' $tamperedRun 'exit-code.txt'

        $tamperedRun = Join-Path $tamperRoot 'injection'
        Copy-RunForTamper $run $tamperedRun
        Add-Content -LiteralPath (Join-Path $tamperedRun 'debugger.cmd') -Value 'set pc=677e'
        Test-NegativeControl 'debugger state injection' $tamperedRun 'Unsupported debugger'
    }
    finally {
        Remove-Item -LiteralPath $tamperRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$facts = $capture.facts
$provenance = $capture.provenance
$observation = $capture.observation
$exitCode = [int]$observation.exit_code

$result = [ordered]@{
    schema_version = 2
    classification = 'Natural original-ROM MAME reset boot observation. Executable threshold and checksum outcomes are observed; intent and gameplay are not claimed.'
    rom = [ordered]@{
        name = 'a6ls.p1'
        length = $capture.run_rom_length
        expected_length = $ExpectedRomLength
        sha1 = $ExpectedRomSha1
        run_copy_sha1_after = $capture.actual_run_rom_sha1
        unchanged = $true
    }
    starting_contract = [ordered]@{
        mode = $provenance.mode
        declared_starting_nvram = $provenance.starting_nvram
        declared_starting_configuration = $provenance.starting_configuration
        declared_user_inputs = $provenance.user_inputs
        configuration_read_disabled = $true
        isolated_rom_copy = 'verified: length 65536; SHA1 402d1518bb78fdc489b06c2aabc771e5ce151847'
        user_inputs = 'none; no input playback files and no playback argument'
        pc_ram_input_or_rom_injection = 'none; debugger script contains only bpset/printf/go/quit and arguments contain no state load, playback, autoboot or cheat option'
        mame_sha256 = $provenance.mame_sha256
        mame_exit_code = $exitCode
        debug_log_sha256 = $capture.actual_log_sha256
        console_sha256 = $capture.actual_console_sha256
        debug_log_sha256_source = 'recomputed from raw debug.log'
        console_sha256_source = 'recomputed from raw console.txt'
    }
    observed = [ordered]@{
        reset_entry = $facts.reset
        init_entry = $facts.init
        reset_entries = $facts.reset_count
        init_entries = $facts.init_count
        checksum_entry = $facts.check_entry
        verifier_entry = $facts.verify_entry
        sum_xor = $facts.sum_xor
        rotate_add = $facts.rotate_add
        rotate_sub_xor = $facts.rotate_sub_xor
        checksum_return = $facts.checksum_return
        next_startup_boundary = $facts.next_startup_boundary
        checksum_marker_order = $facts.order
    }
    verification = [ordered]@{
        original_rom_identity = $true
        run_copy_identity = $true
        isolated_rom_copy_length = $capture.run_rom_length
        exit_code_consistent = $true
        debug_log_hash_matches_observation = $true
        console_hash_matches_observation = $true
        observation_booleans_match_log = $true
        checksum_marker_order_enforced = $true
        required_breakpoint_addresses = $ExpectedBpsetAddresses
        injection_claim_supported = $true
        starting_nvram_verification = 'declared by capture provenance; pre-run emptiness is not reconstructable from the post-run directory'
        reset_marker_present = $true
        init_marker_present = $true
        verifier_entered = $true
        verifier_failure_marker_absent = $true
        returned_to_caller_677e = $true
        stopped_at_next_startup_boundary = $true
        active_record = [ordered]@{
            gate_719b = '00'
            expected_hex = '3E761E2605'
            start = '1400'
            end = 'FFFF'
            error_code = '12'
        }
        computed = [ordered]@{
            sum = '3E'
            xor = '76'
            rotate_add = '1E'
            rotate_sub_xor_a = '26'
            rotate_sub_xor_b = '05'
        }
        matches_static_expectation = $true
    }
    provenance = [ordered]@{
        capture_script = 'tools/Capture-RomIntegrityBoot.ps1'
        curator_script = 'tools/Curate-RomIntegrityBoot.ps1'
        raw_run_directory = $(if ($run.StartsWith((Get-Location).Path, [StringComparison]::OrdinalIgnoreCase)) { $run.Substring((Get-Location).Path.Length).TrimStart('\','/').Replace('\','/') } else { $run.Replace('\','/') })
        static_evidence = @(
            'evidence/mpu4/maps/rom-integrity.json',
            'evidence/mpu4/native/66a5.json',
            'evidence/mpu4/native/66db.json'
        )
    }
    limitations = @(
        'This observes one natural cold reset with the original image and declared-absent NVRAM in MAME 0.281.',
        'The post-run directory cannot independently prove that NVRAM and configuration were absent before MAME started; those two entries remain capture declarations. Configuration reading is verifiably disabled with -noreadconfig.',
        'The injection claim is limited to the captured debugger script and arguments: no state load, playback, autoboot, cheat, memory/PC write or ROM replacement command is present.',
        'It does not prove physical hardware behaviour, modified-ROM behaviour, gameplay, randomness or timing equivalence.',
        'Only the active gate-00 record at FFD1 is exercised; disabled records remain unexercised.',
        'No ROM repair, re-signing, bypass or patch was performed.',
        'Negative controls are synthetic tampering of copied raw artifacts, not natural execution evidence.'
    )
}

$out = [IO.Path]::GetFullPath($OutputPath)
$outDir = Split-Path -Parent $out
if (!(Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $out

$compactLog = Join-Path $outDir 'original-reset-boot.log'
$lines = @($capture.debug_log -split "`r?`n" | Where-Object { $_ -match '^(BOOT_|MAME debugger|Currently targeting|>bpset|>goto|>gtime|>quit|Stopped|Breakpoint|Cleared)' })
$lines | Set-Content -LiteralPath $compactLog

Write-Output "Curated $out"
Write-Output "Curated $compactLog"

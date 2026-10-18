[CmdletBinding()]
param(
    [string]$RunDirectory,
    [string]$OutputPath,
    [ValidateSet('Original','Repaired')][string]$Variant,
    [string]$OriginalRom,
    [string]$SourceMapPath,
    [string]$BuildReportPath,
    [string]$ControlRunDirectory,
    [string]$ChangedRunDirectory,
    [switch]$NegativeControl
)
$ErrorActionPreference = 'Stop'

$script:IlCurationOriginalLength = 65536
$script:IlCurationOriginalSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$script:IlCurationOriginalSha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
$script:IlCurationMameSha256 = '0fce5a88df4f9d9b1fbf1405812c00848036e615993780978d967da34204cb7a'
$script:IlCurationVariants = @{
    Original = @{
        Sha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
        Sha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
        Fields = '3E761E2605'
        ChangedOffsets = @()
    }
    Repaired = @{
        Sha1 = 'e1a42dccd304b7b175aabac99e8400cdad04cf69'
        Sha256 = '577f76bd36dfca04dfb01b5f5d0be93e16572f8617c7ca906397c98df36e5107'
        Fields = 'BEF69E7CC7'
        ChangedOffsets = @(0x9EDC, 0xFFD1, 0xFFD2, 0xFFD3, 0xFFD4, 0xFFD5)
    }
}
$script:IlCurationRequiredBreakpoints = @('7cd1','6750','66a5','66db','66f3','6715','674c','674f','677e','67b3','3b1a','7cf6','76c7')

function Get-IlCurationHashHex {
    param([string]$Path, [string]$Algorithm)
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        try { return ([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Read-IlCurationJson {
    param([string]$Path)
    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function Get-IlCurationField {
    param([string]$Line, [string]$Name)
    $m = [regex]::Match($Line, ('\b' + [regex]::Escape($Name) + '=([0-9A-Fa-f]+)'))
    if (!$m.Success) { throw "Missing field $Name in line: $Line" }
    return $m.Groups[1].Value.ToUpperInvariant()
}

function Find-IlCurationMarkerIndex {
    param([string[]]$Lines, [string]$Pattern, [int]$Start = 0)
    for ($i = $Start; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match $Pattern) { return $i }
    }
    return -1
}

function Find-IlCurationMarkerIndexBackward {
    param([string[]]$Lines, [string]$Pattern, [int]$Start)
    for ($i = $Start; $i -ge 0; $i--) {
        if ($Lines[$i] -match $Pattern) { return $i }
    }
    return -1
}

function Format-IlCurationOffset {
    param([int]$Offset)
    return ('{0:X4}' -f $Offset)
}

function Format-IlCurationOffsets {
    param([int[]]$Offsets)
    return (($Offsets | ForEach-Object { Format-IlCurationOffset $_ }) -join ',')
}

function Get-IlCurationChangedOffsets {
    param([byte[]]$Original, [byte[]]$Variant)
    if ($Original.Length -ne $Variant.Length) { throw 'Cannot compare ROM images of different lengths' }
    $offsets = New-Object 'System.Collections.Generic.List[int]'
    for ($i = 0; $i -lt $Original.Length; $i++) {
        if ($Original[$i] -ne $Variant[$i]) { [void]$offsets.Add($i) }
    }
    return $offsets.ToArray()
}

function Assert-IlCurationChangedOffsets {
    param([int[]]$Actual, [int[]]$Expected, [string]$Label)
    $actualSorted = @($Actual | Sort-Object)
    $expectedSorted = @($Expected | Sort-Object)
    if (($actualSorted -join ',') -ne ($expectedSorted -join ',')) {
        throw ("$Label changed offsets differ: actual {0}; expected {1}" -f (Format-IlCurationOffsets $actualSorted), (Format-IlCurationOffsets $expectedSorted))
    }
}

function Assert-IlCurationRomIdentity {
    param([string]$Path, [string]$ExpectedSha1, [string]$ExpectedSha256, [string]$Label)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label is missing: $Path" }
    $length = (Get-Item -LiteralPath $Path).Length
    if ($length -ne $script:IlCurationOriginalLength) { throw "$Label length is $length, expected $($script:IlCurationOriginalLength)" }
    $sha1 = Get-IlCurationHashHex $Path 'SHA1'
    $sha256 = Get-IlCurationHashHex $Path 'SHA256'
    if ($sha1 -ine $ExpectedSha1) { throw "$Label SHA1 is $sha1, expected $ExpectedSha1" }
    if ($sha256 -ine $ExpectedSha256) { throw "$Label SHA256 is $sha256, expected $ExpectedSha256" }
    return [ordered]@{ length = $length; sha1 = $sha1; sha256 = $sha256 }
}

function Assert-IlCurationIdentityRecord {
    param($Provenance, $Observation, [string]$ExpectedSha1, [string]$ExpectedSha256)
    if ([string]$Provenance.original_rom_sha1 -ine $script:IlCurationOriginalSha1) { throw 'Provenance original ROM SHA1 is not the accepted original' }
    if ([string]$Provenance.original_rom_sha256 -ine $script:IlCurationOriginalSha256) { throw 'Provenance original ROM SHA256 is not the accepted original' }
    if ([string]$Provenance.expected_variant_sha1 -ine $ExpectedSha1) { throw 'Provenance expected variant SHA1 differs from the accepted image' }
    if ([string]$Provenance.expected_variant_sha256 -ine $ExpectedSha256) { throw 'Provenance expected variant SHA256 differs from the accepted image' }
    if ([string]$Provenance.run_rom_sha1 -ine $ExpectedSha1) { throw 'Provenance run-copy SHA1 differs from the accepted image' }
    if ([string]$Provenance.run_rom_sha256 -ine $ExpectedSha256) { throw 'Provenance run-copy SHA256 differs from the accepted image' }
    if ([string]$Observation.original_rom_sha1 -ine $script:IlCurationOriginalSha1) { throw 'Observation original ROM SHA1 is not the accepted original' }
    if ([string]$Observation.original_rom_sha256 -ine $script:IlCurationOriginalSha256) { throw 'Observation original ROM SHA256 is not the accepted original' }
    if ([string]$Observation.expected_variant_sha1 -ine $ExpectedSha1) { throw 'Observation expected variant SHA1 differs from the accepted image' }
    if ([string]$Observation.expected_variant_sha256 -ine $ExpectedSha256) { throw 'Observation expected variant SHA256 differs from the accepted image' }
    if ([string]$Observation.run_rom_sha1_after -ine $ExpectedSha1) { throw 'Observation run-copy SHA1 differs from the accepted image' }
    if ([string]$Observation.run_rom_sha256_after -ine $ExpectedSha256) { throw 'Observation run-copy SHA256 differs from the accepted image' }
}

function Test-IlStartupLog {
    param([string]$Log, [string]$ExpectedFields)
    $lines = @($Log -split "\r?\n")
    $failureIndex = Find-IlCurationMarkerIndex $lines '^ILBOOT_ROM_VERIFY_FAILED\b' 0
    if ($failureIndex -ge 0) { throw "Firmware verifier failure marker present at line $($failureIndex + 1): $($lines[$failureIndex])" }

    $resetCount = @($lines | Where-Object { $_ -match '^ILBOOT_RESET pc=7CD1\b' }).Count
    $initCount = @($lines | Where-Object { $_ -match '^ILBOOT_INIT_ENTRY pc=6750\b' }).Count
    if ($resetCount -eq 0) { throw 'Missing reset marker pc=7CD1' }
    if ($initCount -eq 0) { throw 'Missing init marker pc=6750' }

    $groups = New-Object 'System.Collections.Generic.List[object]'
    $current = $null
    $tailSeen = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '^ILBOOT_RESET\b' -or $line -match '^ILBOOT_INIT_ENTRY\b') {
            if ($null -ne $current) { throw "Checksum group interrupted before completion at line $($i + 1): $line" }
            if ($tailSeen) { throw "Startup marker after the init tail at line $($i + 1): $line" }
            continue
        }
        if ($line -match '^ILBOOT_ROM_CHECK_ENTRY\b') {
            if ($null -ne $current) { throw "Nested checksum entry at line $($i + 1): $line" }
            if ($tailSeen) { throw "Checksum entry after the init tail at line $($i + 1): $line" }
            $current = [ordered]@{
                check_index = $i; check = $line
                verify_index = -1; verify = $null
                sum_index = -1; sum = $null
                rotate_add_index = -1; rotate_add = $null
                rotate_sub_index = -1; rotate_sub = $null
                return_index = -1; return = $null
            }
            continue
        }
        if ($null -eq $current) {
            if ($line -match '^ILBOOT_INIT_TAIL_JMP pc=67B3\b') { $tailSeen = $true; continue }
            if ($line -match '^ILBOOT_(INIT_TAIL_ENTRY|VM_CALL|VM_ENTRY|CAPTURE_END)\b') {
                if (!$tailSeen) { throw "Startup marker before the init tail at line $($i + 1): $line" }
                continue
            }
            if ($line -match '^ILBOOT_') { throw "Startup marker outside a complete checksum group at line $($i + 1): $line" }
            continue
        }
        if ($line -match '^ILBOOT_ROM_VERIFY_ENTRY\b') {
            if ($current.verify_index -ge 0) { throw "Duplicate verifier entry at line $($i + 1): $line" }
            $current.verify_index = $i; $current.verify = $line; continue
        }
        if ($line -match '^ILBOOT_SUM_XOR\b') {
            if ($current.verify_index -lt 0) { throw "Sum/XOR before verifier entry at line $($i + 1): $line" }
            if ($current.sum_index -ge 0) { throw "Duplicate sum/XOR result at line $($i + 1): $line" }
            $current.sum_index = $i; $current.sum = $line; continue
        }
        if ($line -match '^ILBOOT_ROTATE_ADD\b') {
            if ($current.sum_index -lt 0) { throw "Rotate-add before sum/XOR at line $($i + 1): $line" }
            if ($current.rotate_add_index -ge 0) { throw "Duplicate rotate-add result at line $($i + 1): $line" }
            $current.rotate_add_index = $i; $current.rotate_add = $line; continue
        }
        if ($line -match '^ILBOOT_ROTATE_SUB_XOR\b') {
            if ($current.rotate_add_index -lt 0) { throw "Rotate-sub-XOR before rotate-add at line $($i + 1): $line" }
            if ($current.rotate_sub_index -ge 0) { throw "Duplicate rotate-sub-XOR result at line $($i + 1): $line" }
            $current.rotate_sub_index = $i; $current.rotate_sub = $line; continue
        }
        if ($line -match '^ILBOOT_ROM_CHECK_RETURN\b') {
            if ($current.rotate_sub_index -lt 0) { throw "Checksum return before rotate-sub-XOR at line $($i + 1): $line" }
            $current.return_index = $i; $current.return = $line
            $groups.Add($current)
            $current = $null
            continue
        }
        if ($line -match '^ILBOOT_') { throw "Unexpected startup marker inside a checksum group at line $($i + 1): $line" }
    }
    if ($null -ne $current) { throw 'Incomplete checksum group at the end of the log' }
    if ($groups.Count -eq 0) { throw 'No complete checksum group was observed' }

    for ($g = 0; $g -lt $groups.Count; $g++) {
        $group = $groups[$g]
        $number = $g + 1
        $gate = Get-IlCurationField $group.check 'gate719b'
        $expected = Get-IlCurationField $group.verify 'expected'
        $startAddr = Get-IlCurationField $group.verify 'start'
        $endAddr = Get-IlCurationField $group.verify 'end'
        $errorCode = Get-IlCurationField $group.verify 'error'
        $sumValue = Get-IlCurationField $group.sum 'sum'
        $xorValue = Get-IlCurationField $group.sum 'xor'
        $rotateAddValue = Get-IlCurationField $group.rotate_add 'value'
        $rotateSubA = Get-IlCurationField $group.rotate_sub 'a'
        $rotateSubB = Get-IlCurationField $group.rotate_sub 'b'
        $computed = $sumValue + $xorValue + $rotateAddValue + $rotateSubA + $rotateSubB
        if ($gate -ne '00') { throw "Checksum group $number first mismatch: gate719b=$gate, expected 00" }
        if ($expected -ne $ExpectedFields) { throw "Checksum group $number first mismatch: expected fields=$expected, expected $ExpectedFields" }
        if ($computed -ne $ExpectedFields) { throw "Checksum group $number first mismatch: computed fields=$computed, expected $ExpectedFields" }
        if ($startAddr -ne '1400') { throw "Checksum group $number first mismatch: start=$startAddr, expected 1400" }
        if ($endAddr -ne 'FFFF') { throw "Checksum group $number first mismatch: end=$endAddr, expected FFFF" }
        if ($errorCode -ne '12') { throw "Checksum group $number first mismatch: error=$errorCode, expected 12" }
    }

    $tailCount = @($lines | Where-Object { $_ -match '^ILBOOT_INIT_TAIL_JMP pc=67B3\b' }).Count
    if ($tailCount -ne 1) { throw "Expected exactly one init-tail marker pc=67B3, found $tailCount" }
    $tailIndex = Find-IlCurationMarkerIndex $lines '^ILBOOT_INIT_TAIL_JMP pc=67B3\b' 0
    $priorGroups = @($groups | Where-Object { $_.return_index -lt $tailIndex })
    if ($priorGroups.Count -eq 0) { throw 'No completed checksum group precedes the init tail' }
    $anchored = $priorGroups[$priorGroups.Count - 1]
    $groupsAfterTail = @($groups | Where-Object { $_.return_index -gt $tailIndex })
    if ($groupsAfterTail.Count -gt 0) { throw 'A checksum group completed after the init tail' }

    $vmEntryCount = @($lines | Where-Object { $_ -match '^ILBOOT_VM_ENTRY pc=76C7\b' }).Count
    if ($vmEntryCount -ne 1) { throw "Expected exactly one VM entry marker pc=76C7, found $vmEntryCount" }

    $forwardSpecs = @(
        @{ Key = 'init_tail_entry'; Pattern = '^ILBOOT_INIT_TAIL_ENTRY pc=3B1A\b' },
        @{ Key = 'vm_call'; Pattern = '^ILBOOT_VM_CALL pc=7CF6\b' },
        @{ Key = 'vm_entry'; Pattern = '^ILBOOT_VM_ENTRY pc=76C7\b' },
        @{ Key = 'end'; Pattern = '^ILBOOT_CAPTURE_END pc=76C7\b' }
    )
    $ordered = [ordered]@{}
    $start = $tailIndex + 1
    foreach ($spec in $forwardSpecs) {
        $index = Find-IlCurationMarkerIndex $lines $spec.Pattern $start
        if ($index -lt 0) { throw ('Chronological startup marker missing or out of order: ' + $spec.Key) }
        $ordered[$spec.Key] = [ordered]@{ index = $index; line = $lines[$index] }
        $start = $index + 1
    }
    for ($i = $ordered['end'].index + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^ILBOOT_') { throw "Capture marker after ILBOOT_CAPTURE_END: $($lines[$i])" }
    }
    foreach ($key in @('vm_call','vm_entry','end')) {
        $x = Get-IlCurationField $ordered[$key].line 'x'
        if ($x -ne 'FDF0') { throw "$key X=$x, expected FDF0" }
    }
    $firstWord = Get-IlCurationField $ordered['vm_entry'].line 'first_word'
    $firstWordEnd = Get-IlCurationField $ordered['end'].line 'first_word'
    if ($firstWord -ne $firstWordEnd) { throw 'VM entry and capture-end first_word differ' }

    $firstCheckIndex = Find-IlCurationMarkerIndex $lines '^ILBOOT_ROM_CHECK_ENTRY\b' 0
    $resetBefore = Find-IlCurationMarkerIndexBackward $lines '^ILBOOT_RESET pc=7CD1\b' ($firstCheckIndex - 1)
    $initBefore = Find-IlCurationMarkerIndexBackward $lines '^ILBOOT_INIT_ENTRY pc=6750\b' ($firstCheckIndex - 1)
    if ($resetBefore -lt 0 -or $initBefore -lt 0) { throw 'Reset/init markers do not precede the first checksum entry' }

    return [ordered]@{
        outcome = 'passed'
        group_count = $groups.Count
        reset_count = $resetCount
        init_count = $initCount
        check_entry = $anchored.check
        verify_entry = $anchored.verify
        sum_xor = $anchored.sum
        rotate_add = $anchored.rotate_add
        rotate_sub_xor = $anchored.rotate_sub
        checksum_return = $anchored.return
        init_tail_jump = $lines[$tailIndex]
        init_tail_entry = $ordered['init_tail_entry'].line
        vm_call = $ordered['vm_call'].line
        vm_entry = $ordered['vm_entry'].line
        capture_end = $ordered['end'].line
        expected_fields = $ExpectedFields
        computed_fields = (Get-IlCurationField $anchored.sum 'sum') + (Get-IlCurationField $anchored.sum 'xor') + (Get-IlCurationField $anchored.rotate_add 'value') + (Get-IlCurationField $anchored.rotate_sub 'a') + (Get-IlCurationField $anchored.rotate_sub 'b')
        initial_stream_pointer = (Get-IlCurationField $ordered['vm_entry'].line 'x')
        first_stream_word = $firstWord
        marker_order = '7CD1 reset -> 6750 init -> 66A5/66DB/66F3/6715/674C/677E per complete group -> 67B3 -> 3B1A -> 7CF6 -> 76C7 -> end'
    }
}

function Test-IlStartupCapture {
    param([string]$Run, [string]$Variant, [string]$OriginalRom, [string]$SourceMapPath, [string]$BuildReportPath)
    $run = [IO.Path]::GetFullPath($Run)
    $expected = $script:IlCurationVariants[$Variant]
    $paths = [ordered]@{
        log = Join-Path $run 'debug.log'
        console = Join-Path $run 'console.txt'
        console_error = Join-Path $run 'console.err.txt'
        provenance = Join-Path $run 'provenance.json'
        observation = Join-Path $run 'observation.json'
        exit = Join-Path $run 'exit-code.txt'
        arguments = Join-Path $run 'arguments.json'
        command = Join-Path $run 'command.json'
        timing = Join-Path $run 'timing.json'
        debugger = Join-Path $run 'debugger.cmd'
        version = Join-Path $run 'mame-version.txt'
        runRom = Join-Path $run 'roms/m4addr/a6ls.p1'
    }
    foreach ($key in $paths.Keys) {
        if (!(Test-Path -LiteralPath $paths[$key] -PathType Leaf)) { throw "Missing capture file: $($paths[$key])" }
    }

    $originalIdentity = Assert-IlCurationRomIdentity $OriginalRom $script:IlCurationOriginalSha1 $script:IlCurationOriginalSha256 'original ROM'
    $runRomIdentity = Assert-IlCurationRomIdentity $paths.runRom $expected.Sha1 $expected.Sha256 'isolated run ROM copy'
    $log = Get-Content -LiteralPath $paths.log -Raw
    $facts = Test-IlStartupLog $log $expected.Fields
    $provenance = Read-IlCurationJson $paths.provenance
    $observation = Read-IlCurationJson $paths.observation
    $command = Read-IlCurationJson $paths.command
    $timing = Read-IlCurationJson $paths.timing

    if ([string]$provenance.mode -ne 'Natural IL integrity startup observation') { throw "Unsupported capture mode: $($provenance.mode)" }
    if ([string]$provenance.variant -ne $Variant) { throw "Provenance variant differs: $($provenance.variant)" }
    if ([string]$provenance.starting_nvram -ne 'absent') { throw 'Unsupported starting NVRAM claim' }
    if ([string]$provenance.starting_configuration -notmatch '^absent;\s*-noreadconfig$') { throw 'Unsupported starting configuration claim' }
    if ([string]$provenance.user_inputs -ne 'none') { throw 'Unsupported user-input claim' }
    if (-not ($provenance.configuration_read_disabled -is [bool]) -or -not $provenance.configuration_read_disabled) { throw 'Configuration reading is not recorded as disabled' }
    if ([IO.Path]::GetFullPath([string]$provenance.working_directory) -ne $run) { throw 'Provenance working directory does not match the run directory' }
    if ([string]$provenance.mame_version -notmatch '^0\.281\b') { throw "Unexpected recorded MAME version: $($provenance.mame_version)" }
    $mamePath = [string]$provenance.mame_executable
    if (!(Test-Path -LiteralPath $mamePath -PathType Leaf)) { throw "Recorded MAME executable is missing: $mamePath" }
    $mameSha = Get-IlCurationHashHex $mamePath 'SHA256'
    if ($mameSha -ine $script:IlCurationMameSha256) { throw "Recorded MAME executable SHA256 is $mameSha, expected $($script:IlCurationMameSha256)" }
    if ([string]$provenance.mame_sha256 -ine $mameSha) { throw 'Provenance MAME SHA256 differs from the executable' }
    if ([int]$provenance.seconds_to_run -ne 30) { throw "Unexpected seconds_to_run: $($provenance.seconds_to_run)" }
    if ([int]$provenance.wall_timeout_seconds -gt 1800) { throw 'Wall timeout exceeds the 1800-second cap' }
    if ([string]$provenance.expected_fields -ne $expected.Fields) { throw 'Provenance expected fields differ' }
    Assert-IlCurationIdentityRecord $provenance $observation $expected.Sha1 $expected.Sha256
    if ([string]$provenance.expected_changed_offsets -ne (Format-IlCurationOffsets ([int[]]$expected.ChangedOffsets))) { throw 'Provenance expected changed offsets differ' }

    $empty = $provenance.pre_run_empty_directory_file_counts
    foreach ($name in @('cfg','nvram','inp','snap','comments','state','diff')) {
        if (-not ($empty.PSObject.Properties.Name -contains $name)) { throw "Provenance is missing pre-run emptiness for $name" }
        if ([int]$empty.$name -ne 0) { throw "Pre-run directory $name was not empty" }
    }
    $preRunRomFiles = @($provenance.pre_run_rom_directory_files)
    if ($preRunRomFiles.Count -ne 1 -or [string]$preRunRomFiles[0] -ne 'a6ls.p1') { throw 'Pre-run ROM directory was not exactly a6ls.p1' }

    if ([string]$observation.variant -ne $Variant) { throw 'Observation variant differs' }
    if ($null -eq $observation.exit_code -or [int]$observation.exit_code -ne 0) { throw 'Observation exit_code is not 0' }
    if (-not ($observation.timed_out -is [bool]) -or $observation.timed_out) { throw 'Observation timed_out is not boolean false' }
    if ([double]$observation.wall_seconds -le 0 -or [double]$observation.wall_seconds -gt [double]$provenance.wall_timeout_seconds) { throw 'Observation wall_seconds is outside the declared wall cap' }
    if (-not ($observation.rom_unchanged -is [bool]) -or -not $observation.rom_unchanged) { throw 'Observation rom_unchanged is not boolean true' }
    if ([string]$observation.expected_fields -ne $facts.expected_fields) { throw 'Observation expected_fields differs from the raw log' }
    if ([string]$observation.first_stream_word -ine $facts.first_stream_word) { throw 'Observation first_stream_word differs from the raw log' }
    $rawExit = (Get-Content -LiteralPath $paths.exit -Raw).Trim()
    if ($rawExit -ne '0') { throw "Capture exit-code.txt was $rawExit" }
    if ([int]$rawExit -ne [int]$observation.exit_code) { throw 'Observation exit_code differs from exit-code.txt' }

    $actualFlags = [ordered]@{
        reset_reached = ($facts.reset_count -gt 0)
        init_reached = ($facts.init_count -gt 0)
        check_reached = ($facts.group_count -gt 0)
        verify_reached = ($facts.group_count -gt 0)
        sum_reached = ($facts.group_count -gt 0)
        rotate_add_reached = ($facts.group_count -gt 0)
        rotate_sub_reached = ($facts.group_count -gt 0)
        failure_reached = $false
        checksum_returned = ($facts.group_count -gt 0)
        init_tail_jmp_reached = $true
        init_tail_entry_reached = $true
        vm_call_reached = $true
        vm_entry_reached = $true
        stopped_at_vm_entry = $true
        stopped_at_failure = $false
    }
    foreach ($key in $actualFlags.Keys) {
        if (-not ($observation.PSObject.Properties.Name -contains $key)) { throw "Observation is missing $key" }
        if (-not ($observation.$key -is [bool])) { throw "Observation $key is not boolean" }
        if ($observation.$key -ne $actualFlags[$key]) { throw "Observation $key differs from the raw log" }
    }
    if (-not ($timing.timed_out -is [bool]) -or $timing.timed_out) { throw 'Timing record reports a timeout' }
    if ($null -eq $timing.exit_code -or [int]$timing.exit_code -ne 0) { throw 'Timing record exit_code is not 0' }
    if ([IO.Path]::GetFullPath([string]$command.working_directory) -ne $run) { throw 'Command working directory does not match the run directory' }
    if ([int]$command.emulated_seconds_limit -ne 30) { throw 'Command emulated limit is not 30 seconds' }
    if ([int]$command.wall_timeout_seconds -gt 1800) { throw 'Command wall timeout exceeds the 1800-second cap' }

    $actualLogSha256 = Get-IlCurationHashHex $paths.log 'SHA256'
    $actualConsoleSha256 = Get-IlCurationHashHex $paths.console 'SHA256'
    $actualConsoleErrorSha256 = Get-IlCurationHashHex $paths.console_error 'SHA256'
    if ([string]$observation.debug_log_sha256 -ine $actualLogSha256) { throw 'Observation debug_log_sha256 does not match the raw debug.log' }
    if ([string]$observation.console_sha256 -ine $actualConsoleSha256) { throw 'Observation console_sha256 does not match the raw console.txt' }
    if ([string]$observation.console_error_sha256 -ine $actualConsoleErrorSha256) { throw 'Observation console_error_sha256 does not match the raw console.err.txt' }

    $mameArgs = @($command.arguments)
    foreach ($bad in @('-state','-playback','-autoboot_script','-autoboot_delay','-cheat','-nvram','-load')) {
        foreach ($arg in $mameArgs) {
            if ([string]$arg -ieq $bad -or [string]$arg -like "$bad=*") { throw "Unsupported state or injection argument: $arg" }
        }
    }
    if ($mameArgs -notcontains 'm4addr') { throw 'Arguments do not select m4addr' }
    if ($mameArgs -notcontains '-noreadconfig') { throw 'Arguments do not disable configuration reading' }
    foreach ($required in @('-debug','-debugger','-debugscript','-debuglog')) { if ($mameArgs -notcontains $required) { throw "Missing required argument: $required" } }
    $debugScriptArg = $null
    for ($i = 0; $i -lt $mameArgs.Count; $i++) {
        if ([string]$mameArgs[$i] -ieq '-debugscript') {
            if ($i + 1 -ge $mameArgs.Count) { throw 'Missing debugscript value' }
            $debugScriptArg = [string]$mameArgs[$i + 1]
        }
    }
    if ([IO.Path]::GetFullPath($debugScriptArg) -ne [IO.Path]::GetFullPath($paths.debugger)) { throw 'Debugger script argument does not point at the captured debugger.cmd' }
    $romPathArg = $null
    for ($i = 0; $i -lt $mameArgs.Count; $i++) {
        if ([string]$mameArgs[$i] -ieq '-rompath') { $romPathArg = [string]$mameArgs[$i + 1] }
    }
    $firstRomPath = ($romPathArg -split ';')[0]
    if ([IO.Path]::GetFullPath($firstRomPath) -ne [IO.Path]::GetFullPath((Join-Path $run 'roms'))) { throw 'First ROM path is not the isolated run roms directory' }
    $runRoot = $run.TrimEnd('\') + '\'
    foreach ($dirArg in @('-cfg_directory','-nvram_directory','-input_directory','-snapshot_directory','-comment_directory','-state_directory','-diff_directory')) {
        $dirValue = $null
        for ($i = 0; $i -lt $mameArgs.Count; $i++) {
            if ([string]$mameArgs[$i] -ieq $dirArg) { $dirValue = [string]$mameArgs[$i + 1] }
        }
        if ([string]::IsNullOrWhiteSpace($dirValue)) { throw "Missing directory argument $dirArg" }
        $dirFull = [IO.Path]::GetFullPath($dirValue)
        if (!($dirFull.StartsWith($runRoot, [StringComparison]::OrdinalIgnoreCase))) { throw "Directory argument $dirArg is outside the isolated run directory" }
    }
    $inputDirectory = $null
    for ($i = 0; $i -lt $mameArgs.Count; $i++) {
        if ([string]$mameArgs[$i] -ieq '-input_directory') { $inputDirectory = [string]$mameArgs[$i + 1] }
    }
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
    foreach ($address in $script:IlCurationRequiredBreakpoints) {
        if ($bpsetAddresses -notcontains $address) { throw "Missing expected breakpoint address: $address" }
    }

    $originalBytes = [IO.File]::ReadAllBytes($OriginalRom)
    $variantBytes = [IO.File]::ReadAllBytes($paths.runRom)
    $actualChanged = Get-IlCurationChangedOffsets $originalBytes $variantBytes
    Assert-IlCurationChangedOffsets $actualChanged $expected.ChangedOffsets "$Variant variant"
    $changedBytes = @()
    foreach ($offset in $actualChanged) {
        $changedBytes += [ordered]@{
            offset = Format-IlCurationOffset $offset
            original = ('{0:X2}' -f $originalBytes[$offset])
            variant = ('{0:X2}' -f $variantBytes[$offset])
        }
    }
    $fieldBytes = @()
    for ($i = 0; $i -lt 5; $i++) { $fieldBytes += ('{0:X2}' -f $variantBytes[0xFFD1 + $i]) }
    if (($fieldBytes -join '') -ne $expected.Fields) { throw "Variant active field bytes are $($fieldBytes -join '') not $($expected.Fields)" }

    $sourceMap = $null
    $buildReport = $null
    if ($Variant -eq 'Repaired') {
        if ([string]::IsNullOrWhiteSpace($SourceMapPath)) { throw 'Repaired variant requires -SourceMapPath' }
        if ([string]::IsNullOrWhiteSpace($BuildReportPath)) { throw 'Repaired variant requires -BuildReportPath' }
        if (!(Test-Path -LiteralPath $SourceMapPath -PathType Leaf)) { throw "Source map is missing: $SourceMapPath" }
        if (!(Test-Path -LiteralPath $BuildReportPath -PathType Leaf)) { throw "Build report is missing: $BuildReportPath" }
        $sourceMap = Read-IlCurationJson $SourceMapPath
        $buildReport = Read-IlCurationJson $BuildReportPath
        if ([string]$sourceMap.outputImageSha256 -ine $expected.Sha256) { throw 'Source map output image identity differs from the repaired image' }
        if ([string]$sourceMap.originalRomSha256 -ine $script:IlCurationOriginalSha256) { throw 'Source map original ROM identity differs from the accepted original' }
        $entryAt9EDC = @($sourceMap.entries | Where-Object { [string]$_.address -ieq '9EDC' })
        if ($entryAt9EDC.Count -ne 1) { throw 'Source map does not contain exactly one 9EDC entry' }
        if ([string]$entryAt9EDC[0].imageByte -ine '00') { throw 'Source map 9EDC byte is not the repaired 00 value' }
        if ([string]$buildReport.repaired.sha256 -ine $expected.Sha256) { throw 'Build report repaired SHA256 differs from the accepted image' }
        if ([string]$buildReport.original.sha256 -ine $script:IlCurationOriginalSha256) { throw 'Build report original SHA256 differs from the accepted original' }
        $reportedOffsets = @($buildReport.repaired.changedOffsetsHex | ForEach-Object { [string]$_ })
        $expectedOffsets = @($expected.ChangedOffsets | ForEach-Object { Format-IlCurationOffset $_ })
        if (($reportedOffsets -join ',') -ne ($expectedOffsets -join ',')) { throw 'Build report repaired changed offsets differ from the accepted set' }
    }

    return [ordered]@{
        run_directory = $run
        variant = $Variant
        facts = $facts
        provenance = $provenance
        observation = $observation
        command = $command
        timing = $timing
        original_identity = $originalIdentity
        run_rom_identity = $runRomIdentity
        changed_offsets = $actualChanged
        changed_bytes = $changedBytes
        field_bytes = ($fieldBytes -join '')
        actual_log_sha256 = $actualLogSha256
        actual_console_sha256 = $actualConsoleSha256
        actual_console_error_sha256 = $actualConsoleErrorSha256
        debug_log = $log
        source_map = $sourceMap
        build_report = $buildReport
        source_map_sha256 = $(if ($sourceMap) { Get-IlCurationHashHex $SourceMapPath 'SHA256' } else { $null })
        build_report_sha256 = $(if ($buildReport) { Get-IlCurationHashHex $BuildReportPath 'SHA256' } else { $null })
    }
}

function Assert-IlCurationOutputAvailable {
    param([string]$OutputPath)
    $out = [IO.Path]::GetFullPath($OutputPath)
    $parent = Split-Path -Parent $out
    if ([string]::IsNullOrWhiteSpace($parent) -or !(Test-Path -LiteralPath $parent -PathType Container)) { throw "Output parent directory is missing: $parent" }
    if (Test-Path -LiteralPath $out) { throw "Curated output is create-only and already exists: $out" }
    return $out
}

function Write-IlCurationOutput {
    param([string]$Path, $Object)
    $json = ConvertTo-Json -InputObject $Object -Depth 14
    $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($json)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) }
    finally { $stream.Dispose() }
}

function Copy-IlCurationRunForTamper {
    param([string]$Source, [string]$Destination)
    New-Item -ItemType Directory -Path $Destination | Out-Null
    Copy-Item -Path (Join-Path $Source '*') -Destination $Destination -Recurse
    $sourceFull = [IO.Path]::GetFullPath($Source)
    $destFull = [IO.Path]::GetFullPath($Destination)
    foreach ($name in @('arguments.json','command.json')) {
        $path = Join-Path $Destination $name
        $value = Read-IlCurationJson $path
        if ($name -eq 'arguments.json') {
            $newArgs = @($value | ForEach-Object { ([string]$_).Replace($sourceFull, $destFull) })
            $text = ConvertTo-Json -InputObject @($newArgs) -Depth 6
            [IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
        } else {
            $value.working_directory = $destFull
            $value.arguments = @($value.arguments | ForEach-Object { ([string]$_).Replace($sourceFull, $destFull) })
            [IO.File]::WriteAllText($path, (ConvertTo-Json -InputObject $value -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
        }
    }
    $provPath = Join-Path $Destination 'provenance.json'
    $prov = Read-IlCurationJson $provPath
    $prov.working_directory = $destFull
    [IO.File]::WriteAllText($provPath, (ConvertTo-Json -InputObject $prov -Depth 12), (New-Object System.Text.UTF8Encoding($false)))
    $commandPath = Join-Path $Destination 'command.json'
    $cmd = Read-IlCurationJson $commandPath
    $cmd.working_directory = $destFull
    $cmd.arguments = @($cmd.arguments | ForEach-Object { ([string]$_).Replace($sourceFull, $destFull) })
    [IO.File]::WriteAllText($commandPath, (ConvertTo-Json -InputObject $cmd -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
    return $destFull
}

function Test-IlCurationNegativeControl {
    param([string]$Name, [scriptblock]$Block, [string]$ExpectedPattern)
    try {
        & $Block | Out-Null
        throw "Negative control '$Name' was not rejected"
    }
    catch {
        $message = $_.Exception.Message
        if ($message -eq "Negative control '$Name' was not rejected") { throw }
        if ($message -notmatch $ExpectedPattern) { throw "Negative control '$Name' was rejected with unexpected message: $message" }
        Write-Output ("Negative control rejected {0}: {1}" -f $Name, $message)
    }
}

function Get-IlCurationRelativePath {
    param([string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetFullPath((Get-Location).Path)
    if ($full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($root.Length).TrimStart('\','/').Replace('\','/')
    }
    return $full.Replace('\','/')
}

function New-IlCurationRunResult {
    param($Capture, [string]$SourceMapPath, [string]$BuildReportPath)
    $run = $Capture.run_directory
    $variant = $Capture.variant
    $facts = $Capture.facts
    $provenance = $Capture.provenance
    $observation = $Capture.observation
    return [ordered]@{
        schema_version = 1
        task = 'il-boot-04'
        classification = 'Natural MAME 0.281 fresh-boot startup observation of one identity-checked A6L image. The original checker code, gates, ranges and disabled records are preserved; the repaired variant differs only at the IL operand and the five active expected fields.'
        variant = $variant
        rom = [ordered]@{
            name = 'a6ls.p1'
            length = $Capture.run_rom_identity.length
            original_sha1 = $Capture.original_identity.sha1
            original_sha256 = $Capture.original_identity.sha256
            variant_sha1 = $Capture.run_rom_identity.sha1
            variant_sha256 = $Capture.run_rom_identity.sha256
            run_copy_sha1_after = $observation.run_rom_sha1_after
            run_copy_sha256_after = $observation.run_rom_sha256_after
            unchanged = $true
            changed_offsets = @($Capture.changed_offsets | ForEach-Object { Format-IlCurationOffset $_ })
            changed_bytes = $Capture.changed_bytes
            active_fields_hex = $Capture.field_bytes
        }
        starting_contract = [ordered]@{
            mode = $provenance.mode
            declared_starting_nvram = $provenance.starting_nvram
            declared_starting_configuration = $provenance.starting_configuration
            declared_user_inputs = $provenance.user_inputs
            configuration_read_disabled = $true
            isolated_rom_copy = ('verified: length {0}; SHA1 {1}; SHA256 {2}' -f $Capture.run_rom_identity.length, $Capture.run_rom_identity.sha1, $Capture.run_rom_identity.sha256)
            pre_run_empty_directory_file_counts = $provenance.pre_run_empty_directory_file_counts
            pre_run_rom_directory_files = $provenance.pre_run_rom_directory_files
            user_inputs = 'none; no input playback files and no playback argument'
            pc_ram_input_or_rom_injection = 'none; debugger script contains only bpset/printf/go/quit and arguments contain no state load, playback, autoboot or cheat option'
        }
        mame = [ordered]@{
            executable = $provenance.mame_executable
            sha256 = $provenance.mame_sha256
            version = $provenance.mame_version
            command_arguments = @($Capture.command.arguments)
            emulated_seconds_limit = [int]$Capture.command.emulated_seconds_limit
            wall_timeout_seconds = [int]$Capture.command.wall_timeout_seconds
            exit_code = [int]$observation.exit_code
            timed_out = $false
            wall_seconds = [double]$observation.wall_seconds
        }
        instrumentation = [ordered]@{
            observation_only = $true
            marker_prefix = 'ILBOOT_'
            debugger_script_sha256 = Get-IlCurationHashHex (Join-Path $run 'debugger.cmd') 'SHA256'
            debug_log_sha256 = $Capture.actual_log_sha256
            console_sha256 = $Capture.actual_console_sha256
            console_error_sha256 = $Capture.actual_console_error_sha256
            no_ram_pc_register_or_rom_injection = $true
            vm_entry_phase = 'Entry to native 76C7 before the F8/FC trampoline has fetched a token. X=FDF0 is the initial token-stream pointer; the recorded Y value belongs to the caller and is not a fetched VM cursor. first_stream_word is a read-only peek at the not-yet-fetched stream head, not an executed instruction or IL mapping.'
        }
        observed = $facts
        verification = [ordered]@{
            original_rom_identity = $true
            variant_identity_sha1_sha256 = $true
            run_copy_identity = $true
            exact_changed_byte_set = $true
            active_field_bytes_match = $true
            exit_code_consistent = $true
            debug_log_hash_matches_observation = $true
            console_hash_matches_observation = $true
            observation_booleans_match_log = $true
            marker_order_enforced = $true
            all_complete_checksum_groups_match = $true
            first_mismatch_reported = $true
            firmware_failure_marker_absent = $true
            required_breakpoint_addresses = $script:IlCurationRequiredBreakpoints
            injection_claim_supported = $true
            starting_nvram_verification = 'declared by capture provenance; pre-run emptiness recorded by the capture before launch'
            source_map_bound_to_variant = $(if ($variant -eq 'Repaired') { $true } else { $null })
            source_map_sha256 = $Capture.source_map_sha256
            build_report_sha256 = $Capture.build_report_sha256
        }
        provenance = [ordered]@{
            capture_script = 'tools/Capture-IlIntegrityStartup.ps1'
            curator_script = 'tools/Curate-IlIntegrityStartup.ps1'
            raw_run_directory = Get-IlCurationRelativePath $run
            original_control_evidence = 'evidence/mpu4/integrity/original-startup-vm-entry.json'
            build_report = $(if ($BuildReportPath) { Get-IlCurationRelativePath $BuildReportPath } else { $null })
            source_map = $(if ($SourceMapPath) { Get-IlCurationRelativePath $SourceMapPath } else { $null })
            static_evidence = @('evidence/mpu4/maps/rom-integrity.json','evidence/mpu4/native/66a5.json','evidence/mpu4/native/66db.json','evidence/mpu4/native/76c7.json')
        }
        limitations = @(
            'This is one natural cold reset observation per image in MAME 0.281, stopped at the first 76C7 entry or the first failure.',
            'The capture records checker fields, return, init tail and VM entry. It does not observe the first token fetch, 9ED9 execution, gameplay, randomness, timing equivalence or physical hardware.',
            'The 76C7 observation is an interpreter entry before the F8/FC trampoline fetches a token. Y at that point is not a fetched VM cursor, and no PC-to-IL mapping beyond the native entry PC is claimed.',
            'The repaired variant passes the original checker and reaches the same VM entry and stream pointer as the original control. This does not establish later definition or gameplay behaviour.',
            'MAME loader hash warnings for modified images remain expected and are not firmware-integrity repair.',
            'Starting NVRAM/configuration absence is recorded before launch by the capture; it is not an inference from post-run files.',
            'Negative controls are synthetic tampering of copied run artifacts, not natural execution evidence.'
        )
    }
}

function New-IlCurationCombinedResult {
    param($ControlCapture, $ChangedCapture, [string]$SourceMapPath, [string]$BuildReportPath)
    $control = New-IlCurationRunResult $ControlCapture $null $null
    $changed = New-IlCurationRunResult $ChangedCapture $SourceMapPath $BuildReportPath
    $controlFacts = $ControlCapture.facts
    $changedFacts = $ChangedCapture.facts
    $controlConsoleError = Get-Content -LiteralPath (Join-Path $ControlCapture.run_directory 'console.err.txt') -Raw
    $changedConsoleError = Get-Content -LiteralPath (Join-Path $ChangedCapture.run_directory 'console.err.txt') -Raw
    $controlMarkers = @(($ControlCapture.debug_log -split "\r?\n") | Where-Object { $_ -match '^ILBOOT_' } | ForEach-Object { ($_ -split ' ')[0] })
    $changedMarkers = @(($ChangedCapture.debug_log -split "\r?\n") | Where-Object { $_ -match '^ILBOOT_' } | ForEach-Object { ($_ -split ' ')[0] })
    $markerChainSame = (($controlMarkers -join ',') -eq ($changedMarkers -join ','))
    $vmEntryFields = @('pc','x','y','u','s')
    $vmEntrySame = $true
    foreach ($field in $vmEntryFields) {
        if ((Get-IlCurationField $controlFacts.vm_entry $field) -ne (Get-IlCurationField $changedFacts.vm_entry $field)) { $vmEntrySame = $false }
    }
    $controlLoaderWarning = [regex]::IsMatch($controlConsoleError, '(?i)WRONG CHECKSUMS|the machine might not run correctly')
    $changedLoaderWarning = [regex]::IsMatch($changedConsoleError, '(?i)WRONG CHECKSUMS|the machine might not run correctly')
    $controlEmulated = [regex]::Match((Get-Content -LiteralPath (Join-Path $ControlCapture.run_directory 'console.txt') -Raw), '\((\d+(?:\.\d+)?) seconds\)')
    $changedEmulated = [regex]::Match((Get-Content -LiteralPath (Join-Path $ChangedCapture.run_directory 'console.txt') -Raw), '\((\d+(?:\.\d+)?) seconds\)')
    $expectedOffsets = @($ChangedCapture.changed_offsets | ForEach-Object { Format-IlCurationOffset $_ })
    return [ordered]@{
        schema_version = 1
        task = 'il-boot-04'
        classification = 'Natural MAME 0.281 fresh-boot control/changed comparison. The untouched original and the IL 9ED9 operand edit with ordered active-field repair both pass the original firmware checker and reach the same first VM entry. This is startup/checksum acceptance only, not 9ED9 execution or gameplay.'
        images = [ordered]@{
            original = [ordered]@{
                name = 'a6ls.p1'
                length = $ControlCapture.run_rom_identity.length
                sha1 = $ControlCapture.run_rom_identity.sha1
                sha256 = $ControlCapture.run_rom_identity.sha256
                active_fields_hex = $ControlCapture.field_bytes
                changed_offsets = @()
            }
            repaired = [ordered]@{
                name = 'a6ls.p1'
                length = $ChangedCapture.run_rom_identity.length
                sha1 = $ChangedCapture.run_rom_identity.sha1
                sha256 = $ChangedCapture.run_rom_identity.sha256
                active_fields_hex = $ChangedCapture.field_bytes
                changed_offsets = $expectedOffsets
                changed_bytes = $ChangedCapture.changed_bytes
            }
        }
        starting_contract = [ordered]@{
            mode = 'Natural IL integrity startup observation'
            starting_nvram = 'absent for both runs'
            starting_configuration = 'absent for both runs; -noreadconfig'
            user_inputs = 'none for both runs'
            configuration_read_disabled = $true
            pre_run_empty_directory_file_counts = [ordered]@{
                original = $ControlCapture.provenance.pre_run_empty_directory_file_counts
                repaired = $ChangedCapture.provenance.pre_run_empty_directory_file_counts
            }
            pre_run_rom_directory_files = [ordered]@{
                original = $ControlCapture.provenance.pre_run_rom_directory_files
                repaired = $ChangedCapture.provenance.pre_run_rom_directory_files
            }
            injection = 'none; both debugger scripts contain only bpset/printf/go/quit and both argument sets contain no state load, playback, autoboot or cheat option'
        }
        mame = [ordered]@{
            executable = $ChangedCapture.provenance.mame_executable
            sha256 = $ChangedCapture.provenance.mame_sha256
            version = $ChangedCapture.provenance.mame_version
            command_arguments = [ordered]@{
                original = @($ControlCapture.command.arguments)
                repaired = @($ChangedCapture.command.arguments)
            }
            emulated_seconds_limit = 30
            emulated_seconds_reported = [ordered]@{
                original = $(if ($controlEmulated.Success) { [double]$controlEmulated.Groups[1].Value } else { $null })
                repaired = $(if ($changedEmulated.Success) { [double]$changedEmulated.Groups[1].Value } else { $null })
            }
            emulated_seconds_source = 'MAME console summary line; not a stopwatch'
            wall_timeout_seconds = [int]$ChangedCapture.command.wall_timeout_seconds
            exits = [ordered]@{
                original = [int]$ControlCapture.observation.exit_code
                repaired = [int]$ChangedCapture.observation.exit_code
            }
            wall_seconds = [ordered]@{
                original = [double]$ControlCapture.observation.wall_seconds
                repaired = [double]$ChangedCapture.observation.wall_seconds
            }
            timed_out = $false
        }
        instrumentation = [ordered]@{
            observation_only = $true
            marker_prefix = 'ILBOOT_'
            original_debugger_script_sha256 = Get-IlCurationHashHex (Join-Path $ControlCapture.run_directory 'debugger.cmd') 'SHA256'
            repaired_debugger_script_sha256 = Get-IlCurationHashHex (Join-Path $ChangedCapture.run_directory 'debugger.cmd') 'SHA256'
            no_ram_pc_register_or_rom_injection = $true
            vm_entry_phase = 'Entry to native 76C7 before the F8/FC trampoline has fetched a token. X=FDF0 is the initial token-stream pointer; Y at this point belongs to the caller and is not a fetched VM cursor. first_stream_word is a read-only peek at the not-yet-fetched stream head, not an executed instruction or IL mapping.'
        }
        runs = [ordered]@{
            original = [ordered]@{
                run_directory = Get-IlCurationRelativePath $ControlCapture.run_directory
                exit_code = [int]$ControlCapture.observation.exit_code
                timed_out = $false
                wall_seconds = [double]$ControlCapture.observation.wall_seconds
                debug_log_sha256 = $ControlCapture.actual_log_sha256
                console_sha256 = $ControlCapture.actual_console_sha256
                console_error_sha256 = $ControlCapture.actual_console_error_sha256
                observed = $controlFacts
                loader_hash_warning_present = $controlLoaderWarning
            }
            repaired = [ordered]@{
                run_directory = Get-IlCurationRelativePath $ChangedCapture.run_directory
                exit_code = [int]$ChangedCapture.observation.exit_code
                timed_out = $false
                wall_seconds = [double]$ChangedCapture.observation.wall_seconds
                debug_log_sha256 = $ChangedCapture.actual_log_sha256
                console_sha256 = $ChangedCapture.actual_console_sha256
                console_error_sha256 = $ChangedCapture.actual_console_error_sha256
                observed = $changedFacts
                loader_hash_warning_present = $changedLoaderWarning
            }
        }
        build = [ordered]@{
            repaired_sha256 = $ChangedCapture.run_rom_identity.sha256
            source_map_sha256 = $ChangedCapture.source_map_sha256
            build_report_sha256 = $ChangedCapture.build_report_sha256
            source_map_bound_to_repaired_image = $true
            source_map = $(if ($SourceMapPath) { Get-IlCurationRelativePath $SourceMapPath } else { $null })
            build_report = $(if ($BuildReportPath) { Get-IlCurationRelativePath $BuildReportPath } else { $null })
        }
        comparison = [ordered]@{
            control_fields = $controlFacts.expected_fields
            repaired_fields = $changedFacts.expected_fields
            control_computed_fields = $controlFacts.computed_fields
            repaired_computed_fields = $changedFacts.computed_fields
            changed_offsets = $expectedOffsets
            marker_chain_same = $markerChainSame
            reset_count_same = ($controlFacts.reset_count -eq $changedFacts.reset_count)
            init_count_same = ($controlFacts.init_count -eq $changedFacts.init_count)
            checksum_group_count_same = ($controlFacts.group_count -eq $changedFacts.group_count)
            vm_entry_pc_x_y_u_s_same = $vmEntrySame
            initial_stream_pointer_same = ($controlFacts.initial_stream_pointer -eq $changedFacts.initial_stream_pointer)
            initial_stream_pointer = $changedFacts.initial_stream_pointer
            first_stream_word_same = ($controlFacts.first_stream_word -eq $changedFacts.first_stream_word)
            first_stream_word = $changedFacts.first_stream_word
            firmware_failure_marker_absent_in_both = $true
            all_complete_checksum_groups_match_in_both = $true
            loader_hash_warning_in_control = $controlLoaderWarning
            loader_hash_warning_in_repaired = $changedLoaderWarning
            loader_warning_separate_from_firmware_check = $true
        }
        verification = [ordered]@{
            control_rom_identity = $true
            repaired_rom_identity = $true
            exact_changed_byte_set = $true
            active_field_bytes_match_both = $true
            both_exit_zero = $true
            both_rom_copies_unchanged = $true
            raw_log_and_console_hashes_recomputed = $true
            observation_booleans_match_logs = $true
            marker_order_enforced = $true
            all_complete_checksum_groups_match = $true
            first_mismatch_reported = $true
            firmware_failure_marker_absent = $true
            required_breakpoint_addresses = $script:IlCurationRequiredBreakpoints
            injection_claim_supported = $true
            starting_nvram_verification = 'declared and pre-run emptiness recorded by both captures before launch'
            source_map_bound_to_repaired_image = $true
        }
        provenance = [ordered]@{
            capture_script = 'tools/Capture-IlIntegrityStartup.ps1'
            curator_script = 'tools/Curate-IlIntegrityStartup.ps1'
            original_run_directory = Get-IlCurationRelativePath $ControlCapture.run_directory
            repaired_run_directory = Get-IlCurationRelativePath $ChangedCapture.run_directory
            build_report = $(if ($BuildReportPath) { Get-IlCurationRelativePath $BuildReportPath } else { $null })
            source_map = $(if ($SourceMapPath) { Get-IlCurationRelativePath $SourceMapPath } else { $null })
            prior_original_startup_evidence = 'evidence/mpu4/integrity/original-startup-vm-entry.json'
            static_evidence = @('evidence/mpu4/maps/rom-integrity.json','evidence/mpu4/native/66a5.json','evidence/mpu4/native/66db.json','evidence/mpu4/native/76c7.json')
        }
        limitations = @(
            'This is one natural cold reset observation per image in MAME 0.281, stopped at the first 76C7 entry or the first failure.',
            'The captures record checker fields, return, init tail and VM entry. They do not observe the first token fetch, 9ED9 execution, gameplay, randomness, timing equivalence or physical hardware.',
            'The 76C7 observation is an interpreter entry before the F8/FC trampoline fetches a token. Y at that point is not a fetched VM cursor, and no PC-to-IL mapping beyond the native entry PC is claimed.',
            'The repaired image passes the original checker and reaches the same VM entry, stream pointer and first stream word as the original control. This does not establish later definition or gameplay behaviour.',
            'The repaired image produces expected MAME loader CRC/SHA warnings. Those loader warnings are separate from, and do not weaken, the original firmware checker result.',
            'Starting NVRAM/configuration absence is recorded before launch by each capture; it is not an inference from post-run files.',
            'Negative controls are synthetic tampering of copied run artifacts, not natural execution evidence.'
        )
    }
}

function Invoke-IlCurationMain {
    $combinedMode = (![string]::IsNullOrWhiteSpace($ControlRunDirectory) -or ![string]::IsNullOrWhiteSpace($ChangedRunDirectory))
    if ($combinedMode) {
        foreach ($name in @('ControlRunDirectory','ChangedRunDirectory','OutputPath','OriginalRom')) {
            if ([string]::IsNullOrWhiteSpace((Get-Variable -Name $name -ValueOnly))) { throw "Missing required parameter: $name" }
        }
        $controlRun = [IO.Path]::GetFullPath($ControlRunDirectory)
        $changedRun = [IO.Path]::GetFullPath($ChangedRunDirectory)
        $controlCapture = Test-IlStartupCapture $controlRun 'Original' $OriginalRom $null $null
        $changedCapture = Test-IlStartupCapture $changedRun 'Repaired' $OriginalRom $SourceMapPath $BuildReportPath
        $outputFull = Assert-IlCurationOutputAvailable $OutputPath
        $result = New-IlCurationCombinedResult $controlCapture $changedCapture $SourceMapPath $BuildReportPath
        Write-IlCurationOutput $outputFull $result
        Write-Output "Curated $outputFull"
        return
    }
    foreach ($name in @('RunDirectory','OutputPath','Variant','OriginalRom')) {
        if ([string]::IsNullOrWhiteSpace((Get-Variable -Name $name -ValueOnly))) { throw "Missing required parameter: $name" }
    }
    $run = [IO.Path]::GetFullPath($RunDirectory)
    $capture = Test-IlStartupCapture $run $Variant $OriginalRom $SourceMapPath $BuildReportPath
    $outputFull = Assert-IlCurationOutputAvailable $OutputPath

    if ($NegativeControl) {
        $tamperRoot = Join-Path ([IO.Path]::GetTempPath()) ('fm-ilboot04-curate-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tamperRoot | Out-Null
        try {
            $tampered = Copy-IlCurationRunForTamper $run (Join-Path $tamperRoot 'identity')
            $prov = Read-IlCurationJson (Join-Path $tampered 'provenance.json')
            $prov.expected_variant_sha1 = ('0' * 40)
            [IO.File]::WriteAllText((Join-Path $tampered 'provenance.json'), (ConvertTo-Json -InputObject $prov -Depth 12), (New-Object System.Text.UTF8Encoding($false)))
            Test-IlCurationNegativeControl 'tampered provenance identity' { Test-IlStartupCapture $tampered $Variant $OriginalRom $SourceMapPath $BuildReportPath } 'expected variant SHA1'

            $tampered = Copy-IlCurationRunForTamper $run (Join-Path $tamperRoot 'observation')
            $obs = Read-IlCurationJson (Join-Path $tampered 'observation.json')
            $obs.original_rom_sha1 = ('0' * 40)
            [IO.File]::WriteAllText((Join-Path $tampered 'observation.json'), (ConvertTo-Json -InputObject $obs -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
            Test-IlCurationNegativeControl 'stale observation identity' { Test-IlStartupCapture $tampered $Variant $OriginalRom $SourceMapPath $BuildReportPath } 'Observation original ROM SHA1'

            $tampered = Copy-IlCurationRunForTamper $run (Join-Path $tamperRoot 'rom')
            $runRomPath = Join-Path $tampered 'roms/m4addr/a6ls.p1'
            $bytes = [IO.File]::ReadAllBytes($runRomPath)
            $bytes[0] = $bytes[0] -bxor 0xFF
            [IO.File]::WriteAllBytes($runRomPath, $bytes)
            Test-IlCurationNegativeControl 'changed isolated ROM copy' { Test-IlStartupCapture $tampered $Variant $OriginalRom $SourceMapPath $BuildReportPath } 'isolated run ROM copy'

            $tampered = Copy-IlCurationRunForTamper $run (Join-Path $tamperRoot 'loghash')
            $obs = Read-IlCurationJson (Join-Path $tampered 'observation.json')
            $obs.debug_log_sha256 = ('0' * 64)
            [IO.File]::WriteAllText((Join-Path $tampered 'observation.json'), (ConvertTo-Json -InputObject $obs -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
            Test-IlCurationNegativeControl 'tampered log hash' { Test-IlStartupCapture $tampered $Variant $OriginalRom $SourceMapPath $BuildReportPath } 'debug_log_sha256'

            $tampered = Copy-IlCurationRunForTamper $run (Join-Path $tamperRoot 'injection')
            Add-Content -LiteralPath (Join-Path $tampered 'debugger.cmd') -Value 'set pc=76c7'
            Test-IlCurationNegativeControl 'debugger state injection' { Test-IlStartupCapture $tampered $Variant $OriginalRom $SourceMapPath $BuildReportPath } 'Unsupported debugger command'

            $tampered = Copy-IlCurationRunForTamper $run (Join-Path $tamperRoot 'missing')
            $logPath = Join-Path $tampered 'debug.log'
            $logText = Get-Content -LiteralPath $logPath -Raw
            $changed = [regex]::Replace($logText, '(?m)^ILBOOT_ROTATE_SUB_XOR[^\r\n]*\r?\n', '')
            [IO.File]::WriteAllText($logPath, $changed)
            $obs = Read-IlCurationJson (Join-Path $tampered 'observation.json')
            $obs.debug_log_sha256 = Get-IlCurationHashHex $logPath 'SHA256'
            [IO.File]::WriteAllText((Join-Path $tampered 'observation.json'), (ConvertTo-Json -InputObject $obs -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
            Test-IlCurationNegativeControl 'missing rotate marker' { Test-IlStartupCapture $tampered $Variant $OriginalRom $SourceMapPath $BuildReportPath } 'missing or out of order|Incomplete checksum|before rotate-sub-XOR'

            $tampered = Copy-IlCurationRunForTamper $run (Join-Path $tamperRoot 'failure')
            $logPath = Join-Path $tampered 'debug.log'
            $logText = Get-Content -LiteralPath $logPath -Raw
            $changed = $logText.Replace("ILBOOT_INIT_TAIL_JMP", "ILBOOT_ROM_VERIFY_FAILED error=12`r`nILBOOT_INIT_TAIL_JMP")
            [IO.File]::WriteAllText($logPath, $changed)
            $obs = Read-IlCurationJson (Join-Path $tampered 'observation.json')
            $obs.debug_log_sha256 = Get-IlCurationHashHex $logPath 'SHA256'
            [IO.File]::WriteAllText((Join-Path $tampered 'observation.json'), (ConvertTo-Json -InputObject $obs -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
            Test-IlCurationNegativeControl 'firmware failure marker' { Test-IlStartupCapture $tampered $Variant $OriginalRom $SourceMapPath $BuildReportPath } 'failure marker'

            $tampered = Copy-IlCurationRunForTamper $run (Join-Path $tamperRoot 'fields')
            $logPath = Join-Path $tampered 'debug.log'
            $logText = Get-Content -LiteralPath $logPath -Raw
            $changed = $logText.Replace('expected=' + $capture.facts.expected_fields, 'expected=0000000000').Replace('sum=' + $capture.facts.computed_fields.Substring(0,2), 'sum=00')
            [IO.File]::WriteAllText($logPath, $changed)
            $obs = Read-IlCurationJson (Join-Path $tampered 'observation.json')
            $obs.debug_log_sha256 = Get-IlCurationHashHex $logPath 'SHA256'
            [IO.File]::WriteAllText((Join-Path $tampered 'observation.json'), (ConvertTo-Json -InputObject $obs -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
            Test-IlCurationNegativeControl 'first field mismatch' { Test-IlStartupCapture $tampered $Variant $OriginalRom $SourceMapPath $BuildReportPath } 'first mismatch'

            $tampered = Copy-IlCurationRunForTamper $run (Join-Path $tamperRoot 'preexisting')
            $prov = Read-IlCurationJson (Join-Path $tampered 'provenance.json')
            $prov.pre_run_empty_directory_file_counts.cfg = 1
            [IO.File]::WriteAllText((Join-Path $tampered 'provenance.json'), (ConvertTo-Json -InputObject $prov -Depth 12), (New-Object System.Text.UTF8Encoding($false)))
            Test-IlCurationNegativeControl 'pre-run configuration collision' { Test-IlStartupCapture $tampered $Variant $OriginalRom $SourceMapPath $BuildReportPath } 'Pre-run directory cfg was not empty'

            $existingOutput = Join-Path $tamperRoot 'existing-output.json'
            Set-Content -LiteralPath $existingOutput -Value 'synthetic'
            Test-IlCurationNegativeControl 'create-only output collision' { Assert-IlCurationOutputAvailable $existingOutput } 'create-only'
        }
        finally {
            Remove-Item -LiteralPath $tamperRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $result = New-IlCurationRunResult $capture $SourceMapPath $BuildReportPath
    Write-IlCurationOutput $outputFull $result
    Write-Output "Curated $outputFull"
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-IlCurationMain
}

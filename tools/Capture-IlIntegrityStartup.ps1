[CmdletBinding()]
param(
    [string]$MameExecutable,
    [string]$RomDirectory,
    [string]$OriginalRom,
    [string]$VariantRom,
    [ValidateSet('Original','Repaired')][string]$Variant,
    [string]$RunDirectory,
    [ValidateRange(1,60)][int]$SecondsToRun = 30,
    [ValidateRange(30,1800)][int]$WallTimeoutSeconds = 600
)
$ErrorActionPreference = 'Stop'

$script:IlBootOriginalLength = 65536
$script:IlBootOriginalSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$script:IlBootOriginalSha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
$script:IlBootVariants = @{
    Original = @{
        Sha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
        Sha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
        Fields = '3E761E2605'
        ChangedOffsets = @()
        Description = 'untouched original control image'
    }
    Repaired = @{
        Sha1 = 'e1a42dccd304b7b175aabac99e8400cdad04cf69'
        Sha256 = '577f76bd36dfca04dfb01b5f5d0be93e16572f8617c7ca906397c98df36e5107'
        Fields = 'BEF69E7CC7'
        ChangedOffsets = @(0x9EDC, 0xFFD1, 0xFFD2, 0xFFD3, 0xFFD4, 0xFFD5)
        Description = 'IL 9ED9 operand edit with ordered active integrity repair'
    }
}
$script:IlBootMarkerPrefix = 'ILBOOT_'

function Get-IlBootHashHex {
    param([string]$Path, [string]$Algorithm)
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        try { return ([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Get-IlBootBytes {
    param([string]$Path)
    return [IO.File]::ReadAllBytes($Path)
}

function Assert-IlBootRomIdentity {
    param([string]$Path, [int]$ExpectedLength, [string]$ExpectedSha1, [string]$ExpectedSha256, [string]$Label)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label is missing: $Path" }
    $length = (Get-Item -LiteralPath $Path).Length
    if ($length -ne $ExpectedLength) { throw "$Label length is $length, expected $ExpectedLength" }
    $actualSha1 = Get-IlBootHashHex $Path 'SHA1'
    $actualSha256 = Get-IlBootHashHex $Path 'SHA256'
    if ($actualSha1 -ine $ExpectedSha1) { throw "$Label SHA1 is $actualSha1, expected $ExpectedSha1" }
    if ($actualSha256 -ine $ExpectedSha256) { throw "$Label SHA256 is $actualSha256, expected $ExpectedSha256" }
    return [ordered]@{ length = $length; sha1 = $actualSha1; sha256 = $actualSha256 }
}

function Get-IlBootChangedOffsets {
    param([byte[]]$Original, [byte[]]$Variant)
    if ($Original.Length -ne $Variant.Length) { throw 'Cannot compare ROM images of different lengths' }
    $offsets = New-Object 'System.Collections.Generic.List[int]'
    for ($i = 0; $i -lt $Original.Length; $i++) {
        if ($Original[$i] -ne $Variant[$i]) { [void]$offsets.Add($i) }
    }
    return $offsets.ToArray()
}

function Format-IlBootOffset {
    param([int]$Offset)
    return ('{0:X4}' -f $Offset)
}

function Format-IlBootOffsets {
    param([int[]]$Offsets)
    return (($Offsets | ForEach-Object { Format-IlBootOffset $_ }) -join ',')
}

function Parse-IlBootOffsets {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    $result = @()
    foreach ($part in ($Text -split ',')) {
        $trim = $part.Trim()
        if ($trim -eq '') { continue }
        $result += [Convert]::ToInt32($trim, 16)
    }
    return [int[]]$result
}

function Assert-IlBootChangedOffsets {
    param([int[]]$Actual, [int[]]$Expected, [string]$Label)
    $actualSorted = @($Actual | Sort-Object)
    $expectedSorted = @($Expected | Sort-Object)
    if (($actualSorted -join ',') -ne ($expectedSorted -join ',')) {
        throw ("$Label changed offsets differ: actual {0}; expected {1}" -f (Format-IlBootOffsets $actualSorted), (Format-IlBootOffsets $expectedSorted))
    }
}

function New-IlBootRunDirectory {
    param([string]$RunDirectory)
    $run = [IO.Path]::GetFullPath($RunDirectory)
    if (Test-Path -LiteralPath $run) { throw "Use a fresh create-only run directory: $run" }
    New-Item -ItemType Directory -Path $run -ErrorAction Stop | Out-Null
    foreach ($name in @('roms/m4addr','cfg','nvram','inp','snap','comments','state','diff')) {
        New-Item -ItemType Directory -Path (Join-Path $run $name) -ErrorAction Stop | Out-Null
    }
    return $run
}

function Get-IlBootDirectoryFileCount {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path -PathType Container)) { return 0 }
    return @(Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue).Count
}

function Write-IlBootJson {
    param([string]$Path, $Object, [int]$Depth = 10)
    $json = ConvertTo-Json -InputObject $Object -Depth $Depth
    [IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function ConvertTo-IlBootArgumentString {
    param([string[]]$Arguments)
    $quoted = foreach ($arg in $Arguments) {
        $text = [string]$arg
        if ($text -match '[\s"]') {
            '"' + ($text.Replace('\','\\').Replace('"','\"')) + '"'
        } else {
            $text
        }
    }
    return ($quoted -join ' ')
}

function Invoke-IlBootProcess {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$WorkingDirectory,
        [string]$StandardOutputPath,
        [string]$StandardErrorPath,
        [int]$TimeoutSeconds
    )
    $argumentString = ConvertTo-IlBootArgumentString $Arguments
    $startUtc = [DateTime]::UtcNow
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = [IO.Path]::GetFullPath($FilePath)
    $startInfo.Arguments = $argumentString
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw "Failed to start process: $FilePath" }
    $processId = $process.Id
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = $false
    $exitCode = $null
    try {
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $timedOut = $true
            $taskkill = Join-Path $env:SystemRoot 'System32/taskkill.exe'
            & $taskkill /PID $processId /T /F 2>&1 | Out-Null
            $process.WaitForExit(30000) | Out-Null
        }
        if (-not $process.HasExited) {
            try { $process.Kill() } catch { }
            $process.WaitForExit(30000) | Out-Null
        }
        if ($process.HasExited) { $exitCode = $process.ExitCode }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        [IO.File]::WriteAllText($StandardOutputPath, $stdout, (New-Object System.Text.UTF8Encoding($false)))
        [IO.File]::WriteAllText($StandardErrorPath, $stderr, (New-Object System.Text.UTF8Encoding($false)))
    }
    finally {
        $stopwatch.Stop()
        if (-not $process.HasExited) {
            $taskkill = Join-Path $env:SystemRoot 'System32/taskkill.exe'
            & $taskkill /PID $processId /T /F 2>&1 | Out-Null
            $process.WaitForExit(30000) | Out-Null
            if ($process.HasExited) { $exitCode = $process.ExitCode }
        }
        $process.Dispose()
    }
    return [ordered]@{
        command_line = $argumentString
        start_utc = $startUtc.ToString('o')
        end_utc = [DateTime]::UtcNow.ToString('o')
        wall_seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
        timed_out = $timedOut
        exit_code = $exitCode
        process_id = $processId
    }
}

function Invoke-IlBootMain {
    foreach ($name in @('MameExecutable','RomDirectory','OriginalRom','VariantRom','Variant','RunDirectory')) {
        if ([string]::IsNullOrWhiteSpace((Get-Variable -Name $name -ValueOnly))) { throw "Missing required parameter: $name" }
    }
    if (!(Test-Path -LiteralPath $MameExecutable -PathType Leaf)) { throw "MAME executable is missing: $MameExecutable" }
    if (!(Test-Path -LiteralPath $RomDirectory -PathType Container)) { throw "MAME ROM directory is missing: $RomDirectory" }

    $originalIdentity = Assert-IlBootRomIdentity $OriginalRom $script:IlBootOriginalLength $script:IlBootOriginalSha1 $script:IlBootOriginalSha256 'original ROM'
    $expected = $script:IlBootVariants[$Variant]
    $variantIdentity = Assert-IlBootRomIdentity $VariantRom $script:IlBootOriginalLength $expected.Sha1 $expected.Sha256 "$Variant variant ROM"

    $originalBytes = Get-IlBootBytes $OriginalRom
    $variantBytes = Get-IlBootBytes $VariantRom
    $actualChanged = Get-IlBootChangedOffsets $originalBytes $variantBytes
    Assert-IlBootChangedOffsets $actualChanged $expected.ChangedOffsets "$Variant variant"
    $expectedChanged = [int[]]$expected.ChangedOffsets

    $run = New-IlBootRunDirectory $RunDirectory
    $runRom = Join-Path $run 'roms/m4addr/a6ls.p1'
    Copy-Item -LiteralPath $VariantRom -Destination $runRom -ErrorAction Stop
    $runCopyIdentity = Assert-IlBootRomIdentity $runRom $script:IlBootOriginalLength $expected.Sha1 $expected.Sha256 'isolated run ROM copy'

    $preRunEmpty = [ordered]@{}
    foreach ($name in @('cfg','nvram','inp','snap','comments','state','diff')) {
        $preRunEmpty[$name] = Get-IlBootDirectoryFileCount (Join-Path $run $name)
    }
    $preRunRomFiles = @(Get-ChildItem -LiteralPath (Join-Path $run 'roms/m4addr') -File | ForEach-Object { $_.Name } | Sort-Object)
    if (($preRunRomFiles -join ',') -ne 'a6ls.p1') { throw 'The isolated ROM directory does not contain exactly a6ls.p1 before launch' }
    foreach ($key in $preRunEmpty.Keys) {
        if ($preRunEmpty[$key] -ne 0) { throw "Pre-run directory $key is not empty" }
    }
    $preRunTopLevel = @(Get-ChildItem -LiteralPath $run -Force | ForEach-Object { $_.Name } | Sort-Object)

    $mameVersionOutput = Join-Path $run 'mame-version.txt'
    $mameVersionError = Join-Path $run 'mame-version.err.txt'
    $versionRun = Invoke-IlBootProcess $MameExecutable @('-version') $run $mameVersionOutput $mameVersionError 60
    if ($versionRun.timed_out -or $versionRun.exit_code -ne 0) { throw "MAME -version failed: exit=$($versionRun.exit_code) timed_out=$($versionRun.timed_out)" }
    $mameVersion = ((Get-Content -LiteralPath $mameVersionOutput -Raw).Trim() -split "\r?\n")[0]
    if ($mameVersion -notmatch '^0\.281\b') { throw "Unexpected MAME version: $mameVersion" }

    $commands = @(
        'bpset 7cd1,1,{printf "ILBOOT_RESET pc=%04X s=%04X cc=%02X\n",pc,s,cc;go}',
        'bpset 6750,1,{printf "ILBOOT_INIT_ENTRY pc=%04X u=%04X\n",pc,u;go}',
        'bpset 66a5,1,{printf "ILBOOT_ROM_CHECK_ENTRY pc=%04X u=%04X gate719b=%02X\n",pc,u,b@0x719b;go}',
        'bpset 66db,1,{printf "ILBOOT_ROM_VERIFY_ENTRY pc=%04X u=%04X expected=%02X%02X%02X%02X%02X start=%04X end=%04X error=%02X\n",pc,u,b@(w@(u+1)),b@(w@(u+1)+1),b@(w@(u+1)+2),b@(w@(u+1)+3),b@(w@(u+1)+4),w@(u+3),w@(u+5),b@(u+7);go}',
        'bpset 66f3,1,{printf "ILBOOT_SUM_XOR sum=%02X xor=%02X\n",a,b;go}',
        'bpset 6715,1,{printf "ILBOOT_ROTATE_ADD value=%02X\n",a;go}',
        'bpset 674c,1,{printf "ILBOOT_ROTATE_SUB_XOR a=%02X b=%02X\n",a,b;go}',
        'bpset 674f,1,{printf "ILBOOT_ROM_VERIFY_FAILED error=%02X\n",b}',
        'bpset 677e,1,{printf "ILBOOT_ROM_CHECK_RETURN pc=%04X y=%04X u=%04X\n",pc,y,u;go}',
        'bpset 67b3,1,{printf "ILBOOT_INIT_TAIL_JMP pc=%04X y=%04X u=%04X\n",pc,y,u;go}',
        'bpset 3b1a,1,{printf "ILBOOT_INIT_TAIL_ENTRY pc=%04X y=%04X u=%04X\n",pc,y,u;go}',
        'bpset 7cf6,1,{printf "ILBOOT_VM_CALL pc=%04X x=%04X y=%04X u=%04X\n",pc,x,y,u;go}',
        'bpset 76c7,1,{printf "ILBOOT_VM_ENTRY pc=%04X x=%04X y=%04X u=%04X s=%04X first_word=%04X\n",pc,x,y,u,s,w@(x)}',
        'go',
        'printf "ILBOOT_CAPTURE_END pc=%04X x=%04X y=%04X u=%04X s=%04X first_word=%04X\n",pc,x,y,u,s,w@(x)',
        'quit'
    )
    $debuggerPath = Join-Path $run 'debugger.cmd'
    [IO.File]::WriteAllLines($debuggerPath, $commands, (New-Object System.Text.UTF8Encoding($false)))

    $mameArgs = @(
        'm4addr','-noreadconfig',
        '-rompath',((Join-Path $run 'roms')+';'+$RomDirectory),
        '-cfg_directory',(Join-Path $run 'cfg'),
        '-nvram_directory',(Join-Path $run 'nvram'),
        '-input_directory',(Join-Path $run 'inp'),
        '-snapshot_directory',(Join-Path $run 'snap'),
        '-comment_directory',(Join-Path $run 'comments'),
        '-state_directory',(Join-Path $run 'state'),
        '-diff_directory',(Join-Path $run 'diff'),
        '-debug','-debugger','windows',
        '-debugscript',$debuggerPath,
        '-debuglog','-video','none','-sound','none','-window',
        '-skip_gameinfo','-nothrottle',
        '-seconds_to_run',[string]$SecondsToRun
    )
    Write-IlBootJson (Join-Path $run 'arguments.json') @($mameArgs) 6

    $argumentsRecord = [ordered]@{
        arguments = @($mameArgs)
        working_directory = $run
        emulated_seconds_limit = $SecondsToRun
        wall_timeout_seconds = $WallTimeoutSeconds
    }
    Write-IlBootJson (Join-Path $run 'command.json') $argumentsRecord 8

    $provenance = [ordered]@{
        mode = 'Natural IL integrity startup observation'
        classification = 'Natural emulator execution from a fresh isolated directory and absent NVRAM/configuration; read-only debugger breakpoints and printf only; no PC, RAM, register, input or ROM injection'
        variant = $Variant
        variant_description = $expected.Description
        original_rom_sha1 = $originalIdentity.sha1
        original_rom_sha256 = $originalIdentity.sha256
        expected_variant_sha1 = $expected.Sha1
        expected_variant_sha256 = $expected.Sha256
        run_rom_sha1 = $runCopyIdentity.sha1
        run_rom_sha256 = $runCopyIdentity.sha256
        expected_fields = $expected.Fields
        expected_changed_offsets = (Format-IlBootOffsets $expectedChanged)
        actual_changed_offsets = (Format-IlBootOffsets $actualChanged)
        starting_nvram = 'absent'
        starting_configuration = 'absent; -noreadconfig'
        user_inputs = 'none'
        configuration_read_disabled = $true
        working_directory = $run
        mame_executable = [IO.Path]::GetFullPath($MameExecutable)
        mame_sha256 = Get-IlBootHashHex $MameExecutable 'SHA256'
        mame_version = $mameVersion
        mame_version_exit_code = $versionRun.exit_code
        mame_version_wall_seconds = $versionRun.wall_seconds
        seconds_to_run = $SecondsToRun
        wall_timeout_seconds = $WallTimeoutSeconds
        pre_run_empty_directory_file_counts = $preRunEmpty
        pre_run_rom_directory_files = $preRunRomFiles
        pre_run_top_level_entries = $preRunTopLevel
        capture_script = 'tools/Capture-IlIntegrityStartup.ps1'
        marker_prefix = $script:IlBootMarkerPrefix
        observation_instrumentation = 'read-only MAME debugger bpset/printf/go/quit at reset, init, checker, expected/computed field sites, return, init tail, VM call and first VM entry; no writes'
    }
    Write-IlBootJson (Join-Path $run 'provenance.json') $provenance 10

    $consolePath = Join-Path $run 'console.txt'
    $consoleErrorPath = Join-Path $run 'console.err.txt'
    $runResult = Invoke-IlBootProcess $MameExecutable $mameArgs $run $consolePath $consoleErrorPath $WallTimeoutSeconds
    Set-Content -LiteralPath (Join-Path $run 'exit-code.txt') -Value ([string]$runResult.exit_code) -NoNewline
    Write-IlBootJson (Join-Path $run 'timing.json') $runResult 8

    $logPath = Join-Path $run 'debug.log'
    if (!(Test-Path -LiteralPath $logPath -PathType Leaf)) { throw "MAME did not produce debug.log; exit=$($runResult.exit_code) timed_out=$($runResult.timed_out)" }
    $log = Get-Content -LiteralPath $logPath -Raw
    $postRunCopyIdentity = Assert-IlBootRomIdentity $runRom $script:IlBootOriginalLength $expected.Sha1 $expected.Sha256 'isolated run ROM copy after execution'

    $verifyLine = [regex]::Match($log, '(?m)^ILBOOT_ROM_VERIFY_ENTRY .*expected=([0-9A-Fa-f]+)')
    $vmEntryLine = [regex]::Match($log, '(?m)^ILBOOT_VM_ENTRY pc=76C7 .*first_word=([0-9A-Fa-f]+)')
    $observation = [ordered]@{
        variant = $Variant
        exit_code = $runResult.exit_code
        timed_out = $runResult.timed_out
        wall_seconds = $runResult.wall_seconds
        emulated_seconds_limit = $SecondsToRun
        original_rom_sha1 = $originalIdentity.sha1
        original_rom_sha256 = $originalIdentity.sha256
        expected_variant_sha1 = $expected.Sha1
        expected_variant_sha256 = $expected.Sha256
        run_rom_sha1_after = $postRunCopyIdentity.sha1
        run_rom_sha256_after = $postRunCopyIdentity.sha256
        rom_unchanged = ($postRunCopyIdentity.sha1 -ieq $expected.Sha1 -and $postRunCopyIdentity.sha256 -ieq $expected.Sha256)
        expected_fields = $(if ($verifyLine.Success) { $verifyLine.Groups[1].Value.ToUpperInvariant() } else { $null })
        first_stream_word = $(if ($vmEntryLine.Success) { $vmEntryLine.Groups[1].Value.ToUpperInvariant() } else { $null })
        debug_log_sha256 = Get-IlBootHashHex $logPath 'SHA256'
        console_sha256 = Get-IlBootHashHex $consolePath 'SHA256'
        console_error_sha256 = Get-IlBootHashHex $consoleErrorPath 'SHA256'
        reset_reached = [regex]::IsMatch($log, '(?m)^ILBOOT_RESET pc=7CD1\b')
        init_reached = [regex]::IsMatch($log, '(?m)^ILBOOT_INIT_ENTRY pc=6750\b')
        check_reached = [regex]::IsMatch($log, '(?m)^ILBOOT_ROM_CHECK_ENTRY pc=66A5\b')
        verify_reached = [regex]::IsMatch($log, '(?m)^ILBOOT_ROM_VERIFY_ENTRY pc=66DB\b')
        sum_reached = [regex]::IsMatch($log, '(?m)^ILBOOT_SUM_XOR ')
        rotate_add_reached = [regex]::IsMatch($log, '(?m)^ILBOOT_ROTATE_ADD ')
        rotate_sub_reached = [regex]::IsMatch($log, '(?m)^ILBOOT_ROTATE_SUB_XOR ')
        failure_reached = [regex]::IsMatch($log, '(?m)^ILBOOT_ROM_VERIFY_FAILED ')
        checksum_returned = [regex]::IsMatch($log, '(?m)^ILBOOT_ROM_CHECK_RETURN pc=677E\b')
        init_tail_jmp_reached = [regex]::IsMatch($log, '(?m)^ILBOOT_INIT_TAIL_JMP pc=67B3\b')
        init_tail_entry_reached = [regex]::IsMatch($log, '(?m)^ILBOOT_INIT_TAIL_ENTRY pc=3B1A\b')
        vm_call_reached = [regex]::IsMatch($log, '(?m)^ILBOOT_VM_CALL pc=7CF6\b')
        vm_entry_reached = [regex]::IsMatch($log, '(?m)^ILBOOT_VM_ENTRY pc=76C7\b')
        stopped_at_vm_entry = [regex]::IsMatch($log, '(?m)^ILBOOT_CAPTURE_END pc=76C7\b')
        stopped_at_failure = [regex]::IsMatch($log, '(?m)^ILBOOT_CAPTURE_END pc=674F\b')
    }
    Write-IlBootJson (Join-Path $run 'observation.json') $observation 8

    if ($runResult.timed_out) { throw "MAME exceeded the ${WallTimeoutSeconds}s wall cap; capture preserved at $run" }
    if ($runResult.exit_code -ne 0) { throw "MAME exited $($runResult.exit_code); inspect $consolePath and $run" }
    if (!$observation.rom_unchanged) { throw 'Run ROM copy changed during capture' }
    Write-Output $run
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-IlBootMain
}

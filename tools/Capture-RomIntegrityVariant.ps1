param(
    [Parameter(Mandatory=$true)][string]$MameExecutable,
    [Parameter(Mandatory=$true)][string]$RomDirectory,
    [Parameter(Mandatory=$true)][string]$RomPath,
    [Parameter(Mandatory=$true)][ValidateSet('Original','UnrepairedPatch','RepairedPatch')][string]$Variant,
    [Parameter(Mandatory=$true)][string]$OriginalRom,
    [Parameter(Mandatory=$true)][string]$ExpectedRomSha1,
    [Parameter(Mandatory=$true)][string]$ExpectedRomSha256,
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [ValidateRange(1,60)][int]$SecondsToRun = 30
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

$OriginalSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$actualOriginalSha1 = Get-HashHex $OriginalRom 'SHA1'
if ($actualOriginalSha1 -ne $OriginalSha1) { throw "Unexpected original ROM SHA1: $actualOriginalSha1" }
$actualRomLength = (Get-Item -LiteralPath $RomPath).Length
if ($actualRomLength -ne 65536) { throw "Unexpected variant ROM length: $actualRomLength" }
$actualRomSha1 = Get-HashHex $RomPath 'SHA1'
$actualRomSha256 = Get-HashHex $RomPath 'SHA256'
if ($actualRomSha1 -ine $ExpectedRomSha1) { throw "Unexpected variant ROM SHA1: $actualRomSha1" }
if ($actualRomSha256 -ine $ExpectedRomSha256) { throw "Unexpected variant ROM SHA256: $actualRomSha256" }
if ($Variant -eq 'Original' -and $actualRomSha1 -ne $OriginalSha1) { throw 'Original variant is not the original image' }
if ($Variant -ne 'Original' -and $actualRomSha1 -eq $OriginalSha1) { throw 'Modified variant has original identity' }

$run = [IO.Path]::GetFullPath($RunDirectory)
if (Test-Path -LiteralPath $run) { throw 'Use a fresh isolated directory' }
New-Item -ItemType Directory -Path $run | Out-Null
foreach ($name in @('roms/m4addr','cfg','nvram','inp','snap','comments','state','diff')) {
    New-Item -ItemType Directory (Join-Path $run $name) | Out-Null
}
$runRom = Join-Path $run 'roms/m4addr/a6ls.p1'
Copy-Item -LiteralPath $RomPath -Destination $runRom
$runRomSha1 = Get-HashHex $runRom 'SHA1'
$runRomSha256 = Get-HashHex $runRom 'SHA256'
if ($runRomSha1 -ine $ExpectedRomSha1 -or $runRomSha256 -ine $ExpectedRomSha256) { throw 'Copied variant ROM identity changed' }

$commands = @(
    'bpset 7cd1,1,{printf "VARIANT_RESET pc=%04X s=%04X cc=%02X\n",pc,s,cc;go}',
    'bpset 6750,1,{printf "VARIANT_INIT_ENTRY pc=%04X u=%04X\n",pc,u;go}',
    'bpset 66a5,1,{printf "VARIANT_ROM_CHECK_ENTRY pc=%04X u=%04X gate719b=%02X\n",pc,u,b@0x719b;go}',
    'bpset 66db,1,{printf "VARIANT_ROM_VERIFY_ENTRY pc=%04X u=%04X expected=%02X%02X%02X%02X%02X start=%04X end=%04X error=%02X\n",pc,u,b@(w@(u+1)),b@(w@(u+1)+1),b@(w@(u+1)+2),b@(w@(u+1)+3),b@(w@(u+1)+4),w@(u+3),w@(u+5),b@(u+7);go}',
    'bpset 66f3,1,{printf "VARIANT_SUM_XOR sum=%02X xor=%02X\n",a,b;go}',
    'bpset 6715,1,{printf "VARIANT_ROTATE_ADD value=%02X\n",a;go}',
    'bpset 674c,1,{printf "VARIANT_ROTATE_SUB_XOR a=%02X b=%02X\n",a,b;go}',
    'bpset 674f,1,{printf "VARIANT_ROM_VERIFY_FAILED error=%02X\n",b}',
    'bpset 677e,1,{printf "VARIANT_ROM_CHECK_RETURN pc=%04X y=%04X u=%04X\n",pc,y,u;go}',
    'bpset 67b3,1,{printf "VARIANT_INIT_TAIL_JMP pc=%04X y=%04X u=%04X\n",pc,y,u;go}',
    'bpset 3b1a,1,{printf "VARIANT_INIT_TAIL_ENTRY pc=%04X y=%04X u=%04X\n",pc,y,u;go}',
    'bpset 7cf6,1,{printf "VARIANT_VM_CALL pc=%04X x=%04X y=%04X u=%04X\n",pc,x,y,u;go}',
    'bpset 76c7,1,{printf "VARIANT_VM_ENTRY pc=%04X x=%04X y=%04X u=%04X s=%04X\n",pc,x,y,u,s}',
    'go',
    'printf "VARIANT_CAPTURE_END pc=%04X x=%04X y=%04X u=%04X\n",pc,x,y,u',
    'quit'
)
$commands | Set-Content (Join-Path $run 'debugger.cmd')

$mameArgs = @(
    'm4addr','-noreadconfig',
    '-rompath',((Join-Path $run 'roms')+';'+$RomDirectory),
    '-cfg_directory',"$run/cfg",
    '-nvram_directory',"$run/nvram",
    '-input_directory',"$run/inp",
    '-snapshot_directory',"$run/snap",
    '-comment_directory',"$run/comments",
    '-state_directory',"$run/state",
    '-diff_directory',"$run/diff",
    '-debug','-debugger','windows',
    '-debugscript',"$run/debugger.cmd",
    '-debuglog','-video','none','-sound','none','-window',
    '-skip_gameinfo','-nothrottle',
    '-seconds_to_run',$SecondsToRun
)
$mameArgs | ConvertTo-Json | Set-Content (Join-Path $run 'arguments.json')
@{
    mode = 'Natural ROM integrity variant reset'
    classification = 'Natural emulator execution; fresh isolated directory and absent NVRAM/configuration; no PC, RAM, input or ROM injection; variant identity checked before and after the run'
    variant = $Variant
    mame_sha256 = Get-HashHex $MameExecutable 'SHA256'
    original_rom_sha1 = $actualOriginalSha1
    expected_rom_sha1 = $ExpectedRomSha1
    expected_rom_sha256 = $ExpectedRomSha256
    run_rom_sha1 = $runRomSha1
    run_rom_sha256 = $runRomSha256
    starting_nvram = 'absent'
    starting_configuration = 'absent; -noreadconfig'
    user_inputs = 'none'
} | ConvertTo-Json | Set-Content (Join-Path $run 'provenance.json')

Push-Location $run
try {
    $ErrorActionPreference = 'Continue'
    & $MameExecutable @mameArgs *> console.txt
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $exitCode | Set-Content exit-code.txt
}
finally { Pop-Location }

$postRomSha1 = Get-HashHex $runRom 'SHA1'
$postRomSha256 = Get-HashHex $runRom 'SHA256'
$logPath = Join-Path $run 'debug.log'
$log = Get-Content -LiteralPath $logPath -Raw
$vmEntry = [regex]::Match($log, '(?m)^VARIANT_VM_ENTRY pc=76C7 x=([0-9A-Fa-f]+)\b')
$expectedRead = [regex]::Match($log, '(?m)^VARIANT_ROM_VERIFY_ENTRY .*expected=([0-9A-Fa-f]+)')
@{
    exit_code = $exitCode
    variant = $Variant
    original_rom_sha1 = $actualOriginalSha1
    expected_rom_sha1 = $ExpectedRomSha1
    expected_rom_sha256 = $ExpectedRomSha256
    run_rom_sha1_after = $postRomSha1
    run_rom_sha256_after = $postRomSha256
    rom_unchanged = ($postRomSha1 -ieq $ExpectedRomSha1 -and $postRomSha256 -ieq $ExpectedRomSha256)
    expected_fields = $(if ($expectedRead.Success) { $expectedRead.Groups[1].Value.ToUpperInvariant() } else { $null })
    debug_log_sha256 = Get-HashHex $logPath 'SHA256'
    console_sha256 = Get-HashHex (Join-Path $run 'console.txt') 'SHA256'
    reset_reached = $log.Contains('VARIANT_RESET pc=7CD1')
    init_reached = $log.Contains('VARIANT_INIT_ENTRY pc=6750')
    check_reached = $log.Contains('VARIANT_ROM_CHECK_ENTRY pc=66A5')
    verify_reached = $log.Contains('VARIANT_ROM_VERIFY_ENTRY pc=66DB')
    sum_reached = $log.Contains('VARIANT_SUM_XOR ')
    rotate_add_reached = $log.Contains('VARIANT_ROTATE_ADD ')
    rotate_sub_reached = $log.Contains('VARIANT_ROTATE_SUB_XOR ')
    failure_reached = [regex]::IsMatch($log, '(?m)^VARIANT_ROM_VERIFY_FAILED ')
    checksum_returned = $log.Contains('VARIANT_ROM_CHECK_RETURN pc=677E')
    init_tail_jmp_reached = $log.Contains('VARIANT_INIT_TAIL_JMP pc=67B3')
    init_tail_entry_reached = $log.Contains('VARIANT_INIT_TAIL_ENTRY pc=3B1A')
    vm_call_reached = $log.Contains('VARIANT_VM_CALL pc=7CF6')
    vm_entry_reached = $vmEntry.Success
    stopped_at_vm_entry = [regex]::IsMatch($log, '(?m)^VARIANT_CAPTURE_END pc=76C7\b')
    stopped_at_failure = [regex]::IsMatch($log, '(?m)^VARIANT_CAPTURE_END pc=674F\b')
    initial_stream_pointer = $(if ($vmEntry.Success) { $vmEntry.Groups[1].Value.ToUpperInvariant() } else { $null })
} | ConvertTo-Json | Set-Content (Join-Path $run 'observation.json')

if ($exitCode -ne 0) { throw "MAME exited $exitCode; inspect $run/console.txt" }
if ($postRomSha1 -ine $ExpectedRomSha1 -or $postRomSha256 -ine $ExpectedRomSha256) { throw 'Run ROM copy changed during capture' }
Write-Output $run

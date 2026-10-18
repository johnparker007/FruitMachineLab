param(
    [Parameter(Mandatory=$true)][string]$MameExecutable,
    [Parameter(Mandatory=$true)][string]$RomDirectory,
    [Parameter(Mandatory=$true)][string]$OriginalRom,
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [ValidateRange(1,60)][int]$SecondsToRun = 10
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

$expectedSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$actualSha1 = Get-HashHex $OriginalRom 'SHA1'
if ($actualSha1 -ne $expectedSha1) { throw "Unexpected original ROM SHA1: $actualSha1" }

$run = [IO.Path]::GetFullPath($RunDirectory)
if (Test-Path -LiteralPath $run) { throw 'Use a fresh isolated directory' }
New-Item -ItemType Directory -Path $run | Out-Null
foreach ($name in @('roms/m4addr','cfg','nvram','inp','snap','comments','state','diff')) {
    New-Item -ItemType Directory (Join-Path $run $name) | Out-Null
}
$runRom = Join-Path $run 'roms/m4addr/a6ls.p1'
Copy-Item -LiteralPath $OriginalRom -Destination $runRom
$runRomSha1 = Get-HashHex $runRom 'SHA1'
if ($runRomSha1 -ne $expectedSha1) { throw "Copied ROM SHA1 changed: $runRomSha1" }

$commands = @(
    'bpset 7cd1,1,{printf "BOOT_RESET pc=%04X s=%04X cc=%02X\n",pc,s,cc;go}',
    'bpset 6750,1,{printf "BOOT_INIT_ENTRY pc=%04X u=%04X\n",pc,u;go}',
    'bpset 66a5,1,{printf "BOOT_ROM_CHECK_ENTRY pc=%04X u=%04X gate719b=%02X\n",pc,u,b@0x719b;go}',
    'bpset 66db,1,{printf "BOOT_ROM_VERIFY_ENTRY pc=%04X u=%04X expected=%02X%02X%02X%02X%02X start=%04X end=%04X error=%02X\n",pc,u,b@(w@(u+1)),b@(w@(u+1)+1),b@(w@(u+1)+2),b@(w@(u+1)+3),b@(w@(u+1)+4),w@(u+3),w@(u+5),b@(u+7);go}',
    'bpset 66f3,1,{printf "BOOT_SUM_XOR sum=%02X xor=%02X\n",a,b;go}',
    'bpset 6715,1,{printf "BOOT_ROTATE_ADD value=%02X\n",a;go}',
    'bpset 674c,1,{printf "BOOT_ROTATE_SUB_XOR a=%02X b=%02X\n",a,b;go}',
    'bpset 674d,1,{printf "BOOT_ROM_VERIFY_FAILED error=%02X\n",b}',
    'bpset 677e,1,{printf "BOOT_ROM_CHECK_RETURN pc=%04X y=%04X u=%04X\n",pc,y,u}',
    'go',
    'printf "BOOT_CAPTURE_END pc=%04X y=%04X\n",pc,y',
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
    mode = 'Natural original reset boot'
    classification = 'Natural emulator execution; fresh isolated directory and absent NVRAM/configuration; no PC, RAM, input or ROM injection'
    mame_sha256 = Get-HashHex $MameExecutable 'SHA256'
    original_rom_sha1 = $actualSha1
    run_rom_sha1 = $runRomSha1
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
$logPath = Join-Path $run 'debug.log'
$log = Get-Content -LiteralPath $logPath -Raw
@{
    exit_code = $exitCode
    original_rom_sha1 = $actualSha1
    run_rom_sha1_after = $postRomSha1
    rom_unchanged = ($postRomSha1 -eq $expectedSha1)
    debug_log_sha256 = Get-HashHex $logPath 'SHA256'
    console_sha256 = Get-HashHex (Join-Path $run 'console.txt') 'SHA256'
    reset_reached = $log.Contains('BOOT_RESET pc=7CD1')
    init_reached = $log.Contains('BOOT_INIT_ENTRY pc=6750')
    rom_check_reached = $log.Contains('BOOT_ROM_CHECK_ENTRY pc=66A5')
    rom_verify_reached = $log.Contains('BOOT_ROM_VERIFY_ENTRY pc=66DB')
    rom_check_returned = $log.Contains('BOOT_ROM_CHECK_RETURN pc=677E')
    stopped_at_checksum_return = [regex]::IsMatch($log, '(?m)^BOOT_CAPTURE_END pc=677E')
    verify_failed = [regex]::IsMatch($log, '(?m)^BOOT_ROM_VERIFY_FAILED ')
} | ConvertTo-Json | Set-Content (Join-Path $run 'observation.json')

if ($exitCode -ne 0) { throw "MAME exited $exitCode; inspect $run/console.txt" }
if ($postRomSha1 -ne $expectedSha1) { throw 'Run ROM copy changed during capture' }
Write-Output $run

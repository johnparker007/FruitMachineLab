param(
    [Parameter(Mandatory=$true)][string]$MameExecutable,
    [Parameter(Mandatory=$true)][string]$RomDirectory,
    [Parameter(Mandatory=$true)][string]$PatchedRom,
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [ValidateSet('Lookup','Boot')][string]$Mode = 'Lookup',
    [ValidateRange(0,255)][int]$ExpectedValue = 12
)
$ErrorActionPreference = 'Stop'
$run = [IO.Path]::GetFullPath($RunDirectory)
if (Test-Path $run) { throw 'Use a fresh isolated directory' }
New-Item -ItemType Directory $run | Out-Null
foreach ($name in @('roms/m4addr','cfg','nvram','inp','snap','comments','state','diff')) { New-Item -ItemType Directory (Join-Path $run $name) | Out-Null }
Copy-Item -LiteralPath $PatchedRom -Destination (Join-Path $run 'roms/m4addr/a6ls.p1')
$commands = @('printf "ROM_PATCH_TABLE value=%02X\n",b@75be')
if ($Mode -eq 'Lookup') {
    # Synthetic isolated invocation of the original VM lookup, not a played game.
    $commands += @('bpset fc,y==0xc708','w@f8=w@7927;w@fa=w@7929;w@fc=w@792b;w@fe=w@792d','pc=0xfc;y=0xc6fe;u=0x600;s=0x700;dp=0;cc=0x50;w@f4=0x500;b@501=1','go','printf "ROM_PATCH_LOOKUP y=%04X top=%04X\n",y,w@u','quit')
} else {
    # Reach the original initial threaded stream from reset; no RAM/PC injection.
    $commands += @('bpset fc,y==0xfdf0,{printf "ROM_PATCH_BOOT initial_stream=%04X\n",y;go}','gtime #12000','printf "ROM_PATCH_BOOT_END pc=%04X y=%04X\n",pc,y','save final-ram.bin,0,800','quit')
}
$commands | Set-Content (Join-Path $run 'debugger.cmd')
$mameArgs = @('m4addr','-noreadconfig','-rompath',((Join-Path $run 'roms')+';'+$RomDirectory),'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','15')
$mameArgs | ConvertTo-Json | Set-Content (Join-Path $run 'arguments.json')
@{mode=$Mode;classification= $(if($Mode -eq 'Lookup'){'Synthetic original-VM invocation on patched ROM'}else{'Reset boot observation, isolated fresh NVRAM'});mame_sha256=(Get-FileHash $MameExecutable).Hash;rom_sha256=(Get-FileHash $PatchedRom).Hash} | ConvertTo-Json | Set-Content (Join-Path $run 'provenance.json')
Push-Location $run
try {
    # MAME emits expected modified-ROM checksum warnings on stderr.
    $ErrorActionPreference = 'Continue'
    & $MameExecutable @mameArgs *> console.txt
    $exitCode=$LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $exitCode | Set-Content exit-code.txt
}
finally { Pop-Location }
if ($exitCode -ne 0) { throw "MAME exited $exitCode; inspect $run/console.txt" }
$log = Get-Content (Join-Path $run 'debug.log') -Raw
if (!$log.Contains(('ROM_PATCH_TABLE value={0:X2}' -f $ExpectedValue))) { throw 'MAME did not load the expected table' }
if ($Mode -eq 'Lookup' -and !$log.Contains(('ROM_PATCH_LOOKUP y=C708 top={0:X4}' -f $ExpectedValue))) { throw 'Original VM lookup did not reach the expected result' }
@{mode=$Mode;table_value=$ExpectedValue;lookup_verified=($Mode -eq 'Lookup');initial_stream_reached=$log.Contains('ROM_PATCH_BOOT initial_stream=FDF0');debug_log_sha256=(Get-FileHash (Join-Path $run 'debug.log')).Hash} | ConvertTo-Json | Set-Content (Join-Path $run 'observation.json')
Write-Output $run

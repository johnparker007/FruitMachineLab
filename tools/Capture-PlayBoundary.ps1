param(
    [Parameter(Mandatory=$true)][string]$MameExecutable,
    [Parameter(Mandatory=$true)][string]$RomDirectory,
    [Parameter(Mandatory=$true)][string]$OriginalRom,
    [Parameter(Mandatory=$true)][string]$RomPath,
    [Parameter(Mandatory=$true)][ValidateSet('Original','Repaired')][string]$Variant,
    [Parameter(Mandatory=$true)][string]$ExpectedRomSha1,
    [Parameter(Mandatory=$true)][string]$ExpectedRomSha256,
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [Parameter(Mandatory=$true)][ValidateSet('None','Coin','CoinStart')][string]$InputMode,
    [ValidateRange(1,180)][int]$SecondsToRun = 90,
    [double]$CoinAtSeconds = 35.0,
    [double]$StartAtSeconds = 37.0
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
$actualLength = (Get-Item -LiteralPath $RomPath).Length
if ($actualLength -ne 65536) { throw "Unexpected variant ROM length: $actualLength" }
$actualSha1 = Get-HashHex $RomPath 'SHA1'
$actualSha256 = Get-HashHex $RomPath 'SHA256'
if ($actualSha1 -ine $ExpectedRomSha1) { throw "Unexpected variant ROM SHA1: $actualSha1" }
if ($actualSha256 -ine $ExpectedRomSha256) { throw "Unexpected variant ROM SHA256: $actualSha256" }
if ($Variant -eq 'Original' -and $actualSha1 -ne $OriginalSha1) { throw 'Original variant is not the original image' }
if ($Variant -eq 'Repaired' -and $actualSha1 -eq $OriginalSha1) { throw 'Repaired variant has original identity' }

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
    'bpset 7cd1,1,{printf "PLAY_RESET pc=%04X s=%04X cc=%02X cycle=%016X\n",pc,s,cc,totalcycles;go}',
    'bpset 6750,1,{printf "PLAY_INIT_ENTRY pc=%04X u=%04X cycle=%016X\n",pc,u,totalcycles;go}',
    'bpset 677e,1,{printf "PLAY_ROM_CHECK_RETURN pc=%04X y=%04X u=%04X cycle=%016X\n",pc,y,u,totalcycles;go}',
    'bpset 76c7,1,{printf "PLAY_VM_ENTRY pc=%04X x=%04X y=%04X u=%04X s=%04X cycle=%016X\n",pc,x,y,u,s,totalcycles;temp0=1;go}',
    'bpset 496a,temp0==1 && temp1==0,{printf "PLAY_MAIN_FIRST_NATIVE pc=%04X x=%04X y=%04X u=%04X cycle=%016X\n",pc,x,y,u,totalcycles;temp1=1;go}',
    'bpset 4ac0,temp0==1 && temp2==0,{printf "PLAY_ATTRACT_LAMP_RANGE pc=%04X x=%04X y=%04X u=%04X credit2f0=%02X cycle=%016X\n",pc,x,y,u,b@0x2f0,totalcycles;temp2=1;go}',
    'bpset 482f,temp0==1 && temp3==0,{printf "PLAY_STATUS_SERVICE pc=%04X x=%04X y=%04X u=%04X credit2f0=%02X cycle=%016X\n",pc,x,y,u,b@0x2f0,totalcycles;temp3=1;go}',
    'bpset 2cb3,temp0==1 && temp4==0,{printf "PLAY_LAMP_STATUS_UPDATE pc=%04X x=%04X y=%04X u=%04X credit2f0=%02X cycle=%016X\n",pc,x,y,u,b@0x2f0,totalcycles;temp4=1;go}',
    'bpset 2beb,temp0==1 && temp5==0,{printf "PLAY_REEL_REFRESH pc=%04X x=%04X y=%04X u=%04X cycle=%016X\n",pc,x,y,u,totalcycles;temp5=1;go}',
    'bpset 171d,temp0==1 && temp6==0,{printf "PLAY_LAMP_INIT pc=%04X x=%04X y=%04X u=%04X credit2f0=%02X cycle=%016X\n",pc,x,y,u,b@0x2f0,totalcycles;temp6=1;go}',
    'bpset 2892,temp0==1 && temp7==0,{printf "PLAY_STARTUP_LAMP_SENSE pc=%04X x=%04X y=%04X u=%04X cycle=%016X\n",pc,x,y,u,totalcycles;temp7=1;go}'
)
if ($InputMode -eq 'Coin') {
    $commands += 'bpset 67e8,b==0x12,{printf "PLAY_PREPLAY_READY cond=%02X credit2f0=%02X pc=%04X x=%04X y=%04X u=%04X cycle=%016X\n",b,b@0x2f0,pc,x,y,u,totalcycles;quit}'
} elseif ($InputMode -eq 'CoinStart') {
    $commands += @(
        'bpset 67e8,b==0x12 && temp8==0,{printf "PLAY_PREPLAY_READY cond=%02X credit2f0=%02X pc=%04X x=%04X y=%04X u=%04X cycle=%016X\n",b,b@0x2f0,pc,x,y,u,totalcycles;temp8=1;go}',
        'bpset 61d6,temp9==0,{printf "PLAY_PAID_SPIN_SETUP pc=%04X x=%04X y=%04X u=%04X cycle=%016X\n",pc,x,y,u,totalcycles;temp9=2;go}',
        'wpset 75bd,7,r,temp9==2,{printf "PLAY_AWARD_TABLE_READ address=%04X value=%02X credit2f0=%02X cycle=%016X\n",wpaddr,wpdata,b@0x2f0,totalcycles;quit}'
    )
}
$commands += @('go','printf "PLAY_CAPTURE_END pc=%04X x=%04X y=%04X u=%04X cycle=%016X\n",pc,x,y,u,totalcycles','quit')
$commands | Set-Content (Join-Path $run 'debugger.cmd')

$inputPlan = $null
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
if ($InputMode -ne 'None') {
    $coinLast = $CoinAtSeconds + 0.05
    $startFirst = if ($InputMode -eq 'CoinStart') { $StartAtSeconds } else { 1000000.0 }
    $startLast = if ($InputMode -eq 'CoinStart') { $StartAtSeconds + 0.20 } else { 1000000.20 }
    $lua = @"
local m=manager.machine
local cpu=m.devices[":maincpu"]
local mem=cpu.spaces["program"]
local log=assert(io.open("input-levels.csv","w"))
log:write("frame,t,aux2,black2,credit2f0,coin_active,start_active\n")
local auxFields={}
for _,mask in ipairs({1,2,4,8,16,32,64,128}) do auxFields[mask]=assert(m.ioport.ports[":AUX2"]:field(mask)) end
local blackFields={}
for _,mask in ipairs({1,2,4,8,16,32,64,128}) do blackFields[mask]=assert(m.ioport.ports[":BLACK2"]:field(mask)) end
local actions=assert(io.open("actions.csv","w"))
actions:write("first_t,last_t,port,mask,reason\n")
local frame=0
local coinFirst=$CoinAtSeconds
local coinLast=$coinLast
local startFirst=$startFirst
local startLast=$startLast
local coinLogged=false
local startLogged=false
emu.register_frame_done(function()
 local t=m.time:as_double()
 frame=frame+1
 local coin=t>=coinFirst and t<coinLast
 local start=t>=startFirst and t<startLast
 if coin and not coinLogged then actions:write(string.format("%.6f,%.6f,:AUX2,128,coin\n",coinFirst,coinLast));actions:flush();coinLogged=true end
 if start and not startLogged then actions:write(string.format("%.6f,%.6f,:BLACK2,128,start\n",startFirst,startLast));actions:flush();startLogged=true end
 for mask,field in pairs(auxFields) do field:set_value((coin and mask==128) and 1 or 0) end
 for mask,field in pairs(blackFields) do field:set_value((start and mask==128) and 1 or 0) end
 log:write(string.format("%d,%.6f,%02X,%02X,%d,%d,%d\n",frame,t,m.ioport.ports[":AUX2"]:read(),m.ioport.ports[":BLACK2"]:read(),mem:read_u8(0x2f0),coin and 1 or 0,start and 1 or 0));log:flush()
end,"frame")
"@
    $luaPath = Join-Path $run 'input.lua'
    $lua | Set-Content -Encoding ASCII $luaPath
    $inputPlan = @{
        mode = $InputMode
        coin = @{ port = ':AUX2'; mask = 128; first_t = $CoinAtSeconds; last_t = $coinLast }
        start = $(if ($InputMode -eq 'CoinStart') { @{ port = ':BLACK2'; mask = 128; first_t = $StartAtSeconds; last_t = $startLast } } else { $null })
    }
    $mameArgs += @('-autoboot_delay','0','-autoboot_script',$luaPath)
}
$mameArgs | ConvertTo-Json | Set-Content (Join-Path $run 'arguments.json')
$provenance = [ordered]@{
    mode = 'Natural startup through post-VM attract/preplay boundary'
    classification = 'Natural emulator execution; fresh isolated directory and absent NVRAM/configuration; no PC, RAM, state or ROM injection'
    variant = $Variant
    input_mode = $InputMode
    mame_sha256 = Get-HashHex $MameExecutable 'SHA256'
    original_rom_sha1 = $actualOriginalSha1
    expected_rom_sha1 = $ExpectedRomSha1
    expected_rom_sha256 = $ExpectedRomSha256
    run_rom_sha1 = $runRomSha1
    run_rom_sha256 = $runRomSha256
    starting_nvram = 'absent'
    starting_configuration = 'absent; -noreadconfig'
    user_inputs = $(if ($InputMode -eq 'None') { 'none' } else { 'controlled MAME ioport field values only' })
    input_plan = $inputPlan
}
$provenance | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $run 'provenance.json')

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
$observed = [ordered]@{
    exit_code = $exitCode
    variant = $Variant
    input_mode = $InputMode
    original_rom_sha1 = $actualOriginalSha1
    expected_rom_sha1 = $ExpectedRomSha1
    expected_rom_sha256 = $ExpectedRomSha256
    run_rom_sha1_after = $postRomSha1
    run_rom_sha256_after = $postRomSha256
    rom_unchanged = ($postRomSha1 -ieq $ExpectedRomSha1 -and $postRomSha256 -ieq $ExpectedRomSha256)
    debug_log_sha256 = Get-HashHex $logPath 'SHA256'
    console_sha256 = Get-HashHex (Join-Path $run 'console.txt') 'SHA256'
    reset_reached = $log.Contains('PLAY_RESET pc=7CD1')
    init_reached = $log.Contains('PLAY_INIT_ENTRY pc=6750')
    checksum_returned = $log.Contains('PLAY_ROM_CHECK_RETURN pc=677E')
    vm_entry_reached = $log.Contains('PLAY_VM_ENTRY pc=76C7')
    main_first_native_reached = $log.Contains('PLAY_MAIN_FIRST_NATIVE pc=496A')
    attract_lamp_range_reached = $log.Contains('PLAY_ATTRACT_LAMP_RANGE pc=4AC0')
    status_service_reached = $log.Contains('PLAY_STATUS_SERVICE pc=482F')
    lamp_status_update_reached = $log.Contains('PLAY_LAMP_STATUS_UPDATE pc=2CB3')
    reel_refresh_reached = $log.Contains('PLAY_REEL_REFRESH pc=2BEB')
    lamp_init_reached = $log.Contains('PLAY_LAMP_INIT pc=171D')
    startup_lamp_sense_reached = $log.Contains('PLAY_STARTUP_LAMP_SENSE pc=2892')
    preplay_ready = [regex]::IsMatch($log, '(?m)^PLAY_PREPLAY_READY cond=12\b')
    paid_spin_setup = $log.Contains('PLAY_PAID_SPIN_SETUP pc=61D6')
    award_table_read = [regex]::IsMatch($log, '(?m)^PLAY_AWARD_TABLE_READ address=')
    stopped_at_preplay = [regex]::IsMatch($log, '(?m)^PLAY_PREPLAY_READY ') -and -not $log.Contains('PLAY_CAPTURE_END') -and -not $log.Contains('PLAY_AWARD_TABLE_READ')
    stopped_at_award = [regex]::IsMatch($log, '(?m)^PLAY_AWARD_TABLE_READ ')
    capture_end = [regex]::IsMatch($log, '(?m)^PLAY_CAPTURE_END ')
}
if (Test-Path -LiteralPath (Join-Path $run 'input.lua')) {
    $observed.input_lua_sha256 = Get-HashHex (Join-Path $run 'input.lua') 'SHA256'
    $observed.actions_sha256 = Get-HashHex (Join-Path $run 'actions.csv') 'SHA256'
    $observed.input_levels_sha256 = Get-HashHex (Join-Path $run 'input-levels.csv') 'SHA256'
}
$observed | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $run 'observation.json')

if ($exitCode -ne 0) { throw "MAME exited $exitCode; inspect $run/console.txt" }
if ($postRomSha1 -ine $ExpectedRomSha1 -or $postRomSha256 -ine $ExpectedRomSha256) { throw 'Run ROM copy changed during capture' }
Write-Output $run

param(
    [Parameter(Mandatory=$true)][string]$MameExecutable,
    [Parameter(Mandatory=$true)][string]$RomDirectory,
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [switch]$NativeSound
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$run=[System.IO.Path]::GetFullPath($RunDirectory)
if(Test-Path -LiteralPath $run){throw 'Use a fresh run directory; existing evidence is never overwritten'}
New-Item -ItemType Directory -Path $run | Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory (Join-Path $run $name) | Out-Null}
Copy-Item (Join-Path $root 'evidence/mpu4/skill-cash/input.lua') "$run/input.lua"
Copy-Item (Join-Path $root 'evidence/mpu4/skill-cash/actions.csv') "$run/replay-actions.csv"
$format='SC y=%04X token=%04X u=%04X top=%04X second=%04X third=%04X fourth=%04X s=%04X f4=%04X f6=%04X frame=%04X tick=%04X irq=%02X seed=%04X choice=%02X rate=%02X latch=%04X opt=%04X abort=%04X pending=%04X win=%04X\n'
$values='y,w@y,u,w@u,w@(u+2),w@(u+4),w@(u+6),s,w@0xf4,w@0xf6,w@(w@0xf4),w@0x2d,b@0x33,w@0x324,b@0x4f,b@0x4e,w@0x90,w@0x719f,w@0x719b,w@0xba,w@0x2fa'
$extra=@()
if($NativeSound) {
 $format=$format.Replace('\n',' clock=%04X\n');$values+=',w@0x45'
 $extra=@(
  'bpset 0x5c18,temp0==1,{printf "SQ stream=%04X clock=%04X rate=%02X volume=%02X abort=%04X free=%04X\n",x,w@0x45,b@0x4e,b@0x50,w@0x719b,w@0x49;go}',
  'bpset 0x5c46,temp0==1,{printf "QE stream=%04X clock=%04X task=%04X rate=%02X\n",w@(y+0x13),w@0x45,y,b@0x4e;go}',
  'bpset 0x5d3b,temp0==1,{printf "SN cursor=%04X opcode=%02X task=%04X clock=%04X choice=%02X rate=%02X tempo=%02X gate=%02X flags=%02X pitch=%02X transpose=%02X\n",u,b@u,y,w@0x45,b@0x4f,b@0x4e,b@(y+0xe),b@(y+0x10),b@(y+0x12),b@(y+0xc),b@(y+0xd);go}',
  'bpset 0x5cf3,temp0==1,{printf "SW duration=%02X cursor=%04X task=%04X clock=%04X callback=%04X rate=%02X tempo=%02X flags=%02X\n",b,u,y,w@0x45,w@s,b@0x4e,b@(y+0xe),b@(y+0x12);go}',
  'wpset 0x4f,1,w,temp0==1,{printf "WC pc=%04X cursor=%04X task=%04X clock=%04X old=%02X value=%02X\n",pc,u,y,w@0x45,b@0x4f,wpdata;go}',
  'bpset 0x5b77,temp0==1,{printf "SR clock=%04X choice=%02X rate=%02X\n",w@0x45,b@0x4f,b@0x4e;go}'
 )
 # Debugger setup invokes paused frame callbacks. Ignore precisely the added
 # setup callbacks in this copied observer, preserving the original physical times.
 $lua=[System.IO.File]::ReadAllText("$run/input.lua")
 $lua=$lua.Replace('local frame=0',"local frame=0`nlocal setup_callbacks_to_skip=$($extra.Count)")
 $lua=$lua.Replace('emu.register_frame_done(function()',"emu.register_frame_done(function()`n if setup_callbacks_to_skip>0 then`n  assert(m.time:as_double()<0.001,'Unexpected running frame during debugger setup')`n  setup_callbacks_to_skip=setup_callbacks_to_skip-1`n  return`n end")
 [System.IO.File]::WriteAllText("$run/input.lua",$lua)
}
$print='printf "'+$format+'",'+$values
$commands=@(
 # Keep the original fixture's one-breakpoint startup command count. Each debugger
 # setup command triggers a paused frame callback in this harness; extra commands
 # change frame-number-based physical input timing. temp0 starts at zero in MAME.
 "bpset 0xfc,y==0xc721 || temp0==1,{temp0=(y!=0xc71d);$print;go}"
)+$extra+@(
 'gtime #2400000',
 'save ram-final.bin,0,800',
 'quit'
)
$commands | Set-Content "$run/debugger.cmd"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,
 '-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",
 '-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",
 '-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none',
 '-window','-skip_gameinfo','-nothrottle','-seconds_to_run','2402','-autoboot_delay','0','-autoboot_script',"$run/input.lua")
$arguments | ConvertTo-Json | Set-Content "$run/arguments.json"
@{mame_sha256=(Get-FileHash -LiteralPath $MameExecutable).Hash;replay_sha256=(Get-FileHash "$run/replay-actions.csv").Hash;
 native_sound_capture=[bool]$NativeSound;paused_setup_callbacks_skipped=$extra.Count;
 initial_state='Fresh isolated default configuration and absent NVRAM; physical-input fixture only; no RAM/ROM injection.'} |
 ConvertTo-Json | Set-Content "$run/provenance.json"
$previousReplay=$env:MPU4_REPLAY
$previousPolicy=$env:MPU4_POLICY
try {
 $env:MPU4_REPLAY="$run/replay-actions.csv"
 $env:MPU4_POLICY='7'
 Push-Location $run
 try { & $MameExecutable @arguments *> "$run/console.txt"; $LASTEXITCODE | Set-Content "$run/exit-code.txt" }
 finally { Pop-Location }
} finally { $env:MPU4_REPLAY=$previousReplay; $env:MPU4_POLICY=$previousPolicy }
if(!(Select-String -LiteralPath "$run/debug.log" -Pattern '^SC y=C71D ' -Quiet)){throw "Skill Cash completion was not captured; inspect $run"}
Get-ChildItem $run -File | Get-FileHash | Select-Object Path,Hash | ConvertTo-Json | Set-Content "$run/hashes.json"
Write-Output $run

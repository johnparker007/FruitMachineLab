param(
    [Parameter(Mandatory=$true)][string]$MameExecutable,
    [Parameter(Mandatory=$true)][string]$RomDirectory,
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [switch]$NativeSound,
    [switch]$NativeNvram,
    [switch]$FullFeature,
    [switch]$NativeInput,
    [switch]$NativeLampFrames,
    [switch]$NativeAlpha,
    [switch]$NativeScan,
    [switch]$SharedTiming,
    [switch]$TimerDeadlines
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
if($SharedTiming) {$format=$format.Replace('\n',' cycle=%016X\n');$values+=',totalcycles'}
if($FullFeature) {
 $format=$format.Replace('\n',' guard=%02X checksum=%02X mode=%02X display=%04X suppress=%04X\n')
 $values+=',b@0x2c,b@0x322,b@0x323,w@0x327,w@0xa0'
}
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
}
if($NativeNvram) {
 $stateFormat=''
 $stateValues=''
 foreach($address in 0x2F0..0x308) {$stateFormat+=' source'+$address.ToString('X4')+'=%02X';$stateValues+=',b@0x'+$address.ToString('X4')}
 foreach($address in 0x309..0x321) {$stateFormat+=' copy'+$address.ToString('X4')+'=%02X';$stateValues+=',b@0x'+$address.ToString('X4')}
 $nvFormat=' mode=%02X guard=%02X checksum=%02X u=%04X s=%04X pending=%04X win=%04X'+$stateFormat+'\n'
 $nvValues='b@0x323,b@0x2c,b@0x322,u,s,w@0xba,w@0x2fa'+$stateValues
 $extra+=@(('bpset 0x6e06,temp0==1,{printf "NI'+$nvFormat+'",'+$nvValues+';go}'),
 ('bpset 0x6e68,temp0==1,{printf "NO'+$nvFormat+'",'+$nvValues+';go}'))
}
if($NativeInput) {
 $extra+=@('bpset 0x67ec,temp0==1 && (x==0x83a4 || x==0x83a7 || x==0x8413 || x==0x8386),{printf "PI selector=%02X p0=%02X p1=%02X p2=%02X p3=%02X p6=%02X p7=%02X clock=%04X\n",b@x,b@0,b@1,b@2,b@3,b@6,b@7,w@0x45;go}')
}
if($NativeLampFrames) {
 $frameFormat='';$frameValues=''
 for($address=0x100;$address -lt 0x140;$address+=2){$frameFormat+='%04X';$frameValues+=',w@0x'+$address.ToString('X4')}
 $extra+=@(('bpset 0x49c5,temp0==1,{printf "LI id=%02X pattern=%02X frames='+$frameFormat+'\n",a,b'+$frameValues+';go}'),
 ('bpset 0x4a23,temp0==1,{printf "LF id=%02X pattern=%02X column=%02X frames='+$frameFormat+'\n",b@s,b@(s+1),x-0x100'+$frameValues+';go}'))
}
if($NativeAlpha) {
 $alphaFormat=' cursor=%02X control=%02X stop=%02X mirror=%02X digit=%02X shadow=%04X%04X%04X%04X%04X%04X%04X%04X digits=%04X%04X%04X%04X pending=%04X win=%04X display=%04X credit=%04X clock=%04X tick=%04X\n'
 $alphaValues='b@0x54,b@0x55,b@0x57,b@0xc5,b@0xc4,w@0x58,w@0x5a,w@0x5c,w@0x5e,w@0x60,w@0x62,w@0x64,w@0x66,w@0x1a,w@0x1c,w@0x1e,w@0x20,w@0xba,w@0x2fa,w@0x327,w@0x2f0,w@0x45,w@0x2d'
 $extra+=@(('bpset 0x3cc0,temp0==1,{printf "AE stream=%04X'+$alphaFormat+'",x,'+$alphaValues+';go}'),
 ('bpset 0x774e,temp0==1,{printf "AX next=%04X'+$alphaFormat+'",w@0x52,'+$alphaValues+';go}'),
 ('bpset 0x3d0e,temp0==1,{printf "AR'+$alphaFormat+'",'+$alphaValues+';go}'),
 ('bpset 0x3d5d,temp0==1,{printf "AZ'+$alphaFormat+'",'+$alphaValues+';go}'),
 'bpset 0x400d,temp0==1,{printf "AB value=%02X clock=%04X tick=%04X\n",a,w@0x45,w@0x2d;go}')
}
if($NativeScan) {
 $scanFormat=' phase=%02X count=%02X reload=%02X alternate=%02X alternate_reload=%02X column=%04X suppress=%02X decimal=%02X sweep=%02X samples=%04X%04X%04X%04X digits=%04X%04X%04X%04X blink=%04X%04X%04X%04X ports=%02X%02X%02X%02X%02X%02X clock=%04X tick=%04X frames='
 $scanValues='b@0x23,b@0x24,b@0x25,b@0x26,b@0x27,w@0x28,b@0x8d,b@0x22,b@0xb3,w@8,w@0xa,w@0xc,w@0xe,w@0x1a,w@0x1c,w@0x1e,w@0x20,w@0x2be,w@0x2c0,w@0x2c2,w@0x2c4,b@0xa00,b@0xa02,b@0xb00,b@0xe01,b@0xb01,b@0xf01,w@0x45,w@0x2d'
 for($address=0x100;$address -lt 0x140;$address+=2){$scanFormat+='%04X';$scanValues+=',w@0x'+$address.ToString('X4')}
 $scanFormat+='\n'
 $extra+=@(('bpset 0x28fe,temp0==1,{printf "SI'+$scanFormat+'",'+$scanValues+';go}'),
 ('bpset 0x29ba,temp0==1,{printf "SX'+$scanFormat+'",'+$scanValues+';go}'),
 'bpset 0x19c2,temp0==1,{printf "PE enabled=%02X count=%02X reload=%02X step=%02X timer=%04X callback=%04X control=%04X clock=%04X tick=%04X\n",b@0xb3,b@0xe8,b@0xe9,b@0xea,w@0x32d,w@0x3d,w@0x3f,w@0x45,w@0x2d;go}',
 'bpset 0x19f8,temp0==1,{printf "PX enabled=%02X count=%02X reload=%02X step=%02X timer=%04X callback=%04X control=%04X clock=%04X tick=%04X\n",b@0xb3,b@0xe8,b@0xe9,b@0xea,w@0x32d,w@0x3d,w@0x3f,w@0x45,w@0x2d;go}')
}
if($SharedTiming) {
 $extra+=@(
 'bpset 0x49c5,temp0==1,{printf "ML cycle=%016X id=%02X pattern=%02X\n",totalcycles,a,b;go}',
 'wpset 0x100,0x40,w,temp0==1,{printf "MW cycle=%016X address=%04X value=%02X\n",totalcycles,wpaddr,wpdata;go}',
 'bpset 0x4a23,temp0==1,{printf "MF cycle=%016X\n",totalcycles;go}',
 'bpset 0x28fe,temp0==1,{printf "MS cycle=%016X phase=%02X count=%02X reload=%02X alternate=%02X alternate_reload=%02X column=%04X suppress=%02X decimal=%02X sweep=%02X sample=%04X%04X%04X%04X digits=%04X%04X%04X%04X blink=%04X%04X%04X%04X ports=%02X%02X%02X%02X%02X%02X pulse=%04X%02X%04X masks=%04X%04X%04X%04X%04X%04X%04X%04X blank=%04X%04X%04X%04X\n",totalcycles,b@0x23,b@0x24,b@0x25,b@0x26,b@0x27,w@0x28,b@0x8d,b@0x22,b@0xb3,w@8,w@0xa,w@0xc,w@0xe,w@0x1a,w@0x1c,w@0x1e,w@0x20,w@0x2be,w@0x2c0,w@0x2c2,w@0x2c4,b@0xa00,b@0xa02,b@0xb00,b@0xe01,b@0xb01,b@0xf01,w@0xe8,b@0xea,w@0x32d,w@0x140,w@0x142,w@0x144,w@0x146,w@0x148,w@0x14a,w@0x14c,w@0x14e,w@0xab,w@0xad,w@0xaf,w@0xb1;go}',
 'bpset 0x29ba,temp0==1,{printf "MX cycle=%016X phase=%02X count=%02X alternate=%02X column=%04X ports=%02X%02X%02X%02X%02X%02X\n",totalcycles,b@0x23,b@0x24,b@0x26,w@0x28,b@0xa00,b@0xa02,b@0xb00,b@0xe01,b@0xb01,b@0xf01;go}',
 'bpset 0x70ef,temp0==1,{printf "MA cycle=%016X timer=%04X callback=%04X\n",totalcycles,y,x;go}',
 'bpset 0x48fd,temp0==1,{printf "MC cycle=%016X column=%04X ports=%02X%02X%02X\n",totalcycles,w@0x28,b@0xa00,b@0xa02,b@0xb00;go}',
 'bpset 0x4916,temp0==1,{printf "MD cycle=%016X column=%04X ports=%02X%02X%02X\n",totalcycles,w@0x28,b@0xa00,b@0xa02,b@0xb00;go}'
 )
}
if($TimerDeadlines) {
 $extra+=@(
 'wpset 0x907,1,w,temp0==1,{printf "TL cycle=%016X pc=%04X value=%02X timer=%04X control=%02X\n",totalcycles,pc,wpdata,y,b@0x40;go}',
 'bpset 0xfe70,temp0==1,{printf "TI cycle=%016X cc=%02X\n",totalcycles,cc;go}',
 'bpset 0x48fd,temp0==1,{printf "TC cycle=%016X column=%04X\n",totalcycles,w@0x28;go}'
 )
}
if($extra.Count -gt 0) {
 # Debugger setup invokes paused frame callbacks. Ignore precisely the added
 # setup callbacks in this copied observer, preserving the original physical times.
 $lua=[System.IO.File]::ReadAllText("$run/input.lua")
 $lua=$lua.Replace('local frame=0',"local frame=0`nlocal setup_callbacks_to_skip=$($extra.Count)")
 $lua=$lua.Replace('emu.register_frame_done(function()',"emu.register_frame_done(function()`n if setup_callbacks_to_skip>0 then`n  assert(m.time:as_double()<0.001,'Unexpected running frame during debugger setup')`n  setup_callbacks_to_skip=setup_callbacks_to_skip-1`n  return`n end")
 [System.IO.File]::WriteAllText("$run/input.lua",$lua)
}
$print='printf "'+$format+'",'+$values
$stop=if($FullFeature){'0xc767'}else{'0xc71d'}
$commands=@(
 # Keep the original fixture's one-breakpoint startup command count. Each debugger
 # setup command triggers a paused frame callback in this harness; extra commands
 # change frame-number-based physical input timing. temp0 starts at zero in MAME.
 "bpset 0xfc,y==0xc721 || temp0==1,{temp0=(y!=$stop);$print;go}"
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
 native_sound_capture=[bool]$NativeSound;native_nvram_capture=[bool]$NativeNvram;full_feature_capture=[bool]$FullFeature;native_input_capture=[bool]$NativeInput;native_lamp_frames=[bool]$NativeLampFrames;native_alpha_capture=[bool]$NativeAlpha;native_scan_capture=[bool]$NativeScan;shared_timing=[bool]$SharedTiming;paused_setup_callbacks_skipped=$extra.Count;
 timer_deadlines=[bool]$TimerDeadlines;
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

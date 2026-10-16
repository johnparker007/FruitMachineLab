param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory)
if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$commands.Add('bpset 0x800')
foreach($pc in @(0x48FF,0x4903,0x4906,0x4909,0x490B,0x490D,0x4910,0x4913,0x4916,0x4917,0x4919,0x491D,0x491F,0x4922)){
 $commands.Add(('bpset {0:X},1,{{printf "CI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))
}
foreach($column in @(0,3,7)){foreach($blank in @(0,1)){foreach($ports in @(@(0xFF,0xAA),@(0xA5,0x5A),@(0,0xFF))){
 $id=$cases.Count
 # Isolated synthetic PIA register state, not user MAME configuration. Select
 # all-output DDR then data registers so original callback reads known latches.
 $commands.Add(('temp1=0x{0:X};pc=0x48fd;cc=0x50;dp=0;s=0x700;w@700=0x800;y=0x2345;u=0x3456;w@28=0x{1:X};b@{2:X}=0xf;b@{3:X}=0xf0;b@{4:X}=0x{5:X};b@a01=0;b@a00=0xff;b@a01=4;b@a00=0x{6:X};b@a03=0;b@a02=0xff;b@a03=4;b@a02=0x{7:X};b@b01=0;b@b00=0xff;b@b01=4;b@b00=0xcc' -f $id,$column,(0x140+$column),(0x148+$column),(0xAB+$column),$blank,$ports[0],$ports[1]))
 $commands.Add('printf "CS id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)');$commands.Add('go')
 $commands.Add('printf "CF id=%X cycle=%016X pc=%04X s=%04X y=%04X u=%04X bank0=%02X bank1=%02X display=%02X\n",temp1,totalcycles,pc,s,y,u,b@a00,b@a02,b@b00')
 $cases.Add([ordered]@{id=$id;column=$column;blank=$blank;bank0=$ports[0];bank1=$ports[1];mask0=15;mask1=240;display=204})
}}}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
@'
local m=manager.machine;local cpu=m.devices[':maincpu'];local mem=cpu.spaces['program']
local f=assert(io.open('lamp-writes.csv','w'));f:setvbuf('no');f:write('pc,address,data,seconds,attoseconds\n')
_G.fml_lamp_callback_write=mem:install_write_tap(0xa00,0xb00,'fml-lamp-callback-write',function(address,data)
 local pc=cpu.state['CURPC'].value
 if (pc==0x490d and address==0xa00) or (pc==0x4910 and address==0xa02) or (pc==0x491f and address==0xb00) then
  f:write(string.format('%04X,%04X,%02X,%d,%d\n',pc,address,data,m.time.seconds,m.time.attoseconds))
 end
end)
'@|Set-Content "$run/lamp-writes.lua"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','10','-autoboot_delay','0','-autoboot_script',"$run/lamp-writes.lua")
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
Push-Location $run;try{& $MameExecutable @arguments *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location}
if($code -ne 0 -or (Select-String "$run/debug.log" -Pattern '^Error ' -Quiet)){throw 'Invalid callback experiment'}
Write-Output $run

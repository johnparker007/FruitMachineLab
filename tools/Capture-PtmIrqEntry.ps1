param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory)
if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$id=0
foreach($latch in @(1,40,255)){
 foreach($hold in @(0,30,180)){
  foreach($body in @('nop','ldd')){
   $bytes=[Collections.Generic.List[byte]]::new();$instructions=[Collections.Generic.List[object]]::new()
   function Emit([int[]]$values){foreach($v in $values){$bytes.Add([byte]$v)}}
   function Store([int]$value,[int]$address){Emit @(0x86,$value,0xB7,($address -shr 8),($address -band 255))}
   Store 1 0x901;Store 1 0x900;Store 0 0x901;Store 0x63 0x900;Store ($latch -shr 8) 0x906;Store ($latch -band 255) 0x907;Store 1 0x901;Store 0 0x900
   $release=0x700+$bytes.Count
   # Masked two-cycle NOPs can hold IRQ pending for several timer periods.
   for($i=0;$i -lt $hold;$i++){Emit @(0x12)}
   $unmask=0x700+$bytes.Count;Emit @(0x1C,0xEF)
   $loop=0x700+$bytes.Count
   if($body -eq 'nop'){$instructions.Add(@{address=$loop;cycles=2;next=$loop+1});Emit @(0x12)}
   else{$instructions.Add(@{address=$loop;cycles=3;next=$loop+3});Emit @(0xCC,0xAB,0xCD)}
   $branch=0x700+$bytes.Count;$instructions.Add(@{address=$branch;cycles=3;next=$loop});Emit @(0x20,(256-($branch+2-$loop)))
   if($bytes.Count -gt 0x100){throw 'Program exceeds selected RAM window'}
   $name='irq-{0}.bin' -f $id;[IO.File]::WriteAllBytes("$run/$name",$bytes.ToArray())
   $commands.Add(('load {0},700;pc=0x700;cc=0x50;s=0x600;u=0x4567;x=0x1234;y=0x2345;dp=0x0a;temp1=0x{1:X}' -f $name,$id))
   $commands.Add(('wpset 0x900,1,w,pc=={0:X},{{printf "IA id=%X cycle=%016X\n",temp1,totalcycles;go}}' -f $release))
   $commands.Add(('bpset {0:X},1,{{printf "IB id=%X pc=%04X cycle=%016X cc=%02X\n",temp1,pc,totalcycles,cc;go}}' -f $unmask))
   foreach($ins in $instructions){$commands.Add(('bpset {0:X},1,{{printf "IB id=%X pc=%04X cycle=%016X cc=%02X\n",temp1,pc,totalcycles,cc;go}}' -f $ins.address))}
   $commands.Add('bpset 0xfe70');$commands.Add('go')
   $commands.Add('printf "IE id=%X cycle=%016X pc=%04X cc=%02X a=%02X b=%02X dp=%02X x=%04X y=%04X u=%04X s=%04X frame=%04X%04X%04X%04X%04X%04X\n",temp1,totalcycles,pc,cc,a,b,dp,x,y,u,s,w@s,w@(s+2),w@(s+4),w@(s+6),w@(s+8),w@(s+0xa)')
   $commands.Add('bpclear');$commands.Add('wpclear')
   $cases.Add([ordered]@{id=$id;latch=$latch;masked_nops=$hold;body=$body;release_pc=$release;unmask_pc=$unmask;instructions=@($instructions.ToArray());program_hex=[Convert]::ToHexString($bytes.ToArray())});$id++
  }
 }
}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json -Depth 6|Set-Content "$run/cases.json"
@'
local m=manager.machine;local cpu=m.devices[':maincpu'];local mem=cpu.spaces['program']
local f=assert(io.open('bus-time.csv','w'));f:setvbuf('no');f:write('event,pc,seconds,attoseconds\n')
_G.fml_irq_bus=mem:install_write_tap(0x900,0x900,'fml-irq-bus',function()
 if cpu.state['PC'].value==0x728 then f:write(string.format('release,%04X,%d,%d\n',cpu.state['PC'].value,m.time.seconds,m.time.attoseconds)) end
end)
'@|Set-Content "$run/bus-time.lua"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','10')
$arguments+=@('-autoboot_delay','0','-autoboot_script',"$run/bus-time.lua")
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
Push-Location $run;try{& $MameExecutable @arguments *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location}
if($code -ne 0 -or (Select-String "$run/debug.log" -Pattern '^Error ' -Quiet)){throw 'Invalid IRQ experiment'}
Write-Output $run

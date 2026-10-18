param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory);if(Test-Path $run){throw 'Fresh isolated directory required'};New-Item -ItemType Directory $run|Out-Null;foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
function Word([byte[]]$b,[int]$a,[int]$v){$b[$a]=[byte](($v -shr 8)-band 255);$b[$a+1]=[byte]($v-band 255)}
$seed=[byte[]]::new(0x800)
Word $seed 0x47 0;Word $seed 0x49 0x1A0
for($at=0x1A0;$at -lt 0x259;$at+=0x25){Word $seed $at ($at+0x25)};Word $seed 0x259 0
$seed[0x4B]=0;for($n=1;$n -le 5;$n++){$seed[0x27D+$n]=[byte]$n};$seed[0x4C]=5;$seed[0x283]=255
$seed[0x4D]=0;$seed[0x4E]=16;$seed[0x4F]=0;$seed[0x50]=16
$seed|Set-Content "$run/seed-reset.bin" -Encoding Byte
$cmd=[Collections.Generic.List[string]]::new()
$body='';foreach($name in @('Queue','Service','Cancel','Release','Note','Yield','Attenuation')){$body+=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Adders/AddersSound${name}Plan.cs" -Raw};$body+=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Adders/AddersYmCachedWritePlan.cs" -Raw
$pcs=@(0x4C34,0x5DC5,0x5DCC,0x5DD5,0x5D63,0x5D77,0x5D8B)+@([regex]::Matches($body,'new NativeRoutineStep\(0x([0-9A-F]{4}),"')|ForEach-Object {[Convert]::ToInt32($_.Groups[1].Value,16)})|Sort-Object -Unique
foreach($pc in $pcs){if($pc -eq 0x4C34){continue};$cmd.Add(('bpset {0:X},1,{{printf "OI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
$cmd.Add('bpset 4C34');$cmd.Add('load seed-reset.bin,0')
$phases=@(
 @{id=0;name='queue';pc=0x5C18;x=0x59EB;y=0x1A0;a=0x91;b=0x31;clock=0},
 @{id=1;name='service1';pc=0x5CD0;x=0x8784;y=0x1A0;a=0;b=0;clock=0},
 @{id=2;name='service2';pc=0x5CD0;x=0x8784;y=0x1A0;a=0;b=0;clock=0x00FF},
 @{id=3;name='cancel';pc=0x5C7A;x=0x59EB;y=0x1A0;a=0x89;b=0xAB;clock=-1}
)
foreach($phase in $phases){
 $cmd.Add(('temp1=0x{0:X}' -f $phase.id))
 $cmd.Add(('printf "PH id=%X cycle=%016X\n",temp1,totalcycles'))
 $cmd.Add(('save tone-{0}-before.bin,0,800' -f $phase.id))
 if($phase.clock -ge 0){$cmd.Add(('pc=0x{0:X};x=0x{1:X};y=0x{2:X};u=0x600;s=0x700;dp=0;cc=0x50;a=0x{3:X};b=0x{4:X};w@700=0x4c34;b@45=0x{5:X};b@46=0x{6:X};b@44=0;b@719b=0' -f $phase.pc,$phase.x,$phase.y,$phase.a,$phase.b,(($phase.clock -shr 8)-band 255),($phase.clock-band 255)))}
 else{$cmd.Add(('pc=0x{0:X};x=0x{1:X};y=0x{2:X};u=0x600;s=0x700;dp=0;cc=0x50;a=0x{3:X};b=0x{4:X};w@700=0x4c34;b@44=0;b@719b=0' -f $phase.pc,$phase.x,$phase.y,$phase.a,$phase.b))}
 $cmd.Add('go')
 $cmd.Add(('save tone-{0}-after.bin,0,800' -f $phase.id))
 $cmd.Add(('printf "PE id=%X pc=%04X cycle=%016X s=%04X u=%04X x=%04X y=%04X\n",temp1,pc,totalcycles,s,u,x,y'))
}
$cmd.Add('quit');$cmd|Set-Content "$run/debugger.cmd"
[ordered]@{classification='Synthetic isolated original-ROM 59EB lifecycle: reset list, native5C18 queue, two externally timed5CD0 service ticks (second at due-1), native5C7A cancel; masked IRQ. Host writes are only PC/registers, return word0700=4C34, counter44=0, enable719B=0 and declared 45/46 clocks; no other intermediate RAM edits and no captured end state is injected.';mame_sha256=([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([IO.File]::ReadAllBytes($MameExecutable)))-replace '-','')}|ConvertTo-Json|Set-Content "$run/provenance.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30');$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
Push-Location $run;$old=$ErrorActionPreference;try{$ErrorActionPreference='Continue';& $MameExecutable @arguments *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{$ErrorActionPreference=$old;Pop-Location};if($code -ne 0 -or (Select-String "$run/debug.log" -Pattern '^Error ' -Quiet)){throw 'Invalid tone lifecycle capture'};Write-Output $run

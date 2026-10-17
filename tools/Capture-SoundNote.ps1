param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory);if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null;foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$cmd=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$cmd.Add('bpset 5d3b');$cmd.Add('bpset 5cde')
$body='';foreach($name in @('Note','Yield')){$body+=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Adders/AddersSound${name}Plan.cs" -Raw};$body+=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Adders/AddersYmCachedWritePlan.cs" -Raw
$pcs=@(0x5DC5,0x5DCC,0x5DD5)+@([regex]::Matches($body,'new NativeRoutineStep\(0x([0-9A-F]{4}),"')|ForEach-Object {[Convert]::ToInt32($_.Groups[1].Value,16)})
foreach($pc in ($pcs|Sort-Object -Unique)){$cmd.Add(('bpset {0:X},1,{{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
foreach($note in @(0x2B,0x84,0x5A,0xBA)){foreach($pool in @(0,1,2)){foreach($pitch in @(0,255)){foreach($flags in @(0,128)){
$id=$cases.Count;$cases.Add([ordered]@{id=$id;note=$note;pool=$pool;pitch=$pitch;flags=$flags})
$cmd.Add(('pc=0x5d48;b=0x{0:X};x=0x8784;y=0x1a0;u=0x601;s=0x700;dp=0;cc=0x50;b@600=0x{0:X};b@601=5;w@45=0xffff;b@4d=0x7f;b@4e=16;w@47=0x1c5;w@1c5=0;w@1c7=0x9998;b@1aa=0xff;b@1ab=0xa5;b@1ac=0x{1:X};b@1ad=0;b@1ae=16;b@1af=0x20;b@1b0=0;b@1b2=0x{2:X}' -f $note,$pitch,$flags))
$head=if($pool){0}else{255};$tail=if($pool -eq 2){5}elseif($pool){0}else{255};$cmd.Add(('b@4b=0x{0:X};b@4c=0x{1:X}' -f $head,$tail))
for($n=0;$n -lt 6;$n++){$next=if($pool -eq 2 -and $n -lt 5){$n+1}else{255};$cmd.Add(('b@{0:X}=0x{1:X}' -f (0x27E+$n),$next))}
$cmd.Add("save operation-$id-before.bin,0,800");$cmd.Add('printf "OS pc=%04X cycle=%016X\n",pc,totalcycles');$cmd.Add('go');$cmd.Add('printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s');$cmd.Add("save operation-$id-after.bin,0,800")
}}}}
$cmd.Add('quit');$cmd|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{classification='48 synthetic original melodic notes, empty/last/multiple free channels and wrapped pitch; not natural sound playback.';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
$args=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30')
$args|ConvertTo-Json|Set-Content "$run/arguments.json";Push-Location $run;try{& $MameExecutable @args *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location};if($code -ne 0){throw 'Invalid operation capture'};Write-Output $run


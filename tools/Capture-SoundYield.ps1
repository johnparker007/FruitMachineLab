param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory);if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null;foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$cmd=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$cmd.Add('bpset 5cde')
$body=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Adders/AddersSoundYieldPlan.cs" -Raw
foreach($pc in ([regex]::Matches($body,'new NativeRoutineStep\(0x([0-9A-F]{4}),"')|ForEach-Object {[Convert]::ToInt32($_.Groups[1].Value,16)}|Sort-Object -Unique)){$cmd.Add(('bpset {0:X},1,{{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
foreach($duration in @(0,1,16,255)){foreach($flags in @(0,128)){foreach($tempo in @(0,16,255)){foreach($variant in @(0,1)){
$id=$cases.Count;$clock=if($variant){65535}else{0x1234};$rate=if($variant){255}else{0};$cases.Add([ordered]@{id=$id;duration=$duration;flags=$flags;tempo=$tempo;clock=$clock;rate=$rate})
$cmd.Add(('pc=0x5cf3;b=0x{0:X};y=0x1a0;u=0x879e;s=0x700;dp=0;cc=0x50;w@700=0x5e29;w@45=0x{1:X};b@4e=0x{2:X};b@1b2=0x{3:X};b@1ae=0x{4:X};w@47=0x1c5;w@1c5=0x1ea;w@1ea=0;w@1c7=0x{5:X};w@1ec=0x{6:X}' -f $duration,$clock,$rate,$flags,$tempo,(($clock+1)-band 65535),(($clock+65534)-band 65535)))
$cmd.Add("save operation-$id-before.bin,0,800");$cmd.Add('printf "OS pc=%04X cycle=%016X\n",pc,totalcycles');$cmd.Add('go');$cmd.Add('printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s');$cmd.Add("save operation-$id-after.bin,0,800")
}}}}
$cmd.Add('quit');$cmd|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{classification='48 synthetic original5CF3 yields, explicit removed task and callback stack; not natural sound playback.';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
$args=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30')
$args|ConvertTo-Json|Set-Content "$run/arguments.json";Push-Location $run;try{& $MameExecutable @args *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location};if($code -ne 0){throw 'Invalid operation capture'};Write-Output $run

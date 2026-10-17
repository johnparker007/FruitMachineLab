param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory);if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null;foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$cmd=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$cmd.Add('bpset 4c34')
$body=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Adders/AddersSerialFramePlan.cs" -Raw
foreach($pc in ([regex]::Matches($body,'new NativeRoutineStep\(0x([0-9A-F]{4}),"')|ForEach-Object {[Convert]::ToInt32($_.Groups[1].Value,16)}|Sort-Object -Unique)){$cmd.Add(('bpset {0:X},1,{{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
foreach($state in 0..7){foreach($value in @(1,0x2D,0x2E,0x5F)){
$id=$cases.Count;$cases.Add([ordered]@{id=$id;state=$state;value=$value})
$cmd.Add(('pc=0x51b1;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@84=0xff;b@3da=1;b@3db=0x{0:X};w@3d6=0x3a8;b@3a8=0x{0:X};b@3a5=0;b@3a6=0;b@323=0;b@73=0x55;b@ff44=0;b@38d=0;b@719a=0' -f $value))
switch($state){0{$cmd.Add('b@84=0')} 1{$cmd.Add('b@3da=0')} 2{$cmd.Add('b@3a5=2')} 3{$cmd.Add('w@3d6=0x200')} 4{$cmd.Add('b@323=0xff')} 5{$cmd.Add('b@ff44=1')} 6{$cmd.Add('b@38d=1')} 7{$cmd.Add('b@719a=1;w@a3=0')}}
$cmd.Add("save operation-$id-before.bin,0,800");$cmd.Add('printf "OS pc=%04X cycle=%016X\n",pc,totalcycles');$cmd.Add('go');$cmd.Add('printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s');$cmd.Add("save operation-$id-after.bin,0,800")
}}
$cmd.Add('quit');$cmd|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{classification='32 synthetic original51B1 positive queue frame calls, explicit mode/hook states; not natural sound playback.';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
$args=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30')
$args|ConvertTo-Json|Set-Content "$run/arguments.json";Push-Location $run;try{& $MameExecutable @args *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location};if($code -ne 0){throw 'Invalid operation capture'};Write-Output $run


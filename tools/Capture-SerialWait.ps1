param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory);if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null;foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$cmd=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();foreach($stop in @('4c34','2cb3','5471','546a','6ef7')){$cmd.Add("bpset $stop")}
$body=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Adders/AddersSerialWaitPlan.cs" -Raw
foreach($pc in ([regex]::Matches($body,'new NativeRoutineStep\(0x([0-9A-F]{4}),"')|ForEach-Object {[Convert]::ToInt32($_.Groups[1].Value,16)}|Sort-Object -Unique)){$cmd.Add(('bpset {0:X},1,{{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
foreach($variant in 0..7){foreach($state in 0..3){
$id=$cases.Count;$entry=if($variant -lt 2){0x5429}else{0x5434};$x=@(0,0,1,0x1001,0xF001,0,0x1002,0xF002)[$variant];$a=if($variant -eq 7){0}else{255};$busy=if($state-band 1){255}else{0};$status=if($state-band 2){0x8F}else{0x80}
$cases.Add([ordered]@{id=$id;entry=$entry;x=$x;a=$a;busy=$busy;status=$status})
$cmd.Add(('pc=0x{0:X};x=0x{1:X};a=0x{2:X};b=0xab;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@7d=0x{3:X};b@75=0x{4:X};b@323=0;b@73=0xff' -f $entry,$x,$a,$busy,$status))
$cmd.Add("save operation-$id-before.bin,0,800");$cmd.Add('printf "OS pc=%04X cycle=%016X\n",pc,totalcycles');$cmd.Add('go');$cmd.Add('printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s');$cmd.Add("save operation-$id-after.bin,0,800")
}}
$cmd.Add('quit');$cmd|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{classification='32 synthetic original5429/5434 busy wait prefixes to first helper boundary, no helper skipped; not natural sound playback.';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
$args=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30')
$args|ConvertTo-Json|Set-Content "$run/arguments.json";Push-Location $run;try{& $MameExecutable @args *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location};if($code -ne 0){throw 'Invalid operation capture'};Write-Output $run


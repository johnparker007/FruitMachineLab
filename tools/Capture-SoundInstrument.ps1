param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory);if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null;foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$cmd=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$cmd.Add('bpset 5d3b')
$body=(Get-Content "$PSScriptRoot/../src/FruitMachineLab.Adders/AddersSoundInstrumentPlan.cs" -Raw)+(Get-Content "$PSScriptRoot/../src/FruitMachineLab.Adders/AddersYmCachedWritePlan.cs" -Raw)
foreach($pc in ([regex]::Matches($body,'new NativeRoutineStep\(0x([0-9A-F]{4}),"')|ForEach-Object {[Convert]::ToInt32($_.Groups[1].Value,16)}|Sort-Object -Unique)){$cmd.Add(('bpset {0:X},1,{{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
foreach($command in @(0xC5,0xDB,0xDD)){foreach($pattern in @(0,1,2,3)){foreach($flags in @(0,128)){foreach($hit in @(0,1)){
$id=$cases.Count;$operand=@(0,0xE0,255,128)[$pattern];$pitch=@(0,12,244,255)[$pattern];$reg=$command-0xC5;$index=($operand+$pitch+$(if($flags){127}else{0}))-band 255;$table=0x5A1E+2*$index
$cases.Add([ordered]@{id=$id;command=$command;operand=$operand;pitch=$pitch;flags=$flags;hit=$hit})
$cmd.Add(('pc=0x5f5b;y=0x1a0;u=0x601;s=0x700;dp=0;cc=0x50;b@600=0x{0:X};b@601=0x{1:X};b@1ac=0x{2:X};b@1ad=0;b@1b2=0x{3:X};b@4d=0x7f' -f $command,$operand,$pitch,$flags))
$cmd.Add(('b@{0:X}=b@{1:X};b@{2:X}=b@{3:X}&0xf' -f (0x284+$reg),($table+1),(0x294+$reg),$table))
if(!$hit){$cmd.Add(('b@{0:X}=b@{0:X}^0xff;b@{1:X}=b@{1:X}^0xff' -f (0x284+$reg),(0x294+$reg)))}
$cmd.Add("save operation-$id-before.bin,0,800");$cmd.Add('printf "OS pc=%04X cycle=%016X\n",pc,totalcycles');$cmd.Add('go');$cmd.Add('printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s');$cmd.Add("save operation-$id-after.bin,0,800")
}}}}
$cmd.Add('quit');$cmd|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{classification='48 synthetic original instrument/cache calls, wrapped pitch indexes and cache hits; not natural sound playback.';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
$args=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30')
$args|ConvertTo-Json|Set-Content "$run/arguments.json";Push-Location $run;try{& $MameExecutable @args *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location};if($code -ne 0){throw 'Invalid operation capture'};Write-Output $run


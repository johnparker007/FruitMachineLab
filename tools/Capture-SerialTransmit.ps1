param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory);if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null;foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$cmd=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();foreach($at in @('70d6','70c9','6ba7','6a08','4c34')){$cmd.Add("bpset $at")}
$body=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Adders/AddersSerialTransmitPlan.cs" -Raw
foreach($pc in ([regex]::Matches($body,'new NativeRoutineStep\(0x([0-9A-F]{4}),"')|ForEach-Object {[Convert]::ToInt32($_.Groups[1].Value,16)}|Sort-Object -Unique)){$cmd.Add(('bpset {0:X},1,{{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
foreach($entry in @(0x69C0,0x69D7)){foreach($value in @(0x34,0x3C,0xFF,0)){foreach($state in 0..3){
$id=$cases.Count;$more=$state-band 1;$mode=if($state-band 2){128}else{0};$end=if($entry -eq 0x69C0){if($value -eq 255){0x70C9}else{0x70D6}}elseif($more){0x6BA7}elseif($mode){0x4C34}else{0x6A08};$stack=if($end -eq 0x70C9){0x6FE}elseif($end -eq 0x4C34){0x702}else{0x700}
$cases.Add([ordered]@{id=$id;entry=$entry;value=$value;state=$state;end=$end;stack=$stack})
$cmd.Add(('pc=0x{0:X};a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@42=0x37c;b@37c=0x{1:X};b@71=0xff;b@3a6=0x{2:X};b@323=0x{3:X};b@73=0xff;b@80=0xff;w@389=0x599' -f $entry,$value,$more,$mode))
$cmd.Add("save operation-$id-before.bin,0,800");$cmd.Add('printf "OS pc=%04X cycle=%016X\n",pc,totalcycles');$cmd.Add('go');$cmd.Add('printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s');$cmd.Add("save operation-$id-after.bin,0,800")
}}}
$cmd.Add('quit');$cmd|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{stem='serial-transmit';count=32;regions=@(,@(0x69C0,0x6A07));classification='Synthetic TX bit callback and post-reset tail, no helper skipped';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json -Depth 5|Set-Content "$run/provenance.json"
$args=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30')
$args|ConvertTo-Json|Set-Content "$run/arguments.json";Push-Location $run;try{& $MameExecutable @args *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location};if($code -ne 0){throw 'Invalid transport capture'};Write-Output $run

param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory);if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null;foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$cmd=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$cmd.Add('bpset 69fe')
$body=(Get-Content "$PSScriptRoot/../src/FruitMachineLab.Adders/AddersSerialBitPlan.cs" -Raw)+(Get-Content "$PSScriptRoot/../src/FruitMachineLab.Adders/AddersSerialBytePlan.cs" -Raw)
foreach($pc in (@(0x6961,0x6969,0x6979,0x6990,0x6997,0x699F,0x69A3)+@([regex]::Matches($body,'new NativeRoutineStep\(0x([0-9A-F]{4}),"')|ForEach-Object {[Convert]::ToInt32($_.Groups[1].Value,16)}|Sort-Object -Unique))){$cmd.Add(('bpset {0:X},1,{{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
foreach($value in @(0,1,2,3,0x80,0x81,0xFE,0xFF)){foreach($control in @(0,8,13,15)){
$id=$cases.Count;$cases.Add([ordered]@{id=$id;entry=0x693E;value=$value;control=$control;end=0x69FE;stack=0x6F8})
$cmd.Add(('pc=0x693e;a=0x89;b=0x{0:X};x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=4;b@b03=4;b@71=0;b@38e=0x{1:X}' -f $value,$control))
$cmd.Add("save operation-$id-before.bin,0,800");$cmd.Add('printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@c01,b@b03');$cmd.Add('go');$cmd.Add('printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x');$cmd.Add("save operation-$id-after.bin,0,800")
}}
$cmd.Add('quit');$cmd|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{stem='serial-byte';count=32;regions=@(,@(0x693E,0x69BF));classification='Synthetic original serial byte frames to69FE boundary; actual PIA reads, no timer bypass';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json -Depth 5|Set-Content "$run/provenance.json"
$args=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30')
$args|ConvertTo-Json|Set-Content "$run/arguments.json";Push-Location $run;try{& $MameExecutable @args *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location};if($code -ne 0){throw 'Invalid transport capture'};Write-Output $run

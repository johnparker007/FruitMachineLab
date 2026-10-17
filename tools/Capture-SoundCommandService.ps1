param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory,[switch]$Notes,[switch]$Calls,[switch]$Prompt)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory);if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null;foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$cmd=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$series=0;$cmd.Add('bpset 4c34')
$body='';foreach($name in @('Service','Release','Yield','Child','Instrument','Attenuation','Note')){$body+=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Adders/AddersSound${name}Plan.cs" -Raw};$body+=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Adders/AddersYmCachedWritePlan.cs" -Raw
foreach($pc in (@(0x5DC5,0x5DCC,0x5DD5,0x5D63,0x5D77,0x5D8B)+@([regex]::Matches($body,'new NativeRoutineStep\(0x([0-9A-F]{4}),"')|ForEach-Object {[Convert]::ToInt32($_.Groups[1].Value,16)}|Sort-Object -Unique))){$cmd.Add(('bpset {0:X},1,{{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
 $durations=if($Notes -or $Calls -or $Prompt){@(1)}else{@(0,1,16,255)}
foreach($free in @(0,0x1C5)){foreach($duration in $durations){foreach($flags in @(0,128)){foreach($tempo in @(0,16)){

$cmd.Add(('pc=0x5cd0;x=0x8784;y=0x1a0;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@45=0;w@47=0x1a0;w@49=0x{0:X};b@44=0;b@4d=0;b@4e=16' -f $free))
for($p=0x1A0;$p -lt 0x27E;$p++){$cmd.Add(('b@{0:X}=0' -f $p))}
$cmd.Add(('w@1a2=1;w@1a4=0x5d3b;w@1a6=0x1c5;w@1a8=0x600;w@1b3=0x600;b@1aa=0xff;b@1ab=0xa0;b@1ae=0x{0:X};b@1b2=0x{1:X};w@1c5=0x1ea;w@1ea=0x20f;w@20f=0x234;w@234=0x259;b@4b=0xff;b@4c=0xff' -f $tempo,$flags))
$cmd.Add(('b@600=0xc5;b@601=0xe0;b@602=0xc7;b@603=0x0c;b@604=0xc2;w@605=0x620;b@607=0xce;b@608=0x{0:X};b@609=0xc0;b@620=0xc5;b@621=0x10;b@622=0xce;b@623=1;b@624=0xc0' -f $duration))
if($Notes){$cmd.Add('w@605=0x8739')};if($Calls){$cmd.Add('b@600=0xc1;w@601=0x620;b@603=0xce;b@604=1;b@605=0xc0;b@620=0xc1;w@621=0x630;b@623=0xc0;b@630=0xc0')}
if($Prompt){$cmd.Add('w@1a8=0x8784;w@1b3=0x8784')}
for($tick=0;$tick -lt $(if($Prompt){16}elseif($Notes){12}elseif($Calls){3}else{1});$tick++){
$id=$cases.Count;$cases.Add([ordered]@{id=$id;series=$series;tick=$tick;free=$free;duration=$duration;flags=$flags;tempo=$tempo})
$cmd.Add('pc=0x5cd0;x=0x8784;y=0x1a0;u=0x600;s=0x700;dp=0;cc=0x50')
$cmd.Add("save operation-$id-before.bin,0,800");$cmd.Add('printf "OS pc=%04X cycle=%016X\n",pc,totalcycles');$cmd.Add('go');$cmd.Add('printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s');$cmd.Add("save operation-$id-after.bin,0,800")
}
$series++
}}}}
$cmd.Add('quit');$cmd|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{classification="Synthetic original native service calls: $($cases.Count) rows; actual8784 prompt=$Prompt; actual8739 child=$Notes; RAM foreground stream, synthetic caller cadence.";mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
$args=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30')
$args|ConvertTo-Json|Set-Content "$run/arguments.json";Push-Location $run;try{& $MameExecutable @args *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location};if($code -ne 0){throw 'Invalid operation capture'};Write-Output $run


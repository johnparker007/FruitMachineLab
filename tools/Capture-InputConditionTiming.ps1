param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory,[switch]$PayoutTail)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory);if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$commands.Add('bpset 4c34')
$body=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Runtime/Mpu4InputConditionPlan.cs" -Raw
if($PayoutTail){$body+=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Adders/AddersPayoutTailPlan.cs" -Raw;$body+=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Runtime/Mpu4QueueChecksumPlan.cs" -Raw}
$start=if($PayoutTail){0x4C91}else{0x67EC}
foreach($pc in ([regex]::Matches($body,'new NativeRoutineStep\(0x([0-9A-F]{4}),"')|ForEach-Object {[Convert]::ToInt32($_.Groups[1].Value,16)}|Sort-Object -Unique|Where-Object {$_ -ne $start})){$commands.Add(('bpset {0:X},1,{{printf "NI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
$selectors=if($PayoutTail){@(0x4ACA,0x4ADB,0x4AEC,0x4AFD)}else{@(0,4,0x1C,0x1F,0x40,0x82,0x87,0x91)}
foreach($selector in $selectors){foreach($pattern in @(0,1,2,3,4,5,6,7)){
 $id=$cases.Count;$cases.Add([ordered]@{id=$id;selector=$selector;pattern=$pattern})
 $commands.Add(('pc=0x67ec;x=0x100;y=0x4567;a=0x89;b=0xab;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@100=0x{0:X}' -f $selector))
 for($p=0;$p -lt 8;$p++){$value=switch($pattern){0{0} 1{255} 2{1 -shl ($p%8)} 3{0x55} 4{0xAA} 5{if($p -eq 0){255}else{0}} 6{if($p -eq 3){255}else{0}} 7{if($p -eq 6){255}else{0}}};$commands.Add(('b@{0:X}=0x{1:X}' -f $p,$value))}
 if($PayoutTail){$commands.Add(('pc=0x4c91;y=0x{0:X};b@2c=0x7a;b@373=0xa5' -f $selector));$tail=@(0,0,1,1,255,255,4,4)[$pattern];$level=if($pattern%2){255}else{0};$commands.Add(('b@(w@(y+1)+1)=0x{0:X};b@0=0x{1:X}' -f $tail,$level));$commands.Add('w@36b=w@36b&0x00ff;w@36d=w@36d&0x00ff;w@36f=w@36f&0x00ff;w@371=w@371&0x00ff')}
 $commands.Add("save condition-$id-before.bin,0,800");$commands.Add('printf "NS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)');$commands.Add('go');$commands.Add('printf "NF pc=%04X cycle=%016X a=%02X b=%02X cc=%02X x=%04X y=%04X u=%04X s=%04X\n",pc,totalcycles,a,b,cc,x,y,u,s');$commands.Add("save condition-$id-after.bin,0,800")
}}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{payout_tail=[bool]$PayoutTail;classification='Synthetic original67EC condition or4C91 payout tail calls with injected sampled inputs, masked IRQ. Not physical acquisition or natural gameplay.';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
Push-Location $run;try{& $MameExecutable @arguments *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location}
if($code -ne 0){throw 'Invalid input-condition capture'};Write-Output $run

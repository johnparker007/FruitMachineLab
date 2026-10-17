param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory,[switch]$Composed)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory);if(Test-Path $run){throw 'Use a fresh isolated directory'};New-Item -ItemType Directory $run|Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new()
foreach($pc in @($(if($Composed){0x280C}else{0x4395}),0x4604,0x4621)){$commands.Add(('bpset {0:X}' -f $pc))}
# Log each translated opcode plus the unchanged46D3 child. Current PC4592 is
# recorded explicitly because debugger go skips the breakpoint at current PC.
$source=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Runtime/Mpu4CoinServiceExecution.cs" -Raw
$addresses=@([regex]::Matches($source,'new\(0x([0-9A-F]{4}),"')|ForEach-Object {[Convert]::ToInt32($_.Groups[1].Value,16)})+@(0x46D3,0x46D5,0x46D7,0x46D9,0x46DB,0x46DD,0x46E0,0x46E1,0x46E3,0x46E6,0x46E8,0x46EA,0x46EC,0x46EF)
if($Composed){foreach($file in @('Mpu4PanelAccumulationExecution.cs','Mpu4CoinIdleExecution.cs')){$body=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Runtime/$file" -Raw;$addresses+=@([regex]::Matches($body,'new\(0x([0-9A-F]{4}),"')|ForEach-Object {[Convert]::ToInt32($_.Groups[1].Value,16)})}}
$entry=if($Composed){0x438C}else{0x4592}
foreach($pc in ($addresses|Sort-Object -Unique|Where-Object {$_ -ne $entry})){$commands.Add(('bpset {0:X},1,{{printf "SI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
foreach($variant in 0..7){foreach($level in 0..7){
 $id=$cases.Count;$flags=@(0,0x80,0x40,0x20,0,0,0,0)[$variant];$bank=@(0,1,0x4F,0x50,0,1,0,1)[$level];$first=@(0,9999,10000,65535,0,9990,0,65535)[$level];$second=if($level -in @(3,7)){2}elseif($level -eq 5){10}else{0};$port6=if($variant -band 1){255}else{0};$port7=if($variant -band 2){255}else{0};$reel0=if($variant -ge 4){0x73}else{0x72};$reel1=if($variant -ge 5){0xCD}else{0xCC};$guard=if($variant -ge 6){1}else{0};$enable=if($level -band 1){1}else{0};$port0=if($level -band 2){2}else{0};$latch=($id*37) -band 255
 if($Composed){$port6=0;$port7=0}
 $cases.Add([ordered]@{id=$id;flags=$flags;bank=$bank;first=$first;second=$second;port6=$port6;port7=$port7;reel0=$reel0;reel1=$reel1;guard=$guard;enable=$enable;port0=$port0;latch=$latch})
 $commands.Add(('temp1=0x{0:X};pc=0x4592;cc=0x50;dp=0;s=0x700;w@700=0x4395;b@2b=0x{1:X};b@2f0=0x{2:X};w@2fc=0x{3:X};w@302=0x{4:X};b@0x6=0x{5:X};b@0x7=0x{6:X};b@370=0x{7:X};b@372=0x{8:X};b@339=0x{9:X};b@338=0x{10:X};b@0x0=0x{11:X};b@c03=0;b@c02=0xff;b@c03=4;b@c02=0x69;b@f03=0;b@f02=0xff;b@f03=4;b@f02=0x{12:X}' -f $id,$flags,$bank,$first,$second,$port6,$port7,$reel0,$reel1,$guard,$enable,$port0,$latch))
 if($Composed){$commands.Add('pc=0x438c;w@700=0x280c;w@28=0;w@c6=0x19b8;b@0x2=0;b@0x5=0;b@89=0;b@2a=0;b@8a=0;b@c02=0;b@10=0;b@11=0;b@12=0;b@13=0;b@14=0;b@15=0;b@16=0;b@17=0;b@18=0;b@8e=0x12;b@96=0x3c')}
 $commands.Add('printf "SS id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)');$commands.Add('go')
 $commands.Add('printf "SF id=%X cycle=%016X pc=%04X s=%04X a=%02X b=%02X outc=%02X outf=%02X\n",temp1,totalcycles,pc,s,a,b,b@c02,b@f02')
}}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{classification='Synthetic original4592 service or composed438C idle route; injected RAM and all-output PIA latches, IRQ/FIRQ masked, ROM unpatched. Stops before alarm/helper or after return. No natural coin pin or whole-game claim';composed=[bool]$Composed;mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30');$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
Push-Location $run;try{& $MameExecutable @arguments *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location};if($code -ne 0 -or (Select-String "$run/debug.log" -Pattern '^Error ' -Quiet)){throw 'Invalid coin service experiment'};Write-Output $run

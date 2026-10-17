param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory)
if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new()
foreach($pc in @(0x438C,0x4167,0xFECE)){$commands.Add(('bpset {0:X}' -f $pc))}
$addresses=@(0xFEBC,0xFEBE,0xFEC0,0x27D2,0x27D4,0x27D6,0x27D8,0x27DA,0x27DB,0x27DD,0x27E0,0x27E2,0x27E4,0x27E7,0x27EA,0x27EC,0x27EF,0x27F3,0x27F6,0x27F8,0x27FA,0x27FE,0x2801,0x2803,0x2809)
foreach($pc in $addresses){$commands.Add(('bpset {0:X},1,{{printf "II id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
foreach($column in 0..7){foreach($variant in 0..7){
 $id=$cases.Count;$busy=if($variant -eq 7){1}else{0};$active=if($variant -band 2){1}else{0};$counter=if($variant -band 4){255}else{$variant -band 1};$alternate=if($variant -eq 6){1}else{0};$input=if($variant -band 1){0x81}else{0x5A}
 $cases.Add([ordered]@{id=$id;column=$column;busy=$busy;active=$active;counter=$counter;alternate=$alternate;input=$input;drive=0xA53C})
 $commands.Add(('temp1=0x{0:X};pc=0xfeba;cc=0x50;dp=0;s=0x700;w@28=0x{1:X};b@2c=0x{2:X};b@6c=0x{3:X};b@6e=0x{4:X};b@32f=0x{5:X};w@6f=0xa53c;b@f01=0;b@f00=0xff;b@f01=4;b@f00=0x{6:X};b@d03=0;b@d02=0xff;b@d03=4;b@d02=0;b@e01=0;b@e00=0xff;b@e01=4;b@e00=0' -f $id,$column,$busy,$active,$counter,$alternate,$input))
 $commands.Add(((0..7|ForEach-Object {'b@0x{0:X}=0x55' -f $_}) -join ';'))
 $commands.Add('printf "IS id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)');$commands.Add('go')
 $commands.Add('printf "IF id=%X cycle=%016X pc=%04X s=%04X busy=%02X counter=%02X bank0=%02X bank1=%02X port0=%02X port1=%02X port2=%02X port3=%02X port4=%02X port5=%02X port6=%02X port7=%02X\n",temp1,totalcycles,pc,s,b@2c,b@6e,b@d02,b@e00,b@0,b@1,b@2,b@3,b@4,b@5,b@6,b@7')
}}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{classification='Synthetic original FEBA/27D2 prefix, IRQ/FIRQ masked, injected RAM and PIA output-mode input substitute; stops before438C/4167/FECE executes, not natural input hardware or whole handler';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
Push-Location $run;try{& $MameExecutable @arguments *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location}
if($code -ne 0 -or (Select-String "$run/debug.log" -Pattern '^Error ' -Quiet)){throw 'Invalid input-service experiment'}
Write-Output $run

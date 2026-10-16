param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory)
if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$commands.Add('bpset 0x800')
$addresses=@(foreach($name in @('28fe','19c2','70ef')){ $native=Get-Content "$PSScriptRoot/../evidence/mpu4/native/$name.json" -Raw|ConvertFrom-Json; foreach($line in ($native.assembly -split "`n")){if($line -match '^([0-9a-fA-F]{4}) '){[Convert]::ToInt32($Matches[1],16)}} })+@(0x19FA,0x19FD,0x1A01,0x1A03)
foreach($pc in ($addresses|Sort-Object -Unique|Where-Object {$_ -ne 0x28FE})){
 $commands.Add(('bpset {0:X},1,{{printf "SI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))
}
foreach($column in 0..7){foreach($variant in 0..7){
 $id=$cases.Count;$phase=$variant -band 3;$count=if($variant -band 1){1}else{2};$alternate=if($variant -band 2){1}else{2};$alternateReload=if($variant -band 4){3}else{0};$sample=if($variant -eq 3){4}else{0};$sweep=if($variant -eq 2){0}else{255};$timer=@(40,30,300,65535)[$variant -band 3];$step=if($variant -band 4){254}else{2};$pulseCount=if($variant -band 1){2}else{0};$suppress=if($variant -eq 7){1}else{0}
 $case=[ordered]@{id=$id;column=$column;phase=$phase;count=$count;reload=3;alternate=$alternate;alternate_reload=$alternateReload;sample=$sample;sweep=$sweep;timer=$timer;step=$step;pulse_count=$pulseCount;pulse_reload=8;suppress=$suppress;decimal=0xAA;blink=0x55}
 $cases.Add($case)
 $commands.Add(('temp1=0x{0:X};pc=0x28fe;cc=0x50;dp=0;s=0x700;w@700=0x800;w@28=0x{1:X};b@23=0x{2:X};b@24=0x{3:X};b@25=3;b@26=0x{4:X};b@27=0x{5:X};b@8=0x{6:X};b@9=0x{6:X};b@0xa=0x{6:X};b@0xb=0x{6:X};b@0xc=0x{6:X};b@0xd=0x{6:X};b@0xe=0x{6:X};b@0xf=0x{6:X};b@b3=0x{7:X};w@32d=0x{8:X};b@ea=0x{9:X};b@e8=0x{10:X};b@e9=8;b@8d=0x{11:X};b@22=0xaa;b@1a=0x3f;b@1b=0x3f;b@1c=0x3f;b@1d=0x3f;b@1e=0x3f;b@1f=0x3f;b@20=0x3f;b@21=0x3f;b@2be=0x55;b@2bf=0x55;b@2c0=0x55;b@2c1=0x55;b@2c2=0x55;b@2c3=0x55;b@2c4=0x55;b@2c5=0x55;b@3f=0;b@40=0' -f $id,$column,$phase,$count,$alternate,$alternateReload,$sample,$sweep,$timer,$step,$pulseCount,$suppress))
 # Known PIA outputs and input sense low, isolated runtime injection only.
 $commands.Add('b@a01=0;b@a00=0xff;b@a01=4;b@a00=0xa5;b@a03=0;b@a02=0xff;b@a03=4;b@a02=0x5a;b@b01=0;b@b00=0xff;b@b01=4;b@b00=0xcc;b@b03=0;b@b02=0xff;b@b03=4;b@b02=0')
 $commands.Add('w@3d=0x48fd')
 $commands.Add(((0..7|ForEach-Object {'b@0x{0:X}=0x{1:X}' -f (8+$_),$sample}) -join ';'))
 $commands.Add(((0..63|ForEach-Object {'b@{0:X}=0x{1:X}' -f (0x100+$_),(($_*37+11) -band 255)}) -join ';'))
 $commands.Add('printf "SS id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)');$commands.Add('go')
 $commands.Add('printf "SF id=%X cycle=%016X pc=%04X s=%04X phase=%02X count=%02X alternate=%02X column=%04X pulse_count=%02X step=%02X timer=%04X callback=%04X control2=%02X control3=%02X bank0=%02X bank1=%02X display=%02X\n",temp1,totalcycles,pc,s,b@23,b@24,b@26,w@28,b@e8,b@ea,w@32d,w@3d,b@3f,b@40,b@a00,b@a02,b@b00')
}}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{classification='Synthetic isolated original28FE calls, masked CPU IRQ/FIRQ, injected RAM/PIA state, not natural gameplay';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
Push-Location $run;try{& $MameExecutable @arguments *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location}
if($code -ne 0 -or (Select-String "$run/debug.log" -Pattern '^Error ' -Quiet)){throw 'Invalid scan experiment'}
Write-Output $run

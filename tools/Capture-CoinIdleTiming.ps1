param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory);if(Test-Path $run){throw 'Use a fresh isolated directory'};New-Item -ItemType Directory $run|Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new()
foreach($pc in @(0x43F1,0x4426,0x44AB,0x4562,0x4519,0x4592)){$commands.Add(('bpset {0:X}' -f $pc))}
foreach($pc in @(0x43ED,0x43EF,0x4409,0x440B,0x440D,0x440F,0x4413,0x4415,0x4417,0x4419,0x441B,0x441C,0x4497,0x4499,0x449B,0x449D,0x449F,0x44A1,0x44A3,0x44A5,0x44A7,0x44A9,0x44BD,0x44BF,0x44C1,0x44C3,0x44C6,0x44CA,0x44CC,0x44CE,0x44D0,0x44D2,0x44D4,0x44D8,0x44DA,0x44DC,0x44DE,0x44E0,0x44E4,0x44E6,0x44E8,0x4510,0x4512,0x4514,0x4516,0x4517,0x4587,0x4589,0x458B,0x458E)){$commands.Add(('bpset {0:X},1,{{printf "CI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
foreach($variant in 0..7){foreach($level in 0..7){
 $id=$cases.Count;$a=@(0,2,4,0,0,0,0,0)[$variant];$state=if($variant -eq 3){$level+1}else{0};$sticky=@(0,1,2,4,0x10,0x80,0xF0,0xFF)[$level];$counter=@(0,1,0x7F,0x80,0xFF,1,0x7F,0)[$variant]
 $cases.Add([ordered]@{id=$id;a=$a;state=$state;sticky=$sticky;counter=$counter})
 $commands.Add(('temp1=0x{0:X};pc=0x43e9;cc=0x50;dp=0;s=0x700;a=0x{1:X};b@8a=0x{2:X};b@2a=0x{3:X};b@10=0x55;b@11=0x66;b@8b=0x77;b@df=0x88' -f $id,$a,$state,$sticky))
 foreach($p in 0x12..0x18){$commands.Add(('b@{0:X}=0x{1:X}' -f $p,$counter))}
 $commands.Add('printf "CS id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)');$commands.Add('go')
 $commands.Add('printf "CF id=%X cycle=%016X pc=%04X s=%04X sticky=%02X state=%02X c10=%02X c11=%02X c12=%02X c13=%02X c14=%02X c15=%02X c16=%02X c17=%02X c18=%02X c8b=%02X cdf=%02X\n",temp1,totalcycles,pc,s,b@2a,b@8a,b@10,b@11,b@12,b@13,b@14,b@15,b@16,b@17,b@18,b@8b,b@df')
}}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{classification='Synthetic bounded43E9 calls, injected A/RAM, IRQ/FIRQ masked, original ROM coin records. Stops before active pulse/alarm/post-table service; no gameplay claim';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30');$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
Push-Location $run;try{& $MameExecutable @arguments *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location};if($code -ne 0 -or (Select-String "$run/debug.log" -Pattern '^Error ' -Quiet)){throw 'Invalid coin idle experiment'};Write-Output $run

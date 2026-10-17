param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory);if(Test-Path $run){throw 'Use a fresh isolated directory'};New-Item -ItemType Directory $run|Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$commands.Add('bpset 0x501')
foreach($pc in @(0x46D5,0x46D7,0x46D9,0x46DB,0x46DD,0x46E0,0x46E1,0x46E3,0x46E6,0x46E8,0x46EA,0x46EC,0x46EF)){$commands.Add(('bpset {0:X},1,{{printf "AI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
foreach($selector in @(0,8,0x3F,0x40,0x7F,0x80,0x88,0xFF)){foreach($variant in 0..7){
 $id=$cases.Count;$port6=if($variant -band 1){255}else{0};$port7=if($variant -band 2){255}else{0};$cc=0x50 -bor $(if($variant -band 4){0xAF}else{0})
 $cases.Add([ordered]@{id=$id;selector=$selector;port6=$port6;port7=$port7;cc=$cc})
 $commands.Add(('temp1=0x{0:X};pc=0x46d3;cc=0x{1:X};dp=0;s=0x700;w@700=0x500;b@500=0x{2:X};b@0x6=0x{3:X};b@0x7=0x{4:X};a=0x12;b=0x34;x=0x5678;y=0x9abc;u=0xdef0' -f $id,$cc,$selector,$port6,$port7))
 $commands.Add('printf "AS id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)');$commands.Add('go')
 $commands.Add('printf "AF id=%X cycle=%016X pc=%04X s=%04X a=%02X b=%02X x=%04X y=%04X u=%04X cc=%02X return=%04X\n",temp1,totalcycles,pc,s,a,b,x,y,u,cc,w@700')
}}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{classification='Synthetic isolated original46D3 calls with RAM inline byte/return frame and masked IRQ/FIRQ; original ROM table, boundary selectors included; not natural gameplay';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30');$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
Push-Location $run;try{& $MameExecutable @arguments *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location};if($code -ne 0 -or (Select-String "$run/debug.log" -Pattern '^Error ' -Quiet)){throw 'Invalid inline auxiliary experiment'};Write-Output $run

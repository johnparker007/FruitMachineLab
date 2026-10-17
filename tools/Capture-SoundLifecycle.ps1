param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory);if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null;foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$commands.Add('bpset 4c34')
foreach($kind in @('release','cancel','finish')){foreach($rhythm in @(0,0x21)){foreach($count in @(0,1,3,6)){foreach($tail in @(0,1)){
$id=$cases.Count;$entry=switch($kind){release{0x5E2C} cancel{0x5C7A} finish{0x5E6D}}
$cases.Add([ordered]@{id=$id;kind=$kind;entry=$entry;rhythm=$rhythm;channels=$count;tail=$tail})
$commands.Add(('pc=0x{0:X};s=0x700;u=0x600;x=0x8784;y=0x1a0;dp=0;cc=0x50;w@700=0x4c34;b@719b=0;b@44=0;w@45=0x1234;w@47=0x1c5;w@49=0x1ea;w@1c5=0;w@1c7=0x9999;w@1d8=0x8888;w@1a0=0x1c5;w@1b3=0x8784;w@1a6=0x1c5;b@1b1=0x{1:X};b@1af=0x55' -f $entry,$rhythm))
# Channel chains use each valid id exactly once; nonempty free-list cases reserve channel5.
$owned=$count;if($tail -eq 1 -and $count -eq 6){$owned=5};$cases[$id].channels=$owned
$commands.Add(('b@1aa=0x{0:X};b@4b=0x{1:X};b@4c=0x{1:X}' -f $(if($owned){0}else{255}),$(if($tail){5}else{255})))
for($n=0;$n -lt 6;$n++){$next=if($n+1 -lt $owned){$n+1}else{255};$commands.Add(('b@{0:X}=0x{1:X};b@{2:X}=0x{3:X}' -f (0x27E+$n),$next,(0x2A4+$n),(0xF0+$n)))}
$commands.Add('b@292=0xff')
if($kind -eq 'cancel'){$commands.Add('w@47=0x1a0')};if($kind -eq 'finish'){$commands.Add('b@44=1')}
$commands.Add("save lifecycle-$id-before.bin,0,800");$commands.Add('printf "LS pc=%04X cycle=%016X\n",pc,totalcycles');$commands.Add('go');$commands.Add('printf "LF pc=%04X cycle=%016X s=%04X u=%04X y=%04X\n",pc,totalcycles,s,u,y');$commands.Add("save lifecycle-$id-after.bin,0,800")
}}}}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{classification='48 synthetic original sound release/cancel/root-return calls; explicit channel lists, masked IRQ. No audio or natural scheduler timing claim.';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json";Push-Location $run;try{& $MameExecutable @arguments *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location};if($code -ne 0){throw 'Invalid lifecycle capture'};Write-Output $run



param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory);if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$commands.Add('bpset 4ccb')
$body=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Runtime/Mpu4NvramExecution.cs" -Raw
foreach($pc in ([regex]::Matches($body,'new\(0x([0-9A-F]{4}),"')|ForEach-Object {[Convert]::ToInt32($_.Groups[1].Value,16)}|Sort-Object -Unique|Where-Object {$_ -ne 0x6E06})) {
 $commands.Add(('bpset {0:X},1,{{printf "NI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))
}
foreach($mode in @(0,127,128,255)){foreach($guard in @(0,122)){foreach($pattern in @(0,1,255)){
 $id=$cases.Count;$cases.Add([ordered]@{id=$id;mode=$mode;guard=$guard;pattern=$pattern})
 $commands.Add(('temp1=0x{0:X};pc=0x6e06;cc=0x50;dp=0;s=0x790;u=0x600;w@790=0x4ccb;b@323=0x{1:X};b@2c=0x{2:X};b@322=0xa5' -f $id,$mode,$guard))
 for($at=0x2F0;$at -lt 0x309;$at++){$value=if($pattern -eq 1){($at*37+11)-band 255}else{$pattern};$commands.Add(('b@{0:X}=0x{1:X}' -f $at,$value))}
 $commands.Add(('save nvram-{0}-before.bin,0,800' -f $id));$commands.Add('printf "NS id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)');$commands.Add('go')
 $commands.Add('printf "NF id=%X pc=%04X cycle=%016X u=%04X s=%04X\n",temp1,pc,totalcycles,u,s');$commands.Add(('save nvram-{0}-after.bin,0,800' -f $id))
}}}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{classification='24 synthetic isolated original-ROM6E06 calls, masked IRQ, injected RAM and native return frame. No natural gameplay or interrupt-delivery timing claim.';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
Push-Location $run;try{& $MameExecutable @arguments *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location}
if($code -ne 0){throw 'Invalid NVRAM capture'};Write-Output $run

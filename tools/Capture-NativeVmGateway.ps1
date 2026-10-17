param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$SeedRam,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory);if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
Copy-Item $SeedRam "$run/seed.bin"
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new()
foreach($line in @('temp0=0','bpset fc,temp0==1','bpset 76f6,temp0==0','bpset 4cd1','wpset 80c,1,w,1,{printf "GW cycle=%016X value=%02X\n",totalcycles,wpdata;go}')){$commands.Add($line)}
$body=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Runtime/Mpu4NativeVmGatewayExecution.cs" -Raw
foreach($pc in ([regex]::Matches($body,'new\(0x([0-9A-F]{4}),"')|ForEach-Object {[Convert]::ToInt32($_.Groups[1].Value,16)}|Sort-Object -Unique|Where-Object {$_ -notin @(0x76BF,0x76F6)})) {
 $commands.Add(('bpset {0:X},temp0==1,{{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))
}
foreach($initialised in @(0,1)){foreach($flag in @(0,1,8,255)){
 $id=$cases.Count;$cases.Add([ordered]@{id=$id;initialised=$initialised;flag=$flag})
 foreach($line in @('load seed.bin,0','temp0=0','pc=0x76bf','a=0x12','b=0x34','dp=0','cc=0x50','x=0xa8f9','y=0xbeef','u=0x600','s=0x790','w@790=0x4cd1','w@f2=0x456','w@a0=1','w@f8=0x3420','w@fa=0x3184','w@fc=0xaea1','w@fe=0x6e91',('b@f1=0x'+$flag.ToString('X2')))){$commands.Add($line)}
 if(!$initialised){$commands.Add('b@f8=0')}
 foreach($line in @("save gateway-$id-before.bin,0,800",'printf "GS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)','temp0=1','go','temp0=0',"save gateway-$id-entry.bin,0,800",'printf "GX pc=%04X cycle=%016X x=%04X y=%04X u=%04X s=%04X\n",pc,totalcycles,x,y,u,s','go',"save gateway-$id-return.bin,0,800",'printf "GR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)','temp0=1','go','temp0=0',"save gateway-$id-after.bin,0,800",'printf "GF pc=%04X cycle=%016X a=%02X b=%02X dp=%02X cc=%02X x=%04X y=%04X u=%04X s=%04X\n",pc,totalcycles,a,b,dp,cc,x,y,u,s')){$commands.Add($line)}
}}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{classification='Eight synthetic isolated original76BF gateways, real suppressed A8F9 VM body, masked IRQ. Initial trampoline andF1 vary. No natural gameplay/IRQ claim.';mame_sha256=(Get-FileHash $MameExecutable).Hash;seed_sha256=(Get-FileHash "$run/seed.bin").Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
Push-Location $run;try{& $MameExecutable @arguments *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location}
if($code -ne 0){throw 'Invalid gateway capture'};Write-Output $run

param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$SeedRam,[Parameter(Mandatory=$true)][string]$RunDirectory,[switch]$InstructionTiming)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory)
if(Test-Path -LiteralPath $run){throw 'Use a fresh directory'}
New-Item -ItemType Directory -Path $run|Out-Null
foreach($name in @('cfg','nvram','state','snap','diff','comments')){New-Item -ItemType Directory (Join-Path $run $name)|Out-Null}
Copy-Item -LiteralPath $SeedRam -Destination "$run/seed.bin"
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$id=0
if($InstructionTiming){
 $commands.Add('temp0=0');$commands.Add('bpset 76bf,temp0==1');$commands.Add('bpset 4cd1,temp0==0');$commands.Add('bpset 6858');$pcs=[Collections.Generic.HashSet[int]]::new()
 $commands.Add('bpset fc,temp0==0,{printf "DV y=%04X token=%04X cycle=%016X u=%04X top=%04X second=%04X s=%04X\n",y,w@y,totalcycles,u,w@u,w@(u+2),s;go}')
 $commands.Add('bpset 76f6,temp0==0,{printf "DG cycle=%016X s=%04X u=%04X\n",totalcycles,s,u;go}')
 foreach($entry in @('4cbe','6e06','6e0d','57f7','59a4','6fec','6fc1','68e0')){
  $native=Get-Content "$PSScriptRoot/../evidence/mpu4/native/$entry.json" -Raw|ConvertFrom-Json
  foreach($match in [regex]::Matches($native.assembly,'(?m)^([0-9a-f]{4}) ')){[void]$pcs.Add([Convert]::ToInt32($match.Groups[1].Value,16))}
 }
 foreach($pc in @(0x6E05,0x57A9,0x57AB,0x57AC,0x57AE,0x57B0,0x57B2,0x57B4,0x57B6,0x7032,0x7034,0x7037,0x7039,0x703B,0x703E,0x7040,0x7042,0x7044,0x7047,0x7009,0x700C,0x700D,0x700F,0x7011,0x7012,0x7015,0x7017,0x7018)){[void]$pcs.Add($pc)}
 foreach($pc in ($pcs|Sort-Object|Where-Object {$_ -notin @(0x4CBE,0x4CD1)})){$commands.Add(('bpset {0:X},temp0==1,{{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
}
foreach($record in @(0x4ACA,0x4ADB,0x4AEC,0x4AFD)){foreach($mode in @(0,128)){foreach($suppressed in @(0,1)){foreach($value in @(0,65535)){
 $name="debit-$id";$id++;$cases.Add([ordered]@{id=$name;record=$record;mode=$mode;suppressed=$suppressed;balance=$value})
 $pointer=if($record -lt 0x4AEC){0x2FE}else{0x300}
 foreach($command in @('load seed.bin,0','s=0x790','u=0x600','dp=0','cc=0x50',('b@0x323=0x'+$mode.ToString('X2')),('w@0xa0=0x'+$suppressed.ToString('X4')),'b@0x55=0x1f','b@0x57=0','b@0x54=0','b@0xc5=0',('w@0x'+$pointer.ToString('X4')+'=0x'+$value.ToString('X4')),'b@0x3a=0x80','w@0x35e=0xfffe','w@0x360=0xfffe','w@0x362=0xfffe','w@0x364=0xfffe','w@0x366=0xfffe','w@0x368=0xfffe','w@0x36b=0xff01','w@0x36d=0xff02','w@0x36f=0xff03','w@0x371=0xff04','b@0x3e6=0xff','w@0x3e7=0xfffe','b@0x3ec=0xff','w@0x3ed=0xfffe','b@0x419=0xff','w@0x41a=0xfffe','b@0x41c=0xff','w@0x41d=0xfffe','b@0x41f=0xff','w@0x420=0xfffe','b@0x425=0xff','w@0x426=0xfffe',"save $name-before.bin,0,800",('y=0x'+$record.ToString('X4')),'pc=0x4cbe','g 0x6858',"save $name-after.bin,0,800",('printf "PAYOUT '+$name+' pc=%04X u=%04X y=%04X\n",pc,u,y'))) {$commands.Add($command)}
 if($InstructionTiming){
  # Replace this case's straight run with two timed spans around the real VM call.
  $go=$commands.Count-3
  if($commands[$go] -ne 'g 0x6858'){throw 'Unexpected debit command layout'}
  $commands.RemoveAt($go)
  $insert=@('printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)','temp0=1','g 0x76bf','temp0=0',"save $name-display-entry.bin,0,800",'printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s','g 0x4cd1',"save $name-display-return.bin,0,800",'printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)','temp0=1','g 0x6858','temp0=0','printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u')
  foreach($item in $insert){$commands.Insert($go,$item);$go++}
 }
}}}}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json -Depth 4|Set-Content "$run/cases.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-state_directory',"$run/state",'-snapshot_directory',"$run/snap",'-diff_directory',"$run/diff",'-comment_directory',"$run/comments",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
[ordered]@{instruction_timing=[bool]$InstructionTiming;classification='Synthetic isolated native4CBE, real nested VM display call, stop before6858; explicit registers/RAM and IRQ masked. Optional instruction logging separates76BF display owner. No natural payout or timing claim.';mame_sha256=(Get-FileHash $MameExecutable).Hash;seed_sha256=(Get-FileHash "$run/seed.bin").Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
Push-Location $run
try{& $MameExecutable @arguments *> "$run/console.txt";$LASTEXITCODE|Set-Content "$run/exit-code.txt"}finally{Pop-Location}
if($LASTEXITCODE -ne 0){throw 'MAME payout matrix failed'}
Write-Output $run

param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$SeedRam,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory)
if(Test-Path -LiteralPath $run){throw 'Use a fresh directory'}
New-Item -ItemType Directory -Path $run|Out-Null
foreach($name in @('cfg','nvram','state','snap','diff','comments')){New-Item -ItemType Directory (Join-Path $run $name)|Out-Null}
Copy-Item -LiteralPath $SeedRam -Destination "$run/seed.bin"
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$id=0
foreach($record in @(0x4ACA,0x4ADB,0x4AEC,0x4AFD)){foreach($mode in @(0,128)){foreach($suppressed in @(0,1)){foreach($value in @(0,65535)){
 $name="debit-$id";$id++;$cases.Add([ordered]@{id=$name;record=$record;mode=$mode;suppressed=$suppressed;balance=$value})
 $pointer=if($record -lt 0x4AEC){0x2FE}else{0x300}
 foreach($command in @('load seed.bin,0','s=0x790','u=0x600','dp=0','cc=0x50',('b@0x323=0x'+$mode.ToString('X2')),('w@0xa0=0x'+$suppressed.ToString('X4')),'b@0x55=0x1f','b@0x57=0','b@0x54=0','b@0xc5=0',('w@0x'+$pointer.ToString('X4')+'=0x'+$value.ToString('X4')),'b@0x3a=0x80','w@0x35e=0xfffe','w@0x360=0xfffe','w@0x362=0xfffe','w@0x364=0xfffe','w@0x366=0xfffe','w@0x368=0xfffe','w@0x36b=0xff01','w@0x36d=0xff02','w@0x36f=0xff03','w@0x371=0xff04','b@0x3e6=0xff','w@0x3e7=0xfffe','b@0x3ec=0xff','w@0x3ed=0xfffe','b@0x419=0xff','w@0x41a=0xfffe','b@0x41c=0xff','w@0x41d=0xfffe','b@0x41f=0xff','w@0x420=0xfffe','b@0x425=0xff','w@0x426=0xfffe',"save $name-before.bin,0,800",('y=0x'+$record.ToString('X4')),'pc=0x4cbe','g 0x6858',"save $name-after.bin,0,800",('printf "PAYOUT '+$name+' pc=%04X u=%04X y=%04X\n",pc,u,y'))) {$commands.Add($command)}
}}}}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json -Depth 4|Set-Content "$run/cases.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-state_directory',"$run/state",'-snapshot_directory',"$run/snap",'-diff_directory',"$run/diff",'-comment_directory',"$run/comments",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
[ordered]@{classification='Synthetic isolated native4CBE, real nested VM display call, stop before6858; explicit registers/RAM and IRQ masked. No natural payout or timing claim.';mame_sha256=(Get-FileHash $MameExecutable).Hash;seed_sha256=(Get-FileHash "$run/seed.bin").Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
Push-Location $run
try{& $MameExecutable @arguments *> "$run/console.txt";$LASTEXITCODE|Set-Content "$run/exit-code.txt"}finally{Pop-Location}
if($LASTEXITCODE -ne 0){throw 'MAME payout matrix failed'}
Write-Output $run

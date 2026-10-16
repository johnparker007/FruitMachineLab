param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$SeedRam,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory)
if(Test-Path -LiteralPath $run){throw 'Use a fresh directory'}
New-Item -ItemType Directory -Path $run|Out-Null
foreach($name in @('cfg','nvram','state','snap','diff','comments')){New-Item -ItemType Directory (Join-Path $run $name)|Out-Null}
Copy-Item -LiteralPath $SeedRam -Destination "$run/seed.bin"
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$number=0
$commands.Add('bpset 0x7000')
$commands.Add('bpset 0x49c5,1,{printf "SL id=%02X pattern=%02X\n",a,b;go}')
foreach($spec in @(@(0,0,15,32,0),@(0,0,0,32,0),@(0,0,15,0,0),@(0,0,15,32,4),@(0,0,15,32,8),@(0,0,15,32,12),@(1,0,7,0,12),@(1,0,6,0,12),@(1,0,6,0,4),@(1,0,6,0,8),@(1,1,0,32,12),@(0,1,15,32,0),@(255,0,14,32,12),@(0,0,7,32,12))){
 $id='status-'+$number;$number++;$cases.Add([ordered]@{id=$id;mode=$spec[0];inhibit=$spec[1];aux=$spec[2];triac=$spec[3];input0=$spec[4]})
 foreach($command in @('load seed.bin,0','s=0x790','cc=0x50','dp=0','w@0x790=0x7000',('b@0x32f=0x'+$spec[0].ToString('X2')),('b@0x338=0x'+$spec[1].ToString('X2')),('b@0=0x'+$spec[4].ToString('X2')),'b@0xc03=0','b@0xc02=0xf','b@0xc03=0x3c',('b@0xc02=0x'+$spec[2].ToString('X2')),'b@0xf03=0','b@0xf02=0xff','b@0xf03=0x34',('b@0xf02=0x'+$spec[3].ToString('X2')),('printf "CASE '+$id+'\n"'),"save $id-before.bin,0,800",'pc=0x482f','g',('printf "DONE '+$id+'\n"'))){$commands.Add($command)}
}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json -Depth 4|Set-Content "$run/cases.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-state_directory',"$run/state",'-snapshot_directory',"$run/snap",'-diff_directory',"$run/diff",'-comment_directory',"$run/comments",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
[ordered]@{classification='Synthetic native482F branch matrix; explicit port/flag/input setup, masked IRQs; not a natural game path';mame_sha256=(Get-FileHash $MameExecutable).Hash;seed_sha256=(Get-FileHash "$run/seed.bin").Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
Push-Location $run
try{& $MameExecutable @arguments *> "$run/console.txt";$LASTEXITCODE|Set-Content "$run/exit-code.txt"}finally{Pop-Location}
if($LASTEXITCODE -ne 0){throw 'MAME matrix failed'}
Write-Output $run

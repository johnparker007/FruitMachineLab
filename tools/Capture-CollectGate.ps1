param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$SeedRam,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory)
if(Test-Path -LiteralPath $run){throw 'Use a fresh directory'}
New-Item -ItemType Directory -Path $run|Out-Null
foreach($name in @('cfg','nvram','state','snap','diff','comments')){New-Item -ItemType Directory (Join-Path $run $name)|Out-Null}
Copy-Item -LiteralPath $SeedRam -Destination "$run/seed.bin"
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$id=0
$commands.Add('bpset 0x4c34');$commands.Add('temp0=0');$commands.Add('wpset 0xf02,1,w,temp0==1,{printf "PO id=%02X value=%02X\n",temp1,wpdata;go}')
$commands.Add('bpset 0x7172,temp0==1,{pc=0x7199;go}')
$commands.Add('bpset 0x4cbe,temp0==1,{printf "PD id=%02X record=%04X balance=%04X\n",temp1,y,w@(w@(y+5));go}')
foreach($credits in @(0,1)){foreach($pressed in @(0,1)){foreach($tick in @(0,0x6400,0x6401,0x8000)){foreach($scottish in @(0,4)){
 $name="gate-$id";$cases.Add([ordered]@{id=$id;name=$name;entry=0xAB1B;credits=$credits;pressed=$pressed;tick=$tick;scottish=$scottish})
 $setup=@('temp0=0','load seed.bin,0','s=0x790','u=0x600','dp=0','cc=0x50','w@0x790=0x4c34','b@0x323=0','w@0xa0=0','b@0x55=0x1f','b@0x57=0','b@0x54=0','b@0xc5=0','w@0x2fc=0x18','w@0x2fe=0','w@0x300=0','w@0x302=0',('b@0x2f0=0x'+$credits.ToString('X2')),('b@3=0x'+$pressed.ToString('X2')),('w@0x2d=0x'+$tick.ToString('X4')),'b@0=0','b@1=0','b@2=0',('b@6=0x'+$scottish.ToString('X2')),'b@7=0','w@0x47=0','b@0x3a=0x80','w@0x36b=0','w@0x36d=0','w@0x36f=0','w@0x371=0','b@0xf03=0x30','b@0xf02=0xff','b@0xf03=0x34','b@0xf02=0x30',"save $name-before.bin,0,800",('temp1=0x'+$id.ToString('X2')),'temp0=1','x=0xab1b','pc=0x76bf','g','temp0=0',"save $name-after.bin,0,800",('printf "PF id=%02X pc=%04X u=%04X result=%04X\n",temp1,pc,u,w@u'))
 foreach($command in $setup){$commands.Add($command)};$id++
}}}}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json -Depth 4|Set-Content "$run/cases.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-state_directory',"$run/state",'-snapshot_directory',"$run/snap",'-diff_directory',"$run/diff",'-comment_directory',"$run/comments",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
[ordered]@{collect_gate=$true;classification='Synthetic original-ROM76BF->AB1B credit/collect gate, direct sampled port3 levels and tick/credit prerequisites. IRQ masked;7172 waits skipped via7199 RTS; not natural input acquisition/timing.';mame_sha256=(Get-FileHash $MameExecutable).Hash;seed_sha256=(Get-FileHash "$run/seed.bin").Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
Push-Location $run
try{& $MameExecutable @arguments *> "$run/console.txt";$LASTEXITCODE|Set-Content "$run/exit-code.txt"}finally{Pop-Location}
if($LASTEXITCODE -ne 0){throw 'MAME collect gate matrix failed'}
Write-Output $run

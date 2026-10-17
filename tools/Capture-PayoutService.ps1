param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$SeedRam,[Parameter(Mandatory=$true)][string]$RunDirectory,[switch]$Collection)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory)
if(Test-Path -LiteralPath $run){throw 'Use a fresh directory'}
New-Item -ItemType Directory -Path $run|Out-Null
foreach($name in @('cfg','nvram','state','snap','diff','comments')){New-Item -ItemType Directory (Join-Path $run $name)|Out-Null}
Copy-Item -LiteralPath $SeedRam -Destination "$run/seed.bin"
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$id=0
$commands.Add('bpset 0x4c34');$commands.Add('temp0=0');$commands.Add('wpset 0xf02,1,w,temp0==1,{printf "PO id=%02X value=%02X\n",temp1,wpdata;go}')
$commands.Add('bpset 0x7172,temp0==1,{pc=0x7199;go}')
$commands.Add('bpset 0x4cbe,temp0==1,{printf "PD id=%02X record=%04X balance=%04X\n",temp1,y,w@(w@(y+5));go}')
foreach($entry in @(0x4B39,0x4B8C)){foreach($scottish in @(0,4)){foreach($levels in @(0,15)){foreach($small in @($true,$false)){
 $name="service-$id";$amount=if($small){2}elseif($entry -eq 0x4B39){24}else{6};$cases.Add([ordered]@{id=$id;name=$name;entry=$entry;scottish=$scottish;levels=$levels;amount=$amount})
 $pointer=if($entry -eq 0x4B39){0x2FE}else{0x300}; $prepare=@(); if($Collection){ $cases[$cases.Count-1].entry=0xAA2B; $prepare=@('w@0x2fc=0','w@0x2fe=0','w@0x300=0','w@0x302=0'); $bank=if($levels -eq 15){$pointer}elseif($entry -eq 0x4B39){0x2FC}else{0x302}; $amount=if(!$small -and $entry -eq 0x4B8C){20}elseif(!$small -and $scottish -eq 4){20}else{$amount};$cases[$cases.Count-1].amount=$amount; $prepare+=('w@0x'+$bank.ToString('X4')+'=0x'+$amount.ToString('X4')) }
 foreach($command in @('temp0=0','load seed.bin,0','s=0x790','u=0x600','dp=0','cc=0x50','w@0x790=0x4c34','b@0x323=0','w@0xa0=0','b@0x55=0x1f','b@0x57=0','b@0x54=0','b@0xc5=0','w@0x2fe=0','w@0x300=0',('w@0x'+$pointer.ToString('X4')+'=0x'+$amount.ToString('X4')),('b@0=0x'+$levels.ToString('X2')),'b@1=0','b@2=0','b@3=0',('b@6=0x'+$scottish.ToString('X2')),'b@7=0','b@0x3a=0x80','w@0x36b=0','w@0x36d=0','w@0x36f=0','w@0x371=0','w@0x7d2=0x8000','b@0x7d4=0','b@0xf03=0x30','b@0xf02=0xff','b@0xf03=0x34','b@0xf02=0x30',$(if($Collection){$prepare}),"save $name-before.bin,0,800",('temp1=0x'+$id.ToString('X2')),'temp0=1',$(if($Collection){'x=0xaa2b';'pc=0x76bf'}else{'pc=0x'+$entry.ToString('X4')}),'g','temp0=0',"save $name-after.bin,0,800",('printf "PF id=%02X pc=%04X u=%04X\n",temp1,pc,u'))) {foreach($piece in @($command)){$commands.Add([string]$piece)}}
 $id++
}}}}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json -Depth 4|Set-Content "$run/cases.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-state_directory',"$run/state",'-snapshot_directory',"$run/snap",'-diff_directory',"$run/diff",'-comment_directory',"$run/comments",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
[ordered]@{collection=[bool]$Collection;classification='Synthetic original-ROM4B39/4B8C service. IRQ masked, debugger skips7172 calls via native7199 RTS, serial enabled by unchanged ROM71A1, explicit PIA DDR/output and level inputs. Not natural timing.';mame_sha256=(Get-FileHash $MameExecutable).Hash;seed_sha256=(Get-FileHash "$run/seed.bin").Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
Push-Location $run
try{& $MameExecutable @arguments *> "$run/console.txt";$LASTEXITCODE|Set-Content "$run/exit-code.txt"}finally{Pop-Location}
if($LASTEXITCODE -ne 0){throw 'MAME payout service matrix failed'}
Write-Output $run

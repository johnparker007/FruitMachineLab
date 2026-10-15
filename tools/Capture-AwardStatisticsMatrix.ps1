param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$SeedRam,[Parameter(Mandatory=$true)][string]$RunDirectory,[switch]$Scaled)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory)
if(Test-Path -LiteralPath $run){throw 'Use a fresh directory'}
New-Item -ItemType Directory -Path $run|Out-Null
foreach($name in @('cfg','nvram','state','snap','diff','comments')){New-Item -ItemType Directory (Join-Path $run $name)|Out-Null}
Copy-Item -LiteralPath $SeedRam -Destination "$run/seed.bin"
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$number=0
if(!$Scaled){foreach($global in @($true,$false)){foreach($spec in @(@(0,0,0),@(1,1,0),@(255,2,0),@(256,3,0),@(65535,4,0),@(257,0,0),@(16,1,127),@(16,1,128),@(16,1,255),@(65535,0,0),@(256,258,0))){
 $id='statistics-'+$number;$number++;$amount=$spec[0];$selector=$spec[1];$mode=$spec[2];$indexed=0x43A+6*($selector -band 255)
 $cases.Add([ordered]@{id=$id;global=$global;amount=$amount;selector=$selector;mode=$mode})
 foreach($command in @('load seed.bin,0','s=0x790','cc=0x50',('x=0x'+$amount.ToString('X4')),('y=0x'+$selector.ToString('X4')),('b@0x323=0x'+$mode.ToString('X2')),'w@0x43a=0xffff','b@0x43c=0xff','w@0x43d=0xffff','b@0x43f=0xf0',('w@0x'+$indexed.ToString('X4')+'=0xffff'),('b@0x'+($indexed+2).ToString('X4')+'=0xff'),('w@0x'+($indexed+3).ToString('X4')+'=0xffff'),('b@0x'+($indexed+5).ToString('X4')+'=0xf0'),"save $id-before.bin,0,800",$(if($global){'pc=0x1622'}else{'pc=0x166d'}),$(if($global){'g 0x166b'}else{'g 0x1699'}),"save $id-after.bin,0,800",('printf "MATRIX '+$id+' x=%04X y=%04X\n",x,y'))){$commands.Add($command)}
}}
}
if($Scaled){foreach($spec in @(@(0,0,0,0),@(1,1,0,0),@(16,4,0,0),@(255,2,0,0),@(256,3,0,0),@(65535,0,0,0),@(16,4,128,0),@(16,4,255,0),@(1,256,0,0),@(1,1,0,0x7FFFFF),@(65535,0,0,0xFFFFFF),@(1,2,0,0xFFFFFF))){
 $id='scaled-'+$number;$number++;$amount=$spec[0];$selector=$spec[1];$mode=$spec[2];$value=$spec[3];$at=0x7C9+3*($selector -band 255)
 $cases.Add([ordered]@{id=$id;global=$false;amount=$amount;selector=$selector;mode=$mode;scaled=$true})
 foreach($command in @('load seed.bin,0','s=0x790','cc=0x50',('x=0x'+$amount.ToString('X4')),('y=0x'+$selector.ToString('X4')),('b@0x323=0x'+$mode.ToString('X2')),('b@0x'+$at.ToString('X4')+'=0x'+($value -shr 16).ToString('X2')),('w@0x'+($at+1).ToString('X4')+'=0x'+($value -band 65535).ToString('X4')),'bpset 0x1568',"save $id-before.bin,0,800",'pc=0x151f','g 0x1571',"save $id-after.bin,0,800",('printf "MATRIX '+$id+' pc=%04X\n",pc'),'bpclear')){$commands.Add($command)}
}}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json -Depth 4|Set-Content "$run/cases.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-state_directory',"$run/state",'-snapshot_directory',"$run/snap",'-diff_directory',"$run/diff",'-comment_directory',"$run/comments",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
[ordered]@{scaled=[bool]$Scaled;classification=$(if($Scaled){'Synthetic isolated native151F with stop before overflow SWI3; explicit registers/counters/mode; IRQ masked'}else{'Synthetic isolated native1622/166D: explicit registers, counter bytes and mode; IRQ masked; not a natural game path'});mame_sha256=(Get-FileHash $MameExecutable).Hash;seed_sha256=(Get-FileHash "$run/seed.bin").Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
Push-Location $run
try{& $MameExecutable @arguments *> "$run/console.txt";$LASTEXITCODE|Set-Content "$run/exit-code.txt"}finally{Pop-Location}
if($LASTEXITCODE -ne 0){throw 'MAME matrix failed'}
Write-Output $run

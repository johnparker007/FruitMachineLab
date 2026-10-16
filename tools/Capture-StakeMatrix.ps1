param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$SeedRam,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory)
if(Test-Path -LiteralPath $run){throw 'Use a fresh directory'}
New-Item -ItemType Directory -Path $run|Out-Null
foreach($name in @('cfg','nvram','state','snap','diff','comments')){New-Item -ItemType Directory (Join-Path $run $name)|Out-Null}
Copy-Item -LiteralPath $SeedRam -Destination "$run/seed.bin"
$cases=[Collections.Generic.List[object]]::new();$commands=[Collections.Generic.List[string]]::new();$commands.Add('bpset 0x7000')
foreach($spec in @(@(0,0,1,0),@(0,0,1,39),@(0,0,1,40),@(0,0,1,255),@(0,0,0,39),@(128,0,1,39),@(0,1,1,39),@(0,0,255,39))){$cases.Add(@{kind='decay';mode=$spec[0];config=$spec[1];count=$spec[2];phase=$spec[3]})}
foreach($percentage in @(1,69,70,71,74,80,98,255)){$cases.Add(@{kind='target';percentage=$percentage;cache=0;key=0;dip=0})}
foreach($cache in @(0,80,255)){$cases.Add(@{kind='target';percentage=0;cache=$cache;key=0;dip=0})}
foreach($index in 1..15){$cases.Add(@{kind='target';percentage=0;cache=0;key=$index;dip=0});$cases.Add(@{kind='target';percentage=0;cache=0;key=0;dip=$index})}
foreach($selector in 0..4){foreach($value in @(0,1,65535,16777215)){$cases.Add(@{kind='subtract';selector=$selector;value=$value})}}
foreach($mode in @(0,128)){foreach($value in @(0,65535,16777215)){$cases.Add(@{kind='increment';mode=$mode;value=$value})}}
$number=0
foreach($case in $cases){
 $id='stake-'+$number;$number++;$case.id=$id
 foreach($command in @('load seed.bin,0','s=0x790','cc=0x50','dp=0','w@0x790=0x7000','maincpu.mb@0x719a=0','maincpu.mb@0x71a2=0','b@0x323=0')){$commands.Add($command)}
 switch($case.kind){
  'decay'{$native='3afa';$commands.Add(('b@0x323='+$case.mode));$commands.Add(('maincpu.mb@0x719a='+$case.config));$commands.Add(('b@0x35b='+$case.count));$commands.Add(('b@0x35c='+$case.phase))}
  'target'{
   $native='4d9b';$commands.Add(('maincpu.mb@0x71a2='+$case.percentage));$commands.Add(('b@0x344='+$case.cache));$commands.Add(('b@0x345='+($case.cache -bxor 255)))
   foreach($port in @(0,1,2,3,6,7)){$commands.Add(('b@'+$port+'=0'))}
   foreach($bit in 0..3){
    if($case.key -band (8 -shr $bit)){foreach($port in 0..3){$at=0x71AA+4*(7+$bit)+$port;$commands.Add(('b@'+$port+'=b@'+$port+'|b@0x'+$at.ToString('X4')))}}
    if($case.dip -band (8 -shr $bit)){foreach($port in 6..7){$at=0x7226+((2*(0x8F-$bit)) -band 255)+$port-6;$commands.Add(('b@'+$port+'=b@'+$port+'|b@0x'+$at.ToString('X4')))}}
   }
  }
  'subtract'{$native='14eb';$commands.Add(('b='+$case.selector));$commands.Add('maincpu.mb@0x71a2=#80');$commands.Add(('x=w@(0x1462+#'+(9*$case.selector)+')'));$commands.Add(('b@x=#'+($case.value -shr 16)));$commands.Add(('w@(x+1)=#'+($case.value -band 65535)))}
  'increment'{$native='57db';$commands.Add(('b@0x323='+$case.mode));$commands.Add('x=0x3dd');$commands.Add(('b@x=#'+($case.value -shr 16)));$commands.Add(('w@(x+1)=#'+($case.value -band 65535)))}
 }
 # Debugger bare numerals are hexadecimal. Decimal fields above must be explicit.
 # Normalize simple assignments generated from decimal case values.
 for($n=$commands.Count-1;$n -ge 0;$n--){if($commands[$n] -eq 'load seed.bin,0'){break};if($commands[$n] -match '^((?:b(?:@0x[0-9a-f]+)?|maincpu.mb@0x[0-9a-f]+)=)([0-9]+)$'){$commands[$n]=$Matches[1]+'#'+$Matches[2]}}
 foreach($command in @(('printf "CFG '+$id+' a=%02X p=%02X\n",b@0x719a,b@0x71a2'),"save $id-before.bin,0,800",('pc=0x'+$native),'g',('printf "DONE '+$id+' d=%04X\n",d'),"save $id-after.bin,0,800")){$commands.Add($command)}
}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json -Depth 4|Set-Content "$run/cases.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-state_directory',"$run/state",'-snapshot_directory',"$run/snap",'-diff_directory',"$run/diff",'-comment_directory',"$run/comments",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
[ordered]@{classification='Synthetic native stake/target/decay matrix; explicit in-memory ROM configuration patches, counters and sampled inputs; ROM files unchanged, masked IRQs; not a natural game path';mame_sha256=(Get-FileHash $MameExecutable).Hash;seed_sha256=(Get-FileHash "$run/seed.bin").Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
Push-Location $run
try{& $MameExecutable @arguments *> "$run/console.txt";$LASTEXITCODE|Set-Content "$run/exit-code.txt"}finally{Pop-Location}
if($LASTEXITCODE -ne 0){throw 'MAME matrix failed'}
Write-Output $run

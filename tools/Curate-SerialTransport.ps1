param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0'){throw 'Incomplete capture'}
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Wrong ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath);$p=Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json;$cases=@(Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json)
if($cases.Count -ne $p.count){throw 'Wrong catalog'}
$rows=[Collections.Generic.List[object]]::new();$catalog=[Collections.Generic.List[object]]::new();$indexes=@{};$active=$null;$id=0
foreach($line in Get-Content "$RunDirectory/debug.log"){
 if($line -match '(?i)^error '){throw 'Debugger error'};if($line -notmatch '^O([SIF]) '){continue};$kind=$Matches[1];$f=[ordered]@{}
 foreach($match in [regex]::Matches($line,'([a-z]+)=([0-9A-F]+)')){if($match.Groups[1].Value -ne 'bytes'){$f[$match.Groups[1].Value]=[Convert]::ToUInt64($match.Groups[2].Value,16)}}
 if($kind -eq 'S'){
  if($null -ne $active -or $id -ge $cases.Count -or $f.pc -ne $cases[$id].entry){throw 'Wrong start'}
  $active=[ordered]@{case=$cases[$id];start_cycle=$f.cycle;start=$f;steps=[Collections.Generic.List[object]]::new()}
 }elseif($kind -eq 'I'){
  if($null -eq $active -or $line -notmatch 'bytes=([0-9A-F]{10})'){throw 'Missing instruction'};$hex=$Matches[1];$pc=[int]$f.pc
  if([Convert]::ToHexString($rom[$pc..($pc+4)]) -ne $hex){throw 'ROM differs'}
  if(!$indexes.ContainsKey($pc)){$indexes[$pc]=$catalog.Count;$catalog.Add([ordered]@{pc=$pc;context_hex=$hex})};$active.steps.Add(@($indexes[$pc],($f.cycle-$active.start_cycle)))
 }else{
  if($null -eq $active -or $f.pc -ne $cases[$id].end -or $f.s -ne $cases[$id].stack){throw 'Wrong boundary'}
  $active['cycles']=$f.cycle-$active.start_cycle;$active['end']=$f
  foreach($side in @('before','after')){$ram=[IO.File]::ReadAllBytes("$RunDirectory/operation-$id-$side.bin");if($ram.Length -ne 2048){throw 'Wrong RAM'};$active["${side}_hex"]=[Convert]::ToHexString($ram)}
  $rows.Add($active);$active=$null;$id++
 }
}
if($null -ne $active -or $rows.Count -ne $p.count){throw 'Incomplete matrix'}
$spans=@($p.regions);if($spans.Count -eq 2 -and $spans[0] -is [ValueType]){$spans=@(,$spans)}
$regions=@(foreach($span in $spans){[ordered]@{address=$span[0];bytes_hex=[Convert]::ToHexString($rom[$span[0]..$span[1]])}})
$target="$PSScriptRoot/../evidence/mpu4/collection/$($p.stem)"
[ordered]@{classification=$p.classification;catalog=@($catalog.ToArray());rows=@($rows.ToArray());rom_regions=$regions;capture=$p;raw_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash}|ConvertTo-Json -Depth 10|Set-Content "$target.json";Copy-Item "$RunDirectory/debugger.cmd" "$target-debugger.cmd"

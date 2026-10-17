param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$target="$PSScriptRoot/../evidence/mpu4/collection"
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0'){throw 'Incomplete capture'}
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Wrong ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath);$cases=@(Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json);$catalog=[Collections.Generic.List[object]]::new();$indexes=@{};$rows=[Collections.Generic.List[object]]::new();$active=$null;$id=0
foreach($line in Get-Content "$RunDirectory/debug.log"){
 if($line -match '(?i)^error '){throw 'Debugger error'};if($line -notmatch '^N([SIF]) '){continue};$kind=$Matches[1];$fields=@{}
 foreach($match in [regex]::Matches($line,'([a-z0-9_]+)=([0-9A-F]+)')){$fields[$match.Groups[1].Value]=[Convert]::ToUInt64($match.Groups[2].Value,16)}
 if($kind -eq 'S'){if($null -ne $active){throw 'Unfinished case'};$active=[ordered]@{case=$cases[$id];start_cycle=$fields.cycle;steps=[Collections.Generic.List[object]]::new()}}
 if($null -eq $active){throw 'Missing start'}
 if($kind -in @('S','I')){if($line -notmatch 'bytes=([0-9A-F]{10})'){throw 'Missing bytes'};$hex=$Matches[1];$pc=[int]$fields.pc;if([Convert]::ToHexString($rom[$pc..($pc+4)]) -ne $hex){throw 'ROM differs'}
  if(!$indexes.ContainsKey($pc)){$indexes[$pc]=$catalog.Count;$catalog.Add([ordered]@{pc=$pc;context_hex=$hex})};$active.steps.Add(@($indexes[$pc],($fields.cycle-$active.start_cycle)))
 }else{if($fields.pc -ne 0x4C34 -or $fields.s -ne 0x702 -or $fields.u -ne 0x600 -or $fields.x -ne 0x100 -or $fields.y -ne 0x4567 -or $fields.a -ne 0x89 -or $fields.b -ne 0xAB){throw 'Incorrect input-condition return'}
  foreach($side in @('before','after')){$ram=[IO.File]::ReadAllBytes("$RunDirectory/condition-$id-$side.bin");if($ram.Length -ne 2048){throw 'Wrong RAM length'};$active["${side}_hex"]=[Convert]::ToHexString($ram)}
  $active['end']=$fields;$active.steps=@($active.steps.ToArray());$rows.Add($active);$active=$null;$id++}
}
if($null -ne $active -or $rows.Count -ne 64){throw 'Incomplete64-case matrix'}
[ordered]@{classification='64 synthetic original input-condition instruction paths, not physical input acquisition.';catalog=@($catalog.ToArray());rows=@($rows.ToArray());rom_regions=@([ordered]@{address=0x67EC;bytes_hex=[Convert]::ToHexString($rom[0x67EC..0x6857])},[ordered]@{address=0x71AA;bytes_hex=[Convert]::ToHexString($rom[0x71AA..0x7249])});capture=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);raw_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash}|ConvertTo-Json -Depth 9|Set-Content "$target/input-condition-timing.json"
Copy-Item "$RunDirectory/debugger.cmd" "$target/input-condition-timing-debugger.cmd"

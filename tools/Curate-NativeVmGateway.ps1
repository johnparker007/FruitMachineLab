param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$target="$PSScriptRoot/../evidence/mpu4/collection"
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0'){throw 'Incomplete capture'}
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Wrong ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath);$cases=@(Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json)
$catalog=[Collections.Generic.List[object]]::new();$indexes=@{};$rows=[Collections.Generic.List[object]]::new();$active=$null;$phase='';$id=0
foreach($line in Get-Content "$RunDirectory/debug.log") {
 if($line -match '(?i)^error '){throw 'Debugger error'}
 if($line -notmatch '^G([SIXRFW]) '){continue};$kind=$Matches[1];$fields=@{}
 foreach($match in [regex]::Matches($line,'([a-z0-9_]+)=([0-9A-F]+)')){$fields[$match.Groups[1].Value]=[Convert]::ToUInt64($match.Groups[2].Value,16)}
 if($kind -eq 'S'){if($null -ne $active){throw 'Unfinished gateway'};$active=[ordered]@{case=$cases[$id];start_cycle=$fields.cycle;prefix=[Collections.Generic.List[object]]::new();suffix=[Collections.Generic.List[object]]::new();writes=[Collections.Generic.List[object]]::new()};$phase='prefix'}
 if($null -eq $active){throw 'Missing gateway start'}
 if($kind -eq 'W'){$active.writes.Add(@(($fields.cycle-$active.start_cycle),$fields.value));continue}
 if($kind -eq 'X'){if($fields.pc -ne 0xFC -or $fields.y -ne 0xA8F9 -or $fields.s -ne 0x782 -or $fields.u -ne 0x600){throw 'Wrong gateway VM entry'};$active['vm_entry']=$fields;$phase='vm';continue}
 if($kind -eq 'R'){if($phase -ne 'vm' -or $fields.pc -ne 0x76F6){throw 'Wrong VM return'};$active['vm_return_cycle']=$fields.cycle;$phase='suffix'}
 if($kind -in @('S','I','R')){
  if($phase -eq 'vm'){throw 'Native timing attributed to VM owner'}
  if($line -notmatch 'bytes=([0-9A-F]{10})'){throw 'Missing bytes'};$hex=$Matches[1];$pc=[int]$fields.pc
  if([Convert]::ToHexString($rom[$pc..($pc+4)]) -ne $hex){throw 'ROM differs'}
  if(!$indexes.ContainsKey($pc)){$indexes[$pc]=$catalog.Count;$catalog.Add([ordered]@{pc=$pc;context_hex=$hex})}
  $active[$phase].Add(@($indexes[$pc],($fields.cycle-$active.start_cycle)))
 }elseif($kind -eq 'F'){
  if($fields.pc -ne 0x4CD1 -or $fields.s -ne 0x792 -or $fields.u -ne 0x600 -or $fields.x -ne 0xA8F9 -or $fields.y -ne 0xBEEF -or $fields.a -ne 0x12 -or $fields.b -ne 0x34 -or $fields.cc -ne 0x50 -or $fields.dp -ne 0){throw 'Wrong native gateway return'}
  foreach($side in @('before','entry','return','after')){$ram=[IO.File]::ReadAllBytes("$RunDirectory/gateway-$id-$side.bin");if($ram.Length -ne 2048){throw 'Incomplete RAM'};$active["${side}_hex"]=[Convert]::ToHexString($ram)}
  $active['end']=$fields;foreach($key in @('prefix','suffix','writes')){$active[$key]=@($active[$key].ToArray())};$rows.Add($active);$active=$null;$id++
 }
}
if($null -ne $active -or $rows.Count -ne 8){throw 'Incomplete eight-case gateway matrix'}
[ordered]@{classification='Eight synthetic original-ROM gateway native spans around real suppressed A8F9. VM elapsed time isolates native spans only, never runtime pacing.';catalog=@($catalog.ToArray());rows=@($rows.ToArray());rom_regions=@([ordered]@{address=0x76BF;bytes_hex=[Convert]::ToHexString($rom[0x76BF..0x7706])},[ordered]@{address=0x7927;bytes_hex=[Convert]::ToHexString($rom[0x7927..0x792E])});embedded_words=@([ordered]@{address=0x76ED;value=0x76F4;role='VM return stream contains token76F4'},[ordered]@{address=0x76F4;value=0x76F6;role='Token header points to native return handler76F6'});capture=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);raw_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash}|ConvertTo-Json -Depth 9|Set-Content "$target/native-vm-gateway.json"
Copy-Item "$RunDirectory/debugger.cmd" "$target/native-vm-gateway-debugger.cmd"
Write-Output 'Curated8 native VM gateway cases and exact code/data bytes'

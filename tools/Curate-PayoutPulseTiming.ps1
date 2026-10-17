param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$target="$PSScriptRoot/../evidence/mpu4/collection"
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0'){throw 'Incomplete capture'}
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Wrong ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath);$cases=@(Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json)
$provenance=Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json
$full=[bool]$provenance.output_service;$stem=if($full){'output-service-timing'}else{'pulse-timing'}
$catalog=[Collections.Generic.List[object]]::new();$indexes=@{};$rows=[Collections.Generic.List[object]]::new();$active=$null
foreach($line in Get-Content "$RunDirectory/debug.log") {
 if($line -match '(?i)^error '){throw 'Debugger error'}
 if($line -notmatch '^P([SIWF]) '){continue};$kind=$Matches[1];$fields=@{}
 foreach($match in [regex]::Matches($line,'([a-z0-9_]+)=([0-9A-F]+)')){$fields[$match.Groups[1].Value]=[Convert]::ToUInt64($match.Groups[2].Value,16)}
 if($kind -eq 'S'){if($null -ne $active){throw 'Unfinished row'};$active=[ordered]@{case=$cases[[int]$fields.id];start_cycle=$fields.cycle;steps=[Collections.Generic.List[object]]::new();writes=[Collections.Generic.List[object]]::new()}}
 if($null -eq $active -or $active.case.id -ne $fields.id){throw 'Missing/mismatched row'}
 if($kind -in @('S','I')) {
  if($line -notmatch 'bytes=([0-9A-F]{10})'){throw 'Missing bytes'};$hex=$Matches[1];$pc=[int]$fields.pc
  if([Convert]::ToHexString($rom[$pc..($pc+4)]) -ne $hex){throw 'ROM differs'}
  if(!$indexes.ContainsKey($pc)){$indexes[$pc]=$catalog.Count;$catalog.Add([ordered]@{pc=$pc;context_hex=$hex})}
  $active.steps.Add(@($indexes[$pc],($fields.cycle-$active.start_cycle)))
 }elseif($kind -eq 'W'){$active.writes.Add(@(($fields.cycle-$active.start_cycle),$fields.value))}
 else {
  $pulses=if($full){($active.case.queues|Measure-Object -Sum).Sum}else{1};$polls=if($pulses -eq 0){0}else{260*$pulses-1}
  $exit=if($full){0x4C34}else{0x685A};$stack=if($full){0x702}else{0x704}
  if($fields.pc -ne $exit -or $fields.s -ne $stack -or $fields.polls -ne $polls -or $active.writes.Count -ne 2*$pulses){throw 'Unexpected pulse/service exit'}
  if($full){
   $before=[IO.File]::ReadAllBytes("$RunDirectory/output-$($active.case.id)-before.bin");$after=[IO.File]::ReadAllBytes("$RunDirectory/output-$($active.case.id)-after.bin")
   if($before.Length -ne 2048 -or $after.Length -ne 2048){throw 'Incomplete RAM snapshots'}
   $active['before_hex']=[Convert]::ToHexString($before);$active['after_hex']=[Convert]::ToHexString($after)
  }
  $active['end']=$fields;$active.steps=@($active.steps.ToArray());$active.writes=@($active.writes.ToArray());$rows.Add($active);$active=$null
 }
}
if($null -ne $active -or $rows.Count -ne 8){throw 'Incomplete eight-case matrix'}
[ordered]@{classification='Eight synthetic original-ROM pulse or full output-service instruction paths. Counter changes at odd717C compares, even compares unchanged; masked IRQ. Not natural service timing.';catalog=@($catalog.ToArray());rows=@($rows.ToArray());capture=$provenance;raw_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash}|ConvertTo-Json -Depth 9|Set-Content "$target/$stem.json"
Copy-Item "$RunDirectory/debugger.cmd" "$target/$stem-debugger.cmd"
Write-Output "Curated8 native $stem cases"

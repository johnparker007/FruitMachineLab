param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$target="$PSScriptRoot/../evidence/mpu4/collection"
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0'){throw 'Incomplete capture'}
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Wrong ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath);$cases=@(Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json);$catalog=[Collections.Generic.List[object]]::new();$indexes=@{};$rows=[Collections.Generic.List[object]]::new();$active=$null;$id=0
$tail=[bool](Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json).payout_tail
$comp=[bool](Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json).token_compensation
foreach($line in Get-Content "$RunDirectory/debug.log"){
 if($line -match '(?i)^error '){throw 'Debugger error'};if($line -notmatch '^N([SIF]) '){continue};$kind=$Matches[1];$fields=@{}
 foreach($match in [regex]::Matches($line,'([a-z0-9_]+)=([0-9A-F]+)')){$fields[$match.Groups[1].Value]=[Convert]::ToUInt64($match.Groups[2].Value,16)}
 if($kind -eq 'S'){if($null -ne $active){throw 'Unfinished case'};$active=[ordered]@{case=$cases[$id];start_cycle=$fields.cycle;steps=[Collections.Generic.List[object]]::new()}}
 if($null -eq $active){throw 'Missing start'}
 if($kind -in @('S','I')){if($line -notmatch 'bytes=([0-9A-F]{10})'){throw 'Missing bytes'};$hex=$Matches[1];$pc=[int]$fields.pc;if([Convert]::ToHexString($rom[$pc..($pc+4)]) -ne $hex){throw 'ROM differs'}
  if(!$indexes.ContainsKey($pc)){$indexes[$pc]=$catalog.Count;$catalog.Add([ordered]@{pc=$pc;context_hex=$hex})};$active.steps.Add(@($indexes[$pc],($fields.cycle-$active.start_cycle)))
 }else{if($comp){if($fields.pc -ne ($cases[$id].entry+32) -or $fields.s -ne 0x700 -or $fields.u -ne 0x600){throw 'Wrong compensation end'}}else{$expectedY=if($tail){$cases[$id].selector}else{0x4567};if($fields.pc -ne 0x4C34 -or $fields.s -ne 0x702 -or $fields.u -ne 0x600 -or $fields.x -ne 0x100 -or $fields.y -ne $expectedY -or $fields.a -ne 0x89 -or $fields.b -ne 0xAB){throw 'Incorrect input-condition return'}}
  $prefix=if($comp){'compensation'}else{'condition'}
  foreach($side in @('before','after')){$ram=[IO.File]::ReadAllBytes("$RunDirectory/$prefix-$id-$side.bin");if($ram.Length -ne 2048){throw 'Wrong RAM length'};$active["${side}_hex"]=[Convert]::ToHexString($ram)}
  $active['end']=$fields;$active.steps=@($active.steps.ToArray());$rows.Add($active);$active=$null;$id++}
}
if($null -ne $active -or $rows.Count -ne $(if($tail -or $comp){32}else{64})){throw 'Incomplete native matrix'}
$stem=if($comp){'token-compensation-timing'}elseif($tail){'tail-timing'}else{'input-condition-timing'}
$spans=if($comp){@(@(0x4D07,0x4D26),@(0x4D51,0x4D70),@(0x6F51,0x6F78))}else{@(@(0x67EC,0x6857),@(0x71AA,0x7249))}
$regions=@(foreach($span in $spans){[ordered]@{address=$span[0];bytes_hex=[Convert]::ToHexString($rom[$span[0]..$span[1]])}})
[ordered]@{classification='Synthetic original translated native instruction paths; no natural scheduling or delivery claim.';catalog=@($catalog.ToArray());rows=@($rows.ToArray());rom_regions=$regions;capture=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);raw_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash}|ConvertTo-Json -Depth 9|Set-Content "$target/$stem.json"
Copy-Item "$RunDirectory/debugger.cmd" "$target/$stem-debugger.cmd"

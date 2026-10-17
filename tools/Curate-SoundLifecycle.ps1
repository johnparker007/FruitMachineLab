param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0'){throw 'Incomplete capture'}
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Wrong ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath);$cases=@(Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json);$rows=[Collections.Generic.List[object]]::new();$active=$null;$id=0
foreach($line in Get-Content "$RunDirectory/debug.log"){
if($line -match '(?i)^error '){throw 'Debugger error'};if($line -notmatch '^L([SIF]) '){continue};$kind=$Matches[1];$f=[ordered]@{};foreach($match in [regex]::Matches($line,'([a-z]+)=([0-9A-F]+)')){if($match.Groups[1].Value -ne 'bytes'){$f[$match.Groups[1].Value]=[Convert]::ToUInt64($match.Groups[2].Value,16)}}
if($kind -eq 'S'){if($null -ne $active -or $f.pc -ne $cases[$id].entry){throw 'Wrong start'};$active=[ordered]@{case=$cases[$id];start_cycle=$f.cycle;steps=[Collections.Generic.List[object]]::new()}}
elseif($kind -eq 'I'){if($null -eq $active -or $line -notmatch 'bytes=([0-9A-F]{10})'){throw 'Missing instruction'};$hex=$Matches[1];$pc=[int]$f.pc;if([Convert]::ToHexString($rom[$pc..($pc+4)]) -ne $hex){throw 'ROM context differs'};$active.steps.Add([ordered]@{pc=$pc;cycle=$f.cycle-$active.start_cycle;context_hex=$hex})}
else{$expectedU=if($cases[$id].kind -in @('scheduler','nested')){0x879F}else{0x600};if($null -eq $active -or $f.pc -ne 0x4C34 -or $f.s -ne 0x702 -or $f.u -ne $expectedU){throw 'Wrong return'};$active['cycles']=$f.cycle-$active.start_cycle;$active['end']=$f;foreach($side in @('before','after')){$ram=[IO.File]::ReadAllBytes("$RunDirectory/lifecycle-$id-$side.bin");if($ram.Length -ne 2048){throw 'Wrong RAM'};$active["${side}_hex"]=[Convert]::ToHexString($ram)};$rows.Add($active);$active=$null;$id++}}
if($null -ne $active -or $rows.Count -ne 160){throw 'Incomplete matrix'}
$regions=@(foreach($span in @(@(0x5C7A,0x5D47),@(0x5AE3,0x5AE4),@(0x879E,0x879E),@(0x5E2C,0x5E8E),@(0x60AB,0x60E0))){[ordered]@{address=$span[0];bytes_hex=[Convert]::ToHexString($rom[$span[0]..$span[1]])}})
$catalog=[Collections.Generic.List[object]]::new();$indexes=@{}
foreach($row in $rows){$steps=@(foreach($step in $row.steps){$pc=[int]$step.pc;if(!$indexes.ContainsKey($pc)){$indexes[$pc]=$catalog.Count;$catalog.Add([ordered]@{pc=$pc;context_hex=$step.context_hex})};,@($indexes[$pc],$step.cycle)});$row.steps=$steps}
$target="$PSScriptRoot/../evidence/mpu4/collection/sound-lifecycle"
[ordered]@{classification='Synthetic original-ROM native calls; instruction timing and memory comparisons, not natural service cadence.';catalog=@($catalog.ToArray());rows=@($rows.ToArray());rom_regions=$regions;capture=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);raw_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash}|ConvertTo-Json -Depth 9|Set-Content "$target.json"
Copy-Item "$RunDirectory/debugger.cmd" "$target-debugger.cmd"


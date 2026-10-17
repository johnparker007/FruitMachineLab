param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$target="$PSScriptRoot/../evidence/mpu4/collection"
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0'){throw 'Incomplete capture'}
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Wrong ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath);$cases=@(Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json);$catalog=[Collections.Generic.List[object]]::new();$indexes=@{};$rows=[Collections.Generic.List[object]]::new();$active=$null;$call=$null
foreach($line in Get-Content "$RunDirectory/debug.log"){
 if($line -match '(?i)^error '){throw 'Debugger error'};if($line -notmatch '^C([BISVRE]) '){continue};$kind=$Matches[1];$f=@{}
 foreach($match in [regex]::Matches($line,'([a-z0-9_]+)=([0-9A-F]+)')){$f[$match.Groups[1].Value]=[Convert]::ToUInt64($match.Groups[2].Value,16)}
 if($kind -eq 'B'){if($null -ne $active){throw 'Unfinished row'};$active=[ordered]@{case=$cases[[int]$f.id];start_cycle=$f.cycle;steps=[Collections.Generic.List[object]]::new();calls=[Collections.Generic.List[object]]::new()}}
 if($null -eq $active -or $active.case.id -ne $f.id){throw 'Missing caller start'}
 if($kind -eq 'S'){if($null -ne $call){throw 'Nested debit unexpectedly logged'};$call=[ordered]@{entry=$f;vm=[Collections.Generic.List[object]]::new()};continue}
 if($kind -eq 'V'){if($null -eq $call){throw 'VM outside debit owner'};$call.vm.Add($f);continue}
 if($kind -eq 'R'){if($null -eq $call){throw 'Unexpected debit return'};$call['end']=$f;$call.vm=@($call.vm.ToArray());$active.calls.Add($call);$call=$null;continue}
 if($kind -in @('B','I')){if($null -ne $call){throw 'Caller instruction inside child'};if($line -notmatch 'bytes=([0-9A-F]{10})'){throw 'Missing bytes'};$hex=$Matches[1];$pc=[int]$f.pc;if([Convert]::ToHexString($rom[$pc..($pc+4)]) -ne $hex){throw 'ROM differs'}
  if(!$indexes.ContainsKey($pc)){$indexes[$pc]=$catalog.Count;$catalog.Add([ordered]@{pc=$pc;context_hex=$hex})};$active.steps.Add(@($indexes[$pc],($f.cycle-$active.start_cycle)))
 }elseif($kind -eq 'E'){
  if($null -ne $call -or $f.pc -ne 0x4C34 -or $f.s -ne 0x792){throw 'Wrong caller exit'}
  foreach($side in @('before','after')){$ram=[IO.File]::ReadAllBytes("$RunDirectory/$($active.case.name)-$side.bin");if($ram.Length -ne 2048){throw 'Incomplete RAM'};$active["${side}_hex"]=[Convert]::ToHexString($ram)}
  $active['end']=$f;$active.steps=@($active.steps.ToArray());$active.calls=@($active.calls.ToArray());$rows.Add($active);$active=$null
 }
}
if($null -ne $active -or $rows.Count -ne 16){throw 'Incomplete caller matrix'}
[ordered]@{classification='16 synthetic original cash/token native callers with real nested VM and output waits. Counter increments before odd717C compares; masked IRQ. Not natural IRQ scheduling or physical delivery.';catalog=@($catalog.ToArray());rows=@($rows.ToArray());rom_regions=@([ordered]@{address=0x67E2;bytes_hex=[Convert]::ToHexString($rom[0x67E2..0x6857])});capture=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);raw_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash}|ConvertTo-Json -Depth 10|Set-Content "$target/caller-timing.json"
Copy-Item "$RunDirectory/debugger.cmd" "$target/caller-timing-debugger.cmd"
Write-Output 'Curated16 timed payout callers, no skipped output waits'

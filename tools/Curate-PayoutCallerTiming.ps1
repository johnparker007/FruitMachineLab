param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$target="$PSScriptRoot/../evidence/mpu4/collection"
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0'){throw 'Incomplete capture'}
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Wrong ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath);$cases=@(Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json);$catalog=[Collections.Generic.List[object]]::new();$indexes=@{};$rows=[Collections.Generic.List[object]]::new();$active=$null;$call=$null
$bridge=[bool](Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json).vm_bridge
foreach($line in Get-Content "$RunDirectory/debug.log"){
 if($line -match '(?i)^error '){throw 'Debugger error'};if($line -notmatch '^C([BISVRE]) '){continue};$kind=$Matches[1];$f=@{}
 foreach($match in [regex]::Matches($line,'([a-z0-9_]+)=([0-9A-F]+)')){$f[$match.Groups[1].Value]=[Convert]::ToUInt64($match.Groups[2].Value,16)}
 if($kind -eq 'B'){if($null -ne $active){throw 'Unfinished row'};$active=[ordered]@{case=$cases[[int]$f.id];start_cycle=$f.cycle;steps=[Collections.Generic.List[object]]::new();calls=[Collections.Generic.List[object]]::new()}}
 if($null -eq $active -or $active.case.id -ne $f.id){throw 'Missing caller start'}
 if($kind -eq 'S'){if($null -ne $call){throw 'Nested debit unexpectedly logged'};$call=[ordered]@{entry=$f;vm=[Collections.Generic.List[object]]::new()};continue}
 if($kind -eq 'V'){if($null -eq $call){throw 'VM outside debit owner'};$call.vm.Add($f);continue}
 if($kind -eq 'R'){if($null -eq $call){throw 'Unexpected debit return'};$call['end']=$f;$call.vm=@($call.vm.ToArray());$active.calls.Add($call);$call=$null;continue}
 if($kind -in @('B','I')){if($null -ne $call){throw 'Caller instruction inside child'};if($line -notmatch 'bytes=([0-9A-F]{10})'){throw 'Missing bytes'};$hex=$Matches[1];$pc=[int]$f.pc;if($pc -in @(0xFC,0xFE)){$opcode=if($pc -eq 0xFC){'AEA1'}else{'6E91'};if(!$hex.StartsWith($opcode)){throw 'RAM NEXT differs'}}elseif([Convert]::ToHexString($rom[$pc..($pc+4)]) -ne $hex){throw 'ROM differs'}
  if(!$indexes.ContainsKey($pc)){$indexes[$pc]=$catalog.Count;$catalog.Add([ordered]@{pc=$pc;context_hex=$hex})};$active.steps.Add(@($indexes[$pc],($f.cycle-$active.start_cycle)))
 }elseif($kind -eq 'E'){
  $exit=if($bridge){0xFC}else{0x4C34};$stack=if($bridge){0x790}else{0x792};if($null -ne $call -or $f.pc -ne $exit -or $f.s -ne $stack){throw 'Wrong caller exit'}
  foreach($side in @('before','after')){$ram=[IO.File]::ReadAllBytes("$RunDirectory/$($active.case.name)-$side.bin");if($ram.Length -ne 2048){throw 'Incomplete RAM'};$active["${side}_hex"]=[Convert]::ToHexString($ram)}
  $active['end']=$f;$active.steps=@($active.steps.ToArray());$active.calls=@($active.calls.ToArray());$rows.Add($active);$active=$null
 }
}
if($null -ne $active -or $rows.Count -ne 16){throw 'Incomplete caller matrix'}
$stem=if($bridge){'vm-word-timing'}else{'caller-timing'}
[ordered]@{classification='16 synthetic original cash/token callers or VM words with real nested VM and output waits. Counter increments before odd717C compares; masked IRQ. ROM contexts checked; RAM NEXT opcodes checked against template, not ROM00FC bytes. Not natural IRQ scheduling or delivery.';catalog=@($catalog.ToArray());rows=@($rows.ToArray());rom_regions=@([ordered]@{address=0x67E2;bytes_hex=[Convert]::ToHexString($rom[0x67E2..0x6857])});capture=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);raw_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash}|ConvertTo-Json -Depth 10|Set-Content "$target/$stem.json"
Copy-Item "$RunDirectory/debugger.cmd" "$target/$stem-debugger.cmd"
if($bridge){[ordered]@{rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;scope='Exact VM/native payout bridge and token headers;80E4/80F4 point to776F then native4B39/4B8C';regions=@([ordered]@{address=0x776F;bytes_hex=[Convert]::ToHexString($rom[0x776F..0x778C])},[ordered]@{address=0x80E4;bytes_hex=[Convert]::ToHexString($rom[0x80E4..0x80F7])})}|ConvertTo-Json -Depth 5|Set-Content "$target/payout-word-data.json"}
Write-Output 'Curated16 timed payout callers, no skipped output waits'

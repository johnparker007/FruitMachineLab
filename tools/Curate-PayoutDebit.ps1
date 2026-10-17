param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$target="$PSScriptRoot/../evidence/mpu4/collection"
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0'){throw 'Incomplete matrix'}
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Wrong ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath);$log=[IO.File]::ReadAllText("$RunDirectory/debug.log")
if($log -match '(?mi)^Error in (?:assignment )?expression:'){throw 'Debugger expression error'}
$rows=@(foreach($case in (Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json)) {
 if($log -notmatch ('(?m)^PAYOUT '+$case.id+' pc=6858 u=0600 y='+$case.record.ToString('X4')+'\s*$')){throw 'Incorrect native exit'}
 $before=[IO.File]::ReadAllBytes("$RunDirectory/$($case.id)-before.bin");$after=[IO.File]::ReadAllBytes("$RunDirectory/$($case.id)-after.bin")
 if($before.Length -ne 2048 -or $after.Length -ne 2048){throw 'Wrong snapshot length'}
 [ordered]@{case=$case;before_hex=[Convert]::ToHexString($before);after_hex=[Convert]::ToHexString($after)}
})
if($rows.Count -ne 32){throw 'Expected32 matrix cases'}
[ordered]@{classification='Synthetic isolated native4CBE through nestedA8F9 VM display and accounting/queues, stopped before6858. IRQ masked; no natural timing claim.';rows=$rows;capture=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);raw_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash}|ConvertTo-Json -Depth 8|Set-Content "$target/debit-matrix.json"
$ranges=@(foreach($r in @(@(0x4ACA,68),@(0x201A,4),@(0x20B0,4),@(0x5BCE,74),@(0x7D36,2),@(0x8437,4),@(0x84AC,4),@(0x84E8,10),@(0x851C,10),@(0x8739,104),@(0xFF34,30))){[ordered]@{address=$r[0];bytes_hex=[Convert]::ToHexString($rom[$r[0]..($r[0]+$r[1]-1)])}})
$native=@(foreach($r in @(@(0x4B39,0x23B),@(0x511B,0x96),@(0x57A9,15),@(0x57F7,9),@(0x59A4,23),@(0x5B77,0x57),@(0x5C18,0x62),@(0x60AB,0x2B),@(0x6858,0x98),@(0x6FC1,16),@(0x6FEC,28),@(0x7009,16),@(0x7032,23),@(0x7172,41))){[ordered]@{address=$r[0];bytes_hex=[Convert]::ToHexString($rom[$r[0]..($r[0]+$r[1]-1)])}})
[ordered]@{rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;classification='Exact ROM ranges. Records4ACA..4B0D, triac masks/messages, display pointer, shared Collect input and option constants. Native regions preserve bytes, not a lossless symbolic listing.';ranges=$ranges;native_regions=$native;collect_input=[ordered]@{selector=0x1C;rom_address=0x721A;bytes_hex=[Convert]::ToHexString($rom[0x721A..0x721D]);mux_column=3;bit=1;active_high=$true;shared_label='Collect / Take Feature';mame_ref='mame0281';mame_path='src/mame/barcrest/mpu4mod4yam.cpp';sampling='Condition1C reads sampled byte0003 level. OR latch0091 is separate. Physical release clears the sampled bit at the next acquisition.'}}|ConvertTo-Json -Depth 6|Set-Content "$target/payout-data.json"
Copy-Item "$RunDirectory/debugger.cmd" "$target/debit-matrix-debugger.cmd"
$pending=[Collections.Generic.Queue[string]]::new();$seen=[Collections.Generic.HashSet[string]]::new();$pending.Enqueue('AB1B');$regions=[Collections.Generic.List[object]]::new()
while($pending.Count -gt 0) {
 $body=$pending.Dequeue();if(!$seen.Add($body)){continue};$sites=[Collections.Generic.List[int]]::new()
 foreach($line in Get-Content "$PSScriptRoot/../evidence/mpu4/VM-SCRIPTS/$body.txt") {
  if($line -notmatch '^\s*\*?\s*([0-9A-F]{4})\s+([0-9A-F]{4})\s+'){continue}
  $at=[Convert]::ToInt32($Matches[1],16);$token=[Convert]::ToInt32($Matches[2],16)
  if(($rom[$at]*256+$rom[$at+1]) -ne $token){throw "ROM token differs at$at"};$sites.Add($at)
  if($line -match '\bbody=0x([0-9A-F]{4})'){$pending.Enqueue($Matches[1])}
 }
 if($sites.Count -eq 0){throw "Empty script$body"}
 $regions.Add([ordered]@{body=$body;address=$sites[0];bytes_hex=[Convert]::ToHexString($rom[$sites[0]..($sites[$sites.Count-1]+1)]);checked_token_sites=@($sites.ToArray())})
}
[ordered]@{rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;scope='AB1B static call closure throughAAA1/AA2B, including disabled/unvisited arms. Exact bytes through last token and checked listing tokens, not a lossless symbolic rebuild.';regions=@($regions.ToArray())}|ConvertTo-Json -Depth 8|Set-Content "$target/vm-encoding-checkpoint.json"
Write-Output 'Curated32 native payout debits plus exact ROM data/instruction ranges'
if((Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json).instruction_timing){
 $catalog=[Collections.Generic.List[object]]::new();$indexes=@{};$timed=[Collections.Generic.List[object]]::new();$active=$null;$phase='';$caseIndex=0
 foreach($line in $log -split '\r?\n'){
  if($line -notmatch '^D([SIXRFVG]) '){continue};$kind=$Matches[1];$fields=@{}
  foreach($match in [regex]::Matches($line,'([a-z0-9_]+)=([0-9A-F]+)')){$fields[$match.Groups[1].Value]=[Convert]::ToUInt64($match.Groups[2].Value,16)}
  if($kind -eq 'S'){if($null -ne $active){throw 'Unfinished timed debit'};$active=[ordered]@{case=$rows[$caseIndex].case;before_hex=$rows[$caseIndex].before_hex;after_hex=$rows[$caseIndex].after_hex;start_cycle=$fields.cycle;prefix=[Collections.Generic.List[object]]::new();suffix=[Collections.Generic.List[object]]::new();display_vm=[Collections.Generic.List[object]]::new()};$phase='prefix'}
  if($null -eq $active){throw 'Unexpected timing marker'}
  if($kind -eq 'V'){if($phase -ne 'display'){throw 'VM outside display owner'};$active.display_vm.Add($fields);continue}
  if($kind -eq 'G'){if($phase -ne 'display'){throw 'Gateway return outside display owner'};$active['gateway_return_cycle']=$fields.cycle;continue}
  if($kind -eq 'X'){if($fields.pc -ne 0x76BF -or $fields.u -ne 0x600 -or $fields.x -ne 0xA8F9){throw 'Wrong display entry'};$active['display_entry']=$fields;$phase='display';continue}
  if($kind -eq 'R'){if($phase -ne 'display' -or $fields.pc -ne 0x4CD1){throw 'Wrong display return'};$active['display_return_cycle']=$fields.cycle;$phase='suffix'}
  if($kind -in @('S','I','R')){
   if($phase -eq 'display'){throw 'Native timing attributed to display owner'}
   if($line -notmatch 'bytes=([0-9A-F]{10})'){throw 'Missing instruction bytes'};$hex=$Matches[1];$pc=[int]$fields.pc
   if([Convert]::ToHexString($rom[$pc..($pc+4)]) -ne $hex){throw 'Wrong timed ROM bytes'}
   if(!$indexes.ContainsKey($pc)){$indexes[$pc]=$catalog.Count;$catalog.Add([ordered]@{pc=$pc;context_hex=$hex})}
   $active[$phase].Add(@($indexes[$pc],($fields.cycle-$active.start_cycle)))
  }elseif($kind -eq 'F'){
   if($phase -ne 'suffix' -or $fields.pc -ne 0x6858 -or $fields.u -ne 0x600){throw 'Wrong timed debit exit'}
   foreach($side in @('entry','return')){$ram=[IO.File]::ReadAllBytes("$RunDirectory/$($active.case.id)-display-$side.bin");if($ram.Length -ne 2048){throw 'Missing display boundary RAM'};$active["display_${side}_hex"]=[Convert]::ToHexString($ram)}
   $active['end']=$fields;$active.prefix=@($active.prefix.ToArray());$active.suffix=@($active.suffix.ToArray());$active.display_vm=@($active.display_vm.ToArray());$timed.Add($active);$active=$null;$caseIndex++
  }
 }
 if($null -ne $active -or $timed.Count -ne 32){throw 'Incomplete timed debit matrix'}
 [ordered]@{classification='32 synthetic original4CBE paths with timed native spans around the real76BF/A8F9 display owner. Display duration is verification-only, not a runtime pacing input.';catalog=@($catalog.ToArray());rows=@($timed.ToArray());capture=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);raw_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash}|ConvertTo-Json -Depth 9|Set-Content "$target/debit-timing.json"
 Copy-Item "$RunDirectory/debugger.cmd" "$target/debit-timing-debugger.cmd"
 $preserved=@(foreach($span in @(@(0x7574,10),@(0x765F,6),@(0x767F,19),@(0x786B,0x1D),@(0x790D,0x18),@(0x792F,0x24),@(0x7946,0xF),@(0x796E,11),@(0x7979,11),@(0x7982,10),@(0x7A3F,0x14),@(0x8414,0x10),@(0xA7A9,0x166))){[ordered]@{address=$span[0];bytes_hex=[Convert]::ToHexString($rom[$span[0]..($span[0]+$span[1]-1)])}})
 # Exact token headers used by the display closure, including shared constants.
 $tokens=@(0x81B0,0x81D9,0x82CE,0x82D6,0x8222,0x82D2,0x8226,0x8306,0x84D4,0x84E0)
 foreach($at in $tokens){$preserved+=,[ordered]@{address=$at;bytes_hex=[Convert]::ToHexString($rom[$at..($at+5)])}}
 [ordered]@{rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;scope='Selected display VM native handlers, headers, complete script/inline data span. Exact bytes, not lossless symbolic assembly.';regions=$preserved}|ConvertTo-Json -Depth 5|Set-Content "$target/display-vm-data.json"
 Write-Output 'Curated32 timed debit prefix/suffix paths with explicit display handoffs'
}

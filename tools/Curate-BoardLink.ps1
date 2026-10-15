param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][ValidateSet('ladder','snake')][string]$LinkKind,[switch]$Continuation,[switch]$Availability,[switch]$NudgeEntry,[switch]$NudgePrompt,[switch]$NudgeRequest,[switch]$NudgeMotion,[switch]$NudgeReturn,[switch]$NudgeSequence,[switch]$NudgeResult,[switch]$NudgeExit,[switch]$NudgeWinTransfer,[switch]$ObservedPrefix,[switch]$NudgeTail,[switch]$TailWindow)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash';$stem=if($NudgeTail){'nudge-tail'}elseif($NudgeWinTransfer){'nudge-win-transfer'}elseif($NudgeExit){'nudge-exit'}elseif($NudgeResult){'nudge-result'}elseif($NudgeSequence){'nudge-sequence'}elseif($NudgeReturn){'nudge-return'}elseif($NudgeMotion){'nudge-motion-vm'}elseif($NudgeRequest){'nudge-request'}elseif($NudgePrompt){'nudge-prompt'}elseif($NudgeEntry){'nudge-entry'}elseif($Availability){'ladder-availability'}else{$LinkKind+'-link'+$(if($Continuation){'-next'}else{''})};$classification='Natural '+$LinkKind+' dispatch from DBC4 '+$(if($Continuation){'to DD38/E2FC continuation'}else{'to DE81'})+'; unchanged physical input campaign; no RAM/register injection'
if($Availability){if(!$Continuation -or $LinkKind -ne 'ladder'){throw 'Availability requires ladder continuation'};$classification='Natural ladder through next selection decision DD7E/DD98, including native availability search; unchanged physical inputs; no RAM/register injection'}
if($NudgeEntry){$classification='Natural type-1 nudge preparation E247 to B4C5, with physical TAKE at naturally reached square22; no RAM/register injection'}
if($NudgePrompt){if(!$NudgeEntry){throw 'NudgePrompt requires NudgeEntry'};$classification='Natural type-1 E247 through first B403 scan; physical TAKE at square22, no state injection'}
if($NudgeRequest){$classification='Natural type-1 request: physical TAKE and physical Nudge1; stop before main-reel motion'}
if($NudgeMotion){$classification='Natural type-1 through completed Nudge1 motion to B339; bounded before unresolved local+2 residue read; raw capture continues through B34E'}
if($NudgeReturn){if(!$NudgeMotion){throw 'NudgeReturn requires NudgeMotion'};$classification='Natural first Nudge1 completes and returns to the next B403 prompt; native lamp save-area dependency preserved'}
if($NudgeSequence){if(!$NudgeReturn){throw 'NudgeSequence requires NudgeReturn'};$classification='Natural repeated physical Nudge1 requests through the B749 sequence return; no state injection'}
if($NudgeResult){if(!$NudgeSequence){throw 'NudgeResult requires NudgeSequence'};$classification='Natural exhausted nudges through automatic improvement and E263 pending-award return; physical inputs only'}
if($NudgeExit){if(!$NudgeResult){throw 'NudgeExit requires NudgeResult'};$classification='Natural nudge improvement result returns through indexed dispatcher to E460 feature-board exit; physical inputs only'}
if($NudgeWinTransfer){if(!$NudgeExit){throw 'NudgeWinTransfer requires NudgeExit'};$classification='Natural nudge result through outer caller to AFC2 pending-to-current-win final increment and NVRAM return; no bank/payout claim'}
if(Select-String -LiteralPath (Join-Path $RunDirectory 'debug.log') -Pattern '^Error in expression:' -Quiet){throw 'Debugger expression errors invalidate this curation'}
if(!$ObservedPrefix -and (Get-Content (Join-Path $RunDirectory 'exit-code.txt') -Raw).Trim() -ne '0'){throw 'Incomplete capture: use an explicitly bounded observed-prefix workflow only when applicable'}
if($ObservedPrefix -and !$NudgeWinTransfer){throw 'ObservedPrefix requires NudgeWinTransfer'}
if($ObservedPrefix){$classification+='; selected complete prefix from a capture whose process failed later; no terminal RAM snapshot or completed-campaign claim'}
if($NudgeTail){if(!$NudgeWinTransfer -or $ObservedPrefix){throw 'NudgeTail requires complete NudgeWinTransfer campaign'};$classification='Natural nudge current-win animation and seven-flash tail through AFF0; completed capture with terminal RAM'}
if($TailWindow -and !$NudgeTail){throw 'TailWindow requires NudgeTail'}
$prefix=$null;$prefixCount=0;$prefixHash=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
if($NudgePrompt -and !$TailWindow){$prefix=Get-Content (Join-Path $target $(if($NudgeTail){'nudge-win-transfer.json'}elseif($NudgeWinTransfer){'nudge-exit.json'}elseif($NudgeExit){'nudge-result.json'}elseif($NudgeResult){'nudge-sequence.json'}elseif($NudgeSequence){'nudge-return.json'}elseif($NudgeReturn){'nudge-motion-vm.json'}elseif($NudgeMotion){'nudge-request.json'}else{'nudge-entry.json'})) -Raw|ConvertFrom-Json}
if($Continuation -and !$NudgeEntry){$prefix=Get-Content (Join-Path $target (($LinkKind+'-link'+$(if($Availability){'-next'}else{''}))+'.json')) -Raw|ConvertFrom-Json}
$keys=@('y','token','top','second','third','fourth','u','s','f4','f6','frame','tick','irq','seed','choice','rate','latch','pending','win','guard','checksum','mode','display','suppress','clock','board','pot')
$vm=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
$rawVm=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256);$rawCount=0;$lifted=0
$lamp=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256);$sound=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
$schedule=[Collections.Generic.List[object]]::new();$anchors=[Collections.Generic.List[object]]::new();$conditions=[Collections.Generic.List[object]]::new();$beforeReads=[Collections.Generic.List[object]]::new();$serial=[Collections.Generic.List[byte]]::new()
$byteReads=[Collections.Generic.List[object]]::new();$native=[Collections.Generic.List[object]]::new();$soundObservations=[Collections.Generic.List[object]]::new();$availabilityRows=[Collections.Generic.List[object]]::new();$availabilityEntry=$null
$frameMasks=[ordered]@{};$ordinalFrameMasks=[Collections.Generic.List[object]]::new();$nudgeFrameMask=65535;$lastNudgeSite=''
$initial=$null;$last=$null;$count=0;$inputKey='';$lamps=0;$sounds=0;$previous=$null;$sites=@{};$tokens=@{};$busy=0UL;$outer=0UL;$irq=[Collections.Generic.Stack[object]]::new()
function AppendWords($hash,$values){$bytes=[byte[]]::new($values.Count*2);for($n=0;$n -lt $values.Count;$n++){$bytes[2*$n]=[byte]($values[$n] -shr 8);$bytes[2*$n+1]=[byte]($values[$n] -band 255)};$hash.AppendData($bytes)}
$windowActive=!$TailWindow
foreach($line in [IO.File]::ReadLines((Join-Path $RunDirectory 'debug.log'))) {
 if(!$windowActive){if($line -match '^SC y=AFC2 .*pending=0000 win=0010 '){$windowActive=$true}else{continue}}
 if($line -notmatch '^(SC|LF|AB|SN|PI|IE|IX|QE|WC|AV) '){continue};$kind=$Matches[1];$f=[ordered]@{}
 foreach($match in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$f[$match.Groups[1].Value]=$match.Groups[2].Value}
 if($kind -eq 'AV'){if($line -match '^AV enter '){$availabilityEntry=@{ordinal=($count-1);fields=$f}}else{if($null -eq $availabilityEntry){throw 'Availability exit without entry'};$e=$availabilityEntry.fields;$availabilityRows.Add([int[]]@($availabilityEntry.ordinal,[Convert]::ToUInt16($e.u,16),[Convert]::ToUInt16($e.budget,16),[Convert]::ToUInt16($f.result,16),[Convert]::ToUInt16($f.best,16),[Convert]::ToUInt16($f.a8,16),[Convert]::ToUInt16($f.dd,16),[Convert]::ToUInt16($f.de,16),[Convert]::ToUInt16($f.symbols.Substring(0,4),16),[Convert]::ToUInt16($f.symbols.Substring(4,4),16),[Convert]::ToUInt16($f.symbols.Substring(8,4),16)));$availabilityEntry=$null};continue}
 if($kind -eq 'IE'){if($irq.Count -eq 0){$outer=[Convert]::ToUInt64($f.cycle,16)};$irq.Push($f);continue}
 if($kind -eq 'IX'){if($irq.Count -eq 0 -or $irq.Pop().s -ne $f.s){throw 'IRQ nesting differs'};if($irq.Count -eq 0){$busy+=[Convert]::ToUInt64($f.cycle,16)-$outer};continue}
 if($kind -eq 'SC') {
  AppendWords $rawVm @($keys|ForEach-Object {[Convert]::ToUInt16($f[$_],16)});$rawCount++
  # Existing 856F typed scheduler-list test: native allocator pointers are not
  # modeled. Preserve raw digest and explicitly omit its four inner dispatches.
  if($f.y -in @('8571','8573','8575','8577')){$lifted++;continue}
  if($null -eq $initial){$initial=$f};$last=$f
  $cycle=[Convert]::ToUInt64($f.cycle,16)
  if($null -ne $previous){$cost=$cycle-$previous.cycle-($busy-$previous.busy);if($cost -gt 0){foreach($pair in @(@($sites,$previous.y),@($tokens,$previous.token))){if(!$pair[0].ContainsKey($pair[1]) -or $cost -lt $pair[0][$pair[1]]){$pair[0][$pair[1]]=$cost}}};if($previous.token -eq '790D' -and $previous.top -eq '002D' -and $f.top -ne $previous.tick){$delta=([int][Convert]::ToUInt16($f.top,16)-[int][Convert]::ToUInt16($previous.tick,16)+65536)%65536;$beforeReads.Add([int[]]@(($count-1),$delta))}}
  if($null -ne $previous -and $previous.token -eq '786B' -and $previous.top -eq '0033' -and $f.top -ne ('00'+$previous.irq)){$byteReads.Add([int[]]@(($count-1),(([Convert]::ToUInt16($f.top,16)-[Convert]::ToUInt16($previous.irq,16)+256)%256)))}
  $previous=@{cycle=$cycle;busy=$busy;y=$f.y;token=$f.token;top=$f.top;tick=$f.tick;irq=$f.irq}
  $values=[int[]]@($keys | ForEach-Object {[Convert]::ToUInt16($f[$_],16)})
  if($NudgeEntry){
   if($lastNudgeSite -eq 'B730'){$nudgeFrameMask=0}
   if($lastNudgeSite -eq 'B2D0'){$nudgeFrameMask=$nudgeFrameMask -bor 65280}
   if($lastNudgeSite -eq 'B2E2'){$nudgeFrameMask=$nudgeFrameMask -bor 255}
   if($nudgeFrameMask -ne 65535){$ordinalFrameMasks.Add([int[]]@($count,$nudgeFrameMask));$values[10]=$values[10] -band $nudgeFrameMask}
   $lastNudgeSite=$f.y
  }
  # Local-release 76BD is lifted inside the shared physical stack return helper.
  if($f.y -eq '76BD'){$lifted++;continue}
  if($frameMasks.Contains($f.y)){$values[10]=$values[10] -band $frameMasks[$f.y]};AppendWords $vm $values;if($null -ne $prefix -and $prefixCount -lt $prefix.instructions){AppendWords $prefixHash $values;$prefixCount++}
  if(($NudgePrompt -and !$NudgeResult) -or ($NudgeResult -and $count%32 -eq 0) -or $count -lt 180 -or $count%1024 -eq 0 -or $f.y -in @('DE11','DE13','DE30','DE42','DE7F','DBC4','DBED','DE96','DD38','DDEF','A838','A842','A849','A84F','A863')){$anchors.Add([int[]](@($count)+$values))}
  $inputs=[int[]]@(@('tick','irq','latch','clock') | ForEach-Object {[Convert]::ToUInt16($f[$_],16)});$key=$inputs -join ','
  if($key -ne $inputKey){$schedule.Add([int[]](@($count)+$inputs));$inputKey=$key};$count++;if($ObservedPrefix -and $f.y -eq 'AFC2' -and $f.pending -eq '0000' -and $f.win -eq '0010'){break};if($NudgeMotion -and !$NudgeReturn -and $f.y -eq 'B339'){break}
 }elseif($kind -eq 'QE' -or ($kind -eq 'WC' -and $f.pc -eq '5B80')){$tag=if($kind -eq 'QE'){1}else{2};$stream=if($kind -eq 'QE'){[Convert]::ToUInt16($f.stream,16)}else{0};$native.Add([int[]]@(($count-1),$tag,[Convert]::ToUInt16($f.clock,16),$stream))}
 elseif($kind -eq 'PI'){$conditions.Add([int[]](@($count-1)+@(@('selector','p0','p1','p2','p3','p6','p7') | ForEach-Object {[Convert]::ToUInt16($f[$_],16)})))}
 elseif($kind -eq 'LF'){$lamp.AppendData([byte[]]@([Convert]::ToByte($f.id,16),([Convert]::ToByte($f.pattern,16) -band 15),[Convert]::ToByte($f.column,16)));$lamp.AppendData([Convert]::FromHexString($f.frames));$lamps++}
 elseif($kind -eq 'SN'){$soundRow=[int[]]@(@('cursor','opcode','clock','choice','rate','tempo','gate','flags','pitch','transpose') | ForEach-Object {[Convert]::ToUInt16($f[$_],16)});AppendWords $sound $soundRow;$soundObservations.Add($soundRow);$sounds++}
 elseif($kind -eq 'AB'){$serial.Add([Convert]::ToByte($f.value,16))}
}

if(!$NudgeEntry -and ($initial.y -ne 'DBC4' -or (!$Availability -and !$Continuation -and $last.y -ne 'DE81') -or (!$Availability -and $Continuation -and $last.y -notin @('DD38','E2FC')) -or ($Availability -and $last.y -notin @('DD7E','DD98')))){throw 'Incomplete natural link reference'}

if($NudgeEntry -and ($initial.y -ne $(if($TailWindow){'AFC2'}else{'E247'}) -or $last.y -ne $(if($NudgeTail){'AFF0'}elseif($NudgeWinTransfer){'AFC2'}elseif($NudgeExit){'E460'}elseif($NudgeResult){'E263'}elseif($NudgeSequence){'B749'}elseif($NudgeReturn){'B403'}elseif($NudgeMotion){'B339'}elseif($NudgeRequest){'B31F'}elseif($NudgePrompt){'B403'}else{'B4C5'}))){throw 'Incomplete nudge preparation reference'}
if($NudgeReturn -and !$NudgeSequence -and $last.pot -ne '02'){throw 'Return did not retain two nudges'}
if($NudgeWinTransfer -and ($last.pending -ne '0000' -or $last.win -ne '0010')){throw 'Incomplete pending-to-current-win transfer'}
if($NudgeSequence -and $last.pot -ne '00'){throw 'Sequence did not exhaust the pot'}
if($null -ne $prefix -and ($prefixCount -ne $prefix.instructions -or [Convert]::ToHexString($prefixHash.GetHashAndReset()) -cne $prefix.expected_vm_sha256)){throw 'Continuation changed the independently captured prefix'}
$prefixHash.Dispose()
$orderedSites=[ordered]@{};foreach($key in ($sites.Keys|Sort-Object)){$orderedSites[$key]=$sites[$key]};$orderedTokens=[ordered]@{};foreach($key in ($tokens.Keys|Sort-Object)){$orderedTokens[$key]=$tokens[$key]}
[ordered]@{terminal_ram_hex=$(if($NudgeResult -and !$ObservedPrefix){[Convert]::ToHexString([IO.File]::ReadAllBytes((Join-Path $RunDirectory 'result-ram.bin')))}else{$null});classification=$classification;availability=@($availabilityRows.ToArray());raw_instructions=$rawCount;raw_vm_sha256=[Convert]::ToHexString($rawVm.GetHashAndReset());lifted_dispatches=$lifted;undefined_frame_masks=$frameMasks;ordinal_frame_masks=@($ordinalFrameMasks.ToArray());initial=$initial;terminal=$last;ram_hex=[Convert]::ToHexString([IO.File]::ReadAllBytes((Join-Path $RunDirectory $(if($TailWindow){'tail-entry-ram.bin'}else{'boundary-ram.bin'}))));instructions=$count;expected_vm_sha256=[Convert]::ToHexString($vm.GetHashAndReset());inputs=@($schedule.ToArray());conditions=@($conditions.ToArray());before_reads=@($beforeReads.ToArray());byte_reads=@($byteReads.ToArray());native=@($native.ToArray());anchors=@($anchors.ToArray());lamp_requests=$lamps;expected_lamp_sha256=[Convert]::ToHexString($lamp.GetHashAndReset());sound_commands=$sounds;sound_observations=@($soundObservations.ToArray());expected_sound_sha256=[Convert]::ToHexString($sound.GetHashAndReset());serial_hex=[Convert]::ToHexString($serial.ToArray());sites=$orderedSites;tokens=$orderedTokens} | ConvertTo-Json -Depth 7 -Compress | Set-Content (Join-Path $target ($stem+'.json'))
[ordered]@{run_directory=$RunDirectory;observed_prefix=[bool]$ObservedPrefix;process_exit_code=$(Get-Content (Join-Path $RunDirectory 'exit-code.txt') -Raw);raw_sha256=(Get-FileHash (Join-Path $RunDirectory 'debug.log')).Hash;ram_sha256=(Get-FileHash (Join-Path $RunDirectory $(if($TailWindow){'tail-entry-ram.bin'}else{'boundary-ram.bin'}))).Hash;classification=$classification;prefix_instructions=$(if($null -ne $prefix){$prefix.instructions}else{0});prefix_vm_sha256=$(if($null -ne $prefix){$prefix.expected_vm_sha256}else{$null});tail_window=[bool]$TailWindow;capture=(Get-Content (Join-Path $RunDirectory 'provenance.json') -Raw|ConvertFrom-Json)} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $target ($stem+'-verification.json'))
Copy-Item (Join-Path $RunDirectory 'debugger.cmd') (Join-Path $target ($stem+'-debugger.cmd'))
foreach($hash in @($vm,$rawVm,$lamp,$sound)){$hash.Dispose()}

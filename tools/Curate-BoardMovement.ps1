param([Parameter(Mandatory=$true)][string]$RunDirectory,[switch]$NudgePotProbe,[switch]$Continuation)
$ErrorActionPreference='Stop';if($NudgePotProbe -and $Continuation){throw 'Synthetic nudge probe cannot be combined with natural continuation'};$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash';$stem=if($NudgePotProbe){'nudge-pot-probe'}elseif($Continuation){'board-movement-next'}else{'board-movement'};$classification=if($NudgePotProbe){'Synthetic DDE3 invocation at the natural square-7 roll return; explicit Y redirection, not a naturally reached nudge animation'}else{'Natural post-roll board movement with physical campaign input; no memory/register injection'}
$prefix=$null;$prefixCount=0;$prefixHash=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
if($Continuation){$prefix=Get-Content (Join-Path $target (('board-movement')+'.json')) -Raw|ConvertFrom-Json}
$keys=@('y','token','top','second','third','fourth','u','s','f4','f6','frame','tick','irq','seed','choice','rate','latch','pending','win','guard','checksum','mode','display','suppress','clock','board','pot')
$vm=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
$rawVm=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256);$rawCount=0;$lifted=0
$lamp=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256);$sound=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
$schedule=[Collections.Generic.List[object]]::new();$anchors=[Collections.Generic.List[object]]::new();$conditions=[Collections.Generic.List[object]]::new();$beforeReads=[Collections.Generic.List[object]]::new();$serial=[Collections.Generic.List[byte]]::new()
$byteReads=[Collections.Generic.List[object]]::new();$native=[Collections.Generic.List[object]]::new();$soundObservations=[Collections.Generic.List[object]]::new()
$frameMasks=[ordered]@{}
$initial=$null;$last=$null;$count=0;$inputKey='';$lamps=0;$sounds=0;$previous=$null;$sites=@{};$tokens=@{};$busy=0UL;$outer=0UL;$irq=[Collections.Generic.Stack[object]]::new()
function AppendWords($hash,$values){$bytes=[byte[]]::new($values.Count*2);for($n=0;$n -lt $values.Count;$n++){$bytes[2*$n]=[byte]($values[$n] -shr 8);$bytes[2*$n+1]=[byte]($values[$n] -band 255)};$hash.AppendData($bytes)}
foreach($line in [IO.File]::ReadLines((Join-Path $RunDirectory 'debug.log'))) {
 if($line -notmatch '^(SC|LF|AB|SN|PI|IE|IX|QE|WC) '){continue};$kind=$Matches[1];$f=[ordered]@{}
 foreach($match in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$f[$match.Groups[1].Value]=$match.Groups[2].Value}
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
  # Local-release 76BD is lifted inside the shared physical stack return helper.
  if($f.y -eq '76BD'){continue}
  if($frameMasks.Contains($f.y)){$values[10]=$values[10] -band $frameMasks[$f.y]};AppendWords $vm $values;if($null -ne $prefix -and $prefixCount -lt $prefix.instructions){AppendWords $prefixHash $values;$prefixCount++}
  if($count -lt 180 -or $count%1024 -eq 0 -or $f.y -in @('DE11','DE13','DE30','DE42','DE7F','DBC4','DBED','DE96','DD38','DDEF','A838','A842','A849','A84F','A863')){$anchors.Add([int[]](@($count)+$values))}
  $inputs=[int[]]@(@('tick','irq','latch','clock') | ForEach-Object {[Convert]::ToUInt16($f[$_],16)});$key=$inputs -join ','
  if($key -ne $inputKey){$schedule.Add([int[]](@($count)+$inputs));$inputKey=$key};$count++
 }elseif($kind -eq 'QE' -or ($kind -eq 'WC' -and $f.pc -eq '5B80')){$tag=if($kind -eq 'QE'){1}else{2};$stream=if($kind -eq 'QE'){[Convert]::ToUInt16($f.stream,16)}else{0};$native.Add([int[]]@(($count-1),$tag,[Convert]::ToUInt16($f.clock,16),$stream))}
 elseif($kind -eq 'PI'){$conditions.Add([int[]](@($count-1)+@(@('selector','p0','p1','p2','p3','p6','p7') | ForEach-Object {[Convert]::ToUInt16($f[$_],16)})))}
 elseif($kind -eq 'LF'){$lamp.AppendData([byte[]]@([Convert]::ToByte($f.id,16),([Convert]::ToByte($f.pattern,16) -band 15),[Convert]::ToByte($f.column,16)));$lamp.AppendData([Convert]::FromHexString($f.frames));$lamps++}
 elseif($kind -eq 'SN'){$soundRow=[int[]]@(@('cursor','opcode','clock','choice','rate','tempo','gate','flags','pitch','transpose') | ForEach-Object {[Convert]::ToUInt16($f[$_],16)});AppendWords $sound $soundRow;$soundObservations.Add($soundRow);$sounds++}
 elseif($kind -eq 'AB'){$serial.Add([Convert]::ToByte($f.value,16))}
}

if((!$NudgePotProbe -and ($initial.y -ne 'B28F' -or $last.y -notin $(if($Continuation){@('DD38','E2FC')}else{@('DD38','DE96')}))) -or ($NudgePotProbe -and ($initial.y -ne 'DDE3' -or $last.y -ne 'DDEF'))){throw 'Incomplete or changed board movement/probe reference'}
$rollTerminal=(Get-Content (Join-Path $target 'dice-motion-vm.json') -Raw|ConvertFrom-Json).terminal
foreach($key in $keys[0..24]) {
 if($NudgePotProbe -and $key -in @('y','token')){continue}
 if($initial[$key] -cne $rollTerminal.$key){throw ('Movement/probe entry differs from prior independent roll boundary: '+$key)}
}
if($Continuation -and ($prefixCount -ne $prefix.instructions -or [Convert]::ToHexString($prefixHash.GetHashAndReset()) -cne $prefix.expected_vm_sha256)){throw 'Continuation changed the independently captured prefix'}
$prefixHash.Dispose()
$orderedSites=[ordered]@{};foreach($key in ($sites.Keys|Sort-Object)){$orderedSites[$key]=$sites[$key]};$orderedTokens=[ordered]@{};foreach($key in ($tokens.Keys|Sort-Object)){$orderedTokens[$key]=$tokens[$key]}
[ordered]@{classification=$classification;raw_instructions=$rawCount;raw_vm_sha256=[Convert]::ToHexString($rawVm.GetHashAndReset());lifted_dispatches=$lifted;undefined_frame_masks=$frameMasks;initial=$initial;terminal=$last;ram_hex=[Convert]::ToHexString([IO.File]::ReadAllBytes((Join-Path $RunDirectory 'boundary-ram.bin')));instructions=$count;expected_vm_sha256=[Convert]::ToHexString($vm.GetHashAndReset());inputs=@($schedule.ToArray());conditions=@($conditions.ToArray());before_reads=@($beforeReads.ToArray());byte_reads=@($byteReads.ToArray());native=@($native.ToArray());anchors=@($anchors.ToArray());lamp_requests=$lamps;expected_lamp_sha256=[Convert]::ToHexString($lamp.GetHashAndReset());sound_commands=$sounds;sound_observations=@($soundObservations.ToArray());expected_sound_sha256=[Convert]::ToHexString($sound.GetHashAndReset());serial_hex=[Convert]::ToHexString($serial.ToArray());sites=$orderedSites;tokens=$orderedTokens} | ConvertTo-Json -Depth 7 -Compress | Set-Content (Join-Path $target ($stem+'.json'))
[ordered]@{run_directory=$RunDirectory;raw_sha256=(Get-FileHash (Join-Path $RunDirectory 'debug.log')).Hash;ram_sha256=(Get-FileHash (Join-Path $RunDirectory 'boundary-ram.bin')).Hash;classification=$classification;prefix_instructions=$(if($Continuation){$prefix.instructions}else{0});prefix_vm_sha256=$(if($Continuation){$prefix.expected_vm_sha256}else{$null});capture=(Get-Content (Join-Path $RunDirectory 'provenance.json') -Raw|ConvertFrom-Json)} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $target ($stem+'-verification.json'))
Copy-Item (Join-Path $RunDirectory 'debugger.cmd') (Join-Path $target ($stem+'-debugger.cmd'))
foreach($hash in @($vm,$rawVm,$lamp,$sound)){$hash.Dispose()}

param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash'
$feature=Get-Content (Join-Path $target 'feature-replay.json') -Raw | ConvertFrom-Json
$keys=@('y','token','top','second','third','fourth','u','s','f4','f6','frame','tick','irq','seed','choice','rate','latch','pending','win','guard','checksum','mode','display','suppress','clock')
$prefix=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
$vm=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
$lamp=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
$sound=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
$serial=[Collections.Generic.List[byte]]::new();$schedule=[Collections.Generic.List[object]]::new();$padding=$null;$initial=$null;$alpha=$null;$frames=$null;$initialFrames=$null;$active=$false;$count=0;$prefixCount=0;$previousInput='';$lampCount=0;$soundCount=0
$sites=@{};$tokens=@{};$previous=$null;$busy=0UL;$outer=$null;$irqStack=[Collections.Generic.Stack[object]]::new()
$anchors=[Collections.Generic.List[object]]::new()
function AppendWords($hash,$values){$bytes=[byte[]]::new($values.Count*2);for($n=0;$n -lt $values.Count;$n++){$bytes[2*$n]=[byte]($values[$n] -shr 8);$bytes[2*$n+1]=[byte]($values[$n] -band 255)};$hash.AppendData($bytes)}
foreach($line in [IO.File]::ReadLines((Join-Path $RunDirectory 'debug.log'))) {
 if($line -notmatch '^(SC|LF|AE|AB|SN|IE|IX) '){continue};$kind=$Matches[1];$fields=[ordered]@{}
 foreach($match in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$fields[$match.Groups[1].Value]=$match.Groups[2].Value}
 if(!$active) {
  if($kind -eq 'LF'){$frames=$fields.frames}
  if($kind -ne 'SC'){continue}
  AppendWords $prefix @($keys | ForEach-Object {[Convert]::ToUInt16($fields[$_],16)});$prefixCount++
  if($fields.y -ne 'C767'){continue}
  if($prefixCount -ne $feature.instructions -or [Convert]::ToHexString($prefix.GetHashAndReset()) -ne $feature.expected_sha256){throw 'Pre-probe feature prefix differs'}
  $initialFrames=$frames;$active=$true;$fields.y='A365';$fields.token='9B3E';$initial=$fields
 }
 if($kind -eq 'IE') {if($irqStack.Count -eq 0){$outer=[Convert]::ToUInt64($fields.cycle,16)};$irqStack.Push($fields);continue}
 if($kind -eq 'IX') {if($irqStack.Count -eq 0){throw 'Unmatched probe IRQ return'};$entry=$irqStack.Pop();if($entry.s -ne $fields.s){throw 'Probe IRQ stack mismatch'};if($irqStack.Count -eq 0){$busy+=[Convert]::ToUInt64($fields.cycle,16)-$outer};continue}
 if($kind -eq 'SC') {
  # 856F is lifted as a typed active-list zero test. Do not fabricate native
  # allocator pointer values at its internal 8571..8577 dispatches.
  if($fields.y -in @('8571','8573','8575','8577')){continue}
  $cycle=[Convert]::ToUInt64($fields.cycle,16)
  if($null -ne $previous){$cost=$cycle-$previous.cycle-($busy-$previous.busy);if($cost -gt 0){foreach($pair in @(@($sites,$previous.y),@($tokens,$previous.token))){if(!$pair[0].ContainsKey($pair[1]) -or $cost -lt $pair[0][$pair[1]]){$pair[0][$pair[1]]=$cost}}}}
  $previous=@{cycle=$cycle;busy=$busy;y=$fields.y;token=$fields.token}
  $signature=@($keys | ForEach-Object {[Convert]::ToUInt16($fields[$_],16)})
  AppendWords $vm $signature
  if($count -lt 30 -or $count%2048 -eq 0 -or $fields.y -eq 'A398'){$anchors.Add([int[]](@($count)+$signature))}
  $values=@('tick','irq','clock','latch') | ForEach-Object {[Convert]::ToUInt16($fields[$_],16)};$inputKey=$values -join ','
  if($inputKey -ne $previousInput){$schedule.Add([int[]](@($count)+$values));$previousInput=$inputKey}
  if($fields.y -eq '9B49'){$padding=@('top','second','third','fourth') | ForEach-Object {[Convert]::ToUInt16($fields[$_],16)}}
  $count++;if($fields.y -eq 'A398'){break}
 }elseif($kind -eq 'LF') {
  $lamp.AppendData([byte[]]@([Convert]::ToByte($fields.id,16),([Convert]::ToByte($fields.pattern,16) -band 15),[Convert]::ToByte($fields.column,16)))
  $lamp.AppendData([Convert]::FromHexString($fields.frames));$lampCount++
 }elseif($kind -eq 'AE' -and $null -eq $alpha){$alpha=$fields}
 elseif($kind -eq 'AB'){$serial.Add([Convert]::ToByte($fields.value,16))}
 elseif($kind -eq 'SN') {AppendWords $sound @(@('cursor','opcode','clock','choice','rate','tempo','gate','flags','pitch','transpose') | ForEach-Object {[Convert]::ToUInt16($fields[$_],16)});$soundCount++}
}
if($null -eq $initial -or $fields.y -ne 'A398' -or $null -eq $padding -or $null -eq $alpha -or $lampCount -ne 485){throw 'Incomplete synthetic helper probe'}
$orderedSites=[ordered]@{};foreach($key in ($sites.Keys | Sort-Object)){$orderedSites[$key]=$sites[$key]};$orderedTokens=[ordered]@{};foreach($key in ($tokens.Keys | Sort-Object)){$orderedTokens[$key]=$tokens[$key]}
[ordered]@{classification='Synthetic MAME helper experiment: redirect Y from C767 to A365 at the real feature return boundary. Not a reached jackpot award. Prefix digest matches original feature; internal allocator-pointer zero-test rows are lifted';initial=$initial;initial_frames=$initialFrames;initial_alpha=$alpha;residual_stack_cells=$padding;instructions=$count;expected_vm_sha256=[Convert]::ToHexString($vm.GetHashAndReset());inputs=@($schedule.ToArray());anchors=@($anchors.ToArray());lamp_requests=$lampCount;expected_lamp_sha256=[Convert]::ToHexString($lamp.GetHashAndReset());serial_hex=[Convert]::ToHexString($serial.ToArray());sound_commands=$soundCount;expected_sound_sha256=[Convert]::ToHexString($sound.GetHashAndReset());sites=$orderedSites;tokens=$orderedTokens} | ConvertTo-Json -Depth 7 -Compress | Set-Content (Join-Path $target 'jackpot-probe.json')
[ordered]@{classification='Synthetic register redirect; no original workspace writes';run_directory=$RunDirectory;raw_debug_sha256=(Get-FileHash (Join-Path $RunDirectory 'debug.log')).Hash;prefix_dispatches=$prefixCount;prefix_vm_sha256=$feature.expected_sha256} | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $target 'jackpot-probe-verification.json')
Copy-Item (Join-Path $RunDirectory 'debugger.cmd') (Join-Path $target 'jackpot-probe-debugger.cmd')
foreach($hash in @($prefix,$vm,$lamp,$sound)){$hash.Dispose()}

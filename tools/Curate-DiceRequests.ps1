param([Parameter(Mandatory=$true)][string]$RunDirectory,[switch]$Motion)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash'
$keys=@('y','token','top','second','third','fourth','u','s','f4','f6','frame','tick','irq','seed','choice','rate','latch','pending','win','guard','checksum','mode','display','suppress','clock')
$vm=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
$lamp=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256);$sound=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
$schedule=[Collections.Generic.List[object]]::new();$anchors=[Collections.Generic.List[object]]::new();$conditions=[Collections.Generic.List[object]]::new();$beforeReads=[Collections.Generic.List[object]]::new();$serial=[Collections.Generic.List[byte]]::new()
$native=[Collections.Generic.List[object]]::new();$soundObservations=[Collections.Generic.List[object]]::new()
$body=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256);$bodyActive=$false;$bodyCount=0
$frameMasks=[ordered]@{}
$initial=$null;$last=$null;$count=0;$inputKey='';$lamps=0;$sounds=0;$previous=$null;$sites=@{};$tokens=@{};$busy=0UL;$outer=0UL;$irq=[Collections.Generic.Stack[object]]::new()
function AppendWords($hash,$values){$bytes=[byte[]]::new($values.Count*2);for($n=0;$n -lt $values.Count;$n++){$bytes[2*$n]=[byte]($values[$n] -shr 8);$bytes[2*$n+1]=[byte]($values[$n] -band 255)};$hash.AppendData($bytes)}
foreach($line in [IO.File]::ReadLines((Join-Path $RunDirectory 'debug.log'))) {
 if($line -notmatch '^(SC|LF|AB|SN|PI|IE|IX|QE|WC) '){continue};$kind=$Matches[1];$f=[ordered]@{}
 foreach($match in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$f[$match.Groups[1].Value]=$match.Groups[2].Value}
 if($kind -eq 'IE'){if($irq.Count -eq 0){$outer=[Convert]::ToUInt64($f.cycle,16)};$irq.Push($f);continue}
 if($kind -eq 'IX'){if($irq.Count -eq 0 -or $irq.Pop().s -ne $f.s){throw 'IRQ nesting differs'};if($irq.Count -eq 0){$busy+=[Convert]::ToUInt64($f.cycle,16)-$outer};continue}
 if($kind -eq 'SC') {
  if($null -eq $initial){$initial=$f};$last=$f
  $cycle=[Convert]::ToUInt64($f.cycle,16)
  if($null -ne $previous){$cost=$cycle-$previous.cycle-($busy-$previous.busy);if($cost -gt 0){foreach($pair in @(@($sites,$previous.y),@($tokens,$previous.token))){if(!$pair[0].ContainsKey($pair[1]) -or $cost -lt $pair[0][$pair[1]]){$pair[0][$pair[1]]=$cost}}};if($previous.token -eq '790D' -and $previous.top -eq '002D' -and $f.top -ne $previous.tick){$delta=([int][Convert]::ToUInt16($f.top,16)-[int][Convert]::ToUInt16($previous.tick,16)+65536)%65536;$beforeReads.Add([int[]]@(($count-1),$delta))}}
  $previous=@{cycle=$cycle;busy=$busy;y=$f.y;token=$f.token;top=$f.top;tick=$f.tick}
  $values=[int[]]@($keys | ForEach-Object {[Convert]::ToUInt16($f[$_],16)})
  if($f.y -eq 'B271'){$bodyActive=$true};if($bodyActive){AppendWords $body $values;$bodyCount++};if($f.y -eq 'B283'){$bodyActive=$false}
  # Local-release 76BD is lifted inside the shared physical stack return helper.
  if($f.y -eq '76BD'){continue}
  if($frameMasks.Contains($f.y)){$values[10]=$values[10] -band $frameMasks[$f.y]};AppendWords $vm $values
  if($count -lt 180 -or $count%1024 -eq 0 -or $f.y -in @('DDAB','DE96','E2FC','C721','C767','E460')){$anchors.Add([int[]](@($count)+$values))}
  $inputs=[int[]]@(@('tick','irq','latch','clock') | ForEach-Object {[Convert]::ToUInt16($f[$_],16)});$key=$inputs -join ','
  if($key -ne $inputKey){$schedule.Add([int[]](@($count)+$inputs));$inputKey=$key};$count++
 }elseif($kind -eq 'QE' -or ($kind -eq 'WC' -and $f.pc -eq '5B80')){$tag=if($kind -eq 'QE'){1}else{2};$stream=if($kind -eq 'QE'){[Convert]::ToUInt16($f.stream,16)}else{0};$native.Add([int[]]@(($count-1),$tag,[Convert]::ToUInt16($f.clock,16),$stream))}
 elseif($kind -eq 'PI'){$conditions.Add([int[]](@($count-1)+@(@('selector','p0','p1','p2','p3','p6','p7') | ForEach-Object {[Convert]::ToUInt16($f[$_],16)})))}
 elseif($kind -eq 'LF'){$lamp.AppendData([byte[]]@([Convert]::ToByte($f.id,16),([Convert]::ToByte($f.pattern,16) -band 15),[Convert]::ToByte($f.column,16)));$lamp.AppendData([Convert]::FromHexString($f.frames));$lamps++}
 elseif($kind -eq 'SN'){$soundRow=[int[]]@(@('cursor','opcode','clock','choice','rate','tempo','gate','flags','pitch','transpose') | ForEach-Object {[Convert]::ToUInt16($f[$_],16)});AppendWords $sound $soundRow;$soundObservations.Add($soundRow);$sounds++}
 elseif($kind -eq 'AB'){$serial.Add([Convert]::ToByte($f.value,16))}
}

if($initial.y -ne 'DD7E' -or $last.y -ne $(if($Motion){'B28F'}else{'B283'})){throw 'Incomplete or changed dice-requests reference'}
$baseline=Get-Content (Join-Path $target 'dice-request-body.json') -Raw|ConvertFrom-Json;$bodyHash=[Convert]::ToHexString($body.GetHashAndReset());$body.Dispose()
if($bodyCount -ne $baseline.instructions -or $bodyHash -ne $baseline.expected_vm_sha256){throw 'The narrower independent dice-request capture differs'}
$orderedSites=[ordered]@{};foreach($key in ($sites.Keys|Sort-Object)){$orderedSites[$key]=$sites[$key]};$orderedTokens=[ordered]@{};foreach($key in ($tokens.Keys|Sort-Object)){$orderedTokens[$key]=$tokens[$key]}
[ordered]@{classification=$(if($Motion){'Natural square-7 roll through B28F; captured VM and output reference, not Live player input'}else{'Natural dice request path on board square 7. Captured platform/input replay; stops before physical reel motion. No result injection'});undefined_frame_masks=$frameMasks;initial=$initial;terminal=$last;ram_hex=[Convert]::ToHexString([IO.File]::ReadAllBytes((Join-Path $RunDirectory 'boundary-ram.bin')));instructions=$count;expected_vm_sha256=[Convert]::ToHexString($vm.GetHashAndReset());inputs=@($schedule.ToArray());conditions=@($conditions.ToArray());before_reads=@($beforeReads.ToArray());native=@($native.ToArray());anchors=@($anchors.ToArray());lamp_requests=$lamps;expected_lamp_sha256=[Convert]::ToHexString($lamp.GetHashAndReset());sound_commands=$sounds;sound_observations=@($soundObservations.ToArray());expected_sound_sha256=[Convert]::ToHexString($sound.GetHashAndReset());serial_hex=[Convert]::ToHexString($serial.ToArray());sites=$orderedSites;tokens=$orderedTokens} | ConvertTo-Json -Depth 7 -Compress | Set-Content (Join-Path $target $(if($Motion){'dice-motion-vm.json'}else{'dice-requests.json'}))
[ordered]@{run_directory=$RunDirectory;raw_sha256=(Get-FileHash (Join-Path $RunDirectory 'debug.log')).Hash;ram_sha256=(Get-FileHash (Join-Path $RunDirectory 'boundary-ram.bin')).Hash;classification=$(if($Motion){'Natural roll through B28F; one native alpha brightness restoration difference remains explicit in verification; no memory/register injection'}else{'Natural dice request boundary; no memory/register injection'});independent_body_dispatches=$bodyCount;independent_body_sha256=$bodyHash} | ConvertTo-Json | Set-Content (Join-Path $target $(if($Motion){'dice-motion-vm-verification.json'}else{'dice-requests-verification.json'}))
Copy-Item (Join-Path $RunDirectory 'debugger.cmd') (Join-Path $target $(if($Motion){'dice-motion-vm-debugger.cmd'}else{'dice-requests-debugger.cmd'}))
foreach($hash in @($vm,$lamp,$sound)){$hash.Dispose()}

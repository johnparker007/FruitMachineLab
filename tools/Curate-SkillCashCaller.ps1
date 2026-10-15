param([Parameter(Mandatory=$true)][string]$RunDirectory,[switch]$BoardResult)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash'
$keys=@('y','token','top','second','third','fourth','u','s','f4','f6','frame','tick','irq','seed','choice','rate','latch','pending','win','guard','checksum','mode','display','suppress','clock')
$rows=[Collections.Generic.List[object]]::new();$lamps=[Collections.Generic.List[object]]::new();$sounds=[Collections.Generic.List[object]]::new();$serial=[Collections.Generic.List[byte]]::new()
$feature=Get-Content (Join-Path $target 'feature-replay.json') -Raw | ConvertFrom-Json
$hash=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
$phase='entry';$count=0;$initialFrames=$null;$initialAlpha=$null
$sites=@{};$tokens=@{};$previous=$null;$busy=0UL;$outer=0UL;$irq=[Collections.Generic.Stack[object]]::new()
foreach($line in [IO.File]::ReadLines((Join-Path $RunDirectory 'debug.log'))) {
 if($line -notmatch '^(SC|LI|LF|AE|AB|SN|IE|IX) '){continue};$kind=$Matches[1];$f=[ordered]@{}
 foreach($match in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$f[$match.Groups[1].Value]=$match.Groups[2].Value}
 if($kind -eq 'IE'){if($irq.Count -eq 0){$outer=[Convert]::ToUInt64($f.cycle,16)};$irq.Push($f);continue}
 if($kind -eq 'IX'){if($irq.Count -eq 0 -or $irq.Pop().s -ne $f.s){throw 'IRQ nesting differs'};if($irq.Count -eq 0){$busy+=[Convert]::ToUInt64($f.cycle,16)-$outer};continue}
 if($kind -eq 'SC') {
  $cycle=[Convert]::ToUInt64($f.cycle,16)
  if($null -ne $previous){$cost=$cycle-$previous.cycle-($busy-$previous.busy);if($cost -gt 0){foreach($pair in @(@($sites,$previous.y),@($tokens,$previous.token))){if(!$pair[0].ContainsKey($pair[1]) -or $cost -lt $pair[0][$pair[1]]){$pair[0][$pair[1]]=$cost}}}}
  $previous=@{cycle=$cycle;busy=$busy;y=$f.y;token=$f.token}
  if($f.y -eq 'C721'){$phase='feature'}
  $values=[int[]]@($keys | ForEach-Object {[Convert]::ToUInt16($f[$_],16)})
  if($phase -eq 'feature') {
   $bytes=[byte[]]::new(50);for($n=0;$n -lt 25;$n++){$bytes[2*$n]=[byte]($values[$n] -shr 8);$bytes[2*$n+1]=[byte]($values[$n] -band 255)};$hash.AppendData($bytes);$count++
   if($f.y -eq 'C767'){$phase='exit'}
  }else{$rows.Add($values)}
 }elseif($phase -eq 'entry') {
  if($kind -eq 'LI' -and $null -eq $initialFrames){$initialFrames=$f.frames}
  if($kind -eq 'AE' -and $null -eq $initialAlpha){$initialAlpha=$f}
  if($kind -eq 'LF'){$lamps.Add($f)}
  if($kind -eq 'SN'){$sounds.Add($f)}
  if($kind -eq 'AB'){$serial.Add([Convert]::ToByte($f.value,16))}
 }
}
$digest=[Convert]::ToHexString($hash.GetHashAndReset());$hash.Dispose()
if($count -ne $feature.instructions -or $digest -ne $feature.expected_sha256){throw "Caller feature body differs: $count / $digest"}
$first=if($BoardResult){0xE2FC}else{0xDFF6};$last=if($BoardResult){0xE33C}else{0xE0BF};$name=if($BoardResult){'board-result'}else{'caller'}
if($rows[0][0] -ne $first -or $rows[-1][0] -ne $last -or $null -eq $initialFrames -or $null -eq $initialAlpha){throw 'Incomplete natural caller capture'}
$orderedSites=[ordered]@{};foreach($key in ($sites.Keys | Sort-Object)){$orderedSites[$key]=$sites[$key]};$orderedTokens=[ordered]@{};foreach($key in ($tokens.Keys | Sort-Object)){$orderedTokens[$key]=$tokens[$key]}
[ordered]@{classification='Trace-backed natural board-position-32 caller; unchanged physical input campaign. Middle C721 digest independently matches the original reference';fields=$keys;rows=@($rows.ToArray());initial_frames=$initialFrames;initial_alpha=$initialAlpha;entry_lamps=@($lamps.ToArray());entry_sound=@($sounds.ToArray());entry_serial_hex=[Convert]::ToHexString($serial.ToArray());feature_dispatches=$count;feature_sha256=$digest;sites=$orderedSites;tokens=$orderedTokens} | ConvertTo-Json -Depth 7 | Set-Content (Join-Path $target "$name.json")
[ordered]@{run_directory=$RunDirectory;raw_sha256=(Get-FileHash (Join-Path $RunDirectory 'debug.log')).Hash;classification='Natural caller path, no RAM/register injection';feature_sha256=$digest} | ConvertTo-Json | Set-Content (Join-Path $target "$name-verification.json")
Copy-Item (Join-Path $RunDirectory 'debugger.cmd') (Join-Path $target "$name-debugger.cmd")

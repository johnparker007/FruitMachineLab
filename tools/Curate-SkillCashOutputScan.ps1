param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash'
$original=Get-Content (Join-Path $target 'hashes.json') -Raw | ConvertFrom-Json;$comparisons=[ordered]@{}
foreach($name in @('state.csv','feature-state.csv','input-levels.csv','ram-final.bin')) {
 $expected=($original | Where-Object {[IO.Path]::GetFileName($_.Path) -eq $name}).Hash;$actual=(Get-FileHash (Join-Path $RunDirectory $name)).Hash
 if($actual -ne $expected){throw "Scan capture differs in $name"};$comparisons[$name]=[ordered]@{equal=$true;sha256=$actual}
}
$initial=$null;$previous=$null;$entry=$null;$count=0;$inputs=[Collections.Generic.List[object]]::new();$anchors=[Collections.Generic.List[object]]::new();$bytes=[IO.MemoryStream]::new()
$pulseEntry=$null;$pulses=[Collections.Generic.List[object]]::new()
try {
 foreach($line in [IO.File]::ReadLines((Join-Path $RunDirectory 'debug.log'))) {
  if($line -notmatch '^(SI|SX|PE|PX) '){continue};$kind=$Matches[1];$state=[ordered]@{}
  foreach($match in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$state[$match.Groups[1].Value]=$match.Groups[2].Value}
  if($kind -eq 'PE') {$pulseEntry=$state;continue}
  if($kind -eq 'PX') {
   if($null -eq $pulseEntry){throw 'Pulse return without entry'}
   $values=@($count)
   foreach($key in @('enabled','count','reload','step','timer','callback','control')){$values+=[Convert]::ToInt32($pulseEntry[$key],16)}
   foreach($key in @('count','step','timer','callback','control')){$values+=[Convert]::ToInt32($state[$key],16)}
   $pulses.Add([int[]]$values);$pulseEntry=$null;continue
  }
  if($kind -eq 'SI') {
   if($null -ne $entry){throw 'Nested output scan'};$entry=$state
   if($null -eq $initial){$initial=$state} else {
    $changes=[ordered]@{};foreach($key in $state.Keys){if($state[$key] -ne $previous[$key]){$changes[$key]=$state[$key]}}
    if($changes.Count -ne 0){$inputs.Add([ordered]@{ordinal=$count;changes=$changes})}
   }
  } else {
   if($null -eq $entry){throw 'Scan return without entry'}
   foreach($key in @('phase','count','reload','alternate','alternate_reload')){$bytes.WriteByte([Convert]::ToByte($state[$key],16))}
   $column=[Convert]::ToInt32($state.column,16);$bytes.WriteByte([byte]($column -shr 8));$bytes.WriteByte([byte]($column -band 255));$bytes.Write([Convert]::FromHexString($state.ports))
   if($count%128 -eq 0){$anchors.Add([ordered]@{ordinal=$count;phase=[Convert]::ToInt32($state.phase,16);count=[Convert]::ToInt32($state.count,16);reload=[Convert]::ToInt32($state.reload,16);alternate=[Convert]::ToInt32($state.alternate,16);alternate_reload=[Convert]::ToInt32($state.alternate_reload,16);column=$column;ports=$state.ports})}
   $previous=$state;$entry=$null;$count++
  }
 }
 $digest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes.ToArray()))
} finally {$bytes.Dispose()}
if($null -ne $entry -or $null -ne $pulseEntry -or $count -lt 100 -or $pulses.Count -lt 100){throw "Incomplete output scan: $count"}
[ordered]@{classification='Native IRQ output scan with captured between-call RAM inputs, software counter/column transitions and port latches. PIA handshake cycles and PTM callbacks are outside this proof';
 initial=$initial;inputs=@($inputs.ToArray());anchors=@($anchors.ToArray());pulse_calls=@($pulses.ToArray());scans=$count;expected_sha256=$digest} | ConvertTo-Json -Depth 8 -Compress | Set-Content (Join-Path $target 'output-scan.json')
[ordered]@{run_directory=$RunDirectory;raw_debug_sha256=(Get-FileHash (Join-Path $RunDirectory 'debug.log')).Hash;comparisons=$comparisons;provenance=(Get-Content (Join-Path $RunDirectory 'provenance.json') -Raw | ConvertFrom-Json)} |
 ConvertTo-Json -Depth 7 | Set-Content (Join-Path $target 'output-scan-verification.json')
Copy-Item (Join-Path $RunDirectory 'debugger.cmd') (Join-Path $target 'output-scan-debugger.cmd')

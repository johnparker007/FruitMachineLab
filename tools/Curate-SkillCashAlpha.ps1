param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash'
$original=Get-Content (Join-Path $target 'hashes.json') -Raw | ConvertFrom-Json;$comparisons=[ordered]@{}
foreach($name in @('state.csv','feature-state.csv','input-levels.csv','ram-final.bin')) {
 $expected=($original | Where-Object {[IO.Path]::GetFileName($_.Path) -eq $name}).Hash;$actual=(Get-FileHash (Join-Path $RunDirectory $name)).Hash
 if($actual -ne $expected){throw "Alpha capture differs in $name"};$comparisons[$name]=[ordered]@{equal=$true;sha256=$actual}
}
$calls=[Collections.Generic.List[object]]::new();$active=$null;$serial=$null
foreach($line in [IO.File]::ReadLines((Join-Path $RunDirectory 'debug.log'))) {
 if($line -notmatch '^(AR|AZ|AE|AX|AB) '){continue};$tag=$Matches[1];$fields=[ordered]@{}
 foreach($match in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')) {
  $name=$match.Groups[1].Value;$value=$match.Groups[2].Value
  $fields[$name]=if($name -in @('shadow','digits')){$value}else{[Convert]::ToInt32($value,16)}
 }
 if($tag -in @('AR','AE')) {
  if($null -ne $active){throw 'Nested alpha request'};$active=[ordered]@{kind=$tag;before=$fields};$serial=[Collections.Generic.List[object]]::new()
 } elseif($tag -eq 'AB') {
  if($null -eq $active){throw 'Serial output outside captured alpha request'}
  $serial.Add([int[]]@($fields.value,$fields.clock,$fields.tick))
 } else {
  if($null -eq $active -or ($tag -eq 'AZ') -ne ($active.kind -eq 'AR')){throw 'Alpha return boundary differs'}
  $calls.Add([ordered]@{kind=$active.kind;before=$active.before;after=$fields;serial=@($serial.ToArray())});$active=$null
 }
}
if($null -ne $active -or $calls.Count -ne 44){throw "Incomplete alpha capture: $($calls.Count)"}
[ordered]@{classification='Trace-backed native software alpha shadow/cursor/digits and serial-byte sequences. PIA signal edges and VFD device timing are not emulated';calls=@($calls.ToArray())} |
 ConvertTo-Json -Depth 10 -Compress | Set-Content (Join-Path $target 'alpha-calls.json')
[ordered]@{run_directory=$RunDirectory;raw_debug_sha256=(Get-FileHash (Join-Path $RunDirectory 'debug.log')).Hash;comparisons=$comparisons;
 provenance=(Get-Content (Join-Path $RunDirectory 'provenance.json') -Raw | ConvertFrom-Json)} | ConvertTo-Json -Depth 7 | Set-Content (Join-Path $target 'alpha-verification.json')
Copy-Item (Join-Path $RunDirectory 'debugger.cmd') (Join-Path $target 'alpha-debugger.cmd')

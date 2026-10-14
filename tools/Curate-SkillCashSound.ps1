param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$target=Join-Path $root 'evidence/mpu4/skill-cash'
$original=Get-Content (Join-Path $target 'hashes.json') -Raw | ConvertFrom-Json
$comparisons=[ordered]@{}
foreach($name in @('state.csv','feature-state.csv','input-levels.csv','ram-final.bin')) {
 $expected=($original | Where-Object {[System.IO.Path]::GetFileName($_.Path) -eq $name}).Hash
 $actual=(Get-FileHash (Join-Path $RunDirectory $name)).Hash
 if($expected -ne $actual){throw "Native sound capture diverged in $name"}
 $comparisons[$name]=[ordered]@{equal=$true;sha256=$actual}
}
$events=[System.Collections.Generic.List[object]]::new()
$active=$false;$resetWrite=$false;$queueCount=0
foreach($line in [System.IO.File]::ReadLines((Join-Path $RunDirectory 'debug.log'))) {
 if($line -notmatch '^(SQ|QE|SN|SW|WC|SR|SC) '){continue}
 $tag=$Matches[1];$fields=[ordered]@{}
 foreach($match in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$fields[$match.Groups[1].Value]=[Convert]::ToInt32($match.Groups[2].Value,16)}
 if($tag -eq 'SQ') {
  if($fields.stream -ne 0x8EE4){continue}
  if($active){throw 'Overlapping choice streams'}
  $active=$true;$queueCount++
 } elseif($tag -eq 'SR') {
  if(!$active){continue};$resetWrite=$true
 } elseif($tag -eq 'WC' -and $resetWrite) {
  if($fields.pc -eq 0x5B80){$resetWrite=$false;$active=$false}
 } elseif(!$active) {continue}
 if($tag -eq 'SC') {
  if($fields.y -ne 0x8595){continue}
  $tag='read';$fields=[ordered]@{clock=$fields.clock;choice=$fields.choice;rate=$fields.rate}
 }
 if($tag -eq 'QE' -and $fields.stream -ne 0x8EE4){continue}
 $events.Add([ordered]@{kind=$tag;fields=$fields})
}
if($queueCount -ne 3 -or $active -or $resetWrite){throw 'Incomplete native choice-stream capture'}
$events | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $target 'sound-events.json')
[ordered]@{run_directory=$RunDirectory;raw_debug_sha256=(Get-FileHash (Join-Path $RunDirectory 'debug.log')).Hash;
 comparisons=$comparisons;provenance=(Get-Content (Join-Path $RunDirectory 'provenance.json') -Raw | ConvertFrom-Json);
 scope='Single-task 8EE4 opcode, wait, choice-write, reset and VM-read observations. Audio cache/channel effects are not validated.'} |
 ConvertTo-Json -Depth 7 | Set-Content (Join-Path $target 'sound-verification.json')
Copy-Item (Join-Path $RunDirectory 'debugger.cmd') (Join-Path $target 'sound-debugger.cmd')

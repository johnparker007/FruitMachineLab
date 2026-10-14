param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$target=Join-Path $root 'evidence/mpu4/skill-cash'
$original=Get-Content (Join-Path $target 'hashes.json') -Raw | ConvertFrom-Json
$comparisons=[ordered]@{}
foreach($name in @('state.csv','feature-state.csv','input-levels.csv','ram-final.bin')) {
 $expected=($original | Where-Object {[IO.Path]::GetFileName($_.Path) -eq $name}).Hash
 $actual=(Get-FileHash (Join-Path $RunDirectory $name)).Hash
 if($expected -ne $actual){throw "Award capture diverged in $name"}
 $comparisons[$name]=[ordered]@{equal=$true;sha256=$actual}
}
$calls=[Collections.Generic.List[object]]::new();$cores=[Collections.Generic.List[object]]::new()
$active=$null;$steps=$null
foreach($line in [IO.File]::ReadLines((Join-Path $RunDirectory 'debug.log'))) {
 if($line -notmatch '^(NI|NO|SC) '){continue}
 $tag=$Matches[1];$fields=[ordered]@{}
 foreach($match in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$fields[$match.Groups[1].Value]=[Convert]::ToInt32($match.Groups[2].Value,16)}
 if($tag -eq 'NI'){if($null -ne $active){throw 'Nested native refresh'};$active=$fields}
 if($tag -eq 'NO'){if($null -eq $active){throw 'Refresh exit without entry'};$calls.Add([ordered]@{before=$active;after=$fields});$active=$null}
 if($tag -eq 'SC') {
  if($fields.y -eq 0xAF9D -and $fields.pending -gt 0 -and $fields.pending -lt 0x8000){$steps=[Collections.Generic.List[object]]::new()}
  if($null -ne $steps){$steps.Add($fields)}
  if($null -ne $steps -and $fields.y -eq 0xAFC6){$cores.Add(@($steps));$steps=$null}
 }
}
if($null -ne $active -or $calls.Count -ne 13 -or $cores.Count -ne 10){throw "Unexpected refresh/core coverage: $($calls.Count)/$($cores.Count)"}
[ordered]@{classification='Trace-backed native refresh memory observations and bounded AF93 accounting slices; hardware effects and interleaved IRQ cases are excluded';calls=@($calls);cores=@($cores)} |
 ConvertTo-Json -Depth 12 | Set-Content (Join-Path $target 'award-calls.json')
[ordered]@{run_directory=$RunDirectory;raw_debug_sha256=(Get-FileHash (Join-Path $RunDirectory 'debug.log')).Hash;comparisons=$comparisons;
 provenance=(Get-Content (Join-Path $RunDirectory 'provenance.json') -Raw | ConvertFrom-Json)} | ConvertTo-Json -Depth 7 | Set-Content (Join-Path $target 'award-verification.json')
Copy-Item (Join-Path $RunDirectory 'debugger.cmd') (Join-Path $target 'award-debugger.cmd')

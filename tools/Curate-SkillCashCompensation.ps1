param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$expected=(Get-Content (Join-Path $root 'evidence/mpu4/skill-cash/focused-verification.json') -Raw | ConvertFrom-Json).raw_debug_sha256
$source=Join-Path $RunDirectory 'debug.log'
if((Get-FileHash -LiteralPath $source).Hash -ne $expected){throw 'Source trace differs from the verified focused run'}
$calls=[System.Collections.Generic.List[object]]::new()
$active=$null
$initial=[System.Collections.Generic.List[object]]::new()
$loop=[System.Collections.Generic.List[object]]::new()
$initialActive=$false;$loopActive=$false;$prefixFinished=$false
$selection=[System.Collections.Generic.List[object]]::new()
$selectionActive=$null;$awaitNext=$null
foreach($line in [System.IO.File]::ReadLines($source)) {
 if(!$line.StartsWith('SC ')){continue}
 $state=[ordered]@{}
 foreach($match in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$state[$match.Groups[1].Value]=[Convert]::ToInt32($match.Groups[2].Value,16)}
 if($null -ne $awaitNext){$awaitNext.next=$state.y;$selection.Add($awaitNext);$awaitNext=$null}
 if($state.y -eq 0xC6B3){$selectionActive=@{entry=$state}}
 if($null -ne $selectionActive){
  if($state.y -eq 0xC6BB){$selectionActive.latch=$state.latch}
  if($state.y -eq 0x9A44){$selectionActive.timer=$state.tick}
  if($state.y -eq 0x9A48){$selectionActive.abort=$state.abort}
  if($state.y -eq 0xC676){$selectionActive.gate=$state}
  if($state.y -eq 0xC6C5){$selectionActive.exit=$state;$awaitNext=$selectionActive;$selectionActive=$null}
 }
 if(!$prefixFinished) {
  if($state.y -eq 0xC721){$initialActive=$true}
  if($state.y -eq 0xC734){$initialActive=$false}
  if($initialActive){$initial.Add($state)}
  if($state.y -eq 0xC73C){$loopActive=$true}
  if($state.y -eq 0xC755){$loopActive=$false;$prefixFinished=$true}
  if($loopActive){$loop.Add($state)}
 }
 if($state.y -eq 0xC66A){if($null -ne $active){throw 'Nested chance call'};$active=[System.Collections.Generic.List[object]]::new()}
 if($null -ne $active){$active.Add($state)}
 if($state.y -eq 0xC672){$calls.Add(@{steps=@($active.ToArray())});$active=$null}
}
if($calls.Count -ne 3 -or $null -ne $active){throw 'Expected three complete compensation/chance calls'}
[ordered]@{classification='Captured VM state; values following memory fetches supply observed RAM/input data, not helper results';
 raw_debug_sha256=$expected;calls=@($calls.ToArray())} | ConvertTo-Json -Depth 7 |
 Set-Content (Join-Path $root 'evidence/mpu4/skill-cash/compensation-calls.json')
[ordered]@{initial=@($initial.ToArray());loop=@($loop.ToArray());raw_debug_sha256=$expected} | ConvertTo-Json -Depth 6 |
 Set-Content (Join-Path $root 'evidence/mpu4/skill-cash/control-prefix.json')
if($selection.Count -ne 1202 -or $null -ne $awaitNext -or $null -ne $selectionActive){throw 'Incomplete selection decisions'}
function Compact($state,$names) { $result=[ordered]@{};foreach($name in $names){$result[$name]=$state[$name]};return $result }
$compact=@($selection | ForEach-Object { [ordered]@{
 entry=(Compact $_.entry @('y','token','top','second','u','s','f4','f6','frame','seed'));
 latch=$_.latch;timer=$_.timer;abort=$_.abort;gate=(Compact $_.gate @('top','s'));
 exit=(Compact $_.exit @('top','second','u','s','f4','f6'));next=$_.next
}})
[ordered]@{iterations=$compact;classification='Platform choice byte, panel latch, IRQ timer and abort values are observed inputs; computed boolean gates and successor cursors are expected outputs';raw_debug_sha256=$expected} |
 ConvertTo-Json -Depth 7 | Set-Content (Join-Path $root 'evidence/mpu4/skill-cash/selection-decisions.json')

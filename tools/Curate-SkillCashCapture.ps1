param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$target=Join-Path $root 'evidence/mpu4/skill-cash'
function Snapshot($line) {
 $fields=@{}
 foreach($match in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$fields[$match.Groups[1].Value]=[Convert]::ToInt32($match.Groups[2].Value,16)}
 return @{site=$fields.y;token=$fields.token;top=$fields.top;second=$fields.second;third=$fields.third;fourth=$fields.fourth;
  seed=$fields.seed;irq=$fields.irq;frame=$fields.frame;option=$fields.opt;u=$fields.u}
}
$pending=@{}
$calls=[System.Collections.Generic.List[object]]::new()
$starts=@{0x99D8='random';0x9A00='percentage';0xC646='option';0xC676='gate'}
$ends=@{0x99EA='random';0x9A0F='percentage';0xC666='option';0xC695='gate'}
foreach($line in [System.IO.File]::ReadLines((Join-Path $RunDirectory 'debug.log'))) {
 if(!$line.StartsWith('SC ')){continue}
 $state=Snapshot $line
 if($starts.ContainsKey($state.site)) {
  $kind=$starts[$state.site]
  if($pending.ContainsKey($kind)){throw "Nested or unfinished $kind capture"}
  $pending[$kind]=@{kind=$kind;entry=$state;chance=$null}
 }
 if($state.site -eq 0xC68C){$pending['gate'].chance=$state.top}
 if($ends.ContainsKey($state.site)) {
  $kind=$ends[$state.site]
  if(!$pending.ContainsKey($kind)){throw "Missing $kind entry"}
  $pending[$kind].exit=$state
  $calls.Add($pending[$kind]);$pending.Remove($kind)
 }
}
if($pending.Count -ne 0 -or $calls.Count -eq 0){throw 'Incomplete helper capture'}
$reference=Join-Path $root 'evidence/mpu4/skill-cash/hashes.json'
$original=Get-Content $reference -Raw | ConvertFrom-Json
$comparisons=@{}
foreach($name in @('state.csv','feature-state.csv','input-levels.csv','ram-final.bin')) {
 $expected=($original | Where-Object {[System.IO.Path]::GetFileName($_.Path) -eq $name}).Hash
 $actual=(Get-FileHash (Join-Path $RunDirectory $name)).Hash
 $comparisons[$name]=@{equal=($expected -eq $actual);sha256=$actual}
 if($expected -ne $actual){throw "Focused run diverged in $name"}
}
$calls | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $target 'helper-calls.json')
@{run_directory=$RunDirectory;raw_debug_sha256=(Get-FileHash (Join-Path $RunDirectory 'debug.log')).Hash;
 comparisons=$comparisons;counts=($calls | Group-Object kind | ForEach-Object {@{kind=$_.Name;count=$_.Count}});
 provenance=(Get-Content (Join-Path $RunDirectory 'provenance.json') -Raw | ConvertFrom-Json);
 scope='Helper entry/exit snapshots; gate chance boundary remains observed input. Full raw trace and RAM remain outside repository.'} |
 ConvertTo-Json -Depth 8 | Set-Content (Join-Path $target 'focused-verification.json')
Copy-Item (Join-Path $RunDirectory 'debugger.cmd') (Join-Path $target 'focused-debugger.cmd')

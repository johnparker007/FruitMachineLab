param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash'
$original=Get-Content (Join-Path $target 'hashes.json') -Raw | ConvertFrom-Json;$comparisons=[ordered]@{}
foreach($name in @('state.csv','feature-state.csv','input-levels.csv','ram-final.bin')) {
 $expected=($original | Where-Object {[IO.Path]::GetFileName($_.Path) -eq $name}).Hash;$actual=(Get-FileHash (Join-Path $RunDirectory $name)).Hash
 if($actual -ne $expected){throw "Shared capture differs in $name"};$comparisons[$name]=[ordered]@{equal=$true;sha256=$actual}
}
$cycles=[Collections.Generic.List[object]]::new();$events=[Collections.Generic.List[object]]::new();$firstScan=$null;$firstCycle=$null;$previousCycle=0UL;$previousVm=0UL
$vmBytes=[IO.MemoryStream]::new();$vmFields=@('y','token','top','second','third','fourth','u','s','f4','f6','frame','tick','irq','seed','choice','rate','latch','pending','win','guard','checksum','mode','display','suppress')
foreach($line in [IO.File]::ReadLines((Join-Path $RunDirectory 'debug.log'))) {
 if($line -notmatch '^(SC|ML|MW|MF|MS|MX|MA|MC|MD) '){continue};$kind=$Matches[1];$fields=[ordered]@{}
 foreach($match in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$fields[$match.Groups[1].Value]=$match.Groups[2].Value}
 $cycle=[Convert]::ToUInt64($fields.cycle,16)
 if($null -eq $firstCycle){$firstCycle=$cycle;$previousCycle=$cycle;$previousVm=$cycle}
 if($kind -eq 'SC') {
  $cycles.Add(($cycle-$previousVm));$previousVm=$cycle
  foreach($key in $vmFields){$value=[Convert]::ToUInt16($fields[$key],16);$vmBytes.WriteByte([byte]($value -shr 8));$vmBytes.WriteByte([byte]($value -band 255))}
  continue
 }
 $id=switch($kind){'ML'{0}'MW'{1}'MF'{2}'MS'{3}'MX'{4}'MA'{5}'MC'{6}'MD'{7}}
 $keys=switch($kind){'ML'{@('id','pattern')}'MW'{@('address','value')}'MF'{@()}'MS'{@('phase','count','reload','alternate','alternate_reload','column','ports')}'MX'{@('phase','count','alternate','column','ports')}'MA'{@('timer','callback')}'MC'{@('column','ports')}'MD'{@('column','ports')}}
 $row=@(($cycle-$previousCycle),$id);foreach($key in $keys){$row+=[Convert]::ToUInt64($fields[$key],16)}
 $events.Add([ulong[]]$row);$previousCycle=$cycle
 if($kind -eq 'MS' -and $null -eq $firstScan){$firstScan=$fields}
}
if($cycles.Count -ne 98704 -or $null -eq $firstScan){throw 'Incomplete shared feature interval'}
$initialOutstanding=($events | Where-Object {$_[1] -in @(5,6)} | Select-Object -First 1)[1] -eq 6
$vmDigest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($vmBytes.ToArray()));$vmBytes.Dispose()
[ordered]@{classification='One captured CPU-cycle timeline for VM dispatches, predicted lamp writes, native scans and timer callback effects. CPU/PTM deadline generation is not emulated';
 initial_cycle=$firstCycle;expected_vm_sha256=$vmDigest;vm_fields=$vmFields;vm_cycle_deltas=@($cycles.ToArray());initial_scan=$firstScan;initial_timer_outstanding=$initialOutstanding;events=@($events.ToArray())} |
 ConvertTo-Json -Depth 7 -Compress | Set-Content (Join-Path $target 'shared-timing.json')
[ordered]@{run_directory=$RunDirectory;raw_debug_sha256=(Get-FileHash (Join-Path $RunDirectory 'debug.log')).Hash;comparisons=$comparisons;provenance=(Get-Content (Join-Path $RunDirectory 'provenance.json') -Raw | ConvertFrom-Json)} |
 ConvertTo-Json -Depth 7 | Set-Content (Join-Path $target 'shared-timing-verification.json')
Copy-Item (Join-Path $RunDirectory 'debugger.cmd') (Join-Path $target 'shared-timing-debugger.cmd')

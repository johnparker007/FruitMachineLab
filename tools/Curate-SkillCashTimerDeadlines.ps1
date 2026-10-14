param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$target=Join-Path $root 'evidence/mpu4/skill-cash'
$original=Get-Content (Join-Path $target 'hashes.json') -Raw | ConvertFrom-Json
$comparisons=[ordered]@{}
foreach($name in @('state.csv','feature-state.csv','input-levels.csv','ram-final.bin')) {
 $expected=($original | Where-Object {[IO.Path]::GetFileName($_.Path) -eq $name}).Hash
 $actual=(Get-FileHash (Join-Path $RunDirectory $name)).Hash
 if($actual -ne $expected){throw "Timer capture differs in $name"}
 $comparisons[$name]=$actual
}
$rows=[Collections.Generic.List[object]]::new()
$arm=$null;$irq=$null;$initialCallbacks=0
foreach($line in [IO.File]::ReadLines((Join-Path $RunDirectory 'debug.log'))) {
 if($line -notmatch '^(TL|TI|TC) '){continue};$kind=$Matches[1];$fields=@{}
 foreach($match in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$fields[$match.Groups[1].Value]=[Convert]::ToUInt64($match.Groups[2].Value,16)}
 switch($kind) {
  'TL' {if($null -ne $arm){throw 'Timer rearmed before callback'};$arm=$fields;$irq=$null}
  'TI' {if($null -ne $arm){$irq=$fields.cycle}}
  'TC' {
   if($null -eq $arm){$initialCallbacks++;continue}
   if($null -eq $irq){throw 'Callback without captured IRQ entry'}
   # MAME exposes PC after fetching STY operands: 710F, while the bus store belongs to 710B.
   if($arm.pc -ne 0x710F -or $arm.control -ne 0x63 -or $arm.value -ne ($arm.timer -band 255)){throw 'Unexpected timer arm'}
   $rows.Add([ulong[]]@($arm.cycle,$arm.timer,($irq-$arm.cycle),($fields.cycle-$irq),$fields.column))
   $arm=$null;$irq=$null
  }
 }
}
if($null -ne $arm -or $rows.Count -lt 6000){throw 'Incomplete timer capture'}
[ordered]@{classification='Trace-backed latch write, IRQ entry and callback entry. Offsets include CPU service latency; not hardware-expiry timestamps';initial_callbacks=$initialCallbacks;fields=@('latch_cycle','timer','irq_offset','callback_offset_from_irq','column');rows=@($rows.ToArray())} | ConvertTo-Json -Depth 5 -Compress | Set-Content (Join-Path $target 'timer-deadlines.json')
[ordered]@{raw_debug_sha256=(Get-FileHash (Join-Path $RunDirectory 'debug.log')).Hash;run_directory=$RunDirectory;comparisons=$comparisons} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $target 'timer-deadlines-verification.json')
Copy-Item (Join-Path $RunDirectory 'debugger.cmd') (Join-Path $target 'timer-deadlines-debugger.cmd')

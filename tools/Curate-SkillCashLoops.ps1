param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$reference=Get-Content (Join-Path $root 'evidence/mpu4/skill-cash/sound-verification.json') -Raw | ConvertFrom-Json
$source=Join-Path $RunDirectory 'debug.log'
if((Get-FileHash -LiteralPath $source).Hash -ne $reference.raw_debug_sha256){throw 'Use the verified native sound capture'}
$names=@('y','token','top','second','u','s','f4','f6','frame','tick','irq','seed','choice','rate','latch','clock')
$calls=[System.Collections.Generic.List[object]]::new();$steps=$null
foreach($line in [System.IO.File]::ReadLines($source)) {
 if(!$line.StartsWith('SC ')){continue}
 $state=[ordered]@{}
 foreach($match in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$state[$match.Groups[1].Value]=[Convert]::ToInt32($match.Groups[2].Value,16)}
 if($state.y -eq 0xC699){if($null -ne $steps){throw 'Nested selection loop'};$steps=[System.Collections.Generic.List[object]]::new()}
 if($null -ne $steps){$steps.Add($state)}
 if($state.y -ne 0xC6CC -or $null -eq $steps){continue}
 $inputs=[System.Collections.Generic.List[object]]::new();$anchors=[System.Collections.Generic.List[object]]::new()
 $beforeReads=[System.Collections.Generic.List[object]]::new()
 $bytes=[System.IO.MemoryStream]::new()
 try {
  for($index=0;$index -lt $steps.Count;$index++) {
   $current=$steps[$index];$signature=@($names | ForEach-Object {$current[$_]})
   foreach($value in $signature){$bytes.WriteByte([byte]($value -shr 8));$bytes.WriteByte([byte]($value -band 255))}
   if($index%256 -eq 0 -or $index -eq $steps.Count-1){$anchors.Add([int[]](@($index)+$signature))}
   if($index -eq 0){continue}
   $previous=$steps[$index-1];$irqDelta=($current.irq-$previous.irq) -band 255
   $timerDelta=$irqDelta
   # An IRQ before native STD ,X is overwritten by the VM's timer store; its
   # 0033 increment remains visible. Capture that phase instead of injecting 002D.
   if($previous.token -eq 0x7874 -and $previous.top -eq 0x002D){
    $timerDelta=($current.tick-$previous.second) -band 0xFFFF
    if($timerDelta -gt $irqDelta){throw 'Unresolved timer-store/IRQ phase'}
   }
   if($previous.token -eq 0x790D -and $previous.top -eq 0x002D){
    $beforeRead=($current.top-$previous.tick) -band 0xFFFF
    if($beforeRead -gt $irqDelta){throw 'Unresolved timer-read/IRQ phase'}
    if($beforeRead -ne 0){$beforeReads.Add([int[]]@(($index-1),$beforeRead))}
    $irqDelta-=$beforeRead;$timerDelta-=$beforeRead
   }
   $baseLatch=$previous.latch
   # The VM itself clears this mask; do not replay its calculated result as input.
   if($previous.y -eq 0x847C){$baseLatch=$baseLatch -band (0xFFFF -bxor 0x008F)}
   $setBits=$current.latch -band (0xFFFF -bxor $baseLatch)
   $clearBits=$baseLatch -band (0xFFFF -bxor $current.latch)
   if($irqDelta -ne 0 -or $setBits -ne 0 -or $clearBits -ne 0 -or $current.clock -ne $previous.clock){
    $inputs.Add([int[]]@($index,$irqDelta,$timerDelta,$setBits,$clearBits,$current.clock))
   }
  }
  $digest=[Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes.ToArray()))
 } finally {$bytes.Dispose()}
 $calls.Add([ordered]@{initial=$steps[0];instructions=$steps.Count;expected_sha256=$digest;inputs=@($inputs.ToArray());before_reads=@($beforeReads.ToArray());anchors=@($anchors.ToArray())})
 $steps=$null
}
if($calls.Count -ne 3 -or $null -ne $steps){throw 'Expected three complete C699 calls'}
[ordered]@{classification='Per-dispatch IRQ/latch/scheduler timing inputs plus a canonical expected-state digest. Choice, VM mask results and helper returns are not injected.';
 input_fields=@('ordinal','irq_delta','timer_delta_after_vm_store','latch_set','latch_clear','clock');
 signature_fields=$names;raw_debug_sha256=$reference.raw_debug_sha256;calls=@($calls.ToArray())} |
 ConvertTo-Json -Depth 8 -Compress | Set-Content (Join-Path $root 'evidence/mpu4/skill-cash/selection-loops.json')

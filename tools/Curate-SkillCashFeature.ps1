param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$target=Join-Path $root 'evidence/mpu4/skill-cash'
$original=Get-Content (Join-Path $target 'hashes.json') -Raw | ConvertFrom-Json
$comparisons=[ordered]@{}
foreach($name in @('state.csv','feature-state.csv','input-levels.csv','ram-final.bin')) {
 $expected=($original | Where-Object {[IO.Path]::GetFileName($_.Path) -eq $name}).Hash
 $actual=(Get-FileHash (Join-Path $RunDirectory $name)).Hash
 if($expected -ne $actual){throw "Full feature capture diverged in $name"}
 $comparisons[$name]=[ordered]@{equal=$true;sha256=$actual}
}
$steps=[Collections.Generic.List[object]]::new();$sound=[Collections.Generic.List[object]]::new()
$native=[Collections.Generic.List[object]]::new();$ports=[Collections.Generic.List[object]]::new();$entry=$null
foreach($line in [IO.File]::ReadLines((Join-Path $RunDirectory 'debug.log'))) {
 if($line -notmatch '^(SC|SQ|QE|SN|SW|WC|SR|NI|NO|PI) '){continue};$kind=$Matches[1]
 $fields=[ordered]@{}
 foreach($match in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$fields[$match.Groups[1].Value]=[Convert]::ToInt32($match.Groups[2].Value,16)}
 if($kind -eq 'SC'){$steps.Add($fields)}
 elseif($kind -eq 'PI'){$ports.Add($fields)}
 elseif($kind -eq 'NI'){$entry=$fields}
 elseif($kind -eq 'NO') {if($null -eq $entry){throw 'Missing native entry'};$native.Add([ordered]@{before=$entry;after=$fields});$entry=$null}
 else {$sound.Add([ordered]@{kind=$kind;fields=$fields})}
}
if($steps[0].y -ne 0xC721 -or $steps[$steps.Count-1].y -ne 0xC767 -or $native.Count -ne 13){throw 'Incomplete feature capture'}
$names=@('y','token','top','second','third','fourth','u','s','f4','f6','frame','tick','irq','seed','choice','rate','latch','pending','win','guard','checksum','mode','display','suppress','clock')
$inputs=[Collections.Generic.List[object]]::new();$beforeReads=[Collections.Generic.List[object]]::new();$anchors=[Collections.Generic.List[object]]::new()
$conditions=[Collections.Generic.List[object]]::new();$bytes=[IO.MemoryStream]::new()
try {
 for($index=0;$index -lt $steps.Count;$index++) {
  $current=$steps[$index];$signature=@($names | ForEach-Object {$current[$_]})
  foreach($value in $signature){$bytes.WriteByte([byte]($value -shr 8));$bytes.WriteByte([byte]($value -band 255))}
  if($index%256 -eq 0 -or $index -eq $steps.Count-1){$anchors.Add([int[]](@($index)+$signature))}
  if($index -eq 0){continue};$previous=$steps[$index-1]
  $irqDelta=($current.irq-$previous.irq) -band 255
  $timerDelta=($current.tick-$previous.tick) -band 0xFFFF
  if($previous.token -eq 0x7874 -and $previous.top -eq 0x2D) {
   $timerDelta=($current.tick-$previous.second) -band 0xFFFF
  } else {
   if(($timerDelta -band 255) -ne $irqDelta){throw "Unresolved timer/IRQ phase at $index"}
   $irqDelta=$timerDelta
  }
  if($previous.token -eq 0x790D -and $previous.top -eq 0x2D) {
   $pulse=($current.top-$previous.tick) -band 0xFFFF
   if($pulse -gt $irqDelta){throw 'Invalid read phase'}
   if($pulse -ne 0){$beforeReads.Add([int[]]@(($index-1),$pulse))}
   $irqDelta-=$pulse;$timerDelta-=$pulse
  }
  $baseLatch=$previous.latch
  if($previous.y -eq 0x847C){$baseLatch=$baseLatch -band (0xFFFF -bxor 0x008F)}
  $setBits=$current.latch -band (0xFFFF -bxor $baseLatch)
  $clearBits=$baseLatch -band (0xFFFF -bxor $current.latch)
  if($irqDelta -ne 0 -or $setBits -ne 0 -or $clearBits -ne 0 -or $current.clock -ne $previous.clock) {
   $inputs.Add([int[]]@($index,$irqDelta,$timerDelta,$setBits,$clearBits,$current.clock))
  }
 }
 $digest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes.ToArray()))
} finally {$bytes.Dispose()}
$inputSites=@{}
foreach($file in Get-ChildItem (Join-Path $root 'evidence/mpu4/VM-SCRIPTS') -Filter '*.txt') {
 foreach($line in [IO.File]::ReadLines($file.FullName)) {
  if($line -match '^\s*\*?\s*([0-9A-F]{4})\s+\w+\s+vm_test_input_condition\s+value=0x([0-9A-F]{4})') {
   $inputSites[[Convert]::ToInt32($Matches[1],16)]=[Convert]::ToInt32($Matches[2],16)
  }
 }
}
$portIndex=0
for($index=0;$index -lt $steps.Count-1;$index++) {
 if($inputSites.ContainsKey([int]$steps[$index].y)) {
  if($portIndex -ge $ports.Count){throw 'Missing native input ports'}
  $port=$ports[$portIndex++];$selector=$inputSites[[int]$steps[$index].y]
  if($port.selector -ne $selector){throw 'Input selector mismatch'}
  $conditions.Add([int[]]@($index,$selector,$steps[$index+1].top,$port.p0,$port.p1,$port.p2,$port.p3,$port.p6,$port.p7))
 }
}
if($portIndex -ne $ports.Count){throw 'Extra native input observations'}
[ordered]@{classification='Complete C721 VM dispatch digest with captured IRQ/latch/scheduler timing and physical input-port observations. Input conditions, choices, accounting and helper results are calculated.';
 initial=$steps[0];allocated_frame=($steps | Where-Object {$_.y -eq 0xC726} | Select-Object -First 1).frame;
 instructions=$steps.Count;expected_sha256=$digest;signature_fields=$names;inputs=@($inputs.ToArray());before_reads=@($beforeReads.ToArray());conditions=@($conditions.ToArray());anchors=@($anchors.ToArray());native=@($native.ToArray())} |
 ConvertTo-Json -Depth 10 -Compress | Set-Content (Join-Path $target 'feature-replay.json')
$sound | ConvertTo-Json -Depth 6 -Compress | Set-Content (Join-Path $target 'feature-sound.json')
[ordered]@{run_directory=$RunDirectory;raw_debug_sha256=(Get-FileHash (Join-Path $RunDirectory 'debug.log')).Hash;comparisons=$comparisons;
 provenance=(Get-Content (Join-Path $RunDirectory 'provenance.json') -Raw | ConvertFrom-Json)} | ConvertTo-Json -Depth 7 | Set-Content (Join-Path $target 'feature-verification.json')
Copy-Item (Join-Path $RunDirectory 'debugger.cmd') (Join-Path $target 'feature-debugger.cmd')

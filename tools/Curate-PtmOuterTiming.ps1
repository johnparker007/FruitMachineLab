param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash'
$prior=Get-Content "$target/ptm-instruction-boundaries-verification.json" -Raw|ConvertFrom-Json
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0' -or (Get-FileHash "$RunDirectory/ptm-instructions.csv").Hash -ne $prior.instructions_sha256 -or (Get-FileHash "$RunDirectory/ptm-skill-cpu.csv").Hash -ne $prior.phase_sha256){throw 'Use accepted instruction/state streams'}
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath);$ops=@(Import-Csv "$RunDirectory/ptm-instructions.csv"|Where-Object {$_.event -eq 'opcode'})
$services=Get-Content "$target/ptm-service-timing.json" -Raw|ConvertFrom-Json
function Cycle($r){[ulong][decimal]::Round(([decimal]$r.seconds*1000000000000000000d+[decimal]$r.attoseconds)*1720000d/1000000000000000000d)-1}
$stack=[Collections.Generic.Stack[object]]::new();$roots=[Collections.Generic.List[object]]::new()
for($i=0;$i -lt $ops.Count;$i++){
 if($ops[$i].address -eq 'FE70'){$stack.Push(@{index=$i;own=[Collections.Generic.List[int]]::new();children=[Collections.Generic.List[object]]::new()})}
 if($stack.Count -eq 1){$stack.Peek().own.Add($i)}
 if($ops[$i].address -eq 'FF13'){
  $f=$stack.Pop();$f.end=$i
  if($stack.Count -eq 0){$roots.Add($f)}else{$stack.Peek().children.Add($f)}
 }
}
if($roots.Count -ne 19 -or $stack.Count -ne 1){throw 'Completed/open outer service counts differ'}
$catalog=[Collections.Generic.List[object]]::new();$keys=@{};$parents=[Collections.Generic.List[object]]::new();$nativeCount=0;$childCount=0
foreach($r in $roots){
 if($r.children.Count -ne 1){throw 'Expected one selected child per parent'}
 $start=Cycle $ops[$r.index];$steps=[Collections.Generic.List[object]]::new()
 foreach($i in $r.own){
  $row=$ops[$i];$pc=[Convert]::ToInt32($row.address,16);$bytes=[Convert]::FromHexString($row.bytes)
  if($pc -lt 0x1400 -or $bytes.Length -ne 5){throw 'Expected selected ROM context'}
  for($k=0;$k -lt 5;$k++){if($bytes[$k] -ne $rom[$pc+$k]){throw 'ROM bytes differ'}}
  $key="$($row.address):$($row.bytes)"
  if(!$keys.ContainsKey($key)){$keys[$key]=$catalog.Count;$catalog.Add([ordered]@{pc=$pc;context_hex=$row.bytes})}
  $child=@($r.children|Where-Object {$_.index -eq $i+1})
  if($child.Count){
   $childEntry=Cycle $ops[$child[0].index];$frames=@($services.irqs|Where-Object {$_.entry_cycle -eq $childEntry});$tailIndex=-1
   for($n=0;$n -lt $services.timer3_tails.Count;$n++){if($services.timer3_tails[$n].entry_cycle -eq $childEntry){$tailIndex=$n}}
   if($frames.Count -ne 1 -or $tailIndex -lt 0){throw 'Missing verified child timing'}
   $end=[ulong]$frames[0].accepted_cycle;$next=[int]$frames[0].saved_resume_pc
  }else{$end=Cycle $ops[$i+1];$next=[Convert]::ToInt32($ops[$i+1].address,16)}
  $steps.Add([long[]]@(0,((Cycle $row)-$start),$keys[$key],[Convert]::ToInt32($row.cc,16),($end-$start),$next));$nativeCount++
  if($child.Count){$steps.Add([long[]]@(1,($end-$start),$tailIndex,([ulong]$frames[0].resumed_cycle-$start)));$childCount++}
 }
 $frame=@($services.irqs|Where-Object {$_.entry_cycle -eq $start})
 if($frame.Count -ne 1 -or $frame[0].depth -ne 0){throw 'Missing parent frame'}
 $parents.Add([ordered]@{entry_cycle=$start;accepted_cycle=[ulong]$frame[0].accepted_cycle;resumed_cycle=[ulong]$frame[0].resumed_cycle;saved_resume_pc=[int]$frame[0].saved_resume_pc;steps=@($steps.ToArray())})
}
[ordered]@{classification='Natural selected outer timer1 instruction paths, with nested timer3 work referenced once. Observed paths and flags, not a generated whole-machine schedule or lossless disassembly.';catalog_qualification='Each context_hex is five observed ROM bytes checked against original ROM; native decoder supplies actual length.';native_step_fields=@('kind=0','cycle_relative_to_parent_entry','catalog_index','captured_cc','completion_cycle_relative','next_pc_before_any_child');child_step_fields=@('kind=1','accepted_cycle_relative','index_in_ptm_service_timing_timer3_tails','resumed_cycle_relative');catalog=@($catalog.ToArray());parents=@($parents.ToArray())}|ConvertTo-Json -Depth 9 -Compress|Set-Content "$target/ptm-outer-timing.json"
[ordered]@{source_run=$RunDirectory;instructions_sha256=$prior.instructions_sha256;phase_sha256=$prior.phase_sha256;service_fixture_sha256=(Get-FileHash "$target/ptm-service-timing.json").Hash;rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;parents=$parents.Count;native_instructions=$nativeCount;referenced_children=$childCount;catalog_contexts=$catalog.Count;excluded_open_parent=$stack.Count;source_tag='mame0281';source_commit='2843a3deb81cf93735244044894196ccfbea4d20'}|ConvertTo-Json|Set-Content "$target/ptm-outer-timing-verification.json"
Write-Output "Curated $nativeCount own instructions/$childCount child references in19 outer services; $($catalog.Count) ROM contexts"

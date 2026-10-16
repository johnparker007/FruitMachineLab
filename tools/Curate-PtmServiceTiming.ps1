param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash'
$prior=Get-Content "$target/ptm-instruction-boundaries-verification.json" -Raw|ConvertFrom-Json
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0' -or (Get-FileHash "$RunDirectory/ptm-instructions.csv").Hash -ne $prior.instructions_sha256 -or (Get-FileHash "$RunDirectory/ptm-skill-cpu.csv").Hash -ne $prior.phase_sha256){throw 'Use the accepted instruction capture'}
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath);$ops=@(Import-Csv "$RunDirectory/ptm-instructions.csv"|Where-Object {$_.event -eq 'opcode'})
$phase=@(Import-Csv "$RunDirectory/ptm-skill-cpu.csv"|Where-Object {$_.event -eq 'handler'})
function Cycle($r){[ulong][decimal]::Round(([decimal]$r.seconds*1000000000000000000d+[decimal]$r.attoseconds)*1720000d/1000000000000000000d)-1}
function Instruction([int]$i){
 $r=$ops[$i];$pc=[Convert]::ToInt32($r.address,16);$b=[Convert]::FromHexString($r.bytes)
 if($b.Length -ne 5 -or $pc -lt 0x1400){throw 'Expected selected ROM instruction context'}
 for($k=0;$k -lt 5;$k++){if($b[$k] -ne $rom[$pc+$k]){throw 'ROM context differs'}}
 $next=[Convert]::ToInt32($ops[$i+1].address,16);$cc=[Convert]::ToInt32($r.cc,16);$taken=$null
 if($b[0] -eq 0x10 -and $b[1] -eq 0x26){$taken=($cc -band 4) -eq 0;$disp=($b[2] -shl 8) -bor $b[3];if($disp -ge 32768){$disp-=65536};$expected=($pc+4+$(if($taken){$disp}else{0})) -band 65535;if($next -ne $expected){throw 'Long BNE outcome differs from captured CC'}}
 [ordered]@{pc=$pc;cycle=(Cycle $r);cc=$cc;context_hex=$r.bytes;next_pc=$next;next_cycle=(Cycle $ops[$i+1]);branch_taken=$taken}
}
$stack=[Collections.Generic.Stack[object]]::new();$irqs=[Collections.Generic.List[object]]::new();$tails=[Collections.Generic.List[object]]::new();$scans=[Collections.Generic.List[object]]::new();$incompleteScans=0
for($i=0;$i -lt $ops.Count;$i++){
 $r=$ops[$i]
 if($r.address -eq 'FE70'){$stack.Push(@{index=$i;depth=$stack.Count;status=[int]$r.status;cycle=(Cycle $r)})}
 if($r.address -eq 'FF13'){
  if($stack.Count -eq 0 -or $i+1 -ge $ops.Count){throw 'Unmatched/truncated IRQ return'}
  $entry=$stack.Pop();$h=$ops[$entry.index];$matching=@($phase|Where-Object {(Cycle $_) -eq $entry.cycle})
  if($matching.Count -ne 1){throw 'Missing entry frame observation'}
  $resume=[Convert]::ToInt32($matching[0].resume,16);$next=[Convert]::ToInt32($ops[$i+1].address,16)
  if($next -ne $resume -or (Cycle $ops[$i+1])-(Cycle $r) -ne 15){throw 'Full IRQ RTI/resume differs'}
  $irqs.Add([ordered]@{status=$entry.status;depth=$entry.depth;entry_cycle=$entry.cycle;accepted_cycle=($entry.cycle-19);rti=(Instruction $i);stacked_cc_e=1;stacked_cc_e_basis='Ordinary IRQ saves E=1; selected ROM path leaves the saved CC intact; full15-cycle return is trace-checked';saved_resume_pc=$resume;resumed_pc=$next;resumed_cycle=(Cycle $ops[$i+1])})
  if(($entry.status -band 4) -ne 0){
   $cb=$entry.index;while($cb -lt $i -and $ops[$cb].address -ne '48FD'){$cb++};if($cb -eq $i){throw 'Missing callback'}
   $path=@(for($k=$cb;$k -le $i;$k++){Instruction $k})
   $tails.Add([ordered]@{entry_cycle=$entry.cycle;callback_cycle=(Cycle $ops[$cb]);instructions=$path;resumed_cycle=(Cycle $ops[$i+1])})
  }
 }
 if($r.address -eq '28FE'){
  $j=$i+1;while($j -lt $ops.Count -and $ops[$j].address -ne '29BA'){$j++}
  if($j -eq $ops.Count){$incompleteScans++;continue}
  $path=@(for($k=$i;$k -le $j;$k++){Instruction $k})
  $scans.Add([ordered]@{entry_cycle=(Cycle $r);rts_cycle=(Cycle $ops[$j]);returned_cycle=(Cycle $ops[$j+1]);instructions=$path})
 }
}
if($irqs.Count -ne 38 -or $tails.Count -ne 19 -or $scans.Count -ne 19 -or $stack.Count -ne 1 -or $incompleteScans -ne 1){throw 'Selected complete/incomplete service counts differ'}
[ordered]@{classification='Selected natural Skill Cash callback tails, timer1 scans and nested IRQ returns from the existing accepted passive capture. Last timer1 IRQ/scan is incomplete and excluded. Not full outer-handler timing recovery.';instruction_context='Five observed ROM bytes, not an asserted instruction length; each context byte checked against original ROM.';irqs=@($irqs.ToArray());timer3_tails=@($tails.ToArray());timer1_scans=@($scans.ToArray())}|ConvertTo-Json -Depth 9|Set-Content "$target/ptm-service-timing.json"
[ordered]@{source_run=$RunDirectory;instructions_sha256=$prior.instructions_sha256;phase_sha256=$prior.phase_sha256;rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;complete_irq_returns=$irqs.Count;complete_timer3_tails=$tails.Count;complete_timer1_scans=$scans.Count;excluded_open_irqs=$stack.Count;excluded_open_scans=$incompleteScans;source_tag='mame0281';source_commit='2843a3deb81cf93735244044894196ccfbea4d20'}|ConvertTo-Json|Set-Content "$target/ptm-service-timing-verification.json"
Write-Output 'Curated38 IRQ returns,19 timer3 tails and19 timer1 scans'

param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath,[string]$ExcludedRunDirectory)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash'
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0'){throw 'Incomplete instruction capture'}
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath)
$phase=@(Import-Csv "$RunDirectory/ptm-skill-cpu.csv"|Where-Object {$_.event -ne 'installed'})
$original=@((Get-Content "$target/ptm-skill-cpu.json" -Raw|ConvertFrom-Json).rows)
if($phase.Count -ne $original.Count){throw 'Instrumented phase window differs'}
for($i=0;$i -lt $phase.Count;$i++){foreach($p in $original[$i].PSObject.Properties){if($phase[$i].($p.Name) -ne $p.Value){throw "Original state/timestamp prefix changed at$i/$($p.Name)"}}}
$arms=@($phase|Where-Object {$_.event -eq 'write' -and $_.address -eq '0907'})
$raw=@(Import-Csv "$RunDirectory/ptm-instructions.csv");$ops=@($raw|Where-Object {$_.event -eq 'opcode'})
function Cycle($row){[ulong][decimal]::Round(([decimal]$row.seconds*1000000000000000000d+[decimal]$row.attoseconds)*1720000d/1000000000000000000d)}
function Instruction($row){
 $pc=[Convert]::ToInt32($row.address,16);$bytes=[Convert]::FromHexString($row.bytes)
 if($bytes.Length -ne 5){throw 'Missing five-byte instruction context'}
 $kind='ram';if($pc -ge 0x1400){$kind='rom';for($k=0;$k -lt 5;$k++){if($bytes[$k] -ne $rom[($pc+$k) -band 65535]){throw 'Native instruction context differs from ROM'}}}
 [ordered]@{pc=$pc;cycle=((Cycle $row)-1);cc=[Convert]::ToInt32($row.cc,16);context_hex=$row.bytes;memory_kind=$kind}
}
$windows=[Collections.Generic.List[object]]::new();$j=0
for($i=1;$i -lt $ops.Count;$i++){
 $h=$ops[$i];if($h.address -ne 'FE70' -or (([int]$h.status -band 4) -eq 0)){continue}
 if($j -ge 19){throw 'Extra timer3 handler'}
 $arm=$arms[$j];if($arm.output3 -ne '1' -or $arm.control3 -ne '99'){throw 'Phase assumption differs'}
 $armCycle=Cycle $arm;$assertion=$armCycle+320;$handlerCycle=(Cycle $h)-1
 $delivery=@($raw|Where-Object {$_.cpuirq -eq '1' -and (([int]$_.status -band 4) -ne 0) -and (Cycle $_) -ge $assertion -and (Cycle $_) -le $handlerCycle}|Select-Object -First 1)
 if($delivery.Count -ne 1){throw 'Missing delivered IRQ sample'}
 $path=[Collections.Generic.List[object]]::new();$end=$i
 while($end -lt $ops.Count -and $ops[$end].address -ne '48FD'){
  if($end -gt $i -and $ops[$end].address -eq 'FE70'){throw 'Unexpected nested IRQ in selected timer3 path'}
  $path.Add((Instruction $ops[$end]));$end++
 }
 if($end -eq $ops.Count){throw 'Missing lamp callback'}
 $windows.Add([ordered]@{arm_index=$j;latch_bus_cycle=$armCycle;latch_seconds=$arm.seconds;latch_attoseconds=$arm.attoseconds;latch=40;initial_high=$true;calculated_assertion_cycle=$assertion;last_instruction=(Instruction $ops[$i-1]);handler_cycle=$handlerCycle;first_cpu_level_sample=[ordered]@{event=$delivery[0].event;cycle=(Cycle $delivery[0]);pc=[Convert]::ToInt32($delivery[0].pc,16);curpc=[Convert]::ToInt32($delivery[0].curpc,16);cpuirq=1;status=[int]$delivery[0].status};handler_path=@($path.ToArray());callback_cycle=((Cycle $ops[$end])-1)})
 $j++
}
if($windows.Count -ne 19 -or $arms.Count -ne 20){throw 'Incomplete natural instruction windows'}
[ordered]@{classification='Natural original Skill Cash input campaign, passive guarded instruction observer; original354 timer-state rows match field-for-field. Selected windows, not a lossless listing or complete CPU emulator.';instruction_time='Opcode-fetch time minus one CPU cycle. context_hex holds five observed bytes, including possible following code/data; it is not an asserted instruction length. ROM contexts byte-checked; RAM contexts observed only.';delivery_qualification='first_cpu_level_sample is the first observed delivered CPU IRQ=1 with timer3 flag set after calculated assertion, not a direct timestamp of asynchronous delivery.';windows=@($windows.ToArray())}|ConvertTo-Json -Depth 8|Set-Content "$target/ptm-instruction-boundaries.json"
$excluded=$null;if($ExcludedRunDirectory){$excluded=[ordered]@{source_run=$ExcludedRunDirectory;reason='Unguarded instruction-byte inspection reentered other observer taps, duplicating phase events and ending the window early. Not accepted timing evidence.';lua_sha256=(Get-FileHash "$ExcludedRunDirectory/ptm-skill-cpu.lua").Hash;phase_sha256=(Get-FileHash "$ExcludedRunDirectory/ptm-skill-cpu.csv").Hash;instruction_sha256=(Get-FileHash "$ExcludedRunDirectory/ptm-instructions.csv").Hash}}
[ordered]@{source_run=$RunDirectory;phase_sha256=(Get-FileHash "$RunDirectory/ptm-skill-cpu.csv").Hash;instructions_sha256=(Get-FileHash "$RunDirectory/ptm-instructions.csv").Hash;lua_sha256=(Get-FileHash "$RunDirectory/ptm-skill-cpu.lua").Hash;input_lua_sha256=(Get-FileHash "$RunDirectory/input.lua").Hash;provenance=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);instruction_samples=$ops.Count;state_samples=$phase.Count;selected_timer3_windows=$windows.Count;excluded_observer_attempt=$excluded;source_tag='mame0281';source_commit='2843a3deb81cf93735244044894196ccfbea4d20'}|ConvertTo-Json -Depth 8|Set-Content "$target/ptm-instruction-boundaries-verification.json"
Write-Output "Curated19 timer3 instruction/handler windows from $($ops.Count) opcode samples"

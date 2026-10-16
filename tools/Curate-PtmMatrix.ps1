param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0' -or (Select-String "$RunDirectory/debug.log" -Pattern '^Error ' -Quiet)){throw 'Invalid capture'}
$rows=[Collections.Generic.List[object]]::new();$arm=$null;$read=$null;$ties=0
foreach($line in [IO.File]::ReadLines("$RunDirectory/debug.log")){
 if($line -notmatch '^(PL|PR|PS) '){continue};$kind=$Matches[1];$f=@{}
 foreach($m in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$f[$m.Groups[1].Value]=[Convert]::ToUInt64($m.Groups[2].Value,16)}
 if($kind -eq 'PL'){if($arm){throw 'Overlapping matrix arm'};$arm=$f;continue}
 if($kind -eq 'PR'){if(!$arm -or $read){throw 'Unexpected matrix status read'};$read=$f;continue}
 if(!$arm -or !$read -or $read.value -ne $f.status -or $arm.channel -ne $f.channel -or $arm.latch -ne $f.latch -or $arm.phase -ne $f.phase -or $arm.delay -ne $f.delay){throw 'Matrix row disagreement'}
 $expiry=if($arm.channel -eq 1){$arm.latch+1}else{8*($arm.latch+1-$arm.phase)}
 $elapsed=$read.cycle-$arm.cycle;$flag=128 -bor (1 -shl ($arm.channel-1));$tie=$elapsed -eq $expiry
 if($tie){$ties++;if($f.status -notin @(0,$flag)){throw 'Unexpected boundary status'}}
 elseif($f.status -ne $(if($elapsed -gt $expiry){$flag}else{0})){throw 'Hardware countdown disagreement'}
 $name='case-{0}-{1}-{2}-{3}.bin' -f $arm.channel,$arm.latch,$arm.delay,$arm.phase
 $rows.Add([ordered]@{channel=$arm.channel;latch=$arm.latch;initial_high=$arm.phase;arm_cycle=$arm.cycle;read_cycle=$read.cycle;end_cycle=$f.cycle;status=$f.status;boundary_tie=$tie;program_hex=[Convert]::ToHexString([IO.File]::ReadAllBytes((Join-Path $RunDirectory $name)))})
 $arm=$null;$read=$null
}
if($arm -or $read -or $rows.Count -ne 96){throw 'Incomplete96-case matrix'}
$keys=@($rows|ForEach-Object {'{0}:{1}:{2}' -f $_.channel,$_.initial_high,$_.latch}|Sort-Object -Unique)
if($keys.Count -ne 24){throw 'Missing matrix coverage'}
$target=Join-Path $root 'evidence/mpu4/skill-cash'
[ordered]@{classification='Synthetic native RAM programs and masked CPU interrupts; actual MC6840 bus stores/status reads. Timer1 continuous42 and timer3 single-shot63 after global reset, both timer3 initial phases. Not natural gameplay, IRQ acceptance or full PTM recovery';fields_qualification='arm/read cycles are debugger instruction-start coordinates, not effective bus times; matched five-cycle store/read instruction offsets cancel in elapsed comparisons; equal-cycle ordering remains unresolved';rows=@($rows.ToArray())}|ConvertTo-Json -Depth 5 -Compress|Set-Content "$target/ptm-matrix.json"
[ordered]@{source_run=$RunDirectory;raw_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash;debugger_sha256=(Get-FileHash "$RunDirectory/debugger.cmd").Hash;observations=$rows.Count;strict_comparisons=($rows.Count-$ties);equal_cycle_boundaries=$ties;provenance=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json)}|ConvertTo-Json -Depth 5|Set-Content "$target/ptm-matrix-verification.json"
Copy-Item "$RunDirectory/debugger.cmd" "$target/ptm-matrix-debugger.cmd"
$rom=[IO.File]::ReadAllBytes($RomPath)
[ordered]@{classification='ROM-byte checked timer setup and dispatch records, with synthetic MC6840 reference matrix; not a lossless timer/CPU reconstruction';rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;ranges=[ordered]@{'707E'=[Convert]::ToHexString([byte[]]$rom[0x707E..0x710F]);'FE70'=[Convert]::ToHexString([byte[]]$rom[0xFE70..0xFF13]);'FFF8'=[Convert]::ToHexString([byte[]]$rom[0xFFF8..0xFFF9])};mame_source='maps/mame-timing-source.json';irq_entry_evidence='skill-cash/ptm-irq-entry.json';skill_cash_cpu_evidence='skill-cash/ptm-skill-cpu.json';instruction_boundary_evidence='skill-cash/ptm-instruction-boundaries.json';service_timing_evidence='skill-cash/ptm-service-timing.json';outer_timing_evidence='skill-cash/ptm-outer-timing.json';normal_timer1_latch=3440;normal_timer1_period_cpu_cycles=3441;alternate_timer1_latch=2580;native_listing='native/timer-native.txt';native_irq_export='native/fe70.json';implementation=@('src/FruitMachineLab.Runtime/Mpu4Timer1Clock.cs','src/FruitMachineLab.Runtime/Mpu4Timer3Deadline.cs','src/FruitMachineLab.Runtime/Mpu4Timer3Pulse.cs','src/FruitMachineLab.Runtime/Mpu4Timer3PhaseClock.cs');lifecycle_evidence='skill-cash/ptm-lifecycle.json: 643 natural observations across20 arms; post-shot phase, frozen counter and control00/63 rearm; independent byte-identical repeat; not canonical Skill Cash';verification='skill-cash/ptm-matrix.json';natural_phase_evidence='skill-cash/ptm-natural-phase.json: cold-attract100 arms,1 low/99 high at the store; phase unchanged one CPU cycle later; not the canonical Skill Cash capture';unresolved=@('Remaining canonical arms beyond the first20 observed high phases; do not generalize phase globally','Same-cycle PTM expiry versus CPU status-read ordering','IRQ acceptance beyond the selected19 unmasked timer3 windows; timer1 contention, nested services and translated-helper instruction boundaries','Reset, gate changes, external edges, other controls and zero-latch lifecycle remain outside the selected phase clock','Live still uses captured IRQ service/occupancy and callback timestamps; new clock mechanics are not an invented replacement for CPU acceptance')}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $root 'evidence/mpu4/maps/ptm-clock-semantics.json')
Write-Output "Curated96 bus samples; $ties explicit equal-cycle boundaries"

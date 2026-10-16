param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath,[Parameter(Mandatory=$true)][string]$MameExecutable,[string]$ExcludedRunDirectory)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash'
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0' -or (Select-String "$RunDirectory/debug.log" -Pattern '^Error ' -Quiet)){throw 'Invalid delay capture'}
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath);$cases=@(Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json)
function Fields($line){$f=@{};foreach($m in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$f[$m.Groups[1].Value]=[Convert]::ToUInt64($m.Groups[2].Value,16)};return $f}
$rows=[Collections.Generic.List[object]]::new();$current=$null;$pass=$null
foreach($line in [IO.File]::ReadLines("$RunDirectory/debug.log")){
 if($line -notmatch '^(DS|DE|DX|DF) '){continue};$kind=$Matches[1];$f=Fields $line
 if($kind -eq 'DS'){
  if($null -ne $current -or $f.id -ne $rows.Count -or ($f.gate -band 0x80)){throw 'Invalid enabled gate/case order'}
  $current=[ordered]@{case=$cases[$f.id];start_cycle=$f.cycle;gate=$f.gate;passes=[Collections.Generic.List[object]]::new()};continue
 }
 if($null -eq $current -or $f.id -ne $current.case.id){throw 'No active case'}
 if($kind -eq 'DE'){if($null -ne $pass){throw 'Overlapping pass'};$pass=$f.cycle;continue}
 if($kind -eq 'DX'){if($null -eq $pass){throw 'Missing pass start'};$current.passes.Add([ulong[]]@($pass,$f.cycle));$pass=$null;continue}
 if($null -ne $pass){throw 'Open pass at return'};$current.end=$f;$rows.Add($current);$current=$null
}
if($rows.Count -ne 20 -or $null -ne $current -or $cases.Count -ne 20){throw 'Incomplete20-case matrix'}
$literalCases=@(Get-Content "$RunDirectory/literal-cases.json" -Raw|ConvertFrom-Json);$literalRows=[Collections.Generic.List[object]]::new();$literalStart=$null
foreach($line in [IO.File]::ReadLines("$RunDirectory/debug.log")){
 if($line -notmatch '^(LS|LF) '){continue};$kind=$Matches[1];$f=Fields $line
 if($kind -eq 'LS'){$literalStart=$f;continue}
 if($null -eq $literalStart -or $f.id -ne $literalRows.Count -or $f.id -ne $literalStart.id){throw 'Unordered literal cases'}
 $literalRows.Add([ordered]@{case=$literalCases[$f.id];start_cycle=$literalStart.cycle;end=$f});$literalStart=$null
}
if($literalRows.Count -ne 20 -or $null -ne $literalStart){throw 'Incomplete literal matrix'}
$literalTokens=@{};$literalReferences=0
foreach($file in Get-ChildItem "$root/evidence/mpu4/VM-SCRIPTS/*.txt"){
 foreach($line in [IO.File]::ReadLines($file.FullName)){
  if($line -notmatch '^\s*\*?\s*([0-9A-F]{4})\s+([0-9A-F]{4})\s+(vm_push_word_body_(byte|word))\s+.*value=0x([0-9A-F]{4})'){continue}
  $token=[Convert]::ToInt32($Matches[2],16);$operation=$Matches[3];$word=$Matches[4] -eq 'word';$value=[Convert]::ToInt32($Matches[5],16);$header=$rom[$token]*256+$rom[$token+1]
  $expected=if($word){0x794F}else{0x7946};$actual=if($word){$rom[$token+2]*256+$rom[$token+3]}else{$rom[$token+2]}
  if($header -ne $expected -or $value -ne $actual){throw "Literal header/value mismatch at$($token.ToString('X4'))"}
  $literalTokens[$token]=[ordered]@{token=$token;operation=$operation;value=$value;header_hex=[Convert]::ToHexString($rom[$token..($token+1)]);operand_hex=[Convert]::ToHexString($rom[($token+2)..($token+$(if($word){3}else{2}))])};$literalReferences++
 }
}
[ordered]@{classification='ROM-byte checked literal header/operand membership found in existing recovered VM listings; not a lossless dictionary export';rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;references=$literalReferences;tokens=@($literalTokens.Keys|Sort-Object|ForEach-Object {$literalTokens[$_]})}|ConvertTo-Json -Depth 5|Set-Content "$root/evidence/mpu4/maps/vm-literal-timing.json"
$prior=Get-Content "$target/nudge-tone-verification.json" -Raw|ConvertFrom-Json;$tone=Get-Content "$target/nudge-tone.json" -Raw|ConvertFrom-Json;$natural=$prior.run_directory
if((Get-FileHash "$natural/debug.log").Hash -ne $prior.raw_sha256){throw 'Natural tone source changed'}
$first=[Convert]::ToUInt64($tone.initial.cycle,16);$terminal=$null;$roots=[Collections.Generic.List[object]]::new();$stack=[Collections.Generic.Stack[object]]::new();$outer=$null
foreach($line in [IO.File]::ReadLines("$natural/debug.log")){
 if($line -notmatch '^(SC|IE|IX) '){continue};$kind=$Matches[1];$f=Fields $line
 if($f.cycle -lt $first){continue}
 if($kind -eq 'SC'){if($f.y -eq 0xFC4F){$terminal=$f.cycle;break};continue}
 if($kind -eq 'IE'){
  if($stack.Count -eq 0){$outer=[ordered]@{handler_cycle=$f.cycle;accepted_cycle=$f.cycle-19;children=0}}else{$outer.children++}
  $stack.Push($f)
 }else{
  if($stack.Count -eq 0 -or $stack.Pop().s -ne $f.s){throw 'Unbalanced native IRQ frame'}
  if($stack.Count -eq 0){$outer.rti_cycle=$f.cycle;$outer.resumed_cycle=$f.cycle+15;$roots.Add($outer);$outer=$null}
 }
}
if($null -eq $terminal -or $stack.Count){throw 'Natural tone boundaries incomplete'}
$bounds=@($first,[ulong]$tone.tone_phases[2].cycle,[ulong]$tone.tone_phases[3].cycle,[ulong]$terminal);$phases=@(for($i=0;$i -lt 3;$i++){
 $busy=0UL;$count=0
 foreach($r in $roots){if($r.resumed_cycle -le $bounds[$i] -or $r.accepted_cycle -ge $bounds[$i+1]){continue};if($r.accepted_cycle -lt $bounds[$i] -or $r.resumed_cycle -gt $bounds[$i+1]){throw 'Phase splits an IRQ envelope'};$busy+=$r.resumed_cycle-$r.accepted_cycle;$count++}
 [ordered]@{start=$bounds[$i];end=$bounds[$i+1];outer_irqs=$count;full_irq_cycles=$busy;cpu_cycles=$bounds[$i+1]-$bounds[$i]-$busy}
})
$regions=@(foreach($r in @(@('7159','repeat and single-pass helper',0x7159,0x7171),@('718A','enabled gate and statically preserved disabled exit',0x718A,0x7199),@('5A05','tone wait caller',0x5A05,0x5A09))){[ordered]@{address=$r[0];label=$r[1];bytes_hex=[Convert]::ToHexString($rom[$r[2]..$r[3]])}})
[ordered]@{classification='20 synthetic native7159 calls with IRQ/FIRQ masked; natural fixed tone phase reconciliation uses recorded handler boundaries plus source-derived19-cycle entry and15-cycle full RTI. No generated IRQ assertion schedule claim.';regions=$regions;rows=@($rows.ToArray());natural=[ordered]@{classification='Existing physical-input tone campaign; old saved-PC log field is not used';initial=$first;terminal=$terminal;phases=$phases;outer_irqs=@($roots.ToArray())};provenance=[ordered]@{synthetic_run=$RunDirectory;synthetic_log_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash;synthetic_commands_sha256=(Get-FileHash "$RunDirectory/debugger.cmd").Hash;cases_sha256=(Get-FileHash "$RunDirectory/cases.json").Hash;natural_run=$natural;natural_log_sha256=$prior.raw_sha256;rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;mame_sha256=(Get-FileHash $MameExecutable).Hash}}|ConvertTo-Json -Depth 9 -Compress|Set-Content "$target/calibrated-delay-timing.json"
Write-Output "20 native cases; natural CPU phase budgets: $($phases.cpu_cycles -join ','); $($roots.Count) outer IRQs"
if($ExcludedRunDirectory){
 $path="$target/calibrated-delay-timing.json";$data=Get-Content $path -Raw|ConvertFrom-Json
 $data.provenance|Add-Member -NotePropertyName excluded_attempt -NotePropertyValue ([ordered]@{source_run=$ExcludedRunDirectory;log_sha256=(Get-FileHash "$ExcludedRunDirectory/debug.log").Hash;reason='20 simulated-second capture limit cut off the final zero/255-count matrix case despite exit0; rejected as incomplete. Accepted capture allows60 simulated seconds.'})
 $data|ConvertTo-Json -Depth 9 -Compress|Set-Content $path
}
$path="$target/calibrated-delay-timing.json";$data=Get-Content $path -Raw|ConvertFrom-Json
$data|Add-Member -NotePropertyName literal_rows -NotePropertyValue @($literalRows.ToArray())
$data|Add-Member -NotePropertyName literal_native_regions -NotePropertyValue @([ordered]@{address=0x7946;bytes_hex=[Convert]::ToHexString($rom[0x7946..0x794C])},[ordered]@{address=0x794F;bytes_hex=[Convert]::ToHexString($rom[0x794F..0x7954])})
$data|ConvertTo-Json -Depth 9 -Compress|Set-Content $path
Write-Output "$($literalTokens.Count) literal tokens/$literalReferences existing references,20 native literal cases"

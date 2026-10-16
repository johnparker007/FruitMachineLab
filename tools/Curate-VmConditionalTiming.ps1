param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$NaturalRunDirectory,[Parameter(Mandatory=$true)][string]$RomPath,[Parameter(Mandatory=$true)][string]$MameExecutable,[string]$ExcludedRunDirectory)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash'
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0' -or (Select-String "$RunDirectory/debug.log" -Pattern '^Error ' -Quiet)){throw 'Invalid synthetic capture'}
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath);$cases=@(Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json)
if($cases.Count -ne 376){throw 'Expected376 synthetic cases'}
function Fields($line){$f=@{};foreach($m in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){if($m.Groups[1].Value -eq 'bytes'){$f.bytes=$m.Groups[2].Value}else{$f[$m.Groups[1].Value]=[Convert]::ToUInt64($m.Groups[2].Value,16)}};return $f}
function Context([int]$pc,[string]$hex){$bytes=[Convert]::FromHexString($hex);if($bytes.Length -ne 5 -or $pc -lt 0x1400){throw 'Expected native ROM context'};for($k=0;$k -lt 5;$k++){if($bytes[$k] -ne $rom[$pc+$k]){throw 'ROM context differs'}}}
$synthetic=[Collections.Generic.List[object]]::new();$current=$null
foreach($line in [IO.File]::ReadLines("$RunDirectory/debug.log")){
 if($line -notmatch '^(VS|VI|VE) '){continue};$kind=$Matches[1];$f=Fields $line
 if($kind -eq 'VS'){
  if($null -ne $current -or $f.id -ne $synthetic.Count){throw 'Unordered synthetic cases'}
  $case=$cases[$f.id];$entry=$rom[$case.token]*256+$rom[$case.token+1]
  if($f.pc -ne $entry){throw 'Entry header differs'}
  Context $f.pc $f.bytes
  $current=[ordered]@{case=$case;header_hex=[Convert]::ToHexString($rom[$case.token..($case.token+1)]);start_cycle=$f.cycle;instructions=[Collections.Generic.List[object]]::new()}
  $current.instructions.Add([ordered]@{pc=$f.pc;context_hex=$f.bytes;cycle=$f.cycle;cc=$f.cc});continue
 }
 if($null -eq $current -or $f.id -ne $current.case.id){throw 'Missing active case'}
 if($kind -eq 'VI'){Context $f.pc $f.bytes;$current.instructions.Add([ordered]@{pc=$f.pc;context_hex=$f.bytes;cycle=$f.cycle;cc=$f.cc});continue}
 if($f.pc -ne 0xFC -or $current.instructions.Count -eq 0){throw 'Missing native return to NEXT'}
 $current.end=$f;$synthetic.Add($current);$current=$null
}
if($synthetic.Count -ne 376 -or $null -ne $current){throw 'Incomplete synthetic matrix'}
$prior=Get-Content "$target/ptm-instruction-boundaries-verification.json" -Raw|ConvertFrom-Json
if((Get-Content "$NaturalRunDirectory/exit-code.txt" -Raw).Trim() -ne '0' -or (Get-FileHash "$NaturalRunDirectory/ptm-instructions.csv").Hash -ne $prior.instructions_sha256){throw 'Use accepted natural instruction capture'}
$ops=@(Import-Csv "$NaturalRunDirectory/ptm-instructions.csv"|Where-Object event -eq opcode)
function Cycle($r){[ulong][decimal]::Round(([decimal]$r.seconds*1000000000000000000d+[decimal]$r.attoseconds)*1720000d/1000000000000000000d)-1}
$tokens=@{'7984'=0x7982;'79A8'=0x79A6;'79BB'=0x79B9;'7A71'=0x7A6F;'7ADE'=0x7ADC;'7AE9'=0x7AE7}
$natural=[Collections.Generic.List[object]]::new();$excluded=[Collections.Generic.List[object]]::new()
$starts=@(for($i=0;$i -lt $ops.Count;$i++){if($ops[$i].address -eq '00FC'){$i}})
for($n=0;$n -lt $starts.Count-1;$n++){
 $start=$starts[$n];$stop=$starts[$n+1];$entry=$ops[$start+2].address
 if($ops[$start+1].address -ne '00FE' -or !$tokens.ContainsKey($entry)){continue}
 $token=$tokens[$entry]
 if(@($ops[$start..($stop-1)]|Where-Object address -eq FE70).Count){$excluded.Add([ordered]@{token=$token;start_cycle=(Cycle $ops[$start]);reason='Contains native IRQ work; excluded from uninterrupted timing comparison'});continue}
 $instructions=@(for($i=$start;$i -lt $stop;$i++){
  $r=$ops[$i];$pc=[Convert]::ToInt32($r.address,16);if($pc -ge 0x1400){Context $pc $r.bytes}
  [ordered]@{pc=$pc;context_hex=$r.bytes;cycle=(Cycle $r);cc=[Convert]::ToInt32($r.cc,16)}
 })
 $branch=$instructions|Where-Object {$_.pc -in @(0x7986,0x79AA,0x79BD,0x7A75,0x7AE3,0x7AEE)}
 if(@($branch).Count -ne 1){throw 'Expected one conditional instruction'}
 $natural.Add([ordered]@{token=$token;selection_basis='Representative token for observed native entry; token identity and VM operands are absent. Path selected from captured native branch CC.';branch_pc=$branch.pc;branch_cc=$branch.cc;start_cycle=(Cycle $ops[$start]);end_cycle=(Cycle $ops[$stop]);instructions=$instructions})
}
[ordered]@{classification='Synthetic native ROM execution with injected CPU/RAM state; ordinary IRQ masked. Starts at native body, stops before RAM NEXT; no natural whole-machine equivalence.';rows=@($synthetic.ToArray())}|ConvertTo-Json -Depth 9 -Compress|Set-Content "$target/vm-conditional-synthetic.json"
[ordered]@{classification='Natural uninterrupted selected VM paths from the accepted Skill Cash prefix. Native contexts ROM-byte checked; RAM NEXT observed. Operands not present: path selection is checked from captured CC, independently of synthetic operand selection.';rows=@($natural.ToArray());excluded_interrupted=@($excluded.ToArray());partial_initial_and_final_excluded=$true}|ConvertTo-Json -Depth 8 -Compress|Set-Content "$target/vm-conditional-natural.json"
[ordered]@{synthetic_run=$RunDirectory;natural_run=$NaturalRunDirectory;synthetic_debugger_sha256=(Get-FileHash "$RunDirectory/debugger.cmd").Hash;synthetic_log_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash;synthetic_cases_sha256=(Get-FileHash "$RunDirectory/cases.json").Hash;natural_instructions_sha256=$prior.instructions_sha256;rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;mame_sha256=(Get-FileHash $MameExecutable).Hash;synthetic_cases=$synthetic.Count;natural_paths=$natural.Count;excluded_interrupted=$excluded.Count;source_tag='mame0281';source_commit='2843a3deb81cf93735244044894196ccfbea4d20'}|ConvertTo-Json|Set-Content "$target/vm-conditional-verification.json"
Write-Output "$($synthetic.Count) synthetic cases, $($natural.Count) natural paths, $($excluded.Count) interrupted excluded"
if($ExcludedRunDirectory){
 $path="$target/vm-conditional-verification.json";$v=Get-Content $path -Raw|ConvertFrom-Json
 $v|Add-Member -NotePropertyName excluded_attempt -NotePropertyValue ([ordered]@{source_run=$ExcludedRunDirectory;log_sha256=(Get-FileHash "$ExcludedRunDirectory/debug.log").Hash;reason='Initial breakpoint is skipped by debugger go; first instruction snapshot was missing. Corrected capture explicitly logs its start boundary. Excluded from fixtures.'})
 $v|ConvertTo-Json -Depth 5|Set-Content $path
}

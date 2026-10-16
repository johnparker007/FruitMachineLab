param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath,[string]$ExcludedRunDirectory)
$ErrorActionPreference='Stop';$target="$PSScriptRoot/../evidence/mpu4/skill-cash"
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0'){throw 'Capture did not exit cleanly'}
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath);$cases=@(Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json);$rows=[Collections.Generic.List[object]]::new();$active=$null
foreach($line in (Get-Content "$RunDirectory/debug.log")){
 if($line -notmatch '^S([SIF]) '){continue};$kind=$Matches[1];$fields=@{};foreach($match in [regex]::Matches($line,'([a-z0-9_]+)=([0-9A-F]+)')){$fields[$match.Groups[1].Value]=[Convert]::ToUInt64($match.Groups[2].Value,16)}
 if($kind -eq 'S'){if($null -ne $active){throw 'Unfinished case'};$active=[ordered]@{case=$cases[[int]$fields.id];instructions=[Collections.Generic.List[object]]::new()}}
 if($null -eq $active -or $fields.id -ne $active.case.id){throw 'Missing/mismatched case'}
 if($kind -in @('S','I')){
  if($line -notmatch 'bytes=([0-9A-F]{10})'){throw 'Missing context'};$hex=$Matches[1];$pc=[int]$fields.pc;$bytes=[Convert]::FromHexString($hex);for($n=0;$n -lt 5;$n++){if($bytes[$n] -ne $rom[$pc+$n]){throw 'ROM context differs'}}
  $active.instructions.Add([ordered]@{pc=$pc;cycle=$fields.cycle;context_hex=$hex})
 }else{
  if($fields.pc -ne 0x800 -or $fields.s -ne 0x702){throw 'Unexpected native return'};$active['end']=$fields;$active.instructions=@($active.instructions.ToArray());$rows.Add($active);$active=$null
 }
}
if($null -ne $active -or $rows.Count -ne 64 -or $cases.Count -ne 64){throw 'Truncated scan capture'}
$excluded=$null;if($ExcludedRunDirectory){$excluded=[ordered]@{source_run=$ExcludedRunDirectory;debug_sha256=(Get-FileHash "$ExcludedRunDirectory/debug.log").Hash;reason='Preliminary64-case run used ambiguous debugger b@a/b@b expressions for sample RAM, which resolve CPU registers rather than hex addresses. Replaced with explicit0x addresses and deterministic frame seeds; not used for comparisons.'}}
$regions=@(foreach($r in @(@(0x28E6,24,'three eight-column PIA control selector tables'),@(0x28FE,189,'output scan28FE through29BA RTS'),@(0x29BB,4,'phase blink-mask table'),@(0x19C2,56,'sweep helper through19F8 PULS'),@(0x19FA,11,'signed-step reversal tail through1A03 BRA19E9'),@(0x70EF,34,'timer3 arm through710F PULS'))){[ordered]@{address=$r[0];bytes_hex=[Convert]::ToHexString($rom[$r[0]..($r[0]+$r[1]-1)]);purpose=$r[2]}})
[ordered]@{classification='Synthetic isolated original-ROM28FE scan calls; injected RAM/PIA state, IRQ/FIRQ masked; not a natural gameplay path';context='Five ROM-checked bytes, not asserted instruction lengths. Initial frames byte[i]=(i*37+11)&255; glyph3F,decimalAA,blink55,portsA5/5A/CC; callback48FD, control shadows00.';native_regions=$regions;rows=@($rows.ToArray())}|ConvertTo-Json -Depth 8|Set-Content "$target/output-scan-timing.json"
[ordered]@{source_run=$RunDirectory;debug_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash;cases_sha256=(Get-FileHash "$RunDirectory/cases.json").Hash;rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;provenance=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);cases=$rows.Count;excluded=$excluded}|ConvertTo-Json -Depth 5|Set-Content "$target/output-scan-timing-verification.json"
Write-Output 'Curated64 isolated original output-scan paths'

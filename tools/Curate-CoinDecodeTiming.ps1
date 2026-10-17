param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$target="$PSScriptRoot/../evidence/mpu4/skill-cash"
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0'){throw 'Capture did not exit cleanly'}
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath);$cases=@(Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json);$rows=[Collections.Generic.List[object]]::new();$active=$null
foreach($line in (Get-Content "$RunDirectory/debug.log")){
 if($line -notmatch '^C([SIF]) '){continue};$kind=$Matches[1];$fields=@{};foreach($match in [regex]::Matches($line,'([a-z0-9_]+)=([0-9A-F]+)')){$fields[$match.Groups[1].Value]=[Convert]::ToUInt64($match.Groups[2].Value,16)}
 if($kind -eq 'S'){if($null -ne $active){throw 'Unfinished case'};$active=[ordered]@{case=$cases[[int]$fields.id];instructions=[Collections.Generic.List[object]]::new()}}
 if($null -eq $active -or $fields.id -ne $active.case.id){throw 'Missing/mismatched case'}
 if($kind -in @('S','I')){
  if($line -notmatch 'bytes=([0-9A-F]{10})'){throw 'Missing context'};$hex=$Matches[1];$pc=[int]$fields.pc;$bytes=[Convert]::FromHexString($hex);for($n=0;$n -lt 5;$n++){if($bytes[$n] -ne $rom[$pc+$n]){throw 'ROM context differs'}}
  $active.instructions.Add([ordered]@{pc=$pc;cycle=$fields.cycle;context_hex=$hex})
 }else{
  if($fields.pc -ne 0x46D3 -or $fields.s -ne 0x6FC){throw 'Unexpected continuation/stack'};$active['end']=$fields;$active.instructions=@($active.instructions.ToArray());$rows.Add($active);$active=$null
 }
}
if($null -ne $active -or $rows.Count -ne 64 -or $cases.Count -ne 64){throw 'Truncated coin-prefix capture'}
$regions=@(foreach($r in @(@(0x438C,19),@(0x439F,69),@(0x71EE,4),@(0x43E4,5))){[ordered]@{address=$r[0];bytes_hex=[Convert]::ToHexString($rom[$r[0]..($r[0]+$r[1]-1)])}})
[ordered]@{classification='Synthetic original-ROM coin-decode prefix, stops before46D3. Five-byte contexts are not instruction lengths. Exact43E4 byte88 is retained as unresolved inline data, not decoded as an EORA instruction.';native_regions=$regions;rows=@($rows.ToArray())}|ConvertTo-Json -Depth 8|Set-Content "$target/coin-decode-timing.json"
[ordered]@{source_run=$RunDirectory;debug_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash;cases_sha256=(Get-FileHash "$RunDirectory/cases.json").Hash;rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;provenance=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);cases=$rows.Count}|ConvertTo-Json -Depth 5|Set-Content "$target/coin-decode-timing-verification.json"
Write-Output 'Curated64 isolated original coin-decode prefixes'

param([Parameter(Mandatory=$true)][string]$RunDirectory,[string]$RepeatRunDirectory)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash'
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0'){throw 'Incomplete capture'}
$rows=@(Import-Csv "$RunDirectory/lifecycle.csv")
if(@($rows|Where-Object {$_.event -eq 'after' -and $_.address -eq '710F'}).Count -ne 20){throw 'Incomplete20-arm lifecycle capture'}
foreach($row in $rows){if($row.event -notin @('write','read','after')){throw 'Invalid event'}}
$repeat=$null
if($RepeatRunDirectory){
 if((Get-Content "$RepeatRunDirectory/exit-code.txt" -Raw).Trim() -ne '0' -or (Get-FileHash "$RepeatRunDirectory/lifecycle.csv").Hash -ne (Get-FileHash "$RunDirectory/lifecycle.csv").Hash){throw 'Independent lifecycle repeat differs'}
 $repeat=[ordered]@{source_run=$RepeatRunDirectory;csv_sha256=(Get-FileHash "$RepeatRunDirectory/lifecycle.csv").Hash;lua_sha256=(Get-FileHash "$RepeatRunDirectory/lifecycle.lua").Hash;byte_identical=$true}
}
[ordered]@{classification='Natural cold/default attract, no player input or state injection. Bus writes sample BEFORE access; bus reads sample AFTER access, with data holding returned value. Selected opcode fetches sample AFTER prior instruction. Exact decimal timestamp strings retain attosecond truncation. Not canonical Skill Cash.';rows=$rows}|ConvertTo-Json -Depth 5|Set-Content "$target/ptm-lifecycle.json"
[ordered]@{source_run=$RunDirectory;csv_sha256=(Get-FileHash "$RunDirectory/lifecycle.csv").Hash;lua_sha256=(Get-FileHash "$RunDirectory/lifecycle.lua").Hash;debugger_sha256=(Get-FileHash "$RunDirectory/debugger.cmd").Hash;provenance=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);rows=$rows.Count;arms=20;independent_repeat=$repeat;reference_source='https://raw.githubusercontent.com/mamedev/mame/master/src/devices/machine/6840ptm.cpp';source_version_gap='Upstream master explains the hypothesis; installed0.281 read-only observations validate the selected lifecycle. No claim that master equals installed source.'}|ConvertTo-Json -Depth 6|Set-Content "$target/ptm-lifecycle-verification.json"
Write-Output "Curated $($rows.Count) lifecycle observations"

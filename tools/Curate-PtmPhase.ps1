param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash'
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0'){throw 'Incomplete capture'}
$raw=@(Import-Csv "$RunDirectory/phase.csv");$rows=[Collections.Generic.List[object]]::new();$low=0;$high=0
if($raw.Count -ne 200){throw 'Incomplete100-arm phase capture'}
for($i=0;$i -lt 200;$i+=2){
 $a=$raw[$i];$b=$raw[$i+1]
 if($a.event -ne 'write' -or $b.event -ne 'after' -or $a.pc -ne '710F' -or $b.pc -ne '7110' -or $a.output3 -ne $b.output3 -or $b.latch3 -ne '40' -or $a.output3 -notin @('0','1')){throw 'Phase pair differs'}
 if($a.output3 -eq '0'){$low++}else{$high++}
 $rows.Add([ordered]@{write_time=$a.time;after_time=$b.time;initial_high=[int]$a.output3;control1=[int]$a.control1;control2=[int]$a.control2;control3=[int]$a.control3;previous_latch=[int]$a.latch3;latch=[int]$b.latch3})
}
[ordered]@{classification='Natural cold/default attract before any player input. Read-only saved-item observations at710F bus write and7110 opcode fetch; neither canonical Skill Cash nor full startup validation.';rows=@($rows.ToArray())}|ConvertTo-Json -Depth 5|Set-Content "$target/ptm-natural-phase.json"
$excluded=@();$previous="$target/ptm-natural-phase-verification.json"
if(Test-Path $previous){$old=Get-Content $previous -Raw|ConvertFrom-Json;if($old.PSObject.Properties.Name -contains 'excluded_attempts'){$excluded=@($old.excluded_attempts)}}
[ordered]@{source_run=$RunDirectory;csv_sha256=(Get-FileHash "$RunDirectory/phase.csv").Hash;lua_sha256=(Get-FileHash "$RunDirectory/phase.lua").Hash;debugger_sha256=(Get-FileHash "$RunDirectory/debugger.cmd").Hash;provenance=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);low_arms=$low;high_arms=$high;excluded_attempts=$excluded}|ConvertTo-Json -Depth 6|Set-Content $previous
Copy-Item "$RunDirectory/phase.lua" "$target/ptm-natural-phase.lua"
Write-Output "Curated100 arms: low=$low high=$high"

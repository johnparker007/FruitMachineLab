param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0' -or (Select-String -LiteralPath "$RunDirectory/debug.log" -Pattern '^Error in expression:' -Quiet)){throw 'Incomplete/error matrix'}
$rows=@();$log=Get-Content "$RunDirectory/debug.log" -Raw
foreach($case in (Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json)){
 $match=[regex]::Match($log,('(?m)^DONE '+[regex]::Escape($case.id)+' d=([0-9A-F]{4})'))
 if(!$match.Success){throw ('Missing return '+$case.id)}
 $row=[ordered]@{};foreach($property in $case.PSObject.Properties){$row[$property.Name]=$property.Value}
 $row.before_hex=[Convert]::ToHexString([IO.File]::ReadAllBytes("$RunDirectory/$($case.id)-before.bin"))
 $row.after_hex=[Convert]::ToHexString([IO.File]::ReadAllBytes("$RunDirectory/$($case.id)-after.bin"))
 $config=[regex]::Match($log,('(?m)^CFG '+[regex]::Escape($case.id)+' a=([0-9A-F]{2}) p=([0-9A-F]{2})'))
 if(!$config.Success){throw 'Missing configuration observation'}
 $row.actual_config=[Convert]::ToByte($config.Groups[1].Value,16);$row.actual_percentage=[Convert]::ToByte($config.Groups[2].Value,16)
 $expectedConfig=if($case.kind -eq 'decay'){$case.config}else{0};$expectedPercentage=if($case.kind -eq 'target'){$case.percentage}elseif($case.kind -eq 'subtract'){80}else{0}
 if($row.actual_config -ne $expectedConfig -or $row.actual_percentage -ne $expectedPercentage){throw 'Requested ROM configuration patch was not observed'}
 $row.return_d=[Convert]::ToUInt16($match.Groups[1].Value,16);$rows+=@($row)
}
[ordered]@{classification='Synthetic native3AFA/4D9B/14EB/57DB MAME matrix; masked IRQs; compared low0000..06FF and protected07C9..07E7 RAM, plus returnedD for4D9B. Native CPU stack/register residue is not compared';source_run=$RunDirectory;raw_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash;provenance=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);cases=$rows}|ConvertTo-Json -Depth 6 -Compress|Set-Content (Join-Path $root 'evidence/mpu4/skill-cash/stake-matrix.json')

param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0' -or (Select-String -LiteralPath "$RunDirectory/debug.log" -Pattern '^Error in expression:' -Quiet)){throw 'Incomplete/error matrix'}
$rows=@();$log=Get-Content "$RunDirectory/debug.log" -Raw
foreach($case in (Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json)){
 if(![regex]::IsMatch($log,('(?m)^DONE '+[regex]::Escape($case.id)+'\r?$'))){throw ('Missing return '+$case.id)}
 $rows+=@([ordered]@{id=$case.id;mask=$case.mask;seed=$case.seed;irq=$case.irq;before_hex=[Convert]::ToHexString([IO.File]::ReadAllBytes("$RunDirectory/$($case.id)-before.bin"));after_hex=[Convert]::ToHexString([IO.File]::ReadAllBytes("$RunDirectory/$($case.id)-after.bin"))})
}
[ordered]@{classification='Synthetic native2BBC matrix; compare0000..06FF RAM, excluding native CPU stack, with exact held/unheld requests and PRNG state';source_run=$RunDirectory;raw_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash;provenance=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);cases=$rows}|ConvertTo-Json -Depth 6 -Compress|Set-Content (Join-Path $root 'evidence/mpu4/skill-cash/reel-request-matrix.json')

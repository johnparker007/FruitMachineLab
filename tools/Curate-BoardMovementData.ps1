param([Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
if((Get-FileHash -LiteralPath $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDc489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
$bytes=[IO.File]::ReadAllBytes($RomPath);$ranges=[ordered]@{}
foreach($range in @(@(0x8E6D,57),@(0x971F,34),@(0xA64B,16))) {$ranges[$range[0].ToString('X4')]=[Convert]::ToHexString([byte[]]$bytes[$range[0]..($range[0]+$range[1]-1)])}
foreach($token in @(0x8E93,0x96E8)){if($bytes[$token] -ne $bytes[0x8EE2] -or $bytes[$token+1] -ne $bytes[0x8EE3]){throw 'Queued-sound gateway differs'}}
[ordered]@{classification='Selected static ROM sound and profile data for board advance; not a recorded movement outcome. 8E93/96E8 share the identical 8568 parameter gateway entry cost with 8EE2; bodies still execute';rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;ranges=$ranges;equivalent_timing_tokens=[ordered]@{'8E93'='8EE2';'96E8'='8EE2'}}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $root 'evidence/mpu4/maps/board-movement-data.json')

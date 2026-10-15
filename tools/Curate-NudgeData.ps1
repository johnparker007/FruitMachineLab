param([Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
if((Get-FileHash -LiteralPath $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
$bytes=[IO.File]::ReadAllBytes($RomPath);$ranges=[ordered]@{}
foreach($range in @(@(0x8B0D,52),@(0x9E06,6),@(0x9BD4,4),@(0x8435,6),@(0x9BF8,16),@(0x9C08,6),@(0x9DA9,20),@(0x930B,82),@(0xB3E5,18))){$ranges[$range[0].ToString('X4')]=[Convert]::ToHexString([byte[]]$bytes[$range[0]..($range[0]+$range[1]-1)])}
[ordered]@{classification='Selected static parameter records for type-1 nudge preparation; no recorded outcome substitution';rom_sha1=(Get-FileHash -LiteralPath $RomPath -Algorithm SHA1).Hash;ranges=$ranges}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $root 'evidence/mpu4/maps/nudge-preparation-data.json')

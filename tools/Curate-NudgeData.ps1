param([Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
if((Get-FileHash -LiteralPath $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
$bytes=[IO.File]::ReadAllBytes($RomPath);$ranges=[ordered]@{}
foreach($range in @(@(0x8B0D,52),@(0x9E06,6),@(0x9BD4,10),@(0x8435,6),@(0x9BF8,16),@(0x9C08,6),@(0x9DA9,20),@(0x930B,82),@(0xB3E5,18),@(0xB666,170),@(0x8B99,22),@(0x940F,21),@(0x9424,34),@(0xAF76,11),@(0x8B41,74),@(0x8714,17),@(0x8492,6),@(0x1462,45),@(0x84C8,12),@(0x8510,4),@(0xFF34,1),@(0x8530,4),@(0xFF4A,1),@(0x84B6,6),@(0x84AA,6),@(0x84A4,6),@(0x8486,6),@(0x848C,6),@(0x9C20,4),@(0x7256,1),@(0x204A,5),@(0x8480,6),@(0x84B0,6),@(0x843B,6))){$ranges[$range[0].ToString('X4')]=[Convert]::ToHexString([byte[]]$bytes[$range[0]..($range[0]+$range[1]-1)])}
[ordered]@{classification='Selected static parameter records for type-1 nudge preparation; no recorded outcome substitution';rom_sha1=(Get-FileHash -LiteralPath $RomPath -Algorithm SHA1).Hash;ranges=$ranges}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $root 'evidence/mpu4/maps/nudge-preparation-data.json')

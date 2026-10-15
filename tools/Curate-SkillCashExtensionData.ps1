param([Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
$bytes=[IO.File]::ReadAllBytes($RomPath);$ranges=[ordered]@{}
foreach($range in @(@(0x7248,0xF5),@(0x84C4,4),@(0x8988,0x40),@(0x975B,0x1A7),@(0x9BCA,4),@(0x9C5A,5),@(0xA310,11),@(0xA374,19),@(0xDE9A,0x13C),@(0xDFD8,18),@(0xE2D9,10))){$ranges[$range[0].ToString('X4')]=[Convert]::ToHexString([byte[]]$bytes[$range[0]..($range[0]+$range[1]-1)])}
if([Convert]::ToHexString([byte[]]$bytes[0xA363..0xA364]) -ne '00F8' -or [Convert]::ToHexString([byte[]]$bytes[0x9B3E..0x9B3F]) -ne '00F8'){throw 'Threaded call headers differ'}
if([Convert]::ToHexString([byte[]]$bytes[0x7F0D..0x7F0E]) -ne '7946' -or [Convert]::ToHexString([byte[]]$bytes[0x7F07..0x7F08]) -ne '7946'){throw 'Literal fetch headers differ'}
[ordered]@{classification='Static deduction: selected lamp/sound/alpha data for A365 and DFD8 dispatch tokens from hash-checked unchanged ROM. Timing aliases have identical native dispatch headers, not new measured paths';rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;ranges=$ranges;equivalent_timing_tokens=[ordered]@{A363='9B3E';'7F0D'='7F07'}} | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $root 'evidence/mpu4/maps/skill-cash-extension-data.json')

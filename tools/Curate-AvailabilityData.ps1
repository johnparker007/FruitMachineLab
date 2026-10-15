param([Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
if((Get-FileHash -LiteralPath $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
$bytes=[IO.File]::ReadAllBytes($RomPath)
[ordered]@{classification='Static triple/pair result tables for native reel search; outcomes computed by recovered loops';rom_sha1=(Get-FileHash -LiteralPath $RomPath -Algorithm SHA1).Hash;ranges=[ordered]@{'75BD'=[Convert]::ToHexString([byte[]]$bytes[0x75BD..0x75CA])}}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $root 'evidence/mpu4/maps/nudge-availability-data.json')

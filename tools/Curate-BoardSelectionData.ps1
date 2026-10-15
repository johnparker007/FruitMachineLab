param([Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
$bytes=[IO.File]::ReadAllBytes($RomPath);$ranges=[ordered]@{}
foreach($range in @(@(0x843D,4),@(0x84A0,4),@(0x84F4,4),@(0x84FA,4),@(0x95FD,0x122),@(0x9B84,2),@(0x9BAA,4),@(0x9BB6,4),@(0xA12E,48),@(0xD5D1,816),@(0xD903,48),@(0xD938,5),@(0xD996,5),@(0xD9AC,24))) {
 $ranges[$range[0].ToString('X4')]=[Convert]::ToHexString([byte[]]$bytes[$range[0]..($range[0]+$range[1]-1)])
}
[ordered]@{classification='Static selected ROM data for board square 32 selection, masked conditions and announcement sound; unchanged ROM SHA1 checked';rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;ranges=$ranges} | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $root 'evidence/mpu4/maps/board-selection-data.json')

param([Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
if((Get-FileHash -LiteralPath $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
$bytes=[IO.File]::ReadAllBytes($RomPath);$ranges=[ordered]@{}
foreach($range in @(@(0x72FD,33),@(0x8EA8,58),@(0x955F,27),@(0x95AF,26),@(0x95C9,15),@(0x972E,54),@(0x9B88,4),@(0x9BDE,16),@(0x9C0E,16),@(0xA192,58),@(0xDAC9,16))) {$ranges[$range[0].ToString('X4')]=[Convert]::ToHexString([byte[]]$bytes[$range[0]..($range[0]+$range[1]-1)])}
$dynamic=@(0x9BDE,0x9BE2,0x9BE6,0x9BEA,0x9C0E,0x9C12,0x9C16,0x9C1A)
foreach($token in $dynamic){if($bytes[$token] -ne 0x9B -or $bytes[$token+1] -ne 0x15){throw 'Indexed lamp parameter gateway differs'}}
[ordered]@{classification='Selected static ROM path tables, dynamic lamp words and sound streams for ladders/snakes; outcomes execute in the VM';rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;ranges=$ranges;dynamic_tokens=@($dynamic|ForEach-Object {$_.ToString('X4')})}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $root 'evidence/mpu4/maps/board-link-data.json')

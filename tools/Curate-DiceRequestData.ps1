param([Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
$bytes=[IO.File]::ReadAllBytes($RomPath);$ranges=[ordered]@{}
foreach($range in @(@(0x14DB,16),@(0x75CB,136),@(0x87A1,361),@(0x9C2A,4),@(0x9DC3,4),@(0xA160,48),@(0xA5FB,32),@(0xA65B,16),@(0xB029,13),@(0xB23D,28),@(0xFF42,1))) {
 $ranges[$range[0].ToString('X4')]=[Convert]::ToHexString([byte[]]$bytes[$range[0]..($range[0]+$range[1]-1)])
}
$calls=[Collections.Generic.HashSet[string]]::new()
foreach($file in Get-ChildItem (Join-Path $root 'evidence/mpu4/VM-SCRIPTS') -Filter '*.txt') {
 foreach($line in [IO.File]::ReadLines($file.FullName)) {
  if($line -match '^\s*\*?\s*[0-9A-F]{4}\s+([0-9A-F]{4})\s+.*body=' -and $line -notmatch 'push_address') {
   $token=$Matches[1];$at=[Convert]::ToUInt16($token,16);if($bytes[$at] -eq 0 -and $bytes[$at+1] -eq 0xF8){[void]$calls.Add($token)}
  }
 }
}
if($bytes[0x9B3E] -ne 0 -or $bytes[0x9B3F] -ne 0xF8){throw 'Pacing reference is not the same threaded-call gateway'}
if($bytes[0x78BE] -ne $bytes[0x78B5] -or $bytes[0x78BF] -ne $bytes[0x78B6]){throw 'Zero-word native gateways differ'}
[ordered]@{classification='Static selected ROM data for dice result selection, reel geometry and symbol projection; physical motion is not implied. Call pacing membership is statically validated identical 00F8 gateway, not newly measured paths';rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;ranges=$ranges;equivalent_timing_tokens=[ordered]@{'78BE'='78B5'};threaded_call_pacing=[ordered]@{header='00F8';reference_token='9B3E';tokens=@($calls|Sort-Object)}}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $root 'evidence/mpu4/maps/dice-request-data.json')

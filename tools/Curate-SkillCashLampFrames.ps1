param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash'
$original=Get-Content (Join-Path $target 'hashes.json') -Raw | ConvertFrom-Json;$comparisons=[ordered]@{}
foreach($name in @('state.csv','feature-state.csv','input-levels.csv','ram-final.bin')) {
 $expected=($original | Where-Object {[IO.Path]::GetFileName($_.Path) -eq $name}).Hash;$actual=(Get-FileHash (Join-Path $RunDirectory $name)).Hash
 if($actual -ne $expected){throw "Lamp capture differs in $name"};$comparisons[$name]=[ordered]@{equal=$true;sha256=$actual}
}
$map=Get-Content (Join-Path $root 'evidence/mpu4/maps/deep-pass-lamp-map.json') -Raw | ConvertFrom-Json
# Derive response bits from measured rows, retaining native XOR addressing.
$responses=@(for($column=0;$column -lt 8;$column++){
 $row=$map.lamp_rows | Where-Object {$_.rom_command_id -eq $column};([int]$row.buffer_column -shl 3) -bxor ($column -band 0x78)
})
foreach($row in $map.lamp_rows) {
 if([int]$row.rom_command_id -gt 127){continue}
 if((($responses[[int]$row.rom_command_id -band 7] -bxor [int]$row.rom_command_id) -band 0x78) -shr 3 -ne [int]$row.buffer_column){throw 'Inconsistent characteriser map'}
}
$initial=$null;$pending=$null;$count=0;$anchors=[Collections.Generic.List[object]]::new();$bytes=[IO.MemoryStream]::new()
try {
 foreach($line in [IO.File]::ReadLines((Join-Path $RunDirectory 'debug.log'))) {
  if($line -match '^LI id=([0-9A-F]{2}) pattern=([0-9A-F]{2}) frames=([0-9A-F]{128})') {
   if($null -ne $pending){throw 'Nested lamp native call'};$pending=@([Convert]::ToInt32($Matches[1],16),[Convert]::ToInt32($Matches[2],16));
   if($null -eq $initial){$initial=$Matches[3]}
  } elseif($line -match '^LF id=([0-9A-F]{2}) pattern=([0-9A-F]{2}) column=([0-9A-F]{2}) frames=([0-9A-F]{128})') {
   $id=[Convert]::ToInt32($Matches[1],16);$pattern=[Convert]::ToInt32($Matches[2],16);$column=[Convert]::ToInt32($Matches[3],16);$frames=$Matches[4]
   if($null -eq $pending -or $pending[0] -ne $id -or $pending[1] -ne $pattern){throw 'Lamp return arguments differ'}
   $bytes.WriteByte([byte]$id);$bytes.WriteByte([byte]($pattern -band 15));$bytes.WriteByte([byte]$column)
   $frameBytes=[Convert]::FromHexString($frames);$bytes.Write($frameBytes)
   if($count%128 -eq 0){$anchors.Add([ordered]@{ordinal=$count;id=$id;pattern=($pattern -band 15);column=$column;frames=$frames})}
   $pending=$null;$count++
  }
 }
 $digest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes.ToArray()))
} finally {$bytes.Dispose()}
if($count -ne 7298 -or $null -ne $pending){throw "Incomplete lamp capture: $count"}
[ordered]@{classification='Trace-backed 49C5 return frame RAM; column responses derived from prior reviewed map. Physical scan timing is not included';
 initial=$initial;responses=$responses;requests=$count;expected_sha256=$digest;anchors=@($anchors.ToArray())} |
 ConvertTo-Json -Depth 7 -Compress | Set-Content (Join-Path $target 'lamp-frames.json')
[ordered]@{run_directory=$RunDirectory;raw_debug_sha256=(Get-FileHash (Join-Path $RunDirectory 'debug.log')).Hash;comparisons=$comparisons;
 provenance=(Get-Content (Join-Path $RunDirectory 'provenance.json') -Raw | ConvertFrom-Json)} | ConvertTo-Json -Depth 7 | Set-Content (Join-Path $target 'lamp-frame-verification.json')
Copy-Item (Join-Path $RunDirectory 'debugger.cmd') (Join-Path $target 'lamp-frame-debugger.cmd')

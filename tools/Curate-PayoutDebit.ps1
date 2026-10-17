param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$target="$PSScriptRoot/../evidence/mpu4/collection"
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0'){throw 'Incomplete matrix'}
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Wrong ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath);$log=[IO.File]::ReadAllText("$RunDirectory/debug.log")
if($log -match '(?mi)^Error in (?:assignment )?expression:'){throw 'Debugger expression error'}
$rows=@(foreach($case in (Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json)) {
 if($log -notmatch ('(?m)^PAYOUT '+$case.id+' pc=6858 u=0600 y='+$case.record.ToString('X4')+'\s*$')){throw 'Incorrect native exit'}
 $before=[IO.File]::ReadAllBytes("$RunDirectory/$($case.id)-before.bin");$after=[IO.File]::ReadAllBytes("$RunDirectory/$($case.id)-after.bin")
 if($before.Length -ne 2048 -or $after.Length -ne 2048){throw 'Wrong snapshot length'}
 [ordered]@{case=$case;before_hex=[Convert]::ToHexString($before);after_hex=[Convert]::ToHexString($after)}
})
if($rows.Count -ne 32){throw 'Expected32 matrix cases'}
[ordered]@{classification='Synthetic isolated native4CBE through nestedA8F9 VM display and accounting/queues, stopped before6858. IRQ masked; no natural timing claim.';rows=$rows;capture=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);raw_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash}|ConvertTo-Json -Depth 8|Set-Content "$target/debit-matrix.json"
$ranges=@(foreach($r in @(@(0x4ACA,68),@(0x201A,4),@(0x20B0,4),@(0x5BCE,74),@(0x7D36,2),@(0x84E8,4),@(0x851C,10),@(0xFF34,30))){[ordered]@{address=$r[0];bytes_hex=[Convert]::ToHexString($rom[$r[0]..($r[0]+$r[1]-1)])}})
$native=@(foreach($r in @(@(0x4B39,0x23B),@(0x511B,0x96),@(0x57A9,15),@(0x57F7,9),@(0x59A4,23),@(0x5B77,0x57),@(0x60AB,0x2B),@(0x6858,0x98),@(0x6FC1,16),@(0x6FEC,28),@(0x7009,16),@(0x7032,23),@(0x7172,41))){[ordered]@{address=$r[0];bytes_hex=[Convert]::ToHexString($rom[$r[0]..($r[0]+$r[1]-1)])}})
[ordered]@{rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;classification='Exact ROM ranges. Records4ACA..4B0D, triac masks/messages, display pointer and option constants. Native regions preserve bytes, not a lossless symbolic listing.';ranges=$ranges;native_regions=$native}|ConvertTo-Json -Depth 6|Set-Content "$target/payout-data.json"
Copy-Item "$RunDirectory/debugger.cmd" "$target/debit-matrix-debugger.cmd"
$pending=[Collections.Generic.Queue[string]]::new();$seen=[Collections.Generic.HashSet[string]]::new();$pending.Enqueue('AA2B');$regions=[Collections.Generic.List[object]]::new()
while($pending.Count -gt 0) {
 $body=$pending.Dequeue();if(!$seen.Add($body)){continue};$sites=[Collections.Generic.List[int]]::new()
 foreach($line in Get-Content "$PSScriptRoot/../evidence/mpu4/VM-SCRIPTS/$body.txt") {
  if($line -notmatch '^\s*\*?\s*([0-9A-F]{4})\s+([0-9A-F]{4})\s+'){continue}
  $at=[Convert]::ToInt32($Matches[1],16);$token=[Convert]::ToInt32($Matches[2],16)
  if(($rom[$at]*256+$rom[$at+1]) -ne $token){throw "ROM token differs at$at"};$sites.Add($at)
  if($line -match '\bbody=0x([0-9A-F]{4})'){$pending.Enqueue($Matches[1])}
 }
 if($sites.Count -eq 0){throw "Empty script$body"}
 $regions.Add([ordered]@{body=$body;address=$sites[0];bytes_hex=[Convert]::ToHexString($rom[$sites[0]..($sites[$sites.Count-1]+1)]);checked_token_sites=@($sites.ToArray())})
}
[ordered]@{rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;scope='AA2B static call closure, including disabled/unvisited arms. Exact bytes through last token and checked listing tokens, not a lossless symbolic rebuild.';regions=@($regions.ToArray())}|ConvertTo-Json -Depth 8|Set-Content "$target/vm-encoding-checkpoint.json"
Write-Output 'Curated32 native payout debits plus exact ROM data/instruction ranges'

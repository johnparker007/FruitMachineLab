param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath,[string]$HardwareRunDirectory,[string]$IndependentRunDirectory,[switch]$Nudge,[switch]$Sequence,[switch]$Result,[switch]$PaidSpin)
$ErrorActionPreference='Stop';if($Sequence -and !$Nudge){throw 'Sequence requires Nudge'};$stem=if($PaidSpin){'paid-spin-native'}elseif($Result){'nudge-result-native'}elseif($Sequence){'nudge-sequence-native'}elseif($Nudge){'nudge-motion-native'}else{'dice-motion'};$root=Split-Path $PSScriptRoot -Parent
if($PaidSpin -and ((Get-Content (Join-Path $RunDirectory 'exit-code.txt') -Raw).Trim() -ne '0' -or (Select-String -LiteralPath (Join-Path $RunDirectory 'debug.log') -Pattern '^Error in expression:' -Quiet))){throw 'Incomplete/error paid-spin capture'}
if((Get-FileHash -LiteralPath $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
$events=[Collections.Generic.List[object]]::new();$active=$false;$done=$false;$ordinal=-1
foreach($line in [IO.File]::ReadLines((Join-Path $RunDirectory 'debug.log'))) {
 if($line -match '^SC ' -and (!$PaidSpin -or $line -notmatch '^SC y=E247 ')){if(!$Result -or $line -notmatch '^SC y=(8571|8573|8575|8577|76BD) '){$ordinal++};continue}
 if($line -notmatch '^RM '){continue};$fields=[ordered]@{}
 foreach($match in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$fields[$match.Groups[1].Value]=$match.Groups[2].Value}
 if($fields.pc -eq $(if($PaidSpin){'61D5'}else{'61F6'})){$active=$true};if(!$active -or ($done -and !$Sequence)){continue}
 $fields.ordinal=$ordinal;$events.Add($fields);if($fields.pc -eq '64F0'){$done=$true}
}
if(!$done){throw 'Incomplete native reel motion'}
$independent=[ordered]@{}
if($IndependentRunDirectory) {
 $other=[Collections.Generic.List[string]]::new();$observing=$false
 foreach($line in [IO.File]::ReadLines((Join-Path $IndependentRunDirectory 'debug.log'))) {
  if($line -notmatch '^RM '){continue};$fields=@{};foreach($match in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$fields[$match.Groups[1].Value]=$match.Groups[2].Value}
  if($fields.pc -eq $(if($PaidSpin){'61D5'}else{'61F6'})){$observing=$true};if(!$observing){continue}
  $other.Add((@('pc','flags','drive','records','nvram','checksum')|ForEach-Object {$fields[$_]}) -join ':');if($fields.pc -eq '64F0' -and !$Sequence){break}
 }
 $current=@($events | ForEach-Object {$row=$_;(@('pc','flags','drive','records','nvram','checksum')|ForEach-Object {$row[$_]}) -join ':'})
 if(($current -join "`n") -cne ($other.ToArray() -join "`n")){throw 'Independent motion observations differ'}
 $independent=[ordered]@{source_run=$IndependentRunDirectory;raw_sha256=(Get-FileHash (Join-Path $IndependentRunDirectory 'debug.log')).Hash;core_observations=$other.Count;core_sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($current -join "`n"))))}
}
$data=[IO.File]::ReadAllBytes($RomPath);$ranges=[ordered]@{}
foreach($range in @(@(0x1453,10),@(0x60D6,217),@(0x661B,96),@(0x9585,40))) {$ranges[$range[0].ToString('X4')]=[Convert]::ToHexString([byte[]]$data[$range[0]..($range[0]+$range[1]-1)])}
$target=Join-Path $root 'evidence/mpu4/skill-cash'
if(!$Nudge -and !$PaidSpin){[ordered]@{classification='Selected static ROM data for translated motor profiles, coil phases, stop lamps and rolling sound. No recorded player events, optic waveforms or reel outcomes';rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;ranges=$ranges}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $root 'evidence/mpu4/maps/dice-motion-data.json')}
[ordered]@{classification=$(if($PaidSpin){'Natural paid-spin61D5 through cleanup; per-service clock and generated-optic reference; selected TailWindow, not a Live replay input source'}elseif($Result){'Natural physical three-nudge sequence and automatic improvement; canonical ordinals exclude typed scheduler-list and local-release dispatches; native observations are reference only'}elseif($Sequence){'Natural square22 three physical Nudge1 requests; all native observations including idle services retained; reference only'}elseif($Nudge){'Natural square22 Nudge1 motion; physical TAKE/Nudge1, native observations are reference only'}else{'Natural square-7 roll. Native motion states and external optic reads are reference evidence, not a Live input source'});source_run=$RunDirectory;raw_sha256=(Get-FileHash (Join-Path $RunDirectory 'debug.log')).Hash;independent=$independent;rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;ram_hex=[Convert]::ToHexString([IO.File]::ReadAllBytes((Join-Path $RunDirectory $(if($PaidSpin){'tail-entry-ram.bin'}else{'boundary-ram.bin'}))));ranges=$ranges;events=@($events.ToArray())}|ConvertTo-Json -Depth 5 -Compress|Set-Content (Join-Path $target ($stem+'.json'))
Copy-Item (Join-Path $RunDirectory 'debugger.cmd') (Join-Path $target ($stem+'-debugger.cmd'))
if($Nudge -and !$Sequence -and !$PaidSpin){
 $rows=Import-Csv (Join-Path $RunDirectory 'motor-states.csv');$initial=[Convert]::FromHexString($events[0].records)
 $seed=$rows|Where-Object {$_.square -eq '22' -and $_.busy -eq '0' -and [int]$_.native0 -eq $initial[24] -and [int]$_.native1 -eq $initial[26] -and [int]$_.native2 -eq $initial[28] -and [int]$_.native3 -eq $initial[30]}|Select-Object -First 1
 if(!$seed){throw 'Missing nudge-entry device motor seed'}
 [ordered]@{classification='Read-only MAME device state at matching natural idle square22 positions; phase/position seed, not machine startup';source_sha256=(Get-FileHash (Join-Path $RunDirectory 'motor-states.csv')).Hash;items_sha256=(Get-FileHash (Join-Path $RunDirectory 'motor-items.txt')).Hash;seed=$seed}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $target 'nudge-motor-seed.json')
}
if($HardwareRunDirectory) {
 $rows=Import-Csv (Join-Path $HardwareRunDirectory 'motor-states.csv');$seeds=[Collections.Generic.List[object]]::new()
 $board=Get-Content (Join-Path $target 'board-selection.json') -Raw|ConvertFrom-Json;$boardRam=[Convert]::FromHexString($board.ram_hex)
 foreach($entry in @(@(7,24,90,6,56),@(32,$boardRam[0x168],$boardRam[0x16A],$boardRam[0x16C],$boardRam[0x16E]))) {
  $row=$rows | Where-Object { $_.square -eq $entry[0] -and $_.busy -eq '0' -and [int]$_.native0 -eq $entry[1] -and [int]$_.native1 -eq $entry[2] -and [int]$_.native2 -eq $entry[3] -and [int]$_.native3 -eq $entry[4]} | Select-Object -First 1
  if(!$row){throw 'Missing feature-entry motor seed'};$seeds.Add($row)
 }
 [ordered]@{classification='Read-only MAME device saved-item observations at matching idle feature-entry positions. Establishes motor coordinate/phase seed, not full startup';source_run=$HardwareRunDirectory;source_sha256=(Get-FileHash (Join-Path $HardwareRunDirectory 'motor-states.csv')).Hash;items_sha256=(Get-FileHash (Join-Path $HardwareRunDirectory 'motor-items.txt')).Hash;seeds=@($seeds.ToArray())}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $target 'dice-motor-seeds.json')
}
Write-Output ('Curated '+$events.Count+' native observations')

param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath,[Parameter(Mandatory=$true)][string]$MameExecutable)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash'
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0' -or (Select-String "$RunDirectory/debug.log" -Pattern '^Error ' -Quiet)){throw 'Invalid callback capture'}
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath);$cases=@(Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json);$rows=[Collections.Generic.List[object]]::new();$current=$null
function Fields($line){$f=@{};foreach($m in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){if($m.Groups[1].Value -eq 'bytes'){$f.bytes=$m.Groups[2].Value}else{$f[$m.Groups[1].Value]=[Convert]::ToUInt64($m.Groups[2].Value,16)}};return $f}
foreach($line in [IO.File]::ReadLines("$RunDirectory/debug.log")){
 if($line -notmatch '^(CS|CI|CF) '){continue};$kind=$Matches[1];$f=Fields $line
 if($kind -eq 'CS'){if($null -ne $current -or $f.id -ne $rows.Count){throw 'Unordered cases'};$current=[ordered]@{case=$cases[$f.id];start_cycle=$f.cycle;instructions=[Collections.Generic.List[object]]::new()}}
 if($null -eq $current -or $f.id -ne $current.case.id){throw 'Missing active case'}
 if($kind -eq 'CF'){
  if($f.pc -ne 0x800 -or $f.s -ne 0x702 -or $f.y -ne 0x2345 -or $f.u -ne 0x3456){throw 'Unexpected native callback return/register frame'}
  $current.end=$f;$rows.Add($current);$current=$null;continue
 }
 $bytes=[Convert]::FromHexString($f.bytes);if($bytes.Length -ne 5){throw 'Missing ROM context'};for($k=0;$k -lt 5;$k++){if($bytes[$k] -ne $rom[$f.pc+$k]){throw 'ROM bytes differ'}}
 $current.instructions.Add([ordered]@{pc=$f.pc;cycle=$f.cycle;context_hex=$f.bytes})
}
if($rows.Count -ne 18 -or $cases.Count -ne 18 -or $null -ne $current){throw 'Incomplete18-case callback matrix'}
$bus=@(Import-Csv "$RunDirectory/lamp-writes.csv");$used=0
foreach($row in $rows){
 $writes=@(foreach($b in $bus){$cycle=[ulong][decimal]::Round(([decimal]$b.seconds*1000000000000000000d+[decimal]$b.attoseconds)*1720000d/1000000000000000000d);if($cycle -ge $row.start_cycle -and $cycle -lt $row.end.cycle){[ordered]@{cycle=$cycle;pc=[Convert]::ToInt32($b.pc,16);address=[Convert]::ToInt32($b.address,16);value=[Convert]::ToInt32($b.data,16);seconds=$b.seconds;attoseconds=$b.attoseconds}}})
 if($writes.Count -ne $(if($row.case.blank){3}else{2})){throw 'Unexpected write count'};$row.writes=$writes;$used+=$writes.Count
}
if($used -ne $bus.Count -or $used -ne 45){throw 'Unassigned or missing bus write'}
[ordered]@{classification='18 synthetic original-ROM callback calls, IRQ/FIRQ masked, injected RAM and transient PIA DDR/latch state.45 effective bus writes; no natural full-machine or preemption claim.';rows=@($rows.ToArray());provenance=[ordered]@{source_run=$RunDirectory;log_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash;bus_sha256=(Get-FileHash "$RunDirectory/lamp-writes.csv").Hash;commands_sha256=(Get-FileHash "$RunDirectory/debugger.cmd").Hash;observer_sha256=(Get-FileHash "$RunDirectory/lamp-writes.lua").Hash;rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;mame_sha256=(Get-FileHash $MameExecutable).Hash;natural_service_fixture_sha256=(Get-FileHash "$target/ptm-service-timing.json").Hash}}|ConvertTo-Json -Depth 8 -Compress|Set-Content "$target/lamp-callback-timing.json"
Copy-Item "$RunDirectory/lamp-writes.lua" "$target/lamp-callback-writes.lua"
Write-Output 'Curated18 callback paths/45 effective bus writes'

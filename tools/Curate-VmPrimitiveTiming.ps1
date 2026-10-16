param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash'
$prior=Get-Content "$target/ptm-instruction-boundaries-verification.json" -Raw|ConvertFrom-Json
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0' -or (Get-FileHash "$RunDirectory/ptm-instructions.csv").Hash -ne $prior.instructions_sha256){throw 'Use accepted instruction stream'}
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath);$ops=@(Import-Csv "$RunDirectory/ptm-instructions.csv"|Where-Object {$_.event -eq 'opcode'})
function Cycle($r){[ulong][decimal]::Round(([decimal]$r.seconds*1000000000000000000d+[decimal]$r.attoseconds)*1720000d/1000000000000000000d)-1}
$tokens=@{ '78B7'=0x78B5; '795D'=0x795B; '7965'=0x7963; '7931'=0x792F }
$samples=[Collections.Generic.List[object]]::new();$interrupted=0
$starts=@(for($i=0;$i -lt $ops.Count;$i++){if($ops[$i].address -eq '00FC'){$i}})
for($n=0;$n -lt $starts.Count-1;$n++){
 $start=$starts[$n];$end=$starts[$n+1];$entry=$ops[$start+2].address
 if($ops[$start+1].address -ne '00FE' -or !$tokens.ContainsKey($entry)){continue}
 if(@($ops[$start..($end-1)]|Where-Object {$_.address -eq 'FE70'}).Count){$interrupted++;continue}
 $token=$tokens[$entry]
 if(($rom[$token]*256+$rom[$token+1]) -ne [Convert]::ToInt32($entry,16)){throw 'Token header differs'}
 $instructions=@(for($i=$start;$i -lt $end;$i++){
  $r=$ops[$i];$pc=[Convert]::ToInt32($r.address,16);$bytes=[Convert]::FromHexString($r.bytes)
  if($pc -ge 0x1400){for($k=0;$k -lt 5;$k++){if($bytes[$k] -ne $rom[$pc+$k]){throw 'ROM context differs'}}}
  [ordered]@{pc=$pc;context_hex=$r.bytes;cycle=(Cycle $r);completion_cycle=(Cycle $ops[$i+1])}
 })
 $samples.Add([ordered]@{token=$token;header_hex=[Convert]::ToHexString($rom[$token..($token+1)]);start_cycle=(Cycle $ops[$start]);end_cycle=(Cycle $ops[$end]);instructions=$instructions})
}
[ordered]@{classification='Natural uninterrupted selected VM primitive paths. Native five-byte contexts and token headers checked against original ROM; RAM NEXT observed, not a ROM listing. Interrupted and incomplete paths excluded, not fitted.';source_run=$RunDirectory;instructions_sha256=$prior.instructions_sha256;rom_sha1=(Get-FileHash $RomPath -Algorithm SHA1).Hash;excluded_interrupted=$interrupted;initial_partial_next_excluded=$true;final_open_next_excluded=$true;samples=@($samples.ToArray())}|ConvertTo-Json -Depth 8|Set-Content "$target/vm-primitive-timing.json"
Write-Output "Curated $($samples.Count) uninterrupted primitive paths; $interrupted interrupted excluded"
$gateways=[Collections.Generic.List[object]]::new();$gatewayInterrupted=0
for($n=0;$n -lt $starts.Count-1;$n++){
 $start=$starts[$n];$end=$starts[$n+1]
 if($ops[$start+1].address -ne '00FE' -or $ops[$start+2].address -ne '00F8'){continue}
 if(@($ops[$start..($end-1)]|Where-Object {$_.address -eq 'FE70'}).Count){$gatewayInterrupted++;continue}
 $instructions=@(for($i=$start;$i -lt $end;$i++){
  $r=$ops[$i]
  [ordered]@{pc=[Convert]::ToInt32($r.address,16);context_hex=$r.bytes;cycle=(Cycle $r);completion_cycle=(Cycle $ops[$i+1])}
 })
 $gateways.Add([ordered]@{start_cycle=(Cycle $ops[$start]);end_cycle=(Cycle $ops[$end]);instructions=$instructions})
}
[ordered]@{classification='Natural complete uninterrupted RAM NEXT/threaded-call gateway boundaries. All bytes observed in RAM, not a ROM listing. Token membership is independently ROM-header checked in maps/dice-request-data.json; this stream does not observe token identities.';instructions_sha256=$prior.instructions_sha256;excluded_interrupted=$gatewayInterrupted;samples=@($gateways.ToArray())}|ConvertTo-Json -Depth 8|Set-Content "$target/vm-call-gateway-timing.json"
Write-Output "Curated $($gateways.Count) gateway paths; $gatewayInterrupted interrupted excluded"

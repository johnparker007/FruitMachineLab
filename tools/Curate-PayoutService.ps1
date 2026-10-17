param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$target="$PSScriptRoot/../evidence/mpu4/collection"
$provenance=Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json
$stem=if($provenance.collect_gate){'collect-gate-matrix'}elseif($provenance.collection){'router-matrix'}else{'service-matrix'}
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0'){throw 'Incomplete matrix'}
$log=[IO.File]::ReadAllText("$RunDirectory/debug.log")
if($log -match '(?mi)^Error in (?:assignment )?expression:'){throw 'Debugger expression error'}
$rows=@(foreach($case in (Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json)) {
 $hex=$case.id.ToString('X2');$exitPattern=if($provenance.collect_gate){' pc=4C34 u=05FE result=([0-9A-F]{4})\s*$'}else{' pc=4C34 u=0600\s*$'}
 if($log -notmatch ('(?m)^PF id='+$hex+$exitPattern)){throw 'Incorrect native exit'}
 $result=if($provenance.collect_gate){[Convert]::ToInt32($Matches[1],16)}else{$null}
 $before=[IO.File]::ReadAllBytes("$RunDirectory/$($case.name)-before.bin");$after=[IO.File]::ReadAllBytes("$RunDirectory/$($case.name)-after.bin")
 if($before.Length -ne 2048 -or $after.Length -ne 2048){throw 'Wrong snapshot length'}
 $writes=@([regex]::Matches($log,'(?m)^PO id='+$hex+' value=([0-9A-F]{2})\s*$')|ForEach-Object {[Convert]::ToInt32($_.Groups[1].Value,16)})
 $debits=@([regex]::Matches($log,'(?m)^PD id='+$hex+' record=([0-9A-F]{4}) balance=([0-9A-F]{4})\s*$')|ForEach-Object {[ordered]@{record=[Convert]::ToInt32($_.Groups[1].Value,16);balance=[Convert]::ToInt32($_.Groups[2].Value,16)}})
 if($writes.Count -ne 2*$debits.Count){throw 'Unpaired outputs in selected fixture'}
 [ordered]@{case=$case;result=$result;before_hex=[Convert]::ToHexString($before);after_hex=[Convert]::ToHexString($after);triac_writes=$writes;debits=$debits}
})
$expected=if($provenance.collect_gate){32}else{16};if($rows.Count -ne $expected){throw "Expected$expected cases"}
[ordered]@{classification='Synthetic original-ROM native payout orAA2B collection router with7172 wait calls explicitly skipped by debugger RTS7199; IRQ masked. Selected RAM/debit/output comparisons, not natural scheduling or physical delivery evidence.';rows=$rows;capture=$provenance;raw_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash}|ConvertTo-Json -Depth 8|Set-Content "$target/$stem.json"
Copy-Item "$RunDirectory/debugger.cmd" "$target/$stem-debugger.cmd"
Write-Output "Curated$expected original-ROM $stem experiments (explicit skipped waits)"

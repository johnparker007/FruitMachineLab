param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash'
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0'){throw 'Incomplete matrix process'}
$log=Get-Content "$RunDirectory/debug.log" -Raw
if($log -match '(?m)^Error in expression:'){throw 'Debugger expression error'}
$rows=[Collections.Generic.List[object]]::new()
foreach($case in (Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json)){
 $match=[regex]::Match($log,('(?ms)^CASE '+$case.id+'\r?$\n(.*?)^DONE '+$case.id+'\r?$'))
 if(!$match.Success){throw 'Missing matrix return'}
 $lamps=[Collections.Generic.List[object]]::new()
 foreach($lamp in [regex]::Matches($match.Groups[1].Value,'(?m)^SL id=([0-9A-F]{2}) pattern=([0-9A-F]{2})')){$lamps.Add([int[]]@([Convert]::ToByte($lamp.Groups[1].Value,16),[Convert]::ToByte($lamp.Groups[2].Value,16)))}
 if($lamps.Count -lt 2){throw 'Incomplete lamp observations'}
 $rows.Add([ordered]@{setup=$case;before_hex=[Convert]::ToHexString([IO.File]::ReadAllBytes("$RunDirectory/$($case.id)-before.bin"));lamps=@($lamps.ToArray())})
}
[ordered]@{classification='Synthetic isolated482F branch matrix; compares ordered lamp calls, not full native stack or physical lamp delivery';cases=@($rows.ToArray());capture=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);raw_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash}|ConvertTo-Json -Depth 7|Set-Content "$target/status-matrix.json"
Copy-Item "$RunDirectory/debugger.cmd" "$target/status-matrix-debugger.cmd"

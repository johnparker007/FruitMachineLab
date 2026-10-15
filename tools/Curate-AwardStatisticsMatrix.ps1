param([Parameter(Mandatory=$true)][string]$RunDirectory,[switch]$Scaled)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash';$stem=if($Scaled){'scaled-accounting-matrix'}else{'award-statistics-matrix'}
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0'){throw 'Incomplete matrix process'}
$log=[IO.File]::ReadAllText("$RunDirectory/debug.log")
if($log -match '(?m)^Error in expression:'){throw 'Debugger expression error'}
$rows=[Collections.Generic.List[object]]::new()
foreach($case in (Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json)){
 $before=[IO.File]::ReadAllBytes("$RunDirectory/$($case.id)-before.bin");$after=[IO.File]::ReadAllBytes("$RunDirectory/$($case.id)-after.bin")
 if($before.Length -ne 2048 -or $after.Length -ne 2048 -or $log -notmatch ('(?m)^MATRIX '+$case.id+' ')){throw 'Incomplete case'}
 if($Scaled -and $log -notmatch ('(?m)^MATRIX '+$case.id+' pc=(1571|1568)\s*$')){throw 'Unexpected scaled-counter exit boundary'}
 $rows.Add([ordered]@{id=$case.id;global=$case.global;amount=$case.amount;selector=$case.selector;mode=$case.mode;scaled=[bool]$Scaled;alarm65=($log -match ('(?m)^MATRIX '+$case.id+' pc=1568'));expected_accounting_hex=[Convert]::ToHexString([byte[]]$after[0x7C9..0x7E7]);before_hex=[Convert]::ToHexString($before);expected_low_ram_sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([byte[]]$after[0..0x6FF]))})
}
[ordered]@{classification=$(if($Scaled){'Synthetic native151F unsigned24 multiply, signed overflow clamp before alarm, mode-gated complement/checksum'}else{'Synthetic isolated native1622/166D matrix; unsigned24 carry/wrap, selector0 alias, low-byte selector and signed mode gate'});compared_ram_end_exclusive=0x700;excluded=$(if($Scaled){'Native S-stack residue excluded; accounting07C9..07E7 separately compared in expected_accounting_hex'}else{'Native S-stack residue 0700..07FF; selectors confined to non-stack RAM'});cases=@($rows.ToArray());capture=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);raw_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash}|ConvertTo-Json -Depth 6|Set-Content "$target/$stem.json"
Copy-Item "$RunDirectory/debugger.cmd" "$target/$stem-debugger.cmd"

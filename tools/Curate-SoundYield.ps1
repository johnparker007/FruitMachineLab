param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath,[ValidateSet('yield','child','instrument','service','note','noteservice','callservice','rhythm','prompt','queue','reset','serial-reply','serial-transfer','serial-frame')][string]$Operation='yield')
$ErrorActionPreference='Stop';if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0'){throw 'Incomplete capture'}
if((Get-FileHash $RomPath -Algorithm SHA1).Hash -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Wrong ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath);$cases=@(Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json);$rows=[Collections.Generic.List[object]]::new();$catalog=[Collections.Generic.List[object]]::new();$indexes=@{};$active=$null;$id=0
$entry=switch($Operation){yield{0x5CF3} child{0x5EE3} instrument{0x5F5B} service{0x5CD0} note{0x5D48}};$end=switch($Operation){yield{0x5CDE} service{0x4C34} default{0x5D3B}};$stack=if($Operation -in @('yield','service')){0x702}else{0x700};$count=if($Operation -in @('child','service')){32}else{48}
if($Operation -eq 'noteservice'){$entry=0x5CD0;$end=0x4C34;$stack=0x702;$count=96}
if($Operation -eq 'callservice'){$entry=0x5CD0;$end=0x4C34;$stack=0x702;$count=24}
if($Operation -eq 'rhythm'){$entry=0x5D48;$count=120}
if($Operation -eq 'prompt'){$entry=0x5CD0;$end=0x4C34;$stack=0x702;$count=128}
if($Operation -eq 'queue'){$entry=0x5C18;$end=0x4C34;$stack=0x702;$count=32}
if($Operation -eq 'reset'){$entry=0x5B77;$end=0x4C34;$stack=0x702;$count=32}
if($Operation -eq 'serial-reply'){$entry=0x53AE;$end=0x4C34;$stack=0x702;$count=32}
if($Operation -eq 'serial-transfer','serial-frame'){$entry=0x5330;$end=0x4C34;$stack=0x702;$count=32}
if($Operation -eq 'serial-frame'){$entry=0x51B1;$end=0x4C34;$stack=0x702;$count=32}
foreach($line in Get-Content "$RunDirectory/debug.log"){
if($line -match '(?i)^error '){throw 'Debugger error'};if($line -notmatch '^O([SIF]) '){continue};$kind=$Matches[1];$f=[ordered]@{};foreach($match in [regex]::Matches($line,'([a-z]+)=([0-9A-F]+)')){if($match.Groups[1].Value -ne 'bytes'){$f[$match.Groups[1].Value]=[Convert]::ToUInt64($match.Groups[2].Value,16)}}
if($kind -eq 'S'){if($null -ne $active -or $f.pc -ne $entry){throw 'Wrong start'};$active=[ordered]@{case=$cases[$id];start_cycle=$f.cycle;steps=[Collections.Generic.List[object]]::new()}}
elseif($kind -eq 'I'){if($null -eq $active -or $line -notmatch 'bytes=([0-9A-F]{10})'){throw 'Missing instruction'};$hex=$Matches[1];$pc=[int]$f.pc;if([Convert]::ToHexString($rom[$pc..($pc+4)]) -ne $hex){throw 'ROM context differs'};if(!$indexes.ContainsKey($pc)){$indexes[$pc]=$catalog.Count;$catalog.Add([ordered]@{pc=$pc;context_hex=$hex})};$active.steps.Add(@($indexes[$pc],($f.cycle-$active.start_cycle)))}
else{if($Operation -in @('note','rhythm')){$end=if($cases[$id].note -ge 0x60){0x5CDE}else{0x5D3B};$stack=0x700};if($null -eq $active -or $f.pc -ne $end -or $f.s -ne $stack){throw 'Wrong return'};$active['cycles']=$f.cycle-$active.start_cycle;$active['end']=$f;foreach($side in @('before','after')){$ram=[IO.File]::ReadAllBytes("$RunDirectory/operation-$id-$side.bin");if($ram.Length -ne 2048){throw 'Wrong RAM'};$active["${side}_hex"]=[Convert]::ToHexString($ram)};$rows.Add($active);$active=$null;$id++}}
if($null -ne $active -or $rows.Count -ne $count){throw 'Incomplete matrix'}
$spans=@();switch($Operation){yield{$spans+=,@(0x5CF3,0x5D37)} child{$spans=@(@(0x5EE3,0x5F14),@(0x5C51,0x5C79),@(0x8787,0x8788))} instrument{$spans=@(@(0x5F5B,0x5F81),@(0x60AB,0x60BE),@(0x5A1E,0x5C1D))} service{$spans=@(@(0x5C18,0x60E0),@(0x5963,0x5C17))}}
if($Operation -in @('note','rhythm')){$spans=@(@(0x5CF3,0x5E2B),@(0x60AB,0x60BE),@(0x5A1E,0x5AE2))}
if($Operation -in @('noteservice','callservice','rhythm','prompt','queue','reset','serial-reply','serial-transfer','serial-frame')){$spans=@(@(0x5C18,0x60E0),@(0x5963,0x5C17),@(0x8739,0x879E))}
if($Operation -eq 'queue'){$spans=@(@(0x5C18,0x5C79),@(0x60C8,0x60D5))}
if($Operation -eq 'reset'){$spans=@(@(0x5B77,0x5C17),@(0x60AB,0x60D5))}
if($Operation -eq 'serial-reply'){$spans=@();$spans+=,@(0x53AE,0x5428)}
if($Operation -eq 'serial-transfer','serial-frame'){$spans=@();$spans+=,@(0x5330,0x5428)}
if($Operation -eq 'serial-frame'){$spans=@(@(0x51B1,0x5283),@(0x5744,0x5753),@(0x6917,0x6918),@(0xFF44,0xFF44))}
$regions=@(foreach($span in $spans){[ordered]@{address=$span[0];bytes_hex=[Convert]::ToHexString($rom[$span[0]..$span[1]])}})
$stem=if($Operation -like 'serial-*'){$Operation}else{"sound-$Operation"};$target="$PSScriptRoot/../evidence/mpu4/collection/$stem"
[ordered]@{classification='Synthetic original-ROM instruction/RAM paths, no natural service cadence';catalog=@($catalog.ToArray());rows=@($rows.ToArray());rom_regions=$regions;capture=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);raw_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash}|ConvertTo-Json -Depth 9|Set-Content "$target.json";Copy-Item "$RunDirectory/debugger.cmd" "$target-debugger.cmd"

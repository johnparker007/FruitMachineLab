param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RomPath)
$ErrorActionPreference='Stop'
function Hash([string]$p,[string]$alg='SHA256'){$h=[Security.Cryptography.HashAlgorithm]::Create($alg);([BitConverter]::ToString($h.ComputeHash([IO.File]::ReadAllBytes($p)))-replace '-','')}
function Hex([byte[]]$b){([BitConverter]::ToString($b)-replace '-','')}
function HashBytes([byte[]]$b){$h=[Security.Cryptography.SHA256]::Create();([BitConverter]::ToString($h.ComputeHash($b))-replace '-','')}
$target="$PSScriptRoot/../evidence/mpu4/collection";if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0'){throw 'Capture incomplete'};if((Hash $RomPath 'SHA1') -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath)
$names=@('queue','service1','service2','cancel');$rows=[Collections.Generic.List[object]]::new();$active=@{}
foreach($line in (Get-Content "$RunDirectory/debug.log")){
 if($line -notmatch '^(PH|PE|OI) '){continue}
 $fields=@{};foreach($m in [regex]::Matches($line,'([a-z0-9_]+)=([0-9A-F]+)')){$fields[$m.Groups[1].Value]=[Convert]::ToUInt64($m.Groups[2].Value,16)}
 if($line.StartsWith('PH ')){$id=[int]$fields.id;if($id -ne $rows.Count){throw 'Unexpected phase id'};$active=[ordered]@{id=$id;name=$names[$id];start_cycle=$fields.cycle;instructions=[Collections.Generic.List[object]]::new()};continue}
 if($line.StartsWith('OI ')){if($null -eq $active -or [int]$fields.id -ne $active.id){throw 'Mismatched phase instruction'};if($line -notmatch 'bytes=([0-9A-F]{10})'){throw 'Missing context'};$pc=[int]$fields.pc;if($fields.cycle -lt $active.start_cycle){throw 'Instruction precedes phase start'};if($fields.cycle -ge $active.start_cycle+0x10000){throw 'Instruction cycle outside phase'};$active.instructions.Add([ordered]@{pc=$pc;cycle=$fields.cycle-$active.start_cycle;context_hex=$Matches[1]});continue}
 if($null -eq $active -or [int]$fields.id -ne $active.id){throw 'Mismatched phase end'}
 $id=$active.id;$active['cycles']=$fields.cycle-$active.start_cycle;$active['end']=[ordered]@{pc=$fields.pc;cycle=$fields.cycle;s=$fields.s;u=$fields.u;x=$fields.x;y=$fields.y}
 $before=[IO.File]::ReadAllBytes("$RunDirectory/tone-$id-before.bin");$after=[IO.File]::ReadAllBytes("$RunDirectory/tone-$id-after.bin");if($before.Length -ne 0x800 -or $after.Length -ne 0x800){throw 'Phase RAM is not 2KB'}
 $active['before_hex']=Hex $before;$active['after_hex']=Hex $after;$active.instructions=@($active.instructions.ToArray());$rows.Add($active);$active=@{}
}
if($rows.Count -ne 4 -or $active.Count -ne 0){throw 'Truncated tone lifecycle capture'}
if($rows[0].instructions[0].pc -ne 0x60C8 -or $rows[1].instructions[0].pc -ne 0x5CD2 -or $rows[2].instructions[0].pc -ne 0x5CD2 -or $rows[3].instructions[0].pc -ne 0x60C8){throw 'Phase entry boundary differs'}
if($rows[0].before_hex.Substring(0x47*2,4) -ne '0000' -or $rows[0].after_hex.Substring(0x47*2,4) -ne '01A0'){throw 'Queue list differs'}
if($rows[1].after_hex.Substring(0x1B3*2,4) -ne '59EB' -or $rows[1].after_hex.Substring(0x1AA*2,2) -ne '00' -or $rows[1].after_hex.Substring(0x4B*2,2) -ne '01'){throw 'Tone task did not acquire a channel'}
if($rows[2].after_hex.Substring(0x4C*2,2) -ne '05' -or $rows[3].after_hex.Substring(0x4C*2,2) -ne '00' -or $rows[3].after_hex.Substring(0x47*2,4) -ne '0000'){throw 'Cancel did not release the tone owner'}
$regions=@(
 [ordered]@{name='59EB stream and instrument data';address=0x59EB;bytes_hex=(Hex $rom[0x59EB..0x5A1F]);sha256=(HashBytes $rom[0x59EB..0x5A1F])},
 [ordered]@{name='5963 sound dispatch table';address=0x5963;bytes_hex=(Hex $rom[0x5963..(0x5963+692)]);sha256=(HashBytes $rom[0x5963..(0x5963+692)])},
 [ordered]@{name='5C18 queue cancel service dispatch';address=0x5C18;bytes_hex=(Hex $rom[0x5C18..0x5D3A]);sha256=(HashBytes $rom[0x5C18..0x5D3A])},
 [ordered]@{name='5E24 CE entry and 5E2C/5E6D release root';address=0x5E24;bytes_hex=(Hex $rom[0x5E24..0x5E8C]);sha256=(HashBytes $rom[0x5E24..0x5E8C])},
 [ordered]@{name='5EB2 C3 and 5EC6 C4';address=0x5EB2;bytes_hex=(Hex $rom[0x5EB2..0x5EE0]);sha256=(HashBytes $rom[0x5EB2..0x5EE0])},
 [ordered]@{name='5F88 C5/C6 attenuation tail';address=0x5F88;bytes_hex=(Hex $rom[0x5F88..0x5FDB]);sha256=(HashBytes $rom[0x5F88..0x5FDB])},
 [ordered]@{name='6049 D8';address=0x6049;bytes_hex=(Hex $rom[0x6049..0x6051]);sha256=(HashBytes $rom[0x6049..0x6051])},
 [ordered]@{name='608E C6 instrument table';address=0x608E;bytes_hex=(Hex $rom[0x608E..0x609B]);sha256=(HashBytes $rom[0x608E..0x609B])},
 [ordered]@{name='60AB cached write';address=0x60AB;bytes_hex=(Hex $rom[0x60AB..0x60BD]);sha256=(HashBytes $rom[0x60AB..0x60BD])},
 [ordered]@{name='60C8 disabled gate';address=0x60C8;bytes_hex=(Hex $rom[0x60C8..0x60D5]);sha256=(HashBytes $rom[0x60C8..0x60D5])}
)
[ordered]@{classification='Synthetic isolated original-ROM 59EB lifecycle: recovered reset list, native5C18 queue, two explicitly timed5CD0 service ticks, native5C7A cancel. Masked IRQ. Caller inputs are external: before each phase the harness sets PC/registers, return word0700=4C34, counter44=0, enable719B=0 and the declared 45/46 clock (0 for queue/service1, 00FF for service2). These are caller clock/ABI writes, not autonomous execution. Retained task/channel state is produced by native instructions; no other RAM is edited between phases.';source_run=$RunDirectory;raw_sha256=(Hash "$RunDirectory/debug.log");rom_sha1=(Hash $RomPath 'SHA1');provenance=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);rom_regions=$regions;rows=@($rows.ToArray())}|ConvertTo-Json -Depth 8|Set-Content "$target/tone-lifecycle.json"
[ordered]@{source_run=$RunDirectory;debug_sha256=(Hash "$RunDirectory/debug.log");debugger_sha256=(Hash "$RunDirectory/debugger.cmd");arguments_sha256=(Hash "$RunDirectory/arguments.json");seed_sha256=(Hash "$RunDirectory/seed-reset.bin");rom_sha1=(Hash $RomPath 'SHA1');provenance=(Get-Content "$RunDirectory/provenance.json" -Raw|ConvertFrom-Json);rom_regions=@($regions|ForEach-Object {[ordered]@{address=$_.address;sha256=$_.sha256}});phases=@($rows|ForEach-Object {[ordered]@{id=$_.id;name=$_.name;start_cycle=$_.start_cycle;cycles=$_.cycles;instructions=$_.instructions.Count;end=$_.end}})}|ConvertTo-Json -Depth 8|Set-Content "$target/tone-lifecycle-verification.json"
Write-Output ("Curated {0} tone lifecycle phases, {1} instructions" -f $rows.Count,($rows|ForEach-Object {$_.instructions.Count}|Measure-Object -Sum).Sum)

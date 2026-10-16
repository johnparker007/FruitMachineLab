param([Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$MameExecutable)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash'
if((Get-Content "$RunDirectory/exit-code.txt" -Raw).Trim() -ne '0' -or (Select-String "$RunDirectory/debug.log" -Pattern '^Error ' -Quiet)){throw 'Invalid capture'}
$cases=@(Get-Content "$RunDirectory/cases.json" -Raw|ConvertFrom-Json);$bus=@(Import-Csv "$RunDirectory/bus-time.csv")
if($cases.Count -ne 18 -or $bus.Count -ne 18){throw 'Incomplete18-case IRQ matrix'}
$arms=@{};$last=@{};$rows=[Collections.Generic.List[object]]::new()
foreach($line in [IO.File]::ReadLines("$RunDirectory/debug.log")){
 if($line -notmatch '^(IA|IB|IE) '){continue};$kind=$Matches[1];$f=@{}
 foreach($m in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){if($m.Groups[1].Value -eq 'frame'){$f.frame=$m.Groups[2].Value}else{$f[$m.Groups[1].Value]=[Convert]::ToUInt64($m.Groups[2].Value,16)}}
 $id=[int]$f.id;if($id -lt 0 -or $id -ge 18){throw 'Invalid case ID'}
 if($kind -eq 'IA'){$arms[$id]=$f;continue};if($kind -eq 'IB'){$last[$id]=$f;continue}
 if(!$arms.ContainsKey($id) -or !$last.ContainsKey($id) -or $id -ne $rows.Count){throw 'Unordered IRQ matrix'}
 $c=$cases[$id];$b=$last[$id];$ins=@($c.instructions|Where-Object {$_.address -eq $b.pc})
 if($b.pc -eq $c.unmask_pc){$cost=3;$resume=$c.unmask_pc+2;$cc=$b.cc -band 0xEF}
 elseif($ins.Count -eq 1){$cost=$ins[0].cycles;$resume=$ins[0].next;$cc=$b.cc;if($c.body -eq 'ldd' -and $b.pc -eq $c.instructions[0].address){$cc=($cc -band 0xF1) -bor 8}}
 else{throw 'Unknown last instruction'}
 $accepted=$b.cycle+$cost;if($f.cycle-$accepted -ne 19 -or $f.pc -ne 0xFE70){throw 'IRQ entry cost/vector differs'}
 $frame=('{0:X2}{1:X2}{2:X2}{3:X2}{4:X4}{5:X4}{6:X4}{7:X4}' -f ($cc -bor 0x80),$f.a,$f.b,$f.dp,$f.x,$f.y,$f.u,$resume)
 if($f.frame -ne $frame -or $f.s -ne 0x5F4 -or $f.cc -ne ($cc -bor 0x90)){throw 'IRQ frame differs'}
 # Exact bus time maps this isolated CPU's origin to its clock. Debugger
 # watchpoint totalcycles identifies the store's START, five cycles earlier.
 $time=[decimal]$bus[$id].seconds*1000000000000000000d+[decimal]$bus[$id].attoseconds
 $effective=[ulong][decimal]::Round($time*1720000d/1000000000000000000d)
 if($effective -ne $arms[$id].cycle+5){throw 'Bus/watchpoint qualification changed'}
 $assertion=$effective+8*($c.latch+1)
 if($accepted -lt $assertion){throw 'Accepted before calculated assertion'}
 $rows.Add([ordered]@{id=$id;latch=$c.latch;masked_nops=$c.masked_nops;body=$c.body;program_hex=$c.program_hex;release_instruction_cycle=$arms[$id].cycle;release_bus_cycle=$effective;release_seconds=$bus[$id].seconds;release_attoseconds=$bus[$id].attoseconds;calculated_first_assertion_cycle=$assertion;last_instruction_pc=$b.pc;last_instruction_cycle=$b.cycle;last_instruction_cycles=$cost;accepted_cycle=$accepted;handler_cycle=$f.cycle;resume_pc=$resume;before_cc=$cc;a=$f.a;b=$f.b;dp=$f.dp;x=$f.x;y=$f.y;u=$f.u;before_s=0x600;handler_cc=$f.cc;handler_s=$f.s;frame_hex=$frame})
}
if($rows.Count -ne 18){throw 'Incomplete IRQ matrix'}
[ordered]@{classification='Synthetic RAM programs, injected initial CPU registers, global PTM reset and selected timer3 low phase. Actual CPU accepts ordinary IRQ and enters original FE70 vector; stopped before handler. No natural gameplay equivalence.';rows=@($rows.ToArray())}|ConvertTo-Json -Depth 6|Set-Content "$target/ptm-irq-entry.json"
[ordered]@{source_run=$RunDirectory;debug_log_sha256=(Get-FileHash "$RunDirectory/debug.log").Hash;bus_csv_sha256=(Get-FileHash "$RunDirectory/bus-time.csv").Hash;debugger_sha256=(Get-FileHash "$RunDirectory/debugger.cmd").Hash;observer_sha256=(Get-FileHash "$RunDirectory/bus-time.lua").Hash;mame_sha256=(Get-FileHash $MameExecutable).Hash;cases=18;source_tag='mame0281';source_commit='2843a3deb81cf93735244044894196ccfbea4d20';entry_cycles=19;frame_bytes=12;unresolved='Timer assertion is calculated from selected clock mechanics, not a direct asynchronous IRQ-line timestamp. No canonical Skill Cash handler or nested-service timing is inferred.'}|ConvertTo-Json|Set-Content "$target/ptm-irq-entry-verification.json"
Copy-Item "$RunDirectory/bus-time.lua" "$target/ptm-irq-entry.lua"
Write-Output 'Curated18 ordinary IRQ entry/frame cases'

param([Parameter(Mandatory=$true)][string]$RomPath,[Parameter(Mandatory=$true)][string]$DisassemblyDirectory,[string]$StackRunDirectory)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
$sha1=(Get-FileHash -LiteralPath $RomPath -Algorithm SHA1).Hash
if($sha1 -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected ROM'}
$rom=[IO.File]::ReadAllBytes($RomPath);$native=[Collections.Generic.List[object]]::new();$scripts=[Collections.Generic.List[object]]::new()
foreach($name in @('nudge-motor-native.txt','nudge-result-native.txt','nudge-decrement-native.txt','nudge-stack-bridge.txt','nudge-stack-save.txt','nudge-loop-leave.txt','nudge-loop-cleanup.txt','nudge-plan-native.txt','nudge-outer-index.txt')) {
 $source=Join-Path $DisassemblyDirectory $name;$rows=[Collections.Generic.List[object]]::new()
 foreach($line in [IO.File]::ReadLines($source)) {
  if($line -notmatch '^([0-9A-F]{4}):\s+((?:[0-9A-F]{2}\s+)+)(.*)$'){if($line.Trim()){throw "Unexpected disassembly line: $line"};continue}
  $at=[Convert]::ToInt32($Matches[1],16);$hex=($Matches[2] -replace '\s','');$text=$Matches[3];$bytes=[Convert]::FromHexString($hex)
  if([Convert]::ToHexString([byte[]]$rom[$at..($at+$bytes.Length-1)]) -cne $hex){throw ('Disassembly bytes differ at '+$at.ToString('X4'))}
  $rows.Add([ordered]@{address=$at.ToString('X4');bytes=$hex;decoded=$text})
 }
 $native.Add([ordered]@{source=$name;source_sha256=(Get-FileHash -LiteralPath $source).Hash;classification='Byte-checked MAME linear disassembly; code/data typing, reachability and all function boundaries are not established by this decode';instructions=@($rows.ToArray())})
}
foreach($name in @('B31F','B306','EDB4','ED06','ED94','ECD6','AF93','AF67','AF4E','9FEF','9CB5','8560','A8F9','A7DB','A86B','E2E5','E2FC','E43D','E3E2','EDD3','EE11','EE62','FC34','B712','B652','B666','B6DB','B384','B352','B91D','E247','B72D','9ADB','B403','B43D','B3C8','9DCF','B4C5')) {
 $path=Join-Path $root ('evidence/mpu4/VM-SCRIPTS/'+$name+'.txt');$rows=[Collections.Generic.List[object]]::new()
 foreach($line in [IO.File]::ReadLines($path)) {
  if($line -match '^\*?\s*([0-9A-F]{4})\s+([0-9A-F]{4})\s+(.*)$'){
   $at=[Convert]::ToInt32($Matches[1],16);$token=$Matches[2];$annotation=$Matches[3]
   if([Convert]::ToHexString([byte[]]$rom[$at..($at+1)]) -cne $token){throw "VM token differs at $at"}
   $rows.Add([ordered]@{address=$at;token=$token;annotation=$annotation})
  }
 }
 if($rows.Count -eq 0){throw "No script rows: $name"}
 $first=$rows[0].address;$end=$rows[$rows.Count-1].address+2
 for($n=0;$n -lt $rows.Count;$n++) {
  $at=$rows[$n].address;$next=if($n+1 -lt $rows.Count){$rows[$n+1].address}else{$end}
  if($next -le $at){throw 'Non-monotonic VM listing'}
  $rows[$n].bytes_through_next_listed_site=[Convert]::ToHexString([byte[]]$rom[$at..($next-1)])
  $rows[$n].address=$at.ToString('X4')
 }
 $scripts.Add([ordered]@{listing=('VM-SCRIPTS/'+$name+'.txt');listing_sha256=(Get-FileHash -LiteralPath $path).Hash;start=$first.ToString('X4');end_exclusive=$end.ToString('X4');span_hex=[Convert]::ToHexString([byte[]]$rom[$first..($end-1)]);classification='Exact selected ROM span and checked listed tokens; gaps/operands/embedded data preserved verbatim. Span partition does not prove each decoded operand or relocation semantics. Last return token span ends after two bytes.';sites=@($rows.ToArray())})
}
$functions=[Collections.Generic.List[object]]::new()
foreach($address in @('61f6','6287','6403','649d','656b','77a8','4a8c','4a90','7a02')) {
 $relative='native/'+$address+'.json';$path=Join-Path $root ('evidence/mpu4/'+$relative)
 if(Test-Path -LiteralPath $path){$record=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json;$functions.Add([ordered]@{entry=$address.ToUpper();label=$record.name;existing_export=$relative;export_sha256=(Get-FileHash -LiteralPath $path).Hash;exported_body_size=$record.body_size;qualification='Ghidra recovered function body size is retained, not assumed to be a contiguous extent or complete calling convention'})}
}
$loopRecord=[ordered]@{address='7A15';bytes=[Convert]::ToHexString([byte[]]$rom[0x7A15..0x7A1B]);header='7A17';native='7A17';stack_effect='Data stack unchanged; removes current eight-byte loop frame at S, restores F6 from S+6';effects='LDY ,Y reads absolute inline target; BRA 7A0D performs loop removal and NEXT; B42D operand B433 is byte-checked in the B403 VM span'}
$stackEvidence=$null
if($StackRunDirectory) {
 $path=Join-Path $StackRunDirectory 'debug.log';$writes=[Collections.Generic.List[object]]::new()
 foreach($line in [IO.File]::ReadLines($path)) {
  if($line -notmatch '^NS '){continue};$row=[ordered]@{}
  foreach($match in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$row[$match.Groups[1].Value]=$match.Groups[2].Value}
  $writes.Add($row)
 }
 if($writes.Count -eq 0){throw 'No stack observations'}
 $last=@($writes.ToArray()|Where-Object {$_.address -eq '078D'})[-1]
 if($last.pc -ne '4A8E' -or $last.value -ne '8F'){throw 'Unexpected final local+2 producer'}
 $stackEvidence=[ordered]@{classification='Natural read-only nine-byte watchpoint capture; address-specific proof for this entry shape, not a general CPU-stack model';source_run=$StackRunDirectory;raw_sha256=(Get-FileHash -LiteralPath $path).Hash;writes=@($writes.ToArray());last_local2_write=$last;producer='Native4A8C PSHS PC,Y,D after gateway77A8. VM S0796 -> saved D at078C, its low pattern byte078D later becomes frame078B+2.';consumer='B339/B33B reads local+2; B33D tests it. No initialization is inserted.';implementation='src/FruitMachineLab.Runtime/Mpu4LampRequests.cs','src/FruitMachineLab.Adders/AddersNudgeAvailability.cs';verification='Natural nudge-return canonical VM digest plus focused save-area/frame-reuse test'}
}
[ordered]@{rom_sha1=$sha1;native_stack_evidence=$stackEvidence;functions=@($functions.ToArray());calling_conventions=[ordered]@{native_motion="61F6 accepts requests at0169+2*reel, caller VM U/Y retained; motor service is IRQ-driven; synchronous bit08 path remains unsupported";service="6403 mutates reel records0150..019F and phase/drive state, reads optics via656B; cleanup649D updates positions and NVRAM complements/checksum";vm="B31F runs within B72D nine-byte local frame and B403 loop frame; B306 consumes BE and BF when BD=15hex; preserves local+2 lamp-pattern residue before reading it"};scope='Selected current nudge recovery checkpoint, not a lossless full-ROM listing or rebuild';native=@($native.ToArray());vm=@($scripts.ToArray());dictionary_records=@([ordered]@{address='7A26';label='vm_push_outer_loop_index';bytes=[Convert]::ToHexString([byte[]]$rom[0x7A26..0x7A30]);header='7A28';native='7A28';stack_effect='( -- outer-loop-index )';effects='LDX direct F6; LDD [6,X]; PSHU D; JMP direct FC. Follows the saved outer F6 pointer, not a fixed host loop depth'},[ordered]@{address='8084';label='push_best_reel_search_movement_triplet_with_symbols_restored';bytes=[Convert]::ToHexString([byte[]]$rom[0x8084..0x8087]);native='2A2F';stack_effect='( budget -- reel1-moves reel2-moves reel3-moves ), reel3 on top';effects='Consumes low budget byte, allocates seventeen-byte U scratch frame via6FA2, calls2A7F, ASRB/SEX returns signed movement cells, restores symbols0160/0162/0164, leaves DD unchanged';implementation='src/FruitMachineLab.Adders/AddersNudgeAvailability.cs';verification='skill-cash/nudge-plan-matrix.json'},$loopRecord,[ordered]@{address='82BB';bytes=[Convert]::ToHexString([byte[]]$rom[0x82BB..0x82BE]);header='794F';value='0170';stack_effect='( -- 0170 )';effects='Word literal used by 9DCD indexed reel mode-byte writes'},[ordered]@{address='7659';bytes=[Convert]::ToHexString([byte[]]$rom[0x7659..0x765E]);header='765B';native='765B';stack_effect='( byte-address -- )';effects='DEC [,U++]; 8-bit wrap, address cell consumed; JMP direct FC threaded NEXT'});related_maps=@('nudge-inputs.json','nudge-preparation-semantics.json','nudge-preparation-data.json','dice-motion-data.json');implementation=@('src/FruitMachineLab.Adders/AddersReelMotion.cs','src/FruitMachineLab.Adders/AddersReelHardware.cs','src/FruitMachineLab.Adders/SkillCashLiveSession.cs','src/FruitMachineLab.Runtime/Mpu4LampRequests.cs','src/FruitMachineLab.Adders/AddersNudgeAvailability.cs','src/FruitMachineLab.Runtime/VmControlStack.cs','src/FruitMachineLab.Runtime/RecoveredScript.cs');verification=@('skill-cash/nudge-request.json','skill-cash/dice-motion.json','skill-cash/nudge-motion-native.json','skill-cash/nudge-motion-vm.json','skill-cash/nudge-return.json','skill-cash/nudge-result.json','skill-cash/nudge-exit.json','skill-cash/nudge-win-transfer.json','skill-cash/nudge-tail.json','skill-cash/nudge-result-native.json','skill-cash/nudge-plan-matrix.json');layout_constraints=@('16-bit big-endian cells and absolute pointers remain address-bound','VM dictionary headers and native gateways must retain their original entry addresses unless every reference is relocated','Branch/inline token bytes and embedded alpha operands remain preserved at current addresses');unresolved=@('B339/B33B local+2 reads a reused lamp save-area byte: 4A8C saved D at VM S-10 via gateway77A8; translated selected save area now retained. Full native CPU-stack footprints remain incomplete','Full ROM coverage, symbolic operand recovery and data/code typing','Portable Ghidra comments, symbol namespaces, data definitions and complete cross-reference export: no live Ghidra API exposed in this session','Reassembly, relocation and byte-identical baseline rebuild have not been implemented')}|ConvertTo-Json -Depth 9|Set-Content (Join-Path $root 'evidence/mpu4/maps/nudge-encoding-checkpoint.json')

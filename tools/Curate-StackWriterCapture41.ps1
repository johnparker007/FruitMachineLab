param(
    [string]$RunDirectory='artifacts/deepseek/capture-41/natural-stack-writer',
    [string]$RomPath='E:\Arcade\MAME0266\roms\m4addr.zip',
    [string]$MamePath='E:\Arcade\MAME0266\mame281.exe',
    [string]$SourceRun='artifacts/deepseek/gate-28/natural-service',
    [string]$FixturePath='evidence/mpu4/collection/stack-writer-0785-capture41.json',
    [string]$PriorCapture36Fixture='evidence/mpu4/collection/matched-service-window-capture36.json',
    [string]$PriorCapture36Run='artifacts/deepseek/capture-36/natural-service'
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath("$PSScriptRoot/..")
function Abs([string]$p){if([IO.Path]::IsPathRooted($p)){[IO.Path]::GetFullPath($p)}else{[IO.Path]::GetFullPath((Join-Path $root $p))}}
function HashBytes([byte[]]$bytes,[string]$algorithm='SHA256'){([BitConverter]::ToString([Security.Cryptography.HashAlgorithm]::Create($algorithm).ComputeHash($bytes))-replace '-','')}
function HashFile([string]$p,[string]$algorithm='SHA256'){HashBytes ([IO.File]::ReadAllBytes($p)) $algorithm}
function Fields([string]$line){$f=[ordered]@{};foreach($m in [regex]::Matches($line,'([A-Za-z0-9]+)=([0-9A-F]+)')){$f[$m.Groups[1].Value]=$m.Groups[2].Value};return $f}
function ReadRam([string]$name){$p=Join-Path $run $name;if(!(Test-Path -LiteralPath $p)){throw "Missing $name"};$b=[IO.File]::ReadAllBytes($p);if($b.Length -ne 0x800){throw "Non-2KB $name"};return ,$b}
function ByteAt([byte[]]$ram,[int]$offset){if($offset -lt 0 -or $offset -ge $ram.Length){throw ("Offset {0:X} outside 2KB" -f $offset)};return $ram[$offset].ToString('X2')}
function Num([string]$s){[Convert]::ToInt32($s,16)}
function WordNum([byte[]]$ram,[int]$offset){if($offset -lt 0 -or $offset+1 -ge $ram.Length){throw ("Word offset {0:X} outside 2KB" -f $offset)};return (([int]$ram[$offset] -shl 8) -bor [int]$ram[$offset+1])}
function WordAt([byte[]]$ram,[int]$offset){WordNum $ram $offset|ForEach-Object{$_.ToString('X4')}}

$run=Abs $RunDirectory
$rom=Abs $RomPath
$mame=Abs $MamePath
$source=Abs $SourceRun
$target=Abs $FixturePath
$priorFixture=Abs $PriorCapture36Fixture
$priorRun=Abs $PriorCapture36Run
foreach($p in @($run,$rom,$mame,$source,$priorFixture,$priorRun)){if(!(Test-Path -LiteralPath $p)){throw "Missing $p"}}

$mameExpected='0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A'
$romZipExpected='E2553AFA6B8E9DEF55BD920E4BED77A4324696C1E358B73BE70BFD2C58179989'
$romSha1Expected='402D1518BB78FDC489B06C2AABC771E5CE151847'
$sourceInputExpected='7C664323A5725E9FB294CB201B17B855564AF2E4A500560ED499F1EE45179D0D'
$sourceReplayExpected='4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D'
$derivedInputExpected='BC93C0699861A2B3DE402489DD09BEA95E0438C27A1F79698430B7E68A475957'
$priorFixtureExpected='AC60AC5EDE6A962B1FB90DFB8389EF85C6AFE304A25DD24CC7C753A2F59FDB82'
$priorDebugExpected='47BC0C374226824A8FD0A70749930B33F925533739FBC26975CBB4872353729D'
$priorArgsExpected='9973A4C95FB1C1A65F05877CDCBDA3785D91F4FED11D890F1BF55999CE863781'
$priorProvExpected='741B020ED0D2AC2005C81C66918D953D49AD9B0D74078EA80979BCA0B2376A4A'
$priorSv00Expected='C90B379DC628CE94CECB1B1344741181233B8485B9A1329E54C8824395C1C986'
$priorFecc00Expected='01F0D4E7BCB16253EDE10A20EE2EC1B893429CE7969204365A49FE2B5FBE4303'
$declaredPatch='removed only the debugger-startup frame assertion and set its skip guard to zero; replay/physical-input/event code unchanged'

if((Get-Content (Join-Path $run 'exit-code.txt') -Raw).Trim() -ne '0'){throw 'Capture exit is not 0'}
$mameHash=HashFile $mame
if($mameHash -ne $mameExpected){throw 'Unexpected actual MAME binary hash'}
$romZipHash=HashFile $rom
if($romZipHash -ne $romZipExpected){throw 'Unexpected actual ROM zip hash'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::OpenRead($rom)
try{
    $entry=$zip.GetEntry('a6ls.p1')
    if(!$entry){throw 'Missing a6ls.p1 in actual ROM zip'}
    $ms=[IO.MemoryStream]::new()
    $stream=$entry.Open()
    try{$stream.CopyTo($ms)}finally{$stream.Dispose()}
    $romBytes=$ms.ToArray()
    $ms.Dispose()
}finally{$zip.Dispose()}
if($romBytes.Length -ne 0x10000){throw 'Unexpected actual ROM entry size'}
$romSha1=HashBytes $romBytes 'SHA1'
if($romSha1 -ne $romSha1Expected){throw 'Unexpected actual ROM entry SHA1'}
if((HashFile $priorFixture) -ne $priorFixtureExpected){throw 'Retained capture36 fixture changed'}
if((HashFile (Join-Path $priorRun 'debug.log')) -ne $priorDebugExpected){throw 'Retained capture36 debug.log changed'}
if((HashFile (Join-Path $priorRun 'arguments.json')) -ne $priorArgsExpected){throw 'Retained capture36 arguments changed'}
if((HashFile (Join-Path $priorRun 'provenance.json')) -ne $priorProvExpected){throw 'Retained capture36 provenance changed'}
if((HashFile (Join-Path $priorRun 'sv-00.bin')) -ne $priorSv00Expected){throw 'Retained capture36 sv-00 changed'}
if((HashFile (Join-Path $priorRun 'fecc-00.bin')) -ne $priorFecc00Expected){throw 'Retained capture36 fecc-00 changed'}

$sourceInput=Join-Path $source 'input.lua'
$sourceReplay=Join-Path $source 'replay-actions.csv'
if(!(Test-Path -LiteralPath $sourceInput) -or !(Test-Path -LiteralPath $sourceReplay)){throw 'Missing pinned source campaign'}
$sourceInputHash=HashFile $sourceInput
$sourceReplayHash=HashFile $sourceReplay
if($sourceInputHash -ne $sourceInputExpected -or $sourceReplayHash -ne $sourceReplayExpected){throw 'Pinned source campaign hash differs'}
$runInput=Join-Path $run 'input.lua'
$runReplay=Join-Path $run 'replay-actions.csv'
$derivedInputHash=HashFile $runInput
if((HashFile $runReplay) -ne $sourceReplayExpected){throw 'Run replay is not the pinned source campaign'}
$sourceText=[IO.File]::ReadAllText($sourceInput)
$derivedText=[IO.File]::ReadAllText($runInput)
$assertBlockPattern="\r?\n if setup_callbacks_to_skip>0 then\r?\n  assert\(m\.time:as_double\(\)<0\.001,'Unexpected running frame during debugger setup'\)\r?\n  setup_callbacks_to_skip=setup_callbacks_to_skip-1\r?\n  return\r?\n end"
if([regex]::Matches($sourceText,'local setup_callbacks_to_skip=36').Count -ne 1){throw 'Pinned source lacks declared skip guard'}
if([regex]::Matches($sourceText,$assertBlockPattern).Count -ne 1){throw 'Pinned source lacks declared frame assertion block'}
$expectedDerived=$sourceText.Replace('local setup_callbacks_to_skip=36','local setup_callbacks_to_skip=0')
$expectedDerived=[regex]::Replace($expectedDerived,$assertBlockPattern,'')
if($derivedText -cne $expectedDerived){throw 'Derived input differs beyond the declared patch'}
if($derivedInputHash -ne $derivedInputExpected){throw 'Derived input hash differs from declared patch result'}
foreach($scriptText in @($sourceText,$derivedText)){
    if($scriptText -match 'mem:write|write_u8|write_u16'){throw 'Input campaign writes machine memory'}
}

$provenance=Get-Content (Join-Path $run 'provenance.json') -Raw|ConvertFrom-Json
$saveCap=[int]$provenance.save_cap
$eventCap=[int]$provenance.event_cap
$hardTimeout=[int]$provenance.hard_timeout_seconds
$secondsToRun=[int]$provenance.seconds_to_run
if($saveCap -lt 1 -or $saveCap -gt 32){throw 'Provenance save cap is invalid'}
if($eventCap -lt 1 -or $eventCap -gt 1024){throw 'Provenance event cap is invalid'}
if($hardTimeout -lt 1 -or $secondsToRun -lt 1){throw 'Provenance timeout is invalid'}
$provenanceChecks=[ordered]@{
    mame_sha256=$mameHash
    rom_zip_sha256=$romZipHash
    rom_sha1=$romSha1
    source_input_lua_sha256=$sourceInputHash
    derived_input_lua_sha256=$derivedInputHash
    source_replay_actions_sha256=$sourceReplayHash
    debugger_sha256=(HashFile (Join-Path $run 'debugger.cmd'))
}
foreach($name in $provenanceChecks.Keys){if([string]$provenance.$name -ne [string]$provenanceChecks[$name]){throw "Provenance differs from actual $name"}}
if([string]$provenance.mame_version -ne '0.281'){throw 'Provenance MAME version differs'}
if([string]$provenance.rom_entry -ne 'a6ls.p1' -or [int]$provenance.rom_bytes -ne 0x10000){throw 'Provenance ROM entry differs'}
if([string]$provenance.input_lua_patch -cne $declaredPatch){throw 'Provenance declares an unexpected input patch'}

$romDirectory=[IO.Path]::GetDirectoryName($rom)
$expectedArgs=@('m4addr','-noreadconfig','-rompath',$romDirectory,'-cfg_directory',(Join-Path $run 'cfg'),'-nvram_directory',(Join-Path $run 'nvram'),'-input_directory',(Join-Path $run 'inp'),'-snapshot_directory',(Join-Path $run 'snap'),'-comment_directory',(Join-Path $run 'comments'),'-state_directory',(Join-Path $run 'state'),'-diff_directory',(Join-Path $run 'diff'),'-autoboot_delay','0','-autoboot_script',(Join-Path $run 'input.lua'),'-debug','-debugger','windows','-debugscript',(Join-Path $run 'debugger.cmd'),'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run',"$secondsToRun")
$actualArgs=[object[]](Get-Content (Join-Path $run 'arguments.json') -Raw|ConvertFrom-Json)
if($actualArgs.Count -ne $expectedArgs.Count){throw 'Capture argument count differs from isolation contract'}
for($i=0;$i -lt $expectedArgs.Count;$i++){if([string]$actualArgs[$i] -cne [string]$expectedArgs[$i]){throw "Capture argument differs at index $i"}}
foreach($directory in @('cfg','nvram','inp','snap','comments','state','diff')){if(!(Test-Path -LiteralPath (Join-Path $run $directory))){throw "Missing isolated directory $directory"}}
foreach($arg in $actualArgs){if([string]$arg -match '^-(load|playback|cheat|autosave|rewind)$'){throw "Forbidden capture argument $arg"}}

$debuggerLines=@(Get-Content (Join-Path $run 'debugger.cmd')|Where-Object{$_ -ne ''})
if($debuggerLines[$debuggerLines.Count-2] -ne 'go' -or $debuggerLines[$debuggerLines.Count-1] -ne 'quit'){throw 'Debugger does not end with go then quit'}
foreach($line in $debuggerLines){
    if($line -match '^temp[0-9]+=0$'){continue}
    if($line -eq 'go' -or $line -eq 'quit'){continue}
    if($line -notmatch '^(bpset|wpset) 0x[0-9a-f]+,'){throw "Debugger line is not an allowlisted bpset/wpset: $line"}
    if($line -notmatch '^\s*(bpset|wpset)'){}
    foreach($forbidden in @('load','fill','dump','write','mem','cheat','watch','rp','ep','trace','step','over','state','playback','reset')){
        if($line -match "\b$forbidden\b"){throw "Debugger contains forbidden command token $forbidden"}
    }
    $body=[regex]::Match($line,'\{(.*)\}$').Groups[1].Value
    if(!$body){throw 'Debugger action is empty'}
    foreach($part in @($body -split ';')){
        if($part -match '^printf '){continue}
        if($part -match '^save [A-Za-z0-9\-]+\.bin,0,800$'){continue}
        if($part -match '^temp[0-9]+=temp[0-9]+\+1$'){continue}
        if($part -match '^temp[0-9]+=[0-9]+$'){continue}
        if($part -eq 'go' -or $part -eq 'quit'){continue}
        throw "Debugger action contains unexpected command: $part"
    }
}

$allLogLines=@(Get-Content (Join-Path $run 'debug.log'))
$events=New-Object System.Collections.Generic.List[object]
$previousCycle=$null
foreach($line in $allLogLines){
    if($line -notmatch '^([A-Za-z0-9_]+) pc='){continue}
    $tag=$Matches[1]
    if($tag -like 'OVERFLOW_*'){throw "Capture reported overflow event $tag"}
    if($tag -notmatch '^(FC|Q|FE70|FF13|FEC9|SW|SVC)$'){throw "Unexpected event tag $tag"}
    $f=Fields $line
    foreach($key in @('pc','cyc','s','u','x','y','a','b','dp','cc')){if(!$f.Contains($key)){throw "Event $tag lacks $key"}}
    $cycle=[Convert]::ToUInt64($f.cyc,16)
    if($previousCycle -ne $null -and $cycle -lt $previousCycle){throw "Cycles are not monotonic at $tag"}
    $previousCycle=$cycle
    $event=[ordered]@{tag=$tag;pc=$f.pc;cycle=$f.cyc;s=$f.s;u=$f.u;x=$f.x;y=$f.y;a=$f.a;b=$f.b;dp=$f.dp;cc=$f.cc}
    if($tag -eq 'SW'){
        foreach($key in @('wpaddr','old','new','win','opm4','opm3','opm2','opm1','op0','op1','op2','op3')){if(!$f.Contains($key)){throw "SW lacks $key"}}
        $wp=[Convert]::ToInt32($f.wpaddr,16)
        if($wp -lt 0x780 -or $wp -gt 0x78F){throw ("SW address {0:X4} outside 0780..078F" -f $wp)}
        $event.wpaddr=$f.wpaddr;$event.old=$f.old;$event.new=$f.new;$event.win=$f.win
        $event.opcode_context=[ordered]@{m4=$f.opm4;m3=$f.opm3;m2=$f.opm2;m1=$f.opm1;p0=$f.op0;p1=$f.op1;p2=$f.op2;p3=$f.op3}
    }else{
        foreach($key in @('44','47','49','4d','ret','st0','st2','st4','st6','st8','st10')){if(!$f.Contains($key)){throw "Event $tag lacks $key"}}
        $event.host=[ordered]@{'44'=$f.'44';'47'=$f.'47';'49'=$f.'49';'4d'=$f.'4d'}
        $event.stack=[ordered]@{s0=$f.st0;s2=$f.st2;s4=$f.st4;s6=$f.st6;s8=$f.st8;s10=$f.st10}
        $event.ret=$f.ret
    }
    $events.Add($event)|Out-Null
}
if($events.Count -gt $eventCap){throw "Event count $($events.Count) exceeds cap $eventCap"}
$tagCounts=@{}
foreach($event in $events){if(!$tagCounts.ContainsKey($event.tag)){$tagCounts[$event.tag]=0};$tagCounts[$event.tag]++}
foreach($t in @('FC','Q','FE70','FF13','FEC9','SW','SVC')){if(!$tagCounts.ContainsKey($t)){$tagCounts[$t]=0}}
foreach($required in @('FC','Q','SVC')){if($tagCounts[$required] -ne 1){throw "Expected exactly one $required event, got $($tagCounts[$required])"}}
if($tagCounts['FE70'] -lt 2){throw 'Expected outer and nested FE70 events'}
if($tagCounts['FF13'] -lt 1 -or $tagCounts['FEC9'] -lt 1){throw 'Missing FF13 or FEC9 anchor'}
if($tagCounts['SW'] -lt 1){throw 'No stack-write event'}
if($events[0].tag -ne 'FC'){throw 'First event is not FC4D'}
if($events[$events.Count-1].tag -ne 'SVC'){throw 'Last event is not the first 5CD0'}

$fc=$events|Where-Object{$_.tag -eq 'FC'}|Select-Object -First 1
$queue=$events|Where-Object{$_.tag -eq 'Q'}|Select-Object -First 1
$svc=$events|Where-Object{$_.tag -eq 'SVC'}|Select-Object -First 1
$fe70=@($events|Where-Object{$_.tag -eq 'FE70'})
$ff13=@($events|Where-Object{$_.tag -eq 'FF13'})
$fec9=@($events|Where-Object{$_.tag -eq 'FEC9'})
$outerFe70=$fe70|Where-Object{$_.s -eq '078D'}|Select-Object -First 1
$nestedFe70=$fe70|Where-Object{$_.s -eq '0778'}|Select-Object -First 1
if($fc.y -ne 'FC4D' -or $fc.x -ne '8132'){throw 'FC4D entry registers differ'}
if($fc.host.'47' -ne '0000' -or $fc.host.'49' -ne '01A0' -or $fc.host.'4d' -ne '00'){throw 'FC4D initial list differs'}
if($queue.ret -ne '59E9'){throw 'Queue continuation differs'}
if($svc.pc -ne '5CD0' -or $svc.ret -ne 'FECC' -or $svc.s -ne '078B' -or $svc.u -ne '0672'){throw 'First 5CD0 anchor differs'}
if(!$outerFe70){throw 'Missing outer FE70 with S=078D'}
if(!$nestedFe70){throw 'Missing nested FE70 with S=0778'}
if(!($ff13|Where-Object{$_.s -eq '0778'})){throw 'Missing nested FF13 with S=0778'}
if(!($fec9|Where-Object{$_.s -eq '078D'})){throw 'Missing FEC9 with S=078D'}

$fcRam=ReadRam 'fc4d.bin'
$stopRam=ReadRam 'stop5cd0.bin'
$track=@{}
foreach($offset in 0x780..0x78F){$track[$offset]=[int]$fcRam[$offset]}
$stackWrites=@()
foreach($event in $events){
    if($event.tag -ne 'SW'){continue}
    $addr=[Convert]::ToInt32($event.wpaddr,16)
    $old=[Convert]::ToInt32($event.old,16)
    $new=[Convert]::ToInt32($event.new,16)
    if($old -ne $track[$addr]){throw ("SW {0:X4} old {1:X2} differs from tracked {2:X2}" -f $addr,$old,$track[$addr])}
    $stackWrites+=$event
    $track[$addr]=$new
}
foreach($offset in 0x780..0x78F){if($track[$offset] -ne [int]$stopRam[$offset]){throw ("Final tracked {0:X4}={1:X2} differs from stop5cd0 {2:X2}" -f $offset,$track[$offset],[int]$stopRam[$offset])}}
if($fcRam[0x785] -ne 0x00 -or $stopRam[0x785] -ne 0x19){throw 'Fresh target 0785 did not transition 00 -> 19'}
$writes785=@($stackWrites|Where-Object{$_.wpaddr -eq '0785'})
if($writes785.Count -lt 1){throw 'No write to 0785'}
$firstWrite785=$writes785[0]
if($firstWrite785.old -ne '00' -or $firstWrite785.new -ne '3F'){throw 'First 0785 write is not the expected pre-commit 00->3F'}
$finalWriter=$writes785|Where-Object{$_.old -ne '19' -and $_.new -eq '19'}|Select-Object -First 1
if(!$finalWriter){throw 'No 0785 write establishes 19'}
if($finalWriter.pc -ne '19BB'){throw 'Final 0785 writer PC differs'}
$op=$finalWriter.opcode_context
if($op.m3 -ne 'BD' -or $op.m2 -ne '1A' -or $op.m1 -ne '87'){throw 'Final 0785 writer opcode bytes differ'}
$writerStart=0x19B8
if($romBytes[$writerStart] -ne 0xBD -or $romBytes[$writerStart+1] -ne 0x1A -or $romBytes[$writerStart+2] -ne 0x87){throw 'ROM bytes at 19B8 are not BD 1A 87'}
$rewrites=@($writes785|Where-Object{$_.old -eq '19' -and $_.new -eq '19'})
if($rewrites.Count -lt 2){throw 'Expected same-value rewrites from 19BB/19BE call chain'}
$keyPcs=@('FEC3','280C','439E','19BB','19BE','19C1','280F','FEC6','6B6A','FEC9','FECC')
foreach($pc in $keyPcs){if(!($stackWrites|Where-Object{$_.pc -eq $pc})){throw "Missing stack-write event at PC $pc"}}
$word00c6=WordAt $stopRam 0xC6
if($word00c6 -ne '19B8'){throw 'Indirect caller pointer 00C6 is not 19B8'}
if(!($stackWrites|Where-Object{$_.pc -eq '439E'})){throw 'Missing indirect-caller return write at PC 439E'}
$indirectCaller=[ordered]@{instruction_start='439A';opcode='AD 9F 00 C6';mnemonic='JSR [$00C6]';return_address='439E';pointer='00C6';target=$word00c6;trace_evidence='SW pc=439E pushes return word 439E; stop5cd0.bin word 00C6=19B8'}
$firstWrite785Out=[ordered]@{pc=$firstWrite785.pc;cycle=$firstWrite785.cycle;s=$firstWrite785.s;wpaddr=$firstWrite785.wpaddr;old=$firstWrite785.old;new=$firstWrite785.new;instruction_start='70EF';opcode='34 05';mnemonic='PSHS B,CC';registers=[ordered]@{a=$firstWrite785.a;b=$firstWrite785.b;x=$firstWrite785.x;y=$firstWrite785.y;u=$firstWrite785.u;dp=$firstWrite785.dp;cc=$firstWrite785.cc};opcode_context=$firstWrite785.opcode_context}
$finalWriterOut=[ordered]@{pc=$finalWriter.pc;cycle=$finalWriter.cycle;s=$finalWriter.s;wpaddr=$finalWriter.wpaddr;old=$finalWriter.old;new=$finalWriter.new;instruction_start='19B8';opcode='BD 1A 87';mnemonic='JSR $1A87';source_function='irq_accumulate_inputs_and_check_modes';callee='accumulate_mux_input_or_and_samples';meaning='saved JSR return address 19BB; high byte 19 becomes 0785; low byte BB becomes 0786';registers=[ordered]@{a=$finalWriter.a;b=$finalWriter.b;x=$finalWriter.x;y=$finalWriter.y;u=$finalWriter.u;dp=$finalWriter.dp;cc=$finalWriter.cc};opcode_context=$finalWriter.opcode_context}

$stackWindowBefore=@();$stackWindowAfter=@()
foreach($offset in 0x780..0x78F){$stackWindowBefore+=[ordered]@{address=('{0:X4}' -f $offset);value=(ByteAt $fcRam $offset)}}
foreach($offset in 0x780..0x78F){$stackWindowAfter+=[ordered]@{address=('{0:X4}' -f $offset);value=(ByteAt $stopRam $offset)}}
$compactWrites=@()
foreach($w in $stackWrites){$compactWrites+=[ordered]@{tag=$w.tag;pc=$w.pc;cycle=$w.cycle;s=$w.s;wpaddr=$w.wpaddr;old=$w.old;new=$w.new;a=$w.a;b=$w.b;x=$w.x;y=$w.y;u=$w.u;dp=$w.dp;cc=$w.cc;opcode_context=$w.opcode_context}}
$anchors=[ordered]@{
  fc4d=[ordered]@{pc=$fc.pc;cycle=$fc.cycle;s=$fc.s;x=$fc.x;y=$fc.y;host=$fc.host;ret=$fc.ret;ram_sha256=(HashFile (Join-Path $run 'fc4d.bin'))}
  queue=[ordered]@{pc=$queue.pc;cycle=$queue.cycle;s=$queue.s;x=$queue.x;y=$queue.y;host=$queue.host;ret=$queue.ret;ram_sha256=(HashFile (Join-Path $run 'queue.bin'))}
  outer_fe70=[ordered]@{pc=$outerFe70.pc;cycle=$outerFe70.cycle;s=$outerFe70.s;stack=$outerFe70.stack;ret=$outerFe70.ret}
  nested_fe70=[ordered]@{pc=$nestedFe70.pc;cycle=$nestedFe70.cycle;s=$nestedFe70.s;stack=$nestedFe70.stack;ret=$nestedFe70.ret}
  ff13=[ordered]@{pc=$ff13[0].pc;cycle=$ff13[0].cycle;s=$ff13[0].s;stack=$ff13[0].stack;ret=$ff13[0].ret}
  fec9=[ordered]@{pc=$fec9[0].pc;cycle=$fec9[0].cycle;s=$fec9[0].s;stack=$fec9[0].stack;ret=$fec9[0].ret}
  first_5cd0=[ordered]@{pc=$svc.pc;cycle=$svc.cycle;s=$svc.s;u=$svc.u;x=$svc.x;y=$svc.y;host=$svc.host;stack=$svc.stack;ret=$svc.ret;ram_sha256=(HashFile (Join-Path $run 'stop5cd0.bin'))}
}

$fixture=[ordered]@{
 schema='stack-writer-0785-capture41/1'
 classification='controlled replay natural: one fresh first-FC4D-to-first-5CD0 gap from the retained recorded physical-input campaign; original reset ROM/settings/NVRAM; no RAM/CPU/device/PTM/ACK/end-state injection; debugger breakpoints/write watchpoint/reads/2KB saves only'
 source=[ordered]@{
  run=$RunDirectory
  rom_sha1=$romSha1;rom_zip_sha256=$romZipHash
  mame_version='0.281';mame_sha256=$mameHash
  source_input_lua_sha256=$sourceInputHash
  derived_input_lua_sha256=$derivedInputHash
  input_lua_patch=$declaredPatch
  replay_actions_sha256=$sourceReplayHash
  debug_sha256=(HashFile (Join-Path $run 'debug.log'))
  debugger_sha256=(HashFile (Join-Path $run 'debugger.cmd'))
  arguments_sha256=(HashFile (Join-Path $run 'arguments.json'))
  provenance_sha256=(HashFile (Join-Path $run 'provenance.json'))
  exit=0
  conditions='fresh isolated cfg/nvram/inp/snap/state/diff; actual m4addr.zip read-only; MPU4_REPLAY=retained replay-actions.csv; no machine-state load, PTM/ACK/end-state injection or debugger memory write; stopped by first 5CD0 guard'
  event_cap=$eventCap;save_cap=$saveCap;hard_timeout_seconds=$hardTimeout
 }
 occurrence=[ordered]@{
  identity='fresh first FC4D->first 5CD0 occurrence in this run; absolute cycle/state is its own and is not fitted to capture36, gate28 or the historical nudge checkpoint'
  scope='single gap only; not a continuous lifecycle, autonomous IRQ cadence or later-delta recovery'
  entry='FC4D';entry_cycle=$fc.cycle;entry_s=$fc.s;entry_x=$fc.x
  stop='5CD0';stop_cycle=$svc.cycle;stop_s=$svc.s;stop_ret=$svc.ret
  event_counts=[ordered]@{total=$events.Count;fc=$tagCounts['FC'];queue=$tagCounts['Q'];fe70=$tagCounts['FE70'];ff13=$tagCounts['FF13'];fec9=$tagCounts['FEC9'];stack_writes=$tagCounts['SW'];first_5cd0=$tagCounts['SVC']}
  historical_relation='fresh 0785 final value is 19, matching the historical net delta, but the fresh gap has an intermediate 0785=3F write and its own cycles; it is not claimed as the identical historical occurrence'
 }
 watchpoint=[ordered]@{
  address='0780';length=16;type='write';mame_version='0.281'
  semantics='MAME 0.281 installs a pre-commit write tap (points.cpp:231-237); debug_watchpoint::triggered sets wpaddr/wpdata and runs the action before the write commits (points.cpp:314-355). old=b@wpaddr is the pre-write byte; new=wpdata is the value about to be written; stop5cd0.bin is the independent after-state.'
  pc_semantics='M6809 read_opcode_arg increments PC during operand fetch (m6809.h:214-216); tap PC is post-fetch. Instruction starts are recovered from logged pre-PC bytes and verified against the original ROM.'
  installed_help='artifacts/deepseek/capture-41/mame0281-help-wpset.txt sha256=A2C1738BF2413B9EC285FAA18F8A540FE675DBE9CF5FB24A397CE5DF8CA99D3A'
  source_reference='MAME mame0281 src/emu/debug/points.cpp sha256=72AE0E61EAE7C51EE3E7CD0E12C39DEE2B8B0AF90D65232E3A04451058927612; src/devices/cpu/m6809/m6809.h sha256=A8581492454D4123FC2548725AD9E7FEC0430C0B93E072E4E92A3761A4B72D59'
 }
 stack_window=[ordered]@{before_0780_078f=$stackWindowBefore;after_0780_078f=$stackWindowAfter}
 first_0785_write=$firstWrite785Out
 final_0785_writer=$finalWriterOut
 indirect_caller_439a=$indirectCaller
 same_value_rewrites_0785=@($rewrites|ForEach-Object{[ordered]@{pc=$_.pc;cycle=$_.cycle;s=$_.s;old=$_.old;new=$_.new}})
 key_call_chain=@($stackWrites|Where-Object{$keyPcs -contains $_.pc}|ForEach-Object{[ordered]@{pc=$_.pc;cycle=$_.cycle;s=$_.s;wpaddr=$_.wpaddr;old=$_.old;new=$_.new;opcode_context=$_.opcode_context}})
 stack_writes=$compactWrites
 anchors=$anchors
 validation=[ordered]@{
  validator='tools/Curate-StackWriterCapture41.ps1'
  actual_mame_sha256=$mameHash
  actual_rom_zip_sha256=$romZipHash
  actual_rom_entry_sha1=$romSha1
  source_campaign_pins_verified=$true
  source_input_lua_sha256=$sourceInputHash
  derived_input_only_declared_patch=$true
  debugger_allowlisted_breakpoints_watchpoint_reads_saves=$true
  debugger_has_no_load_write_or_state_injection=$true
  arguments_isolated_noreadconfig_original_rom=$true
  event_cap_enforced=$true
  save_cap_enforced=$true
  cycles_monotonic=$true
  old_bytes_match_fc4d_then_prior_new=$true
  final_stack_window_matches_stop5cd0=$true
  target_0785_transition_00_to_19=$true
  writer_opcode_verified_against_original_rom=$true
  prior_capture36_fixture_and_raw_unchanged=$true
  classification_basis='derived from the executed checks above; the free-text classification string is descriptive, not used as evidence'
 }
 next_task='Trace the remaining 0785-marker consumers and the exact 438C/19B8/1A87 stack order against a second independent natural gap before attributing later transitions; do not build an adapter from these writes.'
 limits=@(
  'Single fresh FC4D->first 5CD0 gap; no continuous execution or autonomous IRQ cadence is claimed.',
  'The fresh occurrence is not the historical occurrence; 0785 final=19 matches only the snapshotted net delta.',
  'The first watched 0785 write is PSHS B,CC -> 3F; the final 19 comes later from the JSR return high byte. These are distinct events.',
  'Later inter-service deltas and downstream consumers are not recovered here.'
 )
}
$directory=[IO.Path]::GetDirectoryName($target)
if(!(Test-Path -LiteralPath $directory)){New-Item -ItemType Directory -Path $directory -Force|Out-Null}
$json=$fixture|ConvertTo-Json -Depth 30
[IO.File]::WriteAllText($target,$json,[Text.UTF8Encoding]::new($false))
Write-Output ("Curated capture41 entry={0} cycle={1} stop={2} writes={3} first0785={4} final0785={5} sha256={6}" -f $fixture.occurrence.entry,$fixture.occurrence.entry_cycle,$fixture.occurrence.stop_cycle,$compactWrites.Count,$firstWrite785Out.pc,$finalWriterOut.pc,(HashFile $target))

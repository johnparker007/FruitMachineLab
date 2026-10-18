param(
    [string]$RunDirectory='artifacts/deepseek/capture-43/natural-caller-stack',
    [string]$RomPath='E:\Arcade\MAME0266\roms\m4addr.zip',
    [string]$MamePath='E:\Arcade\MAME0266\mame281.exe',
    [string]$SourceRun='artifacts/deepseek/gate-28/natural-service',
    [string]$FixturePath='evidence/mpu4/collection/stack-writer-0790-capture43.json',
    [string]$PriorCapture41Fixture='evidence/mpu4/collection/stack-writer-0785-capture41.json',
    [string]$PriorCapture41Run='artifacts/deepseek/capture-41/natural-stack-writer'
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath("$PSScriptRoot/..")
function Abs([string]$p){if([IO.Path]::IsPathRooted($p)){[IO.Path]::GetFullPath($p)}else{[IO.Path]::GetFullPath((Join-Path $root $p))}}
function HashBytes([byte[]]$bytes,[string]$algorithm='SHA256'){([BitConverter]::ToString([Security.Cryptography.HashAlgorithm]::Create($algorithm).ComputeHash($bytes))-replace '-','')}
function HashFile([string]$p,[string]$algorithm='SHA256'){HashBytes ([IO.File]::ReadAllBytes($p)) $algorithm}
function Fields([string]$line){$f=[ordered]@{};foreach($m in [regex]::Matches($line,'([A-Za-z0-9]+)=([0-9A-F]+)')){$f[$m.Groups[1].Value]=$m.Groups[2].Value};return $f}
function ReadRam([string]$name){$p=Join-Path $run $name;if(!(Test-Path -LiteralPath $p)){throw "Missing $name"};$b=[IO.File]::ReadAllBytes($p);if($b.Length -ne 0x800){throw "Non-2KB $name"};return ,$b}
function WordAt([byte[]]$ram,[int]$offset){if($offset -lt 0 -or $offset+1 -ge $ram.Length){throw ("Word offset {0:X} outside 2KB" -f $offset)};return ((([int]$ram[$offset] -shl 8) -bor [int]$ram[$offset+1]).ToString('X4'))}

$run=Abs $RunDirectory
$rom=Abs $RomPath
$mame=Abs $MamePath
$source=Abs $SourceRun
$target=Abs $FixturePath
$priorFixture=Abs $PriorCapture41Fixture
$priorRun=Abs $PriorCapture41Run
foreach($p in @($run,$rom,$mame,$source,$priorFixture,$priorRun)){if(!(Test-Path -LiteralPath $p)){throw "Missing $p"}}

$mameExpected='0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A'
$romZipExpected='E2553AFA6B8E9DEF55BD920E4BED77A4324696C1E358B73BE70BFD2C58179989'
$romSha1Expected='402D1518BB78FDC489B06C2AABC771E5CE151847'
$sourceInputExpected='7C664323A5725E9FB294CB201B17B855564AF2E4A500560ED499F1EE45179D0D'
$sourceReplayExpected='4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D'
$derivedInputExpected='BC93C0699861A2B3DE402489DD09BEA95E0438C27A1F79698430B7E68A475957'
$priorFixtureExpected='D23207FA7EBD2221124EBDACE8DAAA83F6B181566F301B236CA431518C1A5680'
$priorDebugExpected='FD580CA17A67DC2382CBFFF88F0684F1401F225231BCF59E9B1C2E1255E42490'
$priorStopExpected='6F51BB65E70D31D65C4B1054221973C77C3B636FE6443CE30802388686ADA4D9'
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
    $ms=[IO.MemoryStream]::new();$stream=$entry.Open();try{$stream.CopyTo($ms)}finally{$stream.Dispose()};$romBytes=$ms.ToArray();$ms.Dispose()
}finally{$zip.Dispose()}
if($romBytes.Length -ne 0x10000){throw 'Unexpected actual ROM entry size'}
$romSha1=HashBytes $romBytes 'SHA1'
if($romSha1 -ne $romSha1Expected){throw 'Unexpected actual ROM entry SHA1'}
if((HashFile $priorFixture) -ne $priorFixtureExpected){throw 'Retained capture41 fixture changed'}
if((HashFile (Join-Path $priorRun 'debug.log')) -ne $priorDebugExpected){throw 'Retained capture41 debug.log changed'}
if((HashFile (Join-Path $priorRun 'stop5cd0.bin')) -ne $priorStopExpected){throw 'Retained capture41 stop snapshot changed'}

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
if($secondsToRun -ne 430 -or $hardTimeout -ne 600 -or $eventCap -ne 128 -or $saveCap -ne 4){throw 'Capture caps/timeouts differ from the declared bounded run'}
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
if([string]$provenance.watchpoint -ne '0x0790 length 16 write; log PC/registers/cycles/wpaddr/old/new, opcode context and actual 719B; no memory write'){throw 'Provenance watchpoint differs'}

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
if(!($debuggerLines|Where-Object{$_ -match '^wpset 0x790,10,w,'})){throw 'Debugger lacks the 0790 length-16 write watchpoint'}

$allLogLines=@(Get-Content (Join-Path $run 'debug.log'))
$events=New-Object System.Collections.Generic.List[object]
$previousCycle=$null
foreach($line in $allLogLines){
    if($line -notmatch '^([A-Za-z0-9_]+) pc='){continue}
    $tag=$Matches[1]
    if($tag -like 'OVERFLOW_*'){throw "Capture reported overflow event $tag"}
    if($tag -notmatch '^(FC|Q|FE70|FF13|FEC9|SW|SVC)$'){throw "Unexpected event tag $tag"}
    $f=Fields $line
    foreach($key in @('pc','cyc','s','u','x','y','a','b','dp','cc','719b')){if(!$f.Contains($key)){throw "Event $tag lacks $key"}}
    if($f['719b'] -ne '00'){throw "Event $tag has actual 719B=$($f['719b']), expected 00"}
    $cycle=[Convert]::ToUInt64($f.cyc,16)
    if($previousCycle -ne $null -and $cycle -lt $previousCycle){throw "Cycles are not monotonic at $tag"}
    $previousCycle=$cycle
    $event=[ordered]@{tag=$tag;pc=$f.pc;cycle=$f.cyc;s=$f.s;u=$f.u;x=$f.x;y=$f.y;a=$f.a;b=$f.b;dp=$f.dp;cc=$f.cc;actual_719b=$f['719b']}
    if($tag -eq 'SW'){
        foreach($key in @('wpaddr','old','new','win','opm4','opm3','opm2','opm1','op0','op1','op2','op3')){if(!$f.Contains($key)){throw "SW lacks $key"}}
        $wp=[Convert]::ToInt32($f.wpaddr,16)
        if($wp -lt 0x790 -or $wp -gt 0x79F){throw ("SW address {0:X4} outside 0790..079F" -f $wp)}
        $event.wpaddr=$f.wpaddr;$event.old=$f.old;$event.new=$f.new;$event.win=$f.win
        $event.opcode_context=[ordered]@{m4=$f.opm4;m3=$f.opm3;m2=$f.opm2;m1=$f.opm1;p0=$f.op0;p1=$f.op1;p2=$f.op2;p3=$f.op3}
    }else{
        foreach($key in @('44','47','49','4d','ret','st0','st2','st4','st6','st8','st10')){if(!$f.Contains($key)){throw "Event $tag lacks $key"}}
        $event.host=[ordered]@{'44'=$f.'44';'47'=$f.'47';'49'=$f.'49';'4d'=$f.'4d'}
        $event.stack=[ordered]@{s0=$f.st0;s2=$f.st2;s4=$f.st4;s6=$f.st6;s8=$f.st8;s0x10=$f.st10}
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
if($queue.ret -ne '59E9'){throw 'Queue continuation differs'}
if($svc.pc -ne '5CD0' -or $svc.ret -ne 'FECC' -or $svc.s -ne '078B' -or $svc.u -ne '0672'){throw 'First 5CD0 anchor differs'}
if(!$outerFe70){throw 'Missing outer FE70 with S=078D'}
if(!$nestedFe70){throw 'Missing nested FE70 with S=0778'}
if(!($ff13|Where-Object{$_.s -eq '0778'})){throw 'Missing nested FF13 with S=0778'}
if(!($fec9|Where-Object{$_.s -eq '078D'})){throw 'Missing FEC9 with S=078D'}
if($romBytes[0xFFF8] -ne 0xFE -or $romBytes[0xFFF9] -ne 0x70){throw 'Original IRQ vector is not FE70'}

$fcRam=ReadRam 'fc4d.bin'
$stopRam=ReadRam 'stop5cd0.bin'
$queueRam=ReadRam 'queue.bin'
$track=@{}
foreach($offset in 0x790..0x79F){$track[$offset]=[int]$fcRam[$offset]}
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
foreach($offset in 0x790..0x79F){if($track[$offset] -ne [int]$stopRam[$offset]){throw ("Final tracked {0:X4}={1:X2} differs from stop5cd0 {2:X2}" -f $offset,$track[$offset],[int]$stopRam[$offset])}}
$writes799=@($stackWrites|Where-Object{$_.wpaddr -eq '0799'})
$writes79F=@($stackWrites|Where-Object{$_.wpaddr -eq '079F'})
if($writes799.Count -lt 1){throw 'No write to 0799'}
if($writes79F.Count -lt 1){throw 'No write to 079F'}

function LastWriter([string]$addr){$w=@($stackWrites|Where-Object{$_.wpaddr -eq $addr});if($w.Count -lt 1){throw "No writer for $addr"};return $w[$w.Count-1]}
$w799=LastWriter '0799'
if($w799.pc -ne '7166' -or $w799.cycle -ne '0000000003C5946A' -or $w799.old -ne 'E9' -or $w799.new -ne '02' -or $w799.b -ne '02'){throw 'Final 0799 writer differs'}
if($w799.opcode_context.p0 -ne 'C6' -or $w799.opcode_context.m1 -ne '04' -or $w799.opcode_context.m2 -ne '34'){throw '0799 writer opcode context differs'}
if($romBytes[0x7164] -ne 0x34 -or $romBytes[0x7165] -ne 0x04){throw 'ROM bytes at 7164 are not 34 04'}
$w79F=LastWriter '079F'
if($w79F.pc -ne '5A0A' -or $w79F.cycle -ne '0000000003C59435' -or $w79F.old -ne '05' -or $w79F.new -ne '0A'){throw 'Final 079F writer differs'}
if($w79F.opcode_context.m1 -ne '59' -or $w79F.opcode_context.m2 -ne '71' -or $w79F.opcode_context.m3 -ne 'BD'){throw '079F writer opcode context differs'}
if($romBytes[0x5A07] -ne 0xBD -or $romBytes[0x5A08] -ne 0x71 -or $romBytes[0x5A09] -ne 0x59){throw 'ROM bytes at 5A07 are not BD 71 59'}
if((WordAt $stopRam 0x79E) -ne '5A0A'){throw '079E/079F return word is not 5A0A'}
$w79D=LastWriter '079D';$w79C=LastWriter '079C'
if($w79D.pc -ne '715D' -or $w79C.pc -ne '715D' -or $w79D.cycle -ne '0000000003C5945C' -or $w79C.cycle -ne '0000000003C5945C'){throw 'Final 079C/079D writers differ'}
if($w79D.new -ne '02' -or $w79C.new -ne '91' -or $w79C.a -ne '91' -or $w79D.b -ne '02'){throw 'PSHS A,B values differ'}
if($romBytes[0x715B] -ne 0x34 -or $romBytes[0x715C] -ne 0x06){throw 'ROM bytes at 715B are not 34 06'}
$w79B=LastWriter '079B';$w79A=LastWriter '079A'
if($w79B.pc -ne '715F' -or $w79A.pc -ne '715F' -or $w79B.cycle -ne '0000000003C59463' -or $w79A.cycle -ne '0000000003C59463'){throw 'Final 079A/079B writers differ'}
if((WordAt $stopRam 0x79A) -ne '715F'){throw '079A/079B return word is not 715F'}
if($romBytes[0x715D] -ne 0x8D -or $romBytes[0x715E] -ne 0x05){throw 'ROM bytes at 715D are not 8D 05'}

$irqWrites=@($stackWrites|Where-Object{$_.pc -eq '716A' -and $_.cycle -eq '0000000003C5965D'})
if($irqWrites.Count -ne 9){throw "Expected 9 IRQ-frame writes at 716A, got $($irqWrites.Count)"}
$irqExpected=[ordered]@{'0798'='6A';'0797'='71';'0796'='72';'0795'='06';'0794'='4F';'0793'='FC';'0792'='A6';'0791'='80';'0790'='00'}
foreach($k in $irqExpected.Keys){
    $w=$irqWrites|Where-Object{$_.wpaddr -eq $k}
    if(!$w -or $w.new -ne $irqExpected[$k]){throw "IRQ frame byte $k differs"}
    if($w.a -ne '47' -or $w.b -ne '27' -or $w.cc -ne 'C0' -or $w.u -ne '0672' -or $w.x -ne '80A6' -or $w.y -ne 'FC4F' -or $w.dp -ne '00'){throw "IRQ frame registers differ at $k"}
}
if((WordAt $stopRam 0x797) -ne '716A'){throw 'IRQ frame PC word at 0797 is not 716A'}
if((WordAt $stopRam 0x795) -ne '0672'){throw 'IRQ frame U word differs'}
if((WordAt $stopRam 0x793) -ne 'FC4F'){throw 'IRQ frame Y word differs'}
if((WordAt $stopRam 0x791) -ne '80A6'){throw 'IRQ frame X word differs'}
if($stopRam[0x790] -ne 0x00){throw 'IRQ frame DP differs'}
if($outerFe70.cycle -ne '0000000003C59673'){throw 'Outer FE70 does not follow the IRQ frame'}
if($outerFe70.host.'47' -ne '01A0' -or $outerFe70.host.'49' -ne '01C5' -or $outerFe70.host.'4d' -ne '31'){throw 'Outer FE70 host fields differ'}
$fec9ret=$fec9[0].ret

$stackWindowBefore=@();$stackWindowAfter=@()
foreach($offset in 0x790..0x79F){$stackWindowBefore+=[ordered]@{address=('{0:X4}' -f $offset);value=('{0:X2}' -f $fcRam[$offset])}}
foreach($offset in 0x790..0x79F){$stackWindowAfter+=[ordered]@{address=('{0:X4}' -f $offset);value=('{0:X2}' -f $stopRam[$offset])}}
$finalWriters=@()
foreach($offset in 0x790..0x79F){
    $addr=('{0:X4}' -f $offset)
    $w=LastWriter $addr
    $finalWriters+=[ordered]@{address=$addr;value=('{0:X2}' -f $stopRam[$offset]);pc=$w.pc;cycle=$w.cycle;s=$w.s;old=$w.old;new=$w.new;registers=[ordered]@{a=$w.a;b=$w.b;x=$w.x;y=$w.y;u=$w.u;dp=$w.dp;cc=$w.cc};opcode_context=$w.opcode_context}
}
$compactWrites=@()
foreach($w in $stackWrites){$compactWrites+=[ordered]@{tag=$w.tag;pc=$w.pc;cycle=$w.cycle;s=$w.s;wpaddr=$w.wpaddr;old=$w.old;new=$w.new;a=$w.a;b=$w.b;x=$w.x;y=$w.y;u=$w.u;dp=$w.dp;cc=$w.cc;actual_719b=$w.actual_719b;opcode_context=$w.opcode_context}}
$anchors=[ordered]@{
  fc4d=[ordered]@{pc=$fc.pc;cycle=$fc.cycle;s=$fc.s;x=$fc.x;y=$fc.y;host=$fc.host;ret=$fc.ret;actual_719b=$fc.actual_719b;ram_sha256=(HashFile (Join-Path $run 'fc4d.bin'))}
  queue=[ordered]@{pc=$queue.pc;cycle=$queue.cycle;s=$queue.s;x=$queue.x;y=$queue.y;host=$queue.host;ret=$queue.ret;actual_719b=$queue.actual_719b;ram_sha256=(HashFile (Join-Path $run 'queue.bin'))}
  outer_fe70=[ordered]@{pc=$outerFe70.pc;cycle=$outerFe70.cycle;s=$outerFe70.s;stack=$outerFe70.stack;ret=$outerFe70.ret;actual_719b=$outerFe70.actual_719b;note='s0x10 is the word at S+0x10 because MAME parses the expression literal 10 as hex; the IRQ resume PC is the watched frame word 0797/0798=716A'}
  nested_fe70=[ordered]@{pc=$nestedFe70.pc;cycle=$nestedFe70.cycle;s=$nestedFe70.s;stack=$nestedFe70.stack;ret=$nestedFe70.ret;actual_719b=$nestedFe70.actual_719b}
  ff13=[ordered]@{pc=$ff13[0].pc;cycle=$ff13[0].cycle;s=$ff13[0].s;stack=$ff13[0].stack;ret=$ff13[0].ret;actual_719b=$ff13[0].actual_719b}
  fec9=[ordered]@{pc=$fec9[0].pc;cycle=$fec9[0].cycle;s=$fec9[0].s;stack=$fec9[0].stack;ret=$fec9[0].ret;actual_719b=$fec9[0].actual_719b}
  first_5cd0=[ordered]@{pc=$svc.pc;cycle=$svc.cycle;s=$svc.s;u=$svc.u;x=$svc.x;y=$svc.y;host=$svc.host;stack=$svc.stack;ret=$svc.ret;actual_719b=$svc.actual_719b;ram_sha256=(HashFile (Join-Path $run 'stop5cd0.bin'))}
}
$writers=[ordered]@{
  irq_frame_0790_0798=[ordered]@{kind='6809 hardware IRQ frame push (entire state), not PSHS/JSR';interrupted_pc='716A';cycle='0000000003C5965D';s_before='0799';s_after='078D';frame_bytes='0790..0798 watched: DP=00 X=80A6 Y=FC4F U=0672 PC=716A; B/A/CC at 078F/078E/078D are outside this watchpoint and are taken from the event registers B=27 A=47 CC=C0 plus the unchanged stop snapshot';irq_vector='FFF8=FE70';resume_pc='716A'}
  final_0799=[ordered]@{instruction_start='7164';opcode='34 04';mnemonic='PSHS B';tap_pc='7166';cycle=$w799.cycle;s='0799';b=$w799.b;old=$w799.old;new=$w799.new;semantics='M6809 PSHS pushes B; value written is B=02, not a return address'}
  final_079a_079b=[ordered]@{instruction_start='715D';opcode='8D 05';mnemonic='BSR $7164';tap_pc='715F';cycle=$w79A.cycle;return_word='715F';bytes=@([ordered]@{address='079A';old=$w79A.old;new=$w79A.new},[ordered]@{address='079B';old=$w79B.old;new=$w79B.new});semantics='BSR pushes its own return address 715F (low byte 5F first, then high byte 71)'}
  final_079c_079d=[ordered]@{instruction_start='715B';opcode='34 06';mnemonic='PSHS A,B';tap_pc='715D';cycle=$w79C.cycle;a=$w79C.a;b=$w79C.b;bytes=@([ordered]@{address='079C';old=$w79C.old;new=$w79C.new},[ordered]@{address='079D';old=$w79D.old;new=$w79D.new});semantics='PSHS A,B pushes B first then A; 079D=B=02, 079C=A=91'}
  final_079e_079f=[ordered]@{instruction_start='5A07';opcode='BD 71 59';mnemonic='JSR $7159';tap_pc='5A0A';cycle=$w79F.cycle;return_word='5A0A';bytes=@([ordered]@{address='079E';old='5A';new='5A'},[ordered]@{address='079F';old=$w79F.old;new=$w79F.new});semantics='JSR pushes its return address 5A0A; 079E=5A unchanged, 079F 05->0A'}
}
$fixture=[ordered]@{
 schema='stack-writer-0790-capture43/1'
 classification='controlled replay natural: one fresh first-FC4D-to-first-5CD0 gap from the retained recorded physical-input campaign; original reset ROM/settings/NVRAM; no RAM/CPU/device/PTM/ACK/end-state injection; debugger breakpoints/write watchpoint/reads/2KB saves only'
 source=[ordered]@{
  run=$RunDirectory;rom_sha1=$romSha1;rom_zip_sha256=$romZipHash;mame_version='0.281';mame_sha256=$mameHash
  source_input_lua_sha256=$sourceInputHash;derived_input_lua_sha256=$derivedInputHash;input_lua_patch=$declaredPatch;replay_actions_sha256=$sourceReplayHash
  debug_sha256=(HashFile (Join-Path $run 'debug.log'));debugger_sha256=(HashFile (Join-Path $run 'debugger.cmd'));arguments_sha256=(HashFile (Join-Path $run 'arguments.json'));provenance_sha256=(HashFile (Join-Path $run 'provenance.json'))
  exit=0;conditions='fresh isolated cfg/nvram/inp/snap/state/diff; actual m4addr.zip read-only; MPU4_REPLAY=retained replay-actions.csv; no machine-state load, PTM/ACK/end-state injection or debugger memory write; stopped by first 5CD0 guard'
  event_cap=$eventCap;save_cap=$saveCap;hard_timeout_seconds=$hardTimeout;seconds_to_run=$secondsToRun
 }
 occurrence=[ordered]@{
  identity='fresh first FC4D->first 5CD0 occurrence in this run; absolute cycle/state is its own and is not fitted to capture36, gate28 or the historical nudge checkpoint'
  scope='single gap only; not a continuous lifecycle, autonomous IRQ cadence or later-delta recovery'
  entry='FC4D';entry_cycle=$fc.cycle;entry_s=$fc.s;entry_x=$fc.x;stop='5CD0';stop_cycle=$svc.cycle;stop_s=$svc.s;stop_ret=$svc.ret
  event_counts=[ordered]@{total=$events.Count;fc=$tagCounts['FC'];queue=$tagCounts['Q'];fe70=$tagCounts['FE70'];ff13=$tagCounts['FF13'];fec9=$tagCounts['FEC9'];stack_writes=$tagCounts['SW'];first_5cd0=$tagCounts['SVC']}
  actual_719b='00 at every logged event'
  historical_relation='fresh 0799..079D and 079F finals match the values analysis42 read from the capture41 queue->stop delta, but this run has its own instruction/cycle trace; it is not retroactive proof of capture36, whose ledger remains a snapshot net delta'
 }
 watchpoint=[ordered]@{
  address='0790';length=16;type='write';mame_version='0.281'
  semantics='MAME 0.281 installs a pre-commit write tap (points.cpp:231-237); debug_watchpoint::triggered sets wpaddr/wpdata and runs the action before the write commits (points.cpp:314-355). old=b@wpaddr is the pre-write byte; new=wpdata is the value about to be written; stop5cd0.bin is the independent after-state.'
  pc_semantics='M6809 read_opcode_arg increments PC during operand fetch (m6809.h:202); tap PC is post-fetch for PSHS. Stack pushes write low byte before high byte (m6809.lst PUSH_REGISTERS). BSR/JSR tap PC is the return address they push. Hardware IRQ stacking saves the interrupted PC and the full register set (base6x09.lst IRQ).'
  auxiliary_note='The printf field labelled st10 is w@(s+10); MAME parses 10 as hexadecimal, so it is the word at S+0x10, not S+0x0A. The IRQ resume PC is therefore taken from the watched 0797/0798 frame word, not from st10.'
  irq_vector=[ordered]@{address='FFF8';value='FE70'}
 }
 stack_window=[ordered]@{before_0790_079f=$stackWindowBefore;after_0790_079f=$stackWindowAfter}
 final_writers=@($finalWriters)
 writer_semantics=$writers
 stack_writes=$compactWrites
 anchors=$anchors
 validation=[ordered]@{
  validator='tools/Curate-StackWriterCapture43.ps1'
  actual_mame_sha256=$mameHash;actual_rom_zip_sha256=$romZipHash;actual_rom_entry_sha1=$romSha1
  source_campaign_pins_verified=$true;source_input_lua_sha256=$sourceInputHash;derived_input_only_declared_patch=$true
  debugger_allowlisted_breakpoints_watchpoint_reads_saves=$true;debugger_has_no_load_write_or_state_injection=$true
  arguments_isolated_noreadconfig_original_rom=$true;event_cap_enforced=$true;save_cap_enforced=$true;cycles_monotonic=$true
  actual_719b_logged_and_zero=$true
  old_bytes_match_fc4d_then_prior_new=$true
  final_0790_079f_matches_stop5cd0_for_all_16=$true
  target_0799_written=$true;target_079f_written=$true
  writer_opcodes_verified_against_original_rom=$true
  irq_frame_push_verified_from_9_watched_bytes_and_registers=$true
  prior_capture41_fixture_and_raw_unchanged=$true
  classification_basis='derived from the executed checks above; the free-text classification string is descriptive, not used as evidence'
 }
 next_task='Recover the foreground caller of the 7164/716A sequence and the helper/producer of the 5A07 JSR return path, then decide whether the next smallest evidence step is a 0770..078F watchpoint at the same gap or a static helper boundary; do not build runtime/adapter code from these stack bytes.'
 limits=@(
  'Single fresh FC4D->first 5CD0 gap; no continuous execution or autonomous IRQ cadence is claimed.',
  'The fresh occurrence is not capture36 and is not a retroactive capture36 traceback; final-value agreement is not occurrence identity.',
  'B/A/CC bytes of the IRQ frame at 078D..078F are outside the 0790..079F watchpoint; they are stated from the event registers and the unchanged stop snapshot, not from watched writes.',
  'The 55xx/716x caller context and downstream consumers of these stack words are not recovered here.'
 )
}
$directory=[IO.Path]::GetDirectoryName($target)
if(!(Test-Path -LiteralPath $directory)){New-Item -ItemType Directory -Path $directory -Force|Out-Null}
$json=$fixture|ConvertTo-Json -Depth 30
[IO.File]::WriteAllText($target,$json,[Text.UTF8Encoding]::new($false))
Write-Output ("Curated capture43 entry={0} cycle={1} stop={2} writes={3} final0799={4} final079f={5} sha256={6}" -f $fixture.occurrence.entry,$fixture.occurrence.entry_cycle,$fixture.occurrence.stop_cycle,$compactWrites.Count,$w799.pc,$w79F.pc,(HashFile $target))

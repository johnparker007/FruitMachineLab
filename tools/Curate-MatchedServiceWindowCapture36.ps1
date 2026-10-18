param(
    [string]$RunDirectory='artifacts/deepseek/capture-36/natural-service',
    [string]$RomPath='E:\Arcade\MAME0266\roms\m4addr.zip',
    [string]$MamePath='E:\Arcade\MAME0266\mame281.exe',
    [string]$SourceRun='artifacts/deepseek/gate-28/natural-service',
    [string]$FixturePath='evidence/mpu4/collection/matched-service-window-capture36.json',
    [string]$Capture33Fixture='evidence/mpu4/collection/fresh-tone-occurrence-capture33.json',
    [string]$Oracle31Fixture='evidence/mpu4/collection/fresh-tone-occurrence.json'
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath("$PSScriptRoot/..")
function Abs([string]$p){if([IO.Path]::IsPathRooted($p)){[IO.Path]::GetFullPath($p)}else{[IO.Path]::GetFullPath((Join-Path $root $p))}}
function HashBytes([byte[]]$bytes,[string]$algorithm='SHA256'){([BitConverter]::ToString([Security.Cryptography.HashAlgorithm]::Create($algorithm).ComputeHash($bytes))-replace '-','')}
function HashFile([string]$p,[string]$algorithm='SHA256'){HashBytes ([IO.File]::ReadAllBytes($p)) $algorithm}
function Fields([string]$line){$f=[ordered]@{};foreach($m in [regex]::Matches($line,'([A-Za-z0-9]+)=([0-9A-F]+)')){$f[$m.Groups[1].Value]=$m.Groups[2].Value};return $f}
function ReadRam([string]$name){$p=Join-Path $run $name;if(!(Test-Path -LiteralPath $p)){throw "Missing $name"};$b=[IO.File]::ReadAllBytes($p);if($b.Length -ne 0x800){throw "Non-2KB $name"};return ,$b}
function ByteAt([byte[]]$ram,[int]$offset){if($offset -lt 0 -or $offset -ge $ram.Length){throw ("Offset {0:X} outside 2KB" -f $offset)};return $ram[$offset].ToString('X2')}
function WordNum([byte[]]$ram,[int]$offset){if($offset -lt 0 -or $offset+1 -ge $ram.Length){throw ("Word offset {0:X} outside 2KB" -f $offset)};return (([int]$ram[$offset] -shl 8) -bor [int]$ram[$offset+1])}
function WordAt([byte[]]$ram,[int]$offset){WordNum $ram $offset|ForEach-Object{$_.ToString('X4')}}
function AssertByte([byte[]]$ram,[int]$offset,[string]$actual,[string]$label){$expected=ByteAt $ram $offset;if($actual -ne $expected){throw "$label byte at $('{0:X3}' -f $offset) is $actual, saved $expected"}}
function AssertWord([byte[]]$ram,[int]$offset,[string]$actual,[string]$label){$expected=WordAt $ram $offset;if($actual -ne $expected){throw "$label word at $('{0:X3}' -f $offset) is $actual, saved $expected"}}

$run=Abs $RunDirectory
$rom=Abs $RomPath
$mame=Abs $MamePath
$source=Abs $SourceRun
$target=Abs $FixturePath
$capture33=Abs $Capture33Fixture
$oracle31=Abs $Oracle31Fixture
foreach($p in @($run,$rom,$mame,$source,$capture33,$oracle31)){if(!(Test-Path -LiteralPath $p)){throw "Missing $p"}}

$mameExpected='0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A'
$romZipExpected='E2553AFA6B8E9DEF55BD920E4BED77A4324696C1E358B73BE70BFD2C58179989'
$romSha1Expected='402D1518BB78FDC489B06C2AABC771E5CE151847'
$sourceInputExpected='7C664323A5725E9FB294CB201B17B855564AF2E4A500560ED499F1EE45179D0D'
$sourceReplayExpected='4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D'
$derivedInputExpected='BC93C0699861A2B3DE402489DD09BEA95E0438C27A1F79698430B7E68A475957'
$capture33Expected='1D1167098AE50316081838CF74868EBC31E9485EDF7D81379F3F065930EB25E8'
$oracle31Expected='1D71F7088E2528C9D78B5174AD9EFAE99739754B56855086DA477A54C986B313'
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
if((HashFile $capture33) -ne $capture33Expected){throw 'Retained capture33 fixture changed'}
if((HashFile $oracle31) -ne $oracle31Expected){throw 'Retained oracle31 fixture changed'}

$sourceInput=Join-Path $source 'input.lua'
$sourceReplay=Join-Path $source 'replay-actions.csv'
if(!(Test-Path -LiteralPath $sourceInput) -or !(Test-Path -LiteralPath $sourceReplay)){throw 'Missing pinned source campaign'}
$sourceInputHash=HashFile $sourceInput
$sourceReplayHash=HashFile $sourceReplay
if($sourceInputHash -ne $sourceInputExpected){throw 'Pinned source input.lua hash differs'}
if($sourceReplayHash -ne $sourceReplayExpected){throw 'Pinned source replay-actions.csv hash differs'}
$runInput=Join-Path $run 'input.lua'
$runReplay=Join-Path $run 'replay-actions.csv'
if(!(Test-Path -LiteralPath $runInput) -or !(Test-Path -LiteralPath $runReplay)){throw 'Missing derived input/replay'}
$derivedInputHash=HashFile $runInput
$replayHash=HashFile $runReplay
if($replayHash -ne $sourceReplayExpected){throw 'Run replay is not the pinned source campaign'}

$sourceText=[IO.File]::ReadAllText($sourceInput)
$derivedText=[IO.File]::ReadAllText($runInput)
$assertBlockPattern="\r?\n if setup_callbacks_to_skip>0 then\r?\n  assert\(m\.time:as_double\(\)<0\.001,'Unexpected running frame during debugger setup'\)\r?\n  setup_callbacks_to_skip=setup_callbacks_to_skip-1\r?\n  return\r?\n end"
if([regex]::Matches($sourceText,'local setup_callbacks_to_skip=36').Count -ne 1){throw 'Pinned source does not contain exactly one declared skip guard'}
if([regex]::Matches($sourceText,$assertBlockPattern).Count -ne 1){throw 'Pinned source does not contain exactly one declared frame assertion block'}
$expectedDerived=$sourceText.Replace('local setup_callbacks_to_skip=36','local setup_callbacks_to_skip=0')
$expectedDerived=[regex]::Replace($expectedDerived,$assertBlockPattern,'')
if($expectedDerived -ceq $sourceText){throw 'Declared source patch did not change input.lua'}
if($derivedText -cne $expectedDerived){throw 'Derived input differs beyond the declared patch from the pinned source'}
if($derivedInputHash -ne $derivedInputExpected){throw 'Derived input hash differs from the declared patch result'}
if($derivedText -match 'setup_callbacks_to_skip=36'){throw 'Derived input retained the old skip guard'}
if($derivedText -notmatch 'setup_callbacks_to_skip=0'){throw 'Derived input lacks the declared skip guard'}
foreach($scriptText in @($sourceText,$derivedText)){
    if($scriptText -match 'mem:write|write_u8|write_u16'){throw 'Input campaign writes machine memory'}
}

$provenance=Get-Content (Join-Path $run 'provenance.json') -Raw|ConvertFrom-Json
$saveCap=[int]$provenance.save_cap
$eventCap=[int]$provenance.event_cap
$hardTimeout=[int]$provenance.hard_timeout_seconds
$secondsToRun=[int]$provenance.seconds_to_run
if($saveCap -lt 1 -or $saveCap -gt 128){throw 'Provenance save cap is invalid'}
if($eventCap -lt 1 -or $eventCap -gt 4096){throw 'Provenance event cap is invalid'}
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
if([string]$provenance.input_lua_patch -cne $declaredPatch){throw 'Provenance declares an input patch other than the pinned patch'}

$romDirectory=[IO.Path]::GetDirectoryName($rom)
$expectedArgs=@('m4addr','-noreadconfig','-rompath',$romDirectory,'-cfg_directory',(Join-Path $run 'cfg'),'-nvram_directory',(Join-Path $run 'nvram'),'-input_directory',(Join-Path $run 'inp'),'-snapshot_directory',(Join-Path $run 'snap'),'-comment_directory',(Join-Path $run 'comments'),'-state_directory',(Join-Path $run 'state'),'-diff_directory',(Join-Path $run 'diff'),'-autoboot_delay','0','-autoboot_script',(Join-Path $run 'input.lua'),'-debug','-debugger','windows','-debugscript',(Join-Path $run 'debugger.cmd'),'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run',"$secondsToRun")
$actualArgs=[object[]](Get-Content (Join-Path $run 'arguments.json') -Raw|ConvertFrom-Json)
if($actualArgs.Count -ne $expectedArgs.Count){throw 'Capture argument count differs from declared isolation contract'}
for($i=0;$i -lt $expectedArgs.Count;$i++){if([string]$actualArgs[$i] -cne [string]$expectedArgs[$i]){throw "Capture argument differs at index $i"}}
foreach($directory in @('cfg','nvram','inp','snap','comments','state','diff')){if(!(Test-Path -LiteralPath (Join-Path $run $directory))){throw "Missing isolated directory $directory"}}
foreach($arg in $actualArgs){if([string]$arg -match '^-(load|playback|cheat|autosave|rewind)$'){throw "Forbidden capture argument $arg"}}

$fmt='pc=%04X cyc=%016X s=%04X u=%04X x=%04X y=%04X a=%02X b=%02X dp=%02X cc=%02X 44=%02X 45=%04X 46=%04X 47=%04X 49=%04X 4b=%02X 4c=%02X 4d=%02X 4e=%02X 4f=%02X 50=%02X 27e=%04X 27f=%02X 280=%04X 281=%02X 282=%04X 283=%02X 719B=%02X st0=%04X st2=%04X st4=%04X st6=%04X st8=%04X st10=%04X ret=%04X'
$fmtArgs='pc,totalcycles,s,u,x,y,a,b,dp,cc,b@0x44,w@0x45,w@0x46,w@0x47,w@0x49,b@0x4b,b@0x4c,b@0x4d,b@0x4e,b@0x4f,b@0x50,w@0x27e,b@0x27f,w@0x280,b@0x281,w@0x282,b@0x283,b@0x719b,w@s,w@(s+2),w@(s+4),w@(s+6),w@(s+8),w@(s+10),w@s'
$addresses=@('fc','5a14','5a01','5c18','5a05','fe70','ff13','fec9','5cd0','fecc','fece','5d3b','5cf3','5e29','5e2c','5e6d','5a0a','5c7a','5a10','5a1c')
$saveNames=@('fc4d.bin','queue.bin','cancel.bin','return5a10.bin','return5a1c.bin')
$debuggerLines=@(Get-Content (Join-Path $run 'debugger.cmd')|Where-Object{$_ -ne ''})
$expectedDebuggerCount=10+1+7+$saveCap+1+$saveCap+1+10+18+2
if($debuggerLines.Count -ne $expectedDebuggerCount){throw "Debugger command count $($debuggerLines.Count) differs from declared capture script $expectedDebuggerCount"}
for($i=0;$i -lt 10;$i++){if($debuggerLines[$i] -cne "temp$i=0"){throw "Debugger temp$i initialization differs"}}
if($debuggerLines[$debuggerLines.Count-2] -cne 'go' -or $debuggerLines[$debuggerLines.Count-1] -cne 'quit'){throw 'Debugger does not end with go then quit'}
$addressCounts=@{}
$allowedSavePattern='^(fc4d|queue|cancel|return5a10|return5a1c)\.bin$|^sv-\d\d\.bin$|^fecc-\d\d\.bin$'
for($i=10;$i -lt $debuggerLines.Count-2;$i++){
    $line=$debuggerLines[$i]
    $m=[regex]::Match($line,'^bpset 0x([0-9a-f]+),([^,]+),\{(.*)\}$')
    if(!$m.Success){throw "Debugger line $i is not an allowlisted bpset"}
    $address=$m.Groups[1].Value.ToLowerInvariant()
    if($addresses -notcontains $address){throw "Debugger address $address is not allowlisted"}
    if(!$addressCounts.ContainsKey($address)){$addressCounts[$address]=0}
    $addressCounts[$address]++
    $condition=$m.Groups[2].Value
    if($condition -notmatch '^[A-Za-z0-9<>=!&| ]+$'){throw "Debugger condition at $address contains a non-allowlisted token"}
    if($condition -match '@'){throw "Debugger condition at $address reads memory"}
    $parts=@($m.Groups[3].Value -split ';')
    $pm=[regex]::Match($parts[0],'^printf "(\S+) (.+)",(.+)$')
    if(!$pm.Success){throw "Debugger action at $address does not start with an allowlisted printf"}
    $tag=$pm.Groups[1].Value
    $format=$pm.Groups[2].Value
    $arguments=$pm.Groups[3].Value
    if($tag -like 'OVERFLOW_*'){
        $expectedFormat='pc=%04X cyc=%016X s=%04X ret=%04X\n'
        $expectedArguments='pc,totalcycles,s,w@s'
    }else{
        $expectedFormat=$fmt
        $expectedArguments=$fmtArgs
        if($tag -eq '5d3b'){$expectedFormat+=' op=%02X';$expectedArguments+=',b@u'}
        $expectedFormat+='\n'
    }
    if($format -cne $expectedFormat){throw "Debugger printf format at $address differs from the allowlist"}
    if($arguments -cne $expectedArguments){throw "Debugger printf reads at $address differ from the allowlist"}
    if($parts.Count -lt 2){throw "Debugger action at $address lacks go or quit"}
    $index=1
    if($index -lt $parts.Count -and $parts[$index] -match '^save '){
        $sm=[regex]::Match($parts[$index],'^save ([^,]+),([^,]+),([^,]+)$')
        if(!$sm.Success){throw "Debugger save at $address is malformed"}
        if($sm.Groups[1].Value -notmatch $allowedSavePattern){throw "Debugger saves a non-allowlisted file $($sm.Groups[1].Value)"}
        if([Convert]::ToInt32($sm.Groups[2].Value,16) -ne 0 -or [Convert]::ToInt32($sm.Groups[3].Value,16) -ne 0x800){throw "Debugger save at $address saves a non-2KB region"}
        $index++
    }
    while($index -lt $parts.Count-1){
        if($parts[$index] -notmatch '^temp[0-9]+=temp[0-9]+\+1$' -and $parts[$index] -notmatch '^temp[0-9]+=[0-9]+$'){throw "Debugger action at $address contains an unexpected command $($parts[$index])"}
        $index++
    }
    $final=$parts[$parts.Count-1]
    if($final -ne 'go' -and $final -ne 'quit'){throw "Debugger action at $address does not end with go or quit"}
    foreach($forbidden in @('load','fill','dump','write','mem','cheat','watch','wp','rp','ep','trace','step','over','state','playback','reset')){
        if($parts -match "\b$forbidden\b"){throw "Debugger action at $address contains forbidden command $forbidden"}
    }
}
foreach($address in $addresses){
    if(!$addressCounts.ContainsKey($address)){throw "Debugger lacks allowlisted address $address"}
    $expected=if($address -eq 'fc'){1}elseif($address -eq '5cd0'){$saveCap+1}elseif($address -eq 'fecc'){$saveCap+2}else{2}
    if($addressCounts[$address] -ne $expected){throw "Debugger address $address has $($addressCounts[$address]) guards, expected $expected"}
}

$allLogLines=@(Get-Content (Join-Path $run 'debug.log'))
$events=New-Object System.Collections.Generic.List[object]
$previousCycle=$null
foreach($line in $allLogLines){
    if($line -notmatch '^([A-Za-z0-9_]+) pc='){continue}
    $tag=$Matches[1]
    if($tag -notmatch '^(fc|5a14|5a01|5c18|5a05|fe70|ff13|fec9|fece|5d3b|5cf3|5e29|5e2c|5e6d|5a0a|5c7a|5a10|5a1c|sv\d\d|fecc\d\d|OVERFLOW_.+)$'){throw "Unexpected event tag $tag"}
    if($tag -like 'OVERFLOW_*'){throw "Capture reported overflow event $tag"}
    $f=Fields $line
    foreach($key in @('pc','cyc','s','u','x','y','a','b','dp','cc','44','45','46','47','49','4b','4c','4d','4e','4f','50','27e','27f','280','281','282','283','719B','st0','st2','st4','st6','st8','st10','ret')){if(!$f.Contains($key)){throw "Event $tag lacks $key"}}
    $cycle=[Convert]::ToUInt64($f.cyc,16)
    if($previousCycle -ne $null -and $cycle -le $previousCycle){throw "Cycles are not strictly increasing at $tag"}
    $previousCycle=$cycle
    $expectedPc=if($tag -match '^sv\d\d$'){'5CD0'}elseif($tag -match '^fecc\d\d$'){'FECC'}else{$tag.ToUpperInvariant().PadLeft(4,'0')}
    if($f.pc -ne $expectedPc){throw "Event $tag PC is $($f.pc), expected $expectedPc"}
    $ramFile=$null
    $ram=$null
    if($tag -eq 'fc'){$ramFile='fc4d.bin'}
    elseif($tag -eq '5c18'){$ramFile='queue.bin'}
    elseif($tag -eq '5c7a'){$ramFile='cancel.bin'}
    elseif($tag -eq '5a10'){$ramFile='return5a10.bin'}
    elseif($tag -eq '5a1c'){$ramFile='return5a1c.bin'}
    elseif($tag -match '^sv(\d\d)$'){$ramFile="sv-$($Matches[1]).bin"}
    elseif($tag -match '^fecc(\d\d)$'){$ramFile="fecc-$($Matches[1]).bin"}
    if($ramFile){$ram=ReadRam $ramFile}
    $event=[ordered]@{tag=$tag;pc=$f.pc;cycle=$f.cyc;s=$f.s;u=$f.u;x=$f.x;y=$f.y;a=$f.a;b=$f.b;dp=$f.dp;cc=$f.cc;host=[ordered]@{'44'=$f.'44';'45'=$f.'45';'46'=$f.'46';'47'=$f.'47';'49'=$f.'49';'4b'=$f.'4b';'4c'=$f.'4c';'4d'=$f.'4d';'4e'=$f.'4e';'4f'=$f.'4f';'50'=$f.'50'};links=[ordered]@{'27e'=$f.'27e';'27f'=$f.'27f';'280'=$f.'280';'281'=$f.'281';'282'=$f.'282';'283'=$f.'283'};'719B'=$f.'719B';stack=[ordered]@{s0=$f.st0;s2=$f.st2;s4=$f.st4;s6=$f.st6;s8=$f.st8;s10=$f.st10};ret=$f.ret;ram_file=$ramFile;ram=$ram}
    $events.Add($event)|Out-Null
}
if($events.Count -gt $eventCap){throw "Event count $($events.Count) exceeds cap $eventCap"}
$tagCounts=@{}
foreach($event in $events){if(!$tagCounts.ContainsKey($event.tag)){$tagCounts[$event.tag]=0};$tagCounts[$event.tag]++}
foreach($t in @('fe70','ff13','fec9','fece','5d3b','5cf3','5e29','5e2c','5e6d','5a14','5a01','5a05','5a0a','5c18','5c7a','5a10','5a1c')){if(!$tagCounts.ContainsKey($t)){$tagCounts[$t]=0}}
foreach($required in @('fc','5a14','5a01','5c18','5a05','5c7a','5a10','5a1c')){if($tagCounts[$required] -ne 1){throw "Expected exactly one $required event, got $($tagCounts[$required])"}}
if($events[0].tag -ne 'fc'){throw 'First event is not FC4D'}
if($events[$events.Count-1].tag -ne '5a1c'){throw 'Last event is not 5A1C'}
$entries=@($events|Where-Object{$_.tag -match '^sv\d\d$'})
$returns=@($events|Where-Object{$_.tag -match '^fecc\d\d$'})
if($entries.Count -ne $returns.Count){throw "Service entries $($entries.Count) differ from returns $($returns.Count)"}
if($entries.Count -gt $saveCap){throw "Service entries exceed save cap $saveCap"}
if($returns.Count -gt $saveCap){throw "Service returns exceed save cap $saveCap"}
$svFiles=@(Get-ChildItem -LiteralPath $run -Filter 'sv-*.bin'|ForEach-Object{$_.Name}|Sort-Object)
$feccFiles=@(Get-ChildItem -LiteralPath $run -Filter 'fecc-*.bin'|ForEach-Object{$_.Name}|Sort-Object)
if($svFiles.Count -ne $entries.Count){throw "Saved service entries $($svFiles.Count) differ from logged entries $($entries.Count)"}
if($feccFiles.Count -ne $returns.Count){throw "Saved service returns $($feccFiles.Count) differ from logged returns $($returns.Count)"}
for($i=0;$i -lt $entries.Count;$i++){if($svFiles[$i] -ne ("sv-{0:D2}.bin" -f $i)){throw "Service save sequence differs at index $i"}}
for($i=0;$i -lt $returns.Count;$i++){if($feccFiles[$i] -ne ("fecc-{0:D2}.bin" -f $i)){throw "Return save sequence differs at index $i"}}

$combined=@($entries)+@($returns)
$combined=@($combined|Sort-Object {[Convert]::ToUInt64($_.cycle,16)})
$stack=New-Object System.Collections.Stack
$pairs=New-Object System.Collections.Generic.List[object]
foreach($event in $combined){
    if($event.tag -match '^sv\d\d$'){
        $event['depth']=$stack.Count+1
        $stack.Push($event)
    }else{
        if($stack.Count -eq 0){throw "Return $($event.tag) has no open service entry"}
        $entry=$stack.Pop()
        $expectedS=(([Convert]::ToInt32($entry.s,16)+2) -band 0xFFFF).ToString('X4')
        if($event.s -ne $expectedS){throw "Wrong matched S: $($event.tag) S=$($event.s), entry $($entry.tag) S=$($entry.s), expected $expectedS"}
        if($entry.ret -ne 'FECC'){throw "Service entry $($entry.tag) return word is $($entry.ret), expected FECC"}
        if($event.ret -notmatch '^C[0-9A-F]{3}$'){throw "Return $($event.tag) stack top $($event.ret) is not an IRQ frame"}
        $fec9=@($events|Where-Object{$_.tag -eq 'fec9' -and $_.s -eq $event.s -and [Convert]::ToUInt64($_.cycle,16) -lt [Convert]::ToUInt64($entry.cycle,16)})|Select-Object -Last 1
        if(!$fec9){throw "No FEC9 wrapper with S=$($event.s) before $($entry.tag)"}
        if((([Convert]::ToInt32($fec9.s,16)-2) -band 0xFFFF).ToString('X4') -ne $entry.s){throw "FEC9 wrapper S does not precede service entry $($entry.tag) by 2"}
        if($event.host.'44' -ne '00' -and $entry.depth -eq 1){throw "Outer service pair $($entry.tag)/$($event.tag) does not return with 0044=00"}
        $pair=[ordered]@{
            depth=$entry.depth
            nested=($entry.depth -gt 1)
            entry_tag=$entry.tag;return_tag=$event.tag
            entry_cycle=$entry.cycle;return_cycle=$event.cycle
            entry_s=$entry.s;return_s=$event.s
            entry_return_word=$entry.ret;return_stack_word=$event.ret
            host_44_entry=$entry.host.'44';host_44_return=$event.host.'44'
            resume_pc=(WordAt $event.ram ([Convert]::ToInt32($event.s,16)+0xA))
            fro_cycle=$fec9.cycle
            entry=$entry;return=$event
        }
        $pairs.Add($pair)|Out-Null
    }
}
if($stack.Count -ne 0){throw "Unmatched service entries: $($stack.Count)"}
if($pairs.Count -ne $entries.Count){throw 'Not every service entry was paired'}
$outerPairs=@($pairs|Where-Object{!$_.nested})
$nestedPairs=@($pairs|Where-Object{$_.nested})
if($outerPairs.Count -lt 1){throw 'No outer service completion pair was captured'}

function CheckFrame([object]$event,[byte[]]$ram,[string]$label){
    $sp=[Convert]::ToInt32($event.s,16)
    AssertByte $ram 0x44 $event.host.'44' "$label host"
    AssertWord $ram 0x45 $event.host.'45' "$label host"
    AssertWord $ram 0x46 $event.host.'46' "$label host"
    AssertWord $ram 0x47 $event.host.'47' "$label host"
    AssertWord $ram 0x49 $event.host.'49' "$label host"
    foreach($offset in @(0x4b,0x4c,0x4d,0x4e,0x4f,0x50)){AssertByte $ram $offset $event.host[$offset.ToString('x')] "$label host"}
    AssertWord $ram 0x27e $event.links.'27e' "$label link"
    AssertByte $ram 0x27f $event.links.'27f' "$label link"
    AssertWord $ram 0x280 $event.links.'280' "$label link"
    AssertByte $ram 0x281 $event.links.'281' "$label link"
    if([Convert]::ToInt32($event.links.'282',16) -ne (WordNum $ram 0x282)){throw "$label link 282 differs"}
    AssertByte $ram 0x283 $event.links.'283' "$label link"
    if($sp+10 -ge $ram.Length){throw "$label stack pointer outside 2KB"}
    AssertWord $ram $sp $event.stack.s0 "$label stack"
    AssertWord $ram ($sp+2) $event.stack.s2 "$label stack"
    AssertWord $ram ($sp+4) $event.stack.s4 "$label stack"
    AssertWord $ram ($sp+6) $event.stack.s6 "$label stack"
    AssertWord $ram ($sp+8) $event.stack.s8 "$label stack"
    AssertWord $ram ($sp+0x10) $event.stack.s10 "$label stack"
    if((WordAt $ram $sp) -ne $event.ret){throw "$label ret word differs from saved 2KB"}
}
foreach($event in $events){if($event.ram){CheckFrame $event $event.ram $event.tag}}

$fc=$events|Where-Object{$_.tag -eq 'fc'}|Select-Object -First 1
$queue=$events|Where-Object{$_.tag -eq '5c18'}|Select-Object -First 1
$cancel=$events|Where-Object{$_.tag -eq '5c7a'}|Select-Object -First 1
$ret10=$events|Where-Object{$_.tag -eq '5a10'}|Select-Object -First 1
$ret1c=$events|Where-Object{$_.tag -eq '5a1c'}|Select-Object -First 1
$firstFec9=$events|Where-Object{$_.tag -eq 'fec9'}|Select-Object -First 1
$firstFece=$events|Where-Object{$_.tag -eq 'fece'}|Select-Object -First 1
if($fc.y -ne 'FC4D' -or $fc.x -ne '8132'){throw 'FC4D entry registers differ from the known entry shape'}
if($queue.ret -ne '59E9'){throw 'Queue continuation differs'}
if($cancel.ret -ne '5A10'){throw 'Cancel continuation differs'}
if($fc.host.'47' -ne '0000' -or $fc.host.'49' -ne '01A0' -or $fc.host.'4d' -ne '00'){throw 'FC4D initial list differs'}
if($queue.host.'47' -ne '0000' -or $queue.host.'49' -ne '01A0' -or $queue.host.'4d' -ne '31'){throw 'Queue precondition differs'}
if($ret1c.host.'47' -ne '0000' -or $ret1c.host.'49' -ne '01A0' -or $ret1c.host.'4d' -ne '00'){throw 'Return state differs'}
if($ret1c.x -ne '59EB' -or $ret1c.y -ne 'FC4F'){throw 'Return registers differ'}
$firstPair=$outerPairs|Sort-Object {[Convert]::ToUInt64($_.entry_cycle,16)}|Select-Object -First 1
$firstEntry=$firstPair.entry
$firstReturn=$firstPair.return
if($firstEntry.tag -ne 'sv00' -or $firstReturn.tag -ne 'fecc00'){throw 'First outer service pair is not sv00/fecc00'}
$phaseNames=@('fc4d->5a14','5a14->5a01','5a01->5c18','5c18->5a05','5a05->5a0a','5a0a->5c7a')
$phaseTags=@('5a14','5a01','5c18','5a05','5a0a','5c7a')
$phaseCycles=[ordered]@{}
for($i=0;$i -lt $phaseNames.Count;$i++){
    $from=if($i -eq 0){$fc}else{$events|Where-Object{$_.tag -eq $phaseTags[$i-1]}|Select-Object -First 1}
    $to=$events|Where-Object{$_.tag -eq $phaseTags[$i]}|Select-Object -First 1
    $phaseCycles[$phaseNames[$i]]=[Convert]::ToUInt64($to.cycle,16)-[Convert]::ToUInt64($from.cycle,16)
}
$sound719b=@($events|ForEach-Object{$_.'719B'}|Sort-Object -Unique)
$all719bZero=(@($sound719b|Where-Object{$_ -ne '00'}).Count -eq 0)

$compactEvents=@()
foreach($event in $events){
    $compactEvents+=[ordered]@{tag=$event.tag;pc=$event.pc;cycle=$event.cycle;s=$event.s;u=$event.u;x=$event.x;y=$event.y;a=$event.a;b=$event.b;'44'=$event.host.'44';'45'=$event.host.'45';'47'=$event.host.'47';'49'=$event.host.'49';'4b'=$event.host.'4b';'4c'=$event.host.'4c';'4d'=$event.host.'4d';'719B'=$event.'719B';ret=$event.ret;ram_file=$event.ram_file}
}
$pairOutput=@()
foreach($pair in $pairs){
    $entry=$pair.entry;$return=$pair.return
    $entryOut=[ordered]@{tag=$entry.tag;pc=$entry.pc;cycle=$entry.cycle;s=$entry.s;u=$entry.u;x=$entry.x;y=$entry.y;a=$entry.a;b=$entry.b;host=$entry.host;links=$entry.links;'719B'=$entry.'719B';stack=$entry.stack;ret=$entry.ret;ram_file=$entry.ram_file;ram_sha256=(HashBytes $entry.ram);ram_hex=([BitConverter]::ToString($entry.ram)-replace '-','')}
    $returnOut=[ordered]@{tag=$return.tag;pc=$return.pc;cycle=$return.cycle;s=$return.s;u=$return.u;x=$return.x;y=$return.y;a=$return.a;b=$return.b;host=$return.host;links=$return.links;'719B'=$return.'719B';stack=$return.stack;ret=$return.ret;ram_file=$return.ram_file;ram_sha256=(HashBytes $return.ram);ram_hex=([BitConverter]::ToString($return.ram)-replace '-','')}
    $pairOutput+=[ordered]@{depth=$pair.depth;nested=$pair.nested;entry_tag=$pair.entry_tag;return_tag=$pair.return_tag;entry_cycle=$pair.entry_cycle;return_cycle=$pair.return_cycle;entry_s=$pair.entry_s;return_s=$pair.return_s;entry_return_word=$pair.entry_return_word;return_stack_word=$pair.return_stack_word;host_44_entry=$pair.host_44_entry;host_44_return=$pair.host_44_return;resume_pc=$pair.resume_pc;fec9_cycle=$pair.fro_cycle;entry=$entryOut;return=$returnOut}
}
$q=@($events|Where-Object{$_.tag -eq '5c18'}|Select-Object -First 1)
$cx=@($events|Where-Object{$_.tag -eq '5c7a'}|Select-Object -First 1)
$r10=@($events|Where-Object{$_.tag -eq '5a10'}|Select-Object -First 1)
$r1c=@($events|Where-Object{$_.tag -eq '5a1c'}|Select-Object -First 1)
$m14=$events|Where-Object{$_.tag -eq '5a14'}|Select-Object -First 1
$m01=$events|Where-Object{$_.tag -eq '5a01'}|Select-Object -First 1
$m05=$events|Where-Object{$_.tag -eq '5a05'}|Select-Object -First 1
$m0a=$events|Where-Object{$_.tag -eq '5a0a'}|Select-Object -First 1
function FrameOut([object]$event){
    $o=[ordered]@{tag=$event.tag;pc=$event.pc;cycle=$event.cycle;s=$event.s;u=$event.u;x=$event.x;y=$event.y;a=$event.a;b=$event.b;host=$event.host;links=$event.links;'719B'=$event.'719B';stack=$event.stack;ret=$event.ret;ram_file=$event.ram_file}
    if($event.ram){$o.ram_sha256=(HashBytes $event.ram);$o.ram_hex=([BitConverter]::ToString($event.ram)-replace '-','')}
    return $o
}

$fixture=[ordered]@{
 schema='matched-service-window-capture36/1'
 classification='controlled replay natural: one first complete FC4D->5A1C occurrence from the retained recorded physical-input campaign; original reset ROM/settings/NVRAM; no RAM/CPU/device/PTM/ACK/end-state injection; debugger breakpoints/reads/2KB saves only'
 source=[ordered]@{
  run='artifacts/deepseek/capture-36/natural-service'
  rom_sha1=$romSha1;rom_zip_sha256=$romZipHash
  mame_version='0.281';mame_sha256=$mameHash
  source_input_lua_sha256=$sourceInputHash
  derived_input_lua_sha256=$derivedInputHash
  input_lua_patch=$declaredPatch
  replay_actions_sha256=$replayHash
  debug_sha256=(HashFile (Join-Path $run 'debug.log'))
  debugger_sha256=(HashFile (Join-Path $run 'debugger.cmd'))
  arguments_sha256=(HashFile (Join-Path $run 'arguments.json'))
  provenance_sha256=(HashFile (Join-Path $run 'provenance.json'))
  exit=0
  conditions='fresh isolated cfg/nvram/inp/snap/state/diff; actual m4addr.zip read-only; MPU4_REPLAY=retained replay-actions.csv; no machine-state load, PTM/ACK/end-state injection or debugger memory write; capture stopped by first 5A1C guard'
  event_cap=$eventCap;save_cap=$saveCap;hard_timeout_seconds=$hardTimeout
 }
 occurrence=[ordered]@{
  identity='first complete FC4D->5A1C in this fresh run; absolute cycle/state is its own and is not fitted or relabelled from capture33, gate28 or any later occurrence'
  scope='single-occurrence event window and matched service pairs; not a continuous C# execution or autonomous IRQ cadence'
  entry='FC4D';entry_cycle=$fc.cycle;entry_x=$fc.x;entry_s=$fc.s
  stop='5A1C';stop_cycle=$ret1c.cycle;stop_state=[ordered]@{'47'=$ret1c.host.'47';'49'=$ret1c.host.'49';'4b'=$ret1c.host.'4b';'4c'=$ret1c.host.'4c';'4d'=$ret1c.host.'4d'}
  phase_cycles=$phaseCycles
  event_counts=[ordered]@{total=$events.Count;fe70=$tagCounts['fe70'];ff13=$tagCounts['ff13'];fec9=$tagCounts['fec9'];service_entries=$entries.Count;service_returns=$returns.Count;fece=$tagCounts['fece'];stream_5d3b=$tagCounts['5d3b'];stream_5cf3=$tagCounts['5cf3'];stream_5e29=$tagCounts['5e29'];stream_5e2c=$tagCounts['5e2c'];stream_5e6d=$tagCounts['5e6d'];foreground_5a14=$tagCounts['5a14'];foreground_5a01=$tagCounts['5a01'];foreground_5a05=$tagCounts['5a05'];foreground_5a0a=$tagCounts['5a0a'];queue=$tagCounts['5c18'];cancel=$tagCounts['5c7a'];return_5a10=$tagCounts['5a10'];return_5a1c=$tagCounts['5a1c']}
  services=[ordered]@{total=$pairs.Count;outer=$outerPairs.Count;nested=$nestedPairs.Count;first_outer_entry=$firstEntry.tag;first_outer_entry_cycle=$firstEntry.cycle;first_outer_return=$firstReturn.tag;first_outer_return_cycle=$firstReturn.cycle;pairing='LIFO by stack pointer: return.s == entry.s+2, return word at entry.s is FECC, FEC9 wrapper at entry.s+2, and the return stack top is an IRQ frame (C0xx); nesting is entry depth > 1. No first-FECC flag is used.'}
  first_fec9_cycle=$firstFec9.cycle;first_fece_cycle=$firstFece.cycle
  stack_note='Raw st0..st10 are w@s..w@(s+0x10), because MAME debugger expressions treat bare 10 as hexadecimal. The IRQ-frame PC is read separately at S+0xA from each saved return 2KB and recorded as service_pairs[].resume_pc.'
  anchors=[ordered]@{fc=(FrameOut $fc);marker_5a14=(FrameOut $m14);marker_5a01=(FrameOut $m01);queue=(FrameOut $q[0]);marker_5a05=(FrameOut $m05);first_fec9=(FrameOut $firstFec9);first_outer_entry=(FrameOut $firstEntry);first_outer_return=(FrameOut $firstReturn);first_fece=(FrameOut $firstFece);marker_5a0a=(FrameOut $m0a);cancel=(FrameOut $cx[0]);return_5a10=(FrameOut $r10[0]);return_5a1c=(FrameOut $r1c[0])}
  event_window=$compactEvents
  sound_719b_values=$sound719b;all_719b_zero=$all719bZero
 }
 service_pairs=$pairOutput
 validation=[ordered]@{
  validator='tools/Curate-MatchedServiceWindowCapture36.ps1'
  actual_mame_sha256=$mameHash
  actual_rom_zip_sha256=$romZipHash
  actual_rom_entry_sha1=$romSha1
  source_campaign_pins_verified=$true
  source_input_lua_sha256=$sourceInputHash
  derived_input_only_declared_patch=$true
  debugger_allowlisted_reads_saves_tempguards=$true
  debugger_has_no_load_write_or_state_injection=$true
  arguments_isolated_noreadconfig_original_rom=$true
  frames_pc_tag_and_strict_cycle_order=$true
  event_cap_enforced=$true
  save_cap_enforced=$true
  all_logged_service_entries_saved=$true
  all_logged_service_returns_saved=$true
  stack_discipline_pairing=$true
  fec9_wrapper_matches_each_pair=$true
  saved_ram_cross_checked=@('fc','5c18','sv*','fecc*','5c7a','5a10','5a1c')
  nested_vs_outer_distinguished_by_depth=$true
  retained_capture33_fixture_sha256=$capture33Expected
  retained_oracle31_fixture_sha256=$oracle31Expected
  classification_basis='derived from the executed checks above; the free-text classification string is descriptive, not used as evidence'
 }
 next_task=[ordered]@{
  smallest_component='Seed retained sv-00.bin at 5CD0 (S=078B, U=0672, X=0366, Y=0000, A=05, B=0B, return FECC), run AddersNativeSound.BeginService, and compare the complete 2KB result plus 0044/0047/0049/004B/027E against fecc-00.bin. Repeat for every captured outer pair in cycle order.'
  continuous_same_state_adapter='Apply the captured 25 ordered outer service call/return pairs and the 5D3B/5CF3/5E2C stream events between first FECC and 5A0A, using each saved return 2KB only as the next captured state; compare every saved before/after frame. This is a captured-component sequence, not autonomous IRQ timing.'
  missing_gaps=@('No nested 5CD0 service was observed in this occurrence: all 25 pairs are depth 1. The capture33 nested FECC remains a separate anchor, not a matched outer completion.','Stream callbacks 5E29 and 5E6D were not hit in this window; only 5E2C was observed.','The 25 service intervals are captured, but the exact foreground writes and stream state between them are not replayed by a headless adapter.','No continuous C# execution, autonomous IRQ cadence, timer1 ownership, audio, Live ownership or hardware claim is made.')
 }
 limits=@('Single-occurrence event window and matched service pairs only; no continuous FC4D->5A1C lifecycle is claimed.','No nested 5CD0 service was observed in this occurrence; capture33 nested anchors remain separate and are not relabelled.','Stream callbacks 5E29/5E6D were not hit; only 5E2C was observed.','No stream-command coverage beyond the events logged in this window, no timer1 cadence, no outer-IRQ ownership, no 6B4D/58BB, no finish CPU budget, no audio, no Live ownership and no hardware claim.','actions.csv has only its header because the first complete occurrence and guarded stop preceded the later paid_start action; replay-actions.csv is the authoritative verified input sequence.')
}
$directory=[IO.Path]::GetDirectoryName($target)
if(!(Test-Path -LiteralPath $directory)){New-Item -ItemType Directory -Path $directory -Force|Out-Null}
$json=$fixture|ConvertTo-Json -Depth 30
[IO.File]::WriteAllText($target,$json,[Text.UTF8Encoding]::new($false))
Write-Output ("Curated capture36 entry={0} cycle={1} events={2} pairs={3} outer={4} nested={5} sha256={6}" -f $fixture.occurrence.entry,$fixture.occurrence.entry_cycle,$events.Count,$pairs.Count,$outerPairs.Count,$nestedPairs.Count,(HashFile $target))

param(
    [string]$RunDirectory='artifacts/deepseek/capture-33/natural-service',
    [string]$RomPath='E:\Arcade\MAME0266\roms\m4addr.zip',
    [string]$MamePath='E:\Arcade\MAME0266\mame281.exe',
    [string]$SourceRun='artifacts/deepseek/gate-28/natural-service',
    [string]$FixturePath='evidence/mpu4/collection/fresh-tone-occurrence-capture33.json'
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath("$PSScriptRoot/..")
function Abs([string]$p){if([IO.Path]::IsPathRooted($p)){[IO.Path]::GetFullPath($p)}else{[IO.Path]::GetFullPath((Join-Path $root $p))}}
function HashBytes([byte[]]$bytes,[string]$algorithm='SHA256'){([BitConverter]::ToString([Security.Cryptography.HashAlgorithm]::Create($algorithm).ComputeHash($bytes))-replace '-','')}
function HashFile([string]$p,[string]$algorithm='SHA256'){HashBytes ([IO.File]::ReadAllBytes($p)) $algorithm}
function HashText([string]$text){HashBytes ([Text.UTF8Encoding]::new($false).GetBytes($text))}
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
if(!(Test-Path -LiteralPath $run)){throw 'Missing run'}
if(!(Test-Path -LiteralPath $rom)){throw 'Missing ROM zip'}
if(!(Test-Path -LiteralPath $mame)){throw 'Missing MAME executable'}
if(!(Test-Path -LiteralPath $source)){throw 'Missing source campaign'}

$mameExpected='0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A'
$romZipExpected='E2553AFA6B8E9DEF55BD920E4BED77A4324696C1E358B73BE70BFD2C58179989'
$romSha1Expected='402D1518BB78FDC489B06C2AABC771E5CE151847'
$sourceInputExpected='7C664323A5725E9FB294CB201B17B855564AF2E4A500560ED499F1EE45179D0D'
$sourceReplayExpected='4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D'
$derivedInputExpected='BC93C0699861A2B3DE402489DD09BEA95E0438C27A1F79698430B7E68A475957'
$declaredPatch='removed only the debugger-startup frame assertion and set its skip guard to zero; replay/physical-input/event code unchanged'
$secondsToRun=430

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
if([int]$provenance.seconds_to_run -ne $secondsToRun){throw 'Provenance seconds_to_run differs'}
if([int]$provenance.hard_timeout_seconds -ne 600){throw 'Provenance hard timeout differs'}
if([string]$provenance.mame_version -ne '0.281'){throw 'Provenance MAME version differs'}
if([string]$provenance.rom_entry -ne 'a6ls.p1' -or [int]$provenance.rom_bytes -ne 0x10000){throw 'Provenance ROM entry differs'}
if([string]$provenance.input_lua_patch -cne $declaredPatch){throw 'Provenance declares an input patch other than the pinned patch'}

$romDirectory=[IO.Path]::GetDirectoryName($rom)
$expectedArgs=@('m4addr','-noreadconfig','-rompath',$romDirectory,'-cfg_directory',(Join-Path $run 'cfg'),'-nvram_directory',(Join-Path $run 'nvram'),'-input_directory',(Join-Path $run 'inp'),'-snapshot_directory',(Join-Path $run 'snap'),'-comment_directory',(Join-Path $run 'comments'),'-state_directory',(Join-Path $run 'state'),'-diff_directory',(Join-Path $run 'diff'),'-autoboot_delay','0','-autoboot_script',(Join-Path $run 'input.lua'),'-debug','-debugger','windows','-debugscript',(Join-Path $run 'debugger.cmd'),'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run',"$secondsToRun")
$actualArgs=[object[]](Get-Content (Join-Path $run 'arguments.json') -Raw|ConvertFrom-Json)
if($actualArgs.Count -ne $expectedArgs.Count){throw 'Capture argument count differs from declared isolation contract'}
for($i=0;$i -lt $expectedArgs.Count;$i++){if([string]$actualArgs[$i] -cne [string]$expectedArgs[$i]){throw "Capture argument differs at index $i"}}
foreach($directory in @('cfg','nvram','inp','snap','comments','state','diff')){if(!(Test-Path -LiteralPath (Join-Path $run $directory))){throw "Missing isolated directory $directory"}}

$guardSpec=@(
    [pscustomobject]@{Tag='fc';Addr='fc';Cond='temp0==0 && y==0xfc4d';Save='fc4d.bin';Set='temp0=1';Quit=$false},
    [pscustomobject]@{Tag='5a14';Addr='5a14';Cond='temp0==1';Save=$null;Set=$null;Quit=$false},
    [pscustomobject]@{Tag='5a01';Addr='5a01';Cond='temp0==1';Save=$null;Set=$null;Quit=$false},
    [pscustomobject]@{Tag='5c18';Addr='5c18';Cond='temp0==1 && temp1==0';Save='queue.bin';Set='temp1=1';Quit=$false},
    [pscustomobject]@{Tag='5a05';Addr='5a05';Cond='temp0==1';Save=$null;Set=$null;Quit=$false},
    [pscustomobject]@{Tag='fec9';Addr='fec9';Cond='temp0==1 && temp1==1 && temp2==0';Save='fec9.bin';Set='temp2=1';Quit=$false},
    [pscustomobject]@{Tag='5cd0';Addr='5cd0';Cond='temp2==1 && temp3==0';Save='sv.bin';Set='temp3=1';Quit=$false},
    [pscustomobject]@{Tag='fecc';Addr='fecc';Cond='temp3==1 && temp4==0';Save='fecc.bin';Set='temp4=1';Quit=$false},
    [pscustomobject]@{Tag='fece';Addr='fece';Cond='temp4==1 && temp5==0';Save='fece.bin';Set='temp5=1';Quit=$false},
    [pscustomobject]@{Tag='5a0a';Addr='5a0a';Cond='temp0==1';Save=$null;Set=$null;Quit=$false},
    [pscustomobject]@{Tag='5c7a';Addr='5c7a';Cond='temp0==1 && temp1==1 && temp2==1 && temp3==1 && temp4==1 && temp5==1 && temp6==0 && x==0x59eb && w@0x47==0x1a0';Save='cancel.bin';Set='temp6=1';Quit=$false},
    [pscustomobject]@{Tag='5a10';Addr='5a10';Cond='temp6==1 && temp7==0';Save='return5a10.bin';Set='temp7=1';Quit=$false},
    [pscustomobject]@{Tag='5a1c';Addr='5a1c';Cond='temp7==1 && temp8==0';Save='return5a1c.bin';Set='temp8=1';Quit=$true}
)
$fmtArgs='pc,totalcycles,s,u,x,y,a,b,dp,cc,b@0x44,w@0x45,w@0x46,w@0x47,w@0x49,b@0x4b,b@0x4c,b@0x4d,b@0x4e,b@0x4f,b@0x50,w@0x27e,b@0x27f,w@0x280,b@0x281,w@0x282,b@0x283,b@0x719b,w@s,w@(s+2),w@(s+4),w@(s+6)'
$debuggerLines=@(Get-Content (Join-Path $run 'debugger.cmd')|Where-Object{$_ -ne ''})
if($debuggerLines.Count -ne (9+$guardSpec.Count+2)){throw 'Debugger command count differs from declared capture script'}
for($i=0;$i -lt 9;$i++){if($debuggerLines[$i] -cne "temp$i=0"){throw "Debugger temp$i initialization differs"}}
for($i=0;$i -lt $guardSpec.Count;$i++){
    $spec=$guardSpec[$i]
    $line=$debuggerLines[9+$i]
    $m=[regex]::Match($line,'^bpset 0x([0-9a-fA-F]+),([^,]+),\{(.*)\}$')
    if(!$m.Success){throw "Debugger guard $($spec.Tag) is not an allowlisted bpset"}
    if($m.Groups[1].Value.ToLowerInvariant() -ne $spec.Addr){throw "Debugger guard $($spec.Tag) address differs"}
    if($m.Groups[2].Value -cne $spec.Cond){throw "Debugger guard $($spec.Tag) condition differs"}
    $parts=@($m.Groups[3].Value -split ';')
    $pm=[regex]::Match($parts[0],'^printf "([^"]*)",(.+)$')
    if(!$pm.Success){throw "Debugger guard $($spec.Tag) does not start with an allowed printf"}
    if($pm.Groups[2].Value -cne $fmtArgs){throw "Debugger guard $($spec.Tag) reads differ from the declared allowlist"}
    $format=$pm.Groups[1].Value
    $normalized=[regex]::Replace($format,'282=%0[24]X','282=%WORD%')
    $expectedFormat="$($spec.Tag) pc=%04X cyc=%016X s=%04X u=%04X x=%04X y=%04X a=%02X b=%02X dp=%02X cc=%02X 44=%02X 45=%04X 46=%04X 47=%04X 49=%04X 4b=%02X 4c=%02X 4d=%02X 4e=%02X 4f=%02X 50=%02X 27e=%04X 27f=%02X 280=%04X 281=%02X 282=%WORD% 283=%02X 719B=%02X st0=%04X st2=%04X st4=%04X st6=%04X\n"
    if($normalized -cne $expectedFormat){throw "Debugger guard $($spec.Tag) format differs from the declared allowlist"}
    $index=1
    if($spec.Save){
        if($index -ge $parts.Count){throw "Debugger guard $($spec.Tag) lacks its declared save"}
        $sm=[regex]::Match($parts[$index],'^save ([^,]+),([^,]+),([^,]+)$')
        if(!$sm.Success){throw "Debugger guard $($spec.Tag) has an unexpected pre-save command"}
        if($sm.Groups[1].Value -cne $spec.Save){throw "Debugger guard $($spec.Tag) saves the wrong file"}
        if([Convert]::ToInt32($sm.Groups[2].Value,16) -ne 0 -or [Convert]::ToInt32($sm.Groups[3].Value,16) -ne 0x800){throw "Debugger guard $($spec.Tag) saves a non-2KB region"}
        $index++
    }
    if($spec.Set){
        if($index -ge $parts.Count -or $parts[$index] -cne $spec.Set){throw "Debugger guard $($spec.Tag) lacks its declared temp update"}
        $index++
    }
    $final=if($spec.Quit){'quit'}else{'go'}
    if($index -ge $parts.Count -or $parts[$index] -cne $final){throw "Debugger guard $($spec.Tag) lacks its declared $final"}
    if($index -ne $parts.Count-1){throw "Debugger guard $($spec.Tag) contains extra commands"}
}
if($debuggerLines[9+$guardSpec.Count] -cne 'go' -or $debuggerLines[9+$guardSpec.Count+1] -cne 'quit'){throw 'Debugger does not end with go then quit'}

$allLogLines=@(Get-Content (Join-Path $run 'debug.log'))
$tags=@($guardSpec|ForEach-Object{$_.Tag})
$logLines=@($allLogLines|Where-Object{$_ -match '^(fc|5a14|5a01|5c18|5a05|fec9|5cd0|fecc|fece|5a0a|5c7a|5a10|5a1c) '})
if($logLines.Count -ne $tags.Count){throw "Expected $($tags.Count) anchors, got $($logLines.Count)"}
$keyRegs=@{
    'fc'=@{s='07AA';u='0672';x='8132';y='FC4D';a='00';b='FF'}
    '5a14'=@{s='07A6';u='0672';x='80A6';y='FC4F';a='00';b='FF'}
    '5a01'=@{s='07A0';u='0672';x='80A6';y='FC4F';a='91';b='02'}
    '5c18'=@{s='0798';u='0672';x='59EB';y='FC4F';a='91';b='31'}
    '5a05'=@{s='07A0';u='0672';x='80A6';y='FC4F';a='91';b='91'}
    'fec9'=@{s='078D';u='0672';x='0366';y='0000';a='05';b='0B'}
    '5cd0'=@{s='078B';u='0672';x='0366';y='0000';a='05';b='0B'}
    'fecc'=@{s='077F';u='59F2';x='0366';y='0000';a='01';b='0B'}
    'fece'=@{s='077F';u='59F2';x='0366';y='0000';a='01';b='0B'}
    '5a0a'=@{s='07A0';u='0672';x='80A6';y='FC4F';a='91';b='02'}
    '5c7a'=@{s='079E';u='0672';x='59EB';y='FC4F';a='91';b='02'}
    '5a10'=@{s='07A0';u='0672';x='59EB';y='FC4F';a='91';b='02'}
    '5a1c'=@{s='07A4';u='0672';x='59EB';y='FC4F';a='91';b='02'}
}
$ramFiles=@{fc='fc4d.bin';'5c18'='queue.bin';fec9='fec9.bin';'5cd0'='sv.bin';fecc='fecc.bin';fece='fece.bin';'5c7a'='cancel.bin';'5a10'='return5a10.bin';'5a1c'='return5a1c.bin'}
$frameByTag=@{}
$frames=@()
$previousCycle=$null
for($i=0;$i -lt $tags.Count;$i++){
    $spec=$guardSpec[$i]
    $line=$logLines[$i]
    if(!$line.StartsWith($spec.Tag+' ')){throw "Anchor order differs at ${i}: $line"}
    $f=Fields $line
    foreach($key in @('pc','cyc','s','u','x','y','a','b','dp','cc','44','45','46','47','49','4b','4c','4d','4e','4f','50','27e','27f','280','281','282','283','719B','st0','st2','st4','st6')){if(!$f.Contains($key)){throw "Anchor $($spec.Tag) lacks $key"}}
    $expectedPc=$spec.Addr.ToUpperInvariant().PadLeft(4,'0')
    if($f.pc -ne $expectedPc){throw "Anchor $($spec.Tag) PC is $($f.pc), expected $expectedPc"}
    $cycle=[Convert]::ToUInt64($f.cyc,16)
    if($previousCycle -ne $null -and $cycle -le $previousCycle){throw "Cycles are not strictly increasing at $($spec.Tag)"}
    $previousCycle=$cycle
    if($f.'719B' -ne '00'){throw "719B is not 00 at $($spec.Tag)"}
    foreach($key in $keyRegs[$spec.Tag].Keys){if($f[$key] -ne $keyRegs[$spec.Tag][$key]){throw "Register $key differs at $($spec.Tag)"}}
    $frame=[ordered]@{tag=$spec.Tag;pc=$f.pc;cycle=$f.cyc;s=$f.s;u=$f.u;x=$f.x;y=$f.y;a=$f.a;b=$f.b;dp=$f.dp;cc=$f.cc;host=[ordered]@{'44'=$f.'44';'45'=$f.'45';'46'=$f.'46';'47'=$f.'47';'49'=$f.'49';'4b'=$f.'4b';'4c'=$f.'4c';'4d'=$f.'4d';'4e'=$f.'4e';'4f'=$f.'4f';'50'=$f.'50'};links=[ordered]@{'27e'=$f.'27e';'27f'=$f.'27f';'280'=$f.'280';'281'=$f.'281';'282'=$f.'282';'283'=$f.'283'};'719B'=$f.'719B';stack=[ordered]@{s0=$f.st0;s2=$f.st2;s4=$f.st4;s6=$f.st6}}
    if($ramFiles.ContainsKey($spec.Tag)){
        $ram=ReadRam $ramFiles[$spec.Tag]
        $frame['ram_file']=$ramFiles[$spec.Tag]
        $frame['ram_sha256']=(HashBytes $ram)
        $frame['ram_hex']=([BitConverter]::ToString($ram)-replace '-','')
        AssertByte $ram 0x44 $f.'44' "$($spec.Tag) host"
        AssertWord $ram 0x45 $f.'45' "$($spec.Tag) host"
        AssertWord $ram 0x46 $f.'46' "$($spec.Tag) host"
        AssertWord $ram 0x47 $f.'47' "$($spec.Tag) host"
        AssertWord $ram 0x49 $f.'49' "$($spec.Tag) host"
        foreach($offset in @(0x4b,0x4c,0x4d,0x4e,0x4f,0x50)){AssertByte $ram $offset $f[$offset.ToString('x')] "$($spec.Tag) host"}
        AssertWord $ram 0x27e $f.'27e' "$($spec.Tag) link"
        AssertByte $ram 0x27f $f.'27f' "$($spec.Tag) link"
        AssertWord $ram 0x280 $f.'280' "$($spec.Tag) link"
        AssertByte $ram 0x281 $f.'281' "$($spec.Tag) link"
        if([Convert]::ToInt32($f.'282',16) -ne (WordNum $ram 0x282)){throw "Link 282 word differs at $($spec.Tag)"}
        AssertByte $ram 0x283 $f.'283' "$($spec.Tag) link"
        $sp=[Convert]::ToInt32($f.s,16)
        if($sp+6 -ge $ram.Length){throw "Stack pointer outside 2KB at $($spec.Tag)"}
        AssertWord $ram $sp $f.st0 "$($spec.Tag) stack"
        AssertWord $ram ($sp+2) $f.st2 "$($spec.Tag) stack"
        AssertWord $ram ($sp+4) $f.st4 "$($spec.Tag) stack"
        AssertWord $ram ($sp+6) $f.st6 "$($spec.Tag) stack"
    }
    $frameByTag[$spec.Tag]=$frame
    $frames+=,$frame
}
if(0x719b -lt 0x800){throw '719B is not outside the saved 2KB region'}
if($frameByTag.fc.host.'47' -ne '0000' -or $frameByTag.fc.host.'49' -ne '01A0' -or $frameByTag.fc.host.'4b' -ne '00' -or $frameByTag.fc.host.'4c' -ne '05' -or $frameByTag.fc.host.'4d' -ne '00'){throw 'FC4D initial list differs'}
if($frameByTag.'5c18'.host.'47' -ne '0000' -or $frameByTag.'5c18'.host.'49' -ne '01A0' -or $frameByTag.'5c18'.host.'4d' -ne '31'){throw 'Queue precondition differs'}
if($frameByTag.'5a1c'.host.'47' -ne '0000' -or $frameByTag.'5a1c'.host.'49' -ne '01A0' -or $frameByTag.'5a1c'.host.'4d' -ne '00'){throw 'Return state differs'}
if($frameByTag.'5c18'.stack.s0 -ne '59E9'){throw 'Queue continuation differs'}
if($frameByTag.'5cd0'.stack.s0 -ne 'FECC'){throw 'Service continuation differs'}
if($frameByTag.'5c7a'.stack.s0 -ne '5A10'){throw 'Cancel continuation differs'}

$anchors=@($frames|Where-Object{$_ -ne $null -and $_.tag -in @('fc','5c18','fec9','5cd0','fecc','fece','5c7a','5a10','5a1c')})
$markers=@($frames|Where-Object{$_ -ne $null -and $_.tag -in @('5a14','5a01','5a05','5a0a')})
$inputRows=@(Get-Content (Join-Path $run 'input-levels.csv'))
if($inputRows.Count -lt 1000){throw 'Input campaign log is sparse'}
$stateRows=@(Get-Content (Join-Path $run 'state.csv'))
if($stateRows.Count -lt 100){throw 'State log is sparse'}

$fixture=[ordered]@{
 schema='fresh-tone-occurrence-capture33/1'
 classification='controlled replay natural: one first complete FC4D->5C18->FEC9/5CD0/FECC/FECE->5C7A->5A10->5A1C occurrence from the retained recorded physical-input campaign; original reset ROM/settings/NVRAM; no RAM/register/PTM/ACK/end-state injection; debugger reads and 2KB saves only'
 source=[ordered]@{
  run='artifacts/deepseek/capture-33/natural-service'
  rom_sha1=$romSha1;rom_zip_sha256=$romZipHash
  mame_version=$provenance.mame_version;mame_sha256=$mameHash
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
  input_sequence='retained replay campaign (1250 events, including paid_start at frame 24403); this first complete occurrence occurred earlier in the same run, before the later paid_start event'
 }
 occurrence=[ordered]@{
  identity='first complete FC4D->5A1C in this fresh run; absolute cycle/caller/RAM are its own and are not fitted or relabelled from gate28, the historical nudge-tone snapshot or any later occurrence'
  anchor_scope='single-occurrence anchor sequence only; not a continuous lifecycle'
  entry='FC4D';entry_cycle=$frameByTag.fc.cycle;entry_x=$frameByTag.fc.x
  phase_cycles=[ordered]@{'fc4d->5a14'=([Convert]::ToUInt64($frameByTag.'5a14'.cycle,16)-[Convert]::ToUInt64($frameByTag.fc.cycle,16));'5a14->5a01'=([Convert]::ToUInt64($frameByTag.'5a01'.cycle,16)-[Convert]::ToUInt64($frameByTag.'5a14'.cycle,16));'5a01->5c18'=([Convert]::ToUInt64($frameByTag.'5c18'.cycle,16)-[Convert]::ToUInt64($frameByTag.'5a01'.cycle,16));'5c18->5a05'=([Convert]::ToUInt64($frameByTag.'5a05'.cycle,16)-[Convert]::ToUInt64($frameByTag.'5c18'.cycle,16));'5a05->5a0a'=([Convert]::ToUInt64($frameByTag.'5a0a'.cycle,16)-[Convert]::ToUInt64($frameByTag.'5a05'.cycle,16));'5a05->5c7a'=([Convert]::ToUInt64($frameByTag.'5c7a'.cycle,16)-[Convert]::ToUInt64($frameByTag.'5a05'.cycle,16))}
  anchors=@($anchors);markers=@($markers)
  sound_719b='00 at every captured anchor in the actual debug log (outside the saved 2KB)'
  stack_note='raw w@s,w@(s+2),w@(s+4),w@(s+6); queue continuation 59E9, 5CD0 continuation FECC, cancel continuation 5A10, each checked against its saved 2KB stack word'
 }
 validation=[ordered]@{
  validator='tools/Curate-FreshToneOccurrenceCapture33.ps1'
  actual_mame_sha256=$mameHash
  actual_rom_zip_sha256=$romZipHash
  actual_rom_entry_sha1=$romSha1
  source_campaign_pins_verified=$true
  source_input_lua_sha256=$sourceInputHash
  derived_input_only_declared_patch=$true
  debugger_allowlisted_reads_saves_tempguards=$true
  arguments_isolated_noreadconfig_original_rom=$true
  frames_pc_tag_and_strict_cycle_order=$true
  saved_ram_cross_checked_frames=@('fc','5c18','fec9','5cd0','fecc','fece','5c7a','5a10','5a1c')
  marker_only_frames=@('5a14','5a01','5a05','5a0a')
  link_282_encoding='big-endian word w@0x282; retained raw printed 282=5FF with the legacy %02X width; the numeric word 0x05FF is compared to the saved 2KB; the capture script now formats this field as %04X'
  sound_719b='actual debug log only; outside the 0x000-0x7FF snapshot; 00 at all 13 frames'
  classification_basis='derived from the executed checks above; the free-text classification string is descriptive, not used as evidence'
 }
 limits=@('Single-occurrence anchor set only; no continuous FC4D->5A1C lifecycle is captured or claimed.','Intervening service/stream commands and foreground writes between first FECE and 5A0A are absent; 5A14/5A01/5A05/5A0A are marker-only frames without saved 2KB.','Does not compare or re-time gate28, the historical nudge-tone snapshot or any later occurrence.','No stream-command breakpoints, timer1 cadence, outer IRQ ownership, 6B4D/58BB, finish CPU budget, audio, Live ownership or hardware claim.','actions.csv has only its header because the first complete occurrence and guarded stop happened before the later paid_start action; replay-actions.csv is the authoritative verified input sequence.')
}
$directory=[IO.Path]::GetDirectoryName($target)
if(!(Test-Path -LiteralPath $directory)){New-Item -ItemType Directory -Path $directory -Force|Out-Null}
$json=$fixture|ConvertTo-Json -Depth 12
[IO.File]::WriteAllText($target,$json,[Text.UTF8Encoding]::new($false))
Write-Output ("Curated capture33 occurrence entry={0} cycle={1} anchors={2} markers={3} sha256={4}" -f $fixture.occurrence.entry,$fixture.occurrence.entry_cycle,$anchors.Count,$markers.Count,(HashFile $target))

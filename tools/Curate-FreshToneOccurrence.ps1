param(
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [Parameter(Mandatory=$true)][string]$RomPath,
    [string]$MamePath = 'E:\Arcade\MAME0266\mame281.exe'
)
$ErrorActionPreference='Stop'
function HashFile([string]$path,[string]$algorithm='SHA256'){
    $hash=[Security.Cryptography.HashAlgorithm]::Create($algorithm)
    ([BitConverter]::ToString($hash.ComputeHash([IO.File]::ReadAllBytes($path)))-replace '-','')
}
function HexBytes([byte[]]$bytes){([BitConverter]::ToString($bytes)-replace '-','')}
function ReadRam([string]$name){
    $bytes=[IO.File]::ReadAllBytes((Join-Path $RunDirectory $name))
    if($bytes.Length -ne 0x800){throw "Snapshot $name is not 2 KB"}
    return ,$bytes
}
function Fields([string]$line){
    $fields=@{}
    foreach($match in [regex]::Matches($line,'([a-z0-9_]+)=([0-9A-F]+)')){$fields[$match.Groups[1].Value]=$match.Groups[2].Value}
    return $fields
}
function Frame([string]$name,[string]$line,[string]$ramFile){
    $fields=Fields $line
    $frame=[ordered]@{
        name=$name
        pc=$fields.pc
        cycle=$fields.cyc
        s=$fields.s
        u=$fields.u
        x=$fields.x
        y=$fields.y
        a=$fields.a
        b=$fields.b
        dp=$fields.dp
        cc=$fields.cc
    }
    if($ramFile){
        $ram=ReadRam $ramFile
        $frame['ram_file']=$ramFile
        $frame['ram_sha256']=(HexBytes ([Security.Cryptography.SHA256]::Create().ComputeHash($ram)))
        $frame['ram_hex']=(HexBytes $ram)
    }
    return $frame
}
$run=[IO.Path]::GetFullPath($RunDirectory)
$rom=[IO.Path]::GetFullPath($RomPath)
$mame=[IO.Path]::GetFullPath($MamePath)
if((Get-Content (Join-Path $run 'exit-code.txt') -Raw).Trim() -ne '0'){throw 'Capture exit is not 0'}
if((HashFile $rom 'SHA1') -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected original ROM'}
if((HashFile $mame) -ne '0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A'){throw 'Unexpected MAME binary'}
$expectedHashes=[ordered]@{
    'input.lua'='7C664323A5725E9FB294CB201B17B855564AF2E4A500560ED499F1EE45179D0D'
    'replay-actions.csv'='4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D'
    'debug.log'='87980007509CB3592B0447CE0F2617EA1CB2DA03F68784A427B015DC2DAC6910'
    'debugger.cmd'='8F702823906F89DAE4B3C2FD690CE0583528C9B486111635954E9FC8667F86B9'
    'arguments.json'='368B8FC9B5D5ED02D34C427BD89467DEE2D852686C2F85939B50443A4258A77C'
    'actions.csv'='17E315DAA7C7007856403A9CA2484B7812F8D37411FE14FAA40B77E8DEC77E9A'
    'fc4d.bin'='30E97EE9A1A9CC7D50868BDD595D69E52A0A6BF9A0C65E5909F367F8BB3AF6BE'
    'queue.bin'='66DA2286F81C679E7206D1E1EADE21348D3047BA4845585CDBE3B145BC13BDB9'
    'phase14.bin'='4B50CF81B1C64960DFB10BD1368ACBA81955A7A782FFDA6AB07263B8670613F2'
    'phase05.bin'='931B082B36B2033A0EC01DCE22360289213DC1264243F8CDD2949A81681A68EA'
    'phase0a.bin'='D8CFB9F04EB6785D89DDCD3C2FF2BDCD902C7C14C0D1CF48D1B52B6C221B58A3'
    'sv-0.bin'='64B8D9B9CF33A1B00747013936FAFD88FDEB136C6F45CD0E259637758CE4B31D'
    'fecc-0.bin'='B62BA5DCBB2073841AE1CB9943DC3B67C7EA930FFDC6A1FCD8FAC7102601D537'
    'fece-0.bin'='B62BA5DCBB2073841AE1CB9943DC3B67C7EA930FFDC6A1FCD8FAC7102601D537'
    'cancel.bin'='191EC8427A34D5EC59F15069559F722710C55924FC16C8E2EBE9B63C1BE2EA24'
    'return.bin'='A8BBB595ED19BF6EAFF304B8AA7D0F6B7A27738F96565640D737074A6B0589EF'
}
foreach($name in $expectedHashes.Keys){
    $path=Join-Path $run $name
    if(!(Test-Path -LiteralPath $path)){throw "Missing raw artifact $name"}
    if((HashFile $path) -ne $expectedHashes[$name]){throw "Raw artifact hash differs: $name"}
}
$arguments=Get-Content (Join-Path $run 'arguments.json') -Raw|ConvertFrom-Json
$argumentText=$arguments -join "`n"
foreach($forbidden in @('-state ','-playback','-cheat','-autosave','-loadstate','-rewind')){
    if($argumentText -match [regex]::Escape($forbidden)){throw "Forbidden capture argument $forbidden"}
}
if($argumentText -notmatch '-noreadconfig' -or $argumentText -notmatch '-sound\s+none' -or $argumentText -notmatch '-video\s+none' -or $argumentText -notmatch '-seconds_to_run\s+430'){throw 'Capture arguments differ from the declared isolation contract'}
if($argumentText -notmatch 'input\.lua'){throw 'Capture is not driven by the declared input script'}
$debugger=Get-Content (Join-Path $run 'debugger.cmd')
foreach($line in $debugger){
    if($line -match '\b(fill|load|wpset|history|rewind|cheat|snapshot)\b' -or $line -match 'mem:write|write_u8|write_u16'){throw "Debugger contains injection command: $line"}
    if($line -match 'save\s+([^,;]+),([^,;]+),([0-9A-Fa-f]+);'){
        if($Matches[2].Trim() -ne '0' -or $Matches[3].Trim() -ne '800'){throw 'Debugger saves a non-2KB region'}
    }
}
$inputScript=Get-Content (Join-Path $run 'input.lua') -Raw
if($inputScript -match 'mem:write' -or $inputScript -match 'write_u8' -or $inputScript -match 'write_u16'){throw 'Input campaign writes machine memory'}
$replay=Get-Content (Join-Path $run 'replay-actions.csv')
if($replay[0] -ne 'first_frame,last_frame,port,mask,reason,display,credits,nudges'){throw 'Replay campaign header differs'}
if($replay.Count -lt 1000){throw 'Replay campaign is unexpectedly sparse'}
for($i=1;$i -lt $replay.Count;$i++){
    $cells=$replay[$i] -split ','
    if($cells.Count -lt 8){throw "Malformed replay event at line $i"}
    $first=[int]$cells[0];$last=[int]$cells[1]
    if($first -lt 0 -or $last -lt $first){throw "Invalid replay frame range at line $i"}
    if($cells[2] -notmatch '^:(AUX2|BLACK2)$'){throw "Unexpected replay port at line $i"}
    if($cells[3] -notmatch '^\d+$'){throw "Unexpected replay mask at line $i"}
}
$actions=Get-Content (Join-Path $run 'actions.csv')
if($actions.Count -ne 2 -or $actions[0] -ne 'first_frame,last_frame,port,mask,reason,display,credits,nudges' -or $actions[1] -notmatch '^24403,24415,:BLACK2,128,paid_start,'){throw 'Unexpected runtime action beyond the declared replay'}
$first=[ordered]@{}
$last=[ordered]@{}
$fe9=0;$fec=0;$fee=0;$cmd=0;$swd=0
foreach($line in [IO.File]::ReadLines((Join-Path $run 'debug.log'))){
    if($line -match '^FC ' -and !$first.Contains('FC')){$first.FC=$line;continue}
    if($line -match '^SQ ' -and !$first.Contains('SQ')){$first.SQ=$line;continue}
    if($line -match '^P14 '){$last.P14=$line;if(!$first.Contains('P14')){$first.P14=$line};continue}
    if($line -match '^P01 ' -and !$first.Contains('P01')){$first.P01=$line;continue}
    if($line -match '^P05 '){$last.P05=$line;if(!$first.Contains('P05')){$first.P05=$line};continue}
    if($line -match '^P0A '){$last.P0A=$line;if(!$first.Contains('P0A')){$first.P0A=$line};continue}
    if($line -match '^P10 '){$last.P10=$line;if(!$first.Contains('P10')){$first.P10=$line};continue}
    if($line -match '^P1C '){$last.P1C=$line;if(!$first.Contains('P1C')){$first.P1C=$line};continue}
    if($line -match '^CX '){$last.CX=$line;if(!$first.Contains('CX')){$first.CX=$line};continue}
    if($line -match '^FE9 '){if($fe9 -lt 2){$first["FE9_$fe9"]=$line};$fe9++;continue}
    if($line -match '^FEC '){if($fec -lt 1){$first['FEC']=$line};$fec++;continue}
    if($line -match '^FEE '){if($fee -lt 1){$first['FEE']=$line};$fee++;continue}
    if($line -match '^SV ' -and !$first.Contains('SV')){$first.SV=$line;continue}
    if($line -match '^SWD ' -and !$first.Contains('SWD')){$first.SWD=$line;continue}
    if($line -match '^CMD '){if($cmd -lt 6){$first["CMD_$cmd"]=$line};$cmd++;continue}
}
$expectedLines=[ordered]@{
    FC='FC pc=00FC cyc=0000000003CCB742 s=07AA u=0672 x=8132 y=FC4D a=00 b=FF dp=00 cc=C4 44=00 c45=391B c46=1B00 h47=0000 f49=01A0 4b=00 4c=05 4d=00 4e=10 4f=00 50=10 27e=0102 280=0304 282=05FF'
    P14='P14 pc=5A14 cyc=0000000003CCB76B s=07A6 u=0672 x=80A6 y=FC4F a=00 b=FF c45=391B 4d=00 4f=00 4e=10'
    P01='P01 pc=5A01 cyc=0000000003CCB784 s=07A0 u=0672 x=80A6 y=FC4F a=91 b=02 c45=391B 4d=00 4f=00 4e=10'
    SQ='SQ pc=5C18 cyc=0000000003CCB7AE s=0798 u=0672 x=59EB y=FC4F a=91 b=31 dp=00 cc=C0 44=00 c45=391B c46=1B00 h47=0000 f49=01A0 4b=00 4c=05 4d=31 4e=10 4f=00 50=10 27e=0102 280=0304 282=05FF'
    P05='P05 pc=5A05 cyc=0000000003CCB8BF s=07A0 u=0672 x=80A6 y=FC4F a=91 b=91 c45=391B 4d=31 4f=00 4e=10'
    FE9_0='FE9 pc=FEC9 cyc=0000000003CCC0F5 s=078D u=0672 x=0366 y=0000 a=05 b=0B dp=00 cc=C4 44=00 c45=391B c46=1B01 h47=01A0 f49=01C5 4b=00 4c=05 4d=31 4e=10 4f=00 50=10 27e=0102 280=0304 282=05FF'
    SV='SV pc=5CD0 cyc=0000000003CCC0FD s=078B u=0672 x=0366 y=0000 a=05 b=0B dp=00 cc=C4 44=00 c45=391B c46=1B01 h47=01A0 f49=01C5 4b=00 4c=05 4d=31 4e=10 4f=00 50=10 27e=0102 280=0304 282=05FF'
    CMD_0='CMD pc=5D3B cyc=0000000003CCC149 cursor=59EB opcode=C6 task=01A0 clock=391C choice=00 rate=10 tempo=10 gate=00 flags=00 pitch=00 transpose=00'
    CMD_1='CMD pc=5D3B cyc=0000000003CCC30A cursor=59EE opcode=C5 task=01A0 clock=391C choice=00 rate=10 tempo=10 gate=00 flags=00 pitch=00 transpose=00'
    CMD_2='CMD pc=5D3B cyc=0000000003CCC349 cursor=59F0 opcode=D8 task=01A0 clock=391C choice=00 rate=10 tempo=10 gate=00 flags=00 pitch=00 transpose=00'
    CMD_3='CMD pc=5D3B cyc=0000000003CCC373 cursor=59F1 opcode=00 task=01A0 clock=391C choice=00 rate=10 tempo=10 gate=00 flags=80 pitch=00 transpose=00'
    CMD_4='CMD pc=5D3B cyc=0000000003CCC4A9 cursor=59F2 opcode=C3 task=01A0 clock=391C choice=00 rate=10 tempo=10 gate=00 flags=80 pitch=00 transpose=00'
    CMD_5='CMD pc=5D3B cyc=0000000003CCC4F6 cursor=59F4 opcode=CE task=01A0 clock=391C choice=00 rate=10 tempo=10 gate=00 flags=80 pitch=00 transpose=00'
    SWD='SWD duration=FF cursor=59F6 task=01A0 clock=391C callback=5E29 rate=10 tempo=10 flags=80'
    FEC='FEC pc=FECC cyc=0000000003CCC5DD s=078D u=0000 x=0047 y=01A0 a=39 b=1C dp=00 cc=C5 44=00 c45=391C c46=1C01 h47=01A0 f49=01C5 4b=01 4c=05 4d=31 4e=10 4f=00 50=10 27e=FF02 280=0304 282=05FF'
    FEE='FEE pc=FECE cyc=0000000003CCC5E3 s=078D u=0000 x=0047 y=01A0 a=39 b=1C dp=00 cc=C4 44=00 c45=391C c46=1C01 h47=01A0 f49=01C5 4b=01 4c=05 4d=31 4e=10 4f=00 50=10 27e=FF02 280=0304 282=05FF'
    P0A='P0A pc=5A0A cyc=0000000003CE0402 s=07A0 u=0672 x=80A6 y=FC4F a=91 b=02 c45=3934 4d=31 4f=00 4e=10'
    CX='CX pc=5C7A cyc=0000000003CE040D s=079E u=0672 x=59EB y=FC4F a=91 b=02 dp=00 cc=C0 44=00 c45=3934 c46=3401 h47=01A0 f49=01C5 4b=01 4c=05 4d=31 4e=10 4f=00 50=10 27e=FF02 280=0304 282=05FF'
    P10='P10 pc=5A10 cyc=0000000003CE0541 s=07A0 u=0672 x=59EB y=FC4F a=91 b=02 c45=3934 4d=31 4f=00 4e=10'
    P1C='P1C pc=5A1C cyc=0000000003CE0550 s=07A4 u=0672 x=59EB y=FC4F a=91 b=02 c45=3934 4d=00 4f=00 4e=10'
}
foreach($key in $expectedLines.Keys){
    if($first[$key] -ne $expectedLines[$key]){throw "First natural marker differs: $key"}
}
$expectedLast=[ordered]@{
    P14='P14 pc=5A14 cyc=000000002B4B6215 s=07A6 u=0672 x=80A6 y=FC4F a=00 b=FF c45=2341 4d=00 4f=00 4e=10'
    P05='P05 pc=5A05 cyc=000000002B4B6369 s=07A0 u=0672 x=80A6 y=FC4F a=91 b=91 c45=2341 4d=31 4f=00 4e=10'
    P0A='P0A pc=5A0A cyc=000000002B4CA7B5 s=07A0 u=0672 x=80A6 y=FC4F a=91 b=02 c45=2359 4d=31 4f=00 4e=10'
    CX='CX pc=5C7A cyc=000000002B4CA7C0 s=079E u=0672 x=59EB y=FC4F a=91 b=02 dp=00 cc=C0 44=00 c45=2359 c46=5901 h47=01A0 f49=01C5 4b=01 4c=05 4d=31 4e=10 4f=00 50=10 27e=FF02 280=0304 282=05FF'
    P10='P10 pc=5A10 cyc=000000002B4CAF3A s=07A0 u=0672 x=59EB y=FC4F a=91 b=02 c45=2359 4d=31 4f=00 4e=10'
    P1C='P1C pc=5A1C cyc=000000002B4CAF49 s=07A4 u=0672 x=59EB y=FC4F a=91 b=02 c45=2359 4d=00 4f=00 4e=10'
}
foreach($key in $expectedLast.Keys){
    if($last[$key] -ne $expectedLast[$key]){throw "Last cancel/return marker differs: $key"}
}
$primaryFrames=@(
    (Frame 'fc4d' $first.FC 'fc4d.bin'),
    (Frame 'queue' $first.SQ 'queue.bin'),
    (Frame 'service-before' $first.SV 'sv-0.bin'),
    (Frame 'service-after' $first.FEC 'fecc-0.bin'),
    (Frame 'service-after-clear' $first.FEE 'fece-0.bin')
)
$primaryMarkers=@(
    (Frame 'foreground-5a14' $first.P14 $null),
    (Frame 'foreground-5a01' $first.P01 $null),
    (Frame 'foreground-5a05' $first.P05 $null),
    (Frame 'foreground-5a0a' $first.P0A $null),
    (Frame 'cancel-entry' $first.CX $null),
    (Frame 'cancel-foreground-5a10' $first.P10 $null),
    (Frame 'return-5a1c' $first.P1C $null)
)
$lastFrames=@(
    (Frame 'foreground-5a14' $last.P14 'phase14.bin'),
    (Frame 'foreground-5a05' $last.P05 'phase05.bin'),
    (Frame 'foreground-5a0a' $last.P0A 'phase0a.bin'),
    (Frame 'cancel-before' $last.CX 'cancel.bin'),
    (Frame 'cancel-foreground-5a10' $last.P10 $null),
    (Frame 'cancel-after' $last.P1C 'return.bin')
)
function HostFrom([string]$line){
    $f=Fields $line
    $clock=$f.c45
    if($clock.Length -ne 4){throw 'Caller frame has no 16-bit 0x45 clock'}
    return [ordered]@{'44'=$f.'44';'45'=$clock.Substring(0,2);'46'=$clock.Substring(2,2);'719B'='00'}
}
$fcRam=ReadRam 'fc4d.bin';$queueRam=ReadRam 'queue.bin'
$delta=[Collections.Generic.List[object]]::new()
for($i=0;$i -lt 0x800;$i++){
    if($fcRam[$i] -ne $queueRam[$i]){
        if(!($i -eq 0x4D -or ($i -ge 0x798 -and $i -le 0x7A9))){throw ("Foreground delta touches non-caller state at {0:X3}" -f $i)}
        $delta.Add([ordered]@{offset=('{0:X3}' -f $i);from=$fcRam[$i];to=$queueRam[$i]})
    }
}
if($delta.Count -ne 16){throw "Unexpected foreground delta count $($delta.Count)"}
$commands=@()
for($i=0;$i -lt 6;$i++){
    $f=Fields $first["CMD_$i"]
    $commands+=,[ordered]@{cursor=$f.cursor;opcode=$f.opcode;cycle=$f.cyc;task=$f.task;clock=$f.clock;flags=$f.flags}
}
$expectedOpcodes=@('C6','C5','D8','00','C3','CE')
for($i=0;$i -lt 6;$i++){if($commands[$i].opcode -ne $expectedOpcodes[$i]){throw 'Command order differs'}}
$romBytes=[IO.File]::ReadAllBytes($rom)
$regions=@(
    [ordered]@{name='59EB stream and data';address=0x59EB;bytes_hex=(HexBytes $romBytes[0x59EB..0x5A1F]);sha256=(HexBytes ([Security.Cryptography.SHA256]::Create().ComputeHash($romBytes[0x59EB..0x5A1F])))},
    [ordered]@{name='5963 sound dispatch table';address=0x5963;bytes_hex=(HexBytes $romBytes[0x5963..0x5C57]);sha256=(HexBytes ([Security.Cryptography.SHA256]::Create().ComputeHash($romBytes[0x5963..0x5C57])))},
    [ordered]@{name='5C18 queue cancel service dispatch';address=0x5C18;bytes_hex=(HexBytes $romBytes[0x5C18..0x5D3A]);sha256=(HexBytes ([Security.Cryptography.SHA256]::Create().ComputeHash($romBytes[0x5C18..0x5D3A])))},
    [ordered]@{name='5E24 CE and release roots';address=0x5E24;bytes_hex=(HexBytes $romBytes[0x5E24..0x5E8C]);sha256=(HexBytes ([Security.Cryptography.SHA256]::Create().ComputeHash($romBytes[0x5E24..0x5E8C])))},
    [ordered]@{name='5EB2 C3 and 5EC6 C4';address=0x5EB2;bytes_hex=(HexBytes $romBytes[0x5EB2..0x5EE0]);sha256=(HexBytes ([Security.Cryptography.SHA256]::Create().ComputeHash($romBytes[0x5EB2..0x5EE0])))},
    [ordered]@{name='5F88 C5/C6 attenuation tail';address=0x5F88;bytes_hex=(HexBytes $romBytes[0x5F88..0x5FDB]);sha256=(HexBytes ([Security.Cryptography.SHA256]::Create().ComputeHash($romBytes[0x5F88..0x5FDB])))},
    [ordered]@{name='6049 D8';address=0x6049;bytes_hex=(HexBytes $romBytes[0x6049..0x6051]);sha256=(HexBytes ([Security.Cryptography.SHA256]::Create().ComputeHash($romBytes[0x6049..0x6051])))},
    [ordered]@{name='608E C6 instrument table';address=0x608E;bytes_hex=(HexBytes $romBytes[0x608E..0x609B]);sha256=(HexBytes ([Security.Cryptography.SHA256]::Create().ComputeHash($romBytes[0x608E..0x609B])))},
    [ordered]@{name='60AB cached write';address=0x60AB;bytes_hex=(HexBytes $romBytes[0x60AB..0x60BD]);sha256=(HexBytes ([Security.Cryptography.SHA256]::Create().ComputeHash($romBytes[0x60AB..0x60BD])))},
    [ordered]@{name='60C8 disabled gate';address=0x60C8;bytes_hex=(HexBytes $romBytes[0x60C8..0x60D5]);sha256=(HexBytes ([Security.Cryptography.SHA256]::Create().ComputeHash($romBytes[0x60C8..0x60D5])))}
)
$fixture=[ordered]@{
    schema='fresh-tone-occurrence/1'
    classification='controlled replay natural: retained physical-input campaign, genuine MAME devices, no RAM/register/PTM/ACK/end-state injection; explicit captured caller frames only'
    source=[ordered]@{
        run='artifacts/deepseek/gate-28/natural-service'
        rom_sha1=(HashFile $rom 'SHA1')
        mame_version='0.281'
        mame_sha256=(HashFile $mame)
        input_lua_sha256=$expectedHashes['input.lua']
        replay_actions_sha256=$expectedHashes['replay-actions.csv']
        debug_sha256=$expectedHashes['debug.log']
        debugger_sha256=$expectedHashes['debugger.cmd']
        arguments_sha256=$expectedHashes['arguments.json']
        actions_sha256=$expectedHashes['actions.csv']
        exit=0
        conditions='fresh isolated cfg/nvram/inp/snap/state/diff; original ROM read-only; MPU4_REPLAY=retained replay-actions.csv; no machine-state load, PTM/ACK/end-state injection or debugger memory write'
    }
    historical=[ordered]@{
        retained_entry_x='80A3'
        retained_cycle='699661924'
        retained_ram_sha256='DF378149DDBE03252E8D19EE4B3CC97AC091E66573F16D521E30B5E1DFE172CC'
        relation='unchanged historical nudge-tone snapshot; this fresh occurrence differs in cycle and caller and is reported, not fitted'
    }
    primary=[ordered]@{
        entry='FC4D'
        cycle='0000000003CCB742'
        entry_x='8132'
        ram_sha256=$expectedHashes['fc4d.bin']
        foreground_delta=$delta
        queue=[ordered]@{caller=(Frame 'queue-caller' $first.SQ $null);host=(HostFrom $first.SQ);before='fc4d';after_retained='service-before'}
        service=[ordered]@{caller=(Frame 'service-caller' $first.SV $null);host=(HostFrom $first.SV);before='service-before';after='service-after';return_word='FECC'}
        cancel=[ordered]@{caller=(Frame 'cancel-caller' $first.CX $null);host=(HostFrom $first.CX);before='service-after';foreground_after='cancel-foreground-5a10';return='return-5a1c';note='first-window cancel/return full 2KB was not temp-guarded; only marker registers are retained'}
        phase_widths=[ordered]@{'5A14-5A05'=340;'5A05-5A0A'=84803;'5A05-cancel'=84814}
        frames=@($primaryFrames)
        markers=@($primaryMarkers)
        commands=@($commands)
        wait=[ordered]@{cursor='59F6';duration='FF';callback='5E29';task='01A0';clock='391C';flags='80'}
    }
    cancel_full=[ordered]@{
        note='full 2KB cancel/return anchors are from the last matching natural occurrence in the same controlled replay; first-window cancel/return had no temp-guarded full RAM save'
        cycle='000000002B4CA7C0'
        cancel=[ordered]@{caller=(Frame 'cancel-caller' $last.CX $null);host=(HostFrom $last.CX);before='cancel-before'}
        return=[ordered]@{marker=(Frame 'return-marker' $last.P1C $null);after='cancel-after'}
        frames=@($lastFrames)
    }
    rom_regions=@($regions)
}
$target=Join-Path $PSScriptRoot '../evidence/mpu4/collection'
if(!(Test-Path -LiteralPath $target)){throw "Missing evidence target $target"}
$fixture|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $target 'fresh-tone-occurrence.json')
Write-Output ("Curated fresh tone occurrence {0}: {1} primary frames, {2} cancel/return frames, {3} commands, {4} ROM regions" -f $fixture.primary.cycle,$primaryFrames.Count,$lastFrames.Count,$commands.Count,$regions.Count)

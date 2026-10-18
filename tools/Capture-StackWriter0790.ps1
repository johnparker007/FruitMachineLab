param(
    [string]$MamePath = 'E:\Arcade\MAME0266\mame281.exe',
    [string]$RomDirectory = 'E:\Arcade\MAME0266\roms',
    [string]$SourceRun = 'artifacts/deepseek/gate-28/natural-service',
    [string]$RunDirectory = 'artifacts/deepseek/capture-43/natural-caller-stack',
    [int]$SecondsToRun = 430,
    [int]$SaveCap = 4,
    [int]$EventCap = 128,
    [int]$HardTimeoutSeconds = 600,
    [switch]$GenerateOnly
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath("$PSScriptRoot/..")
function Abs([string]$p){if([IO.Path]::IsPathRooted($p)){[IO.Path]::GetFullPath($p)}else{[IO.Path]::GetFullPath((Join-Path $root $p))}}
function HashFile([string]$p,[string]$alg='SHA256'){([BitConverter]::ToString([Security.Cryptography.HashAlgorithm]::Create($alg).ComputeHash([IO.File]::ReadAllBytes($p)))-replace '-','')}
function HashBytes([byte[]]$bytes,[string]$algorithm='SHA256'){
    $sha=[Security.Cryptography.HashAlgorithm]::Create($algorithm)
    $hash=$sha.ComputeHash($bytes)
    return ([BitConverter]::ToString($hash) -replace '-','')
}
$mame=Abs $MamePath
$roms=Abs $RomDirectory
$source=Abs $SourceRun
$run=Abs $RunDirectory
if(!(Test-Path -LiteralPath $mame)){throw 'Missing MAME executable'}
if(!(Test-Path -LiteralPath $roms)){throw 'Missing ROM directory'}
if(!(Test-Path -LiteralPath (Join-Path $source 'input.lua')) -or !(Test-Path -LiteralPath (Join-Path $source 'replay-actions.csv'))){throw 'Missing gate28 campaign source'}
if(Test-Path -LiteralPath $run){throw 'Fresh isolated directory required'}
if($SaveCap -lt 1 -or $SaveCap -gt 32){throw 'SaveCap must be between 1 and 32'}
if($EventCap -lt 1 -or $EventCap -gt 1024){throw 'EventCap must be between 1 and 1024'}
if($SecondsToRun -lt 1 -or $HardTimeoutSeconds -lt 1){throw 'Timeout values must be positive'}
$mameHash=HashFile $mame
if($mameHash -ne '0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A'){throw 'Unexpected MAME binary'}
$inputExpected='7C664323A5725E9FB294CB201B17B855564AF2E4A500560ED499F1EE45179D0D'
$replayExpected='4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D'
$sourceInput=Join-Path $source 'input.lua'
$sourceReplay=Join-Path $source 'replay-actions.csv'
if((HashFile $sourceInput) -ne $inputExpected){throw 'Unexpected source input.lua'}
if((HashFile $sourceReplay) -ne $replayExpected){throw 'Unexpected source replay-actions.csv'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::OpenRead((Join-Path $roms 'm4addr.zip'))
try{$entry=$zip.GetEntry('a6ls.p1');if(!$entry){throw 'Missing a6ls.p1 in m4addr.zip'};$ms=[IO.MemoryStream]::new();$stream=$entry.Open();$stream.CopyTo($ms);$stream.Dispose();$romBytes=$ms.ToArray();$ms.Dispose()}finally{$zip.Dispose()}
if((HashBytes $romBytes 'SHA1') -ne '402D1518BB78FDC489B06C2AABC771E5CE151847'){throw 'Unexpected original a6ls.p1'}
New-Item -ItemType Directory -Path $run|Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory -Path (Join-Path $run $name)|Out-Null}
Copy-Item -LiteralPath $sourceReplay -Destination (Join-Path $run 'replay-actions.csv')
if((HashFile (Join-Path $run 'replay-actions.csv')) -ne $replayExpected){throw 'Copied campaign hash differs'}
$derivedInput=[IO.File]::ReadAllText($sourceInput)
$derivedInput=$derivedInput.Replace('local setup_callbacks_to_skip=36','local setup_callbacks_to_skip=0')
$derivedInput=[regex]::Replace($derivedInput,"\r?\n if setup_callbacks_to_skip>0 then\r?\n  assert\(m\.time:as_double\(\)<0\.001,'Unexpected running frame during debugger setup'\)\r?\n  setup_callbacks_to_skip=setup_callbacks_to_skip-1\r?\n  return\r?\n end",'')
if($derivedInput -eq [IO.File]::ReadAllText($sourceInput)){throw 'Input derivative patch did not apply'}
[IO.File]::WriteAllText((Join-Path $run 'input.lua'),$derivedInput,[Text.UTF8Encoding]::new($false))
$derivedInputHash=HashFile (Join-Path $run 'input.lua')
$anchorFmt='pc=%04X cyc=%016X s=%04X u=%04X x=%04X y=%04X a=%02X b=%02X dp=%02X cc=%02X 44=%02X 47=%04X 49=%04X 4d=%02X 719b=%02X ret=%04X st0=%04X st2=%04X st4=%04X st6=%04X st8=%04X st10=%04X'
$anchorArgs='pc,totalcycles,s,u,x,y,a,b,dp,cc,b@0x44,w@0x47,w@0x49,b@0x4d,b@0x719b,w@s,w@s,w@(s+2),w@(s+4),w@(s+6),w@(s+8),w@(s+10)'
$stackFmt='pc=%04X cyc=%016X s=%04X u=%04X x=%04X y=%04X a=%02X b=%02X dp=%02X cc=%02X 719b=%02X wpaddr=%04X old=%02X new=%02X win=%02X%02X%02X%02X%02X%02X opm4=%02X opm3=%02X opm2=%02X opm1=%02X op0=%02X op1=%02X op2=%02X op3=%02X'
$stackArgs='pc,totalcycles,s,u,x,y,a,b,dp,cc,b@0x719b,wpaddr,b@wpaddr,wpdata,b@0x790,b@0x791,b@0x792,b@0x793,b@0x794,b@0x795,b@(pc-4),b@(pc-3),b@(pc-2),b@(pc-1),b@pc,b@(pc+1),b@(pc+2),b@(pc+3)'
function Anchor([string]$address,[string]$tag,[string]$condition,[string]$save,[bool]$quit,[bool]$arm){
    $cmd='printf "'+$tag+' '+$anchorFmt+'\n",'+$anchorArgs
    if($save){$cmd+=';save '+$save+',0,800'}
    if($arm){$cmd+=';temp0=1'}
    $cmd+=';temp9=temp9+1'
    if($quit){$cmd+=';quit'}else{$cmd+=';go'}
    return "bpset 0x$address,$condition,{$cmd}"
}
function StackWrite([string]$condition){
    return "wpset 0x790,10,w,$condition,{printf ""SW $stackFmt\n"",$stackArgs;temp1=temp1+1;go}"
}
function StackOverflow([string]$condition){
    return "wpset 0x790,10,w,$condition,{printf ""OVERFLOW_stack pc=%04X cyc=%016X s=%04X wpaddr=%04X\n"",pc,totalcycles,s,wpaddr;quit}"
}
$lines=[Collections.Generic.List[string]]::new()
foreach($i in 0..9){$lines.Add("temp$i=0")|Out-Null}
$lines.Add((Anchor 'fc' 'FC' 'temp0==0 && y==0xfc4d' 'fc4d.bin' $false $true))|Out-Null
$lines.Add((Anchor '5c18' 'Q' 'temp0==1 && temp3==0' 'queue.bin' $false))|Out-Null
$lines.Add((Anchor 'fe70' 'FE70' "temp0==1 && temp9<$EventCap" $null $false))|Out-Null
$lines.Add((Anchor 'ff13' 'FF13' "temp0==1 && temp9<$EventCap" $null $false))|Out-Null
$lines.Add((Anchor 'fec9' 'FEC9' "temp0==1 && temp9<$EventCap" $null $false))|Out-Null
$lines.Add((StackWrite "temp0==1 && temp1<$EventCap"))|Out-Null
$lines.Add((StackOverflow "temp0==1 && temp1>=$EventCap"))|Out-Null
$lines.Add((Anchor '5cd0' 'SVC' 'temp0==1 && temp2==0' 'stop5cd0.bin' $true))|Out-Null
foreach($a in @('fe70','ff13','fec9')){
    $lines.Add((Anchor $a "OVERFLOW_$a" "temp0==1 && temp9>=$EventCap" $null $true))|Out-Null
}
$lines.Add('go')|Out-Null
$lines.Add('quit')|Out-Null
Set-Content -LiteralPath (Join-Path $run 'debugger.cmd') -Value $lines -Encoding ASCII
$debuggerHash=HashFile (Join-Path $run 'debugger.cmd')
$arguments=@('m4addr','-noreadconfig','-rompath',$roms,'-cfg_directory',(Join-Path $run 'cfg'),'-nvram_directory',(Join-Path $run 'nvram'),'-input_directory',(Join-Path $run 'inp'),'-snapshot_directory',(Join-Path $run 'snap'),'-comment_directory',(Join-Path $run 'comments'),'-state_directory',(Join-Path $run 'state'),'-diff_directory',(Join-Path $run 'diff'),'-autoboot_delay','0','-autoboot_script',(Join-Path $run 'input.lua'),'-debug','-debugger','windows','-debugscript',(Join-Path $run 'debugger.cmd'),'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run',"$SecondsToRun")
$arguments|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $run 'arguments.json')
$provenance=[ordered]@{
 classification='controlled replay natural: recorded physical-input campaign, genuine MAME devices, original reset ROM/settings/NVRAM; no RAM/register/PTM/ACK/end-state injection; debugger breakpoints/watchpoints/reads/2KB saves only'
 source_run=$SourceRun
 source_input_lua_sha256=$inputExpected
 derived_input_lua_sha256=$derivedInputHash
 input_lua_patch='removed only the debugger-startup frame assertion and set its skip guard to zero; replay/physical-input/event code unchanged'
 source_replay_actions_sha256=$replayExpected
 mame_sha256=$mameHash
 mame_version='0.281'
 rom_zip_sha256=(HashFile (Join-Path $roms 'm4addr.zip'))
 rom_entry='a6ls.p1'
 rom_sha1=(HashBytes $romBytes 'SHA1')
 rom_bytes=$romBytes.Length
 debugger_sha256=$debuggerHash
 seconds_to_run=$SecondsToRun
 hard_timeout_seconds=$HardTimeoutSeconds
 save_cap=$SaveCap
 event_cap=$EventCap
 watchpoint='0x0790 length 16 write; log PC/registers/cycles/wpaddr/old/new, opcode context and actual 719B; no memory write'
}
$provenance|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $run 'provenance.json')
if($GenerateOnly){Write-Output $run;return}
$psi=[Diagnostics.ProcessStartInfo]::new()
$psi.FileName=$mame
$psi.Arguments=($arguments|ForEach-Object {if($_ -match '\s'){'"'+$_+'"'}else{$_}})-join ' '
$psi.WorkingDirectory=$run
$psi.UseShellExecute=$false
$psi.RedirectStandardOutput=$true
$psi.RedirectStandardError=$true
$psi.EnvironmentVariables['MPU4_REPLAY']=(Join-Path $run 'replay-actions.csv')
[void]$psi.EnvironmentVariables.Remove('MPU4_POLICY')
$p=[Diagnostics.Process]::Start($psi)
$outTask=$p.StandardOutput.ReadToEndAsync()
$errTask=$p.StandardError.ReadToEndAsync()
if(!$p.WaitForExit($HardTimeoutSeconds*1000)){$p.Kill();throw 'Capture hard timeout'}
$p.WaitForExit()
Set-Content -LiteralPath (Join-Path $run 'console.txt') -Value $outTask.Result -Encoding ASCII
Set-Content -LiteralPath (Join-Path $run 'stderr.txt') -Value $errTask.Result -Encoding ASCII
$p.ExitCode|Set-Content -LiteralPath (Join-Path $run 'exit-code.txt') -Encoding ASCII
if($p.ExitCode -ne 0){throw "Capture exit $($p.ExitCode)"}
if(!(Test-Path -LiteralPath (Join-Path $run 'debug.log'))){throw 'Missing debug.log'}
Write-Output $run


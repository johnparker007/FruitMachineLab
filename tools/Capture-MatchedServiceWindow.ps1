param(
    [string]$MamePath = 'E:\Arcade\MAME0266\mame281.exe',
    [string]$RomDirectory = 'E:\Arcade\MAME0266\roms',
    [string]$SourceRun = 'artifacts/deepseek/gate-28/natural-service',
    [string]$RunDirectory = 'artifacts/deepseek/capture-36/natural-service',
    [int]$SecondsToRun = 430,
    [int]$SaveCap = 48,
    [int]$EventCap = 512,
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
if($SaveCap -lt 1 -or $SaveCap -gt 128){throw 'SaveCap must be between 1 and 128'}
if($EventCap -lt 1 -or $EventCap -gt 4096){throw 'EventCap must be between 1 and 4096'}
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
$fmt='pc=%04X cyc=%016X s=%04X u=%04X x=%04X y=%04X a=%02X b=%02X dp=%02X cc=%02X 44=%02X 45=%04X 46=%04X 47=%04X 49=%04X 4b=%02X 4c=%02X 4d=%02X 4e=%02X 4f=%02X 50=%02X 27e=%04X 27f=%02X 280=%04X 281=%02X 282=%04X 283=%02X 719B=%02X st0=%04X st2=%04X st4=%04X st6=%04X st8=%04X st10=%04X ret=%04X'
$fmtArgs='pc,totalcycles,s,u,x,y,a,b,dp,cc,b@0x44,w@0x45,w@0x46,w@0x47,w@0x49,b@0x4b,b@0x4c,b@0x4d,b@0x4e,b@0x4f,b@0x50,w@0x27e,b@0x27f,w@0x280,b@0x281,w@0x282,b@0x283,b@0x719b,w@s,w@(s+2),w@(s+4),w@(s+6),w@(s+8),w@(s+10),w@s'
function Marker([string]$address,[string]$tag,[string]$condition,[string]$save,[string]$set,[bool]$quit,[bool]$opcode=$false){
    $format=$fmt
    $formatArguments=$fmtArgs
    if($opcode){$format+=' op=%02X';$formatArguments+=',b@u'}
    $cmd='printf "'+$tag+' '+$format+'\n",'+$formatArguments
    if($save){$cmd+=';save '+$save+',0,800'}
    if($set){$cmd+=';'+$set}
    $cmd+=';temp9=temp9+1'
    if($quit){$cmd+=';quit'}else{$cmd+=';go'}
    return "bpset 0x$address,$condition,{$cmd}"
}
function Overflow([string]$address,[string]$tag,[string]$condition){
    return "bpset 0x$address,$condition,{printf ""$tag pc=%04X cyc=%016X s=%04X ret=%04X\n"",pc,totalcycles,s,w@s;quit}"
}
$lines=[Collections.Generic.List[string]]::new()
foreach($i in 0..9){$lines.Add("temp$i=0")|Out-Null}
$lines.Add((Marker 'fc' 'fc' 'temp0==0 && y==0xfc4d' 'fc4d.bin' 'temp0=1' $false))|Out-Null
$lines.Add((Marker '5a14' '5a14' "temp0==1 && temp9<$EventCap" $null $null $false))|Out-Null
$lines.Add((Marker '5a01' '5a01' "temp0==1 && temp9<$EventCap" $null $null $false))|Out-Null
$lines.Add((Marker '5c18' '5c18' 'temp0==1 && temp4==0' 'queue.bin' 'temp4=1' $false))|Out-Null
$lines.Add((Marker '5a05' '5a05' "temp0==1 && temp9<$EventCap" $null $null $false))|Out-Null
$lines.Add((Marker 'fe70' 'fe70' "temp0==1 && temp9<$EventCap" $null $null $false))|Out-Null
$lines.Add((Marker 'ff13' 'ff13' "temp0==1 && temp9<$EventCap" $null $null $false))|Out-Null
$lines.Add((Marker 'fec9' 'fec9' "temp0==1 && temp9<$EventCap" $null $null $false))|Out-Null
for($k=0;$k -lt $SaveCap;$k++){
    $slot=$k.ToString('00')
    $lines.Add((Marker '5cd0' "sv$slot" "temp0==1 && temp2==$k && temp9<$EventCap" "sv-$slot.bin" "temp2=$($k+1)" $false))|Out-Null
}
$lines.Add((Overflow '5cd0' 'OVERFLOW_sv' "temp0==1 && temp2>=$SaveCap"))|Out-Null
for($k=0;$k -lt $SaveCap;$k++){
    $slot=$k.ToString('00')
    $lines.Add((Marker 'fecc' "fecc$slot" "temp0==1 && temp3==$k && temp9<$EventCap" "fecc-$slot.bin" "temp3=$($k+1)" $false))|Out-Null
}
$lines.Add((Overflow 'fecc' 'OVERFLOW_fecc' "temp0==1 && temp3>=$SaveCap"))|Out-Null
$lines.Add((Marker 'fece' 'fece' "temp0==1 && temp9<$EventCap" $null $null $false))|Out-Null
$lines.Add((Marker '5d3b' '5d3b' "temp0==1 && temp9<$EventCap" $null $null $false $true))|Out-Null
$lines.Add((Marker '5cf3' '5cf3' "temp0==1 && temp9<$EventCap" $null $null $false))|Out-Null
$lines.Add((Marker '5e29' '5e29' "temp0==1 && temp9<$EventCap" $null $null $false))|Out-Null
$lines.Add((Marker '5e2c' '5e2c' "temp0==1 && temp9<$EventCap" $null $null $false))|Out-Null
$lines.Add((Marker '5e6d' '5e6d' "temp0==1 && temp9<$EventCap" $null $null $false))|Out-Null
$lines.Add((Marker '5a0a' '5a0a' "temp0==1 && temp9<$EventCap" $null $null $false))|Out-Null
$lines.Add((Marker '5c7a' '5c7a' 'temp0==1 && temp5==0' 'cancel.bin' 'temp5=1' $false))|Out-Null
$lines.Add((Marker '5a10' '5a10' 'temp0==1 && temp6==0' 'return5a10.bin' 'temp6=1' $false))|Out-Null
$lines.Add((Marker '5a1c' '5a1c' 'temp0==1 && temp7==0' 'return5a1c.bin' 'temp7=1' $true))|Out-Null
foreach($a in @('fc','5a14','5a01','5c18','5a05','fe70','ff13','fec9','fecc','fece','5d3b','5cf3','5e29','5e2c','5e6d','5a0a','5c7a','5a10','5a1c')){
    if($a -eq 'fc'){continue}
    $lines.Add((Overflow $a 'OVERFLOW_event' "temp0==1 && temp9>=$EventCap"))|Out-Null
}
$lines.Add('go')|Out-Null
$lines.Add('quit')|Out-Null
Set-Content -LiteralPath (Join-Path $run 'debugger.cmd') -Value $lines -Encoding ASCII
$debuggerHash=HashFile (Join-Path $run 'debugger.cmd')
$arguments=@('m4addr','-noreadconfig','-rompath',$roms,'-cfg_directory',(Join-Path $run 'cfg'),'-nvram_directory',(Join-Path $run 'nvram'),'-input_directory',(Join-Path $run 'inp'),'-snapshot_directory',(Join-Path $run 'snap'),'-comment_directory',(Join-Path $run 'comments'),'-state_directory',(Join-Path $run 'state'),'-diff_directory',(Join-Path $run 'diff'),'-autoboot_delay','0','-autoboot_script',(Join-Path $run 'input.lua'),'-debug','-debugger','windows','-debugscript',(Join-Path $run 'debugger.cmd'),'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run',"$SecondsToRun")
$arguments|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $run 'arguments.json')
$provenance=[ordered]@{
 classification='controlled replay natural: recorded physical-input campaign, genuine MAME devices, original reset ROM/settings/NVRAM; no RAM/register/PTM/ACK/end-state injection; debugger breakpoints/reads/2KB saves only'
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

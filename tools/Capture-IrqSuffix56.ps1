param(
    [string]$MamePath = 'E:\Arcade\MAME0266\mame281.exe',
    [string]$RomDirectory = 'E:\Arcade\MAME0266\roms',
    [string]$SourceRun = 'artifacts/deepseek/gate-28/natural-service',
    [string]$RunDirectory = 'artifacts/deepseek/capture-56/natural-irq-suffix',
    [int]$SecondsToRun = 430,
    [int]$EventCap = 128,
    [int]$InstructionCap = 4096,
    [int]$HardTimeoutSeconds = 600,
    [switch]$GenerateOnly
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath("$PSScriptRoot/..")
function Abs([string]$p){if([IO.Path]::IsPathRooted($p)){[IO.Path]::GetFullPath($p)}else{[IO.Path]::GetFullPath((Join-Path $root $p))}}
function HashFile([string]$p,[string]$alg='SHA256'){([BitConverter]::ToString([Security.Cryptography.HashAlgorithm]::Create($alg).ComputeHash([IO.File]::ReadAllBytes($p)))-replace '-','')}
function HashBytes([byte[]]$bytes,[string]$algorithm='SHA256'){$sha=[Security.Cryptography.HashAlgorithm]::Create($algorithm);$hash=$sha.ComputeHash($bytes);return ([BitConverter]::ToString($hash) -replace '-','')}
$mame=Abs $MamePath
$roms=Abs $RomDirectory
$source=Abs $SourceRun
$run=Abs $RunDirectory
if(!(Test-Path -LiteralPath $mame)){throw 'Missing MAME executable'}
if(!(Test-Path -LiteralPath $roms)){throw 'Missing ROM directory'}
if(!(Test-Path -LiteralPath (Join-Path $source 'input.lua')) -or !(Test-Path -LiteralPath (Join-Path $source 'replay-actions.csv'))){throw 'Missing gate28 campaign source'}
if(Test-Path -LiteralPath $run){throw 'Fresh isolated directory required'}
if($EventCap -lt 1 -or $EventCap -gt 1024){throw 'EventCap must be between 1 and 1024'}
if($InstructionCap -lt 1 -or $InstructionCap -gt 65536){throw 'InstructionCap must be between 1 and 65536'}
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
$anchorFmt='pc=%04X cyc=%016X s=%04X u=%04X x=%04X y=%04X a=%02X b=%02X dp=%02X cc=%02X q719b=%02X m83=%02X m2=%02X m323=%02X m85=%02X m7c=%02X m71=%02X m72=%02X m3a5=%02X m3a6=%02X m7a=%04X m73=%02X piaA=%02X%02X%02X%02X%02X%02X msg=%02X'
$anchorArgs='pc,totalcycles,s,u,x,y,a,b,dp,cc,b@0x719b,b@0x83,b@0x2,w@0x323,b@0x85,b@0x7c,b@0x71,b@0x72,w@0x3a5,w@0x3a6,w@0x7a,b@0x73,b@0xa00,b@0xa02,b@0xb00,b@0xe01,b@0xb01,b@0xf01,b@0x38f'
$stackFmt='pc=%04X cyc=%016X s=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X wpaddr=%04X old=%02X new=%02X opm4=%02X opm3=%02X opm2=%02X opm1=%02X op0=%02X op1=%02X op2=%02X op3=%02X'
$stackArgs='pc,totalcycles,s,u,a,b,dp,cc,wpaddr,b@wpaddr,wpdata,b@(pc-4),b@(pc-3),b@(pc-2),b@(pc-1),b@pc,b@(pc+1),b@(pc+2),b@(pc+3)'
$lines=[Collections.Generic.List[string]]::new()
foreach($i in 0..9){$lines.Add("temp$i=0")|Out-Null}
$lines.Add(('bpset 0xfc,temp0==0 && y==0xfc4d,{printf "FC '+$anchorFmt+'\n",'+$anchorArgs+';save fc4d.bin,0,800;temp0=1;go}'))|Out-Null
$lines.Add(('bpset 0xfec3,temp0==1 && temp2==0 && b@pc==0xbd && w@(pc+1)==0x6b4d,{printf "TRACE_ENTRY '+$anchorFmt+'\n",'+$anchorArgs+';save fec3.bin,0,800;temp4=s;temp6=totalcycles;temp2=1;temp7=0;trace routine.trace,0,,{tracelog "cyc=%016X A=%02X B=%02X X=%04X Y=%04X U=%04X S=%04X CC=%02X ",totalcycles,a,b,x,y,u,s,cc};go}'))|Out-Null
$lines.Add(('bpset 0xfec6,temp2==1 && temp7==0 && s==temp4 && w@(s-2)==0xfec6,{printf "FEC6_RET '+$anchorFmt+'\n",'+$anchorArgs+';save fec6.bin,0,800;temp7=1;go}'))|Out-Null
$lines.Add(('bpset 0xfec6,temp2==1 && temp7==0 && (s!=temp4 || w@(s-2)!=0xfec6),{printf "FEC6_OTHER pc=%04X cyc=%016X s=%04X u=%04X x=%04X y=%04X a=%02X b=%02X dp=%02X cc=%02X entryS=%04X retword=%04X\n",pc,totalcycles,s,u,x,y,a,b,dp,cc,temp4,w@(s-2);go}'))|Out-Null
$lines.Add(('bpset 0xfec9,temp2==1 && temp7==1 && s==temp4,{printf "FEC9_RET '+$anchorFmt+'\n",'+$anchorArgs+';save fec9.bin,0,800;temp7=2;go}'))|Out-Null
$lines.Add(('bpset 0x5cd0,temp2==1 && temp7==2 && s==temp4-2 && w@(s)==0xfecc,{printf "SV_ENTRY '+$anchorFmt+'\n",'+$anchorArgs+';save sv.bin,0,800;temp7=3;go}'))|Out-Null
$lines.Add(('bpset 0xfecc,temp2==1 && temp7==3 && s==temp4 && w@(s-2)==0xfec6,{printf "FECC_RET '+$anchorFmt+'\n",'+$anchorArgs+';save fecc.bin,0,800;temp7=4;go}'))|Out-Null
$lines.Add(('bpset 0xfece,temp2==1 && temp7==4 && s==temp4,{printf "FECE_END '+$anchorFmt+'\n",'+$anchorArgs+';trace off,0;traceflush;save fece.bin,0,800;temp3=1;quit}'))|Out-Null
$lines.Add(('wpset 0x780,10,w,temp2==1 && temp5<'+$EventCap+',{printf "SW '+$stackFmt+'\n",'+$stackArgs+';temp5=temp5+1;go}'))|Out-Null
$lines.Add(('wpset 0x780,10,w,temp2==1 && temp5>='+$EventCap+',{printf "OVERFLOW_stack pc=%04X cyc=%016X s=%04X wpaddr=%04X\n",pc,totalcycles,s,wpaddr;trace off,0;traceflush;quit}'))|Out-Null
$lines.Add('go')|Out-Null
$lines.Add('quit')|Out-Null
Set-Content -LiteralPath (Join-Path $run 'debugger.cmd') -Value $lines -Encoding ASCII
$debuggerHash=HashFile (Join-Path $run 'debugger.cmd')
$arguments=@('m4addr','-noreadconfig','-rompath',$roms,'-cfg_directory',(Join-Path $run 'cfg'),'-nvram_directory',(Join-Path $run 'nvram'),'-input_directory',(Join-Path $run 'inp'),'-snapshot_directory',(Join-Path $run 'snap'),'-comment_directory',(Join-Path $run 'comments'),'-state_directory',(Join-Path $run 'state'),'-diff_directory',(Join-Path $run 'diff'),'-autoboot_delay','0','-autoboot_script',(Join-Path $run 'input.lua'),'-debug','-debugger','windows','-debugscript',(Join-Path $run 'debugger.cmd'),'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run',"$SecondsToRun")
$arguments|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $run 'arguments.json')
$provenance=[ordered]@{
 classification='controlled replay natural: recorded physical-input campaign, genuine MAME devices, original reset ROM/settings/NVRAM; no RAM/register/PTM/ACK/end-state injection; debugger breakpoints/watchpoints/reads/2KB saves/instruction trace only'
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
 event_cap=$EventCap
 instruction_cap=$InstructionCap
 save_cap='fc4d, fec3, fec6, fec9, sv, fecc, fece (full 2KB each); no state/playback loading'
 trace='routine.trace CPU0 from selected FEC3 JSR6B4D through matched FEC6, FEC9, 5CD0, FECC, FECE; loop detection default'
 watchpoint='0x0780 length 16 write; log PC/registers/cycles/wpaddr/old/new and opcode context; no memory write'
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
if(!(Test-Path -LiteralPath (Join-Path $run 'routine.trace'))){throw 'Missing routine.trace'}
$traceLines=@(Get-Content -LiteralPath (Join-Path $run 'routine.trace'))
if($traceLines.Count -gt $InstructionCap){throw "Trace exceeds instruction cap $InstructionCap"}
$traceLines.Count|Set-Content -LiteralPath (Join-Path $run 'trace-lines.txt') -Encoding ASCII
Write-Output $run

param(
    [string]$MamePath = 'E:\Arcade\MAME0266\mame281.exe',
    [string]$RomDirectory = 'E:\Arcade\MAME0266\roms',
    [string]$SourceRun = 'artifacts/deepseek/gate-28/natural-service',
    [string]$RunDirectory = 'artifacts/deepseek/capture-61/natural-irq-prefix',
    [int]$SecondsToRun = 430,
    [int]$EventCap = 256,
    [int]$InstructionCap = 16384,
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
$observer=@'
-- Capture61 read-only PTM saved-item observer. No RAM, CPU, PTM or input injection.
local c61m=manager.machine;local c61cpu=c61m.devices[':maincpu'];local c61mem=c61cpu.spaces['program'];local c61ptm=assert(c61m.devices[':ptm_ic2'])
local c61f=assert(io.open('ptm-state.csv','w'));c61f:setvbuf('no')
c61f:write('event,pc,seconds,attoseconds,output1,output2,output3,control1,control2,control3,latch1,latch2,latch3,counter1,counter2,counter3,enabled1,enabled2,enabled3,single1,single2,single3,mode1,mode2,mode3,status,status_read,irq,gate1,gate2,gate3,clk1,clk2,clk3,t3_divisor,t3_scaler,cc,s,y,u\n')
local c61seen_fc=false;local c61outer=false;local c61nested=false;local c61returned=false;local c61fec3=false
local function c61item(n,i) return emu.item(assert(c61ptm.items['0/'..n])):read(i or 0) end
local function c61sample(event)
 local ok,err=pcall(function()
  c61f:write(string.format('%s,%04X,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%02X,%04X,%04X,%04X\n',event,c61cpu.state['PC'].value,c61m.time.seconds,c61m.time.attoseconds,
   c61item('m_output',0),c61item('m_output',1),c61item('m_output',2),
   c61item('m_control_reg',0),c61item('m_control_reg',1),c61item('m_control_reg',2),
   c61item('m_latch',0),c61item('m_latch',1),c61item('m_latch',2),
   c61item('m_counter',0),c61item('m_counter',1),c61item('m_counter',2),
   c61item('m_enabled',0),c61item('m_enabled',1),c61item('m_enabled',2),
   c61item('m_single_fired',0),c61item('m_single_fired',1),c61item('m_single_fired',2),
   c61item('m_mode',0),c61item('m_mode',1),c61item('m_mode',2),
   c61item('m_status_reg'),c61item('m_status_read_since_int'),c61item('m_irq'),
   c61item('m_gate',0),c61item('m_gate',1),c61item('m_gate',2),
   c61item('m_clk',0),c61item('m_clk',1),c61item('m_clk',2),
   c61item('m_t3_divisor'),c61item('m_t3_scaler'),
   c61cpu.state['CC'].value,c61cpu.state['S'].value,c61cpu.state['Y'].value,c61cpu.state['U'].value))
 end)
 if not ok then c61f:write('ERROR '..tostring(err)..'\n') end
end
_G.c61_fc=c61mem:install_read_tap(0xfc,0xfc,'c61-fc',function(address,data)
 if not c61seen_fc and c61cpu.state['PC'].value==0xfd and c61cpu.state['Y'].value==0xfc4d then c61seen_fc=true end
end)
_G.c61_fe70=c61mem:install_read_tap(0xfe70,0xfe70,'c61-fe70',function(address,data)
 if not c61seen_fc or c61cpu.state['PC'].value~=0xfe71 then return end
 if not c61outer then c61outer=true;c61sample('outer') elseif not c61nested then c61nested=true;c61sample('nested') end
end)
_G.c61_ff13=c61mem:install_read_tap(0xff13,0xff13,'c61-ff13',function(address,data)
 if c61nested and not c61returned and c61cpu.state['PC'].value==0xff14 then c61returned=true;c61sample('nested_return') end
end)
_G.c61_fec3=c61mem:install_read_tap(0xfec3,0xfec3,'c61-fec3',function(address,data)
 if c61returned and not c61fec3 and c61cpu.state['PC'].value==0xfec4 then c61fec3=true;c61sample('fec3') end
end)
'@
$derivedInput=$derivedInput+"`r`n"+$observer+"`r`n"
[IO.File]::WriteAllText((Join-Path $run 'input.lua'),$derivedInput,[Text.UTF8Encoding]::new($false))
$derivedInputHash=HashFile (Join-Path $run 'input.lua')
$anchorFmt='pc=%04X cyc=%016X s=%04X u=%04X x=%04X y=%04X a=%02X b=%02X dp=%02X cc=%02X twoC=%02X m44=%02X m6b=%02X m29=%02X w1400=%04X q719b=%02X q719c=%02X r2=%04X r0=%04X s0=%04X s2=%04X s4=%04X'
$anchorArgs='pc,totalcycles,s,u,x,y,a,b,dp,cc,b@0x2c,b@0x44,b@0x6b,b@0x29,w@0x1400,b@0x719b,b@0x719c,w@(s-2),w@s,w@s,w@(s+2),w@(s+4)'
$stackFmt='pc=%04X cyc=%016X s=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X wpaddr=%04X old=%02X new=%02X op0=%02X op1=%02X op2=%02X op3=%02X'
$stackArgs='pc,totalcycles,s,u,a,b,dp,cc,wpaddr,b@wpaddr,wpdata,b@pc,b@(pc+1),b@(pc+2),b@(pc+3)'
$lines=[Collections.Generic.List[string]]::new()
foreach($i in 0..9){$lines.Add("temp$i=0")|Out-Null}
$lines.Add(('bpset 0xfc,temp0==0 && y==0xfc4d,{printf "FC '+$anchorFmt+'\n",'+$anchorArgs+';save fc4d.bin,0,800;temp0=1;go}'))|Out-Null
$lines.Add(('bpset 0xfe70,temp0==1 && temp1==0,{printf "OUTER_FE70 '+$anchorFmt+'\n",'+$anchorArgs+';save fe70.bin,0,800;temp8=s;temp9=w@s;temp1=1;trace routine.trace,0,,{tracelog "cyc=%016X A=%02X B=%02X X=%04X Y=%04X U=%04X S=%04X CC=%02X OP=%02X%02X%02X%02X ",totalcycles,a,b,x,y,u,s,cc,b@pc,b@(pc+1),b@(pc+2),b@(pc+3)};go}'))|Out-Null
$lines.Add(('bpset 0xfe70,temp0==1 && temp1==1 && temp2==0,{printf "NESTED_FE70 '+$anchorFmt+'\n",'+$anchorArgs+';save fe70_nested.bin,0,800;temp2=1;go}'))|Out-Null
$lines.Add(('bpset 0xff13,temp0==1 && temp2==1 && temp3==0,{printf "NESTED_RETURN '+$anchorFmt+'\n",'+$anchorArgs+';save ff13.bin,0,800;temp3=1;go}'))|Out-Null
$lines.Add(('bpset 0x2851,temp0==1 && temp2==1 && temp3==1 && temp4==0,{printf "GUARD_2851 '+$anchorFmt+'\n",'+$anchorArgs+';temp4=1;go}'))|Out-Null
$lines.Add(('bpset 0x288e,temp0==1 && temp4==1 && temp5==0,{printf "GUARD_1400_RTS '+$anchorFmt+'\n",'+$anchorArgs+';temp5=1;go}'))|Out-Null
$lines.Add(('bpset 0xfec3,temp0==1 && temp1==1 && temp2==1 && temp3==1 && temp5==1 && temp6==0 && s==temp8 && w@s==temp9 && w@(s-2)==0xfec3,{printf "FEC3_ENTRY '+$anchorFmt+'\n",'+$anchorArgs+';save fec3.bin,0,800;trace off,0;traceflush;temp6=1;temp4=0;go}'))|Out-Null
$lines.Add(('bpset 0xfec3,temp0==1 && temp1==1 && temp6==0 && (temp2==0 || temp3==0 || temp5==0 || s!=temp8 || w@s!=temp9 || w@(s-2)!=0xfec3),{printf "UNSUPPORTED_FEC3 pc=%04X cyc=%016X s=%04X outerS=%04X outerRet=%04X ret2=%04X stageN=%02X stageR=%02X stageG=%02X\n",pc,totalcycles,s,temp8,temp9,w@(s-2),temp2,temp3,temp5;trace off,0;traceflush;quit}'))|Out-Null
$lines.Add(('bpset 0xfece,temp6==1 && temp7==0,{printf "FECE_SUFFIX '+$anchorFmt+'\n",'+$anchorArgs+';save fece.bin,0,800;temp7=1;quit}'))|Out-Null
$lines.Add(('bpset 0x288f,temp0==1,{printf "UNSUPPORTED_SWI2 pc=%04X cyc=%016X s=%04X\n",pc,totalcycles,s;trace off,0;traceflush;quit}'))|Out-Null
$lines.Add(('bpset 0x6407,temp0==1,{printf "UNSUPPORTED_6403_ACTIVE pc=%04X cyc=%016X m6b=%02X\n",pc,totalcycles,b@0x6b;trace off,0;traceflush;quit}'))|Out-Null
$lines.Add(('bpset 0x439a,temp0==1 && w@0xc6!=0x19b8,{printf "UNSUPPORTED_C6 pc=%04X cyc=%016X c6=%04X\n",pc,totalcycles,w@0xc6;trace off,0;traceflush;quit}'))|Out-Null
$lines.Add(('bpset 0x4167,temp0==1,{printf "UNSUPPORTED_4167 pc=%04X cyc=%016X\n",pc,totalcycles;trace off,0;traceflush;quit}'))|Out-Null
$lines.Add(('bpset 0x7ccf,temp0==1,{printf "UNSUPPORTED_7CCF pc=%04X cyc=%016X\n",pc,totalcycles;trace off,0;traceflush;quit}'))|Out-Null
$lines.Add(('wpset 0x780,10,w,temp6==1 && temp7==0 && temp4<'+$EventCap+',{printf "SW '+$stackFmt+'\n",'+$stackArgs+';temp4=temp4+1;go}'))|Out-Null
$lines.Add(('wpset 0x780,10,w,temp6==1 && temp7==0 && temp4>='+$EventCap+',{printf "OVERFLOW_stack pc=%04X cyc=%016X s=%04X wpaddr=%04X\n",pc,totalcycles,s,wpaddr;trace off,0;traceflush;quit}'))|Out-Null
$lines.Add('go')|Out-Null
$lines.Add('quit')|Out-Null
Set-Content -LiteralPath (Join-Path $run 'debugger.cmd') -Value $lines -Encoding ASCII
$debuggerHash=HashFile (Join-Path $run 'debugger.cmd')
$arguments=@('m4addr','-noreadconfig','-rompath',$roms,'-cfg_directory',(Join-Path $run 'cfg'),'-nvram_directory',(Join-Path $run 'nvram'),'-input_directory',(Join-Path $run 'inp'),'-snapshot_directory',(Join-Path $run 'snap'),'-comment_directory',(Join-Path $run 'comments'),'-state_directory',(Join-Path $run 'state'),'-diff_directory',(Join-Path $run 'diff'),'-autoboot_delay','0','-autoboot_script',(Join-Path $run 'input.lua'),'-debug','-debugger','windows','-debugscript',(Join-Path $run 'debugger.cmd'),'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run',"$SecondsToRun")
$arguments|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $run 'arguments.json')
$timerSourceRoot='C:\projects\GitRepos\mame'
$timerSources=[ordered]@{}
foreach($rel in @('src/devices/machine/6840ptm.cpp','src/devices/machine/6840ptm.h','src/mame/barcrest/mpu4.cpp','src/mame/barcrest/mpu4.h')){
    $p=Join-Path $timerSourceRoot $rel
    if(!(Test-Path -LiteralPath $p)){throw "Missing MAME source $rel"}
    $timerSources[$rel]=HashFile $p
}
$provenance=[ordered]@{
 classification='controlled replay natural: recorded physical-input campaign, genuine MAME devices, original reset ROM/settings/NVRAM; no RAM/register/PTM/ACK/end-state/input injection; debugger breakpoints/watchpoint/reads/2KB saves/instruction trace and read-only Lua PTM saved-item sampling only'
 source_run=$SourceRun
 source_input_lua_sha256=$inputExpected
 derived_input_lua_sha256=$derivedInputHash
 input_lua_patch='removed only the debugger-startup frame assertion and set its skip guard to zero, then appended a read-only PTM saved-item observer; replay/physical-input/event code unchanged'
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
 save_cap='fc4d, fe70, fe70_nested, ff13, fec3, fece (full 2KB each); no state/playback loading'
 selection_rule='fresh first FC4D window; outer FE70 is the first FE70 after it, nested FE70 is the next FE70, FF13 is the nested return; guard RTS at 288E must be taken; FEC3 entry additionally requires S=outerS, w@s=outer return word and w@(s-2)=FEC3; no old absolute cycles or historical fitting'
 trace='routine.trace CPU0 from selected outer FE70 before its first instruction through matched FEC3 entry, including nested FE70/FF13; logs cycle, A/B/X/Y/U/S/CC, actual opcode bytes and PC/disassembly; loop detection default'
 watchpoint='0x0780 length 16 write; enabled only after matched FEC3, before suffix FECE; logs PC/registers/cycles/wpaddr/old/new and opcode context; no memory write'
 timer_state='read-only Lua emu.item saved-state reads of ptm_ic2 m_output/m_control_reg/m_latch/m_counter/m_enabled/m_single_fired/m_mode/m_status_reg/m_status_read_since_int/m_irq/m_gate/m_clk/m_t3_divisor/m_t3_scaler at outer FE70, nested FE70, FF13 and FEC3'
 timer_source='local installed MAME source tree used only to identify saved-state item names/semantics; actual values come from the running pinned mame281.exe'
 timer_source_root=$timerSourceRoot
 timer_source_sha256=$timerSources
 limits='m_counter is MAME saved reload/frozen counter field, not a continuously decremented register; remaining timer ticks are not exposed by the Lua saved-item API and are not inferred. No whole-IRQ/cadence/Live/hardware/gate-3 claim.'
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
if(!(Test-Path -LiteralPath (Join-Path $run 'ptm-state.csv'))){throw 'Missing ptm-state.csv'}
if(Select-String -LiteralPath (Join-Path $run 'ptm-state.csv') -Pattern '^ERROR ' -Quiet){throw 'PTM observer failed'}
$traceLines=@(Get-Content -LiteralPath (Join-Path $run 'routine.trace'))
if($traceLines.Count -gt $InstructionCap){throw "Trace exceeds instruction cap $InstructionCap"}
$traceLines.Count|Set-Content -LiteralPath (Join-Path $run 'trace-lines.txt') -Encoding ASCII
Write-Output $run


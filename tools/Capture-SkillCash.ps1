param(
    [Parameter(Mandatory=$true)][string]$MameExecutable,
    [Parameter(Mandatory=$true)][string]$RomDirectory,
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [switch]$NativeSound,
    [switch]$NativeNvram,
    [switch]$FullFeature,
    [switch]$NativeInput,
    [switch]$NativeLampFrames,
    [switch]$NativeAlpha,
    [switch]$NativeScan,
    [switch]$SharedTiming,
    [switch]$TimerDeadlines,
    [switch]$CpuInterrupts,
    [switch]$JackpotProbe,
    [switch]$CashFeatureCaller,
    [switch]$BoardResultCaller,
    [switch]$BoardSelection,
    [switch]$DiceRequests,
    [switch]$DiceMotion,
    [switch]$BoardMovement,
    [switch]$NudgePotProbe,
    [switch]$ContinueBoard,
    [switch]$Availability,
    [switch]$NudgeEntry,
    [switch]$NudgePrompt,
    [switch]$NudgeRequest,
    [switch]$NudgeMotion,
    [switch]$NudgeStack,
    [switch]$NudgeReturn,
    [switch]$NudgeSequence,
    [switch]$NudgeResult,
    [switch]$NudgeExit,
    [switch]$NudgeWinTransfer,
    [switch]$NudgeTail,
    [switch]$NudgeAccounting,
    [switch]$NudgeBankReturn,
    [switch]$NudgeCycleInit,
    [switch]$NudgeIc8,
    [switch]$NudgeBackground,
    [switch]$NudgeStatus,
    [switch]$NudgeServices,
    [switch]$NudgePreplay,
    [switch]$NudgeEligibility,
    [switch]$NudgeStart,
    [switch]$NudgeStake,
    [switch]$NudgeTone,
    [switch]$NudgeSpinFlags,
    [switch]$NudgeSpinGates,
    [switch]$TailWindow,
    [switch]$NoMotorItems,
    [ValidateSet('Ladder','Snake')][string]$BoardLink
)
$ErrorActionPreference='Stop'
if($NudgeStack -and !$NudgeMotion){throw 'NudgeStack requires NudgeMotion'}
if($NudgeSpinGates -and !$NudgeSpinFlags){throw 'NudgeSpinGates requires NudgeSpinFlags'}
if($NudgeSpinFlags -and !$NudgeTone){throw 'NudgeSpinFlags requires NudgeTone'}
if($NudgeTone -and !$NudgeStake){throw 'NudgeTone requires NudgeStake'}
if($NudgeStake -and !$NudgeStart){throw 'NudgeStake requires NudgeStart'}
if($NudgeStart -and !$NudgeEligibility){throw 'NudgeStart requires NudgeEligibility'}
if($NudgeEligibility -and !$NudgePreplay){throw 'NudgeEligibility requires NudgePreplay'}
if($NudgePreplay -and !$NudgeServices){throw 'NudgePreplay requires NudgeServices'}
if($NudgeServices -and !$NudgeStatus){throw 'NudgeServices requires NudgeStatus'}
if($NudgeStatus -and !$NudgeBackground){throw 'NudgeStatus requires NudgeBackground'}
if($NudgeBackground -and !$NudgeIc8){throw 'NudgeBackground requires NudgeIc8'}
if($NudgeIc8 -and !$NudgeCycleInit){throw 'NudgeIc8 requires NudgeCycleInit'}
if($NudgeCycleInit -and !$NudgeBankReturn){throw 'NudgeCycleInit requires NudgeBankReturn'}
if($NudgeBankReturn -and !$NudgeAccounting){throw 'NudgeBankReturn requires NudgeAccounting'}
if($NudgeAccounting -and (!$TailWindow -or !$NudgeTail)){throw 'NudgeAccounting requires TailWindow/NudgeTail'}
if($TailWindow -and !$NudgeTail){throw 'TailWindow requires NudgeTail'}
if($NudgeTail -and !$NudgeWinTransfer){throw 'NudgeTail requires NudgeWinTransfer'}
if($NudgeWinTransfer -and !$NudgeExit){throw 'NudgeWinTransfer requires NudgeExit'}
if($NudgeExit -and !$NudgeResult){throw 'NudgeExit requires NudgeResult'}
if($NudgeResult -and !$NudgeSequence){throw 'NudgeResult requires NudgeSequence'}
if($NudgeSequence -and !$NudgeReturn){throw 'NudgeSequence requires NudgeReturn'}
if($NudgeReturn -and !$NudgeMotion){throw 'NudgeReturn requires NudgeMotion'}
if($ContinueBoard -and (!$BoardMovement -and !$BoardLink -or $NudgePotProbe)){throw 'ContinueBoard requires a natural BoardMovement or BoardLink capture'}
if($NudgeMotion -and !$NudgeRequest){throw 'NudgeMotion requires NudgeRequest'}
if($NudgeRequest -and !$NudgePrompt){throw 'NudgeRequest requires NudgePrompt'}
if($NudgePrompt -and !$NudgeEntry){throw 'NudgePrompt requires NudgeEntry'}
if($NudgeEntry -and (!$Availability -or !$ContinueBoard -or $BoardLink -ne 'Ladder')){throw 'NudgeEntry requires Ladder/ContinueBoard/Availability'}
if($Availability -and (!$ContinueBoard -or $BoardLink -ne 'Ladder')){throw 'Availability requires natural ladder continuation'}
$root=Split-Path $PSScriptRoot -Parent
$run=[System.IO.Path]::GetFullPath($RunDirectory)
if(Test-Path -LiteralPath $run){throw 'Use a fresh run directory; existing evidence is never overwritten'}
New-Item -ItemType Directory -Path $run | Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory (Join-Path $run $name) | Out-Null}
Copy-Item (Join-Path $root 'evidence/mpu4/skill-cash/input.lua') "$run/input.lua"
Copy-Item (Join-Path $root 'evidence/mpu4/skill-cash/actions.csv') "$run/replay-actions.csv"
$format='SC y=%04X token=%04X u=%04X top=%04X second=%04X third=%04X fourth=%04X s=%04X f4=%04X f6=%04X frame=%04X tick=%04X irq=%02X seed=%04X choice=%02X rate=%02X latch=%04X opt=%04X abort=%04X pending=%04X win=%04X\n'
$values='y,w@y,u,w@u,w@(u+2),w@(u+4),w@(u+6),s,w@0xf4,w@0xf6,w@(w@0xf4),w@0x2d,b@0x33,w@0x324,b@0x4f,b@0x4e,w@0x90,w@0x719f,w@0x719b,w@0xba,w@0x2fa'
$extra=@()
$statusPrint=if($NudgeStatus){';printf "HW y=%04X aux=%02X\n",y,b@0xc02'}else{''}
$ioPrint=if($NudgeIc8){';printf "IO y=%04X value=%02X control=%02X\n",y,b@0xf02,b@0xf03'}else{''}
if($BoardMovement -or $BoardLink){$format=$format.Replace('\n',' board=%02X pot=%02X\n');$values+=',b@0xc9,b@0xbf'}
if($SharedTiming -or $CpuInterrupts) {$format=$format.Replace('\n',' cycle=%016X\n');$values+=',totalcycles'}
if($FullFeature) {
 $format=$format.Replace('\n',' guard=%02X checksum=%02X mode=%02X display=%04X suppress=%04X\n')
 $values+=',b@0x2c,b@0x322,b@0x323,w@0x327,w@0xa0'
}
if($NativeSound) {
 $format=$format.Replace('\n',' clock=%04X\n');$values+=',w@0x45'
 $extra=@(
  'bpset 0x5c18,temp0==1,{printf "SQ stream=%04X clock=%04X rate=%02X volume=%02X abort=%04X free=%04X\n",x,w@0x45,b@0x4e,b@0x50,w@0x719b,w@0x49;go}',
  'bpset 0x5c46,temp0==1,{printf "QE stream=%04X clock=%04X task=%04X rate=%02X\n",w@(y+0x13),w@0x45,y,b@0x4e;go}',
  'bpset 0x5d3b,temp0==1,{printf "SN cursor=%04X opcode=%02X task=%04X clock=%04X choice=%02X rate=%02X tempo=%02X gate=%02X flags=%02X pitch=%02X transpose=%02X\n",u,b@u,y,w@0x45,b@0x4f,b@0x4e,b@(y+0xe),b@(y+0x10),b@(y+0x12),b@(y+0xc),b@(y+0xd);go}',
  'bpset 0x5cf3,temp0==1,{printf "SW duration=%02X cursor=%04X task=%04X clock=%04X callback=%04X rate=%02X tempo=%02X flags=%02X\n",b,u,y,w@0x45,w@s,b@0x4e,b@(y+0xe),b@(y+0x12);go}',
  'wpset 0x4f,1,w,temp0==1,{printf "WC pc=%04X cursor=%04X task=%04X clock=%04X old=%02X value=%02X\n",pc,u,y,w@0x45,b@0x4f,wpdata;go}',
  'bpset 0x5b77,temp0==1,{printf "SR clock=%04X choice=%02X rate=%02X\n",w@0x45,b@0x4f,b@0x4e;go}'
 )
}
if($NativeNvram) {
 $stateFormat=''
 $stateValues=''
 foreach($address in 0x2F0..0x308) {$stateFormat+=' source'+$address.ToString('X4')+'=%02X';$stateValues+=',b@0x'+$address.ToString('X4')}
 foreach($address in 0x309..0x321) {$stateFormat+=' copy'+$address.ToString('X4')+'=%02X';$stateValues+=',b@0x'+$address.ToString('X4')}
 $nvFormat=' mode=%02X guard=%02X checksum=%02X u=%04X s=%04X pending=%04X win=%04X'+$stateFormat+'\n'
 $nvValues='b@0x323,b@0x2c,b@0x322,u,s,w@0xba,w@0x2fa'+$stateValues
 $extra+=@(('bpset 0x6e06,temp0==1,{printf "NI'+$nvFormat+'",'+$nvValues+';go}'),
 ('bpset 0x6e68,temp0==1,{printf "NO'+$nvFormat+'",'+$nvValues+';go}'))
}
if($NativeInput) {
 $extra+=@('bpset 0x67ec,temp0==1,{printf "PI selector=%02X p0=%02X p1=%02X p2=%02X p3=%02X p6=%02X p7=%02X clock=%04X\n",b@x,b@0,b@1,b@2,b@3,b@6,b@7,w@0x45;go}')
}
if($NativeLampFrames) {
 $frameFormat='';$frameValues=''
 for($address=0x100;$address -lt 0x140;$address+=2){$frameFormat+='%04X';$frameValues+=',w@0x'+$address.ToString('X4')}
 $extra+=@(('bpset 0x49c5,temp0==1,{printf "LI id=%02X pattern=%02X frames='+$frameFormat+'\n",a,b'+$frameValues+';go}'),
 ('bpset 0x4a23,temp0==1,{printf "LF id=%02X pattern=%02X column=%02X frames='+$frameFormat+'\n",b@s,b@(s+1),x-0x100'+$frameValues+';go}'))
}
if($NativeAlpha) {
 $alphaFormat=' cursor=%02X control=%02X stop=%02X mirror=%02X digit=%02X shadow=%04X%04X%04X%04X%04X%04X%04X%04X digits=%04X%04X%04X%04X pending=%04X win=%04X display=%04X credit=%04X clock=%04X tick=%04X\n'
 $alphaValues='b@0x54,b@0x55,b@0x57,b@0xc5,b@0xc4,w@0x58,w@0x5a,w@0x5c,w@0x5e,w@0x60,w@0x62,w@0x64,w@0x66,w@0x1a,w@0x1c,w@0x1e,w@0x20,w@0xba,w@0x2fa,w@0x327,w@0x2f0,w@0x45,w@0x2d'
 $extra+=@(('bpset 0x3cc0,temp0==1,{printf "AE stream=%04X'+$alphaFormat+'",x,'+$alphaValues+';go}'),
 ('bpset 0x774e,temp0==1,{printf "AX next=%04X'+$alphaFormat+'",w@0x52,'+$alphaValues+';go}'),
 ('bpset 0x3d0e,temp0==1,{printf "AR'+$alphaFormat+'",'+$alphaValues+';go}'),
 ('bpset 0x3d5d,temp0==1,{printf "AZ'+$alphaFormat+'",'+$alphaValues+';go}'),
 'bpset 0x400d,temp0==1,{printf "AB value=%02X clock=%04X tick=%04X\n",a,w@0x45,w@0x2d;go}')
}
if($NativeScan) {
 $scanFormat=' phase=%02X count=%02X reload=%02X alternate=%02X alternate_reload=%02X column=%04X suppress=%02X decimal=%02X sweep=%02X samples=%04X%04X%04X%04X digits=%04X%04X%04X%04X blink=%04X%04X%04X%04X ports=%02X%02X%02X%02X%02X%02X clock=%04X tick=%04X frames='
 $scanValues='b@0x23,b@0x24,b@0x25,b@0x26,b@0x27,w@0x28,b@0x8d,b@0x22,b@0xb3,w@8,w@0xa,w@0xc,w@0xe,w@0x1a,w@0x1c,w@0x1e,w@0x20,w@0x2be,w@0x2c0,w@0x2c2,w@0x2c4,b@0xa00,b@0xa02,b@0xb00,b@0xe01,b@0xb01,b@0xf01,w@0x45,w@0x2d'
 for($address=0x100;$address -lt 0x140;$address+=2){$scanFormat+='%04X';$scanValues+=',w@0x'+$address.ToString('X4')}
 $scanFormat+='\n'
 $extra+=@(('bpset 0x28fe,temp0==1,{printf "SI'+$scanFormat+'",'+$scanValues+';go}'),
 ('bpset 0x29ba,temp0==1,{printf "SX'+$scanFormat+'",'+$scanValues+';go}'),
 'bpset 0x19c2,temp0==1,{printf "PE enabled=%02X count=%02X reload=%02X step=%02X timer=%04X callback=%04X control=%04X clock=%04X tick=%04X\n",b@0xb3,b@0xe8,b@0xe9,b@0xea,w@0x32d,w@0x3d,w@0x3f,w@0x45,w@0x2d;go}',
 'bpset 0x19f8,temp0==1,{printf "PX enabled=%02X count=%02X reload=%02X step=%02X timer=%04X callback=%04X control=%04X clock=%04X tick=%04X\n",b@0xb3,b@0xe8,b@0xe9,b@0xea,w@0x32d,w@0x3d,w@0x3f,w@0x45,w@0x2d;go}')
}
if($SharedTiming) {
 $extra+=@(
 'bpset 0x49c5,temp0==1,{printf "ML cycle=%016X id=%02X pattern=%02X\n",totalcycles,a,b;go}',
 'wpset 0x100,0x40,w,temp0==1,{printf "MW cycle=%016X address=%04X value=%02X\n",totalcycles,wpaddr,wpdata;go}',
 'bpset 0x4a23,temp0==1,{printf "MF cycle=%016X\n",totalcycles;go}',
 'bpset 0x28fe,temp0==1,{printf "MS cycle=%016X phase=%02X count=%02X reload=%02X alternate=%02X alternate_reload=%02X column=%04X suppress=%02X decimal=%02X sweep=%02X sample=%04X%04X%04X%04X digits=%04X%04X%04X%04X blink=%04X%04X%04X%04X ports=%02X%02X%02X%02X%02X%02X pulse=%04X%02X%04X masks=%04X%04X%04X%04X%04X%04X%04X%04X blank=%04X%04X%04X%04X\n",totalcycles,b@0x23,b@0x24,b@0x25,b@0x26,b@0x27,w@0x28,b@0x8d,b@0x22,b@0xb3,w@8,w@0xa,w@0xc,w@0xe,w@0x1a,w@0x1c,w@0x1e,w@0x20,w@0x2be,w@0x2c0,w@0x2c2,w@0x2c4,b@0xa00,b@0xa02,b@0xb00,b@0xe01,b@0xb01,b@0xf01,w@0xe8,b@0xea,w@0x32d,w@0x140,w@0x142,w@0x144,w@0x146,w@0x148,w@0x14a,w@0x14c,w@0x14e,w@0xab,w@0xad,w@0xaf,w@0xb1;go}',
 'bpset 0x29ba,temp0==1,{printf "MX cycle=%016X phase=%02X count=%02X alternate=%02X column=%04X ports=%02X%02X%02X%02X%02X%02X\n",totalcycles,b@0x23,b@0x24,b@0x26,w@0x28,b@0xa00,b@0xa02,b@0xb00,b@0xe01,b@0xb01,b@0xf01;go}',
 'bpset 0x70ef,temp0==1,{printf "MA cycle=%016X timer=%04X callback=%04X\n",totalcycles,y,x;go}',
 'bpset 0x48fd,temp0==1,{printf "MC cycle=%016X column=%04X ports=%02X%02X%02X\n",totalcycles,w@0x28,b@0xa00,b@0xa02,b@0xb00;go}',
 'bpset 0x4916,temp0==1,{printf "MD cycle=%016X column=%04X ports=%02X%02X%02X\n",totalcycles,w@0x28,b@0xa00,b@0xa02,b@0xb00;go}'
 )
}
if($TimerDeadlines) {
 $extra+=@(
 'wpset 0x907,1,w,temp0==1,{printf "TL cycle=%016X pc=%04X value=%02X timer=%04X control=%02X\n",totalcycles,pc,wpdata,y,b@0x40;go}',
 'bpset 0xfe70,temp0==1,{printf "TI cycle=%016X cc=%02X\n",totalcycles,cc;go}',
 'bpset 0x48fd,temp0==1,{printf "TC cycle=%016X column=%04X\n",totalcycles,w@0x28;go}'
 )
}
if($CpuInterrupts) {
 $extra+=@(
 'bpset 0xfe70,temp0==1,{printf "IE cycle=%016X s=%04X resume=%04X\n",totalcycles,s,w@(s+10);go}',
 'bpset 0xff13,temp0==1,{printf "IX cycle=%016X s=%04X resume=%04X\n",totalcycles,s,w@(s+10);go}'
 )
}
$print='printf "'+$format+'",'+$values+$ioPrint+$statusPrint
if($NudgePotProbe -and !$BoardMovement){throw 'Nudge pot probe requires BoardMovement'}
if($BoardLink){
 if(!$FullFeature -or !$CpuInterrupts -or !$NativeSound -or $BoardMovement -or $BoardSelection -or $DiceRequests -or $DiceMotion -or $JackpotProbe){throw 'Board link requires FullFeature, CPU interrupts and native sound, excluding other entry modes'}
 $relation=if($BoardLink -eq 'Ladder'){'>'}else{'<'}
 if($NudgeEntry){$extra+=@("bpset 0xfc,temp0==0 && temp2==0 && y==0xe247,{$print;save boundary-ram.bin,0,800;$(if($NudgeStake){'save config-entry.bin,7190,1a;'})temp0=1;temp2=1;go}")}else{$extra+=@("bpset 0xfc,temp0==0 && temp2==0 && y==0xdbc4 && b@(0xa160+b@0xc9)!=0 && b@(0xa160+b@0xc9)${relation}b@0xc9,{$print;save boundary-ram.bin,0,800;$(if($NudgeStake){'save config-entry.bin,7190,1a;'})temp0=1;temp2=1;go}")}
}
if($BoardMovement){if(!$FullFeature -or !$CpuInterrupts -or !$NativeSound -or $BoardSelection -or $DiceRequests -or $DiceMotion -or $JackpotProbe){throw 'Board movement requires FullFeature, CPU interrupts and native sound, excluding other boundary modes'};$probeEntry=if($NudgePotProbe){'y=0xdde3;'}else{''};$extra+=@("bpset 0xfc,temp0==0 && temp2==0 && y==0xb28f && b@0xc9==7,{$probeEntry$print;save boundary-ram.bin,0,800;$(if($NudgeStake){'save config-entry.bin,7190,1a;'})temp0=1;temp2=1;go}")}
if($BoardSelection){if(!$FullFeature -or $JackpotProbe -or !$CpuInterrupts -or !$NativeSound){throw 'Board selection requires full feature, CPU interrupts and native sound'};$extra+=@("bpset 0xfc,temp0==0 && temp2==0 && y==0xdd38 && b@0xc9==0x20,{$print;save boundary-ram.bin,0,800;$(if($NudgeStake){'save config-entry.bin,7190,1a;'})temp0=1;temp2=1;go}")}
if($DiceRequests -or $DiceMotion){if(!$FullFeature -or $BoardSelection -or $JackpotProbe){throw 'Dice capture requires FullFeature and excludes other boundary experiments'};$extra+=@("bpset 0xfc,temp0==0 && temp2==0 && y==0xdd7e && b@0xc9==7,{$print;save boundary-ram.bin,0,800;$(if($NudgeStake){'save config-entry.bin,7190,1a;'})temp0=1;temp2=1;go}")}
if($DiceMotion -or $NudgeMotion) {
 $motionFormat='RM pc=%04X cycle=%016X flags=%04X%02X drive=%04X optic=%02X c2=%04X abort=%04X records='
 $motionValues='pc,totalcycles,w@0x6a,b@0x6c,w@0x6d,b@0xb02,w@0xc2,w@0x719b'
 for($address=0x150;$address -lt 0x1A0;$address+=2){$motionFormat+='%04X';$motionValues+=',w@0x'+$address.ToString('X4')}
 $motionFormat+=' nvram=%04X%04X checksum=%02X x=%04X mask=%02X phases=%04X control=%02X\n';$motionValues+=',w@0x2f2,w@0x2f4,b@0x322,x,b@(s+2),w@0x6f,b@0xb03'
 foreach($address in @('61f6','6228','623a','6248','6403','649b','64f0','656b')) {
  $extra+=('bpset 0x'+$address+',temp0==1,{printf "'+$motionFormat+'",'+$motionValues+';go}')
 }
 $motorLua=@'
local motor_items=assert(io.open('motor-items.txt','w'))
for tag,device in pairs(m.devices) do
 if tag:find('reel') then
  for name,id in pairs(device.items) do motor_items:write(tag,' ',name,' ',tostring(id),'\n') end
 end
end
motor_items:close()
local motor_states=assert(io.open('motor-states.csv','w'))
motor_states:write('t,square,busy,native0,native1,native2,native3,position0,position1,position2,position3,phase0,phase1,phase2,phase3,pattern0,pattern1,pattern2,pattern3\n')
local function observe_motors()
 local values={m.time:as_double(),mem:read_u8(0xc9),mem:read_u8(0x6b)}
 for reel=0,3 do table.insert(values,mem:read_u8(0x168+2*reel)) end
 for _,item in ipairs({'m_step_pos','m_phase','m_pattern'}) do
  for reel=0,3 do local device=m.devices[':reel'..reel];table.insert(values,emu.item(device.items['0/'..item]):read(0)) end
 end
 motor_states:write(table.concat(values,','),'\n')
end
'@
 if($NoMotorItems){$motorLua='local function observe_motors() end'}
 $lua=[IO.File]::ReadAllText("$run/input.lua").Replace('local frame=0',$motorLua+"`nlocal frame=0")
 $lua=$lua.Replace('frame=frame+1',"frame=frame+1`n observe_motors()")
 [IO.File]::WriteAllText("$run/input.lua",$lua)
}
if($Availability){
 $extra+=@(
 'bpset 0x29f4,temp0==1,{printf "AV enter u=%04X s=%04X budget=%04X cycle=%016X\n",u,s,w@u,totalcycles;save availability-ram.bin,0,800;go}',
 'bpset 0x2a2e,temp0==1,{printf "AV exit u=%04X s=%04X result=%04X best=%02X a8=%02X dd=%02X de=%02X symbols=%04X%04X%04X cycle=%016X\n",u,s,w@u,b@0xc8,b@0xa8,b@0xdd,b@0xde,w@0x160,w@0x162,w@0x164,totalcycles;go}')
}
if($NudgeEntry){
 # A physical TAKE pulse at the naturally reached ladder destination; no state edit.
 $lua=[IO.File]::ReadAllText("$run/input.lua")
 $lua=$lua.Replace('local frame=0',"local nudge_take_sent=false`nlocal frame=0")
 $lua=$lua.Replace('local text=display()',"local text=display()`n if not nudge_take_sent and mem:read_u8(0xc9)==22 and text:find('TAKE NUDGE',1,true) then`n  pulse(frame,':BLACK2',1,12,'take_nudge_entry',text)`n  nudge_take_sent=true`n end")
 [IO.File]::WriteAllText("$run/input.lua",$lua)
}
if($NudgeRequest){
 $lua=[IO.File]::ReadAllText("$run/input.lua")
 $lua=$lua.Replace('local frame=0',"local nudge_step_sent=false`nlocal frame=0")
 $lua=$lua.Replace('local text=display()',"local text=display()`n if not nudge_step_sent and mem:read_u8(0xbd)==0x15 and mem:read_u8(0xbe)==3 and text:find('NUDGES',1,true) then`n  pulse(frame,':BLACK2',2,6,'nudge1_request',text)`n  nudge_step_sent=true`n end")
 [IO.File]::WriteAllText("$run/input.lua",$lua)
}
if($NudgeSequence) {
 $lua=[IO.File]::ReadAllText("$run/input.lua").Replace('local frame=0',"local nudge_remaining_sent={}`nlocal frame=0")
 $lua=$lua.Replace('local text=display()',"local text=display()`n local remaining=mem:read_u8(0xbe)`n if mem:read_u8(0xbd)==0x15 and remaining>0 and remaining<3 and not nudge_remaining_sent[remaining] and text:find('NUDGE',1,true) then`n  pulse(frame,':BLACK2',2,6,'nudge1_repeat',text)`n  nudge_remaining_sent[remaining]=true`n end")
 [IO.File]::WriteAllText("$run/input.lua",$lua)
}
if($NudgeStack) {
 $extra+='wpset 0x78b,9,w,temp0==1,{printf "NS pc=%04X address=%04X value=%02X s=%04X y=%04X f4=%04X cycle=%016X\n",pc,wpaddr,wpdata,s,y,w@0xf4,totalcycles;go}'
}
# The terminal observer owns stopping; regular dispatch logging must remain active
# at earlier occurrences of the same site (for example AFC2 for each meter unit).
if($NudgeResult){$end=if($NudgeSpinGates){'0xf38c'}elseif($NudgeSpinFlags){'0xf38a'}elseif($NudgeTone){'0xf384'}elseif($NudgeStake){'0xfc4d'}elseif($NudgeStart){'0xfcdc'}elseif($NudgeEligibility){'0xfcd5'}elseif($NudgePreplay){'0xfc99'}elseif($NudgeServices){'0xfc03'}elseif($NudgeStatus){'0xfbf3'}elseif($NudgeBackground){'0xfbf1'}elseif($NudgeIc8){'0xfdba'}elseif($NudgeCycleInit){'0xfaf0'}elseif($NudgeBankReturn){'0xfe1f'}elseif($NudgeAccounting){'0xaf25'}elseif($NudgeTail){'0xaff0'}elseif($NudgeWinTransfer){'0xafc2'}elseif($NudgeExit){'0xe460'}else{'0xe263'};$extra+=('bpset 0xfc,temp0==1 && y=='+$end+$(if($NudgeWinTransfer -and !$NudgeTail){' && w@0xba==0 && w@0x2fa==0x10'}else{''})+',{printf "'+$format+'",'+$values+$ioPrint+$statusPrint+';save result-ram.bin,0,800;temp0=0;quit}')}
if($TailWindow){$extra+=('bpset 0xfc,temp0==1 && temp3==0 && y=='+$(if($NudgeSpinGates){'0xf38a'}elseif($NudgeSpinFlags){'0xf384'}elseif($NudgeTone){'0xfc4d'}elseif($NudgeStake){'0xfcdc'}elseif($NudgeEligibility){'0xfc99'}elseif($NudgePreplay){'0xfc03'}elseif($NudgeServices){'0xfbf3'}elseif($NudgeStatus){'0xfbf1'}elseif($NudgeBackground){'0xfdba'}elseif($NudgeIc8){'0xfaf0'}elseif($NudgeCycleInit){'0xfe1f'}elseif($NudgeBankReturn){'0xaf25'}elseif($NudgeAccounting){'0xaff0'}else{'0xafc2 && w@0xba==0 && w@0x2fa==0x10'})+',{printf "'+$format+'",'+$values+$ioPrint+$statusPrint+';save tail-entry-ram.bin,0,800;'+$(if($NudgeStake){'save config-window.bin,7190,1a;'}else{''})+'temp3=1;go}')}
if($NudgeIc8){
 # Keep peripheral logging inside the selected window. Earlier failed captures
 # with active pre-window observers are retained externally, never curated.
 $extra=@($extra|ForEach-Object {if($_ -notmatch '"SC '){$_.Replace('temp0==1','temp0==1 && temp3==1')}else{$_}})
}
if($NudgeServices){$extra+='bpset 0x6903,temp3==1,{printf "CH x=%04X call=%02X response=%02X expected=%02X\n",x,b@(x-1),a,b@x;go}'}
if($NudgeStart){
 $lua=[IO.File]::ReadAllText("$run/input.lua").Replace('local frame=0',"local paid_start_sent=false`nlocal frame=0")
 $lua=$lua.Replace('local text=display()',"local text=display()`n if not paid_start_sent and t>=406.6 then`n  pulse(frame,':BLACK2',128,12,'paid_start',text)`n  paid_start_sent=true`n end")
 [IO.File]::WriteAllText("$run/input.lua",$lua)
}
if($NudgeTone){
 foreach($at in @('5a14','5a01','5a05','5a0a','5a10','5a1c')){
  $extra+=('bpset 0x'+$at+',temp3==1,{printf "NT pc=%04X cycle=%016X clock=%04X tick=%04X parameter=%02X choice=%02X rate=%02X\n",pc,totalcycles,w@0x45,w@0x2d,b@0x4d,b@0x4f,b@0x4e;go}')
 }
}
if($extra.Count -gt 0) {
 # Debugger setup invokes paused frame callbacks. Ignore precisely the added
 # setup callbacks in this copied observer, preserving the original physical times.
 $lua=[System.IO.File]::ReadAllText("$run/input.lua")
 $lua=$lua.Replace('local frame=0',"local frame=0`nlocal setup_callbacks_to_skip=$($extra.Count)")
 $lua=$lua.Replace('emu.register_frame_done(function()',"emu.register_frame_done(function()`n if setup_callbacks_to_skip>0 then`n  assert(m.time:as_double()<0.001,'Unexpected running frame during debugger setup')`n  setup_callbacks_to_skip=setup_callbacks_to_skip-1`n  return`n end")
 [System.IO.File]::WriteAllText("$run/input.lua",$lua)
}
$print='printf "'+$format+'",'+$values+$ioPrint+$statusPrint
$stop=if($FullFeature){'0xc767'}else{'0xc71d'}
if($CashFeatureCaller){if(!$FullFeature -or $JackpotProbe){throw 'Caller capture requires FullFeature and excludes synthetic JackpotProbe'};$stop='0xe0bf'}
if($BoardResultCaller){if(!$CashFeatureCaller){throw 'Board result capture requires CashFeatureCaller'};$stop='0xe33c'}
if($BoardSelection){$stop='0xe460'}
if($DiceRequests){$stop='0xb283'}
if($DiceMotion){$stop='0xb28f'}
$dispatchAction="temp0=(y!=$stop);$print;go"
if($BoardMovement){$dispatchAction="temp0=(y!=0xdd38 && y!=0xde96);$print;go"}
if($NudgePotProbe){$dispatchAction="temp0=(y!=0xddef);$print;go"}
if($BoardLink){$dispatchAction="temp0=(y!=0xde81);$print;go"}
if($ContinueBoard){$dispatchAction="temp0=(y!=0xdd38 && y!=0xe2fc);$print;go"}
if($Availability){$dispatchAction="temp0=(y!=0xdd7e && y!=0xdd98);$print;go"}
if($NudgeEntry){$dispatchAction="temp0=(y!=0xb4c5);$print;go"}
if($NudgePrompt){$dispatchAction="temp0=(y!=0xb403);$print;go"}
if($NudgeRequest){$dispatchAction="temp0=(y!=0xb31f);$print;go"}
if($NudgeMotion){$dispatchAction="temp0=(y!=0xb34e);$print;go"}
if($NudgeReturn){$dispatchAction="temp0=(y!=0xb403 || b@0xbe!=2);$print;go"}
if($NudgeSequence){$dispatchAction="temp0=(y!=0xb749);$print;go"}
if($NudgeResult){$dispatchAction="temp0=1;$print;go"}
if($JackpotProbe) {
 if(!$FullFeature){throw 'Jackpot probe requires -FullFeature'}
 # Synthetic helper experiment: enter A365 at the real C721 return boundary.
 # This is not a physically reached jackpot or an award-path reference capture.
 $dispatchAction="temp0=(y!=0xa398);$print;y=y+(y==0xc767)*(0xa365-0xc767);go"
}
$commands=@(
 # Keep the original fixture's one-breakpoint startup command count. Each debugger
 # setup command triggers a paused frame callback in this harness; extra commands
 # change frame-number-based physical input timing. temp0 starts at zero in MAME.
 $(if($BoardSelection -or $DiceRequests -or $DiceMotion -or $BoardMovement -or $BoardLink){"bpset 0xfc,temp0==1$(if($TailWindow){' && temp3==1'})$(if($NudgeResult){(' && y!='+$end+$(if($NudgeWinTransfer -and !$NudgeTail){' || temp0==1 && w@0xba!=0 || temp0==1 && w@0x2fa!=0x10'}else{''}))}),{$dispatchAction}"}elseif($BoardResultCaller){"bpset 0xfc,(y==0xe2fc && w@u==2 && b@0xc9==0x20) || temp0==1,{$dispatchAction}"}elseif($CashFeatureCaller){"bpset 0xfc,(y==0xdff6 && b@0xc9==0x20) || temp0==1,{$dispatchAction}"}else{"bpset 0xfc,y==0xc721 || temp0==1,{$dispatchAction}"})
)+$extra+@(
 $(if($NudgePrompt){'gtime #600000'}else{'gtime #2400000'}),
 'save ram-final.bin,0,800',
 'quit'
)
$commands | Set-Content "$run/debugger.cmd"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,
 '-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",
 '-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",
 '-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none',
 '-window','-skip_gameinfo','-nothrottle','-seconds_to_run',$(if($NudgePrompt){'602'}else{'2402'}),'-autoboot_delay','0','-autoboot_script',"$run/input.lua")
$arguments | ConvertTo-Json | Set-Content "$run/arguments.json"
@{mame_sha256=(Get-FileHash -LiteralPath $MameExecutable).Hash;replay_sha256=(Get-FileHash "$run/replay-actions.csv").Hash;
 native_sound_capture=[bool]$NativeSound;native_nvram_capture=[bool]$NativeNvram;full_feature_capture=[bool]$FullFeature;native_input_capture=[bool]$NativeInput;native_lamp_frames=[bool]$NativeLampFrames;native_alpha_capture=[bool]$NativeAlpha;native_scan_capture=[bool]$NativeScan;shared_timing=[bool]$SharedTiming;paused_setup_callbacks_skipped=$extra.Count;
 timer_deadlines=[bool]$TimerDeadlines;cpu_interrupts=[bool]$CpuInterrupts;synthetic_jackpot_probe=[bool]$JackpotProbe;cash_feature_caller=[bool]$CashFeatureCaller;board_result_caller=[bool]$BoardResultCaller;board_selection=[bool]$BoardSelection;dice_requests=[bool]$DiceRequests;dice_motion=[bool]$DiceMotion;board_movement=[bool]$BoardMovement;synthetic_nudge_pot_probe=[bool]$NudgePotProbe;board_link=$BoardLink;continue_board=[bool]$ContinueBoard;availability=[bool]$Availability;nudge_entry=[bool]$NudgeEntry;nudge_prompt=[bool]$NudgePrompt;nudge_request=[bool]$NudgeRequest;nudge_motion=[bool]$NudgeMotion;nudge_stack=[bool]$NudgeStack;nudge_return=[bool]$NudgeReturn;nudge_sequence=[bool]$NudgeSequence;nudge_result=[bool]$NudgeResult;nudge_exit=[bool]$NudgeExit;nudge_win_transfer=[bool]$NudgeWinTransfer;nudge_tail=[bool]$NudgeTail;nudge_accounting=[bool]$NudgeAccounting;nudge_bank_return=[bool]$NudgeBankReturn;nudge_cycle_init=[bool]$NudgeCycleInit;nudge_ic8=[bool]$NudgeIc8;nudge_background=[bool]$NudgeBackground;nudge_status=[bool]$NudgeStatus;nudge_services=[bool]$NudgeServices;nudge_preplay=[bool]$NudgePreplay;nudge_eligibility=[bool]$NudgeEligibility;nudge_start=[bool]$NudgeStart;nudge_stake=[bool]$NudgeStake;nudge_tone=[bool]$NudgeTone;nudge_spin_flags=[bool]$NudgeSpinFlags;nudge_spin_gates=[bool]$NudgeSpinGates;tail_window=[bool]$TailWindow;motor_items_observer_disabled=[bool]$NoMotorItems;additional_physical_take_at_square22=[bool]$NudgeEntry;
 initial_state=$(if($NudgePotProbe){'Fresh isolated physical campaign; explicit synthetic Y=DDE3 redirection at B28F; no RAM/ROM injection'}elseif($JackpotProbe){'Fresh isolated physical campaign; explicit synthetic jackpot VM-entry redirection; no RAM/ROM injection'}else{'Fresh isolated default configuration and absent NVRAM; physical-input fixture only; no RAM/ROM injection.'})} |
 ConvertTo-Json | Set-Content "$run/provenance.json"
$previousReplay=$env:MPU4_REPLAY
$previousPolicy=$env:MPU4_POLICY
try {
 $env:MPU4_REPLAY="$run/replay-actions.csv"
 $env:MPU4_POLICY='7'
 Push-Location $run
 try { & $MameExecutable @arguments *> "$run/console.txt"; $LASTEXITCODE | Set-Content "$run/exit-code.txt" }
 finally { Pop-Location }
} finally { $env:MPU4_REPLAY=$previousReplay; $env:MPU4_POLICY=$previousPolicy }
if((Get-Content -LiteralPath "$run/exit-code.txt") -ne '0'){throw "MAME exited unsuccessfully; do not curate an incomplete capture: $run"}
if(Select-String -LiteralPath "$run/debug.log" -Pattern '^Error in expression:' -Quiet){throw "Debugger expression error: $run"}
$completion=if($NudgeSpinGates){'^SC y=F38C '}elseif($NudgeSpinFlags){'^SC y=F38A '}elseif($NudgeTone){'^SC y=F384 '}elseif($NudgeStake){'^SC y=FC4D '}elseif($NudgeStart){'^SC y=FCDC '}elseif($NudgeEligibility){'^SC y=FCD5 '}elseif($NudgePreplay){'^SC y=FC99 '}elseif($NudgeServices){'^SC y=FC03 '}elseif($NudgeStatus){'^SC y=FBF3 '}elseif($NudgeBackground){'^SC y=FBF1 '}elseif($NudgeIc8){'^SC y=FDBA '}elseif($NudgeCycleInit){'^SC y=FAF0 '}elseif($NudgeBankReturn){'^SC y=FE1F '}elseif($NudgeAccounting){'^SC y=AF25 '}elseif($NudgeTail){'^SC y=AFF0 '}elseif($NudgeWinTransfer){'^SC y=AFC2 .*pending=0000 win=0010 '}elseif($NudgeExit){'^SC y=E460 '}elseif($NudgeResult){'^SC y=E263 '}elseif($NudgeSequence){'^SC y=B749 '}elseif($NudgeReturn){'^SC y=B403 '}elseif($NudgeMotion){'^SC y=B34E '}elseif($NudgeRequest){'^SC y=B31F '}elseif($NudgePrompt){'^SC y=B403 '}elseif($NudgeEntry){'^SC y=B4C5 '}elseif($Availability){'^SC y=(DD7E|DD98) '}elseif($ContinueBoard){'^SC y=(DD38|E2FC) '}elseif($BoardLink){'^SC y=DE81 '}elseif($NudgePotProbe){'^SC y=DDEF '}elseif($BoardMovement){'^SC y=(DD38|DE96) '}elseif($DiceMotion){'^SC y=B28F '}elseif($DiceRequests){'^SC y=B283 '}else{'^SC y=C71D '}
if(!(Select-String -LiteralPath "$run/debug.log" -Pattern $completion -Quiet)){throw "Requested completion was not captured; inspect $run"}
Get-ChildItem $run -File | Get-FileHash | Select-Object Path,Hash | ConvertTo-Json | Set-Content "$run/hashes.json"
Write-Output $run

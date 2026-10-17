param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory,[switch]$OutputService)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory);if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$commands.Add($(if($OutputService){'bpset 4c34'}else{'bpset 685a'}));$commands.Add('temp0=0');$commands.Add('wpset f02,1,w,temp0==1,{printf "PW id=%X cycle=%016X value=%02X\n",temp1,totalcycles,wpdata;go}')
$body=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Runtime/Mpu4PayoutPulseExecution.cs" -Raw
if($OutputService){$body+=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Runtime/Mpu4PayoutOutputExecution.cs" -Raw}
$start=if($OutputService){0x6858}else{0x68A0}
foreach($pc in ([regex]::Matches($body,'new(?: Step)?\(0x([0-9A-F]{4}),"')|ForEach-Object {[Convert]::ToInt32($_.Groups[1].Value,16)}|Sort-Object -Unique|Where-Object {$_ -ne $start})) {
 $action=if($pc -eq 0x717C){'temp2=temp2+1;b@6e=(b@6e+(temp2&1))&0xff;'}else{''}
 $commands.Add(('bpset {0:X},1,{{{1}printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc,$action))
}
$specs=if($OutputService){@(@(0,0,0,0),@(1,0,0,0),@(0,1,0,0),@(0,0,1,0),@(0,0,0,1),@(1,1,1,1),@(2,0,1,0),@(0,2,0,1))}else{@(@(1,0),@(1,250),@(2,0),@(2,250),@(4,0),@(4,250),@(8,0),@(8,250))}
foreach($spec in $specs) {
 $id=$cases.Count;$mask=if($OutputService){0}else{$spec[0]};$counter=if($OutputService){250}else{$spec[1]};$port=if($counter -eq 0){0x30}else{0xA5};$cases.Add([ordered]@{id=$id;mask=$mask;counter=$counter;port=$port;queues=$(if($OutputService){$spec}else{$null})})
 $commands.Add(('temp0=0;temp1=0x{0:X};temp2=0;pc=0x{4:X};cc=0x50;dp=0;s=0x700;b@700=0x{1:X};b@701=0;w@702=0;b@6e=0x{2:X};b@f03=0x30;b@f02=0xff;b@f03=0x34;b@f02=0x{3:X}' -f $id,$mask,$counter,$port,$start))
 if($OutputService){
  $commands.Add('w@700=0x4c34;b@2b=0x20;b@323=0;b@2c=0x7a;b@373=0;b@84=0;b@7d=0;w@3d6=0x3d0;w@3d8=0x3d4;b@3da=0;b@3db=0xa5')
  if($id -eq 7){$commands.Add('b@3da=0x1f;w@3d8=0x3d3')}
  for($i=0;$i -lt 4;$i++){$commands.Add(('b@{0:X}=0x{1:X};b@{2:X}=0x{3:X}' -f (0x36B+2*$i),$spec[$i],(0x36C+2*$i),$i))}
  $commands.Add(('save output-{0}-before.bin,0,800' -f $id))
 }
 $commands.Add('printf "PS id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)');$commands.Add('temp0=1');$commands.Add('go');$commands.Add('temp0=0')
 $commands.Add('printf "PF id=%X pc=%04X cycle=%016X counter=%02X port=%02X s=%04X polls=%04X\n",temp1,pc,totalcycles,b@6e,b@f02,s,temp2')
 if($OutputService){$commands.Add(('save output-{0}-after.bin,0,800' -f $id))}
}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{output_service=[bool]$OutputService;classification='Synthetic original-ROM pulse suffix or6858 output service. Masked IRQ; counter6E increments before every odd717C compare; even compares retain it. No skipped waits, ROM patch or captured acceptance input. Poll policy is synthetic, not natural IRQ timing.';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
Push-Location $run;try{& $MameExecutable @arguments *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location}
if($code -ne 0){throw 'Invalid pulse capture'};Write-Output $run

param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$SeedRam,[Parameter(Mandatory=$true)][string]$RunDirectory,[switch]$Collection,[switch]$InstructionTiming,[switch]$VmBridge)
if($VmBridge){$InstructionTiming=$true}
if($Collection -and $InstructionTiming){throw 'Caller timing is isolated native entry, not router mode'}
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory)
if(Test-Path -LiteralPath $run){throw 'Use a fresh directory'}
New-Item -ItemType Directory -Path $run|Out-Null
foreach($name in @('cfg','nvram','state','snap','diff','comments')){New-Item -ItemType Directory (Join-Path $run $name)|Out-Null}
Copy-Item -LiteralPath $SeedRam -Destination "$run/seed.bin"
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$id=0
$commands.Add('bpset 0x4c34');$commands.Add('temp0=0');$commands.Add('wpset 0xf02,1,w,temp0==1,{printf "PO id=%02X value=%02X\n",temp1,wpdata;go}')
if(!$InstructionTiming){$commands.Add('bpset 0x7172,temp0==1,{pc=0x7199;go}');$commands.Add('bpset 0x4cbe,temp0==1,{printf "PD id=%02X record=%04X balance=%04X\n",temp1,y,w@(w@(y+5));go}')}
else{
 $commands.Add('temp2=0');$commands.Add('temp3=0');$commands.Add('bpset 717c,temp0==1,{temp3=temp3+1;b@6e=(b@6e+(temp3&1))&0xff;go}')
 $commands.Add('bpset 4cbe,temp0==1,{printf "PD id=%02X record=%04X balance=%04X\n",temp1,y,w@(w@(y+5));printf "CS id=%02X cycle=%016X y=%04X s=%04X cc=%02X\n",temp1,totalcycles,y,s,cc;temp2=1;go}')
 $commands.Add('bpset fc,temp0==1&&temp2==1,{printf "CV id=%02X cycle=%016X y=%04X token=%04X\n",temp1,totalcycles,y,w@y;go}')
 foreach($pc in @(0x4C23,0x4C8A,0x4D07,0x4D4D,0x4D42)){$commands.Add(('bpset {0:X},temp0==1,{{printf "CR id=%02X cycle=%016X pc=%04X\n",temp1,totalcycles,pc;temp2=0;printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
 $pcs=[Collections.Generic.HashSet[int]]::new()
 foreach($entry in @('67e2','67ec','4b39','4b8c','4c25','4c91','4cf8','6f57')){$f=Get-Content "$PSScriptRoot/../evidence/mpu4/native/$entry.json" -Raw|ConvertFrom-Json;foreach($match in [regex]::Matches($f.assembly,'(?m)^([0-9a-f]{4}) ')){[void]$pcs.Add([Convert]::ToInt32($match.Groups[1].Value,16))}};[void]$pcs.Add(0x6F51)
 foreach($match in [regex]::Matches((Get-Content "$PSScriptRoot/../src/FruitMachineLab.Runtime/Mpu4QueueChecksumPlan.cs" -Raw),'new NativeRoutineStep\(0x([0-9A-F]{4}),"')){[void]$pcs.Add([Convert]::ToInt32($match.Groups[1].Value,16))}
 if($VmBridge){foreach($pc in @(0xFE,0x776F,0x7771,0x7773,0x7775,0x7777,0x777A,0x777C,0x777E,0x7780,0x7782,0x7784,0x7786,0x7788,0x778B)){[void]$pcs.Add($pc)};$commands.Add('bpset fc,temp0==1&&temp2==0&&y==0x112')}
 $excluded=if($VmBridge){@(0x4C23,0x4C8A,0x4D07,0x4D4D,0x4D42)}else{@(0x4B39,0x4B8C,0x4C23,0x4C8A,0x4D07,0x4D4D,0x4D42)}
 foreach($pc in ($pcs|Sort-Object|Where-Object {$_ -notin $excluded})){$commands.Add(('bpset {0:X},temp0==1&&temp2==0,{{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
}
foreach($entry in @(0x4B39,0x4B8C)){foreach($scottish in @(0,4)){foreach($levels in @(0,15)){foreach($small in @($true,$false)){
 $name="service-$id";$amount=if($small){2}elseif($entry -eq 0x4B39){24}else{6};$cases.Add([ordered]@{id=$id;name=$name;entry=$entry;scottish=$scottish;levels=$levels;amount=$amount})
 $pointer=if($entry -eq 0x4B39){0x2FE}else{0x300}; $prepare=@(); if($Collection){ $cases[$cases.Count-1].entry=0xAA2B; $prepare=@('w@0x2fc=0','w@0x2fe=0','w@0x300=0','w@0x302=0'); $bank=if($levels -eq 15){$pointer}elseif($entry -eq 0x4B39){0x2FC}else{0x302}; $amount=if(!$small -and $entry -eq 0x4B8C){20}elseif(!$small -and $scottish -eq 4){20}else{$amount};$cases[$cases.Count-1].amount=$amount; $prepare+=('w@0x'+$bank.ToString('X4')+'=0x'+$amount.ToString('X4')) }
 foreach($command in @('temp0=0','load seed.bin,0','s=0x790','u=0x600','dp=0','cc=0x50','w@0x790=0x4c34','b@0x323=0','w@0xa0=0','b@0x55=0x1f','b@0x57=0','b@0x54=0','b@0xc5=0','w@0x2fe=0','w@0x300=0',('w@0x'+$pointer.ToString('X4')+'=0x'+$amount.ToString('X4')),('b@0=0x'+$levels.ToString('X2')),'b@1=0','b@2=0','b@3=0',('b@6=0x'+$scottish.ToString('X2')),'b@7=0','b@0x3a=0x80','w@0x36b=0','w@0x36d=0','w@0x36f=0','w@0x371=0','w@0x7d2=0x8000','b@0x7d4=0','b@0xf03=0x30','b@0xf02=0xff','b@0xf03=0x34','b@0xf02=0x30',$(if($Collection){$prepare}),"save $name-before.bin,0,800",('temp1=0x'+$id.ToString('X2')),'temp0=1',$(if($Collection){'x=0xaa2b';'pc=0x76bf'}else{'pc=0x'+$entry.ToString('X4')}),'g','temp0=0',"save $name-after.bin,0,800",('printf "PF id=%02X pc=%04X u=%04X\n",temp1,pc,u'))) {foreach($piece in @($command)){$commands.Add([string]$piece)}}
 if($InstructionTiming){$go=$commands.Count-4;if($commands[$go] -ne 'g'){throw 'Unexpected service command layout'}
  if($VmBridge){$token=if($entry -eq 0x4B39){0x80E4}else{0x80F4};$flag=if($small){0}else{8};$cases[$cases.Count-1]['vm_flag']=$flag;$commands.Insert($go,('pc=0xfc;y=0x110;w@110=0x{0:X};w@112=0x80e8;b@f1=0x{1:X};w@f8=0x3420;w@fa=0x3184;w@fc=0xaea1;w@fe=0x6e91' -f $token,$flag));$go++;$commands.Insert($go,"save $name-before.bin,0,800");$go++}
  $commands.Insert($go,'temp2=0;temp3=0');$commands.Insert($go+1,'printf "CB id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)');$commands.Insert($commands.Count,'printf "CE id=%02X pc=%04X cycle=%016X s=%04X polls=%04X\n",temp1,pc,totalcycles,s,temp3')}
 $id++
}}}}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json -Depth 4|Set-Content "$run/cases.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-state_directory',"$run/state",'-snapshot_directory',"$run/snap",'-diff_directory',"$run/diff",'-comment_directory',"$run/comments",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
[ordered]@{collection=[bool]$Collection;instruction_timing=[bool]$InstructionTiming;vm_bridge=[bool]$VmBridge;classification=$(if($InstructionTiming){'Synthetic original-ROM caller/debit/display/output; masked IRQ; real7172 polling with counter incremented on odd717C compares. No skipped waits. Not natural IRQ timing or delivery.'}else{'Synthetic original-ROM4B39/4B8C service. IRQ masked, debugger skips7172 calls via native7199 RTS. Not natural timing.'});mame_sha256=(Get-FileHash $MameExecutable).Hash;seed_sha256=(Get-FileHash "$run/seed.bin").Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
Push-Location $run
try{& $MameExecutable @arguments *> "$run/console.txt";$LASTEXITCODE|Set-Content "$run/exit-code.txt"}finally{Pop-Location}
if($LASTEXITCODE -ne 0){throw 'MAME payout service matrix failed'}
Write-Output $run

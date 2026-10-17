param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory)
if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$commands.Add('bpset 0x46d3')
$addresses=@(0x438E,0x4390,0x4392,0x439F,0x43A2,0x43A4,0x43A8,0x43AB,0x43AD,0x43AE,0x43AF,0x43B0,0x43B2,0x43B4,0x43B6,0x43BA,0x43BC,0x43BD,0x43BF,0x43C1,0x43C3,0x43C4,0x43C6,0x43C8,0x43CB,0x43CD,0x43CF,0x43D1,0x43D3,0x43D5,0x43D7,0x43D9,0x43DB,0x43DD,0x43DF,0x43E1)
foreach($pc in $addresses){$commands.Add(('bpset {0:X},1,{{printf "CI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
foreach($id in 0..63){
 $column=if($id -band 1){4}else{0};$port5=($id*37) -band 255;$port2=if($id -band 2){16}else{0};$aux=($id*53) -band 255;$prior=($id*13) -band 255;$sticky=($id*71) -band 255
 $cases.Add([ordered]@{id=$id;column=$column;port5=$port5;port2=$port2;aux=$aux;prior=$prior;sticky=$sticky})
 $commands.Add(('temp1=0x{0:X};pc=0x438c;cc=0x50;dp=0;s=0x700;w@28=0x{1:X};b@0x0=0;b@0x1=0;b@0x2=0x{2:X};b@0x3=0;b@0x4=0;b@0x5=0x{3:X};b@89=0x{4:X};b@2a=0x{5:X};b@c03=0;b@c02=0xff;b@c03=4;b@c02=0x{6:X}' -f $id,$column,$port2,$port5,$prior,$sticky,$aux))
 $commands.Add('printf "CS id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)');$commands.Add('go')
 $commands.Add('printf "CF id=%X cycle=%016X pc=%04X s=%04X prior=%02X sticky=%02X a=%02X b=%02X y=%04X\n",temp1,totalcycles,pc,s,b@89,b@2a,a,b,y')
}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{classification='Synthetic438C->439F decode prefix only, stops before46D3 executes. Original ROM/table, masked IRQ/FIRQ, injected RAM and PIA output-mode auxiliary read, not coin insertion gameplay';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
Push-Location $run;try{& $MameExecutable @arguments *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location}
if($code -ne 0 -or (Select-String "$run/debug.log" -Pattern '^Error ' -Quiet)){throw 'Invalid coin-prefix experiment'}
Write-Output $run

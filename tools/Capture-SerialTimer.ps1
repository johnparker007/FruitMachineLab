param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory);if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null;foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$cmd=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$cmd.Add('bpset 4c34');foreach($at in @('70cb','70d8')){$cmd.Add(('bpset {0},1,{{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $at))}
$body=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Adders/AddersSerialTimerPlan.cs" -Raw
foreach($pc in ([regex]::Matches($body,'new NativeRoutineStep\(0x([0-9A-F]{4}),"')|ForEach-Object {[Convert]::ToInt32($_.Groups[1].Value,16)}|Sort-Object -Unique)){$cmd.Add(('bpset {0:X},1,{{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
foreach($entry in @(0x70C9,0x70D6)){foreach($period in @(0,1,0x1234,0xFFFF)){foreach($cc in @(0,0x50)){
$id=$cases.Count;$cases.Add([ordered]@{id=$id;entry=$entry;period=$period;cc=$cc;end=0x4C34;stack=0x702})
$cmd.Add(('pc=0x{0:X};a=0x89;b=0xab;x=0x69c0;y=0x{1:X};u=0x600;s=0x700;dp=0;cc=0x{2:X};w@700=0x4c34;w@3b=0;b@3f=0;b@901=0' -f $entry,$period,$cc))
$cmd.Add("save operation-$id-before.bin,0,800");$cmd.Add('printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@901,b@904');$cmd.Add('go');$cmd.Add('printf "OF pc=%04X cycle=%016X s=%04X b=%02X cc=%02X\n",pc,totalcycles,s,b,cc');$cmd.Add("save operation-$id-after.bin,0,800")
}}}
$cmd.Add('quit');$cmd|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{stem='serial-timer';count=16;regions=@(,@(0x70C9,0x70EE));classification='Synthetic original timer2 reset/arm, explicit native context; no IRQ acceptance claim';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json -Depth 5|Set-Content "$run/provenance.json"
$args=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30')
$args|ConvertTo-Json|Set-Content "$run/arguments.json";Push-Location $run;try{& $MameExecutable @args *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location};if($code -ne 0){throw 'Invalid transport capture'};Write-Output $run

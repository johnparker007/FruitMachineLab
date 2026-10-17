param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory);if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null;foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$cmd=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$cmd.Add('bpset 5d3b')
$body=Get-Content "$PSScriptRoot/../src/FruitMachineLab.Adders/AddersSoundChildPlan.cs" -Raw
foreach($pc in ([regex]::Matches($body,'new NativeRoutineStep\(0x([0-9A-F]{4}),"')|ForEach-Object {[Convert]::ToInt32($_.Groups[1].Value,16)}|Sort-Object -Unique)){$cmd.Add(('bpset {0:X},1,{{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
foreach($free in @(0,0x1C5)){foreach($pattern in @(0,1,128,255)){foreach($clock in @(0,1,0xFFFE,0xFFFF)){
$id=$cases.Count;$cases.Add([ordered]@{id=$id;free=$free;pattern=$pattern;clock=$clock})
$cmd.Add(('pc=0x5ee3;y=0x1a0;u=0x8787;s=0x700;dp=0;cc=0x50;w@45=0x{0:X};w@49=0x{1:X};w@47=0x1ea;w@1ea=0;w@1c5=0x20f;b@719b=0x80' -f $clock,$free))
foreach($offset in @(0xB,0xC,0xD,0xE,0x10,0x12)){$cmd.Add(('b@{0:X}=0x{1:X}' -f (0x1A0+$offset),(($pattern+$offset)-band 255)))}
$cmd.Add('b@1d4=0x55;b@1d6=0xaa;w@1cb=0xdead;b@1cf=0x66')
$cmd.Add("save operation-$id-before.bin,0,800");$cmd.Add('printf "OS pc=%04X cycle=%016X\n",pc,totalcycles');$cmd.Add('go');$cmd.Add('printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s');$cmd.Add("save operation-$id-after.bin,0,800")
}}}
$cmd.Add('quit');$cmd|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{classification='32 synthetic original C2 child allocations, explicit free pool and inherited fields; not natural sound playback.';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
$args=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30')
$args|ConvertTo-Json|Set-Content "$run/arguments.json";Push-Location $run;try{& $MameExecutable @args *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location};if($code -ne 0){throw 'Invalid operation capture'};Write-Output $run


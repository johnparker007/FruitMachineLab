param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$SeedRam,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory)
if(Test-Path $run){throw 'Use a fresh directory'}
New-Item -ItemType Directory $run|Out-Null
foreach($name in @('cfg','nvram','state','snap','diff','comments')){New-Item -ItemType Directory (Join-Path $run $name)|Out-Null}
Copy-Item $SeedRam "$run/seed.bin"
$commands=[Collections.Generic.List[string]]::new();$cases=@();$commands.Add('bpset 0x7000');$number=0
foreach($mask in 0..7){foreach($seed in @(0,65535,6040)){foreach($irq in @(0,255)){
 $id='request-'+$number;$number++;$cases+=@([ordered]@{id=$id;mask=($mask*8);seed=$seed;irq=$irq})
 foreach($command in @('load seed.bin,0','s=0x790','cc=0x50','dp=0','w@0x790=0x7000',('w@0x324=#'+$seed),('b@0x33=#'+$irq),('b@0x86=#'+($mask*8)),'b@0x169=0xaa','b@0x16b=0xaa','b@0x16d=0xaa',"save $id-before.bin,0,800",'pc=0x2bbc','g',('printf "DONE '+$id+'\n"'),"save $id-after.bin,0,800")){$commands.Add($command)}
}}}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-state_directory',"$run/state",'-snapshot_directory',"$run/snap",'-diff_directory',"$run/diff",'-comment_directory',"$run/comments",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
[ordered]@{classification='Synthetic native2BBC: all eight hold masks, three PRNG seeds, two IRQ bytes; IRQs masked; not a naturally reached spin';mame_sha256=(Get-FileHash $MameExecutable).Hash;seed_sha256=(Get-FileHash "$run/seed.bin").Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
Push-Location $run
try{& $MameExecutable @arguments *> "$run/console.txt";$LASTEXITCODE|Set-Content "$run/exit-code.txt"}finally{Pop-Location}
if($LASTEXITCODE -ne 0){throw 'MAME matrix failed'}
Write-Output $run

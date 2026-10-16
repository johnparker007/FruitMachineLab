param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory)
if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
Copy-Item "$PSScriptRoot/../evidence/mpu4/skill-cash/ptm-lifecycle.lua" "$run/lifecycle.lua"
@('gtime #40000','quit')|Set-Content "$run/debugger.cmd"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-autoboot_delay','0','-autoboot_script',"$run/lifecycle.lua")
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
Push-Location $run;try{& $MameExecutable @arguments *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location}
if($code -ne 0 -or (Select-String "$run/lifecycle.csv" -Pattern '^ERROR ' -Quiet)){throw 'Invalid lifecycle capture'}
$rows=@(Import-Csv "$run/lifecycle.csv")
if(@($rows|Where-Object {$_.event -eq 'after' -and $_.address -eq '710F'}).Count -ne 20){throw 'Incomplete20-arm lifecycle capture'}
[ordered]@{classification='Natural cold/default attract sequence, absent NVRAM, no physical inputs or state injection. Read-only writes sample BEFORE access; reads sample AFTER with returned data; selected following opcode fetches sample AFTER prior instruction. Not canonical Skill Cash.';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
Write-Output $run

param(
 [Parameter(Mandatory=$true)][string]$MameExecutable,
 [Parameter(Mandatory=$true)][string]$RomDirectory,
 [Parameter(Mandatory=$true)][string]$RunDirectory,
 [switch]$NudgeCheckpoint,
 [switch]$AccountingCheckpoint
)
$ErrorActionPreference='Stop'
$run=[System.IO.Path]::GetFullPath($RunDirectory)
if(Test-Path -LiteralPath $run){throw 'Use a fresh output directory'}
New-Item -ItemType Directory -Path $run | Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory (Join-Path $run $name) | Out-Null}
$commands=@('dasm sound-native.txt,5c18,495,1','dasm lamp-native.txt,497f,126,1',
 'dasm vm-bridges.txt,776f,8c,1','dasm alpha-native-a.txt,3cc0,29c,1',
 'dasm alpha-native-b.txt,3f74,102,1','dasm timer-native.txt,707e,92,1','symlist')
if($NudgeCheckpoint){$commands+=@('dasm nudge-motor-native.txt,61f6,485,1','dasm nudge-result-native.txt,1aa3,100,1','dasm nudge-decrement-native.txt,765b,4,1','dasm nudge-stack-bridge.txt,77a8,19,1','dasm nudge-stack-save.txt,4a8c,19,1','dasm nudge-loop-leave.txt,7a17,5,1','dasm nudge-loop-cleanup.txt,7a0d,8,1','dasm nudge-plan-native.txt,2a2f,50,1','dasm nudge-outer-index.txt,7a28,9,1')}
if($AccountingCheckpoint){$commands+=@('dasm accounting-native.txt,1622,79,1','dasm accounting-counter.txt,151f,54,1','dasm accounting-add24.txt,57a9,57,1','dasm accounting-gateway.txt,77aa,17,1','dasm accounting-refresh.txt,6f57,22,1','dasm accounting-sign.txt,75ab,12,1','dasm accounting-stack-entry.txt,7b35,8,1','dasm accounting-serial-idle.txt,5429,6,1','dasm accounting-serial-return.txt,53ad,1,1','dasm accounting-pia-init.txt,67b7,18,1','dasm accounting-noop.txt,4c34,1,1','dasm accounting-status.txt,482f,8a,1','dasm accounting-door.txt,6ef7,3a,1','dasm accounting-nvram-gate.txt,6e99,5e,1','dasm accounting-test-gate.txt,2e53,c,1','dasm accounting-characteriser.txt,68f1,26,1','dasm accounting-input-flags.txt,67e2,76,1','dasm preplay-reel-lamps.txt,2c71,61,1','dasm preplay-rotate.txt,7ac5,16,1','dasm stake-decay.txt,3af8,22,1','dasm stake-subtract.txt,14eb,34,1','dasm stake-target.txt,4d8f,11c,1','dasm stake-lamps.txt,171d,9,1','dasm stake-groups.txt,2c5e,55,1','dasm stake-increment.txt,57db,e,1','dasm stake-double-negate.txt,7cb5,18,1','dasm stake-double-compare.txt,7c8e,19,1','dasm tone-native.txt,59d9,45,1','dasm tone-delay.txt,7159,41,1','dasm tone-cancel.txt,5c7a,1d,1','dasm tone-find.txt,5cb5,16,1','dasm spin-requests.txt,2bbc,2f,1','dasm paid-spin-entry.txt,61d5,21,1','dasm paid-spin-directions.txt,2cd0,45,1','dasm paid-spin-mask.txt,1421,32,1','dasm parameter-profile.txt,169b,82,1')}
$commands+=@('quit');$commands | Set-Content "$run/debugger.cmd"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",
 '-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",
 '-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','2')
$arguments | ConvertTo-Json | Set-Content "$run/arguments.json"
Push-Location $run
try { & $MameExecutable @arguments *> console.txt; if($LASTEXITCODE -ne 0){throw "MAME failed: $LASTEXITCODE"} }
finally { Pop-Location }
foreach($name in @('sound-native.txt','lamp-native.txt','vm-bridges.txt','alpha-native-a.txt','alpha-native-b.txt')){if(!(Test-Path "$run/$name")){throw "Missing disassembly: $name"}}
Get-ChildItem $run -File | Get-FileHash | Select-Object Path,Hash | ConvertTo-Json | Set-Content "$run/hashes.json"
Write-Output $run

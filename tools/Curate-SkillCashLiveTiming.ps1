param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash'
$proof=Get-Content (Join-Path $target 'shared-timing-verification.json') -Raw | ConvertFrom-Json
$log=Join-Path $RunDirectory 'debug.log'
if((Get-FileHash $log).Hash -ne $proof.raw_debug_sha256){throw 'Use the hash-verified shared timing capture'}
$sites=@{};$tokens=@{};$previous=$null
foreach($line in [IO.File]::ReadLines($log)) {
 if($line -notmatch '^SC y=([0-9A-F]{4}) token=([0-9A-F]{4}).* cycle=([0-9A-F]{16})'){continue}
 $point=@{site=$Matches[1];token=$Matches[2];cycle=[Convert]::ToUInt64($Matches[3],16)}
 if($null -ne $previous){$delta=$point.cycle-$previous.cycle;if($delta -gt 0){
  foreach($pair in @(@($sites,$previous.site),@($tokens,$previous.token))){$table=$pair[0];$key=$pair[1];if(!$table.ContainsKey($key) -or $delta -lt $table[$key]){$table[$key]=$delta}}
 }}
 $previous=$point
}
$orderedSites=[ordered]@{};foreach($key in ($sites.Keys | Sort-Object)){$orderedSites[$key]=$sites[$key]}
$orderedTokens=[ordered]@{};foreach($key in ($tokens.Keys | Sort-Object)){$orderedTokens[$key]=$tokens[$key]}
[ordered]@{classification='Captured CPU translation pacing boundary: minimum observed dispatch-to-dispatch duration by site, with token fallback. Not a CPU cycle emulator; IRQ overlap and native waits remain qualified';raw_debug_sha256=$proof.raw_debug_sha256;sites=$orderedSites;tokens=$orderedTokens} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $target 'live-cpu-timing.json')

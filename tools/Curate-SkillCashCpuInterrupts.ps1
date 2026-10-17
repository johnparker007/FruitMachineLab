param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$target=Join-Path $root 'evidence/mpu4/skill-cash'
$original=Get-Content (Join-Path $target 'hashes.json') -Raw | ConvertFrom-Json
$comparisons=[ordered]@{}
foreach($name in @('state.csv','feature-state.csv','input-levels.csv','ram-final.bin')) {
 $actual=(Get-FileHash (Join-Path $RunDirectory $name)).Hash
 if($actual -ne ($original | Where-Object {[IO.Path]::GetFileName($_.Path) -eq $name}).Hash){throw "IRQ capture differs in $name"};$comparisons[$name]=$actual
}
$stack=[Collections.Generic.Stack[object]]::new();$intervals=[Collections.Generic.List[object]]::new();$first=$null;$last=0UL;$entries=0;$maximumDepth=0
$sites=@{};$tokens=@{};$previous=$null;$busy=0UL;$outer=$null
$timer1=[Collections.Generic.List[ulong]]::new();$latestEntry=$null
foreach($line in [IO.File]::ReadLines((Join-Path $RunDirectory 'debug.log'))) {
 if($line -notmatch '^(SC|IE|IX|MS) '){continue};$kind=$Matches[1];$fields=@{}
 if($kind -eq 'MS'){if($line -notmatch 'cycle=([0-9A-F]+)'){throw 'Missing scan cycle'};$scanCycle=[Convert]::ToUInt64($Matches[1],16);if($null -eq $first -or $null -eq $latestEntry -or ($scanCycle-$latestEntry) -notin @(65,112)){throw 'Uncovered timer1 dispatch-to-scan path'};$timer1.Add($latestEntry-$first);continue}
 foreach($match in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$fields[$match.Groups[1].Value]=[Convert]::ToUInt64($match.Groups[2].Value,16)}
 if($null -eq $first){$first=$fields.cycle};$last=$fields.cycle
 if($kind -eq 'SC') {
  if($null -ne $previous){$delta=$fields.cycle-$previous.cycle; $cost=$delta-($busy-$previous.busy)
   if($cost -gt 0){foreach($pair in @(@($sites,([int]$previous.y).ToString('X4')),@($tokens,([int]$previous.token).ToString('X4')))){
    if(!$pair[0].ContainsKey($pair[1]) -or $cost -lt $pair[0][$pair[1]]){$pair[0][$pair[1]]=$cost}
   }}
  };$previous=@{cycle=$fields.cycle;y=$fields.y;token=$fields.token;busy=$busy};continue
 }
 if($kind -eq 'IE') {
  $latestEntry=$fields.cycle
  if($stack.Count -eq 0){$outer=$fields.cycle};$stack.Push($fields);$entries++;$maximumDepth=[Math]::Max($maximumDepth,$stack.Count)
 }else{
  if($stack.Count -eq 0){throw 'Unmatched IRQ return'};$entry=$stack.Pop()
  if($entry.s -ne $fields.s -or $entry.resume -ne $fields.resume){throw 'IRQ stack/return address differs'}
  if($stack.Count -eq 0){$intervals.Add([ulong[]]@(($outer-$first),($fields.cycle-$outer)));$busy+=$fields.cycle-$outer;$outer=$null}
 }
}
if($stack.Count -ne 0 -or $entries -lt 12000 -or $intervals.Count -eq 0 -or $timer1.Count -ne 6103){throw 'Incomplete IRQ interval capture'}
$orderedSites=[ordered]@{};foreach($key in ($sites.Keys | Sort-Object)){$orderedSites[$key]=$sites[$key]}
$orderedTokens=[ordered]@{};foreach($key in ($tokens.Keys | Sort-Object)){$orderedTokens[$key]=$tokens[$key]}
[ordered]@{classification='Trace-backed IRQ entry to RTI instruction boundaries, outer interval union. Excludes CPU acceptance/stacking and RTI instruction duration. timer1_handler_entries preserves6103 FE70 entries, including nested timer1 services lost by union; observed dispatch65 or112 cycles includes optional ignored SWI2.';initial_cycle=$first;entries=$entries;maximum_depth=$maximumDepth;busy_cycles=$busy;duration_cycles=($last-$first);intervals=@($intervals.ToArray());sites=$orderedSites;tokens=$orderedTokens;timer1_handler_entries=@($timer1.ToArray())} | ConvertTo-Json -Depth 6 -Compress | Set-Content (Join-Path $target 'cpu-interrupts.json')
[ordered]@{run_directory=$RunDirectory;raw_debug_sha256=(Get-FileHash (Join-Path $RunDirectory 'debug.log')).Hash;comparisons=$comparisons} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $target 'cpu-interrupts-verification.json')

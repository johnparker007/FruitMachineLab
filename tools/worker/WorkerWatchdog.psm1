Set-StrictMode -Version 2

# Pure policy: percentages, CPU usage and a rewritten timestamp cannot grant
# unlimited time. A semantic milestone and a command each have independent bounds.
function Get-WorkerWatchdogDecision {
    param([datetime]$Now,[datetime]$Started,[datetime]$LastActivity,
        [datetime]$LastMilestone,[datetime]$HardDeadline,
        [int]$SoftSeconds,[int]$IdleSeconds,[int]$MilestoneSeconds,
        $CommandStarted=$null,[int]$CommandSeconds=1200)
    if($Now -ge $HardDeadline){return 'hard-deadline'}
    if($CommandStarted -and ($Now-[datetime]$CommandStarted).TotalSeconds -ge $CommandSeconds){return 'command-deadline'}
    # A declared quiet command gets a bounded lease, never an unlimited exemption.
    if(!$CommandStarted){
        if(($Now-$LastActivity).TotalSeconds -ge $IdleSeconds){return 'stalled-no-activity'}
        if(($Now-$LastMilestone).TotalSeconds -ge $MilestoneSeconds){return 'stalled-no-milestone'}
    }
    if(($Now-$Started).TotalSeconds -ge $SoftSeconds){return 'running-extended'}
    return 'running'
}

function Read-WorkerProgress {
    param([string]$Path,[string]$TaskId,[datetime]$Started)
    if(!(Test-Path -LiteralPath $Path)){return $null}
    $file=Get-Item -LiteralPath $Path
    if($file.Length -gt 32768){throw 'Progress file exceeds 32 KB'}
    $p=Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json -ErrorAction Stop
    if($p.taskId -ne $TaskId){throw 'Progress task identity differs'}
    if([string]::IsNullOrWhiteSpace($p.phase) -or [string]::IsNullOrWhiteSpace($p.nextStep)){throw 'Progress needs phase and nextStep'}
    if($p.phase.Length -gt 160 -or $p.nextStep.Length -gt 600){throw 'Progress text exceeds bounds'}
    if($p.PSObject.Properties['percent'] -and $null -ne $p.percent -and ($p.percent -lt 0 -or $p.percent -gt 100)){throw 'Invalid progress percentage'}
    # Local receipt time, not a worker-supplied clock, drives policy.
    if($file.LastWriteTimeUtc -lt $Started){throw 'Stale progress file'}
    $command=$null
    if($p.PSObject.Properties['activeCommand'] -and $p.activeCommand){
        $c=$p.activeCommand
        if([string]::IsNullOrWhiteSpace($c.id)){throw 'Active command needs stable id'}
        if([string]::IsNullOrWhiteSpace($c.description)){throw 'Active command needs description'}
        $command=[pscustomobject]@{id=[string]$c.id;description=([string]$c.description).Substring(0,[Math]::Min(240,([string]$c.description).Length))}
    }
    $completed=@($p.completed)
    if($completed.Count -gt 100){throw 'Too many completed milestones'}
    $signature=([ordered]@{phase=$p.phase;completed=$completed}|ConvertTo-Json -Compress -Depth 4)
    return [pscustomobject]@{phase=[string]$p.phase;nextStep=[string]$p.nextStep;percent=if($p.PSObject.Properties['percent']){$p.percent}else{$null};signature=$signature;command=$command;received=$file.LastWriteTimeUtc}
}
Export-ModuleMember -Function Get-WorkerWatchdogDecision,Read-WorkerProgress

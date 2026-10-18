param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$TaskId,
    # TimeoutSeconds is now a soft planning budget, not a kill timer.
    [ValidateRange(30,86400)][int]$TimeoutSeconds = 1200,
    [ValidateRange(30,86400)][int]$HardTimeoutSeconds = 10800,
    [ValidateRange(5,7200)][int]$IdleTimeoutSeconds = 900,
    [ValidateRange(5,14400)][int]$MilestoneTimeoutSeconds = 1800,
    [ValidateRange(5,14400)][int]$CommandTimeoutSeconds = 1800
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DeepSeekWorker.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'WorkerWatchdog.psm1') -Force
if($HardTimeoutSeconds -lt $TimeoutSeconds){throw 'Hard timeout must be at least the soft budget'}

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$task = Join-Path $root "tasks/deepseek/$TaskId.md"
if (!(Test-Path -LiteralPath $task)) { throw "Missing task: $TaskId" }
$run = Join-Path $root "artifacts/deepseek/$TaskId"
if (Test-Path -LiteralPath $run) { throw 'Existing run: supervisor must inspect it; no automatic retry.' }
New-Item -ItemType Directory -Path $run | Out-Null
$lockPath = Join-Path $root 'artifacts/deepseek/worker.lock'

$statePath = Join-Path $run 'state.json'
$eventsPath = Join-Path $run 'events.jsonl'
$stderrPath = Join-Path $run 'stderr.txt'
$reportPath = Join-Path $run 'worker-report.md'

$lock = $null
$process = $null
$stdoutWriter = $null
$stderrWriter = $null
$state = $null
$timedOut = $false
$stopReason = $null
$lastActivity = [DateTime]::UtcNow
$lastMilestone = $lastActivity
$lastProgressSignature = $null
$activeCommandId = $null
$activeCommandStarted = $null
$commandStarts = @{}
$lastWatchdogCheck = [DateTime]::MinValue

$script:State = $null
$script:StatePath = $statePath
$script:EventsWriter = $null
$script:StderrWriter = $null
$script:ReportText = [Text.StringBuilder]::new()
$script:EventIndex = 0
$script:ParseErrors = 0
$script:LastText = $null
$script:LastTextIndex = -1
$script:LastToolUseIndex = -1
$script:LastStepFinishIndex = -1
$script:LastStepFinishReason = $null
$script:PermissionDenied = $false
$script:ProviderError = $false
$script:StderrError = $false
$script:LastEventUtc = $null
$script:LastEventReceivedUtc = $null
$script:LastEventType = $null
$script:LastEventSummary = ''
$script:LastStderrUtc = $null
$script:LastStderrSummary = ''

function Update-RunnerState {
    if ($null -eq $script:State -or !$script:StatePath) { return }
    $s = $script:State
    $s.lastEventUtc = if ($script:LastEventUtc) { $script:LastEventUtc.ToString('o') } else { $null }
    $s.lastEventReceivedUtc = if ($script:LastEventReceivedUtc) { $script:LastEventReceivedUtc.ToString('o') } else { $null }
    $s.lastEventType = $script:LastEventType
    $s.lastEventSummary = $script:LastEventSummary
    $s.lastStderrUtc = if ($script:LastStderrUtc) { $script:LastStderrUtc.ToString('o') } else { $null }
    $s.lastStderrSummary = $script:LastStderrSummary
    $s.eventCount = $script:EventIndex
    $s.parseErrors = $script:ParseErrors
    $s.reportBytes = $script:ReportText.Length
    if ($script:PermissionDenied) { $s.errorCategory = 'permission-denied' }
    elseif ($script:ProviderError) { $s.errorCategory = 'provider-error' }
    elseif ($script:StderrError) { $s.errorCategory = 'stderr-error' }
    Write-WorkerStateAtomic -Path $script:StatePath -State $s
}

function Add-StdoutLine {
    param([AllowEmptyString()][string]$Line)
    $script:EventsWriter.WriteLine($Line)
    $now = [DateTime]::UtcNow
    $script:lastActivity = $now
    $script:LastEventReceivedUtc = $now
    $info = Get-WorkerEventInfo $Line
    if (!$info.Valid) {
        $script:ParseErrors++
        $script:LastEventType = 'malformed'
        $script:LastEventSummary = 'malformed-event'
    } else {
        $script:EventIndex++
        $idx = $script:EventIndex
        $script:LastEventUtc = if ($info.TimestampUtc) { $info.TimestampUtc } else { $now }
        $script:LastEventType = $info.Type
        $script:LastEventSummary = $info.Summary
        if ($info.IsText) {
            $script:LastText = $info.Text
            $script:LastTextIndex = $idx
            if ($script:ReportText.Length -lt 4194304) { [void]$script:ReportText.AppendLine($info.Text) }
        }
        if ($info.IsToolUse) {
            $script:LastToolUseIndex = $idx
            if($info.ToolStatus -eq 'completed'){$script:lastMilestone=$now}
        }
        if ($info.IsStepFinish) {
            $script:LastStepFinishIndex = $idx
            $script:LastStepFinishReason = $info.FinishReason
        }
        if ($info.PermissionDenied) { $script:PermissionDenied = $true }
        if ($info.ProviderError) { $script:ProviderError = $true }
    }
    Update-RunnerState
}

function Add-StderrLine {
    param([AllowEmptyString()][string]$Line)
    $script:StderrWriter.WriteLine($Line)
    $now = [DateTime]::UtcNow
    $summary = 'stderr'
    if ($Line -match '(?i)auto-rejecting|permission requested') {
        $script:PermissionDenied = $true
        $summary = 'stderr:permission-denied'
    } elseif ($Line -match '(?i)\bError:') {
        $script:StderrError = $true
        $summary = 'stderr:error'
        if (Test-WorkerProviderError $Line) { $script:ProviderError = $true; $summary = 'stderr:provider-error' }
    }
    $script:LastStderrUtc = $now
    $script:LastStderrSummary = ConvertTo-WorkerSummary $summary
    Update-RunnerState
}

function Stop-WorkerProcessTree {
    param([Parameter(Mandatory)]$Process)
    $taskkill = Join-Path $env:SystemRoot 'System32/taskkill.exe'
    if (Test-Path -LiteralPath $taskkill) {
        try { & $taskkill /PID $Process.Id /T /F *> $null } catch { }
    }
    try {
        if (!$Process.HasExited) { $Process.Kill($true) }
    } catch { }
    try { [void]$Process.WaitForExit(10000) } catch { }
    if (!$Process.HasExited -and (Test-Path -LiteralPath $taskkill)) {
        try { & $taskkill /PID $Process.Id /T /F *> $null } catch { }
    }
    if(!$Process.WaitForExit(5000)){throw 'Worker termination could not be confirmed; manual process inspection required'}
}

try {
    $lock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None')
    $start = [DateTime]::UtcNow
    $softDeadline = $start.AddSeconds($TimeoutSeconds)
    $deadline = $start.AddSeconds($HardTimeoutSeconds)
    $lastActivity=$start;$lastMilestone=$start
    $state = [ordered]@{
        task = $TaskId
        status = 'running'
        startedUtc = $start.ToString('o')
        deadlineUtc = $deadline.ToString('o')
        timeoutSeconds = $TimeoutSeconds
        softDeadlineUtc = $softDeadline.ToString('o')
        hardTimeoutSeconds = $HardTimeoutSeconds
        idleTimeoutSeconds = $IdleTimeoutSeconds
        milestoneTimeoutSeconds = $MilestoneTimeoutSeconds
        commandTimeoutSeconds = $CommandTimeoutSeconds
        health = 'running'
        progress = $null
        lastActivityReceivedUtc = $start.ToString('o')
        lastMilestoneReceivedUtc = $start.ToString('o')
        retries = 0
        model = 'deepseek/deepseek-flash'
        taskSha256 = (Get-FileHash $task).Hash
        processId = $null
        processName = $null
        runnerProcessId = $PID
        lastEventUtc = $null
        lastEventReceivedUtc = $null
        lastEventType = $null
        lastEventSummary = ''
        lastStderrUtc = $null
        lastStderrSummary = ''
        eventCount = 0
        parseErrors = 0
        reportBytes = 0
    }
    $script:State = $state
    Write-WorkerStateAtomic -Path $statePath -State $state
    git -C $root status --short | Set-Content (Join-Path $run 'before-status.txt')

    $exe = (Get-Command opencode.cmd -ErrorAction Stop).Source
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $env:ComSpec
    $info.WorkingDirectory = $root
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    # Task IDs are restricted above. No auto-approval or configuration override.
    # Attach the runner contract to every task; do not rely on a callback to
    # remember to request progress, and never overwrite the user's task file.
    $contract=Join-Path $run 'worker-contract.md'
    $contractText=@"
# Runner supervision contract for $TaskId
Follow the attached task's scope and preservation rules. The runner's time policy
supersedes older task text describing a fixed wall timeout: soft budget
$TimeoutSeconds seconds; hard maximum $HardTimeoutSeconds seconds, no automatic retry.
Update artifacts/deepseek/$TaskId/progress.json atomically at each phase, before
and after each command, and about every two minutes when able. Schema:
{"taskId":"$TaskId","phase":"inspect","completed":[],"percent":null,"nextStep":"concrete next action","activeCommand":null}
Use completed for concrete milestones with evidence paths. Percent is optional,
estimated and never evidence. Before a command, activeCommand must be
{"id":"unique-stable-command-id","description":"short purpose, no secrets"}.
Clear it after completion; never rotate an id to extend the same command.
Commands must have explicit tool timeouts no greater than $CommandTimeoutSeconds seconds.
Silence outside a declared command is bounded by $IdleTimeoutSeconds seconds;
no completed tool or changed phase/completed milestone is bounded by
$MilestoneTimeoutSeconds seconds. A declared command has its own absolute
$CommandTimeoutSeconds-second cap; timestamp rewrites cannot extend it.
Write command logs/exits and partial findings durably as work proceeds. Near the
hard maximum, stop cleanly with result.md naming completed work, verified results,
unresolved issues and an exact continuation. Hard maximum/stall interruption is
incomplete work, never acceptance. Do not invent progress or retry automatically.
"@
    [IO.File]::WriteAllText($contract,$contractText,[Text.UTF8Encoding]::new($false))
    $relativeContract='artifacts/deepseek/'+$TaskId+'/worker-contract.md'
    $info.Arguments = '/d /s /c ""' + $exe + '" run --pure --format json --model deepseek/deepseek-flash "Execute the attached bounded task and supervision contract, then stop." --file tasks/deepseek/' + $TaskId + '.md ' + $relativeContract + '"'
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    if (!$process.Start()) { throw 'OpenCode did not start' }
    $state.processId = $process.Id
    try { $state.processName = $process.ProcessName } catch { $state.processName = 'unknown' }
    $script:EventsWriter = [IO.StreamWriter]::new($eventsPath, $false, [Text.UTF8Encoding]::new($false))
    $script:EventsWriter.AutoFlush = $true
    $script:StderrWriter = [IO.StreamWriter]::new($stderrPath, $false, [Text.UTF8Encoding]::new($false))
    $script:StderrWriter.AutoFlush = $true
    Update-RunnerState

    $stdoutTask = $process.StandardOutput.ReadLineAsync()
    $stderrTask = $process.StandardError.ReadLineAsync()
    $stdoutOpen = $true
    $stderrOpen = $true
    $exitObservedAt = $null
    $pipeDrainIncomplete = $false

    while ($true) {
        $worked = $false
        if ($stdoutOpen -and $stdoutTask.IsCompleted) {
            $line = $stdoutTask.GetAwaiter().GetResult()
            if ($null -eq $line) {
                $stdoutOpen = $false
            } else {
                Add-StdoutLine $line
                $stdoutTask = $process.StandardOutput.ReadLineAsync()
                $worked = $true
            }
        }
        if ($stderrOpen -and $stderrTask.IsCompleted) {
            $line = $stderrTask.GetAwaiter().GetResult()
            if ($null -eq $line) {
                $stderrOpen = $false
            } else {
                Add-StderrLine $line
                $stderrTask = $process.StandardError.ReadLineAsync()
                $worked = $true
            }
        }

        if ($process.HasExited) {
            if ($null -eq $exitObservedAt) { $exitObservedAt = [DateTime]::UtcNow }
        }
        if ($process.HasExited -and !$stdoutOpen -and !$stderrOpen) { break }
        if ($exitObservedAt -and ([DateTime]::UtcNow - $exitObservedAt).TotalSeconds -gt 15) {
            if ($stdoutOpen -or $stderrOpen) { $pipeDrainIncomplete = $true }
            break
        }

        $now=[DateTime]::UtcNow
        if(!$timedOut -and ($now-$lastWatchdogCheck).TotalSeconds -ge 2){
            $lastWatchdogCheck=$now
            try{
                $progress=Read-WorkerProgress -Path (Join-Path $run 'progress.json') -TaskId $TaskId -Started $start
                if($progress){
                    $state.progress=[ordered]@{phase=$progress.phase;nextStep=$progress.nextStep;percent=$progress.percent;reportedUtc=$progress.received.ToString('o');verified=$false}
                    if($progress.signature -ne $lastProgressSignature){
                        $lastProgressSignature=$progress.signature;$lastMilestone=$now;$lastActivity=$now
                    }
                    if($progress.command){
                        if($progress.command.id -ne $activeCommandId){
                            $activeCommandId=$progress.command.id
                            if(!$commandStarts.ContainsKey($activeCommandId)){$commandStarts[$activeCommandId]=$now}
                            $activeCommandStarted=$commandStarts[$activeCommandId]
                        }
                        $state.progress.activeCommand=$progress.command
                    }else{$activeCommandId=$null;$activeCommandStarted=$null}
                    $state.progressError=$null
                }
            }catch{$state.progressError=ConvertTo-WorkerSummary $_.Exception.Message}
            $state.lastActivityReceivedUtc=$lastActivity.ToString('o')
            $state.lastMilestoneReceivedUtc=$lastMilestone.ToString('o')
            $state.activeCommandStartedUtc=if($activeCommandStarted){$activeCommandStarted.ToString('o')}else{$null}
            $decision=Get-WorkerWatchdogDecision -Now $now -Started $start -LastActivity $lastActivity -LastMilestone $lastMilestone -HardDeadline $deadline -SoftSeconds $TimeoutSeconds -IdleSeconds $IdleTimeoutSeconds -MilestoneSeconds $MilestoneTimeoutSeconds -CommandStarted $activeCommandStarted -CommandSeconds $CommandTimeoutSeconds
            $state.health=$decision
            if($decision -notin @('running','running-extended')){$stopReason=$decision;$timedOut=$true}
            Update-RunnerState
        }
        if ($timedOut -and !$state.Contains('terminationRequestedUtc')) {
            $state.terminationRequestedUtc=[DateTime]::UtcNow.ToString('o')
            $timedOut = $true
            $state.status = if($stopReason -like 'stalled-*'){'stalled'}else{'interrupted'}
            $state.reason = $stopReason
            $state.requiresSupervisorReview=$true
            $state.semanticFailure=$false
            Update-RunnerState
            Stop-WorkerProcessTree -Process $process
        }
        if (!$worked) { Start-Sleep -Milliseconds 50 }
    }

    if (!$process.HasExited) {
        if (!$process.WaitForExit(5000)) { Stop-WorkerProcessTree -Process $process }
    }

    $state.exitCode = $process.ExitCode
    $state.finishedUtc = [DateTime]::UtcNow.ToString('o')
    if ($timedOut) {
        $state.status = if($stopReason -like 'stalled-*'){'stalled'}else{'interrupted'}
        $state.reason = $stopReason
    } elseif ($script:PermissionDenied) {
        $state.status = 'blocked'
        $state.reason = 'permission-denied'
    } elseif ($script:ProviderError) {
        $state.status = 'blocked'
        $state.reason = 'provider-error'
    } elseif ($script:StderrError) {
        $state.status = 'blocked'
        $state.reason = 'stderr-error'
    } elseif ($process.ExitCode -ne 0) {
        $state.status = 'blocked'
        $state.reason = 'nonzero-exit'
    } elseif ($script:ParseErrors -gt 0) {
        $state.status = 'incomplete'
        $state.reason = 'malformed-event-log'
    } elseif ($script:LastTextIndex -lt 0) {
        $state.status = 'incomplete'
        $state.reason = 'missing-final-result'
    } elseif ($script:LastStepFinishIndex -lt 0 -or $script:LastStepFinishReason -ne 'stop') {
        $state.status = 'incomplete'
        $state.reason = 'no-terminal-stop'
    } elseif ($script:LastTextIndex -le $script:LastToolUseIndex) {
        $state.status = 'incomplete'
        $state.reason = 'missing-final-result'
    } elseif ($script:LastStepFinishIndex -lt $script:LastTextIndex) {
        $state.status = 'incomplete'
        $state.reason = 'no-terminal-stop'
    } elseif (Test-WorkerStepExhaustion $script:LastText) {
        $state.status = 'incomplete'
        $state.reason = 'step-exhaustion'
    } elseif ($pipeDrainIncomplete) {
        $state.status = 'incomplete'
        $state.reason = 'output-pipe-open'
    } elseif ([string]::IsNullOrWhiteSpace($script:LastText)) {
        $state.status = 'incomplete'
        $state.reason = 'empty-final-result'
    } else {
        $state.status = 'needs-review'
        $state.reason = 'final-result-present'
    }
    $state.finalEvent = $script:LastStepFinishReason
    $state.finalTextEvent = ($script:LastTextIndex -ge 0)
    $state.outputPipeDrained = !$pipeDrainIncomplete
    $state.reportPresent = ($script:ReportText.Length -gt 0)
    $state.acceptance = 'not-assessed'
    $state.retries = 0
    if ($state.reportPresent) {
        [IO.File]::WriteAllText($reportPath, $script:ReportText.ToString(), [Text.UTF8Encoding]::new($false))
    }
    Update-RunnerState
    git -C $root status --short | Set-Content (Join-Path $run 'after-status.txt')
    Write-Output "$TaskId : $($state.status) ($($state.reason)), exit $($state.exitCode). Inspect artifacts/deepseek/$TaskId."
    if ($state.status -ne 'needs-review') { exit 1 }
} catch {
    if ($null -ne $process -and !$process.HasExited) {
        try { Stop-WorkerProcessTree -Process $process } catch { }
    }
    if ($null -eq $state) {
        $state = [ordered]@{ task = $TaskId; status = 'dispatch-error'; startedUtc = [DateTime]::UtcNow.ToString('o') }
        $script:State = $state
    }
    if ($timedOut) {
        $state.status = if($stopReason -like 'stalled-*'){'stalled'}else{'interrupted'}
        $state.reason = $stopReason
    } else {
        $state.status = 'dispatch-error'
        $state.reason = 'dispatch-error'
    }
    $state.error = [string]$_.Exception.Message
    $state.finishedUtc = [DateTime]::UtcNow.ToString('o')
    $state.reportPresent = ($script:ReportText.Length -gt 0)
    $state.acceptance = 'not-assessed'
    try { Update-RunnerState } catch { }
    throw
} finally {
    if ($null -ne $script:EventsWriter) { try { $script:EventsWriter.Dispose() } catch { } }
    if ($null -ne $script:StderrWriter) { try { $script:StderrWriter.Dispose() } catch { } }
    if ($null -ne $lock) { $lock.Dispose() }
}

$ErrorActionPreference = 'Stop'

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
$tempBase = Join-Path $env:TEMP 'opencode'
New-Item -ItemType Directory -Path $tempBase -Force | Out-Null
$root = Join-Path $tempBase ('worker30-tests-' + [Guid]::NewGuid().ToString('N'))
$fakeBin = Join-Path $repo 'tests/worker/fake-bin'
$workerSource = Join-Path $repo 'tools/worker'
$script:Failures = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { Write-Output "PASS: $Message" }
    else { $script:Failures++; Write-Output "FAIL: $Message" }
}

function Get-State {
    param([string]$TaskId)
    $p = Join-Path $root "artifacts/deepseek/$TaskId/state.json"
    if (!(Test-Path -LiteralPath $p)) { return $null }
    return Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
}

function New-Task {
    param([string]$TaskId)
    $p = Join-Path $root "tasks/deepseek/$TaskId.md"
    Set-Content -LiteralPath $p -Value "# Fake task $TaskId"
}

function Invoke-FakeRun {
    param(
        [string]$Mode,
        [string]$TaskId,
        [int]$TimeoutSeconds = 30,
        [int]$HardSeconds = 0,
        [int]$IdleSeconds = 900,
        [int]$CommandSeconds = 1800,
        [string]$ComSpec = $null,
        [switch]$PassThru
    )
    New-Task $TaskId
    $caseDir = Join-Path $root "runner-$TaskId"
    New-Item -ItemType Directory -Path $caseDir -Force | Out-Null
    $env:FAKE_MODE = $Mode
    $env:FAKE_PIDFILE = Join-Path $caseDir 'fake-pids.txt'
    $oldComSpec = $env:ComSpec
    if ($ComSpec) { $env:ComSpec = $ComSpec }
    if(!$HardSeconds){$HardSeconds=$TimeoutSeconds}
    $env:FAKE_PROGRESS = Join-Path $root "artifacts/deepseek/$TaskId/progress.json"
    $env:FAKE_TASK = $TaskId
    $args = @('-NoProfile', '-File', (Join-Path $root 'tools/worker/Invoke-DeepSeekTask.ps1'), '-TaskId', $TaskId, '-TimeoutSeconds', $TimeoutSeconds, '-HardTimeoutSeconds', $HardSeconds, '-IdleTimeoutSeconds', $IdleSeconds, '-CommandTimeoutSeconds', $CommandSeconds)
    $sp = @{
        FilePath = $pwsh
        ArgumentList = $args
        RedirectStandardOutput = (Join-Path $caseDir 'out.txt')
        RedirectStandardError = (Join-Path $caseDir 'err.txt')
        NoNewWindow = $true
        PassThru = $true
    }
    try {
        $p = Start-Process @sp
        if ($PassThru) { return $p }
        $p.WaitForExit()
        return [pscustomobject]@{ ExitCode = $p.ExitCode; CaseDir = $caseDir }
    } finally {
        $env:ComSpec = $oldComSpec
    }
}

function Invoke-Status {
    param([string]$TaskId)
    $statusArgs = @('-NoProfile', '-File', (Join-Path $root 'tools/worker/Get-DeepSeekStatus.ps1'))
    if ($TaskId) { $statusArgs += @('-TaskId', $TaskId) }
    $raw = & $pwsh @statusArgs 2>&1 | Out-String
    return [pscustomobject]@{ Raw = $raw; Json = ($raw | ConvertFrom-Json) }
}

function Set-Checkpoint {
    param($Data)
    $p = Join-Path $root 'artifacts/deepseek/orchestrator-checkpoint.json'
    if ($null -eq $Data) {
        if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
    } else {
        $Data | ConvertTo-Json -Compress | Set-Content -LiteralPath $p
    }
}

function New-StateRun {
    param([string]$TaskId, $State)
    $dir = Join-Path $root "artifacts/deepseek/$TaskId"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $State | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $dir 'state.json')
}

New-Item -ItemType Directory -Path (Join-Path $root 'tools/worker'), (Join-Path $root 'tasks/deepseek'), (Join-Path $root 'docs'), (Join-Path $root 'artifacts/deepseek') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $workerSource 'DeepSeekWorker.psm1'), (Join-Path $workerSource 'WorkerWatchdog.psm1'), (Join-Path $workerSource 'Invoke-DeepSeekTask.ps1'), (Join-Path $workerSource 'Get-DeepSeekStatus.ps1') -Destination (Join-Path $root 'tools/worker')
Set-Content -LiteralPath (Join-Path $root 'docs/DEEPSEEK-WORKER-STATUS.md') -Value '# Test checkpoint'
$env:PATH = $fakeBin + ';' + $env:PATH
Import-Module (Join-Path $root 'tools/worker/DeepSeekWorker.psm1') -Force
$atomicCheckpoint = Join-Path $root 'atomic-checkpoint.json'
try {
    Write-WorkerCheckpointAtomic -Path $atomicCheckpoint -Checkpoint ([ordered]@{ status='stopped'; nextTask=$null })
    Assert-True ($null -ne (Get-Content -LiteralPath $atomicCheckpoint -Raw | ConvertFrom-Json)) 'checkpoint helper: atomic write accepted'
} catch { Assert-True $false "checkpoint helper: atomic write failed: $($_.Exception.Message)" }
$refused = $false
try { Write-WorkerCheckpointAtomic -Path $atomicCheckpoint -Checkpoint ([ordered]@{ status='stopped'; acceptance='accepted' }) } catch { $refused = $true }
Assert-True $refused 'checkpoint helper: worker cannot self-declare acceptance'

try {
    $r = Invoke-FakeRun -Mode complete -TaskId complete
    $s = Get-State complete
    Assert-True ($r.ExitCode -eq 0) 'complete: runner exit 0'
    Assert-True ($s.status -eq 'needs-review' -and $s.reason -eq 'final-result-present') 'complete: needs-review with terminal result'
    Assert-True ($s.reportPresent -eq $true -and (Test-Path -LiteralPath (Join-Path $root 'artifacts/deepseek/complete/worker-report.md'))) 'complete: actual report written'
    Assert-True (@(Get-ChildItem (Join-Path $root 'artifacts/deepseek/complete') -Filter '.state.*.tmp' -ErrorAction SilentlyContinue).Count -eq 0) 'complete: no atomic temp residue'
    Assert-True ($s.finalEvent -eq 'stop' -and $s.finalTextEvent -eq $true) 'complete: final event recorded'
    Assert-True ($s.acceptance -eq 'not-assessed') 'complete: runner does not self-accept'

    $r = Invoke-FakeRun -Mode quoted -TaskId quoted
    $s = Get-State quoted
    Assert-True ($s.status -eq 'needs-review' -and !$s.errorCategory) 'quoted historical permission phrase: not blocked'

    $r = Invoke-FakeRun -Mode permission -TaskId permission
    $s = Get-State permission
    Assert-True ($r.ExitCode -ne 0 -and $s.status -eq 'blocked' -and $s.reason -eq 'permission-denied') 'structured tool permission error: blocked'

    $r = Invoke-FakeRun -Mode provider -TaskId provider
    $s = Get-State provider
    Assert-True ($s.status -eq 'blocked' -and $s.reason -eq 'provider-error') 'structured provider error: blocked'

    $r = Invoke-FakeRun -Mode nonzero -TaskId nonzero
    $s = Get-State nonzero
    Assert-True ($s.status -eq 'blocked' -and $s.reason -eq 'nonzero-exit' -and $s.exitCode -eq 3) 'nonzero exit: blocked'

    $r = Invoke-FakeRun -Mode nofinal -TaskId nofinal
    $s = Get-State nofinal
    Assert-True ($s.status -eq 'incomplete' -and $s.reason -eq 'missing-final-result') 'missing final result: incomplete'

    $r = Invoke-FakeRun -Mode exhaustion -TaskId exhaustion
    $s = Get-State exhaustion
    Assert-True ($s.status -eq 'incomplete' -and $s.reason -eq 'step-exhaustion') 'step exhaustion: incomplete'

    $r = Invoke-FakeRun -Mode partial -TaskId partial
    $s = Get-State partial
    Assert-True ($s.status -eq 'incomplete' -and $s.reason -eq 'malformed-event-log') 'partial JSON: incomplete'

    $r = Invoke-FakeRun -Mode complete -TaskId dispatchfail -ComSpec 'C:\definitely-missing-cmd.exe'
    $s = Get-State dispatchfail
    Assert-True ($r.ExitCode -ne 0 -and $s.status -eq 'dispatch-error' -and $s.finishedUtc -and $s.status -ne 'running') 'dispatch failure: no stale running state'

    $p = Invoke-FakeRun -Mode slow -TaskId slow -PassThru
    $sawRunning = $false
    $sawIncremental = $false
    $sawLastEvent = $false
    for ($i = 0; $i -lt 100 -and !$p.HasExited; $i++) {
        $s = Get-State slow
        $ep = Join-Path $root 'artifacts/deepseek/slow/events.jsonl'
        if ($s -and $s.status -eq 'running') { $sawRunning = $true }
        if ((Test-Path -LiteralPath $ep) -and (Get-Item -LiteralPath $ep).Length -gt 0) { $sawIncremental = $true }
        if ($s -and $s.lastEventType) { $sawLastEvent = $true }
        if ($sawRunning -and $sawIncremental -and $sawLastEvent) { break }
        Start-Sleep -Milliseconds 100
    }
    $p.WaitForExit()
    $s = Get-State slow
    Assert-True $sawRunning 'slow run: durable running state while process active'
    Assert-True $sawIncremental 'slow run: incremental raw stdout durable while running'
    Assert-True $sawLastEvent 'slow run: last-event metadata durable while running'
    Assert-True ($s.status -eq 'needs-review') 'slow run: completes to needs-review'

    $r = Invoke-FakeRun -Mode extended -TaskId extended -HardSeconds 60
    $s = Get-State extended
    Assert-True ($s.status -eq 'needs-review' -and ([datetime]$s.finishedUtc-[datetime]$s.startedUtc).TotalSeconds -gt 30) 'soft budget: productive worker finishes after soft deadline'
    $st = Invoke-Status extended
    Assert-True ($st.Json.watchdog.progress.phase -eq 'verification' -and !$st.Json.watchdog.progress.verified) 'status: advisory progress visible without acceptance claim'

    $r = Invoke-FakeRun -Mode timeout-tree -TaskId idlestall -IdleSeconds 5
    $s = Get-State idlestall
    Assert-True ($s.status -eq 'stalled' -and $s.reason -eq 'stalled-no-activity') 'idle: silent worker stopped before hard deadline'
    foreach($id in (Get-Content (Join-Path $root 'runner-idlestall/fake-pids.txt'))){
        Assert-True ($null -eq (Get-Process -Id ([int]$id) -ErrorAction SilentlyContinue)) 'idle: descendant stopped'
    }
    $r = Invoke-FakeRun -Mode commandstall -TaskId commandstall -IdleSeconds 5 -CommandSeconds 10
    $s = Get-State commandstall
    Assert-True ($s.reason -eq 'command-deadline' -and ([datetime]$s.finishedUtc-[datetime]$s.startedUtc).TotalSeconds -ge 10) 'command: quiet lease survives idle limit but is force stopped at command bound'

    $r = Invoke-FakeRun -Mode timeout-tree -TaskId timeouttree -TimeoutSeconds 30
    $s = Get-State timeouttree
    Assert-True ($s.status -eq 'interrupted' -and $s.reason -eq 'hard-deadline' -and $s.finishedUtc -and !$s.semanticFailure -and $s.requiresSupervisorReview) 'timeout: hard deadline preserved as interruption requiring review'
    Assert-True ($s.parseErrors -ge 1) 'timeout: truncated JSON did not override timeout'
    Assert-True ((Get-Item -LiteralPath (Join-Path $root 'artifacts/deepseek/timeouttree/events.jsonl')).Length -gt 0) 'timeout: partial raw events durable'
    $pidFile = Join-Path $root 'runner-timeouttree/fake-pids.txt'
    if (Test-Path -LiteralPath $pidFile) {
        $pids = @(Get-Content -LiteralPath $pidFile | ForEach-Object { [int]$_ })
        foreach ($id in $pids) {
            $alive = Get-Process -Id $id -ErrorAction SilentlyContinue
            Assert-True ($null -eq $alive) "timeout: process tree member $id terminated"
        }
    } else {
        Assert-True $false 'timeout: fake pid file present'
    }

    $r = Invoke-FakeRun -Mode pipe-drain -TaskId pipedrain -TimeoutSeconds 30
    $s = Get-State pipedrain
    Assert-True ($s.status -eq 'incomplete' -and $s.reason -eq 'output-pipe-open') 'pipe drain: open child pipe is incomplete, not completed stop'
    Assert-True ($s.outputPipeDrained -eq $false) 'pipe drain: drain state recorded'
    $pidFile = Join-Path $root 'runner-pipedrain/fake-pids.txt'
    if (Test-Path -LiteralPath $pidFile) {
        foreach ($id in @(Get-Content -LiteralPath $pidFile | ForEach-Object { [int]$_ })) {
            $alive = Get-Process -Id $id -ErrorAction SilentlyContinue
            if ($alive) { try { $alive.Kill() } catch { } }
        }
    }

    $now = [DateTime]::UtcNow
    New-StateRun 'zzz-latest' ([ordered]@{ task='zzz-latest'; status='needs-review'; reason='final-result-present'; startedUtc=$now.ToString('o'); finishedUtc=$now.ToString('o'); acceptance='not-assessed' })

    Set-Checkpoint ([ordered]@{ status='stopped'; boundary='workflowrobustness'; gate='gate-28'; attempt=2; nextTask=$null; reviewedTask='complete'; stopreason='reviewed' })
    $st = Invoke-Status
    Assert-True ($st.Json.status -eq 'STOPPED' -and $null -eq $st.Json.nextTask) 'status: stopped checkpoint with null nextTask reports STOPPED'
    Assert-True ($null -eq $st.Json.currentTask) 'status: stopped checkpoint never promotes an old latest run'
    Assert-True ($st.Json.lastReviewedRun.id -eq 'complete' -and $st.Json.lastReviewedRun.status -eq 'needs-review') 'status: last reviewed run reported separately'
    Assert-True ($st.Json.lastReviewedRun.id -ne 'zzz-latest') 'status: newer unrelated run is not the reviewed run'
    Assert-True ($st.Json.stopreason -eq 'reviewed') 'status: stopreason emitted'

    Set-Checkpoint ([ordered]@{ status='active-robustness-resumption'; boundary='workflowrobustness'; gate='gate-28'; attempt=2; nextTask='slow'; reviewedTask='complete'; stopreason=$null })
    $st = Invoke-Status
    Assert-True ($st.Json.status -eq 'active-robustness-resumption' -and $st.Json.currentTask.id -eq 'slow' -and $st.Json.nextTask -eq 'slow') 'status: checkpoint nextTask wins over latest run'
    Assert-True ($st.Json.lastReviewedRun.id -eq 'complete') 'status: reviewed run remains separate from active nextTask'
    Assert-True ($st.Json.boundary -eq 'workflowrobustness' -and $st.Json.gate -eq 'gate-28' -and $st.Json.attempt -eq 2) 'status: boundary/gate/attempt emitted'
    Assert-True ($st.Json.checkpoint.exists -eq $true -and $st.Json.checkpoint.valid -eq $true -and $st.Json.checkpoint.sha256) 'status: valid checkpoint metadata present'
    $override = Invoke-Status -TaskId complete
    Assert-True ($override.Json.currentTask.id -eq 'complete' -and $override.Json.nextTask -eq 'slow') 'status: explicit TaskId overrides a valid checkpoint nextTask'

    Set-Checkpoint ([ordered]@{ status='active'; nextTask='ghost'; reviewedTask='complete'; attempt=2 })
    $st = Invoke-Status
    Assert-True ($st.Json.status -eq 'MISSING-RUN' -and $st.Json.currentTask.exists -eq $false -and $st.Json.liveness -eq 'no-run') 'status: missing nextTask run is diagnosed without fallback'

    Set-Content -LiteralPath (Join-Path $root 'artifacts/deepseek/orchestrator-checkpoint.json') -Value '{not valid json'
    $st = Invoke-Status
    Assert-True ($st.Json.status -eq 'CHECKPOINT-MALFORMED' -and $st.Json.diagnostic -eq 'checkpoint-malformed' -and $null -eq $st.Json.currentTask) 'status: malformed checkpoint fails safe'
    Assert-True ($null -eq $st.Json.lastReviewedRun) 'status: malformed checkpoint does not infer reviewed history'

    Set-Checkpoint $null
    $st = Invoke-Status
    Assert-True ($st.Json.status -eq 'CHECKPOINT-MISSING' -and $st.Json.diagnostic -eq 'checkpoint-missing' -and $null -eq $st.Json.currentTask) 'status: missing checkpoint has no auto dispatch'

    $st = Invoke-Status -TaskId complete
    Assert-True ($st.Json.selection.source -eq 'explicit' -and $st.Json.currentTask.id -eq 'complete') 'status: explicit TaskId overrides checkpoint state'
    Assert-True ($st.Json.liveness -eq 'stopped' -and $st.Json.review.state -eq 'needs-review') 'status: stopped run has review state'
    Assert-True ($st.Json.checkpoint.exists -eq $false) 'status: checkpoint metadata present and honestly reports absence'
    Assert-True (@($st.Raw.Trim() -split '\r?\n').Count -eq 1) 'status: one compact JSON object'
    Assert-True ($null -ne $st.Json.process -and $null -ne $st.Json.deadline -and $null -ne $st.Json.review) 'status: process/deadline/review present'
    Assert-True ($st.Raw -notmatch 'bounded fake report') 'status: no raw report text exposed'
    Assert-True ($st.Json.review.acceptance -eq 'not-assessed') 'status: acceptance remains not-assessed'

    $now = [DateTime]::UtcNow
    $staleDir = Join-Path $root 'artifacts/deepseek/stalerun'
    New-Item -ItemType Directory -Path $staleDir -Force | Out-Null
    [ordered]@{ task='stalerun'; status='running'; startedUtc=$now.ToString('o'); deadlineUtc=$now.AddSeconds(600).ToString('o'); timeoutSeconds=600; processId=999999 } | ConvertTo-Json | Set-Content (Join-Path $staleDir 'state.json')
    $st = Invoke-Status -TaskId stalerun
    Assert-True ($st.Json.liveness -eq 'stale') 'status: stale dead PID without lock'

    $deadDir = Join-Path $root 'artifacts/deepseek/deadrun'
    New-Item -ItemType Directory -Path $deadDir -Force | Out-Null
    [ordered]@{ task='deadrun'; status='running'; startedUtc=$now.ToString('o'); deadlineUtc=$now.AddSeconds(600).ToString('o'); timeoutSeconds=600; processId=999998 } | ConvertTo-Json | Set-Content (Join-Path $deadDir 'state.json')
    $lockStream = [IO.File]::Open((Join-Path $root 'artifacts/deepseek/worker.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    try {
        $st = Invoke-Status -TaskId deadrun
        Assert-True ($st.Json.liveness -eq 'dead') 'status: dead process with lock held'
    } finally { $lockStream.Dispose() }

    $sleeper = Start-Process -FilePath $pwsh -ArgumentList @('-NoProfile', '-Command', 'Start-Sleep -Seconds 60') -PassThru -WindowStyle Hidden
    try {
        $runDir = Join-Path $root 'artifacts/deepseek/runningrun'
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        [ordered]@{ task='runningrun'; status='running'; startedUtc=$sleeper.StartTime.ToUniversalTime().ToString('o'); deadlineUtc=[DateTime]::UtcNow.AddSeconds(600).ToString('o'); timeoutSeconds=600; processId=$sleeper.Id } | ConvertTo-Json | Set-Content (Join-Path $runDir 'state.json')
        $st = Invoke-Status -TaskId runningrun
        Assert-True ($st.Json.liveness -eq 'running' -and $st.Json.process.alive -eq $true) 'status: live running process'
        Assert-True ($st.Json.deadline.remainingSeconds -gt 0 -and $st.Json.deadline.expired -eq $false) 'status: live deadline not expired'
    } finally {
        if (!$sleeper.HasExited) { $sleeper.Kill() }
    }

    $r = Invoke-FakeRun -Mode complete -TaskId complete
    Assert-True ($r.ExitCode -ne 0 -and (Get-Content -LiteralPath (Join-Path $root 'runner-complete/err.txt') -Raw) -match 'Existing run') 'create-only: no automatic retry over existing run'
} finally {
    Write-Output "TEMP: $root"
    if ($script:Failures -gt 0) {
        Write-Output "FAILURES: $script:Failures"
        exit 1
    }
    Write-Output 'ALL WORKER TESTS PASSED'
    exit 0
}

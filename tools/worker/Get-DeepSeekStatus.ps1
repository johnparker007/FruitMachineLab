param(
    [ValidatePattern('^[a-z0-9-]+$')][string]$TaskId
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DeepSeekWorker.psm1') -Force

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$artifacts = Join-Path $root 'artifacts/deepseek'
$checkpointPath = Join-Path $artifacts 'orchestrator-checkpoint.json'
$legacyDocPath = Join-Path $root 'docs/DEEPSEEK-WORKER-STATUS.md'
$lockPath = Join-Path $artifacts 'worker.lock'

function ConvertTo-Utc {
    param($Value)
    return ConvertTo-WorkerUtc $Value
}

function Get-JsonOnce {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path)) { return $null }
    try {
        $raw = [IO.File]::ReadAllText($Path)
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return $null
    }
}

function Get-LatestRunId {
    $candidates = @()
    if (Test-Path -LiteralPath $artifacts) {
        $candidates = Get-ChildItem -LiteralPath $artifacts -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $sp = Join-Path $_.FullName 'state.json'
            if (Test-Path -LiteralPath $sp) {
                $st = Get-JsonOnce $sp
                if ($st) {
                    [pscustomobject]@{ Id = $_.Name; Started = (ConvertTo-Utc $st.startedUtc) }
                }
            }
        } | Sort-Object Started -Descending
    }
    if ($candidates.Count -gt 0) { return $candidates[0].Id }
    return $null
}

$checkpoint = [ordered]@{
    file = 'artifacts/deepseek/orchestrator-checkpoint.json'
    exists = $false
    valid = $false
    modifiedUtc = $null
    sha256 = $null
}
$checkpointData = $null
$diagnostic = $null
$rawCheckpoint = $null

if (Test-Path -LiteralPath $checkpointPath) {
    $checkpoint.exists = $true
    $checkpoint.modifiedUtc = (Get-Item -LiteralPath $checkpointPath).LastWriteTimeUtc.ToString('o')
    try {
        $rawCheckpoint = [IO.File]::ReadAllText($checkpointPath)
        if ([string]::IsNullOrWhiteSpace($rawCheckpoint)) { throw 'Empty checkpoint' }
        $checkpoint.sha256 = ([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($rawCheckpoint)) | ForEach-Object { $_.ToString('x2') }) -join ''
        $checkpointData = $rawCheckpoint | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $checkpointData -or $checkpointData -is [array]) { throw 'Checkpoint is not an object' }
        $checkpoint.valid = $true
    } catch {
        $checkpointData = $null
        $diagnostic = 'checkpoint-malformed'
    }
} else {
    $diagnostic = 'checkpoint-missing'
}

function Get-CheckpointValue {
    param($Data, [string[]]$Names)
    if ($null -eq $Data) { return $null }
    foreach ($name in $Names) {
        $prop = $Data.PSObject.Properties[$name]
        if ($prop) { return $prop.Value }
    }
    return $null
}

$checkpointStatus = [string](Get-CheckpointValue $checkpointData @('status'))
$boundary = Get-CheckpointValue $checkpointData @('boundary')
$gate = Get-CheckpointValue $checkpointData @('gate')
$attempt = Get-CheckpointValue $checkpointData @('attempt')
$reviewedTask = [string](Get-CheckpointValue $checkpointData @('reviewedTask'))
$stopreason = Get-CheckpointValue $checkpointData @('stopreason', 'stopReason', 'reason')
$nextTask = [string](Get-CheckpointValue $checkpointData @('nextTask'))

if ($checkpoint.valid -and $nextTask -and $nextTask -notmatch '^[a-z0-9-]+$') {
    $diagnostic = 'checkpoint-invalid-next-task'
    $nextTask = ''
}
if ([string]::IsNullOrWhiteSpace($nextTask)) { $nextTask = $null }
if ([string]::IsNullOrWhiteSpace($reviewedTask)) { $reviewedTask = $null }

$selection = [ordered]@{ taskId = $null; source = 'none'; authority = 'none' }
if ($TaskId) {
    $selection.taskId = $TaskId
    $selection.source = 'explicit'
    $selection.authority = 'explicit-override'
} elseif ($checkpoint.valid -and $nextTask) {
    $selection.taskId = $nextTask
    $selection.source = 'checkpoint'
    $selection.authority = 'checkpoint'
} elseif (!$checkpoint.exists) {
    $legacy = $false
    if (Test-Path -LiteralPath $legacyDocPath) {
        try {
            $legacyText = Get-Content -LiteralPath $legacyDocPath -Raw
            if ($legacyText -match '(?i)historical pilot checkpoint|legacy checkpoint') { $legacy = $true }
        } catch { }
    }
    if ($legacy) {
        $latest = Get-LatestRunId
        if ($latest) {
            $selection.taskId = $latest
            $selection.source = 'legacy-latest'
            $selection.authority = 'none'
        }
    }
}

function Get-RunDirectory {
    param([string]$Id)
    if (!$Id) { return $null }
    return (Join-Path $artifacts $Id)
}

function Get-RunState {
    param([string]$Id)
    $dir = Get-RunDirectory $Id
    if (!$dir -or !(Test-Path -LiteralPath $dir)) { return $null }
    return (Get-JsonOnce (Join-Path $dir 'state.json'))
}

function Get-RunSummary {
    param([string]$Id)
    if (!$Id) { return $null }
    $dir = Get-RunDirectory $Id
    $summary = [ordered]@{
        id = $Id
        exists = [bool](Test-Path -LiteralPath $dir)
        statePresent = $false
        liveness = 'no-run'
        status = $null
        reason = $null
        acceptance = 'not-assessed'
        startedUtc = $null
        finishedUtc = $null
        reportPresent = $false
    }
    if (!$summary.exists) { return $summary }
    $st = Get-JsonOnce (Join-Path $dir 'state.json')
    if (!$st) { return $summary }
    $summary.statePresent = $true
    $summary.liveness = Get-WorkerStatusLiveness -State $st -LockPath $lockPath
    $summary.status = $st.status
    $summary.reason = $st.reason
    if ($st.PSObject.Properties['acceptance']) { $summary.acceptance = $st.acceptance }
    $sv = ConvertTo-Utc $st.startedUtc
    if ($sv) { $summary.startedUtc = $sv.ToString('o') }
    $fv = ConvertTo-Utc $st.finishedUtc
    if ($fv) { $summary.finishedUtc = $fv.ToString('o') }
    $summary.reportPresent = [bool](Test-Path -LiteralPath (Join-Path $dir 'worker-report.md'))
    return $summary
}

$run = Get-RunDirectory $selection.taskId
$state = $null
$liveness = 'no-run'
$processInfo = $null
$deadlineInfo = $null
$review = $null
$lastEvent = [ordered]@{ utc = $null; type = $null; summary = $null; valid = $false }

if ($run -and (Test-Path -LiteralPath $run)) {
    $statePath = Join-Path $run 'state.json'
    $state = Get-JsonOnce $statePath
}

if ($state) {
    $pidValue = $null
    if ($state.PSObject.Properties['processId'] -and $state.processId) { $pidValue = [string]$state.processId }
    $liveness = Get-WorkerStatusLiveness -State $state -LockPath $lockPath -ProcessId $pidValue

    $deadlineValue = ConvertTo-Utc $state.deadlineUtc
    if (!$deadlineValue) {
        $started = ConvertTo-Utc $state.startedUtc
        if ($started -and $state.timeoutSeconds) { $deadlineValue = $started.AddSeconds([double]$state.timeoutSeconds) }
    }
    $remaining = $null
    if ($deadlineValue) { $remaining = [int][Math]::Round(($deadlineValue - [DateTime]::UtcNow).TotalSeconds) }

    $processInfo = [ordered]@{ id = $pidValue; name = $null; alive = $false; startedUtc = $null }
    if ($pidValue) {
        $p = Get-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue
        if ($p) {
            $processInfo.alive = $true
            try { $processInfo.name = $p.ProcessName } catch { }
            try { $processInfo.startedUtc = $p.StartTime.ToUniversalTime().ToString('o') } catch { }
        }
    }

    $eventsPath = Join-Path $run 'events.jsonl'
    if (Test-Path -LiteralPath $eventsPath) {
        $tail = @(Get-Content -LiteralPath $eventsPath -Tail 5 -ErrorAction SilentlyContinue)
        for ($i = $tail.Count - 1; $i -ge 0; $i--) {
            if ([string]::IsNullOrWhiteSpace($tail[$i])) { continue }
            $info = Get-WorkerEventInfo $tail[$i]
            if ($info.Valid) {
                $lastEvent.valid = $true
                $lastEvent.type = $info.Type
                $lastEvent.summary = $info.Summary
                $lastEvent.utc = if ($info.TimestampUtc) { $info.TimestampUtc.ToString('o') } else { (Get-Item -LiteralPath $eventsPath).LastWriteTimeUtc.ToString('o') }
            } else {
                $lastEvent.type = 'malformed'
                $lastEvent.summary = 'malformed-event'
                $lastEvent.utc = (Get-Item -LiteralPath $eventsPath).LastWriteTimeUtc.ToString('o')
            }
            break
        }
    }
    if (!$lastEvent.valid -and $state.PSObject.Properties['lastEventType'] -and $state.lastEventType) {
        $lastEvent.type = $state.lastEventType
        $lastEvent.summary = $state.lastEventSummary
        $v = ConvertTo-Utc $state.lastEventUtc
        if ($v) { $lastEvent.utc = $v.ToString('o') }
    }

    $review = [ordered]@{
        state = $state.status
        reason = $state.reason
        acceptance = if ($state.PSObject.Properties['acceptance']) { $state.acceptance } else { 'not-assessed' }
        reportPresent = (Test-Path -LiteralPath (Join-Path $run 'worker-report.md'))
        finalEvent = $state.finalEvent
        finalTextEvent = $state.finalTextEvent
        exitCode = $state.exitCode
        startedUtc = if ($state.startedUtc) { $v = ConvertTo-Utc $state.startedUtc; if ($v) { $v.ToString('o') } else { $null } } else { $null }
        finishedUtc = if ($state.finishedUtc) { $v = ConvertTo-Utc $state.finishedUtc; if ($v) { $v.ToString('o') } else { $null } } else { $null }
        eventCount = $state.eventCount
        parseErrors = $state.parseErrors
        lastEventUtc = $lastEvent.utc
        lastEventType = $lastEvent.type
        lastEventSummary = $lastEvent.summary
    }

    $deadlineInfo = [ordered]@{
        utc = if ($deadlineValue) { $deadlineValue.ToString('o') } else { $null }
        remainingSeconds = $remaining
        expired = ($null -ne $remaining -and $remaining -le 0)
    }
}

if (!$selection.taskId) {
    $status = if (!$checkpoint.exists) { 'CHECKPOINT-MISSING' } elseif (!$checkpoint.valid) { 'CHECKPOINT-MALFORMED' } else { 'NO-NEXT-TASK' }
    if ($checkpoint.valid -and !$nextTask -and $checkpointStatus -match '(?i)stop|paus|halt|complet|idle|inactive') { $status = 'STOPPED' }
} elseif (!$run -or !(Test-Path -LiteralPath $run)) {
    $status = 'MISSING-RUN'
} elseif (!$state) {
    $status = 'NO-STATE'
} elseif ($selection.source -eq 'checkpoint') {
    $status = if ($checkpointStatus) { $checkpointStatus } else { 'ACTIVE' }
} elseif ($selection.source -eq 'legacy-latest') {
    $status = 'LEGACY-LATEST'
} else {
    $status = $liveness
}

$lockHeld = $false
try {
    $stream = [IO.File]::Open($lockPath, 'Open', 'ReadWrite', 'None')
    $stream.Dispose()
} catch {
    if ([IO.File]::Exists($lockPath)) { $lockHeld = $true }
}

$currentTask = $null
if ($selection.taskId) {
    $currentTask = [ordered]@{
        id = $selection.taskId
        exists = [bool]($run -and (Test-Path -LiteralPath $run))
        statePresent = [bool]$state
        statePath = if ($run) { Join-Path $run 'state.json' } else { $null }
    }
}

$payload = [ordered]@{
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    status = $status
    liveness = $liveness
    boundary = $boundary
    gate = $gate
    attempt = $attempt
    nextTask = $nextTask
    reviewedTask = $reviewedTask
    stopreason = $stopreason
    diagnostic = $diagnostic
    checkpointStatus = if ($checkpointStatus) { $checkpointStatus } else { $null }
    selection = $selection
    checkpoint = $checkpoint
    currentTask = $currentTask
    lastReviewedRun = Get-RunSummary $reviewedTask
    process = $processInfo
    deadline = $deadlineInfo
    lock = [ordered]@{ held = $lockHeld }
    review = $review
    watchdog = if($state -and $state.PSObject.Properties['health']){
        [ordered]@{health=$state.health;softDeadlineUtc=$state.softDeadlineUtc;hardDeadlineUtc=$state.deadlineUtc;lastActivityReceivedUtc=$state.lastActivityReceivedUtc;lastMilestoneReceivedUtc=$state.lastMilestoneReceivedUtc;progress=$state.progress;activeCommandStartedUtc=$state.activeCommandStartedUtc}
    }else{$null}
}
$payload | ConvertTo-Json -Depth 8 -Compress

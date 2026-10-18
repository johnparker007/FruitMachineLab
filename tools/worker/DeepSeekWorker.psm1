Set-StrictMode -Version 2.0

function Write-WorkerStateAtomic {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$State
    )
    $dir = Split-Path -Parent $Path
    $json = $State | ConvertTo-Json -Depth 8 -Compress
    $tmp = Join-Path $dir ('.state.' + $PID + '.' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($tmp, $json, [Text.UTF8Encoding]::new($false))
        for ($attempt = 0; $attempt -lt 6; $attempt++) {
            try {
                if ([IO.File]::Exists($Path)) {
                    try { [IO.File]::Move($tmp, $Path, $true) }
                    catch { Move-Item -LiteralPath $tmp -Destination $Path -Force }
                } else {
                    [IO.File]::Move($tmp, $Path)
                }
                return
            } catch {
                if ($attempt -eq 5) { throw }
                Start-Sleep -Milliseconds 25
            }
        }
    } finally {
        if ([IO.File]::Exists($tmp)) { [IO.File]::Delete($tmp) }
    }
}

function Write-WorkerCheckpointAtomic {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Checkpoint
    )
    $acceptance = $null
    if ($Checkpoint -is [Collections.IDictionary]) {
        if ($Checkpoint.Contains('acceptance')) { $acceptance = $Checkpoint['acceptance'] }
    } elseif ($Checkpoint.PSObject.Properties['acceptance']) {
        $acceptance = $Checkpoint.acceptance
    }
    if ($acceptance -eq 'accepted') {
        throw 'Worker checkpoint helper cannot declare acceptance; supervisor review is required.'
    }
    Write-WorkerStateAtomic -Path $Path -State $Checkpoint
}

function Get-WorkerEventInfo {
    param([AllowEmptyString()][string]$Line)
    $result = [ordered]@{
        Valid          = $false
        Type           = $null
        TimestampUtc   = $null
        IsText         = $false
        Text           = $null
        IsToolUse      = $false
        ToolName       = $null
        ToolStatus     = $null
        ToolError      = $null
        IsStepFinish   = $false
        FinishReason   = $null
        IsErrorEvent   = $false
        ErrorText      = $null
        PermissionDenied = $false
        ProviderError  = $false
        StepExhausted  = $false
        Summary        = ''
    }
    if ([string]::IsNullOrWhiteSpace($Line)) { return [pscustomobject]$result }
    $event = $null
    try { $event = $Line | ConvertFrom-Json -ErrorAction Stop } catch { return [pscustomobject]$result }
    if ($null -eq $event) { return [pscustomobject]$result }

    $result.Valid = $true
    if ($event.PSObject.Properties['type']) { $result.Type = [string]$event.type }
    if ($event.PSObject.Properties['timestamp'] -and $event.timestamp) {
        try { $result.TimestampUtc = [DateTimeOffset]::FromUnixTimeMilliseconds([long]$event.timestamp).UtcDateTime } catch { }
    }

    $part = $null
    if ($event.PSObject.Properties['part'] -and $event.part) { $part = $event.part }

    if ($result.Type -eq 'text' -and $part -and $part.PSObject.Properties['text']) {
        $result.IsText = $true
        $result.Text = [string]$part.text
        if (Test-WorkerStepExhaustion $result.Text) { $result.StepExhausted = $true }
    }

    if ($result.Type -eq 'tool_use' -and $part) {
        $result.IsToolUse = $true
        if ($part.PSObject.Properties['tool']) { $result.ToolName = [string]$part.tool }
        $state = $null
        if ($part.PSObject.Properties['state'] -and $part.state) { $state = $part.state }
        if ($state -and $state.PSObject.Properties['status']) { $result.ToolStatus = [string]$state.status }
        if ($state -and $state.PSObject.Properties['error'] -and $state.error) {
            $result.ToolError = [string]$state.error
            if ($result.ToolError -match '(?i)(permission|rejected|denied|forbidden|not\s+allowed)') {
                $result.PermissionDenied = $true
            } elseif (Test-WorkerProviderError $result.ToolError) {
                $result.ProviderError = $true
            }
        }
    }

    if ($result.Type -eq 'step_finish' -and $part -and $part.PSObject.Properties['reason']) {
        $result.IsStepFinish = $true
        $result.FinishReason = [string]$part.reason
    }

    if ($result.Type -eq 'error') {
        $result.IsErrorEvent = $true
        if ($event.PSObject.Properties['error'] -and $event.error) { $result.ErrorText = [string]$event.error }
        $result.ProviderError = $true
    }
    if ($event.PSObject.Properties['error'] -and $event.error -and $result.Type -ne 'tool_use') {
        $result.IsErrorEvent = $true
        if (!$result.ErrorText) { $result.ErrorText = [string]$event.error }
        $result.ProviderError = $true
    }

    $summaryParts = @()
    if ($result.Type) { $summaryParts += $result.Type }
    if ($result.IsToolUse) {
        if ($result.ToolName) { $summaryParts += $result.ToolName }
        if ($result.ToolStatus) { $summaryParts += $result.ToolStatus }
    }
    if ($result.IsStepFinish -and $result.FinishReason) { $summaryParts += $result.FinishReason }
    if ($result.PermissionDenied) { $summaryParts += 'permission-denied' }
    elseif ($result.ProviderError) { $summaryParts += 'provider-error' }
    elseif ($result.StepExhausted) { $summaryParts += 'step-exhaustion' }
    $result.Summary = ConvertTo-WorkerSummary (($summaryParts | Where-Object { $_ }) -join ':')
    return [pscustomobject]$result
}

function Test-WorkerStepExhaustion {
    param([AllowEmptyString()][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    return $Text -match '(?i)maximum steps for this agent have been reached|maximum\s+(?:agent\s+)?steps.{0,40}(?:reached|exhausted)|step\s+(?:limit|budget).{0,30}(?:reached|exhausted)|too many steps'
}

function Test-WorkerProviderError {
    param([AllowEmptyString()][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    return $Text -match '(?i)(provider|api[\s_-]?error|rate[\s_-]?limit|quota|insufficient|unauthorized|authentication|model.{0,24}not.{0,24}found|overloaded|service unavailable|bad gateway|gateway timeout)'
}

function ConvertTo-WorkerSummary {
    param([AllowEmptyString()][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $clean = $Text -replace '[\x00-\x1f\x7f]+', ' ' -replace '\s+', ' '
    $clean = $clean.Trim()
    if ($clean.Length -gt 160) { $clean = $clean.Substring(0, 160) }
    return $clean
}

function ConvertTo-WorkerUtc {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [DateTime]) { return $Value.ToUniversalTime() }
    if ($Value -is [DateTimeOffset]) { return $Value.UtcDateTime }
    try {
        return [DateTime]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
    } catch { return $null }
}

function Get-WorkerStatusLiveness {
    param(
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)][string]$LockPath,
        [string]$ProcessId
    )
    $status = ''
    if ($State.PSObject.Properties['status'] -and $State.status) { $status = '' + $State.status }
    if ($status -ne 'running') { return 'stopped' }

    $alive = $false
    $pidValue = 0
    if ($ProcessId -and [int]::TryParse($ProcessId, [ref]$pidValue)) {
        $p = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
        if ($p) {
            $alive = $true
            if ($State.PSObject.Properties['startedUtc'] -and $State.startedUtc) {
                $started = ConvertTo-WorkerUtc $State.startedUtc
                if ($started) {
                    try {
                        if ($p.StartTime.ToUniversalTime() -lt $started.AddSeconds(-30)) { $alive = $false }
                        if ($p.StartTime.ToUniversalTime() -gt $started.AddSeconds(30)) { $alive = $false }
                    } catch { }
                }
            }
        }
    }

    $lockHeld = $false
    try {
        $stream = [IO.File]::Open($LockPath, 'Open', 'ReadWrite', 'None')
        $stream.Dispose()
    } catch {
        if ([IO.File]::Exists($LockPath)) { $lockHeld = $true }
    }

    $deadline = $null
    if ($State.PSObject.Properties['deadlineUtc'] -and $State.deadlineUtc) {
        $deadline = ConvertTo-WorkerUtc $State.deadlineUtc
    }
    if ($null -eq $deadline -and $State.PSObject.Properties['startedUtc'] -and $State.startedUtc -and $State.PSObject.Properties['timeoutSeconds'] -and $State.timeoutSeconds) {
        $started = ConvertTo-WorkerUtc $State.startedUtc
        if ($started) { $deadline = $started.AddSeconds([double]$State.timeoutSeconds) }
    }
    $expired = ($null -ne $deadline -and [DateTime]::UtcNow -ge $deadline)

    if ($alive -and !$expired) { return 'running' }
    if ($alive -and $expired) { return 'overdue' }
    if (!$alive -and $lockHeld) { return 'dead' }
    return 'stale'
}

Export-ModuleMember -Function Write-WorkerStateAtomic, Write-WorkerCheckpointAtomic, Get-WorkerEventInfo, Test-WorkerStepExhaustion, Test-WorkerProviderError, ConvertTo-WorkerSummary, ConvertTo-WorkerUtc, Get-WorkerStatusLiveness

$ErrorActionPreference = 'Stop'

function Now { [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() }
function Emit($Object) {
    [Console]::Out.WriteLine(($Object | ConvertTo-Json -Compress -Depth 8))
    [Console]::Out.Flush()
}
function StepStart {
    Emit @{ type = 'step_start'; timestamp = (Now); part = @{ type = 'step-start' } }
}
function StepFinish([string]$Reason) {
    Emit @{ type = 'step_finish'; timestamp = (Now); part = @{ reason = $Reason } }
}
function Text([string]$Value) {
    Emit @{ type = 'text'; timestamp = (Now); part = @{ type = 'text'; text = $Value } }
}
function ToolCompleted([string]$Output) {
    Emit @{ type = 'tool_use'; timestamp = (Now); part = @{ type = 'tool'; tool = 'bash'; callID = 'call_1'; state = @{ status = 'completed'; input = @{ command = 'echo test' }; output = $Output; metadata = @{ exit = 0 } } } }
}
function ToolPermissionError {
    Emit @{ type = 'tool_use'; timestamp = (Now); part = @{ type = 'tool'; tool = 'bash'; callID = 'call_2'; state = @{ status = 'error'; input = @{ command = 'git status --short' }; error = 'The user rejected permission to use this specific tool call.' } } }
}

$mode = $env:FAKE_MODE
switch ($mode) {
    'complete' {
        StepStart
        ToolCompleted 'ok'
        StepFinish 'tool-calls'
        StepStart
        Text 'COMPLETE: bounded fake report for deterministic runner test.'
        StepFinish 'stop'
        exit 0
    }
    'quoted' {
        StepStart
        ToolCompleted 'Historical note: The user rejected permission to use this specific tool call. auto-rejecting was mentioned in a quoted document.'
        StepFinish 'tool-calls'
        StepStart
        Text 'COMPLETE: quoted historical phrase is not a live permission failure.'
        StepFinish 'stop'
        exit 0
    }
    'slow' {
        StepStart
        Start-Sleep -Seconds 3
        ToolCompleted 'ok'
        StepFinish 'tool-calls'
        StepStart
        Text 'COMPLETE: slow fake report.'
        StepFinish 'stop'
        exit 0
    }
    'permission' {
        StepStart
        ToolPermissionError
        StepFinish 'tool-calls'
        exit 0
    }
    'provider' {
        Emit @{ type = 'error'; timestamp = (Now); error = 'Provider API rate limit exceeded' }
        exit 0
    }
    'nonzero' {
        StepStart
        Text 'COMPLETE: process will exit nonzero.'
        StepFinish 'stop'
        exit 3
    }
    'nofinal' {
        StepStart
        ToolCompleted 'ok'
        StepFinish 'tool-calls'
        exit 0
    }
    'exhaustion' {
        StepStart
        Text 'Maximum steps for this agent have been reached, so I cannot continue tool operations or complete the implementation in this turn.'
        StepFinish 'stop'
        exit 0
    }
    'partial' {
        StepStart
        Text 'COMPLETE: final text is present but the event log is truncated.'
        StepFinish 'stop'
        [Console]::Out.WriteLine('{"type":"tool_use","part":')
        [Console]::Out.Flush()
        exit 0
    }
    'pipe-drain' {
        StepStart
        Text 'COMPLETE: terminal text arrives before the parent exits with an inherited pipe still open.'
        StepFinish 'stop'
        $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
        $psi = [Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = $pwsh
        $psi.Arguments = '-NoProfile -Command "Start-Sleep -Seconds 30"'
        $psi.UseShellExecute = $false
        $child = [Diagnostics.Process]::Start($psi)
        if ($env:FAKE_PIDFILE) {
            Set-Content -LiteralPath $env:FAKE_PIDFILE -Value @($PID, $child.Id)
        }
        exit 0
    }
    'timeout-tree' {
        StepStart
        [Console]::Out.WriteLine('{"type":"tool_use","part":')
        [Console]::Out.Flush()
        $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
        $child = Start-Process -FilePath $pwsh -ArgumentList @('-NoProfile', '-Command', 'Start-Sleep -Seconds 120') -PassThru -WindowStyle Hidden
        if ($env:FAKE_PIDFILE) {
            Set-Content -LiteralPath $env:FAKE_PIDFILE -Value @($PID, $child.Id)
        }
        Start-Sleep -Seconds 120
        exit 0
    }
    default {
        [Console]::Error.WriteLine("Unknown FAKE_MODE: $mode")
        exit 9
    }
}

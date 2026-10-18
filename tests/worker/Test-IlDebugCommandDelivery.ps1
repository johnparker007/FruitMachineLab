[CmdletBinding()]
param(
    [string]$MameExecutable = 'E:\Arcade\MAME0266\mame281.exe',
    [string]$RomDirectory = 'E:\Arcade\MAME0266\roms',
    [string]$OriginalRom = 'C:\Users\John\Documents\Codex\2026-10-13\help-me-set-up-a-local\outputs\mpu4\rom\a6ls.p1',
    [string]$RepairedRom,
    [string]$OutputPath,
    [string]$RunRoot,
    [ValidateRange(30,600)][int]$WallTimeoutSeconds = 240,
    [ValidateRange(30,180)][int]$IdleSeconds = 55,
    [ValidateRange(1000,30000)][int]$DeliveryBoundMs = 3000,
    [ValidateRange(1000,120000)][int]$PauseBoundMs = 60000,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if ([string]::IsNullOrWhiteSpace($RepairedRom)) { $RepairedRom = Join-Path $repo 'artifacts/deepseek/il-boot-04/build-01/edited-repaired.p1' }
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $repo 'evidence/mpu4/integrity/il-debug-delivery.json' }
$stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
if ([string]::IsNullOrWhiteSpace($RunRoot)) { $RunRoot = Join-Path $repo ('artifacts/deepseek/il-debug-polling-21/test-runs/run-' + $stamp) }
$RunRoot = [IO.Path]::GetFullPath($RunRoot)
$SourceMapPath = Join-Path $repo 'artifacts/deepseek/il-boot-04/build-01/source-map.json'
$BuildReportPath = Join-Path $repo 'artifacts/deepseek/il-boot-04/build-01/build-report.json'
$PlanPath = Join-Path $repo 'evidence/mpu4/integrity/il-natural-reachability-plan.json'
$ReplayPath = Join-Path $repo 'evidence/mpu4/skill-cash/actions.csv'
$InputLuaPath = Join-Path $repo 'evidence/mpu4/skill-cash/input.lua'
$OriginalSha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
$RepairedSha256 = '577f76bd36dfca04dfb01b5f5d0be93e16572f8617c7ca906397c98df36e5107'
$MameSha256 = '0fce5a88df4f9d9b1fbf1405812c00848036e615993780978d967da34204cb7a'
$script:PwshPath = $null
$pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -ne $pwshCommand) { $script:PwshPath = $pwshCommand.Source }

$script:Checks = 0
$script:Failures = 0
$script:OwnedProcesses = New-Object 'System.Collections.Generic.List[int]'
function Write-Pass([string]$Message) { $script:Checks++; [Console]::WriteLine("PASS: $Message") }
function Write-Fail([string]$Message) { $script:Checks++; $script:Failures++; [Console]::WriteLine("FAIL: $Message") }
function Assert-True([bool]$Condition,[string]$Message) { if ($Condition) { Write-Pass $Message } else { Write-Fail $Message } }
function Assert-Equal($Actual,$Expected,[string]$Message) { if ([string]$Actual -eq [string]$Expected) { Write-Pass $Message } else { Write-Fail "$Message (actual '$Actual', expected '$Expected')" } }
function Assert-Match([string]$Actual,[string]$Pattern,[string]$Message) { if ($Actual -match $Pattern) { Write-Pass $Message } else { Write-Fail "$Message (actual '$Actual')" } }
function Assert-AtMost([double]$Actual,[double]$Bound,[string]$Message) { if ($Actual -le $Bound) { Write-Pass "$Message ($([math]::Round($Actual,1)) ms <= $Bound ms)" } else { Write-Fail "$Message ($([math]::Round($Actual,1)) ms > $Bound ms)" } }

function Get-Sha256([string]$Path) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [IO.File]::ReadAllBytes($Path)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()
    }
    finally { $sha.Dispose() }
}

function Invoke-ChildPowerShell([string[]]$Arguments) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $text = (& powershell @Arguments 2>&1 | Out-String)
        return [ordered]@{ text = $text; exit_code = $LASTEXITCODE }
    }
    finally { $ErrorActionPreference = $previous }
}

function Read-Response([string]$Path) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Response file is missing: $Path" }
    $table = @{}
    foreach ($line in ([IO.File]::ReadAllText($Path) -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $index = $line.IndexOf('=')
        if ($index -lt 1) { throw "Response line is malformed: $line" }
        $key = $line.Substring(0,$index)
        if ($table.ContainsKey($key)) { throw "Response key is duplicated: $key" }
        $table[$key] = $line.Substring($index+1)
    }
    return $table
}

function Write-Request([string]$SessionDirectory,[int]$Sequence,[string]$Command,[int]$Node = -1,[string]$Nonce = $null,[string]$RequestId = $null) {
    $config = Get-Content -LiteralPath (Join-Path $SessionDirectory 'session-config.json') -Raw | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace($Nonce)) { $Nonce = [guid]::NewGuid().ToString('N').Substring(0,8).ToLowerInvariant() }
    if ([string]::IsNullOrWhiteSpace($RequestId)) { $RequestId = 'r' + $Sequence + '-' + $Nonce }
    $nodeText = if ($Node -ge 0) { [string]$Node } else { '' }
    $text = @(
        'protocol=il-debug-session-v1',
        ('session=' + $config.sessionId),
        ('sequence=' + $Sequence),
        ('requestId=' + $RequestId),
        ('nonce=' + $Nonce),
        ('command=' + $Command),
        ('node=' + $nodeText)
    ) -join "`n"
    $path = Join-Path $SessionDirectory ('commands/request-{0:D6}.req' -f $Sequence)
    $temp = Join-Path $SessionDirectory ('commands/.tmp-delivery-{0:D6}' -f $Sequence)
    [IO.File]::WriteAllText($temp,($text + "`n"),(New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $temp -Destination $path -ErrorAction Stop
    return [ordered]@{ sequence = $Sequence; command = $Command; path = $path; nonce = $Nonce; requestId = $RequestId }
}

function Wait-Response([string]$SessionDirectory,[int]$Sequence,[int]$BoundMs) {
    $path = Join-Path $SessionDirectory ('responses/request-{0:D6}.resp' -f $Sequence)
    $deadline = [DateTime]::UtcNow.AddMilliseconds($BoundMs)
    while (!(Test-Path -LiteralPath $path -PathType Leaf)) {
        if ([DateTime]::UtcNow -gt $deadline) { return $null }
        Start-Sleep -Milliseconds 25
    }
    return Read-Response $path
}

function Send-Command([string]$SessionDirectory,[int]$Sequence,[string]$Command,[int]$BoundMs,[int]$Node = -1) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $request = Write-Request $SessionDirectory $Sequence $Command $Node
    $response = Wait-Response $SessionDirectory $Sequence $BoundMs
    $elapsed = $watch.Elapsed.TotalMilliseconds
    return [ordered]@{
        request = $request
        response = $response
        elapsedMs = [math]::Round($elapsed,1)
        responsePath = (Join-Path $SessionDirectory ('responses/request-{0:D6}.resp' -f $Sequence))
    }
}

function Stop-OwnedProcess([int]$ProcessId) {
    if ($null -ne (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) {
        & "$env:SystemRoot\System32\taskkill.exe" /PID $ProcessId /T /F 2>&1 | Out-Null
    }
}

$launch = $null
$processId = 0
$sessionDirectory = $null
$measurements = [ordered]@{
    idleSeconds = $IdleSeconds
    deliveryBoundMs = $DeliveryBoundMs
    pauseBoundMs = $PauseBoundMs
    initialInspect = $null
    repeatedInspect = $null
    pause = $null
    pausedInspect = $null
    queuedInspect = $null
    collision = $null
    stop = $null
    idleStartUtc = $null
    idleEndUtc = $null
}
$evidence = $null
$script:FinalExit = 1
try {
    foreach ($path in @($MameExecutable,$OriginalRom,$RepairedRom,$SourceMapPath,$BuildReportPath,$PlanPath,$ReplayPath,$InputLuaPath)) {
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file is missing: $path" }
    }
    if (!(Test-Path -LiteralPath $RomDirectory -PathType Container)) { throw "Installed ROM directory is missing: $RomDirectory" }
    Assert-Equal (Get-Sha256 $MameExecutable) $MameSha256 'installed MAME SHA256 is the checked 0.281 binary'
    Assert-Equal (Get-Sha256 $OriginalRom) $OriginalSha256 'original ROM identity'
    Assert-Equal (Get-Sha256 $RepairedRom) $RepairedSha256 'repaired ROM identity'
    Assert-Match (Get-Sha256 (Join-Path $repo 'tools/Start-IlDebugSession.ps1')) '^[0-9a-f]{64}$' 'launcher SHA256 is present'
    $launcherText = [IO.File]::ReadAllText((Join-Path $repo 'tools/Start-IlDebugSession.ps1'))
    Assert-Match $launcherText "'-debugger','imgui'" '9ED9 launcher requests the imgui debugger provider'
    Assert-Match $launcherText "'-video','bgfx'" '9ED9 launcher requests the BGFX renderer required by imgui'
    Assert-Match $launcherText "'-bgfx_path'" '9ED9 launcher supplies the installed BGFX asset path'
    Assert-True ($launcherText -notmatch "'-debugger','windows'") '9ED9 launcher no longer depends on the blocking Windows debugger wait'
    Assert-True ($launcherText -notmatch "'-video','none'") '9ED9 launcher no longer requests video none'

    $sessionDirectory = Join-Path $RunRoot 'delivery-9ed9-original'
    $arguments = @('-NoProfile','-File',(Join-Path $repo 'tools/Start-IlDebugSession.ps1'),
        '-MameExecutable',$MameExecutable,'-RomDirectory',$RomDirectory,'-OriginalRom',$OriginalRom,
        '-RepairedRom',$RepairedRom,'-Variant','Original','-RunDirectory',$sessionDirectory,
        '-SecondsToRun','120','-WallTimeoutSeconds',[string]$WallTimeoutSeconds,
        '-SourceMapPath',$SourceMapPath,'-BuildReportPath',$BuildReportPath,'-PlanPath',$PlanPath,
        '-ReplayPath',$ReplayPath,'-InputLuaPath',$InputLuaPath)
    $child = Invoke-ChildPowerShell $arguments
    if ($child.exit_code -ne 0) { throw "Session launcher failed: $($child.text)" }
    $launch = $child.text | ConvertFrom-Json
    $processId = [int]$launch.process_id
    $script:OwnedProcesses.Add($processId)
    Assert-True ($processId -gt 0) 'strict-paused session launched with a process id'
    Assert-Equal $launch.ready.exec 'stop' 'session starts stopped'
    Assert-Equal $launch.ready.variant 'Original' 'session uses the original variant'
    Assert-Equal $launch.ready.map 'ok' 'source map validated'
    Assert-Equal $launch.ready.lfs 'ok' 'Lua lfs available'
    $sessionLaunch = Get-Content -LiteralPath (Join-Path $sessionDirectory 'session-launch.json') -Raw | ConvertFrom-Json
    Assert-Match $sessionLaunch.command_line '-debugger imgui' 'session command line uses imgui'
    Assert-Match $sessionLaunch.command_line '-video bgfx' 'session command line uses BGFX'
    Assert-Match $sessionLaunch.command_line '-bgfx_path' 'session command line supplies BGFX assets'
    Assert-True ($sessionLaunch.command_line -notmatch 'debugger windows') 'session command line does not use the Windows debugger'
    Assert-True ($sessionLaunch.command_line -notmatch 'video none') 'session command line does not use video none'

    $measurements.idleStartUtc = [DateTime]::UtcNow.ToString('o')
    $idleWatch = [Diagnostics.Stopwatch]::StartNew()
    while ($idleWatch.Elapsed.TotalSeconds -lt $IdleSeconds) {
        if ($null -eq (Get-Process -Id $processId -ErrorAction SilentlyContinue)) { throw 'MAME exited during the idle window' }
        $remaining = $IdleSeconds - $idleWatch.Elapsed.TotalSeconds
        if ($remaining -gt 1) { Start-Sleep -Seconds 1 } else { Start-Sleep -Milliseconds 100 }
    }
    $measurements.idleEndUtc = [DateTime]::UtcNow.ToString('o')
    Assert-True ($null -ne (Get-Process -Id $processId -ErrorAction SilentlyContinue)) 'MAME remains alive after the idle window'

    $initial = Send-Command $sessionDirectory 1 'inspect' $DeliveryBoundMs
    $measurements.initialInspect = $initial
    Assert-True ($null -ne $initial.response) 'first inspect after idle is delivered within the bound'
    Assert-AtMost $initial.elapsedMs $DeliveryBoundMs 'first inspect after idle delivery latency'
    if ($null -ne $initial.response) {
        Assert-Equal $initial.response['status'] 'error' 'initial inspect status is error'
        Assert-Equal $initial.response['errorCode'] 'wrong_phase' 'initial inspect is rejected for the strict initial phase'
        Assert-Equal $initial.response['execState'] 'stop' 'initial inspect reports stopped execution'
        Assert-Equal $initial.response['phase'] 'initial' 'initial inspect reports the initial phase'
        Assert-Equal $initial.response['pc'] '7CCF' 'initial inspect PC is the reset hold'
        Assert-Equal $initial.response['u'] '0000' 'initial inspect U is unchanged'
        Assert-Equal $initial.response['s'] '0000' 'initial inspect S is unchanged'
        Assert-Equal $initial.response['emulatedTime'] '0.000002326' 'initial inspect emulated time is unchanged'
    }
    $second = Send-Command $sessionDirectory 2 'inspect' $DeliveryBoundMs
    $measurements.repeatedInspect = $second
    Assert-True ($null -ne $second.response) 'second inspect after idle is delivered within the bound'
    Assert-AtMost $second.elapsedMs $DeliveryBoundMs 'second inspect after idle delivery latency'
    if ($null -ne $initial.response -and $null -ne $second.response) {
        foreach ($key in @('pc','u','s','emulatedTime','dataStack0','controlStack0')) {
            Assert-Equal $second.response[$key] $initial.response[$key] "repeated idle inspect keeps $key"
        }
    }

    $pause = Send-Command $sessionDirectory 3 'pause-at-mapped-node' $PauseBoundMs 0
    $measurements.pause = $pause
    Assert-True ($null -ne $pause.response) 'pause-at-mapped-node is delivered after the idle sequence'
    Assert-AtMost $pause.elapsedMs $PauseBoundMs 'pause-at-mapped-node response latency'
    if ($null -ne $pause.response) {
        Assert-Equal $pause.response['status'] 'ok' 'pause-at-mapped-node status'
        Assert-Equal $pause.response['kind'] 'paused-at-node' 'pause-at-mapped-node kind'
        Assert-Equal $pause.response['nodeIndex'] '0' 'pause-at-mapped-node resolves node 0'
        Assert-Equal $pause.response['pc'] '00FC' 'pause-at-mapped-node PC'
        Assert-Equal $pause.response['y'] '9ED9' 'pause-at-mapped-node Y'
        Assert-Equal $pause.response['execState'] 'stop' 'pause-at-mapped-node remains stopped'
    }

    $pausedInspect = Send-Command $sessionDirectory 4 'inspect' $DeliveryBoundMs
    $measurements.pausedInspect = $pausedInspect
    Assert-True ($null -ne $pausedInspect.response) 'paused inspect is delivered within the bound'
    Assert-AtMost $pausedInspect.elapsedMs $DeliveryBoundMs 'paused inspect delivery latency'
    if ($null -ne $pause.response -and $null -ne $pausedInspect.response) {
        foreach ($key in @('pc','x','y','u','s','emulatedTime','dataStack0','controlStack0')) {
            Assert-Equal $pausedInspect.response[$key] $pause.response[$key] "paused inspect keeps $key"
        }
    }

    $forgedPath = Join-Path $sessionDirectory 'responses/request-000006.resp'
    $config = Get-Content -LiteralPath (Join-Path $sessionDirectory 'session-config.json') -Raw | ConvertFrom-Json
    $forgedText = @(
        'protocol=il-debug-session-v1',
        ('session=' + $config.sessionId),
        'sequence=6',
        'requestId=r6-forged00',
        'nonce=forged00',
        'status=ok',
        'kind=forged',
        'proof=forged'
    ) -join "`n"
    [IO.File]::WriteAllText($forgedPath,($forgedText + "`n"),(New-Object System.Text.UTF8Encoding($false)))
    $collisionWatch = [Diagnostics.Stopwatch]::StartNew()
    $collisionRequest = Write-Request $sessionDirectory 6 'inspect'
    $collisionPath = Join-Path $sessionDirectory 'commands/processed-collision-000006.req'
    $collisionDeadline = [DateTime]::UtcNow.AddMilliseconds($DeliveryBoundMs)
    while (!(Test-Path -LiteralPath $collisionPath -PathType Leaf)) {
        if ([DateTime]::UtcNow -gt $collisionDeadline) { break }
        Start-Sleep -Milliseconds 25
    }
    $collisionElapsed = $collisionWatch.Elapsed.TotalMilliseconds
    $stopWatch = [Diagnostics.Stopwatch]::StartNew()
    $queued = Write-Request $sessionDirectory 7 'stop'
    $stopResponse = Wait-Response $sessionDirectory 7 $DeliveryBoundMs
    $stop = [ordered]@{ request = $queued; response = $stopResponse; elapsedMs = [math]::Round($stopWatch.Elapsed.TotalMilliseconds,1); responsePath = (Join-Path $sessionDirectory 'responses/request-000007.resp') }
    $measurements.collision = [ordered]@{ elapsedMs = [math]::Round($collisionElapsed,1); processed = (Test-Path -LiteralPath $collisionPath); forgedResponse = (Read-Response $forgedPath) }
    $measurements.queuedInspect = $collisionRequest
    $measurements.stop = $stop
    Assert-True $measurements.collision.processed 'queued forged-response collision is detected and the request is quarantined within the bound'
    Assert-AtMost $collisionElapsed $DeliveryBoundMs 'collision detection latency'
    Assert-Equal $measurements.collision.forgedResponse['nonce'] 'forged00' 'the forged response is not overwritten'
    Assert-True ($null -ne $stop.response) 'queued stop is delivered within the bound'
    Assert-AtMost $stop.elapsedMs $DeliveryBoundMs 'queued stop delivery latency'
    if ($null -ne $stop.response) {
        Assert-Equal $stop.response['status'] 'ok' 'stop status'
        Assert-Equal $stop.response['kind'] 'stopped' 'stop kind'
        Assert-Equal $stop.response['acknowledged'] 'yes' 'stop is acknowledged'
        if ($null -ne $pausedInspect.response) {
            foreach ($key in @('pc','u','s','emulatedTime')) {
                Assert-Equal $stop.response[$key] $pausedInspect.response[$key] "stop keeps the paused $key"
            }
        }
    }

    $exitDeadline = [DateTime]::UtcNow.AddSeconds(20)
    while ($null -ne (Get-Process -Id $processId -ErrorAction SilentlyContinue)) {
        if ([DateTime]::UtcNow -gt $exitDeadline) { break }
        Start-Sleep -Milliseconds 100
    }
    $exited = ($null -eq (Get-Process -Id $processId -ErrorAction SilentlyContinue))
    Assert-True $exited 'MAME exits after the stop command'
    $exitCode = $null
    $exitFile = Join-Path $sessionDirectory 'mame-exit-code.txt'
    if (Test-Path -LiteralPath $exitFile -PathType Leaf) { $exitCode = ([IO.File]::ReadAllText($exitFile)).Trim() }
    Assert-Equal $exitCode '0' 'MAME exit code is zero'
    $eventsPath = Join-Path $sessionDirectory 'events.jsonl'
    Assert-True (Test-Path -LiteralPath $eventsPath -PathType Leaf) 'event log exists'
    if (Test-Path -LiteralPath $eventsPath -PathType Leaf) {
        $eventLines = @([IO.File]::ReadAllLines($eventsPath) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        Assert-True ($eventLines.Count -gt 0) 'event log is non-empty'
        $allStrict = $true
        foreach ($line in $eventLines) { try { $null = $line | ConvertFrom-Json } catch { $allStrict = $false; break } }
        Assert-True $allStrict 'event log is strict JSONL'
    }
}
catch {
    Write-Fail ("unexpected error: " + $_.Exception.Message)
}
finally {
    if ($processId -gt 0) { Stop-OwnedProcess $processId }
    $evidence = [ordered]@{
        schemaVersion = 1
        task = 'il-debug-polling-21'
        protocol = 'il-debug-session-v1'
        status = if ($script:Failures -eq 0) { 'pass' } else { 'fail' }
        frontend = [ordered]@{
            debugger = 'imgui'
            video = 'bgfx'
            reason = 'MAME 0.281 debug_imgui::init_debugger fatalerrors unless the video provider is bgfx; its wait_for_debugger loop calls osd().update(false) and sleeps 50 ms per iteration, so emulator_info::periodic_check (and the Lua periodic callback) is entered about 20 times per second while stopped.'
            original_failure = 'The Windows debugger blocks in GetMessage with no timer; the Lua periodic callback could not be entered for 10.8-79 s while stopped.'
            bgfx_window_required = $true
            focus_behavior = 'debug_imgui::wait_for_debugger does not call set_foreground, unlike the Windows debugger first-stop path.'
        }
        idle = [ordered]@{
            seconds = $IdleSeconds
            start_utc = $measurements.idleStartUtc
            end_utc = $measurements.idleEndUtc
            process_alive_after = ($null -ne (Get-Process -Id $processId -ErrorAction SilentlyContinue))
        }
        bounds = [ordered]@{
            delivery_ms = $DeliveryBoundMs
            pause_ms = $PauseBoundMs
            idle_seconds = $IdleSeconds
        }
        measurements = $measurements
        checks = $script:Checks
        failures = $script:Failures
        run_directory = $sessionDirectory
        mame_exit_code = $exitCode
        source_hashes = [ordered]@{
            start_il_debug_session_sha256 = (Get-Sha256 (Join-Path $repo 'tools/Start-IlDebugSession.ps1'))
            il_debug_session_lua_sha256 = (Get-Sha256 (Join-Path $repo 'tools/lua/IlDebugSession.lua'))
            mame_sha256 = (Get-Sha256 $MameExecutable)
            original_rom_sha256 = (Get-Sha256 $OriginalRom)
            repaired_rom_sha256 = (Get-Sha256 $RepairedRom)
        }
        limitations = @(
            'The imgui debugger requires the BGFX renderer, so a MAME rendering window is created during a strict-paused session.',
            'BGFX asset resolution uses the installed MAME bgfx directory derived from the executable path.',
            'This regression bounds stopped command delivery latency after a 55 s idle; it does not measure every internal frontend stage.',
            'No RAM/register/ROM writes, save-state loads, CPU step keepalives, retries or extended timeouts are used.',
            'The zero-path 7982 single step and paid EE16/EE22 windows remain outside this delivery check.'
        )
    }
    if ($sessionDirectory) { $evidence.run_directory = $sessionDirectory }
    $evidencePath = $OutputPath
    if ((Test-Path -LiteralPath $evidencePath -PathType Leaf) -and !$Force) {
        Write-Fail "Evidence output already exists (use -Force): $evidencePath"
    } else {
        $tempOutput = $evidencePath + '.tmp-' + [guid]::NewGuid().ToString('N')
        [IO.File]::WriteAllText($tempOutput,(ConvertTo-Json -InputObject $evidence -Depth 20),(New-Object System.Text.UTF8Encoding($false)))
        Move-Item -LiteralPath $tempOutput -Destination $evidencePath -Force
        Write-Pass "Evidence written: $evidencePath"
    }
}

Write-Output "Test-IlDebugCommandDelivery: $($script:Checks) checks, $($script:Failures) failures"
Write-Output "RUNROOT=$RunRoot"
if ($script:Failures -gt 0) { exit 1 }
exit 0

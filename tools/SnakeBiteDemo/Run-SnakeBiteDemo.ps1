param(
    [Parameter(Mandatory=$true)][string]$OriginalRom,
    [ValidateSet('Win','Loss','Control')][string]$Mode = 'Win',
    [switch]$Manual,
    [string]$RunDirectory,
    [int]$Attempts = 1,
    [string]$RetryReason,
    [int]$EmulatedSeconds = 600,
    [int]$WallTimeoutSeconds = 300,
    [double]$ThrottleOnTime = 538.0,
    [int]$ManualSeconds = 60,
    [string]$MameExecutable = 'E:\Arcade\MAME0266\mame281.exe',
    [string]$SupportRomPath = 'E:\Arcade\MAME0266\roms',
    [string]$BgfxPath = 'E:\Arcade\MAME0266\bgfx',
    [string]$InputLua,
    [string]$BuilderScript
)
$ErrorActionPreference = 'Stop'

$ExpectedOriginalSha256 = 'EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C'
$ExpectedOriginalLength = 65536
$ExpectedRepairedSha256 = '7124269C34881B2C8CCAA577DC2EDF28957EED3E69BC2052C5D789172D3653CF'
$ExpectedPayloadBytes = 982
$KnownEntryFrame = 32630
$KnownEntryTime = 543.824470930
$EntryTimeTolerance = 0.05
$FastRatioMinimum = 2.0
$ThrottleRatioMinimum = 0.80
$ThrottleRatioMaximum = 1.20

$root = $PSScriptRoot
$fixtures = @{
    'Win'     = @{ Archive = 'win-right.csv.gz';        Sha256 = 'B5E9A91560343345C1605707FEF9F7DD4FC51CC0A978F4539FC2C78580AE1D66' }
    'Loss'    = @{ Archive = 'loss-left.csv.gz';        Sha256 = '7134FAA251472C2FD87F104D85142A2978F4C465327EE6EBBA3BFBE78BE0D0AF' }
    'Control' = @{ Archive = 'control-nopress.csv.gz';  Sha256 = 'D2BB74AFFB770FF94D2B8DD1B49E8EFADAF431A8DF0597DC5617E3864BE68E1D' }
}

function Get-Sha256Hex([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToUpperInvariant() }
    finally { $stream.Dispose(); $sha.Dispose() }
}
function Resolve-RepoRoot([string]$Start) {
    $dir = [IO.Path]::GetFullPath($Start)
    while ($dir) {
        if (Test-Path -LiteralPath (Join-Path $dir 'tools\Build-SnakeBitePlayable.ps1')) { return $dir }
        $parent = [IO.Directory]::GetParent($dir)
        if (!$parent) { break }
        $dir = $parent.FullName
    }
    return $null
}
function To-InvariantDouble([object]$Value) {
    return [double]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture)
}
function To-HexInt([string]$Value) {
    return [Convert]::ToInt32($Value, 16)
}
function Get-LastEvent($Events, [string]$Name) {
    $found = @($Events | Where-Object { $_.event -eq $Name })
    if ($found.Count -eq 0) { return $null }
    return $found[$found.Count - 1]
}
function Get-MarkerTime([string]$Path) {
    if (Test-Path -LiteralPath $Path) { return (Get-Item -LiteralPath $Path).LastWriteTimeUtc }
    return $null
}

if (!(Test-Path -LiteralPath $OriginalRom)) { throw "original ROM not found: $OriginalRom" }
if (!(Test-Path -LiteralPath $MameExecutable)) { throw "MAME executable not found: $MameExecutable" }
if (!(Test-Path -LiteralPath $SupportRomPath)) { throw "support ROM path not found: $SupportRomPath" }
if (!(Test-Path -LiteralPath $BgfxPath)) { throw "bgfx path not found: $BgfxPath" }
if ($Attempts -lt 1 -or $Attempts -gt 10) { throw 'Attempts out of range 1..10' }
if ($Attempts -gt 1 -and [string]::IsNullOrWhiteSpace($RetryReason)) {
    throw 'Attempts > 1 requires an explicit -RetryReason describing the diagnostic reason; the default is one attempt'
}
$RetryReason = if ($RetryReason) { $RetryReason } else { '' }
if ($Manual -and $ManualSeconds -lt 5) { throw 'ManualSeconds must be at least 5' }

$sourceLength = (Get-Item -LiteralPath $OriginalRom).Length
$sourceHash = Get-Sha256Hex $OriginalRom
if ($sourceLength -ne $ExpectedOriginalLength) { throw "original ROM length $sourceLength does not match expected $ExpectedOriginalLength" }
if ($sourceHash -ne $ExpectedOriginalSha256) { throw "original ROM SHA256 $sourceHash does not match expected $ExpectedOriginalSha256" }

if (!$BuilderScript) {
    $repoRoot = Resolve-RepoRoot $root
    if (!$repoRoot) { throw 'could not locate tools\Build-SnakeBitePlayable.ps1 above the package directory; pass -BuilderScript explicitly' }
    $BuilderScript = Join-Path $repoRoot 'tools\Build-SnakeBitePlayable.ps1'
}
if (!(Test-Path -LiteralPath $BuilderScript)) { throw "builder script not found: $BuilderScript" }
if (!$InputLua) { $InputLua = Join-Path $root 'input\ReplayInput.lua' }
if (!(Test-Path -LiteralPath $InputLua)) { throw "input provider not found: $InputLua" }

$packageInputHash = Get-Sha256Hex $InputLua
$observerPath = Join-Path $root 'observer\SnakeBiteObserver.lua'
if (!(Test-Path -LiteralPath $observerPath)) { throw "observer not found: $observerPath" }
$newRunHelper = Join-Path $root 'lib\New-DemoRun.ps1'
$captureHelper = Join-Path $root 'lib\Run-DemoCapture.ps1'
foreach ($required in @($newRunHelper, $captureHelper)) {
    if (!(Test-Path -LiteralPath $required)) { throw "helper not found: $required" }
}

if (!$RunDirectory) {
    $suffix = if ($Manual) { '-manual' } else { '' }
    $RunDirectory = Join-Path $root ('runs\snakebite-' + $Mode.ToLowerInvariant() + $suffix + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
$RunDirectory = [IO.Path]::GetFullPath($RunDirectory)
if (Test-Path -LiteralPath $RunDirectory) { throw "run directory already exists: $RunDirectory" }

$fixture = $fixtures[$Mode]
$fixturePath = Join-Path $root ('fixtures\' + $fixture.Archive)
if (!(Test-Path -LiteralPath $fixturePath)) { throw "fixture not found: $fixturePath" }
$buildDirectory = Join-Path $RunDirectory 'build'
New-Item -ItemType Directory -Path $RunDirectory -Force | Out-Null

Write-Output ("mode={0} manual={1}" -f $Mode, [bool]$Manual)
Write-Output ("source={0} length={1} sha256={2}" -f ([IO.Path]::GetFullPath($OriginalRom)), $sourceLength, $sourceHash)
Write-Output ("builder={0}" -f $BuilderScript)
Write-Output ("run={0}" -f $RunDirectory)
Write-Output ("fixture={0} expectedSha256={1}" -f $fixture.Archive, $fixture.Sha256)
Write-Output ("controls: Hold 2/Nudge 2 (right) catches the ball; Hold 1/Nudge 1 (left) or no movement misses")
if ($Manual) {
    Write-Output 'manual mode: replay runs only to the known feature entry, then all launcher input overrides are cleared for physical play'
}

& $BuilderScript -OriginalRom $OriginalRom -OutputDirectory $buildDirectory
$repairedRom = Join-Path $buildDirectory 'ball-repaired.p1'
$payload = Join-Path $buildDirectory 'ball-payload.bin'
if (!(Test-Path -LiteralPath $repairedRom)) { throw "builder did not produce $repairedRom" }
if (!(Test-Path -LiteralPath $payload)) { throw "builder did not produce $payload" }
$repairedHash = Get-Sha256Hex $repairedRom
$payloadLength = (Get-Item -LiteralPath $payload).Length
if ($repairedHash -ne $ExpectedRepairedSha256) { throw "repaired ROM SHA256 $repairedHash does not match expected $ExpectedRepairedSha256" }
if ($payloadLength -ne $ExpectedPayloadBytes) { throw "payload length $payloadLength does not match expected $ExpectedPayloadBytes" }
Write-Output ("repaired={0} sha256={1} payloadBytes={2}" -f $repairedRom, $repairedHash, $payloadLength)

$attemptSummaries = @()
$successDirectory = $null
$successSummary = $null

for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
    $attemptDirectory = Join-Path $RunDirectory ('attempt-{0:D2}' -f $attempt)
    Write-Output ("attempt {0}/{1}: {2}" -f $attempt, $Attempts, $attemptDirectory)
    $captureError = ''
    try {
        & $newRunHelper -RunDirectory $attemptDirectory -RomPath $repairedRom -FixturePath $fixturePath -FixtureSha256 $fixture.Sha256 -InputLua $InputLua -ObserverPath $observerPath | Out-Null
        & $captureHelper -RunDirectory $attemptDirectory -TargetY '1012' -PostY 'D003' -EmulatedSeconds $EmulatedSeconds -WallTimeoutSeconds $WallTimeoutSeconds -ThrottleOnTime $ThrottleOnTime -ManualSeconds $ManualSeconds -Manual:$Manual -Mode $Mode -MameExecutable $MameExecutable -SupportRomPath $SupportRomPath -BgfxPath $BgfxPath | Out-Null
    } catch {
        $captureError = $_.Exception.Message
        Write-Output ("attempt {0} capture error: {1}" -f $attempt, $captureError)
    }

    $eventsPath = Join-Path $attemptDirectory 'ball-events.jsonl'
    $framesPath = Join-Path $attemptDirectory 'ball-frames.csv'
    $exitPath = Join-Path $attemptDirectory 'run-exit.json'
    $events = @()
    if (Test-Path -LiteralPath $eventsPath) {
        foreach ($line in [IO.File]::ReadAllLines($eventsPath)) {
            if ($line.Trim().Length -eq 0) { continue }
            $events += ($line | ConvertFrom-Json)
        }
    }
    $entry = Get-LastEvent $events 'cave_entry'
    $body = Get-LastEvent $events 'original_body_entry'
    $return = Get-LastEvent $events 'feature_return'
    $finish = Get-LastEvent $events 'finish'
    $throttleEvent = Get-LastEvent $events 'throttle_on'
    $fastEvent = Get-LastEvent $events 'fast_start'
    $handoverEvent = Get-LastEvent $events 'handover'

    $reasons = New-Object System.Collections.Generic.List[string]
    $exit = $null
    if (Test-Path -LiteralPath $exitPath) {
        $exit = Get-Content -LiteralPath $exitPath -Raw | ConvertFrom-Json
        if ($exit.exitCode -ne 0 -or $exit.timedOut) { $reasons.Add(('nonzero or timed-out MAME exit: code={0} timedOut={1}' -f $exit.exitCode, $exit.timedOut)) }
    } else {
        $reasons.Add('run-exit.json is missing')
    }
    if ($captureError) { $reasons.Add("capture error: $captureError") }
    if (!$entry) { $reasons.Add('cave_entry event is missing') }
    if (!$body) { $reasons.Add('original_body_entry event is missing') }
    if (!$return) { $reasons.Add('feature_return event is missing') }
    if (!$finish) { $reasons.Add('finish event is missing') }
    if (!$throttleEvent) { $reasons.Add('throttle_on event is missing') }
    if (!$fastEvent) { $reasons.Add('fast_start event is missing') }

    if ($entry) {
        if ([int]$entry.frame -ne $KnownEntryFrame) { $reasons.Add(('cave entry frame {0} differs from known {1}' -f $entry.frame, $KnownEntryFrame)) }
        $entryT = To-InvariantDouble $entry.t
        if ([Math]::Abs($entryT - $KnownEntryTime) -gt $EntryTimeTolerance) { $reasons.Add(('cave entry time {0} differs from known {1} by more than {2}' -f $entry.t, $KnownEntryTime, $EntryTimeTolerance)) }
    }
    if ($entry -and $body) {
        if ($body.u -ne $entry.u -or $body.s -ne $entry.s) { $reasons.Add(('original body entry U/S {0}/{1} differs from cave entry {2}/{3}' -f $body.u, $body.s, $entry.u, $entry.s)) }
    }
    if ($entry -and $return) {
        if ($return.u -ne $entry.u) { $reasons.Add(('feature return U {0} differs from cave entry U {1}' -f $return.u, $entry.u)) }
        $returnDelta = (To-HexInt $return.s) - (To-HexInt $entry.s)
        if ($returnDelta -ne 4) { $reasons.Add(('feature return S {0} is not cave entry S {1} plus 4' -f $return.s, $entry.s)) }
    }
    if ($fastEvent -and $fastEvent.throttled -ne 'false') { $reasons.Add(('fast_start throttle readback {0} is not false' -f $fastEvent.throttled)) }
    if ($throttleEvent) {
        if ($throttleEvent.throttled -ne 'true') { $reasons.Add(('throttle_on readback {0} is not true' -f $throttleEvent.throttled)) }
        if ($throttleEvent.rate -ne '1.0' -and $throttleEvent.rate -ne '1') { $reasons.Add(('throttle_on rate readback {0} is not 1.0' -f $throttleEvent.rate)) }
    }
    if ($finish) {
        if ($finish.throttle_readback -ne 'true') { $reasons.Add(('finish throttle readback {0} is not true' -f $finish.throttle_readback)) }
        if ($finish.reason -ne 'return_window' -and !($Manual -and $finish.reason -eq 'manual_window')) {
            $reasons.Add(('finish reason {0} is not an accepted post-feature window' -f $finish.reason))
        }
    }

    $markerFast = Get-MarkerTime (Join-Path $attemptDirectory 'marker-00-fast-start')
    $markerThrottle = Get-MarkerTime (Join-Path $attemptDirectory 'marker-01-throttle-on')
    $markerFinish = Get-MarkerTime (Join-Path $attemptDirectory 'marker-05-finish')
    $fastEmulated = $null
    $fastWall = $null
    $fastRatio = $null
    $throttleEmulated = $null
    $throttleWall = $null
    $throttleRatio = $null
    $throttleFps = $null
    if ($fastEvent -and $throttleEvent -and $markerFast -and $markerThrottle) {
        $fastEmulated = (To-InvariantDouble $throttleEvent.t) - (To-InvariantDouble $fastEvent.t)
        $fastWall = ($markerThrottle - $markerFast).TotalSeconds
        if ($fastWall -gt 0) { $fastRatio = $fastEmulated / $fastWall }
        if (!$fastRatio -or $fastRatio -lt $FastRatioMinimum) { $reasons.Add(('fast segment ratio {0} is below {1}; the route did not run unthrottled' -f $fastRatio, $FastRatioMinimum)) }
    } else {
        $reasons.Add('fast timing markers are incomplete')
    }
    if ($throttleEvent -and $finish -and $markerThrottle -and $markerFinish) {
        $throttleEmulated = (To-InvariantDouble $finish.t) - (To-InvariantDouble $throttleEvent.t)
        $throttleWall = ($markerFinish - $markerThrottle).TotalSeconds
        if ($throttleWall -gt 0) {
            $throttleRatio = $throttleEmulated / $throttleWall
            $throttleFps = ([double]$finish.frame - [double]$throttleEvent.frame) / $throttleWall
        }
        if (!$throttleRatio -or $throttleRatio -lt $ThrottleRatioMinimum -or $throttleRatio -gt $ThrottleRatioMaximum) {
            $reasons.Add(('throttle segment ratio {0} is outside {1}..{2}; realtime viewing was not demonstrated' -f $throttleRatio, $ThrottleRatioMinimum, $ThrottleRatioMaximum))
        }
    } else {
        $reasons.Add('throttle timing markers are incomplete')
    }

    $decisionRows = @()
    $winRows = @()
    $lossRows = @()
    $decisionGrids = @()
    if ($entry -and $body -and (Test-Path -LiteralPath $framesPath)) {
        $allRows = @(Import-Csv -LiteralPath $framesPath)
        $entryFrameInt = [int]$entry.frame
        $bodyFrameInt = [int]$body.frame
        $decisionRows = @($allRows | Where-Object {
            $_.frame -match '^\d+$' -and [int]$_.frame -ge $entryFrameInt -and [int]$_.frame -le $bodyFrameInt -and $_.grid
        })
        $winRows = @($decisionRows | Where-Object { (($_.grid -split '/')[0]) -eq '100001' })
        $lossRows = @($decisionRows | Where-Object { (($_.grid -split '/')[7]) -eq '111111' })
        $seen = @{}
        foreach ($row in $decisionRows) {
            if (!$seen.ContainsKey($row.grid)) {
                $seen[$row.grid] = $true
                $decisionGrids += [ordered]@{ frame = [int]$row.frame; grid = $row.grid }
            }
        }
    }
    if (!$Manual) {
        if ($Mode -eq 'Win') {
            if ($winRows.Count -eq 0) { $reasons.Add('Win mode did not observe the top-corner win flash 100001') }
            if ($lossRows.Count -gt 0) { $reasons.Add('Win mode also observed the bottom-row loss flash 111111') }
        } else {
            if ($lossRows.Count -eq 0) { $reasons.Add(('{0} mode did not observe the bottom-row loss flash 111111' -f $Mode)) }
            if ($winRows.Count -gt 0) { $reasons.Add(('{0} mode also observed the top-corner win flash 100001' -f $Mode)) }
        }
    }

    $handoverInfo = $null
    $writesAfter = @()
    if ($Manual) {
        $ownershipAfter = Join-Path $attemptDirectory 'input-ownership-after-handover.json'
        $writesPath = Join-Path $attemptDirectory 'input-writes.csv'
        $cleared = $null
        if (Test-Path -LiteralPath $ownershipAfter) {
            $ownership = Get-Content -LiteralPath $ownershipAfter -Raw | ConvertFrom-Json
            $cleared = [int]$ownership.cleared
        }
        if ($entry -and (Test-Path -LiteralPath $writesPath)) {
            $writes = @(Import-Csv -LiteralPath $writesPath)
            $writesAfter = @($writes | Where-Object { $_.op -eq 'set' -and $_.frame -match '^\d+$' -and [int]$_.frame -gt [int]$entry.frame })
        }
        if (!$handoverEvent) {
            $reasons.Add('manual mode did not log a handover event')
        } else {
            if ($handoverEvent.supported -ne 'true') { $reasons.Add('manual handover is unsupported by the input provider') }
            if ($handoverEvent.ok -ne 'true') { $reasons.Add(('manual handover failed: ok={0} first={1} second={2}' -f $handoverEvent.ok, $handoverEvent.first, $handoverEvent.second)) }
        }
        if ($cleared -ne 9) { $reasons.Add(('handover cleared {0} of 9 owned fields' -f $cleared)) }
        if ($writesAfter.Count -gt 0) { $reasons.Add(('input provider wrote {0} set_value calls after handover' -f $writesAfter.Count)) }
        $handoverInfo = [ordered]@{
            requested = $true
            supported = if ($handoverEvent) { $handoverEvent.supported } else { 'missing' }
            ok = if ($handoverEvent) { $handoverEvent.ok } else { 'missing' }
            clearedFields = $cleared
            writesAfterHandover = $writesAfter.Count
            ownershipAfterFile = (Test-Path -LiteralPath $ownershipAfter)
            note = 'API clear_value handover observed; physical cabinet buttons are unverified'
        }
    }

    $summary = [ordered]@{
        task = 'feature-launch-continuation-112'
        generatedUtc = [DateTime]::UtcNow.ToString('o')
        mode = $Mode
        manual = [bool]$Manual
        attemptsRequested = $Attempts
        attempt = $attempt
        retryReason = $RetryReason
        sourceRom = [ordered]@{ path = [IO.Path]::GetFullPath($OriginalRom); length = $sourceLength; sha256 = $sourceHash }
        repairedRom = [ordered]@{ path = $repairedRom; sha256 = $repairedHash; payloadBytes = $payloadLength }
        launch = @{
            mameExecutable = $MameExecutable
            mameSha256 = (Get-Sha256Hex $MameExecutable)
            supportRomPath = $SupportRomPath
            bgfxPath = $BgfxPath
            throttleOnTime = $ThrottleOnTime
            manualSeconds = $ManualSeconds
            emulatedSeconds = $EmulatedSeconds
            wallTimeoutSeconds = $WallTimeoutSeconds
        }
        fixture = @{ archive = $fixture.Archive; expectedSha256 = $fixture.Sha256 }
        inputProvider = @{ path = ([IO.Path]::GetFullPath($InputLua)); sha256 = $packageInputHash }
        observerSha256 = (Get-Sha256Hex $observerPath)
        exit = if ($exit) { @{ exitCode = $exit.exitCode; timedOut = $exit.timedOut; wallSeconds = $exit.wallSeconds; finishReason = if ($finish) { $finish.reason } else { $null } } } else { $null }
        entry = if ($entry) { @{ frame = [int]$entry.frame; t = $entry.t; pc = $entry.pc; y = $entry.y; u = $entry.u; s = $entry.s; x = $entry.x; grid = $entry.grid; display = $entry.display } } else { $null }
        originalBodyEntry = if ($body) { @{ frame = [int]$body.frame; t = $body.t; pc = $body.pc; y = $body.y; u = $body.u; s = $body.s; grid = $body.grid } } else { $null }
        featureReturn = if ($return) { @{ frame = [int]$return.frame; t = $return.t; pc = $return.pc; y = $return.y; u = $return.u; s = $return.s; grid = $return.grid } } else { $null }
        finish = if ($finish) { @{ frame = [int]$finish.frame; t = $finish.t; reason = $finish.reason; throttleReadback = $finish.throttle_readback; speedPercent = $finish.speed_percent } } else { $null }
        timing = [ordered]@{
            fastEmulatedSeconds = $fastEmulated
            fastWallSeconds = $fastWall
            fastRatio = $fastRatio
            throttleEmulatedSeconds = $throttleEmulated
            throttleWallSeconds = $throttleWall
            throttleRatio = $throttleRatio
            throttleFramesPerSecond = $throttleFps
            acceptedRatio = ('{0}..{1}' -f $ThrottleRatioMinimum, $ThrottleRatioMaximum)
        }
        outcome = [ordered]@{
            winFlashObserved = ($winRows.Count -gt 0)
            lossFlashObserved = ($lossRows.Count -gt 0)
            winFrame = if ($winRows.Count -gt 0) { [int]$winRows[0].frame } else { $null }
            lossFrame = if ($lossRows.Count -gt 0) { [int]$lossRows[0].frame } else { $null }
            decisionGrids = $decisionGrids
            checked = !$Manual
        }
        handover = $handoverInfo
        accepted = ($reasons.Count -eq 0)
        reasons = @($reasons.ToArray())
    }
    $summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $attemptDirectory 'analysis.json') -Encoding UTF8
    $attemptSummaries += $summary

    if ($reasons.Count -eq 0) {
        $successDirectory = $attemptDirectory
        $successSummary = $summary
        Write-Output ("attempt {0} accepted" -f $attempt)
        break
    }
    Write-Output ("attempt {0} rejected: {1}" -f $attempt, (($reasons.ToArray()) -join '; '))
    Write-Output ("private evidence kept at {0}" -f $attemptDirectory)
}

if (!$successDirectory) {
    throw ("no attempt was accepted; all attempt directories are preserved under {0}. No automatic retry is performed; rerun with -Attempts N -RetryReason <diagnostic> only if a retry is explicitly justified." -f $RunDirectory)
}

$successSummary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $RunDirectory 'summary.json') -Encoding UTF8
Write-Output ''
Write-Output ("SUCCESS mode={0} manual={1}" -f $Mode, [bool]$Manual)
Write-Output ("sourceSha256={0}" -f $sourceHash)
Write-Output ("repairedSha256={0} payloadBytes={1}" -f $repairedHash, $payloadLength)
Write-Output ("run={0}" -f $successDirectory)
Write-Output ("exitCode={0} wallSeconds={1} finishReason={2}" -f $successSummary.exit.exitCode, $successSummary.exit.wallSeconds, $successSummary.exit.finishReason)
Write-Output ("entry frame={0} t={1} u={2} s={3}" -f $successSummary.entry.frame, $successSummary.entry.t, $successSummary.entry.u, $successSummary.entry.s)
Write-Output ("body  frame={0} t={1} u={2} s={3}" -f $successSummary.originalBodyEntry.frame, $successSummary.originalBodyEntry.t, $successSummary.originalBodyEntry.u, $successSummary.originalBodyEntry.s)
Write-Output ("return frame={0} t={1} u={2} s={3}" -f $successSummary.featureReturn.frame, $successSummary.featureReturn.t, $successSummary.featureReturn.u, $successSummary.featureReturn.s)
Write-Output ("timing fast {0:N3}s emulated / {1:N3}s wall (x{2:N2}); throttle {3:N3}s emulated / {4:N3}s wall (x{5:N3}, {6:N1} fps)" -f $successSummary.timing.fastEmulatedSeconds, $successSummary.timing.fastWallSeconds, $successSummary.timing.fastRatio, $successSummary.timing.throttleEmulatedSeconds, $successSummary.timing.throttleWallSeconds, $successSummary.timing.throttleRatio, $successSummary.timing.throttleFramesPerSecond)
if (!$Manual) {
    Write-Output ("outcome winFlash={0} lossFlash={1}" -f $successSummary.outcome.winFlashObserved, $successSummary.outcome.lossFlashObserved)
} else {
    Write-Output ("handover cleared={0} writesAfterHandover={1} (physical play unverified)" -f $successSummary.handover.clearedFields, $successSummary.handover.writesAfterHandover)
}
Write-Output ("input bindings: {0}" -f (Join-Path $successDirectory 'input-bindings.txt'))
Write-Output ("summary: {0}" -f (Join-Path $RunDirectory 'summary.json'))

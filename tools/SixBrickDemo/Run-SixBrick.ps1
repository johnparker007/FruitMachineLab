param(
    [Parameter(Mandatory=$true)][string]$OriginalRom,
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [ValidateSet('AllClear','Miss','Manual')][string]$Mode = 'AllClear',
    [string]$MameExecutable = 'E:\Arcade\MAME0266\mame281.exe',
    [string]$SupportRomPath = 'E:\Arcade\MAME0266\roms',
    [string]$BgfxPath = 'E:\Arcade\MAME0266\bgfx',
    [string]$FixturePath,
    [string]$ExpectedRepairedSha256 = 'C0F40BF86311773824BF8A6DDA21EA8DE0C7E1169DAE1142DDF97641EC190F9E',
    [int]$ExpectedPayloadBytes = 888,
    [int]$EmulatedSeconds = 650,
    [int]$WallTimeoutSeconds = 300,
    [int]$ManualSeconds = 90,
    [int]$Attempts = 1
)
$ErrorActionPreference = 'Stop'

$ExpectedOriginalSha256 = 'EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C'
$ExpectedOriginalLength = 65536
$KnownEntryFrame = 32630
$KnownEntryTime = 543.824470930
$EntryTimeTolerance = 0.05
$root = $PSScriptRoot
if (!$FixturePath) { $FixturePath = Join-Path $root 'fixtures\control-nopress.csv.gz' }
$builderScript = [IO.Path]::GetFullPath((Join-Path $root 'builder\Build-SixBrick.ps1'))
$inputLua = Join-Path $root 'input\AutoPaddle.lua'
$observerPath = Join-Path $root 'observer\SixBrickObserver.lua'
$newRunHelper = Join-Path $root 'lib\New-DemoRun.ps1'
$captureHelper = Join-Path $root 'lib\Run-DemoCapture.ps1'

function Get-Sha256Hex([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToUpperInvariant() }
    finally { $stream.Dispose(); $sha.Dispose() }
}
function Get-GzipContentSha256Hex([string]$Path) {
    $input = [IO.File]::OpenRead($Path)
    $gzip = $null
    $memory = New-Object IO.MemoryStream
    try {
        $gzip = New-Object IO.Compression.GzipStream($input, [IO.Compression.CompressionMode]::Decompress)
        $gzip.CopyTo($memory)
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($memory.ToArray()))).Replace('-','').ToUpperInvariant() }
        finally { $sha.Dispose() }
    }
    finally {
        $memory.Dispose()
        if ($gzip) { $gzip.Dispose() }
        $input.Dispose()
    }
}
function To-InvariantDouble([object]$Value) {
    return [double]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture)
}
function Get-LastEvent($Events, [string]$Name) {
    $found = @($Events | Where-Object { $_.event -eq $Name })
    if ($found.Count -eq 0) { return $null }
    return $found[$found.Count - 1]
}
function Get-Row([string]$Grid, [int]$Row) {
    if (!$Grid) { return '' }
    $parts = $Grid -split '/'
    if ($parts.Count -ne 8) { return '' }
    return $parts[$Row]
}

foreach ($required in @($OriginalRom, $MameExecutable, $SupportRomPath, $BgfxPath, $builderScript, $inputLua, $observerPath, $newRunHelper, $captureHelper, $FixturePath)) {
    if (!(Test-Path -LiteralPath $required)) { throw "required path not found: $required" }
}
if ($Attempts -ne 1) { throw 'this package intentionally supports one attempt only' }
$sourceLength = (Get-Item -LiteralPath $OriginalRom).Length
$sourceHash = Get-Sha256Hex $OriginalRom
if ($sourceLength -ne $ExpectedOriginalLength) { throw "original ROM length $sourceLength does not match $ExpectedOriginalLength" }
if ($sourceHash -ne $ExpectedOriginalSha256) { throw "original ROM SHA256 $sourceHash does not match $ExpectedOriginalSha256" }

$RunDirectory = [IO.Path]::GetFullPath($RunDirectory)
if (Test-Path -LiteralPath $RunDirectory) { throw "run directory already exists: $RunDirectory" }
$fixtureArchiveHash = Get-Sha256Hex $FixturePath
$fixtureHash = Get-GzipContentSha256Hex $FixturePath
$buildDirectory = Join-Path $RunDirectory 'build'
New-Item -ItemType Directory -Path $RunDirectory -Force | Out-Null

Write-Output ("mode={0} sourceSha256={1}" -f $Mode, $sourceHash)
& $builderScript -OriginalRom $OriginalRom -OutputDirectory $buildDirectory
$repairedRom = Join-Path $buildDirectory 'sixbrick-repaired.p1'
$payload = Join-Path $buildDirectory 'sixbrick-payload.bin'
if (!(Test-Path -LiteralPath $repairedRom)) { throw "builder did not produce $repairedRom" }
if (!(Test-Path -LiteralPath $payload)) { throw "builder did not produce $payload" }
$repairedHash = Get-Sha256Hex $repairedRom
$payloadLength = (Get-Item -LiteralPath $payload).Length
if ($ExpectedRepairedSha256 -and $repairedHash -ne $ExpectedRepairedSha256.ToUpperInvariant()) {
    throw "repaired ROM SHA256 $repairedHash does not match expected $ExpectedRepairedSha256"
}
if ($ExpectedPayloadBytes -and $payloadLength -ne $ExpectedPayloadBytes) {
    throw "payload length $payloadLength does not match expected $ExpectedPayloadBytes"
}
Write-Output ("repaired={0} sha256={1} payloadBytes={2}" -f $repairedRom, $repairedHash, $payloadLength)

$attemptDirectory = Join-Path $RunDirectory 'attempt-01'
$autoPaddle = $Mode -eq 'AllClear'
$manual = $Mode -eq 'Manual'
& $newRunHelper -RunDirectory $attemptDirectory -RomPath $repairedRom -FixturePath $FixturePath -FixtureSha256 $fixtureHash -InputLua $inputLua -ObserverPath $observerPath | Out-Null
& $captureHelper -RunDirectory $attemptDirectory -TargetY '1012' -PostY 'D086' -EmulatedSeconds $EmulatedSeconds -WallTimeoutSeconds $WallTimeoutSeconds -ThrottleOnTime 538.0 -ManualSeconds $ManualSeconds -Manual:$manual -AutoPaddle:$autoPaddle -AutoFrom 32630 -MaxFrames 46000 -Mode $Mode -MameExecutable $MameExecutable -SupportRomPath $SupportRomPath -BgfxPath $BgfxPath | Out-Null

$eventsPath = Join-Path $attemptDirectory 'ball-events.jsonl'
$framesPath = Join-Path $attemptDirectory 'ball-frames.csv'
$masksPath = Join-Path $attemptDirectory 'mask-events.csv'
$exitPath = Join-Path $attemptDirectory 'run-exit.json'
$events = @()
if (Test-Path -LiteralPath $eventsPath) {
    foreach ($line in [IO.File]::ReadAllLines($eventsPath)) {
        if ($line.Trim().Length -eq 0) { continue }
        $events += ($line | ConvertFrom-Json)
    }
}
$entry = Get-LastEvent $events 'cave_entry'
$win = Get-LastEvent $events 'win_state'
$loss = Get-LastEvent $events 'loss_state'
$body = Get-LastEvent $events 'original_body_entry'
$return = Get-LastEvent $events 'feature_return'
$finish = Get-LastEvent $events 'finish'
$throttleEvent = Get-LastEvent $events 'throttle_on'
$fastEvent = Get-LastEvent $events 'fast_start'
$handover = Get-LastEvent $events 'handover'

$reasons = New-Object System.Collections.Generic.List[string]
$exit = $null
if (Test-Path -LiteralPath $exitPath) {
    $exit = Get-Content -LiteralPath $exitPath -Raw | ConvertFrom-Json
    if ($exit.exitCode -ne 0 -or $exit.timedOut) { $reasons.Add(('nonzero or timed-out MAME exit: code={0} timedOut={1}' -f $exit.exitCode, $exit.timedOut)) }
} else { $reasons.Add('run-exit.json is missing') }
foreach ($pair in @(@('fast_start',$fastEvent),@('throttle_on',$throttleEvent),@('cave_entry',$entry),@('original_body_entry',$body),@('feature_return',$return),@('finish',$finish))) {
    if (!$pair[1]) { $reasons.Add(($pair[0] + ' event is missing')) }
}
if ($fastEvent -and $fastEvent.throttled -ne 'false') { $reasons.Add('fast_start throttle readback is not false') }
if ($throttleEvent) {
    if ($throttleEvent.throttled -ne 'true') { $reasons.Add('throttle_on readback is not true') }
    if ($throttleEvent.rate -ne '1.0' -and $throttleEvent.rate -ne '1') { $reasons.Add('throttle_on rate is not 1.0') }
}
if ($entry) {
    if ([int]$entry.frame -ne $KnownEntryFrame) { $reasons.Add(('cave entry frame {0} differs from {1}' -f $entry.frame, $KnownEntryFrame)) }
    if ([Math]::Abs((To-InvariantDouble $entry.t) - $KnownEntryTime) -gt $EntryTimeTolerance) { $reasons.Add('cave entry time differs from the known route') }
}
if ($entry -and $return -and ($entry.saved02fe -ne $return.saved02fe -or $entry.saved0300 -ne $return.saved0300)) { $reasons.Add('original 02FE/0300 words were not restored') }
if ($return) {
    if ($return.u -ne '0672') { $reasons.Add('feature return U is not 0672') }
    if ($return.s -ne '079E') { $reasons.Add('feature return S is not 079E') }
    if ([int]$return.c9 -ne 0) { $reasons.Add('feature return C9 is not 0') }
    if ($entry -and $body -and $return.s -ne '079E') { $reasons.Add('return is not balanced at S=079E') }
}
if ($finish) {
    if ($finish.throttle_readback -ne 'true') { $reasons.Add('finish throttle readback is not true') }
    if ($Mode -ne 'Manual' -and $finish.reason -ne 'return_window') { $reasons.Add('finish reason is not return_window') }
}

$allRows = @()
$entryFrameInt = if ($entry) { [int]$entry.frame } else { 0 }
if (Test-Path -LiteralPath $framesPath) { $allRows = @(Import-Csv -LiteralPath $framesPath) }
$firstSix = $allRows | Where-Object { [int]$_.frame -ge $entryFrameInt -and (Get-Row $_.grid 0) -eq '111111' } | Select-Object -First 1
$firstFlash = $allRows | Where-Object { [int]$_.frame -ge $entryFrameInt -and (Get-Row $_.grid 0) -eq '100001' } | Select-Object -First 1
$firstBottomFlash = $allRows | Where-Object { [int]$_.frame -ge $entryFrameInt -and (Get-Row $_.grid 7) -eq '111111' } | Select-Object -First 1
$maskEvents = @()
if (Test-Path -LiteralPath $masksPath) {
    $maskEvents = @(Import-Csv -LiteralPath $masksPath | Where-Object { $_.u2 -match '^[0-9A-Fa-f]{4}$' })
}
$maskSequence = @($maskEvents | ForEach-Object { $_.u2 })
$hasAllSix = $null -ne $firstSix
if (!$hasAllSix) { $reasons.Add('the initial six-brick top row 111111 was not observed') }

if ($Mode -eq 'AllClear') {
    if (!$win) { $reasons.Add('win_state event is missing') }
    if ($loss) { $reasons.Add('a loss_state event was observed in AllClear mode') }
    if ($win) {
        if ($win.u0 -ne '0000') { $reasons.Add(('win_state mask cell u0 is {0}, expected 0000' -f $win.u0)) }
        if ([int]$win.c9 -ne 5) { $reasons.Add('win_state C9 is not 5') }
    }
    if ($maskSequence.Count -lt 6) { $reasons.Add(('only {0} pre-win mask samples were observed; expected 003F plus five reductions' -f $maskSequence.Count)) }
    if ($maskSequence.Count -gt 0) {
        if ($maskSequence[0] -ne '003F') { $reasons.Add('first observed six-brick mask is not 003F') }
        if ($maskSequence[$maskSequence.Count - 1] -ne '0001') { $reasons.Add('last pre-win observed mask is not 0001') }
        foreach ($m in $maskSequence) {
            $value = [Convert]::ToInt32($m, 16)
            if (($value -band 0xFFC0) -ne 0) { $reasons.Add(('mask {0} contains bits outside the six-brick mask' -f $m)); break }
        }
    }
    if (!$firstFlash) { $reasons.Add('the 100001 win flash was not observed') }
    if ($firstFlash -and $win -and [int]$firstFlash.frame -lt [int]$win.frame) { $reasons.Add('win flash appeared before the mask-zero win state') }
} elseif ($Mode -eq 'Miss') {
    if (!$loss) { $reasons.Add('loss_state event is missing') }
    if ($win) { $reasons.Add('a win_state event was observed in Miss mode') }
    if ($loss) {
        if ($loss.u2 -ne '003F') { $reasons.Add(('loss_state mask u2 is {0}, expected 003F' -f $loss.u2)) }
        if ([int]$loss.c9 -ne 5) { $reasons.Add('loss_state C9 is not 5') }
    }
    if (!$firstBottomFlash) { $reasons.Add('the 111111 bottom-row loss flash was not observed') }
} else {
    if (!$handover) { $reasons.Add('manual handover event is missing') }
    if ($handover -and ($handover.supported -ne 'true' -or $handover.ok -ne 'true')) { $reasons.Add('manual handover was not supported/ok') }
    $ownershipAfter = Join-Path $attemptDirectory 'input-ownership-after-handover.json'
    $cleared = $null
    if (Test-Path -LiteralPath $ownershipAfter) {
        $cleared = [int]((Get-Content -LiteralPath $ownershipAfter -Raw | ConvertFrom-Json).cleared)
    }
    if ($cleared -ne 9) { $reasons.Add(('handover cleared {0} of 9 owned fields' -f $cleared)) }
    $writesAfter = 0
    $writesPath = Join-Path $attemptDirectory 'input-writes.csv'
    if ($handover -and (Test-Path -LiteralPath $writesPath)) {
        $writes = @(Import-Csv -LiteralPath $writesPath)
        $writesAfter = @($writes | Where-Object { $_.op -eq 'set' -and $_.frame -match '^\d+$' -and [int]$_.frame -gt [int]$handover.frame }).Count
    }
    if ($writesAfter -gt 0) { $reasons.Add(('input provider wrote {0} set_value calls after handover' -f $writesAfter)) }
}

$summary = [ordered]@{
    task = 'feature-six-brick-final-continuation-116'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    mode = $Mode
    accepted = ($reasons.Count -eq 0)
    reasons = @($reasons.ToArray())
    sourceRom = [ordered]@{ path = [IO.Path]::GetFullPath($OriginalRom); length = $sourceLength; sha256 = $sourceHash }
    repairedRom = [ordered]@{ path = $repairedRom; sha256 = $repairedHash; payloadBytes = $payloadLength }
    fixture = [ordered]@{ path = [IO.Path]::GetFullPath($FixturePath); archiveSha256 = $fixtureArchiveHash; replaySha256 = $fixtureHash }
    launch = @{
        mameExecutable = $MameExecutable
        mameSha256 = (Get-Sha256Hex $MameExecutable)
        emulatedSeconds = $EmulatedSeconds
        wallTimeoutSeconds = $WallTimeoutSeconds
        throttleOnTime = 538.0
        manualSeconds = $ManualSeconds
    }
    exit = if ($exit) { @{ exitCode = $exit.exitCode; timedOut = $exit.timedOut; wallSeconds = $exit.wallSeconds } } else { $null }
    entry = if ($entry) { @{ frame = [int]$entry.frame; t = $entry.t; u = $entry.u; s = $entry.s; c9 = [int]$entry.c9; grid = $entry.grid } } else { $null }
    winState = if ($win) { @{ frame = [int]$win.frame; t = $win.t; u = $win.u; u0 = $win.u0; u2 = $win.u2; c9 = [int]$win.c9; grid = $win.grid } } else { $null }
    lossState = if ($loss) { @{ frame = [int]$loss.frame; t = $loss.t; u = $loss.u; u0 = $loss.u0; u2 = $loss.u2; c9 = [int]$loss.c9; grid = $loss.grid } } else { $null }
    originalBodyEntry = if ($body) { @{ frame = [int]$body.frame; t = $body.t; u = $body.u; s = $body.s; c9 = [int]$body.c9 } } else { $null }
    featureReturn = if ($return) { @{ frame = [int]$return.frame; t = $return.t; u = $return.u; s = $return.s; c9 = [int]$return.c9 } } else { $null }
    finish = if ($finish) { @{ frame = [int]$finish.frame; t = $finish.t; reason = $finish.reason; throttleReadback = $finish.throttle_readback } } else { $null }
    observations = [ordered]@{
        firstSixBrickTop = if ($firstSix) { @{ frame = [int]$firstSix.frame; t = $firstSix.t; grid = $firstSix.grid } } else { $null }
        firstWinFlashTop = if ($firstFlash) { @{ frame = [int]$firstFlash.frame; t = $firstFlash.t; grid = $firstFlash.grid } } else { $null }
        firstLossFlashBottom = if ($firstBottomFlash) { @{ frame = [int]$firstBottomFlash.frame; t = $firstBottomFlash.t; grid = $firstBottomFlash.grid } } else { $null }
        maskSequence = $maskSequence
        maskEvents = $maskEvents
    }
    handover = if ($handover) { @{ supported = $handover.supported; ok = $handover.ok; cleared = $cleared; writesAfterHandover = $writesAfter } } else { $null }
}
$summaryPath = Join-Path $attemptDirectory 'analysis.json'
$summary | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
$summary | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $RunDirectory 'summary.json') -Encoding UTF8

Write-Output ("accepted={0}" -f $summary.accepted)
if ($reasons.Count -gt 0) { Write-Output ('reasons=' + ($reasons -join ' | ')) }
Write-Output ("entry frame={0} t={1} u={2} s={3}" -f $summary.entry.frame, $summary.entry.t, $summary.entry.u, $summary.entry.s)
if ($win) { Write-Output ("win frame={0} maskCell={1} grid={2}" -f $win.frame, $win.u0, $win.grid) }
if ($loss) { Write-Output ("loss frame={0} mask={1} grid={2}" -f $loss.frame, $loss.u2, $loss.grid) }
Write-Output ("return frame={0} u={1} s={2} c9={3}" -f $summary.featureReturn.frame, $summary.featureReturn.u, $summary.featureReturn.s, $summary.featureReturn.c9)
Write-Output ("summary={0}" -f $summaryPath)
if ($reasons.Count -gt 0) { throw 'the run did not satisfy the package checks' }

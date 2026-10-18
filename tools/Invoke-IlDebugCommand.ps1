[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$SessionDirectory,
    [Parameter(Mandatory=$true)][ValidateSet('pause-at-mapped-node','inspect','step-one-IL-node','resume-to-supported-boundary','stop')][string]$Command,
    [ValidateRange(0,4)][int]$Node = -1,
    [ValidateRange(1,600)][int]$TimeoutSeconds = 120
)
$ErrorActionPreference = 'Stop'

$script:DcProtocol = 'il-debug-session-v1'
$sessionDir = [IO.Path]::GetFullPath($SessionDirectory)
$configPath = Join-Path $sessionDir 'session-config.json'
$launchPath = Join-Path $sessionDir 'session-launch.json'
$commandsDir = Join-Path $sessionDir 'commands'
$responsesDir = Join-Path $sessionDir 'responses'
$protocolDir = Join-Path $sessionDir 'protocol'
foreach ($path in @($configPath,$launchPath)) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Session file is missing: $path" }
}
foreach ($path in @($commandsDir,$responsesDir,$protocolDir)) {
    if (!(Test-Path -LiteralPath $path -PathType Container)) { throw "Session directory is missing: $path" }
}
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$launch = Get-Content -LiteralPath $launchPath -Raw | ConvertFrom-Json
if ($config.schemaVersion -ne 1) { throw 'Session schemaVersion is not 1' }
if ($config.protocol -ne $script:DcProtocol) { throw 'Session protocol mismatch' }
if ($config.sessionId -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') { throw 'Session ID is malformed' }
if ($launch.sessionId -ne $config.sessionId) { throw 'Launch record session ID mismatch' }
$process = Get-Process -Id ([int]$launch.process_id) -ErrorAction SilentlyContinue
if ($null -eq $process) { throw "Session process $($launch.process_id) is not running" }

if ($Command -eq 'pause-at-mapped-node') {
    if ($Node -lt 0) { throw 'pause-at-mapped-node requires -Node 0..4' }
} elseif ($Node -ge 0) {
    throw "$Command does not accept -Node"
}

# Serialize sequence allocation and request publication. The lock is held until
# the request file is visible so a higher sequence cannot overtake a lower one.
$lockPath = Join-Path $protocolDir 'sequence.lock'
$sequencePath = Join-Path $protocolDir 'sequence.txt'
$lock = $null
$requestPath = $null
$sequence = $null
$nonce = $null
$requestId = $null
try {
    $lock = [IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $sequence = 0
    if (Test-Path -LiteralPath $sequencePath -PathType Leaf) {
        $text = [IO.File]::ReadAllText($sequencePath).Trim()
        if ($text -notmatch '^\d+$') { throw 'Sequence counter is malformed' }
        $sequence = [int]$text
    }
    $sequence++
    if ($sequence -gt 999999) { throw 'Sequence counter is exhausted' }
    $nonce = [guid]::NewGuid().ToString('N').Substring(0,8).ToLowerInvariant()
    $requestId = 'r' + $sequence + '-' + $nonce
    $requestPath = Join-Path $commandsDir ('request-{0:D6}.req' -f $sequence)
    if (Test-Path -LiteralPath $requestPath) { throw "Request file already exists: $requestPath" }
    $nodeText = if ($Command -eq 'pause-at-mapped-node') { [string]$Node } else { '' }
    $lines = @(
        ('protocol=' + $script:DcProtocol),
        ('session=' + $config.sessionId),
        ('sequence=' + $sequence),
        ('requestId=' + $requestId),
        ('nonce=' + $nonce),
        ('command=' + $Command),
        ('node=' + $nodeText)
    )
    $temp = Join-Path $commandsDir ('.tmp-' + $requestId)
    [IO.File]::WriteAllText($temp, (($lines -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $temp -Destination $requestPath -ErrorAction Stop
    [IO.File]::WriteAllText($sequencePath, [string]$sequence, (New-Object System.Text.UTF8Encoding($false)))
}
finally {
    if ($null -ne $lock) { $lock.Dispose() }
}

$responsePath = Join-Path $responsesDir ('request-{0:D6}.resp' -f $sequence)
$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
while (!(Test-Path -LiteralPath $responsePath -PathType Leaf)) {
    if ([DateTime]::UtcNow -gt $deadline) {
        Write-Output "TIMEOUT: no response for sequence $sequence after $TimeoutSeconds seconds"
        Write-Output "REQUEST=$requestPath"
        exit 2
    }
    Start-Sleep -Milliseconds 100
}

$responseText = [IO.File]::ReadAllText($responsePath)
$response = @{}
foreach ($line in ($responseText -split "`r?`n")) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $index = $line.IndexOf('=')
    if ($index -lt 1) { throw "Response line is malformed: $line" }
    $key = $line.Substring(0,$index)
    $value = $line.Substring($index+1)
    if ($response.ContainsKey($key)) { throw "Response key is duplicated: $key" }
    $response[$key] = $value
}
foreach ($key in @('protocol','session','sequence','requestId','nonce','command','status','kind','proof','acknowledged','phase')) {
    if (!$response.ContainsKey($key)) { throw "Response is missing required key: $key" }
}
if ($response['protocol'] -ne $script:DcProtocol) { throw 'Response protocol mismatch' }
if ($response['session'] -ne $config.sessionId) { throw 'Response session mismatch' }
if ([int]$response['sequence'] -ne $sequence) { throw "Response sequence mismatch (actual '$($response['sequence'])', expected '$sequence')" }
if ($response['requestId'] -ne $requestId) { throw 'Response requestId mismatch' }
if ($response['nonce'] -ne $nonce) { throw 'Response nonce mismatch; response is stale or forged' }
if ($response['command'] -ne $Command) { throw 'Response command mismatch' }

Write-Output "SESSION=$sessionDir"
Write-Output "REQUEST=$requestPath"
Write-Output "RESPONSE=$responsePath"
Write-Output $responseText.TrimEnd()

if ($response['status'] -ne 'ok') {
    Write-Output "REJECTED: $($response['errorCode']): $($response['message'])"
    exit 1
}
if ($response['acknowledged'] -ne 'yes') { throw 'Successful response is not acknowledged' }

switch ($Command) {
    'pause-at-mapped-node' {
        if ($response['kind'] -ne 'paused-at-node') { throw "Unexpected response kind: $($response['kind'])" }
        if ($response['proof'] -ne 'boundary_reached') { throw 'Pause response lacks a boundary proof' }
        if ($response['boundaryPhase'] -ne 'prefetch') { throw 'Pause response is not at a prefetch boundary' }
        if ($response['nodeIndex'] -ne [string]$Node) { throw 'Pause response node does not match the request' }
        if ($response['execState'] -ne 'stop') { throw 'Pause response does not report stopped execution' }
    }
    'inspect' {
        if ($response['kind'] -ne 'inspection') { throw "Unexpected response kind: $($response['kind'])" }
        if ($response['proof'] -ne 'stopped_read_only') { throw 'Inspect response lacks a read-only proof' }
        if ($response['stateUnchanged'] -ne 'yes') { throw 'Inspect response reports state change' }
        if (!$response.ContainsKey('timeBefore') -or !$response.ContainsKey('timeAfter')) { throw 'Inspect response lacks emulated-time readings' }
        if ([double]$response['timeBefore'] -ne [double]$response['timeAfter']) { throw 'Inspect response reports emulated-time advance' }
        if ($response['execState'] -ne 'stop') { throw 'Inspect response does not report stopped execution' }
    }
    { $_ -eq 'step-one-IL-node' -or $_ -eq 'resume-to-supported-boundary' } {
        $expectedKind = if ($Command -eq 'step-one-IL-node') { 'node-stepped' } else { 'resumed-to-boundary' }
        if ($response['kind'] -ne $expectedKind) { throw "Unexpected response kind: $($response['kind'])" }
        if ($response['proof'] -ne 'boundary_reached') { throw 'Step response lacks a boundary proof' }
        if (!$response.ContainsKey('steps') -or [int]$response['steps'] -lt 1) { throw 'Step response does not report an instruction step' }
        if (!$response.ContainsKey('toBoundaryPhase') -or [string]::IsNullOrWhiteSpace($response['toBoundaryPhase'])) { throw 'Step response lacks a target boundary phase' }
        if (!$response.ContainsKey('transitionCount') -or [int]$response['transitionCount'] -lt 1) { throw 'Step response has no observed transitions' }
        if (!$response.ContainsKey('transition.0')) { throw 'Step response lacks the first transition' }
        if ($response['execState'] -ne 'stop') { throw 'Step response does not report stopped execution' }
        if ([double]$response['timeAfter'] -le [double]$response['timeBefore']) { throw 'Step response does not report emulated-time advance' }
    }
    'stop' {
        if ($response['kind'] -ne 'stopped') { throw "Unexpected response kind: $($response['kind'])" }
        if ($response['proof'] -ne 'exit_scheduled') { throw 'Stop response lacks an exit proof' }
        if ($response['exitScheduled'] -ne 'yes') { throw 'Stop response did not schedule exit' }
    }
}
exit 0

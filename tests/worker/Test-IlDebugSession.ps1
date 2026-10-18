[CmdletBinding()]
param(
    [string]$MameExecutable = 'E:\Arcade\MAME0266\mame281.exe',
    [string]$RomDirectory = 'E:\Arcade\MAME0266\roms',
    [string]$OriginalRom = 'C:\Users\John\Documents\Codex\2026-10-13\help-me-set-up-a-local\outputs\mpu4\rom\a6ls.p1',
    [string]$RepairedRom,
    [string]$OutputPath,
    [string]$RunRoot,
    [ValidateRange(30,600)][int]$WallTimeoutSeconds = 180,
    [switch]$SkipNatural,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if ([string]::IsNullOrWhiteSpace($RepairedRom)) { $RepairedRom = Join-Path $repo 'artifacts/deepseek/il-boot-04/build-01/edited-repaired.p1' }
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $repo 'evidence/mpu4/integrity/il-debug-session.json' }
$stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
if ([string]::IsNullOrWhiteSpace($RunRoot)) { $RunRoot = Join-Path $repo ('artifacts/deepseek/il-debug-log-11/test-runs/run-' + $stamp) }
$RunRoot = [IO.Path]::GetFullPath($RunRoot)
$SourceMapPath = Join-Path $repo 'artifacts/deepseek/il-boot-04/build-01/source-map.json'
$BuildReportPath = Join-Path $repo 'artifacts/deepseek/il-boot-04/build-01/build-report.json'
$PlanPath = Join-Path $repo 'evidence/mpu4/integrity/il-natural-reachability-plan.json'
$ReplayPath = Join-Path $repo 'evidence/mpu4/skill-cash/actions.csv'
$InputLuaPath = Join-Path $repo 'evidence/mpu4/skill-cash/input.lua'
$EventJsonHelper = Join-Path $repo 'tests/worker/Test-IlEventJson.ps1'
$LegacyStep10Events = Join-Path $repo 'artifacts/deepseek/il-debug-step-10/test-runs/run-20261018-151132/natural-original/events.jsonl'
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

function Get-Sha256([string]$Path) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [IO.File]::ReadAllBytes($Path)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()
    }
    finally { $sha.Dispose() }
}

function Read-Response([string]$Path) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Response file is missing: $Path" }
    $text = [IO.File]::ReadAllText($Path)
    $table = @{}
    foreach ($line in ($text -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $index = $line.IndexOf('=')
        if ($index -lt 1) { throw "Response line is malformed: $line" }
        $key = $line.Substring(0,$index)
        $value = $line.Substring($index+1)
        if ($table.ContainsKey($key)) { throw "Response key is duplicated: $key" }
        $table[$key] = $value
    }
    return $table
}

function Get-Transitions($Response) {
    $list = New-Object 'System.Collections.Generic.List[object]'
    for ($i=0; ; $i++) {
        $key = "transition.$i"
        if (!$Response.ContainsKey($key)) { break }
        $item = @{}
        foreach ($part in ([string]$Response[$key] -split ';')) {
            $index = $part.IndexOf('=')
            if ($index -gt 0) { $item[$part.Substring(0,$index)] = $part.Substring($index+1) }
        }
        $list.Add($item)
    }
    return $list.ToArray()
}

function Wait-Response([string]$Path,[int]$TimeoutSeconds = 40) {
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
        if ([DateTime]::UtcNow -gt $deadline) { throw "Timed out waiting for response: $Path" }
        Start-Sleep -Milliseconds 100
    }
    Start-Sleep -Milliseconds 50
    return Read-Response $Path
}

function Wait-ForFile([string]$Path,[int]$TimeoutSeconds = 20) {
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
        if ([DateTime]::UtcNow -gt $deadline) { return $false }
        Start-Sleep -Milliseconds 100
    }
    return $true
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
function Invoke-EventJsonHelper([string[]]$Arguments) {
    if ([string]::IsNullOrWhiteSpace($script:PwshPath)) { throw 'pwsh with System.Text.Json is required for strict event JSON checks' }
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $text = (& $script:PwshPath @Arguments 2>&1 | Out-String)
        return [ordered]@{ text = $text; exit_code = $LASTEXITCODE }
    }
    finally { $ErrorActionPreference = $previous }
}
function Invoke-CliCommand([string]$SessionDirectory,[string]$Command,[int]$Node = -1,[int]$TimeoutSeconds = 60) {
    $arguments = @('-NoProfile','-File',(Join-Path $repo 'tools/Invoke-IlDebugCommand.ps1'),'-SessionDirectory',$SessionDirectory,'-Command',$Command,'-TimeoutSeconds',[string]$TimeoutSeconds)
    if ($Node -ge 0) { $arguments += @('-Node',[string]$Node) }
    $child = Invoke-ChildPowerShell $arguments
    $text = $child.text
    $exitCode = $child.exit_code
    $responsePath = $null
    if ($text -match 'RESPONSE=([^\r\n]+)') { $responsePath = $Matches[1].Trim() }
    $response = if ($responsePath -and (Test-Path -LiteralPath $responsePath -PathType Leaf)) { Read-Response $responsePath } else { $null }
    return [ordered]@{ exit_code = $exitCode; text = $text; response_path = $responsePath; response = $response }
}

function New-DirectRequest([string]$SessionDirectory,[int]$Sequence,[string]$Command,[string[]]$ExtraLines = @(),[string]$Nonce = $null,[string]$RequestId = $null) {
    $config = Get-Content -LiteralPath (Join-Path $SessionDirectory 'session-config.json') -Raw | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace($Nonce)) { $Nonce = [guid]::NewGuid().ToString('N').Substring(0,8).ToLowerInvariant() }
    if ([string]::IsNullOrWhiteSpace($RequestId)) { $RequestId = 'r' + $Sequence + '-' + $Nonce }
    $lines = @(
        'protocol=il-debug-session-v1',
        ('session=' + $config.sessionId),
        ('sequence=' + $Sequence),
        ('requestId=' + $RequestId),
        ('nonce=' + $Nonce),
        ('command=' + $Command),
        'node='
    )
    if ($ExtraLines.Count -gt 0) { $lines += $ExtraLines }
    return New-RawRequest $SessionDirectory $Sequence (($lines -join "`n") + "`n") 40
}

function New-RawRequest([string]$SessionDirectory,[int]$Sequence,[string]$Text,[int]$TimeoutSeconds = 40) {
    $path = Join-Path $SessionDirectory ('commands/request-{0:D6}.req' -f $Sequence)
    $temp = Join-Path $SessionDirectory ('commands/.tmp-test-{0:D6}' -f $Sequence)
    [IO.File]::WriteAllText($temp,$Text,(New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $temp -Destination $path -ErrorAction Stop
    $responsePath = Join-Path $SessionDirectory ('responses/request-{0:D6}.resp' -f $Sequence)
    return Wait-Response $responsePath $TimeoutSeconds
}

function Start-DebugSession([string]$Variant,[string]$RunDirectory) {
    $arguments = @('-NoProfile','-File',(Join-Path $repo 'tools/Start-IlDebugSession.ps1'),
        '-MameExecutable',$MameExecutable,'-RomDirectory',$RomDirectory,'-OriginalRom',$OriginalRom,
        '-RepairedRom',$RepairedRom,'-Variant',$Variant,'-RunDirectory',$RunDirectory,
        '-SecondsToRun','120','-WallTimeoutSeconds',[string]$WallTimeoutSeconds,
        '-SourceMapPath',$SourceMapPath,'-BuildReportPath',$BuildReportPath,'-PlanPath',$PlanPath,
        '-ReplayPath',$ReplayPath,'-InputLuaPath',$InputLuaPath)
    $child = Invoke-ChildPowerShell $arguments
    $text = $child.text
    if ($child.exit_code -ne 0) { throw "Session launcher failed: $text" }
    $launch = $text | ConvertFrom-Json
    $script:OwnedProcesses.Add([int]$launch.process_id)
    return $launch
}

function Wait-OwnedExit([int]$ProcessId,[int]$TimeoutSeconds = 20) {
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ($null -ne (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) {
        if ([DateTime]::UtcNow -gt $deadline) { return $false }
        Start-Sleep -Milliseconds 200
    }
    return $true
}

function Stop-OwnedProcess([int]$ProcessId) {
    if ($null -ne (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) {
        & "$env:SystemRoot\System32\taskkill.exe" /PID $ProcessId /T /F 2>&1 | Out-Null
    }
}

function Assert-SessionCommands($SessionDirectory,[string]$Variant,[string]$ExpectedOperand,[string]$ExpectedResult) {
    $pause = Invoke-CliCommand $SessionDirectory 'pause-at-mapped-node' 0 90
    Assert-Equal $pause.exit_code 0 "$Variant pause command exits zero"
    if ($null -eq $pause.response) { Write-Fail "$Variant pause has no response"; return $null }
    $p = $pause.response
    Assert-Equal $p['status'] 'ok' "$Variant pause status"
    Assert-Equal $p['kind'] 'paused-at-node' "$Variant pause kind"
    Assert-Equal $p['proof'] 'boundary_reached' "$Variant pause proof"
    Assert-Equal $p['boundaryPhase'] 'prefetch' "$Variant pause boundary phase"
    Assert-Equal $p['nodeIndex'] '0' "$Variant pause node index"
    Assert-Equal $p['pc'] '00FC' "$Variant pause PC"
    Assert-Equal $p['y'] '9ED9' "$Variant pause Y"
    Assert-Equal $p['token'] '795B' "$Variant pause token"
    Assert-Equal $p['ilOperand'] $ExpectedOperand "$Variant first IL operand"
    Assert-Equal $p['u'] '066E' "$Variant entry U"
    Assert-Equal $p['s'] '0796' "$Variant entry S"
    Assert-Equal $p['execState'] 'stop' "$Variant pause reports stopped"
    Assert-True ([double]$p['emulatedTime'] -gt 0) "$Variant pause has positive emulated time"

    $inspectA = Invoke-CliCommand $SessionDirectory 'inspect' -1 30
    $inspectB = Invoke-CliCommand $SessionDirectory 'inspect' -1 30
    Assert-Equal $inspectA.exit_code 0 "$Variant first inspect exits zero"
    Assert-Equal $inspectB.exit_code 0 "$Variant second inspect exits zero"
    if ($null -ne $inspectA.response -and $null -ne $inspectB.response) {
        $a = $inspectA.response; $b = $inspectB.response
        Assert-Equal $a['status'] 'ok' "$Variant first inspect status"
        Assert-Equal $a['proof'] 'stopped_read_only' "$Variant first inspect proof"
        Assert-Equal $a['stateUnchanged'] 'yes' "$Variant first inspect state unchanged"
        Assert-Equal $b['stateUnchanged'] 'yes' "$Variant second inspect state unchanged"
        foreach ($key in @('pc','x','y','u','s','emulatedTime','dataStack0','controlStack0')) {
            Assert-Equal $a[$key] $b[$key] "$Variant repeated inspect keeps $key"
        }
        Assert-Equal $a['pc'] $p['pc'] "$Variant inspect keeps pause PC"
        Assert-Equal $a['y'] $p['y'] "$Variant inspect keeps pause Y"
    }

    $resume = Invoke-CliCommand $SessionDirectory 'resume-to-supported-boundary' -1 30
    Assert-Equal $resume.exit_code 0 "$Variant resume to handler exits zero"
    if ($null -ne $resume.response) {
        $r = $resume.response
        Assert-Equal $r['kind'] 'resumed-to-boundary' "$Variant resume kind"
        Assert-Equal $r['toBoundaryPhase'] 'handler' "$Variant resume target phase"
        Assert-Equal $r['pc'] '795D' "$Variant resume handler PC"
        Assert-Equal $r['y'] '9EDB' "$Variant resume handler Y"
        Assert-Equal $r['x'] '795D' "$Variant resume handler X"
        Assert-True ([int]$r['steps'] -gt 0) "$Variant resume performed native steps"
        Assert-True ([double]$r['timeAfter'] -gt [double]$r['timeBefore']) "$Variant resume advanced emulated time"
        $t = @(Get-Transitions $r)
        Assert-Equal $t.Count 1 "$Variant resume observed one transition"
        if ($t.Count -ge 1) {
            Assert-Equal $t[0]['type'] 'handler' "$Variant resume transition type"
            Assert-Equal $t[0]['pc'] '795D' "$Variant resume transition PC"
            Assert-Equal $t[0]['y'] '9EDB' "$Variant resume transition Y"
        }
    }

    $steps = @()
    for ($i=0; $i -lt 5; $i++) {
        $step = Invoke-CliCommand $SessionDirectory 'step-one-IL-node' -1 30
        $steps += $step
        Assert-Equal $step.exit_code 0 "$Variant node step $i exits zero"
        if ($null -ne $step.response) {
            $s = $step.response
            Assert-Equal $s['kind'] 'node-stepped' "$Variant node step $i kind"
            Assert-Equal $s['proof'] 'boundary_reached' "$Variant node step $i proof"
            Assert-True ([int]$s['steps'] -gt 0) "$Variant node step $i performed native steps"
            Assert-True ([double]$s['timeAfter'] -gt [double]$s['timeBefore']) "$Variant node step $i advanced emulated time"
        }
    }
    if ($steps.Count -eq 5 -and ($steps | Where-Object { $null -eq $_.response }).Count -eq 0) {
        $s0=$steps[0].response; $s1=$steps[1].response; $s2=$steps[2].response; $s3=$steps[3].response; $s4=$steps[4].response
        Assert-Equal $s0['toNodeIndex'] '1' "$Variant step 0 reaches node 1"
        Assert-Equal $s0['y'] '9EDD' "$Variant step 0 Y"
        Assert-Equal $s1['toNodeIndex'] '2' "$Variant step 1 reaches node 2"
        Assert-Equal $s1['y'] '9EDF' "$Variant step 1 Y"
        Assert-Equal $s2['toNodeIndex'] '3' "$Variant step 2 reaches node 3"
        Assert-Equal $s2['y'] '9EE3' "$Variant step 2 Y"
        Assert-Equal $s3['toNodeIndex'] '4' "$Variant step 3 reaches node 4"
        Assert-Equal $s3['y'] '9EE5' "$Variant step 3 Y"
        Assert-Equal $s3['resultExpected'] $ExpectedResult "$Variant expected XOR result"
        Assert-Equal $s3['resultObserved'] $ExpectedResult "$Variant observed XOR result"
        Assert-Equal $s4['toBoundaryPhase'] 'post-return' "$Variant step 4 reaches caller continuation"
        Assert-Equal $s4['resultObserved'] $ExpectedResult "$Variant post-return result"
        Assert-Equal $s4['callerCursor'] $s4['savedCursor'] "$Variant caller cursor matches saved cursor"
        Assert-Equal ([Convert]::ToInt32($s4['postReturnS'],16)) (([Convert]::ToInt32($s4['returnS'],16)) + 2) "$Variant post-return S is PULS+2"
        Assert-Equal $s4['y'] $s4['savedCursor'] "$Variant post-return Y restores caller cursor"
        Assert-Equal $s4['postReturnToken'] '75A9' "$Variant post-return caller token"
        $t1 = @(Get-Transitions $s1); $t2 = @(Get-Transitions $s2); $t3 = @(Get-Transitions $s3); $t4 = @(Get-Transitions $s4)
        Assert-True ($t1.Count -ge 2) "$Variant step 1 records handler and prefetch"
        if ($t1.Count -ge 2) { Assert-Equal $t1[0]['pc'] '7880' "$Variant add handler PC"; Assert-Equal $t1[0]['y'] '9EDF' "$Variant add handler Y"; Assert-Equal $t1[0]['x'] '7880' "$Variant add handler X" }
        Assert-True ($t2.Count -ge 2) "$Variant step 2 records handler and prefetch"
        if ($t2.Count -ge 2) { Assert-Equal $t2[0]['pc'] '795D' "$Variant literal handler PC"; Assert-Equal $t2[0]['y'] '9EE1' "$Variant literal handler Y"; Assert-Equal $t2[0]['x'] '795D' "$Variant literal handler X" }
        Assert-True ($t3.Count -ge 2) "$Variant step 3 records handler and prefetch"
        if ($t3.Count -ge 2) { Assert-Equal $t3[0]['pc'] '7AB1' "$Variant XOR handler PC"; Assert-Equal $t3[0]['y'] '9EE5' "$Variant XOR handler Y"; Assert-Equal $t3[0]['x'] '7AB1' "$Variant XOR handler X" }
        Assert-True ($t4.Count -ge 2) "$Variant step 4 records return handler and caller"
        if ($t4.Count -ge 2) {
            Assert-Equal $t4[0]['type'] 'return-handler' "$Variant return handler type"
            Assert-Equal $t4[0]['pc'] '7931' "$Variant return handler PC"
            Assert-Equal $t4[0]['y'] '9EE7' "$Variant return handler Y"
            Assert-Equal $t4[0]['savedCursor'] $s4['savedCursor'] "$Variant return handler saved cursor"
            Assert-Equal $t4[1]['type'] 'post-return' "$Variant post-return transition type"
            Assert-Equal $t4[1]['pc'] '00FC' "$Variant post-return PC"
            Assert-Equal $t4[1]['y'] $s4['savedCursor'] "$Variant post-return Y"
        }
    }

    $noSuccessor = Invoke-CliCommand $SessionDirectory 'resume-to-supported-boundary' -1 30
    Assert-Equal $noSuccessor.exit_code 1 "$Variant post-return resume is rejected"
    if ($null -ne $noSuccessor.response) {
        Assert-Equal $noSuccessor.response['status'] 'error' "$Variant post-return resume status"
        Assert-Equal $noSuccessor.response['errorCode'] 'no_successor' "$Variant post-return resume error"
    }

    $stop = Invoke-CliCommand $SessionDirectory 'stop' -1 30
    Assert-Equal $stop.exit_code 0 "$Variant stop command exits zero"
    if ($null -ne $stop.response) {
        Assert-Equal $stop.response['status'] 'ok' "$Variant stop status"
        Assert-Equal $stop.response['kind'] 'stopped' "$Variant stop kind"
        Assert-Equal $stop.response['proof'] 'exit_scheduled' "$Variant stop proof"
    }
    return [ordered]@{ pause = $pause; inspectA = $inspectA; inspectB = $inspectB; resume = $resume; steps = $steps; noSuccessor = $noSuccessor; stop = $stop }
}

function Invoke-NaturalSession([string]$Variant,[string]$RunDirectory) {
    $launch = Start-DebugSession $Variant $RunDirectory
    $processId = [int]$launch.process_id
    try {
        $commands = Assert-SessionCommands $RunDirectory $Variant $(if ($Variant -eq 'Original') { 'FF80' } else { 'FF00' }) $(if ($Variant -eq 'Original') { '0000' } else { '0080' })
        $exited = Wait-OwnedExit $processId 20
        Assert-True $exited "$Variant MAME process exits after stop"
        $exitCodePath = Join-Path $RunDirectory 'mame-exit-code.txt'
        if (Test-Path -LiteralPath $exitCodePath -PathType Leaf) {
            Assert-Equal ([IO.File]::ReadAllText($exitCodePath).Trim()) '0' "$Variant MAME exit code is zero"
        } else { Write-Fail "$Variant MAME exit code file is missing" }
        Assert-True (!(Test-Path -LiteralPath (Join-Path $RunDirectory 'session-timeout.txt'))) "$Variant session did not hit the wall timeout"
        $stateCount = @(Get-ChildItem -LiteralPath (Join-Path $RunDirectory 'state') -Recurse -File -ErrorAction SilentlyContinue).Count
        Assert-Equal $stateCount 0 "$Variant state directory is empty"
        $runRom = Join-Path $RunDirectory 'roms/m4addr/a6ls.p1'
        $expectedSha = if ($Variant -eq 'Original') { $OriginalSha256 } else { $RepairedSha256 }
        Assert-Equal (Get-Sha256 $runRom) $expectedSha "$Variant isolated ROM is unchanged"
        $console = Get-Content -LiteralPath (Join-Path $RunDirectory 'console.txt') -Raw
        Assert-True ($console -match 'Average speed') "$Variant MAME console records an average speed"
        Assert-True ($console -notmatch 'ACCESS VIOLATION|Exception at EIP') "$Variant MAME console has no exception"
        return [ordered]@{ launch = $launch; commands = $commands; run_directory = $RunDirectory }
    }
    finally {
        Stop-OwnedProcess $processId
    }
}

function Invoke-NegativeSession([string]$RunDirectory) {
    $launch = Start-DebugSession 'Original' $RunDirectory
    $processId = [int]$launch.process_id
    $results = New-Object 'System.Collections.Generic.List[object]'
    try {
        $checks = @(
            @{ Seq = 1; Command = 'shell-exec'; Extra = @(); Expected = 'unknown_command'; Name = 'unknown command' },
            @{ Seq = 2; Command = 'inspect'; Extra = @('write=1'); Expected = 'unknown_field'; Name = 'write field' },
            @{ Seq = 3; Command = 'inspect'; Extra = @('address=1000'); Expected = 'unknown_field'; Name = 'arbitrary read address' },
            @{ Seq = 4; Command = 'inspect'; Extra = @('pc=1234'); Expected = 'unknown_field'; Name = 'injected PC state' },
            @{ Seq = 5; Command = 'step-one-IL-node'; Extra = @(); Expected = 'wrong_phase'; Name = 'step before pause' },
            @{ Seq = 6; Command = 'inspect'; Extra = @(); Expected = 'wrong_phase'; Name = 'inspect before pause' }
        )
        foreach ($check in $checks) {
            $response = New-DirectRequest $RunDirectory $check.Seq $check.Command $check.Extra
            $passed = ($response['status'] -eq 'error' -and $response['errorCode'] -eq $check.Expected)
            Assert-True $passed "negative $($check.Name) rejects with $($check.Expected)"
            $script:NegativeRecords.Add([ordered]@{ name = $check.Name; sequence = $check.Seq; command = $check.Command; expected = $check.Expected; actual = $response['errorCode']; pass = $passed })
        }
        $previousStaleResponse = Join-Path $RunDirectory 'responses/request-000005.resp'
        if (Test-Path -LiteralPath $previousStaleResponse) { Move-Item -LiteralPath $previousStaleResponse -Destination (Join-Path $RunDirectory 'responses/request-000005.first.resp') -Force }
        $stale = New-DirectRequest $RunDirectory 5 'inspect' @()
        Assert-Equal $stale['errorCode'] 'stale_sequence' 'stale sequence is rejected'
        $script:NegativeRecords.Add([ordered]@{ name='stale sequence'; sequence=5; command='inspect'; expected='stale_sequence'; actual=$stale['errorCode']; pass=($stale['errorCode'] -eq 'stale_sequence') })
        $future = New-DirectRequest $RunDirectory 20 'inspect' @()
        Assert-Equal $future['errorCode'] 'out_of_order' 'out-of-order sequence is rejected'
        $script:NegativeRecords.Add([ordered]@{ name='out-of-order sequence'; sequence=20; command='inspect'; expected='out_of_order'; actual=$future['errorCode']; pass=($future['errorCode'] -eq 'out_of_order') })
        $missing = New-RawRequest $RunDirectory 7 ("session=" + $launch.sessionId + "`nsequence=7`nrequestId=r7-deadbeef`nnonce=deadbeef`ncommand=inspect`nnode=`n") 40
        Assert-Equal $missing['errorCode'] 'missing_field' 'missing protocol is rejected'
        $script:NegativeRecords.Add([ordered]@{ name='missing protocol'; sequence=7; command='inspect'; expected='missing_field'; actual=$missing['errorCode']; pass=($missing['errorCode'] -eq 'missing_field') })
        $carriageText = "protocol=il-debug-session-v1`rsession=" + $launch.sessionId + "`nsequence=8`nrequestId=r8-deadbeef`nnonce=deadbeef`ncommand=inspect`nnode=`n"
        $carriage = New-RawRequest $RunDirectory 8 $carriageText 40
        Assert-Equal $carriage['errorCode'] 'carriage_return' 'carriage-return request is rejected'
        $script:NegativeRecords.Add([ordered]@{ name='carriage return'; sequence=8; command='inspect'; expected='carriage_return'; actual=$carriage['errorCode']; pass=($carriage['errorCode'] -eq 'carriage_return') })
        $collisionPath = Join-Path $RunDirectory 'responses/request-000009.resp'
        $forged = "protocol=il-debug-session-v1`nsession=$($launch.sessionId)`nsequence=000009`nrequestId=r9-forged00`nnonce=forged00`ncommand=inspect`nstatus=ok`nkind=inspection`nproof=stopped_read_only`nacknowledged=yes`nphase=paused`nstateUnchanged=yes`n"
        [IO.File]::WriteAllText($collisionPath,$forged,(New-Object System.Text.UTF8Encoding($false)))
        $collisionResponse = New-DirectRequest $RunDirectory 9 'inspect' @()
        $collisionMarker = Join-Path $RunDirectory 'commands/processed-collision-000009.req'
        $collisionMoved = Wait-ForFile $collisionMarker 20
        Assert-Equal ([IO.File]::ReadAllText($collisionPath)) $forged 'response collision does not overwrite a forged response'
        Assert-True $collisionMoved 'collision request is moved out of the command queue'
        $script:NegativeRecords.Add([ordered]@{ name='response collision'; sequence=9; command='inspect'; expected='no overwrite'; actual=($(if($collisionMoved){'moved'}else{'not moved'})); pass=$collisionMoved })
        [IO.File]::WriteAllText((Join-Path $RunDirectory 'protocol/sequence.txt'),'9',(New-Object System.Text.UTF8Encoding($false)))
        $fakePath = Join-Path $RunDirectory 'responses/request-000010.resp'
        $fake = "protocol=il-debug-session-v1`nsession=$($launch.sessionId)`nsequence=000010`nrequestId=r10-forged00`nnonce=forged00`ncommand=inspect`nstatus=ok`nkind=inspection`nproof=stopped_read_only`nacknowledged=yes`nphase=paused`nstateUnchanged=yes`n"
        [IO.File]::WriteAllText($fakePath,$fake,(New-Object System.Text.UTF8Encoding($false)))
        $falseAck = Invoke-CliCommand $RunDirectory 'inspect' -1 10
        Assert-True ($falseAck.exit_code -ne 0) 'false acknowledgment is rejected by the CLI'
        Assert-Match $falseAck.text 'requestId|nonce|mismatch' 'false acknowledgment rejection names the binding mismatch'
        $script:NegativeRecords.Add([ordered]@{ name='false acknowledgment'; sequence=10; command='inspect'; expected='request binding mismatch'; actual=('exit ' + $falseAck.exit_code); pass=($falseAck.exit_code -ne 0) })
        $falseAckMarker = Join-Path $RunDirectory 'commands/processed-collision-000010.req'
        $falseAckMoved = Wait-ForFile $falseAckMarker 20
        Assert-True $falseAckMoved 'false acknowledgment request is moved by collision handling'
        Remove-Item -LiteralPath $fakePath -Force
        $stop = Invoke-CliCommand $RunDirectory 'stop' -1 30
        Assert-Equal $stop.exit_code 0 'negative session stop exits zero'
        $exited = Wait-OwnedExit $processId 20
        Assert-True $exited 'negative session process exits after stop'
        return [ordered]@{ launch = $launch; run_directory = $RunDirectory; records = $script:NegativeRecords.ToArray() }
    }
    finally {
        Stop-OwnedProcess $processId
    }
}

function New-ResponseRecords([string]$RunDirectory) {
    $list = New-Object 'System.Collections.Generic.List[object]'
    $paths = @(Get-ChildItem -LiteralPath (Join-Path $RunDirectory 'responses') -File -Filter 'request-*.resp' | Sort-Object Name)
    foreach ($path in $paths) {
        $r = Read-Response $path.FullName
        $record = [ordered]@{
            sequence = [int]$r['sequence']
            requestId = $r['requestId']
            command = $r['command']
            status = $r['status']
            kind = $r['kind']
            proof = $r['proof']
            response_sha256 = Get-Sha256 $path.FullName
        }
        foreach ($key in @('errorCode','fromNodeIndex','toNodeIndex','fromBoundaryPhase','toBoundaryPhase','steps','transitionCount','ilNode','ilOperand','resultExpected','resultObserved','savedCursor','returnS','postReturnS','callerCursor','postReturnToken','pc','x','y','u','s','emulatedTime','timeBefore','timeAfter','stateUnchanged')) {
            if ($r.ContainsKey($key) -and ![string]::IsNullOrWhiteSpace([string]$r[$key])) { $record[$key] = $r[$key] }
        }
        $transitions = @(Get-Transitions $r)
        if ($transitions.Count -gt 0) { $record['transitions'] = $transitions }
        $list.Add($record)
    }
    return $list.ToArray()
}

function New-SessionSummary([string]$RunDirectory,[string]$Variant) {
    $config = Get-Content -LiteralPath (Join-Path $RunDirectory 'session-config.json') -Raw | ConvertFrom-Json
    $launch = Get-Content -LiteralPath (Join-Path $RunDirectory 'session-launch.json') -Raw | ConvertFrom-Json
    $metadata = Get-Content -LiteralPath (Join-Path $RunDirectory 'session-metadata.json') -Raw | ConvertFrom-Json
    $runRom = Join-Path $RunDirectory 'roms/m4addr/a6ls.p1'
    return [ordered]@{
        variant = $Variant
        session_id = $config.sessionId
        run_directory = $RunDirectory
        protocol = 'il-debug-session-v1'
        rom_sha256_before = $metadata.variant_rom.sha256
        rom_sha256_after = Get-Sha256 $runRom
        rom_unchanged = ((Get-Sha256 $runRom) -eq $metadata.variant_rom.sha256)
        source_map_sha256 = $metadata.source_map_sha256
        build_report_sha256 = $metadata.build_report_sha256
        plan_sha256 = $metadata.plan_sha256
        replay_sha256 = $metadata.replay_sha256
        mame_sha256 = $metadata.mame_sha256
        mame_version = $launch.mame_version
        process_id = [int]$launch.process_id
        mame_exit_code = if (Test-Path -LiteralPath (Join-Path $RunDirectory 'mame-exit-code.txt')) { [int](([IO.File]::ReadAllText((Join-Path $RunDirectory 'mame-exit-code.txt'))).Trim()) } else { -1 }
        session_timeout = Test-Path -LiteralPath (Join-Path $RunDirectory 'session-timeout.txt')
        state_directory_files = @(Get-ChildItem -LiteralPath (Join-Path $RunDirectory 'state') -Recurse -File -ErrorAction SilentlyContinue).Count
        responses = New-ResponseRecords $RunDirectory
        raw_hashes = [ordered]@{
            session_config = Get-Sha256 (Join-Path $RunDirectory 'session-config.json')
            session_map = Get-Sha256 (Join-Path $RunDirectory 'session-map.lua')
            session_metadata = Get-Sha256 (Join-Path $RunDirectory 'session-metadata.json')
            session_launch = Get-Sha256 (Join-Path $RunDirectory 'session-launch.json')
            variant_map = Get-Sha256 (Join-Path $RunDirectory 'variant-map.json')
            events = Get-Sha256 (Join-Path $RunDirectory 'events.jsonl')
            console = Get-Sha256 (Join-Path $RunDirectory 'console.txt')
            console_error = Get-Sha256 (Join-Path $RunDirectory 'console.err.txt')
            run_rom = Get-Sha256 $runRom
        }
    }
}

function Assert-LauncherNegative([string]$Name,[string]$RunDirectory,[hashtable]$Overrides,[string]$Pattern,[switch]$AllowExistingDirectory) {
    $parameters = [ordered]@{
        MameExecutable = $MameExecutable
        RomDirectory = $RomDirectory
        OriginalRom = $OriginalRom
        RepairedRom = $RepairedRom
        Variant = 'Original'
        RunDirectory = $RunDirectory
        SecondsToRun = '120'
        WallTimeoutSeconds = [string]$WallTimeoutSeconds
        SourceMapPath = $SourceMapPath
        BuildReportPath = $BuildReportPath
        PlanPath = $PlanPath
        ReplayPath = $ReplayPath
        InputLuaPath = $InputLuaPath
    }
    foreach ($key in $Overrides.Keys) { $parameters[$key] = $Overrides[$key] }
    $arguments = @('-NoProfile','-File',(Join-Path $repo 'tools/Start-IlDebugSession.ps1'))
    foreach ($key in $parameters.Keys) { $arguments += @(('-' + $key),[string]$parameters[$key]) }
    $child = Invoke-ChildPowerShell $arguments
    $text = $child.text
    $passed = ($child.exit_code -ne 0 -and $text -match $Pattern)
    if (!$AllowExistingDirectory) { $passed = $passed -and !(Test-Path -LiteralPath $RunDirectory) }
    Assert-True $passed "launcher negative $Name is rejected"
    return [ordered]@{ name=$Name; rejected=$passed; message=($text.Trim() -split "`r?`n")[0] }
}

function Invoke-ParseEventFile([string]$Label,[string]$EventsPath,[string]$OutputPath) {
    if (!(Test-Path -LiteralPath $EventsPath -PathType Leaf)) {
        Write-Fail "$Label events.jsonl is missing"
        return $null
    }
    Assert-True (Test-Path -LiteralPath $EventsPath -PathType Leaf) "$Label events.jsonl exists"
    $child = Invoke-EventJsonHelper @('-NoProfile','-File',$EventJsonHelper,'-Mode','Parse','-EventsPath',$EventsPath,'-OutputPath',$OutputPath)
    Assert-Equal $child.exit_code 0 "$Label strict JSONL parser exits zero"
    if ($child.exit_code -ne 0) { [Console]::WriteLine($child.text) }
    if (!(Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
        Write-Fail "$Label strict JSONL summary is missing"
        return $null
    }
    return (Get-Content -LiteralPath $OutputPath -Raw | ConvertFrom-Json)
}

function Assert-StrictEventSession([string]$Label,$ParseSummary,[string]$ExpectedVariant,[string]$ExpectedResult,[string]$SessionId) {
    Assert-True ($null -ne $ParseSummary) "$Label strict JSONL summary is present"
    if ($null -eq $ParseSummary) { return }
    Assert-True ([bool]$ParseSummary.pass) "$Label strict JSONL parse passes"
    Assert-Equal @($ParseSummary.failures).Count 0 "$Label strict JSONL parse has zero failures"
    Assert-True ([int]$ParseSummary.nonblank -gt 0) "$Label events.jsonl has nonblank records"
    Assert-Equal ([int]$ParseSummary.nonblank) ([int]$ParseSummary.recordCount) "$Label every nonblank event record parsed"
    $records = @($ParseSummary.records)
    Assert-True (($records | Where-Object { $_.event -isnot [string] }).Count -eq 0) "$Label every record names a string event"

    $ready = @($records | Where-Object { $_.event -eq 'session_ready' })
    Assert-Equal $ready.Count 1 "$Label has one session_ready event"
    if ($ready.Count -eq 1) {
        Assert-Equal $ready[0].variant $ExpectedVariant "$Label ready variant"
        Assert-Equal $ready[0].session $SessionId "$Label ready session"
        Assert-Equal $ready[0].expectedResult $ExpectedResult "$Label ready expected result"
    }
    $accepted = @($records | Where-Object { $_.event -eq 'command_accepted' })
    $responses = @($records | Where-Object { $_.event -eq 'command_response' })
    Assert-Equal $accepted.Count 11 "$Label accepted command count"
    Assert-Equal $responses.Count 11 "$Label command response count"
    Assert-Equal ([int]$ParseSummary.eventCounts.command_accepted) 11 "$Label accepted event count"
    Assert-Equal ([int]$ParseSummary.eventCounts.command_response) 11 "$Label response event count"
    $sequence = 1
    foreach ($command in @('pause-at-mapped-node','inspect','inspect','resume-to-supported-boundary','step-one-IL-node','step-one-IL-node','step-one-IL-node','step-one-IL-node','step-one-IL-node','resume-to-supported-boundary','stop')) {
        $acceptedForSequence = @($accepted | Where-Object { [int]$_.sequence -eq $sequence })
        $responseForSequence = @($responses | Where-Object { [int]$_.sequence -eq $sequence })
        Assert-Equal $acceptedForSequence.Count 1 "$Label sequence $sequence accepted once"
        Assert-Equal $responseForSequence.Count 1 "$Label sequence $sequence responded once"
        if ($acceptedForSequence.Count -eq 1 -and $responseForSequence.Count -eq 1) {
            Assert-Equal $acceptedForSequence[0].command $command "$Label sequence $sequence command"
            Assert-Equal $responseForSequence[0].command $command "$Label sequence $sequence response command"
            Assert-Equal $responseForSequence[0].requestId $acceptedForSequence[0].requestId "$Label sequence $sequence request binding"
            if ($command -eq 'resume-to-supported-boundary' -and $sequence -eq 10) {
                Assert-Equal $responseForSequence[0].status 'error' "$Label no-successor response status"
                Assert-Equal $responseForSequence[0].errorCode 'no_successor' "$Label no-successor response code"
            }
            else {
                Assert-Equal $responseForSequence[0].status 'ok' "$Label sequence $sequence response status"
                Assert-Equal $responseForSequence[0].requestId $acceptedForSequence[0].requestId "$Label sequence $sequence response requestId"
            }
        }
        $sequence++
    }
    $pauseHits = @($records | Where-Object { $_.event -eq 'pause_hit' })
    Assert-Equal $pauseHits.Count 1 "$Label pause hit count"
    if ($pauseHits.Count -eq 1) { Assert-Equal $pauseHits[0].node 0 "$Label pause hit node" }
    $resumes = @($records | Where-Object { $_.event -eq 'resume_complete' })
    Assert-Equal $resumes.Count 1 "$Label resume completion count"
    if ($resumes.Count -eq 1) { Assert-Equal $resumes[0].toPhase 'handler' "$Label resume completion phase" }
    $steps = @($records | Where-Object { $_.event -eq 'node_step_complete' })
    Assert-Equal $steps.Count 5 "$Label node step completion count"
    if ($steps.Count -eq 5) {
        $expectedTargets = @(1,2,3,4,4)
        $expectedPhases = @('prefetch','prefetch','prefetch','prefetch','post-return')
        for ($index = 0; $index -lt 5; $index++) {
            Assert-Equal $steps[$index].fromNode $index "$Label step $index from node"
            Assert-Equal $steps[$index].toNode $expectedTargets[$index] "$Label step $index to node"
            Assert-Equal $steps[$index].toPhase $expectedPhases[$index] "$Label step $index phase"
            Assert-True ([int]$steps[$index].steps -ge 1) "$Label step $index has native steps"
        }
        Assert-Equal $steps[3].resultObserved $ExpectedResult "$Label node-4 result"
        Assert-Equal $steps[4].resultObserved $ExpectedResult "$Label post-return result"
    }
    $nativeSteps = @($records | Where-Object { $_.event -eq 'native_step' })
    Assert-True ($nativeSteps.Count -ge 10) "$Label native step events"
    Assert-True (($nativeSteps | Where-Object { [string]$_.pc -notmatch '^[0-9A-F]{4}$' }).Count -eq 0) "$Label native step PCs are mapped-width hex"
    Assert-Equal @($records | Where-Object { $_.event -eq 'session_stopped' }).Count 1 "$Label session stop event"
    foreach ($forbidden in @('step_failure','pause_failure','session_timeout','response_collision','startup_failure')) {
        Assert-Equal @($records | Where-Object { $_.event -eq $forbidden }).Count 0 "$Label has no $forbidden event"
    }
}

function Assert-StrictNegativeEvents($ParseSummary) {
    Assert-True ($null -ne $ParseSummary) 'negative strict JSONL summary is present'
    if ($null -eq $ParseSummary) { return }
    Assert-True ([bool]$ParseSummary.pass) 'negative strict JSONL parse passes'
    Assert-Equal @($ParseSummary.failures).Count 0 'negative strict JSONL parse has zero failures'
    Assert-Equal ([int]$ParseSummary.nonblank) ([int]$ParseSummary.recordCount) 'negative every nonblank event record parsed'
    $records = @($ParseSummary.records)
    $responses = @($records | Where-Object { $_.event -eq 'command_response' })
    Assert-Equal $responses.Count 11 'negative command response count'
    Assert-Equal @($responses | Where-Object { $_.status -eq 'error' }).Count 10 'negative responses record the ten error responses'
    $codes = @($responses | ForEach-Object { [string]$_.errorCode })
    foreach ($code in @('unknown_command','unknown_field','wrong_phase','stale_sequence','out_of_order','missing_field','carriage_return')) {
        Assert-True ($codes -contains $code) "negative response includes $code"
    }
    Assert-Equal @($records | Where-Object { $_.event -eq 'response_collision' }).Count 2 'negative collision events'
    Assert-Equal @($records | Where-Object { $_.event -eq 'node_step_complete' }).Count 0 'negative session executed no mapped node'
    Assert-Equal @($records | Where-Object { $_.event -eq 'step_start' }).Count 0 'negative session started no step'
    Assert-Equal @($records | Where-Object { $_.event -eq 'session_stopped' }).Count 1 'negative session stop event'
}

$originalSummary = $null
$changedSummary = $null
$negativeSummary = $null
$eventJsonEvidence = $null
$launcherNegatives = New-Object 'System.Collections.Generic.List[object]'
$script:NegativeRecords = New-Object 'System.Collections.Generic.List[object]'

try {
    New-Item -ItemType Directory -Path $RunRoot -Force | Out-Null

    # Launcher identity/quota negatives. These fail before any MAME process starts.
    $negRoot = Join-Path $RunRoot 'launcher-negatives'
    New-Item -ItemType Directory -Path $negRoot -Force | Out-Null
    $wrongOriginal = Join-Path $negRoot 'wrong-original'
    $launcherNegatives.Add((Assert-LauncherNegative 'wrong original identity' $wrongOriginal @{ OriginalRom=$RepairedRom } 'SHA'))
    $wrongRepaired = Join-Path $negRoot 'wrong-repaired'
    $launcherNegatives.Add((Assert-LauncherNegative 'wrong repaired identity' $wrongRepaired @{ RepairedRom=$OriginalRom } 'SHA'))
    $staleMap = Join-Path $negRoot 'stale-map.json'
    Copy-Item -LiteralPath $SourceMapPath -Destination $staleMap
    Add-Content -LiteralPath $staleMap -Value ' '
    $staleMapRun = Join-Path $negRoot 'stale-map-run'
    $launcherNegatives.Add((Assert-LauncherNegative 'stale source map' $staleMapRun @{ SourceMapPath=$staleMap } 'Source map SHA256'))
    $staleBuild = Join-Path $negRoot 'stale-build.json'
    Copy-Item -LiteralPath $BuildReportPath -Destination $staleBuild
    Add-Content -LiteralPath $staleBuild -Value ' '
    $staleBuildRun = Join-Path $negRoot 'stale-build-run'
    $launcherNegatives.Add((Assert-LauncherNegative 'stale build report' $staleBuildRun @{ BuildReportPath=$staleBuild } 'Build report SHA256'))
    $collisionRun = Join-Path $negRoot 'existing-run'
    New-Item -ItemType Directory -Path $collisionRun -Force | Out-Null
    $launcherNegatives.Add((Assert-LauncherNegative 'existing run directory' $collisionRun @{} 'fresh create-only' -AllowExistingDirectory))
}
finally {
    foreach ($processId in $script:OwnedProcesses) { Stop-OwnedProcess $processId }
}

if (!$SkipNatural) {
    # The two natural runs are performed here so a failure still reaches cleanup.
    $originalRun = Join-Path $RunRoot 'natural-original'
    $changedRun = Join-Path $RunRoot 'natural-changed'
    $originalNatural = Invoke-NaturalSession 'Original' $originalRun
    $changedNatural = Invoke-NaturalSession 'Changed' $changedRun
    $originalSummary = New-SessionSummary $originalRun 'Original'
    $changedSummary = New-SessionSummary $changedRun 'Changed'
    Assert-Equal $originalSummary.responses.Count 11 'original session has eleven responses'
    Assert-Equal $changedSummary.responses.Count 11 'changed session has eleven responses'
    $originalPause = @($originalSummary.responses | Where-Object { $_.command -eq 'pause-at-mapped-node' })[0]
    $changedPause = @($changedSummary.responses | Where-Object { $_.command -eq 'pause-at-mapped-node' })[0]
    Assert-Equal $originalPause.ilOperand 'FF80' 'original map operand FF80'
    Assert-Equal $changedPause.ilOperand 'FF00' 'changed map operand FF00'
    Assert-Equal $originalPause.u $changedPause.u 'original/changed entry U match'
    Assert-Equal $originalPause.s $changedPause.s 'original/changed entry S match'
    Assert-Equal $originalPause.token $changedPause.token 'original/changed first token match'
    $originalNode4 = @($originalSummary.responses | Where-Object { $_.toNodeIndex -eq '4' -and $_.toBoundaryPhase -eq 'prefetch' })[0]
    $changedNode4 = @($changedSummary.responses | Where-Object { $_.toNodeIndex -eq '4' -and $_.toBoundaryPhase -eq 'prefetch' })[0]
    $originalPost = @($originalSummary.responses | Where-Object { $_.toBoundaryPhase -eq 'post-return' })[0]
    $changedPost = @($changedSummary.responses | Where-Object { $_.toBoundaryPhase -eq 'post-return' })[0]
    Assert-Equal $originalNode4.resultObserved '0000' 'original node-4 result is 0000'
    Assert-Equal $changedNode4.resultObserved '0080' 'changed node-4 result is 0080'
    Assert-Equal $originalPost.callerCursor $changedPost.callerCursor 'original/changed caller cursors match'

    $negativeRun = Join-Path $RunRoot 'negative-protocol'
    $negativeSummary = Invoke-NegativeSession $negativeRun

    Assert-True (-not [string]::IsNullOrWhiteSpace($script:PwshPath)) 'pwsh with System.Text.Json is available for strict event checks'

    $originalEvents = Invoke-ParseEventFile 'original' (Join-Path $originalRun 'events.jsonl') (Join-Path $RunRoot 'events-original.json')
    $changedEvents = Invoke-ParseEventFile 'changed' (Join-Path $changedRun 'events.jsonl') (Join-Path $RunRoot 'events-changed.json')
    $negativeEvents = Invoke-ParseEventFile 'negative' (Join-Path $negativeRun 'events.jsonl') (Join-Path $RunRoot 'events-negative.json')
    Assert-StrictEventSession 'original' $originalEvents 'Original' '0000' $originalSummary.session_id
    Assert-StrictEventSession 'changed' $changedEvents 'Changed' '0080' $changedSummary.session_id
    Assert-StrictNegativeEvents $negativeEvents

    $negativeControlOutput = Join-Path $RunRoot 'strict-json-negative-controls.json'
    $negativeControlChild = Invoke-EventJsonHelper @('-NoProfile','-File',$EventJsonHelper,'-Mode','Negative','-OutputPath',$negativeControlOutput,'-LegacyEventsPath',$LegacyStep10Events)
    Assert-Equal $negativeControlChild.exit_code 0 'strict JSON negative controls exit zero'
    Assert-True (Test-Path -LiteralPath $negativeControlOutput -PathType Leaf) 'strict JSON negative control summary exists'
    $negativeControlSummary = $null
    if (Test-Path -LiteralPath $negativeControlOutput -PathType Leaf) {
        $negativeControlSummary = Get-Content -LiteralPath $negativeControlOutput -Raw | ConvertFrom-Json
    }
    Assert-True ($null -ne $negativeControlSummary) 'strict JSON negative control summary parsed'
    if ($null -ne $negativeControlSummary) {
        Assert-True ([bool]$negativeControlSummary.pass) 'strict JSON negative controls pass'
        Assert-True ([bool]$negativeControlSummary.allRejected) 'every constructed malformed record is rejected'
        Assert-True ([bool]$negativeControlSummary.positiveAccepted) 'escaped control-character positive control is accepted'
        Assert-True ([bool]$negativeControlSummary.positiveDecoded) 'escaped control-character positive control round-trips'
        Assert-Equal ([int]$negativeControlSummary.negativeCount) 9 'strict JSON negative control count'
        Assert-True ([bool]$negativeControlSummary.legacy.pass) 'preserved step-10 trailing-comma log is rejected in full'
        Assert-Equal ([int]$negativeControlSummary.legacy.rejected) ([int]$negativeControlSummary.legacy.nonblank) 'every preserved step-10 event record is rejected'
        Assert-True ([int]$negativeControlSummary.legacy.nonblank -ge 60) 'preserved step-10 log has the expected records'
        foreach ($case in @($negativeControlSummary.cases)) {
            Assert-True ([bool]$case.rejected) "strict JSON negative control rejects $($case.name)"
        }
    }

    $serializerRun = Join-Path $RunRoot 'serializer-probe'
    $serializerOutput = Join-Path $RunRoot 'serializer-probe-summary.json'
    $serializerChild = Invoke-EventJsonHelper @('-NoProfile','-File',$EventJsonHelper,'-Mode','Serializer',
        '-SourcePath',(Join-Path $repo 'tools/lua/IlDebugSession.lua'),
        '-MameExecutable',$MameExecutable,'-RomDirectory',$RomDirectory,
        '-RunDirectory',$serializerRun,'-OutputPath',$serializerOutput,
        '-ExpectedMameSha256',$MameSha256,'-TimeoutSeconds','180')
    Assert-Equal $serializerChild.exit_code 0 'real serializer escaping probe exits zero'
    Assert-True (Test-Path -LiteralPath $serializerOutput -PathType Leaf) 'serializer escaping summary exists'
    $serializerSummary = $null
    if (Test-Path -LiteralPath $serializerOutput -PathType Leaf) {
        $serializerSummary = Get-Content -LiteralPath $serializerOutput -Raw | ConvertFrom-Json
    }
    Assert-True ($null -ne $serializerSummary) 'serializer escaping summary parsed'
    if ($null -ne $serializerSummary) {
        Assert-True ([bool]$serializerSummary.pass) 'real serializer escaping probe passes'
        Assert-Equal ([int]$serializerSummary.caseCount) 9 'serializer probe case count'
        Assert-Equal ([int]$serializerSummary.recordCount) ([int]$serializerSummary.expectedCount) 'serializer probe record count'
        Assert-True ([bool]$serializerSummary.emptyFieldRecord) 'serializer writes valid JSON for an empty field table'
        Assert-True ([bool]$serializerSummary.nilFieldRecord) 'serializer writes valid JSON for a nil field table'
        Assert-True ([bool]$serializerSummary.specialKeyRecord) 'serializer escapes special object keys'
        foreach ($case in @($serializerSummary.cases)) {
            Assert-True ([bool]$case.pass) "serializer case $($case.id) round-trips"
        }
        foreach ($key in @('quote','backslash','crlf','tab','nul')) {
            Assert-True ([bool]$serializerSummary.escapeChecks.$key) "serializer decodes escaped $key"
        }
        foreach ($key in @('hasEscapedQuote','hasEscapedBackslash','hasEscapedCrLf','hasEscapedTab','hasEscapedNul','hasEscapedUnitSeparator','hasNoRawCarriageReturn','hasNoRawTab','hasNoRawNul')) {
            Assert-True ([bool]$serializerSummary.rawChecks.$key) "serializer raw output check $key"
        }
    }
    $eventJsonEvidence = [ordered]@{
        parser = 'System.Text.Json JsonDocument with AllowTrailingCommas=false and CommentHandling=Disallow'
        helper = 'tests/worker/Test-IlEventJson.ps1'
        sessions = [ordered]@{
            original = [ordered]@{ path = $originalEvents.path; sha256 = $originalEvents.sha256; nonblank = [int]$originalEvents.nonblank; parsed = [int]$originalEvents.recordCount; failures = @($originalEvents.failures).Count }
            changed = [ordered]@{ path = $changedEvents.path; sha256 = $changedEvents.sha256; nonblank = [int]$changedEvents.nonblank; parsed = [int]$changedEvents.recordCount; failures = @($changedEvents.failures).Count }
            negative = [ordered]@{ path = $negativeEvents.path; sha256 = $negativeEvents.sha256; nonblank = [int]$negativeEvents.nonblank; parsed = [int]$negativeEvents.recordCount; failures = @($negativeEvents.failures).Count }
        }
        negative_controls = $negativeControlSummary
        serializer_probe = $serializerSummary
        prior_invalid_artifact = [ordered]@{
            path = 'artifacts/deepseek/il-debug-step-10/test-runs/run-20261018-151132/natural-original/events.jsonl'
            sha256 = $negativeControlSummary.legacy.sha256
            issue = 'Trailing comma before every closing brace; CR was discarded and other control bytes were not escaped.'
            disposition = 'Preserved unchanged as a rejected continuation input; not accepted as valid event JSON and not used in this increment.'
        }
    }
}

if ($script:Failures -eq 0 -and !$SkipNatural) {
    $evidence = [ordered]@{
        schema_version = 1
        task = 'il-debug-log-11'
        generated_utc = [DateTime]::UtcNow.ToString('o')
        classification = 'Read-only MAME 0.281 paused Lua debugger session using native single-instruction stepping and map-derived IL boundary resolution. Event logs are strict JSONL with complete string escaping. No CPU/register/RAM/ROM writes, no save-state loading and no state seeding. The OSD debugger window is used only as the stopped host; the Lua periodic callback drives the command/step state machine and is not itself an instruction boundary.'
        result_status = 'complete_bounded_paused_il_debug_session_with_strict_event_json'
        target = 'first natural 9ED9 call reached from a fresh isolated boot with the tracked physical-input replay'
        protocol = 'il-debug-session-v1'
        mame = [ordered]@{
            executable = [IO.Path]::GetFullPath($MameExecutable)
            version = $originalSummary.mame_version
            sha256 = $originalSummary.mame_sha256
            debugger = 'manager.machine.debugger and :maincpu debug interfaces under -debug'
            host = 'installed windows OSD debugger; file-based strict command protocol'
            instruction_boundary_source = 'cpu.debug:step(1) with observed stopped execution state'
            lua_instruction_callback = 'unsupported and not used'
        }
        build = [ordered]@{
            source_map_sha256 = $originalSummary.source_map_sha256
            build_report_sha256 = $originalSummary.build_report_sha256
            plan_sha256 = $originalSummary.plan_sha256
            replay_sha256 = $originalSummary.replay_sha256
            body_start = '9ED9'
            body_end_exclusive = '9EE7'
            nodes = 5
        }
        natural = [ordered]@{
            original = $originalSummary
            changed = $changedSummary
            comparison = [ordered]@{
                same_entry_u = ($originalPause.u -eq $changedPause.u)
                same_entry_s = ($originalPause.s -eq $changedPause.s)
                same_node_tokens = ($originalPause.token -eq $changedPause.token)
                original_operand = $originalPause.ilOperand
                changed_operand = $changedPause.ilOperand
                original_result = $originalNode4.resultObserved
                changed_result = $changedNode4.resultObserved
                original_caller_cursor = $originalPost.callerCursor
                changed_caller_cursor = $changedPost.callerCursor
            }
        }
        negative_tests = $negativeSummary.records
        strict_event_json = $eventJsonEvidence
        launcher_negatives = $launcherNegatives.ToArray()
        provenance = [ordered]@{
            run_control = 'Lua manager.machine.debugger and cpu.debug step/go/breakpoints'
            exact_boundaries = 'native debugger stopped state and cpu.debug:step(1)'
            node_resolution = 'output-bound source map and handler-entry plan, validated against live bytes'
            command_driver = 'Lua emu.register_periodic while stopped; not an instruction boundary'
            input = 'tracked physical replay only; no PC/RAM/register/ROM injection'
            event_serialization = 'real tools/lua/IlDebugSession.lua serializer block extracted and run under installed MAME Lua 5.4'
            validation = 'PowerShell tools/Invoke-IlDebugCommand.ps1, tests/worker/Test-IlDebugSession.ps1 and tests/worker/Test-IlEventJson.ps1'
        }
        acceptance = [ordered]@{
            stopped_state_handshake = $true
            strict_command_vocabulary = $true
            inspect_no_cycle_or_state_advance = $true
            five_node_step_transitions = $true
            actual_caller_continuation = $true
            original_result_0000 = ($originalPost.resultObserved -eq '0000')
            changed_result_0080 = ($changedPost.resultObserved -eq '0080')
            no_state_seeding_or_writes = $true
            strict_event_json = ([int]$eventJsonEvidence.sessions.original.failures -eq 0 -and [int]$eventJsonEvidence.sessions.changed.failures -eq 0 -and [bool]$eventJsonEvidence.serializer_probe.pass)
            trailing_comma_records_rejected = [bool]$eventJsonEvidence.negative_controls.legacy.pass
            control_character_records_rejected = [bool]$eventJsonEvidence.negative_controls.allRejected
            paid_window_unchanged = 'unresolved; not retried'
            physical_hardware_compatibility = 'not claimed'
        }
        limitations = @(
            'The OSD debugger window is required as the stopped host; -debugger none auto-resumes on scheduled events at reset.',
            'The Lua periodic callback is a command driver, not an instruction callback; exact boundaries come from native step/breakpoint state.',
            'Only the fixed 9ED9 definition map and its five nodes are supported.',
            'The demonstrated call is the first natural 9ED9 call with the tracked replay, not the later EE16/EE22 paid window.',
            'No arbitrary memory reads, register writes, state injection, save-state loads or extension allocation are supported.',
            'Physical MPU4 hardware compatibility remains separate and unproved.',
            'The preserved il-debug-step-10 event logs are invalid JSONL (trailing commas and incomplete escaping) and remain unchanged only as rejected review inputs.'
        )
    }
    $tempOutput = $OutputPath + '.tmp-' + [guid]::NewGuid().ToString('N')
    [IO.File]::WriteAllText($tempOutput,(ConvertTo-Json -InputObject $evidence -Depth 20),(New-Object System.Text.UTF8Encoding($false)))
    if ((Test-Path -LiteralPath $OutputPath) -and !$Force) {
        Remove-Item -LiteralPath $tempOutput -Force
        Write-Fail "Evidence output already exists (use -Force): $OutputPath"
    } else {
        Move-Item -LiteralPath $tempOutput -Destination $OutputPath -Force
        Write-Pass "Curated evidence written: $OutputPath"
    }
} elseif ($script:Failures -eq 0 -and $SkipNatural) {
    Write-Pass 'Natural sessions skipped; launcher and static checks only'
}

Write-Output "Test-IlDebugSession: $($script:Checks) checks, $($script:Failures) failures"
Write-Output "RUNROOT=$RunRoot"
if ($script:Failures -gt 0) { exit 1 }

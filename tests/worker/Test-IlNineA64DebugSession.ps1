[CmdletBinding()]
param(
    [string]$MameExecutable = 'E:\Arcade\MAME0266\mame281.exe',
    [string]$RomDirectory = 'E:\Arcade\MAME0266\roms',
    [string]$OriginalRom = 'C:\Users\John\Documents\Codex\2026-10-13\help-me-set-up-a-local\outputs\mpu4\rom\a6ls.p1',
    [string]$OutputPath,
    [string]$RunRoot,
    [ValidateRange(30,600)][int]$WallTimeoutSeconds = 180,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $repo 'evidence/mpu4/integrity/il-9a64-debug-session.json' }
$stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
if ([string]::IsNullOrWhiteSpace($RunRoot)) { $RunRoot = Join-Path $repo ('artifacts/deepseek/il-9a64-session-16/test-runs/run-' + $stamp) }
$RunRoot = [IO.Path]::GetFullPath($RunRoot)
$StartTool = Join-Path $repo 'tools/Start-IlDebugSession.ps1'
$CliTool = Join-Path $repo 'tools/Invoke-IlDebugCommand.ps1'
$MapTool = Join-Path $repo 'tools/Capture-IlNineA64Natural.ps1'
$EventJsonHelper = Join-Path $repo 'tests/worker/Test-IlEventJson.ps1'
$ManifestTool = Join-Path $repo 'tools/Update-CuratedManifest.ps1'
$ReplayPath = Join-Path $repo 'evidence/mpu4/skill-cash/actions.csv'
$InputLuaPath = Join-Path $repo 'evidence/mpu4/skill-cash/input.lua'
$OriginalSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$OriginalSha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
$MameSha256 = '0fce5a88df4f9d9b1fbf1405812c00848036e615993780978d967da34204cb7a'
$MapSha256 = '8d9c9ddc58373e1ffdd221590a75babc1fb7bf3f497bfca587dbac84981df766'
$BuildSha256 = '11455cdcc15d91780bd1f67c3bd0f6fcdffb3a6a22a4cb61f6fdbc901e3ec3e2'

$script:Checks = 0
$script:Failures = 0
$script:OwnedProcesses = New-Object 'System.Collections.Generic.List[int]'
$script:PwshPath = $null
$pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -ne $pwshCommand) { $script:PwshPath = $pwshCommand.Source }

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
function Get-RomWord([byte[]]$Rom,[int]$Address) { return ((([int]$Rom[$Address]) -shl 8) -bor [int]$Rom[($Address + 1) -band 0xFFFF]) }
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
function Invoke-CliCommand([string]$SessionDirectory,[string]$Command,[int]$Node = -1,[int]$TimeoutSeconds = 90,[int]$Caller = -1) {
    $arguments = @('-NoProfile','-File',$CliTool,'-SessionDirectory',$SessionDirectory,'-Command',$Command,'-TimeoutSeconds',[string]$TimeoutSeconds)
    if ($Node -ge 0) { $arguments += @('-Node',[string]$Node) }
    if ($Caller -ge 0) { $arguments += @('-Caller',[string]$Caller) }
    $child = Invoke-ChildPowerShell $arguments
    $text = $child.text
    $exitCode = $child.exit_code
    $responsePath = $null
    if ($text -match 'RESPONSE=([^\r\n]+)') { $responsePath = $Matches[1].Trim() }
    $response = if ($responsePath -and (Test-Path -LiteralPath $responsePath -PathType Leaf)) { Read-Response $responsePath } else { $null }
    return [ordered]@{ exit_code = $exitCode; text = $text; response_path = $responsePath; response = $response }
}
function New-RawRequest([string]$SessionDirectory,[int]$Sequence,[string]$Text,[int]$TimeoutSeconds = 40) {
    $path = Join-Path $SessionDirectory ('commands/request-{0:D6}.req' -f $Sequence)
    $temp = Join-Path $SessionDirectory ('commands/.tmp-test-{0:D6}' -f $Sequence)
    [IO.File]::WriteAllText($temp,$Text,(New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $temp -Destination $path -ErrorAction Stop
    $responsePath = Join-Path $SessionDirectory ('responses/request-{0:D6}.resp' -f $Sequence)
    return Wait-Response $responsePath $TimeoutSeconds
}
function New-DirectRequest([string]$SessionDirectory,[int]$Sequence,[string]$Command,[string]$Node = '',[string[]]$ExtraLines = @()) {
    $config = Get-Content -LiteralPath (Join-Path $SessionDirectory 'session-config.json') -Raw | ConvertFrom-Json
    $nonce = [guid]::NewGuid().ToString('N').Substring(0,8).ToLowerInvariant()
    $requestId = 'r' + $Sequence + '-' + $nonce
    $lines = @(
        'protocol=il-debug-session-v1',
        ('session=' + $config.sessionId),
        ('sequence=' + $Sequence),
        ('requestId=' + $requestId),
        ('nonce=' + $nonce),
        ('command=' + $Command),
        ('node=' + $Node)
    )
    if ($ExtraLines.Count -gt 0) { $lines += $ExtraLines }
    return New-RawRequest $SessionDirectory $Sequence (($lines -join "`n") + "`n") 40
}
function Start-9A64Session([string]$RunDirectory,[string]$MapPath,[string]$BuildPath) {
    $arguments = @('-NoProfile','-File',$StartTool,
        '-MameExecutable',$MameExecutable,'-RomDirectory',$RomDirectory,'-OriginalRom',$OriginalRom,
        '-Variant','Original','-Definition','9A64','-RunDirectory',$RunDirectory,
        '-SecondsToRun','120','-WallTimeoutSeconds',[string]$WallTimeoutSeconds,
        '-SourceMapPath',$MapPath,'-BuildReportPath',$BuildPath,
        '-ReplayPath',$ReplayPath,'-InputLuaPath',$InputLuaPath)
    $child = Invoke-ChildPowerShell $arguments
    if ($child.exit_code -ne 0) { throw "9A64 session launcher failed: $($child.text)" }
    $launch = $child.text | ConvertFrom-Json
    $script:OwnedProcesses.Add([int]$launch.process_id)
    return $launch
}
function Wait-OwnedExit([int]$ProcessId,[int]$TimeoutSeconds = 30) {
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
function Get-HandlerSequence($Responses) {
    $list = New-Object 'System.Collections.Generic.List[string]'
    foreach ($response in @($Responses)) {
        if ($null -eq $response) { continue }
        foreach ($transition in @(Get-Transitions $response)) {
            if ($transition['type'] -eq 'handler' -or $transition['type'] -eq 'return-handler') {
                if (-not $list.Contains([string]$transition['pc'])) { $list.Add([string]$transition['pc']) }
            }
        }
    }
    return $list.ToArray()
}
function Invoke-OneCall([string]$SessionDirectory,[string]$Label,[byte[]]$Rom) {
    $pause = Invoke-CliCommand $SessionDirectory 'pause-at-caller-token' -1 120 0
    Assert-Equal $pause.exit_code 0 "$Label caller pause command exits zero"
    if ($null -eq $pause.response) { throw "$Label caller pause has no response" }
    $p = $pause.response
    Assert-Equal $p['status'] 'ok' "$Label caller pause status"
    Assert-Equal $p['kind'] 'paused-at-caller' "$Label caller pause kind"
    Assert-Equal $p['boundaryPhase'] 'caller-prefetch' "$Label caller pause boundary phase"
    Assert-Equal $p['callerIndex'] '0' "$Label caller pause index"
    Assert-Equal $p['pc'] '00FC' "$Label caller pause PC"
    Assert-Equal $p['y'] 'EF9C' "$Label caller pause Y is the caller token address"
    Assert-Equal $p['callerTokenAddress'] 'EF9C' "$Label caller token address"
    Assert-Equal $p['callerToken'] '9A62' "$Label caller token"
    Assert-Equal $p['calleeHeaderAddress'] '9A62' "$Label callee header address"
    Assert-Equal $p['calleeHeaderValue'] '00F8' "$Label callee header value"
    Assert-Equal $p['calleeBodyStart'] '9A64' "$Label callee body start"
    Assert-Equal $p['calleeBodyEndExclusive'] '9A72' "$Label callee body end"
    Assert-Equal $p['callerSuccessor'] 'EF9E' "$Label caller successor"
    Assert-Equal $p['postReturnToken'] '80C4' "$Label caller post-return token"
    Assert-Equal $p['u'] '066C' "$Label caller pause U"
    Assert-Equal $p['s'] '07AC' "$Label caller pause S"
    Assert-Equal $p['execState'] 'stop' "$Label caller pause reports stopped"

    $inspectA = Invoke-CliCommand $SessionDirectory 'inspect' -1 30
    $inspectB = Invoke-CliCommand $SessionDirectory 'inspect' -1 30
    Assert-Equal $inspectA.exit_code 0 "$Label first inspect exits zero"
    Assert-Equal $inspectB.exit_code 0 "$Label second inspect exits zero"
    if ($null -ne $inspectA.response -and $null -ne $inspectB.response) {
        $a = $inspectA.response; $b = $inspectB.response
        Assert-Equal $a['proof'] 'stopped_read_only' "$Label inspect proof"
        Assert-Equal $a['boundaryPhase'] 'caller-prefetch' "$Label caller inspect boundary"
        Assert-Equal $a['stateUnchanged'] 'yes' "$Label first inspect unchanged"
        Assert-Equal $b['stateUnchanged'] 'yes' "$Label second inspect unchanged"
        foreach ($key in @('pc','x','y','u','s','emulatedTime','callerToken')) { Assert-Equal $a[$key] $b[$key] "$Label repeated inspect keeps $key" }
        Assert-Equal $a['emulatedTime'] $p['emulatedTime'] "$Label inspect does not advance emulated time"
    }

    $entry = Invoke-CliCommand $SessionDirectory 'step-into-mapped-call' -1 30
    Assert-Equal $entry.exit_code 0 "$Label step-into exits zero"
    if ($null -eq $entry.response) { throw "$Label step-into has no response" }
    $e = $entry.response
    Assert-Equal $e['status'] 'ok' "$Label step-into status"
    Assert-Equal $e['kind'] 'call-entered' "$Label step-into kind"
    Assert-Equal $e['steps'] '4' "$Label step-into exact four native steps"
    Assert-Equal $e['transitionCount'] '4' "$Label step-into four transitions"
    Assert-Equal $e['toBoundaryPhase'] 'prefetch' "$Label step-into target phase"
    Assert-Equal $e['toNodeIndex'] '0' "$Label step-into target node"
    Assert-Equal $e['pc'] '00FC' "$Label step-into PC"
    Assert-Equal $e['x'] '9A64' "$Label step-into X"
    Assert-Equal $e['y'] '9A64' "$Label step-into Y"
    Assert-Equal $e['token'] '7B6D' "$Label step-into first token"
    Assert-Equal $e['handlerPc'] '7B6F' "$Label step-into first handler"
    Assert-Equal $e['ilOperand'] '' "$Label non-branch callee node has no word literal operand"
    Assert-Equal $e['savedCursor'] 'EF9E' "$Label step-into saved cursor"
    Assert-Equal $e['entrySPre'] '07AC' "$Label step-into pre-entry S"
    Assert-Equal $e['entryS'] '07AA' "$Label step-into entry S"
    Assert-Equal $e['entryDeltaS'] '0002' "$Label step-into S delta"
    Assert-Equal $e['entryU'] '066C' "$Label step-into entry U"
    Assert-Equal $e['entryUAtBoundary'] '066C' "$Label step-into U unchanged"
    Assert-Equal $e['u'] $p['u'] "$Label step-into keeps U"
    Assert-Equal $e['execState'] 'stop' "$Label step-into reports stopped"
    $et = @(Get-Transitions $e)
    Assert-Equal $et.Count 4 "$Label step-into transition count"
    if ($et.Count -eq 4) {
        Assert-Equal $et[0]['type'] 'ldx-y-increment' "$Label entry transition 0 type"
        Assert-Equal $et[0]['pc'] '00FE' "$Label entry transition 0 PC"
        Assert-Equal $et[0]['y'] 'EF9E' "$Label entry transition 0 Y"
        Assert-Equal $et[0]['x'] '9A62' "$Label entry transition 0 X"
        Assert-Equal $et[1]['type'] 'jmp-indirect' "$Label entry transition 1 type"
        Assert-Equal $et[1]['pc'] '00F8' "$Label entry transition 1 PC"
        Assert-Equal $et[1]['x'] '9A64' "$Label entry transition 1 X"
        Assert-Equal $et[2]['type'] 'pshs-y' "$Label entry transition 2 type"
        Assert-Equal $et[2]['pc'] '00FA' "$Label entry transition 2 PC"
        Assert-Equal $et[2]['s'] '07AA' "$Label entry transition 2 S"
        Assert-Equal $et[2]['savedCursor'] 'EF9E' "$Label entry transition 2 saved cursor"
        Assert-Equal $et[3]['type'] 'leay-x' "$Label entry transition 3 type"
        Assert-Equal $et[3]['pc'] '00FC' "$Label entry transition 3 PC"
        Assert-Equal $et[3]['y'] '9A64' "$Label entry transition 3 Y"
        Assert-Equal $et[3]['x'] '9A64' "$Label entry transition 3 X"
    }

    $resume = Invoke-CliCommand $SessionDirectory 'resume-to-supported-boundary' -1 30
    Assert-Equal $resume.exit_code 0 "$Label resume exits zero"
    if ($null -ne $resume.response) {
        $r = $resume.response
        Assert-Equal $r['toBoundaryPhase'] 'handler' "$Label resume reaches a handler"
        Assert-Equal $r['pc'] '7B6F' "$Label resume handler PC"
        Assert-Equal $r['y'] '9A66' "$Label resume handler Y"
        Assert-Equal $r['x'] '7B6F' "$Label resume handler X is the token code field"
        Assert-True ([double]$r['timeAfter'] -gt [double]$r['timeBefore']) "$Label resume advances emulated time"
    }

    $stepResponses = New-Object 'System.Collections.Generic.List[object]'
    $commands = New-Object 'System.Collections.Generic.List[object]'
    $commands.Add($pause.response); $commands.Add($inspectA.response); $commands.Add($inspectB.response); $commands.Add($entry.response); $commands.Add($resume.response)

    $step0 = Invoke-CliCommand $SessionDirectory 'step-one-IL-node' -1 30
    Assert-Equal $step0.exit_code 0 "$Label step to node 1 exits zero"
    if ($null -ne $step0.response) {
        $s = $step0.response
        $commands.Add($s); $stepResponses.Add($s)
        Assert-Equal $s['toBoundaryPhase'] 'prefetch' "$Label step to node 1 phase"
        Assert-Equal $s['toNodeIndex'] '1' "$Label step to node 1 index"
        Assert-Equal $s['y'] '9A66' "$Label step to node 1 Y"
        Assert-Equal $s['token'] '7982' "$Label step to node 1 branch token"
        Assert-Equal $s['ilBranchOperandAddress'] '9A68' "$Label branch operand is a byte after the token"
        Assert-Equal $s['ilBranchOperandByte'] '06' "$Label branch operand byte"
        Assert-Equal $s['ilBranchTargetAddress'] '9A6E' "$Label branch target is a node boundary"
        Assert-Equal $s['ilOperand'] '' "$Label branch node is not treated as a word literal"
    }

    $branchStep = Invoke-CliCommand $SessionDirectory 'step-one-IL-node' -1 30
    Assert-Equal $branchStep.exit_code 0 "$Label branch-conditioned step exits zero"
    if ($null -eq $branchStep.response) { throw "$Label branch step has no response" }
    $bs = $branchStep.response
    $commands.Add($bs); $stepResponses.Add($bs)
    Assert-Equal $bs['fromNodeIndex'] '1' "$Label branch step starts at node 1"
    Assert-Equal $bs['branchNodeIndex'] '1' "$Label branch step names the conditional branch node"
    Assert-Equal $bs['branchCondition'] 'IfZero' "$Label branch condition is IfZero"
    Assert-Equal $bs['branchTokenAddress'] '9A66' "$Label branch token address is the node address"
    Assert-Equal $bs['branchOperandAddress'] '9A68' "$Label branch operand address"
    Assert-Equal $bs['branchOperandByte'] '06' "$Label branch operand byte"
    Assert-Equal $bs['branchLiveOperandByte'] '06' "$Label live branch operand byte matches"
    Assert-Equal $bs['branchTargetAddress'] '9A6E' "$Label branch model target"
    Assert-Equal $bs['branchUAdvance'] '0002' "$Label conditional branch advances U by exactly two"
    Assert-Equal $bs['branchExpectedNextY'] $bs['branchObservedNextY'] "$Label branch next Y matches the model successor"
    $branchPath = [string]$bs['branchPath']
    Assert-True ($branchPath -eq 'zero' -or $branchPath -eq 'nonzero') "$Label branch path is zero or nonzero"
    if ($branchPath -eq 'zero') {
        Assert-Equal $bs['branchConditionCell'] '0000' "$Label zero path condition cell"
        Assert-Equal $bs['toNodeIndex'] '4' "$Label zero path reaches node 4"
        Assert-Equal $bs['y'] '9A6E' "$Label zero path Y"
    } else {
        Assert-True ($bs['branchConditionCell'] -ne '0000') "$Label nonzero path condition cell is nonzero"
        Assert-Equal $bs['toNodeIndex'] '2' "$Label nonzero path reaches node 2"
        Assert-Equal $bs['y'] '9A69' "$Label nonzero path Y"
    }
    $nodeSequence = New-Object 'System.Collections.Generic.List[int]'
    foreach ($value in @(0,1,[int]$bs['toNodeIndex'])) { $nodeSequence.Add($value) }
    $unconditionalSeen = $false
    $guard = 0
    while ($stepResponses[$stepResponses.Count - 1]['toBoundaryPhase'] -ne 'post-return') {
        $guard++
        if ($guard -gt 8) { Write-Fail "$Label did not reach post-return within eight IL steps"; break }
        $next = Invoke-CliCommand $SessionDirectory 'step-one-IL-node' -1 30
        Assert-Equal $next.exit_code 0 "$Label continuation step exits zero"
        if ($null -eq $next.response) { Write-Fail "$Label continuation step has no response"; break }
        $ns = $next.response
        $commands.Add($ns); $stepResponses.Add($ns)
        if ($ns['toBoundaryPhase'] -eq 'prefetch') {
            $nodeSequence.Add([int]$ns['toNodeIndex'])
            $expectedNext = if ($branchPath -eq 'zero') { @(5) } else { @(3,5) }
            if ($branchPath -eq 'nonzero' -and [int]$ns['fromNodeIndex'] -eq 3) {
                $unconditionalSeen = $true
                Assert-Equal $ns['branchNodeIndex'] '3' "$Label unconditional branch node"
                Assert-Equal $ns['branchPath'] 'always' "$Label unconditional branch path"
                Assert-Equal $ns['branchOperandAddress'] '9A6D' "$Label unconditional branch operand address"
                Assert-Equal $ns['branchOperandByte'] '03' "$Label unconditional branch operand byte"
                Assert-Equal $ns['branchTargetAddress'] '9A70' "$Label unconditional branch target"
                Assert-Equal $ns['branchObservedNextY'] '9A70' "$Label unconditional branch next Y is 9A70"
                Assert-Equal $ns['branchUAdvance'] '0000' "$Label unconditional branch does not consume a data cell"
            }
        }
    }
    $post = $stepResponses[$stepResponses.Count - 1]
    Assert-Equal $post['fromNodeIndex'] '5' "$Label return step starts at the return node"
    Assert-Equal $post['toBoundaryPhase'] 'post-return' "$Label return step reaches the caller continuation"
    Assert-Match $post['postReturnS'] '^[0-9A-F]{4}$' "$Label post-return S is observed"
    Assert-Match $post['returnS'] '^[0-9A-F]{4}$' "$Label return-handler S is observed"
    Assert-Equal ([Convert]::ToInt32($post['postReturnS'],16)) ((([Convert]::ToInt32($post['returnS'],16)) + 2) -band 0xFFFF) "$Label post-return S is the return-handler S plus PULS"
    Assert-Equal $post['callerCursor'] $post['savedCursor'] "$Label caller cursor matches the saved cursor"
    Assert-Equal $post['y'] $post['savedCursor'] "$Label post-return Y restores the saved cursor"
    $savedCursor = [Convert]::ToInt32([string]$post['savedCursor'],16)
    Assert-Equal $post['postReturnToken'] ('{0:X4}' -f (Get-RomWord $Rom $savedCursor)) "$Label post-return token is the ROM word at the saved cursor"
    $expectedNodes = if ($branchPath -eq 'zero') { '0,1,4,5' } else { '0,1,2,3,5' }
    Assert-Equal (($nodeSequence.ToArray()) -join ',') $expectedNodes "$Label observed node sequence"
    $handlers = @(Get-HandlerSequence (@($resume.response) + $stepResponses.ToArray()))
    $handlerText = ($handlers -join ',')
    $expectedHandlers = if ($branchPath -eq 'zero') { '7B6F,7984,7673,7931' } else { '7B6F,7984,7667,797B,7931' }
    Assert-Equal $handlerText $expectedHandlers "$Label observed handler sequence"
    if ($branchPath -eq 'zero') {
        $internal = @($stepResponses.ToArray() | ForEach-Object { Get-Transitions $_ } | Where-Object { $_['pc'] -eq '797B' })
        Assert-Equal $internal.Count 0 "$Label internal 797B zero-handle execution is not labelled as node 3"
        $fromNode3 = @($stepResponses.ToArray() | Where-Object { [int]$_['fromNodeIndex'] -eq 3 })
        Assert-Equal $fromNode3.Count 0 "$Label zero path never steps from node 3"
    } else {
        Assert-True $unconditionalSeen "$Label nonzero path observes the 7979 unconditional branch"
    }
    return [ordered]@{
        label = $Label
        branchPath = $branchPath
        conditionCell = $bs['branchConditionCell']
        branchOperandAddress = $bs['branchOperandAddress']
        branchOperandByte = $bs['branchOperandByte']
        branchTargetAddress = $bs['branchTargetAddress']
        branchNextY = $bs['branchObservedNextY']
        branchUAdvance = $bs['branchUAdvance']
        nodeSequence = (($nodeSequence.ToArray()) -join ',')
        handlerSequence = $handlerText
        pause = $p
        entry = $e
        postReturn = $post
        stepCount = $stepResponses.Count
        commands = $commands.ToArray()
    }
}

function Invoke-ZeroPath([string]$SessionDirectory,[byte[]]$Rom) {
    # Pause at the zero-only branch target 9A6E in a fresh session. This avoids
    # stepping earlier nonzero calls and therefore observes the natural zero
    # path from its mapped target through the clear handler and return.
    $pause = Invoke-CliCommand $SessionDirectory 'pause-at-mapped-node' 4 120
    Assert-Equal $pause.exit_code 0 'zero-path pause command exits zero'
    if ($null -eq $pause.response) { throw 'zero-path pause has no response' }
    $p = $pause.response
    Assert-Equal $p['status'] 'ok' 'zero-path pause status'
    Assert-Equal $p['kind'] 'paused-at-node' 'zero-path pause kind'
    Assert-Equal $p['nodeIndex'] '4' 'zero-path pause node index'
    Assert-Equal $p['nodeAddress'] '9A6E' 'zero-path pause is at the 9A6E branch target'
    Assert-Equal $p['token'] '7671' 'zero-path pause token'
    Assert-Equal $p['handlerPc'] '7673' 'zero-path pause maps the clear handler'
    Assert-Equal $p['y'] '9A6E' 'zero-path prefetch Y'
    Assert-Equal $p['ilOperand'] '' 'zero-path target is not a word literal node'
    Assert-Equal $p['execState'] 'stop' 'zero-path pause reports stopped'

    $inspectA = Invoke-CliCommand $SessionDirectory 'inspect' -1 30
    $inspectB = Invoke-CliCommand $SessionDirectory 'inspect' -1 30
    Assert-Equal $inspectA.exit_code 0 'zero-path first inspect exits zero'
    Assert-Equal $inspectB.exit_code 0 'zero-path second inspect exits zero'
    if ($null -ne $inspectA.response -and $null -ne $inspectB.response) {
        $a = $inspectA.response; $b = $inspectB.response
        Assert-Equal $a['stateUnchanged'] 'yes' 'zero-path inspect is read-only'
        Assert-Equal $b['stateUnchanged'] 'yes' 'zero-path repeated inspect is read-only'
        Assert-Equal $a['emulatedTime'] $b['emulatedTime'] 'zero-path inspect does not advance emulated time'
    }

    $resume = Invoke-CliCommand $SessionDirectory 'resume-to-supported-boundary' -1 30
    Assert-Equal $resume.exit_code 0 'zero-path resume exits zero'
    if ($null -ne $resume.response) {
        $r = $resume.response
        Assert-Equal $r['toBoundaryPhase'] 'handler' 'zero-path resume reaches a handler'
        Assert-Equal $r['pc'] '7673' 'zero-path clear handler PC'
        Assert-Equal $r['y'] '9A70' 'zero-path clear handler Y'
        Assert-Equal $r['x'] '7673' 'zero-path clear handler X is the token code field'
    }

    $stepResponses = New-Object 'System.Collections.Generic.List[object]'
    $nodeSequence = New-Object 'System.Collections.Generic.List[int]'
    $nodeSequence.Add(4)
    $next = Invoke-CliCommand $SessionDirectory 'step-one-IL-node' -1 30
    Assert-Equal $next.exit_code 0 'zero-path step to node 5 exits zero'
    if ($null -eq $next.response) { throw 'zero-path step to node 5 has no response' }
    $s = $next.response
    $stepResponses.Add($s)
    Assert-Equal $s['toBoundaryPhase'] 'prefetch' 'zero-path step reaches a prefetch'
    Assert-Equal $s['toNodeIndex'] '5' 'zero-path reaches node 5'
    Assert-Equal $s['y'] '9A70' 'zero-path node 5 Y'
    Assert-Equal $s['token'] '792F' 'zero-path node 5 return token'
    $nodeSequence.Add(5)

    $postStep = Invoke-CliCommand $SessionDirectory 'step-one-IL-node' -1 30
    Assert-Equal $postStep.exit_code 0 'zero-path return step exits zero'
    if ($null -eq $postStep.response) { throw 'zero-path return step has no response' }
    $post = $postStep.response
    $stepResponses.Add($post)
    Assert-Equal $post['fromNodeIndex'] '5' 'zero-path return step starts at node 5'
    Assert-Equal $post['toBoundaryPhase'] 'post-return' 'zero-path return step reaches the caller continuation'
    Assert-Match $post['postReturnS'] '^[0-9A-F]{4}$' 'zero-path post-return S is observed'
    Assert-Match $post['returnS'] '^[0-9A-F]{4}$' 'zero-path return-handler S is observed'
    Assert-Equal ([Convert]::ToInt32($post['postReturnS'],16)) ((([Convert]::ToInt32($post['returnS'],16)) + 2) -band 0xFFFF) 'zero-path post-return S is the return-handler S plus PULS'
    Assert-Equal $post['callerCursor'] $post['savedCursor'] 'zero-path caller cursor matches the saved cursor'
    Assert-Equal $post['y'] $post['savedCursor'] 'zero-path post-return Y restores the saved cursor'
    $savedCursor = [Convert]::ToInt32([string]$post['savedCursor'],16)
    Assert-Equal $post['postReturnToken'] ('{0:X4}' -f (Get-RomWord $Rom $savedCursor)) 'zero-path post-return token is the ROM word at the saved cursor'

    $handlers = @(Get-HandlerSequence (@($resume.response) + $stepResponses.ToArray()))
    $handlerText = ($handlers -join ',')
    Assert-Equal $handlerText '7673,7931' 'zero-path observed handler sequence starts at the clear handler'
    Assert-Equal (($nodeSequence.ToArray()) -join ',') '4,5' 'zero-path observed node sequence'
    $allTransitions = @($stepResponses.ToArray() | ForEach-Object { Get-Transitions $_ })
    Assert-Equal @($allTransitions | Where-Object { $_['node'] -eq '2' -or $_['node'] -eq '3' }).Count 0 'zero-path session never resolves node 2 or node 3'
    Assert-Equal @($allTransitions | Where-Object { $_['pc'] -eq '797B' }).Count 0 'zero-path session never labels internal 797B execution as node 3'
    return [ordered]@{
        label = 'zero-path'
        branchPath = 'zero-target-observed'
        conditionCell = $null
        branchTargetAddress = '9A6E'
        nodeSequence = (($nodeSequence.ToArray()) -join ',')
        handlerSequence = $handlerText
        pause = $p
        postReturn = $post
        stepCount = $stepResponses.Count
        commands = @($pause.response, $inspectA.response, $inspectB.response, $resume.response, $s, $post)
    }
}

$natural = $null
$negative = $null
$launcherNegatives = New-Object 'System.Collections.Generic.List[object]'
$protocolNegatives = New-Object 'System.Collections.Generic.List[object]'
$naturalEvents = $null
$zeroEvents = $null
$negativeEvents = $null

try {
    New-Item -ItemType Directory -Path $RunRoot -Force | Out-Null
    Assert-True (Test-Path -LiteralPath $StartTool -PathType Leaf) 'paused-session launcher exists'
    Assert-True (Test-Path -LiteralPath $CliTool -PathType Leaf) 'paused-session command tool exists'
    Assert-True (Test-Path -LiteralPath $MapTool -PathType Leaf) '9A64 map generator exists'
    Assert-True (Test-Path -LiteralPath $OriginalRom -PathType Leaf) 'strict original ROM exists'
    Assert-True (-not [string]::IsNullOrWhiteSpace($script:PwshPath)) 'pwsh with System.Text.Json is available'

    $mapRun = Join-Path $RunRoot 'map'
    $mapChild = Invoke-ChildPowerShell @('-NoProfile','-File',$MapTool,'-Mode','MapOnly','-OriginalRom',$OriginalRom,'-RunDirectory',$mapRun)
    Assert-Equal $mapChild.exit_code 0 'MapOnly exits zero'
    $mapInfo = $mapChild.text | ConvertFrom-Json
    Assert-Equal $mapInfo.entries 14 'generated 9A64 source map has fourteen entries'
    Assert-Equal $mapInfo.nodes 6 'generated 9A64 source map has six nodes'
    Assert-Equal $mapInfo.branches 2 'generated 9A64 source map has two byte branches'
    Assert-Equal $mapInfo.sourceMapSha256 $MapSha256 'generated 9A64 source map hash is the accepted identity'
    Assert-Equal $mapInfo.buildReportSha256 $BuildSha256 'generated 9A64 build report hash is the accepted identity'
    $mapPath = [string]$mapInfo.sourceMap
    $buildPath = [string]$mapInfo.buildReport

    # Launcher negatives. None may create a run directory or start a session.
    function Assert-LauncherNegative([string]$Name,[string]$RunDirectory,[hashtable]$Overrides,[string]$Pattern) {
        $parameters = [ordered]@{
            MameExecutable = $MameExecutable
            RomDirectory = $RomDirectory
            OriginalRom = $OriginalRom
            Variant = 'Original'
            Definition = '9A64'
            RunDirectory = $RunDirectory
            SecondsToRun = '120'
            WallTimeoutSeconds = [string]$WallTimeoutSeconds
            SourceMapPath = $mapPath
            BuildReportPath = $buildPath
            ReplayPath = $ReplayPath
            InputLuaPath = $InputLuaPath
        }
        foreach ($key in $Overrides.Keys) { $parameters[$key] = $Overrides[$key] }
        $arguments = @('-NoProfile','-File',$StartTool)
        foreach ($key in $parameters.Keys) { $arguments += @(('-' + $key),[string]$parameters[$key]) }
        $child = Invoke-ChildPowerShell $arguments
        $passed = ($child.exit_code -ne 0 -and $child.text -match $Pattern -and !(Test-Path -LiteralPath $RunDirectory))
        Assert-True $passed "launcher negative $Name is rejected"
        return [ordered]@{ name=$Name; rejected=$passed; message=($child.text.Trim() -split "`r?`n")[0] }
    }
    $negRoot = Join-Path $RunRoot 'launcher-negatives'
    New-Item -ItemType Directory -Path $negRoot -Force | Out-Null
    $wrongRom = Join-Path $negRoot 'wrong-original.p1'
    $wrongBytes = [IO.File]::ReadAllBytes($OriginalRom)
    $wrongBytes[0x9EDC] = $wrongBytes[0x9EDC] -bxor 0x01
    [IO.File]::WriteAllBytes($wrongRom,$wrongBytes)
    $launcherNegatives.Add((Assert-LauncherNegative 'wrong original identity' (Join-Path $negRoot 'wrong-original-run') @{ OriginalRom=$wrongRom } 'SHA'))
    $launcherNegatives.Add((Assert-LauncherNegative 'modified 9A64 variant' (Join-Path $negRoot 'changed-run') @{ Variant='Changed' } 'only the original identity image'))
    $launcherNegatives.Add((Assert-LauncherNegative 'modified 9A64 image' (Join-Path $negRoot 'edited-run') @{ RepairedRom=$wrongRom } '9A64 image|modified images'))
    $staleMap = Join-Path $negRoot 'stale-map.json'
    Copy-Item -LiteralPath $mapPath -Destination $staleMap
    Add-Content -LiteralPath $staleMap -Value ' '
    $launcherNegatives.Add((Assert-LauncherNegative 'stale 9A64 source map' (Join-Path $negRoot 'stale-map-run') @{ SourceMapPath=$staleMap } '9A64 source map SHA256'))
    $staleBuild = Join-Path $negRoot 'stale-build.json'
    Copy-Item -LiteralPath $buildPath -Destination $staleBuild
    Add-Content -LiteralPath $staleBuild -Value ' '
    $launcherNegatives.Add((Assert-LauncherNegative 'stale 9A64 build report' (Join-Path $negRoot 'stale-build-run') @{ BuildReportPath=$staleBuild } '9A64 build report SHA256'))
    $existing = Join-Path $negRoot 'existing-run'
    New-Item -ItemType Directory -Path $existing -Force | Out-Null
    $existingChild = Invoke-ChildPowerShell @('-NoProfile','-File',$StartTool,'-MameExecutable',$MameExecutable,'-RomDirectory',$RomDirectory,'-OriginalRom',$OriginalRom,'-Variant','Original','-Definition','9A64','-RunDirectory',$existing,'-SecondsToRun','120','-WallTimeoutSeconds',[string]$WallTimeoutSeconds,'-SourceMapPath',$mapPath,'-BuildReportPath',$buildPath,'-ReplayPath',$ReplayPath,'-InputLuaPath',$InputLuaPath)
    $existingPass = ($existingChild.exit_code -ne 0 -and $existingChild.text -match 'fresh create-only')
    Assert-True $existingPass 'launcher negative existing run directory is rejected'
    $launcherNegatives.Add([ordered]@{ name='existing run directory'; rejected=$existingPass; message=($existingChild.text.Trim() -split "`r?`n")[0] })

    # Two natural sessions are the supported maximum for this increment.
    # Session A steps the first natural (nonzero) call and then verifies the
    # post-return rearm transition by pausing at the next natural call.
    $naturalRun = Join-Path $RunRoot 'natural-9a64'
    $sessionStart = [DateTime]::UtcNow
    $launch = Start-9A64Session $naturalRun $mapPath $buildPath
    $processId = [int]$launch.process_id
    $rom = [IO.File]::ReadAllBytes($OriginalRom)
    $config = Get-Content -LiteralPath (Join-Path $naturalRun 'session-config.json') -Raw | ConvertFrom-Json
    $first = Invoke-OneCall $naturalRun 'first-call' $rom
    Assert-Equal $first.branchPath 'nonzero' 'first natural 9A64 call takes the nonzero path'
    Assert-Equal $first.postReturn['toBoundaryPhase'] 'post-return' 'first call ends at an observed post-return boundary'
    $rearm = Invoke-CliCommand $naturalRun 'pause-at-mapped-node' 0 120
    Assert-Equal $rearm.exit_code 0 'post-return rearm exits zero'
    if ($null -ne $rearm.response) {
        Assert-Equal $rearm.response['status'] 'ok' 'rearm status is ok'
        Assert-Equal $rearm.response['kind'] 'paused-at-node' 'rearm pauses at the next natural mapped node'
        Assert-Equal $rearm.response['nodeIndex'] '0' 'rearm pauses at node 0'
        Assert-Equal $rearm.response['y'] '9A64' 'rearm pauses at the 9A64 body start'
        Assert-True ([double]$rearm.response['emulatedTime'] -gt [double]$first.postReturn['emulatedTime']) 'rearm reaches a later natural call'
    }
    $rearmInspect = Invoke-CliCommand $naturalRun 'inspect' -1 30
    Assert-Equal $rearmInspect.exit_code 0 'rearm inspect exits zero'
    if ($null -ne $rearmInspect.response) { Assert-Equal $rearmInspect.response['stateUnchanged'] 'yes' 'rearm inspect is read-only' }
    $stop = Invoke-CliCommand $naturalRun 'stop' -1 30
    Assert-Equal $stop.exit_code 0 'natural session stop exits zero'
    $sessionWallSeconds = [Math]::Round(([DateTime]::UtcNow - $sessionStart).TotalSeconds,3)
    $exited = Wait-OwnedExit $processId 30
    Assert-True $exited 'natural MAME process exits after stop'
    $exitCodeText = Get-Content -LiteralPath (Join-Path $naturalRun 'mame-exit-code.txt') -Raw
    Assert-Equal $exitCodeText.Trim() '0' 'natural MAME exit code is zero'
    Assert-True (!(Test-Path -LiteralPath (Join-Path $naturalRun 'session-timeout.txt'))) 'natural session did not hit the wall timeout'
    Assert-Equal @(Get-ChildItem -LiteralPath (Join-Path $naturalRun 'state') -Recurse -File -ErrorAction SilentlyContinue).Count 0 'natural state directory is empty'
    Assert-Equal (Get-Sha256 (Join-Path $naturalRun 'roms/m4addr/a6ls.p1')) $OriginalSha256 'natural isolated ROM is unchanged'
    Assert-Equal (Get-Sha256 (Join-Path $naturalRun 'IlDebugSession.lua')) (Get-Sha256 (Join-Path $repo 'tools/lua/IlDebugSession.lua')) 'run captures the current Lua session source'
    $console = Get-Content -LiteralPath (Join-Path $naturalRun 'console.txt') -Raw
    Assert-True ($console -notmatch 'ACCESS VIOLATION|Exception at EIP') 'natural MAME console has no exception'
    $natural = [ordered]@{ launch=$launch; first=$first; rearm=$rearm; rearmInspect=$rearmInspect; stop=$stop; sessionWallSeconds=$sessionWallSeconds; run_directory=$naturalRun }

    $naturalParsePath = Join-Path $RunRoot 'events-natural.json'
    $naturalChild = Invoke-EventJsonHelper @('-NoProfile','-File',$EventJsonHelper,'-Mode','Parse','-EventsPath',(Join-Path $naturalRun 'events.jsonl'),'-OutputPath',$naturalParsePath)
    Assert-Equal $naturalChild.exit_code 0 'natural 9A64 events pass strict JSON parsing'
    if (Test-Path -LiteralPath $naturalParsePath -PathType Leaf) { $naturalEvents = Get-Content -LiteralPath $naturalParsePath -Raw | ConvertFrom-Json }
    Assert-True ($null -ne $naturalEvents) 'natural strict event summary exists'
    if ($null -ne $naturalEvents) {
        Assert-True ([bool]$naturalEvents.pass) 'natural strict event summary passes'
        Assert-Equal @($naturalEvents.failures).Count 0 'natural strict event summary has no failures'
        Assert-Equal ([int]$naturalEvents.nonblank) ([int]$naturalEvents.recordCount) 'natural every nonblank event parsed'
        $records = @($naturalEvents.records)
        $steps = @($records | Where-Object { $_.event -eq 'node_step_complete' })
        $resumes = @($records | Where-Object { $_.event -eq 'resume_complete' })
        $pauseHits = @($records | Where-Object { $_.event -eq 'pause_hit' })
        $callerPauseHits = @($records | Where-Object { $_.event -eq 'caller_pause_hit' })
        Assert-Equal $callerPauseHits.Count 1 'session A pauses once at the caller token'
        Assert-Equal $pauseHits.Count 1 'session A rearm pauses at the next mapped body node'
        Assert-Equal @($records | Where-Object { $_.event -eq 'call_enter_complete' }).Count 1 'session A records one four-instruction call entry'
        Assert-Equal @($records | Where-Object { $_.event -eq 'call_enter_failure' }).Count 0 'session A has no call entry failure'
        Assert-Equal $resumes.Count 1 'session A resumes once'
        $branchRecords = @($steps | Where-Object { $_.fromNode -eq 1 })
        Assert-Equal $branchRecords.Count 1 'session A records one 7982 branch step'
        Assert-Equal @($branchRecords | Where-Object { $_.branchPath -eq 'nonzero' }).Count 1 'session A branch step is nonzero'
        Assert-Equal $branchRecords[0].branchUAdvance '0002' 'session A branch step records U+2'
        Assert-Equal @($steps | Where-Object { $_.branchPath -eq 'always' }).Count 1 'session A records the 7979 unconditional branch'
        Assert-Equal @($steps | Where-Object { $_.toPhase -eq 'post-return' }).Count 1 'session A records an actual post-return step'
        foreach ($forbidden in @('step_failure','pause_failure','session_timeout','startup_failure')) { Assert-Equal @($records | Where-Object { $_.event -eq $forbidden }).Count 0 "session A has no $forbidden event" }
        Assert-Equal @($records | Where-Object { $_.event -eq 'session_stopped' }).Count 1 'session A stop event'
    }

    # Session B starts fresh and pauses at the zero-only branch target 9A6E.
    # This avoids stepping earlier nonzero calls and observes the natural zero
    # branch target through the clear handler and the return.
    $zeroRun = Join-Path $RunRoot 'zero-path-9a64'
    $zeroStart = [DateTime]::UtcNow
    $zeroLaunch = Start-9A64Session $zeroRun $mapPath $buildPath
    $zeroProcessId = [int]$zeroLaunch.process_id
    $zero = Invoke-ZeroPath $zeroRun $rom
    $zeroStop = Invoke-CliCommand $zeroRun 'stop' -1 30
    Assert-Equal $zeroStop.exit_code 0 'zero-path session stop exits zero'
    $zeroWallSeconds = [Math]::Round(([DateTime]::UtcNow - $zeroStart).TotalSeconds,3)
    $zeroExited = Wait-OwnedExit $zeroProcessId 30
    Assert-True $zeroExited 'zero-path MAME process exits after stop'
    $zeroExitCodeText = Get-Content -LiteralPath (Join-Path $zeroRun 'mame-exit-code.txt') -Raw
    Assert-Equal $zeroExitCodeText.Trim() '0' 'zero-path MAME exit code is zero'
    Assert-True (!(Test-Path -LiteralPath (Join-Path $zeroRun 'session-timeout.txt'))) 'zero-path session did not hit the wall timeout'
    Assert-Equal @(Get-ChildItem -LiteralPath (Join-Path $zeroRun 'state') -Recurse -File -ErrorAction SilentlyContinue).Count 0 'zero-path state directory is empty'
    Assert-Equal (Get-Sha256 (Join-Path $zeroRun 'roms/m4addr/a6ls.p1')) $OriginalSha256 'zero-path isolated ROM is unchanged'
    $zeroConsole = Get-Content -LiteralPath (Join-Path $zeroRun 'console.txt') -Raw
    Assert-True ($zeroConsole -notmatch 'ACCESS VIOLATION|Exception at EIP') 'zero-path MAME console has no exception'
    $zeroSession = [ordered]@{ launch=$zeroLaunch; zero=$zero; stop=$zeroStop; sessionWallSeconds=$zeroWallSeconds; run_directory=$zeroRun }

    $zeroParsePath = Join-Path $RunRoot 'events-zero.json'
    $zeroChild = Invoke-EventJsonHelper @('-NoProfile','-File',$EventJsonHelper,'-Mode','Parse','-EventsPath',(Join-Path $zeroRun 'events.jsonl'),'-OutputPath',$zeroParsePath)
    Assert-Equal $zeroChild.exit_code 0 'zero-path 9A64 events pass strict JSON parsing'
    if (Test-Path -LiteralPath $zeroParsePath -PathType Leaf) { $zeroEvents = Get-Content -LiteralPath $zeroParsePath -Raw | ConvertFrom-Json }
    Assert-True ($null -ne $zeroEvents) 'zero-path strict event summary exists'
    if ($null -ne $zeroEvents) {
        Assert-True ([bool]$zeroEvents.pass) 'zero-path strict event summary passes'
        Assert-Equal @($zeroEvents.failures).Count 0 'zero-path strict event summary has no failures'
        Assert-Equal ([int]$zeroEvents.nonblank) ([int]$zeroEvents.recordCount) 'zero-path every nonblank event parsed'
        $zrecords = @($zeroEvents.records)
        $zsteps = @($zrecords | Where-Object { $_.event -eq 'node_step_complete' })
        Assert-Equal @($zrecords | Where-Object { $_.event -eq 'pause_hit' }).Count 1 'zero-path session pauses once'
        Assert-Equal @($zrecords | Where-Object { $_.event -eq 'resume_complete' }).Count 1 'zero-path session resumes once'
        Assert-Equal @($zsteps | Where-Object { $_.fromNode -eq 1 }).Count 0 'zero-path session does not claim a 7982 step it did not take'
        Assert-Equal @($zsteps | Where-Object { $_.toPhase -eq 'post-return' }).Count 1 'zero-path session records an actual post-return step'
        Assert-Equal @($zsteps | Where-Object { $_.fromNode -eq 2 -or $_.fromNode -eq 3 }).Count 0 'zero-path session never resolves node 2 or node 3'
        foreach ($forbidden in @('step_failure','pause_failure','session_timeout','startup_failure')) { Assert-Equal @($zrecords | Where-Object { $_.event -eq $forbidden }).Count 0 "zero-path session has no $forbidden event" }
        Assert-Equal @($zrecords | Where-Object { $_.event -eq 'session_stopped' }).Count 1 'zero-path session stop event'
    }

    # Synthetic protocol negatives. This session never executes a mapped node.
    $negativeRun = Join-Path $RunRoot 'protocol-negatives'
    $negLaunch = Start-9A64Session $negativeRun $mapPath $buildPath
    $negProcessId = [int]$negLaunch.process_id
    try {
        $cases = @(
            @{ Seq=1; Command='shell-exec'; Expected='unknown_command'; Name='unknown command' },
            @{ Seq=2; Command='inspect'; Extra=@('write=1'); Expected='unknown_field'; Name='write field' },
            @{ Seq=3; Command='step-one-IL-node'; Expected='wrong_phase'; Name='step before pause' },
            @{ Seq=4; Command='inspect'; Expected='wrong_phase'; Name='inspect before pause' }
        )
        foreach ($case in $cases) {
            $extra = if ($case.ContainsKey('Extra')) { @($case.Extra) } else { @() }
            $response = New-DirectRequest $negativeRun $case.Seq $case.Command '' $extra
            $passed = ($response['status'] -eq 'error' -and $response['errorCode'] -eq $case.Expected)
            Assert-True $passed "9A64 negative $($case.Name) rejects with $($case.Expected)"
            $protocolNegatives.Add([ordered]@{ name=$case.Name; sequence=$case.Seq; command=$case.Command; expected=$case.Expected; actual=$response['errorCode']; pass=$passed })
        }
        $nodeResponse = New-DirectRequest $negativeRun 5 'pause-at-mapped-node' '6'
        $nodePass = ($nodeResponse['status'] -eq 'error' -and $nodeResponse['errorCode'] -eq 'node')
        Assert-True $nodePass '9A64 negative out-of-range node is rejected'
        $protocolNegatives.Add([ordered]@{ name='out-of-range node'; sequence=5; command='pause-at-mapped-node'; expected='node'; actual=$nodeResponse['errorCode']; pass=$nodePass })

        $collisionPath = Join-Path $negativeRun 'responses/request-000006.resp'
        $configNegative = Get-Content -LiteralPath (Join-Path $negativeRun 'session-config.json') -Raw | ConvertFrom-Json
        $forged = "protocol=il-debug-session-v1`nsession=$($configNegative.sessionId)`nsequence=000006`nrequestId=r6-forged00`nnonce=forged00`ncommand=inspect`nstatus=ok`nkind=inspection`nproof=stopped_read_only`nacknowledged=yes`nphase=paused`nstateUnchanged=yes`n"
        [IO.File]::WriteAllText($collisionPath,$forged,(New-Object System.Text.UTF8Encoding($false)))
        $lines = @('protocol=il-debug-session-v1',('session=' + $configNegative.sessionId),'sequence=6','requestId=r6-abcdef12','nonce=abcdef12','command=inspect','node=')
        $requestPath = Join-Path $negativeRun 'commands/request-000006.req'
        $tempPath = Join-Path $negativeRun 'commands/.tmp-test-000006'
        [IO.File]::WriteAllText($tempPath,(($lines -join "`n") + "`n"),(New-Object System.Text.UTF8Encoding($false)))
        Move-Item -LiteralPath $tempPath -Destination $requestPath
        $collisionMarker = Join-Path $negativeRun 'commands/processed-collision-000006.req'
        $collisionMoved = Wait-ForFile $collisionMarker 20
        Assert-True $collisionMoved '9A64 collision request is moved out of the queue'
        Assert-Equal ([IO.File]::ReadAllText($collisionPath)) $forged '9A64 collision does not overwrite a forged response'
        $protocolNegatives.Add([ordered]@{ name='response collision'; sequence=6; command='inspect'; expected='no overwrite'; actual=($(if($collisionMoved){'moved'}else{'not moved'})); pass=($collisionMoved -and ([IO.File]::ReadAllText($collisionPath) -eq $forged)) })

        $stopResponse = New-DirectRequest $negativeRun 7 'stop' ''
        Assert-Equal $stopResponse['status'] 'ok' '9A64 negative session stop succeeds'
        $negExited = Wait-OwnedExit $negProcessId 30
        Assert-True $negExited '9A64 negative session process exits'
        $negative = [ordered]@{ launch=$negLaunch; run_directory=$negativeRun; protocol=$protocolNegatives.ToArray() }
    }
    finally { Stop-OwnedProcess $negProcessId }

    $negativeParsePath = Join-Path $RunRoot 'events-negative-9a64.json'
    $negativeChild = Invoke-EventJsonHelper @('-NoProfile','-File',$EventJsonHelper,'-Mode','Parse','-EventsPath',(Join-Path $negativeRun 'events.jsonl'),'-OutputPath',$negativeParsePath)
    Assert-Equal $negativeChild.exit_code 0 '9A64 negative events pass strict JSON parsing'
    if (Test-Path -LiteralPath $negativeParsePath -PathType Leaf) { $negativeEvents = Get-Content -LiteralPath $negativeParsePath -Raw | ConvertFrom-Json }
    Assert-True ($null -ne $negativeEvents) '9A64 negative strict event summary exists'
    if ($null -ne $negativeEvents) {
        Assert-True ([bool]$negativeEvents.pass) '9A64 negative strict event summary passes'
        Assert-Equal @($negativeEvents.failures).Count 0 '9A64 negative strict event summary has no failures'
        $negRecords = @($negativeEvents.records)
        Assert-Equal @($negRecords | Where-Object { $_.event -eq 'node_step_complete' }).Count 0 '9A64 negative session executes no mapped node'
        Assert-Equal @($negRecords | Where-Object { $_.event -eq 'step_start' }).Count 0 '9A64 negative session starts no step'
        Assert-Equal @($negRecords | Where-Object { $_.event -eq 'response_collision' }).Count 1 '9A64 negative session records one collision'
        Assert-Equal @($negRecords | Where-Object { $_.event -eq 'session_stopped' }).Count 1 '9A64 negative session stop event'
    }

    if ($script:Failures -eq 0) {
        $metadata = Get-Content -LiteralPath (Join-Path $naturalRun 'session-metadata.json') -Raw | ConvertFrom-Json
        $zeroMetadata = Get-Content -LiteralPath (Join-Path $zeroRun 'session-metadata.json') -Raw | ConvertFrom-Json
        $responseRecords = New-Object 'System.Collections.Generic.List[object]'
        foreach ($sessionInfo in @(@{ label='nonzero-7982-step'; dir=$naturalRun }, @{ label='zero-target'; dir=$zeroRun })) {
            foreach ($path in @(Get-ChildItem -LiteralPath (Join-Path $sessionInfo.dir 'responses') -File -Filter 'request-*.resp' | Sort-Object Name)) {
                $r = Read-Response $path.FullName
                $record = [ordered]@{
                    session = $sessionInfo.label; sequence = [int]$r['sequence']; requestId = $r['requestId']; command = $r['command']; status = $r['status']; kind = $r['kind']; proof = $r['proof']; sha256 = Get-Sha256 $path.FullName
                }
                foreach ($key in @('fromNodeIndex','toNodeIndex','fromBoundaryPhase','toBoundaryPhase','steps','branchNodeIndex','branchCondition','branchPath','branchConditionCell','branchOperandAddress','branchOperandByte','branchTargetAddress','branchObservedNextY','branchUAdvance','savedCursor','returnS','postReturnS','callerCursor','postReturnToken','callerIndex','callerTokenAddress','callerToken','calleeHeaderAddress','calleeHeaderValue','calleeBodyStart','calleeBodyEndExclusive','callerSuccessor','entrySPre','entryS','entryDeltaS','entryX','entryY','entryU','entryUAtBoundary','boundaryPhase','nodeIndex','y','token','handlerPc','pc','x','u','s','emulatedTime','timeBefore','timeAfter','stateUnchanged')) {
                    if ($r.ContainsKey($key) -and ![string]::IsNullOrWhiteSpace([string]$r[$key])) { $record[$key] = $r[$key] }
                }
                $responseRecords.Add($record)
            }
        }
        $evidence = [ordered]@{
            schemaVersion = 1
            taskId = 'il-9a64-session-16'
            generatedUtc = [DateTime]::UtcNow.ToString('o')
            resultStatus = 'complete_bounded_9a64_caller_entry_nonzero_7982_and_natural_zero_target'
            definition = '9A64'
            protocol = 'il-debug-session-v1'
            classification = 'Read-only MAME 0.281 paused Lua debugger sessions over the independent 9A64 identity source map. Two fresh natural original-image runs with the tracked physical-input replay: one pauses at the explicit EF9C caller token, performs the exact four-instruction step-into to 9A64, steps the first nonzero 7982 branch and verifies post-return rearm; one pauses at the zero-only mapped target 9A6E and steps the clear and return path. No state, register, RAM or ROM writes; no save-state load; no speculative input.'
            source = [ordered]@{
                startTool = 'tools/Start-IlDebugSession.ps1'
                commandTool = 'tools/Invoke-IlDebugCommand.ps1'
                lua = 'tools/lua/IlDebugSession.lua'
                luaSha256 = Get-Sha256 (Join-Path $repo 'tools/lua/IlDebugSession.lua')
                runLuaSha256 = Get-Sha256 (Join-Path $naturalRun 'IlDebugSession.lua')
                zeroRunLuaSha256 = Get-Sha256 (Join-Path $zeroRun 'IlDebugSession.lua')
                mapGenerator = 'tools/Capture-IlNineA64Natural.ps1'
                mapSource = 'NineASixFourDecoder.Decode + VmIlCompiler.CompileIdentity + VmIlSourceMap.CreateForBuild'
            }
            map = [ordered]@{
                path = [IO.Path]::GetFullPath($mapPath)
                sha256 = $mapInfo.sourceMapSha256
                buildReportPath = [IO.Path]::GetFullPath($buildPath)
                buildReportSha256 = $mapInfo.buildReportSha256
                originalRomSha1 = $OriginalSha1
                originalRomSha256 = $OriginalSha256
                bodyStart = '9A64'
                bodyEndExclusive = '9A72'
                spanHex = '7B6D79820676657979037671792F'
                entries = 14
                nodes = 6
                branches = 2
                returnNodeIndex = 5
            }
            images = [ordered]@{
                original = $metadata.original_rom
                runRomBefore = $metadata.run_rom_before
                runRomAfter = [ordered]@{ sha1=$OriginalSha1; sha256=(Get-Sha256 (Join-Path $naturalRun 'roms/m4addr/a6ls.p1')) }
                runRomUnchanged = ((Get-Sha256 (Join-Path $naturalRun 'roms/m4addr/a6ls.p1')) -eq $OriginalSha256)
                zeroRunRomUnchanged = ((Get-Sha256 (Join-Path $zeroRun 'roms/m4addr/a6ls.p1')) -eq $OriginalSha256)
            }
            mame = [ordered]@{ executable=$MameExecutable; version=((Get-Content -LiteralPath (Join-Path $naturalRun 'mame-version.txt') -Raw).Trim()); sha256=$MameSha256 }
            inputs = [ordered]@{ replaySha256=(Get-Sha256 $ReplayPath); inputLuaSha256=(Get-Sha256 $InputLuaPath); secondsToRun=120; wallTimeoutSeconds=$WallTimeoutSeconds; startingNvram='absent'; startingConfiguration='absent; -noreadconfig'; saveStateLoaded=$false }
            sessions = @(
                [ordered]@{
                    label = 'nonzero-7982-step'
                    sessionId = $config.sessionId
                    runDirectory = $naturalRun
                    launch = Get-Content -LiteralPath (Join-Path $naturalRun 'session-launch.json') -Raw | ConvertFrom-Json
                    wallSeconds = $sessionWallSeconds
                    mameExitCode = [int]$exitCodeText.Trim()
                    stateDirectoryFiles = @(Get-ChildItem -LiteralPath (Join-Path $naturalRun 'state') -Recurse -File -ErrorAction SilentlyContinue).Count
                    sessionTimeout = Test-Path -LiteralPath (Join-Path $naturalRun 'session-timeout.txt')
                    observed = 'First natural call: caller-token prefetch EF9C, explicit four-instruction entry to 9A64, 7982 nonzero branch step, 7979 unconditional branch, node 5 return and actual post-return. Then a post-return rearm reached a later natural call and was inspected without claiming its branch path.'
                    rearmTransition = 'pause-at-mapped-node from an observed post-return boundary arms the next natural mapped-node prefetch; no other post-return command was added.'
                },
                [ordered]@{
                    label = 'zero-target'
                    sessionId = $zeroMetadata.sessionId
                    runDirectory = $zeroRun
                    launch = Get-Content -LiteralPath (Join-Path $zeroRun 'session-launch.json') -Raw | ConvertFrom-Json
                    wallSeconds = $zeroWallSeconds
                    mameExitCode = [int]$zeroExitCodeText.Trim()
                    stateDirectoryFiles = @(Get-ChildItem -LiteralPath (Join-Path $zeroRun 'state') -Recurse -File -ErrorAction SilentlyContinue).Count
                    sessionTimeout = Test-Path -LiteralPath (Join-Path $zeroRun 'session-timeout.txt')
                    observed = 'Fresh session paused at the zero-only mapped target 9A6E, then stepped the clear handler 7673, node 5 prefetch 9A70 and actual post-return.'
                    rearmTransition = 'not used in this session'
                }
            )
            calls = @($first, $zero)
            responses = $responseRecords.ToArray()
            coverage = [ordered]@{
                naturalSessions = 2
                callsObserved = 2
                nonzero7982StepObserved = $true
                zero7982StepObserved = $false
                zeroTargetObserved = $true
                branchPathsObserved = @('nonzero','zero-target')
                firstCallPath = $first.branchPath
                zeroPathObservation = 'The zero path was entered naturally at the zero-only mapped target 9A6E. The 7982 zero-condition cell itself was not single-stepped; no 7982-zero claim is made.'
                observedNodeSequences = @($first.nodeSequence, $zero.nodeSequence)
                observedHandlerSequences = @($first.handlerSequence, $zero.handlerSequence)
                branchOperandAddress = '9A68'
                branchOperandByte = '06'
                branchTargetZero = '9A6E'
                branchFallThroughNonzero = '9A69'
                unconditionalOperandAddress = '9A6D'
                unconditionalOperandByte = '03'
                unconditionalTarget = '9A70'
                conditionalUAdvance = '0002'
                unconditionalUAdvance = '0000'
                callerEntryObserved = $true
                callerTokenAddress = $first.pause.callerTokenAddress
                callerToken = $first.pause.callerToken
                calleeBodyStart = $first.pause.calleeBodyStart
                callerSuccessor = $first.pause.callerSuccessor
                postReturnToken = $first.pause.postReturnToken
                callerEntrySteps = $first.entry.steps
                callerEntryDeltaS = $first.entry.entryDeltaS
                callerEntrySavedCursor = $first.entry.savedCursor
                callerEntryTransitionTypes = @('ldx-y-increment','jmp-indirect','pshs-y','leay-x')
                callerEntryUUnchanged = ($first.entry.entryU -eq $first.pause.u)
            }
            strictEventJson = [ordered]@{
                natural = [ordered]@{ path=(Join-Path $naturalRun 'events.jsonl'); sha256=(Get-Sha256 (Join-Path $naturalRun 'events.jsonl')); nonblank=[int]$naturalEvents.nonblank; recordCount=[int]$naturalEvents.recordCount; failures=@($naturalEvents.failures).Count; eventCounts=$naturalEvents.eventCounts }
                zero = [ordered]@{ path=(Join-Path $zeroRun 'events.jsonl'); sha256=(Get-Sha256 (Join-Path $zeroRun 'events.jsonl')); nonblank=[int]$zeroEvents.nonblank; recordCount=[int]$zeroEvents.recordCount; failures=@($zeroEvents.failures).Count; eventCounts=$zeroEvents.eventCounts }
                negative = [ordered]@{ path=(Join-Path $negativeRun 'events.jsonl'); sha256=(Get-Sha256 (Join-Path $negativeRun 'events.jsonl')); nonblank=[int]$negativeEvents.nonblank; recordCount=[int]$negativeEvents.recordCount; failures=@($negativeEvents.failures).Count; eventCounts=$negativeEvents.eventCounts }
            }
            negativeControls = [ordered]@{ launcher=$launcherNegatives.ToArray(); protocol=$protocolNegatives.ToArray() }
            commands = @(
                [ordered]@{ id='maponly-9a64'; description='Generate the identity 9A64 map/build through the accepted IL API'; exitCode=$mapChild.exit_code; sourceMapSha256=$mapInfo.sourceMapSha256; buildReportSha256=$mapInfo.buildReportSha256 },
                [ordered]@{ id='natural-9a64-session'; description='Fresh natural 9A64 caller-entry session: EF9C caller pause, four-instruction step-into, nonzero 7982 step, post-return and rearm'; exitCode=[int]$exitCodeText.Trim(); wallSeconds=$sessionWallSeconds; emulatedSeconds=120 },
                [ordered]@{ id='zero-target-9a64-session'; description='Fresh natural 9A64 paused session at the zero-only target 9A6E'; exitCode=[int]$zeroExitCodeText.Trim(); wallSeconds=$zeroWallSeconds; emulatedSeconds=120 }
            )
            limitations = @(
                'Only the fixed 9A64 identity definition and its two checked byte-branch handlers are supported.',
                'Only original-image 9A64 sessions are accepted; 9A64 edits, operand replacement and modified images are rejected.',
                'The nonzero 7982 step observed condition cell FFFF and followed the fall-through to 9A69. The zero path was observed naturally from the zero-only target 9A6E; the 7982 zero-condition cell was not itself single-stepped in this increment.',
                'The rearm command is pause-at-mapped-node from an observed post-return boundary; no call-step-over, arbitrary continuation or state injection is provided.',
                'Step-into covers only the explicit EF9C caller token and the exact four-instruction entry chain; there is no nested call stack, call-step-over, arbitrary step-out or interrupt boundary.',
                'No memory OR/clear effect is claimed; only observed native boundaries, branch operands/targets, U/S state and the post-return continuation are reported.',
                'No extension allocation, new word, native primitive, native C# executor or physical hardware compatibility is claimed.',
                'The EE16/EE22 paid-window comparison remains unchanged and was not retried.'
            )
            validation = [ordered]@{
                focusedTest = 'tests/worker/Test-IlNineA64DebugSession.ps1'
                priorSessionTest = 'tests/worker/Test-IlDebugSession.ps1'
                strictJsonHelper = 'tests/worker/Test-IlEventJson.ps1'
                manifestTool = 'tools/Update-CuratedManifest.ps1'
            }
        }
        $tempOutput = $OutputPath + '.tmp-' + [guid]::NewGuid().ToString('N')
        [IO.File]::WriteAllText($tempOutput,(ConvertTo-Json -InputObject $evidence -Depth 24),(New-Object System.Text.UTF8Encoding($false)))
        if ((Test-Path -LiteralPath $OutputPath) -and !$Force) {
            Remove-Item -LiteralPath $tempOutput -Force
            Write-Fail "Evidence output already exists (use -Force): $OutputPath"
        } else {
            Move-Item -LiteralPath $tempOutput -Destination $OutputPath -Force
            Write-Pass "Curated evidence written: $OutputPath"
        }
    }
}
finally {
    foreach ($processId in $script:OwnedProcesses) { Stop-OwnedProcess $processId }
}

Write-Output "Test-IlNineA64DebugSession: $($script:Checks) checks, $($script:Failures) failures"
Write-Output "RUNROOT=$RunRoot"
if ($script:Failures -gt 0) { exit 1 }

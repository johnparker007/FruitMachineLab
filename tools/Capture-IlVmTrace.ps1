[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$MameExecutable,
    [Parameter(Mandatory=$true)][string]$RomDirectory,
    [Parameter(Mandatory=$true)][string]$OriginalRom,
    [Parameter(Mandatory=$true)][string]$RepairedRom,
    [Parameter(Mandatory=$true)][string]$VariantRom,
    [Parameter(Mandatory=$true)][ValidateSet('Original','Changed')][string]$Variant,
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [string]$SourceMapPath,
    [string]$BuildReportPath,
    [string]$PlanPath,
    [string]$ReplayPath,
    [string]$InputLuaPath,
    [ValidateRange(1,120)][int]$SecondsToRun = 120,
    [ValidateRange(30,600)][int]$WallTimeoutSeconds = 600
)
$ErrorActionPreference = 'Stop'

$script:LtOriginalSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$script:LtOriginalSha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
$script:LtRepairedSha1 = 'e1a42dccd304b7b175aabac99e8400cdad04cf69'
$script:LtRepairedSha256 = '577f76bd36dfca04dfb01b5f5d0be93e16572f8617c7ca906397c98df36e5107'
$script:LtSourceMapSha256 = '0c39a6d0d1beac32ca0f64bfec5ce848b2297be41180d0234d2bfdf491df21a9'
$script:LtBuildReportSha256 = 'ae7e0fb2c0121e0b4e62d38e82511841644fcdf922b2d9e54de79b3d7e57f61a'
$script:LtReplaySha256 = '4a051da15264842697879eff396b34a789f5d80623f9a2e749c244e6a80e721d'
$script:LtMameSha256 = '0fce5a88df4f9d9b1fbf1405812c00848036e615993780978d967da34204cb7a'
$script:LtExpectedChangedOffsets = @(0x9EDC,0xFFD1,0xFFD2,0xFFD3,0xFFD4,0xFFD5)
$script:LtRoot = Split-Path $PSScriptRoot -Parent
if ([string]::IsNullOrWhiteSpace($SourceMapPath)) { $SourceMapPath = Join-Path $script:LtRoot 'artifacts/deepseek/il-boot-04/build-01/source-map.json' }
if ([string]::IsNullOrWhiteSpace($BuildReportPath)) { $BuildReportPath = Join-Path $script:LtRoot 'artifacts/deepseek/il-boot-04/build-01/build-report.json' }
if ([string]::IsNullOrWhiteSpace($PlanPath)) { $PlanPath = Join-Path $script:LtRoot 'evidence/mpu4/integrity/il-natural-reachability-plan.json' }
if ([string]::IsNullOrWhiteSpace($ReplayPath)) { $ReplayPath = Join-Path $script:LtRoot 'evidence/mpu4/skill-cash/actions.csv' }
if ([string]::IsNullOrWhiteSpace($InputLuaPath)) { $InputLuaPath = Join-Path $script:LtRoot 'evidence/mpu4/skill-cash/input.lua' }

function Get-LtHash {
    param([string]$Path,[string]$Algorithm)
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        try { return ([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Write-LtJson {
    param([string]$Path,$Object,[int]$Depth = 14)
    [IO.File]::WriteAllText($Path,(ConvertTo-Json -InputObject $Object -Depth $Depth),(New-Object System.Text.UTF8Encoding($false)))
}

function ConvertTo-LtHexInt {
    param([string]$Text)
    return [Convert]::ToInt32($Text,16)
}

function Format-LtOffsets {
    param([int[]]$Offsets)
    return (($Offsets | ForEach-Object { '{0:X4}' -f $_ }) -join ',')
}

function Get-LtChangedOffsets {
    param([byte[]]$A,[byte[]]$B)
    if ($A.Length -ne $B.Length) { throw 'Cannot compare different-length images' }
    $list = New-Object 'System.Collections.Generic.List[int]'
    for ($i=0;$i -lt $A.Length;$i++) { if ($A[$i] -ne $B[$i]) { [void]$list.Add($i) } }
    return $list.ToArray()
}

function Assert-LtRom {
    param([string]$Path,[int]$Length,[string]$Sha1,[string]$Sha256,[string]$Label)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label is missing: $Path" }
    $actualLength = (Get-Item -LiteralPath $Path).Length
    if ($actualLength -ne $Length) { throw "$Label length is $actualLength, expected $Length" }
    $actualSha1 = Get-LtHash $Path 'SHA1'
    $actualSha256 = Get-LtHash $Path 'SHA256'
    if ($actualSha1 -ine $Sha1) { throw "$Label SHA1 is $actualSha1, expected $Sha1" }
    if ($actualSha256 -ine $Sha256) { throw "$Label SHA256 is $actualSha256, expected $Sha256" }
    return [ordered]@{length=$actualLength;sha1=$actualSha1;sha256=$actualSha256}
}

function Get-LtVariantMap {
    param($SourceMap,[byte[]]$OriginalBytes,[byte[]]$RepairedBytes,[string]$Variant)
    if ($SourceMap.schemaVersion -ne 1) { throw 'Source map schemaVersion is not 1' }
    if ($SourceMap.originalRomSha256 -ine $script:LtOriginalSha256) { throw 'Source map original identity is stale or wrong' }
    if ($SourceMap.outputImageSha256 -ine $script:LtRepairedSha256) { throw 'Source map is not bound to the accepted repaired image' }
    if ($SourceMap.bodyStart -ne '9ED9' -or $SourceMap.bodyEndExclusive -ne '9EE7') { throw 'Source map body span is not 9ED9..9EE7' }
    $entries = @($SourceMap.entries)
    if ($entries.Count -ne 14) { throw "Source map has $($entries.Count) entries, expected 14" }
    $spanStart = ConvertTo-LtHexInt $SourceMap.bodyStart
    $spanEnd = ConvertTo-LtHexInt $SourceMap.bodyEndExclusive
    $expectedAddress = $spanStart
    $lastNode = -1
    foreach ($entry in $entries) {
        $address = ConvertTo-LtHexInt $entry.address
        if ($address -ne $expectedAddress) { throw "Source map is not contiguous at $($entry.address)" }
        if ($entry.nodeIndex -lt $lastNode) { throw "Source map node order is reordered at $($entry.address)" }
        if ($entry.nodeIndex -gt $lastNode) {
            if ($entry.nodeIndex -ne ($lastNode + 1)) { throw "Source map node index gap at $($entry.address)" }
            $lastNode = $entry.nodeIndex
        }
        $imageByte = [Convert]::ToInt32($entry.imageByte,16)
        if ($imageByte -ne $RepairedBytes[$address]) { throw "Source map byte at $($entry.address) differs from the repaired image" }
        $expectedAddress++
    }
    if ($expectedAddress -ne $spanEnd) { throw 'Source map does not cover the declared body end' }
    if ($lastNode -ne 4) { throw 'Source map does not contain the five checked node indices 0..4' }

    $sourceDifferences = Get-LtChangedOffsets $OriginalBytes $RepairedBytes
    if (($sourceDifferences -join ',') -ne ($script:LtExpectedChangedOffsets -join ',')) {
        throw "Original/repaired diff is $(Format-LtOffsets $sourceDifferences), expected 9EDC,FFD1,FFD2,FFD3,FFD4,FFD5"
    }
    $spanDifference = @($sourceDifferences | Where-Object { $_ -ge $spanStart -and $_ -lt $spanEnd })
    if (($spanDifference -join ',') -ne '40668') { throw "The only source-map span difference must be 9EDC, found $(Format-LtOffsets $spanDifference)" }

    $variantEntries = New-Object 'System.Collections.Generic.List[object]'
    foreach ($entry in $entries) {
        $address = ConvertTo-LtHexInt $entry.address
        $byte = if ($Variant -eq 'Original') { $OriginalBytes[$address] } else { $RepairedBytes[$address] }
        $variantEntries.Add([ordered]@{
            address = '{0:X4}' -f $address
            nodeIndex = [int]$entry.nodeIndex
            token = [string]$entry.token
            operation = [string]$entry.operation
            imageByte = '{0:X2}' -f $byte
        })
    }
    $imageSha = if ($Variant -eq 'Original') { $script:LtOriginalSha256 } else { $script:LtRepairedSha256 }
    return [ordered]@{
        schemaVersion = 1
        variant = $Variant
        originalRomSha256 = $script:LtOriginalSha256
        outputImageSha256 = $imageSha
        bodyStart = '9ED9'
        bodyEndExclusive = '9EE7'
        entries = $variantEntries.ToArray()
    }
}

function Get-LtNodes {
    param($VariantMap)
    $nodes = New-Object 'System.Collections.Generic.List[object]'
    $byIndex = @{}
    foreach ($entry in @($VariantMap.entries)) {
        $index = [int]$entry.nodeIndex
        if (!$byIndex.ContainsKey($index)) {
            $byIndex[$index] = [ordered]@{
                index = $index
                address = $entry.address
                token = $entry.token
                operation = $entry.operation
                bytes = New-Object 'System.Collections.Generic.List[int]'
            }
            $nodes.Add($byIndex[$index])
        }
        [void]$byIndex[$index].bytes.Add([Convert]::ToInt32($entry.imageByte,16))
    }
    return $nodes.ToArray()
}

function Get-LtPlan {
    param([string]$Path)
    $plan = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    $handlers = @($plan.vm_observation_boundaries.handler_entries)
    if ($handlers.Count -lt 4) { throw 'handler-entry plan is incomplete' }
    $callSiteText = [string]$plan.vm_observation_boundaries.composite_entry_limit.call_site
    if ($callSiteText -notmatch '^([0-9A-Fa-f]{4}) ') { throw 'plan call site is not a 4-digit hex address' }
    return [ordered]@{
        plan = $plan
        handlers = $handlers
        callSite = $Matches[1].ToUpperInvariant()
    }
}

function Write-LtLuaMap {
    param([string]$Path,$VariantMap,$Nodes,$Handlers)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('return {')
    [void]$sb.AppendLine('  schemaVersion = 1,')
    [void]$sb.AppendLine(('  variant = "{0}",' -f $VariantMap.variant))
    [void]$sb.AppendLine(('  imageSha256 = "{0}",' -f $VariantMap.outputImageSha256))
    [void]$sb.AppendLine(('  originalRomSha256 = "{0}",' -f $VariantMap.originalRomSha256))
    [void]$sb.AppendLine(('  bodyStart = 0x{0},' -f $VariantMap.bodyStart))
    [void]$sb.AppendLine(('  bodyEndExclusive = 0x{0},' -f $VariantMap.bodyEndExclusive))
    [void]$sb.AppendLine('  nodes = {')
    foreach ($node in $Nodes) {
        $bytes = (@($node.bytes) | ForEach-Object { '0x{0:X2}' -f $_ }) -join ','
        [void]$sb.AppendLine(('    {{ index = {0}, address = 0x{1}, token = 0x{2}, operation = "{3}", bytes = {{{4}}} }},' -f $node.index,$node.address,$node.token,$node.operation,$bytes))
    }
    [void]$sb.AppendLine('  },')
    [void]$sb.AppendLine('  entries = {')
    foreach ($entry in @($VariantMap.entries)) {
        [void]$sb.AppendLine(('    {{ address = 0x{0}, nodeIndex = {1}, token = 0x{2}, operation = "{3}", imageByte = 0x{4} }},' -f $entry.address,$entry.nodeIndex,$entry.token,$entry.operation,$entry.imageByte))
    }
    [void]$sb.AppendLine('  },')
    [void]$sb.AppendLine('  handlers = {')
    foreach ($handler in @($Handlers)) {
        [void]$sb.AppendLine(('    {{ address = 0x{0}, operation = "{1}" }},' -f $handler.pc,$handler.operation))
    }
    [void]$sb.AppendLine('  },')
    [void]$sb.AppendLine('  positiveControl = { start = 0x66A0, stop = 0x66F0 },')
    [void]$sb.AppendLine('}')
    [IO.File]::WriteAllText($Path,$sb.ToString(),(New-Object System.Text.UTF8Encoding($false)))
}

function Write-LtDebuggerCommands {
    param([string]$Path,$VariantMap,$Nodes,$PlanInfo)
    $handlerByOperation = @{}
    foreach ($handler in @($PlanInfo.handlers)) { $handlerByOperation[[string]$handler.operation] = [string]$handler.pc }
    $callSite = $PlanInfo.callSite
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $prefetchFormat = 'printf "EVENT NODE_PREFETCH index=%d y=%04X token=%04X x=%04X u=%04X s=%04X top=%04X second=%04X third=%04X fourth=%04X sw0=%04X sw1=%04X cycle=%016X\n",{0},y,w@y,x,u,s,w@u,w@(u+2),w@(u+4),w@(u+6),w@s,w@(s+2),totalcycles'
    $handlerFormat = 'printf "EVENT HANDLER_ENTRY index=%d pc=%04X token=%04X x=%04X y=%04X u=%04X s=%04X top=%04X second=%04X third=%04X fourth=%04X sw0=%04X sw1=%04X cycle=%016X\n",{0},pc,w@(y-2),x,y,u,s,w@u,w@(u+2),w@(u+4),w@(u+6),w@s,w@(s+2),totalcycles'
    $returnFormat = 'printf "EVENT RETURN_HANDLER index=%d pc=%04X token=%04X x=%04X y=%04X u=%04X s=%04X saved_cursor=%04X top=%04X second=%04X cycle=%016X\n",{0},pc,w@(y-2),x,y,u,s,w@s,w@u,w@(u+2),totalcycles;temp6=w@s'
    $postFormat = 'printf "EVENT POST_RETURN_CALLER_PREFETCH y=%04X token=%04X x=%04X u=%04X s=%04X w_at_s=%04X cycle=%016X\n",y,w@y,x,u,s,w@s,totalcycles;temp7=1;quit'
    $callFormat = 'printf "EVENT CALLSITE_PREFETCH y=%04X token=%04X x=%04X u=%04X s=%04X cycle=%016X\n",y,w@y,x,u,s,totalcycles;temp8=1'
    $compositeFormat = 'printf "EVENT COMPOSITE_ENTRY pc=%04X x=%04X y=%04X saved_caller_y=%04X s=%04X cycle=%016X\n",pc,x,y,y,s,totalcycles;temp9=1'

    for ($i = 0; $i -lt $Nodes.Count; $i++) {
        $node = $Nodes[$i]
        $condition = @()
        if ($i -gt 0) { $condition += "temp$($i-1)==1" }
        $condition += "temp$i==0"
        $condition += "y==0x$($node.address.ToLowerInvariant())"
        $action = '{' + ($prefetchFormat -f $i) + ';temp' + $i + '=1;go}'
        $lines.Add(('bpset 0xfc,' + ($condition -join ' && ') + ',' + $action))
    }
    for ($i = 0; $i -lt $Nodes.Count; $i++) {
        $node = $Nodes[$i]
        $handler = $handlerByOperation[$node.operation]
        if ([string]::IsNullOrWhiteSpace($handler)) { throw "no handler entry for operation $($node.operation)" }
        $condition = @("temp$i==1", ('pc==0x' + $handler.ToLowerInvariant()), ('y==0x' + ('{0:X4}' -f ((ConvertTo-LtHexInt $node.address) + 2)).ToLowerInvariant()))
        if ($i -eq 4) {
            $action = '{' + ($returnFormat -f $i) + ';temp5=1;go}'
        } else {
            $action = '{' + ($handlerFormat -f $i) + ';go}'
        }
        $lines.Add(('bpset 0x' + $handler.ToLowerInvariant() + ',' + ($condition -join ' && ') + ',' + $action))
    }
    $lines.Add(('bpset 0xfc,temp8==0 && y==0x' + $callSite.ToLowerInvariant() + ',{' + $callFormat + ';go}'))
    $lines.Add(('bpset 0xf8,temp9==0 && temp8==1 && pc==0xf8 && x==0x' + $Nodes[0].address.ToLowerInvariant() + ',{' + $compositeFormat + ';go}'))
    $lines.Add(('bpset 0xfc,temp5==1 && temp7==0 && y==temp6,{' + $postFormat + '}'))
    $lines.Add('gtime #120000')
    $lines.Add('quit')
    [IO.File]::WriteAllLines($Path, $lines, (New-Object System.Text.UTF8Encoding($false)))
}

function ConvertTo-LtArgumentString {
    param([string[]]$Arguments)
    $quoted = foreach ($arg in $Arguments) {
        $text = [string]$arg
        if ($text -match '[\s"]') { '"' + $text.Replace('"','\"') + '"' } else { $text }
    }
    return ($quoted -join ' ')
}

function Invoke-LtProcess {
    param([string]$FilePath,[string[]]$Arguments,[string]$WorkingDirectory,[string]$StdOutPath,[string]$StdErrPath,[int]$TimeoutSeconds)
    $argumentString = ConvertTo-LtArgumentString $Arguments
    $startUtc = [DateTime]::UtcNow
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = [IO.Path]::GetFullPath($FilePath)
    $startInfo.Arguments = $argumentString
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw "Failed to start process: $FilePath" }
    $processId = $process.Id
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $timedOut = $false
    $exitCode = $null
    try {
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $timedOut = $true
            $taskkill = Join-Path $env:SystemRoot 'System32/taskkill.exe'
            & $taskkill /PID $processId /T /F 2>&1 | Out-Null
            $process.WaitForExit(30000) | Out-Null
        }
        if ($process.HasExited) { $exitCode = $process.ExitCode }
        [IO.File]::WriteAllText($StdOutPath,$stdoutTask.GetAwaiter().GetResult(),(New-Object System.Text.UTF8Encoding($false)))
        [IO.File]::WriteAllText($StdErrPath,$stderrTask.GetAwaiter().GetResult(),(New-Object System.Text.UTF8Encoding($false)))
    }
    finally {
        $stopwatch.Stop()
        if (-not $process.HasExited) {
            $taskkill = Join-Path $env:SystemRoot 'System32/taskkill.exe'
            & $taskkill /PID $processId /T /F 2>&1 | Out-Null
            $process.WaitForExit(30000) | Out-Null
            if ($process.HasExited) { $exitCode = $process.ExitCode }
        }
        $process.Dispose()
    }
    return [ordered]@{
        command_id = 'mame-il-native-debugger-capture'
        description = 'Fresh isolated source-map-derived native debugger capture with Lua input/state observer'
        command_line = $argumentString
        start_utc = $startUtc.ToString('o')
        end_utc = [DateTime]::UtcNow.ToString('o')
        wall_seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds,3)
        timeout_seconds = $TimeoutSeconds
        timed_out = $timedOut
        exit_code = $exitCode
        process_id = $processId
    }
}

function ConvertTo-LtEvent {
    param([string]$Line)
    if ($Line -notmatch '^EVENT\s+(\S+)\s+(.*)$') { return $null }
    $name = $Matches[1]
    $rest = $Matches[2]
    $fields = [ordered]@{ event = $name }
    foreach ($match in [regex]::Matches($rest, '([A-Za-z_][A-Za-z0-9_]*)=([0-9A-Fa-f]+)')) {
        $fields[$match.Groups[1].Value] = $match.Groups[2].Value
    }
    return $fields
}

function Get-LtBoundaryEvents {
    param([string]$DebugLogPath)
    if (!(Test-Path -LiteralPath $DebugLogPath -PathType Leaf)) { throw "debug log is missing: $DebugLogPath" }
    $events = New-Object 'System.Collections.Generic.List[object]'
    foreach ($line in Get-Content -LiteralPath $DebugLogPath) {
        $event = ConvertTo-LtEvent $line
        if ($null -ne $event) { $events.Add($event) }
    }
    if ($events.Count -eq 0) { throw 'debug log contains no exact-boundary events' }
    return $events.ToArray()
}

function Assert-LtBoundaryEvents {
    param($Events,$VariantMap,$Nodes,$PlanInfo,[byte[]]$ImageBytes)
    $nodeEvents = @($Events | Where-Object { $_.event -eq 'NODE_PREFETCH' })
    $handlerEvents = @($Events | Where-Object { $_.event -eq 'HANDLER_ENTRY' -or $_.event -eq 'RETURN_HANDLER' })
    $postEvents = @($Events | Where-Object { $_.event -eq 'POST_RETURN_CALLER_PREFETCH' })
    if ($nodeEvents.Count -ne 5) { throw "expected five node prefetches, found $($nodeEvents.Count)" }
    if ($handlerEvents.Count -ne 5) { throw "expected five handler entries, found $($handlerEvents.Count)" }
    if ($postEvents.Count -ne 1) { throw "expected one post-return caller prefetch, found $($postEvents.Count)" }
    $handlerByOperation = @{}
    foreach ($handler in @($PlanInfo.handlers)) { $handlerByOperation[[string]$handler.operation] = [string]$handler.pc }
    for ($i=0;$i -lt 5;$i++) {
        $node = $Nodes[$i]
        $ev = $nodeEvents[$i]
        if ([int]$ev.index -ne $i) { throw "node prefetch order is wrong at index $i" }
        if ([string]$ev.y -ine $node.address) { throw "node $i prefetch Y is $($ev.y), expected $($node.address)" }
        if ([string]$ev.token -ine $node.token) { throw "node $i token is $($ev.token), expected $($node.token)" }
        if ($i -eq 0 -and [string]$ev.x -ine $node.address) { throw "initial prefetch X is $($ev.x), expected the composite body address $($node.address)" }
        $handler = $handlerEvents[$i]
        if ([int]$handler.index -ne $i) { throw "handler order is wrong at index $i" }
        $expectedHandler = $handlerByOperation[$node.operation]
        if ([string]$handler.pc -ine $expectedHandler) { throw "handler $i PC is $($handler.pc), expected $expectedHandler" }
        $expectedY = '{0:X4}' -f ((ConvertTo-LtHexInt $node.address) + 2)
        if ([string]$handler.y -ine $expectedY) { throw "handler $i Y is $($handler.y), expected $expectedY" }
        if ([string]$handler.token -ine $node.token) { throw "handler $i token is $($handler.token), expected $($node.token)" }
        if ([string]$handler.x -ine $expectedHandler) { throw "handler $i X is $($handler.x), expected token pointer+2 $expectedHandler" }
        if ($i -eq 4 -and $handler.event -ne 'RETURN_HANDLER') { throw 'handler 4 is not the RETURN_HANDLER event' }
        if ($i -lt 4 -and $handler.event -ne 'HANDLER_ENTRY') { throw "handler $i has the wrong event name" }
    }
    $firstLiteral = ([int]$ImageBytes[(ConvertTo-LtHexInt $Nodes[0].address)+2] -shl 8) -bor [int]$ImageBytes[(ConvertTo-LtHexInt $Nodes[0].address)+3]
    $secondLiteral = ([int]$ImageBytes[(ConvertTo-LtHexInt $Nodes[2].address)+2] -shl 8) -bor [int]$ImageBytes[(ConvertTo-LtHexInt $Nodes[2].address)+3]
    $expectedResult = $firstLiteral -bxor $secondLiteral
    if ([Convert]::ToInt32([string]$nodeEvents[0].top,16) -ne 0) { throw 'first node prefetch does not start from a zero data-stack top' }
    if ([Convert]::ToInt32([string]$nodeEvents[1].top,16) -ne $firstLiteral) { throw 'node 1 stack top does not match the first inline literal' }
    if ([Convert]::ToInt32([string]$nodeEvents[3].top,16) -ne $secondLiteral) { throw 'node 3 stack top does not match the second inline literal' }
    if ([Convert]::ToInt32([string]$nodeEvents[3].second,16) -ne $firstLiteral) { throw 'node 3 second stack word does not match the first inline literal' }
    if ([Convert]::ToInt32([string]$nodeEvents[4].top,16) -ne $expectedResult) { throw "node 4 result is $($nodeEvents[4].top), expected $('{0:X4}' -f $expectedResult)" }
    $returnEvent = $handlerEvents[4]
    $savedCursor = [string]$returnEvent.saved_cursor
    $post = $postEvents[0]
    if ([string]$post.y -ine $savedCursor) { throw "post-return Y is $($post.y), expected saved caller cursor $savedCursor" }
    $returnS = [Convert]::ToInt32([string]$returnEvent.s,16)
    $postS = [Convert]::ToInt32([string]$post.s,16)
    if ($postS -ne $returnS + 2) { throw "post-return S is $('{0:X4}' -f $postS), expected PULS increment of $('{0:X4}' -f ($returnS+2))" }
    return [ordered]@{
        node_prefetches = $nodeEvents
        handler_entries = $handlerEvents
        return_handler = $returnEvent
        post_return = $post
        first_literal = '{0:X4}' -f $firstLiteral
        second_literal = '{0:X4}' -f $secondLiteral
        result = '{0:X4}' -f $expectedResult
        saved_cursor = $savedCursor
    }
}

$run = [IO.Path]::GetFullPath($RunDirectory)
if (Test-Path -LiteralPath $run) { throw "Use a fresh create-only run directory: $run" }
foreach ($path in @($MameExecutable,$SourceMapPath,$BuildReportPath,$PlanPath,$ReplayPath,$InputLuaPath)) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file is missing: $path" }
}
if (!(Test-Path -LiteralPath $RomDirectory -PathType Container)) { throw "Installed ROM directory is missing: $RomDirectory" }

$sourceMapHash = Get-LtHash $SourceMapPath 'SHA256'
if ($sourceMapHash -ine $script:LtSourceMapSha256) { throw "Source map SHA256 is $sourceMapHash, expected $($script:LtSourceMapSha256)" }
$buildReportHash = Get-LtHash $BuildReportPath 'SHA256'
if ($buildReportHash -ine $script:LtBuildReportSha256) { throw "Build report SHA256 is $buildReportHash, expected $($script:LtBuildReportSha256)" }
$replayHash = Get-LtHash $ReplayPath 'SHA256'
if ($replayHash -ine $script:LtReplaySha256) { throw "Replay SHA256 is $replayHash, expected $($script:LtReplaySha256)" }
$mameHash = Get-LtHash $MameExecutable 'SHA256'
if ($mameHash -ine $script:LtMameSha256) { throw "MAME SHA256 is $mameHash, expected $($script:LtMameSha256)" }
$planHash = Get-LtHash $PlanPath 'SHA256'
$inputLuaHash = Get-LtHash $InputLuaPath 'SHA256'

$originalIdentity = Assert-LtRom $OriginalRom 65536 $script:LtOriginalSha1 $script:LtOriginalSha256 'original ROM'
$repairedIdentity = Assert-LtRom $RepairedRom 65536 $script:LtRepairedSha1 $script:LtRepairedSha256 'repaired ROM'
$expectedVariant = if ($Variant -eq 'Original') { @{ Sha1=$script:LtOriginalSha1; Sha256=$script:LtOriginalSha256 } } else { @{ Sha1=$script:LtRepairedSha1; Sha256=$script:LtRepairedSha256 } }
$variantIdentity = Assert-LtRom $VariantRom 65536 $expectedVariant.Sha1 $expectedVariant.Sha256 "$Variant ROM"
$originalBytes = [IO.File]::ReadAllBytes($OriginalRom)
$repairedBytes = [IO.File]::ReadAllBytes($RepairedRom)
$variantBytes = [IO.File]::ReadAllBytes($VariantRom)
$actualChanged = Get-LtChangedOffsets $originalBytes $repairedBytes
if ($Variant -eq 'Original') {
    if ((Get-LtChangedOffsets $variantBytes $originalBytes).Count -ne 0) { throw 'Original variant image differs from the original ROM' }
} else {
    if ((Get-LtChangedOffsets $variantBytes $repairedBytes).Count -ne 0) { throw 'Changed variant image differs from the repaired ROM' }
}

$sourceMap = Get-Content -LiteralPath $SourceMapPath -Raw | ConvertFrom-Json
$buildReport = Get-Content -LiteralPath $BuildReportPath -Raw | ConvertFrom-Json
if ($buildReport.original.sha256 -ine $script:LtOriginalSha256) { throw 'Build report original identity is wrong' }
if ($buildReport.repaired.sha256 -ine $script:LtRepairedSha256) { throw 'Build report repaired identity is wrong' }
if ($buildReport.sourceMap.outputImageSha256 -ine $script:LtRepairedSha256) { throw 'Build report source map is not bound to the repaired image' }
if ($buildReport.sourceMap.originalRomSha256 -ine $script:LtOriginalSha256) { throw 'Build report source map original identity is wrong' }
if ($buildReport.edit.nodeIndex -ne 0) { throw 'Build report edit node is not zero' }
if ($buildReport.edit.operandAddress -ne '9EDB') { throw 'Build report operand address is not 9EDB' }
if ($buildReport.edit.replacementValue -ne 'FF00') { throw 'Build report replacement is not FF00' }
if (!$buildReport.checks.sourceMapBoundToRepairedSha256) { throw 'Build report does not assert source-map binding' }

$planInfo = Get-LtPlan $PlanPath
$variantMap = Get-LtVariantMap $sourceMap $originalBytes $repairedBytes $Variant
$nodes = Get-LtNodes $variantMap
if ($nodes.Count -ne 5) { throw "Expected five source-map nodes, found $($nodes.Count)" }
$handlers = @($planInfo.handlers)

New-Item -ItemType Directory -Path $run -ErrorAction Stop | Out-Null
foreach ($name in @('roms/m4addr','cfg','nvram','inp','snap','comments','state','diff')) { New-Item -ItemType Directory -Path (Join-Path $run $name) -ErrorAction Stop | Out-Null }
$runRom = Join-Path $run 'roms/m4addr/a6ls.p1'
Copy-Item -LiteralPath $VariantRom -Destination $runRom -ErrorAction Stop
$runRomIdentity = Assert-LtRom $runRom 65536 $expectedVariant.Sha1 $expectedVariant.Sha256 'isolated run ROM copy'
Copy-Item -LiteralPath $ReplayPath -Destination (Join-Path $run 'replay-actions.csv') -ErrorAction Stop
Copy-Item -LiteralPath $InputLuaPath -Destination (Join-Path $run 'input.lua') -ErrorAction Stop
Copy-Item -LiteralPath (Join-Path $script:LtRoot 'tools/lua/IlVmTrace.lua') -Destination (Join-Path $run 'IlVmTrace.lua') -ErrorAction Stop
[IO.File]::WriteAllText((Join-Path $run 'observer.lua'),"dofile('input.lua')`ndofile('IlVmTrace.lua')`n",(New-Object System.Text.UTF8Encoding($false)))
$variantMapDocument = [ordered]@{
    schemaVersion = 1
    variant = $variantMap.variant
    originalRomSha256 = $variantMap.originalRomSha256
    outputImageSha256 = $variantMap.outputImageSha256
    bodyStart = $variantMap.bodyStart
    bodyEndExclusive = $variantMap.bodyEndExclusive
    entries = @($variantMap.entries)
    nodes = @($nodes)
}
Write-LtJson (Join-Path $run 'variant-map.json') $variantMapDocument 12
Write-LtLuaMap (Join-Path $run 'trace-map.lua') $variantMap $nodes $handlers
Write-LtDebuggerCommands (Join-Path $run 'debugger.cmd') $variantMap $nodes $planInfo
$debuggerText = Get-Content -LiteralPath (Join-Path $run 'debugger.cmd') -Raw
if ($debuggerText -match '(?im)^\s*(save|load|state|playback|wp(set|clear|enable|disable)|pc\s*=|x\s*=|y\s*=|u\s*=|s\s*=)') {
    throw 'Generated debugger commands contain a forbidden state or register write'
}

$preRunEmpty = [ordered]@{}
foreach ($name in @('cfg','nvram','inp','snap','comments','state','diff')) { $preRunEmpty[$name] = @(Get-ChildItem -LiteralPath (Join-Path $run $name) -Recurse -File -ErrorAction SilentlyContinue).Count }
$preRunRomFiles = @(Get-ChildItem -LiteralPath (Join-Path $run 'roms/m4addr') -File | ForEach-Object { $_.Name } | Sort-Object)
if (($preRunRomFiles -join ',') -ne 'a6ls.p1') { throw 'Isolated ROM directory must contain exactly a6ls.p1 before launch' }
foreach ($key in $preRunEmpty.Keys) { if ($preRunEmpty[$key] -ne 0) { throw "Pre-run directory $key is not empty" } }
Write-LtJson (Join-Path $run 'pre-run-empty.json') $preRunEmpty 6

$versionOut = Join-Path $run 'mame-version.txt'
$versionErr = Join-Path $run 'mame-version.err.txt'
$versionRecord = Invoke-LtProcess $MameExecutable @('-version') $run $versionOut $versionErr 60
if ($versionRecord.timed_out -or $versionRecord.exit_code -ne 0) { throw "MAME -version failed: exit=$($versionRecord.exit_code)" }
$mameVersion = ((Get-Content -LiteralPath $versionOut -Raw).Trim() -split "\r?\n")[0]
if ($mameVersion -notmatch '^0\.281\b') { throw "Unexpected MAME version: $mameVersion" }

$arguments = @('m4addr','-noreadconfig','-rompath',((Join-Path $run 'roms')+';'+$RomDirectory),
    '-cfg_directory',(Join-Path $run 'cfg'),'-nvram_directory',(Join-Path $run 'nvram'),
    '-input_directory',(Join-Path $run 'inp'),'-snapshot_directory',(Join-Path $run 'snap'),
    '-comment_directory',(Join-Path $run 'comments'),'-state_directory',(Join-Path $run 'state'),
    '-diff_directory',(Join-Path $run 'diff'),'-debug','-debugger','windows',
    '-debugscript',(Join-Path $run 'debugger.cmd'),'-debuglog',
    '-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle',
    '-seconds_to_run',[string]$SecondsToRun,'-autoboot_delay','0',
    '-autoboot_script',(Join-Path $run 'observer.lua'))
Write-LtJson (Join-Path $run 'arguments.json') @($arguments) 6
$traceMapHash = Get-LtHash (Join-Path $run 'trace-map.lua') 'SHA256'
$variantMapHash = Get-LtHash (Join-Path $run 'variant-map.json') 'SHA256'
$observerHash = Get-LtHash (Join-Path $run 'IlVmTrace.lua') 'SHA256'
$debuggerHash = Get-LtHash (Join-Path $run 'debugger.cmd') 'SHA256'
Write-LtJson (Join-Path $run 'provenance.json') ([ordered]@{
    classification = 'Fresh-isolated natural MAME 0.281 run with tracked physical-input replay. Exact instruction boundaries come from source-map/plan-derived native debugger breakpoints; Lua supplies map/live-byte validation, physical input and frame-sampled state.'
    variant = $Variant
    original_rom_sha1 = $originalIdentity.sha1
    original_rom_sha256 = $originalIdentity.sha256
    repaired_rom_sha1 = $repairedIdentity.sha1
    repaired_rom_sha256 = $repairedIdentity.sha256
    variant_rom_sha1 = $variantIdentity.sha1
    variant_rom_sha256 = $variantIdentity.sha256
    run_rom_sha1_before = $runRomIdentity.sha1
    run_rom_sha256_before = $runRomIdentity.sha256
    original_repaired_diff_hex = Format-LtOffsets ($actualChanged | Sort-Object)
    source_map_path = $SourceMapPath
    source_map_sha256 = $sourceMapHash
    build_report_path = $BuildReportPath
    build_report_sha256 = $buildReportHash
    plan_path = $PlanPath
    plan_sha256 = $planHash
    variant_map_sha256 = $variantMapHash
    trace_map_sha256 = $traceMapHash
    debugger_commands_sha256 = $debuggerHash
    observer_sha256 = $observerHash
    replay_path = 'evidence/mpu4/skill-cash/actions.csv'
    replay_sha256 = $replayHash
    input_lua_sha256 = $inputLuaHash
    mame_executable = [IO.Path]::GetFullPath($MameExecutable)
    mame_sha256 = $mameHash
    mame_version = $mameVersion
    seconds_to_run = $SecondsToRun
    wall_timeout_seconds = $WallTimeoutSeconds
    starting_nvram = 'absent'
    starting_configuration = 'absent; -noreadconfig'
    save_state_loaded = $false
    debugger_used = $true
    debugger_writes = $false
    exact_boundary_source = 'native MAME debugger bpset/printf actions generated from the checked source map and handler-entry plan'
    physical_inputs = 'tracked replay only; no PC/RAM/register/ROM injection'
    pre_run_empty_directory_file_counts = $preRunEmpty
    pre_run_rom_directory_files = $preRunRomFiles
}) 14

$leasePath = Join-Path $run 'command-lease.json'
$consolePath = Join-Path $run 'console.txt'
$consoleErrorPath = Join-Path $run 'console.err.txt'
$previousReplay = $env:MPU4_REPLAY
$previousPolicy = $env:MPU4_POLICY
$previousMap = $env:FML_IL_MAP_TABLE
$previousVariant = $env:FML_IL_VARIANT
$previousImage = $env:FML_IL_IMAGE_SHA256
$previousOriginal = $env:FML_IL_ORIGINAL_SHA256
$previousSeconds = $env:FML_IL_SECONDS
try {
    $env:MPU4_REPLAY = Join-Path $run 'replay-actions.csv'
    $env:MPU4_POLICY = '7'
    $env:FML_IL_MAP_TABLE = Join-Path $run 'trace-map.lua'
    $env:FML_IL_VARIANT = $Variant
    $env:FML_IL_IMAGE_SHA256 = $expectedVariant.Sha256
    $env:FML_IL_ORIGINAL_SHA256 = $script:LtOriginalSha256
    $env:FML_IL_SECONDS = [string]$SecondsToRun
    $runRecord = Invoke-LtProcess $MameExecutable $arguments $run $consolePath $consoleErrorPath $WallTimeoutSeconds
}
finally {
    $env:MPU4_REPLAY = $previousReplay
    $env:MPU4_POLICY = $previousPolicy
    $env:FML_IL_MAP_TABLE = $previousMap
    $env:FML_IL_VARIANT = $previousVariant
    $env:FML_IL_IMAGE_SHA256 = $previousImage
    $env:FML_IL_ORIGINAL_SHA256 = $previousOriginal
    $env:FML_IL_SECONDS = $previousSeconds
}
Write-LtJson $leasePath $runRecord 8
Set-Content -LiteralPath (Join-Path $run 'exit-code.txt') -Value ([string]$runRecord.exit_code) -NoNewline

$capPath = Join-Path $run 'lua-capability.csv'
$samplePath = Join-Path $run 'lua-samples.csv'
$tapPath = Join-Path $run 'lua-boundary-taps.csv'
$debugLogPath = Join-Path $run 'debug.log'
if (!(Test-Path -LiteralPath $capPath -PathType Leaf)) { throw "Lua observer did not produce lua-capability.csv; exit=$($runRecord.exit_code) timed_out=$($runRecord.timed_out)" }
if (!(Test-Path -LiteralPath $debugLogPath -PathType Leaf)) { throw "Native debugger did not produce debug.log; exit=$($runRecord.exit_code) timed_out=$($runRecord.timed_out)" }
$capLines = @(Get-Content -LiteralPath $capPath)
$mapLine = @($capLines | Where-Object { $_ -like 'MAP_OK,*' })
$debuggerLine = @($capLines | Where-Object { $_ -like 'manager_machine_debugger_type,*' })
$cpuDebugLine = @($capLines | Where-Object { $_ -like 'cpu_debug_type,*' })
$boundaryLine = @($capLines | Where-Object { $_ -like 'BOUNDARY_SUPPORT=*' })
$summaryLine = @($capLines | Where-Object { $_ -like 'SUMMARY,*' })
if ($mapLine.Count -ne 1) { throw 'Lua capability log is missing MAP_OK' }
if ($debuggerLine.Count -ne 1 -or $debuggerLine[0] -notmatch 'manager_machine_debugger_type,userdata') { throw 'Lua capability log does not record manager.machine.debugger=userdata' }
if ($cpuDebugLine.Count -ne 1 -or $cpuDebugLine[0] -notmatch 'cpu_debug_type,userdata') { throw 'Lua capability log does not record cpu.debug=userdata' }
if ($boundaryLine.Count -lt 1 -or $boundaryLine[0] -notmatch 'native_debugger_breakpoints') { throw 'Lua capability log does not name native debugger breakpoints' }
$positiveHits = 0
$boundaryHits = 0
$sampleCount = 0
if ($summaryLine.Count -eq 1) {
    $summary = $summaryLine[0]
    if ($summary -match 'positive_control_hits=(\d+)') { $positiveHits = [int]$Matches[1] }
    if ($summary -match 'boundary_tap_hits=(\d+)') { $boundaryHits = [int]$Matches[1] }
    if ($summary -match 'frame_samples=(\d+)') { $sampleCount = [int]$Matches[1] }
}
if (Test-Path -LiteralPath $tapPath -PathType Leaf) {
    $tapRows = @(Get-Content -LiteralPath $tapPath | Where-Object { $_ -match '^positive-control,' -or $_ -match '^node-' -or $_ -match '^handler-' })
    $positiveHits = @($tapRows | Where-Object { $_ -match '^positive-control,' }).Count
    $boundaryHits = @($tapRows | Where-Object { $_ -match '^node-' -or $_ -match '^handler-' }).Count
}
if (Test-Path -LiteralPath $samplePath -PathType Leaf) {
    $sampleCount = @(Get-Content -LiteralPath $samplePath | Where-Object { $_ -match '^\d+,' }).Count
}
if ($positiveHits -le 0) { throw 'Lua read-tap positive control never fired; tap capability is unproven' }

$events = Get-LtBoundaryEvents $debugLogPath
$checked = Assert-LtBoundaryEvents $events $variantMap $nodes $planInfo $variantBytes
$postRunRom = Assert-LtRom $runRom 65536 $expectedVariant.Sha1 $expectedVariant.Sha256 'isolated run ROM copy after execution'
$stateFiles = @(Get-ChildItem -LiteralPath (Join-Path $run 'state') -Recurse -File -ErrorAction SilentlyContinue)
if ($stateFiles.Count -ne 0) { throw 'State directory contains files; a save state may have been seeded or written' }

$observation = [ordered]@{
    variant = $Variant
    classification = 'Fresh-isolated natural run; exact boundaries from source-map/plan-derived native debugger hooks; Lua map/live-byte validation, input and frame samples'
    exit_code = $runRecord.exit_code
    timed_out = $runRecord.timed_out
    wall_seconds = $runRecord.wall_seconds
    emulated_seconds_limit = $SecondsToRun
    run_rom_sha1_after = $postRunRom.sha1
    run_rom_sha256_after = $postRunRom.sha256
    rom_unchanged = ($postRunRom.sha1 -ieq $expectedVariant.Sha1 -and $postRunRom.sha256 -ieq $expectedVariant.Sha256)
    source_map_sha256 = $sourceMapHash
    build_report_sha256 = $buildReportHash
    plan_sha256 = $planHash
    variant_map_sha256 = $variantMapHash
    trace_map_sha256 = $traceMapHash
    debugger_commands_sha256 = $debuggerHash
    observer_sha256 = $observerHash
    replay_sha256 = $replayHash
    mame_sha256 = $mameHash
    mame_version = $mameVersion
    manager_machine_debugger = 'userdata'
    cpu_debug = 'userdata'
    lua_instruction_callback_supported = $false
    native_debugger_exact_boundaries = $true
    complete_call_proof = $true
    map_live_bytes_ok = $true
    map_entries = 14
    map_nodes = 5
    positive_control_tap_hits = $positiveHits
    boundary_tap_hits = $boundaryHits
    frame_sample_count = $sampleCount
    lua_capability_sha256 = Get-LtHash $capPath 'SHA256'
    lua_samples_sha256 = if (Test-Path -LiteralPath $samplePath) { Get-LtHash $samplePath 'SHA256' } else { '' }
    lua_boundary_taps_sha256 = if (Test-Path -LiteralPath $tapPath) { Get-LtHash $tapPath 'SHA256' } else { '' }
    debug_log_sha256 = Get-LtHash $debugLogPath 'SHA256'
    debugger_used = $true
    debugger_writes = $false
    save_state_loaded = $false
    input_replay_event_count = @(Get-Content -LiteralPath (Join-Path $run 'replay-actions.csv') | Where-Object { $_ -match '^\d+' }).Count
    input_lua_sha256 = $inputLuaHash
    state_directory_files = $stateFiles.Count
    boundary_events = @($events)
    call = $checked
}
Write-LtJson (Join-Path $run 'observation.json') $observation 18
Get-ChildItem -LiteralPath $run -File | ForEach-Object {
    [ordered]@{ name=$_.Name; length=$_.Length; sha256=Get-LtHash $_.FullName 'SHA256' }
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $run 'hashes.json')

if ($runRecord.timed_out) { throw "MAME exceeded the ${WallTimeoutSeconds}s wall cap; probe preserved at $run" }
if ($runRecord.exit_code -ne 0) { throw "MAME exited $($runRecord.exit_code); inspect $consolePath and $run" }
if (!$observation.rom_unchanged) { throw 'Run ROM copy changed during capture' }
Write-Output $run

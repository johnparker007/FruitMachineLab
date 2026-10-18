[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$OriginalRom,
    [Parameter(Mandatory=$true)][string]$MameExecutable,
    [Parameter(Mandatory=$true)][string]$RomDirectory,
    [Parameter(Mandatory=$true)][string]$OutputRoot,
    [string]$EditSpec = '9ED9:FF80->FF00',
    [string]$IlBuildProject,
    [string]$DotnetExecutable = 'dotnet',
    [ValidateRange(1,120)][int]$SecondsToRun = 120,
    [ValidateRange(30,600)][int]$WallTimeoutSeconds = 600,
    [ValidateRange(5,600)][int]$CommandTimeoutSeconds = 120
)
$ErrorActionPreference = 'Stop'

$script:OriginalSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$script:OriginalSha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
$script:UnrepairedSha256 = 'a99d96f8ea8b4770d2d3828125f25894e831726fe44a79a37e0871faba135ed2'
$script:RepairedSha1 = 'e1a42dccd304b7b175aabac99e8400cdad04cf69'
$script:RepairedSha256 = '577f76bd36dfca04dfb01b5f5d0be93e16572f8617c7ca906397c98df36e5107'
$script:MameSha256 = '0fce5a88df4f9d9b1fbf1405812c00848036e615993780978d967da34204cb7a'
$script:OriginalSpan = '795BFF80787E795BFF807AAF792F'
$script:EditedSpan = '795BFF00787E795BFF807AAF792F'
$script:ExpectedChangedOffsets = @(40668,65489,65490,65491,65492,65493)
$script:ExpectedRepairOnlyOffsets = @(65489,65490,65491,65492,65493)
$script:Utf8 = New-Object System.Text.UTF8Encoding($false)
$script:Repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:OriginalFull = [IO.Path]::GetFullPath($OriginalRom)
$script:OutputFull = [IO.Path]::GetFullPath($OutputRoot)
$script:BuildDirectory = Join-Path $script:OutputFull 'build'
$script:SessionDirectory = Join-Path $script:OutputFull 'session'
$script:LogDirectory = Join-Path $script:OutputFull 'logs'
$script:ReportPath = Join-Path $script:OutputFull 'workflow-report.json'
$script:SummaryPath = Join-Path $script:OutputFull 'build-summary.txt'
$script:OutputCreated = $false
$script:CommandIndex = 0
$script:Errors = New-Object 'System.Collections.Generic.List[object]'
$script:Phases = [ordered]@{}
foreach ($name in @('preflight','build','launch','pause','inspect','stop')) {
    $script:Phases[$name] = [ordered]@{
        status = 'pending'
        started_utc = $null
        completed_utc = $null
        duration_ms = $null
        exit_code = $null
        message = ''
    }
}
$script:Report = [ordered]@{
    schemaVersion = 1
    taskId = 'il-build-debug-24'
    generated_utc = [DateTime]::UtcNow.ToString('o')
    classification = 'Create-only bounded build of the one supported 9ED9 FF80 -> FF00 edit through the existing independent IlBuildCLI, followed by one isolated fresh-boot paused MAME observation of the mapped node and operand. Static build evidence and runtime observation are recorded separately; no full-call result, gameplay or hardware claim is made.'
    outcome = 'running'
    edit = [ordered]@{ specification = '9ED9:FF80->FF00'; tokenAddress = '9ED9'; operandAddress = '9EDB'; expectedOriginal = 'FF80'; replacement = 'FF00' }
    input = [ordered]@{}
    output = [ordered]@{ root = $script:OutputFull; build_directory = $script:BuildDirectory; session_directory = $script:SessionDirectory; log_directory = $script:LogDirectory }
    phases = $script:Phases
    actual_exits = [ordered]@{}
    statuses = [ordered]@{ built = $false; launched = $false; paused = $false; observed = $false; stopped = $false; fresh_boot_observed = $false }
    build = [ordered]@{}
    session = [ordered]@{}
    observed = [ordered]@{}
    errors = $script:Errors
    limitations = @(
        'Only the fixed 9ED9 definition, four tokens and the first 795B literal at 9EDB are supported.',
        'The repaired integrity fields are algorithmic; natural checker acceptance and physical hardware compatibility are separate claims.',
        'The paused observation covers the first mapped node and operand only; no later call, result or gameplay is claimed.',
        'The imgui debugger requires BGFX and creates a rendering window; the Lua periodic callback is a command driver, not an instruction boundary.'
    )
}

function Get-Sha1 { param([string]$Path) return (Get-HashHex $Path 'SHA1') }
function Get-Sha256 { param([string]$Path) return (Get-HashHex $Path 'SHA256') }
function Get-HashHex {
    param([string]$Path,[string]$Algorithm)
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        try { return ([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}
function Get-RomIdentity {
    param([string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    if (!(Test-Path -LiteralPath $full -PathType Leaf)) { throw "ROM file is missing: $full" }
    $item = Get-Item -LiteralPath $full
    return [ordered]@{ path = $full; length = [int]$item.Length; sha1 = (Get-Sha1 $full); sha256 = (Get-Sha256 $full) }
}
function Assert-OriginalIdentity {
    param([string]$Path,[string]$Label = 'original ROM')
    $identity = Get-RomIdentity $Path
    if ($identity.length -ne 65536) { throw "$Label length is $($identity.length), expected 65536" }
    if ($identity.sha1 -ine $script:OriginalSha1) { throw "$Label SHA1 is $($identity.sha1), expected $($script:OriginalSha1)" }
    if ($identity.sha256 -ine $script:OriginalSha256) { throw "$Label SHA256 is $($identity.sha256), expected $($script:OriginalSha256)" }
    return $identity
}
function Get-Offsets {
    param([byte[]]$A,[byte[]]$B)
    if ($A.Length -ne $B.Length) { throw 'Cannot compare different-length images' }
    $list = New-Object 'System.Collections.Generic.List[int]'
    for ($index=0; $index -lt $A.Length; $index++) { if ($A[$index] -ne $B[$index]) { [void]$list.Add($index) } }
    return $list.ToArray()
}
function Format-OffsetsHex { param([int[]]$Offsets) return (@($Offsets | ForEach-Object { '{0:X4}' -f $_ }) -join ',') }
function ConvertTo-QuotedArgument {
    param([string]$Text)
    if ($Text -match '[\s"]') { return '"' + $Text.Replace('"','\"') + '"' }
    return $Text
}
function Invoke-CapturedProcess {
    param(
        [string]$FileName,
        [string[]]$Arguments,
        [string]$WorkingDirectory,
        [string]$StdoutPath,
        [string]$StderrPath,
        [int]$TimeoutSeconds
    )
    $argumentString = (@($Arguments | ForEach-Object { ConvertTo-QuotedArgument ([string]$_) }) -join ' ')
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $FileName
    $info.Arguments = $argumentString
    $info.WorkingDirectory = $WorkingDirectory
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $info
    $watch = [Diagnostics.Stopwatch]::StartNew()
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $exited = $process.WaitForExit($TimeoutSeconds * 1000)
    $timedOut = !$exited
    if ($timedOut) {
        & "$env:SystemRoot\System32\taskkill.exe" /PID $process.Id /T /F 2>&1 | Out-Null
        [void]$process.WaitForExit(10000)
    }
    $watch.Stop()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = -1
    if ($process.HasExited) { $exitCode = $process.ExitCode }
    $process.Dispose()
    if (![string]::IsNullOrWhiteSpace($StdoutPath)) { [IO.File]::WriteAllText($StdoutPath,$stdout,$script:Utf8) }
    if (![string]::IsNullOrWhiteSpace($StderrPath)) { [IO.File]::WriteAllText($StderrPath,$stderr,$script:Utf8) }
    return [ordered]@{
        exit_code = $exitCode
        timed_out = $timedOut
        duration_ms = [math]::Round($watch.Elapsed.TotalMilliseconds,1)
        stdout = $stdout
        stderr = $stderr
        stdout_path = $StdoutPath
        stderr_path = $StderrPath
    }
}
function Set-Phase {
    param([string]$Name,[string]$Status,[string]$Message = '',$ExitCode = $null)
    $phase = $script:Phases[$Name]
    if ($Status -eq 'running') {
        $phase.started_utc = [DateTime]::UtcNow.ToString('o')
        $phase.status = 'running'
        $phase.message = $Message
    } else {
        $phase.status = $Status
        $phase.message = $Message
        $phase.completed_utc = [DateTime]::UtcNow.ToString('o')
        if ($null -ne $phase.started_utc) {
            $started = [DateTime]::Parse([string]$phase.started_utc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind)
            $phase.duration_ms = [math]::Round(([DateTime]::UtcNow - $started.ToUniversalTime()).TotalMilliseconds,1)
        }
        if ($null -ne $ExitCode) { $phase.exit_code = [int]$ExitCode }
    }
    Write-Report
}
function Add-WorkflowError {
    param([string]$Phase,[string]$Message)
    $script:Errors.Add([ordered]@{ phase = $Phase; message = $Message; utc = [DateTime]::UtcNow.ToString('o') })
}
function Write-CanonicalJson {
    param([string]$Path,$Object)
    $json = ConvertTo-Json -InputObject $Object -Depth 30
    $temp = $Path + '.tmp-' + [guid]::NewGuid().ToString('N')
    [IO.File]::WriteAllText($temp,$json,$script:Utf8)
    Move-Item -LiteralPath $temp -Destination $Path -Force
}
function Write-Report {
    if (!$script:OutputCreated) { return }
    try {
        $script:Report.generated_utc = [DateTime]::UtcNow.ToString('o')
        $script:Report.actual_exits = [ordered]@{
            preflight = $script:Phases.preflight.exit_code
            build = $script:Phases.build.exit_code
            launch = $script:Phases.launch.exit_code
            pause = $script:Phases.pause.exit_code
            inspect = $script:Phases.inspect.exit_code
            stop = $script:Phases.stop.exit_code
        }
        Write-CanonicalJson $script:ReportPath $script:Report
    }
    catch {
        [Console]::Error.WriteLine("workflow report write failed: $($_.Exception.Message)")
    }
}
function Write-Summary {
    param([string]$Outcome)
    if (!$script:OutputCreated) { return }
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.Add('FruitMachineLab IL build + paused debug workflow')
    $lines.Add('===============================================')
    $lines.Add("Outcome: $Outcome")
    $lines.Add("Generated: $($script:Report.generated_utc)")
    $lines.Add('')
    $lines.Add("Original ROM: $($script:OriginalFull)")
    $lines.Add("Edit: 9ED9:FF80->FF00 (operand at 9EDB)")
    $lines.Add('')
    if ($script:Report.build -and $script:Report.build.Contains('repaired')) {
        $lines.Add("Unrepaired image: $($script:Report.build.unrepaired.path)")
        $lines.Add("  SHA256: $($script:Report.build.unrepaired.sha256)")
        $lines.Add("Repaired image: $($script:Report.build.repaired.path)")
        $lines.Add("  SHA1:   $($script:Report.build.repaired.sha1)")
        $lines.Add("  SHA256: $($script:Report.build.repaired.sha256)")
        $lines.Add("Diff offsets: $($script:Report.build.repaired.changed_offsets_hex)")
        $lines.Add("Integrity fields: $($script:Report.build.integrity.unrepaired_fields) -> $($script:Report.build.integrity.repaired_fields)")
        $lines.Add("Source map: $($script:Report.output.source_map.path)")
        $lines.Add("  SHA256: $($script:Report.output.source_map.sha256)")
        $lines.Add("Build report: $($script:Report.output.build_report.path)")
        $lines.Add("  SHA256: $($script:Report.output.build_report.sha256)")
        $lines.Add("Integrity report: $($script:Report.output.integrity_report.path)")
        $lines.Add("  SHA256: $($script:Report.output.integrity_report.sha256)")
    }
    $lines.Add('')
    $lines.Add('Phase status:')
    foreach ($name in @('preflight','build','launch','pause','inspect','stop')) {
        $lines.Add(('  {0,-9} {1,-8} exit={2}' -f $name,$script:Phases[$name].status,$script:Phases[$name].exit_code))
    }
    $lines.Add('')
    $lines.Add('Statuses:')
    $lines.Add("  built=$($script:Report.statuses.built) launched=$($script:Report.statuses.launched) paused=$($script:Report.statuses.paused) observed=$($script:Report.statuses.observed) stopped=$($script:Report.statuses.stopped) fresh_boot_observed=$($script:Report.statuses.fresh_boot_observed)")
    if ($script:Report.session.Contains('pause')) {
        $p = $script:Report.session.pause
        $lines.Add('')
        $lines.Add("Observed paused node: $($p.nodeIndex)")
        $lines.Add("  PC=$($p.pc) Y=$($p.y) U=$($p.u) S=$($p.s)")
        $lines.Add("  token=$($p.token) IL operand=$($p.ilOperand) emulatedTime=$($p.emulatedTime)")
    }
    if ($script:Report.session.Contains('run_directory')) {
        $lines.Add('')
        $lines.Add("Session: $($script:Report.session.session_id)")
        $lines.Add("  Run directory: $($script:Report.session.run_directory)")
        $lines.Add("  Process ID: $($script:Report.session.process_id)")
    }
    if ($script:Errors.Count -gt 0) {
        $lines.Add('')
        $lines.Add('Errors:')
        foreach ($error in $script:Errors) { $lines.Add("  [$($error.phase)] $($error.message)") }
    }
    [IO.File]::WriteAllLines($script:SummaryPath,$lines,$script:Utf8)
}
function Assert-CanonicalBuildArtifact {
    param([string]$Path,[string]$Label)
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { throw "$Label has a UTF-8 BOM" }
    if ($bytes.Length -lt 2 -or $bytes[$bytes.Length-1] -ne 0x7D) { throw "$Label is not the canonical create-only JSON document" }
}
function Assert-Properties {
    param($Object,[string[]]$Expected,[string]$Label)
    if ($null -eq $Object) { throw "$Label is missing" }
    $actual = @($Object.PSObject.Properties | ForEach-Object { [string]$_.Name })
    if ($actual.Count -ne $Expected.Count) { throw "$Label has $($actual.Count) properties, expected $($Expected.Count)" }
    foreach ($name in $Expected) { if ($actual -cnotcontains $name) { throw "$Label is missing property $name" } }
}
function Assert-Sequence {
    param($Actual,[object[]]$Expected,[string]$Label)
    $values = @($Actual)
    if ($values.Count -ne $Expected.Count) { throw "$Label has $($values.Count) values, expected $($Expected.Count)" }
    for ($index=0; $index -lt $values.Count; $index++) {
        if ([string]$values[$index] -ne [string]$Expected[$index]) { throw "$Label value $index is $($values[$index]), expected $($Expected[$index])" }
    }
}
function Read-KeyValueFile {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Response file is missing: $Path" }
    $table = @{}
    foreach ($line in ([IO.File]::ReadAllText($Path) -split "`r?`n")) {
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
function Assert-ResponseEqual {
    param($Response,[string]$Key,[string]$Expected,[string]$Label)
    if (![string]::Equals([string]$Response[$Key],[string]$Expected,[StringComparison]::Ordinal)) {
        throw "$Label $Key is '$($Response[$Key])', expected '$Expected'"
    }
}
function Assert-HexWord {
    param($Value,[string]$Label)
    if ([string]$Value -notmatch '^[0-9A-Fa-f]{4}$') { throw "$Label is not a four-digit hexadecimal word: '$Value'" }
}
function Invoke-DebugCommand {
    param([string]$Command,[int]$Node = -1)
    $script:CommandIndex++
    $base = Join-Path $script:LogDirectory ('command-{0}-{1}' -f $script:CommandIndex,$Command)
    $arguments = @('-NoProfile','-File',(Join-Path $script:Repo 'tools/Invoke-IlDebugCommand.ps1'),
        '-SessionDirectory',$script:SessionDirectory,'-Command',$Command,'-TimeoutSeconds',[string]$CommandTimeoutSeconds)
    if ($Node -ge 0) { $arguments += @('-Node',[string]$Node) }
    $process = Invoke-CapturedProcess $script:PowerShellExe $arguments $script:Repo ($base + '.stdout.txt') ($base + '.stderr.txt') ($CommandTimeoutSeconds + 30)
    $responsePath = $null
    if ($process.stdout -match 'RESPONSE=([^\r\n]+)') { $responsePath = $Matches[1].Trim() }
    $response = $null
    if ($responsePath -and (Test-Path -LiteralPath $responsePath -PathType Leaf)) { $response = Read-KeyValueFile $responsePath }
    return [ordered]@{
        exit_code = $process.exit_code
        timed_out = $process.timed_out
        duration_ms = $process.duration_ms
        stdout_path = $process.stdout_path
        stderr_path = $process.stderr_path
        response_path = $responsePath
        response = $response
    }
}
function Stop-LaunchedSessionForCleanup {
    param([string]$FailedPhase)
    if (!$script:Report.statuses.launched -or $script:Report.statuses.stopped) { return }
    try {
        $result = Invoke-DebugCommand 'stop'
        $exited = $false
        if ($result.exit_code -eq 0) {
            $processId = [int]$script:Report.session.process_id
            $deadline = [DateTime]::UtcNow.AddSeconds(30)
            while ($null -ne (Get-Process -Id $processId -ErrorAction SilentlyContinue)) {
                if ([DateTime]::UtcNow -gt $deadline) { break }
                Start-Sleep -Milliseconds 200
            }
            $exited = ($null -eq (Get-Process -Id $processId -ErrorAction SilentlyContinue))
        }
        $script:Report.cleanup = [ordered]@{
            attempted = $true
            failed_phase = $FailedPhase
            command = 'stop'
            exit_code = $result.exit_code
            response_path = $result.response_path
            mame_exited = $exited
        }
    }
    catch {
        $script:Report.cleanup = [ordered]@{
            attempted = $true
            failed_phase = $FailedPhase
            command = 'stop'
            exit_code = $null
            message = $_.Exception.Message
            mame_exited = $false
        }
    }
    Write-Report
}
function Assert-BuildAgreement {
    param([byte[]]$OriginalBytes,[byte[]]$UnrepairedBytes,[byte[]]$RepairedBytes,$Map,$Build,$Integrity)
    $originalDiff = Get-Offsets $OriginalBytes $UnrepairedBytes
    if (($originalDiff -join ',') -ne '40668') { throw "Original/unrepaired diff is $(Format-OffsetsHex $originalDiff), expected 9EDC" }
    $unrepairedDiff = Get-Offsets $UnrepairedBytes $RepairedBytes
    if (($unrepairedDiff -join ',') -ne ($script:ExpectedRepairOnlyOffsets -join ',')) {
        throw "Unrepaired/repaired diff is $(Format-OffsetsHex $unrepairedDiff), expected FFD1,FFD2,FFD3,FFD4,FFD5"
    }
    $repairedDiff = Get-Offsets $OriginalBytes $RepairedBytes
    if (($repairedDiff -join ',') -ne ($script:ExpectedChangedOffsets -join ',')) {
        throw "Original/repaired diff is $(Format-OffsetsHex $repairedDiff), expected 9EDC,FFD1,FFD2,FFD3,FFD4,FFD5"
    }
    if ((ConvertTo-Hex $OriginalBytes 0x9ED9 14) -ne $script:OriginalSpan) { throw 'Original 9ED9 span differs from the accepted span' }
    if ((ConvertTo-Hex $UnrepairedBytes 0x9ED9 14) -ne $script:EditedSpan) { throw 'Unrepaired 9ED9 span differs from the accepted span' }
    if ((ConvertTo-Hex $RepairedBytes 0x9ED9 14) -ne $script:EditedSpan) { throw 'Repaired 9ED9 span differs from the accepted span' }
    if ($RepairedBytes[0x9EDC] -ne 0x00 -or $OriginalBytes[0x9EDC] -ne 0x80) { throw '9EDC is not 80 -> 00' }
    if ($RepairedBytes[0x9EDB] -ne 0xFF -or $RepairedBytes[0x9EE1] -ne 0xFF -or $RepairedBytes[0x9EE2] -ne 0x80) { throw 'A preserved literal byte changed unexpectedly' }
    if ($RepairedBytes[0x9ED7] -ne 0x00 -or $RepairedBytes[0x9ED8] -ne 0xF8) { throw 'The 9ED9 header changed unexpectedly' }

    Assert-Properties $Map @('schemaVersion','taskId','classification','originalRomSha256','outputImageSha256','identityBuild','bodyStart','bodyEndExclusive','entries') 'Source map'
    if ([int]$Map.schemaVersion -ne 1 -or [string]$Map.taskId -cne 'il-integrity-03') { throw 'Source map schema/task identity is wrong' }
    if ([string]$Map.originalRomSha256 -ine $script:OriginalSha256) { throw 'Source map original identity is wrong' }
    if ([string]$Map.outputImageSha256 -ine $script:RepairedSha256) { throw 'Source map is not bound to the fresh repaired image' }
    if ([bool]$Map.identityBuild) { throw 'Source map must describe the non-identity build' }
    if ([string]$Map.bodyStart -ine '9ED9' -or [string]$Map.bodyEndExclusive -ine '9EE7') { throw 'Source map body span is wrong' }
    $entries = @($Map.entries)
    if ($entries.Count -ne 14) { throw "Source map has $($entries.Count) entries, expected 14" }
    $expectedNodeIndices = @(0,0,0,0,1,1,2,2,2,2,3,3,4,4)
    $expectedTokens = @('795B','795B','795B','795B','787E','787E','795B','795B','795B','795B','7AAF','7AAF','792F','792F')
    $expectedOperations = @('vm_push_inline_word_literal','vm_push_inline_word_literal','vm_push_inline_word_literal','vm_push_inline_word_literal','vm_add_words','vm_add_words','vm_push_inline_word_literal','vm_push_inline_word_literal','vm_push_inline_word_literal','vm_push_inline_word_literal','vm_bitwise_xor','vm_bitwise_xor','vm_return_to_caller_stream','vm_return_to_caller_stream')
    for ($index=0; $index -lt 14; $index++) {
        $entry = $entries[$index]
        Assert-Properties $entry @('address','nodeIndex','token','operation','imageByte') "Source map entry $index"
        if ([Convert]::ToInt32([string]$entry.address,16) -ne (0x9ED9 + $index)) { throw "Source map entry $index is not contiguous" }
        if ([int]$entry.nodeIndex -ne $expectedNodeIndices[$index]) { throw "Source map entry $index nodeIndex is wrong" }
        if ([string]$entry.token -ine $expectedTokens[$index]) { throw "Source map entry $index token is wrong" }
        if ([string]$entry.operation -cne $expectedOperations[$index]) { throw "Source map entry $index operation is wrong" }
        if ([Convert]::ToInt32([string]$entry.imageByte,16) -ne [int]$RepairedBytes[0x9ED9 + $index]) { throw "Source map entry $index imageByte differs from the repaired image" }
    }

    Assert-Properties $Build @('schemaVersion','taskId','classification','original','unrepaired','repaired','edit','unrepairedDiff','repairedDiff','repairOnlyDiff','integrity','sourceMap','checks','limitations') 'Build report'
    if ([int]$Build.schemaVersion -ne 1 -or [string]$Build.taskId -cne 'il-integrity-03') { throw 'Build report schema/task identity is wrong' }
    if ([string]$Build.original.sha1 -ine $script:OriginalSha1 -or [string]$Build.original.sha256 -ine $script:OriginalSha256) { throw 'Build report original identity is wrong' }
    if ([string]$Build.unrepaired.sha256 -ine $script:UnrepairedSha256) { throw 'Build report unrepaired identity is wrong' }
    if ([string]$Build.repaired.sha1 -ine $script:RepairedSha1 -or [string]$Build.repaired.sha256 -ine $script:RepairedSha256) { throw 'Build report repaired identity is wrong' }
    if ([string]$Build.original.path -ine $script:OriginalFull) { throw 'Build report original path differs from the supplied original' }
    if ([string]$Build.repaired.path -ine (Join-Path $script:BuildDirectory 'edited-repaired.p1')) { throw 'Build report repaired path is not the fresh output' }
    if ([string]$Build.unrepaired.path -ine (Join-Path $script:BuildDirectory 'edited-unrepaired.p1')) { throw 'Build report unrepaired path is not the fresh output' }
    if ([string]$Build.sourceMap.path -ine (Join-Path $script:BuildDirectory 'source-map.json')) { throw 'Build report source-map path is not the fresh output' }
    if ([string]$Build.edit.operandAddress -ine '9EDB' -or [string]$Build.edit.replacementValue -ine 'FF00') { throw 'Build report edit does not match the supported request' }
    if (![bool]$Build.checks.sourceMapBoundToRepairedSha256 -or ![bool]$Build.checks.orderedIntegrityRepair) { throw 'Build report is missing required consistency checks' }
    Assert-Sequence $Build.unrepaired.changedOffsets @(40668) 'Build report unrepaired changed offsets'
    Assert-Sequence $Build.unrepaired.changedOffsetsHex @('9EDC') 'Build report unrepaired changed offsets hex'
    Assert-Sequence $Build.repaired.changedOffsets @(40668,65489,65490,65491,65492,65493) 'Build report repaired changed offsets'
    Assert-Sequence $Build.repaired.changedOffsetsHex @('9EDC','FFD1','FFD2','FFD3','FFD4','FFD5') 'Build report repaired changed offsets hex'
    Assert-Sequence $Build.repairOnlyDiff.offset @(65489,65490,65491,65492,65493) 'Build report repair-only offsets'
    if ([string]$Build.repaired.storedFieldsHex -ine 'BEF69E7CC7' -or [string]$Build.repaired.computedFieldsHex -ine 'BEF69E7CC7') { throw 'Build report repaired integrity fields are wrong' }
    if ([string]$Build.unrepaired.storedFieldsHex -ine '3E761E2605') { throw 'Build report unrepaired integrity fields are wrong' }
    if (![bool]$Build.integrity.repaired -or [bool]$Build.integrity.accepted) { throw 'Build report integrity flags are wrong' }
    if ([string]$Build.integrity.recordBase -ine 'FFD1' -or [string]$Build.integrity.gate -ine '00' -or [string]$Build.integrity.errorCode -ine '12') { throw 'Build report integrity record is wrong' }
    $fields = @($Build.integrity.fieldWrites)
    if ($fields.Count -ne 5) { throw 'Build report integrity field count is wrong' }
    for ($index=0; $index -lt 5; $index++) { if ([int]$fields[$index].offset -ne (65489 + $index)) { throw "Build report integrity field $index offset is wrong" } }
    if ([string]$Build.sourceMap.outputImageSha256 -ine $script:RepairedSha256 -or [string]$Build.sourceMap.originalRomSha256 -ine $script:OriginalSha256) { throw 'Build report source-map identity is wrong' }
    if ([int]$Build.sourceMap.coveredBytes -ne 14 -or [int]$Build.sourceMap.entries -ne 14) { throw 'Build report source-map coverage is wrong' }

    Assert-Properties $Integrity @('schemaVersion','taskId','classification','original','unrepaired','repaired','record','algorithmOrder','evidenceSource','fieldWrites','repairOnlyDiff','status','limitations') 'Integrity report'
    if ([int]$Integrity.schemaVersion -ne 1 -or [string]$Integrity.taskId -cne 'il-integrity-03') { throw 'Integrity report schema/task identity is wrong' }
    if ([string]$Integrity.original.sha1 -ine $script:OriginalSha1 -or [string]$Integrity.original.sha256 -ine $script:OriginalSha256) { throw 'Integrity report original identity is wrong' }
    if ([string]$Integrity.unrepaired.sha256 -ine $script:UnrepairedSha256) { throw 'Integrity report unrepaired identity is wrong' }
    if ([string]$Integrity.repaired.sha1 -ine $script:RepairedSha1 -or [string]$Integrity.repaired.sha256 -ine $script:RepairedSha256) { throw 'Integrity report repaired identity is wrong' }
    if ([string]$Integrity.repaired.storedFieldsHex -ine 'BEF69E7CC7' -or [string]$Integrity.repaired.computedFieldsHex -ine 'BEF69E7CC7') { throw 'Integrity report repaired fields are wrong' }
    if ([string]$Integrity.status -notmatch 'ALGORITHMICALLY REPAIRED') { throw 'Integrity report status is not the algorithmic repair status' }
    if (@($Integrity.fieldWrites).Count -ne 5) { throw 'Integrity report field count is wrong' }
}
function ConvertTo-Hex {
    param([byte[]]$Bytes,[int]$Offset,[int]$Length)
    $slice = [byte[]]$Bytes[$Offset..($Offset+$Length-1)]
    return ([BitConverter]::ToString($slice)).Replace('-','').ToUpperInvariant()
}

# ---- preflight -----------------------------------------------------------------
try {
    Set-Phase 'preflight' 'running' 'Checking the original identity, MAME, support paths and create-only output root'
    if ($EditSpec -ine '9ED9:FF80->FF00') {
        throw "Unsupported edit request '$EditSpec'; only 9ED9:FF80->FF00 is supported"
    }
    if (Test-Path -LiteralPath $script:OutputFull) {
        throw "Use a fresh create-only output root: $script:OutputFull"
    }
    if (Test-Path -LiteralPath $script:OriginalFull -PathType Container) { throw "Original ROM path is a directory: $script:OriginalFull" }
    if (!(Test-Path -LiteralPath $script:MameExecutable -PathType Leaf)) { throw "MAME executable is missing: $MameExecutable" }
    if (!(Test-Path -LiteralPath $RomDirectory -PathType Container)) { throw "Installed ROM directory is missing: $RomDirectory" }
    if ([string]::IsNullOrWhiteSpace($IlBuildProject)) { $IlBuildProject = Join-Path $script:Repo 'tools/FruitMachineLab.IlBuild' }
    $script:IlBuildProject = [IO.Path]::GetFullPath($IlBuildProject)
    if (!(Test-Path -LiteralPath $script:IlBuildProject)) { throw "IlBuild project is missing: $script:IlBuildProject" }
    $dotnetCommand = Get-Command $DotnetExecutable -ErrorAction Stop
    if ($dotnetCommand.CommandType -eq 'Application' -or (Test-Path -LiteralPath $DotnetExecutable -PathType Leaf)) {
        $script:DotnetExe = if (Test-Path -LiteralPath $DotnetExecutable -PathType Leaf) { [IO.Path]::GetFullPath($DotnetExecutable) } else { $dotnetCommand.Source }
    } else { throw "Dotnet executable could not be resolved: $DotnetExecutable" }
    $script:PowerShellExe = if ($PSVersionTable.PSEdition -eq 'Core') { Join-Path $PSHOME 'pwsh.exe' } else { Join-Path $PSHOME 'powershell.exe' }
    if (!(Test-Path -LiteralPath $script:PowerShellExe -PathType Leaf)) { throw "PowerShell executable is missing: $script:PowerShellExe" }
    $script:PlanPath = Join-Path $script:Repo 'evidence/mpu4/integrity/il-natural-reachability-plan.json'
    $script:ReplayPath = Join-Path $script:Repo 'evidence/mpu4/skill-cash/actions.csv'
    $script:InputLuaPath = Join-Path $script:Repo 'evidence/mpu4/skill-cash/input.lua'
    foreach ($path in @($script:PlanPath,$script:ReplayPath,$script:InputLuaPath)) { if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required support file is missing: $path" } }

    $script:InputOriginal = Assert-OriginalIdentity $script:OriginalFull
    $mameIdentity = Get-RomIdentity $MameExecutable
    if ($mameIdentity.sha256 -ine $script:MameSha256) { throw "MAME SHA256 is $($mameIdentity.sha256), expected $($script:MameSha256)" }
    $script:Report.input = [ordered]@{
        original = $script:InputOriginal
        mame = [ordered]@{ path = $mameIdentity.path; length = $mameIdentity.length; sha256 = $mameIdentity.sha256 }
        rom_directory = [IO.Path]::GetFullPath($RomDirectory)
        il_build_project = $script:IlBuildProject
        support = [ordered]@{
            plan = [ordered]@{ path = $script:PlanPath; sha256 = (Get-Sha256 $script:PlanPath) }
            replay = [ordered]@{ path = $script:ReplayPath; sha256 = (Get-Sha256 $script:ReplayPath) }
            input_lua = [ordered]@{ path = $script:InputLuaPath; sha256 = (Get-Sha256 $script:InputLuaPath) }
        }
    }
    Set-Phase 'preflight' 'passed' 'Original identity, MAME, support paths and create-only output root verified' 0
}
catch {
    Add-WorkflowError 'preflight' $_.Exception.Message
    $script:Report.outcome = 'failed_preflight'
    Set-Phase 'preflight' 'failed' $_.Exception.Message 1
    Write-Report
    Write-Summary $script:Report.outcome
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}

# ---- build --------------------------------------------------------------------
try {
    New-Item -ItemType Directory -Path $script:OutputFull -ErrorAction Stop | Out-Null
    $script:OutputCreated = $true
    New-Item -ItemType Directory -Path $script:LogDirectory -ErrorAction Stop | Out-Null
    Set-Phase 'build' 'running' 'Running the existing independent IlBuildCLI'
    $buildStdout = Join-Path $script:LogDirectory 'build.stdout.txt'
    $buildStderr = Join-Path $script:LogDirectory 'build.stderr.txt'
    $buildArguments = @('run','--project',$script:IlBuildProject,'--no-build','--',$script:OriginalFull,$script:BuildDirectory)
    $buildProcess = Invoke-CapturedProcess $script:DotnetExe $buildArguments $script:Repo $buildStdout $buildStderr 1800
    $reported = [ordered]@{}
    foreach ($line in ($buildProcess.stdout -split "`r?`n")) {
        if ($line -match '^([a-zA-Z0-9_]+)=(.*)$') { $reported[$Matches[1]] = $Matches[2] }
    }
    $script:Report.build.cli = [ordered]@{
        project = $script:IlBuildProject
        exit_code = $buildProcess.exit_code
        timed_out = $buildProcess.timed_out
        duration_ms = $buildProcess.duration_ms
        stdout = $buildStdout
        stderr = $buildStderr
        reported = $reported
    }
    if ($buildProcess.exit_code -ne 0) { throw "IlBuildCLI exited $($buildProcess.exit_code): $($buildProcess.stderr.Trim())" }
    foreach ($path in @((Join-Path $script:BuildDirectory 'edited-unrepaired.p1'),(Join-Path $script:BuildDirectory 'edited-repaired.p1'),(Join-Path $script:BuildDirectory 'build-report.json'),(Join-Path $script:BuildDirectory 'integrity-report.json'),(Join-Path $script:BuildDirectory 'source-map.json'))) {
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Build artifact is missing: $path" }
    }
    $unrepairedPath = Join-Path $script:BuildDirectory 'edited-unrepaired.p1'
    $repairedPath = Join-Path $script:BuildDirectory 'edited-repaired.p1'
    $mapPath = Join-Path $script:BuildDirectory 'source-map.json'
    $buildReportPath = Join-Path $script:BuildDirectory 'build-report.json'
    $integrityReportPath = Join-Path $script:BuildDirectory 'integrity-report.json'
    $originalBytes = [IO.File]::ReadAllBytes($script:OriginalFull)
    $unrepairedBytes = [IO.File]::ReadAllBytes($unrepairedPath)
    $repairedBytes = [IO.File]::ReadAllBytes($repairedPath)
    if ($unrepairedBytes.Length -ne 65536 -or $repairedBytes.Length -ne 65536) { throw 'Build output length is not 65536' }
    $unrepairedSha256 = Get-Sha256 $unrepairedPath
    $repairedSha1 = Get-Sha1 $repairedPath
    $repairedSha256 = Get-Sha256 $repairedPath
    if ($unrepairedSha256 -ine $script:UnrepairedSha256) { throw "Unrepaired image SHA256 is $unrepairedSha256, expected $($script:UnrepairedSha256)" }
    if ($repairedSha1 -ine $script:RepairedSha1 -or $repairedSha256 -ine $script:RepairedSha256) { throw "Repaired image identity is not the accepted 9EDC build" }
    if ((Get-Sha256 $script:OriginalFull) -ine $script:OriginalSha256) { throw 'Original ROM changed during the build phase' }
    foreach ($path in @($mapPath,$buildReportPath,$integrityReportPath)) { Assert-CanonicalBuildArtifact $path ([IO.Path]::GetFileName($path)) }
    $map = Get-Content -LiteralPath $mapPath -Raw | ConvertFrom-Json
    $buildReport = Get-Content -LiteralPath $buildReportPath -Raw | ConvertFrom-Json
    $integrityReport = Get-Content -LiteralPath $integrityReportPath -Raw | ConvertFrom-Json
    Assert-BuildAgreement $originalBytes $unrepairedBytes $repairedBytes $map $buildReport $integrityReport
    if ([string]$reported['original_sha256'] -ine $script:OriginalSha256 -or [string]$reported['repaired_sha256'] -ine $script:RepairedSha256 -or [string]$reported['unrepaired_sha256'] -ine $script:UnrepairedSha256) {
        throw 'IlBuildCLI reported hashes disagree with the written artifacts'
    }
    if ([string]$reported['repaired_changed_offsets'] -ine '9EDC,FFD1,FFD2,FFD3,FFD4,FFD5') { throw 'IlBuildCLI did not report the accepted repaired diff' }
    $diffRecords = $script:ExpectedChangedOffsets | ForEach-Object {
        [ordered]@{ offset = $_; offsetHex = ('{0:X4}' -f $_); before = ('{0:X2}' -f $originalBytes[$_]); after = ('{0:X2}' -f $repairedBytes[$_]) }
    }
    $script:Report.build = [ordered]@{
        cli = $script:Report.build.cli
        original = [ordered]@{ path = $script:OriginalFull; length = 65536; sha1 = $script:OriginalSha1; sha256 = $script:OriginalSha256; unchanged = $true }
        unrepaired = [ordered]@{ path = $unrepairedPath; length = 65536; sha256 = $unrepairedSha256 }
        repaired = [ordered]@{ path = $repairedPath; length = 65536; sha1 = $repairedSha1; sha256 = $repairedSha256; changed_offsets = $script:ExpectedChangedOffsets; changed_offsets_hex = (Format-OffsetsHex $script:ExpectedChangedOffsets) }
        diff = $diffRecords
        repair_only_diff = @($script:ExpectedRepairOnlyOffsets | ForEach-Object { [ordered]@{ offset = $_; offsetHex = ('{0:X4}' -f $_); before = ('{0:X2}' -f $unrepairedBytes[$_]); after = ('{0:X2}' -f $repairedBytes[$_]) } })
        integrity = [ordered]@{
            status = [string]$buildReport.integrity.status
            recordBase = [string]$buildReport.integrity.recordBase
            gate = [string]$buildReport.integrity.gate
            errorCode = [string]$buildReport.integrity.errorCode
            unrepaired_fields = [string]$buildReport.unrepaired.storedFieldsHex
            repaired_fields = [string]$buildReport.repaired.storedFieldsHex
            computed_fields = [string]$buildReport.repaired.computedFieldsHex
            field_writes = @($buildReport.integrity.fieldWrites)
        }
        map_build_image_agree = $true
    }
    $script:Report.output.source_map = [ordered]@{ path = $mapPath; sha256 = (Get-Sha256 $mapPath); bodyStart = '9ED9'; bodyEndExclusive = '9EE7'; entries = 14 }
    $script:Report.output.build_report = [ordered]@{ path = $buildReportPath; sha256 = (Get-Sha256 $buildReportPath) }
    $script:Report.output.integrity_report = [ordered]@{ path = $integrityReportPath; sha256 = (Get-Sha256 $integrityReportPath) }
    $script:Report.output.repaired_image = $script:Report.build.repaired
    $script:Report.output.unrepaired_image = $script:Report.build.unrepaired
    $script:Report.statuses.built = $true
    Set-Phase 'build' 'passed' 'Fresh independent IL build, ordered integrity repair and output-bound source map verified' $buildProcess.exit_code
}
catch {
    $failureExit = if ($null -ne $buildProcess) { $buildProcess.exit_code } else { 1 }
    Add-WorkflowError 'build' $_.Exception.Message
    if (!$script:Report.statuses.built) { $script:Report.outcome = 'failed_build' }
    Set-Phase 'build' 'failed' $_.Exception.Message $failureExit
    Write-Report
    Write-Summary $script:Report.outcome
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}

# ---- launch -------------------------------------------------------------------
try {
    Set-Phase 'launch' 'running' 'Starting the isolated repaired-image paused debug session'
    $launchStdout = Join-Path $script:LogDirectory 'launcher.stdout.txt'
    $launchStderr = Join-Path $script:LogDirectory 'launcher.stderr.txt'
    $launchArguments = @('-NoProfile','-File',(Join-Path $script:Repo 'tools/Start-IlDebugSession.ps1'),
        '-MameExecutable',$MameExecutable,'-RomDirectory',$RomDirectory,'-OriginalRom',$script:OriginalFull,
        '-RepairedRom',$repairedPath,'-Variant','Changed','-Definition','9ED9','-RunDirectory',$script:SessionDirectory,
        '-SourceMapPath',$mapPath,'-BuildReportPath',$buildReportPath,'-PlanPath',$script:PlanPath,
        '-ReplayPath',$script:ReplayPath,'-InputLuaPath',$script:InputLuaPath,
        '-SecondsToRun',[string]$SecondsToRun,'-WallTimeoutSeconds',[string]$WallTimeoutSeconds)
    $launchProcess = Invoke-CapturedProcess $script:PowerShellExe $launchArguments $script:Repo $launchStdout $launchStderr ($WallTimeoutSeconds + 180)
    if ($launchProcess.exit_code -ne 0) { throw "Start-IlDebugSession.ps1 exited $($launchProcess.exit_code): $($launchProcess.stderr.Trim())" }
    $launch = $launchProcess.stdout | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace([string]$launch.sessionId)) { throw 'Launcher did not return a session ID' }
    if ([string]$launch.session_directory -ine $script:SessionDirectory) { throw 'Launcher returned a different session directory' }
    if ([string]$launch.variant -cne 'Changed') { throw 'Launcher did not start the changed image' }
    if (!(Test-Path -LiteralPath (Join-Path $script:SessionDirectory 'session-launch.json') -PathType Leaf)) { throw 'Session launch record is missing' }
    $runRom = Join-Path $script:SessionDirectory 'roms/m4addr/a6ls.p1'
    $runRomBefore = Get-RomIdentity $runRom
    if ($runRomBefore.sha256 -ine $script:RepairedSha256) { throw 'Isolated session ROM is not the exact repaired image' }
    $script:Report.session = [ordered]@{
        session_id = [string]$launch.sessionId
        process_id = [int]$launch.process_id
        run_directory = $script:SessionDirectory
        launch_stdout = $launchStdout
        launch_stderr = $launchStderr
        launch_exit_code = $launchProcess.exit_code
        mame_version = [string]$launch.mame_version
        mame_sha256 = $script:MameSha256
        start_utc = [DateTime]::UtcNow.ToString('o')
        run_rom_before = $runRomBefore
        ready = $launch.ready
        seconds_to_run = $SecondsToRun
        wall_timeout_seconds = $WallTimeoutSeconds
    }
    $script:Report.statuses.launched = $true
    Set-Phase 'launch' 'passed' 'Isolated repaired-image session launched and ready in the stopped state' $launchProcess.exit_code
}
catch {
    $failureExit = if ($null -ne $launchProcess) { $launchProcess.exit_code } else { 1 }
    Add-WorkflowError 'launch' $_.Exception.Message
    $script:Report.outcome = 'failed_launch'
    Set-Phase 'launch' 'failed' $_.Exception.Message $failureExit
    Write-Report
    Write-Summary $script:Report.outcome
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}

# ---- pause --------------------------------------------------------------------
try {
    Set-Phase 'pause' 'running' 'Pausing at the first mapped 9ED9 node'
    $pauseResult = Invoke-DebugCommand 'pause-at-mapped-node' 0
    if ($pauseResult.exit_code -ne 0 -or $null -eq $pauseResult.response) {
        throw "pause-at-mapped-node exited $($pauseResult.exit_code) without a valid response"
    }
    $pause = $pauseResult.response
    Assert-ResponseEqual $pause 'protocol' 'il-debug-session-v1' 'pause response'
    Assert-ResponseEqual $pause 'session' $script:Report.session.session_id 'pause response'
    Assert-ResponseEqual $pause 'command' 'pause-at-mapped-node' 'pause response'
    Assert-ResponseEqual $pause 'status' 'ok' 'pause response'
    Assert-ResponseEqual $pause 'kind' 'paused-at-node' 'pause response'
    Assert-ResponseEqual $pause 'proof' 'boundary_reached' 'pause response'
    Assert-ResponseEqual $pause 'boundaryPhase' 'prefetch' 'pause response'
    Assert-ResponseEqual $pause 'nodeIndex' '0' 'pause response'
    Assert-ResponseEqual $pause 'pc' '00FC' 'pause response'
    Assert-ResponseEqual $pause 'y' '9ED9' 'pause response'
    Assert-ResponseEqual $pause 'token' '795B' 'pause response'
    Assert-ResponseEqual $pause 'ilOperand' 'FF00' 'pause response'
    Assert-ResponseEqual $pause 'execState' 'stop' 'pause response'
    Assert-HexWord $pause['u'] 'pause U'
    Assert-HexWord $pause['s'] 'pause S'
    $emulatedTime = [double]$pause['emulatedTime']
    if ($emulatedTime -le 0) { throw 'Pause did not report positive emulated time' }
    $script:Report.session.pause = [ordered]@{
        response_path = $pauseResult.response_path
        exit_code = $pauseResult.exit_code
        duration_ms = $pauseResult.duration_ms
        nodeIndex = [int]$pause['nodeIndex']
        boundaryPhase = [string]$pause['boundaryPhase']
        proof = [string]$pause['proof']
        pc = [string]$pause['pc']
        y = [string]$pause['y']
        u = [string]$pause['u']
        s = [string]$pause['s']
        token = [string]$pause['token']
        ilOperand = [string]$pause['ilOperand']
        emulatedTime = $emulatedTime
        execState = [string]$pause['execState']
    }
    $script:Report.statuses.paused = $true
    Set-Phase 'pause' 'passed' 'Mapped node 0 reached naturally at a native prefetch boundary' $pauseResult.exit_code
}
catch {
    $failureExit = if ($null -ne $pauseResult) { $pauseResult.exit_code } else { 1 }
    Add-WorkflowError 'pause' $_.Exception.Message
    $script:Report.outcome = 'failed_pause'
    Set-Phase 'pause' 'failed' $_.Exception.Message $failureExit
    Stop-LaunchedSessionForCleanup 'pause'
    Write-Report
    Write-Summary $script:Report.outcome
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}

# ---- inspect ------------------------------------------------------------------
try {
    Set-Phase 'inspect' 'running' 'Inspecting the paused mapped node read-only'
    $inspectResult = Invoke-DebugCommand 'inspect'
    if ($inspectResult.exit_code -ne 0 -or $null -eq $inspectResult.response) {
        throw "inspect exited $($inspectResult.exit_code) without a valid response"
    }
    $inspection = $inspectResult.response
    Assert-ResponseEqual $inspection 'protocol' 'il-debug-session-v1' 'inspect response'
    Assert-ResponseEqual $inspection 'session' $script:Report.session.session_id 'inspect response'
    Assert-ResponseEqual $inspection 'command' 'inspect' 'inspect response'
    Assert-ResponseEqual $inspection 'status' 'ok' 'inspect response'
    Assert-ResponseEqual $inspection 'kind' 'inspection' 'inspect response'
    Assert-ResponseEqual $inspection 'proof' 'stopped_read_only' 'inspect response'
    Assert-ResponseEqual $inspection 'stateUnchanged' 'yes' 'inspect response'
    Assert-ResponseEqual $inspection 'execState' 'stop' 'inspect response'
    foreach ($key in @('pc','y','u','s','ilOperand')) {
        if ([string]$inspection[$key] -ne [string]$script:Report.session.pause[$key]) { throw "Inspect $key differs from the pause observation" }
    }
    if ([double]$inspection['timeBefore'] -ne [double]$inspection['timeAfter']) { throw 'Inspect advanced emulated time' }
    $script:Report.session.inspect = [ordered]@{
        response_path = $inspectResult.response_path
        exit_code = $inspectResult.exit_code
        duration_ms = $inspectResult.duration_ms
        pc = [string]$inspection['pc']
        y = [string]$inspection['y']
        u = [string]$inspection['u']
        s = [string]$inspection['s']
        ilOperand = [string]$inspection['ilOperand']
        emulatedTime = [double]$inspection['emulatedTime']
        stateUnchanged = [string]$inspection['stateUnchanged']
        proof = [string]$inspection['proof']
    }
    $script:Report.observed = [ordered]@{
        node_index = [int]$script:Report.session.pause.nodeIndex
        boundary_phase = [string]$script:Report.session.pause.boundaryPhase
        proof = [string]$script:Report.session.pause.proof
        pc = [string]$script:Report.session.pause.pc
        y = [string]$script:Report.session.pause.y
        u = [string]$script:Report.session.pause.u
        s = [string]$script:Report.session.pause.s
        token = [string]$script:Report.session.pause.token
        il_operand = [string]$script:Report.session.pause.ilOperand
        emulated_time = [double]$script:Report.session.pause.emulatedTime
        full_call_observed = $false
        note = 'Only the first mapped node and operand were observed from the compiled repaired image; no later call or result is claimed.'
    }
    $script:Report.statuses.observed = $true
    $script:Report.statuses.fresh_boot_observed = $true
    Set-Phase 'inspect' 'passed' 'Paused PC/Y/U/S/token/mapped operand observed read-only from the compiled image' $inspectResult.exit_code
}
catch {
    $failureExit = if ($null -ne $inspectResult) { $inspectResult.exit_code } else { 1 }
    Add-WorkflowError 'inspect' $_.Exception.Message
    $script:Report.outcome = 'failed_observe'
    Set-Phase 'inspect' 'failed' $_.Exception.Message $failureExit
    Stop-LaunchedSessionForCleanup 'inspect'
    Write-Report
    Write-Summary $script:Report.outcome
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}

# ---- stop ---------------------------------------------------------------------
try {
    Set-Phase 'stop' 'running' 'Stopping the paused session through the strict command'
    $stopResult = Invoke-DebugCommand 'stop'
    if ($stopResult.exit_code -ne 0 -or $null -eq $stopResult.response) {
        throw "stop exited $($stopResult.exit_code) without a valid response"
    }
    $stop = $stopResult.response
    Assert-ResponseEqual $stop 'protocol' 'il-debug-session-v1' 'stop response'
    Assert-ResponseEqual $stop 'session' $script:Report.session.session_id 'stop response'
    Assert-ResponseEqual $stop 'command' 'stop' 'stop response'
    Assert-ResponseEqual $stop 'status' 'ok' 'stop response'
    Assert-ResponseEqual $stop 'kind' 'stopped' 'stop response'
    Assert-ResponseEqual $stop 'proof' 'exit_scheduled' 'stop response'
    Assert-ResponseEqual $stop 'exitScheduled' 'yes' 'stop response'
    $processId = [int]$script:Report.session.process_id
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    while ($null -ne (Get-Process -Id $processId -ErrorAction SilentlyContinue)) {
        if ([DateTime]::UtcNow -gt $deadline) { throw "MAME process $processId did not exit after stop" }
        Start-Sleep -Milliseconds 200
    }
    $exitCodePath = Join-Path $script:SessionDirectory 'mame-exit-code.txt'
    $exitDeadline = [DateTime]::UtcNow.AddSeconds(30)
    while (!(Test-Path -LiteralPath $exitCodePath -PathType Leaf)) {
        if ([DateTime]::UtcNow -gt $exitDeadline) { throw 'MAME exit-code record is missing' }
        Start-Sleep -Milliseconds 200
    }
    $mameExitCode = [int](([IO.File]::ReadAllText($exitCodePath)).Trim())
    if ($mameExitCode -ne 0) { throw "MAME exited $mameExitCode after stop" }
    if (Test-Path -LiteralPath (Join-Path $script:SessionDirectory 'session-timeout.txt')) { throw 'Session hit its wall timeout' }
    $runRomAfter = Get-RomIdentity (Join-Path $script:SessionDirectory 'roms/m4addr/a6ls.p1')
    if ($runRomAfter.sha256 -ine $script:RepairedSha256) { throw 'Isolated session ROM changed during the run' }
    if ((Get-Sha256 $script:OriginalFull) -ine $script:OriginalSha256) { throw 'Original ROM changed during the session' }
    $script:Report.session.stop = [ordered]@{
        response_path = $stopResult.response_path
        exit_code = $stopResult.exit_code
        duration_ms = $stopResult.duration_ms
        kind = [string]$stop['kind']
        proof = [string]$stop['proof']
        mame_exit_code = $mameExitCode
        session_timeout = $false
        run_rom_after = $runRomAfter
        run_rom_unchanged = $true
    }
    $script:Report.statuses.stopped = $true
    Set-Phase 'stop' 'passed' 'Session stopped cleanly and the isolated repaired ROM remained unchanged' $stopResult.exit_code
}
catch {
    $failureExit = if ($null -ne $stopResult) { $stopResult.exit_code } else { 1 }
    Add-WorkflowError 'stop' $_.Exception.Message
    $script:Report.outcome = 'failed_stop'
    Set-Phase 'stop' 'failed' $_.Exception.Message $failureExit
    Write-Report
    Write-Summary $script:Report.outcome
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}

$script:Report.outcome = 'complete_bounded_build_paused_observation'
Write-Summary $script:Report.outcome
Write-Report
Write-Output "WORKFLOW_REPORT=$script:ReportPath"
Write-Output "BUILD_SUMMARY=$script:SummaryPath"
Write-Output "SESSION_ID=$($script:Report.session.session_id)"
Write-Output "PROCESS_ID=$($script:Report.session.process_id)"
Write-Output "REPAIRED_IMAGE=$repairedPath"
Write-Output "SOURCE_MAP=$mapPath"
Write-Output "BUILD_REPORT=$buildReportPath"
Write-Output "STATUS=built,launched,paused,observed,stopped"
exit 0

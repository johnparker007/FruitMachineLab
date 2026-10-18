[CmdletBinding()]
param(
    [string]$MameExecutable = 'E:\Arcade\MAME0266\mame281.exe',
    [string]$RomDirectory = 'E:\Arcade\MAME0266\roms',
    [string]$OriginalRom = 'C:\Users\John\Documents\Codex\2026-10-13\help-me-set-up-a-local\outputs\mpu4\rom\a6ls.p1',
    [string]$OutputPath,
    [string]$RunRoot,
    [ValidateRange(1,120)][int]$SecondsToRun = 120,
    [ValidateRange(30,600)][int]$WallTimeoutSeconds = 600,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $repo 'evidence/mpu4/integrity/il-build-debug-workflow.json' }
$stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
if ([string]::IsNullOrWhiteSpace($RunRoot)) { $RunRoot = Join-Path $repo ('artifacts/deepseek/il-build-debug-24/test-runs/run-' + $stamp) }
$RunRoot = [IO.Path]::GetFullPath($RunRoot)
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$successRoot = Join-Path $RunRoot 'fresh-success'
$negRoot = Join-Path $RunRoot 'negatives'
$PlanPath = Join-Path $repo 'evidence/mpu4/integrity/il-natural-reachability-plan.json'
$ReplayPath = Join-Path $repo 'evidence/mpu4/skill-cash/actions.csv'
$InputLuaPath = Join-Path $repo 'evidence/mpu4/skill-cash/input.lua'
$EventJsonHelper = Join-Path $repo 'tests/worker/Test-IlEventJson.ps1'
$ManifestGenerator = Join-Path $repo 'tools/Update-CuratedManifest.ps1'
$OriginalSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$OriginalSha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
$UnrepairedSha256 = 'a99d96f8ea8b4770d2d3828125f25894e831726fe44a79a37e0871faba135ed2'
$RepairedSha1 = 'e1a42dccd304b7b175aabac99e8400cdad04cf69'
$RepairedSha256 = '577f76bd36dfca04dfb01b5f5d0be93e16572f8617c7ca906397c98df36e5107'
$MameSha256 = '0fce5a88df4f9d9b1fbf1405812c00848036e615993780978d967da34204cb7a'
$script:PwshPath = $null
$pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -ne $pwshCommand) { $script:PwshPath = $pwshCommand.Source }

$script:Utf8 = New-Object System.Text.UTF8Encoding($false)
$script:Checks = 0
$script:Failures = 0
$script:OwnedProcesses = New-Object 'System.Collections.Generic.List[int]'
function Write-Pass([string]$Message) { $script:Checks++; [Console]::WriteLine("PASS: $Message") }
function Write-Fail([string]$Message) { $script:Checks++; $script:Failures++; [Console]::WriteLine("FAIL: $Message") }
function Assert-True([bool]$Condition,[string]$Message) { if ($Condition) { Write-Pass $Message } else { Write-Fail $Message } }
function Assert-Equal($Actual,$Expected,[string]$Message) { if ([string]$Actual -eq [string]$Expected) { Write-Pass $Message } else { Write-Fail "$Message (actual '$Actual', expected '$Expected')" } }
function Assert-Match([string]$Actual,[string]$Pattern,[string]$Message) { if ($Actual -match $Pattern) { Write-Pass $Message } else { Write-Fail "$Message (actual '$Actual')" } }
function Assert-NotNull($Value,[string]$Message) { if ($null -ne $Value -and ![string]::IsNullOrWhiteSpace([string]$Value)) { Write-Pass $Message } else { Write-Fail $Message } }

function Get-Sha1([string]$Path) { return Get-HashHex $Path 'SHA1' }
function Get-Sha256([string]$Path) { return Get-HashHex $Path 'SHA256' }
function Get-HashHex([string]$Path,[string]$Algorithm) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        try { return ([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}
function Get-Offsets([byte[]]$A,[byte[]]$B) {
    $list = New-Object 'System.Collections.Generic.List[int]'
    for ($index=0; $index -lt $A.Length; $index++) { if ($A[$index] -ne $B[$index]) { [void]$list.Add($index) } }
    return $list.ToArray()
}
function Format-OffsetsHex([int[]]$Offsets) { return (@($Offsets | ForEach-Object { '{0:X4}' -f $_ }) -join ',') }
function Invoke-ChildPowerShell([string[]]$Arguments) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $text = (& powershell @Arguments 2>&1 | Out-String)
        return [ordered]@{ text = $text; exit_code = $LASTEXITCODE }
    }
    finally { $ErrorActionPreference = $previous }
}
function Invoke-PwshChild([string[]]$Arguments) {
    if ([string]::IsNullOrWhiteSpace($script:PwshPath)) { throw 'pwsh is required for the strict event JSON parser' }
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $text = (& $script:PwshPath @Arguments 2>&1 | Out-String)
        return [ordered]@{ text = $text; exit_code = $LASTEXITCODE }
    }
    finally { $ErrorActionPreference = $previous }
}
function Invoke-Workflow([string]$OutputRoot,[string]$Original = $OriginalRom,[string]$EditSpec = '9ED9:FF80->FF00',[string]$IlBuildProject = '') {
    $arguments = @('-NoProfile','-File',(Join-Path $repo 'tools/Build-IlDebugSession.ps1'),
        '-OriginalRom',$Original,'-MameExecutable',$MameExecutable,'-RomDirectory',$RomDirectory,
        '-OutputRoot',$OutputRoot,'-EditSpec',$EditSpec,'-SecondsToRun',[string]$SecondsToRun,
        '-WallTimeoutSeconds',[string]$WallTimeoutSeconds,'-CommandTimeoutSeconds','120')
    if (![string]::IsNullOrWhiteSpace($IlBuildProject)) { $arguments += @('-IlBuildProject',$IlBuildProject) }
    return Invoke-ChildPowerShell $arguments
}
function Invoke-Launcher([string]$RunDirectory,[string]$SourceMapPath,[string]$BuildReportPath,[string]$RepairedRom) {
    $arguments = @('-NoProfile','-File',(Join-Path $repo 'tools/Start-IlDebugSession.ps1'),
        '-MameExecutable',$MameExecutable,'-RomDirectory',$RomDirectory,'-OriginalRom',$OriginalRom,
        '-RepairedRom',$RepairedRom,'-Variant','Changed','-Definition','9ED9','-RunDirectory',$RunDirectory,
        '-SourceMapPath',$SourceMapPath,'-BuildReportPath',$BuildReportPath,'-PlanPath',$PlanPath,
        '-ReplayPath',$ReplayPath,'-InputLuaPath',$InputLuaPath,'-SecondsToRun',[string]$SecondsToRun,
        '-WallTimeoutSeconds',[string]$WallTimeoutSeconds)
    return Invoke-ChildPowerShell $arguments
}
function Invoke-StrictJson([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($script:PwshPath)) { throw 'pwsh with System.Text.Json is required for strict JSON checks' }
    $env:FML_STRICT_JSON_PATH = $Path
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $command = '$o=[System.Text.Json.JsonDocumentOptions]::new(); $o.AllowTrailingCommas=$false; $o.CommentHandling=[System.Text.Json.JsonCommentHandling]::Disallow; $d=[System.Text.Json.JsonDocument]::Parse([IO.File]::ReadAllText($env:FML_STRICT_JSON_PATH),$o); $d.Dispose(); Write-Output "OK"'
        $text = (& $script:PwshPath -NoProfile -Command $command 2>&1 | Out-String)
        return [ordered]@{ text = $text.Trim(); exit_code = $LASTEXITCODE; pass = ($LASTEXITCODE -eq 0 -and $text -match 'OK') }
    }
    finally {
        $ErrorActionPreference = $previous
        Remove-Item Env:FML_STRICT_JSON_PATH -ErrorAction SilentlyContinue
    }
}
function Assert-CanonicalJson([string]$Path,[string]$Label) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    Assert-True ($bytes.Length -gt 0 -and $bytes[$bytes.Length-1] -eq 0x7D) "$Label is a canonical JSON document ending at }"
    $strict = Invoke-StrictJson $Path
    Assert-True ([bool]$strict.pass) "$Label parses with strict System.Text.Json"
}
function Assert-Negative([string]$Label,$Result,[string]$Pattern,[string]$OutputRootToCheck) {
    $rejected = ($Result.exit_code -ne 0 -and $Result.text -match $Pattern)
    Assert-True $rejected "$Label is rejected before MAME"
    if (![string]::IsNullOrWhiteSpace($OutputRootToCheck)) {
        Assert-True (!(Test-Path -LiteralPath $OutputRootToCheck)) "$Label does not create its output root"
    }
    return [ordered]@{ name = $Label; rejected = $rejected; exit_code = $Result.exit_code; message = (($Result.text.Trim() -split "`r?`n")[0]) }
}
function Get-StateFileCount([string]$SessionDirectory) {
    $path = Join-Path $SessionDirectory 'state'
    if (!(Test-Path -LiteralPath $path -PathType Container)) { return 0 }
    return @(Get-ChildItem -LiteralPath $path -Recurse -File -ErrorAction SilentlyContinue).Count
}
function Stop-OwnedProcess([int]$ProcessId) {
    if ($ProcessId -gt 0 -and $null -ne (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) {
        & "$env:SystemRoot\System32\taskkill.exe" /PID $ProcessId /T /F 2>&1 | Out-Null
    }
}
function Read-ResponseFile([string]$Path) {
    $table = @{}
    foreach ($line in ([IO.File]::ReadAllText($Path) -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $index = $line.IndexOf('=')
        if ($index -lt 1) { throw "Response line is malformed: $line" }
        $table[$line.Substring(0,$index)] = $line.Substring($index+1)
    }
    return $table
}

$negatives = New-Object 'System.Collections.Generic.List[object]'
$originalBefore = $null
$success = $null
$report = $null
try {
    if (Test-Path -LiteralPath $RunRoot) { throw "Use a fresh test run root: $RunRoot" }
    New-Item -ItemType Directory -Path $RunRoot -ErrorAction Stop | Out-Null
    New-Item -ItemType Directory -Path $negRoot -ErrorAction Stop | Out-Null
    $originalBefore = Get-Sha256 $OriginalRom
    Assert-Equal $originalBefore $OriginalSha256 'original ROM starts with the supported identity'

    # ---- successful fresh workflow -------------------------------------------------
    $workflow = Invoke-Workflow $successRoot
    Assert-Equal $workflow.exit_code 0 'fresh workflow exits zero'
    if ($workflow.exit_code -ne 0) { [Console]::WriteLine($workflow.text) }
    Assert-True (Test-Path -LiteralPath (Join-Path $successRoot 'workflow-report.json') -PathType Leaf) 'workflow report exists'
    Assert-True (Test-Path -LiteralPath (Join-Path $successRoot 'build-summary.txt') -PathType Leaf) 'human-readable build summary exists'
    $reportPath = Join-Path $successRoot 'workflow-report.json'
    $summaryPath = Join-Path $successRoot 'build-summary.txt'
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    $summaryText = [IO.File]::ReadAllText($summaryPath)
    Assert-Equal $report.outcome 'complete_bounded_build_paused_observation' 'workflow outcome is the complete bounded observation'
    foreach ($phase in @('preflight','build','launch','pause','inspect','stop')) {
        Assert-Equal $report.phases.$phase.status 'passed' "phase $phase passed"
        Assert-Equal $report.phases.$phase.exit_code 0 "phase $phase actual exit is zero"
        Assert-Equal $report.actual_exits.$phase 0 "workflow summary actual exit for $phase is zero"
    }
    foreach ($status in @('built','launched','paused','observed','stopped','fresh_boot_observed')) {
        Assert-True ([bool]$report.statuses.$status) "status $status is true"
    }
    Assert-Equal $report.input.original.sha1 $OriginalSha1 'workflow records the original SHA1'
    Assert-Equal $report.input.original.sha256 $OriginalSha256 'workflow records the original SHA256'
    Assert-Equal $report.input.mame.sha256 $MameSha256 'workflow records the installed MAME SHA256'
    Assert-Equal $report.build.cli.exit_code 0 'IlBuildCLI actual exit is zero'
    $buildDir = Join-Path $successRoot 'build'
    $repairedPath = Join-Path $buildDir 'edited-repaired.p1'
    $unrepairedPath = Join-Path $buildDir 'edited-unrepaired.p1'
    $mapPath = Join-Path $buildDir 'source-map.json'
    $buildReportPath = Join-Path $buildDir 'build-report.json'
    $integrityReportPath = Join-Path $buildDir 'integrity-report.json'
    Assert-Equal (Get-Sha1 $repairedPath) $RepairedSha1 'fresh repaired image SHA1 is the accepted identity'
    Assert-Equal (Get-Sha256 $repairedPath) $RepairedSha256 'fresh repaired image SHA256 is the accepted identity'
    Assert-Equal (Get-Sha256 $unrepairedPath) $UnrepairedSha256 'fresh unrepaired image SHA256 is the accepted identity'
    $originalBytes = [IO.File]::ReadAllBytes($OriginalRom)
    $repairedBytes = [IO.File]::ReadAllBytes($repairedPath)
    $unrepairedBytes = [IO.File]::ReadAllBytes($unrepairedPath)
    Assert-Equal (Format-OffsetsHex (Get-Offsets $originalBytes $repairedBytes)) '9EDC,FFD1,FFD2,FFD3,FFD4,FFD5' 'original/repaired diff is exactly 9EDC plus the active fields'
    Assert-Equal (Format-OffsetsHex (Get-Offsets $unrepairedBytes $repairedBytes)) 'FFD1,FFD2,FFD3,FFD4,FFD5' 'repair-only diff is exactly the active fields'
    Assert-Equal ([int]$repairedBytes[0x9EDC]) 0 'compiled operand byte at 9EDC is 00'
    Assert-Equal ([int]$originalBytes[0x9EDC]) 128 'original operand byte at 9EDC is 80'

    $map = Get-Content -LiteralPath $mapPath -Raw | ConvertFrom-Json
    $buildReport = Get-Content -LiteralPath $buildReportPath -Raw | ConvertFrom-Json
    $integrityReport = Get-Content -LiteralPath $integrityReportPath -Raw | ConvertFrom-Json
    Assert-Equal $map.originalRomSha256 $OriginalSha256 'fresh source map records the original identity'
    Assert-Equal $map.outputImageSha256 $RepairedSha256 'fresh source map is output-bound to the repaired image'
    Assert-Equal @($map.entries).Count 14 'fresh source map covers fourteen bytes'
    Assert-Equal $buildReport.original.sha256 $OriginalSha256 'fresh build report records the original identity'
    Assert-Equal $buildReport.repaired.sha1 $RepairedSha1 'fresh build report records the repaired SHA1'
    Assert-Equal $buildReport.repaired.sha256 $RepairedSha256 'fresh build report records the repaired SHA256'
    Assert-Equal $buildReport.sourceMap.outputImageSha256 $RepairedSha256 'fresh build report source map is output-bound'
    Assert-Equal $buildReport.sourceMap.path $mapPath 'fresh build report points at the supplied source map'
    Assert-Equal $buildReport.repaired.path $repairedPath 'fresh build report points at the supplied repaired image'
    Assert-Equal $buildReport.edit.operandAddress '9EDB' 'fresh build report names operand 9EDB'
    Assert-Equal $buildReport.edit.replacementValue 'FF00' 'fresh build report names replacement FF00'
    Assert-Equal $integrityReport.repaired.sha256 $RepairedSha256 'fresh integrity report records the repaired image'
    Assert-Equal $report.output.source_map.sha256 (Get-Sha256 $mapPath) 'workflow report records the fresh source-map hash'
    Assert-Equal $report.output.build_report.sha256 (Get-Sha256 $buildReportPath) 'workflow report records the fresh build-report hash'
    Assert-Equal $report.output.integrity_report.sha256 (Get-Sha256 $integrityReportPath) 'workflow report records the fresh integrity-report hash'
    Assert-CanonicalJson $reportPath 'workflow report'
    Assert-CanonicalJson $mapPath 'source map'
    Assert-CanonicalJson $buildReportPath 'build report'
    Assert-CanonicalJson $integrityReportPath 'integrity report'

    # ---- actual paused observation -------------------------------------------------
    $sessionDir = Join-Path $successRoot 'session'
    Assert-Equal $report.session.run_directory $sessionDir 'workflow reports the isolated session directory'
    Assert-Match $report.session.session_id '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' 'workflow retains a valid session ID'
    Assert-True ([int]$report.session.process_id -gt 0) 'workflow retains a positive process ID'
    Assert-Match $report.session.mame_version '^0\.281\b' 'session used MAME 0.281'
    Assert-Equal $report.observed.node_index 0 'observed mapped node is 0'
    Assert-Equal $report.observed.boundary_phase 'prefetch' 'observation is at the prefetch boundary'
    Assert-Equal $report.observed.proof 'boundary_reached' 'observation has a native boundary proof'
    Assert-Equal $report.observed.pc '00FC' 'observed PC is 00FC'
    Assert-Equal $report.observed.y '9ED9' 'observed Y is 9ED9'
    Assert-Equal $report.observed.u '066E' 'observed U is 066E'
    Assert-Equal $report.observed.s '0796' 'observed S is 0796'
    Assert-Equal $report.observed.token '795B' 'observed token is 795B'
    Assert-Equal $report.observed.il_operand 'FF00' 'observed mapped IL operand is FF00 from the compiled image'
    Assert-True ([double]$report.observed.emulated_time -gt 0) 'observation reports positive emulated time'
    Assert-True (![bool]$report.observed.full_call_observed) 'workflow does not claim a full call'
    Assert-Equal $report.session.inspect.stateUnchanged 'yes' 'inspect reports no state change'
    Assert-Equal $report.session.inspect.proof 'stopped_read_only' 'inspect has the read-only proof'
    Assert-Equal $report.session.stop.kind 'stopped' 'stop response kind is stopped'
    Assert-Equal $report.session.stop.proof 'exit_scheduled' 'stop response has an exit proof'
    Assert-Equal $report.session.stop.mame_exit_code 0 'MAME exited zero after stop'
    Assert-True ([bool]$report.session.stop.run_rom_unchanged) 'isolated repaired ROM is unchanged after the run'
    Assert-Equal (Get-StateFileCount $sessionDir) 0 'session wrote no save states'
    Assert-True (!(Test-Path -LiteralPath (Join-Path $sessionDir 'session-timeout.txt'))) 'session did not hit its wall timeout'
    $pauseResponsePath = [string]$report.session.pause.response_path
    Assert-True (Test-Path -LiteralPath $pauseResponsePath -PathType Leaf) 'pause response file is retained'
    if (Test-Path -LiteralPath $pauseResponsePath -PathType Leaf) {
        $pauseResponse = Read-ResponseFile $pauseResponsePath
        Assert-Equal $pauseResponse['ilOperand'] 'FF00' 'retained pause response resolves the compiled operand'
        Assert-Equal $pauseResponse['execState'] 'stop' 'retained pause response reports stopped execution'
    }
    Assert-True ($summaryText -match 'Outcome: complete_bounded_build_paused_observation') 'build summary states the complete outcome'
    Assert-True ($summaryText -match 'PC=00FC Y=9ED9 U=066E S=0796') 'build summary records the observed registers'
    Assert-True ($summaryText -match 'IL operand=FF00') 'build summary records the observed mapped operand'
    Assert-True ($summaryText -match 'launched=True paused=True observed=True stopped=True') 'build summary distinguishes launched, paused, observed and stopped'

    $eventsPath = Join-Path $sessionDir 'events.jsonl'
    $eventsOutput = Join-Path $RunRoot 'events-summary.json'
    $eventsChild = Invoke-PwshChild @('-NoProfile','-File',$EventJsonHelper,'-Mode','Parse','-EventsPath',$eventsPath,'-OutputPath',$eventsOutput)
    Assert-Equal $eventsChild.exit_code 0 'session events parse with the existing strict JSONL parser'
    Assert-True (Test-Path -LiteralPath $eventsOutput -PathType Leaf) 'strict event summary exists'
    $eventsSummary = Get-Content -LiteralPath $eventsOutput -Raw | ConvertFrom-Json
    Assert-True ([bool]$eventsSummary.pass) 'strict event JSONL parse passes'
    Assert-Equal @($eventsSummary.failures).Count 0 'strict event JSONL has zero failures'
    Assert-True ([int]$eventsSummary.nonblank -gt 0) 'strict event JSONL has nonblank records'
    Assert-Equal ([int]$eventsSummary.nonblank) ([int]$eventsSummary.recordCount) 'every nonblank event record parsed'

    # ---- prelaunch negatives -------------------------------------------------------
    $wrongRomRoot = Join-Path $negRoot 'wrong-rom'
    $wrongRom = Invoke-Workflow $wrongRomRoot $repairedPath
    $negatives.Add((Assert-Negative 'wrong original identity' $wrongRom 'SHA' $wrongRomRoot))
    Assert-Equal (Get-Sha256 $repairedPath) $RepairedSha256 'wrong-original control preserves the repaired image'

    $existingRoot = Join-Path $negRoot 'existing-root'
    New-Item -ItemType Directory -Path $existingRoot -ErrorAction Stop | Out-Null
    $sentinelPath = Join-Path $existingRoot 'sentinel.txt'
    [IO.File]::WriteAllText($sentinelPath,'preserve-me',$script:Utf8)
    $existingResult = Invoke-Workflow $existingRoot
    $existingRejected = ($existingResult.exit_code -ne 0 -and $existingResult.text -match 'fresh create-only')
    Assert-True $existingRejected 'existing output root is rejected before MAME'
    Assert-Equal ([IO.File]::ReadAllText($sentinelPath)) 'preserve-me' 'existing output root contents are preserved'
    Assert-True (!(Test-Path -LiteralPath (Join-Path $existingRoot 'build'))) 'existing output root gained no build directory'
    Assert-True (!(Test-Path -LiteralPath (Join-Path $existingRoot 'session'))) 'existing output root gained no session directory'
    $negatives.Add([ordered]@{ name='existing output root'; rejected=$existingRejected; exit_code=$existingResult.exit_code; message=(($existingResult.text.Trim() -split "`r?`n")[0]) })

    $unsupportedRoot = Join-Path $negRoot 'unsupported-edit'
    $unsupported = Invoke-Workflow $unsupportedRoot $OriginalRom '9ED9:FF80->FF01'
    $negatives.Add((Assert-Negative 'unsupported edit request' $unsupported 'Unsupported edit request' $unsupportedRoot))

    $notProject = Join-Path $negRoot 'not-a-project'
    New-Item -ItemType Directory -Path $notProject -ErrorAction Stop | Out-Null
    $failedBuildRoot = Join-Path $negRoot 'failed-build'
    $failedBuild = Invoke-Workflow $failedBuildRoot $OriginalRom '9ED9:FF80->FF00' $notProject
    $failedBuildRejected = ($failedBuild.exit_code -ne 0 -and $failedBuild.text -match 'IlBuildCLI exited')
    Assert-True $failedBuildRejected 'failed IlBuildCLI is rejected before MAME'
    $failedReportPath = Join-Path $failedBuildRoot 'workflow-report.json'
    Assert-True (Test-Path -LiteralPath $failedReportPath -PathType Leaf) 'failed build retains a machine-readable workflow report'
    if (Test-Path -LiteralPath $failedReportPath -PathType Leaf) {
        $failedReport = Get-Content -LiteralPath $failedReportPath -Raw | ConvertFrom-Json
        Assert-Equal $failedReport.outcome 'failed_build' 'failed build report names the failed build outcome'
        Assert-Equal $failedReport.phases.build.status 'failed' 'failed build phase is marked failed'
        Assert-True ([int]$failedReport.phases.build.exit_code -ne 0) 'failed build report retains the actual nonzero exit'
        Assert-Equal $failedReport.phases.launch.status 'pending' 'failed build never enters the launch phase'
        Assert-True (![bool]$failedReport.statuses.built) 'failed build does not claim a built image'
        Assert-True (@($failedReport.errors).Count -gt 0) 'failed build report records an error'
        Assert-True (!(Test-Path -LiteralPath (Join-Path $failedBuildRoot 'session'))) 'failed build creates no session directory'
    }
    $negatives.Add([ordered]@{ name='failed build'; rejected=$failedBuildRejected; exit_code=$failedBuild.exit_code; message=(($failedBuild.text.Trim() -split "`r?`n")[0]) })

    # ---- stale or changed map/build controls ---------------------------------------
    $staleMap = Join-Path $negRoot 'stale-map.json'
    Copy-Item -LiteralPath $mapPath -Destination $staleMap
    Add-Content -LiteralPath $staleMap -Value ' '
    $staleMapRun = Join-Path $negRoot 'stale-map-run'
    $staleMapResult = Invoke-Launcher $staleMapRun $staleMap $buildReportPath $repairedPath
    $staleMapRejected = ($staleMapResult.exit_code -ne 0 -and $staleMapResult.text -match 'Source map SHA256')
    Assert-True $staleMapRejected 'stale source map is rejected before MAME'
    Assert-True (!(Test-Path -LiteralPath $staleMapRun)) 'stale source map creates no run directory'
    $negatives.Add([ordered]@{ name='stale source map'; rejected=$staleMapRejected; exit_code=$staleMapResult.exit_code; message=(($staleMapResult.text.Trim() -split "`r?`n")[0]) })

    $staleBuild = Join-Path $negRoot 'stale-build.json'
    Copy-Item -LiteralPath $buildReportPath -Destination $staleBuild
    Add-Content -LiteralPath $staleBuild -Value ' '
    $staleBuildRun = Join-Path $negRoot 'stale-build-run'
    $staleBuildResult = Invoke-Launcher $staleBuildRun $mapPath $staleBuild $repairedPath
    $staleBuildRejected = ($staleBuildResult.exit_code -ne 0 -and $staleBuildResult.text -match 'Build report SHA256')
    Assert-True $staleBuildRejected 'stale build report is rejected before MAME'
    Assert-True (!(Test-Path -LiteralPath $staleBuildRun)) 'stale build report creates no run directory'
    $negatives.Add([ordered]@{ name='stale build report'; rejected=$staleBuildRejected; exit_code=$staleBuildResult.exit_code; message=(($staleBuildResult.text.Trim() -split "`r?`n")[0]) })

    $wrongMap = Join-Path $negRoot 'wrong-binding-map.json'
    $wrongMapText = [IO.File]::ReadAllText($mapPath).Replace($RepairedSha256.ToUpperInvariant(),('0' * 64))
    [IO.File]::WriteAllText($wrongMap,$wrongMapText,(New-Object System.Text.UTF8Encoding($false)))
    $wrongMapRun = Join-Path $negRoot 'wrong-binding-map-run'
    $wrongMapResult = Invoke-Launcher $wrongMapRun $wrongMap $buildReportPath $repairedPath
    $wrongMapRejected = ($wrongMapResult.exit_code -ne 0 -and $wrongMapResult.text -match 'Source map is not bound')
    Assert-True $wrongMapRejected 'canonical source map with the wrong image binding is rejected'
    Assert-True (!(Test-Path -LiteralPath $wrongMapRun)) 'wrong-binding source map creates no run directory'
    $negatives.Add([ordered]@{ name='wrong-binding source map'; rejected=$wrongMapRejected; exit_code=$wrongMapResult.exit_code; message=(($wrongMapResult.text.Trim() -split "`r?`n")[0]) })

    $wrongBuild = Join-Path $negRoot 'wrong-binding-build.json'
    $wrongBuildText = [IO.File]::ReadAllText($buildReportPath).Replace($RepairedSha256.ToUpperInvariant(),('0' * 64))
    [IO.File]::WriteAllText($wrongBuild,$wrongBuildText,(New-Object System.Text.UTF8Encoding($false)))
    $wrongBuildRun = Join-Path $negRoot 'wrong-binding-build-run'
    $wrongBuildResult = Invoke-Launcher $wrongBuildRun $mapPath $wrongBuild $repairedPath
    $wrongBuildRejected = ($wrongBuildResult.exit_code -ne 0 -and $wrongBuildResult.text -match 'Build report repaired identity')
    Assert-True $wrongBuildRejected 'canonical build report with the wrong image identity is rejected'
    Assert-True (!(Test-Path -LiteralPath $wrongBuildRun)) 'wrong-binding build report creates no run directory'
    $negatives.Add([ordered]@{ name='wrong-binding build report'; rejected=$wrongBuildRejected; exit_code=$wrongBuildResult.exit_code; message=(($wrongBuildResult.text.Trim() -split "`r?`n")[0]) })

    # ---- preservation ---------------------------------------------------------------
    Assert-Equal (Get-Sha256 $OriginalRom) $OriginalSha256 'original ROM remains unchanged after all runs and negatives'
    Assert-Equal (Get-Sha256 $repairedPath) $RepairedSha256 'fresh repaired image remains unchanged'
    Assert-Equal ([IO.File]::ReadAllText($sentinelPath)) 'preserve-me' 'existing-root sentinel remains unchanged after all controls'

    # ---- curated evidence and manifest ---------------------------------------------
    if ($script:Failures -eq 0) {
        $reportSha256 = Get-Sha256 $reportPath
        $summarySha256 = Get-Sha256 $summaryPath
        $evidence = [ordered]@{
            schema_version = 1
            task = 'il-build-debug-24'
            generated_utc = [DateTime]::UtcNow.ToString('o')
            classification = 'Fresh create-only build of the single supported 9ED9 FF80 -> FF00 edit through the independent IlBuildCLI, followed by one isolated repaired-image paused MAME 0.281 observation of the first mapped node. Static build evidence and runtime observation are separate; no full-call, gameplay or hardware claim is made.'
            result_status = 'complete_bounded_build_paused_observation'
            workflow = [ordered]@{
                entrypoint = 'tools/Build-IlDebugSession.ps1'
                output_root = $successRoot
                report_path = $reportPath
                report_sha256 = $reportSha256
                summary_path = $summaryPath
                summary_sha256 = $summarySha256
                phases = $report.phases
                actual_exits = $report.actual_exits
                statuses = $report.statuses
            }
            inputs = [ordered]@{
                original = $report.input.original
                mame = $report.input.mame
                rom_directory = $report.input.rom_directory
                support = $report.input.support
            }
            build = [ordered]@{
                cli_exit_code = $report.build.cli.exit_code
                cli_stdout = $report.build.cli.stdout
                cli_stderr = $report.build.cli.stderr
                original = $report.build.original
                unrepaired = $report.build.unrepaired
                repaired = $report.build.repaired
                diff = $report.build.diff
                repair_only_diff = $report.build.repair_only_diff
                integrity = $report.build.integrity
                source_map = $report.output.source_map
                build_report = $report.output.build_report
                integrity_report = $report.output.integrity_report
                map_build_image_agree = [bool]$report.build.map_build_image_agree
            }
            observation = [ordered]@{
                session_id = $report.session.session_id
                process_id = $report.session.process_id
                run_directory = $report.session.run_directory
                mame_version = $report.session.mame_version
                mame_sha256 = $report.session.mame_sha256
                node_index = $report.observed.node_index
                boundary_phase = $report.observed.boundary_phase
                proof = $report.observed.proof
                pc = $report.observed.pc
                y = $report.observed.y
                u = $report.observed.u
                s = $report.observed.s
                token = $report.observed.token
                il_operand = $report.observed.il_operand
                emulated_time = $report.observed.emulated_time
                full_call_observed = [bool]$report.observed.full_call_observed
                inspect_state_unchanged = $report.session.inspect.stateUnchanged
                stop_kind = $report.session.stop.kind
                stop_proof = $report.session.stop.proof
                mame_exit_code = $report.session.stop.mame_exit_code
                run_rom_unchanged = [bool]$report.session.stop.run_rom_unchanged
                state_directory_files = Get-StateFileCount $sessionDir
                note = 'Only the first mapped node and operand were observed; no later call or result is claimed.'
            }
            negatives = $negatives.ToArray()
            preservation = [ordered]@{
                original_sha256_before = $originalBefore
                original_sha256_after = Get-Sha256 $OriginalRom
                original_unchanged = ((Get-Sha256 $OriginalRom) -eq $OriginalSha256)
                repaired_sha256 = Get-Sha256 $repairedPath
                existing_root_sentinel = [IO.File]::ReadAllText($sentinelPath)
                isolated_run_rom_unchanged = [bool]$report.session.stop.run_rom_unchanged
            }
            strict_json = [ordered]@{
                workflow_report = (Invoke-StrictJson $reportPath).pass
                source_map = (Invoke-StrictJson $mapPath).pass
                build_report = (Invoke-StrictJson $buildReportPath).pass
                integrity_report = (Invoke-StrictJson $integrityReportPath).pass
                session_events = [ordered]@{
                    path = $eventsPath
                    sha256 = Get-Sha256 $eventsPath
                    nonblank = [int]$eventsSummary.nonblank
                    parsed = [int]$eventsSummary.recordCount
                    failures = @($eventsSummary.failures).Count
                    pass = [bool]$eventsSummary.pass
                }
            }
            limitations = @(
                'Only the fixed 9ED9 definition and the first 795B literal at 9EDB are supported.',
                'Integrity repair is algorithmic; natural checker acceptance is observed only for this fresh boot, and physical hardware compatibility is not claimed.',
                'The paused observation covers the first mapped node and operand only; no later call, result, gameplay or paid-window behaviour is claimed.',
                'The imgui debugger requires BGFX and creates a rendering window; the Lua periodic callback is a command driver, not an instruction boundary.'
            )
        }
        $tempEvidence = $OutputPath + '.tmp-' + [guid]::NewGuid().ToString('N')
        $json = ConvertTo-Json -InputObject $evidence -Depth 30
        [IO.File]::WriteAllText($tempEvidence,$json,(New-Object System.Text.UTF8Encoding($false)))
        $strictEvidence = Invoke-StrictJson $tempEvidence
        Assert-True ([bool]$strictEvidence.pass) 'curated evidence parses with strict System.Text.Json'
        if ((Test-Path -LiteralPath $OutputPath) -and !$Force) {
            Remove-Item -LiteralPath $tempEvidence -Force
            Write-Fail "Evidence output already exists (use -Force): $OutputPath"
        } else {
            Move-Item -LiteralPath $tempEvidence -Destination $OutputPath -Force
            Write-Pass "Curated evidence written: $OutputPath"
            $generator = Invoke-ChildPowerShell @('-NoProfile','-File',$ManifestGenerator)
            Assert-Equal $generator.exit_code 0 'curated manifest generator exits zero'
            $verify = Invoke-ChildPowerShell @('-NoProfile','-File',$ManifestGenerator,'-Verify')
            Assert-Equal $verify.exit_code 0 'curated manifest verifies after evidence write'
            $manifestPath = Join-Path $repo 'evidence/curated-manifest.json'
            $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            $evidenceRelative = 'evidence/mpu4/integrity/il-build-debug-workflow.json'
            $evidenceIncluded = (@($manifest | Where-Object { $_.path -eq $evidenceRelative }).Count -eq 1)
            Assert-True $evidenceIncluded 'curated manifest includes the new workflow evidence'
            $entryCount = @($manifest).Count
            $evidence.manifest_verification = [ordered]@{
                path = $manifestPath
                entries = $entryCount
                verified = $true
                evidence_included = $evidenceIncluded
            }
            $json = ConvertTo-Json -InputObject $evidence -Depth 30
            [IO.File]::WriteAllText($OutputPath,$json,(New-Object System.Text.UTF8Encoding($false)))
            $strictFinal = Invoke-StrictJson $OutputPath
            Assert-True ([bool]$strictFinal.pass) 'final curated evidence parses with strict System.Text.Json'
            $generator2 = Invoke-ChildPowerShell @('-NoProfile','-File',$ManifestGenerator)
            Assert-Equal $generator2.exit_code 0 'curated manifest regenerates after final evidence write'
            $verify2 = Invoke-ChildPowerShell @('-NoProfile','-File',$ManifestGenerator,'-Verify')
            Assert-Equal $verify2.exit_code 0 'curated manifest verifies after final evidence write'
        }
    }
}
catch {
    Write-Fail $_.Exception.Message
}
finally {
    foreach ($processId in $script:OwnedProcesses) { Stop-OwnedProcess $processId }
    if ($null -ne $report -and $null -ne $report.session -and $null -ne $report.session.process_id) {
        Stop-OwnedProcess ([int]$report.session.process_id)
    }
}

Write-Output "Test-IlBuildDebugWorkflow: $($script:Checks) checks, $($script:Failures) failures"
Write-Output "RUNROOT=$RunRoot"
Write-Output "EVIDENCE=$OutputPath"
if ($script:Failures -gt 0) { exit 1 }

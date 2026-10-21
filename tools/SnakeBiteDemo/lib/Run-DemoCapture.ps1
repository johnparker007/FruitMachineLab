param(
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [Parameter(Mandatory=$true)][string]$TargetY,
    [Parameter(Mandatory=$true)][string]$PostY,
    [int]$EmulatedSeconds = 600,
    [int]$WallTimeoutSeconds = 300,
    [double]$ThrottleOnTime = 538.0,
    [int]$ManualSeconds = 60,
    [switch]$Manual,
    [string]$Mode = 'Win',
    [string]$MameExecutable = 'E:\Arcade\MAME0266\mame281.exe',
    [string]$SupportRomPath = 'E:\Arcade\MAME0266\roms',
    [string]$BgfxPath = 'E:\Arcade\MAME0266\bgfx'
)
$ErrorActionPreference = 'Stop'
function Get-Sha256Hex([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToUpperInvariant() }
    finally { $stream.Dispose(); $sha.Dispose() }
}
$run = [IO.Path]::GetFullPath($RunDirectory)
if (!(Test-Path -LiteralPath $run)) { throw "run directory does not exist: $run" }
if (!(Test-Path -LiteralPath $MameExecutable)) { throw "MAME executable not found: $MameExecutable" }
if (!(Test-Path -LiteralPath $SupportRomPath)) { throw "support ROM path not found: $SupportRomPath" }
if (!(Test-Path -LiteralPath $BgfxPath)) { throw "bgfx path not found: $BgfxPath" }

$romPath = Join-Path $run 'roms\m4addr\a6ls.p1'
$replayPath = Join-Path $run 'replay-actions.csv'
$inputLua = Join-Path $run 'input.lua'
$observer = Join-Path $run 'SnakeBiteObserver.lua'
foreach ($required in @($romPath, $replayPath, $inputLua, $observer)) {
    if (!(Test-Path -LiteralPath $required)) { throw "required run file missing: $required" }
}
foreach ($name in @('cfg','nvram','inp','snap','comments','state','diff')) {
    $path = Join-Path $run $name
    if (!(Test-Path -LiteralPath $path)) { New-Item -ItemType Directory -Path $path | Out-Null }
    $count = @(Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue).Count
    if ($count -ne 0) { throw "isolated directory $name is not empty: $count entries" }
}

$arguments = @(
    'm4addr',
    '-noreadconfig',
    '-rompath', "$(Join-Path $run 'roms');$SupportRomPath",
    '-cfg_directory', (Join-Path $run 'cfg'),
    '-nvram_directory', (Join-Path $run 'nvram'),
    '-input_directory', (Join-Path $run 'inp'),
    '-snapshot_directory', (Join-Path $run 'snap'),
    '-comment_directory', (Join-Path $run 'comments'),
    '-state_directory', (Join-Path $run 'state'),
    '-diff_directory', (Join-Path $run 'diff'),
    '-debug',
    '-debugger', 'imgui',
    '-debuglog',
    '-video', 'bgfx',
    '-sound', 'none',
    '-window',
    '-skip_gameinfo',
    '-nothrottle',
    '-seconds_to_run', [string]$EmulatedSeconds,
    '-autoboot_delay', '0',
    '-autoboot_script', $observer,
    '-bgfx_path', $BgfxPath
)

$envValues = [ordered]@{
    MPU4_REPLAY = $replayPath
    MPU4_POLICY = '7'
    FML_FEATURE_TARGET = $TargetY
    FML_FEATURE_POST = $PostY
    FML_RETURN_Y = 'E243'
    FML_THROTTLE_T = [string]$ThrottleOnTime
    FML_MANUAL = $(if ($Manual) { '1' } else { '0' })
    FML_MANUAL_SECONDS = [string]$ManualSeconds
    FML_DENSE_FROM = '32580'
    FML_MAX_FRAMES = '40000'
    FML_POST_RETURN_SECONDS = '1.5'
}

$launch = [ordered]@{
    mode = $Mode
    manual = [bool]$Manual
    runDirectory = $run
    mameExecutable = $MameExecutable
    mameSha256 = (Get-Sha256Hex $MameExecutable)
    romPath = $romPath
    romSha256 = (Get-Sha256Hex $romPath)
    replayPath = $replayPath
    replaySha256 = (Get-Sha256Hex $replayPath)
    inputLuaSha256 = (Get-Sha256Hex $inputLua)
    observerSha256 = (Get-Sha256Hex $observer)
    targetY = $TargetY
    postY = $PostY
    returnY = 'E243'
    emulatedSeconds = $EmulatedSeconds
    wallTimeoutSeconds = $WallTimeoutSeconds
    throttleOnTime = $ThrottleOnTime
    manualSeconds = $ManualSeconds
    arguments = $arguments
    childEnvironment = $envValues
}
$launch | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $run 'launch-record.json') -Encoding UTF8

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $MameExecutable
$psi.WorkingDirectory = $run
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
if ($psi.PSObject.Properties.Name -contains 'ArgumentList') {
    foreach ($a in $arguments) { [void]$psi.ArgumentList.Add($a) }
} else {
    $psi.Arguments = ($arguments | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
}
foreach ($key in $envValues.Keys) { $psi.EnvironmentVariables[$key] = [string]$envValues[$key] }

$startUtc = [DateTime]::UtcNow
$sw = [Diagnostics.Stopwatch]::StartNew()
$process = [Diagnostics.Process]::Start($psi)
$outTask = $process.StandardOutput.ReadToEndAsync()
$errTask = $process.StandardError.ReadToEndAsync()
$exited = $process.WaitForExit($WallTimeoutSeconds * 1000)
$sw.Stop()
if (-not $exited) {
    try { $process.Kill() } catch {}
    $outTask.Wait(5000) | Out-Null
    $errTask.Wait(5000) | Out-Null
    $result = [ordered]@{
        exitCode = $null
        timedOut = $true
        wallSeconds = [Math]::Round($sw.Elapsed.TotalSeconds, 3)
        startUtc = $startUtc.ToString('o')
        endUtc = [DateTime]::UtcNow.ToString('o')
        stdout = $outTask.Result
        stderr = $errTask.Result
    }
    $result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $run 'run-exit.json') -Encoding UTF8
    throw "MAME exceeded wall timeout ${WallTimeoutSeconds}s"
}
$outTask.Wait(5000) | Out-Null
$errTask.Wait(5000) | Out-Null
$result = [ordered]@{
    exitCode = $process.ExitCode
    timedOut = $false
    wallSeconds = [Math]::Round($sw.Elapsed.TotalSeconds, 3)
    startUtc = $startUtc.ToString('o')
    endUtc = [DateTime]::UtcNow.ToString('o')
    stdout = $outTask.Result
    stderr = $errTask.Result
}
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $run 'run-exit.json') -Encoding UTF8
$outTask.Result | Set-Content -LiteralPath (Join-Path $run 'console.out.txt') -Encoding UTF8
$errTask.Result | Set-Content -LiteralPath (Join-Path $run 'console.err.txt') -Encoding UTF8
Write-Output ("exit={0} timedOut={1} wallSeconds={2}" -f $result.exitCode, $result.timedOut, $result.wallSeconds)

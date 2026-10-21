param(
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [Parameter(Mandatory=$true)][string]$RomPath,
    [Parameter(Mandatory=$true)][string]$FixturePath,
    [Parameter(Mandatory=$true)][string]$FixtureSha256,
    [Parameter(Mandatory=$true)][string]$InputLua,
    [Parameter(Mandatory=$true)][string]$ObserverPath
)
$ErrorActionPreference = 'Stop'
function Get-Sha256Hex([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToUpperInvariant() }
    finally { $stream.Dispose(); $sha.Dispose() }
}
$run = [IO.Path]::GetFullPath($RunDirectory)
if (Test-Path -LiteralPath $run) { throw "run directory already exists: $run" }
foreach ($required in @($RomPath, $FixturePath, $InputLua, $ObserverPath)) {
    if (!(Test-Path -LiteralPath $required)) { throw "required file not found: $required" }
}
New-Item -ItemType Directory -Path (Join-Path $run 'roms\m4addr') -Force | Out-Null
foreach ($name in @('cfg','nvram','inp','snap','comments','state','diff')) {
    New-Item -ItemType Directory -Path (Join-Path $run $name) -Force | Out-Null
}
Copy-Item -LiteralPath $RomPath -Destination (Join-Path $run 'roms\m4addr\a6ls.p1')
Copy-Item -LiteralPath $InputLua -Destination (Join-Path $run 'input.lua')
Copy-Item -LiteralPath $ObserverPath -Destination (Join-Path $run 'SnakeBiteObserver.lua')

$replay = Join-Path $run 'replay-actions.csv'
$input = [IO.File]::OpenRead($FixturePath)
$gzip = $null
$output = $null
try {
    $gzip = New-Object IO.Compression.GZipStream($input, [IO.Compression.CompressionMode]::Decompress)
    $output = [IO.File]::Create($replay)
    $gzip.CopyTo($output)
}
finally {
    if ($output) { $output.Dispose() }
    if ($gzip) { $gzip.Dispose() }
    $input.Dispose()
}
$actualFixtureHash = Get-Sha256Hex $replay
if ($actualFixtureHash -ne $FixtureSha256.ToUpperInvariant()) {
    throw "decompressed fixture hash $actualFixtureHash differs from expected $FixtureSha256"
}

$record = [ordered]@{
    runDirectory = $run
    romPath = (Join-Path $run 'roms\m4addr\a6ls.p1')
    romSha256 = (Get-Sha256Hex (Join-Path $run 'roms\m4addr\a6ls.p1'))
    fixtureArchive = [IO.Path]::GetFileName($FixturePath)
    fixtureArchiveSha256 = (Get-Sha256Hex $FixturePath)
    replayPath = $replay
    replaySha256 = $actualFixtureHash
    inputLuaSha256 = (Get-Sha256Hex (Join-Path $run 'input.lua'))
    observerSha256 = (Get-Sha256Hex (Join-Path $run 'SnakeBiteObserver.lua'))
}
$record | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $run 'fixture-record.json') -Encoding UTF8
Write-Output ("run={0} replaySha256={1}" -f $run, $actualFixtureHash)

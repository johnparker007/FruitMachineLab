$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$failures = New-Object System.Collections.Generic.List[string]

function Get-Sha256Hex([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToUpperInvariant() }
    finally { $stream.Dispose(); $sha.Dispose() }
}

$fixtures = @(
    @{ Name = 'win-right.csv.gz';       Sha256 = 'B5E9A91560343345C1605707FEF9F7DD4FC51CC0A978F4539FC2C78580AE1D66' },
    @{ Name = 'loss-left.csv.gz';       Sha256 = '7134FAA251472C2FD87F104D85142A2978F4C465327EE6EBBA3BFBE78BE0D0AF' },
    @{ Name = 'control-nopress.csv.gz'; Sha256 = 'D2BB74AFFB770FF94D2B8DD1B49E8EFADAF431A8DF0597DC5617E3864BE68E1D' }
)
$temp = Join-Path ([IO.Path]::GetTempPath()) ('snakebite-fixture-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    foreach ($fixture in $fixtures) {
        $archive = Join-Path $root ('fixtures\' + $fixture.Name)
        $target = Join-Path $temp $fixture.Name.Replace('.gz','')
        $input = [IO.File]::OpenRead($archive)
        try {
            $gzip = New-Object IO.Compression.GZipStream($input, [IO.Compression.CompressionMode]::Decompress)
            try {
                $output = [IO.File]::Create($target)
                try { $gzip.CopyTo($output) } finally { $output.Dispose() }
            } finally { $gzip.Dispose() }
        } finally { $input.Dispose() }
        $actual = Get-Sha256Hex $target
        if ($actual -eq $fixture.Sha256) { Write-Output ("PASS fixture {0} {1}" -f $fixture.Name, $actual) }
        else { $failures.Add(('fixture {0} hash {1} != {2}' -f $fixture.Name, $actual, $fixture.Sha256)) }
    }
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

foreach ($relative in @('Run-SnakeBiteDemo.ps1','lib\New-DemoRun.ps1','lib\Run-DemoCapture.ps1')) {
    $path = Join-Path $root $relative
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$parseErrors)
    if ($parseErrors.Count -eq 0) { Write-Output ("PASS syntax {0}" -f $relative) }
    else { $failures.Add(('syntax {0}: {1}' -f $relative, ($parseErrors | ForEach-Object { $_.Message }) -join '; ')) }
}

$combined = (Get-Content -LiteralPath (Join-Path $root 'Run-SnakeBiteDemo.ps1') -Raw) +
    (Get-Content -LiteralPath (Join-Path $root 'lib\Run-DemoCapture.ps1') -Raw)
foreach ($expected in @('7124269C34881B2C8CCAA577DC2EDF28957EED3E69BC2052C5D789172D3653CF','EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C','MPU4_POLICY','MPU4_REPLAY')) {
    if ($combined.Contains($expected)) {
        Write-Output ("PASS identity reference {0}" -f $expected)
    } else {
        $failures.Add("missing identity reference $expected")
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Output ("FAIL {0}" -f $_) }
    exit 1
}
Write-Output 'PASS package integrity'
exit 0

param([string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$run = Join-Path $root ('artifacts/rom-patch-cli-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $run | Out-Null
$dll = Join-Path $root 'tools/FruitMachineLab.RomPatch/bin/Debug/net8.0/FruitMachineLab.RomPatch.dll'
function Invoke-Rejected($specPath,$sourcePath,$targetPath,$log) {
    $ErrorActionPreference = 'Continue' # Windows PowerShell wraps expected stderr in ErrorRecord.
    & dotnet $dll $specPath $sourcePath $targetPath 2>&1 | Out-File $log
    return $LASTEXITCODE
}
$inputFile = Join-Path $run 'original.bin'; $output = Join-Path $run 'patched.bin'; $specFile = Join-Path $run 'patch.json'
[byte[]]$bytes = 0..255; [IO.File]::WriteAllBytes($inputFile,$bytes)
$spec = @{SchemaVersion=1;Description='Synthetic CLI safety test';InputLength=256;InputSha1=(Get-FileHash $inputFile -Algorithm SHA1).Hash;Edits=@(@{Offset=10;ExpectedHex='0A';ReplacementHex='0C';Provenance='Synthetic'})}
$spec | ConvertTo-Json -Depth 5 | Set-Content $specFile
& dotnet $dll $specFile $inputFile $output > (Join-Path $run 'report.json')
if ($LASTEXITCODE -ne 0) { throw 'CLI patch failed' }
$hash = (Get-FileHash $output).Hash
$report = Get-Content (Join-Path $run 'report.json') -Raw | ConvertFrom-Json
if ($report.OutputSha256 -ne $hash -or $report.ChangedOffsets.Count -ne 1 -or $report.ChangedOffsets[0] -ne 10) { throw 'Invalid build report' }
if ((Invoke-Rejected $specFile $inputFile $output (Join-Path $run 'existing-error.txt')) -eq 0 -or (Get-FileHash $output).Hash -ne $hash) { throw 'Existing output overwritten' }
if ((Invoke-Rejected $specFile $inputFile $inputFile (Join-Path $run 'input-error.txt')) -eq 0 -or (Get-FileHash $inputFile -Algorithm SHA1).Hash -ne $spec.InputSha1) { throw 'Input overwrite accepted' }
$second = Join-Path $run 'repeat.bin'; & dotnet $dll $specFile $inputFile $second > $null
if ($LASTEXITCODE -ne 0 -or (Get-FileHash $second).Hash -ne $hash) { throw 'Non-reproducible output' }
$spec.InputSha1 = '0' * 40; $spec | ConvertTo-Json -Depth 5 | Set-Content $specFile
$bad = Join-Path $run 'rejected.bin'
if ((Invoke-Rejected $specFile $inputFile $bad (Join-Path $run 'identity-error.txt')) -eq 0 -or (Test-Path $bad)) { throw 'Wrong ROM created output' }
$identityError = Get-Content (Join-Path $run 'identity-error.txt') -Raw
if (!$identityError.Contains('Unexpected ROM identity or length') -or $identityError.Contains('Unhandled exception')) { throw 'Validation failure did not exit cleanly' }
Write-Output 'PASS CLI creation, report/readback, overwrite rejection, input preservation, reproducibility and wrong-ROM rejection'

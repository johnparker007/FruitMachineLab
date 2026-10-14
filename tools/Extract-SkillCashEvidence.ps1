param(
    [Parameter(Mandatory=$true)][string]$SourceRoot,
    [string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent)
)
$ErrorActionPreference='Stop'
# Reads the forensic workspace; writes only this repository's selected evidence.
$destination=Join-Path $RepositoryRoot 'evidence/mpu4/skill-cash'
New-Item -ItemType Directory -Force $destination | Out-Null
$excerpts=@{}
$sources=@{}
foreach($suffix in @('a','b')) {
    $source=Join-Path $SourceRoot "runs/vm-batch-policy7-$suffix/debug.log"
    $capturing=$false
    $rows=[System.Collections.Generic.List[string]]::new()
    $first=0; $last=0; $lineNumber=0
    foreach($line in [System.IO.File]::ReadLines($source)) {
        $lineNumber++
        if(!$capturing -and $line -match 'FEATURE_VM y=C721 ') { $capturing=$true; $first=$lineNumber }
        if($capturing) { $rows.Add($line) }
        if($capturing -and $line -match 'FEATURE_VM y=C71D ') { $last=$lineNumber; break }
    }
    if($first -eq 0 -or $last -eq 0) { throw "Complete feature interval not found in $source" }
    $excerpts[$suffix]=[string]::Join("`n",$rows)+"`n"
    $sources[$suffix]=@{path=$source;sha256=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash;first_line=$first;last_line=$last}
}
if($excerpts['a'] -cne $excerpts['b']) { throw 'Selected MAME replay intervals differ' }
$output=Join-Path $destination 'dispatch.txt'
[System.IO.File]::WriteAllText($output,$excerpts['a'],[System.Text.UTF8Encoding]::new($false))
@{sources=$sources;excerpts_equal=$true;excerpt_sha256=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash;scope='First C721 entry through first C71D dispatch, inclusive. Not a full campaign.'} |
    ConvertTo-Json -Depth 6 | Set-Content (Join-Path $destination 'extraction-verification.json')

param([switch]$Verify)
$ErrorActionPreference='Stop';$root=[IO.Path]::GetFullPath("$PSScriptRoot/..");$manifest=Join-Path $root 'evidence/curated-manifest.json'
if(!$Verify){
 $entries=@(Get-ChildItem (Join-Path $root 'evidence/mpu4'),(Join-Path $root 'docs/recovery') -Recurse -File|ForEach-Object {
  [ordered]@{path=[IO.Path]::GetRelativePath($root,$_.FullName).Replace('\','/');bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
 }|Sort-Object {$_.path})
 $entries|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $manifest
}
$rows=@(Get-Content -LiteralPath $manifest -Raw|ConvertFrom-Json)
foreach($row in $rows){$path=Join-Path $root $row.path;if((Get-Item -LiteralPath $path).Length -ne $row.bytes -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $row.sha256){throw "Curated manifest differs: $($row.path)"}}
Write-Output "Verified $($rows.Count) curated entries"

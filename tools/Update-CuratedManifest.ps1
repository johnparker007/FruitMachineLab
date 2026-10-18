param([switch]$Verify)
$ErrorActionPreference='Stop';$root=[IO.Path]::GetFullPath("$PSScriptRoot/..");$manifest=Join-Path $root 'evidence/curated-manifest.json'
function Get-RelativePath([string]$Base,[string]$Path){
 $baseFull=[IO.Path]::GetFullPath($Base).TrimEnd('\')+'\';$pathFull=[IO.Path]::GetFullPath($Path)
 if($pathFull.StartsWith($baseFull,[StringComparison]::OrdinalIgnoreCase)){return $pathFull.Substring($baseFull.Length)}
 return $pathFull
}
function Get-CanonicalBytes([string]$Path){
 # Canonical content identity is LF bytes. Accept LF or CRLF; reject BOM and bare CR.
 $bytes=[IO.File]::ReadAllBytes($Path)
 if($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF){throw "Curated manifest rejected BOM: $Path"}
 if($bytes.Length -ge 2 -and (($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) -or ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF))){throw "Curated manifest rejected BOM: $Path"}
 if($bytes.Length -ge 4 -and $bytes[0] -eq 0 -and $bytes[1] -eq 0 -and $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xFF){throw "Curated manifest rejected BOM: $Path"}
 $list=New-Object 'System.Collections.Generic.List[byte]'
 $list.Capacity=$bytes.Length
 for($index=0;$index -lt $bytes.Length;$index++){
  $value=$bytes[$index]
  if($value -eq 0x0D){
   if($index+1 -ge $bytes.Length -or $bytes[$index+1] -ne 0x0A){throw "Curated manifest rejected bare CR: $Path"}
   $index++
   [void]$list.Add([byte]0x0A)
  }else{[void]$list.Add($value)}
 }
 return $list.ToArray()
}
function Get-Sha256Hex([byte[]]$Bytes){
 $sha=[Security.Cryptography.SHA256]::Create()
 try{$hash=$sha.ComputeHash($Bytes)}finally{$sha.Dispose()}
 return ([BitConverter]::ToString($hash)).Replace('-','')
}
if(!$Verify){
 $entries=@(Get-ChildItem (Join-Path $root 'evidence/mpu4'),(Join-Path $root 'docs/recovery') -Recurse -File|ForEach-Object {
  $bytes=Get-CanonicalBytes $_.FullName
  [ordered]@{path=(Get-RelativePath $root $_.FullName).Replace('\','/');bytes=$bytes.Length;sha256=(Get-Sha256Hex $bytes)}
 }|Sort-Object {$_.path})
 $json=ConvertTo-Json -InputObject @($entries) -Depth 4
 $json=$json.Replace("`r`n","`n")
 if($json.Contains("`r")){throw 'Curated manifest generator produced a bare CR'}
 [IO.File]::WriteAllText($manifest,$json,(New-Object System.Text.UTF8Encoding($false)))
}
$rows=Get-Content -LiteralPath $manifest -Raw|ConvertFrom-Json
foreach($row in $rows){
 $path=Join-Path $root $row.path
 $bytes=Get-CanonicalBytes $path
 if($bytes.Length -ne $row.bytes -or (Get-Sha256Hex $bytes) -ne $row.sha256){throw "Curated manifest differs: $($row.path)"}
}
Write-Output "Verified $($rows.Count) curated entries"

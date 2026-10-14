param([Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$expected=(Get-Content (Join-Path $root 'evidence/mpu4/skill-cash/focused-verification.json') -Raw | ConvertFrom-Json).raw_debug_sha256
$source=Join-Path $RunDirectory 'debug.log'
if((Get-FileHash -LiteralPath $source).Hash -ne $expected){throw 'Source trace differs from verified capture'}
$seen=@{};$calls=[System.Collections.Generic.List[object]]::new();$active=$null;$key=$null
foreach($line in [System.IO.File]::ReadLines($source)) {
 if(!$line.StartsWith('SC ')){continue}
 $state=[ordered]@{}
 foreach($match in [regex]::Matches($line,'(\w+)=([0-9A-F]+)')){$state[$match.Groups[1].Value]=[Convert]::ToInt32($match.Groups[2].Value,16)}
 if($state.y -eq 0xC62B){
  $key=('{0}:{1}' -f ($state.frame -shr 8),$state.top)
  if(!$seen.ContainsKey($key)){$active=[System.Collections.Generic.List[object]]::new()}
 }
 if($null -ne $active){$active.Add($state)}
 if($state.y -eq 0xC633 -and $null -ne $active){$calls.Add([ordered]@{steps=@($active.ToArray())});$seen[$key]=$true;$active=$null}
}
if($calls.Count -eq 0 -or $null -ne $active){throw 'Incomplete lamp helper capture'}
[ordered]@{calls=@($calls.ToArray());raw_debug_sha256=$expected;
 classification='VM helper control/stack observations; native lamp requests reconstructed statically, hardware/frame-RAM effects remain unverified'} |
 ConvertTo-Json -Depth 7 | Set-Content (Join-Path $root 'evidence/mpu4/skill-cash/lamp-calls.json')

param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$SeedRam,[Parameter(Mandatory=$true)][string]$RunDirectory,[switch]$Flagged,[switch]$MatchingResult,[switch]$Plan,[switch]$FallbackResult)
$ErrorActionPreference='Stop';if($FallbackResult){$MatchingResult=$true};if($Plan -and ($Flagged -or $MatchingResult)){throw 'Plan cannot be combined with other native-entry switches'};$run=[IO.Path]::GetFullPath($RunDirectory)
if(Test-Path -LiteralPath $run){throw 'Use a fresh directory'}
New-Item -ItemType Directory -Path $run|Out-Null
foreach($name in @('cfg','nvram','state','snap','diff','comments')){New-Item -ItemType Directory (Join-Path $run $name)|Out-Null}
Copy-Item -LiteralPath $SeedRam -Destination "$run/seed.bin"
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$number=0
if(!$MatchingResult){foreach($budget in @(0,1,3,7,0x100,0x103,63,64,127,255)){
 $id='search-'+$number;$number++;$cases.Add([ordered]@{id=$id;kind=$(if($Plan){'plan'}elseif($Flagged){'flagged-search'}else{'search'});budget=$budget})
 foreach($command in @('load seed.bin,0','u=0x660','s=0x790','cc=0x50',('w@0x660=0x'+$budget.ToString('X4')),'b@0xdd=0xff','b@0xde=0x35',"save $id-before.bin,0,800",$(if($Plan){'pc=0x2a2f'}elseif($Flagged){'pc=0x29ec'}else{'pc=0x29f4'}),$(if($Plan){'g 0x2a7e'}else{'g 0x2a2e'}),"save $id-after.bin,0,800",('printf "MATRIX '+$id+' u=%04X result=%04X best=%02X dd=%02X de=%02X\n",u,w@u,b@0xc8,b@0xdd,b@0xde'))){$commands.Add($command)}
}
}
$lookupCases=@(@(2,2,2,0,0,0,0),@(2,4,5,1,1,1,0),@(2,4,5,2,2,2,255),@(2,4,5,2,2,2,0),@(3,3,5,0,0,0,0),@(2,3,3,0,0,0,0),@(0,0,0,1,1,1,255))
if($FallbackResult){foreach($bits in 0..7){$lookupCases+=,@(2,4,5,($bits -band 1),(($bits -shr 1) -band 1),(($bits -shr 2) -band 1),0)};$lookupCases+=,@(0,0,5,1,1,0,0);$lookupCases+=,@(6,5,6,0,0,0,0);$lookupCases+=,@(5,6,6,0,0,0,0)}
foreach($case in $lookupCases){
 $id='lookup-'+$number;$number++;$cases.Add([ordered]@{id=$id;kind=$(if($FallbackResult){'fallback-result'}elseif($MatchingResult){'matching-result'}else{'lookup'});values=$case})
 foreach($command in @('load seed.bin,0','s=0x790','cc=0x50','b@0xde=0x35',$(if($MatchingResult){'u=0x660'}else{'a=0'}))){$commands.Add($command)}
 for($reel=0;$reel -lt 3;$reel++){$commands.Add(('w@0x'+(0x160+2*$reel).ToString('X4')+'=0x'+(256*$case[$reel]+$case[$reel+3]).ToString('X4')))}
 foreach($command in @(('b@0xdd=0x'+$case[6].ToString('X2')), "save $id-before.bin,0,800",$(if($FallbackResult){'pc=0x1af1'}elseif($MatchingResult){'pc=0x1aa3'}else{'pc=0x1ac3'}),$(if($FallbackResult){'g 0x1afd'}elseif($MatchingResult){'g 0x1ac2'}else{'g 0x1b42'}),"save $id-after.bin,0,800",('printf "MATRIX '+$id+' b=%02X dd=%02X de=%02X\n",b,b@0xdd,b@0xde'))){$commands.Add($command)}
}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json -Depth 4|Set-Content "$run/cases.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-state_directory',"$run/state",'-snapshot_directory',"$run/snap",'-diff_directory',"$run/diff",'-comment_directory',"$run/comments",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
[ordered]@{plan=[bool]$Plan;flagged=[bool]$Flagged;matching_result=[bool]$MatchingResult;fallback_result=[bool]$FallbackResult;classification='Synthetic native helper matrix: explicit PC/U/S/CC/budget/symbol/flag setup; IRQs masked. Not a natural game path';mame_sha256=(Get-FileHash $MameExecutable).Hash;seed_sha256=(Get-FileHash "$run/seed.bin").Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
Push-Location $run
try{& $MameExecutable @arguments *> "$run/console.txt";$LASTEXITCODE|Set-Content "$run/exit-code.txt"}finally{Pop-Location}
Write-Output $run

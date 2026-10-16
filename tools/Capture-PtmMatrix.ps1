param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory)
if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run | Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory (Join-Path $run $name)|Out-Null}
$commands=[Collections.Generic.List[string]]::new()
$commands.Add('cc=0x50')
$commands.Add('wpset 0x900,8,w,(temp1==1 && wpaddr==0x900 && pc==0x719) || (temp1==3 && ((temp4==1 && wpaddr==0x907 && pc==0x723) || (temp4==0 && wpaddr==0x900 && pc==0x728))),{printf "PL channel=%X latch=%04X delay=%04X phase=%X cycle=%016X\n",temp1,temp2,temp3,temp4,totalcycles;go}')
$commands.Add('wpset 0x901,1,r,1,{printf "PR cycle=%016X value=%02X\n",totalcycles,wpdata;go}')
foreach($channel in @(1,3)){
 foreach($phase in $(if($channel -eq 3){@(0,1)}else{@(0)})){
 foreach($latch in @(0,1,30,40,41,255,3440,65535)){
  $expiry=if($channel -eq 1){$latch+1}else{8*($latch+1)}
  foreach($extra in @(0,4,8,12)){
   $bytes=[Collections.Generic.List[byte]]::new()
   function Emit([int[]]$values){foreach($v in $values){$bytes.Add([byte]$v)}}
   function Store([byte]$v,[int]$address){Emit @(0x86,$v,0xB7,($address -shr 8),($address -band 255))}
   Store 1 0x901;Store 1 0x900
   if($channel -eq 1){Store ($latch -shr 8) 0x902;Store ($latch -band 255) 0x903;Store 0x42 0x900}
   elseif($phase -eq 0){Store 0 0x901;Store 0x63 0x900;Store ($latch -shr 8) 0x906;Store ($latch -band 255) 0x907;Store 1 0x901;Store 0 0x900}
   else{Store 0 0x900;Store 0 0x901;Store 0x63 0x900;Store ($latch -shr 8) 0x906;Store ($latch -band 255) 0x907}
   $count=[Math]::Max(0,[int][Math]::Floor(($expiry-16)/7))
   if($count -gt 0){
    foreach($part in @([Math]::Min($count,65535),[Math]::Max(0,$count-65535))){
     if($part -eq 0){continue};Emit @(0xCC,($part -shr 8),($part -band 255),0x83,0,1,0x26,0xFB)
    }
   }
   foreach($n in 1..($extra+1)){Emit @(0x12)}
   Emit @(0xB6,0x09,0x01)
   $stop=0x700+$bytes.Count;Emit @(0x20,0xFE)
   $name=('case-{0}-{1}-{2}-{3}.bin' -f $channel,$latch,$extra,$phase);[IO.File]::WriteAllBytes((Join-Path $run $name),$bytes.ToArray())
   $commands.Add(('load {0},700;pc=0x700;cc=0x50;temp0=totalcycles;temp1={1:X};temp2={2:X};temp3={3:X};temp4={4:X}' -f $name,$channel,$latch,$extra,$phase))
   $commands.Add(('bpset {0:x}' -f $stop));$commands.Add('go')
   $commands.Add(('printf "PS channel={0} latch={1:X4} delay={2:X4} phase={3:X} start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a' -f $channel,$latch,$extra,$phase));$commands.Add('bpclear')
  }
 }
}
}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','10')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
Push-Location $run
try{& $MameExecutable @arguments *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location}
if($code -ne 0 -or (Select-String "$run/debug.log" -Pattern '^Error ' -Quiet)){throw 'Invalid/incomplete PTM experiment'}
[ordered]@{classification='Synthetic isolated MC6840 timer matrix; RAM timer-register program/delay loop and CPU masking/register injection, not gameplay; ROM/config originals untouched';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
Write-Output $run

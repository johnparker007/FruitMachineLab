param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory);if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null;foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new();$commands.Add('bpset 4d27');$commands.Add('bpset 4d71')
$pcs=@(0x6F51,0x6F57,0x6F5A,0x6F5C,0x6F5F,0x6F60,0x6F62,0x6F64,0x6F65,0x6F67,0x6F6B,0x6F6D,0x6F6F,0x6F70,0x6F73,0x6F75,0x6F78)
foreach($base in @(0x4D07,0x4D51)){foreach($offset in @(2,5,8,11,14,17,19,21,23,26,29)){$pcs+=($base+$offset)}}
foreach($pc in $pcs){$commands.Add(('bpset {0:X},1,{{printf "NI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $pc))}
foreach($entry in @(0x4D07,0x4D51)){foreach($mode in @(0,128)){foreach($value in @(0,499,500,65535,0x800000,0x800001,0x7FFFFF,0xFFFFFF)){
 $id=$cases.Count;$cases.Add([ordered]@{id=$id;entry=$entry;mode=$mode;value=$value});$commands.Add(('pc=0x{0:X};s=0x700;u=0x600;dp=0;cc=0x50;b@323=0x{1:X};b@2c=0x7a' -f $entry,$mode))
 for($p=0x7C9;$p -le 0x7E7;$p++){$commands.Add(('b@{0:X}=0x{1:X}' -f $p,(($p*17+31)-band 255)))}
 $commands.Add(('b@7d2=0x{0:X};w@7d3=0x{1:X}' -f ($value -shr 16),($value-band 65535)));$commands.Add("save compensation-$id-before.bin,0,800");$commands.Add('printf "NS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)');$commands.Add('go');$commands.Add('printf "NF pc=%04X cycle=%016X s=%04X u=%04X\n",pc,totalcycles,s,u');$commands.Add("save compensation-$id-after.bin,0,800")
}}}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json"
[ordered]@{token_compensation=$true;classification='32 synthetic original token compensation tails, explicit normal/service mode and signed24 boundaries, masked IRQ. Not natural payout.';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','30')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json";Push-Location $run;try{& $MameExecutable @arguments *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location};if($code -ne 0){throw 'Invalid compensation capture'};Write-Output $run

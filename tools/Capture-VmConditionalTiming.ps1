param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory)
if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new()
# All native instruction boundaries on the selected ROM paths, including shared tails.
$sites=@(0x7984,0x7986,0x797B,0x797D,0x797E,0x7980,0x7988,0x798A,0x79A8,0x79AA,0x799C,0x799E,0x79A0,0x79A2,0x79AC,0x79AE,0x79BB,0x79BD,0x79B2,0x79B5,0x79BF,0x79C1,0x7A71,0x7A73,0x7A75,0x7A77,0x7A4C,0x7A4F,0x7A51,0x7A3F,0x7A42,0x7A44,0x7ADE,0x7AE0,0x7AE3,0x7AF0,0x7AF2,0x7AE5,0x7AE9,0x7AEB,0x7AEE)
$commands.Add('bpset 0xfc')
foreach($site in $sites){$commands.Add(('bpset {0:X},1,{{printf "VI id=%X pc=%04X cycle=%016X cc=%02X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,cc,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}}' -f $site))}
function Case([int]$token,[int]$top,[int]$second,[int]$operand,[int]$cc){
 $id=$cases.Count
 $commands.Add(('temp1=0x{0:X};pc=w@{1:X};x=0x{2:X};y=0x402;u=0x600;s=0x700;dp=0;cc=0x{3:X};d=0xcafe;w@600=0x{4:X};w@602=0x{5:X};w@604=0x1234;w@402=0x{6:X}' -f $id,$token,($token+2),$cc,$top,$second,$operand))
 # Resuming skips a breakpoint at the current PC. Record that first boundary
 # explicitly before go; following boundaries are captured by breakpoint actions.
 $commands.Add('printf "VS id=%X pc=%04X cycle=%016X cc=%02X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,cc,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)')
 $commands.Add('go')
 $commands.Add('printf "VE id=%X pc=%04X cycle=%016X u=%04X y=%04X s=%04X top=%04X second=%04X cc=%02X\n",temp1,pc,totalcycles,u,y,s,w@u,w@(u+2),cc')
 $cases.Add([ordered]@{id=$id;token=$token;top=$top;second=$second;operand_word=$operand;initial_cc=$cc;initial_u=0x600;initial_y=0x402;initial_s=0x700})
}
foreach($cc in @(0x50,0x5F)){
 foreach($token in @(0x7982,0x798C,0x79A6,0x79B9)){
  foreach($top in @(0,1,0x8000,0xFFFF)){
   foreach($operand in @(0x0000,0x0100,0x7F00,0x8000,0xFF00)){Case $token $top 0xBEEF $operand $cc}
  }
 }
 foreach($token in @(0x7A6F,0x7ADC,0x7AE7)){
  foreach($top in @(0,1,0x7FFF,0x8000,0x8001,0xFFFF)){
   foreach($second in @(0,1,0x7FFF,0x8000,0x8001,0xFFFF)){Case $token $top $second 0 $cc}
  }
 }
}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json -Depth 4|Set-Content "$run/cases.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','10')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
Push-Location $run;try{& $MameExecutable @arguments *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location}
if($code -ne 0 -or (Select-String "$run/debug.log" -Pattern '^Error ' -Quiet)){throw 'Invalid conditional experiment'}
Write-Output "$($cases.Count) isolated native cases: $run"

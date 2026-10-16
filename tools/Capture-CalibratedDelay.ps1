param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory)
if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
$commands=[Collections.Generic.List[string]]::new();$cases=[Collections.Generic.List[object]]::new()
$commands.Add('bpset 0x800')
$commands.Add('bpset 0x7164,1,{printf "DE id=%X cycle=%016X\n",temp1,totalcycles;go}')
$commands.Add('bpset 0x7170,1,{printf "DX id=%X cycle=%016X\n",temp1,totalcycles;go}')
foreach($b in @(0,1,2,3,255)){foreach($a in @(0,255)){foreach($cc in @(0x50,0x5F)){
 $id=$cases.Count
 $commands.Add(('temp1=0x{0:X};pc=0x7159;cc=0x{1:X};dp=0;s=0x700;w@700=0x800;a=0x{2:X};b=0x{3:X};x=0x1234;y=0x2345;u=0x3456' -f $id,$cc,$a,$b))
 $commands.Add('printf "DS id=%X cycle=%016X gate=%02X\n",temp1,totalcycles,b@719b');$commands.Add('go')
 $commands.Add('printf "DF id=%X cycle=%016X pc=%04X a=%02X b=%02X s=%04X x=%04X y=%04X u=%04X\n",temp1,totalcycles,pc,a,b,s,x,y,u')
 $cases.Add([ordered]@{id=$id;count=$b;a=$a;initial_cc=$cc})
}}}
$literals=[Collections.Generic.List[object]]::new();$commands.Add('bpset 0xfc')
foreach($word in @(0,1)){foreach($value in @(0,1,0x7FFF,0x8000,0xFFFF)){foreach($cc in @(0x50,0x5F)){
 $id=$literals.Count;$pc=if($word){0x794F}else{0x7946}
 $commands.Add(('temp1=0x{0:X};pc=0x{1:X};cc=0x{2:X};dp=0;s=0x700;u=0x600;x=0x400;y=0x402;w@400=0x{3:X};w@600=0xbeef' -f $id,$pc,$cc,$value))
 $commands.Add('printf "LS id=%X cycle=%016X\n",temp1,totalcycles');$commands.Add('go')
 $commands.Add('printf "LF id=%X cycle=%016X pc=%04X u=%04X s=%04X y=%04X top=%04X second=%04X\n",temp1,totalcycles,pc,u,s,y,w@u,w@(u+2)')
 $literals.Add([ordered]@{id=$id;word=[bool]$word;value=$value;initial_cc=$cc})
}}}
$commands.Add('quit');$commands|Set-Content "$run/debugger.cmd";$cases|ConvertTo-Json|Set-Content "$run/cases.json";$literals|ConvertTo-Json|Set-Content "$run/literal-cases.json"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-seconds_to_run','60')
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
Push-Location $run;try{& $MameExecutable @arguments *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location}
if($code -ne 0 -or (Select-String "$run/debug.log" -Pattern '^Error ' -Quiet)){throw 'Invalid delay experiment'}
Write-Output $run

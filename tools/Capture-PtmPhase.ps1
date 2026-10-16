param([Parameter(Mandatory=$true)][string]$MameExecutable,[Parameter(Mandatory=$true)][string]$RomDirectory,[Parameter(Mandatory=$true)][string]$RunDirectory)
$ErrorActionPreference='Stop';$run=[IO.Path]::GetFullPath($RunDirectory)
if(Test-Path $run){throw 'Use a fresh isolated directory'}
New-Item -ItemType Directory $run|Out-Null
foreach($name in @('cfg','nvram','inp','snap','comments','state','diff')){New-Item -ItemType Directory "$run/$name"|Out-Null}
@'
local m=manager.machine;local cpu=m.devices[':maincpu'];local mem=cpu.spaces['program'];local ptm=assert(m.devices[':ptm_ic2'])
local f=assert(io.open('phase.csv','w'));f:setvbuf('no')
f:write('event,time,pc,output3,control1,control2,control3,latch3\n')
local count=0
local function item(name,i) return emu.item(assert(ptm.items['0/'..name])):read(i or 0) end
local function sample(event)
 local ok,err=pcall(function()
  f:write(string.format('%s,%.12f,%04X,%d,%d,%d,%d,%d\n',event,m.time:as_double(),cpu.state['PC'].value,item('m_output',2),item('m_control_reg',0),item('m_control_reg',1),item('m_control_reg',2),item('m_latch',2)))
 end)
 if not ok then f:write('ERROR ',tostring(err),'\n');count=100 end
end
_G.fml_ptm_write=mem:install_write_tap(0x907,0x907,'fml-ptm-write',function()
 if count<100 and cpu.state['PC'].value==0x710f then sample('write') end
end)
_G.fml_ptm_after=mem:install_read_tap(0x710f,0x710f,'fml-ptm-after',function()
 -- Opcode reads increment PC; exclude unrelated checksum/data/debugger reads.
 if count<100 and cpu.state['PC'].value==0x7110 then sample('after');count=count+1 end
end)
'@|Set-Content "$run/phase.lua"
@('gtime #40000','quit')|Set-Content "$run/debugger.cmd"
$arguments=@('m4addr','-noreadconfig','-rompath',$RomDirectory,'-cfg_directory',"$run/cfg",'-nvram_directory',"$run/nvram",'-input_directory',"$run/inp",'-snapshot_directory',"$run/snap",'-comment_directory',"$run/comments",'-state_directory',"$run/state",'-diff_directory',"$run/diff",'-debug','-debugger','windows','-debugscript',"$run/debugger.cmd",'-debuglog','-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle','-autoboot_delay','0','-autoboot_script',"$run/phase.lua")
$arguments|ConvertTo-Json|Set-Content "$run/arguments.json"
Push-Location $run;try{& $MameExecutable @arguments *> console.txt;$code=$LASTEXITCODE;$code|Set-Content exit-code.txt}finally{Pop-Location}
if($code -ne 0 -or (Select-String "$run/phase.csv" -Pattern '^ERROR ' -Quiet)){throw 'Invalid phase capture'}
$rows=@(Import-Csv "$run/phase.csv");if($rows.Count -ne 200){throw 'Incomplete100-arm phase capture'}
for($i=0;$i -lt 200;$i+=2){if($rows[$i].event -ne 'write' -or $rows[$i+1].event -ne 'after' -or $rows[$i].pc -ne '710F' -or $rows[$i+1].pc -ne '7110'){throw 'Phase pair differs'}}
[ordered]@{classification='Natural cold/default attract sequence, absent NVRAM, no physical inputs or state injection. Read-only PTM saved-item samples at native710B latch write and following opcode fetch; not the canonical Skill Cash campaign';mame_sha256=(Get-FileHash $MameExecutable).Hash}|ConvertTo-Json|Set-Content "$run/provenance.json"
Write-Output $run

-- Passive observer added to the original physical-input campaign. The dispatch
-- tap activates only at actual C721 entry; no ROM/RAM/register/input injection.
local m=manager.machine;local cpu=m.devices[':maincpu'];local mem=cpu.spaces['program'];local ptm=assert(m.devices[':ptm_ic2'])
local f=assert(io.open('ptm-skill-cpu.csv','w'));f:setvbuf('no')
f:write('event,pc,address,data,seconds,attoseconds,output3,control1,control2,control3,latch3,counter3,enabled3,single3,status,statusread,irq,gate3,clock3,cpuirq,cc,s,resume,y\n')
local active=false;local entered=false;local arms=0
local function item(device,name,i) return emu.item(assert(device.items['0/'..name])):read(i or 0) end
local function sample(event,address,data)
 local s=cpu.state['S'].value
 _G.fml_ptm_observer_read=true;local resume=mem:read_u16(s+10);_G.fml_ptm_observer_read=false
 f:write(string.format('%s,%04X,%04X,%02X,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%02X,%04X,%04X,%04X\n',event,cpu.state['PC'].value,address,data,m.time.seconds,m.time.attoseconds,item(ptm,'m_output',2),item(ptm,'m_control_reg',0),item(ptm,'m_control_reg',1),item(ptm,'m_control_reg',2),item(ptm,'m_latch',2),item(ptm,'m_counter',2),item(ptm,'m_enabled',2),item(ptm,'m_single_fired',2),item(ptm,'m_status_reg'),item(ptm,'m_status_read_since_int'),item(ptm,'m_irq'),item(ptm,'m_gate',2),item(ptm,'m_clk',2),item(cpu,'m_irq_line'),cpu.state['CC'].value,s,resume,cpu.state['Y'].value))
end
local function install()
if _G.fml_ptm_instruction_timing then
 local instructions=assert(io.open('ptm-instructions.csv','w'));instructions:setvbuf('no')
 instructions:write('event,address,pc,curpc,seconds,attoseconds,cc,cpuirq,ptmirq,status,bytes\n')
 local busy=false;local lastcpu=-1;local lastptm=-1
 _G.fml_skill_instruction=mem:install_read_tap(0,0xffff,'fml-skill-instruction',function(address,data)
  if not active or busy or _G.fml_ptm_observer_read then return end
  local pc=cpu.state['PC'].value;local curpc=cpu.state['CURPC'].value
  local irq=item(cpu,'m_irq_line');local ptmirq=item(ptm,'m_irq')
  local opcode=address==curpc and pc==address+1
  local event=opcode and 'opcode' or ((irq~=lastcpu or ptmirq~=lastptm) and 'line' or nil)
  lastcpu=irq;lastptm=ptmirq
  if not event then return end
  busy=true
  local bytes=''
  if opcode then _G.fml_ptm_observer_read=true;for i=0,4 do bytes=bytes..string.format('%02X',mem:read_u8((address+i)&0xffff)) end;_G.fml_ptm_observer_read=false end
  instructions:write(string.format('%s,%04X,%04X,%04X,%d,%d,%02X,%d,%d,%d,%s\n',event,address,pc,curpc,m.time.seconds,m.time.attoseconds,cpu.state['CC'].value,irq,ptmirq,item(ptm,'m_status_reg'),bytes))
  busy=false
 end)
end
_G.fml_skill_dispatch=mem:install_read_tap(0xfc,0xfc,'fml-skill-dispatch',function(address,data)
 if _G.fml_ptm_observer_read then return end
 if not entered and cpu.state['PC'].value==0xfd and cpu.state['Y'].value==0xc721 then entered=true;active=true;sample('entry',address,data) end
end)
_G.fml_skill_write=mem:install_write_tap(0x900,0x907,'fml-skill-write',function(address,data) if active and not _G.fml_ptm_observer_read then sample('write',address,data) end end)
_G.fml_skill_read=mem:install_read_tap(0x900,0x907,'fml-skill-read',function(address,data) if active and not _G.fml_ptm_observer_read then sample('read',address,data) end end)
_G.fml_skill_code=mem:install_read_tap(0x70c5,0x710f,'fml-skill-code',function(address,data)
 if _G.fml_ptm_observer_read then return end
 if active and cpu.state['PC'].value==address+1 and (address==0x70c5 or address==0x7109 or address==0x710f) then
  sample('after',address,data)
  if address==0x710f then arms=arms+1;if arms==20 then active=false end end
 end
end)
_G.fml_skill_irq=mem:install_read_tap(0xfe70,0xfe70,'fml-skill-irq',function(address,data) if active and not _G.fml_ptm_observer_read and cpu.state['PC'].value==0xfe71 then sample('handler',address,data) end end)
_G.fml_skill_callback=mem:install_read_tap(0x48fd,0x48fd,'fml-skill-callback',function(address,data) if active and not _G.fml_ptm_observer_read and cpu.state['PC'].value==0x48fe then sample('callback',address,data) end end)
end
local installed=false
emu.register_frame_done(function()
 if not installed and m.time:as_double()>=2040 then installed=true;install();f:write('installed\n') end
 if entered and not active and _G.fml_skill_instruction then _G.fml_skill_instruction:remove();_G.fml_skill_instruction=nil end
end,'frame')

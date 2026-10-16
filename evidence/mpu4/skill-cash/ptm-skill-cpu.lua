-- Passive observer added to the original physical-input campaign. The dispatch
-- tap activates only at actual C721 entry; no ROM/RAM/register/input injection.
local m=manager.machine;local cpu=m.devices[':maincpu'];local mem=cpu.spaces['program'];local ptm=assert(m.devices[':ptm_ic2'])
local f=assert(io.open('ptm-skill-cpu.csv','w'));f:setvbuf('no')
f:write('event,pc,address,data,seconds,attoseconds,output3,control1,control2,control3,latch3,counter3,enabled3,single3,status,statusread,irq,gate3,clock3,cpuirq,cc,s,resume,y\n')
local active=false;local entered=false;local arms=0
local function item(device,name,i) return emu.item(assert(device.items['0/'..name])):read(i or 0) end
local function sample(event,address,data)
 local s=cpu.state['S'].value
 f:write(string.format('%s,%04X,%04X,%02X,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%02X,%04X,%04X,%04X\n',event,cpu.state['PC'].value,address,data,m.time.seconds,m.time.attoseconds,item(ptm,'m_output',2),item(ptm,'m_control_reg',0),item(ptm,'m_control_reg',1),item(ptm,'m_control_reg',2),item(ptm,'m_latch',2),item(ptm,'m_counter',2),item(ptm,'m_enabled',2),item(ptm,'m_single_fired',2),item(ptm,'m_status_reg'),item(ptm,'m_status_read_since_int'),item(ptm,'m_irq'),item(ptm,'m_gate',2),item(ptm,'m_clk',2),item(cpu,'m_irq_line'),cpu.state['CC'].value,s,mem:read_u16(s+10),cpu.state['Y'].value))
end
local function install()
_G.fml_skill_dispatch=mem:install_read_tap(0xfc,0xfc,'fml-skill-dispatch',function(address,data)
 if not entered and cpu.state['PC'].value==0xfd and cpu.state['Y'].value==0xc721 then entered=true;active=true;sample('entry',address,data) end
end)
_G.fml_skill_write=mem:install_write_tap(0x900,0x907,'fml-skill-write',function(address,data) if active then sample('write',address,data) end end)
_G.fml_skill_read=mem:install_read_tap(0x900,0x907,'fml-skill-read',function(address,data) if active then sample('read',address,data) end end)
_G.fml_skill_code=mem:install_read_tap(0x70c5,0x710f,'fml-skill-code',function(address,data)
 if active and cpu.state['PC'].value==address+1 and (address==0x70c5 or address==0x7109 or address==0x710f) then
  sample('after',address,data)
  if address==0x710f then arms=arms+1;if arms==20 then active=false end end
 end
end)
_G.fml_skill_irq=mem:install_read_tap(0xfe70,0xfe70,'fml-skill-irq',function(address,data) if active and cpu.state['PC'].value==0xfe71 then sample('handler',address,data) end end)
_G.fml_skill_callback=mem:install_read_tap(0x48fd,0x48fd,'fml-skill-callback',function(address,data) if active and cpu.state['PC'].value==0x48fe then sample('callback',address,data) end end)
end
local installed=false
emu.register_frame_done(function()
 if not installed and m.time:as_double()>=2040 then installed=true;install();f:write('installed\n') end
end,'frame')

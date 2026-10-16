-- Read-only natural cold-attract observer. No input or state injection.
local m=manager.machine;local cpu=m.devices[':maincpu'];local mem=cpu.spaces['program'];local ptm=assert(m.devices[':ptm_ic2'])
local f=assert(io.open('lifecycle.csv','w'));f:setvbuf('no')
f:write('event,time,pc,address,data,output3,control1,control2,control3,latch3,counter3,enabled3,single3,status,irq,seconds,attoseconds\n')
local arms=0;local active=false
local function item(name,i) return emu.item(assert(ptm.items['0/'..name])):read(i or 0) end
local function sample(event,address,data)
 local ok,err=pcall(function()
  f:write(string.format('%s,%.12f,%04X,%04X,%02X,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n',event,m.time:as_double(),cpu.state['PC'].value,address,data,item('m_output',2),item('m_control_reg',0),item('m_control_reg',1),item('m_control_reg',2),item('m_latch',2),item('m_counter',2),item('m_enabled',2),item('m_single_fired',2),item('m_status_reg'),item('m_irq'),m.time.seconds,m.time.attoseconds))
 end)
 if not ok then f:write('ERROR ',tostring(err),'\n');active=false;arms=20 end
end
_G.fml_lifecycle_write=mem:install_write_tap(0x900,0x907,'fml-lifecycle-write',function(address,data)
 local pc=cpu.state['PC'].value
 if pc==0x7102 and arms<20 then active=true end
 if active then sample('write',address,data) end
end)
_G.fml_lifecycle_read=mem:install_read_tap(0x900,0x907,'fml-lifecycle-read',function(address,data)
 if active then sample('read',address,data) end
end)
_G.fml_lifecycle_code=mem:install_read_tap(0x70b3,0x710f,'fml-lifecycle-code',function(address,data)
 local pc=cpu.state['PC'].value
 if active and pc==address+1 and (address==0x70c5 or address==0x7109 or address==0x710f) then
  sample('after',address,data)
  if address==0x710f then arms=arms+1;if arms==20 then active=false end end
 end
end)

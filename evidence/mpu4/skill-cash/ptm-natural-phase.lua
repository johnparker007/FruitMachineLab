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

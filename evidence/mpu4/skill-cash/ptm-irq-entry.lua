local m=manager.machine;local cpu=m.devices[':maincpu'];local mem=cpu.spaces['program']
local f=assert(io.open('bus-time.csv','w'));f:setvbuf('no');f:write('event,pc,seconds,attoseconds\n')
_G.fml_irq_bus=mem:install_write_tap(0x900,0x900,'fml-irq-bus',function()
 if cpu.state['PC'].value==0x728 then f:write(string.format('release,%04X,%d,%d\n',cpu.state['PC'].value,m.time.seconds,m.time.attoseconds)) end
end)

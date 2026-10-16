local m=manager.machine;local cpu=m.devices[':maincpu'];local mem=cpu.spaces['program']
local f=assert(io.open('lamp-writes.csv','w'));f:setvbuf('no');f:write('pc,address,data,seconds,attoseconds\n')
_G.fml_lamp_callback_write=mem:install_write_tap(0xa00,0xb00,'fml-lamp-callback-write',function(address,data)
 local pc=cpu.state['CURPC'].value
 if (pc==0x490d and address==0xa00) or (pc==0x4910 and address==0xa02) or (pc==0x491f and address==0xb00) then
  f:write(string.format('%04X,%04X,%02X,%d,%d\n',pc,address,data,m.time.seconds,m.time.attoseconds))
 end
end)

-- Read-only observation plus explicitly scheduled physical input overrides.
local m=manager.machine
local cpu=m.devices[":maincpu"]
local mem=cpu.spaces["program"]
local log=assert(io.open("state.csv","w"))
local inventory=assert(io.open("input-fields.txt","w"))
for tag,port in pairs(m.ioport.ports) do
 for name,field in pairs(port.fields) do inventory:write(tag," ",name," mask=",tostring(field.mask),"\n") end
end
inventory:close()
-- Adaptive choices generate a frame-exact physical-input fixture; replay bypasses policy.
local variant=tonumber(os.getenv("MPU4_POLICY") or "0")
local replay=os.getenv("MPU4_REPLAY")
local events={}
if replay then
 for line in io.lines(replay) do
  local f,l,p,k=line:match("^(%d+),(%d+),([^,]+),(%d+),")
  if f then table.insert(events,{first=tonumber(f),last=tonumber(l),port=p,mask=tonumber(k)}) end
 end
end
local actions=assert(io.open("actions.csv","w"));actions:write("first_frame,last_frame,port,mask,reason,display,credits,nudges\n")
local controls={}
for _,mask in ipairs({1,2,4,8,16,32,64,128}) do controls[":BLACK2:"..mask]=assert(m.ioport.ports[":BLACK2"]:field(mask)) end
controls[":AUX2:128"]=assert(m.ioport.ports[":AUX2"]:field(128))
local ports=assert(io.open("input-levels.csv","w"));ports:write("frame,t,aux2,black2,coin_override\n")
local next_choice=2100
local turn=0
local super_step=0
local last_coin_frame=-10000
local function display()
 local out=""
 for a=0x58,0x67 do local c=mem:read_u8(a)&63;if c<32 then c=c+64 end;out=out..string.char(c) end
 return out
end
local function pulse(frame,port,mask,length,reason,text)
 local e={first=frame,last=frame+length,port=port,mask=mask};table.insert(events,e)
 actions:write(string.format("%d,%d,%s,%d,%s,%s,%d,%d\n",e.first,e.last,port,mask,reason,text,mem:read_u8(0x2f0),mem:read_u8(0xbe)));actions:flush()
end
log:write("t,pc,y,u,s,raw_black1,raw_black2,service,credit_candidate,state_2f0,state_304,seed,reel0,reel1,reel2,reel3,lamps,alpha,ram160_19f,bank_words\n")
local features=assert(io.open("feature-state.csv","w"));features:write("frame,t,c9,eb,bf,be,reel166,flags_a0,pending,current,bank,display\n")
local frame=0
emu.register_frame_done(function()
 local t=m.time:as_double()
 frame=frame+1
 local text=display()
 features:write(string.format("%d,%.9f,%d,%d,%d,%d,%d,%04X,%d,%d,%d,%s\n",frame,t,mem:read_u8(0xc9),mem:read_u8(0xeb),mem:read_u8(0xbf),mem:read_u8(0xbe),mem:read_u8(0x166),mem:read_u16(0xa0),mem:read_u16(0xba),mem:read_u16(0x2fa),mem:read_u16(0x2fc),text))
 if not replay and frame>=next_choice then
  turn=turn+1
  local credits=mem:read_u8(0x2f0)
  local busy=(mem:read_u8(0x6b)&128)~=0
  if text:find("ALM",1,true) then
   next_choice=frame+600 -- Preserve alarm evidence, never inject service reset.
  elseif text:find("SUPER HOLD",1,true) then
   local masks={2,4,8,128};pulse(frame,":BLACK2",masks[super_step%4+1],12,"superhold_select_or_confirm",text);super_step=super_step+1;next_choice=frame+90
  elseif text:find("NUDGE",1,true) and mem:read_u8(0xbe)>0 then
   pulse(frame,":BLACK2",2^(1+(turn+variant)%3),9,"nudge",text);next_choice=frame+90
  elseif text:find("DICE",1,true) or text:find("TAKE",1,true) or text:find("BACK",1,true) or text:find("ADVANCE",1,true) or text:find("BOOST",1,true) or text:find("RATTLER",1,true) then
   pulse(frame,":BLACK2",(variant>=4 and turn%3==0) and 1 or 128,12,"feature_roll_or_take",text);next_choice=frame+120
  elseif text:find("EXCHANGE",1,true) or text:find("EXCH",1,true) then
   pulse(frame,":BLACK2",variant%2==0 and 64 or 1,9,"exchange_or_collect",text);next_choice=frame+120
  elseif text:find("HI",1,true) or text:find("LO",1,true) or text:find("GAMBLE",1,true) then
   pulse(frame,":BLACK2",variant==2 and 1 or (turn%2==0 and 16 or 32),9,"gamble_choice",text);next_choice=frame+120
  elseif credits<3 and not busy and mem:read_u16(0xba)==0 and mem:read_u16(0x2fa)==0 then
   pulse(frame,":AUX2",128,3,"short_coin",text);next_choice=frame+120
  elseif not busy and mem:read_u16(0xba)==0 and mem:read_u16(0x2fa)==0 then
   if variant>0 and turn%3==0 then pulse(frame,":BLACK2",2^(1+((turn//3+variant)%3)),9,"hold_probe",text);next_choice=frame+45
   else pulse(frame,":BLACK2",128,12,"start_probe",text);next_choice=frame+180 end
  else
   pulse(frame,":BLACK2",({128,16,32,2,4,8,64,1})[(turn+variant)%8+1],9,"busy_choice_probe",text);next_choice=frame+60
  end
 end
 local values={}
 for _,e in ipairs(events) do local key=e.port..":"..string.format("%d",e.mask);values[key]=(values[key] or false) or (frame>=e.first and frame<e.last) end
 for key,field in pairs(controls) do field:set_value(values[key] and 1 or 0) end
 ports:write(string.format("%d,%.9f,%02X,%02X,%d\n",frame,t,m.ioport.ports[":AUX2"]:read(),m.ioport.ports[":BLACK2"]:read(),values[":AUX2:128"] and 1 or 0))
 if frame%6==0 then
  local lamps="";for a=0x100,0x13f do lamps=lamps..string.format("%02X",mem:read_u8(a)) end
  local alpha="";for a=0x58,0x67 do alpha=alpha..string.format("%02X",mem:read_u8(a)) end
  local extra="";for a=0x160,0x19f do extra=extra..string.format("%02X",mem:read_u8(a)) end
  local bank="";for a=0x2fa,0x303 do bank=bank..string.format("%02X",mem:read_u8(a)) end
  log:write(string.format("%.9f,%04X,%04X,%04X,%04X,%02X,%02X,%02X,%06X,%02X,%02X,%04X,%04X,%04X,%04X,%04X,%s,%s,%s,%s\n",t,cpu.state["PC"].value,cpu.state["Y"].value,cpu.state["U"].value,cpu.state["S"].value,mem:read_u8(2),mem:read_u8(3),mem:read_u8(0x323),mem:read_u8(0x3fe)*65536+mem:read_u16(0x3ff),mem:read_u8(0x2f0),mem:read_u8(0x304),mem:read_u16(0x324),mem:read_u16(0x150),mem:read_u16(0x152),mem:read_u16(0x154),mem:read_u16(0x156),lamps,alpha,extra,bank));log:flush()
 end
end,"frame")

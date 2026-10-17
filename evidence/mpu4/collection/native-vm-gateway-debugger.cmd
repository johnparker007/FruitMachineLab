temp0=0
bpset fc,temp0==1
bpset 76f6,temp0==0
bpset 4cd1
wpset 80c,1,w,1,{printf "GW cycle=%016X value=%02X\n",totalcycles,wpdata;go}
bpset 76C1,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76C3,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76C5,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76C9,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76CC,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76D0,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76D2,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76D4,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76D7,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76D9,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76DB,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76DD,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76DF,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76E1,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76E4,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76E7,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76E9,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76EB,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76EF,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76F2,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76F8,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76FA,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76FC,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 76FE,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7700,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7702,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7705,temp0==1,{printf "GI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
load seed.bin,0
temp0=0
pc=0x76bf
a=0x12
b=0x34
dp=0
cc=0x50
x=0xa8f9
y=0xbeef
u=0x600
s=0x790
w@790=0x4cd1
w@f2=0x456
w@a0=1
w@f8=0x3420
w@fa=0x3184
w@fc=0xaea1
w@fe=0x6e91
b@f1=0x00
b@f8=0
save gateway-0-before.bin,0,800
printf "GS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
save gateway-0-entry.bin,0,800
printf "GX pc=%04X cycle=%016X x=%04X y=%04X u=%04X s=%04X\n",pc,totalcycles,x,y,u,s
go
save gateway-0-return.bin,0,800
printf "GR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
save gateway-0-after.bin,0,800
printf "GF pc=%04X cycle=%016X a=%02X b=%02X dp=%02X cc=%02X x=%04X y=%04X u=%04X s=%04X\n",pc,totalcycles,a,b,dp,cc,x,y,u,s
load seed.bin,0
temp0=0
pc=0x76bf
a=0x12
b=0x34
dp=0
cc=0x50
x=0xa8f9
y=0xbeef
u=0x600
s=0x790
w@790=0x4cd1
w@f2=0x456
w@a0=1
w@f8=0x3420
w@fa=0x3184
w@fc=0xaea1
w@fe=0x6e91
b@f1=0x01
b@f8=0
save gateway-1-before.bin,0,800
printf "GS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
save gateway-1-entry.bin,0,800
printf "GX pc=%04X cycle=%016X x=%04X y=%04X u=%04X s=%04X\n",pc,totalcycles,x,y,u,s
go
save gateway-1-return.bin,0,800
printf "GR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
save gateway-1-after.bin,0,800
printf "GF pc=%04X cycle=%016X a=%02X b=%02X dp=%02X cc=%02X x=%04X y=%04X u=%04X s=%04X\n",pc,totalcycles,a,b,dp,cc,x,y,u,s
load seed.bin,0
temp0=0
pc=0x76bf
a=0x12
b=0x34
dp=0
cc=0x50
x=0xa8f9
y=0xbeef
u=0x600
s=0x790
w@790=0x4cd1
w@f2=0x456
w@a0=1
w@f8=0x3420
w@fa=0x3184
w@fc=0xaea1
w@fe=0x6e91
b@f1=0x08
b@f8=0
save gateway-2-before.bin,0,800
printf "GS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
save gateway-2-entry.bin,0,800
printf "GX pc=%04X cycle=%016X x=%04X y=%04X u=%04X s=%04X\n",pc,totalcycles,x,y,u,s
go
save gateway-2-return.bin,0,800
printf "GR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
save gateway-2-after.bin,0,800
printf "GF pc=%04X cycle=%016X a=%02X b=%02X dp=%02X cc=%02X x=%04X y=%04X u=%04X s=%04X\n",pc,totalcycles,a,b,dp,cc,x,y,u,s
load seed.bin,0
temp0=0
pc=0x76bf
a=0x12
b=0x34
dp=0
cc=0x50
x=0xa8f9
y=0xbeef
u=0x600
s=0x790
w@790=0x4cd1
w@f2=0x456
w@a0=1
w@f8=0x3420
w@fa=0x3184
w@fc=0xaea1
w@fe=0x6e91
b@f1=0xFF
b@f8=0
save gateway-3-before.bin,0,800
printf "GS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
save gateway-3-entry.bin,0,800
printf "GX pc=%04X cycle=%016X x=%04X y=%04X u=%04X s=%04X\n",pc,totalcycles,x,y,u,s
go
save gateway-3-return.bin,0,800
printf "GR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
save gateway-3-after.bin,0,800
printf "GF pc=%04X cycle=%016X a=%02X b=%02X dp=%02X cc=%02X x=%04X y=%04X u=%04X s=%04X\n",pc,totalcycles,a,b,dp,cc,x,y,u,s
load seed.bin,0
temp0=0
pc=0x76bf
a=0x12
b=0x34
dp=0
cc=0x50
x=0xa8f9
y=0xbeef
u=0x600
s=0x790
w@790=0x4cd1
w@f2=0x456
w@a0=1
w@f8=0x3420
w@fa=0x3184
w@fc=0xaea1
w@fe=0x6e91
b@f1=0x00
save gateway-4-before.bin,0,800
printf "GS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
save gateway-4-entry.bin,0,800
printf "GX pc=%04X cycle=%016X x=%04X y=%04X u=%04X s=%04X\n",pc,totalcycles,x,y,u,s
go
save gateway-4-return.bin,0,800
printf "GR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
save gateway-4-after.bin,0,800
printf "GF pc=%04X cycle=%016X a=%02X b=%02X dp=%02X cc=%02X x=%04X y=%04X u=%04X s=%04X\n",pc,totalcycles,a,b,dp,cc,x,y,u,s
load seed.bin,0
temp0=0
pc=0x76bf
a=0x12
b=0x34
dp=0
cc=0x50
x=0xa8f9
y=0xbeef
u=0x600
s=0x790
w@790=0x4cd1
w@f2=0x456
w@a0=1
w@f8=0x3420
w@fa=0x3184
w@fc=0xaea1
w@fe=0x6e91
b@f1=0x01
save gateway-5-before.bin,0,800
printf "GS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
save gateway-5-entry.bin,0,800
printf "GX pc=%04X cycle=%016X x=%04X y=%04X u=%04X s=%04X\n",pc,totalcycles,x,y,u,s
go
save gateway-5-return.bin,0,800
printf "GR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
save gateway-5-after.bin,0,800
printf "GF pc=%04X cycle=%016X a=%02X b=%02X dp=%02X cc=%02X x=%04X y=%04X u=%04X s=%04X\n",pc,totalcycles,a,b,dp,cc,x,y,u,s
load seed.bin,0
temp0=0
pc=0x76bf
a=0x12
b=0x34
dp=0
cc=0x50
x=0xa8f9
y=0xbeef
u=0x600
s=0x790
w@790=0x4cd1
w@f2=0x456
w@a0=1
w@f8=0x3420
w@fa=0x3184
w@fc=0xaea1
w@fe=0x6e91
b@f1=0x08
save gateway-6-before.bin,0,800
printf "GS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
save gateway-6-entry.bin,0,800
printf "GX pc=%04X cycle=%016X x=%04X y=%04X u=%04X s=%04X\n",pc,totalcycles,x,y,u,s
go
save gateway-6-return.bin,0,800
printf "GR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
save gateway-6-after.bin,0,800
printf "GF pc=%04X cycle=%016X a=%02X b=%02X dp=%02X cc=%02X x=%04X y=%04X u=%04X s=%04X\n",pc,totalcycles,a,b,dp,cc,x,y,u,s
load seed.bin,0
temp0=0
pc=0x76bf
a=0x12
b=0x34
dp=0
cc=0x50
x=0xa8f9
y=0xbeef
u=0x600
s=0x790
w@790=0x4cd1
w@f2=0x456
w@a0=1
w@f8=0x3420
w@fa=0x3184
w@fc=0xaea1
w@fe=0x6e91
b@f1=0xFF
save gateway-7-before.bin,0,800
printf "GS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
save gateway-7-entry.bin,0,800
printf "GX pc=%04X cycle=%016X x=%04X y=%04X u=%04X s=%04X\n",pc,totalcycles,x,y,u,s
go
save gateway-7-return.bin,0,800
printf "GR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
save gateway-7-after.bin,0,800
printf "GF pc=%04X cycle=%016X a=%02X b=%02X dp=%02X cc=%02X x=%04X y=%04X u=%04X s=%04X\n",pc,totalcycles,a,b,dp,cc,x,y,u,s
quit

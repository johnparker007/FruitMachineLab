bpset 4c34
bpset 6A08,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A0A,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A0C,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A0D,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A0F,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A11,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A13,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A16,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A18,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A1B,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A1E,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A20,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A23,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A25,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A28,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
pc=0x6a08;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@72=0x0;b@75=0xff;b@b03=0x0
save operation-0-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-0-after.bin,0,800
pc=0x6a08;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@72=0x0;b@75=0xff;b@b03=0x4
save operation-1-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-1-after.bin,0,800
pc=0x6a08;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@72=0x0;b@75=0xff;b@b03=0x34
save operation-2-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-2-after.bin,0,800
pc=0x6a08;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@72=0x0;b@75=0xff;b@b03=0x3C
save operation-3-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-3-after.bin,0,800
pc=0x6a08;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@72=0x1;b@75=0xff;b@b03=0x0
save operation-4-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-4-after.bin,0,800
pc=0x6a08;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@72=0x1;b@75=0xff;b@b03=0x4
save operation-5-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-5-after.bin,0,800
pc=0x6a08;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@72=0x1;b@75=0xff;b@b03=0x34
save operation-6-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-6-after.bin,0,800
pc=0x6a08;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@72=0x1;b@75=0xff;b@b03=0x3C
save operation-7-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-7-after.bin,0,800
pc=0x6a08;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@72=0x80;b@75=0xff;b@b03=0x0
save operation-8-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-8-after.bin,0,800
pc=0x6a08;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@72=0x80;b@75=0xff;b@b03=0x4
save operation-9-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-9-after.bin,0,800
pc=0x6a08;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@72=0x80;b@75=0xff;b@b03=0x34
save operation-10-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-10-after.bin,0,800
pc=0x6a08;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@72=0x80;b@75=0xff;b@b03=0x3C
save operation-11-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-11-after.bin,0,800
pc=0x6a08;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@72=0xFF;b@75=0xff;b@b03=0x0
save operation-12-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-12-after.bin,0,800
pc=0x6a08;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@72=0xFF;b@75=0xff;b@b03=0x4
save operation-13-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-13-after.bin,0,800
pc=0x6a08;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@72=0xFF;b@75=0xff;b@b03=0x34
save operation-14-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-14-after.bin,0,800
pc=0x6a08;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@72=0xFF;b@75=0xff;b@b03=0x3C
save operation-15-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-15-after.bin,0,800
quit

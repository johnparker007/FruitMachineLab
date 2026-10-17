bpset 4c34
bpset 69A9,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 69AB,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 69AD,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 69AF,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 69B0,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 69B3,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 69B5,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 69B7,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 69B9,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 69BB,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 69BD,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 69BF,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
pc=0x69a9;a=0x0;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x0
save operation-0-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-0-after.bin,0,800
pc=0x69a9;a=0x0;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x4
save operation-1-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-1-after.bin,0,800
pc=0x69a9;a=0x0;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x34
save operation-2-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-2-after.bin,0,800
pc=0x69a9;a=0x0;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x3C
save operation-3-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-3-after.bin,0,800
pc=0x69a9;a=0x1;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x0
save operation-4-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-4-after.bin,0,800
pc=0x69a9;a=0x1;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x4
save operation-5-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-5-after.bin,0,800
pc=0x69a9;a=0x1;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x34
save operation-6-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-6-after.bin,0,800
pc=0x69a9;a=0x1;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x3C
save operation-7-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-7-after.bin,0,800
pc=0x69a9;a=0x2;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x0
save operation-8-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-8-after.bin,0,800
pc=0x69a9;a=0x2;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x4
save operation-9-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-9-after.bin,0,800
pc=0x69a9;a=0x2;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x34
save operation-10-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-10-after.bin,0,800
pc=0x69a9;a=0x2;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x3C
save operation-11-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-11-after.bin,0,800
pc=0x69a9;a=0x3;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x0
save operation-12-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-12-after.bin,0,800
pc=0x69a9;a=0x3;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x4
save operation-13-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-13-after.bin,0,800
pc=0x69a9;a=0x3;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x34
save operation-14-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-14-after.bin,0,800
pc=0x69a9;a=0x3;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x3C
save operation-15-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-15-after.bin,0,800
pc=0x69a9;a=0x80;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x0
save operation-16-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-16-after.bin,0,800
pc=0x69a9;a=0x80;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x4
save operation-17-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-17-after.bin,0,800
pc=0x69a9;a=0x80;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x34
save operation-18-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-18-after.bin,0,800
pc=0x69a9;a=0x80;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x3C
save operation-19-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-19-after.bin,0,800
pc=0x69a9;a=0x81;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x0
save operation-20-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-20-after.bin,0,800
pc=0x69a9;a=0x81;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x4
save operation-21-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-21-after.bin,0,800
pc=0x69a9;a=0x81;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x34
save operation-22-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-22-after.bin,0,800
pc=0x69a9;a=0x81;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x3C
save operation-23-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-23-after.bin,0,800
pc=0x69a9;a=0xFE;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x0
save operation-24-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-24-after.bin,0,800
pc=0x69a9;a=0xFE;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x4
save operation-25-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-25-after.bin,0,800
pc=0x69a9;a=0xFE;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x34
save operation-26-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-26-after.bin,0,800
pc=0x69a9;a=0xFE;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x3C
save operation-27-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-27-after.bin,0,800
pc=0x69a9;a=0xFF;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x0
save operation-28-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-28-after.bin,0,800
pc=0x69a9;a=0xFF;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x4
save operation-29-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-29-after.bin,0,800
pc=0x69a9;a=0xFF;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x34
save operation-30-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-30-after.bin,0,800
pc=0x69a9;a=0xFF;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@78=0x37c;b@c01=0x3C
save operation-31-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X\n",pc,totalcycles,b@c01
go
printf "OF pc=%04X cycle=%016X s=%04X a=%02X x=%04X\n",pc,totalcycles,s,a,x
save operation-31-after.bin,0,800
quit

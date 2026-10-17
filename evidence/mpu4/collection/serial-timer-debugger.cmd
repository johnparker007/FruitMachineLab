bpset 4c34
bpset 70cb,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 70d8,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 70CD,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 70CF,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 70D2,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 70D4,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 70DA,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 70DD,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 70E0,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 70E2,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 70E4,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 70E7,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 70E9,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 70ED,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
pc=0x70C9;a=0x89;b=0xab;x=0x69c0;y=0x0;u=0x600;s=0x700;dp=0;cc=0x0;w@700=0x4c34;w@3b=0;b@3f=0;b@901=0
save operation-0-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@901,b@904
go
printf "OF pc=%04X cycle=%016X s=%04X b=%02X cc=%02X\n",pc,totalcycles,s,b,cc
save operation-0-after.bin,0,800
pc=0x70C9;a=0x89;b=0xab;x=0x69c0;y=0x0;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@3b=0;b@3f=0;b@901=0
save operation-1-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@901,b@904
go
printf "OF pc=%04X cycle=%016X s=%04X b=%02X cc=%02X\n",pc,totalcycles,s,b,cc
save operation-1-after.bin,0,800
pc=0x70C9;a=0x89;b=0xab;x=0x69c0;y=0x1;u=0x600;s=0x700;dp=0;cc=0x0;w@700=0x4c34;w@3b=0;b@3f=0;b@901=0
save operation-2-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@901,b@904
go
printf "OF pc=%04X cycle=%016X s=%04X b=%02X cc=%02X\n",pc,totalcycles,s,b,cc
save operation-2-after.bin,0,800
pc=0x70C9;a=0x89;b=0xab;x=0x69c0;y=0x1;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@3b=0;b@3f=0;b@901=0
save operation-3-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@901,b@904
go
printf "OF pc=%04X cycle=%016X s=%04X b=%02X cc=%02X\n",pc,totalcycles,s,b,cc
save operation-3-after.bin,0,800
pc=0x70C9;a=0x89;b=0xab;x=0x69c0;y=0x1234;u=0x600;s=0x700;dp=0;cc=0x0;w@700=0x4c34;w@3b=0;b@3f=0;b@901=0
save operation-4-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@901,b@904
go
printf "OF pc=%04X cycle=%016X s=%04X b=%02X cc=%02X\n",pc,totalcycles,s,b,cc
save operation-4-after.bin,0,800
pc=0x70C9;a=0x89;b=0xab;x=0x69c0;y=0x1234;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@3b=0;b@3f=0;b@901=0
save operation-5-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@901,b@904
go
printf "OF pc=%04X cycle=%016X s=%04X b=%02X cc=%02X\n",pc,totalcycles,s,b,cc
save operation-5-after.bin,0,800
pc=0x70C9;a=0x89;b=0xab;x=0x69c0;y=0xFFFF;u=0x600;s=0x700;dp=0;cc=0x0;w@700=0x4c34;w@3b=0;b@3f=0;b@901=0
save operation-6-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@901,b@904
go
printf "OF pc=%04X cycle=%016X s=%04X b=%02X cc=%02X\n",pc,totalcycles,s,b,cc
save operation-6-after.bin,0,800
pc=0x70C9;a=0x89;b=0xab;x=0x69c0;y=0xFFFF;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@3b=0;b@3f=0;b@901=0
save operation-7-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@901,b@904
go
printf "OF pc=%04X cycle=%016X s=%04X b=%02X cc=%02X\n",pc,totalcycles,s,b,cc
save operation-7-after.bin,0,800
pc=0x70D6;a=0x89;b=0xab;x=0x69c0;y=0x0;u=0x600;s=0x700;dp=0;cc=0x0;w@700=0x4c34;w@3b=0;b@3f=0;b@901=0
save operation-8-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@901,b@904
go
printf "OF pc=%04X cycle=%016X s=%04X b=%02X cc=%02X\n",pc,totalcycles,s,b,cc
save operation-8-after.bin,0,800
pc=0x70D6;a=0x89;b=0xab;x=0x69c0;y=0x0;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@3b=0;b@3f=0;b@901=0
save operation-9-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@901,b@904
go
printf "OF pc=%04X cycle=%016X s=%04X b=%02X cc=%02X\n",pc,totalcycles,s,b,cc
save operation-9-after.bin,0,800
pc=0x70D6;a=0x89;b=0xab;x=0x69c0;y=0x1;u=0x600;s=0x700;dp=0;cc=0x0;w@700=0x4c34;w@3b=0;b@3f=0;b@901=0
save operation-10-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@901,b@904
go
printf "OF pc=%04X cycle=%016X s=%04X b=%02X cc=%02X\n",pc,totalcycles,s,b,cc
save operation-10-after.bin,0,800
pc=0x70D6;a=0x89;b=0xab;x=0x69c0;y=0x1;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@3b=0;b@3f=0;b@901=0
save operation-11-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@901,b@904
go
printf "OF pc=%04X cycle=%016X s=%04X b=%02X cc=%02X\n",pc,totalcycles,s,b,cc
save operation-11-after.bin,0,800
pc=0x70D6;a=0x89;b=0xab;x=0x69c0;y=0x1234;u=0x600;s=0x700;dp=0;cc=0x0;w@700=0x4c34;w@3b=0;b@3f=0;b@901=0
save operation-12-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@901,b@904
go
printf "OF pc=%04X cycle=%016X s=%04X b=%02X cc=%02X\n",pc,totalcycles,s,b,cc
save operation-12-after.bin,0,800
pc=0x70D6;a=0x89;b=0xab;x=0x69c0;y=0x1234;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@3b=0;b@3f=0;b@901=0
save operation-13-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@901,b@904
go
printf "OF pc=%04X cycle=%016X s=%04X b=%02X cc=%02X\n",pc,totalcycles,s,b,cc
save operation-13-after.bin,0,800
pc=0x70D6;a=0x89;b=0xab;x=0x69c0;y=0xFFFF;u=0x600;s=0x700;dp=0;cc=0x0;w@700=0x4c34;w@3b=0;b@3f=0;b@901=0
save operation-14-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@901,b@904
go
printf "OF pc=%04X cycle=%016X s=%04X b=%02X cc=%02X\n",pc,totalcycles,s,b,cc
save operation-14-after.bin,0,800
pc=0x70D6;a=0x89;b=0xab;x=0x69c0;y=0xFFFF;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;w@3b=0;b@3f=0;b@901=0
save operation-15-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@901,b@904
go
printf "OF pc=%04X cycle=%016X s=%04X b=%02X cc=%02X\n",pc,totalcycles,s,b,cc
save operation-15-after.bin,0,800
quit

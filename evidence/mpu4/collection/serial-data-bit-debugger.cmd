bpset 4c34
bpset 70d6
bpset 70c9
bpset 6AA3,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6AA5,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6AA7,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6AAA,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6AAC,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6AAF,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6AB3,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6AB6,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6AB9,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6ABA,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6ABC,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6ABE,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6AC0,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
wpset 901,1,r,1,{printf "OA address=0901 value=%02X write=0 cycle=%016X\n",wpdata,totalcycles;go}
wpset 901,1,w,1,{printf "OA address=0901 value=%02X write=1 cycle=%016X\n",wpdata,totalcycles;go}
wpset 904,1,r,1,{printf "OA address=0904 value=%02X write=0 cycle=%016X\n",wpdata,totalcycles;go}
wpset 904,1,w,1,{printf "OA address=0904 value=%02X write=1 cycle=%016X\n",wpdata,totalcycles;go}
wpset 905,1,r,1,{printf "OA address=0905 value=%02X write=0 cycle=%016X\n",wpdata,totalcycles;go}
wpset 905,1,w,1,{printf "OA address=0905 value=%02X write=1 cycle=%016X\n",wpdata,totalcycles;go}
wpset B02,1,r,1,{printf "OA address=0B02 value=%02X write=0 cycle=%016X\n",wpdata,totalcycles;go}
wpset B02,1,w,1,{printf "OA address=0B02 value=%02X write=1 cycle=%016X\n",wpdata,totalcycles;go}
wpset B03,1,r,1,{printf "OA address=0B03 value=%02X write=0 cycle=%016X\n",wpdata,totalcycles;go}
wpset B03,1,w,1,{printf "OA address=0B03 value=%02X write=1 cycle=%016X\n",wpdata,totalcycles;go}
wpset C01,1,r,1,{printf "OA address=0C01 value=%02X write=0 cycle=%016X\n",wpdata,totalcycles;go}
wpset C01,1,w,1,{printf "OA address=0C01 value=%02X write=1 cycle=%016X\n",wpdata,totalcycles;go}
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x0;b@74=0x0;b@77=0xff
save operation-0-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-0-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x0;b@74=0x55;b@77=0xff
save operation-1-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-1-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x0;b@74=0x80;b@77=0xff
save operation-2-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-2-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x0;b@74=0xFF;b@77=0xff
save operation-3-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-3-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x0;b@74=0x0;b@77=0xff
save operation-4-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-4-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x0;b@74=0x55;b@77=0xff
save operation-5-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-5-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x0;b@74=0x80;b@77=0xff
save operation-6-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-6-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x0;b@74=0xFF;b@77=0xff
save operation-7-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-7-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x1;b@74=0x0;b@77=0xff
save operation-8-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-8-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x1;b@74=0x55;b@77=0xff
save operation-9-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-9-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x1;b@74=0x80;b@77=0xff
save operation-10-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-10-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x1;b@74=0xFF;b@77=0xff
save operation-11-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-11-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x1;b@74=0x0;b@77=0xff
save operation-12-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-12-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x1;b@74=0x55;b@77=0xff
save operation-13-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-13-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x1;b@74=0x80;b@77=0xff
save operation-14-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-14-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x1;b@74=0xFF;b@77=0xff
save operation-15-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-15-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x2;b@74=0x0;b@77=0xff
save operation-16-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-16-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x2;b@74=0x55;b@77=0xff
save operation-17-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-17-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x2;b@74=0x80;b@77=0xff
save operation-18-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-18-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x2;b@74=0xFF;b@77=0xff
save operation-19-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-19-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x2;b@74=0x0;b@77=0xff
save operation-20-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-20-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x2;b@74=0x55;b@77=0xff
save operation-21-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-21-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x2;b@74=0x80;b@77=0xff
save operation-22-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-22-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x2;b@74=0xFF;b@77=0xff
save operation-23-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-23-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x8;b@74=0x0;b@77=0xff
save operation-24-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-24-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x8;b@74=0x55;b@77=0xff
save operation-25-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-25-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x8;b@74=0x80;b@77=0xff
save operation-26-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-26-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x8;b@74=0xFF;b@77=0xff
save operation-27-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-27-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x8;b@74=0x0;b@77=0xff
save operation-28-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-28-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x8;b@74=0x55;b@77=0xff
save operation-29-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-29-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x8;b@74=0x80;b@77=0xff
save operation-30-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-30-after.bin,0,800
pc=0x6AA3;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x8;b@74=0xFF;b@77=0xff
save operation-31-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-31-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x0;b@74=0x0;b@77=0xff
save operation-32-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-32-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x0;b@74=0x55;b@77=0xff
save operation-33-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-33-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x0;b@74=0x80;b@77=0xff
save operation-34-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-34-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x0;b@74=0xFF;b@77=0xff
save operation-35-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-35-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x0;b@74=0x0;b@77=0xff
save operation-36-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-36-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x0;b@74=0x55;b@77=0xff
save operation-37-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-37-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x0;b@74=0x80;b@77=0xff
save operation-38-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-38-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x0;b@74=0xFF;b@77=0xff
save operation-39-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-39-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x1;b@74=0x0;b@77=0xff
save operation-40-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-40-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x1;b@74=0x55;b@77=0xff
save operation-41-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-41-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x1;b@74=0x80;b@77=0xff
save operation-42-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-42-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x1;b@74=0xFF;b@77=0xff
save operation-43-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-43-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x1;b@74=0x0;b@77=0xff
save operation-44-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-44-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x1;b@74=0x55;b@77=0xff
save operation-45-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-45-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x1;b@74=0x80;b@77=0xff
save operation-46-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-46-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x1;b@74=0xFF;b@77=0xff
save operation-47-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-47-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x2;b@74=0x0;b@77=0xff
save operation-48-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-48-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x2;b@74=0x55;b@77=0xff
save operation-49-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-49-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x2;b@74=0x80;b@77=0xff
save operation-50-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-50-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x2;b@74=0xFF;b@77=0xff
save operation-51-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-51-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x2;b@74=0x0;b@77=0xff
save operation-52-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-52-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x2;b@74=0x55;b@77=0xff
save operation-53-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-53-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x2;b@74=0x80;b@77=0xff
save operation-54-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-54-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x2;b@74=0xFF;b@77=0xff
save operation-55-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-55-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x8;b@74=0x0;b@77=0xff
save operation-56-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-56-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x8;b@74=0x55;b@77=0xff
save operation-57-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-57-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x8;b@74=0x80;b@77=0xff
save operation-58-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-58-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x0;w@38b=0x599;b@75=0x8;b@74=0xFF;b@77=0xff
save operation-59-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-59-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x8;b@74=0x0;b@77=0xff
save operation-60-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-60-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x8;b@74=0x55;b@77=0xff
save operation-61-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-61-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x8;b@74=0x80;b@77=0xff
save operation-62-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-62-after.bin,0,800
pc=0x6AB6;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=4;b@b02=0x80;w@38b=0x599;b@75=0x8;b@74=0xFF;b@77=0xff
save operation-63-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-63-after.bin,0,800
quit

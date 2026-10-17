bpset 4c34
bpset 70d6
bpset 70c9
bpset 6A81,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A84,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A86,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A89,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A8C,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A8E,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A91,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A94,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A96,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A99,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6A9C,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6AA0,1,{printf "OI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
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
pc=0x6a81;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=0x4;b@b02=0x0;w@38b=0x0;w@81=0
save operation-0-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-0-after.bin,0,800
pc=0x6a81;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=0x4;b@b02=0x80;w@38b=0x0;w@81=0
save operation-1-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-1-after.bin,0,800
pc=0x6a81;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=0x34;b@b02=0x0;w@38b=0x0;w@81=0
save operation-2-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-2-after.bin,0,800
pc=0x6a81;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=0x34;b@b02=0x80;w@38b=0x0;w@81=0
save operation-3-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-3-after.bin,0,800
pc=0x6a81;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=0x4;b@b02=0x0;w@38b=0x1;w@81=0
save operation-4-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-4-after.bin,0,800
pc=0x6a81;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=0x4;b@b02=0x80;w@38b=0x1;w@81=0
save operation-5-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-5-after.bin,0,800
pc=0x6a81;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=0x34;b@b02=0x0;w@38b=0x1;w@81=0
save operation-6-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-6-after.bin,0,800
pc=0x6a81;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=0x34;b@b02=0x80;w@38b=0x1;w@81=0
save operation-7-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-7-after.bin,0,800
pc=0x6a81;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=0x4;b@b02=0x0;w@38b=0x599;w@81=0
save operation-8-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-8-after.bin,0,800
pc=0x6a81;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=0x4;b@b02=0x80;w@38b=0x599;w@81=0
save operation-9-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-9-after.bin,0,800
pc=0x6a81;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=0x34;b@b02=0x0;w@38b=0x599;w@81=0
save operation-10-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-10-after.bin,0,800
pc=0x6a81;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=0x34;b@b02=0x80;w@38b=0x599;w@81=0
save operation-11-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-11-after.bin,0,800
pc=0x6a81;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=0x4;b@b02=0x0;w@38b=0xFFFF;w@81=0
save operation-12-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-12-after.bin,0,800
pc=0x6a81;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=0x4;b@b02=0x80;w@38b=0xFFFF;w@81=0
save operation-13-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-13-after.bin,0,800
pc=0x6a81;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=0x34;b@b02=0x0;w@38b=0xFFFF;w@81=0
save operation-14-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-14-after.bin,0,800
pc=0x6a81;a=0x89;b=0xab;x=0x1234;y=0x4567;u=0x600;s=0x700;dp=0;cc=0x50;w@700=0x4c34;b@b03=0;b@b02=0x80;b@b03=0x34;b@b02=0x80;w@38b=0xFFFF;w@81=0
save operation-15-before.bin,0,800
printf "OS pc=%04X cycle=%016X io=%02X rx=%02X\n",pc,totalcycles,b@b03,b@b02
go
printf "OF pc=%04X cycle=%016X s=%04X\n",pc,totalcycles,s
save operation-15-after.bin,0,800
quit

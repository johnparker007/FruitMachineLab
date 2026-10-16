cc=0x50
wpset 0x900,8,w,(temp1==1 && wpaddr==0x900 && pc==0x719) || (temp1==3 && ((temp4==1 && wpaddr==0x907 && pc==0x723) || (temp4==0 && wpaddr==0x900 && pc==0x728))),{printf "PL channel=%X latch=%04X delay=%04X phase=%X cycle=%016X\n",temp1,temp2,temp3,temp4,totalcycles;go}
wpset 0x901,1,r,1,{printf "PR cycle=%016X value=%02X\n",totalcycles,wpdata;go}
load case-1-0-0-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=0;temp3=0;temp4=0
bpset 71d
go
printf "PS channel=1 latch=0000 delay=0000 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-0-4-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=0;temp3=4;temp4=0
bpset 721
go
printf "PS channel=1 latch=0000 delay=0004 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-0-8-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=0;temp3=8;temp4=0
bpset 725
go
printf "PS channel=1 latch=0000 delay=0008 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-0-12-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=0;temp3=C;temp4=0
bpset 729
go
printf "PS channel=1 latch=0000 delay=000C phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-1-0-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=1;temp3=0;temp4=0
bpset 71d
go
printf "PS channel=1 latch=0001 delay=0000 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-1-4-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=1;temp3=4;temp4=0
bpset 721
go
printf "PS channel=1 latch=0001 delay=0004 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-1-8-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=1;temp3=8;temp4=0
bpset 725
go
printf "PS channel=1 latch=0001 delay=0008 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-1-12-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=1;temp3=C;temp4=0
bpset 729
go
printf "PS channel=1 latch=0001 delay=000C phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-30-0-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=1E;temp3=0;temp4=0
bpset 725
go
printf "PS channel=1 latch=001E delay=0000 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-30-4-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=1E;temp3=4;temp4=0
bpset 729
go
printf "PS channel=1 latch=001E delay=0004 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-30-8-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=1E;temp3=8;temp4=0
bpset 72d
go
printf "PS channel=1 latch=001E delay=0008 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-30-12-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=1E;temp3=C;temp4=0
bpset 731
go
printf "PS channel=1 latch=001E delay=000C phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-40-0-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=28;temp3=0;temp4=0
bpset 725
go
printf "PS channel=1 latch=0028 delay=0000 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-40-4-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=28;temp3=4;temp4=0
bpset 729
go
printf "PS channel=1 latch=0028 delay=0004 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-40-8-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=28;temp3=8;temp4=0
bpset 72d
go
printf "PS channel=1 latch=0028 delay=0008 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-40-12-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=28;temp3=C;temp4=0
bpset 731
go
printf "PS channel=1 latch=0028 delay=000C phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-41-0-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=29;temp3=0;temp4=0
bpset 725
go
printf "PS channel=1 latch=0029 delay=0000 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-41-4-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=29;temp3=4;temp4=0
bpset 729
go
printf "PS channel=1 latch=0029 delay=0004 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-41-8-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=29;temp3=8;temp4=0
bpset 72d
go
printf "PS channel=1 latch=0029 delay=0008 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-41-12-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=29;temp3=C;temp4=0
bpset 731
go
printf "PS channel=1 latch=0029 delay=000C phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-255-0-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=FF;temp3=0;temp4=0
bpset 725
go
printf "PS channel=1 latch=00FF delay=0000 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-255-4-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=FF;temp3=4;temp4=0
bpset 729
go
printf "PS channel=1 latch=00FF delay=0004 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-255-8-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=FF;temp3=8;temp4=0
bpset 72d
go
printf "PS channel=1 latch=00FF delay=0008 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-255-12-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=FF;temp3=C;temp4=0
bpset 731
go
printf "PS channel=1 latch=00FF delay=000C phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-3440-0-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=D70;temp3=0;temp4=0
bpset 725
go
printf "PS channel=1 latch=0D70 delay=0000 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-3440-4-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=D70;temp3=4;temp4=0
bpset 729
go
printf "PS channel=1 latch=0D70 delay=0004 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-3440-8-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=D70;temp3=8;temp4=0
bpset 72d
go
printf "PS channel=1 latch=0D70 delay=0008 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-3440-12-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=D70;temp3=C;temp4=0
bpset 731
go
printf "PS channel=1 latch=0D70 delay=000C phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-65535-0-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=FFFF;temp3=0;temp4=0
bpset 725
go
printf "PS channel=1 latch=FFFF delay=0000 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-65535-4-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=FFFF;temp3=4;temp4=0
bpset 729
go
printf "PS channel=1 latch=FFFF delay=0004 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-65535-8-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=FFFF;temp3=8;temp4=0
bpset 72d
go
printf "PS channel=1 latch=FFFF delay=0008 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-1-65535-12-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=1;temp2=FFFF;temp3=C;temp4=0
bpset 731
go
printf "PS channel=1 latch=FFFF delay=000C phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-0-0-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=0;temp3=0;temp4=0
bpset 72c
go
printf "PS channel=3 latch=0000 delay=0000 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-0-4-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=0;temp3=4;temp4=0
bpset 730
go
printf "PS channel=3 latch=0000 delay=0004 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-0-8-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=0;temp3=8;temp4=0
bpset 734
go
printf "PS channel=3 latch=0000 delay=0008 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-0-12-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=0;temp3=C;temp4=0
bpset 738
go
printf "PS channel=3 latch=0000 delay=000C phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-1-0-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=1;temp3=0;temp4=0
bpset 72c
go
printf "PS channel=3 latch=0001 delay=0000 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-1-4-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=1;temp3=4;temp4=0
bpset 730
go
printf "PS channel=3 latch=0001 delay=0004 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-1-8-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=1;temp3=8;temp4=0
bpset 734
go
printf "PS channel=3 latch=0001 delay=0008 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-1-12-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=1;temp3=C;temp4=0
bpset 738
go
printf "PS channel=3 latch=0001 delay=000C phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-30-0-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=1E;temp3=0;temp4=0
bpset 734
go
printf "PS channel=3 latch=001E delay=0000 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-30-4-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=1E;temp3=4;temp4=0
bpset 738
go
printf "PS channel=3 latch=001E delay=0004 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-30-8-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=1E;temp3=8;temp4=0
bpset 73c
go
printf "PS channel=3 latch=001E delay=0008 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-30-12-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=1E;temp3=C;temp4=0
bpset 740
go
printf "PS channel=3 latch=001E delay=000C phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-40-0-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=28;temp3=0;temp4=0
bpset 734
go
printf "PS channel=3 latch=0028 delay=0000 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-40-4-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=28;temp3=4;temp4=0
bpset 738
go
printf "PS channel=3 latch=0028 delay=0004 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-40-8-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=28;temp3=8;temp4=0
bpset 73c
go
printf "PS channel=3 latch=0028 delay=0008 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-40-12-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=28;temp3=C;temp4=0
bpset 740
go
printf "PS channel=3 latch=0028 delay=000C phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-41-0-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=29;temp3=0;temp4=0
bpset 734
go
printf "PS channel=3 latch=0029 delay=0000 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-41-4-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=29;temp3=4;temp4=0
bpset 738
go
printf "PS channel=3 latch=0029 delay=0004 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-41-8-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=29;temp3=8;temp4=0
bpset 73c
go
printf "PS channel=3 latch=0029 delay=0008 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-41-12-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=29;temp3=C;temp4=0
bpset 740
go
printf "PS channel=3 latch=0029 delay=000C phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-255-0-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=FF;temp3=0;temp4=0
bpset 734
go
printf "PS channel=3 latch=00FF delay=0000 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-255-4-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=FF;temp3=4;temp4=0
bpset 738
go
printf "PS channel=3 latch=00FF delay=0004 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-255-8-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=FF;temp3=8;temp4=0
bpset 73c
go
printf "PS channel=3 latch=00FF delay=0008 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-255-12-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=FF;temp3=C;temp4=0
bpset 740
go
printf "PS channel=3 latch=00FF delay=000C phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-3440-0-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=D70;temp3=0;temp4=0
bpset 734
go
printf "PS channel=3 latch=0D70 delay=0000 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-3440-4-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=D70;temp3=4;temp4=0
bpset 738
go
printf "PS channel=3 latch=0D70 delay=0004 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-3440-8-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=D70;temp3=8;temp4=0
bpset 73c
go
printf "PS channel=3 latch=0D70 delay=0008 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-3440-12-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=D70;temp3=C;temp4=0
bpset 740
go
printf "PS channel=3 latch=0D70 delay=000C phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-65535-0-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=FFFF;temp3=0;temp4=0
bpset 73c
go
printf "PS channel=3 latch=FFFF delay=0000 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-65535-4-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=FFFF;temp3=4;temp4=0
bpset 740
go
printf "PS channel=3 latch=FFFF delay=0004 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-65535-8-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=FFFF;temp3=8;temp4=0
bpset 744
go
printf "PS channel=3 latch=FFFF delay=0008 phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-65535-12-0.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=FFFF;temp3=C;temp4=0
bpset 748
go
printf "PS channel=3 latch=FFFF delay=000C phase=0 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-0-0-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=0;temp3=0;temp4=1
bpset 727
go
printf "PS channel=3 latch=0000 delay=0000 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-0-4-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=0;temp3=4;temp4=1
bpset 72b
go
printf "PS channel=3 latch=0000 delay=0004 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-0-8-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=0;temp3=8;temp4=1
bpset 72f
go
printf "PS channel=3 latch=0000 delay=0008 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-0-12-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=0;temp3=C;temp4=1
bpset 733
go
printf "PS channel=3 latch=0000 delay=000C phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-1-0-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=1;temp3=0;temp4=1
bpset 727
go
printf "PS channel=3 latch=0001 delay=0000 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-1-4-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=1;temp3=4;temp4=1
bpset 72b
go
printf "PS channel=3 latch=0001 delay=0004 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-1-8-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=1;temp3=8;temp4=1
bpset 72f
go
printf "PS channel=3 latch=0001 delay=0008 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-1-12-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=1;temp3=C;temp4=1
bpset 733
go
printf "PS channel=3 latch=0001 delay=000C phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-30-0-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=1E;temp3=0;temp4=1
bpset 72f
go
printf "PS channel=3 latch=001E delay=0000 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-30-4-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=1E;temp3=4;temp4=1
bpset 733
go
printf "PS channel=3 latch=001E delay=0004 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-30-8-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=1E;temp3=8;temp4=1
bpset 737
go
printf "PS channel=3 latch=001E delay=0008 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-30-12-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=1E;temp3=C;temp4=1
bpset 73b
go
printf "PS channel=3 latch=001E delay=000C phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-40-0-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=28;temp3=0;temp4=1
bpset 72f
go
printf "PS channel=3 latch=0028 delay=0000 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-40-4-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=28;temp3=4;temp4=1
bpset 733
go
printf "PS channel=3 latch=0028 delay=0004 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-40-8-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=28;temp3=8;temp4=1
bpset 737
go
printf "PS channel=3 latch=0028 delay=0008 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-40-12-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=28;temp3=C;temp4=1
bpset 73b
go
printf "PS channel=3 latch=0028 delay=000C phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-41-0-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=29;temp3=0;temp4=1
bpset 72f
go
printf "PS channel=3 latch=0029 delay=0000 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-41-4-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=29;temp3=4;temp4=1
bpset 733
go
printf "PS channel=3 latch=0029 delay=0004 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-41-8-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=29;temp3=8;temp4=1
bpset 737
go
printf "PS channel=3 latch=0029 delay=0008 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-41-12-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=29;temp3=C;temp4=1
bpset 73b
go
printf "PS channel=3 latch=0029 delay=000C phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-255-0-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=FF;temp3=0;temp4=1
bpset 72f
go
printf "PS channel=3 latch=00FF delay=0000 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-255-4-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=FF;temp3=4;temp4=1
bpset 733
go
printf "PS channel=3 latch=00FF delay=0004 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-255-8-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=FF;temp3=8;temp4=1
bpset 737
go
printf "PS channel=3 latch=00FF delay=0008 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-255-12-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=FF;temp3=C;temp4=1
bpset 73b
go
printf "PS channel=3 latch=00FF delay=000C phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-3440-0-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=D70;temp3=0;temp4=1
bpset 72f
go
printf "PS channel=3 latch=0D70 delay=0000 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-3440-4-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=D70;temp3=4;temp4=1
bpset 733
go
printf "PS channel=3 latch=0D70 delay=0004 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-3440-8-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=D70;temp3=8;temp4=1
bpset 737
go
printf "PS channel=3 latch=0D70 delay=0008 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-3440-12-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=D70;temp3=C;temp4=1
bpset 73b
go
printf "PS channel=3 latch=0D70 delay=000C phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-65535-0-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=FFFF;temp3=0;temp4=1
bpset 737
go
printf "PS channel=3 latch=FFFF delay=0000 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-65535-4-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=FFFF;temp3=4;temp4=1
bpset 73b
go
printf "PS channel=3 latch=FFFF delay=0004 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-65535-8-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=FFFF;temp3=8;temp4=1
bpset 73f
go
printf "PS channel=3 latch=FFFF delay=0008 phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
load case-3-65535-12-1.bin,700;pc=0x700;cc=0x50;temp0=totalcycles;temp1=3;temp2=FFFF;temp3=C;temp4=1
bpset 743
go
printf "PS channel=3 latch=FFFF delay=000C phase=1 start=%016X cycle=%016X status=%02X\n",temp0,totalcycles,a
bpclear
quit

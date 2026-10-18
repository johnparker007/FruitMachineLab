printf "ROM_PATCH_TABLE value=%02X\n",b@75be
bpset fc,y==0xc708
w@f8=w@7927;w@fa=w@7929;w@fc=w@792b;w@fe=w@792d
pc=0xfc;y=0xc6fe;u=0x600;s=0x700;dp=0;cc=0x50;w@f4=0x500;b@501=1
go
printf "ROM_PATCH_LOOKUP y=%04X top=%04X\n",y,w@u
quit

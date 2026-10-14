bpset 0xfc,y>=0xb000 && y<0xe450,{printf "FEATURE_VM y=%04X token=%04X u=%04X top=%04X s=%04X tick=%04X\n",y,w@y,u,w@u,s,w@0x2d;go}
gtime #2400000
save ram-final.bin,0,800
quit

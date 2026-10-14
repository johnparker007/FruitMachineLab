bpset 0xfc,y==0xc721 || temp0==1,{temp0=(y!=0xc767);printf "SC y=%04X token=%04X u=%04X top=%04X second=%04X third=%04X fourth=%04X s=%04X f4=%04X f6=%04X frame=%04X tick=%04X irq=%02X seed=%04X choice=%02X rate=%02X latch=%04X opt=%04X abort=%04X pending=%04X win=%04X guard=%02X checksum=%02X mode=%02X display=%04X suppress=%04X\n",y,w@y,u,w@u,w@(u+2),w@(u+4),w@(u+6),s,w@0xf4,w@0xf6,w@(w@0xf4),w@0x2d,b@0x33,w@0x324,b@0x4f,b@0x4e,w@0x90,w@0x719f,w@0x719b,w@0xba,w@0x2fa,b@0x2c,b@0x322,b@0x323,w@0x327,w@0xa0;go}
wpset 0x907,1,w,temp0==1,{printf "TL cycle=%016X pc=%04X value=%02X timer=%04X control=%02X\n",totalcycles,pc,wpdata,y,b@0x40;go}
bpset 0xfe70,temp0==1,{printf "TI cycle=%016X cc=%02X\n",totalcycles,cc;go}
bpset 0x48fd,temp0==1,{printf "TC cycle=%016X column=%04X\n",totalcycles,w@0x28;go}
gtime #2400000
save ram-final.bin,0,800
quit

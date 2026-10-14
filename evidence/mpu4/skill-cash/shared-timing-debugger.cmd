bpset 0xfc,y==0xc721 || temp0==1,{temp0=(y!=0xc767);printf "SC y=%04X token=%04X u=%04X top=%04X second=%04X third=%04X fourth=%04X s=%04X f4=%04X f6=%04X frame=%04X tick=%04X irq=%02X seed=%04X choice=%02X rate=%02X latch=%04X opt=%04X abort=%04X pending=%04X win=%04X cycle=%016X guard=%02X checksum=%02X mode=%02X display=%04X suppress=%04X\n",y,w@y,u,w@u,w@(u+2),w@(u+4),w@(u+6),s,w@0xf4,w@0xf6,w@(w@0xf4),w@0x2d,b@0x33,w@0x324,b@0x4f,b@0x4e,w@0x90,w@0x719f,w@0x719b,w@0xba,w@0x2fa,totalcycles,b@0x2c,b@0x322,b@0x323,w@0x327,w@0xa0;go}
bpset 0x49c5,temp0==1,{printf "ML cycle=%016X id=%02X pattern=%02X\n",totalcycles,a,b;go}
wpset 0x100,0x40,w,temp0==1,{printf "MW cycle=%016X address=%04X value=%02X\n",totalcycles,wpaddr,wpdata;go}
bpset 0x4a23,temp0==1,{printf "MF cycle=%016X\n",totalcycles;go}
bpset 0x28fe,temp0==1,{printf "MS cycle=%016X phase=%02X count=%02X reload=%02X alternate=%02X alternate_reload=%02X column=%04X suppress=%02X decimal=%02X sweep=%02X sample=%04X%04X%04X%04X digits=%04X%04X%04X%04X blink=%04X%04X%04X%04X ports=%02X%02X%02X%02X%02X%02X pulse=%04X%02X%04X masks=%04X%04X%04X%04X%04X%04X%04X%04X blank=%04X%04X%04X%04X\n",totalcycles,b@0x23,b@0x24,b@0x25,b@0x26,b@0x27,w@0x28,b@0x8d,b@0x22,b@0xb3,w@8,w@0xa,w@0xc,w@0xe,w@0x1a,w@0x1c,w@0x1e,w@0x20,w@0x2be,w@0x2c0,w@0x2c2,w@0x2c4,b@0xa00,b@0xa02,b@0xb00,b@0xe01,b@0xb01,b@0xf01,w@0xe8,b@0xea,w@0x32d,w@0x140,w@0x142,w@0x144,w@0x146,w@0x148,w@0x14a,w@0x14c,w@0x14e,w@0xab,w@0xad,w@0xaf,w@0xb1;go}
bpset 0x29ba,temp0==1,{printf "MX cycle=%016X phase=%02X count=%02X alternate=%02X column=%04X ports=%02X%02X%02X%02X%02X%02X\n",totalcycles,b@0x23,b@0x24,b@0x26,w@0x28,b@0xa00,b@0xa02,b@0xb00,b@0xe01,b@0xb01,b@0xf01;go}
bpset 0x70ef,temp0==1,{printf "MA cycle=%016X timer=%04X callback=%04X\n",totalcycles,y,x;go}
bpset 0x48fd,temp0==1,{printf "MC cycle=%016X column=%04X ports=%02X%02X%02X\n",totalcycles,w@0x28,b@0xa00,b@0xa02,b@0xb00;go}
bpset 0x4916,temp0==1,{printf "MD cycle=%016X column=%04X ports=%02X%02X%02X\n",totalcycles,w@0x28,b@0xa00,b@0xa02,b@0xb00;go}
gtime #2400000
save ram-final.bin,0,800
quit

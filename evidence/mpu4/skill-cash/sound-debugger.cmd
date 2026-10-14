bpset 0xfc,y==0xc721 || temp0==1,{temp0=(y!=0xc71d);printf "SC y=%04X token=%04X u=%04X top=%04X second=%04X third=%04X fourth=%04X s=%04X f4=%04X f6=%04X frame=%04X tick=%04X irq=%02X seed=%04X choice=%02X rate=%02X latch=%04X opt=%04X abort=%04X pending=%04X win=%04X clock=%04X\n",y,w@y,u,w@u,w@(u+2),w@(u+4),w@(u+6),s,w@0xf4,w@0xf6,w@(w@0xf4),w@0x2d,b@0x33,w@0x324,b@0x4f,b@0x4e,w@0x90,w@0x719f,w@0x719b,w@0xba,w@0x2fa,w@0x45;go}
bpset 0x5c18,temp0==1,{printf "SQ stream=%04X clock=%04X rate=%02X volume=%02X abort=%04X free=%04X\n",x,w@0x45,b@0x4e,b@0x50,w@0x719b,w@0x49;go}
bpset 0x5c46,temp0==1,{printf "QE stream=%04X clock=%04X task=%04X rate=%02X\n",w@(y+0x13),w@0x45,y,b@0x4e;go}
bpset 0x5d3b,temp0==1,{printf "SN cursor=%04X opcode=%02X task=%04X clock=%04X choice=%02X rate=%02X tempo=%02X gate=%02X flags=%02X pitch=%02X transpose=%02X\n",u,b@u,y,w@0x45,b@0x4f,b@0x4e,b@(y+0xe),b@(y+0x10),b@(y+0x12),b@(y+0xc),b@(y+0xd);go}
bpset 0x5cf3,temp0==1,{printf "SW duration=%02X cursor=%04X task=%04X clock=%04X callback=%04X rate=%02X tempo=%02X flags=%02X\n",b,u,y,w@0x45,w@s,b@0x4e,b@(y+0xe),b@(y+0x12);go}
wpset 0x4f,1,w,temp0==1,{printf "WC pc=%04X cursor=%04X task=%04X clock=%04X old=%02X value=%02X\n",pc,u,y,w@0x45,b@0x4f,wpdata;go}
bpset 0x5b77,temp0==1,{printf "SR clock=%04X choice=%02X rate=%02X\n",w@0x45,b@0x4f,b@0x4e;go}
gtime #2400000
save ram-final.bin,0,800
quit

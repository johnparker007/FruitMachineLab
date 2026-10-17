bpset 0x4c34
temp0=0
wpset 0xf02,1,w,temp0==1,{printf "PO id=%02X value=%02X\n",temp1,wpdata;go}
temp2=0
temp3=0
bpset 717c,temp0==1,{temp3=temp3+1;b@6e=(b@6e+(temp3&1))&0xff;go}
bpset 4cbe,temp0==1,{printf "PD id=%02X record=%04X balance=%04X\n",temp1,y,w@(w@(y+5));printf "CS id=%02X cycle=%016X y=%04X s=%04X cc=%02X\n",temp1,totalcycles,y,s,cc;temp2=1;go}
bpset fc,temp0==1&&temp2==1,{printf "CV id=%02X cycle=%016X y=%04X token=%04X\n",temp1,totalcycles,y,w@y;go}
bpset 4C23,temp0==1,{printf "CR id=%02X cycle=%016X pc=%04X\n",temp1,totalcycles,pc;temp2=0;printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C8A,temp0==1,{printf "CR id=%02X cycle=%016X pc=%04X\n",temp1,totalcycles,pc;temp2=0;printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D07,temp0==1,{printf "CR id=%02X cycle=%016X pc=%04X\n",temp1,totalcycles,pc;temp2=0;printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D4D,temp0==1,{printf "CR id=%02X cycle=%016X pc=%04X\n",temp1,totalcycles,pc;temp2=0;printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D42,temp0==1,{printf "CR id=%02X cycle=%016X pc=%04X\n",temp1,totalcycles,pc;temp2=0;printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset fc,temp0==1&&temp2==0&&y==0x112
bpset FE,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B39,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B3D,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B3F,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B43,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B46,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B4A,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B4D,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B4F,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B51,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B55,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B59,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B5C,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B5E,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B61,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B63,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B66,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B68,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B6B,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B6D,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B70,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B72,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B75,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B77,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B7A,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B7E,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B81,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B83,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B86,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B88,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B89,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B8C,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B90,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B93,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B97,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B9A,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B9C,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4B9F,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4BA1,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4BA4,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4BA6,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4BA9,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4BAB,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4BAE,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4BB0,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4BB3,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4BB5,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4BB8,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4BBC,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4BBF,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4BC2,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4BC4,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C19,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C1C,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C1E,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C20,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C25,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C26,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C28,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C2B,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C2D,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C7C,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C7E,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C7F,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C83,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C85,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C87,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C8C,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C8F,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C91,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C93,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C95,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C97,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C99,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C9C,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4C9E,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CA0,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CA2,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CA4,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CA5,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CA7,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CA9,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CAB,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CAD,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CAF,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CB1,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CB4,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CB7,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CB9,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CBB,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CBC,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CF8,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CFA,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CFD,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CFF,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D02,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D04,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D09,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D0C,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D0F,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D12,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D15,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D18,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D1A,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D1C,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D1E,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D21,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D24,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D27,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D29,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D2C,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D2E,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D30,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D32,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D34,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D36,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D38,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D3A,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D3D,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D3F,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D44,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D45,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D48,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D4A,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D51,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D53,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D56,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D59,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D5C,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D5F,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D62,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D64,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D66,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D68,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D6B,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D6E,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D71,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4D73,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 67E2,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 67E4,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 67E6,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 67E8,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 67EA,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 67EC,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 67EE,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 67F0,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 67F1,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 67F3,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 67F6,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 67F7,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 67F8,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 67F9,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 67FC,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 67FE,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6802,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6804,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6806,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6808,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 680C,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 680E,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6810,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6812,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6814,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6818,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 681A,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 681C,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 681E,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6820,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6822,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6824,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6826,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6828,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 682C,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 682E,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6830,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6832,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6834,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6836,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6838,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 683B,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 683C,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 683D,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6840,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6842,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6845,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6847,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6849,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 684C,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 684E,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6850,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6852,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6854,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6856,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6F51,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6F57,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6F5A,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6F5C,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6F5F,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6F60,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6F62,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6F64,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6F65,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6F67,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6F6B,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6F6D,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6F6F,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6F70,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6F73,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6F75,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6F78,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7009,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 700C,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 700D,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 700F,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7011,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7012,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7015,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7017,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7018,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7032,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7034,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7037,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7039,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 703B,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 703E,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7040,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7042,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7044,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7047,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 776F,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7771,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7773,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7775,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7777,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 777A,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 777C,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 777E,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7780,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7782,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7784,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7786,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7788,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 778B,temp0==1&&temp2==0,{printf "CI id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
temp0=0
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
w@0x790=0x4c34
b@0x323=0
w@0xa0=0
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x2fe=0
w@0x300=0
w@0x02FE=0x0002
b@0=0x00
b@1=0
b@2=0
b@3=0
b@6=0x00
b@7=0
b@0x3a=0x80
w@0x36b=0
w@0x36d=0
w@0x36f=0
w@0x371=0
w@0x7d2=0x8000
b@0x7d4=0
b@0xf03=0x30
b@0xf02=0xff
b@0xf03=0x34
b@0xf02=0x30
save service-0-before.bin,0,800
temp1=0x00
temp0=1
pc=0x4B39
pc=0xfc;y=0x110;w@110=0x80E4;w@112=0x80e8;b@f1=0x0;w@f8=0x3420;w@fa=0x3184;w@fc=0xaea1;w@fe=0x6e91
save service-0-before.bin,0,800
temp2=0;temp3=0
printf "CB id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
g
temp0=0
save service-0-after.bin,0,800
printf "PF id=%02X pc=%04X u=%04X\n",temp1,pc,u
printf "CE id=%02X pc=%04X cycle=%016X s=%04X polls=%04X\n",temp1,pc,totalcycles,s,temp3
temp0=0
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
w@0x790=0x4c34
b@0x323=0
w@0xa0=0
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x2fe=0
w@0x300=0
w@0x02FE=0x0018
b@0=0x00
b@1=0
b@2=0
b@3=0
b@6=0x00
b@7=0
b@0x3a=0x80
w@0x36b=0
w@0x36d=0
w@0x36f=0
w@0x371=0
w@0x7d2=0x8000
b@0x7d4=0
b@0xf03=0x30
b@0xf02=0xff
b@0xf03=0x34
b@0xf02=0x30
save service-1-before.bin,0,800
temp1=0x01
temp0=1
pc=0x4B39
pc=0xfc;y=0x110;w@110=0x80E4;w@112=0x80e8;b@f1=0x8;w@f8=0x3420;w@fa=0x3184;w@fc=0xaea1;w@fe=0x6e91
save service-1-before.bin,0,800
temp2=0;temp3=0
printf "CB id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
g
temp0=0
save service-1-after.bin,0,800
printf "PF id=%02X pc=%04X u=%04X\n",temp1,pc,u
printf "CE id=%02X pc=%04X cycle=%016X s=%04X polls=%04X\n",temp1,pc,totalcycles,s,temp3
temp0=0
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
w@0x790=0x4c34
b@0x323=0
w@0xa0=0
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x2fe=0
w@0x300=0
w@0x02FE=0x0002
b@0=0x0F
b@1=0
b@2=0
b@3=0
b@6=0x00
b@7=0
b@0x3a=0x80
w@0x36b=0
w@0x36d=0
w@0x36f=0
w@0x371=0
w@0x7d2=0x8000
b@0x7d4=0
b@0xf03=0x30
b@0xf02=0xff
b@0xf03=0x34
b@0xf02=0x30
save service-2-before.bin,0,800
temp1=0x02
temp0=1
pc=0x4B39
pc=0xfc;y=0x110;w@110=0x80E4;w@112=0x80e8;b@f1=0x0;w@f8=0x3420;w@fa=0x3184;w@fc=0xaea1;w@fe=0x6e91
save service-2-before.bin,0,800
temp2=0;temp3=0
printf "CB id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
g
temp0=0
save service-2-after.bin,0,800
printf "PF id=%02X pc=%04X u=%04X\n",temp1,pc,u
printf "CE id=%02X pc=%04X cycle=%016X s=%04X polls=%04X\n",temp1,pc,totalcycles,s,temp3
temp0=0
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
w@0x790=0x4c34
b@0x323=0
w@0xa0=0
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x2fe=0
w@0x300=0
w@0x02FE=0x0018
b@0=0x0F
b@1=0
b@2=0
b@3=0
b@6=0x00
b@7=0
b@0x3a=0x80
w@0x36b=0
w@0x36d=0
w@0x36f=0
w@0x371=0
w@0x7d2=0x8000
b@0x7d4=0
b@0xf03=0x30
b@0xf02=0xff
b@0xf03=0x34
b@0xf02=0x30
save service-3-before.bin,0,800
temp1=0x03
temp0=1
pc=0x4B39
pc=0xfc;y=0x110;w@110=0x80E4;w@112=0x80e8;b@f1=0x8;w@f8=0x3420;w@fa=0x3184;w@fc=0xaea1;w@fe=0x6e91
save service-3-before.bin,0,800
temp2=0;temp3=0
printf "CB id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
g
temp0=0
save service-3-after.bin,0,800
printf "PF id=%02X pc=%04X u=%04X\n",temp1,pc,u
printf "CE id=%02X pc=%04X cycle=%016X s=%04X polls=%04X\n",temp1,pc,totalcycles,s,temp3
temp0=0
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
w@0x790=0x4c34
b@0x323=0
w@0xa0=0
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x2fe=0
w@0x300=0
w@0x02FE=0x0002
b@0=0x00
b@1=0
b@2=0
b@3=0
b@6=0x04
b@7=0
b@0x3a=0x80
w@0x36b=0
w@0x36d=0
w@0x36f=0
w@0x371=0
w@0x7d2=0x8000
b@0x7d4=0
b@0xf03=0x30
b@0xf02=0xff
b@0xf03=0x34
b@0xf02=0x30
save service-4-before.bin,0,800
temp1=0x04
temp0=1
pc=0x4B39
pc=0xfc;y=0x110;w@110=0x80E4;w@112=0x80e8;b@f1=0x0;w@f8=0x3420;w@fa=0x3184;w@fc=0xaea1;w@fe=0x6e91
save service-4-before.bin,0,800
temp2=0;temp3=0
printf "CB id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
g
temp0=0
save service-4-after.bin,0,800
printf "PF id=%02X pc=%04X u=%04X\n",temp1,pc,u
printf "CE id=%02X pc=%04X cycle=%016X s=%04X polls=%04X\n",temp1,pc,totalcycles,s,temp3
temp0=0
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
w@0x790=0x4c34
b@0x323=0
w@0xa0=0
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x2fe=0
w@0x300=0
w@0x02FE=0x0018
b@0=0x00
b@1=0
b@2=0
b@3=0
b@6=0x04
b@7=0
b@0x3a=0x80
w@0x36b=0
w@0x36d=0
w@0x36f=0
w@0x371=0
w@0x7d2=0x8000
b@0x7d4=0
b@0xf03=0x30
b@0xf02=0xff
b@0xf03=0x34
b@0xf02=0x30
save service-5-before.bin,0,800
temp1=0x05
temp0=1
pc=0x4B39
pc=0xfc;y=0x110;w@110=0x80E4;w@112=0x80e8;b@f1=0x8;w@f8=0x3420;w@fa=0x3184;w@fc=0xaea1;w@fe=0x6e91
save service-5-before.bin,0,800
temp2=0;temp3=0
printf "CB id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
g
temp0=0
save service-5-after.bin,0,800
printf "PF id=%02X pc=%04X u=%04X\n",temp1,pc,u
printf "CE id=%02X pc=%04X cycle=%016X s=%04X polls=%04X\n",temp1,pc,totalcycles,s,temp3
temp0=0
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
w@0x790=0x4c34
b@0x323=0
w@0xa0=0
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x2fe=0
w@0x300=0
w@0x02FE=0x0002
b@0=0x0F
b@1=0
b@2=0
b@3=0
b@6=0x04
b@7=0
b@0x3a=0x80
w@0x36b=0
w@0x36d=0
w@0x36f=0
w@0x371=0
w@0x7d2=0x8000
b@0x7d4=0
b@0xf03=0x30
b@0xf02=0xff
b@0xf03=0x34
b@0xf02=0x30
save service-6-before.bin,0,800
temp1=0x06
temp0=1
pc=0x4B39
pc=0xfc;y=0x110;w@110=0x80E4;w@112=0x80e8;b@f1=0x0;w@f8=0x3420;w@fa=0x3184;w@fc=0xaea1;w@fe=0x6e91
save service-6-before.bin,0,800
temp2=0;temp3=0
printf "CB id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
g
temp0=0
save service-6-after.bin,0,800
printf "PF id=%02X pc=%04X u=%04X\n",temp1,pc,u
printf "CE id=%02X pc=%04X cycle=%016X s=%04X polls=%04X\n",temp1,pc,totalcycles,s,temp3
temp0=0
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
w@0x790=0x4c34
b@0x323=0
w@0xa0=0
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x2fe=0
w@0x300=0
w@0x02FE=0x0018
b@0=0x0F
b@1=0
b@2=0
b@3=0
b@6=0x04
b@7=0
b@0x3a=0x80
w@0x36b=0
w@0x36d=0
w@0x36f=0
w@0x371=0
w@0x7d2=0x8000
b@0x7d4=0
b@0xf03=0x30
b@0xf02=0xff
b@0xf03=0x34
b@0xf02=0x30
save service-7-before.bin,0,800
temp1=0x07
temp0=1
pc=0x4B39
pc=0xfc;y=0x110;w@110=0x80E4;w@112=0x80e8;b@f1=0x8;w@f8=0x3420;w@fa=0x3184;w@fc=0xaea1;w@fe=0x6e91
save service-7-before.bin,0,800
temp2=0;temp3=0
printf "CB id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
g
temp0=0
save service-7-after.bin,0,800
printf "PF id=%02X pc=%04X u=%04X\n",temp1,pc,u
printf "CE id=%02X pc=%04X cycle=%016X s=%04X polls=%04X\n",temp1,pc,totalcycles,s,temp3
temp0=0
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
w@0x790=0x4c34
b@0x323=0
w@0xa0=0
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x2fe=0
w@0x300=0
w@0x0300=0x0002
b@0=0x00
b@1=0
b@2=0
b@3=0
b@6=0x00
b@7=0
b@0x3a=0x80
w@0x36b=0
w@0x36d=0
w@0x36f=0
w@0x371=0
w@0x7d2=0x8000
b@0x7d4=0
b@0xf03=0x30
b@0xf02=0xff
b@0xf03=0x34
b@0xf02=0x30
save service-8-before.bin,0,800
temp1=0x08
temp0=1
pc=0x4B8C
pc=0xfc;y=0x110;w@110=0x80F4;w@112=0x80e8;b@f1=0x0;w@f8=0x3420;w@fa=0x3184;w@fc=0xaea1;w@fe=0x6e91
save service-8-before.bin,0,800
temp2=0;temp3=0
printf "CB id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
g
temp0=0
save service-8-after.bin,0,800
printf "PF id=%02X pc=%04X u=%04X\n",temp1,pc,u
printf "CE id=%02X pc=%04X cycle=%016X s=%04X polls=%04X\n",temp1,pc,totalcycles,s,temp3
temp0=0
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
w@0x790=0x4c34
b@0x323=0
w@0xa0=0
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x2fe=0
w@0x300=0
w@0x0300=0x0006
b@0=0x00
b@1=0
b@2=0
b@3=0
b@6=0x00
b@7=0
b@0x3a=0x80
w@0x36b=0
w@0x36d=0
w@0x36f=0
w@0x371=0
w@0x7d2=0x8000
b@0x7d4=0
b@0xf03=0x30
b@0xf02=0xff
b@0xf03=0x34
b@0xf02=0x30
save service-9-before.bin,0,800
temp1=0x09
temp0=1
pc=0x4B8C
pc=0xfc;y=0x110;w@110=0x80F4;w@112=0x80e8;b@f1=0x8;w@f8=0x3420;w@fa=0x3184;w@fc=0xaea1;w@fe=0x6e91
save service-9-before.bin,0,800
temp2=0;temp3=0
printf "CB id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
g
temp0=0
save service-9-after.bin,0,800
printf "PF id=%02X pc=%04X u=%04X\n",temp1,pc,u
printf "CE id=%02X pc=%04X cycle=%016X s=%04X polls=%04X\n",temp1,pc,totalcycles,s,temp3
temp0=0
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
w@0x790=0x4c34
b@0x323=0
w@0xa0=0
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x2fe=0
w@0x300=0
w@0x0300=0x0002
b@0=0x0F
b@1=0
b@2=0
b@3=0
b@6=0x00
b@7=0
b@0x3a=0x80
w@0x36b=0
w@0x36d=0
w@0x36f=0
w@0x371=0
w@0x7d2=0x8000
b@0x7d4=0
b@0xf03=0x30
b@0xf02=0xff
b@0xf03=0x34
b@0xf02=0x30
save service-10-before.bin,0,800
temp1=0x0A
temp0=1
pc=0x4B8C
pc=0xfc;y=0x110;w@110=0x80F4;w@112=0x80e8;b@f1=0x0;w@f8=0x3420;w@fa=0x3184;w@fc=0xaea1;w@fe=0x6e91
save service-10-before.bin,0,800
temp2=0;temp3=0
printf "CB id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
g
temp0=0
save service-10-after.bin,0,800
printf "PF id=%02X pc=%04X u=%04X\n",temp1,pc,u
printf "CE id=%02X pc=%04X cycle=%016X s=%04X polls=%04X\n",temp1,pc,totalcycles,s,temp3
temp0=0
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
w@0x790=0x4c34
b@0x323=0
w@0xa0=0
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x2fe=0
w@0x300=0
w@0x0300=0x0006
b@0=0x0F
b@1=0
b@2=0
b@3=0
b@6=0x00
b@7=0
b@0x3a=0x80
w@0x36b=0
w@0x36d=0
w@0x36f=0
w@0x371=0
w@0x7d2=0x8000
b@0x7d4=0
b@0xf03=0x30
b@0xf02=0xff
b@0xf03=0x34
b@0xf02=0x30
save service-11-before.bin,0,800
temp1=0x0B
temp0=1
pc=0x4B8C
pc=0xfc;y=0x110;w@110=0x80F4;w@112=0x80e8;b@f1=0x8;w@f8=0x3420;w@fa=0x3184;w@fc=0xaea1;w@fe=0x6e91
save service-11-before.bin,0,800
temp2=0;temp3=0
printf "CB id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
g
temp0=0
save service-11-after.bin,0,800
printf "PF id=%02X pc=%04X u=%04X\n",temp1,pc,u
printf "CE id=%02X pc=%04X cycle=%016X s=%04X polls=%04X\n",temp1,pc,totalcycles,s,temp3
temp0=0
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
w@0x790=0x4c34
b@0x323=0
w@0xa0=0
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x2fe=0
w@0x300=0
w@0x0300=0x0002
b@0=0x00
b@1=0
b@2=0
b@3=0
b@6=0x04
b@7=0
b@0x3a=0x80
w@0x36b=0
w@0x36d=0
w@0x36f=0
w@0x371=0
w@0x7d2=0x8000
b@0x7d4=0
b@0xf03=0x30
b@0xf02=0xff
b@0xf03=0x34
b@0xf02=0x30
save service-12-before.bin,0,800
temp1=0x0C
temp0=1
pc=0x4B8C
pc=0xfc;y=0x110;w@110=0x80F4;w@112=0x80e8;b@f1=0x0;w@f8=0x3420;w@fa=0x3184;w@fc=0xaea1;w@fe=0x6e91
save service-12-before.bin,0,800
temp2=0;temp3=0
printf "CB id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
g
temp0=0
save service-12-after.bin,0,800
printf "PF id=%02X pc=%04X u=%04X\n",temp1,pc,u
printf "CE id=%02X pc=%04X cycle=%016X s=%04X polls=%04X\n",temp1,pc,totalcycles,s,temp3
temp0=0
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
w@0x790=0x4c34
b@0x323=0
w@0xa0=0
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x2fe=0
w@0x300=0
w@0x0300=0x0006
b@0=0x00
b@1=0
b@2=0
b@3=0
b@6=0x04
b@7=0
b@0x3a=0x80
w@0x36b=0
w@0x36d=0
w@0x36f=0
w@0x371=0
w@0x7d2=0x8000
b@0x7d4=0
b@0xf03=0x30
b@0xf02=0xff
b@0xf03=0x34
b@0xf02=0x30
save service-13-before.bin,0,800
temp1=0x0D
temp0=1
pc=0x4B8C
pc=0xfc;y=0x110;w@110=0x80F4;w@112=0x80e8;b@f1=0x8;w@f8=0x3420;w@fa=0x3184;w@fc=0xaea1;w@fe=0x6e91
save service-13-before.bin,0,800
temp2=0;temp3=0
printf "CB id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
g
temp0=0
save service-13-after.bin,0,800
printf "PF id=%02X pc=%04X u=%04X\n",temp1,pc,u
printf "CE id=%02X pc=%04X cycle=%016X s=%04X polls=%04X\n",temp1,pc,totalcycles,s,temp3
temp0=0
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
w@0x790=0x4c34
b@0x323=0
w@0xa0=0
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x2fe=0
w@0x300=0
w@0x0300=0x0002
b@0=0x0F
b@1=0
b@2=0
b@3=0
b@6=0x04
b@7=0
b@0x3a=0x80
w@0x36b=0
w@0x36d=0
w@0x36f=0
w@0x371=0
w@0x7d2=0x8000
b@0x7d4=0
b@0xf03=0x30
b@0xf02=0xff
b@0xf03=0x34
b@0xf02=0x30
save service-14-before.bin,0,800
temp1=0x0E
temp0=1
pc=0x4B8C
pc=0xfc;y=0x110;w@110=0x80F4;w@112=0x80e8;b@f1=0x0;w@f8=0x3420;w@fa=0x3184;w@fc=0xaea1;w@fe=0x6e91
save service-14-before.bin,0,800
temp2=0;temp3=0
printf "CB id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
g
temp0=0
save service-14-after.bin,0,800
printf "PF id=%02X pc=%04X u=%04X\n",temp1,pc,u
printf "CE id=%02X pc=%04X cycle=%016X s=%04X polls=%04X\n",temp1,pc,totalcycles,s,temp3
temp0=0
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
w@0x790=0x4c34
b@0x323=0
w@0xa0=0
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x2fe=0
w@0x300=0
w@0x0300=0x0006
b@0=0x0F
b@1=0
b@2=0
b@3=0
b@6=0x04
b@7=0
b@0x3a=0x80
w@0x36b=0
w@0x36d=0
w@0x36f=0
w@0x371=0
w@0x7d2=0x8000
b@0x7d4=0
b@0xf03=0x30
b@0xf02=0xff
b@0xf03=0x34
b@0xf02=0x30
save service-15-before.bin,0,800
temp1=0x0F
temp0=1
pc=0x4B8C
pc=0xfc;y=0x110;w@110=0x80F4;w@112=0x80e8;b@f1=0x8;w@f8=0x3420;w@fa=0x3184;w@fc=0xaea1;w@fe=0x6e91
save service-15-before.bin,0,800
temp2=0;temp3=0
printf "CB id=%02X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
g
temp0=0
save service-15-after.bin,0,800
printf "PF id=%02X pc=%04X u=%04X\n",temp1,pc,u
printf "CE id=%02X pc=%04X cycle=%016X s=%04X polls=%04X\n",temp1,pc,totalcycles,s,temp3
quit

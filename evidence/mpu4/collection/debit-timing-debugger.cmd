temp0=0
bpset 76bf,temp0==1
bpset 4cd1,temp0==0
bpset 6858
bpset fc,temp0==0,{printf "DV y=%04X token=%04X cycle=%016X u=%04X top=%04X second=%04X s=%04X\n",y,w@y,totalcycles,u,w@u,w@(u+2),s;go}
bpset 76f6,temp0==0,{printf "DG cycle=%016X s=%04X u=%04X\n",totalcycles,s,u;go}
bpset 4CC1,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CC3,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CC5,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CC8,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CCB,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CCE,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CD3,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CD5,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CD7,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CDA,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CDC,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CDF,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CE1,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CE4,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CE6,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CE9,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CEB,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CED,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 4CF0,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 57A9,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 57AB,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 57AC,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 57AE,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 57B0,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 57B2,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 57B4,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 57B6,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 57F7,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 57FA,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 57FC,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 57FF,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 59A4,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 59A6,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 59A9,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 59AB,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 59AC,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 59AE,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 59B0,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 59B2,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 59B4,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 59B6,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 59B9,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68E0,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68E2,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68E4,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68E6,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68E8,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68EA,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68EC,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68EF,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E05,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E06,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E09,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E0D,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E0F,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E12,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E14,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E16,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E19,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E1C,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E1E,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E21,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E22,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E24,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E26,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E27,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E2B,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E2D,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E30,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E32,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E34,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E37,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E39,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E3B,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E3D,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E3E,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E42,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E44,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E47,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E49,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E4B,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E4D,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E50,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E52,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E54,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E57,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E5A,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E5C,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E5E,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E60,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E63,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E65,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6E68,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6FC1,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6FC4,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6FC5,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6FC7,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6FC9,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6FCA,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6FCD,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6FCF,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6FD0,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6FEC,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6FEE,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6FF1,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6FF3,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6FF5,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6FF8,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6FFA,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6FFC,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6FFE,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7000,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7002,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7004,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7007,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7009,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 700C,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 700D,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 700F,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7011,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7012,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7015,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7017,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7018,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7032,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7034,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7037,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7039,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 703B,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 703E,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7040,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7042,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7044,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7047,temp0==1,{printf "DI pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x00
w@0xa0=0x0000
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x02FE=0x0000
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-0-before.bin,0,800
y=0x4ACA
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-0-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-0-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-0-after.bin,0,800
printf "PAYOUT debit-0 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x00
w@0xa0=0x0000
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x02FE=0xFFFF
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-1-before.bin,0,800
y=0x4ACA
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-1-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-1-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-1-after.bin,0,800
printf "PAYOUT debit-1 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x00
w@0xa0=0x0001
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x02FE=0x0000
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-2-before.bin,0,800
y=0x4ACA
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-2-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-2-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-2-after.bin,0,800
printf "PAYOUT debit-2 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x00
w@0xa0=0x0001
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x02FE=0xFFFF
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-3-before.bin,0,800
y=0x4ACA
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-3-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-3-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-3-after.bin,0,800
printf "PAYOUT debit-3 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x80
w@0xa0=0x0000
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x02FE=0x0000
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-4-before.bin,0,800
y=0x4ACA
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-4-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-4-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-4-after.bin,0,800
printf "PAYOUT debit-4 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x80
w@0xa0=0x0000
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x02FE=0xFFFF
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-5-before.bin,0,800
y=0x4ACA
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-5-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-5-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-5-after.bin,0,800
printf "PAYOUT debit-5 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x80
w@0xa0=0x0001
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x02FE=0x0000
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-6-before.bin,0,800
y=0x4ACA
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-6-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-6-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-6-after.bin,0,800
printf "PAYOUT debit-6 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x80
w@0xa0=0x0001
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x02FE=0xFFFF
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-7-before.bin,0,800
y=0x4ACA
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-7-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-7-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-7-after.bin,0,800
printf "PAYOUT debit-7 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x00
w@0xa0=0x0000
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x02FE=0x0000
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-8-before.bin,0,800
y=0x4ADB
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-8-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-8-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-8-after.bin,0,800
printf "PAYOUT debit-8 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x00
w@0xa0=0x0000
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x02FE=0xFFFF
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-9-before.bin,0,800
y=0x4ADB
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-9-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-9-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-9-after.bin,0,800
printf "PAYOUT debit-9 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x00
w@0xa0=0x0001
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x02FE=0x0000
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-10-before.bin,0,800
y=0x4ADB
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-10-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-10-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-10-after.bin,0,800
printf "PAYOUT debit-10 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x00
w@0xa0=0x0001
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x02FE=0xFFFF
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-11-before.bin,0,800
y=0x4ADB
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-11-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-11-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-11-after.bin,0,800
printf "PAYOUT debit-11 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x80
w@0xa0=0x0000
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x02FE=0x0000
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-12-before.bin,0,800
y=0x4ADB
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-12-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-12-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-12-after.bin,0,800
printf "PAYOUT debit-12 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x80
w@0xa0=0x0000
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x02FE=0xFFFF
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-13-before.bin,0,800
y=0x4ADB
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-13-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-13-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-13-after.bin,0,800
printf "PAYOUT debit-13 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x80
w@0xa0=0x0001
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x02FE=0x0000
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-14-before.bin,0,800
y=0x4ADB
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-14-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-14-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-14-after.bin,0,800
printf "PAYOUT debit-14 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x80
w@0xa0=0x0001
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x02FE=0xFFFF
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-15-before.bin,0,800
y=0x4ADB
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-15-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-15-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-15-after.bin,0,800
printf "PAYOUT debit-15 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x00
w@0xa0=0x0000
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x0300=0x0000
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-16-before.bin,0,800
y=0x4AEC
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-16-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-16-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-16-after.bin,0,800
printf "PAYOUT debit-16 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x00
w@0xa0=0x0000
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x0300=0xFFFF
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-17-before.bin,0,800
y=0x4AEC
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-17-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-17-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-17-after.bin,0,800
printf "PAYOUT debit-17 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x00
w@0xa0=0x0001
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x0300=0x0000
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-18-before.bin,0,800
y=0x4AEC
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-18-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-18-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-18-after.bin,0,800
printf "PAYOUT debit-18 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x00
w@0xa0=0x0001
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x0300=0xFFFF
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-19-before.bin,0,800
y=0x4AEC
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-19-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-19-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-19-after.bin,0,800
printf "PAYOUT debit-19 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x80
w@0xa0=0x0000
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x0300=0x0000
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-20-before.bin,0,800
y=0x4AEC
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-20-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-20-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-20-after.bin,0,800
printf "PAYOUT debit-20 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x80
w@0xa0=0x0000
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x0300=0xFFFF
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-21-before.bin,0,800
y=0x4AEC
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-21-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-21-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-21-after.bin,0,800
printf "PAYOUT debit-21 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x80
w@0xa0=0x0001
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x0300=0x0000
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-22-before.bin,0,800
y=0x4AEC
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-22-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-22-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-22-after.bin,0,800
printf "PAYOUT debit-22 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x80
w@0xa0=0x0001
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x0300=0xFFFF
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-23-before.bin,0,800
y=0x4AEC
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-23-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-23-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-23-after.bin,0,800
printf "PAYOUT debit-23 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x00
w@0xa0=0x0000
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x0300=0x0000
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-24-before.bin,0,800
y=0x4AFD
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-24-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-24-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-24-after.bin,0,800
printf "PAYOUT debit-24 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x00
w@0xa0=0x0000
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x0300=0xFFFF
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-25-before.bin,0,800
y=0x4AFD
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-25-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-25-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-25-after.bin,0,800
printf "PAYOUT debit-25 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x00
w@0xa0=0x0001
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x0300=0x0000
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-26-before.bin,0,800
y=0x4AFD
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-26-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-26-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-26-after.bin,0,800
printf "PAYOUT debit-26 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x00
w@0xa0=0x0001
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x0300=0xFFFF
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-27-before.bin,0,800
y=0x4AFD
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-27-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-27-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-27-after.bin,0,800
printf "PAYOUT debit-27 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x80
w@0xa0=0x0000
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x0300=0x0000
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-28-before.bin,0,800
y=0x4AFD
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-28-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-28-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-28-after.bin,0,800
printf "PAYOUT debit-28 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x80
w@0xa0=0x0000
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x0300=0xFFFF
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-29-before.bin,0,800
y=0x4AFD
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-29-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-29-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-29-after.bin,0,800
printf "PAYOUT debit-29 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x80
w@0xa0=0x0001
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x0300=0x0000
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-30-before.bin,0,800
y=0x4AFD
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-30-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-30-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-30-after.bin,0,800
printf "PAYOUT debit-30 pc=%04X u=%04X y=%04X\n",pc,u,y
load seed.bin,0
s=0x790
u=0x600
dp=0
cc=0x50
b@0x323=0x80
w@0xa0=0x0001
b@0x55=0x1f
b@0x57=0
b@0x54=0
b@0xc5=0
w@0x0300=0xFFFF
b@0x3a=0x80
w@0x35e=0xfffe
w@0x360=0xfffe
w@0x362=0xfffe
w@0x364=0xfffe
w@0x366=0xfffe
w@0x368=0xfffe
w@0x36b=0xff01
w@0x36d=0xff02
w@0x36f=0xff03
w@0x371=0xff04
b@0x3e6=0xff
w@0x3e7=0xfffe
b@0x3ec=0xff
w@0x3ed=0xfffe
b@0x419=0xff
w@0x41a=0xfffe
b@0x41c=0xff
w@0x41d=0xfffe
b@0x41f=0xff
w@0x420=0xfffe
b@0x425=0xff
w@0x426=0xfffe
save debit-31-before.bin,0,800
y=0x4AFD
pc=0x4cbe
printf "DS pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x76bf
temp0=0
save debit-31-display-entry.bin,0,800
printf "DX pc=%04X cycle=%016X x=%04X u=%04X a=%02X b=%02X dp=%02X cc=%02X y=%04X s=%04X\n",pc,totalcycles,x,u,a,b,dp,cc,y,s
g 0x4cd1
save debit-31-display-return.bin,0,800
printf "DR pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
g 0x6858
temp0=0
printf "DF pc=%04X cycle=%016X u=%04X\n",pc,totalcycles,u
save debit-31-after.bin,0,800
printf "PAYOUT debit-31 pc=%04X u=%04X y=%04X\n",pc,u,y
quit

bpset 4c34
temp0=0
wpset f02,1,w,temp0==1,{printf "PW id=%X cycle=%016X value=%02X\n",temp1,totalcycles,wpdata;go}
bpset 511B,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 511D,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5120,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5122,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5124,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5128,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 512A,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 512B,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 512F,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5131,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5133,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5135,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5137,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5139,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 513B,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 513D,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 513F,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5141,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5143,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5145,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5147,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5149,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 514B,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 514D,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 514F,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5151,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5153,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5155,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5157,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5159,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 515B,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 515E,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5160,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5162,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5164,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5166,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5168,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 516A,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 516C,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 516E,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5170,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5173,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5176,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5178,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 517B,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 517D,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5180,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5181,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5183,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5186,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5188,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 518A,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 518D,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5190,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 5192,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 519F,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 51A2,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 51A5,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 51A7,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 51A9,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 51AB,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 51AD,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 51AF,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 685A,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 685D,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6861,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6863,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6865,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6867,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6869,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 686C,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 686E,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6870,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6872,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6874,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6876,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6878,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 687B,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 687D,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 687F,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6881,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6884,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6886,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6889,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 688B,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 688D,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 688F,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6893,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6895,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 6899,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 689B,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 689D,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68A0,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68A2,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68A4,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68A6,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68A8,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68AB,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68AE,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68B0,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68B2,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68B5,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68B7,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68B8,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68BA,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68BC,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68BF,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68C2,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68C4,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68C6,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 68C9,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7009,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 700C,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 700D,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 700F,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7011,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7012,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7015,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7017,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7018,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7032,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7034,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7037,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7039,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 703B,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 703E,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7040,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7042,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7044,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7047,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7172,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7174,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7176,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7178,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 717A,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 717C,1,{temp2=temp2+1;b@6e=(b@6e+(temp2&1))&0xff;printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 717E,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7180,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7181,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7183,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7185,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7186,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7188,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 718A,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 718C,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 718F,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7191,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7193,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7195,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7197,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
bpset 7199,1,{printf "PI id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4);go}
temp0=0;temp1=0x0;temp2=0;pc=0x6858;cc=0x50;dp=0;s=0x700;b@700=0x0;b@701=0;w@702=0;b@6e=0xFA;b@f03=0x30;b@f02=0xff;b@f03=0x34;b@f02=0xA5
w@700=0x4c34;b@2b=0x20;b@323=0;b@2c=0x7a;b@373=0;b@84=0;b@7d=0;w@3d6=0x3d0;w@3d8=0x3d4;b@3da=0;b@3db=0xa5
b@36B=0x0;b@36C=0x0
b@36D=0x0;b@36E=0x1
b@36F=0x0;b@370=0x2
b@371=0x0;b@372=0x3
save output-0-before.bin,0,800
printf "PS id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
printf "PF id=%X pc=%04X cycle=%016X counter=%02X port=%02X s=%04X polls=%04X\n",temp1,pc,totalcycles,b@6e,b@f02,s,temp2
save output-0-after.bin,0,800
temp0=0;temp1=0x1;temp2=0;pc=0x6858;cc=0x50;dp=0;s=0x700;b@700=0x0;b@701=0;w@702=0;b@6e=0xFA;b@f03=0x30;b@f02=0xff;b@f03=0x34;b@f02=0xA5
w@700=0x4c34;b@2b=0x20;b@323=0;b@2c=0x7a;b@373=0;b@84=0;b@7d=0;w@3d6=0x3d0;w@3d8=0x3d4;b@3da=0;b@3db=0xa5
b@36B=0x1;b@36C=0x0
b@36D=0x0;b@36E=0x1
b@36F=0x0;b@370=0x2
b@371=0x0;b@372=0x3
save output-1-before.bin,0,800
printf "PS id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
printf "PF id=%X pc=%04X cycle=%016X counter=%02X port=%02X s=%04X polls=%04X\n",temp1,pc,totalcycles,b@6e,b@f02,s,temp2
save output-1-after.bin,0,800
temp0=0;temp1=0x2;temp2=0;pc=0x6858;cc=0x50;dp=0;s=0x700;b@700=0x0;b@701=0;w@702=0;b@6e=0xFA;b@f03=0x30;b@f02=0xff;b@f03=0x34;b@f02=0xA5
w@700=0x4c34;b@2b=0x20;b@323=0;b@2c=0x7a;b@373=0;b@84=0;b@7d=0;w@3d6=0x3d0;w@3d8=0x3d4;b@3da=0;b@3db=0xa5
b@36B=0x0;b@36C=0x0
b@36D=0x1;b@36E=0x1
b@36F=0x0;b@370=0x2
b@371=0x0;b@372=0x3
save output-2-before.bin,0,800
printf "PS id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
printf "PF id=%X pc=%04X cycle=%016X counter=%02X port=%02X s=%04X polls=%04X\n",temp1,pc,totalcycles,b@6e,b@f02,s,temp2
save output-2-after.bin,0,800
temp0=0;temp1=0x3;temp2=0;pc=0x6858;cc=0x50;dp=0;s=0x700;b@700=0x0;b@701=0;w@702=0;b@6e=0xFA;b@f03=0x30;b@f02=0xff;b@f03=0x34;b@f02=0xA5
w@700=0x4c34;b@2b=0x20;b@323=0;b@2c=0x7a;b@373=0;b@84=0;b@7d=0;w@3d6=0x3d0;w@3d8=0x3d4;b@3da=0;b@3db=0xa5
b@36B=0x0;b@36C=0x0
b@36D=0x0;b@36E=0x1
b@36F=0x1;b@370=0x2
b@371=0x0;b@372=0x3
save output-3-before.bin,0,800
printf "PS id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
printf "PF id=%X pc=%04X cycle=%016X counter=%02X port=%02X s=%04X polls=%04X\n",temp1,pc,totalcycles,b@6e,b@f02,s,temp2
save output-3-after.bin,0,800
temp0=0;temp1=0x4;temp2=0;pc=0x6858;cc=0x50;dp=0;s=0x700;b@700=0x0;b@701=0;w@702=0;b@6e=0xFA;b@f03=0x30;b@f02=0xff;b@f03=0x34;b@f02=0xA5
w@700=0x4c34;b@2b=0x20;b@323=0;b@2c=0x7a;b@373=0;b@84=0;b@7d=0;w@3d6=0x3d0;w@3d8=0x3d4;b@3da=0;b@3db=0xa5
b@36B=0x0;b@36C=0x0
b@36D=0x0;b@36E=0x1
b@36F=0x0;b@370=0x2
b@371=0x1;b@372=0x3
save output-4-before.bin,0,800
printf "PS id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
printf "PF id=%X pc=%04X cycle=%016X counter=%02X port=%02X s=%04X polls=%04X\n",temp1,pc,totalcycles,b@6e,b@f02,s,temp2
save output-4-after.bin,0,800
temp0=0;temp1=0x5;temp2=0;pc=0x6858;cc=0x50;dp=0;s=0x700;b@700=0x0;b@701=0;w@702=0;b@6e=0xFA;b@f03=0x30;b@f02=0xff;b@f03=0x34;b@f02=0xA5
w@700=0x4c34;b@2b=0x20;b@323=0;b@2c=0x7a;b@373=0;b@84=0;b@7d=0;w@3d6=0x3d0;w@3d8=0x3d4;b@3da=0;b@3db=0xa5
b@36B=0x1;b@36C=0x0
b@36D=0x1;b@36E=0x1
b@36F=0x1;b@370=0x2
b@371=0x1;b@372=0x3
save output-5-before.bin,0,800
printf "PS id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
printf "PF id=%X pc=%04X cycle=%016X counter=%02X port=%02X s=%04X polls=%04X\n",temp1,pc,totalcycles,b@6e,b@f02,s,temp2
save output-5-after.bin,0,800
temp0=0;temp1=0x6;temp2=0;pc=0x6858;cc=0x50;dp=0;s=0x700;b@700=0x0;b@701=0;w@702=0;b@6e=0xFA;b@f03=0x30;b@f02=0xff;b@f03=0x34;b@f02=0xA5
w@700=0x4c34;b@2b=0x20;b@323=0;b@2c=0x7a;b@373=0;b@84=0;b@7d=0;w@3d6=0x3d0;w@3d8=0x3d4;b@3da=0;b@3db=0xa5
b@36B=0x2;b@36C=0x0
b@36D=0x0;b@36E=0x1
b@36F=0x1;b@370=0x2
b@371=0x0;b@372=0x3
save output-6-before.bin,0,800
printf "PS id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
printf "PF id=%X pc=%04X cycle=%016X counter=%02X port=%02X s=%04X polls=%04X\n",temp1,pc,totalcycles,b@6e,b@f02,s,temp2
save output-6-after.bin,0,800
temp0=0;temp1=0x7;temp2=0;pc=0x6858;cc=0x50;dp=0;s=0x700;b@700=0x0;b@701=0;w@702=0;b@6e=0xFA;b@f03=0x30;b@f02=0xff;b@f03=0x34;b@f02=0xA5
w@700=0x4c34;b@2b=0x20;b@323=0;b@2c=0x7a;b@373=0;b@84=0;b@7d=0;w@3d6=0x3d0;w@3d8=0x3d4;b@3da=0;b@3db=0xa5
b@3da=0x1f;w@3d8=0x3d3
b@36B=0x0;b@36C=0x0
b@36D=0x2;b@36E=0x1
b@36F=0x0;b@370=0x2
b@371=0x1;b@372=0x3
save output-7-before.bin,0,800
printf "PS id=%X pc=%04X cycle=%016X bytes=%02X%02X%02X%02X%02X\n",temp1,pc,totalcycles,b@pc,b@(pc+1),b@(pc+2),b@(pc+3),b@(pc+4)
temp0=1
go
temp0=0
printf "PF id=%X pc=%04X cycle=%016X counter=%02X port=%02X s=%04X polls=%04X\n",temp1,pc,totalcycles,b@6e,b@f02,s,temp2
save output-7-after.bin,0,800
quit

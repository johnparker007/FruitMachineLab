using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Native 2C12: software projection of position and signed requested stop offsets.
// This neither moves a stepper nor invents a reel completion time.
public static class AddersReelSymbols
{
    public static void Refresh(Machine machine)
    {
        ushort table=0x75DB;
        for(int reel=0;reel<4;reel++) {
            int x=2*reel;byte stops=machine.Memory[0x75CB+x],steps=machine.Memory[0x75CC+x];
            if(steps==0 || stops is 0 or >63)throw new NotSupportedException("Unrecovered reel geometry outside translated byte-loop domain");
            byte position=machine.Memory[0x168+x],index=255;
            do{index=unchecked((byte)(index+1));if(position<steps)break;position=unchecked((byte)(position-steps));}while(true);
            index=unchecked((byte)(index-machine.Memory[0x169+x]));
            while((sbyte)index<0)index=unchecked((byte)(index+stops));
            do{index=unchecked((byte)(index-stops));}while((sbyte)index>=0);
            index=unchecked((byte)(index+stops));
            machine.WriteWord((ushort)(0x160+x),machine.ReadWord(Cell.Add(table,(ushort)(2*index))));table=Cell.Add(table,(ushort)(2*stops));
        }
    }
    public static void RefreshWithoutRequests(Machine machine)
    {
        if((machine.Memory[0x6B]&0x80)!=0)throw new NotSupportedException("Native 6616 must wait for physical reel completion");
        byte[] saved=new byte[4];for(int reel=0;reel<4;reel++){saved[reel]=machine.Memory[0x169+2*reel];machine.Memory[0x169+2*reel]=0;}
        try{Refresh(machine);}finally{for(int reel=0;reel<4;reel++)machine.Memory[0x169+2*reel]=saved[reel];}
    }
}

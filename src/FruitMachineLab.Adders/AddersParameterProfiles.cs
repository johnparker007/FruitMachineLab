using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Native 169B: byte-register operations and signed 24-bit subtraction flags.
public static class AddersParameterProfiles
{
    public static byte Compute(Machine machine,ushort profile)
    {
        byte tier=1;
        if((sbyte)machine.Memory[0x323]>=0 && (machine.ReadWord(profile)==0x7D5 || (machine.Memory[0x330]==0 && machine.Memory[0x71A0]==0)) && machine.Memory[0xFF42]!=0) {
            ushort counter=machine.ReadWord(profile);
            for(ushort threshold=0x14DB;threshold<0x14EB;threshold+=4) {
                int value=(machine.Memory[counter]<<16)|(machine.Memory[Cell.Add(counter,1)]<<8)|machine.Memory[Cell.Add(counter,2)];
                int limit=(machine.Memory[threshold+1]<<16)|(machine.Memory[threshold+2]<<8)|machine.Memory[threshold+3];
                int Sign24(int n)=>(n&0x800000)!=0 ? n|unchecked((int)0xFF000000) : n;
                if(Sign24(value)<Sign24(limit))break;tier++;
            }
        }
        byte scale=machine.Memory[Cell.Add(profile,unchecked((byte)(tier+8)))];
        byte mode=machine.Memory[0x304];if(machine.Memory[0xE0]==0 || (sbyte)mode>5 || mode!=machine.Memory[0x2F0])mode=6;
        byte multiplier=machine.Memory[Cell.Add(profile,unchecked((byte)(mode+2)))];
        ushort product=(ushort)(scale*multiplier);if(product==0)return 0;
        ushort result=1;while(true){product=Cell.Subtract(product,100);if((short)product<=0)break;result=Cell.Add(result,1);}return (byte)result;
    }
}

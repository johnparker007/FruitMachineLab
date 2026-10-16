using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public static class AddersStakeAccounting
{
    // Native57DB/57A9: unsigned24 wrap and signed mode gate, no NVRAM refresh.
    public static void Increment(Machine m,ushort at)
    {
        if((sbyte)m.Memory[0x323]<0)return;
        uint value=(((uint)m.Memory[at]<<16)|m.ReadWord(Cell.Add(at,1)))+1;
        m.Memory[at]=(byte)(value>>16);m.WriteWord(Cell.Add(at,1),(ushort)value);
    }

    // Native3AFA: accepted calls advance035C only while035B is nonzero.
    public static void Decay(Machine m)
    {
        if((sbyte)m.Memory[0x323]<0 || m.Memory[0x719A]!=0 || m.Memory[0x35B]==0)return;
        m.Memory[0x35C]=unchecked((byte)(m.Memory[0x35C]+1));
        if(m.Memory[0x35C]!=40)return;
        m.Memory[0x35C]=0;m.Memory[0x35B]--;
    }

    // Native4DBE. Cached/key-derived percentage is a configured target, not RTP.
    public static ushort TargetOffset(Machine m)
    {
        byte percentage=m.Memory[0x71A2];
        if(percentage==0){
            (ushort Address,byte Percentage)[] overrides=[(0xFF4E,82),(0xFF50,78),(0xFF4A,84),(0xFF40,82),(0xFF48,80),(0xFF3E,92),(0xFF3C,84)];
            foreach(var item in overrides)if(m.Memory[item.Address]==0){percentage=item.Percentage;break;}
            if(percentage==0){
                if(m.Memory[0x344]!=0 && (byte)~m.Memory[0x345]==m.Memory[0x344])percentage=m.Memory[0x344];
                else{
                    if(m.Memory[0x344]!=0){m.Memory[0x344]=0;m.Memory[0x345]=255;}
                    byte Index(byte[] selectors){byte index=0;for(int n=0;n<4;n++)if(Mpu4InputConditions.Evaluate(m,selectors[n])!=0)index|=(byte)(16>>n);return index;}
                    byte key=Index([7,8,9,10]);if(key==0)key=Index([0x8F,0x8E,0x8D,0x8C]);
                    // Both zero sets carry in4E43;4DBE then uses ROM148F.
                    if(key==0)percentage=m.Memory[0x148F];else return (ushort)(key*5-10);
                }
            }
        }
        return (ushort)Math.Clamp(percentage*5-350,0,140);
    }

    // Native14EB, nine-byte table1462. Preserve subtraction before SWI3 overflow.
    public static void SubtractConfigured(Machine m,ushort selector)
    {
        byte index=(byte)selector;
        if(index>=5)throw new NotSupportedException("Native14EB selector references an uncurated accounting record");
        ushort at=m.ReadWord((ushort)(0x1462+9*index));
        ushort offset=TargetOffset(m),margin=(ushort)Math.Min(offset*2,40);
        m.WriteWord(0x336,margin);
        ushort amount=(ushort)((offset*2+700-margin)>>1),low=m.ReadWord(Cell.Add(at,1));
        byte high=m.Memory[at];bool borrow=low<amount;
        m.WriteWord(Cell.Add(at,1),Cell.Subtract(low,amount));m.Memory[at]=unchecked((byte)(high-(borrow ? 1 : 0)));
        if(high==0x80 && borrow){
            m.Memory[at]=0x80;m.WriteWord(Cell.Add(at,1),0);
            throw new NotSupportedException("Native14EB SWI3 alarm65: accounting underflow after800000 clamp");
        }
        AddersAwardStatistics.RefreshAccounting(m);
    }
}

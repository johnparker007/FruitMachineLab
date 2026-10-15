using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Native1622/166D, with unsigned24 additions57A9 gated by mode0323.
// Selector zero deliberately aliases the global pair; do not deduplicate it.
public static class AddersAwardStatistics
{
    public static void Record(Machine m,ushort amount,ushort selector,bool global)
    {
        if((m.Memory[0x323]&0x80)!=0)return;
        void Add(ushort at,uint value) {
            uint sum=(((uint)m.Memory[at]<<16)|m.ReadWord(Cell.Add(at,1)))+value;
            m.Memory[at]=(byte)(sum>>16);m.WriteWord(Cell.Add(at,1),(ushort)sum);
        }
        ushort indexed=Cell.Add(0x43D,(ushort)(6*(selector&255)));
        if(global){Add(0x43A,1);Add(0x43D,amount);}
        Add(indexed,amount);Add(Cell.Subtract(indexed,3),1);
    }

    public static void Execute(Machine m,bool global)
    {
        ushort selector=m.Pop(),amount=m.Pop();Record(m,amount,selector,global);
    }

    // Native151F: selector table1462, nine-byte records, counter pointer first.
    // SWI3 alarm handling is outside this translation and must remain explicit.
    public static void AddScaled(Machine m,ushort amount,ushort selector)
    {
        byte index=(byte)selector;
        if(index>=5)throw new NotSupportedException("Native151F SWI3 alarm64: accounting selector outside0..4");
        ushort at=m.ReadWord((ushort)(0x1462+9*index));
        uint delta=(uint)amount*500;
        uint before=((uint)m.Memory[at]<<16)|m.ReadWord(Cell.Add(at,1));
        uint sum=before+delta;
        byte high=(byte)(sum>>16),addend=(byte)(delta>>16),oldHigh=m.Memory[at];
        m.Memory[at]=high;m.WriteWord(Cell.Add(at,1),(ushort)sum);
        if(((oldHigh^high)&(addend^high)&0x80)!=0){
            m.Memory[at]=0x7F;m.WriteWord(Cell.Add(at,1),0xFFFF);
            throw new NotSupportedException("Native151F SWI3 alarm65: accounting overflow after7FFFFF clamp");
        }
        RefreshAccounting(m);
    }

    public static void RefreshAccounting(Machine m)
    {
        if((m.Memory[0x323]&0x80)!=0)return;
        byte checksum=0;
        for(ushort at=0x7C9;at<0x7D8;at++){
            byte complement=unchecked((byte)~m.Memory[at]);m.Memory[at+15]=complement;
            checksum=unchecked((byte)(checksum+complement-1));
        }
        m.Memory[0x7E7]=checksum;
    }
}

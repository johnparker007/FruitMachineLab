using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

public static class AddersSoundQueueMemory
{
    // Native5C18/5C51, selected six-record pool. This accompanies the logical
    // scheduler; it does not model sound instruction timing or YM synthesis.
    public static bool Queue(Machine m,ushort stream)
    {
        if((m.Memory[0x719B]&0x80)!=0)return false;
        ushort at=m.ReadWord(0x49);if(at==0)return false;
        if(at<0x1A0 || at>0x259 || (at-0x1A0)%0x25!=0)
            throw new NotSupportedException("Unrecovered sound task pool pointer");
        m.WriteWord((ushort)(at+0x13),stream);m.WriteWord((ushort)(at+8),stream);
        m.WriteWord(0x49,m.ReadWord(at));m.WriteWord(at,m.ReadWord(0x47));m.WriteWord(0x47,at);
        m.WriteWord((ushort)(at+4),0x5D3B);m.Memory[at+0x11]=0;m.Memory[at+0xF]=0;
        m.WriteWord((ushort)(at+6),(ushort)(at+0x25));m.Memory[at+0xA]=0xFF;
        int volume=13*m.Memory[0x50];byte scaled=volume>255 ? (byte)255 : (byte)volume;
        m.Memory[at+0xB]=(byte)((~(scaled>>4)&15)|0xA0);
        m.Memory[at+0xC]=0;m.Memory[at+0xD]=0;m.Memory[at+0x10]=0;m.Memory[at+0x12]=0;
        m.Memory[at+0xE]=16;m.WriteWord((ushort)(at+2),Cell.Add(m.ReadWord(0x45),1));
        return true;
    }
}

using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

public static class AddersPayoutSerial
{
    // Native511B positive one-byte message path used by6858. Transmission and
    // negative two-byte messages are separate, explicitly unrecovered paths.
    public static void Enqueue(Machine m,byte message)
    {
        if((message&0x80)!=0)throw new NotSupportedException("Native511B two-byte serial message requires its A argument");
        byte mode=(byte)(m.Memory[0x71A1]&15);
        if(mode==15)return;
        bool blocked=message>=0x60 ? (mode&(message==0x60 ? 8 : 4))!=0
            : message>=0x20 ? (mode&1)!=0 : (mode&2)!=0 || message is 6 or 0x15;
        if(blocked)return;
        m.Memory[0x84]=0;byte count=m.Memory[0x3DA];
        if(count>=0x20){m.Memory[0x7D]=0xFF;m.Memory[0x2B]|=0x80;}
        ushort at=m.ReadWord(0x3D8);if(at<0x3A8 || at>=0x3D4)at=0x3A8;
        if(count==0)m.WriteWord(0x3D6,at);
        m.Memory[at]=message;m.Memory[0x3DB]=unchecked((byte)(m.Memory[0x3DB]+message));
        m.WriteWord(0x3D8,Cell.Add(at,1));m.Memory[0x3DA]=unchecked((byte)(count+1));
        m.Memory[0x84]=0xFF;
    }
}

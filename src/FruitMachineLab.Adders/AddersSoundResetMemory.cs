using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

public static class AddersSoundResetMemory
{
    // Native5B8F plus60AB cache effects, after the scheduler has accepted5B77.
    // No YM2413 synthesis or CPU/peripheral write timing is claimed.
    public static void Apply(Machine m,Action<byte,byte>? ymWrite=null)
    {
        m.WriteWord(0x47,0);m.WriteWord(0x49,0x1A0);
        for(ushort at=0x1A0;at<0x259;at+=0x25)m.WriteWord(at,(ushort)(at+0x25));
        m.WriteWord(0x259,0);m.Memory[0x4B]=0;
        for(byte n=1;n<=5;n++)m.Memory[0x27D+n]=n;
        m.Memory[0x4C]=5;m.Memory[0x283]=0xFF;
        for(int at=0x5BCE;at<0x5C18;at+=2) {
            byte value=m.Memory[at],register=m.Memory[at+1];int cached=0x284+unchecked((sbyte)register);
            if(m.Memory[cached]==value)continue;
            m.Memory[cached]=value;ymWrite?.Invoke(register,value);
        }
    }
}

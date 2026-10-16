using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public static class AddersBackgroundServices
{
    // Native68F1 translated scan. This adapter reproduces MAME's selected m4addr
    // 6809 compatibility response, not the unknown physical PAL transformation.
    public static void VerifyCharacteriser(Machine m,Func<ushort,byte> response,Action<ushort,byte,byte>? observed=null)
    {
        if((m.Memory[0x719B]&1)!=0)return;
        for(ushort at=0x2B39;at<0x2BB9;at+=2){
            byte call=m.Memory[at],value=response(Cell.Add(at,1));observed?.Invoke(at,call,value);
            if((value&0xFC)!=m.Memory[at+1])throw new NotSupportedException($"Native68F1 SWI alarm16: characteriser mismatch at{at:X4}");
        }
    }
    public static byte Mame6809CompatibilityResponse(Machine m,ushort x)=>x is >=0x800 and <=0xFFF ? (byte)0 : m.Memory[x];

    public static void RefreshDoor(Machine m)
    {
        byte mode=Mpu4InputConditions.Evaluate(m,0x0E)==0xFFFF ? (byte)0x80 : (byte)0;
        if(mode==m.Memory[0x323])return;
        m.Memory[0x323]=mode;
        if(mode==0){
            for(int n=0;n<25;n++)m.Memory[0x2F0+n]=unchecked((byte)~m.Memory[0x309+n]);
            for(int n=0;n<15;n++)m.Memory[0x7C9+n]=unchecked((byte)~m.Memory[0x7D8+n]);
        }
        throw new NotSupportedException("Native6EF7 door-mode change reached reset7CCF after recovered memory effects");
    }
    public static void CheckNvram(Machine m)
    {
        m.Memory[0x38]=unchecked((byte)(m.Memory[0x38]-1));
        if(m.Memory[0x38]!=0 || (m.Memory[0x323]&0x80)!=0)return;
        byte saved=m.Memory[0x2C],sum=0;m.Memory[0x2C]=1;
        for(int n=0;n<25;n++){
            byte copy=m.Memory[0x309+n];
            if((m.Memory[0x323]&0x80)==0 && copy!=unchecked((byte)~m.Memory[0x2F0+n]))throw new NotSupportedException("Native6E99 NVRAM complement fault at6EDE; repair/reset not translated");
            sum=unchecked((byte)(sum+copy-1));
        }
        if(sum!=m.Memory[0x322])throw new NotSupportedException("Native6E99 NVRAM checksum fault at6EDE; repair/reset not translated");
        m.Memory[0x2C]=saved;
    }
    public static void CheckTestGate(Machine m)
    {
        if((m.Memory[0x323]&0x80)!=0 && Mpu4InputConditions.Evaluate(m,0x10)!=0)throw new NotSupportedException("Native2E53 service/Test menu entry remains outside playable scope");
    }
}

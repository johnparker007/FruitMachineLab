using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Prefix and post-70D6 continuation are distinct observed CPU boundaries.
public sealed class AddersSerialDataBitPlan(Machine m, ushort stack,
    Func<ushort,byte> read, ushort entry=0x6AA3)
{
    private byte a;
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        if(entry is not (0x6AA3 or 0x6AB6))throw new NotSupportedException("Unknown serial data-bit entry");
        if(entry==0x6AA3)
        {
            yield return new NativeRoutineStep(0x6AA3,"0A75",()=>m.Memory[0x75]--);
            yield return new NativeRoutineStep(0x6AA5,"2705");
            if(m.Memory[0x75]!=0)
            {
                yield return new NativeRoutineStep(0x6AA7,"8E6AA3");
                yield return new NativeRoutineStep(0x6AAA,"2003");
            }
            else yield return new NativeRoutineStep(0x6AAC,"8E6AC1");
            yield return new NativeRoutineStep(0x6AAF,"10BE038B");
            yield return new NativeRoutineStep(0x6AB3,"BD70D6",()=>m.WriteWord((ushort)(stack-2),0x6AB6));
            yield return new NativeRoutineCall(0x70D6,0x6AB6,m.ReadWord(0x38B),(ushort)(stack-2),0x50);
        }
        yield return new NativeRoutineStep(0x6AB6,"B60B02",()=>a=read(0xB02));
        yield return new NativeRoutineStep(0x6AB9,"48");
        yield return new NativeRoutineStep(0x6ABA,"2402");
        if((a&0x80)!=0)yield return new NativeRoutineStep(0x6ABC,"0C77",()=>m.Memory[0x77]++);
        yield return new NativeRoutineStep(0x6ABE,"0674",()=>m.Memory[0x74]=(byte)((m.Memory[0x74]>>1)|(a&0x80)));
        yield return new NativeRoutineStep(0x6AC0,"39");
    }
}

using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Original-ROM start-bit validation. Hardware helpers retain CPU ownership.
public sealed class AddersSerialStartBitPlan(Machine m, ushort stack, ushort initialY,
    Func<ushort, byte> read, Action<ushort, byte> write)
{
    private byte a;
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        yield return new NativeRoutineStep(0x6A81,"7D0B02",()=>a=read(0xB02));
        yield return new NativeRoutineStep(0x6A84,"2A13");
        if ((a & 0x80) != 0)
        {
            yield return new NativeRoutineStep(0x6A86,"B60B02",()=>a=read(0xB02));
            yield return new NativeRoutineStep(0x6A89,"B60B03",()=>a=read(0xB03));
            yield return new NativeRoutineStep(0x6A8C,"8A01",()=>a|=1);
            yield return new NativeRoutineStep(0x6A8E,"B70B03",()=>write(0xB03,a));
            yield return new NativeRoutineStep(0x6A91,"8E6A3B");
            yield return new NativeRoutineStep(0x6A94,"9F81",()=>m.WriteWord(0x81,0x6A3B));
            yield return new NativeRoutineStep(0x6A96,"7E70C9");
            yield return new NativeRoutineCall(0x70C9,0x4C34,initialY,stack,0x50);
            yield break;
        }
        yield return new NativeRoutineStep(0x6A99,"8E6AA3");
        yield return new NativeRoutineStep(0x6A9C,"10BE038B");
        yield return new NativeRoutineStep(0x6AA0,"7E70D6");
        yield return new NativeRoutineCall(0x70D6,0x4C34,m.ReadWord(0x38B),stack,0x50);
    }
}

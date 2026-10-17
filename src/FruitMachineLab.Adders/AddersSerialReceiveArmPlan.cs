using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public sealed class AddersSerialReceiveArmPlan(Machine m,ushort stack,ushort initialX,ushort initialY,byte initialA,byte initialB,Func<ushort,byte> read,Action<ushort,byte> write)
{
    private byte a;
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        yield return new NativeRoutineStep(0x6A08,"0D72");yield return new NativeRoutineStep(0x6A0A,"2701");if(m.Memory[0x72]!=0){yield return new NativeRoutineStep(0x6A0C,"39");yield break;}
        yield return new NativeRoutineStep(0x6A0D,"0372",()=>m.Memory[0x72]=(byte)~m.Memory[0x72]);yield return new NativeRoutineStep(0x6A0F,"0F75",()=>m.Memory[0x75]=0);
        yield return new NativeRoutineStep(0x6A11,"3436",()=>{m.WriteWord((ushort)(stack-6),(ushort)((initialA<<8)|initialB));m.WriteWord((ushort)(stack-4),initialX);m.WriteWord((ushort)(stack-2),initialY);});
        yield return new NativeRoutineStep(0x6A13,"8E01F4");yield return new NativeRoutineStep(0x6A16,"9F7A",()=>m.WriteWord(0x7A,500));yield return new NativeRoutineStep(0x6A18,"B60B02",()=>a=read(0xB02));
        yield return new NativeRoutineStep(0x6A1B,"8E6A3B");yield return new NativeRoutineStep(0x6A1E,"9F81",()=>m.WriteWord(0x81,0x6A3B));yield return new NativeRoutineStep(0x6A20,"B60B03",()=>a=read(0xB03));yield return new NativeRoutineStep(0x6A23,"8A01",()=>a|=1);yield return new NativeRoutineStep(0x6A25,"B70B03",()=>write(0xB03,a));yield return new NativeRoutineStep(0x6A28,"35B6");
    }
}

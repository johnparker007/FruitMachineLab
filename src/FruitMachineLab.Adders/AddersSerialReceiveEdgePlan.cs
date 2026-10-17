using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public sealed class AddersSerialReceiveEdgePlan(Machine m,ushort stack,Func<ushort,byte> read,Action<ushort,byte> write,ushort entry=0x6A3B)
{
    private byte a;private ushort period;
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        if(entry is not (0x6A3B or 0x6A6B))throw new NotSupportedException("Unknown serial edge entry");
        if(entry==0x6A3B){
            yield return new NativeRoutineStep(0x6A3B,"8E0000");yield return new NativeRoutineStep(0x6A3E,"9F81",()=>m.WriteWord(0x81,0));yield return new NativeRoutineStep(0x6A40,"0D72");yield return new NativeRoutineStep(0x6A42,"2604");
            if(m.Memory[0x72]==0){yield return new NativeRoutineStep(0x6A44,"0372",()=>m.Memory[0x72]=(byte)~m.Memory[0x72]);yield return new NativeRoutineStep(0x6A46,"0F75",()=>m.Memory[0x75]=0);}
            yield return new NativeRoutineStep(0x6A48,"0D75");yield return new NativeRoutineStep(0x6A4A,"262E");
            if(m.Memory[0x75]!=0){yield return new NativeRoutineStep(0x6A7A,"B60B03",()=>a=read(0xB03));yield return new NativeRoutineStep(0x6A7D,"B60B02",()=>a=read(0xB02));yield return new NativeRoutineStep(0x6A80,"39");yield break;}
            yield return new NativeRoutineStep(0x6A4C,"0F77",()=>m.Memory[0x77]=0);yield return new NativeRoutineStep(0x6A4E,"0F74",()=>m.Memory[0x74]=0);
            yield return new NativeRoutineStep(0x6A50,"B60B03",()=>a=read(0xB03));yield return new NativeRoutineStep(0x6A53,"84FE",()=>a&=0xFE);yield return new NativeRoutineStep(0x6A55,"B70B03",()=>write(0xB03,a));yield return new NativeRoutineStep(0x6A58,"10BE038B",()=>period=m.ReadWord(0x38B));
            yield return new NativeRoutineStep(0x6A5C,"1E20");yield return new NativeRoutineStep(0x6A5E,"44");yield return new NativeRoutineStep(0x6A5F,"56",()=>period>>=1);yield return new NativeRoutineStep(0x6A60,"83006E",()=>period=unchecked((ushort)(period-110)));yield return new NativeRoutineStep(0x6A63,"1E20");yield return new NativeRoutineStep(0x6A65,"8E6A81");
            yield return new NativeRoutineStep(0x6A68,"BD70D6",()=>m.WriteWord((ushort)(stack-2),0x6A6B));yield return new NativeRoutineCall(0x70D6,0x6A6B,period,(ushort)(stack-2),0x50);
        }
        yield return new NativeRoutineStep(0x6A6B,"8607",()=>a=7);yield return new NativeRoutineStep(0x6A6D,"9775",()=>m.Memory[0x75]=a);yield return new NativeRoutineStep(0x6A6F,"B6038E",()=>a=m.Memory[0x38E]);yield return new NativeRoutineStep(0x6A72,"8508");yield return new NativeRoutineStep(0x6A74,"2703");if((a&8)!=0)yield return new NativeRoutineStep(0x6A76,"7C0075",()=>m.Memory[0x75]++);yield return new NativeRoutineStep(0x6A79,"39");
    }
}

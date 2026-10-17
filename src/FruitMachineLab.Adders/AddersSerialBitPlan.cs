using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

//69A9 stores the PIA control-register image for one serial bit, or FF sentinel.
public sealed class AddersSerialBitPlan(Machine m,byte value,Func<ushort,byte> read)
{
    private ushort x;private byte a=value;private bool carry;
    public byte A=>a;public ushort X=>x;
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        yield return new NativeRoutineStep(0x69A9,"9E78",()=>x=m.ReadWord(0x78));yield return new NativeRoutineStep(0x69AB,"81FF");yield return new NativeRoutineStep(0x69AD,"270C");
        if(a!=255){
            yield return new NativeRoutineStep(0x69AF,"44",()=>{carry=(a&1)!=0;a>>=1;});yield return new NativeRoutineStep(0x69B0,"B60C01",()=>a=read(0xC01));
            yield return new NativeRoutineStep(0x69B3,"843F",()=>a&=0x3F);yield return new NativeRoutineStep(0x69B5,"8A3C",()=>a|=0x3C);yield return new NativeRoutineStep(0x69B7,"2502");if(!carry)yield return new NativeRoutineStep(0x69B9,"8437",()=>a&=0x37);
        }
        yield return new NativeRoutineStep(0x69BB,"A780",()=>{m.Memory[x]=a;x++;});yield return new NativeRoutineStep(0x69BD,"9F78",()=>m.WriteWord(0x78,x));yield return new NativeRoutineStep(0x69BF,"39");
    }
}

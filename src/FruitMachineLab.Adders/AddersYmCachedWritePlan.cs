using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Native60AB preserves X, writes the signed-B cache only when changed, and
// reports a completed address/data pair at60B9. No audio synthesis is modeled.
public sealed class AddersYmCachedWritePlan(Machine m,byte value,byte register,ushort savedX,ushort stack,Action<byte,byte>? write=null)
{
    private bool unchanged;private ushort s=stack;
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        yield return new NativeRoutineStep(0x60AB,"3410",()=>{s-=2;m.WriteWord(s,savedX);});
        yield return new NativeRoutineStep(0x60AD,"8E0284");
        yield return new NativeRoutineStep(0x60B0,"A185",()=>unchanged=value==m.Memory[0x284+unchecked((sbyte)register)]);
        yield return new NativeRoutineStep(0x60B2,"2709");
        if(!unchanged){
            yield return new NativeRoutineStep(0x60B4,"F70880");
            yield return new NativeRoutineStep(0x60B7,"A785",()=>m.Memory[0x284+unchecked((sbyte)register)]=value);
            yield return new NativeRoutineStep(0x60B9,"B70881",()=>write?.Invoke(register,value));
            yield return new NativeRoutineStep(0x60BC,"12");
        }
        yield return new NativeRoutineStep(0x60BD,"3590");
    }
}

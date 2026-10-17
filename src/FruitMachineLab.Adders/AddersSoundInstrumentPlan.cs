using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Native5F5B, shared DB/DC/DD helper. Unsigned ABX uses the wrapped byte sum;
// command-derived B may be signed-negative for the cache. Preserve that aliasing.
public sealed class AddersSoundInstrumentPlan(Machine m,ushort task,ushort cursor,ushort stack,Action<byte,byte>? write=null)
{
    private byte a,b;private ushort u=cursor,x,s=stack;private bool negative;
    public ushort Cursor=>u;
    public ushort X=>x;
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        AddersSoundLifecycleMemory.ValidateTask(task);
        yield return new NativeRoutineStep(0x5F5B,"E6C0",()=>{b=m.Memory[u];u++;});
        yield return new NativeRoutineStep(0x5F5D,"6DA812",()=>negative=(sbyte)m.Memory[task+0x12]<0);
        yield return new NativeRoutineStep(0x5F60,"2A02");
        if(negative)yield return new NativeRoutineStep(0x5F62,"DB4D",()=>b+=m.Memory[0x4D]);
        yield return new NativeRoutineStep(0x5F64,"EB2C",()=>b+=m.Memory[task+0xC]);
        yield return new NativeRoutineStep(0x5F66,"EB2D",()=>b+=m.Memory[task+0xD]);
        yield return new NativeRoutineStep(0x5F68,"8E5A1E",()=>x=0x5A1E);
        yield return new NativeRoutineStep(0x5F6B,"3A",()=>x+=b);yield return new NativeRoutineStep(0x5F6C,"3A",()=>x+=b);
        yield return new NativeRoutineStep(0x5F6D,"E65E",()=>b=m.Memory[unchecked((ushort)(u-2))]);
        yield return new NativeRoutineStep(0x5F6F,"C0C5",()=>b-=0xC5);
        yield return new NativeRoutineStep(0x5F71,"A601",()=>a=m.Memory[x+1]);
        yield return new NativeRoutineStep(0x5F73,"BD60AB",()=>{s-=2;m.WriteWord(s,0x5F76);});
        foreach(var op in new AddersYmCachedWritePlan(m,a,b,x,s,write).Instructions())yield return op;s+=2;
        yield return new NativeRoutineStep(0x5F76,"CB10",()=>b+=0x10);
        yield return new NativeRoutineStep(0x5F78,"A684",()=>a=m.Memory[x]);
        yield return new NativeRoutineStep(0x5F7A,"840F",()=>a&=0x0F);
        yield return new NativeRoutineStep(0x5F7C,"BD60AB",()=>{s-=2;m.WriteWord(s,0x5F7F);});
        foreach(var op in new AddersYmCachedWritePlan(m,a,b,x,s,write).Instructions())yield return op;s+=2;
        yield return new NativeRoutineStep(0x5F7F,"7E5D3B");
    }
}

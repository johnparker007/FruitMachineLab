using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

// Selected5E2C/60AB instruction plan. It stages RAM/cache effects, not audio.
// Y/DP stay fixed; native stack writes are real. No complete CPU register contract.
public sealed class AddersSoundReleasePlan(Machine m,ushort task,ushort stack,ushort initialU,ushort initialX,Action<byte,byte>? ymWrite=null)
{
    private byte a,b;
    private ushort x=initialX,s=stack;
    private bool zero,negative;
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        AddersSoundLifecycleMemory.ValidateTask(task);
        yield return new NativeRoutineStep(0x5E2C,"3440",()=>{s-=2;m.WriteWord(s,initialU);});
        yield return new NativeRoutineStep(0x5E2E,"CE0284");
        yield return new NativeRoutineStep(0x5E31,"A6A811",()=>{a=m.Memory[task+0x11];zero=a==0;});
        yield return new NativeRoutineStep(0x5E34,"270B");
        if(!zero){
            yield return new NativeRoutineStep(0x5E36,"6FA811",()=>m.Memory[task+0x11]=0);
            yield return new NativeRoutineStep(0x5E39,"43",()=>a=(byte)~a);
            yield return new NativeRoutineStep(0x5E3A,"A44E",()=>a&=m.Memory[0x292]);
            yield return new NativeRoutineStep(0x5E3C,"C60E",()=>b=0x0E);
            yield return new NativeRoutineStep(0x5E3E,"BD60AB",()=>{s-=2;m.WriteWord(s,0x5E41);});
            foreach(var op in CachedWrite())yield return op;
        }
        yield return new NativeRoutineStep(0x5E41,"8E027E",()=>x=0x27E);
        yield return new NativeRoutineStep(0x5E44,"6F2F",()=>m.Memory[task+0xF]=0);
        var seen=new HashSet<byte>();
        while(true){
            yield return new NativeRoutineStep(0x5E46,"E62A",()=>{b=m.Memory[task+0xA];negative=(sbyte)b<0;});
            yield return new NativeRoutineStep(0x5E48,"2B21");
            if(negative)break;
            if(b>5 || !seen.Add(b))throw new InvalidDataException("Invalid native sound channel chain");
            yield return new NativeRoutineStep(0x5E4A,"A685",()=>a=m.Memory[x+b]);
            yield return new NativeRoutineStep(0x5E4C,"A72A",()=>m.Memory[task+0xA]=a);
            yield return new NativeRoutineStep(0x5E4E,"CB20",()=>b+=0x20);
            yield return new NativeRoutineStep(0x5E50,"A6C5",()=>a=m.Memory[0x284+b]);
            yield return new NativeRoutineStep(0x5E52,"84EF",()=>a&=0xEF);
            yield return new NativeRoutineStep(0x5E54,"BD60AB",()=>{s-=2;m.WriteWord(s,0x5E57);});
            foreach(var op in CachedWrite())yield return op;
            yield return new NativeRoutineStep(0x5E57,"C020",()=>b-=0x20);
            yield return new NativeRoutineStep(0x5E59,"964C",()=>{a=m.Memory[0x4C];negative=(sbyte)a<0;});
            yield return new NativeRoutineStep(0x5E5B,"2B04");
            if(!negative){
                if(a>5)throw new InvalidDataException("Invalid native free-channel tail");
                yield return new NativeRoutineStep(0x5E5D,"E786",()=>m.Memory[x+a]=b);
                yield return new NativeRoutineStep(0x5E5F,"2002");
            }else yield return new NativeRoutineStep(0x5E61,"D74B",()=>m.Memory[0x4B]=b);
            yield return new NativeRoutineStep(0x5E63,"D74C",()=>m.Memory[0x4C]=b);
            yield return new NativeRoutineStep(0x5E65,"86FF",()=>a=255);
            yield return new NativeRoutineStep(0x5E67,"A785",()=>m.Memory[x+b]=a);
            yield return new NativeRoutineStep(0x5E69,"20DB");
        }
        yield return new NativeRoutineStep(0x5E6B,"35C0",()=>s+=4);
    }
    private IEnumerable<NativeRoutineWork> CachedWrite()
    {
        foreach(var op in new AddersYmCachedWritePlan(m,a,b,x,s,ymWrite).Instructions())yield return op;
        s+=2;
    }
}
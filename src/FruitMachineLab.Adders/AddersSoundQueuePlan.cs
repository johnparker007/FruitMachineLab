using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Foreground5C18 with disabled60C8 gate and real S saves. One call, not a
// scheduler tick. Its5C51 sequence follows the same recovered allocator as C2.
public sealed class AddersSoundQueuePlan(Machine m,ushort stream,ushort stack,ushort initialY,byte initialA,byte initialB)
{
    private ushort s=stack,x=stream,y=initialY,clock;
    private byte a=initialA,b=initialB;
    public bool Queued {get;private set;}
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        yield return new NativeRoutineStep(0x5C18,"BD60C8",()=>{s-=2;m.WriteWord(s,0x5C1B);});
        yield return new NativeRoutineStep(0x60C8,"3404",()=>{s--;m.Memory[s]=b;});
        yield return new NativeRoutineStep(0x60CA,"F6719B",()=>b=m.Memory[0x719B]);
        yield return new NativeRoutineStep(0x60CD,"C580");yield return new NativeRoutineStep(0x60CF,"2602");
        if((b&0x80)!=0){yield return new NativeRoutineStep(0x60D3,"3263",()=>s+=3);yield return new NativeRoutineStep(0x60D5,"39");yield break;}
        yield return new NativeRoutineStep(0x60D1,"3584",()=>{b=m.Memory[s];s+=3;});
        yield return new NativeRoutineStep(0x5C1B,"3436",()=>{s-=6;m.WriteWord(s,(ushort)((a<<8)|b));m.WriteWord((ushort)(s+2),x);m.WriteWord((ushort)(s+4),y);});
        yield return new NativeRoutineStep(0x5C1D,"0C44",()=>m.Memory[0x44]++);
        yield return new NativeRoutineStep(0x5C1F,"8D30",()=>{s-=2;m.WriteWord(s,0x5C21);});
        yield return new NativeRoutineStep(0x5C51,"109E49",()=>y=m.ReadWord(0x49));yield return new NativeRoutineStep(0x5C54,"2723");
        if(y!=0){
            AddersSoundLifecycleMemory.ValidateTask(y);
            yield return new NativeRoutineStep(0x5C56,"AFA813",()=>m.WriteWord((ushort)(y+0x13),x));yield return new NativeRoutineStep(0x5C59,"AF28",()=>m.WriteWord((ushort)(y+8),x));
            yield return new NativeRoutineStep(0x5C5B,"AEA4",()=>x=m.ReadWord(y));yield return new NativeRoutineStep(0x5C5D,"9F49",()=>m.WriteWord(0x49,x));
            yield return new NativeRoutineStep(0x5C5F,"9E47",()=>x=m.ReadWord(0x47));yield return new NativeRoutineStep(0x5C61,"AFA4",()=>m.WriteWord(y,x));yield return new NativeRoutineStep(0x5C63,"109F47",()=>m.WriteWord(0x47,y));
            yield return new NativeRoutineStep(0x5C66,"8E5D3B",()=>x=0x5D3B);yield return new NativeRoutineStep(0x5C69,"AF24",()=>m.WriteWord((ushort)(y+4),x));
            yield return new NativeRoutineStep(0x5C6B,"6FA811",()=>m.Memory[y+0x11]=0);yield return new NativeRoutineStep(0x5C6E,"6F2F",()=>m.Memory[y+0xF]=0);
            yield return new NativeRoutineStep(0x5C70,"30A825",()=>x=(ushort)(y+0x25));yield return new NativeRoutineStep(0x5C73,"AF26",()=>m.WriteWord((ushort)(y+6),x));
            yield return new NativeRoutineStep(0x5C75,"86FF",()=>a=255);yield return new NativeRoutineStep(0x5C77,"A72A",()=>m.Memory[y+0xA]=a);
        }
        yield return new NativeRoutineStep(0x5C79,"39",()=>s+=2);yield return new NativeRoutineStep(0x5C21,"272A");
        if(y!=0){
            yield return new NativeRoutineStep(0x5C23,"860D",()=>a=13);yield return new NativeRoutineStep(0x5C25,"D650",()=>b=m.Memory[0x50]);
            yield return new NativeRoutineStep(0x5C27,"3D",()=>{int product=a*b;a=(byte)(product>>8);b=(byte)product;});
            yield return new NativeRoutineStep(0x5C28,"4D");yield return new NativeRoutineStep(0x5C29,"2702");if(a!=0)yield return new NativeRoutineStep(0x5C2B,"C6FF",()=>b=255);
            yield return new NativeRoutineStep(0x5C2D,"54",()=>b>>=1);yield return new NativeRoutineStep(0x5C2E,"54",()=>b>>=1);yield return new NativeRoutineStep(0x5C2F,"54",()=>b>>=1);yield return new NativeRoutineStep(0x5C30,"54",()=>b>>=1);
            yield return new NativeRoutineStep(0x5C31,"53",()=>b=(byte)~b);yield return new NativeRoutineStep(0x5C32,"C40F",()=>b&=15);yield return new NativeRoutineStep(0x5C34,"CAA0",()=>b|=0xA0);
            yield return new NativeRoutineStep(0x5C36,"E72B",()=>m.Memory[y+0xB]=b);yield return new NativeRoutineStep(0x5C38,"6F2C",()=>m.Memory[y+0xC]=0);yield return new NativeRoutineStep(0x5C3A,"6F2D",()=>m.Memory[y+0xD]=0);
            yield return new NativeRoutineStep(0x5C3C,"6FA810",()=>m.Memory[y+0x10]=0);yield return new NativeRoutineStep(0x5C3F,"6FA812",()=>m.Memory[y+0x12]=0);
            yield return new NativeRoutineStep(0x5C42,"8610",()=>a=16);yield return new NativeRoutineStep(0x5C44,"A72E",()=>m.Memory[y+0xE]=a);
            yield return new NativeRoutineStep(0x5C46,"DC45",()=>clock=m.ReadWord(0x45));yield return new NativeRoutineStep(0x5C48,"C30001",()=>clock++);yield return new NativeRoutineStep(0x5C4B,"ED22",()=>{m.WriteWord((ushort)(y+2),clock);Queued=true;});
        }
        yield return new NativeRoutineStep(0x5C4D,"0A44",()=>m.Memory[0x44]--);yield return new NativeRoutineStep(0x5C4F,"35B6");
    }
}

using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Native C2 handler5EE3 with5C51 allocation. Child is due at the current clock;
// parent continues immediately. It does not call foreground5C18/disabled gating.
public sealed class AddersSoundChildPlan(Machine m,ushort parent,ushort cursor,ushort stack)
{
    private ushort x,y=parent,u=cursor,s=stack,clock;private byte a;
    private readonly ushort owner=parent;
    public ushort Cursor=>u;
    public ushort X=>x;
    public ushort Child {get;private set;}
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        AddersSoundLifecycleMemory.ValidateTask(owner);
        yield return new NativeRoutineStep(0x5EE3,"3420",()=>{s-=2;m.WriteWord(s,y);});
        yield return new NativeRoutineStep(0x5EE5,"AEC1",()=>{x=m.ReadWord(u);u+=2;});
        yield return new NativeRoutineStep(0x5EE7,"BD5C51",()=>{s-=2;m.WriteWord(s,0x5EEA);});
        yield return new NativeRoutineStep(0x5C51,"109E49",()=>{y=m.ReadWord(0x49);Child=y;});
        yield return new NativeRoutineStep(0x5C54,"2723");
        if(y!=0){
            AddersSoundLifecycleMemory.ValidateTask(y);if(y==owner)throw new InvalidDataException("Parent sound task is also free");
            yield return new NativeRoutineStep(0x5C56,"AFA813",()=>m.WriteWord((ushort)(y+0x13),x));
            yield return new NativeRoutineStep(0x5C59,"AF28",()=>m.WriteWord((ushort)(y+8),x));
            yield return new NativeRoutineStep(0x5C5B,"AEA4",()=>x=m.ReadWord(y));
            yield return new NativeRoutineStep(0x5C5D,"9F49",()=>m.WriteWord(0x49,x));
            yield return new NativeRoutineStep(0x5C5F,"9E47",()=>x=m.ReadWord(0x47));
            yield return new NativeRoutineStep(0x5C61,"AFA4",()=>m.WriteWord(y,x));
            yield return new NativeRoutineStep(0x5C63,"109F47",()=>m.WriteWord(0x47,y));
            yield return new NativeRoutineStep(0x5C66,"8E5D3B",()=>x=0x5D3B);
            yield return new NativeRoutineStep(0x5C69,"AF24",()=>m.WriteWord((ushort)(y+4),x));
            yield return new NativeRoutineStep(0x5C6B,"6FA811",()=>m.Memory[y+0x11]=0);
            yield return new NativeRoutineStep(0x5C6E,"6F2F",()=>m.Memory[y+0xF]=0);
            yield return new NativeRoutineStep(0x5C70,"30A825",()=>x=(ushort)(y+0x25));
            yield return new NativeRoutineStep(0x5C73,"AF26",()=>m.WriteWord((ushort)(y+6),x));
            yield return new NativeRoutineStep(0x5C75,"86FF",()=>a=255);
            yield return new NativeRoutineStep(0x5C77,"A72A",()=>m.Memory[y+0xA]=a);
        }
        yield return new NativeRoutineStep(0x5C79,"39",()=>s+=2);
        yield return new NativeRoutineStep(0x5EEA,"3510",()=>{x=m.ReadWord(s);s+=2;});
        yield return new NativeRoutineStep(0x5EEC,"1E12",()=>{(x,y)=(y,x);});
        yield return new NativeRoutineStep(0x5EEE,"1027FE49",Branch:Child==0);if(Child==0)yield break;
        yield return new NativeRoutineStep(0x5EF2,"A62B",()=>a=m.Memory[y+0xB]);yield return new NativeRoutineStep(0x5EF4,"A70B",()=>m.Memory[x+0xB]=a);
        yield return new NativeRoutineStep(0x5EF6,"A62C",()=>a=m.Memory[y+0xC]);yield return new NativeRoutineStep(0x5EF8,"A70C",()=>m.Memory[x+0xC]=a);
        yield return new NativeRoutineStep(0x5EFA,"A62D",()=>a=m.Memory[y+0xD]);yield return new NativeRoutineStep(0x5EFC,"A70D",()=>m.Memory[x+0xD]=a);
        yield return new NativeRoutineStep(0x5EFE,"A62E",()=>a=m.Memory[y+0xE]);yield return new NativeRoutineStep(0x5F00,"A70E",()=>m.Memory[x+0xE]=a);
        yield return new NativeRoutineStep(0x5F02,"A6A810",()=>a=m.Memory[y+0x10]);yield return new NativeRoutineStep(0x5F05,"A78810",()=>m.Memory[x+0x10]=a);
        yield return new NativeRoutineStep(0x5F08,"A6A812",()=>a=m.Memory[y+0x12]);yield return new NativeRoutineStep(0x5F0B,"A78812",()=>m.Memory[x+0x12]=a);
        yield return new NativeRoutineStep(0x5F0E,"DC45",()=>clock=m.ReadWord(0x45));
        yield return new NativeRoutineStep(0x5F10,"ED02",()=>m.WriteWord((ushort)(x+2),clock));
        yield return new NativeRoutineStep(0x5F12,"7E5D3B");
    }
}

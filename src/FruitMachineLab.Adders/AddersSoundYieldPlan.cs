using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Native5CF3 consumes the JSR return as a CALLBACK, not a normal return.
// Caller owns the task removed from0047. Completion continues5CDE at same tick.
public sealed class AddersSoundYieldPlan(Machine m,ushort task,ushort cursor,ushort stack,byte duration)
{
    private byte a,b=duration;
    private ushort s=stack,x,u=cursor,d;
    private bool negative,zero,carry,insertAfter;
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        AddersSoundLifecycleMemory.ValidateTask(task);
        yield return new NativeRoutineStep(0x5CF3,"EF28",()=>m.WriteWord((ushort)(task+8),u));
        yield return new NativeRoutineStep(0x5CF5,"3510",()=>{x=m.ReadWord(s);s+=2;});
        yield return new NativeRoutineStep(0x5CF7,"AF24",()=>m.WriteWord((ushort)(task+4),x));
        yield return new NativeRoutineStep(0x5CF9,"8610",()=>a=16);
        yield return new NativeRoutineStep(0x5CFB,"6DA812",()=>negative=(sbyte)m.Memory[task+0x12]<0);
        yield return new NativeRoutineStep(0x5CFE,"2A02");
        if(negative)yield return new NativeRoutineStep(0x5D00,"964E",()=>a=m.Memory[0x4E]);
        yield return new NativeRoutineStep(0x5D02,"3D",()=>{int product=a*b;a=(byte)(product>>8);b=(byte)product;});
        yield return new NativeRoutineStep(0x5D03,"3406",()=>{s-=2;m.WriteWord(s,(ushort)((a<<8)|b));});
        yield return new NativeRoutineStep(0x5D05,"A62E",()=>a=m.Memory[task+0xE]);
        yield return new NativeRoutineStep(0x5D07,"3D",()=>{int product=a*b;a=(byte)(product>>8);b=(byte)product;});
        yield return new NativeRoutineStep(0x5D08,"E6E4",()=>b=m.Memory[s]);
        yield return new NativeRoutineStep(0x5D0A,"A7E4",()=>m.Memory[s]=a);
        yield return new NativeRoutineStep(0x5D0C,"A62E",()=>a=m.Memory[task+0xE]);
        yield return new NativeRoutineStep(0x5D0E,"3D",()=>{int product=a*b;a=(byte)(product>>8);b=(byte)product;});
        yield return new NativeRoutineStep(0x5D0F,"EBE4",()=>{int sum=b+m.Memory[s];b=(byte)sum;carry=sum>255;});
        yield return new NativeRoutineStep(0x5D11,"8900",()=>a=unchecked((byte)(a+(carry ? 1 : 0))));
        yield return new NativeRoutineStep(0x5D13,"CE0047",()=>u=0x47);
        yield return new NativeRoutineStep(0x5D16,"EDE4",()=>{d=(ushort)((a<<8)|b);m.WriteWord(s,d);zero=d==0;});
        yield return new NativeRoutineStep(0x5D18,"2602");
        if(zero)yield return new NativeRoutineStep(0x5D1A,"6C61",()=>m.Memory[s+1]++);
        var seen=new HashSet<ushort>();
        while(true){
            yield return new NativeRoutineStep(0x5D1C,"30C4",()=>x=u);
            yield return new NativeRoutineStep(0x5D1E,"EE84",()=>u=m.ReadWord(x));
            yield return new NativeRoutineStep(0x5D20,"2709");if(u==0)break;
            AddersSoundLifecycleMemory.ValidateTask(u);if(u==task || !seen.Add(u))throw new InvalidDataException("Invalid yielded sound list ownership");
            yield return new NativeRoutineStep(0x5D22,"EC42",()=>d=m.ReadWord((ushort)(u+2)));
            yield return new NativeRoutineStep(0x5D24,"9345",()=>d=unchecked((ushort)(d-m.ReadWord(0x45))));
            yield return new NativeRoutineStep(0x5D26,"10A3E4",()=>insertAfter=d<=m.ReadWord(s));
            yield return new NativeRoutineStep(0x5D29,"23F1");if(!insertAfter)break;
        }
        yield return new NativeRoutineStep(0x5D2B,"3506",()=>{d=m.ReadWord(s);s+=2;});
        yield return new NativeRoutineStep(0x5D2D,"D345",()=>d=Cell.Add(d,m.ReadWord(0x45)));
        yield return new NativeRoutineStep(0x5D2F,"ED22",()=>m.WriteWord((ushort)(task+2),d));
        yield return new NativeRoutineStep(0x5D31,"EFA4",()=>m.WriteWord(task,u));
        yield return new NativeRoutineStep(0x5D33,"10AF84",()=>m.WriteWord(x,task));
        yield return new NativeRoutineStep(0x5D36,"20A6");
    }
}

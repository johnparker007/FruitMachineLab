using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public sealed class AddersSoundCancelPlan(Machine m,ushort stream,ushort stack,ushort initialY,ushort initialU,byte initialA,byte initialB,Action<byte,byte>? write=null)
{
    private ushort x=stream,y=initialY,s=stack,d;private byte a=initialA,b=initialB;private bool found;
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        yield return new NativeRoutineStep(0x5C7A,"BD60C8",()=>{s-=2;m.WriteWord(s,0x5C7D);});
        yield return new NativeRoutineStep(0x60C8,"3404",()=>{s--;m.Memory[s]=b;});yield return new NativeRoutineStep(0x60CA,"F6719B",()=>b=m.Memory[0x719B]);
        yield return new NativeRoutineStep(0x60CD,"C580");yield return new NativeRoutineStep(0x60CF,"2602");
        if((b&0x80)!=0){yield return new NativeRoutineStep(0x60D3,"3263");yield return new NativeRoutineStep(0x60D5,"39");yield break;}
        yield return new NativeRoutineStep(0x60D1,"3584",()=>{b=m.Memory[s];s+=3;});
        yield return new NativeRoutineStep(0x5C7D,"3436",()=>{s-=6;m.WriteWord(s,(ushort)((a<<8)|b));m.WriteWord((ushort)(s+2),x);m.WriteWord((ushort)(s+4),y);});
        yield return new NativeRoutineStep(0x5C7F,"0C44",()=>m.Memory[0x44]++);
        yield return new NativeRoutineStep(0x5C81,"8D32",()=>{s-=2;m.WriteWord(s,0x5C83);});
        yield return new NativeRoutineStep(0x5CB5,"1F10",()=>d=x);yield return new NativeRoutineStep(0x5CB7,"108E0047",()=>y=0x47);
        var seen=new HashSet<ushort>();while(true){
            yield return new NativeRoutineStep(0x5CBB,"30A4",()=>x=y);yield return new NativeRoutineStep(0x5CBD,"10AE84",()=>y=m.ReadWord(x));
            yield return new NativeRoutineStep(0x5CC0,"2708");if(y==0)break;
            AddersSoundLifecycleMemory.ValidateTask(y);if(!seen.Add(y))throw new InvalidDataException("Cyclic native cancel list");
            yield return new NativeRoutineStep(0x5CC2,"10A3A813",()=>found=d==m.ReadWord((ushort)(y+0x13)));yield return new NativeRoutineStep(0x5CC6,"26F3");
            if(found){yield return new NativeRoutineStep(0x5CC8,"8601",()=>a=1);break;}
        }
        yield return new NativeRoutineStep(0x5CCA,"39",()=>s+=2);yield return new NativeRoutineStep(0x5C83,"270E");
        if(found){
            yield return new NativeRoutineStep(0x5C85,"ECA4",()=>d=m.ReadWord(y));yield return new NativeRoutineStep(0x5C87,"ED84",()=>m.WriteWord(x,d));
            yield return new NativeRoutineStep(0x5C89,"9E49",()=>x=m.ReadWord(0x49));yield return new NativeRoutineStep(0x5C8B,"AFA4",()=>m.WriteWord(y,x));yield return new NativeRoutineStep(0x5C8D,"109F49",()=>m.WriteWord(0x49,y));
            yield return new NativeRoutineStep(0x5C90,"BD5E2C",()=>{s-=2;m.WriteWord(s,0x5C93);});
            foreach(var op in new AddersSoundReleasePlan(m,y,s,initialU,x,write).Instructions())yield return op;s+=2;
        }
        yield return new NativeRoutineStep(0x5C93,"0A44",()=>m.Memory[0x44]--);yield return new NativeRoutineStep(0x5C95,"35B6");
    }
}

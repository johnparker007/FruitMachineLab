using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// C5 absolute attenuation high nibble,5F88->5FDB. Existing channels update their
// native YM cache; it is not an instrument-table command.
public sealed class AddersSoundAttenuationPlan(Machine m,ushort task,ushort cursor,ushort stack,ushort initialX,Action<byte,byte>? write=null)
{
    private ushort u=cursor,s=stack,x=initialX;private byte a,b;private bool negative;
    public ushort Cursor=>u;public ushort X=>x;
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        yield return new NativeRoutineStep(0x5F88,"A6C0",()=>{a=m.Memory[u];u++;});
        yield return new NativeRoutineStep(0x5F8A,"A82B",()=>a^=m.Memory[task+0xB]);
        yield return new NativeRoutineStep(0x5F8C,"84F0",()=>a&=0xF0);
        yield return new NativeRoutineStep(0x5F8E,"A82B",()=>a^=m.Memory[task+0xB]);
        yield return new NativeRoutineStep(0x5F90,"2033");
        yield return new NativeRoutineStep(0x5FC5,"A72B",()=>m.Memory[task+0xB]=a);
        yield return new NativeRoutineStep(0x5FC7,"E62A",()=>{b=m.Memory[task+0xA];negative=(sbyte)b<0;});
        yield return new NativeRoutineStep(0x5FC9,"102BFD6E",Branch:negative);if(negative)yield break;
        yield return new NativeRoutineStep(0x5FCD,"8E027E",()=>x=0x27E);
        var seen=new HashSet<byte>();
        while(true){
            if(b>5 || !seen.Add(b))throw new InvalidDataException("Invalid attenuation channel chain");
            yield return new NativeRoutineStep(0x5FD0,"CB30",()=>b+=0x30);
            yield return new NativeRoutineStep(0x5FD2,"BD60AB",()=>{s-=2;m.WriteWord(s,0x5FD5);});
            foreach(var op in new AddersYmCachedWritePlan(m,a,b,x,s,write).Instructions())yield return op;s+=2;
            yield return new NativeRoutineStep(0x5FD5,"C030",()=>b-=0x30);
            yield return new NativeRoutineStep(0x5FD7,"E685",()=>{b=m.Memory[x+b];negative=(sbyte)b<0;});
            yield return new NativeRoutineStep(0x5FD9,"2AF5");if(negative)break;
        }
        yield return new NativeRoutineStep(0x5FDB,"7E5D3B");
    }
}

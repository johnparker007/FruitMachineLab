using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Timer2 TX callback prefix. Typed handoffs prevent pretending a rearm/reset
// completed before the shared PTM helper owns the CPU.
public sealed class AddersSerialTransmitPlan(Machine m,ushort stack,ushort initialY,ushort entry=0x69C0)
{
    private ushort x;private byte b;
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        if(entry is not (0x69C0 or 0x69D7))throw new NotSupportedException("Unrecovered TX callback entry");
        if(entry==0x69C0){
        yield return new NativeRoutineStep(0x69C0,"9E42",()=>x=m.ReadWord(0x42));yield return new NativeRoutineStep(0x69C2,"E680",()=>{b=m.Memory[x];x++;});yield return new NativeRoutineStep(0x69C4,"9F42",()=>m.WriteWord(0x42,x));yield return new NativeRoutineStep(0x69C6,"C1FF");yield return new NativeRoutineStep(0x69C8,"2705");
        if(b!=255){yield return new NativeRoutineStep(0x69CA,"F70C01",()=>Write?.Invoke(0xC01,b));yield return new NativeRoutineStep(0x69CD,"202F");yield return new NativeRoutineStep(0x69FE,"8E69C0");yield return new NativeRoutineStep(0x6A01,"10BE0389");yield return new NativeRoutineStep(0x6A05,"7E70D6");yield return new NativeRoutineCall(0x70D6,0x4C34,m.ReadWord(0x389),stack,0x50);yield break;}
        yield return new NativeRoutineStep(0x69CF,"C63C",()=>b=0x3C);yield return new NativeRoutineStep(0x69D1,"F70C01",()=>Write?.Invoke(0xC01,b));yield return new NativeRoutineStep(0x69D4,"BD70C9",()=>m.WriteWord((ushort)(stack-2),0x69D7));yield return new NativeRoutineCall(0x70C9,0x69D7,initialY,(ushort)(stack-2),0x50);
        }
        yield return new NativeRoutineStep(0x69D7,"0F71",()=>m.Memory[0x71]=0);yield return new NativeRoutineStep(0x69D9,"108E0000");yield return new NativeRoutineStep(0x69DD,"109F3B",()=>m.WriteWord(0x3B,0));
        yield return new NativeRoutineStep(0x69E0,"7D03A6");bool more=m.Memory[0x3A6]!=0;yield return new NativeRoutineStep(0x69E3,"102601C0",Branch:more);if(more){yield return new NativeRoutineCall(0x6BA7,0x4C34,0,stack,0x50);yield break;}
        yield return new NativeRoutineStep(0x69E7,"7D0323");yield return new NativeRoutineStep(0x69EA,"2B11");if((sbyte)m.Memory[0x323]>=0){
            yield return new NativeRoutineStep(0x69EC,"7D0073");yield return new NativeRoutineStep(0x69EF,"270C");if(m.Memory[0x73]!=0){yield return new NativeRoutineStep(0x69F1,"C632",()=>b=50);yield return new NativeRoutineStep(0x69F3,"D77E",()=>m.Memory[0x7E]=b);yield return new NativeRoutineStep(0x69F5,"8607");yield return new NativeRoutineStep(0x69F7,"977C",()=>m.Memory[0x7C]=7);yield return new NativeRoutineStep(0x69F9,"0F80",()=>m.Memory[0x80]=0);yield return new NativeRoutineStep(0x69FB,"200B");yield return new NativeRoutineCall(0x6A08,0x4C34,0,stack,0x50);yield break;}}
        yield return new NativeRoutineStep(0x69FD,"39");
    }
    public Action<ushort,byte>? Write {get;init;}
}

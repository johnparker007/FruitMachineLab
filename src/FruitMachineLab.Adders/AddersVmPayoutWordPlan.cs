using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Selected80E4/80F4 word headers ->776F bridge -> native caller -> NEXT.
// The native bridge saves Y but does not invent an extra logical VM call frame.
public sealed class AddersVmPayoutWordPlan(Machine m,Instruction instruction,ushort stackPointer,byte initialConditionCode,Action<byte>? writeMode)
{
    private byte a;
    private bool zero;
    private ushort s=stackPointer;
    public ushort ResumeCursor {get;private set;}
    private void Mode(byte value)=>(writeMode ?? throw new NotSupportedException("Payout word080C mode write requires a hardware owner"))(value);
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        if(instruction.Native is not (0x4B39 or 0x4B8C) || m.ReadWord(instruction.Token)!=0x776F || m.ReadWord(Cell.Add(instruction.Token,2))!=instruction.Native)throw new NotSupportedException("Payout VM word/native header differs");
        if(m.ReadWord(0xFC)!=0xAEA1 || m.ReadWord(0xFE)!=0x6E91)throw new NotSupportedException("Payout word requires the original RAM NEXT template");
        yield return new NativeRoutineStep(0xFC,"AEA1");yield return new NativeRoutineStep(0xFE,"6E91");
        yield return new NativeRoutineStep(0x776F,"96F1",()=>{a=m.Memory[0xF1];zero=a==0;});yield return new NativeRoutineStep(0x7771,"2707");
        if(!zero){yield return new NativeRoutineStep(0x7773,"8A01",()=>a|=1);yield return new NativeRoutineStep(0x7775,"97F1",()=>m.Memory[0xF1]=a);yield return new NativeRoutineStep(0x7777,"B7080C",()=>Mode(a));}
        yield return new NativeRoutineStep(0x777A,"3420",()=>{s=Cell.Subtract(s,2);m.WriteWord(s,Cell.Add(instruction.Site,2));});
        yield return new NativeRoutineStep(0x777C,"AD94",()=>{s=Cell.Subtract(s,2);m.WriteWord(s,0x777E);});yield return new NativeRoutineCall(instruction.Native!.Value,0x777E,Cell.Add(instruction.Site,2),s,initialConditionCode);s=Cell.Add(s,2);
        yield return new NativeRoutineStep(0x777E,"3520",()=>{ResumeCursor=m.ReadWord(s);s=Cell.Add(s,2);if(ResumeCursor!=Cell.Add(instruction.Site,2))throw new NotSupportedException("Payout native bridge changed VM return cursor");});
        yield return new NativeRoutineStep(0x7780,"96F1",()=>{a=m.Memory[0xF1];zero=a==0;});yield return new NativeRoutineStep(0x7782,"2707");
        if(!zero){yield return new NativeRoutineStep(0x7784,"84FE",()=>a&=0xFE);yield return new NativeRoutineStep(0x7786,"97F1",()=>m.Memory[0xF1]=a);yield return new NativeRoutineStep(0x7788,"B7080C",()=>Mode(a));}
        yield return new NativeRoutineStep(0x778B,"0EFC");
    }
}

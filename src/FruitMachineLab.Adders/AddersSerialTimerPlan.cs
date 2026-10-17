using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Selected timer2 reset/arm helpers. Bus accesses are explicit byte operations;
// timer load MSB then LSB order follows MC6809 STY extended.
public sealed class AddersSerialTimerPlan(Machine m,ushort entry,ushort stack,ushort callback,ushort period,byte initialB,byte conditionCode,Func<ushort,byte> read,Action<ushort,byte> write)
{
    private byte b=initialB;public bool Masked {get;private set;}=(conditionCode&0x10)!=0;
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        if(entry is not (0x70C9 or 0x70D6))throw new NotSupportedException("Unrecovered serial timer helper");
        yield return new NativeRoutineStep(entry,"3405",()=>{m.Memory[stack-2]=conditionCode;m.Memory[stack-1]=b;});
        yield return new NativeRoutineStep((ushort)(entry+2),"1A50",()=>Masked=true);
        if(entry==0x70D6){
            yield return new NativeRoutineStep(0x70DA,"F60901",()=>b=read(0x901));yield return new NativeRoutineStep(0x70DD,"F60904",()=>b=read(0x904));yield return new NativeRoutineStep(0x70E0,"9F3B",()=>m.WriteWord(0x3B,callback));
            yield return new NativeRoutineStep(0x70E2,"C662",()=>b=0x62);yield return new NativeRoutineStep(0x70E4,"F70901",()=>write(0x901,b));yield return new NativeRoutineStep(0x70E7,"D73F",()=>m.Memory[0x3F]=b);
            yield return new NativeRoutineStep(0x70E9,"10BF0904",()=>{write(0x904,(byte)(period>>8));write(0x905,(byte)period);});yield return new NativeRoutineStep(0x70ED,"3585",()=>Masked=(conditionCode&0x10)!=0);
        }else{
            yield return new NativeRoutineStep(0x70CD,"C600",()=>b=0);yield return new NativeRoutineStep(0x70CF,"F70901",()=>write(0x901,b));yield return new NativeRoutineStep(0x70D2,"D73F",()=>m.Memory[0x3F]=b);yield return new NativeRoutineStep(0x70D4,"3585",()=>Masked=(conditionCode&0x10)!=0);
        }
    }
}

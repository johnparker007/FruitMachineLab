using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

// Native4C91, including A preservation across67EC/7032 and returned TSTA flags.
public sealed class AddersPayoutTailPlan(Machine m,ushort record)
{
    private byte a;
    private ushort x;
    private bool above,zero,carry;
    public byte ReturnFlags {get;private set;}
    public bool Allowed {get;private set;}
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        _=AddersPayoutRecord.Read(m,record);
        yield return new NativeRoutineStep(0x4C91,"3416");yield return new NativeRoutineStep(0x4C93,"AE21",()=>x=m.ReadWord(Cell.Add(record,1)));yield return new NativeRoutineStep(0x4C95,"A601",()=>a=m.Memory[Cell.Add(x,1)]);
        yield return new NativeRoutineStep(0x4C97,"30A4");yield return new NativeRoutineStep(0x4C99,"BD67EC");var input=new Mpu4InputConditionPlan(m,record);foreach(var op in input.Instructions())yield return op;
        yield return new NativeRoutineStep(0x4C9C,"2609");
        if(input.Zero){yield return new NativeRoutineStep(0x4C9E,"A124",()=>{above=a>m.Memory[record+4];carry=a<m.Memory[record+4];});yield return new NativeRoutineStep(0x4CA0,"2212");
            if(!above){yield return new NativeRoutineStep(0x4CA2,"A624",()=>a=m.Memory[record+4]);yield return new NativeRoutineStep(0x4CA4,"4C",()=>a++);yield return new NativeRoutineStep(0x4CA5,"2006");}}
        else{yield return new NativeRoutineStep(0x4CA7,"A124",()=>{above=a>m.Memory[record+4];carry=a<m.Memory[record+4];});yield return new NativeRoutineStep(0x4CA9,"2309");if(above)yield return new NativeRoutineStep(0x4CAB,"A624",()=>a=m.Memory[record+4]);}
        bool store=input.Zero ? !above : above;
        if(store){yield return new NativeRoutineStep(0x4CAD,"AE21",()=>x=m.ReadWord(Cell.Add(record,1)));yield return new NativeRoutineStep(0x4CAF,"A701",()=>m.Memory[Cell.Add(x,1)]=a);yield return new NativeRoutineStep(0x4CB1,"BD7032");foreach(var op in new Mpu4QueueChecksumPlan(m).Instructions())yield return op;}
        yield return new NativeRoutineStep(0x4CB4,"7DFF42",()=>zero=m.Memory[0xFF42]==0);yield return new NativeRoutineStep(0x4CB7,"2602");if(zero)yield return new NativeRoutineStep(0x4CB9,"86FF",()=>a=255);
        yield return new NativeRoutineStep(0x4CBB,"4D",()=>{Allowed=a!=0;ReturnFlags=(byte)((carry ? 1 : 0)|(a==0 ? 4 : 0)|((sbyte)a<0 ? 8 : 0));});yield return new NativeRoutineStep(0x4CBC,"3596");
    }
}

using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Selected4B8C/4CF8/4D45. Nonzero balance is deliberate: do not repair odd-value
// underflow into denomination coverage. Tail flush does not repeat compensation.
public sealed class AddersTokenPayoutPlan(Machine m,ushort nativeStack,byte initialConditionCode)
{
    private ushort s=nativeStack,y,d,x;
    private byte a;
    private bool zero;
    private void Push(ushort v){s=Cell.Subtract(s,2);m.WriteWord(s,v);}
    private void Pop()=>s=Cell.Add(s,2);
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        yield return new NativeRoutineStep(0x4B8C,"108E4AEC",()=>y=0x4AEC);yield return new NativeRoutineStep(0x4B90,"170165",()=>Push(0x4B93));foreach(var op in Record())yield return op;
        yield return new NativeRoutineStep(0x4B93,"108E4AFD",()=>y=0x4AFD);bool forced=true;
        foreach(var item in new (ushort At,ushort Port,string Bytes,ushort Branch,string Jump)[]{(0x4B97,0xFF48,"7DFF48",0x4B9A,"2720"),(0x4B9C,0xFF4A,"7DFF4A",0x4B9F,"271B"),(0x4BA1,0xFF40,"7DFF40",0x4BA4,"2716"),(0x4BA6,0xFF3C,"7DFF3C",0x4BA9,"2711"),(0x4BAB,0xFF3E,"7DFF3E",0x4BAE,"270C"),(0x4BB0,0xFF3A,"7DFF3A",0x4BB3,"2707")}){
            yield return new NativeRoutineStep(item.At,item.Bytes,()=>zero=m.Memory[item.Port]==0);yield return new NativeRoutineStep(item.Branch,item.Jump);if(zero){forced=false;break;}}
        if(forced){yield return new NativeRoutineStep(0x4BB5,"7DFF36",()=>zero=m.Memory[0xFF36]==0);yield return new NativeRoutineStep(0x4BB8,"10260189",Branch:!zero);forced=!zero;}
        if(!forced){yield return new NativeRoutineStep(0x4BBC,"170139",()=>Push(0x4BBF));foreach(var op in Record())yield return op;yield return new NativeRoutineStep(0x4BBF,"ECB805",()=>{d=m.ReadWord(m.ReadWord(Cell.Add(y,5)));zero=d==0;});yield return new NativeRoutineStep(0x4BC2,"26C5");if(!zero)throw new NotSupportedException("Native4B89/4BC5 token manager prompt remains unsupported");yield return new NativeRoutineStep(0x4BC4,"39",Pop);yield break;}
        while(true){yield return new NativeRoutineStep(0x4D45,"ECB805",()=>{d=m.ReadWord(m.ReadWord(Cell.Add(y,5)));zero=d==0;});yield return new NativeRoutineStep(0x4D48,"2729");if(zero){yield return new NativeRoutineStep(0x4D73,"39",Pop);yield break;}
            yield return new NativeRoutineStep(0x4D4A,"17FF71",()=>Push(0x4D4D));yield return new NativeRoutineCall(0x4CBE,0x4D4D,y,s,initialConditionCode);Pop();yield return new NativeRoutineStep(0x4D4D,"108C4AEC");foreach(var op in new AddersTokenCompensationPlan(m,0x4D51).Instructions())yield return op;yield return new NativeRoutineStep(0x4D71,"20D2");}
    }
    private IEnumerable<NativeRoutineWork> Condition(ushort at,string bytes){yield return new NativeRoutineStep(at,bytes);var p=new Mpu4InputConditionPlan(m,y);foreach(var op in p.Instructions())yield return op;zero=p.Zero;}
    private IEnumerable<NativeRoutineWork> Record()
    {
        yield return new NativeRoutineStep(0x4CF8,"30A4");foreach(var op in Condition(0x4CFA,"BD67EC"))yield return op;yield return new NativeRoutineStep(0x4CFD,"2645");if(!zero){yield return new NativeRoutineStep(0x4D44,"39",Pop);yield break;}
        while(true){yield return new NativeRoutineStep(0x4CFF,"ECB805",()=>{d=m.ReadWord(m.ReadWord(Cell.Add(y,5)));zero=d==0;});yield return new NativeRoutineStep(0x4D02,"2740");if(zero){yield return new NativeRoutineStep(0x4D44,"39",Pop);yield break;}
            yield return new NativeRoutineStep(0x4D04,"17FFB7",()=>Push(0x4D07));yield return new NativeRoutineCall(0x4CBE,0x4D07,y,s,initialConditionCode);Pop();foreach(var op in new AddersTokenCompensationPlan(m,0x4D07).Instructions())yield return op;
            yield return new NativeRoutineStep(0x4D27,"30A4");foreach(var op in Condition(0x4D29,"BD67EC"))yield return op;yield return new NativeRoutineStep(0x4D2C,"27D1");if(zero)continue;
            yield return new NativeRoutineStep(0x4D2E,"A624",()=>a=m.Memory[y+4]);yield return new NativeRoutineStep(0x4D30,"AE21",()=>x=m.ReadWord(Cell.Add(y,1)));yield return new NativeRoutineStep(0x4D32,"A701",()=>m.Memory[Cell.Add(x,1)]=a);break;
        }
        while(true){yield return new NativeRoutineStep(0x4D34,"AE21",()=>x=m.ReadWord(Cell.Add(y,1)));yield return new NativeRoutineStep(0x4D36,"6D01",()=>zero=m.Memory[Cell.Add(x,1)]==0);yield return new NativeRoutineStep(0x4D38,"270A");if(zero)break;
            yield return new NativeRoutineStep(0x4D3A,"ECB805",()=>{d=m.ReadWord(m.ReadWord(Cell.Add(y,5)));zero=d==0;});yield return new NativeRoutineStep(0x4D3D,"2705");if(zero)break;
            yield return new NativeRoutineStep(0x4D3F,"17FF7C",()=>Push(0x4D42));yield return new NativeRoutineCall(0x4CBE,0x4D42,y,s,initialConditionCode);Pop();yield return new NativeRoutineStep(0x4D42,"20F0");}
        yield return new NativeRoutineStep(0x4D44,"39",Pop);
    }
}

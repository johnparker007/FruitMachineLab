using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

// Selected4B39/4C25/4C7C caller. Each4CBE yields CPU ownership with its real
// native S return frame; the host composes the timed debit, never a semantic copy.
public sealed class AddersCashPayoutPlan(Machine m,ushort nativeStack,byte initialConditionCode)
{
    private ushort s=nativeStack,y,d;
    private byte cc=initialConditionCode;
    private bool zero,lowerOrSame,above;
    public ushort StackPointer=>s;
    private void Push(ushort value){s=Cell.Subtract(s,2);m.WriteWord(s,value);}
    private void Pop(){s=Cell.Add(s,2);}
    private void Compare(ushort left,ushort right){ushort result=Cell.Subtract(left,right);zero=result==0;above=left>right;lowerOrSame=left<=right;cc=(byte)((cc&0xF0)|(left<right ? 1 : 0)|(zero ? 4 : 0)|((short)result<0 ? 8 : 0)|(((left^right)&(left^result)&0x8000)!=0 ? 2 : 0));}
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        yield return new NativeRoutineStep(0x4B39,"BD67E2");var input=new Mpu4InputConditionPlan(m,0x4B3C);foreach(var op in input.Instructions(inline:true))yield return op;
        yield return new NativeRoutineStep(0x4B3D,"2607");
        if(input.Zero){yield return new NativeRoutineStep(0x4B3F,"108E4ADB",()=>y=0x4ADB);yield return new NativeRoutineStep(0x4B43,"1700DF",()=>Push(0x4B46));foreach(var op in Record())yield return op;}
        yield return new NativeRoutineStep(0x4B46,"108E4ACA",()=>y=0x4ACA);yield return new NativeRoutineStep(0x4B4A,"1700D8",()=>Push(0x4B4D));foreach(var op in Record())yield return op;
        yield return new NativeRoutineStep(0x4B4D,"8600",()=>zero=true);yield return new NativeRoutineStep(0x4B4F,"2708");
        bool forced=true;
        foreach(var item in new (ushort At,ushort Port,string Bytes,ushort Branch,string Jump)[]{(0x4B59,0xFF48,"7DFF48",0x4B5C,"2720"),(0x4B5E,0xFF4A,"7DFF4A",0x4B61,"271B"),(0x4B63,0xFF40,"7DFF40",0x4B66,"2716"),(0x4B68,0xFF3C,"7DFF3C",0x4B6B,"2711"),(0x4B6D,0xFF3E,"7DFF3E",0x4B70,"270C"),(0x4B72,0xFF3A,"7DFF3A",0x4B75,"2707")}){
            yield return new NativeRoutineStep(item.At,item.Bytes,()=>zero=m.Memory[item.Port]==0);yield return new NativeRoutineStep(item.Branch,item.Jump);if(zero){forced=false;break;}}
        if(forced){yield return new NativeRoutineStep(0x4B77,"7DFF36",()=>zero=m.Memory[0xFF36]==0);yield return new NativeRoutineStep(0x4B7A,"102600FE",Branch:!zero);forced=!zero;}
        if(!forced){yield return new NativeRoutineStep(0x4B7E,"FC02FE",()=>{d=m.ReadWord(0x2FE);zero=d==0;});yield return new NativeRoutineStep(0x4B81,"2705");if(!zero)throw new NotSupportedException("Native4BC5 manager payout prompt remains unsupported");yield return new NativeRoutineStep(0x4B88,"39",Pop);yield break;}
        yield return new NativeRoutineStep(0x4C7C,"E623",()=>d=m.Memory[y+3]);yield return new NativeRoutineStep(0x4C7E,"4F");
        while(true){yield return new NativeRoutineStep(0x4C7F,"10A3B805",()=>Compare(d,m.ReadWord(m.ReadWord(Cell.Add(y,5)))));yield return new NativeRoutineStep(0x4C83,"22A8");if(above){yield return new NativeRoutineStep(0x4C2D,"39",Pop);yield break;}
            yield return new NativeRoutineStep(0x4C85,"3406",()=>Push(d));yield return new NativeRoutineStep(0x4C87,"170034",()=>Push(0x4C8A));yield return new NativeRoutineCall(0x4CBE,0x4C8A,y,s,cc);Pop();
            yield return new NativeRoutineStep(0x4C8A,"3506",Pop);yield return new NativeRoutineStep(0x4C8C,"BD4C91");foreach(var op in Tail())yield return op;yield return new NativeRoutineStep(0x4C8F,"20EE");}
    }
    private IEnumerable<NativeRoutineWork> Tail(){var tail=new AddersPayoutTailPlan(m,y);foreach(var op in tail.Instructions())yield return op;cc=(byte)((cc&0xF0)|tail.ReturnFlags);zero=!tail.Allowed;}
    private IEnumerable<NativeRoutineWork> Record()
    {
        while(true){yield return new NativeRoutineStep(0x4C25,"4F");yield return new NativeRoutineStep(0x4C26,"E623",()=>d=m.Memory[y+3]);yield return new NativeRoutineStep(0x4C28,"A3B805",()=>{ushort before=d;Compare(before,m.ReadWord(m.ReadWord(Cell.Add(y,5))));d=Cell.Subtract(before,m.ReadWord(m.ReadWord(Cell.Add(y,5))));});yield return new NativeRoutineStep(0x4C2B,"23EC");
            if(!lowerOrSame){yield return new NativeRoutineStep(0x4C2D,"39",Pop);yield break;}
            yield return new NativeRoutineStep(0x4C19,"170075");foreach(var op in Tail())yield return op;yield return new NativeRoutineStep(0x4C1C,"270F");if(zero){yield return new NativeRoutineStep(0x4C2D,"39",Pop);yield break;}
            yield return new NativeRoutineStep(0x4C1E,"3406",()=>Push(d));yield return new NativeRoutineStep(0x4C20,"17009B",()=>Push(0x4C23));yield return new NativeRoutineCall(0x4CBE,0x4C23,y,s,cc);Pop();yield return new NativeRoutineStep(0x4C23,"3506",Pop);
        }
    }
}

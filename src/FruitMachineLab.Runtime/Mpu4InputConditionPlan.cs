namespace FruitMachineLab.Runtime;

// Native67EC, preserving its three distinct outcomes: no selected bit (Z),
// all requested bits (C), mixed (neither). Invalid selectors stop before SWI3.
public sealed class Mpu4InputConditionPlan(Machine machine,ushort selectorAddress)
{
    private byte b;
    private ushort x,y;
    private bool negative,above,zero;
    public bool Zero {get;private set;}
    public bool Carry {get;private set;}
    public ushort CellValue=>Zero ? (ushort)0 : Carry ? ushort.MaxValue : (ushort)1;
    public IEnumerable<NativeRoutineWork> Instructions(bool inline=false)
    {
        if(inline){yield return new NativeRoutineStep(0x67E2,"3434");yield return new NativeRoutineStep(0x67E4,"AE65");yield return new NativeRoutineStep(0x67E6,"E680",()=>b=machine.Memory[selectorAddress]);yield return new NativeRoutineStep(0x67E8,"AF65");yield return new NativeRoutineStep(0x67EA,"2004");}
        else{yield return new NativeRoutineStep(0x67EC,"3434");yield return new NativeRoutineStep(0x67EE,"E684",()=>b=machine.Memory[selectorAddress]);}
        yield return new NativeRoutineStep(0x67F0,"5D",()=>negative=(sbyte)b<0);yield return new NativeRoutineStep(0x67F1,"2B45");
        bool selected=false;
        if(negative){
            yield return new NativeRoutineStep(0x6838,"8E7226",()=>x=0x7226);yield return new NativeRoutineStep(0x683B,"58",()=>b=unchecked((byte)(b<<1)));yield return new NativeRoutineStep(0x683C,"3A",()=>x=Cell.Add(x,b));
            yield return new NativeRoutineStep(0x683D,"8C7248",()=>above=x>0x7248);yield return new NativeRoutineStep(0x6840,"2210");if(above)throw new NotSupportedException("Native6854 invalid input selector SWI3");
            yield return new NativeRoutineStep(0x6842,"F60006",()=>b=machine.Memory[6]);yield return new NativeRoutineStep(0x6845,"E584",()=>zero=(b&machine.Memory[x])==0);yield return new NativeRoutineStep(0x6847,"26E5");selected=!zero;
            if(!selected){yield return new NativeRoutineStep(0x6849,"F60007",()=>b=machine.Memory[7]);yield return new NativeRoutineStep(0x684C,"E501",()=>zero=(b&machine.Memory[Cell.Add(x,1)])==0);yield return new NativeRoutineStep(0x684E,"26DE");selected=!zero;}
            if(!selected)yield return new NativeRoutineStep(0x6850,"20BC");
        }else{
            yield return new NativeRoutineStep(0x67F3,"8E71AA",()=>x=0x71AA);yield return new NativeRoutineStep(0x67F6,"58",()=>b=unchecked((byte)(b<<1)));yield return new NativeRoutineStep(0x67F7,"58",()=>b=unchecked((byte)(b<<1)));yield return new NativeRoutineStep(0x67F8,"3A",()=>x=Cell.Add(x,b));
            yield return new NativeRoutineStep(0x67F9,"8C7226",()=>above=x>0x7226);yield return new NativeRoutineStep(0x67FC,"2254");if(above)throw new NotSupportedException("Native6854 invalid input selector SWI3");
            yield return new NativeRoutineStep(0x67FE,"108E0000",()=>y=0);
            while(true){yield return new NativeRoutineStep(0x6802,"E680",()=>{b=machine.Memory[x];x++;});yield return new NativeRoutineStep(0x6804,"E5A0",()=>{zero=(b&machine.Memory[y])==0;y++;});yield return new NativeRoutineStep(0x6806,"260C");
                if(!zero){selected=true;break;}yield return new NativeRoutineStep(0x6808,"108C0004",()=>zero=y==4);yield return new NativeRoutineStep(0x680C,"26F4");if(zero)break;}
            if(selected){
                while(true){yield return new NativeRoutineStep(0x6814,"108C0000",()=>zero=y==0);yield return new NativeRoutineStep(0x6818,"2706");if(zero)break;
                    yield return new NativeRoutineStep(0x681A,"313F",()=>y--);yield return new NativeRoutineStep(0x681C,"301F",()=>x--);yield return new NativeRoutineStep(0x681E,"20F4");}
                while(true){yield return new NativeRoutineStep(0x6820,"E6A0",()=>{b=machine.Memory[y];y++;});yield return new NativeRoutineStep(0x6822,"E484",()=>b&=machine.Memory[x]);yield return new NativeRoutineStep(0x6824,"E180",()=>{zero=b==machine.Memory[x];x++;});yield return new NativeRoutineStep(0x6826,"260C");
                    if(!zero){yield return new NativeRoutineStep(0x6834,"1CFA",()=>{Zero=false;Carry=false;});yield return new NativeRoutineStep(0x6836,"35B4");yield break;}
                    yield return new NativeRoutineStep(0x6828,"108C0004",()=>zero=y==4);yield return new NativeRoutineStep(0x682C,"26F2");if(zero)break;}
            }
        }
        if(selected){yield return new NativeRoutineStep(0x682E,"1CFA",()=>{Zero=false;Carry=false;});yield return new NativeRoutineStep(0x6830,"1A01",()=>Carry=true);yield return new NativeRoutineStep(0x6832,"35B4");}
        else{yield return new NativeRoutineStep(0x680E,"1CFA",()=>{Zero=false;Carry=false;});yield return new NativeRoutineStep(0x6810,"1A04",()=>Zero=true);yield return new NativeRoutineStep(0x6812,"35B4");}
    }
}

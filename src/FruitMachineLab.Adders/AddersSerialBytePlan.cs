using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public sealed class AddersSerialBytePlan(Machine m,ushort stack,ushort initialX,ushort initialY,byte initialA,byte value,Func<ushort,byte> read,Action<ushort,byte> write)
{
    private ushort s=stack,x=initialX;private byte a=initialA,b=value;private bool carry;
    private IEnumerable<NativeRoutineWork> Bit(ushort site,string bytes,ushort next)
    {
        yield return new NativeRoutineStep(site,bytes,()=>{s-=2;m.WriteWord(s,next);});
        var p=new AddersSerialBitPlan(m,a,read);foreach(var op in p.Instructions())yield return op;a=p.A;x=p.X;s+=2;
    }
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        yield return new NativeRoutineStep(0x693E,"3436",()=>{s-=6;m.WriteWord(s,(ushort)((a<<8)|b));m.WriteWord((ushort)(s+2),x);m.WriteWord((ushort)(s+4),initialY);});
        bool busy;do{busy=false;yield return new NativeRoutineStep(0x6940,"0D71",()=>busy=m.Memory[0x71]!=0);yield return new NativeRoutineStep(0x6942,"26FC");if(busy)throw new NotSupportedException("Serial byte starts while previous transmission remains busy");}while(busy);
        yield return new NativeRoutineStep(0x6944,"0371",()=>m.Memory[0x71]=(byte)~m.Memory[0x71]);yield return new NativeRoutineStep(0x6946,"B60B03",()=>a=read(0xB03));yield return new NativeRoutineStep(0x6949,"84FE",()=>a&=0xFE);yield return new NativeRoutineStep(0x694B,"B70B03",()=>write(0xB03,a));
        yield return new NativeRoutineStep(0x694E,"8E0000",()=>x=0);yield return new NativeRoutineStep(0x6951,"9F81",()=>m.WriteWord(0x81,x));yield return new NativeRoutineStep(0x6953,"1F98",()=>a=b);yield return new NativeRoutineStep(0x6955,"8E037C",()=>x=0x37C);
        yield return new NativeRoutineStep(0x6958,"9776",()=>m.Memory[0x76]=a);yield return new NativeRoutineStep(0x695A,"9777",()=>m.Memory[0x77]=a);yield return new NativeRoutineStep(0x695C,"9F78",()=>m.WriteWord(0x78,x));yield return new NativeRoutineStep(0x695E,"9F42",()=>m.WriteWord(0x42,x));
        yield return new NativeRoutineStep(0x6960,"4F",()=>a=0);foreach(var op in Bit(0x6961,"8D46",0x6963))yield return op;
        yield return new NativeRoutineStep(0x6963,"C607",()=>b=7);
        do{yield return new NativeRoutineStep(0x6965,"4F",()=>a=0);yield return new NativeRoutineStep(0x6966,"0477",()=>{carry=(m.Memory[0x77]&1)!=0;m.Memory[0x77]>>=1;});yield return new NativeRoutineStep(0x6968,"49",()=>a=(byte)((a<<1)|(carry ? 1 : 0)));foreach(var op in Bit(0x6969,"8D3E",0x696B))yield return op;yield return new NativeRoutineStep(0x696B,"5A",()=>b--);yield return new NativeRoutineStep(0x696C,"26F7");}while(b!=0);
        yield return new NativeRoutineStep(0x696E,"F6038E",()=>b=m.Memory[0x38E]);yield return new NativeRoutineStep(0x6971,"C508");yield return new NativeRoutineStep(0x6973,"2706");
        if((b&8)!=0){yield return new NativeRoutineStep(0x6975,"4F",()=>a=0);yield return new NativeRoutineStep(0x6976,"0477",()=>{carry=(m.Memory[0x77]&1)!=0;m.Memory[0x77]>>=1;});yield return new NativeRoutineStep(0x6978,"49",()=>a=(byte)((a<<1)|(carry ? 1 : 0)));foreach(var op in Bit(0x6979,"8D2E",0x697B))yield return op;}
        yield return new NativeRoutineStep(0x697B,"F6038E",()=>b=m.Memory[0x38E]);yield return new NativeRoutineStep(0x697E,"C504");yield return new NativeRoutineStep(0x6980,"2710");
        if((b&4)!=0){
            yield return new NativeRoutineStep(0x6982,"D676",()=>b=m.Memory[0x76]);yield return new NativeRoutineStep(0x6984,"4F",()=>a=0);
            do{yield return new NativeRoutineStep(0x6985,"58",()=>{carry=(b&0x80)!=0;b<<=1;});yield return new NativeRoutineStep(0x6986,"8900",()=>a+=(byte)(carry ? 1 : 0));yield return new NativeRoutineStep(0x6988,"5D");yield return new NativeRoutineStep(0x6989,"26FA");}while(b!=0);
            yield return new NativeRoutineStep(0x698B,"B8038E",()=>a^=m.Memory[0x38E]);yield return new NativeRoutineStep(0x698E,"8401",()=>a&=1);foreach(var op in Bit(0x6990,"8D17",0x6992))yield return op;
        }
        yield return new NativeRoutineStep(0x6992,"F6038E",()=>b=m.Memory[0x38E]);yield return new NativeRoutineStep(0x6995,"8601",()=>a=1);foreach(var op in Bit(0x6997,"8D10",0x6999))yield return op;yield return new NativeRoutineStep(0x6999,"C502");yield return new NativeRoutineStep(0x699B,"2704");
        if((b&2)!=0){yield return new NativeRoutineStep(0x699D,"8601",()=>a=1);foreach(var op in Bit(0x699F,"8D08",0x69A1))yield return op;}
        yield return new NativeRoutineStep(0x69A1,"86FF",()=>a=255);foreach(var op in Bit(0x69A3,"8D04",0x69A5))yield return op;
        yield return new NativeRoutineStep(0x69A5,"8D57",()=>{s-=2;m.WriteWord(s,0x69A7);});yield return new NativeRoutineCall(0x69FE,0x69A7,initialY,s,0x50);
        yield return new NativeRoutineStep(0x69A7,"35B6");
    }
}

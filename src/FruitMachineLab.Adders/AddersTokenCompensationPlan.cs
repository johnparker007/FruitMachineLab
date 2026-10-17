using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// The two original compensation tails share bytes but retain distinct PCs.
public sealed class AddersTokenCompensationPlan(Machine m,ushort entry)
{
    private byte a,b,scratch;
    private ushort d,x;
    private bool borrow,overflow,negative,lower;
    private NativeRoutineStep At(int offset,string bytes,Action? effect=null)=>new(Cell.Add(entry,(ushort)offset),bytes,effect);
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        if(entry is not (0x4D07 or 0x4D51))throw new NotSupportedException("Unknown token compensation entry");
        yield return At(0,"C6FF",()=>b=255);yield return At(2,"F7002C",()=>m.Memory[0x2C]=b);yield return At(5,"FC07D3",()=>d=m.ReadWord(0x7D3));
        yield return At(8,"8301F4",()=>{borrow=d<500;d=Cell.Subtract(d,500);});yield return At(11,"FD07D3",()=>m.WriteWord(0x7D3,d));yield return At(14,"B607D2",()=>a=m.Memory[0x7D2]);
        yield return At(17,"8200",()=>{byte before=a;a=unchecked((byte)(a-(borrow ? 1 : 0)));overflow=before==0x80 && borrow;});yield return At(19,"2802");
        if(overflow)yield return At(21,"8680",()=>a=0x80);yield return At(23,"B707D2",()=>m.Memory[0x7D2]=a);
        yield return At(26,"BD6F57");foreach(var op in Accounting())yield return op;yield return At(29,"7F002C",()=>m.Memory[0x2C]=0);
    }
    private IEnumerable<NativeRoutineWork> Accounting()
    {
        yield return new NativeRoutineStep(0x6F57,"7D0323",()=>negative=(sbyte)m.Memory[0x323]<0);yield return new NativeRoutineStep(0x6F5A,"2BF5");if(negative){yield return new NativeRoutineStep(0x6F51,"39");yield break;}
        yield return new NativeRoutineStep(0x6F5C,"8E07C9",()=>x=0x7C9);yield return new NativeRoutineStep(0x6F5F,"5F",()=>b=0);yield return new NativeRoutineStep(0x6F60,"200E");
        while(true){yield return new NativeRoutineStep(0x6F70,"8C07D8",()=>lower=x<0x7D8);yield return new NativeRoutineStep(0x6F73,"25ED");if(!lower)break;
            yield return new NativeRoutineStep(0x6F62,"A684",()=>a=m.Memory[x]);yield return new NativeRoutineStep(0x6F64,"43",()=>a=unchecked((byte)~a));yield return new NativeRoutineStep(0x6F65,"3402",()=>scratch=a);
            yield return new NativeRoutineStep(0x6F67,"A789000F",()=>m.Memory[Cell.Add(x,15)]=a);yield return new NativeRoutineStep(0x6F6B,"3001",()=>x++);yield return new NativeRoutineStep(0x6F6D,"EBE0",()=>b=unchecked((byte)(b+scratch)));yield return new NativeRoutineStep(0x6F6F,"5A",()=>b--);}
        yield return new NativeRoutineStep(0x6F75,"F707E7",()=>m.Memory[0x7E7]=b);yield return new NativeRoutineStep(0x6F78,"39");
    }
}

namespace FruitMachineLab.Runtime;

// Selected7032/7009. Caller registers/CC are saved by the original wrapper;
// this flat plan owns only its local operands and the observable RAM stores.
public sealed class Mpu4QueueChecksumPlan(Machine machine)
{
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        byte b=0,guard=0;ushort x=0;bool lower=false;
        yield return new NativeRoutineStep(0x7032,"3417");yield return new NativeRoutineStep(0x7034,"F6002C",()=>b=machine.Memory[0x2C]);yield return new NativeRoutineStep(0x7037,"3404",()=>guard=b);
        yield return new NativeRoutineStep(0x7039,"C601",()=>b=1);yield return new NativeRoutineStep(0x703B,"F7002C",()=>machine.Memory[0x2C]=b);yield return new NativeRoutineStep(0x703E,"8DC9");
        yield return new NativeRoutineStep(0x7009,"8E036B",()=>x=0x36B);yield return new NativeRoutineStep(0x700C,"5F",()=>b=0);yield return new NativeRoutineStep(0x700D,"2003");
        while(true){yield return new NativeRoutineStep(0x7012,"8C0373",()=>lower=x<0x373);yield return new NativeRoutineStep(0x7015,"25F8");if(!lower)break;
            yield return new NativeRoutineStep(0x700F,"EB80",()=>{b=unchecked((byte)(b+machine.Memory[x]));x++;});yield return new NativeRoutineStep(0x7011,"5C",()=>b++);}
        yield return new NativeRoutineStep(0x7017,"5C",()=>b++);yield return new NativeRoutineStep(0x7018,"39");yield return new NativeRoutineStep(0x7040,"E784",()=>machine.Memory[x]=b);
        yield return new NativeRoutineStep(0x7042,"3504",()=>b=guard);yield return new NativeRoutineStep(0x7044,"F7002C",()=>machine.Memory[0x2C]=b);yield return new NativeRoutineStep(0x7047,"3597");
    }
}

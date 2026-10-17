namespace FruitMachineLab.Runtime;

// Selected6858 suffix68A0..68C9, including7172/718A polling. The caller owns
// queue/debit/serial predecessors and native save-frame RAM. No recorded timing.
public sealed class Mpu4PayoutPulseExecution : IDisposable
{
    private sealed record Step(ushort Address,string Bytes,Action? Effect=null);
    private readonly Machine m;
    private readonly Func<byte> readPort;
    private readonly Action<byte> writePort;
    private readonly IEnumerator<Step> steps;
    private Step? pending;
    private byte a,b,savedMask,group,abort,interruptMask,savedInterruptMask;
    private bool zero;
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle {get;private set;}
    public bool Completed {get;private set;}
    public ushort Address=>pending?.Address ?? 0x685A;
    public bool IrqMasked=>(interruptMask&0x10)!=0;
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}
    public Action<OutputScanAccess>? ObserveAccess {get;set;}
    public Mpu4PayoutPulseExecution(Machine machine,ulong start,byte mask,byte initialInterruptMask,
        Func<byte> readTriac,Action<byte> writeTriac)
    {
        m=machine;Cycle=start;a=mask;interruptMask=(byte)(initialInterruptMask&0x50);
        readPort=readTriac;writePort=writeTriac;steps=Run().GetEnumerator();Next();
    }
    private static ulong Cost(Step s)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(s.Bytes)).Cycles;
    private void Next(){if(!steps.MoveNext()){Completed=true;pending=null;NextEventCycle=ulong.MaxValue;return;}pending=steps.Current;NextEventCycle=checked(Cycle+Cost(pending));}
    public void AdvanceTo(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        while(!Completed && NextEventCycle<=cycle){var s=pending!;ulong from=NextEventCycle-Cost(s);Cycle=NextEventCycle;s.Effect?.Invoke();ObserveInstruction?.Invoke(new(s.Address,s.Bytes,from,Cycle));Next();}
        Cycle=cycle;
    }
    public void SuspendUntil(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        if(IrqMasked)throw new InvalidOperationException("IRQ cannot suspend masked payout write section");
        if(!Completed){if(NextEventCycle-Cycle!=Cost(pending!))throw new InvalidOperationException("Suspension requires an instruction boundary");NextEventCycle=checked(NextEventCycle+cycle-Cycle);}
        Cycle=cycle;
    }
    private byte Read(){byte value=readPort();ObserveAccess?.Invoke(new(Cycle,0xF02,value,false,true));return value;}
    private void Write(){writePort(a);ObserveAccess?.Invoke(new(Cycle,0xF02,a,true,true));}
    private IEnumerable<Step> Run()
    {
        yield return new(0x68A0,"3526");
        yield return new(0x68A2,"3402",()=>savedMask=a);
        yield return new(0x68A4,"3401",()=>savedInterruptMask=interruptMask);
        yield return new(0x68A6,"1A50",()=>interruptMask|=0x50);
        yield return new(0x68A8,"BA0F02",()=>a|=Read());yield return new(0x68AB,"B70F02",Write);
        yield return new(0x68AE,"3501",()=>interruptMask=savedInterruptMask);
        yield return new(0x68B0,"C60D",()=>b=13);yield return new(0x68B2,"BD7172");
        foreach(var s in Wait())yield return s;
        yield return new(0x68B5,"3502",()=>a=savedMask);yield return new(0x68B7,"43",()=>a=unchecked((byte)~a));
        yield return new(0x68B8,"3401",()=>savedInterruptMask=interruptMask);
        yield return new(0x68BA,"1A50",()=>interruptMask|=0x50);
        yield return new(0x68BC,"B40F02",()=>a&=Read());yield return new(0x68BF,"B70F02",Write);
        yield return new(0x68C2,"3501",()=>interruptMask=savedInterruptMask);
        yield return new(0x68C4,"C60D",()=>b=13);yield return new(0x68C6,"BD7172");
        foreach(var s in Wait())yield return s;
        yield return new(0x68C9,"208F");
    }
    private IEnumerable<Step> Wait()
    {
        yield return new(0x7172,"8D16");yield return new(0x718A,"3404");
        yield return new(0x718C,"F6719B",()=>abort=m.Memory[0x719B]);yield return new(0x718F,"C580");yield return new(0x7191,"2602");
        if((abort&0x80)!=0){yield return new(0x7195,"3504");yield return new(0x7197,"3262");yield return new(0x7199,"39");yield break;}
        yield return new(0x7193,"3584");byte savedA=a,savedB=b;
        yield return new(0x7174,"3406");
        do {
            yield return new(0x7176,"3404",()=>group=b);yield return new(0x7178,"C605",()=>b=5);
            do {
                yield return new(0x717A,"966E",()=>a=m.Memory[0x6E]);
                do {yield return new(0x717C,"916E",()=>zero=a==m.Memory[0x6E]);yield return new(0x717E,"27FC");}while(zero);
                yield return new(0x7180,"5A",()=>b--);yield return new(0x7181,"26F7");
            }while(b!=0);
            yield return new(0x7183,"3504",()=>b=group);yield return new(0x7185,"5A",()=>b--);yield return new(0x7186,"26EE");
        }while(b!=0);
        yield return new(0x7188,"3586",()=>{a=savedA;b=savedB;});
    }
    public void Dispose()=>steps.Dispose();
}

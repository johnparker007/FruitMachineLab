namespace FruitMachineLab.Runtime;

// Bounded original-ROM continuation43E9. Executes the idle validation path and
// nine-byte coin records; active pulse/alarm/service branches remain explicit
// continuations. Optional service composes4592 through4395. Entry A is the
// caller's restored register, not an implicit RAM2A read.
public sealed class Mpu4CoinIdleExecution : IDisposable
{
    private sealed record Step(ushort Address,string Bytes,Action? Effect=null,bool? Branch=null);
    private readonly Machine m;
    private readonly IEnumerator<Step> steps;
    private Step? pending;
    private byte a,b;
    private ushort x,y;
    private readonly bool continueService;
    private readonly Func<ushort,byte>? readPort;
    private readonly Action<ushort,byte>? writePort;
    private Mpu4CoinServiceExecution? service;
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle {get;private set;}
    public bool Completed {get;private set;}
    public ushort Continuation {get;private set;}
    public ushort Address=>pending?.Address ?? Continuation;
    public OutputScanInstruction PendingInstruction=>pending is null ? throw new InvalidOperationException("Coin idle completed") : new(pending.Address,pending.Bytes,NextEventCycle-Cost(pending),NextEventCycle);
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}
    public Mpu4CoinIdleExecution(Machine machine,ulong start,byte entryA,bool continueService=false,Func<ushort,byte>? readPort=null,Action<ushort,byte>? writePort=null){m=machine;a=entryA;this.continueService=continueService;this.readPort=readPort;this.writePort=writePort;Cycle=start;steps=Run().GetEnumerator();Next();}
    private static ulong Cost(Step s)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(s.Bytes),s.Branch).Cycles;
    private void Next(){if(!steps.MoveNext()){Completed=true;pending=null;NextEventCycle=ulong.MaxValue;return;}pending=steps.Current;NextEventCycle=checked(Cycle+Cost(pending));}
    public void AdvanceTo(ulong cycle){if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));while(!Completed && NextEventCycle<=cycle){var s=pending!;ulong from=NextEventCycle-Cost(s);Cycle=NextEventCycle;s.Effect?.Invoke();ObserveInstruction?.Invoke(new(s.Address,s.Bytes,from,Cycle));Next();}Cycle=cycle;}
    public void SuspendUntil(ulong cycle){if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));if(!Completed){if(NextEventCycle-Cycle!=Cost(pending!))throw new InvalidOperationException("IRQ suspension requires an instruction boundary");service?.SuspendUntil(cycle);NextEventCycle=checked(NextEventCycle+(cycle-Cycle));}Cycle=cycle;}
    private IEnumerable<Step> Run()
    {
        yield return new(0x43E9,"108E0010",()=>y=0x10);yield return new(0x43ED,"D68A",()=>b=m.Memory[0x8A]);yield return new(0x43EF,"2718");
        if(b!=0){Continuation=0x43F1;yield break;}
        yield return new(0x4409,"8502");yield return new(0x440B,"2619");if((a&2)!=0){Continuation=0x4426;yield break;}
        yield return new(0x440D,"8504");bool rejected=(a&4)!=0;yield return new(0x440F,"10260098",Branch:rejected);if(rejected){Continuation=0x44AB;yield break;}
        yield return new(0x4413,"6FA4",()=>m.Memory[y]=0);yield return new(0x4415,"6F21",()=>m.Memory[Cell.Add(y,1)]=0);yield return new(0x4417,"0F8B",()=>m.Memory[0x8B]=0);yield return new(0x4419,"0FDF",()=>m.Memory[0xDF]=0);yield return new(0x441B,"5F",()=>b=0);yield return new(0x441C,"2079");
        yield return new(0x4497,"D78A",()=>m.Memory[0x8A]=b);yield return new(0x4499,"E6A4",()=>b=m.Memory[y]);yield return new(0x449B,"C150");yield return new(0x449D,"220C");
        if(b>0x50){Continuation=0x44AB;yield break;}
        yield return new(0x449F,"E621",()=>b=m.Memory[Cell.Add(y,1)]);yield return new(0x44A1,"C150");yield return new(0x44A3,"2206");if(b>0x50){Continuation=0x44AB;yield break;}
        yield return new(0x44A5,"D68B",()=>b=m.Memory[0x8B]);yield return new(0x44A7,"C113");yield return new(0x44A9,"2312");if(b>0x13){Continuation=0x44AB;yield break;}
        yield return new(0x44BD,"962A",()=>a=m.Memory[0x2A]);yield return new(0x44BF,"84F9",()=>a&=0xF9);yield return new(0x44C1,"972A",()=>m.Memory[0x2A]=a);
        yield return new(0x44C3,"8E40E9",()=>x=0x40E9);yield return new(0x44C6,"108E0012",()=>y=0x12);
        while(true){
            yield return new(0x44CA,"E608",()=>b=m.Memory[Cell.Add(x,8)]);yield return new(0x44CC,"C1F0");yield return new(0x44CE,"260A");
            if(b==0xF0){yield return new(0x44D0,"D42A",()=>b&=m.Memory[0x2A]);yield return new(0x44D2,"E108");bool active=b==m.Memory[Cell.Add(x,8)];yield return new(0x44D4,"1027008A",Branch:active);if(active){Continuation=0x4562;yield break;}yield return new(0x44D8,"2036");}
            else{yield return new(0x44DA,"962A",()=>a=m.Memory[0x2A]);yield return new(0x44DC,"84F0",()=>a&=0xF0);yield return new(0x44DE,"81F0");bool all=a==0xF0;yield return new(0x44E0,"102700A3",Branch:all);if(all){foreach(var s in NextRecord())yield return s;if(x==0x4128)break;continue;}yield return new(0x44E4,"D52A");yield return new(0x44E6,"267A");if((b&m.Memory[0x2A])!=0){Continuation=0x4562;yield break;}yield return new(0x44E8,"2026");}
            yield return new(0x4510,"A6A4",()=>a=m.Memory[y]);yield return new(0x4512,"2B73");if((a&0x80)==0){yield return new(0x4514,"6FA4",()=>m.Memory[y]=0);yield return new(0x4516,"4D");yield return new(0x4517,"2F6E");if(a>0){Continuation=0x4519;yield break;}}
            foreach(var s in NextRecord())yield return s;if(x==0x4128)break;
        }
        Continuation=0x4592;
        if(continueService){using var child=new Mpu4CoinServiceExecution(m,Cycle,readPort ?? throw new NotSupportedException("Coin service requires actual PIA reads"),writePort ?? throw new NotSupportedException("Coin service requires actual PIA writes"));service=child;while(!child.Completed){var s=child.PendingInstruction;yield return new(s.Address,s.Bytes,()=>child.AdvanceTo(Cycle),s.Bytes.StartsWith("102",StringComparison.Ordinal) ? s.Completed-s.Started==6 : null);}service=null;Continuation=child.Continuation;}
    }
    private IEnumerable<Step> NextRecord(){yield return new(0x4587,"3009",()=>x=Cell.Add(x,9));yield return new(0x4589,"3121",()=>y=Cell.Add(y,1));yield return new(0x458B,"8C4128");yield return new(0x458E,"1026FF38",Branch:x!=0x4128);}
    public void Dispose()=>steps.Dispose();
}

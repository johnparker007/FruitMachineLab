namespace FruitMachineLab.Runtime;

// Selected FEBA wrapper and27D2 input/drive prefix. Ends at438C entry;
// 4167 dispatch and the remaining service are explicit continuation boundaries.
// No CPU interpreter or captured instruction stream is used.
public sealed class Mpu4InputServiceExecution : IDisposable
{
    private sealed record Step(ushort Address,string Bytes,Action? Effect=null);
    private readonly Machine m;
    private readonly Func<byte,byte> readPort;
    private readonly IEnumerator<Step> steps;
    private Step? pending;
    private byte a,b;
    private ushort x;
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle {get;private set;}
    public bool Completed {get;private set;}
    public ushort Address=>pending?.Address ?? Continuation;
    public ushort Continuation {get;private set;}
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}
    public Action<OutputScanAccess>? ObserveAccess {get;set;}
    public Mpu4InputServiceExecution(Machine machine,ulong start,Func<byte,byte> readPort)
    {m=machine;this.readPort=readPort;Cycle=start;steps=Run().GetEnumerator();Next();}
    private void Next()
    {
        if(!steps.MoveNext()){pending=null;Completed=true;NextEventCycle=ulong.MaxValue;return;}
        pending=steps.Current;NextEventCycle=checked(Cycle+(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(pending.Bytes)).Cycles);
    }
    public void AdvanceTo(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        while(!Completed && NextEventCycle<=cycle){var step=pending!;ulong from=NextEventCycle-(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(step.Bytes)).Cycles;Cycle=NextEventCycle;step.Effect?.Invoke();ObserveInstruction?.Invoke(new(step.Address,step.Bytes,from,Cycle));Next();}
        Cycle=cycle;
    }
    public void SuspendUntil(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        if(!Completed){ulong cost=(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(pending!.Bytes)).Cycles;if(NextEventCycle-Cycle!=cost)throw new InvalidOperationException("IRQ suspension requires an instruction boundary");NextEventCycle=checked(NextEventCycle+(cycle-Cycle));}Cycle=cycle;
    }
    private void Put(ushort address,byte value){m.Memory[address]=value;ObserveAccess?.Invoke(new(Cycle,address,value,true,false));}
    private void Drive(ushort address,byte value)=>ObserveAccess?.Invoke(new(Cycle,address,value,true,true));
    private IEnumerable<Step> Run()
    {
        yield return new(0xFEBA,"0D2C");bool busy=m.Memory[0x2C]!=0;yield return new(0xFEBC,"2610");
        if(busy){Continuation=0xFECE;yield break;}
        yield return new(0xFEBE,"032C",()=>Put(0x2C,(byte)~m.Memory[0x2C]));yield return new(0xFEC0,"BD27D2");
        yield return new(0x27D2,"0C6E",()=>Put(0x6E,unchecked((byte)(m.Memory[0x6E]+1))));yield return new(0x27D4,"0D6C");bool active=m.Memory[0x6C]!=0;yield return new(0x27D6,"260A");
        bool zero=false;if(!active){yield return new(0x27D8,"966E",()=>a=m.Memory[0x6E]);yield return new(0x27DA,"46");zero=(a&1)!=0;yield return new(0x27DB,"2405");if(zero){yield return new(0x27DD,"CC0000",()=>{a=0;b=0;});yield return new(0x27E0,"2002");}}
        if(!zero)yield return new(0x27E2,"DC6F",()=>{a=m.Memory[0x6F];b=m.Memory[0x70];});
        yield return new(0x27E4,"B70D02",()=>Drive(0xD02,a));yield return new(0x27E7,"F70E00",()=>Drive(0xE00,b));yield return new(0x27EA,"9E28",()=>x=m.ReadWord(0x28));
        yield return new(0x27EC,"B60F00",()=>{if(x>7)throw new NotSupportedException("Input service requires a recovered mux column0..7");a=readPort((byte)x);ObserveAccess?.Invoke(new(Cycle,0xF00,a,false,true));});
        yield return new(0x27EF,"A7890000",()=>Put(x,a));yield return new(0x27F3,"8C0001");yield return new(0x27F6,"2206");
        if(x<=1){yield return new(0x27F8,"3004",()=>x=Cell.Add(x,4));yield return new(0x27FA,"A7890000",()=>Put(x,a));}
        yield return new(0x27FE,"7D032F");bool alternate=m.Memory[0x32F]!=0;yield return new(0x2801,"2706");
        if(alternate){yield return new(0x2803,"BD4167");Continuation=0x4167;}
        else{yield return new(0x2809,"BD438C");Continuation=0x438C;}
    }
    public void Dispose()=>steps.Dispose();
}

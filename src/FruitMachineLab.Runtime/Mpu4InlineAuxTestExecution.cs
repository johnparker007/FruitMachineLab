namespace FruitMachineLab.Runtime;

//46D3 consumes one inline byte through the saved return PC. A/B/X are restored;
// the caller observes N/Z from the final AND, V=0 and C=0, not an A return value.
// Native S-stack bytes and unrelated CC bits are not simulated here.
public sealed class Mpu4InlineAuxTestExecution : IDisposable
{
    private sealed record Step(ushort Address,string Bytes,Action? Effect=null);
    private readonly Machine m;
    private readonly byte inline;
    private readonly IEnumerator<Step> steps;
    private Step? pending;
    private byte b,a;
    private ushort x;
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle {get;private set;}
    public bool Completed {get;private set;}
    public OutputScanInstruction PendingInstruction=>pending is null ? throw new InvalidOperationException("Auxiliary test completed") : new(pending.Address,pending.Bytes,NextEventCycle-(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(pending.Bytes)).Cycles,NextEventCycle);
    public ushort ReturnAddress {get;private set;}
    public bool Zero=>a==0;
    public bool Negative=>(a&0x80)!=0;
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}
    public Mpu4InlineAuxTestExecution(Machine machine,ulong start,byte inlineMask,ushort savedReturnAddress)
    {m=machine;Cycle=start;inline=inlineMask;ReturnAddress=savedReturnAddress;steps=Run().GetEnumerator();Next();}
    private void Next(){if(!steps.MoveNext()){Completed=true;pending=null;NextEventCycle=ulong.MaxValue;return;}pending=steps.Current;NextEventCycle=checked(Cycle+(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(pending.Bytes)).Cycles);}
    public void AdvanceTo(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        while(!Completed && NextEventCycle<=cycle){var step=pending!;ulong from=NextEventCycle-(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(step.Bytes)).Cycles;Cycle=NextEventCycle;step.Effect?.Invoke();ObserveInstruction?.Invoke(new(step.Address,step.Bytes,from,Cycle));Next();}Cycle=cycle;
    }
    public void SuspendUntil(ulong resumeCycle)
    {
        if(resumeCycle<Cycle)throw new ArgumentOutOfRangeException(nameof(resumeCycle));
        if(!Completed){ulong cost=(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(pending!.Bytes)).Cycles;if(NextEventCycle-Cycle!=cost)throw new InvalidOperationException("IRQ suspension requires an instruction boundary");NextEventCycle=checked(NextEventCycle+(resumeCycle-Cycle));}Cycle=resumeCycle;
    }
    private IEnumerable<Step> Run()
    {
        yield return new(0x46D3,"3416");yield return new(0x46D5,"AE64");yield return new(0x46D7,"E680",()=>b=inline);yield return new(0x46D9,"AF64",()=>ReturnAddress=Cell.Add(ReturnAddress,1));yield return new(0x46DB,"C47F",()=>b&=0x7F);yield return new(0x46DD,"8E7226",()=>x=0x7226);yield return new(0x46E0,"58",()=>b<<=1);yield return new(0x46E1,"A685",()=>a=m.Memory[Cell.Add(x,unchecked((ushort)(short)(sbyte)b))]);yield return new(0x46E3,"B40006",()=>a&=m.Memory[6]);yield return new(0x46E6,"2607");
        if(a==0){yield return new(0x46E8,"3001",()=>x=Cell.Add(x,1));yield return new(0x46EA,"A685",()=>a=m.Memory[Cell.Add(x,unchecked((ushort)(short)(sbyte)b))]);yield return new(0x46EC,"B40007",()=>a&=m.Memory[7]);}
        yield return new(0x46EF,"3596");
    }
    public void Dispose()=>steps.Dispose();
}

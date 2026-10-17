namespace FruitMachineLab.Runtime;

// A clock for explicit translated instruction plans. This does not decode or
// execute CPU semantics: each recovered routine supplies its own effects/flow.
public abstract record NativeRoutineWork;
public sealed record NativeRoutineStep(ushort Address,string Bytes,Action? Effect=null,bool? Branch=null):NativeRoutineWork;
public sealed record NativeRoutineCall(ushort Entry,ushort Continuation,ushort Y,ushort S,byte ConditionCode):NativeRoutineWork;

public sealed class NativeRoutineExecution : IDisposable
{
    private readonly IEnumerator<NativeRoutineWork> plan;
    private readonly Func<bool> irqMasked;
    private NativeRoutineStep? pending;
    private readonly ushort continuation;
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle {get;private set;}
    public ushort Address=>pending?.Address ?? Call?.Entry ?? continuation;
    public bool Completed {get;private set;}
    public string? Fault {get;private set;}
    public NativeRoutineCall? Call {get;private set;}
    public bool IrqMasked=>irqMasked();
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}
    public NativeRoutineExecution(IEnumerable<NativeRoutineWork> instructions,ulong start,ushort returnAddress,Func<bool> masked)
    {Cycle=start;continuation=returnAddress;irqMasked=masked;plan=instructions.GetEnumerator();Next();}
    private static ulong Cost(NativeRoutineStep s)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(s.Bytes),s.Branch).Cycles;
    private void Next(){if(!plan.MoveNext()){Completed=true;pending=null;NextEventCycle=ulong.MaxValue;return;}Call=plan.Current as NativeRoutineCall;pending=plan.Current as NativeRoutineStep;NextEventCycle=pending is null ? ulong.MaxValue : checked(Cycle+Cost(pending));}
    public void AdvanceTo(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));if(Fault is not null)throw new InvalidOperationException(Fault);
        if(Call is not null)throw new InvalidOperationException("Native child owns execution until ReturnFromCall");
        try{while(!Completed && Call is null && NextEventCycle<=cycle){var s=pending!;ulong from=NextEventCycle-Cost(s);Cycle=NextEventCycle;s.Effect?.Invoke();ObserveInstruction?.Invoke(new(s.Address,s.Bytes,from,Cycle));Next();}if(Call is null)Cycle=cycle;}
        catch(Exception e){Fault=e.Message;Dispose();throw;}
    }
    public void ReturnFromCall(ulong cycle,ushort cursor)
    {
        if(Fault is not null)throw new InvalidOperationException(Fault);if(Call is null || cursor!=Call.Continuation || cycle<Cycle)throw new InvalidOperationException("Unbalanced native child return");
        Cycle=cycle;Call=null;try{Next();}catch(Exception e){Fault=e.Message;Dispose();throw;}
    }
    public void SuspendUntil(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));if(Fault is not null)throw new InvalidOperationException(Fault);
        if(Call is not null)throw new InvalidOperationException("Child must suspend its own CPU work");if(IrqMasked)throw new InvalidOperationException("IRQ cannot suspend masked native routine");
        if(!Completed){if(NextEventCycle-Cycle!=Cost(pending!))throw new InvalidOperationException("Suspension requires an instruction boundary");NextEventCycle=checked(NextEventCycle+cycle-Cycle);}Cycle=cycle;
    }
    public void Dispose()=>plan.Dispose();
}

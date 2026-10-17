using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Selected normal-mode cash4B39 CPU owner; alpha timing stays an explicit adapter.
// Caller arithmetic flags are local plans, not a complete exposed CPU snapshot.
public sealed class AddersTimedCashPayoutExecution : IDisposable
{
    private readonly Machine m;
    private readonly string evidence;
    private readonly Mpu4Alpha alpha;
    private readonly Func<Instruction,Machine,ulong> alphaCycles;
    private readonly Func<byte> readTriac;
    private readonly Action<byte> writeTriac;
    private readonly Action<byte>? writeMode;
    private readonly NativeRoutineExecution caller;
    private AddersTimedPayoutDebitExecution? debit;
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle=>debit?.NextEventCycle ?? caller.NextEventCycle;
    public ushort Address=>debit?.Address ?? caller.Address;
    public bool Completed=>caller.Completed;
    public string? Fault {get;private set;}
    public bool IrqMasked=>debit?.IrqMasked ?? caller.IrqMasked;
    public int Debits {get;private set;}
    public Action<OutputScanInstruction>? ObserveCallerInstruction {get;set;}
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}
    public Action<NativeRoutineCall,ulong>? ObserveDebit {get;set;}
    public AddersTimedCashPayoutExecution(Machine machine,string evidenceDirectory,Mpu4Alpha alphaOutput,
        ulong start,ushort stackPointer,byte initialConditionCode,Func<Instruction,Machine,ulong> unresolvedAlphaCycles,
        Func<byte> readPort,Action<byte> writePort,Action<byte>? writeVmMode=null)
    {
        if((sbyte)machine.Memory[0x323]<0)throw new NotSupportedException("Timed cash caller is selected normal mode only");
        m=machine;evidence=evidenceDirectory;alpha=alphaOutput;Cycle=start;alphaCycles=unresolvedAlphaCycles;readTriac=readPort;writeTriac=writePort;writeMode=writeVmMode;
        var plan=new AddersCashPayoutPlan(m,stackPointer,initialConditionCode);caller=new(plan.Instructions(),start,m.ReadWord(stackPointer),()=>(initialConditionCode&0x10)!=0);
        caller.ObserveInstruction=i=>{ObserveCallerInstruction?.Invoke(i);ObserveInstruction?.Invoke(i);};
    }
    public void AdvanceTo(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));if(Fault is not null)throw new InvalidOperationException(Fault);
        try{while(!Completed && NextEventCycle<=cycle){Cycle=NextEventCycle;
            if(debit is not null){debit.AdvanceTo(Cycle);if(!debit.Completed)continue;debit.Dispose();debit=null;caller.ReturnFromCall(Cycle,caller.Call!.Continuation);continue;}
            caller.AdvanceTo(Cycle);if(caller.Call is not { } call)continue;ObserveDebit?.Invoke(call,Cycle);Debits++;
            debit=new(m,evidence,alpha,Cycle,call.Y,call.S,call.ConditionCode,call.Continuation,alphaCycles,readTriac,writeTriac,writeMode);debit.ObserveInstruction=i=>ObserveInstruction?.Invoke(i);
        }
        if(!Completed){if(debit is not null)debit.AdvanceTo(cycle);else caller.AdvanceTo(cycle);}Cycle=cycle;}
        catch(Exception e){Fault=e.Message;Dispose();throw;}
    }
    public void SuspendUntil(ulong cycle){if(Fault is not null)throw new InvalidOperationException(Fault);if(debit is not null)debit.SuspendUntil(cycle);else caller.SuspendUntil(cycle);Cycle=cycle;}
    public void Dispose(){debit?.Dispose();caller.Dispose();}
}

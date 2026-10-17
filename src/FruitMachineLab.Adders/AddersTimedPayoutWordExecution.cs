using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// One pending recovered VM payout word. Its VM executor must acknowledge this
// completion exactly once; it must not execute a semantic payout afterwards.
public sealed class AddersTimedPayoutWordExecution : IDisposable
{
    private readonly Machine m;private readonly string evidence;private readonly Mpu4Alpha alpha;
    private readonly Func<Instruction,Machine,ulong> alphaCycles;private readonly Func<byte> readPort;private readonly Action<byte> writePort;private readonly Action<byte>? writeMode;
    private readonly AddersVmPayoutWordPlan plan;private readonly NativeRoutineExecution bridge;
    private AddersTimedPayoutServiceExecution? service;
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle=>service?.NextEventCycle ?? bridge.NextEventCycle;
    public ushort Address=>service?.Address ?? bridge.Address;
    public bool Completed=>bridge.Completed;
    public string? Fault {get;private set;}
    public bool IrqMasked=>service?.IrqMasked ?? bridge.IrqMasked;
    public int Debits {get;private set;}
    public ushort ResumeCursor=>plan.ResumeCursor;
    public Action<OutputScanInstruction>? ObserveCallerInstruction {get;set;}
    public Action<NativeRoutineCall,ulong>? ObserveDebit {get;set;}
    public AddersTimedPayoutWordExecution(Machine machine,string evidenceDirectory,Mpu4Alpha alphaOutput,Instruction instruction,ulong start,byte initialConditionCode,
        Func<Instruction,Machine,ulong> unresolvedAlphaCycles,Func<byte> readTriac,Action<byte> writeTriac,Action<byte>? writeVmMode=null)
    {
        m=machine;evidence=evidenceDirectory;alpha=alphaOutput;Cycle=start;alphaCycles=unresolvedAlphaCycles;readPort=readTriac;writePort=writeTriac;writeMode=writeVmMode;
        ushort s=m.Control?.Pointer ?? throw new NotSupportedException("Payout VM bridge requires native control context");if(s>0x7C8)throw new NotSupportedException("Payout VM S must remain below accounting RAM07C9");plan=new(m,instruction,s,initialConditionCode,writeMode);bridge=new(plan.Instructions(),start,0xFC,()=>(initialConditionCode&0x10)!=0);bridge.ObserveInstruction=i=>ObserveCallerInstruction?.Invoke(i);
    }
    public void AdvanceTo(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));if(Fault is not null)throw new InvalidOperationException(Fault);
        try{while(!Completed && NextEventCycle<=cycle){Cycle=NextEventCycle;
            if(service is not null){service.AdvanceTo(Cycle);if(!service.Completed)continue;Debits+=service.Debits;service.Dispose();service=null;bridge.ReturnFromCall(Cycle,0x777E);continue;}
            bridge.AdvanceTo(Cycle);if(bridge.Call is not {} call)continue;service=new(m,evidence,alpha,Cycle,call.S,call.ConditionCode,alphaCycles,readPort,writePort,writeMode,call.Entry);service.ObserveCallerInstruction=i=>ObserveCallerInstruction?.Invoke(i);service.ObserveDebit=(c,at)=>ObserveDebit?.Invoke(c,at);
        }if(!Completed){if(service is not null)service.AdvanceTo(cycle);else bridge.AdvanceTo(cycle);}Cycle=cycle;}
        catch(Exception e){Fault=e.Message;Dispose();throw;}
    }
    public void SuspendUntil(ulong cycle){if(Fault is not null)throw new InvalidOperationException(Fault);if(service is not null)service.SuspendUntil(cycle);else bridge.SuspendUntil(cycle);Cycle=cycle;}
    public void Dispose(){service?.Dispose();bridge.Dispose();}
}

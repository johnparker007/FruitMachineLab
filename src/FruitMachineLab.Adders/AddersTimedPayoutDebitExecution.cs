using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

// One selected native4CBE debit, real nested display owner and6858 output
// service. Cash/token selection callers remain outside this CPU owner.
public sealed class AddersTimedPayoutDebitExecution : IDisposable
{
    private readonly Machine m;
    private readonly string evidence;
    private readonly Mpu4Alpha alpha;
    private readonly Func<Instruction,Machine,ulong> alphaCycles;
    private readonly Func<byte> readTriac;
    private readonly Action<byte> writeTriac;
    private readonly Action<byte>? writeMode;
    private readonly byte mask;
    private readonly ushort continuation;
    private readonly AddersPayoutDebitExecution debit;
    private AddersPayoutDisplayExecution? display;
    private Mpu4PayoutOutputExecution? output;
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle=>output?.NextEventCycle ?? display?.NextEventCycle ?? debit.NextEventCycle;
    public ushort Address=>output?.Address ?? display?.Address ?? debit.Address;
    public bool Completed=>output?.Completed==true;
    public string? Fault {get;private set;}
    public bool IrqMasked=>output?.IrqMasked ?? display?.IrqMasked ?? debit.IrqMasked;
    public string Phase=>Completed ? "Completed" : output is not null ? "Outputs" : display is not null ? "Display/"+display.Phase : "Debit";
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}
    public Action<OutputScanAccess>? ObserveAccess {get;set;}
    public Action<PayoutDisplayVmWord>? ObserveVmWord {get;set;}
    public AddersTimedPayoutDebitExecution(Machine machine,string evidenceDirectory,Mpu4Alpha alphaOutput,
        ulong start,ushort record,ushort nativeStackPointer,byte initialConditionCode,ushort nativeContinuation,
        Func<Instruction,Machine,ulong> unresolvedAlphaCycles,Func<byte> readPort,Action<byte> writePort,Action<byte>? writeVmMode=null)
    {
        if(machine.ReadWord(nativeStackPointer)!=nativeContinuation)throw new InvalidOperationException("Payout native caller return frame differs");
        m=machine;evidence=evidenceDirectory;alpha=alphaOutput;Cycle=start;mask=(byte)(initialConditionCode&0x50);continuation=nativeContinuation;
        alphaCycles=unresolvedAlphaCycles;readTriac=readPort;writeTriac=writePort;writeMode=writeVmMode;
        debit=new(machine,start,record,machine.DataPointer,initialConditionCode,nativeStackPointer);
        debit.ObserveInstruction=i=>ObserveInstruction?.Invoke(i);debit.ObserveAccess=v=>ObserveAccess?.Invoke(v);
    }
    public void AdvanceTo(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        if(Fault is not null)throw new InvalidOperationException(Fault);
        try{
            while(!Completed && NextEventCycle<=cycle){
                Cycle=NextEventCycle;
                if(output is not null){output.AdvanceTo(Cycle);continue;}
                if(display is not null){display.AdvanceTo(Cycle);if(!display.Completed)continue;display.Dispose();display=null;debit.ReturnFromDisplay(Cycle,m.DataPointer,0x4CD1);continue;}
                debit.AdvanceTo(Cycle);
                if(debit.WaitingForDisplay){display=new(m,evidence,alpha,Cycle,debit.DisplayRegisters,alphaCycles,writeMode);display.ObserveInstruction=i=>ObserveInstruction?.Invoke(i);display.ObserveAccess=v=>ObserveAccess?.Invoke(v);display.ObserveVmWord=w=>ObserveVmWord?.Invoke(w);}
                else if(debit.Completed){output=new(m,Cycle,mask,continuation,readTriac,writeTriac);output.ObserveInstruction=i=>ObserveInstruction?.Invoke(i);output.ObserveAccess=v=>ObserveAccess?.Invoke(v);}
            }
            if(!Completed){if(output is not null)output.AdvanceTo(cycle);else if(display is not null)display.AdvanceTo(cycle);else debit.AdvanceTo(cycle);}Cycle=cycle;
        }catch(Exception e){Fault=e.Message;Dispose();throw;}
    }
    public void SuspendUntil(ulong cycle)
    {
        if(Fault is not null)throw new InvalidOperationException(Fault);
        if(output is not null)output.SuspendUntil(cycle);else if(display is not null)display.SuspendUntil(cycle);else debit.SuspendUntil(cycle);Cycle=cycle;
    }
    public void Dispose(){display?.Dispose();output?.Dispose();debit.Dispose();}
}

using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

public readonly record struct PayoutDisplayVmWord(Instruction Instruction,ulong Started,ulong Completed,
    ushort DataPointer,ushort StackPointer,bool AlphaTimingAdapter);

// Incremental selected A8F9 display inside the real staged native gateway.
// VM words are atomic CPU-budget boundaries; alpha work explicitly retains a
// caller-provided timing adapter. No full instruction/IRQ acceptance is claimed.
public sealed class AddersPayoutDisplayExecution : IDisposable
{
    private readonly Machine m;
    private readonly string evidence;
    private readonly Mpu4Alpha alpha;
    private readonly Func<Instruction,Machine,ulong> alphaCycles;
    private readonly Mpu4NativeVmGatewayExecution gateway;
    private readonly VmControlStack? previousControl;
    private ScriptExecutor? vm;
    private bool returning,entered;
    private PayoutDisplayVmWord pending;
    private ulong vmDue,dispatchStarted;
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle=>vm is null ? gateway.NextEventCycle : vmDue;
    public bool Completed=>gateway.Completed;
    public string? Fault {get;private set;}
    public ushort Address=>vm is null ? gateway.Address : returning ? (ushort)0xFC : pending.Instruction.Site;
    public bool IrqMasked=>gateway.IrqMasked;
    public string Phase=>Completed ? "Completed" : vm is null ? entered ? "NativeReturn" : "NativeEntry" : returning ? "ReturnDispatch" : "VmWord";
    public NativeVmRegisters Registers=>gateway.Registers;
    public ushort Continuation=>gateway.Continuation;
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}
    public Action<OutputScanAccess>? ObserveAccess {get;set;}
    public Action<PayoutDisplayVmWord>? ObserveVmWord {get;set;}
    public AddersPayoutDisplayExecution(Machine machine,string evidenceDirectory,Mpu4Alpha alphaOutput,
        ulong start,NativeVmRegisters registers,Func<Instruction,Machine,ulong> unresolvedAlphaCycles,Action<byte>? writeVmMode=null)
    {
        if(registers.X!=0xA8F9)throw new NotSupportedException("Only selected A8F9 payout display entry is supported");
        if(machine.DataPointer!=registers.U)throw new InvalidOperationException("Display VM U does not match logical stack");
        m=machine;evidence=evidenceDirectory;alpha=alphaOutput;alphaCycles=unresolvedAlphaCycles;Cycle=start;previousControl=m.Control;
        gateway=new(m,start,registers,writeVmMode);gateway.ObserveInstruction=i=>ObserveInstruction?.Invoke(i);gateway.ObserveAccess=a=>ObserveAccess?.Invoke(a);
    }
    private void ScheduleWord()
    {
        if(vm!.Completed){
            if(m.Control!.ResumeCursor!=0x76ED)throw new NotSupportedException("Nonlocal payout display gateway return");
            returning=true;dispatchStarted=Cycle;vmDue=checked(Cycle+AddersPayoutDisplayTiming.ReturnDispatchCycles(m));return;
        }
        Instruction instruction=vm.NextInstruction!;ulong cost=AddersPayoutDisplayTiming.Cycles(instruction,m,alphaCycles);
        pending=new(instruction,Cycle,checked(Cycle+cost),m.DataPointer,m.Control!.Pointer,instruction.Operation=="vm_execute_alpha_stream");vmDue=pending.Completed;
    }
    private void EnterVm()
    {
        entered=true;m.Control=new(m,gateway.StackPointer);
        vm=new(m){ResolveScript=at=>new(Path.Combine(evidence,"VM-SCRIPTS",$"{at:X4}.txt")),WordHandler=(i,_)=>{
            if(i.Operation!="vm_execute_alpha_stream")return false;alpha.Execute(Cell.Add(i.Site,2));return true;
        }};
        vm.Begin(new(Path.Combine(evidence,"VM-SCRIPTS","A8F9.txt")));ScheduleWord();
    }
    public void AdvanceTo(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        if(Fault is not null)throw new InvalidOperationException(Fault);
        try{
            while(!Completed && NextEventCycle<=cycle){
                Cycle=NextEventCycle;
                if(vm is null){gateway.AdvanceTo(Cycle);if(gateway.WaitingForVm)EnterVm();else if(gateway.Completed)m.Control=previousControl;}
                else if(returning){gateway.ReturnFromVm(Cycle,m.Control!.Pointer,m.DataPointer,m.Control.ResumeCursor);vm=null;}
                else{vm.Step();ObserveVmWord?.Invoke(pending);ScheduleWord();}
            }
            if(vm is null && !Completed)gateway.AdvanceTo(cycle);Cycle=cycle;
        }catch(Exception e){Fault=e.Message;Dispose();throw;}
    }
    public void SuspendUntil(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        if(Fault is not null)throw new InvalidOperationException(Fault);
        if(IrqMasked)throw new InvalidOperationException("IRQ cannot suspend masked display");
        if(vm is null)gateway.SuspendUntil(cycle);
        else{
            ulong from=returning ? dispatchStarted : pending.Started;
            if(Cycle!=from)throw new InvalidOperationException("Display VM IRQ suspension requires a complete word boundary");
            ulong delta=cycle-Cycle;vmDue=checked(vmDue+delta);
            if(returning)dispatchStarted=cycle;else pending=pending with{Started=cycle,Completed=vmDue};
        }
        Cycle=cycle;
    }
    // A failed/incomplete call retains its current machine/control state for
    // diagnosis. Dispose must not silently unwind or invent a successful return.
    public void Dispose()=>gateway.Dispose();
}

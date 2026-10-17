using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Incremental collection VM + selected timed native payout. The enclosing host
// owns IRQ/input/sound clocks. Ordinary collection VM/helper CPU budgets remain
// explicit injected adapters, rather than silently adopting zero-cost work.
public sealed class AddersTimedCollectionExecution : IDisposable
{
    private readonly Machine m;private readonly string evidence;private readonly Mpu4Alpha alpha;
    private readonly Func<Instruction,Machine,ulong> wordCycles,alphaCycles;
    private readonly Func<byte> readPort;private readonly Action<byte> writePort;private readonly Action<byte>? writeMode;
    private readonly AddersCollectionTransfer transfer;
    private readonly byte vmMask;
    private AddersTimedPayoutWordExecution? payout;
    private ulong next;
    private bool payoutDue;
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle=>payout?.NextEventCycle ?? next;
    public bool Completed=>transfer.Completed;
    public bool Paused {get;private set;}
    public string? Fault {get;private set;}
    public ushort? Address=>payout?.Address ?? transfer.NextInstruction?.Site;
    public bool NativePayoutActive=>payout is not null;
    public int Debits {get;private set;}
    public Action<Instruction,ulong>? ObserveDispatch {get;set;}
    public Action<NativeRoutineCall,ulong>? ObserveDebit {get;set;}
    public void Pause()=>Paused=true;
    public void Resume(){if(Fault is not null)throw new InvalidOperationException(Fault);Paused=false;}
    public AddersTimedCollectionExecution(Machine machine,string evidenceDirectory,ushort entry,ulong start,
        Action<LampRequest> lampOutput,Mpu4Alpha alphaOutput,Mpu4ChoiceStreamScheduler scheduler,
        Func<Instruction,Machine,ulong> unresolvedCollectionWordCycles,Func<Instruction,Machine,ulong> unresolvedAlphaCycles,
        Func<byte> readTriac,Action<byte> writeTriac,byte vmInterruptMask,Action<byte>? writeVmMode=null,Action<byte,byte>? ymWrite=null)
    {
        if(machine.Control is null || machine.Control.Pointer>0x7C8)throw new NotSupportedException("Timed collection requires a native VM S below accounting RAM07C9");
        m=machine;evidence=evidenceDirectory;alpha=alphaOutput;Cycle=start;vmMask=(byte)(vmInterruptMask&0x50);wordCycles=unresolvedCollectionWordCycles;alphaCycles=unresolvedAlphaCycles;readPort=readTriac;writePort=writeTriac;writeMode=writeVmMode;
        var bindings=new AddersCollectionWordBindings(m,lampOutput,alpha,scheduler,ymWrite);transfer=new(m,evidence,entry,lampOutput,bindings.Handle);Schedule();
    }
    private void Schedule()
    {
        if(Completed){next=ulong.MaxValue;return;}payoutDue=transfer.PendingPayout is not null;
        if(payoutDue){next=Cycle;return;}
        ulong budget=wordCycles(transfer.NextInstruction!,m);if(budget==0)throw new NotSupportedException("Collection VM/helper CPU budget cannot be zero");next=checked(Cycle+budget);
    }
    public void AdvanceCycles(ulong cycles){if(Paused || Completed || Fault is not null)return;AdvanceTo(checked(Cycle+cycles));}
    public void AdvanceTo(ulong cycle)
    {
        if(Paused || Completed || Fault is not null)return;if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        int budget=1_000_000;
        try{while(!Completed && NextEventCycle<=cycle){if(--budget==0)throw new InvalidOperationException("Collection event budget exceeded");Cycle=NextEventCycle;
            if(payout is not null){payout.AdvanceTo(Cycle);if(!payout.Completed)continue;Debits+=payout.Debits;payout.Dispose();payout=null;transfer.ServicePayout(_=>{});Schedule();continue;}
            Instruction i=transfer.NextInstruction!;ObserveDispatch?.Invoke(i,Cycle);
            if(payoutDue){payout=new(m,evidence,alpha,i,Cycle,vmMask,alphaCycles,readPort,writePort,writeMode);payout.ObserveDebit=(call,at)=>ObserveDebit?.Invoke(call,at);continue;}
            transfer.Step();Schedule();
        }
        if(!Completed){payout?.AdvanceTo(cycle);Cycle=cycle;}}
        catch(Exception e){Fault=e.Message;Paused=true;Dispose();throw;}
    }
    // Host must freeze its own service/input/sound clocks while paused too.
    // This component does not supply/guess IRQ acceptance or service periods.
    public void Dispose()=>payout?.Dispose();
}

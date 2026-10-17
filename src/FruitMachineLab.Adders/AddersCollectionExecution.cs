using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

/// <summary>Composes collection VM transfers and native payout against one machine.
/// The host still owns the IRQ/service clock and PIA hardware interface.</summary>
public sealed class AddersCollectionExecution
{
    private readonly Machine machine;
    private readonly string evidence;
    private readonly Mpu4Alpha alpha;
    private readonly Func<byte> readTriac;
    private readonly Action<byte> writeTriac;
    private readonly AddersCollectionTransfer transfer;
    private AddersPayoutExecution? payout;
    public bool Completed=>transfer.Completed;
    public bool Waiting=>payout?.Waiting==true;
    public ushort? Address=>payout is {Completed:false} ? payout.Address : transfer.NextInstruction?.Site;
    public int Debits {get;private set;}
    public bool Paused {get;private set;}
    public Action<AddersPayoutRecord,ushort>? ObserveDebit {get;set;}
    public void Pause()=>Paused=true;
    public void Resume()=>Paused=false;

    public AddersCollectionExecution(Machine machine,string evidenceDirectory,ushort entry,
        Action<LampRequest> lampOutput,Mpu4Alpha alpha,Mpu4ChoiceStreamScheduler scheduler,
        Func<byte> readTriac,Action<byte> writeTriac,Action<byte,byte>? ymWrite=null)
    {
        this.machine=machine;evidence=evidenceDirectory;this.alpha=alpha;
        this.readTriac=readTriac;this.writeTriac=writeTriac;
        var bindings=new AddersCollectionWordBindings(machine,lampOutput,alpha,scheduler,ymWrite);
        transfer=new(machine,evidence,entry,lampOutput,bindings.Handle);
    }
    public void Step()
    {
        if(Paused || Completed)return;
        if(transfer.PendingPayout is { } native) {
            payout ??=new(machine,native,()=>AddersPayoutDisplay.Refresh(machine,evidence,alpha),
                readTriac,writeTriac,message=>AddersPayoutSerial.Enqueue(machine,message)) {ObserveDebit=(record,balance)=>ObserveDebit?.Invoke(record,balance)};
            payout.Step();
            if(payout.Completed) {
                var completedPayout=payout;Debits+=completedPayout.Debits;
                // Service has already executed incrementally on this same Machine;
                // acknowledge completion rather than executing the native call twice.
                transfer.ServicePayout(actual=> {
                    if(actual!=native || !completedPayout.Completed)throw new InvalidOperationException("Mismatched payout continuation");
                });
                payout=null;
            }
        } else transfer.Step();
    }
}

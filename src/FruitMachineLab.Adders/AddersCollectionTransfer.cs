using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

/// <summary>
/// Incremental ROM collection transfers. Stops BEFORE native4B39/4B8C;
/// this component neither delivers coins nor drains pending balances.
/// </summary>
public sealed class AddersCollectionTransfer
{
    private readonly ScriptExecutor executor;
    private bool completingPayout;
    public Instruction? NextInstruction => executor.NextInstruction;
    public bool Completed => executor.Completed;
    public ushort? PendingPayout => NextInstruction?.Native is 0x4B39 or 0x4B8C
        ? NextInstruction.Native : null;

    public AddersCollectionTransfer(Machine machine, string evidenceDirectory, ushort entry, Action<LampRequest> lampOutput,
        Func<Instruction,Machine,bool>? additionalHandler=null)
    {
        if(entry is not (0xAA2B or 0xA983 or 0xA9A0 or 0xA9D5 or 0xAA04 or 0xA942))
            throw new ArgumentOutOfRangeException(nameof(entry), "Unrecovered collection entry");
        if(machine.Control is null)
            throw new ArgumentException("Collection requires an existing physical VM control stack", nameof(machine));
        ArgumentNullException.ThrowIfNull(lampOutput);
        var lamps=new Mpu4LampRequests(machine,lampOutput);
        RecoveredScript Resolve(ushort body) => new(Path.Combine(evidenceDirectory,"VM-SCRIPTS",$"{body:X4}.txt"));
        executor = new ScriptExecutor(machine) {
            ResolveScript=Resolve,
            InputConditionCell=selector=>Mpu4InputConditions.Evaluate(machine,(byte)selector),
            WordHandler=(instruction,m) => {
                if(instruction.Native is 0x4B39 or 0x4B8C) {
                    if(!completingPayout)throw new InvalidOperationException("Payout service must complete before VM continuation");
                    return true;
                }
                return lamps.HandleWord(instruction) || additionalHandler?.Invoke(instruction,m)==true;
            }
        };
        executor.Begin(Resolve(entry));
    }

    public void Step()
    {
        if(PendingPayout is not null)throw new InvalidOperationException("Waiting for native payout service");
        executor.Step();
    }

    /// <summary>
    /// The host must run the real native service against this same machine.
    /// Returning acknowledges its completion; exceptions leave the VM at the call.
    /// No memory, clock or input snapshots are supplied by this component.
    /// </summary>
    public void ServicePayout(Action<ushort> service)
    {
        ArgumentNullException.ThrowIfNull(service);
        ushort native=PendingPayout ?? throw new InvalidOperationException("No pending payout call");
        service(native);
        completingPayout=true;
        try { executor.Step(); }
        finally { completingPayout=false; }
    }
}

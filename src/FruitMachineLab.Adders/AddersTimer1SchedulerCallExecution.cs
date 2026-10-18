using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

// Bounded FEC9 JSR5CD0 wrapper: the original FEC9 instruction is BD5CD0, so
// JSR pushes the next instruction FECC as the continuation. Run the existing
// 5CD0 service, verify the RTS return word, then execute CLR $2C at FECC and
// stop at FECE. The caller establishes the timer1 handoff state; this invents
// no cadence and no IRQ owner.
public sealed class AddersTimer1SchedulerCallExecution : IDisposable
{
    public const ushort ReturnAddress=0xFECC;
    private readonly Machine machine;
    private readonly ushort frame;
    private readonly NativeRoutineExecution execution;
    public ulong Cycle=>execution.Cycle;
    public ulong NextEventCycle=>execution.NextEventCycle;
    public bool Completed=>execution.Completed;
    public ushort Address=>execution.Address;
    public string? Fault=>execution.Fault;
    public ushort Stack {get;private set;}
    public Action<OutputScanInstruction>? ObserveInstruction {get=>execution.ObserveInstruction;set=>execution.ObserveInstruction=value;}
    public AddersTimer1SchedulerCallExecution(Machine machine,ulong start,ushort stack,ushort u,ushort x,ushort y,bool irqMasked,ushort returnAddress=ReturnAddress,Action<byte,byte>? ymWrite=null)
    {
        if(stack<2)throw new ArgumentOutOfRangeException(nameof(stack));
        if(returnAddress!=ReturnAddress)throw new ArgumentOutOfRangeException(nameof(returnAddress),"FEC9 JSR5CD0 supports only the FECC continuation");
        this.machine=machine;Stack=stack;frame=(ushort)(stack-2);
        execution=new NativeRoutineExecution(Instructions(u,x,y,ymWrite),start,0xFECE,()=>irqMasked);
    }
    private IEnumerable<NativeRoutineWork> Instructions(ushort u,ushort x,ushort y,Action<byte,byte>? ymWrite)
    {
        yield return new NativeRoutineStep(0xFEC9,"BD5CD0",()=>{Stack=frame;machine.WriteWord(frame,ReturnAddress);});
        var plan=new AddersSoundServicePlan(machine,frame,u,x,y,ymWrite:ymWrite);
        foreach(var work in plan.Instructions()){
            if(work is NativeRoutineStep step && step.Address==0x5D3A){
                if(step.Bytes!="39")throw new InvalidDataException("Unexpected scheduler return opcode");
                yield return new NativeRoutineStep(0x5D3A,"39",()=>{if(machine.ReadWord(frame)!=ReturnAddress)throw new InvalidDataException("Scheduler return word differs");Stack=(ushort)(frame+2);});
            }else yield return work;
        }
        yield return new NativeRoutineStep(0xFECC,"0F2C",()=>machine.Memory[0x2C]=0);
    }
    public void AdvanceTo(ulong cycle)=>execution.AdvanceTo(cycle);
    public void Dispose()=>execution.Dispose();
}

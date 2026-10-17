namespace FruitMachineLab.Runtime;

// Selected FEF2->FF13 full ordinary IRQ return. Saved bank byte must be0,
// saved CC E must be1. Frame/register restoration remains the CPU owner's job.
public sealed class Mpu4OrdinaryIrqReturnExecution
{
    public static IReadOnlyList<(ushort Address,string Bytes)> Path=>[(0xFEF2,"2014"),(0xFF08,"A663"),(0xFF0A,"2707"),(0xFF13,"3B")];
    private int index;
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle {get;private set;}
    public bool Completed=>index==Path.Count;
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}
    public Mpu4OrdinaryIrqReturnExecution(ulong start,byte savedBank,byte savedCC)
    {
        if(savedBank!=0 || (savedCC&0x80)==0)throw new NotSupportedException("Selected IRQ return requires bank0 and a full saved frame");Cycle=start;NextEventCycle=checked(start+Cost(0));
    }
    private static ulong Cost(int n)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(Path[n].Bytes),stackedCC:0x80).Cycles;
    public void AdvanceTo(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        while(!Completed && NextEventCycle<=cycle){var ins=Path[index];ulong from=NextEventCycle-Cost(index);Cycle=NextEventCycle;ObserveInstruction?.Invoke(new(ins.Address,ins.Bytes,from,Cycle));index++;NextEventCycle=Completed ? ulong.MaxValue : checked(Cycle+Cost(index));}Cycle=cycle;
    }
}

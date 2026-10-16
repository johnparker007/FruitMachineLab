namespace FruitMachineLab.Runtime;

// Internal-clock, 16-bit continuous control42 subset. This generates timer
// expiries, not CPU IRQ acceptance or ROM service execution.
public sealed class Mpu4Timer1Clock
{
    public const ushort NormalLatch=0x0D70; // ROM708E/7091
    public static ulong Period(ushort latch)=>(ulong)latch+1;
    public ulong Cycle {get;private set;}
    public ulong NextExpiry {get;private set;}
    public ulong Expiries {get;private set;}
    public ushort Latch {get;}
    public Mpu4Timer1Clock(ulong latchCycle,ushort latch,byte control=0x42)
    {
        if(control!=0x42)throw new NotSupportedException("Only internal 16-bit continuous timer1 control42 is verified");
        Latch=latch;Cycle=latchCycle;NextExpiry=checked(latchCycle+Period(latch));
    }
    // Inclusive expiry count; not a decision about same-cycle CPU bus ordering.
    public ulong AdvanceTo(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        ulong due=cycle<NextExpiry ? 0 : (cycle-NextExpiry)/Period(Latch)+1;
        ulong next=checked(NextExpiry+checked(due*Period(Latch)));
        ulong total=checked(Expiries+due);
        Cycle=cycle;NextExpiry=next;Expiries=total;return due;
    }
}

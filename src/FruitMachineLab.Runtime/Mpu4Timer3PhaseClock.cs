namespace FruitMachineLab.Runtime;

// Selected MAME-reference timer3 lifecycle: control00/63, word counting,
// reset released, gate low, no external clock edges. Not a complete MC6840.
// Attoseconds preserve MAME's truncation when switching clock sources; rounding
// each bus access to CPU cycles loses the observed frozen-counter decrement.
public sealed class Mpu4Timer3PhaseClock
{
    public const decimal AttosecondsPerSecond=1_000_000_000_000_000_000m;
    private const decimal CpuTick=581_395_348_837m; // floor(1e18 / 1720000)
    private const decimal PrescaledTick=4_651_162_790_697m; // floor(1e18 / 215000)
    public decimal Time {get;private set;}
    public decimal? NextTransition {get;private set;}
    public bool OutputHigh {get;private set;}
    public bool SingleFired {get;private set;}
    public bool InterruptPending {get;private set;}
    public bool IrqAsserted=>InterruptPending && Control==0x63;
    public byte Control {get;private set;}
    public ushort Latch {get;private set;}=ushort.MaxValue;
    public ushort RawCounter {get;private set;}=ushort.MaxValue;
    public bool Enabled=>NextTransition.HasValue;
    private bool statusRead;

    // Explicit replay/checkpoint seed while control00 has stopped this channel.
    // It does not infer phase or reset any subsequent arm.
    public static Mpu4Timer3PhaseClock FromStoppedSnapshot(decimal time,bool outputHigh,bool singleFired,ushort latch,ushort rawCounter,bool pending,bool statusRead)
    {
        if(time<0 || latch==0)throw new ArgumentOutOfRangeException(nameof(time),"Snapshot needs nonnegative time and a positive latch");
        return new(){Time=time,OutputHigh=outputHigh,SingleFired=singleFired,Latch=latch,RawCounter=rawCounter,InterruptPending=pending,statusRead=statusRead};
    }

    // Inclusive timer events. CPU accesses exactly on an event require their
    // own recovered ordering; this does not resolve the bus-matrix ties.
    public void AdvanceTo(decimal time)
    {
        if(time<Time)throw new ArgumentOutOfRangeException(nameof(time));
        while(NextTransition is { } next && next<=time)
        {
            if(OutputHigh){InterruptPending=true;statusRead=false;SingleFired=true;}
            OutputHigh=!OutputHigh;
            RawCounter=Latch;
            NextTransition=checked(next+CpuTick*8*(OutputHigh ? Latch : 1));
        }
        Time=time;
    }

    public void WriteControl(byte control)
    {
        if(control!=0 && control!=0x63)throw new NotSupportedException("Only timer3 control00/63 is recovered here");
        if(control==Control)return;
        if(control==0)
        {
            // New divisor=1 is installed before remaining time is converted.
            RawCounter=checked((ushort)decimal.Floor((NextTransition!.Value-Time)*1_720_000/AttosecondsPerSecond));
            NextTransition=null;
        }
        else NextTransition=checked(Time+PrescaledTick*RawCounter);
        Control=control;
    }

    public void WriteLatch(ushort latch)
    {
        // Zero schedules a zero-duration high phase; deliberately excluded until
        // its repeated same-timestamp ordering has a dedicated lifecycle proof.
        if(latch==0)throw new NotSupportedException("Zero-latch lifecycle ordering is not recovered");
        Latch=RawCounter=latch;InterruptPending=false;
        NextTransition=Control==0x63 ? checked(Time+CpuTick*8*(OutputHigh ? latch : 1)) : null;
    }

    public void ReadStatus(){statusRead|=InterruptPending;}
    public void ReadCounterMsb(){if(statusRead)InterruptPending=false;}
}

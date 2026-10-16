namespace FruitMachineLab.Runtime;

// Bounded internal-clock control63 pulse. IRQ assertion is separate from CPU
// acceptance/callback service; the caller supplies the phase at each arm.
// External clocks, free-running post-shot transitions and register-bus timing
// are not inferred by this class.
public sealed class Mpu4Timer3Pulse
{
    public ulong Cycle {get;private set;}
    public Mpu4Timer3Deadline? Deadline {get;private set;}
    private bool outputHigh,outputPhaseKnown;
    public bool OutputHigh=>outputPhaseKnown ? outputHigh : throw new NotSupportedException("Post-shot/internal clock phase is outside the bounded timer3 pulse");
    public bool InterruptPending {get;private set;}
    private bool initialHigh;
    public ulong NextEvent=>Deadline is not { } d || InterruptPending ? ulong.MaxValue : outputHigh ? d.Interrupt : d.FirstEdge;
    public void Arm(ulong cycle,ushort latch,bool outputHigh,byte control=0x63)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle),"Timer clock cannot run backwards");
        var deadline=Mpu4Timer3Deadline.Calculate(cycle,latch,outputHigh,control);
        Cycle=cycle;Deadline=deadline;initialHigh=this.outputHigh=outputHigh;outputPhaseKnown=true;InterruptPending=false;
    }
    // Inclusive event-clock contract. A CPU bus access on the same cycle needs
    // a separately recovered ordering; the hardware matrix keeps those ties open.
    public void AdvanceTo(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle),"Timer clock cannot run backwards");
        Cycle=cycle;
        if(Deadline is not { } d)return;
        if(cycle>=d.Interrupt){outputHigh=false;outputPhaseKnown=cycle==d.Interrupt;InterruptPending=true;}
        else outputHigh=initialHigh || cycle>=d.FirstEdge;
    }
    public void Acknowledge()
    {
        if(!InterruptPending)throw new InvalidOperationException("Timer3 acknowledged before expiry");
        Deadline=null;InterruptPending=false;outputPhaseKnown=false;
    }
}

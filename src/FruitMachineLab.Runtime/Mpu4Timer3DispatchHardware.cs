namespace FruitMachineLab.Runtime;

// Bounded connection from the selected native dispatch to an already seeded
// timer3. Other PTM channels, interrupt priority and CPU delivery are supplied
// by the caller, not inferred here. Live does not yet have that hardware seed.
public sealed class Mpu4Timer3DispatchHardware
{
    private readonly Mpu4Timer3PhaseClock timer;
    private readonly ulong entryCycle;
    private readonly decimal entryTime;
    private bool statusRead,counterRead,selectorWritten,stopped;

    public Mpu4Timer3DispatchHardware(Mpu4Timer3PhaseClock timer,ulong entryCycle,decimal entryTime)
    {
        if(entryTime<timer.Time)throw new ArgumentOutOfRangeException(nameof(entryTime));
        timer.AdvanceTo(entryTime);
        if(!timer.IrqAsserted)throw new NotSupportedException("Selected timer3 dispatch requires an asserted enabled timer3");
        this.timer=timer;this.entryCycle=entryCycle;this.entryTime=entryTime;
    }

    private void Advance(ulong cycle)
    {
        if(cycle<entryCycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        // Keep sub-cycle timer phase. Rounding bus times to integer CPU cycles
        // before subtracting them would lose the frozen-counter behaviour.
        timer.AdvanceTo(entryTime+(cycle-entryCycle)*Mpu4Timer3PhaseClock.AttosecondsPerSecond/1_720_000m);
    }

    public void Read(Timer3DispatchRead access)
    {
        if(access.Address==0x901 && !statusRead && !counterRead && !selectorWritten){
            Advance(access.Cycle);
            if(!timer.IrqAsserted)throw new NotSupportedException("Timer3 assertion changed before selected status read");
            timer.ReadStatus();statusRead=true;return;
        }
        if(access.Address==0x906 && statusRead && !counterRead && !selectorWritten){
            Advance(access.Cycle);timer.ReadCounterMsb();counterRead=true;return;
        }
        throw new NotSupportedException("Outside the selected timer3 status/counter read sequence");
    }

    public void Write(Timer3DispatchWrite access)
    {
        if(!access.Hardware)throw new ArgumentException("RAM shadows are not PTM accesses",nameof(access));
        if(access.Address==0x901 && counterRead && !selectorWritten && (access.Value&0x41)==0){
            Advance(access.Cycle);selectorWritten=true;return; // CR2 bit0 selects CR3 at0900.
        }
        if(access.Address==0x900 && selectorWritten && !stopped && access.Value==0){
            Advance(access.Cycle);timer.WriteControl(0);stopped=true;return;
        }
        throw new NotSupportedException("Outside the selected timer3 selector/stop write sequence");
    }
}

namespace FruitMachineLab.Runtime;

/// <summary>
/// Bounded MAME-reference countdown for timer 3, control 63, with reset released.
/// The caller supplies the effective latch-write cycle and internal output phase.
/// This calculates expiry, not CPU IRQ acceptance or native callback execution.
/// Other controls and post-expiry retrigger behaviour are deliberately unsupported.
/// </summary>
public readonly record struct Mpu4Timer3Deadline(ulong FirstEdge, ulong Interrupt)
{
    public static Mpu4Timer3Deadline Calculate(ulong latchCycle, ushort latch, bool outputHigh, byte control=0x63)
    {
        if(control!=0x63)throw new NotSupportedException($"Timer-3 control {control:X2} has no verified deadline translation");
        // 6840 mode 4: low output rises after one prescaled tick, then falls
        // after latch ticks. An already-high output only has the latter phase.
        ulong first=checked(latchCycle+(outputHigh ? (ulong)latch*8 : 8UL));
        return new(first,outputHigh ? first : checked(first+(ulong)latch*8));
    }
}

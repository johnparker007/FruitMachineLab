namespace FruitMachineLab.Runtime;

public record CapturedCycleEvent(int Sequence,ulong Cycle,ulong[] Data);

// A deterministic clock driven by captured timestamps, not a CPU/PTM simulator.
// Same-cycle events retain source order; advancing time never synthesizes events.
public sealed class CapturedCycleTimeline(ulong initialCycle,IReadOnlyList<ulong[]> rows)
{
    private int cursor;
    private ulong previous=initialCycle;
    private ulong? next;
    public ulong Now { get; private set; }=initialCycle;
    public int Remaining=>rows.Count-cursor;
    public void AdvanceTo(ulong cycle,Action<CapturedCycleEvent> dispatch)
    {
        if(cycle<Now)throw new InvalidDataException("Captured cycle clock moved backwards");
        while(cursor<rows.Count) {
            if(rows[cursor].Length<2)throw new InvalidDataException("Malformed captured event");
            next??=checked(previous+rows[cursor][0]);if(next>cycle)break;
            Now=next.Value;
            dispatch(new(cursor,Now,rows[cursor]));previous=Now;next=null;cursor++;
        }
        Now=cycle;
    }
}

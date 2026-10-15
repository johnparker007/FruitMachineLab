namespace FruitMachineLab.Runtime;

// Explicit translated-CPU boundary: observed outer IRQ entry-to-RTI intervals.
// Nested IRQ time is already included once. No acceptance/RTI cycles are inferred.
public sealed class CapturedInterruptOccupancy
{
    private readonly ulong[][] intervals;
    private readonly ulong period;
    private int index;
    private ulong epoch;
    public ulong NextStart=>checked(epoch+intervals[index][0]);
    public ulong NextEnd=>checked(NextStart+intervals[index][1]);
    public CapturedInterruptOccupancy(ulong period,IEnumerable<ulong[]> intervals)
    {
        this.period=period;this.intervals=intervals.Select(row=>row.ToArray()).ToArray();ulong previous=0;
        if(period==0 || this.intervals.Length==0)throw new InvalidDataException("Missing IRQ occupancy");
        foreach(var row in this.intervals) {
            if(row.Length!=2 || row[1]==0 || row[0]<previous || checked(row[0]+row[1])>period)throw new InvalidDataException("Invalid IRQ occupancy interval");
            previous=row[0]+row[1];
        }
    }
    public void Consume(){if(++index==intervals.Length){index=0;epoch=checked(epoch+period);}}
}

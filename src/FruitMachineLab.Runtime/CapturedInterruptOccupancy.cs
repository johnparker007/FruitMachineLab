namespace FruitMachineLab.Runtime;

// Explicit translated-CPU adapter. The constructor preserves observed intervals;
// the ordinary-IRQ factory adds verified entry/return costs. Nested service is
// already included once. IRQ assertion/start timing itself is not generated.
public sealed class CapturedInterruptOccupancy
{
    // Recorded starts remain observed. Ordinary full-frame entry/RTI costs are
    // source-derived; nested service is already inside each outer interval.
    public static CapturedInterruptOccupancy FromOrdinaryIrqHandlers(ulong period,IEnumerable<ulong[]> handlers)
    {
        ulong rti=(ulong)M6809InstructionTiming.Decode(new byte[]{0x3B},stackedCC:0x80).Cycles;
        return new(period,handlers.Select(row=> {
            if(row.Length!=2 || row[0]<M6809IrqEntry.EntryCycles)throw new InvalidDataException("IRQ interval has no room for ordinary entry");
            return new ulong[]{row[0]-M6809IrqEntry.EntryCycles,checked(row[1]+M6809IrqEntry.EntryCycles+rti)};
        }));
    }
    private readonly ulong[][] intervals;
    private readonly ulong period;
    private readonly ulong availableCpuWork;
    private int index;
    private ulong epoch;
    // Project pure CPU work through this explicit periodic IRQ adapter. Does
    // not consume its iteration cursor, execute handlers or invent IRQ starts.
    public ulong CompletionAfterCpuWork(ulong start,ulong work)
    {
        if(work==0)return start;
        if(availableCpuWork==0)throw new InvalidOperationException("No CPU work is available in IRQ period");
        ulong cursor=start,localEpoch=start/period*period;
        while(true){
            foreach(var row in intervals){
                ulong begin=checked(localEpoch+row[0]),end=checked(begin+row[1]);
                if(end<=cursor)continue;
                if(begin>cursor){ulong available=begin-cursor;if(work<=available)return checked(cursor+work);work-=available;}
                cursor=end;
            }
            ulong boundary=checked(localEpoch+period);
            if(cursor<boundary){ulong available=boundary-cursor;if(work<=available)return checked(cursor+work);work-=available;cursor=boundary;}
            localEpoch=boundary;
        }
    }
    public ulong NextStart=>checked(epoch+intervals[index][0]);
    public ulong NextEnd=>checked(NextStart+intervals[index][1]);
    public CapturedInterruptOccupancy(ulong period,IEnumerable<ulong[]> intervals)
    {
        this.period=period;this.intervals=intervals.Select(row=>row.ToArray()).ToArray();ulong previous=0,busy=0;
        if(period==0 || this.intervals.Length==0)throw new InvalidDataException("Missing IRQ occupancy");
        foreach(var row in this.intervals) {
            if(row.Length!=2 || row[1]==0 || row[0]<previous || checked(row[0]+row[1])>period)throw new InvalidDataException("Invalid IRQ occupancy interval");
            previous=row[0]+row[1];
            busy=checked(busy+row[1]);
        }
        availableCpuWork=period-busy;
    }
    public void Consume(){if(++index==intervals.Length){index=0;epoch=checked(epoch+period);}}
}

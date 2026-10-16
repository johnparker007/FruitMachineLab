using System.Text.Json;
using System.Text.Json.Serialization;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record TimerDeadlineCapture([property:JsonPropertyName("initial_callbacks")] int InitialCallbacks,ulong[][] Rows);
public record TimerDeadlineVerification(int Arms,ulong MinimumIrqLatency,ulong MaximumIrqLatency,ulong MinimumCallbackService,ulong MaximumCallbackService,bool StartingOutputHigh=false);

public static class SkillCashTimerDeadlineVerification
{
    public static TimerDeadlineVerification Verify(string evidenceDirectory,bool startingOutputHigh=false)
    {
        var capture=JsonSerializer.Deserialize<TimerDeadlineCapture>(File.ReadAllText(Path.Combine(evidenceDirectory,"skill-cash","timer-deadlines.json")),
            new JsonSerializerOptions{PropertyNameCaseInsensitive=true}) ?? throw new InvalidDataException("Missing timer capture");
        var result=Verify(capture,startingOutputHigh);
        var shared=JsonSerializer.Deserialize<SharedTimingCapture>(File.ReadAllText(Path.Combine(evidenceDirectory,"skill-cash","shared-timing.json")),
            new JsonSerializerOptions{PropertyNameCaseInsensitive=true}) ?? throw new InvalidDataException("Missing shared capture");
        ulong cycle=shared.InitialCycle;int callback=0;
        foreach(var item in shared.Events) {
            if(item.Length<2)throw new InvalidDataException("Malformed shared event");
            cycle=checked(cycle+item[0]);
            if(item[1]!=6)continue;
            if(callback>=capture.Rows.Length)throw new InvalidDataException("Extra shared timer callback");
            var row=capture.Rows[callback++];
            if(cycle!=checked(row[0]+row[2]+row[3]) || item.Length!=4 || item[2]!=row[4])throw new InvalidDataException("Independent captures disagree on callback cycle or column");
        }
        if(callback!=capture.Rows.Length)throw new InvalidDataException("Missing shared timer callback");
        return result;
    }
    // Conditional consistency check, not an observation of canonical initial
    // phase for all6103 arms. The newer ptm-skill-cpu capture observes the first20
    // high phases and effective STY stores seven cycles after these coordinates.
    // Keep the old coordinate calculation explicit rather than relabeling it as
    // measured hardware assertion/CPU-entry latency.
    public static TimerDeadlineVerification Verify(TimerDeadlineCapture capture,bool startingOutputHigh=false)
    {
        if(capture.Rows.Length==0 || capture.InitialCallbacks<0)throw new InvalidDataException("Empty timer capture");
        ulong minimum=ulong.MaxValue,maximum=0,minService=ulong.MaxValue,maxService=0,previous=0;
        foreach(var row in capture.Rows) {
            if(row.Length!=5 || row[1]>ushort.MaxValue || row[4]>7 || row[0]<=previous)throw new InvalidDataException("Malformed or unordered timer capture");
            previous=row[0];
            var deadline=Mpu4Timer3Deadline.Calculate(row[0],(ushort)row[1],startingOutputHigh);
            ulong irq=checked(row[0]+row[2]);
            if(irq<deadline.Interrupt || row[3]==0)throw new InvalidDataException("Timer callback precedes calculated expiry or IRQ service");
            ulong latency=irq-deadline.Interrupt;
            minimum=Math.Min(minimum,latency);maximum=Math.Max(maximum,latency);
            minService=Math.Min(minService,row[3]);maxService=Math.Max(maxService,row[3]);
        }
        return new(capture.Rows.Length,minimum,maximum,minService,maxService,startingOutputHigh);
    }
}

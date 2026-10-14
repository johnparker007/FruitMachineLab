namespace FruitMachineLab.Runtime;

public record LampLatchFrame(ulong Cycle,byte Column,byte Low,byte High);
public record AlphaPlaybackFrame(ulong Cycle,string Text,ushort Pending,ushort CurrentWin);
public record PlaybackSample(double[] LampDuty,string Alpha,ushort Pending,ushort CurrentWin);

// Renderer-facing presentation of verified outputs. Duty is the fraction of a
// trailing window energized at the multiplexed latch, not measured brightness.
public sealed class OutputPlayback
{
    public const double CpuCyclesPerSecond=1_720_000;
    private readonly LampLatchFrame[] lamps;
    private readonly AlphaPlaybackFrame[] alpha;
    public ulong DurationCycles { get; }
    public double DurationSeconds=>DurationCycles/CpuCyclesPerSecond;
    public int LampFrameCount=>lamps.Length;
    public int AlphaFrameCount=>alpha.Length;
    public OutputPlayback(ulong durationCycles,IEnumerable<LampLatchFrame> lamps,IEnumerable<AlphaPlaybackFrame> alpha)
    {
        DurationCycles=durationCycles;this.lamps=lamps.ToArray();this.alpha=alpha.ToArray();
        if(durationCycles==0 || this.lamps.Length==0 || this.alpha.Length==0)throw new InvalidDataException("Playback requires a duration and initial outputs");
        if(this.lamps[0].Cycle!=0 || this.alpha[0].Cycle!=0)throw new InvalidDataException("Playback requires outputs at cycle zero");
        ulong previous=0;
        foreach(var frame in this.lamps) {
            if(frame.Cycle<previous || frame.Cycle>durationCycles || frame.Column>7)throw new InvalidDataException("Invalid lamp playback order or column");previous=frame.Cycle;
        }
        previous=0;
        foreach(var frame in this.alpha) {
            if(frame.Cycle<previous || frame.Cycle>durationCycles)throw new InvalidDataException("Invalid alpha playback order");previous=frame.Cycle;
        }
    }
    public PlaybackSample Sample(ulong cycle,ulong persistenceCycles=34_400)
    {
        if(persistenceCycles==0)throw new ArgumentOutOfRangeException(nameof(persistenceCycles));
        cycle=Math.Min(cycle,DurationCycles);ulong start=cycle>persistenceCycles ? cycle-persistenceCycles : 0;
        var duty=new double[128];
        int at=LastAt(lamps.Length,index=>lamps[index].Cycle,start);
        ulong cursor=start;
        while(cursor<cycle) {
            var frame=lamps[at];ulong next=at+1<lamps.Length ? Math.Min(cycle,lamps[at+1].Cycle) : cycle;
            double fraction=(next-cursor)/(double)persistenceCycles;
            for(int bit=0;bit<8;bit++) {
                if((frame.Low&(1<<bit))!=0)duty[frame.Column*8+bit]+=fraction;
                if((frame.High&(1<<bit))!=0)duty[64+frame.Column*8+bit]+=fraction;
            }
            cursor=next;if(at+1<lamps.Length && lamps[at+1].Cycle<=cursor)at++;
        }
        var display=alpha[LastAt(alpha.Length,index=>alpha[index].Cycle,cycle)];
        return new(duty,display.Text,display.Pending,display.CurrentWin);
    }
    private static int LastAt(int count,Func<int,ulong> timestamp,ulong cycle)
    {
        int lo=0,hi=count;
        while(lo<hi){int mid=lo+(hi-lo)/2;if(timestamp(mid)<=cycle)lo=mid+1;else hi=mid;}
        return Math.Max(0,lo-1);
    }
}

// Uses elapsed wall time supplied by the host; no WPF, sleeps or game mutations.
public sealed class PlaybackTransport(double durationSeconds)
{
    public double DurationSeconds { get; }=double.IsFinite(durationSeconds) && durationSeconds>0 ? durationSeconds : throw new ArgumentOutOfRangeException(nameof(durationSeconds));
    public double PositionSeconds { get; private set; }
    public bool IsPlaying { get; private set; }
    private double speed=1;
    public double Speed {get=>speed;set=>speed=double.IsFinite(value) && value>0 ? value : throw new ArgumentOutOfRangeException(nameof(value));}
    public void Play(){if(PositionSeconds>=DurationSeconds)PositionSeconds=0;IsPlaying=true;}
    public void Pause()=>IsPlaying=false;
    public void Seek(double seconds){if(!double.IsFinite(seconds))throw new ArgumentOutOfRangeException(nameof(seconds));PositionSeconds=Math.Clamp(seconds,0,DurationSeconds);if(PositionSeconds==DurationSeconds)Pause();}
    public void Advance(TimeSpan elapsed){if(elapsed<TimeSpan.Zero)throw new ArgumentOutOfRangeException(nameof(elapsed));if(IsPlaying)Seek(PositionSeconds+elapsed.TotalSeconds*Speed);}
}

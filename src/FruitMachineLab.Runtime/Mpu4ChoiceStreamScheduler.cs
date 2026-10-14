namespace FruitMachineLab.Runtime;

public record ChoiceStreamEvent(string Kind,ushort Clock,ushort Cursor,byte Value,ushort Callback,
    byte Choice,byte Rate,byte Tempo,byte Gate,byte Flags,byte Pitch,byte Transpose,ushort Due=0);

/// <summary>
/// Recovered single-task sound-stream timing and choice effects. YM2413 synthesis,
/// register-cache/channel effects and concurrent tasks remain outside this subset.
/// </summary>
public sealed class Mpu4ChoiceStreamScheduler(Machine machine,ushort clock,Action<ChoiceStreamEvent>? observer=null)
{
    private sealed record Loop(byte Count,ushort Cursor);
    private readonly Stack<Loop> loops=new();
    private ushort cursor,due;
    private byte tempo=16,gate,flags,pitch,transpose;
    private byte remainingDuration;
    private ushort resume;
    public ushort Clock { get; private set; }=clock;
    public bool Active { get; private set; }
    public byte Choice=>machine.Memory[0x4F];
    private byte Fetch() { byte value=machine.Memory[cursor];cursor=Cell.Add(cursor,1);return value; }
    private void Emit(string kind,ushort at,byte value=0,ushort callback=0,ushort nextDue=0)=>
        observer?.Invoke(new(kind,Clock,at,value,callback,Choice,machine.Memory[0x4E],tempo,gate,flags,pitch,transpose,nextDue));

    public bool Queue(ushort stream)
    {
        if((machine.Memory[0x719B]&0x80)!=0)return false; // native 60C8 early return
        if(Active)throw new NotSupportedException("Concurrent sound tasks require further scheduler recovery");
        cursor=stream;tempo=16;gate=0;flags=0;pitch=0;transpose=0;loops.Clear();resume=0;
        due=Cell.Add(Clock,1);Active=true;return true;
    }
    public static ushort ScaleDelay(byte duration,byte globalRate,byte localTempo,byte taskFlags)
    {
        uint rate=(taskFlags&0x80)!=0 ? globalRate : 16u;
        ushort ticks=(ushort)(duration*rate*localTempo/256u);
        return ticks==0 ? (ushort)1 : ticks;
    }
    private void Wait(byte duration,ushort callback)
    {
        due=Cell.Add(Clock,ScaleDelay(duration,machine.Memory[0x4E],tempo,flags));resume=callback;
        Emit("wait",cursor,duration,callback,due);
    }
    public void AdvanceTicks(int ticks)
    {
        if(ticks<0)throw new ArgumentOutOfRangeException(nameof(ticks));
        for(int n=0;n<ticks;n++) { Clock=Cell.Add(Clock,1);if(Active && Clock==due)RunDueTask(); }
    }
    public bool Reset()
    {
        if((machine.Memory[0x719B]&0x80)!=0)return false;
        Active=false;loops.Clear();resume=0;WriteChoice(0,0x5B7E);
        machine.Memory[0x4D]=0;machine.Memory[0x4E]=16;machine.Memory[0x50]=16;
        return true;
    }
    private void WriteChoice(byte value,ushort pc)
    {
        Emit("choice",cursor,value,pc);machine.Memory[0x4F]=value;
    }
    private void BeginDuration(byte duration)
    {
        if(gate==0 || ((gate&1)!=0 && gate>=duration)) { Fetch();Wait(duration,0x5E1F);return; }
        if((gate&1)!=0) { remainingDuration=unchecked((byte)(duration-gate));Wait(gate,0x5DF0);return; }
        byte first=(byte)(duration*gate/256);
        remainingDuration=unchecked((byte)(duration-first));
        if(first!=0)Wait(first,0x5E07);
        else { Fetch();Wait(remainingDuration,0x5E17); }
    }
    private void RunDueTask()
    {
        if(resume is 0x5DF0 or 0x5E07) {
            Fetch();Wait(remainingDuration,resume==0x5DF0 ? (ushort)0x5DFA : (ushort)0x5E17);return;
        }
        resume=0;
        for(int budget=0;budget<10000;budget++)
        {
            ushort at=cursor;byte command=Fetch();Emit("command",at,command);
            if(command<0xC0)
            {
                // Notes below 60h continue immediately. Timed notes consume the
                // following duration; pitch/register/channel effects are not modeled.
                if(command>=0x60) { BeginDuration(machine.Memory[cursor]);return; }
                continue;
            }
            switch(command)
            {
                case 0xC0:
                    if(loops.Count!=0)throw new NotSupportedException("Sound return with loop/call state needs further recovery");
                    Active=false;return;
                case 0xC3:
                    if(loops.Count>=5)throw new InvalidOperationException("Native sound loop stack capacity exceeded");
                    var count=Fetch();loops.Push(new(count,cursor));break;
                case 0xC4:
                    if(loops.Count==0)throw new InvalidOperationException("Native sound loop stack underflow");
                    var frame=loops.Pop();byte left=frame.Count==0 ? (byte)0 : unchecked((byte)(frame.Count-1));
                    if(frame.Count==0 || left!=0) { loops.Push(frame with {Count=left});cursor=frame.Cursor; }
                    break;
                case 0xC6: Fetch();Fetch();break; // instrument-bank operand, YM effects outside timing subset
                case 0xC7: pitch=Fetch();break;
                case 0xC8: var offset=Fetch();pitch=offset==0 ? (byte)0 : unchecked((byte)(pitch+offset));break;
                case 0xC9: Fetch();break; // detune operand, register effects outside timing subset
                case 0xCC: tempo=Fetch();break;
                case 0xCD: var multiplier=Fetch();tempo=multiplier==0 ? (byte)16 : unchecked((byte)(tempo*multiplier/16));break;
                case 0xCE: Wait(Fetch(),0x5E29);return;
                case 0xCF: BeginDuration(machine.Memory[cursor]);return;
                case 0xD1: break; // channel release: no timing/choice mutation
                case 0xD2: WriteChoice(Fetch(),0x60A6);break;
                case 0xD3: WriteChoice(unchecked((byte)(Choice+Fetch())),0x60A6);break;
                case 0xD7: gate=Fetch();break;
                case 0xD8: flags|=0x80;break;
                default:throw new NotSupportedException($"Untranslated sound command {command:X2} at {at:X4}");
            }
        }
        throw new InvalidOperationException("Sound stream instruction budget exhausted without yielding");
    }
}

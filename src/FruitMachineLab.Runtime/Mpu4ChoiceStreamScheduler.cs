namespace FruitMachineLab.Runtime;

public record ChoiceStreamEvent(string Kind,ushort Clock,ushort Cursor,byte Value,ushort Callback,
    byte Choice,byte Rate,byte Tempo,byte Gate,byte Flags,byte Pitch,byte Transpose,ushort Due=0);

public record SoundContinuation(ushort Callback,IReadOnlyList<ushort> CallReturns);

/// <summary>
/// Recovered sound-stream timing and choice effects. YM2413 synthesis and
/// register-cache/channel effects remain outside this subset.
/// </summary>
public sealed class Mpu4ChoiceStreamScheduler(Machine machine,ushort clock,Action<ChoiceStreamEvent>? observer=null)
{
    private sealed record Frame(byte? Count,ushort Cursor);
    private sealed class TaskState
    {
        public readonly Stack<Frame> Frames=new();
        public ushort Cursor,Due,Resume,Root;
        public byte Tempo=16,Gate,Flags,Pitch,Transpose,RemainingDuration;
        public int StackBytes;
    }
    private readonly List<TaskState> tasks=new();
    private TaskState task=new();
    private Stack<Frame> loops=>task.Frames;
    private ushort cursor {get=>task.Cursor;set=>task.Cursor=value;}
    private ushort due {get=>task.Due;set=>task.Due=value;}
    private ushort resume {get=>task.Resume;set=>task.Resume=value;}
    private byte tempo {get=>task.Tempo;set=>task.Tempo=value;}
    private byte gate {get=>task.Gate;set=>task.Gate=value;}
    private byte flags {get=>task.Flags;set=>task.Flags=value;}
    private byte pitch {get=>task.Pitch;set=>task.Pitch=value;}
    private byte transpose {get=>task.Transpose;set=>task.Transpose=value;}
    private byte remainingDuration {get=>task.RemainingDuration;set=>task.RemainingDuration=value;}
    public ushort Clock { get; private set; }=clock;
    public bool Active=>tasks.Count!=0;
    public static byte DiatonicTranspose(byte current,byte increment)
    {
        if(increment==0)return 0;
        byte note=current,octave=0;
        if((sbyte)note<0){do{octave=unchecked((byte)(octave-12));note=unchecked((byte)(note+12));}while((sbyte)note<0);}
        else {do{octave=unchecked((byte)(octave+12));note=unchecked((byte)(note-12));}while((sbyte)note>=0);octave=unchecked((byte)(octave-12));note=unchecked((byte)(note+12));}
        if(note>=4)note++;
        note=unchecked((byte)((note>>1)+increment));
        if((sbyte)note<0){do{octave=unchecked((byte)(octave-12));note=unchecked((byte)(note+7));}while((sbyte)note<0);}
        else {do{octave=unchecked((byte)(octave+12));note=unchecked((byte)(note-7));}while((sbyte)note>=0);octave=unchecked((byte)(octave-12));note=unchecked((byte)(note+7));}
        note=(byte)(note<<1);if(note>4)note--;
        return unchecked((byte)(note+octave));
    }
    public int ActiveTasks=>tasks.Count;
    // Fresh queues need no adapter. Other boundary records require an explicit,
    // game-validated continuation; untyped sound stacks remain unsupported.
    public void RestoreQueuedNativeTasks(Func<ushort,SoundContinuation?>? resolveContinuation=null)
    {
        if(Active)throw new InvalidOperationException("Scheduler already active");
        var visited=new HashSet<ushort>();var restoredTasks=new List<TaskState>();
        for(ushort at=machine.ReadWord(0x47);at!=0;at=machine.ReadWord(at)) {
            if(!visited.Add(at) || at>0x7DA)throw new InvalidDataException("Invalid captured sound task list");
            bool fresh=machine.ReadWord(Cell.Add(at,4))==0x5D3B && machine.ReadWord(Cell.Add(at,6))==Cell.Add(at,0x25) && machine.ReadWord(Cell.Add(at,8))==machine.ReadWord(Cell.Add(at,0x13));
            var continuation=fresh ? null : resolveContinuation?.Invoke(at);
            if(!fresh && continuation is null)throw new NotSupportedException("Captured sound continuation is not a fresh queue");
            var restored=new TaskState{Root=machine.ReadWord(Cell.Add(at,0x13)),Cursor=machine.ReadWord(Cell.Add(at,8)),Due=machine.ReadWord(Cell.Add(at,2)),Tempo=machine.Memory[at+0xE],Gate=machine.Memory[at+0x10],Flags=machine.Memory[at+0x12],Pitch=machine.Memory[at+0xC],Transpose=machine.Memory[at+0xD]};
            if(continuation is not null) {
                // Only gate-free continuations directly resuming command fetch
                // are supported here. The game adapter validates typed ROM frames.
                if(restored.Gate!=0 || continuation.Callback is not (0x5E1F or 0x5E29) || continuation.Callback!=machine.ReadWord(Cell.Add(at,4)) || continuation.CallReturns.Count>8 || machine.ReadWord(Cell.Add(at,6))!=Cell.Add(at,(ushort)(0x25-2*continuation.CallReturns.Count)))throw new InvalidDataException("Invalid typed sound continuation");
                restored.Resume=continuation.Callback;
                foreach(ushort address in continuation.CallReturns){restored.StackBytes+=2;if(machine.ReadWord(Cell.Add(at,(ushort)(0x25-restored.StackBytes)))!=address)throw new InvalidDataException("Typed sound frame differs from native stack");restored.Frames.Push(new(null,address));}
            }
            restoredTasks.Add(restored);
        }
        tasks.AddRange(restoredTasks);
    }
    public byte Choice=>machine.Memory[0x4F];
    private byte Fetch() { byte value=machine.Memory[cursor];cursor=Cell.Add(cursor,1);return value; }
    private void Emit(string kind,ushort at,byte value=0,ushort callback=0,ushort nextDue=0)=>
        observer?.Invoke(new(kind,Clock,at,value,callback,Choice,machine.Memory[0x4E],tempo,gate,flags,pitch,transpose,nextDue));

    public bool Queue(ushort stream)
    {
        if((machine.Memory[0x719B]&0x80)!=0)return false; // native 60C8 early return
        // Native caller inserts at the active-list head, then sets due=clock+1.
        // Multi-task CPU entry preemption and exhausted allocator are not modeled.
        task=new(){Cursor=stream,Root=stream,Due=Cell.Add(Clock,1)};
        tasks.Insert(0,task);return true;
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
        ushort delay=unchecked((ushort)(due-Clock));
        int index=0;
        while(index<tasks.Count && unchecked((ushort)(tasks[index].Due-Clock))<=delay)index++;
        tasks.Insert(index,task); // native BLS places a yielded task after equal deadlines
    }
    public void AdvanceTicks(int ticks)
    {
        if(ticks<0)throw new ArgumentOutOfRangeException(nameof(ticks));
        for(int n=0;n<ticks;n++) {
            Clock=Cell.Add(Clock,1);
            int budget=10000;
            while(tasks.Count!=0 && tasks[0].Due==Clock) {
                if(--budget==0)throw new InvalidOperationException("Too many sound tasks without advancing time");
                task=tasks[0];tasks.RemoveAt(0);RunDueTask();
            }
        }
    }
    // Native5C7A removes the first matching root stream, preserving other tasks.
    // Hardware channel release and native allocator/free-list bytes remain outside this model.
    public bool Cancel(ushort stream)
    {
        if((machine.Memory[0x719B]&0x80)!=0)return false;
        int index=tasks.FindIndex(item=>item.Root==stream);if(index>=0)tasks.RemoveAt(index);return true;
    }
    public bool Reset()
    {
        if((machine.Memory[0x719B]&0x80)!=0)return false;
        tasks.Clear();loops.Clear();resume=0;WriteChoice(0,0x5B7E);
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
                    if(loops.Count==0)return;
                    var call=loops.Pop();
                    if(call.Count is not null)throw new NotSupportedException("Sound return over loop bytes needs explicit evidence");
                    task.StackBytes-=2;cursor=call.Cursor;break;
                case 0xC1:
                    if(task.StackBytes>14)throw new InvalidOperationException("Native sound call stack capacity exceeded");
                    ushort target=(ushort)((Fetch()<<8)|Fetch());
                    loops.Push(new(null,cursor));task.StackBytes+=2;cursor=target;break;
                case 0xC2:
                    ushort child=(ushort)((Fetch()<<8)|Fetch());
                    tasks.Insert(0,new(){Cursor=child,Root=child,Due=Clock,Tempo=tempo,Gate=gate,Flags=flags,Pitch=pitch,Transpose=transpose});break;
                case 0xC3:
                    if(task.StackBytes>13)throw new InvalidOperationException("Native sound loop stack capacity exceeded");
                    var count=Fetch();loops.Push(new(count,cursor));task.StackBytes+=3;break;
                case 0xC4:
                    if(loops.Count==0)throw new InvalidOperationException("Native sound loop stack underflow");
                    var frame=loops.Pop();if(frame.Count is not { } loopCount)throw new NotSupportedException("Sound loop over call bytes needs explicit evidence");
                    byte left=loopCount==0 ? (byte)0 : unchecked((byte)(loopCount-1));
                    if(frame.Count==0 || left!=0) { loops.Push(frame with {Count=left});cursor=frame.Cursor; }
                    else task.StackBytes-=3;
                    break;
                case 0xC5: Fetch();break; // instrument register operand; audio effects remain separate
                case 0xDB:
                case 0xDD: Fetch();break; // same 5F5B table/register helper, no timing or tracked task-state mutation
                case 0xC6: Fetch();Fetch();break; // instrument-bank operand, YM effects outside timing subset
                case 0xC7: pitch=Fetch();break;
                case 0xC8: var offset=Fetch();pitch=offset==0 ? (byte)0 : unchecked((byte)(pitch+offset));break;
                case 0xC9: Fetch();break; // detune operand, register effects outside timing subset
                case 0xCA: Fetch();break; // volume operand; no timing/choice mutation
                case 0xCB: Fetch();break; // native 5F92 relative attenuation: register cache only
                case 0xCC: tempo=Fetch();break;
                case 0xCD: var multiplier=Fetch();tempo=multiplier==0 ? (byte)16 : unchecked((byte)(tempo*multiplier/16));break;
                case 0xCE: Wait(Fetch(),0x5E29);return;
                case 0xCF: BeginDuration(machine.Memory[cursor]);return;
                case 0xD1: break; // channel release: no timing/choice mutation
                case 0xD0: break; // sustain flag: channel/register effects only
                case 0xD2: WriteChoice(Fetch(),0x60A6);break;
                case 0xD3: WriteChoice(unchecked((byte)(Choice+Fetch())),0x60A6);break;
                case 0xD7: gate=Fetch();break;
                case 0xD8: flags|=0x80;break;
                case 0xDA: transpose=DiatonicTranspose(transpose,Fetch());break;
                default:throw new NotSupportedException($"Untranslated sound command {command:X2} at {at:X4}");
            }
        }
        throw new InvalidOperationException("Sound stream instruction budget exhausted without yielding");
    }
}

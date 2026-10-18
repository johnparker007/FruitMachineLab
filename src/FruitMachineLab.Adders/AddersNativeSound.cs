using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Explicit bounded owner of native task memory and one5CD0 service invocation.
// Host chooses when service is called; this class invents no IRQ/cadence.
public sealed class AddersNativeSound(Machine machine,Action<byte,byte>? ymWrite=null) : IDisposable
{
    private NativeRoutineExecution? running;
    private AddersSoundServicePlan? plan;
    private bool disposed;
    public bool Owns(Machine state)=>ReferenceEquals(machine,state);
    public bool Active=>machine.ReadWord(0x47)!=0;
    public bool Servicing=>running is not null;
    public ulong Cycle {get;private set;}
    public ushort? Address=>running?.Address;
    public ushort? LastAddress {get;private set;}
    public ulong NextEventCycle=>running?.NextEventCycle ?? ulong.MaxValue;
    public bool Paused {get;private set;}
    public string? Fault {get;private set;}
    public int CompletedTasks {get;private set;}
    public int CompletedCalls {get;private set;}
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}
    private void Foreground(){ObjectDisposedException.ThrowIf(disposed,this);if(Fault is not null)throw new InvalidOperationException(Fault);if(Servicing)throw new InvalidOperationException("Native sound service owns task memory");}
    public bool Queue(ushort stream){Foreground();return AddersSoundQueueMemory.Queue(machine,stream);}
    public bool Cancel(ushort stream){Foreground();return AddersSoundLifecycleMemory.Cancel(machine,stream,ymWrite);}
    public bool Reset()
    {
        Foreground();if((machine.Memory[0x719B]&0x80)!=0)return false;
        machine.Memory[0x4D]=0;machine.Memory[0x4E]=16;machine.Memory[0x4F]=0;machine.Memory[0x50]=16;
        AddersSoundResetMemory.Apply(machine,ymWrite);return true;
    }
    public void BeginService(ulong cycle,ushort stack,ushort u,ushort x,ushort y,bool irqMasked,ushort returnAddress=0x4C34)
    {
        BeginCall(0x5CD0,cycle,stack,u,x,y,0,0,irqMasked,returnAddress);
    }
    // Native helper entry only: VM->native wrapper costs/frames remain caller-owned.
    // returnAddress is the caller's continuation word (default preserves 4C34).
    public void BeginCall(ushort entry,ulong cycle,ushort stack,ushort u,ushort x,ushort y,byte a,byte b,bool irqMasked,ushort returnAddress=0x4C34)
    {
        Foreground();if(Paused)throw new InvalidOperationException("Native sound is paused");if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        IEnumerable<NativeRoutineWork> instructions=entry switch {
            0x5CD0=>(plan=new(machine,stack,u,x,y,ymWrite:ymWrite)).Instructions(),
            0x5C18=>new AddersSoundQueuePlan(machine,x,stack,y,a,b).Instructions(),
            0x5C7A=>new AddersSoundCancelPlan(machine,x,stack,y,u,a,b,ymWrite).Instructions(),
            0x5B77=>new AddersSoundResetPlan(machine,stack,x,y,a,b,ymWrite).Instructions(),
            _=>throw new NotSupportedException("Unrecovered native sound entry")};
        Cycle=cycle;LastAddress=null;running=new(instructions,cycle,returnAddress,()=>irqMasked);
        running.ObserveInstruction=i=>ObserveInstruction?.Invoke(i);
    }
    public void AdvanceTo(ulong cycle)
    {
        ObjectDisposedException.ThrowIf(disposed,this);if(Paused)return;if(Fault is not null)throw new InvalidOperationException(Fault);
        var execution=running ?? throw new InvalidOperationException("No native sound service is active");
        try{execution.AdvanceTo(cycle);Cycle=execution.Cycle;if(execution.Completed){LastAddress=execution.Address;CompletedTasks+=plan?.CompletedTasks ?? 0;CompletedCalls++;execution.Dispose();running=null;plan=null;}}
        catch(Exception e){Cycle=execution.Cycle;Fault=e.Message;Paused=true;execution.Dispose();throw;}
    }
    public void Pause()=>Paused=true;
    public void Resume(){if(Fault is not null)throw new InvalidOperationException(Fault);Paused=false;}
    public void Dispose(){running?.Dispose();disposed=true;Paused=true;}
}

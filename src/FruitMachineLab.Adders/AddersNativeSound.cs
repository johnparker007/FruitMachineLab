using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Explicit bounded owner of native task memory and one5CD0 service invocation.
// Host chooses when service is called; this class invents no IRQ/cadence.
public sealed class AddersNativeSound(Machine machine,Action<byte,byte>? ymWrite=null)
{
    private NativeRoutineExecution? running;
    private AddersSoundServicePlan? plan;
    public bool Owns(Machine state)=>ReferenceEquals(machine,state);
    public bool Active=>machine.ReadWord(0x47)!=0;
    public bool Servicing=>running is not null;
    public ulong Cycle {get;private set;}
    public ushort? Address=>running?.Address;
    public ulong NextEventCycle=>running?.NextEventCycle ?? ulong.MaxValue;
    public bool Paused {get;private set;}
    public string? Fault {get;private set;}
    public int CompletedTasks {get;private set;}
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}
    private void Foreground(){if(Fault is not null)throw new InvalidOperationException(Fault);if(Servicing)throw new InvalidOperationException("Native sound service owns task memory");}
    public bool Queue(ushort stream){Foreground();return AddersSoundQueueMemory.Queue(machine,stream);}
    public bool Cancel(ushort stream){Foreground();return AddersSoundLifecycleMemory.Cancel(machine,stream,ymWrite);}
    public bool Reset()
    {
        Foreground();if((machine.Memory[0x719B]&0x80)!=0)return false;
        machine.Memory[0x4D]=0;machine.Memory[0x4E]=16;machine.Memory[0x4F]=0;machine.Memory[0x50]=16;
        AddersSoundResetMemory.Apply(machine,ymWrite);return true;
    }
    public void BeginService(ulong cycle,ushort stack,ushort u,ushort x,ushort y,bool irqMasked)
    {
        Foreground();if(Paused)throw new InvalidOperationException("Native sound is paused");if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        Cycle=cycle;plan=new(machine,stack,u,x,y,ymWrite:ymWrite);running=new(plan.Instructions(),cycle,0x4C34,()=>irqMasked);
        running.ObserveInstruction=i=>ObserveInstruction?.Invoke(i);
    }
    public void AdvanceTo(ulong cycle)
    {
        if(Paused)return;if(Fault is not null)throw new InvalidOperationException(Fault);
        var execution=running ?? throw new InvalidOperationException("No native sound service is active");
        try{execution.AdvanceTo(cycle);Cycle=execution.Cycle;if(execution.Completed){CompletedTasks+=plan!.CompletedTasks;execution.Dispose();running=null;plan=null;}}
        catch(Exception e){Cycle=execution.Cycle;Fault=e.Message;Paused=true;execution.Dispose();throw;}
    }
    public void Pause()=>Paused=true;
    public void Resume(){if(Fault is not null)throw new InvalidOperationException(Fault);Paused=false;}
}

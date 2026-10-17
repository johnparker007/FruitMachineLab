namespace FruitMachineLab.Runtime;

// Selected scan/input/panel CPU owner. Timer3 acceptance is generated at a
// completed unmasked instruction; no recorded IRQ timestamp/path is consumed.
// Scan entry, initial hardware/RAM state and later outer service are supplied.
public sealed class Mpu4TimedPanelService : IDisposable
{
    private readonly Machine m;
    private readonly Mpu4Timer3PhaseClock timer;
    private readonly Func<ulong,decimal> time;
    private readonly Func<byte,byte> input;
    private readonly Func<ushort,byte> read;
    private readonly Action<ushort,byte> write;
    private Mpu4OutputScanExecution? scan;
    private Mpu4InputServiceExecution? prefix;
    private Mpu4PanelAccumulationExecution? panel;
    private Mpu4Timer3DispatchExecution? dispatch;
    private Mpu4LampCallbackExecution? callback;
    private Mpu4OrdinaryIrqReturnExecution? epilogue;
    private ulong? entry;
    public ulong Cycle {get;private set;}
    public bool Completed {get;private set;}
    public ulong NextEventCycle=>Completed ? ulong.MaxValue : entry ?? epilogue?.NextEventCycle ?? callback?.NextEventCycle ?? dispatch?.NextEventCycle ?? panel?.NextEventCycle ?? prefix?.NextEventCycle ?? scan!.NextEventCycle;
    public ushort? ScanAddress=>scan?.Address;
    public ushort? InputAddress=>prefix?.Address;
    public ushort? PanelAddress=>panel?.Address;
    public bool InterruptActive=>entry.HasValue || dispatch is not null || callback is not null || epilogue is not null;
    public ulong? NextDispatchEvent=>dispatch?.NextEventCycle;
    public ulong? NextCallbackEvent=>callback?.NextEventCycle;
    public int Interrupts {get;private set;}
    public Action<OutputScanInstruction>? ObserveScan {get;set;}
    public Action<OutputScanInstruction>? ObserveInput {get;set;}
    public Action<OutputScanInstruction>? ObservePanel {get;set;}
    public Action<OutputScanAccess>? ObserveScanAccess {get;set;}
    public Action<OutputScanAccess>? ObserveInputAccess {get;set;}
    public Action<ulong,Timer3Arm>? ObserveArm {get;set;}
    public Action<ulong>? ObserveAcceptance {get;set;}
    public Action<ulong>? ObserveEntry {get;set;}
    public Action<Timer3DispatchWrite>? ObserveDispatchWrite {get;set;}
    public Action<ulong>? ObserveCallbackEntry {get;set;}
    public Action<LampCallbackWrite>? ObserveCallbackWrite {get;set;}
    public Action<ulong>? ObserveCallbackComplete {get;set;}
    public Action<ulong>? ObserveReturn {get;set;}
    public Mpu4TimedPanelService(Machine machine,ulong start,Mpu4Timer3PhaseClock timer,Func<ulong,decimal> time,Func<byte,byte> input,Func<ushort,byte> read,Action<ushort,byte> write,bool afterScan=false)
    {
        m=machine;Cycle=start;this.timer=timer;this.time=time;this.input=input;this.read=read;this.write=write;
        if(afterScan){StartInput();return;}
        var arm=new Mpu4Timer3ArmHardware(timer,time);scan=new(m,start);scan.ObserveInstruction=i=>ObserveScan?.Invoke(i);scan.ObserveAccess=a=>{arm.Access(a);ObserveScanAccess?.Invoke(a);};scan.ObserveArm=(at,value)=>{if(value.Timer!=40)throw new NotSupportedException("Timed panel service requires the selected40-cycle latch; scan IRQ masking for other pulses is unresolved");ObserveArm?.Invoke(at,value);};
    }
    public void AdvanceTo(ulong target)
    {
        if(target<Cycle)throw new ArgumentOutOfRangeException(nameof(target));
        while(!Completed && NextEventCycle<=target){Cycle=NextEventCycle;Step();}Cycle=target;
    }
    private void Step()
    {
        if(entry.HasValue){entry=null;dispatch=new(m,Cycle,new Mpu4Timer3DispatchHardware(timer,Cycle,time(Cycle)));ObserveEntry?.Invoke(Cycle);return;}
        if(dispatch is not null){dispatch.AdvanceTo(Cycle,w=>ObserveDispatchWrite?.Invoke(w));if(dispatch.Completed){dispatch=null;callback=new(m,Cycle);ObserveCallbackEntry?.Invoke(Cycle);}return;}
        if(callback is not null){callback.AdvanceTo(Cycle,w=>ObserveCallbackWrite?.Invoke(w));if(callback.Completed){callback=null;ObserveCallbackComplete?.Invoke(Cycle);epilogue=new(Cycle,0,0x80);}return;}
        if(epilogue is not null){epilogue.AdvanceTo(Cycle);if(epilogue.Completed){epilogue=null;panel?.SuspendUntil(Cycle);prefix?.SuspendUntil(Cycle);timer.AdvanceTo(time(Cycle));Interrupts++;ObserveReturn?.Invoke(Cycle);}return;}
        if(scan is not null){scan.AdvanceTo(Cycle);if(scan.Completed){scan.Dispose();scan=null;StartInput();}return;}
        if(prefix is not null){prefix.AdvanceTo(Cycle);if(prefix.Completed){if(prefix.Continuation!=0x438C)throw new NotSupportedException($"Timed input continuation {prefix.Continuation:X4}");prefix.Dispose();prefix=null;panel=new(m,Cycle,()=>read(0xC02),m.Memory[0x43E4],true,true,read,write);panel.ObserveInstruction=i=>ObservePanel?.Invoke(i);}CheckInterrupt();return;}
        panel!.AdvanceTo(Cycle);CheckInterrupt();
        if(panel.Completed && !InterruptActive){if(panel.Continuation!=0x280C)throw new NotSupportedException($"Timed panel continuation {panel.Continuation:X4}");if(timer.Enabled || timer.InterruptPending)throw new NotSupportedException("Timer3 needs an instruction boundary in the remaining outer service");Completed=true;}
    }
    private void CheckInterrupt()
    {
        timer.AdvanceTo(time(Cycle));if(!timer.IrqAsserted)return;
        if(panel?.Completed==true || prefix?.Completed==true)throw new NotSupportedException("IRQ at an unresolved service transition");
        entry=checked(Cycle+M6809IrqEntry.EntryCycles);ObserveAcceptance?.Invoke(Cycle);
    }
    private void StartInput(){prefix=new(m,Cycle,input);prefix.ObserveInstruction=i=>ObserveInput?.Invoke(i);prefix.ObserveAccess=a=>ObserveInputAccess?.Invoke(a);}
    public void Dispose(){scan?.Dispose();prefix?.Dispose();panel?.Dispose();}
}

using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Source-derived CPU work for native start-tone setup: VM word80A4 ->776F
// bridge ->5A14/59FF/59D9 -> foreground5C18 -> return. Interrupt work is
// excluded; the selected natural setup phase has no outer IRQ envelope.
// ROM bytes: 00FC/00FE RAM NEXT template,776F..777C,777E..778B (payout-word-data),
//5A14..5A1C/59D9..59E9 (nudge-encoding-checkpoint),5C18..5C4F/60C8..60D5
// (collection/sound-queue). No recorded duration is used.
public static class AddersToneSetupTiming
{
    private static ulong Cost(string bytes)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(bytes)).Cycles;
    private static ulong Branch(string bytes,bool taken)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(bytes),taken).Cycles;

    // 80A4 points at776F: LDA F1; BEQ777A; optional mode write; PSHS Y; JSR5A14.
    public static ulong BridgeCycles(Machine machine)
    {
        ulong cycles=Cost("AEA1")+Cost("6E91")+Cost("96F1");
        if(machine.Memory[0xF1]==0)cycles+=Branch("2707",true);
        else cycles+=Branch("2707",false)+Cost("8A01")+Cost("97F1")+Cost("B7080C");
        return cycles+Cost("3420")+Cost("AD94");
    }

    // 5A14 wrapper/59FF/59D9 prologue through the JSR5C18 boundary.
    public static ulong WrapperCycles {get;}=Cost("3406")+Cost("8691")+Cost("C602")+Cost("8DE3")+
        Cost("3406")+Cost("1F89")+Cost("8DD4")+
        Cost("3416")+Cost("C060")+Branch("2A02",true)+Cost("D74D")+Cost("8E59EB")+Cost("BD5C18");

    // Foreground5C18 allocation path on a temporary copy, including the60C8
    // gate and the rate/attenuation branch. It uses the actual native free-list
    // head. The selected natural start-tone path has an available record
    // (native reset5B97/5B9A starts at01A0); a zero head takes the real
    // empty-list branch instead of an injected budget. Exhausted-pool and
    // prior-list variants remain explicit boundaries.
    public static ulong QueueCycles(Machine machine,ushort stream=0x59EB,byte a=0x91,byte b=0x31)
    {
        // Only memory is copied: the queue plan's side effects are memory writes.
        // The caller's Data stack, control stack and local frame are never touched.
        var copy=new Machine();
        Array.Copy(machine.Memory,copy.Memory,copy.Memory.Length);
        ushort head=copy.ReadWord(0x49);
        if(head!=0) {
            try {AddersSoundLifecycleMemory.ValidateTask(head);}
            catch(NotSupportedException error) {throw new NotSupportedException($"Start-tone queue head {head:X4} is not in the recovered sound task pool",error);}
        }
        var plan=new AddersSoundQueuePlan(copy,stream,0x700,head,a,b);
        ulong cycles=0;
        foreach(var work in plan.Instructions()) {
            if(work is not NativeRoutineStep step)throw new NotSupportedException("Tone queue timing contains an unsupported call");
            cycles+=Cost(step.Bytes);
            step.Effect?.Invoke();
        }
        return cycles;
    }

    public static ulong Cycles(Machine machine)=>BridgeCycles(machine)+WrapperCycles+QueueCycles(machine)+Cost("3596");
}

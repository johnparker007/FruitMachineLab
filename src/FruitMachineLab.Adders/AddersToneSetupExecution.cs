using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

// Only captured/source-derived registers are claimed. Native sound plans have
// no CPU flag file, so CC and DP are deliberately outside this state.
public readonly record struct AddersToneSetupState(
    ulong Cycle,ushort PC,ushort S,ushort X,ushort Y,ushort U,byte A,byte B);

public sealed record AddersToneSetupResult(
    AddersToneSetupState QueueEntry,
    AddersToneSetupState Foreground5A05,
    ulong WrapperCycles,
    ulong QueueCycles,
    ulong ReturnCycles,
    ushort QueueReturn,
    byte[] QueueEntryMemory);

// Smallest independently captured start-tone setup boundary:
//5A14 PSHS B A; LDA #91; LDB #02; BSR59FF; PSHS B A; TFR A,B; BSR59D9;
// PSHS X B A; SUBB #60; BPL59E1; STB <4D; LDX #59EB; JSR5C18; then the
// existing AddersNativeSound queue owner on the SAME Machine; 59E9 PULS A B X PC
// returns to5A05. The caller supplies the captured5A14 registers and a single
// initial 2 KB frame. No clone is used and no byte is reseeded after entry.
public static class AddersToneSetupExecution
{
    public const ushort ForegroundEntry=0x5A14;
    public const ushort QueueEntry=0x5C18;
    public const ushort QueueContinuation=0x59E9;
    public const ushort Foreground5A05=0x5A05;
    public const ushort Stream=0x59EB;
    public const byte Tone=0x91;
    public const byte Duration=0x02;
    // Deepest live frame below the5A14 entry S: PSHS2+BSR59FF2+59FF PSHS2+
    // BSR59D9 2+59D9 PSHS4=12, then JSR5C18 2+5C1B PSHS6+BSR5C51 2=22.
    // The transient60C8 PSHS B/LEAS3 is shallower; S=22 writes its BSR word to0/1.
    public const ushort MinimumStackPointer=22;

    private static ulong Cost(string bytes,bool? taken=null)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(bytes),taken).Cycles;

    public static ulong WrapperCycles {get;}=Cost("3406")+Cost("8691")+Cost("C602")+Cost("8DE3")+
        Cost("3406")+Cost("1F89")+Cost("8DD4")+Cost("3416")+Cost("C060")+Cost("2A02",true)+
        Cost("D74D")+Cost("8E59EB")+Cost("BD5C18");

    public static ulong ReturnCycles {get;}=Cost("3596");

    public static AddersToneSetupResult Execute(
        AddersNativeSound sound,
        Machine machine,
        ulong startCycle,
        ushort s,
        ushort u,
        ushort x,
        ushort y,
        byte a,
        byte b,
        bool irqMasked=false)
    {
        ArgumentNullException.ThrowIfNull(sound);
        ArgumentNullException.ThrowIfNull(machine);
        if(!sound.Owns(machine))throw new InvalidOperationException("Native sound owner belongs to a different machine");
        if(sound.Servicing)throw new InvalidOperationException("Native sound service owns task memory");
        if(sound.Paused)throw new InvalidOperationException("Native sound is paused");
        if(sound.Fault is not null)throw new InvalidOperationException(sound.Fault);
        if(startCycle<sound.Cycle)throw new ArgumentOutOfRangeException(nameof(startCycle));
        if(s<MinimumStackPointer)throw new ArgumentOutOfRangeException(nameof(s));
        if((machine.Memory[0x719B]&0x80)!=0)throw new NotSupportedException("719B bit80 disabled-tone setup requires independent evidence");
        if(sound.Active || machine.ReadWord(0x47)!=0)throw new InvalidDataException("A native tone task is already active");
        // The selected setup contract requires a real native allocation. Reject an
        // empty free pool here, before the wrapper writes its stack/004D frame; a
        // nonzero head reuses the same pool validation as the native queue path.
        ushort head=machine.ReadWord(0x49);
        if(head==0)throw new InvalidDataException("Native tone setup requires a free sound task, but the free pool is empty");
        AddersSoundLifecycleMemory.ValidateTask(head);

        ulong cycle=startCycle;
        void Step(string bytes,Action effect){cycle=checked(cycle+Cost(bytes));effect();}

        Step("3406",()=>{s-=2;machine.Memory[s]=a;machine.Memory[Cell.Add(s,1)]=b;});
        Step("8691",()=>a=Tone);
        Step("C602",()=>b=Duration);
        Step("8DE3",()=>{s-=2;machine.WriteWord(s,0x5A1C);});
        Step("3406",()=>{s-=2;machine.Memory[s]=a;machine.Memory[Cell.Add(s,1)]=b;});
        Step("1F89",()=>b=a);
        Step("8DD4",()=>{s-=2;machine.WriteWord(s,Foreground5A05);});
        Step("3416",()=>{
            s-=4;
            machine.Memory[s]=a;
            machine.Memory[Cell.Add(s,1)]=b;
            machine.WriteWord(Cell.Add(s,2),x);
        });
        Step("C060",()=>b=(byte)(b-0x60));
        // B=91 after59FF TFR, so91-60=31 is positive and BPL59E1 is taken.
        // The CB60 fallback stays explicit for a negative branch, matching the
        // source-derived Branch("2A02",true) used by WrapperCycles.
        bool bplTaken=(b&0x80)==0;
        cycle=checked(cycle+Cost("2A02",bplTaken));
        if(!bplTaken)Step("CB60",()=>b=(byte)(b+0x60));
        Step("D74D",()=>machine.Memory[0x4D]=b);
        Step("8E59EB",()=>x=Stream);
        Step("BD5C18",()=>{s-=2;machine.WriteWord(s,QueueContinuation);});

        ulong wrapperCycles=cycle-startCycle;
        var queueEntry=new AddersToneSetupState(cycle,QueueEntry,s,x,y,u,a,b);
        byte[] queueMemory=machine.Memory.AsSpan(0,0x800).ToArray();
        ulong queueStart=cycle;
        sound.BeginCall(QueueEntry,cycle,s,u,x,y,a,b,irqMasked,QueueContinuation);
        while(sound.Servicing)sound.AdvanceTo(sound.NextEventCycle);
        ulong queueCycles=sound.Cycle-queueStart;
        if(sound.LastAddress!=QueueContinuation)throw new InvalidDataException($"5C18 returned {sound.LastAddress:X4}, expected59E9");
        if(!sound.Active)throw new InvalidDataException("5C18 did not create the native tone task");

        // The5C4F PULS consumes the JSR5C18 word at s/s+1 and leaves S=s+2.
        // PULS A B X PC then reads the captured59D9 frame and the5A05 return.
        cycle=checked(cycle+queueCycles+ReturnCycles);
        ushort returnS=Cell.Add(s,2);
        byte finalA=machine.Memory[returnS];
        byte finalB=machine.Memory[Cell.Add(returnS,1)];
        ushort finalX=machine.ReadWord(Cell.Add(returnS,2));
        ushort pc=machine.ReadWord(Cell.Add(returnS,4));
        if(pc!=Foreground5A05)throw new InvalidDataException($"59E9 returned {pc:X4}, expected5A05");
        ushort finalS=Cell.Add(returnS,6);
        var end=new AddersToneSetupState(cycle,pc,finalS,finalX,y,u,finalA,finalB);
        return new(queueEntry,end,wrapperCycles,queueCycles,ReturnCycles,QueueContinuation,queueMemory);
    }
}

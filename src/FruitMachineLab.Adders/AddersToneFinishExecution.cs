using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

// Only captured/source-derived registers are claimed here. DP and CC are kept
// out of this record so a caller cannot mistake them for verified CPU state.
public readonly record struct AddersToneFinishState(
    ulong Cycle,ushort PC,ushort S,ushort X,ushort Y,ushort U,byte A,byte B);

// CC bits are E80 F40 H20 I10 N08 Z04 V02 C01. A zero KnownMask bit is
// explicitly unknown; it does not mean the flag is known to be zero.
public readonly record struct AddersToneFinishFlags(byte KnownMask,byte Value)
{
    public const byte C=0x01,V=0x02,Z=0x04,N=0x08,Condition=0x0F;
    public static readonly AddersToneFinishFlags Unknown=new(0,0);
    public bool IsKnown(byte bits)=>(KnownMask&bits)==bits;
}

public sealed record AddersToneFinishResult(
    AddersToneFinishState CancelState,
    AddersToneFinishState FinalState,
    AddersToneFinishFlags LdxFlags,
    AddersToneFinishFlags CancelFlags,
    AddersToneFinishFlags FinalFlags,
    bool DpSourcePreserved,
    byte[] CancelMemory);

public static class AddersToneFinishExecution
{
    public const ushort CallerLdx=0x5A0A;
    public const ushort Call=0x5A0D;
    public const ushort CancelContinuation=0x5A10;
    public const ushort Finish=0x5A12;
    public const ushort Continuation=0x5A1C;
    public const ushort LoadedX=0x59EB;
    // Exact deepest live native frame below the 5A0A S:
    // JSR5C7A(2)+5C7D PSHS6+5C90 BSR2+5E2C PSHS U2+5E3E BSR2+60AB PSHS X2.
    // The 5C81 BSR frame has already unwound before 5C90. S=16 writes to 0..15.
    public const ushort MinimumStackPointer=16;

    private static ulong Cost(string bytes)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(bytes)).Cycles;

    // LDX #59EB: N=0 (bit15 clear), Z=0 (non-zero), V=0; C/H/I/F/E preserved.
    public static AddersToneFinishFlags AfterLdx(byte? entryCc)
    {
        if(entryCc is null)return new(AddersToneFinishFlags.N|AddersToneFinishFlags.Z|AddersToneFinishFlags.V,0);
        return new(0xFF,(byte)(entryCc.Value&~0x0E));
    }

    // CLR <4D sets N=0,Z=1,V=0,C=0 and leaves H/I/F/E unchanged. Those four
    // bits were already made unknown by the native cancel, so only N/Z/V/C are
    // exposed here. C=0 is independent of the entry CC.
    public static AddersToneFinishFlags AfterClr()=>new(AddersToneFinishFlags.Condition,AddersToneFinishFlags.Z);

    public static AddersToneFinishResult Execute(
        AddersNativeSound sound,
        Machine machine,
        ulong startCycle,
        ushort s,
        ushort y,
        ushort u,
        byte a,
        byte b,
        byte? cc,
        bool irqMasked=true)
    {
        ArgumentNullException.ThrowIfNull(sound);
        ArgumentNullException.ThrowIfNull(machine);
        if(!sound.Owns(machine))throw new InvalidOperationException("Native sound owner belongs to a different machine");
        if(sound.Servicing)throw new InvalidOperationException("Native sound service owns task memory");
        if(sound.Paused)throw new InvalidOperationException("Native sound is paused");
        if(sound.Fault is not null)throw new InvalidOperationException(sound.Fault);
        if(startCycle<sound.Cycle)throw new ArgumentOutOfRangeException(nameof(startCycle));
        if(s<MinimumStackPointer)throw new ArgumentOutOfRangeException(nameof(s));
        if((machine.Memory[0x719B]&0x80)!=0)throw new NotSupportedException("719B bit80 disabled-tone cancel requires independent evidence");
        if(machine.ReadWord(Cell.Add(s,2))!=Continuation)throw new InvalidDataException($"5A12 return word {machine.ReadWord(Cell.Add(s,2)):X4}, expected5A1C");
        AddersSoundLifecycleMemory.ValidateCancel(machine,LoadedX);
        AddersToneFinishFlags ldxFlags=AfterLdx(cc);

        ulong cycle=checked(startCycle+Cost("8E59EB"));
        ushort x=LoadedX;
        cycle=checked(cycle+Cost("BD5C7A"));
        ushort cancelS=Cell.Subtract(s,2);
        machine.WriteWord(cancelS,CancelContinuation);
        sound.BeginCall(0x5C7A,cycle,cancelS,u,x,y,a,b,irqMasked,CancelContinuation);
        while(sound.Servicing)sound.AdvanceTo(sound.NextEventCycle);
        cycle=sound.Cycle;
        if(sound.LastAddress!=CancelContinuation)throw new InvalidDataException($"5C7A returned {sound.LastAddress:X4}, expected5A10");
        // A/B are restored by the actual 5C95 PULS from the pushed caller frame;
        // X/Y are restored there too and U by the 5E6B PULS. The cancel plan has
        // no CC model, so every flag after 5C7A is explicitly unknown. DP is not
        // touched by any cancel/release instruction, but the fixture does not
        // retain DP, so it is reported as source-preserved, not captured.
        var cancelState=new AddersToneFinishState(cycle,CancelContinuation,s,x,y,u,a,b);
        AddersToneFinishFlags cancelFlags=AddersToneFinishFlags.Unknown;
        byte[] cancelMemory=machine.Memory.AsSpan(0,0x800).ToArray();

        cycle=checked(cycle+Cost("0F4D"));
        machine.Memory[0x4D]=0;
        AddersToneFinishFlags finalFlags=AfterClr();

        cycle=checked(cycle+Cost("3586"));
        byte finalA=machine.Memory[s];
        byte finalB=machine.Memory[Cell.Add(s,1)];
        ushort pc=(ushort)((machine.Memory[Cell.Add(s,2)]<<8)|machine.Memory[Cell.Add(s,3)]);
        if(pc!=Continuation)throw new InvalidDataException($"5A12 returned {pc:X4}, expected5A1C");
        ushort finalS=Cell.Add(s,4);
        var finalState=new AddersToneFinishState(cycle,pc,finalS,x,y,u,finalA,finalB);
        return new(cancelState,finalState,ldxFlags,cancelFlags,finalFlags,true,cancelMemory);
    }
}

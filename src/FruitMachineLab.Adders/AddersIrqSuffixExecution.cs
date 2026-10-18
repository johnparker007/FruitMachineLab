using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

// CC bits are E80 F40 H20 I10 N08 Z04 V02 C01. A zero KnownMask bit is
// explicitly unknown; it does not mean the flag is known to be zero. Native
// 5CD0 has no CPU register/flag file, so its post-service flags are unknown.
public readonly record struct AddersIrqSuffixFlags(byte KnownMask,byte Value)
{
    public const byte C=0x01,V=0x02,Z=0x04,N=0x08,Condition=0x0F;
    public static readonly AddersIrqSuffixFlags Unknown=new(0,0);
    public static AddersIrqSuffixFlags AfterClr()=>new(Condition,Z);
    public bool IsKnown(byte bits)=>(KnownMask&bits)==bits;
}

public sealed record AddersIrqSuffixNativeState(
    ulong Cycle,ushort PC,ushort S,AddersIrqSuffixFlags Flags,byte[] MemoryAfter);

public sealed record AddersIrqSuffixResult(
    AddersIrq6B4DZeroStateResult SixB4D,
    AddersMeterPulseResult MeterPulse,
    AddersIrq6B4DZeroState ServiceEntry,
    byte[] ServiceEntryMemory,
    AddersIrqSuffixNativeState Fecc,
    AddersIrqSuffixNativeState Fece,
    IReadOnlyList<OutputScanInstruction> ServiceInstructions);

public static class AddersIrqSuffixExecution
{
    public const ushort Fec3=0xFEC3;
    public const ushort Fec6=0xFEC6;
    public const ushort Fec9=0xFEC9;
    public const ushort Service=0x5CD0;
    public const ushort Fecc=0xFECC;
    public const ushort Fece=0xFECE;
    public const ushort ServiceReturnWord=0xFECC;
    public const ushort CapturedEntryS=AddersIrq6B4DZeroStateExecution.SuffixCaptureS;
    public const ushort CapturedServiceEntryS=0x078B;
    public const string Fec9CallBytes="BD5CD0";
    public const string FeccBytes="0F2C";

    public static ulong Fec9CallCycles {get;}=
        (ulong)M6809InstructionTiming.Decode(Convert.FromHexString(Fec9CallBytes)).Cycles;
    public static ulong FeccCycles {get;}=
        (ulong)M6809InstructionTiming.Decode(Convert.FromHexString(FeccBytes)).Cycles;

    public static AddersIrqSuffixResult Execute(
        Machine machine,ulong fec3Cycle,ushort fec3S,ushort fec3U,ushort fec3X,ushort fec3Y,byte fec3A,byte fec3B,byte fec3CC)
    {
        ArgumentNullException.ThrowIfNull(machine);
        if(fec3S!=CapturedEntryS)throw new NotSupportedException(
            $"IRQ suffix requires the independently captured FEC3 entry S={CapturedEntryS:X4}, got {fec3S:X4}");
        if(!machine.Memory.AsSpan(Fec9,Fec9CallBytes.Length/2)
            .SequenceEqual(Convert.FromHexString(Fec9CallBytes)))
            throw new NotSupportedException("FEC9 JSR 5CD0 bytes differ");
        if(!machine.Memory.AsSpan(Fecc,FeccBytes.Length/2).SequenceEqual(Convert.FromHexString(FeccBytes)))
            throw new NotSupportedException("FECC CLR 2C bytes differ");
        if(machine.ReadWord(Fec9+1)!=Service)
            throw new NotSupportedException("FEC9 JSR target is not 5CD0");
        if(machine.ReadWord(Fecc)!=0x0F2C)
            throw new NotSupportedException("FECC continuation is not CLR 2C");

        var six=AddersIrq6B4DZeroStateExecution.Execute(
            machine,fec3Cycle,fec3S,fec3U,fec3X,fec3Y,fec3A,fec3B,fec3CC);
        var atFec6=six.Return;

        var meter=AddersMeterPulseExecution.Execute(
            machine,atFec6.Cycle,atFec6.S,atFec6.U,atFec6.X,atFec6.Y,atFec6.A,atFec6.B,atFec6.CC);
        var atFec9=meter.ReturnState;

        if(atFec9.S!=CapturedEntryS)throw new NotSupportedException(
            $"58BB returned FEC9 S={atFec9.S:X4}, expected the captured {CapturedEntryS:X4}");
        ushort s=Cell.Subtract(atFec9.S,2);
        if(s!=CapturedServiceEntryS)throw new NotSupportedException(
            $"FEC9 JSR produced S={s:X4}, expected the captured {CapturedServiceEntryS:X4}");
        machine.WriteWord(s,ServiceReturnWord);
        ulong serviceCycle=checked(atFec9.Cycle+Fec9CallCycles);
        var serviceEntry=new AddersIrq6B4DZeroState(
            serviceCycle,Service,s,atFec9.U,atFec9.X,atFec9.Y,atFec9.A,atFec9.B,atFec9.CC);
        byte[] serviceMemory=machine.Memory.AsSpan(0,0x800).ToArray();

        var instructions=new List<OutputScanInstruction>();
        using(var sound=new AddersNativeSound(machine))
        {
            sound.ObserveInstruction=instructions.Add;
            sound.BeginCall(Service,serviceCycle,s,atFec9.U,atFec9.X,atFec9.Y,atFec9.A,atFec9.B,true,ServiceReturnWord);
            while(sound.Servicing)sound.AdvanceTo(sound.NextEventCycle);
            if(sound.Fault is not null)throw new InvalidDataException($"5CD0 service faulted: {sound.Fault}");
            if(sound.CompletedCalls!=1)throw new InvalidDataException(
                $"5CD0 service completed {sound.CompletedCalls} calls, expected 1");
            if(sound.LastAddress!=ServiceReturnWord)throw new InvalidDataException(
                $"5CD0 service continuation {sound.LastAddress:X4}, expected {ServiceReturnWord:X4}");
            ulong returnedCycle=sound.Cycle;
            ushort returnWord=machine.ReadWord(s);
            if(returnWord!=ServiceReturnWord)throw new InvalidDataException(
                $"FEC9 JSR stack word {returnWord:X4}, expected {ServiceReturnWord:X4}");
            s=Cell.Add(s,2);
            var fecc=new AddersIrqSuffixNativeState(
                returnedCycle,Fecc,s,AddersIrqSuffixFlags.Unknown,machine.Memory.AsSpan(0,0x800).ToArray());

            machine.Memory[0x2C]=0;
            ulong feceCycle=checked(returnedCycle+FeccCycles);
            var fece=new AddersIrqSuffixNativeState(
                feceCycle,Fece,s,AddersIrqSuffixFlags.AfterClr(),machine.Memory.AsSpan(0,0x800).ToArray());
            return new(six,meter,serviceEntry,serviceMemory,fecc,fece,instructions);
        }
    }
}

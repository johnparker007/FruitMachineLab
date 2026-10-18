using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

public readonly record struct AddersMeterPulseState(
    ulong Cycle,ushort PC,ushort S,ushort X,ushort Y,ushort U,byte A,byte B);

public sealed record AddersMeterPulseResult(
    AddersMeterPulseState CallState,
    AddersMeterPulseState ReturnState,
    ulong CallCycles,
    ulong HelperCycles,
    byte[] MemoryAfter);

public static class AddersMeterPulseExecution
{
    public const ushort Call=0xFEC6;
    public const ushort Entry=0x58BB;
    public const ushort Return=0xFEC9;
    public const ushort MinimumStackPointer=2;
    public const string CallBytes="BD58BB";
    public const string HelperBytes=
        "B6719B8504262D0D3A2B28963926458E03668609200610AE8126274C8C036A25F5"+
        "8E035E8601200610AE8126154C8C036625F5398E035ECC0000ED818C036A26F939"+
        "9739313F10AF1EBD6FECBD5924C628D73A390A3A2701390D392B0896398A809739"+
        "20E70F3920";

    private static ulong Cost(string bytes,bool? taken=null)=>
        (ulong)M6809InstructionTiming.Decode(Convert.FromHexString(bytes),taken).Cycles;

    public static ulong CallCycles {get;}=Cost(CallBytes);

    public static ulong HelperCycles {get;}=
        Cost("B6719B")+Cost("8504")+Cost("262D",false)+Cost("0D3A")+Cost("2B28",false)+
        Cost("9639")+Cost("2645",false)+Cost("8E0366")+Cost("8609")+Cost("2006")+
        3*Cost("8C036A")+3*Cost("25F5")+2*Cost("10AE81")+2*Cost("2627",false)+2*Cost("4C")+
        Cost("8E035E")+Cost("8601")+Cost("2006")+
        5*Cost("8C0366")+5*Cost("25F5")+4*Cost("10AE81")+4*Cost("2627",false)+4*Cost("4C")+
        Cost("39");

    public static ulong TotalCycles {get;}=CallCycles+HelperCycles;

    public static void Validate(Machine machine,ushort s)
    {
        ArgumentNullException.ThrowIfNull(machine);
        if(s<MinimumStackPointer)throw new ArgumentOutOfRangeException(nameof(s));
        if(!machine.Memory.AsSpan(Call,3).SequenceEqual(Convert.FromHexString(CallBytes)))
            throw new NotSupportedException("FEC6 JSR 58BB bytes differ");
        if(!machine.Memory.AsSpan(Entry,HelperBytes.Length/2).SequenceEqual(Convert.FromHexString(HelperBytes)))
            throw new NotSupportedException("58BB original helper bytes differ");
        if((machine.Memory[0x719B]&0x04)!=0)
            throw new NotSupportedException("58BB 719B bit2 clear-queue branch has no captured evidence");
        if((sbyte)machine.Memory[0x003A]<0)
            throw new NotSupportedException("58BB 003A negative early-return branch has no captured evidence");
        if(machine.Memory[0x0039]!=0)
            throw new NotSupportedException("58BB active meter branch has no captured evidence");
        for(ushort address=0x035E;address<0x036A;address+=2)
            if(machine.ReadWord(address)!=0)
                throw new NotSupportedException($"58BB nonzero meter word at {address:X4} has no captured evidence");
    }

    public static AddersMeterPulseResult Execute(
        Machine machine,ulong startCycle,ushort s,ushort u,ushort x,ushort y,byte a,byte b)
    {
        Validate(machine,s);
        var callState=new AddersMeterPulseState(startCycle,Call,s,x,y,u,a,b);
        ulong cycle=startCycle;
        void Step(string bytes,bool? taken=null){cycle=checked(cycle+Cost(bytes,taken));}

        Step(CallBytes);
        s=Cell.Subtract(s,2);
        machine.WriteWord(s,Return);

        Step("B6719B");a=machine.Memory[0x719B];
        Step("8504");
        Step("262D",false);
        Step("0D3A");
        Step("2B28",false);
        Step("9639");a=machine.Memory[0x0039];
        Step("2645",false);
        Step("8E0366");x=0x0366;
        Step("8609");a=0x09;
        Step("2006");
        while(true)
        {
            Step("8C036A");
            bool c=x<0x036A;
            Step("25F5",c);
            if(!c)break;
            Step("10AE81");
            ushort value=machine.ReadWord(x);
            y=value;
            x=Cell.Add(x,2);
            if(value!=0)throw new InvalidOperationException("58BB meter word changed during scanned path");
            Step("2627",false);
            Step("4C");a++;
        }

        Step("8E035E");x=0x035E;
        Step("8601");a=0x01;
        Step("2006");
        while(true)
        {
            Step("8C0366");
            bool c=x<0x0366;
            Step("25F5",c);
            if(!c)break;
            Step("10AE81");
            ushort value=machine.ReadWord(x);
            y=value;
            x=Cell.Add(x,2);
            if(value!=0)throw new InvalidOperationException("58BB meter word changed during scanned path");
            Step("2627",false);
            Step("4C");a++;
        }

        Step("39");
        if(machine.ReadWord(s)!=Return)
            throw new InvalidDataException($"58BB return word {machine.ReadWord(s):X4}, expected {Return:X4}");
        s=Cell.Add(s,2);

        var returnState=new AddersMeterPulseState(cycle,Return,s,x,y,u,a,b);
        return new(callState,returnState,CallCycles,HelperCycles,machine.Memory.AsSpan(0,0x800).ToArray());
    }
}


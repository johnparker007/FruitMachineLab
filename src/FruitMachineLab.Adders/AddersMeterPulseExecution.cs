using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

public readonly record struct AddersMeterPulseState(
    ulong Cycle,ushort PC,ushort S,ushort X,ushort Y,ushort U,byte A,byte B,byte CC);

public sealed record AddersMeterPulseResult(
    AddersMeterPulseState CallState,
    AddersMeterPulseState ReturnState,
    ulong CallCycles,
    ulong HelperCycles,
    byte[] MemoryAfter,
    IReadOnlyList<AddersMeterPulseState> Boundaries);

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
        Machine machine,ulong startCycle,ushort s,ushort u,ushort x,ushort y,byte a,byte b,byte cc=0)
    {
        Validate(machine,s);
        var callState=new AddersMeterPulseState(startCycle,Call,s,x,y,u,a,b,cc);
        var boundaries=new List<AddersMeterPulseState>(40);
        ulong cycle=startCycle;
        ushort pc=Call;

        void Record()=>boundaries.Add(new(cycle,pc,s,x,y,u,a,b,cc));
        void Step(string bytes,ushort address,ushort next,bool? taken=null,Action? effect=null)
        {
            if(pc!=address)throw new InvalidDataException(
                $"58BB expected PC {address:X4}, got {pc:X4}");
            Record();
            cycle=checked(cycle+Cost(bytes,taken));
            effect?.Invoke();
            pc=next;
        }

        Step(CallBytes,Call,Entry,effect:()=>{s=Cell.Subtract(s,2);machine.WriteWord(s,Return);});
        Step("B6719B",0x58BB,0x58BE,effect:()=>{a=machine.Memory[0x719B];cc=SetNZV(cc,a,8);});
        Step("8504",0x58BE,0x58C0,effect:()=>cc=SetNZV(cc,(byte)(a&0x04),8));
        Step("262D",0x58C0,0x58C2,taken:false);
        Step("0D3A",0x58C2,0x58C4,effect:()=>cc=SetNZV(cc,machine.Memory[0x003A],8));
        Step("2B28",0x58C4,0x58C6,taken:false);
        Step("9639",0x58C6,0x58C8,effect:()=>{a=machine.Memory[0x0039];cc=SetNZV(cc,a,8);});
        Step("2645",0x58C8,0x58CA,taken:false);
        Step("8E0366",0x58CA,0x58CD,effect:()=>{x=0x0366;cc=SetNZV(cc,x,16);});
        Step("8609",0x58CD,0x58CF,effect:()=>{a=0x09;cc=SetNZV(cc,a,8);});
        Step("2006",0x58CF,0x58D7);
        while(true)
        {
            Step("8C036A",0x58D7,0x58DA,effect:()=>cc=Compare16(cc,x,0x036A));
            bool carry=(cc&0x01)!=0;
            Step("25F5",0x58DA,carry?(ushort)0x58D1:(ushort)0x58DC,taken:carry);
            if(!carry)break;
            Step("10AE81",0x58D1,0x58D4,effect:()=>{y=machine.ReadWord(x);x=Cell.Add(x,2);cc=SetNZV(cc,y,16);});
            Step("2627",0x58D4,0x58D6,taken:false);
            Step("4C",0x58D6,0x58D7,effect:()=>{a=unchecked((byte)(a+1));cc=Increment(cc,a);});
        }

        Step("8E035E",0x58DC,0x58DF,effect:()=>{x=0x035E;cc=SetNZV(cc,x,16);});
        Step("8601",0x58DF,0x58E1,effect:()=>{a=0x01;cc=SetNZV(cc,a,8);});
        Step("2006",0x58E1,0x58E9);
        while(true)
        {
            Step("8C0366",0x58E9,0x58EC,effect:()=>cc=Compare16(cc,x,0x0366));
            bool carry=(cc&0x01)!=0;
            Step("25F5",0x58EC,carry?(ushort)0x58E3:(ushort)0x58EE,taken:carry);
            if(!carry)break;
            Step("10AE81",0x58E3,0x58E6,effect:()=>{y=machine.ReadWord(x);x=Cell.Add(x,2);cc=SetNZV(cc,y,16);});
            Step("2627",0x58E6,0x58E8,taken:false);
            Step("4C",0x58E8,0x58E9,effect:()=>{a=unchecked((byte)(a+1));cc=Increment(cc,a);});
        }

        Step("39",0x58EE,Return,effect:()=>
        {
            if(machine.ReadWord(s)!=Return)
                throw new InvalidDataException($"58BB return word {machine.ReadWord(s):X4}, expected {Return:X4}");
            s=Cell.Add(s,2);
        });
        boundaries.Add(new(cycle,Return,s,x,y,u,a,b,cc));

        var returnState=new AddersMeterPulseState(cycle,Return,s,x,y,u,a,b,cc);
        return new(callState,returnState,CallCycles,HelperCycles,machine.Memory.AsSpan(0,0x800).ToArray(),boundaries);
    }

    private static byte SetNZV(byte cc,ushort value,int bits)
    {
        cc=(byte)(cc&~0x0E);
        if(value==0)cc|=0x04;
        if((value&(1<<(bits-1)))!=0)cc|=0x08;
        return cc;
    }

    private static byte Increment(byte cc,byte value)
    {
        cc=SetNZV(cc,value,8);
        if(value==0x80)cc|=0x02;
        return cc;
    }

    private static byte Compare16(byte cc,ushort left,ushort right)
    {
        ushort result=unchecked((ushort)(left-right));
        cc=(byte)(cc&~0x0F);
        if(result==0)cc|=0x04;
        if((result&0x8000)!=0)cc|=0x08;
        if(((left^right)&(left^result)&0x8000)!=0)cc|=0x02;
        if(left<right)cc|=0x01;
        return cc;
    }
}

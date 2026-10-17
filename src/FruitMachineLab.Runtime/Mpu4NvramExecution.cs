namespace FruitMachineLab.Runtime;

// Selected native6E06/6E0D refresh. Software guard002C is not the CPU IRQ mask.
// Native S-frame residue belongs to the caller; the temporary byte on U is real.
public sealed class Mpu4NvramExecution : IDisposable
{
    private sealed record Step(ushort Address,string Bytes,Action? Effect=null,bool? Branch=null);
    private readonly Machine m;
    private readonly IEnumerator<Step> steps;
    private Step? pending;
    private byte a,b,mask;
    private ushort x,u;
    private bool negative,lower;
    private readonly byte incomingCc;
    private byte returnCc,additionFlags;
    public byte ReturnConditionCode=>Completed ? returnCc : throw new InvalidOperationException("NVRAM CC is available only at native return");
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle {get;private set;}
    public bool Completed {get;private set;}
    public string? Fault {get;private set;}
    public ushort Continuation {get;}
    public ushort Address=>pending?.Address ?? Continuation;
    public ushort DataPointer=>u;
    public bool IrqMasked=>(mask&0x10)!=0;
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}
    public Action<OutputScanAccess>? ObserveAccess {get;set;}
    public Mpu4NvramExecution(Machine machine,ulong start,ushort dataPointer,byte initialInterruptMask,ushort continuation)
    {
        m=machine;Cycle=start;u=dataPointer;incomingCc=initialInterruptMask;mask=(byte)(initialInterruptMask&0x50);Continuation=continuation;
        steps=Run().GetEnumerator();Next();
    }
    private static ulong Cost(Step s)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(s.Bytes),s.Branch).Cycles;
    private void Next(){if(!steps.MoveNext()){Completed=true;pending=null;NextEventCycle=ulong.MaxValue;return;}pending=steps.Current;NextEventCycle=checked(Cycle+Cost(pending));}
    public void AdvanceTo(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        if(Fault is not null)throw new InvalidOperationException(Fault);
        try{while(!Completed && NextEventCycle<=cycle){var s=pending!;ulong from=NextEventCycle-Cost(s);Cycle=NextEventCycle;s.Effect?.Invoke();ObserveInstruction?.Invoke(new(s.Address,s.Bytes,from,Cycle));Next();}Cycle=cycle;}
        catch(Exception e){Fault=e.Message;Dispose();throw;}
    }
    public void SuspendUntil(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        if(Fault is not null)throw new InvalidOperationException(Fault);
        if(IrqMasked)throw new InvalidOperationException("IRQ cannot suspend masked NVRAM execution");
        if(!Completed){if(NextEventCycle-Cycle!=Cost(pending!))throw new InvalidOperationException("Suspension requires an instruction boundary");NextEventCycle=checked(NextEventCycle+cycle-Cycle);}Cycle=cycle;
    }
    private void Write(ushort at,byte value){m.Memory[at]=value;ObserveAccess?.Invoke(new(Cycle,at,value,true,false));}
    private IEnumerable<Step> Run()
    {
        yield return new(0x6E06,"7D0323",()=>{byte value=m.Memory[0x323];negative=(sbyte)value<0;returnCc=(byte)((incomingCc&0xF1)|(negative ? 8 : 0)|(value==0 ? 4 : 0));});
        yield return new(0x6E09,"102BFFF8",Branch:negative);
        if(negative){yield return new(0x6E05,"39");yield break;}
        byte guard=0,savedMask=mask;
        yield return new(0x6E0D,"3417");yield return new(0x6E0F,"F6002C",()=>b=m.Memory[0x2C]);
        yield return new(0x6E12,"3404",()=>guard=b);yield return new(0x6E14,"C601",()=>b=1);
        yield return new(0x6E16,"F7002C",()=>Write(0x2C,b));yield return new(0x6E19,"F60322",()=>b=m.Memory[0x322]);
        yield return new(0x6E1C,"3604",()=>{u--;Write(u,b);});yield return new(0x6E1E,"8E02F0",()=>x=0x2F0);
        yield return new(0x6E21,"5F",()=>b=0);yield return new(0x6E22,"2009");
        while(true){yield return new(0x6E2D,"8C02FA",()=>lower=x<0x2FA);yield return new(0x6E30,"25F2");if(!lower)break;
            yield return new(0x6E24,"A684",()=>a=m.Memory[x]);yield return new(0x6E26,"43",()=>a=unchecked((byte)~a));
            yield return new(0x6E27,"A7890019",()=>Write(Cell.Add(x,0x19),a));yield return new(0x6E2B,"E080",()=>{b=unchecked((byte)(b-m.Memory[x]));x++;});}
        yield return new(0x6E32,"3502",()=>a=guard);yield return new(0x6E34,"B7002C",()=>Write(0x2C,a));
        yield return new(0x6E37,"3501",()=>mask=savedMask);yield return new(0x6E39,"2009");
        while(true){yield return new(0x6E44,"8C0309",()=>lower=x<0x309);yield return new(0x6E47,"25F2");if(!lower)break;
            yield return new(0x6E3B,"A684",()=>a=m.Memory[x]);yield return new(0x6E3D,"43",()=>a=unchecked((byte)~a));
            yield return new(0x6E3E,"A7890019",()=>Write(Cell.Add(x,0x19),a));yield return new(0x6E42,"E080",()=>{b=unchecked((byte)(b-m.Memory[x]));x++;});}
        yield return new(0x6E49,"C019",()=>b=unchecked((byte)(b-0x19)));yield return new(0x6E4B,"C019",()=>b=unchecked((byte)(b-0x19)));
        yield return new(0x6E4D,"B6002C",()=>a=m.Memory[0x2C]);yield return new(0x6E50,"3402",()=>guard=a);
        yield return new(0x6E52,"8601",()=>a=1);yield return new(0x6E54,"B7002C",()=>Write(0x2C,a));
        yield return new(0x6E57,"B60322",()=>a=m.Memory[0x322]);yield return new(0x6E5A,"A0C4",()=>a=unchecked((byte)(a-m.Memory[u])));
        yield return new(0x6E5C,"A7C4",()=>Write(u,a));yield return new(0x6E5E,"EBC0",()=>{byte delta=m.Memory[u];int sum=b+delta;additionFlags=(byte)((sum>255 ? 1 : 0)|((b&15)+(delta&15)>15 ? 0x20 : 0));b=(byte)sum;u++;});
        yield return new(0x6E60,"F70322",()=>Write(0x322,b));yield return new(0x6E63,"3504",()=>b=guard);
        yield return new(0x6E65,"F7002C",()=>{Write(0x2C,b);returnCc=(byte)((incomingCc&0xD0)|additionFlags|((sbyte)b<0 ? 8 : 0)|(b==0 ? 4 : 0));});yield return new(0x6E68,"3596");
    }
    public void Dispose()=>steps.Dispose();
}

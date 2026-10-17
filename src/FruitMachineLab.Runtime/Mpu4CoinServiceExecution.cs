namespace FruitMachineLab.Runtime;

// Original4592 service suffix of439F. Alarm48DA and helper46F1 are explicit
// boundaries. PIA reads/writes are device callbacks, never ordinary RAM access.
public sealed class Mpu4CoinServiceExecution : IDisposable
{
    private sealed record Step(ushort Address,string Bytes,Action? Effect=null,bool? Branch=null);
    private readonly Machine m;
    private readonly Func<ushort,byte> readPort;
    private readonly Action<ushort,byte> writePort;
    private readonly IEnumerator<Step> steps;
    private Step? pending;
    private Mpu4InlineAuxTestExecution? inline;
    private byte a,b;
    private ushort d;
    private bool zero;
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle {get;private set;}
    public bool Completed {get;private set;}
    public ushort Continuation {get;private set;}
    public ushort Address=>pending?.Address ?? Continuation;
    public OutputScanInstruction PendingInstruction=>pending is null ? throw new InvalidOperationException("Coin service completed") : new(pending.Address,pending.Bytes,NextEventCycle-Cost(pending),NextEventCycle);
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}
    public Mpu4CoinServiceExecution(Machine machine,ulong start,Func<ushort,byte> readPort,Action<ushort,byte> writePort){m=machine;this.readPort=readPort;this.writePort=writePort;Cycle=start;steps=Run().GetEnumerator();Next();}
    private static ulong Cost(Step s)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(s.Bytes),s.Branch).Cycles;
    private void Next(){if(!steps.MoveNext()){Completed=true;pending=null;NextEventCycle=ulong.MaxValue;return;}pending=steps.Current;NextEventCycle=checked(Cycle+Cost(pending));}
    public void AdvanceTo(ulong cycle){if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));while(!Completed && NextEventCycle<=cycle){var s=pending!;ulong from=NextEventCycle-Cost(s);Cycle=NextEventCycle;s.Effect?.Invoke();ObserveInstruction?.Invoke(new(s.Address,s.Bytes,from,Cycle));Next();}Cycle=cycle;}
    public void SuspendUntil(ulong cycle){if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));if(!Completed){if(NextEventCycle-Cycle!=Cost(pending!))throw new InvalidOperationException("IRQ suspension requires an instruction boundary");inline?.SuspendUntil(cycle);NextEventCycle=checked(NextEventCycle+(cycle-Cycle));}Cycle=cycle;}
    private IEnumerable<Step> Test(ushort operand)
    {
        using var child=new Mpu4InlineAuxTestExecution(m,Cycle,m.Memory[operand],operand);inline=child;
        while(!child.Completed){var s=child.PendingInstruction;yield return new(s.Address,s.Bytes,()=>child.AdvanceTo(Cycle));}
        inline=null;zero=child.Zero;
    }
    private IEnumerable<Step> Run()
    {
        yield return new(0x4592,"962B",()=>a=m.Memory[0x2B]);yield return new(0x4594,"2B68");
        if((a&0x80)!=0){foreach(var s in Inhibit())yield return s;yield break;}
        yield return new(0x4596,"48",()=>a=unchecked((byte)(a<<1)));yield return new(0x4597,"2B69");
        if((a&0x80)!=0){yield return new(0x4602,"862F",()=>a=0x2F);Continuation=0x4604;yield break;}
        yield return new(0x4599,"48",()=>a=unchecked((byte)(a<<1)));bool fault=(a&0x80)!=0;yield return new(0x459A,"102B0081",Branch:fault);
        if(fault){yield return new(0x461F,"8620",()=>a=0x20);Continuation=0x4621;yield break;}
        yield return new(0x459E,"B602F0",()=>a=m.Memory[0x2F0]);yield return new(0x45A1,"8150");yield return new(0x45A3,"2459");
        if(a>=0x50){foreach(var s in Inhibit())yield return s;yield break;}
        yield return new(0x45A5,"BD46D3");foreach(var s in Test(0x45A8))yield return s;yield return new(0x45A9,"2708");
        if(!zero){yield return new(0x45AB,"7DFF40",()=>zero=m.Memory[0xFF40]==0);yield return new(0x45AE,"2703");if(!zero){yield return new(0x45B0,"4D");yield return new(0x45B1,"264B");if(a!=0){foreach(var s in Inhibit())yield return s;yield break;}}}
        yield return new(0x45B3,"FC02FC",()=>{d=m.ReadWord(0x2FC);a=(byte)(d>>8);b=(byte)d;});yield return new(0x45B6,"F30302",()=>{d=Cell.Add(d,m.ReadWord(0x302));a=(byte)(d>>8);b=(byte)d;});yield return new(0x45B9,"10832710");yield return new(0x45BD,"243F");
        if(d>=10000){foreach(var s in Inhibit())yield return s;yield break;}
        yield return new(0x45BF,"BD46D3");foreach(var s in Test(0x45C2))yield return s;yield return new(0x45C3,"270D");bool clear=false;
        if(!zero){yield return new(0x45C5,"7DFF40",()=>zero=m.Memory[0xFF40]==0);yield return new(0x45C8,"2708");if(!zero){yield return new(0x45CA,"B602F0",()=>a=m.Memory[0x2F0]);yield return new(0x45CD,"2703");if(a!=0){yield return new(0x45CF,"4F",()=>a=0);yield return new(0x45D0,"2017");clear=true;}}}
        if(!clear){
            yield return new(0x45D2,"8620",()=>a=0x20);yield return new(0x45D4,"F60370",()=>b=m.Memory[0x370]);yield return new(0x45D7,"C173");yield return new(0x45D9,"250E");
            if(b>=0x73){yield return new(0x45DB,"F60372",()=>b=m.Memory[0x372]);yield return new(0x45DE,"C1CD");yield return new(0x45E0,"2507");if(b>=0xCD){yield return new(0x45E2,"BD46D3");foreach(var s in Test(0x45E5))yield return s;yield return new(0x45E6,"2701");if(!zero)yield return new(0x45E8,"4F",()=>a=0);}}
        }
        yield return new(0x45E9,"7D0339",()=>zero=m.Memory[0x339]==0);yield return new(0x45EC,"273D");
        if(!zero){yield return new(0x45EE,"BD46D3");foreach(var s in Test(0x45F1))yield return s;yield return new(0x45F2,"2737");if(!zero){yield return new(0x45F4,"D600",()=>b=m.Memory[0]);yield return new(0x45F6,"C502");yield return new(0x45F8,"2731");if((b&2)!=0){yield return new(0x45FA,"8A08",()=>a|=8);yield return new(0x45FC,"202D");}}}
        foreach(var s in Output())yield return s;
    }
    private IEnumerable<Step> Inhibit(){yield return new(0x45FE,"860F",()=>a=0x0F);yield return new(0x4600,"2029");foreach(var s in Output())yield return s;}
    private IEnumerable<Step> Output()
    {
        yield return new(0x462B,"7D0338",()=>zero=m.Memory[0x338]==0);yield return new(0x462E,"2605");
        bool mask=!zero;if(!mask){yield return new(0x4630,"7DFF34",()=>zero=m.Memory[0xFF34]==0);yield return new(0x4633,"2602");mask=zero;}if(mask)yield return new(0x4635,"84DF",()=>a&=0xDF);
        yield return new(0x4637,"B70C02",()=>writePort(0xC02,a));yield return new(0x463A,"B80F02",()=>a^=readPort(0xF02));yield return new(0x463D,"8420",()=>a&=0x20);yield return new(0x463F,"B80F02",()=>a^=readPort(0xF02));yield return new(0x4642,"B70F02",()=>writePort(0xF02,a));yield return new(0x4645,"39");Continuation=0x4395;
    }
    public void Dispose()=>steps.Dispose();
}

namespace FruitMachineLab.Runtime;

// Bounded438C dispatch,439F decoding prefix and19B8->1A87 accumulation.
// Defaults to prefix boundaries. Optional explicit inline operand composes46D3;
// optional panel service continues1A05/1A58 to280C or the original7CCF jump.
// Optional coin service composes the43E9 idle path through return4395. Active
// coin branches,43E5 taken44C3 and unknown callbacks remain explicit boundaries.
public sealed class Mpu4PanelAccumulationExecution : IDisposable
{
    private sealed record Step(ushort Address,string Bytes,Action? Effect=null,bool? Branch=null);
    private readonly Machine m;
    private readonly IEnumerator<Step> steps;
    private Step? pending;
    private byte a,b,saved,temp;
    private ushort x,y;
    private bool carry;
    private readonly Func<byte>? readAux;
    private readonly byte? inlineAuxMask;
    private readonly bool continuePanelService;
    private Mpu4InlineAuxTestExecution? activeInline;
    private bool serviceTrap;
    private readonly bool continueCoinService;
    private readonly Func<ushort,byte>? readPort;
    private readonly Action<ushort,byte>? writePort;
    private Mpu4CoinIdleExecution? activeCoin;
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle {get;private set;}
    public bool Completed {get;private set;}
    public ushort Continuation {get;private set;}
    public ushort Address=>pending?.Address ?? Continuation;
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}
    public Mpu4PanelAccumulationExecution(Machine machine,ulong start,Func<byte>? readAux=null,byte? inlineAuxMask=null,bool continuePanelService=false,bool continueCoinService=false,Func<ushort,byte>? readPort=null,Action<ushort,byte>? writePort=null){m=machine;this.readAux=readAux;this.inlineAuxMask=inlineAuxMask;this.continuePanelService=continuePanelService;this.continueCoinService=continueCoinService;this.readPort=readPort;this.writePort=writePort;Cycle=start;steps=Run().GetEnumerator();Next();}
    private static ulong Cost(Step step)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(step.Bytes),step.Branch).Cycles;
    private void Next(){if(!steps.MoveNext()){Completed=true;pending=null;NextEventCycle=ulong.MaxValue;return;}pending=steps.Current;NextEventCycle=checked(Cycle+Cost(pending));}
    public void AdvanceTo(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        while(!Completed && NextEventCycle<=cycle){var step=pending!;ulong from=NextEventCycle-Cost(step);Cycle=NextEventCycle;step.Effect?.Invoke();ObserveInstruction?.Invoke(new(step.Address,step.Bytes,from,Cycle));Next();}Cycle=cycle;
    }
    // Caller has completed an instruction and now transfers CPU ownership to
    // a nested interrupt. Preserve translated locals and defer the next opcode.
    public void SuspendUntil(ulong resumeCycle)
    {
        if(resumeCycle<Cycle)throw new ArgumentOutOfRangeException(nameof(resumeCycle));
        if(!Completed){ulong pendingCost=Cost(pending!);if(NextEventCycle-Cycle!=pendingCost)throw new InvalidOperationException("IRQ suspension requires an instruction boundary");activeInline?.SuspendUntil(resumeCycle);activeCoin?.SuspendUntil(resumeCycle);NextEventCycle=checked(NextEventCycle+(resumeCycle-Cycle));}
        Cycle=resumeCycle;
    }
    private IEnumerable<Step> Run()
    {
        yield return new(0x438C,"9629",()=>a=m.Memory[0x29]);yield return new(0x438E,"8503");yield return new(0x4390,"2603");
        if((a&3)==0){
            yield return new(0x4392,"BD439F");foreach(var step in CoinPrefix())yield return step;
            if(inlineAuxMask is null){Continuation=0x46D3;yield break;}
            using var aux=new Mpu4InlineAuxTestExecution(m,Cycle,inlineAuxMask.Value,0x43E4);activeInline=aux;
            while(!aux.Completed){var instruction=aux.PendingInstruction;yield return new(instruction.Address,instruction.Bytes,()=>aux.AdvanceTo(Cycle));}
            activeInline=null;if(aux.ReturnAddress!=0x43E5)throw new InvalidOperationException("Inline return did not skip the operand");
            bool taken=!aux.Zero;yield return new(0x43E5,"102600DA",Branch:taken);Continuation=taken ? (ushort)0x44C3 : (ushort)0x43E9;
            if(taken || !continueCoinService)yield break;
            using var coin=new Mpu4CoinIdleExecution(m,Cycle,a,true,readPort,writePort);activeCoin=coin;
            while(!coin.Completed){var s=coin.PendingInstruction;yield return new(s.Address,s.Bytes,()=>coin.AdvanceTo(Cycle),s.Bytes.StartsWith("102",StringComparison.Ordinal) ? s.Completed-s.Started==6 : null);}
            activeCoin=null;Continuation=coin.Continuation;if(Continuation!=0x4395)yield break;
        }
        yield return new(0x4395,"7D00C6");bool callback=m.Memory[0xC6]!=0;yield return new(0x4398,"2704");
        if(!callback){yield return new(0x439E,"39");Continuation=0x280C;yield break;}
        yield return new(0x439A,"AD9F00C6");ushort target=m.ReadWord(0xC6);if(target!=0x19B8){Continuation=target;yield break;}
        yield return new(0x19B8,"BD1A87");yield return new(0x1A87,"BE0028",()=>x=m.ReadWord(0x28));yield return new(0x1A8A,"A6890000",()=>a=m.Memory[x]);yield return new(0x1A8E,"3402",()=>saved=a);yield return new(0x1A90,"AA89008E",()=>a|=m.Memory[Cell.Add(x,0x8E)]);yield return new(0x1A94,"A789008E",()=>m.Memory[Cell.Add(x,0x8E)]=a);yield return new(0x1A98,"3502",()=>a=saved);yield return new(0x1A9A,"A4890096",()=>a&=m.Memory[Cell.Add(x,0x96)]);yield return new(0x1A9E,"A7890096",()=>m.Memory[Cell.Add(x,0x96)]=a);yield return new(0x1AA2,"39");yield return new(0x19BB,"BD1A05");
        if(!continuePanelService){Continuation=0x1A05;yield break;}
        foreach(var step in CheckServiceInputs(false))yield return step;if(serviceTrap){Continuation=0x7CCF;yield break;}
        yield return new(0x19BE,"BD1A58");foreach(var step in CheckServiceInputs(true))yield return step;if(serviceTrap){Continuation=0x7CCF;yield break;}
        yield return new(0x19C1,"39");yield return new(0x439E,"39");Continuation=0x280C;
    }
    private IEnumerable<Step> CheckServiceInputs(bool second)
    {
        if(!second){
            yield return new(0x1A05,"F60029",()=>b=m.Memory[0x29]);yield return new(0x1A08,"C107");yield return new(0x1A0A,"2627");
            if(b==7){
                yield return new(0x1A0C,"C6FF",()=>b=0xFF);yield return new(0x1A0E,"7DFF4C");yield return new(0x1A11,"2708");
                if(m.Memory[0xFF4C]!=0){yield return new(0x1A13,"B60004",()=>a=m.Memory[4]);yield return new(0x1A16,"8500");yield return new(0x1A18,"2601");yield return new(0x1A1A,"5F",()=>b=0);}
                yield return new(0x1A1B,"F10339");yield return new(0x1A1E,"2710");
                if(b==m.Memory[0x339])yield return new(0x1A30,"7F0088",()=>m.Memory[0x88]=0);
                else{
                    yield return new(0x1A20,"7C0088",()=>m.Memory[0x88]++);yield return new(0x1A23,"B60088",()=>a=m.Memory[0x88]);yield return new(0x1A26,"810A");yield return new(0x1A28,"2509");
                    if(a>=10){yield return new(0x1A2A,"F70339",()=>m.Memory[0x339]=b);yield return new(0x1A2D,"7E7CCF");serviceTrap=true;yield break;}
                }
            }
            yield return new(0x1A33,"39");
        }else{
            yield return new(0x1A58,"F60029",()=>b=m.Memory[0x29]);yield return new(0x1A5B,"C107");yield return new(0x1A5D,"2627");
            if(b==7){
                yield return new(0x1A5F,"4F",()=>a=0);yield return new(0x1A60,"D605",()=>b=m.Memory[5]);yield return new(0x1A62,"C408",()=>b&=8);yield return new(0x1A64,"2701");if(b!=0)yield return new(0x1A66,"43",()=>a=(byte)~a);
                yield return new(0x1A67,"7DFF46");yield return new(0x1A6A,"2602");if(m.Memory[0xFF46]==0)yield return new(0x1A6C,"86FF",()=>a=0xFF);
                yield return new(0x1A6E,"B1032F");yield return new(0x1A71,"2710");
                if(a==m.Memory[0x32F])yield return new(0x1A83,"7F00E2",()=>m.Memory[0xE2]=0);
                else{
                    yield return new(0x1A73,"7C00E2",()=>m.Memory[0xE2]++);yield return new(0x1A76,"F600E2",()=>b=m.Memory[0xE2]);yield return new(0x1A79,"C10A");yield return new(0x1A7B,"2509");
                    if(b>=10){yield return new(0x1A7D,"B7032F",()=>m.Memory[0x32F]=a);yield return new(0x1A80,"7E7CCF");serviceTrap=true;yield break;}
                }
            }
            yield return new(0x1A86,"39");
        }
    }
    private IEnumerable<Step> CoinPrefix()
    {
        yield return new(0x439F,"B60005",()=>a=m.Memory[5]);yield return new(0x43A2,"847F",()=>a&=0x7F);yield return new(0x43A4,"108E0000",()=>y=0);yield return new(0x43A8,"8E71AA",()=>x=0x71AA);yield return new(0x43AB,"C611",()=>b=0x11);yield return new(0x43AD,"58",()=>b<<=1);yield return new(0x43AE,"58",()=>b<<=1);yield return new(0x43AF,"3A",()=>x=Cell.Add(x,b));
        while(true){
            yield return new(0x43B0,"E680",()=>{b=m.Memory[x];x=Cell.Add(x,1);});yield return new(0x43B2,"2609");if(b!=0)break;
            yield return new(0x43B4,"3121",()=>y=Cell.Add(y,1));yield return new(0x43B6,"108C0004");yield return new(0x43BA,"26F4");if(y==4){yield return new(0x43BC,"5F",()=>b=0);break;}
        }
        yield return new(0x43BD,"E5A4");bool selected=(b&m.Memory[y])!=0;yield return new(0x43BF,"2702");if(selected)yield return new(0x43C1,"8A80",()=>a|=0x80);
        yield return new(0x43C3,"48",()=>{carry=(a&0x80)!=0;a=unchecked((byte)(a<<1));});yield return new(0x43C4,"8900",()=>a=unchecked((byte)(a+(carry ? 1 : 0))));yield return new(0x43C6,"3402",()=>saved=a);
        yield return new(0x43C8,"B80C02",()=>a^=(readAux ?? throw new NotSupportedException("439F requires the actual0C02 auxiliary input level"))());yield return new(0x43CB,"84F0",()=>a&=0xF0);yield return new(0x43CD,"A8E0",()=>a^=saved);yield return new(0x43CF,"1F89",()=>b=a);yield return new(0x43D1,"9489",()=>a&=m.Memory[0x89]);yield return new(0x43D3,"3402",()=>temp=a);yield return new(0x43D5,"1F98",()=>a=b);yield return new(0x43D7,"9A89",()=>a|=m.Memory[0x89]);yield return new(0x43D9,"942A",()=>a&=m.Memory[0x2A]);yield return new(0x43DB,"AAE0",()=>a|=temp);yield return new(0x43DD,"972A",()=>m.Memory[0x2A]=a);yield return new(0x43DF,"D789",()=>m.Memory[0x89]=b);yield return new(0x43E1,"BD46D3");
    }
    public void Dispose()=>steps.Dispose();
}

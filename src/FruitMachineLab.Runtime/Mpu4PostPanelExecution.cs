namespace FruitMachineLab.Runtime;

// Native280F..2851 counter/sense service. Motor completion is an explicit
// predecessor boundary; stack/alarm validation at2851 remains caller-owned.
public sealed class Mpu4PostPanelExecution : IDisposable
{
    private sealed record Step(ushort Address,string Bytes,Action? Effect=null);
    private readonly Machine m;
    private readonly Func<byte> readSense;
    private readonly IEnumerator<Step> steps;
    private Step? pending;
    private ushort x;
    private byte a;
    private bool zero,carry;
    private readonly bool includeIdleMotor;
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle {get;private set;}
    public bool Completed {get;private set;}
    public ushort Address=>pending?.Address ?? 0x2851;
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}
    public Action<OutputScanAccess>? ObserveAccess {get;set;}
    public Mpu4PostPanelExecution(Machine machine,ulong start,Func<byte> readSense,bool includeIdleMotor=false){m=machine;Cycle=start;this.readSense=readSense;this.includeIdleMotor=includeIdleMotor;steps=Run().GetEnumerator();Next();}
    private static ulong Cost(Step s)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(s.Bytes)).Cycles;
    private void Next(){if(!steps.MoveNext()){Completed=true;pending=null;NextEventCycle=ulong.MaxValue;return;}pending=steps.Current;NextEventCycle=checked(Cycle+Cost(pending));}
    public void AdvanceTo(ulong cycle){if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));while(!Completed && NextEventCycle<=cycle){var s=pending!;ulong from=NextEventCycle-Cost(s);Cycle=NextEventCycle;s.Effect?.Invoke();ObserveInstruction?.Invoke(new(s.Address,s.Bytes,from,Cycle));Next();}Cycle=cycle;}
    public void SuspendUntil(ulong cycle){if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));if(!Completed){if(NextEventCycle-Cycle!=Cost(pending!))throw new InvalidOperationException("IRQ suspension requires an instruction boundary");NextEventCycle=checked(NextEventCycle+(cycle-Cycle));}Cycle=cycle;}
    private void Word(ushort at,ushort value){m.WriteWord(at,value);ObserveAccess?.Invoke(new(Cycle,at,value,true,false));}
    private void Byte(ushort at,byte value){m.Memory[at]=value;ObserveAccess?.Invoke(new(Cycle,at,value,true,false));}
    private IEnumerable<Step> Run()
    {
        if(includeIdleMotor){yield return new(0x280C,"BD6403");yield return new(0x6403,"0D6B",()=>a=m.Memory[0x6B]);yield return new(0x6405,"2AFB");if((a&0x80)!=0)throw new NotSupportedException("Active6403 motor body remains a separate timing boundary");yield return new(0x6402,"39");}
        yield return new(0x280F,"9E2D",()=>x=m.ReadWord(0x2D));yield return new(0x2811,"3001",()=>x=Cell.Add(x,1));yield return new(0x2813,"9F2D",()=>Word(0x2D,x));
        yield return new(0x2815,"9E2F",()=>x=m.ReadWord(0x2F));yield return new(0x2817,"3001",()=>x=Cell.Add(x,1));yield return new(0x2819,"9F2F",()=>Word(0x2F,x));
        yield return new(0x281B,"9E31",()=>x=m.ReadWord(0x31));yield return new(0x281D,"3001",()=>x=Cell.Add(x,1));yield return new(0x281F,"8C0101",()=>zero=x==0x101);yield return new(0x2822,"2707");
        if(!zero){yield return new(0x2824,"8C8000",()=>zero=x==0x8000);yield return new(0x2827,"2702");if(!zero)yield return new(0x2829,"9F31",()=>Word(0x31,x));}
        yield return new(0x282B,"0C33",()=>Byte(0x33,unchecked((byte)(m.Memory[0x33]+1))));yield return new(0x282D,"9E35",()=>{x=m.ReadWord(0x35);zero=x==0;});yield return new(0x282F,"2704");
        if(!zero){yield return new(0x2831,"301F",()=>x=Cell.Subtract(x,1));yield return new(0x2833,"9F35",()=>Word(0x35,x));}
        yield return new(0x2835,"9E28",()=>x=m.ReadWord(0x28));yield return new(0x2837,"B60B02",()=>{a=readSense();ObserveAccess?.Invoke(new(Cycle,0xB02,a,false,true));});yield return new(0x283A,"44",()=>{carry=(a&1)!=0;a>>=1;});yield return new(0x283B,"2510");
        if(!carry){yield return new(0x283D,"A6890008",()=>{a=m.Memory[Cell.Add(x,8)];zero=a==0;});yield return new(0x2841,"270E");if(zero)yield break;yield return new(0x2843,"8103");yield return new(0x2845,"2206");if(a<=3){yield return new(0x2847,"6F890008",()=>Byte(Cell.Add(x,8),0));yield return new(0x284B,"2004");yield break;}}
        yield return new(0x284D,"6C890008",()=>Byte(Cell.Add(x,8),unchecked((byte)(m.Memory[Cell.Add(x,8)]+1))));
    }
    public void Dispose()=>steps.Dispose();
}

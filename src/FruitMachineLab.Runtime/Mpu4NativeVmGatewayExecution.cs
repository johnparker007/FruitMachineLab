namespace FruitMachineLab.Runtime;

public readonly record struct NativeVmRegisters(byte A,byte B,byte DirectPage,byte ConditionCode,
    ushort X,ushort Y,ushort U,ushort S);

// Selected DP=0 native76BF gateway. The VM owns FC..return dispatch between the
// two staged native spans. Native stack bytes and saved-entry pointer are real.
public sealed class Mpu4NativeVmGatewayExecution : IDisposable
{
    private sealed record Step(ushort Address,string Bytes,Action? Effect=null);
    private readonly Machine m;
    private readonly Action<byte>? writeMode;
    private readonly IEnumerator<Step?> steps;
    private Step? pending;
    private NativeVmRegisters r;
    private ushort x,y,s,vmStack;
    private byte a,b;
    private bool zero;
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle {get;private set;}
    public bool WaitingForVm {get;private set;}
    public bool Completed {get;private set;}
    public string? Fault {get;private set;}
    public ushort Address=>pending?.Address ?? (WaitingForVm ? (ushort)0xFC : Continuation);
    public ushort Continuation {get;private set;}
    public ushort StackPointer=>s;
    public ushort Body=>y;
    public ushort DataPointer=>r.U;
    public bool IrqMasked=>(r.ConditionCode&0x10)!=0;
    // Intermediate arithmetic flags are not exposed as a complete CPU snapshot.
    public NativeVmRegisters Registers=>Completed ? r with{A=a,B=b,X=x,Y=y,S=s}
        : throw new InvalidOperationException("Full restored registers are available only at native return");
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}
    public Action<OutputScanAccess>? ObserveAccess {get;set;}
    public Mpu4NativeVmGatewayExecution(Machine machine,ulong start,NativeVmRegisters registers,Action<byte>? writeVmMode=null)
    {
        if(registers.DirectPage!=0)throw new NotSupportedException("Native VM gateway currently requires DP=0");
        m=machine;writeMode=writeVmMode;Cycle=start;r=registers;a=r.A;b=r.B;x=r.X;y=r.Y;s=r.S;
        steps=Run().GetEnumerator();Next();
    }
    private static ulong Cost(Step step)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(step.Bytes)).Cycles;
    private void Next(){if(!steps.MoveNext()){Completed=true;pending=null;NextEventCycle=ulong.MaxValue;return;}pending=steps.Current;if(pending is null){WaitingForVm=true;NextEventCycle=ulong.MaxValue;return;}NextEventCycle=checked(Cycle+Cost(pending));}
    public void AdvanceTo(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        if(Fault is not null)throw new InvalidOperationException(Fault);
        if(WaitingForVm)throw new InvalidOperationException("VM owns execution until ReturnFromVm");
        try{while(!Completed && !WaitingForVm && NextEventCycle<=cycle){var step=pending!;ulong from=NextEventCycle-Cost(step);Cycle=NextEventCycle;step.Effect?.Invoke();ObserveInstruction?.Invoke(new(step.Address,step.Bytes,from,Cycle));Next();}if(!WaitingForVm)Cycle=cycle;}
        catch(Exception e){Fault=e.Message;Dispose();throw;}
    }
    public void ReturnFromVm(ulong cycle,ushort stackPointer,ushort dataPointer,ushort cursor)
    {
        if(Fault is not null)throw new InvalidOperationException(Fault);
        if(!WaitingForVm || cursor!=0x76ED || stackPointer!=Cell.Add(vmStack,2) || cycle<Cycle)throw new InvalidOperationException("Unbalanced native VM gateway return");
        Cycle=cycle;s=stackPointer;r=r with{U=dataPointer};WaitingForVm=false;
        // Caller hands off AFTER the FC/FE dispatch of embedded word76F4. Its
        // timing belongs to the VM owner; this class resumes at handler76F6.
        Next();
    }
    public void SuspendUntil(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        if(Fault is not null)throw new InvalidOperationException(Fault);
        if(WaitingForVm)throw new InvalidOperationException("VM owner must suspend its own execution");
        if(IrqMasked)throw new InvalidOperationException("IRQ cannot suspend masked gateway");
        if(!Completed){if(NextEventCycle-Cycle!=Cost(pending!))throw new InvalidOperationException("Suspension requires an instruction boundary");NextEventCycle=checked(NextEventCycle+cycle-Cycle);}Cycle=cycle;
    }
    private void Byte(ushort at,byte value){m.Memory[at]=value;ObserveAccess?.Invoke(new(Cycle,at,value,true,false));}
    private void Word(ushort at,ushort value){m.WriteWord(at,value);ObserveAccess?.Invoke(new(Cycle,at,value,true,false));}
    private void Mode(byte value){(writeMode ?? throw new NotSupportedException("Gateway080C characteriser mode write requires a hardware owner"))(value);ObserveAccess?.Invoke(new(Cycle,0x80C,value,true,true));}
    private void PushByte(byte value){s--;Byte(s,value);}
    private void PushWord(ushort value){s=Cell.Subtract(s,2);Word(s,value);}
    private byte PopByte(){byte value=m.Memory[s];s++;return value;}
    private ushort PopWord(){ushort value=m.ReadWord(s);s=Cell.Add(s,2);return value;}
    private IEnumerable<Step?> Run()
    {
        yield return new(0x76BF,"343F",()=>{PushWord(y);PushWord(x);PushByte(r.DirectPage);PushByte(b);PushByte(a);PushByte(r.ConditionCode);});
        yield return new(0x76C1,"0DF8",()=>zero=m.Memory[0xF8]==0);yield return new(0x76C3,"2614");
        if(zero){yield return new(0x76C5,"2002");yield return new(0x76C9,"8E00F8",()=>x=0xF8);yield return new(0x76CC,"108E7927",()=>y=0x7927);
            do{yield return new(0x76D0,"ECA1",()=>{ushort d=m.ReadWord(y);a=(byte)(d>>8);b=(byte)d;y+=2;});yield return new(0x76D2,"ED81",()=>{Word(x,(ushort)((a<<8)|b));x+=2;});
                yield return new(0x76D4,"8C0100",()=>zero=x==0x100);yield return new(0x76D7,"26F7");}while(!zero);}
        yield return new(0x76D9,"96F1",()=>{a=m.Memory[0xF1];zero=a==0;});yield return new(0x76DB,"2707");
        if(!zero){yield return new(0x76DD,"84FE",()=>a&=0xFE);yield return new(0x76DF,"97F1",()=>Byte(0xF1,a));yield return new(0x76E1,"B7080C",()=>Mode(a));}
        yield return new(0x76E4,"10AE64",()=>y=m.ReadWord(Cell.Add(s,4)));yield return new(0x76E7,"9EF2",()=>x=m.ReadWord(0xF2));
        yield return new(0x76E9,"3450",()=>{PushWord(r.U);PushWord(x);});yield return new(0x76EB,"8D02",()=>PushWord(0x76ED));
        yield return new(0x76EF,"10DFF2",()=>{Word(0xF2,s);vmStack=s;});yield return new(0x76F2,"0EFC");
        yield return null;
        yield return new(0x76F6,"3530",()=>{x=PopWord();y=PopWord();});yield return new(0x76F8,"9FF2",()=>Word(0xF2,x));
        yield return new(0x76FA,"96F1",()=>{a=m.Memory[0xF1];zero=a==0;});yield return new(0x76FC,"2707");
        if(!zero){yield return new(0x76FE,"8A01",()=>a|=1);yield return new(0x7700,"97F1",()=>Byte(0xF1,a));yield return new(0x7702,"B7080C",()=>Mode(a));}
        yield return new(0x7705,"35BF",()=>{byte cc=PopByte();a=PopByte();b=PopByte();byte dp=PopByte();x=PopWord();y=PopWord();Continuation=PopWord();r=r with{ConditionCode=cc,DirectPage=dp};});
    }
    public void Dispose()=>steps.Dispose();
}

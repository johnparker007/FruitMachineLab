using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

// Selected4CBE caller through JMP6858. Native76BF/display is an explicit owner
// handoff, never a zero-cost callback or a captured runtime duration.
public sealed class AddersPayoutDebitExecution : IDisposable
{
    private abstract record Work;
    private sealed record Step(ushort Address,string Bytes,Action? Effect=null,bool? Branch=null):Work;
    private sealed record Nvram:Work;
    private sealed record Display:Work;
    private readonly Machine m;
    private readonly ushort record,u;
    private readonly ushort? nativeStack;
    private readonly IEnumerator<Work> steps;
    private Step? pending;
    private Mpu4NvramExecution? nvram;
    private byte a,b,mask;
    private byte cc;
    private ushort x;
    private bool zero,negative,carry,lower;
    private ulong next;
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle=>nvram?.NextEventCycle ?? next;
    public bool Completed {get;private set;}
    public bool WaitingForDisplay {get;private set;}
    public string? Fault {get;private set;}
    public ushort Address=>nvram?.Address ?? (WaitingForDisplay ? (ushort)0x76BF : pending?.Address ?? 0x6858);
    public ushort DisplayBody=>x;
    public NativeVmRegisters DisplayRegisters=>WaitingForDisplay && nativeStack.HasValue
        ? new(a,b,0,cc,x,record,u,Cell.Subtract(nativeStack.Value,2))
        : throw new InvalidOperationException("Display registers require its handoff and an explicit native S owner");
    public bool IrqMasked=>nvram?.IrqMasked ?? (mask&0x10)!=0;
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}
    public Action<OutputScanAccess>? ObserveAccess {get;set;}
    public AddersPayoutDebitExecution(Machine machine,ulong start,ushort recordAddress,ushort dataPointer,byte initialInterruptMask,ushort? nativeStackPointer=null)
    {
        _=AddersPayoutRecord.Read(machine,recordAddress);m=machine;record=recordAddress;u=dataPointer;nativeStack=nativeStackPointer;Cycle=start;cc=initialInterruptMask;mask=(byte)(initialInterruptMask&0x50);
        steps=Run().GetEnumerator();Next();
    }
    private static ulong Cost(Step s)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(s.Bytes),s.Branch).Cycles;
    private void Next()
    {
        if(!steps.MoveNext()){Completed=true;pending=null;next=ulong.MaxValue;return;}
        if(steps.Current is Nvram){pending=null;nvram=new(m,Cycle,u,cc,0x4CCB);nvram.ObserveInstruction=i=>ObserveInstruction?.Invoke(i);nvram.ObserveAccess=v=>ObserveAccess?.Invoke(v);return;}
        if(steps.Current is Display){pending=null;WaitingForDisplay=true;next=ulong.MaxValue;return;}
        pending=(Step)steps.Current;next=checked(Cycle+Cost(pending));
    }
    public void AdvanceTo(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        if(Fault is not null)throw new InvalidOperationException(Fault);
        if(WaitingForDisplay)throw new InvalidOperationException("Native76BF display owns execution until ReturnFromDisplay");
        try{while(!Completed && !WaitingForDisplay && NextEventCycle<=cycle){
            if(nvram is not null){nvram.AdvanceTo(nvram.NextEventCycle);Cycle=nvram.Cycle;if(!nvram.Completed)continue;cc=nvram.ReturnConditionCode;nvram.Dispose();nvram=null;Next();continue;}
            var s=pending!;ulong from=next-Cost(s);Cycle=next;s.Effect?.Invoke();ObserveInstruction?.Invoke(new(s.Address,s.Bytes,from,Cycle));Next();
        }
        // Do not consume caller time beyond a newly reached owner handoff.
        if(!WaitingForDisplay){nvram?.AdvanceTo(cycle);Cycle=cycle;}}
        catch(Exception e){Fault=e.Message;Dispose();throw;}
    }
    public void ReturnFromDisplay(ulong cycle,ushort dataPointer,ushort continuation)
    {
        if(Fault is not null)throw new InvalidOperationException(Fault);
        if(!WaitingForDisplay || continuation!=0x4CD1 || dataPointer!=u || cycle<Cycle)throw new InvalidOperationException("Unbalanced native display return");
        Cycle=cycle;WaitingForDisplay=false;Next();
    }
    public void SuspendUntil(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        if(Fault is not null)throw new InvalidOperationException(Fault);
        if(WaitingForDisplay)throw new InvalidOperationException("Display owner must suspend its own execution");
        if(IrqMasked)throw new InvalidOperationException("IRQ cannot suspend masked debit");
        if(nvram is not null)nvram.SuspendUntil(cycle);
        else if(!Completed){if(next-Cycle!=Cost(pending!))throw new InvalidOperationException("Suspension requires an instruction boundary");next=checked(next+cycle-Cycle);}Cycle=cycle;
    }
    private void Byte(ushort at,byte value){m.Memory[at]=value;ObserveAccess?.Invoke(new(Cycle,at,value,true,false));}
    private void Word(ushort at,ushort value){m.WriteWord(at,value);ObserveAccess?.Invoke(new(Cycle,at,value,true,false));}
    private ushort D {get=>(ushort)((a<<8)|b);set{a=(byte)(value>>8);b=(byte)value;}}
    private IEnumerable<Work> Run()
    {
        yield return new Step(0x4CBE,"ECB805",()=>D=m.ReadWord(m.ReadWord(Cell.Add(record,5))));
        yield return new Step(0x4CC1,"E023",()=>{byte v=m.Memory[record+3];carry=b<v;b=unchecked((byte)(b-v));});
        yield return new Step(0x4CC3,"8200",()=>{int borrow=carry ? 1 : 0;bool c=a<borrow;a=unchecked((byte)(a-borrow));cc=(byte)((cc&0xF0)|(c ? 1 : 0));});
        yield return new Step(0x4CC5,"EDB805",()=>Word(m.ReadWord(Cell.Add(record,5)),D));
        yield return new Step(0x4CC8,"BD6E06");yield return new Nvram();
        yield return new Step(0x4CCB,"BE7D36",()=>{x=m.ReadWord(0x7D36);cc=(byte)((cc&0xF1)|((short)x<0 ? 8 : 0)|(x==0 ? 4 : 0));});
        yield return new Step(0x4CCE,"BD76BF",()=>{if(nativeStack is ushort s)Word(Cell.Subtract(s,2),0x4CD1);});yield return new Display();
        yield return new Step(0x4CD1,"E623",()=>b=m.Memory[record+3]);yield return new Step(0x4CD3,"AE27",()=>{x=m.ReadWord(Cell.Add(record,7));zero=x==0;});
        yield return new Step(0x4CD5,"2703");if(!zero){yield return new Step(0x4CD7,"BD57F7");foreach(var w in Account())yield return w;}
        yield return new Step(0x4CDA,"AE29",()=>x=m.ReadWord(Cell.Add(record,9)));yield return new Step(0x4CDC,"BD57F7");foreach(var w in Account())yield return w;
        yield return new Step(0x4CDF,"AE2B",()=>x=m.ReadWord(Cell.Add(record,11)));yield return new Step(0x4CE1,"BD57F7");foreach(var w in Account())yield return w;
        yield return new Step(0x4CE4,"AE2D",()=>x=m.ReadWord(Cell.Add(record,13)));yield return new Step(0x4CE6,"BD59A4");foreach(var w in Meter())yield return w;
        yield return new Step(0x4CE9,"C601",()=>b=1);yield return new Step(0x4CEB,"AE21",()=>x=m.ReadWord(Cell.Add(record,1)));yield return new Step(0x4CED,"BD68E0");
        byte sa=a,sb=b,sm=mask;ushort sx=x;
        yield return new Step(0x68E0,"3416");yield return new Step(0x68E2,"3401");yield return new Step(0x68E4,"1A50",()=>mask|=0x50);
        yield return new Step(0x68E6,"EB84",()=>b=unchecked((byte)(b+m.Memory[x])));yield return new Step(0x68E8,"E784",()=>Byte(x,b));yield return new Step(0x68EA,"3501",()=>mask=sm);
        yield return new Step(0x68EC,"BD7032");foreach(var w in Checksum(false))yield return w;
        yield return new Step(0x68EF,"3596",()=>{a=sa;b=sb;x=sx;});yield return new Step(0x4CF0,"7E6858");
    }
    private IEnumerable<Work> Account()
    {
        yield return new Step(0x57F7,"7D0323",()=>negative=(sbyte)m.Memory[0x323]<0);yield return new Step(0x57FA,"2B03");
        if(negative){yield return new Step(0x57FF,"39");yield break;}
        yield return new Step(0x57FC,"7E57A9");byte sa=a,sb=b;
        yield return new Step(0x57A9,"3406");yield return new Step(0x57AB,"4F",()=>a=0);
        yield return new Step(0x57AC,"E301",()=>{uint sum=(uint)D+m.ReadWord(Cell.Add(x,1));carry=sum>65535;D=(ushort)sum;});
        yield return new Step(0x57AE,"ED01",()=>Word(Cell.Add(x,1),D));yield return new Step(0x57B0,"A684",()=>a=m.Memory[x]);
        yield return new Step(0x57B2,"8900",()=>a=unchecked((byte)(a+(carry ? 1 : 0))));yield return new Step(0x57B4,"A784",()=>Byte(x,a));
        yield return new Step(0x57B6,"3586",()=>{a=sa;b=sb;});
    }
    private IEnumerable<Work> Meter()
    {
        byte sa=a,sb=b,sm=mask;ushort sx=x;
        yield return new Step(0x59A4,"3416");yield return new Step(0x59A6,"7D0323",()=>negative=(sbyte)m.Memory[0x323]<0);yield return new Step(0x59A9,"2B0E");
        if(!negative){yield return new Step(0x59AB,"4F",()=>a=0);yield return new Step(0x59AC,"3401");yield return new Step(0x59AE,"1A50",()=>mask|=0x50);
            yield return new Step(0x59B0,"E384",()=>D=Cell.Add(D,m.ReadWord(x)));yield return new Step(0x59B2,"ED84",()=>Word(x,D));yield return new Step(0x59B4,"3501",()=>mask=sm);
            yield return new Step(0x59B6,"BD6FEC");foreach(var w in Checksum(true))yield return w;}
        yield return new Step(0x59B9,"3596",()=>{a=sa;b=sb;x=sx;});
    }
    private IEnumerable<Work> Checksum(bool meter)
    {
        byte sa=a,sb=b,sm=mask,guard=0;ushort sx=x;
        yield return new Step(meter ? (ushort)0x6FEC : (ushort)0x7032,"3417");
        yield return new Step(meter ? (ushort)0x6FEE : (ushort)0x7034,"F6002C",()=>b=m.Memory[0x2C]);
        yield return new Step(meter ? (ushort)0x6FF1 : (ushort)0x7037,"3404",()=>guard=b);
        yield return new Step(meter ? (ushort)0x6FF3 : (ushort)0x7039,"C601",()=>b=1);
        yield return new Step(meter ? (ushort)0x6FF5 : (ushort)0x703B,"F7002C",()=>Byte(0x2C,b));
        yield return new Step(meter ? (ushort)0x6FF8 : (ushort)0x703E,meter ? "8DC7" : "8DC9");
        yield return new Step(meter ? (ushort)0x6FC1 : (ushort)0x7009,meter ? "8E035E" : "8E036B",()=>x=meter ? (ushort)0x35E : (ushort)0x36B);
        yield return new Step(meter ? (ushort)0x6FC4 : (ushort)0x700C,"5F",()=>b=0);yield return new Step(meter ? (ushort)0x6FC5 : (ushort)0x700D,"2003");
        while(true){yield return new Step(meter ? (ushort)0x6FCA : (ushort)0x7012,meter ? "8C036A" : "8C0373",()=>lower=x<(meter ? 0x36A : 0x373));
            yield return new Step(meter ? (ushort)0x6FCD : (ushort)0x7015,"25F8");if(!lower)break;
            yield return new Step(meter ? (ushort)0x6FC7 : (ushort)0x700F,"EB80",()=>{b=unchecked((byte)(b+m.Memory[x]));x++;});yield return new Step(meter ? (ushort)0x6FC9 : (ushort)0x7011,"5C",()=>b++);}
        yield return new Step(meter ? (ushort)0x6FCF : (ushort)0x7017,"5C",()=>b++);yield return new Step(meter ? (ushort)0x6FD0 : (ushort)0x7018,"39");
        yield return new Step(meter ? (ushort)0x6FFA : (ushort)0x7040,"E784",()=>Byte(x,b));
        if(meter){yield return new Step(0x6FFC,"0D3A",()=>negative=(sbyte)m.Memory[0x3A]<0);yield return new Step(0x6FFE,"2A02");if(negative)yield return new Step(0x7000,"0F3A",()=>Byte(0x3A,0));}
        yield return new Step(meter ? (ushort)0x7002 : (ushort)0x7042,"3504",()=>b=guard);
        yield return new Step(meter ? (ushort)0x7004 : (ushort)0x7044,"F7002C",()=>Byte(0x2C,b));
        yield return new Step(meter ? (ushort)0x7007 : (ushort)0x7047,"3597",()=>{a=sa;b=sb;x=sx;mask=sm;});
    }
    public void Dispose(){nvram?.Dispose();steps.Dispose();}
}

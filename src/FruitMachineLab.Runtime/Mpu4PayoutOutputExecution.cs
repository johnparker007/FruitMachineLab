namespace FruitMachineLab.Runtime;

// Selected normal-mode6858 output service, with7032 checksum, positive511B
// notification and the staged pulse/polling child. Debit/display remain callers.
public sealed class Mpu4PayoutOutputExecution : IDisposable
{
    private abstract record Work;
    private sealed record Step(ushort Address,string Bytes,Action? Effect=null,bool? Branch=null) : Work;
    private sealed record Pulse(byte Mask) : Work;
    private readonly Machine m;
    private readonly Func<byte> readPort;
    private readonly Action<byte> writePort;
    private readonly IEnumerator<Work> steps;
    private Step? pending;
    private Mpu4PayoutPulseExecution? pulse;
    private byte a,b,interruptMask;
    private ushort x,y;
    private bool zero,lower,negative;
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle=>pulse?.NextEventCycle ?? next;
    private ulong next;
    public bool Completed {get;private set;}
    public string? Fault {get;private set;}
    public ushort Continuation {get;}
    public ushort Address=>pulse?.Address ?? pending?.Address ?? Continuation;
    public bool IrqMasked=>pulse?.IrqMasked ?? (interruptMask&0x10)!=0;
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}
    public Action<OutputScanAccess>? ObserveAccess {get;set;}
    public Mpu4PayoutOutputExecution(Machine machine,ulong start,byte initialInterruptMask,ushort continuation,
        Func<byte> readTriac,Action<byte> writeTriac)
    {
        m=machine;Cycle=start;interruptMask=(byte)(initialInterruptMask&0x50);Continuation=continuation;
        readPort=readTriac;writePort=writeTriac;steps=Run().GetEnumerator();Next();
    }
    private static ulong Cost(Step s)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(s.Bytes),s.Branch).Cycles;
    private void Next()
    {
        if(!steps.MoveNext()){Completed=true;pending=null;next=ulong.MaxValue;return;}
        if(steps.Current is Pulse p) {
            pending=null;pulse=new(m,Cycle,p.Mask,interruptMask,readPort,writePort);
            pulse.ObserveInstruction=i=>ObserveInstruction?.Invoke(i);pulse.ObserveAccess=v=>ObserveAccess?.Invoke(v);return;
        }
        pending=(Step)steps.Current;next=checked(Cycle+Cost(pending));
    }
    public void AdvanceTo(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        if(Fault is not null)throw new InvalidOperationException(Fault);
        try {
        while(!Completed && NextEventCycle<=cycle) {
            if(pulse is not null){pulse.AdvanceTo(pulse.NextEventCycle);Cycle=pulse.Cycle;if(!pulse.Completed)continue;pulse.Dispose();pulse=null;Next();continue;}
            var s=pending!;ulong from=next-Cost(s);Cycle=next;s.Effect?.Invoke();ObserveInstruction?.Invoke(new(s.Address,s.Bytes,from,Cycle));Next();
        }
        pulse?.AdvanceTo(cycle);Cycle=cycle;
        }catch(Exception e){Fault=e.Message;Dispose();throw;}
    }
    public void SuspendUntil(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        if(Fault is not null)throw new InvalidOperationException(Fault);
        if(IrqMasked)throw new InvalidOperationException("IRQ cannot suspend masked payout service");
        if(pulse is not null)pulse.SuspendUntil(cycle);
        else if(!Completed){if(next-Cycle!=Cost(pending!))throw new InvalidOperationException("Suspension requires an instruction boundary");next=checked(next+cycle-Cycle);}
        Cycle=cycle;
    }
    private void Byte(ushort at,byte value){m.Memory[at]=value;ObserveAccess?.Invoke(new(Cycle,at,value,true,false));}
    private void Word(ushort at,ushort value){m.WriteWord(at,value);ObserveAccess?.Invoke(new(Cycle,at,value,true,false));}
    private IEnumerable<Work> Run()
    {
        yield return new Step(0x6858,"3436");
        while(true) {
            yield return new Step(0x685A,"8E036B",()=>x=0x36B);yield return new Step(0x685D,"108E201A",()=>y=0x201A);
            while(true) {
                yield return new Step(0x6861,"A6A0",()=>{a=m.Memory[y];y++;});yield return new Step(0x6863,"6D84",()=>zero=m.Memory[x]==0);yield return new Step(0x6865,"2609");if(!zero)break;
                yield return new Step(0x6867,"3002",()=>x+=2);yield return new Step(0x6869,"8C0373",()=>lower=x<0x373);yield return new Step(0x686C,"25F3");
                if(!lower){yield return new Step(0x686E,"35B6");yield break;}
            }
            yield return new Step(0x6870,"6A84",()=>Byte(x,unchecked((byte)(m.Memory[x]-1))));
            yield return new Step(0x6872,"6D01",()=>zero=m.Memory[x+1]==0);yield return new Step(0x6874,"2702");
            if(!zero)yield return new Step(0x6876,"6A01",()=>Byte(Cell.Add(x,1),unchecked((byte)(m.Memory[x+1]-1))));
            yield return new Step(0x6878,"BD7032");foreach(var w in Checksum())yield return w;
            yield return new Step(0x687B,"D62B",()=>b=m.Memory[0x2B]);yield return new Step(0x687D,"C120",()=>zero=b==0x20);yield return new Step(0x687F,"2705");
            if(!zero){yield return new Step(0x6881,"7D0323",()=>negative=(sbyte)m.Memory[0x323]<0);yield return new Step(0x6884,"2B45");if(negative)throw new NotSupportedException("Native68CB service-mode tone/delay remains unrecovered");}
            yield return new Step(0x6886,"F6719B",()=>b=m.Memory[0x719B]);yield return new Step(0x6889,"C504",()=>zero=(b&4)==0);yield return new Step(0x688B,"26E1");
            if(!zero){yield return new Step(0x686E,"35B6");yield break;}
            byte mask=a;yield return new Step(0x688D,"3426");yield return new Step(0x688F,"31A90096",()=>y=Cell.Add(y,0x96));yield return new Step(0x6893,"313F",()=>y--);
            yield return new Step(0x6895,"108C20B4",()=>lower=y<0x20B4);yield return new Step(0x6899,"2405");
            if(lower){yield return new Step(0x689B,"E6A4",()=>b=m.Memory[y]);yield return new Step(0x689D,"BD511B");foreach(var w in Serial())yield return w;}
            yield return new Pulse(mask);
        }
    }
    private IEnumerable<Work> Checksum()
    {
        byte savedA=a,savedB=b,savedMask=interruptMask,guard=0;ushort savedX=x;
        yield return new Step(0x7032,"3417");yield return new Step(0x7034,"F6002C",()=>b=m.Memory[0x2C]);yield return new Step(0x7037,"3404",()=>guard=b);
        yield return new Step(0x7039,"C601",()=>b=1);yield return new Step(0x703B,"F7002C",()=>Byte(0x2C,b));yield return new Step(0x703E,"8DC9");
        yield return new Step(0x7009,"8E036B",()=>x=0x36B);yield return new Step(0x700C,"5F",()=>b=0);yield return new Step(0x700D,"2003");
        while(true) {
            yield return new Step(0x7012,"8C0373",()=>lower=x<0x373);yield return new Step(0x7015,"25F8");if(!lower)break;
            yield return new Step(0x700F,"EB80",()=>{b=unchecked((byte)(b+m.Memory[x]));x++;});yield return new Step(0x7011,"5C",()=>b++);
        }
        yield return new Step(0x7017,"5C",()=>b++);yield return new Step(0x7018,"39");yield return new Step(0x7040,"E784",()=>Byte(x,b));
        yield return new Step(0x7042,"3504",()=>b=guard);yield return new Step(0x7044,"F7002C",()=>Byte(0x2C,b));
        yield return new Step(0x7047,"3597",()=>{a=savedA;b=savedB;x=savedX;interruptMask=savedMask;});
    }
    private IEnumerable<Work> Serial()
    {
        byte savedA=a,savedB=b,message=b,count=0;ushort savedX=x;
        yield return new Step(0x511B,"3416");yield return new Step(0x511D,"B671A1",()=>a=m.Memory[0x71A1]);yield return new Step(0x5120,"840F",()=>a&=15);
        yield return new Step(0x5122,"810F",()=>zero=a==15);yield return new Step(0x5124,"10270087",Branch:zero);
        if(zero){yield return new Step(0x51AF,"3596",()=>{a=savedA;b=savedB;x=savedX;});yield break;}
        yield return new Step(0x5128,"3404");yield return new Step(0x512A,"5D",()=>negative=(sbyte)b<0);yield return new Step(0x512B,"2A02");
        if(negative)throw new NotSupportedException("Native511B negative-message filter requires its separate contract");
        yield return new Step(0x512F,"C160",()=>{lower=b<0x60;zero=b==0x60;});yield return new Step(0x5131,"250E");
        bool blocked;
        if(!lower) {
            yield return new Step(0x5133,"2706");
            if(zero){yield return new Step(0x513B,"8508",()=>zero=(a&8)==0);yield return new Step(0x513D,"266E");blocked=!zero;if(!blocked)yield return new Step(0x513F,"2016");}
            else{yield return new Step(0x5135,"8504",()=>zero=(a&4)==0);yield return new Step(0x5137,"2674");blocked=!zero;if(!blocked)yield return new Step(0x5139,"201C");}
        } else {
            yield return new Step(0x5141,"C120",()=>lower=b<0x20);yield return new Step(0x5143,"2506");
            if(!lower){yield return new Step(0x5145,"8501",()=>zero=(a&1)==0);yield return new Step(0x5147,"2664");blocked=!zero;if(!blocked)yield return new Step(0x5149,"200C");}
            else {
                yield return new Step(0x514B,"8502",()=>zero=(a&2)==0);yield return new Step(0x514D,"265E");blocked=!zero;
                if(!blocked){yield return new Step(0x514F,"C106",()=>zero=b==6);yield return new Step(0x5151,"275A");blocked=zero;}
                if(!blocked){yield return new Step(0x5153,"C115",()=>zero=b==0x15);yield return new Step(0x5155,"2756");blocked=zero;}
            }
        }
        if(blocked){yield return new Step(0x51AD,"3504");yield return new Step(0x51AF,"3596",()=>{a=savedA;b=savedB;x=savedX;});yield break;}
        yield return new Step(0x5157,"3504",()=>b=message);yield return new Step(0x5159,"0F84",()=>Byte(0x84,0));
        yield return new Step(0x515B,"B603DA",()=>a=m.Memory[0x3DA]);yield return new Step(0x515E,"8120",()=>lower=a<0x20);yield return new Step(0x5160,"250E");
        if(!lower){yield return new Step(0x5162,"3402",()=>count=a);yield return new Step(0x5164,"86FF",()=>a=255);yield return new Step(0x5166,"977D",()=>Byte(0x7D,a));yield return new Step(0x5168,"8680",()=>a=128);yield return new Step(0x516A,"9A2B",()=>a|=m.Memory[0x2B]);yield return new Step(0x516C,"972B",()=>Byte(0x2B,a));yield return new Step(0x516E,"3502",()=>a=count);}
        yield return new Step(0x5170,"BE03D8",()=>x=m.ReadWord(0x3D8));yield return new Step(0x5173,"8C03A8",()=>lower=x<0x3A8);yield return new Step(0x5176,"2505");bool invalid=lower;
        if(!invalid){yield return new Step(0x5178,"8C03D4",()=>lower=x<0x3D4);yield return new Step(0x517B,"2503");invalid=!lower;}
        if(invalid)yield return new Step(0x517D,"8E03A8",()=>x=0x3A8);
        yield return new Step(0x5180,"4D",()=>zero=a==0);yield return new Step(0x5181,"2603");if(zero)yield return new Step(0x5183,"BF03D6",()=>Word(0x3D6,x));
        yield return new Step(0x5186,"3502",()=>a=savedA);yield return new Step(0x5188,"E780",()=>{Byte(x,b);x++;});yield return new Step(0x518A,"FB03DB",()=>b=unchecked((byte)(b+m.Memory[0x3DB])));yield return new Step(0x518D,"F703DB",()=>Byte(0x3DB,b));
        yield return new Step(0x5190,"6D1F",()=>negative=(sbyte)m.Memory[Cell.Subtract(x,1)]<0);yield return new Step(0x5192,"2A0B");
        if(negative)throw new NotSupportedException("Native511B queued byte became a two-byte message during execution");
        yield return new Step(0x519F,"BF03D8",()=>Word(0x3D8,x));yield return new Step(0x51A2,"7C03DA",()=>Byte(0x3DA,unchecked((byte)(m.Memory[0x3DA]+1))));yield return new Step(0x51A5,"0D84",()=>zero=m.Memory[0x84]==0);yield return new Step(0x51A7,"2602");
        if(zero)yield return new Step(0x51A9,"0384",()=>Byte(0x84,unchecked((byte)~m.Memory[0x84])));
        yield return new Step(0x51AB,"3594",()=>{b=savedB;x=savedX;});
    }
    public void Dispose(){pulse?.Dispose();steps.Dispose();}
}

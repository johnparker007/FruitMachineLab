namespace FruitMachineLab.Runtime;

public sealed record OutputScanInstruction(ushort Address,string Bytes,ulong Started,ulong Completed);
public sealed record OutputScanAccess(ulong Cycle,ushort Address,ushort? Value,bool Write,bool Hardware);

// Translation of28FE,19C2/19FA,70EF, not an opcode interpreter. Each yielded
// instruction completes before its effects are applied. No captured path is
// consumed. The caller owns interrupt preemption, PIA sense and PTM hardware.
public sealed class Mpu4OutputScanExecution : IDisposable
{
    private sealed record Step(ushort Address,string Bytes,Action? Effect=null,bool? Branch=null);
    private readonly Machine m;
    private readonly IEnumerator<Step> steps;
    private readonly Func<byte> sense;
    private Step? pending;
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle {get;private set;}
    public bool Completed {get;private set;}
    public ushort Address=>pending?.Address ?? 0x29BA;
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}
    public Action<OutputScanAccess>? ObserveAccess {get;set;}
    public Action<ulong,Timer3Arm>? ObserveArm {get;set;}
    private byte a,b,stackB;
    private ushort x,y;
    private bool carry;

    public Mpu4OutputScanExecution(Machine machine,ulong start,Func<byte>? readSense=null)
    {
        m=machine;Cycle=start;sense=readSense ?? (()=>m.Memory[0xB02]);steps=Run().GetEnumerator();Next();
    }
    private void Next()
    {
        if(!steps.MoveNext()){pending=null;Completed=true;NextEventCycle=ulong.MaxValue;return;}
        pending=steps.Current;NextEventCycle=checked(Cycle+(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(pending.Bytes),pending.Branch).Cycles);
    }
    public void AdvanceTo(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        while(!Completed && NextEventCycle<=cycle){
            var step=pending!;ulong start=NextEventCycle-(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(step.Bytes),step.Branch).Cycles;
            Cycle=NextEventCycle;step.Effect?.Invoke();ObserveInstruction?.Invoke(new(step.Address,step.Bytes,start,Cycle));Next();
        }
        Cycle=cycle;
    }
    private void Put(ushort address,byte value,bool control=false)
    {
        bool hardware=address>=0x900 && address<=0xF03;
        if(control){byte status=(byte)(m.Memory[address]&0x80);if((value&0x20)==0)status|=(byte)(m.Memory[address]&0x40);m.Memory[address]=(byte)((value&0x3F)|status);}
        else m.Memory[address]=value;
        ObserveAccess?.Invoke(new(Cycle,address,value,true,hardware));
    }
    private void Word(ushort address,ushort value){m.WriteWord(address,value);ObserveAccess?.Invoke(new(Cycle,address,value,true,false));}
    private void Bus(ushort address,ushort value,bool write)=>ObserveAccess?.Invoke(new(Cycle,address,write ? value : null,write,true));
    private IEnumerable<Step> Run()
    {
        yield return new(0x28FE,"7D008D");bool suppress=m.Memory[0x8D]!=0;
        yield return new(0x2901,"102600B5",Branch:suppress);
        if(suppress){yield return new(0x29BA,"39");yield break;}
        yield return new(0x2905,"5F",()=>b=0);
        yield return new(0x2906,"F70A00",()=>Put(0xA00,b));yield return new(0x2909,"F70A02",()=>Put(0xA02,b));yield return new(0x290C,"F70B00",()=>Put(0xB00,b));
        yield return new(0x290F,"9E28",()=>x=m.ReadWord(0x28));yield return new(0x2911,"3001",()=>x=Cell.Add(x,1));yield return new(0x2913,"8C0008");yield return new(0x2916,"252C");
        if(x>=8){
            yield return new(0x2918,"D627",()=>b=m.Memory[0x27]);yield return new(0x291A,"2716");
            if(b!=0){
                yield return new(0x291C,"9623",()=>a=m.Memory[0x23]);yield return new(0x291E,"0A26",()=>Put(0x26,unchecked((byte)(m.Memory[0x26]-1))));yield return new(0x2920,"2604");
                if(m.Memory[0x26]==0){yield return new(0x2922,"8802",()=>a^=2);yield return new(0x2924,"D726",()=>Put(0x26,b));}
                yield return new(0x2926,"0A24",()=>Put(0x24,unchecked((byte)(m.Memory[0x24]-1))));yield return new(0x2928,"2615");
                if(m.Memory[0x24]==0){yield return new(0x292A,"8801",()=>a^=1);yield return new(0x292C,"D625",()=>b=m.Memory[0x25]);yield return new(0x292E,"D724",()=>Put(0x24,b));yield return new(0x2930,"200D");}
                yield return new(0x293F,"9723",()=>Put(0x23,a));
            }else{
                yield return new(0x2932,"0A24",()=>Put(0x24,unchecked((byte)(m.Memory[0x24]-1))));yield return new(0x2934,"260B");
                if(m.Memory[0x24]==0){yield return new(0x2936,"9625",()=>a=m.Memory[0x25]);yield return new(0x2938,"9724",()=>Put(0x24,a));yield return new(0x293A,"9623",()=>a=m.Memory[0x23]);yield return new(0x293C,"4C",()=>a++);yield return new(0x293D,"8403",()=>a&=3);yield return new(0x293F,"9723",()=>Put(0x23,a));}
            }
            yield return new(0x2941,"8E0000",()=>x=0);
        }
        yield return new(0x2944,"9F28",()=>Word(0x28,x));yield return new(0x2946,"8E28E6",()=>x=0x28E6);yield return new(0x2949,"D629",()=>b=m.Memory[0x29]);yield return new(0x294B,"3A",()=>x=Cell.Add(x,b));
        yield return new(0x294C,"A684",()=>a=m.Memory[x]);yield return new(0x294E,"B70E01",()=>Put(0xE01,a,true));yield return new(0x2951,"A608",()=>a=m.Memory[x+8]);yield return new(0x2953,"B70B01",()=>Put(0xB01,a,true));yield return new(0x2956,"A68810",()=>a=m.Memory[x+16]);yield return new(0x2959,"B70F01",()=>Put(0xF01,a,true));
        yield return new(0x295C,"9E28",()=>x=m.ReadWord(0x28));yield return new(0x295E,"A6890008",()=>a=m.Memory[x+8]);yield return new(0x2962,"8103");yield return new(0x2964,"2227");
        if(a<=3){
            yield return new(0x2966,"C626",()=>b=0x26);
            while(true){
                yield return new(0x2968,"B60B02",()=>{a=sense();ObserveAccess?.Invoke(new(Cycle,0xB02,a,false,true));});yield return new(0x296B,"8402",()=>a&=2);yield return new(0x296D,"2706");if(a==0)break;
                yield return new(0x296F,"5A",()=>b--);yield return new(0x2970,"26F6");
                if(b==0)throw new NotSupportedException("Output scan sense timeout reaches native SWI alarm19; alarm execution is not recovered");
            }
            yield return new(0x2975,"D623",()=>b=m.Memory[0x23]);yield return new(0x2977,"58",()=>b<<=1);yield return new(0x2978,"58",()=>b<<=1);yield return new(0x2979,"58",()=>b<<=1);yield return new(0x297A,"58",()=>b<<=1);yield return new(0x297B,"3A",()=>x=Cell.Add(x,b));
            yield return new(0x297C,"A6890100",()=>a=m.Memory[x+0x100]);yield return new(0x2980,"E6890108",()=>b=m.Memory[x+0x108]);yield return new(0x2984,"B70A00",()=>Put(0xA00,a));yield return new(0x2987,"F70A02",()=>Put(0xA02,b));yield return new(0x298A,"BD19C2");
            byte savedA=a;
            yield return new(0x19C2,"3402");yield return new(0x19C4,"7D00B3");yield return new(0x19C7,"272F");
            if(m.Memory[0xB3]!=0){
                yield return new(0x19C9,"10BE032D",()=>y=m.ReadWord(0x32D));yield return new(0x19CD,"B600E8",()=>a=m.Memory[0xE8]);yield return new(0x19D0,"4A",()=>a--);yield return new(0x19D1,"B700E8",()=>Put(0xE8,a));yield return new(0x19D4,"4D");yield return new(0x19D5,"2E1B");
                if((sbyte)a<=0){
                    yield return new(0x19D7,"B600E9",()=>a=m.Memory[0xE9]);yield return new(0x19DA,"B700E8",()=>Put(0xE8,a));yield return new(0x19DD,"108C012C");yield return new(0x19E1,"2C17");bool reverse=(short)y>=300;
                    if(!reverse){yield return new(0x19E3,"108C001E");yield return new(0x19E7,"2F11");reverse=(short)y<=30;}
                    if(reverse){yield return new(0x19FA,"7000EA",()=>Put(0xEA,unchecked((byte)-m.Memory[0xEA])));yield return new(0x19FD,"108C001E");yield return new(0x1A01,"2600");yield return new(0x1A03,"20E4");}
                    yield return new(0x19E9,"B600EA",()=>a=m.Memory[0xEA]);yield return new(0x19EC,"31A6",()=>y=Cell.Add(y,unchecked((ushort)(short)(sbyte)a)));yield return new(0x19EE,"10BF032D",()=>Word(0x32D,y));
                }
                yield return new(0x19F2,"8E48FD",()=>x=0x48FD);yield return new(0x19F5,"BD70EF");
                byte savedB=b;
                yield return new(0x70EF,"3405");yield return new(0x70F1,"1A50");yield return new(0x70F3,"F60901",()=>Bus(0x901,0,false));yield return new(0x70F6,"F60906",()=>Bus(0x906,0,false));yield return new(0x70F9,"9F3D",()=>Word(0x3D,x));yield return new(0x70FB,"D63F",()=>b=m.Memory[0x3F]);yield return new(0x70FD,"C4FE",()=>b&=0xFE);yield return new(0x70FF,"F70901",()=>Bus(0x901,b,true));yield return new(0x7102,"D73F",()=>Put(0x3F,b));yield return new(0x7104,"C663",()=>b=0x63);yield return new(0x7106,"F70900",()=>Bus(0x900,b,true));yield return new(0x7109,"D740",()=>Put(0x40,b));
                yield return new(0x710B,"10BF0906",()=>{ObserveAccess?.Invoke(new(Cycle-1,0x906,(byte)(y>>8),true,true));Bus(0x907,(byte)y,true);ObserveArm?.Invoke(Cycle,new(y,x));});yield return new(0x710F,"3585",()=>b=savedB);
            }
            yield return new(0x19F8,"3582",()=>a=savedA);
        }
        yield return new(0x298D,"D622",()=>b=m.Memory[0x22]);yield return new(0x298F,"9629",()=>a=m.Memory[0x29]);
        do{yield return new(0x2991,"54",()=>{carry=(b&1)!=0;b>>=1;});yield return new(0x2992,"4A",()=>a--);yield return new(0x2993,"2AFC");}while((sbyte)a>=0);
        yield return new(0x2995,"9629",()=>a=m.Memory[0x29]);yield return new(0x2997,"8E001A",()=>x=0x1A);yield return new(0x299A,"A686",()=>a=m.Memory[x+unchecked((sbyte)a)]);yield return new(0x299C,"2402");if(carry)yield return new(0x299E,"8A80",()=>a|=0x80);
        yield return new(0x29A0,"8E02BE",()=>x=0x2BE);yield return new(0x29A3,"D629",()=>b=m.Memory[0x29]);yield return new(0x29A5,"E685",()=>b=m.Memory[x+unchecked((sbyte)b)]);yield return new(0x29A7,"3404",()=>stackB=b);yield return new(0x29A9,"F60023",()=>b=m.Memory[0x23]);yield return new(0x29AC,"8E29BB",()=>x=0x29BB);yield return new(0x29AF,"E685",()=>b=m.Memory[x+unchecked((sbyte)b)]);yield return new(0x29B1,"E4E0",()=>b&=stackB);yield return new(0x29B3,"2702");if(b!=0)yield return new(0x29B5,"8480",()=>a&=0x80);
        yield return new(0x29B7,"B70B00",()=>Put(0xB00,a));yield return new(0x29BA,"39");
    }
    public void Dispose()=>steps.Dispose();
}

namespace FruitMachineLab.Runtime;

public sealed class Mpu4PostPanelGuardExecution : IDisposable
{
    private sealed record Step(ushort Address,string Bytes,bool? Branch=null,Action? Effect=null);
    private static readonly (ushort Address,string Bytes)[] SelectedBytes=new[]
    {
        ((ushort)0x2851,"0D44"),((ushort)0x2853,"260E"),((ushort)0x2855,"AE6A"),((ushort)0x2857,"C60A"),
        ((ushort)0x2859,"8C0525"),((ushort)0x285C,"2531"),((ushort)0x285E,"8C0676"),((ushort)0x2861,"222C"),
        ((ushort)0x2863,"C60B"),((ushort)0x2865,"118C0677"),((ushort)0x2869,"2524"),((ushort)0x286B,"118C07C8"),
        ((ushort)0x286F,"221E"),((ushort)0x2871,"7D1400"),((ushort)0x2874,"2618"),((ushort)0x288E,"39")
    };
    private readonly Machine m;
    private readonly IEnumerator<Step> steps;
    private Step? pending;
    private byte a,b,dp,cc;
    private ushort x,y,u,s,pc;
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle {get;private set;}
    public bool Completed {get;private set;}
    public ushort Address=>pending?.Address ?? pc;
    public ushort Continuation=>pc;
    public ushort PC=>pc;
    public ushort S=>s;
    public ushort SavedU{get;private set;}
    public byte A=>a;
    public byte B=>b;
    public ushort X=>x;
    public ushort Y=>y;
    public ushort U=>u;
    public byte DP=>dp;
    public byte CC=>cc;
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}

    public Mpu4PostPanelGuardExecution(Machine machine,ulong start,byte a,byte b,ushort x,ushort y,ushort u,ushort s,byte dp,byte cc)
    {
        if(dp!=0)throw new NotSupportedException($"2851 guard DP {dp:X2} is outside captured DP=00; direct-page 0044 is not parameterized");
        ArgumentNullException.ThrowIfNull(machine);
        ValidateSelectedBytes(machine);
        m=machine;this.a=a;this.b=b;this.x=x;this.y=y;this.u=u;this.s=s;this.dp=dp;this.cc=cc;pc=0x2851;
        if(m.Memory[0x44]!=0)throw new NotSupportedException("2851 guard 44 nonzero selects 2863; selected tail requires 44=0");
        SavedU=m.ReadWord(Cell.Add(s,0xA));
        if(SavedU<0x0525 || SavedU>0x0676)throw new NotSupportedException($"2851 guard saved-U {SavedU:X4} outside 0525..0676 reaches SWI2 288F");
        if(s<0x0677 || s>0x07C8)throw new NotSupportedException($"2851 guard S {s:X4} outside 0677..07C8 reaches SWI2 288F");
        if(m.Memory[0x1400]==0)throw new NotSupportedException("2851 guard TST 1400 zero reaches SWI2 288F");
        Cycle=start;steps=Run().GetEnumerator();Next();
    }

    private static void ValidateSelectedBytes(Machine machine)
    {
        foreach(var (address,bytes) in SelectedBytes)
        {
            byte[] expected=Convert.FromHexString(bytes);
            if(!machine.Memory.AsSpan(address,expected.Length).SequenceEqual(expected))
                throw new NotSupportedException($"2851 guard original selected bytes differ at {address:X4}");
        }
    }

    private static ulong Cost(Step step)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(step.Bytes),step.Branch).Cycles;
    private void Next(){if(!steps.MoveNext()){Completed=true;pending=null;NextEventCycle=ulong.MaxValue;return;}pending=steps.Current;NextEventCycle=checked(Cycle+Cost(pending));}
    public void AdvanceTo(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        while(!Completed && NextEventCycle<=cycle){var step=pending!;ulong from=NextEventCycle-Cost(step);Cycle=NextEventCycle;step.Effect?.Invoke();ObserveInstruction?.Invoke(new(step.Address,step.Bytes,from,Cycle));Next();}
        Cycle=cycle;
    }
    private void TestByte(byte value)=>cc=(byte)((cc&0xF1)|(value==0 ? 0x04 : 0)|((value&0x80)!=0 ? 0x08 : 0));
    private void LoadB(byte value){b=value;cc=(byte)((cc&0xF1)|(b==0 ? 0x04 : 0)|((b&0x80)!=0 ? 0x08 : 0));}
    private void LoadX(ushort value){x=value;cc=(byte)((cc&0xF1)|(x==0 ? 0x04 : 0)|((x&0x8000)!=0 ? 0x08 : 0));}
    private void Compare16(ushort lhs,ushort rhs)
    {
        ushort result=unchecked((ushort)(lhs-rhs));
        bool negative=(result&0x8000)!=0;
        bool zero=result==0;
        bool overflow=(((lhs^rhs)&(lhs^result))&0x8000)!=0;
        bool carry=lhs<rhs;
        cc=(byte)((cc&0xF0)|(negative ? 0x08 : 0)|(zero ? 0x04 : 0)|(overflow ? 0x02 : 0)|(carry ? 0x01 : 0));
    }
    private IEnumerable<Step> Run()
    {
        yield return new(0x2851,"0D44",Effect:()=>TestByte(m.Memory[0x44]));
        yield return new(0x2853,"260E",Branch:(cc&0x04)==0);
        if((cc&0x04)==0)throw new NotSupportedException("2851 guard 44 nonzero selects 2863");
        yield return new(0x2855,"AE6A",Effect:()=>LoadX(m.ReadWord(Cell.Add(s,0x0A))));
        yield return new(0x2857,"C60A",Effect:()=>LoadB(0x0A));
        yield return new(0x2859,"8C0525",Effect:()=>Compare16(x,0x0525));
        yield return new(0x285C,"2531",Branch:(cc&0x01)!=0);
        if((cc&0x01)!=0)throw new NotSupportedException("2851 guard saved-U below 0525 reaches SWI2 288F");
        yield return new(0x285E,"8C0676",Effect:()=>Compare16(x,0x0676));
        yield return new(0x2861,"222C",Branch:(cc&0x01)==0 && (cc&0x04)==0);
        if((cc&0x01)==0 && (cc&0x04)==0)throw new NotSupportedException("2851 guard saved-U above 0676 reaches SWI2 288F");
        yield return new(0x2863,"C60B",Effect:()=>LoadB(0x0B));
        yield return new(0x2865,"118C0677",Effect:()=>Compare16(s,0x0677));
        yield return new(0x2869,"2524",Branch:(cc&0x01)!=0);
        if((cc&0x01)!=0)throw new NotSupportedException("2851 guard S below 0677 reaches SWI2 288F");
        yield return new(0x286B,"118C07C8",Effect:()=>Compare16(s,0x07C8));
        yield return new(0x286F,"221E",Branch:(cc&0x01)==0 && (cc&0x04)==0);
        if((cc&0x01)==0 && (cc&0x04)==0)throw new NotSupportedException("2851 guard S above 07C8 reaches SWI2 288F");
        yield return new(0x2871,"7D1400",Effect:()=>TestByte(m.Memory[0x1400]));
        yield return new(0x2874,"2618",Branch:(cc&0x04)==0);
        if((cc&0x04)!=0)throw new NotSupportedException("2851 guard TST 1400 zero reaches SWI2 288F");
        yield return new(0x288E,"39",Effect:()=>{pc=m.ReadWord(s);s=Cell.Add(s,2);});
    }
    public void Dispose()=>steps.Dispose();
}

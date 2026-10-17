namespace FruitMachineLab.Runtime;

// Selected FE70 timer1 path through generated28FE entry. Caller establishes
// accepted ordinary IRQ, bank0, no IC4/timer2 priority, timer1 pending. This
// does not choose IRQ acceptance from an atomic VM token or simulate its frame.
public sealed class Mpu4Timer1DispatchExecution
{
    private readonly List<(ushort Address,string Bytes)> Path=[(0xFE70,"96F1"),(0xFE72,"2709"),(0xFE7D,"B60B03"),(0xFE80,"2A04"),(0xFE86,"B60901"),(0xFE89,"D63F"),(0xFE8B,"C540"),(0xFE8D,"2704"),(0xFE93,"8501"),(0xFE95,"2610"),(0xFEA7,"B60902"),(0xFEAA,"1CEF"),(0xFEAC,"AE68"),(0xFEAE,"C60A"),(0xFEB0,"8C0525"),(0xFEB3,"2C02"),(0xFEB7,"BD28FE")];
    private readonly Machine m;
    private readonly Func<ushort> savedU;
    private ushort u;
    private int index;
    public ulong Cycle {get;private set;}
    public ulong NextEventCycle {get;private set;}
    public bool Completed=>index==Path.Count;
    public ushort Address=>Completed ? (ushort)0x28FE : Path[index].Address;
    public Action<OutputScanInstruction>? ObserveInstruction {get;set;}
    public Action<OutputScanAccess>? ObserveAccess {get;set;}
    public Mpu4Timer1DispatchExecution(Machine machine,ulong start,Func<ushort> savedU){m=machine;this.savedU=savedU;Cycle=start;Validate();NextEventCycle=checked(start+Cost(0));}
    private ulong Cost(int i)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(Path[i].Bytes),Path[i].Address==0xFE6B ? false : null,Path[i].Address==0xFE6F ? (byte)0x80 : null).Cycles;
    private void Validate(){if(m.Memory[0xF1]!=0 || (m.Memory[0xB03]&0x80)!=0 || (m.Memory[0x3F]&0x40)!=0)throw new NotSupportedException("Timer1 dispatch requires selected bank0/no IC4 or timer2 priority");}
    public void AdvanceTo(ulong cycle)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));Validate();
        while(!Completed && NextEventCycle<=cycle){var s=Path[index];ulong from=NextEventCycle-Cost(index);Cycle=NextEventCycle;
            if(s.Address==0xFE86)ObserveAccess?.Invoke(new(Cycle,0x901,0x81,false,true));
            if(s.Address==0xFEA7)ObserveAccess?.Invoke(new(Cycle,0x902,null,false,true));
            if(s.Address==0xFEAC)u=savedU();
            if(s.Address==0xFEB3 && (short)u<(short)0x525)Path.InsertRange(index+1,[(0xFEB5,"103F"),(0xFE66,"B6719C"),(0xFE69,"8501"),(0xFE6B,"102637B1"),(0xFE6F,"3B")]);
            if(s.Address==0xFE6B && (m.Memory[0x719C]&1)!=0)throw new NotSupportedException("Enabled native SWI2 alarm remains outside the selected return path");
            ObserveInstruction?.Invoke(new(s.Address,s.Bytes,from,Cycle));index++;NextEventCycle=Completed ? ulong.MaxValue : checked(Cycle+Cost(index));
        }Cycle=cycle;
    }
}

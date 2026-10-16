namespace FruitMachineLab.Runtime;

public sealed record Timer3DispatchWrite(ulong Cycle,ushort Address,byte Value,bool Hardware);
public sealed record Timer3DispatchRead(ulong Cycle,ushort Address);

// Selected ordinary FE70->48FD dispatch path, DP0, bank flag0, no IC4/timer2
// priority, and timer3 selected. Handler entry is an explicit external boundary.
// Hardware writes are exposed as events, not simulated as flat RAM registers.
public sealed class Mpu4Timer3DispatchExecution
{
    public static IReadOnlyList<(ushort Address,string Bytes)> Path => [
        (0xFE70,"96F1"),(0xFE72,"2709"),(0xFE7D,"B60B03"),(0xFE80,"2A04"),
        (0xFE86,"B60901"),(0xFE89,"D63F"),(0xFE8B,"C540"),(0xFE8D,"2704"),
        (0xFE93,"8501"),(0xFE95,"2610"),(0xFE97,"D640"),(0xFE99,"C540"),
        (0xFE9B,"2700"),(0xFE9D,"8504"),(0xFE9F,"2640"),(0xFEE1,"B60906"),
        (0xFEE4,"1CEF"),(0xFEE6,"BD70B3"),(0x70B3,"3405"),(0x70B5,"1A50"),
        (0x70B7,"D63F"),(0x70B9,"C4FE"),(0x70BB,"F70901"),(0x70BE,"D73F"),
        (0x70C0,"C600"),(0x70C2,"F70900"),(0x70C5,"D740"),(0x70C7,"3585"),
        (0xFEE9,"9E3D"),(0xFEEB,"8C1400"),(0xFEEE,"2502"),(0xFEF0,"AD84")];
    private readonly Machine machine;
    private readonly byte control2,control3,ic4;
    private int index;
    private int readIndex;
    private readonly Mpu4Timer3DispatchHardware? hardware;
    public ulong Cycle {get;private set;}
    public ulong CallbackAt {get;}
    public bool Completed {get;private set;}
    public IReadOnlyList<Timer3DispatchWrite> Writes {get;}
    public IReadOnlyList<Timer3DispatchRead> Reads {get;}
    public ulong NextEventCycle=>Completed ? ulong.MaxValue : Math.Min(readIndex<Reads.Count ? Reads[readIndex].Cycle : CallbackAt,index<Writes.Count ? Writes[index].Cycle : CallbackAt);

    public Mpu4Timer3DispatchExecution(Machine machine,ulong handlerEntry,Mpu4Timer3DispatchHardware? hardware=null)
    {
        this.hardware=hardware;
        this.machine=machine;Cycle=handlerEntry;control2=machine.Memory[0x3F];control3=machine.Memory[0x40];ic4=machine.Memory[0xB03];
        if(machine.Memory[0xF1]!=0 || (ic4&0x80)!=0 || (control2&0x40)!=0 || control3!=0x63 || machine.ReadWord(0x3D)!=0x48FD)
            throw new NotSupportedException("Timer3 dispatch requires the recovered DP0/bank0 selected timer3 path");
        var writes=new List<Timer3DispatchWrite>();var reads=new List<Timer3DispatchRead>();ulong at=handlerEntry;
        foreach(var ins in Path){
            at=checked(at+(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(ins.Bytes)).Cycles);
            if(ins.Address==0xFE86)reads.Add(new(at,0x901));
            if(ins.Address==0xFEE1)reads.Add(new(at,0x906));
            if(ins.Address==0x70BB)writes.Add(new(at,0x901,(byte)(control2&0xFE),true));
            if(ins.Address==0x70BE)writes.Add(new(at,0x3F,(byte)(control2&0xFE),false));
            if(ins.Address==0x70C2)writes.Add(new(at,0x900,0,true));
            if(ins.Address==0x70C5)writes.Add(new(at,0x40,0,false));
        }
        Writes=writes.AsReadOnly();Reads=reads.AsReadOnly();CallbackAt=at;
    }

    public void AdvanceTo(ulong cycle,Action<Timer3DispatchWrite>? observe=null,Action<Timer3DispatchRead>? observeRead=null)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        if(!Completed && (machine.Memory[0xF1]!=0 || machine.Memory[0xB03]!=ic4 || machine.ReadWord(0x3D)!=0x48FD || machine.Memory[0x3F]!=(index>=2 ? (byte)(control2&0xFE) : control2) || machine.Memory[0x40]!=(index>=4 ? (byte)0 : control3)))
            throw new NotSupportedException("Preemption/changed dispatch state requires native IRQ recovery");
        while(NextEventCycle<=cycle && NextEventCycle<CallbackAt){
            if(readIndex<Reads.Count && Reads[readIndex].Cycle==NextEventCycle){
                var read=Reads[readIndex++];Cycle=read.Cycle;hardware?.Read(read);observeRead?.Invoke(read);continue;
            }
            var write=Writes[index++];Cycle=write.Cycle;
            if(write.Hardware)hardware?.Write(write);
            if(!write.Hardware)machine.Memory[write.Address]=write.Value;
            observe?.Invoke(write);
        }
        Cycle=cycle;if(cycle>=CallbackAt)Completed=true;
    }
}

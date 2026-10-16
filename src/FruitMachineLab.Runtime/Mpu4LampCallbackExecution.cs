namespace FruitMachineLab.Runtime;

public sealed record LampCallbackWrite(ulong Cycle,ushort Address,byte Value);

// Selected non-preempted native48FD/4917 path. Entry remains an external
// hardware boundary; subsequent port writes/completion derive from instructions.
public sealed class Mpu4LampCallbackExecution
{
    private readonly Machine machine;
    private readonly ushort column;
    private readonly byte bank0,bank1,mask0,mask1,blank,display;
    private int index;
    private static ulong Cost(string bytes)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(bytes)).Cycles;
    public static IReadOnlyList<(ushort Address,string Bytes)> Path(bool blank) =>
        new (ushort,string)[]{(0x48FD,"9E28"),(0x48FF,"30890140"),(0x4903,"B60A00"),(0x4906,"F60A02"),(0x4909,"A484"),(0x490B,"E408"),(0x490D,"B70A00"),(0x4910,"F70A02"),(0x4913,"BD4917"),(0x4917,"9E28"),(0x4919,"6D8900AB"),(0x491D,"2703")}
            .Concat(blank ? new (ushort,string)[]{(0x491F,"7F0B00"),(0x4922,"39"),(0x4916,"39")} : new (ushort,string)[]{(0x4922,"39"),(0x4916,"39")}).ToArray();
    public ulong Started {get;}
    public ulong Cycle {get;private set;}
    public ulong CompletedAt {get;}
    public bool Completed {get;private set;}
    public IReadOnlyList<LampCallbackWrite> Writes {get;}
    public ulong NextEventCycle=>Completed ? ulong.MaxValue : index<Writes.Count ? Writes[index].Cycle : CompletedAt;

    public Mpu4LampCallbackExecution(Machine machine,ulong started)
    {
        this.machine=machine;Started=Cycle=started;column=machine.ReadWord(0x28);
        if(column>7)throw new NotSupportedException("Live callback requires a selected MPU4 column0..7");
        bank0=machine.Memory[0xA00];bank1=machine.Memory[0xA02];display=machine.Memory[0xB00];
        mask0=machine.Memory[0x140+column];mask1=machine.Memory[0x148+column];blank=machine.Memory[0xAB+column];
        var writes=new List<LampCallbackWrite>();ulong at=started;
        foreach(var ins in Path(blank!=0)){
            at=checked(at+Cost(ins.Bytes));
            if(ins.Address==0x490D)writes.Add(new(at,0xA00,(byte)(bank0&mask0)));
            if(ins.Address==0x4910)writes.Add(new(at,0xA02,(byte)(bank1&mask1)));
            if(ins.Address==0x491F)writes.Add(new(at,0xB00,0));
        }
        Writes=writes.AsReadOnly();CompletedAt=at;
    }

    public void AdvanceTo(ulong cycle,Action<LampCallbackWrite>? observe=null)
    {
        if(cycle<Cycle)throw new ArgumentOutOfRangeException(nameof(cycle));
        if(!Completed && (machine.ReadWord(0x28)!=column || machine.Memory[0x140+column]!=mask0 || machine.Memory[0x148+column]!=mask1 || machine.Memory[0xAB+column]!=blank))
            throw new NotSupportedException("Callback preemption or changed masks require native boundary recovery");
        if(!Completed && (machine.Memory[0xA00]!=(index>0 ? (byte)(bank0&mask0) : bank0) || machine.Memory[0xA02]!=(index>1 ? (byte)(bank1&mask1) : bank1) || machine.Memory[0xB00]!=(index>2 ? (byte)0 : display)))
            throw new NotSupportedException("Output writer interrupted the selected native callback path");
        while(index<Writes.Count && Writes[index].Cycle<=cycle){
            var write=Writes[index++];Cycle=write.Cycle;machine.Memory[write.Address]=write.Value;observe?.Invoke(write);
        }
        Cycle=cycle;if(cycle>=CompletedAt)Completed=true;
    }
}

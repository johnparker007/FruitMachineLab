using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public static class AddersSoundOperationVerification
{
    public static int Queue(string evidence)=>Verify(evidence,"sound-queue",(m,row)=>new AddersSoundQueuePlan(m,0x8784,0x700,0x1A0,0x89,0xAB).Instructions(),0x5C18,0x4C34);
    public static int Prompt(string evidence)=>Verify(evidence,"sound-prompt",(m,row)=>new AddersSoundServicePlan(m,0x700,0x600,0x8784,0x1A0).Instructions(),0x5CD0,0x4C34,true);
    public static int Rhythm(string evidence)=>Verify(evidence,"sound-rhythm",(m,row)=>new AddersSoundNotePlan(m,0x1A0,0x601,0x700,0x8784,row.GetProperty("case").GetProperty("note").GetByte()).Instructions(),0x5D48,0x5CDE);
    public static int Calls(string evidence)=>Verify(evidence,"sound-callservice",(m,row)=>new AddersSoundServicePlan(m,0x700,0x600,0x8784,0x1A0).Instructions(),0x5CD0,0x4C34,true);
    public static int NativeChildLongevity(string evidence,bool prompt=false)
    {
        using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection",prompt ? "sound-prompt.json" : "sound-noteservice.json")));
        var m=new Machine();foreach(var region in doc.RootElement.GetProperty("rom_regions").EnumerateArray())Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!).CopyTo(m.Memory,region.GetProperty("address").GetInt32());
        AddersSoundResetMemory.Apply(m);m.WriteWord(0x700,0x4C34);m.Memory[0x50]=16;m.Memory[0x4E]=16;ulong clock=0;int writes=0,completed=0;
        for(int round=0;round<12;round++){
            if(!AddersSoundQueueMemory.Queue(m,prompt ? (ushort)0x8784 : (ushort)0x8739))throw new InvalidDataException("Native child pool exhausted");
            ushort at=m.ReadWord(0x47);m.Memory[at+0xC]=(byte)(round%2==0 ? 0 : 12);m.Memory[at+0xE]=(byte)(round%3==0 ? 0 : 16);
            int ticks=0;while(m.ReadWord(0x47)!=0 && ++ticks<2000){
                var plan=new AddersSoundServicePlan(m,0x700,0x600,0x8784,0x1A0,ymWrite:(_,_)=>writes++);
                using var e=new NativeRoutineExecution(plan.Instructions(),clock,0x4C34,()=>true);
                e.ObserveInstruction=i=>{byte[] bytes=Convert.FromHexString(i.Bytes);if(!m.Memory.AsSpan(i.Address,bytes.Length).SequenceEqual(bytes))throw new InvalidDataException("Native child source differs");};
                while(!e.Completed)e.AdvanceTo(e.NextEventCycle);clock=e.Cycle;completed+=plan.CompletedTasks;
            }
            if(ticks>=2000 || m.Memory[0x44]!=0)throw new InvalidDataException("Native child failed to drain");
            var free=new HashSet<ushort>();for(ushort p=m.ReadWord(0x49);p!=0;p=m.ReadWord(p)){AddersSoundLifecycleMemory.ValidateTask(p);if(!free.Add(p))throw new InvalidDataException("Native task pool cycle");}
            var channels=new HashSet<byte>();for(byte p=m.Memory[0x4B];(sbyte)p>=0;p=m.Memory[0x27E+p]){if(p>5 || !channels.Add(p))throw new InvalidDataException("Native channel free cycle");}
            if(free.Count!=6 || channels.Count!=6)throw new InvalidDataException("Native child leaked tasks/channels");
            for(int p=0;p<6;p++)if((m.Memory[0x2A4+p]&0x10)!=0)throw new InvalidDataException("Native child retained key-on");
        }
        if(completed!=(prompt ? 48 : 12) || writes<100)throw new InvalidDataException("Native child completion/output coverage missing");return completed;
    }
    public static int Yield(string evidence)=>Verify(evidence,"sound-yield",(m,row)=>new AddersSoundYieldPlan(m,0x1A0,0x879E,0x700,row.GetProperty("case").GetProperty("duration").GetByte()).Instructions(),0x5CF3,0x5CDE);
    public static int Child(string evidence)=>Verify(evidence,"sound-child",(m,row)=>new AddersSoundChildPlan(m,0x1A0,0x8787,0x700).Instructions(),0x5EE3,0x5D3B);
    public static int Instrument(string evidence)=>Verify(evidence,"sound-instrument",(m,row)=>new AddersSoundInstrumentPlan(m,0x1A0,0x601,0x700).Instructions(),0x5F5B,0x5D3B);
    public static int Service(string evidence)=>Verify(evidence,"sound-service",(m,row)=>new AddersSoundServicePlan(m,0x700,0x600,0x8784,0x1A0).Instructions(),0x5CD0,0x4C34);
    public static int Note(string evidence)=>Verify(evidence,"sound-note",(m,row)=>new AddersSoundNotePlan(m,0x1A0,0x601,0x700,0x8784,row.GetProperty("case").GetProperty("note").GetByte()).Instructions(),0x5D48,0x5CDE);
    public static int NoteService(string evidence)
    {
        using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection","sound-noteservice.json")));
        var pcs=doc.RootElement.GetProperty("catalog").EnumerateArray().Select(i=>i.GetProperty("pc").GetUInt16()).ToHashSet();
        foreach(ushort pc in new ushort[]{0x603A,0x5E1F,0x5E89})if(!pcs.Contains(pc))throw new InvalidDataException("Native child sustain/release/completion coverage missing");
        return Verify(evidence,"sound-noteservice",(m,row)=>new AddersSoundServicePlan(m,0x700,0x600,0x8784,0x1A0).Instructions(),0x5CD0,0x4C34,true);
    }
    public static int Verify(string evidence,string stem,Func<Machine,JsonElement,IEnumerable<NativeRoutineWork>> plan,ushort entry,ushort continuation,bool preserve=false)
    {
        using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection",stem+".json")));int count=0;
        Machine? current=null;
        foreach(var row in doc.RootElement.GetProperty("rows").EnumerateArray()){
            bool initial=!preserve || row.GetProperty("case").GetProperty("tick").GetInt32()==0;
            byte[] seed=Convert.FromHexString(row.GetProperty("before_hex").GetString()!);
            if(initial){current=new Machine();seed.CopyTo(current.Memory,0);}
            var m=current!;if(!initial && !m.Memory.AsSpan(0,0x800).SequenceEqual(seed))throw new InvalidDataException("Native sound state diverged BETWEEN service calls");
            foreach(var region in doc.RootElement.GetProperty("rom_regions").EnumerateArray())Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!).CopyTo(m.Memory,region.GetProperty("address").GetInt32());
            ushort next=stem is "sound-note" or "sound-rhythm" && row.GetProperty("case").GetProperty("note").GetByte()<0x60 ? (ushort)0x5D3B : continuation;
            var actual=new List<(ushort,ulong)>();using var e=new NativeRoutineExecution(plan(m,row),0,next,()=>true);
            e.ObserveInstruction=i=>{byte[] bytes=Convert.FromHexString(i.Bytes);if(!m.Memory.AsSpan(i.Address,bytes.Length).SequenceEqual(bytes))throw new InvalidDataException("Sound operation opcode differs");actual.Add((i.Address,i.Started));};
            while(!e.Completed){ulong due=e.NextEventCycle;byte[] before=m.Memory.AsSpan(0,0x800).ToArray();e.AdvanceTo(due-1);if(!m.Memory.AsSpan(0,0x800).SequenceEqual(before))throw new InvalidDataException("Early sound operation effect");e.AdvanceTo(due);}
            var expected=new List<(ushort,ulong)>{(entry,0)};expected.AddRange(row.GetProperty("steps").EnumerateArray().Select(i=>(doc.RootElement.GetProperty("catalog")[i[0].GetInt32()].GetProperty("pc").GetUInt16(),i[1].GetUInt64())));
            if(!actual.SequenceEqual(expected))throw new InvalidDataException($"{stem} case{count} instruction times differ");if(e.Cycle!=row.GetProperty("cycles").GetUInt64())throw new InvalidDataException("Sound operation duration differs");
            if(e.Address!=row.GetProperty("end").GetProperty("pc").GetUInt16())throw new InvalidDataException("Sound operation continuation differs");
            byte[] after=Convert.FromHexString(row.GetProperty("after_hex").GetString()!);for(int p=0;p<0x800;p++)if(m.Memory[p]!=after[p])throw new InvalidDataException($"{stem} case{count} RAM{p:X4}: expected{after[p]:X2}, actual{m.Memory[p]:X2}");count++;
        }return count;
    }
}

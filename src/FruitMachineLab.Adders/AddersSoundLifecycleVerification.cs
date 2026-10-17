using System.Text.Json;
using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

public static class AddersSoundLifecycleVerification
{
    public static int TimedRelease(string evidence)=>Timed(evidence,"release");
    public static int Timed(string evidence,string kind)
    {
        using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection","sound-lifecycle.json")));int count=0;
        foreach(var row in doc.RootElement.GetProperty("rows").EnumerateArray()){
            if(row.GetProperty("case").GetProperty("kind").GetString()!=kind)continue;
            var m=new Machine();Convert.FromHexString(row.GetProperty("before_hex").GetString()!).CopyTo(m.Memory,0);
            foreach(var region in doc.RootElement.GetProperty("rom_regions").EnumerateArray())Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!).CopyTo(m.Memory,region.GetProperty("address").GetInt32());
            var actual=new List<(ushort,ulong)>();
            var writes=new List<(byte,byte)>();var expectedWrites=new List<(byte,byte)>();
            var semantic=new Machine();m.Memory.CopyTo(semantic.Memory,0);AddersSoundLifecycleMemory.ReleaseChannels(semantic,0x1A0,(r,v)=>expectedWrites.Add((r,v)));
            ushort entry=row.GetProperty("case").GetProperty("entry").GetUInt16();
            IEnumerable<NativeRoutineWork> plan=kind=="release"
                ? new AddersSoundReleasePlan(m,0x1A0,0x700,0x600,0x8784,(r,v)=>writes.Add((r,v))).Instructions()
                : new AddersSoundServicePlan(m,0x700,0x600,0x8784,0x1A0,entry,(r,v)=>writes.Add((r,v))).Instructions();
            using var execution=new NativeRoutineExecution(plan,0,0x4C34,()=>true);
            execution.ObserveInstruction=i=>{byte[] bytes=Convert.FromHexString(i.Bytes);if(!m.Memory.AsSpan(i.Address,bytes.Length).SequenceEqual(bytes))throw new InvalidDataException("Sound release encoding differs from ROM");actual.Add((i.Address,i.Started));};
            while(!execution.Completed){
                byte[] before=m.Memory.AsSpan(0,0x800).ToArray();int writeCount=writes.Count;ulong due=execution.NextEventCycle;
                execution.AdvanceTo(due-1);
                if(!m.Memory.AsSpan(0,0x800).SequenceEqual(before) || writes.Count!=writeCount)throw new InvalidDataException("Sound effect committed before instruction completion");
                execution.AdvanceTo(due);
            }
            if(!writes.SequenceEqual(expectedWrites))throw new InvalidDataException("Staged sound cache-write notifications differ");
            var expected=new List<(ushort,ulong)>{(entry,0)};
            expected.AddRange(row.GetProperty("steps").EnumerateArray().Select(i=>(doc.RootElement.GetProperty("catalog")[i[0].GetInt32()].GetProperty("pc").GetUInt16(),i[1].GetUInt64())));
            if(!actual.SequenceEqual(expected))throw new InvalidDataException("Sound release instruction times differ");
            if(execution.Cycle!=row.GetProperty("cycles").GetUInt64())throw new InvalidDataException("Sound release duration differs");
            byte[] after=Convert.FromHexString(row.GetProperty("after_hex").GetString()!);
            for(int p=0;p<0x800;p++)if(m.Memory[p]!=after[p])throw new InvalidDataException($"Timed sound release RAM{p:X4}: expected{after[p]:X2}, actual{m.Memory[p]:X2}");
            count++;
        }return count;
    }
    public static int Matrix(string evidence,string kind)
    {
        using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection","sound-lifecycle.json")));int count=0;
        foreach(var row in doc.RootElement.GetProperty("rows").EnumerateArray()){
            if(row.GetProperty("case").GetProperty("kind").GetString()!=kind)continue;
            var m=new Machine();Convert.FromHexString(row.GetProperty("before_hex").GetString()!).CopyTo(m.Memory,0);
            if(kind=="release")AddersSoundLifecycleMemory.ReleaseChannels(m,0x1A0);
            else if(kind=="cancel")AddersSoundLifecycleMemory.Cancel(m,0x8784);
            else if(kind=="finish"){AddersSoundLifecycleMemory.FinishRoot(m,0x1A0);m.Memory[0x44]--;}
            else throw new NotSupportedException(kind);
            byte[] expected=Convert.FromHexString(row.GetProperty("after_hex").GetString()!);
            // Only caller-owned native stack scratch is outside this memory helper.
            foreach(int p in Enumerable.Range(0,0x6F0).Concat(Enumerable.Range(0x702,0xFE)))
                if(m.Memory[p]!=expected[p])throw new InvalidDataException($"Sound lifecycle {kind} case{row.GetProperty("case").GetProperty("id")} RAM{p:X4}: expected{expected[p]:X2}, actual{m.Memory[p]:X2}");
            count++;
        }
        if(count!=32)throw new InvalidDataException("Incomplete sound lifecycle matrix");return count;
    }
}

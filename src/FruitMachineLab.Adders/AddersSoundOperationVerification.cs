using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public static class AddersSoundOperationVerification
{
    public static int Yield(string evidence)=>Verify(evidence,"sound-yield",(m,row)=>new AddersSoundYieldPlan(m,0x1A0,0x879E,0x700,row.GetProperty("case").GetProperty("duration").GetByte()).Instructions(),0x5CF3,0x5CDE);
    public static int Child(string evidence)=>Verify(evidence,"sound-child",(m,row)=>new AddersSoundChildPlan(m,0x1A0,0x8787,0x700).Instructions(),0x5EE3,0x5D3B);
    public static int Instrument(string evidence)=>Verify(evidence,"sound-instrument",(m,row)=>new AddersSoundInstrumentPlan(m,0x1A0,0x601,0x700).Instructions(),0x5F5B,0x5D3B);
    public static int Verify(string evidence,string stem,Func<Machine,JsonElement,IEnumerable<NativeRoutineWork>> plan,ushort entry,ushort continuation)
    {
        using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection",stem+".json")));int count=0;
        foreach(var row in doc.RootElement.GetProperty("rows").EnumerateArray()){
            var m=new Machine();Convert.FromHexString(row.GetProperty("before_hex").GetString()!).CopyTo(m.Memory,0);
            foreach(var region in doc.RootElement.GetProperty("rom_regions").EnumerateArray())Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!).CopyTo(m.Memory,region.GetProperty("address").GetInt32());
            var actual=new List<(ushort,ulong)>();using var e=new NativeRoutineExecution(plan(m,row),0,continuation,()=>true);
            e.ObserveInstruction=i=>{byte[] bytes=Convert.FromHexString(i.Bytes);if(!m.Memory.AsSpan(i.Address,bytes.Length).SequenceEqual(bytes))throw new InvalidDataException("Sound operation opcode differs");actual.Add((i.Address,i.Started));};
            while(!e.Completed){ulong due=e.NextEventCycle;byte[] before=m.Memory.AsSpan(0,0x800).ToArray();e.AdvanceTo(due-1);if(!m.Memory.AsSpan(0,0x800).SequenceEqual(before))throw new InvalidDataException("Early sound operation effect");e.AdvanceTo(due);}
            var expected=new List<(ushort,ulong)>{(entry,0)};expected.AddRange(row.GetProperty("steps").EnumerateArray().Select(i=>(doc.RootElement.GetProperty("catalog")[i[0].GetInt32()].GetProperty("pc").GetUInt16(),i[1].GetUInt64())));
            if(!actual.SequenceEqual(expected))throw new InvalidDataException($"{stem} case{count} instruction times differ");if(e.Cycle!=row.GetProperty("cycles").GetUInt64())throw new InvalidDataException("Sound operation duration differs");
            byte[] after=Convert.FromHexString(row.GetProperty("after_hex").GetString()!);for(int p=0;p<0x800;p++)if(m.Memory[p]!=after[p])throw new InvalidDataException($"{stem} case{count} RAM{p:X4}: expected{after[p]:X2}, actual{m.Memory[p]:X2}");count++;
        }return count;
    }
}

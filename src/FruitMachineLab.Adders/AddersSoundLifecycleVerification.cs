using System.Text.Json;
using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

public static class AddersSoundLifecycleVerification
{
    public static int Matrix(string evidence,string kind)
    {
        using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection","sound-lifecycle.json")));int count=0;
        foreach(var row in doc.RootElement.GetProperty("rows").EnumerateArray()){
            if(row.GetProperty("case").GetProperty("kind").GetString()!=kind)continue;
            var m=new Machine();Convert.FromHexString(row.GetProperty("before_hex").GetString()!).CopyTo(m.Memory,0);
            AddersSoundLifecycleMemory.ReleaseChannels(m,0x1A0);
            byte[] expected=Convert.FromHexString(row.GetProperty("after_hex").GetString()!);
            // Only caller-owned native stack scratch is outside this memory helper.
            foreach(int p in Enumerable.Range(0,0x6F0).Concat(Enumerable.Range(0x702,0xFE)))
                if(m.Memory[p]!=expected[p])throw new InvalidDataException($"Sound lifecycle {kind} case{row.GetProperty("case").GetProperty("id")} RAM{p:X4}: expected{expected[p]:X2}, actual{m.Memory[p]:X2}");
            count++;
        }
        if(count!=16)throw new InvalidDataException("Incomplete sound lifecycle matrix");return count;
    }
}

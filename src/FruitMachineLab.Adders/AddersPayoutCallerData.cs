using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public static class AddersPayoutCallerData
{
    public static void Load(Machine m,string evidence)
    {
        AddersPayoutDisplay.LoadRomData(m,evidence);AddersPayoutDisplayTiming.LoadRomData(m,evidence);
        using var payout=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection","payout-data.json")));
        foreach(var region in payout.RootElement.GetProperty("native_regions").EnumerateArray())Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!).CopyTo(m.Memory,region.GetProperty("address").GetInt32());
        using var input=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection","input-condition-timing.json")));
        foreach(var region in input.RootElement.GetProperty("rom_regions").EnumerateArray())Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!).CopyTo(m.Memory,region.GetProperty("address").GetInt32());
        using var caller=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection","caller-timing.json")));
        foreach(var region in caller.RootElement.GetProperty("rom_regions").EnumerateArray())Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!).CopyTo(m.Memory,region.GetProperty("address").GetInt32());
        using var word=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection","payout-word-data.json")));
        foreach(var region in word.RootElement.GetProperty("regions").EnumerateArray())Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!).CopyTo(m.Memory,region.GetProperty("address").GetInt32());
    }
}

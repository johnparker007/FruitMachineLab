using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public static class BoardSelectionState
{
    public static ushort Apply(Machine machine,string evidence,bool diceRequests=false)
    {
        using var capture=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash",diceRequests ? "dice-requests.json" : "board-selection.json")));var root=capture.RootElement;
        Convert.FromHexString(root.GetProperty("ram_hex").GetString()!).CopyTo(machine.Memory,0);
        using var data=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"maps","board-selection-data.json")));
        foreach(var range in data.RootElement.GetProperty("ranges").EnumerateObject())Convert.FromHexString(range.Value.GetString()!).CopyTo(machine.Memory,Convert.ToInt32(range.Name,16));
        if(diceRequests)LoadDiceData(machine,evidence);
        ushort First(string key)=>Convert.ToUInt16(root.GetProperty("initial").GetProperty(key).GetString(),16);
        ushort Last(string key)=>Convert.ToUInt16(root.GetProperty("terminal").GetProperty(key).GetString(),16);
        machine.Control=new(machine,First("s"));if(!diceRequests)machine.WriteWord(Last("s"),0xBEEF);
        machine.DataStackBase=Cell.Add(diceRequests ? First("u") : Last("u"),8);machine.SetDataPointer(First("u"));
        machine.WriteWord(0x719F,First("opt"));machine.WriteWord(0x719B,First("abort"));
        return First("clock");
    }
    public static void LoadDiceData(Machine machine,string evidence)
    {
        using var data=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"maps","dice-request-data.json")));
        foreach(var range in data.RootElement.GetProperty("ranges").EnumerateObject())Convert.FromHexString(range.Value.GetString()!).CopyTo(machine.Memory,Convert.ToInt32(range.Name,16));
    }
}

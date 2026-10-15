using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public static class BoardMovementState
{
    public static void LoadData(Machine machine,string evidence)
    {
        using var data=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"maps","board-movement-data.json")));
        foreach(var range in data.RootElement.GetProperty("ranges").EnumerateObject())Convert.FromHexString(range.Value.GetString()!).CopyTo(machine.Memory,Convert.ToUInt16(range.Name,16));
    }
    public static ushort Apply(Machine machine,string evidence,bool nudgePotProbe=false)
    {
        BoardSelectionState.Apply(machine,evidence,true);LoadData(machine,evidence);
        using var data=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash",nudgePotProbe ? "nudge-pot-probe.json" : "board-movement.json")));var root=data.RootElement;
        Convert.FromHexString(root.GetProperty("ram_hex").GetString()!).CopyTo(machine.Memory,0);
        ushort First(string key)=>Convert.ToUInt16(root.GetProperty("initial").GetProperty(key).GetString(),16);
        machine.Control=new(machine,First("s"));machine.DataStackBase=Cell.Add(First("u"),8);machine.SetDataPointer(First("u"));
        machine.WriteWord(0x719F,First("opt"));machine.WriteWord(0x719B,First("abort"));return First("clock");
    }
}

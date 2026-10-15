using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public static class BoardLinkState
{
    // Trace-backed shapes at the two natural DBC4 entries. Do not decode
    // arbitrary native stack bytes as calls or loops.
    public static SoundContinuation? ResolveSoundContinuation(Machine m,ushort at)
    {
        ushort root=m.ReadWord(Cell.Add(at,0x13)),cursor=m.ReadWord(Cell.Add(at,8)),callback=m.ReadWord(Cell.Add(at,4));
        if((cursor!=0x971A || callback!=0x5E1F) && (cursor!=0x971C || callback!=0x5E29))return null;
        if(m.Memory[0x971A]!=0xCE || m.Memory[0x971B]!=0xFF || m.Memory[0x971C]!=0xC0)return null;
        if(root==0x9714 && m.ReadWord(Cell.Add(at,6))==Cell.Add(at,0x25))return new(callback,[]);
        if(root==0x971F && m.ReadWord(0x9728)==0xC197 && m.Memory[0x972A]==0x14 && m.Memory[0x972B]==0xC0 && m.ReadWord(Cell.Add(at,6))==Cell.Add(at,0x23) && m.ReadWord(Cell.Add(at,0x23))==0x972B)return new(callback,[0x972B]);
        return null;
    }
    public static void LoadData(Machine machine,string evidence)
    {
        using var nudge=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"maps","nudge-preparation-data.json")));
        foreach(var range in nudge.RootElement.GetProperty("ranges").EnumerateObject())Convert.FromHexString(range.Value.GetString()!).CopyTo(machine.Memory,Convert.ToUInt16(range.Name,16));
        using var availability=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"maps","nudge-availability-data.json")));
        foreach(var range in availability.RootElement.GetProperty("ranges").EnumerateObject())Convert.FromHexString(range.Value.GetString()!).CopyTo(machine.Memory,Convert.ToUInt16(range.Name,16));
        using var data=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"maps","board-link-data.json")));
        foreach(var range in data.RootElement.GetProperty("ranges").EnumerateObject())Convert.FromHexString(range.Value.GetString()!).CopyTo(machine.Memory,Convert.ToUInt16(range.Name,16));
    }
    public static ushort Apply(Machine machine,string evidence,string kind,bool continuation=false,bool availability=false,bool nudgeEntry=false,bool nudgePrompt=false,bool nudgeRequest=false,bool nudgeMotion=false)
    {
        if(kind is not ("ladder" or "snake"))throw new ArgumentException("Unknown board link kind",nameof(kind));
        BoardMovementState.Apply(machine,evidence);LoadData(machine,evidence);
        using var data=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash",nudgeMotion ? "nudge-motion-vm.json" : nudgeRequest ? "nudge-request.json" : nudgePrompt ? "nudge-prompt.json" : nudgeEntry ? "nudge-entry.json" : availability ? "ladder-availability.json" : kind+"-link"+(continuation ? "-next" : "")+".json")));var root=data.RootElement;
        Convert.FromHexString(root.GetProperty("ram_hex").GetString()!).CopyTo(machine.Memory,0);
        ushort First(string key)=>Convert.ToUInt16(root.GetProperty("initial").GetProperty(key).GetString(),16);
        machine.Control=new(machine,First("s"));machine.DataStackBase=Cell.Add(First("u"),8);machine.SetDataPointer(First("u"));
        machine.WriteWord(0x719F,First("opt"));machine.WriteWord(0x719B,First("abort"));return First("clock");
    }
}

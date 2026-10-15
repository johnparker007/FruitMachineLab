using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Trace-backed entry boundary, not startup or a fabricated complete machine state.
public static class SkillCashCallerState
{
    public static ushort Apply(Machine m,string evidence,bool boardResult=false)
    {
        using var document=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash",boardResult ? "board-result.json" : "caller.json")));
        var root=document.RootElement;var first=root.GetProperty("rows")[0].EnumerateArray().Select(x=>(ushort)x.GetInt32()).ToArray();
        m.Data.Clear();
        // The type cell is consumed before DFF6; its fourth caller cell is
        // separately observed there, below the four visible entry cells.
        if(boardResult){var caller=root.GetProperty("rows").EnumerateArray().First(row=>row[0].GetInt32()==0xDFF6);m.Data.Push((ushort)caller[5].GetInt32());}
        for(int n=5;n>=2;n--)m.Data.Push(first[n]);m.DataStackBase=Cell.Add(first[6],(ushort)(boardResult ? 10 : 8));
        m.Control=new(m,first[7]){LoopFrame=first[9]};m.LocalFrame=first[8];m.WriteWord(m.LocalFrame,first[10]);m.WriteWord(first[7],0xBEEF);
        foreach(var pair in new[]{(11,0x2D),(13,0x324),(16,0x90),(17,0xBA),(18,0x2FA),(22,0x327),(23,0xA0)})m.WriteWord((ushort)pair.Item2,first[pair.Item1]);
        foreach(var pair in new[]{(12,0x33),(14,0x4F),(15,0x4E),(19,0x2C),(20,0x322),(21,0x323)})m.Memory[pair.Item2]=(byte)first[pair.Item1];
        m.Memory[0xC9]=32;
        Convert.FromHexString(root.GetProperty("initial_frames").GetString()!).CopyTo(m.Memory,0x100);
        var alpha=root.GetProperty("initial_alpha");
        foreach(var pair in new[]{("cursor",0x54),("control",0x55),("stop",0x57),("mirror",0xC5),("digit",0xC4)})m.Memory[pair.Item2]=Convert.ToByte(alpha.GetProperty(pair.Item1).GetString(),16);
        Convert.FromHexString(alpha.GetProperty("shadow").GetString()!).CopyTo(m.Memory,0x58);
        Convert.FromHexString(alpha.GetProperty("digits").GetString()!).CopyTo(m.Memory,0x1A);
        return first[24];
    }
}

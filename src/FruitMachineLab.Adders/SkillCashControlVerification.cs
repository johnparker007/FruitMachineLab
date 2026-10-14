using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record ControlCapture(Dictionary<string,ushort>[] Initial,Dictionary<string,ushort>[] Loop,string RawDebugSha256);
public static class SkillCashControlVerification
{
    public static int Verify(string evidenceDirectory)
    {
        var capture=JsonSerializer.Deserialize<ControlCapture>(File.ReadAllText(Path.Combine(evidenceDirectory,"skill-cash","control-prefix.json")),
            new JsonSerializerOptions{PropertyNameCaseInsensitive=true}) ?? throw new InvalidDataException("Missing control capture");
        var first=capture.Initial[0];
        var m=new Machine { LocalFrame=first["f4"] };
        m.Control=new VmControlStack(m,first["s"]){LoopFrame=first["f6"]};
        m.WriteWord(first["s"],0xBEEF);m.WriteWord(first["f4"],first["frame"]);
        var allocated=capture.Initial.First(s=>s["y"]==0xC726);
        // Local allocation does not clear reused stack bytes. Seed their captured
        // pre-initialization contents rather than assuming they are zero.
        m.WriteWord(allocated["f4"],allocated["frame"]);
        foreach(var name in new[]{"fourth","third","second","top"})m.Data.Push(first[name]);
        int total=0;
        RecoveredScript Resolve(ushort address)=>new(Path.Combine(evidenceDirectory,"VM-SCRIPTS",address.ToString("X4")+".txt"));
        void Range(Dictionary<string,ushort>[] steps,ushort start,ushort end)
        {
            int cursor=0,depth=m.Data.Count;
            var executor=new ScriptExecutor(m) { ResolveScript=Resolve,BeforeInstruction=(instruction,state)=> {
                if(cursor>=steps.Length)throw new InvalidDataException("Extra prefix instruction");
                var observed=steps[cursor++];
                if(instruction.Site!=observed["y"] || instruction.Token!=observed["token"])
                    throw new InvalidDataException("Control prefix instruction mismatch");
                if(state.Control!.Pointer!=observed["s"] || state.LocalFrame!=observed["f4"] || state.Control.LoopFrame!=observed["f6"] || state.ReadWord(state.LocalFrame)!=observed["frame"])
                    throw new InvalidDataException($"Control prefix S/F4/F6/local bytes mismatch at {instruction.Site:X4}");
                var cells=state.Data.ToArray();var names=new[]{"top","second","third","fourth"};
                for(int n=0;n<Math.Min(cells.Length,4);n++)if(cells[n]!=observed[names[n]])throw new InvalidDataException("Prefix data cell differs");
                if(observed["u"]!=unchecked((ushort)(steps[0]["u"]-2*(state.Data.Count-depth))))throw new InvalidDataException("Prefix U mismatch");
            }};
            executor.RunRange(Resolve(0xC721),start,end);
            if(cursor!=steps.Length)throw new InvalidDataException("Unconsumed prefix observations");total+=cursor;
        }
        Range(capture.Initial,0xC721,0xC732);
        Range(capture.Loop,0xC73C,0xC753);
        if(m.Data.Peek()!=25 || m.Control.Pointer!=0x0786 || m.LocalFrame!=0x0792 || m.Control.LoopIndex!=0)
            throw new InvalidDataException("Feature prefix final state mismatch");
        return total;
    }
}

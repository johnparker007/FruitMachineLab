using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record LampVerification(int Calls,int Instructions,int Requests);
public static class SkillCashLampVerification
{
    public static LampVerification Verify(string evidenceDirectory)
    {
        var capture=JsonSerializer.Deserialize<CompensationCapture>(File.ReadAllText(Path.Combine(evidenceDirectory,"skill-cash","lamp-calls.json")),
            new JsonSerializerOptions{PropertyNameCaseInsensitive=true}) ?? throw new InvalidDataException("Missing lamp helper capture");
        RecoveredScript Resolve(ushort address)=>new(Path.Combine(evidenceDirectory,"VM-SCRIPTS",address.ToString("X4")+".txt"));
        int instructions=0,requests=0;
        foreach(var call in capture.Calls)
        {
            var first=call.Steps[0];var m=new Machine {LocalFrame=first["f4"]};SkillCashData.Load(m);
            m.Control=new VmControlStack(m,first["s"]){LoopFrame=first["f6"]};
            m.WriteWord(first["s"],0xC6B3);m.WriteWord(first["f4"],first["frame"]);
            m.WriteWord(first["f6"],(ushort)(first["frame"]>>8));
            foreach(var name in new[]{"fourth","third","second","top"})m.Data.Push(first[name]);
            var output=new List<LampRequest>();var lamps=new Mpu4LampRequests(m,output.Add);int cursor=0;
            var executor=new ScriptExecutor(m) {ResolveScript=Resolve,ResolveWord=SkillCashData.ResolveWord,
                WordHandler=(instruction,state)=>lamps.HandleWord(instruction),BeforeInstruction=(instruction,state)=> {
                    if(cursor>=call.Steps.Length)throw new InvalidDataException("Extra lamp helper instruction");
                    var observed=call.Steps[cursor++];
                    if(instruction.Site!=observed["y"] || instruction.Token!=observed["token"] || state.Control!.Pointer!=observed["s"])
                        throw new InvalidDataException("Lamp dynamic dispatch/control stack mismatch");
                    var cells=state.Data.ToArray();var names=new[]{"top","second","third","fourth"};
                    for(int n=0;n<Math.Min(4,cells.Length);n++)if(cells[n]!=observed[names[n]])throw new InvalidDataException("Lamp helper stack mismatch");
                    if(observed["u"]!=unchecked((ushort)(first["u"]-2*(state.Data.Count-4))) || state.LocalFrame!=observed["f4"] || state.Control.LoopFrame!=observed["f6"])
                        throw new InvalidDataException("Lamp helper U/F4/F6 mismatch");
                }};
            executor.Run(Resolve(0xC62B));
            if(cursor!=call.Steps.Length || output.Count!=6 || m.Control.ResumeCursor!=0xC6B3)
                throw new InvalidDataException("Lamp helper call did not preserve its continuation");
            instructions+=cursor;requests+=output.Count;
        }
        return new(capture.Calls.Length,instructions,requests);
    }
}

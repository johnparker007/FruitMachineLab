using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record SelectionDecision(Dictionary<string,ushort> Entry,ushort Latch,ushort Timer,ushort Abort,
    Dictionary<string,ushort> Gate,Dictionary<string,ushort> Exit,ushort Next);
public record SelectionCapture(SelectionDecision[] Iterations,string Classification,string RawDebugSha256);
public record SelectionVerification(int Decisions,IReadOnlyList<ushort> Choices)
{
    public int AcceptedChoices=>Choices.Count;
}

public static class SkillCashSelectionVerification
{
    public static SelectionVerification Verify(string evidenceDirectory)
    {
        var capture=JsonSerializer.Deserialize<SelectionCapture>(File.ReadAllText(Path.Combine(evidenceDirectory,"skill-cash","selection-decisions.json")),
            new JsonSerializerOptions{PropertyNameCaseInsensitive=true}) ?? throw new InvalidDataException("Missing selection capture");
        var compensation=SkillCashCompensationVerification.Load(evidenceDirectory);
        var sound=SkillCashSoundVerification.Verify(evidenceDirectory);
        RecoveredScript Resolve(ushort address)=>new(Path.Combine(evidenceDirectory,"VM-SCRIPTS",address.ToString("X4")+".txt"));
        var accepted=new List<ushort>();
        int acceptedReads=0;
        foreach(var decision in capture.Iterations)
        {
            byte computedChoice=sound.ReadChoices[acceptedReads++];
            var e=decision.Entry;
            var m=new Machine { LocalFrame=e["f4"] };SkillCashData.Load(m);
            m.Control=new VmControlStack(m,e["s"]){LoopFrame=e["f6"]};
            m.WriteWord(e["s"],0xC757);m.WriteWord(e["f6"],(ushort)(e["frame"]>>8));
            m.WriteWord(e["f4"],e["frame"]);m.WriteWord(0x324,e["seed"]);m.WriteWord(0x719B,decision.Abort);
            m.WriteWord(0x90,decision.Latch);m.WriteWord(0x2D,decision.Timer);
            if(computedChoice!=e["top"])throw new InvalidDataException("Choice stream differs from selection input cell");
            m.Data.Push(e["second"]);m.Data.Push(computedChoice);
            var executor=new ScriptExecutor(m) {
                ResolveScript=Resolve,
                WordHandler=(instruction,state)=> {
                    if(instruction.Token!=0xC668)return false;
                    var interval=compensation.Single(c=>(c.Steps[0]["frame"]>>8)==(e["frame"]>>8));
                    state.Control!.EnterCall(0xC68C);SkillCashCompensationVerification.Execute(evidenceDirectory,interval,state);return true;
                },
                BeforeInstruction=(instruction,state)=> {
                    if(instruction.Site==0xC676 && (state.Data.Peek()!=decision.Gate["top"] || state.Control!.Pointer!=decision.Gate["s"]))
                        throw new InvalidDataException("Computed selection gate input differs from MAME");
                }
            };
            executor.RunRange(Resolve(0xC699),0xC6B3,0xC6C3);
            if(decision.Exit["u"]!=unchecked((ushort)(e["u"]-2*(m.Data.Count-2))))throw new InvalidDataException("Selection U differs from MAME");
            ushort flag=m.Pop();ushort choice=m.Data.Peek();
            if(flag!=decision.Exit["top"] || choice!=decision.Exit["second"] || m.Control.Pointer!=decision.Exit["s"] || m.LocalFrame!=decision.Exit["f4"] || m.Control.LoopFrame!=decision.Exit["f6"])
                throw new InvalidDataException("Selection decision differs from MAME");
            ushort next=flag==0 ? (ushort)0xC6AB : (ushort)0xC6C8;
            if(next!=decision.Next)throw new InvalidDataException("Selection branch successor differs from MAME");
            if(flag!=0)accepted.Add(choice);
        }
        if(capture.Iterations.Length!=1202 || accepted.Count!=3)throw new InvalidDataException("Selection decision coverage changed");
        return new(capture.Iterations.Length,accepted);
    }
}

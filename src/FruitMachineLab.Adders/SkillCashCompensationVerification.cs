using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record CompensationCall(Dictionary<string,ushort>[] Steps);
public record CompensationCapture(string Classification,string RawDebugSha256,CompensationCall[] Calls);

public static class SkillCashCompensationVerification
{
    public static CompensationCall[] Load(string evidenceDirectory) =>
        JsonSerializer.Deserialize<CompensationCapture>(File.ReadAllText(Path.Combine(evidenceDirectory,"skill-cash","compensation-calls.json")),
            new JsonSerializerOptions{PropertyNameCaseInsensitive=true})?.Calls ?? throw new InvalidDataException("Missing compensation capture");

    public static int Verify(string evidenceDirectory)
    {
        var calls=Load(evidenceDirectory);
        foreach(var call in calls)
        {
            var first=call.Steps[0];
            var m=new Machine();SkillCashData.Load(m);m.WriteWord(0x324,first["seed"]);
            m.LocalFrame=first["f4"];m.Control=new VmControlStack(m,first["s"]){LoopFrame=first["f6"]};
            m.WriteWord(first["s"],0xC68C);m.WriteWord(first["f6"],(ushort)(first["frame"]>>8));
            foreach(var name in new[]{"fourth","third","second","top"})m.Data.Push(first[name]);
            Execute(evidenceDirectory,call,m);
        }
        if(calls.Length!=3)throw new InvalidDataException("Expected three chance calls");
        return calls.Length;
    }

    public static void Execute(string evidenceDirectory,CompensationCall call,Machine machine)
    {
        var steps=call.Steps;
        if(steps.Length==0 || steps[0]["y"]!=0xC66A || steps[^1]["y"]!=0xC672)
            throw new InvalidDataException("Incomplete chance interval");
        // Recover RAM *inputs* from the values immediately following each recorded
        // byte+word fetch. Calculated ratio, index and chance are never injected.
        foreach(ushort site in new ushort[]{0xA0F1,0xA102})
        {
            int at=Array.FindIndex(steps,s=>s["y"]==site);
            if(at<0 || at+1>=steps.Length)throw new InvalidDataException("Missing compensation RAM read");
            var address=steps[at]["top"];
            var after=steps[at+1];
            if(after["top"]>255)throw new InvalidDataException("Recorded byte exceeds byte range");
            machine.Memory[address]=(byte)after["top"];
            machine.WriteWord(Cell.Add(address,1),after["second"]);
        }
        ushort InputResult(ushort condition) => condition switch {
            4=>steps.Single(s=>s["y"]==0x9F62)["top"],
            3=>steps.Single(s=>s["y"]==0x9F64)["top"],
            _=>throw new NotSupportedException($"Uncaptured input condition {condition}")
        };
        int cursor=0;
        RecoveredScript Resolve(ushort address)=>new(Path.Combine(evidenceDirectory,"VM-SCRIPTS",address.ToString("X4")+".txt"));
        int originalDepth=machine.Data.Count;
        var executor=new ScriptExecutor(machine) {
            ResolveScript=Resolve,InputCondition=condition=>InputResult(condition)!=0,
            BeforeInstruction=(instruction,state)=> {
                if(cursor>=steps.Length)throw new InvalidDataException("Runtime executed extra chance instruction");
                var observed=steps[cursor++];
                if(instruction.Site!=observed["y"] || instruction.Token!=observed["token"])
                    throw new InvalidDataException($"Chance control-flow mismatch at {instruction.Site:X4}");
                var stack=state.Data.ToArray();
                var names=new[]{"top","second","third","fourth"};
                for(int n=0;n<Math.Min(4,stack.Length);n++)
                    if(stack[n]!=observed[names[n]])throw new InvalidDataException($"Chance stack mismatch at {instruction.Site:X4}, cell {n}");
                int delta=state.Data.Count-originalDepth;
                if(observed["u"]!=unchecked((ushort)(steps[0]["u"]-2*delta)))
                    throw new InvalidDataException("Chance stack depth differs from recorded U");
                if(state.ReadWord(0x324)!=observed["seed"])throw new InvalidDataException("Chance RNG seed mismatch");
                if(state.Control is not null && (state.Control.Pointer!=observed["s"] || state.LocalFrame!=observed["f4"] || state.Control.LoopFrame!=observed["f6"]))
                    throw new InvalidDataException($"Chance S/F4/F6 mismatch at {instruction.Site:X4}");
                // IRQ counter is an explicitly recorded platform input. No timing or
                // helper return is invented to reproduce the chance calculation.
                state.Memory[0x33]=(byte)observed["irq"];
            }
        };
        executor.Run(Resolve(0xC66A));
        if(cursor!=steps.Length || machine.Data.Count!=originalDepth+1)
            throw new InvalidDataException("Chance instruction count or stack effect mismatch");
    }
}

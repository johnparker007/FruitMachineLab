using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record HelperSnapshot(ushort Site,ushort Token,ushort Top,ushort Second,ushort Third,ushort Fourth,
    ushort Seed,ushort Irq,ushort Frame,ushort Option,ushort U);
public record HelperCall(string Kind,HelperSnapshot Entry,HelperSnapshot Exit,ushort? Chance);
public record HelperVerification(int RandomCalls,int PercentageCalls,int OptionCalls,int GateCalls);

public static class SkillCashHelperVerification
{
    public static HelperVerification Verify(string evidenceDirectory)
    {
        var calls=JsonSerializer.Deserialize<HelperCall[]>(File.ReadAllText(Path.Combine(evidenceDirectory,"skill-cash","helper-calls.json")),
            new JsonSerializerOptions{PropertyNameCaseInsensitive=true}) ?? throw new InvalidDataException("Missing helper calls");
        RecoveredScript Resolve(ushort address)=>new(Path.Combine(evidenceDirectory,"VM-SCRIPTS",address.ToString("X4")+".txt"));
        int random=0,percentage=0,option=0,gate=0;
        foreach(var call in calls)
        {
            var m=new Machine(); SkillCashData.Load(m);
            m.WriteWord(0x324,call.Entry.Seed);m.Memory[0x33]=(byte)call.Entry.Irq;m.WriteWord(0x719F,call.Entry.Option);
            m.Data.Push(call.Entry.Second);m.Data.Push(call.Entry.Top);
            var executor=new ScriptExecutor(m) {
                ResolveScript=Resolve,LoopIndex=()=>(ushort)(call.Entry.Frame>>8),
                ObservedWord=(instruction,state)=> {
                    if(instruction.Token!=0xC668) return false;
                    state.Data.Push(call.Chance ?? throw new InvalidDataException("Missing observed compensation/chance helper result"));
                    return true;
                }
            };
            int before=m.Data.Count;
            ushort body;
            switch(call.Kind)
            {
                case "random": body=0x99D8;random++;break;
                case "percentage": body=0x9A00;percentage++;break;
                case "option": body=0xC646;option++;break;
                case "gate": body=0xC676;gate++;break;
                default:throw new InvalidDataException("Unknown helper kind");
            }
            var script=Resolve(body);
            if(call.Entry.Site!=body || script.Instructions[0].Token!=call.Entry.Token || call.Exit.Token!=0x792F)
                throw new InvalidDataException("Helper snapshot token or entry differs from recovered listing");
            executor.Run(script);
            var output=m.Data.ToArray();
            if(output[0]!=call.Exit.Top || (output.Length>1 && output[1]!=call.Exit.Second))
                throw new InvalidDataException($"{call.Kind} stack result differs from MAME at {call.Entry.Site:X4}");
            int expectedDelta=call.Kind is "random" or "option" ? 1 : call.Kind=="percentage" ? -1 : 0;
            if(m.Data.Count!=before+expectedDelta) throw new InvalidDataException("Helper stack effect differs from recovery");
            if(call.Exit.U!=unchecked((ushort)(call.Entry.U-2*expectedDelta)))
                throw new InvalidDataException("Recorded U register differs from translated stack effect");
            if(call.Kind=="random" && m.ReadWord(0x324)!=call.Exit.Seed) throw new InvalidDataException("Seed update differs from MAME");
        }
        if(random!=3 || percentage!=3 || option!=3 || gate!=1202) throw new InvalidDataException("Unexpected focused fixture coverage");
        return new(random,percentage,option,gate);
    }
}

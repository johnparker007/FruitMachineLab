using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record NvramCall(Dictionary<string,ushort> Before,Dictionary<string,ushort> After);
public record AwardCapture(NvramCall[] Calls,Dictionary<string,ushort>[][] Cores);
public record AwardVerification(int Refreshes,int Transfers,int Instructions,ushort CurrentWin);

public static class SkillCashAwardVerification
{
    public static AwardVerification Verify(string evidenceDirectory)
    {
        var capture=JsonSerializer.Deserialize<AwardCapture>(File.ReadAllText(Path.Combine(evidenceDirectory,"skill-cash","award-calls.json")),
            new JsonSerializerOptions{PropertyNameCaseInsensitive=true}) ?? throw new InvalidDataException("Missing award capture");
        if(capture.Calls.Length!=13 || capture.Cores.Length!=10)throw new InvalidDataException("Incomplete award capture");
        void Seed(Machine m,Dictionary<string,ushort> state) {
            for(ushort address=0x2F0;address<0x322;address++)m.Memory[address]=(byte)state[(address<0x309 ? "source" : "copy")+address.ToString("X4")];
            m.Memory[0x322]=(byte)state["checksum"];m.Memory[0x323]=(byte)state["mode"];m.Memory[0x2C]=(byte)state["guard"];
        }
        foreach(var call in capture.Calls) {
            var m=new Machine();Seed(m,call.Before);Mpu4Nvram.Refresh(m);
            for(ushort address=0x2F0;address<0x322;address++) {
                var key=(address<0x309 ? "source" : "copy")+address.ToString("X4");
                if(m.Memory[address]!=call.After[key])throw new InvalidDataException($"NVRAM byte mismatch at {address:X4}");
            }
            if(m.Memory[0x322]!=call.After["checksum"] || m.Memory[0x2C]!=call.After["guard"] || call.Before["u"]!=call.After["u"])
                throw new InvalidDataException("NVRAM checksum/guard/U mismatch");
        }
        int instructions=0;ushort pending=10,win=0;
        RecoveredScript Resolve(ushort address)=>new(Path.Combine(evidenceDirectory,"VM-SCRIPTS",address.ToString("X4")+".txt"));
        foreach(var steps in capture.Cores) {
            var first=steps[0];var last=steps[^1];
            if(first["pending"]!=pending || first["win"]!=win)throw new InvalidDataException("Award transfers do not join");
            var native=capture.Calls.First(c=>c.Before["pending"]==last["pending"] && c.Before["win"]==last["win"]);
            var m=new Machine();Seed(m,native.Before);
            m.WriteWord(0xBA,pending);m.WriteWord(0x2FA,win);m.LocalFrame=first["f4"];m.WriteWord(m.LocalFrame,first["frame"]);
            m.Control=new VmControlStack(m,first["s"]){LoopFrame=first["f6"]};
            // Static ROM pointer cells and byte values, not inferred predicate results.
            m.WriteWord(0x851E,0xFF36);m.WriteWord(0x8522,0xFF3A);m.Memory[0xFF36]=0xFF;m.Memory[0xFF3A]=0xFF;
            foreach(var name in new[]{"fourth","third","second","top"})m.Data.Push(first[name]);
            int cursor=0;
            void Compare(Instruction instruction,Machine state) {
                if(cursor>=steps.Length)throw new InvalidDataException("Extra accounting instruction");
                var reference=steps[cursor++];
                if(instruction.Site==0xAFC2) {
                    for(ushort address=0x309;address<0x322;address++)
                        if(state.Memory[address]!=native.After["copy"+address.ToString("X4")])throw new InvalidDataException("Integrated accounting complement mismatch");
                    if(state.Memory[0x322]!=native.After["checksum"])throw new InvalidDataException("Integrated accounting checksum mismatch");
                }
                if(instruction.Site!=reference["y"] || instruction.Token!=reference["token"] || state.Control!.Pointer!=reference["s"] ||
                    state.LocalFrame!=reference["f4"] || state.Control.LoopFrame!=reference["f6"] || state.ReadWord(0xBA)!=reference["pending"] || state.ReadWord(0x2FA)!=reference["win"])
                    throw new InvalidDataException($"Accounting state mismatch at {instruction.Site:X4}");
                var cells=state.Data.ToArray();var names=new[]{"top","second","third","fourth"};
                for(int n=0;n<Math.Min(4,cells.Length);n++)if(cells[n]!=reference[names[n]])throw new InvalidDataException("Accounting stack mismatch");
                if(reference["u"]!=unchecked((ushort)(first["u"]-2*(cells.Length-4))))throw new InvalidDataException("Accounting U mismatch");
            }
            new ScriptExecutor(m){ResolveScript=Resolve,BeforeInstruction=Compare}.RunRange(Resolve(0xAF93),0xAF9D,0xAFC4);
            Compare(new(0xAFC6,0x8579,"boundary",null,null),m);
            if(cursor!=steps.Length)throw new InvalidDataException("Unused accounting observations");
            pending=m.ReadWord(0xBA);win=m.ReadWord(0x2FA);instructions+=cursor-1;
        }
        if(pending!=0 || win!=10)throw new InvalidDataException("Accounting final balance mismatch");
        return new(capture.Calls.Length,capture.Cores.Length,instructions,win);
    }
}

using System.Globalization;
using System.Text.RegularExpressions;
using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

public record Dispatch(ushort Site, ushort Token, ushort Stack, ushort Top, ushort Tick);
public record SkillCashResult(byte Level, ushort PendingAward, IReadOnlyList<DiagnosticEvent> Events);

// A bounded replay of the recovered feature mechanics, not a free-running game.
// Selection decisions execute from recorded platform inputs; award data is recovered ROM data.
public static class SkillCashReplay
{
    public static IReadOnlyList<Dispatch> ReadTrace(string path) => File.ReadLines(path).Select(line =>
        Regex.Match(line, @"FEATURE_VM y=([0-9A-F]{4}) token=([0-9A-F]{4}) u=([0-9A-F]{4}) top=([0-9A-F]{4}) s=[0-9A-F]{4} tick=([0-9A-F]{4})"))
        .Where(m => m.Success).Select(m => new Dispatch(Hex(m,1),Hex(m,2),Hex(m,3),Hex(m,4),Hex(m,5))).ToArray();
    private static ushort Hex(Match m, int group) => ushort.Parse(m.Groups[group].Value, NumberStyles.HexNumber);

    public static SkillCashResult Run(string evidenceDirectory)
    {
        var trace = ReadTrace(Path.Combine(evidenceDirectory,"skill-cash","dispatch.txt"));
        var decisions=SkillCashSelectionVerification.Verify(evidenceDirectory);
        var loops=SkillCashLoopVerification.Verify(evidenceDirectory);
        var selected = trace.Where(x => x.Site == 0xC757).ToArray();
        var timers = trace.Where(x => x.Site == 0xC755).ToArray();
        if (selected.Length != 3 || timers.Length != 3) throw new InvalidDataException("Expected one three-stage Skill Cash interval");
        var frameAddresses=trace.Where(x=>x.Site==0xC759).Select(x=>x.Top).Distinct().ToArray();
        if(frameAddresses.Length!=1) throw new InvalidDataException("Local-frame address changed within feature");
        var machine = new Machine { LocalFrame = Cell.Subtract(frameAddresses[0],1) };
        SkillCashData.Load(machine);
        var events = new List<DiagnosticEvent>();
        string Listing(string name) => Path.Combine(evidenceDirectory,"VM-SCRIPTS",name + ".txt");
        new ScriptExecutor(machine).Run(new RecoveredScript(Listing("C637")));
        for (ushort stage = 0; stage < 3; stage++)
        {
            machine.Memory[machine.LocalFrame] = (byte)stage;
            var timer = Cell.Subtract(25, Cell.Multiply(stage,5));
            if (timers[stage].Top != timer) throw new InvalidDataException($"Timer mismatch at stage {stage}");
            // C757..C75F: frame address, fetch, signed min, frame address, store.
            machine.Data.Push(loops.Choices[stage]);
            var stageIndex=stage;
            new ScriptExecutor(machine) { BeforeInstruction=(instruction,state)=> {
                var reference=trace.Where(x=>x.Site==instruction.Site).ElementAt(stageIndex);
                if(instruction.Token!=reference.Token || state.Data.Count==0 || state.Data.Peek()!=reference.Top)
                    throw new InvalidDataException($"Stack mismatch at {instruction.Site:X4}, stage {stageIndex}");
            }}.RunRange(new RecoveredScript(Listing("C721")),0xC757,0xC75F);
            events.Add(new(0xC75F,"Selected level",machine.Memory[frameAddresses[0]],"Complete recovered C699 call, ROM choice stream and stage reduction; platform timing/latch data remains recorded"));
        }
        var lookup = trace.Single(x => x.Site == 0xC706);
        new ScriptExecutor(machine).RunRange(new RecoveredScript(Listing("C6FC")),0xC6FE,0xC704);
        if (lookup.Top != machine.Data.Peek()) throw new InvalidDataException("Award-table address mismatch");
        new ScriptExecutor(machine).RunRange(new RecoveredScript(Listing("C6FC")),0xC706,0xC706);
        var amount=machine.Pop();
        if(amount!=trace.Single(x => x.Site == 0xC708).Top) throw new InvalidDataException("ROM table amount differs from recorded read");
        // This debugger excludes 9F6A: preserve the unknown condition by evaluating both
        // possibilities. A replay needing that missing evidence fails instead of guessing.
        ushort Normalize(bool condition) {
            var state=new Machine(); state.Data.Push(amount);
            new ScriptExecutor(state) { InputCondition = _ => condition }.Run(new RecoveredScript(Listing("9F6A")));
            return state.Pop();
        }
        var normalized = Normalize(false);
        if(normalized!=Normalize(true)) throw new InvalidDataException("Unobserved input condition affects this award; additional trace evidence required");
        if (normalized != trace.Single(x => x.Site == 0xC70A).Top) throw new InvalidDataException("Normalized award mismatch");
        machine.Data.Push(normalized);
        new ScriptExecutor(machine) { BeforeInstruction=(instruction,state)=> {
            var reference=trace.Single(x=>x.Site==instruction.Site);
            if(instruction.Token!=reference.Token || state.Data.Peek()!=reference.Top)
                throw new InvalidDataException($"Pending store stack mismatch at {instruction.Site:X4}");
        }}.RunRange(new RecoveredScript(Listing("C6FC")),0xC70A,0xC70E);
        events.Add(new(0xC70E,"Pending award",machine.ReadWord(0x00BA),"Recovered ROM-table lookup and big-endian word store, compared with MAME"));
        var helpers=SkillCashHelperVerification.Verify(evidenceDirectory);
        events.Add(new(0x99D8,"RNG calls verified",(ushort)helpers.RandomCalls,"Native seed update and recovered random-word script compared with focused MAME capture"));
        events.Add(new(0x9A00,"Percentage calls verified",(ushort)helpers.PercentageCalls,"Native division and strict unsigned comparison compared with MAME"));
        events.Add(new(0xC676,"Selection gates verified",(ushort)helpers.GateCalls,"Recovered gates, compensation calculation and nested S/F4/F6 frames compared with MAME"));
        events.Add(new(0xC66A,"Compensation calls verified",(ushort)SkillCashCompensationVerification.Verify(evidenceDirectory),"Calculated ratio, clipped index and chance from captured RAM, input conditions and IRQ counter; no chance helper return injected"));
        events.Add(new(0xC721,"Control prefix instructions verified",(ushort)SkillCashControlVerification.Verify(evidenceDirectory),"Physical local/loop allocation, return-stack pointers and uninitialized local bytes compared with MAME"));
        events.Add(new(0xC6B3,"Selection decisions verified",(ushort)decisions.Decisions,"Calculated choice stream, panel latch and IRQ timing; accepted 3, 2, 1"));
        events.Add(new(0xC699,"Complete-loop dispatches verified",(ushort)loops.Instructions,"Canonical stack/frame/timer/RNG/choice state digests match all three complete C699 calls"));
        events.Add(new(0x4A8C,"Decoded lamp requests",(ushort)loops.LampRequests,"Native request IDs/patterns decoded; hardware characteriser and frame-RAM effects remain unverified"));
        var sound=SkillCashSoundVerification.Verify(evidenceDirectory);
        events.Add(new(0x5D3B,"Sound-stream commands verified",(ushort)sound.Commands,"ROM 8EE4 choice/timing subset matches native opcode, delay, and choice-write observations; audio synthesis is not implemented"));
        return new(machine.Memory[frameAddresses[0]],machine.ReadWord(0x00BA),events);
    }
}

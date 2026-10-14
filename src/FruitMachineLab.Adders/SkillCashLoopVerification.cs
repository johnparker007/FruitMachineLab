using System.Buffers.Binary;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record SelectionLoopCall(Dictionary<string,ushort> Initial,int Instructions,[property:JsonPropertyName("expected_sha256")] string ExpectedSha256,int[][] Inputs,
    [property:JsonPropertyName("before_reads")] int[][] BeforeReads,int[][] Anchors);
public record SelectionLoopCapture(string Classification,[property:JsonPropertyName("signature_fields")] string[] SignatureFields,
    [property:JsonPropertyName("raw_debug_sha256")] string RawDebugSha256,SelectionLoopCall[] Calls);
public record LoopVerification(int Instructions,int LampRequests,IReadOnlyList<ushort> Choices);

public static class SkillCashLoopVerification
{
    public static LoopVerification Verify(string evidenceDirectory,Action<int,int,IReadOnlyList<ushort>>? observe=null)
    {
        var options=new JsonSerializerOptions{PropertyNameCaseInsensitive=true};
        var capture=JsonSerializer.Deserialize<SelectionLoopCapture>(File.ReadAllText(Path.Combine(evidenceDirectory,"skill-cash","selection-loops.json")),options)
            ?? throw new InvalidDataException("Missing selection loop capture");
        var sound=JsonSerializer.Deserialize<NativeSoundObservation[]>(File.ReadAllText(Path.Combine(evidenceDirectory,"skill-cash","sound-events.json")),options)!;
        var enqueues=sound.Where(e=>e.Kind=="QE").ToArray();
        var resets=sound.Where(e=>e.Kind=="WC" && e.Fields["pc"]==0x5B80).ToArray();
        var compensation=SkillCashCompensationVerification.Load(evidenceDirectory);
        if(capture.Calls.Length!=3 || enqueues.Length!=3 || resets.Length!=3)throw new InvalidDataException("Incomplete native phases");
        var choices=new List<ushort>();int instructions=0,requests=0;
        var scripts=new Dictionary<ushort,RecoveredScript>();
        RecoveredScript Resolve(ushort address) {
            if(!scripts.TryGetValue(address,out var script)){script=new(Path.Combine(evidenceDirectory,"VM-SCRIPTS",address.ToString("X4")+".txt"));scripts.Add(address,script);}
            return script;
        }
        for(int stage=0;stage<capture.Calls.Length;stage++)
        {
            var call=capture.Calls[stage];var first=call.Initial;
            var m=new Machine {LocalFrame=first["f4"]};SkillCashData.Load(m);
            m.Control=new VmControlStack(m,first["s"]){LoopFrame=first["f6"]};
            m.WriteWord(first["s"],0xC757);m.WriteWord(first["f6"],(ushort)stage);m.WriteWord(first["f4"],first["frame"]);
            m.WriteWord(0x2D,first["tick"]);m.Memory[0x33]=(byte)first["irq"];m.WriteWord(0x324,first["seed"]);
            m.Memory[0x4F]=(byte)first["choice"];m.Memory[0x4E]=(byte)first["rate"];
            m.WriteWord(0x90,first["latch"]);m.WriteWord(0x719B,first["abort"]);m.WriteWord(0x719F,first["opt"]);
            foreach(var name in new[]{"fourth","third","second","top"})m.Data.Push(first[name]);
            var comp=compensation.Single(c=>(c.Steps[0]["frame"]>>8)==stage);
            foreach(ushort site in new ushort[]{0xA0F1,0xA102}) {
                int at=Array.FindIndex(comp.Steps,s=>s["y"]==site);ushort address=comp.Steps[at]["top"];
                m.Memory[address]=(byte)comp.Steps[at+1]["top"];m.WriteWord(Cell.Add(address,1),comp.Steps[at+1]["second"]);
            }
            bool Condition(ushort condition)=>condition switch {
                4=>comp.Steps.Single(s=>s["y"]==0x9F62)["top"]!=0,
                3=>comp.Steps.Single(s=>s["y"]==0x9F64)["top"]!=0,
                _=>throw new NotSupportedException($"Uncaptured condition {condition}")
            };
            var scheduler=new Mpu4ChoiceStreamScheduler(m,first["clock"]);
            void Advance(ushort target) {
                ushort delta=unchecked((ushort)(target-scheduler.Clock));
                if(delta>32767)throw new InvalidDataException("Selection clock moved backwards");
                scheduler.AdvanceTicks(delta);
            }
            var lamps=new Mpu4LampRequests(m,_=>requests++);
            int ordinal=0,input=0,anchor=0,readPhase=0;ushort clock=first["clock"];
            using var hash=IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
            var executor=new ScriptExecutor(m) {
                ResolveScript=Resolve,ResolveWord=SkillCashData.ResolveWord,InputCondition=Condition,
                OperationBoundary=(instruction,state)=> {
                    if(readPhase<call.BeforeReads.Length && call.BeforeReads[readPhase][0]==ordinal-1) {
                        if(instruction.Token!=0x790D || state.Data.Peek()!=0x2D)throw new InvalidDataException("Timer read phase attached to wrong operation");
                        ushort ticks=(ushort)call.BeforeReads[readPhase++][1];
                        state.Memory[0x33]=unchecked((byte)(state.Memory[0x33]+ticks));state.WriteWord(0x2D,Cell.Add(state.ReadWord(0x2D),ticks));
                    }
                },
                WordHandler=(instruction,state)=> {
                    if(lamps.HandleWord(instruction))return true;
                    if(instruction.Native==0x5C18) {
                        var stream=state.Pop();if(stream!=0x8EE4)throw new NotSupportedException("Unrecovered selection sound stream");
                        Advance(enqueues[stage].Fields["clock"]);if(!scheduler.Queue(stream))throw new InvalidDataException("Selection sound queue disabled");return true;
                    }
                    if(instruction.Native==0x5B77) {
                        Advance(resets[stage].Fields["clock"]);if(!scheduler.Reset())throw new InvalidDataException("Selection reset disabled");return true;
                    }
                    return false;
                },
                BeforeInstruction=(instruction,state)=> {
                    if(ordinal>=call.Instructions)throw new InvalidDataException("Extra selection loop dispatch");
                    if(input<call.Inputs.Length && call.Inputs[input][0]==ordinal) {
                        var point=call.Inputs[input++];
                        state.Memory[0x33]=unchecked((byte)(state.Memory[0x33]+point[1]));
                        state.WriteWord(0x2D,Cell.Add(state.ReadWord(0x2D),(ushort)point[2]));
                        state.WriteWord(0x90,(ushort)((state.ReadWord(0x90)|point[3])&~point[4]));clock=(ushort)point[5];
                    }
                    Advance(clock);
                    var cells=state.Data.ToArray();
                    ushort[] signature=[instruction.Site,instruction.Token,cells[0],cells[1],unchecked((ushort)(first["u"]-2*(cells.Length-4))),
                        state.Control!.Pointer,state.LocalFrame,state.Control.LoopFrame,state.ReadWord(state.LocalFrame),state.ReadWord(0x2D),state.Memory[0x33],
                        state.ReadWord(0x324),state.Memory[0x4F],state.Memory[0x4E],state.ReadWord(0x90),scheduler.Clock];
                    if(anchor<call.Anchors.Length && call.Anchors[anchor][0]==ordinal) {
                        var expected=call.Anchors[anchor++];
                        for(int n=0;n<signature.Length;n++)if(signature[n]!=expected[n+1])
                            throw new InvalidDataException($"Selection stage {stage} ordinal {ordinal} {capture.SignatureFields[n]}: {signature[n]:X4} != {expected[n+1]:X4}");
                    }
                    Span<byte> bytes=stackalloc byte[32];for(int n=0;n<signature.Length;n++)BinaryPrimitives.WriteUInt16BigEndian(bytes.Slice(n*2,2),signature[n]);hash.AppendData(bytes);
                    observe?.Invoke(stage,ordinal,signature);
                    ordinal++;
                }
            };
            executor.Run(Resolve(0xC699),call.Instructions+1);
            string actualHash=Convert.ToHexString(hash.GetHashAndReset());
            if(ordinal!=call.Instructions || input!=call.Inputs.Length || anchor!=call.Anchors.Length || readPhase!=call.BeforeReads.Length ||
                actualHash!=call.ExpectedSha256 || m.Control.ResumeCursor!=0xC757)
                throw new InvalidDataException($"Selection stage {stage}: dispatches {ordinal}/{call.Instructions}, inputs {input}/{call.Inputs.Length}, anchors {anchor}/{call.Anchors.Length}, return {m.Control.ResumeCursor:X4}, digest {actualHash}/{call.ExpectedSha256}");
            choices.Add(m.Data.Peek());instructions+=ordinal;
        }
        return new(instructions,requests,choices);
    }
}

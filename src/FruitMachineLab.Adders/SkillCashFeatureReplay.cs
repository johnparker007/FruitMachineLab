using System.Buffers.Binary;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record FeatureCapture(Dictionary<string,ushort> Initial,int Instructions,
    [property:JsonPropertyName("allocated_frame")] ushort AllocatedFrame,
    [property:JsonPropertyName("expected_sha256")] string ExpectedSha256,
    [property:JsonPropertyName("signature_fields")] string[] SignatureFields,
    int[][] Inputs,[property:JsonPropertyName("before_reads")] int[][] BeforeReads,int[][] Conditions,int[][] Anchors,NvramCall[] Native);
public record AlphaRequest(ushort Site,string Program);
public record AlphaFrame(int Ordinal,ushort Site,ushort Clock,ushort Tick,ushort Pending,ushort CurrentWin,AlphaState State);
public record FeatureReplayResult(int Instructions,int LampRequests,int AlphaRequests,int Queues,int Refreshes,
    ushort Pending,ushort CurrentWin,ushort Display,ushort ReturnCursor,IReadOnlyList<ushort> Choices,
    byte Level,IReadOnlyList<DiagnosticEvent> Events,IReadOnlyList<AlphaFrame> AlphaFrames);

// Continuous C721 execution with captured platform timing and recovered alpha software effects.
public static class SkillCashFeatureReplay
{
    public static FeatureReplayResult Run(string evidenceDirectory,Action<AlphaRequest>? alphaOutput=null,
        Action<LampRequest>? lampOutput=null,Action<int,IReadOnlyList<ushort>>? observe=null,
        Action<int,Instruction,Machine>? platformStep=null)
    {
        var options=new JsonSerializerOptions{PropertyNameCaseInsensitive=true};
        var capture=JsonSerializer.Deserialize<FeatureCapture>(File.ReadAllText(Path.Combine(evidenceDirectory,"skill-cash","feature-replay.json")),options)!;
        var sound=JsonSerializer.Deserialize<NativeSoundObservation[]>(File.ReadAllText(Path.Combine(evidenceDirectory,"skill-cash","feature-sound.json")),options)!;
        var enqueues=sound.Where(x=>x.Kind=="QE").ToArray();var resets=sound.Where(x=>x.Kind=="WC" && x.Fields["pc"]==0x5B80).ToArray();
        var first=capture.Initial;var m=new Machine();SkillCashData.LoadFeature(m);SkillCashData.LoadAlpha(m);
        var alphaCapture=SkillCashAlphaVerification.Load(evidenceDirectory);SkillCashAlphaVerification.Seed(m,alphaCapture.Calls[0].Before);
        var initialNative=capture.Native[0].Before;
        for(ushort address=0x2F0;address<0x322;address++)m.Memory[address]=(byte)initialNative[(address<0x309 ? "source" : "copy")+address.ToString("X4")];
        m.LocalFrame=first["f4"];m.WriteWord(m.LocalFrame,first["frame"]);
        m.Control=new VmControlStack(m,first["s"]){LoopFrame=first["f6"]};
        m.WriteWord(first["s"],0xBEEF); // caller cursor absent from captured pre-dispatch fields
        m.WriteWord(Cell.Subtract(first["s"],4),capture.AllocatedFrame);
        m.WriteWord(0x2D,first["tick"]);m.Memory[0x33]=(byte)first["irq"];m.WriteWord(0x324,first["seed"]);
        m.Memory[0x4F]=(byte)first["choice"];m.Memory[0x4E]=(byte)first["rate"];
        m.WriteWord(0x90,first["latch"]);m.WriteWord(0x719B,first["abort"]);m.WriteWord(0x719F,first["opt"]);
        m.WriteWord(0xBA,first["pending"]);m.WriteWord(0x2FA,first["win"]);
        m.Memory[0x2C]=(byte)first["guard"];m.Memory[0x322]=(byte)first["checksum"];m.Memory[0x323]=(byte)first["mode"];
        m.WriteWord(0x327,first["display"]);m.WriteWord(0xA0,first["suppress"]);
        foreach(var name in new[]{"fourth","third","second","top"})m.Data.Push(first[name]);
        var comp=SkillCashCompensationVerification.Load(evidenceDirectory)[0];
        foreach(ushort site in new ushort[]{0xA0F1,0xA102}) {
            int at=Array.FindIndex(comp.Steps,x=>x["y"]==site);ushort address=comp.Steps[at]["top"];
            m.Memory[address]=(byte)comp.Steps[at+1]["top"];m.WriteWord(Cell.Add(address,1),comp.Steps[at+1]["second"]);
        }
        var scripts=new Dictionary<ushort,RecoveredScript>();
        RecoveredScript Resolve(ushort address) {
            if(!scripts.TryGetValue(address,out var script)){script=new(Path.Combine(evidenceDirectory,"VM-SCRIPTS",address.ToString("X4")+".txt"));scripts.Add(address,script);}return script;
        }
        int ordinal=0,input=0,anchor=0,phase=0,condition=0,queue=0,reset=0,refresh=0,lamps=0,alphas=0;
        var events=new List<DiagnosticEvent>();byte level=0;
        var alphaFrames=new List<AlphaFrame>();var alphaSerial=new List<byte>();var alpha=new Mpu4Alpha(m,alphaSerial.Add);
        var choices=new List<ushort>();var scheduler=new Mpu4ChoiceStreamScheduler(m,first["clock"]);ushort clock=first["clock"];
        void Advance(ushort target) {
            ushort delta=unchecked((ushort)(target-scheduler.Clock));if(delta>32767)throw new InvalidDataException("Feature clock moved backwards");
            scheduler.AdvanceTicks(delta);if(delta!=0)m.Memory[0x2C]=0; // native 5CD6
        }
        var lampRequests=new Mpu4LampRequests(m,request=>{lamps++;lampOutput?.Invoke(request);});
        NvramCall? pendingNative=null;
        void CompareNvram(Dictionary<string,ushort> expected) {
            for(ushort address=0x2F0;address<0x322;address++) {
                var key=(address<0x309 ? "source" : "copy")+address.ToString("X4");
                if(m.Memory[address]!=expected[key])throw new InvalidDataException($"Continuous NVRAM byte {address:X4} differs");
            }
            if(m.Memory[0x322]!=expected["checksum"] || m.Memory[0x2C]!=expected["guard"] || m.Memory[0x323]!=expected["mode"])
                throw new InvalidDataException("Continuous NVRAM checksum/guard/mode differs");
        }
        using var hash=IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        var executor=new ScriptExecutor(m) {
            ResolveScript=Resolve,ResolveWord=SkillCashData.ResolveWord,
            InputConditionCell=value=> {
                if(condition>=capture.Conditions.Length)throw new InvalidDataException("Uncaptured input condition");
                var point=capture.Conditions[condition++];if(point[0]!=ordinal-1 || point[1]!=value || point.Length!=9)throw new InvalidDataException("Condition boundary mismatch");
                int[] ports=[0,1,2,3,6,7];for(int n=0;n<ports.Length;n++)m.Memory[ports[n]]=(byte)point[n+3];
                ushort result=Mpu4InputConditions.Evaluate(m,(byte)value);
                if(result!=point[2])throw new InvalidDataException("Calculated input condition differs from MAME");return result;
            },
            OperationBoundary=(instruction,state)=> {
                if(instruction.Native==0x6E06) {
                    if(refresh>capture.Native.Length)throw new InvalidDataException("Extra native refresh");
                    pendingNative=capture.Native[refresh-1];CompareNvram(pendingNative.Before);
                }
                if(phase<capture.BeforeReads.Length && capture.BeforeReads[phase][0]==ordinal-1) {
                    if(instruction.Token!=0x790D || state.Data.Peek()!=0x2D)throw new InvalidDataException("Invalid timer phase");
                    ushort ticks=(ushort)capture.BeforeReads[phase++][1];state.WriteWord(0x2D,Cell.Add(state.ReadWord(0x2D),ticks));state.Memory[0x33]=unchecked((byte)(state.Memory[0x33]+ticks));
                }
            },
            WordHandler=(instruction,state)=> {
                if(lampRequests.HandleWord(instruction))return true;
                if(instruction.Native==0x5C18) {
                    var stream=state.Pop();var enqueue=enqueues[queue++].Fields;
                    if(stream!=enqueue["stream"] || state.Memory[0x4E]!=enqueue["rate"])throw new InvalidDataException("Enqueue stream/rate mismatch");
                    Advance(enqueue["clock"]);return scheduler.Queue(stream);
                }
                if(instruction.Native==0x5B77) {Advance(resets[reset++].Fields["clock"]);return scheduler.Reset();}
                if(instruction.Native==0x5CCB) {
                    Advance((ushort)capture.Inputs.Single(x=>x[0]==ordinal)[5]);
                    if(scheduler.Active)throw new InvalidDataException("Scheduler wait returned with active tasks");return true;
                }
                if(instruction.Native==0x3D0E || instruction.Operation=="vm_execute_alpha_stream") {
                    string program=instruction.Native==0x3D0E ? "reset-and-clear" : instruction.InlineStream ?? throw new InvalidDataException("Missing alpha request");
                    if(alphas>=alphaCapture.Calls.Length)throw new InvalidDataException("Extra alpha request");
                    var call=alphaCapture.Calls[alphas++];SkillCashAlphaVerification.Compare(alpha.Snapshot(),call.Before);
                    if(state.ReadWord(0xBA)!=call.Before.Pending || state.ReadWord(0x2FA)!=call.Before.Win || state.ReadWord(0x327)!=call.Before.Display || state.ReadWord(0x2F0)!=call.Before.Credit)
                        throw new InvalidDataException("Continuous alpha input memory differs");
                    alphaSerial.Clear();
                    if(instruction.Native==0x3D0E){if(call.Kind!="AR")throw new InvalidDataException("Alpha reset kind mismatch");alpha.Reset();}
                    else {
                        ushort stream=Cell.Add(instruction.Site,2);
                        if(call.Kind!="AE" || stream!=call.Before.Stream)throw new InvalidDataException("Alpha stream mismatch");alpha.Execute(stream);
                    }
                    var snapshot=alpha.Snapshot();SkillCashAlphaVerification.Compare(snapshot,call.After);
                    if(call.Kind=="AE" && snapshot.Stream!=call.After.Next || !alphaSerial.SequenceEqual(call.Serial.Select(p=>checked((byte)p[0]))))
                        throw new InvalidDataException("Continuous alpha continuation/serial bytes differ");
                    alphaFrames.Add(new(ordinal-1,instruction.Site,call.After.Clock,call.After.Tick,state.ReadWord(0xBA),state.ReadWord(0x2FA),snapshot));
                    alphaOutput?.Invoke(new(instruction.Site,program));return true;
                }
                return false;
            },
            BeforeInstruction=(instruction,state)=> {
                if(ordinal>=capture.Instructions)throw new InvalidDataException("Extra feature dispatch");
                if(pendingNative is { } native){CompareNvram(native.After);pendingNative=null;}
                if(input<capture.Inputs.Length && capture.Inputs[input][0]==ordinal) {
                    var point=capture.Inputs[input++];state.Memory[0x33]=unchecked((byte)(state.Memory[0x33]+point[1]));
                    state.WriteWord(0x2D,Cell.Add(state.ReadWord(0x2D),(ushort)point[2]));state.WriteWord(0x90,(ushort)((state.ReadWord(0x90)|point[3])&~point[4]));clock=(ushort)point[5];
                }
                Advance(clock);if(instruction.Site==0xC757)choices.Add(state.Data.Peek());if(instruction.Native==0x6E06)refresh++;
                platformStep?.Invoke(ordinal,instruction,state);
                if(instruction.Site==0xC761) {
                    level=state.Memory[Cell.Add(state.LocalFrame,1)];
                    events.Add(new(instruction.Site,"Selected level",level,$"Stage {choices.Count}; scheduler clock {scheduler.Clock:X4}; calculated from the continuous recovered selection loop"));
                }
                if(instruction.Site==0xC710)events.Add(new(instruction.Site,"Pending award committed",state.ReadWord(0xBA),"Recovered table lookup, normalization and store"));
                if(instruction.Site==0xAFC2)events.Add(new(instruction.Site,"Current win transfer",state.ReadWord(0x2FA),$"Pending {state.ReadWord(0xBA)}; NVRAM refreshed; scheduler clock {scheduler.Clock:X4}"));
                var cells=state.Data.ToArray();
                ushort[] signature=[instruction.Site,instruction.Token,cells[0],cells[1],cells[2],cells[3],unchecked((ushort)(first["u"]-2*(cells.Length-4))),
                    state.Control!.Pointer,state.LocalFrame,state.Control.LoopFrame,state.ReadWord(state.LocalFrame),state.ReadWord(0x2D),state.Memory[0x33],state.ReadWord(0x324),
                    state.Memory[0x4F],state.Memory[0x4E],state.ReadWord(0x90),state.ReadWord(0xBA),state.ReadWord(0x2FA),state.Memory[0x2C],state.Memory[0x322],state.Memory[0x323],state.ReadWord(0x327),state.ReadWord(0xA0),scheduler.Clock];
                if(anchor<capture.Anchors.Length && capture.Anchors[anchor][0]==ordinal) {
                    var expected=capture.Anchors[anchor++];for(int n=0;n<signature.Length;n++)if(signature[n]!=expected[n+1])throw new InvalidDataException($"Feature ordinal {ordinal}, {instruction.Site:X4}, {capture.SignatureFields[n]}: {signature[n]:X4} != {expected[n+1]:X4}");
                }
                Span<byte> bytes=stackalloc byte[50];for(int n=0;n<signature.Length;n++)BinaryPrimitives.WriteUInt16BigEndian(bytes.Slice(n*2,2),signature[n]);hash.AppendData(bytes);
                observe?.Invoke(ordinal,signature);ordinal++;
            }
        };
        executor.Run(Resolve(0xC721),capture.Instructions+1);string digest=Convert.ToHexString(hash.GetHashAndReset());
        if(ordinal!=capture.Instructions || input!=capture.Inputs.Length || phase!=capture.BeforeReads.Length || condition!=capture.Conditions.Length || anchor!=capture.Anchors.Length || queue!=enqueues.Length || reset!=resets.Length || alphas!=alphaCapture.Calls.Length || digest!=capture.ExpectedSha256)
            throw new InvalidDataException($"Feature incomplete or digest differs: {ordinal}/{capture.Instructions}, {digest}/{capture.ExpectedSha256}");
        if(m.LocalFrame!=first["f4"] || m.Control.Pointer!=Cell.Add(first["s"],2) || m.Control.LoopFrame!=first["f6"] || m.Control.ResumeCursor!=0xBEEF)throw new InvalidDataException("Feature caller frame not restored");
        events.Add(new(0xC767,"Final pending award",m.ReadWord(0xBA),"Terminal clear in AF93; caller frame restored"));
        events.Add(new(0xC767,"Final current win",m.ReadWord(0x2FA),"Award transfer and even rounding; ROM units"));
        events.Add(new(0xC767,"Continuous VM dispatches",ordinal,"Canonical state digest matches the recorded MAME path"));
        events.Add(new(0x49C5,"Decoded lamp requests",lamps,"Logical IDs/patterns feed a separately verified frame-memory adapter; electrical output timing remains outside this replay"));
        events.Add(new(0x773C,"Alpha calls verified",alphas,"Software shadow, numeric formatting, cursor and serial byte sequences match MAME; PIA edges remain outside this model"));
        return new(ordinal,lamps,alphas,queue,refresh,m.ReadWord(0xBA),m.ReadWord(0x2FA),m.ReadWord(0x327),m.Control.ResumeCursor,choices,level,events,alphaFrames);
    }
}

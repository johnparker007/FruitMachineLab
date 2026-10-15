using System.Buffers.Binary;
using System.Security.Cryptography;
using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record BoardSelectionVerificationResult(int Instructions,int Lamps,int Sounds,int AlphaBytes,int Conditions);
public static class BoardSelectionVerification
{
    public static BoardSelectionVerificationResult Verify(string evidence,bool diceRequests=false)
    {
        using var capture=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash",diceRequests ? "dice-requests.json" : "board-selection.json")));var root=capture.RootElement;
        // C63C writes the low byte; C640 clears the high byte. Only bytes
        // preceding those first writes may be excluded as undefined residue.
        string[] undefinedWords=["C726","C728","C72A","C72C","C72E","C730","C732","C637","C63A","C63C"];
        var frameMasks=undefinedWords.ToDictionary(site=>site,_=>0);frameMasks.Add("C63E",255);frameMasks.Add("C640",255);
        if(diceRequests)frameMasks.Clear();
        var declared=root.GetProperty("undefined_frame_masks").EnumerateObject().ToArray();
        if(declared.Length!=frameMasks.Count || declared.Any(item=>!frameMasks.TryGetValue(item.Name,out int mask) || item.Value.GetInt32()!=mask))throw new InvalidDataException("Invalid uninitialized-frame comparison exclusions");
        var m=new SkillCashLiveSession(evidence).Machine;ushort clock=BoardSelectionState.Apply(m,evidence,diceRequests);
        using var vmHash=IncrementalHash.CreateHash(HashAlgorithmName.SHA256);using var lampHash=IncrementalHash.CreateHash(HashAlgorithmName.SHA256);using var soundHash=IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        static void Hash(IncrementalHash hash,ReadOnlySpan<ushort> values){Span<byte> bytes=stackalloc byte[values.Length*2];for(int n=0;n<values.Length;n++)BinaryPrimitives.WriteUInt16BigEndian(bytes.Slice(n*2,2),values[n]);hash.AppendData(bytes);}
        var serial=new List<byte>();var alpha=new Mpu4Alpha(m,serial.Add);int lamps=0,sounds=0;
        var scheduler=new Mpu4ChoiceStreamScheduler(m,clock,item=>{if(item.Kind!="command")return;sounds++;Hash(soundHash,new ushort[]{item.Cursor,item.Value,item.Clock,item.Choice,item.Rate,item.Tempo,item.Gate,item.Flags,item.Pitch,item.Transpose});});
        scheduler.RestoreQueuedNativeTasks();
        var response=JsonSerializer.Deserialize<LampFrameCapture>(File.ReadAllText(Path.Combine(evidence,"skill-cash","lamp-frames.json")),new JsonSerializerOptions{PropertyNameCaseInsensitive=true})!;
        var frames=new Mpu4LampFrames(m,response.Responses.Select(x=>(byte)x).ToArray());
        var requests=new Mpu4LampRequests(m,request=>{byte column=frames.Apply(request.Id,request.Pattern);lampHash.AppendData(new byte[]{request.Id,(byte)(request.Pattern&15),column});lampHash.AppendData(frames.Snapshot());lamps++;});
        int[][] Rows(string name)=>root.GetProperty(name).EnumerateArray().Select(row=>row.EnumerateArray().Select(x=>x.GetInt32()).ToArray()).ToArray();
        var inputs=Rows("inputs");var conditions=Rows("conditions");var reads=Rows("before_reads");var anchors=Rows("anchors").ToDictionary(row=>row[0]);int point=0,condition=0,phase=0,ordinal=0;
        var native=Rows("native");int nativePoint=0;
        var catalog=new RecoveredScriptCatalog(Path.Combine(evidence,"VM-SCRIPTS"));
        RecoveredScript Resolve(ushort at)=>catalog.Owner(at);
        void Advance(ushort target){ushort delta=Cell.Subtract(target,scheduler.Clock);if(delta>32767)throw new InvalidDataException("Board sound clock reversed");if(delta!=0){m.Memory[0x2C]=0;m.WriteWord(0x35,(ushort)Math.Max(0,m.ReadWord(0x35)-delta));}scheduler.AdvanceTicks(delta);}
        var executor=new ScriptExecutor(m){ResolveScript=Resolve,ResolveWord=SkillCashData.ResolveWord,
            InputConditionCell=value=>{
                if(condition>=conditions.Length)throw new InvalidDataException("Extra board input condition");var row=conditions[condition++];
                if(row[0]!=ordinal || row[1]!=value)throw new InvalidDataException($"Board input condition ordinal {ordinal}, expected {row[0]}");
                int[] ports=[0,1,2,3,6,7];for(int n=0;n<ports.Length;n++)m.Memory[ports[n]]=(byte)row[n+2];
                return Mpu4InputConditions.Evaluate(m,(byte)value);
            },
            OperationBoundary=(i,state)=>{if(phase<reads.Length && reads[phase][0]==ordinal){if(i.Token!=0x790D || state.Data.Peek()!=0x2D)throw new InvalidDataException("Invalid board timer read phase");ushort ticks=(ushort)reads[phase++][1];state.WriteWord(0x2D,Cell.Add(state.ReadWord(0x2D),ticks));state.Memory[0x33]=unchecked((byte)(state.Memory[0x33]+ticks));}},
            WordHandler=(i,state)=>{
                if(i.Native is 0x5C18 or 0x5B77){if(nativePoint>=native.Length)throw new InvalidDataException("Extra native scheduler call");var row=native[nativePoint++];if(row[0]!=ordinal || row[1]!=(i.Native==0x5C18 ? 1 : 2) || (i.Native==0x5C18 && row[3]!=state.Data.Peek()))throw new InvalidDataException("Native board scheduler phase differs");Advance((ushort)row[2]);}
                if(i.Native==0x5CCB){if(point>=inputs.Length || inputs[point][0]!=ordinal+1)throw new InvalidDataException("Missing board scheduler wait boundary");Advance((ushort)inputs[point][4]);}
                return AddersNativeWords.Handle(i,state,requests,scheduler,alpha);
            }
        };
        ushort entry=diceRequests ? Convert.ToUInt16(root.GetProperty("initial").GetProperty("y").GetString(),16) : (ushort)0xDD38;
        executor.BeginResumed(Resolve(entry),entry,catalog.Owner,0xBEEF,root.GetProperty("instructions").GetInt32()+1);
        while(!executor.Completed) {
            if(point<inputs.Length && inputs[point][0]==ordinal){var row=inputs[point++];m.WriteWord(0x2D,(ushort)row[1]);m.Memory[0x33]=(byte)row[2];m.WriteWord(0x90,(ushort)row[3]);Advance((ushort)row[4]);}
            var i=executor.NextInstruction!;var cells=m.Data.ToArray();
            ushort[] signature=[i.Site,i.Token,cells[0],cells[1],cells[2],cells[3],m.DataPointer,m.Control!.Pointer,m.LocalFrame,m.Control.LoopFrame,m.ReadWord(m.LocalFrame),m.ReadWord(0x2D),m.Memory[0x33],m.ReadWord(0x324),m.Memory[0x4F],m.Memory[0x4E],m.ReadWord(0x90),m.ReadWord(0xBA),m.ReadWord(0x2FA),m.Memory[0x2C],m.Memory[0x322],m.Memory[0x323],m.ReadWord(0x327),m.ReadWord(0xA0),scheduler.Clock];
            if(frameMasks.TryGetValue(i.Site.ToString("X4"),out int mask))signature[10]&=(ushort)mask;
            if(anchors.TryGetValue(ordinal,out var expected))for(int n=0;n<signature.Length;n++)if(signature[n]!=expected[n+1])throw new InvalidDataException($"Board ordinal {ordinal}, {i.Site:X4}, field {n}: {signature[n]:X4} != {expected[n+1]:X4}");
            Hash(vmHash,signature);if(diceRequests && i.Site==0xB283){ordinal++;break;}executor.Step();ordinal++;
        }
        void Match(string key,string actual){if(root.GetProperty(key).GetString()!=actual)throw new InvalidDataException($"Board {key} differs: {actual}");}
        Match("expected_vm_sha256",Convert.ToHexString(vmHash.GetHashAndReset()));Match("expected_lamp_sha256",Convert.ToHexString(lampHash.GetHashAndReset()));Match("expected_sound_sha256",Convert.ToHexString(soundHash.GetHashAndReset()));Match("serial_hex",Convert.ToHexString(serial.ToArray()));
        if(ordinal!=root.GetProperty("instructions").GetInt32() || lamps!=root.GetProperty("lamp_requests").GetInt32() || sounds!=root.GetProperty("sound_commands").GetInt32() || condition!=conditions.Length || point!=inputs.Length || phase!=reads.Length || nativePoint!=native.Length)throw new InvalidDataException("Incomplete board selection replay");
        return new(ordinal,lamps,sounds,serial.Count,condition);
    }
}

using System.Buffers.Binary;
using System.Security.Cryptography;
using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record JackpotProbeVerification(int Instructions,int LampRequests,int SoundCommands,int SerialBytes);
public static class SkillCashJackpotProbeVerification
{
    public static JackpotProbeVerification Verify(string evidence)
    {
        using var capture=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","jackpot-probe.json")));var root=capture.RootElement;
        var initial=root.GetProperty("initial");ushort First(string key)=>Convert.ToUInt16(initial.GetProperty(key).GetString(),16);
        var m=new Machine();SkillCashData.LoadFeature(m);SkillCashData.LoadAlpha(m);SkillCashData.LoadExtensions(m,evidence);
        foreach(var name in new[]{"fourth","third","second","top"})m.Data.Push(First(name));m.DataStackBase=Cell.Add(First("u"),8);
        int offset=0;foreach(var cell in root.GetProperty("residual_stack_cells").EnumerateArray()){m.WriteWord(Cell.Add(Cell.Subtract(First("u"),64),(ushort)offset),cell.GetUInt16());offset+=2;}
        m.LocalFrame=First("f4");m.WriteWord(m.LocalFrame,First("frame"));m.Control=new(m,First("s")){LoopFrame=First("f6")};
        foreach(var pair in new[]{("tick",0x2D),("seed",0x324),("latch",0x90),("pending",0xBA),("win",0x2FA),("display",0x327),("suppress",0xA0)})m.WriteWord((ushort)pair.Item2,First(pair.Item1));
        foreach(var pair in new[]{("irq",0x33),("choice",0x4F),("rate",0x4E),("guard",0x2C),("checksum",0x322),("mode",0x323)})m.Memory[pair.Item2]=(byte)First(pair.Item1);
        var a=root.GetProperty("initial_alpha");
        foreach(var pair in new[]{("cursor",0x54),("control",0x55),("stop",0x57),("mirror",0xC5),("digit",0xC4)})m.Memory[pair.Item2]=Convert.ToByte(a.GetProperty(pair.Item1).GetString(),16);
        Convert.FromHexString(a.GetProperty("shadow").GetString()!).CopyTo(m.Memory,0x58);Convert.FromHexString(a.GetProperty("digits").GetString()!).CopyTo(m.Memory,0x1A);
        Convert.FromHexString(root.GetProperty("initial_frames").GetString()!).CopyTo(m.Memory,0x100);
        using var vmHash=IncrementalHash.CreateHash(HashAlgorithmName.SHA256);using var lampHash=IncrementalHash.CreateHash(HashAlgorithmName.SHA256);using var soundHash=IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        static void Hash(IncrementalHash hash,ReadOnlySpan<ushort> values){Span<byte> bytes=stackalloc byte[values.Length*2];for(int n=0;n<values.Length;n++)BinaryPrimitives.WriteUInt16BigEndian(bytes.Slice(2*n,2),values[n]);hash.AppendData(bytes);}
        int sounds=0,lamps=0;var serial=new List<byte>();var alpha=new Mpu4Alpha(m,serial.Add);
        var scheduler=new Mpu4ChoiceStreamScheduler(m,First("clock"),item=>{if(item.Kind!="command")return;sounds++;Hash(soundHash,new ushort[]{item.Cursor,item.Value,item.Clock,item.Choice,item.Rate,item.Tempo,item.Gate,item.Flags,item.Pitch,item.Transpose});});
        var frameCapture=JsonSerializer.Deserialize<LampFrameCapture>(File.ReadAllText(Path.Combine(evidence,"skill-cash","lamp-frames.json")),new JsonSerializerOptions{PropertyNameCaseInsensitive=true})!;
        var frames=new Mpu4LampFrames(m,frameCapture.Responses.Select(x=>(byte)x).ToArray());
        var requests=new Mpu4LampRequests(m,request=>{byte column=frames.Apply(request.Id,request.Pattern);lampHash.AppendData(new byte[]{request.Id,(byte)(request.Pattern&15),column});lampHash.AppendData(frames.Snapshot());lamps++;});
        var scripts=new Dictionary<ushort,RecoveredScript>();RecoveredScript Resolve(ushort address){if(!scripts.TryGetValue(address,out var script)){script=new(Path.Combine(evidence,"VM-SCRIPTS",address.ToString("X4")+".txt"));scripts.Add(address,script);}return script;}
        var inputs=root.GetProperty("inputs").EnumerateArray().Select(row=>row.EnumerateArray().Select(x=>x.GetInt32()).ToArray()).ToArray();int point=0;
        var anchors=root.GetProperty("anchors").EnumerateArray().Select(row=>row.EnumerateArray().Select(x=>x.GetInt32()).ToArray()).ToDictionary(row=>row[0]);
        var executor=new ScriptExecutor(m){ResolveScript=Resolve,ResolveWord=SkillCashData.ResolveWord,WordHandler=(instruction,state)=>AddersNativeWords.Handle(instruction,state,requests,scheduler,alpha)};
        executor.Begin(Resolve(0xA365),root.GetProperty("instructions").GetInt32()+1);int count=0;
        while(!executor.Completed) {
            if(point<inputs.Length && inputs[point][0]==count) {
                var row=inputs[point++];ushort delta=Cell.Subtract((ushort)row[1],m.ReadWord(0x2D));m.WriteWord(0x2D,(ushort)row[1]);m.Memory[0x33]=(byte)row[2];m.WriteWord(0x90,(ushort)row[4]);
                m.WriteWord(0x35,(ushort)Math.Max(0,m.ReadWord(0x35)-delta));scheduler.AdvanceTicks(Cell.Subtract((ushort)row[3],scheduler.Clock));
            }
            var instruction=executor.NextInstruction!;var cells=m.Data.ToArray();
            ushort[] signature=[instruction.Site,instruction.Token,cells[0],cells[1],cells[2],cells[3],m.DataPointer,m.Control.Pointer,m.LocalFrame,m.Control.LoopFrame,m.ReadWord(m.LocalFrame),m.ReadWord(0x2D),m.Memory[0x33],m.ReadWord(0x324),m.Memory[0x4F],m.Memory[0x4E],m.ReadWord(0x90),m.ReadWord(0xBA),m.ReadWord(0x2FA),m.Memory[0x2C],m.Memory[0x322],m.Memory[0x323],m.ReadWord(0x327),m.ReadWord(0xA0),scheduler.Clock];
            if(anchors.TryGetValue(count,out var expected))for(int n=0;n<signature.Length;n++)if(signature[n]!=expected[n+1])throw new InvalidDataException($"Jackpot probe ordinal {count}, {instruction.Site:X4}, field {n}: {signature[n]:X4} != {expected[n+1]:X4}");
            Hash(vmHash,signature);
            count++;if(instruction.Site==0xA398)break;executor.Step();
        }
        void Match(string name,string actual){if(actual!=root.GetProperty(name).GetString())throw new InvalidDataException($"Jackpot helper probe {name} differs: {actual}");}
        Match("expected_vm_sha256",Convert.ToHexString(vmHash.GetHashAndReset()));Match("expected_lamp_sha256",Convert.ToHexString(lampHash.GetHashAndReset()));Match("expected_sound_sha256",Convert.ToHexString(soundHash.GetHashAndReset()));Match("serial_hex",Convert.ToHexString(serial.ToArray()));
        if(count!=root.GetProperty("instructions").GetInt32() || lamps!=485 || sounds!=root.GetProperty("sound_commands").GetInt32() || point!=inputs.Length)throw new InvalidDataException("Incomplete jackpot helper probe replay");
        return new(count,lamps,sounds,serial.Count);
    }
}

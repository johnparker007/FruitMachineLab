using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record LampFrameAnchor(int Ordinal,byte Id,byte Pattern,byte Column,string Frames);
public record LampFrameCapture(string Initial,int[] Responses,int Requests,
    [property:JsonPropertyName("expected_sha256")] string ExpectedSha256,LampFrameAnchor[] Anchors);
public static class SkillCashLampFrameVerification
{
    public static int Verify(string evidenceDirectory,Action<int,IReadOnlyList<byte>>? output=null)
    {
        var capture=JsonSerializer.Deserialize<LampFrameCapture>(File.ReadAllText(Path.Combine(evidenceDirectory,"skill-cash","lamp-frames.json")),
            new JsonSerializerOptions{PropertyNameCaseInsensitive=true})!;
        var m=new Machine();var initial=Convert.FromHexString(capture.Initial);
        if(initial.Length!=64)throw new InvalidDataException("Missing initial lamp frames");initial.CopyTo(m.Memory,0x100);
        var frames=new Mpu4LampFrames(m,capture.Responses.Select(value=>checked((byte)value)).ToArray());int count=0,anchor=0;
        using var hash=IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        SkillCashFeatureReplay.Run(evidenceDirectory,lampOutput:request=> {
            byte column=frames.Apply(request.Id,request.Pattern);var snapshot=frames.Snapshot();
            if(anchor<capture.Anchors.Length && capture.Anchors[anchor].Ordinal==count) {
                var expected=capture.Anchors[anchor++];
                if(expected.Id!=request.Id || expected.Pattern!=(request.Pattern&15) || expected.Column!=column || expected.Frames!=Convert.ToHexString(snapshot))
                    throw new InvalidDataException($"Lamp frame mismatch at request {count}, id {request.Id:X2}");
            }
            Span<byte> bytes=stackalloc byte[67];bytes[0]=request.Id;bytes[1]=(byte)(request.Pattern&15);bytes[2]=column;snapshot.CopyTo(bytes[3..]);hash.AppendData(bytes);
            output?.Invoke(count,snapshot);count++;
        });
        if(count!=capture.Requests || anchor!=capture.Anchors.Length || Convert.ToHexString(hash.GetHashAndReset())!=capture.ExpectedSha256)
            throw new InvalidDataException("Lamp frame request count or canonical digest differs");
        return count;
    }
}

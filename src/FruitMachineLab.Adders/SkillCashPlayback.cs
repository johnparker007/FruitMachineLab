using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record PlaybackLamp(int Number,byte LogicalId,string Caption);
public record SkillCashPlaybackResult(OutputPlayback Output,IReadOnlyList<PlaybackLamp> Lamps,SharedTimingVerification Verification);
public static class SkillCashPlayback
{
    public static SkillCashPlaybackResult Load(string evidenceDirectory)
    {
        SkillCashSoundVerification.VerifyFeature(evidenceDirectory);
        SkillCashLampFrameVerification.Verify(evidenceDirectory);
        SkillCashOutputScanVerification.Verify(evidenceDirectory);
        SkillCashTimerDeadlineVerification.Verify(evidenceDirectory);
        var verified=SkillCashSharedTimingVerification.Verify(evidenceDirectory);
        var capture=JsonSerializer.Deserialize<SharedTimingCapture>(File.ReadAllText(Path.Combine(evidenceDirectory,"skill-cash","shared-timing.json")),new JsonSerializerOptions{PropertyNameCaseInsensitive=true})!;
        var dispatch=new ulong[capture.VmCycleDeltas.Length];ulong cycle=0;
        for(int n=0;n<dispatch.Length;n++){cycle=checked(cycle+capture.VmCycleDeltas[n]);dispatch[n]=cycle;}
        var initial=capture.InitialScan;var ports=Convert.FromHexString(initial["ports"]);
        var lamps=new List<LampLatchFrame>{new(0,checked((byte)Convert.ToUInt16(initial["column"],16)),ports[0],ports[1])};
        foreach(var frame in verified.Outputs) {
            var bytes=Convert.FromHexString(frame.Ports);lamps.Add(new(frame.CycleOffset,checked((byte)frame.Column),bytes[0],bytes[1]));
        }
        var first=SkillCashAlphaVerification.Load(evidenceDirectory).Calls[0].Before;
        var m=new Machine();SkillCashAlphaVerification.Seed(m,first);
        var alpha=new List<AlphaPlaybackFrame>{new(0,new Mpu4Alpha(m).Snapshot().Text,first.Pending,first.Win)};
        // Native alpha completion lies inside a VM operation. Align completed
        // software shadow to the next dispatch; do not invent serial bit timing.
        foreach(var frame in verified.Feature.AlphaFrames)alpha.Add(new(dispatch[Math.Min(frame.Ordinal+1,dispatch.Length-1)],frame.State.Text,frame.Pending,frame.CurrentWin));
        using var map=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidenceDirectory,"maps","deep-pass-lamp-map.json")));
        var captions=map.RootElement.GetProperty("lamp_rows").EnumerateArray().Select(row=>new PlaybackLamp(row.GetProperty("mame_lamp").GetInt32(),row.GetProperty("rom_command_id").GetByte(),
            string.Join(" / ",row.GetProperty("captions").EnumerateArray().Select(x=>string.IsNullOrWhiteSpace(x.GetString()) ? "?" : x.GetString())))).OrderBy(x=>x.Number).ToArray();
        if(captions.Length!=128 || captions.Where((lamp,index)=>lamp.Number!=index).Any())throw new InvalidDataException("Lamp caption map is not a complete permutation");
        return new(new(cycle,lamps,alpha),captions,verified);
    }
}

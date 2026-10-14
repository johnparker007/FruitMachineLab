using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record NativeSoundObservation(string Kind,Dictionary<string,ushort> Fields);
public record SoundVerification(int Queues,int Commands,int Waits,int Writes,int Reads,IReadOnlyList<byte> ReadChoices);

public static class SkillCashSoundVerification
{
    public static SoundVerification Verify(string evidenceDirectory)
    {
        var records=JsonSerializer.Deserialize<NativeSoundObservation[]>(File.ReadAllText(Path.Combine(evidenceDirectory,"skill-cash","sound-events.json")),
            new JsonSerializerOptions{PropertyNameCaseInsensitive=true}) ?? throw new InvalidDataException("Missing sound events");
        var machine=new Machine();SkillCashData.Load(machine);
        var pending=new Queue<ChoiceStreamEvent>();
        Mpu4ChoiceStreamScheduler? scheduler=null;
        int queues=0,commands=0,waits=0,writes=0;
        var choices=new List<byte>();
        foreach(var observation in records)
        {
            var f=observation.Fields;
            if(scheduler is null)scheduler=new(machine,f["clock"],pending.Enqueue);
            scheduler.AdvanceTicks(unchecked((ushort)(f["clock"]-scheduler.Clock)));
            switch(observation.Kind)
            {
                case "SQ":
                    if(pending.Count!=0 || f["free"]==0)throw new InvalidDataException("Unsupported queued task state");
                    byte rate=(byte)(25-5*queues);
                    if(rate!=f["rate"])throw new InvalidDataException("Queue rate differs from recovered stage timing");
                    machine.Memory[0x4E]=rate;machine.WriteWord(0x719B,f["abort"]);
                    queues++;break;
                case "QE":
                    if(machine.Memory[0x4E]!=f["rate"])throw new InvalidDataException("Rate changed before enqueue boundary");
                    if(pending.Count!=0 || !scheduler.Queue(f["stream"]))throw new InvalidDataException("Unexpected native enqueue boundary");
                    break;
                case "SR":
                    if(pending.Count!=0 || scheduler.Choice!=f["choice"])throw new InvalidDataException("Choice before reset differs");
                    // IRQ work can run between native 5B77 entry and cancellation.
                    // Preserve it; apply reset at the captured 004F clear boundary.
                    break;
                case "read":
                    if(pending.Count!=0 || scheduler.Choice!=f["choice"])throw new InvalidDataException("Calculated 004F differs from VM read");
                    choices.Add(scheduler.Choice);break;
                default:
                    if(observation.Kind=="WC" && f["pc"]==0x5B80) {
                        if(pending.Count!=0 || !scheduler.Reset())throw new InvalidDataException("Unexpected reset boundary");
                    }
                    if(!pending.TryDequeue(out var computed))throw new InvalidDataException("Missing calculated native stream event");
                    bool same=observation.Kind switch {
                        "SN"=>computed.Kind=="command" && computed.Cursor==f["cursor"] && computed.Value==f["opcode"] &&
                            computed.Choice==f["choice"] && computed.Tempo==f["tempo"] && computed.Gate==f["gate"] &&
                            computed.Flags==f["flags"] && computed.Pitch==f["pitch"] && computed.Transpose==f["transpose"],
                        "SW"=>computed.Kind=="wait" && computed.Cursor==f["cursor"] && computed.Value==f["duration"] &&
                            computed.Callback==f["callback"] && computed.Tempo==f["tempo"] && computed.Flags==f["flags"],
                        "WC"=>computed.Kind=="choice" && computed.Value==f["value"] && Cell.Add(computed.Callback,2)==f["pc"] &&
                            (computed.Callback==0x5B7E || computed.Cursor==f["cursor"]),
                        _=>false
                    };
                    if(!same || computed.Clock!=f["clock"])throw new InvalidDataException($"Native {observation.Kind} differs at clock {f["clock"]:X4}, cursor {computed.Cursor:X4}");
                    if(observation.Kind=="SN")commands++;else if(observation.Kind=="SW")waits++;else writes++;
                    break;
            }
        }
        if(pending.Count!=0 || queues!=3 || choices.Count!=1202)throw new InvalidDataException("Incomplete sound verification");
        return new(queues,commands,waits,writes,choices.Count,choices);
    }
}

using System.Text.Json;
using System.Text.Json.Serialization;
using System.Buffers.Binary;
using System.Security.Cryptography;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record SharedTimingCapture([property:JsonPropertyName("initial_cycle")] ulong InitialCycle,
    [property:JsonPropertyName("vm_cycle_deltas")] ulong[] VmCycleDeltas,
    [property:JsonPropertyName("initial_scan")] Dictionary<string,string> InitialScan,
    [property:JsonPropertyName("initial_timer_outstanding")] bool InitialTimerOutstanding,ulong[][] Events,
    [property:JsonPropertyName("expected_vm_sha256")] string ExpectedVmSha256);
public record SharedOutputFrame(int Sequence,ulong CycleOffset,string Kind,byte Phase,ushort Column,string Ports);
public record SharedTimingVerification(int Instructions,int LampWrites,int Scans,int Arms,int Callbacks,IReadOnlyList<SharedOutputFrame> Outputs);

public static class SkillCashSharedTimingVerification
{
    public static SharedTimingVerification Verify(string evidenceDirectory)
    {
        var options=new JsonSerializerOptions{PropertyNameCaseInsensitive=true};
        var capture=JsonSerializer.Deserialize<SharedTimingCapture>(File.ReadAllText(Path.Combine(evidenceDirectory,"skill-cash","shared-timing.json")),options)!;
        var lampCapture=JsonSerializer.Deserialize<LampFrameCapture>(File.ReadAllText(Path.Combine(evidenceDirectory,"skill-cash","lamp-frames.json")),options)!;
        var requests=new Queue<LampRequest>();var arms=new Queue<Timer3Arm>();
        Machine? shared=null;Mpu4LampFrames? frames=null;Mpu4OutputScan? scan=null;
        LampRequest? active=null;int frame=0,writes=0,scans=0,armCount=0,callbacks=0;
        bool timerPending=capture.InitialTimerOutstanding,callbackOpen=false;ulong vmCycle=capture.InitialCycle;
        var timeline=new CapturedCycleTimeline(capture.InitialCycle,capture.Events);
        var outputs=new List<SharedOutputFrame>();
        using var vmHash=IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        void Initialize(Machine m) {
            shared=m;SkillCashData.LoadScan(m);Convert.FromHexString(lampCapture.Initial).CopyTo(m.Memory,0x100);
            var initial=capture.InitialScan;
            foreach(var pair in new[]{("phase",0x23),("count",0x24),("reload",0x25),("alternate",0x26),("alternate_reload",0x27),("suppress",0x8D),("decimal",0x22),("sweep",0xB3)})m.Memory[pair.Item2]=Convert.ToByte(initial[pair.Item1],16);
            m.WriteWord(0x28,Convert.ToUInt16(initial["column"],16));
            foreach(var pair in new[]{("sample",8),("digits",0x1A),("blink",0x2BE),("masks",0x140),("blank",0xAB)})Convert.FromHexString(initial[pair.Item1]).CopyTo(m.Memory,pair.Item2);
            var pulse=Convert.FromHexString(initial["pulse"]);m.Memory[0xE8]=pulse[0];m.Memory[0xE9]=pulse[1];m.Memory[0xEA]=pulse[2];m.WriteWord(0x32D,(ushort)((pulse[3]<<8)|pulse[4]));
            var ports=Convert.FromHexString(initial["ports"]);int[] addresses=[0xA00,0xA02,0xB00,0xE01,0xB01,0xF01];for(int n=0;n<6;n++)m.Memory[addresses[n]]=ports[n];
            frames=new(m,lampCapture.Responses.Select(x=>checked((byte)x)).ToArray());
            scan=new(m,state=>Mpu4LampPulseSweep.Advance(state,arms.Enqueue));
            if(capture.InitialTimerOutstanding)m.WriteWord(0x3D,0x48FD);
        }
        ulong Ports(int count)=>Convert.ToUInt64(Convert.ToHexString(new byte[]{shared!.Memory[0xA00],shared.Memory[0xA02],shared.Memory[0xB00],shared.Memory[0xE01],shared.Memory[0xB01],shared.Memory[0xF01]}[..count]),16);
        void Event(ulong[] row) {
            var m=shared!;
            int length=row[1] switch {0 or 1 or 5 or 6 or 7=>4,2=>2,3=>9,4=>7,_=>throw new InvalidDataException("Unknown shared event")};
            if(row.Length!=length)throw new InvalidDataException("Malformed shared event payload");
            switch(row[1]) {
                case 0:
                    if(active is not null || !requests.TryDequeue(out active) || active.Id!=row[2] || (ulong)(active.Pattern&15)!=(row[3]&15))throw new InvalidDataException("Shared lamp request boundary differs");frame=0;break;
                case 1: {
                    if(active is null || frame>=4)throw new InvalidDataException("Shared lamp write without request");
                    byte column=frames!.ApplyFrame(active.Id,active.Pattern,frame);
                    int address=0x100+16*frame+column;
                    if((ulong)address!=row[2] || m.Memory[address]!=row[3])throw new InvalidDataException($"Shared lamp write {writes} differs at {address:X4}");
                    frame++;writes++;break;
                }
                case 2:if(active is null || frame!=4)throw new InvalidDataException("Incomplete shared lamp call");active=null;break;
                case 3:
                    if(m.Memory[0x23]!=row[2] || m.Memory[0x24]!=row[3] || m.Memory[0x25]!=row[4] || m.Memory[0x26]!=row[5] || m.Memory[0x27]!=row[6] || m.ReadWord(0x28)!=row[7] || Ports(6)!=row[8])throw new InvalidDataException($"Shared scan {scans} entry differs");
                    scan!.Advance();scans++;break;
                case 4:
                    if(m.Memory[0x23]!=row[2] || m.Memory[0x24]!=row[3] || m.Memory[0x26]!=row[4] || m.ReadWord(0x28)!=row[5] || Ports(6)!=row[6])throw new InvalidDataException($"Shared scan {scans-1} return differs");
                    outputs.Add(new(outputs.Count,timeline.Now-capture.InitialCycle,"Scan",m.Memory[0x23],m.ReadWord(0x28),Ports(6).ToString("X12")));break;
                case 5:
                    if(!arms.TryDequeue(out var arm) || arm.Timer!=row[2] || arm.Callback!=row[3])throw new InvalidDataException("Shared timer arm differs");
                    timerPending=true;armCount++;break;
                case 6:
                    if(callbackOpen || !timerPending || m.ReadWord(0x28)!=row[2] || Ports(3)!=row[3])throw new InvalidDataException($"Shared callback {callbacks} entry differs");
                    // FE70 dispatch disables timer 3 before calling its registered helper.
                    if(!Mpu4TimerCallbacks.DispatchTimer3(m,(address,state)=> {
                        if(address!=0x48FD)throw new NotSupportedException($"Untranslated timer callback {address:X4}");Mpu4LampInhibit.Apply(state);
                    }))throw new InvalidDataException("Captured timer callback was suppressed");
                    timerPending=false;callbackOpen=true;callbacks++;break;
                case 7:
                    if(!callbackOpen || m.ReadWord(0x28)!=row[2] || Ports(3)!=row[3])throw new InvalidDataException("Shared callback return differs");callbackOpen=false;
                    outputs.Add(new(outputs.Count,timeline.Now-capture.InitialCycle,"Timer callback",m.Memory[0x23],m.ReadWord(0x28),Ports(6).ToString("X12")));break;
                default:throw new InvalidDataException("Unknown shared event");
            }
        }
        var result=SkillCashFeatureReplay.Run(evidenceDirectory,lampOutput:requests.Enqueue,observe:(ordinal,signature)=> {
            Span<byte> bytes=stackalloc byte[48];for(int n=0;n<24;n++)BinaryPrimitives.WriteUInt16BigEndian(bytes.Slice(n*2,2),signature[n]);vmHash.AppendData(bytes);
        },platformStep:(ordinal,instruction,m)=> {
            if(shared is null)Initialize(m);
            if(ordinal>=capture.VmCycleDeltas.Length)throw new InvalidDataException("Extra timed VM instruction");
            vmCycle=checked(vmCycle+capture.VmCycleDeltas[ordinal]);
            timeline.AdvanceTo(vmCycle,item=>Event(item.Data));
        });
        if(timeline.Remaining!=0 || callbackOpen || requests.Count!=0 || active is not null || arms.Count!=0 || result.Instructions!=capture.VmCycleDeltas.Length || writes!=4*result.LampRequests ||
            Convert.ToHexString(vmHash.GetHashAndReset())!=capture.ExpectedVmSha256)
            throw new InvalidDataException("Incomplete shared timing replay");
        return new(result.Instructions,writes,scans,armCount,callbacks,outputs);
    }
}

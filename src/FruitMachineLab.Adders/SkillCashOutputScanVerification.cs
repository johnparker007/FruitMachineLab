using System.Buffers.Binary;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record ScanInput(int Ordinal,Dictionary<string,string> Changes);
public record ScanAnchor(int Ordinal,byte Phase,byte Count,byte Reload,byte Alternate,
    [property:JsonPropertyName("alternate_reload")] byte AlternateReload,ushort Column,string Ports);
public record ScanCapture(Dictionary<string,string> Initial,ScanInput[] Inputs,ScanAnchor[] Anchors,int Scans,
    [property:JsonPropertyName("expected_sha256")] string ExpectedSha256,[property:JsonPropertyName("pulse_calls")] int[][] PulseCalls);
public record OutputScanFrame(int Ordinal,ushort ReferenceClock,ushort ReferenceTick,OutputScanState State);
public record ScanVerification(int Scans,int ExternalChanges,int PulseCalls,IReadOnlyList<OutputScanState> States,IReadOnlyList<OutputScanFrame> Frames);
public static class SkillCashOutputScanVerification
{
    public static ScanVerification Verify(string evidenceDirectory,bool incremental=false)
    {
        var capture=JsonSerializer.Deserialize<ScanCapture>(File.ReadAllText(Path.Combine(evidenceDirectory,"skill-cash","output-scan.json")),
            new JsonSerializerOptions{PropertyNameCaseInsensitive=true})!;
        var m=new Machine();SkillCashData.LoadScan(m);
        ushort referenceClock=0,referenceTick=0;
        void Apply(Dictionary<string,string> fields) {
            foreach(var pair in fields) {
                switch(pair.Key) {
                    case "frames":Convert.FromHexString(pair.Value).CopyTo(m.Memory,0x100);break;
                    case "digits":Convert.FromHexString(pair.Value).CopyTo(m.Memory,0x1A);break;
                    case "samples":Convert.FromHexString(pair.Value).CopyTo(m.Memory,8);break;
                    case "blink":Convert.FromHexString(pair.Value).CopyTo(m.Memory,0x2BE);break;
                    case "ports": {
                        ushort[] addresses=[0xA00,0xA02,0xB00,0xE01,0xB01,0xF01];var values=Convert.FromHexString(pair.Value);
                        for(int n=0;n<addresses.Length;n++)m.Memory[addresses[n]]=values[n];break;
                    }
                    case "column":m.WriteWord(0x28,Convert.ToUInt16(pair.Value,16));break;
                    case "clock":referenceClock=Convert.ToUInt16(pair.Value,16);break;
                    case "tick":referenceTick=Convert.ToUInt16(pair.Value,16);break;
                    default: {
                        ushort address=pair.Key switch {"phase"=>0x23,"count"=>0x24,"reload"=>0x25,"alternate"=>0x26,"alternate_reload"=>0x27,
                            "suppress"=>0x8D,"decimal"=>0x22,"sweep"=>0xB3,_=>throw new InvalidDataException("Unknown scan input field")};
                        m.Memory[address]=Convert.ToByte(pair.Value,16);break;
                    }
                }
            }
        }
        int ordinal=0,pulse=0;
        int[]? pendingPulse=null;
        int[] PreparePulse(Machine state) {
            if(pulse>=capture.PulseCalls.Length)throw new InvalidDataException("Extra lamp pulse call");
            var call=capture.PulseCalls[pulse++];if(call[0]!=ordinal || call[1]!=state.Memory[0xB3])throw new InvalidDataException("Pulse call boundary differs");
            state.Memory[0xE8]=(byte)call[2];state.Memory[0xE9]=(byte)call[3];state.Memory[0xEA]=(byte)call[4];
            state.WriteWord(0x32D,(ushort)call[5]);state.WriteWord(0x3D,(ushort)call[6]);state.WriteWord(0x3F,(ushort)call[7]);
            return call;
        }
        void VerifyPulse(Machine state,int[] call,int arms) {
            if(state.Memory[0xE8]!=call[8] || state.Memory[0xEA]!=call[9] || state.ReadWord(0x32D)!=call[10] || state.ReadWord(0x3D)!=call[11] || state.ReadWord(0x3F)!=call[12] || arms!=1)
                throw new InvalidDataException("Pulse helper state differs");
        }
        var scan=new Mpu4OutputScan(m,state=> {
            var call=PreparePulse(state);int arms=0;Mpu4LampPulseSweep.Advance(state,arm=>{arms++;if(arm.Callback!=0x48FD || arm.Timer!=call[10])throw new InvalidDataException("Pulse arm differs");});VerifyPulse(state,call,arms);
        });
        Apply(capture.Initial);var states=new List<OutputScanState>();var frames=new List<OutputScanFrame>();int input=0,anchor=0;
        using var hash=IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        Span<byte> bytes=stackalloc byte[13];
        for(ordinal=0;ordinal<capture.Scans;ordinal++) {
            if(input<capture.Inputs.Length && capture.Inputs[input].Ordinal==ordinal)Apply(capture.Inputs[input++].Changes);
            if(incremental){
                int arms=0;using var execution=new Mpu4OutputScanExecution(m,0);
                execution.ObserveInstruction=instruction=>{if(instruction.Address==0x19C2)pendingPulse=PreparePulse(m);if(instruction.Address==0x19F8){VerifyPulse(m,pendingPulse ?? throw new InvalidDataException("Missing pulse entry"),arms);pendingPulse=null;}};
                execution.ObserveArm=(_,arm)=>{arms++;if(pendingPulse is null || arm.Callback!=0x48FD || arm.Timer!=pendingPulse[10])throw new InvalidDataException("Incremental arm differs");};
                while(!execution.Completed)execution.AdvanceTo(execution.NextEventCycle);
            }else scan.Advance();
            var state=scan.Snapshot();states.Add(state);frames.Add(new(ordinal,referenceClock,referenceTick,state));
            if(anchor<capture.Anchors.Length && capture.Anchors[anchor].Ordinal==ordinal) {
                var expected=capture.Anchors[anchor++];
                if(state.Phase!=expected.Phase || state.Count!=expected.Count || state.Reload!=expected.Reload || state.Alternate!=expected.Alternate ||
                    state.AlternateReload!=expected.AlternateReload || state.Column!=expected.Column || state.Ports!=expected.Ports)throw new InvalidDataException($"Output scan mismatch at {ordinal}: {state} != {expected}");
            }
            bytes[0]=state.Phase;bytes[1]=state.Count;bytes[2]=state.Reload;bytes[3]=state.Alternate;bytes[4]=state.AlternateReload;
            BinaryPrimitives.WriteUInt16BigEndian(bytes.Slice(5,2),state.Column);Convert.FromHexString(state.Ports).CopyTo(bytes[7..]);hash.AppendData(bytes);
        }
        if(input!=capture.Inputs.Length || anchor!=capture.Anchors.Length || pulse!=capture.PulseCalls.Length || Convert.ToHexString(hash.GetHashAndReset())!=capture.ExpectedSha256)throw new InvalidDataException("Output scan digest or coverage differs");
        return new(capture.Scans,capture.Inputs.Length,pulse,states,frames);
    }
}

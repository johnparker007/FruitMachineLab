using System.Text.Json;
using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

public static class AddersMeterPulseVerification
{
    private const string FileName="meter-pulse-58bb-empty.json";

    private static string FilePath(string evidence)=>Path.Combine(evidence,"collection",FileName);

    public static int Verify(string evidence)
    {
        using var document=JsonDocument.Parse(File.ReadAllText(FilePath(evidence)));
        var root=document.RootElement;
        if(root.GetProperty("schema").GetString()!="fruitmachinelab.mpu4.meter-pulse-58bb-empty/v1")
            throw new InvalidDataException("Meter pulse schema differs");

        var capture=root.GetProperty("capture");
        string capturePath=Path.Combine(evidence,capture.GetProperty("fixture").GetString()!);
        if(!FixtureIntegrity.MatchesPinnedHash(capturePath,capture.GetProperty("fixture_sha256").GetString()!))
            throw new InvalidDataException("Meter pulse capture41 fixture hash differs");
        using var captureDocument=JsonDocument.Parse(File.ReadAllText(capturePath));
        var captureRoot=captureDocument.RootElement;
        if(captureRoot.GetProperty("source").GetProperty("debug_sha256").GetString()!=capture.GetProperty("debug_sha256").GetString())
            throw new InvalidDataException("Meter pulse debug provenance differs");
        if(captureRoot.GetProperty("source").GetProperty("rom_sha1").GetString()!=capture.GetProperty("rom_sha1").GetString())
            throw new InvalidDataException("Meter pulse ROM provenance differs");

        var (machine,s,u,x,y,a,b,start)=Seed(root);
        var callPush=captureRoot.GetProperty("key_call_chain").EnumerateArray()
            .Single(row=>row.GetProperty("pc").GetString()=="FEC9" && row.GetProperty("wpaddr").GetString()=="078C");
        if(HexU64(callPush.GetProperty("cycle"))!=start || callPush.GetProperty("old").GetString()!="C6" ||
           callPush.GetProperty("new").GetString()!="C9")
            throw new InvalidDataException("Meter pulse FEC6 call event differs");
        byte[] before=machine.Memory.AsSpan(0,0x800).ToArray();

        var result=AddersMeterPulseExecution.Execute(machine,start,s,u,x,y,a,b);
        var expected=root.GetProperty("expected");
        var returned=root.GetProperty("return");
        if(result.CallCycles!=(ulong)expected.GetProperty("call_cycles").GetUInt64() ||
           result.HelperCycles!=(ulong)expected.GetProperty("helper_cycles").GetUInt64() ||
           result.ReturnState.Cycle-start!=(ulong)expected.GetProperty("captured_span_cycles").GetUInt64())
            throw new InvalidDataException("Meter pulse cycle split differs");
        if(AddersMeterPulseExecution.CallCycles!=8 || AddersMeterPulseExecution.HelperCycles!=187 ||
           AddersMeterPulseExecution.TotalCycles!=195)
            throw new InvalidDataException("Meter pulse source timing differs");

        if(result.ReturnState.Cycle!=HexU64(returned.GetProperty("cycle")) ||
           result.ReturnState.PC!=HexU16(returned.GetProperty("pc")) ||
           result.ReturnState.S!=HexU16(returned.GetProperty("s")) ||
           result.ReturnState.U!=HexU16(returned.GetProperty("u")) ||
           result.ReturnState.X!=HexU16(returned.GetProperty("x")) ||
           result.ReturnState.Y!=HexU16(returned.GetProperty("y")) ||
           result.ReturnState.A!=HexU8(returned.GetProperty("a")) ||
           result.ReturnState.B!=HexU8(returned.GetProperty("b")))
            throw new InvalidDataException("Meter pulse return state differs");
        if(machine.ReadWord((ushort)(result.ReturnState.S-2))!=0xFEC9)
            throw new InvalidDataException("Meter pulse return word differs");

        var fec9=captureRoot.GetProperty("anchors").GetProperty("fec9");
        if(HexU64(fec9.GetProperty("cycle"))!=result.ReturnState.Cycle ||
           HexU16(fec9.GetProperty("s"))!=result.ReturnState.S ||
           HexU16(fec9.GetProperty("ret"))!=0xC047)
            throw new InvalidDataException("Meter pulse FEC9 capture anchor differs");

        for(int address=0;address<0x800;address++)
            if(address!=0x078B && address!=0x078C && before[address]!=machine.Memory[address])
                throw new InvalidDataException($"Meter pulse wrote unexpected RAM at {address:X4}");
        if(machine.Memory[0x078B]!=0xFE || machine.Memory[0x078C]!=0xC9)
            throw new InvalidDataException("Meter pulse stack word differs");
        if(result.MemoryAfter.Length!=0x800 || !result.MemoryAfter.AsSpan().SequenceEqual(machine.Memory.AsSpan(0,0x800)))
            throw new InvalidDataException("Meter pulse after-memory copy differs");

        var entry=root.GetProperty("entry");
        if(HexU64(entry.GetProperty("cycle"))!=start || HexU16(entry.GetProperty("s"))!=s ||
           HexU16(entry.GetProperty("u"))!=u || HexU16(entry.GetProperty("x"))!=x ||
           HexU16(entry.GetProperty("y"))!=y || HexU8(entry.GetProperty("a"))!=a ||
           HexU8(entry.GetProperty("b"))!=b)
            throw new InvalidDataException("Meter pulse entry state differs");
        return 1;
    }

    public static int Rejects(string evidence,string kind)
    {
        using var document=JsonDocument.Parse(File.ReadAllText(FilePath(evidence)));
        var (machine,s,u,x,y,a,b,start)=Seed(document.RootElement);
        if(kind=="disabled")machine.Memory[0x719B]=0x04;
        else if(kind=="timer")machine.Memory[0x003A]=0x80;
        else if(kind=="active")machine.Memory[0x0039]=0x01;
        else if(kind=="pulse")machine.WriteWord(0x035E,1);
        else if(kind=="rom")machine.Memory[AddersMeterPulseExecution.Entry]^=0xFF;
        else if(kind=="call")machine.Memory[AddersMeterPulseExecution.Call]^=0xFF;
        else if(kind=="stack")s=1;
        else throw new ArgumentOutOfRangeException(nameof(kind));

        byte[] before=machine.Memory.ToArray();
        bool rejected=false;
        try{AddersMeterPulseExecution.Execute(machine,start,s,u,x,y,a,b);}
        catch(NotSupportedException){rejected=true;}
        catch(ArgumentOutOfRangeException){rejected=true;}
        catch(InvalidDataException){rejected=true;}
        if(!rejected)throw new InvalidDataException($"Meter pulse negative {kind} was accepted");
        if(!before.AsSpan().SequenceEqual(machine.Memory))
            throw new InvalidDataException($"Meter pulse negative {kind} mutated memory");
        return 1;
    }

    private static ushort HexU16(JsonElement value)=>value.ValueKind==JsonValueKind.String ? Convert.ToUInt16(value.GetString()!,16) : value.GetUInt16();
    private static ulong HexU64(JsonElement value)=>value.ValueKind==JsonValueKind.String ? Convert.ToUInt64(value.GetString()!,16) : value.GetUInt64();
    private static byte HexU8(JsonElement value)=>value.ValueKind==JsonValueKind.String ? Convert.ToByte(value.GetString()!,16) : value.GetByte();

    private static (Machine Machine,ushort S,ushort U,ushort X,ushort Y,byte A,byte B,ulong Start) Seed(JsonElement root)
    {
        var machine=new Machine();
        foreach(var region in root.GetProperty("rom_regions").EnumerateArray())
            Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!)
                .CopyTo(machine.Memory,Convert.ToUInt16(region.GetProperty("address").GetString()!,16));
        var ram=root.GetProperty("ram");
        machine.Memory[0x719B]=HexU8(ram.GetProperty("719b"));
        machine.Memory[0x0039]=HexU8(ram.GetProperty("0039"));
        machine.Memory[0x003A]=HexU8(ram.GetProperty("003a"));
        Convert.FromHexString(ram.GetProperty("queue_hex").GetString()!).CopyTo(machine.Memory,0x035E);
        var entry=root.GetProperty("entry");
        return (machine,HexU16(entry.GetProperty("s")),HexU16(entry.GetProperty("u")),
            HexU16(entry.GetProperty("x")),HexU16(entry.GetProperty("y")),
            HexU8(entry.GetProperty("a")),HexU8(entry.GetProperty("b")),
            HexU64(entry.GetProperty("cycle")));
    }
}



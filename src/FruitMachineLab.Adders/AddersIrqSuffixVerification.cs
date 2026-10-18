using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Nodes;
using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

public static class AddersIrqSuffixVerification
{
    private const string CompositionFile="irq-suffix-capture57-composition.json";
    private const string CaptureFile="irq-suffix-capture57.json";
    private const string CompositionSha256="859E96D303DEBC044B529C60327427FB3D92EB9D58FA3EE20A716D27330F4EFA";
    private const string CaptureSha256="B7029FD86E2D93154E1EA907E24A589CE1C1A8DE2BD17CB81016BD4ADE6A8545";
    private const string RomSha1="402D1518BB78FDC489B06C2AABC771E5CE151847";
    private const string RomSha256="EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C";
    private const int RamSize=0x800;

    private sealed record Region(ushort Address,byte[] Bytes);
    private sealed record Anchor(ushort PC,ulong Cycle,ushort S,ushort U,ushort X,ushort Y,byte A,byte B,byte CC,byte[] Memory);
    private sealed record TraceRow(ushort PC,ulong Cycle,ushort S,ushort U,ushort X,ushort Y,byte A,byte B,byte CC,string Op);

    private static string PathOf(string evidence,string name)=>Path.Combine(evidence,"collection",name);
    private static void Require(bool condition,string message){if(!condition)throw new InvalidDataException(message);}
    private static string Sha256(byte[] bytes)=>Convert.ToHexString(SHA256.HashData(bytes));
    private static ushort U16(JsonElement value)=>value.ValueKind==JsonValueKind.String
        ? Convert.ToUInt16(value.GetString()!,16) : value.GetUInt16();
    private static ulong U64(JsonElement value)=>value.ValueKind==JsonValueKind.String
        ? Convert.ToUInt64(value.GetString()!,16) : value.GetUInt64();
    private static byte U8(JsonElement value)=>value.ValueKind==JsonValueKind.String
        ? Convert.ToByte(value.GetString()!,16) : value.GetByte();

    public static int Verify(string evidence)
    {
        string composition=PathOf(evidence,CompositionFile);
        string capture=PathOf(evidence,CaptureFile);
        Require(FixtureIntegrity.MatchesPinnedHash(composition,CompositionSha256),"IRQ suffix composition fixture hash differs");
        Require(FixtureIntegrity.MatchesPinnedHash(capture,CaptureSha256),"IRQ suffix capture57 fixture hash differs");
        using var compositionDocument=JsonDocument.Parse(File.ReadAllText(composition));
        using var captureDocument=JsonDocument.Parse(File.ReadAllText(capture));
        return VerifySemantic(compositionDocument.RootElement,captureDocument.RootElement);
    }

    public static int VerifySemanticForTests(string evidence)
    {
        using var compositionDocument=JsonDocument.Parse(File.ReadAllText(PathOf(evidence,CompositionFile)));
        using var captureDocument=JsonDocument.Parse(File.ReadAllText(PathOf(evidence,CaptureFile)));
        return VerifySemantic(compositionDocument.RootElement,captureDocument.RootElement);
    }

    private static int VerifySemantic(JsonElement root,JsonElement capture)
    {
        Require(root.GetProperty("schema").GetString()=="fruitmachinelab.mpu4.irq-suffix-capture57-composition/v1",
            "IRQ suffix composition schema differs");
        Require(capture.GetProperty("schema").GetString()=="fruitmachinelab.mpu4.irq-suffix-capture57/v1",
            "IRQ suffix capture57 schema differs");
        Require(capture.GetProperty("attempt").GetInt32()==2,"IRQ suffix capture57 attempt differs");
        Require(capture.GetProperty("exitCode").GetInt32()==0,"IRQ suffix capture57 exit differs");
        var provenance=root.GetProperty("provenance");
        Require(provenance.GetProperty("rom_sha1").GetString()==RomSha1,"IRQ suffix ROM SHA1 differs");
        Require(provenance.GetProperty("rom_sha256").GetString()==RomSha256,"IRQ suffix ROM SHA256 differs");
        Require(provenance.GetProperty("mame_version").GetString()=="0.281","IRQ suffix MAME version differs");
        Require(provenance.GetProperty("entry_s").GetString()==capture.GetProperty("entryS").GetString(),
            "IRQ suffix entry S differs from capture57");
        Require(capture.GetProperty("entryS").GetString()=="078D",
            "IRQ suffix capture57 entry S is not the independently captured 078D");
        Require(AddersIrqSuffixExecution.CapturedEntryS==0x078D,
            "IRQ suffix closed entry S placement differs");
        Require(provenance.GetProperty("service_entry_s").GetString()==capture.GetProperty("serviceEntryS").GetString(),
            "IRQ suffix service entry S differs from capture57");
        Require(capture.GetProperty("serviceEntryS").GetString()=="078B",
            "IRQ suffix capture57 service entry S is not the independently captured 078B");
        Require(AddersIrqSuffixExecution.CapturedServiceEntryS==0x078B,
            "IRQ suffix closed service entry S placement differs");
        Require(provenance.GetProperty("host_44_at_service").GetString()==capture.GetProperty("host44AtService").GetString(),
            "IRQ suffix host 44 differs from capture57");

        var host=root.GetProperty("host_inputs");
        Require(host.GetProperty("719B").GetString()=="00","IRQ suffix captured 719B is not the observed zero");
        Require(host.GetProperty("guard83").GetString()=="FF","IRQ suffix captured 83 is not the observed FF");
        Require(host.GetProperty("host44").GetString()=="00","IRQ suffix captured host 44 is not the observed zero");

        var regions=ReadRegions(root);
        var anchors=ReadAnchors(root);
        var rows=ReadTrace(capture);
        Require(rows.Count==capture.GetProperty("trace").GetProperty("count").GetInt32(),
            "IRQ suffix trace row count differs");
        Require(root.GetProperty("trace").GetProperty("fixture").GetString()=="collection/irq-suffix-capture57.json",
            "IRQ suffix composition trace reference differs");

        var machine=new Machine();
        foreach(var region in regions)region.Bytes.CopyTo(machine.Memory,region.Address);
        var entry=anchors["fec3"];
        Require(provenance.GetProperty("entry_memory_sha256").GetString()==Sha256(entry.Memory),
            "IRQ suffix initial FEC3 2KB does not match the captured entry pin; intermediate reseeding is rejected");
        entry.Memory.CopyTo(machine.Memory,0);
        Require(Sha256(machine.Memory.AsSpan(0,RamSize).ToArray())==Sha256(entry.Memory),
            "IRQ suffix initial FEC3 2KB differs");
        Require(machine.Memory[0x719B]==0x00,"IRQ suffix initial 719B is not the observed zero");
        Require(machine.Memory[0x0083]==0xFF,"IRQ suffix initial 83 is not the observed FF");
        Require(machine.Memory[0x0044]==0x00,"IRQ suffix initial host 44 is not the observed zero");
        for(int index=0;index<rows.Count;index++)
        {
            var row=rows[index];
            Require(row.PC+4<=machine.Memory.Length,$"IRQ suffix trace row {index} PC crosses memory");
            string actual=Convert.ToHexString(machine.Memory.AsSpan(row.PC,4));
            Require(actual==row.Op,$"IRQ suffix trace row {index} opcode context differs at {row.PC:X4}");
            if(index>0)Require(row.Cycle>rows[index-1].Cycle,$"IRQ suffix trace row {index} cycle is not increasing");
        }

        var expected=root.GetProperty("expected_cycles");
        var result=AddersIrqSuffixExecution.Execute(
            machine,entry.Cycle,entry.S,entry.U,entry.X,entry.Y,entry.A,entry.B,entry.CC);
        VerifyClosedFrames(regions,entry);

        CompareCpu(entry.Cycle,entry.PC,entry.S,entry.U,entry.X,entry.Y,entry.A,entry.B,entry.CC,
            result.SixB4D.Entry,"FEC3 entry");
        for(int index=0;index<32;index++)
            CompareCpuTrace(rows[index],result.SixB4D.Boundaries[index],$"6B4D trace row {index}");
        Require(result.SixB4D.CallCycles==U64(expected.GetProperty("fec3_to_fec6_call")),
            "IRQ suffix 6B4D call cycles differ");
        Require(result.SixB4D.PathCycles==U64(expected.GetProperty("fec3_to_fec6_path")),
            "IRQ suffix 6B4D path cycles differ");
        Require(result.SixB4D.Return.Cycle-entry.Cycle==U64(expected.GetProperty("fec3_to_fec6_total")),
            "IRQ suffix 6B4D total cycles differ");
        CompareMemory(result.SixB4D.MemoryAfter,anchors["fec6"].Memory,"FEC6");

        MatchMeterTrace(rows,result.MeterPulse.Boundaries);
        Require(result.MeterPulse.CallCycles==U64(expected.GetProperty("fec6_to_fec9_call")),
            "IRQ suffix 58BB call cycles differ");
        Require(result.MeterPulse.HelperCycles==U64(expected.GetProperty("fec6_to_fec9_helper")),
            "IRQ suffix 58BB helper cycles differ");
        Require(result.MeterPulse.ReturnState.Cycle-result.MeterPulse.CallState.Cycle==U64(expected.GetProperty("fec6_to_fec9_total")),
            "IRQ suffix 58BB total cycles differ");
        CompareMemory(result.MeterPulse.MemoryAfter,anchors["fec9"].Memory,"FEC9");

        CompareCpuTrace(rows[67],result.ServiceEntry,"5CD0 entry");
        CompareMemory(result.ServiceEntryMemory,anchors["sv"].Memory,"5CD0 entry");
        Require(result.ServiceEntry.Cycle-result.MeterPulse.ReturnState.Cycle==U64(expected.GetProperty("fec9_to_sv_call")),
            "IRQ suffix FEC9 JSR cycles differ");
        Require(machine.ReadWord(result.ServiceEntry.S)==0xFECC,"IRQ suffix FEC9 JSR stack word differs");
        Require(result.ServiceEntry.S==result.MeterPulse.ReturnState.S-2,"IRQ suffix FEC9 JSR did not push the return frame");

        MatchServiceTrace(rows,result.ServiceInstructions);
        Require(result.ServiceInstructions.Count>0 && result.ServiceInstructions[^1].Address==0x5D3A,
            "IRQ suffix native service did not finish at 5D3A");
        Require(result.Fecc.Cycle-result.ServiceEntry.Cycle==U64(expected.GetProperty("sv_to_fecc_service")),
            "IRQ suffix native service span differs");
        Require(result.Fecc.Cycle==rows[258].Cycle,"IRQ suffix FECC cycle differs from the capture57 trace");
        Require(result.Fecc.S==rows[258].S,"IRQ suffix FECC S differs from the capture57 trace");
        Require(result.Fecc.Flags.KnownMask==0,
            "IRQ suffix native 5CD0 post-service flags must be explicitly unknown");
        CompareMemory(result.Fecc.MemoryAfter,anchors["fecc"].Memory,"FECC");
        Require(result.Fecc.Cycle-result.MeterPulse.ReturnState.Cycle==U64(expected.GetProperty("fec9_to_fecc_total")),
            "IRQ suffix FEC9 to FECC total cycles differ");

        Require(result.Fece.Cycle==rows[259].Cycle,"IRQ suffix FECE cycle differs from the capture57 trace");
        Require(result.Fece.S==rows[259].S,"IRQ suffix FECE S differs from the capture57 trace");
        Require(result.Fece.Flags.KnownMask==AddersIrqSuffixFlags.Condition &&
            result.Fece.Flags.Value==AddersIrqSuffixFlags.Z,
            "IRQ suffix FECC CLR 2C known condition flags must be N0 Z1 V0 C0");
        Require((result.Fece.Flags.KnownMask&0xF0)==0,
            "IRQ suffix FECC CLR 2C must not claim H/I/F/E after native 5CD0");
        Require((rows[259].CC&AddersIrqSuffixFlags.Condition)==result.Fece.Flags.Value,
            "IRQ suffix FECC CLR 2C captured condition bits differ from the known mask");
        CompareMemory(result.Fece.MemoryAfter,anchors["fece"].Memory,"FECE");
        Require(result.Fece.Cycle-result.Fecc.Cycle==U64(expected.GetProperty("fecc_clr2c")),
            "IRQ suffix FECC CLR 2C cycles differ");
        Require(result.Fece.Cycle-entry.Cycle==U64(expected.GetProperty("fec3_to_fece_total")),
            "IRQ suffix total FEC3 to FECE cycles differ");
        VerifyRomUnchanged(machine,regions);
        return 1;
    }

    private static void VerifyClosedFrames(Region[] regions,Anchor entry)
    {
        foreach(ushort s in new[]{AddersIrq6B4DZeroStateExecution.CaptureS,AddersIrq6B4DZeroStateExecution.SuffixCaptureS})
        {
            var machine=new Machine();
            foreach(var region in regions)region.Bytes.CopyTo(machine.Memory,region.Address);
            entry.Memory.CopyTo(machine.Memory,0);
            var result=AddersIrq6B4DZeroStateExecution.Execute(
                machine,entry.Cycle,s,entry.U,entry.X,entry.Y,entry.A,entry.B,entry.CC);
            Require(result.Entry.S==s,$"IRQ suffix closed FEC3 frame S={s:X4} was not accepted");
            Require(result.Return.S==s,$"IRQ suffix closed FEC3 frame S={s:X4} did not unwind");
        }
    }

    private static void MatchMeterTrace(IReadOnlyList<TraceRow> rows,IReadOnlyList<AddersMeterPulseState> boundaries)
    {
        int matched=0,cursor=0;
        for(int index=31;index<67;index++)
        {
            var row=rows[index];
            bool found=false;
            for(;cursor<boundaries.Count;cursor++)
            {
                var boundary=boundaries[cursor];
                if(boundary.PC!=row.PC || boundary.Cycle!=row.Cycle)continue;
                CompareMeterTrace(row,boundary,$"58BB trace row {index}");
                found=true;matched++;cursor++;break;
            }
            Require(found,$"IRQ suffix 58BB trace row {index} PC {row.PC:X4} cycle {row.Cycle:X} has no generated boundary");
        }
        Require(matched==36,$"IRQ suffix 58BB matched {matched} trace rows, expected 36");
        Require(boundaries.Count>=36,"IRQ suffix 58BB boundary count is below the captured trace count");
    }

    private static void MatchServiceTrace(IReadOnlyList<TraceRow> rows,IReadOnlyList<OutputScanInstruction> instructions)
    {
        int matched=0;
        for(int index=67;index<258;index++)
        {
            var row=rows[index];
            ulong expected=row.Cycle;
            bool found=false;
            for(int cursor=0;cursor<instructions.Count;cursor++)
            {
                var instruction=instructions[cursor];
                if(instruction.Address!=row.PC || instruction.Started!=expected)continue;
                Require(row.Op.StartsWith(instruction.Bytes,StringComparison.OrdinalIgnoreCase),
                    $"IRQ suffix native trace row {index} opcode {row.Op} differs from {instruction.Bytes}");
                found=true;matched++;break;
            }
            Require(found,$"IRQ suffix native trace row {index} PC {row.PC:X4} cycle {expected} has no generated instruction");
        }
        Require(matched==191,$"IRQ suffix native trace matched {matched} rows, expected 191");
    }

    private static void CompareCpuTrace(TraceRow row,AddersIrq6B4DZeroState actual,string label)=>
        CompareCpu(row.Cycle,row.PC,row.S,row.U,row.X,row.Y,row.A,row.B,row.CC,actual,label);

    private static void CompareMeterTrace(TraceRow row,AddersMeterPulseState actual,string label)
    {
        Require(row.Cycle==actual.Cycle,$"{label} cycle {actual.Cycle:X} expected {row.Cycle:X}");
        Require(row.PC==actual.PC,$"{label} PC {actual.PC:X4} expected {row.PC:X4}");
        Require(row.S==actual.S,$"{label} S {actual.S:X4} expected {row.S:X4}");
        Require(row.U==actual.U,$"{label} U {actual.U:X4} expected {row.U:X4}");
        Require(row.X==actual.X,$"{label} X {actual.X:X4} expected {row.X:X4}");
        Require(row.Y==actual.Y,$"{label} Y {actual.Y:X4} expected {row.Y:X4}");
        Require(row.A==actual.A,$"{label} A {actual.A:X2} expected {row.A:X2}");
        Require(row.B==actual.B,$"{label} B {actual.B:X2} expected {row.B:X2}");
        Require(row.CC==actual.CC,$"{label} CC {actual.CC:X2} expected {row.CC:X2}");
    }

    private static void CompareCpu(ulong cycle,ushort pc,ushort s,ushort u,ushort x,ushort y,byte a,byte b,byte cc,
        AddersIrq6B4DZeroState actual,string label)
    {
        Require(cycle==actual.Cycle,$"{label} cycle {actual.Cycle:X} expected {cycle:X}");
        Require(pc==actual.PC,$"{label} PC {actual.PC:X4} expected {pc:X4}");
        Require(s==actual.S,$"{label} S {actual.S:X4} expected {s:X4}");
        Require(u==actual.U,$"{label} U {actual.U:X4} expected {u:X4}");
        Require(x==actual.X,$"{label} X {actual.X:X4} expected {x:X4}");
        Require(y==actual.Y,$"{label} Y {actual.Y:X4} expected {y:X4}");
        Require(a==actual.A,$"{label} A {actual.A:X2} expected {a:X2}");
        Require(b==actual.B,$"{label} B {actual.B:X2} expected {b:X2}");
        Require(cc==actual.CC,$"{label} CC {actual.CC:X2} expected {cc:X2}");
    }

    private static void CompareMemory(byte[] actual,byte[] expected,string label)
    {
        Require(actual.Length==RamSize && expected.Length==RamSize,$"{label} 2KB length differs");
        for(int address=0;address<RamSize;address++)
            Require(actual[address]==expected[address],
                $"{label} full 2KB differs at {address:X3}: actual{actual[address]:X2}, captured{expected[address]:X2}");
    }

    private static Region[] ReadRegions(JsonElement root)
    {
        var regions=root.GetProperty("rom_regions").EnumerateArray().Select(item=>
        {
            ushort address=U16(item.GetProperty("address"));
            byte[] bytes=Convert.FromHexString(item.GetProperty("bytes_hex").GetString()!);
            Require(bytes.Length==item.GetProperty("bytes").GetInt32(),$"IRQ suffix ROM region {address:X4} length differs");
            Require(Sha256(bytes).Equals(item.GetProperty("sha256").GetString(),StringComparison.OrdinalIgnoreCase),
                $"IRQ suffix ROM region {address:X4} hash differs");
            Require(address+bytes.Length<=0x10000,$"IRQ suffix ROM region {address:X4} crosses memory");
            return new Region(address,bytes);
        }).ToArray();
        var ordered=regions.OrderBy(region=>region.Address).ToArray();
        for(int index=1;index<ordered.Length;index++)
            Require(ordered[index-1].Address+ordered[index-1].Bytes.Length<=ordered[index].Address,
                "IRQ suffix ROM regions overlap");
        return regions;
    }

    private static Dictionary<string,Anchor> ReadAnchors(JsonElement root)
    {
        var anchors=new Dictionary<string,Anchor>(StringComparer.Ordinal);
        foreach(var property in root.GetProperty("anchors").EnumerateObject())
        {
            var value=property.Value;
            byte[] memory=Convert.FromHexString(value.GetProperty("memory_hex").GetString()!);
            Require(memory.Length==RamSize,$"IRQ suffix anchor {property.Name} 2KB length differs");
            Require(Sha256(memory)==value.GetProperty("memory_sha256").GetString(),
                $"IRQ suffix anchor {property.Name} 2KB hash differs");
            anchors[property.Name]=new(
                U16(value.GetProperty("pc")),U64(value.GetProperty("cycle")),U16(value.GetProperty("s")),
                U16(value.GetProperty("u")),U16(value.GetProperty("x")),U16(value.GetProperty("y")),
                U8(value.GetProperty("a")),U8(value.GetProperty("b")),U8(value.GetProperty("cc")),memory);
        }
        foreach(string name in new[]{"fec3","fec6","fec9","sv","fecc","fece"})
            Require(anchors.ContainsKey(name),$"IRQ suffix anchor {name} is missing");
        Require(anchors["fec3"].PC==0xFEC3,"IRQ suffix initial anchor is not FEC3");
        Require(anchors["sv"].PC==0x5CD0,"IRQ suffix service anchor is not 5CD0");
        Require(anchors["fecc"].PC==0xFECC && anchors["fece"].PC==0xFECE,"IRQ suffix return anchors differ");
        return anchors;
    }

    private static List<TraceRow> ReadTrace(JsonElement capture)
    {
        var trace=capture.GetProperty("trace");
        var rows=trace.GetProperty("rows").EnumerateArray().Select(row=>new TraceRow(
            U16(row.GetProperty("pc")),U64(row.GetProperty("cyc")),U16(row.GetProperty("s")),
            U16(row.GetProperty("u")),U16(row.GetProperty("x")),U16(row.GetProperty("y")),
            U8(row.GetProperty("a")),U8(row.GetProperty("b")),U8(row.GetProperty("cc")),
            row.GetProperty("op").GetString()!)).ToList();
        Require(rows.Count>=260,$"IRQ suffix capture57 trace has only {rows.Count} rows");
        Require(rows[0].PC==0x6B4D && rows[0].Cycle==0x3C59B89,"IRQ suffix trace does not start at the captured 6B4D");
        Require(rows[31].PC==0xFEC6 && rows[31].Cycle==0x3C59C2B,"IRQ suffix trace FEC6 boundary differs");
        Require(rows[66].PC==0xFEC9 && rows[66].Cycle==0x3C59CEE,"IRQ suffix trace FEC9 boundary differs");
        Require(rows[67].PC==0x5CD0 && rows[67].Cycle==0x3C59CF6,"IRQ suffix trace 5CD0 boundary differs");
        Require(rows[258].PC==0xFECC && rows[259].PC==0xFECE,"IRQ suffix trace return boundaries differ");
        return rows;
    }

    private static void VerifyRomUnchanged(Machine machine,Region[] regions)
    {
        foreach(var region in regions)
            for(int offset=0;offset<region.Bytes.Length;offset++)
                Require(machine.Memory[region.Address+offset]==region.Bytes[offset],
                    $"IRQ suffix execution changed ROM {region.Address+offset:X4}");
    }

    public static int Rejects(string evidence)
    {
        using var compositionDocument=JsonDocument.Parse(File.ReadAllText(PathOf(evidence,CompositionFile)));
        using var captureDocument=JsonDocument.Parse(File.ReadAllText(PathOf(evidence,CaptureFile)));
        var compositionRoot=compositionDocument.RootElement;
        var captureRoot=captureDocument.RootElement;
        int count=0;

        void Semantic(string kind,string expected,JsonNode composition,JsonNode capture)
        {
            using var changedComposition=JsonDocument.Parse(composition.ToJsonString());
            using var changedCapture=JsonDocument.Parse(capture.ToJsonString());
            try{VerifySemantic(changedComposition.RootElement,changedCapture.RootElement);}
            catch(Exception error)when(error is InvalidDataException or NotSupportedException)
            {
                if(!error.Message.Contains(expected,StringComparison.Ordinal))
                    throw new InvalidDataException(
                        $"IRQ suffix negative {kind} failed at an unexpected rule: {error.Message}",error);
                count++;
                return;
            }
            throw new InvalidDataException($"IRQ suffix negative {kind} was accepted");
        }

        void EntryS(string kind,ushort s)
        {
            var (machine,entry)=Seed(compositionRoot);
            byte[] before=machine.Memory.ToArray();
            bool rejected=false;
            try{
                AddersIrqSuffixExecution.Execute(
                    machine,entry.Cycle,s,entry.U,entry.X,entry.Y,entry.A,entry.B,entry.CC);
            }catch(NotSupportedException){rejected=true;}
            catch(InvalidDataException){rejected=true;}
            catch(ArgumentOutOfRangeException){rejected=true;}
            if(!rejected)throw new InvalidDataException($"IRQ suffix negative {kind} was accepted");
            if(!before.AsSpan().SequenceEqual(machine.Memory))
                throw new InvalidDataException($"IRQ suffix negative {kind} mutated memory before rejection");
            count++;
        }

        void Memory(string kind,Action<Machine> mutate)
        {
            var (machine,entry)=Seed(compositionRoot);
            mutate(machine);
            byte[] before=machine.Memory.ToArray();
            bool rejected=false;
            try{
                AddersIrqSuffixExecution.Execute(
                    machine,entry.Cycle,entry.S,entry.U,entry.X,entry.Y,entry.A,entry.B,entry.CC);
            }catch(NotSupportedException){rejected=true;}
            catch(InvalidDataException){rejected=true;}
            if(!rejected)throw new InvalidDataException($"IRQ suffix negative {kind} was accepted");
            if(!before.AsSpan().SequenceEqual(machine.Memory))
                throw new InvalidDataException($"IRQ suffix negative {kind} mutated memory before rejection");
            count++;
        }

        Memory("branch",machine=>machine.Memory[0x0073]=0x01);
        Memory("rom",machine=>machine.Memory[0x6B4D]^=0xFF);
        Memory("continuation",machine=>machine.Memory[0xFEC9+1]=0xD1);
        EntryS("s1",0x0001);
        EntryS("snearlow",0x0002);
        EntryS("snearhigh",0x078C);

        var frameNode=JsonNode.Parse(compositionRoot.GetRawText())!;
        frameNode["anchors"]!["fec3"]!["s"]="0786";
        Semantic("frame","requires the independently captured FEC3 entry S",
            frameNode,JsonNode.Parse(captureRoot.GetRawText())!);

        var intermediateNode=JsonNode.Parse(compositionRoot.GetRawText())!;
        string fec6Hex=intermediateNode["anchors"]!["fec6"]!["memory_hex"]!.GetValue<string>();
        string changedHex=fec6Hex[..^2]+(fec6Hex.EndsWith("00",StringComparison.Ordinal)?"01":"00");
        intermediateNode["anchors"]!["fec6"]!["memory_hex"]=changedHex;
        intermediateNode["anchors"]!["fec6"]!["memory_sha256"]=Sha256(Convert.FromHexString(changedHex));
        Semantic("intermediate","FEC6 full 2KB differs",
            intermediateNode,JsonNode.Parse(captureRoot.GetRawText())!);

        var reseedNode=JsonNode.Parse(compositionRoot.GetRawText())!;
        string fec6Memory=reseedNode["anchors"]!["fec6"]!["memory_hex"]!.GetValue<string>();
        reseedNode["anchors"]!["fec3"]!["memory_hex"]=fec6Memory;
        reseedNode["anchors"]!["fec3"]!["memory_sha256"]=Sha256(Convert.FromHexString(fec6Memory));
        Semantic("reseed","intermediate reseeding is rejected",
            reseedNode,JsonNode.Parse(captureRoot.GetRawText())!);

        var traceNode=JsonNode.Parse(captureRoot.GetRawText())!;
        traceNode["trace"]!["rows"]![0]!["cc"]="00";
        Semantic("trace","6B4D trace row 0 CC",
            JsonNode.Parse(compositionRoot.GetRawText())!,traceNode);

        var (ownerMachine,ownerEntry)=Seed(compositionRoot);
        using var owner=new AddersNativeSound(ownerMachine);
        owner.BeginCall(0x5CD0,ownerEntry.Cycle+170+195+8,0x078B,ownerEntry.U,0x0366,0,
            (byte)0x05,(byte)0x0B,true,0xFECC);
        bool duplicate=false;
        try{owner.BeginCall(0x5CD0,owner.Cycle+1,0x078B,ownerEntry.U,0x0366,0,0x05,0x0B,true,0xFECC);}
        catch(InvalidOperationException){duplicate=true;}
        if(!duplicate)throw new InvalidDataException("IRQ suffix negative duplicateowner was accepted");
        count++;
        return count;
    }

    private static (Machine Machine,Anchor Entry) Seed(JsonElement root)
    {
        var machine=new Machine();
        foreach(var region in ReadRegions(root))region.Bytes.CopyTo(machine.Memory,region.Address);
        var entry=ReadAnchors(root)["fec3"];
        entry.Memory.CopyTo(machine.Memory,0);
        return (machine,entry);
    }
}

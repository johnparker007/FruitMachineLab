using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Nodes;
using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

// Verify37: component comparison of every captured outer 5CD0/FECC pair in
// capture36. Each call starts from its own actual 2 KB entry snapshot and actual
// captured 719B value; no captured return snapshot is used as a later state and
// no autonomous IRQ cadence is claimed.
public static class AddersMatchedServiceVerification
{
    private const ushort ServiceEntry=0x5CD0;
    private const ushort ServiceReturn=0xFECC;
    private const int RamSize=0x800;
    private const string ExpectedRomSha1="402D1518BB78FDC489B06C2AABC771E5CE151847";
    private const string ExpectedRomSha256="EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C";
    private const string ExpectedCapture36Sha256="AC60AC5EDE6A962B1FB90DFB8389EF85C6AFE304A25DD24CC7C753A2F59FDB82";
    private const string ExpectedRegionsSha256="DD5DFDCE3E44B51944180A9CB5A5DC84A11D917C3BFD7C301DD8F33F7F40E864";
    private static string FixturePath(string evidence)=>Path.Combine(evidence,"collection","matched-service-window-capture36.json");
    private static string RegionPath(string evidence)=>Path.Combine(evidence,"collection","native-service-rom-regions-capture36.json");

    private sealed record Frame(string Tag,ushort PC,ulong Cycle,ushort S,ushort U,ushort X,ushort Y,byte A,byte B,byte Enable,
        JsonElement Host,JsonElement Links,Dictionary<string,ushort> Stack,byte[] Ram);
    private sealed record Region(ushort Address,byte[] Bytes);

    private static ushort WordAt(byte[] ram,int address)=>(ushort)((ram[address]<<8)|ram[address+1]);
    private static void Require(bool condition,string message){if(!condition)throw new InvalidDataException(message);}

    private static void ValidateFields(JsonElement fields,byte[] ram,string label)
    {
        foreach(var property in fields.EnumerateObject()){
            string text=property.Value.GetString()!;
            ushort address=Convert.ToUInt16(property.Name,16);
            ushort value=Convert.ToUInt16(text,16);
            if(text.Length<=2)Require(ram[address]==(byte)value,$"{label} {property.Name}: fixture{value:X2}, saved before{ram[address]:X2}");
            else Require(WordAt(ram,address)==value,$"{label} {property.Name}: fixture{value:X4}, saved before{WordAt(ram,address):X4}");
        }
    }
    private static void Host(Machine machine,JsonElement host,byte[] ram,string label)
    {
        ValidateFields(host,ram,label+" host");
        foreach(var property in host.EnumerateObject()){
            string text=property.Value.GetString()!;
            ushort address=Convert.ToUInt16(property.Name,16);
            ushort value=Convert.ToUInt16(text,16);
            if(text.Length<=2){if(machine.Memory[address]!=(byte)value)throw new InvalidDataException($"{label} host {property.Name} was not seeded from the saved frame");}
            else if(machine.ReadWord(address)!=value)throw new InvalidDataException($"{label} host {property.Name} was not seeded from the saved frame");
        }
    }
    private static Dictionary<string,ushort> Words(JsonElement element)
    {
        var values=new Dictionary<string,ushort>(StringComparer.OrdinalIgnoreCase);
        foreach(var property in element.EnumerateObject())
            values[property.Name]=Convert.ToUInt16(property.Value.GetString()!,16);
        return values;
    }

    private static Frame ReadFrame(JsonElement element,string role,string expectedTag)
    {
        string tag=element.GetProperty("tag").GetString()!;
        Require(tag==expectedTag,$"{role} tag {tag} differs from {expectedTag}");
        string? ramFile=element.GetProperty("ram_file").GetString();
        Require(ramFile is not null,$"{role} {tag} has no saved 2 KB frame");
        byte[] ram=Convert.FromHexString(element.GetProperty("ram_hex").GetString()!);
        Require(ram.Length==RamSize,$"{role} {tag} snapshot is not 2 KB");
        string hash=Convert.ToHexString(SHA256.HashData(ram));
        Require(hash.Equals(element.GetProperty("ram_sha256").GetString(),StringComparison.OrdinalIgnoreCase),$"{role} {tag} snapshot hash differs");
        var host=element.GetProperty("host");
        ValidateFields(host,ram,$"{role} {tag} host");
        var links=element.GetProperty("links");
        ValidateFields(links,ram,$"{role} {tag} link");
        var stack=Words(element.GetProperty("stack"));
        ushort s=Convert.ToUInt16(element.GetProperty("s").GetString()!,16);
        foreach(var (name,value) in stack){
            ushort offset=Convert.ToUInt16(name.Substring(1),16);ushort saved=WordAt(ram,(ushort)(s+offset));
            Require(saved==value,$"{role} {tag} stack {name}: fixture{value:X4}, saved before{saved:X4}");
        }
        return new(tag,Convert.ToUInt16(element.GetProperty("pc").GetString()!,16),Convert.ToUInt64(element.GetProperty("cycle").GetString()!,16),
            s,Convert.ToUInt16(element.GetProperty("u").GetString()!,16),Convert.ToUInt16(element.GetProperty("x").GetString()!,16),
            Convert.ToUInt16(element.GetProperty("y").GetString()!,16),Convert.ToByte(element.GetProperty("a").GetString()!,16),
            Convert.ToByte(element.GetProperty("b").GetString()!,16),Convert.ToByte(element.GetProperty("719B").GetString()!,16),
            host,links,stack,ram);
    }

    private static Region[] ReadRegions(JsonElement root)
    {
        Require(root.GetProperty("schema").GetString()=="matched-service-native-rom-regions/1","ROM region schema differs");
        var source=root.GetProperty("source");
        Require(source.GetProperty("rom").GetString()=="a6ls.p1","ROM region source file differs");
        Require(source.GetProperty("rom_size").GetInt32()==0x10000,"ROM region source size differs");
        Require(source.GetProperty("rom_sha1").GetString()==ExpectedRomSha1,"ROM region source SHA1 differs");
        Require(source.GetProperty("rom_sha256").GetString()==ExpectedRomSha256,"ROM region source SHA256 differs");
        var regions=root.GetProperty("regions").EnumerateArray().Select(item=>{
            ushort address=checked((ushort)item.GetProperty("address").GetInt32());
            byte[] bytes=Convert.FromHexString(item.GetProperty("bytes_hex").GetString()!);
            Require(bytes.Length==item.GetProperty("bytes").GetInt32(),$"ROM region {address:X4} length differs");
            string hash=Convert.ToHexString(SHA256.HashData(bytes));
            Require(hash.Equals(item.GetProperty("sha256").GetString(),StringComparison.OrdinalIgnoreCase),$"ROM region {address:X4} hash differs");
            Require(address+bytes.Length<=0x10000,$"ROM region {address:X4} exceeds the image");
            return new Region(address,bytes);
        }).ToArray();
        var ordered=regions.OrderBy(region=>region.Address).ToArray();
        for(int i=1;i<ordered.Length;i++)
            Require(ordered[i-1].Address+ordered[i-1].Bytes.Length<=ordered[i].Address,"ROM regions overlap");
        return regions;
    }

    private static void LoadRegions(Machine machine,Region[] regions,ushort address,int length)
    {
        foreach(var region in regions)
            if(address>=region.Address && address+length<=region.Address+region.Bytes.Length){
                Array.Copy(region.Bytes,0,machine.Memory,region.Address,region.Bytes.Length);
                return;
            }
        throw new InvalidDataException($"Missing required ROM region {address:X4}+{length:X}");
    }

    private static void VerifyRomUnchanged(Machine machine,Region[] regions,int pair)
    {
        foreach(var region in regions)
            for(int offset=0;offset<region.Bytes.Length;offset++)
                if(machine.Memory[region.Address+offset]!=region.Bytes[offset])
                    throw new InvalidDataException($"Pair {pair:D2} changed ROM {region.Address+offset:X4}");
    }

    private static int VerifySemantic(JsonElement root,JsonElement regionRoot)
    {
        Require(root.GetProperty("schema").GetString()=="matched-service-window-capture36/1","Matched service schema differs");
        string classification=root.GetProperty("classification").GetString()!;
        Require(classification.StartsWith("controlled replay natural",StringComparison.Ordinal),"Matched service classification differs");
        var source=root.GetProperty("source");
        Require(source.GetProperty("rom_sha1").GetString()==ExpectedRomSha1,"Matched service ROM SHA1 differs");
        Require(source.GetProperty("rom_zip_sha256").GetString()=="E2553AFA6B8E9DEF55BD920E4BED77A4324696C1E358B73BE70BFD2C58179989","Matched service ROM zip hash differs");
        Require(source.GetProperty("mame_sha256").GetString()=="0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A","Matched service MAME hash differs");

        var occurrence=root.GetProperty("occurrence");
        Require(occurrence.GetProperty("all_719b_zero").GetBoolean(),"Matched service 719B is not captured as zero");
        var enables=occurrence.GetProperty("sound_719b_values").EnumerateArray().Select(value=>value.GetString()).ToArray();
        Require(enables.Length==1 && enables[0]=="00","Matched service 719B values differ");

        var regions=ReadRegions(regionRoot);
        LoadRegions(new Machine(),regions,0x5963,0x2B5);
        LoadRegions(new Machine(),regions,0x5C18,0x4C9);

        var capturedEvents=occurrence.GetProperty("event_window").EnumerateArray()
            .Select(item=>(Tag:item.GetProperty("tag").GetString()!,PC:Convert.ToUInt16(item.GetProperty("pc").GetString()!,16),Cycle:Convert.ToUInt64(item.GetProperty("cycle").GetString()!,16)))
            .ToArray();
        var pairs=root.GetProperty("service_pairs").EnumerateArray().ToArray();
        Require(pairs.Length==25,$"Matched service pair count {pairs.Length} differs from 25");
        ulong previousCycle=0;
        for(int index=0;index<pairs.Length;index++)
        {
            var item=pairs[index];
            Require(item.GetProperty("depth").GetInt32()==1,$"Pair {index:D2} is not depth 1");
            Require(!item.GetProperty("nested").GetBoolean(),$"Pair {index:D2} is nested");
            Require(item.GetProperty("entry_tag").GetString()==$"sv{index:D2}",$"Pair {index:D2} entry tag differs");
            Require(item.GetProperty("return_tag").GetString()==$"fecc{index:D2}",$"Pair {index:D2} return tag differs");
            Require(item.GetProperty("entry_return_word").GetString()=="FECC",$"Pair {index:D2} entry return word differs");
            Require(item.GetProperty("host_44_entry").GetString()=="00" && item.GetProperty("host_44_return").GetString()=="00",$"Pair {index:D2} host 44 differs");
            var entry=ReadFrame(item.GetProperty("entry"),"entry",$"sv{index:D2}");
            var ret=ReadFrame(item.GetProperty("return"),"return",$"fecc{index:D2}");
            Require(entry.PC==ServiceEntry,$"Pair {index:D2} entry PC {entry.PC:X4} differs from 5CD0");
            Require(ret.PC==ServiceReturn,$"Pair {index:D2} return PC {ret.PC:X4} differs from FECC");
            Require(ret.S==entry.S+2,$"Pair {index:D2} return S {ret.S:X4} is not entry S+2");
            Require(entry.Enable==0,$"Pair {index:D2} entry 719B is not the captured zero");
            Require(entry.Cycle>previousCycle && ret.Cycle>entry.Cycle,$"Pair {index:D2} cycles are not increasing");
            previousCycle=ret.Cycle;
            ushort capturedWord=WordAt(entry.Ram,entry.S);
            Require(capturedWord==ServiceReturn,$"Pair {index:D2} captured stack return word {capturedWord:X4} is not FECC");
            Require(item.GetProperty("return_stack_word").GetString()==$"{WordAt(ret.Ram,ret.S):X4}",$"Pair {index:D2} return stack word differs");
            Require(item.GetProperty("return_s").GetString()==$"{ret.S:X4}",$"Pair {index:D2} return_s differs");
            var machine=new Machine();
            LoadRegions(machine,regions,0x5963,0x2B5);
            LoadRegions(machine,regions,0x5C18,0x4C9);
            entry.Ram.CopyTo(machine.Memory,0);
            Host(machine,entry.Host,entry.Ram,$"Pair {index:D2} entry");
            machine.Memory[0x719B]=entry.Enable;
            var observed=new List<OutputScanInstruction>();
            using var sound=new AddersNativeSound(machine);
            sound.ObserveInstruction=instruction=>observed.Add(instruction);
            sound.BeginCall(ServiceEntry,0,entry.S,entry.U,entry.X,entry.Y,entry.A,entry.B,true,capturedWord);
            while(sound.Servicing)sound.AdvanceTo(sound.NextEventCycle);
            Require(sound.Fault is null,$"Pair {index:D2} native service faulted: {sound.Fault}");
            Require(sound.CompletedCalls==1,$"Pair {index:D2} completed calls {sound.CompletedCalls} differ from 1");
            Require(sound.LastAddress==capturedWord,$"Pair {index:D2} last address {sound.LastAddress:X4} did not consume the captured continuation {capturedWord:X4}");
            Require(observed.Count>0 && observed[^1].Address==0x5D3A,$"Pair {index:D2} did not complete at the 5D3A RTS");
            Require(sound.Cycle==ret.Cycle-entry.Cycle,$"Pair {index:D2} service span {sound.Cycle:X} differs from the captured {ret.Cycle-entry.Cycle:X}");
            var capturedStreamEvents=capturedEvents.Where(item=>item.Tag is "5d3b" or "5cf3" && item.Cycle>=entry.Cycle && item.Cycle<=ret.Cycle).ToArray();
            var actualStreamEvents=observed.Where(instruction=>instruction.Address is 0x5D3B or 0x5CF3).ToArray();
            Require(actualStreamEvents.Length==capturedStreamEvents.Length,$"Pair {index:D2} generated {actualStreamEvents.Length} 5D3B/5CF3 events; captured {capturedStreamEvents.Length}");
            for(int eventIndex=0;eventIndex<capturedStreamEvents.Length;eventIndex++){
                var expected=capturedStreamEvents[eventIndex];var actual=actualStreamEvents[eventIndex];
                Require(actual.Address==expected.PC,$"Pair {index:D2} stream event {eventIndex} PC {actual.Address:X4} differs from {expected.PC:X4}");
                Require(entry.Cycle+actual.Started==expected.Cycle,$"Pair {index:D2} stream event {eventIndex} cycle {entry.Cycle+actual.Started:X} differs from {expected.Cycle:X}");
            }
            for(int address=0;address<RamSize;address++)
                if(machine.Memory[address]!=ret.Ram[address])
                    throw new InvalidDataException($"Pair {index:D2} RAM {address:X3}: captured{ret.Ram[address]:X2}, actual{machine.Memory[address]:X2}");
            VerifyRomUnchanged(machine,regions,index);
        }
        return pairs.Length;
    }

    public static int Verify(string evidence)
    {
        string fixture=FixturePath(evidence),regionPath=RegionPath(evidence);
        Require(Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(fixture)))==ExpectedCapture36Sha256,"Matched service fixture hash differs");
        Require(Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(regionPath)))==ExpectedRegionsSha256,"ROM region fixture hash differs");
        using var document=JsonDocument.Parse(File.ReadAllText(fixture));
        using var regionDocument=JsonDocument.Parse(File.ReadAllText(regionPath));
        return VerifySemantic(document.RootElement,regionDocument.RootElement);
    }

    // Test-only adapter: deliberately runs semantic validation without the raw
    // fixture pins so isolated mutations can reach their intended rule. Production
    // callers must use Verify, which always enforces both pinned hashes.
    public static int VerifySemanticForTests(string evidence)
    {
        using var document=JsonDocument.Parse(File.ReadAllText(FixturePath(evidence)));
        using var regionDocument=JsonDocument.Parse(File.ReadAllText(RegionPath(evidence)));
        return VerifySemantic(document.RootElement,regionDocument.RootElement);
    }

    public static string Rejects(string evidence,string kind)
    {
        // Prove the pinned fixture is valid before any isolated in-memory mutation.
        Require(Verify(evidence)==25,"Matched service baseline did not pass before a negative mutation");
        string original=File.ReadAllText(FixturePath(evidence));
        string regionOriginal=File.ReadAllText(RegionPath(evidence));
        var root=JsonNode.Parse(original)!.AsObject();
        var regionRoot=JsonNode.Parse(regionOriginal)!.AsObject();
        var pairs=root["service_pairs"]!.AsArray();
        JsonObject Entry(int index)=>pairs[index]!["entry"]!.AsObject();
        JsonObject Return(int index)=>pairs[index]!["return"]!.AsObject();
        void Rehash(JsonObject frame)
        {
            byte[] ram=Convert.FromHexString(frame["ram_hex"]!.GetValue<string>());
            frame["ram_sha256"]=Convert.ToHexString(SHA256.HashData(ram));
        }
        string expected;
        if(kind=="wrongpair"){
            // Keep the declared span coherent so the changed 2 KB frame reaches the
            // actual execution comparison instead of failing an earlier declaration.
            var other=pairs[24]!["return"]!.DeepClone().AsObject();
            other["tag"]="fecc00";
            other["cycle"]=Return(0)["cycle"]!.GetValue<string>();
            byte[] ram=Convert.FromHexString(other["ram_hex"]!.GetValue<string>());
            ushort retS=Convert.ToUInt16(other["s"]!.GetValue<string>(),16);
            pairs[0]!["return"]=other;
            pairs[0]!["return_s"]=other["s"]!.GetValue<string>();
            pairs[0]!["return_cycle"]=other["cycle"]!.GetValue<string>();
            pairs[0]!["return_stack_word"]=$"{WordAt(ram,retS):X4}";
            expected="Pair 00 RAM 003";
        }else if(kind=="returnS"){
            pairs[0]!["return_s"]="078F";
            expected="Pair 00 return_s differs";
        }else if(kind=="returnword"){
            var entry=Entry(0);string hex=entry["ram_hex"]!.GetValue<string>();
            int at=Convert.ToUInt16(entry["s"]!.GetValue<string>(),16)*2;
            entry["ram_hex"]=hex.Substring(0,at)+"FEC9"+hex.Substring(at+4);
            Rehash(entry);
            entry["stack"]!["s0"]="FEC9";
            expected="Pair 00 captured stack return word FEC9 is not FECC";
        }else if(kind=="host"){
            Entry(0)["host"]!["4b"]="02";
            expected="entry sv00 host 4b";
        }else if(kind=="expectedRAM"){
            string hex=Return(0)["ram_hex"]!.GetValue<string>();
            int at=0x294*2;string changed=hex.Substring(at,2)=="FF" ? "00" : "FF";
            Return(0)["ram_hex"]=hex.Substring(0,at)+changed+hex.Substring(at+2);
            Rehash(Return(0));
            expected="Pair 00 RAM 294";
        }else if(kind=="missingROM"){
            var regions=regionRoot["regions"]!.AsArray();
            var keep=regions.Where(region=>region!["address"]!.GetValue<int>()!=0x5963).Select(region=>region!.DeepClone()).ToArray();
            regions.Clear();foreach(var region in keep)regions.Add(region);
            expected="Missing required ROM region 5963";
        }else throw new ArgumentOutOfRangeException(nameof(kind));
        using var document=JsonDocument.Parse(root.ToJsonString());
        using var regionDocument=JsonDocument.Parse(regionRoot.ToJsonString());
        try{
            VerifySemantic(document.RootElement,regionDocument.RootElement);
        }catch(InvalidDataException error){
            if(!error.Message.Contains(expected,StringComparison.Ordinal))
                throw new InvalidDataException($"Matched service negative {kind} rejected at unexpected stage '{error.Message}', expected '{expected}'",error);
            return error.Message;
        }
        throw new InvalidDataException($"Matched service negative {kind} was accepted");
    }

    // Pinning control: append only JSON whitespace so the document semantics are
    // identical while the raw-byte pin must still reject the changed file.
    public static int PinnedRejects(string evidence,string kind)
    {
        string name=kind switch {
            "capture"=>"matched-service-window-capture36.json",
            "regions"=>"native-service-rom-regions-capture36.json",
            _=>throw new ArgumentOutOfRangeException(nameof(kind))
        };
        string dir=Directory.CreateTempSubdirectory("fruitmachine-verify38-pin-").FullName;
        try{
            Directory.CreateDirectory(Path.Combine(dir,"collection"));
            File.Copy(FixturePath(evidence),Path.Combine(dir,"collection","matched-service-window-capture36.json"));
            File.Copy(RegionPath(evidence),Path.Combine(dir,"collection","native-service-rom-regions-capture36.json"));
            File.AppendAllText(Path.Combine(dir,"collection",name)," ");
            try{Verify(dir);}
            catch(InvalidDataException error){
                if(!error.Message.Contains("fixture hash",StringComparison.Ordinal))
                    throw new InvalidDataException($"Pinning negative {kind} rejected at unexpected stage '{error.Message}'",error);
                return 1;
            }
            throw new InvalidDataException($"Pinning negative {kind} was accepted");
        }finally{Directory.Delete(dir,true);}
    }
}

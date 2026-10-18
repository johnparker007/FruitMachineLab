using System.Security.Cryptography;
using System.Text.Json;
using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

// Oracle31 execution of the actual5A14 foreground setup. The captured
// foreground_delta is used only as a comparison: this verifier seeds the single
// captured FC4D 2 KB frame, executes the recovered wrapper and the existing
// native queue owner, then compares the resulting 5C18/5A05 states.
public static class AddersToneSetupVerification
{
    private const int RamSize=0x800;
    private const string ExpectedFc4dSha256="30E97EE9A1A9CC7D50868BDD595D69E52A0A6BF9A0C65E5909F367F8BB3AF6BE";
    private const string BridgeRomSha1="402D1518BB78FDC489B06C2AABC771E5CE151847";
    private static string FixturePath(string evidence)=>Path.Combine(evidence,"collection","fresh-tone-occurrence.json");
    private static string BridgeFixturePath(string evidence)=>Path.Combine(evidence,"collection","tone-setup-bridge-data.json");
    private static void Require(bool condition,string message){if(!condition)throw new InvalidDataException(message);}

    private sealed record Frame(string Name,ushort PC,ulong Cycle,ushort S,ushort U,ushort X,ushort Y,byte A,byte B,byte[]? Ram);

    private static Frame ReadFrame(JsonElement element)
    {
        byte[]? ram=null;
        if(element.TryGetProperty("ram_hex",out var hex) && hex.ValueKind!=JsonValueKind.Null){
            ram=Convert.FromHexString(hex.GetString()!);
            Require(ram.Length==RamSize,$"Snapshot {element.GetProperty("name").GetString()} is not 2 KB");
            string hash=Convert.ToHexString(SHA256.HashData(ram));
            Require(hash.Equals(element.GetProperty("ram_sha256").GetString(),StringComparison.OrdinalIgnoreCase),$"Snapshot {element.GetProperty("name").GetString()} hash differs");
        }
        return new(
            element.GetProperty("name").GetString()!,
            Convert.ToUInt16(element.GetProperty("pc").GetString()!,16),
            Convert.ToUInt64(element.GetProperty("cycle").GetString()!,16),
            Convert.ToUInt16(element.GetProperty("s").GetString()!,16),
            Convert.ToUInt16(element.GetProperty("u").GetString()!,16),
            Convert.ToUInt16(element.GetProperty("x").GetString()!,16),
            Convert.ToUInt16(element.GetProperty("y").GetString()!,16),
            Convert.ToByte(element.GetProperty("a").GetString()!,16),
            Convert.ToByte(element.GetProperty("b").GetString()!,16),
            ram);
    }

    private static Frame Find(JsonElement[] frames,string name)
    {
        foreach(var frame in frames)if(frame.GetProperty("name").GetString()==name)return ReadFrame(frame);
        throw new InvalidDataException($"Missing captured frame {name}");
    }

    private static JsonElement[] Regions(JsonElement root)=>root.GetProperty("rom_regions").EnumerateArray().ToArray();

    private static byte[] Required(JsonElement[] regions,ushort address,int length)
    {
        foreach(var region in regions){
            int at=region.GetProperty("address").GetInt32();
            byte[] bytes=Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!);
            if(address>=at && address+length<=at+bytes.Length)return bytes[(address-at)..(address-at+length)];
        }
        throw new InvalidDataException($"Missing required ROM region {address:X4}+{length:X}");
    }

    private static void LoadRegions(Machine machine,JsonElement[] regions)
    {
        foreach(var region in regions){
            int address=region.GetProperty("address").GetInt32();
            Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!).CopyTo(machine.Memory,address);
        }
    }

    private static void RequireBytes(Machine machine,ushort address,string expected)
    {
        byte[] bytes=Convert.FromHexString(expected);
        for(int i=0;i<bytes.Length;i++)
            if(machine.Memory[address+i]!=bytes[i])
                throw new InvalidDataException($"ROM {address+i:X4}: expected{bytes[i]:X2}, actual{machine.Memory[address+i]:X2}");
    }

    private static void RequireRom(Machine machine)
    {
        RequireBytes(machine,0x5A14,"34068691C6028DE3");
        RequireBytes(machine,0x59FF,"34061F898DD4");
        RequireBytes(machine,0x59D9,"3416C0602A02CB60D74D8E59EBBD5C18");
        RequireBytes(machine,0x5C18,"BD60C83436");
        RequireBytes(machine,0x5C4F,"35B6");
        RequireBytes(machine,0x59E9,"3596");
    }

    private static void RequireBridgeRom(Machine machine)
    {
        RequireBytes(machine,0x776F,"96F127078A0197F1B7080C3420AD94352096F1270784FE97F1B7080C0EFC");
        RequireBytes(machine,0x80A4,"776F5A14");
        RequireBytes(machine,0xFC4D,"80A4F382");
    }

    private static void Compare(ReadOnlySpan<byte> actual,ReadOnlySpan<byte> expected,string stage)
    {
        Require(actual.Length>=RamSize && expected.Length>=RamSize,$"{stage} size differs");
        for(int address=0;address<RamSize;address++)
            if(actual[address]!=expected[address])
                throw new InvalidDataException($"{stage} {address:X3}: expected{expected[address]:X2}, actual{actual[address]:X2}");
    }

    private static void CompareState(AddersToneSetupState state,Frame expected,string stage)
    {
        Require(state.PC==expected.PC,$"{stage} PC differs");
        Require(state.Cycle==expected.Cycle,$"{stage} cycle {state.Cycle:X} differs from {expected.Cycle:X}");
        Require(state.S==expected.S,$"{stage} S differs");
        Require(state.U==expected.U,$"{stage} U differs");
        Require(state.X==expected.X,$"{stage} X differs");
        Require(state.Y==expected.Y,$"{stage} Y differs");
        Require(state.A==expected.A,$"{stage} A differs");
        Require(state.B==expected.B,$"{stage} B differs");
    }

    private static void CompareForegroundDelta(byte[] from,byte[] to,JsonElement[] delta)
    {
        var expected=new Dictionary<int,(byte From,byte To)>();
        foreach(var item in delta){
            int offset=Convert.ToInt32(item.GetProperty("offset").GetString()!,16);
            byte valueFrom=item.GetProperty("from").GetByte();
            byte valueTo=item.GetProperty("to").GetByte();
            Require(offset==0x4D || (offset>=0x798 && offset<=0x7A9),$"Foreground delta offset {offset:X3} is outside the captured setup ranges");
            expected[offset]=(valueFrom,valueTo);
        }
        Require(expected.Count==16,"Foreground delta count is not16");
        for(int address=0;address<RamSize;address++){
            if(from[address]==to[address])continue;
            if(!expected.TryGetValue(address,out var pair))
                throw new InvalidDataException($"Foreground delta {address:X3} has no captured entry");
            if(from[address]!=pair.From || to[address]!=pair.To)
                throw new InvalidDataException($"Foreground delta {address:X3}: captured {pair.From:X2}->{pair.To:X2}, generated {from[address]:X2}->{to[address]:X2}");
        }
        foreach(var (address,pair) in expected)
            if(from[address]!=pair.From || to[address]!=pair.To)
                throw new InvalidDataException($"Foreground delta {address:X3} captured {pair.From:X2}->{pair.To:X2} was not generated");
    }

    private static int VerifySemantic(JsonElement root,JsonElement bridgeRoot,string? negative)
    {
        Require(root.GetProperty("schema").GetString()=="fresh-tone-occurrence/1","Fresh tone schema differs");
        Require(root.GetProperty("classification").GetString()!.StartsWith("controlled replay natural",StringComparison.Ordinal),"Fresh tone classification differs");
        var source=root.GetProperty("source");
        Require(source.GetProperty("rom_sha1").GetString()=="402D1518BB78FDC489B06C2AABC771E5CE151847","Fresh tone ROM SHA1 differs");
        Require(source.GetProperty("exit").GetInt32()==0,"Fresh tone capture exit differs");
        Require(bridgeRoot.GetProperty("rom_sha1").GetString()==BridgeRomSha1,"Bridge ROM SHA1 differs");

        var primary=root.GetProperty("primary");
        var frames=primary.GetProperty("frames").EnumerateArray().ToArray();
        var markers=primary.GetProperty("markers").EnumerateArray().ToArray();
        var fc4d=Find(frames,"fc4d");
        var queue=Find(frames,"queue");
        var marker14=Find(markers,"foreground-5a14");
        var marker05=Find(markers,"foreground-5a05");
        Require(fc4d.Ram is not null && queue.Ram is not null,"Fresh setup frames are not 2 KB");
        Require(Convert.ToHexString(SHA256.HashData(fc4d.Ram!))==ExpectedFc4dSha256,"Fresh FC4D snapshot differs");
        Require(fc4d.PC==AddersToneSetupExecution.VmEntry,"FC4D VM entry PC differs");
        Require(fc4d.Y==0xFC4D,"FC4D VM entry Y differs");
        Require(marker14.PC==AddersToneSetupExecution.ForegroundEntry,"Foreground5A14 marker PC differs");
        Require(marker05.PC==AddersToneSetupExecution.Foreground5A05,"Foreground5A05 marker PC differs");
        Require(marker05.Cycle-marker14.Cycle==340,"Captured5A14-5A05 span differs");

        var regions=Regions(root);
        if(negative=="missingROM")regions=regions.Where(region=>region.GetProperty("address").GetInt32()!=0x5963).ToArray();
        var bridgeRegions=bridgeRoot.GetProperty("regions").EnumerateArray().ToArray();
        var machine=new Machine();
        try{LoadRegions(machine,regions);LoadRegions(machine,bridgeRegions);RequireRom(machine);RequireBridgeRom(machine);}
        catch(InvalidDataException error)when(negative=="missingROM"){throw new InvalidDataException("missingROM rejected",error);}

        fc4d.Ram!.CopyTo(machine.Memory,0);
        RequireBytes(machine,0x00FC,"AEA16E91");
        machine.Memory[0x719B]=0;

        ushort s=fc4d.S;
        if(negative=="stack")s=AddersToneSetupExecution.MinimumVmEntryStackPointer-1;
        if(negative=="gate")machine.Memory[0x719B]|=0x80;
        if(negative=="ownership")machine.WriteWord(0x47,0x1A0);
        if(negative=="pool")machine.WriteWord(0x49,0);
        if(negative=="poolPointer")machine.WriteWord(0x49,0x1234);
        if(negative=="vmTemplate")machine.Memory[AddersToneSetupExecution.VmEntry]=0;
        if(negative=="vmToken")machine.WriteWord(fc4d.Y,0x80A6);
        if(negative=="vmHeader")machine.WriteWord(AddersToneSetupExecution.VmToken,0x777A);
        if(negative=="vmNative")machine.WriteWord(Cell.Add(AddersToneSetupExecution.VmToken,2),0x5A05);
        if(negative=="bridgeMode")machine.Memory[0xF1]=0x80;
        byte[] before=machine.Memory.ToArray();

        using var sound=new AddersNativeSound(negative=="owner" ? new Machine() : machine);
        if(negative=="servicing")sound.BeginService(0,fc4d.S,fc4d.U,fc4d.X,fc4d.Y,false,0xFECC);
        if(negative=="paused")sound.Pause();
        AddersToneSetupBridgeResult result;
        try{
            result=AddersToneSetupExecution.ExecuteFromVmEntry(sound,machine,fc4d.Cycle,s,fc4d.U,fc4d.X,fc4d.Y,fc4d.A,fc4d.B);
        }
        catch(Exception error)when(negative is "stack" or "gate" or "ownership" or "owner" or "servicing" or "paused" or "pool" or "poolPointer" or "vmTemplate" or "vmToken" or "vmHeader" or "vmNative" or "bridgeMode"){
            Require(before.SequenceEqual(machine.Memory),$"{negative} mutated memory before rejection");
            string? stage=negative switch{
                "stack" when error is ArgumentOutOfRangeException=>"stack",
                "gate" when error is NotSupportedException && error.Message.Contains("719B",StringComparison.Ordinal)=>"gate",
                "ownership" when error is InvalidDataException && error.Message.Contains("already active",StringComparison.Ordinal)=>"ownership",
                "owner" when error is InvalidOperationException && error.Message.Contains("different machine",StringComparison.Ordinal)=>"owner",
                "servicing" when error is InvalidOperationException && error.Message.Contains("service owns",StringComparison.Ordinal)=>"servicing",
                "paused" when error is InvalidOperationException && error.Message.Contains("paused",StringComparison.Ordinal)=>"paused",
                "pool" when error is InvalidDataException && error.Message.Contains("free pool is empty",StringComparison.Ordinal)=>"pool",
                "poolPointer" when error is NotSupportedException && error.Message.Contains("sound task pool",StringComparison.Ordinal)=>"poolPointer",
                "vmTemplate" when error is NotSupportedException && error.Message.Contains("NEXT template",StringComparison.Ordinal)=>"vmTemplate",
                "vmToken" when error is NotSupportedException && error.Message.Contains("token",StringComparison.Ordinal)=>"vmToken",
                "vmHeader" when error is NotSupportedException && error.Message.Contains("80A4 target",StringComparison.Ordinal)=>"vmHeader",
                "vmNative" when error is NotSupportedException && error.Message.Contains("80A4 native",StringComparison.Ordinal)=>"vmNative",
                "bridgeMode" when error is NotSupportedException && error.Message.Contains("F1!=0 mode branch",StringComparison.Ordinal)=>"bridgeMode",
                _=>null};
            if(stage is null)throw;
            throw new InvalidDataException($"{stage} rejected",error);
        }

        Require(result.DispatchCycles==17,$"Source dispatch cost {result.DispatchCycles} differs from17");
        Require(result.BridgeCycles==24,$"Source bridge cost {result.BridgeCycles} differs from24");
        Require(result.DispatchCycles+result.BridgeCycles==marker14.Cycle-fc4d.Cycle,"Bridge span does not reach5A14");
        CompareState(result.VmEntryState,fc4d,"VM entry");
        CompareState(result.Foreground5A14,marker14,"5A14 entry");
        Require(fc4d.Ram![0x7A8]==0xFC && fc4d.Ram[0x7A9]==0x4D,"FC4D pre-entry Y word differs");
        Require(machine.ReadWord(0x7A6)==0x777E,"776F did not push the777E return word");
        Require(machine.ReadWord(0x7A8)==marker14.Y,"776F did not write the caller Y word at07A8/07A9");
        Require(result.Setup.WrapperCycles==67,$"Source wrapper cost {result.Setup.WrapperCycles} differs from67");
        Require(result.Setup.QueueCycles==262,$"Source queue cost {result.Setup.QueueCycles} differs from262");
        Require(result.Setup.ReturnCycles==11,$"Source59E9 cost {result.Setup.ReturnCycles} differs from11");
        Require(result.Setup.Foreground5A05.Cycle-marker14.Cycle==340,"Generated5A14-5A05 span differs");
        CompareState(result.Setup.QueueEntry,queue,"queue entry");
        if(negative=="snapshot")queue.Ram![0x4D]^=0xFF;
        Compare(result.Setup.QueueEntryMemory,queue.Ram!,"queue snapshot");
        CompareForegroundDelta(fc4d.Ram!,result.Setup.QueueEntryMemory,primary.GetProperty("foreground_delta").EnumerateArray().ToArray());
        CompareState(result.Setup.Foreground5A05,marker05,"5A05");
        Require(result.Setup.QueueReturn==AddersToneSetupExecution.QueueContinuation,"Queue continuation differs");

        Require(sound.CompletedCalls==1,"Native owner did not complete exactly one queue call");
        Require(sound.Active,"Native owner did not create the tone task");
        Require(machine.ReadWord(0x47)==0x1A0,"Native queue root differs");
        Require(machine.ReadWord(0x49)==0x1C5,"Native free head differs");
        Require(machine.Memory[0x4D]==0x31,"Foreground59E1 did not write004D");
        Require(machine.Memory[0x719B]==0,"Sound enable changed during the supported path");
        return 1;
    }

    public static int Verify(string evidence)
    {
        using var document=JsonDocument.Parse(File.ReadAllText(FixturePath(evidence)));
        using var bridgeDocument=JsonDocument.Parse(File.ReadAllText(BridgeFixturePath(evidence)));
        return VerifySemantic(document.RootElement,bridgeDocument.RootElement,null);
    }

    public static int VerifyCycles(string evidence)
    {
        using var document=JsonDocument.Parse(File.ReadAllText(FixturePath(evidence)));
        var primary=document.RootElement.GetProperty("primary");
        var markers=primary.GetProperty("markers").EnumerateArray().ToArray();
        var marker14=Find(markers,"foreground-5a14");
        var marker05=Find(markers,"foreground-5a05");
        Require(AddersToneSetupExecution.DispatchCycles==17,"DispatchCycles is not17");
        Require(AddersToneSetupExecution.BridgeBodyCycles==24,"BridgeBodyCycles is not24");
        Require(AddersToneSetupExecution.DispatchCycles+AddersToneSetupExecution.BridgeBodyCycles==41,"Bridge total is not41");
        Require(AddersToneSetupExecution.WrapperCycles==67,"WrapperCycles is not67");
        Require(AddersToneSetupExecution.ReturnCycles==11,"ReturnCycles is not11");
        Require(marker05.Cycle-marker14.Cycle==340,"Captured setup span is not340");
        Require(340-AddersToneSetupExecution.WrapperCycles-AddersToneSetupExecution.ReturnCycles==262,"Captured setup does not leave262 queue cycles");
        return 1;
    }

    // Exact source stack boundary: S=21 is rejected before any write, while S=22
    // reaches the deepest BSR5C51 frame and confines it to addresses0/1.
    public static int VerifyStackBoundary(string evidence)
    {
        using var document=JsonDocument.Parse(File.ReadAllText(FixturePath(evidence)));
        var root=document.RootElement;
        var primary=root.GetProperty("primary");
        var frames=primary.GetProperty("frames").EnumerateArray().ToArray();
        var markers=primary.GetProperty("markers").EnumerateArray().ToArray();
        var fc4d=Find(frames,"fc4d");
        var marker14=Find(markers,"foreground-5a14");
        Require(fc4d.Ram is not null,"FC4D stack-boundary frame is not2 KB");
        var regions=Regions(root);

        Machine Build()
        {
            var machine=new Machine();
            LoadRegions(machine,regions);
            RequireRom(machine);
            fc4d.Ram!.CopyTo(machine.Memory,0);
            machine.Memory[0x719B]=0;
            return machine;
        }

        var below=Build();
        byte[] before=below.Memory.ToArray();
        bool rejected=false;
        using(var sound=new AddersNativeSound(below)){
            try{AddersToneSetupExecution.Execute(sound,below,marker14.Cycle,AddersToneSetupExecution.MinimumStackPointer-1,marker14.U,marker14.X,marker14.Y,marker14.A,marker14.B);}
            catch(ArgumentOutOfRangeException error)when(error.ParamName=="s"){rejected=true;}
        }
        Require(rejected,"S21 was not rejected by the setup preflight");
        Require(before.SequenceEqual(below.Memory),"S21 rejection mutated memory");

        var minimum=Build();
        minimum.Memory[0]=0xAA;minimum.Memory[1]=0xBB;
        AddersToneSetupResult result;
        bool active,called;
        using(var sound=new AddersNativeSound(minimum)){
            result=AddersToneSetupExecution.Execute(sound,minimum,marker14.Cycle,AddersToneSetupExecution.MinimumStackPointer,marker14.U,marker14.X,marker14.Y,marker14.A,marker14.B);
            active=sound.Active;called=sound.CompletedCalls==1;
        }
        Require(AddersToneSetupExecution.MinimumStackPointer==22,"Setup minimum stack is no longer22");
        Require(result.QueueEntry.S==8,"S22 queue entry S is not8");
        Require(result.Foreground5A05.S==16,"S22 final S is not16");
        Require(result.Foreground5A05.PC==AddersToneSetupExecution.Foreground5A05,"S22 did not return to5A05");
        Require(minimum.Memory[0]==0x5C && minimum.Memory[1]==0x21,"S22 deepest BSR word was not confined to0/1");
        Require(active && called,"S22 did not create the native tone task");
        return 1;
    }

    public static int Rejects(string evidence,string kind)
    {
        Require(Verify(evidence)==1,"Setup baseline did not pass before a negative mutation");
        using var document=JsonDocument.Parse(File.ReadAllText(FixturePath(evidence)));
        using var bridgeDocument=JsonDocument.Parse(File.ReadAllText(BridgeFixturePath(evidence)));
        try{VerifySemantic(document.RootElement,bridgeDocument.RootElement,kind);}
        catch(InvalidDataException error){
            if(!error.Message.Contains(kind,StringComparison.Ordinal))
                throw new InvalidDataException($"Setup negative {kind} rejected at unexpected stage '{error.Message}'",error);
            return 1;
        }
        throw new InvalidDataException($"Setup negative {kind} was accepted");
    }
}

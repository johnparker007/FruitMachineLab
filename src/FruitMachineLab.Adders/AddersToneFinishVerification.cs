using System.Security.Cryptography;
using System.Text.Json;
using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

public static class AddersToneFinishVerification
{
    private const int RamSize=0x800;
    private const string ExpectedCapture36Sha256="AC60AC5EDE6A962B1FB90DFB8389EF85C6AFE304A25DD24CC7C753A2F59FDB82";
    private const string ExpectedRegionsSha256="DD5DFDCE3E44B51944180A9CB5A5DC84A11D917C3BFD7C301DD8F33F7F40E864";
    private static string FixturePath(string evidence)=>Path.Combine(evidence,"collection","matched-service-window-capture36.json");
    private static string RegionPath(string evidence)=>Path.Combine(evidence,"collection","native-service-rom-regions-capture36.json");
    private static void Require(bool condition,string message){if(!condition)throw new InvalidDataException(message);}
    private static ushort U16(JsonElement element,string name)=>Convert.ToUInt16(element.GetProperty(name).GetString()!,16);
    private static ulong U64(JsonElement element,string name)=>Convert.ToUInt64(element.GetProperty(name).GetString()!,16);
    private static byte U8(JsonElement element,string name)=>Convert.ToByte(element.GetProperty(name).GetString()!,16);
    private static byte[] Ram(JsonElement element)=>Convert.FromHexString(element.GetProperty("ram_hex").GetString()!);
    private static JsonElement[] Regions(JsonElement root)=>root.GetProperty("regions").EnumerateArray().ToArray();
    private static JsonElement FindEvent(JsonElement root,string tag)=>root.GetProperty("occurrence").GetProperty("event_window").EnumerateArray().First(item=>item.GetProperty("tag").GetString()==tag);

    private static bool HasRegion(JsonElement[] regions,ushort address,int length)
    {
        foreach(var region in regions){
            int at=region.GetProperty("address").GetInt32();
            int size=region.GetProperty("bytes").GetInt32();
            if(address>=at && address+length<=at+size)return true;
        }
        return false;
    }

    private static void LoadRegions(Machine machine,JsonElement[] regions)
    {
        Require(HasRegion(regions,0x5A0A,8),"Missing required ROM region 5963");
        Require(HasRegion(regions,0x5C7A,0x1C),"Missing required ROM region 5C18");
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
        RequireBytes(machine,0x5A0A,"8E59EB");
        RequireBytes(machine,0x5A0D,"BD5C7A");
        RequireBytes(machine,0x5A10,"0F4D");
        RequireBytes(machine,0x5A12,"3586");
        RequireBytes(machine,0x5C7A,"BD60C8");
        RequireBytes(machine,0x5C7D,"3436");
        RequireBytes(machine,0x5C95,"35B6");
        RequireBytes(machine,0x5E2C,"3440");
        RequireBytes(machine,0x5E6B,"35C0");
        RequireBytes(machine,0x60AB,"3410");
        RequireBytes(machine,0x60BD,"3590");
        RequireBytes(machine,0x60C8,"3404");
        RequireBytes(machine,0x60D1,"3584");
    }

    private static void Compare(ReadOnlySpan<byte> actual,ReadOnlySpan<byte> expected,string stage)
    {
        Require(actual.Length>=RamSize && expected.Length>=RamSize,$"{stage} size differs");
        for(int address=0;address<RamSize;address++)
            if(actual[address]!=expected[address])
                throw new InvalidDataException($"{stage} {address:X3}: expected{expected[address]:X2}, actual{actual[address]:X2}");
    }

    // Capture36 retains PC/cycle/S/U/X/Y/A/B but not DP or CC. Only those
    // captured registers are compared; flags are checked separately below.
    private static void CompareState(AddersToneFinishState state,JsonElement expected,string stage)
    {
        Require(state.PC==U16(expected,"pc"),$"{stage} PC differs");
        Require(state.Cycle==U64(expected,"cycle"),$"{stage} cycle {state.Cycle:X} differs from {U64(expected,"cycle"):X}");
        Require(state.S==U16(expected,"s"),$"{stage} S differs");
        Require(state.U==U16(expected,"u"),$"{stage} U differs");
        Require(state.X==U16(expected,"x"),$"{stage} X differs");
        Require(state.Y==U16(expected,"y"),$"{stage} Y differs");
        Require(state.A==U8(expected,"a"),$"{stage} A differs");
        Require(state.B==U8(expected,"b"),$"{stage} B differs");
    }

    private static int VerifySemantic(JsonElement root,JsonElement regionRoot,string? negative=null)
    {
        Require(root.GetProperty("schema").GetString()=="matched-service-window-capture36/1","Matched service schema differs");
        var occurrence=root.GetProperty("occurrence");
        var anchors=occurrence.GetProperty("anchors");
        var start=FindEvent(root,"5a0a");
        var cancel=anchors.GetProperty("cancel");
        var ret10=anchors.GetProperty("return_5a10");
        var ret1c=anchors.GetProperty("return_5a1c");
        byte[] expected10=Ram(ret10),expected1c=Ram(ret1c);
        var regions=Regions(regionRoot);
        if(negative=="missingROM")regions=regions.Where(region=>region.GetProperty("address").GetInt32()!=0x5963).ToArray();
        var machine=new Machine();
        try{LoadRegions(machine,regions);RequireRom(machine);}
        catch(InvalidDataException error)when(negative=="missingROM")
        {throw new InvalidDataException("missingROM rejected",error);}

        Ram(cancel).CopyTo(machine.Memory,0);
        ushort s=U16(start,"s");
        if(negative=="stack")s=AddersToneFinishExecution.MinimumStackPointer-1;
        if(negative=="return")machine.WriteWord(Cell.Add(s,2),0x1234);
        if(negative=="gate")machine.Memory[0x719B]|=0x80;
        if(negative=="ownership")machine.WriteWord(0x1A0+0x13,0x1234);
        byte[] before=machine.Memory.ToArray();
        using var sound=negative=="owner" ? new AddersNativeSound(new Machine()) : new AddersNativeSound(machine);
        AddersToneFinishResult result;
        try{
            // The fixture retains no entry CC, so no captured/synthetic CC is
            // supplied here. LDX N/Z/V are still known; everything after the
            // native cancel stays explicitly unknown until the CLR bits.
            result=AddersToneFinishExecution.Execute(sound,machine,U64(start,"cycle"),s,U16(start,"y"),U16(start,"u"),U8(start,"a"),U8(start,"b"),null);
        }
        catch(Exception error)when(negative is "stack" or "return" or "gate" or "ownership" or "owner"){
            Require(before.SequenceEqual(machine.Memory),$"{negative} mutated memory before rejection");
            string? stage=negative switch{
                "stack" when error is ArgumentOutOfRangeException=>"stack",
                "return" when error is InvalidDataException && error.Message.Contains("5A12 return word",StringComparison.Ordinal)=>"return",
                "gate" when error is NotSupportedException && error.Message.Contains("719B",StringComparison.Ordinal)=>"gate",
                "ownership" when error is InvalidDataException && error.Message.Contains("no 59EB root",StringComparison.Ordinal)=>"ownership",
                "owner" when error is InvalidOperationException && error.Message.Contains("different machine",StringComparison.Ordinal)=>"owner",
                _=>null};
            if(stage is null)throw;
            throw new InvalidDataException($"{stage} rejected",error);
        }

        ulong expected10Cycle=negative=="cycle" ? U64(ret10,"cycle")+1 : U64(ret10,"cycle");
        Require(result.CancelState.Cycle==expected10Cycle,$"5A10 cycle {result.CancelState.Cycle:X} differs from {expected10Cycle:X}");
        CompareState(result.CancelState,ret10,"5A10");
        if(negative=="snapshot")expected10[0x294]^=0xFF;
        Compare(result.CancelMemory,expected10,"5A10 snapshot");
        Require(result.CancelState.Cycle-U64(start,"cycle")==U64(ret10,"cycle")-U64(start,"cycle"),"5A10 span differs");
        Require(result.FinalState.Cycle==U64(ret1c,"cycle"),"5A1C cycle differs");
        CompareState(result.FinalState,ret1c,"5A1C");
        Require(result.LdxFlags.KnownMask==0x0E && result.LdxFlags.Value==0,"5A0A LDX #59EB known N/Z/V flags differ");
        Require(result.CancelFlags.KnownMask==0,"5C7A native cancel flags must be explicitly unknown");
        Require(result.FinalFlags.KnownMask==0x0F && result.FinalFlags.Value==0x04,"5A10 CLR known condition flags must be N0 Z1 V0 C0");
        Require(result.DpSourcePreserved,"5C7A/5E2C source contracts must preserve DP");
        Require(result.FinalState.S==Cell.Add(result.CancelState.S,4),"5A12 S is not cancel S+4");
        if(negative=="final")expected1c[0x4D]^=0xFF;
        Compare(machine.Memory.AsSpan(0,RamSize),expected1c,"final 5A1C snapshot");
        Require(sound.LastAddress==AddersToneFinishExecution.CancelContinuation,"5C7A continuation differs");
        Require(!sound.Active,"5C7A did not release the active tone");
        Require(machine.ReadWord(0x49)==0x1A0,"5C7A free-list head differs");
        Require(machine.Memory[0x4D]==0,"5A10 did not clear004D");
        return 1;
    }

    // Source-semantics controls for LDX/CLR and the 16-byte maximum native
    // depth. These deliberately do not invent captured DP/CC values.
    private static int VerifyFlagsAndStack(JsonElement root,JsonElement regionRoot)
    {
        var regions=Regions(regionRoot);
        var start=FindEvent(root,"5a0a");
        var anchors=root.GetProperty("occurrence").GetProperty("anchors");
        byte[] cancelRam=Ram(anchors.GetProperty("cancel"));
        AddersToneFinishResult Run(byte? entryCc,ushort? stack=null)
        {
            var machine=new Machine();
            LoadRegions(machine,regions);
            RequireRom(machine);
            cancelRam.CopyTo(machine.Memory,0);
            ushort s=stack ?? U16(start,"s");
            if(stack is not null)machine.WriteWord(Cell.Add(s,2),AddersToneFinishExecution.Continuation);
            using var sound=new AddersNativeSound(machine);
            return AddersToneFinishExecution.Execute(sound,machine,U64(start,"cycle"),s,U16(start,"y"),U16(start,"u"),U8(start,"a"),U8(start,"b"),entryCc);
        }

        var carried=Run(0xCB);
        Require(carried.LdxFlags.KnownMask==0xFF,"LDX flags are not fully known with an explicit entry CC");
        Require(carried.LdxFlags.IsKnown(0x0E) && (carried.LdxFlags.Value&0x0E)==0,"LDX #59EB did not clear N/Z/V");
        Require((carried.LdxFlags.Value&0x01)!=0,"LDX did not preserve entry C=1");
        Require((carried.LdxFlags.Value&0xF0)==(0xCB&0xF0),"LDX did not preserve H/I/F/E");
        Require((carried.LdxFlags.Value&0x0E)==0 && carried.LdxFlags.Value==0xC1,"LDX #59EB CC differs from C1 for entry CB");
        Require(carried.CancelFlags.KnownMask==0,"Native 5C7A cancel flags are not explicitly unknown");
        Require(carried.FinalFlags.KnownMask==0x0F,"CLR did not expose exactly N/Z/V/C");
        Require(carried.FinalFlags.Value==0x04,"CLR did not leave N0 Z1 V0 C0");
        Require((carried.FinalFlags.Value&0x01)==0,"CLR with entry C=1 did not clear C");
        Require((carried.FinalFlags.KnownMask&0xF0)==0,"CLR claimed H/I/F/E after a native cancel with no CC model");

        var cleared=Run(0xC4);
        Require(cleared.FinalFlags.Value==0x04,"CLR with entry C=0 changed known condition flags");
        Require((cleared.FinalFlags.Value&0x01)==0,"CLR with entry C=0 did not leave C=0");
        var allSet=Run(0xFF);
        Require(allSet.FinalFlags.Value==0x04,"CLR known bits depended on the entry CC");
        var unknown=Run(null);
        Require(unknown.LdxFlags.KnownMask==0x0E && unknown.LdxFlags.Value==0,"LDX known N/Z/V bits with no entry CC differ");
        Require(unknown.FinalFlags.KnownMask==0x0F && unknown.FinalFlags.Value==0x04,"CLR known bits with no entry CC differ");

        var minimum=Run(null,AddersToneFinishExecution.MinimumStackPointer);
        Require(AddersToneFinishExecution.MinimumStackPointer==16,"Native cancel minimum stack is no longer 16");
        Require(minimum.CancelState.S==AddersToneFinishExecution.MinimumStackPointer,"Minimum-stack 5A10 S differs");
        Require(minimum.FinalState.S==AddersToneFinishExecution.MinimumStackPointer+4,"Minimum-stack 5A1C S differs");
        Require(minimum.FinalState.PC==AddersToneFinishExecution.Continuation,"Minimum-stack 5A1C PC differs");
        Require(minimum.DpSourcePreserved,"Minimum-stack run lost the source DP contract");
        return 1;
    }

    public static int VerifyFlagsAndStack(string evidence)
    {
        using var document=JsonDocument.Parse(File.ReadAllText(FixturePath(evidence)));
        using var regionDocument=JsonDocument.Parse(File.ReadAllText(RegionPath(evidence)));
        return VerifyFlagsAndStack(document.RootElement,regionDocument.RootElement);
    }

    public static int Verify(string evidence)
    {
        string fixture=FixturePath(evidence),regionPath=RegionPath(evidence);
        Require(FixtureIntegrity.MatchesPinnedHash(fixture,ExpectedCapture36Sha256),"Matched service fixture hash differs");
        Require(FixtureIntegrity.MatchesPinnedHash(regionPath,ExpectedRegionsSha256),"ROM region fixture hash differs");
        using var document=JsonDocument.Parse(File.ReadAllText(fixture));
        using var regionDocument=JsonDocument.Parse(File.ReadAllText(regionPath));
        return VerifySemantic(document.RootElement,regionDocument.RootElement);
    }

    public static int VerifySemanticForTests(string evidence,string? negative=null)
    {
        using var document=JsonDocument.Parse(File.ReadAllText(FixturePath(evidence)));
        using var regionDocument=JsonDocument.Parse(File.ReadAllText(RegionPath(evidence)));
        return VerifySemantic(document.RootElement,regionDocument.RootElement,negative);
    }

    public static int Rejects(string evidence,string kind)
    {
        Require(Verify(evidence)==1,"Tone finish baseline did not pass before a negative mutation");
        try{VerifySemanticForTests(evidence,kind);}
        catch(InvalidDataException error){
            if(!error.Message.Contains(kind,StringComparison.Ordinal))
                throw new InvalidDataException($"Tone finish negative {kind} rejected at unexpected stage '{error.Message}'",error);
            return 1;
        }
        throw new InvalidDataException($"Tone finish negative {kind} was accepted");
    }
}

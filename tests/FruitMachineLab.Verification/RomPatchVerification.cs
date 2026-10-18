using System.Security.Cryptography;
using FruitMachineLab.Adders;
using FruitMachineLab.Runtime;

internal static class RomPatchVerification
{
    private static byte[] Source() => Enumerable.Range(0, 256).Select(i => (byte)i).ToArray();
    private static RomPatchSpec Spec(byte[] source) => new() {
        SchemaVersion = 1, Description = "Synthetic patch safety experiment", InputLength = source.Length,
        InputSha1 = Convert.ToHexString(SHA1.HashData(source)),
        Edits = [new() { Offset = 10, ExpectedHex = "0A0B", ReplacementHex = "0C0D", Provenance = "Synthetic input" }]
    };
    private static void Assert(bool condition) { if (!condition) throw new Exception("ROM patch assertion failed"); }
    private static void Reject(Action action)
    {
        try { action(); } catch (InvalidDataException) { return; }
        throw new Exception("Unsafe patch was accepted");
    }
    public static void Preservation()
    {
        byte[] source = Source(), before = source.ToArray(); var spec = Spec(source);
        var a = RomPatch.Apply(source, spec); var b = RomPatch.Apply(source, spec);
        Assert(source.SequenceEqual(before) && a.Image.SequenceEqual(b.Image) && a.OutputSha256 == b.OutputSha256);
        Assert(a.ChangedOffsets.SequenceEqual(new[] {10, 11}) && a.Image[10] == 12 && a.Image[11] == 13);
        Assert(a.Image.Where((_, i) => i != 10 && i != 11).SequenceEqual(before.Where((_, i) => i != 10 && i != 11)));
        Assert(a.InputSha256 == Convert.ToHexString(SHA256.HashData(before)));
        // A valid first edit must not mutate the source when a later edit fails.
        Reject(() => RomPatch.Apply(source, spec with { Edits = [spec.Edits[0], spec.Edits[0] with { Offset = 20 }] }));
        Assert(source.SequenceEqual(before));
    }
    public static void Rejections()
    {
        byte[] source = Source(); var spec = Spec(source); var edit = spec.Edits[0];
        Reject(() => RomPatch.Apply(source.AsSpan(1), spec));
        Reject(() => RomPatch.Apply(source, spec with { InputSha1 = new string('0',40) }));
        Reject(() => RomPatch.Apply(source, spec with { InputSha1 = "GG" }));
        Reject(() => RomPatch.Apply(source, spec with { SchemaVersion = 2 }));
        Reject(() => RomPatch.Apply(source, spec with { Edits = [] }));
        foreach (var invalid in new[] {
            edit with { ExpectedHex = "FFFF" }, edit with { Offset = -1 }, edit with { Offset = int.MaxValue },
            edit with { Offset = 255 }, edit with { ReplacementHex = "01" }, edit with { ReplacementHex = "ZZZZ" },
            edit with { ExpectedHex = "", ReplacementHex = "" }, edit with { Provenance = "" }
        }) Reject(() => RomPatch.Apply(source, spec with { Edits = [invalid] }));
        Reject(() => RomPatch.Apply(source, spec with { Edits = [edit, edit with { Offset = 11, ExpectedHex = "0B0C" }] }));
        try { RomPatchSpec.Parse("{\"SchemaVersion\":1,\"Typo\":1}"); }
        catch (System.Text.Json.JsonException) { return; }
        throw new Exception("Malformed patch JSON accepted");
    }
    private static RomPatchSpec Example(string evidence) => RomPatchSpec.Parse(File.ReadAllText(Path.Combine(evidence,"patches","skill-cash-level1-12.json")));
    public static void Provenance(string evidence)
    {
        var spec = Example(evidence);
        using var map = System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"maps","skill-cash-rom-data.json")));
        Assert(spec.InputSha1 == map.RootElement.GetProperty("rom_sha1").GetString());
        byte[] table = map.RootElement.GetProperty("tables").GetProperty("75BD").GetProperty("bytes").EnumerateArray().Select(x=>x.GetByte()).ToArray();
        Assert(spec.InputLength == 65536 && spec.Edits.Length == 1 && spec.Edits[0].Offset == 0x75BD);
        Assert(Convert.FromHexString(spec.Edits[0].ExpectedHex).SequenceEqual(table));
    }
    public static void Execution(string evidence)
    {
        // Synthetic full-sized image, NOT the original ROM. The shipped spec's identity
        // stays strict; only this test substitutes a synthetic identity explicitly.
        var spec = Example(evidence); byte[] source = new byte[65536];
        Convert.FromHexString(spec.Edits[0].ExpectedHex).CopyTo(source, 0x75BD);
        spec = spec with { InputSha1 = Convert.ToHexString(SHA1.HashData(source)) };
        var patched = RomPatch.Apply(source, spec);
        foreach (var image in new[] {source, patched.Image})
        {
            var m = new Machine(); image.CopyTo(m.Memory, 0); m.LocalFrame = 0x500; m.Memory[0x501] = 1;
            var script = new RecoveredScript(Path.Combine(evidence,"VM-SCRIPTS","C6FC.txt"));
            new ScriptExecutor(m).RunRange(script, 0xC6FE, 0xC706);
            ushort expected = ReferenceEquals(image, source) ? (ushort)10 : (ushort)12;
            Assert(m.Pop() == expected && m.Data.Count == 0);
            m.Memory[0x160] = m.Memory[0x162] = m.Memory[0x164] = 1;
            Assert(AddersNudgeAvailability.Lookup(m) == expected);
        }
        Assert(patched.ChangedOffsets.SequenceEqual(new[] {0x75BE}));
    }
}

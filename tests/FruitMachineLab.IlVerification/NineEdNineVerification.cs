using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using FruitMachineLab.Il;

namespace FruitMachineLab.IlVerification;

internal sealed record VerificationCheck(string Name, bool Passed, string? Error);

internal sealed record VerificationReport(
    string TaskId,
    int SchemaVersion,
    string Status,
    string Classification,
    string EvidenceClass,
    string RomPath,
    int RomLength,
    string RomSha1Before,
    string RomSha256Before,
    string RomSha1After,
    string RomSha256After,
    bool InputUnchanged,
    string EmittedSpanHex,
    int[] ChangedOffsets,
    string EditedSpanHex,
    string EditedOutputSha1,
    string EditedOutputSha256,
    int[] EditedChangedOffsets,
    string SourceMapRomSha256,
    string SourceMapImageSha256,
    bool SourceMapIsIdentity,
    int SourceMapSpanBytes,
    int SourceMapEntries,
    string EditedSourceMapImageSha256,
    int EditedSourceMapEntries,
    string IntegrityOriginalFieldsHex,
    string IntegrityUnrepairedFieldsHex,
    string IntegrityRepairedFieldsHex,
    string IntegrityAlgorithmOrder,
    string RepairedOutputSha1,
    string RepairedOutputSha256,
    int[] RepairedChangedOffsets,
    int[] RepairChangedOffsets,
    string RepairedSourceMapImageSha256,
    string[] IlAssemblyReferences,
    string[] VerifierAssemblyReferences,
    IReadOnlyList<VerificationCheck> Checks,
    IReadOnlyList<string> Limitations,
    string RemainingChainBoundary);

internal static class VerificationOutputs
{
    public static void WriteCreateOnly(string path, string content)
    {
        using var stream = new FileStream(
            path, FileMode.CreateNew, FileAccess.Write, FileShare.None);
        using var writer = new StreamWriter(stream, new UTF8Encoding(false));
        writer.Write(content);
    }
}

internal static class NineEdNineVerification
{
    private const string ExpectedSpanHex = "795BFF80787E795BFF807AAF792F";
    private const string ExpectedSpanSha256 =
        "A7BEC73F18CB7B8937768DE2BC6EC56DC1B98C2EC61C136F2B979153CF56AD77";
    private const string ExpectedEditedSpanHex = "795BFF00787E795BFF807AAF792F";
    private const string ExpectedEditedSha1 = "51E81CC5F41DA2AA659A4D14D277E9E78614EB6B";
    private const string ExpectedEditedSha256 =
        "A99D96F8EA8B4770D2D3828125F25894E831726FE44A79A37E0871FABA135ED2";
    private const string ExpectedOriginalFieldsHex = "3E761E2605";
    private const string ExpectedUnorderedFieldsHex = "BEF69D36ED";
    private const string ExpectedRepairedFieldsHex = "BEF69E7CC7";
    private const string ExpectedRepairedSha1 = "E1A42DCCD304B7B175AABAC99E8400CDAD04CF69";
    private const string ExpectedRepairedSha256 =
        "577F76BD36DFCA04DFB01B5F5D0BE93E16572F8617C7CA906397C98DF36E5107";

    private static readonly (ushort Address, ushort Token, string Operation, ushort? Literal)[]
        ExpectedNodes =
        {
            (0x9ED9, 0x795B, "vm_push_inline_word_literal", 0xFF80),
            (0x9EDD, 0x787E, "vm_add_words", null),
            (0x9EDF, 0x795B, "vm_push_inline_word_literal", 0xFF80),
            (0x9EE3, 0x7AAF, "vm_bitwise_xor", null),
            (0x9EE5, 0x792F, "vm_return_to_caller_stream", null)
        };

    public static VerificationReport Run(string romPath, string repositoryRoot, string outputDirectory)
    {
        if (Directory.Exists(outputDirectory))
            throw new IOException($"Output directory already exists: {outputDirectory}");

        byte[] rom = File.ReadAllBytes(romPath);
        string beforeSha1 = Convert.ToHexString(SHA1.HashData(rom));
        string beforeSha256 = Convert.ToHexString(SHA256.HashData(rom));
        var checks = new List<VerificationCheck>();
        VmIlDefinition definition = null!;
        VmIlCompileResult compile = null!;
        VmIlSourceMap map = null!;
        VmIlEditCompileResult edited = null!;
        VmIlSourceMap editedMap = null!;
        VmIlRepairedEditCompileResult repairedBuild = null!;
        VmIlSourceMap repairedMap = null!;
        string[] ilReferences = Array.Empty<string>();
        string[] verifierReferences = Array.Empty<string>();

        void Assert(bool condition, string message)
        {
            if (!condition) throw new InvalidDataException(message);
        }

        void Reject(Action action, string expected)
        {
            try
            {
                action();
            }
            catch (Exception error) when (error is InvalidDataException or IOException or
                                          KeyNotFoundException or ArgumentException or
                                          NotSupportedException or InvalidOperationException)
            {
                Assert(error.Message.Contains(expected, StringComparison.OrdinalIgnoreCase),
                    $"Expected rejection containing '{expected}', got '{error.Message}'");
                return;
            }
            throw new InvalidDataException(
                $"Unsafe input was accepted; expected rejection containing '{expected}'");
        }

        void Check(string name, Action action)
        {
            try
            {
                action();
                checks.Add(new VerificationCheck(name, true, null));
                Console.WriteLine("PASS " + name);
            }
            catch (Exception error)
            {
                checks.Add(new VerificationCheck(name, false, error.Message));
                throw new InvalidOperationException($"Check failed: {name}: {error.Message}", error);
            }
        }

        string EvidencePath(params string[] parts) =>
            Path.Combine(new[] { repositoryRoot, "evidence", "mpu4" }.Concat(parts).ToArray());

        try
        {
            Check("Original ROM identity header and five nodes decode from actual bytes", () =>
            {
                Assert(rom.Length == NineEdNineDecoder.RequiredRomLength, "ROM length differs");
                Assert(beforeSha1 == NineEdNineDecoder.RequiredRomSha1, "ROM SHA1 differs");
                Assert(beforeSha256 == NineEdNineDecoder.RequiredRomSha256, "ROM SHA256 differs");

                definition = NineEdNineDecoder.Decode(rom);
                Assert(definition.RomLength == rom.Length, "Definition ROM length differs");
                Assert(definition.RomSha1 == beforeSha1, "Definition SHA1 differs");
                Assert(definition.RomSha256 == beforeSha256, "Definition SHA256 differs");
                Assert(definition.HeaderAddress == 0x9ED7, "Header address differs");
                Assert(Convert.ToHexString(definition.HeaderBytes) == "00F8", "Header value differs");
                Assert(definition.BodyStart == 0x9ED9, "Body start differs");
                Assert(definition.BodyEndExclusive == 0x9EE7, "Definition end differs");
                Assert(definition.BodyLength == 14, "Definition length differs");
                Assert(definition.Nodes.Count == ExpectedNodes.Length, "Node count differs");

                for (int index = 0; index < ExpectedNodes.Length; index++)
                {
                    var expected = ExpectedNodes[index];
                    VmIlNode node = definition.Nodes[index];
                    Assert(node.Index == index, $"Node {index} index differs");
                    Assert(node.Address == expected.Address, $"Node {index} address differs");
                    Assert(node.Token == expected.Token, $"Node {index} token differs");
                    Assert(node.Operation == expected.Operation, $"Node {index} operation differs");
                    Assert(node.EvidenceClass == VmIlEvidenceClass.OriginalRomBytes,
                        $"Node {index} evidence class differs");
                    Assert(node.Bytes.SequenceEqual(
                            rom.AsSpan(node.Address, node.Bytes.Length).ToArray()),
                        $"Node {index} bytes differ from the ROM");
                    if (expected.Literal is ushort literal)
                    {
                        VmIlOperand operand = node.Operand ??
                            throw new InvalidDataException($"Node {index} operand is missing");
                        Assert(operand.Address == node.Address + 2,
                            $"Node {index} operand address differs");
                        Assert(operand.Bytes.SequenceEqual(
                                rom.AsSpan(operand.Address, 2).ToArray()),
                            $"Node {index} operand bytes differ from the ROM");
                        Assert(operand.Value == literal, $"Node {index} operand value differs");
                    }
                    else
                    {
                        Assert(node.Operand is null, $"Node {index} unexpectedly has an operand");
                    }
                }

                Assert(Convert.ToHexString(rom.AsSpan(0x9ED9, 14)) == ExpectedSpanHex,
                    "Original span bytes differ");
                Assert(definition.Provenance.ObservedSites == 5,
                    "Definition observed-site count differs");
            });

            Check("Cited listing checkpoint caller invocation and paid-window provenance agree", () =>
            {
                string definitionPath = EvidencePath(
                    "definitions", "bias-word-signed-value-9ed9.vm.json");
                using var definitionJson = JsonDocument.Parse(File.ReadAllText(definitionPath));
                JsonElement definitionRoot = definitionJson.RootElement;
                Assert(definitionRoot.GetProperty("Address").GetString() == "9ED9",
                    "Curated definition address differs");
                Assert(definitionRoot.GetProperty("OriginalSpanHex").GetString() == ExpectedSpanHex,
                    "Curated definition span differs");
                Assert(definitionRoot.GetProperty("OriginalSpanSha256").GetString() ==
                       ExpectedSpanSha256, "Curated definition span hash differs");
                Assert(definitionRoot.GetProperty("RomSha1").GetString() ==
                       NineEdNineDecoder.RequiredRomSha1, "Curated definition SHA1 differs");
                Assert(Convert.ToHexString(SHA256.HashData(rom.AsSpan(0x9ED9, 14))) ==
                       ExpectedSpanSha256, "Actual span hash differs from the cited hash");
                Assert(definitionRoot.GetProperty("Provenance").GetProperty("ObservedSites").GetInt32() == 5,
                    "Curated observed-site count differs");

                string listingPath = EvidencePath("VM-SCRIPTS", "9ED9.txt");
                string listing = File.ReadAllText(listingPath);
                Assert(MatchesPinnedHash(listingPath, NineEdNineDecoder.ListingSha256),
                    "9ED9 listing hash does not match its cited pin");
                string[] listingLines = listing.Split('\n');
                foreach (var expected in ExpectedNodes)
                {
                    bool found = listingLines.Any(line =>
                    {
                        string[] parts = line.Trim().Split(
                            (char[]?)null, StringSplitOptions.RemoveEmptyEntries);
                        if (parts.Length < 3 || parts[0] != "*" ||
                            parts[1] != expected.Address.ToString("X4") ||
                            parts[2] != expected.Token.ToString("X4") ||
                            !parts.Contains(expected.Operation))
                            return false;
                        return expected.Literal is not ushort literal ||
                               line.Contains($"inline_value=0x{literal:X4}",
                                   StringComparison.OrdinalIgnoreCase);
                    });
                    Assert(found, $"Listing line for {expected.Address:X4} is missing or differs");
                }
                int observed = listingLines.Count(line =>
                {
                    string[] parts = line.Trim().Split(
                        (char[]?)null, StringSplitOptions.RemoveEmptyEntries);
                    return parts.Length >= 2 && parts[0] == "*" &&
                           ExpectedNodes.Any(node => parts[1] == node.Address.ToString("X4"));
                });
                Assert(observed == 5, "Listing does not mark exactly five target sites observed");

                string caller = File.ReadAllText(EvidencePath("VM-SCRIPTS", "EBB8.txt"));
                Assert(caller.Split('\n').Any(line =>
                        line.Contains("9ED7", StringComparison.Ordinal) &&
                        line.Contains("body=0x9ED9", StringComparison.OrdinalIgnoreCase)),
                    "Natural caller EBB8 does not cite header 9ED7 with body 9ED9");

                using var checkpointJson = JsonDocument.Parse(
                    File.ReadAllText(EvidencePath("maps", "nudge-encoding-checkpoint.json")));
                JsonElement region = checkpointJson.RootElement.GetProperty("vm")
                    .EnumerateArray()
                    .Single(row => row.GetProperty("listing").GetString() ==
                                   "VM-SCRIPTS/9ED9.txt");
                Assert(region.GetProperty("start").GetString() == "9ED9",
                    "Checkpoint start differs");
                Assert(region.GetProperty("end_exclusive").GetString() == "9EE7",
                    "Checkpoint end differs");
                Assert(region.GetProperty("span_hex").GetString() == ExpectedSpanHex,
                    "Checkpoint span differs");

                using var invocationJson = JsonDocument.Parse(File.ReadAllText(
                    EvidencePath("collection", "vm-definition-9ed9-invocation.json")));
                JsonElement invocationRoot = invocationJson.RootElement;
                JsonElement original = invocationRoot.GetProperty("source")
                    .GetProperty("original_rom");
                Assert(original.GetProperty("length").GetInt32() == 65536,
                    "Invocation original length differs");
                Assert(original.GetProperty("sha1").GetString() ==
                       NineEdNineDecoder.RequiredRomSha1.ToLowerInvariant(),
                    "Invocation original SHA1 differs");
                Assert(original.GetProperty("sha256").GetString() ==
                       NineEdNineDecoder.RequiredRomSha256.ToLowerInvariant(),
                    "Invocation original SHA256 differs");
                Assert(original.GetProperty("span").GetString() == ExpectedSpanHex,
                    "Invocation original span differs");
                Assert(invocationRoot.GetProperty("case_count").GetInt32() == 10,
                    "Invocation case count differs");
                Assert(invocationRoot.GetProperty("classification").GetString()!
                        .Contains("Synthetic", StringComparison.OrdinalIgnoreCase),
                    "Invocation evidence is not classified as synthetic");

                using var paidJson = JsonDocument.Parse(File.ReadAllText(
                    EvidencePath("skill-cash", "paid-flag-accounting.json")));
                JsonElement paidRoot = paidJson.RootElement;
                Assert(paidRoot.GetProperty("sites").GetProperty("9ED9").GetInt32() == 35,
                    "Natural paid-window 9ED9 site count differs");
                Assert(paidRoot.GetProperty("classification").GetString()!
                        .Contains("Natural", StringComparison.OrdinalIgnoreCase),
                    "Paid-window evidence is not classified as natural");
            });

            Check("Identity compiler emits the exact span and preserves all 65536 bytes", () =>
            {
                compile = VmIlCompiler.CompileIdentity(definition, rom);
                Assert(Convert.ToHexString(compile.EmittedBody) == ExpectedSpanHex,
                    "Compiled body differs from the original span");
                Assert(compile.ChangedOffsets.Length == 0, "Identity compile changed offsets");
                Assert(compile.Image.Length == 65536, "Compiled image length differs");
                Assert(compile.Image.SequenceEqual(rom), "Compiled image differs from the original");
                Assert(compile.InputSha256 == beforeSha256, "Compile input SHA256 differs");
                Assert(compile.OutputSha256 == beforeSha256, "Compile output SHA256 differs");
                Assert(compile.EmittedBody.SequenceEqual(rom.AsSpan(0x9ED9, 14).ToArray()),
                    "Emitted body bytes differ from the original ROM span");
            });

            Check("Source map binds the ROM hash and span and maps every byte uniquely", () =>
            {
                map = VmIlSourceMap.Create(definition);
                Assert(map.RomSha256 == NineEdNineDecoder.RequiredRomSha256,
                    "Source map is not bound to the exact ROM SHA256");
                Assert(map.BodyStart == 0x9ED9 && map.BodyEndExclusive == 0x9EE7,
                    "Source map span differs");
                Assert(map.Entries.Count == 14, "Source map entry count differs");
                for (int index = 0; index < 14; index++)
                {
                    ushort address = (ushort)(0x9ED9 + index);
                    VmIlSourceMapEntry entry = map.Resolve(address);
                    Assert(entry.Address == address, $"Source map address {address:X4} differs");
                    VmIlNode node = definition.Nodes[entry.NodeIndex];
                    Assert(address >= node.Address &&
                           address < node.Address + node.Bytes.Length,
                        $"Address {address:X4} reverse-maps to the wrong node");
                    Assert(entry.Token == node.Token, $"Address {address:X4} token differs");
                    Assert(map.ResolveNodeIndex(address) == entry.NodeIndex,
                        $"Address {address:X4} reverse lookup differs");
                }
                Assert(map.Resolve(0x9ED9).NodeIndex == 0, "First byte node differs");
                Assert(map.Resolve(0x9EDC).NodeIndex == 0, "Operand byte node differs");
                Assert(map.Resolve(0x9EE6).NodeIndex == 4, "Last byte node differs");
            });

            Check("Fixed original identity rejects caller-forged definition hashes and tampered images", () =>
            {
                byte[] tampered = (byte[])rom.Clone();
                tampered[0x1400] ^= 1;
                string tamperedSha1 = Convert.ToHexString(SHA1.HashData(tampered));
                string tamperedSha256 = Convert.ToHexString(SHA256.HashData(tampered));
                VmIlDefinition forged = definition with
                {
                    RomLength = tampered.Length,
                    RomSha1 = tamperedSha1,
                    RomSha256 = tamperedSha256
                };

                Reject(() => VmIlCompiler.CompileIdentity(forged, tampered), "SHA1");
                Reject(() => VmIlCompiler.CompileEdit(
                        tampered, new VmIlOperandEdit(0x9EDB, 0xFF80, 0xFF00)),
                    "SHA1");
                Reject(() => VmIlSourceMap.Create(forged), "identity");
                Reject(() => VmIlSourceMap.Create(definition with
                {
                    RomSha256 = tamperedSha256
                }), "identity");
            });

            Check("Supported same-size IL edit emits FF00 at 9EDC and preserves all other bytes", () =>
            {
                edited = VmIlCompiler.CompileEdit(
                    rom, new VmIlOperandEdit(0x9EDB, 0xFF80, 0xFF00));

                Assert(edited.Compile.EmittedBody.Length == 14,
                    "Edited emitted body length differs");
                Assert(Convert.ToHexString(edited.Compile.EmittedBody) == ExpectedEditedSpanHex,
                    "Edited emitted body differs from 795BFF00787E795BFF807AAF792F");
                Assert(edited.Compile.ChangedOffsets.SequenceEqual(new[] { 0x9EDC }),
                    "Edited compile did not change exactly offset 9EDC");
                Assert(edited.Compile.Image.Length == 65536,
                    "Edited image length differs");
                Assert(rom[0x9EDC] == 0x80 && edited.Compile.Image[0x9EDC] == 0x00,
                    "9EDC was not 80 -> 00");
                Assert(edited.Compile.Image[0x9EDB] == 0xFF,
                    "Unexpected change to the first literal high byte");
                Assert(edited.Compile.Image[0x9EE1] == 0xFF &&
                       edited.Compile.Image[0x9EE2] == 0x80,
                    "Second inline literal FF80 was not preserved");
                Assert(edited.Compile.Image[0x9ED7] == 0x00 &&
                       edited.Compile.Image[0x9ED8] == 0xF8,
                    "VM header 00F8 was not preserved");

                int diffCount = 0;
                for (int offset = 0; offset < rom.Length; offset++)
                {
                    if (rom[offset] == edited.Compile.Image[offset]) continue;
                    diffCount++;
                    Assert(offset == 0x9EDC,
                        $"Unexpected changed byte at {offset:X4}");
                }
                Assert(diffCount == 1, "Edited image diff is not exactly one byte");

                string editedSha1 = Convert.ToHexString(SHA1.HashData(edited.Compile.Image));
                string editedSha256 = Convert.ToHexString(SHA256.HashData(edited.Compile.Image));
                Assert(editedSha1 == ExpectedEditedSha1, "Edited image SHA1 differs");
                Assert(editedSha256 == ExpectedEditedSha256, "Edited image SHA256 differs");
                Assert(edited.Compile.OutputSha256 == ExpectedEditedSha256,
                    "Compile output SHA256 differs");
                Assert(edited.Compile.InputSha256 == beforeSha256,
                    "Compile input SHA256 differs");
                Assert(edited.OriginalRomSha1 == beforeSha1 &&
                       edited.OriginalRomSha256 == beforeSha256,
                    "Edited result original identity differs");
                Assert(!edited.IntegrityRepaired,
                    "Edited artifact unexpectedly claims repaired integrity");
                Assert(edited.IntegrityStatus.Contains("UNREPAIRED", StringComparison.Ordinal),
                    "Edited artifact is not marked UNREPAIRED");

                Assert(edited.Edit.NodeIndex == 0, "Edited node index differs");
                Assert(edited.Edit.TokenAddress == 0x9ED9, "Edited token address differs");
                Assert(edited.Edit.OperandAddress == 0x9EDB, "Edited operand address differs");
                Assert(edited.Edit.Token == 0x795B, "Edited token differs");
                Assert(edited.Edit.Operation == "vm_push_inline_word_literal",
                    "Edited operation differs");
                Assert(edited.Edit.OperandWidthBytes == 2, "Edited operand width differs");
                Assert(edited.Edit.ExpectedOriginalValue == 0xFF80,
                    "Edited expected original value differs");
                Assert(edited.Edit.ActualOriginalValue == 0xFF80,
                    "Edited actual original value differs");
                Assert(edited.Edit.ReplacementValue == 0xFF00,
                    "Edited replacement value differs");
                Assert(edited.Edit.ExpectedOriginalBytesHex == "FF80",
                    "Edited expected original bytes differ");
                Assert(edited.Edit.ReplacementBytesHex == "FF00",
                    "Edited replacement bytes differ");
                Assert(edited.Edit.ChangedOffsets.SequenceEqual(new[] { 0x9EDC }),
                    "Edited report changed offsets differ");
            });

            Check("Edited source map covers all 14 bytes and is bound to the exact output image", () =>
            {
                editedMap = VmIlSourceMap.CreateForBuild(
                    edited.SourceDefinition, edited.Compile.Image, edited.Compile.EmittedBody);
                string editedSha256 = Convert.ToHexString(SHA256.HashData(edited.Compile.Image));

                Assert(editedMap.RomSha256 == beforeSha256,
                    "Edited source map original identity differs");
                Assert(editedMap.ImageSha256 == editedSha256,
                    "Edited source map is not bound to the output image SHA256");
                Assert(!editedMap.IsIdentityBuild,
                    "Edited source map incorrectly claims an identity build");
                Assert(editedMap.BodyStart == 0x9ED9 && editedMap.BodyEndExclusive == 0x9EE7,
                    "Edited source-map span differs");
                Assert(editedMap.Entries.Count == 14, "Edited source-map entry count differs");

                for (int index = 0; index < 14; index++)
                {
                    ushort address = (ushort)(0x9ED9 + index);
                    VmIlSourceMapEntry entry = editedMap.Resolve(address, editedSha256);
                    Assert(entry.Address == address,
                        $"Edited source-map address {address:X4} differs");
                    Assert(entry.ImageByte == edited.Compile.Image[address],
                        $"Edited source-map byte at {address:X4} differs from the image");
                    VmIlNode node = definition.Nodes[entry.NodeIndex];
                    Assert(entry.Token == node.Token,
                        $"Edited source-map token at {address:X4} differs");
                    Assert(entry.Operation == node.Operation,
                        $"Edited source-map operation at {address:X4} differs");
                    Assert(editedMap.ResolveNodeIndex(address, editedSha256) == entry.NodeIndex,
                        $"Edited source-map reverse lookup at {address:X4} differs");
                }

                Assert(editedMap.Resolve(0x9EDC, editedSha256).ImageByte == 0x00,
                    "Edited source map does not show 9EDC = 00");
                Assert(editedMap.Resolve(0x9EDB, editedSha256).ImageByte == 0xFF,
                    "Edited source map does not show 9EDB = FF");
                Assert(editedMap.Resolve(0x9EE1, editedSha256).ImageByte == 0xFF &&
                       editedMap.Resolve(0x9EE2, editedSha256).ImageByte == 0x80,
                    "Edited source map does not preserve the second literal FF80");
                Assert(map.Resolve(0x9EDC, beforeSha256).ImageByte == 0x80,
                    "Original source map does not show 9EDC = 80");
                Assert(editedMap.Resolve(0x9EDC, edited.Compile.Image).ImageByte == 0x00,
                    "Edited source map image-span lookup differs");

                Reject(() => map.Resolve(0x9EDC, editedSha256), "identity");
                Reject(() => editedMap.Resolve(0x9EDC, beforeSha256), "identity");
                Reject(() => editedMap.Resolve(0x9EDC, rom), "identity");

                byte[] wrongBody = (byte[])edited.Compile.Image.Clone();
                wrongBody[0x9EDC] = 0x80;
                Reject(() => VmIlSourceMap.CreateForBuild(
                        edited.SourceDefinition, wrongBody, edited.Compile.EmittedBody),
                    "does not match");
                Reject(() => VmIlSourceMap.CreateForBuild(
                        edited.SourceDefinition with { BodyEndExclusive = 0x10001 },
                        edited.Compile.Image, edited.Compile.EmittedBody),
                    "invalid");
            });

            Check("Original firmware integrity fields verify in recovered record order", () =>
            {
                VmIlIntegrityOriginalVerification original =
                    VmIlIntegrity.VerifyOriginal(rom);
                Assert(original.RecordBase == 0xFFD1, "Integrity record base differs");
                Assert(original.RangeStart == 0x1400, "Integrity range start differs");
                Assert(original.RangeEnd == 0xFFFF, "Integrity range end differs");
                Assert(original.ErrorCode == 0x12, "Integrity error code differs");
                Assert(original.Gate == 0x00, "Integrity record gate differs");
                Assert(original.StoredFieldsHex == ExpectedOriginalFieldsHex,
                    "Original stored integrity fields differ");
                Assert(original.ComputedFieldsHex == ExpectedOriginalFieldsHex,
                    "Recomputed original integrity fields differ");
                Assert(rom[0x719B] == 0x00, "Outer gate 719B is not the original 00");
                Assert(Convert.ToHexString(rom.AsSpan(0xFFD6, 6)) == "1400FFFF1200",
                    "Active record metadata FFD6-FFDB differs");
            });

            Check("Checked repair applies ordered fields and changes only 9EDC plus FFD1-FFD5", () =>
            {
                repairedBuild = VmIlCompiler.CompileEditWithIntegrity(
                    rom, new VmIlOperandEdit(0x9EDB, 0xFF80, 0xFF00));
                VmIlIntegrityResult integrity = repairedBuild.Integrity;
                VmIlIntegrityReport integrityReport = integrity.Report;
                byte[] unrepairedImage = repairedBuild.Unrepaired.Compile.Image;
                byte[] repairedImage = integrity.RepairedImage;

                Assert(repairedBuild.Unrepaired.Compile.ChangedOffsets.SequenceEqual(
                        new[] { 0x9EDC }),
                    "Unrepaired compile did not change exactly 9EDC");
                Assert(Convert.ToHexString(unrepairedImage.AsSpan(0x9ED9, 14)) ==
                       ExpectedEditedSpanHex, "Unrepaired span differs");
                Assert(Convert.ToHexString(repairedImage.AsSpan(0x9ED9, 14)) ==
                       ExpectedEditedSpanHex, "Repair changed the edited span");

                Assert(integrityReport.OriginalStoredFieldsHex == ExpectedOriginalFieldsHex,
                    "Report original stored fields differ");
                Assert(integrityReport.OriginalComputedFieldsHex == ExpectedOriginalFieldsHex,
                    "Report original computed fields differ");
                Assert(integrityReport.UnrepairedStoredFieldsHex == ExpectedOriginalFieldsHex,
                    "Unrepaired stored fields were not preserved");
                Assert(integrityReport.RepairedStoredFieldsHex == ExpectedRepairedFieldsHex,
                    "Repaired stored fields differ from the derived ordered values");
                Assert(integrityReport.RepairedComputedFieldsHex == ExpectedRepairedFieldsHex,
                    "Repaired computed fields differ from the derived ordered values");

                Assert(integrityReport.Fields.Count == 5, "Field write count differs");
                string[] expectedNames =
                    { "sum", "xor", "rotate_add", "rotate_sub_xor_a", "rotate_sub_xor_b" };
                int[] expectedOffsets = { 0xFFD1, 0xFFD2, 0xFFD3, 0xFFD4, 0xFFD5 };
                string[] expectedAfter = { "BE", "F6", "9E", "7C", "C7" };
                for (int index = 0; index < expectedNames.Length; index++)
                {
                    VmIlIntegrityField field = integrityReport.Fields[index];
                    Assert(field.Name == expectedNames[index],
                        $"Field {index} name differs");
                    Assert(field.Offset == expectedOffsets[index],
                        $"Field {index} offset differs");
                    Assert($"{field.UnrepairedValue:X2}" ==
                           ExpectedOriginalFieldsHex.Substring(index * 2, 2),
                        $"Field {index} unrepaired value differs");
                    Assert($"{field.RepairedValue:X2}" == expectedAfter[index],
                        $"Field {index} repaired value differs");
                }
                Assert(integrityReport.AlgorithmOrder.Contains("sum_xor", StringComparison.Ordinal) &&
                       integrityReport.AlgorithmOrder.Contains("rotate_add", StringComparison.Ordinal) &&
                       integrityReport.AlgorithmOrder.Contains("rotate_sub_xor", StringComparison.Ordinal),
                    "Algorithm order description is incomplete");

                int[] expectedRepairedDiff =
                    new[] { 0x9EDC }.Concat(Enumerable.Range(0xFFD1, 5)).ToArray();
                Assert(integrityReport.UnrepairedChangedOffsets.SequenceEqual(
                        new[] { 0x9EDC }), "Unrepaired changed offsets differ");
                Assert(integrityReport.RepairedChangedOffsets.SequenceEqual(
                        expectedRepairedDiff), "Repaired changed offsets differ");
                Assert(integrityReport.RepairChangedOffsets.SequenceEqual(
                        Enumerable.Range(0xFFD1, 5)), "Repair-only changed offsets differ");

                Assert(integrity.RepairedImageSha1 == ExpectedRepairedSha1,
                    "Repaired image SHA1 differs");
                Assert(integrity.RepairedImageSha256 == ExpectedRepairedSha256,
                    "Repaired image SHA256 differs");
                Assert(integrity.UnrepairedImageSha256 == ExpectedEditedSha256,
                    "Unrepaired image SHA256 differs");
                Assert(integrity.OriginalRomSha1 == beforeSha1 &&
                       integrity.OriginalRomSha256 == beforeSha256,
                    "Integrity result original identity differs");
                Assert(repairedImage[0x9EDC] == 0x00, "Repaired image lost the 9EDC edit");

                repairedMap = VmIlSourceMap.CreateForBuild(
                    repairedBuild.Unrepaired.SourceDefinition,
                    repairedImage,
                    repairedBuild.Unrepaired.Compile.EmittedBody);
                Assert(repairedMap.ImageSha256 == ExpectedRepairedSha256,
                    "Repaired source map is not bound to the repaired SHA256");
                Assert(!repairedMap.IsIdentityBuild,
                    "Repaired source map incorrectly claims identity");
                Assert(repairedMap.Entries.Count == 14,
                    "Repaired source map entry count differs");
                for (int index = 0; index < 14; index++)
                {
                    ushort address = (ushort)(0x9ED9 + index);
                    VmIlSourceMapEntry entry = repairedMap.Resolve(address, ExpectedRepairedSha256);
                    Assert(entry.Address == address,
                        $"Repaired source-map address {address:X4} differs");
                    Assert(entry.ImageByte == repairedImage[address],
                        $"Repaired source-map byte at {address:X4} differs");
                }
                Assert(repairedMap.Resolve(0x9EDC, ExpectedRepairedSha256).ImageByte == 0x00,
                    "Repaired source map does not resolve 9EDC to 00");

                Reject(() => editedMap.Resolve(0x9EDC, ExpectedRepairedSha256), "identity");
                Reject(() => repairedMap.Resolve(0x9EDC, ExpectedEditedSha256), "identity");
                Reject(() => repairedMap.Resolve(0x9EDC, rom), "identity");
            });

            Check("Ordered regeneration differs from unordered stale-field computation", () =>
            {
                byte[] unrepairedImage = repairedBuild.Unrepaired.Compile.Image;
                VmIlIntegrityComputedFields ordered =
                    VmIlIntegrity.ComputeForTests(unrepairedImage, orderedWrites: true);
                VmIlIntegrityComputedFields unordered =
                    VmIlIntegrity.ComputeForTests(unrepairedImage, orderedWrites: false);
                string orderedHex = FormatComputed(ordered);
                string unorderedHex = FormatComputed(unordered);
                Assert(orderedHex == ExpectedRepairedFieldsHex,
                    "Ordered synthetic computation differs from the repaired fields");
                Assert(unorderedHex == ExpectedUnorderedFieldsHex,
                    "Unordered synthetic computation differs from the expected stale fields");
                Assert(orderedHex != unorderedHex,
                    "Ordered and unordered computations unexpectedly agree");

                byte[] wrongOrder = (byte[])unrepairedImage.Clone();
                wrongOrder[0xFFD1] = (byte)unordered.Sum;
                wrongOrder[0xFFD2] = (byte)unordered.Xor;
                wrongOrder[0xFFD3] = (byte)unordered.RotateAdd;
                wrongOrder[0xFFD4] = (byte)unordered.RotateSubXorA;
                wrongOrder[0xFFD5] = (byte)unordered.RotateSubXorB;
                Reject(() => VmIlIntegrity.VerifyFieldsForTests(wrongOrder),
                    "ordered computation");
                Assert(VmIlIntegrity.VerifyFieldsForTests(
                        repairedBuild.Integrity.RepairedImage) == ExpectedRepairedFieldsHex,
                    "Repaired fields do not self-verify");
            });

            Check("Integrity repair rejects forged identity unexpected edits protected bytes and malformed inputs", () =>
            {
                byte[] unrepairedImage = repairedBuild.Unrepaired.Compile.Image;
                byte[] repairedImage = repairedBuild.Integrity.RepairedImage;

                Reject(() => VmIlIntegrity.Repair(
                        rom.AsSpan(0, rom.Length - 1), unrepairedImage), "length");
                Reject(() => VmIlIntegrity.Repair(
                        rom, unrepairedImage.AsSpan(0, unrepairedImage.Length - 1)), "length");

                byte[] tamperedOriginal = (byte[])rom.Clone();
                tamperedOriginal[0x1400] ^= 1;
                Reject(() => VmIlIntegrity.Repair(tamperedOriginal, unrepairedImage), "SHA1");

                byte[] badRecord = (byte[])rom.Clone();
                badRecord[0xFFD6] = 0x15;
                Reject(() => VmIlIntegrity.ValidateRecordTableForTests(badRecord), "record");

                byte[] badGate = (byte[])rom.Clone();
                badGate[0x719B] = 0x02;
                Reject(() => VmIlIntegrity.ValidateRecordTableForTests(badGate), "gate");

                byte[] badFields = (byte[])rom.Clone();
                badFields[0xFFD1] ^= 1;
                Reject(() => VmIlIntegrity.VerifyFieldsForTests(badFields),
                    "ordered computation");

                byte[] extraByte = (byte[])unrepairedImage.Clone();
                extraByte[0x1401] ^= 1;
                Reject(() => VmIlIntegrity.Repair(rom, extraByte), "supported 9ED9");

                Reject(() => VmIlIntegrity.Repair(rom, rom), "80 -> 00");
                Reject(() => VmIlIntegrity.Repair(rom, repairedImage), "supported 9ED9");

                byte[] wrongOperand = (byte[])unrepairedImage.Clone();
                wrongOperand[0x9EDC] = 0x01;
                Reject(() => VmIlIntegrity.Repair(rom, wrongOperand), "80 -> 00");

                byte[] changedChecker = (byte[])unrepairedImage.Clone();
                changedChecker[0x66DB] ^= 1;
                Reject(() => VmIlIntegrity.Repair(rom, changedChecker), "checker code");

                byte[] changedMetadata = (byte[])unrepairedImage.Clone();
                changedMetadata[0xFFD6] ^= 1;
                Reject(() => VmIlIntegrity.Repair(rom, changedMetadata),
                    "active record metadata");
            });

            Check("Edit validation rejects unsupported values addresses tokens widths spans and multiple edits", () =>
            {
                VmIlOperandEdit valid = new(0x9EDB, 0xFF80, 0xFF00);
                VmIlNode first = definition.Nodes[0];
                VmIlNode[] rest = definition.Nodes.Skip(1).ToArray();

                Reject(() => VmIlCompiler.CompileEdit(
                        rom, new VmIlOperandEdit(0x9EDB, 0xFF81, 0xFF00)),
                    "expected original");
                Reject(() => VmIlCompiler.CompileEdit(
                        rom, new VmIlOperandEdit(0x9EDC, 0xFF80, 0xFF00)),
                    "operand address");
                Reject(() => VmIlCompiler.CompileEdit(
                        rom, new VmIlOperandEdit(0x9ED9, 0xFF80, 0xFF00)),
                    "operand address");
                Reject(() => VmIlCompiler.CompileEdit(
                        rom, new VmIlOperandEdit(0x9EE1, 0xFF80, 0xFF00)),
                    "operand address");
                Reject(() => VmIlCompiler.CompileEdit(
                        rom, new VmIlOperandEdit(0xFFFF, 0xFF80, 0xFF00)),
                    "operand address");
                Reject(() => VmIlCompiler.CompileEdit(
                        rom, new VmIlOperandEdit(0x9EDB, 0xFF80, 0xFF80)),
                    "no-op");
                Reject(() => VmIlCompiler.CompileEdits(
                        rom, Array.Empty<VmIlOperandEdit>()), "Exactly one");
                Reject(() => VmIlCompiler.CompileEdits(
                        rom, new[] { valid, valid }), "Exactly one");

                VmIlDefinition unsupportedToken = definition with
                {
                    Nodes = new[]
                    {
                        first with
                        {
                            Token = 0x7963,
                            Operation = "vm_push_inline_byte_literal"
                        }
                    }.Concat(rest).ToArray()
                };
                Reject(() => VmIlCompiler.CompileEditsForTests(
                        unsupportedToken, rom, new[] { valid }),
                    "Unsupported edit target token");

                VmIlDefinition wrongWidth = definition with
                {
                    Nodes = new[]
                    {
                        first with
                        {
                            Operand = new VmIlOperand(0x9EDB, new byte[] { 0xFF }, 0xFF80)
                        }
                    }.Concat(rest).ToArray()
                };
                Reject(() => VmIlCompiler.CompileEditsForTests(
                        wrongWidth, rom, new[] { valid }),
                    "operand width");

                VmIlNode[] changedUnrelated = definition.Nodes.ToArray();
                changedUnrelated[1] = new VmIlNode(
                    1, 0x9EDD, 0x7AAF, "vm_bitwise_xor",
                    new byte[] { 0x7A, 0xAF }, null,
                    VmIlEvidenceClass.OriginalRomBytes);
                Reject(() => VmIlCompiler.CompileEditsForTests(
                        definition with { Nodes = changedUnrelated }, rom, new[] { valid }),
                    "original span");

                Reject(() => VmIlCompiler.CompileEditsForTests(
                        definition with { BodyEndExclusive = 0x9EE6 }, rom, new[] { valid }),
                    "definition end");
                Reject(() => VmIlCompiler.CompileEditsForTests(
                        definition with { BodyStart = 0x9EDA }, rom, new[] { valid }),
                    "body start");
                Reject(() => VmIlCompiler.CompileEditsForTests(
                        definition with { BodyEndExclusive = 0x10001 }, rom, new[] { valid }),
                    "address space");

                byte[] tampered = (byte[])rom.Clone();
                tampered[0x9EDC] ^= 1;
                Reject(() => VmIlCompiler.CompileEdit(tampered, valid), "SHA1");
            });

            Check("Wrong length SHA1 and SHA256 are rejected before decoding", () =>
            {
                Reject(() => NineEdNineDecoder.Decode(rom.AsSpan(0, rom.Length - 1)),
                    "length");
                Reject(() => NineEdNineDecoder.Decode(new byte[rom.Length + 1]), "length");
                Reject(() => NineEdNineDecoder.ValidateIdentity(
                        rom, 65536, new string('0', 40),
                        NineEdNineDecoder.RequiredRomSha256),
                    "SHA1");
                Reject(() => NineEdNineDecoder.ValidateIdentity(
                        rom, 65536, NineEdNineDecoder.RequiredRomSha1,
                        new string('0', 64)),
                    "SHA256");
                byte[] tampered = (byte[])rom.Clone();
                tampered[0x9EDC] ^= 1;
                Reject(() => NineEdNineDecoder.Decode(tampered), "SHA1");
            });

            Check("Unsupported tokens malformed operands and truncation are rejected", () =>
            {
                RejectBody(new byte[] { 0x79, 0x63 }, "unsupported");
                RejectBody(new byte[] { 0x79, 0x82 }, "unsupported");
                RejectBody(new byte[] { 0xFF, 0xFF }, "unsupported");
                RejectBody(new byte[] { 0x79, 0x5B, 0xFF, 0x80 }, "return");
                RejectBody(new byte[] { 0x79, 0x5B }, "truncated");
                RejectBody(new byte[] { 0x79, 0x5B, 0xFF }, "truncated");
                RejectBody(new byte[] { 0x78, 0x7E, 0xFF, 0x80 }, "unsupported");
                RejectBody(new byte[] { 0x78, 0x7E, 0x7A, 0xAF }, "return");
            });

            Check("Header body-start end return and address-overflow mismatches are rejected", () =>
            {
                Reject(() => NineEdNineDecoder.DecodeImageWithoutIdentityForTests(
                        rom, 0x9ED7, 0x00F9, 0x9ED9, 0x9EE7),
                    "header mismatch");
                Reject(() => NineEdNineDecoder.DecodeImageWithoutIdentityForTests(
                        rom, 0x9ED7, 0x00F8, 0x9EDA, 0x9EE7),
                    "body-start");
                RejectBodyAtEnd(rom.AsSpan(0x9ED9, 14).ToArray(), 0x9ED9, 0x9EE6,
                    "definition end");
                RejectBodyAtEnd(rom.AsSpan(0x9ED9, 14).ToArray(), 0x9ED9, 0x9EE8,
                    "return");
                RejectBodyAtEnd(new byte[] { 0x79, 0x2F, 0x79, 0x2F }, 0x9ED9, 0x9EDD,
                    "return");
                RejectBodyAtEnd(new byte[] { 0x79, 0x2F, 0x7A, 0xAF }, 0x9ED9, 0x9EDD,
                    "return");
                Reject(() => NineEdNineDecoder.DecodeBodyForTests(
                        new byte[] { 0x79, 0x5B, 0xFF, 0x80 }, 0xFFFE, 0x10002),
                    "address space");
                Reject(() => NineEdNineDecoder.DecodeBodyForTests(
                        new byte[] { 0x79, 0x5B, 0xFF, 0x80 }, 0x9ED9, 0x10001),
                    "address space");
            });

            Check("Compiler rejects unsupported tampered malformed and edited definitions", () =>
            {
                VmIlNode first = definition.Nodes[0];
                VmIlNode[] rest = definition.Nodes.Skip(1).ToArray();

                Reject(() => VmIlCompiler.CompileIdentity(definition with
                {
                    Nodes = new[]
                    {
                        first with
                        {
                            Token = 0x7963,
                            Operation = "vm_push_inline_byte_literal"
                        }
                    }.Concat(rest).ToArray()
                }, rom), "unsupported");

                Reject(() => VmIlCompiler.CompileIdentity(definition with
                {
                    Nodes = new[] { first with { Operand = null } }.Concat(rest).ToArray()
                }, rom), "operand");

                Reject(() => VmIlCompiler.CompileIdentity(definition with
                {
                    Nodes = new[]
                    {
                        first with
                        {
                            Operand = new VmIlOperand(
                                first.Operand!.Address, new byte[] { 0xFF }, 0xFF80)
                        }
                    }.Concat(rest).ToArray()
                }, rom), "width");

                Reject(() => VmIlCompiler.CompileIdentity(definition with
                {
                    Nodes = new[]
                    {
                        first with { Bytes = new byte[] { 0x79, 0x5B, 0xFF } }
                    }.Concat(rest).ToArray()
                }, rom), "byte length");

                Reject(() => VmIlCompiler.CompileIdentity(definition with
                {
                    HeaderBytes = new byte[] { 0x00, 0xF9 }
                }, rom), "header bytes");

                Reject(() => VmIlCompiler.CompileIdentity(definition with
                {
                    BodyStart = 0x9EDA
                }, rom), "body start");

                Reject(() => VmIlCompiler.CompileIdentity(definition with
                {
                    BodyEndExclusive = 0x9EE6
                }, rom), "definition end");

                Reject(() => VmIlCompiler.CompileIdentity(definition with
                {
                    BodyEndExclusive = 0x10001
                }, rom), "address space");

                var multipleReturns = new VmIlNode[]
                {
                    new(0, 0x9ED9, 0x792F, "vm_return_to_caller_stream",
                        new byte[] { 0x79, 0x2F }, null, VmIlEvidenceClass.OriginalRomBytes),
                    new(1, 0x9EDB, 0x7AAF, "vm_bitwise_xor",
                        new byte[] { 0x7A, 0xAF }, null, VmIlEvidenceClass.OriginalRomBytes)
                };
                Reject(() => VmIlCompiler.CompileIdentity(definition with
                {
                    BodyEndExclusive = 0x9EDD,
                    Nodes = multipleReturns
                }, rom), "multiple VM return");

                var returnBoundary = new VmIlNode[]
                {
                    new(0, 0x9ED9, 0x792F, "vm_return_to_caller_stream",
                        new byte[] { 0x79, 0x2F }, null, VmIlEvidenceClass.OriginalRomBytes)
                };
                Reject(() => VmIlCompiler.CompileIdentity(definition with
                {
                    BodyEndExclusive = 0x9EDD,
                    Nodes = returnBoundary
                }, rom), "return boundary");

                var editedFirst = first with
                {
                    Bytes = new byte[] { 0x79, 0x5B, 0xFF, 0x00 },
                    Operand = new VmIlOperand(first.Operand!.Address,
                        new byte[] { 0xFF, 0x00 }, 0xFF00)
                };
                Reject(() => VmIlCompiler.CompileIdentity(definition with
                {
                    Nodes = new[] { editedFirst }.Concat(rest).ToArray()
                }, rom), "original span bytes");

                byte[] tampered = (byte[])rom.Clone();
                tampered[0x9EDC] ^= 1;
                Reject(() => VmIlCompiler.CompileIdentity(definition, tampered), "SHA1");
            });

            Check("Changed span byte decodes differently or fails identity compile", () =>
            {
                byte[] changedBody = rom.AsSpan(0x9ED9, 14).ToArray();
                changedBody[3] = 0x00;
                VmIlDefinition synthetic =
                    NineEdNineDecoder.DecodeBodyForTests(changedBody, 0x9ED9, 0x9EE7);
                Assert(synthetic.Nodes[0].Operand!.Value == 0xFF00,
                    "Changed literal did not decode as FF00");
                Assert(!synthetic.Nodes[0].Bytes.SequenceEqual(definition.Nodes[0].Bytes),
                    "Changed literal bytes did not differ");

                VmIlNode[] changedNodes = definition.Nodes.ToArray();
                changedNodes[0] = changedNodes[0] with
                {
                    Bytes = new byte[] { 0x79, 0x5B, 0xFF, 0x00 },
                    Operand = new VmIlOperand(0x9EDB, new byte[] { 0xFF, 0x00 }, 0xFF00)
                };
                Reject(() => VmIlCompiler.CompileIdentity(definition with
                {
                    Nodes = changedNodes
                }, rom), "original span bytes");
            });

            Check("Ambiguous and out-of-span source maps fail explicitly", () =>
            {
                Reject(() => map.Resolve(0x9ED8), "outside");
                Reject(() => map.Resolve(0x9EE7), "outside");
                Reject(() => map.Resolve(0xFFFF), "outside");

                var overlapping = new VmIlNode[]
                {
                    new(0, 0x9ED9, 0x787E, "vm_add_words",
                        new byte[] { 0x78, 0x7E }, null, VmIlEvidenceClass.OriginalRomBytes),
                    new(1, 0x9ED9, 0x7AAF, "vm_bitwise_xor",
                        new byte[] { 0x7A, 0xAF }, null, VmIlEvidenceClass.OriginalRomBytes)
                };
                Reject(() => VmIlSourceMap.Create(definition with
                {
                    BodyEndExclusive = 0x9EDB,
                    Nodes = overlapping
                }), "ambiguous");
            });

            Check("Input ROM is unchanged and outputs reject existing paths", () =>
            {
                byte[] after = File.ReadAllBytes(romPath);
                Assert(Convert.ToHexString(SHA1.HashData(after)) == beforeSha1,
                    "Input ROM SHA1 changed during verification");
                Assert(Convert.ToHexString(SHA256.HashData(after)) == beforeSha256,
                    "Input ROM SHA256 changed during verification");

                string temporary = Path.Combine(
                    Path.GetTempPath(), "fml-il-create-" + Guid.NewGuid().ToString("N"));
                Directory.CreateDirectory(temporary);
                try
                {
                    string file = Path.Combine(temporary, "report.json");
                    VerificationOutputs.WriteCreateOnly(file, "first");
                    Reject(() => VerificationOutputs.WriteCreateOnly(file, "second"), "exists");
                    Assert(File.ReadAllText(file) == "first",
                        "Create-only output was overwritten");
                }
                finally
                {
                    Directory.Delete(temporary, true);
                }
            });

            Check("IL and verifier dependency boundaries exclude the native executor", () =>
            {
                ilReferences = typeof(VmIlDefinition).Assembly.GetReferencedAssemblies()
                    .Select(name => name.Name ?? string.Empty)
                    .OrderBy(name => name, StringComparer.Ordinal).ToArray();
                verifierReferences = typeof(NineEdNineVerification).Assembly
                    .GetReferencedAssemblies()
                    .Select(name => name.Name ?? string.Empty)
                    .OrderBy(name => name, StringComparer.Ordinal).ToArray();

                Assert(ilReferences.All(name =>
                        !name.StartsWith("FruitMachineLab", StringComparison.OrdinalIgnoreCase) &&
                        (name.StartsWith("System.", StringComparison.OrdinalIgnoreCase) ||
                         name is "System.Runtime" or "mscorlib" or "netstandard")),
                    "IL assembly references a forbidden dependency");
                Assert(verifierReferences.All(name =>
                        name != "FruitMachineLab.Runtime" &&
                        name != "FruitMachineLab.Adders" &&
                        !name.Contains("Executor", StringComparison.OrdinalIgnoreCase)),
                    "Verifier references a native executor assembly");

                string ilProject = File.ReadAllText(Path.Combine(
                    repositoryRoot, "src", "FruitMachineLab.Il",
                    "FruitMachineLab.Il.csproj"));
                Assert(!ilProject.Contains("ProjectReference", StringComparison.OrdinalIgnoreCase),
                    "IL project has a project dependency");
                Assert(!ilProject.Contains("PackageReference", StringComparison.OrdinalIgnoreCase),
                    "IL project has a package dependency");

                string verifierProject = File.ReadAllText(Path.Combine(
                    repositoryRoot, "tests", "FruitMachineLab.IlVerification",
                    "FruitMachineLab.IlVerification.csproj"));
                Assert(verifierProject.Contains(
                        "src/FruitMachineLab.Il/FruitMachineLab.Il.csproj",
                        StringComparison.OrdinalIgnoreCase),
                    "Verifier does not reference the IL project");
                int projectReferences = verifierProject.Split(
                    "ProjectReference", StringSplitOptions.None).Length - 1;
                Assert(projectReferences == 1,
                    "Verifier has dependencies other than the IL project");

                string cliProject = File.ReadAllText(Path.Combine(
                    repositoryRoot, "tools", "FruitMachineLab.IlBuild",
                    "FruitMachineLab.IlBuild.csproj"));
                Assert(!cliProject.Contains("PackageReference", StringComparison.OrdinalIgnoreCase),
                    "CLI project has a package dependency");
                Assert(cliProject.Contains(
                        "src/FruitMachineLab.Il/FruitMachineLab.Il.csproj",
                        StringComparison.OrdinalIgnoreCase),
                    "CLI does not reference the IL project");
                Assert(!cliProject.Contains("FruitMachineLab.Runtime",
                        StringComparison.OrdinalIgnoreCase) &&
                       !cliProject.Contains("FruitMachineLab.Adders",
                        StringComparison.OrdinalIgnoreCase) &&
                       !cliProject.Contains("Executor",
                        StringComparison.OrdinalIgnoreCase),
                    "CLI references a native executor assembly");
                int cliProjectReferences = cliProject.Split(
                    "ProjectReference", StringSplitOptions.None).Length - 1;
                Assert(cliProjectReferences == 1,
                    "CLI has dependencies other than the IL project");
            });
        }
        catch
        {
            WriteFailureOutputs(outputDirectory, checks);
            throw;
        }

        byte[] finalBytes = File.ReadAllBytes(romPath);
        string afterSha1 = Convert.ToHexString(SHA1.HashData(finalBytes));
        string afterSha256 = Convert.ToHexString(SHA256.HashData(finalBytes));
        string editedSha1 = Convert.ToHexString(SHA1.HashData(edited.Compile.Image));
        string editedSha256 = edited.Compile.OutputSha256;
        VmIlIntegrityResult repairedIntegrity = repairedBuild.Integrity;
        var report = new VerificationReport(
            "il-integrity-03",
            3,
            "passed",
            "Independent ROM-byte decode to IL, unchanged identity compile, one checked same-size operand edit, " +
            "exact full-image diff, output-bound source maps and ordered regeneration of the active gate-00 " +
            "integrity fields. No boot, MAME execution, natural acceptance or runtime Y-observation claim.",
            NineEdNineDecoder.EvidenceClass,
            Path.GetFullPath(romPath),
            rom.Length,
            beforeSha1,
            beforeSha256,
            afterSha1,
            afterSha256,
            beforeSha1 == afterSha1 && beforeSha256 == afterSha256,
            Convert.ToHexString(compile.EmittedBody),
            compile.ChangedOffsets,
            Convert.ToHexString(edited.Compile.EmittedBody),
            editedSha1,
            editedSha256,
            edited.Compile.ChangedOffsets,
            map.RomSha256,
            map.ImageSha256,
            map.IsIdentityBuild,
            map.Entries.Count,
            map.Entries.Count,
            editedMap.ImageSha256,
            editedMap.Entries.Count,
            repairedIntegrity.Report.OriginalStoredFieldsHex,
            repairedIntegrity.Report.UnrepairedStoredFieldsHex,
            repairedIntegrity.Report.RepairedStoredFieldsHex,
            repairedIntegrity.Report.AlgorithmOrder,
            repairedIntegrity.RepairedImageSha1,
            repairedIntegrity.RepairedImageSha256,
            repairedIntegrity.Report.RepairedChangedOffsets,
            repairedIntegrity.Report.RepairChangedOffsets,
            repairedMap.ImageSha256,
            ilReferences,
            verifierReferences,
            checks,
            new[]
            {
                "Only the fixed 9ED9 definition, four tokens and the first 795B operand at 9EDB are supported; " +
                "this is not a general decoder or editor.",
                "Only the active gate-00 record FFD1 is regenerated in the recovered order; the three disabled " +
                "records, checker code and outer gate are preserved unchanged.",
                "The repaired image is algorithmically repaired only; it is not natural boot acceptance, MAME " +
                "execution evidence or physical hardware compatibility.",
                "No MAME launch, natural fresh-boot execution, synthetic invocation or runtime stack observation is performed.",
                "Ordering and field-exclusion checks are synthetic in-memory fault experiments, clearly labelled.",
                "Cited listing/checkpoint/JSON files are verification oracles only; the decoders consume ROM bytes.",
                "Natural paid-window reach is retained as cited provenance, not re-executed or proven here.",
                "Natural reach of 9ED9 and the Y observation boundary remain unproven for this release."
            },
            "M2 remains next: run a natural fresh-boot MAME original control and this algorithmically repaired " +
            "edited image with no injection, observe PC/Y/U/S and resolve 9ED9 execution to IL. Natural 9ED9 " +
            "reach before the first token fetch remains uncertain; algorithmically repaired is not MAME acceptance.");

        WriteOutputs(outputDirectory, report, BuildLog(report));
        Console.WriteLine(
            $"PASS {checks.Count} verification groups; identity compile preserved 65536 bytes, " +
            $"edited compile changed {edited.Compile.ChangedOffsets.Length} byte at 9EDC, " +
            $"ordered repair produced {repairedIntegrity.Report.RepairedStoredFieldsHex} and " +
            $"repaired source map bound to {repairedMap.ImageSha256}.");
        return report;

        void RejectBody(byte[] body, string expected)
        {
            Reject(() => NineEdNineDecoder.DecodeBodyForTests(
                body, 0x9ED9, 0x9EE7), expected);
        }

        void RejectBodyAtEnd(byte[] body, ushort start, int end, string expected)
        {
            Reject(() => NineEdNineDecoder.DecodeBodyForTests(body, start, end), expected);
        }
    }

    private static bool MatchesPinnedHash(string path, string pinned)
    {
        byte[] bytes = File.ReadAllBytes(path);
        if (Hash(bytes) == pinned.ToUpperInvariant()) return true;

        var lf = new List<byte>(bytes.Length);
        for (int index = 0; index < bytes.Length; index++)
        {
            if (bytes[index] == (byte)'\r' && index + 1 < bytes.Length &&
                bytes[index + 1] == (byte)'\n')
                continue;
            lf.Add(bytes[index]);
        }
        if (Hash(lf.ToArray()) == pinned.ToUpperInvariant()) return true;

        var crlf = new List<byte>(bytes.Length + 16);
        for (int index = 0; index < bytes.Length; index++)
        {
            if (bytes[index] == (byte)'\n' &&
                (index == 0 || bytes[index - 1] != (byte)'\r'))
                crlf.Add((byte)'\r');
            crlf.Add(bytes[index]);
        }
        return Hash(crlf.ToArray()) == pinned.ToUpperInvariant();
    }

    private static string Hash(byte[] bytes) =>
        Convert.ToHexString(SHA256.HashData(bytes));

    private static string FormatComputed(VmIlIntegrityComputedFields fields) =>
        $"{fields.Sum:X2}{fields.Xor:X2}{fields.RotateAdd:X2}" +
        $"{fields.RotateSubXorA:X2}{fields.RotateSubXorB:X2}";

    private static string BuildLog(VerificationReport report)
    {
        var builder = new StringBuilder();
        builder.AppendLine("FruitMachineLab il-integrity-03 verification");
        builder.AppendLine("ROM: " + report.RomPath);
        builder.AppendLine("SHA1: " + report.RomSha1Before);
        builder.AppendLine("SHA256: " + report.RomSha256Before);
        builder.AppendLine("ROM length: " + report.RomLength);
        builder.AppendLine("Input unchanged: " + report.InputUnchanged);
        builder.AppendLine("Identity emitted span: " + report.EmittedSpanHex);
        builder.AppendLine("Identity changed offsets: " +
            (report.ChangedOffsets.Length == 0
                ? "none"
                : string.Join(',', report.ChangedOffsets)));
        builder.AppendLine("Edited emitted span: " + report.EditedSpanHex);
        builder.AppendLine("Edited output SHA1: " + report.EditedOutputSha1);
        builder.AppendLine("Edited output SHA256: " + report.EditedOutputSha256);
        builder.AppendLine("Edited changed offsets: " +
            (report.EditedChangedOffsets.Length == 0
                ? "none"
                : string.Join(',', report.EditedChangedOffsets)));
        builder.AppendLine("Source map ROM SHA256: " + report.SourceMapRomSha256);
        builder.AppendLine("Source map image SHA256: " + report.SourceMapImageSha256);
        builder.AppendLine("Source map identity build: " + report.SourceMapIsIdentity);
        builder.AppendLine("Source map span bytes: " + report.SourceMapSpanBytes);
        builder.AppendLine("Edited source map image SHA256: " + report.EditedSourceMapImageSha256);
        builder.AppendLine("Edited source map entries: " + report.EditedSourceMapEntries);
        builder.AppendLine("Integrity original fields: " + report.IntegrityOriginalFieldsHex);
        builder.AppendLine("Integrity unrepaired fields: " + report.IntegrityUnrepairedFieldsHex);
        builder.AppendLine("Integrity repaired fields: " + report.IntegrityRepairedFieldsHex);
        builder.AppendLine("Integrity algorithm order: " + report.IntegrityAlgorithmOrder);
        builder.AppendLine("Repaired output SHA1: " + report.RepairedOutputSha1);
        builder.AppendLine("Repaired output SHA256: " + report.RepairedOutputSha256);
        builder.AppendLine("Repaired changed offsets: " +
            string.Join(',', report.RepairedChangedOffsets));
        builder.AppendLine("Repair-only changed offsets: " +
            string.Join(',', report.RepairChangedOffsets));
        builder.AppendLine("Repaired source map image SHA256: " +
            report.RepairedSourceMapImageSha256);
        builder.AppendLine(
            "Integrity: ALGORITHMICALLY REPAIRED; no MAME acceptance, boot or hardware claim");
        builder.AppendLine("IL references: " + string.Join(", ", report.IlAssemblyReferences));
        builder.AppendLine("Verifier references: " +
            string.Join(", ", report.VerifierAssemblyReferences));
        foreach (VerificationCheck check in report.Checks)
            builder.AppendLine("PASS " + check.Name);
        builder.AppendLine("Classification: " + report.Classification);
        foreach (string limitation in report.Limitations)
            builder.AppendLine("LIMIT " + limitation);
        builder.AppendLine("NEXT " + report.RemainingChainBoundary);
        builder.AppendLine("STATUS " + report.Status);
        return builder.ToString();
    }

    private static void WriteOutputs(
        string outputDirectory, VerificationReport report, string log)
    {
        Directory.CreateDirectory(outputDirectory);
        VerificationOutputs.WriteCreateOnly(
            Path.Combine(outputDirectory, "verification.log"), log);
        string json = JsonSerializer.Serialize(
            report, new JsonSerializerOptions { WriteIndented = true });
        VerificationOutputs.WriteCreateOnly(
            Path.Combine(outputDirectory, "verification-report.json"), json + Environment.NewLine);
    }

    private static void WriteFailureOutputs(
        string outputDirectory, IReadOnlyList<VerificationCheck> checks)
    {
        if (Directory.Exists(outputDirectory)) return;
        Directory.CreateDirectory(outputDirectory);
        var builder = new StringBuilder();
        builder.AppendLine("FruitMachineLab il-integrity-03 verification FAILED");
        foreach (VerificationCheck check in checks)
            builder.AppendLine((check.Passed ? "PASS " : "FAIL ") + check.Name +
                (check.Error is null ? string.Empty : ": " + check.Error));
        builder.AppendLine("STATUS failed");
        try
        {
            VerificationOutputs.WriteCreateOnly(
                Path.Combine(outputDirectory, "verification.failure.log"),
                builder.ToString());
        }
        catch (IOException)
        {
        }
    }
}

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
    string SourceMapRomSha256,
    int SourceMapSpanBytes,
    int SourceMapEntries,
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
        var report = new VerificationReport(
            "il-impl-01",
            1,
            "passed",
            "Independent ROM-byte decode to IL, unchanged identity compile and Y-addressed source map. " +
            "No CPU-PC-to-IL or runtime Y-observation-phase claim.",
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
            map.RomSha256,
            map.Entries.Count,
            map.Entries.Count,
            ilReferences,
            verifierReferences,
            checks,
            new[]
            {
                "Only the fixed 9ED9 definition and four tokens are supported; this is not a general decoder.",
                "The ROM is read-only; no operand edit, integrity repair, repaired image or create-only ROM output is performed.",
                "No MAME launch, natural fresh-boot execution, synthetic invocation or runtime stack observation is performed.",
                "Cited listing/checkpoint/JSON files are verification oracles only; the decoder consumes ROM bytes.",
                "Natural paid-window reach is retained as cited provenance, not re-executed or proven here."
            },
            "M2 remains next: edit the first literal FF80->FF00 at 9EDC, validate a separately evidenced integrity repair, " +
            "run natural fresh-boot MAME execution and resolve observed PC/Y/U/S to IL. That work is not authorized here.");

        WriteOutputs(outputDirectory, report, BuildLog(report));
        Console.WriteLine(
            $"PASS {checks.Count} verification groups; identity compile preserved 65536 bytes " +
            $"with {compile.ChangedOffsets.Length} changed offsets.");
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

    private static string BuildLog(VerificationReport report)
    {
        var builder = new StringBuilder();
        builder.AppendLine("FruitMachineLab il-impl-01 verification");
        builder.AppendLine("ROM: " + report.RomPath);
        builder.AppendLine("SHA1: " + report.RomSha1Before);
        builder.AppendLine("SHA256: " + report.RomSha256Before);
        builder.AppendLine("ROM length: " + report.RomLength);
        builder.AppendLine("Input unchanged: " + report.InputUnchanged);
        builder.AppendLine("Emitted span: " + report.EmittedSpanHex);
        builder.AppendLine("Changed offsets: " +
            (report.ChangedOffsets.Length == 0
                ? "none"
                : string.Join(',', report.ChangedOffsets)));
        builder.AppendLine("Source map ROM SHA256: " + report.SourceMapRomSha256);
        builder.AppendLine("Source map span bytes: " + report.SourceMapSpanBytes);
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
        builder.AppendLine("FruitMachineLab il-impl-01 verification FAILED");
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

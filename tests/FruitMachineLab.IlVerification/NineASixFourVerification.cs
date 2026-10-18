using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using FruitMachineLab.Il;

namespace FruitMachineLab.IlVerification;

internal sealed record NineASixFourCheck(string Name, bool Passed, string? Error);

internal sealed record NineASixFourNodeReport(
    int Index,
    string Address,
    string Token,
    string Operation,
    string BytesHex,
    string? BranchTarget,
    string? BranchCondition,
    string? BranchOperandAddress,
    string? BranchOperandByte,
    string? BranchOffsetBase,
    bool? BranchOffsetUnsigned);

internal sealed record NineASixFourBranchReport(
    string TokenAddress,
    string OperandAddress,
    string OperandByte,
    string TargetAddress,
    string Condition,
    string OffsetBase,
    bool OffsetUnsigned,
    int OperandWidthBytes,
    string EvidenceClass);

internal sealed record NineASixFourInstructionReport(
    string Address,
    string BytesHex,
    string Mnemonic,
    string Operand);

internal sealed record NineASixFourHandlerReport(
    string TokenAddress,
    string HandlerAddress,
    string Operation,
    string Condition,
    IReadOnlyList<NineASixFourInstructionReport> Instructions,
    string Semantics);

internal sealed record NineASixFourVerificationReport(
    string TaskId,
    int SchemaVersion,
    string Status,
    string Classification,
    string EvidenceClass,
    string RomPath,
    int RomLength,
    string RomSha1,
    string RomSha256,
    string HeaderAddress,
    string HeaderHex,
    string BodyStart,
    string BodyEndExclusive,
    string SpanHex,
    int NodeCount,
    IReadOnlyList<NineASixFourNodeReport> Nodes,
    IReadOnlyList<NineASixFourBranchReport> Branches,
    IReadOnlyList<NineASixFourHandlerReport> Handlers,
    string IdentityEmittedSpanHex,
    int[] IdentityChangedOffsets,
    string IdentityOutputSha256,
    bool IdentityImageUnchanged,
    string SourceMapRomSha256,
    string SourceMapImageSha256,
    bool SourceMapIsIdentity,
    int SourceMapEntries,
    int SourceMapBranches,
    string SourceMapEvidenceClass,
    IReadOnlyList<NineASixFourCheck> Checks,
    IReadOnlyList<string> Limitations,
    string RemainingChainBoundary);

internal static class NineASixFourVerification
{
    private const string ExpectedSpanHex = "7B6D79820676657979037671792F";

    private static readonly (ushort Address, ushort Token, string Operation)[]
        ExpectedNodes =
        {
            (0x9A64, 0x7B6D, "vm_rotate_three_cells"),
            (0x9A66, 0x7982, "vm_branch_forward8_if_zero"),
            (0x9A69, 0x7665, "vm_or_word_memory"),
            (0x9A6B, 0x7979, "vm_branch_unsigned_forward8"),
            (0x9A6E, 0x7671, "vm_clear_word_memory_bits"),
            (0x9A70, 0x792F, "vm_return_to_caller_stream")
        };

    private static readonly (ushort Address, ushort Token, byte Operand, ushort Target,
        VmIlBranchCondition Condition)[] ExpectedBranches =
        {
            (0x9A66, 0x7982, 0x06, 0x9A6E, VmIlBranchCondition.IfZero),
            (0x9A6B, 0x7979, 0x03, 0x9A70, VmIlBranchCondition.Always)
        };

    public static NineASixFourVerificationReport Run(
        string romPath, string repositoryRoot, string outputDirectory)
    {
        if (Directory.Exists(outputDirectory))
            throw new IOException($"Output directory already exists: {outputDirectory}");

        byte[] rom = File.ReadAllBytes(romPath);
        string romSha1 = Convert.ToHexString(SHA1.HashData(rom));
        string romSha256 = Convert.ToHexString(SHA256.HashData(rom));
        var checks = new List<NineASixFourCheck>();
        VmIlDefinition definition = null!;
        VmIlCompileResult compile = null!;
        VmIlSourceMap map = null!;
        IReadOnlyList<NineASixFourBranchHandler> handlers = Array.Empty<NineASixFourBranchHandler>();

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
                checks.Add(new NineASixFourCheck(name, true, null));
                Console.WriteLine("PASS " + name);
            }
            catch (Exception error)
            {
                checks.Add(new NineASixFourCheck(name, false, error.Message));
                throw new InvalidOperationException($"Check failed: {name}: {error.Message}", error);
            }
        }

        string EvidencePath(params string[] parts) =>
            Path.Combine(new[] { repositoryRoot, "evidence", "mpu4" }.Concat(parts).ToArray());

        void RejectImage(byte[] image, string expected)
        {
            Reject(() => NineASixFourDecoder.DecodeImageWithoutIdentityForTests(
                image,
                NineASixFourDecoder.HeaderAddress,
                NineASixFourDecoder.HeaderValue,
                NineASixFourDecoder.BodyStart,
                NineASixFourDecoder.BodyEndExclusive), expected);
        }

        try
        {
            Check("Original ROM identity and 9A64 header decode", () =>
            {
                Assert(rom.Length == NineASixFourDecoder.RequiredRomLength, "ROM length differs");
                Assert(romSha1 == NineASixFourDecoder.RequiredRomSha1, "ROM SHA1 differs");
                Assert(romSha256 == NineASixFourDecoder.RequiredRomSha256, "ROM SHA256 differs");

                definition = NineASixFourDecoder.Decode(rom);
                Assert(definition.RomLength == rom.Length, "Definition ROM length differs");
                Assert(definition.RomSha1 == romSha1, "Definition SHA1 differs");
                Assert(definition.RomSha256 == romSha256, "Definition SHA256 differs");
                Assert(definition.HeaderAddress == 0x9A62, "Header address differs");
                Assert(Convert.ToHexString(definition.HeaderBytes) == "00F8", "Header value differs");
                Assert(definition.BodyStart == 0x9A64, "Body start differs");
                Assert(definition.BodyEndExclusive == 0x9A72, "Definition end differs");
                Assert(definition.BodyLength == 14, "Definition length differs");
                Assert(definition.Provenance.ObservedSites == 6, "Observed site count differs");
                Assert(!definition.Provenance.EvidenceClass.Contains("natural execution proof",
                    StringComparison.OrdinalIgnoreCase), "Provenance overclaims natural execution");
                Assert(definition.Provenance.EvidenceClass.Contains("not natural",
                    StringComparison.OrdinalIgnoreCase), "Provenance does not distinguish static decode");
            });

            Check("Six 9A64 nodes and two byte branches decode from original bytes", () =>
            {
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
                    expected.BytesFromRom(rom).SequenceEqual(node.Bytes)
                        .OrFail($"Node {index} bytes differ from the ROM");
                    expected.LiteralsAbsent(node);
                }

                Assert(definition.Nodes[0].Branch is null, "Rotate node has a branch");
                Assert(definition.Nodes[2].Branch is null, "OR-memory node has a branch");
                Assert(definition.Nodes[4].Branch is null, "Clear-memory node has a branch");
                Assert(definition.Nodes[5].Branch is null, "Return node has a branch");

                for (int index = 0; index < ExpectedBranches.Length; index++)
                {
                    var expected = ExpectedBranches[index];
                    VmIlNode node = definition.Nodes[index == 0 ? 1 : 3];
                    Assert(node.Address == expected.Address, $"Branch {index} address differs");
                    Assert(node.Token == expected.Token, $"Branch {index} token differs");
                    Assert(node.Bytes.Length == 3, $"Branch {index} byte width differs");
                    Assert(node.Bytes[2] == expected.Operand, $"Branch {index} operand differs");
                    VmIlBranch branch = node.Branch ??
                        throw new InvalidDataException($"Branch {index} model is missing");
                    Assert(branch.HandlerAddress == expected.Token + 2,
                        $"Branch {index} handler address differs");
                    Assert(branch.OperandAddress == expected.Address + 2,
                        $"Branch {index} operand address differs");
                    Assert(branch.OperandByte == expected.Operand,
                        $"Branch {index} operand byte differs");
                    Assert(branch.TargetAddress == expected.Target,
                        $"Branch {index} target differs");
                    Assert(branch.Condition == expected.Condition,
                        $"Branch {index} condition differs");
                    Assert(branch.OffsetBase == "operand-address",
                        $"Branch {index} offset base differs");
                    Assert(branch.OffsetUnsigned, $"Branch {index} signedness differs");
                    Assert(branch.OperandWidthBytes == 1,
                        $"Branch {index} operand width differs");
                    Assert(branch.EvidenceClass.Contains("Static decoded contract",
                        StringComparison.OrdinalIgnoreCase),
                        $"Branch {index} evidence is not classified as a static decoded contract");
                    Assert(branch.EvidenceClass.Contains("No natural",
                        StringComparison.OrdinalIgnoreCase),
                        $"Branch {index} evidence overclaims natural execution");
                }

                Assert(Convert.ToHexString(
                        rom.AsSpan(definition.BodyStart, definition.BodyLength)) ==
                    ExpectedSpanHex, "Original span differs from the checked fixture");
            });

            Check("797B and 7984 handlers decode to the checked byte-branch contracts", () =>
            {
                handlers = NineASixFourDecoder.DecodeBranchHandlers(rom);
                Assert(handlers.Count == 2, "Handler count differs");

                NineASixFourBranchHandler unsigned = handlers[0];
                Assert(unsigned.TokenAddress == 0x7979, "Unsigned token differs");
                Assert(unsigned.HandlerAddress == 0x797B, "Unsigned handler differs");
                Assert(unsigned.Condition == VmIlBranchCondition.Always, "Unsigned condition differs");
                AssertInstructions(unsigned, new[]
                {
                    (0x797B, "E6A4", "LDAB", ",Y"),
                    (0x797D, "4F", "CLRA", ""),
                    (0x797E, "31AB", "LEAY", "D,Y"),
                    (0x7980, "0EFC", "JMP", "<$FC")
                });

                NineASixFourBranchHandler ifZero = handlers[1];
                Assert(ifZero.TokenAddress == 0x7982, "If-zero token differs");
                Assert(ifZero.HandlerAddress == 0x7984, "If-zero handler differs");
                Assert(ifZero.Condition == VmIlBranchCondition.IfZero, "If-zero condition differs");
                AssertInstructions(ifZero, new[]
                {
                    (0x7984, "ECC1", "LDD", ",U++"),
                    (0x7986, "27F3", "BEQ", "$797B"),
                    (0x7988, "3121", "LEAY", "1,Y"),
                    (0x798A, "0EFC", "JMP", "<$FC")
                });

                Assert(rom.AsSpan(0x7979, 2).SequenceEqual(new byte[] { 0x79, 0x7B }),
                    "7979 token header does not point at 797B");
                Assert(rom.AsSpan(0x7982, 2).SequenceEqual(new byte[] { 0x79, 0x84 }),
                    "7982 token header does not point at 7984");
                Assert(rom.AsSpan(0x797B, 7).SequenceEqual(
                        new byte[] { 0xE6, 0xA4, 0x4F, 0x31, 0xAB, 0x0E, 0xFC }),
                    "797B handler bytes differ");
                Assert(rom.AsSpan(0x7984, 8).SequenceEqual(
                        new byte[] { 0xEC, 0xC1, 0x27, 0xF3, 0x31, 0x21, 0x0E, 0xFC }),
                    "7984 handler bytes differ");
            });

            Check("Unchanged 9A64 body and complete image compile byte-identically", () =>
            {
                compile = VmIlCompiler.CompileIdentity(definition, rom);
                Assert(compile.ChangedOffsets.Length == 0, "Identity compile changed bytes");
                Assert(compile.Image.Length == rom.Length, "Identity image length differs");
                Assert(compile.Image.SequenceEqual(rom), "Identity image differs from the input");
                Assert(compile.OutputSha256 == romSha256, "Identity output SHA256 differs");
                Assert(compile.EmittedBody.SequenceEqual(
                        rom.AsSpan(definition.BodyStart, definition.BodyLength).ToArray()),
                    "Identity emitted span differs");
                Assert(Convert.ToHexString(compile.EmittedBody) == ExpectedSpanHex,
                    "Identity emitted hex differs");
            });

            Check("Source map binds the exact identity image and exposes checked branches", () =>
            {
                map = VmIlSourceMap.Create(definition);
                Assert(map.RomSha256 == romSha256, "Map ROM SHA256 differs");
                Assert(map.ImageSha256 == romSha256, "Map image SHA256 differs");
                Assert(map.IsIdentityBuild, "Map does not report an identity build");
                Assert(map.Entries.Count == definition.BodyLength, "Map entry count differs");
                Assert(map.Branches.Count == 2, "Map branch count differs");
                Assert(map.Provenance.EvidenceClass == definition.Provenance.EvidenceClass,
                    "Map provenance differs from the definition");
                Assert(map.Provenance.ObservedSites == 6, "Map observed site count differs");

                for (int address = definition.BodyStart;
                     address < definition.BodyEndExclusive;
                     address++)
                {
                    VmIlSourceMapEntry entry = map.Resolve((ushort)address);
                    Assert(entry.NodeIndex >= 0 && entry.NodeIndex < definition.Nodes.Count,
                        $"Map node index differs at {address:X4}");
                    Assert(entry.ImageByte == rom[address],
                        $"Map image byte differs at {address:X4}");
                    VmIlNode node = definition.Nodes[entry.NodeIndex];
                    Assert(entry.Token == node.Token && entry.Operation == node.Operation,
                        $"Map token/operation differs at {address:X4}");
                }

                foreach (VmIlSourceMapBranch branch in map.Branches)
                {
                    VmIlNode node = definition.Nodes[branch.NodeIndex];
                    Assert(node.Address == branch.TokenAddress,
                        $"Map branch token address differs at {branch.TokenAddress:X4}");
                    Assert(map.Resolve(branch.TokenAddress).ImageByte == (rom[branch.TokenAddress]),
                        "Map branch token byte differs");
                    Assert(map.Resolve(branch.OperandAddress).ImageByte == branch.OperandByte,
                        $"Map branch operand byte differs at {branch.OperandAddress:X4}");
                    Assert(branch.OperandByte == rom[branch.OperandAddress],
                        "Map branch operand differs from the ROM");
                    Assert(branch.TargetAddress == (ushort)(branch.OperandAddress + branch.OperandByte),
                        "Map branch target arithmetic differs");
                    Assert(map.Resolve(branch.TargetAddress).NodeIndex ==
                        definition.Nodes.Single(
                            item => item.Address == branch.TargetAddress).Index,
                        "Map branch target does not resolve to its boundary node");
                    VmIlSourceMapBranch resolved = map.ResolveBranch(branch.TokenAddress);
                    Assert(resolved == branch, "ResolveBranch returned a different branch");
                }

                VmIlSourceMap built = VmIlSourceMap.CreateForBuild(
                    definition, compile.Image, compile.EmittedBody);
                Assert(built.IsIdentityBuild, "Built map is not bound to the identity image");
                Assert(built.ResolveBranch(0x9A66, compile.OutputSha256).TargetAddress == 0x9A6E,
                    "Built map branch binding differs");
                Reject(() => built.ResolveBranch(0x9A66, "00"),
                    "identity mismatch");
                Reject(() => built.ResolveBranch(0x9A64),
                    "not a checked branch");
                Reject(() => VmIlSourceMap.CreateForBuild(
                        definition, compile.Image, compile.EmittedBody[..^1]),
                    "body length");
            });

            Check("Malformed 9A64 bytes are rejected from permitted original-ROM evidence", () =>
            {
                Reject(() => NineASixFourDecoder.Decode(rom.AsSpan(0, rom.Length - 1).ToArray()),
                    "length");
                byte[] tampered = rom.ToArray();
                tampered[0x1234] ^= 0xFF;
                Reject(() => NineASixFourDecoder.Decode(tampered), "SHA1");

                byte[] image = rom.ToArray();
                image[NineASixFourDecoder.HeaderAddress + 1] ^= 0xFF;
                RejectImage(image, "header");

                image = rom.ToArray();
                image[0x9A64] = 0x79;
                image[0x9A65] = 0x5B;
                RejectImage(image, "outside the supported 9A64");

                image = rom.ToArray();
                image[0x7982] = 0x79;
                image[0x7983] = 0x85;
                RejectImage(image, "points at");

                image = rom.ToArray();
                image[0x797B] = 0xE7;
                RejectImage(image, "unsupported");

                image = rom.ToArray();
                image[0x9A68] = 0x00;
                RejectImage(image, "inside or before its operand");

                image = rom.ToArray();
                image[0x9A68] = 0x02;
                RejectImage(image, "not an instruction boundary");

                image = rom.ToArray();
                image[0x9A68] = 0x05;
                RejectImage(image, "not an instruction boundary");

                image = rom.ToArray();
                image[0x9A68] = 0x7F;
                RejectImage(image, "outside the definition span");

                image = rom.ToArray();
                image[0x9A70] = 0x76;
                image[0x9A71] = 0x65;
                RejectImage(image, "return");
            });

            Check("Forged branch plans are rejected despite full original-ROM identity", () =>
            {
                VmIlNode[] nodes = definition.Nodes.ToArray();
                int branchIndex = 1;
                VmIlNode branchNode = nodes[branchIndex];
                VmIlBranch branch = branchNode.Branch!;

                nodes[branchIndex] = branchNode with { Branch = null };
                Reject(() => VmIlCompiler.CompileIdentity(
                        definition with { Nodes = nodes }, rom),
                    "missing its checked branch model");
                Reject(() => VmIlSourceMap.Create(definition with { Nodes = nodes }),
                    "has no checked branch model");

                nodes = definition.Nodes.ToArray();
                nodes[branchIndex] = branchNode with
                {
                    Branch = branch with { TargetAddress = 0x9A69 }
                };
                Reject(() => VmIlCompiler.CompileIdentity(
                        definition with { Nodes = nodes }, rom),
                    "does not match its operand byte");
                Reject(() => VmIlSourceMap.Create(definition with { Nodes = nodes }),
                    "does not match operand-address");

                nodes = definition.Nodes.ToArray();
                nodes[branchIndex] = branchNode with
                {
                    Branch = branch with { OperandByte = 0x05 }
                };
                Reject(() => VmIlCompiler.CompileIdentity(
                        definition with { Nodes = nodes }, rom),
                    "does not match its original byte");

                nodes = definition.Nodes.ToArray();
                nodes[branchIndex] = branchNode with
                {
                    Bytes = new byte[] { 0x79, 0x82, 0x02 },
                    Branch = branch with
                    {
                        OperandByte = 0x02,
                        TargetAddress = 0x9A6A
                    }
                };
                Reject(() => VmIlSourceMap.Create(definition with { Nodes = nodes }),
                    "not an instruction boundary");

                nodes = definition.Nodes.ToArray();
                nodes[branchIndex] = branchNode with
                {
                    Bytes = new byte[] { 0x79, 0x82, 0x7F },
                    Branch = branch with
                    {
                        OperandByte = 0x7F,
                        TargetAddress = 0x9AE7
                    }
                };
                Reject(() => VmIlSourceMap.Create(definition with { Nodes = nodes }),
                    "outside the definition span");

                nodes = definition.Nodes.ToArray();
                nodes[branchIndex] = branchNode with
                {
                    Branch = branch with { OperandWidthBytes = 2 }
                };
                Reject(() => VmIlCompiler.CompileIdentity(
                        definition with { Nodes = nodes }, rom),
                    "wrong operand width");

                nodes = definition.Nodes.ToArray();
                nodes[branchIndex] = branchNode with
                {
                    Branch = branch with { Condition = VmIlBranchCondition.Always }
                };
                Reject(() => VmIlCompiler.CompileIdentity(
                        definition with { Nodes = nodes }, rom),
                    "does not match its token");

                nodes = definition.Nodes.ToArray();
                nodes[branchIndex] = branchNode with
                {
                    Branch = branch with { OffsetUnsigned = false }
                };
                Reject(() => VmIlCompiler.CompileIdentity(
                        definition with { Nodes = nodes }, rom),
                    "unsupported offset semantics");

                nodes = definition.Nodes.ToArray();
                nodes[branchIndex] = branchNode with
                {
                    Branch = branch with { HandlerAddress = 0x9A66 }
                };
                Reject(() => VmIlCompiler.CompileIdentity(
                        definition with { Nodes = nodes }, rom),
                    "does not follow node");

                Reject(() => VmIlCompiler.CompileEdit(
                        rom, new VmIlOperandEdit(0x9A68, 0x0006, 0x0003)),
                    "Unsupported edit operand address");
            });

            Check("Tracked 9A64 evidence agrees with the decoded plan and image", () =>
            {
                string evidencePath = EvidencePath("integrity", "il-9a64-decode.json");
                using JsonDocument document = JsonDocument.Parse(
                    File.ReadAllText(evidencePath));
                JsonElement root = document.RootElement;
                Assert(root.GetProperty("Status").GetString() == "passed",
                    "Tracked evidence status differs");
                JsonElement original = root.GetProperty("OriginalRom");
                Assert(original.GetProperty("Length").GetInt32() == rom.Length,
                    "Tracked evidence ROM length differs");
                Assert(original.GetProperty("Sha1").GetString() == romSha1,
                    "Tracked evidence ROM SHA1 differs");
                Assert(original.GetProperty("Sha256").GetString() == romSha256,
                    "Tracked evidence ROM SHA256 differs");
                JsonElement decoded = root.GetProperty("Definition");
                Assert(decoded.GetProperty("HeaderAddress").GetString() == "9A62" &&
                       decoded.GetProperty("HeaderHex").GetString() == "00F8",
                    "Tracked evidence header differs");
                Assert(decoded.GetProperty("BodyStart").GetString() == "9A64" &&
                       decoded.GetProperty("BodyEndExclusive").GetString() == "9A72",
                    "Tracked evidence body boundaries differ");
                Assert(decoded.GetProperty("SpanHex").GetString() == ExpectedSpanHex,
                    "Tracked evidence span differs");
                Assert(decoded.GetProperty("ObservedSites").GetInt32() == 6,
                    "Tracked evidence observed sites differ");
                Assert(root.GetProperty("Branches").GetArrayLength() == 2,
                    "Tracked evidence branch count differs");
                Assert(root.GetProperty("IdentityCompile").GetProperty("OutputSha256")
                        .GetString() == compile.OutputSha256,
                    "Tracked evidence identity output differs");
                Assert(root.GetProperty("SourceMap").GetProperty("ImageSha256")
                        .GetString() == map.ImageSha256,
                    "Tracked evidence source-map image differs");
                Assert(root.GetProperty("SourceMap").GetProperty("Branches").GetInt32() == 2,
                    "Tracked evidence source-map branch count differs");
                Assert(root.GetProperty("NegativeControls").GetArrayLength() >= 8,
                    "Tracked evidence lacks negative controls");
            });

            Check("Cited 9A64 listing and checkpoint provenance hashes agree", () =>
            {
                Assert(MatchesPinnedHash(
                        EvidencePath("VM-SCRIPTS", "9A64.txt"),
                        NineASixFourDecoder.ListingSha256),
                    "9A64 listing SHA256 differs");
                string checkpoint = File.ReadAllText(EvidencePath(
                    "maps", "nudge-encoding-checkpoint.json"));
                Assert(checkpoint.Contains("\"span_hex\": \"7B6D79820676657979037671792F\"",
                        StringComparison.Ordinal),
                    "Checkpoint span was not found");
                Assert(checkpoint.Contains("branch=0x9A6E", StringComparison.Ordinal) &&
                       checkpoint.Contains("branch=0x9A70", StringComparison.Ordinal),
                    "Checkpoint branch targets were not found");
            });
        }
        catch
        {
            WriteFailureOutputs(outputDirectory, checks);
            throw;
        }

        byte[] finalBytes = File.ReadAllBytes(romPath);
        Assert(Convert.ToHexString(SHA1.HashData(finalBytes)) == romSha1,
            "Input ROM SHA1 changed during verification");
        Assert(Convert.ToHexString(SHA256.HashData(finalBytes)) == romSha256,
            "Input ROM SHA256 changed during verification");

        var nodesReport = definition.Nodes.Select(node =>
        {
            VmIlBranch? branch = node.Branch;
            return new NineASixFourNodeReport(
                node.Index,
                $"{node.Address:X4}",
                $"{node.Token:X4}",
                node.Operation,
                Convert.ToHexString(node.Bytes),
                branch is null ? null : $"{branch.TargetAddress:X4}",
                branch is null ? null : branch.Condition.ToString(),
                branch is null ? null : $"{branch.OperandAddress:X4}",
                branch is null ? null : $"{branch.OperandByte:X2}",
                branch?.OffsetBase,
                branch?.OffsetUnsigned);
        }).ToArray();

        var branchesReport = map.Branches.Select(branch => new NineASixFourBranchReport(
            $"{branch.TokenAddress:X4}",
            $"{branch.OperandAddress:X4}",
            $"{branch.OperandByte:X2}",
            $"{branch.TargetAddress:X4}",
            branch.Condition.ToString(),
            branch.OffsetBase,
            branch.OffsetUnsigned,
            branch.OperandWidthBytes,
            branch.EvidenceClass)).ToArray();

        var handlersReport = handlers.Select(handler => new NineASixFourHandlerReport(
            $"{handler.TokenAddress:X4}",
            $"{handler.HandlerAddress:X4}",
            handler.Operation,
            handler.Condition.ToString(),
            handler.Instructions.Select(instruction => new NineASixFourInstructionReport(
                $"{instruction.Address:X4}",
                Convert.ToHexString(instruction.Bytes),
                instruction.Mnemonic,
                instruction.Operand)).ToArray(),
            handler.Semantics)).ToArray();

        var report = new NineASixFourVerificationReport(
            "il-9a64-local-13",
            1,
            "passed",
            "Independent static decode of the original 9A64 definition, checked byte-sized branch " +
            "representation with explicit targets, identity compile and source-map binding. No " +
            "natural 9A64 execution, edit, MAME run, hardware or extension claim.",
            NineASixFourDecoder.EvidenceClass,
            Path.GetFullPath(romPath),
            rom.Length,
            romSha1,
            romSha256,
            $"{definition.HeaderAddress:X4}",
            Convert.ToHexString(definition.HeaderBytes),
            $"{definition.BodyStart:X4}",
            $"{definition.BodyEndExclusive:X4}",
            Convert.ToHexString(compile.EmittedBody),
            definition.Nodes.Count,
            nodesReport,
            branchesReport,
            handlersReport,
            Convert.ToHexString(compile.EmittedBody),
            compile.ChangedOffsets,
            compile.OutputSha256,
            compile.Image.SequenceEqual(rom),
            map.RomSha256,
            map.ImageSha256,
            map.IsIdentityBuild,
            map.Entries.Count,
            map.Branches.Count,
            map.Provenance.EvidenceClass,
            checks,
            new[]
            {
                "Only the six tokens used by 9A64 and the two checked byte-branch handlers are supported; " +
                "this is not a general decoder.",
                "Branch base, signedness (unsigned), one-byte width and target arithmetic are static " +
                "deductions from the original 6809 handler bytes; they are not natural execution evidence.",
                "No 9A64 edit, operand replacement, relocation, linker, extension allocation or new-word " +
                "support is implemented.",
                "No MAME launch, natural 9A64 branch execution, runtime path coverage or hardware test " +
                "was performed.",
                "The original 9ED9 decode/edit/integrity behavior is established by the preceding focused " +
                "verifier; this verifier is additive.",
                "The cited listing and checkpoint are verification oracles only; branch contracts come " +
                "from original ROM bytes."
            },
            "Natural reachability and branch-path observation for 9A64 remain separate supervisor-selected " +
            "work. Do not extend the paused debugger to 9A64 until that observation task is authorized.");

        WriteOutputs(outputDirectory, report);
        Console.WriteLine(
            $"PASS {checks.Count} 9A64 verification groups; identity compile preserved 65536 bytes, " +
            $"two checked byte branches target 9A6E/9A70, source map bound to {map.ImageSha256}.");
        return report;
    }

    private static void AssertInstructions(
        NineASixFourBranchHandler handler,
        IReadOnlyList<(int Address, string Bytes, string Mnemonic, string Operand)> expected)
    {
        if (handler.Instructions.Count != expected.Count)
            throw new InvalidDataException(
                $"Handler {handler.HandlerAddress:X4} instruction count differs");
        for (int index = 0; index < expected.Count; index++)
        {
            NineASixFourHandlerInstruction instruction = handler.Instructions[index];
            var item = expected[index];
            if (instruction.Address != item.Address ||
                Convert.ToHexString(instruction.Bytes) != item.Bytes ||
                instruction.Mnemonic != item.Mnemonic ||
                instruction.Operand != item.Operand)
                throw new InvalidDataException(
                    $"Handler {handler.HandlerAddress:X4} instruction {index} differs");
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

    private static void WriteOutputs(
        string outputDirectory, NineASixFourVerificationReport report)
    {
        Directory.CreateDirectory(outputDirectory);
        string json = JsonSerializer.Serialize(
            report, new JsonSerializerOptions { WriteIndented = true });
        VerificationOutputs.WriteCreateOnly(
            Path.Combine(outputDirectory, "verification-report.json"), json + Environment.NewLine);
        VerificationOutputs.WriteCreateOnly(
            Path.Combine(outputDirectory, "il-9a64-decode.json"), json + Environment.NewLine);
        var log = new StringBuilder();
        log.AppendLine("FruitMachineLab il-9a64-local-13 verification");
        log.AppendLine("ROM SHA1: " + report.RomSha1);
        log.AppendLine("ROM SHA256: " + report.RomSha256);
        log.AppendLine("Header: " + report.HeaderAddress + " " + report.HeaderHex);
        log.AppendLine("Span: " + report.SpanHex);
        log.AppendLine("Nodes: " + report.NodeCount + ", branches: " + report.Branches.Count);
        log.AppendLine("Identity changed offsets: " +
            (report.IdentityChangedOffsets.Length == 0
                ? "none"
                : string.Join(',', report.IdentityChangedOffsets)));
        log.AppendLine("Source map image SHA256: " + report.SourceMapImageSha256);
        log.AppendLine("Source map branches: " + report.SourceMapBranches);
        log.AppendLine("Evidence: static decoded contract; no natural 9A64 execution");
        foreach (NineASixFourCheck check in report.Checks)
            log.AppendLine("PASS " + check.Name);
        foreach (string limitation in report.Limitations)
            log.AppendLine("LIMIT " + limitation);
        log.AppendLine("NEXT " + report.RemainingChainBoundary);
        log.AppendLine("STATUS " + report.Status);
        VerificationOutputs.WriteCreateOnly(
            Path.Combine(outputDirectory, "verification.log"), log.ToString());
    }

    private static void WriteFailureOutputs(
        string outputDirectory, IReadOnlyList<NineASixFourCheck> checks)
    {
        if (Directory.Exists(outputDirectory)) return;
        Directory.CreateDirectory(outputDirectory);
        var builder = new StringBuilder();
        builder.AppendLine("FruitMachineLab il-9a64-local-13 verification FAILED");
        foreach (NineASixFourCheck check in checks)
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

    private static byte[] BytesFromRom(
        this (ushort Address, ushort Token, string Operation) expected, byte[] rom)
    {
        int length = expected.Token is 0x7982 or 0x7979 ? 3 : 2;
        return rom.AsSpan(expected.Address, length).ToArray();
    }

    private static void OrFail(this bool condition, string message)
    {
        if (!condition) throw new InvalidDataException(message);
    }

    private static void LiteralsAbsent(
        this (ushort Address, ushort Token, string Operation) expected, VmIlNode node)
    {
        if (expected.Token is 0x7982 or 0x7979)
        {
            if (node.Operand is not null)
                throw new InvalidDataException(
                    $"Node {node.Index} branch unexpectedly has an inline operand");
            return;
        }
        if (node.Operand is not null || node.Branch is not null)
            throw new InvalidDataException(
                $"Node {node.Index} unexpectedly has an operand or branch");
    }
}

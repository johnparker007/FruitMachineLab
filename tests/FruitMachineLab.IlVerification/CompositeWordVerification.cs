using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using FruitMachineLab.Il;

namespace FruitMachineLab.IlVerification;

internal sealed record CompositeWordVerificationCheck(string Name, bool Passed, string? Error);

internal sealed record CompositeWordVerificationReport(
    string TaskId,
    int SchemaVersion,
    string Status,
    string Classification,
    string RomPath,
    int RomLength,
    string RomSha1Before,
    string RomSha256Before,
    string RomSha1After,
    string RomSha256After,
    bool InputUnchanged,
    string HeaderHex,
    string BodyHex,
    string CallerOriginalTokenHex,
    string CallerReplacementTokenHex,
    string UnrepairedSha1,
    string UnrepairedSha256,
    int[] UnrepairedChangedOffsets,
    string OutputSha1,
    string OutputSha256,
    int[] ChangedOffsets,
    int ChangedCount,
    string IntegrityOriginalFieldsHex,
    string IntegrityRepairedFieldsHex,
    string IntegrityAlgorithmOrder,
    int[] RepairChangedOffsets,
    string MapBuildId,
    int MapEntryCount,
    int MapPhaseCount,
    string CallerSavedCursorHex,
    string CallerPostReturnTokenHex,
    IReadOnlyList<CompositeWordVerificationCheck> Checks,
    IReadOnlyList<string> Limitations,
    string RemainingBoundary);

internal static class CompositeWordVerification
{
    public static void Run(string romPath, string repositoryRoot, string outputDirectory)
    {
        if (Directory.Exists(outputDirectory))
            throw new IOException($"Output directory already exists: {outputDirectory}");

        byte[] rom = File.ReadAllBytes(romPath);
        byte[] originalSnapshot = (byte[])rom.Clone();
        string beforeSha1 = Sha1(rom);
        string beforeSha256 = Sha256(rom);
        var checks = new List<CompositeWordVerificationCheck>();
        CompositeWordBuildResult build = null!;
        JsonElement contractRoot = default;

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

        void RejectReadOnly(Action action, string label)
        {
            try
            {
                action();
            }
            catch (NotSupportedException)
            {
                return;
            }
            throw new InvalidDataException($"{label} accepted caller mutation");
        }

        void Check(string name, Action action)
        {
            try
            {
                action();
                checks.Add(new CompositeWordVerificationCheck(name, true, null));
                Console.WriteLine("PASS " + name);
            }
            catch (Exception error)
            {
                checks.Add(new CompositeWordVerificationCheck(name, false, error.Message));
                throw new InvalidOperationException($"Check failed: {name}: {error.Message}", error);
            }
        }

        try
        {
            string contractPath = Path.Combine(
                repositoryRoot, "evidence", "mpu4", "integrity",
                "il-composite-contract.json");
            using var contractDocument = JsonDocument.Parse(File.ReadAllText(contractPath));
            contractRoot = contractDocument.RootElement.Clone();

            Check("Public builder compiles the exact reviewed header body and caller", () =>
            {
                build = CompositeWordBuilder.Build(rom);

                Assert(build.OriginalRomSha1 == beforeSha1, "Builder original SHA1 differs");
                Assert(build.OriginalRomSha256 == beforeSha256, "Builder original SHA256 differs");
                Assert(build.OutputImageSha1 == CompositeWordBuilder.ExpectedOutputSha1,
                    "Builder output SHA1 differs from the reviewed contract");
                Assert(build.OutputImageSha256 == CompositeWordBuilder.ExpectedOutputSha256,
                    "Builder output SHA256 differs from the reviewed contract");
                Assert(build.OutputImage.Length == 65536, "Builder output length differs");
                Assert(build.BuildId == CompositeWordBuilder.ExpectedOutputSha256,
                    "Builder build identity differs");
                Assert(build.PayloadBytes.Length == 16, "Payload length differs");
                Assert(Convert.ToHexString(build.CopyPayloadBytes()) ==
                    CompositeWordBuilder.PayloadHex, "Payload bytes differ");
                Assert(Convert.ToHexString(build.OutputImage.Slice(0x1010, 16)) ==
                    CompositeWordBuilder.PayloadHex, "Header/body bytes differ");
                Assert(Convert.ToHexString(build.OutputImage.Slice(0x1012, 14)) ==
                    CompositeWordBuilder.BodyHex, "Body bytes differ");
                Assert(Convert.ToHexString(build.OutputImage.Slice(0x9F14, 2)) == "1010",
                    "Caller token replacement differs");
                Assert(Convert.ToHexString(build.OutputImage.Slice(0x9F16, 2)) == "75A9",
                    "Caller successor token differs");
                Assert(Convert.ToHexString(build.OutputImage.Slice(0x9ED7, 2)) == "00F8",
                    "Original 9ED7 header changed");
                Assert(Convert.ToHexString(build.OutputImage.Slice(0x9ED9, 14)) ==
                    CompositeWordBuilder.BodyHex, "Original 9ED9 body changed");
                Assert(build.Nodes.Count == 5, "Copied node count differs");
                Assert(build.Nodes[0].Address == 0x1012 && build.Nodes[0].Token == 0x795B &&
                       build.Nodes[0].HandlerAddress == 0x795D,
                    "First copied node differs");
                Assert(build.Nodes[2].OperandAddress == 0x101A &&
                       build.Nodes[2].OperandValue == 0xFF80,
                    "Second copied literal differs");
                Assert(build.Nodes[4].Address == 0x101E &&
                       build.Nodes[4].Token == 0x792F,
                    "Final copied return differs");
            });

            Check("Builder output matches the curated static contract exactly", () =>
            {
                JsonElement identity = contractRoot.GetProperty("originalIdentity");
                Assert(identity.GetProperty("sha1").GetString() ==
                       beforeSha1.ToLowerInvariant(), "Contract original SHA1 differs");
                Assert(identity.GetProperty("sha256").GetString() ==
                       beforeSha256.ToLowerInvariant(), "Contract original SHA256 differs");

                JsonElement proposal = contractRoot.GetProperty("proposal");
                Assert(proposal.GetProperty("headerAddress").GetString() == "1010",
                    "Contract header address differs");
                Assert(proposal.GetProperty("headerBytes").GetString() == "00F8",
                    "Contract header bytes differ");
                Assert(proposal.GetProperty("bodyStart").GetString() == "1012",
                    "Contract body start differs");
                Assert(proposal.GetProperty("bodyEndExclusive").GetString() == "1020",
                    "Contract body end differs");
                Assert(proposal.GetProperty("bodyHex").GetString() ==
                       CompositeWordBuilder.BodyHex, "Contract body differs");
                JsonElement token = proposal.GetProperty("tokenReplacement");
                Assert(token.GetProperty("address").GetString() == "9F14",
                    "Contract caller address differs");
                Assert(token.GetProperty("expectedOriginalBytes").GetString() == "9ED7",
                    "Contract expected caller token differs");
                Assert(token.GetProperty("replacementBytes").GetString() == "1010",
                    "Contract replacement caller token differs");
                Assert(token.GetProperty("sameSize").GetBoolean(),
                    "Contract caller replacement is not same-size");

                JsonElement diff = contractRoot.GetProperty("proposedImageDiff");
                int[] expectedDiff = diff.GetProperty("extensionRealizedChangedOffsets")
                    .EnumerateArray().Select(value => Convert.ToInt32(value.GetString(), 16))
                    .Concat(diff.GetProperty("callsiteChangedOffsets").EnumerateArray()
                        .Select(value => Convert.ToInt32(value.GetString(), 16)))
                    .Concat(diff.GetProperty("integrityChangedOffsets").EnumerateArray()
                        .Select(value => Convert.ToInt32(value.GetString(), 16)))
                    .ToArray();
                Assert(diff.GetProperty("totalChangedCount").GetInt32() == 21,
                    "Contract total changed count differs");
                Assert(expectedDiff.SequenceEqual(build.ChangedOffsets),
                    "Builder changed offsets differ from the curated contract");

                JsonElement integrity = contractRoot.GetProperty("integrity");
                Assert(integrity.GetProperty("originalFieldsHex").GetString() ==
                       CompositeWordBuilder.OriginalFieldsHex,
                    "Contract original fields differ");
                Assert(integrity.GetProperty("proposedFieldsHex").GetString() ==
                       CompositeWordBuilder.CompositeFieldsHex,
                    "Contract composite fields differ");
                Assert(integrity.GetProperty("fieldOffsets").EnumerateArray()
                        .Select(value => value.GetString())
                        .SequenceEqual(new[] { "FFD1", "FFD2", "FFD3", "FFD4", "FFD5" }),
                    "Contract field offsets differ");
            });

            Check("Independent full-image diff realizes 14 extension plus 2 caller then 21", () =>
            {
                int[] unrepairedDiff = Diff(rom, build.CopyUnrepairedImage());
                Assert(unrepairedDiff.SequenceEqual(
                        new[]
                        {
                            0x1010, 0x1011, 0x1012, 0x1013, 0x1015, 0x1016, 0x1017,
                            0x1018, 0x1019, 0x101B, 0x101C, 0x101D, 0x101E, 0x101F,
                            0x9F14, 0x9F15
                        }),
                    "Unrepaired independent diff is not 14 extension plus 2 caller changes");
                Assert(unrepairedDiff.Length == 16, "Unrepaired diff count differs");
                Assert(build.UnrepairedChangedOffsets.SequenceEqual(unrepairedDiff),
                    "Reported unrepaired diff differs from the independent diff");
                Assert(build.CopyUnrepairedImage()[0x1014] == 0xFF &&
                       build.CopyUnrepairedImage()[0x101A] == 0xFF,
                    "Unchanged allocation FF bytes were overwritten");

                int[] outputDiff = Diff(rom, build.CopyOutputImage());
                Assert(outputDiff.Length == 21, "Final independent diff count differs");
                Assert(outputDiff.SequenceEqual(build.ChangedOffsets),
                    "Reported final diff differs from the independent diff");
                Assert(outputDiff.SequenceEqual(
                        unrepairedDiff.Concat(Enumerable.Range(0xFFD1, 5)).ToArray()),
                    "Final diff is not unrepaired diff plus FFD1-FFD5");
                for (int offset = 0; offset < rom.Length; offset++)
                {
                    bool allowed = (offset >= 0x1010 && offset <= 0x101F) ||
                                   (offset >= 0x9F14 && offset <= 0x9F15) ||
                                   (offset >= 0xFFD1 && offset <= 0xFFD5);
                    if (!allowed)
                        Assert(build.CopyOutputImage()[offset] == rom[offset],
                            $"Independent preservation check failed at {offset:X4}");
                }
                Assert(build.CopyUnrepairedImage().AsSpan(0x1000, 16)
                        .SequenceEqual(rom.AsSpan(0x1000, 16)),
                    "Unrepaired left guard differs");
                Assert(build.CopyOutputImage().AsSpan(0x13F0, 16)
                        .SequenceEqual(rom.AsSpan(0x13F0, 16)),
                    "Final right guard differs");
            });

            Check("Independent ordered checksum verification reproduces E93F3C61B5", () =>
            {
                byte[] output = build.CopyOutputImage();
                string stored = Convert.ToHexString(output.AsSpan(0xFFD1, 5));
                Assert(stored == "E93F3C61B5", "Stored composite fields differ");
                Assert(Convert.ToHexString(rom.AsSpan(0xFFD1, 5)) == "3E761E2605",
                    "Original stored fields differ");
                Assert(IndependentFields(output) == "E93F3C61B5",
                    "Independent ordered checksum does not reproduce the contract fields");
                Assert(build.IntegrityReport.RepairedStoredFieldsHex == "E93F3C61B5",
                    "Builder integrity fields differ");
                Assert(build.IntegrityReport.RepairChangedOffsets.SequenceEqual(
                        Enumerable.Range(0xFFD1, 5)),
                    "Repair-only diff is not FFD1-FFD5");
                Assert(build.IntegrityReport.AlgorithmOrder.Contains("sum_xor",
                           StringComparison.Ordinal) &&
                       build.IntegrityReport.AlgorithmOrder.Contains("rotate_add",
                           StringComparison.Ordinal) &&
                       build.IntegrityReport.AlgorithmOrder.Contains("rotate_sub_xor",
                           StringComparison.Ordinal),
                    "Integrity algorithm order description differs");
                Assert(build.IntegrityReport.Status.Contains("not natural boot",
                           StringComparison.OrdinalIgnoreCase),
                    "Integrity status overclaims natural acceptance");
            });

            Check("Composite map distinguishes header body caller and return boundary", () =>
            {
                CompositeWordSourceMap map = build.SourceMap;
                Assert(map.OutputImageSha256 == build.OutputImageSha256,
                    "Map is not bound to the final output SHA256");
                Assert(map.BuildId == build.OutputImageSha256, "Map build ID differs");
                Assert(map.OriginalRomSha1 == beforeSha1 &&
                       map.OriginalRomSha256 == beforeSha256,
                    "Map original identity differs");
                Assert(map.Entries.Count == 20, "Map entry count differs");

                CompositeWordMapEntry header = map.Resolve(0x1010);
                Assert(header.Kind == CompositeWordMapKind.Header,
                    "Header entry kind differs");
                Assert(header.Token == 0x00F8 && header.ReplacementToken is null,
                    "Header token/value distinction differs");
                Assert(header.NodeIndex is null, "Header entry unexpectedly has a node index");

                CompositeWordMapEntry body = map.Resolve(0x1012);
                Assert(body.Kind == CompositeWordMapKind.Body,
                    "Body entry kind differs");
                Assert(body.NodeIndex == 0 && body.Token == 0x795B &&
                       body.Operation == "vm_push_inline_word_literal",
                    "Body token entry differs");
                Assert(body.HandlerAddress == 0x795D, "Body handler differs");

                CompositeWordMapEntry caller = map.Resolve(0x9F14);
                Assert(caller.Kind == CompositeWordMapKind.CallerToken,
                    "Caller entry kind differs");
                Assert(caller.Token == 0x9ED7 && caller.ReplacementToken == 0x1010,
                    "Caller original/replacement token distinction differs");
                CompositeWordMapEntry successor = map.Resolve(0x9F16);
                Assert(successor.Kind == CompositeWordMapKind.CallerSuccessor &&
                       successor.Token == 0x75A9,
                    "Caller successor entry differs");

                Assert(map.Caller.TokenAddress == 0x9F14 &&
                       map.Caller.OriginalToken == 0x9ED7 &&
                       map.Caller.ReplacementToken == 0x1010,
                    "Caller binding token differs");
                Assert(map.Caller.HeaderAddress == 0x1010 &&
                       map.Caller.HeaderValue == 0x00F8 &&
                       map.Caller.BodyStart == 0x1012 &&
                       map.Caller.BodyEndExclusive == 0x1020,
                    "Caller binding header/body differs");
                Assert(map.Caller.SavedReturnCursor == 0x9F16,
                    "Caller saved return cursor differs");
                Assert(map.Caller.PostReturnTokenAddress == 0x9F16 &&
                       map.Caller.PostReturnToken == 0x75A9,
                    "Caller post-return token differs");

                Assert(map.Phases.Count == 13, "Phase count differs");
                CompositeWordPhase headerPhase = map.Phases.Single(
                    phase => phase.Phase == "header-trampoline-entry");
                Assert(headerPhase.Pc == 0x00F8 && headerPhase.X == 0x1012 &&
                       headerPhase.Y == 0x9F16 && headerPhase.SavedCursor == 0x9F16,
                    "Header trampoline phase differs");
                CompositeWordPhase prefetch = map.Phases.Single(
                    phase => phase.Phase == "body-prefetch-0");
                Assert(prefetch.Pc == 0x00FC && prefetch.X == 0x1012 &&
                       prefetch.Y == 0x1012 && prefetch.Token == 0x795B &&
                       prefetch.HandlerAddress == 0x795D,
                    "First body prefetch phase differs");
                CompositeWordPhase handler = map.Phases.Single(
                    phase => phase.Phase == "handler-0");
                Assert(handler.Y == 0x1014 && handler.InlineOperandAddress == 0x1014 &&
                       handler.InlineOperandValue == 0xFF80,
                    "First native handler phase differs");
                CompositeWordPhase returnPhase = map.Phases.Single(
                    phase => phase.Phase == "return-handler");
                Assert(returnPhase.Pc == 0x7931 && returnPhase.Y == 0x1020 &&
                       returnPhase.SavedCursor == 0x9F16,
                    "Return handler phase differs");
                CompositeWordPhase postReturn = map.Phases.Single(
                    phase => phase.Phase == "post-return-prefetch");
                Assert(postReturn.Y == 0x9F16 && postReturn.Token == 0x75A9,
                    "Post-return phase differs");
                Assert(map.Phases.All(phase =>
                        phase.Classification == CompositeWordSourceMap.PhaseClassification),
                    "Map phase classification overclaims execution");

                map.ValidateImage(build.CopyOutputImage());
                Assert(map.Resolve(0x1012, build.CopyOutputImage()).ImageByte == 0x79,
                    "Map image lookup differs");
                Reject(() => map.Resolve(0x1012, new string('0', 64)), "identity");
                byte[] tampered = build.CopyOutputImage();
                tampered[0x1012] ^= 1;
                Reject(() => map.Resolve(0x1012, tampered), "identity");
                Reject(() => map.Resolve(0x1020), "no entry");
                Reject(() => map.Resolve(0x9ED7), "no entry");
            });

            Check("Public API rejects wrong identity callsite payload range extra changes and map", () =>
            {
                byte[] unrepaired = build.CopyUnrepairedImage();
                var valid = new VmIlCompositePatchSpec(
                    0x1010,
                    Enumerable.Repeat((byte)0xFF, 16).ToArray(),
                    Convert.FromHexString(CompositeWordBuilder.PayloadHex),
                    0x9F14,
                    new byte[] { 0x9E, 0xD7 },
                    new byte[] { 0x10, 0x10 });

                Reject(() => VmIlIntegrity.RepairComposite(
                        originalSnapshot.AsSpan(0, originalSnapshot.Length - 1),
                        unrepaired, valid), "length");
                Reject(() => VmIlIntegrity.RepairComposite(
                        originalSnapshot, unrepaired.AsSpan(0, unrepaired.Length - 1), valid),
                    "length");

                byte[] tamperedOriginal = (byte[])originalSnapshot.Clone();
                tamperedOriginal[0x1400] ^= 1;
                Reject(() => VmIlIntegrity.RepairComposite(
                        tamperedOriginal, unrepaired, valid), "SHA1");

                Reject(() => VmIlIntegrity.RepairComposite(
                        originalSnapshot, unrepaired,
                        valid with { CallerOffset = 0x9F15 }), "9F14");
                Reject(() => VmIlIntegrity.RepairComposite(
                        originalSnapshot, unrepaired,
                        valid with { ExpectedCallerBytes = new byte[] { 0x9E, 0xD8 } }),
                    "9ED7");
                Reject(() => VmIlIntegrity.RepairComposite(
                        originalSnapshot, unrepaired,
                        valid with { ReplacementCallerBytes = new byte[] { 0x10, 0x11 } }),
                    "1010");
                Reject(() => VmIlIntegrity.RepairComposite(
                        originalSnapshot, unrepaired,
                        valid with { AllocationStart = 0x100F }), "1010-101F");
                Reject(() => VmIlIntegrity.RepairComposite(
                        originalSnapshot, unrepaired,
                        valid with { ExpectedAllocationBytes = new byte[15] }), "1010-101F");
                byte[] wrongHeaderPayload = Convert.FromHexString(CompositeWordBuilder.PayloadHex);
                wrongHeaderPayload[1] = 0xF9;
                Reject(() => VmIlIntegrity.RepairComposite(
                        originalSnapshot, unrepaired,
                        valid with { ReplacementAllocationBytes = wrongHeaderPayload }),
                    "reviewed");
                byte[] wrongBodyPayload = Convert.FromHexString(CompositeWordBuilder.PayloadHex);
                wrongBodyPayload[4] = 0x00;
                Reject(() => VmIlIntegrity.RepairComposite(
                        originalSnapshot, unrepaired,
                        valid with { ReplacementAllocationBytes = wrongBodyPayload }),
                    "reviewed");
                byte[] unsupportedToken = Convert.FromHexString(CompositeWordBuilder.PayloadHex);
                unsupportedToken[2] = 0x79;
                unsupportedToken[3] = 0x63;
                Reject(() => VmIlIntegrity.RepairComposite(
                        originalSnapshot, unrepaired,
                        valid with { ReplacementAllocationBytes = unsupportedToken }),
                    "reviewed");

                byte[] extra = (byte[])unrepaired.Clone();
                extra[0x1401] ^= 1;
                Reject(() => VmIlIntegrity.RepairComposite(
                        originalSnapshot, extra, valid), "unexpected changes");
                byte[] premodifiedFields = (byte[])unrepaired.Clone();
                premodifiedFields[0xFFD1] ^= 1;
                Reject(() => VmIlIntegrity.RepairComposite(
                        originalSnapshot, premodifiedFields, valid), "pre-modified");

                CompositeWordSourceMap map = build.SourceMap;
                Reject(() => map.ValidateBuild(new string('0', 64)), "identity");
                Reject(() => map.ValidateImage(originalSnapshot), "identity");
            });

            Check("Repeated builds are deterministic for the same original bytes", () =>
            {
                CompositeWordBuildResult rebuilt = CompositeWordBuilder.Build(rom);
                Assert(rebuilt.OutputImageSha1 == build.OutputImageSha1 &&
                       rebuilt.OutputImageSha256 == build.OutputImageSha256,
                    "Repeated build output identity differs");
                Assert(rebuilt.UnrepairedImageSha1 == build.UnrepairedImageSha1 &&
                       rebuilt.UnrepairedImageSha256 == build.UnrepairedImageSha256,
                    "Repeated unrepaired identity differs");
                Assert(rebuilt.CopyOutputImage().SequenceEqual(build.CopyOutputImage()),
                    "Repeated build bytes differ");
                Assert(rebuilt.ChangedOffsets.SequenceEqual(build.ChangedOffsets) &&
                       rebuilt.UnrepairedChangedOffsets.SequenceEqual(
                           build.UnrepairedChangedOffsets),
                    "Repeated build diff differs");
                Assert(rebuilt.SourceMap.BuildId == build.SourceMap.BuildId &&
                       rebuilt.SourceMap.Phases.Count == build.SourceMap.Phases.Count,
                    "Repeated build map differs");
            });

            Check("Immutable owned results leave the caller ROM and prior copies unchanged", () =>
            {
                byte[] first = build.CopyOutputImage();
                first[0x1010] ^= 1;
                byte[] second = build.CopyOutputImage();
                Assert(second[0x1010] == 0x00,
                    "Mutating one output copy changed the owned build result");
                Assert(Sha256(second) == CompositeWordBuilder.ExpectedOutputSha256,
                    "Owned output identity changed after caller mutation");
                Assert(Sha1(build.CopyOutputImage()) == CompositeWordBuilder.ExpectedOutputSha1,
                    "Owned output SHA1 changed after caller mutation");
                byte[] payload = build.CopyPayloadBytes();
                payload[0] = 0xFF;
                Assert(build.CopyPayloadBytes()[0] == 0x00,
                    "Mutating a payload copy changed the owned build result");
                Assert(build.ChangedOffsets.Count == 21,
                    "Changed-offset view length differs");
                Assert(build.OutputImage.Length == 65536, "Output span length differs");
                Assert(rom.SequenceEqual(originalSnapshot) &&
                       Sha1(rom) == beforeSha1 && Sha256(rom) == beforeSha256,
                    "Builder mutated its caller input ROM");
                Assert(build.Status.Contains("STATIC COMPILED", StringComparison.Ordinal) &&
                       build.Status.Contains("not execution proof",
                           StringComparison.OrdinalIgnoreCase),
                    "Build status overclaims execution");
            });

            Check("Read-only map and integrity report reject external mutation", () =>
            {
                CompositeWordSourceMap map = build.SourceMap;
                string serializedBefore = JsonSerializer.Serialize(map);
                CompositeWordMapEntry headerBefore = map.Resolve(0x1010);
                CompositeWordPhase phaseBefore = map.Phases[0];
                CompositeWordNode nodeBefore = map.Nodes[0];

                Assert((object)map.Entries is not CompositeWordMapEntry[],
                    "Entries exposes a caller-mutable array");
                Assert((object)map.Phases is not CompositeWordPhase[],
                    "Phases exposes a caller-mutable array");
                Assert((object)map.Nodes is not CompositeWordNode[],
                    "Nodes exposes a caller-mutable array");
                Assert((object)build.Nodes is not CompositeWordNode[],
                    "Build Nodes exposes a caller-mutable array");
                Assert((object)build.ChangedOffsets is not int[],
                    "ChangedOffsets exposes a caller-mutable array");

                CompositeWordMapEntry tamperedEntry =
                    headerBefore with { Operation = "tampered" };
                CompositeWordPhase tamperedPhase =
                    phaseBefore with { Phase = "tampered" };
                CompositeWordNode tamperedNode =
                    nodeBefore with { Operation = "tampered" };

                RejectReadOnly(() =>
                    ((IList<CompositeWordMapEntry>)map.Entries)[0] = tamperedEntry,
                    "Entries index replacement");
                RejectReadOnly(() =>
                    ((IList<CompositeWordMapEntry>)map.Entries).Add(tamperedEntry),
                    "Entries add");
                RejectReadOnly(() =>
                    ((IList<CompositeWordMapEntry>)map.Entries).Clear(),
                    "Entries clear");
                RejectReadOnly(() =>
                    ((IList<CompositeWordPhase>)map.Phases)[0] = tamperedPhase,
                    "Phases index replacement");
                RejectReadOnly(() =>
                    ((IList<CompositeWordPhase>)map.Phases).RemoveAt(0),
                    "Phases remove");
                RejectReadOnly(() =>
                    ((IList<CompositeWordNode>)map.Nodes)[0] = tamperedNode,
                    "Nodes index replacement");
                RejectReadOnly(() =>
                    ((IList<CompositeWordNode>)map.Nodes).Clear(),
                    "Nodes clear");
                RejectReadOnly(() =>
                    ((IList<int>)build.ChangedOffsets)[0] = 0x1400,
                    "ChangedOffsets index replacement");
                RejectReadOnly(() =>
                    ((IList<int>)build.UnrepairedChangedOffsets)[0] = 0x1400,
                    "UnrepairedChangedOffsets index replacement");
                RejectReadOnly(() =>
                    ((IList<int>)build.RepairChangedOffsets)[0] = 0x1400,
                    "RepairChangedOffsets index replacement");
                RejectReadOnly(() =>
                    ((IList<CompositeWordNode>)build.Nodes)[0] = tamperedNode,
                    "Build Nodes index replacement");

                Assert(map.Resolve(0x1010) == headerBefore,
                    "Map resolution changed after rejected mutation");
                Assert(map.Phases[0] == phaseBefore,
                    "Map phase changed after rejected mutation");
                Assert(map.Nodes[0] == nodeBefore,
                    "Map node changed after rejected mutation");
                Assert(map.Entries.Count == 20 && map.Phases.Count == 13 &&
                       map.Nodes.Count == 5,
                    "Map collection count changed after rejected mutation");
                Assert(JsonSerializer.Serialize(map) == serializedBefore,
                    "Serialized map changed after rejected mutation");

                VmIlIntegrityReport report = build.IntegrityReport;
                string repairedFields = report.RepairedStoredFieldsHex;
                int firstUnrepaired = report.UnrepairedChangedOffsets[0];
                int firstRepaired = report.RepairedChangedOffsets[0];
                int firstRepair = report.RepairChangedOffsets[0];
                VmIlIntegrityField firstField = report.Fields[0];

                report.UnrepairedChangedOffsets[0] = 0x0100;
                report.RepairedChangedOffsets[0] = 0x0100;
                report.RepairChangedOffsets[0] = 0x0100;
                try
                {
                    ((IList<VmIlIntegrityField>)report.Fields)[0] =
                        new VmIlIntegrityField("tampered", 0, 0, 0, "tampered");
                }
                catch (NotSupportedException)
                {
                }

                VmIlIntegrityReport retained = build.IntegrityReport;
                Assert(retained.RepairedStoredFieldsHex == repairedFields,
                    "Retained integrity fields changed after caller mutation");
                Assert(retained.UnrepairedChangedOffsets[0] == firstUnrepaired,
                    "Retained unrepaired offsets changed after caller mutation");
                Assert(retained.RepairedChangedOffsets[0] == firstRepaired,
                    "Retained repaired offsets changed after caller mutation");
                Assert(retained.RepairChangedOffsets[0] == firstRepair,
                    "Retained repair offsets changed after caller mutation");
                Assert(retained.Fields[0] == firstField,
                    "Retained integrity field list changed after caller mutation");
                Assert(retained.RepairChangedOffsets.SequenceEqual(
                        Enumerable.Range(0xFFD1, 5)),
                    "Retained repair offsets no longer match FFD1-FFD5");
                Assert(retained.Fields.Count == 5 &&
                       retained.UnrepairedChangedOffsets.Length == 16 &&
                       retained.RepairedChangedOffsets.Length == 21,
                    "Retained integrity report counts changed");
                Assert(JsonSerializer.Serialize(retained) ==
                       JsonSerializer.Serialize(build.IntegrityReport),
                    "Serialized retained integrity report changed after mutation");
                Assert(build.CopyOutputImage().AsSpan(0xFFD1, 5).SequenceEqual(
                        Convert.FromHexString("E93F3C61B5")),
                    "Retained output fields changed after report mutation");
            });
        }
        catch
        {
            WriteFailureOutputs(outputDirectory, checks);
            throw;
        }

        byte[] finalBytes = File.ReadAllBytes(romPath);
        string afterSha1 = Sha1(finalBytes);
        string afterSha256 = Sha256(finalBytes);
        var report = new CompositeWordVerificationReport(
            "il-composite-build-33",
            1,
            "passed",
            "Strict static composite-word build: independently decoded 9ED9 nodes, byte-identical " +
            "extension body at 1012-101F, one same-size caller token replacement at 9F14, exact " +
            "21-byte realized diff, ordered FFD1-FFD5 regeneration against the curated contract " +
            "and a final-ROM-hash-bound composite map. No MAME execution or hardware claim.",
            Path.GetFullPath(romPath),
            rom.Length,
            beforeSha1,
            beforeSha256,
            afterSha1,
            afterSha256,
            beforeSha1 == afterSha1 && beforeSha256 == afterSha256,
            CompositeWordBuilder.HeaderHex,
            CompositeWordBuilder.BodyHex,
            "9ED7",
            "1010",
            build.UnrepairedImageSha1,
            build.UnrepairedImageSha256,
            build.UnrepairedChangedOffsets.ToArray(),
            build.OutputImageSha1,
            build.OutputImageSha256,
            build.ChangedOffsets.ToArray(),
            build.ChangedOffsets.Count,
            build.IntegrityReport.OriginalStoredFieldsHex,
            build.IntegrityReport.RepairedStoredFieldsHex,
            build.IntegrityReport.AlgorithmOrder,
            build.RepairChangedOffsets.ToArray(),
            build.SourceMap.BuildId,
            build.SourceMap.Entries.Count,
            build.SourceMap.Phases.Count,
            "9F16",
            "75A9",
            checks,
            new[]
            {
                "The 1010 composite word and the 9F14 redirect are statically compiled only; no " +
                "MAME run, natural reach of 1010, runtime handler observation or hardware test was made.",
                "The body is a byte-identical copy of the certified 9ED9 token sequence; this does " +
                "not claim general dictionary/header decoding, relocation or banking.",
                "The original 9ED7 header/body and all other callers are preserved by the exact diff; " +
                "the broader purpose of 9F12 remains unresolved.",
                "The extension range 1010-13EF is human-approved for this exact ROM revision only.",
                "Integrity repair is algorithmically verified in the recovered field order; it is not " +
                "natural boot acceptance."
            },
            "Next boundary is a reviewed natural fresh-boot MAME task observing the 1010 header/body, " +
            "native handlers, return through 7931 and the saved cursor 9F16. No execution proof exists here.");

        WriteOutputs(outputDirectory, report);
        WritePrivateBuild(outputDirectory, build);
        Console.WriteLine(
            $"PASS {checks.Count} composite-word groups; output SHA256 {build.OutputImageSha256}, " +
            $"fields {build.IntegrityReport.RepairedStoredFieldsHex}, changed {build.ChangedOffsets.Count}.");
    }

    private static int[] Diff(byte[] before, byte[] after)
    {
        if (before.Length != after.Length)
            throw new InvalidDataException("Image lengths differ");
        var changed = new List<int>();
        for (int offset = 0; offset < before.Length; offset++)
        {
            if (before[offset] != after[offset])
                changed.Add(offset);
        }
        return changed.ToArray();
    }

    private static string IndependentFields(byte[] image)
    {
        byte[] working = (byte[])image.Clone();
        int sum = 0;
        int xor = 0;
        int pointer = 0x1400;
        while (true)
        {
            int value = working[pointer];
            sum = (sum + value) & 0xFF;
            xor ^= value;
            if (pointer == 0xFFFF)
                break;
            pointer++;
            if (pointer == 0xFFD1)
                pointer = 0xFFD6;
        }
        working[0xFFD1] = (byte)sum;
        working[0xFFD2] = (byte)xor;

        int a = 0;
        int b = 0;
        int carry = 0;
        pointer = 0x1400;
        while (true)
        {
            int value = working[pointer];
            int next = (b >> 7) & 1;
            b = ((b << 1) | carry) & 0xFF;
            carry = next;
            int total = a + value + carry;
            a = total & 0xFF;
            carry = (total >> 8) & 1;
            next = b & 1;
            b = ((carry << 7) | (b >> 1)) & 0xFF;
            carry = next;
            if (pointer == 0xFFFF)
                break;
            pointer++;
            if (pointer == 0xFFD3)
                pointer = 0xFFD6;
            carry = pointer < 0xFFD3 ? 1 : 0;
        }
        working[0xFFD3] = (byte)a;

        a = 0;
        b = 0;
        carry = 0;
        pointer = 0x1400;
        while (true)
        {
            int value = working[pointer];
            int next = (b >> 7) & 1;
            b = (b << 1) & 0xFF;
            carry = next;
            int total = b + carry;
            b = total & 0xFF;
            carry = (total >> 8) & 1;
            total = b - value;
            b = total & 0xFF;
            carry = total < 0 ? 1 : 0;
            int savedB = b;
            b = a;
            for (int index = 0; index < 3; index++)
            {
                carry = b & 1;
                b = ((b >> 1) | (b & 0x80)) & 0xFF;
                a = ((carry << 7) | (a >> 1)) & 0xFF;
            }
            b = savedB;
            a ^= value;
            if (pointer == 0xFFFF)
                break;
            pointer++;
            if (pointer == 0xFFD4)
                pointer = 0xFFD6;
        }
        working[0xFFD4] = (byte)a;
        working[0xFFD5] = (byte)b;
        return Convert.ToHexString(working.AsSpan(0xFFD1, 5));
    }

    private static string Sha1(ReadOnlySpan<byte> bytes) =>
        Convert.ToHexString(SHA1.HashData(bytes));

    private static string Sha256(ReadOnlySpan<byte> bytes) =>
        Convert.ToHexString(SHA256.HashData(bytes));

    private static void WriteOutputs(
        string outputDirectory, CompositeWordVerificationReport report)
    {
        Directory.CreateDirectory(outputDirectory);
        var log = new StringBuilder();
        log.AppendLine("FruitMachineLab il-composite-build-33 verification");
        log.AppendLine("ROM: " + report.RomPath);
        log.AppendLine("SHA1: " + report.RomSha1Before);
        log.AppendLine("SHA256: " + report.RomSha256Before);
        log.AppendLine("Input unchanged: " + report.InputUnchanged);
        log.AppendLine("Header: " + report.HeaderHex);
        log.AppendLine("Body: " + report.BodyHex);
        log.AppendLine("Caller: " + report.CallerOriginalTokenHex + " -> " +
            report.CallerReplacementTokenHex);
        log.AppendLine("Unrepaired SHA1: " + report.UnrepairedSha1);
        log.AppendLine("Unrepaired SHA256: " + report.UnrepairedSha256);
        log.AppendLine("Unrepaired changed: " +
            string.Join(',', report.UnrepairedChangedOffsets));
        log.AppendLine("Output SHA1: " + report.OutputSha1);
        log.AppendLine("Output SHA256: " + report.OutputSha256);
        log.AppendLine("Changed count: " + report.ChangedCount);
        log.AppendLine("Changed offsets: " + string.Join(',', report.ChangedOffsets));
        log.AppendLine("Integrity original: " + report.IntegrityOriginalFieldsHex);
        log.AppendLine("Integrity repaired: " + report.IntegrityRepairedFieldsHex);
        log.AppendLine("Integrity order: " + report.IntegrityAlgorithmOrder);
        log.AppendLine("Repair-only: " + string.Join(',', report.RepairChangedOffsets));
        log.AppendLine("Map build ID: " + report.MapBuildId);
        log.AppendLine("Map entries: " + report.MapEntryCount);
        log.AppendLine("Map phases: " + report.MapPhaseCount);
        log.AppendLine("Caller saved cursor: " + report.CallerSavedCursorHex);
        log.AppendLine("Caller post-return token: " + report.CallerPostReturnTokenHex);
        foreach (CompositeWordVerificationCheck check in report.Checks)
            log.AppendLine("PASS " + check.Name);
        log.AppendLine("Classification: " + report.Classification);
        foreach (string limitation in report.Limitations)
            log.AppendLine("LIMIT " + limitation);
        log.AppendLine("NEXT " + report.RemainingBoundary);
        log.AppendLine("STATUS " + report.Status);

        VerificationOutputs.WriteCreateOnly(
            Path.Combine(outputDirectory, "verification.log"), log.ToString());
        string json = JsonSerializer.Serialize(
            report, new JsonSerializerOptions { WriteIndented = true });
        VerificationOutputs.WriteCreateOnly(
            Path.Combine(outputDirectory, "verification-report.json"),
            json + Environment.NewLine);
    }

    private static void WritePrivateBuild(
        string outputDirectory, CompositeWordBuildResult build)
    {
        WriteCreateOnly(
            Path.Combine(outputDirectory, "built-unrepaired.p1"),
            build.CopyUnrepairedImage());
        WriteCreateOnly(
            Path.Combine(outputDirectory, "built-repaired.p1"),
            build.CopyOutputImage());
        string mapJson = JsonSerializer.Serialize(
            build.SourceMap, new JsonSerializerOptions { WriteIndented = true });
        VerificationOutputs.WriteCreateOnly(
            Path.Combine(outputDirectory, "composite-source-map.json"),
            mapJson + Environment.NewLine);
        string buildJson = JsonSerializer.Serialize(
            new
            {
                schemaVersion = 1,
                taskId = "il-composite-build-33",
                classification = build.Status,
                originalRomSha1 = build.OriginalRomSha1,
                originalRomSha256 = build.OriginalRomSha256,
                unrepairedImageSha1 = build.UnrepairedImageSha1,
                unrepairedImageSha256 = build.UnrepairedImageSha256,
                outputImageSha1 = build.OutputImageSha1,
                outputImageSha256 = build.OutputImageSha256,
                headerAddress = "1010",
                headerBytes = CompositeWordBuilder.HeaderHex,
                bodyStart = "1012",
                bodyEndExclusive = "1020",
                bodyHex = CompositeWordBuilder.BodyHex,
                callerTokenAddress = "9F14",
                callerExpectedToken = "9ED7",
                callerReplacementToken = "1010",
                callerSavedReturnCursor = "9F16",
                callerPostReturnToken = "75A9",
                integrityOriginalFieldsHex =
                    build.IntegrityReport.OriginalStoredFieldsHex,
                integrityRepairedFieldsHex =
                    build.IntegrityReport.RepairedStoredFieldsHex,
                unrepairedChangedOffsets = build.UnrepairedChangedOffsets,
                changedOffsets = build.ChangedOffsets,
                repairChangedOffsets = build.RepairChangedOffsets,
                nodes = build.Nodes,
                provenance = build.Provenance
            },
            new JsonSerializerOptions { WriteIndented = true });
        VerificationOutputs.WriteCreateOnly(
            Path.Combine(outputDirectory, "build-report.json"),
            buildJson + Environment.NewLine);
    }

    private static void WriteCreateOnly(string path, byte[] content)
    {
        using var stream = new FileStream(
            path, FileMode.CreateNew, FileAccess.Write, FileShare.None);
        stream.Write(content, 0, content.Length);
    }

    private static void WriteFailureOutputs(
        string outputDirectory, IReadOnlyList<CompositeWordVerificationCheck> checks)
    {
        if (Directory.Exists(outputDirectory)) return;
        Directory.CreateDirectory(outputDirectory);
        var builder = new StringBuilder();
        builder.AppendLine("FruitMachineLab il-composite-build-33 verification FAILED");
        foreach (CompositeWordVerificationCheck check in checks)
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

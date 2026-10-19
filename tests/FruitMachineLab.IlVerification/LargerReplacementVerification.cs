using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using FruitMachineLab.Il;

namespace FruitMachineLab.IlVerification;

internal sealed record LargerReplacementVerificationCheck(
    string Name, bool Passed, string? Error);

internal sealed record LargerReplacementVerificationReport(
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
    string PayloadHex,
    int NodeCount,
    int InlineOperandCount,
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
    int MapInlineOperandCount,
    int MapNodeCount,
    int MapPhaseCount,
    string CallerSavedCursorHex,
    string CallerPostReturnTokenHex,
    string FinalReturnAddressHex,
    IReadOnlyList<LargerReplacementVector> StaticVectors,
    IReadOnlyList<LargerReplacementVerificationCheck> Checks,
    IReadOnlyList<string> Limitations,
    string RemainingBoundary);

internal static class LargerReplacementVerification
{
    private const string ExpectedOriginalFieldsHex = "3E761E2605";
    private const string ExpectedRepairedFieldsHex = "E93F3C61B5";
    private const string ExpectedOutputSha1 = "7D81C9828A8A8C882861151E84B676AE05D272BF";
    private const string ExpectedOutputSha256 =
        "F693D70A73F1C12857CD64CA9DB9D68DE9BBC1888101ABC283FA2752C094B523";
    private const string ExpectedUnrepairedSha1 =
        "5ACD11F897005A9C80C4931460847BC4E6414FA5";
    private const string ExpectedUnrepairedSha256 =
        "F8B0CAAEFF6EA6ACF9B11F9E9CEF39D2F9A4346EBC11C5FB8245D76D40E235B9";

    private static readonly int[] ExpectedUnrepairedChangedOffsets =
    {
        0x1010, 0x1011, 0x1012, 0x1013, 0x1015, 0x1016, 0x1017, 0x1018,
        0x1019, 0x101B, 0x101C, 0x101D, 0x101E, 0x101F, 0x1020, 0x1021,
        0x1022, 0x1023, 0x1024, 0x1025, 0x9F14, 0x9F15
    };

    private static readonly int[] ExpectedChangedOffsets =
        ExpectedUnrepairedChangedOffsets
            .Concat(Enumerable.Range(0xFFD1, 5))
            .ToArray();

    public static void Run(string romPath, string repositoryRoot, string outputDirectory)
    {
        if (Directory.Exists(outputDirectory))
            throw new IOException($"Output directory already exists: {outputDirectory}");

        byte[] rom = File.ReadAllBytes(romPath);
        byte[] originalSnapshot = (byte[])rom.Clone();
        string beforeSha1 = Sha1(rom);
        string beforeSha256 = Sha256(rom);
        var checks = new List<LargerReplacementVerificationCheck>();
        LargerReplacementBuildResult build = null!;

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
                checks.Add(new LargerReplacementVerificationCheck(name, true, null));
                Console.WriteLine("PASS " + name);
            }
            catch (Exception error)
            {
                checks.Add(new LargerReplacementVerificationCheck(name, false, error.Message));
                throw new InvalidOperationException($"Check failed: {name}: {error.Message}", error);
            }
        }

        try
        {
            Check("Builder compiles the reviewed 7-node larger body and caller", () =>
            {
                build = LargerReplacementBuilder.Build(rom);

                Assert(build.OriginalRomSha1 == beforeSha1, "Builder original SHA1 differs");
                Assert(build.OriginalRomSha256 == beforeSha256, "Builder original SHA256 differs");
                Assert(build.OutputImageSha1 == ExpectedOutputSha1,
                    "Builder output SHA1 differs from the reviewed contract");
                Assert(build.OutputImageSha256 == ExpectedOutputSha256,
                    "Builder output SHA256 differs from the reviewed contract");
                Assert(build.UnrepairedImageSha1 == ExpectedUnrepairedSha1,
                    "Unrepaired SHA1 differs from the reviewed contract");
                Assert(build.UnrepairedImageSha256 == ExpectedUnrepairedSha256,
                    "Unrepaired SHA256 differs from the reviewed contract");
                Assert(build.OutputImage.Length == 65536, "Builder output length differs");
                Assert(build.BuildId == ExpectedOutputSha256, "Builder build identity differs");
                Assert(build.PayloadBytes.Length == 22, "Payload length differs");
                Assert(Convert.ToHexString(build.CopyPayloadBytes()) ==
                       LargerReplacementBuilder.PayloadHex, "Payload bytes differ");
                Assert(Convert.ToHexString(build.CopyOutputImage().AsSpan(0x1010, 22)) ==
                       LargerReplacementBuilder.PayloadHex,
                    "Header/body allocation bytes differ");
                Assert(Convert.ToHexString(build.CopyOutputImage().AsSpan(0x1010, 2)) == "00F8",
                    "Header bytes differ");
                Assert(Convert.ToHexString(build.CopyOutputImage().AsSpan(0x1012, 20)) ==
                       LargerReplacementBuilder.BodyHex, "Body bytes differ");
                Assert(Convert.ToHexString(build.CopyOutputImage().AsSpan(0x9F14, 2)) == "1010",
                    "Caller token replacement differs");
                Assert(Convert.ToHexString(build.CopyOutputImage().AsSpan(0x9F16, 2)) == "75A9",
                    "Caller successor token differs");
                Assert(Convert.ToHexString(build.CopyOutputImage().AsSpan(0x9ED7, 2)) == "00F8",
                    "Original 9ED7 header changed");
                Assert(Convert.ToHexString(build.CopyOutputImage().AsSpan(0x9ED9, 14)) ==
                       LargerReplacementBuilder.OriginalBodyHex, "Original 9ED9 body changed");
                Assert(Convert.ToHexString(build.CopyOutputImage().AsSpan(0x7927, 8)) ==
                       LargerReplacementBuilder.RuntimeDispatchTemplateHex,
                    "Runtime dispatch template changed");

                Assert(build.Nodes.Count == 7, "Node count differs");
                Assert(build.Nodes.Select(node => node.Address).SequenceEqual(
                        new ushort[] { 0x1012, 0x1016, 0x1018, 0x101C, 0x101E, 0x1022, 0x1024 }),
                    "Node addresses differ");
                Assert(build.Nodes.Select(node => node.Token).SequenceEqual(
                        new ushort[] { 0x795B, 0x787E, 0x795B, 0x7AAF, 0x795B, 0x787E, 0x792F }),
                    "Node tokens differ");
                Assert(build.Nodes.Where(node => node.OperandAddress is not null)
                        .Select(node => node.OperandAddress)
                        .SequenceEqual(new ushort?[] { 0x1014, 0x101A, 0x1020 }),
                    "Inline operand addresses differ");
                Assert(build.Nodes.Where(node => node.OperandValue is not null)
                        .Select(node => node.OperandValue)
                        .SequenceEqual(new ushort?[] { 0xFF80, 0xFF80, 0x0001 }),
                    "Inline operand values differ");
                Assert(build.Nodes[^1].Token == 0x792F &&
                       build.Nodes[^1].Address == 0x1024,
                    "Final return is not the single 792F at 1024");
                Assert(build.Nodes.All(node => node.HandlerAddress == node.Token + 2),
                    "A node handler does not follow its token");
                Assert(build.ByteChanges.Count == 27, "Byte-change count differs");
                Assert(build.Status.Contains("STATIC COMPILED", StringComparison.Ordinal) &&
                       build.Status.Contains("not execution proof",
                           StringComparison.OrdinalIgnoreCase),
                    "Build status overclaims execution");
            });

            Check("Independent diff is exactly 22 unrepaired and 27 final offsets", () =>
            {
                int[] unrepairedDiff = Diff(rom, build.CopyUnrepairedImage());
                Assert(unrepairedDiff.SequenceEqual(ExpectedUnrepairedChangedOffsets),
                    "Unrepaired independent diff is not exactly 20 extension plus 2 caller changes");
                Assert(build.UnrepairedChangedOffsets.SequenceEqual(unrepairedDiff),
                    "Reported unrepaired diff differs from the independent diff");

                int[] outputDiff = Diff(rom, build.CopyOutputImage());
                Assert(outputDiff.Length == 27, "Final independent diff count differs");
                Assert(outputDiff.SequenceEqual(ExpectedChangedOffsets),
                    "Final independent diff is not the reviewed 27 offsets");
                Assert(outputDiff.SequenceEqual(build.ChangedOffsets),
                    "Reported final diff differs from the independent diff");
                Assert(outputDiff.SequenceEqual(
                        unrepairedDiff.Concat(Enumerable.Range(0xFFD1, 5)).ToArray()),
                    "Final diff is not unrepaired diff plus FFD1-FFD5");

                Assert(build.CopyUnrepairedImage()[0x1014] == 0xFF &&
                       build.CopyUnrepairedImage()[0x101A] == 0xFF,
                    "1014 or 101A changed from the original FF");
                for (int offset = 0; offset < rom.Length; offset++)
                {
                    bool allowed = (offset >= 0x1010 && offset <= 0x1025) ||
                                   (offset >= 0x9F14 && offset <= 0x9F15) ||
                                   (offset >= 0xFFD1 && offset <= 0xFFD5);
                    if (!allowed)
                        Assert(build.CopyOutputImage()[offset] == rom[offset],
                            $"Independent final preservation check failed at {offset:X4}");
                    bool allowedUnrepaired = (offset >= 0x1010 && offset <= 0x1025) ||
                                             (offset >= 0x9F14 && offset <= 0x9F15);
                    if (!allowedUnrepaired)
                        Assert(build.CopyUnrepairedImage()[offset] == rom[offset],
                            $"Independent unrepaired preservation check failed at {offset:X4}");
                }

                Assert(build.CopyOutputImage().AsSpan(0x1000, 16)
                        .SequenceEqual(rom.AsSpan(0x1000, 16)), "Final left guard differs");
                Assert(build.CopyOutputImage().AsSpan(0x1000, 4)
                        .SequenceEqual(rom.AsSpan(0x1000, 4)), "Final protected cells differ");
                Assert(build.CopyOutputImage().AsSpan(0x13F0, 16)
                        .SequenceEqual(rom.AsSpan(0x13F0, 16)), "Final right guard differs");
                Assert(build.CopyOutputImage().AsSpan(0x1400, 16)
                        .SequenceEqual(rom.AsSpan(0x1400, 16)), "Integrity neighbour differs");
                Assert(build.CopyOutputImage().AsSpan(0x9ED7, 16)
                        .SequenceEqual(rom.AsSpan(0x9ED7, 16)),
                    "Original 9ED7/9ED9 definition changed");
                Assert(build.CopyOutputImage().AsSpan(0x1026, 0x13EF - 0x1026 + 1)
                        .SequenceEqual(rom.AsSpan(0x1026, 0x13EF - 0x1026 + 1)),
                    "Unallocated extension 1026-13EF changed");
                Assert(build.CopyOutputImage()[0x719B] == rom[0x719B],
                    "Outer gate 719B changed");
                Assert(build.CopyOutputImage().AsSpan(0x9F10, 4)
                        .SequenceEqual(rom.AsSpan(0x9F10, 4)),
                    "Caller header/body prefix 9F10-9F13 is not preserved");
                Assert(build.CopyOutputImage().AsSpan(0x9F16, 8)
                        .SequenceEqual(rom.AsSpan(0x9F16, 8)),
                    "Caller bytes after the successor are not preserved");
                Assert(build.CopyOutputImage().AsSpan(0x9F3B, 6)
                        .SequenceEqual(rom.AsSpan(0x9F3B, 6)),
                    "Parent caller context 9F3B-9F40 is not preserved");
            });

            Check("Integrity wrapper repairs only FFD1-FFD5 and reproduces E93F3C61B5", () =>
            {
                byte[] output = build.CopyOutputImage();
                string stored = Convert.ToHexString(output.AsSpan(0xFFD1, 5));
                Assert(stored == ExpectedRepairedFieldsHex, "Stored fields differ");
                Assert(Convert.ToHexString(rom.AsSpan(0xFFD1, 5)) == ExpectedOriginalFieldsHex,
                    "Original stored fields differ");
                Assert(IndependentFields(output) == ExpectedRepairedFieldsHex,
                    "Independent ordered checksum does not reproduce the contract fields");
                Assert(build.IntegrityReport.RepairedStoredFieldsHex ==
                       ExpectedRepairedFieldsHex, "Builder integrity fields differ");
                Assert(build.IntegrityReport.RepairChangedOffsets.SequenceEqual(
                        Enumerable.Range(0xFFD1, 5)), "Repair-only diff is not FFD1-FFD5");
                Assert(build.RepairChangedOffsets.SequenceEqual(Enumerable.Range(0xFFD1, 5)),
                    "Builder repair-only diff is not FFD1-FFD5");
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

            Check("Source map binds the exact image and resolves every reviewed span", () =>
            {
                LargerReplacementSourceMap map = build.SourceMap;
                Assert(map.OutputImageSha256 == build.OutputImageSha256,
                    "Map is not bound to the final output SHA256");
                Assert(map.BuildId == build.OutputImageSha256, "Map build ID differs");
                Assert(map.OriginalRomSha1 == beforeSha1 &&
                       map.OriginalRomSha256 == beforeSha256,
                    "Map original identity differs");
                Assert(map.Entries.Count == 30, "Map entry count differs");
                Assert(map.Nodes.Count == 7, "Map node count differs");
                Assert(map.InlineOperands.Count == 3, "Map inline operand count differs");
                Assert(map.Phases.Count == 17, "Map phase count differs");

                LargerReplacementMapEntry header = map.Resolve(0x1010);
                Assert(header.Kind == LargerReplacementMapKind.Header &&
                       header.Token == 0x00F8, "Header map entry differs");
                LargerReplacementMapEntry first = map.Resolve(0x1012);
                Assert(first.Kind == LargerReplacementMapKind.Body &&
                       first.NodeIndex == 0 && first.Token == 0x795B &&
                       first.HandlerAddress == 0x795D, "First body entry differs");
                LargerReplacementMapEntry operand0 = map.Resolve(0x1014);
                Assert(operand0.OperandAddress == 0x1014 &&
                       operand0.OperandValue == 0xFF80, "First inline operand entry differs");
                LargerReplacementMapEntry operand1 = map.Resolve(0x101A);
                Assert(operand1.OperandAddress == 0x101A &&
                       operand1.OperandValue == 0xFF80, "Second inline operand entry differs");
                LargerReplacementMapEntry operand2 = map.Resolve(0x1020);
                Assert(operand2.OperandAddress == 0x1020 &&
                       operand2.OperandValue == 0x0001, "Third inline operand entry differs");
                LargerReplacementMapEntry finalReturn = map.Resolve(0x1024);
                Assert(finalReturn.IsFinalReturn &&
                       finalReturn.Token == 0x792F &&
                       finalReturn.HandlerAddress == 0x7931,
                    "Final return entry differs");
                Assert(map.InlineOperands.Select(item => item.Address)
                        .SequenceEqual(new ushort[] { 0x1014, 0x101A, 0x1020 }),
                    "Inline operand map list differs");
                Assert(map.InlineOperands.Select(item => item.Value)
                        .SequenceEqual(new ushort[] { 0xFF80, 0xFF80, 0x0001 }),
                    "Inline operand map values differ");

                LargerReplacementMapEntry caller = map.Resolve(0x9F14);
                Assert(caller.Kind == LargerReplacementMapKind.CallerToken &&
                       caller.Token == 0x9ED7 && caller.ReplacementToken == 0x1010,
                    "Caller original/replacement token distinction differs");
                LargerReplacementMapEntry successor = map.Resolve(0x9F16);
                Assert(successor.Kind == LargerReplacementMapKind.CallerSuccessor &&
                       successor.Token == 0x75A9, "Caller successor entry differs");
                Assert(map.Resolve(0x9F3D).Kind == LargerReplacementMapKind.ParentToken &&
                       map.Resolve(0x9F3D).Token == 0x9F10,
                    "Parent token entry differs");
                Assert(map.Resolve(0x9F3F).Kind == LargerReplacementMapKind.ParentSuccessor &&
                       map.Resolve(0x9F3F).Token == 0x792F,
                    "Parent successor entry differs");

                Assert(map.Caller.TokenAddress == 0x9F14 &&
                       map.Caller.OriginalToken == 0x9ED7 &&
                       map.Caller.ReplacementToken == 0x1010 &&
                       map.Caller.SavedReturnCursor == 0x9F16 &&
                       map.Caller.PostReturnTokenAddress == 0x9F16 &&
                       map.Caller.PostReturnToken == 0x75A9 &&
                       map.Caller.ParentTokenAddress == 0x9F3D &&
                       map.Caller.ParentToken == 0x9F10 &&
                       map.Caller.ParentSuccessorAddress == 0x9F3F &&
                       map.Caller.ParentSuccessorToken == 0x792F &&
                       map.Caller.FinalReturnAddress == 0x1024 &&
                       map.Caller.ReturnHandlerAddress == 0x7931,
                    "Caller binding differs");

                Assert(map.Phases.All(phase =>
                        phase.Classification == LargerReplacementSourceMap.PhaseClassification),
                    "Map phase classification overclaims execution");
                LargerReplacementStaticPhase dispatch =
                    map.Phases.Single(phase => phase.Phase == "caller-dispatch");
                Assert(dispatch.Pc == 0x00FC && dispatch.Y == 0x9F14 &&
                       dispatch.Token == 0x9ED7 && dispatch.ReplacementToken == 0x1010,
                    "Caller dispatch phase differs");
                LargerReplacementStaticPhase trampoline =
                    map.Phases.Single(phase => phase.Phase == "header-trampoline-entry");
                Assert(trampoline.Pc == 0x00F8 && trampoline.X == 0x1012 &&
                       trampoline.Y == 0x9F16 && trampoline.SavedCursor == 0x9F16,
                    "Trampoline phase differs");
                LargerReplacementStaticPhase finalPrefetch =
                    map.Phases.Single(phase => phase.Phase == "body-prefetch-6");
                Assert(finalPrefetch.Y == 0x1024 && finalPrefetch.Token == 0x792F,
                    "Final prefetch phase differs");
                LargerReplacementStaticPhase returnHandler =
                    map.Phases.Single(phase => phase.Phase == "return-handler");
                Assert(returnHandler.Y == 0x1026 && returnHandler.SavedCursor == 0x9F16 &&
                       returnHandler.HandlerAddress == 0x7931,
                    "Return handler phase differs");
                LargerReplacementStaticPhase postReturn =
                    map.Phases.Single(phase => phase.Phase == "post-return-prefetch");
                Assert(postReturn.Y == 0x9F16 && postReturn.Token == 0x75A9,
                    "Post-return phase differs");

                Assert(map.Semantics.BodyUNet == 0 &&
                       map.Semantics.EntryDepth == 1 &&
                       map.Semantics.ExitDepth == 1 &&
                       map.Semantics.TrampolineSDelta == -2 &&
                       map.Semantics.ReturnHandlerSDelta == 2 &&
                       map.Semantics.WholeCallSNet == 0 &&
                       !map.Semantics.NestedCall &&
                       map.Semantics.Classification ==
                       LargerReplacementSourceMap.PhaseClassification,
                    "Map semantic contract differs");

                map.ValidateImage(build.CopyOutputImage());
                Assert(map.Resolve(0x1012, build.CopyOutputImage()).ImageByte == 0x79,
                    "Map image lookup differs");
                Reject(() => map.Resolve(0x1100), "no entry");
                Reject(() => map.Resolve(0x9ED7), "no entry");
            });

            Check("Static stack and 16-bit wrap vectors match task49", () =>
            {
                LargerReplacementStaticContract contract = build.StaticContract;
                Assert(contract.EntryDepth == 1 && contract.ExitDepth == 1 &&
                       contract.BodyUNet == 0 && contract.TrampolineSDelta == -2 &&
                       contract.ReturnHandlerSDelta == 2 && contract.WholeCallSNet == 0 &&
                       !contract.NestedCall,
                    "Static stack/frame contract differs");
                Assert(contract.Classification ==
                       LargerReplacementBuilder.StaticPhaseClassification,
                    "Static contract overclaims execution");
                Assert(contract.Vectors.Count == 5, "Static vector count differs");

                (ushort Input, ushort Copied, ushort Exit, ushort After)[] expected =
                {
                    (0x0000, 0x0000, 0x0001, 0x0000),
                    (0x0001, 0x0001, 0x0002, 0x0000),
                    (0x7FFF, 0x80FF, 0x8100, 0xFFFF),
                    (0x8000, 0x8000, 0x8001, 0xFFFF),
                    (0xFFFF, 0x00FF, 0x0100, 0x0000)
                };
                for (int index = 0; index < expected.Length; index++)
                {
                    LargerReplacementVector actual = contract.Vectors[index];
                    Assert(actual.Input == expected[index].Input &&
                           actual.CopiedValue == expected[index].Copied &&
                           actual.CalleeExit == expected[index].Exit &&
                           actual.AfterSuccessor == expected[index].After,
                        $"Static vector {index} differs");
                    ushort copied = (ushort)(((actual.Input + 0xFF80) & 0xFFFF) ^ 0xFF80);
                    ushort exit = (ushort)((copied + 0x0001) & 0xFFFF);
                    ushort after = (exit & 0x8000) != 0 ? (ushort)0xFFFF : (ushort)0x0000;
                    Assert(copied == actual.CopiedValue &&
                           exit == actual.CalleeExit &&
                           after == actual.AfterSuccessor,
                        $"Independent vector arithmetic {index} differs");
                }

                int cells = 1;
                int uDelta = 0;
                foreach (LargerReplacementNode node in build.Nodes)
                {
                    int delta = node.Token switch
                    {
                        0x795B => -2,
                        0x787E => 2,
                        0x7AAF => 2,
                        0x792F => 0,
                        _ => throw new InvalidDataException(
                            $"Unexpected node token {node.Token:X4}")
                    };
                    Assert(node.StackDeltaBytes == delta,
                        $"Node {node.Index} stack delta differs");
                    if (node.Token == 0x795B)
                        cells += 1;
                    else if (node.Token is 0x787E or 0x7AAF)
                        cells -= 1;
                    Assert(node.DepthAfter == cells,
                        $"Node {node.Index} depth differs");
                    uDelta += delta;
                }
                Assert(cells == 1 && uDelta == 0,
                    "Independent body stack does not end at depth 1 and U delta 0");
                Assert(build.CopyOutputImage().AsSpan(0x1012, 20)
                        .IndexOfAny(new byte[] { 0x34, 0x35 }) < 0,
                    "Body unexpectedly contains a PSHS/PULS prefix byte");
            });

            Check("Task48 append-after-return is rejected by reachability", () =>
            {
                byte[] task48Body = Convert.FromHexString(
                    "795BFF80787E795BFF807AAF792F795B0001787E792F");
                try
                {
                    LargerReplacementBuilder.AnalyzeFlatBody(
                        task48Body, 0x1012, 0x1012 + task48Body.Length);
                    throw new InvalidDataException("Task48 payload was accepted");
                }
                catch (InvalidDataException error)
                {
                    Assert(error.Message.Contains("returnAddress=101E",
                            StringComparison.OrdinalIgnoreCase),
                        $"Task48 rejection does not report the early return: {error.Message}");
                    Assert(error.Message.Contains("unreachableAddresses=[1020,1024,1026]",
                            StringComparison.OrdinalIgnoreCase),
                        $"Task48 rejection does not report the unreachable nodes: {error.Message}");
                    Assert(error.Message.Contains("reachab",
                            StringComparison.OrdinalIgnoreCase),
                        $"Task48 rejection is not a reachability failure: {error.Message}");
                }

                Reject(() => LargerReplacementBuilder.AnalyzeFlatBody(
                        Convert.FromHexString("795BFF"), 0x1012, 0x1015),
                    "truncated");
                Reject(() => LargerReplacementBuilder.AnalyzeFlatBody(
                        Convert.FromHexString("795BFF801234"), 0x1012, 0x1018),
                    "unsupported");
                Reject(() => LargerReplacementBuilder.AnalyzeFlatBody(
                        Convert.FromHexString("795BFF80787E792F792F"), 0x1012, 0x101C),
                    "reachability");
                Reject(() => LargerReplacementBuilder.AnalyzeFlatBody(
                        Convert.FromHexString("795BFF80"), 0x1012, 0x1016),
                    "missing");
                Reject(() => LargerReplacementBuilder.AnalyzeFlatBody(
                        Convert.FromHexString("787E"), 0x1012, 0x1014),
                    "underflow");
                Reject(() => LargerReplacementBuilder.ValidateComposedPayload(
                        Convert.FromHexString(
                            "00F9795BFF80787E795BFF807AAF795B0001787E792F")),
                    "header");
                Reject(() => LargerReplacementBuilder.ValidateComposedPayload(
                        Convert.FromHexString(
                            "00F8795BFF80787E795BFF807AAF795B0001787E792E")),
                    "body");
                Reject(() => LargerReplacementBuilder.ValidateComposedPayload(
                        Convert.FromHexString("00F8795BFF80")), "length");
            });

            Check("Identity and range guards reject length SHA1 SHA256 guards and last FF byte", () =>
            {
                byte[] shortImage = rom.AsSpan(0, rom.Length - 1).ToArray();
                Reject(() => LargerReplacementBuilder.Build(shortImage), "length");

                byte[] tampered = (byte[])rom.Clone();
                tampered[0x1400] ^= 1;
                Reject(() => LargerReplacementBuilder.Build(tampered), "SHA1");

                string tamperedSha1 = Sha1(tampered);
                string tamperedSha256 = Sha256(tampered);
                Reject(
                    () => NineEdNineDecoder.ValidateIdentity(
                        tampered, 65536,
                        "0000000000000000000000000000000000000000",
                        tamperedSha256),
                    "SHA1");
                try
                {
                    NineEdNineDecoder.ValidateIdentity(
                        tampered, 65536, tamperedSha1,
                        "0000000000000000000000000000000000000000000000000000000000000000");
                    throw new InvalidDataException("SHA256 identity mismatch was accepted");
                }
                catch (InvalidDataException error)
                {
                    Assert(error.Message.Contains("SHA256", StringComparison.OrdinalIgnoreCase),
                        $"Expected SHA256 rejection, got '{error.Message}'");
                }

                byte[] lastByte = (byte[])rom.Clone();
                lastByte[0x1025] = 0xFE;
                Reject(
                    () => ExtensionRangeAllocator.CreateWithoutIdentityForTests(
                        lastByte, ExtensionRangeDescriptor.Approved),
                    "FF");

                byte[] leftGuard = (byte[])rom.Clone();
                leftGuard[0x1000] ^= 1;
                Reject(
                    () => ExtensionRangeAllocator.CreateWithoutIdentityForTests(
                        leftGuard, ExtensionRangeDescriptor.Approved),
                    "left guard");

                byte[] rightGuard = (byte[])rom.Clone();
                rightGuard[0x13F0] ^= 1;
                Reject(
                    () => ExtensionRangeAllocator.CreateWithoutIdentityForTests(
                        rightGuard, ExtensionRangeDescriptor.Approved),
                    "right guard");

                var allocator = ExtensionRangeAllocator.CreateWithoutIdentityForTests(
                    rom, ExtensionRangeDescriptor.Approved);
                Reject(
                    () => allocator.Plan(new[]
                    {
                        new ExtensionAllocationRequest("overflow", 993)
                    }),
                    "exceeds");
                ExtensionRangePlan plan = allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest("larger", 22)
                });
                Assert(plan.Allocations.Single().CpuStart == 0x1010 &&
                       plan.Allocations.Single().CpuEnd == 0x1025 &&
                       plan.Allocations.Single().Length == 22,
                    "Allocator does not place the larger replacement at 1010-1025");
            });

            Check("Public larger repair rejects wrong identity caller payload range and changes", () =>
            {
                byte[] unrepaired = build.CopyUnrepairedImage();
                var valid = new VmIlLargerReplacementPatchSpec(
                    0x1010,
                    Enumerable.Repeat((byte)0xFF, 22).ToArray(),
                    Convert.FromHexString(LargerReplacementBuilder.PayloadHex),
                    0x9F14,
                    new byte[] { 0x9E, 0xD7 },
                    new byte[] { 0x10, 0x10 });

                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot.AsSpan(0, originalSnapshot.Length - 1),
                        unrepaired, valid), "length");
                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot, unrepaired.AsSpan(0, unrepaired.Length - 1), valid),
                    "length");
                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot, unrepaired, null!), "missing");

                byte[] tamperedOriginal = (byte[])originalSnapshot.Clone();
                tamperedOriginal[0x1400] ^= 1;
                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        tamperedOriginal, unrepaired, valid), "SHA1");

                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot, unrepaired,
                        valid with { CallerOffset = 0x9F15 }), "9F14");
                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot, unrepaired,
                        valid with { CallerOffset = 0x1010 }), "overlap");
                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot, unrepaired,
                        valid with { ExpectedCallerBytes = new byte[] { 0x9E, 0xD8 } }),
                    "9ED7");
                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot, unrepaired,
                        valid with { ReplacementCallerBytes = new byte[] { 0x10, 0x11 } }),
                    "1010");
                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot, unrepaired,
                        valid with { AllocationStart = 0x9F14 }), "1010-1025");
                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot, unrepaired,
                        valid with { AllocationStart = 0xFFFF }), "1010-1025");
                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot, unrepaired,
                        valid with { ExpectedAllocationBytes = new byte[21] }),
                    "1010-1025");
                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot, unrepaired,
                        valid with { ReplacementAllocationBytes = new byte[23] }),
                    "1010-1025");

                byte[] nonFill = Enumerable.Repeat((byte)0xFF, 22).ToArray();
                nonFill[21] = 0xFE;
                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot, unrepaired,
                        valid with { ExpectedAllocationBytes = nonFill }), "FF");

                byte[] wrongHeader = Convert.FromHexString(
                    LargerReplacementBuilder.PayloadHex);
                wrongHeader[1] = 0xF9;
                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot, unrepaired,
                        valid with { ReplacementAllocationBytes = wrongHeader }), "reviewed");

                byte[] wrongBody = Convert.FromHexString(
                    LargerReplacementBuilder.PayloadHex);
                wrongBody[4] ^= 1;
                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot, unrepaired,
                        valid with { ReplacementAllocationBytes = wrongBody }), "reviewed");

                byte[] extra = (byte[])unrepaired.Clone();
                extra[0x1401] ^= 1;
                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot, extra, valid), "unexpected changes");
                byte[] guard = (byte[])unrepaired.Clone();
                guard[0x1000] ^= 1;
                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot, guard, valid), "unexpected changes");
                byte[] protectedCell = (byte[])unrepaired.Clone();
                protectedCell[0x1003] ^= 1;
                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot, protectedCell, valid), "unexpected changes");
                byte[] successor = (byte[])unrepaired.Clone();
                successor[0x9F16] ^= 1;
                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot, successor, valid), "unexpected changes");
                byte[] parent = (byte[])unrepaired.Clone();
                parent[0x9F3D] ^= 1;
                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot, parent, valid), "unexpected changes");
                byte[] premodifiedFields = (byte[])unrepaired.Clone();
                premodifiedFields[0xFFD1] ^= 1;
                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot, premodifiedFields, valid), "pre-modified");
                byte[] wrongCaller = (byte[])unrepaired.Clone();
                wrongCaller[0x9F14] = 0x9E;
                wrongCaller[0x9F15] = 0xD7;
                Reject(() => VmIlIntegrity.RepairLargerReplacement(
                        originalSnapshot, wrongCaller, valid), "1010");

                LargerReplacementSourceMap map = build.SourceMap;
                Reject(() => map.ValidateBuild(new string('0', 64)), "identity");
                Reject(() => map.ValidateImage(originalSnapshot), "identity");
                Reject(() => map.Resolve(0x1012, new string('0', 64)), "identity");
                byte[] tamperedOutput = build.CopyOutputImage();
                tamperedOutput[0x1012] ^= 1;
                Reject(() => map.ValidateImage(tamperedOutput), "identity");
            });

            Check("Repeated builds are deterministic and the input ROM is unchanged", () =>
            {
                LargerReplacementBuildResult rebuilt = LargerReplacementBuilder.Build(rom);
                Assert(rebuilt.OutputImageSha1 == build.OutputImageSha1 &&
                       rebuilt.OutputImageSha256 == build.OutputImageSha256,
                    "Repeated build output identity differs");
                Assert(rebuilt.UnrepairedImageSha1 == build.UnrepairedImageSha1 &&
                       rebuilt.UnrepairedImageSha256 == build.UnrepairedImageSha256,
                    "Repeated unrepaired identity differs");
                Assert(rebuilt.CopyOutputImage().SequenceEqual(build.CopyOutputImage()),
                    "Repeated build bytes differ");
                Assert(rebuilt.CopyUnrepairedImage().SequenceEqual(build.CopyUnrepairedImage()),
                    "Repeated unrepaired bytes differ");
                Assert(rebuilt.CopyPayloadBytes().SequenceEqual(build.CopyPayloadBytes()),
                    "Repeated payload bytes differ");
                Assert(rebuilt.ChangedOffsets.SequenceEqual(build.ChangedOffsets) &&
                       rebuilt.UnrepairedChangedOffsets.SequenceEqual(
                           build.UnrepairedChangedOffsets) &&
                       rebuilt.RepairChangedOffsets.SequenceEqual(
                           build.RepairChangedOffsets),
                    "Repeated build diff differs");
                Assert(rebuilt.SourceMap.BuildId == build.SourceMap.BuildId &&
                       rebuilt.SourceMap.Phases.Count == build.SourceMap.Phases.Count &&
                       rebuilt.SourceMap.Entries.Count == build.SourceMap.Entries.Count,
                    "Repeated build map differs");
                byte[] firstMap = JsonSerializer.SerializeToUtf8Bytes(build.SourceMap);
                byte[] secondMap = JsonSerializer.SerializeToUtf8Bytes(rebuilt.SourceMap);
                Assert(firstMap.SequenceEqual(secondMap), "Repeated map JSON differs");
                Assert(rebuilt.StaticContract.Vectors.SequenceEqual(
                        build.StaticContract.Vectors),
                    "Repeated static vectors differ");
                Assert(rom.SequenceEqual(originalSnapshot) &&
                       Sha1(rom) == beforeSha1 && Sha256(rom) == beforeSha256,
                    "Builder mutated its caller input ROM");
            });

            Check("Owned buffers report and map aliases cannot alter the retained build", () =>
            {
                byte[] first = build.CopyOutputImage();
                first[0x1010] ^= 1;
                byte[] second = build.CopyOutputImage();
                Assert(second[0x1010] == 0x00,
                    "Mutating one output copy changed the owned build result");
                Assert(Sha256(second) == ExpectedOutputSha256,
                    "Owned output identity changed after caller mutation");
                Assert(Sha1(build.CopyOutputImage()) == ExpectedOutputSha1,
                    "Owned output SHA1 changed after caller mutation");
                byte[] unrepaired = build.CopyUnrepairedImage();
                unrepaired[0x1010] ^= 1;
                Assert(build.CopyUnrepairedImage()[0x1010] == 0x00,
                    "Mutating an unrepaired copy changed the owned build result");
                byte[] payload = build.CopyPayloadBytes();
                payload[0] = 0xFF;
                Assert(build.CopyPayloadBytes()[0] == 0x00,
                    "Mutating a payload copy changed the owned build result");

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
                    ((IList<LargerReplacementNode>)build.Nodes)[0] =
                        build.Nodes[1], "Nodes index replacement");
                RejectReadOnly(() =>
                    ((IList<LargerReplacementVector>)build.StaticContract.Vectors)[0] =
                        build.StaticContract.Vectors[1], "Static vector index replacement");

                VmIlIntegrityReport report = build.IntegrityReport;
                string repairedFields = report.RepairedStoredFieldsHex;
                int firstRepaired = report.RepairedChangedOffsets[0];
                VmIlIntegrityField firstField = report.Fields[0];
                report.RepairedChangedOffsets[0] = 0x0100;
                report.UnrepairedChangedOffsets[0] = 0x0100;
                report.RepairChangedOffsets[0] = 0x0100;
                ((IList<VmIlIntegrityField>)report.Fields)[0] =
                    new VmIlIntegrityField("tampered", 0, 0, 0, "tampered");

                VmIlIntegrityReport retained = build.IntegrityReport;
                Assert(retained.RepairedStoredFieldsHex == repairedFields,
                    "Retained integrity fields changed after caller mutation");
                Assert(retained.RepairedChangedOffsets[0] == firstRepaired,
                    "Retained repaired offsets changed after caller mutation");
                Assert(retained.UnrepairedChangedOffsets[0] == 0x1010,
                    "Retained unrepaired offsets are not the reviewed first offset");
                Assert(retained.RepairChangedOffsets.SequenceEqual(
                        Enumerable.Range(0xFFD1, 5)),
                    "Retained repair offsets no longer match FFD1-FFD5");
                Assert(retained.Fields[0] == firstField && retained.Fields.Count == 5,
                    "Retained integrity field list changed after caller mutation");
                Assert(retained.UnrepairedChangedOffsets.Length == 22 &&
                       retained.RepairedChangedOffsets.Length == 27,
                    "Retained integrity report counts changed");
                Assert(build.CopyOutputImage().AsSpan(0xFFD1, 5).SequenceEqual(
                        Convert.FromHexString(ExpectedRepairedFieldsHex)),
                    "Retained output fields changed after report mutation");

                LargerReplacementSourceMap map = build.SourceMap;
                RejectReadOnly(() =>
                    ((IList<LargerReplacementMapEntry>)map.Entries)[0] =
                        map.Entries[1], "Map entries index replacement");
                RejectReadOnly(() =>
                    ((IList<LargerReplacementInlineOperand>)map.InlineOperands)[0] =
                        map.InlineOperands[1], "Map inline operand index replacement");
                RejectReadOnly(() =>
                    ((IList<LargerReplacementStaticPhase>)map.Phases)[0] =
                        map.Phases[1], "Map phase index replacement");
                RejectReadOnly(() =>
                    ((IList<LargerReplacementNode>)map.Nodes)[0] =
                        map.Nodes[1], "Map nodes index replacement");

                LargerReplacementMapEntry firstEntry = map.Resolve(0x1010);
                string entriesJson = JsonSerializer.Serialize(map.Entries);
                LargerReplacementMapEntry retainedEntry = map.Resolve(0x1010);
                Assert(retainedEntry == firstEntry, "Retained map entry changed");
                Assert(JsonSerializer.Serialize(map.Entries) == entriesJson,
                    "Retained map entries changed after caller mutation");
                Assert(map.BuildId == ExpectedOutputSha256,
                    "Retained map build identity changed after caller mutation");
            });

            Check("Serialized map and build outputs are internally consistent", () =>
            {
                string mapJson = JsonSerializer.Serialize(
                    build.SourceMap, new JsonSerializerOptions { WriteIndented = true });
                using JsonDocument document = JsonDocument.Parse(mapJson);
                JsonElement root = document.RootElement;
                Assert(root.GetProperty("OutputImageSha256").GetString() ==
                       ExpectedOutputSha256, "Serialized map build identity differs");
                Assert(root.GetProperty("Entries").GetArrayLength() == 30,
                    "Serialized map entry count differs");
                Assert(root.GetProperty("InlineOperands").GetArrayLength() == 3,
                    "Serialized map operand count differs");
                Assert(root.GetProperty("Phases").GetArrayLength() == 17,
                    "Serialized map phase count differs");
                Assert(root.GetProperty("Classification").GetString() ==
                       LargerReplacementSourceMap.BuildClassification,
                    "Serialized map classification differs");
                Assert(root.GetProperty("Caller").GetProperty("SavedReturnCursor")
                           .GetUInt16() == 0x9F16,
                    "Serialized caller saved cursor differs");
                Assert(root.GetProperty("Caller").GetProperty("PostReturnToken")
                           .GetUInt16() == 0x75A9,
                    "Serialized caller post-return token differs");
            });
        }
        catch
        {
            WriteFailureOutputs(outputDirectory, checks);
            throw;
        }

        var report = new LargerReplacementVerificationReport(
            "il-larger-replacement-build-50",
            1,
            "pass",
            "STATIC larger-replacement builder/map verification only. No MAME run, natural " +
            "execution, gameplay or hardware compatibility is claimed.",
            romPath,
            rom.Length,
            beforeSha1,
            beforeSha256,
            Sha1(rom),
            Sha256(rom),
            rom.SequenceEqual(originalSnapshot),
            LargerReplacementBuilder.PayloadHex,
            build.Nodes.Count,
            build.SourceMap.InlineOperands.Count,
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
            build.SourceMap.InlineOperands.Count,
            build.SourceMap.Nodes.Count,
            build.SourceMap.Phases.Count,
            "9F16",
            "75A9",
            "1024",
            build.StaticContract.Vectors.ToArray(),
            checks,
            new[]
            {
                "The body at 1012-1025 has not executed; the 0000 -> 0001 callee-exit " +
                "prediction is static.",
                "75A9 then normalizes positive 0001 to 0000, so the parent result may remain " +
                "0000; no gameplay or parent-level change is claimed.",
                "The original 9ED7/9ED9 definition, other caller bytes and all guards are " +
                "preserved by the exact diff; the broader purpose of 9F12 remains unresolved.",
                "The extension range 1010-13EF is human-approved for this exact ROM revision only.",
                "Integrity repair is algorithmically verified in the recovered field order; it " +
                "is not natural boot acceptance.",
                "No MAME run, capture, PC/Y/U/S observation or hardware test was performed."
            },
            "Next boundary is a separately dispatched natural fresh-boot MAME task observing " +
            "the new body at 1012, inline operands 1014/101A/1020, final return at 1024, " +
            "saved cursor 9F16 and post-return token 75A9. No execution proof exists here.");

        WriteOutputs(outputDirectory, report);
        WritePrivateBuild(outputDirectory, build);
        Console.WriteLine(
            $"PASS {checks.Count} larger-replacement groups; output SHA256 " +
            $"{build.OutputImageSha256}, fields {build.IntegrityReport.RepairedStoredFieldsHex}, " +
            $"changed {build.ChangedOffsets.Count}.");
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
        string outputDirectory, LargerReplacementVerificationReport report)
    {
        Directory.CreateDirectory(outputDirectory);
        var log = new StringBuilder();
        log.AppendLine("FruitMachineLab il-larger-replacement-build-50 verification");
        log.AppendLine("ROM: " + report.RomPath);
        log.AppendLine("SHA1: " + report.RomSha1Before);
        log.AppendLine("SHA256: " + report.RomSha256Before);
        log.AppendLine("Input unchanged: " + report.InputUnchanged);
        log.AppendLine("Payload: " + report.PayloadHex);
        log.AppendLine("Nodes: " + report.NodeCount);
        log.AppendLine("Inline operands: " + report.InlineOperandCount);
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
        log.AppendLine("Map inline operands: " + report.MapInlineOperandCount);
        log.AppendLine("Map nodes: " + report.MapNodeCount);
        log.AppendLine("Map phases: " + report.MapPhaseCount);
        log.AppendLine("Caller saved cursor: " + report.CallerSavedCursorHex);
        log.AppendLine("Caller post-return token: " + report.CallerPostReturnTokenHex);
        log.AppendLine("Final return: " + report.FinalReturnAddressHex);
        foreach (LargerReplacementVector vector in report.StaticVectors)
            log.AppendLine(
                $"VECTOR {vector.Input:X4} -> {vector.CopiedValue:X4} -> " +
                $"{vector.CalleeExit:X4} -> {vector.AfterSuccessor:X4}");
        foreach (LargerReplacementVerificationCheck check in report.Checks)
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
        string outputDirectory, LargerReplacementBuildResult build)
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
            Path.Combine(outputDirectory, "larger-replacement-source-map.json"),
            mapJson + Environment.NewLine);
        string buildJson = JsonSerializer.Serialize(
            new
            {
                schemaVersion = 1,
                taskId = "il-larger-replacement-build-50",
                classification = build.Status,
                originalRomSha1 = build.OriginalRomSha1,
                originalRomSha256 = build.OriginalRomSha256,
                unrepairedImageSha1 = build.UnrepairedImageSha1,
                unrepairedImageSha256 = build.UnrepairedImageSha256,
                outputImageSha1 = build.OutputImageSha1,
                outputImageSha256 = build.OutputImageSha256,
                allocation = new
                {
                    start = "1010",
                    endInclusive = "1025",
                    length = 22,
                    headerHex = LargerReplacementBuilder.HeaderHex,
                    bodyHex = LargerReplacementBuilder.BodyHex,
                    payloadHex = LargerReplacementBuilder.PayloadHex
                },
                nodes = build.Nodes,
                callerTokenAddress = "9F14",
                callerExpectedToken = "9ED7",
                callerReplacementToken = "1010",
                callerSavedReturnCursor = "9F16",
                callerPostReturnToken = "75A9",
                finalReturnAddress = "1024",
                integrityOriginalFieldsHex =
                    build.IntegrityReport.OriginalStoredFieldsHex,
                integrityRepairedFieldsHex =
                    build.IntegrityReport.RepairedStoredFieldsHex,
                unrepairedChangedOffsets = build.UnrepairedChangedOffsets,
                changedOffsets = build.ChangedOffsets,
                repairChangedOffsets = build.RepairChangedOffsets,
                sourceMap = new
                {
                    buildId = build.SourceMap.BuildId,
                    entries = build.SourceMap.Entries.Count,
                    inlineOperands = build.SourceMap.InlineOperands,
                    phases = build.SourceMap.Phases,
                    caller = build.SourceMap.Caller,
                    semantics = build.SourceMap.Semantics,
                    staticContract = build.StaticContract
                },
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
        string outputDirectory, IReadOnlyList<LargerReplacementVerificationCheck> checks)
    {
        if (Directory.Exists(outputDirectory)) return;
        Directory.CreateDirectory(outputDirectory);
        var builder = new StringBuilder();
        builder.AppendLine(
            "FruitMachineLab il-larger-replacement-build-50 verification FAILED");
        foreach (LargerReplacementVerificationCheck check in checks)
        {
            builder.AppendLine((check.Passed ? "PASS " : "FAIL ") + check.Name +
                (check.Error is null ? string.Empty : ": " + check.Error));
        }
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

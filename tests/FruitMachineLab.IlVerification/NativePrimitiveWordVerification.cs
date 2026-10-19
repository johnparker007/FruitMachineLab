using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using FruitMachineLab.Il;

namespace FruitMachineLab.IlVerification;

internal sealed record NativePrimitiveVerificationCheck(
    string Name, bool Passed, string? Error);

internal sealed record NativePrimitiveVerificationReport(
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
    string TokenHex,
    string HandlerHex,
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
    int MapInstructionCount,
    int MapPhaseCount,
    string CallerSavedCursorHex,
    string CallerPostReturnTokenHex,
    IReadOnlyList<NativePrimitiveVerificationCheck> Checks,
    IReadOnlyList<string> Limitations,
    string RemainingBoundary);

internal static class NativePrimitiveWordVerification
{
    private const string ExpectedTokenHex = "1012";
    private const string ExpectedHandlerHex = "ECC4C38000EDC40EFC";
    private const string ExpectedPayloadHex = "1012ECC4C38000EDC40EFC";
    private const string ExpectedOriginalFieldsHex = "3E761E2605";
    private const string ExpectedRepairedFieldsHex = "E93F3C61B5";
    private const string ExpectedOutputSha1 = "22BF419CF68F243169F05193B0E1AAF708D07707";
    private const string ExpectedOutputSha256 =
        "67E9390B8CD5EB941E1928F5E38129DF265207536002B6304C2A3B413E9B3AA8";

    private static readonly int[] ExpectedChangedOffsets =
    {
        0x1010, 0x1011, 0x1012, 0x1013, 0x1014, 0x1015, 0x1016, 0x1017, 0x1018,
        0x1019, 0x101A, 0x9F14, 0x9F15, 0xFFD1, 0xFFD2, 0xFFD3, 0xFFD4, 0xFFD5
    };

    private static readonly int[] ExpectedUnrepairedChangedOffsets =
    {
        0x1010, 0x1011, 0x1012, 0x1013, 0x1014, 0x1015, 0x1016, 0x1017, 0x1018,
        0x1019, 0x101A, 0x9F14, 0x9F15
    };

    public static void Run(string romPath, string repositoryRoot, string outputDirectory)
    {
        if (Directory.Exists(outputDirectory))
            throw new IOException($"Output directory already exists: {outputDirectory}");

        byte[] rom = File.ReadAllBytes(romPath);
        byte[] originalSnapshot = (byte[])rom.Clone();
        string beforeSha1 = Sha1(rom);
        string beforeSha256 = Sha256(rom);
        var checks = new List<NativePrimitiveVerificationCheck>();
        NativePrimitiveBuildResult build = null!;

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
                checks.Add(new NativePrimitiveVerificationCheck(name, true, null));
                Console.WriteLine("PASS " + name);
            }
            catch (Exception error)
            {
                checks.Add(new NativePrimitiveVerificationCheck(name, false, error.Message));
                throw new InvalidOperationException($"Check failed: {name}: {error.Message}", error);
            }
        }

        try
        {
            Check("Builder compiles the reviewed direct token handler and caller", () =>
            {
                build = NativePrimitiveWordBuilder.Build(rom);

                Assert(build.OriginalRomSha1 == beforeSha1, "Builder original SHA1 differs");
                Assert(build.OriginalRomSha256 == beforeSha256, "Builder original SHA256 differs");
                Assert(build.OutputImageSha1 == ExpectedOutputSha1,
                    "Builder output SHA1 differs from the reviewed contract");
                Assert(build.OutputImageSha256 == ExpectedOutputSha256,
                    "Builder output SHA256 differs from the reviewed contract");
                Assert(build.OutputImage.Length == 65536, "Builder output length differs");
                Assert(build.BuildId == ExpectedOutputSha256, "Builder build identity differs");
                Assert(build.PayloadBytes.Length == 11, "Payload length differs");
                Assert(Convert.ToHexString(build.CopyPayloadBytes()) == ExpectedPayloadHex,
                    "Payload bytes differ");
                Assert(Convert.ToHexString(build.OutputImage.Slice(0x1010, 11)) ==
                    ExpectedPayloadHex, "Token/handler allocation bytes differ");
                Assert(Convert.ToHexString(build.OutputImage.Slice(0x1010, 2)) ==
                    ExpectedTokenHex, "Token cell differs");
                Assert(Convert.ToHexString(build.OutputImage.Slice(0x1012, 9)) ==
                    ExpectedHandlerHex, "Handler bytes differ");
                Assert(Convert.ToHexString(build.OutputImage.Slice(0x9F14, 2)) == "1010",
                    "Caller token replacement differs");
                Assert(Convert.ToHexString(build.OutputImage.Slice(0x9F16, 2)) == "75A9",
                    "Caller successor token differs");
                Assert(Convert.ToHexString(build.OutputImage.Slice(0x9ED7, 2)) == "00F8",
                    "Original 9ED7 header changed");
                Assert(Convert.ToHexString(build.OutputImage.Slice(0x9ED9, 14)) ==
                    NativePrimitiveWordBuilder.OriginalDefinitionBodyHex,
                    "Original 9ED9 body changed");
                Assert(Convert.ToHexString(build.OutputImage.Slice(0x7927, 8)) ==
                    "34203184AEA16E91", "Runtime dispatch template changed");
                Assert(build.Status.Contains("STATIC COMPILED", StringComparison.Ordinal) &&
                       build.Status.Contains("not execution proof",
                           StringComparison.OrdinalIgnoreCase),
                    "Build status overclaims execution");
            });

            Check("Independent diff is exactly the reviewed 18 offsets", () =>
            {
                int[] unrepairedDiff = Diff(rom, build.CopyUnrepairedImage());
                Assert(unrepairedDiff.SequenceEqual(ExpectedUnrepairedChangedOffsets),
                    "Unrepaired independent diff is not 11 allocation plus 2 caller changes");
                Assert(build.UnrepairedChangedOffsets.SequenceEqual(unrepairedDiff),
                    "Reported unrepaired diff differs from the independent diff");

                int[] outputDiff = Diff(rom, build.CopyOutputImage());
                Assert(outputDiff.Length == 18, "Final independent diff count differs");
                Assert(outputDiff.SequenceEqual(ExpectedChangedOffsets),
                    "Final independent diff is not the reviewed 18 offsets");
                Assert(outputDiff.SequenceEqual(build.ChangedOffsets),
                    "Reported final diff differs from the independent diff");
                Assert(outputDiff.SequenceEqual(
                        unrepairedDiff.Concat(Enumerable.Range(0xFFD1, 5)).ToArray()),
                    "Final diff is not unrepaired diff plus FFD1-FFD5");
                for (int offset = 0; offset < rom.Length; offset++)
                {
                    bool allowed = (offset >= 0x1010 && offset <= 0x101A) ||
                                   (offset >= 0x9F14 && offset <= 0x9F15) ||
                                   (offset >= 0xFFD1 && offset <= 0xFFD5);
                    if (!allowed)
                        Assert(build.CopyOutputImage()[offset] == rom[offset],
                            $"Independent preservation check failed at {offset:X4}");
                }

                Assert(build.CopyOutputImage().AsSpan(0x1000, 16)
                        .SequenceEqual(rom.AsSpan(0x1000, 16)),
                    "Final left guard differs");
                Assert(build.CopyOutputImage().AsSpan(0x1000, 4)
                        .SequenceEqual(rom.AsSpan(0x1000, 4)),
                    "Final protected cells differ");
                Assert(build.CopyOutputImage().AsSpan(0x13F0, 16)
                        .SequenceEqual(rom.AsSpan(0x13F0, 16)),
                    "Final right guard differs");
                Assert(build.CopyOutputImage().AsSpan(0x1400, 16)
                        .SequenceEqual(rom.AsSpan(0x1400, 16)),
                    "Integrity neighbour differs");
                Assert(build.CopyOutputImage().AsSpan(0x9ED7, 16)
                        .SequenceEqual(rom.AsSpan(0x9ED7, 16)),
                    "Original 9ED7/9ED9 definition changed");
                Assert(build.CopyOutputImage().AsSpan(0x9F10, 4)
                        .SequenceEqual(rom.AsSpan(0x9F10, 4)),
                    "Caller parent bytes 9F10-9F13 are not preserved");
                Assert(build.CopyOutputImage()[0x9F14] == 0x10 &&
                       build.CopyOutputImage()[0x9F15] == 0x10,
                    "Caller replacement at 9F14 is not 1010");
                Assert(build.CopyOutputImage().AsSpan(0x9F16, 8)
                        .SequenceEqual(rom.AsSpan(0x9F16, 8)),
                    "Caller bytes after the successor are not preserved");
            });

            Check("Independent ordered checksum reproduces E93F3C61B5", () =>
            {
                byte[] output = build.CopyOutputImage();
                string stored = Convert.ToHexString(output.AsSpan(0xFFD1, 5));
                Assert(stored == ExpectedRepairedFieldsHex, "Stored native fields differ");
                Assert(Convert.ToHexString(rom.AsSpan(0xFFD1, 5)) == ExpectedOriginalFieldsHex,
                    "Original stored fields differ");
                Assert(IndependentFields(output) == ExpectedRepairedFieldsHex,
                    "Independent ordered checksum does not reproduce the contract fields");
                Assert(build.IntegrityReport.RepairedStoredFieldsHex ==
                    ExpectedRepairedFieldsHex, "Builder integrity fields differ");
                Assert(build.IntegrityReport.RepairChangedOffsets.SequenceEqual(
                        Enumerable.Range(0xFFD1, 5)), "Repair-only diff is not FFD1-FFD5");
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

            Check("Map models C/T/H direct entry boundaries and static return context", () =>
            {
                NativePrimitiveSourceMap map = build.SourceMap;
                Assert(map.OutputImageSha256 == build.OutputImageSha256,
                    "Map is not bound to the final output SHA256");
                Assert(map.BuildId == build.OutputImageSha256, "Map build ID differs");
                Assert(map.OriginalRomSha1 == beforeSha1 &&
                       map.OriginalRomSha256 == beforeSha256,
                    "Map original identity differs");
                Assert(map.Entries.Count == 15, "Map entry count differs");
                Assert(map.Instructions.Count == 4, "Map instruction count differs");
                Assert(map.Phases.Count == 12, "Map phase count differs");
                Assert(!map.IsDefinitionHeader &&
                       map.PointerCellClassification.Contains("not_00f8",
                           StringComparison.Ordinal),
                    "Map wrongly describes the pointer cell as a 00F8 header");

                NativePrimitiveMapEntry token = map.Resolve(0x1010);
                Assert(token.Kind == NativePrimitiveMapKind.TokenCell &&
                       token.Token == 0x1012 && token.HandlerAddress == 0x1012,
                    "Token-cell entry differs");
                Assert(token.ImageByte == 0x10, "Token-cell first byte differs");
                Assert(map.Resolve(0x1011).ImageByte == 0x12, "Token-cell second byte differs");

                NativePrimitiveMapEntry handler = map.Resolve(0x1012);
                Assert(handler.Kind == NativePrimitiveMapKind.NativeHandler &&
                       handler.HandlerAddress == 0x1012,
                    "Handler entry differs");
                Assert(map.Resolve(0x1014).Operation == "ADDD #$8000",
                    "Second handler instruction differs");
                Assert(map.Resolve(0x1017).Operation == "STD ,U",
                    "Third handler instruction differs");
                Assert(map.Resolve(0x1019).Operation == "JMP $00FC",
                    "Final handler instruction differs");

                Assert(map.Instructions.Select(item => item.Address)
                        .SequenceEqual(new ushort[] { 0x1012, 0x1014, 0x1017, 0x1019 }),
                    "Instruction boundaries differ");
                Assert(map.Instructions[^1].NextAddress == 0x101B &&
                       map.Instructions[^1].BytesHex == "0EFC",
                    "Handler JMP ending differs");

                NativePrimitiveMapEntry caller = map.Resolve(0x9F14);
                Assert(caller.Kind == NativePrimitiveMapKind.CallerToken &&
                       caller.Token == 0x9ED7 && caller.ReplacementToken == 0x1010,
                    "Caller original/replacement token distinction differs");
                NativePrimitiveMapEntry successor = map.Resolve(0x9F16);
                Assert(successor.Kind == NativePrimitiveMapKind.CallerSuccessor &&
                       successor.Token == 0x75A9, "Caller successor entry differs");

                Assert(map.Dispatch.StreamAddressC == 0x9F14 &&
                       map.Dispatch.TokenCellT == 0x1010 &&
                       map.Dispatch.HandlerAddressH == 0x1012,
                    "Dispatch C/T/H binding differs");
                Assert(map.Dispatch.AfterDispatchPc == 0x1012 &&
                       map.Dispatch.AfterDispatchX == 0x1012 &&
                       map.Dispatch.AfterDispatchY == 0x9F16,
                    "After-dispatch PC/X/Y arithmetic differs");
                Assert(map.Dispatch.RejoinAddress == 0x00FC &&
                       map.Dispatch.RejoinY == 0x9F16,
                    "Dispatcher rejoin binding differs");
                Assert(map.Dispatch.ParentTokenAddress == 0x9F3D &&
                       map.Dispatch.ParentToken == 0x9F10 &&
                       map.Dispatch.ParentSuccessorAddress == 0x9F3F &&
                       map.Dispatch.ParentSuccessorToken == 0x792F,
                    "Outer return context differs");

                Assert(map.Semantics.StackEffect.Contains("8000h", StringComparison.Ordinal) &&
                       map.Semantics.DataStackPointerUnchanged &&
                       map.Semantics.ControlStackPointerUnchanged &&
                       map.Semantics.CursorUnchanged &&
                       map.Semantics.DClobbered &&
                       !map.Semantics.HDefinedOutput,
                    "Semantic contract overclaims or mismatches stack/cursor/register effects");
                Assert(map.Semantics.HContract.Contains("not defined",
                           StringComparison.OrdinalIgnoreCase),
                    "H contract asserts an H output");
                Assert(map.Semantics.IntentionalChange.Contains("Intentional",
                           StringComparison.Ordinal),
                    "Intentional behaviour change is not declared");
                Assert(map.Phases.All(phase =>
                        phase.Classification == NativePrimitiveSourceMap.PhaseClassification),
                    "Map phase classification overclaims execution");
                Assert(map.OuterReturn.Classification ==
                       NativePrimitiveSourceMap.PhaseClassification,
                    "Outer return context is not marked static");

                string handlerHex = Convert.ToHexString(build.OutputImage.Slice(0x1012, 9));
                Assert(!handlerHex.Contains("00F8", StringComparison.Ordinal),
                    "Handler wrongly contains a 00F8 composite header");
                Assert(!handlerHex.Contains("34", StringComparison.Ordinal) &&
                       !handlerHex.Contains("35", StringComparison.Ordinal) &&
                       !handlerHex.Contains("792F", StringComparison.Ordinal),
                    "Handler contains PSHS/PULS or the 792F return token");

                map.ValidateImage(build.CopyOutputImage());
                Assert(map.Resolve(0x1012, build.CopyOutputImage()).ImageByte == 0xEC,
                    "Map image lookup differs");
                Reject(() => map.Resolve(0x1012, new string('0', 64)), "identity");
                Reject(() => map.Resolve(0x1020), "no entry");
                Reject(() => map.Resolve(0x9ED7), "no entry");
            });

            Check("Public native repair rejects wrong identity caller payload range and changes", () =>
            {
                byte[] unrepaired = build.CopyUnrepairedImage();
                var valid = new VmIlNativePrimitivePatchSpec(
                    0x1010,
                    Enumerable.Repeat((byte)0xFF, 11).ToArray(),
                    Convert.FromHexString(ExpectedPayloadHex),
                    0x9F14,
                    new byte[] { 0x9E, 0xD7 },
                    new byte[] { 0x10, 0x10 });

                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        originalSnapshot.AsSpan(0, originalSnapshot.Length - 1),
                        unrepaired, valid), "length");
                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        originalSnapshot, unrepaired.AsSpan(0, unrepaired.Length - 1), valid),
                    "length");
                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        originalSnapshot, unrepaired, null!), "missing");

                byte[] tamperedOriginal = (byte[])originalSnapshot.Clone();
                tamperedOriginal[0x1400] ^= 1;
                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        tamperedOriginal, unrepaired, valid), "SHA1");

                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        originalSnapshot, unrepaired,
                        valid with { CallerOffset = 0x9F15 }), "9F14");
                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        originalSnapshot, unrepaired,
                        valid with { CallerOffset = 0x1015 }), "9F14");
                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        originalSnapshot, unrepaired,
                        valid with { ExpectedCallerBytes = new byte[] { 0x9E, 0xD8 } }),
                    "9ED7");
                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        originalSnapshot, unrepaired,
                        valid with { ReplacementCallerBytes = new byte[] { 0x10, 0x11 } }),
                    "1010");
                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        originalSnapshot, unrepaired,
                        valid with { AllocationStart = 0x9F14 }), "1010-101A");
                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        originalSnapshot, unrepaired,
                        valid with { AllocationStart = 0xFFFF }), "1010-101A");
                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        originalSnapshot, unrepaired,
                        valid with { ExpectedAllocationBytes = new byte[10] }),
                    "1010-101A");
                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        originalSnapshot, unrepaired,
                        valid with { ReplacementAllocationBytes = new byte[12] }),
                    "1010-101A");

                byte[] nonFill = Enumerable.Repeat((byte)0xFF, 11).ToArray();
                nonFill[10] = 0xFE;
                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        originalSnapshot, unrepaired,
                        valid with { ExpectedAllocationBytes = nonFill }), "FF");

                byte[] compositeHeader = Convert.FromHexString(ExpectedPayloadHex);
                compositeHeader[0] = 0x00;
                compositeHeader[1] = 0xF8;
                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        originalSnapshot, unrepaired,
                        valid with { ReplacementAllocationBytes = compositeHeader }),
                    "reviewed");

                byte[] missingJmp = Convert.FromHexString(ExpectedPayloadHex);
                missingJmp[10] = 0xFD;
                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        originalSnapshot, unrepaired,
                        valid with { ReplacementAllocationBytes = missingJmp }),
                    "reviewed");

                byte[] wrongHandler = Convert.FromHexString(ExpectedPayloadHex);
                wrongHandler[4] ^= 0x01;
                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        originalSnapshot, unrepaired,
                        valid with { ReplacementAllocationBytes = wrongHandler }),
                    "reviewed");

                byte[] wrongTarget = Convert.FromHexString(ExpectedPayloadHex);
                wrongTarget[1] = 0x13;
                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        originalSnapshot, unrepaired,
                        valid with { ReplacementAllocationBytes = wrongTarget }),
                    "reviewed");

                byte[] extra = (byte[])unrepaired.Clone();
                extra[0x1401] ^= 1;
                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        originalSnapshot, extra, valid), "unexpected changes");
                byte[] guard = (byte[])unrepaired.Clone();
                guard[0x1000] ^= 1;
                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        originalSnapshot, guard, valid), "unexpected changes");
                byte[] protectedCell = (byte[])unrepaired.Clone();
                protectedCell[0x1003] ^= 1;
                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        originalSnapshot, protectedCell, valid), "unexpected changes");
                byte[] premodifiedFields = (byte[])unrepaired.Clone();
                premodifiedFields[0xFFD1] ^= 1;
                Reject(() => VmIlIntegrity.RepairNativePrimitive(
                        originalSnapshot, premodifiedFields, valid), "pre-modified");

                NativePrimitiveSourceMap map = build.SourceMap;
                Reject(() => map.ValidateBuild(new string('0', 64)), "identity");
                Reject(() => map.ValidateImage(originalSnapshot), "identity");
                byte[] tampered = build.CopyOutputImage();
                tampered[0x1012] ^= 1;
                Reject(() => map.Resolve(0x1012, tampered), "identity");
            });

            Check("Identity and range guards reject length SHA1 SHA256 guards and last FF byte", () =>
            {
                byte[] shortImage = rom.AsSpan(0, rom.Length - 1).ToArray();
                Reject(() => NativePrimitiveWordBuilder.Build(shortImage), "length");

                byte[] tampered = (byte[])rom.Clone();
                tampered[0x1400] ^= 1;
                Reject(() => NativePrimitiveWordBuilder.Build(tampered), "SHA1");

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
                    throw new InvalidDataException(
                        "SHA256 identity mismatch was accepted");
                }
                catch (InvalidDataException error)
                {
                    Assert(error.Message.Contains("SHA256", StringComparison.OrdinalIgnoreCase),
                        $"Expected SHA256 rejection, got '{error.Message}'");
                }

                byte[] lastByte = (byte[])rom.Clone();
                lastByte[0x101A] = 0xFE;
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
            });

            Check("Repeated builds are deterministic and input is unchanged", () =>
            {
                NativePrimitiveBuildResult rebuilt = NativePrimitiveWordBuilder.Build(rom);
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
                Assert(rom.SequenceEqual(originalSnapshot) &&
                       Sha1(rom) == beforeSha1 && Sha256(rom) == beforeSha256,
                    "Builder mutated its caller input ROM");
            });

            Check("Owned buffers and integrity report aliases cannot alter retained build", () =>
            {
                byte[] first = build.CopyOutputImage();
                first[0x1010] ^= 1;
                byte[] second = build.CopyOutputImage();
                Assert(second[0x1010] == 0x10,
                    "Mutating one output copy changed the owned build result");
                Assert(Sha256(second) == ExpectedOutputSha256,
                    "Owned output identity changed after caller mutation");
                Assert(Sha1(build.CopyOutputImage()) == ExpectedOutputSha1,
                    "Owned output SHA1 changed after caller mutation");
                byte[] payload = build.CopyPayloadBytes();
                payload[0] = 0xFF;
                Assert(build.CopyPayloadBytes()[0] == 0x10,
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
                Assert(retained.Fields[0] == firstField &&
                       retained.Fields.Count == 5,
                    "Retained integrity field list changed after caller mutation");
                Assert(retained.UnrepairedChangedOffsets.Length == 13 &&
                       retained.RepairedChangedOffsets.Length == 18,
                    "Retained integrity report counts changed");
                Assert(build.CopyOutputImage().AsSpan(0xFFD1, 5).SequenceEqual(
                        Convert.FromHexString(ExpectedRepairedFieldsHex)),
                    "Retained output fields changed after report mutation");
                Assert(JsonSerializer.Serialize(retained) ==
                       JsonSerializer.Serialize(build.IntegrityReport),
                    "Serialized retained integrity report changed after mutation");
            });

            Check("Read-only map collections and nested contracts reject mutation", () =>
            {
                NativePrimitiveSourceMap map = build.SourceMap;
                string serializedBefore = JsonSerializer.Serialize(map);
                NativePrimitiveMapEntry entryBefore = map.Resolve(0x1010);
                NativePrimitiveHandlerInstruction instructionBefore = map.Instructions[0];
                NativePrimitiveStaticPhase phaseBefore = map.Phases[0];
                NativePrimitiveSemanticContract semanticsBefore = map.Semantics;
                NativePrimitiveDispatchBinding dispatchBefore = map.Dispatch;

                Assert((object)map.Entries is not NativePrimitiveMapEntry[],
                    "Entries exposes a caller-mutable array");
                Assert((object)map.Instructions is not NativePrimitiveHandlerInstruction[],
                    "Instructions exposes a caller-mutable array");
                Assert((object)map.Phases is not NativePrimitiveStaticPhase[],
                    "Phases exposes a caller-mutable array");
                Assert((object)build.ChangedOffsets is not int[],
                    "ChangedOffsets exposes a caller-mutable array");

                RejectReadOnly(() =>
                    ((IList<NativePrimitiveMapEntry>)map.Entries)[0] =
                        entryBefore with { Operation = "tampered" },
                    "Entries index replacement");
                RejectReadOnly(() =>
                    ((IList<NativePrimitiveMapEntry>)map.Entries).Clear(),
                    "Entries clear");
                RejectReadOnly(() =>
                    ((IList<NativePrimitiveHandlerInstruction>)map.Instructions)[0] =
                        instructionBefore with { Operation = "tampered" },
                    "Instructions index replacement");
                RejectReadOnly(() =>
                    ((IList<NativePrimitiveStaticPhase>)map.Phases)[0] =
                        phaseBefore with { Phase = "tampered" },
                    "Phases index replacement");
                RejectReadOnly(() =>
                    ((IList<NativePrimitiveStaticPhase>)map.Phases).RemoveAt(0),
                    "Phases remove");

                NativePrimitiveSemanticContract semanticAlias =
                    semanticsBefore with { HDefinedOutput = true };
                NativePrimitiveDispatchBinding dispatchAlias =
                    dispatchBefore with { AfterDispatchY = 0x1012 };
                Assert(semanticAlias.HDefinedOutput && !map.Semantics.HDefinedOutput,
                    "Nested semantic contract was aliased");
                Assert(dispatchAlias.AfterDispatchY == 0x1012 &&
                       map.Dispatch.AfterDispatchY == 0x9F16,
                    "Nested dispatch binding was aliased");

                Assert(map.Resolve(0x1010) == entryBefore,
                    "Map resolution changed after rejected mutation");
                Assert(map.Instructions[0] == instructionBefore,
                    "Map instruction changed after rejected mutation");
                Assert(map.Phases[0] == phaseBefore,
                    "Map phase changed after rejected mutation");
                Assert(map.Entries.Count == 15 && map.Instructions.Count == 4 &&
                       map.Phases.Count == 12,
                    "Map collection count changed after rejected mutation");
                Assert(JsonSerializer.Serialize(map) == serializedBefore,
                    "Serialized map changed after rejected mutation");
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
        var report = new NativePrimitiveVerificationReport(
            "il-native-primitive-build-45",
            1,
            "passed",
            "Strict static native-primitive build: direct token 1010 -> handler 1012, " +
            "LDD/ADDD/STD/JMP handler at 1012-101A, one same-size 9F14 caller redirect, exact " +
            "18-byte realized diff, ordered FFD1-FFD5 regeneration and a final-ROM-hash-bound " +
            "direct-native source map. No MAME execution or hardware claim.",
            Path.GetFullPath(romPath),
            rom.Length,
            beforeSha1,
            beforeSha256,
            afterSha1,
            afterSha256,
            beforeSha1 == afterSha1 && beforeSha256 == afterSha256,
            ExpectedTokenHex,
            ExpectedHandlerHex,
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
            build.SourceMap.Instructions.Count,
            build.SourceMap.Phases.Count,
            "9F16",
            "75A9",
            checks,
            new[]
            {
                "The direct handler at 1012-101A has not executed; natural instruction " +
                "execution at 1012 remains a hypothesis.",
                "The observed input 0000 prediction (8000, then FFFF after 75A9) is an " +
                "intentional behaviour change, not original 9ED9 preservation or full-game proof.",
                "The original 9ED7/9ED9 header/body and other caller bytes are preserved by " +
                "the exact diff; the purpose of 9F12 remains unresolved.",
                "The extension range 1010-13EF is human-approved for this exact ROM revision only.",
                "Integrity repair is algorithmically verified in the recovered field order; it is " +
                "not natural boot acceptance.",
                "No MAME run, capture, PC/Y/U/S observation or hardware test was performed."
            },
            "Next boundary is a reviewed natural fresh-boot MAME task observing direct native " +
            "entry at 1012, D=8000, top=8000, dispatcher rejoin at 00FC with Y=9F16 and token " +
            "75A9, then FFFF after 75A9. No execution proof exists here.");

        WriteOutputs(outputDirectory, report);
        WritePrivateBuild(outputDirectory, build);
        Console.WriteLine(
            $"PASS {checks.Count} native-primitive groups; output SHA256 " +
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
        string outputDirectory, NativePrimitiveVerificationReport report)
    {
        Directory.CreateDirectory(outputDirectory);
        var log = new StringBuilder();
        log.AppendLine("FruitMachineLab il-native-primitive-build-45 verification");
        log.AppendLine("ROM: " + report.RomPath);
        log.AppendLine("SHA1: " + report.RomSha1Before);
        log.AppendLine("SHA256: " + report.RomSha256Before);
        log.AppendLine("Input unchanged: " + report.InputUnchanged);
        log.AppendLine("Token: " + report.TokenHex);
        log.AppendLine("Handler: " + report.HandlerHex);
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
        log.AppendLine("Map instructions: " + report.MapInstructionCount);
        log.AppendLine("Map phases: " + report.MapPhaseCount);
        log.AppendLine("Caller saved cursor: " + report.CallerSavedCursorHex);
        log.AppendLine("Caller post-return token: " + report.CallerPostReturnTokenHex);
        foreach (NativePrimitiveVerificationCheck check in report.Checks)
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
        string outputDirectory, NativePrimitiveBuildResult build)
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
            Path.Combine(outputDirectory, "native-primitive-source-map.json"),
            mapJson + Environment.NewLine);
        string buildJson = JsonSerializer.Serialize(
            new
            {
                schemaVersion = 1,
                taskId = "il-native-primitive-build-45",
                classification = build.Status,
                originalRomSha1 = build.OriginalRomSha1,
                originalRomSha256 = build.OriginalRomSha256,
                unrepairedImageSha1 = build.UnrepairedImageSha1,
                unrepairedImageSha256 = build.UnrepairedImageSha256,
                outputImageSha1 = build.OutputImageSha1,
                outputImageSha256 = build.OutputImageSha256,
                tokenAddress = "1010",
                tokenHex = ExpectedTokenHex,
                handlerStart = "1012",
                handlerEndInclusive = "101A",
                handlerHex = ExpectedHandlerHex,
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
                instructions = build.SourceMap.Instructions,
                dispatch = build.SourceMap.Dispatch,
                semantics = build.SourceMap.Semantics,
                outerReturn = build.SourceMap.OuterReturn,
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
        string outputDirectory, IReadOnlyList<NativePrimitiveVerificationCheck> checks)
    {
        if (Directory.Exists(outputDirectory)) return;
        Directory.CreateDirectory(outputDirectory);
        var builder = new StringBuilder();
        builder.AppendLine(
            "FruitMachineLab il-native-primitive-build-45 verification FAILED");
        foreach (NativePrimitiveVerificationCheck check in checks)
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

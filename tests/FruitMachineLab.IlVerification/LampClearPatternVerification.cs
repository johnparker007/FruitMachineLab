using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using FruitMachineLab.Il;

namespace FruitMachineLab.IlVerification;

internal sealed record LampClearPatternVerificationCheck(
    string Name, bool Passed, string? Error);

internal sealed record LampClearPatternVerificationReport(
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
    string Old8FPayloadHex,
    int AllocationLength,
    int RemainingApprovedBytes,
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
    int[] RepairChangedOffsets,
    int RepairChangedCount,
    string MapBuildId,
    int MapEntryCount,
    int MapNodeCount,
    int MapInlineOperandCount,
    int MapPhaseCount,
    int MapBoundaryCount,
    string MapClassification,
    ushort PatternOperandValue,
    int ObservedResponseColumn,
    ushort[] ObservedFrameAddresses,
    int ClearAlgebraBeforeValues,
    IReadOnlyList<LampPatternVector> StaticVectors,
    IReadOnlyList<LampPatternStackStep> StackSteps,
    IReadOnlyList<LampClearPatternVerificationCheck> Checks,
    IReadOnlyList<string> Limitations,
    string RemainingBoundary);

internal static class LampClearPatternVerification
{
    private const string ExpectedOriginalSha1 = "402D1518BB78FDC489B06C2AABC771E5CE151847";
    private const string ExpectedOriginalSha256 =
        "EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C";
    private const string Old8FPayloadHex =
        "00F8795BFF80787E795BFF807AAF79630079638F9C44792F";
    private const string Old8FOutputSha256 =
        "631F6C252A5DF359525553F7D14A4FC8CEF965C76BBECA759EAAA862A3FAD4DE";

    private static readonly LampPatternVector[] ExpectedVectors =
    {
        new(0x0000, 0x0000),
        new(0x0001, 0x0001),
        new(0x7FFF, 0x80FF),
        new(0x8000, 0x8000),
        new(0xFFFF, 0x00FF)
    };

    public static void Run(string romPath, string repositoryRoot, string outputDirectory)
    {
        if (Directory.Exists(outputDirectory))
            throw new IOException($"Output directory already exists: {outputDirectory}");

        byte[] rom = File.ReadAllBytes(romPath);
        byte[] originalSnapshot = (byte[])rom.Clone();
        string beforeSha1 = Sha1(rom);
        string beforeSha256 = Sha256(rom);
        var checks = new List<LampClearPatternVerificationCheck>();
        LampPatternBuildResult build = null!;

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
                                          NotSupportedException or InvalidOperationException or
                                          OverflowException)
            {
                Assert(string.IsNullOrEmpty(expected) ||
                       error.Message.Contains(expected, StringComparison.OrdinalIgnoreCase),
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
                checks.Add(new LampClearPatternVerificationCheck(name, true, null));
            }
            catch (Exception error) when (error is InvalidDataException or IOException or
                                          KeyNotFoundException or ArgumentException or
                                          NotSupportedException or InvalidOperationException or
                                          OverflowException)
            {
                checks.Add(new LampClearPatternVerificationCheck(name, false, error.Message));
            }
        }

        void AssertRangeEqual(byte[] first, byte[] second, int start, int end, string label)
        {
            for (int offset = start; offset <= end; offset++)
            {
                Assert(first[offset] == second[offset],
                    $"{label} differs at {offset:X4}: {first[offset]:X2} vs " +
                    $"{second[offset]:X2}");
            }
        }

        build = LampPatternWordBuilder.BuildClearPattern(rom);
        checks.Add(new LampClearPatternVerificationCheck(
            "Positive lamp-clear build completes", true, null));

        Check("Original identity and input are unchanged", () =>
        {
            Assert(rom.Length == 65536, "ROM length is not 65536");
            Assert(string.Equals(beforeSha1, ExpectedOriginalSha1,
                StringComparison.OrdinalIgnoreCase), "original SHA1 differs");
            Assert(string.Equals(beforeSha256, ExpectedOriginalSha256,
                StringComparison.OrdinalIgnoreCase), "original SHA256 differs");
            Assert(rom.SequenceEqual(originalSnapshot), "input ROM changed during build");
        });

        Check("Payload is exactly the literal pattern-80 24 bytes", () =>
        {
            Assert(build.PayloadBytes.Length == LampPatternWordBuilder.AllocationLength,
                "payload length differs");
            Assert(Convert.ToHexString(build.PayloadBytes) ==
                   LampPatternWordBuilder.ClearPayloadHex, "payload hex differs");
            Assert(build.PayloadBytes[0] == 0x00 && build.PayloadBytes[1] == 0xF8,
                "header is not 00F8");
            Assert(build.PayloadBytes[0x1014 - 0x1010] == 0xFF &&
                   build.PayloadBytes[0x101A - 0x1010] == 0xFF,
                "1014/101A are not FF");
            Assert(build.PayloadBytes[0x1020 - 0x1010] == 0x00,
                "inline index is not 00");
            Assert(build.PayloadBytes[0x1023 - 0x1010] == 0x80,
                "inline pattern is not 80");
        });

        Check("Only 1023 differs from the accepted 8F payload", () =>
        {
            byte[] oldPayload = Convert.FromHexString(Old8FPayloadHex);
            byte[] newPayload = build.CopyPayloadBytes();
            Assert(oldPayload.Length == newPayload.Length, "payload lengths differ");
            int differences = 0;
            for (int index = 0; index < oldPayload.Length; index++)
            {
                if (oldPayload[index] == newPayload[index])
                    continue;
                differences++;
                Assert(index == 0x1023 - 0x1010,
                    $"unexpected 8F/80 payload difference at " +
                    $"{(0x1010 + index):X4}");
                Assert(oldPayload[index] == 0x8F && newPayload[index] == 0x80,
                    "the single difference is not 8F -> 80");
            }
            Assert(differences == 1, "8F/80 payload does not differ in exactly one byte");
        });

        Check("Eight nodes and four inline operands carry the clear descriptor", () =>
        {
            Assert(build.Nodes.Count == 8, "node count differs");
            ushort[] addresses =
            {
                0x1012, 0x1016, 0x1018, 0x101C, 0x101E, 0x1021, 0x1024, 0x1026
            };
            ushort[] tokens =
            {
                0x795B, 0x787E, 0x795B, 0x7AAF, 0x7963, 0x7963, 0x9C44, 0x792F
            };
            for (int index = 0; index < addresses.Length; index++)
            {
                Assert(build.Nodes[index].Index == index, $"node {index} index differs");
                Assert(build.Nodes[index].Address == addresses[index],
                    $"node {index} address differs");
                Assert(build.Nodes[index].Token == tokens[index],
                    $"node {index} token differs");
            }
            Assert(build.Nodes[5].OperandAddress == 0x1023 &&
                   build.Nodes[5].OperandValue == 0x0080,
                "pattern node is not the literal 1023 = 0080 operand");
            Assert(build.SourceMap.InlineOperands.Count == 4, "inline operand count differs");
            Assert(build.SourceMap.InlineOperands[0].Address == 0x1014 &&
                   build.SourceMap.InlineOperands[0].Width == 2 &&
                   build.SourceMap.InlineOperands[0].Value == 0xFF80,
                "word operand 1014 differs");
            Assert(build.SourceMap.InlineOperands[1].Address == 0x101A &&
                   build.SourceMap.InlineOperands[1].Width == 2 &&
                   build.SourceMap.InlineOperands[1].Value == 0xFF80,
                "word operand 101A differs");
            Assert(build.SourceMap.InlineOperands[2].Address == 0x1020 &&
                   build.SourceMap.InlineOperands[2].Width == 1 &&
                   build.SourceMap.InlineOperands[2].Value == 0x00,
                "index operand 1020 differs");
            Assert(build.SourceMap.InlineOperands[3].Address == 0x1023 &&
                   build.SourceMap.InlineOperands[3].Width == 1 &&
                   build.SourceMap.InlineOperands[3].Value == 0x80,
                "pattern operand 1023 differs");
        });

        Check("Shared call has zero caller operands and is not token+2", () =>
        {
            LampPatternNode shared = build.Nodes[6];
            Assert(shared.Token == 0x9C44, "shared token differs");
            Assert(shared.HandlerAddress == 0x9B15, "shared handler differs");
            Assert(shared.HandlerAddress != shared.Token + 2,
                "shared handler incorrectly used token+2");
            Assert(shared.OperandKind == LampPatternOperandKind.ServiceOwnedNoCallerOperand,
                "shared call operand kind differs");
            Assert(shared.OperandAddress is null && shared.OperandValue is null,
                "shared call unexpectedly carries a caller operand");
            Assert(shared.SharedBodyAddress == 0x9B18, "shared body address differs");
            Assert(shared.ServicePointerAddress == 0x9C46 &&
                   shared.ServicePointerValue == 0x72BF,
                "service-owned 9C46 pointer differs");
            Assert(shared.Address + 2 == build.Nodes[7].Address,
                "shared call is not exactly two bytes before the return");
            Assert(build.Nodes[7].Address == 0x1026 &&
                   build.Nodes[7].Token == 0x792F,
                "next caller token is not the 1026 return");
        });

        Check("Relative stack model matches the accepted 61/67 contract", () =>
        {
            LampPatternStaticContract contract = build.StaticContract;
            Assert(contract.EntryU == 0x066E && contract.EntryS == 0x0798,
                "entry U/S differs");
            Assert(contract.DeepestS == 0x078A &&
                   contract.DeepestSRelativeToEntry == -14,
                "deepest native S differs");
            Assert(contract.SharedSavedCursor == 0x1026 &&
                   contract.OuterSavedCursor == 0x9F16,
                "saved cursors differ");
            Assert(contract.NestedCall, "service call is not marked nested");
            Assert(contract.BodyUNet == 0 && contract.WholeCallSNet == 0,
                "stack net is not balanced");
            Assert(contract.StackSteps.Count == 43, "stack step count differs");
            LampPatternStackStep Step(string phase) => contract.StackSteps.Single(
                step => step.Phase == phase);
            Assert(Step("handler-5").U == 0x066C, "handler-5 U differs");
            Assert(Step("shared-handler-entry").U == 0x066A &&
                   Step("shared-handler-entry").S == 0x0796,
                "shared 9B15 entry must be PRE-JSR");
            Assert(Step("service-trampoline-pshu").U == 0x0668,
                "796E post-PSHU U differs");
            Assert(Step("native-prologue-deepest").S == 0x078A,
                "native deepest S differs");
            Assert(Step("native-return").U == 0x066E &&
                   Step("native-return").S == 0x0792,
                "native return U/S differs");
            Assert(Step("outer-returned-to-9F16").U == 0x066E &&
                   Step("outer-returned-to-9F16").S == 0x0798,
                "outer return U/S differs");
            Assert(!contract.StackSteps.Any(step => step.S == 0x0778),
                "stack model transplanted the old B951 S=0778 absolute value");
        });

        Check("9ED9 result vectors are preserved", () =>
        {
            Assert(build.StaticContract.Vectors.Count == ExpectedVectors.Length,
                "vector count differs");
            for (int index = 0; index < ExpectedVectors.Length; index++)
            {
                Assert(build.StaticContract.Vectors[index] == ExpectedVectors[index],
                    $"vector {ExpectedVectors[index].Input:X4} differs");
            }
        });

        Check("Clear algebra covers all 256 before-byte values", () =>
        {
            Assert(build.Nodes[5].OperandValue == 0x0080,
                "pattern node is not 0x0080");
            byte mask = LampPatternWordBuilder.PredictedMask;
            Assert(mask == 0x01, "mask is not 01");
            Assert((LampPatternWordBuilder.ClearPatternOperand & 0x0F) == 0x00,
                "pattern low nibble is not the clear branch");
            Assert(rom[0x72BF] == 0x78, "72BF index 0 logical ID is not 78");
            byte[] maskTable = { 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80 };
            for (int index = 0; index < maskTable.Length; index++)
                Assert(rom[0x49BD + index] == maskTable[index],
                    "mask table differs at " + (0x49BD + index).ToString("X4"));
            for (int before = 0; before <= 0xFF; before++)
            {
                int expected = ((before | mask) - mask) & 0xFF;
                Assert(expected == (before & ~mask),
                    "native OR/subtract sequence differs from clear-bit contract");
                Assert((expected & ~mask) == (before & ~mask),
                    "clear algebra changed a bit outside mask 01");
                if ((before & mask) != 0)
                    Assert(expected == (before ^ mask),
                        "clear algebra did not clear an on mask bit");
                else
                    Assert(expected == before,
                        "clear algebra changed an already-clear mask bit");
            }
            int derivedColumn =
                ((LampPatternWordBuilder.ObservedCharacteriserResponse ^ 0x78) & 0x78) >> 3;
            Assert(derivedColumn == LampPatternWordBuilder.ObservedResponseColumn,
                "observed response/column formula differs");
            for (int bank = 0; bank < 4; bank++)
            {
                int address = 0x0100 + bank * 0x10 + derivedColumn;
                Assert(address == LampPatternWordBuilder.ClearObservedFrameAddresses[bank],
                    $"observed frame bank {bank} address differs");
            }
        });

        Check("Integrity repair is derived from the literal patch and FFD1-FFD5", () =>
        {
            var expectedUnrepaired = new List<int>();
            byte[] payload = Convert.FromHexString(LampPatternWordBuilder.ClearPayloadHex);
            for (int index = 0; index < payload.Length; index++)
            {
                int offset = LampPatternWordBuilder.AllocationStart + index;
                if (rom[offset] != payload[index])
                    expectedUnrepaired.Add(offset);
            }
            Assert(rom[0x9F14] != 0x10 || rom[0x9F15] != 0x10,
                "original caller unexpectedly already 1010");
            expectedUnrepaired.Add(0x9F14);
            expectedUnrepaired.Add(0x9F15);
            Assert(build.UnrepairedChangedOffsets.SequenceEqual(expectedUnrepaired),
                "unrepaired diff is not the literal payload plus caller bytes");
            Assert(build.CopyUnrepairedImage()[0x1014] == 0xFF &&
                   build.CopyUnrepairedImage()[0x101A] == 0xFF &&
                   build.CopyOutputImage()[0x1014] == 0xFF &&
                   build.CopyOutputImage()[0x101A] == 0xFF,
                "1014/101A are not preserved FF");
            Assert(build.RepairChangedOffsets.All(offset =>
                    offset >= VmIlIntegrity.SumOffset &&
                    offset <= VmIlIntegrity.RotateSubXorBOffset),
                "repair changed a byte outside FFD1-FFD5");
            int[] expectedFinal = expectedUnrepaired
                .Concat(build.RepairChangedOffsets)
                .OrderBy(offset => offset)
                .ToArray();
            Assert(build.ChangedOffsets.SequenceEqual(expectedFinal),
                "final diff is not the derived patch plus repair set");
            Assert(build.IntegrityReport.Fields.Count == 5,
                "integrity field count differs");
            Assert(build.IntegrityReport.Fields.Select(field => field.Offset)
                    .SequenceEqual(new ushort[]
                    {
                        VmIlIntegrity.SumOffset, VmIlIntegrity.XorOffset,
                        VmIlIntegrity.RotateAddOffset, VmIlIntegrity.RotateSubXorAOffset,
                        VmIlIntegrity.RotateSubXorBOffset
                    }),
                "integrity field locations differ");
            VmIlIntegrityComputedFields recomputed =
                VmIlIntegrity.ComputeForTests(build.CopyUnrepairedImage(), true);
            string expectedFields =
                $"{recomputed.Sum:X2}{recomputed.Xor:X2}{recomputed.RotateAdd:X2}" +
                $"{recomputed.RotateSubXorA:X2}{recomputed.RotateSubXorB:X2}";
            Assert(string.Equals(
                    build.IntegrityReport.RepairedStoredFieldsHex, expectedFields,
                    StringComparison.Ordinal),
                "repaired fields do not equal the ordered recomputation");
            Assert(string.Equals(
                    build.IntegrityReport.RepairedStoredFieldsHex,
                    build.IntegrityReport.RepairedComputedFieldsHex,
                    StringComparison.Ordinal),
                "stored and computed repaired fields differ");
        });

        Check("Preserved spans and guards are unchanged", () =>
        {
            byte[] output = build.CopyOutputImage();
            AssertRangeEqual(rom, output, 0x1000, 0x100F, "left guard");
            AssertRangeEqual(rom, output, 0x1000, 0x1003, "protected cells");
            AssertRangeEqual(rom, output, 0x13F0, 0x13FF, "right guard");
            AssertRangeEqual(rom, output, 0x1400, 0x140F, "integrity neighbour");
            AssertRangeEqual(rom, output, 0x9ED7, 0x9EE6, "original 9ED7/9ED9");
            AssertRangeEqual(rom, output, 0x1028, 0x13EF, "unallocated extension");
            AssertRangeEqual(rom, output, 0x9C44, 0x9C47, "shared service cell");
            AssertRangeEqual(rom, output, 0x9B15, 0x9B25, "shared service body");
            AssertRangeEqual(rom, output, 0x796E, 0x7978, "trampoline");
            AssertRangeEqual(rom, output, 0x7963, 0x796B, "byte literal cell");
            AssertRangeEqual(rom, output, 0x8050, 0x8053, "bridge cell");
            AssertRangeEqual(rom, output, 0x7791, 0x77A3, "bridge entry");
            AssertRangeEqual(rom, output, 0x777A, 0x778C, "bridge continuation");
            AssertRangeEqual(rom, output, 0x49C5, 0x4A24, "native service");
            AssertRangeEqual(rom, output, 0x72BF, 0x72EE, "lamp table");
            AssertRangeEqual(rom, output, 0x9F10, 0x9F13, "caller header/body");
            AssertRangeEqual(rom, output, 0x9F16, 0x9F1D, "caller successor suffix");
            AssertRangeEqual(rom, output, 0x9F3B, 0x9F40, "parent context");
            Assert(output[0x1010] == 0x00 && output[0x1011] == 0xF8,
                "header is not 00F8");
            Assert(output[0x9F14] == 0x10 && output[0x9F15] == 0x10,
                "caller token is not 1010");
        });

        Check("Source map is bound to the clear output and descriptor", () =>
        {
            LampPatternSourceMap map = build.SourceMap;
            Assert(map.BuildId == build.OutputImageSha256, "map build id differs");
            Assert(map.Classification == LampPatternWordBuilder.ClearBuildClassification,
                "map classification is not the clear classification");
            Assert(map.Entries.Count == 44, "map entry count differs");
            Assert(map.Nodes.Count == 8, "map node count differs");
            Assert(map.InlineOperands.Count == 4, "map inline operand count differs");
            Assert(map.Phases.Count == 43, "map phase count differs");
            Assert(map.Boundaries.Count == 12, "map boundary count differs");
            Assert(map.Resolve(0x1010).Kind == LampPatternMapKind.Header,
                "header map kind differs");
            Assert(map.Resolve(0x1012).Kind == LampPatternMapKind.Body &&
                   map.Resolve(0x1012).Token == 0x795B,
                "first body map entry differs");
            Assert(map.Resolve(0x1014).OperandKind == LampPatternOperandKind.Word &&
                   map.Resolve(0x1014).OperandValue == 0xFF80,
                "word operand map entry differs");
            Assert(map.Resolve(0x1020).OperandKind == LampPatternOperandKind.Byte &&
                   map.Resolve(0x1020).OperandValue == 0x00,
                "index byte map entry differs");
            Assert(map.Resolve(0x1023).OperandKind == LampPatternOperandKind.Byte &&
                   map.Resolve(0x1023).OperandValue == 0x0080,
                "pattern byte map entry is not 0080");
            Assert(map.Resolve(0x1024).OperandKind ==
                   LampPatternOperandKind.ServiceOwnedNoCallerOperand &&
                   map.Resolve(0x1024).HandlerAddress == 0x9B15,
                "shared-call map entry differs");
            Assert(map.Resolve(0x1026).IsFinalReturn, "final return map entry differs");
            Assert(map.Resolve(0x9F14).Kind == LampPatternMapKind.CallerToken &&
                   map.Resolve(0x9F14).ReplacementToken == 0x1010,
                "caller-token map entry differs");
            Assert(map.Resolve(0x9F16).Kind == LampPatternMapKind.CallerSuccessor &&
                   map.Resolve(0x9F16).Token == 0x75A9,
                "caller-successor map entry differs");
            Assert(map.ResolveBoundary("shared-cell").BytesHex == "9B1572BF",
                "shared-cell boundary differs");
            Assert(map.ResolveBoundary("service-pointer").BytesHex == "72BF",
                "service-pointer boundary differs");
            Assert(map.ResolveBoundary("shared-body").BytesHex ==
                   LampPatternWordBuilder.SharedBodyHex, "shared-body boundary differs");
            Assert(map.Semantics.Classification ==
                   LampPatternSourceMap.PhaseClassification, "semantics class differs");
            Assert(map.Phases.All(phase => phase.Classification ==
                LampPatternSourceMap.PhaseClassification),
                "a phase is not classified as static prediction");
            LampPatternStaticPhase Phase(string name) => map.Phases.Single(
                phase => phase.Phase == name);
            Assert(Phase("handler-0").X == 0x795D &&
                   Phase("handler-5").X == 0x7965,
                "handler dispatch X differs");
            Assert(Phase("shared-handler-entry").X == 0x9C46 &&
                   Phase("shared-handler-entry").U == 0x066A,
                "shared 9B15 PRE-JSR boundary differs");
            Assert(Phase("shared-after-rotate").X == 0x0080 &&
                   Phase("shared-after-swap").X == 0x0080,
                "ROT/SWAP exit X is not the clear pattern 0080");
            Assert(Phase("shared-after-rotate").X != 0x008F &&
                   Phase("shared-after-swap").X != 0x008F,
                "map reused the stale 8F pattern as the ROT/SWAP exit X");
            Assert(Phase("shared-body-entry").Pc == 0x00FC &&
                   Phase("shared-body-entry").X == 0x9B18 &&
                   Phase("shared-body-entry").Y == 0x9B18,
                "shared-body-entry must be the 00FC prefetch with X=Y=9B18");
            Assert(Phase("shared-return-handler").Pc == 0x7931 &&
                   Phase("shared-return-handler").X == 0x7931 &&
                   Phase("outer-return-handler").X == 0x7931,
                "return handler X must be 7931, not the Y cursor");
            Assert(Phase("shared-return-handler").SavedCursor == 0x1026 &&
                   Phase("outer-return-handler").SavedCursor == 0x9F16,
                "return-phase saved cursors differ");
            map.ValidateImage(build.CopyOutputImage());
        });

        Check("Independent ROM-derived phase oracle matches the clear map", () =>
        {
            Dictionary<string, LampPatternOraclePhase> oracle =
                LampPatternPhaseOracle.Build(rom, build.CopyOutputImage(), build.Nodes);
            Assert(oracle.Count == build.SourceMap.Phases.Count,
                "oracle phase count differs from the map");
            foreach (LampPatternStaticPhase phase in build.SourceMap.Phases)
            {
                Assert(oracle.TryGetValue(phase.Phase, out LampPatternOraclePhase? expected),
                    $"oracle has no phase '{phase.Phase}'");
                Assert(expected!.Pc == phase.Pc &&
                       expected.X == phase.X &&
                       expected.Y == phase.Y &&
                       expected.Token == phase.Token &&
                       expected.U == phase.U &&
                       expected.S == phase.S &&
                       expected.SavedCursor == phase.SavedCursor,
                    $"phase '{phase.Phase}' differs from the independent ROM-derived oracle: " +
                    $"oracle PC={expected.Pc:X4} X={expected.X} Y={expected.Y:X4} " +
                    $"U={expected.U:X4} S={expected.S:X4} saved={expected.SavedCursor}, " +
                    $"map PC={phase.Pc:X4} X={phase.X} Y={phase.Y:X4} U={phase.U:X4} " +
                    $"S={phase.S:X4} saved={phase.SavedCursor}");
            }
        });

        Check("Deterministic repeat is byte-identical", () =>
        {
            LampPatternBuildResult repeat = LampPatternWordBuilder.BuildClearPattern(rom);
            Assert(repeat.CopyOutputImage().SequenceEqual(build.CopyOutputImage()),
                "repeated output image differs");
            Assert(repeat.CopyUnrepairedImage().SequenceEqual(build.CopyUnrepairedImage()),
                "repeated unrepaired image differs");
            Assert(repeat.CopyPayloadBytes().SequenceEqual(build.CopyPayloadBytes()),
                "repeated payload differs");
            var options = new JsonSerializerOptions { WriteIndented = true };
            Assert(JsonSerializer.SerializeToUtf8Bytes(repeat.SourceMap, options)
                    .SequenceEqual(JsonSerializer.SerializeToUtf8Bytes(
                        build.SourceMap, options)),
                "repeated source map JSON differs");
        });

        Check("Build result, map and frame views are immutable", () =>
        {
            byte[] outputCopy = build.CopyOutputImage();
            outputCopy[0x1010] = 0xAA;
            Assert(build.OutputImage[0x1010] == 0x00,
                "CopyOutputImage exposed internal output bytes");
            byte[] payloadCopy = build.CopyPayloadBytes();
            payloadCopy[0] = 0xAA;
            Assert(build.PayloadBytes[0] == 0x00,
                "CopyPayloadBytes exposed internal payload bytes");
            Assert(build.IntegrityReport.Fields[0].RepairedValue ==
                   build.IntegrityReport.Fields[0].RepairedValue,
                "integrity report field access differs");
            RejectReadOnly(
                () => ((IList<LampPatternMapEntry>)build.SourceMap.Entries)[0] =
                    build.SourceMap.Entries[0], "Entries");
            RejectReadOnly(
                () => ((IList<LampPatternNode>)build.Nodes)[0] = build.Nodes[0],
                "Nodes");
            RejectReadOnly(
                () => ((IList<LampPatternStaticPhase>)build.SourceMap.Phases)[0] =
                    build.SourceMap.Phases[0], "Phases");
            RejectReadOnly(
                () => ((IList<ushort>)LampPatternWordBuilder.ClearObservedFrameAddresses)[0] =
                    0xFFFF, "ClearObservedFrameAddresses");
            Assert(LampPatternWordBuilder.ClearObservedFrameAddresses[0] == 0x010F,
                "ClearObservedFrameAddresses exposed a mutable global");
            ushort[] frameSnapshot =
                LampPatternWordBuilder.ClearObservedFrameAddresses.ToArray();
            frameSnapshot[0] = 0xFFFF;
            Assert(LampPatternWordBuilder.ClearObservedFrameAddresses[0] == 0x010F,
                "a copied frame-address array changed the global view");
            build.SourceMap.ValidateImage(build.CopyOutputImage());
        });

        Check("Wrong original identity is rejected", () =>
        {
            Reject(() => LampPatternWordBuilder.BuildClearPattern(rom.AsSpan(0, 65535)),
                "length");
            var tampered = (byte[])rom.Clone();
            tampered[0x1400] ^= 1;
            Reject(() => LampPatternWordBuilder.BuildClearPattern(tampered), "SHA1");
        });

        Check("Wrong header/index/pattern and old 8F payload are rejected", () =>
        {
            byte[] payload = Convert.FromHexString(LampPatternWordBuilder.ClearPayloadHex);
            var wrongHeader = (byte[])payload.Clone();
            wrongHeader[0] = 0x01;
            Reject(() => LampPatternWordBuilder.ValidateComposedPayload(
                wrongHeader, LampPatternWordBuilder.VariantClear), "header");
            Reject(() => LampPatternWordBuilder.ValidateComposedPayload(
                payload.AsSpan(0, payload.Length - 1).ToArray(),
                LampPatternWordBuilder.VariantClear), "length");

            var wrongIndex = (byte[])payload.Clone();
            wrongIndex[0x1020 - 0x1010] = 0x01;
            Reject(() => LampPatternWordBuilder.ValidateComposedPayload(
                wrongIndex, LampPatternWordBuilder.VariantClear), "body");
            byte[] wrongIndexBody = wrongIndex.AsSpan(2).ToArray();
            LampPatternNode[] wrongIndexNodes = LampPatternWordBuilder.AnalyzeBody(
                wrongIndexBody, LampPatternWordBuilder.BodyStart,
                LampPatternWordBuilder.BodyStart + wrongIndexBody.Length);
            Reject(() => LampPatternWordBuilder.ValidateNodes(
                rom, wrongIndex, wrongIndexNodes,
                LampPatternWordBuilder.ClearPatternOperand), "operand");

            foreach (byte pattern in new byte[] { 0x00, 0x8E, 0xC0, 0xFF })
            {
                var wrongPattern = (byte[])payload.Clone();
                wrongPattern[0x1023 - 0x1010] = pattern;
                Reject(() => LampPatternWordBuilder.ValidateComposedPayload(
                    wrongPattern, LampPatternWordBuilder.VariantClear), "body");
                byte[] body = wrongPattern.AsSpan(2).ToArray();
                LampPatternNode[] nodes = LampPatternWordBuilder.AnalyzeBody(
                    body, LampPatternWordBuilder.BodyStart,
                    LampPatternWordBuilder.BodyStart + body.Length);
                Reject(() => LampPatternWordBuilder.ValidateNodes(
                    rom, wrongPattern, nodes, LampPatternWordBuilder.ClearPatternOperand),
                    "operand");
            }

            byte[] oldPayload = Convert.FromHexString(Old8FPayloadHex);
            Reject(() => LampPatternWordBuilder.ValidateComposedPayload(
                oldPayload, LampPatternWordBuilder.VariantClear), "body");
            byte[] oldBody = oldPayload.AsSpan(2).ToArray();
            LampPatternNode[] oldNodes = LampPatternWordBuilder.AnalyzeBody(
                oldBody, LampPatternWordBuilder.BodyStart,
                LampPatternWordBuilder.BodyStart + oldBody.Length);
            Reject(() => LampPatternWordBuilder.ValidateNodes(
                rom, oldPayload, oldNodes, LampPatternWordBuilder.ClearPatternOperand),
                "operand");
        });

        Check("Malformed/truncated/early-return bodies are rejected", () =>
        {
            byte[] earlyBody = Convert.FromHexString("795BFF80787E792F795BFF80");
            Reject(() => LampPatternWordBuilder.AnalyzeBody(
                earlyBody, 0x1012, 0x1012 + earlyBody.Length), "reachability");
            byte[] truncatedBody = Convert.FromHexString(
                LampPatternWordBuilder.ClearBodyHex).Take(21).ToArray();
            Reject(() => LampPatternWordBuilder.AnalyzeBody(
                truncatedBody, 0x1012, 0x1012 + truncatedBody.Length), "body");
            var extra = Convert.FromHexString(LampPatternWordBuilder.ClearBodyHex).ToList();
            extra.Insert(extra.Count - 2, 0x00);
            extra.Insert(extra.Count - 2, 0x00);
            byte[] extraBody = extra.ToArray();
            Reject(() => LampPatternWordBuilder.AnalyzeBody(
                extraBody, 0x1012, 0x1012 + extraBody.Length), "token");
        });

        Check("Wrong expected bytes/caller/range are rejected", () =>
        {
            byte[] payload = Convert.FromHexString(LampPatternWordBuilder.ClearPayloadHex);
            byte[] unrepaired = build.CopyUnrepairedImage();
            VmIlLampPatternPatchSpec Spec(
                int start = 0x1010,
                byte[]? expectedAllocation = null,
                byte[]? replacementAllocation = null,
                int callerOffset = 0x9F14,
                byte[]? expectedCaller = null,
                byte[]? replacementCaller = null) =>
                new(
                    start,
                    expectedAllocation ?? Enumerable.Repeat((byte)0xFF, 24).ToArray(),
                    replacementAllocation ?? payload,
                    callerOffset,
                    expectedCaller ?? new byte[] { 0x9E, 0xD7 },
                    replacementCaller ?? new byte[] { 0x10, 0x10 });

            Reject(() => VmIlIntegrity.RepairLampClearPattern(
                rom, unrepaired,
                Spec(start: 0x1011)), "1010-1027");
            Reject(() => VmIlIntegrity.RepairLampClearPattern(
                rom, unrepaired,
                Spec(expectedAllocation: new byte[24])), "FF");
            var wrongPayload = (byte[])payload.Clone();
            wrongPayload[0x1023 - 0x1010] = 0x8F;
            Reject(() => VmIlIntegrity.RepairLampClearPattern(
                rom, unrepaired,
                Spec(replacementAllocation: wrongPayload)), "pattern-80");
            Reject(() => VmIlIntegrity.RepairLampClearPattern(
                rom, unrepaired,
                Spec(callerOffset: 0x9F15)), "9F14");
            Reject(() => VmIlIntegrity.RepairLampClearPattern(
                rom, unrepaired,
                Spec(expectedCaller: new byte[] { 0x9E, 0xD6 })), "9ED7");
            Reject(() => VmIlIntegrity.RepairLampClearPattern(
                rom, unrepaired,
                Spec(replacementCaller: new byte[] { 0x10, 0x11 })), "9ED7 -> 1010");

            byte[] alteredHole = (byte[])unrepaired.Clone();
            alteredHole[0x1014] = 0x00;
            Reject(() => VmIlIntegrity.RepairLampClearPattern(
                rom, alteredHole, Spec()), "payload");
            byte[] alteredHole2 = (byte[])unrepaired.Clone();
            alteredHole2[0x101A] = 0x00;
            Reject(() => VmIlIntegrity.RepairLampClearPattern(
                rom, alteredHole2, Spec()), "payload");
        });

        Check("Allocation overflow and unapproved range are rejected", () =>
        {
            ExtensionRangeAllocator allocator =
                ExtensionRangeAllocator.Create(rom, ExtensionRangeDescriptor.Approved);
            Reject(() => allocator.Plan(new[]
            {
                new ExtensionAllocationRequest("overflow", 993)
            }), "exceeds");
            Reject(() => allocator.Plan(new[]
            {
                new ExtensionAllocationRequest("first", 600),
                new ExtensionAllocationRequest("second", 400)
            }), "exceeds");
            ExtensionRangeDescriptor descriptor =
                ExtensionRangeDescriptor.Approved with { CpuEnd = 0x13FF };
            Reject(() => ExtensionRangeAllocator.Create(rom, descriptor), "CPU range");
        });

        Check("Stale 8F map/build identity is rejected", () =>
        {
            Reject(() => build.SourceMap.ValidateBuild(Old8FOutputSha256), "identity");
            LampPatternBuildResult oldBuild = LampPatternWordBuilder.Build(rom);
            Reject(() => build.SourceMap.ValidateImage(oldBuild.CopyOutputImage()),
                "identity");
            Reject(() => build.SourceMap.ValidateBuild(new string('0', 64)), "identity");
            byte[] tampered = build.CopyOutputImage();
            tampered[0x1010] ^= 1;
            Reject(() => build.SourceMap.ValidateImage(tampered), "identity");
        });

        Assert(rom.SequenceEqual(originalSnapshot), "input ROM changed after checks");
        string afterSha1 = Sha1(rom);
        string afterSha256 = Sha256(rom);

        var report = new LampClearPatternVerificationReport(
            "il-lamp-clear-build-71",
            1,
            checks.All(check => check.Passed) ? "pass" : "fail",
            LampPatternWordBuilder.ClearStatusText,
            Path.GetFullPath(romPath),
            rom.Length,
            beforeSha1,
            beforeSha256,
            afterSha1,
            afterSha256,
            beforeSha1 == afterSha1 && beforeSha256 == afterSha256,
            LampPatternWordBuilder.ClearPayloadHex,
            Old8FPayloadHex,
            LampPatternWordBuilder.AllocationLength,
            LampPatternWordBuilder.RemainingApprovedBytes,
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
            build.RepairChangedOffsets.ToArray(),
            build.RepairChangedOffsets.Count,
            build.SourceMap.BuildId,
            build.SourceMap.Entries.Count,
            build.SourceMap.Nodes.Count,
            build.SourceMap.InlineOperands.Count,
            build.SourceMap.Phases.Count,
            build.SourceMap.Boundaries.Count,
            build.SourceMap.Classification,
            build.Nodes[5].OperandValue ?? 0,
            LampPatternWordBuilder.ObservedResponseColumn,
            LampPatternWordBuilder.ClearObservedFrameAddresses.ToArray(),
            256,
            build.StaticContract.Vectors,
            build.StaticContract.StackSteps,
            checks,
            new[]
            {
                "Static clear-variant build and verification only. No MAME launch, capture, " +
                "synthetic execution, save state, debugger write or hardware test was " +
                "performed.",
                "Pattern 80 clears mask 01 in each of the four banks for every possible " +
                "pre-existing frame byte (after = before & ~01). The recorded observed " +
                "response 00 and column 15 are a static prediction; a future run must use " +
                "the response actually read at 0803.",
                "Frame RAM is not physical lamp output. No visible 1->0 transition, full " +
                "characteriser response, whole-RAM-unchanged state or natural safety claim " +
                "is made.",
                "The reused 9C44/49C5 service still reads DP-relative 00F1, conditionally " +
                "writes 00F1/080C, masks IRQ/FIRQ around 0801/0802/0803, moves U/S frames " +
                "and changes A/CC net. Broad caller safety remains unproved.",
                "M5 remains open; this is one clear variant plus one caller redirect. No " +
                "general linker/compiler, button, timing or scheduling claim is made."
            },
            "Fresh natural 9F14 capture of the exact clear image remains a separate reviewed " +
            "gate.");

        WriteReport(outputDirectory, report, build);
    }

    private static void WriteReport(
        string outputDirectory,
        LampClearPatternVerificationReport report,
        LampPatternBuildResult build)
    {
        Directory.CreateDirectory(outputDirectory);
        var options = new JsonSerializerOptions { WriteIndented = true };
        byte[] reportBytes = JsonSerializer.SerializeToUtf8Bytes(report, options);
        File.WriteAllBytes(
            Path.Combine(outputDirectory, "verification-report.json"), reportBytes);

        var log = new StringBuilder();
        log.AppendLine("FruitMachineLab il-lamp-clear-build-71 verification");
        log.AppendLine("status: " + report.Status);
        log.AppendLine("original_sha1: " + report.RomSha1Before);
        log.AppendLine("original_sha256: " + report.RomSha256Before);
        log.AppendLine("unrepaired_sha1: " + report.UnrepairedSha1);
        log.AppendLine("unrepaired_sha256: " + report.UnrepairedSha256);
        log.AppendLine("output_sha1: " + report.OutputSha1);
        log.AppendLine("output_sha256: " + report.OutputSha256);
        log.AppendLine("fields: " + report.IntegrityRepairedFieldsHex);
        log.AppendLine("repair_changed_count: " + report.RepairChangedCount);
        log.AppendLine("final_changed_count: " + report.ChangedCount);
        log.AppendLine("allocation_length: " + report.AllocationLength);
        log.AppendLine("remaining_approved_bytes: " + report.RemainingApprovedBytes);
        log.AppendLine("map_entries: " + report.MapEntryCount);
        log.AppendLine("map_phases: " + report.MapPhaseCount);
        log.AppendLine("map_boundaries: " + report.MapBoundaryCount);
        log.AppendLine("map_classification: " + report.MapClassification);
        log.AppendLine("pattern_1023: " + report.PatternOperandValue.ToString("X4"));
        log.AppendLine("clear_algebra_before_values: " + report.ClearAlgebraBeforeValues);
        foreach (LampClearPatternVerificationCheck check in report.Checks)
        {
            string tag = check.Passed ? "PASS" : "FAIL";
            log.AppendLine($"{tag} {check.Name}" +
                (check.Error is null ? string.Empty : ": " + check.Error));
        }
        File.WriteAllText(
            Path.Combine(outputDirectory, "verification.log"),
            log.ToString(), new UTF8Encoding(false));

        if (!report.Checks.All(check => check.Passed))
            throw new InvalidDataException(
                string.Join("; ", report.Checks
                    .Where(check => !check.Passed)
                    .Select(check => check.Name + ": " + check.Error)));
    }

    private static string Sha1(byte[] bytes) =>
        Convert.ToHexString(SHA1.HashData(bytes));

    private static string Sha256(byte[] bytes) =>
        Convert.ToHexString(SHA256.HashData(bytes));
}

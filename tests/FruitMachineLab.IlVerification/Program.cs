using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using FruitMachineLab.Il;

namespace FruitMachineLab.IlVerification;

internal static class Program
{
    public static int Main(string[] args)
    {
        if (args.Length is < 1 or > 2)
        {
            Console.Error.WriteLine(
                "Usage: FruitMachineLab.IlVerification <original-a6ls.p1> [new-output-directory]");
            return 2;
        }

        try
        {
            string romPath = Path.GetFullPath(args[0]);
            string repositoryRoot = FindRepositoryRoot(Directory.GetCurrentDirectory())
                ?? FindRepositoryRoot(AppContext.BaseDirectory)
                ?? throw new InvalidOperationException("Repository root was not found");
            string outputDirectory = args.Length == 2
                ? Path.GetFullPath(args[1])
                : Path.Combine(
                    repositoryRoot, "artifacts", "deepseek", "il-integrity-03", "runs",
                    DateTime.UtcNow.ToString("yyyyMMdd-HHmmssfff"));

            NineEdNineVerification.Run(romPath, repositoryRoot, outputDirectory);
            Console.WriteLine("Report: " + Path.Combine(outputDirectory, "verification-report.json"));
            Console.WriteLine("Log: " + Path.Combine(outputDirectory, "verification.log"));

            string nineASixFourOutput = Path.Combine(outputDirectory, "9a64");
            NineASixFourVerification.Run(romPath, repositoryRoot, nineASixFourOutput);
            Console.WriteLine("9A64 report: " +
                Path.Combine(nineASixFourOutput, "verification-report.json"));
            Console.WriteLine("9A64 log: " +
                Path.Combine(nineASixFourOutput, "verification.log"));

            string allocatorOutput = Path.Combine(outputDirectory, "allocator");
            ExtensionRangeAllocatorVerification.Run(romPath, repositoryRoot, allocatorOutput);
            Console.WriteLine("Allocator report: " +
                Path.Combine(allocatorOutput, "verification-report.json"));
            Console.WriteLine("Allocator log: " +
                Path.Combine(allocatorOutput, "verification.log"));

            string emitterOutput = Path.Combine(outputDirectory, "emitter");
            ExtensionRangeEmitterVerification.Run(romPath, repositoryRoot, emitterOutput);
            Console.WriteLine("Emitter report: " +
                Path.Combine(emitterOutput, "verification-report.json"));
            Console.WriteLine("Emitter log: " +
                Path.Combine(emitterOutput, "verification.log"));

            string compositeOutput = Path.Combine(outputDirectory, "composite");
            CompositeWordVerification.Run(romPath, repositoryRoot, compositeOutput);
            Console.WriteLine("Composite report: " +
                Path.Combine(compositeOutput, "verification-report.json"));
            Console.WriteLine("Composite log: " +
                Path.Combine(compositeOutput, "verification.log"));

            string nativePrimitiveOutput = Path.Combine(outputDirectory, "native-primitive");
            NativePrimitiveWordVerification.Run(
                romPath, repositoryRoot, nativePrimitiveOutput);
            Console.WriteLine("Native-primitive report: " +
                Path.Combine(nativePrimitiveOutput, "verification-report.json"));
            Console.WriteLine("Native-primitive log: " +
                Path.Combine(nativePrimitiveOutput, "verification.log"));

            string largerReplacementOutput = Path.Combine(
                outputDirectory, "larger-replacement");
            LargerReplacementVerification.Run(
                romPath, repositoryRoot, largerReplacementOutput);
            Console.WriteLine("Larger-replacement report: " +
                Path.Combine(largerReplacementOutput, "verification-report.json"));
            Console.WriteLine("Larger-replacement log: " +
                Path.Combine(largerReplacementOutput, "verification.log"));

            string lampPatternOutput = Path.Combine(
                outputDirectory, "lamp-pattern");
            LampPatternVerification.Run(
                romPath, repositoryRoot, lampPatternOutput);
            Console.WriteLine("Lamp-pattern report: " +
                Path.Combine(lampPatternOutput, "verification-report.json"));
            Console.WriteLine("Lamp-pattern log: " +
                Path.Combine(lampPatternOutput, "verification.log"));
            return 0;
        }
        catch (Exception error)
        {
            Console.Error.WriteLine("FAIL il verification: " + error.Message);
            return 1;
        }
    }

    private static string? FindRepositoryRoot(string start)
    {
        DirectoryInfo? current = new(Path.GetFullPath(start));
        while (current is not null)
        {
            if (File.Exists(Path.Combine(
                    current.FullName, "FruitMachineLab.Headless.sln")))
                return current.FullName;
            current = current.Parent;
        }
        return null;
    }
}

internal sealed record LampPatternVerificationCheck(
    string Name, bool Passed, string? Error);

internal sealed record LampPatternVerificationReport(
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
    string IntegrityAlgorithmOrder,
    int[] RepairChangedOffsets,
    string MapBuildId,
    int MapEntryCount,
    int MapNodeCount,
    int MapInlineOperandCount,
    int MapPhaseCount,
    int MapBoundaryCount,
    int MapEntryU,
    int MapEntryS,
    int MapDeepestS,
    IReadOnlyList<LampPatternVector> StaticVectors,
    IReadOnlyList<LampPatternStackStep> StackSteps,
    IReadOnlyList<LampPatternVerificationCheck> Checks,
    IReadOnlyList<string> Limitations,
    string RemainingBoundary);

internal static class LampPatternVerification
{
    private const string ExpectedOriginalSha1 = "402D1518BB78FDC489B06C2AABC771E5CE151847";
    private const string ExpectedOriginalSha256 =
        "EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C";
    private const string ExpectedUnrepairedSha1 = "FED6058A6BF8D2627068BAC01D77EE0D279B5E46";
    private const string ExpectedUnrepairedSha256 =
        "3D94F6E2908D9C57C2C20EEDE897A0A19D4C74BA88464053554C0558C25ADDE3";
    private const string ExpectedOutputSha1 = "9F060102692BB31E03F992E95E38F4F59BEE1129";
    private const string ExpectedOutputSha256 =
        "631F6C252A5DF359525553F7D14A4FC8CEF965C76BBECA759EAAA862A3FAD4DE";
    private const string ExpectedFields = "E93F3C61B5";
    private const string ExpectedOriginalFields = "3E761E2605";

    private static readonly int[] ExpectedUnrepairedOffsets =
    {
        0x1010, 0x1011, 0x1012, 0x1013, 0x1015, 0x1016, 0x1017, 0x1018,
        0x1019, 0x101B, 0x101C, 0x101D, 0x101E, 0x101F, 0x1020, 0x1021,
        0x1022, 0x1023, 0x1024, 0x1025, 0x1026, 0x1027, 0x9F14, 0x9F15
    };

    private static readonly int[] ExpectedFinalOffsets =
        ExpectedUnrepairedOffsets.Concat(Enumerable.Range(0xFFD1, 5)).ToArray();

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
        var checks = new List<LampPatternVerificationCheck>();
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
                checks.Add(new LampPatternVerificationCheck(name, true, null));
            }
            catch (Exception error) when (error is InvalidDataException or IOException or
                                          KeyNotFoundException or ArgumentException or
                                          NotSupportedException or InvalidOperationException or
                                          OverflowException)
            {
                checks.Add(new LampPatternVerificationCheck(name, false, error.Message));
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

        build = LampPatternWordBuilder.Build(rom);
        checks.Add(new LampPatternVerificationCheck(
            "Positive lamp-pattern build completes", true, null));

        Check("Original identity and input are unchanged", () =>
        {
            Assert(rom.Length == 65536, "ROM length is not 65536");
            Assert(string.Equals(beforeSha1, ExpectedOriginalSha1,
                StringComparison.OrdinalIgnoreCase), "original SHA1 differs");
            Assert(string.Equals(beforeSha256, ExpectedOriginalSha256,
                StringComparison.OrdinalIgnoreCase), "original SHA256 differs");
            Assert(rom.SequenceEqual(originalSnapshot), "input ROM changed during build");
        });

        Check("Positive build hashes match the reviewed contract", () =>
        {
            Assert(string.Equals(build.UnrepairedImageSha1, ExpectedUnrepairedSha1,
                StringComparison.OrdinalIgnoreCase), "unrepaired SHA1 differs");
            Assert(string.Equals(build.UnrepairedImageSha256, ExpectedUnrepairedSha256,
                StringComparison.OrdinalIgnoreCase), "unrepaired SHA256 differs");
            Assert(string.Equals(build.OutputImageSha1, ExpectedOutputSha1,
                StringComparison.OrdinalIgnoreCase), "output SHA1 differs");
            Assert(string.Equals(build.OutputImageSha256, ExpectedOutputSha256,
                StringComparison.OrdinalIgnoreCase), "output SHA256 differs");
        });

        Check("Payload is exactly the reviewed 24 bytes", () =>
        {
            Assert(build.PayloadBytes.Length == LampPatternWordBuilder.AllocationLength,
                "payload length differs");
            Assert(Convert.ToHexString(build.PayloadBytes) ==
                   LampPatternWordBuilder.PayloadHex, "payload hex differs");
            Assert(build.PayloadBytes[0] == 0x00 && build.PayloadBytes[1] == 0xF8,
                "header is not 00F8");
            Assert(build.PayloadBytes[0x1014 - 0x1010] == 0xFF &&
                   build.PayloadBytes[0x101A - 0x1010] == 0xFF,
                "1014/101A are not FF");
        });

        Check("Eight nodes and four inline operands are decoded", () =>
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
                "byte operand 1020 differs");
            Assert(build.SourceMap.InlineOperands[3].Address == 0x1023 &&
                   build.SourceMap.InlineOperands[3].Width == 1 &&
                   build.SourceMap.InlineOperands[3].Value == 0x8F,
                "byte operand 1023 differs");
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

        Check("Shared service bytes match the original ROM", () =>
        {
            AssertRange(rom, 0x9C44, "9B1572BF", "shared cell");
            AssertRange(rom, 0x9B15, "BD796E", "handler entry");
            AssertRange(rom, 0x9B18,
                "790D7B6D787E786B7B7D8050792F", "shared body");
            AssertRange(rom, 0x796E, "3610AEE410AFE431840EFC", "trampoline");
            AssertRange(rom, 0x8050, "779149C5", "bridge cell");
            AssertRange(rom, 0x7791,
                "370696F127078A0197F1B7080CA641334220D6", "bridge entry");
            AssertRange(rom, 0x777A,
                "3420AD94352096F1270784FE97F1B7080C0EFC", "bridge continuation");
            AssertRange(rom, 0x49C5,
                LampPatternWordBuilder.NativeServiceHex, "native service");
            AssertRange(rom, 0x7963, "79654FE6A036060EFC", "byte literal cell");
            AssertRange(rom, 0x72BF, LampPatternWordBuilder.TableHex, "lamp table");
            Assert(rom[0x9C46] == 0x72 && rom[0x9C47] == 0xBF,
                "9C46 is not the 72BF service pointer");
        });

        Check("Relative stack model and pre-handler phases match supervisor review", () =>
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
            Assert(contract.StackSteps.Count ==
                   LampPatternWordBuilder.ExpectedPhaseOrder.Length,
                "stack step count differs");
            LampPatternStackStep Step(string phase) => contract.StackSteps.Single(
                step => step.Phase == phase);

            Assert(Step("handler-0").U == 0x066E &&
                   Step("handler-0").S == 0x0796,
                "handler-0 must use PRE-handler U=066E S=0796");
            Assert(Step("handler-1").U == 0x066C,
                "handler-1 must use PRE-handler U=066C");
            Assert(Step("handler-2").U == 0x066E,
                "handler-2 must use PRE-handler U=066E");
            Assert(Step("handler-3").U == 0x066C,
                "handler-3 must use PRE-handler U=066C");
            Assert(Step("handler-4").U == 0x066E,
                "handler-4 must use PRE-handler U=066E");
            Assert(Step("handler-5").U == 0x066C,
                "handler-5 must use PRE-handler U=066C");
            LampPatternStackStep sharedBody = Step("shared-body-entry");
            Assert(sharedBody.U == 0x0668 && sharedBody.S == 0x0794,
                "shared-body entry U/S differs");
            LampPatternStackStep sharedHandler = Step("shared-handler-entry");
            Assert(sharedHandler.U == 0x066A && sharedHandler.S == 0x0796,
                "shared 9B15 entry must be the PRE-JSR boundary");
            LampPatternStackStep trampolineJsr = Step(
                "service-trampoline-jrs-entry");
            Assert(trampolineJsr.U == 0x066A && trampolineJsr.S == 0x0794,
                "796E before PSHU must record U=066A S=0794");
            LampPatternStackStep trampolinePshu = Step(
                "service-trampoline-pshu");
            Assert(trampolinePshu.U == 0x0668 && trampolinePshu.S == 0x0794,
                "after 796E PSHU X must record U=0668 S=0794");
            LampPatternStackStep afterAdd = Step("shared-after-add");
            Assert(afterAdd.U == 0x066A, "after-add U differs");
            LampPatternStackStep bridgeEntry = Step("bridge-entry");
            Assert(bridgeEntry.U == 0x066A && bridgeEntry.S == 0x0794,
                "bridge entry U/S differs");
            LampPatternStackStep afterPop = Step("bridge-pulu-pattern");
            Assert(afterPop.U == 0x066C && afterPop.S == 0x0794,
                "PULU D phase does not record U=066C");
            LampPatternStackStep loadIndex = Step("bridge-load-index");
            Assert(loadIndex.U == 0x066C,
                "LDA 1,U phase must not advance U");
            LampPatternStackStep beforeDiscard = Step("bridge-discard-index");
            Assert(beforeDiscard.U == 0x066C && beforeDiscard.S == 0x0794,
                "LEAU phase must start at U=066C");
            LampPatternStackStep afterBranch = Step("bridge-branch-continuation");
            Assert(afterBranch.U == 0x066E,
                "BRA phase must occur after the U advance");
            LampPatternStackStep savesY = Step("bridge-saves-y");
            Assert(savesY.U == 0x066E && savesY.S == 0x0792,
                "PSHS Y phase does not record U=066E S=0792");
            LampPatternStackStep jsrEntry = Step("bridge-jsr-entry");
            Assert(jsrEntry.U == 0x066E && jsrEntry.S == 0x0790,
                "JSR entry phase does not record U=066E S=0790");
            Assert(Step("native-prologue-save-regs").S == 0x078C,
                "49C5 PSHS A,B,X must record S=078C");
            Assert(Step("native-prologue-save-mask").S == 0x078B,
                "49CE PSHS B must record S=078B");
            LampPatternStackStep nativeDeepest = Step("native-prologue-deepest");
            Assert(nativeDeepest.U == 0x066E && nativeDeepest.S == 0x078A,
                "native prologue phase does not record U=066E S=078A");
            Assert(Step("native-epilogue-puls-cc").S == 0x078B,
                "49E0 PULS CC must record S=078B");
            Assert(Step("native-epilogue-puls-a").S == 0x078C,
                "4A21 PULS A must record S=078C");
            LampPatternStackStep nativeReturn = Step("native-return");
            Assert(nativeReturn.U == 0x066E && nativeReturn.S == 0x0792,
                "native exit phase does not record U=066E S=0792");
            LampPatternStackStep restoresY = Step("bridge-restores-y");
            Assert(restoresY.U == 0x066E && restoresY.S == 0x0794,
                "PULS Y phase does not record U=066E S=0794");
            Assert(Step("shared-return-handler").S == 0x0794,
                "shared return handler must be the PRE-PULS boundary");
            LampPatternStackStep sharedReturn = Step("shared-returned-to-1026");
            Assert(sharedReturn.S == 0x0796, "shared-return S differs");
            LampPatternStackStep outerReturn = Step("outer-returned-to-9F16");
            Assert(outerReturn.S == 0x0798, "outer-return S differs");
            Assert(!contract.StackSteps.Any(step => step.S == 0x0778),
                "stack model transplanted the old B951 S=0778 absolute value");
            Assert(contract.ServiceClobbers.Contains("No arithmetic-register preservation",
                StringComparison.Ordinal), "service clobber statement is missing");
            Assert(contract.ServiceClobbers.Contains("066A->066C") &&
                   contract.ServiceClobbers.Contains("066C->066E"),
                "service clobber statement omits the actual PULU/LEAU order");
        });

        Check("Bridge/native chronology is decoded from the actual ROM order", () =>
        {
            LampPatternBridgeEvent[] events =
                LampPatternWordBuilder.DecodeBridgeChronology(rom);
            string[] expectedPhases =
            {
                "bridge-entry", "bridge-pulu-pattern", "bridge-load-index",
                "bridge-discard-index", "bridge-branch-continuation",
                "bridge-saves-y", "bridge-jsr-entry",
                "native-prologue-save-regs", "native-prologue-save-mask",
                "native-prologue-deepest", "native-epilogue-puls-cc",
                "native-epilogue-puls-a", "native-return", "bridge-restores-y"
            };
            Assert(events.Length == expectedPhases.Length,
                "decoded bridge event count differs");
            Assert(events.Select(item => item.Phase).SequenceEqual(expectedPhases),
                "decoded bridge phase order differs");
            Assert(events[0].Pc == 0x7791 && events[0].X == 0x8052 &&
                   events[0].Y == 0x9B24 && events[0].UDelta == 0,
                "bridge entry must be the pre-PULU boundary at 7791");
            Assert(events[1].InstructionPc == 0x7791 && events[1].UDelta == 2,
                "PULU D is not the first U advance");
            Assert(events[2].InstructionPc == 0x779E && events[2].UDelta == 0,
                "LDA 1,U should not advance U");
            Assert(events[3].InstructionPc == 0x77A0 && events[3].UDelta == 0,
                "pre-LEAU boundary must not already apply the U advance");
            Assert(events[4].InstructionPc == 0x77A0 && events[4].UDelta == 2,
                "LEAU 2,U is not the second U advance");
            Assert(events[5].InstructionPc == 0x777A && events[5].SDelta == -2,
                "PSHS Y must follow the U advance");
            Assert(events[6].InstructionPc == 0x777C && events[6].SDelta == -2,
                "JSR must follow PSHS Y");
            Assert(events[7].InstructionPc == 0x49C5 && events[7].SDelta == -4,
                "first native prologue push must be four bytes at 49C5");
            Assert(events[8].InstructionPc == 0x49CE && events[8].SDelta == -1,
                "second native prologue push must be one byte at 49CE");
            Assert(events[9].InstructionPc == 0x49D0 && events[9].SDelta == -1,
                "third native prologue push must be one byte at 49D0");
            Assert(events[10].InstructionPc == 0x49E0 && events[10].SDelta == 1,
                "native PULS CC must precede the epilogue");
            Assert(events[11].InstructionPc == 0x4A21 && events[11].SDelta == 1,
                "native PULS A must precede the return pull");
            Assert(events[12].InstructionPc == 0x4A23 && events[12].SDelta == 6,
                "native PULS A,B,X,PC must restore the return");
            Assert(events[13].InstructionPc == 0x777E && events[13].SDelta == 2,
                "bridge PULS Y must follow the native return");

            var oldOrder = (byte[])rom.Clone();
            oldOrder[0x7791] = 0x36;
            Reject(() => LampPatternWordBuilder.DecodeBridgeChronology(oldOrder),
                "PULU");
            var oldDiscard = (byte[])rom.Clone();
            oldDiscard[0x77A0] = 0x32;
            Reject(() => LampPatternWordBuilder.DecodeBridgeChronology(oldDiscard),
                "LEAU");
            var oldTarget = (byte[])rom.Clone();
            oldTarget[0x77A3] = 0xD5;
            Reject(() => LampPatternWordBuilder.DecodeBridgeChronology(oldTarget),
                "BRA");
            var oldPrologue = (byte[])rom.Clone();
            oldPrologue[0x49CE] = 0x34;
            oldPrologue[0x49CF] = 0x06;
            Reject(() => LampPatternWordBuilder.DecodeBridgeChronology(oldPrologue),
                "PSHS B");
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

        Check("Integrity repair changes exactly FFD1-FFD5", () =>
        {
            Assert(build.UnrepairedChangedOffsets.Count == 24,
                "unrepaired diff count differs");
            Assert(build.UnrepairedChangedOffsets.SequenceEqual(ExpectedUnrepairedOffsets),
                "unrepaired diff offsets differ");
            Assert(build.ChangedOffsets.Count == 29, "final diff count differs");
            Assert(build.ChangedOffsets.SequenceEqual(ExpectedFinalOffsets),
                "final diff offsets differ");
            Assert(build.RepairChangedOffsets.SequenceEqual(
                new[] { 0xFFD1, 0xFFD2, 0xFFD3, 0xFFD4, 0xFFD5 }),
                "repair-only offsets differ");
            Assert(build.IntegrityReport.OriginalStoredFieldsHex == ExpectedOriginalFields,
                "original fields differ");
            Assert(build.IntegrityReport.RepairedStoredFieldsHex == ExpectedFields,
                "repaired fields differ");
            Assert(build.CopyUnrepairedImage()[0x1014] == 0xFF &&
                   build.CopyUnrepairedImage()[0x101A] == 0xFF,
                "unrepaired 1014/101A are not FF");
        });

        Check("Preserved spans and guards are unchanged", () =>
        {
            byte[] output = build.CopyOutputImage();
            AssertRangeEqual(rom, output, 0x1000, 0x100F, "left guard");
            AssertRangeEqual(rom, output, 0x13F0, 0x13FF, "right guard");
            AssertRangeEqual(rom, output, 0x1400, 0x140F, "integrity neighbour");
            AssertRangeEqual(rom, output, 0x9ED7, 0x9EE6, "original 9ED7/9ED9");
            AssertRangeEqual(rom, output, 0x1028, 0x13EF, "unallocated extension");
            AssertRangeEqual(rom, output, 0x9C44, 0x9C47, "shared service cell");
            AssertRangeEqual(rom, output, 0x9B15, 0x9B25, "shared service body");
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

        Check("Source map is bound to the exact output and services", () =>
        {
            LampPatternSourceMap map = build.SourceMap;
            Assert(map.BuildId == build.OutputImageSha256, "map build id differs");
            Assert(map.Entries.Count == 44, "map entry count differs");
            Assert(map.Nodes.Count == 8, "map node count differs");
            Assert(map.InlineOperands.Count == 4, "map inline operand count differs");
            Assert(map.Phases.Count == LampPatternWordBuilder.ExpectedPhaseOrder.Length, "map phase count differs");
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
                   map.Resolve(0x1023).OperandValue == 0x8F,
                "pattern byte map entry differs");
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
            string[] bridgePhases =
            {
                "bridge-entry", "bridge-pulu-pattern", "bridge-load-index",
                "bridge-discard-index", "bridge-branch-continuation",
                "bridge-saves-y", "bridge-jsr-entry",
                "native-prologue-save-regs", "native-prologue-save-mask",
                "native-prologue-deepest", "native-epilogue-puls-cc",
                "native-epilogue-puls-a", "native-return", "bridge-restores-y"
            };
            int previous = -1;
            foreach (string phase in bridgePhases)
            {
                int index = map.Phases.ToList().FindIndex(
                    item => item.Phase == phase);
                Assert(index > previous,
                    $"map phase '{phase}' is absent or out of chronological order");
                previous = index;
            }
            LampPatternStaticPhase Phase(string name) => map.Phases.Single(
                phase => phase.Phase == name);
            for (int index = 0; index < 6; index++)
            {
                LampPatternNode node = build.Nodes[index];
                LampPatternStaticPhase handler = Phase($"handler-{index}");
                Assert(handler.U ==
                       build.StaticContract.StackSteps.Single(step =>
                           step.Phase == $"handler-{index}").U,
                    $"handler-{index} does not use its PRE-handler U");
                Assert(handler.Pc == node.HandlerAddress &&
                       handler.HandlerAddress == node.HandlerAddress &&
                       handler.X == node.Token + 2 &&
                       handler.Y == node.Address + 2,
                    $"handler-{index} PC/X/Y boundary differs");
            }
            Assert(Phase("handler-0").U == 0x066E &&
                   Phase("handler-0").X == 0x795D &&
                   Phase("handler-1").U == 0x066C &&
                   Phase("handler-2").U == 0x066E &&
                   Phase("handler-3").U == 0x066C &&
                   Phase("handler-4").U == 0x066E &&
                   Phase("handler-5").U == 0x066C,
                "handler pre-state or X mapping differs from the ROM instruction order");
            Assert(Phase("shared-handler-entry").Pc == 0x9B15 &&
                   Phase("shared-handler-entry").X == 0x9C46 &&
                   Phase("shared-handler-entry").U == 0x066A &&
                   Phase("shared-handler-entry").S == 0x0796,
                "shared 9B15 entry must be PRE-JSR with X=9C46");
            Assert(Phase("shared-body-entry").Pc == 0x00FC &&
                   Phase("shared-body-entry").X == 0x9B18 &&
                   Phase("shared-body-entry").Y == 0x9B18 &&
                   Phase("shared-body-entry").Token == 0x790D,
                "shared-body-entry must be the 00FC prefetch with X=Y=9B18, " +
                "not native PC 9B18");
            Assert(Phase("shared-after-fetch-word").Pc == 0x00FC &&
                   Phase("shared-after-fetch-word").X == 0x790F &&
                   Phase("shared-after-fetch-word").Y == 0x9B1A,
                "shared-after-fetch-word must be the 00FC prefetch with X=790F " +
                "and Y=9B1A");
            Assert(Phase("shared-after-rotate").X == 0x008F &&
                   Phase("shared-after-add").X == 0x7880 &&
                   Phase("shared-after-fetch-byte").X == 0x786D &&
                   Phase("shared-after-swap").X == 0x008F,
                "shared leaf exit X disagrees with LDX 2,U or preserved dispatch pointer");
            Assert(Phase("service-trampoline-jrs-entry").Pc == 0x796E &&
                   Phase("service-trampoline-jrs-entry").U == 0x066A &&
                   Phase("service-trampoline-jrs-entry").S == 0x0794,
                "796E pre-PSHU boundary differs");
            Assert(Phase("service-trampoline-pshu").Pc == 0x7970 &&
                   Phase("service-trampoline-pshu").U == 0x0668,
                "796E post-PSHU boundary differs");
            Assert(Phase("bridge-entry").X == 0x8052 &&
                   Phase("bridge-entry").Y == 0x9B24,
                "bridge entry X/Y differs");
            Assert(Phase("bridge-pulu-pattern").U == 0x066C &&
                   Phase("bridge-pulu-pattern").Pc == 0x7793,
                "PULU phase U/PC differs in the map");
            Assert(Phase("bridge-discard-index").U == 0x066C,
                "pre-LEAU phase must still record U=066C");
            Assert(Phase("bridge-branch-continuation").U == 0x066E,
                "post-LEAU BRA phase must record U=066E");
            Assert(Phase("bridge-saves-y").U == 0x066E &&
                   Phase("bridge-saves-y").S == 0x0792 &&
                   Phase("bridge-saves-y").Pc == 0x777C,
                "PSHS Y phase U/S/PC differs in the map");
            Assert(Phase("native-prologue-save-regs").Pc == 0x49C7 &&
                   Phase("native-prologue-save-mask").Pc == 0x49D0 &&
                   Phase("native-prologue-deepest").Pc == 0x49D2,
                "native prologue phase PCs are not the true post-instruction " +
                "boundaries 49C7/49D0/49D2");
            Assert(Phase("native-prologue-save-regs").S == 0x078C &&
                   Phase("native-prologue-save-mask").S == 0x078B &&
                   Phase("native-prologue-deepest").S == 0x078A,
                "native prologue pushes are not split across 49C5/49CE/49D0");
            Assert(Phase("native-epilogue-puls-cc").Pc == 0x49E2 &&
                   Phase("native-epilogue-puls-a").Pc == 0x4A23 &&
                   Phase("native-return").Pc == 0x777E,
                "native epilogue phase PCs differ from the decoded instruction ends");
            Assert(Phase("native-epilogue-puls-cc").S == 0x078B &&
                   Phase("native-epilogue-puls-a").S == 0x078C &&
                   Phase("native-return").S == 0x0792,
                "native epilogue S boundaries differ");
            Assert(Phase("native-return").U == 0x066E &&
                   Phase("native-return").X == 0x8052,
                "native return phase does not record U=066E/X=8052");
            Assert(Phase("shared-return-handler").Pc == 0x7931 &&
                   Phase("shared-return-handler").X == 0x7931 &&
                   Phase("shared-return-handler").Y == 0x9B26 &&
                   Phase("outer-return-handler").Pc == 0x7931 &&
                   Phase("outer-return-handler").X == 0x7931 &&
                   Phase("outer-return-handler").Y == 0x1028,
                "return handler X must be the 7931 handler/token-cell+2, not the Y cursor");
            Assert(Phase("shared-returned-to-1026").X == 0x7931 &&
                   Phase("outer-returned-to-9F16").X == 0x7931 &&
                   Phase("shared-prefetch-return").X == 0x8052,
                "post-return prefetch X values differ");
            Assert(Phase("shared-return-handler").SavedCursor == 0x1026 &&
                   Phase("outer-return-handler").SavedCursor == 0x9F16,
                "return-phase saved cursors differ");
            Assert(Phase("shared-returned-to-1026").S == 0x0796 &&
                   Phase("outer-returned-to-9F16").S == 0x0798,
                "return S boundaries differ");
            map.ValidateImage(build.CopyOutputImage());
        });

        Check("Independent ROM-derived phase oracle matches the map", () =>
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
        Check("LDX stack helpers reject stale dispatch X", () =>
        {
            foreach (var pair in new[] { ("shared-after-rotate", (ushort)0x7B6F),
                                         ("shared-after-swap", (ushort)0x7B7F) })
            {
                var stale = build.SourceMap.Phases.Select(phase =>
                    phase.Phase == pair.Item1 ? phase with { X = pair.Item2 } : phase).ToArray();
                Reject(() => LampPatternSourceMap.ValidatePhases(
                    stale, build.Nodes, build.StaticContract, rom), "instruction-boundary model");
            }
        });
        Check("Deterministic repeat is byte-identical", () =>
        {
            LampPatternBuildResult repeat = LampPatternWordBuilder.Build(rom);
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

        Check("Build result and source-map collections are immutable", () =>
        {
            byte[] outputCopy = build.CopyOutputImage();
            outputCopy[0x1010] = 0xAA;
            Assert(build.OutputImage[0x1010] == 0x00,
                "CopyOutputImage exposed internal output bytes");
            byte[] payloadCopy = build.CopyPayloadBytes();
            payloadCopy[0] = 0xAA;
            Assert(build.PayloadBytes[0] == 0x00,
                "CopyPayloadBytes exposed internal payload bytes");
            byte before = build.IntegrityReport.Fields[0].RepairedValue;
            VmIlIntegrityReport integrity = build.IntegrityReport;
            ((VmIlIntegrityField[])integrity.Fields)[0] =
                integrity.Fields[0] with { RepairedValue = (byte)(before ^ 0xFF) };
            Assert(build.IntegrityReport.Fields[0].RepairedValue == before,
                "IntegrityReport exposed internal field array");
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
                () => ((IList<ushort>)LampPatternWordBuilder.PredictedFrameAddresses)[0] =
                    0xFFFF, "PredictedFrameAddresses");
            Assert(LampPatternWordBuilder.PredictedFrameAddresses[0] == 0x010F,
                "PredictedFrameAddresses exposed a mutable global");
            ushort[] frameSnapshot = LampPatternWordBuilder.PredictedFrameAddresses.ToArray();
            frameSnapshot[0] = 0xFFFF;
            Assert(LampPatternWordBuilder.PredictedFrameAddresses[0] == 0x010F,
                "a copied frame-address array changed the global view");
            build.SourceMap.ValidateImage(build.CopyOutputImage());
            Assert(LampPatternWordBuilder.Build(rom).OutputImageSha256 ==
                   build.OutputImageSha256,
                "frame-address tampering changed a fresh build");

            var mutableVectors = new List<LampPatternVector>
            {
                new(0x1234, 0x5678)
            };
            var mutableSteps = new List<LampPatternStackStep>
            {
                new("caller-entry", 0x066E, 0x0798, 0, 0,
                    LampPatternWordBuilder.StackClassification)
            };
            LampPatternStaticContract snapshot = build.StaticContract with
            {
                Vectors = mutableVectors,
                StackSteps = mutableSteps
            };
            mutableVectors[0] = new LampPatternVector(0xAAAA, 0xBBBB);
            mutableVectors.Add(new LampPatternVector(1, 2));
            mutableSteps.Clear();
            Assert(snapshot.Vectors.Count == 1 &&
                   snapshot.Vectors[0] == new LampPatternVector(0x1234, 0x5678),
                "contract Vectors did not snapshot the caller list");
            Assert(snapshot.StackSteps.Count == 1 &&
                   snapshot.StackSteps[0].Phase == "caller-entry",
                "contract StackSteps did not snapshot the caller list");
            RejectReadOnly(
                () => ((IList<LampPatternVector>)snapshot.Vectors)[0] =
                    new LampPatternVector(9, 9), "contract Vectors");
            RejectReadOnly(
                () => ((IList<LampPatternStackStep>)snapshot.StackSteps)[0] =
                    snapshot.StackSteps[0], "contract StackSteps");

            string mapJsonBefore = JsonSerializer.Serialize(
                build.SourceMap, new JsonSerializerOptions { WriteIndented = true });
            mutableSteps.Add(new LampPatternStackStep(
                "injected", 0, 0, 0, 0, "injected"));
            string mapJsonAfter = JsonSerializer.Serialize(
                build.SourceMap, new JsonSerializerOptions { WriteIndented = true });
            Assert(mapJsonBefore == mapJsonAfter,
                "map serialization changed after caller-owned list mutation");
        });

        Check("Wrong original identity is rejected", () =>
        {
            Reject(() => LampPatternWordBuilder.Build(rom.AsSpan(0, 65535)), "length");
            var tampered = (byte[])rom.Clone();
            tampered[0x1400] ^= 1;
            Reject(() => LampPatternWordBuilder.Build(tampered), "SHA1");
        });

        Check("Wrong payload/header/early-return/literal-order/extra-operand is rejected", () =>
        {
            byte[] payload = Convert.FromHexString(LampPatternWordBuilder.PayloadHex);
            var wrongHeader = (byte[])payload.Clone();
            wrongHeader[0] = 0x01;
            Reject(() => LampPatternWordBuilder.ValidateComposedPayload(wrongHeader),
                "header");
            Reject(() => LampPatternWordBuilder.ValidateComposedPayload(
                payload.AsSpan(0, payload.Length - 1).ToArray()), "length");

            byte[] earlyBody = Convert.FromHexString("795BFF80787E792F795BFF80");
            Reject(() => LampPatternWordBuilder.AnalyzeBody(
                earlyBody, 0x1012, 0x1012 + earlyBody.Length), "reachability");

            var swapped = (byte[])payload.Clone();
            int indexOffset = 0x1020 - LampPatternWordBuilder.AllocationStart;
            int patternOffset = 0x1023 - LampPatternWordBuilder.AllocationStart;
            (swapped[indexOffset], swapped[patternOffset]) =
                (swapped[patternOffset], swapped[indexOffset]);
            byte[] swappedBody = swapped.AsSpan(2).ToArray();
            LampPatternNode[] swappedNodes = LampPatternWordBuilder.AnalyzeBody(
                swappedBody, 0x1012, 0x1012 + swappedBody.Length);
            Reject(() => LampPatternWordBuilder.ValidateNodes(rom, swapped, swappedNodes),
                "operand");

            var extra = Convert.FromHexString(LampPatternWordBuilder.BodyHex).ToList();
            extra.Insert(extra.Count - 2, 0x00);
            extra.Insert(extra.Count - 2, 0x00);
            byte[] extraBody = extra.ToArray();
            Reject(() => LampPatternWordBuilder.AnalyzeBody(
                extraBody, 0x1012, 0x1012 + extraBody.Length), "token");

            byte[] truncatedBody = Convert.FromHexString(
                LampPatternWordBuilder.BodyHex).Take(21).ToArray();
            Reject(() => LampPatternWordBuilder.AnalyzeBody(
                truncatedBody, 0x1012, 0x1012 + truncatedBody.Length), "body");
        });

        Check("Truncated bridge service bytes are rejected", () =>
        {
            var tampered = (byte[])rom.Clone();
            tampered[0x77A3] ^= 1;
            Reject(() => LampPatternWordBuilder.ValidateServiceContract(tampered),
                "bridge entry");
            var bodyTamper = (byte[])rom.Clone();
            bodyTamper[0x9B24] ^= 1;
            Reject(() => LampPatternWordBuilder.ValidateServiceContract(bodyTamper),
                "shared service body");
        });

        Check("Wrong handler=token+2 shared cell is rejected", () =>
        {
            var tampered = (byte[])rom.Clone();
            tampered[0x9C44] = 0x9C;
            tampered[0x9C45] = 0x46;
            Reject(() => LampPatternWordBuilder.ValidateServiceContract(tampered),
                "9C44");
            Reject(() => LampPatternWordBuilder.ValidateSharedCallResolution(tampered),
                "9C44");
        });

        Check("Wrong relative U model and old phase states are rejected", () =>
        {
            LampPatternStaticPhase[] phases = build.SourceMap.Phases.ToArray();
            void RejectPhases(LampPatternStaticPhase[] candidate, string label)
            {
                Reject(() => LampPatternSourceMap.ValidatePhases(
                    candidate, build.Nodes, build.StaticContract, rom), label);
            }

            LampPatternStaticPhase[] oldHandlerPost = phases.Select(phase =>
                phase.Phase == "handler-0" ? phase with { U = 0x066C } : phase).ToArray();
            RejectPhases(oldHandlerPost, "handler-0");

            LampPatternStaticPhase[] oldSharedPost = phases.Select(phase =>
                phase.Phase == "shared-handler-entry"
                    ? phase with { U = 0x0668, S = 0x0794 }
                    : phase).ToArray();
            RejectPhases(oldSharedPost, "shared-handler-entry");

            LampPatternStaticPhase[] wrongX = phases.Select(phase =>
                phase.Phase == "handler-0" ? phase with { X = 0x1014 } : phase).ToArray();
            RejectPhases(wrongX, "handler-0");

            LampPatternStaticPhase[] wrongXShared = phases.Select(phase =>
                phase.Phase == "shared-handler-entry"
                    ? phase with { X = 0x9B15 }
                    : phase).ToArray();
            RejectPhases(wrongXShared, "shared-handler-entry");

            LampPatternStaticPhase[] wrongSavedCursor = phases.Select(phase =>
                phase.Phase == "shared-return-handler"
                    ? phase with { SavedCursor = 0x9F16 }
                    : phase).ToArray();
            RejectPhases(wrongSavedCursor, "shared-return-handler");

            LampPatternStaticPhase[] oldSharedBodyPc = phases.Select(phase =>
                phase.Phase == "shared-body-entry"
                    ? phase with { Pc = 0x9B18 }
                    : phase).ToArray();
            RejectPhases(oldSharedBodyPc, "shared-body-entry");

            LampPatternStaticPhase[] oldAfterPrefetchPc = phases.Select(phase =>
                phase.Phase == "shared-after-fetch-word"
                    ? phase with { Pc = 0x9B1A, X = null }
                    : phase).ToArray();
            RejectPhases(oldAfterPrefetchPc, "shared-after-fetch-word");

            LampPatternStaticPhase[] wrongNativePc = phases.Select(phase =>
                phase.Phase == "native-prologue-deepest"
                    ? phase with { Pc = 0x9B18 }
                    : phase).ToArray();
            RejectPhases(wrongNativePc, "native-prologue-deepest");

            LampPatternStaticPhase[] midPshsPc = phases.Select(phase =>
                phase.Phase == "native-prologue-deepest"
                    ? phase with { Pc = 0x49D1 }
                    : phase).ToArray();
            RejectPhases(midPshsPc, "native-prologue-deepest");

            LampPatternStaticPhase[] wrongReturnX = phases.Select(phase =>
                phase.Phase == "shared-return-handler"
                    ? phase with { X = 0x9B26 }
                    : phase).ToArray();
            RejectPhases(wrongReturnX, "shared-return-handler");

            LampPatternStaticPhase[] wrongOuterReturnX = phases.Select(phase =>
                phase.Phase == "outer-return-handler"
                    ? phase with { X = 0x1028 }
                    : phase).ToArray();
            RejectPhases(wrongOuterReturnX, "outer-return-handler");

            LampPatternStaticPhase[] deepestAtJsr = phases.Select(phase =>
                phase.Phase == "bridge-jsr-entry"
                    ? phase with { S = 0x078A }
                    : phase).ToArray();
            RejectPhases(deepestAtJsr, "bridge-jsr-entry");

            LampPatternStaticPhase[] prologueAtEntry = phases.Select(phase =>
                phase.Phase == "native-prologue-save-regs"
                    ? phase with { S = 0x078A }
                    : phase).ToArray();
            RejectPhases(prologueAtEntry, "native-prologue-save-regs");

            LampPatternStackStep[] wrongSteps = build.StaticContract.StackSteps
                .Select(step => step.Phase == "shared-body-entry"
                    ? step with { U = 0x066C }
                    : step)
                .ToArray();
            LampPatternStaticContract wrongU = build.StaticContract with
            {
                StackSteps = wrongSteps
            };
            Reject(() => LampPatternWordBuilder.ValidateStaticContract(wrongU),
                "stack");
            LampPatternStaticContract wrongDeepest = build.StaticContract with
            {
                DeepestS = 0x078C,
                DeepestSRelativeToEntry = -12
            };
            Reject(() => LampPatternWordBuilder.ValidateStaticContract(wrongDeepest),
                "stack");

            LampPatternStackStep[] oldNativeU = build.StaticContract.StackSteps
                .Select(step => step.Phase is "bridge-jsr-entry" or
                                "native-prologue-save-regs" or
                                "native-prologue-deepest" or
                                "bridge-restores-y"
                    ? step with { U = 0x066A }
                    : step)
                .ToArray();
            LampPatternStaticContract oldNative = build.StaticContract with
            {
                StackSteps = oldNativeU
            };
            Reject(() => LampPatternWordBuilder.ValidateStaticContract(oldNative),
                "stack");

            List<LampPatternStackStep> reordered =
                build.StaticContract.StackSteps.ToList();
            int popIndex = reordered.FindIndex(
                step => step.Phase == "bridge-pulu-pattern");
            int saveIndex = reordered.FindIndex(
                step => step.Phase == "bridge-saves-y");
            (reordered[popIndex], reordered[saveIndex]) =
                (reordered[saveIndex], reordered[popIndex]);
            LampPatternStaticContract oldOrder = build.StaticContract with
            {
                StackSteps = reordered
            };
            Reject(() => LampPatternWordBuilder.ValidateStaticContract(oldOrder),
                "stack");
        });
        Check("Guard/preserved-output tamper is rejected", () =>
        {
            byte[] output = build.CopyOutputImage();
            output[0x1000] ^= 1;
            Reject(() => LampPatternWordBuilder.ValidatePreservedOutput(rom, output),
                "preserved");
            byte[] service = build.CopyOutputImage();
            service[0x49C5] ^= 1;
            Reject(() => LampPatternWordBuilder.ValidatePreservedOutput(rom, service),
                "preserved");
        });

        Check("Allocation overflow is rejected", () =>
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
        });

        Check("Unapproved extension range is rejected", () =>
        {
            ExtensionRangeDescriptor descriptor =
                ExtensionRangeDescriptor.Approved with { CpuEnd = 0x13FF };
            Reject(() => ExtensionRangeAllocator.Create(rom, descriptor), "CPU range");
        });

        Check("Stale source-map build identity is rejected", () =>
        {
            Reject(() => build.SourceMap.ValidateBuild(new string('0', 64)),
                "identity");
            byte[] tampered = build.CopyOutputImage();
            tampered[0x1010] ^= 1;
            Reject(() => build.SourceMap.ValidateImage(tampered), "identity");
        });

        Assert(rom.SequenceEqual(originalSnapshot), "input ROM changed after checks");
        string afterSha1 = Sha1(rom);
        string afterSha256 = Sha256(rom);

        var report = new LampPatternVerificationReport(
            "il-lamp-pattern-repair-60",
            1,
            checks.All(check => check.Passed) ? "pass" : "fail",
            LampPatternWordBuilder.StatusText,
            Path.GetFullPath(romPath),
            rom.Length,
            beforeSha1,
            beforeSha256,
            afterSha1,
            afterSha256,
            beforeSha1 == afterSha1 && beforeSha256 == afterSha256,
            LampPatternWordBuilder.PayloadHex,
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
            build.IntegrityReport.AlgorithmOrder,
            build.RepairChangedOffsets.ToArray(),
            build.SourceMap.BuildId,
            build.SourceMap.Entries.Count,
            build.SourceMap.Nodes.Count,
            build.SourceMap.InlineOperands.Count,
            build.SourceMap.Phases.Count,
            build.SourceMap.Boundaries.Count,
            build.StaticContract.EntryU,
            build.StaticContract.EntryS,
            build.StaticContract.DeepestS,
            build.StaticContract.Vectors,
            build.StaticContract.StackSteps,
            checks,
            new[]
            {
                "Static build and verification only. No MAME launch, capture, synthetic " +
                "execution, save state, debugger write or hardware test was performed.",
                "The 010F/011F/012F/013F frame-bit update is a static prediction from the " +
                "original service and the 72BF table; no full response byte is claimed.",
                "Natural safety of the 9C44/49C5 characteriser/PIA/scratch/IRQ side effects " +
                "at the 9F14 caller is unproved. The bridge 080C write is not covered by " +
                "49C5's F/I mask.",
                "MAME layout checked by supervisor: feature-grid outputs run 64..69, " +
                "72..77, ... 120..125 top-to-bottom; output = 64 + 8*topRow + column, so " +
                "72BF index 0 (output 120) is bottom-left START. Physical orientation and " +
                "hardware remain separate and unproved. M5 remains open; no general " +
                "linker/compiler or gameplay claim is made."
            },
            "Fresh natural 9F14 capture of the exact built image remains a separate gate.");

        WriteReport(outputDirectory, report, build);
    }

    private static void AssertRange(
        byte[] image, int address, string expectedHex, string label)
    {
        byte[] expected = Convert.FromHexString(expectedHex);
        if (address < 0 || address + expected.Length > image.Length)
            throw new InvalidDataException($"{label} is outside the image");
        for (int index = 0; index < expected.Length; index++)
        {
            if (image[address + index] != expected[index])
                throw new InvalidDataException(
                    $"{label} differs at {address + index:X4}: " +
                    $"{image[address + index]:X2} vs {expected[index]:X2}");
        }
    }

    private static void WriteReport(
        string outputDirectory, LampPatternVerificationReport report,
        LampPatternBuildResult build)
    {
        Directory.CreateDirectory(outputDirectory);
        var options = new JsonSerializerOptions { WriteIndented = true };
        byte[] reportBytes = JsonSerializer.SerializeToUtf8Bytes(report, options);
        string reportPath = Path.Combine(outputDirectory, "verification-report.json");
        File.WriteAllBytes(reportPath, reportBytes);

        var log = new StringBuilder();
        log.AppendLine("FruitMachineLab il-lamp-pattern-repair-60 verification");
        log.AppendLine("status: " + report.Status);
        log.AppendLine("original_sha1: " + report.RomSha1Before);
        log.AppendLine("original_sha256: " + report.RomSha256Before);
        log.AppendLine("unrepaired_sha1: " + report.UnrepairedSha1);
        log.AppendLine("unrepaired_sha256: " + report.UnrepairedSha256);
        log.AppendLine("output_sha1: " + report.OutputSha1);
        log.AppendLine("output_sha256: " + report.OutputSha256);
        log.AppendLine("fields: " + report.IntegrityRepairedFieldsHex);
        log.AppendLine("allocation_length: " + report.AllocationLength);
        log.AppendLine("remaining_approved_bytes: " + report.RemainingApprovedBytes);
        log.AppendLine("map_entries: " + report.MapEntryCount);
        log.AppendLine("map_phases: " + report.MapPhaseCount);
        log.AppendLine("map_boundaries: " + report.MapBoundaryCount);
        log.AppendLine("stack_entry_u: " + report.MapEntryU.ToString("X4"));
        log.AppendLine("stack_entry_s: " + report.MapEntryS.ToString("X4"));
        log.AppendLine("stack_deepest_s: " + report.MapDeepestS.ToString("X4"));
        foreach (LampPatternVerificationCheck check in report.Checks)
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

internal sealed record LampPatternOraclePhase(
    ushort Pc,
    ushort? X,
    ushort Y,
    ushort Token,
    int U,
    int S,
    ushort? SavedCursor);

internal static class LampPatternPhaseOracle
{
    public static Dictionary<string, LampPatternOraclePhase> Build(
        byte[] rom,
        byte[] output,
        IReadOnlyList<LampPatternNode> nodes)
    {
        if (rom.Length != 0x10000 || output.Length != 0x10000)
            throw new InvalidDataException("Phase oracle requires 65536-byte images");
        if (nodes.Count != 8)
            throw new InvalidDataException("Phase oracle requires eight body nodes");

        var phases = new Dictionary<string, LampPatternOraclePhase>(StringComparer.Ordinal);
        var control = new List<ushort>();
        int u = 0x066E;
        int s = 0x0798;
        int y = 0x9F14;

        void Add(string name, int pc, int? x, int yy, int token, int? saved) =>
            phases.Add(name, new LampPatternOraclePhase(
                checked((ushort)pc),
                x is null ? null : checked((ushort)x.Value),
                checked((ushort)yy),
                checked((ushort)token),
                u,
                s,
                saved is null ? null : checked((ushort)saved.Value)));

        Add("caller-dispatch", 0x00FC, null, 0x9F14, ReadWord(rom, 0x9F14), null);
        Add("header-trampoline-entry", 0x00F8, 0x1012, 0x9F16, 0x00F8, 0x9F16);
        control.Add(0x9F16);
        s -= 2;
        y = 0x1012;
        int x = 0x1012;
        byte[] memory = (byte[])output.Clone();
        memory[0x066E] = memory[0x066F] = 0;

        for (int index = 0; index < 6; index++)
        {
            int token = ReadWord(output, y);
            int handler = ReadWord(rom, token);
            Add($"body-prefetch-{index}", 0x00FC, x, y, token, null);
            if (handler != nodes[index].HandlerAddress || token != nodes[index].Token)
                throw new InvalidDataException(
                    $"Phase oracle body token {index} differs from the decoded node");
            x = token + 2;
            Add($"handler-{index}", handler, x, y + 2, token, null);
            y += 2;
            ApplyLeafHandler(rom, memory, handler, ref x, ref u, ref s, ref y);
        }

        int sharedToken = ReadWord(output, y);
        int sharedHandler = ReadWord(rom, sharedToken);
        Add("body-prefetch-6", 0x00FC, x, y, sharedToken, null);
        Add("shared-handler-entry", sharedHandler, sharedToken + 2, y + 2, sharedToken, null);
        if (sharedToken != 0x9C44 || sharedHandler != 0x9B15)
            throw new InvalidDataException("Phase oracle shared call binding differs");
        s -= 2;
        Add("service-trampoline-jrs-entry", 0x796E, sharedToken + 2, y + 2,
            sharedToken, null);
        u -= 2;
        Add("service-trampoline-pshu", 0x7970, sharedToken + 2, y + 2, sharedToken, null);
        if (!rom.AsSpan(0x796E, 11).SequenceEqual(
                new byte[] { 0x36, 0x10, 0xAE, 0xE4, 0x10, 0xAF, 0xE4, 0x31,
                             0x84, 0x0E, 0xFC }))
            throw new InvalidDataException("Phase oracle 796E trampoline bytes differ");
        control.Add(checked((ushort)(y + 2)));
        memory[u] = 0x9C; memory[u + 1] = 0x46;
        y = 0x9B18;
        Add("shared-body-entry", 0x00FC, y, y, ReadWord(output, y), 0x1026);

        string[] afterNames =
        {
            "shared-after-fetch-word", "shared-after-rotate", "shared-after-add",
            "shared-after-fetch-byte", "shared-after-swap"
        };
        for (int index = 0; index < afterNames.Length; index++)
        {
            int tokenAddress = y;
            int token = ReadWord(output, tokenAddress);
            int handler = ReadWord(rom, token);
            y = tokenAddress + 2;
            x = token + 2;
            ApplyLeafHandler(rom, memory, handler, ref x, ref u, ref s, ref y);
            int nextToken = ReadWord(output, y);
            int nextHandler = ReadWord(rom, nextToken);
            Add(afterNames[index], 0x00FC, x, y, nextToken, 0x1026);
            if (index == afterNames.Length - 1)
            {
                if (nextToken != 0x8050 || nextHandler != 0x7791)
                    throw new InvalidDataException(
                        "Phase oracle did not reach the original 8050 bridge");
            }
        }

        int bridgeTokenAddress = y;
        int bridgeToken = ReadWord(output, bridgeTokenAddress);
        int bridgeHandler = ReadWord(rom, bridgeToken);
        int bridgeX = bridgeToken + 2;
        int bridgeY = bridgeTokenAddress + 2;
        if (bridgeToken != 0x8050 || bridgeHandler != 0x7791)
            throw new InvalidDataException("Phase oracle bridge binding differs");
        Add("bridge-entry", 0x7791, bridgeX, bridgeY, bridgeToken, 0x1026);

        Expect(rom, 0x7791, 0x37, 0x06);
        u += 2;
        int pc = 0x7791 + InstructionLength(rom, 0x7791);
        Add("bridge-pulu-pattern", pc, bridgeX, bridgeY, bridgeToken, 0x1026);

        int ldaF1Pc = pc;
        Expect(rom, ldaF1Pc, 0x96, 0xF1);
        int beqPc = ldaF1Pc + InstructionLength(rom, ldaF1Pc);
        Expect(rom, beqPc, 0x27, 0x07);
        int branchTarget = beqPc + InstructionLength(rom, beqPc) +
            (sbyte)rom[beqPc + 1];
        if (branchTarget != 0x779E)
            throw new InvalidDataException(
                $"Phase oracle bridge BEQ target {branchTarget:X4} differs");
        pc = branchTarget;
        Add("bridge-load-index", pc, bridgeX, bridgeY, bridgeToken, 0x1026);
        pc += InstructionLength(rom, pc);
        Add("bridge-discard-index", pc, bridgeX, bridgeY, bridgeToken, 0x1026);
        Expect(rom, pc, 0x33, 0x42);
        u += 2;
        pc += InstructionLength(rom, pc);
        Add("bridge-branch-continuation", pc, bridgeX, bridgeY, bridgeToken, 0x1026);
        Expect(rom, pc, 0x20, 0xD6);
        int braTarget = pc + InstructionLength(rom, pc) + (sbyte)rom[pc + 1];
        if (braTarget != 0x777A)
            throw new InvalidDataException(
                $"Phase oracle bridge BRA target {braTarget:X4} differs");
        pc = braTarget;
        Expect(rom, pc, 0x34, 0x20);
        control.Add(checked((ushort)bridgeY));
        s -= 2;
        pc += InstructionLength(rom, pc);
        Add("bridge-saves-y", pc, bridgeX, bridgeY, bridgeToken, 0x1026);
        Expect(rom, pc, 0xAD, 0x94);
        int nativeTarget = ReadWord(rom, bridgeX);
        s -= 2;
        pc = nativeTarget;
        Add("bridge-jsr-entry", pc, bridgeX, bridgeY, bridgeToken, 0x1026);

        Expect(rom, pc, 0x34, 0x16);
        s -= 4;
        pc += InstructionLength(rom, pc);
        Add("native-prologue-save-regs", pc, null, bridgeY, bridgeToken, 0x1026);
        while (pc != 0x49CE)
            pc += InstructionLength(rom, pc);
        Expect(rom, pc, 0x34, 0x04);
        s -= 1;
        pc += InstructionLength(rom, pc);
        Add("native-prologue-save-mask", pc, null, bridgeY, bridgeToken, 0x1026);
        Expect(rom, pc, 0x34, 0x01);
        s -= 1;
        pc += InstructionLength(rom, pc);
        Add("native-prologue-deepest", pc, null, bridgeY, bridgeToken, 0x1026);
        while (pc != 0x49E0)
            pc += InstructionLength(rom, pc);
        Expect(rom, pc, 0x35, 0x01);
        s += 1;
        pc += InstructionLength(rom, pc);
        Add("native-epilogue-puls-cc", pc, null, bridgeY, bridgeToken, 0x1026);
        while (pc != 0x4A21)
            pc += InstructionLength(rom, pc);
        Expect(rom, pc, 0x35, 0x02);
        s += 1;
        pc += InstructionLength(rom, pc);
        Add("native-epilogue-puls-a", pc, null, bridgeY, bridgeToken, 0x1026);
        Expect(rom, pc, 0x35, 0x96);
        s += 6;
        pc = 0x777E;
        Add("native-return", pc, bridgeX, bridgeY, bridgeToken, 0x1026);
        Expect(rom, pc, 0x35, 0x20);
        s += 2;
        pc += InstructionLength(rom, pc);
        Add("bridge-restores-y", pc, bridgeX, bridgeY, bridgeToken, 0x1026);
        PopControl(control, 0x9B24);
        while (rom[pc] != 0x0E)
            pc += InstructionLength(rom, pc);
        Expect(rom, pc, 0x0E, 0xFC);
        pc = rom[pc + 1];
        if (pc != 0x00FC)
            throw new InvalidDataException(
                $"Phase oracle bridge continuation JMP target {pc:X4} is not 00FC");
        y = bridgeY;

        int sharedReturnAddress = y;
        int sharedReturnToken = ReadWord(output, sharedReturnAddress);
        Add("shared-prefetch-return", 0x00FC, bridgeX, sharedReturnAddress,
            sharedReturnToken, control[^1]);
        y = sharedReturnAddress + 2;
        int sharedReturnHandler = ReadWord(rom, sharedReturnToken);
        Add("shared-return-handler", sharedReturnHandler, sharedReturnToken + 2, y,
            sharedReturnToken, control[^1]);
        s += 2;
        int resumed = PopControl(control, 0x1026);
        y = resumed;
        Add("shared-returned-to-1026", 0x00FC, sharedReturnToken + 2, resumed,
            ReadWord(output, resumed), control[^1]);
        int outerToken = ReadWord(output, resumed);
        int outerHandler = ReadWord(rom, outerToken);
        y = resumed + 2;
        Add("outer-return-handler", outerHandler, outerToken + 2, y,
            outerToken, control[^1]);
        s += 2;
        int outerResumed = PopControl(control, 0x9F16);
        y = outerResumed;
        Add("outer-returned-to-9F16", 0x00FC, outerToken + 2, outerResumed,
            ReadWord(output, outerResumed), null);

        if (u != 0x066E || s != 0x0798 || y != 0x9F16)
            throw new InvalidDataException(
                $"Phase oracle did not balance: U={u:X4} S={s:X4} Y={y:X4}");
        if (control.Count != 0)
            throw new InvalidDataException("Phase oracle control stack is not empty");
        return phases;
    }

    private static int InstructionLength(byte[] rom, int pc)
    {
        byte opcode = rom[pc];
        if (opcode == 0x10)
        {
            return rom[pc + 1] switch
            {
                0xAE or 0xAF or 0xE6 or 0xE7 or 0xEC or 0xED or 0xEA or 0xE3 or
                0xE8 or 0xE4 or 0xE0 or 0xEE or 0xEF or 0xAD =>
                    checked(3 + IndexedExtra(rom[pc + 2])),
                _ => throw new InvalidDataException(
                    $"Phase oracle cannot decode 10 {rom[pc + 1]:X2} at {pc:X4}")
            };
        }
        if (opcode is 0x30 or 0x31 or 0x33 or 0xA6 or 0xAD or 0xAE or 0xAF or
            0xE0 or 0xE3 or 0xE4 or 0xE6 or 0xE7 or 0xE8 or 0xEA or 0xEC or
            0xED or 0xEE or 0xEF)
            return checked(2 + IndexedExtra(rom[pc + 1]));
        return opcode switch
        {
            0x3A or 0x3D or 0x44 or 0x54 or 0x4F => 1,
            0x0E or 0x1A or 0x1F or 0x20 or 0x25 or 0x27 or 0x34 or 0x35 or
            0x36 or 0x37 or 0x84 or 0x86 or 0x88 or 0x8A or 0x96 or 0x97 or
            0xC4 => 2,
            0x8E or 0xB7 or 0xF6 or 0xF7 => 3,
            _ => throw new InvalidDataException(
                $"Phase oracle cannot decode opcode {opcode:X2} at {pc:X4}")
        };
    }

    private static int IndexedExtra(byte postByte)
    {
        if (postByte < 0x80)
            return 0;
        return (postByte & 0x0F) switch
        {
            0x08 or 0x0C => 1,
            0x09 or 0x0D => 2,
            _ => 0
        };
    }

    private static void ApplyLeafHandler(
        byte[] rom, byte[] memory, int handler, ref int x, ref int u, ref int s, ref int y)
    {
        int d = 0;
        int pc = handler;
        void Store(int address, int value)
        {
            memory[address] = (byte)(value >> 8);
            memory[address + 1] = (byte)value;
        }
        while (true)
        {
            byte op = rom[pc];
            byte post = rom[pc + 1];
            if (op == 0x0E && post == 0xFC) return;
            if (op == 0x4F) { d &= 0xFF; pc++; continue; }
            switch (op, post)
            {
                case (0xEC, 0xA1): d = ReadWord(memory, y); y += 2; break;
                case (0xEC, 0xC4): d = ReadWord(memory, u); break;
                case (0xEC, 0xD4): d = ReadWord(memory, ReadWord(memory, u)); break;
                case (0xEC, 0x44): d = ReadWord(memory, u + 4); break;
                case (0xE6, 0xA0): d = (d & 0xFF00) | memory[y++]; break;
                case (0xE6, 0xD4): d = (d & 0xFF00) | memory[ReadWord(memory, u)]; break;
                case (0xED, 0xC4): Store(u, d); break;
                case (0xED, 0x42): Store(u + 2, d); break;
                case (0xAE, 0x42): x = ReadWord(memory, u + 2); break;
                case (0xAF, 0x44): Store(u + 4, x); break;
                case (0xAF, 0xC4): Store(u, x); break;
                case (0xE3, 0xC4): d = (d + ReadWord(memory, u)) & 0xFFFF; break;
                case (0xA8, 0xC4): d ^= memory[u] << 8; break;
                case (0xE8, 0x41): d ^= memory[u + 1]; break;
                case (0x36, 0x06): u -= 2; Store(u, d); break;
                case (0x37, 0x06): d = ReadWord(memory, u); u += 2; break;
                default: throw new InvalidDataException(
                    $"Phase oracle unsupported leaf instruction {op:X2}{post:X2} at {pc:X4}");
            }
            pc += 2;
        }
    }

    private static int StackBytes(byte mask)
    {
        int bytes = 0;
        if ((mask & 0x80) != 0) bytes += 2;
        if ((mask & 0x40) != 0) bytes += 2;
        if ((mask & 0x20) != 0) bytes += 2;
        if ((mask & 0x10) != 0) bytes += 2;
        if ((mask & 0x08) != 0) bytes += 1;
        if ((mask & 0x04) != 0) bytes += 1;
        if ((mask & 0x02) != 0) bytes += 1;
        if ((mask & 0x01) != 0) bytes += 1;
        return bytes;
    }

    private static int PopControl(List<ushort> control, ushort expected)
    {
        if (control.Count == 0 || control[^1] != expected)
            throw new InvalidDataException(
                $"Phase oracle control pop expected {expected:X4}");
        ushort value = control[^1];
        control.RemoveAt(control.Count - 1);
        return value;
    }

    private static void Expect(byte[] rom, int address, byte first, byte second)
    {
        if (rom[address] != first || rom[address + 1] != second)
            throw new InvalidDataException(
                $"Phase oracle expected bytes {first:X2} {second:X2} at {address:X4}");
    }

    private static ushort ReadWord(byte[] image, int address) =>
        (ushort)((image[address] << 8) | image[address + 1]);
}

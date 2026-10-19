using System.Collections.ObjectModel;
using System.Security.Cryptography;

namespace FruitMachineLab.Il;

public enum LampPatternOperandKind
{
    None,
    Word,
    Byte,
    ServiceOwnedNoCallerOperand
}

public sealed record LampPatternNode(
    int Index,
    ushort Address,
    ushort Token,
    string Operation,
    string BytesHex,
    LampPatternOperandKind OperandKind,
    ushort? OperandAddress,
    ushort? OperandValue,
    ushort HandlerAddress,
    ushort? SharedBodyAddress,
    ushort? ServicePointerAddress,
    ushort? ServicePointerValue,
    int StackDeltaBytes,
    int DepthAfter,
    int URelativeAfter,
    string Classification);

public sealed record LampPatternVector(ushort Input, ushort Result);

public sealed record LampPatternStackStep(
    string Phase,
    int U,
    int S,
    int URelativeToEntry,
    int SRelativeToEntry,
    string Classification);

public sealed record LampPatternBridgeEvent(
    ushort Pc,
    ushort InstructionPc,
    string Phase,
    string Instruction,
    ushort? X,
    ushort Y,
    int UDelta,
    int SDelta,
    string Boundary);

public sealed record LampPatternStaticContract
{
    private ReadOnlyCollection<LampPatternVector> _vectors =
        Array.AsReadOnly(Array.Empty<LampPatternVector>());
    private ReadOnlyCollection<LampPatternStackStep> _stackSteps =
        Array.AsReadOnly(Array.Empty<LampPatternStackStep>());

    public LampPatternStaticContract(
        ushort entryU,
        ushort entryS,
        int entryDepth,
        int exitDepth,
        int bodyUNet,
        int wholeCallSNet,
        ushort deepestS,
        int deepestSRelativeToEntry,
        ushort sharedSavedCursor,
        ushort outerSavedCursor,
        bool nestedCall,
        string resultPreservation,
        string serviceClobbers,
        string classification,
        IReadOnlyList<LampPatternVector> vectors,
        IReadOnlyList<LampPatternStackStep> stackSteps)
    {
        EntryU = entryU;
        EntryS = entryS;
        EntryDepth = entryDepth;
        ExitDepth = exitDepth;
        BodyUNet = bodyUNet;
        WholeCallSNet = wholeCallSNet;
        DeepestS = deepestS;
        DeepestSRelativeToEntry = deepestSRelativeToEntry;
        SharedSavedCursor = sharedSavedCursor;
        OuterSavedCursor = outerSavedCursor;
        NestedCall = nestedCall;
        ResultPreservation = resultPreservation ??
            throw new ArgumentNullException(nameof(resultPreservation));
        ServiceClobbers = serviceClobbers ??
            throw new ArgumentNullException(nameof(serviceClobbers));
        Classification = classification ??
            throw new ArgumentNullException(nameof(classification));
        Vectors = vectors ?? throw new ArgumentNullException(nameof(vectors));
        StackSteps = stackSteps ??
            throw new ArgumentNullException(nameof(stackSteps));
    }

    public ushort EntryU { get; init; }

    public ushort EntryS { get; init; }

    public int EntryDepth { get; init; }

    public int ExitDepth { get; init; }

    public int BodyUNet { get; init; }

    public int WholeCallSNet { get; init; }

    public ushort DeepestS { get; init; }

    public int DeepestSRelativeToEntry { get; init; }

    public ushort SharedSavedCursor { get; init; }

    public ushort OuterSavedCursor { get; init; }

    public bool NestedCall { get; init; }

    public string ResultPreservation { get; init; }

    public string ServiceClobbers { get; init; }

    public string Classification { get; init; }

    public IReadOnlyList<LampPatternVector> Vectors
    {
        get => _vectors;
        init => _vectors = Array.AsReadOnly(
            (value ?? throw new ArgumentNullException(nameof(value))).ToArray());
    }

    public IReadOnlyList<LampPatternStackStep> StackSteps
    {
        get => _stackSteps;
        init => _stackSteps = Array.AsReadOnly(
            (value ?? throw new ArgumentNullException(nameof(value))).ToArray());
    }
}

public sealed record LampPatternProvenance(
    string ProposalId,
    string ContractTaskId,
    string OriginalDefinitionListingPath,
    string OriginalDefinitionListingSha256,
    string OriginalBodyHex,
    string CallerListingPath,
    string ParentListingPath,
    string Classification);

public sealed record LampPatternByteChange(int Offset, byte Before, byte After);

public sealed class LampPatternBuildResult
{
    private readonly byte[] _outputImage;
    private readonly byte[] _unrepairedImage;
    private readonly byte[] _payloadBytes;
    private readonly ReadOnlyCollection<int> _unrepairedChangedOffsets;
    private readonly ReadOnlyCollection<int> _changedOffsets;
    private readonly ReadOnlyCollection<int> _repairChangedOffsets;
    private readonly ReadOnlyCollection<LampPatternByteChange> _byteChanges;
    private readonly ReadOnlyCollection<LampPatternNode> _nodes;
    private readonly VmIlIntegrityReport _integrityReport;

    internal LampPatternBuildResult(
        byte[] outputImage,
        byte[] unrepairedImage,
        byte[] payloadBytes,
        string originalRomSha1,
        string originalRomSha256,
        string unrepairedImageSha1,
        string unrepairedImageSha256,
        string outputImageSha1,
        string outputImageSha256,
        LampPatternNode[] nodes,
        LampPatternStaticContract staticContract,
        int[] unrepairedChangedOffsets,
        int[] changedOffsets,
        int[] repairChangedOffsets,
        LampPatternByteChange[] byteChanges,
        VmIlIntegrityReport integrityReport,
        LampPatternSourceMap sourceMap,
        LampPatternProvenance provenance)
    {
        _outputImage = (byte[])outputImage.Clone();
        _unrepairedImage = (byte[])unrepairedImage.Clone();
        _payloadBytes = (byte[])payloadBytes.Clone();
        _unrepairedChangedOffsets =
            Array.AsReadOnly((int[])unrepairedChangedOffsets.Clone());
        _changedOffsets = Array.AsReadOnly((int[])changedOffsets.Clone());
        _repairChangedOffsets = Array.AsReadOnly((int[])repairChangedOffsets.Clone());
        _byteChanges = Array.AsReadOnly((LampPatternByteChange[])byteChanges.Clone());
        _nodes = Array.AsReadOnly((LampPatternNode[])nodes.Clone());
        OriginalRomSha1 = originalRomSha1;
        OriginalRomSha256 = originalRomSha256;
        UnrepairedImageSha1 = unrepairedImageSha1;
        UnrepairedImageSha256 = unrepairedImageSha256;
        OutputImageSha1 = outputImageSha1;
        OutputImageSha256 = outputImageSha256;
        StaticContract = staticContract;
        _integrityReport = CopyIntegrityReport(integrityReport);
        SourceMap = sourceMap;
        Provenance = provenance;
    }

    public ReadOnlySpan<byte> OutputImage => _outputImage;

    public ReadOnlySpan<byte> UnrepairedImage => _unrepairedImage;

    public ReadOnlySpan<byte> PayloadBytes => _payloadBytes;

    public byte[] CopyOutputImage() => (byte[])_outputImage.Clone();

    public byte[] CopyUnrepairedImage() => (byte[])_unrepairedImage.Clone();

    public byte[] CopyPayloadBytes() => (byte[])_payloadBytes.Clone();

    public string OriginalRomSha1 { get; }

    public string OriginalRomSha256 { get; }

    public string UnrepairedImageSha1 { get; }

    public string UnrepairedImageSha256 { get; }

    public string OutputImageSha1 { get; }

    public string OutputImageSha256 { get; }

    public string BuildId => OutputImageSha256;

    public IReadOnlyList<LampPatternNode> Nodes => _nodes;

    public IReadOnlyList<int> UnrepairedChangedOffsets => _unrepairedChangedOffsets;

    public IReadOnlyList<int> ChangedOffsets => _changedOffsets;

    public IReadOnlyList<int> RepairChangedOffsets => _repairChangedOffsets;

    public IReadOnlyList<LampPatternByteChange> ByteChanges => _byteChanges;

    public LampPatternStaticContract StaticContract { get; }

    public VmIlIntegrityReport IntegrityReport => CopyIntegrityReport(_integrityReport);

    public LampPatternSourceMap SourceMap { get; }

    public LampPatternProvenance Provenance { get; }

    public int AllocationLength => LampPatternWordBuilder.AllocationLength;

    public int RemainingApprovedBytes => LampPatternWordBuilder.RemainingApprovedBytes;

    public string Status => LampPatternWordBuilder.StatusText;

    private static VmIlIntegrityReport CopyIntegrityReport(VmIlIntegrityReport report) =>
        report with
        {
            Fields = report.Fields.ToArray(),
            UnrepairedChangedOffsets = (int[])report.UnrepairedChangedOffsets.Clone(),
            RepairedChangedOffsets = (int[])report.RepairedChangedOffsets.Clone(),
            RepairChangedOffsets = (int[])report.RepairChangedOffsets.Clone()
        };
}

public static class LampPatternWordBuilder
{
    public const ushort HeaderAddress = 0x1010;
    public const ushort HeaderValue = 0x00F8;
    public const string HeaderHex = "00F8";
    public const ushort BodyStart = 0x1012;
    public const int BodyEndExclusive = 0x1028;
    public const int BodyLength = 22;
    public const int AllocationStart = 0x1010;
    public const int AllocationEndInclusive = 0x1027;
    public const int AllocationLength = 24;
    public const string BodyHex = "795BFF80787E795BFF807AAF79630079638F9C44792F";
    public const string PayloadHex = HeaderHex + BodyHex;
    public const int NodeCount = 8;
    public const int WordOperandCount = 2;
    public const int ByteOperandCount = 2;
    public const int InlineOperandCount = 4;
    public const int RemainingApprovedBytes = 968;

    public const ushort CallerTokenAddress = 0x9F14;
    public const ushort CallerOriginalToken = 0x9ED7;
    public const ushort CallerReplacementToken = 0x1010;
    public const ushort CallerSuccessorAddress = 0x9F16;
    public const ushort CallerSuccessorToken = 0x75A9;
    public const ushort ParentTokenAddress = 0x9F3D;
    public const ushort ParentToken = 0x9F10;
    public const ushort ParentSuccessorAddress = 0x9F3F;
    public const ushort ParentSuccessorToken = 0x792F;

    public const ushort OriginalHeaderAddress = 0x9ED7;
    public const ushort OriginalBodyStart = 0x9ED9;
    public const int OriginalBodyEndExclusive = 0x9EE7;
    public const string OriginalBodyHex = "795BFF80787E795BFF807AAF792F";
    public const string OriginalPrefixHex = "795BFF80787E795BFF807AAF";
    public const string RuntimeDispatchTemplateHex = "34203184AEA16E91";
    public const string CallerBodyHex = "77F69ED775A97B7D7B3D792F";
    public const ushort CallerHeaderAddress = 0x9F10;
    public const ushort CallerBodyStart = 0x9F12;
    public const int CallerBodyEndExclusive = 0x9F1E;
    public const ushort ParentBodyStart = 0x9F3B;
    public const string ParentBodyHex = "817D9F10792F";

    public const ushort SharedCallTokenAddress = 0x1024;
    public const ushort SharedCallToken = 0x9C44;
    public const ushort ServiceCellAddress = 0x9C44;
    public const ushort SharedCallHandlerAddress = 0x9B15;
    public const string SharedCallCellHex = "9B1572BF";
    public const ushort SharedBodyAddress = 0x9B18;
    public const string SharedBodyHex = "790D7B6D787E786B7B7D8050792F";
    public const int SharedBodyEndExclusive = 0x9B26;
    public const ushort ServicePointerAddress = 0x9C46;
    public const ushort ServicePointerValue = 0x72BF;
    public const ushort TrampolineAddress = 0x796E;
    public const string TrampolineHex = "3610AEE410AFE431840EFC";
    public const ushort BridgeCellAddress = 0x8050;
    public const ushort BridgePointerAddress = 0x8052;
    public const string BridgeCellHex = "779149C5";
    public const ushort BridgeEntryAddress = 0x7791;
    public const string BridgeEntryHex = "370696F127078A0197F1B7080CA641334220D6";
    public const ushort BridgeContinuationAddress = 0x777A;
    public const string BridgeContinuationHex = "3420AD94352096F1270784FE97F1B7080C0EFC";
    public const ushort NativeServiceAddress = 0x49C5;
    public const ushort NativeServiceEndInclusive = 0x4A24;
    public const string NativeServiceHex =
        "341684078E49BDE686340434011F893D1A50B70801F70802F608033501E861C47854" +
        "54548E01003AA662E684EAE4442502E0E4E784E68810EAE4442502E0E4E78810E688" +
        "20EAE4442502E0E4E78820E68830EAE4442502E0E4E7883035023596";

    public const ushort ByteLiteralTokenAddress = 0x7963;
    public const ushort ByteLiteralHandlerAddress = 0x7965;
    public const string ByteLiteralCellHex = "79654FE6A036060EFC";
    public const string ByteLiteralHandlerHex = "4FE6A036060EFC";
    public const ushort IndexOperandAddress = 0x1020;
    public const byte IndexOperand = 0x00;
    public const ushort PatternOperandAddress = 0x1023;
    public const byte PatternOperand = 0x8F;

    public const ushort TableAddress = 0x72BF;
    public const int TableLength = 48;
    public const string TableHex =
        "78191A3B3C1D70111233341568090A2B2C0D60010223240558393A1B1C3D5031321314" +
        "3548292A0B0C2D402122030425";

    public const int GridIndex = 0;
    public const int GridCellSize = 6;
    public const int GridLastRow = 7;
    public const int GridLastColumn = 5;
    public const byte PredictedMask = 0x01;
    private static readonly ushort[] PredictedFrameAddressStorage =
    {
        0x010F, 0x011F, 0x012F, 0x013F
    };
    private static readonly ReadOnlyCollection<ushort> PredictedFrameAddressView =
        Array.AsReadOnly((ushort[])PredictedFrameAddressStorage.Clone());
    public static ReadOnlyCollection<ushort> PredictedFrameAddresses =>
        PredictedFrameAddressView;

    public const ushort CallerEntryU = 0x066E;
    public const ushort CallerEntryS = 0x0798;
    public const ushort OuterBodyEntryS = 0x0796;
    public const ushort SharedBodyEntryS = 0x0794;
    public const ushort DeepestNativeS = 0x078A;
    public const ushort SharedSavedCursor = 0x1026;
    public const ushort OuterSavedCursor = 0x9F16;

    public const ushort LeftGuardStart = 0x1000;
    public const ushort LeftGuardEnd = 0x100F;
    public const ushort RightGuardStart = 0x13F0;
    public const ushort RightGuardEnd = 0x13FF;
    public const ushort IntegrityStart = 0x1400;

    public const string OriginalFieldsHex = "3E761E2605";
    public const string ExpectedRepairedFieldsHex = "E93F3C61B5";
    public const string ExpectedUnrepairedSha1 = "FED6058A6BF8D2627068BAC01D77EE0D279B5E46";
    public const string ExpectedUnrepairedSha256 =
        "3D94F6E2908D9C57C2C20EEDE897A0A19D4C74BA88464053554C0558C25ADDE3";
    public const string ExpectedOutputSha1 = "9F060102692BB31E03F992E95E38F4F59BEE1129";
    public const string ExpectedOutputSha256 =
        "631F6C252A5DF359525553F7D14A4FC8CEF965C76BBECA759EAAA862A3FAD4DE";

    public const string ProposalId = "lamp-pattern-24-byte-word";
    public const string ContractTaskId = "il-lamp-pattern-repair-60";
    public const string ProvenanceText =
        "Statically compiled 24-byte lamp-pattern word. Header 1010 contains 00F8 and body " +
        "1012-1027 contains the certified 9ED9 prefix, two inline byte literals (index 00 and " +
        "pattern 8F), the shared 9C44 lamp call with zero caller-stream operands, and one final " +
        "792F at 1026. Only the naturally cited caller token 9ED7 at 9F14 is replaced by 1010. " +
        "Original 9ED7/9ED9, service cells, table 72BF, other callers, guards, protected cells " +
        "and the 1400 neighbour are preserved. No MAME execution, natural new-body behaviour, " +
        "gameplay or hardware compatibility is claimed.";
    public const string StatusText =
        "STATIC COMPILED LAMP-PATTERN WORD ONLY: the 24-byte extension allocation and one " +
        "same-size caller token were emitted in memory and the ordered integrity fields were " +
        "repaired. The only predicted lamp effect from this word is frame-buffer bit 01 at " +
        "010F/011F/012F/013F for index 00 and pattern 8F. The reused original service also " +
        "reads DP-relative 00F1, conditionally writes 00F1 and 080C, masks IRQ/FIRQ around " +
        "its 0801/0802/0803 access, pushes and pulls U/S frames, saves and restores Y, and " +
        "changes A/CC net; 49C5 preserves A/B/X only within its own prologue/epilogue. No " +
        "whole-RAM-unchanged, safe-caller, natural-boot, execution or hardware claim is made.";
    public const string StaticPhaseClassification = "static_prediction_not_execution";
    public const string StackClassification = "static_relative_stack_model_not_capture";
    public const string ResultPreservationText =
        "The first 12 new body bytes are the original 9ED9 prefix. For every 16-bit input the " +
        "word leaves the same result cell at data-stack depth 1; the two new literal cells are " +
        "consumed by the shared 9C44 call and push no output.";
    public const string ServiceClobbersText =
        "The shared lamp service and bridge change A and CC state; 49C5 itself preserves A/B/X " +
        "and masks IRQ/FIRQ around its 0801/0802/0803 access, the bridge restores Y, U advances " +
        "066A->066C on the 7791 PULU D and 066C->066E on the 77A0 LEAU 2,U before the 777A " +
        "PSHS Y/JSR, S nets 0 across the service, and DP must be 0 for the 00F1 access. No " +
        "arithmetic-register preservation claim is made.";
    public const string SharedCallBoundaryText =
        "9C44 is a two-byte caller-stream token with zero caller operands. Its service cell is " +
        "9C44..9C47 = 9B1572BF: handler 9B15 at 9C44 and service-owned pointer 72BF at 9C46. " +
        "The handler=token+2 rule does not apply to 9C44; 9C46 is not a caller inline operand. " +
        "The shared body 9B18 returns to the caller's next token 1026, not to 9C46.";

    private static readonly (ushort Token, ushort Handler, int OperandBytes, string Operation,
        string HandlerHex)[] TokenTable =
    {
        (0x795B, 0x795D, 2, "vm_push_inline_word_literal",
            "ECA136060EFC"),
        (0x787E, 0x7880, 0, "vm_add_words",
            "3706E3C4EDC40EFC"),
        (0x7AAF, 0x7AB1, 0, "vm_bitwise_xor",
            "3706A8C4E841EDC40EFC"),
        (0x7963, 0x7965, 1, "vm_push_inline_byte_literal",
            "4FE6A036060EFC"),
        (0x9C44, 0x9B15, 0, "vm_call_shared_lamp_service",
            "BD796E"),
        (0x792F, 0x7931, 0, "vm_return_to_caller_stream",
            "35200EFC")
    };

    private static readonly int[] ExpectedUnrepairedChangedOffsets =
    {
        0x1010, 0x1011, 0x1012, 0x1013, 0x1015, 0x1016, 0x1017, 0x1018,
        0x1019, 0x101B, 0x101C, 0x101D, 0x101E, 0x101F, 0x1020, 0x1021,
        0x1022, 0x1023, 0x1024, 0x1025, 0x1026, 0x1027, 0x9F14, 0x9F15
    };

    private static readonly int[] ExpectedFinalChangedOffsets =
        ExpectedUnrepairedChangedOffsets.Concat(Enumerable.Range(0xFFD1, 5)).ToArray();

    private static readonly LampPatternVector[] ExpectedVectors =
    {
        new(0x0000, 0x0000),
        new(0x0001, 0x0001),
        new(0x7FFF, 0x80FF),
        new(0x8000, 0x8000),
        new(0xFFFF, 0x00FF)
    };

    internal static readonly string[] ExpectedPhaseOrder =
    {
        "caller-dispatch",
        "header-trampoline-entry",
        "body-prefetch-0",
        "handler-0",
        "body-prefetch-1",
        "handler-1",
        "body-prefetch-2",
        "handler-2",
        "body-prefetch-3",
        "handler-3",
        "body-prefetch-4",
        "handler-4",
        "body-prefetch-5",
        "handler-5",
        "body-prefetch-6",
        "shared-handler-entry",
        "service-trampoline-jrs-entry",
        "service-trampoline-pshu",
        "shared-body-entry",
        "shared-after-fetch-word",
        "shared-after-rotate",
        "shared-after-add",
        "shared-after-fetch-byte",
        "shared-after-swap",
        "bridge-entry",
        "bridge-pulu-pattern",
        "bridge-load-index",
        "bridge-discard-index",
        "bridge-branch-continuation",
        "bridge-saves-y",
        "bridge-jsr-entry",
        "native-prologue-save-regs",
        "native-prologue-save-mask",
        "native-prologue-deepest",
        "native-epilogue-puls-cc",
        "native-epilogue-puls-a",
        "native-return",
        "bridge-restores-y",
        "shared-prefetch-return",
        "shared-return-handler",
        "shared-returned-to-1026",
        "outer-return-handler",
        "outer-returned-to-9F16"
    };

    public static LampPatternBuildResult Build(ReadOnlySpan<byte> originalRom)
    {
        VmIlDefinition originalDefinition = ValidateOriginalSource(originalRom);
        ValidateServiceContract(originalRom);
        LampPatternBridgeEvent[] bridgeEvents = DecodeBridgeChronology(originalRom);

        byte[] payload = Convert.FromHexString(PayloadHex);
        ValidateComposedPayload(payload);
        LampPatternNode[] nodes = AnalyzeBody(
            payload.AsSpan(2), BodyStart, BodyEndExclusive);
        ValidateNodes(originalRom, payload, nodes);
        LampPatternStaticContract staticContract = BuildStaticContract(nodes, bridgeEvents);
        ValidateStaticContract(staticContract);
        ValidateSharedCallResolution(originalRom);

        var descriptor = ExtensionRangeDescriptor.Approved;
        ExtensionRangeAllocator allocator =
            ExtensionRangeAllocator.Create(originalRom, descriptor);
        ExtensionRangePlan plan = allocator.Plan(new[]
        {
            new ExtensionAllocationRequest(ProposalId, AllocationLength)
        });
        ExtensionRangeAllocation allocation = plan.Allocations.Single();
        if (allocation.CpuStart != AllocationStart ||
            allocation.CpuEnd != AllocationEndInclusive ||
            allocation.FileStart != AllocationStart ||
            allocation.FileEnd != AllocationEndInclusive ||
            allocation.Length != AllocationLength)
            throw new InvalidDataException(
                "Allocator did not place the lamp-pattern word at 1010-1027");

        for (int offset = AllocationStart; offset <= AllocationEndInclusive; offset++)
        {
            if (originalRom[offset] != 0xFF)
                throw new InvalidDataException(
                    $"Reviewed lamp-pattern allocation byte at {offset:X4} is " +
                    $"{originalRom[offset]:X2}; expected FF");
        }

        var payloadRecord = new ExtensionPayload(ProposalId, payload);
        ExtensionRangeEmission emission = ExtensionRangeEmitter.Emit(
            originalRom, descriptor, plan, new[] { payloadRecord });

        if (!emission.IntegrityCoveredBytesUnchanged ||
            !emission.IntegrityFieldsUnchanged)
            throw new InvalidDataException(
                "Extension emission unexpectedly changed integrity-covered bytes or fields");
        if (!emission.OutputImage.Slice(AllocationStart, AllocationLength)
                .SequenceEqual(payload))
            throw new InvalidDataException(
                "Emitted extension allocation does not contain the lamp-pattern payload");
        if (!emission.ChangedOffsets.SequenceEqual(
                ExpectedUnrepairedChangedOffsets.Take(22).ToArray()))
            throw new InvalidDataException(
                "Extension emission did not realize exactly the 22 reviewed payload changes");
        if (!emission.OutputImage.Slice(IntegrityStart, 0x10000 - IntegrityStart)
                .SequenceEqual(originalRom.Slice(
                    IntegrityStart, 0x10000 - IntegrityStart)))
            throw new InvalidDataException(
                "Unrepaired extension emission changed integrity-covered 1400-FFFF bytes");

        byte[] unrepaired = emission.CopyOutputImage();
        ValidateCallerBeforePatch(originalRom, unrepaired);
        if (!unrepaired.AsSpan(CallerTokenAddress, 2)
                .SequenceEqual(new byte[] { 0x9E, 0xD7 }))
            throw new InvalidDataException("Original caller token at 9F14 is not 9ED7");
        unrepaired[CallerTokenAddress] = 0x10;
        unrepaired[CallerTokenAddress + 1] = 0x10;

        int[] unrepairedDiff = ChangedOffsets(originalRom, unrepaired);
        if (!unrepairedDiff.SequenceEqual(ExpectedUnrepairedChangedOffsets))
            throw new InvalidDataException(
                "Unrepaired lamp-pattern diff is not exactly 22 extension changes plus " +
                "the two caller-token bytes");
        if (unrepaired[0x1014] != 0xFF || unrepaired[0x101A] != 0xFF)
            throw new InvalidDataException(
                "Unrepaired lamp-pattern word changed the original FF bytes at 1014/101A");

        var patch = new VmIlLampPatternPatchSpec(
            AllocationStart,
            Enumerable.Repeat((byte)0xFF, AllocationLength).ToArray(),
            payload,
            CallerTokenAddress,
            new byte[] { 0x9E, 0xD7 },
            new byte[] { 0x10, 0x10 });
        VmIlIntegrityResult integrity =
            VmIlIntegrity.RepairLampPattern(originalRom, unrepaired, patch);

        string outputSha1 = Sha1(integrity.RepairedImage);
        string outputSha256 = Sha256(integrity.RepairedImage);
        string unrepairedSha1 = Sha1(unrepaired);
        string unrepairedSha256 = Sha256(unrepaired);
        if (!string.Equals(unrepairedSha1, ExpectedUnrepairedSha1,
                StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(unrepairedSha256, ExpectedUnrepairedSha256,
                StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                $"Lamp-pattern unrepaired hashes are SHA1 {unrepairedSha1} / SHA256 " +
                $"{unrepairedSha256}; the reviewed contract requires " +
                $"{ExpectedUnrepairedSha1} / {ExpectedUnrepairedSha256}");
        if (!string.Equals(outputSha1, ExpectedOutputSha1, StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(outputSha256, ExpectedOutputSha256,
                StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                $"Lamp-pattern output hashes are SHA1 {outputSha1} / SHA256 " +
                $"{outputSha256}; the reviewed contract requires {ExpectedOutputSha1} / " +
                $"{ExpectedOutputSha256}");
        if (!string.Equals(
                integrity.Report.RepairedStoredFieldsHex, ExpectedRepairedFieldsHex,
                StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Lamp-pattern integrity fields are " +
                $"{integrity.Report.RepairedStoredFieldsHex}; the reviewed contract requires " +
                $"{ExpectedRepairedFieldsHex}");

        int[] finalDiff = ChangedOffsets(originalRom, integrity.RepairedImage);
        if (finalDiff.Length != 29 || !finalDiff.SequenceEqual(ExpectedFinalChangedOffsets))
            throw new InvalidDataException(
                "Final lamp-pattern diff is not exactly the reviewed 29 changed offsets");
        if (!integrity.Report.UnrepairedChangedOffsets.SequenceEqual(
                ExpectedUnrepairedChangedOffsets) ||
            !integrity.Report.RepairedChangedOffsets.SequenceEqual(
                ExpectedFinalChangedOffsets))
            throw new InvalidDataException(
                "Lamp-pattern integrity report diff does not match the reviewed contract");
        if (!integrity.Report.RepairChangedOffsets.SequenceEqual(
                new[] { 0xFFD1, 0xFFD2, 0xFFD3, 0xFFD4, 0xFFD5 }))
            throw new InvalidDataException(
                "Lamp-pattern repair changed bytes outside FFD1-FFD5");

        ValidatePreservedOutput(originalRom, integrity.RepairedImage);
        ValidatePredictedLampEffect(originalRom);

        var changes = new LampPatternByteChange[finalDiff.Length];
        for (int index = 0; index < finalDiff.Length; index++)
        {
            int offset = finalDiff[index];
            changes[index] = new LampPatternByteChange(
                offset, originalRom[offset], integrity.RepairedImage[offset]);
        }

        var provenance = new LampPatternProvenance(
            ProposalId,
            ContractTaskId,
            originalDefinition.Provenance.ListingPath,
            originalDefinition.Provenance.ListingSha256,
            OriginalBodyHex,
            "evidence/mpu4/VM-SCRIPTS/9F12.txt",
            "evidence/mpu4/VM-SCRIPTS/9F3B.txt",
            "static_compiled_lamp_pattern_word; original_rom_bytes; audit55_corrected_relative_model; " +
            "static_prediction_only");

        LampPatternSourceMap map = LampPatternSourceMap.CreateForBuild(
            originalRom,
            integrity.RepairedImage,
            nodes,
            staticContract,
            provenance);

        return new LampPatternBuildResult(
            integrity.RepairedImage,
            unrepaired,
            payload,
            Sha1(originalRom),
            Sha256(originalRom),
            unrepairedSha1,
            unrepairedSha256,
            outputSha1,
            outputSha256,
            nodes,
            staticContract,
            unrepairedDiff,
            finalDiff,
            integrity.Report.RepairChangedOffsets.ToArray(),
            changes,
            integrity.Report,
            map,
            provenance);
    }

    internal static VmIlDefinition ValidateOriginalSource(ReadOnlySpan<byte> rom)
    {
        VmIlDefinition definition = NineEdNineDecoder.Decode(rom);
        if (definition.HeaderAddress != OriginalHeaderAddress ||
            definition.BodyStart != OriginalBodyStart ||
            definition.BodyEndExclusive != OriginalBodyEndExclusive ||
            !definition.HeaderBytes.SequenceEqual(new byte[] { 0x00, 0xF8 }))
            throw new InvalidDataException(
                "Certified 9ED9 definition header/body span does not match the reviewed source");
        if (!rom.Slice(OriginalBodyStart, OriginalBodyEndExclusive - OriginalBodyStart)
                .SequenceEqual(Convert.FromHexString(OriginalBodyHex)))
            throw new InvalidDataException(
                "Original 9ED9 body bytes differ from the certified reviewed body");
        if (definition.Nodes.Count != 5)
            throw new InvalidDataException(
                $"Certified 9ED9 definition has {definition.Nodes.Count} nodes; expected 5");
        ushort[] originalTokens = { 0x795B, 0x787E, 0x795B, 0x7AAF, 0x792F };
        if (!definition.Nodes.Select(node => node.Token).SequenceEqual(originalTokens))
            throw new InvalidDataException(
                "Certified 9ED9 tokens differ from the preserved original sequence");
        if (!rom.Slice(OriginalBodyStart, OriginalPrefixHex.Length / 2)
                .SequenceEqual(Convert.FromHexString(OriginalPrefixHex)))
            throw new InvalidDataException(
                "Original 9ED9 prefix differs from the new word's preserved prefix");

        if (!rom.Slice(CallerHeaderAddress, 2).SequenceEqual(new byte[] { 0x00, 0xF8 }))
            throw new InvalidDataException("Caller definition header at 9F10 is not 00F8");
        if (!rom.Slice(CallerBodyStart, CallerBodyEndExclusive - CallerBodyStart)
                .SequenceEqual(Convert.FromHexString(CallerBodyHex)))
            throw new InvalidDataException(
                "Caller body at 9F12 does not match the reviewed 9F12 body");
        if (!rom.Slice(CallerTokenAddress, 2).SequenceEqual(new byte[] { 0x9E, 0xD7 }))
            throw new InvalidDataException("Caller token at 9F14 is not the expected 9ED7");
        if (!rom.Slice(CallerSuccessorAddress, 2)
                .SequenceEqual(new byte[] { 0x75, 0xA9 }))
            throw new InvalidDataException(
                "Caller successor token at 9F16 is not the expected 75A9");
        if (!rom.Slice(ParentBodyStart, ParentBodyHex.Length / 2)
                .SequenceEqual(Convert.FromHexString(ParentBodyHex)))
            throw new InvalidDataException(
                "Parent caller context at 9F3B-9F40 does not match the reviewed contract");
        if (!rom.Slice(ParentTokenAddress, 2).SequenceEqual(new byte[] { 0x9F, 0x10 }) ||
            !rom.Slice(ParentSuccessorAddress, 2).SequenceEqual(new byte[] { 0x79, 0x2F }))
            throw new InvalidDataException(
                "Parent caller context at 9F3D/9F3F does not match the reviewed contract");
        if (!rom.Slice(0x7927, 8)
                .SequenceEqual(Convert.FromHexString(RuntimeDispatchTemplateHex)))
            throw new InvalidDataException(
                "Runtime dispatch template at 7927-792E differs from the reviewed bytes");

        for (int offset = AllocationStart; offset <= AllocationEndInclusive; offset++)
        {
            if (rom[offset] != 0xFF)
                throw new InvalidDataException(
                    $"Reviewed lamp-pattern allocation byte at {offset:X4} is " +
                    $"{rom[offset]:X2}; expected FF");
        }

        foreach (var handler in TokenTable)
        {
            if (ReadWord(rom, handler.Token) != handler.Handler)
                throw new InvalidDataException(
                    $"Token {handler.Token:X4} cell points to {ReadWord(rom, handler.Token):X4}; " +
                    $"expected handler {handler.Handler:X4}");
            int evidenceLength = handler.HandlerHex.Length / 2;
            if (!rom.Slice(handler.Handler, evidenceLength)
                    .SequenceEqual(Convert.FromHexString(handler.HandlerHex)))
                throw new InvalidDataException(
                    $"Token {handler.Token:X4} handler bytes at {handler.Handler:X4} do not " +
                    "match the reviewed original service");
        }

        return definition;
    }

    internal static void ValidateServiceContract(ReadOnlySpan<byte> rom)
    {
        if (rom.Length != 0x10000)
            throw new InvalidDataException(
                $"ROM length {rom.Length} differs from the supported 65536 bytes");

        EnsureRomEqual(rom, ServiceCellAddress, SharedCallCellHex,
            "9C44 shared-cell token");
        EnsureRomEqual(rom, SharedCallHandlerAddress, "BD796E",
            "9B15 JSR trampoline entry");
        EnsureRomEqual(rom, SharedBodyAddress, SharedBodyHex,
            "9B18 shared service body");
        EnsureRomEqual(rom, TrampolineAddress, TrampolineHex,
            "796E shared-body trampoline");
        EnsureRomEqual(rom, BridgeCellAddress, BridgeCellHex,
            "8050 bridge cell");
        EnsureRomEqual(rom, BridgeEntryAddress, BridgeEntryHex,
            "7791-77A3 bridge entry");
        EnsureRomEqual(rom, BridgeContinuationAddress, BridgeContinuationHex,
            "777A-778C bridge continuation");
        EnsureRomEqual(rom, NativeServiceAddress, NativeServiceHex,
            "49C5-4A24 native lamp service");
        EnsureRomEqual(rom, ByteLiteralTokenAddress, ByteLiteralCellHex,
            "7963 byte-literal cell/handler");
        EnsureRomEqual(rom, TableAddress, TableHex,
            "72BF 48-cell lamp table");

        ushort sharedCell = ReadWord(rom, ServiceCellAddress);
        if (sharedCell != SharedCallHandlerAddress)
            throw new InvalidDataException(
                $"Shared call 9C44 resolves to {sharedCell:X4}; expected 9B15");
        ushort servicePointer = ReadWord(rom, ServicePointerAddress);
        if (servicePointer != ServicePointerValue)
            throw new InvalidDataException(
                $"Service-owned pointer at 9C46 is {servicePointer:X4}; expected 72BF");
        if (sharedCell == ServiceCellAddress + 2)
            throw new InvalidDataException(
                "The shared call 9C44 must not be resolved by the handler=token+2 rule");

        ushort byteLiteralCell = ReadWord(rom, ByteLiteralTokenAddress);
        if (byteLiteralCell != ByteLiteralHandlerAddress)
            throw new InvalidDataException(
                $"Byte literal 7963 cell points to {byteLiteralCell:X4}; expected 7965");
    }

    internal static void ValidateSharedCallResolution(ReadOnlySpan<byte> rom)
    {
        if (ReadWord(rom, ServiceCellAddress) != SharedCallHandlerAddress)
            throw new InvalidDataException(
                "Shared call token 9C44 is not bound to the original 9B15 handler");
        if (ReadWord(rom, ServicePointerAddress) != ServicePointerValue)
            throw new InvalidDataException(
                "Shared call 9C46 is not the original service-owned 72BF pointer");
        if (ReadWord(rom, ServiceCellAddress) == ServiceCellAddress + 2)
            throw new InvalidDataException(
                "Shared call 9C44 incorrectly used token+2 as its handler");
        if (!rom.Slice(SharedBodyAddress, SharedBodyEndExclusive - SharedBodyAddress)
                .SequenceEqual(Convert.FromHexString(SharedBodyHex)))
            throw new InvalidDataException(
                "Shared service body at 9B18 does not match the reviewed bytes");
    }

    internal static int InstructionLength(ReadOnlySpan<byte> rom, int pc)
    {
        if (pc < 0 || pc >= rom.Length)
            throw new InvalidDataException(
                $"Instruction address {pc:X4} is outside the 6809 ROM image");
        byte opcode = rom[pc];
        if (opcode == 0x10)
        {
            if (pc + 1 >= rom.Length)
                throw new InvalidDataException(
                    $"Truncated 10-prefixed instruction at {pc:X4}");
            return rom[pc + 1] switch
            {
                0xAE or 0xAF or 0xE6 or 0xE7 or 0xEC or 0xED or 0xEA or 0xE3 or
                0xE8 or 0xE4 or 0xE0 or 0xEE or 0xEF or 0xAD => 3,
                _ => throw new InvalidDataException(
                    $"Unsupported 10-prefixed opcode {rom[pc + 1]:X2} at {pc:X4}")
            };
        }

        return opcode switch
        {
            0x3A or 0x3D or 0x44 or 0x54 or 0x4F => 1,
            0x0E or 0x1A or 0x1F or 0x20 or 0x25 or 0x27 or 0x30 or 0x31 or
            0x33 or 0x34 or 0x35 or 0x36 or 0x37 or 0x84 or 0x86 or 0x88 or
            0x8A or 0x96 or 0x97 or 0xA6 or 0xAD or 0xAE or 0xAF or 0xC4 or
            0xE0 or 0xE3 or 0xE4 or 0xE6 or 0xE7 or 0xE8 or 0xEA or 0xEC or
            0xED => 2,
            0x8E or 0xB7 or 0xF6 or 0xF7 => 3,
            _ => throw new InvalidDataException(
                $"Unsupported 6809 opcode {opcode:X2} at {pc:X4}; instruction " +
                "length cannot be derived from the ROM")
        };
    }

    internal static LampPatternBridgeEvent[] DecodeBridgeChronology(
        ReadOnlySpan<byte> rom)
    {
        if (rom.Length != 0x10000)
            throw new InvalidDataException(
                $"ROM length {rom.Length} differs from the supported 65536 bytes");

        if (ReadWord(rom, 0x9B22) != 0x8050)
            throw new InvalidDataException(
                "Shared body token at 9B22 is not the reviewed 8050 bridge token");
        if (ReadWord(rom, BridgeCellAddress) != BridgeEntryAddress ||
            ReadWord(rom, BridgeCellAddress + 2) != NativeServiceAddress)
            throw new InvalidDataException(
                $"Bridge cell at {BridgeCellAddress:X4} is not 7791/49C5");

        var events = new List<LampPatternBridgeEvent>(16);
        void Add(
            int pc,
            int instructionPc,
            string phase,
            string instruction,
            ushort? x,
            int y,
            int uDelta,
            int sDelta,
            string boundary)
        {
            events.Add(new LampPatternBridgeEvent(
                checked((ushort)pc),
                checked((ushort)instructionPc),
                phase,
                instruction,
                x,
                checked((ushort)y),
                uDelta,
                sDelta,
                boundary));
        }

        ExpectBridgeBytes(rom, 0x7791, "3706", "bridge PULU D");
        Add(
            0x7791, 0x7791, "bridge-entry", "VM token 8050 -> handler 7791",
            BridgePointerAddress, 0x9B24, 0, 0,
            "Handler 7791 entry before PULU D; X=8052 token+2, Y=9B24; PRE-POP " +
            "U=066A S=0794.");
        Add(
            0x7793, 0x7791, "bridge-pulu-pattern", "37 06 PULU D",
            BridgePointerAddress, 0x9B24, 2, 0,
            "After 7791 PULU D at PC=7793; pattern cell consumed, U 066A->066C.");

        ExpectBridgeBytes(rom, 0x7793, "96F1", "bridge LDA 00F1");
        ExpectBridgeBytes(rom, 0x7795, "2707", "bridge BEQ +7");
        int branchTarget = 0x7795 + 2 + (sbyte)rom[0x7796];
        if (branchTarget != 0x779E)
            throw new InvalidDataException(
                $"Bridge BEQ at 7795 targets {branchTarget:X4}; expected 779E");
        ExpectBridgeBytes(rom, 0x7797, "8A0197F1B7080C",
            "bridge optional 00F1/080C path");
        ExpectBridgeBytes(rom, 0x779E, "A641", "bridge LDA 1,U");
        Add(
            0x779E, 0x779E, "bridge-load-index", "A6 41 LDA 1,U",
            BridgePointerAddress, 0x9B24, 0, 0,
            "Before 779E LDA 1,U; reads the retained index byte at U+1, U stays 066C.");

        ExpectBridgeBytes(rom, 0x77A0, "3342", "bridge LEAU 2,U");
        Add(
            0x77A0, 0x77A0, "bridge-discard-index", "33 42 LEAU 2,U",
            BridgePointerAddress, 0x9B24, 0, 0,
            "Before 77A0 LEAU 2,U; U is still 066C.");
        ExpectBridgeBytes(rom, 0x77A2, "20D6", "bridge BRA 777A");
        int braTarget = 0x77A2 + 2 + (sbyte)rom[0x77A3];
        if (braTarget != BridgeContinuationAddress)
            throw new InvalidDataException(
                $"Bridge BRA at 77A2 targets {braTarget:X4}; expected 777A");
        Add(
            0x77A2, 0x77A0, "bridge-branch-continuation", "33 42 LEAU 2,U; 20 D6 BRA",
            BridgePointerAddress, 0x9B24, 2, 0,
            "After 77A0 LEAU 2,U at PC=77A2; U 066C->066E before BRA 777A.");

        ExpectBridgeBytes(rom, BridgeContinuationAddress, "3420", "bridge PSHS Y");
        Add(
            BridgeContinuationAddress + 2, BridgeContinuationAddress, "bridge-saves-y",
            "34 20 PSHS Y", BridgePointerAddress, 0x9B24, 0, -2,
            "After 777A PSHS Y at PC=777C; Y=9B24 saved, S 0794->0792 before JSR.");
        ExpectBridgeBytes(rom, BridgeContinuationAddress + 2, "AD94", "bridge JSR");
        ExpectBridgeBytes(rom, NativeServiceAddress, "3416", "native prologue");
        Add(
            NativeServiceAddress, BridgeContinuationAddress + 2, "bridge-jsr-entry",
            "AD 94 JSR [,X] -> 49C5", BridgePointerAddress, 0x9B24, 0, -2,
            "After 777C JSR [,X] at 49C5 entry; return 777E is on S, " +
            "S 0792->0790, U=066E.");
        int saveRegsPc = NativeServiceAddress + InstructionLength(rom, NativeServiceAddress);
        Add(
            saveRegsPc, NativeServiceAddress,
            "native-prologue-save-regs", "34 16 PSHS A,B,X",
            null, 0x9B24, 0, -4,
            $"After 49C5 PSHS A,B,X pushes four bytes at PC={saveRegsPc:X4}; " +
            "S 0790->078C. X is not asserted after the native body begins.");
        ExpectBridgeBytes(rom, 0x49CE, "3404", "native PSHS B");
        int saveMaskPc = 0x49CE + InstructionLength(rom, 0x49CE);
        Add(
            saveMaskPc, 0x49CE, "native-prologue-save-mask", "34 04 PSHS B",
            null, 0x9B24, 0, -1,
            $"After 49CE PSHS B pushes the mask byte at PC={saveMaskPc:X4}; " +
            "S 078C->078B.");
        ExpectBridgeBytes(rom, 0x49D0, "3401", "native PSHS CC");
        int deepestPc = 0x49D0 + InstructionLength(rom, 0x49D0);
        Add(
            deepestPc, 0x49D0, "native-prologue-deepest", "34 01 PSHS CC",
            null, 0x9B24, 0, -1,
            $"After 49D0 PSHS CC pushes one byte at PC={deepestPc:X4}; native " +
            "prologue deepest S=078A. The six prologue bytes were pushed at 49C5, " +
            "49CE and 49D0, not all at entry.");
        ExpectBridgeBytes(rom, 0x49E0, "3501", "native PULS CC");
        int pulsCcPc = 0x49E0 + InstructionLength(rom, 0x49E0);
        Add(
            pulsCcPc, 0x49E0, "native-epilogue-puls-cc", "35 01 PULS CC",
            null, 0x9B24, 0, 1,
            $"After 49E0 PULS CC restores the challenge CC at PC={pulsCcPc:X4}; " +
            "S 078A->078B.");
        ExpectBridgeBytes(rom, 0x4A21, "3502", "native PULS A");
        int pulsAPc = 0x4A21 + InstructionLength(rom, 0x4A21);
        Add(
            pulsAPc, 0x4A21, "native-epilogue-puls-a", "35 02 PULS A",
            null, 0x9B24, 0, 1,
            $"After 4A21 PULS A consumes the saved mask byte at PC={pulsAPc:X4}; " +
            "S 078B->078C.");
        ExpectBridgeBytes(rom, 0x4A23, "3596", "native PULS A,B,X,PC");
        ushort nativeReturnPc = checked((ushort)(
            BridgeContinuationAddress + 2 + InstructionLength(
                rom, BridgeContinuationAddress + 2)));
        Add(
            nativeReturnPc, 0x4A23, "native-return",
            "35 96 PULS A,B,X,PC -> 777E", BridgePointerAddress, 0x9B24, 0, 6,
            $"After 4A23 PULS A,B,X,PC returns to {nativeReturnPc:X4}; S 078C->0792, " +
            "X restored to 8052, Y unchanged 9B24.");
        ExpectBridgeBytes(rom, nativeReturnPc, "3520", "bridge PULS Y");
        Add(
            BridgeContinuationAddress + 6, BridgeContinuationAddress + 4,
            "bridge-restores-y", "35 20 PULS Y",
            BridgePointerAddress, 0x9B24, 0, 2,
            "After 777E PULS Y at PC=7780; restores 9B24, S 0792->0794.");
        ExpectBridgeBytes(
            rom, BridgeContinuationAddress + 6, BridgeContinuationHex.Substring(12),
            "bridge 7780-778C continuation");

        return events.ToArray();
    }

    private static void ExpectBridgeBytes(
        ReadOnlySpan<byte> rom, int address, string expectedHex, string label)
    {
        byte[] expected = Convert.FromHexString(expectedHex);
        if (address < 0 || address + expected.Length > rom.Length)
            throw new InvalidDataException(
                $"Bridge span for {label} at {address:X4} is outside the ROM");
        if (!rom.Slice(address, expected.Length).SequenceEqual(expected))
            throw new InvalidDataException(
                $"Bridge bytes for {label} at {address:X4}-" +
                $"{address + expected.Length - 1:X4} differ from the reviewed order");
    }

    internal static void ValidateComposedPayload(ReadOnlySpan<byte> payload)
    {
        if (payload.Length != AllocationLength)
            throw new InvalidDataException(
                $"Lamp-pattern payload length {payload.Length} differs from the reviewed " +
                $"{AllocationLength}-byte allocation");
        if (!payload.Slice(0, 2).SequenceEqual(Convert.FromHexString(HeaderHex)))
            throw new InvalidDataException(
                "Lamp-pattern header is not the reviewed 00F8 value");
        if (!payload.Slice(2).SequenceEqual(Convert.FromHexString(BodyHex)))
            throw new InvalidDataException(
                "Lamp-pattern body is not the reviewed 22-byte body");
        if (!payload.Slice(2, OriginalPrefixHex.Length / 2)
                .SequenceEqual(Convert.FromHexString(OriginalPrefixHex)))
            throw new InvalidDataException(
                "Lamp-pattern body does not preserve the original 9ED9 12-byte prefix");
    }

    internal static LampPatternNode[] AnalyzeBody(
        ReadOnlySpan<byte> body, ushort bodyStart, int bodyEndExclusive)
    {
        if (body.Length <= 0)
            throw new InvalidDataException("Lamp-pattern body is empty");
        if (bodyEndExclusive != bodyStart + body.Length)
            throw new InvalidDataException(
                $"Lamp-pattern body span {bodyStart:X4}-{bodyEndExclusive - 1:X4} does not " +
                $"match its {body.Length} bytes");
        if (bodyEndExclusive > 0x10000)
            throw new InvalidDataException(
                $"Lamp-pattern body end {bodyEndExclusive:X4} exceeds the 16-bit address space");

        var nodes = new List<LampPatternNode>();
        int cursor = bodyStart;
        int offset = 0;
        int cells = 1;
        int uDelta = 0;
        bool returned = false;

        while (offset < body.Length)
        {
            if (offset + 2 > body.Length)
                throw new InvalidDataException(
                    $"Truncated VM token at {cursor:X4} in the lamp-pattern body");
            if (cursor + 2 > bodyEndExclusive)
                throw new InvalidDataException(
                    $"VM token at {cursor:X4} crosses the body end {bodyEndExclusive:X4}");

            ushort token = (ushort)((body[offset] << 8) | body[offset + 1]);
            var binding = TokenTable.SingleOrDefault(entry => entry.Token == token);
            if (binding.Token != token)
                throw new InvalidDataException(
                    $"Unsupported lamp-pattern token {token:X4} at {cursor:X4}");
            if (token is not (0x795B or 0x787E or 0x7AAF or 0x7963 or 0x9C44 or 0x792F))
                throw new InvalidDataException(
                    $"Lamp-pattern token {token:X4} at {cursor:X4} is outside the reviewed subset");

            int nodeLength = 2 + binding.OperandBytes;
            if (offset + nodeLength > body.Length)
                throw new InvalidDataException(
                    $"Truncated VM operand for token {token:X4} at {cursor:X4}");
            if (cursor + nodeLength > bodyEndExclusive)
                throw new InvalidDataException(
                    $"VM instruction {token:X4} at {cursor:X4} crosses the body end " +
                    $"{bodyEndExclusive:X4}");

            if (returned)
                throw new InvalidDataException(
                    $"Multiple VM return tokens: bytes after a return at {cursor:X4}");

            LampPatternOperandKind operandKind = binding.OperandBytes switch
            {
                2 => LampPatternOperandKind.Word,
                1 => LampPatternOperandKind.Byte,
                _ => token == SharedCallToken
                    ? LampPatternOperandKind.ServiceOwnedNoCallerOperand
                    : LampPatternOperandKind.None
            };

            ushort? operandAddress = null;
            ushort? operandValue = null;
            if (binding.OperandBytes == 2)
            {
                ushort value = (ushort)((body[offset + 2] << 8) | body[offset + 3]);
                operandAddress = checked((ushort)(cursor + 2));
                operandValue = value;
            }
            else if (binding.OperandBytes == 1)
            {
                operandAddress = checked((ushort)(cursor + 2));
                operandValue = body[offset + 2];
            }

            int stackDelta = token switch
            {
                0x795B => -2,
                0x787E => 2,
                0x7AAF => 2,
                0x7963 => -2,
                0x9C44 => 4,
                0x792F => 0,
                _ => throw new InvalidDataException(
                    $"Unsupported lamp-pattern stack effect for token {token:X4} at " +
                    $"{cursor:X4}")
            };

            int depthAfter;
            if (token is 0x795B or 0x7963)
            {
                cells += 1;
                depthAfter = cells;
            }
            else if (token is 0x787E or 0x7AAF)
            {
                if (cells < 2)
                    throw new InvalidDataException(
                        $"Lamp-pattern stack underflow at {cursor:X4}: token {token:X4} needs " +
                        "two input cells");
                cells -= 1;
                depthAfter = cells;
            }
            else if (token == SharedCallToken)
            {
                if (cells != 3)
                    throw new InvalidDataException(
                        $"Shared lamp call at {cursor:X4} requires depth 3; found {cells}");
                cells -= 2;
                depthAfter = cells;
            }
            else
            {
                if (cells != 1)
                    throw new InvalidDataException(
                        $"Lamp-pattern return at {cursor:X4} leaves depth {cells}; expected 1");
                depthAfter = cells;
            }

            if (token == 0x792F)
            {
                if (cursor + nodeLength != bodyEndExclusive)
                {
                    ushort[] unreachable = CollectTokenAddresses(
                        body, offset + nodeLength, cursor + nodeLength, bodyEndExclusive);
                    throw new InvalidDataException(
                        $"Lamp-pattern reachability failed: returnAddress={cursor:X4}; " +
                        $"unreachableAddresses=[{string.Join(",", unreachable.Select(
                            address => address.ToString("X4")))}]; bytes after an earlier " +
                        "return are unreachable");
                }
                returned = true;
            }

            ushort? sharedBodyAddress = token == SharedCallToken
                ? SharedBodyAddress
                : null;
            ushort? servicePointerAddress = token == SharedCallToken
                ? ServicePointerAddress
                : null;
            ushort? servicePointerValue = token == SharedCallToken
                ? ServicePointerValue
                : null;

            nodes.Add(new LampPatternNode(
                nodes.Count,
                (ushort)cursor,
                token,
                binding.Operation,
                Convert.ToHexString(body.Slice(offset, nodeLength)),
                operandKind,
                operandAddress,
                operandValue,
                binding.Handler,
                sharedBodyAddress,
                servicePointerAddress,
                servicePointerValue,
                stackDelta,
                depthAfter,
                uDelta + stackDelta,
                StaticPhaseClassification));

            cursor += nodeLength;
            offset += nodeLength;
            uDelta += stackDelta;
        }

        if (!returned)
            throw new InvalidDataException(
                "Lamp-pattern body is missing its final 792F return token");
        if (uDelta != 0)
            throw new InvalidDataException(
                $"Lamp-pattern body net U delta is {uDelta}; the reviewed contract requires 0");
        if (cells != 1)
            throw new InvalidDataException(
                $"Lamp-pattern body exit depth is {cells}; the reviewed contract requires 1");
        return nodes.ToArray();
    }

    private static ushort[] CollectTokenAddresses(
        ReadOnlySpan<byte> body, int offset, int cursor, int bodyEndExclusive)
    {
        var addresses = new List<ushort>();
        while (offset < body.Length)
        {
            if (offset + 2 > body.Length)
                break;
            addresses.Add(checked((ushort)cursor));
            ushort token = (ushort)((body[offset] << 8) | body[offset + 1]);
            var binding = TokenTable.SingleOrDefault(entry => entry.Token == token);
            if (binding.Token != token)
                break;
            int length = 2 + binding.OperandBytes;
            if (offset + length > body.Length || cursor + length > bodyEndExclusive)
                break;
            offset += length;
            cursor += length;
        }
        return addresses.ToArray();
    }

    internal static void ValidateNodes(
        ReadOnlySpan<byte> rom, ReadOnlySpan<byte> payload, LampPatternNode[] nodes)
    {
        if (nodes.Length != NodeCount)
            throw new InvalidDataException(
                $"Lamp-pattern decoded {nodes.Length} nodes; expected {NodeCount}");

        ushort[] expectedAddresses =
        {
            0x1012, 0x1016, 0x1018, 0x101C, 0x101E, 0x1021, 0x1024, 0x1026
        };
        ushort[] expectedTokens =
        {
            0x795B, 0x787E, 0x795B, 0x7AAF, 0x7963, 0x7963, 0x9C44, 0x792F
        };
        ushort?[] expectedOperandAddresses =
        {
            0x1014, null, 0x101A, null, 0x1020, 0x1023, null, null
        };
        ushort?[] expectedOperandValues =
        {
            0xFF80, null, 0xFF80, null, 0x0000, 0x008F, null, null
        };
        LampPatternOperandKind[] expectedKinds =
        {
            LampPatternOperandKind.Word,
            LampPatternOperandKind.None,
            LampPatternOperandKind.Word,
            LampPatternOperandKind.None,
            LampPatternOperandKind.Byte,
            LampPatternOperandKind.Byte,
            LampPatternOperandKind.ServiceOwnedNoCallerOperand,
            LampPatternOperandKind.None
        };
        ushort[] expectedHandlers =
        {
            0x795D, 0x7880, 0x795D, 0x7AB1, 0x7965, 0x7965, 0x9B15, 0x7931
        };

        int cursor = BodyStart;
        int wordOperands = 0;
        int byteOperands = 0;
        for (int index = 0; index < nodes.Length; index++)
        {
            LampPatternNode node = nodes[index];
            if (node.Index != index ||
                node.Address != expectedAddresses[index] ||
                node.Token != expectedTokens[index] ||
                node.HandlerAddress != expectedHandlers[index] ||
                node.OperandKind != expectedKinds[index])
                throw new InvalidDataException(
                    $"Lamp-pattern node {index} does not match the reviewed body");
            if (node.Address != cursor)
                throw new InvalidDataException(
                    $"Lamp-pattern node {index} at {node.Address:X4} does not follow cursor " +
                    $"{cursor:X4}");
            if (node.OperandAddress != expectedOperandAddresses[index] ||
                node.OperandValue != expectedOperandValues[index])
                throw new InvalidDataException(
                    $"Lamp-pattern node {index} operand differs from the reviewed body");
            if (node.OperandKind == LampPatternOperandKind.Word)
                wordOperands++;
            if (node.OperandKind == LampPatternOperandKind.Byte)
                byteOperands++;
            byte[] bytes = Convert.FromHexString(node.BytesHex);
            if (!payload.Slice(node.Address - HeaderAddress, bytes.Length)
                    .SequenceEqual(bytes))
                throw new InvalidDataException(
                    $"Lamp-pattern node {index} bytes differ from the payload");
            cursor += bytes.Length;
        }

        if (wordOperands != WordOperandCount)
            throw new InvalidDataException(
                $"Lamp-pattern word operand count is {wordOperands}; expected " +
                $"{WordOperandCount}");
        if (byteOperands != ByteOperandCount)
            throw new InvalidDataException(
                $"Lamp-pattern byte operand count is {byteOperands}; expected " +
                $"{ByteOperandCount}");
        if (cursor != BodyEndExclusive)
            throw new InvalidDataException(
                $"Lamp-pattern body ends at {cursor:X4}; expected {BodyEndExclusive:X4}");

        LampPatternNode shared = nodes[6];
        if (shared.Token != SharedCallToken ||
            shared.HandlerAddress != SharedCallHandlerAddress ||
            shared.OperandKind != LampPatternOperandKind.ServiceOwnedNoCallerOperand ||
            shared.SharedBodyAddress != SharedBodyAddress ||
            shared.ServicePointerAddress != ServicePointerAddress ||
            shared.ServicePointerValue != ServicePointerValue)
            throw new InvalidDataException(
                "Lamp-pattern shared-call node is not the reviewed 9C44 -> 9B15/9B18 " +
                "service boundary");
        if (shared.Address + 2 != nodes[7].Address)
            throw new InvalidDataException(
                "Lamp-pattern shared call must be exactly two caller bytes before the return");
        if (shared.HandlerAddress == shared.Token + 2)
            throw new InvalidDataException(
                "Lamp-pattern shared call incorrectly assumed handler=token+2");
        if (nodes[^1].Token != 0x792F || nodes[^1].Address != 0x1026)
            throw new InvalidDataException(
                "Lamp-pattern word does not end with exactly one 792F return at 1026");

        if (ReadWord(rom, ServiceCellAddress) != SharedCallHandlerAddress ||
            ReadWord(rom, ServicePointerAddress) != ServicePointerValue)
            throw new InvalidDataException(
                "Original ROM service cell no longer matches the reviewed shared-call boundary");
    }

    internal static LampPatternStaticContract BuildStaticContract(
        LampPatternNode[] nodes,
        IReadOnlyList<LampPatternBridgeEvent> bridgeEvents)
    {
        if (nodes is null || nodes.Length != NodeCount)
            throw new InvalidDataException(
                "Lamp-pattern static contract requires the eight reviewed nodes");
        if (bridgeEvents is null || bridgeEvents.Count != 14)
            throw new InvalidDataException(
                "Lamp-pattern bridge chronology must contain the fourteen reviewed " +
                "instruction-boundary events");

        string[] bridgePhases = ExpectedPhaseOrder
            .SkipWhile(phase => phase != "bridge-entry")
            .Take(14)
            .ToArray();
        if (!bridgeEvents.Select(evt => evt.Phase).SequenceEqual(bridgePhases))
            throw new InvalidDataException(
                "Lamp-pattern bridge chronology phases differ from the reviewed order");

        var steps = new List<LampPatternStackStep>(ExpectedPhaseOrder.Length);
        int u = CallerEntryU;
        int s = CallerEntryS;
        void Add(string phase)
        {
            steps.Add(new LampPatternStackStep(
                phase, u, s, u - CallerEntryU, s - CallerEntryS, StackClassification));
        }

        Add("caller-dispatch");
        Add("header-trampoline-entry");
        s -= 2;
        Add("body-prefetch-0");
        for (int index = 0; index < 6; index++)
        {
            Add($"handler-{index}");
            u += nodes[index].StackDeltaBytes;
            Add($"body-prefetch-{index + 1}");
        }

        Add("shared-handler-entry");
        s -= 2;
        Add("service-trampoline-jrs-entry");
        u -= 2;
        Add("service-trampoline-pshu");
        Add("shared-body-entry");
        Add("shared-after-fetch-word");
        Add("shared-after-rotate");
        u += 2;
        Add("shared-after-add");
        Add("shared-after-fetch-byte");
        Add("shared-after-swap");

        foreach (LampPatternBridgeEvent bridgeEvent in bridgeEvents)
        {
            u += bridgeEvent.UDelta;
            s += bridgeEvent.SDelta;
            Add(bridgeEvent.Phase);
        }

        Add("shared-prefetch-return");
        Add("shared-return-handler");
        s += 2;
        Add("shared-returned-to-1026");
        Add("outer-return-handler");
        s += 2;
        Add("outer-returned-to-9F16");

        if (!steps.Select(step => step.Phase).SequenceEqual(ExpectedPhaseOrder))
            throw new InvalidDataException(
                "Lamp-pattern stack model phase order differs from the reviewed order");
        if (u != CallerEntryU || s != CallerEntryS)
            throw new InvalidDataException(
                $"Lamp-pattern stack model does not balance: U={u:X4} S={s:X4}");

        var vectors = new LampPatternVector[ExpectedVectors.Length];
        for (int index = 0; index < vectors.Length; index++)
        {
            ushort input = ExpectedVectors[index].Input;
            ushort result = (ushort)(((input + 0xFF80) & 0xFFFF) ^ 0xFF80);
            vectors[index] = new LampPatternVector(input, result);
            if (result != ExpectedVectors[index].Result)
                throw new InvalidDataException(
                    $"Lamp-pattern prefix vector for {input:X4} is {result:X4}; expected " +
                    $"{ExpectedVectors[index].Result:X4}");
        }

        int exitDepth = nodes[^1].DepthAfter;
        var contract = new LampPatternStaticContract(
            CallerEntryU,
            CallerEntryS,
            1,
            exitDepth,
            0,
            0,
            DeepestNativeS,
            DeepestNativeS - CallerEntryS,
            SharedSavedCursor,
            OuterSavedCursor,
            true,
            ResultPreservationText,
            ServiceClobbersText,
            StackClassification,
            Array.AsReadOnly(vectors),
            Array.AsReadOnly(steps.ToArray()));
        ValidateStaticContract(contract);
        return contract;
    }

    internal static void ValidateStaticContract(LampPatternStaticContract contract)
    {
        if (contract.EntryU != CallerEntryU || contract.EntryS != CallerEntryS ||
            contract.EntryDepth != 1 || contract.ExitDepth != 1 ||
            contract.BodyUNet != 0 || contract.WholeCallSNet != 0 ||
            contract.DeepestS != DeepestNativeS ||
            contract.DeepestSRelativeToEntry != DeepestNativeS - CallerEntryS ||
            contract.SharedSavedCursor != SharedSavedCursor ||
            contract.OuterSavedCursor != OuterSavedCursor ||
            !contract.NestedCall ||
            !string.Equals(contract.Classification, StackClassification,
                StringComparison.Ordinal))
            throw new InvalidDataException(
                "Lamp-pattern static stack contract differs from the reviewed relative model");
        if (contract.StackSteps.Count != ExpectedPhaseOrder.Length)
            throw new InvalidDataException(
                $"Lamp-pattern static stack contract has {contract.StackSteps.Count} steps; " +
                $"the reviewed relative model requires {ExpectedPhaseOrder.Length}");
        for (int index = 0; index < contract.StackSteps.Count; index++)
        {
            LampPatternStackStep actual = contract.StackSteps[index];
            string phase = ExpectedPhaseOrder[index];
            if (!string.Equals(actual.Phase, phase, StringComparison.Ordinal) ||
                actual.URelativeToEntry != actual.U - CallerEntryU ||
                actual.SRelativeToEntry != actual.S - CallerEntryS ||
                !string.Equals(actual.Classification, StackClassification,
                    StringComparison.Ordinal))
                throw new InvalidDataException(
                    $"Lamp-pattern stack step {index} ({actual.Phase}) differs from the " +
                    "reviewed relative model");
        }

        void Expect(string phase, int u, int s)
        {
            LampPatternStackStep step = contract.StackSteps.Single(
                item => string.Equals(item.Phase, phase, StringComparison.Ordinal));
            if (step.U != u || step.S != s)
                throw new InvalidDataException(
                    $"Lamp-pattern stack step {phase} is U={step.U:X4} S={step.S:X4}; " +
                    $"expected U={u:X4} S={s:X4}");
        }

        Expect("caller-dispatch", CallerEntryU, CallerEntryS);
        Expect("header-trampoline-entry", CallerEntryU, CallerEntryS);
        Expect("body-prefetch-0", CallerEntryU, OuterBodyEntryS);
        Expect("handler-0", 0x066E, OuterBodyEntryS);
        Expect("body-prefetch-1", 0x066C, OuterBodyEntryS);
        Expect("handler-1", 0x066C, OuterBodyEntryS);
        Expect("body-prefetch-2", 0x066E, OuterBodyEntryS);
        Expect("handler-2", 0x066E, OuterBodyEntryS);
        Expect("body-prefetch-3", 0x066C, OuterBodyEntryS);
        Expect("handler-3", 0x066C, OuterBodyEntryS);
        Expect("body-prefetch-4", 0x066E, OuterBodyEntryS);
        Expect("handler-4", 0x066E, OuterBodyEntryS);
        Expect("body-prefetch-5", 0x066C, OuterBodyEntryS);
        Expect("handler-5", 0x066C, OuterBodyEntryS);
        Expect("body-prefetch-6", 0x066A, OuterBodyEntryS);
        Expect("shared-handler-entry", 0x066A, OuterBodyEntryS);
        Expect("service-trampoline-jrs-entry", 0x066A, SharedBodyEntryS);
        Expect("service-trampoline-pshu", 0x0668, SharedBodyEntryS);
        Expect("shared-body-entry", 0x0668, SharedBodyEntryS);
        Expect("shared-after-fetch-word", 0x0668, SharedBodyEntryS);
        Expect("shared-after-rotate", 0x0668, SharedBodyEntryS);
        Expect("shared-after-add", 0x066A, SharedBodyEntryS);
        Expect("shared-after-fetch-byte", 0x066A, SharedBodyEntryS);
        Expect("shared-after-swap", 0x066A, SharedBodyEntryS);
        Expect("bridge-entry", 0x066A, SharedBodyEntryS);
        Expect("bridge-pulu-pattern", 0x066C, SharedBodyEntryS);
        Expect("bridge-load-index", 0x066C, SharedBodyEntryS);
        Expect("bridge-discard-index", 0x066C, SharedBodyEntryS);
        Expect("bridge-branch-continuation", 0x066E, SharedBodyEntryS);
        Expect("bridge-saves-y", 0x066E, 0x0792);
        Expect("bridge-jsr-entry", 0x066E, 0x0790);
        Expect("native-prologue-save-regs", 0x066E, 0x078C);
        Expect("native-prologue-save-mask", 0x066E, 0x078B);
        Expect("native-prologue-deepest", 0x066E, DeepestNativeS);
        Expect("native-epilogue-puls-cc", 0x066E, 0x078B);
        Expect("native-epilogue-puls-a", 0x066E, 0x078C);
        Expect("native-return", 0x066E, 0x0792);
        Expect("bridge-restores-y", 0x066E, SharedBodyEntryS);
        Expect("shared-prefetch-return", 0x066E, SharedBodyEntryS);
        Expect("shared-return-handler", 0x066E, SharedBodyEntryS);
        Expect("shared-returned-to-1026", 0x066E, OuterBodyEntryS);
        Expect("outer-return-handler", 0x066E, OuterBodyEntryS);
        Expect("outer-returned-to-9F16", 0x066E, CallerEntryS);
        if (contract.StackSteps.Any(step => step.S == 0x0778))
            throw new InvalidDataException(
                "Lamp-pattern stack model transplanted the old B951 S=0778 absolute value");

        if (contract.Vectors.Count != ExpectedVectors.Length)
            throw new InvalidDataException(
                "Lamp-pattern static vectors do not contain the five reviewed inputs");
        for (int index = 0; index < contract.Vectors.Count; index++)
        {
            if (contract.Vectors[index] != ExpectedVectors[index])
                throw new InvalidDataException(
                    $"Lamp-pattern static vector at {ExpectedVectors[index].Input:X4} differs " +
                    "from the reviewed 9ED9 result preservation");
        }
        if (!contract.ResultPreservation.Contains("9ED9", StringComparison.Ordinal) ||
            !contract.ServiceClobbers.Contains("A", StringComparison.Ordinal) ||
            !contract.ServiceClobbers.Contains("CC", StringComparison.Ordinal) ||
            contract.ServiceClobbers.Contains("preserved A", StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                "Lamp-pattern contract overstates register preservation or omits the 9ED9 " +
                "result statement");
    }

    internal static void ValidatePredictedLampEffect(ReadOnlySpan<byte> rom)
    {
        if (GridIndex < 0 || GridIndex >= TableLength)
            throw new InvalidDataException(
                $"Lamp-pattern grid index {GridIndex} is outside the 48-cell table");
        int row = GridIndex / GridCellSize;
        int column = 15 - row;
        if (column < 0 || column > 15)
            throw new InvalidDataException(
                $"Lamp-pattern predicted column {column} is outside the frame buffer");
        byte logicalId = rom[TableAddress + GridIndex];
        int bit = logicalId & 7;
        byte mask = (byte)(1 << bit);
        if (mask != PredictedMask)
            throw new InvalidDataException(
                $"Lamp-pattern predicted mask for index {GridIndex} is {mask:X2}; expected " +
                $"{PredictedMask:X2}");
        for (int frame = 0; frame < 4; frame++)
        {
            int address = 0x0100 + frame * 0x10 + column;
            if (address != PredictedFrameAddresses[frame])
                throw new InvalidDataException(
                    $"Lamp-pattern predicted frame {frame} address is {address:X4}; expected " +
                    $"{PredictedFrameAddresses[frame]:X4}");
        }
        if ((PatternOperand & 0x0F) != 0x0F)
            throw new InvalidDataException(
                "Lamp-pattern byte literal does not set all four low-nibble frame bits");
    }

    internal static void ValidatePreservedOutput(
        ReadOnlySpan<byte> original, ReadOnlySpan<byte> output)
    {
        if (original.Length != output.Length)
            throw new InvalidDataException("Image lengths differ");
        for (int offset = 0; offset < original.Length; offset++)
        {
            bool allowed = (offset >= AllocationStart && offset <= AllocationEndInclusive) ||
                           (offset >= CallerTokenAddress && offset < CallerTokenAddress + 2) ||
                           (offset >= VmIlIntegrity.SumOffset &&
                            offset <= VmIlIntegrity.RotateSubXorBOffset);
            if (!allowed && output[offset] != original[offset])
                throw new InvalidDataException(
                    $"Lamp-pattern output changed preserved byte {offset:X4}");
        }

        EnsureEqual(original, output, LeftGuardStart, LeftGuardEnd, "left guard");
        EnsureEqual(original, output, 0x1000, 0x1003, "protected cells");
        EnsureEqual(original, output, RightGuardStart, RightGuardEnd, "right guard");
        EnsureEqual(original, output, IntegrityStart, 0x140F, "integrity neighbour");
        EnsureEqual(original, output, 0x9ED7, 0x9EE6,
            "original 9ED7 header and 9ED9 body");
        EnsureEqual(original, output, 0x1028, 0x13EF,
            "unallocated extension bytes");
        EnsureEqual(original, output, 0x719B, 0x719B, "outer gate");
        EnsureEqual(original, output, 0x7927, 0x792E, "runtime dispatch template");
        EnsureEqual(original, output, 0x7963, 0x796B, "byte literal cell/handler");
        EnsureEqual(original, output, 0x796E, 0x7978, "shared-body trampoline");
        EnsureEqual(original, output, 0x8050, 0x8053, "bridge cell");
        EnsureEqual(original, output, 0x7791, 0x77A3, "bridge entry");
        EnsureEqual(original, output, 0x777A, 0x778C, "bridge continuation");
        EnsureEqual(original, output, 0x9B15, 0x9B25, "shared service");
        EnsureEqual(original, output, 0x9C44, 0x9C47, "shared service cell");
        EnsureEqual(original, output, 0x49C5, 0x4A24, "native lamp service");
        EnsureEqual(original, output, 0x72BF, 0x72EE, "lamp table");
        EnsureEqual(original, output, 0x9F10, 0x9F13,
            "caller definition header/body prefix");
        EnsureEqual(original, output, 0x9F16, 0x9F17, "caller successor token");
        EnsureEqual(original, output, 0x9F18, 0x9F1D,
            "caller bytes after the successor");
        EnsureEqual(original, output, 0x9F3B, 0x9F40, "parent caller context");

        if (output[0x1014] != 0xFF || output[0x101A] != 0xFF)
            throw new InvalidDataException(
                "Lamp-pattern output changed the original FF bytes at 1014/101A");
    }

    private static void ValidateCallerBeforePatch(
        ReadOnlySpan<byte> original, ReadOnlySpan<byte> unrepaired)
    {
        for (int offset = 0; offset < original.Length; offset++)
        {
            if (offset >= AllocationStart && offset <= AllocationEndInclusive)
                continue;
            if (unrepaired[offset] != original[offset])
                throw new InvalidDataException(
                    $"Unrepaired lamp-pattern word changed byte {offset:X4} outside the " +
                    "allocation");
        }
        if (!unrepaired.Slice(CallerTokenAddress, 2)
                .SequenceEqual(original.Slice(CallerTokenAddress, 2)))
            throw new InvalidDataException(
                "Unrepaired lamp-pattern word pre-modified the caller token before the " +
                "checked patch");
    }

    private static void EnsureRomEqual(
        ReadOnlySpan<byte> rom, int address, string expectedHex, string label)
    {
        byte[] expected = Convert.FromHexString(expectedHex);
        if (address < 0 || address + expected.Length > rom.Length)
            throw new InvalidDataException($"ROM span for {label} is outside the image");
        if (!rom.Slice(address, expected.Length).SequenceEqual(expected))
            throw new InvalidDataException(
                $"ROM bytes for {label} at {address:X4}-" +
                $"{address + expected.Length - 1:X4} differ from the reviewed service");
    }

    private static void EnsureEqual(
        ReadOnlySpan<byte> original,
        ReadOnlySpan<byte> candidate,
        int start,
        int end,
        string label)
    {
        if (end >= candidate.Length)
            throw new InvalidDataException(
                $"Candidate image is too short to inspect {label}");
        if (!original.Slice(start, end - start + 1)
                .SequenceEqual(candidate.Slice(start, end - start + 1)))
            throw new InvalidDataException(
                $"Lamp-pattern output changed preserved {label} at {start:X4}-{end:X4}");
    }

    internal static int[] ChangedOffsets(
        ReadOnlySpan<byte> before, ReadOnlySpan<byte> after)
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

    private static ushort ReadWord(ReadOnlySpan<byte> image, int address) =>
        (ushort)((image[address] << 8) | image[address + 1]);

    private static string Sha1(ReadOnlySpan<byte> bytes) =>
        Convert.ToHexString(SHA1.HashData(bytes));

    private static string Sha256(ReadOnlySpan<byte> bytes) =>
        Convert.ToHexString(SHA256.HashData(bytes));
}

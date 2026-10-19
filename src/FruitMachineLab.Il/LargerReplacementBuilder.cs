using System.Collections.ObjectModel;
using System.Security.Cryptography;

namespace FruitMachineLab.Il;

public sealed record LargerReplacementNode(
    int Index,
    ushort Address,
    ushort Token,
    string Operation,
    string BytesHex,
    ushort? OperandAddress,
    ushort? OperandValue,
    ushort HandlerAddress,
    int StackDeltaBytes,
    int DepthAfter);

public sealed record LargerReplacementVector(
    ushort Input,
    ushort CopiedValue,
    ushort CalleeExit,
    ushort AfterSuccessor);

public sealed record LargerReplacementStaticContract(
    int EntryDepth,
    int ExitDepth,
    int BodyUNet,
    int TrampolineSDelta,
    int ReturnHandlerSDelta,
    int WholeCallSNet,
    bool NestedCall,
    string Classification,
    IReadOnlyList<LargerReplacementVector> Vectors);

public sealed record LargerReplacementProvenance(
    string ProposalId,
    string ContractTaskId,
    string OriginalDefinitionListingPath,
    string OriginalDefinitionListingSha256,
    string OriginalBodyHex,
    string CallerListingPath,
    string ParentListingPath,
    string Classification);

public sealed record LargerReplacementByteChange(int Offset, byte Before, byte After);

public sealed class LargerReplacementBuildResult
{
    private readonly byte[] _outputImage;
    private readonly byte[] _unrepairedImage;
    private readonly byte[] _payloadBytes;
    private readonly ReadOnlyCollection<int> _unrepairedChangedOffsets;
    private readonly ReadOnlyCollection<int> _changedOffsets;
    private readonly ReadOnlyCollection<int> _repairChangedOffsets;
    private readonly ReadOnlyCollection<LargerReplacementByteChange> _byteChanges;
    private readonly ReadOnlyCollection<LargerReplacementNode> _nodes;
    private readonly VmIlIntegrityReport _integrityReport;

    internal LargerReplacementBuildResult(
        byte[] outputImage,
        byte[] unrepairedImage,
        byte[] payloadBytes,
        string originalRomSha1,
        string originalRomSha256,
        string unrepairedImageSha1,
        string unrepairedImageSha256,
        string outputImageSha1,
        string outputImageSha256,
        LargerReplacementNode[] nodes,
        LargerReplacementStaticContract staticContract,
        int[] unrepairedChangedOffsets,
        int[] changedOffsets,
        int[] repairChangedOffsets,
        LargerReplacementByteChange[] byteChanges,
        VmIlIntegrityReport integrityReport,
        LargerReplacementSourceMap sourceMap,
        LargerReplacementProvenance provenance)
    {
        _outputImage = (byte[])outputImage.Clone();
        _unrepairedImage = (byte[])unrepairedImage.Clone();
        _payloadBytes = (byte[])payloadBytes.Clone();
        _unrepairedChangedOffsets =
            Array.AsReadOnly((int[])unrepairedChangedOffsets.Clone());
        _changedOffsets = Array.AsReadOnly((int[])changedOffsets.Clone());
        _repairChangedOffsets = Array.AsReadOnly((int[])repairChangedOffsets.Clone());
        _byteChanges =
            Array.AsReadOnly((LargerReplacementByteChange[])byteChanges.Clone());
        _nodes = Array.AsReadOnly((LargerReplacementNode[])nodes.Clone());
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

    public IReadOnlyList<LargerReplacementNode> Nodes => _nodes;

    public IReadOnlyList<int> UnrepairedChangedOffsets => _unrepairedChangedOffsets;

    public IReadOnlyList<int> ChangedOffsets => _changedOffsets;

    public IReadOnlyList<int> RepairChangedOffsets => _repairChangedOffsets;

    public IReadOnlyList<LargerReplacementByteChange> ByteChanges => _byteChanges;

    public LargerReplacementStaticContract StaticContract { get; }

    public VmIlIntegrityReport IntegrityReport => CopyIntegrityReport(_integrityReport);

    public LargerReplacementSourceMap SourceMap { get; }

    public LargerReplacementProvenance Provenance { get; }

    public string Status => LargerReplacementBuilder.StatusText;

    private static VmIlIntegrityReport CopyIntegrityReport(VmIlIntegrityReport report) =>
        report with
        {
            Fields = report.Fields.ToArray(),
            UnrepairedChangedOffsets = (int[])report.UnrepairedChangedOffsets.Clone(),
            RepairedChangedOffsets = (int[])report.RepairedChangedOffsets.Clone(),
            RepairChangedOffsets = (int[])report.RepairChangedOffsets.Clone()
        };
}

public static class LargerReplacementBuilder
{
    public const ushort HeaderAddress = 0x1010;
    public const ushort HeaderValue = 0x00F8;
    public const string HeaderHex = "00F8";
    public const ushort BodyStart = 0x1012;
    public const int BodyEndExclusive = 0x1026;
    public const int AllocationStart = 0x1010;
    public const int AllocationEndInclusive = 0x1025;
    public const int AllocationLength = 22;
    public const string BodyHex = "795BFF80787E795BFF807AAF795B0001787E792F";
    public const string PayloadHex = HeaderHex + BodyHex;
    public const int NodeCount = 7;
    public const int InlineOperandCount = 3;

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
    public const string RuntimeDispatchTemplateHex = "34203184AEA16E91";
    public const string CallerBodyHex = "77F69ED775A97B7D7B3D792F";
    public const ushort CallerHeaderAddress = 0x9F10;
    public const ushort CallerBodyStart = 0x9F12;
    public const int CallerBodyEndExclusive = 0x9F1E;
    public const ushort ParentBodyStart = 0x9F3B;
    public const string ParentBodyHex = "817D9F10792F";

    public const string OriginalFieldsHex = "3E761E2605";
    public const string ReplacementFieldsHex = "E93F3C61B5";
    public const string ExpectedOutputSha1 = "7D81C9828A8A8C882861151E84B676AE05D272BF";
    public const string ExpectedOutputSha256 =
        "F693D70A73F1C12857CD64CA9DB9D68DE9BBC1888101ABC283FA2752C094B523";

    public const string ProposalId = "larger-replacement-9ed9-plus-one";
    public const string ContractTaskId = "il-larger-contract-correction-49";
    public const string ProvenanceText =
        "Statically compiled larger replacement for the corrected task49 contract. Header " +
        "1010 contains 00F8 and body 1012-1025 contains the certified 9ED9 prefix followed " +
        "by push 0001, add and one final return. Only the naturally cited caller token 9ED7 " +
        "at 9F14 is replaced by 1010. Original 9ED7/9ED9, other caller bytes, guards, " +
        "protected cells and the 1400 neighbour are preserved. No MAME execution, natural " +
        "new-body behaviour, gameplay or hardware compatibility is claimed.";
    public const string StatusText =
        "STATIC COMPILED LARGER REPLACEMENT ONLY: the 22-byte extension allocation and one " +
        "same-size caller token were emitted in memory and the ordered integrity fields were " +
        "repaired. This is not execution proof, natural boot acceptance or hardware compatibility.";
    public const string StaticPhaseClassification = "static_prediction_not_execution";

    private static readonly (ushort Token, ushort Handler, string HandlerHex)[] Handlers =
    {
        (0x795B, 0x795D, "ECA136060EFC"),
        (0x787E, 0x7880, "3706E3C4EDC40EFC"),
        (0x7AAF, 0x7AB1, "3706A8C4E841EDC40EFC"),
        (0x792F, 0x7931, "35200EFC")
    };

    private static readonly int[] UnrepairedChangedOffsets =
    {
        0x1010, 0x1011, 0x1012, 0x1013, 0x1015, 0x1016, 0x1017, 0x1018,
        0x1019, 0x101B, 0x101C, 0x101D, 0x101E, 0x101F, 0x1020, 0x1021,
        0x1022, 0x1023, 0x1024, 0x1025, 0x9F14, 0x9F15
    };

    private static readonly int[] FinalChangedOffsets =
    {
        0x1010, 0x1011, 0x1012, 0x1013, 0x1015, 0x1016, 0x1017, 0x1018,
        0x1019, 0x101B, 0x101C, 0x101D, 0x101E, 0x101F, 0x1020, 0x1021,
        0x1022, 0x1023, 0x1024, 0x1025, 0x9F14, 0x9F15,
        0xFFD1, 0xFFD2, 0xFFD3, 0xFFD4, 0xFFD5
    };

    private static readonly LargerReplacementVector[] ExpectedVectors =
    {
        new(0x0000, 0x0000, 0x0001, 0x0000),
        new(0x0001, 0x0001, 0x0002, 0x0000),
        new(0x7FFF, 0x80FF, 0x8100, 0xFFFF),
        new(0x8000, 0x8000, 0x8001, 0xFFFF),
        new(0xFFFF, 0x00FF, 0x0100, 0x0000)
    };

    public static LargerReplacementBuildResult Build(ReadOnlySpan<byte> originalRom)
    {
        VmIlDefinition originalDefinition = NineEdNineDecoder.Decode(originalRom);
        ValidateCertifiedSource(originalRom, originalDefinition);

        byte[] payload = Convert.FromHexString(PayloadHex);
        ValidateComposedPayload(payload);
        LargerReplacementNode[] nodes = AnalyzeFlatBody(
            payload.AsSpan(2), BodyStart, BodyEndExclusive);
        ValidateNodes(originalRom, payload, nodes);
        LargerReplacementStaticContract staticContract = BuildStaticContract(nodes);
        ValidateStaticVectors(staticContract);

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
                "Allocator did not place the larger replacement at 1010-1025");
        for (int offset = AllocationStart; offset <= AllocationEndInclusive; offset++)
        {
            if (originalRom[offset] != 0xFF)
                throw new InvalidDataException(
                    $"Reviewed larger-replacement allocation byte at {offset:X4} is " +
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
                "Emitted extension allocation does not contain the larger-replacement payload");
        if (!emission.ChangedOffsets.SequenceEqual(
                UnrepairedChangedOffsets.Take(20).ToArray()))
            throw new InvalidDataException(
                "Extension emission did not realize exactly the 20 reviewed payload changes");
        if (!emission.OutputImage.Slice(VmIlIntegrity.RangeStart, 0x10000 - 0x1400)
                .SequenceEqual(originalRom.Slice(
                    VmIlIntegrity.RangeStart, 0x10000 - 0x1400)))
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
        if (!unrepairedDiff.SequenceEqual(UnrepairedChangedOffsets))
            throw new InvalidDataException(
                "Unrepaired larger-replacement diff is not exactly 20 extension changes plus " +
                "the two caller-token bytes");
        if (unrepaired[0x1014] != 0xFF || unrepaired[0x101A] != 0xFF)
            throw new InvalidDataException(
                "Unrepaired larger replacement changed the original FF bytes at 1014/101A");

        var patch = new VmIlLargerReplacementPatchSpec(
            AllocationStart,
            Enumerable.Repeat((byte)0xFF, AllocationLength).ToArray(),
            payload,
            CallerTokenAddress,
            new byte[] { 0x9E, 0xD7 },
            new byte[] { 0x10, 0x10 });
        VmIlIntegrityResult integrity =
            VmIlIntegrity.RepairLargerReplacement(originalRom, unrepaired, patch);

        string outputSha1 = Sha1(integrity.RepairedImage);
        string outputSha256 = Sha256(integrity.RepairedImage);
        if (!string.Equals(outputSha1, ExpectedOutputSha1, StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(outputSha256, ExpectedOutputSha256,
                StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                $"Larger-replacement output hashes are SHA1 {outputSha1} / SHA256 " +
                $"{outputSha256}; the reviewed contract requires {ExpectedOutputSha1} / " +
                $"{ExpectedOutputSha256}");
        if (!string.Equals(
                integrity.Report.RepairedStoredFieldsHex, ReplacementFieldsHex,
                StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Larger-replacement integrity fields are " +
                $"{integrity.Report.RepairedStoredFieldsHex}; the reviewed contract requires " +
                $"{ReplacementFieldsHex}");

        int[] finalDiff = ChangedOffsets(originalRom, integrity.RepairedImage);
        if (finalDiff.Length != 27 || !finalDiff.SequenceEqual(FinalChangedOffsets))
            throw new InvalidDataException(
                "Final larger-replacement diff is not exactly the reviewed 27 changed offsets");
        if (!integrity.Report.UnrepairedChangedOffsets.SequenceEqual(
                UnrepairedChangedOffsets) ||
            !integrity.Report.RepairedChangedOffsets.SequenceEqual(FinalChangedOffsets))
            throw new InvalidDataException(
                "Larger-replacement integrity report diff does not match the reviewed contract");
        if (!integrity.Report.RepairChangedOffsets.SequenceEqual(
                new[] { 0xFFD1, 0xFFD2, 0xFFD3, 0xFFD4, 0xFFD5 }))
            throw new InvalidDataException(
                "Larger-replacement repair changed bytes outside FFD1-FFD5");

        ValidatePreservedBytes(originalRom, unrepaired, integrity.RepairedImage);

        var changes = new LargerReplacementByteChange[finalDiff.Length];
        for (int index = 0; index < finalDiff.Length; index++)
        {
            int offset = finalDiff[index];
            changes[index] = new LargerReplacementByteChange(
                offset, originalRom[offset], integrity.RepairedImage[offset]);
        }

        var provenance = new LargerReplacementProvenance(
            ProposalId,
            ContractTaskId,
            originalDefinition.Provenance.ListingPath,
            originalDefinition.Provenance.ListingSha256,
            OriginalBodyHex,
            "evidence/mpu4/VM-SCRIPTS/9F12.txt",
            "evidence/mpu4/VM-SCRIPTS/9F3B.txt",
            "static_compiled_larger_replacement; original_rom_bytes; corrected_task49_contract; " +
            "prior_caller_reachability_only");

        LargerReplacementSourceMap map = LargerReplacementSourceMap.CreateForBuild(
            originalRom,
            integrity.RepairedImage,
            nodes,
            staticContract,
            provenance);

        return new LargerReplacementBuildResult(
            integrity.RepairedImage,
            unrepaired,
            payload,
            Sha1(originalRom),
            Sha256(originalRom),
            Sha1(unrepaired),
            Sha256(unrepaired),
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

    internal static void ValidateComposedPayload(ReadOnlySpan<byte> payload)
    {
        if (payload.Length != AllocationLength)
            throw new InvalidDataException(
                $"Larger-replacement payload length {payload.Length} differs from the reviewed " +
                $"{AllocationLength}-byte allocation");
        if (!payload.Slice(0, 2).SequenceEqual(Convert.FromHexString(HeaderHex)))
            throw new InvalidDataException(
                "Larger-replacement header is not the reviewed 00F8 value");
        if (!payload.Slice(2).SequenceEqual(Convert.FromHexString(BodyHex)))
            throw new InvalidDataException(
                "Larger-replacement body is not the reviewed corrected 20-byte body");
    }

    internal static LargerReplacementNode[] AnalyzeFlatBody(
        ReadOnlySpan<byte> body, ushort bodyStart, int bodyEndExclusive)
    {
        if (body.Length <= 0)
            throw new InvalidDataException("Flat body is empty");
        if (bodyEndExclusive != bodyStart + body.Length)
            throw new InvalidDataException(
                $"Flat body span {bodyStart:X4}-{bodyEndExclusive - 1:X4} does not match its " +
                $"{body.Length} bytes");
        if (bodyEndExclusive > 0x10000)
            throw new InvalidDataException(
                $"Flat body end {bodyEndExclusive:X4} exceeds the 16-bit address space");

        var nodes = new List<LargerReplacementNode>();
        int cursor = bodyStart;
        int offset = 0;
        int cells = 1;
        int uDelta = 0;
        bool returned = false;

        while (offset < body.Length)
        {
            if (offset + 2 > body.Length)
                throw new InvalidDataException(
                    $"Truncated VM token at {cursor:X4} in the flat body");
            if (cursor + 2 > bodyEndExclusive)
                throw new InvalidDataException(
                    $"VM token at {cursor:X4} crosses the flat body end {bodyEndExclusive:X4}");

            ushort token = (ushort)((body[offset] << 8) | body[offset + 1]);
            if (!VmIlVocabulary.TryGetOperation(token, out string operation, out int operandBytes))
                throw new InvalidDataException(
                    $"Unsupported flat-body token {token:X4} at {cursor:X4}");
            if (token is not (VmIlVocabulary.InlineWordLiteral or VmIlVocabulary.AddWords or
                VmIlVocabulary.BitwiseXor or VmIlVocabulary.ReturnToCallerStream))
                throw new InvalidDataException(
                    $"Flat-body token {token:X4} at {cursor:X4} is outside the reviewed subset");

            int nodeLength = 2 + operandBytes;
            if (offset + nodeLength > body.Length)
                throw new InvalidDataException(
                    $"Truncated VM operand for token {token:X4} at {cursor:X4}");
            if (cursor + nodeLength > bodyEndExclusive)
                throw new InvalidDataException(
                    $"VM instruction {token:X4} at {cursor:X4} crosses the flat body end " +
                    $"{bodyEndExclusive:X4}");

            if (returned)
                throw new InvalidDataException(
                    $"Multiple VM return tokens: bytes after a return at {cursor:X4}");

            VmIlOperand? operand = null;
            if (operandBytes == 2)
            {
                ushort value = (ushort)((body[offset + 2] << 8) | body[offset + 3]);
                operand = new VmIlOperand(
                    checked((ushort)(cursor + 2)),
                    body.Slice(offset + 2, 2).ToArray(),
                    value);
            }

            int stackDelta = token switch
            {
                VmIlVocabulary.InlineWordLiteral => -2,
                VmIlVocabulary.AddWords => 2,
                VmIlVocabulary.BitwiseXor => 2,
                VmIlVocabulary.ReturnToCallerStream => 0,
                _ => throw new InvalidDataException(
                    $"Unsupported flat-body stack effect for token {token:X4} at {cursor:X4}")
            };

            int depthAfter;
            if (token == VmIlVocabulary.InlineWordLiteral)
            {
                cells += 1;
                depthAfter = cells;
            }
            else if (token is VmIlVocabulary.AddWords or VmIlVocabulary.BitwiseXor)
            {
                if (cells < 2)
                    throw new InvalidDataException(
                        $"Flat-body stack underflow at {cursor:X4}: token {token:X4} needs two " +
                        "input cells");
                cells -= 1;
                depthAfter = cells;
            }
            else
            {
                if (cells != 1)
                    throw new InvalidDataException(
                        $"Flat-body return at {cursor:X4} leaves depth {cells}; expected 1");
                depthAfter = cells;
            }

            if (token == VmIlVocabulary.ReturnToCallerStream)
            {
                if (cursor + nodeLength != bodyEndExclusive)
                {
                    ushort[] unreachable = CollectTokenAddresses(
                        body, offset + nodeLength, cursor + nodeLength, bodyEndExclusive);
                    throw new InvalidDataException(
                        $"Flat body reachability failed: returnAddress={cursor:X4}; " +
                        $"unreachableAddresses=[{string.Join(",", unreachable.Select(
                            address => address.ToString("X4")))}]; bytes after an earlier " +
                        "return are unreachable");
                }
                returned = true;
            }

            nodes.Add(new LargerReplacementNode(
                nodes.Count,
                (ushort)cursor,
                token,
                operation,
                Convert.ToHexString(body.Slice(offset, nodeLength)),
                operand?.Address,
                operand?.Value,
                checked((ushort)(token + 2)),
                stackDelta,
                depthAfter));

            cursor += nodeLength;
            offset += nodeLength;
            uDelta += stackDelta;
        }

        if (!returned)
            throw new InvalidDataException("Flat body is missing its final 792F return token");
        if (uDelta != 0)
            throw new InvalidDataException(
                $"Flat body net U delta is {uDelta}; the reviewed contract requires 0");
        if (cells != 1)
            throw new InvalidDataException(
                $"Flat body exit depth is {cells}; the reviewed contract requires 1");
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
            if (!VmIlVocabulary.TryGetOperation(token, out _, out int operandBytes))
                break;
            int length = 2 + operandBytes;
            if (offset + length > body.Length || cursor + length > bodyEndExclusive)
                break;
            offset += length;
            cursor += length;
        }
        return addresses.ToArray();
    }

    private static void ValidateNodes(
        ReadOnlySpan<byte> rom, ReadOnlySpan<byte> payload, LargerReplacementNode[] nodes)
    {
        if (nodes.Length != NodeCount)
            throw new InvalidDataException(
                $"Larger replacement decoded {nodes.Length} nodes; expected {NodeCount}");

        ushort[] expectedAddresses = { 0x1012, 0x1016, 0x1018, 0x101C, 0x101E, 0x1022, 0x1024 };
        ushort[] expectedTokens =
        {
            0x795B, 0x787E, 0x795B, 0x7AAF, 0x795B, 0x787E, 0x792F
        };
        ushort?[] expectedOperandAddresses =
        {
            0x1014, null, 0x101A, null, 0x1020, null, null
        };
        ushort?[] expectedOperandValues =
        {
            0xFF80, null, 0xFF80, null, 0x0001, null, null
        };

        int cursor = BodyStart;
        int inlineOperands = 0;
        for (int index = 0; index < nodes.Length; index++)
        {
            LargerReplacementNode node = nodes[index];
            if (node.Index != index ||
                node.Address != expectedAddresses[index] ||
                node.Token != expectedTokens[index] ||
                node.HandlerAddress != expectedTokens[index] + 2)
                throw new InvalidDataException(
                    $"Larger-replacement node {index} does not match the reviewed body");
            if (node.Address != cursor)
                throw new InvalidDataException(
                    $"Larger-replacement node {index} at {node.Address:X4} does not follow " +
                    $"cursor {cursor:X4}");
            if (node.OperandAddress != expectedOperandAddresses[index] ||
                node.OperandValue != expectedOperandValues[index])
                throw new InvalidDataException(
                    $"Larger-replacement node {index} operand differs from the reviewed body");
            if (node.OperandAddress is not null)
                inlineOperands++;
            byte[] bytes = Convert.FromHexString(node.BytesHex);
            if (!payload.Slice(node.Address - HeaderAddress, bytes.Length)
                    .SequenceEqual(bytes))
                throw new InvalidDataException(
                    $"Larger-replacement node {index} bytes differ from the payload");
            ushort pointer = (ushort)((rom[node.Token] << 8) | rom[node.Token + 1]);
            if (pointer != node.HandlerAddress)
                throw new InvalidDataException(
                    $"Flat-body token {node.Token:X4} pointer cell contains {pointer:X4}; " +
                    $"expected handler {node.HandlerAddress:X4}");
            cursor += bytes.Length;
        }

        if (inlineOperands != InlineOperandCount)
            throw new InvalidDataException(
                $"Larger replacement has {inlineOperands} inline operands; expected " +
                $"{InlineOperandCount}");
        if (cursor != BodyEndExclusive)
            throw new InvalidDataException(
                $"Larger-replacement body ends at {cursor:X4}; expected {BodyEndExclusive:X4}");
        if (nodes[^1].Token != VmIlVocabulary.ReturnToCallerStream ||
            nodes[^1].Address != 0x1024)
            throw new InvalidDataException(
                "Larger replacement does not end with exactly one 792F return at 1024");
    }

    private static LargerReplacementStaticContract BuildStaticContract(
        LargerReplacementNode[] nodes)
    {
        int cells = 1;
        int uDelta = 0;
        foreach (LargerReplacementNode node in nodes)
        {
            int expectedDelta;
            int expectedDepth;
            if (node.Token == VmIlVocabulary.InlineWordLiteral)
            {
                expectedDelta = -2;
                cells += 1;
                expectedDepth = cells;
            }
            else if (node.Token is VmIlVocabulary.AddWords or VmIlVocabulary.BitwiseXor)
            {
                if (cells < 2)
                    throw new InvalidDataException(
                        $"Static stack underflow at {node.Address:X4}");
                expectedDelta = 2;
                cells -= 1;
                expectedDepth = cells;
            }
            else if (node.Token == VmIlVocabulary.ReturnToCallerStream)
            {
                if (cells != 1)
                    throw new InvalidDataException(
                        $"Static return at {node.Address:X4} leaves depth {cells}; expected 1");
                expectedDelta = 0;
                expectedDepth = cells;
            }
            else
            {
                throw new InvalidDataException(
                    $"Unsupported static-contract token {node.Token:X4} at {node.Address:X4}");
            }

            if (node.StackDeltaBytes != expectedDelta || node.DepthAfter != expectedDepth)
                throw new InvalidDataException(
                    $"Static stack metadata for node {node.Index} at {node.Address:X4} " +
                    "differs from the reviewed token effects");
            uDelta += expectedDelta;
        }
        if (uDelta != 0 || cells != 1)
            throw new InvalidDataException(
                "Static stack contract does not balance at net U 0 and depth 1");

        var vectors = new LargerReplacementVector[ExpectedVectors.Length];
        for (int index = 0; index < vectors.Length; index++)
        {
            ushort input = ExpectedVectors[index].Input;
            ushort copied = (ushort)(((input + 0xFF80) & 0xFFFF) ^ 0xFF80);
            ushort exit = (ushort)((copied + 0x0001) & 0xFFFF);
            ushort after = (exit & 0x8000) != 0 ? (ushort)0xFFFF : (ushort)0x0000;
            vectors[index] = new LargerReplacementVector(input, copied, exit, after);
        }

        var contract = new LargerReplacementStaticContract(
            1,
            1,
            0,
            -2,
            2,
            0,
            false,
            StaticPhaseClassification,
            Array.AsReadOnly(vectors));
        ValidateStaticVectors(contract);
        return contract;
    }

    private static void ValidateStaticVectors(LargerReplacementStaticContract contract)
    {
        if (contract.Vectors.Count != ExpectedVectors.Length)
            throw new InvalidDataException(
                "Static vector table does not contain the five reviewed inputs");
        for (int index = 0; index < ExpectedVectors.Length; index++)
        {
            if (contract.Vectors[index] != ExpectedVectors[index])
                throw new InvalidDataException(
                    $"Static vector at input {ExpectedVectors[index].Input:X4} differs from " +
                    "the reviewed task49 values");
        }
        if (contract.EntryDepth != 1 || contract.ExitDepth != 1 ||
            contract.BodyUNet != 0 || contract.TrampolineSDelta != -2 ||
            contract.ReturnHandlerSDelta != 2 || contract.WholeCallSNet != 0 ||
            contract.NestedCall)
            throw new InvalidDataException(
                "Static stack/frame contract differs from the reviewed task49 values");
    }

    private static void ValidateCertifiedSource(
        ReadOnlySpan<byte> rom, VmIlDefinition definition)
    {
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
                    $"Reviewed larger-replacement allocation byte at {offset:X4} is " +
                    $"{rom[offset]:X2}; expected FF");
        }

        foreach (var handler in Handlers)
        {
            ushort pointer = (ushort)((rom[handler.Token] << 8) | rom[handler.Token + 1]);
            if (pointer != handler.Handler)
                throw new InvalidDataException(
                    $"Token pointer cell at {handler.Token:X4} is {pointer:X4}; " +
                    $"expected native handler {handler.Handler:X4}");
            int evidenceLength = handler.HandlerHex.Length / 2;
            if (!rom.Slice(handler.Handler, evidenceLength)
                    .SequenceEqual(Convert.FromHexString(handler.HandlerHex)))
                throw new InvalidDataException(
                    $"Native handler bytes at {handler.Handler:X4} do not match the " +
                    "reviewed static contract");
        }
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
                    $"Unrepaired larger replacement changed byte {offset:X4} outside the " +
                    "allocation");
        }
        if (!unrepaired.Slice(CallerTokenAddress, 2)
                .SequenceEqual(original.Slice(CallerTokenAddress, 2)))
            throw new InvalidDataException(
                "Unrepaired larger replacement pre-modified the caller token before the " +
                "checked patch");
    }

    private static void ValidatePreservedBytes(
        ReadOnlySpan<byte> original,
        ReadOnlySpan<byte> unrepaired,
        ReadOnlySpan<byte> output)
    {
        for (int offset = 0; offset < original.Length; offset++)
        {
            bool allowed = (offset >= AllocationStart && offset <= AllocationEndInclusive) ||
                           (offset >= CallerTokenAddress && offset < CallerTokenAddress + 2) ||
                           (offset >= VmIlIntegrity.SumOffset &&
                            offset <= VmIlIntegrity.RotateSubXorBOffset);
            if (!allowed && output[offset] != original[offset])
                throw new InvalidDataException(
                    $"Larger-replacement output changed preserved byte {offset:X4}");
        }

        EnsureEqual(original, output, 0x1000, 0x100F, "left guard");
        EnsureEqual(original, output, 0x1000, 0x1003, "protected cells");
        EnsureEqual(original, output, 0x13F0, 0x13FF, "right guard");
        EnsureEqual(original, output, 0x1400, 0x140F, "integrity neighbour");
        EnsureEqual(original, output, 0x9ED7, 0x9EE6,
            "original 9ED7 header and 9ED9 body");
        EnsureEqual(original, output, 0x1026, 0x13EF, "unallocated extension bytes");
        EnsureEqual(original, output, 0x719B, 0x719B, "outer gate");
        EnsureEqual(original, output, 0x7927, 0x792E, "runtime dispatch template");
        EnsureEqual(original, output, 0x9F10, 0x9F13,
            "caller definition header/body prefix");
        EnsureEqual(original, output, 0x9F16, 0x9F1D,
            "caller successor and following bytes");
        EnsureEqual(original, output, 0x9F3B, 0x9F40, "parent caller context");
        if (output[0x1014] != 0xFF || output[0x101A] != 0xFF)
            throw new InvalidDataException(
                "Larger-replacement output changed the original FF bytes at 1014/101A");
        if (!unrepaired.Slice(0x9ED7, 16).SequenceEqual(original.Slice(0x9ED7, 16)))
            throw new InvalidDataException(
                "Unrepaired larger replacement changed the original 9ED7/9ED9 definition");
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
                $"Larger-replacement output changed preserved {label} at {start:X4}-{end:X4}");
    }

    private static int[] ChangedOffsets(
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

    private static string Sha1(ReadOnlySpan<byte> bytes) =>
        Convert.ToHexString(SHA1.HashData(bytes));

    private static string Sha256(ReadOnlySpan<byte> bytes) =>
        Convert.ToHexString(SHA256.HashData(bytes));
}

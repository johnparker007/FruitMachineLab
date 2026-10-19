using System.Collections.ObjectModel;
using System.Security.Cryptography;

namespace FruitMachineLab.Il;

public sealed record CompositeWordNode(
    int Index,
    ushort Address,
    ushort Token,
    string Operation,
    string BytesHex,
    ushort? OperandAddress,
    ushort? OperandValue,
    ushort HandlerAddress);

public sealed record CompositeWordProvenance(
    string ProposalId,
    string OriginalDefinitionListingPath,
    string OriginalDefinitionListingSha256,
    string OriginalBodyHex,
    string CallerListingPath,
    string ParentListingPath,
    string Classification);

public sealed record CompositeWordByteChange(int Offset, byte Before, byte After);

public sealed class CompositeWordBuildResult
{
    private readonly byte[] _outputImage;
    private readonly byte[] _unrepairedImage;
    private readonly byte[] _payloadBytes;
    private readonly ReadOnlyCollection<int> _unrepairedChangedOffsets;
    private readonly ReadOnlyCollection<int> _changedOffsets;
    private readonly ReadOnlyCollection<int> _repairChangedOffsets;
    private readonly ReadOnlyCollection<CompositeWordByteChange> _byteChanges;
    private readonly ReadOnlyCollection<CompositeWordNode> _nodes;
    private readonly VmIlIntegrityReport _integrityReport;

    internal CompositeWordBuildResult(
        byte[] outputImage,
        byte[] unrepairedImage,
        byte[] payloadBytes,
        string originalRomSha1,
        string originalRomSha256,
        string unrepairedImageSha1,
        string unrepairedImageSha256,
        string outputImageSha1,
        string outputImageSha256,
        CompositeWordNode[] nodes,
        int[] unrepairedChangedOffsets,
        int[] changedOffsets,
        int[] repairChangedOffsets,
        CompositeWordByteChange[] byteChanges,
        VmIlIntegrityReport integrityReport,
        CompositeWordSourceMap sourceMap,
        CompositeWordProvenance provenance)
    {
        _outputImage = (byte[])outputImage.Clone();
        _unrepairedImage = (byte[])unrepairedImage.Clone();
        _payloadBytes = (byte[])payloadBytes.Clone();
        _unrepairedChangedOffsets = Array.AsReadOnly((int[])unrepairedChangedOffsets.Clone());
        _changedOffsets = Array.AsReadOnly((int[])changedOffsets.Clone());
        _repairChangedOffsets = Array.AsReadOnly((int[])repairChangedOffsets.Clone());
        _byteChanges = Array.AsReadOnly((CompositeWordByteChange[])byteChanges.Clone());
        _nodes = Array.AsReadOnly((CompositeWordNode[])nodes.Clone());
        OriginalRomSha1 = originalRomSha1;
        OriginalRomSha256 = originalRomSha256;
        UnrepairedImageSha1 = unrepairedImageSha1;
        UnrepairedImageSha256 = unrepairedImageSha256;
        OutputImageSha1 = outputImageSha1;
        OutputImageSha256 = outputImageSha256;
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

    public IReadOnlyList<CompositeWordNode> Nodes => _nodes;

    public IReadOnlyList<int> UnrepairedChangedOffsets => _unrepairedChangedOffsets;

    public IReadOnlyList<int> ChangedOffsets => _changedOffsets;

    public IReadOnlyList<int> RepairChangedOffsets => _repairChangedOffsets;

    public IReadOnlyList<CompositeWordByteChange> ByteChanges => _byteChanges;

    public VmIlIntegrityReport IntegrityReport => CopyIntegrityReport(_integrityReport);

    public CompositeWordSourceMap SourceMap { get; }

    public CompositeWordProvenance Provenance { get; }

    public string Status => CompositeWordBuilder.StatusText;

    private static VmIlIntegrityReport CopyIntegrityReport(VmIlIntegrityReport report) =>
        report with
        {
            Fields = report.Fields.ToArray(),
            UnrepairedChangedOffsets = (int[])report.UnrepairedChangedOffsets.Clone(),
            RepairedChangedOffsets = (int[])report.RepairedChangedOffsets.Clone(),
            RepairChangedOffsets = (int[])report.RepairChangedOffsets.Clone()
        };
}

public static class CompositeWordBuilder
{
    public const ushort HeaderAddress = 0x1010;
    public const ushort HeaderValue = 0x00F8;
    public const string HeaderHex = "00F8";
    public const ushort BodyStart = 0x1012;
    public const int BodyEndExclusive = 0x1020;
    public const int AllocationLength = 16;
    public const string BodyHex = "795BFF80787E795BFF807AAF792F";
    public const string PayloadHex = "00F8" + BodyHex;

    public const ushort OriginalHeaderAddress = 0x9ED7;
    public const ushort OriginalBodyStart = 0x9ED9;
    public const int OriginalBodyEndExclusive = 0x9EE7;
    public const string OriginalBodyHex = BodyHex;

    public const ushort CallerHeaderAddress = 0x9F10;
    public const ushort CallerBodyStart = 0x9F12;
    public const int CallerBodyEndExclusive = 0x9F1E;
    public const string CallerBodyHex = "77F69ED775A97B7D7B3D792F";
    public const ushort CallerTokenAddress = 0x9F14;
    public const ushort CallerOriginalToken = 0x9ED7;
    public const ushort CallerReplacementToken = 0x1010;
    public const ushort CallerSuccessorAddress = 0x9F16;
    public const ushort CallerSuccessorToken = 0x75A9;
    public const ushort ParentTokenAddress = 0x9F3D;
    public const ushort ParentToken = 0x9F10;
    public const ushort ParentSuccessorAddress = 0x9F3F;
    public const ushort ParentSuccessorToken = 0x792F;

    public const string OriginalFieldsHex = "3E761E2605";
    public const string CompositeFieldsHex = "E93F3C61B5";
    public const string ExpectedOutputSha1 = "DC6381B9883AAFDE372D2C2AA14C817BAE839B21";
    public const string ExpectedOutputSha256 =
        "761F34BAAC06C6F8F5DA963CCADEB276FAE9196EE1C4D9060BC915A314E3903D";

    public const string ProposalId = "composite-copy-9ed9-at-1010";
    public const string ProvenanceText =
        "Statically compiled composite definition for the reviewed A6L 0.1 set 1 proposal. " +
        "The new header 1010 contains 00F8 and the body 1012-101F is a byte-identical copy of " +
        "the certified 9ED9 body; only the naturally cited caller token 9ED7 at 9F14 is " +
        "replaced by 1010. Original 9ED7/9ED9 and every other caller byte are preserved. " +
        "No MAME execution, natural new-word behaviour or hardware compatibility is claimed.";
    public const string StatusText =
        "STATIC COMPILED COMPOSITE WORD ONLY: extension header/body and one same-size caller " +
        "token were emitted in memory and the ordered integrity fields were repaired. This is " +
        "not execution proof, natural boot acceptance or hardware compatibility.";

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
        0x1019, 0x101B, 0x101C, 0x101D, 0x101E, 0x101F, 0x9F14, 0x9F15
    };

    private static readonly int[] FinalChangedOffsets =
    {
        0x1010, 0x1011, 0x1012, 0x1013, 0x1015, 0x1016, 0x1017, 0x1018,
        0x1019, 0x101B, 0x101C, 0x101D, 0x101E, 0x101F, 0x9F14, 0x9F15,
        0xFFD1, 0xFFD2, 0xFFD3, 0xFFD4, 0xFFD5
    };

    public static CompositeWordBuildResult Build(ReadOnlySpan<byte> originalRom)
    {
        VmIlDefinition originalDefinition = NineEdNineDecoder.Decode(originalRom);
        ValidateCertifiedSource(originalRom, originalDefinition);

        CompositeWordNode[] nodes = BuildNodes(originalRom, originalDefinition);
        byte[] payload = Convert.FromHexString(PayloadHex);

        var descriptor = ExtensionRangeDescriptor.Approved;
        ExtensionRangeAllocator allocator =
            ExtensionRangeAllocator.Create(originalRom, descriptor);
        ExtensionRangePlan plan = allocator.Plan(new[]
        {
            new ExtensionAllocationRequest(ProposalId, AllocationLength)
        });
        ExtensionRangeAllocation allocation = plan.Allocations.Single();
        if (allocation.CpuStart != HeaderAddress ||
            allocation.CpuEnd != BodyEndExclusive - 1 ||
            allocation.FileStart != HeaderAddress ||
            allocation.FileEnd != BodyEndExclusive - 1 ||
            allocation.Length != AllocationLength)
            throw new InvalidDataException(
                "Allocator did not place the reviewed composite word at 1010-101F");

        var payloadRecord = new ExtensionPayload(ProposalId, payload);
        ExtensionRangeEmission emission = ExtensionRangeEmitter.Emit(
            originalRom, descriptor, plan, new[] { payloadRecord });

        if (!emission.IntegrityCoveredBytesUnchanged ||
            !emission.IntegrityFieldsUnchanged)
            throw new InvalidDataException(
                "Extension emission unexpectedly changed integrity-covered bytes or fields");
        if (!emission.OutputImage.Slice(HeaderAddress, AllocationLength)
                .SequenceEqual(payload))
            throw new InvalidDataException(
                "Emitted extension allocation does not contain the composite payload");
        if (!emission.ChangedOffsets.SequenceEqual(
                new[] { 0x1010, 0x1011, 0x1012, 0x1013, 0x1015, 0x1016, 0x1017,
                        0x1018, 0x1019, 0x101B, 0x101C, 0x101D, 0x101E, 0x101F }))
            throw new InvalidDataException(
                "Extension emission did not realize exactly the 14 reviewed payload changes");
        if (!emission.OutputImage.Slice(VmIlIntegrity.RangeStart, 0x10000 - 0x1400)
                .SequenceEqual(originalRom.Slice(VmIlIntegrity.RangeStart, 0x10000 - 0x1400)))
            throw new InvalidDataException(
                "Unrepaired extension emission changed integrity-covered 1400-FFFF bytes");

        byte[] unrepaired = emission.CopyOutputImage();
        ValidateCallerBeforePatch(originalRom, unrepaired);
        if (unrepaired[CallerTokenAddress] != 0x9E ||
            unrepaired[(int)CallerTokenAddress + 1] != 0xD7)
            throw new InvalidDataException("Original caller token at 9F14 is not 9ED7");
        unrepaired[CallerTokenAddress] = 0x10;
        unrepaired[CallerTokenAddress + 1] = 0x10;

        int[] unrepairedDiff = ChangedOffsets(originalRom, unrepaired);
        if (!unrepairedDiff.SequenceEqual(UnrepairedChangedOffsets))
            throw new InvalidDataException(
                "Unrepaired composite diff is not exactly 14 extension changes plus the " +
                "two caller-token bytes");

        var patch = new VmIlCompositePatchSpec(
            HeaderAddress,
            Enumerable.Repeat((byte)0xFF, AllocationLength).ToArray(),
            payload,
            CallerTokenAddress,
            new byte[] { 0x9E, 0xD7 },
            new byte[] { 0x10, 0x10 });
        VmIlIntegrityResult integrity =
            VmIlIntegrity.RepairComposite(originalRom, unrepaired, patch);

        string outputSha1 = Sha1(integrity.RepairedImage);
        string outputSha256 = Sha256(integrity.RepairedImage);
        if (!string.Equals(outputSha1, ExpectedOutputSha1, StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(outputSha256, ExpectedOutputSha256, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                $"Composite output hashes are SHA1 {outputSha1} / SHA256 {outputSha256}; " +
                $"the reviewed contract requires {ExpectedOutputSha1} / {ExpectedOutputSha256}");
        if (!string.Equals(
                integrity.Report.RepairedStoredFieldsHex, CompositeFieldsHex,
                StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Composite integrity fields are {integrity.Report.RepairedStoredFieldsHex}; " +
                $"the reviewed contract requires {CompositeFieldsHex}");

        int[] finalDiff = ChangedOffsets(originalRom, integrity.RepairedImage);
        if (finalDiff.Length != 21 || !finalDiff.SequenceEqual(FinalChangedOffsets))
            throw new InvalidDataException(
                "Final composite diff is not exactly the reviewed 21 changed offsets");
        if (!integrity.Report.UnrepairedChangedOffsets.SequenceEqual(UnrepairedChangedOffsets) ||
            !integrity.Report.RepairedChangedOffsets.SequenceEqual(FinalChangedOffsets))
            throw new InvalidDataException(
                "Composite integrity report diff does not match the reviewed contract");
        if (!integrity.Report.RepairChangedOffsets.SequenceEqual(
                new[] { 0xFFD1, 0xFFD2, 0xFFD3, 0xFFD4, 0xFFD5 }))
            throw new InvalidDataException(
                "Composite repair changed bytes outside FFD1-FFD5");

        ValidatePreservedBytes(originalRom, unrepaired, integrity.RepairedImage);

        var changes = new CompositeWordByteChange[finalDiff.Length];
        for (int index = 0; index < finalDiff.Length; index++)
        {
            int offset = finalDiff[index];
            changes[index] = new CompositeWordByteChange(
                offset, originalRom[offset], integrity.RepairedImage[offset]);
        }
        var provenance = new CompositeWordProvenance(
            ProposalId,
            originalDefinition.Provenance.ListingPath,
            originalDefinition.Provenance.ListingSha256,
            OriginalBodyHex,
            "evidence/mpu4/VM-SCRIPTS/9F12.txt",
            "evidence/mpu4/VM-SCRIPTS/9F3B.txt",
            "static_compiled_contract; original_rom_bytes; prior_trace_reachability_only");

        CompositeWordSourceMap map = CompositeWordSourceMap.CreateForBuild(
            originalRom,
            integrity.RepairedImage,
            nodes,
            provenance);

        return new CompositeWordBuildResult(
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
            unrepairedDiff,
            finalDiff,
            integrity.Report.RepairChangedOffsets.ToArray(),
            changes,
            integrity.Report,
            map,
            provenance);
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
        if (!rom.Slice(ParentTokenAddress, 2).SequenceEqual(new byte[] { 0x9F, 0x10 }) ||
            !rom.Slice(ParentSuccessorAddress, 2).SequenceEqual(new byte[] { 0x79, 0x2F }))
            throw new InvalidDataException(
                "Parent caller context at 9F3D/9F3F does not match the reviewed contract");
        if (!rom.Slice(0x7927, 8)
                .SequenceEqual(Convert.FromHexString("34203184AEA16E91")))
            throw new InvalidDataException(
                "Runtime dispatch template at 7927-792E differs from the reviewed bytes");

        foreach (var handler in Handlers)
        {
            ushort header = (ushort)((rom[handler.Token] << 8) | rom[handler.Token + 1]);
            if (header != handler.Handler)
                throw new InvalidDataException(
                    $"Token header at {handler.Token:X4} is {header:X4}; " +
                    $"expected native handler {handler.Handler:X4}");
            int evidenceLength = handler.HandlerHex.Length / 2;
            if (!rom.Slice(handler.Handler, evidenceLength)
                    .SequenceEqual(Convert.FromHexString(handler.HandlerHex)))
                throw new InvalidDataException(
                    $"Native handler bytes at {handler.Handler:X4} do not match the " +
                    "reviewed static contract");
        }

        foreach (VmIlNode node in definition.Nodes)
        {
            if (!Handlers.Any(item => item.Token == node.Token))
                throw new InvalidDataException(
                    $"Unsupported composite body token {node.Token:X4} at {node.Address:X4}");
            if (node.Operand is not null &&
                !string.Equals(Convert.ToHexString(node.Operand.Bytes),
                    node.Token == 0x795B ? "FF80" : "UNEXPECTED",
                    StringComparison.Ordinal))
                throw new InvalidDataException(
                    $"Unsupported inline operand at {node.Address:X4}");
        }
    }

    private static CompositeWordNode[] BuildNodes(
        ReadOnlySpan<byte> rom, VmIlDefinition definition)
    {
        int shift = BodyStart - OriginalBodyStart;
        var nodes = new CompositeWordNode[definition.Nodes.Count];
        for (int index = 0; index < definition.Nodes.Count; index++)
        {
            VmIlNode node = definition.Nodes[index];
            int address = node.Address + shift;
            if (address < BodyStart || address >= BodyEndExclusive)
                throw new InvalidDataException(
                    $"Copied node {index} at {node.Address:X4} falls outside the new body span");
            ushort copiedAddress = checked((ushort)address);
            ushort handlerAddress = checked((ushort)(node.Token + 2));
            ushort? operandAddress = null;
            ushort? operandValue = null;
            if (node.Operand is not null)
            {
                int copiedOperandAddress = node.Operand.Address + shift;
                if (copiedOperandAddress < copiedAddress + 2 ||
                    copiedOperandAddress + 1 >= BodyEndExclusive)
                    throw new InvalidDataException(
                        $"Copied operand {index} does not lie inside the new body span");
                operandAddress = checked((ushort)copiedOperandAddress);
                operandValue = node.Operand.Value;
            }

            if (!rom.Slice(node.Address, node.Bytes.Length).SequenceEqual(node.Bytes))
                throw new InvalidDataException(
                    $"Certified node {index} bytes do not match the original ROM");
            if (!string.Equals(Convert.ToHexString(node.Bytes),
                    Convert.ToHexString(rom.Slice(node.Address, node.Bytes.Length)),
                    StringComparison.Ordinal))
                throw new InvalidDataException(
                    $"Certified node {index} bytes are not the original bytes");

            nodes[index] = new CompositeWordNode(
                index,
                copiedAddress,
                node.Token,
                node.Operation,
                Convert.ToHexString(node.Bytes),
                operandAddress,
                operandValue,
                handlerAddress);
        }

        string bodyHex = string.Concat(nodes.Select(node => node.BytesHex));
        if (!string.Equals(bodyHex, BodyHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                "Independently decoded 9ED9 nodes do not re-emit the certified body");

        int cursor = BodyStart;
        foreach (CompositeWordNode node in nodes)
        {
            if (node.Address != cursor)
                throw new InvalidDataException(
                    $"Copied node at {node.Address:X4} does not follow cursor {cursor:X4}");
            cursor += node.BytesHex.Length / 2;
        }
        if (cursor != BodyEndExclusive)
            throw new InvalidDataException(
                $"Copied body ends at {cursor:X4}; expected {BodyEndExclusive:X4}");
        return nodes;
    }

    private static void ValidateCallerBeforePatch(
        ReadOnlySpan<byte> original, ReadOnlySpan<byte> unrepaired)
    {
        for (int offset = 0; offset < original.Length; offset++)
        {
            if (offset == HeaderAddress || offset == HeaderAddress + 1)
                continue;
            if (offset >= HeaderAddress && offset < BodyEndExclusive)
                continue;
            if (unrepaired[offset] != original[offset])
                throw new InvalidDataException(
                    $"Unrepaired composite changed byte {offset:X4} outside the allocation");
        }
        if (!unrepaired.Slice(CallerTokenAddress, 2)
                .SequenceEqual(original.Slice(CallerTokenAddress, 2)))
            throw new InvalidDataException(
                "Unrepaired composite pre-modified the caller token before the checked patch");
    }

    private static void ValidatePreservedBytes(
        ReadOnlySpan<byte> original,
        ReadOnlySpan<byte> unrepaired,
        ReadOnlySpan<byte> output)
    {
        for (int offset = 0; offset < original.Length; offset++)
        {
            bool allowed = (offset >= HeaderAddress && offset < BodyEndExclusive) ||
                           (offset >= CallerTokenAddress && offset < CallerTokenAddress + 2) ||
                           (offset >= VmIlIntegrity.SumOffset &&
                            offset <= VmIlIntegrity.RotateSubXorBOffset);
            if (!allowed && output[offset] != original[offset])
                throw new InvalidDataException(
                    $"Composite output changed preserved byte {offset:X4}");
        }

        if (!output.Slice(ExtensionRangeAllocator.LeftGuardStart,
                ExtensionRangeAllocator.LeftGuardEnd -
                ExtensionRangeAllocator.LeftGuardStart + 1)
                .SequenceEqual(original.Slice(
                    ExtensionRangeAllocator.LeftGuardStart,
                    ExtensionRangeAllocator.LeftGuardEnd -
                    ExtensionRangeAllocator.LeftGuardStart + 1)))
            throw new InvalidDataException("Composite output changed the left guard");
        if (!output.Slice(ExtensionRangeAllocator.RightGuardStart,
                ExtensionRangeAllocator.RightGuardEnd -
                ExtensionRangeAllocator.RightGuardStart + 1)
                .SequenceEqual(original.Slice(
                    ExtensionRangeAllocator.RightGuardStart,
                    ExtensionRangeAllocator.RightGuardEnd -
                    ExtensionRangeAllocator.RightGuardStart + 1)))
            throw new InvalidDataException("Composite output changed the right guard");
        if (!output.Slice(0x1014, 1).SequenceEqual(original.Slice(0x1014, 1)) ||
            !output.Slice(0x101A, 1).SequenceEqual(original.Slice(0x101A, 1)))
            throw new InvalidDataException(
                "Composite output changed the unallocated FF bytes at 1014/101A");
        if (!output.Slice(OriginalHeaderAddress, 16)
                .SequenceEqual(original.Slice(OriginalHeaderAddress, 16)))
            throw new InvalidDataException(
                "Composite output changed the original 9ED7 header or 9ED9 body");
        if (!output.Slice(CallerSuccessorAddress, 2)
                .SequenceEqual(original.Slice(CallerSuccessorAddress, 2)))
            throw new InvalidDataException(
                "Composite output changed the caller successor token at 9F16");
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

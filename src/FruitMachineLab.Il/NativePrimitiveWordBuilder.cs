using System.Collections.ObjectModel;
using System.Security.Cryptography;

namespace FruitMachineLab.Il;

public sealed record NativePrimitiveByteChange(int Offset, byte Before, byte After);

public sealed class NativePrimitiveBuildResult
{
    private readonly byte[] _outputImage;
    private readonly byte[] _unrepairedImage;
    private readonly byte[] _payloadBytes;
    private readonly ReadOnlyCollection<int> _unrepairedChangedOffsets;
    private readonly ReadOnlyCollection<int> _changedOffsets;
    private readonly ReadOnlyCollection<int> _repairChangedOffsets;
    private readonly ReadOnlyCollection<NativePrimitiveByteChange> _byteChanges;
    private readonly VmIlIntegrityReport _integrityReport;

    internal NativePrimitiveBuildResult(
        byte[] outputImage,
        byte[] unrepairedImage,
        byte[] payloadBytes,
        string originalRomSha1,
        string originalRomSha256,
        string unrepairedImageSha1,
        string unrepairedImageSha256,
        string outputImageSha1,
        string outputImageSha256,
        int[] unrepairedChangedOffsets,
        int[] changedOffsets,
        int[] repairChangedOffsets,
        NativePrimitiveByteChange[] byteChanges,
        VmIlIntegrityReport integrityReport,
        NativePrimitiveSourceMap sourceMap,
        NativePrimitiveProvenance provenance)
    {
        _outputImage = (byte[])outputImage.Clone();
        _unrepairedImage = (byte[])unrepairedImage.Clone();
        _payloadBytes = (byte[])payloadBytes.Clone();
        _unrepairedChangedOffsets =
            Array.AsReadOnly((int[])unrepairedChangedOffsets.Clone());
        _changedOffsets = Array.AsReadOnly((int[])changedOffsets.Clone());
        _repairChangedOffsets = Array.AsReadOnly((int[])repairChangedOffsets.Clone());
        _byteChanges =
            Array.AsReadOnly((NativePrimitiveByteChange[])byteChanges.Clone());
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

    public IReadOnlyList<int> UnrepairedChangedOffsets => _unrepairedChangedOffsets;

    public IReadOnlyList<int> ChangedOffsets => _changedOffsets;

    public IReadOnlyList<int> RepairChangedOffsets => _repairChangedOffsets;

    public IReadOnlyList<NativePrimitiveByteChange> ByteChanges => _byteChanges;

    public VmIlIntegrityReport IntegrityReport => CopyIntegrityReport(_integrityReport);

    public NativePrimitiveSourceMap SourceMap { get; }

    public NativePrimitiveProvenance Provenance { get; }

    public string Status => NativePrimitiveWordBuilder.StatusText;

    private static VmIlIntegrityReport CopyIntegrityReport(VmIlIntegrityReport report) =>
        report with
        {
            Fields = report.Fields.ToArray(),
            UnrepairedChangedOffsets = (int[])report.UnrepairedChangedOffsets.Clone(),
            RepairedChangedOffsets = (int[])report.RepairedChangedOffsets.Clone(),
            RepairChangedOffsets = (int[])report.RepairChangedOffsets.Clone()
        };
}

public static class NativePrimitiveWordBuilder
{
    public const ushort TokenAddress = 0x1010;
    public const ushort TokenValue = 0x1012;
    public const string TokenHex = "1012";
    public const ushort HandlerStart = 0x1012;
    public const int HandlerEndExclusive = 0x101B;
    public const int HandlerLength = 9;
    public const string HandlerHex = "ECC4C38000EDC40EFC";
    public const int AllocationStart = 0x1010;
    public const int AllocationEndInclusive = 0x101A;
    public const int AllocationLength = 11;
    public const string PayloadHex = TokenHex + HandlerHex;

    public const ushort CallerTokenAddress = 0x9F14;
    public const ushort CallerOriginalToken = 0x9ED7;
    public const ushort CallerReplacementToken = 0x1010;
    public const string CallerReplacementTokenHex = "1010";
    public const ushort CallerSuccessorAddress = 0x9F16;
    public const ushort CallerSuccessorToken = 0x75A9;
    public const string CallerSuccessorTokenHex = "75A9";

    public const ushort ParentTokenAddress = 0x9F3D;
    public const ushort ParentToken = 0x9F10;
    public const ushort ParentSuccessorAddress = 0x9F3F;
    public const ushort ParentSuccessorToken = 0x792F;

    public const ushort OriginalDefinitionHeaderAddress = 0x9ED7;
    public const ushort OriginalDefinitionBodyStart = 0x9ED9;
    public const int OriginalDefinitionBodyLength = 14;
    public const string OriginalDefinitionBodyHex = "795BFF80787E795BFF807AAF792F";
    public const string RuntimeDispatchTemplateHex = "34203184AEA16E91";

    public const ushort RejoinAddress = 0x00FC;

    public const string OriginalFieldsHex = "3E761E2605";
    public const string NativePrimitiveFieldsHex = "E93F3C61B5";
    public const string ExpectedOutputSha1 = "22BF419CF68F243169F05193B0E1AAF708D07707";
    public const string ExpectedOutputSha256 =
        "67E9390B8CD5EB941E1928F5E38129DF265207536002B6304C2A3B413E9B3AA8";

    public const string ProposalId = "vm_bias_word_by_8000";
    public const string ContractTaskId = "il-native-abi-correction-44";
    public const string ProvenanceText =
        "Statically compiled direct native 6809 primitive for the corrected A6L 0.1 set 1 " +
        "proposal. Token cell 1010 contains 1012 and the direct handler 1012-101A is " +
        "LDD ,U; ADDD #$8000; STD ,U; JMP $00FC. Only the naturally cited caller token " +
        "9ED7 at 9F14 is replaced by 1010. Original 9ED7/9ED9, other caller bytes, guards, " +
        "protected cells and the 1400 neighbour are preserved. No MAME execution, natural " +
        "primitive behaviour, gameplay or hardware compatibility is claimed.";
    public const string StatusText =
        "STATIC COMPILED NATIVE PRIMITIVE ONLY: the direct token/handler allocation and one " +
        "same-size caller token were emitted in memory and the ordered integrity fields were " +
        "repaired. This is not execution proof, natural boot acceptance or hardware compatibility.";

    private static readonly NativePrimitiveHandlerInstruction[] Instructions =
    {
        new(0, 0x1012, 0x1014, "ECC4", "LDD ,U"),
        new(1, 0x1014, 0x1017, "C38000", "ADDD #$8000"),
        new(2, 0x1017, 0x1019, "EDC4", "STD ,U"),
        new(3, 0x1019, 0x101B, "0EFC", "JMP $00FC")
    };

    private static readonly int[] UnrepairedChangedOffsets =
    {
        0x1010, 0x1011, 0x1012, 0x1013, 0x1014, 0x1015, 0x1016, 0x1017, 0x1018,
        0x1019, 0x101A, 0x9F14, 0x9F15
    };

    private static readonly int[] FinalChangedOffsets =
    {
        0x1010, 0x1011, 0x1012, 0x1013, 0x1014, 0x1015, 0x1016, 0x1017, 0x1018,
        0x1019, 0x101A, 0x9F14, 0x9F15, 0xFFD1, 0xFFD2, 0xFFD3, 0xFFD4, 0xFFD5
    };

    public static IReadOnlyList<NativePrimitiveHandlerInstruction> HandlerInstructions =>
        Array.AsReadOnly((NativePrimitiveHandlerInstruction[])Instructions.Clone());

    public static NativePrimitiveBuildResult Build(ReadOnlySpan<byte> originalRom)
    {
        VmIlDefinition definition = NineEdNineDecoder.Decode(originalRom);
        ValidateOriginalContext(originalRom, definition);

        byte[] payload = Convert.FromHexString(PayloadHex);
        if (payload.Length != AllocationLength)
            throw new InvalidDataException(
                "Native-primitive payload length differs from the reviewed 11-byte allocation");
        ValidatePayload(payload);

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
                "Allocator did not place the reviewed native primitive at 1010-101A");

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
                "Emitted extension allocation does not contain the native primitive payload");
        if (!emission.ChangedOffsets.SequenceEqual(
                Enumerable.Range(AllocationStart, AllocationLength)))
            throw new InvalidDataException(
                "Extension emission did not realize exactly the 11 reviewed payload changes");
        if (!emission.OutputImage.Slice(VmIlIntegrity.RangeStart, 0x10000 - 0x1400)
                .SequenceEqual(originalRom.Slice(VmIlIntegrity.RangeStart, 0x10000 - 0x1400)))
            throw new InvalidDataException(
                "Unrepaired extension emission changed integrity-covered 1400-FFFF bytes");

        byte[] unrepaired = emission.CopyOutputImage();
        ValidateCallerBeforePatch(originalRom, unrepaired);
        if (!unrepaired.AsSpan(CallerTokenAddress, 2).SequenceEqual(new byte[] { 0x9E, 0xD7 }))
            throw new InvalidDataException("Original caller token at 9F14 is not 9ED7");
        unrepaired[CallerTokenAddress] = 0x10;
        unrepaired[CallerTokenAddress + 1] = 0x10;

        int[] unrepairedDiff = ChangedOffsets(originalRom, unrepaired);
        if (!unrepairedDiff.SequenceEqual(UnrepairedChangedOffsets))
            throw new InvalidDataException(
                "Unrepaired native-primitive diff is not exactly 11 extension changes plus " +
                "the two caller-token bytes");

        var patch = new VmIlNativePrimitivePatchSpec(
            AllocationStart,
            Enumerable.Repeat((byte)0xFF, AllocationLength).ToArray(),
            payload,
            CallerTokenAddress,
            new byte[] { 0x9E, 0xD7 },
            new byte[] { 0x10, 0x10 });
        VmIlIntegrityResult integrity =
            VmIlIntegrity.RepairNativePrimitive(originalRom, unrepaired, patch);

        string outputSha1 = Sha1(integrity.RepairedImage);
        string outputSha256 = Sha256(integrity.RepairedImage);
        if (!string.Equals(outputSha1, ExpectedOutputSha1, StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(outputSha256, ExpectedOutputSha256, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                $"Native-primitive output hashes are SHA1 {outputSha1} / SHA256 " +
                $"{outputSha256}; the reviewed contract requires {ExpectedOutputSha1} / " +
                $"{ExpectedOutputSha256}");
        if (!string.Equals(
                integrity.Report.RepairedStoredFieldsHex, NativePrimitiveFieldsHex,
                StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Native-primitive integrity fields are " +
                $"{integrity.Report.RepairedStoredFieldsHex}; the reviewed contract requires " +
                $"{NativePrimitiveFieldsHex}");

        int[] finalDiff = ChangedOffsets(originalRom, integrity.RepairedImage);
        if (finalDiff.Length != 18 || !finalDiff.SequenceEqual(FinalChangedOffsets))
            throw new InvalidDataException(
                "Final native-primitive diff is not exactly the reviewed 18 changed offsets");
        if (!integrity.Report.UnrepairedChangedOffsets.SequenceEqual(
                UnrepairedChangedOffsets) ||
            !integrity.Report.RepairedChangedOffsets.SequenceEqual(FinalChangedOffsets))
            throw new InvalidDataException(
                "Native-primitive integrity report diff does not match the reviewed contract");
        if (!integrity.Report.RepairChangedOffsets.SequenceEqual(
                new[] { 0xFFD1, 0xFFD2, 0xFFD3, 0xFFD4, 0xFFD5 }))
            throw new InvalidDataException(
                "Native-primitive repair changed bytes outside FFD1-FFD5");

        ValidatePreservedBytes(originalRom, unrepaired, integrity.RepairedImage);
        ValidateHandlerSemantics(integrity.RepairedImage);

        var changes = new NativePrimitiveByteChange[finalDiff.Length];
        for (int index = 0; index < finalDiff.Length; index++)
        {
            int offset = finalDiff[index];
            changes[index] = new NativePrimitiveByteChange(
                offset, originalRom[offset], integrity.RepairedImage[offset]);
        }

        var provenance = new NativePrimitiveProvenance(
            ProposalId,
            ContractTaskId,
            definition.Provenance.ListingPath,
            definition.Provenance.ListingSha256,
            "static_compiled_native_primitive; original_rom_bytes; corrected_abi_contract; " +
            "prior_caller_reachability_only");

        NativePrimitiveSourceMap map = NativePrimitiveSourceMap.CreateForBuild(
            originalRom,
            integrity.RepairedImage,
            provenance);

        return new NativePrimitiveBuildResult(
            integrity.RepairedImage,
            unrepaired,
            payload,
            Sha1(originalRom),
            Sha256(originalRom),
            Sha1(unrepaired),
            Sha256(unrepaired),
            outputSha1,
            outputSha256,
            unrepairedDiff,
            finalDiff,
            integrity.Report.RepairChangedOffsets.ToArray(),
            changes,
            integrity.Report,
            map,
            provenance);
    }

    private static void ValidateOriginalContext(
        ReadOnlySpan<byte> rom, VmIlDefinition definition)
    {
        if (definition.HeaderAddress != OriginalDefinitionHeaderAddress ||
            definition.BodyStart != OriginalDefinitionBodyStart ||
            definition.BodyEndExclusive !=
            OriginalDefinitionBodyStart + OriginalDefinitionBodyLength ||
            !definition.HeaderBytes.SequenceEqual(new byte[] { 0x00, 0xF8 }))
            throw new InvalidDataException(
                "Certified 9ED9 definition header/body span does not match the reviewed source");
        if (!rom.Slice(OriginalDefinitionBodyStart, OriginalDefinitionBodyLength)
                .SequenceEqual(Convert.FromHexString(OriginalDefinitionBodyHex)))
            throw new InvalidDataException(
                "Original 9ED9 body bytes differ from the certified reviewed body");
        if (definition.Nodes.Count != 5)
            throw new InvalidDataException(
                $"Certified 9ED9 definition has {definition.Nodes.Count} nodes; expected 5");
        ushort[] expectedTokens = { 0x795B, 0x787E, 0x795B, 0x7AAF, 0x792F };
        if (!definition.Nodes.Select(node => node.Token).SequenceEqual(expectedTokens))
            throw new InvalidDataException(
                "Certified 9ED9 tokens differ from the preserved original sequence");
        if (!rom.Slice(CallerTokenAddress, 2).SequenceEqual(new byte[] { 0x9E, 0xD7 }))
            throw new InvalidDataException("Caller token at 9F14 is not the expected 9ED7");
        if (!rom.Slice(CallerSuccessorAddress, 2).SequenceEqual(new byte[] { 0x75, 0xA9 }))
            throw new InvalidDataException(
                "Caller successor token at 9F16 is not the expected 75A9");
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
                    $"Reviewed native-primitive allocation byte at {offset:X4} is " +
                    $"{rom[offset]:X2}; expected FF");
        }
    }

    private static void ValidatePayload(byte[] payload)
    {
        if (!string.Equals(Convert.ToHexString(payload), PayloadHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                "Native-primitive payload differs from the reviewed token and handler bytes");
        string handlerHex = Convert.ToHexString(payload.AsSpan(2, HandlerLength));
        if (!string.Equals(handlerHex, HandlerHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                "Native-primitive handler bytes differ from the reviewed handler");
        if (handlerHex.Contains("792F", StringComparison.Ordinal) ||
            Convert.ToHexString(payload.AsSpan(0, 2)) == "00F8")
            throw new InvalidDataException(
                "Native-primitive payload wrongly contains a composite header, PSHS/PULS " +
                "or the 792F return token");
        string instructions = string.Concat(Instructions.Select(item => item.BytesHex));
        if (!string.Equals(instructions, HandlerHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                "Native-primitive instruction boundaries do not cover the reviewed handler");
        foreach (NativePrimitiveHandlerInstruction instruction in Instructions)
        {
            int expectedNext = instruction.Address + instruction.BytesHex.Length / 2;
            if (instruction.NextAddress != expectedNext ||
                instruction.NextAddress > HandlerEndExclusive)
                throw new InvalidDataException(
                    $"Native-primitive instruction boundary {instruction.Address:X4} is invalid");
        }
        if (!Instructions[^1].BytesHex.EndsWith("0EFC", StringComparison.Ordinal))
            throw new InvalidDataException(
                "Native-primitive handler is missing the reviewed JMP $00FC ending");
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
                    $"Unrepaired native primitive changed byte {offset:X4} outside the " +
                    "allocation");
        }
        if (!unrepaired.Slice(CallerTokenAddress, 2)
                .SequenceEqual(original.Slice(CallerTokenAddress, 2)))
            throw new InvalidDataException(
                "Unrepaired native primitive pre-modified the caller token before the " +
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
                    $"Native-primitive output changed preserved byte {offset:X4}");
        }

        if (!output.Slice(ExtensionRangeAllocator.LeftGuardStart,
                ExtensionRangeAllocator.LeftGuardEnd -
                ExtensionRangeAllocator.LeftGuardStart + 1)
                .SequenceEqual(original.Slice(
                    ExtensionRangeAllocator.LeftGuardStart,
                    ExtensionRangeAllocator.LeftGuardEnd -
                    ExtensionRangeAllocator.LeftGuardStart + 1)))
            throw new InvalidDataException("Native-primitive output changed the left guard");
        if (!output.Slice(ExtensionRangeAllocator.RightGuardStart,
                ExtensionRangeAllocator.RightGuardEnd -
                ExtensionRangeAllocator.RightGuardStart + 1)
                .SequenceEqual(original.Slice(
                    ExtensionRangeAllocator.RightGuardStart,
                    ExtensionRangeAllocator.RightGuardEnd -
                    ExtensionRangeAllocator.RightGuardStart + 1)))
            throw new InvalidDataException("Native-primitive output changed the right guard");
        if (!output.Slice(0x1000, 4).SequenceEqual(original.Slice(0x1000, 4)))
            throw new InvalidDataException(
                "Native-primitive output changed the protected cells 1000-1003");
        if (!output.Slice(0x1400, 16).SequenceEqual(original.Slice(0x1400, 16)))
            throw new InvalidDataException(
                "Native-primitive output changed the 1400-140F integrity neighbour");
        if (!output.Slice(OriginalDefinitionHeaderAddress, 16)
                .SequenceEqual(original.Slice(OriginalDefinitionHeaderAddress, 16)))
            throw new InvalidDataException(
                "Native-primitive output changed the original 9ED7 header or 9ED9 body");
        if (!output.Slice(CallerSuccessorAddress, 2)
                .SequenceEqual(original.Slice(CallerSuccessorAddress, 2)))
            throw new InvalidDataException(
                "Native-primitive output changed the caller successor token at 9F16");
        if (!output.Slice(ParentTokenAddress, 2)
                .SequenceEqual(original.Slice(ParentTokenAddress, 2)) ||
            !output.Slice(ParentSuccessorAddress, 2)
                .SequenceEqual(original.Slice(ParentSuccessorAddress, 2)))
            throw new InvalidDataException(
                "Native-primitive output changed the outer return context 9F3D/9F3F");
        if (!output.Slice(0x7927, 8)
                .SequenceEqual(original.Slice(0x7927, 8)))
            throw new InvalidDataException(
                "Native-primitive output changed the runtime dispatch template");
        if (!unrepaired.Slice(OriginalDefinitionHeaderAddress, 16)
                .SequenceEqual(original.Slice(OriginalDefinitionHeaderAddress, 16)))
            throw new InvalidDataException(
                "Unrepaired native primitive changed the original 9ED7/9ED9 definition");
    }

    private static void ValidateHandlerSemantics(ReadOnlySpan<byte> output)
    {
        if (!output.Slice(TokenAddress, 2)
                .SequenceEqual(Convert.FromHexString(TokenHex)))
            throw new InvalidDataException(
                "Native-primitive token cell at 1010 is not 1012");
        if (!output.Slice(HandlerStart, HandlerLength)
                .SequenceEqual(Convert.FromHexString(HandlerHex)))
            throw new InvalidDataException(
                "Native-primitive handler at 1012-101A differs from the reviewed bytes");
        string handlerHex = Convert.ToHexString(output.Slice(HandlerStart, HandlerLength));
        if (handlerHex.Contains("34", StringComparison.Ordinal) ||
            handlerHex.Contains("35", StringComparison.Ordinal) ||
            handlerHex.Contains("792F", StringComparison.Ordinal))
            throw new InvalidDataException(
                "Native-primitive handler contains PSHS/PULS or the 792F return token");
        if (!handlerHex.EndsWith("0EFC", StringComparison.Ordinal))
            throw new InvalidDataException(
                "Native-primitive handler does not end with JMP $00FC");
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

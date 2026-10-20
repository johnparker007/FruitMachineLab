using System.Collections.ObjectModel;
using System.Security.Cryptography;

namespace FruitMachineLab.Il;

public enum LampPatternMapKind
{
    Header,
    Body,
    CallerToken,
    CallerSuccessor,
    ParentToken,
    ParentSuccessor,
    ServiceBoundary
}

public sealed record LampPatternMapEntry(
    ushort Address,
    LampPatternMapKind Kind,
    int? NodeIndex,
    ushort Token,
    ushort? ReplacementToken,
    string Operation,
    ushort? HandlerAddress,
    LampPatternOperandKind OperandKind,
    ushort? OperandAddress,
    ushort? OperandValue,
    bool IsFinalReturn,
    byte ImageByte);

public sealed record LampPatternInlineOperand(
    int NodeIndex,
    ushort Address,
    ushort Value,
    int Width,
    LampPatternOperandKind Kind);

public sealed record LampPatternStaticPhase(
    string Phase,
    string Classification,
    ushort Pc,
    ushort? X,
    ushort Y,
    ushort Token,
    ushort? ReplacementToken,
    ushort? HandlerAddress,
    LampPatternOperandKind OperandKind,
    ushort? OperandAddress,
    ushort? OperandValue,
    int U,
    int S,
    int URelativeToEntry,
    int SRelativeToEntry,
    ushort? SavedCursor,
    ushort? NextY,
    string Boundary);

public sealed record LampPatternCallerBinding(
    ushort TokenAddress,
    ushort OriginalToken,
    ushort ReplacementToken,
    ushort HeaderAddress,
    ushort HeaderValue,
    ushort BodyStart,
    int BodyEndExclusive,
    ushort OuterSavedReturnCursor,
    ushort SharedSavedReturnCursor,
    ushort PostReturnTokenAddress,
    ushort PostReturnToken,
    ushort ParentTokenAddress,
    ushort ParentToken,
    ushort ParentSuccessorAddress,
    ushort ParentSuccessorToken,
    ushort FinalReturnAddress,
    ushort ReturnHandlerAddress);

public sealed record LampPatternSemanticContract(
    string StackEffect,
    int BodyUNet,
    int EntryDepth,
    int ExitDepth,
    int WholeCallSNet,
    ushort DeepestS,
    int DeepestSRelativeToEntry,
    ushort SharedSavedCursor,
    ushort OuterSavedCursor,
    bool NestedCall,
    string ResultPreservation,
    string ServiceClobbers,
    string Classification);

public sealed record LampPatternServiceBoundary(
    string Name,
    ushort Start,
    ushort EndInclusive,
    string BytesHex,
    string Role,
    string Classification);

public sealed class LampPatternSourceMap
{
    public const string PhaseClassification = "static_prediction_not_execution";
    public const string BuildClassification =
        "static_lamp_pattern_map_bound_to_exact_output_sha256";

    private readonly ReadOnlyCollection<LampPatternMapEntry> _entries;
    private readonly ReadOnlyCollection<LampPatternInlineOperand> _inlineOperands;
    private readonly ReadOnlyCollection<LampPatternNode> _nodes;
    private readonly ReadOnlyCollection<LampPatternStaticPhase> _phases;
    private readonly ReadOnlyCollection<LampPatternServiceBoundary> _boundaries;
    private readonly LampPatternVariant _variant;
    private readonly string _classification;

    private LampPatternSourceMap(
        string originalRomSha1,
        string originalRomSha256,
        string outputImageSha1,
        string outputImageSha256,
        LampPatternNode[] nodes,
        LampPatternMapEntry[] entries,
        LampPatternInlineOperand[] inlineOperands,
        LampPatternStaticPhase[] phases,
        LampPatternServiceBoundary[] boundaries,
        LampPatternCallerBinding caller,
        LampPatternSemanticContract semantics,
        LampPatternStaticContract staticContract,
        LampPatternProvenance provenance,
        LampPatternVariant variant)
    {
        OriginalRomSha1 = originalRomSha1;
        OriginalRomSha256 = originalRomSha256;
        OutputImageSha1 = outputImageSha1;
        OutputImageSha256 = outputImageSha256;
        _nodes = Array.AsReadOnly((LampPatternNode[])nodes.Clone());
        _entries = Array.AsReadOnly((LampPatternMapEntry[])entries.Clone());
        _inlineOperands =
            Array.AsReadOnly((LampPatternInlineOperand[])inlineOperands.Clone());
        _phases = Array.AsReadOnly((LampPatternStaticPhase[])phases.Clone());
        _boundaries =
            Array.AsReadOnly((LampPatternServiceBoundary[])boundaries.Clone());
        Caller = caller;
        Semantics = semantics;
        StaticContract = staticContract;
        Provenance = provenance;
        _variant = variant ?? throw new ArgumentNullException(nameof(variant));
        _classification = variant.Classification;
    }

    public string OriginalRomSha1 { get; }

    public string OriginalRomSha256 { get; }

    public string OutputImageSha1 { get; }

    public string OutputImageSha256 { get; }

    public string BuildId => OutputImageSha256;

    public ushort HeaderAddress => LampPatternWordBuilder.HeaderAddress;

    public string HeaderHex => LampPatternWordBuilder.HeaderHex;

    public ushort BodyStart => LampPatternWordBuilder.BodyStart;

    public int BodyEndExclusive => LampPatternWordBuilder.BodyEndExclusive;

    public int AllocationEndInclusive => LampPatternWordBuilder.AllocationEndInclusive;

    public ReadOnlyCollection<LampPatternNode> Nodes => _nodes;

    public ReadOnlyCollection<LampPatternMapEntry> Entries => _entries;

    public ReadOnlyCollection<LampPatternInlineOperand> InlineOperands =>
        _inlineOperands;

    public ReadOnlyCollection<LampPatternStaticPhase> Phases => _phases;

    public ReadOnlyCollection<LampPatternServiceBoundary> Boundaries => _boundaries;

    public LampPatternCallerBinding Caller { get; }

    public LampPatternSemanticContract Semantics { get; }

    public LampPatternStaticContract StaticContract { get; }

    public LampPatternProvenance Provenance { get; }

    public string Classification => _classification;

    public LampPatternMapEntry Resolve(ushort address)
    {
        foreach (LampPatternMapEntry entry in _entries)
        {
            if (entry.Address == address)
                return entry;
        }
        throw new KeyNotFoundException(
            $"Lamp-pattern source map has no entry for address {address:X4}");
    }

    public LampPatternMapEntry Resolve(ushort address, string outputImageSha256)
    {
        ValidateBuild(outputImageSha256);
        return Resolve(address);
    }

    public LampPatternMapEntry Resolve(ushort address, ReadOnlySpan<byte> outputImage)
    {
        ValidateImage(outputImage);
        LampPatternMapEntry entry = Resolve(address);
        if (entry.ImageByte != outputImage[address])
            throw new InvalidDataException(
                $"Lamp-pattern source-map byte at {address:X4} is {entry.ImageByte:X2}; " +
                $"the bound image contains {outputImage[address]:X2}");
        return entry;
    }

    public LampPatternServiceBoundary ResolveBoundary(string name)
    {
        foreach (LampPatternServiceBoundary boundary in _boundaries)
        {
            if (string.Equals(boundary.Name, name, StringComparison.Ordinal))
                return boundary;
        }
        throw new KeyNotFoundException(
            $"Lamp-pattern source map has no service boundary named '{name}'");
    }

    public void ValidateBuild(string outputImageSha256)
    {
        if (!string.Equals(
                outputImageSha256, OutputImageSha256, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                $"Lamp-pattern source-map build identity mismatch: map is bound to " +
                $"{OutputImageSha256}, not {outputImageSha256}");
    }

    public void ValidateImage(ReadOnlySpan<byte> outputImage)
    {
        if (outputImage.Length != 0x10000)
            throw new InvalidDataException(
                $"Lamp-pattern source-map image length {outputImage.Length} differs from " +
                "65536");
        string sha256 = Sha256(outputImage);
        ValidateBuild(sha256);

        if (!outputImage.Slice(LampPatternWordBuilder.HeaderAddress, 2)
                .SequenceEqual(Convert.FromHexString(LampPatternWordBuilder.HeaderHex)))
            throw new InvalidDataException(
                "Lamp-pattern source-map image header at 1010 is not 00F8");
        if (!outputImage.Slice(
                LampPatternWordBuilder.BodyStart,
                LampPatternWordBuilder.BodyEndExclusive - LampPatternWordBuilder.BodyStart)
                .SequenceEqual(Convert.FromHexString(_variant.BodyHex)))
            throw new InvalidDataException(
                "Lamp-pattern source-map body at 1012-1027 differs from the reviewed body");
        if (!outputImage.Slice(
                LampPatternWordBuilder.CallerTokenAddress, 2)
                .SequenceEqual(Convert.FromHexString("1010")))
            throw new InvalidDataException(
                "Lamp-pattern source-map caller token at 9F14 is not 1010");
        if (!outputImage.Slice(
                LampPatternWordBuilder.CallerSuccessorAddress, 2)
                .SequenceEqual(Convert.FromHexString("75A9")))
            throw new InvalidDataException(
                "Lamp-pattern source-map caller successor at 9F16 is not 75A9");
        if (!outputImage.Slice(0x9ED7, 16)
                .SequenceEqual(Convert.FromHexString(
                    "00F8" + LampPatternWordBuilder.OriginalBodyHex)))
            throw new InvalidDataException(
                "Lamp-pattern source-map output changed the original 9ED7/9ED9 definition");
        if (!outputImage.Slice(
                LampPatternWordBuilder.ParentTokenAddress, 2)
                .SequenceEqual(Convert.FromHexString("9F10")) ||
            !outputImage.Slice(
                LampPatternWordBuilder.ParentSuccessorAddress, 2)
                .SequenceEqual(Convert.FromHexString("792F")))
            throw new InvalidDataException(
                "Lamp-pattern source-map parent context at 9F3D/9F3F differs");

        if (!outputImage.Slice(
                LampPatternWordBuilder.ServiceCellAddress,
                LampPatternWordBuilder.SharedCallCellHex.Length / 2)
                .SequenceEqual(Convert.FromHexString(
                    LampPatternWordBuilder.SharedCallCellHex)))
            throw new InvalidDataException(
                "Lamp-pattern source-map shared service cell 9C44 is not 9B1572BF");
        if (!outputImage.Slice(
                LampPatternWordBuilder.SharedBodyAddress,
                LampPatternWordBuilder.SharedBodyEndExclusive -
                LampPatternWordBuilder.SharedBodyAddress)
                .SequenceEqual(Convert.FromHexString(
                    LampPatternWordBuilder.SharedBodyHex)))
            throw new InvalidDataException(
                "Lamp-pattern source-map shared body 9B18 differs from the reviewed bytes");
        if (!outputImage.Slice(
                LampPatternWordBuilder.ByteLiteralTokenAddress,
                LampPatternWordBuilder.ByteLiteralCellHex.Length / 2)
                .SequenceEqual(Convert.FromHexString(
                    LampPatternWordBuilder.ByteLiteralCellHex)))
            throw new InvalidDataException(
                "Lamp-pattern source-map byte literal cell 7963 differs from the reviewed bytes");
        if (!outputImage.Slice(
                LampPatternWordBuilder.TableAddress,
                LampPatternWordBuilder.TableLength)
                .SequenceEqual(Convert.FromHexString(LampPatternWordBuilder.TableHex)))
            throw new InvalidDataException(
                "Lamp-pattern source-map lamp table 72BF differs from the reviewed bytes");

        ushort finalToken = ReadWord(outputImage, 0x1026);
        if (finalToken != VmIlVocabulary.ReturnToCallerStream)
            throw new InvalidDataException(
                "Lamp-pattern source-map final body token at 1026 is not 792F");

        foreach (LampPatternMapEntry entry in _entries)
        {
            if (entry.ImageByte != outputImage[entry.Address])
                throw new InvalidDataException(
                    $"Lamp-pattern source-map byte at {entry.Address:X4} is " +
                    $"{entry.ImageByte:X2}; the bound image contains " +
                    $"{outputImage[entry.Address]:X2}");
        }

        foreach (LampPatternInlineOperand operand in _inlineOperands)
        {
            if (operand.Width == 2)
            {
                ushort encoded = ReadWord(outputImage, operand.Address);
                if (encoded != operand.Value)
                    throw new InvalidDataException(
                        $"Lamp-pattern inline word operand at {operand.Address:X4} is " +
                        $"{encoded:X4}; expected {operand.Value:X4}");
            }
            else
            {
                byte encoded = outputImage[operand.Address];
                if (encoded != (byte)operand.Value)
                    throw new InvalidDataException(
                        $"Lamp-pattern inline byte operand at {operand.Address:X4} is " +
                        $"{encoded:X2}; expected {operand.Value:X2}");
            }
        }

        foreach (LampPatternServiceBoundary boundary in _boundaries)
        {
            byte[] expected = Convert.FromHexString(boundary.BytesHex);
            if (!outputImage.Slice(boundary.Start, expected.Length)
                    .SequenceEqual(expected))
                throw new InvalidDataException(
                    $"Lamp-pattern source-map service boundary '{boundary.Name}' at " +
                    $"{boundary.Start:X4}-{boundary.EndInclusive:X4} differs from the bound " +
                    "image");
        }
    }

    internal static LampPatternSourceMap CreateForBuild(
        ReadOnlySpan<byte> originalRom,
        ReadOnlySpan<byte> outputImage,
        LampPatternNode[] nodes,
        LampPatternStaticContract staticContract,
        LampPatternProvenance provenance) =>
        CreateForBuild(
            originalRom,
            outputImage,
            nodes,
            staticContract,
            provenance,
            LampPatternWordBuilder.VariantEightF);

    internal static LampPatternSourceMap CreateForBuild(
        ReadOnlySpan<byte> originalRom,
        ReadOnlySpan<byte> outputImage,
        LampPatternNode[] nodes,
        LampPatternStaticContract staticContract,
        LampPatternProvenance provenance,
        LampPatternVariant variant)
    {
        VmIlDefinition originalDefinition =
            LampPatternWordBuilder.ValidateOriginalSource(originalRom);
        LampPatternWordBuilder.ValidateServiceContract(originalRom);
        if (outputImage.Length != originalRom.Length)
            throw new InvalidDataException(
                "Lamp-pattern source-map image length differs from the original ROM");
        if (nodes is null || nodes.Length != LampPatternWordBuilder.NodeCount)
            throw new InvalidDataException(
                "Lamp-pattern source map requires the eight reviewed body nodes");

        ValidateSource(originalRom, outputImage, nodes, variant);

        var entries = new List<LampPatternMapEntry>(64);
        entries.Add(new LampPatternMapEntry(
            LampPatternWordBuilder.HeaderAddress,
            LampPatternMapKind.Header,
            null,
            LampPatternWordBuilder.HeaderValue,
            null,
            "definition-header-00f8",
            null,
            LampPatternOperandKind.None,
            null,
            null,
            false,
            outputImage[LampPatternWordBuilder.HeaderAddress]));
        entries.Add(new LampPatternMapEntry(
            LampPatternWordBuilder.HeaderAddress + 1,
            LampPatternMapKind.Header,
            null,
            LampPatternWordBuilder.HeaderValue,
            null,
            "definition-header-00f8",
            null,
            LampPatternOperandKind.None,
            null,
            null,
            false,
            outputImage[LampPatternWordBuilder.HeaderAddress + 1]));

        var inlineOperands = new List<LampPatternInlineOperand>(
            LampPatternWordBuilder.InlineOperandCount);
        for (int index = 0; index < nodes.Length; index++)
        {
            LampPatternNode node = nodes[index];
            if (node.OperandAddress is ushort operandAddress &&
                node.OperandValue is ushort operandValue)
            {
                int width = node.OperandKind == LampPatternOperandKind.Word ? 2 : 1;
                inlineOperands.Add(new LampPatternInlineOperand(
                    index, operandAddress, operandValue, width, node.OperandKind));
            }

            byte[] nodeBytes = Convert.FromHexString(node.BytesHex);
            for (int byteIndex = 0; byteIndex < nodeBytes.Length; byteIndex++)
            {
                int address = node.Address + byteIndex;
                bool isOperand = node.OperandAddress is ushort operand &&
                                 address >= operand &&
                                 address < operand + (node.OperandKind ==
                                     LampPatternOperandKind.Word ? 2 : 1);
                LampPatternOperandKind entryKind = isOperand
                    ? node.OperandKind
                    : node.Token == LampPatternWordBuilder.SharedCallToken
                        ? LampPatternOperandKind.ServiceOwnedNoCallerOperand
                        : LampPatternOperandKind.None;
                entries.Add(new LampPatternMapEntry(
                    checked((ushort)address),
                    LampPatternMapKind.Body,
                    index,
                    node.Token,
                    null,
                    node.Operation,
                    node.HandlerAddress,
                    entryKind,
                    isOperand ? node.OperandAddress : null,
                    isOperand ? node.OperandValue : null,
                    node.Token == VmIlVocabulary.ReturnToCallerStream,
                    outputImage[address]));
            }
        }
        entries.Add(new LampPatternMapEntry(
            LampPatternWordBuilder.CallerTokenAddress,
            LampPatternMapKind.CallerToken,
            null,
            LampPatternWordBuilder.CallerOriginalToken,
            LampPatternWordBuilder.CallerReplacementToken,
            "caller-token-redirect",
            null,
            LampPatternOperandKind.None,
            null,
            null,
            false,
            outputImage[LampPatternWordBuilder.CallerTokenAddress]));
        entries.Add(new LampPatternMapEntry(
            LampPatternWordBuilder.CallerTokenAddress + 1,
            LampPatternMapKind.CallerToken,
            null,
            LampPatternWordBuilder.CallerOriginalToken,
            LampPatternWordBuilder.CallerReplacementToken,
            "caller-token-redirect",
            null,
            LampPatternOperandKind.None,
            null,
            null,
            false,
            outputImage[LampPatternWordBuilder.CallerTokenAddress + 1]));
        entries.Add(new LampPatternMapEntry(
            LampPatternWordBuilder.CallerSuccessorAddress,
            LampPatternMapKind.CallerSuccessor,
            null,
            LampPatternWordBuilder.CallerSuccessorToken,
            null,
            "caller-successor-token",
            null,
            LampPatternOperandKind.None,
            null,
            null,
            false,
            outputImage[LampPatternWordBuilder.CallerSuccessorAddress]));
        entries.Add(new LampPatternMapEntry(
            LampPatternWordBuilder.CallerSuccessorAddress + 1,
            LampPatternMapKind.CallerSuccessor,
            null,
            LampPatternWordBuilder.CallerSuccessorToken,
            null,
            "caller-successor-token",
            null,
            LampPatternOperandKind.None,
            null,
            null,
            false,
            outputImage[LampPatternWordBuilder.CallerSuccessorAddress + 1]));
        entries.Add(new LampPatternMapEntry(
            LampPatternWordBuilder.ParentTokenAddress,
            LampPatternMapKind.ParentToken,
            null,
            LampPatternWordBuilder.ParentToken,
            null,
            "parent-token-context",
            null,
            LampPatternOperandKind.None,
            null,
            null,
            false,
            outputImage[LampPatternWordBuilder.ParentTokenAddress]));
        entries.Add(new LampPatternMapEntry(
            LampPatternWordBuilder.ParentTokenAddress + 1,
            LampPatternMapKind.ParentToken,
            null,
            LampPatternWordBuilder.ParentToken,
            null,
            "parent-token-context",
            null,
            LampPatternOperandKind.None,
            null,
            null,
            false,
            outputImage[LampPatternWordBuilder.ParentTokenAddress + 1]));
        entries.Add(new LampPatternMapEntry(
            LampPatternWordBuilder.ParentSuccessorAddress,
            LampPatternMapKind.ParentSuccessor,
            null,
            LampPatternWordBuilder.ParentSuccessorToken,
            null,
            "parent-successor-context",
            null,
            LampPatternOperandKind.None,
            null,
            null,
            false,
            outputImage[LampPatternWordBuilder.ParentSuccessorAddress]));
        entries.Add(new LampPatternMapEntry(
            LampPatternWordBuilder.ParentSuccessorAddress + 1,
            LampPatternMapKind.ParentSuccessor,
            null,
            LampPatternWordBuilder.ParentSuccessorToken,
            null,
            "parent-successor-context",
            null,
            LampPatternOperandKind.None,
            null,
            null,
            false,
            outputImage[LampPatternWordBuilder.ParentSuccessorAddress + 1]));

        LampPatternServiceBoundary[] boundaries = BuildBoundaries(outputImage);
        foreach (LampPatternServiceBoundary boundary in boundaries)
        {
            entries.Add(new LampPatternMapEntry(
                boundary.Start,
                LampPatternMapKind.ServiceBoundary,
                null,
                0,
                null,
                boundary.Name,
                null,
                LampPatternOperandKind.None,
                null,
                null,
                false,
                outputImage[boundary.Start]));
        }

        var caller = new LampPatternCallerBinding(
            LampPatternWordBuilder.CallerTokenAddress,
            LampPatternWordBuilder.CallerOriginalToken,
            LampPatternWordBuilder.CallerReplacementToken,
            LampPatternWordBuilder.HeaderAddress,
            LampPatternWordBuilder.HeaderValue,
            LampPatternWordBuilder.BodyStart,
            LampPatternWordBuilder.BodyEndExclusive,
            LampPatternWordBuilder.OuterSavedCursor,
            LampPatternWordBuilder.SharedSavedCursor,
            LampPatternWordBuilder.CallerSuccessorAddress,
            LampPatternWordBuilder.CallerSuccessorToken,
            LampPatternWordBuilder.ParentTokenAddress,
            LampPatternWordBuilder.ParentToken,
            LampPatternWordBuilder.ParentSuccessorAddress,
            LampPatternWordBuilder.ParentSuccessorToken,
            0x1026,
            0x7931);

        var semantics = new LampPatternSemanticContract(
            "relative to the 9F14 context U=066E S=0798: outer body S=0796; shared body " +
            "entry U=0668 S=0794; after add U=066A; bridge entry U=066A S=0794; 7791 " +
            "PULU D U=066C; 77A0 LEAU 2,U U=066E before 777A PSHS Y/JSR; native entry " +
            "S=0790 and prologue deepest S=078A; native exit S=0792; PULS Y S=0794; " +
            "shared return to 1026 S=0796; outer return to 9F16 S=0798",
            staticContract.BodyUNet,
            staticContract.EntryDepth,
            staticContract.ExitDepth,
            staticContract.WholeCallSNet,
            staticContract.DeepestS,
            staticContract.DeepestSRelativeToEntry,
            staticContract.SharedSavedCursor,
            staticContract.OuterSavedCursor,
            staticContract.NestedCall,
            staticContract.ResultPreservation,
            staticContract.ServiceClobbers,
            LampPatternSourceMap.PhaseClassification);

        var phases = BuildPhases(nodes, staticContract, originalRom, variant);

        var map = new LampPatternSourceMap(
            Sha1(originalRom),
            Sha256(originalRom),
            Sha1(outputImage),
            Sha256(outputImage),
            nodes,
            entries.ToArray(),
            inlineOperands.ToArray(),
            phases,
            boundaries,
            caller,
            semantics,
            staticContract,
            provenance,
            variant);
        map.ValidateImage(outputImage);
        return map;
    }

    private static void ValidateSource(
        ReadOnlySpan<byte> originalRom,
        ReadOnlySpan<byte> outputImage,
        LampPatternNode[] nodes,
        LampPatternVariant variant)
    {
        if (!outputImage.Slice(
                LampPatternWordBuilder.HeaderAddress, 2)
                .SequenceEqual(Convert.FromHexString(
                    LampPatternWordBuilder.HeaderHex)))
            throw new InvalidDataException(
                "Lamp-pattern source-map requires header 00F8 at 1010");
        if (!outputImage.Slice(
                LampPatternWordBuilder.BodyStart,
                LampPatternWordBuilder.BodyEndExclusive -
                LampPatternWordBuilder.BodyStart)
                .SequenceEqual(Convert.FromHexString(
                    variant.BodyHex)))
            throw new InvalidDataException(
                "Lamp-pattern source-map requires the reviewed body at 1012-1027");
        if (!outputImage.Slice(
                LampPatternWordBuilder.CallerTokenAddress, 2)
                .SequenceEqual(new byte[] { 0x10, 0x10 }))
            throw new InvalidDataException(
                "Lamp-pattern source-map requires caller token 1010 at 9F14");
        if (!outputImage.Slice(
                LampPatternWordBuilder.CallerSuccessorAddress, 2)
                .SequenceEqual(new byte[] { 0x75, 0xA9 }))
            throw new InvalidDataException(
                "Lamp-pattern source-map requires successor 75A9 at 9F16");
        if (!originalRom.Slice(
                LampPatternWordBuilder.OriginalBodyStart,
                LampPatternWordBuilder.OriginalBodyEndExclusive -
                LampPatternWordBuilder.OriginalBodyStart)
                .SequenceEqual(Convert.FromHexString(
                    LampPatternWordBuilder.OriginalBodyHex)))
            throw new InvalidDataException(
                "Original 9ED9 body differs from the reviewed certified body");

        ushort[] expectedAddresses =
        {
            0x1012, 0x1016, 0x1018, 0x101C, 0x101E, 0x1021, 0x1024, 0x1026
        };
        ushort[] expectedTokens =
        {
            0x795B, 0x787E, 0x795B, 0x7AAF, 0x7963, 0x7963, 0x9C44, 0x792F
        };
        int cursor = LampPatternWordBuilder.BodyStart;
        for (int index = 0; index < nodes.Length; index++)
        {
            LampPatternNode node = nodes[index];
            if (node.Index != index ||
                node.Address != expectedAddresses[index] ||
                node.Token != expectedTokens[index])
                throw new InvalidDataException(
                    $"Lamp-pattern source-map node {index} does not match the reviewed body");
            if (node.Address != cursor)
                throw new InvalidDataException(
                    $"Lamp-pattern source-map node {index} at {node.Address:X4} does not " +
                    $"follow cursor {cursor:X4}");
            byte[] bytes = Convert.FromHexString(node.BytesHex);
            if (!outputImage.Slice(node.Address, bytes.Length).SequenceEqual(bytes))
                throw new InvalidDataException(
                    $"Lamp-pattern source-map node {index} bytes differ from the output image");
            if (node.OperandAddress is ushort operandAddress)
            {
                int width = node.OperandKind == LampPatternOperandKind.Word ? 2 : 1;
                if (operandAddress != node.Address + 2 ||
                    operandAddress + width > LampPatternWordBuilder.BodyEndExclusive)
                    throw new InvalidDataException(
                        $"Lamp-pattern source-map node {index} operand is outside the body");
                ushort encoded = width == 2
                    ? ReadWord(outputImage, operandAddress)
                    : outputImage[operandAddress];
                if (node.OperandValue != encoded)
                    throw new InvalidDataException(
                        $"Lamp-pattern source-map node {index} operand value differs");
            }
            cursor += bytes.Length;
        }
        if (cursor != LampPatternWordBuilder.BodyEndExclusive)
            throw new InvalidDataException(
                "Lamp-pattern source-map node sequence does not cover the full body");
    }

    private static LampPatternServiceBoundary[] BuildBoundaries(
        ReadOnlySpan<byte> image)
    {
        return new[]
        {
            new LampPatternServiceBoundary(
                "caller-shared-token", 0x1024, 0x1025, "9C44",
                "Two-byte caller-stream shared call token with zero caller operands.",
                PhaseClassification),
            new LampPatternServiceBoundary(
                "shared-cell", LampPatternWordBuilder.ServiceCellAddress,
                LampPatternWordBuilder.ServiceCellAddress + 3,
                LampPatternWordBuilder.SharedCallCellHex,
                "Service cell: handler 9B15 at 9C44 and service-owned 72BF pointer at " +
                "9C46. The handler=token+2 rule does not apply.",
                PhaseClassification),
            new LampPatternServiceBoundary(
                "handler-entry", LampPatternWordBuilder.SharedCallHandlerAddress,
                LampPatternWordBuilder.SharedCallHandlerAddress + 2, "BD796E",
                "JSR 796E at the resolved 9C44 handler.",
                PhaseClassification),
            new LampPatternServiceBoundary(
                "shared-body", LampPatternWordBuilder.SharedBodyAddress,
                checked((ushort)(LampPatternWordBuilder.SharedBodyAddress +
                LampPatternWordBuilder.SharedBodyHex.Length / 2 - 1)),
                LampPatternWordBuilder.SharedBodyHex,
                "9B18 shared body: fetch 9C46, rotate, add, fetch table byte, swap, " +
                "bridge, return.",
                PhaseClassification),
            new LampPatternServiceBoundary(
                "trampoline", LampPatternWordBuilder.TrampolineAddress,
                checked((ushort)(LampPatternWordBuilder.TrampolineAddress +
                LampPatternWordBuilder.TrampolineHex.Length / 2 - 1)),
                LampPatternWordBuilder.TrampolineHex,
                "796E trampoline pushes X, replaces the JSR return with the outer cursor " +
                "and jumps to the shared body.",
                PhaseClassification),
            new LampPatternServiceBoundary(
                "service-pointer", LampPatternWordBuilder.ServicePointerAddress,
                LampPatternWordBuilder.ServicePointerAddress + 1,
                LampPatternWordBuilder.ServicePointerValue.ToString("X4"),
                "Service-owned 72BF lamp table pointer. It is not a caller inline operand.",
                PhaseClassification),
            new LampPatternServiceBoundary(
                "bridge-cell", LampPatternWordBuilder.BridgeCellAddress,
                LampPatternWordBuilder.BridgeCellAddress + 3,
                LampPatternWordBuilder.BridgeCellHex,
                "8050 bridge cell pointing to 7791 and 49C5.",
                PhaseClassification),
            new LampPatternServiceBoundary(
                "bridge-entry", LampPatternWordBuilder.BridgeEntryAddress,
                checked((ushort)(LampPatternWordBuilder.BridgeEntryAddress +
                LampPatternWordBuilder.BridgeEntryHex.Length / 2 - 1)),
                LampPatternWordBuilder.BridgeEntryHex,
                "7791-77A3 bridge entry: pop pattern, access 00F1/080C, load index low " +
                "byte, discard index and continue at 777A.",
                PhaseClassification),
            new LampPatternServiceBoundary(
                "bridge-continuation", LampPatternWordBuilder.BridgeContinuationAddress,
                checked((ushort)(LampPatternWordBuilder.BridgeContinuationAddress +
                LampPatternWordBuilder.BridgeContinuationHex.Length / 2 - 1)),
                LampPatternWordBuilder.BridgeContinuationHex,
                "777A-778C bridge continuation: save Y, JSR the native service, restore " +
                "Y, access 00F1/080C and jump to the saved body cursor.",
                PhaseClassification),
            new LampPatternServiceBoundary(
                "native-service", LampPatternWordBuilder.NativeServiceAddress,
                LampPatternWordBuilder.NativeServiceEndInclusive,
                LampPatternWordBuilder.NativeServiceHex,
                "49C5-4A24 original native lamp service preserving A/B/X, updating one " +
                "mask bit in each of the four frame banks.",
                PhaseClassification),
            new LampPatternServiceBoundary(
                "byte-literal-cell", LampPatternWordBuilder.ByteLiteralTokenAddress,
                checked((ushort)(LampPatternWordBuilder.ByteLiteralTokenAddress +
                LampPatternWordBuilder.ByteLiteralCellHex.Length / 2 - 1)),
                LampPatternWordBuilder.ByteLiteralCellHex,
                "7963 cell points to 7965; the handler consumes exactly one inline byte.",
                PhaseClassification),
            new LampPatternServiceBoundary(
                "lamp-table", LampPatternWordBuilder.TableAddress,
                LampPatternWordBuilder.TableAddress + LampPatternWordBuilder.TableLength - 1,
                LampPatternWordBuilder.TableHex,
                "72BF 48-cell logical lamp-ID table reused by the service.",
                PhaseClassification)
        };
    }

    private static LampPatternStaticPhase[] BuildPhases(
        LampPatternNode[] nodes,
        LampPatternStaticContract contract,
        ReadOnlySpan<byte> originalRom,
        LampPatternVariant variant)
    {
        var phases = new List<LampPatternStaticPhase>(44);

        void Add(
            string phase,
            ushort pc,
            ushort? x,
            ushort y,
            ushort token,
            ushort? replacementToken,
            ushort? handler,
            LampPatternOperandKind operandKind,
            ushort? operandAddress,
            ushort? operandValue,
            string step,
            ushort? savedCursor,
            ushort? nextY,
            string boundary)
        {
            LampPatternStackStep stack = contract.StackSteps.Single(
                item => string.Equals(item.Phase, step, StringComparison.Ordinal));
            phases.Add(new LampPatternStaticPhase(
                phase,
                PhaseClassification,
                pc,
                x,
                y,
                token,
                replacementToken,
                handler,
                operandKind,
                operandAddress,
                operandValue,
                stack.U,
                stack.S,
                stack.URelativeToEntry,
                stack.SRelativeToEntry,
                savedCursor,
                nextY,
                boundary));
        }

        Add(
            "caller-dispatch", 0x00FC, null, 0x9F14, 0x9ED7, 0x1010, null,
            LampPatternOperandKind.None, null, null, "caller-dispatch", null, 0x9F16,
            "Before LDX ,Y++ at 00FC; the caller token 9ED7 at 9F14 is replaced by 1010.");
        Add(
            "header-trampoline-entry", 0x00F8, 0x1012, 0x9F16, 0x00F8, null, null,
            LampPatternOperandKind.None, null, null, "header-trampoline-entry", 0x9F16,
            0x1012, "At the 00F8 header before PSHS Y; X=1012 token+2, Y=9F16; the " +
            "saved cursor is 9F16.");

        for (int index = 0; index < 6; index++)
        {
            LampPatternNode node = nodes[index];
            int operandBytes = node.OperandKind switch
            {
                LampPatternOperandKind.Word => 2,
                LampPatternOperandKind.Byte => 1,
                _ => 0
            };
            ushort prefetchX = index == 0
                ? checked((ushort)(LampPatternWordBuilder.HeaderAddress + 2))
                : nodes[index - 1].HandlerAddress;
            Add(
                $"body-prefetch-{index}", 0x00FC, prefetchX, node.Address, node.Token,
                null, node.HandlerAddress, node.OperandKind, node.OperandAddress,
                node.OperandValue, $"body-prefetch-{index}", null,
                checked((ushort)(node.Address + 2)),
                $"NEXT prefetch at 00FC before LDX ,Y++; X={prefetchX:X4} is the " +
                $"previous dispatch pointer, Y={node.Address:X4}, body token " +
                $"{node.Token:X4}.");
            Add(
                $"handler-{index}", node.HandlerAddress,
                checked((ushort)(node.Token + 2)), checked((ushort)(node.Address + 2)),
                node.Token, null, node.HandlerAddress, node.OperandKind,
                node.OperandAddress, node.OperandValue, $"handler-{index}", null,
                checked((ushort)(node.Address + 2 + operandBytes)),
                $"PRE-handler boundary at {node.HandlerAddress:X4}; X={node.Token + 2:X4} " +
                $"(token cell + 2), Y={node.Address + 2:X4} (token address + 2); " +
                $"U={ContractU(contract, $"handler-{index}"):X4} " +
                $"S={ContractS(contract, $"handler-{index}"):X4}. " +
                (node.OperandAddress is null
                    ? "No inline operand."
                    : $"Inline operand at {node.OperandAddress:X4}."));
        }

        LampPatternNode shared = nodes[6];
        ushort sharedPrefetchX = nodes[5].HandlerAddress;
        Add(
            "body-prefetch-6", 0x00FC, sharedPrefetchX, shared.Address, shared.Token,
            null, shared.HandlerAddress,
            LampPatternOperandKind.ServiceOwnedNoCallerOperand,
            null, null, "body-prefetch-6", null, 0x1026,
            $"NEXT prefetch of the shared 9C44 token at 00FC; X={sharedPrefetchX:X4} " +
            "is the previous handler pointer, Y=1024. The next caller word is the " +
            "792F return at 1026, not an inline operand.");
        Add(
            "shared-handler-entry", 0x9B15, 0x9C46, 0x1026, 0x9C44, null, 0x9B15,
            LampPatternOperandKind.ServiceOwnedNoCallerOperand, null, null,
            "shared-handler-entry", null, 0x1026,
            "Handler 9B15 entry before JSR 796E; X=9C46 (9C44 token cell + 2), " +
            "Y=1026; PRE-JSR U=066A S=0796. The 72BF service pointer is not a " +
            "caller operand.");
        Add(
            "service-trampoline-jrs-entry", 0x796E, 0x9C46, 0x1026, 0x9C44, null, 0x9B15,
            LampPatternOperandKind.ServiceOwnedNoCallerOperand, null, null,
            "service-trampoline-jrs-entry", null, 0x1026,
            "At 796E after JSR 796E; before PSHU X. The JSR return 9B18 is on S, " +
            "S=0794; U is still 066A.");
        Add(
            "service-trampoline-pshu", 0x7970, 0x9C46, 0x1026, 0x9C44, null, 0x9B15,
            LampPatternOperandKind.ServiceOwnedNoCallerOperand, null, null,
            "service-trampoline-pshu", null, 0x9B18,
            "After 796E PSHU X pushes the service pointer 9C46 on U; U=0668 S=0794. " +
            "LDX ,S recovers 9B18, STY ,S stores the outer cursor 1026, LEAY ,X sets " +
            "Y=9B18 and JMP 00FC enters the shared body.");

        ushort sharedBodyCursor = LampPatternWordBuilder.SharedBodyAddress;
        ushort sharedBodyToken = ReadWord(originalRom, sharedBodyCursor);
        ushort sharedBodyHandler = ReadWord(originalRom, sharedBodyToken);
        Add(
            "shared-body-entry", 0x00FC, LampPatternWordBuilder.SharedBodyAddress,
            LampPatternWordBuilder.SharedBodyAddress, sharedBodyToken, null,
            sharedBodyHandler, LampPatternOperandKind.None, null, null,
            "shared-body-entry", 0x1026, 0x9B1A,
            "NEXT prefetch at 00FC entering the shared body: X=Y=9B18 from the 796E " +
            "trampoline, token 790D at 9B18. PC is the runtime 00FC, not the native " +
            "byte address 9B18; the STY ,S slot holds the outer caller cursor 1026; " +
            "U=0668 S=0794.");
        string[] sharedAfterNames =
        {
            "shared-after-fetch-word", "shared-after-rotate", "shared-after-add",
            "shared-after-fetch-byte", "shared-after-swap"
        };
        for (int index = 0; index < sharedAfterNames.Length; index++)
        {
            ushort afterX = SharedLeafExitX(sharedBodyToken, sharedBodyHandler, variant);
            sharedBodyCursor = checked((ushort)(sharedBodyCursor + 2));
            ushort nextToken = ReadWord(originalRom, sharedBodyCursor);
            ushort nextHandler = ReadWord(originalRom, nextToken);
            Add(
                sharedAfterNames[index], 0x00FC, afterX, sharedBodyCursor, nextToken,
                null, nextHandler, LampPatternOperandKind.None, null, null,
                sharedAfterNames[index], 0x1026,
                checked((ushort)(sharedBodyCursor + 2)),
                $"NEXT prefetch at 00FC after the {sharedBodyToken:X4} handler; " +
                $"X={afterX:X4} is the leaf exit X (including stack-helper loads), Y={sharedBodyCursor:X4}, " +
                $"next shared token {nextToken:X4}.");
            sharedBodyToken = nextToken;
            sharedBodyHandler = nextHandler;
        }
        foreach (LampPatternBridgeEvent bridgeEvent in
                 LampPatternWordBuilder.DecodeBridgeChronology(originalRom))
        {
            Add(
                bridgeEvent.Phase, bridgeEvent.Pc, bridgeEvent.X, bridgeEvent.Y,
                0x8050, null, 0x7791, LampPatternOperandKind.None, null, null,
                bridgeEvent.Phase, 0x1026, bridgeEvent.Y, bridgeEvent.Boundary);
        }

        Add(
            "shared-prefetch-return", 0x00FC, 0x8052, 0x9B24, 0x792F, null, 0x7931,
            LampPatternOperandKind.None, null, null, "shared-prefetch-return", 0x1026,
            0x9B26, "After the 7780-778B continuation JMP $00FC; NEXT prefetch at " +
            "00FC of the shared 792F return at 9B24. X=8052 is the restored bridge " +
            "dispatch pointer.");
        Add(
            "shared-return-handler", 0x7931, 0x7931, 0x9B26, 0x792F, null, 0x7931,
            LampPatternOperandKind.None, null, null, "shared-return-handler", 0x1026,
            0x1026, "Shared 792F handler entry before PULS Y; X=792F token cell + 2 " +
            "= 7931, Y=9B26 (token address + 2), not X=Y. Saved cursor 1026 is on " +
            "the control stack; S=0794 and after the pull S=0796.");
        Add(
            "shared-returned-to-1026", 0x00FC, 0x7931, 0x1026, 0x792F, null, 0x7931,
            LampPatternOperandKind.None, null, null, "shared-returned-to-1026", 0x9F16,
            0x1028, "NEXT prefetch at 00FC after the shared PULS Y restored the outer " +
            "cursor 1026; X remains 7931. The outer saved cursor 9F16 remains on the " +
            "control stack.");
        Add(
            "outer-return-handler", 0x7931, 0x7931, 0x1028, 0x792F, null, 0x7931,
            LampPatternOperandKind.None, null, null, "outer-return-handler", 0x9F16,
            0x9F16, "Outer 792F handler entry before PULS Y; X=7931 (token cell + 2), " +
            "Y=1028 (token address + 2), not X=Y; saved cursor 9F16; S=0796 and " +
            "after the pull S=0798.");
        Add(
            "outer-returned-to-9F16", 0x00FC, 0x7931, 0x9F16, 0x75A9, null, 0x75AB,
            LampPatternOperandKind.None, null, null, "outer-returned-to-9F16", null,
            0x9F18, "After the outer return, NEXT prefetches the caller successor token " +
            "75A9 at 9F16; X remains 7931.");

        LampPatternStaticPhase[] result = phases.ToArray();
        ValidatePhases(result, nodes, contract, originalRom, variant);
        return result;
    }

    // ROT and SWAP execute LDX 2,U. In this exact word their second cell is
    // the byte-literal pattern; NEXT does not restore the dispatch pointer.
    private static ushort SharedLeafExitX(
        ushort token, ushort handler, LampPatternVariant variant) =>
        token is 0x7B6D or 0x7B7D ? variant.PatternOperand : handler;

    private static int ContractU(LampPatternStaticContract contract, string phase) =>
        contract.StackSteps.Single(item =>
            string.Equals(item.Phase, phase, StringComparison.Ordinal)).U;

    private static int ContractS(LampPatternStaticContract contract, string phase) =>
        contract.StackSteps.Single(item =>
            string.Equals(item.Phase, phase, StringComparison.Ordinal)).S;

    internal static void ValidatePhases(
        IReadOnlyList<LampPatternStaticPhase> phases,
        IReadOnlyList<LampPatternNode> nodes,
        LampPatternStaticContract contract,
        ReadOnlySpan<byte> originalRom) =>
        ValidatePhases(
            phases,
            nodes,
            contract,
            originalRom,
            LampPatternWordBuilder.VariantEightF);

    internal static void ValidatePhases(
        IReadOnlyList<LampPatternStaticPhase> phases,
        IReadOnlyList<LampPatternNode> nodes,
        LampPatternStaticContract contract,
        ReadOnlySpan<byte> originalRom,
        LampPatternVariant variant)
    {
        if (phases is null || phases.Count != contract.StackSteps.Count)
            throw new InvalidDataException(
                "Lamp-pattern phase list does not match the reviewed stack-step count");
        if (nodes is null || nodes.Count != LampPatternWordBuilder.NodeCount)
            throw new InvalidDataException(
                "Lamp-pattern phase validation requires the eight reviewed nodes");

        var names = new HashSet<string>(StringComparer.Ordinal);
        for (int index = 0; index < phases.Count; index++)
        {
            LampPatternStaticPhase phase = phases[index];
            if (!names.Add(phase.Phase))
                throw new InvalidDataException(
                    $"Duplicate lamp-pattern phase name '{phase.Phase}'");
            if (!string.Equals(phase.Classification, PhaseClassification,
                    StringComparison.Ordinal))
                throw new InvalidDataException(
                    $"Lamp-pattern phase '{phase.Phase}' is not classified as a static " +
                    "prediction");
            LampPatternStackStep step = contract.StackSteps[index];
            if (!string.Equals(phase.Phase, step.Phase, StringComparison.Ordinal))
                throw new InvalidDataException(
                    $"Lamp-pattern phase {index} is '{phase.Phase}' but the stack model " +
                    $"expects '{step.Phase}'");
            if (phase.U != step.U || phase.S != step.S ||
                phase.URelativeToEntry != step.URelativeToEntry ||
                phase.SRelativeToEntry != step.SRelativeToEntry)
                throw new InvalidDataException(
                    $"Lamp-pattern phase '{phase.Phase}' U/S does not match the relative " +
                    "stack model");
        }

        for (int index = 0; index < 6; index++)
        {
            LampPatternNode node = nodes[index];
            LampPatternStaticPhase handler = phases.Single(phase =>
                string.Equals(phase.Phase, $"handler-{index}", StringComparison.Ordinal));
            if (handler.Pc != node.HandlerAddress ||
                handler.HandlerAddress != node.HandlerAddress ||
                handler.Token != node.Token ||
                handler.X != node.Token + 2 ||
                handler.Y != node.Address + 2 ||
                handler.OperandKind != node.OperandKind ||
                handler.OperandAddress != node.OperandAddress ||
                handler.OperandValue != node.OperandValue)
                throw new InvalidDataException(
                    $"Lamp-pattern handler-{index} phase is not the PRE-handler boundary " +
                    "with X=token+2 and Y=token-address+2");
            LampPatternStaticPhase prefetch = phases.Single(phase =>
                string.Equals(phase.Phase, $"body-prefetch-{index}", StringComparison.Ordinal));
            ushort expectedX = index == 0
                ? checked((ushort)(LampPatternWordBuilder.HeaderAddress + 2))
                : nodes[index - 1].HandlerAddress;
            if (prefetch.Pc != 0x00FC || prefetch.X != expectedX ||
                prefetch.Y != node.Address || prefetch.Token != node.Token ||
                prefetch.HandlerAddress != node.HandlerAddress)
                throw new InvalidDataException(
                    $"Lamp-pattern body-prefetch-{index} phase is not the NEXT boundary " +
                    $"with X={expectedX:X4}, Y={node.Address:X4} and token {node.Token:X4}");
        }

        void Require(
            string phase,
            ushort pc,
            ushort? x,
            ushort y,
            ushort token,
            ushort? handler,
            ushort? savedCursor)
        {
            LampPatternStaticPhase actual = phases.Single(item =>
                string.Equals(item.Phase, phase, StringComparison.Ordinal));
            if (actual.Pc != pc || actual.X != x || actual.Y != y ||
                actual.Token != token || actual.HandlerAddress != handler ||
                actual.SavedCursor != savedCursor)
                throw new InvalidDataException(
                    $"Lamp-pattern phase '{phase}' does not match the independent " +
                    "instruction-boundary model: PC={actual.Pc:X4} X={actual.X} " +
                    $"Y={actual.Y:X4} token={actual.Token:X4} saved={actual.SavedCursor}");
        }

        if (ReadWord(originalRom, LampPatternWordBuilder.ServiceCellAddress) != 0x9B15 ||
            ReadWord(originalRom, 0x9C46) != 0x72BF ||
            ReadWord(originalRom, LampPatternWordBuilder.BridgeCellAddress) != 0x7791 ||
            ReadWord(originalRom, LampPatternWordBuilder.BridgeCellAddress + 2) != 0x49C5)
            throw new InvalidDataException(
                "Lamp-pattern phase validation requires the original 9C44/8050 cells");

        Require("shared-handler-entry", 0x9B15, 0x9C46, 0x1026, 0x9C44, 0x9B15,
            null);
        Require("service-trampoline-jrs-entry", 0x796E, 0x9C46, 0x1026, 0x9C44,
            0x9B15, null);
        Require("service-trampoline-pshu", 0x7970, 0x9C46, 0x1026, 0x9C44, 0x9B15,
            null);

        ushort sharedCursor = LampPatternWordBuilder.SharedBodyAddress;
        ushort sharedToken = ReadWord(originalRom, sharedCursor);
        ushort sharedHandler = ReadWord(originalRom, sharedToken);
        Require("shared-body-entry", 0x00FC, LampPatternWordBuilder.SharedBodyAddress,
            LampPatternWordBuilder.SharedBodyAddress, sharedToken, sharedHandler,
            LampPatternWordBuilder.SharedSavedCursor);
        string[] sharedAfterNames =
        {
            "shared-after-fetch-word", "shared-after-rotate", "shared-after-add",
            "shared-after-fetch-byte", "shared-after-swap"
        };
        foreach (string afterName in sharedAfterNames)
        {
            ushort afterX = SharedLeafExitX(sharedToken, sharedHandler, variant);
            sharedCursor = checked((ushort)(sharedCursor + 2));
            ushort nextToken = ReadWord(originalRom, sharedCursor);
            sharedHandler = ReadWord(originalRom, nextToken);
            sharedToken = nextToken;
            Require(afterName, 0x00FC, afterX, sharedCursor, nextToken,
                sharedHandler, LampPatternWordBuilder.SharedSavedCursor);
        }

        LampPatternBridgeEvent[] bridgeEvents =
            LampPatternWordBuilder.DecodeBridgeChronology(originalRom);
        foreach (LampPatternBridgeEvent bridgeEvent in bridgeEvents)
        {
            Require(bridgeEvent.Phase, bridgeEvent.Pc, bridgeEvent.X,
                bridgeEvent.Y, 0x8050, 0x7791,
                LampPatternWordBuilder.SharedSavedCursor);
        }

        ushort jsrReturn = checked((ushort)(
            LampPatternWordBuilder.BridgeContinuationAddress + 2 +
            LampPatternWordBuilder.InstructionLength(
                originalRom, LampPatternWordBuilder.BridgeContinuationAddress + 2)));
        Require("native-prologue-save-regs",
            checked((ushort)(0x49C5 + LampPatternWordBuilder.InstructionLength(
                originalRom, 0x49C5))), null, 0x9B24, 0x8050, 0x7791, 0x1026);
        Require("native-prologue-save-mask",
            checked((ushort)(0x49CE + LampPatternWordBuilder.InstructionLength(
                originalRom, 0x49CE))), null, 0x9B24, 0x8050, 0x7791, 0x1026);
        Require("native-prologue-deepest",
            checked((ushort)(0x49D0 + LampPatternWordBuilder.InstructionLength(
                originalRom, 0x49D0))), null, 0x9B24, 0x8050, 0x7791, 0x1026);
        Require("native-epilogue-puls-cc",
            checked((ushort)(0x49E0 + LampPatternWordBuilder.InstructionLength(
                originalRom, 0x49E0))), null, 0x9B24, 0x8050, 0x7791, 0x1026);
        Require("native-epilogue-puls-a",
            checked((ushort)(0x4A21 + LampPatternWordBuilder.InstructionLength(
                originalRom, 0x4A21))), null, 0x9B24, 0x8050, 0x7791, 0x1026);
        Require("native-return", jsrReturn, 0x8052, 0x9B24, 0x8050, 0x7791, 0x1026);
        Require("shared-prefetch-return", 0x00FC, 0x8052, 0x9B24, 0x792F, 0x7931,
            0x1026);
        Require("shared-return-handler", 0x7931, 0x7931, 0x9B26, 0x792F, 0x7931,
            0x1026);
        Require("shared-returned-to-1026", 0x00FC, 0x7931, 0x1026, 0x792F, 0x7931,
            LampPatternWordBuilder.OuterSavedCursor);
        Require("outer-return-handler", 0x7931, 0x7931, 0x1028, 0x792F, 0x7931,
            LampPatternWordBuilder.OuterSavedCursor);
        Require("outer-returned-to-9F16", 0x00FC, 0x7931, 0x9F16, 0x75A9, 0x75AB,
            null);

        foreach (string prefetchName in new[]
                 {
                     "shared-prefetch-return", "shared-returned-to-1026",
                     "outer-returned-to-9F16"
                 })
        {
            LampPatternStaticPhase prefetch = phases.Single(item =>
                string.Equals(item.Phase, prefetchName, StringComparison.Ordinal));
            if (prefetch.Pc != 0x00FC)
                throw new InvalidDataException(
                    $"Lamp-pattern phase '{prefetchName}' must use runtime PC 00FC, not " +
                    $"{prefetch.Pc:X4}");
        }

        LampPatternNode sharedNode = nodes[6];
        if (sharedNode.Token != LampPatternWordBuilder.SharedCallToken ||
            ReadWord(originalRom, sharedNode.Token) != 0x9B15 ||
            !originalRom.Slice(0x9B15, 3).SequenceEqual(new byte[] { 0xBD, 0x79, 0x6E }))
            throw new InvalidDataException(
                "Lamp-pattern phase validation requires the original 9C44 -> 9B15 -> " +
                "796E service chain");
    }
    private static ushort ReadWord(ReadOnlySpan<byte> image, int address) =>
        (ushort)((image[address] << 8) | image[address + 1]);

    private static string Sha1(ReadOnlySpan<byte> bytes) =>
        Convert.ToHexString(SHA1.HashData(bytes));

    private static string Sha256(ReadOnlySpan<byte> bytes) =>
        Convert.ToHexString(SHA256.HashData(bytes));
}

using System.Collections.ObjectModel;
using System.Security.Cryptography;

namespace FruitMachineLab.Il;

public enum LargerReplacementMapKind
{
    Header,
    Body,
    CallerToken,
    CallerSuccessor,
    ParentToken,
    ParentSuccessor
}

public sealed record LargerReplacementMapEntry(
    ushort Address,
    LargerReplacementMapKind Kind,
    int? NodeIndex,
    ushort Token,
    ushort? ReplacementToken,
    string Operation,
    ushort? HandlerAddress,
    ushort? OperandAddress,
    ushort? OperandValue,
    bool IsFinalReturn,
    byte ImageByte);

public sealed record LargerReplacementInlineOperand(
    int NodeIndex,
    ushort Address,
    ushort Value);

public sealed record LargerReplacementStaticPhase(
    string Phase,
    string Classification,
    ushort Pc,
    ushort? X,
    ushort Y,
    ushort Token,
    ushort? ReplacementToken,
    ushort? HandlerAddress,
    ushort? InlineOperandAddress,
    ushort? InlineOperandValue,
    ushort? SavedCursor,
    ushort? NextY,
    string Boundary);

public sealed record LargerReplacementCallerBinding(
    ushort TokenAddress,
    ushort OriginalToken,
    ushort ReplacementToken,
    ushort HeaderAddress,
    ushort HeaderValue,
    ushort BodyStart,
    int BodyEndExclusive,
    ushort SavedReturnCursor,
    ushort PostReturnTokenAddress,
    ushort PostReturnToken,
    ushort ParentTokenAddress,
    ushort ParentToken,
    ushort ParentSuccessorAddress,
    ushort ParentSuccessorToken,
    ushort FinalReturnAddress,
    ushort ReturnHandlerAddress);

public sealed record LargerReplacementSemanticContract(
    string StackEffect,
    int BodyUNet,
    int EntryDepth,
    int ExitDepth,
    int TrampolineSDelta,
    int ReturnHandlerSDelta,
    int WholeCallSNet,
    bool NestedCall,
    string Classification);

public sealed class LargerReplacementSourceMap
{
    public const string PhaseClassification = "static_prediction_not_execution";
    public const string BuildClassification =
        "static_larger_replacement_map_bound_to_exact_output_sha256";

    private readonly ReadOnlyCollection<LargerReplacementMapEntry> _entries;
    private readonly ReadOnlyCollection<LargerReplacementInlineOperand> _inlineOperands;
    private readonly ReadOnlyCollection<LargerReplacementNode> _nodes;
    private readonly ReadOnlyCollection<LargerReplacementStaticPhase> _phases;

    private LargerReplacementSourceMap(
        string originalRomSha1,
        string originalRomSha256,
        string outputImageSha1,
        string outputImageSha256,
        LargerReplacementNode[] nodes,
        LargerReplacementMapEntry[] entries,
        LargerReplacementInlineOperand[] inlineOperands,
        LargerReplacementStaticPhase[] phases,
        LargerReplacementCallerBinding caller,
        LargerReplacementSemanticContract semantics,
        LargerReplacementStaticContract staticContract,
        LargerReplacementProvenance provenance)
    {
        OriginalRomSha1 = originalRomSha1;
        OriginalRomSha256 = originalRomSha256;
        OutputImageSha1 = outputImageSha1;
        OutputImageSha256 = outputImageSha256;
        _nodes = Array.AsReadOnly((LargerReplacementNode[])nodes.Clone());
        _entries = Array.AsReadOnly((LargerReplacementMapEntry[])entries.Clone());
        _inlineOperands =
            Array.AsReadOnly((LargerReplacementInlineOperand[])inlineOperands.Clone());
        _phases =
            Array.AsReadOnly((LargerReplacementStaticPhase[])phases.Clone());
        Caller = caller;
        Semantics = semantics;
        StaticContract = staticContract;
        Provenance = provenance;
    }

    public string OriginalRomSha1 { get; }

    public string OriginalRomSha256 { get; }

    public string OutputImageSha1 { get; }

    public string OutputImageSha256 { get; }

    public string BuildId => OutputImageSha256;

    public ushort HeaderAddress => LargerReplacementBuilder.HeaderAddress;

    public string HeaderHex => LargerReplacementBuilder.HeaderHex;

    public ushort BodyStart => LargerReplacementBuilder.BodyStart;

    public int BodyEndExclusive => LargerReplacementBuilder.BodyEndExclusive;

    public int AllocationEndInclusive => LargerReplacementBuilder.AllocationEndInclusive;

    public ReadOnlyCollection<LargerReplacementNode> Nodes => _nodes;

    public ReadOnlyCollection<LargerReplacementMapEntry> Entries => _entries;

    public ReadOnlyCollection<LargerReplacementInlineOperand> InlineOperands =>
        _inlineOperands;

    public ReadOnlyCollection<LargerReplacementStaticPhase> Phases => _phases;

    public LargerReplacementCallerBinding Caller { get; }

    public LargerReplacementSemanticContract Semantics { get; }

    public LargerReplacementStaticContract StaticContract { get; }

    public LargerReplacementProvenance Provenance { get; }

    public string Classification => BuildClassification;

    public LargerReplacementMapEntry Resolve(ushort address)
    {
        foreach (LargerReplacementMapEntry entry in _entries)
        {
            if (entry.Address == address)
                return entry;
        }
        throw new KeyNotFoundException(
            $"Larger-replacement source map has no entry for address {address:X4}");
    }

    public LargerReplacementMapEntry Resolve(ushort address, string outputImageSha256)
    {
        ValidateBuild(outputImageSha256);
        return Resolve(address);
    }

    public LargerReplacementMapEntry Resolve(
        ushort address, ReadOnlySpan<byte> outputImage)
    {
        ValidateImage(outputImage);
        LargerReplacementMapEntry entry = Resolve(address);
        if (entry.ImageByte != outputImage[address])
            throw new InvalidDataException(
                $"Larger-replacement source-map byte at {address:X4} is " +
                $"{entry.ImageByte:X2}; the bound image contains {outputImage[address]:X2}");
        return entry;
    }

    public void ValidateBuild(string outputImageSha256)
    {
        if (!string.Equals(
                outputImageSha256, OutputImageSha256, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                $"Larger-replacement source-map build identity mismatch: map is bound to " +
                $"{OutputImageSha256}, not {outputImageSha256}");
    }

    public void ValidateImage(ReadOnlySpan<byte> outputImage)
    {
        if (outputImage.Length != 0x10000)
            throw new InvalidDataException(
                $"Larger-replacement source-map image length {outputImage.Length} differs " +
                "from 65536");
        string sha256 = Sha256(outputImage);
        ValidateBuild(sha256);

        if (!outputImage.Slice(HeaderAddress, 2)
                .SequenceEqual(Convert.FromHexString(HeaderHex)))
            throw new InvalidDataException(
                "Larger-replacement source-map image header at 1010 is not 00F8");
        if (!outputImage.Slice(BodyStart, BodyEndExclusive - BodyStart)
                .SequenceEqual(Convert.FromHexString(LargerReplacementBuilder.BodyHex)))
            throw new InvalidDataException(
                "Larger-replacement source-map body at 1012-1025 differs from the reviewed " +
                "body");
        if (!outputImage.Slice(
                LargerReplacementBuilder.CallerTokenAddress, 2)
                .SequenceEqual(Convert.FromHexString("1010")))
            throw new InvalidDataException(
                "Larger-replacement source-map caller token at 9F14 is not 1010");
        if (!outputImage.Slice(
                LargerReplacementBuilder.CallerSuccessorAddress, 2)
                .SequenceEqual(Convert.FromHexString("75A9")))
            throw new InvalidDataException(
                "Larger-replacement source-map caller successor at 9F16 is not 75A9");
        if (!outputImage.Slice(0x9ED7, 16)
                .SequenceEqual(Convert.FromHexString(
                    "00F8" + LargerReplacementBuilder.OriginalBodyHex)))
            throw new InvalidDataException(
                "Larger-replacement source-map output changed the original 9ED7/9ED9 " +
                "definition");
        if (!outputImage.Slice(
                LargerReplacementBuilder.ParentTokenAddress, 2)
                .SequenceEqual(Convert.FromHexString("9F10")) ||
            !outputImage.Slice(
                LargerReplacementBuilder.ParentSuccessorAddress, 2)
                .SequenceEqual(Convert.FromHexString("792F")))
            throw new InvalidDataException(
                "Larger-replacement source-map parent context at 9F3D/9F3F differs");

        ushort finalToken = ReadWord(outputImage, 0x1024);
        if (finalToken != VmIlVocabulary.ReturnToCallerStream)
            throw new InvalidDataException(
                "Larger-replacement source-map final body token at 1024 is not 792F");

        foreach (LargerReplacementMapEntry entry in _entries)
        {
            if (entry.ImageByte != outputImage[entry.Address])
                throw new InvalidDataException(
                    $"Larger-replacement source-map byte at {entry.Address:X4} is " +
                    $"{entry.ImageByte:X2}; the bound image contains " +
                    $"{outputImage[entry.Address]:X2}");
        }

        foreach (LargerReplacementInlineOperand operand in _inlineOperands)
        {
            ushort encoded = ReadWord(outputImage, operand.Address);
            if (encoded != operand.Value)
                throw new InvalidDataException(
                    $"Larger-replacement inline operand at {operand.Address:X4} is " +
                    $"{encoded:X4}; expected {operand.Value:X4}");
        }
    }

    internal static LargerReplacementSourceMap CreateForBuild(
        ReadOnlySpan<byte> originalRom,
        ReadOnlySpan<byte> outputImage,
        LargerReplacementNode[] nodes,
        LargerReplacementStaticContract staticContract,
        LargerReplacementProvenance provenance)
    {
        NineEdNineDecoder.ValidateIdentity(
            originalRom,
            NineEdNineDecoder.RequiredRomLength,
            NineEdNineDecoder.RequiredRomSha1,
            NineEdNineDecoder.RequiredRomSha256);
        if (outputImage.Length != originalRom.Length)
            throw new InvalidDataException(
                "Larger-replacement source-map image length differs from the original ROM");
        if (nodes is null || nodes.Length != LargerReplacementBuilder.NodeCount)
            throw new InvalidDataException(
                "Larger-replacement source map requires the seven reviewed body nodes");

        ValidateSource(originalRom, outputImage, nodes);

        var entries = new List<LargerReplacementMapEntry>(32);
        entries.Add(new LargerReplacementMapEntry(
            LargerReplacementBuilder.HeaderAddress,
            LargerReplacementMapKind.Header,
            null,
            LargerReplacementBuilder.HeaderValue,
            null,
            "definition-header-00f8",
            null,
            null,
            null,
            false,
            outputImage[LargerReplacementBuilder.HeaderAddress]));
        entries.Add(new LargerReplacementMapEntry(
            LargerReplacementBuilder.HeaderAddress + 1,
            LargerReplacementMapKind.Header,
            null,
            LargerReplacementBuilder.HeaderValue,
            null,
            "definition-header-00f8",
            null,
            null,
            null,
            false,
            outputImage[LargerReplacementBuilder.HeaderAddress + 1]));

        var inlineOperands = new List<LargerReplacementInlineOperand>(
            LargerReplacementBuilder.InlineOperandCount);
        for (int index = 0; index < nodes.Length; index++)
        {
            LargerReplacementNode node = nodes[index];
            if (node.OperandAddress is ushort operandAddress &&
                node.OperandValue is ushort operandValue)
                inlineOperands.Add(new LargerReplacementInlineOperand(
                    index, operandAddress, operandValue));

            byte[] nodeBytes = Convert.FromHexString(node.BytesHex);
            for (int byteIndex = 0; byteIndex < nodeBytes.Length; byteIndex++)
            {
                int address = node.Address + byteIndex;
                bool isOperand = node.OperandAddress is ushort operand &&
                                 (address == operand || address == operand + 1);
                entries.Add(new LargerReplacementMapEntry(
                    checked((ushort)address),
                    LargerReplacementMapKind.Body,
                    index,
                    node.Token,
                    null,
                    node.Operation,
                    node.HandlerAddress,
                    isOperand ? node.OperandAddress : null,
                    isOperand ? node.OperandValue : null,
                    node.Token == VmIlVocabulary.ReturnToCallerStream,
                    outputImage[address]));
            }
        }

        entries.Add(new LargerReplacementMapEntry(
            LargerReplacementBuilder.CallerTokenAddress,
            LargerReplacementMapKind.CallerToken,
            null,
            LargerReplacementBuilder.CallerOriginalToken,
            LargerReplacementBuilder.CallerReplacementToken,
            "caller-token-redirect",
            null,
            null,
            null,
            false,
            outputImage[LargerReplacementBuilder.CallerTokenAddress]));
        entries.Add(new LargerReplacementMapEntry(
            LargerReplacementBuilder.CallerTokenAddress + 1,
            LargerReplacementMapKind.CallerToken,
            null,
            LargerReplacementBuilder.CallerOriginalToken,
            LargerReplacementBuilder.CallerReplacementToken,
            "caller-token-redirect",
            null,
            null,
            null,
            false,
            outputImage[LargerReplacementBuilder.CallerTokenAddress + 1]));
        entries.Add(new LargerReplacementMapEntry(
            LargerReplacementBuilder.CallerSuccessorAddress,
            LargerReplacementMapKind.CallerSuccessor,
            null,
            LargerReplacementBuilder.CallerSuccessorToken,
            null,
            "caller-successor-token",
            null,
            null,
            null,
            false,
            outputImage[LargerReplacementBuilder.CallerSuccessorAddress]));
        entries.Add(new LargerReplacementMapEntry(
            LargerReplacementBuilder.CallerSuccessorAddress + 1,
            LargerReplacementMapKind.CallerSuccessor,
            null,
            LargerReplacementBuilder.CallerSuccessorToken,
            null,
            "caller-successor-token",
            null,
            null,
            null,
            false,
            outputImage[LargerReplacementBuilder.CallerSuccessorAddress + 1]));
        entries.Add(new LargerReplacementMapEntry(
            LargerReplacementBuilder.ParentTokenAddress,
            LargerReplacementMapKind.ParentToken,
            null,
            LargerReplacementBuilder.ParentToken,
            null,
            "parent-token-context",
            null,
            null,
            null,
            false,
            outputImage[LargerReplacementBuilder.ParentTokenAddress]));
        entries.Add(new LargerReplacementMapEntry(
            LargerReplacementBuilder.ParentTokenAddress + 1,
            LargerReplacementMapKind.ParentToken,
            null,
            LargerReplacementBuilder.ParentToken,
            null,
            "parent-token-context",
            null,
            null,
            null,
            false,
            outputImage[LargerReplacementBuilder.ParentTokenAddress + 1]));
        entries.Add(new LargerReplacementMapEntry(
            LargerReplacementBuilder.ParentSuccessorAddress,
            LargerReplacementMapKind.ParentSuccessor,
            null,
            LargerReplacementBuilder.ParentSuccessorToken,
            null,
            "parent-successor-context",
            null,
            null,
            null,
            false,
            outputImage[LargerReplacementBuilder.ParentSuccessorAddress]));
        entries.Add(new LargerReplacementMapEntry(
            LargerReplacementBuilder.ParentSuccessorAddress + 1,
            LargerReplacementMapKind.ParentSuccessor,
            null,
            LargerReplacementBuilder.ParentSuccessorToken,
            null,
            "parent-successor-context",
            null,
            null,
            null,
            false,
            outputImage[LargerReplacementBuilder.ParentSuccessorAddress + 1]));

        var caller = new LargerReplacementCallerBinding(
            LargerReplacementBuilder.CallerTokenAddress,
            LargerReplacementBuilder.CallerOriginalToken,
            LargerReplacementBuilder.CallerReplacementToken,
            LargerReplacementBuilder.HeaderAddress,
            LargerReplacementBuilder.HeaderValue,
            LargerReplacementBuilder.BodyStart,
            LargerReplacementBuilder.BodyEndExclusive,
            LargerReplacementBuilder.CallerSuccessorAddress,
            LargerReplacementBuilder.CallerSuccessorAddress,
            LargerReplacementBuilder.CallerSuccessorToken,
            LargerReplacementBuilder.ParentTokenAddress,
            LargerReplacementBuilder.ParentToken,
            LargerReplacementBuilder.ParentSuccessorAddress,
            LargerReplacementBuilder.ParentSuccessorToken,
            0x1024,
            0x7931);

        var semantics = new LargerReplacementSemanticContract(
            "input x; ((x + FF80h) mod 10000h) XOR FF80h; + 0001h at callee exit; " +
            "75A9 normalizes to 0000h when bit15 is clear, otherwise FFFFh",
            staticContract.BodyUNet,
            staticContract.EntryDepth,
            staticContract.ExitDepth,
            staticContract.TrampolineSDelta,
            staticContract.ReturnHandlerSDelta,
            staticContract.WholeCallSNet,
            staticContract.NestedCall,
            PhaseClassification);

        var phases = BuildPhases(nodes);

        var map = new LargerReplacementSourceMap(
            Sha1(originalRom),
            Sha256(originalRom),
            Sha1(outputImage),
            Sha256(outputImage),
            nodes,
            entries.ToArray(),
            inlineOperands.ToArray(),
            phases,
            caller,
            semantics,
            staticContract,
            provenance);
        map.ValidateImage(outputImage);
        return map;
    }

    private static void ValidateSource(
        ReadOnlySpan<byte> originalRom,
        ReadOnlySpan<byte> outputImage,
        LargerReplacementNode[] nodes)
    {
        if (!outputImage.Slice(
                LargerReplacementBuilder.HeaderAddress, 2)
                .SequenceEqual(Convert.FromHexString(
                    LargerReplacementBuilder.HeaderHex)))
            throw new InvalidDataException(
                "Larger-replacement source-map requires header 00F8 at 1010");
        if (!outputImage.Slice(
                LargerReplacementBuilder.BodyStart,
                LargerReplacementBuilder.BodyEndExclusive -
                LargerReplacementBuilder.BodyStart)
                .SequenceEqual(Convert.FromHexString(
                    LargerReplacementBuilder.BodyHex)))
            throw new InvalidDataException(
                "Larger-replacement source-map requires the reviewed body at 1012-1025");
        if (!outputImage.Slice(
                LargerReplacementBuilder.CallerTokenAddress, 2)
                .SequenceEqual(new byte[] { 0x10, 0x10 }))
            throw new InvalidDataException(
                "Larger-replacement source-map requires caller token 1010 at 9F14");
        if (!outputImage.Slice(
                LargerReplacementBuilder.CallerSuccessorAddress, 2)
                .SequenceEqual(new byte[] { 0x75, 0xA9 }))
            throw new InvalidDataException(
                "Larger-replacement source-map requires successor 75A9 at 9F16");
        if (!originalRom.Slice(
                LargerReplacementBuilder.OriginalBodyStart, 14)
                .SequenceEqual(Convert.FromHexString(
                    LargerReplacementBuilder.OriginalBodyHex)))
            throw new InvalidDataException(
                "Original 9ED9 body differs from the reviewed certified body");

        ushort[] expectedAddresses =
        {
            0x1012, 0x1016, 0x1018, 0x101C, 0x101E, 0x1022, 0x1024
        };
        ushort[] expectedTokens =
        {
            0x795B, 0x787E, 0x795B, 0x7AAF, 0x795B, 0x787E, 0x792F
        };
        int cursor = LargerReplacementBuilder.BodyStart;
        for (int index = 0; index < nodes.Length; index++)
        {
            LargerReplacementNode node = nodes[index];
            if (node.Index != index ||
                node.Address != expectedAddresses[index] ||
                node.Token != expectedTokens[index] ||
                node.HandlerAddress != expectedTokens[index] + 2)
                throw new InvalidDataException(
                    $"Larger-replacement source-map node {index} does not match the " +
                    "reviewed body");
            if (node.Address != cursor)
                throw new InvalidDataException(
                    $"Larger-replacement source-map node {index} at {node.Address:X4} does " +
                    $"not follow cursor {cursor:X4}");
            byte[] bytes = Convert.FromHexString(node.BytesHex);
            if (!outputImage.Slice(node.Address, bytes.Length).SequenceEqual(bytes))
                throw new InvalidDataException(
                    $"Larger-replacement source-map node {index} bytes differ from the " +
                    "output image");
            if (node.OperandAddress is ushort operandAddress)
            {
                if (operandAddress != node.Address + 2 ||
                    operandAddress + 1 >= LargerReplacementBuilder.BodyEndExclusive)
                    throw new InvalidDataException(
                        $"Larger-replacement source-map node {index} operand is outside the " +
                        "body");
                ushort encoded = ReadWord(outputImage, operandAddress);
                if (node.OperandValue != encoded)
                    throw new InvalidDataException(
                        $"Larger-replacement source-map node {index} operand value differs");
            }
            cursor += bytes.Length;
        }
        if (cursor != LargerReplacementBuilder.BodyEndExclusive)
            throw new InvalidDataException(
                "Larger-replacement source-map node sequence does not cover the full body");
    }

    private static LargerReplacementStaticPhase[] BuildPhases(
        LargerReplacementNode[] nodes)
    {
        var phases = new List<LargerReplacementStaticPhase>(17)
        {
            new(
                "caller-dispatch",
                PhaseClassification,
                0x00FC,
                null,
                0x9F14,
                0x9ED7,
                0x1010,
                null,
                null,
                null,
                null,
                0x9F16,
                "Before LDX ,Y++ at 00FC; the caller word at 9F14 is replaced by 1010."),
            new(
                "header-trampoline-entry",
                PhaseClassification,
                0x00F8,
                0x1012,
                0x9F16,
                0x00F8,
                null,
                null,
                null,
                null,
                0x9F16,
                0x1012,
                "After JMP [,X++] at 00FE and before PSHS Y; Y already advanced to 9F16.")
        };

        for (int index = 0; index < 6; index++)
        {
            LargerReplacementNode node = nodes[index];
            int operandBytes = node.OperandAddress is null ? 0 : 2;
            phases.Add(new LargerReplacementStaticPhase(
                $"body-prefetch-{index}",
                PhaseClassification,
                0x00FC,
                null,
                node.Address,
                node.Token,
                null,
                node.HandlerAddress,
                null,
                null,
                null,
                checked((ushort)(node.Address + 2)),
                $"Prefetch at 00FC before LDX ,Y++; body token at {node.Address:X4}."));
            phases.Add(new LargerReplacementStaticPhase(
                $"handler-{index}",
                PhaseClassification,
                node.HandlerAddress,
                node.HandlerAddress,
                checked((ushort)(node.Address + 2)),
                node.Token,
                null,
                node.HandlerAddress,
                node.OperandAddress,
                node.OperandValue,
                null,
                checked((ushort)(node.Address + 2 + operandBytes)),
                node.OperandAddress is null
                    ? $"Native handler entry at {node.HandlerAddress:X4}; no inline operand."
                    : $"Native handler entry before the inline word at " +
                      $"{node.OperandAddress:X4}-{node.OperandAddress + 1:X4}."));
        }

        LargerReplacementNode returnNode = nodes[6];
        phases.Add(new LargerReplacementStaticPhase(
            "body-prefetch-6",
            PhaseClassification,
            0x00FC,
            null,
            returnNode.Address,
            returnNode.Token,
            null,
            returnNode.HandlerAddress,
            null,
            null,
            null,
            checked((ushort)(returnNode.Address + 2)),
            "Prefetch at 00FC with Y=1024 and the final 792F token."));
        phases.Add(new LargerReplacementStaticPhase(
            "return-handler",
            PhaseClassification,
            returnNode.HandlerAddress,
            returnNode.HandlerAddress,
            checked((ushort)(returnNode.Address + 2)),
            returnNode.Token,
            null,
            returnNode.HandlerAddress,
            null,
            null,
            0x9F16,
            0x9F16,
            "Return handler entry before PULS Y; Y=1026 and the saved caller cursor is " +
            "9F16."));
        phases.Add(new LargerReplacementStaticPhase(
            "post-return-prefetch",
            PhaseClassification,
            0x00FC,
            returnNode.HandlerAddress,
            0x9F16,
            0x75A9,
            null,
            null,
            null,
            null,
            null,
            0x9F18,
            "After PULS Y; caller successor token at 9F16 is 75A9."));
        return phases.ToArray();
    }

    private static ushort ReadWord(ReadOnlySpan<byte> image, int address) =>
        (ushort)((image[address] << 8) | image[address + 1]);

    private static string Sha1(ReadOnlySpan<byte> bytes) =>
        Convert.ToHexString(SHA1.HashData(bytes));

    private static string Sha256(ReadOnlySpan<byte> bytes) =>
        Convert.ToHexString(SHA256.HashData(bytes));
}

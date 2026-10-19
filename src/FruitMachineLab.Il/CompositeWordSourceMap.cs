using System.Collections.ObjectModel;
using System.Security.Cryptography;

namespace FruitMachineLab.Il;

public enum CompositeWordMapKind
{
    Header,
    Body,
    CallerToken,
    CallerSuccessor
}

public sealed record CompositeWordMapEntry(
    ushort Address,
    CompositeWordMapKind Kind,
    int? NodeIndex,
    ushort Token,
    ushort? ReplacementToken,
    string Operation,
    ushort? HandlerAddress,
    byte ImageByte);

public sealed record CompositeWordPhase(
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
    string Boundary);

public sealed record CompositeWordCallerBinding(
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
    ushort ParentSuccessorToken);

public sealed class CompositeWordSourceMap
{
    public const string PhaseClassification =
        "static_compiled_map_not_execution_proof";

    private readonly ReadOnlyCollection<CompositeWordMapEntry> _entries;
    private readonly ReadOnlyCollection<CompositeWordPhase> _phases;
    private readonly ReadOnlyCollection<CompositeWordNode> _nodes;

    private CompositeWordSourceMap(
        string originalRomSha1,
        string originalRomSha256,
        string outputImageSha1,
        string outputImageSha256,
        CompositeWordNode[] nodes,
        CompositeWordMapEntry[] entries,
        CompositeWordPhase[] phases,
        CompositeWordCallerBinding caller,
        CompositeWordProvenance provenance)
    {
        OriginalRomSha1 = originalRomSha1;
        OriginalRomSha256 = originalRomSha256;
        OutputImageSha1 = outputImageSha1;
        OutputImageSha256 = outputImageSha256;
        _nodes = Array.AsReadOnly((CompositeWordNode[])nodes.Clone());
        _entries = Array.AsReadOnly((CompositeWordMapEntry[])entries.Clone());
        _phases = Array.AsReadOnly((CompositeWordPhase[])phases.Clone());
        Caller = caller;
        Provenance = provenance;
    }

    public string OriginalRomSha1 { get; }

    public string OriginalRomSha256 { get; }

    public string OutputImageSha1 { get; }

    public string OutputImageSha256 { get; }

    public string BuildId => OutputImageSha256;

    public ushort HeaderAddress => CompositeWordBuilder.HeaderAddress;

    public string HeaderHex => "00F8";

    public ushort BodyStart => CompositeWordBuilder.BodyStart;

    public int BodyEndExclusive => CompositeWordBuilder.BodyEndExclusive;

    public ReadOnlyCollection<CompositeWordNode> Nodes => _nodes;

    public ReadOnlyCollection<CompositeWordMapEntry> Entries => _entries;

    public ReadOnlyCollection<CompositeWordPhase> Phases => _phases;

    public CompositeWordCallerBinding Caller { get; }

    public CompositeWordProvenance Provenance { get; }

    public string Classification => PhaseClassification;

    public CompositeWordMapEntry Resolve(ushort address)
    {
        foreach (CompositeWordMapEntry entry in _entries)
        {
            if (entry.Address == address)
                return entry;
        }
        throw new KeyNotFoundException(
            $"Composite source map has no entry for address {address:X4}");
    }

    public CompositeWordMapEntry Resolve(ushort address, string outputImageSha256)
    {
        ValidateBuild(outputImageSha256);
        return Resolve(address);
    }

    public CompositeWordMapEntry Resolve(ushort address, ReadOnlySpan<byte> outputImage)
    {
        ValidateImage(outputImage);
        CompositeWordMapEntry entry = Resolve(address);
        if (entry.ImageByte != outputImage[address])
            throw new InvalidDataException(
                $"Composite source-map byte at {address:X4} is {entry.ImageByte:X2}; " +
                $"the bound image contains {outputImage[address]:X2}");
        return entry;
    }

    public void ValidateBuild(string outputImageSha256)
    {
        if (!string.Equals(
                outputImageSha256, OutputImageSha256, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                $"Composite source-map build identity mismatch: map is bound to " +
                $"{OutputImageSha256}, not {outputImageSha256}");
    }

    public void ValidateImage(ReadOnlySpan<byte> outputImage)
    {
        if (outputImage.Length != 0x10000)
            throw new InvalidDataException(
                $"Composite source-map image length {outputImage.Length} differs from 65536");
        string sha256 = Sha256(outputImage);
        ValidateBuild(sha256);
        if (!outputImage.Slice(HeaderAddress, 2)
                .SequenceEqual(Convert.FromHexString(HeaderHex)))
            throw new InvalidDataException(
                "Composite source-map image header at 1010 is not 00F8");
        if (!outputImage.Slice(BodyStart, BodyEndExclusive - BodyStart)
                .SequenceEqual(Convert.FromHexString(CompositeWordBuilder.BodyHex)))
            throw new InvalidDataException(
                "Composite source-map image body at 1012-101F differs from the reviewed body");
        if (!outputImage.Slice(
                CompositeWordBuilder.CallerTokenAddress, 2)
                .SequenceEqual(Convert.FromHexString("1010")))
            throw new InvalidDataException(
                "Composite source-map image caller token at 9F14 is not 1010");
        if (!outputImage.Slice(
                CompositeWordBuilder.CallerSuccessorAddress, 2)
                .SequenceEqual(Convert.FromHexString("75A9")))
            throw new InvalidDataException(
                "Composite source-map image caller successor at 9F16 is not 75A9");
        foreach (CompositeWordMapEntry entry in _entries)
        {
            if (entry.ImageByte != outputImage[entry.Address])
                throw new InvalidDataException(
                    $"Composite source-map byte at {entry.Address:X4} is " +
                    $"{entry.ImageByte:X2}; the bound image contains " +
                    $"{outputImage[entry.Address]:X2}");
        }
    }

    internal static CompositeWordSourceMap CreateForBuild(
        ReadOnlySpan<byte> originalRom,
        ReadOnlySpan<byte> outputImage,
        CompositeWordNode[] nodes,
        CompositeWordProvenance provenance)
    {
        NineEdNineDecoder.ValidateIdentity(
            originalRom,
            NineEdNineDecoder.RequiredRomLength,
            NineEdNineDecoder.RequiredRomSha1,
            NineEdNineDecoder.RequiredRomSha256);
        if (outputImage.Length != originalRom.Length)
            throw new InvalidDataException(
                "Composite source-map image length differs from the original ROM");
        if (nodes is null || nodes.Length != 5)
            throw new InvalidDataException(
                "Composite source map requires the five copied body nodes");

        ValidateCopiedNodes(originalRom, outputImage, nodes);

        var entries = new List<CompositeWordMapEntry>(20);
        entries.Add(new CompositeWordMapEntry(
            CompositeWordBuilder.HeaderAddress,
            CompositeWordMapKind.Header,
            null,
            0x00F8,
            null,
            "definition-header-00f8",
            null,
            outputImage[CompositeWordBuilder.HeaderAddress]));
        entries.Add(new CompositeWordMapEntry(
            CompositeWordBuilder.HeaderAddress + 1,
            CompositeWordMapKind.Header,
            null,
            0x00F8,
            null,
            "definition-header-00f8",
            null,
            outputImage[CompositeWordBuilder.HeaderAddress + 1]));

        for (int index = 0; index < nodes.Length; index++)
        {
            CompositeWordNode node = nodes[index];
            byte[] nodeBytes = Convert.FromHexString(node.BytesHex);
            for (int byteIndex = 0; byteIndex < nodeBytes.Length; byteIndex++)
            {
                int address = node.Address + byteIndex;
                entries.Add(new CompositeWordMapEntry(
                    (ushort)address,
                    CompositeWordMapKind.Body,
                    index,
                    node.Token,
                    null,
                    node.Operation,
                    node.HandlerAddress,
                    outputImage[address]));
            }
        }

        entries.Add(new CompositeWordMapEntry(
            CompositeWordBuilder.CallerTokenAddress,
            CompositeWordMapKind.CallerToken,
            null,
            CompositeWordBuilder.CallerOriginalToken,
            CompositeWordBuilder.CallerReplacementToken,
            "caller-token-redirect",
            null,
            outputImage[CompositeWordBuilder.CallerTokenAddress]));
        entries.Add(new CompositeWordMapEntry(
            CompositeWordBuilder.CallerTokenAddress + 1,
            CompositeWordMapKind.CallerToken,
            null,
            CompositeWordBuilder.CallerOriginalToken,
            CompositeWordBuilder.CallerReplacementToken,
            "caller-token-redirect",
            null,
            outputImage[CompositeWordBuilder.CallerTokenAddress + 1]));
        entries.Add(new CompositeWordMapEntry(
            CompositeWordBuilder.CallerSuccessorAddress,
            CompositeWordMapKind.CallerSuccessor,
            null,
            CompositeWordBuilder.CallerSuccessorToken,
            null,
            "caller-successor-token",
            null,
            outputImage[CompositeWordBuilder.CallerSuccessorAddress]));
        entries.Add(new CompositeWordMapEntry(
            CompositeWordBuilder.CallerSuccessorAddress + 1,
            CompositeWordMapKind.CallerSuccessor,
            null,
            CompositeWordBuilder.CallerSuccessorToken,
            null,
            "caller-successor-token",
            null,
            outputImage[CompositeWordBuilder.CallerSuccessorAddress + 1]));

        CompositeWordPhase[] phases = BuildPhases(nodes);
        var caller = new CompositeWordCallerBinding(
            CompositeWordBuilder.CallerTokenAddress,
            CompositeWordBuilder.CallerOriginalToken,
            CompositeWordBuilder.CallerReplacementToken,
            CompositeWordBuilder.HeaderAddress,
            CompositeWordBuilder.HeaderValue,
            CompositeWordBuilder.BodyStart,
            CompositeWordBuilder.BodyEndExclusive,
            CompositeWordBuilder.CallerSuccessorAddress,
            CompositeWordBuilder.CallerSuccessorAddress,
            CompositeWordBuilder.CallerSuccessorToken,
            CompositeWordBuilder.ParentTokenAddress,
            CompositeWordBuilder.ParentToken,
            CompositeWordBuilder.ParentSuccessorAddress,
            CompositeWordBuilder.ParentSuccessorToken);

        return new CompositeWordSourceMap(
            Sha1(originalRom),
            Sha256(originalRom),
            Sha1(outputImage),
            Sha256(outputImage),
            nodes,
            entries.ToArray(),
            phases,
            caller,
            provenance);
    }

    private static void ValidateCopiedNodes(
        ReadOnlySpan<byte> originalRom,
        ReadOnlySpan<byte> outputImage,
        CompositeWordNode[] nodes)
    {
        if (!outputImage.Slice(
                CompositeWordBuilder.HeaderAddress, 2)
                .SequenceEqual(Convert.FromHexString(CompositeWordBuilder.HeaderHex)))
            throw new InvalidDataException(
                "Composite source-map requires header 00F8 at 1010");
        if (!outputImage.Slice(
                CompositeWordBuilder.BodyStart,
                CompositeWordBuilder.BodyEndExclusive - CompositeWordBuilder.BodyStart)
                .SequenceEqual(Convert.FromHexString(CompositeWordBuilder.BodyHex)))
            throw new InvalidDataException(
                "Composite source-map requires the reviewed body at 1012-101F");
        if (!outputImage.Slice(
                CompositeWordBuilder.CallerTokenAddress, 2)
                .SequenceEqual(new byte[] { 0x10, 0x10 }))
            throw new InvalidDataException(
                "Composite source-map requires caller token 1010 at 9F14");

        ushort[] expectedAddresses = { 0x1012, 0x1016, 0x1018, 0x101C, 0x101E };
        ushort[] expectedTokens = { 0x795B, 0x787E, 0x795B, 0x7AAF, 0x792F };
        int cursor = CompositeWordBuilder.BodyStart;
        for (int index = 0; index < nodes.Length; index++)
        {
            CompositeWordNode node = nodes[index];
            if (node.Index != index ||
                node.Address != expectedAddresses[index] ||
                node.Token != expectedTokens[index])
                throw new InvalidDataException(
                    $"Composite source-map node {index} does not match the reviewed body");
            if (node.Address != cursor)
                throw new InvalidDataException(
                    $"Composite source-map node {index} at {node.Address:X4} does not " +
                    $"follow cursor {cursor:X4}");
            byte[] bytes = Convert.FromHexString(node.BytesHex);
            if (!outputImage.Slice(node.Address, bytes.Length).SequenceEqual(bytes))
                throw new InvalidDataException(
                    $"Composite source-map node {index} bytes differ from the output image");
            if (node.HandlerAddress != node.Token + 2)
                throw new InvalidDataException(
                    $"Composite source-map node {index} handler does not follow its token");
            if (node.OperandAddress is ushort operandAddress)
            {
                if (operandAddress != node.Address + 2 ||
                    operandAddress + 1 >= CompositeWordBuilder.BodyEndExclusive)
                    throw new InvalidDataException(
                        $"Composite source-map node {index} operand is outside the body");
                ushort encoded = (ushort)(
                    (outputImage[operandAddress] << 8) | outputImage[operandAddress + 1]);
                if (node.OperandValue != encoded)
                    throw new InvalidDataException(
                        $"Composite source-map node {index} operand value differs");
            }
            cursor += bytes.Length;
        }
        if (cursor != CompositeWordBuilder.BodyEndExclusive)
            throw new InvalidDataException(
                "Composite source-map node sequence does not cover the full body");
        if (!originalRom.Slice(CompositeWordBuilder.OriginalBodyStart, 14)
                .SequenceEqual(Convert.FromHexString(CompositeWordBuilder.BodyHex)))
            throw new InvalidDataException(
                "Original 9ED9 body differs from the reviewed certified body");
    }

    private static CompositeWordPhase[] BuildPhases(CompositeWordNode[] nodes)
    {
        CompositeWordNode literal0 = nodes[0];
        CompositeWordNode add = nodes[1];
        CompositeWordNode literal1 = nodes[2];
        CompositeWordNode xor = nodes[3];
        CompositeWordNode ret = nodes[4];

        return new[]
        {
            new CompositeWordPhase(
                "caller-dispatch", PhaseClassification, 0x00FC, null, 0x9F14,
                0x9ED7, 0x1010, null, null, null, null,
                "Before LDX ,Y++ at 00FC; the caller word at 9F14 is replaced by 1010."),
            new CompositeWordPhase(
                "header-trampoline-entry", PhaseClassification, 0x00F8, 0x1012, 0x9F16,
                0x00F8, null, null, null, null, 0x9F16,
                "After JMP [,X++] at 00FE and before PSHS Y; Y already advanced to 9F16."),
            new CompositeWordPhase(
                "body-prefetch-0", PhaseClassification, 0x00FC, 0x1012, 0x1012,
                literal0.Token, null, literal0.HandlerAddress, null, null, null,
                "Prefetch after PSHS/LEAY; first body token at 1012."),
            new CompositeWordPhase(
                "handler-0", PhaseClassification, literal0.HandlerAddress,
                literal0.HandlerAddress, 0x1014, literal0.Token, null,
                literal0.HandlerAddress, literal0.OperandAddress,
                literal0.OperandValue, null,
                "Native handler entry before the inline literal at 1014-1015."),
            new CompositeWordPhase(
                "body-prefetch-1", PhaseClassification, 0x00FC, literal0.HandlerAddress,
                0x1016, add.Token, null, add.HandlerAddress, null, null, null,
                "Prefetch after handler 795D pushed FF80; token at 1016."),
            new CompositeWordPhase(
                "handler-1", PhaseClassification, add.HandlerAddress, add.HandlerAddress,
                0x1018, add.Token, null, add.HandlerAddress, null, null, null,
                "Native add handler entry before PULU A,B; no inline operand."),
            new CompositeWordPhase(
                "body-prefetch-2", PhaseClassification, 0x00FC, add.HandlerAddress,
                0x1018, literal1.Token, null, literal1.HandlerAddress, null, null, null,
                "Prefetch after handler 7880; Y was not advanced by that handler."),
            new CompositeWordPhase(
                "handler-2", PhaseClassification, literal1.HandlerAddress,
                literal1.HandlerAddress, 0x101A, literal1.Token, null,
                literal1.HandlerAddress, literal1.OperandAddress,
                literal1.OperandValue, null,
                "Native handler entry before the inline literal at 101A-101B."),
            new CompositeWordPhase(
                "body-prefetch-3", PhaseClassification, 0x00FC, literal1.HandlerAddress,
                0x101C, xor.Token, null, xor.HandlerAddress, null, null, null,
                "Prefetch after the second 795D push; token at 101C."),
            new CompositeWordPhase(
                "handler-3", PhaseClassification, xor.HandlerAddress, xor.HandlerAddress,
                0x101E, xor.Token, null, xor.HandlerAddress, null, null, null,
                "Native XOR handler entry before PULU A,B; no inline operand."),
            new CompositeWordPhase(
                "body-prefetch-4", PhaseClassification, 0x00FC, xor.HandlerAddress,
                0x101E, ret.Token, null, ret.HandlerAddress, null, null, null,
                "Prefetch after handler 7AB1; final body token at 101E."),
            new CompositeWordPhase(
                "return-handler", PhaseClassification, ret.HandlerAddress,
                ret.HandlerAddress, 0x1020, ret.Token, null, ret.HandlerAddress,
                null, null, 0x9F16,
                "Return handler entry before PULS Y; saved caller cursor is 9F16."),
            new CompositeWordPhase(
                "post-return-prefetch", PhaseClassification, 0x00FC, ret.HandlerAddress,
                0x9F16, 0x75A9, null, null, null, null, null,
                "After PULS Y; caller successor token at 9F16 is 75A9.")
        };
    }

    private static string Sha1(ReadOnlySpan<byte> bytes) =>
        Convert.ToHexString(SHA1.HashData(bytes));

    private static string Sha256(ReadOnlySpan<byte> bytes) =>
        Convert.ToHexString(SHA256.HashData(bytes));
}

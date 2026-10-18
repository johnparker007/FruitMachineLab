using System.Security.Cryptography;

namespace FruitMachineLab.Il;

public static class NineEdNineDecoder
{
    public const int RequiredRomLength = 65536;
    public const string RequiredRomSha1 = "402D1518BB78FDC489B06C2AABC771E5CE151847";
    public const string RequiredRomSha256 = "EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C";

    public const ushort HeaderAddress = 0x9ED7;
    public const ushort HeaderValue = 0x00F8;
    public const ushort BodyStart = 0x9ED9;
    public const int BodyEndExclusive = 0x9EE7;

    public const string ListingPath = "evidence/mpu4/VM-SCRIPTS/9ED9.txt";
    public const string ListingSha256 = "15A98BF4A6F58BFC5622FEA8304134BA3CAB2133866A6DDA5B1C321E45A68CC6";
    public const string CheckpointPath = "evidence/mpu4/maps/nudge-encoding-checkpoint.json";
    public const string CheckpointSpanClassification =
        "Exact selected ROM span and checked listed tokens; gaps/operands/embedded data preserved verbatim.";
    public const int ObservedSites = 5;

    public const string EvidenceClass =
        "Direct decode of the identity-checked original ROM bytes. Five cited sites are marked observed in the reviewed " +
        "MAME listing; the 795B inline-word width is cited from the separately checked interpreter path 795B->795D ECA1. " +
        "This is static/original-ROM evidence, not natural or synthetic execution.";

    public static VmIlDefinition Decode(ReadOnlySpan<byte> rom)
    {
        ValidateIdentity(rom, RequiredRomLength, RequiredRomSha1, RequiredRomSha256);
        return DecodeImageWithoutIdentityForTests(
            rom, HeaderAddress, HeaderValue, BodyStart, BodyEndExclusive);
    }

    internal static void ValidateIdentity(
        ReadOnlySpan<byte> rom, int expectedLength, string expectedSha1, string expectedSha256)
    {
        if (rom.Length != expectedLength)
            throw new InvalidDataException(
                $"ROM length mismatch: expected {expectedLength}, got {rom.Length}");

        string sha1 = Convert.ToHexString(SHA1.HashData(rom));
        if (!string.Equals(sha1, expectedSha1, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                $"ROM SHA1 identity mismatch: expected {expectedSha1.ToUpperInvariant()}, got {sha1}");

        string sha256 = Convert.ToHexString(SHA256.HashData(rom));
        if (!string.Equals(sha256, expectedSha256, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                $"ROM SHA256 identity mismatch: expected {expectedSha256.ToUpperInvariant()}, got {sha256}");
    }

    internal static VmIlDefinition DecodeImageWithoutIdentityForTests(
        ReadOnlySpan<byte> image,
        ushort headerAddress,
        ushort expectedHeaderValue,
        ushort expectedBodyStart,
        int expectedEndExclusive)
    {
        if (image.Length != RequiredRomLength)
            throw new InvalidDataException(
                $"ROM length mismatch: expected {RequiredRomLength}, got {image.Length}");

        if (headerAddress > image.Length - 2)
            throw new InvalidDataException("VM header is outside the ROM image");

        ushort headerValue = (ushort)((image[headerAddress] << 8) | image[headerAddress + 1]);
        if (headerValue != expectedHeaderValue)
            throw new InvalidDataException(
                $"VM header mismatch at {headerAddress:X4}: expected {expectedHeaderValue:X4}, got {headerValue:X4}");

        int derivedBodyStart = headerAddress + 2;
        if (derivedBodyStart != expectedBodyStart)
            throw new InvalidDataException(
                $"VM body-start mismatch: header derives {derivedBodyStart:X4}, expected {expectedBodyStart:X4}");

        if (expectedEndExclusive <= expectedBodyStart || expectedEndExclusive > image.Length)
            throw new InvalidDataException(
                $"VM definition end {expectedEndExclusive:X4} is outside the body span");

        byte[] headerBytes = image.Slice(headerAddress, 2).ToArray();
        ReadOnlySpan<byte> body = image.Slice(
            expectedBodyStart, expectedEndExclusive - expectedBodyStart);

        string sha1 = Convert.ToHexString(SHA1.HashData(image));
        string sha256 = Convert.ToHexString(SHA256.HashData(image));
        return DecodeBodyCore(
            body, expectedBodyStart, expectedEndExclusive, image.Length, sha1, sha256, headerBytes);
    }

    internal static VmIlDefinition DecodeBodyForTests(
        ReadOnlySpan<byte> body, ushort bodyAddress, int bodyEndExclusive)
    {
        string sha1 = Convert.ToHexString(SHA1.HashData(body));
        string sha256 = Convert.ToHexString(SHA256.HashData(body));
        return DecodeBodyCore(
            body, bodyAddress, bodyEndExclusive, RequiredRomLength, sha1, sha256,
            new byte[] { 0x00, 0xF8 });
    }

    private static VmIlDefinition DecodeBodyCore(
        ReadOnlySpan<byte> body,
        ushort bodyAddress,
        int bodyEndExclusive,
        int romLength,
        string romSha1,
        string romSha256,
        byte[] headerBytes)
    {
        if (bodyEndExclusive <= bodyAddress)
            throw new InvalidDataException("VM definition end does not follow the body start");
        if (bodyEndExclusive > 0x10000)
            throw new InvalidDataException(
                $"VM definition end {bodyEndExclusive:X4} exceeds the 16-bit address space");
        if (bodyAddress + body.Length > 0x10000)
            throw new InvalidDataException("VM body exceeds the 16-bit address space");

        var nodes = new List<VmIlNode>();
        int cursor = bodyAddress;
        int offset = 0;
        bool returned = false;

        while (offset < body.Length)
        {
            if (returned)
                throw new InvalidDataException(
                    $"VM bytes follow the return token at {cursor:X4}");

            if (cursor + 2 > bodyEndExclusive)
                throw new InvalidDataException(
                    $"VM token at {cursor:X4} crosses the definition end {bodyEndExclusive:X4}");
            if (cursor + 2 > 0x10000)
                throw new InvalidDataException(
                    $"VM token at {cursor:X4} exceeds the 16-bit address space");
            if (offset + 2 > body.Length)
                throw new InvalidDataException($"Truncated VM token at {cursor:X4}");

            ushort token = (ushort)((body[offset] << 8) | body[offset + 1]);
            if (!VmIlVocabulary.TryGetOperation(token, out string operation, out int operandBytes))
                throw new InvalidDataException($"Unsupported VM token {token:X4} at {cursor:X4}");

            int nodeLength = 2 + operandBytes;
            if (cursor + nodeLength > bodyEndExclusive)
                throw new InvalidDataException(
                    $"VM instruction at {cursor:X4} crosses the definition end {bodyEndExclusive:X4}");
            if (cursor + nodeLength > 0x10000)
                throw new InvalidDataException(
                    $"VM instruction at {cursor:X4} exceeds the 16-bit address space");
            if (offset + nodeLength > body.Length)
                throw new InvalidDataException($"Truncated VM operand at {cursor:X4}");

            byte[] nodeBytes = body.Slice(offset, nodeLength).ToArray();
            VmIlOperand? operand = null;
            if (operandBytes == 2)
            {
                ushort value = (ushort)((body[offset + 2] << 8) | body[offset + 3]);
                operand = new VmIlOperand(
                    (ushort)(cursor + 2),
                    body.Slice(offset + 2, 2).ToArray(),
                    value);
            }

            if (token == VmIlVocabulary.ReturnToCallerStream)
            {
                if (returned)
                    throw new InvalidDataException($"Multiple VM return tokens at {cursor:X4}");
                if (cursor + nodeLength != bodyEndExclusive)
                    throw new InvalidDataException(
                        $"Multiple VM returns or bytes follow the return token at {cursor:X4}; " +
                        $"expected end {bodyEndExclusive:X4}");
                returned = true;
            }

            nodes.Add(new VmIlNode(
                nodes.Count,
                (ushort)cursor,
                token,
                operation,
                nodeBytes,
                operand,
                VmIlEvidenceClass.OriginalRomBytes));

            cursor += nodeLength;
            offset += nodeLength;
        }

        if (!returned)
            throw new InvalidDataException("VM definition is missing its return token");
        if (cursor != bodyEndExclusive)
            throw new InvalidDataException(
                $"VM span ends at {cursor:X4}; expected {bodyEndExclusive:X4}");
        if (offset != body.Length)
            throw new InvalidDataException(
                $"VM body length {body.Length} does not match its decoded span");

        return new VmIlDefinition(
            romLength,
            romSha1,
            romSha256,
            HeaderAddress,
            headerBytes,
            bodyAddress,
            bodyEndExclusive,
            nodes,
            new VmIlProvenance(
                EvidenceClass,
                ListingPath,
                ListingSha256,
                CheckpointPath,
                CheckpointSpanClassification,
                ObservedSites));
    }
}

using System.Security.Cryptography;

namespace FruitMachineLab.Il;

public sealed record NineASixFourHandlerInstruction(
    ushort Address,
    byte[] Bytes,
    string Mnemonic,
    string Operand);

public sealed record NineASixFourBranchHandler(
    ushort TokenAddress,
    ushort HandlerAddress,
    string Operation,
    VmIlBranchCondition Condition,
    IReadOnlyList<NineASixFourHandlerInstruction> Instructions,
    string Semantics);

public static class NineASixFourDecoder
{
    public const int RequiredRomLength = 65536;
    public const string RequiredRomSha1 = "402D1518BB78FDC489B06C2AABC771E5CE151847";
    public const string RequiredRomSha256 = "EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C";

    public const ushort HeaderAddress = 0x9A62;
    public const ushort HeaderValue = 0x00F8;
    public const ushort BodyStart = 0x9A64;
    public const int BodyEndExclusive = 0x9A72;

    public const string ListingPath = "evidence/mpu4/VM-SCRIPTS/9A64.txt";
    public const string ListingSha256 = "01A93F20773E1530FCCCA66CC4C3ACB2C066F4595C1A0371B08EBF99D3CDC3E9";
    public const string CheckpointPath = "evidence/mpu4/maps/nudge-encoding-checkpoint.json";
    public const string CheckpointSpanClassification =
        "Exact selected ROM span and checked listed tokens; gaps/operands/embedded data preserved verbatim.";
    public const int ObservedSites = 6;

    public const ushort BranchIfZeroToken = 0x7982;
    public const ushort BranchIfZeroHandler = 0x7984;
    public const ushort UnsignedForward8Token = 0x7979;
    public const ushort UnsignedForward8Handler = 0x797B;

    public const string OffsetBase = "operand-address";
    public const int BranchOperandWidthBytes = 1;

    public const string EvidenceClass =
        "Direct static decode of the identity-checked original ROM bytes. Six cited sites are marked observed " +
        "in the reviewed MAME listing; the byte-branch base and signedness are decoded from the original 6809 " +
        "handler bytes at 797B and 7984. This is static original-ROM evidence, not natural or synthetic execution.";

    public const string BranchEvidenceClass =
        "Static decoded contract from original-ROM 6809 handlers 797B/7984: one unsigned byte operand at the " +
        "operand address, forward target = operand address + operand byte. No natural 9A64 branch execution " +
        "or runtime path coverage is claimed.";

    public static VmIlDefinition Decode(ReadOnlySpan<byte> rom)
    {
        ValidateIdentity(rom);
        return DecodeImageWithoutIdentityForTests(
            rom, HeaderAddress, HeaderValue, BodyStart, BodyEndExclusive);
    }

    public static IReadOnlyList<NineASixFourBranchHandler> DecodeBranchHandlers(
        ReadOnlySpan<byte> rom)
    {
        ValidateIdentity(rom);
        return DecodeBranchHandlersCore(rom);
    }

    internal static void ValidateIdentity(ReadOnlySpan<byte> rom)
    {
        if (rom.Length != RequiredRomLength)
            throw new InvalidDataException(
                $"ROM length mismatch: expected {RequiredRomLength}, got {rom.Length}");

        string sha1 = Convert.ToHexString(SHA1.HashData(rom));
        if (!string.Equals(sha1, RequiredRomSha1, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                $"ROM SHA1 identity mismatch: expected {RequiredRomSha1.ToUpperInvariant()}, got {sha1}");

        string sha256 = Convert.ToHexString(SHA256.HashData(rom));
        if (!string.Equals(sha256, RequiredRomSha256, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                $"ROM SHA256 identity mismatch: expected {RequiredRomSha256.ToUpperInvariant()}, got {sha256}");
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

        ushort headerValue = ReadWord(image, headerAddress);
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
        string sha1 = Convert.ToHexString(SHA1.HashData(image));
        string sha256 = Convert.ToHexString(SHA256.HashData(image));
        return DecodeBodyCore(image, expectedBodyStart, expectedEndExclusive, headerBytes, sha1, sha256);
    }

    private static VmIlDefinition DecodeBodyCore(
        ReadOnlySpan<byte> image,
        int bodyStart,
        int bodyEndExclusive,
        byte[] headerBytes,
        string romSha1,
        string romSha256)
    {
        if (bodyEndExclusive <= bodyStart)
            throw new InvalidDataException("VM definition end does not follow the body start");
        if (bodyEndExclusive > 0x10000)
            throw new InvalidDataException(
                $"VM definition end {bodyEndExclusive:X4} exceeds the 16-bit address space");

        IReadOnlyList<NineASixFourBranchHandler> handlers = DecodeBranchHandlersCore(image);
        var nodes = new List<VmIlNode>();
        int cursor = bodyStart;
        bool returned = false;

        while (cursor < bodyEndExclusive)
        {
            if (returned)
                throw new InvalidDataException(
                    $"VM bytes follow the return token at {cursor:X4}");
            if (cursor + 2 > bodyEndExclusive)
                throw new InvalidDataException(
                    $"VM token at {cursor:X4} crosses the definition end {bodyEndExclusive:X4}");

            ushort token = ReadWord(image, cursor);
            if (!VmIlVocabulary.TryGetOperation(
                    token, out string operation, out int operandBytes,
                    includeNineASixFour: true))
                throw new InvalidDataException($"Unsupported VM token {token:X4} at {cursor:X4}");
            if (!VmIlVocabulary.IsNineASixFourToken(token))
                throw new InvalidDataException(
                    $"VM token {token:X4} at {cursor:X4} is outside the supported 9A64 definition");
            if (operandBytes is not (0 or 1))
                throw new InvalidDataException(
                    $"Unsupported VM operand width for token {token:X4} at {cursor:X4}");
            if (operandBytes == 1 && !VmIlVocabulary.IsBranchWithByteOperand(token))
                throw new InvalidDataException(
                    $"VM token {token:X4} at {cursor:X4} has an unsupported byte operand");

            int nodeLength = 2 + operandBytes;
            if (cursor + nodeLength > bodyEndExclusive)
                throw new InvalidDataException(
                    $"VM instruction at {cursor:X4} crosses the definition end {bodyEndExclusive:X4}");
            if (cursor + nodeLength > 0x10000)
                throw new InvalidDataException(
                    $"VM instruction at {cursor:X4} exceeds the 16-bit address space");

            ValidateTokenHeader(image, token);
            byte[] nodeBytes = image.Slice(cursor, nodeLength).ToArray();
            VmIlBranch? branch = null;

            if (operandBytes == 1)
            {
                NineASixFourBranchHandler handler = handlers.Single(item =>
                    item.TokenAddress == token);
                if (handler.HandlerAddress != ReadWord(image, token))
                    throw new InvalidDataException(
                        $"VM token {token:X4} at {cursor:X4} does not point at its decoded handler");

                ushort operandAddress = (ushort)(cursor + 2);
                byte operandByte = image[operandAddress];
                ushort target = (ushort)(operandAddress + operandByte);
                branch = new VmIlBranch(
                    handler.HandlerAddress,
                    operandAddress,
                    operandByte,
                    target,
                    handler.Condition,
                    OffsetBase,
                    OffsetUnsigned: true,
                    BranchOperandWidthBytes,
                    BranchEvidenceClass);
            }

            if (token == VmIlVocabulary.ReturnToCallerStream)
            {
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
                Operand: null,
                VmIlEvidenceClass.OriginalRomBytes)
            {
                Branch = branch
            });

            cursor += nodeLength;
        }

        if (!returned)
            throw new InvalidDataException("VM definition is missing its return token");
        if (cursor != bodyEndExclusive)
            throw new InvalidDataException(
                $"VM span ends at {cursor:X4}; expected {bodyEndExclusive:X4}");

        ValidateBranchTargets(nodes, bodyStart, bodyEndExclusive);

        return new VmIlDefinition(
            RequiredRomLength,
            romSha1,
            romSha256,
            HeaderAddress,
            headerBytes,
            (ushort)bodyStart,
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

    private static void ValidateBranchTargets(
        IReadOnlyList<VmIlNode> nodes, int bodyStart, int bodyEndExclusive)
    {
        var boundaries = new HashSet<ushort>(nodes.Select(node => node.Address));
        foreach (VmIlNode node in nodes)
        {
            if (node.Branch is null)
                continue;

            VmIlBranch branch = node.Branch;
            if (branch.OperandWidthBytes != BranchOperandWidthBytes)
                throw new InvalidDataException(
                    $"Branch at {node.Address:X4} has an unsupported operand width");
            if (!branch.OffsetUnsigned || branch.OffsetBase != OffsetBase)
                throw new InvalidDataException(
                    $"Branch at {node.Address:X4} has unsupported offset semantics");
            if (branch.OperandAddress != node.Address + 2)
                throw new InvalidDataException(
                    $"Branch operand at {branch.OperandAddress:X4} does not follow token {node.Address:X4}");
            if (branch.OperandAddress >= bodyEndExclusive ||
                node.Bytes.Length != 3 ||
                node.Bytes[2] != branch.OperandByte)
                throw new InvalidDataException(
                    $"Branch operand at {branch.OperandAddress:X4} does not match the original byte");
            if (branch.TargetAddress != (ushort)(branch.OperandAddress + branch.OperandByte))
                throw new InvalidDataException(
                    $"Branch target {branch.TargetAddress:X4} does not match operand-address plus unsigned byte");

            if (branch.TargetAddress <= branch.OperandAddress)
                throw new InvalidDataException(
                    $"Branch target {branch.TargetAddress:X4} is inside or before its operand at " +
                    $"{branch.OperandAddress:X4}");
            if (branch.TargetAddress < bodyStart || branch.TargetAddress >= bodyEndExclusive)
                throw new InvalidDataException(
                    $"Branch target {branch.TargetAddress:X4} is outside the definition span " +
                    $"{bodyStart:X4}..{bodyEndExclusive - 1:X4}");
            if (!boundaries.Contains(branch.TargetAddress))
                throw new InvalidDataException(
                    $"Branch target {branch.TargetAddress:X4} is not an instruction boundary in this definition");

            VmIlBranchCondition expectedCondition =
                node.Token == BranchIfZeroToken
                    ? VmIlBranchCondition.IfZero
                    : node.Token == UnsignedForward8Token
                        ? VmIlBranchCondition.Always
                        : throw new InvalidDataException(
                            $"VM token {node.Token:X4} at {node.Address:X4} is not a supported branch");
            if (branch.Condition != expectedCondition)
                throw new InvalidDataException(
                    $"Branch condition at {node.Address:X4} does not match the decoded handler");
            if (branch.HandlerAddress != node.Token + 2)
                throw new InvalidDataException(
                    $"Branch handler at {branch.HandlerAddress:X4} does not follow token {node.Address:X4}");
        }
    }

    private static void ValidateTokenHeader(
        ReadOnlySpan<byte> image, ushort token)
    {
        int tokenAddress = token;
        if (tokenAddress + 2 > image.Length)
            throw new InvalidDataException(
                $"VM token {token:X4} has no header pointer inside the ROM image");
        ushort pointer = ReadWord(image, tokenAddress);
        ushort expectedHandler = (ushort)(tokenAddress + 2);
        if (pointer != expectedHandler)
            throw new InvalidDataException(
                $"VM token {token:X4} points at {pointer:X4}; " +
                $"decoded handler entry is {expectedHandler:X4}");
    }

    private static IReadOnlyList<NineASixFourBranchHandler> DecodeBranchHandlersCore(
        ReadOnlySpan<byte> image)
    {
        if (image.Length < RequiredRomLength)
            throw new InvalidDataException("ROM image is too short to decode branch handlers");

        ushort unsignedToken = ValidateHandlerToken(
            image, UnsignedForward8Token, UnsignedForward8Handler);
        ushort ifZeroToken = ValidateHandlerToken(
            image, BranchIfZeroToken, BranchIfZeroHandler);

        IReadOnlyList<NineASixFourHandlerInstruction> unsignedInstructions =
            DecodeHandler(image, UnsignedForward8Handler, expectedJump: 0xFC);
        IReadOnlyList<NineASixFourHandlerInstruction> ifZeroInstructions =
            DecodeHandler(image, BranchIfZeroHandler, expectedJump: 0xFC);

        ValidateInstructionSequence(
            unsignedInstructions,
            UnsignedForward8Handler,
            new[]
            {
                ("LDAB", ",Y"),
                ("CLRA", ""),
                ("LEAY", "D,Y"),
                ("JMP", "<$FC")
            });
        ValidateInstructionSequence(
            ifZeroInstructions,
            BranchIfZeroHandler,
            new[]
            {
                ("LDD", ",U++"),
                ("BEQ", $"${UnsignedForward8Handler:X4}"),
                ("LEAY", "1,Y"),
                ("JMP", "<$FC")
            });

        return new[]
        {
            new NineASixFourBranchHandler(
                unsignedToken,
                UnsignedForward8Handler,
                VmIlVocabulary.BranchUnsignedForward8Operation,
                VmIlBranchCondition.Always,
                unsignedInstructions,
                "LDAB ,Y reads the byte at Y without advancing; CLRA zero-extends it to an unsigned " +
                "16-bit value; LEAY D,Y replaces Y with operand-address + unsigned operand. No data " +
                "cell is consumed."),
            new NineASixFourBranchHandler(
                ifZeroToken,
                BranchIfZeroHandler,
                VmIlVocabulary.BranchForward8IfZeroOperation,
                VmIlBranchCondition.IfZero,
                ifZeroInstructions,
                "LDD ,U++ pops one 16-bit data cell and tests it. When the cell is 0000, BEQ enters " +
                "the 797B handler, so Y becomes operand-address + unsigned operand. When nonzero, " +
                "LEAY 1,Y skips exactly the one-byte operand.")
        };
    }

    private static ushort ValidateHandlerToken(
        ReadOnlySpan<byte> image, ushort tokenAddress, ushort expectedHandler)
    {
        if (tokenAddress + 2 > image.Length)
            throw new InvalidDataException(
                $"Branch token {tokenAddress:X4} is outside the ROM image");
        ushort pointer = ReadWord(image, tokenAddress);
        if (pointer != expectedHandler)
            throw new InvalidDataException(
                $"Branch token {tokenAddress:X4} points at {pointer:X4}; " +
                $"expected decoded handler {expectedHandler:X4}");
        return tokenAddress;
    }

    private static IReadOnlyList<NineASixFourHandlerInstruction> DecodeHandler(
        ReadOnlySpan<byte> image, ushort handlerAddress, byte expectedJump)
    {
        var instructions = new List<NineASixFourHandlerInstruction>();
        int cursor = handlerAddress;

        while (true)
        {
            if (cursor >= image.Length)
                throw new InvalidDataException(
                    $"Handler {handlerAddress:X4} runs outside the ROM image");

            byte opcode = image[cursor];
            switch (opcode)
            {
                case 0xE6:
                {
                    RequireBytes(image, cursor, 2, handlerAddress);
                    byte post = image[cursor + 1];
                    if (post != 0xA4)
                        throw new InvalidDataException(
                            $"Handler {handlerAddress:X4}: unsupported LDAB indexed postbyte {post:X2}");
                    instructions.Add(Instruction(image, cursor, 2, "LDAB", ",Y"));
                    cursor += 2;
                    break;
                }
                case 0x4F:
                    instructions.Add(Instruction(image, cursor, 1, "CLRA", ""));
                    cursor += 1;
                    break;
                case 0x31:
                {
                    RequireBytes(image, cursor, 2, handlerAddress);
                    byte post = image[cursor + 1];
                    string operand = post switch
                    {
                        0xAB => "D,Y",
                        0x21 => "1,Y",
                        _ => throw new InvalidDataException(
                            $"Handler {handlerAddress:X4}: unsupported LEAY indexed postbyte {post:X2}")
                    };
                    instructions.Add(Instruction(image, cursor, 2, "LEAY", operand));
                    cursor += 2;
                    break;
                }
                case 0x0E:
                {
                    RequireBytes(image, cursor, 2, handlerAddress);
                    byte target = image[cursor + 1];
                    if (target != expectedJump)
                        throw new InvalidDataException(
                            $"Handler {handlerAddress:X4}: JMP target {target:X2} is not the " +
                            $"expected NEXT entry {expectedJump:X2}");
                    instructions.Add(Instruction(
                        image, cursor, 2, "JMP", $"<${target:X2}"));
                    return instructions;
                }
                case 0xEC:
                {
                    RequireBytes(image, cursor, 2, handlerAddress);
                    byte post = image[cursor + 1];
                    if (post != 0xC1)
                        throw new InvalidDataException(
                            $"Handler {handlerAddress:X4}: unsupported LDD indexed postbyte {post:X2}");
                    instructions.Add(Instruction(image, cursor, 2, "LDD", ",U++"));
                    cursor += 2;
                    break;
                }
                case 0x27:
                {
                    RequireBytes(image, cursor, 2, handlerAddress);
                    sbyte relative = unchecked((sbyte)image[cursor + 1]);
                    ushort target = (ushort)(cursor + 2 + relative);
                    instructions.Add(Instruction(
                        image, cursor, 2, "BEQ", $"${target:X4}"));
                    cursor += 2;
                    break;
                }
                default:
                    throw new InvalidDataException(
                        $"Handler {handlerAddress:X4}: unsupported 6809 opcode {opcode:X2} " +
                        $"at {cursor:X4}");
            }
        }
    }

    private static void ValidateInstructionSequence(
        IReadOnlyList<NineASixFourHandlerInstruction> instructions,
        ushort handlerAddress,
        IReadOnlyList<(string Mnemonic, string Operand)> expected)
    {
        if (instructions.Count != expected.Count)
            throw new InvalidDataException(
                $"Handler {handlerAddress:X4} has {instructions.Count} decoded instructions; " +
                $"expected {expected.Count}");
        for (int index = 0; index < expected.Count; index++)
        {
            if (!string.Equals(instructions[index].Mnemonic, expected[index].Mnemonic,
                    StringComparison.Ordinal) ||
                !string.Equals(instructions[index].Operand, expected[index].Operand,
                    StringComparison.Ordinal))
                throw new InvalidDataException(
                    $"Handler {handlerAddress:X4} instruction {index} decodes as " +
                    $"{instructions[index].Mnemonic} {instructions[index].Operand}; expected " +
                    $"{expected[index].Mnemonic} {expected[index].Operand}");
        }
    }

    private static NineASixFourHandlerInstruction Instruction(
        ReadOnlySpan<byte> image, int address, int length, string mnemonic, string operand) =>
        new((ushort)address, image.Slice(address, length).ToArray(), mnemonic, operand);

    private static void RequireBytes(
        ReadOnlySpan<byte> image, int address, int length, ushort handlerAddress)
    {
        if (address + length > image.Length)
            throw new InvalidDataException(
                $"Handler {handlerAddress:X4} instruction at {address:X4} crosses the ROM end");
    }

    private static ushort ReadWord(ReadOnlySpan<byte> image, int address)
    {
        if (address < 0 || address + 2 > image.Length)
            throw new InvalidDataException(
                $"16-bit read at {address:X4} is outside the ROM image");
        return (ushort)((image[address] << 8) | image[address + 1]);
    }
}

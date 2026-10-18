using System.Security.Cryptography;

namespace FruitMachineLab.Il;

public static class VmIlCompiler
{
    public const ushort SupportedEditTokenAddress = 0x9ED9;
    public const ushort SupportedEditOperandAddress = 0x9EDB;
    public const ushort SupportedEditOriginalValue = 0xFF80;
    public const int SupportedEditOperandWidthBytes = 2;

    public const string UnrepairedIntegrityStatus =
        "UNREPAIRED experimental artifact: firmware integrity fields were not regenerated. " +
        "No boot, MAME execution, integrity acceptance or hardware compatibility is claimed.";

    public static VmIlCompileResult CompileIdentity(
        VmIlDefinition definition, ReadOnlySpan<byte> originalImage)
    {
        ArgumentNullException.ThrowIfNull(definition);

        ValidateOriginalIdentity(originalImage);
        string inputSha1 = Sha1(originalImage);
        string inputSha256 = Sha256(originalImage);
        ValidateDefinitionIdentity(definition, originalImage.Length, inputSha1, inputSha256);

        List<byte> emitted = BuildEmittedBody(
            definition, originalImage, editedNodeIndex: null, editedNodeBytes: null);
        byte[] emittedBody = emitted.ToArray();

        byte[] image = originalImage.ToArray();
        emittedBody.CopyTo(image, definition.BodyStart);

        int[] changed = ChangedOffsets(originalImage, image);
        string outputSha256 = Sha256(image);
        return new VmIlCompileResult(
            image, emittedBody, inputSha256, outputSha256, changed);
    }

    public static VmIlEditCompileResult CompileEdit(
        ReadOnlySpan<byte> originalImage, VmIlOperandEdit edit)
    {
        if (edit is null)
            throw new ArgumentNullException(nameof(edit));
        return CompileEdits(originalImage, new[] { edit });
    }

    public static VmIlRepairedEditCompileResult CompileEditWithIntegrity(
        ReadOnlySpan<byte> originalImage, VmIlOperandEdit edit)
    {
        VmIlEditCompileResult unrepaired = CompileEdit(originalImage, edit);
        VmIlIntegrityResult integrity =
            VmIlIntegrity.Repair(originalImage, unrepaired.Compile.Image);
        return new VmIlRepairedEditCompileResult(unrepaired, integrity);
    }

    public static VmIlEditCompileResult CompileEdits(
        ReadOnlySpan<byte> originalImage, IReadOnlyList<VmIlOperandEdit> edits)
    {
        VmIlDefinition definition = NineEdNineDecoder.Decode(originalImage);
        return CompileEditsCore(definition, originalImage, edits);
    }

    internal static VmIlEditCompileResult CompileEditsForTests(
        VmIlDefinition definition,
        ReadOnlySpan<byte> originalImage,
        IReadOnlyList<VmIlOperandEdit> edits)
    {
        return CompileEditsCore(definition, originalImage, edits);
    }

    private static VmIlEditCompileResult CompileEditsCore(
        VmIlDefinition definition,
        ReadOnlySpan<byte> originalImage,
        IReadOnlyList<VmIlOperandEdit> edits)
    {
        ArgumentNullException.ThrowIfNull(definition);
        ArgumentNullException.ThrowIfNull(edits);

        ValidateOriginalIdentity(originalImage);
        string originalSha1 = Sha1(originalImage);
        string originalSha256 = Sha256(originalImage);
        ValidateDefinitionIdentity(
            definition, originalImage.Length, originalSha1, originalSha256);

        if (edits.Count != 1)
            throw new InvalidDataException(
                "Exactly one explicit operand edit is supported; multiple or overlapping edits are rejected");
        VmIlOperandEdit edit = edits[0] ??
            throw new InvalidDataException("The declared operand edit is missing");

        if (edit.OperandAddress != SupportedEditOperandAddress)
            throw new InvalidDataException(
                $"Unsupported edit operand address {edit.OperandAddress:X4}; " +
                $"only the first 9ED9 literal operand at {SupportedEditOperandAddress:X4} is supported");

        VmIlNode? target = definition.Nodes?
            .FirstOrDefault(node => node is not null &&
                                    node.Operand is not null &&
                                    node.Operand.Address == edit.OperandAddress);
        if (target is null)
            throw new InvalidDataException(
                $"Unsupported edit operand address {edit.OperandAddress:X4}; " +
                "no decoded operand exists there");
        if (target.Index != 0 || target.Address != SupportedEditTokenAddress ||
            target.Token != VmIlVocabulary.InlineWordLiteral ||
            !string.Equals(target.Operation, VmIlVocabulary.InlineWordLiteralOperation,
                StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Unsupported edit target token {target.Token:X4} at {target.Address:X4}; " +
                "only the first 795B inline-word literal is editable");

        VmIlOperand operand = target.Operand!;
        if (operand.Bytes is null || operand.Bytes.Length != SupportedEditOperandWidthBytes)
            throw new InvalidDataException(
                $"Unsupported edit operand width at {operand.Address:X4}; " +
                $"expected {SupportedEditOperandWidthBytes} bytes");
        if (target.Bytes is null || target.Bytes.Length != 2 + SupportedEditOperandWidthBytes)
            throw new InvalidDataException(
                $"Unsupported edit node width at {target.Address:X4}; " +
                $"expected {2 + SupportedEditOperandWidthBytes} bytes");

        if (operand.Value != edit.ExpectedOriginalValue)
            throw new InvalidDataException(
                $"Edit expected original value {edit.ExpectedOriginalValue:X4} does not match " +
                $"the decoded value {operand.Value:X4} at {operand.Address:X4}");
        if (edit.ExpectedOriginalValue != SupportedEditOriginalValue)
            throw new InvalidDataException(
                $"Unsupported expected original literal {edit.ExpectedOriginalValue:X4}; " +
                $"only {SupportedEditOriginalValue:X4} is supported");
        if (edit.ReplacementValue == edit.ExpectedOriginalValue)
            throw new InvalidDataException(
                $"Edit replacement {edit.ReplacementValue:X4} equals the original literal; " +
                "no-op edits are rejected");

        byte[] replacementBytes =
        {
            (byte)(edit.ReplacementValue >> 8),
            (byte)(edit.ReplacementValue & 0xFF)
        };
        byte[] editedNode = target.Bytes.ToArray();
        editedNode[2] = replacementBytes[0];
        editedNode[3] = replacementBytes[1];

        List<byte> emitted = BuildEmittedBody(
            definition, originalImage, target.Index, editedNode);
        byte[] emittedBody = emitted.ToArray();
        byte[] image = originalImage.ToArray();
        emittedBody.CopyTo(image, definition.BodyStart);

        var changed = new List<int>();
        for (int offset = 0; offset < image.Length; offset++)
        {
            if (image[offset] == originalImage[offset])
                continue;
            if (offset < operand.Address || offset >= operand.Address + operand.Bytes.Length)
                throw new InvalidDataException(
                    $"Edited compile changed unrelated byte at {offset:X4}; " +
                    $"only {operand.Address:X4}..{operand.Address + operand.Bytes.Length - 1:X4} may differ");
            changed.Add(offset);
        }

        var expectedDiff = new List<int>();
        for (int index = 0; index < operand.Bytes.Length; index++)
        {
            if (operand.Bytes[index] != replacementBytes[index])
                expectedDiff.Add(operand.Address + index);
        }
        if (!changed.SequenceEqual(expectedDiff))
            throw new InvalidDataException(
                "Edited compile diff does not match the declared operand replacement");

        string outputSha256 = Sha256(image);
        var compile = new VmIlCompileResult(
            image, emittedBody, originalSha256, outputSha256, changed.ToArray());
        var report = new VmIlEditReport(
            target.Index,
            target.Address,
            operand.Address,
            target.Token,
            target.Operation,
            operand.Bytes.Length,
            edit.ExpectedOriginalValue,
            operand.Value,
            edit.ReplacementValue,
            Convert.ToHexString(operand.Bytes),
            Convert.ToHexString(replacementBytes),
            changed.ToArray());

        return new VmIlEditCompileResult(
            definition,
            compile,
            report,
            originalSha1,
            originalSha256,
            false,
            UnrepairedIntegrityStatus);
    }

    private static List<byte> BuildEmittedBody(
        VmIlDefinition definition,
        ReadOnlySpan<byte> originalImage,
        int? editedNodeIndex,
        byte[]? editedNodeBytes)
    {
        if (definition.Nodes is null || definition.Nodes.Count == 0)
            throw new InvalidDataException("VM definition has no nodes");
        if (definition.HeaderBytes is null || definition.HeaderBytes.Length != 2)
            throw new InvalidDataException("VM definition header must be two bytes");
        if (definition.HeaderAddress > originalImage.Length - 2)
            throw new InvalidDataException("VM definition header is outside the ROM image");

        ReadOnlySpan<byte> actualHeader =
            originalImage.Slice(definition.HeaderAddress, 2);
        if (!actualHeader.SequenceEqual(definition.HeaderBytes))
            throw new InvalidDataException(
                $"VM definition header bytes do not match the original ROM at {definition.HeaderAddress:X4}");

        int derivedBodyStart = definition.HeaderAddress + definition.HeaderBytes.Length;
        if (definition.BodyStart != derivedBodyStart)
            throw new InvalidDataException(
                $"VM body start {definition.BodyStart:X4} does not follow the header; " +
                $"expected {derivedBodyStart:X4}");
        if (definition.BodyEndExclusive <= definition.BodyStart)
            throw new InvalidDataException("VM definition end does not follow the body start");
        if (definition.BodyEndExclusive > 0x10000)
            throw new InvalidDataException(
                $"VM definition end {definition.BodyEndExclusive:X4} exceeds the 16-bit address space");
        if (definition.BodyEndExclusive > originalImage.Length)
            throw new InvalidDataException("VM definition span exceeds the ROM image");

        var emitted = new List<byte>(definition.BodyLength);
        int cursor = definition.BodyStart;
        bool sawReturn = false;
        bool includeNineASixFour = IsNineASixFourDefinition(definition);

        for (int index = 0; index < definition.Nodes.Count; index++)
        {
            VmIlNode? node = definition.Nodes[index];
            if (node is null)
                throw new InvalidDataException($"VM definition node {index} is missing");
            if (node.Index != index)
                throw new InvalidDataException(
                    $"VM definition node index {node.Index} does not match position {index}");
            if (node.Address != cursor)
                throw new InvalidDataException(
                    $"VM definition node {index} starts at {node.Address:X4}; expected {cursor:X4}");

            if (!VmIlVocabulary.TryGetOperation(
                    node.Token, out string operation, out int operandBytes,
                    includeNineASixFour))
                throw new InvalidDataException(
                    $"Unsupported VM token {node.Token:X4} at {node.Address:X4}");
            if (!string.Equals(node.Operation, operation, StringComparison.Ordinal))
                throw new InvalidDataException(
                    $"VM token {node.Token:X4} does not encode operation {node.Operation ?? "<null>"}");

            int nodeLength = 2 + operandBytes;
            if (node.Bytes is null || node.Bytes.Length != nodeLength)
                throw new InvalidDataException(
                    $"VM node at {node.Address:X4} has the wrong byte length");
            if (cursor + nodeLength > definition.BodyEndExclusive)
                throw new InvalidDataException(
                    $"VM node at {node.Address:X4} crosses the definition end {definition.BodyEndExclusive:X4}");
            if (cursor + nodeLength > 0x10000)
                throw new InvalidDataException(
                    $"VM node at {node.Address:X4} exceeds the 16-bit address space");

            ushort token = (ushort)((node.Bytes[0] << 8) | node.Bytes[1]);
            if (token != node.Token)
                throw new InvalidDataException(
                    $"VM node bytes at {node.Address:X4} do not encode token {node.Token:X4}");

            if (operandBytes == 2)
            {
                if (node.Branch is not null)
                    throw new InvalidDataException(
                        $"VM token {node.Token:X4} at {node.Address:X4} does not take a branch operand");
                if (node.Operand is null)
                    throw new InvalidDataException(
                        $"VM inline-word node at {node.Address:X4} is missing its operand");
                if (node.Operand.Address != node.Address + 2)
                    throw new InvalidDataException(
                        $"VM operand at {node.Operand.Address:X4} does not follow node {node.Address:X4}");
                if (node.Operand.Bytes is null || node.Operand.Bytes.Length != 2)
                    throw new InvalidDataException(
                        $"VM operand at {node.Operand.Address:X4} has the wrong width");
                ushort encodedValue =
                    (ushort)((node.Operand.Bytes[0] << 8) | node.Operand.Bytes[1]);
                if (encodedValue != node.Operand.Value)
                    throw new InvalidDataException(
                        $"VM operand value at {node.Operand.Address:X4} does not match its bytes");
                if (node.Bytes[2] != node.Operand.Bytes[0] ||
                    node.Bytes[3] != node.Operand.Bytes[1])
                    throw new InvalidDataException(
                        $"VM node bytes at {node.Address:X4} do not match its inline operand");
            }
            else if (operandBytes == 1)
            {
                if (node.Operand is not null)
                    throw new InvalidDataException(
                        $"VM branch node at {node.Address:X4} must not carry an inline-word operand");
                if (node.Branch is null)
                    throw new InvalidDataException(
                        $"VM branch node at {node.Address:X4} is missing its checked branch model");
                ValidateBranch(node, definition);
            }
            else if (node.Operand is not null || node.Branch is not null)
            {
                throw new InvalidDataException(
                    $"VM token {node.Token:X4} at {node.Address:X4} does not take an operand");
            }

            if (node.Token == VmIlVocabulary.ReturnToCallerStream)
            {
                if (index != definition.Nodes.Count - 1)
                    throw new InvalidDataException(
                        $"Multiple VM return tokens: return at {node.Address:X4} is not the final node");
                if (cursor + nodeLength != definition.BodyEndExclusive)
                    throw new InvalidDataException(
                        $"VM return boundary at {node.Address:X4} does not end at " +
                        $"{definition.BodyEndExclusive:X4}");
                sawReturn = true;
            }

            ReadOnlySpan<byte> originalNode =
                originalImage.Slice(node.Address, node.Bytes.Length);
            if (!originalNode.SequenceEqual(node.Bytes))
                throw new InvalidDataException(
                    $"VM node at {node.Address:X4} does not match the original span bytes; " +
                    "identity compile only accepts unchanged decoded bytes");

            byte[] emittedNode = node.Bytes;
            if (editedNodeIndex == index)
            {
                if (editedNodeBytes is null || editedNodeBytes.Length != nodeLength)
                    throw new InvalidDataException(
                        $"Edited VM node at {node.Address:X4} has the wrong width");
                if (editedNodeBytes[0] != node.Bytes[0] ||
                    editedNodeBytes[1] != node.Bytes[1])
                    throw new InvalidDataException(
                        $"Edited VM node at {node.Address:X4} changes the execution token");
                if (operandBytes != 2 &&
                    !editedNodeBytes.AsSpan().SequenceEqual(node.Bytes))
                    throw new InvalidDataException(
                        $"Edited VM token {node.Token:X4} at {node.Address:X4} does not take an operand");
                emittedNode = editedNodeBytes;
            }

            emitted.AddRange(emittedNode);
            cursor += nodeLength;
        }

        if (!sawReturn)
            throw new InvalidDataException("VM definition is missing its return token");
        if (cursor != definition.BodyEndExclusive)
            throw new InvalidDataException(
                $"VM definition span ends at {cursor:X4}; expected {definition.BodyEndExclusive:X4}");
        if (emitted.Count != definition.BodyLength)
            throw new InvalidDataException(
                $"Compiled VM body length {emitted.Count} differs from span length {definition.BodyLength}");

        ValidateBranchTargets(definition);
        return emitted;
    }

    private static void ValidateBranch(VmIlNode node, VmIlDefinition definition)
    {
        VmIlBranch branch = node.Branch!;
        if (!VmIlVocabulary.IsBranchWithByteOperand(node.Token))
            throw new InvalidDataException(
                $"VM token {node.Token:X4} at {node.Address:X4} does not take a branch operand");
        if (branch.OperandWidthBytes != 1)
            throw new InvalidDataException(
                $"VM branch at {node.Address:X4} has the wrong operand width");
        if (branch.OperandAddress != node.Address + 2)
            throw new InvalidDataException(
                $"VM branch operand at {branch.OperandAddress:X4} does not follow node {node.Address:X4}");
        if (node.Bytes.Length != 3 || node.Bytes[2] != branch.OperandByte)
            throw new InvalidDataException(
                $"VM branch operand at {branch.OperandAddress:X4} does not match its original byte");
        ushort expectedTarget = (ushort)(branch.OperandAddress + branch.OperandByte);
        if (branch.TargetAddress != expectedTarget)
            throw new InvalidDataException(
                $"VM branch target {branch.TargetAddress:X4} does not match its operand byte");
        if (branch.TargetAddress <= branch.OperandAddress)
            throw new InvalidDataException(
                $"VM branch target {branch.TargetAddress:X4} is inside or before its operand");
        if (branch.TargetAddress < definition.BodyStart ||
            branch.TargetAddress >= definition.BodyEndExclusive)
            throw new InvalidDataException(
                $"VM branch target {branch.TargetAddress:X4} is outside the definition span");
        if (!string.Equals(branch.OffsetBase, NineASixFourDecoder.OffsetBase,
                StringComparison.Ordinal) || !branch.OffsetUnsigned)
            throw new InvalidDataException(
                $"VM branch at {node.Address:X4} has unsupported offset semantics");
        VmIlBranchCondition expectedCondition =
            node.Token == VmIlVocabulary.BranchForward8IfZero
                ? VmIlBranchCondition.IfZero
                : VmIlBranchCondition.Always;
        if (branch.Condition != expectedCondition)
            throw new InvalidDataException(
                $"VM branch condition at {node.Address:X4} does not match its token");
        if (branch.HandlerAddress != node.Token + 2)
            throw new InvalidDataException(
                $"VM branch handler at {branch.HandlerAddress:X4} does not follow node {node.Address:X4}");
        if (string.IsNullOrWhiteSpace(branch.EvidenceClass))
            throw new InvalidDataException(
                $"VM branch at {node.Address:X4} has no evidence classification");
    }

    private static void ValidateBranchTargets(VmIlDefinition definition)
    {
        var boundaries = new HashSet<ushort>(
            definition.Nodes.Where(node => node is not null).Select(node => node.Address));
        foreach (VmIlNode node in definition.Nodes)
        {
            if (node?.Branch is null)
                continue;
            if (!boundaries.Contains(node.Branch.TargetAddress))
                throw new InvalidDataException(
                    $"VM branch target {node.Branch.TargetAddress:X4} is not an instruction " +
                    "boundary in this definition");
        }
    }

    private static bool IsNineASixFourDefinition(VmIlDefinition definition) =>
        (definition.Provenance is not null &&
         string.Equals(definition.Provenance.ListingPath,
             NineASixFourDecoder.ListingPath, StringComparison.Ordinal)) ||
        (definition.BodyStart == NineASixFourDecoder.BodyStart &&
         definition.BodyEndExclusive == NineASixFourDecoder.BodyEndExclusive);

    private static void ValidateOriginalIdentity(ReadOnlySpan<byte> originalImage)
    {
        NineEdNineDecoder.ValidateIdentity(
            originalImage,
            NineEdNineDecoder.RequiredRomLength,
            NineEdNineDecoder.RequiredRomSha1,
            NineEdNineDecoder.RequiredRomSha256);
    }

    private static void ValidateDefinitionIdentity(
        VmIlDefinition definition, int length, string sha1, string sha256)
    {
        if (definition.RomLength != length ||
            !string.Equals(definition.RomSha1, sha1, StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(definition.RomSha256, sha256, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                "VM definition original identity does not match the exact original ROM");
    }

    private static int[] ChangedOffsets(
        ReadOnlySpan<byte> originalImage, ReadOnlySpan<byte> image)
    {
        if (image.Length != originalImage.Length)
            throw new InvalidDataException("Compiled image length differs from the original");
        var changed = new List<int>();
        for (int offset = 0; offset < image.Length; offset++)
        {
            if (image[offset] != originalImage[offset])
                changed.Add(offset);
        }
        return changed.ToArray();
    }

    private static string Sha1(ReadOnlySpan<byte> bytes) =>
        Convert.ToHexString(SHA1.HashData(bytes));

    private static string Sha256(ReadOnlySpan<byte> bytes) =>
        Convert.ToHexString(SHA256.HashData(bytes));
}

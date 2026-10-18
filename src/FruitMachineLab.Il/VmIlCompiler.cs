using System.Security.Cryptography;

namespace FruitMachineLab.Il;

public static class VmIlCompiler
{
    public static VmIlCompileResult CompileIdentity(
        VmIlDefinition definition, ReadOnlySpan<byte> originalImage)
    {
        ArgumentNullException.ThrowIfNull(definition);

        NineEdNineDecoder.ValidateIdentity(
            originalImage, definition.RomLength, definition.RomSha1, definition.RomSha256);

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
                    node.Token, out string operation, out int operandBytes))
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
            else if (node.Operand is not null)
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

            emitted.AddRange(node.Bytes);
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

        byte[] emittedBody = emitted.ToArray();
        byte[] image = originalImage.ToArray();
        emittedBody.CopyTo(image, definition.BodyStart);

        var changed = new List<int>();
        for (int offset = 0; offset < image.Length; offset++)
        {
            if (image[offset] != originalImage[offset])
                changed.Add(offset);
        }

        string inputSha256 = Convert.ToHexString(SHA256.HashData(originalImage));
        string outputSha256 = Convert.ToHexString(SHA256.HashData(image));
        return new VmIlCompileResult(
            image, emittedBody, inputSha256, outputSha256, changed.ToArray());
    }
}

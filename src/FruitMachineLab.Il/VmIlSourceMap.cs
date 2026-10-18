namespace FruitMachineLab.Il;

public sealed record VmIlSourceMapEntry(
    ushort Address,
    int NodeIndex,
    ushort Token,
    string Operation);

public sealed class VmIlSourceMap
{
    private readonly VmIlSourceMapEntry[] _byAddress;

    private VmIlSourceMap(
        string romSha256,
        ushort bodyStart,
        int bodyEndExclusive,
        VmIlSourceMapEntry[] byAddress)
    {
        RomSha256 = romSha256;
        BodyStart = bodyStart;
        BodyEndExclusive = bodyEndExclusive;
        _byAddress = byAddress;
    }

    public string RomSha256 { get; }

    public ushort BodyStart { get; }

    public int BodyEndExclusive { get; }

    public IReadOnlyList<VmIlSourceMapEntry> Entries => _byAddress;

    public static VmIlSourceMap Create(VmIlDefinition definition)
    {
        ArgumentNullException.ThrowIfNull(definition);

        if (definition.Nodes is null || definition.Nodes.Count == 0)
            throw new InvalidDataException("VM source map requires at least one node");
        if (string.IsNullOrWhiteSpace(definition.RomSha256) ||
            definition.RomSha256.Length != 64)
            throw new InvalidDataException("VM source map requires the exact ROM SHA256");
        if (definition.BodyEndExclusive <= definition.BodyStart)
            throw new InvalidDataException("VM source map has an invalid definition span");
        if (definition.BodyEndExclusive > 0x10000)
            throw new InvalidDataException(
                $"VM source map span exceeds the 16-bit address space");

        int spanLength = definition.BodyEndExclusive - definition.BodyStart;
        var owner = new int[spanLength];
        Array.Fill(owner, -1);
        var entries = new VmIlSourceMapEntry[spanLength];
        int expectedAddress = definition.BodyStart;

        for (int index = 0; index < definition.Nodes.Count; index++)
        {
            VmIlNode? node = definition.Nodes[index];
            if (node is null)
                throw new InvalidDataException($"VM source-map node {index} is missing");
            if (node.Bytes is null || node.Bytes.Length == 0)
                throw new InvalidDataException(
                    $"VM source-map node {index} has no original bytes");
            if (node.Index != index)
                throw new InvalidDataException(
                    $"VM source-map node index {node.Index} does not match position {index}");

            int nodeEnd = node.Address + node.Bytes.Length;
            if (node.Address < definition.BodyStart || nodeEnd > definition.BodyEndExclusive)
                throw new InvalidDataException(
                    $"VM source-map node {index} at {node.Address:X4} is outside the definition span");
            if (node.Address < expectedAddress)
                throw new InvalidDataException(
                    $"Ambiguous VM source map: node {index} at {node.Address:X4} overlaps node {index - 1}");
            if (node.Address > expectedAddress)
                throw new InvalidDataException(
                    $"VM source map has a gap at {expectedAddress:X4} before node {index}");
            if (nodeEnd > 0x10000)
                throw new InvalidDataException(
                    $"VM source-map node {index} exceeds the 16-bit address space");

            for (int byteIndex = 0; byteIndex < node.Bytes.Length; byteIndex++)
            {
                int address = node.Address + byteIndex;
                int slot = address - definition.BodyStart;
                if (owner[slot] != -1)
                    throw new InvalidDataException(
                        $"Ambiguous VM source map: address {address:X4} maps to nodes " +
                        $"{owner[slot]} and {index}");
                owner[slot] = index;
                entries[slot] = new VmIlSourceMapEntry(
                    (ushort)address, index, node.Token, node.Operation);
            }

            expectedAddress = nodeEnd;
        }

        for (int slot = 0; slot < owner.Length; slot++)
        {
            if (owner[slot] < 0)
                throw new InvalidDataException(
                    $"VM source map does not cover address {definition.BodyStart + slot:X4}");
        }
        if (expectedAddress != definition.BodyEndExclusive)
            throw new InvalidDataException(
                $"VM source map ends at {expectedAddress:X4}; expected {definition.BodyEndExclusive:X4}");

        return new VmIlSourceMap(
            definition.RomSha256, definition.BodyStart, definition.BodyEndExclusive, entries);
    }

    public VmIlSourceMapEntry Resolve(ushort address)
    {
        if (address < BodyStart || address >= BodyEndExclusive)
            throw new KeyNotFoundException(
                $"Source-map address {address:X4} is outside " +
                $"{BodyStart:X4}..{BodyEndExclusive - 1:X4}");
        int slot = address - BodyStart;
        VmIlSourceMapEntry entry = _byAddress[slot];
        if (entry is null)
            throw new InvalidDataException($"VM source map has a gap at {address:X4}");
        return entry;
    }

    public int ResolveNodeIndex(ushort address) => Resolve(address).NodeIndex;
}

using System.Globalization;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace FruitMachineLab.Runtime;

public sealed record Mpu4VmInstruction(ushort Token, string Operation, ushort? Branch = null, ushort? InlineValue = null);

public sealed record Mpu4VmProvenance(
    string Listing,
    string ListingSha256,
    string Checkpoint,
    string CheckpointSpanClassification,
    int ObservedSites);

public sealed record Mpu4VmImage(
    byte[] Image,
    byte[] Encoded,
    string InputSha256,
    string OutputSha256,
    int[] ChangedOffsets);

public sealed record Mpu4VmDefinition
{
    private enum OperandKind { None, Forward8, InlineWord }

    private sealed record Encoding(ushort Token, OperandKind Operand);

    private static readonly IReadOnlyDictionary<string, Encoding> Encodings =
        new Dictionary<string, Encoding>(StringComparer.Ordinal)
        {
            ["vm_rotate_three_cells"] = new(0x7B6D, OperandKind.None),
            ["vm_branch_forward8_if_zero"] = new(0x7982, OperandKind.Forward8),
            ["vm_or_word_memory"] = new(0x7665, OperandKind.None),
            ["vm_branch_unsigned_forward8"] = new(0x7979, OperandKind.Forward8),
            ["vm_clear_word_memory_bits"] = new(0x7671, OperandKind.None),
            ["vm_return_to_caller_stream"] = new(0x792F, OperandKind.None),
            ["vm_push_inline_word_literal"] = new(0x795B, OperandKind.InlineWord),
            ["vm_add_words"] = new(0x787E, OperandKind.None),
            ["vm_bitwise_xor"] = new(0x7AAF, OperandKind.None)
        };

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow
    };

    public required ushort Address { get; init; }
    public required string Purpose { get; init; }
    public required int InputLength { get; init; }
    public required string RomSha1 { get; init; }
    public required byte[] OriginalBytes { get; init; }
    public required string EvidenceClass { get; init; }
    public required Mpu4VmProvenance Provenance { get; init; }
    public required IReadOnlyList<Mpu4VmInstruction> Instructions { get; init; }

    public static Mpu4VmDefinition Load(string path) => Parse(File.ReadAllText(path));

    public static Mpu4VmDefinition Parse(string json)
    {
        FileModel file = JsonSerializer.Deserialize<FileModel>(json, JsonOptions)
            ?? throw new InvalidDataException("Missing VM definition");
        if (file.SchemaVersion != 1 || string.IsNullOrWhiteSpace(file.Purpose) ||
            string.IsNullOrWhiteSpace(file.EvidenceClass) || file.InputLength <= 0 ||
            file.Instructions is not { Length: > 0 })
            throw new InvalidDataException("Invalid VM definition schema, purpose, length or instructions");
        if (file.Provenance is null || file.Provenance.ObservedSites <= 0 ||
            string.IsNullOrWhiteSpace(file.Provenance.Listing) ||
            string.IsNullOrWhiteSpace(file.Provenance.ListingSha256) ||
            string.IsNullOrWhiteSpace(file.Provenance.Checkpoint) ||
            string.IsNullOrWhiteSpace(file.Provenance.CheckpointSpanClassification))
            throw new InvalidDataException("VM definition provenance is incomplete");
        byte[] original = HexBytes(file.OriginalSpanHex, "OriginalSpanHex");
        if (original.Length == 0 ||
            !string.Equals(Sha256(original), file.OriginalSpanSha256, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException("Original VM span hash does not identify the stated bytes");
        var definition = new Mpu4VmDefinition
        {
            Address = Hex16(file.Address, "Address"),
            Purpose = file.Purpose,
            InputLength = file.InputLength,
            RomSha1 = NormalizeSha1(file.RomSha1),
            OriginalBytes = original,
            EvidenceClass = file.EvidenceClass,
            Provenance = new Mpu4VmProvenance(
                file.Provenance.Listing,
                file.Provenance.ListingSha256,
                file.Provenance.Checkpoint,
                file.Provenance.CheckpointSpanClassification,
                file.Provenance.ObservedSites),
            Instructions = file.Instructions.Select(ParseInstruction).ToArray()
        };
        definition.BuildPlan();
        if (!definition.Encode().SequenceEqual(original))
            throw new InvalidDataException("VM definition encoding does not reproduce its original span");
        return definition;
    }

    public byte[] Encode()
    {
        Plan plan = BuildPlan();
        var bytes = new List<byte>(OriginalBytes.Length);
        foreach (var item in plan.Items)
        {
            bytes.Add((byte)(item.Instruction.Token >> 8));
            bytes.Add((byte)item.Instruction.Token);
            switch (item.Encoding.Operand)
            {
                case OperandKind.None:
                    break;
                case OperandKind.Forward8:
                {
                    int offset = item.Instruction.Branch!.Value - (item.Site + 2);
                    bytes.Add((byte)offset);
                    break;
                }
                case OperandKind.InlineWord:
                {
                    ushort value = item.Instruction.InlineValue!.Value;
                    bytes.Add((byte)(value >> 8));
                    bytes.Add((byte)value);
                    break;
                }
                default:
                    throw new InvalidDataException("Unsupported VM operand encoding");
            }
        }
        return bytes.ToArray();
    }

    public IReadOnlyList<Instruction> ToInstructions()
    {
        Plan plan = BuildPlan();
        return plan.Items.Select(item => new Instruction(
            item.Site,
            item.Instruction.Token,
            item.Instruction.Operation,
            item.Instruction.InlineValue,
            item.Instruction.Branch)).ToArray();
    }

    public RecoveredScript ToScript() => new(ToInstructions());

    public Mpu4VmDefinition WithBranch(int instructionIndex, ushort target)
    {
        if (instructionIndex < 0 || instructionIndex >= Instructions.Count)
            throw new InvalidDataException("VM definition instruction index is out of range");
        var copy = Instructions.ToArray();
        copy[instructionIndex] = copy[instructionIndex] with { Branch = target };
        return this with { Instructions = copy };
    }

    public Mpu4VmDefinition WithLiteral(int instructionIndex, ushort value)
    {
        if (instructionIndex < 0 || instructionIndex >= Instructions.Count)
            throw new InvalidDataException("VM definition instruction index is out of range");
        var copy = Instructions.ToArray();
        copy[instructionIndex] = copy[instructionIndex] with { InlineValue = value };
        return this with { Instructions = copy };
    }

    public Mpu4VmImage Apply(ReadOnlySpan<byte> original)
    {
        if (original.Length != InputLength)
            throw new InvalidDataException("VM definition input length mismatch");
        if (!string.Equals(Convert.ToHexString(SHA1.HashData(original)), RomSha1, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException("VM definition original ROM identity mismatch");
        if (Address > original.Length - OriginalBytes.Length ||
            !original.Slice(Address, OriginalBytes.Length).SequenceEqual(OriginalBytes))
            throw new InvalidDataException("VM definition original bytes do not match the stated ROM span");

        byte[] encoded = Encode();
        if (encoded.Length != OriginalBytes.Length)
            throw new InvalidDataException("VM definition replacement would change span length");
        byte[] image = original.ToArray();
        encoded.CopyTo(image, Address);
        var changed = new List<int>();
        for (int offset = 0; offset < encoded.Length; offset++)
            if (image[Address + offset] != original[Address + offset])
                changed.Add(Address + offset);
        return new Mpu4VmImage(
            image,
            encoded,
            Convert.ToHexString(SHA256.HashData(original)),
            Convert.ToHexString(SHA256.HashData(image)),
            changed.ToArray());
    }

    private sealed record PlanItem(Mpu4VmInstruction Instruction, ushort Site, Encoding Encoding);

    private sealed record Plan(IReadOnlyList<PlanItem> Items);

    private Plan BuildPlan()
    {
        var items = new List<PlanItem>();
        int site = Address;
        foreach (var instruction in Instructions)
        {
            if (instruction is null)
                throw new InvalidDataException("VM definition contains a missing instruction");
            if (!Encodings.TryGetValue(instruction.Operation, out var encoding))
                throw new InvalidDataException($"Unsupported VM operation {instruction.Operation}");
            if (instruction.Token != encoding.Token)
                throw new InvalidDataException(
                    $"Token {instruction.Token:X4} does not encode {instruction.Operation}");
            ValidateOperand(instruction, encoding.Operand);
            int length = EncodedLength(encoding.Operand);
            if (site + length > 0x10000)
                throw new InvalidDataException("VM definition exceeds the 16-bit address space");
            items.Add(new PlanItem(instruction, (ushort)site, encoding));
            site += length;
        }
        if (site - Address != OriginalBytes.Length)
            throw new InvalidDataException("VM definition size differs from its original span");
        var sites = items.Select(item => item.Site).ToHashSet();
        foreach (var item in items)
        {
            if (item.Encoding.Operand != OperandKind.Forward8)
                continue;
            ushort target = item.Instruction.Branch!.Value;
            if (!sites.Contains(target))
                throw new InvalidDataException(
                    $"Branch target {target:X4} is not an instruction boundary in this in-place definition");
            int offset = target - (item.Site + 2);
            if (offset < 0 || offset > 0xFF)
                throw new InvalidDataException("Forward branch target is outside the eight-bit encoding");
        }
        return new Plan(items);
    }

    private static void ValidateOperand(Mpu4VmInstruction instruction, OperandKind operand)
    {
        switch (operand)
        {
            case OperandKind.None:
                if (instruction.Branch is not null)
                    throw new InvalidDataException($"Operation {instruction.Operation} does not take an operand");
                if (instruction.InlineValue is not null)
                    throw new InvalidDataException(
                        $"Operation {instruction.Operation} does not take an inline literal");
                break;
            case OperandKind.Forward8:
                if (instruction.Branch is null)
                    throw new InvalidDataException($"Operation {instruction.Operation} requires a branch target");
                if (instruction.InlineValue is not null)
                    throw new InvalidDataException(
                        $"Operation {instruction.Operation} does not take an inline literal");
                break;
            case OperandKind.InlineWord:
                if (instruction.Branch is not null)
                    throw new InvalidDataException(
                        $"Operation {instruction.Operation} does not take a branch target");
                if (instruction.InlineValue is null)
                    throw new InvalidDataException(
                        $"Operation {instruction.Operation} requires an inline literal");
                break;
            default:
                throw new InvalidDataException("Unsupported VM operand encoding");
        }
    }

    private static int EncodedLength(OperandKind operand) => operand switch
    {
        OperandKind.None => 2,
        OperandKind.Forward8 => 3,
        OperandKind.InlineWord => 4,
        _ => throw new InvalidDataException("Unsupported VM operand encoding")
    };

    private static Mpu4VmInstruction ParseInstruction(InstructionModel model)
    {
        if (model is null || string.IsNullOrWhiteSpace(model.Operation))
            throw new InvalidDataException("VM definition instruction is incomplete");
        ushort? branch = model.Branch is null ? null : Hex16(model.Branch, "Branch");
        ushort? inlineValue = model.InlineValue is null ? null : Hex16(model.InlineValue, "InlineValue");
        return new(Hex16(model.Token, "Token"), model.Operation, branch, inlineValue);
    }

    private static ushort Hex16(string? value, string name)
    {
        if (value is null || value.Length != 4)
            throw new InvalidDataException($"{name} must be four hexadecimal digits");
        try { return ushort.Parse(value, NumberStyles.HexNumber, CultureInfo.InvariantCulture); }
        catch (FormatException ex) { throw new InvalidDataException($"{name} is not hexadecimal", ex); }
    }

    private static byte[] HexBytes(string? value, string name)
    {
        if (value is null)
            throw new InvalidDataException($"Missing {name}");
        try { return Convert.FromHexString(value); }
        catch (FormatException ex) { throw new InvalidDataException($"{name} is not hexadecimal", ex); }
    }

    private static string NormalizeSha1(string? value)
    {
        if (value is null || value.Length != 40)
            throw new InvalidDataException("ROM SHA1 must be forty hexadecimal digits");
        try
        {
            byte[] bytes = Convert.FromHexString(value);
            return Convert.ToHexString(bytes);
        }
        catch (FormatException ex)
        {
            throw new InvalidDataException("ROM SHA1 is not hexadecimal", ex);
        }
    }

    private static string Sha256(byte[] bytes) => Convert.ToHexString(SHA256.HashData(bytes));

    private sealed record FileModel
    {
        public required int SchemaVersion { get; init; }
        public required string Address { get; init; }
        public required string Purpose { get; init; }
        public required int InputLength { get; init; }
        public required string RomSha1 { get; init; }
        public required string OriginalSpanHex { get; init; }
        public required string OriginalSpanSha256 { get; init; }
        public required string EvidenceClass { get; init; }
        public required ProvenanceModel Provenance { get; init; }
        public required InstructionModel[] Instructions { get; init; }
    }

    private sealed record ProvenanceModel
    {
        public required string Listing { get; init; }
        public required string ListingSha256 { get; init; }
        public required string Checkpoint { get; init; }
        public required string CheckpointSpanClassification { get; init; }
        public required int ObservedSites { get; init; }
    }

    private sealed record InstructionModel
    {
        public required string Token { get; init; }
        public required string Operation { get; init; }
        public string? Branch { get; init; }
        public string? InlineValue { get; init; }
    }
}

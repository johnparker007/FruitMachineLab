using System.Security.Cryptography;
using System.Text.Json;
using FruitMachineLab.Runtime;

internal static class VmDefinitionVerification
{
    private static string DefinitionPath(string evidence) =>
        Path.Combine(evidence, "definitions", "conditionally-set-or-clear-memory-mask-9a64.vm.json");

    private static Mpu4VmDefinition Load(string evidence) =>
        Mpu4VmDefinition.Load(DefinitionPath(evidence));

    private static void Assert(bool condition, string message)
    {
        if (!condition) throw new Exception(message);
    }

    private static void Reject(Action action, string expected)
    {
        try { action(); }
        catch (Exception ex) when (ex is InvalidDataException or JsonException)
        {
            Assert(ex.Message.Contains(expected, StringComparison.OrdinalIgnoreCase),
                $"Expected rejection containing '{expected}', got '{ex.Message}'");
            return;
        }
        throw new Exception($"Unsafe VM definition was accepted; expected rejection containing '{expected}'");
    }

    public static void RoundTrip(string evidence)
    {
        var definition = Load(evidence);
        Assert(definition.Address == 0x9A64, "Unexpected definition address");
        Assert(definition.Instructions.Count == 6, "Unexpected definition instruction count");
        Assert(Convert.ToHexString(definition.Encode()) == "7B6D79820676657979037671792F",
            "Encoded definition differs from curated original span");
        Assert(definition.OriginalBytes.SequenceEqual(definition.Encode()),
            "Definition does not round-trip its original bytes");

        var decoded = definition.ToInstructions();
        var expected = new (ushort Site, ushort Token, string Operation, ushort? Branch)[]
        {
            (0x9A64, 0x7B6D, "vm_rotate_three_cells", null),
            (0x9A66, 0x7982, "vm_branch_forward8_if_zero", 0x9A6E),
            (0x9A69, 0x7665, "vm_or_word_memory", null),
            (0x9A6B, 0x7979, "vm_branch_unsigned_forward8", 0x9A70),
            (0x9A6E, 0x7671, "vm_clear_word_memory_bits", null),
            (0x9A70, 0x792F, "vm_return_to_caller_stream", null)
        };
        Assert(decoded.Count == expected.Length, "Decoded operation count differs");
        for (int index = 0; index < expected.Length; index++)
        {
            Assert(decoded[index].Site == expected[index].Site, $"Unexpected decoded site at {index}");
            Assert(decoded[index].Token == expected[index].Token, $"Unexpected decoded token at {index}");
            Assert(decoded[index].Operation == expected[index].Operation, $"Unexpected decoded operation at {index}");
            Assert(decoded[index].Branch == expected[index].Branch, $"Unexpected decoded branch at {index}");
        }

        using var checkpoint = JsonDocument.Parse(File.ReadAllText(
            Path.Combine(evidence, "maps", "nudge-encoding-checkpoint.json")));
        var region = checkpoint.RootElement.GetProperty("vm").EnumerateArray()
            .Single(row => row.GetProperty("listing").GetString() == "VM-SCRIPTS/9A64.txt");
        Assert(region.GetProperty("start").GetString() == "9A64", "Checkpoint start differs");
        Assert(region.GetProperty("end_exclusive").GetString() == "9A72", "Checkpoint end differs");
        Assert(region.GetProperty("span_hex").GetString() == Convert.ToHexString(definition.OriginalBytes),
            "Checkpoint span differs from definition bytes");
        Assert(Sha256File(Path.Combine(evidence, "VM-SCRIPTS", "9A64.txt")) == definition.Provenance.ListingSha256,
            "Listing hash differs from definition provenance");

        string? romPath = Environment.GetEnvironmentVariable("FRUITMACHINELAB_ORIGINAL_ROM");
        if (!string.IsNullOrWhiteSpace(romPath))
        {
            byte[] original = File.ReadAllBytes(romPath);
            Assert(original.Length == definition.InputLength, "Local original ROM length differs");
            Assert(Convert.ToHexString(SHA1.HashData(original)) == definition.RomSha1,
                "Local original ROM SHA1 differs");
            Assert(original.AsSpan(definition.Address, definition.OriginalBytes.Length)
                    .SequenceEqual(definition.OriginalBytes),
                "Local original ROM span differs from definition");
        }
    }

    public static void Boundaries(string evidence)
    {
        var definition = Load(evidence);
        var sites = definition.ToInstructions().Select(instruction => instruction.Site).ToArray();
        Assert(sites.SequenceEqual(new ushort[] {0x9A64, 0x9A66, 0x9A69, 0x9A6B, 0x9A6E, 0x9A70}),
            "Definition sites are not sequential listed boundaries");
        Assert(definition.Encode().Length == 14, "Definition span length differs");
        Assert(definition.ToInstructions()[5].Site + 2 == 0x9A72, "Definition end boundary differs");

        Reject(() => definition.WithBranch(1, 0x9A6C).Encode(), "boundary");
        Reject(() => definition.WithBranch(1, 0x9A68).Encode(), "boundary");
        Reject(() => definition.WithBranch(1, 0x9A63).Encode(), "boundary");
        Reject(() => (definition with
        {
            Instructions = [definition.Instructions[0] with {Token = 0x7982}]
        }).Encode(), "does not encode");
        Reject(() => (definition with
        {
            Instructions = [new Mpu4VmInstruction(0x7B6D, "vm_unsupported")]
        }).Encode(), "unsupported");
        Reject(() => (definition with
        {
            Instructions = [new Mpu4VmInstruction(0x7982, "vm_branch_forward8_if_zero")]
        }).Encode(), "branch target");
        Reject(() => (definition with
        {
            Instructions = [new Mpu4VmInstruction(0x7B6D, "vm_rotate_three_cells", 0x9A64)]
        }).Encode(), "does not take");
        Reject(() => (definition with {Instructions = []}).Encode(), "size");
        Reject(() => (definition with {OriginalBytes = new byte[13]}).Encode(), "size");
        Reject(() => (definition with {Address = 0xFFFF}).Encode(), "address space");

        string json = File.ReadAllText(DefinitionPath(evidence));
        Reject(() => Mpu4VmDefinition.Parse(json.Replace("\"SchemaVersion\": 1", "\"SchemaVersion\": 2")),
            "schema");
        Reject(() => Mpu4VmDefinition.Parse(json.Replace("\"Purpose\"", "\"UnknownPurpose\"")),
            "purpose");
        Reject(() => Mpu4VmDefinition.Parse(json.Replace("\"vm_rotate_three_cells\"", "\"vm_unknown\"")),
            "unsupported");
        Reject(() => Mpu4VmDefinition.Parse(json.Replace("\"OriginalSpanSha256\": \"8F6E", "\"OriginalSpanSha256\": \"0F6E")),
            "span hash");
    }

    public static void Execution(string evidence)
    {
        var definition = Load(evidence);
        var zero = Execute(definition, 0, 0x1234, 0x00F0, 0);
        Assert(zero.ReadWord(0x1234) == 0, "Zero branch did not clear the selected mask bits");
        Assert(zero.Data.Count == 0, "Zero branch did not consume its stack cells");
        Assert(zero.LocalFrame == 0x700, "Zero branch changed the local frame");
        Assert(zero.Control!.Pointer == 0x800 && zero.Control.ResumeCursor == 0x9999,
            "Zero branch did not return through the control frame");

        var nonzero = Execute(definition, 1, 0x1234, 0x00F0, 0);
        Assert(nonzero.ReadWord(0x1234) == 0x00F0, "Nonzero branch did not set the selected mask bits");
        Assert(nonzero.Data.Count == 0, "Nonzero branch did not consume its stack cells");
        Assert(nonzero.LocalFrame == 0x700, "Nonzero branch changed the local frame");
        Assert(nonzero.Control!.Pointer == 0x800 && nonzero.Control.ResumeCursor == 0x9999,
            "Nonzero branch did not return through the control frame");
    }

    public static void ChangedOperand(string evidence)
    {
        var original = Load(evidence);
        var changed = original.WithBranch(1, 0x9A69);
        byte[] before = original.Encode(), after = changed.Encode();
        Assert(before.Length == after.Length, "Changed branch operand altered definition size");
        var offsets = Enumerable.Range(0, before.Length).Where(offset => before[offset] != after[offset]).ToArray();
        Assert(offsets.SequenceEqual(new[] {4}), "Changed branch operand did not emit exactly one operand byte");
        Assert(before[4] == 0x06 && after[4] == 0x01, "Branch operand byte did not change from 06 to 01");
        Assert(changed.ToInstructions()[1].Branch == 0x9A69, "Decoded branch did not follow the changed operand");

        var originalZero = Execute(original, 0, 0x1234, 0x00F0, 0xFFFF);
        var changedZero = Execute(changed, 0, 0x1234, 0x00F0, 0xFFFF);
        Assert(originalZero.ReadWord(0x1234) == 0xFF0F, "Original zero branch no longer clears the mask");
        Assert(changedZero.ReadWord(0x1234) == 0xFFFF, "Changed zero branch did not take the OR path");
        Assert(changedZero.Data.Count == 0 && changedZero.Control!.Pointer == 0x800,
            "Changed branch did not complete its stack and control flow");
    }

    public static void ApplyPreservesUnknown(string evidence)
    {
        var definition = Load(evidence);
        byte[] synthetic = new byte[definition.InputLength];
        for (int index = 0; index < synthetic.Length; index++) synthetic[index] = unchecked((byte)(index * 37 + 11));
        definition.OriginalBytes.CopyTo(synthetic, definition.Address);
        string syntheticSha1 = Convert.ToHexString(SHA1.HashData(synthetic));
        var syntheticDefinition = definition with {RomSha1 = syntheticSha1};

        var unchanged = syntheticDefinition.Apply(synthetic);
        Assert(unchanged.Image.SequenceEqual(synthetic), "Reference definition changed the synthetic image");
        Assert(unchanged.ChangedOffsets.Length == 0, "Reference definition reported changes");

        var changed = syntheticDefinition.WithBranch(1, 0x9A69);
        var result = changed.Apply(synthetic);
        Assert(result.ChangedOffsets.SequenceEqual(new[] {0x9A68}), "Changed definition offset differs");
        Assert(result.Image.AsSpan(0, definition.Address).SequenceEqual(synthetic.AsSpan(0, definition.Address)),
            "Bytes before the definition changed");
        int end = definition.Address + definition.OriginalBytes.Length;
        Assert(result.Image.AsSpan(end).SequenceEqual(synthetic.AsSpan(end)),
            "Unknown bytes after the definition changed");
        Assert(result.Image.AsSpan(definition.Address, definition.OriginalBytes.Length)
                .SequenceEqual(changed.Encode()),
            "Definition span was not emitted from the common representation");
        Assert(result.InputSha256 == Convert.ToHexString(SHA256.HashData(synthetic)),
            "Input SHA256 differs");
        Assert(result.OutputSha256 == Convert.ToHexString(SHA256.HashData(result.Image)),
            "Output SHA256 differs");

        Reject(() => syntheticDefinition.Apply(synthetic.AsSpan(1)), "length");
        Reject(() => definition.Apply(synthetic), "identity");
        byte[] tampered = synthetic.ToArray();
        tampered[definition.Address] ^= 0xFF;
        var tamperedDefinition = definition with {RomSha1 = Convert.ToHexString(SHA1.HashData(tampered))};
        Reject(() => tamperedDefinition.Apply(tampered), "original bytes");
    }

    private static Machine Execute(
        Mpu4VmDefinition definition, ushort condition, ushort address, ushort mask, ushort value)
    {
        var machine = new Machine();
        machine.WriteWord(address, value);
        machine.LocalFrame = 0x700;
        machine.Data.Push(condition);
        machine.Data.Push(address);
        machine.Data.Push(mask);
        machine.Control = new VmControlStack(machine, 0x800);
        machine.Control.Push(0x9999);
        new ScriptExecutor(machine).Run(definition.ToScript());
        return machine;
    }

    private static string Sha256File(string path) =>
        Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path)));
}

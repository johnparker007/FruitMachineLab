using System.Globalization;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Nodes;
using FruitMachineLab.Runtime;

internal static class VmDefinitionVerification
{
    private static string DefinitionPath(string evidence) =>
        Path.Combine(evidence, "definitions", "conditionally-set-or-clear-memory-mask-9a64.vm.json");

    private static string LiteralDefinitionPath(string evidence) =>
        Path.Combine(evidence, "definitions", "bias-word-signed-value-9ed9.vm.json");

    private static Mpu4VmDefinition Load(string evidence) =>
        Mpu4VmDefinition.Load(DefinitionPath(evidence));

    private static Mpu4VmDefinition LoadLiteral(string evidence) =>
        Mpu4VmDefinition.Load(LiteralDefinitionPath(evidence));

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
        Assert(FixtureIntegrity.MatchesPinnedHash(Path.Combine(evidence, "VM-SCRIPTS", "9A64.txt"),
                definition.Provenance.ListingSha256),
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

    public static void LiteralRoundTrip(string evidence)
    {
        var definition = LoadLiteral(evidence);
        Assert(definition.Address == 0x9ED9, "Unexpected literal definition address");
        Assert(definition.Instructions.Count == 5, "Unexpected literal definition instruction count");
        Assert(Convert.ToHexString(definition.Encode()) == "795BFF80787E795BFF807AAF792F",
            "Encoded literal definition differs from curated original span");
        Assert(definition.OriginalBytes.SequenceEqual(definition.Encode()),
            "Literal definition does not round-trip its original bytes");

        var decoded = definition.ToInstructions();
        var expected = new (ushort Site, ushort Token, string Operation, ushort? Value, ushort? Branch)[]
        {
            (0x9ED9, 0x795B, "vm_push_inline_word_literal", 0xFF80, null),
            (0x9EDD, 0x787E, "vm_add_words", null, null),
            (0x9EDF, 0x795B, "vm_push_inline_word_literal", 0xFF80, null),
            (0x9EE3, 0x7AAF, "vm_bitwise_xor", null, null),
            (0x9EE5, 0x792F, "vm_return_to_caller_stream", null, null)
        };
        Assert(decoded.Count == expected.Length, "Decoded literal operation count differs");
        for (int index = 0; index < expected.Length; index++)
        {
            Assert(decoded[index].Site == expected[index].Site, $"Unexpected literal site at {index}");
            Assert(decoded[index].Token == expected[index].Token, $"Unexpected literal token at {index}");
            Assert(decoded[index].Operation == expected[index].Operation,
                $"Unexpected literal operation at {index}");
            Assert(decoded[index].Value == expected[index].Value, $"Unexpected literal value at {index}");
            Assert(decoded[index].Branch == expected[index].Branch,
                $"Unexpected literal branch at {index}");
        }

        using var checkpoint = JsonDocument.Parse(File.ReadAllText(
            Path.Combine(evidence, "maps", "nudge-encoding-checkpoint.json")));
        var region = checkpoint.RootElement.GetProperty("vm").EnumerateArray()
            .Single(row => row.GetProperty("listing").GetString() == "VM-SCRIPTS/9ED9.txt");
        Assert(region.GetProperty("start").GetString() == "9ED9", "Checkpoint literal start differs");
        Assert(region.GetProperty("end_exclusive").GetString() == "9EE7",
            "Checkpoint literal end differs");
        Assert(region.GetProperty("span_hex").GetString() == Convert.ToHexString(definition.OriginalBytes),
            "Checkpoint literal span differs from definition bytes");
        Assert(FixtureIntegrity.MatchesPinnedHash(Path.Combine(evidence, "VM-SCRIPTS", "9ED9.txt"),
                definition.Provenance.ListingSha256),
            "Literal listing hash differs from definition provenance");

        string? romPath = Environment.GetEnvironmentVariable("FRUITMACHINELAB_ORIGINAL_ROM");
        if (!string.IsNullOrWhiteSpace(romPath))
        {
            byte[] original = File.ReadAllBytes(romPath);
            Assert(original.Length == definition.InputLength, "Local original ROM length differs");
            Assert(Convert.ToHexString(SHA1.HashData(original)) == definition.RomSha1,
                "Local original ROM SHA1 differs");
            Assert(original.AsSpan(definition.Address, definition.OriginalBytes.Length)
                    .SequenceEqual(definition.OriginalBytes),
                "Local original ROM literal span differs from definition");
        }
    }

    public static void LiteralBoundaries(string evidence)
    {
        var definition = LoadLiteral(evidence);
        var sites = definition.ToInstructions().Select(instruction => instruction.Site).ToArray();
        Assert(sites.SequenceEqual(new ushort[] {0x9ED9, 0x9EDD, 0x9EDF, 0x9EE3, 0x9EE5}),
            "Literal definition sites are not sequential listed boundaries");
        Assert(definition.Encode().Length == 14, "Literal definition span length differs");
        Assert(definition.ToInstructions()[4].Site + 2 == 0x9EE7,
            "Literal definition end boundary differs");

        Reject(() => (definition with
        {
            Instructions = [new Mpu4VmInstruction(0x795B, "vm_push_inline_word_literal")]
        }).Encode(), "requires an inline literal");
        Reject(() => (definition with
        {
            Instructions = [new Mpu4VmInstruction(0x795B, "vm_push_inline_word_literal", 0x9EDD, 0xFF80)]
        }).Encode(), "branch target");
        Reject(() => (definition with
        {
            Instructions = [new Mpu4VmInstruction(0x787E, "vm_add_words", null, 0xFF80)]
        }).Encode(), "inline literal");
        Reject(() => (definition with
        {
            Instructions = [new Mpu4VmInstruction(0x7963, "vm_push_inline_word_literal", null, 0xFF80)]
        }).Encode(), "does not encode");
        Reject(() => (definition with
        {
            Instructions = [new Mpu4VmInstruction(0x795B, "vm_unsupported", null, 0xFF80)]
        }).Encode(), "unsupported");
        Reject(() => (definition with {Instructions = []}).Encode(), "size");
        Reject(() => (definition with {OriginalBytes = new byte[13]}).Encode(), "size");
        Reject(() => (definition with {Address = 0xFFFF}).Encode(), "address space");
        Reject(() => definition.WithLiteral(5, 0xFF80), "out of range");

        string json = File.ReadAllText(LiteralDefinitionPath(evidence));
        Reject(() => Mpu4VmDefinition.Parse(json.Replace("\"SchemaVersion\": 1", "\"SchemaVersion\": 2")),
            "schema");
        Reject(() => Mpu4VmDefinition.Parse(json.Replace("\"InlineValue\": \"FF80\"", "\"InlineValue\": \"F80\"")),
            "four hexadecimal digits");
        Reject(() => Mpu4VmDefinition.Parse(json.Replace("\"InlineValue\": \"FF80\"", "\"InlineValue\": \"ZZ80\"")),
            "not hexadecimal");
        Reject(() => Mpu4VmDefinition.Parse(json.Replace("\"Token\": \"795B\"", "\"Token\": \"7963\"")),
            "does not encode");
        Reject(() => Mpu4VmDefinition.Parse(json.Replace("\"vm_add_words\"", "\"vm_unknown\"")),
            "unsupported");
    }

    public static void LiteralExecution(string evidence)
    {
        var definition = LoadLiteral(evidence);
        var zero = ExecuteLiteral(definition, 0x0000);
        Assert(zero.Data.Count == 1 && zero.Data.Peek() == 0x0000,
            "Literal definition did not preserve zero input");
        Assert(zero.LocalFrame == 0x700, "Literal definition changed the local frame");
        Assert(zero.Control!.Pointer == 0x800 && zero.Control.ResumeCursor == 0x9999,
            "Literal definition did not return through the control frame");

        var wrapped = ExecuteLiteral(definition, 0x0080);
        Assert(wrapped.Data.Count == 1 && wrapped.Data.Peek() == 0xFF80,
            "Literal definition did not wrap 0080 plus FF80");
        Assert(wrapped.LocalFrame == 0x700 && wrapped.Control!.Pointer == 0x800 &&
               wrapped.Control.ResumeCursor == 0x9999,
            "Wrapped literal path changed stack or control frame");

        var negative = ExecuteLiteral(definition, 0xFFFF);
        Assert(negative.Data.Count == 1 && negative.Data.Peek() == 0x00FF,
            "Literal definition did not wrap signed FFFF");
        Assert(negative.LocalFrame == 0x700 && negative.Control!.Pointer == 0x800,
            "Signed literal path changed stack or control frame");

        var high = ExecuteLiteral(definition, 0x8000);
        Assert(high.Data.Count == 1 && high.Data.Peek() == 0x8000,
            "Literal definition did not wrap high signed input");
        Assert(high.LocalFrame == 0x700 && high.Control!.Pointer == 0x800,
            "High literal path changed stack or control frame");
    }

    public static void LiteralChangedOperand(string evidence)
    {
        var original = LoadLiteral(evidence);
        var changed = original.WithLiteral(0, 0xFF00);
        byte[] before = original.Encode(), after = changed.Encode();
        Assert(before.Length == after.Length, "Changed inline literal altered definition size");
        var offsets = Enumerable.Range(0, before.Length)
            .Where(offset => before[offset] != after[offset]).ToArray();
        Assert(offsets.SequenceEqual(new[] {3}),
            "Changed inline literal did not emit exactly one operand byte");
        Assert(before[3] == 0x80 && after[3] == 0x00,
            "Inline literal operand byte did not change from 80 to 00");
        Assert(changed.ToInstructions()[0].Value == 0xFF00,
            "Decoded instruction did not follow the changed inline literal");
        Assert(changed.ToInstructions()[2].Value == 0xFF80,
            "Unchanged inline literal was not preserved");

        var originalLow = ExecuteLiteral(original, 0x0080);
        var changedLow = ExecuteLiteral(changed, 0x0080);
        Assert(originalLow.Data.Peek() == 0xFF80,
            "Original inline literal path no longer biases 0080");
        Assert(changedLow.Data.Peek() == 0x0000,
            "Changed inline literal path did not change decoded behaviour");
        Assert(changedLow.Data.Count == 1 && changedLow.LocalFrame == 0x700 &&
               changedLow.Control!.Pointer == 0x800 && changedLow.Control.ResumeCursor == 0x9999,
            "Changed inline literal did not complete stack and control flow");

        var originalHigh = ExecuteLiteral(original, 0x0100);
        var changedHigh = ExecuteLiteral(changed, 0x0100);
        Assert(originalHigh.Data.Peek() == 0xFF00, "Original second-input behaviour differs");
        Assert(changedHigh.Data.Peek() == 0xFF80,
            "Changed inline literal did not change second-input behaviour");
    }

    public static void LiteralApplyPreservesUnknown(string evidence)
    {
        var definition = LoadLiteral(evidence);
        byte[] synthetic = new byte[definition.InputLength];
        for (int index = 0; index < synthetic.Length; index++)
            synthetic[index] = unchecked((byte)(index * 41 + 7));
        definition.OriginalBytes.CopyTo(synthetic, definition.Address);
        string syntheticSha1 = Convert.ToHexString(SHA1.HashData(synthetic));
        var syntheticDefinition = definition with {RomSha1 = syntheticSha1};

        var unchanged = syntheticDefinition.Apply(synthetic);
        Assert(unchanged.Image.SequenceEqual(synthetic), "Reference literal definition changed the image");
        Assert(unchanged.ChangedOffsets.Length == 0, "Reference literal definition reported changes");

        var changed = syntheticDefinition.WithLiteral(0, 0xFF00);
        var result = changed.Apply(synthetic);
        Assert(result.ChangedOffsets.SequenceEqual(new[] {0x9EDC}),
            "Changed literal offset differs");
        Assert(result.Image.AsSpan(0, definition.Address).SequenceEqual(
                synthetic.AsSpan(0, definition.Address)), "Bytes before the literal definition changed");
        int end = definition.Address + definition.OriginalBytes.Length;
        Assert(result.Image.AsSpan(end).SequenceEqual(synthetic.AsSpan(end)),
            "Unknown bytes after the literal definition changed");
        Assert(result.Image.AsSpan(definition.Address, definition.OriginalBytes.Length)
                .SequenceEqual(changed.Encode()),
            "Literal definition span was not emitted from the common representation");
        Assert(result.InputSha256 == Convert.ToHexString(SHA256.HashData(synthetic)),
            "Literal input SHA256 differs");
        Assert(result.OutputSha256 == Convert.ToHexString(SHA256.HashData(result.Image)),
            "Literal output SHA256 differs");

        Reject(() => syntheticDefinition.Apply(synthetic.AsSpan(1)), "length");
        Reject(() => definition.Apply(synthetic), "identity");
        byte[] tampered = synthetic.ToArray();
        tampered[definition.Address] ^= 0xFF;
        var tamperedDefinition = definition with {RomSha1 = Convert.ToHexString(SHA1.HashData(tampered))};
        Reject(() => tamperedDefinition.Apply(tampered), "original bytes");
    }

    public static void LiteralInvocation(string evidence)
    {
        var original = LoadLiteral(evidence);
        var changed = original.WithLiteral(0, 0xFF00);
        VerifyInvocation(original, changed, ParseInvocation(File.ReadAllText(
            Path.Combine(evidence, "collection", "vm-definition-9ed9-invocation.json"))));
    }

    public static void LiteralInvocationInvariants(string evidence)
    {
        var definition = LoadLiteral(evidence);
        var changed = definition.WithLiteral(0, 0xFF00);
        var invocation = ParseInvocation(File.ReadAllText(
            Path.Combine(evidence, "collection", "vm-definition-9ed9-invocation.json")));

        string originalSpan = Convert.ToHexString(definition.OriginalBytes);
        string changedSpan = Convert.ToHexString(changed.Encode());
        Require(invocation.Classification.StartsWith(
                "Independent MAME original-threaded-interpreter observation", StringComparison.Ordinal),
            "Invocation classification is not the accepted synthetic MAME observation");
        Require(invocation.Headers.Count == 5, "Invocation header contract is incomplete");
        Require(invocation.Headers["body"] == "00F8", "Invocation body header differs");
        foreach (var pair in new[]
                 {
                     (Name: "litword", Token: (ushort)0x795B),
                     (Name: "add", Token: (ushort)0x787E),
                     (Name: "xor", Token: (ushort)0x7AAF),
                     (Name: "ret", Token: (ushort)0x792F)
                 })
            Require(invocation.Headers[pair.Name] == $"{pair.Token + 2:X4}",
                $"Invocation {pair.Name} header does not follow the checked token");
        Require(invocation.Template.Count == 4 &&
                invocation.Template["f8"] == "3420" && invocation.Template["fa"] == "3184" &&
                invocation.Template["fc"] == "AEA1" && invocation.Template["fe"] == "6E91",
            "Invocation dispatch template differs from the accepted original template");

        string firstDispatch = $"{definition.Address + 2:X4}/{definition.Instructions[0].Token + 2:X4}";
        string firstDispatchContract =
            $"Y={definition.Address + 2:X4} X={definition.Instructions[0].Token + 2:X4}";
        string stopPc = (U16(invocation.Headers["ret"], "headers.ret") + 2).ToString("X4");
        Require(invocation.ExpectedU == "0600", "Invocation expected U differs");
        Require(invocation.ExpectedS == "0700", "Invocation expected S differs");
        Require(invocation.ExpectedReturnFrame == "0782", "Invocation expected return frame differs");
        Require(invocation.ExpectedFirstDispatch == firstDispatchContract,
            "Invocation expected first dispatch differs from the checked definition");
        Require(invocation.EmittedOriginalMatches && invocation.EmittedChangedMatches,
            "Invocation source image identity flags are not both true");
        Require(invocation.OriginalSpan == originalSpan && invocation.ChangedSpan == changedSpan,
            "Invocation image spans differ from the same definition");
        Require(invocation.ChangedOffsets.SequenceEqual(new[] { 0x9EDC }) &&
                invocation.ChangedOffsetsHex.SequenceEqual(new[] { "9EDC" }),
            "Invocation changed offsets are not exactly 9EDC");
        Require(invocation.Checks.Count > 0 && invocation.Checks.Values.All(value => value),
            "Invocation evidence check flags are not all true");
        Require(invocation.Cases.Length == 10 && invocation.CaseCount == 10 &&
                invocation.MatchedCount == 10 && invocation.DifferenceCount == 5,
            "Invocation case summary differs from ten cases and five differences");

        var seen = new HashSet<string>();
        foreach (var row in invocation.Cases)
        {
            Require(seen.Add($"{row.Variant}/{row.Input}"),
                $"Duplicate invocation case {row.Variant}/{row.Input}");
            Require(row.U == U16(invocation.ExpectedU, "contract.expected_u") &&
                    row.S == U16(invocation.ExpectedS, "contract.expected_s") &&
                    row.ReturnFrame == U16(invocation.ExpectedReturnFrame, "contract.expected_return_frame"),
                $"Invocation case {row.Variant}/{row.Input} changed stack or return-frame contract");
            Require(row.FirstDispatch == firstDispatch,
                $"Invocation case {row.Variant}/{row.Input} first dispatch differs");
            Require(row.Pc == stopPc && row.Y == $"{row.ReturnFrame:X4}",
                $"Invocation case {row.Variant}/{row.Input} stop PC or Y differs");
            Require(row.ExitCode == 0 && row.DebugLogSha256.Length == 64,
                $"Invocation case {row.Variant}/{row.Input} exit or log hash differs");
            string expectedSpan = row.Variant switch
            {
                "Original" => originalSpan,
                "Changed" => changedSpan,
                _ => throw new InvalidDataException($"Unknown invocation variant {row.Variant}")
            };
            Require(row.RuntimeSpan == expectedSpan,
                $"Invocation case {row.Variant}/{row.Input} runtime span differs from the definition");
        }
    }

    public static void LiteralInvocationTamperRejected(string evidence)
    {
        string json = File.ReadAllText(
            Path.Combine(evidence, "collection", "vm-definition-9ed9-invocation.json"));
        var resultRoot = JsonNode.Parse(json)!.AsObject();
        var firstCase = resultRoot["cases"]![0]!.AsObject();
        firstCase["result"] = firstCase["result"]!.GetValue<string>() == "0000" ? "FFFF" : "0000";
        Reject(() => LiteralInvocationFromJson(evidence, resultRoot.ToJsonString()),
            "recorded MAME result");

        var frameRoot = JsonNode.Parse(json)!.AsObject();
        frameRoot["cases"]![0]!["return_frame"] = "0000";
        Reject(() => LiteralInvocationFromJson(evidence, frameRoot.ToJsonString()), "return frame");
    }

    private static void LiteralInvocationFromJson(string evidence, string json)
    {
        var original = LoadLiteral(evidence);
        var changed = original.WithLiteral(0, 0xFF00);
        VerifyInvocation(original, changed, ParseInvocation(json));
    }

    private static void VerifyInvocation(
        Mpu4VmDefinition original, Mpu4VmDefinition changed, InvocationEvidence invocation)
    {
        Require(invocation.CaseCount == 10 && invocation.MatchedCount == 10 &&
                invocation.DifferenceCount == 5 && invocation.Cases.Length == 10,
            "Invocation case summary differs from ten cases and five differences");
        Require(invocation.OriginalLength == original.InputLength &&
                invocation.ChangedLength == original.InputLength,
            "Invocation image lengths differ from the definition");
        Require(string.Equals(invocation.OriginalSha1, original.RomSha1,
                StringComparison.OrdinalIgnoreCase),
            "Invocation original SHA1 differs from the definition");
        Require(invocation.OriginalSpan == Convert.ToHexString(original.OriginalBytes) &&
                invocation.ChangedSpan == Convert.ToHexString(changed.Encode()),
            "Invocation spans differ from the same definition");
        Require(invocation.ChangedOffsets.SequenceEqual(new[] { 0x9EDC }) &&
                invocation.ChangedOffsetsHex.SequenceEqual(new[] { "9EDC" }),
            "Invocation changed offsets are not exactly 9EDC");

        var originalResults = new Dictionary<ushort, ushort>();
        var changedResults = new Dictionary<ushort, ushort>();
        var seen = new HashSet<string>();
        foreach (var row in invocation.Cases)
        {
            Require(seen.Add($"{row.Variant}/{row.Input}"),
                $"Duplicate invocation case {row.Variant}/{row.Input}");
            var selected = row.Variant switch
            {
                "Original" => original,
                "Changed" => changed,
                _ => throw new InvalidDataException($"Unknown invocation variant {row.Variant}")
            };
            Require(row.ExitCode == 0 && row.DebugLogSha256.Length == 64,
                $"Invocation case {row.Variant}/{row.Input} exit or log hash differs");
            Require(Convert.ToHexString(selected.Encode()) == row.RuntimeSpan,
                $"Invocation case {row.Variant}/{row.Input} runtime span differs from the definition");

            Machine machine = ExecuteInvocationCase(selected, row.InputValue);
            machine.SyncDataToMemory();
            Require(machine.Data.Count == 1,
                $"C# definition left {machine.Data.Count} result cells for {row.Variant}/{row.Input}");
            Require(machine.Data.Peek() == row.Result,
                $"C# definition result {machine.Data.Peek():X4} for {row.Variant}/{row.Input} differs from recorded MAME result {row.Result:X4}");
            Require(machine.DataPointer == row.U,
                $"C# definition U {machine.DataPointer:X4} for {row.Variant}/{row.Input} differs from recorded MAME {row.U:X4}");
            Require(machine.Control is not null &&
                    machine.Control.Pointer == row.S &&
                    machine.Control.ResumeCursor == row.ReturnFrame &&
                    machine.ReadWord(Cell.Subtract(row.S, 2)) == row.ReturnFrame,
                $"C# definition S or return frame for {row.Variant}/{row.Input} differs from recorded MAME return frame {row.ReturnFrame:X4}");
            Require(row.Y == $"{row.ReturnFrame:X4}",
                $"Invocation case {row.Variant}/{row.Input} Y differs from its return frame");
            Require(row.Pc == (U16(invocation.Headers["ret"], "headers.ret") + 2).ToString("X4"),
                $"Invocation case {row.Variant}/{row.Input} stop PC differs from the return header");
            Require(row.FirstDispatch ==
                    $"{original.Address + 2:X4}/{original.Instructions[0].Token + 2:X4}",
                $"Invocation case {row.Variant}/{row.Input} first dispatch differs");

            if (row.Variant == "Original") originalResults.Add(row.InputValue, row.Result);
            else changedResults.Add(row.InputValue, row.Result);
        }

        Require(originalResults.Count == 5 && changedResults.Count == 5,
            "Invocation does not contain five original and five changed inputs");
        int differences = 0;
        foreach (var pair in originalResults)
            if (!changedResults.TryGetValue(pair.Key, out ushort changedResult) ||
                changedResult != pair.Value)
                differences++;
        Require(differences == invocation.DifferenceCount,
            $"Invocation records {invocation.DifferenceCount} differences but the captured results show {differences}");
    }

    private static InvocationEvidence ParseInvocation(string json)
    {
        using var document = JsonDocument.Parse(json);
        var root = document.RootElement;
        Require(Int(root, "schema_version") == 1, "Invocation schema differs");
        string classification = Text(root, "classification");
        Require(classification.StartsWith(
                "Independent MAME original-threaded-interpreter observation", StringComparison.Ordinal),
            "Invocation classification is not the accepted synthetic MAME observation");
        var source = root.GetProperty("source");
        var originalRom = source.GetProperty("original_rom");
        var changedRom = source.GetProperty("changed_rom");
        var headers = root.GetProperty("headers").EnumerateObject()
            .ToDictionary(pair => pair.Name, pair => pair.Value.GetString()!);
        var template = root.GetProperty("dispatch_template").EnumerateObject()
            .ToDictionary(pair => pair.Name, pair => pair.Value.GetString()!);
        var contract = root.GetProperty("contract");
        var checks = root.GetProperty("checks").EnumerateObject()
            .ToDictionary(pair => pair.Name, pair => pair.Value.GetBoolean());
        var cases = root.GetProperty("cases").EnumerateArray().Select(row => new InvocationCase(
            Text(row, "variant"),
            Text(row, "input"),
            U16(Text(row, "input"), "input"),
            U16(Text(row, "result"), "result"),
            U16(Text(row, "u"), "u"),
            U16(Text(row, "s"), "s"),
            U16(Text(row, "return_frame"), "return_frame"),
            Text(row, "pc"),
            Text(row, "y"),
            Text(row, "first_dispatch"),
            Text(row, "runtime_span"),
            Int(row, "exit_code"),
            Text(row, "debug_log_sha256"))).ToArray();
        return new InvocationEvidence(
            classification,
            Int(root, "case_count"),
            Int(root, "matched_case_count"),
            Int(root, "original_changed_difference_count"),
            Text(originalRom, "sha1"), Text(originalRom, "sha256"), Text(originalRom, "span"),
            Int(originalRom, "length"),
            Text(changedRom, "sha1"), Text(changedRom, "sha256"), Text(changedRom, "span"),
            Int(changedRom, "length"),
            changedRom.GetProperty("changed_offsets").EnumerateArray()
                .Select(value => value.GetInt32()).ToArray(),
            Strings(changedRom.GetProperty("changed_offsets_hex")),
            headers, template,
            Text(contract, "expected_u"), Text(contract, "expected_s"),
            Text(contract, "expected_return_frame"), Text(contract, "expected_first_dispatch"),
            source.GetProperty("emitted_original_sha1_matches").GetBoolean(),
            source.GetProperty("emitted_changed_sha1_matches").GetBoolean(),
            checks, cases);
    }

    private static Machine ExecuteInvocationCase(Mpu4VmDefinition definition, ushort input)
    {
        var machine = new Machine { DataStackBase = 0x602, LocalFrame = 0x700 };
        machine.Data.Push(input);
        machine.Control = new VmControlStack(machine, 0x700);
        machine.Control.Push(0x0782);
        new ScriptExecutor(machine).Run(definition.ToScript());
        return machine;
    }

    private static void Require(bool condition, string message)
    {
        if (!condition) throw new InvalidDataException(message);
    }

    private static string Text(JsonElement element, string name) =>
        element.GetProperty(name).GetString() ??
        throw new InvalidDataException($"Invocation field {name} is missing");

    private static int Int(JsonElement element, string name) =>
        element.GetProperty(name).GetInt32();

    private static ushort U16(string value, string name)
    {
        if (value.Length != 4)
            throw new InvalidDataException($"{name} must be four hexadecimal digits");
        try { return ushort.Parse(value, NumberStyles.HexNumber, CultureInfo.InvariantCulture); }
        catch (FormatException ex) { throw new InvalidDataException($"{name} is not hexadecimal", ex); }
    }

    private static string[] Strings(JsonElement element) =>
        element.EnumerateArray().Select(value => value.GetString() ??
            throw new InvalidDataException("Invocation array contains a non-string")).ToArray();

    private sealed record InvocationCase(
        string Variant, string Input, ushort InputValue, ushort Result, ushort U, ushort S,
        ushort ReturnFrame, string Pc, string Y, string FirstDispatch, string RuntimeSpan,
        int ExitCode, string DebugLogSha256);

    private sealed record InvocationEvidence(
        string Classification, int CaseCount, int MatchedCount, int DifferenceCount,
        string OriginalSha1, string OriginalSha256, string OriginalSpan, int OriginalLength,
        string ChangedSha1, string ChangedSha256, string ChangedSpan, int ChangedLength,
        int[] ChangedOffsets, string[] ChangedOffsetsHex,
        Dictionary<string, string> Headers, Dictionary<string, string> Template,
        string ExpectedU, string ExpectedS, string ExpectedReturnFrame, string ExpectedFirstDispatch,
        bool EmittedOriginalMatches, bool EmittedChangedMatches,
        Dictionary<string, bool> Checks, InvocationCase[] Cases);

    private static Machine ExecuteLiteral(Mpu4VmDefinition definition, ushort value)
    {
        var machine = new Machine();
        machine.LocalFrame = 0x700;
        machine.Data.Push(value);
        machine.Control = new VmControlStack(machine, 0x800);
        machine.Control.Push(0x9999);
        new ScriptExecutor(machine).Run(definition.ToScript());
        return machine;
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

}

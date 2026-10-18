using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace FruitMachineLab.Runtime;

// File offsets are explicit: this facility performs no relocation or integrity repair.
public sealed record RomPatchEdit
{
    public required int Offset { get; init; }
    public required string ExpectedHex { get; init; }
    public required string ReplacementHex { get; init; }
    public required string Provenance { get; init; }
}

public sealed record RomPatchSpec
{
    public required int SchemaVersion { get; init; }
    public required string Description { get; init; }
    public required int InputLength { get; init; }
    public required string InputSha1 { get; init; }
    public required RomPatchEdit[] Edits { get; init; }

    public static RomPatchSpec Parse(string json) => JsonSerializer.Deserialize<RomPatchSpec>(json,
        new JsonSerializerOptions { UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow })
        ?? throw new InvalidDataException("Missing patch specification");
}

public sealed record RomPatchResult(byte[] Image, string InputSha256, string OutputSha256, int[] ChangedOffsets);

public static class RomPatch
{
    public static RomPatchResult Apply(ReadOnlySpan<byte> original, RomPatchSpec spec)
    {
        ArgumentNullException.ThrowIfNull(spec);
        if (spec.SchemaVersion != 1 || string.IsNullOrWhiteSpace(spec.Description) ||
            spec.InputLength <= 0 || spec.Edits is not { Length: > 0 })
            throw new InvalidDataException("Invalid patch schema, description, length or edits");
        byte[] identity = Hex(spec.InputSha1);
        if (identity.Length != 20 || original.Length != spec.InputLength ||
            !SHA1.HashData(original).AsSpan().SequenceEqual(identity))
            throw new InvalidDataException("Unexpected ROM identity or length");

        var occupied = new HashSet<int>();
        var edits = new List<(int Offset, byte[] Replacement)>();
        foreach (var edit in spec.Edits)
        {
            if (edit is null || string.IsNullOrWhiteSpace(edit.Provenance))
                throw new InvalidDataException("Every edit requires provenance");
            byte[] expected = Hex(edit.ExpectedHex), replacement = Hex(edit.ReplacementHex);
            if (expected.Length == 0 || expected.Length != replacement.Length || edit.Offset < 0 ||
                edit.Offset > original.Length - expected.Length)
                throw new InvalidDataException("Edit must be nonempty, in bounds and preserve length");
            for (int i = 0; i < expected.Length; i++)
                if (!occupied.Add(edit.Offset + i)) throw new InvalidDataException("Overlapping patch edits");
            if (!original.Slice(edit.Offset, expected.Length).SequenceEqual(expected))
                throw new InvalidDataException($"Unexpected original bytes at file offset {edit.Offset:X4}");
            edits.Add((edit.Offset, replacement));
        }

        byte[] image = original.ToArray();
        foreach (var edit in edits) edit.Replacement.CopyTo(image, edit.Offset);
        var changes = new List<int>();
        for (int i = 0; i < image.Length; i++) if (image[i] != original[i]) changes.Add(i);
        return new(image, Convert.ToHexString(SHA256.HashData(original)),
            Convert.ToHexString(SHA256.HashData(image)), changes.ToArray());
    }

    private static byte[] Hex(string? value)
    {
        if (value is null) throw new InvalidDataException("Missing hex bytes");
        try { return Convert.FromHexString(value); }
        catch (FormatException ex) { throw new InvalidDataException("Invalid hex bytes", ex); }
    }
}

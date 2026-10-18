using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using FruitMachineLab.Runtime;

const int ExpectedOriginalLength = 65536;
const ushort ExpectedAddress = 0x9ED9;
const int ExpectedChangedOffset = 0x9EDC;
const ushort ChangedLiteral = 0xFF00;
const string ExpectedOriginalSha1 = "402D1518BB78FDC489B06C2AABC771E5CE151847";
const string ExpectedOriginalSha256 = "EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C";
const string ExpectedChangedSha1 = "51E81CC5F41DA2AA659A4D14D277E9E78614EB6B";
const string ExpectedChangedSha256 = "A99D96F8EA8B4770D2D3828125F25894E831726FE44A79A37E0871FABA135ED2";
const string ExpectedOriginalSpan = "795BFF80787E795BFF807AAF792F";
ushort[] expectedTokens = [0x795B, 0x787E, 0x795B, 0x7AAF, 0x792F];

try
{
    if (args.Length != 3)
    {
        Console.Error.WriteLine("usage: <definition.vm.json> <original-rom> <output-directory>");
        return 2;
    }

    string definitionPath = Path.GetFullPath(args[0]);
    string originalPath = Path.GetFullPath(args[1]);
    string outputDirectory = Path.GetFullPath(args[2]);
    if (!Directory.Exists(outputDirectory))
    {
        Console.Error.WriteLine($"output directory does not exist: {outputDirectory}");
        return 2;
    }

    // Fixed original identity and accepted narrow definition are checked before
    // any output path is written. A user-supplied definition cannot weaken them.
    byte[] original = File.ReadAllBytes(originalPath);
    if (original.Length != ExpectedOriginalLength)
        throw new InvalidDataException(
            $"original ROM length is {original.Length}, expected {ExpectedOriginalLength}");
    if (!string.Equals(Sha1(original), ExpectedOriginalSha1, StringComparison.OrdinalIgnoreCase))
        throw new InvalidDataException($"original ROM SHA1 does not match {ExpectedOriginalSha1}");
    if (!string.Equals(Sha256(original), ExpectedOriginalSha256, StringComparison.OrdinalIgnoreCase))
        throw new InvalidDataException($"original ROM SHA256 does not match {ExpectedOriginalSha256}");

    byte[] definitionBytes = File.ReadAllBytes(definitionPath);
    string definitionSha256 = Sha256(definitionBytes);
    Mpu4VmDefinition definition = Mpu4VmDefinition.Load(definitionPath);
    if (definition.Address != ExpectedAddress)
        throw new InvalidDataException($"unexpected definition address: {definition.Address:X4}");
    if (definition.InputLength != ExpectedOriginalLength)
        throw new InvalidDataException($"unexpected definition input length: {definition.InputLength}");
    if (!string.Equals(definition.RomSha1, ExpectedOriginalSha1, StringComparison.OrdinalIgnoreCase))
        throw new InvalidDataException("definition ROM SHA1 differs from the accepted original");
    if (definition.Instructions.Count != expectedTokens.Length ||
        !definition.Instructions.Select(instruction => instruction.Token).SequenceEqual(expectedTokens))
        throw new InvalidDataException("definition token contract differs from the accepted 9ED9 body");
    if (!string.Equals(Convert.ToHexString(definition.OriginalBytes), ExpectedOriginalSpan,
            StringComparison.OrdinalIgnoreCase))
        throw new InvalidDataException("definition original span differs from the accepted 9ED9 span");

    Mpu4VmImage reference = definition.Apply(original);
    if (!reference.Image.SequenceEqual(original) || reference.ChangedOffsets.Length != 0)
        throw new InvalidDataException("reference definition changed the original image");
    if (!reference.Encoded.SequenceEqual(definition.OriginalBytes))
        throw new InvalidDataException("reference definition did not reproduce the original span");

    Mpu4VmImage changed = definition.WithLiteral(0, ChangedLiteral).Apply(original);
    if (!changed.ChangedOffsets.SequenceEqual(new[] { ExpectedChangedOffset }))
        throw new InvalidDataException("changed definition did not emit exactly the 9EDC operand byte");
    if (changed.Encoded.Length != definition.OriginalBytes.Length ||
        changed.Encoded[3] != 0x00 || definition.OriginalBytes[3] != 0x80)
        throw new InvalidDataException("changed encoded span differs from the expected operand byte");
    if (!changed.Encoded.AsSpan(0, 3).SequenceEqual(definition.OriginalBytes.AsSpan(0, 3)) ||
        !changed.Encoded.AsSpan(4).SequenceEqual(definition.OriginalBytes.AsSpan(4)))
        throw new InvalidDataException("changed definition modified bytes outside the 9EDC operand");
    if (!string.Equals(Sha1(changed.Image), ExpectedChangedSha1, StringComparison.OrdinalIgnoreCase) ||
        !string.Equals(Sha256(changed.Image), ExpectedChangedSha256, StringComparison.OrdinalIgnoreCase))
        throw new InvalidDataException("changed image hashes differ from the accepted narrow edit");

    string originalOutput = Path.Combine(outputDirectory, "original.p1");
    string changedOutput = Path.Combine(outputDirectory, "changed-9edc.p1");
    string reportOutput = Path.Combine(outputDirectory, "emission.json");
    foreach (string target in new[] { originalOutput, changedOutput, reportOutput })
    {
        if (File.Exists(target) || Directory.Exists(target))
            throw new IOException($"target already exists: {target}");
    }

    // Re-read before writes so a changed input or specification is rejected
    // rather than silently producing an output from a stale decision.
    if (!File.ReadAllBytes(originalPath).SequenceEqual(original) ||
        !string.Equals(Sha256(File.ReadAllBytes(definitionPath)), definitionSha256,
            StringComparison.OrdinalIgnoreCase))
        throw new InvalidDataException("input ROM or definition changed during preflight");

    var report = new
    {
        schema_version = 1,
        classification = "Narrow emission of one checked 9ED9 inline literal from the existing C# definition; no integrity repair, relocation or general editor.",
        definition = new
        {
            path = definitionPath,
            address = $"{definition.Address:X4}",
            purpose = definition.Purpose,
            sha256 = definitionSha256
        },
        original = new
        {
            path = originalPath,
            length = original.Length,
            sha1 = Sha1(original),
            sha256 = Sha256(original),
            span_hex = Convert.ToHexString(definition.OriginalBytes)
        },
        changed = new
        {
            path = changedOutput,
            length = changed.Image.Length,
            sha1 = Sha1(changed.Image),
            sha256 = Sha256(changed.Image),
            span_hex = Convert.ToHexString(changed.Encoded),
            changed_offsets = changed.ChangedOffsets,
            changed_offsets_hex = changed.ChangedOffsets.Select(offset => $"{offset:X4}").ToArray()
        },
        literal = new { instruction_index = 0, original = "FF80", replacement = "FF00" },
        checks = new
        {
            original_length_matches_fixed = true,
            original_sha1_matches_fixed = true,
            original_sha256_matches_fixed = true,
            definition_unchanged = true,
            definition_token_contract = true,
            definition_original_span = true,
            reference_unchanged = true,
            exactly_one_changed_offset = true,
            changed_offset_is_9edc = true,
            changed_sha1_matches_fixed = true,
            changed_sha256_matches_fixed = true,
            checksum_fields_unchanged = true,
            original_readback = true,
            changed_readback = true,
            inputs_preserved = true
        }
    };
    byte[] reportBytes = Encoding.UTF8.GetBytes(
        JsonSerializer.Serialize(report, new JsonSerializerOptions { WriteIndented = true }));

    WriteAllCreateNew(
        new[] { originalOutput, changedOutput, reportOutput },
        new[] { original, changed.Image, reportBytes });

    if (!File.ReadAllBytes(originalOutput).SequenceEqual(original))
        throw new IOException("original copy readback differs");
    if (!File.ReadAllBytes(changedOutput).SequenceEqual(changed.Image))
        throw new IOException("changed copy readback differs");
    if (!File.ReadAllBytes(reportOutput).SequenceEqual(reportBytes))
        throw new IOException("report readback differs");
    if (!File.ReadAllBytes(originalPath).SequenceEqual(original) ||
        !File.ReadAllBytes(definitionPath).SequenceEqual(definitionBytes))
        throw new IOException("input ROM or definition was modified");

    Console.WriteLine($"original={originalOutput}");
    Console.WriteLine($"changed={changedOutput}");
    Console.WriteLine($"changed_offset={ExpectedChangedOffset:X4}");
    Console.WriteLine($"changed_sha1={Sha1(changed.Image)}");
    Console.WriteLine($"changed_sha256={Sha256(changed.Image)}");
    return 0;
}
catch (Exception ex) when (ex is IOException or InvalidDataException or JsonException or
                               UnauthorizedAccessException or ArgumentException)
{
    Console.Error.WriteLine(ex.Message);
    return 1;
}

static string Sha1(byte[] bytes) => Convert.ToHexString(SHA1.HashData(bytes));
static string Sha256(byte[] bytes) => Convert.ToHexString(SHA256.HashData(bytes));

// Reserve every target with CreateNew before writing any bytes. This rejects
// existing files, links and races without truncating an existing report.
static void WriteAllCreateNew(string[] paths, byte[][] contents)
{
    var streams = new List<FileStream>();
    var created = new List<string>();
    try
    {
        for (int index = 0; index < paths.Length; index++)
        {
            streams.Add(new FileStream(paths[index], FileMode.CreateNew, FileAccess.Write, FileShare.None));
            created.Add(paths[index]);
        }
        for (int index = 0; index < contents.Length; index++)
            streams[index].Write(contents[index]);
        foreach (var stream in streams) stream.Flush(true);
    }
    catch
    {
        foreach (var stream in streams) stream.Dispose();
        foreach (string path in created)
        {
            try { File.Delete(path); } catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }
        throw;
    }
    finally
    {
        foreach (var stream in streams) stream.Dispose();
    }
}

using System.Text.Json;
using FruitMachineLab.Runtime;

try
{
    if (args.Length != 3) throw new ArgumentException("Usage: RomPatch <spec.json> <original-rom> <new-output-rom>");
    string specPath = Path.GetFullPath(args[0]), input = Path.GetFullPath(args[1]), output = Path.GetFullPath(args[2]);
    if (string.Equals(input, output, StringComparison.OrdinalIgnoreCase) ||
        string.Equals(specPath, output, StringComparison.OrdinalIgnoreCase))
        throw new IOException("Output must be separate from the input and specification");
    var spec = RomPatchSpec.Parse(File.ReadAllText(specPath));
    var result = RomPatch.Apply(File.ReadAllBytes(input), spec);
    // CreateNew also rejects existing files, hard links and symlinks; never truncate.
    using (var stream = new FileStream(output, FileMode.CreateNew, FileAccess.Write)) stream.Write(result.Image);
    if (!File.ReadAllBytes(output).SequenceEqual(result.Image)) throw new IOException("Output readback mismatch");
    Console.WriteLine(JsonSerializer.Serialize(new {
        spec.Description, spec.InputSha1, result.InputSha256, result.OutputSha256,
        result.ChangedOffsets, Length = result.Image.Length,
        Integrity = "Not repaired or certified; emulator boot and hardware verification required"
    }, new JsonSerializerOptions { WriteIndented = true }));
    return 0;
}
catch (Exception ex) when (ex is IOException or InvalidDataException or ArgumentException or JsonException or UnauthorizedAccessException)
{
    Console.Error.WriteLine(ex.Message);
    return 1;
}

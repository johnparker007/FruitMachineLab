using System.Security.Cryptography;
using System.Text.Json;
using FruitMachineLab.Il;

const string TaskId = "il-edit-02";
const ushort OperandAddress = 0x9EDB;
const ushort ExpectedOriginalLiteral = 0xFF80;
const ushort ReplacementLiteral = 0xFF00;
const string ExpectedEditedSpan = "795BFF00787E795BFF807AAF792F";
const string ExpectedEditedSha1 = "51E81CC5F41DA2AA659A4D14D277E9E78614EB6B";
const string ExpectedEditedSha256 =
    "A99D96F8EA8B4770D2D3828125F25894E831726FE44A79A37E0871FABA135ED2";

try
{
    if (args.Length != 2)
    {
        Console.Error.WriteLine(
            "usage: FruitMachineLab.IlBuild <original-a6ls.p1> <new-output-directory>");
        return 2;
    }

    string romPath = Path.GetFullPath(args[0]);
    string outputDirectory = Path.GetFullPath(args[1]);
    string imagePath = Path.Combine(outputDirectory, "edited-unrepaired.p1");
    string reportPath = Path.Combine(outputDirectory, "build-report.json");
    string mapPath = Path.Combine(outputDirectory, "source-map.json");

    if (!File.Exists(romPath))
        throw new FileNotFoundException("original ROM not found", romPath);
    if (Directory.Exists(romPath))
        throw new IOException("original ROM path is a directory");
    if (string.Equals(romPath, outputDirectory, StringComparison.OrdinalIgnoreCase))
        throw new IOException("output directory must not alias the original ROM");
    if (File.Exists(outputDirectory))
        throw new IOException("output directory path is an existing file");

    byte[] original = File.ReadAllBytes(romPath);
    string originalSha1 = Sha1(original);
    string originalSha256 = Sha256(original);

    VmIlEditCompileResult edited = VmIlCompiler.CompileEdit(
        original, new VmIlOperandEdit(
            OperandAddress, ExpectedOriginalLiteral, ReplacementLiteral));

    string editedSha1 = Sha1(edited.Compile.Image);
    string editedSha256 = Sha256(edited.Compile.Image);
    if (!string.Equals(Convert.ToHexString(edited.Compile.EmittedBody),
            ExpectedEditedSpan, StringComparison.Ordinal))
        throw new InvalidDataException(
            "edited IL emission differs from the accepted 9ED9 span");
    if (!edited.Compile.ChangedOffsets.SequenceEqual(new[] { 0x9EDC }))
        throw new InvalidDataException(
            "edited image does not change exactly offset 9EDC");
    if (original[0x9EDC] != 0x80 || edited.Compile.Image[0x9EDC] != 0x00)
        throw new InvalidDataException("9EDC was not 80 -> 00");
    if (edited.Compile.Image[0x9EDB] != 0xFF ||
        edited.Compile.Image[0x9EE1] != 0xFF ||
        edited.Compile.Image[0x9EE2] != 0x80 ||
        edited.Compile.Image[0x9ED7] != 0x00 ||
        edited.Compile.Image[0x9ED8] != 0xF8)
        throw new InvalidDataException(
            "the first token, second literal or header changed unexpectedly");
    if (!string.Equals(editedSha1, ExpectedEditedSha1, StringComparison.OrdinalIgnoreCase) ||
        !string.Equals(editedSha256, ExpectedEditedSha256, StringComparison.OrdinalIgnoreCase) ||
        !string.Equals(edited.Compile.OutputSha256, ExpectedEditedSha256,
            StringComparison.OrdinalIgnoreCase))
        throw new InvalidDataException(
            "edited image hashes differ from the accepted 9EDC build");
    if (!string.Equals(edited.OriginalRomSha1, originalSha1,
            StringComparison.OrdinalIgnoreCase) ||
        !string.Equals(edited.OriginalRomSha256, originalSha256,
            StringComparison.OrdinalIgnoreCase))
        throw new InvalidDataException(
            "edited IL result does not retain the exact original identity");

    VmIlSourceMap map = VmIlSourceMap.CreateForBuild(
        edited.SourceDefinition, edited.Compile.Image, edited.Compile.EmittedBody);
    if (!string.Equals(map.ImageSha256, editedSha256, StringComparison.OrdinalIgnoreCase))
        throw new InvalidDataException(
            "source map is not bound to the exact output image SHA256");
    if (map.Entries.Count != 14 || map.IsIdentityBuild)
        throw new InvalidDataException(
            "edited source map is not the expected non-identity 14-byte map");
    for (int index = 0; index < map.Entries.Count; index++)
    {
        ushort address = (ushort)(map.BodyStart + index);
        VmIlSourceMapEntry entry = map.Resolve(address, editedSha256);
        if (entry.Address != address || entry.ImageByte != edited.Compile.Image[address])
            throw new InvalidDataException(
                $"source map entry at {address:X4} differs from the built image");
    }

    var diff = edited.Compile.ChangedOffsets.Select(offset => new
    {
        offset,
        offsetHex = $"{offset:X4}",
        before = $"{original[offset]:X2}",
        after = $"{edited.Compile.Image[offset]:X2}"
    }).ToArray();

    var report = new
    {
        schemaVersion = 1,
        taskId = TaskId,
        classification =
            "UNREPAIRED experimental IL edit build. Encoding and diff proof only; firmware " +
            "integrity fields are not regenerated and the image is not accepted for boot, MAME " +
            "execution or hardware compatibility.",
        original = new
        {
            path = romPath,
            length = original.Length,
            sha1 = originalSha1,
            sha256 = originalSha256,
            spanHex = Convert.ToHexString(original.AsSpan(
                edited.SourceDefinition.BodyStart, edited.SourceDefinition.BodyLength))
        },
        output = new
        {
            path = imagePath,
            length = edited.Compile.Image.Length,
            sha1 = editedSha1,
            sha256 = editedSha256,
            spanHex = Convert.ToHexString(edited.Compile.EmittedBody)
        },
        edit = new
        {
            nodeIndex = edited.Edit.NodeIndex,
            tokenAddress = $"{edited.Edit.TokenAddress:X4}",
            operandAddress = $"{edited.Edit.OperandAddress:X4}",
            operandWidthBytes = edited.Edit.OperandWidthBytes,
            token = $"{edited.Edit.Token:X4}",
            operation = edited.Edit.Operation,
            expectedOriginalValue = $"{edited.Edit.ExpectedOriginalValue:X4}",
            actualOriginalValue = $"{edited.Edit.ActualOriginalValue:X4}",
            replacementValue = $"{edited.Edit.ReplacementValue:X4}",
            expectedOriginalBytesHex = edited.Edit.ExpectedOriginalBytesHex,
            replacementBytesHex = edited.Edit.ReplacementBytesHex,
            changedOffsets = edited.Edit.ChangedOffsets,
            changedOffsetsHex = edited.Edit.ChangedOffsets
                .Select(offset => $"{offset:X4}").ToArray()
        },
        diff,
        integrity = new
        {
            repaired = edited.IntegrityRepaired,
            accepted = false,
            status = edited.IntegrityStatus
        },
        sourceMap = new
        {
            outputImageSha256 = map.ImageSha256,
            originalRomSha256 = map.RomSha256,
            identityBuild = map.IsIdentityBuild,
            bodyStart = $"{map.BodyStart:X4}",
            bodyEndExclusive = $"{map.BodyEndExclusive:X4}",
            coveredBytes = map.Entries.Count,
            entries = map.Entries.Count,
            path = mapPath
        },
        checks = new
        {
            originalIdentityStrict = true,
            editedSpanDerivedFromIlValue = true,
            exactlyOneChangedOffset = true,
            secondLiteralPreserved = true,
            headerPreserved = true,
            sourceMapBoundToOutputSha256 = true,
            integrityRepaired = false
        }
    };

    var mapReport = new
    {
        schemaVersion = 1,
        taskId = TaskId,
        classification =
            "Source map bound to the exact edited image SHA256. Original ROM addresses are " +
            "unchanged; the original image hash does not certify this modified image.",
        originalRomSha256 = map.RomSha256,
        outputImageSha256 = map.ImageSha256,
        identityBuild = map.IsIdentityBuild,
        bodyStart = $"{map.BodyStart:X4}",
        bodyEndExclusive = $"{map.BodyEndExclusive:X4}",
        entries = map.Entries.Select(entry => new
        {
            address = $"{entry.Address:X4}",
            nodeIndex = entry.NodeIndex,
            token = $"{entry.Token:X4}",
            operation = entry.Operation,
            imageByte = $"{entry.ImageByte:X2}"
        }).ToArray()
    };

    var jsonOptions = new JsonSerializerOptions { WriteIndented = true };
    byte[] reportBytes = JsonSerializer.SerializeToUtf8Bytes(report, jsonOptions);
    byte[] mapBytes = JsonSerializer.SerializeToUtf8Bytes(mapReport, jsonOptions);

    string[] targets = { imagePath, reportPath, mapPath };
    foreach (string target in targets)
    {
        if (string.Equals(target, romPath, StringComparison.OrdinalIgnoreCase))
            throw new IOException("output must be separate from the original ROM");
        if (File.Exists(target) || Directory.Exists(target))
            throw new IOException($"target already exists: {target}");
    }
    if (targets.Distinct(StringComparer.OrdinalIgnoreCase).Count() != targets.Length)
        throw new IOException("output target collision");

    if (!File.ReadAllBytes(romPath).SequenceEqual(original) ||
        !string.Equals(Sha1(File.ReadAllBytes(romPath)), originalSha1,
            StringComparison.OrdinalIgnoreCase) ||
        !string.Equals(Sha256(File.ReadAllBytes(romPath)), originalSha256,
            StringComparison.OrdinalIgnoreCase))
        throw new InvalidDataException("original ROM changed during preflight");

    if (!Directory.Exists(outputDirectory))
        Directory.CreateDirectory(outputDirectory);

    WriteAllCreateNew(
        targets, new[] { edited.Compile.Image, reportBytes, mapBytes });

    if (!File.ReadAllBytes(imagePath).SequenceEqual(edited.Compile.Image))
        throw new IOException("edited ROM readback differs");
    if (!File.ReadAllBytes(reportPath).SequenceEqual(reportBytes))
        throw new IOException("build report readback differs");
    if (!File.ReadAllBytes(mapPath).SequenceEqual(mapBytes))
        throw new IOException("source map readback differs");
    if (!File.ReadAllBytes(romPath).SequenceEqual(original))
        throw new IOException("original ROM was modified");

    Console.WriteLine("original_sha1=" + originalSha1);
    Console.WriteLine("original_sha256=" + originalSha256);
    Console.WriteLine("output_sha1=" + editedSha1);
    Console.WriteLine("output_sha256=" + editedSha256);
    Console.WriteLine("changed_offset=9EDC");
    Console.WriteLine("span=" + ExpectedEditedSpan);
    Console.WriteLine("integrity=UNREPAIRED (no boot, MAME or hardware claim)");
    Console.WriteLine("image=" + imagePath);
    Console.WriteLine("report=" + reportPath);
    Console.WriteLine("source_map=" + mapPath);
    return 0;
}
catch (Exception ex) when (ex is IOException or InvalidDataException or
                               UnauthorizedAccessException or ArgumentException or
                               NotSupportedException)
{
    Console.Error.WriteLine(ex.Message);
    return 1;
}

static string Sha1(byte[] bytes) => Convert.ToHexString(SHA1.HashData(bytes));

static string Sha256(byte[] bytes) => Convert.ToHexString(SHA256.HashData(bytes));

static void WriteAllCreateNew(string[] paths, byte[][] contents)
{
    var streams = new List<FileStream>();
    var created = new List<string>();
    try
    {
        for (int index = 0; index < paths.Length; index++)
        {
            streams.Add(new FileStream(
                paths[index], FileMode.CreateNew, FileAccess.Write, FileShare.None));
            created.Add(paths[index]);
        }
        for (int index = 0; index < contents.Length; index++)
            streams[index].Write(contents[index]);
        foreach (FileStream stream in streams)
            stream.Flush(true);
    }
    catch
    {
        foreach (FileStream stream in streams)
            stream.Dispose();
        foreach (string path in created)
        {
            try { File.Delete(path); }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }
        throw;
    }
    finally
    {
        foreach (FileStream stream in streams)
            stream.Dispose();
    }
}

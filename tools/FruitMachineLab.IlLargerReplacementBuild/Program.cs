using System.Security.Cryptography;
using System.Text.Json;
using FruitMachineLab.Il;

const string TaskId = "il-larger-replacement-build-50";
const string ExpectedOriginalSha1 = "402D1518BB78FDC489B06C2AABC771E5CE151847";
const string ExpectedOriginalSha256 =
    "EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C";

try
{
    if (args.Length != 2)
    {
        Console.Error.WriteLine(
            "usage: FruitMachineLab.IlLargerReplacementBuild <original-a6ls.p1> " +
            "<new-output-directory>");
        return 2;
    }

    string romPath = Path.GetFullPath(args[0]);
    string outputDirectory = Path.GetFullPath(args[1]);
    const string unrepairedFileName = "larger-unrepaired.p1";
    const string repairedFileName = "larger-repaired.p1";
    const string mapFileName = "larger-replacement-source-map.json";
    const string buildReportFileName = "build-report.json";
    string unrepairedPath = Path.Combine(outputDirectory, unrepairedFileName);
    string repairedPath = Path.Combine(outputDirectory, repairedFileName);
    string mapPath = Path.Combine(outputDirectory, mapFileName);
    string buildReportPath = Path.Combine(outputDirectory, buildReportFileName);

    if (Directory.Exists(romPath))
        throw new IOException("original ROM path is a directory");
    if (!File.Exists(romPath))
        throw new FileNotFoundException("original ROM not found", romPath);
    if (string.Equals(romPath, outputDirectory, StringComparison.OrdinalIgnoreCase))
        throw new IOException("output directory must not alias the original ROM");
    if (File.Exists(outputDirectory))
        throw new IOException("output directory path is an existing file");
    if (Directory.Exists(outputDirectory))
        throw new IOException(
            $"output directory already exists and will not be replaced: {outputDirectory}");

    byte[] original = File.ReadAllBytes(romPath);
    if (original.Length != 65536)
        throw new InvalidDataException(
            $"original ROM length {original.Length} differs from the supported 65536 bytes");
    string originalSha1 = Sha1(original);
    string originalSha256 = Sha256(original);
    if (!string.Equals(originalSha1, ExpectedOriginalSha1, StringComparison.OrdinalIgnoreCase) ||
        !string.Equals(originalSha256, ExpectedOriginalSha256,
            StringComparison.OrdinalIgnoreCase))
        throw new InvalidDataException(
            "original ROM identity differs from the supported a6ls.p1 revision");

    LargerReplacementBuildResult build = LargerReplacementBuilder.Build(original);

    byte[] unrepairedImage = build.CopyUnrepairedImage();
    byte[] repairedImage = build.CopyOutputImage();
    if (!string.Equals(
            build.OutputImageSha1, LargerReplacementBuilder.ExpectedOutputSha1,
            StringComparison.OrdinalIgnoreCase) ||
        !string.Equals(
            build.OutputImageSha256, LargerReplacementBuilder.ExpectedOutputSha256,
            StringComparison.OrdinalIgnoreCase))
        throw new InvalidDataException(
            "built image hashes differ from the reviewed larger-replacement contract");
    if (build.UnrepairedChangedOffsets.Count != 22 ||
        build.ChangedOffsets.Count != 27 ||
        build.RepairChangedOffsets.Count != 5)
        throw new InvalidDataException(
            "built diff counts are not the reviewed 22 unrepaired / 27 final / 5 repair");
    if (build.SourceMap.BuildId != build.OutputImageSha256)
        throw new InvalidDataException("source map is not bound to the output SHA256");
    if (build.SourceMap.Phases.Count != 17)
        throw new InvalidDataException(
            "source map does not contain the reviewed 17 static phases");

    var jsonOptions = new JsonSerializerOptions { WriteIndented = true };
    byte[] mapBytes = JsonSerializer.SerializeToUtf8Bytes(build.SourceMap, jsonOptions);
    var report = new
    {
        schemaVersion = 1,
        taskId = TaskId,
        classification = build.Status,
        staticOnly = true,
        executionClaimed = false,
        original = new
        {
            fileName = Path.GetFileName(romPath),
            length = original.Length,
            sha1 = originalSha1,
            sha256 = originalSha256
        },
        unrepaired = new
        {
            fileName = unrepairedFileName,
            length = unrepairedImage.Length,
            sha1 = build.UnrepairedImageSha1,
            sha256 = build.UnrepairedImageSha256,
            changedCount = build.UnrepairedChangedOffsets.Count,
            changedOffsets = build.UnrepairedChangedOffsets
        },
        repaired = new
        {
            fileName = repairedFileName,
            length = repairedImage.Length,
            sha1 = build.OutputImageSha1,
            sha256 = build.OutputImageSha256,
            changedCount = build.ChangedOffsets.Count,
            changedOffsets = build.ChangedOffsets
        },
        allocation = new
        {
            start = "1010",
            endInclusive = "1025",
            length = 22,
            headerHex = LargerReplacementBuilder.HeaderHex,
            bodyStart = "1012",
            bodyEndExclusive = "1026",
            bodyHex = LargerReplacementBuilder.BodyHex,
            payloadHex = LargerReplacementBuilder.PayloadHex,
            nodeCount = LargerReplacementBuilder.NodeCount,
            inlineOperandCount = LargerReplacementBuilder.InlineOperandCount,
            inlineOperandAddresses = new[] { "1014", "101A", "1020" },
            fullAllocationIsOriginalFF = true,
            bytes1014And101ARemainFF = true
        },
        caller = new
        {
            address = "9F14",
            expectedToken = "9ED7",
            replacementToken = "1010",
            successorAddress = "9F16",
            successorToken = "75A9",
            otherCallerBytesPreserved = true
        },
        originalDefinition = new
        {
            header = "9ED7",
            body = "9ED9",
            preserved = true
        },
        integrity = new
        {
            originalFieldsHex = build.IntegrityReport.OriginalStoredFieldsHex,
            repairedFieldsHex = build.IntegrityReport.RepairedStoredFieldsHex,
            repairChangedOffsets = build.RepairChangedOffsets,
            algorithmOrder = build.IntegrityReport.AlgorithmOrder,
            status = build.IntegrityReport.Status
        },
        sourceMap = new
        {
            fileName = mapFileName,
            buildId = build.SourceMap.BuildId,
            entries = build.SourceMap.Entries.Count,
            nodes = build.SourceMap.Nodes.Count,
            inlineOperands = build.SourceMap.InlineOperands.Count,
            phases = build.SourceMap.Phases.Count,
            caller = build.SourceMap.Caller,
            semantics = build.SourceMap.Semantics,
            staticContract = build.SourceMap.StaticContract
        },
        provenance = build.Provenance,
        limitations = new[]
        {
            "Static compilation only. The new body at 1012-1025, natural boot and gameplay " +
            "were not observed.",
            "The predicted 0000 -> 0001 callee exit is a static result; 75A9 then normalizes " +
            "positive 0001 to 0000, so the parent result may remain unchanged.",
            "Both the body and the caller successor 75A9 remain unexecuted here. No MAME " +
            "run, capture, PC/Y/U/S observation or hardware test was made."
        }
    };
    byte[] reportBytes = JsonSerializer.SerializeToUtf8Bytes(report, jsonOptions);

    string[] targets = { unrepairedPath, repairedPath, mapPath, buildReportPath };
    byte[][] contents = { unrepairedImage, repairedImage, mapBytes, reportBytes };
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

    WriteOutputs(outputDirectory, targets, contents);

    if (!File.ReadAllBytes(unrepairedPath).SequenceEqual(unrepairedImage))
        throw new IOException("unrepaired ROM readback differs");
    if (!File.ReadAllBytes(repairedPath).SequenceEqual(repairedImage))
        throw new IOException("repaired ROM readback differs");
    if (!File.ReadAllBytes(mapPath).SequenceEqual(mapBytes))
        throw new IOException("source map readback differs");
    if (!File.ReadAllBytes(buildReportPath).SequenceEqual(reportBytes))
        throw new IOException("build report readback differs");
    if (!File.ReadAllBytes(romPath).SequenceEqual(original))
        throw new IOException("original ROM was modified");

    Console.WriteLine("original_sha1=" + originalSha1);
    Console.WriteLine("original_sha256=" + originalSha256);
    Console.WriteLine("unrepaired_sha1=" + build.UnrepairedImageSha1);
    Console.WriteLine("unrepaired_sha256=" + build.UnrepairedImageSha256);
    Console.WriteLine("repaired_sha1=" + build.OutputImageSha1);
    Console.WriteLine("repaired_sha256=" + build.OutputImageSha256);
    Console.WriteLine("repaired_fields=" + build.IntegrityReport.RepairedStoredFieldsHex);
    Console.WriteLine("unrepaired_changed=" + build.UnrepairedChangedOffsets.Count);
    Console.WriteLine("final_changed=" + build.ChangedOffsets.Count);
    Console.WriteLine("changed_offsets=" + string.Join(',',
        build.ChangedOffsets.Select(offset => $"{offset:X4}")));
    Console.WriteLine("classification=STATIC_ONLY (no MAME, gameplay or hardware claim)");
    Console.WriteLine("unrepaired_image=" + unrepairedPath);
    Console.WriteLine("repaired_image=" + repairedPath);
    Console.WriteLine("source_map=" + mapPath);
    Console.WriteLine("build_report=" + buildReportPath);
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

static void WriteOutputs(string directory, string[] paths, byte[][] contents)
{
    var created = new List<string>();
    bool directoryCreated = false;
    var streams = new List<FileStream>();
    try
    {
        if (Directory.Exists(directory))
            throw new IOException(
                $"output directory already exists and will not be replaced: {directory}");
        Directory.CreateDirectory(directory);
        directoryCreated = true;

        for (int index = 0; index < paths.Length; index++)
        {
            if (!string.Equals(
                    Path.GetDirectoryName(paths[index]), directory,
                    StringComparison.OrdinalIgnoreCase))
                throw new IOException("output target lies outside the output directory");
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
        if (directoryCreated)
        {
            try { Directory.Delete(directory, recursive: false); }
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

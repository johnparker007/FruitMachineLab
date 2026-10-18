using System.Security.Cryptography;
using System.Text.Json;
using FruitMachineLab.Il;

const string TaskId = "il-integrity-03";
const ushort OperandAddress = 0x9EDB;
const ushort ExpectedOriginalLiteral = 0xFF80;
const ushort ReplacementLiteral = 0xFF00;
const string ExpectedOriginalSpan = "795BFF80787E795BFF807AAF792F";
const string ExpectedEditedSpan = "795BFF00787E795BFF807AAF792F";
const string ExpectedUnrepairedSha1 = "51E81CC5F41DA2AA659A4D14D277E9E78614EB6B";
const string ExpectedUnrepairedSha256 =
    "A99D96F8EA8B4770D2D3828125F25894E831726FE44A79A37E0871FABA135ED2";
const string ExpectedUnrepairedFields = "3E761E2605";
const string ExpectedRepairedFields = "BEF69E7CC7";
const string ExpectedRepairedSha1 = "E1A42DCCD304B7B175AABAC99E8400CDAD04CF69";
const string ExpectedRepairedSha256 =
    "577F76BD36DFCA04DFB01B5F5D0BE93E16572F8617C7CA906397C98DF36E5107";
const string SupportedOriginalSha1 = "402D1518BB78FDC489B06C2AABC771E5CE151847";
const string SupportedOriginalSha256 =
    "EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C";

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
    string unrepairedPath = Path.Combine(outputDirectory, "edited-unrepaired.p1");
    string repairedPath = Path.Combine(outputDirectory, "edited-repaired.p1");
    string buildReportPath = Path.Combine(outputDirectory, "build-report.json");
    string integrityReportPath = Path.Combine(outputDirectory, "integrity-report.json");
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
    if (original.Length != 65536)
        throw new InvalidDataException(
            $"original ROM length {original.Length} differs from the supported 65536 bytes");
    string originalSha1 = Sha1(original);
    string originalSha256 = Sha256(original);
    if (!string.Equals(originalSha1, SupportedOriginalSha1, StringComparison.OrdinalIgnoreCase) ||
        !string.Equals(originalSha256, SupportedOriginalSha256, StringComparison.OrdinalIgnoreCase))
        throw new InvalidDataException(
            "original ROM identity differs from the supported a6ls.p1 revision");

    VmIlRepairedEditCompileResult build = VmIlCompiler.CompileEditWithIntegrity(
        original, new VmIlOperandEdit(
            OperandAddress, ExpectedOriginalLiteral, ReplacementLiteral));

    VmIlEditCompileResult unrepaired = build.Unrepaired;
    byte[] unrepairedImage = unrepaired.Compile.Image;
    VmIlIntegrityResult integrity = build.Integrity;
    byte[] repairedImage = integrity.RepairedImage;
    VmIlIntegrityReport integrityReport = integrity.Report;

    if (!string.Equals(
            Convert.ToHexString(original.AsSpan(0x9ED9, 14)), ExpectedOriginalSpan,
            StringComparison.Ordinal))
        throw new InvalidDataException("original 9ED9 span differs from the accepted span");
    if (!string.Equals(
            Convert.ToHexString(unrepairedImage.AsSpan(0x9ED9, 14)), ExpectedEditedSpan,
            StringComparison.Ordinal))
        throw new InvalidDataException(
            "edited IL emission differs from the accepted 9ED9 span");
    if (!unrepaired.Compile.ChangedOffsets.SequenceEqual(new[] { 0x9EDC }))
        throw new InvalidDataException(
            "edited image does not change exactly offset 9EDC");
    if (original[0x9EDC] != 0x80 || unrepairedImage[0x9EDC] != 0x00)
        throw new InvalidDataException("9EDC was not 80 -> 00");
    if (unrepairedImage[0x9EDB] != 0xFF ||
        unrepairedImage[0x9EE1] != 0xFF ||
        unrepairedImage[0x9EE2] != 0x80 ||
        unrepairedImage[0x9ED7] != 0x00 ||
        unrepairedImage[0x9ED8] != 0xF8)
        throw new InvalidDataException(
            "the first token, second literal or header changed unexpectedly");

    string unrepairedSha1 = Sha1(unrepairedImage);
    string unrepairedSha256 = Sha256(unrepairedImage);
    string repairedSha1 = integrity.RepairedImageSha1;
    string repairedSha256 = integrity.RepairedImageSha256;
    if (!string.Equals(unrepairedSha1, ExpectedUnrepairedSha1, StringComparison.OrdinalIgnoreCase) ||
        !string.Equals(unrepairedSha256, ExpectedUnrepairedSha256,
            StringComparison.OrdinalIgnoreCase) ||
        !string.Equals(unrepaired.Compile.OutputSha256, ExpectedUnrepairedSha256,
            StringComparison.OrdinalIgnoreCase))
        throw new InvalidDataException(
            "unrepaired image hashes differ from the accepted 9EDC build");
    if (!string.Equals(repairedSha1, ExpectedRepairedSha1, StringComparison.OrdinalIgnoreCase) ||
        !string.Equals(repairedSha256, ExpectedRepairedSha256,
            StringComparison.OrdinalIgnoreCase))
        throw new InvalidDataException(
            "repaired image hashes differ from the derived ordered repair");
    if (!string.Equals(integrity.OriginalRomSha1, originalSha1,
            StringComparison.OrdinalIgnoreCase) ||
        !string.Equals(integrity.OriginalRomSha256, originalSha256,
            StringComparison.OrdinalIgnoreCase) ||
        !string.Equals(integrity.UnrepairedImageSha256, unrepairedSha256,
            StringComparison.OrdinalIgnoreCase))
        throw new InvalidDataException(
            "integrity result does not retain the exact original and unrepaired identities");
    if (!string.Equals(
            integrityReport.OriginalStoredFieldsHex, ExpectedUnrepairedFields,
            StringComparison.Ordinal) ||
        !string.Equals(
            integrityReport.OriginalComputedFieldsHex, ExpectedUnrepairedFields,
            StringComparison.Ordinal) ||
        !string.Equals(
            integrityReport.UnrepairedStoredFieldsHex, ExpectedUnrepairedFields,
            StringComparison.Ordinal) ||
        !string.Equals(
            integrityReport.RepairedStoredFieldsHex, ExpectedRepairedFields,
            StringComparison.Ordinal) ||
        !string.Equals(
            integrityReport.RepairedComputedFieldsHex, ExpectedRepairedFields,
            StringComparison.Ordinal))
        throw new InvalidDataException(
            "integrity report fields differ from the derived ordered repair");
    if (!repairedImage.AsSpan(0x9ED9, 14).SequenceEqual(unrepairedImage.AsSpan(0x9ED9, 14)))
        throw new InvalidDataException("repair changed the edited 9ED9 span");

    int[] expectedRepairedDiff =
        new[] { 0x9EDC }.Concat(Enumerable.Range(0xFFD1, 5)).ToArray();
    int[] actualRepairedDiff = Diff(original, repairedImage);
    if (!actualRepairedDiff.SequenceEqual(expectedRepairedDiff))
        throw new InvalidDataException(
            "repaired image diff is not 9EDC plus the active fields FFD1-FFD5");
    if (!Diff(unrepairedImage, repairedImage).SequenceEqual(Enumerable.Range(0xFFD1, 5)))
        throw new InvalidDataException(
            "repair diff is not exactly the active fields FFD1-FFD5");

    VmIlSourceMap map = VmIlSourceMap.CreateForBuild(
        unrepaired.SourceDefinition, repairedImage, unrepaired.Compile.EmittedBody);
    if (!string.Equals(map.ImageSha256, repairedSha256, StringComparison.OrdinalIgnoreCase))
        throw new InvalidDataException(
            "source map is not bound to the exact repaired image SHA256");
    if (map.Entries.Count != 14 || map.IsIdentityBuild)
        throw new InvalidDataException(
            "repaired source map is not the expected non-identity 14-byte map");
    for (int index = 0; index < map.Entries.Count; index++)
    {
        ushort address = (ushort)(map.BodyStart + index);
        VmIlSourceMapEntry entry = map.Resolve(address, repairedSha256);
        if (entry.Address != address || entry.ImageByte != repairedImage[address])
            throw new InvalidDataException(
                $"source map entry at {address:X4} differs from the repaired image");
    }
    if (map.Resolve(0x9EDC, repairedSha256).ImageByte != 0x00)
        throw new InvalidDataException(
            "repaired source map does not resolve the edited operand to 00");

    var unrepairedDiff = unrepaired.Compile.ChangedOffsets.Select(offset => new
    {
        offset,
        offsetHex = $"{offset:X4}",
        before = $"{original[offset]:X2}",
        after = $"{unrepairedImage[offset]:X2}"
    }).ToArray();

    var repairedDiff = actualRepairedDiff.Select(offset => new
    {
        offset,
        offsetHex = $"{offset:X4}",
        before = $"{original[offset]:X2}",
        after = $"{repairedImage[offset]:X2}"
    }).ToArray();

    var repairOnlyDiff = Diff(unrepairedImage, repairedImage).Select(offset => new
    {
        offset,
        offsetHex = $"{offset:X4}",
        before = $"{unrepairedImage[offset]:X2}",
        after = $"{repairedImage[offset]:X2}"
    }).ToArray();

    var fieldWrites = integrityReport.Fields.Select(field => new
    {
        field.Name,
        offset = field.Offset,
        offsetHex = $"{field.Offset:X4}",
        before = $"{field.UnrepairedValue:X2}",
        after = $"{field.RepairedValue:X2}",
        field.Dependency
    }).ToArray();

    var report = new
    {
        schemaVersion = 1,
        taskId = TaskId,
        classification =
            "ALGORITHMICALLY REPAIRED experimental IL edit build. Encoding, diff and ordered " +
            "integrity-field regeneration only; this is not natural boot acceptance, MAME " +
            "execution evidence or hardware compatibility.",
        original = new
        {
            path = romPath,
            length = original.Length,
            sha1 = originalSha1,
            sha256 = originalSha256,
            spanHex = Convert.ToHexString(original.AsSpan(
                unrepaired.SourceDefinition.BodyStart,
                unrepaired.SourceDefinition.BodyLength)),
            storedFieldsHex = integrityReport.OriginalStoredFieldsHex,
            computedFieldsHex = integrityReport.OriginalComputedFieldsHex
        },
        unrepaired = new
        {
            path = unrepairedPath,
            length = unrepairedImage.Length,
            sha1 = unrepairedSha1,
            sha256 = unrepairedSha256,
            spanHex = Convert.ToHexString(unrepaired.Compile.EmittedBody),
            storedFieldsHex = integrityReport.UnrepairedStoredFieldsHex,
            changedOffsets = unrepaired.Compile.ChangedOffsets,
            changedOffsetsHex = unrepaired.Compile.ChangedOffsets
                .Select(offset => $"{offset:X4}").ToArray(),
            integrityStatus = unrepaired.IntegrityStatus
        },
        repaired = new
        {
            path = repairedPath,
            length = repairedImage.Length,
            sha1 = repairedSha1,
            sha256 = repairedSha256,
            spanHex = Convert.ToHexString(repairedImage.AsSpan(0x9ED9, 14)),
            storedFieldsHex = integrityReport.RepairedStoredFieldsHex,
            computedFieldsHex = integrityReport.RepairedComputedFieldsHex,
            changedOffsets = actualRepairedDiff,
            changedOffsetsHex = actualRepairedDiff
                .Select(offset => $"{offset:X4}").ToArray(),
            integrityStatus = integrityReport.Status
        },
        edit = new
        {
            nodeIndex = unrepaired.Edit.NodeIndex,
            tokenAddress = $"{unrepaired.Edit.TokenAddress:X4}",
            operandAddress = $"{unrepaired.Edit.OperandAddress:X4}",
            operandWidthBytes = unrepaired.Edit.OperandWidthBytes,
            token = $"{unrepaired.Edit.Token:X4}",
            operation = unrepaired.Edit.Operation,
            expectedOriginalValue = $"{unrepaired.Edit.ExpectedOriginalValue:X4}",
            actualOriginalValue = $"{unrepaired.Edit.ActualOriginalValue:X4}",
            replacementValue = $"{unrepaired.Edit.ReplacementValue:X4}",
            expectedOriginalBytesHex = unrepaired.Edit.ExpectedOriginalBytesHex,
            replacementBytesHex = unrepaired.Edit.ReplacementBytesHex,
            changedOffsets = unrepaired.Edit.ChangedOffsets,
            changedOffsetsHex = unrepaired.Edit.ChangedOffsets
                .Select(offset => $"{offset:X4}").ToArray()
        },
        unrepairedDiff,
        repairedDiff,
        repairOnlyDiff,
        integrity = new
        {
            repaired = true,
            accepted = false,
            recordBase = $"{integrityReport.RecordBase:X4}",
            rangeStart = $"{integrityReport.RangeStart:X4}",
            rangeEnd = $"{integrityReport.RangeEnd:X4}",
            errorCode = $"{integrityReport.ErrorCode:X2}",
            gate = $"{integrityReport.Gate:X2}",
            algorithmOrder = integrityReport.AlgorithmOrder,
            evidenceSource = integrityReport.EvidenceSource,
            fieldWrites,
            status = integrityReport.Status
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
            originalFieldsVerified = true,
            editedSpanDerivedFromIlValue = true,
            exactlyOneUnrepairedChangedOffset = true,
            secondLiteralPreserved = true,
            headerPreserved = true,
            orderedIntegrityRepair = true,
            repairedDiffIsEditPlusFields = true,
            sourceMapBoundToRepairedSha256 = true,
            acceptedForBoot = false
        },
        limitations = new[]
        {
            "Only the fixed 9ED9 definition, four tokens and the first 795B operand at 9EDB " +
            "are supported.",
            "Only the active gate-00 record FFD1 is regenerated; the three disabled records " +
            "and the original checker code are preserved unchanged.",
            "Algorithmically repaired is not natural boot acceptance, MAME execution evidence " +
            "or physical hardware compatibility.",
            "No MAME launch, capture, PC/Y/U/S observation or synthetic invocation is performed."
        }
    };

    var integrityOnlyReport = new
    {
        schemaVersion = 1,
        taskId = TaskId,
        classification =
            "Ordered regeneration of the active gate-00 firmware integrity fields for the " +
            "checked 9ED9 edit. Static algorithm execution; no checker bypass.",
        original = new
        {
            length = original.Length,
            sha1 = originalSha1,
            sha256 = originalSha256
        },
        unrepaired = new
        {
            length = unrepairedImage.Length,
            sha1 = unrepairedSha1,
            sha256 = unrepairedSha256,
            storedFieldsHex = integrityReport.UnrepairedStoredFieldsHex
        },
        repaired = new
        {
            length = repairedImage.Length,
            sha1 = repairedSha1,
            sha256 = repairedSha256,
            storedFieldsHex = integrityReport.RepairedStoredFieldsHex,
            computedFieldsHex = integrityReport.RepairedComputedFieldsHex
        },
        record = new
        {
            baseAddress = $"{integrityReport.RecordBase:X4}",
            rangeStart = $"{integrityReport.RangeStart:X4}",
            rangeEnd = $"{integrityReport.RangeEnd:X4}",
            errorCode = $"{integrityReport.ErrorCode:X2}",
            gate = $"{integrityReport.Gate:X2}",
            enabled = true
        },
        algorithmOrder = integrityReport.AlgorithmOrder,
        evidenceSource = integrityReport.EvidenceSource,
        fieldWrites,
        repairOnlyDiff,
        status = integrityReport.Status,
        limitations = new[]
        {
            "Recomputed fields are algorithmic; natural checker acceptance in MAME is not " +
            "claimed by this report.",
            "Disabled records FFB0-FFD0, checker code 66A5-674F and outer gate 719B are " +
            "preserved, not patched.",
            "Physical hardware compatibility remains unverified."
        }
    };

    var mapReport = new
    {
        schemaVersion = 1,
        taskId = TaskId,
        classification =
            "Source map bound to the exact repaired image SHA256. Original ROM addresses are " +
            "unchanged; the repaired hash, not the original hash, identifies this image.",
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
    byte[] buildReportBytes = JsonSerializer.SerializeToUtf8Bytes(report, jsonOptions);
    byte[] integrityReportBytes =
        JsonSerializer.SerializeToUtf8Bytes(integrityOnlyReport, jsonOptions);
    byte[] mapBytes = JsonSerializer.SerializeToUtf8Bytes(mapReport, jsonOptions);

    string[] targets =
    {
        unrepairedPath, repairedPath, buildReportPath, integrityReportPath, mapPath
    };
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
        targets,
        new[] { unrepairedImage, repairedImage, buildReportBytes, integrityReportBytes, mapBytes });

    if (!File.ReadAllBytes(unrepairedPath).SequenceEqual(unrepairedImage))
        throw new IOException("unrepaired ROM readback differs");
    if (!File.ReadAllBytes(repairedPath).SequenceEqual(repairedImage))
        throw new IOException("repaired ROM readback differs");
    if (!File.ReadAllBytes(buildReportPath).SequenceEqual(buildReportBytes))
        throw new IOException("build report readback differs");
    if (!File.ReadAllBytes(integrityReportPath).SequenceEqual(integrityReportBytes))
        throw new IOException("integrity report readback differs");
    if (!File.ReadAllBytes(mapPath).SequenceEqual(mapBytes))
        throw new IOException("source map readback differs");
    if (!File.ReadAllBytes(romPath).SequenceEqual(original))
        throw new IOException("original ROM was modified");

    Console.WriteLine("original_sha1=" + originalSha1);
    Console.WriteLine("original_sha256=" + originalSha256);
    Console.WriteLine("unrepaired_sha1=" + unrepairedSha1);
    Console.WriteLine("unrepaired_sha256=" + unrepairedSha256);
    Console.WriteLine("repaired_sha1=" + repairedSha1);
    Console.WriteLine("repaired_sha256=" + repairedSha256);
    Console.WriteLine("unrepaired_changed_offset=9EDC");
    Console.WriteLine("unrepaired_fields=" + integrityReport.UnrepairedStoredFieldsHex);
    Console.WriteLine("repaired_fields=" + integrityReport.RepairedStoredFieldsHex);
    Console.WriteLine("repaired_changed_offsets=9EDC,FFD1,FFD2,FFD3,FFD4,FFD5");
    Console.WriteLine("span=" + ExpectedEditedSpan);
    Console.WriteLine("integrity=ALGORITHMICALLY_REPAIRED (no boot, MAME or hardware claim)");
    Console.WriteLine("unrepaired_image=" + unrepairedPath);
    Console.WriteLine("repaired_image=" + repairedPath);
    Console.WriteLine("build_report=" + buildReportPath);
    Console.WriteLine("integrity_report=" + integrityReportPath);
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

static int[] Diff(byte[] before, byte[] after)
{
    if (before.Length != after.Length)
        throw new InvalidDataException("image lengths differ");
    var changed = new List<int>();
    for (int offset = 0; offset < before.Length; offset++)
    {
        if (before[offset] != after[offset])
            changed.Add(offset);
    }
    return changed.ToArray();
}

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

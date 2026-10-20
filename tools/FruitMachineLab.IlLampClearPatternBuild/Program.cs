using System.Security.Cryptography;
using System.Text.Json;
using FruitMachineLab.Il;

const string TaskId = "il-lamp-clear-build-71";
const string ExpectedOriginalSha1 = "402D1518BB78FDC489B06C2AABC771E5CE151847";
const string ExpectedOriginalSha256 =
    "EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C";

try
{
    if (args.Length != 2)
    {
        Console.Error.WriteLine(
            "usage: FruitMachineLab.IlLampClearPatternBuild <original-a6ls.p1> " +
            "<new-output-directory>");
        return 2;
    }

    string romPath = Path.GetFullPath(args[0]);
    string outputDirectory = Path.GetFullPath(args[1]);
    const string unrepairedFileName = "lamp-clear-unrepaired.p1";
    const string repairedFileName = "lamp-clear-repaired.p1";
    const string mapFileName = "lamp-clear-pattern-source-map.json";
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

    LampPatternBuildResult build = LampPatternWordBuilder.BuildClearPattern(original);

    byte[] unrepairedImage = build.CopyUnrepairedImage();
    byte[] repairedImage = build.CopyOutputImage();
    if (build.Nodes.Count != LampPatternWordBuilder.NodeCount ||
        build.Nodes[5].OperandValue != LampPatternWordBuilder.ClearPatternOperand)
        throw new InvalidDataException(
            "built clear word does not contain the literal pattern-80 operand at 1023");
    if (build.SourceMap.BuildId != build.OutputImageSha256)
        throw new InvalidDataException("source map is not bound to the output SHA256");
    if (build.SourceMap.Nodes.Count != LampPatternWordBuilder.NodeCount ||
        build.SourceMap.InlineOperands.Count != LampPatternWordBuilder.InlineOperandCount)
        throw new InvalidDataException(
            "source map does not contain the eight nodes and four inline operands");
    if (build.SourceMap.Entries.Count != 44)
        throw new InvalidDataException(
            "source map does not contain the 44 reviewed entries");
    if (build.SourceMap.Boundaries.Count != 12)
        throw new InvalidDataException(
            "source map does not contain the twelve reviewed service boundaries");
    if (build.SourceMap.Phases.Count != 43)
        throw new InvalidDataException(
            "source map does not contain the 43 reviewed instruction-boundary phases");
    if (build.IntegrityReport.RepairChangedOffsets.Any(offset =>
            offset < VmIlIntegrity.SumOffset ||
            offset > VmIlIntegrity.RotateSubXorBOffset))
        throw new InvalidDataException(
            "repair changed bytes outside the permitted FFD1-FFD5 field locations");

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
            endInclusive = "1027",
            length = LampPatternWordBuilder.AllocationLength,
            remainingApprovedBytes = LampPatternWordBuilder.RemainingApprovedBytes,
            headerHex = LampPatternWordBuilder.HeaderHex,
            bodyStart = "1012",
            bodyEndExclusive = "1028",
            bodyHex = LampPatternWordBuilder.ClearBodyHex,
            payloadHex = LampPatternWordBuilder.ClearPayloadHex,
            nodeCount = LampPatternWordBuilder.NodeCount,
            wordOperandCount = LampPatternWordBuilder.WordOperandCount,
            byteOperandCount = LampPatternWordBuilder.ByteOperandCount,
            inlineOperandCount = LampPatternWordBuilder.InlineOperandCount,
            inlineOperandAddresses = new[] { "1014", "101A", "1020", "1023" },
            patternOperandAddress = "1023",
            patternOperandHex = "80",
            fullAllocationIsOriginalFF = true,
            bytes1014And101ARemainFF = true,
            only1023DiffersFrom8FPayload = true
        },
        caller = new
        {
            address = "9F14",
            expectedToken = "9ED7",
            replacementToken = "1010",
            successorAddress = "9F16",
            successorToken = "75A9",
            otherCallerBytesPreserved = true,
            outerSavedCursor = "9F16",
            sharedSavedCursor = "1026"
        },
        originalDefinition = new
        {
            header = "9ED7",
            body = "9ED9",
            prefix = LampPatternWordBuilder.OriginalPrefixHex,
            preserved = true
        },
        sharedCall = new
        {
            tokenAddress = "1024",
            token = "9C44",
            callerOperandBytes = 0,
            handler = "9B15",
            handlerIsTokenPlusTwo = false,
            serviceCellAddress = "9C44",
            serviceCellHex = LampPatternWordBuilder.SharedCallCellHex,
            servicePointerAddress = "9C46",
            servicePointerValue = "72BF",
            sharedBody = "9B18",
            sharedBodyHex = LampPatternWordBuilder.SharedBodyHex,
            nextCallerTokenAddress = "1026",
            nextCallerToken = "792F",
            boundary = LampPatternWordBuilder.SharedCallBoundaryText
        },
        integrity = new
        {
            originalFieldsHex = build.IntegrityReport.OriginalStoredFieldsHex,
            repairedFieldsHex = build.IntegrityReport.RepairedStoredFieldsHex,
            repairChangedOffsets = build.RepairChangedOffsets,
            repairChangedCount = build.RepairChangedOffsets.Count,
            algorithmOrder = build.IntegrityReport.AlgorithmOrder,
            status = build.IntegrityReport.Status,
            fieldLocationsPermitted = new[] { "FFD1", "FFD2", "FFD3", "FFD4", "FFD5" },
            valuesForced = false
        },
        staticContract = build.StaticContract,
        predictedLampEffect = new
        {
            classification = LampPatternWordBuilder.StaticPhaseClassification,
            variant = "clear",
            effect = "clear-mask-01-in-four-banks",
            index = LampPatternWordBuilder.GridIndex,
            tableAddress = "72BF",
            logicalId = "78",
            bit = 0,
            maskHex = "01",
            patternHex = "80",
            lowNibble = "00",
            clearForBanks = new[] { 0, 1, 2, 3 },
            otherBitsUnchanged = true,
            observedCharacteriserResponse = "00",
            observedColumn = LampPatternWordBuilder.ObservedResponseColumn,
            columnFormula = LampPatternWordBuilder.ResponseColumnFormula,
            observedFrameAddresses =
                LampPatternWordBuilder.ClearObservedFrameAddresses
                    .Select(address => address.ToString("X4")).ToArray(),
            futureResponseUnknown = true,
            targetColumnDependsOnActual0803Response = true,
            fullResponseByteClaimed = false,
            physicalLampOutputClaimed = false,
            clearAlgebra = "after = before & ~01 for each of the four banks",
            clearAlgebraCoveredBeforeValues = 256,
            mameLayoutCheckedBySupervisor = true,
            mameLayoutBinding =
                "MAME layout checked by supervisor: feature-grid outputs run 64..69, " +
                "72..77, ... 120..125 top-to-bottom; output = 64 + 8*topRow + column; " +
                "72BF index 0 (output 120) is bottom-left START. Physical orientation and " +
                "hardware remain separate.",
            codeNotMappingData = true
        },
        sourceMap = new
        {
            fileName = mapFileName,
            buildId = build.SourceMap.BuildId,
            classification = build.SourceMap.Classification,
            entries = build.SourceMap.Entries.Count,
            nodes = build.SourceMap.Nodes.Count,
            inlineOperands = build.SourceMap.InlineOperands.Count,
            phases = build.SourceMap.Phases.Count,
            boundaries = build.SourceMap.Boundaries.Count,
            caller = build.SourceMap.Caller,
            semantics = build.SourceMap.Semantics,
            staticContract = build.SourceMap.StaticContract
        },
        provenance = build.Provenance,
        limitations = new[]
        {
            "Static compilation only. The new body at 1012-1027, natural boot and gameplay " +
            "were not observed.",
            "Pattern 80 is a static clear variant: for every possible pre-existing frame byte " +
            "the original service clears mask 01 in each of the four banks and leaves all " +
            "other bits unchanged. The observed 0803 response 00 giving column 15 is recorded " +
            "only as a static prediction; a future run must use the response actually read.",
            "Changing frame RAM is not proof of physical lamp output. No visible transition, " +
            "full characteriser response, whole-RAM-unchanged state or MAME run is claimed.",
            "The reused service reads DP-relative 00F1, conditionally writes 00F1/080C, masks " +
            "IRQ/FIRQ around its 0801/0802/0803 access, updates U/S frames and changes A/CC " +
            "net. Natural safety of these effects at the 9F14 caller remains unproved.",
            "M5 remains open; this is one new clear variant plus one caller redirect. No " +
            "general linker/compiler, button, timing or scheduling claim is made."
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
    Console.WriteLine("repair_changed=" + build.RepairChangedOffsets.Count);
    Console.WriteLine("changed_offsets=" + string.Join(',',
        build.ChangedOffsets.Select(offset => $"{offset:X4}")));
    Console.WriteLine("phase_count=" + build.SourceMap.Phases.Count);
    Console.WriteLine("allocation_length=" + LampPatternWordBuilder.AllocationLength);
    Console.WriteLine("remaining_approved_bytes=" +
        LampPatternWordBuilder.RemainingApprovedBytes);
    Console.WriteLine("classification=STATIC_CLEAR_ONLY (no MAME, gameplay or hardware claim)");
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

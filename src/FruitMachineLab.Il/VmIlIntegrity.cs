using System.Security.Cryptography;

namespace FruitMachineLab.Il;

public static class VmIlIntegrity
{
    public const ushort RecordBase = 0xFFD1;
    public const ushort RangeStart = 0x1400;
    public const ushort RangeEnd = 0xFFFF;
    public const byte ErrorCode = 0x12;
    public const byte Gate = 0x00;

    public const ushort SumOffset = 0xFFD1;
    public const ushort XorOffset = 0xFFD2;
    public const ushort RotateAddOffset = 0xFFD3;
    public const ushort RotateSubXorAOffset = 0xFFD4;
    public const ushort RotateSubXorBOffset = 0xFFD5;

    public const string ExpectedOriginalFieldsHex = "3E761E2605";
    public const string ExpectedRecordMetadataHex = "1400FFFF1200";
    public const ushort OuterGateAddress = 0x719B;
    public const byte ExpectedOuterGate = 0x00;

    public const int CheckerCodeStart = 0x66A5;
    public const int CheckerCodeEnd = 0x674F;
    public const int DisabledRecordStart = 0xFFB0;
    public const int DisabledRecordEnd = 0xFFD0;
    public const int ActiveMetadataStart = 0xFFD6;
    public const int ActiveMetadataEnd = 0xFFDB;

    public const int SupportedBodyStart = 0x9ED9;
    public const int SupportedBodyLength = 14;
    public const int SupportedEditOffset = 0x9EDC;
    public const string SupportedUnrepairedSpanHex = "795BFF00787E795BFF807AAF792F";

    public const string AlgorithmOrder =
        "sum_xor (FFD1/FFD2) -> rotate_add (FFD3) -> rotate_sub_xor (FFD4/FFD5); " +
        "each phase reads the fields written by the preceding phase";
    public const string EvidenceSource =
        "evidence/mpu4/maps/rom-integrity.json; docs/recovery/ROM-INTEGRITY-REPAIR-PASS.md; " +
        "tools/Verify-RomIntegrity.ps1; tools/Repair-AddersAwardIntegrity.ps1; " +
        "evidence/mpu4/native/66a5.json and 66db.json";

    public const string RepairedIntegrityStatus =
        "ALGORITHMICALLY REPAIRED active gate-00 integrity fields in the recovered checker order. " +
        "This is not natural boot acceptance, MAME execution evidence or hardware compatibility.";

    private static readonly (int Base, ushort Start, ushort End, byte Error, byte Gate)[]
        ExpectedRecords =
        {
            (0xFFB0, 0x1400, 0x5FFF, 0x15, 0xFF),
            (0xFFBB, 0x1400, 0x7FFF, 0x14, 0xFF),
            (0xFFC6, 0x1400, 0xFFFF, 0x13, 0xFF),
            (RecordBase, RangeStart, RangeEnd, ErrorCode, Gate)
        };

    public static VmIlIntegrityOriginalVerification VerifyOriginal(ReadOnlySpan<byte> image)
    {
        ValidateOriginalIdentity(image);
        ValidateRecordTable(image);

        string stored = ReadFieldsHex(image);
        if (!string.Equals(stored, ExpectedOriginalFieldsHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Original active integrity fields are {stored}; expected {ExpectedOriginalFieldsHex}");

        (int sum, int xor) = SumXor(image);
        int rotateAdd = RotateAdd(image);
        (int rotateSubA, int rotateSubB) = RotateSubXor(image);
        string computed = FormatFields(sum, xor, rotateAdd, rotateSubA, rotateSubB);
        if (!string.Equals(computed, ExpectedOriginalFieldsHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Recomputed original active fields are {computed}; expected {ExpectedOriginalFieldsHex}");

        return new VmIlIntegrityOriginalVerification(
            RecordBase, RangeStart, RangeEnd, ErrorCode, Gate, stored, computed);
    }

    public static VmIlIntegrityResult Repair(
        ReadOnlySpan<byte> originalImage, ReadOnlySpan<byte> unrepairedImage)
    {
        VmIlIntegrityOriginalVerification original = VerifyOriginal(originalImage);
        ValidateUnrepaired(originalImage, unrepairedImage);

        byte[] repaired = unrepairedImage.ToArray();
        (int sum, int xor) = SumXor(repaired);
        repaired[SumOffset] = (byte)sum;
        repaired[XorOffset] = (byte)xor;

        int rotateAdd = RotateAdd(repaired);
        repaired[RotateAddOffset] = (byte)rotateAdd;

        (int rotateSubA, int rotateSubB) = RotateSubXor(repaired);
        repaired[RotateSubXorAOffset] = (byte)rotateSubA;
        repaired[RotateSubXorBOffset] = (byte)rotateSubB;

        string repairedStored = ReadFieldsHex(repaired);
        string expectedRepaired =
            FormatFields(sum, xor, rotateAdd, rotateSubA, rotateSubB);
        if (!string.Equals(repairedStored, expectedRepaired, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Repaired stored fields are {repairedStored}; ordered computation produced {expectedRepaired}");

        (int checkSum, int checkXor) = SumXor(repaired);
        int checkRotateAdd = RotateAdd(repaired);
        (int checkRotateSubA, int checkRotateSubB) = RotateSubXor(repaired);
        string checkFields = FormatFields(
            checkSum, checkXor, checkRotateAdd, checkRotateSubA, checkRotateSubB);
        if (!string.Equals(checkFields, repairedStored, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Repaired image does not verify: stored {repairedStored}, computed {checkFields}");

        EnsureProtectedBytes(originalImage, repaired);

        int[] unrepairedChanged = ChangedOffsets(originalImage, unrepairedImage);
        if (!unrepairedChanged.SequenceEqual(new[] { SupportedEditOffset }))
            throw new InvalidDataException(
                "Unrepaired image diff is not exactly the supported 9ED9 operand edit at 9EDC");
        string span = Convert.ToHexString(
            unrepairedImage.Slice(SupportedBodyStart, SupportedBodyLength));
        if (!string.Equals(span, SupportedUnrepairedSpanHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Unrepaired image does not retain the supported edited span {SupportedUnrepairedSpanHex}");

        int[] repairedChanged = ChangedOffsets(originalImage, repaired);
        int[] expectedRepairedDiff =
            new[] { SupportedEditOffset }.Concat(Enumerable.Range(
                SumOffset, RotateSubXorBOffset - SumOffset + 1)).ToArray();
        if (!repairedChanged.SequenceEqual(expectedRepairedDiff))
            throw new InvalidDataException(
                "Repaired image changes bytes other than 9EDC and the active integrity fields FFD1-FFD5");

        int[] repairChanged = ChangedOffsets(unrepairedImage, repaired);
        int[] expectedRepairDiff = Enumerable.Range(
            SumOffset, RotateSubXorBOffset - SumOffset + 1).ToArray();
        if (!repairChanged.SequenceEqual(expectedRepairDiff))
            throw new InvalidDataException(
                "Repair changed bytes outside the active integrity fields FFD1-FFD5");

        string unrepairedStored = ReadFieldsHex(unrepairedImage);
        if (!string.Equals(unrepairedStored, ExpectedOriginalFieldsHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Unrepaired image fields are {unrepairedStored}; expected the original {ExpectedOriginalFieldsHex}");

        var fields = new[]
        {
            new VmIlIntegrityField(
                "sum", SumOffset, unrepairedImage[SumOffset], repaired[SumOffset],
                "computed first; excludes FFD1-FFD5 and reads no expected field"),
            new VmIlIntegrityField(
                "xor", XorOffset, unrepairedImage[XorOffset], repaired[XorOffset],
                "computed with sum; excludes FFD1-FFD5 and reads no expected field"),
            new VmIlIntegrityField(
                "rotate_add", RotateAddOffset, unrepairedImage[RotateAddOffset],
                repaired[RotateAddOffset],
                "computed after sum/xor; excludes FFD3-FFD5 but reads FFD1-FFD2"),
            new VmIlIntegrityField(
                "rotate_sub_xor_a", RotateSubXorAOffset, unrepairedImage[RotateSubXorAOffset],
                repaired[RotateSubXorAOffset],
                "computed last; excludes FFD4-FFD5 but reads FFD1-FFD3"),
            new VmIlIntegrityField(
                "rotate_sub_xor_b", RotateSubXorBOffset, unrepairedImage[RotateSubXorBOffset],
                repaired[RotateSubXorBOffset],
                "computed with rotate_sub_xor A; excludes FFD4-FFD5 but reads FFD1-FFD3")
        };

        var report = new VmIlIntegrityReport(
            original.RecordBase,
            original.RangeStart,
            original.RangeEnd,
            original.ErrorCode,
            original.Gate,
            original.StoredFieldsHex,
            original.ComputedFieldsHex,
            unrepairedStored,
            repairedStored,
            checkFields,
            fields,
            unrepairedChanged,
            repairedChanged,
            repairChanged,
            AlgorithmOrder,
            RepairedIntegrityStatus,
            EvidenceSource);

        return new VmIlIntegrityResult(
            repaired,
            Sha1(originalImage),
            Sha256(originalImage),
            Sha1(unrepairedImage),
            Sha256(unrepairedImage),
            Sha1(repaired),
            Sha256(repaired),
            report);
    }

    private const int CompositeAllocationStart = 0x1010;
    private const int CompositeAllocationLength = 16;
    private const int CompositeCallerOffset = 0x9F14;
    private const string CompositeReplacementPayloadHex =
        "00F8795BFF80787E795BFF807AAF792F";
    private const string CompositeExpectedCallerHex = "9ED7";
    private const string CompositeReplacementCallerHex = "1010";
    private const string CompositeRepairedFieldsHex = "E93F3C61B5";
    private const string CompositeRepairStatus =
        "ALGORITHMICALLY REPAIRED the reviewed composite extension word and single caller " +
        "token, changing only the active fields FFD1-FFD5 in the recovered checker order. " +
        "This is not natural boot acceptance, MAME execution evidence or hardware compatibility.";

    public static VmIlIntegrityResult RepairComposite(
        ReadOnlySpan<byte> originalImage,
        ReadOnlySpan<byte> unrepairedImage,
        VmIlCompositePatchSpec spec)
    {
        VmIlIntegrityOriginalVerification original = VerifyOriginal(originalImage);
        if (spec is null)
            throw new InvalidDataException("Composite patch specification is missing.");
        if (unrepairedImage.Length != originalImage.Length)
            throw new InvalidDataException(
                $"Unrepaired image length {unrepairedImage.Length} differs from the original " +
                $"{originalImage.Length}");

        byte[] expectedAllocation = spec.ExpectedAllocationBytes?.ToArray() ??
            throw new InvalidDataException("Composite expected allocation bytes are missing.");
        byte[] replacementAllocation = spec.ReplacementAllocationBytes?.ToArray() ??
            throw new InvalidDataException("Composite replacement allocation bytes are missing.");
        byte[] expectedCaller = spec.ExpectedCallerBytes?.ToArray() ??
            throw new InvalidDataException("Composite expected caller bytes are missing.");
        byte[] replacementCaller = spec.ReplacementCallerBytes?.ToArray() ??
            throw new InvalidDataException("Composite replacement caller bytes are missing.");

        if (spec.AllocationStart != CompositeAllocationStart ||
            expectedAllocation.Length != CompositeAllocationLength ||
            replacementAllocation.Length != CompositeAllocationLength)
            throw new InvalidDataException(
                "Composite repair is bounded to the exact 16-byte allocation at 1010-101F.");
        if (expectedAllocation.Any(value => value != 0xFF))
            throw new InvalidDataException(
                "Composite expected allocation bytes must be the original FF contents.");
        if (!string.Equals(Convert.ToHexString(replacementAllocation),
                CompositeReplacementPayloadHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                "Composite replacement allocation is not the reviewed 00F8 header plus " +
                "the certified 9ED9 body.");
        if (spec.CallerOffset != CompositeCallerOffset ||
            expectedCaller.Length != 2 || replacementCaller.Length != 2)
            throw new InvalidDataException(
                "Composite repair is bounded to the exact two-byte caller at 9F14.");
        if (!string.Equals(Convert.ToHexString(expectedCaller),
                CompositeExpectedCallerHex, StringComparison.Ordinal) ||
            !string.Equals(Convert.ToHexString(replacementCaller),
                CompositeReplacementCallerHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                "Composite caller bytes are not the reviewed 9ED7 -> 1010 replacement.");
        if (Overlaps(
                CompositeAllocationStart,
                CompositeAllocationStart + CompositeAllocationLength - 1,
                CompositeCallerOffset, CompositeCallerOffset + 1))
            throw new InvalidDataException(
                "Composite allocation and caller spans overlap.");

        ReadOnlySpan<byte> originalAllocation =
            originalImage.Slice(CompositeAllocationStart, CompositeAllocationLength);
        if (!originalAllocation.SequenceEqual(expectedAllocation))
            throw new InvalidDataException(
                "Original composite allocation at 1010-101F does not match the expected FF bytes.");
        ReadOnlySpan<byte> originalCaller =
            originalImage.Slice(CompositeCallerOffset, 2);
        if (!originalCaller.SequenceEqual(expectedCaller))
            throw new InvalidDataException(
                "Original caller at 9F14 is not the expected 9ED7 token.");
        ReadOnlySpan<byte> unrepairedAllocation =
            unrepairedImage.Slice(CompositeAllocationStart, CompositeAllocationLength);
        if (!unrepairedAllocation.SequenceEqual(replacementAllocation))
            throw new InvalidDataException(
                "Unrepaired composite allocation does not contain the reviewed payload.");
        ReadOnlySpan<byte> unrepairedCaller =
            unrepairedImage.Slice(CompositeCallerOffset, 2);
        if (!unrepairedCaller.SequenceEqual(replacementCaller))
            throw new InvalidDataException(
                "Unrepaired caller at 9F14 is not the reviewed 1010 token.");
        if (!unrepairedImage.Slice(SumOffset, RotateSubXorBOffset - SumOffset + 1)
                .SequenceEqual(originalImage.Slice(
                    SumOffset, RotateSubXorBOffset - SumOffset + 1)))
            throw new InvalidDataException(
                "Unrepaired composite pre-modified the active integrity fields FFD1-FFD5.");

        var expectedChanges = new List<int>();
        for (int index = 0; index < CompositeAllocationLength; index++)
        {
            int offset = CompositeAllocationStart + index;
            if (originalImage[offset] != unrepairedImage[offset])
                expectedChanges.Add(offset);
        }
        for (int index = 0; index < 2; index++)
        {
            int offset = CompositeCallerOffset + index;
            if (originalImage[offset] != unrepairedImage[offset])
                expectedChanges.Add(offset);
        }
        expectedChanges.Sort();
        int[] unrepairedChanged = ChangedOffsets(originalImage, unrepairedImage);
        if (!unrepairedChanged.SequenceEqual(expectedChanges))
            throw new InvalidDataException(
                "Unrepaired composite diff contains unexpected changes outside the " +
                "reviewed allocation and caller spans.");
        if (unrepairedChanged.Length != 16)
            throw new InvalidDataException(
                $"Unrepaired composite diff has {unrepairedChanged.Length} changes; " +
                "the reviewed proposal requires 14 extension and 2 caller changes.");

        EnsureProtectedBytes(originalImage, unrepairedImage);

        string unrepairedStored = ReadFieldsHex(unrepairedImage);
        if (!string.Equals(unrepairedStored, ExpectedOriginalFieldsHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Unrepaired composite fields are {unrepairedStored}; expected the original " +
                $"{ExpectedOriginalFieldsHex}.");

        byte[] repaired = unrepairedImage.ToArray();
        (int sum, int xor) = SumXor(repaired);
        repaired[SumOffset] = (byte)sum;
        repaired[XorOffset] = (byte)xor;
        int rotateAdd = RotateAdd(repaired);
        repaired[RotateAddOffset] = (byte)rotateAdd;
        (int rotateSubA, int rotateSubB) = RotateSubXor(repaired);
        repaired[RotateSubXorAOffset] = (byte)rotateSubA;
        repaired[RotateSubXorBOffset] = (byte)rotateSubB;

        string repairedStored = ReadFieldsHex(repaired);
        string expectedRepaired = FormatFields(
            sum, xor, rotateAdd, rotateSubA, rotateSubB);
        if (!string.Equals(repairedStored, expectedRepaired, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Repaired composite stored fields are {repairedStored}; ordered computation " +
                $"produced {expectedRepaired}.");
        if (!string.Equals(repairedStored, CompositeRepairedFieldsHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Repaired composite fields are {repairedStored}; the reviewed contract " +
                $"requires {CompositeRepairedFieldsHex}.");

        (int checkSum, int checkXor) = SumXor(repaired);
        int checkRotateAdd = RotateAdd(repaired);
        (int checkRotateSubA, int checkRotateSubB) = RotateSubXor(repaired);
        string checkFields = FormatFields(
            checkSum, checkXor, checkRotateAdd, checkRotateSubA, checkRotateSubB);
        if (!string.Equals(checkFields, repairedStored, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Repaired composite image does not verify: stored {repairedStored}, " +
                $"computed {checkFields}.");
        EnsureProtectedBytes(originalImage, repaired);

        int[] fieldOffsets = Enumerable.Range(
            SumOffset, RotateSubXorBOffset - SumOffset + 1).ToArray();
        int[] repairChanged = ChangedOffsets(unrepairedImage, repaired);
        if (!repairChanged.SequenceEqual(fieldOffsets))
            throw new InvalidDataException(
                "Composite repair changed bytes outside the active fields FFD1-FFD5.");
        int[] repairedChanged = ChangedOffsets(originalImage, repaired);
        int[] expectedRepairedDiff = expectedChanges.Concat(fieldOffsets).ToArray();
        if (!repairedChanged.SequenceEqual(expectedRepairedDiff) ||
            repairedChanged.Length != 21)
            throw new InvalidDataException(
                "Repaired composite diff is not exactly the reviewed 21 changed offsets.");

        var fields = new[]
        {
            new VmIlIntegrityField(
                "sum", SumOffset, unrepairedImage[SumOffset], repaired[SumOffset],
                "computed first; excludes FFD1-FFD5 and reads no expected field"),
            new VmIlIntegrityField(
                "xor", XorOffset, unrepairedImage[XorOffset], repaired[XorOffset],
                "computed with sum; excludes FFD1-FFD5 and reads no expected field"),
            new VmIlIntegrityField(
                "rotate_add", RotateAddOffset, unrepairedImage[RotateAddOffset],
                repaired[RotateAddOffset],
                "computed after sum/xor; excludes FFD3-FFD5 but reads FFD1-FFD2"),
            new VmIlIntegrityField(
                "rotate_sub_xor_a", RotateSubXorAOffset, unrepairedImage[RotateSubXorAOffset],
                repaired[RotateSubXorAOffset],
                "computed last; excludes FFD4-FFD5 but reads FFD1-FFD3"),
            new VmIlIntegrityField(
                "rotate_sub_xor_b", RotateSubXorBOffset, unrepairedImage[RotateSubXorBOffset],
                repaired[RotateSubXorBOffset],
                "computed with rotate_sub_xor A; excludes FFD4-FFD5 but reads FFD1-FFD3")
        };

        var report = new VmIlIntegrityReport(
            original.RecordBase,
            original.RangeStart,
            original.RangeEnd,
            original.ErrorCode,
            original.Gate,
            original.StoredFieldsHex,
            original.ComputedFieldsHex,
            unrepairedStored,
            repairedStored,
            checkFields,
            fields,
            unrepairedChanged,
            repairedChanged,
            repairChanged,
            AlgorithmOrder,
            CompositeRepairStatus,
            EvidenceSource);

        return new VmIlIntegrityResult(
            repaired,
            Sha1(originalImage),
            Sha256(originalImage),
            Sha1(unrepairedImage),
            Sha256(unrepairedImage),
            Sha1(repaired),
            Sha256(repaired),
            report);
    }

    internal static VmIlIntegrityComputedFields ComputeForTests(
        ReadOnlySpan<byte> image, bool orderedWrites)
    {
        byte[] working = image.ToArray();
        (int sum, int xor) = SumXor(working);
        if (orderedWrites)
        {
            working[SumOffset] = (byte)sum;
            working[XorOffset] = (byte)xor;
        }
        int rotateAdd = RotateAdd(working);
        if (orderedWrites)
            working[RotateAddOffset] = (byte)rotateAdd;
        (int rotateSubA, int rotateSubB) = RotateSubXor(working);
        return new VmIlIntegrityComputedFields(sum, xor, rotateAdd, rotateSubA, rotateSubB);
    }

    internal static void ValidateRecordTableForTests(ReadOnlySpan<byte> image) =>
        ValidateRecordTable(image);

    internal static string VerifyFieldsForTests(ReadOnlySpan<byte> image)
    {
        string stored = ReadFieldsHex(image);
        (int sum, int xor) = SumXor(image);
        int rotateAdd = RotateAdd(image);
        (int rotateSubA, int rotateSubB) = RotateSubXor(image);
        string computed = FormatFields(sum, xor, rotateAdd, rotateSubA, rotateSubB);
        if (!string.Equals(stored, computed, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Stored integrity fields are {stored}; ordered computation produced {computed}");
        return computed;
    }

    private static void ValidateOriginalIdentity(ReadOnlySpan<byte> image)
    {
        NineEdNineDecoder.ValidateIdentity(
            image,
            NineEdNineDecoder.RequiredRomLength,
            NineEdNineDecoder.RequiredRomSha1,
            NineEdNineDecoder.RequiredRomSha256);
    }

    private static void ValidateRecordTable(ReadOnlySpan<byte> image)
    {
        if (image.Length < 0x10000)
            throw new InvalidDataException("Record table is outside the ROM image");

        if (image[OuterGateAddress] != ExpectedOuterGate)
            throw new InvalidDataException(
                $"Outer gate at {OuterGateAddress:X4} is {image[OuterGateAddress]:X2}; " +
                $"expected {ExpectedOuterGate:X2} (active firmware self-check)");

        foreach (var expected in ExpectedRecords)
        {
            int start = ReadBigEndianWord(image, expected.Base + 5);
            int end = ReadBigEndianWord(image, expected.Base + 7);
            byte error = image[expected.Base + 9];
            byte gate = image[expected.Base + 10];
            if (start != expected.Start || end != expected.End ||
                error != expected.Error || gate != expected.Gate)
                throw new InvalidDataException(
                    $"Unsupported integrity record at {expected.Base:X4}: " +
                    $"start={start:X4} end={end:X4} error={error:X2} gate={gate:X2}");
        }

        for (int index = 0; index < ExpectedRecords.Length - 1; index++)
        {
            int baseAddress = ExpectedRecords[index].Base;
            string expectedFields = new string('F', 10);
            string actualFields = Convert.ToHexString(image.Slice(baseAddress, 5));
            if (!string.Equals(actualFields, expectedFields, StringComparison.Ordinal))
                throw new InvalidDataException(
                    $"Disabled integrity record fields at {baseAddress:X4} are " +
                    $"{actualFields}; expected {expectedFields}");
        }

        string metadata = Convert.ToHexString(
            image.Slice(ActiveMetadataStart, ActiveMetadataEnd - ActiveMetadataStart + 1));
        if (!string.Equals(metadata, ExpectedRecordMetadataHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Active record metadata FFD6-FFDB is {metadata}; " +
                $"expected {ExpectedRecordMetadataHex}");
    }

    private static void ValidateUnrepaired(
        ReadOnlySpan<byte> originalImage, ReadOnlySpan<byte> unrepairedImage)
    {
        if (unrepairedImage.Length != originalImage.Length)
            throw new InvalidDataException(
                $"Unrepaired image length {unrepairedImage.Length} differs from the original " +
                $"{originalImage.Length}");
        if (originalImage[SupportedEditOffset] != 0x80 ||
            unrepairedImage[SupportedEditOffset] != 0x00)
            throw new InvalidDataException(
                "Unrepaired image does not contain the supported 9EDC 80 -> 00 edit");
        EnsureProtectedBytes(originalImage, unrepairedImage);
    }

    private static void EnsureProtectedBytes(
        ReadOnlySpan<byte> originalImage, ReadOnlySpan<byte> candidate)
    {
        EnsureEqual(originalImage, candidate, CheckerCodeStart, CheckerCodeEnd, "checker code");
        EnsureEqual(originalImage, candidate, OuterGateAddress, OuterGateAddress, "outer gate");
        EnsureEqual(originalImage, candidate, DisabledRecordStart, DisabledRecordEnd,
            "disabled integrity records");
        EnsureEqual(originalImage, candidate, ActiveMetadataStart, ActiveMetadataEnd,
            "active record metadata");
    }

    private static void EnsureEqual(
        ReadOnlySpan<byte> originalImage,
        ReadOnlySpan<byte> candidate,
        int start,
        int end,
        string label)
    {
        if (candidate.Length <= end)
            throw new InvalidDataException($"Candidate image is too short to inspect {label}");
        if (!originalImage.Slice(start, end - start + 1)
                .SequenceEqual(candidate.Slice(start, end - start + 1)))
            throw new InvalidDataException(
                $"Protected {label} bytes {start:X4}-{end:X4} differ from the original");
    }

    private static (int Sum, int Xor) SumXor(ReadOnlySpan<byte> image)
    {
        int sum = 0;
        int xor = 0;
        int pointer = RangeStart;
        while (true)
        {
            int value = image[pointer];
            sum = (sum + value) & 0xFF;
            xor ^= value;
            if (pointer == RangeEnd)
                break;
            pointer++;
            if (pointer == SumOffset)
                pointer = 0xFFD6;
        }
        return (sum, xor);
    }

    private static int RotateAdd(ReadOnlySpan<byte> image)
    {
        int a = 0;
        int b = 0;
        int carry = 0;
        int pointer = RangeStart;
        while (true)
        {
            int value = image[pointer];
            int next = (b >> 7) & 1;
            b = ((b << 1) | carry) & 0xFF;
            carry = next;
            int total = a + value + carry;
            a = total & 0xFF;
            carry = (total >> 8) & 1;
            next = b & 1;
            b = ((carry << 7) | (b >> 1)) & 0xFF;
            carry = next;
            if (pointer == RangeEnd)
                break;
            pointer++;
            if (pointer == RotateAddOffset)
                pointer = 0xFFD6;
            carry = pointer < RotateAddOffset ? 1 : 0;
        }
        return a;
    }

    private static (int A, int B) RotateSubXor(ReadOnlySpan<byte> image)
    {
        int a = 0;
        int b = 0;
        int carry = 0;
        int pointer = RangeStart;
        while (true)
        {
            int value = image[pointer];
            int next = (b >> 7) & 1;
            b = (b << 1) & 0xFF;
            carry = next;
            int total = b + carry;
            b = total & 0xFF;
            carry = (total >> 8) & 1;
            total = b - value;
            b = total & 0xFF;
            carry = total < 0 ? 1 : 0;
            int savedB = b;
            b = a;
            for (int index = 0; index < 3; index++)
            {
                carry = b & 1;
                b = ((b >> 1) | (b & 0x80)) & 0xFF;
                a = ((carry << 7) | (a >> 1)) & 0xFF;
            }
            b = savedB;
            a ^= value;
            if (pointer == RangeEnd)
                break;
            pointer++;
            if (pointer == RotateSubXorAOffset)
                pointer = 0xFFD6;
        }
        return (a, b);
    }

    private static bool Overlaps(int firstStart, int firstEnd, int secondStart, int secondEnd) =>
        (long)firstStart <= secondEnd && (long)secondStart <= firstEnd;

    private static int ReadBigEndianWord(ReadOnlySpan<byte> image, int offset)
    {
        if (offset < 0 || offset + 1 >= image.Length)
            throw new InvalidDataException($"Record word at {offset:X4} is outside the ROM image");
        return (image[offset] << 8) | image[offset + 1];
    }

    private static string ReadFieldsHex(ReadOnlySpan<byte> image)
    {
        int length = RotateSubXorBOffset - SumOffset + 1;
        if (image.Length < SumOffset + length)
            throw new InvalidDataException("Integrity fields are outside the ROM image");
        return Convert.ToHexString(image.Slice(SumOffset, length));
    }

    private static string FormatFields(
        int sum, int xor, int rotateAdd, int rotateSubA, int rotateSubB) =>
        $"{sum:X2}{xor:X2}{rotateAdd:X2}{rotateSubA:X2}{rotateSubB:X2}";

    private static int[] ChangedOffsets(
        ReadOnlySpan<byte> before, ReadOnlySpan<byte> after)
    {
        if (before.Length != after.Length)
            throw new InvalidDataException("Image lengths differ");
        var changed = new List<int>();
        for (int offset = 0; offset < before.Length; offset++)
        {
            if (before[offset] != after[offset])
                changed.Add(offset);
        }
        return changed.ToArray();
    }

    private static string Sha1(ReadOnlySpan<byte> image) =>
        Convert.ToHexString(SHA1.HashData(image));

    private static string Sha256(ReadOnlySpan<byte> image) =>
        Convert.ToHexString(SHA256.HashData(image));
}

public sealed record VmIlIntegrityField(
    string Name,
    ushort Offset,
    byte UnrepairedValue,
    byte RepairedValue,
    string Dependency);

public sealed record VmIlIntegrityOriginalVerification(
    ushort RecordBase,
    ushort RangeStart,
    ushort RangeEnd,
    byte ErrorCode,
    byte Gate,
    string StoredFieldsHex,
    string ComputedFieldsHex);

public sealed record VmIlIntegrityReport(
    ushort RecordBase,
    ushort RangeStart,
    ushort RangeEnd,
    byte ErrorCode,
    byte Gate,
    string OriginalStoredFieldsHex,
    string OriginalComputedFieldsHex,
    string UnrepairedStoredFieldsHex,
    string RepairedStoredFieldsHex,
    string RepairedComputedFieldsHex,
    IReadOnlyList<VmIlIntegrityField> Fields,
    int[] UnrepairedChangedOffsets,
    int[] RepairedChangedOffsets,
    int[] RepairChangedOffsets,
    string AlgorithmOrder,
    string Status,
    string EvidenceSource);

public sealed record VmIlIntegrityResult(
    byte[] RepairedImage,
    string OriginalRomSha1,
    string OriginalRomSha256,
    string UnrepairedImageSha1,
    string UnrepairedImageSha256,
    string RepairedImageSha1,
    string RepairedImageSha256,
    VmIlIntegrityReport Report);

public sealed record VmIlIntegrityComputedFields(
    int Sum, int Xor, int RotateAdd, int RotateSubXorA, int RotateSubXorB);

public sealed record VmIlCompositePatchSpec(
    int AllocationStart,
    byte[] ExpectedAllocationBytes,
    byte[] ReplacementAllocationBytes,
    int CallerOffset,
    byte[] ExpectedCallerBytes,
    byte[] ReplacementCallerBytes);

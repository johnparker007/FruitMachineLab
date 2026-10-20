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

    private const int NativePrimitiveAllocationStart = 0x1010;
    private const int NativePrimitiveAllocationLength = 11;
    private const int NativePrimitiveCallerOffset = 0x9F14;
    private const string NativePrimitiveReplacementPayloadHex =
        "1012ECC4C38000EDC40EFC";
    private const string NativePrimitiveExpectedCallerHex = "9ED7";
    private const string NativePrimitiveReplacementCallerHex = "1010";
    private const string NativePrimitiveRepairedFieldsHex = "E93F3C61B5";
    private const string NativePrimitiveRepairStatus =
        "ALGORITHMICALLY REPAIRED the reviewed native-primitive token/handler allocation and " +
        "single caller token, changing only the active fields FFD1-FFD5 in the recovered " +
        "checker order. This is not natural boot acceptance, MAME execution evidence or " +
        "hardware compatibility.";

    public static VmIlIntegrityResult RepairNativePrimitive(
        ReadOnlySpan<byte> originalImage,
        ReadOnlySpan<byte> unrepairedImage,
        VmIlNativePrimitivePatchSpec spec)
    {
        VmIlIntegrityOriginalVerification original = VerifyOriginal(originalImage);
        if (spec is null)
            throw new InvalidDataException("Native-primitive patch specification is missing.");
        if (unrepairedImage.Length != originalImage.Length)
            throw new InvalidDataException(
                $"Unrepaired image length {unrepairedImage.Length} differs from the original " +
                $"{originalImage.Length}");

        byte[] expectedAllocation = spec.ExpectedAllocationBytes?.ToArray() ??
            throw new InvalidDataException(
                "Native-primitive expected allocation bytes are missing.");
        byte[] replacementAllocation = spec.ReplacementAllocationBytes?.ToArray() ??
            throw new InvalidDataException(
                "Native-primitive replacement allocation bytes are missing.");
        byte[] expectedCaller = spec.ExpectedCallerBytes?.ToArray() ??
            throw new InvalidDataException(
                "Native-primitive expected caller bytes are missing.");
        byte[] replacementCaller = spec.ReplacementCallerBytes?.ToArray() ??
            throw new InvalidDataException(
                "Native-primitive replacement caller bytes are missing.");

        if (spec.AllocationStart != NativePrimitiveAllocationStart ||
            expectedAllocation.Length != NativePrimitiveAllocationLength ||
            replacementAllocation.Length != NativePrimitiveAllocationLength)
            throw new InvalidDataException(
                "Native-primitive repair is bounded to the exact 11-byte allocation at " +
                "1010-101A.");
        if (expectedAllocation.Any(value => value != 0xFF))
            throw new InvalidDataException(
                "Native-primitive expected allocation bytes must be the original FF contents.");
        if (!string.Equals(Convert.ToHexString(replacementAllocation),
                NativePrimitiveReplacementPayloadHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                "Native-primitive replacement allocation is not the reviewed 1012 token plus " +
                "LDD/ADDD/STD/JMP handler.");
        if (spec.CallerOffset != NativePrimitiveCallerOffset ||
            expectedCaller.Length != 2 || replacementCaller.Length != 2)
            throw new InvalidDataException(
                "Native-primitive repair is bounded to the exact two-byte caller at 9F14.");
        if (!string.Equals(Convert.ToHexString(expectedCaller),
                NativePrimitiveExpectedCallerHex, StringComparison.Ordinal) ||
            !string.Equals(Convert.ToHexString(replacementCaller),
                NativePrimitiveReplacementCallerHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                "Native-primitive caller bytes are not the reviewed 9ED7 -> 1010 replacement.");
        if (Overlaps(
                NativePrimitiveAllocationStart,
                NativePrimitiveAllocationStart + NativePrimitiveAllocationLength - 1,
                NativePrimitiveCallerOffset, NativePrimitiveCallerOffset + 1))
            throw new InvalidDataException(
                "Native-primitive allocation and caller spans overlap.");

        ReadOnlySpan<byte> originalAllocation =
            originalImage.Slice(NativePrimitiveAllocationStart, NativePrimitiveAllocationLength);
        if (!originalAllocation.SequenceEqual(expectedAllocation))
            throw new InvalidDataException(
                "Original native-primitive allocation at 1010-101A does not match the " +
                "expected FF bytes.");
        ReadOnlySpan<byte> originalCaller =
            originalImage.Slice(NativePrimitiveCallerOffset, 2);
        if (!originalCaller.SequenceEqual(expectedCaller))
            throw new InvalidDataException(
                "Original caller at 9F14 is not the expected 9ED7 token.");
        ReadOnlySpan<byte> unrepairedAllocation =
            unrepairedImage.Slice(NativePrimitiveAllocationStart, NativePrimitiveAllocationLength);
        if (!unrepairedAllocation.SequenceEqual(replacementAllocation))
            throw new InvalidDataException(
                "Unrepaired native-primitive allocation does not contain the reviewed payload.");
        ReadOnlySpan<byte> unrepairedCaller =
            unrepairedImage.Slice(NativePrimitiveCallerOffset, 2);
        if (!unrepairedCaller.SequenceEqual(replacementCaller))
            throw new InvalidDataException(
                "Unrepaired caller at 9F14 is not the reviewed 1010 token.");
        if (!unrepairedImage.Slice(SumOffset, RotateSubXorBOffset - SumOffset + 1)
                .SequenceEqual(originalImage.Slice(
                    SumOffset, RotateSubXorBOffset - SumOffset + 1)))
            throw new InvalidDataException(
                "Unrepaired native primitive pre-modified the active integrity fields " +
                "FFD1-FFD5.");

        var expectedChanges = new List<int>();
        for (int index = 0; index < NativePrimitiveAllocationLength; index++)
        {
            int offset = NativePrimitiveAllocationStart + index;
            if (originalImage[offset] != unrepairedImage[offset])
                expectedChanges.Add(offset);
        }
        for (int index = 0; index < 2; index++)
        {
            int offset = NativePrimitiveCallerOffset + index;
            if (originalImage[offset] != unrepairedImage[offset])
                expectedChanges.Add(offset);
        }
        expectedChanges.Sort();
        int[] unrepairedChanged = ChangedOffsets(originalImage, unrepairedImage);
        if (!unrepairedChanged.SequenceEqual(expectedChanges))
            throw new InvalidDataException(
                "Unrepaired native-primitive diff contains unexpected changes outside the " +
                "reviewed allocation and caller spans.");
        if (unrepairedChanged.Length != 13)
            throw new InvalidDataException(
                $"Unrepaired native-primitive diff has {unrepairedChanged.Length} changes; " +
                "the reviewed proposal requires 11 allocation and 2 caller changes.");

        EnsureProtectedBytes(originalImage, unrepairedImage);
        EnsureNativePrimitiveNeighborhood(originalImage, unrepairedImage);

        string unrepairedStored = ReadFieldsHex(unrepairedImage);
        if (!string.Equals(unrepairedStored, ExpectedOriginalFieldsHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Unrepaired native-primitive fields are {unrepairedStored}; expected the " +
                $"original {ExpectedOriginalFieldsHex}.");

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
                $"Repaired native-primitive stored fields are {repairedStored}; ordered " +
                $"computation produced {expectedRepaired}.");
        if (!string.Equals(
                repairedStored, NativePrimitiveRepairedFieldsHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Repaired native-primitive fields are {repairedStored}; the reviewed contract " +
                $"requires {NativePrimitiveRepairedFieldsHex}.");

        (int checkSum, int checkXor) = SumXor(repaired);
        int checkRotateAdd = RotateAdd(repaired);
        (int checkRotateSubA, int checkRotateSubB) = RotateSubXor(repaired);
        string checkFields = FormatFields(
            checkSum, checkXor, checkRotateAdd, checkRotateSubA, checkRotateSubB);
        if (!string.Equals(checkFields, repairedStored, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Repaired native-primitive image does not verify: stored {repairedStored}, " +
                $"computed {checkFields}.");
        EnsureProtectedBytes(originalImage, repaired);
        EnsureNativePrimitiveNeighborhood(originalImage, repaired);

        int[] fieldOffsets = Enumerable.Range(
            SumOffset, RotateSubXorBOffset - SumOffset + 1).ToArray();
        int[] repairChanged = ChangedOffsets(unrepairedImage, repaired);
        if (!repairChanged.SequenceEqual(fieldOffsets))
            throw new InvalidDataException(
                "Native-primitive repair changed bytes outside the active fields FFD1-FFD5.");
        int[] repairedChanged = ChangedOffsets(originalImage, repaired);
        int[] expectedRepairedDiff = expectedChanges.Concat(fieldOffsets).ToArray();
        if (!repairedChanged.SequenceEqual(expectedRepairedDiff) ||
            repairedChanged.Length != 18)
            throw new InvalidDataException(
                "Repaired native-primitive diff is not exactly the reviewed 18 changed offsets.");

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
                "rotate_sub_xor_a", RotateSubXorAOffset,
                unrepairedImage[RotateSubXorAOffset],
                repaired[RotateSubXorAOffset],
                "computed last; excludes FFD4-FFD5 but reads FFD1-FFD3"),
            new VmIlIntegrityField(
                "rotate_sub_xor_b", RotateSubXorBOffset,
                unrepairedImage[RotateSubXorBOffset],
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
            NativePrimitiveRepairStatus,
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

    private const int LargerReplacementAllocationStart = 0x1010;
    private const int LargerReplacementAllocationLength = 22;
    private const int LargerReplacementCallerOffset = 0x9F14;
    private const string LargerReplacementPayloadHex =
        "00F8795BFF80787E795BFF807AAF795B0001787E792F";
    private const string LargerReplacementExpectedCallerHex = "9ED7";
    private const string LargerReplacementCallerHex = "1010";
    private const string LargerReplacementRepairedFieldsHex = "E93F3C61B5";
    private const string LargerReplacementRepairStatus =
        "ALGORITHMICALLY REPAIRED the reviewed 22-byte larger-replacement allocation and " +
        "single caller token, changing only the active fields FFD1-FFD5 in the recovered " +
        "checker order. This is not natural boot acceptance, MAME execution evidence or " +
        "hardware compatibility.";

    public static VmIlIntegrityResult RepairLargerReplacement(
        ReadOnlySpan<byte> originalImage,
        ReadOnlySpan<byte> unrepairedImage,
        VmIlLargerReplacementPatchSpec spec)
    {
        VmIlIntegrityOriginalVerification original = VerifyOriginal(originalImage);
        if (spec is null)
            throw new InvalidDataException("Larger-replacement patch specification is missing.");
        if (unrepairedImage.Length != originalImage.Length)
            throw new InvalidDataException(
                $"Unrepaired image length {unrepairedImage.Length} differs from the original " +
                $"{originalImage.Length}");

        byte[] expectedAllocation = spec.ExpectedAllocationBytes?.ToArray() ??
            throw new InvalidDataException(
                "Larger-replacement expected allocation bytes are missing.");
        byte[] replacementAllocation = spec.ReplacementAllocationBytes?.ToArray() ??
            throw new InvalidDataException(
                "Larger-replacement replacement allocation bytes are missing.");
        byte[] expectedCaller = spec.ExpectedCallerBytes?.ToArray() ??
            throw new InvalidDataException(
                "Larger-replacement expected caller bytes are missing.");
        byte[] replacementCaller = spec.ReplacementCallerBytes?.ToArray() ??
            throw new InvalidDataException(
                "Larger-replacement replacement caller bytes are missing.");

        if (spec.AllocationStart != LargerReplacementAllocationStart ||
            expectedAllocation.Length != LargerReplacementAllocationLength ||
            replacementAllocation.Length != LargerReplacementAllocationLength)
            throw new InvalidDataException(
                "Larger-replacement repair is bounded to the exact 22-byte allocation at " +
                "1010-1025.");
        if (expectedAllocation.Any(value => value != 0xFF))
            throw new InvalidDataException(
                "Larger-replacement expected allocation bytes must be the original FF contents.");
        if (!string.Equals(Convert.ToHexString(replacementAllocation),
                LargerReplacementPayloadHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                "Larger-replacement replacement allocation is not the reviewed corrected " +
                "00F8 header plus 20-byte body.");
        if (Overlaps(
                LargerReplacementAllocationStart,
                LargerReplacementAllocationStart + LargerReplacementAllocationLength - 1,
                spec.CallerOffset, spec.CallerOffset + 1))
            throw new InvalidDataException(
                "Larger-replacement allocation and caller spans overlap.");
        if (spec.CallerOffset != LargerReplacementCallerOffset ||
            expectedCaller.Length != 2 || replacementCaller.Length != 2)
            throw new InvalidDataException(
                "Larger-replacement repair is bounded to the exact two-byte caller at 9F14.");
        if (!string.Equals(Convert.ToHexString(expectedCaller),
                LargerReplacementExpectedCallerHex, StringComparison.Ordinal) ||
            !string.Equals(Convert.ToHexString(replacementCaller),
                LargerReplacementCallerHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                "Larger-replacement caller bytes are not the reviewed 9ED7 -> 1010 replacement.");
        ReadOnlySpan<byte> originalAllocation =
            originalImage.Slice(
                LargerReplacementAllocationStart, LargerReplacementAllocationLength);
        if (!originalAllocation.SequenceEqual(expectedAllocation))
            throw new InvalidDataException(
                "Original larger-replacement allocation at 1010-1025 does not match the " +
                "expected FF bytes.");
        ReadOnlySpan<byte> originalCaller =
            originalImage.Slice(LargerReplacementCallerOffset, 2);
        if (!originalCaller.SequenceEqual(expectedCaller))
            throw new InvalidDataException(
                "Original caller at 9F14 is not the expected 9ED7 token.");
        ReadOnlySpan<byte> unrepairedAllocation =
            unrepairedImage.Slice(
                LargerReplacementAllocationStart, LargerReplacementAllocationLength);
        if (!unrepairedAllocation.SequenceEqual(replacementAllocation))
            throw new InvalidDataException(
                "Unrepaired larger-replacement allocation does not contain the reviewed " +
                "corrected payload.");
        ReadOnlySpan<byte> unrepairedCaller =
            unrepairedImage.Slice(LargerReplacementCallerOffset, 2);
        if (!unrepairedCaller.SequenceEqual(replacementCaller))
            throw new InvalidDataException(
                "Unrepaired caller at 9F14 is not the reviewed 1010 token.");
        if (!unrepairedImage.Slice(SumOffset, RotateSubXorBOffset - SumOffset + 1)
                .SequenceEqual(originalImage.Slice(
                    SumOffset, RotateSubXorBOffset - SumOffset + 1)))
            throw new InvalidDataException(
                "Unrepaired larger replacement pre-modified the active integrity fields " +
                "FFD1-FFD5.");

        var expectedChanges = new List<int>();
        for (int index = 0; index < LargerReplacementAllocationLength; index++)
        {
            int offset = LargerReplacementAllocationStart + index;
            if (originalImage[offset] != unrepairedImage[offset])
                expectedChanges.Add(offset);
        }
        for (int index = 0; index < 2; index++)
        {
            int offset = LargerReplacementCallerOffset + index;
            if (originalImage[offset] != unrepairedImage[offset])
                expectedChanges.Add(offset);
        }
        expectedChanges.Sort();
        int[] unrepairedChanged = ChangedOffsets(originalImage, unrepairedImage);
        if (!unrepairedChanged.SequenceEqual(expectedChanges))
            throw new InvalidDataException(
                "Unrepaired larger-replacement diff contains unexpected changes outside the " +
                "reviewed allocation and caller spans.");
        if (unrepairedChanged.Length != 22)
            throw new InvalidDataException(
                $"Unrepaired larger-replacement diff has {unrepairedChanged.Length} changes; " +
                "the reviewed contract requires 20 extension and 2 caller changes.");

        EnsureProtectedBytes(originalImage, unrepairedImage);
        EnsureLargerReplacementNeighborhood(originalImage, unrepairedImage);

        string unrepairedStored = ReadFieldsHex(unrepairedImage);
        if (!string.Equals(unrepairedStored, ExpectedOriginalFieldsHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Unrepaired larger-replacement fields are {unrepairedStored}; expected the " +
                $"original {ExpectedOriginalFieldsHex}.");

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
                $"Repaired larger-replacement stored fields are {repairedStored}; ordered " +
                $"computation produced {expectedRepaired}.");
        if (!string.Equals(
                repairedStored, LargerReplacementRepairedFieldsHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Repaired larger-replacement fields are {repairedStored}; the reviewed " +
                $"contract requires {LargerReplacementRepairedFieldsHex}.");

        (int checkSum, int checkXor) = SumXor(repaired);
        int checkRotateAdd = RotateAdd(repaired);
        (int checkRotateSubA, int checkRotateSubB) = RotateSubXor(repaired);
        string checkFields = FormatFields(
            checkSum, checkXor, checkRotateAdd, checkRotateSubA, checkRotateSubB);
        if (!string.Equals(checkFields, repairedStored, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Repaired larger-replacement image does not verify: stored {repairedStored}, " +
                $"computed {checkFields}.");
        EnsureProtectedBytes(originalImage, repaired);
        EnsureLargerReplacementNeighborhood(originalImage, repaired);

        int[] fieldOffsets = Enumerable.Range(
            SumOffset, RotateSubXorBOffset - SumOffset + 1).ToArray();
        int[] repairChanged = ChangedOffsets(unrepairedImage, repaired);
        if (!repairChanged.SequenceEqual(fieldOffsets))
            throw new InvalidDataException(
                "Larger-replacement repair changed bytes outside the active fields FFD1-FFD5.");
        int[] repairedChanged = ChangedOffsets(originalImage, repaired);
        int[] expectedRepairedDiff = expectedChanges.Concat(fieldOffsets).ToArray();
        if (!repairedChanged.SequenceEqual(expectedRepairedDiff) ||
            repairedChanged.Length != 27)
            throw new InvalidDataException(
                "Repaired larger-replacement diff is not exactly the reviewed 27 changed " +
                "offsets.");

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
                "rotate_sub_xor_a", RotateSubXorAOffset,
                unrepairedImage[RotateSubXorAOffset],
                repaired[RotateSubXorAOffset],
                "computed last; excludes FFD4-FFD5 but reads FFD1-FFD3"),
            new VmIlIntegrityField(
                "rotate_sub_xor_b", RotateSubXorBOffset,
                unrepairedImage[RotateSubXorBOffset],
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
            LargerReplacementRepairStatus,
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

    private const int LampPatternAllocationStart = 0x1010;
    private const int LampPatternAllocationLength = 24;
    private const int LampPatternCallerOffset = 0x9F14;
    private const string LampPatternPayloadHex =
        "00F8795BFF80787E795BFF807AAF79630079638F9C44792F";
    private const string LampPatternExpectedCallerHex = "9ED7";
    private const string LampPatternCallerHex = "1010";
    private const string LampPatternRepairedFieldsHex = "E93F3C61B5";
    private const string LampPatternRepairStatus =
        "ALGORITHMICALLY REPAIRED the reviewed 24-byte lamp-pattern allocation and single " +
        "caller token, changing only the active fields FFD1-FFD5 in the recovered checker " +
        "order. This is not natural boot acceptance, MAME execution evidence or hardware " +
        "compatibility.";

    public static VmIlIntegrityResult RepairLampPattern(
        ReadOnlySpan<byte> originalImage,
        ReadOnlySpan<byte> unrepairedImage,
        VmIlLampPatternPatchSpec spec)
    {
        VmIlIntegrityOriginalVerification original = VerifyOriginal(originalImage);
        if (spec is null)
            throw new InvalidDataException("Lamp-pattern patch specification is missing.");
        if (unrepairedImage.Length != originalImage.Length)
            throw new InvalidDataException(
                $"Unrepaired image length {unrepairedImage.Length} differs from the original " +
                $"{originalImage.Length}");

        byte[] expectedAllocation = spec.ExpectedAllocationBytes?.ToArray() ??
            throw new InvalidDataException(
                "Lamp-pattern expected allocation bytes are missing.");
        byte[] replacementAllocation = spec.ReplacementAllocationBytes?.ToArray() ??
            throw new InvalidDataException(
                "Lamp-pattern replacement allocation bytes are missing.");
        byte[] expectedCaller = spec.ExpectedCallerBytes?.ToArray() ??
            throw new InvalidDataException(
                "Lamp-pattern expected caller bytes are missing.");
        byte[] replacementCaller = spec.ReplacementCallerBytes?.ToArray() ??
            throw new InvalidDataException(
                "Lamp-pattern replacement caller bytes are missing.");

        if (spec.AllocationStart != LampPatternAllocationStart ||
            expectedAllocation.Length != LampPatternAllocationLength ||
            replacementAllocation.Length != LampPatternAllocationLength)
            throw new InvalidDataException(
                "Lamp-pattern repair is bounded to the exact 24-byte allocation at " +
                "1010-1027.");
        if (expectedAllocation.Any(value => value != 0xFF))
            throw new InvalidDataException(
                "Lamp-pattern expected allocation bytes must be the original FF contents.");
        if (!string.Equals(Convert.ToHexString(replacementAllocation),
                LampPatternPayloadHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                "Lamp-pattern replacement allocation is not the reviewed 00F8 header plus " +
                "22-byte body.");
        if (Overlaps(
                LampPatternAllocationStart,
                LampPatternAllocationStart + LampPatternAllocationLength - 1,
                spec.CallerOffset, spec.CallerOffset + 1))
            throw new InvalidDataException(
                "Lamp-pattern allocation and caller spans overlap.");
        if (spec.CallerOffset != LampPatternCallerOffset ||
            expectedCaller.Length != 2 || replacementCaller.Length != 2)
            throw new InvalidDataException(
                "Lamp-pattern repair is bounded to the exact two-byte caller at 9F14.");
        if (!string.Equals(Convert.ToHexString(expectedCaller),
                LampPatternExpectedCallerHex, StringComparison.Ordinal) ||
            !string.Equals(Convert.ToHexString(replacementCaller),
                LampPatternCallerHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                "Lamp-pattern caller bytes are not the reviewed 9ED7 -> 1010 replacement.");

        ReadOnlySpan<byte> originalAllocation =
            originalImage.Slice(LampPatternAllocationStart, LampPatternAllocationLength);
        if (!originalAllocation.SequenceEqual(expectedAllocation))
            throw new InvalidDataException(
                "Original lamp-pattern allocation at 1010-1027 does not match the expected " +
                "FF bytes.");
        ReadOnlySpan<byte> originalCaller =
            originalImage.Slice(LampPatternCallerOffset, 2);
        if (!originalCaller.SequenceEqual(expectedCaller))
            throw new InvalidDataException(
                "Original caller at 9F14 is not the expected 9ED7 token.");
        ReadOnlySpan<byte> unrepairedAllocation =
            unrepairedImage.Slice(LampPatternAllocationStart, LampPatternAllocationLength);
        if (!unrepairedAllocation.SequenceEqual(replacementAllocation))
            throw new InvalidDataException(
                "Unrepaired lamp-pattern allocation does not contain the reviewed payload.");
        ReadOnlySpan<byte> unrepairedCaller =
            unrepairedImage.Slice(LampPatternCallerOffset, 2);
        if (!unrepairedCaller.SequenceEqual(replacementCaller))
            throw new InvalidDataException(
                "Unrepaired caller at 9F14 is not the reviewed 1010 token.");
        if (!unrepairedImage.Slice(SumOffset, RotateSubXorBOffset - SumOffset + 1)
                .SequenceEqual(originalImage.Slice(
                    SumOffset, RotateSubXorBOffset - SumOffset + 1)))
            throw new InvalidDataException(
                "Unrepaired lamp-pattern word pre-modified the active integrity fields " +
                "FFD1-FFD5.");

        var expectedChanges = new List<int>();
        for (int index = 0; index < LampPatternAllocationLength; index++)
        {
            int offset = LampPatternAllocationStart + index;
            if (originalImage[offset] != unrepairedImage[offset])
                expectedChanges.Add(offset);
        }
        for (int index = 0; index < 2; index++)
        {
            int offset = LampPatternCallerOffset + index;
            if (originalImage[offset] != unrepairedImage[offset])
                expectedChanges.Add(offset);
        }
        expectedChanges.Sort();
        int[] unrepairedChanged = ChangedOffsets(originalImage, unrepairedImage);
        if (!unrepairedChanged.SequenceEqual(expectedChanges))
            throw new InvalidDataException(
                "Unrepaired lamp-pattern diff contains unexpected changes outside the " +
                "reviewed allocation and caller spans.");
        if (unrepairedChanged.Length != 24)
            throw new InvalidDataException(
                $"Unrepaired lamp-pattern diff has {unrepairedChanged.Length} changes; " +
                "the reviewed contract requires 22 extension and 2 caller changes.");

        EnsureProtectedBytes(originalImage, unrepairedImage);
        EnsureLampPatternNeighborhood(originalImage, unrepairedImage);

        string unrepairedStored = ReadFieldsHex(unrepairedImage);
        if (!string.Equals(unrepairedStored, ExpectedOriginalFieldsHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Unrepaired lamp-pattern fields are {unrepairedStored}; expected the " +
                $"original {ExpectedOriginalFieldsHex}.");

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
                $"Repaired lamp-pattern stored fields are {repairedStored}; ordered " +
                $"computation produced {expectedRepaired}.");
        if (!string.Equals(
                repairedStored, LampPatternRepairedFieldsHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Repaired lamp-pattern fields are {repairedStored}; the reviewed contract " +
                $"requires {LampPatternRepairedFieldsHex}.");

        (int checkSum, int checkXor) = SumXor(repaired);
        int checkRotateAdd = RotateAdd(repaired);
        (int checkRotateSubA, int checkRotateSubB) = RotateSubXor(repaired);
        string checkFields = FormatFields(
            checkSum, checkXor, checkRotateAdd, checkRotateSubA, checkRotateSubB);
        if (!string.Equals(checkFields, repairedStored, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Repaired lamp-pattern image does not verify: stored {repairedStored}, " +
                $"computed {checkFields}.");
        EnsureProtectedBytes(originalImage, repaired);
        EnsureLampPatternNeighborhood(originalImage, repaired);

        int[] fieldOffsets = Enumerable.Range(
            SumOffset, RotateSubXorBOffset - SumOffset + 1).ToArray();
        int[] repairChanged = ChangedOffsets(unrepairedImage, repaired);
        if (!repairChanged.SequenceEqual(fieldOffsets))
            throw new InvalidDataException(
                "Lamp-pattern repair changed bytes outside the active fields FFD1-FFD5.");
        int[] repairedChanged = ChangedOffsets(originalImage, repaired);
        int[] expectedRepairedDiff = expectedChanges.Concat(fieldOffsets).ToArray();
        if (!repairedChanged.SequenceEqual(expectedRepairedDiff) ||
            repairedChanged.Length != 29)
            throw new InvalidDataException(
                "Repaired lamp-pattern diff is not exactly the reviewed 29 changed offsets.");

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
                "rotate_sub_xor_a", RotateSubXorAOffset,
                unrepairedImage[RotateSubXorAOffset],
                repaired[RotateSubXorAOffset],
                "computed last; excludes FFD4-FFD5 but reads FFD1-FFD3"),
            new VmIlIntegrityField(
                "rotate_sub_xor_b", RotateSubXorBOffset,
                unrepairedImage[RotateSubXorBOffset],
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
            LampPatternRepairStatus,
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

    private const string LampClearPatternPayloadHex =
        "00F8795BFF80787E795BFF807AAF7963007963809C44792F";
    private const string LampClearPatternRepairStatus =
        "ALGORITHMICALLY REPAIRED the reviewed 24-byte lamp-clear allocation and single " +
        "caller token, changing only the active field locations FFD1-FFD5 in the recovered " +
        "checker order. The expected diff was derived from the literal clear payload, the " +
        "caller redirect and the independently computed fields; no field value or change " +
        "count was forced. This is not natural boot acceptance, MAME execution evidence or " +
        "hardware compatibility.";

    public static VmIlIntegrityResult RepairLampClearPattern(
        ReadOnlySpan<byte> originalImage,
        ReadOnlySpan<byte> unrepairedImage,
        VmIlLampPatternPatchSpec spec)
    {
        VmIlIntegrityOriginalVerification original = VerifyOriginal(originalImage);
        if (spec is null)
            throw new InvalidDataException("Lamp-clear patch specification is missing.");
        if (unrepairedImage.Length != originalImage.Length)
            throw new InvalidDataException(
                $"Unrepaired image length {unrepairedImage.Length} differs from the original " +
                $"{originalImage.Length}");

        byte[] expectedAllocation = spec.ExpectedAllocationBytes?.ToArray() ??
            throw new InvalidDataException(
                "Lamp-clear expected allocation bytes are missing.");
        byte[] replacementAllocation = spec.ReplacementAllocationBytes?.ToArray() ??
            throw new InvalidDataException(
                "Lamp-clear replacement allocation bytes are missing.");
        byte[] expectedCaller = spec.ExpectedCallerBytes?.ToArray() ??
            throw new InvalidDataException(
                "Lamp-clear expected caller bytes are missing.");
        byte[] replacementCaller = spec.ReplacementCallerBytes?.ToArray() ??
            throw new InvalidDataException(
                "Lamp-clear replacement caller bytes are missing.");

        if (spec.AllocationStart != LampPatternAllocationStart ||
            expectedAllocation.Length != LampPatternAllocationLength ||
            replacementAllocation.Length != LampPatternAllocationLength)
            throw new InvalidDataException(
                "Lamp-clear repair is bounded to the exact 24-byte allocation at 1010-1027.");
        if (expectedAllocation.Any(value => value != 0xFF))
            throw new InvalidDataException(
                "Lamp-clear expected allocation bytes must be the original FF contents.");
        if (!string.Equals(Convert.ToHexString(replacementAllocation),
                LampClearPatternPayloadHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                "Lamp-clear replacement allocation is not the literal 00F8 header plus " +
                "22-byte pattern-80 body.");
        if (Overlaps(
                LampPatternAllocationStart,
                LampPatternAllocationStart + LampPatternAllocationLength - 1,
                spec.CallerOffset, spec.CallerOffset + 1))
            throw new InvalidDataException(
                "Lamp-clear allocation and caller spans overlap.");
        if (spec.CallerOffset != LampPatternCallerOffset ||
            expectedCaller.Length != 2 || replacementCaller.Length != 2)
            throw new InvalidDataException(
                "Lamp-clear repair is bounded to the exact two-byte caller at 9F14.");
        if (!string.Equals(Convert.ToHexString(expectedCaller),
                LampPatternExpectedCallerHex, StringComparison.Ordinal) ||
            !string.Equals(Convert.ToHexString(replacementCaller),
                LampPatternCallerHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                "Lamp-clear caller bytes are not the reviewed 9ED7 -> 1010 replacement.");

        ReadOnlySpan<byte> originalAllocation =
            originalImage.Slice(LampPatternAllocationStart, LampPatternAllocationLength);
        if (!originalAllocation.SequenceEqual(expectedAllocation))
            throw new InvalidDataException(
                "Original lamp-clear allocation at 1010-1027 does not match the expected " +
                "FF bytes.");
        ReadOnlySpan<byte> originalCaller =
            originalImage.Slice(LampPatternCallerOffset, 2);
        if (!originalCaller.SequenceEqual(expectedCaller))
            throw new InvalidDataException(
                "Original caller at 9F14 is not the expected 9ED7 token.");
        ReadOnlySpan<byte> unrepairedAllocation =
            unrepairedImage.Slice(LampPatternAllocationStart, LampPatternAllocationLength);
        if (!unrepairedAllocation.SequenceEqual(replacementAllocation))
            throw new InvalidDataException(
                "Unrepaired lamp-clear allocation does not contain the literal pattern-80 " +
                "payload.");
        ReadOnlySpan<byte> unrepairedCaller =
            unrepairedImage.Slice(LampPatternCallerOffset, 2);
        if (!unrepairedCaller.SequenceEqual(replacementCaller))
            throw new InvalidDataException(
                "Unrepaired caller at 9F14 is not the reviewed 1010 token.");
        if (!unrepairedImage.Slice(SumOffset, RotateSubXorBOffset - SumOffset + 1)
                .SequenceEqual(originalImage.Slice(
                    SumOffset, RotateSubXorBOffset - SumOffset + 1)))
            throw new InvalidDataException(
                "Unrepaired lamp-clear word pre-modified the active integrity fields " +
                "FFD1-FFD5.");

        var expectedChanges = new List<int>();
        for (int index = 0; index < LampPatternAllocationLength; index++)
        {
            int offset = LampPatternAllocationStart + index;
            if (originalImage[offset] != unrepairedImage[offset])
                expectedChanges.Add(offset);
        }
        for (int index = 0; index < 2; index++)
        {
            int offset = LampPatternCallerOffset + index;
            if (originalImage[offset] != unrepairedImage[offset])
                expectedChanges.Add(offset);
        }
        expectedChanges.Sort();
        int[] unrepairedChanged = ChangedOffsets(originalImage, unrepairedImage);
        if (!unrepairedChanged.SequenceEqual(expectedChanges))
            throw new InvalidDataException(
                "Unrepaired lamp-clear diff contains unexpected changes outside the literal " +
                "allocation and caller spans.");

        EnsureProtectedBytes(originalImage, unrepairedImage);
        EnsureLampPatternNeighborhood(originalImage, unrepairedImage);

        string unrepairedStored = ReadFieldsHex(unrepairedImage);
        if (!string.Equals(unrepairedStored, ExpectedOriginalFieldsHex, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Unrepaired lamp-clear fields are {unrepairedStored}; expected the " +
                $"original {ExpectedOriginalFieldsHex}.");

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
                $"Repaired lamp-clear stored fields are {repairedStored}; ordered " +
                $"computation produced {expectedRepaired}.");

        (int checkSum, int checkXor) = SumXor(repaired);
        int checkRotateAdd = RotateAdd(repaired);
        (int checkRotateSubA, int checkRotateSubB) = RotateSubXor(repaired);
        string checkFields = FormatFields(
            checkSum, checkXor, checkRotateAdd, checkRotateSubA, checkRotateSubB);
        if (!string.Equals(checkFields, repairedStored, StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Repaired lamp-clear image does not verify: stored {repairedStored}, " +
                $"computed {checkFields}.");
        EnsureProtectedBytes(originalImage, repaired);
        EnsureLampPatternNeighborhood(originalImage, repaired);

        int[] fieldOffsets = Enumerable.Range(
            SumOffset, RotateSubXorBOffset - SumOffset + 1).ToArray();
        byte[] unrepairedSnapshot = unrepairedImage.ToArray();
        int[] repairChanged = ChangedOffsets(unrepairedImage, repaired);
        if (repairChanged.Any(offset => !fieldOffsets.Contains(offset)))
            throw new InvalidDataException(
                "Lamp-clear repair changed bytes outside the permitted field locations " +
                "FFD1-FFD5.");
        int[] expectedRepairChanges = fieldOffsets
            .Where(offset => unrepairedSnapshot[offset] != repaired[offset])
            .ToArray();
        if (!repairChanged.SequenceEqual(expectedRepairChanges))
            throw new InvalidDataException(
                "Lamp-clear repair diff does not equal the independently computed field " +
                "changes.");
        int[] repairedChanged = ChangedOffsets(originalImage, repaired);
        int[] expectedRepairedDiff = expectedChanges
            .Concat(expectedRepairChanges)
            .OrderBy(offset => offset)
            .ToArray();
        if (!repairedChanged.SequenceEqual(expectedRepairedDiff))
            throw new InvalidDataException(
                "Repaired lamp-clear diff is not exactly the literal patch plus the " +
                "independent field changes.");

        var fields = fieldOffsets.Select(offset =>
            new VmIlIntegrityField(
                offset switch
                {
                    SumOffset => "sum",
                    XorOffset => "xor",
                    RotateAddOffset => "rotate_add",
                    RotateSubXorAOffset => "rotate_sub_xor_a",
                    _ => "rotate_sub_xor_b"
                },
                (ushort)offset,
                unrepairedSnapshot[offset],
                repaired[offset],
                "computed in the recovered ordered checker sequence; only FFD1-FFD5 may " +
                "change")).ToArray();

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
            LampClearPatternRepairStatus,
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

    private static void EnsureLampPatternNeighborhood(
        ReadOnlySpan<byte> originalImage, ReadOnlySpan<byte> candidate)
    {
        EnsureEqual(originalImage, candidate, 0x1000, 0x100F, "left guard");
        EnsureEqual(originalImage, candidate, 0x1000, 0x1003, "protected cells");
        EnsureEqual(originalImage, candidate, 0x13F0, 0x13FF, "right guard");
        EnsureEqual(originalImage, candidate, 0x1400, 0x1407, "integrity neighbour");
        EnsureEqual(originalImage, candidate, 0x9ED7, 0x9EE6,
            "original 9ED7 header and 9ED9 body");
        EnsureEqual(originalImage, candidate, 0x1028, 0x13EF,
            "unallocated extension bytes");
        EnsureEqual(originalImage, candidate, 0x719B, 0x719B, "outer gate");
        EnsureEqual(originalImage, candidate, 0x7927, 0x792E,
            "runtime dispatch template");
        EnsureEqual(originalImage, candidate, 0x7963, 0x796B,
            "byte literal cell/handler");
        EnsureEqual(originalImage, candidate, 0x796E, 0x7978,
            "shared-body trampoline");
        EnsureEqual(originalImage, candidate, 0x8050, 0x8053, "bridge cell");
        EnsureEqual(originalImage, candidate, 0x7791, 0x77A3, "bridge entry");
        EnsureEqual(originalImage, candidate, 0x777A, 0x778C,
            "bridge continuation");
        EnsureEqual(originalImage, candidate, 0x9B15, 0x9B25, "shared service");
        EnsureEqual(originalImage, candidate, 0x9C44, 0x9C47,
            "shared service cell");
        EnsureEqual(originalImage, candidate, 0x49C5, 0x4A24,
            "native lamp service");
        EnsureEqual(originalImage, candidate, 0x72BF, 0x72EE, "lamp table");
        EnsureEqual(originalImage, candidate, 0x9F10, 0x9F13,
            "caller definition header/body prefix");
        EnsureEqual(originalImage, candidate, 0x9F16, 0x9F17,
            "caller successor token");
        EnsureEqual(originalImage, candidate, 0x9F18, 0x9F1D,
            "caller bytes after the successor");
        EnsureEqual(originalImage, candidate, 0x9F3B, 0x9F40,
            "parent caller context");
    }

    private static void EnsureLargerReplacementNeighborhood(
        ReadOnlySpan<byte> originalImage, ReadOnlySpan<byte> candidate)
    {
        EnsureEqual(originalImage, candidate, 0x1000, 0x100F, "left guard");
        EnsureEqual(originalImage, candidate, 0x1000, 0x1003, "protected cells");
        EnsureEqual(originalImage, candidate, 0x13F0, 0x13FF, "right guard");
        EnsureEqual(originalImage, candidate, 0x1400, 0x1407, "integrity neighbour");
        EnsureEqual(originalImage, candidate, 0x9ED7, 0x9EE6,
            "original 9ED7 header and 9ED9 body");
        EnsureEqual(originalImage, candidate, 0x1026, 0x13EF,
            "unallocated extension bytes");
        EnsureEqual(originalImage, candidate, 0x719B, 0x719B, "outer gate");
        EnsureEqual(originalImage, candidate, 0x7927, 0x792E,
            "runtime dispatch template");
        EnsureEqual(originalImage, candidate, 0x9F10, 0x9F13,
            "caller definition header/body prefix");
        EnsureEqual(originalImage, candidate, 0x9F16, 0x9F17,
            "caller successor token");
        EnsureEqual(originalImage, candidate, 0x9F18, 0x9F1D,
            "caller bytes after the successor");
        EnsureEqual(originalImage, candidate, 0x9F3B, 0x9F40,
            "parent caller context");
    }

    private static void EnsureNativePrimitiveNeighborhood(
        ReadOnlySpan<byte> originalImage, ReadOnlySpan<byte> candidate)
    {
        EnsureEqual(originalImage, candidate, 0x1000, 0x100F, "left guard");
        EnsureEqual(originalImage, candidate, 0x1000, 0x1003, "protected cells");
        EnsureEqual(originalImage, candidate, 0x13F0, 0x13FF, "right guard");
        EnsureEqual(originalImage, candidate, 0x1400, 0x1407, "integrity neighbour");
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

public sealed record VmIlNativePrimitivePatchSpec(
    int AllocationStart,
    byte[] ExpectedAllocationBytes,
    byte[] ReplacementAllocationBytes,
    int CallerOffset,
    byte[] ExpectedCallerBytes,
    byte[] ReplacementCallerBytes);

public sealed record VmIlLargerReplacementPatchSpec(
    int AllocationStart,
    byte[] ExpectedAllocationBytes,
    byte[] ReplacementAllocationBytes,
    int CallerOffset,
    byte[] ExpectedCallerBytes,
    byte[] ReplacementCallerBytes);

public sealed record VmIlLampPatternPatchSpec(
    int AllocationStart,
    byte[] ExpectedAllocationBytes,
    byte[] ReplacementAllocationBytes,
    int CallerOffset,
    byte[] ExpectedCallerBytes,
    byte[] ReplacementCallerBytes);

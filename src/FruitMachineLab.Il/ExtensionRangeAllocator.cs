using System.Collections.ObjectModel;

namespace FruitMachineLab.Il;

public sealed record ExtensionRangeGuard(int Start, int End, byte ExpectedFill)
{
    public int Length => checked(End - Start + 1);
}

public sealed record ExtensionRangeApproval(
    bool IsApproved,
    int RomLength,
    string RomSha1,
    string RomSha256,
    int CpuStart,
    int CpuEnd,
    int LeftGuardStart,
    int LeftGuardEnd,
    int RightGuardStart,
    int RightGuardEnd,
    int ProtectedStart,
    int ProtectedEnd,
    int IntegrityStart,
    bool Bank0Only)
{
    public static ExtensionRangeApproval Approved { get; } = new(
        true,
        ExtensionRangeAllocator.RequiredRomLength,
        ExtensionRangeAllocator.RequiredRomSha1,
        ExtensionRangeAllocator.RequiredRomSha256,
        ExtensionRangeAllocator.ApprovedCpuStart,
        ExtensionRangeAllocator.ApprovedCpuEnd,
        ExtensionRangeAllocator.LeftGuardStart,
        ExtensionRangeAllocator.LeftGuardEnd,
        ExtensionRangeAllocator.RightGuardStart,
        ExtensionRangeAllocator.RightGuardEnd,
        ExtensionRangeAllocator.ProtectedStart,
        ExtensionRangeAllocator.ProtectedEnd,
        ExtensionRangeAllocator.IntegrityStart,
        true);
}

public sealed record ExtensionRangeDescriptor(
    int RomLength,
    string RomSha1,
    string RomSha256,
    int CpuStart,
    int CpuEnd,
    int FileStart,
    int FileEnd,
    byte ExpectedFill,
    ExtensionRangeGuard LeftGuard,
    ExtensionRangeGuard RightGuard,
    int ProtectedStart,
    int ProtectedEnd,
    int IntegrityStart,
    ExtensionRangeApproval? Approval)
{
    public static ExtensionRangeDescriptor Approved { get; } = new(
        ExtensionRangeAllocator.RequiredRomLength,
        ExtensionRangeAllocator.RequiredRomSha1,
        ExtensionRangeAllocator.RequiredRomSha256,
        ExtensionRangeAllocator.ApprovedCpuStart,
        ExtensionRangeAllocator.ApprovedCpuEnd,
        ExtensionRangeAllocator.ApprovedFileStart,
        ExtensionRangeAllocator.ApprovedFileEnd,
        ExtensionRangeAllocator.ExpectedFillByte,
        new ExtensionRangeGuard(
            ExtensionRangeAllocator.LeftGuardStart,
            ExtensionRangeAllocator.LeftGuardEnd,
            ExtensionRangeAllocator.ExpectedFillByte),
        new ExtensionRangeGuard(
            ExtensionRangeAllocator.RightGuardStart,
            ExtensionRangeAllocator.RightGuardEnd,
            ExtensionRangeAllocator.ExpectedFillByte),
        ExtensionRangeAllocator.ProtectedStart,
        ExtensionRangeAllocator.ProtectedEnd,
        ExtensionRangeAllocator.IntegrityStart,
        ExtensionRangeApproval.Approved);
}

public sealed record ExtensionAllocationRequest(string Id, int Length);

public sealed record ExtensionRangeAllocation(
    string Id,
    int CpuStart,
    int CpuEnd,
    int FileStart,
    int FileEnd,
    int Length)
{
    public int CpuEndExclusive => checked(CpuEnd + 1);

    public int FileEndExclusive => checked(FileEnd + 1);
}

public sealed class ExtensionRangePlan
{
    private readonly ExtensionRangeAllocation[] _allocations;
    private readonly ReadOnlyCollection<ExtensionRangeAllocation> _view;

    internal ExtensionRangePlan(
        ExtensionRangeDescriptor descriptor,
        ExtensionRangeAllocation[] allocations,
        int allocatedLength,
        string provenance)
    {
        _allocations = (ExtensionRangeAllocation[])allocations.Clone();
        _view = Array.AsReadOnly(_allocations);
        RangeCpuStart = descriptor.CpuStart;
        RangeCpuEnd = descriptor.CpuEnd;
        RangeFileStart = descriptor.FileStart;
        RangeFileEnd = descriptor.FileEnd;
        RangeLength = ExtensionRangeAllocator.DescriptorRangeLength(descriptor);
        AllocatedLength = allocatedLength;
        Provenance = provenance;
    }

    public IReadOnlyList<ExtensionRangeAllocation> Allocations => _view;

    public int RangeCpuStart { get; }

    public int RangeCpuEnd { get; }

    public int RangeFileStart { get; }

    public int RangeFileEnd { get; }

    public int RangeLength { get; }

    public int AllocatedLength { get; }

    public int RemainingCapacity => RangeLength - AllocatedLength;

    public string Provenance { get; }
}

public sealed class ExtensionRangeAllocator
{
    public const int RequiredRomLength = NineEdNineDecoder.RequiredRomLength;
    public const string RequiredRomSha1 = NineEdNineDecoder.RequiredRomSha1;
    public const string RequiredRomSha256 = NineEdNineDecoder.RequiredRomSha256;

    public const int ApprovedCpuStart = 0x1010;
    public const int ApprovedCpuEnd = 0x13EF;
    public const int ApprovedLength = 0x03E0;
    public const int ApprovedFileStart = 0x1010;
    public const int ApprovedFileEnd = 0x13EF;
    public const byte ExpectedFillByte = 0xFF;
    public const int LeftGuardStart = 0x1000;
    public const int LeftGuardEnd = 0x100F;
    public const int RightGuardStart = 0x13F0;
    public const int RightGuardEnd = 0x13FF;
    public const int ProtectedStart = 0x1000;
    public const int ProtectedEnd = 0x1003;
    public const int IntegrityStart = 0x1400;
    public const int AlignmentBytes = 1;

    public const string ProvenanceText =
        "Static allocation planning only for A6L 0.1 set 1 a6ls.p1 SHA1 " +
        "402d1518bb78fdc489b06c2aabc771e5ce151847, human-approved range " +
        "CPU/file 1010-13EF, bank 0 same-offset mapping. No ROM mutation, emission, " +
        "linker, VM redirect, MAME run or hardware validation is performed.";

    private readonly ExtensionRangeDescriptor _descriptor;
    private readonly string _romSha1;
    private readonly string _romSha256;

    private ExtensionRangeAllocator(
        ExtensionRangeDescriptor descriptor, string romSha1, string romSha256)
    {
        _descriptor = descriptor;
        _romSha1 = romSha1;
        _romSha256 = romSha256;
    }

    public ExtensionRangeDescriptor Descriptor => _descriptor;

    public string OriginalRomSha1 => _romSha1;

    public string OriginalRomSha256 => _romSha256;

    public static ExtensionRangeAllocator Create(
        ReadOnlySpan<byte> originalRom, ExtensionRangeDescriptor descriptor) =>
        CreateCore(originalRom, descriptor, validateIdentity: true);

    internal static ExtensionRangeAllocator CreateWithoutIdentityForTests(
        ReadOnlySpan<byte> image, ExtensionRangeDescriptor descriptor) =>
        CreateCore(image, descriptor, validateIdentity: false);

    private static ExtensionRangeAllocator CreateCore(
        ReadOnlySpan<byte> originalRom,
        ExtensionRangeDescriptor descriptor,
        bool validateIdentity)
    {
        if (descriptor is null)
            throw new InvalidDataException("Extension range descriptor is missing.");

        if (validateIdentity)
            NineEdNineDecoder.ValidateIdentity(
                originalRom, RequiredRomLength, RequiredRomSha1, RequiredRomSha256);
        else if (originalRom.Length != RequiredRomLength)
            throw new InvalidDataException(
                $"ROM length mismatch: expected {RequiredRomLength}, got {originalRom.Length}");

        ValidateDescriptor(descriptor, originalRom.Length);
        ValidateDescriptorContents(originalRom, descriptor);

        return new ExtensionRangeAllocator(
            descriptor,
            Convert.ToHexString(System.Security.Cryptography.SHA1.HashData(originalRom)),
            Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(originalRom)));
    }

    public ExtensionRangePlan Plan(IReadOnlyList<ExtensionAllocationRequest> requests)
    {
        if (requests is null)
            throw new InvalidDataException("Allocation requests are missing.");

        var copied = new ExtensionAllocationRequest[requests.Count];
        for (int index = 0; index < copied.Length; index++)
            copied[index] = requests[index] ??
                throw new InvalidDataException(
                    $"Allocation request {index} is missing.");

        long totalLength = 0;
        var identifiers = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (ExtensionAllocationRequest request in copied)
        {
            if (string.IsNullOrWhiteSpace(request.Id))
                throw new InvalidDataException(
                    "Allocation identifier must be nonempty and non-whitespace.");
            if (!identifiers.Add(request.Id))
                throw new InvalidDataException(
                    $"Duplicate allocation identifier '{request.Id}'.");
            if (request.Length <= 0)
                throw new InvalidDataException(
                    $"Allocation '{request.Id}' length must be positive; got {request.Length}.");
            if (request.Length > ApprovedLength)
                throw new InvalidDataException(
                    $"Allocation '{request.Id}' length {request.Length} exceeds remaining range capacity " +
                    $"{ApprovedLength}.");
            totalLength += request.Length;
            if (totalLength > ApprovedLength)
                throw new InvalidDataException(
                    $"Total requested length {totalLength} exceeds remaining range capacity " +
                    $"{ApprovedLength}.");
        }

        int cursor = _descriptor.CpuStart;
        int allocatedLength = (int)totalLength;
        var allocations = new ExtensionRangeAllocation[copied.Length];
        for (int index = 0; index < copied.Length; index++)
        {
            ExtensionAllocationRequest request = copied[index];
            int cpuStart = cursor;
            int cpuEnd;
            int fileStart;
            int fileEnd;
            int nextCursor;
            try
            {
                cpuEnd = checked(cpuStart + request.Length - 1);
                fileStart = checked(_descriptor.FileStart + (cpuStart - _descriptor.CpuStart));
                fileEnd = checked(fileStart + request.Length - 1);
                nextCursor = checked(cpuEnd + 1);
            }
            catch (OverflowException)
            {
                throw new InvalidDataException(
                    $"Allocation '{request.Id}' arithmetic overflowed the range bounds.");
            }

            if (cpuStart < _descriptor.CpuStart || cpuEnd > _descriptor.CpuEnd ||
                fileStart < _descriptor.FileStart || fileEnd > _descriptor.FileEnd)
                throw new InvalidDataException(
                    $"Allocation '{request.Id}' falls outside the approved range bounds.");

            allocations[index] = new ExtensionRangeAllocation(
                request.Id, cpuStart, cpuEnd, fileStart, fileEnd, request.Length);
            cursor = nextCursor;
        }

        ValidateNoOverlap(allocations);
        return new ExtensionRangePlan(
            _descriptor, allocations, allocatedLength, ProvenanceText);
    }

    internal static int DescriptorRangeLength(ExtensionRangeDescriptor descriptor) =>
        checked(descriptor.CpuEnd - descriptor.CpuStart + 1);

    private static void ValidateDescriptor(
        ExtensionRangeDescriptor descriptor, int romLength)
    {
        ExtensionRangeApproval approval = descriptor.Approval ??
            throw new InvalidDataException(
                "Human approval binding is missing from the extension range descriptor.");
        ValidateApproval(approval);

        if (descriptor.RomLength != approval.RomLength ||
            descriptor.RomLength != romLength ||
            descriptor.RomLength != RequiredRomLength)
            throw new InvalidDataException(
                "Descriptor ROM length does not match the approved original identity.");
        if (!string.Equals(descriptor.RomSha1, approval.RomSha1,
                StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(descriptor.RomSha1, RequiredRomSha1,
                StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                "Descriptor ROM SHA1 does not match the approved original identity.");
        if (!string.Equals(descriptor.RomSha256, approval.RomSha256,
                StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(descriptor.RomSha256, RequiredRomSha256,
                StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                "Descriptor ROM SHA256 does not match the approved original identity.");

        ValidateOrderedRange(
            descriptor.CpuStart, descriptor.CpuEnd, "approved CPU range");
        ValidateOrderedRange(
            descriptor.FileStart, descriptor.FileEnd, "approved file range");
        ValidateOrderedRange(
            descriptor.LeftGuard?.Start ?? -1, descriptor.LeftGuard?.End ?? -1,
            "left guard");
        ValidateOrderedRange(
            descriptor.RightGuard?.Start ?? -1, descriptor.RightGuard?.End ?? -1,
            "right guard");
        ValidateOrderedRange(
            descriptor.ProtectedStart, descriptor.ProtectedEnd, "protected cells");
        ValidateOrderedRange(
            descriptor.IntegrityStart, descriptor.IntegrityStart, "integrity start");

        if (descriptor.CpuStart != approval.CpuStart ||
            descriptor.CpuEnd != approval.CpuEnd ||
            descriptor.CpuStart != ApprovedCpuStart ||
            descriptor.CpuEnd != ApprovedCpuEnd ||
            DescriptorRangeLength(descriptor) != ApprovedLength)
            throw new InvalidDataException(
                "Descriptor CPU range does not match the exact approved 1010-13EF range.");

        if (descriptor.FileStart != approval.CpuStart ||
            descriptor.FileEnd != approval.CpuEnd ||
            descriptor.FileStart != descriptor.CpuStart ||
            descriptor.FileEnd != descriptor.CpuEnd ||
            descriptor.FileStart != ApprovedFileStart ||
            descriptor.FileEnd != ApprovedFileEnd)
            throw new InvalidDataException(
                "Descriptor file range does not match the approved bank-0 same-offset mapping.");

        if (descriptor.ExpectedFill != ExpectedFillByte)
            throw new InvalidDataException(
                $"Descriptor expected fill is {descriptor.ExpectedFill:X2}; " +
                $"the approved range requires {ExpectedFillByte:X2}.");

        ValidateGuard(descriptor.LeftGuard, approval.LeftGuardStart, approval.LeftGuardEnd,
            "left guard");
        ValidateGuard(descriptor.RightGuard, approval.RightGuardStart, approval.RightGuardEnd,
            "right guard");

        if (descriptor.ProtectedStart != approval.ProtectedStart ||
            descriptor.ProtectedEnd != approval.ProtectedEnd ||
            descriptor.ProtectedStart != ProtectedStart ||
            descriptor.ProtectedEnd != ProtectedEnd)
            throw new InvalidDataException(
                "Descriptor protected cells do not match the approved 1000-1003 cells.");
        if (descriptor.IntegrityStart != approval.IntegrityStart ||
            descriptor.IntegrityStart != IntegrityStart)
            throw new InvalidDataException(
                "Descriptor integrity start does not match the approved 1400 boundary.");

        ValidateBounds(descriptor, romLength);

        if (descriptor.LeftGuard!.End + 1 != descriptor.CpuStart ||
            descriptor.CpuEnd + 1 != descriptor.RightGuard!.Start ||
            descriptor.RightGuard.End + 1 != descriptor.IntegrityStart)
            throw new InvalidDataException(
                "Descriptor guards, approved range and integrity start are not contiguous.");

        if (Overlaps(descriptor.CpuStart, descriptor.CpuEnd,
                descriptor.LeftGuard.Start, descriptor.LeftGuard.End) ||
            Overlaps(descriptor.CpuStart, descriptor.CpuEnd,
                descriptor.RightGuard.Start, descriptor.RightGuard.End) ||
            Overlaps(descriptor.CpuStart, descriptor.CpuEnd,
                descriptor.ProtectedStart, descriptor.ProtectedEnd) ||
            Overlaps(descriptor.LeftGuard.Start, descriptor.LeftGuard.End,
                descriptor.RightGuard.Start, descriptor.RightGuard.End) ||
            Overlaps(descriptor.LeftGuard.Start, descriptor.LeftGuard.End,
                descriptor.IntegrityStart, descriptor.IntegrityStart))
            throw new InvalidDataException(
                "Descriptor range overlaps a guard, protected cell or integrity boundary.");

        if (descriptor.ProtectedStart < descriptor.LeftGuard.Start ||
            descriptor.ProtectedEnd > descriptor.LeftGuard.End)
            throw new InvalidDataException(
                "Descriptor protected cells lie outside the approved left guard.");
    }

    private static void ValidateApproval(ExtensionRangeApproval approval)
    {
        if (!approval.IsApproved)
            throw new InvalidDataException(
                "Extension range approval is missing or not approved.");
        if (approval.RomLength != RequiredRomLength ||
            !string.Equals(approval.RomSha1, RequiredRomSha1,
                StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(approval.RomSha256, RequiredRomSha256,
                StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                "Approval binding does not match the exact original ROM identity.");
        if (approval.CpuStart != ApprovedCpuStart ||
            approval.CpuEnd != ApprovedCpuEnd ||
            approval.LeftGuardStart != LeftGuardStart ||
            approval.LeftGuardEnd != LeftGuardEnd ||
            approval.RightGuardStart != RightGuardStart ||
            approval.RightGuardEnd != RightGuardEnd ||
            approval.ProtectedStart != ProtectedStart ||
            approval.ProtectedEnd != ProtectedEnd ||
            approval.IntegrityStart != IntegrityStart)
            throw new InvalidDataException(
                "Approval binding does not match the exact approved range or guards.");
        if (!approval.Bank0Only)
            throw new InvalidDataException(
                "Approval binding does not restrict allocation to bank 0.");
    }

    private static void ValidateGuard(
        ExtensionRangeGuard? guard, int expectedStart, int expectedEnd, string name)
    {
        if (guard is null)
            throw new InvalidDataException($"Descriptor {name} is missing.");
        if (guard.Start != expectedStart || guard.End != expectedEnd)
            throw new InvalidDataException(
                $"Descriptor {name} does not match the approved {expectedStart:X4}-{expectedEnd:X4} guard.");
        if (guard.ExpectedFill != ExpectedFillByte)
            throw new InvalidDataException(
                $"Descriptor {name} expected fill is {guard.ExpectedFill:X2}; " +
                $"the approved guard requires {ExpectedFillByte:X2}.");
    }

    private static void ValidateBounds(ExtensionRangeDescriptor descriptor, int romLength)
    {
        if (!IsBounded(descriptor.CpuStart, descriptor.CpuEnd, romLength) ||
            !IsBounded(descriptor.FileStart, descriptor.FileEnd, romLength))
            throw new InvalidDataException(
                "Approved CPU/file range lies outside the original ROM bounds.");
        if (!IsBounded(descriptor.LeftGuard!.Start, descriptor.LeftGuard.End, romLength) ||
            !IsBounded(descriptor.RightGuard!.Start, descriptor.RightGuard.End, romLength) ||
            !IsBounded(descriptor.ProtectedStart, descriptor.ProtectedEnd, romLength) ||
            descriptor.IntegrityStart < 0 || descriptor.IntegrityStart >= romLength)
            throw new InvalidDataException(
                "Descriptor guard, protected or integrity bounds are outside the original ROM.");
    }

    private static void ValidateDescriptorContents(
        ReadOnlySpan<byte> image, ExtensionRangeDescriptor descriptor)
    {
        ValidateFill(image, descriptor.LeftGuard!.Start, descriptor.LeftGuard.Length,
            descriptor.LeftGuard.ExpectedFill, "left guard");
        ValidateFill(image, descriptor.RightGuard!.Start, descriptor.RightGuard.Length,
            descriptor.RightGuard.ExpectedFill, "right guard");
        ValidateFill(image, descriptor.CpuStart, DescriptorRangeLength(descriptor),
            descriptor.ExpectedFill, "approved range");
    }

    private static void ValidateFill(
        ReadOnlySpan<byte> image, int start, int length, byte expected, string name)
    {
        for (int index = 0; index < length; index++)
        {
            byte actual = image[start + index];
            if (actual != expected)
                throw new InvalidDataException(
                    $"Expected {expected:X2} {name} contents at {start + index:X4}; " +
                    $"found {actual:X2}.");
        }
    }

    private static void ValidateOrderedRange(int start, int end, string name)
    {
        if (start < 0 || end < start)
            throw new InvalidDataException(
                $"Descriptor {name} start/end {start}-{end} is invalid.");
    }

    private static bool IsBounded(int start, int end, int length) =>
        start >= 0 && end >= start && (long)end < length;

    private static bool Overlaps(int firstStart, int firstEnd, int secondStart, int secondEnd) =>
        (long)firstStart <= secondEnd && (long)secondStart <= firstEnd;

    private static void ValidateNoOverlap(ExtensionRangeAllocation[] allocations)
    {
        for (int first = 0; first < allocations.Length; first++)
        {
            for (int second = first + 1; second < allocations.Length; second++)
            {
                if (Overlaps(
                        allocations[first].CpuStart, allocations[first].CpuEnd,
                        allocations[second].CpuStart, allocations[second].CpuEnd))
                    throw new InvalidDataException(
                        $"Allocations '{allocations[first].Id}' and " +
                        $"'{allocations[second].Id}' overlap.");
            }
        }
    }
}

using System.Collections.ObjectModel;
using System.Security.Cryptography;

namespace FruitMachineLab.Il;

public sealed class ExtensionPayload
{
    private readonly byte[] _bytes;
    private readonly string _sha1;
    private readonly string _sha256;

    public ExtensionPayload(string id, ReadOnlySpan<byte> bytes)
    {
        if (string.IsNullOrWhiteSpace(id))
            throw new InvalidDataException(
                "Extension payload identifier must be nonempty and non-whitespace.");

        Id = id;
        _bytes = bytes.ToArray();
        _sha1 = Convert.ToHexString(SHA1.HashData(_bytes));
        _sha256 = Convert.ToHexString(SHA256.HashData(_bytes));
    }

    public string Id { get; }

    public int Length => _bytes.Length;

    public ReadOnlySpan<byte> Bytes => _bytes;

    public string Sha1 => _sha1;

    public string Sha256 => _sha256;

    public byte[] CopyBytes() => (byte[])_bytes.Clone();
}

public sealed record ExtensionEmittedPayload(
    string Id,
    int CpuStart,
    int CpuEnd,
    int FileStart,
    int FileEnd,
    int Length,
    string Sha1,
    string Sha256);

public sealed record ExtensionByteChange(int Offset, byte Before, byte After);

public sealed class ExtensionRangeEmission
{
    private readonly byte[] _image;
    private readonly ReadOnlyCollection<ExtensionEmittedPayload> _payloads;
    private readonly ReadOnlyCollection<int> _changedOffsets;
    private readonly ReadOnlyCollection<ExtensionByteChange> _byteChanges;

    internal ExtensionRangeEmission(
        byte[] image,
        ExtensionRangePlan plan,
        ExtensionEmittedPayload[] payloads,
        int[] changedOffsets,
        ExtensionByteChange[] byteChanges,
        string originalRomSha1,
        string originalRomSha256,
        string outputRomSha1,
        string outputRomSha256,
        string originalIntegrityFieldsHex,
        string outputIntegrityFieldsHex,
        bool integrityCoveredBytesUnchanged,
        bool integrityFieldsUnchanged,
        string provenance)
    {
        _image = (byte[])image.Clone();
        _payloads = Array.AsReadOnly((ExtensionEmittedPayload[])payloads.Clone());
        _changedOffsets = Array.AsReadOnly((int[])changedOffsets.Clone());
        _byteChanges = Array.AsReadOnly((ExtensionByteChange[])byteChanges.Clone());
        Plan = plan;
        OriginalRomSha1 = originalRomSha1;
        OriginalRomSha256 = originalRomSha256;
        OutputRomSha1 = outputRomSha1;
        OutputRomSha256 = outputRomSha256;
        OriginalIntegrityFieldsHex = originalIntegrityFieldsHex;
        OutputIntegrityFieldsHex = outputIntegrityFieldsHex;
        IntegrityCoveredBytesUnchanged = integrityCoveredBytesUnchanged;
        IntegrityFieldsUnchanged = integrityFieldsUnchanged;
        Provenance = provenance;
    }

    public ReadOnlySpan<byte> OutputImage => _image;

    public byte[] CopyOutputImage() => (byte[])_image.Clone();

    public int OutputLength => _image.Length;

    public string BuildId => OutputRomSha256;

    public string OriginalRomSha1 { get; }

    public string OriginalRomSha256 { get; }

    public string OutputRomSha1 { get; }

    public string OutputRomSha256 { get; }

    public ExtensionRangePlan Plan { get; }

    public IReadOnlyList<ExtensionEmittedPayload> Payloads => _payloads;

    public IReadOnlyList<int> ChangedOffsets => _changedOffsets;

    public IReadOnlyList<ExtensionByteChange> ByteChanges => _byteChanges;

    public string OriginalIntegrityFieldsHex { get; }

    public string OutputIntegrityFieldsHex { get; }

    public string IntegrityCoveredRange =>
        $"{VmIlIntegrity.RangeStart:X4}-{VmIlIntegrity.RangeEnd:X4}";

    public bool IntegrityCoveredBytesUnchanged { get; }

    public bool IntegrityFieldsUnchanged { get; }

    public string Provenance { get; }
}

public static class ExtensionRangeEmitter
{
    public const string ProvenanceText =
        "Checked in-memory extension payload emission only for A6L 0.1 set 1 a6ls.p1 " +
        "SHA1 402d1518bb78fdc489b06c2aabc771e5ce151847, human-approved CPU/file range " +
        "1010-13EF, bank 0 same-offset mapping. Outputs preserve every byte outside the " +
        "actual allocations, including guards, unallocated FF and the 1400-FFFF integrity " +
        "coverage. Test payload bytes are synthetic unexecuted data, not certified VM " +
        "instructions. No composite/header encoding, reference redirection, VM entry " +
        "redirect, linker, MAME execution or hardware validation is performed.";

    public static ExtensionRangeEmission Emit(
        ReadOnlySpan<byte> originalRom,
        ExtensionRangeDescriptor descriptor,
        IReadOnlyList<ExtensionPayload> payloads) =>
        EmitCore(originalRom, descriptor, expectedPlan: null, requireExpectedPlan: false,
            payloads);

    public static ExtensionRangeEmission Emit(
        ReadOnlySpan<byte> originalRom,
        ExtensionRangeDescriptor descriptor,
        ExtensionRangePlan expectedPlan,
        IReadOnlyList<ExtensionPayload> payloads) =>
        EmitCore(originalRom, descriptor, expectedPlan, requireExpectedPlan: true, payloads);

    private static ExtensionRangeEmission EmitCore(
        ReadOnlySpan<byte> originalRom,
        ExtensionRangeDescriptor descriptor,
        ExtensionRangePlan? expectedPlan,
        bool requireExpectedPlan,
        IReadOnlyList<ExtensionPayload>? payloads)
    {
        if (payloads is null)
            throw new InvalidDataException("Extension payloads are missing.");

        var copiedPayloads = new ExtensionPayload[payloads.Count];
        for (int index = 0; index < copiedPayloads.Length; index++)
        {
            copiedPayloads[index] = payloads[index] ??
                throw new InvalidDataException(
                    $"Extension payload {index} is missing.");
            if (copiedPayloads[index].Length == 0)
                throw new InvalidDataException(
                    $"Extension payload '{copiedPayloads[index].Id}' must be nonempty.");
        }

        var requests = new ExtensionAllocationRequest[copiedPayloads.Length];
        for (int index = 0; index < copiedPayloads.Length; index++)
            requests[index] = new ExtensionAllocationRequest(
                copiedPayloads[index].Id, copiedPayloads[index].Length);

        ExtensionRangeAllocator allocator =
            ExtensionRangeAllocator.Create(originalRom, descriptor);
        ExtensionRangePlan plan = allocator.Plan(requests);

        if (requireExpectedPlan)
        {
            if (expectedPlan is null)
                throw new InvalidDataException("Expected extension range plan is missing.");
            if (!PlansMatch(plan, expectedPlan))
                throw new InvalidDataException(
                    "Caller-supplied extension range plan does not match the plan derived " +
                    "from the payload identifiers and lengths.");
        }

        ValidateExpectedFill(originalRom, plan);

        byte[] output = originalRom.ToArray();
        for (int index = 0; index < copiedPayloads.Length; index++)
        {
            ExtensionRangeAllocation allocation = plan.Allocations[index];
            copiedPayloads[index].Bytes.CopyTo(
                output.AsSpan(allocation.FileStart, allocation.Length));
        }

        ValidateEmission(
            originalRom, output, plan, copiedPayloads,
            out int[] changedOffsets, out ExtensionByteChange[] byteChanges);

        VmIlIntegrityOriginalVerification originalIntegrity =
            VmIlIntegrity.VerifyOriginal(originalRom);
        string outputFields = Convert.ToHexString(output.AsSpan(
            VmIlIntegrity.SumOffset,
            VmIlIntegrity.RotateSubXorBOffset - VmIlIntegrity.SumOffset + 1));
        if (!string.Equals(outputFields, originalIntegrity.StoredFieldsHex,
                StringComparison.Ordinal))
            throw new InvalidDataException(
                $"Output integrity fields are {outputFields}; expected the unchanged " +
                $"original {originalIntegrity.StoredFieldsHex}.");
        EnsureEqual(originalRom, output, VmIlIntegrity.RangeStart, VmIlIntegrity.RangeEnd,
            "integrity-covered 1400-FFFF bytes");

        var payloadEvidence = new ExtensionEmittedPayload[copiedPayloads.Length];
        for (int index = 0; index < copiedPayloads.Length; index++)
        {
            ExtensionRangeAllocation allocation = plan.Allocations[index];
            ExtensionPayload payload = copiedPayloads[index];
            if (payload.Length != allocation.Length)
                throw new InvalidDataException(
                    $"Payload '{payload.Id}' length {payload.Length} differs from its " +
                    $"allocation length {allocation.Length}.");
            payloadEvidence[index] = new ExtensionEmittedPayload(
                payload.Id,
                allocation.CpuStart,
                allocation.CpuEnd,
                allocation.FileStart,
                allocation.FileEnd,
                allocation.Length,
                payload.Sha1,
                payload.Sha256);
        }

        return new ExtensionRangeEmission(
            output,
            plan,
            payloadEvidence,
            changedOffsets,
            byteChanges,
            allocator.OriginalRomSha1,
            allocator.OriginalRomSha256,
            Convert.ToHexString(SHA1.HashData(output)),
            Convert.ToHexString(SHA256.HashData(output)),
            originalIntegrity.StoredFieldsHex,
            outputFields,
            integrityCoveredBytesUnchanged: true,
            integrityFieldsUnchanged: true,
            ProvenanceText);
    }

    private static bool PlansMatch(ExtensionRangePlan canonical, ExtensionRangePlan supplied)
    {
        if (supplied.RangeCpuStart != canonical.RangeCpuStart ||
            supplied.RangeCpuEnd != canonical.RangeCpuEnd ||
            supplied.RangeFileStart != canonical.RangeFileStart ||
            supplied.RangeFileEnd != canonical.RangeFileEnd ||
            supplied.RangeLength != canonical.RangeLength ||
            supplied.AllocatedLength != canonical.AllocatedLength ||
            supplied.RemainingCapacity != canonical.RemainingCapacity ||
            !string.Equals(supplied.Provenance, canonical.Provenance, StringComparison.Ordinal) ||
            supplied.Allocations.Count != canonical.Allocations.Count)
            return false;

        for (int index = 0; index < canonical.Allocations.Count; index++)
        {
            ExtensionRangeAllocation expected = canonical.Allocations[index];
            ExtensionRangeAllocation actual = supplied.Allocations[index];
            if (!string.Equals(actual.Id, expected.Id, StringComparison.Ordinal) ||
                actual.CpuStart != expected.CpuStart ||
                actual.CpuEnd != expected.CpuEnd ||
                actual.FileStart != expected.FileStart ||
                actual.FileEnd != expected.FileEnd ||
                actual.Length != expected.Length)
                return false;
        }

        return true;
    }

    private static void ValidateExpectedFill(
        ReadOnlySpan<byte> originalRom, ExtensionRangePlan plan)
    {
        foreach (ExtensionRangeAllocation allocation in plan.Allocations)
        {
            for (int offset = allocation.FileStart; offset <= allocation.FileEnd; offset++)
            {
                if (originalRom[offset] != ExtensionRangeAllocator.ExpectedFillByte)
                    throw new InvalidDataException(
                        $"Expected {ExtensionRangeAllocator.ExpectedFillByte:X2} allocation " +
                        $"byte for '{allocation.Id}' at {offset:X4}; found " +
                        $"{originalRom[offset]:X2}.");
            }
        }
    }

    private static void ValidateEmission(
        ReadOnlySpan<byte> originalRom,
        ReadOnlySpan<byte> output,
        ExtensionRangePlan plan,
        ExtensionPayload[] payloads,
        out int[] changedOffsets,
        out ExtensionByteChange[] byteChanges)
    {
        if (output.Length != originalRom.Length)
            throw new InvalidDataException(
                $"Emitted output length {output.Length} differs from the original " +
                $"{originalRom.Length}.");

        var allocated = new bool[output.Length];
        foreach (ExtensionRangeAllocation allocation in plan.Allocations)
        {
            if (allocation.FileStart < 0 || allocation.FileEnd >= output.Length ||
                allocation.CpuStart < 0 || allocation.CpuEnd >= output.Length)
                throw new InvalidDataException(
                    $"Allocation '{allocation.Id}' falls outside the emitted image.");
            for (int offset = allocation.FileStart; offset <= allocation.FileEnd; offset++)
                allocated[offset] = true;
        }

        var changed = new List<int>();
        var changes = new List<ExtensionByteChange>();
        for (int offset = 0; offset < output.Length; offset++)
        {
            if (!allocated[offset])
            {
                if (output[offset] != originalRom[offset])
                    throw new InvalidDataException(
                        $"Emitted output changed byte {offset:X4} outside every allocation.");
                continue;
            }

            if (output[offset] != originalRom[offset])
            {
                changed.Add(offset);
                changes.Add(new ExtensionByteChange(
                    offset, originalRom[offset], output[offset]));
            }
        }

        for (int index = 0; index < payloads.Length; index++)
        {
            ExtensionRangeAllocation allocation = plan.Allocations[index];
            if (!output.Slice(allocation.FileStart, allocation.Length)
                    .SequenceEqual(payloads[index].Bytes))
                throw new InvalidDataException(
                    $"Emitted allocation '{allocation.Id}' does not contain its payload.");
        }

        EnsureEqual(originalRom, output, 0x0000, 0x100F, "original bytes and left guard");
        EnsureEqual(originalRom, output, 0x13F0, output.Length - 1,
            "right guard, unallocated FF and integrity coverage");

        changedOffsets = changed.ToArray();
        byteChanges = changes.ToArray();
    }

    private static void EnsureEqual(
        ReadOnlySpan<byte> originalRom,
        ReadOnlySpan<byte> output,
        int start,
        int end,
        string label)
    {
        if (start < 0 || end < start || end >= output.Length)
            throw new InvalidDataException($"Emitted {label} range {start}-{end} is invalid.");
        if (!originalRom.Slice(start, end - start + 1)
                .SequenceEqual(output.Slice(start, end - start + 1)))
            throw new InvalidDataException(
                $"Emitted output changed preserved {label} at {start:X4}-{end:X4}.");
    }
}

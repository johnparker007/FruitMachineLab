using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using FruitMachineLab.Il;

namespace FruitMachineLab.IlVerification;

internal sealed record EmitterAllocationSummary(
    string Id,
    int CpuStart,
    int CpuEnd,
    int FileStart,
    int FileEnd,
    int Length,
    string Sha1,
    string Sha256);

internal sealed record EmitterVerificationReport(
    string TaskId,
    int SchemaVersion,
    string Status,
    string Classification,
    string EvidenceClass,
    string RomPath,
    int RomLength,
    string RomSha1Before,
    string RomSha256Before,
    string RomSha1After,
    string RomSha256After,
    bool InputUnchanged,
    string ApprovedCpuRange,
    string ApprovedFileRange,
    int ApprovedLength,
    string LeftGuard,
    string RightGuard,
    string ProtectedCells,
    int IntegrityStart,
    int OutputLength,
    string WholeOutputSha1,
    string WholeOutputSha256,
    IReadOnlyList<EmitterAllocationSummary> WholeAllocations,
    int WholeChangedCount,
    int[] WholeChangedOffsets,
    string SplitOutputSha1,
    string SplitOutputSha256,
    IReadOnlyList<EmitterAllocationSummary> SplitAllocations,
    int SplitChangedCount,
    int[] SplitChangedOffsets,
    string PartialOutputSha1,
    string PartialOutputSha256,
    IReadOnlyList<EmitterAllocationSummary> PartialAllocations,
    int PartialChangedCount,
    int[] PartialChangedOffsets,
    string IdentityOutputSha1,
    string IdentityOutputSha256,
    bool EmptyRequestIdentity,
    bool FfOnlyPayloadIdentity,
    string IntegrityOriginalFieldsHex,
    string IntegrityOutputFieldsHex,
    bool IntegrityCoveredRangeUnchanged,
    bool IntegrityFieldsUnchanged,
    int NegativeControls,
    IReadOnlyList<VerificationCheck> Checks,
    IReadOnlyList<string> Limitations,
    string RemainingChainBoundary);

internal sealed record EmitterOriginalIdentity(int Length, string Sha1, string Sha256);

internal sealed record EmitterScenarioSummary(
    string Name,
    IReadOnlyList<EmitterAllocationSummary> Allocations,
    int ChangedCount,
    string OutputSha1,
    string OutputSha256);

internal sealed record EmitterEmptyPolicySummary(
    bool EmptyRequestProducesIdentityOutput,
    bool FfOnlyPayloadProducesIdentityOutput);

internal sealed record EmitterIntegritySummary(
    string CoveredRange,
    string OriginalFieldsHex,
    string OutputFieldsHex,
    bool CoveredBytesUnchanged,
    bool FieldsUnchanged);

internal sealed record EmitterEvidenceSummary(
    string TaskId,
    int SchemaVersion,
    string Status,
    string Classification,
    string EvidenceClass,
    string ApprovedCpuRange,
    string ApprovedFileRange,
    int ApprovedLength,
    string Guards,
    string ProtectedCells,
    int IntegrityStart,
    EmitterOriginalIdentity OriginalIdentity,
    IReadOnlyList<EmitterScenarioSummary> Scenarios,
    EmitterEmptyPolicySummary EmptyAndUnchangedPolicy,
    EmitterIntegritySummary Integrity,
    int NegativeControls,
    IReadOnlyList<string> CheckNames,
    IReadOnlyList<string> Limitations,
    string RemainingChainBoundary);

internal static class ExtensionRangeEmitterVerification
{
    public static EmitterVerificationReport Run(
        string romPath, string repositoryRoot, string outputDirectory)
    {
        if (Directory.Exists(outputDirectory))
            throw new IOException($"Output directory already exists: {outputDirectory}");

        byte[] rom = File.ReadAllBytes(romPath);
        string beforeSha1 = HashSha1(rom);
        string beforeSha256 = HashSha256(rom);
        var checks = new List<VerificationCheck>();
        int negativeControls = 0;

        void Assert(bool condition, string message)
        {
            if (!condition) throw new InvalidDataException(message);
        }

        void Reject(Action action, string expected)
        {
            negativeControls++;
            try
            {
                action();
            }
            catch (Exception error) when (error is InvalidDataException or IOException or
                                          KeyNotFoundException or ArgumentException or
                                          NotSupportedException or InvalidOperationException)
            {
                Assert(error.Message.Contains(expected, StringComparison.OrdinalIgnoreCase),
                    $"Expected rejection containing '{expected}', got '{error.Message}'");
                return;
            }
            throw new InvalidDataException(
                $"Unsafe input was accepted; expected rejection containing '{expected}'");
        }

        void Check(string name, Action action)
        {
            try
            {
                action();
                checks.Add(new VerificationCheck(name, true, null));
                Console.WriteLine("PASS " + name);
            }
            catch (Exception error)
            {
                checks.Add(new VerificationCheck(name, false, error.Message));
                throw new InvalidOperationException($"Check failed: {name}: {error.Message}", error);
            }
        }

        ExtensionPayload MakePayload(string id, int length, byte seed) =>
            new(id, Enumerable.Range(0, length)
                .Select(index => (byte)(seed + index * 37)).ToArray());

        EmitterAllocationSummary Summary(
            ExtensionEmittedPayload payload) =>
            new(payload.Id, payload.CpuStart, payload.CpuEnd, payload.FileStart,
                payload.FileEnd, payload.Length, payload.Sha1, payload.Sha256);

        bool SameEvidence(ExtensionRangeEmission left, ExtensionRangeEmission right) =>
            left.OutputRomSha1 == right.OutputRomSha1 &&
            left.OutputRomSha256 == right.OutputRomSha256 &&
            left.Plan.Allocations.SequenceEqual(right.Plan.Allocations) &&
            left.Payloads.SequenceEqual(right.Payloads) &&
            left.ChangedOffsets.SequenceEqual(right.ChangedOffsets) &&
            left.ByteChanges.SequenceEqual(right.ByteChanges) &&
            left.OriginalIntegrityFieldsHex == right.OriginalIntegrityFieldsHex &&
            left.OutputIntegrityFieldsHex == right.OutputIntegrityFieldsHex &&
            left.IntegrityCoveredBytesUnchanged == right.IntegrityCoveredBytesUnchanged &&
            left.IntegrityFieldsUnchanged == right.IntegrityFieldsUnchanged;

        bool Inside(int offset, IReadOnlyList<ExtensionEmittedPayload> allocations) =>
            allocations.Any(allocation =>
                offset >= allocation.FileStart && offset <= allocation.FileEnd);

        void AssertPreservedOutsideAllocations(
            ExtensionRangeEmission emission, ReadOnlySpan<byte> original)
        {
            byte[] output = emission.CopyOutputImage();
            var allocated = new bool[output.Length];
            foreach (ExtensionEmittedPayload allocation in emission.Payloads)
            {
                for (int offset = allocation.FileStart; offset <= allocation.FileEnd; offset++)
                    allocated[offset] = true;
            }

            for (int offset = 0; offset < output.Length; offset++)
            {
                if (!allocated[offset])
                    Assert(output[offset] == original[offset],
                        $"Preserved byte {offset:X4} changed outside allocations");
            }
        }

        ExtensionRangeDescriptor approved = ExtensionRangeDescriptor.Approved;
        ExtensionPayload wholePayload = MakePayload("whole", 992, 0x11);
        ExtensionPayload firstPayload = MakePayload("first", 500, 0x33);
        ExtensionPayload secondPayload = MakePayload("second", 492, 0x77);
        ExtensionPayload partOnePayload = MakePayload("part-one", 100, 0x55);
        ExtensionPayload partTwoPayload = MakePayload("part-two", 200, 0x99);
        ExtensionRangeEmission whole = null!;
        ExtensionRangeEmission split = null!;
        ExtensionRangeEmission partial = null!;
        ExtensionRangeEmission identity = null!;
        ExtensionRangeEmission ffOnly = null!;
        string originalIntegrityFields = string.Empty;

        try
        {
            Check("Approved descriptor binds the exact revision range guards and integrity start", () =>
            {
                Assert(rom.Length == 65536, "ROM length differs");
                Assert(beforeSha1.Equals(ExtensionRangeAllocator.RequiredRomSha1,
                        StringComparison.OrdinalIgnoreCase), "ROM SHA1 differs");
                Assert(beforeSha256.Equals(ExtensionRangeAllocator.RequiredRomSha256,
                        StringComparison.OrdinalIgnoreCase), "ROM SHA256 differs");
                Assert(approved.RomLength == 65536 &&
                       approved.RomSha1.Equals(ExtensionRangeAllocator.RequiredRomSha1,
                           StringComparison.OrdinalIgnoreCase) &&
                       approved.RomSha256.Equals(ExtensionRangeAllocator.RequiredRomSha256,
                           StringComparison.OrdinalIgnoreCase),
                    "Approved descriptor revision differs");
                Assert(approved.CpuStart == 0x1010 && approved.CpuEnd == 0x13EF &&
                       approved.FileStart == 0x1010 && approved.FileEnd == 0x13EF &&
                       approved.ExpectedFill == ExtensionRangeAllocator.ExpectedFillByte &&
                       approved.LeftGuard == new ExtensionRangeGuard(0x1000, 0x100F, 0xFF) &&
                       approved.RightGuard == new ExtensionRangeGuard(0x13F0, 0x13FF, 0xFF) &&
                       approved.ProtectedStart == 0x1000 &&
                       approved.ProtectedEnd == 0x1003 &&
                       approved.IntegrityStart == 0x1400 &&
                       approved.Approval is not null &&
                       approved.Approval.IsApproved &&
                       approved.Approval.Bank0Only,
                    "Approved descriptor range/guard/integrity binding differs");
                Assert(ExtensionRangeAllocator.DescriptorRangeLength(approved) == 992,
                    "Approved descriptor length differs");
            });

            Check("One 992-byte payload fills the exact range and changes only its allocations", () =>
            {
                whole = ExtensionRangeEmitter.Emit(rom, approved, new[] { wholePayload });
                Assert(whole.OutputLength == 65536, "Whole output length differs");
                Assert(whole.Plan.Allocations.Count == 1, "Whole allocation count differs");
                ExtensionRangeAllocation allocation = whole.Plan.Allocations[0];
                Assert(allocation.Id == "whole" && allocation.Length == 992,
                    "Whole allocation identity or length differs");
                Assert(allocation.CpuStart == 0x1010 && allocation.CpuEnd == 0x13EF &&
                       allocation.FileStart == 4112 && allocation.FileEnd == 5103,
                    "Whole allocation boundaries differ");
                Assert(whole.Plan.AllocatedLength == 992 &&
                       whole.Plan.RemainingCapacity == 0,
                    "Whole allocation capacity differs");
                Assert(whole.Payloads.Count == 1 &&
                       whole.Payloads[0].Id == "whole" &&
                       whole.Payloads[0].Length == 992,
                    "Whole payload evidence differs");
                Assert(whole.Payloads[0].Sha1 == wholePayload.Sha1 &&
                       whole.Payloads[0].Sha256 == wholePayload.Sha256,
                    "Whole payload evidence hashes differ");
                Assert(whole.OutputImage.Slice(0x1010, 992)
                        .SequenceEqual(wholePayload.Bytes),
                    "Whole payload was not emitted at 1010");
                AssertPreservedOutsideAllocations(whole, rom);
                Assert(whole.ChangedOffsets.Count > 0,
                    "Whole payload changed no bytes");
                Assert(whole.ChangedOffsets.All(offset => Inside(offset, whole.Payloads)),
                    "Whole changed offset lies outside its allocation");
                Assert(whole.ByteChanges.Count == whole.ChangedOffsets.Count,
                    "Whole byte-change evidence count differs");
                Assert(whole.OutputRomSha1 == HashSha1(whole.CopyOutputImage()) &&
                       whole.OutputRomSha256 == HashSha256(whole.CopyOutputImage()),
                    "Whole output hashes do not bind the emitted image");
                Assert(whole.OriginalRomSha1 == beforeSha1 &&
                       whole.OriginalRomSha256 == beforeSha256,
                    "Whole original identity evidence differs");
                Assert(whole.BuildId == whole.OutputRomSha256,
                    "Whole build identity is not the output SHA256");
            });

            Check("500 plus 492 payloads allocate exact contiguous boundaries deterministically", () =>
            {
                split = ExtensionRangeEmitter.Emit(
                    rom, approved, new[] { firstPayload, secondPayload });
                Assert(split.OutputLength == 65536, "Split output length differs");
                Assert(split.Plan.Allocations.Count == 2, "Split allocation count differs");
                ExtensionRangeAllocation first = split.Plan.Allocations[0];
                ExtensionRangeAllocation second = split.Plan.Allocations[1];
                Assert(first.Id == "first" && first.Length == 500 &&
                       first.CpuStart == 0x1010 && first.CpuEnd == 0x1203 &&
                       first.FileStart == 4112 && first.FileEnd == 4611,
                    "First split allocation differs");
                Assert(second.Id == "second" && second.Length == 492 &&
                       second.CpuStart == 0x1204 && second.CpuEnd == 0x13EF &&
                       second.FileStart == 4612 && second.FileEnd == 5103,
                    "Second split allocation differs");
                Assert(first.CpuEnd + 1 == second.CpuStart &&
                       first.FileEnd + 1 == second.FileStart,
                    "Split allocations are not contiguous");
                Assert(split.Plan.AllocatedLength == 992 &&
                       split.Plan.RemainingCapacity == 0,
                    "Split capacity differs");
                Assert(split.OutputImage.Slice(0x1010, 500)
                        .SequenceEqual(firstPayload.Bytes) &&
                       split.OutputImage.Slice(0x1204, 492)
                        .SequenceEqual(secondPayload.Bytes),
                    "Split payload bytes were not emitted at their allocations");
                AssertPreservedOutsideAllocations(split, rom);
                Assert(split.ChangedOffsets.All(offset => Inside(offset, split.Payloads)),
                    "Split changed offset lies outside its allocations");

                ExtensionRangeEmission repeated = ExtensionRangeEmitter.Emit(
                    rom, approved, new[] { firstPayload, secondPayload });
                Assert(SameEvidence(split, repeated),
                    "Repeated split emission is not deterministic");
                ExtensionRangeEmission repeatedWhole = ExtensionRangeEmitter.Emit(
                    rom, approved, new[] { wholePayload });
                Assert(SameEvidence(whole, repeatedWhole),
                    "Repeated whole emission is not deterministic");
            });

            Check("Partial payloads preserve guards unallocated FF and all other bytes", () =>
            {
                partial = ExtensionRangeEmitter.Emit(
                    rom, approved, new[] { partOnePayload, partTwoPayload });
                Assert(partial.Plan.Allocations.Count == 2,
                    "Partial allocation count differs");
                Assert(partial.Plan.Allocations[0].CpuStart == 0x1010 &&
                       partial.Plan.Allocations[0].CpuEnd == 0x1073 &&
                       partial.Plan.Allocations[1].CpuStart == 0x1074 &&
                       partial.Plan.Allocations[1].CpuEnd == 0x113B,
                    "Partial allocation boundaries differ");
                Assert(partial.Plan.RemainingCapacity == 692,
                    "Partial remaining capacity differs");
                Assert(partial.ChangedOffsets.All(offset => Inside(offset, partial.Payloads)),
                    "Partial changed offset lies outside its allocations");
                AssertPreservedOutsideAllocations(partial, rom);
                for (int offset = 0x113C; offset <= 0x13EF; offset++)
                {
                    Assert(partial.OutputImage[offset] ==
                           ExtensionRangeAllocator.ExpectedFillByte,
                        $"Unallocated approved-range byte {offset:X4} is not FF");
                    Assert(partial.OutputImage[offset] == rom[offset],
                        $"Unallocated approved-range byte {offset:X4} changed");
                }
                Assert(partial.OutputImage.Slice(0x1000, 16)
                        .SequenceEqual(rom.AsSpan(0x1000, 16)),
                    "Left guard changed");
                Assert(partial.OutputImage.Slice(0x13F0, 16)
                        .SequenceEqual(rom.AsSpan(0x13F0, 16)),
                    "Right guard changed");
            });

            Check("Empty request and all-FF payload explicitly produce identity output", () =>
            {
                identity = ExtensionRangeEmitter.Emit(
                    rom, approved, Array.Empty<ExtensionPayload>());
                Assert(identity.OutputLength == 65536,
                    "Empty-request output length differs");
                Assert(identity.Plan.Allocations.Count == 0 &&
                       identity.Plan.AllocatedLength == 0 &&
                       identity.Plan.RemainingCapacity == 992,
                    "Empty-request plan is not empty");
                Assert(identity.ChangedOffsets.Count == 0,
                    "Empty request changed bytes");
                Assert(identity.OutputImage.SequenceEqual(rom),
                    "Empty request did not reproduce the original image");
                Assert(identity.OutputRomSha1 == beforeSha1 &&
                       identity.OutputRomSha256 == beforeSha256,
                    "Empty-request output identity differs from the original");

                var ffBytes = new byte[10];
                Array.Fill(ffBytes, (byte)0xFF);
                ffOnly = ExtensionRangeEmitter.Emit(
                    rom, approved,
                    new[] { new ExtensionPayload("ff-only", ffBytes) });
                Assert(ffOnly.Plan.Allocations.Count == 1 &&
                       ffOnly.Plan.Allocations[0].CpuStart == 0x1010 &&
                       ffOnly.Plan.Allocations[0].Length == 10,
                    "FF-only allocation differs");
                Assert(ffOnly.ChangedOffsets.Count == 0,
                    "FF-only payload changed bytes");
                Assert(ffOnly.OutputImage.SequenceEqual(rom),
                    "FF-only payload did not reproduce the original image");
                Assert(ffOnly.OutputRomSha256 == beforeSha256,
                    "FF-only output identity differs from the original");
            });

            Check("Integrity coverage 1400-FFFF and active fields remain unchanged", () =>
            {
                VmIlIntegrityOriginalVerification original =
                    VmIlIntegrity.VerifyOriginal(rom);
                originalIntegrityFields = original.StoredFieldsHex;
                Assert(originalIntegrityFields == VmIlIntegrity.ExpectedOriginalFieldsHex,
                    "Original active integrity fields differ");
                Assert(whole.IntegrityCoveredRange == "1400-FFFF",
                    "Integrity coverage label differs");
                Assert(whole.OutputIntegrityFieldsHex == originalIntegrityFields,
                    "Whole output active integrity fields differ");
                Assert(whole.IntegrityCoveredBytesUnchanged &&
                       whole.IntegrityFieldsUnchanged,
                    "Whole emission did not report preserved integrity coverage");
                Assert(whole.OutputImage.Slice(0x1400, 0xFFFF - 0x1400 + 1)
                        .SequenceEqual(rom.AsSpan(0x1400, 0xFFFF - 0x1400 + 1)),
                    "Whole emission changed 1400-FFFF integrity coverage");
                Assert(whole.OutputImage.Slice(VmIlIntegrity.SumOffset,
                            VmIlIntegrity.RotateSubXorBOffset -
                            VmIlIntegrity.SumOffset + 1)
                        .SequenceEqual(rom.AsSpan(VmIlIntegrity.SumOffset,
                            VmIlIntegrity.RotateSubXorBOffset -
                            VmIlIntegrity.SumOffset + 1)),
                    "Whole emission changed FFD1-FFD5");
                Assert(whole.ByteChanges.All(change => change.Offset < 0x1400),
                    "Whole changed offset intersects integrity coverage");
                Assert(split.OutputImage.Slice(0x1400, 0xFFFF - 0x1400 + 1)
                        .SequenceEqual(rom.AsSpan(0x1400, 0xFFFF - 0x1400 + 1)) &&
                       partial.OutputImage.Slice(0x1400, 0xFFFF - 0x1400 + 1)
                        .SequenceEqual(rom.AsSpan(0x1400, 0xFFFF - 0x1400 + 1)),
                    "Split or partial emission changed 1400-FFFF integrity coverage");
            });

            Check("Caller ROM and payload buffers cannot mutate an emission", () =>
            {
                byte[] mutableRom = (byte[])rom.Clone();
                byte[] mutableBytes = MakePayloadBytes(64, 0xA1);
                var payload = new ExtensionPayload("mutable", mutableBytes);
                ExtensionRangeEmission emission = ExtensionRangeEmitter.Emit(
                    mutableRom, approved, new[] { payload });
                byte[] before = emission.CopyOutputImage();
                string payloadSha1 = payload.Sha1;
                string payloadSha256 = payload.Sha256;

                mutableBytes[0] ^= 0xFF;
                mutableBytes[63] ^= 0xFF;
                mutableRom[0] ^= 0xFF;
                mutableRom[0x1010] ^= 0xFF;

                Assert(emission.CopyOutputImage().SequenceEqual(before),
                    "Caller buffer mutation changed a completed emission");
                Assert(emission.OutputRomSha256 == HashSha256(before),
                    "Caller mutation changed the recorded output hash");
                Assert(payload.Sha1 == payloadSha1 && payload.Sha256 == payloadSha256,
                    "Payload buffer mutation changed payload evidence");
                Assert(payload.CopyBytes().SequenceEqual(
                        MakePayloadBytes(64, 0xA1)),
                    "Payload did not retain an owned byte copy");

                byte[] payloadCopy = payload.CopyBytes();
                payloadCopy[0] ^= 0xFF;
                Assert(payload.Sha1 == payloadSha1,
                    "Mutating a CopyBytes result changed the payload");

                byte[] outputCopy = emission.CopyOutputImage();
                outputCopy[0x1010] ^= 0xFF;
                Assert(emission.CopyOutputImage().SequenceEqual(before),
                    "Mutating a CopyOutputImage result changed the emission");
            });

            Check("Emission plan payload and diff views are read-only", () =>
            {
                var allocations = (IList<ExtensionRangeAllocation>)whole.Plan.Allocations;
                Assert(allocations.IsReadOnly, "Allocation view is mutable");
                Reject(() => allocations.Add(new ExtensionRangeAllocation(
                    "injected", 0x1010, 0x1010, 4112, 4112, 1)), "read-only");

                var payloadView = (IList<ExtensionEmittedPayload>)whole.Payloads;
                Assert(payloadView.IsReadOnly, "Payload evidence view is mutable");
                Reject(() => payloadView.Add(new ExtensionEmittedPayload(
                    "injected", 0x1010, 0x1010, 4112, 4112, 1, "0", "0")),
                    "read-only");

                var changedView = (IList<int>)whole.ChangedOffsets;
                Assert(changedView.IsReadOnly, "Changed-offset view is mutable");
                Reject(() => changedView.Add(0x1010), "read-only");

                var changesView = (IList<ExtensionByteChange>)whole.ByteChanges;
                Assert(changesView.IsReadOnly, "Byte-change evidence view is mutable");
                Reject(() => changesView.Add(
                    new ExtensionByteChange(0x1010, 0xFF, 0x00)), "read-only");

                Assert(whole.Plan.Allocations.Count == 1 &&
                       whole.Payloads.Count == 1 &&
                       whole.ChangedOffsets.Count == whole.ByteChanges.Count,
                    "Read-only rejection mutated an emission view");
            });

            Check("Wrong original length and SHA1 identity are rejected before output", () =>
            {
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom.AsSpan(0, rom.Length - 1), approved,
                        new[] { wholePayload }), "length");
                byte[] tamperedCoverage = (byte[])rom.Clone();
                tamperedCoverage[0x1400] ^= 1;
                Reject(() => ExtensionRangeEmitter.Emit(
                        tamperedCoverage, approved,
                        new[] { wholePayload }), "SHA1");
                byte[] tamperedRange = (byte[])rom.Clone();
                tamperedRange[0x1010] ^= 1;
                Reject(() => ExtensionRangeEmitter.Emit(
                        tamperedRange, approved,
                        new[] { wholePayload }), "SHA1");
            });

            Check("Unsupported or mismatched approved descriptors are rejected", () =>
            {
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom, approved with { Approval = null },
                        new[] { wholePayload }), "approval");
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom, approved with
                        {
                            Approval = ExtensionRangeApproval.Approved with
                            {
                                IsApproved = false
                            }
                        }, new[] { wholePayload }), "approval");
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom, approved with { CpuEnd = 0x13EE },
                        new[] { wholePayload }), "range");
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom, approved with { FileStart = 0x1011, FileEnd = 0x13F0 },
                        new[] { wholePayload }), "file range");
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom, approved with { ExpectedFill = 0x00 },
                        new[] { wholePayload }), "expected fill");
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom, approved with
                        {
                            LeftGuard = new ExtensionRangeGuard(0x1000, 0x100E, 0xFF)
                        }, new[] { wholePayload }), "left guard");
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom, approved with { RightGuard = new ExtensionRangeGuard(
                            0x13EF, 0x13FE, 0xFF) },
                        new[] { wholePayload }), "right guard");
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom, approved with { ProtectedStart = 0x1004 },
                        new[] { wholePayload }), "protected");
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom, approved with { IntegrityStart = 0x1401 },
                        new[] { wholePayload }), "integrity");
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom, approved with
                        {
                            Approval = ExtensionRangeApproval.Approved with
                            {
                                Bank0Only = false
                            }
                        }, new[] { wholePayload }), "bank 0");
            });

            Check("Empty oversized duplicate blank and null payloads are rejected", () =>
            {
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom, approved,
                        new[] { new ExtensionPayload("empty", ReadOnlySpan<byte>.Empty) }),
                    "nonempty");
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom, approved, new[] { MakePayload("too-large", 993, 0x01) }),
                    "capacity");
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom, approved,
                        new[]
                        {
                            MakePayload("first", 500, 0x01),
                            MakePayload("second", 493, 0x02)
                        }), "capacity");
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom, approved,
                        new[]
                        {
                            MakePayload("same", 1, 0x01),
                            MakePayload("same", 1, 0x02)
                        }), "duplicate");
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom, approved,
                        new[]
                        {
                            MakePayload("same", 1, 0x01),
                            MakePayload("SAME", 1, 0x02)
                        }), "duplicate");
                Reject(() => _ = new ExtensionPayload(
                        "   ", new byte[] { 0x00 }), "identifier");
                Reject(() => _ = new ExtensionPayload(
                        null!, new byte[] { 0x00 }), "identifier");
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom, approved, new ExtensionPayload[] { null! }), "missing");
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom, approved, null!), "missing");
            });

            Check("Mismatched caller-supplied plans and payloads are rejected", () =>
            {
                ExtensionRangeAllocator allocator =
                    ExtensionRangeAllocator.Create(rom, approved);
                ExtensionRangePlan matching = allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest("first", 500),
                    new ExtensionAllocationRequest("second", 492)
                });
                ExtensionRangeEmission withMatching = ExtensionRangeEmitter.Emit(
                    rom, approved, matching, new[] { firstPayload, secondPayload });
                Assert(SameEvidence(split, withMatching),
                    "Matching plan did not produce the canonical emission");

                ExtensionRangePlan wrongIdentifier = allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest("first", 500),
                    new ExtensionAllocationRequest("other", 492)
                });
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom, approved, wrongIdentifier,
                        new[] { firstPayload, secondPayload }), "does not match");

                ExtensionRangePlan shortPlan = allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest("only", 1)
                });
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom, approved, shortPlan,
                        new[] { firstPayload, secondPayload }), "does not match");
                Reject(() => ExtensionRangeEmitter.Emit(
                        rom, approved, null!, new[] { firstPayload, secondPayload }),
                    "missing");
            });

            Check("Payload lengths and hashes bind the emitted allocation evidence", () =>
            {
                foreach (ExtensionEmittedPayload payload in whole.Payloads)
                {
                    int length = payload.FileEnd - payload.FileStart + 1;
                    byte[] bytes = whole.OutputImage
                        .Slice(payload.FileStart, length).ToArray();
                    Assert(length == payload.Length,
                        "Payload evidence length differs from its allocation");
                    Assert(HashSha1(bytes) == payload.Sha1,
                        "Payload evidence SHA1 differs from emitted bytes");
                    Assert(HashSha256(bytes) == payload.Sha256,
                        "Payload evidence SHA256 differs from emitted bytes");
                }
            });

            Check("Input ROM hash is unchanged after all emitter checks", () =>
            {
                byte[] after = File.ReadAllBytes(romPath);
                Assert(HashSha1(after) == beforeSha1,
                    "Input ROM SHA1 changed during verification");
                Assert(HashSha256(after) == beforeSha256,
                    "Input ROM SHA256 changed during verification");
            });
        }
        catch
        {
            WriteFailureOutputs(outputDirectory, checks);
            throw;
        }

        byte[] finalBytes = File.ReadAllBytes(romPath);
        string afterSha1 = HashSha1(finalBytes);
        string afterSha256 = HashSha256(finalBytes);

        var wholeAllocations = whole.Payloads.Select(Summary).ToArray();
        var splitAllocations = split.Payloads.Select(Summary).ToArray();
        var partialAllocations = partial.Payloads.Select(Summary).ToArray();
        var limitations = new[]
        {
            "Emitted payload bytes are synthetic unexecuted test data, not certified VM " +
            "instructions or a new composite word, header or native primitive.",
            "The approved range is a human reservation, not proof that the bytes are unused; " +
            "padding appearance alone is not evidence.",
            "No reference redirection, VM entry redirect, linker, fixup, general relocation, " +
            "bank switching or arbitrary out-of-range patch is supported.",
            "Existing firmware integrity verification is used only to prove that the " +
            "covered 1400-FFFF bytes and active FFD1-FFD5 fields are byte-identical. No " +
            "integrity field is regenerated or invented for this outside-coverage emission.",
            "No MAME boot, gameplay, natural execution, new-word execution or physical " +
            "hardware compatibility is claimed.",
            "The result is synthetic/static tooling evidence only."
        };

        var report = new EmitterVerificationReport(
            "il-extension-emitter-30",
            1,
            "passed",
            "Checked deterministic in-memory extension payload emission inside the " +
            "human-approved 1010-13EF bank-0 range for a6ls.p1, preserving guards, " +
            "unallocated FF, all bytes outside allocations and 1400-FFFF integrity coverage.",
            "Synthetic/static tooling evidence from the actual public emitter API plus " +
            "explicitly classified synthetic payload and tamper controls. Not natural ROM " +
            "behaviour and not certified VM instructions.",
            Path.GetFullPath(romPath),
            rom.Length,
            beforeSha1,
            beforeSha256,
            afterSha1,
            afterSha256,
            beforeSha1 == afterSha1 && beforeSha256 == afterSha256,
            "1010-13EF",
            "4112-5103",
            992,
            "1000-100F",
            "13F0-13FF",
            "1000-1003",
            0x1400,
            whole.OutputLength,
            whole.OutputRomSha1,
            whole.OutputRomSha256,
            wholeAllocations,
            whole.ChangedOffsets.Count,
            whole.ChangedOffsets.ToArray(),
            split.OutputRomSha1,
            split.OutputRomSha256,
            splitAllocations,
            split.ChangedOffsets.Count,
            split.ChangedOffsets.ToArray(),
            partial.OutputRomSha1,
            partial.OutputRomSha256,
            partialAllocations,
            partial.ChangedOffsets.Count,
            partial.ChangedOffsets.ToArray(),
            identity.OutputRomSha1,
            identity.OutputRomSha256,
            identity.OutputRomSha256 == beforeSha256,
            ffOnly.OutputRomSha256 == beforeSha256,
            originalIntegrityFields,
            whole.OutputIntegrityFieldsHex,
            whole.IntegrityCoveredBytesUnchanged,
            whole.IntegrityFieldsUnchanged,
            negativeControls,
            checks,
            limitations,
            "Next supported step is a separately scheduled bounded composite-word ABI and " +
            "linker/reference investigation for this exact range. It must retain identity, " +
            "approval, expected-byte, capacity, overlap, preservation and atomicity checks, " +
            "and establish header/entry/return/stack contracts before any redirect.");

        var evidence = new EmitterEvidenceSummary(
            "il-extension-emitter-30",
            1,
            report.Status,
            report.Classification,
            report.EvidenceClass,
            report.ApprovedCpuRange,
            report.ApprovedFileRange,
            report.ApprovedLength,
            "left 1000-100F; right 13F0-13FF",
            report.ProtectedCells,
            report.IntegrityStart,
            new EmitterOriginalIdentity(rom.Length, beforeSha1, beforeSha256),
            new[]
            {
                new EmitterScenarioSummary("whole-992", wholeAllocations,
                    whole.ChangedOffsets.Count, whole.OutputRomSha1, whole.OutputRomSha256),
                new EmitterScenarioSummary("split-500-492", splitAllocations,
                    split.ChangedOffsets.Count, split.OutputRomSha1, split.OutputRomSha256),
                new EmitterScenarioSummary("partial-100-200", partialAllocations,
                    partial.ChangedOffsets.Count, partial.OutputRomSha1,
                    partial.OutputRomSha256)
            },
            new EmitterEmptyPolicySummary(
                identity.OutputRomSha256 == beforeSha256,
                ffOnly.OutputRomSha256 == beforeSha256),
            new EmitterIntegritySummary(
                whole.IntegrityCoveredRange,
                originalIntegrityFields,
                whole.OutputIntegrityFieldsHex,
                whole.IntegrityCoveredBytesUnchanged,
                whole.IntegrityFieldsUnchanged),
            negativeControls,
            checks.Select(check => check.Name).ToArray(),
            limitations,
            report.RemainingChainBoundary);

        WriteOutputs(outputDirectory, report, evidence, whole, split);
        Console.WriteLine(
            $"PASS {checks.Count} emitter verification groups and {negativeControls} " +
            $"negative controls; whole 992-byte payload and 500+492 split are exact and " +
            $"deterministic; output SHA256 {whole.OutputRomSha256}.");
        return report;
    }

    private static byte[] MakePayloadBytes(int length, byte seed) =>
        Enumerable.Range(0, length).Select(index => (byte)(seed + index * 37)).ToArray();

    private static string HashSha1(ReadOnlySpan<byte> bytes) =>
        Convert.ToHexString(SHA1.HashData(bytes));

    private static string HashSha256(ReadOnlySpan<byte> bytes) =>
        Convert.ToHexString(SHA256.HashData(bytes));

    private static string BuildLog(
        EmitterVerificationReport report,
        EmitterEvidenceSummary evidence)
    {
        var builder = new StringBuilder();
        builder.AppendLine("FruitMachineLab il-extension-emitter-30 verification");
        builder.AppendLine("ROM: " + report.RomPath);
        builder.AppendLine("SHA1: " + report.RomSha1Before);
        builder.AppendLine("SHA256: " + report.RomSha256Before);
        builder.AppendLine("ROM length: " + report.RomLength);
        builder.AppendLine("Input unchanged: " + report.InputUnchanged);
        builder.AppendLine("Approved CPU range: " + report.ApprovedCpuRange);
        builder.AppendLine("Approved file range: " + report.ApprovedFileRange);
        builder.AppendLine("Approved length: " + report.ApprovedLength);
        builder.AppendLine("Output length: " + report.OutputLength);
        builder.AppendLine("Whole output SHA1: " + report.WholeOutputSha1);
        builder.AppendLine("Whole output SHA256: " + report.WholeOutputSha256);
        builder.AppendLine("Whole changed count: " + report.WholeChangedCount);
        builder.AppendLine("Split output SHA1: " + report.SplitOutputSha1);
        builder.AppendLine("Split output SHA256: " + report.SplitOutputSha256);
        builder.AppendLine("Split changed count: " + report.SplitChangedCount);
        builder.AppendLine("Partial output SHA1: " + report.PartialOutputSha1);
        builder.AppendLine("Partial output SHA256: " + report.PartialOutputSha256);
        builder.AppendLine("Partial changed count: " + report.PartialChangedCount);
        builder.AppendLine("Identity output SHA1: " + report.IdentityOutputSha1);
        builder.AppendLine("Identity output SHA256: " + report.IdentityOutputSha256);
        builder.AppendLine("Empty request identity: " + report.EmptyRequestIdentity);
        builder.AppendLine("FF-only payload identity: " + report.FfOnlyPayloadIdentity);
        builder.AppendLine("Integrity original fields: " +
            report.IntegrityOriginalFieldsHex);
        builder.AppendLine("Integrity output fields: " + report.IntegrityOutputFieldsHex);
        builder.AppendLine("Integrity covered range unchanged: " +
            report.IntegrityCoveredRangeUnchanged);
        builder.AppendLine("Integrity fields unchanged: " +
            report.IntegrityFieldsUnchanged);
        builder.AppendLine("Negative controls: " + report.NegativeControls);
        foreach (VerificationCheck check in report.Checks)
            builder.AppendLine("PASS " + check.Name);
        builder.AppendLine("Classification: " + report.Classification);
        builder.AppendLine("Evidence class: " + report.EvidenceClass);
        foreach (string limitation in evidence.Limitations)
            builder.AppendLine("LIMIT " + limitation);
        builder.AppendLine("NEXT " + report.RemainingChainBoundary);
        builder.AppendLine("STATUS " + report.Status);
        return builder.ToString();
    }

    private static void WriteOutputs(
        string outputDirectory,
        EmitterVerificationReport report,
        EmitterEvidenceSummary evidence,
        ExtensionRangeEmission whole,
        ExtensionRangeEmission split)
    {
        Directory.CreateDirectory(outputDirectory);
        VerificationOutputs.WriteCreateOnly(
            Path.Combine(outputDirectory, "verification.log"),
            BuildLog(report, evidence));
        VerificationOutputs.WriteCreateOnly(
            Path.Combine(outputDirectory, "verification-report.json"),
            Serialize(report));
        VerificationOutputs.WriteCreateOnly(
            Path.Combine(outputDirectory, "evidence-summary.json"),
            Serialize(evidence));
        WriteBytesCreateOnly(
            Path.Combine(outputDirectory, "whole-emitted.p1"),
            whole.CopyOutputImage());
        WriteBytesCreateOnly(
            Path.Combine(outputDirectory, "split-emitted.p1"),
            split.CopyOutputImage());
    }

    private static string Serialize<T>(T value) =>
        JsonSerializer.Serialize(value,
            new JsonSerializerOptions { WriteIndented = true })
        .Replace("\r\n", "\n", StringComparison.Ordinal) + "\n";

    private static void WriteBytesCreateOnly(string path, byte[] bytes)
    {
        using var stream = new FileStream(
            path, FileMode.CreateNew, FileAccess.Write, FileShare.None);
        stream.Write(bytes);
    }

    private static void WriteFailureOutputs(
        string outputDirectory, IReadOnlyList<VerificationCheck> checks)
    {
        if (Directory.Exists(outputDirectory)) return;
        Directory.CreateDirectory(outputDirectory);
        var builder = new StringBuilder();
        builder.AppendLine("FruitMachineLab il-extension-emitter-30 verification FAILED");
        foreach (VerificationCheck check in checks)
            builder.AppendLine((check.Passed ? "PASS " : "FAIL ") + check.Name +
                (check.Error is null ? string.Empty : ": " + check.Error));
        builder.AppendLine("STATUS failed");
        try
        {
            VerificationOutputs.WriteCreateOnly(
                Path.Combine(outputDirectory, "verification.failure.log"),
                builder.ToString());
        }
        catch (IOException)
        {
        }
    }
}

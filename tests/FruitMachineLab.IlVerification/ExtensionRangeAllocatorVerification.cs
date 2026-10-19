using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using FruitMachineLab.Il;

namespace FruitMachineLab.IlVerification;

internal sealed record AllocatorPlanSummary(
    string Id,
    int CpuStart,
    int CpuEnd,
    int FileStart,
    int FileEnd,
    int Length);

internal sealed record AllocatorVerificationReport(
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
    int AlignmentBytes,
    IReadOnlyList<AllocatorPlanSummary> WholePlan,
    IReadOnlyList<AllocatorPlanSummary> SplitPlan,
    int WholeRemainingCapacity,
    int SplitRemainingCapacity,
    int NegativeControls,
    IReadOnlyList<VerificationCheck> Checks,
    IReadOnlyList<string> Limitations,
    string RemainingChainBoundary);

internal static class ExtensionRangeAllocatorVerification
{
    public static AllocatorVerificationReport Run(
        string romPath, string repositoryRoot, string outputDirectory)
    {
        if (Directory.Exists(outputDirectory))
            throw new IOException($"Output directory already exists: {outputDirectory}");

        byte[] rom = File.ReadAllBytes(romPath);
        string beforeSha1 = Convert.ToHexString(SHA1.HashData(rom));
        string beforeSha256 = Convert.ToHexString(SHA256.HashData(rom));
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

        bool SamePlan(ExtensionRangePlan first, ExtensionRangePlan second) =>
            first.RangeCpuStart == second.RangeCpuStart &&
            first.RangeCpuEnd == second.RangeCpuEnd &&
            first.RangeFileStart == second.RangeFileStart &&
            first.RangeFileEnd == second.RangeFileEnd &&
            first.RangeLength == second.RangeLength &&
            first.AllocatedLength == second.AllocatedLength &&
            first.RemainingCapacity == second.RemainingCapacity &&
            first.Provenance == second.Provenance &&
            first.Allocations.SequenceEqual(second.Allocations);

        AllocatorPlanSummary Summary(ExtensionRangeAllocation allocation) =>
            new(allocation.Id, allocation.CpuStart, allocation.CpuEnd,
                allocation.FileStart, allocation.FileEnd, allocation.Length);

        string curatedPath = Path.Combine(
            repositoryRoot, "evidence", "mpu4", "integrity",
            "il-extension-range-proposal.json");
        ExtensionRangeDescriptor approved = ExtensionRangeDescriptor.Approved;
        ExtensionRangeAllocator allocator = null!;
        ExtensionRangePlan wholePlan = null!;
        ExtensionRangePlan splitPlan = null!;

        try
        {
            Check("Curated approval binds the exact revision range guards and protected cells", () =>
            {
                using var json = JsonDocument.Parse(File.ReadAllText(curatedPath));
                JsonElement approval = json.RootElement.GetProperty("approval");
                JsonElement revision = approval.GetProperty("revision");
                JsonElement range = approval.GetProperty("range");
                JsonElement guards = approval.GetProperty("guards");
                JsonElement proposal = json.RootElement.GetProperty("proposal");

                Assert(approval.GetProperty("status").GetString() ==
                       "approved-reserved-not-allocated",
                    "Curated approval status differs");
                Assert(revision.GetProperty("length").GetInt32() ==
                       ExtensionRangeAllocator.RequiredRomLength,
                    "Curated revision length differs");
                Assert(revision.GetProperty("sha1").GetString()!.Equals(
                        ExtensionRangeAllocator.RequiredRomSha1,
                        StringComparison.OrdinalIgnoreCase),
                    "Curated revision SHA1 differs");
                Assert(revision.GetProperty("sha256").GetString()!.Equals(
                        ExtensionRangeAllocator.RequiredRomSha256,
                        StringComparison.OrdinalIgnoreCase),
                    "Curated revision SHA256 differs");
                Assert(range.GetProperty("cpuStart").GetString() == "1010" &&
                       range.GetProperty("cpuEnd").GetString() == "13EF" &&
                       range.GetProperty("length").GetInt32() == 992,
                    "Curated approved CPU range differs");
                Assert(guards.GetProperty("left").GetString() == "1000-100F" &&
                       guards.GetProperty("right").GetString() == "13F0-13FF" &&
                       guards.GetProperty("protectedCells").GetString() == "1000-1003" &&
                       guards.GetProperty("integrityStart").GetString() == "1400",
                    "Curated guards differ");
                Assert(proposal.GetProperty("cpuStart").GetString() == "1010" &&
                       proposal.GetProperty("cpuEnd").GetString() == "13EF" &&
                       proposal.GetProperty("fileStart").GetInt32() == 4112 &&
                       proposal.GetProperty("fileEnd").GetInt32() == 5103 &&
                       proposal.GetProperty("length").GetInt32() == 992 &&
                       proposal.GetProperty("expectedFill").GetString() == "FF",
                    "Curated proposal range or fill differs");

                Assert(approved.CpuStart == 0x1010 && approved.CpuEnd == 0x13EF &&
                       approved.FileStart == 4112 && approved.FileEnd == 5103 &&
                       approved.ExpectedFill == 0xFF &&
                       approved.LeftGuard == new ExtensionRangeGuard(0x1000, 0x100F, 0xFF) &&
                       approved.RightGuard == new ExtensionRangeGuard(0x13F0, 0x13FF, 0xFF) &&
                       approved.ProtectedStart == 0x1000 && approved.ProtectedEnd == 0x1003 &&
                       approved.IntegrityStart == 0x1400 &&
                       approved.Approval is not null &&
                       approved.Approval.IsApproved &&
                       approved.Approval.Bank0Only,
                    "Typed approved descriptor differs from curated binding");
                Assert(ExtensionRangeAllocator.DescriptorRangeLength(approved) == 992 &&
                       ExtensionRangeAllocator.AlignmentBytes == 1,
                    "Typed descriptor length or alignment differs");
                ExtensionRangeApproval typedApproval = approved.Approval!;
                Assert(typedApproval.RomLength == 65536 &&
                       typedApproval.RomSha1.Equals(
                           ExtensionRangeAllocator.RequiredRomSha1,
                           StringComparison.OrdinalIgnoreCase) &&
                       typedApproval.RomSha256.Equals(
                           ExtensionRangeAllocator.RequiredRomSha256,
                           StringComparison.OrdinalIgnoreCase),
                    "Typed approval revision binding differs");
            });

            Check("Exact original identity and approved descriptor create the planner", () =>
            {
                Assert(rom.Length == 65536, "ROM length differs");
                Assert(beforeSha1.Equals(ExtensionRangeAllocator.RequiredRomSha1,
                        StringComparison.OrdinalIgnoreCase),
                    "ROM SHA1 differs");
                Assert(beforeSha256.Equals(ExtensionRangeAllocator.RequiredRomSha256,
                        StringComparison.OrdinalIgnoreCase),
                    "ROM SHA256 differs");
                allocator = ExtensionRangeAllocator.Create(rom, approved);
                Assert(allocator.Descriptor == approved, "Planner descriptor differs");
                Assert(allocator.OriginalRomSha1 == beforeSha1,
                    "Planner original SHA1 differs");
                Assert(allocator.OriginalRomSha256 == beforeSha256,
                    "Planner original SHA256 differs");
                Assert(allocator.Descriptor.Approval!.IsApproved,
                    "Planner did not retain the approved binding");
            });

            Check("Entire 992-byte range allocates at the exact CPU and file boundaries", () =>
            {
                wholePlan = allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest("whole", 992)
                });
                Assert(wholePlan.Allocations.Count == 1, "Whole allocation count differs");
                ExtensionRangeAllocation allocation = wholePlan.Allocations[0];
                Assert(allocation.Id == "whole" && allocation.Length == 992,
                    "Whole allocation identity or length differs");
                Assert(allocation.CpuStart == 0x1010 && allocation.CpuEnd == 0x13EF,
                    "Whole allocation CPU boundaries differ");
                Assert(allocation.FileStart == 4112 && allocation.FileEnd == 5103,
                    "Whole allocation file boundaries differ");
                Assert(allocation.CpuEndExclusive == 0x13F0 &&
                       allocation.FileEndExclusive == 5104,
                    "Whole allocation end-exclusive boundaries differ");
                Assert(wholePlan.AllocatedLength == 992 &&
                       wholePlan.RangeLength == 992 &&
                       wholePlan.RemainingCapacity == 0,
                    "Whole allocation capacity differs");
                Assert(wholePlan.RangeCpuStart == 0x1010 &&
                       wholePlan.RangeCpuEnd == 0x13EF &&
                       wholePlan.RangeFileStart == 4112 &&
                       wholePlan.RangeFileEnd == 5103,
                    "Whole plan range differs");
                Assert(wholePlan.Provenance.Contains("no ROM mutation",
                        StringComparison.OrdinalIgnoreCase),
                    "Whole plan provenance does not state the mutation boundary");
            });

            Check("500 plus 492 allocates contiguous exact boundaries and zero remainder", () =>
            {
                splitPlan = allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest("first", 500),
                    new ExtensionAllocationRequest("second", 492)
                });
                Assert(splitPlan.Allocations.Count == 2, "Split allocation count differs");
                ExtensionRangeAllocation first = splitPlan.Allocations[0];
                ExtensionRangeAllocation second = splitPlan.Allocations[1];
                Assert(first.Id == "first" && first.Length == 500,
                    "First split allocation identity or length differs");
                Assert(first.CpuStart == 0x1010 && first.CpuEnd == 0x1203,
                    "First split CPU boundaries differ");
                Assert(first.FileStart == 4112 && first.FileEnd == 4611,
                    "First split file boundaries differ");
                Assert(second.Id == "second" && second.Length == 492,
                    "Second split allocation identity or length differs");
                Assert(second.CpuStart == 0x1204 && second.CpuEnd == 0x13EF,
                    "Second split CPU boundaries differ");
                Assert(second.FileStart == 4612 && second.FileEnd == 5103,
                    "Second split file boundaries differ");
                Assert(first.CpuEnd + 1 == second.CpuStart &&
                       first.FileEnd + 1 == second.FileStart,
                    "Split allocations are not exactly contiguous");
                Assert(splitPlan.AllocatedLength == 992 &&
                       splitPlan.RemainingCapacity == 0,
                    "Split allocation capacity differs");
            });

            Check("Repeated planning is deterministic for the same request sequence", () =>
            {
                ExtensionRangePlan repeatedWhole = allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest("whole", 992)
                });
                ExtensionRangePlan repeatedSplit = allocator.Plan(new List<ExtensionAllocationRequest>
                {
                    new("first", 500),
                    new("second", 492)
                });
                Assert(SamePlan(wholePlan, repeatedWhole),
                    "Repeated whole plan differs");
                Assert(SamePlan(splitPlan, repeatedSplit),
                    "Repeated split plan differs");
            });

            Check("Partial allocations leave exact remaining capacity and byte alignment", () =>
            {
                ExtensionRangePlan partial = allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest("one", 100),
                    new ExtensionAllocationRequest("two", 200)
                });
                Assert(partial.Allocations.Count == 2, "Partial allocation count differs");
                Assert(partial.Allocations[0].CpuStart == 0x1010 &&
                       partial.Allocations[0].CpuEnd == 0x1073,
                    "First partial CPU boundaries differ");
                Assert(partial.Allocations[1].CpuStart == 0x1074 &&
                       partial.Allocations[1].CpuEnd == 0x113B,
                    "Second partial CPU boundaries differ");
                Assert(partial.AllocatedLength == 300 &&
                       partial.RemainingCapacity == 692,
                    "Partial capacity differs");
                Assert(partial.Allocations.All(allocation =>
                        allocation.CpuStart >= 0x1010 && allocation.CpuEnd <= 0x13EF &&
                        allocation.FileStart == allocation.CpuStart &&
                        allocation.FileEnd == allocation.CpuEnd),
                    "Partial allocation escaped the approved byte-aligned range");
                ExtensionRangePlan empty = allocator.Plan(
                    Array.Empty<ExtensionAllocationRequest>());
                Assert(empty.Allocations.Count == 0 &&
                       empty.AllocatedLength == 0 &&
                       empty.RemainingCapacity == 992,
                    "Empty plan does not expose the full remaining capacity");
            });

            Check("Zero negative int-maximum 993 and total-993 requests are rejected", () =>
            {
                Reject(() => allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest("zero", 0)
                }), "positive");
                Reject(() => allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest("negative", -1)
                }), "positive");
                Reject(() => allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest("maximum", int.MaxValue)
                }), "capacity");
                Reject(() => allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest("too-large", 993)
                }), "capacity");
                Reject(() => allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest("first", 500),
                    new ExtensionAllocationRequest("second", 493)
                }), "capacity");
                Reject(() => allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest("first", int.MaxValue),
                    new ExtensionAllocationRequest("second", int.MaxValue)
                }), "capacity");
            });

            Check("Duplicate and missing or whitespace allocation identifiers are rejected", () =>
            {
                Reject(() => allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest("same", 1),
                    new ExtensionAllocationRequest("same", 1)
                }), "duplicate");
                Reject(() => allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest("same", 1),
                    new ExtensionAllocationRequest("SAME", 1)
                }), "duplicate");
                Reject(() => allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest(null!, 1)
                }), "identifier");
                Reject(() => allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest(string.Empty, 1)
                }), "identifier");
                Reject(() => allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest("   ", 1)
                }), "identifier");
                Reject(() => allocator.Plan(new ExtensionAllocationRequest[]
                {
                    null!
                }), "missing");
                Reject(() => allocator.Plan(null!), "missing");
            });

            Check("Failed operations leave allocator state and capacity unchanged", () =>
            {
                var requests = new[] { new ExtensionAllocationRequest("kept", 123) };
                ExtensionRangePlan baseline = allocator.Plan(requests);
                Reject(() => allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest("kept", 1),
                    new ExtensionAllocationRequest("kept", 1)
                }), "duplicate");
                Reject(() => allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest("kept", 993)
                }), "capacity");
                Reject(() => allocator.Plan(new[]
                {
                    new ExtensionAllocationRequest("kept", 0)
                }), "positive");
                ExtensionRangePlan afterFailure = allocator.Plan(requests);
                Assert(SamePlan(baseline, afterFailure),
                    "Failed allocation attempt changed subsequent planning");
                Assert(afterFailure.AllocatedLength == 123 &&
                       afterFailure.RemainingCapacity == 869,
                    "Failed allocation attempt consumed capacity");
            });

            Check("Caller request and ROM buffers cannot mutate plan or planner state", () =>
            {
                var requests = new List<ExtensionAllocationRequest>
                {
                    new("stable", 10)
                };
                ExtensionRangePlan first = allocator.Plan(requests);
                requests.Add(new ExtensionAllocationRequest("later", 20));
                requests[0] = new ExtensionAllocationRequest("changed", 30);
                Assert(first.Allocations.Count == 1 &&
                       first.Allocations[0].Id == "stable" &&
                       first.Allocations[0].Length == 10,
                    "Caller list mutation changed a completed plan");
                ExtensionRangePlan second = allocator.Plan(requests);
                Assert(second.Allocations.Count == 2 &&
                       second.Allocations[0].Id == "changed" &&
                       second.Allocations[0].Length == 30,
                    "Planner did not copy caller request values");

                var view = (IList<ExtensionRangeAllocation>)first.Allocations;
                Assert(view.IsReadOnly, "Plan allocation view is mutable");
                Reject(() => view.Add(new ExtensionRangeAllocation(
                    "injected", 0x1010, 0x1010, 4112, 4112, 1)), "read-only");
                Assert(first.Allocations.Count == 1,
                    "Plan allocation view was mutated through a cast");

                byte[] mutableRom = (byte[])rom.Clone();
                ExtensionRangeAllocator isolated =
                    ExtensionRangeAllocator.Create(mutableRom, approved);
                ExtensionRangePlan beforeMutation = isolated.Plan(new[]
                {
                    new ExtensionAllocationRequest("isolated", 7)
                });
                mutableRom[0x1010] = 0x00;
                ExtensionRangePlan afterMutation = isolated.Plan(new[]
                {
                    new ExtensionAllocationRequest("isolated", 7)
                });
                Assert(SamePlan(beforeMutation, afterMutation),
                    "Mutating the caller ROM buffer changed planner state");
            });

            Check("Wrong length SHA1 and SHA256 original identities are rejected", () =>
            {
                Reject(() => ExtensionRangeAllocator.Create(
                        rom.AsSpan(0, rom.Length - 1), approved), "length");
                byte[] tampered = (byte[])rom.Clone();
                tampered[0x1400] ^= 1;
                Reject(() => ExtensionRangeAllocator.Create(tampered, approved), "SHA1");
                Reject(() => NineEdNineDecoder.ValidateIdentity(
                        rom, 65536, ExtensionRangeAllocator.RequiredRomSha1,
                        new string('0', 64)), "SHA256");
            });

            Check("Missing unapproved and mismatched approval bindings are rejected", () =>
            {
                Reject(() => ExtensionRangeAllocator.Create(
                        rom, approved with { Approval = null }), "approval");
                Reject(() => ExtensionRangeAllocator.Create(rom, approved with
                {
                    Approval = ExtensionRangeApproval.Approved with { IsApproved = false }
                }), "approval");
                Reject(() => ExtensionRangeAllocator.Create(rom, approved with
                {
                    Approval = ExtensionRangeApproval.Approved with { CpuEnd = 0x13EE }
                }), "Approval binding");
                Reject(() => ExtensionRangeAllocator.Create(rom, approved with
                {
                    Approval = ExtensionRangeApproval.Approved with
                    {
                        RomSha1 = new string('0', 40)
                    }
                }), "Approval binding");
                Reject(() => ExtensionRangeAllocator.Create(rom, approved with
                {
                    Approval = ExtensionRangeApproval.Approved with { Bank0Only = false }
                }), "bank 0");
            });

            Check("Mismatched range file mapping guards protected cells and integrity start are rejected", () =>
            {
                Reject(() => ExtensionRangeAllocator.Create(rom, approved with
                {
                    CpuStart = 0x1011,
                    CpuEnd = 0x13F0
                }), "range");
                Reject(() => ExtensionRangeAllocator.Create(rom, approved with
                {
                    FileStart = 0x1011,
                    FileEnd = 0x13F0
                }), "file range");
                Reject(() => ExtensionRangeAllocator.Create(rom, approved with
                {
                    RomLength = 65535
                }), "length");
                Reject(() => ExtensionRangeAllocator.Create(rom, approved with
                {
                    RomSha1 = new string('0', 40)
                }), "SHA1");
                Reject(() => ExtensionRangeAllocator.Create(rom, approved with
                {
                    ExpectedFill = 0x00
                }), "expected fill");
                Reject(() => ExtensionRangeAllocator.Create(rom, approved with
                {
                    LeftGuard = new ExtensionRangeGuard(0x1000, 0x100E, 0xFF)
                }), "left guard");
                Reject(() => ExtensionRangeAllocator.Create(rom, approved with
                {
                    LeftGuard = new ExtensionRangeGuard(0x100F, 0x101E, 0xFF)
                }), "left guard");
                Reject(() => ExtensionRangeAllocator.Create(rom, approved with
                {
                    RightGuard = new ExtensionRangeGuard(0x13EF, 0x13FE, 0xFF)
                }), "right guard");
                Reject(() => ExtensionRangeAllocator.Create(rom, approved with
                {
                    ProtectedStart = 0x1004
                }), "protected");
                Reject(() => ExtensionRangeAllocator.Create(rom, approved with
                {
                    IntegrityStart = 0x1401
                }), "integrity");
                Reject(() => ExtensionRangeAllocator.Create(rom, approved with
                {
                    CpuStart = -1
                }), "range");
                Reject(() => ExtensionRangeAllocator.Create(rom, approved with
                {
                    CpuEnd = 65536
                }), "range");
            });

            Check("Synthetic expected-byte tamper controls reject non-FF range and guards", () =>
            {
                byte[] rangeTamper = (byte[])rom.Clone();
                rangeTamper[0x1010] = 0x00;
                Reject(() => ExtensionRangeAllocator.CreateWithoutIdentityForTests(
                        rangeTamper, approved), "approved range");
                byte[] lowRangeTamper = (byte[])rom.Clone();
                lowRangeTamper[0x13EF] = 0x00;
                Reject(() => ExtensionRangeAllocator.CreateWithoutIdentityForTests(
                        lowRangeTamper, approved), "approved range");
                byte[] leftGuardTamper = (byte[])rom.Clone();
                leftGuardTamper[0x1000] = 0x00;
                Reject(() => ExtensionRangeAllocator.CreateWithoutIdentityForTests(
                        leftGuardTamper, approved), "left guard");
                byte[] rightGuardTamper = (byte[])rom.Clone();
                rightGuardTamper[0x13FF] = 0x00;
                Reject(() => ExtensionRangeAllocator.CreateWithoutIdentityForTests(
                        rightGuardTamper, approved), "right guard");
            });

            Check("Input ROM hash is unchanged after all planner checks", () =>
            {
                byte[] after = File.ReadAllBytes(romPath);
                Assert(Convert.ToHexString(SHA1.HashData(after)) == beforeSha1,
                    "Input ROM SHA1 changed during verification");
                Assert(Convert.ToHexString(SHA256.HashData(after)) == beforeSha256,
                    "Input ROM SHA256 changed during verification");
            });
        }
        catch
        {
            WriteFailureOutputs(outputDirectory, checks);
            throw;
        }

        byte[] finalBytes = File.ReadAllBytes(romPath);
        string afterSha1 = Convert.ToHexString(SHA1.HashData(finalBytes));
        string afterSha256 = Convert.ToHexString(SHA256.HashData(finalBytes));
        var report = new AllocatorVerificationReport(
            "il-extension-allocator-29",
            1,
            "passed",
            "Deterministic static allocation planning inside the human-approved 1010-13EF " +
            "bank-0 range for a6ls.p1. No ROM mutation, emission, linker, VM redirect, " +
            "new word, native primitive, MAME run or hardware validation.",
            "Synthetic/static tooling evidence from the actual public planner API plus " +
            "explicitly classified synthetic tamper controls. Not natural ROM behaviour.",
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
            ExtensionRangeAllocator.AlignmentBytes,
            wholePlan.Allocations.Select(Summary).ToArray(),
            splitPlan.Allocations.Select(Summary).ToArray(),
            wholePlan.RemainingCapacity,
            splitPlan.RemainingCapacity,
            negativeControls,
            checks,
            new[]
            {
                "This implements allocation planning only. It writes no ROM, emits no " +
                "patch, links nothing and redirects no VM entry or reference.",
                "The approved range is a human reservation, not proof that the bytes are " +
                "unused; padding appearance alone is not evidence.",
                "The exact original SHA1/SHA256 identity gate precedes expected-fill checks. " +
                "Expected-byte tamper controls therefore use an internal test seam and are " +
                "classified as synthetic, not as natural ROM evidence.",
                "The allocator is limited to CPU/file 1010-13EF, bank 0, byte alignment and " +
                "first-fit request order. No other alignment, bank, relocation or expansion " +
                "is inferred.",
                "No MAME execution, boot, gameplay, new-word execution or hardware " +
                "compatibility is claimed.",
                "The result is synthetic/static tooling evidence only."
            },
            "Next supported step is a bounded linker/value emitter for this exact range " +
            "under separate scheduling; it must retain this allocator's identity, bounds, " +
            "guard, expected-byte, capacity and atomicity checks.");

        WriteOutputs(outputDirectory, report, BuildLog(report));
        Console.WriteLine(
            $"PASS {checks.Count} allocator verification groups and {negativeControls} " +
            $"negative controls; whole 992-byte plan and 500+492 split are exact and " +
            $"deterministic; input SHA256 {afterSha256}.");
        return report;
    }

    private static string BuildLog(AllocatorVerificationReport report)
    {
        var builder = new StringBuilder();
        builder.AppendLine("FruitMachineLab il-extension-allocator-29 verification");
        builder.AppendLine("ROM: " + report.RomPath);
        builder.AppendLine("SHA1: " + report.RomSha1Before);
        builder.AppendLine("SHA256: " + report.RomSha256Before);
        builder.AppendLine("ROM length: " + report.RomLength);
        builder.AppendLine("Input unchanged: " + report.InputUnchanged);
        builder.AppendLine("Approved CPU range: " + report.ApprovedCpuRange);
        builder.AppendLine("Approved file range: " + report.ApprovedFileRange);
        builder.AppendLine("Approved length: " + report.ApprovedLength);
        builder.AppendLine("Left guard: " + report.LeftGuard);
        builder.AppendLine("Right guard: " + report.RightGuard);
        builder.AppendLine("Protected cells: " + report.ProtectedCells);
        builder.AppendLine("Integrity start: " + report.IntegrityStart.ToString("X4"));
        builder.AppendLine("Alignment bytes: " + report.AlignmentBytes);
        builder.AppendLine("Whole plan: " + FormatPlan(report.WholePlan) +
            "; remaining=" + report.WholeRemainingCapacity);
        builder.AppendLine("Split plan: " + FormatPlan(report.SplitPlan) +
            "; remaining=" + report.SplitRemainingCapacity);
        builder.AppendLine("Negative controls: " + report.NegativeControls);
        foreach (VerificationCheck check in report.Checks)
            builder.AppendLine("PASS " + check.Name);
        builder.AppendLine("Classification: " + report.Classification);
        builder.AppendLine("Evidence class: " + report.EvidenceClass);
        foreach (string limitation in report.Limitations)
            builder.AppendLine("LIMIT " + limitation);
        builder.AppendLine("NEXT " + report.RemainingChainBoundary);
        builder.AppendLine("STATUS " + report.Status);
        return builder.ToString();
    }

    private static string FormatPlan(IReadOnlyList<AllocatorPlanSummary> plan) =>
        string.Join("; ", plan.Select(allocation =>
            $"{allocation.Id}=cpu {allocation.CpuStart:X4}-{allocation.CpuEnd:X4} " +
            $"file {allocation.FileStart}-{allocation.FileEnd} len {allocation.Length}"));

    private static void WriteOutputs(
        string outputDirectory, AllocatorVerificationReport report, string log)
    {
        Directory.CreateDirectory(outputDirectory);
        VerificationOutputs.WriteCreateOnly(
            Path.Combine(outputDirectory, "verification.log"), log);
        string json = JsonSerializer.Serialize(
            report, new JsonSerializerOptions { WriteIndented = true });
        VerificationOutputs.WriteCreateOnly(
            Path.Combine(outputDirectory, "verification-report.json"),
            json + Environment.NewLine);
    }

    private static void WriteFailureOutputs(
        string outputDirectory, IReadOnlyList<VerificationCheck> checks)
    {
        if (Directory.Exists(outputDirectory)) return;
        Directory.CreateDirectory(outputDirectory);
        var builder = new StringBuilder();
        builder.AppendLine("FruitMachineLab il-extension-allocator-29 verification FAILED");
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

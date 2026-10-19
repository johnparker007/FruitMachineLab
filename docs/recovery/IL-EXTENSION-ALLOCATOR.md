# IL extension range allocator

Status: **implemented static allocation planning; not a ROM writer or linker**.
This increment adds an independent, deterministic planner for the human-approved
A6L 0.1 set 1 range `1010-13EF`. It mutates no ROM, emits no image or patch,
resolves no references and runs no emulator.

The approved reservation and its evidence remain in
[IL-EXTENSION-RANGE-PROPOSAL.md](IL-EXTENSION-RANGE-PROPOSAL.md) and
`evidence/mpu4/integrity/il-extension-range-proposal.json`. Approval is a human
reservation decision, not proof that the bytes are unused. The allocator does
not infer free space from padding.

## Implementation

`src/FruitMachineLab.Il/ExtensionRangeAllocator.cs` adds:

- `ExtensionRangeApproval`, a narrow typed binding of the approved revision,
  range, guards, protected cells, integrity start and bank-0 restriction. It
  intentionally carries no conversational quotation, date or status prose.
- `ExtensionRangeDescriptor`, the allocation-relevant range model;
  `ExtensionRangeDescriptor.Approved` records the only accepted values.
- `ExtensionAllocationRequest(string Id, int Length)`.
- `ExtensionRangeAllocation` with CPU/file start, inclusive end and length.
- `ExtensionRangePlan` with an immutable allocation view, remaining capacity and
  provenance.
- `ExtensionRangeAllocator.Create(originalRom, descriptor)` and
  `ExtensionRangeAllocator.Plan(requests)`.

The planner is immutable after creation. `Create` validates, in order:

1. The exact original 65536-byte SHA1
   `402d1518bb78fdc489b06c2aabc771e5ce151847` and SHA256
   `ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c`
   through the existing strict IL identity gate.
2. A present and approved binding, matching the exact revision, `1010-13EF`
   range, `1000-100F` and `13F0-13FF` guards, `1000-1003` protected cells,
   `1400` integrity start and bank 0.
3. CPU/file same-offset mapping and exact file offsets `4112-5103`.
4. Non-overlap and contiguity of the approved range, guards, protected cells and
   integrity boundary, with checked arithmetic and ROM bounds.
5. Expected `FF` contents over the approved range and both guards, plus a
   descriptor expected fill of `FF`.

`Plan` copies the caller's request sequence, rejects missing requests, blank
identifiers, case-insensitive duplicate identifiers, nonpositive lengths,
lengths greater than 992, total requests greater than 992 and any arithmetic
overflow, then allocates in request order with byte alignment. Every allocation
is checked against the approved CPU and file bounds and the completed plan is
checked for overlap. Failures occur before any result is created, so the
allocator's state and remaining capacity are unchanged.

`Plan` returns a read-only view over a private allocation copy. Caller lists,
descriptor values and caller ROM buffers cannot mutate a completed plan or the
planner's validated binding.

## Deterministic boundaries

For the approved byte-aligned range, the required acceptance plans are:

| Request | CPU range | File range | Length | Remaining |
| --- | --- | --- | ---: | ---: |
| `whole=992` | `1010-13EF` | `4112-5103` | 992 | 0 |
| `first=500` | `1010-1203` | `4112-4611` | 500 | 0 |
| `second=492` | `1204-13EF` | `4612-5103` | 492 | 0 |

Repeated planning with the same request order produces identical named
allocations, boundaries, capacity and provenance.

## Verification

`tests/FruitMachineLab.IlVerification/ExtensionRangeAllocatorVerification.cs`
runs through the existing dependency-free IL verifier and writes a fresh report
under the requested private output directory. The focused evidence is:

- `artifacts/deepseek/il-extension-allocator-29/run-il-02/allocator/verification-report.json`
- `artifacts/deepseek/il-extension-allocator-29/run-il-02/allocator/verification.log`
- `evidence/mpu4/integrity/il-extension-allocator.json`

The focused run passed 15 allocator groups and 41 negative controls, including
the whole-range plan, the contiguous `500+492` split, deterministic repetition,
partial capacity, zero/negative/int-max/993/total-993 rejection, duplicate and
blank identifiers, failed-operation atomicity, caller-input immutability,
length/SHA1/SHA256 identity rejection, missing/unapproved/mismatched approval,
range/file/guard/protected/integrity mismatch, out-of-bounds requests and a
synthetic non-`FF` range/guard tamper. The original input hashes were unchanged.

The exact identity gate runs before expected-fill checks, so a public-API ROM
tamper is rejected as an identity mismatch. The non-`FF` content controls use an
internal test seam and are labelled **synthetic**; they are not natural ROM
evidence. All allocator results are **synthetic/static tooling evidence only**.

## Boundaries and next step

Not implemented or claimed:

- ROM mutation, patch emission, output images or integrity regeneration;
- a linker, fixups, VM entry/reference redirection or native trampolines;
- new composite VM words or new 6809 primitives;
- MAME boot/gameplay observation, natural execution or hardware validation;
- other revisions, other ranges, bank switching, general relocation, other
  alignment rules or a whole-ROM no-use proof.

The next supported step is a separately scheduled bounded linker/value emitter
for this exact range. It must retain this allocator's identity, approval,
bounds, guard, expected-byte, capacity, overlap and failed-operation atomicity
checks.

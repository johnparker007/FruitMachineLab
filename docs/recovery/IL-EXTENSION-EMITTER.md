# IL extension payload emitter

Status: **implemented bounded in-memory payload emission; not a linker, ROM
editor for arbitrary bytes, VM redirect or emulator run**. This increment adds a
checked emitter for the human-approved A6L 0.1 set 1 range `1010-13EF`. It reuses
the allocator from
[IL-EXTENSION-ALLOCATOR.md](IL-EXTENSION-ALLOCATOR.md) and the existing
[extension range reservation](IL-EXTENSION-RANGE-PROPOSAL.md). It does not resolve
references, encode composite words/headers, redirect a VM entry, run MAME or
claim natural execution.

The approved range remains a human reservation, not proof that the bytes are
unused. Emitted test payloads in this task are **synthetic unexecuted data**; they
are not certified VM instructions, headers, composite words or native primitives.

## Implementation

`src/FruitMachineLab.Il/ExtensionRangeEmitter.cs` adds:

- `ExtensionPayload(string Id, ReadOnlySpan<byte> Bytes)`: copies the caller's
  bytes, rejects blank identifiers, and exposes the owned bytes only through
  `ReadOnlySpan<byte>` plus `CopyBytes()`. Payload SHA1/SHA256 are recorded from
  the owned copy.
- `ExtensionRangeEmitter.Emit(originalRom, descriptor, payloads)`: derives the
  allocation plan internally from the payload identifiers and lengths and returns
  an `ExtensionRangeEmission`.
- `ExtensionRangeEmitter.Emit(originalRom, descriptor, expectedPlan, payloads)`:
  the same canonical derivation plus an exact comparison with a caller-supplied
  plan. A forged, stale or mismatched plan is rejected; it is never used as the
  source of allocation records.
- `ExtensionRangeEmission`: immutable output image view, allocation-bound payload
  evidence, changed offsets and before/after byte changes, original/output SHA1
  and SHA256, build identity, integrity coverage evidence and provenance.

## Validation and atomicity

`Emit` performs all checks before any result is returned:

1. The payload sequence is copied and `null` entries are rejected. Blank
   identifiers are rejected by `ExtensionPayload`; empty payloads are rejected by
   `Emit`.
2. Request lengths are derived from the copied payloads, so caller-supplied
   allocation records cannot bypass validation. The existing allocator validates
   the exact original 65536-byte SHA1/SHA256 identity, the typed approval binding,
   the exact `1010-13EF` CPU/file range, bank 0, the `1000-100F`/`13F0-13FF`
   guards, `1000-1003` protected cells, the `1400` integrity start, all-`FF`
   range/guard contents, bounds and overlap.
3. Duplicate identifiers (case-insensitive), nonpositive lengths, lengths over
   992 and total capacity over 992 are rejected by the allocator before allocation
   completes.
4. If a plan is supplied, its range, capacity, provenance and every allocation
   must exactly match the internally derived plan.
5. Every byte of every allocation span in the original image is re-checked for
   the approved `FF` fill before emission.
6. Only then is the original image copied into a new owned `byte[]` and the
   payload bytes are written at the derived file offsets. No arbitrary patch or
   out-of-range write exists.
7. The completed image is re-checked: every byte outside an actual allocation
   must equal the original; each allocation must contain its payload; the left
   guard, original prefix, right guard, unallocated approved-range bytes and all
   remaining bytes must be preserved.
8. `VmIlIntegrity.VerifyOriginal` is run on the original to establish the
   recovered integrity record order and original fields. The output must retain
   the entire `1400-FFFF` covered range and the active `FFD1-FFD5` fields
   byte-identically. No integrity field is regenerated or invented because this
   emission is outside the checker's covered range.
9. Original/output hashes, payload hashes and the exact changed-byte diff are
   recorded against the emitted image.

A failed check returns no emission and has no external filesystem effect. Empty
requests are explicitly supported: they return a byte-identical 65536-byte image
with an empty plan and no changes. A payload consisting only of `FF` is also an
explicit identity result, even though its allocation exists. The result's
allocation, payload, changed-offset and byte-change views are read-only copies;
`OutputImage`, payload bytes and hash evidence cannot be mutated through the
returned API.

## Deterministic boundaries

For deterministic synthetic payloads the accepted plans are:

| Scenario | Payloads | CPU/file ranges | Capacity |
| --- | --- | --- | --- |
| `whole-992` | `whole=992` | `1010-13EF` | 0 remaining |
| `split-500-492` | `first=500`, `second=492` | `1010-1203`, `1204-13EF` | 0 remaining |
| `partial-100-200` | `part-one=100`, `part-two=200` | `1010-1073`, `1074-113B` | 692 remaining |

Repeated emissions with the same payload order reproduce identical plans, output
hashes, changed offsets and byte-change evidence. The full-range emitted test
image is 65536 bytes and differs from the original only inside `1010-13EF`.

## Verification

`tests/FruitMachineLab.IlVerification/ExtensionRangeEmitterVerification.cs` runs
through the existing dependency-free IL verifier and writes a fresh report and
private emitted test ROMs under the requested output directory. The focused run
passed **14 emitter groups and 29 negative controls**, alongside the unchanged
20 `9ED9`, 9 `9A64` and 15 allocator groups.

Covered checks include the approved descriptor, one-payload full capacity, the
`500+492` contiguous split, deterministic repetition, partial-plan preservation,
empty-request and all-`FF` identity policies, integrity `1400-FFFF`/`FFD1-FFD5`
preservation, ROM and payload caller immutability, read-only result views, wrong
length/SHA1 identity, unsupported/mismatched descriptors, empty/oversized/
duplicate/blank/null payloads, mismatched caller plans, payload/allocation hash
binding and final input-ROM immutability. Negative controls are explicitly
**synthetic/static tooling evidence**, not natural ROM behaviour.

Accepted evidence:

- `artifacts/deepseek/il-extension-emitter-30/run-il-01/emitter/verification-report.json`
- `artifacts/deepseek/il-extension-emitter-30/run-il-01/emitter/evidence-summary.json`
- `evidence/mpu4/integrity/il-extension-emitter.json`
- private emitted ROMs under `artifacts/deepseek/il-extension-emitter-30/` only
  (never tracked)

For the deterministic whole-992 scenario the output is 65536 bytes, SHA1
`5180308AD7F30F861505D6626ABD84A020EBD4C3`, SHA256
`45DD81C808881FA1BBF4BFF22256EC9702498FD8EF329182C8A5F37A257C1313`. The
deterministic split-500/492 output SHA256 is
`C8B5AB2DDDBD86141531EF1ABB3273AD8A8F51427FD01595CB804B239AA163AA`.

## Boundaries and next step

Not implemented or claimed:

- composite VM word/header encoding, dictionary entries or callable definitions;
- reference resolution, VM entry/reference redirection, trampolines or fixups;
- a general linker, relocation, bank switching or ROM expansion;
- integrity regeneration for edits inside `1400-FFFF`;
- MAME boot/gameplay, natural execution, new-word execution or hardware
  validation;
- other revisions, other ranges or a whole-ROM no-use proof.

The next supported step is a bounded composite-word ABI and linking/reference
investigation for this exact range. It must establish header, entry, return,
stack and caller conventions from evidence before any redirect, and must retain
this emitter's identity, approval, expected-byte, capacity, overlap,
preservation and failed-operation atomicity checks.

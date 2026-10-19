# Bounded IL composite-word build

Status: **static compiled and integrity-repaired only; not executed.**
Task `il-composite-build-33` started from `main`
`cb94a94f2b4d83dd2fbb8a9e69b5178ae705d003`. It implements exactly one
reviewed proposal from the [composite-word contract](IL-COMPOSITE-CONTRACT.md):
a new definition header at `1010` (`00F8`), a byte-identical copy of the
certified `9ED9` body at `1012-101F`, and one same-size caller token replacement
`9ED7 -> 1010` at `9F14`.

Task `il-composite-immutability-34` subsequently repaired a caller-aliasing
defect in the new public result surfaces without changing the emitted image,
diff or integrity fields. The source-map node/entry/phase arrays are now cloned
into `ReadOnlyCollection<T>` wrappers, and the composite build snapshots its
`VmIlIntegrityReport` privately and returns a fresh defensive copy of the field
list and offset arrays on every access. Caller mutation can therefore no longer
reach the validated build records. The task33 raw reports and private outputs
remain under `artifacts/deepseek/il-composite-build-33/` unchanged.

Machine-readable metadata:
`evidence/mpu4/integrity/il-composite-build.json`.

## Implementation

`src/FruitMachineLab.Il/CompositeWordBuilder.cs` independently decodes the
original `9ED9` definition with `NineEdNineDecoder`, validates the certified
token/handler evidence and caller context, re-emits the five decoded nodes at
their copied addresses and refuses any token outside `795B`, `787E`, `7AAF` and
`792F`. It reuses `ExtensionRangeAllocator` and `ExtensionRangeEmitter` for the
16-byte allocation at `1010-101F`, then applies the single caller patch.

`src/FruitMachineLab.Il/VmIlIntegrity.cs` gains the narrow
`RepairComposite(originalImage, unrepairedImage, VmIlCompositePatchSpec)` API.
It accepts only the exact `1010-101F` `FF` allocation containing the reviewed
`00F8` header plus certified body, and only the exact `9F14` `9ED7 -> 1010`
two-byte caller. It validates every expected before/after byte, rejects
unexpected changes, overlapping spans, pre-modified active fields, guard or
field tampering, recomputes only `FFD1`/`FFD2`, then `FFD3`, then `FFD4`/`FFD5`
in the recovered order and verifies the result. The fixed `Repair`/`9EDC` API
and its regressions are unchanged.

`src/FruitMachineLab.Il/CompositeWordSourceMap.cs` provides a dedicated
`CompositeWordSourceMap` bound to the final repaired-image SHA256. It maps the
new header, every body byte and the caller token/successor, records the native
handler for each node, and carries the caller dispatch, header-trampoline entry,
five body prefetches, four native handler entries, return handler and
post-return prefetch as `static_compiled_map_not_execution_proof`. Existing
`VmIlSourceMap` APIs are unchanged.

The builder result owns cloned image/payload/diff arrays, exposes read-only
views and copy methods, and carries the original and output SHA1/SHA256
identities. Its `Nodes`, `Entries`, `Phases`, offset and byte-change collections
are read-only wrappers, not exposed arrays. `IntegrityReport` is copied on every
get, including its `Fields` list and all three `int[]` offset arrays, so mutating
a returned report cannot alter the retained build snapshot. The caller's ROM
buffer is never mutated.

## Exact result

| Item | Value |
| --- | --- |
| New header | `1010` = `00F8` |
| New body | `1012-101F` = `795BFF80787E795BFF807AAF792F` |
| Caller | `9F14` `9ED7 -> 1010`, same size |
| Original `9ED7`/`9ED9` | unchanged |
| Other caller bytes | unchanged |
| Unrepaired diff | 14 extension changes plus 2 caller bytes = 16 |
| Unrepaired SHA1 / SHA256 | `EEEC7CAB9899A476F010B423C38CF4A18C035903` / `4728A644884396A547CBE32364A10A3ADE96B740807F033E678B33249A691A26` |
| Integrity fields | `3E761E2605 -> E93F3C61B5` |
| Final realized changes | 21: 14 extension, 2 caller, `FFD1-FFD5` |
| Output SHA1 | `DC6381B9883AAFDE372D2C2AA14C817BAE839B21` |
| Output SHA256 | `761F34BAAC06C6F8F5DA963CCADEB276FAE9196EE1C4D9060BC915A314E3903D` |

The unchanged allocation bytes `1014` and `101A` remain `FF`. Guards
`1000-100F`/`13F0-13FF`, unallocated extension bytes, `1400-FFFF` outside the
active fields, checker code, metadata and all opaque original bytes are
preserved.

## Verification

Fresh independent IL verification output for the ownership repair:
`artifacts/deepseek/il-composite-immutability-34/il-verifier-20261019-01/`.
The earlier unchanged-output run remains at
`artifacts/deepseek/il-composite-build-33/il-verifier-20261019-04/`.

The composite suite compares the result with the curated contract rather than
with itself. It independently recomputes the SHA1/SHA256, the unrepaired and
final diffs, the 21-offset changed set and the ordered checksum, and checks the
map entries, header/body/caller distinction, native handlers, `9F16` saved
cursor and `75A9` post-return token. Public negative controls reject wrong
identity, wrong caller location/bytes, invalid allocation range, wrong
header/body payload, extra ROM changes, pre-modified integrity fields,
mismatched map build and caller/result mutation. A dedicated mutation-attempt
group casts the collections to `IList<T>`, tries set/add/remove/clear, mutates
the returned integrity report arrays and field list, and then rechecks map
resolution, the serialized map, the retained report and the final output
fields. The test does not rely on the declared read-only interface type alone.

Observed commands and exits:

```powershell
dotnet build FruitMachineLab.Headless.sln --ignore-failed-sources   # 0
dotnet run --project tests/FruitMachineLab.IlVerification --no-build -- `
  artifacts/deepseek/general-14/roms/original.p1 `
  artifacts/deepseek/il-composite-immutability-34/il-verifier-20261019-01  # 0
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .  # 0, 417 groups
dotnet build FruitMachineLab.sln --ignore-failed-sources            # 0
```

Existing IL groups remain 20 (9ED9), 9 (9A64), 15 (allocator) and 14 (emitter);
the composite suite now adds 9 groups, including the mutation-attempt group.
The full verifier baseline remains 417 groups.

Private next-task artifacts under the fresh verifier root are
`composite/built-repaired.p1`, `composite/built-unrepaired.p1`,
`composite/composite-source-map.json` and `composite/build-report.json`. They
are ignored by git; no ROM binary is tracked.

## Boundaries

Proved at build level:

- The new definition token is exactly `1010` with header `00F8` and the
  certified `9ED9` body at `1012-101F`.
- The only caller change is the same-size `9F14` `9ED7 -> 1010` replacement.
- The final diff is exactly the reviewed 21 bytes, and the ordered checksum
  reproduces `E93F3C61B5`.
- The composite map is bound to the final ROM hash and distinguishes header,
  body token, native handler, caller token and caller return boundary.

Not proved:

- The `1010` word has not been executed; natural reach and runtime behaviour
  remain hypotheses.
- No patched image was booted in MAME and no hardware test was made.
- The purpose of the `9F12` caller remains unresolved; only token-level
  equivalence is claimed.
- General dictionary/header decoding, arbitrary caller selection, relocation,
  banking and other ROM revisions are out of scope.

Next, after review: a natural fresh-boot MAME task using the imgui/BGFX paused
debugger and this final-ROM-bound map should observe the `1010` header/body,
the native handlers, return through `7931` and the saved cursor `9F16`. No
execution proof exists in this slice.

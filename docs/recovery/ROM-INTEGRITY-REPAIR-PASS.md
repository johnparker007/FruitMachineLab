# Ordered repair of the active ROM integrity fields

17 October 2026. This is a bounded increment for the existing equal-size shared
award edit at file offset 30142 (`75BE`, `0A` to `0C`). It derives and applies
the active gate-00 checksum fields in the order required by the original
checker, then compares the original, unrepaired and repaired images by natural
MAME reset execution. It does not patch the checker, gates, ranges, disabled
records or any unrelated byte.

## Evidence classes

- **Static:** the field layout, ranges and dependency order come from the saved
  assembly in `evidence/mpu4/native/66a5.json` and `66db.json`.
- **Natural:** the MAME observations use the original executable and isolated
  fresh run directories. No state, PC, RAM, input or ROM injection is used.
- **Synthetic:** the repair tool and curator negative controls alter temporary
  copies only. They write no accepted binary.

## Dependency order from the original code

The active record is at `FFD1`: start `1400`, end `FFFF`, gate `00`, error `12`.
The checker compares fields in this sequence:

1. `66df-66f1` sums and XORs bytes, redirecting `FFD1` to `FFD6`. The whole
   active expected-field area `FFD1-FFD5` is excluded, so sum/XOR depend on no
   expected field.
2. `6701-6713` performs `ROLB; ADCA ,X; RORB`, redirecting `FFD3` to `FFD6`.
   It excludes `FFD3-FFD5` but reads `FFD1` and `FFD2`, so it must run after
   the regenerated sum and XOR are stored.
3. `671f-6740` performs `LSLB; ADCB #0; SUBB ,X`, the rotate/subtract sequence
   and XOR, redirecting `FFD4` to `FFD6`. It excludes `FFD4-FFD5` but reads
   `FFD1-FFD3`, so it must run after sum, XOR and rotate-add are stored.

Computing all fields on the original image instead produces `407020162A`, not
the repaired `40701CFA02`; the tool's negative control records that difference.

## Exact result

The original image has stored/computed fields `3E761E2605`. Applying only the
award edit changes the computed sum/XOR to `4070`, so the unrepaired image is
rejected by the sum/XOR comparison. Regenerating in the required order gives:

| Field | Offset | Unrepaired | Repaired |
| --- | --- | --- | --- |
| sum | `FFD1` / 65489 | `3E` | `40` |
| xor | `FFD2` / 65490 | `76` | `70` |
| rotate-add | `FFD3` / 65491 | `1E` | `1C` |
| rotate-sub A | `FFD4` / 65492 | `26` | `FA` |
| rotate-sub B | `FFD5` / 65493 | `05` | `02` |

Changed offsets against the original are `30142` for the unrepaired image and
`30142,65489-65493` for the repaired image. The repair changes only
`65489-65493` relative to the unrepaired image.

| Image | SHA1 | SHA256 |
| --- | --- | --- |
| Original | `402d1518bb78fdc489b06c2aabc771e5ce151847` | `ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c` |
| Unrepaired patch | `58e997e6e1d2ef2251ddde18a5d41716d21368c0` | `a67062f32dba37ad4f24c8b1bc6ac92c91e8f3b39ce8f9c21904af0fd1667714` |
| Repaired patch | `ae040f3f130934972b9e651d4dbe36ff24fb4954` | `66162b920b05c537a5c7bce098d883b0551951ed46aa97cd98600a3d7b789796` |

## Natural MAME comparison

All three runs use MAME 0.281 (`0fce5a88...c4b7a`), a fresh isolated directory,
declared-absent NVRAM/configuration, `-noreadconfig`, no input playback and no
state loading. Each run stopped at its first observed boundary.

- **Original:** checksum pass with `expected=3E761E2605`, computed
  `3E 76 1E 26 05`, return to `677E`, then the init tail and first VM entry at
  `76C7` with `X=FDF0`.
- **Unrepaired:** `expected=3E761E2605`, but the first failure was at `674F`
  with `error=12` after computing `sum=40 xor=70`. The log records no
  rotate-add, rotate-sub, success return or VM entry after that failure.
- **Repaired:** `expected=40701CFA02`, computed `40 70 1C FA 02`, return to
  `677E`, init tail `67B3`/`3B1A`, call `7CF6`, and first VM entry `76C7` with
  `X=FDF0`. This is the same VM entry and stream pointer as the original.

The repaired image therefore passes the unmodified original checker code and
reaches the original startup boundary naturally. It is not a checker bypass.

## Reproduction

```powershell
New-Item -ItemType Directory -Force artifacts/deepseek/general-07/roms | Out-Null
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Repair-AddersAwardIntegrity.ps1 `
  -OriginalRom <original-a6ls.p1> `
  -PatchSpec evidence/mpu4/patches/skill-cash-level1-12.json `
  -UnrepairedOutput artifacts/deepseek/general-07/roms/unrepaired.p1 `
  -RepairedOutput artifacts/deepseek/general-07/roms/repaired.p1 `
  -ReportPath evidence/mpu4/integrity/repaired-award-fields.json -NegativeControl
```

The capture and curation commands are recorded in the result artifacts. The
new `Capture-RomIntegrityVariant.ps1` and `Curate-RomIntegrityVariant.ps1` use an
explicit variant identity contract; the earlier original-only curators remain
unchanged.

## Output path preservation

Before any output or report write, the repairer resolves every target and
checks, case-insensitively, that the unrepaired output, repaired output and
optional report are distinct, do not alias the original ROM or patch
specification, do not already exist and have existing parent directories. All
checks run before the first create. Each deliverable, including the report, is
opened with `FileMode.CreateNew`; the tool never overwrites or deletes an
existing target. The writes are independent rather than atomic, so a failure
after an earlier create leaves that earlier create in place.

## Boundaries

Only the existing single-byte award edit is accepted. Only the active gate-00
record is regenerated; the three disabled records are preserved. This does not
establish gameplay equivalence, later token semantics, MAME loader-hash repair,
relocation, general ROM editing or physical-hardware compatibility. The
intervening reset after the first `677E` return remains observed but unexplained.

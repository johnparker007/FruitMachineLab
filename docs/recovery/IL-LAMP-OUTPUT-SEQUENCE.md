# IL lamp output sequence diagnostic

Status: normalized offline diagnostic only. This validator does not verify raw
MAME evidence, source maps, ROM images, replay inputs, inventory provenance or
capture capability. It performs no MAME launch, capture API call, layout load,
button handling, network/external read, installation or configuration change.
`naturalProof` is always false. Source-map/image/replay/inventory/capability
gates remain separate and deferred.

## Files

| Path | Purpose |
| --- | --- |
| `tools/Test-IlLampOutputSequence.ps1` | Tracked checker for one normalized JSONL stream. |
| `tests/worker/Test-IlLampOutputSequence.ps1` | Tracked 51-case self-test harness. It runs the checker as a subprocess and records actual exits and hashes. |
| `docs/recovery/IL-LAMP-OUTPUT-SEQUENCE.md` | This schema and limitation summary. |

Stable checker identity: `taskId=il-lamp-output-sequence-checker`,
`resultSchema=1`. Source attribution: task 82 checker, supervisor-repaired by
task 83, source checker SHA256
`017AB36C190E5C8CAF11585B92F4C0E6DA06040D636430520FCCED60F85D72C8`.

## Usage

Run the checker against an existing normalized stream:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Test-IlLampOutputSequence.ps1 `
  -InputPath <normalized.jsonl> -OutputPath <result.json>
```

Exit 0 means the normalized diagnostic passed. Exit 1 means a validation,
inconclusive or diagnostic failure. Exit 2 means invocation/IO failure. A
nonzero exit never asserts a lamp transition.

Run the self-test with a fresh absolute output directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/worker/Test-IlLampOutputSequence.ps1 `
  -OutDir <fresh-absolute-directory>
```

If `-OutDir` is omitted, a unique directory is created under
`artifacts/deepseek/il-lamp-output-checker-curation-84/`. The harness requires an
absolute path, rejects an existing directory, creates only new directories, and
never recursively deletes or moves a run. All generated paths are checked to be
inside the resolved output root before use. It tests the tracked checker
subprocess; it does not invoke the old task-83 self-test or modify its fixtures.
The 51 cases consist of the original 45 assertions plus six independent
supervisor controls: opaque ID 70001 accepted; changed ID, U, S and Y
corruption, and wrong-case lamp name rejected.

## JSONL schema (version 1)

One UTF-8/ASCII JSON object per line, no blank lines, exactly five records in
this order: `begin`, `baseline`, `clear-return`, `write-pre`, `write-post`.
Each phase occurs exactly once.

Every record has `seq` (integer >= 0, strictly increasing), `time` (finite JSON
number >= 0, nondecreasing) and `type` (the exact phase string). Fields are
closed: missing, unknown, duplicated-phase, misordered and wrongly typed fields
fail. JSON integers are not coerced from strings or fractions.

`begin`: `schema` (integer 1), `synthetic` (boolean).

`baseline` and `clear-return`: `output`, `cpu`, `frames`, `column` (15),
`mask` (1). `frames.before` is exactly `[63,63,63,63]` and `frames.after`
exactly `[62,62,62,62]`. The clear-return CPU is `pc=252`, `y=40726`, `u=1646`,
`s=1944`; `cc` is observed, not pinned.

`write-pre` and `write-post`: `output`, `cpu`, `dp` (0), `muxWord` (7),
`frame` (0..3), `sample` (0..3), `x` (=7+16*frame), `b` (62), `selectedRam` (62).
The pair must share all seven write fields and the output identity. CPU `pc` is
10631 before and 10634 after STB. `cc` may change. `y`, `u` and `s` must be
preserved across the immediate STB pair.

`output`: `id` (opaque nonzero 32-bit integer, stable across all observations),
`name` and `roundtripName` (exact case-sensitive `lamp120`), `get` and `indexed`
(0 or 1, equal). The numeric output-manager ID is not the lamp-name suffix; a
stable nonzero ID such as 70001 is valid. `baseline`, `clear-return` and
`write-pre` observe `get=indexed=1`; `write-post` observes `0/0`.

`cpu`: `pc`, `y`, `u`, `s` are 0..65535 and `cc` is 0..255.

## Classifications

- `valid_diagnostic_synthetic`: complete synthetic stream, exit 0.
- `valid_diagnostic_unverified_provenance`: complete non-synthetic-marked
  stream, exit 0; still not natural proof.
- `inconclusive_unsupported_column` / `inconclusive_unsupported_mask`.
- `inconclusive_no_baseline_one`, `inconclusive_clear_return_output_not_one`,
  `inconclusive_pre_already_zero`, `inconclusive_no_output_transition`,
  `inconclusive_overwritten_before_output`.
- `invalid_diagnostic`: observed value/identity mismatch, such as a changed output
  ID, wrong-case lamp name, altered frame byte or STB register corruption.
- `invalid_structure`: parse, schema, type, field, phase, sequence, time,
  invocation or IO failure.

`reasons` records code, message, line, seq and phase. Fixtures are synthetic
diagnostics; they are not captures, compilation output, timing evidence,
hardware behaviour or proof of rendered lamp output.

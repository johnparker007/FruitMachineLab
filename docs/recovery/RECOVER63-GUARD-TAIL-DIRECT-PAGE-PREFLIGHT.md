# Recover63 guard-tail direct-page preflight

## Outcome

`Mpu4PostPanelGuardExecution` now accepts only the captured `DP=00` branch of
the selected `2851..288E` tail. The constructor rejects `DP!=0` before any
guarded-state read, selected-byte validation or mutation. Negative tests cover
`DP=01` and `DP=FF` with the rejection message and byte-identical memory.

The direct-page operand `0044` and the extended operand `1400` remain fixed at
`00xx`/`1400`. Correct parameterization of the direct-page operand by `DP` has
no independent proof, so it is not implemented. This pass restricts the
captured branch rather than claiming a generic direct-page component.

## ROM input contract

`Mpu4PostPanelGuardExecution` hardcodes the 16 selected instruction byte
strings for timing and observation. Before the guard checks, it now validates
each of those instruction bytes against `Machine.Memory` at its actual address
(`2851..2875` and `288E`). A mismatch throws
`NotSupportedException("2851 guard original selected bytes differ at XXXX")`
with memory unchanged.

Callers must seed the original selected ROM bytes. Both verification groups do
this from the capture61 trace rows, whose opcode windows were already checked
against `a6ls.p1`. This is a fail-closed contract for the selected bytes, not a
general ROM loader, disassembler or 6809 CPU.

## Tests

The two focused `2851` groups remain. New assertions inside the existing
negative group cover:

- `DP=01` and `DP=FF` rejected before mutation.
- A changed selected byte at `2851` rejected before mutation.
- Existing `44`, saved-U, `S`, `1400` rejections and `0525/0677`,
  `0676/07C8` accepts remain unchanged.

Commands and actual exits:

- `dotnet build FruitMachineLab.Headless.sln --ignore-failed-sources` -> `0`,
  0 warnings, 0 errors.
- `dotnet run --project tests/FruitMachineLab.Verification --no-build -- . 2851`
  -> `0`, 2 groups.
- Same command without a filter -> `0`, **417 groups passed**.
- `pwsh -NoProfile -File tools/Update-CuratedManifest.ps1 -Verify` -> `0`,
  1330 entries.

## Limits

Single-machine tests start from the explicit captured `2851` register/stack
state. There is no full 2 KB at `2851`, so no full-RAM prefix or FEC3
comparison is made. Timer3 saved-item `m_counter` is not continuously
decremented and independent timer-entry remaining ticks are not exposed. No
autonomous IRQ, cadence, whole-prefix, Live, audio, hardware or gate-3 claim.
`DP!=0`, a non-selected ROM image and a general CPU remain unsupported.

## Files

- `src/FruitMachineLab.Runtime/Mpu4PostPanelGuardExecution.cs`: DP preflight,
  selected-byte validation, unchanged captured tail.
- `tests/FruitMachineLab.Verification/Program.cs`: trace-seeded ROM bytes,
  DP and changed-byte negatives.
- `docs/recovery/RECOVER62-IRQ-PREFIX-TAIL-PASS.md`: corrected contract note.
- `docs/recovery/RECOVER63-GUARD-TAIL-DIRECT-PAGE-PREFLIGHT.md`: this report.
- `evidence/mpu4/collection/irq-prefix-capture61.json`: existing capture.
- `evidence/curated-manifest.json`: RECOVER62 and RECOVER63 entries.
- `artifacts/deepseek/recover-63/`: result, logs and exit files.

## Next task

Compose the captured outer FE70 2 KB and existing prefix components through
`Mpu4PostPanelExecution` into this tail, then compare the captured FEC3 full
2 KB, stack words, `2C=FF`, cycles and nested timer3 occupancy. Stop at the
first mismatch, unsupported `C6`/`4167`, active `6403`, `7CCF` or SWI.

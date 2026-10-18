# Recover49 foreground setup preflight correction

## Outcome

Closed the selected foreground setup's allocation gap. Recover48 permitted a
zero native free-list head at `0049`, wrote the wrapper stack and `004D`, then
the native queue skipped allocation and failed with `!Active`. The setup now
requires a real native allocation: a zero head is rejected before any mutation,
and a nonzero head reuses `AddersSoundLifecycleMemory.ValidateTask` before the
same wrapper runs. No new allocator or list semantics were introduced.

## Stack boundary

The exact deepest frame below the `5A14` entry is `22` bytes:
`5A14 PSHS2 + BSR59FF2 + 59FF PSHS2 + BSR59D9 2 + 59D9 PSHS4 = 12`, then
`JSR5C18 2 + 5C1B PSHS6 + BSR5C51 2 = 22`. The transient `60C8 PSHS B/LEAS3`
frame is shallower. The previous comment incorrectly attributed the wrapper
frames to `5C7A`; it now names `5A14/59D9`.

`S=21` is rejected by preflight with full memory unchanged. `S=22` executes
the real wrapper and queue: queue entry `S=8`, final `S=16`, and the deepest
`BSR5C51` return word `5C21` is confined to addresses `0000/0001`. The `S=22`
run is a source stack-boundary check on the captured `FC4D` frame, not a new
captured occurrence, so it asserts confinement and native allocation rather
than a full captured snapshot.

## Branch cost

At `59FF`, `TFR A,B` makes `B=91` (A was loaded with `91`). `59DB SUBB #60`
therefore produces `31`, `N=0`, and `BPL59E1` is taken; `59E1 CB60` is not
executed on the selected path. The execution now carries that outcome
explicitly (`2A02` taken=true) and only costs `CB60` on a negative branch,
matching the source-derived `WrapperCycles` branch flag.

## Negative controls

All reject before mutation with the pre-rejection memory image unchanged:
`stack` (`S<22`), `pool` (`0049=0`), `poolPointer` (`0049=1234`),
`gate` (`719B` bit80), `ownership` (already-active root), `owner` (different
machine), `servicing`, `paused`, and `missingROM` at region load. `snapshot`
still reaches and fails the full-2 KB `5C18` comparison. The empty-pool and
invalid-pool cases are semantic checks, not hash short circuits.

## Evidence classes

- Static original ROM: unchanged `5A14/59FF/59D9/5C18/5C4F/59E9` bytes,
  rechecked from the curated oracle31 `rom_regions`.
- Fresh oracle31: `collection/fresh-tone-occurrence.json`, `FC4D` 2 KB frame,
  `5A14/5A05` markers and the 16-byte foreground delta.
- Source-derived execution and timing: the existing `AddersSoundQueuePlan` /
  `AddersNativeSound` owner and `M6809InstructionTiming`; `0049` is still the
  real free-list head, with no injected budget or cloned queue state.
- Negative/path controls: `pool`, `poolPointer`, `S=21`, and the `S=22`
  confinement check above.

## Files

- `src/FruitMachineLab.Adders/AddersToneSetupExecution.cs`: empty-pool
  preflight, explicit BPL outcome, corrected stack/`5A14` comment.
- `src/FruitMachineLab.Adders/AddersToneSetupVerification.cs`: pool negatives
  and `S=21` reject / `S=22` confinement verification.
- `tests/FruitMachineLab.Verification/Program.cs`: extended existing setup
  negatives and cycle/stack group; total group count remains `409`.
- `docs/recovery/RECOVER49-FOREGROUND-SETUP-PREFLIGHT-PASS.md`: this report.
- `evidence/curated-manifest.json`: own RECOVER49 entry only.
- `artifacts/deepseek/recover-49/`: result, logs and exits.

## Commands and exits

- `dotnet build FruitMachineLab.Headless.sln -v:minimal` -> exit 0, 0 warnings,
  0 errors.
- Focused `Foreground5A14` run -> exit 0, 3 groups passed.
- Full headless suite -> exit 0, 409 groups passed (the Recover48 baseline is
  unchanged).
- `pwsh -NoProfile -File tools/Update-CuratedManifest.ps1 -Verify` -> exit 0.

## Limits

No new capture, Live execution, IRQ/timer1 cadence, audio, `5CD0` service or
continuous lifecycle was added. The `00FC/80A4/776F` bridge, the `5A05/5A07/7159`
wait, `5A0A..5A12` finish and later foreground/IRQ deltas remain outside this
slice. The `S=22` run reuses captured RAM but is a synthetic stack placement;
it does not claim a captured full state at that stack. No `CC`/`DP` model is
added.

## Next task

Recover the `00FC/80A4/776F` bridge into `5A14` from an independent full 2 KB
entry, or extend the same-machine owner through the first `5CD0` service after
the inter-service foreground/IRQ deltas are attributed. Do not infer timer1
cadence or Live ownership from this setup boundary.

# Recover50 VM entry / 776F foreground bridge pass

## Outcome

Executed the actual VM entry `PC=00FC`, `Y=FC4D` into the Start-tone foreground
setup. `AEA1` loads the `80A4` token through `Y++`; `6E91` follows the
`80A4/80A6` word header to `776F`; `776F` pushes the advanced `Y=FC4F` and calls
`5A14` through the same header. The bridge writes `07A6/07A7=777E` and
`07A8/07A9=FC4F`; the previous manual restore of the captured `Y` word is gone.
The accepted `AddersToneSetupExecution` then reaches `5C18` and `5A05` on the
same `Machine` with the existing `AddersNativeSound` owner.

## Entry and evidence classes

- Static original ROM: `FC4D 80A4 F382`; `80A4 776F 5A14`;
  `776F 96F1 2707 8A01 97F1 B7080C 3420 AD94 ...`; the wrapper and queue bytes
  remain the Recover48/49 set.
- Captured RAM: `00FC AEA1 6E91` is the trace-backed NEXT template, loaded once
  from the independent `FC4D` 2 KB frame. `FC4D` here is the VM CPU address, not
  the RAM snapshot name.
- Fresh natural oracle31: `collection/fresh-tone-occurrence.json` supplies the
  `FC4D` and `queue` 2 KB frames, `5A14/5A05` markers and the 16-byte foreground
  delta. `collection/tone-setup-bridge-data.json` curates the static bridge,
  token and word-header bytes; it is not a new capture.
- Source-derived execution: `M6809InstructionTiming` costs every selected
  instruction; the queue remains the existing `AddersSoundQueuePlan`.

## What is proved

The bridge span is `41` source cycles: `17` dispatch (`AEA1`, `6E91`) plus `24`
body (`96F1`, taken `2707`, `3420`, `AD94`). `F1=0` selects the reported branch,
so the mode writes at `7773/7775/7777` are not executed. Those mode bytes remain
a static deduction only; Recover51 makes the execution restriction explicit. The resulting `5A14`
state matches the captured marker: cycle, `S=07A6`, `X=80A6`, `Y=FC4F`,
`U=0672`, `A=00`, `B=FF`. The wrapper still costs `67`, the queue `262` and the
`59E9` return `11`; `5C18` and `5A05` and the full 2 KB queue frame match. The
generated `FC4D -> 5C18` delta equals the captured 16 entries with the same
from/to values. There is no second RAM seed and no captured delta application.
Only captured/source registers are returned; `CC` and `DP` are not modelled.

## Negative controls

All reject before mutation with the pre-rejection memory unchanged: `stack`
(VM entry `S=25`), `gate`, `ownership`, `owner`, `servicing`, `paused`, `pool`,
`poolPointer`, `vmTemplate`, `vmToken`, `vmHeader`, `vmNative` and `bridgeMode`.
`missingROM` stops at region load. `snapshot` still reaches the full-2 KB queue
comparison. These are semantic-stage checks, not hash short circuits.

## Limits

The `5A05/5A07/7159` wait, `5A0A..5A12` finish, the first `5CD0` service, IRQs,
timer1 cadence, Live integration, audio and a continuous lifecycle remain
outside this slice. The `F1!=0` mode path is a static deduction only;
`ExecuteFromVmEntry` rejects it unconditionally before memory mutation and
exposes no hardware callback (see Recover51). No fitted historical budget or
full CPU flag state is claimed.

## Files

- `src/FruitMachineLab.Adders/AddersToneSetupExecution.cs`: shared preflight,
  actual `00FC/80A4/776F` bridge, explicit branch outcome, call-word writes.
- `src/FruitMachineLab.Adders/AddersToneSetupVerification.cs`: bridge ROM checks,
  `5A14` marker comparison, `07A6..07A9` writes, extended negatives.
- `tests/FruitMachineLab.Verification/Program.cs`: existing setup negatives
  extended; group count remains `409`.
- `evidence/mpu4/collection/tone-setup-bridge-data.json`: static bridge/token
  bytes.
- `docs/recovery/RECOVER50-VM-FOREGROUND-BRIDGE-PASS.md`: this report.
- `evidence/curated-manifest.json`: own RECOVER50 entries only.
- `artifacts/deepseek/recover-50/`: result, logs and exits.

## Commands and exits

- `dotnet build FruitMachineLab.Headless.sln -v:minimal` -> exit 0, 0 warnings,
  0 errors.
- Focused `Foreground5A14` run -> exit 0, 3 groups passed.
- Full headless suite -> exit 0, 409 groups passed (Recover48/49 baseline intact).
- `pwsh -NoProfile -File tools/Update-CuratedManifest.ps1 -Verify` -> exit 0.

## Next task

Extend the same-machine foreground owner through the `5A05/5A07/7159` wait or
the first `5CD0` service, only after the inter-service foreground/IRQ deltas are
attributed. Do not infer timer1 cadence or Live ownership from this bridge.

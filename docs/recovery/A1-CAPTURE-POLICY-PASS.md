# A1 capture policy at the Live evidence boundary

17 October 2026. Partial A1 increment. This pass adds an explicit, fail-closed
classification for evidence read by the existing `SkillCashLiveSession`
constructor. It does not make Live capture-free, change any schedule, result or
game rule, or certify reads outside that constructor.

## Actual protected path

`SkillCashLiveSession(..., RuntimeEvidencePolicy? evidencePolicy = null)` now
defaults to `RuntimeEvidencePolicy.Compatibility`, which reads exactly the same
files as before. `RuntimeEvidencePolicy.CaptureFree(...)` is the strict mode.

The policy executes in `SkillCashLiveSession`'s real constructor through
`ReadEvidence(...)`; it is not a verification-only helper. Strict construction of
the current Live entry fails before play with a precise file/field/replacement
diagnostic because Live still requires recorded timing and results. No
capture-free gameplay is claimed.

| Class | Strict rule |
| --- | --- |
| Static definition | Allowed. ROM-checked tables, decoded memberships, ranges, declared timing aliases and statically byte-checked call membership. |
| Declared checkpoint | Rejected unless `CaptureFree(allowDeclaredCheckpoint: true)` is explicit. Permission does not strip static data in a mixed file. |
| Recorded timing | Always rejected, including with checkpoint permission. |
| Recorded result | Always rejected, including with checkpoint permission. |

Diagnostics name the consumer fields, the class, the replacement target, and, for
mixed files, the other fields present so a mixed file is never described as
wholly static.

## Covered consumers (direct reads)

| Evidence file | Consumed fields | Class |
| --- | --- | --- |
| `maps/vm-literal-timing.json` | `tokens.operation/token/value` | Static definition |
| `skill-cash/calibrated-delay-timing.json` | `natural.phases[0].cpu_cycles`, `natural.phases[2].cpu_cycles/outer_irqs` | Recorded timing |
| `skill-cash/feature-replay.json` | `initial`, `allocated_frame`, `conditions`, `native[0].before` | Declared checkpoint |
| `skill-cash/shared-timing.json` | `initial_scan` only | Declared checkpoint |
| `skill-cash/cpu-interrupts.json` | `sites/tokens`; separately `intervals/timer1_handler_entries` | Recorded timing |
| `skill-cash/jackpot-probe.json` | `sites/tokens` | Recorded timing |
| `maps/skill-cash-extension-data.json` | `equivalent_timing_tokens` | Static definition |
| `skill-cash/board-result.json` | `sites/tokens` | Recorded timing |
| `maps/irq-service-data.json` | PIA/callback/drive/timer3 initial fields; `ranges` retained as static | Declared checkpoint (mixed) |
| `skill-cash/lamp-frames.json` | `initial`, `responses` | Recorded result (mixed with checkpoint) |
| `maps/nudge-preparation-data.json` | `equivalent_timing_tokens` | Static definition |
| `maps/dice-motion-data.json` | `ranges` | Static definition |
| `maps/dice-request-data.json` | `ranges`, `threaded_call_pacing.tokens`, `equivalent_timing_tokens` | Static definition |
| `maps/board-movement-data.json` | `equivalent_timing_tokens` | Static definition |
| `skill-cash/*` board-link cost list, `board-selection.json`, `dice-requests.json`, `dice-motion-vm.json`, `board-movement.json`, `nudge-pot-probe.json` | `sites/tokens` only | Recorded timing |

The `feature-replay.json` requirement explicitly notes its recorded instructions,
inputs, reads, anchors and expected results are not consumed at this boundary.
The `shared-timing.json` requirement notes `events` and `vm_cycle_deltas` are not
consumed. The timing aliases remain static declarations; the captured costs they
point at are rejected separately.

## Remaining unenforced reads (A1 still partial)

These runtime reads are outside the protected constructor boundary and remain
unclassified: `SkillCashPlayback.LoadLamps`; `SkillCashData.LoadExtensions`,
`LoadFeature`, `LoadAlpha`, `LoadScan`; `SkillCashAlphaVerification.Load`;
`SkillCashCompensationVerification.Load`; `SkillCashCallerState.Apply`; the
`BoardSelectionState`/`BoardMovementState`/`BoardLinkState` loaders;
`Mpu4ChoiceStreamScheduler.RestoreQueuedNativeTasks` and
`BoardLinkState.ResolveSoundContinuation`. Collection/payout owners
(`AddersTimedCollectionExecution` and related) also keep externally supplied or
captured budgets. The `lamp-frames.json` read at the constructor is classified,
but the same recorded data still has other verification consumers by design.

## Verification

- Six new groups use the actual constructor and the same requirement objects:
  default compatibility, strict recorded-timing rejection with and without
  checkpoint permission, static allowance, explicit checkpoint permission,
  recorded-result rejection with permission, and mixed static/checkpoint
  diagnostics.
- Clean `HEAD` snapshot (`e443040`) plus only these intended files:
  `dotnet build FruitMachineLab.Headless.sln --no-restore` succeeds with zero
  warnings/errors; full suite passes 376 groups (370 previous baseline plus six).
- `e443040` was not amended or committed to. Uncommitted stopped FEC9 sound
  files/tests/evidence were preserved untouched and excluded from the snapshot
  suite; they were not retried.

## Limits

Strict Live fails early because the current feature-entry path still needs
recorded outer occupancy, helper budgets and lamp responses. A1 remains partial
until every runtime read has a policy classification and causal replacements
exist. No MAME run, capture, installation or configuration change was made.

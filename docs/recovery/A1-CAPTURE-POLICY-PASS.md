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

## SkillCashData static load consumers

General17 extends the same policy object through the four `SkillCashData` loaders
used by Live. These consumers are static ROM data, so strict capture-free policy
allows them without a checkpoint; no recorded schedule or result is read.

| Helper | Evidence file | Consumed fields | Class |
| --- | --- | --- | --- |
| `LoadExtensions` | `maps/skill-cash-extension-data.json` | `ranges` | Static definition |
| `LoadFeature` | `maps/skill-cash-feature-data.json` | `ranges[71AA, 8705, 890A, 7257]` | Static definition |
| `LoadAlpha` | `maps/skill-cash-alpha-scan-data.json` | `ranges[A7B6, A7C9, A814, AF78, 193B, 6C3C]` | Static definition |
| `LoadScan` | `maps/skill-cash-alpha-scan-data.json` | `ranges[28E6, 29BB]` | Static definition |

`SkillCashLiveSession` passes its chosen policy into `LoadExtensions`,
`LoadFeature`, `LoadAlpha` and `LoadScan`; the helpers no longer default silently
to compatibility on that path. When an evidence directory is supplied they read
the source-backed ranges above. Existing callers that pass no directory retain
the compiled ROM byte arrays unchanged, preserving prior verification and replay
semantics. The feature-data `words` and the ROM pointer writes at `851E`/`8522`
remain compiled static definitions; the former is noted as not read from this
file by this loader.

Review18 hardens the feature/alpha/scan map path before any machine write. Every
required range must appear exactly once with its recovered byte length; the
address, hex text and end must be valid within 65536, and a span overlapping a
required span is rejected. Missing, duplicate, short, long, overlapping,
malformed or out-of-bounds entries fail with the file and address in the
diagnostic. `LoadFeature` preflights before its shared `Load(machine)` step, so a
rejected map leaves the supplied machine untouched. Valid maps produce the same
bytes as the compiled arrays. Negative tests use temporary map copies and
sentinel memory, including the feature loader's earlier mutation path.

## Remaining unenforced reads (A1 still partial)

These runtime reads remain outside the protected boundaries and unclassified:
`SkillCashPlayback.LoadLamps`; `SkillCashAlphaVerification.Load`;
`SkillCashCompensationVerification.Load` (both still read by Live seeding);
`SkillCashCallerState.Apply`; the
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
- General17 adds four `SkillCashData` groups: actual strict/default extension
  load equality, feature range equality, alpha/scan range equality, and exact
  requirement file/field inventory. Full suite passes 380 groups (376 baseline
  plus four) with zero build warnings/errors.
- Review18 adds two actual-helper groups: ten invalid temporary map copies
  (missing, duplicate, short, long, overlapping, malformed address/hex and
  out-of-bounds; alpha and scan included) rejected with sentinel memory intact,
  plus valid temporary copies matching compiled bytes. Clean `HEAD` (`a0deb81`)
  snapshot plus only intended files builds with zero warnings/errors and passes
  382 groups.
- `e443040` and `a0deb81` were not amended or committed to. Uncommitted stopped
  FEC9 sound files/tests/evidence were preserved untouched and excluded from all
  snapshot suites; they were not retried.

## Limits

Strict Live fails early because the current feature-entry path still needs
recorded outer occupancy, helper budgets and lamp responses. Adding static ROM
consumers does not make gameplay capture-free or remove that timing/IRQ
ownership. A1 remains partial until every runtime read has a policy
classification and causal replacements exist. No MAME run, capture, installation
or configuration change was made.

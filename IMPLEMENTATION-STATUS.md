# Implementation and evidence boundaries

## Initial import and runtime baseline (historical)

- Imported all top-level recovery reports and the current 528 decoded VM body listings.
- Imported selected board/lamp semantic maps, branch prerequisites, arithmetic checks
  and original replay verification summaries.
- Extracted one Skill Cash interval from vm-batch-policy7-a/debug.log, beginning at
  C721 and ending at C71D. The original summary reports policy7 a/b byte-identical;
  this batch has not rerun MAME. Both original debug logs have now been independently
  SHA256-compared and the selected intervals compared exactly. Source line ranges,
  hashes and launch/input metadata accompany the excerpt.
- Implemented explicit 16-bit arithmetic, Forth flags, big-endian cells, a decoded
  script interpreter subset, frame-address operations and fail-fast unknown helpers.
- Executed recovered C637 initialization and 9F6A award normalization. Translated
  C757..C75F stage reduction and C70E pending-word store.
- WPF consumes the same diagnostic events produced by the headless replay.

## Current continuous replay

The diagnostic app executes the complete recovered C721 VM feature in one run,
matching 98,704 MAME dispatches from entry through C767. It selects 3, 2 and 1,
commits pending award 10, transfers ten units to current win, clears pending to
zero, and restores the caller frame. All thirteen NVRAM refreshes match their
native source/complement/checksum observations.

Native input conditions are calculated from recorded port bytes and recovered
mask tables, including partial match 0001. Choice bytes and queue rates are
calculated; captured IRQ/latch/scheduler timing still drives the platform adapter.
All 7,298 lamp requests reproduce native frame memory. The complete sound protocol
matches 25 queues, concurrent forks, 6,037 commands and 1,930 waits.

See [the continuous feature pass](docs/recovery/SKILL-CASH-CONTINUOUS-FEATURE-PASS.md)
for canonical digest fields, provenance, static caller-sentinel checks and remaining
boundaries. The earlier bounded mechanics replay and independent helper checks
remain as focused verification; the paragraphs below describe those narrower checks.

## Earlier bounded mechanics proof

The recovered selection decisions produce accepted choices 3, 2 and 1 from recorded
platform inputs, matching the recorded helper returns. The stage calculation uses
timer values 25, 20 and 15 and signed minimum to reduce level 6 to 1. The recorded
table-read address is 75BE. The recovered ROM table now supplies 10, checked against
that recorded read; normalization leaves 10; pending BA is
stored as big-endian 000A. Intermediate stack observations independently check
previous levels and computed addresses. Selection decisions, accepted choices and
the award-table read are C# predictions; their latch and IRQ timing
inputs remain captured platform observations. The input-condition branch in 9F6A
is not captured by this debugger range; both condition outcomes are evaluated and
must yield the same result. For award 10 both yield 10. An input-dependent outcome
fails with an explicit request for additional evidence.

## Earlier isolated coverage (historical)

Complete C699 calls now match 65,298 dispatches, with calculated sound-stream choice
bytes and decoded logical lamp requests. Captured IRQ/latch/scheduler timing remains
an external replay input. Full C721 orchestration, enabled option override C646,
hardware lamp/audio effects and full award animation AF93 remain. Native NVRAM
refresh 6E06 matches 13 recorded calls; ten AF93 accounting slices calculate current
win 10, matching 280 dispatches. Display/sound/wait orchestration remains outside
those slices. See [the award/NVRAM pass](docs/recovery/SKILL-CASH-AWARD-NVRAM-PASS.md).
Native RNG and percentage arithmetic now execute and match three focused MAME calls.
C66A/C617/A110/A0E1 now execute from recorded RAM/peripheral/IRQ inputs, with all 240
nested dispatches checked. C676 no longer injects a chance-helper result. Physical
local/loop/nested-return frames match the 29-instruction feature prefix and nested calls.
Selection blocks calculate all 1,202 decisions and accepted choices from platform inputs.
Nonzero compensation and full-feature frame cleanup have static tests only.
That earlier replay did not run C721 end to end or validate final bank,
physical payout or UI animation. Current-win accounting has bounded verification,
not full-feature execution. Unsupported interpreter operations throw.
No synthetic selection/timer semantics are presented as ROM behaviour.

The focused replay has now been captured, and state.csv, feature-state.csv,
input-levels.csv and final RAM match the original campaign exactly. The expanded
report is [SKILL-CASH-RUNTIME-PASS.md](docs/recovery/SKILL-CASH-RUNTIME-PASS.md).
See [the compensation/control pass](docs/recovery/SKILL-CASH-COMPENSATION-PASS.md).
See [the selection/scheduler pass](docs/recovery/SKILL-CASH-SELECTION-SCHEDULER-PASS.md).
## Remaining before standalone gameplay

Continuous C721 orchestration and lamp frame memory are now verified on the selected
path. Alpha reset/stream requests are explicit peripheral boundaries; physical
display memory, audio synthesis and lamp IRQ scanning remain unresolved. Platform
timing is still a recorded per-dispatch adapter rather than a general CPU schedule.
Final payout, enabled ROM-option branch C646, alternate awards and wider campaigns
remain unverified. Unsupported operations fail explicitly; no synthetic fault or
alternate-input test is presented as an observed MAME path.

The subsequent [alpha/output pass](docs/recovery/SKILL-CASH-ALPHA-OUTPUT-PASS.md)
replaces the alpha software boundary: 44 calls/740 bytes match and run continuously
with the feature. An independent IRQ adapter matches 6,103 output scans and
pulse-width helper calls. PIA/VFD electrical timing and elapsed PTM callbacks
remain open; native scan input RAM is recorded rather than supplied by a general
platform schedule. Earlier boundary statements above are historical.

The [shared timing pass](docs/recovery/SKILL-CASH-SHARED-TIMING-PASS.md) now connects
VM-produced requests, 29,192 calculated frame writes, 6,103 IRQ scans and timer
callbacks on one memory image. Frame changes between scans are no longer injected.
CPU-cycle timestamps and game IRQ/latch timing remain captured; hardware timer
deadlines, general scheduling and electrical effects are still unresolved.

## Provenance

The [live Skill Cash slice](docs/recovery/SKILL-CASH-LIVE-PASS.md) executes the VM
incrementally with physical Start sampling, generated lamp/alpha outputs and actual
Pause/Resume. The original playback/scrubber remains separate. Reference-time Start
pulses match 18 VM/frame/accounting checkpoints, 44 alpha states and final lamp frame
memory; CPU dispatch count and completion timing differ. 67 groups and both WPF mode
smoke checks pass. Captured CPU/IRQ pacing remains an explicit boundary.

The [visual playback slice](docs/recovery/SKILL-CASH-PLAYBACK-PASS.md) presents the
verified headless output in diagnostics at recorded real-time speed, with mapped
lamps, alpha shadow, pause/restart/seek and speed controls. The path lasts 12.209 s.
61 verification groups and the WPF playback/render smoke check pass. Persistence
and native-boundary alpha/lamp presentation are qualified in the report.

The [timer deadline investigation](docs/recovery/SKILL-CASH-TIMER-DEADLINE-PASS.md)
adds 6,103 effective latch writes and independent IRQ/callback timestamps. A bounded
source-backed countdown is consistent with the trace; CPU acceptance latency and
exact expiry observation remain unresolved. All callback cycles/columns match the
shared capture. Fifty-seven verification groups pass.

Original workspace is preserved at
`C:\Users\John\Documents\Codex\2026-10-13\help-me-set-up-a-local\outputs\mpu4`.
The baseline ROM SHA1 is 402d1518bb78fdc489b06c2aabc771e5ce151847; no ROM binaries,
NVRAM dumps, Ghidra projects or full campaign logs are copied into the repository.
Reports include static deductions, hypotheses and synthetic fault experiments:
their original qualifications remain authoritative. Imported historical reports
describe earlier inventories; prerequisite-pass is the latest inventory baseline.

`evidence/curated-manifest.json` records byte counts and SHA256 for imported artifacts.
`tools/Extract-SkillCashEvidence.ps1` reproduces interval extraction and a/b comparison
without changing the source workspace. Selected native assembly exports accompany
the interpreter translations; decompiler output remains qualified by its warnings.

The decoded listings contain recovered token/data values and are curated analysis
artifacts. Absolute paths in copied launch metadata describe the original run and
must be resolved explicitly before reuse; they are not portable launch scripts.

## Live award coverage and normal-play boundary

See docs/recovery/SKILL-CASH-EXTENSION-PASS.md. All six default award levels and
the jackpot announcement execute live; 77 verification groups pass. A synthetic
MAME helper probe independently checks VM/lamp/sound/alpha effects. Captured IRQ
occupancy improves pacing but does not resolve general scheduling. The recovered
normal cash-feature selector is executable; full machine play remains future work.

## Normal board-result entry and return

See docs/recovery/SKILL-CASH-BOARD-ENTRY-PASS.md. Live can execute E2FC..E33C for
the selected type-2/position-32 route, including take gating, announcement and nested
table dispatch. Natural MAME captures independently preserve the original feature
digest; both entry modes complete all six default awards. 81 groups pass. This is
a captured board-result boundary, not startup or persistent whole-machine play.

# Implementation and evidence boundaries

Newest: [flag feature entry](docs/recovery/FLAG-FEATURE-ENTRY-PASS.md). Live passes
three-flag accounting, software planning/table construction and pot/board
animation, stopping at E3AE before native61CF motion. Five new natural MAME
windows match; their later-game starting states differ from the generated Live
campaign. The two new core VM words preserve original stack/memory semantics.
147 VM spans/1638 native instruction records are byte-checked in the existing
preservation checkpoint; full-ROM rebuilding remains deferred.

Newest: [paid cycle return](docs/recovery/PAID-CYCLE-RETURN-PASS.md). Live reaches
another Start prompt through the real outer caller. Three generated paid plays
retain one machine and debit credits6→3 with bank16;181 headless groups/eight GUI modes pass.
Natural310/99/1147-observation windows match. EE16 three-flag feature-entry
accounting remains explicit; this is not complete-machine coverage.

Newest: [paid result / ordinary nudge](docs/recovery/PAID-RESULT-ORDINARY-NUDGE-PASS.md).
Live executes result checks and ordinary-nudge eligibility; a mixed-input campaign
offers one nudge and physical Nudge1 reaches B749 with prompt/motor Pause. The
generated no-nudge path stops at FC7C.177 headless groups/eight GUI modes pass. Three natural
reference windows and135 motor observations match; IRQ DP residue is preserved
at a qualified inline-literal boundary. No whole-machine or consecutive-games claim.

Newest: [paid reel spin](docs/recovery/PAID-REEL-SPIN-PASS.md). Live runs the actual
paid motor spin incrementally with Pause/Resume, reaching F398 before result/award
dispatch.172 headless groups/eight GUI modes pass;1282 native motor observations
and18 isolated fallback-result cases match. Earlier entries are history.

Newest: [start tone/spin gates](docs/recovery/START-TONE-SPIN-GATES-PASS.md). Live
executes the timed native routine incrementally, then selected pre-spin flags and
random gates to F38C.168 groups/eight GUI modes pass;48 isolated request cases.
Final stop selection and the paid reel spin remain the next boundary; tone pacing
still uses the explicit CPU/IRQ adapter and audio synthesis remains outside scope.

Newest: [preplay Start/stake](docs/recovery/PREPLAY-START-STAKE-PASS.md). Live
waits for physical START in the recovered preplay loop, consumes one credit and
records the next stake. FC4D/native5A14 and F384 spin remain the next boundary.
163 headless groups/eight GUI modes pass; three natural windows and75-case native
matrix match. This is not another completed game; long-wait2CB3 remains explicit.

Newest: [background services/preplay](docs/recovery/BACKGROUND-SERVICES-PREPLAY-PASS.md).
Live reachesFC99;156 headless groups/eight GUI modes pass. Status lamps and guarded
services execute, with explicit MAME characteriser compatibility and fault/reset
limits. Preplay eligibility and the next paid spin remain outside this milestone.

Newest: [IC8/background entry](docs/recovery/IC8-BACKGROUND-ENTRY-PASS.md). Live
reaches FBF1/native482F;150 headless groups and eight GUI smoke modes pass.
The output latch uses a qualified captured entry seed, not full PIA/startup emulation.

Newest: [nudge cycle return](docs/recovery/NUDGE-CYCLE-RETURN-PASS.md). Live now
passes bank-limit service and the real outer callers/stack check, then refreshes
the next cycle's credit/bank display. FAF0 IC8/background-service boundary remains.
Cash bank16/token bank0/credits6; collection and consecutive games remain future work.

Latest continuation: [nudge award statistics](docs/recovery/NUDGE-AWARD-STATISTICS-PASS.md).
Live runs through the outer award caller, statistics/scaled counters and AF13
cash-bank commit, then stops at AF25 before bank-limit service. Natural226-dispatch,
22-case statistics and12-case scaled-counter comparisons pass. Cash bank16,
token bank0, pending/current-win0; collection has not executed.

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

## Board selection and Take Feature

See docs/recovery/BOARD-SELECTION-TAKE-PASS.md. Live supports physical Take from
DD38/square 32 through Skill Cash and the board-loop return at E460. Saved physical
VM frames resume via decoded address ownership. The natural broader replay checks
99,843 normalized observations plus native lamp/sound/alpha and physical conditions;
uninitialized frame bytes are explicitly excluded until the ROM initializes them.
87 groups pass, including all six awards through all three entry modes. Roll/dice
motion is the next explicit unsupported boundary; no whole-game claim is made.

## Dice selection and request preparation

See docs/recovery/DICE-REQUEST-PASS.md. Live Start executes the recovered selection,
profile scaling and signed reel-offset logic, emits ROLLING and stops before native
61F6. A natural request capture matches 485 dispatches plus lamp/sound/alpha effects;
the 478-dispatch inner body agrees with an independent capture. 92 groups pass,
including varied live timing and native edge tests. Motor scheduling, completion
and board movement remain unimplemented. Game-specific reel/profile tables stay
in the Adders layer until reuse is demonstrated.

## Incremental dice motor

See docs/recovery/DICE-MOTION-PASS.md. Live START now completes a recovered roll
through native profile setup, periodic service, generated motor optics, busy-loop
exit, NVRAM cleanup and symbol refresh, stopping before B28F board continuation.
The text face/position change during execution; Pause/Resume retain motor state.
99 groups and four GUI smoke modes pass. Native verification checks 386 services
and 96 updates against 875 observations; two independent captures agree on core
states. The combined reference matches 7,103 VM observations, 15 lamp requests and
167 sound commands. Alpha is explicitly 83/84 bytes: one brightness restoration
differs; text/cursor/reset match. Exact native alpha/IRQ timing remains unresolved.
The small MAME-derived Barcrest motor model has BSD-3-Clause attribution. This is
not homing, whole-board movement, machine startup or persistent whole-game play.

## Incremental board movement

See docs/recovery/BOARD-MOVEMENT-PASS.md. Live START continues the motor roll into
DDF3 board movement and zero-link DBC4 dispatch, then stops before the next result
or selection. Nonzero-link animation remains an explicit boundary. Board square,
pot, raw type/link and visited squares are exposed independently of WPF. The natural
7→11 reference matches 12,355 VM observations, 11 lamp requests and 60 sound
commands. A separate synthetic DDE3 probe checks the digit animation and 36 sound
commands over 9,565 lifted observations (9,613 raw; 48 inner typed-list observations
excluded). New native arithmetic and memory primitives retain wrap and signed
rounding. 106 groups and all four GUI modes pass, including actual mid-board pause.

## Natural board links — 15 October 2026

Ladder/snake DBC4 paths now execute and match MAME through DE81: 571/22,887 VM
observations, 57/61 lamp requests, 337/265 sound commands and 47/0 alpha bytes.
Live exposes natural entry modes, matches logical outputs and accounting, and
supports actual pause/resume/restart. Polling and provisional timing differences
remain explicit. See docs/recovery/BOARD-LINK-PASS.md. 110 headless groups and
five WPF smoke modes pass. Following result routing and whole-game play remain open.

## Board continuation — 15 October 2026

The optional continuation mode (GUI default enabled) follows recovered caller
frames into the next selection/result. Live 32→36 returns to DD38, accepts another
physical START and retains machine state. Three natural extended captures match
620/22,902/12,363 VM observations, exact earlier prefixes and all output hashes.
Nudge-availability search 29F4 and unsupported result types remain explicit stops.
113 headless groups and six WPF smoke modes pass. See
docs/recovery/BOARD-CONTINUATION-PASS.md for evidence and timing qualifications.

## Nudge availability — 15 October 2026

29F4/2A7F/1AC3/1B63/1B7B now execute from assembly translations. The natural ladder
prompt matches 5,544 VM observations, 52 native calls and all lamp/sound/alpha
outputs. A separately classified 17-case synthetic MAME matrix matches all RAM
below0700, including scratch state and restored symbols. Live reaches TAKE
NUDGEPOT after the ladder and accepts START for another roll or TAKE to the
type-1 result boundary; nudge play remains open. 116 headless groups and seven
GUI smoke modes pass. See docs/recovery/NUDGE-AVAILABILITY-PASS.md.

## Type-1 nudge preparation — 15 October 2026

Flagged 29EC search is translated and independently matches a 17-case native
matrix. Natural E247→B4C5 preparation matches 229 VM observations, 24 lamp requests
and three native calls, with explicit uninitialized-local masks until ROM writes.
Live TAKE now prepares three nudges and stops before main-reel interaction.
118 headless groups and seven GUI smoke modes pass. See
docs/recovery/NUDGE-PREPARATION-PASS.md for exact evidence and next boundaries.

## Nudge prompt/input — 15 October 2026

Natural prompt/request references match375/553 VM observations and complete
outputs, preserving earlier preparation proof. Native1AA3 matching-result and
alpha69 plural formatting now execute. Temporary NUDGE1/2/3 controls route through
sampled BLACK2 input and actual VM scanning. Live stops before B31F motor motion,
with only the selected request incremented and no count/award change. 124 headless
groups and eight GUI smoke modes pass; mouse-held nudge acceptance itself is not
automated. See docs/recovery/NUDGE-INPUT-PASS.md for exact evidence/limitations.

## Main-reel nudge / preservation — 15 October 2026

Live completes one selected main-reel nudge and consumes remaining/pot3→2. Natural
Nudge1 matches135 native observations and generated optics; connected safe prefix
matches750 VM observations and complete outputs. Stop before B33B's uninitialized
local-byte/native-stack-residue dependency; no value/mask is invented. 127 groups
and eight GUI smoke modes pass. A selected ROM-byte checkpoint extends existing
export/maps conventions; full symbolic toolchain is deferred until playable PC
coverage. Ghidra full metadata export remains an access gap. See
docs/recovery/NUDGE-MOTION-PASS.md and docs/PROJECT-ROADMAP.md.
One advance is supported; complete board/game play and the earlier alpha brightness
timing discrepancy remain open. No installations or configuration changes occurred.

## Returned prompts and three-nudge sequence — 15 October 2026

Live now returns to an interactive nudge prompt and supports repeated input.
Three Nudge1 presses consume BE/BF 3→0 and move reel1 12→6→0→90. The previous
local+2 dependency is resolved by retaining the actual native4A8C lamp save area,
not injecting a reference value. Token7A15 loop leave is translated and verified.
Natural connected references cover 2817 returned-prompt and 7785 sequence VM
observations with matching lamp/frame, sound and alpha outputs. Active motor
phases and independently generated optics cover all three movements. Live stops
at B749 before improvement/result routing; post-nudge awards remain unrecovered.
132 headless groups/eight GUI smoke modes pass, including all three controls,
returned prompts, three-press exhaustion and actual mid-motor pause/resume.
The encoding checkpoint now preserves 657 byte-checked native rows, nine VM
spans, 7A15 encodings and 61 natural stack writes with implementation/evidence
links. Full symbolic toolchain and fresh Ghidra metadata export remain deferred/
unavailable respectively. See docs/recovery/NUDGE-RETURN-PASS.md.

## Automatic nudge improvement and pending result — 15 October 2026

Live continues past B749 through recovered B712/B652, B666 rewind and
B6DB/B384/B352 automatic improvement. Native2A2F movement-plan return and7A26
outer-loop index are translated. The result is pending16/current-win0, positions
6,90,42 and symbols2,2,2. Live stops at E263 before caller/award routing.
Natural reference:66368 canonical VM observations,162 lamp/frame requests,1005
sound commands,405 alpha bytes; strict count of6197 existing typed-list/local-
release exclusions. Two complete runs agree on the VM digest and3360 native
core observations.17 synthetic helper cases check complete low RAM, separately
labelled. Live matches ordered lamps, final alpha, reels and51 protected bytes
at the saved result boundary; actual pause/resume during automatic movement passes.
135 headless groups/eight WPF smoke modes pass. Existing encoding checkpoint now
checks700 native rows/17 VM spans and links new dictionary/data/implementation
facts. Full symbolic toolchain remains deferred. See docs/recovery/NUDGE-IMPROVEMENT-PASS.md.

## Board exit and current win transfer — 15 October 2026

Live returns through E263/E460 and runs EDB4/AF93 meter transfer16/0→0/16.
It stops at final AFC2 after native refresh, before display/wait tail, bank commit
or collection. Successful E460 reference checks66412 VM/171 lamps/1005 sounds/
424 alpha bytes and terminal RAM. The transfer reference checks95391 VM/203 lamps/
1341 sounds/987 alpha bytes from an explicitly selected prefix whose source process
failed later; no terminal transfer RAM/full-campaign claim. Its whole successful
exit prefix matches. Live ordered lamps/final alpha, conservation16 and intermediate
meter steps match; pause/resume during rewind and mid-meter freezes actual state.
137 headless groups/all8 WPF smoke modes pass.38 VM spans/700 native rows checked
against ROM, new sound children retained; symbolic toolchain still deferred and
fresh Ghidra metadata access unavailable. See docs/recovery/NUDGE-WIN-TRANSFER-PASS.md.

## Completed current win animation tail — 15 October 2026

Live now executes the remaining display/wait, AF4E even rounding and AF67 seven
flashes, then stops at AFF0 with pending0/current-win16 and refreshed display.
A successful natural AFC2→AFF0 capture window saves entry/terminal RAM and matches
13469 VM observations,63 sound commands,406 alpha bytes and protected accounting
bytes. All entry signature fields match the older observed-prefix boundary;
that earlier process-failure qualification remains. No single complete earlier-
dispatch campaign claim. Capture/curator now reject debugger expression errors.
Full-logging external crash remains unresolved; narrow-window capture succeeds.
139 headless groups/all8 GUI smoke modes pass, including seven flashes, native
wraparound rounding and pause during the flash loop. Existing38 byte-checked VM
spans/700 native rows and8714 sound bytes retained. Next recover AFF0's real outer
caller before bank commit, collection or payout. See docs/recovery/NUDGE-ANIMATION-TAIL-PASS.md.

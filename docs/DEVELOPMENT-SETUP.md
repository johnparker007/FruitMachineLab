# Local and cloud development

Repository: https://github.com/johnparker007/FruitMachineLab
Local clone: C:\projects\GitRepos\FruitMachineLab

## Current status

Live no longer consumes shared-timing Events (including scan-entry timestamps).
Timer1 dispatch and idle post-panel counter/sense work are staged; accepted
outer IRQ entry/occupancy and active motor/sound work remain explicit adapters.
New captures: Capture-/Curate-PostPanelTiming.ps1 and Timer1DispatchTiming.ps1.
Natural ignored SWI2 evidence: Capture-SkillCash -FullFeature -PtmInstructionTiming,
then Curate-Timer1GuardTiming.ps1. See CURRENT-HANDOFF.md for scopes/excluded runs.

Live now generates timer3 assertion/acceptance/entry/callback/return locally;
timer-deadlines.json is no longer a Live dependency. Remaining outer scan/VM
pacing adapters are explicit. Reproduce natural PIA checkpoints with
Capture-SkillCash.ps1 -FullFeature -PtmInstructionTiming and
Curate-PiaServiceTiming.ps1 (RunDirectory/RomPath). Curator also exports the small
maps/irq-service-data.json static-data/initial-hardware checkpoint used by Live.

Coin service suffix4592 and composed438C idle return now have64 native cases
each. Reproduce Capture-CoinServiceTiming.ps1 with the standard isolated capture
parameters; add `-Composed` for the full idle caller. Curate-CoinServiceTiming.ps1
uses RunDirectory/RomPath and selects the evidence stem from capture provenance.
Verifier filters: `"Coin service"` and `"Composed idle"`. Live is unchanged.

Bounded coin-idle continuation43E9 now has64 original-ROM native cases. Reproduce
with tools/Capture-CoinIdleTiming.ps1 (fresh isolated RunDirectory, MameExecutable,
RomDirectory), then tools/Curate-CoinIdleTiming.ps1 (RunDirectory, RomPath).
Targeted verifier filter: `"Coin idle"`. No installed tool/config changes needed.

Composed panel/inline continuations now have64 original-ROM cases, reproduced
with Capture-/Curate-PanelContinuationTiming.ps1 (same standard parameters).
Optional modes keep older prefix verifiers intact. Non-coin IRQ suffixes now
reach280C through1A05/1A58; coin43E9/44C3 and reset7CCF remain explicit boundaries.
Live scheduling is unchanged; see CURRENT-HANDOFF.md for state-seeding caveats.

46D3 now has a separate staged implementation with64 native tests (58/73 cycles,
signed index aliases, adjusted inline return and flags/register preservation).
Capture-/Curate-InlineAuxTiming.ps1 reproduce it; curator also accepts
ExcludedRunDirectory.19-window proof now includes the full nested IRQ return
and resumed native instruction times. See handoff for remaining caller composition
and Live scheduling boundaries.

Timing verifier now generates IRQ acceptance for all19 natural windows after
adding the439F decode prefix.64 isolated original-ROM cases verify its filter
semantics/timing. Reproduce with Capture-/Curate-CoinDecodeTiming.ps1 using the
same parameters as the input-service tools. An explicit0C02 reader is required
past the known prefix;46D3/1A05 continuations and Live IRQ integration remain open.

Live now stages the post-scan FEBA/27D2 input/drive prefix too.64 isolated native
cases and19 natural prefix timing windows verify it. Reproduce with
Capture-InputServiceTiming.ps1 (MameExecutable/RomDirectory/fresh RunDirectory),
then Curate-InputServiceTiming.ps1 (RunDirectory/RomPath). Start acquisition and
reel-drive stores occur at generated instruction times;438C and later service
still use an explicit adapter. See the handoff for remaining IRQ timing work.

Live output scanning is now instruction-staged, including lamp blanking/frame
writes, timer arm and digit output. It retains scan entry/event3, not scan return
or recorded arm events.64 isolated ROM calls,19 natural instruction windows and
the full6103-scan output digest verify it. Reproduce with
Capture-OutputScanTiming.ps1 (MameExecutable/RomDirectory/fresh RunDirectory), then
Curate-OutputScanTiming.ps1 (RunDirectory/RomPath, optional ExcludedRunDirectory).
FE70 entry/outer occupancy and post-scan service remain explicit adapters; see
CURRENT-HANDOFF.md for the rejected strict hardware attachment and next work.

Selected timer3 dispatch can now connect its generated status/counter reads and
control writes to the phase clock. Nineteen natural windows verify acknowledgement,
stop and frozen counter values. This optional hardware connection is exercised by
headless verification; Live still retains recorded IRQ entry. See the handoff and
timing foundation report for the remaining surrounding-instruction boundary.

Dispatch continuation: Live generates48FD entry from32 native FE70 instructions,
not shared callback timestamps. Recorded IRQ handler entry remains the hardware
adapter.19 natural windows and live Pause/timestamp-corruption checks pass;
see handoff/timing foundation for selected-path guards and remaining gaps.

Live timer3 callback port writes/completion now follow source-derived instruction
events, retaining captured entry only.18 isolated paths/45 effective bus writes
and19 natural windows match; see the handoff/timing report. Reproduce with
Capture-/Curate-LampCallbackTiming.ps1 (MameExecutable/RomDirectory/RunDirectory;
curator takes RunDirectory/RomPath/MameExecutable). Scan/IRQ adapters remain.
222 headless groups/eight WPF modes pass; both builds have zero warnings/errors.

Live Start-tone wait now uses34276 source-derived CPU cycles and projects its
deadline through explicit full IRQ envelopes. Capture-/Curate-CalibratedDelay.ps1
reproduce20 delay and20 literal native cases plus the natural phase comparison.
Curator parameters: RunDirectory, RomPath, MameExecutable, optional
ExcludedRunDirectory.217 headless groups/eight WPF modes pass; both builds clean.
See current handoff/timing report; larger IRQ scheduling is still captured.

Conditional timing: Live derives seven VM token entries' costs from pre-execution
stack values.376 injected native cases and12 natural paths match;2 interrupted
paths are excluded. Capture-/Curate-VmConditionalTiming.ps1 reproduce the evidence;
see the existing timing report/handoff. IRQ adapters remain explicit.

Short gateway continuation: Curate-VmPrimitiveTiming.ps1 also exports26 complete
RAM call-gateway paths. Live calculates their28-cycle cost from instructions
for already ROM-header-checked tokens. See CURRENT-HANDOFF.md and the existing
timing foundation report; IRQ timing adapters remain unchanged.

Live now derives selected primitive CPU costs from native encodings, verified
against54 complete natural paths. Reproduce with Curate-VmPrimitiveTiming.ps1
using the accepted instruction RunDirectory and original RomPath. Zero/literals/
return timing is generated; remaining word/IRQ pacing is still captured.
See the existing timing foundation report and CURRENT-HANDOFF.md.

Outer timing continuation:19 complete selected timer1 services match7820
source-derived native instruction costs plus one decoded timer3 child each.
1854 branch destinations match captured flags. Starts/paths remain observed;
Live still uses captured pacing pending native VM/helper boundary integration.
Curate-PtmOuterTiming.ps1 reuses the accepted capture and original ROM; see
the existing timing foundation report and ptm-outer-timing*.json.
207 headless groups/eight WPF modes pass; both solution builds are clean.

Service timing continuation:19 timer3 tails,19 timer1 scans and38 nested IRQ
returns match source-derived timing/saved PCs. Callback completion is78 cycles
(old RTS-start marker73), timer3 acceptance→resume251, scans425–467. Remaining
outer timer1 background work and Live native-boundary scheduling stay explicit.
See the existing timing foundation report; Curate-PtmServiceTiming.ps1 reuses
the accepted external instruction capture with original RomPath.
205 headless groups/eight WPF modes pass; both solution builds are clean.

Native instruction timing continuation:19 timer3 entry windows and608 native
handler instruction durations match source-derived costs. All354 previous
Skill Cash state/timestamp rows stay identical. The remaining0–7 cycles are
explained by completing the current instruction;32 native instructions explain
the128-cycle path to the lamp callback. Live adapters remain until exit/timer1/
contention and translated-helper boundaries are covered. Reproduce with
Capture-SkillCash.ps1 -FullFeature -PtmInstructionTiming and
Curate-PtmInstructionTiming.ps1; see the existing timing foundation report.
201 headless groups/eight WPF modes pass; both solution builds are clean.

IRQ continuation:18 isolated CPU cases verify ordinary19-cycle entry and full
register frames.354 natural Skill Cash observations match20 timer arms;19
IRQ/callback pairs agree exactly with the old prefix after qualifying debugger
versus effective bus timestamps. Live retains captured scheduling while
instruction-boundary/input delivery and native service paths are recovered.
See recovery/PTM-CLOCK-FOUNDATION-PASS.md and maps/mame-timing-source.json.
199 headless groups/eight GUI smoke modes pass; headless/full builds are clean.

Timing continuation: timer3 post-shot/disable/rearm model matches643 natural
observations across20 arms, with a byte-identical independent repeat. Exact
attoseconds retain reference clock-switch truncation. Live scheduling remains
captured pending canonical PTM assertion versus CPU acceptance. See the lifecycle
continuation in recovery/PTM-CLOCK-FOUNDATION-PASS.md.

Latest: timing foundation pass adds timer1/timer3 clock primitives, a96-sample
synthetic hardware matrix and100 natural attract-mode phase pairs.194 headless
groups/eight GUI modes pass. Natural timer3 phase varies; Live's captured IRQ/
callback adapter remains until post-shot/rearm and CPU acceptance are recovered.
See recovery/PTM-CLOCK-FOUNDATION-PASS.md. Gameplay coverage remains as below.

Latest: Live passes feature-entry reel motion/board animation and returns to
an actual board selection prompt; START launches another dice roll.190 headless
groups/eight WPF modes pass. See recovery/FEATURE-ENTRY-MOTION-PASS.md for natural
11936/144-VM windows, independently repeated native motion and coverage limits.

Latest: Live passes three-flag accounting and board preparation through pot
animation, stopping at E3AE before native61CF reel motion. Five new natural MAME
windows match. See recovery/FLAG-FEATURE-ENTRY-PASS.md and CURRENT-HANDOFF.md;
earlier status entries below retain history.

Latest: Live returns through the actual paid-game outer caller to another Start
prompt. A generated test completes three consecutive paid plays in one machine
session (credits6→3, bank16).181 headless groups/eight WPF modes pass. The three-flag feature route
stops explicitly at EE16 before unrecovered accounting. See
recovery/PAID-CYCLE-RETURN-PASS.md for exact MAME windows and coverage limits.

Latest: Live passes paid result evaluation and can offer/execute an ordinary nudge
with the existing physical buttons, stopping at B749 before post-sequence results.
A generated no-nudge route stops at FC7C.177 headless groups/eight WPF modes pass. See
recovery/PAID-RESULT-ORDINARY-NUDGE-PASS.md for exact reference windows, the mixed
Live input experiment, interrupt-stack limits and reproduction.

Latest: Live completes the paid reel motor spin and stops at F398 before result/
award dispatch.172 headless groups/eight WPF modes pass, including motor Pause/
Resume. See recovery/PAID-REEL-SPIN-PASS.md for evidence and remaining limits.
Earlier checkpoints below are history.

Latest: Live passes the incremental native tone and selected pre-spin random
gates, reaching F38C before final request selection/spin.168 headless groups/eight
WPF modes pass, including native-tone Pause and48 isolated reel-request cases.
See recovery/START-TONE-SPIN-GATES-PASS.md for pacing and coverage qualifications.

Latest: Live returns to the genuine Start prompt, accepts the physical button,
debits credits6 to5 and records stake accounting. FC4D timed tone/paid spin is the
next boundary.163 headless groups/eight WPF modes pass, including preplay Pause
and mouse Start. See recovery/PREPLAY-START-STAKE-PASS.md for natural windows,
75-case matrix, preservation checkpoint and remaining coverage limits.

Latest batch reaches FC99 preplay dispatch after verified background services and
credit/display return.156 headless groups/eight WPF smoke modes pass. See
recovery/BACKGROUND-SERVICES-PREPLAY-PASS.md for the explicit MAME characteriser
adapter, fault/reset limits, reproducible captures and next eligibility task.

Latest completed batch: Live reaches FBF1/native482F after IC8 output and initial
background dispatch.150 headless groups/eight WPF smoke modes pass. See
recovery/IC8-BACKGROUND-ENTRY-PASS.md for capture qualifications and next work.

Latest: Live completes bank-limit service/outer-cycle return and the next credit/
bank display refresh through FAF0.147 headless groups/eight WPF smoke modes pass.
See recovery/NUDGE-CYCLE-RETURN-PASS.md; next recover IC8/background service paths.

Previous continuation: Live reaches AF25 after outer award statistics, scaled
counters and cash-bank commit.142 headless groups/eight WPF smoke modes pass.
See recovery/NUDGE-AWARD-STATISTICS-PASS.md for proof and bank-service boundary.

Previous batch: completed meter display/wait and seven-flash tail. See
recovery/NUDGE-ANIMATION-TAIL-PASS.md.139 headless groups/eight GUI smoke modes pass.
That checkpoint stopped at AFF0 with pending0/current-win16 and refreshed display, before outer
award/bank/collection routing. A successful AFC2→AFF0 natural window now supplies
terminal accounting RAM. Older failed-later prefix/full-logging crash limits remain.
No installation or configuration
change, commit/push or cloud setup was performed.

For current priorities and continuation context, read [PROJECT-ROADMAP.md](PROJECT-ROADMAP.md)
and [CURRENT-HANDOFF.md](CURRENT-HANDOFF.md). The dated sections below retain the
history of setup and implementation batches.

The local clone points to the expected GitHub remote. Installed .NET SDKs observed on
2026-10-14: 5.0.404, 7.0.304, 8.0.407 and 9.0.313. The initial solution uses installed SDK 9.0.313 and net8.0 targeting packs. No SDK was installed or pinned. FruitMachineLab.sln includes WPF; FruitMachineLab.Headless.sln builds independently.

Shared instructions are in AGENTS.md. No app project registration, cloud environment,
GitHub authorization, commit, or push has been performed by this setup pass.

## Local project

Add the existing clone as a local project in the desktop app's Codex view, with this folder
as the primary project directory. Start a local task there. This makes repository Git tools
and automatic project-instruction discovery target FruitMachineLab.

The original analysis workspace remains separate. Bring across curated reports, semantic
maps, reproducible tooling and selected fixtures; preserve the original forensic workspace.

## Cloud environment

Create an environment through Work in > Cloud > Select environment > Create environment,
or Settings > Codex Cloud > Environments. Select johnparker007/FruitMachineLab and complete
GitHub authorization if requested. Review the proposed dependencies before approving setup
or publishing the environment.

First establish the headless solution and documented build/test commands locally, then use
those commands to prepare and verify the cloud environment. Windows UI and local hardware
tools need separate validation on Windows; do not treat headless cloud tests as UI validation.

Cloud tasks have isolated working files. Local changes become available through reviewed
commits and pushes, not automatic folder synchronization. Local ROMs, MAME, Ghidra and
loopback MCP services are not automatically available to cloud tasks.

Use separate branches for concurrent work and integrate through review. Preserve a reference
behaviour baseline separate from experiments that change game rules.

Official guidance:
- https://learn.chatgpt.com/docs/projects
- https://learn.chatgpt.com/docs/environments/modes
- https://learn.chatgpt.com/docs/environments/cloud-environments

## First implementation milestone

Create the C# headless runtime and a simple Windows diagnostic UI, then execute Skill Cash
against a selected recorded path. Record the exact SDK and build/test commands. Do not
publish ROM binaries or assume apparent ROM padding is usable space.

## Initial C# batch — 14 October 2026

The repository now contains curated recovery reports, semantic maps, decoded scripts,
a selected Skill Cash trace with independently checked a/b hashes, and headless/WPF
projects. See ../README.md for exact build/run commands and ../IMPLEMENTATION-STATUS.md
for evidence boundaries. Eight dependency-free verification groups cover cell semantics,
initialization, normalization, intermediate replay stacks, fail-fast unsupported helpers,
corrupted-fixture rejection and recorded dispatch tokens.

Skill Cash is currently a bounded mechanics replay, not complete standalone feature
execution. Selection/timing/random gates, NVRAM and win animation remain untranslated.
No installation, system configuration, commit, push or cloud setup was performed.

## Selection/scheduler follow-up

Both solutions build with the existing SDK. Verification now has 29 groups,
including complete C699 replay. See recovery/SKILL-CASH-SELECTION-SCHEDULER-PASS.md
for current boundaries; the initial-batch paragraph above is historical.

## Continuous feature follow-up

The current WPF viewer runs continuous C721 verification, including native sound
timing and lamp frame memory checks. Thirty-nine headless verification groups pass;
no manual GUI check is required between runtime batches. Physical peripheral effects
and interactive platform timing remain open. See
recovery/SKILL-CASH-CONTINUOUS-FEATURE-PASS.md for exact evidence boundaries.

## Alpha/output follow-up

The viewer now includes alpha shadow and IRQ latch timelines. Forty-seven headless
verification groups pass with the existing SDK. See
recovery/SKILL-CASH-ALPHA-OUTPUT-PASS.md for the distinction between verified software
effects and unresolved electrical/platform timing. No new dependencies were added.

## Shared timing follow-up

Fifty-three headless verification groups pass. The IRQ view now includes timer
callback masking after scans, driven by captured CPU-cycle offsets. See
recovery/SKILL-CASH-SHARED-TIMING-PASS.md for the shared-memory proof and remaining
elapsed timer/CPU scheduling work. Existing build/run commands remain unchanged.

## Timer deadline follow-up

Fifty-seven verification groups pass. Actual timer latch writes and IRQ entry now
have an independent capture, checked against the shared callback timeline. See
recovery/SKILL-CASH-TIMER-DEADLINE-PASS.md for the bounded countdown calculation and
unresolved CPU acceptance latency. Build/run commands and dependencies are unchanged.

## Visual playback follow-up

The diagnostics app now opens on a playback tab. Load & play Skill Cash verifies
and plays the 12.209-second recorded path at 1×, with lamps, alpha and transport
controls. 61 headless groups and an opt-in WPF smoke/render check pass. See
recovery/SKILL-CASH-PLAYBACK-PASS.md for renderer boundaries and smoke instructions.

## Live Skill Cash follow-up

Live mode now incrementally executes one feature with a momentary physical Start
control. Pause/Resume suspend the VM and virtual clock. Playback remains separate.
The initial pass had 67 headless groups and Live/playback WPF smoke checks. WPF was built in isolated
temporary output because an existing app locked normal build DLLs. See
recovery/SKILL-CASH-LIVE-PASS.md for exact comparisons and unresolved CPU/IRQ pacing.

The subsequent recovery/SKILL-CASH-EXTENSION-PASS.md documents 77 passing groups,
all six default live award levels, jackpot announcement support and captured IRQ
occupancy pacing. Build commands and dependencies are unchanged. The optional
--live-jackpot-smoke-test <fresh-output-directory> is an accelerated physical-input
and render check, separate from the real-time Live smoke mode.

## Board entry follow-up

81 groups now pass. Live defaults to the recovered E2FC board-result entry for
type 2/position 32, including take gating, announcement, cash-feature table dispatch
and the return to E33C. The checkbox retains the earlier C721-only diagnostic entry.
See recovery/SKILL-CASH-BOARD-ENTRY-PASS.md. Build/smoke commands are unchanged.

## Board selection follow-up

87 groups pass. Live defaults to DD38 on square 32: press TAKE FEATURE, release it,
then use START for Skill Cash. The entry selector also retains C721 and E2FC modes.
START on the board reaches an explicit dice-motion boundary; Restart recovers from
that stop. See recovery/BOARD-SELECTION-TAKE-PASS.md for natural reference evidence,
physical-input mapping and comparison exclusions. Build/smoke commands are unchanged.

## Dice request follow-up

92 groups pass. START at the default board prompt now calculates a native dice
request and renders ROLLING, stopping before 61F6 physical motion. The Take route
and playback remain intact. --live-roll-smoke-test <fresh-output-directory> adds
a real-time Start/request/boundary/restart UI check. See recovery/DICE-REQUEST-PASS.md
for natural capture comparisons and static edge tests. No dependencies changed.

## Dice motion follow-up

99 groups pass. START at the board prompt now runs one incremental motor roll,
with generated optic feedback, changing text face and real motor/VM Pause/Resume.
It stops before B28F returns to board movement. The existing roll smoke switch now
checks motion, pause/resume and completion. See recovery/DICE-MOTION-PASS.md for the
7,103-dispatch comparison and explicit 83/84-byte alpha brightness qualification.
No tools or dependencies were installed; the small MAME-derived motor model carries
BSD-3-Clause attribution in THIRD-PARTY-NOTICES.md. Build commands are unchanged.

## Board movement follow-up

106 groups pass. Live START now continues the roll into one incremental board
advance, with square/pot/history diagnostics and actual mid-movement Pause/Resume.
It stops at the following result/selection, or before a ladder/snake animation.
The roll smoke switch covers both motor and board pauses. See
recovery/BOARD-MOVEMENT-PASS.md for the natural 12,355-dispatch proof, separately
classified synthetic nudge probe, arithmetic edges and unresolved timing. Build
commands and dependencies are unchanged. No installation or system setup occurred.

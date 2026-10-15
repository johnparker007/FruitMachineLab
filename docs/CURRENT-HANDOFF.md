# Current handoff

Updated 15 October 2026. Read PROJECT-ROADMAP.md for agreed direction and AGENTS.md
for permissions and preservation rules. This checkpoint records the last development
batch, including its verification.

## Working implementation

- C# headless runtime/Adders projects and separate WPF diagnostics app.
- Live Skill Cash: incremental VM, retained state, physical momentary Start input,
  actual Pause/Resume, generated lamp/alpha outputs and diagnostic state display.
- Separate verified playback/scrubber; original MAME-backed verification retained.
- Last development batch: 127 headless groups passed. Headless and isolated WPF
  builds passed; Live/playback WPF smoke checks and rendered layouts were checked.
- John subsequently reported that the live feature works well.

See recovery/SKILL-CASH-LIVE-PASS.md for implementation details and exact boundaries.
Live uses provisional captured CPU pacing and repeated IRQ service boundaries.
Reference-time Start presses match 18 VM/frame/accounting checkpoints, 44 alpha
states and final lamp frame memory, but not full CPU state or transient scan timing:
147,310 live dispatches/12.317 s versus 98,704 reference dispatches/12.209 s.
The jackpot announcement now runs live, and all six default award levels complete.
See recovery/SKILL-CASH-EXTENSION-PASS.md for the synthetic helper proof, captured
IRQ occupancy adapter and exact limitations.

Live now defaults to DD38 at board square 32. TAKE FEATURE is physical BLACK2 bit
01; START remains bit 80. Take enters Skill Cash and returns through the restored
DDAF/DE75/E43D frames to E460. The entry selector retains C721 and E2FC modes.
All six default award levels complete through all three modes. START at the board
prompt now runs one incremental dice roll with ROLLING, changing face/position,
native busy-loop completion and symbol refresh. Pause/Resume also suspend the motor.
It continues through incremental board advance and link dispatch. The GUI now
enables continuation by default; disable that option for the earlier one-advance
DE96/DD38 boundary. Restart restores the selected entry.
Nonzero links now execute recovered ladder/snake animations. Two new natural DBC4
entry modes expose ladder 2→22/pot3 and snake 41→7/pot1. With continuation disabled
they stop at DE81; enabled, they continue subject to the explicit result boundaries
described below. Requested symbol/offset stay
separate from the changing position and displayed face. Board square, nudge pot,
raw ROM type/link and visited squares are visible.
The natural selection reference checks 99,843 exposed VM observations (with explicit
uninitialized-local masks), 7,331 lamp requests, 6,099 sound commands, 1,107 alpha
bytes and 868 input-condition reads. Its full original C721 source digest remains
unchanged. See recovery/BOARD-SELECTION-TAKE-PASS.md for exact qualifications.

The retained natural square-7 request reference checks 485 VM observations, 15 lamp
requests/frame results, 16 sound commands, 50 alpha bytes and five input conditions.
Its 478-dispatch body independently matches a narrower capture. Eight live timing
variations at square 32 request symbols 2,4,6; those tests now also require completed
motor motion and matching refreshed symbols.
See recovery/DICE-REQUEST-PASS.md for native profile, symbol and alpha-loop recovery,
static entry-cost equivalences and the distinction between the two board contexts.

The latest motor reference checks 875 native observations, 386 services including
cleanup and 96 optic/update operations; independent MAME runs agree on the core
states. A driven Barcrest model independently generates the captured optic bits.
Device saved-item observations validate the opposite motor/ROM coordinate directions
and feature-entry phase seeds. The combined path matches 7,103 VM observations,
15 lamp requests and 167 sound commands. Alpha has one documented FF brightness
restoration difference (83/84 bytes); text/cursor/reset agree. It is not an exact
alpha-timing match. See recovery/DICE-MOTION-PASS.md and THIRD-PARTY-NOTICES.md.

The new natural movement reference checks 12,355 VM observations, including board
and pot, 11 lamp requests and 60 sound commands, from square 7 to 11 with pot 4.
A separate explicitly synthetic DDE3 helper probe checks 9,565 lifted observations
and 36 sound commands (9,613 raw observations; 48 typed-list inner observations
excluded). It is not a natural nudge-animation path. Live timing variations run
32→34/36/38, with per-square lamp steps and pot logic executed by the actual VM.
See recovery/BOARD-MOVEMENT-PASS.md for arithmetic, IRQ-byte read phases, synthetic
scope and preserved earlier timing qualifications.

## Next development work

Latest batch: one completed main-reel nudge runs Live on all3 controls, selected
position changes by-6 modulo96, requests clear, remaining/pot3→2 and awards0.
Separate main-reel text positions/symbols/motor state; actual mid-motion pause.
Natural Nudge1 proof:135 native observations,60 services/eight optic reads,
device seeds and generated optics match. Connected safe prefix:750 VM,63 lamps,
144 sounds,65 alpha bytes. 127 groups/eight WPF smokes pass. See
recovery/NUDGE-MOTION-PASS.md. Dice references remain unchanged.

New boundary B339: subsequent B33B reads uninitialized local byte+2, MAME8F
versus runtime0B native S-stack residue. Both comparison and Live stop before
the read. Do not seed a constant, add a mask, normalize the branch or invent
timing. Raw source continues through B34E; native cleanup is already complete.
Next recover native stack writes feeding this byte, then the actual returned
nudge prompt/result and accounting. Native2BEB wait now suspends VM while busy.

Preservation policy: complete playable PC machine first; full symbolic6809
assembly/reassembly, editor/compiler/relocation toolchain deferred. Eventual
reconstructed kit aims for byte-identical baseline then editable native/VM ROM
source for hardware testing, not original author source/tools. Extend existing
native JSON, VM listings, maps, provenance and reports with discovered exact bytes,
labels/RAM meanings/frames/side effects/references/layout constraints and C#/test
links. No unrelated coverage work. No lossless/full-rebuild claim without checks.
New nudge-encoding-checkpoint.json checks627 native disassembly rows/seven VM
spans against ROM bytes, links five existing exports and preserves7659/82BB
dictionary records. Tool Curate-NudgeEncodingCheckpoint.ps1 consumes existing
Export-MameDisassembly.ps1 -NudgeCheckpoint output. Linear code/data typing and
complete source coverage remain unresolved. No live Ghidra API is exposed;
portable full symbols/comments/data-definition export is an explicit gap.
Preserve original projects; export read-only at checkpoints when access permits.

Previous input batch: Live TAKE at22 reaches3 NUDGES and accepts NUDGE1/2/3 through
actual sampled BLACK2 bits02/04/08 (selectors1A/18/16, table9E06). Only the chosen
requested offset increments; stop before B31F, BE remains3 and awards remain0.
Controls release on pause, capture/focus loss, window deactivation and stop.
Native1AA3 and alpha69/3DA7 are translated and checked. Dynamic native condition
EXECUTE uses the existing callback without adding VM frames. See
recovery/NUDGE-INPUT-PASS.md and maps/nudge-inputs.json.

Natural references:375 prompt observations through B403;553 physical Nudge1
request observations through B31F; full VM/lamp/sound/alpha match. Each preserves
the prior229-observation preparation prefix and the same141 local masks. Natural
request uses an explicit six-frame physical Nudge1 pulse after the three-nudge
display; no state injection. Matrix1AA3 covers seven synthetic cases below0700.
124 headless groups/eight WPF smoke modes pass. New --live-nudge-smoke-test uses
focused keyboard handlers for all3 controls and checks mouse-capture failure/loss
release; actual mouse-held nudge acceptance is not automated. Existing7 modes pass.

Next: capture B31F through completed main-reel motion, B306 nudge consumption,
refreshed symbols and returned prompt/result. Verify61F6 service, optics and
cleanup independently rather than reusing dice assumptions. Do not decrement
count, move reels or issue awards speculatively. UI has no gameplay logic.

Previous preparation batch: 29EC flagged search translated and matched against a
17-case synthetic native matrix. Natural physical TAKE at square22 now captures
E247→B4C5: 229 VM observations, 24 lamps, three native calls, zero sound/alpha in
this narrow segment. Live type1 dispatch prepares BE=3, BD=15hex and stops before
main-reel nudge interaction at B4C5. Type2 Skill Cash and other boundaries remain.
See recovery/NUDGE-PREPARATION-PASS.md and nudge-preparation-semantics.json.

Nine-byte local-frame allocation exposes undefined CPU-stack residue. The new
fixture masks its first word for 141 observations, enabling high/low bytes only
after B2D0/B2E2 writes; raw digest retained. Verifier derives these ordinal masks
independently. Do not weaken earlier references or seed those bytes as game logic.
118 headless groups and seven GUI smoke modes pass. No commit/push/install/config.

Next: capture B4AD/1AA3 matching-result gate, 9FA2 flag test and B3C8 prompt through
B403 input scan. Determine 9E06 selectors/MAME input mapping before adding nudge
controls; verify B31F main-reel motion separately from the existing dice motor.
Nudge play, result accounting and whole-machine play remain incomplete.

The previous availability batch resolved the 29F4 stop after a ladder. Live now
reaches square22/pot3 TAKE NUDGEPOT, computes best result 0010 and accepts START
for another generated roll or TAKE to the type-1 result boundary. See
recovery/NUDGE-AVAILABILITY-PASS.md. Recovered 29F4/2A7F/1AC3/1B63/1B7B preserve
candidate order, byte wrap, scratch writes, symbol restoration and DD/DE effects.
The 17-byte counted-frame use is inlined; generic SWI2 overflow is unsupported.
Natural proof: 5,544 VM observations, 65 lamps, 420 sounds, 1,631 alpha bytes and
52 native calls. Synthetic matrix: 17 cases with every RAM byte below0700 matched,
excluding native S-stack residue above it. Live pacing still uses budget-3 costs.
That batch passed 116 headless groups and seven WPF smoke modes, including
--live-availability-smoke-test. E247/B91D/29EC preparation now executes as above;
continue B4C5 and main-reel interaction next. Availability is not playable nudges.

Earlier continuation batch: default GUI checkbox now enables repeat selection and
retained-state next rolls. 32→36 returns to an interactive DD38 prompt and accepts
another physical START, preserving all memory/motor/accounting. Disable the option
to reproduce earlier one-advance/link boundaries. The headless `continueBoard`
argument remains opt-in. Board prompt count is visible; readiness starts at DD4E.
See recovery/BOARD-CONTINUATION-PASS.md for scope and six GUI smoke modes.

Natural extended references match 620 ladder observations through DD38, 22,902
snake observations through E2FC/type8 and 12,363 normal movement observations
through E2FC/type3. Complete prior prefixes and all VM/output hashes match. Live
stops at unsupported E2FC types. The earlier 29F4 stop is now resolved as described
above. The repeated 32→36→next roll is synthetic player timing, not a complete
natural MAME reference. The updated dependency map links assembly translations
and verification; do not assume nudge-result/play semantics are also recovered.

Natural nonzero-link DBC4 paths now match 571 ladder and 22,887 snake VM
observations, with exact reference lamps/sound/alpha. Live matches ordered lamp
requests, final alpha shadow, destination, pot and accounting, with explicit
polling/timing differences; see recovery/BOARD-LINK-PASS.md.
Continue recovery of the remaining board-result and availability helpers.
DDF3 movement and zero-link DBC4 dispatch
now execute and are reference-checked. Continue the following board result or
selection after that; only recovered routes continue and missing helpers stop explicitly.
Normal dice motor preparation, service, generated optics, completion and symbol refresh now run;
homing, motor-disabled shortcuts and complete alarm handling remain outside this
feature-entry milestone. Startup, credits and whole-game play
remain open. Resolve the new alpha brightness timing discrepancy with native/IRQ
phase evidence, preserving strict earlier alpha comparisons.
Improve timing and remaining Skill Cash option coverage. Prioritize playable coverage,
not script editing. Bring layout integration into normal-play development using
John's existing importer/renderers when their locations and assets are available.
Work not dependent on those references can proceed independently.

## Practical checks

```powershell
dotnet build FruitMachineLab.Headless.sln --no-restore
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .
dotnet build FruitMachineLab.sln --no-restore
```

An open diagnostics app can lock normal WPF output. Do not stop John's process;
build the diagnostic project to a fresh temporary output folder when necessary.
Smoke switches are documented in the Live/playback recovery reports.

--live-link-smoke-test <fresh-output-directory> checks both natural DBC4 entries,
real-time rendering, memory/time/VM pause, resume, destination/pot, input release
and restart. All five GUI smoke modes passed this batch.

The default Live/jackpot smoke exercises physical Take before Start, plus Take
capture/focus release. The jackpot driver remains accelerated. Replay uses captured
input-port/native scheduling phases; Live never substitutes recorded player events.
Raw boundary capture and temporary diagnostic comparison files remain outside Git.
--live-roll-smoke-test <fresh-output-directory> checks real-time physical Start,
changing position/face, actual mid-motion and mid-board pause/resume, completed
roll/advance, next-dispatch boundary, released controls and clean restart.

No agent commit, push, installation, configuration change or cloud setup was
performed. Inspect git status before the next batch; do not infer commit state
from this checkpoint. The original analysis workspace remains preserved separately.

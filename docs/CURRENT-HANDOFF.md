# Current handoff

Updated 15 October 2026. Read PROJECT-ROADMAP.md for agreed direction and AGENTS.md
for permissions and preservation rules. This checkpoint records the last development
batch, including its verification.

## Working implementation

- C# headless runtime/Adders projects and separate WPF diagnostics app.
- Live Skill Cash: incremental VM, retained state, physical momentary Start input,
  actual Pause/Resume, generated lamp/alpha outputs and diagnostic state display.
- Separate verified playback/scrubber; original MAME-backed verification retained.
- Last development batch: 139 headless groups passed. Headless and isolated WPF
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

Latest batch: Live completes the meter display/wait and AF67 seven-flash tail,
including AF4E even rounding and NVRAM refresh, then stops at AFF0. Pending0/
current-win16, final display refreshed. Next follow AFF0 through EDB4/EE11 and
its real caller before implementing bank commit, collection or payout. See
recovery/NUDGE-ANIMATION-TAIL-PASS.md.139 groups/all8 GUI smoke modes pass.
Headless checks pause during the flash loop as well as rewind/meter transfer.

New nudge-tail fixture: successful natural TailWindow capture from final AFC2
through AFF0, saved entry/terminal RAM, exit0.13469 VM observations, no lifted
dispatches/masks, zero lamps,63 sound commands,406 alpha bytes. Entry signatures
match the old verified transfer prefix's terminal fields; verifier requires window
provenance/success. Terminal protected51-byte vector/pending/win match exactly,
including in Live. Earlier failed-later prefix stays qualified; this is linked-
window proof, not a new full earlier-dispatch campaign.

Removing the motor saved-item reader alone did NOT prevent the full-dispatch
crash. A run with rejected !(...) syntax logged only entry/terminal and was
rejected by prefix comparison. Capture/curator now reject expression errors.
Corrected narrow logging succeeds; root cause of full-logging crash remains open.
-TailWindow enables VM logging at final AFC2 and seeds tail-entry-ram.bin.
-NoMotorItems omits only a read-only temporary Lua observer; original settings
are unchanged and native motor/optic logs remain. Preserve these qualifications.
Data map now includes8714/8716 sound bytes;38 exact VM spans/700 native rows
retained. Full symbolic tooling deferred; fresh Ghidra metadata export unavailable.

Previous transfer batch: Live returned through E263's indexed dispatcher and E460 board
exit and EDD3/EE11/EDB4/AF93 transfer. Its old stop was final AFC2; the new AFF0
boundary is above. Bank commit, collection and payout remain unrecovered.
See recovery/NUDGE-WIN-TRANSFER-PASS.md.137 groups/all8 GUI smoke modes pass;
actual pause/resume during rewind and mid-meter transfer freezes memory/time.

Successful nudge-exit capture:66412 canonical VM observations/171 lamp-frame
requests/1005 sound commands/424 alpha bytes, prefix66368 independently retained,
saved terminal RAM at E460, exit0. Selected nudge-win-transfer prefix:95391 VM/
203 lamps/1341 sounds/987 alpha bytes through AFC2 pending0/win0010. That source
process FAILED LATER; ObservedPrefix=true and unsuccessful exit code retained in
sidecar. No terminal transfer RAM snapshot, later-campaign or full stability claim.
Verifier requires explicit prefix provenance and exact selected boundary. All
canonical signatures/output hashes match; raw101588 and6197 exclusions retained.
The previous successful exit prefix independently matches in full.

Live matches ordered lamps/final alpha to the transfer prefix, final reels to
the saved exit state, each intermediate AFC2 meter step1..15 and conserved total16.
Final step16 stops before execution. NVRAM complements are checked internally;
complete terminal RAM equality is not asserted without a snapshot. Earlier strict
result/exit snapshot comparisons remain unchanged. No recorded input events in Live.

Next obtain clean transfer snapshot/diagnose repeatable external MAME capture
crash, then recover AFC2 display/wait and AF67 tail and actual outer award route.
Do not simply jump to FC76: EE11 calls EDB4 before that return cursor is reached.
Capture switch -NudgeExit stops E460; -NudgeWinTransfer targets final AFC2.
The latter observer must keep ordinary logging active at earlier AFC2 iterations.
Curator -ObservedPrefix is deliberately explicit and only allowed for this target;
ordinary curation rejects unsuccessful processes. Failed exploratory runs are not
successful campaign proof.38 selected VM spans/700 native rows are byte-checked;
new8B41 sound children and inline alpha bytes retained in existing data map.

Previous improvement batch: the exhausted Nudge1 sequence runs the ROM's automatic
improvement. B712/B652 compare the current result with the saved target; B666
rewinds through actual motor steps, B6DB/B384/B352 compute/execute the plan, and
B72D/B91D/E247 return pending BA=0010 (16 ROM units), current win02FA=0000.
Final positions6,90,42 and symbols2,2,2; BE/BF0. At that checkpoint Live stopped
at E263; the newer boundary and verification scope are described above.
See recovery/NUDGE-IMPROVEMENT-PASS.md. 135 groups/eight WPF smoke modes pass.

Natural reference:66368 canonical VM observations,162 lamps/frame results,1005
sound commands,405 alpha bytes. Raw72565 retained; exactly6197 typed-list/local-
release observations excluded and independently counted by the verifier. Prefix
7785 independently matches nudge-sequence. Two complete captures agree on the VM
digest;3360 native core observations agree independently, with eight motor
requests/completions and72optic reads. Terminal RAM is saved read-only at E263;
the verifier and Live match51 protected bytes2F0..322, pending and final reels.
Live ordered lamps/final alpha match; automatic-motor pause/resume freezes state.
Captured CPU/IRQ pacing and other earlier timing qualifications remain explicit.

Native2A2F/token8084 returns three signed ASRB/SEX movement cells (reel3 on top),
restores symbols, preserves search scratch and leaves DD unchanged.17-case
synthetic plan/lookup matrix checks all RAM below0700, excluding native S residue.
Token7A26 follows the saved F6 outer-loop link. New exact bytes, data references,
routine labels/C# links are in the existing encoding/semantic maps. Fresh Ghidra
metadata export remains unavailable; do not install/configure anything for it.
Two failed exploratory external MAME captures are excluded; completed proof runs
exit0. No award banking/collection, full-machine startup or other-option claim.

Previous return batch: B339's native save-area dependency is resolved. Native4A8C saves
D=008F at physical VM S-10 through gateway77A8; its low byte is later local+2.
The lamp translation preserves the relative save area, not a fixed byte seed.
7A15/7A17 explicit loop leave now removes the current eight-byte frame and restores
F6. Live returns to the next nudge prompt; three Nudge1 presses exhaust BE/BF3→0,
reel1 moves12→6→0→90, accounting stays0. All3 controls have first-movement/return
tests. Native-stack footprint coverage remains partial; no general CPU claim.
See recovery/NUDGE-RETURN-PASS.md. 132 groups/eight WPF smoke modes pass.

New references: nudge-return.json checks2817 VM/67 lamps/157 sounds/111 alpha
bytes and preserves the750-observation earlier prefix. nudge-sequence.json checks
7785 VM/148 lamps/462 sounds/195 alpha bytes and preserves that2817 prefix.
727 native observations include three motor preparations/completions and24optic
reads; generated optics and translated active motor phases match. Idle service
observations are retained, not claimed as full CPU comparisons. Earlier dice
references remain unchanged. Natural repeated-input proof is specifically Nudge1.

Previous Live stop: B749, before B74D/B712 improvement and result routing,
now superseded by the E263 boundary above. Do not fabricate subsequent awards
or caller cleanup.
The failed exploratory MAME sequence run is excluded; the retry completed exit0.

Previous motion batch: one completed main-reel nudge ran Live on all3 controls, selected
position changes by-6 modulo96, requests clear, remaining/pot3→2 and awards0.
Separate main-reel text positions/symbols/motor state; actual mid-motion pause.
Natural Nudge1 proof:135 native observations,60 services/eight optic reads,
device seeds and generated optics match. Connected safe prefix:750 VM,63 lamps,
144 sounds,65 alpha bytes. 127 groups/eight WPF smokes pass. See
recovery/NUDGE-MOTION-PASS.md. Dice references remain unchanged.

Previous boundary B339 (now resolved as above): B33B read uninitialized local byte+2, MAME8F
versus runtime0B native S-stack residue. At that checkpoint both comparison and
Live stopped before the read. The resolution above preserves its real writer;
it does not seed a constant, add a mask or normalize the branch. The earlier raw
source continues through B34E; native cleanup is already complete. Native2BEB
wait suspends VM while busy.

Preservation policy: complete playable PC machine first; full symbolic6809
assembly/reassembly, editor/compiler/relocation toolchain deferred. Eventual
reconstructed kit aims for byte-identical baseline then editable native/VM ROM
source for hardware testing, not original author source/tools. Extend existing
native JSON, VM listings, maps, provenance and reports with discovered exact bytes,
labels/RAM meanings/frames/side effects/references/layout constraints and C#/test
links. No unrelated coverage work. No lossless/full-rebuild claim without checks.
Updated nudge-encoding-checkpoint.json checks700 native disassembly rows/17 VM
spans against ROM bytes, links nine existing exports and preserves7659/82BB/7A15/7A26/8084
dictionary records. It retains61 natural stack watchpoint writes and producer/
consumer/C# links. Curate-NudgeEncodingCheckpoint.ps1 consumes the existing
Export-MameDisassembly.ps1 -NudgeCheckpoint output and optional -StackRunDirectory.
Linear code/data typing and
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

# MC6840 timer clock foundation and phase findings

## 17 October: generated outer dispatch and post-panel counters

Live no longer consumes any shared-timing Events, including scan entry. Its
retained accepted outer IRQ entry now starts `Mpu4Timer1DispatchExecution`, which
generates FE70..FEB7 and28FE entry from original native instruction costs. Bank0,
no IC4 priority, no timer2 priority and pending timer1 remain explicit contracts.
The original cpu-interrupts export now retains6103 timer1_handler_entries in
addition to6045 interval unions; union merging had hidden58 nested timer1 services.
Existing intervals, cost dictionaries, initial/duration/busy cycles, entry and
depth fields were checked unchanged on export. No duplicate timeline system was
created. Accepted outer IRQ timing is STILL observational, not generated hardware
assertion/CPU acceptance, and the new dispatch must not be described otherwise.

The ordinary dispatch costs65 cycles. Saved U at8,S is compared SIGNED against
0525; a failed BGE executes original FEB5 SWI2. With ROM719C=00, its vectorFFF4
pointsFE66: LDA719C, BITA01, untaken LBNE, full RTI toFEB7. SWI2 costs20 cycles,
the selected handler27 more, so scan entry is112 cycles. This preserves an odd
but real reference behaviour: valid temporary ROM pointers in U (e.g.8EF5) are
negative for this check, but the configured software-interrupt handler ignores
the alarm. No unsigned comparison, skipped software interrupt or patched ROM.
The enabled719C alarm path remains an explicit unsupported boundary. Full native
S-frame/register writes/restoration are an owner contract, not a6809 interpreter.

64 isolated original-ROM dispatch cases match every address/opcode, instruction
start/completion, native final S and saved-U frame, covering65/112 and signed
threshold extremes. A pending timer1 flag is established with control02/latch1;
its IRQ enable is deliberately OFF so ANDCC does not recursively accept repeated
one-tick physical IRQs. This is a labelled synthetic code-path experiment, not
a claim to naturally enter a handler with IRQ disabled. An initial control42
experiment did recurse after ANDCC, was aborted, and is excluded with raw hash.
Nineteen existing natural normal prefixes independently match all instruction
times, without captured scan entry serving as the execution schedule.

A new PASSIVE full-feature observation records FE66 opcode fetch, actual saved
outer U, current CPU U, SWI saved return and ROM option. It uses ordinary RAM and
CPU state, not extra hardware-register reads. All60 natural112-cycle dispatches
match: FE66 starts handler+77, saved returnFEB7, option00 and equal saved/current
ROM U pointers. The354 original timer samples retain their identical SHA256.
Curate-Timer1GuardTiming.ps1 joins these observations to the independent original
IRQ/scan log and rejects count, phase, timing or frame mismatches. These records
are proof data, not operands injected into Live.

Live's accepted-entry adapter currently supplies its mapped logical VM U. It
does NOT reconstruct temporary native U inside atomic sound/motor helpers or
inject captured U to reproduce those60 frames. Consequently this is not a full
native-frame/timing equivalence claim. Reconstructing CPU ownership/register
state while staging sound execution is a prerequisite for exact arbitrary-entry
guard timing and eventual removal of accepted-entry/occupancy templates.

`Mpu4PostPanelExecution` now generates280F..2851 counter/sense work. It preserves
16-bit wrap at2D/2F, INC33 byte wrap, nonzero35 countdown, and31's original holds:
increment candidates0101/8000 are not stored, leaving0100/7FFF unchanged. The old
atomic adapter omitted31; it is now recovered behaviour, not a ROM bug fix.
2837 reads actual IC4 portB through a device callback. LSRA samples undercurrent
bit0; with clear sense, zero filter stays zero and1..3 clears; otherwise the
selected byte8+column increments with byte wrap. Live's selected ordinary-machine
sense model leaves undercurrent inactive, while keeping the dynamic optic upper
bits. Arbitrary electrical fault/current-sense generation is not implemented.
Effects occur at generated instruction completion; this is not a per-byte RAM
bus simulator. State is preserved if paused between LEAX and STX or read/store.

The idle motor predecessor is generated too: JSR6403/TST6B/BPL6402/RTS takes22
cycles. Busy6407 onward still invokes the existing atomic translated game adapter
under retained outer occupancy, without inventing a motor-body duration. The
post-panel kernel then stages its known instructions from that explicit boundary.
It stops before2851 stack/alarm validation. FEC3 watchdog/meter/sound service and
native sound task timing remain later boundaries; scheduler tick/2C cleanup are
still an explicit adapter after this generated suffix. Active motor service with
no game adapter stops rather than silently pretending the body is implemented.

64 new injected native counter/sense cases verify exact encodings/times and RAM,
including wraps/held limits and both sense levels.19 natural idle suffixes match
every instruction start/completion. The first synthetic matrix used debugger
b@A/b@B as register addresses rather than literal0A/0B; it is excluded with hash,
and the reproducible script now uses explicit0x addresses. New exact ROM regions,
SWI2 vector/options, implementation links and qualification fields extend the
existing timing-source map and curated evidence conventions. Ghidra export
access remains unavailable; no assembler/compiler/editor tooling was introduced.

The Live mutation test removes all shared event rows AND the timer3 deadline
file, and compares RAM, output events and VM counts. Live Pause is also checked
between a post-panel LEAX and its STX. Reference-time player inputs still match
18 VM/frame/accounting checkpoints,44 alpha states and final lamp frames; poll
count145687→145627 and duration12.317→12.316 virtual seconds remain documented
differences, not rebased full-state equivalence. The synthetic jackpot duration
is23.781 seconds (previous23.777), with unchanged award. Next stage2851/FEC3 and
watchdog/meter/sound CPU ownership, active motor paths and remaining VM native
work before removing accepted outer entry/occupancy. No user installations,
configuration, ROMs, original workspace, MAME checkout/settings or Ghidra changed.
Final validation:257 full headless groups pass; both solution builds have zero
warnings/errors. All eight WPF modes pass.1121 curated entries verify and
whitespace check passes. All owned MAME/GUI/verification processes exited.

## 17 October: generated timer3 acceptance connected to Live

Live now runs `Mpu4TimedPanelService`: generated28FE scan, FEBA/27D2 input,
438C panel and selected coin-idle service, with nested timer3 CPU ownership.
The continuous `Mpu4Timer3PhaseClock` consumes generated70EF status/counter/control/
latch bus accesses. After each completed selected unmasked input/panel instruction,
pending timer3 is accepted. The component yields19 cycles to FE70, runs the
verified128-cycle dispatch with real model acknowledgement/stop, runs the lamp
callback and26-cycle FEF2/FF13 return, then shifts and resumes the pending parent
and all active child iterators. No captured acceptance PC, elapsed handler time,
or per-arm phase is supplied. Timer3 cannot run the VM while owning this service.
Pause freezes the owner, pending instruction, IRQ-entry interval and virtual time.

`SkillCashLiveSession` no longer reads timer-deadlines.json; its old Timer3Irq
tuple field and separate recorded-entry callback scheduling were removed. The
existing timestamp-corruption test now deletes the entire deadline file and
still compares output events, RAM and VM counts. A new causal engine test changes
native drive-prefix work after the same arm and requires a different acceptance
instruction/time; another part pauses after acceptance and checks the19-cycle
entry interval. These are synthetic execution tests, separate from natural proof.
Physical Start remains sampled through0F00 and later staged sticky accumulation;
it is no longer accumulated atomically when the input prefix finishes. The older
input test waits for that actual accumulation while preserving its expected value.

The remaining input-state gap was closed with a passive observation added to
ptm-skill-cpu.lua. Capture-SkillCash.ps1 -FullFeature -PtmInstructionTiming emits
pia-service.csv alongside existing instruction/timer observations. It records
save-state IC5/IC8 portB control, DDR and output items plus ordinary RAM0..03FF at
438C entry and actual0C02/0F02 read/write taps. No extra PIA reads acknowledge IRQs
merely for observation. Curate-PiaServiceTiming.ps1 requires all354 existing timer
rows to match field-for-field. Their CSV SHA256 is unchanged:
76BC7E484ED4AC0B69925C52A103F532143AA501CF51FE22474CCB0E63532C02.
The natural physical campaign, ROM and original tools/settings were unchanged.

Accepted evidence:19 service-entry checkpoints, four actual0C02 reads, eight
0F02 reads and four writes to each port. IC5 control3C/DDRB0F/output20 and IC8
control34/DDRBFF/output30 are stable in this window; C6 points19B8. IC5 reads
combine output low nibble and AUX2 high pins (zero in this supported entry);
IC8 reads its output latch. Live stores the raw IC5 output separately and exposes
the selected mixed read value to existing status helpers. It retains board-entry
IC8 state when that earlier entry has its own checkpoint. Full PIA IRQ/strobe,
coin injection/hopper and priority/startup behaviour are not claimed.

maps/irq-service-data.json exports exact ROM helper tables/inline operands/config
regions and one natural initial state, with provenance. It is a static data and
checkpoint dependency, not a captured timing path. Initial stopped timer3 has
high output, single-fired, latch40/raw212, no pending IRQ and status-read bit set;
subsequent phase is continuous and never replaced from capture. Live does not
load the128 synthetic native case paths to run. Native encodings and RAM meanings
remain linked through the existing timing-source map; no assembly toolchain or
claim of a lossless source listing was added. Ghidra export access remains absent.

The SAME connected owner used by Live now verifies19 natural windows through
280C, including all resumed FEBA/panel instructions, generated IRQ acceptance/
entry/return and20 exact PIA access times/values. Output scan instruction costs
remain checked independently in those same windows. Verification seeds non-scan
RAM from each observed438C entry to isolate the selected service; it does not
claim a continuous full-machine state proof. Live initializes once and executes
subsequent services from retained state. The existing reference-time player run
still matches18 VM/frame/accounting checkpoints,44 alpha states and final lamp
frames; full CPU state equality is not claimed. Synthetic jackpot duration moved
from23.761 to23.777 virtual seconds as atomic service effects became staged;
no reference timing or expected award values were rebaselined to hide this.

Explicit remaining timing dependencies: shared-timing event3 scan-entry/jitter
template, cpu-interrupts outer occupancy, remaining native VM word cost tables,
and atomic post280C motor/counter/scheduler service. Generated timer3 entry is
therefore a real removed dependency, not whole-machine autonomous timing. Next
stage280C/6403 and outer-handler ownership, then generate outer interrupt entry
and VM CPU boundaries before removing occupancy. Do not substitute VM-token
completion for an unknown6809 instruction boundary. Latch40, bank0/selected IRQ
priority and known idle coin continuations are guarded; unsupported alarm/helper/
active-coin paths stop explicitly, with no fallback to recorded timer3 entry.

The diagnostic panel identifies locally generated timer3 and retained outer timing.
Playback remains separate. No installations/configuration changes, commits/pushes,
original workspace, ROM, MAME checkout/settings or Ghidra project changes.
Final validation:251 full headless groups pass; both solution builds have zero
warnings/errors. All eight WPF modes pass, including Live nudge/roll/board/link/
jackpot/availability and unchanged playback.1115 curated entries verify and
whitespace check passes. Owned MAME/GUI/verification processes exited.

## 17 October: ordinary coin-service return and composed438C caller

`Mpu4CoinServiceExecution` recovers4592..4645's ordinary service path. It starts
with explicit machine RAM/ROM state and device callbacks, not a CPU instruction
interpreter. Bit80 of2B takes45FE (A=0F); bit40 reaches4602 (A=2F) and stops
before4604 JSR48DA. Bit20 reaches461F (A=20) and stops before4621 JSR46F1. Those
helpers' names are not complete semantics; neither body is silently replaced.
Other paths test2F0 against50, consume46D3 inline87 at45A8, perform wrapped
16-bit sum `[02FC]+[0302]` then compare2710, and consume inline89 at45C2.
The sum wraps BEFORE the unsigned10000 test; native FFFF+2 cases preserve that
reference behaviour. No inferred saturating arithmetic or bug correction.

45D2 starts A20, compares0370 against73 and0372 againstCD, conditionally tests
inline80 at45E5 and clearsA.0339 controls inline81 at45F1, followed by RAM0 bit02
and optional OR08. Original ROM FF40=FF participates in preceding paths. Output
tail462B tests0338, optionally FF34 (originalFF), and conditionally masksA withDF.
TST results are sampled at their instruction completion and retained across
suspension, rather than rereading RAM after the conditional branch.

4637 writesA to actual0C02.463A reads0F02 and XORsA,463D masks20,463F reads0F02
AGAIN and XORs,4642 writes0F02,4645 returns to4395. This is two device reads with
separate instruction events; replacing them with one cached value changes the
ROM behaviour if the device changes between reads. No flat-memory hardware
substitute is used. Device write callbacks fire at generated store completion.
Actual electrical bus subcycle/read side effects remain the device-owner scope.

CoinIdle optionally composes this service, and PanelAccumulation optionally joins
43E9 idle through4395 into19B8/1A05/1A58 and280C. Existing bounded defaults remain
unchanged.43E5 taken44C3, active pulse43F1/4426/44AB/4519/4562 and alarm/helper
routes remain explicit boundaries. The generic CPU register/S-frame restoration
contract is unchanged; this is a selected translated helper, not full6809 state.
Suspension propagates parent→idle→service→active inline child. Wrapper long-branch
metadata comes from the generated child event duration, not recorded timing.

Capture-CoinServiceTiming.ps1 reproduces64 isolated4592 native calls; -Composed
reproduces64 original438C idle callers. The curator selects coin-service-timing
or coin-composed-timing from recorded provenance. Every executed address/opcode,
instruction start/completion, final hardware output latch and continuation match.
Composed cases return280C or stop4604/4621, with original native S checked by
the curator. Isolated cases return4395 or stop at those same helper calls. RAM
is unchanged in the isolated suffix; composed output/latch and panel accumulation
are checked. Threshold/wrap/inline/guard branches are deliberately varied.

These are synthetic masked-IRQ/FIRQ native experiments, with injected RAM and
PIA DDR=FF/output latches. Composed cases intentionally hold coin/auxiliary inputs
zero. They do not establish natural input pins or initial PIA state, whole-machine
coin insertion, changed ROM option bytes, or Live timing equivalence. Original
FF34/FF40=FF branches are native-backed; other configuration values remain static
translations. Exact4592..4645 bytes, inline operands, mask records, config bytes,
caller regions and per-instruction contexts are exported with ROM hash checks,
external raw hashes and implementation links in the existing source/evidence map.
Unexecuted regions/inline data are included without a lossless-ASM claim.

Engine-only synthetic experiments separately verify251-cycle nested suspension
of the entire composed call, distinct0F02 values across the two reads, no device
calls before their generated completion, and retained TST flags when0338 changes
during an interruption. These are not extra natural MAME observations.

Remaining prerequisite: capture natural IC5/IC8 PIA control/direction/latch/read
state, complete required outer motor/counter/scheduler service, then extend the
19-window IRQ proof and attach selected generated scheduling to Live. No Live
or GUI call sites change here. ROMs, MAME/Ghidra settings/projects and the original
workspace remain untouched. Ghidra export access is still unavailable. No new
assembler/editor/export system, installations/configuration changes or commits.
Validation:250 full headless groups pass; full/headless solutions build with
zero warnings/errors.1112 curated entries verify; whitespace check passes.
Live/WPF unchanged; prior GUI passes retained. All owned captures exited.

## 17 October: bounded43E9 idle validation and actual AUX2 source

`Mpu4CoinIdleExecution` translates43E9 through the idle pulse-validation path
and the seven nine-byte records40E9..4127, stopping before4592's later service.
Capture-/Curate-CoinIdleTiming.ps1 reproduce64 synthetic original-ROM calls;
coin-idle-timing.json preserves exact regions and five-byte instruction contexts,
with ROM SHA1 and external capture hashes in its verification sibling. Contexts
are not instruction lengths, and this is not a complete lossless assembly export.

Entry A is the caller's retained register; reading2A instead would change early
BITA02/BITA04 branches.8A selects an active pulse-state path (43F1) when nonzero.
The idle route clears10/11,8B,DF and8A, then clears2A bits06. X starts40E9,
Y starts12; each record is nine bytes, its input mask at+8. MaskF0 tests all
four high inputs together; other records skip when2A high nibble isF0, otherwise
test their selected bit. Active matching goes4562. Counter,Y negative values
are retained/skipped. Nonnegative values are cleared, and their prior value
determines whether to continue (zero) or stop before4519 (positive). X advances
9 andY1 until4128 (seven records). No record relocation/generalization attempted.

All64 injected cases match original instruction addresses, opcode encodings,
start and completion times, affected RAM and explicit continuations43F1/4426/
44AB/4519/4562/4592. Counter0/01/7F/FF and sticky00/01/02/04/10/80/F0/FF exercise
the bounded paths. IRQ/FIRQ are masked; these are synthetic native experiments,
not natural play or proof of complete coin validation. A separate engine test
checks instruction-boundary suspension, pending state and rejected mid-opcode
suspension. No captured timing drives this execution. Live is unchanged.

Static pinned-source audit: mpu4.cpp maps0C00..03 to IC5 PIA; its portB callback
reads AUX2 OR internal auxiliary state, optionally performs coinlock/hopper work.
mpu4mod4yam.cpp's m4addr inputs include mpu4 without overriding AUX2: coin1..4
are active high10/20/40/80. Reel optics instead belong to IC4 portB0B02.
6821pia.cpp `read` selects DDRB at offset2 unless ControlB bit2 selects portB;
`get_in_b_value` returns `(outB & DDRB) | (pins & ~DDRB)`, with all-output shortcut.
`port_b_r` clears IRQB1/B2 and may restore CB2 strobe. Driver callback side effects
therefore cannot be assumed to happen on every direction-register or all-output
read. Existing synthetic coin matrices explicitly set DDRB=FF and inject outB;
they establish code behaviour, not physical coin levels. The natural19-window
capture still lacks actual PIA state/read value. Zero is not an evidence-backed
replacement. The existing source map/exporter now records13 blob identities,
including6821pia.cpp/mpu4mod4yam.cpp; no user source checkout/settings changed.

Remaining:4592 service and required inline tests, then join43E9 into438C and
complete ordinary4395 return and motor/counter/scheduler work before generated
IRQ timing can replace Live's retained boundaries. Ghidra export access remains
unavailable; no assembler/editor tooling, ROM changes or new documentation system.
Validation:245 full headless groups pass; full/headless solution builds have
zero warnings/errors.1108 curated entries verify; whitespace check passes.
Live/WPF unchanged, prior GUI checks retained. All owned captures exited.

16 October 2026. This timing pass establishes independently checked timer clock
primitives and finds a real obstacle to replacing Live's captured scheduling:
timer3's internal phase cannot be assumed to start low at every latch write.
The existing Live gameplay and playback remain intact. Captured IRQ occupancy,
service timing and callback timestamps have deliberately not been replaced by
an unproven clock/CPU coupling.

## New reference evidence

| Evidence | Kind | Verified scope |
| --- | --- | --- |
| skill-cash/ptm-matrix.json | Synthetic native RAM programs | 96 actual bus status reads across timer1 continuous42 and timer3 single-shot63, both timer3 starting phases |
| skill-cash/ptm-natural-phase.json | Natural cold/default attract | 100 latch-write/opcode-fetch pairs:1 starting low,99 starting high |
| skill-cash/ptm-lifecycle.json | Natural cold/default attract | 643 bus/state observations across20 arms; independent byte-identical repeat |
| skill-cash/ptm-irq-entry.json | Synthetic native CPU programs | 18 ordinary IRQ cases: instruction completion, masking,19-cycle entry and12-byte register frame |
| skill-cash/ptm-skill-cpu.json | Original physical-input Skill Cash campaign | 354 bus/state observations,20 arms and19 IRQ/callback pairs matching the old reference prefix |
| skill-cash/ptm-instruction-boundaries.json | Same campaign, guarded passive instruction observer | 19 selected timer3 windows from13809 opcode samples; native completion/entry timing and32-instruction handler paths |
| skill-cash/ptm-service-timing.json | Further selected paths from that accepted capture | 19 timer3 tails,19 timer1 scans,38 IRQ returns; incomplete final parent/scan excluded |
| skill-cash/ptm-outer-timing.json | Complete selected outer services from that capture | 7820 own instructions,611 ROM contexts,1854 branch destinations and19 referenced child interruptions |

All have verification sidecars with source/run hashes. ROM files, existing MAME
configuration/NVRAM and Ghidra projects are preserved. The synthetic programs
execute from RAM0700, mask IRQ/FIRQ and configure the timer through real CPU
stores; they are not game routines or natural gameplay. Their exact instruction
bytes are retained as program_hex, with the reproducible generator in
tools/Capture-PtmMatrix.ps1. The natural observation injects neither RAM/register
state nor player input and runs before any coin insertion. It does not establish
whole startup correctness or the phase of every canonical Skill Cash arm.

The matrix covers latches0,1,30,40,41,255,3440,65535 for timer1 and each timer3
phase, with four delayed status reads per case. Bus watchpoints record actual
arm/read CPU timestamps, and the loaded status byte is checked independently.
90 samples strictly before/after predicted expiry agree. Six reads are exactly
on the calculated expiry cycle; their observed statuses are retained, but the
clock comparison explicitly excludes their ordering. Neither timer-first nor
CPU-first is fabricated for this unresolved boundary.

The natural saved-item probe observes native710B's store at PC710F and the next
opcode fetch at PC7110, one CPU cycle later. The internal output phase is the
same in each pair. Control1 is42, control3 is63; the newly loaded timer3 latch
is40. The first old latch isFFFF and subsequent old latches are40. Internal
output3 is low in the first pair and high in the following99. This is the PTM's
internal state, not a claim about its externally enabled pin waveform.

## Consequence for the earlier deadline investigation

SKILL-CASH-TIMER-DEADLINE-PASS.md established a consistency calculation, not a
measured phase. Its6103 canonical IRQ offsets fit328 cycles plus18–25 cycles of
latency if starting low. They also fit320 cycles plus26–33 cycles if starting
high. The new natural attract samples disprove a universal starting-low rule;
they do not select a phase for each of those older canonical rows.

SkillCashTimerDeadlineVerification now accepts an explicit starting phase and
labels the result accordingly. The original default remains the starting-low
conditional check for compatibility. Test output now states that assumption;
both candidate ranges are verified. No callback timestamp is moved to force a
match. In particular, replacing every recorded callback with a fixed328-cycle
deadline would erase this distinction.

## Runtime clock primitives

- Mpu4Timer1Clock implements the bounded internal16-bit continuous control42
  clock. The period is latch+1; large updates count expiries arithmetically and
  preserve phase. ROM708E/7091 loads normal latch0D70, giving3441 CPU cycles.
  Live's repeating service-template length now uses this shared period helper
  instead of its duplicated numeric literal. Its acceptance template is retained.
- Mpu4Timer3Pulse retains time, first edge and first IRQ-pending state, with an
  explicit phase per arm. It uses the existing Mpu4Timer3Deadline calculation:
  low starts with an8-cycle edge, followed by latch×8; high takes latch×8.
  Hardware expiry and CPU acknowledgement are separate operations. Advancing
  beyond the first expiry does not claim a known internal output phase: querying
  it fails explicitly. Acknowledgement also invalidates that phase. A later arm
  requires its caller to supply the phase rather than silently resetting it.

These classes are not a complete MC6840, reset sequence, external-clock circuit
or CPU emulator. The lifecycle continuation below recovers selected post-shot
and clock/control changes; canonical CPU acceptance remains open before Live use.
The new pulse model is independently verified but is not yet driving Live IRQs.
No timing mode, application setting or installation was changed.

[MAME's PTM implementation](https://raw.githubusercontent.com/mamedev/mame/master/src/devices/machine/6840ptm.cpp)
was used as a source guide for the mode/clock distinctions. Its current master
is not claimed identical to installed0.281. The installed binary's synthetic bus
experiments and natural saved-item observations are the behavioral checks.

## Preservation and reproduction

maps/ptm-clock-semantics.json extends the existing evidence conventions with exact
ROM707E..710F and FE70..FF13 spans, native listing/export references, C# links,
scope and unresolved boundaries. Timer helpers retain their addresses:
707E alternate0A14 latch;708A normal0D70 latch;7096 reset;70B3 timer3 disable;
70C9 timer2 disable;70D6/70EF timer2/3 arm; FE70 IRQ dispatch. Source bytes are
checked against the existing A6L ROM SHA1 by the curator. This is selected
preservation, not a lossless full-ROM listing. Existing Ghidra exports remain;
no live Ghidra API was available for additional portable annotations/types/xrefs.

Run Capture-PtmMatrix.ps1 in a fresh external directory, then Curate-PtmMatrix.ps1
with that directory and the original RomPath. Run Capture-PtmPhase.ps1 in a
separate fresh directory, then Curate-PtmPhase.ps1. Both capture tools take the
existing MameExecutable and RomDirectory and isolate all writable settings.
The phase Lua observer is also curated as ptm-natural-phase.lua. It filters
actual PC values because ROM/data/checksum/debugger reads can hit the same
address as an opcode. Lua memory callbacks return no replacement data.

Excluded attempts are recorded in ptm-natural-phase-verification.json: unsupported
debugger Lua commands; inconclusive full observer campaigns; a debugger-only
peripheral-write/single-step experiment; and a watchpoint that cleared a temporary
stop. None supplies accepted timing evidence. The final matrix uses real CPU
bus programs and permanent stop breakpoints. The existing natural gameplay
capture tool was restored unchanged.

The complete headless suite has194 groups. New coverage includes matrix status
comparisons with explicit ties, natural phase observation, both canonical latency
hypotheses, coarse/fine timer1 updates, timer3 state/acknowledgement and refusal
to expose an invented post-shot phase. All eight WPF modes retain passing results.
Both solution builds have zero warnings/errors.

## Timer3 lifecycle continuation

The16 October continuation adds643 natural read-only observations spanning20
cold-attract arms. A second isolated run produces a byte-identical CSV (hashes
and source locations in skill-cash/ptm-lifecycle-verification.json). Neither run
injects state or physical inputs. They are not canonical Skill Cash captures.

Trace-backed findings: internal output continues toggling after the first
one-shot interrupt; single_fired remains set. Native70B3's control63→00 write
preserves internal output while freezing the counter. Subsequent70EF control00→63
and latch writes preserve that phase and single_fired. All observed disables
retain high output; the first frozen raw counter is202, followed by207/201/51
in the next selected windows. This explains how a later arm can start high;
the external pin output is a separate concept.

Mpu4Timer3PhaseClock reproduces every observed output, raw counter, enabled,
single_fired, latch, control and timer3 status-bit value. Status-read followed by
counter-MSB read clears the channel flag; a later falling transition can assert
it again. Timer3 pending is separated from interrupt enable and shared IRQ
acceptance. Other channels' flags/IRQ contributions are not modelled here.

The source-guided model uses MAME's integer attoseconds. At1.72MHz an internal
tick is floor(1e18/1720000); reload duration multiplies that by8. Clock-source
reenabling instead uses floor(1e18/215000). Disabling installs divisor1 before
converting remaining time back to a frozen count. Flooring can therefore produce
202 where rounded CPU-cycle arithmetic suggests203. The exact timestamps in the
capture validate that distinction without an arbitrary one-cycle adjustment.
This preserves the selected installed-reference behaviour, not a silicon claim.

The observer records writes before access and reads after access (read data is
the value returned). Selected following opcode fetches confirm completed stores.
It keeps decimal seconds/attoseconds as strings, avoiding JSON floating-point
loss. Raw counter is the device's saved reload/frozen field, not a continuously
decremented register. Reproduction: Capture-PtmLifecycle.ps1 with the same three
arguments as Capture-PtmPhase.ps1, twice in fresh external directories; then
Curate-PtmLifecycle.ps1 -RunDirectory <run> -RepeatRunDirectory <other-run>.
The committed observer and tools retain no ROM binary or bulky trace.

The lifecycle model accepts only control00/63, positive latches, released reset,
low gate and no external clock edges. Other controls and zero-latch lifecycle
fail explicitly. Coarse/fine updates and read-to-clear ordering have additional
synthetic regression coverage. The earlier pulse model retains its narrower
contract and explicit first-phase input. Neither new model drives Live IRQs yet.
Existing ROM spans, native helper addresses and calling/side-effect records in
maps/ptm-clock-semantics.json and native/timer-native.txt remain the preservation
baseline; the map now links the lifecycle model and evidence. No new native
routine or VM body was recovered, and no Ghidra project was changed.

Continuation validation:196 headless groups pass, including the full existing
gameplay/reference suite and two lifecycle groups. Headless and full solutions
build with zero warnings/errors. All eight WPF smoke modes pass again, including
playback and the existing live input/pause/paid-game paths. GUI result location
is recorded in CURRENT-HANDOFF.md.

## IRQ entry and canonical Skill Cash continuation

The matching-release source is now pinned to mame0281 commit
2843a3deb81cf93735244044894196ccfbea4d20. maps/mame-timing-source.json records
nine exact Git blob identities and permanent source links for the timer,6809,
MPU4 wiring, scheduler, time representation and input-line delivery. Reproduce
with Export-MameTimingSource.ps1 -MameRepository C:/projects/GitRepos/mame.
The checkout's old branch and local edits remain intact; versioned reads use
git show mame0281:<path>. This is release-matched source, not proof of the
installed executable's complete build provenance.

Source-backed and independently trace-checked: an ordinary MC6809 IRQ checks
the delivered level and I mask at instruction completion. It then saves the
full12-byte frame, sets E/I, fetches the FFF8 vector and reaches FE70 after19
cycles. F is preserved. E is set in the saved CC; I is set in the handler CC.
Frame order from new S is CC,A,B,DP,X,Y,U,PC with big-endian words. The bounded
M6809IrqEntry helper computes this transition from an explicitly supplied CPU
boundary/register snapshot. It does not execute instructions or model CWAI,
SYNC, FIRQ/NMI, source delivery or ROM handler work. It is not used by Live yet.

Capture-PtmIrqEntry.ps1 runs18 isolated RAM programs spanning timer latches
1/40/255, two instruction loops and0/30/180 masked NOPs. Actual CPU execution
accepts IRQ and stops before original FE70 handler execution. All18 entry
costs and full frames agree. Curate-PtmIrqEntry.ps1 preserves synthetic program
bytes, bus timestamps, last instruction, frame and source hashes. These are
synthetic CPU/register experiments, not natural gameplay or new ROM routines.

The bus observer reveals a measurement qualification: the release store's
debugger watchpoint totalcycles coordinate is five cycles earlier than its
effective device access. The original synthetic timer matrix compares matched
five-cycle store/read instructions, so that common offset cancels in its
elapsed comparisons. It must not be transferred uncorrected into IRQ timing.

The natural campaign observer attaches after2040 simulated seconds, before
the actual C721 entry. All354 selected timer states match the phase clock from
one explicitly recorded stopped-channel snapshot; subsequent arms retain state.
All20 latch writes are high-phase, with gate3 and external clock3 low throughout
the observed window. All19 handler/callback pairs exactly match the original
timer-deadlines.json prefix. The20th arm deliberately ends the selected window
before its IRQ. No phase claim extends automatically to the other6083 arms.

For these20 stores, the original debugger coordinate precedes the effective
STY bus write by seven cycles. Correcting that coordinate and using the observed
high phase gives19–26 cycles from calculated assertion to handler entry, rather
than the old conditional26–33. Subtracting the independently verified19-cycle
entry leaves0–7 cycles for instruction completion/input delivery. Their precise
division is not yet measured. Handler-to-lamp-callback entry is128 cycles for
all19 pairs. It remains an observation of the selected native path, not a
universal service duration. Source assertion is calculated from validated timer
mechanics; the asynchronous transition is not directly sampled at its instant.

Reproduce with Capture-SkillCash.ps1 -FullFeature -PtmCpuTiming and its usual
MameExecutable/RomDirectory/fresh RunDirectory arguments, then
Curate-SkillCashPtmCpu.ps1 -RunDirectory <run>. The observer neither injects
machine state nor changes the original physical-input script. Installing RAM
dispatch taps at startup prevented progression in an earlier attempt; that
owned process was stopped and its hashes/reason retained as excluded evidence.
Deferring installation produces the exact existing prefix. The cause of the
startup observer problem is unresolved and supplies no timing evidence.

The existing ROM span map also preserves FFF8..FFF9=FE70 and links both new
evidence sets and the pinned source. No game helper semantics changed and no
additional Ghidra export was available. Tests cover the full observed state
sequence, old/new timestamp correspondence, IRQ frames, masks, preserved F,
stack wrap and input levels. Live timing adapters remain explicit.
Validation for this continuation:199 headless groups and all eight WPF smoke
modes pass. Both headless/full solution builds have zero warnings/errors.

## Native instruction boundary continuation

The next16 October batch records13809 opcode samples plus state-change
observations around the same20 arms. The original354 state rows remain identical
field-for-field, including timestamps. Curated windows retain the instruction
already executing when each of19 timer3 expiries occurs, the delivered CPU IRQ
observation, and every instruction from FE70 to callback48FD. The complete raw
instruction stream stays external. An earlier observer reentered the narrow
taps while inspecting instruction bytes, duplicating events and ending its
window early. Its source/data hashes and exclusion reason are retained. A
shared reentrancy guard fixes observation bookkeeping; no game behaviour changed.

M6809InstructionTiming is a bounded opcode length/cycle decoder, not a CPU
interpreter, assembler or recovered gameplay implementation. Its rules come
from pinned MAME6809 dispatch, addressing and operation paths. It covers the
selected immediate/direct/extended/indexed instructions, short branches and
register masks; other opcodes and unsupported indexed modes fail explicitly.
Input bytes and branch/register execution remain the caller's responsibility.

All19 timer assertions lie within the final native instruction, including the
observed instruction-end cases. These instructions are RTS, JSR extended,
STA/ANDA with16-bit indexed displacement, LDB postincrement and ADCA immediate.
Their source-derived durations plus19-cycle IRQ entry predict every observed
FE70 timestamp exactly. The previous0–7-cycle remainder is therefore explained
by completing the instruction in this window; no extra latency is selected from
the capture. Every last instruction starts with I clear, and these instruction
types do not alter I. Delivered CPU IRQ=1 with timer3 pending is first sampled
at calculated assertion or the following CPU cycle. That is an observation
bound, not a directly sampled input-line transition instant or a universal
one-cycle delivery rule. The six earlier synthetic status-read ties stay open.

The same source-derived decoder checks608 individual native durations across
19 identical32-instruction FE70→48FD paths. Their sum is128 cycles per path,
so128 is now explained by native work rather than inserted as an arbitrary
delay. This includes PTM priority/status checks,70B3 control disable and the
indirect callback call. It does not yet include callback execution, IRQ return,
RTI, timer1 output-scan work or nested service paths. The wider Live scheduler
still needs native instruction boundaries for the executing VM/helpers before
this local proof can replace captured occupancy/callback templates.

Reproduce using Capture-SkillCash.ps1 -FullFeature -PtmInstructionTiming with
the existing executable/ROM directory and a fresh external RunDirectory. The
switch implies PtmCpuTiming and adds no debugger startup command. Instruction
taps attach after2040 simulated seconds and are removed on the first frame
after the20-arm window. Curate-PtmInstructionTiming.ps1 takes RunDirectory,
RomPath and optional ExcludedRunDirectory. It rejects any change to the original
354-row state prefix and byte-checks all selected ROM contexts. context_hex is
five observed bytes, potentially including following code/data, not an asserted
instruction length or lossless routine listing. The runtime decoder supplies
the selected instruction lengths. Existing semantic maps/source identities
link the encodings, C# implementation and evidence; no new Ghidra exports were
available and no project was modified. The source checkpoint now has11 blobs,
including the CPU cycle-read definitions and observer tap API.

Capture maintenance also corrects new -CpuInterrupts resume reads to S+0x0A.
The debugger treats bare10 as hexadecimal, so the old raw resume field sampled
S+16 rather than the saved PC. Existing cpu-interrupts.json retains its timing
intervals and minimum costs unchanged: it does not store that field. Its old
raw field comparison must not be claimed as saved-PC verification. The newer
18-case full-frame matrix independently checks the actual saved PC and frame.
Original captures remain preserved.
Validation:201 headless groups and all eight WPF smoke modes pass. Full/headless
solution builds have zero warnings/errors.1083 curated manifest entries verify.

## Callback return and timer1 service continuation

The next batch reuses the accepted13809-opcode capture; no new MAME campaign
or original-workspace changes were needed. Curate-PtmServiceTiming.ps1 verifies
the accepted instruction/state hashes and ROM SHA1 before extracting selected
tails, scans and IRQ nesting. It byte-checks every five-byte ROM context. This
extends the existing evidence conventions and source map; the contexts remain
observations, not a lossless disassembly. The final20th timer1 IRQ and its scan
are truncated by the observer window and explicitly excluded.

All19 timer3 callbacks execute78 cycles from48FD to caller FEF2. The older
73-cycle callback event marks the start of final RTS at4916, not its completed
return. The nested helper RTS at4922 and final RTS each consume five cycles.
The selected FEF2→FF13 epilogue takes11 cycles, and full-frame RTI takes15.
Thus each selected timer3 interrupt occupies251 cycles from CPU acceptance
through resumed execution:19 entry+217 handler+15 RTI. The previous captured
entry→RTI interval intentionally omitted stacking and RTI; its coordinates
remain preserved. Do not silently relabel those events as complete CPU service.

The source-derived timing decoder now checks342 individual instructions across
the19 callback/exit tails. RTI requires the saved CC E bit explicitly; current
handler CC is not a substitute. Ordinary IRQ sets saved E, the selected handler
paths leave that frame flag intact, and all38 observed full returns take15 cycles
and resume at the saved PC sampled independently on entry. The short6-cycle
RTI check is a synthetic source-derived case, not a captured FIRQ path.

The19 complete timer1 scans contain1988 source-checked instruction durations
from28FE through completed RTS at29BA. Durations vary425–467 cycles according
to the actual paths, including column selection, display bit-loop work and
timer3 arming. They exclude the caller's JSR. The old scan-exit event at29BA
is before its five-cycle RTS. Prefix10 comparisons/loads/stores and indexed
TST/AND/load forms retain their native lengths and timing. Long conditional
timing requires an explicit outcome; the curator derives observed BNE outcomes
from captured CC and checks the target. The natural long BNEs here are not
taken; the taken6-cycle long-branch test is synthetic and source-derived.

The IRQ tree has19 completed outer timer1 services and19 timer3 children, plus
one incomplete outer service. Every selected timer3 interrupt occurs inside a
timer1 background-service path after the scan, not in otherwise idle main-VM
execution. The previously checked final-instruction durations remain valid,
but their surrounding context matters when accounting for occupancy. Child
acceptance→resume is251 cycles and lies inside its parent. Parent measured
acceptance→resume wall spans vary1627–3409 cycles and already include the child;
their remaining native background work has not been fully timing-decoded.
Do not add child time again to the measured outer span or infer full outer
timing recovery from the scan checks alone. All38 saved-PC/RTI resumes match.

Reproduce with Curate-PtmServiceTiming.ps1 -RunDirectory <accepted-run>
-RomPath <original-a6ls.p1>. The accepted source run is recorded in the existing
ptm-instruction-boundaries-verification.json; the curator rejects a different
unverified stream. New service verification metadata links its hashes and the
pinned source. The map includes RTI/PULL_REGISTERS/LBRANCH/TST8 references and
the C# decoder. No new Ghidra annotation export was available; existing projects
and source ROM remain unchanged. Live still uses its explicit captured adapter.
Validation:205 headless groups/all eight WPF modes pass; both solution builds
have zero warnings/errors.1085 curated manifest entries verify.

## Complete selected outer service continuation

The next batch accounts for all native work in the19 completed outer timer1
services. It reuses the accepted capture and the verified timer3 prefixes/tails;
no additional MAME campaign, installation or configuration change was needed.
Curate-PtmOuterTiming.ps1 requires the accepted instruction/state hashes and
original ROM SHA1, byte-checks611 unique five-byte contexts, and stores7820
outer-owned instruction steps. A compact catalog and typed step arrays retain
captured CC, instruction/next-PC coordinates and completion boundaries without
duplicating the nested timer3 instruction streams. Catalog bytes can include
following code/data; the timing decoder supplies actual instruction lengths.
This is selected preservation, not a lossless listing or new function count.

Source-backed timing rules now cover the observed native input, output, sound,
stack-check and task-dispatch paths. This adds selected arithmetic/load/store,
transfer, multiply, prefix10 and CMPS prefix11 encodings. Unsupported encodings
still fail. EvaluateBranch reads explicitly supplied C/V/Z/N flags; it neither
generates those flags nor executes the native instruction's state effects.
All1854 branch destinations agree with the recorded flags and instruction
encodings:1708 short branches,127 long conditionals and19 LBRA instructions.
Source predicates and addressing/operation rules remain pinned in the existing
MAME source map. No native semantic bug or game behaviour was changed.

All19 outer acceptance→resumed-opcode spans match exactly from19-cycle entry,
1357–3139 cycles of their own native work and one source-decoded251-cycle timer3
child per parent. Totals vary1627–3409 cycles. The child is counted once, at the
instruction boundary where it interrupts its parent. For the preceding parent
instruction, completion is the child's acceptance boundary, not the next opcode
after the child's19-cycle entry. The resumed destination comes from the child's
independently checked saved PC. Both IRQ entry and RTI are included. No captured
busy interval or fitted elapsed residual is added to make the sums match.

The selected service timing is now fully accounted for, but service starts,
instruction paths and register/flag snapshots are still observations supplied
to the checks. This does not generate new native paths from game state or prove
an autonomous Live IRQ schedule. The20th outer service remains incomplete and
excluded. Other machine states, later arms, timer2/PIA interrupt paths and
different nesting patterns are outside this proof. The C# runtime remains a
recovered VM/translated-helper engine with a bounded timing decoder, not a
general6809 instruction interpreter or assembly/reassembly toolchain.

Reproduce with Curate-PtmOuterTiming.ps1 -RunDirectory <accepted-run> -RomPath
<original-a6ls.p1>. Existing source/ROM maps link its compact step schema,
instruction contexts, C# timing/branch implementation and verification. Useful
discoveries remain in these exports and the report; no live Ghidra export API
was available and existing projects were preserved. Live's Cost function still
uses explicit captured site/token costs and throws for missing coverage; its
IRQ occupancy/service/callback adapters remain unchanged.
Validation:207 headless groups/all eight WPF modes pass. Full/headless builds
have zero warnings/errors;1087 curated manifest entries verify.

## Next timing milestone

Keep this ahead of broadening gameplay outcomes: the selected natural
post-shot/disable/rearm lifecycle and first20 canonical arms are now verified.
Instruction completion, full selected timer1 service and nested timer3 costs
now agree. Next supply source-derived native boundaries from the common VM
dispatch and selected translated Live helper paths, checking those against the
existing input/output/accounting regressions before replacing captured pacing.
Do not turn the observed native instruction paths into a disguised Live replay.
Extend contention and nesting coverage beyond these arms as integration needs it. Retain
the selected instruction-boundary contract when adding timing to translated
helpers; do not replace it with an unexplained fixed remainder.
Replace the callback template only when those stages can be connected without
choosing an arbitrary latency. After that, derive timer1/IRQ service scheduling
and progressively replace per-word captured execution costs. Captures remain
regression references throughout; the complete playable machine remains the goal.
## VM primitive integration continuation — 16 October 2026

Live now derives CPU work for four straight-line A6L words from their native
encodings using `Mpu4VmPrimitiveTiming`, rather than looking up a captured
minimum. The boundary is NEXT at RAM00FC through the following NEXT at00FC;
IRQ work is excluded. RAM NEXT is the observed `AEA1 6E91`: LDX ,Y++ followed
by JMP [,X++]. These cost8 and9 cycles. This RAM observation is not claimed
to be ROM source or a lossless dispatch reconstruction.

| Token/header | Native body bytes and locations | Total CPU cycles | Existing translated effect |
| --- | --- | --- | --- |
|78B5→78B7|78B7 `CC0000`,78BA `3606`,78BC `0EFC`|30|Push0000; U−2|
|795B→795D|795D `ECA1`,795F `3606`,7961 `0EFC`|35|Read big-endian inline word, Y+2; U−2|
|7963→7965|7965 `4F`,7966 `E6A0`,7968 `3606`,796A `0EFC`|35|Read unsigned inline byte, Y+1; U−2|
|792F→7931|7931 `3520`,7933 `0EFC`|27|Restore caller Y from S; S+2|

These totals include common NEXT. PSHU A/B costs7; PULS Y costs7; direct JMP
costs3. The timing decoder adds only PSHU, indexed LDD and direct JMP needed
for these paths, using the pinned MAME sources. It does not execute a6809.
`RecoveredScript.cs` still implements the actual VM effects; the Live session
uses the timing plan by token. No per-site minimum overrides these four words.
Unsupported tokens continue through the existing explicitly captured adapter.

`Curate-VmPrimitiveTiming.ps1` reproducibly checks original ROM SHA1, token
headers and native five-byte contexts, reusing the accepted passive instruction
capture. `skill-cash/vm-primitive-timing.json` preserves54 complete uninterrupted
paths:5 zero,1 word literal,4 byte literals and44 returns. Every individual
instruction duration and whole boundary matches. Partial initial/final NEXT
windows are excluded; there are no interrupted selected complete paths here.
ROM contexts are checked bytes, not claimed instruction lengths; decoded plan
lengths are separately verified. No new MAME campaign or Ghidra access was needed;
the previously documented Ghidra export gap remains.

This is a small causal timing integration, not replacement of the Live IRQ
scheduler. The selected totals equal previous validated minima, so pacing stays
the same. Live still applies recorded IRQ occupancy and callback/scan scheduling;
native helper paths and intra-word interrupt delivery remain unresolved. Next
derive a state-dependent word/helper boundary, then connect timer assertions to
generated instruction boundaries without using recorded paths as execution.

Initial candidate observation (superseded by the complete boundary check below): the accepted opcode stream contains26 samples each
at RAM00F8 (`3420`, PSHS Y) and00FA (`3184`, LEAY ,X), both with five-byte
contexts `34203184AE`/`3184AEA16E`. Source timing suggests7+4 cycles for this
threaded-call gateway, plus17 for NEXT, consistent with the existing28-cycle
adapter. This pair is not yet curated as a complete boundary proof or integrated;
retain the existing ROM-header membership checks and validate complete paths
before broadening the source-derived model. RAM bytes are observations, not ROM.

Validation:208 headless groups and all eight WPF smoke modes pass. Both solution
builds are clean. The primitive cost cache was rebuilt and targeted-tested after
the full suite; it changes allocation overhead only. No installs/configuration
changes, commits or pushes. Curated manifest contains1088 checked entries.

## Threaded-call gateway continuation — short batch, 16 October 2026

`Curate-VmPrimitiveTiming.ps1` now preserves26 complete uninterrupted gateway
paths in `skill-cash/vm-call-gateway-timing.json`, reusing the accepted capture
hash. Each observed instruction and both NEXT boundaries match the generated
plan:00FC `AEA1` costs8,00FE `6E91` costs9,00F8 `3420` costs7,00FA `3184`
costs4. Total28 CPU cycles, excluding interrupts and the called body. No selected
complete path was interrupted; partial initial/final boundaries are excluded.
All bytes here are observed RAM bytes, not a lossless ROM export.

NEXT advances caller Y by2 and loads/increments X through the token's indirect
header;00F8 PSHS Y saves that return cursor (S−2), then00FA LEAY ,X installs
the body cursor at token+2. The next NEXT begins the body. Existing physical VM
call frames implement these effects; timing code does not emulate instructions.
The candidate pointer/header membership remains independently ROM-byte checked
in `maps/dice-request-data.json` and its existing exporter/tests. The passive
opcode stream alone does not identify which token called the RAM gateway.

Live uses `Mpu4VmPrimitiveTiming.ThreadedCallCycles` before per-site/token timing
for those existing verified headers, requiring Body and no PushAddress. Other
entry mechanisms are not generalized. This removes the old timing fallback to
the captured9B3E token. The called body's instructions still execute separately;
the28-cycle cost never stands in for its logic or duration. No IRQ adapter is
replaced. Remaining helper/state-dependent paths and intra-word IRQ boundaries
are still the next work.

Short-batch validation:209 headless groups, both solution builds and the live
WPF smoke test pass. Other seven GUI modes were not repeated.1089 manifest
entries checked. No new MAME run, installation, configuration change, commit or
push; original ROMs/settings/Ghidra and MAME working files remain untouched.

## Conditional VM timing continuation — 16 October 2026

`Mpu4VmConditionalTiming` now selects native timing paths from the current VM
stack before execution, without consuming or changing cells. Live uses these
costs ahead of captured site/token minima. This is CPU work for the translated
word, not instruction-level execution or a replacement of captured IRQ occupancy.
The old minimum could charge the cheaper path even when actual operands require
more instructions. Unlike the preceding constant-cost batches, this intentionally
changes pacing where a selected path differs from that old adapter.

| Token/header | Recovered operation and pre-state predicate | Cycles predicate false / true, including NEXT |
| --- | --- | --- |
|7982→7984,798C→7984|Forward byte branch, top==0000|36 /45|
|79A6→79A8|Backward byte branch, top==0000|36 /45|
|79B9→79BB|Absolute word branch, top==0000|36 /37|
|7A6F→7A71|Equality, top==second|44 /47|
|7ADC→7ADE|Signed minimum, (short)top<(short)second|37 /42|
|7AE7→7AE9|Signed maximum, (short)top<=(short)second|42 /37|

All paths share observed RAM NEXT `AEA1 6E91` (17 cycles). Native instruction
encodings, exact lengths, addresses and selected paths are in the runtime plan;
the fixtures preserve original-ROM-checked five-byte contexts and token-header
pointers. Five-byte contexts are not claimed instruction lengths or a lossless
listing. The decoder adds only PULU and indexed SUBD needed here, with the pinned
MAME timing source linked in `maps/mame-timing-source.json`.

Native layout/calling facts: U addresses the top big-endian cell; every selected
word consumes one net cell (U+2). Binary words overwrite the surviving second
cell, preserving the next cell; equality writesFFFF or0000. Signed comparisons
use N xor V, retaining overflow behavior. No S frame is created. Y points to the
first operand after NEXT. For a zero condition, forward byte uses unsigned
operand and Y+operand; backward byte builds `FFxx` and adds that signed word
(-256..-1), including byte00 as-256. On a nonzero condition both skip one byte.
Absolute zero branch loads big-endian word atY; nonzero skips two bytes. Binary
words leave Y unchanged. Shared tails are7A3F/7A42/7A44 (false),7A4C/7A4F/7A51
(true) and7AF0/7AF2 (store result). Short native branch destinations, aliases,
pointer headers and common tails remain explicit for future symbolic rebuilding.
Names/pseudocode are recovered descriptions, not original author source.

### Evidence and reproduction

`Capture-VmConditionalTiming.ps1` executes the actual ROM bodies in installed
MAME with injected CPU/RAM state, masking IRQ/FIRQ and stopping before NEXT.
Fresh isolated cfg/NVRAM directories and `-noreadconfig` preserve original settings.
376 cases cover both initial CC50/5F, all seven token entries and14 paths;
branch operands00/01/7F/80/FF, zero/nonzero/high-bit cells, and all pairs from
0000/0001/7FFF/8000/8001/FFFF for equality/min/max. These are synthetic native
experiments, not whole-machine or reached gameplay paths.

`Curate-VmConditionalTiming.ps1` takes RunDirectory, NaturalRunDirectory, RomPath
and MameExecutable. It checks the original ROM SHA1, actual headers/native bytes,
accepted natural instruction-stream hash and complete ordered synthetic cases.
The existing passive Skill Cash capture provides12 complete uninterrupted paths
(3 forward branches,4 backward branches,5 min operations). Two forward branch
paths containing IRQ work are explicitly excluded, as are partial outer bounds.
Natural operands are not captured: those paths are checked from observed native
CC and branch destinations; operand-selected paths are independently checked in
the synthetic matrix. Do not describe all14 alternatives as natural evidence.
Natural token fields name a representative token for each native entry; the
opcode stream alone does not distinguish aliases7982/798C.

Verification checks every native instruction duration and conditional destination,
whole boundary cost, resulting U/Y/S and surviving cells. The same376 operands
also execute the translated VM operations using synthetic diagnostic listings;
result selection and stack cells agree with native execution. The listings use
test marker targets for branch direction, while actual native operand arithmetic
is separately checked at Y. Timing queries preserve their input stack and reject
underflow. Unsupported tokens remain outside this timing model.

The first attempt logged breakpoint actions only. MAME `go` skips a breakpoint
at the current PC, leaving the initial instruction unobserved. The corrected
capture explicitly records that initial boundary before go. The old attempt is
excluded with path/hash/reason in `vm-conditional-verification.json`; both raw
runs remain external. No measured duration is fitted to hide that omission.

Byte-preservation links: the synthetic/natural fixtures, verification hashes,
capture/curation scripts, runtime paths and existing ScriptExecutor implementation
are linked in the timing source map. No unrelated ROM routines were recovered,
no assembler was introduced, and the previous Ghidra export access gap remains.
Existing ROMs, Ghidra projects and MAME working files/settings are preserved.

Remaining boundary: Live still applies captured IRQ intervals and scan/callback
times, and translated word effects remain atomic. Paths now expose native
instruction addresses/costs, but interrupt delivery within a word has not been
coupled to them. Next choose one such boundary for a causal comparison rather
than treating recorded paths as Live execution or claiming full clock recovery.

Validation:212 headless verification groups pass, including all existing live
input, pause/resume, repeated paid-game and MAME-backed replay comparisons.
All eight WPF smoke modes pass and exit cleanly. Full/headless builds have zero
warnings/errors. No test expectations were rebaselined for changed pacing.

## Live calibrated-delay scheduling replacement — 16 October 2026

Live no longer obtains the Start-tone wait duration from `nudge-tone.json`.
`Mpu4CalibratedDelay.StartToneWaitCycles` calculates34276 CPU cycles from native
5A05/7159/7164/718A instructions and loop counts. Its deadline projects that work
through full ordinary-IRQ envelopes. Captured wait duration is verification
evidence, not execution input. IRQ starts, queue setup/cancel and other VM pacing
remain captured. This replaces one scheduling dependency, not the whole PTM/CPU
scheduler; native words are not instruction-stepped.

7159 calls718A's enabled gate, preserves A/B and repeats7164.7164 preserves B,
loads28 outer passes and54 inner iterations, decrements A/B with short BNEs,
then restores B. Single-pass cost17096; enabled7159 costs47+17108*N, with N=B
except B00 wraps to256.5A05 adds13 (LDB1,S and JSR7159); fixed5A14 supplies B02.
719B bit80 disabled pacing remains unsupported in Live. Its bytes are statically
preserved, not claimed dynamically verified.

`Capture-CalibratedDelay.ps1` executes20 isolated original-ROM calls with
B00/01/02/03/FF, A00/FF and CC50/5F. IRQ/FIRQ are masked; gate remains00; only
RAM/register state is injected. All2068 inner passes, whole call durations and
preserved A/B/X/Y/U/S match. Original settings are protected by fresh directories
and `-noreadconfig`; no ROM bytes are patched. An initial20-simulated-second limit
truncated the last case despite exit0; the curator rejected it. The accepted run
allows60 simulated seconds. The excluded run/hash/reason remains in provenance.

`Curate-CalibratedDelay.ps1` validates the existing natural tone log SHA256 and
reconciles24 balanced outer IRQs across its phases, including23 during the wait.
Recorded FE70→RTI-start spans include nested work already. Adding verified19-cycle
ordinary entry and15-cycle full RTI once per outer span gives CPU phase budgets
381/34276/360. The old35058 wait included23*34=782 cycles outside handler bodies.
Source34276 plus full IRQ spans reproduces natural5A05→5A0A exactly. The old log's
incorrect saved-PC field is not used. Exact ROM ranges/bytes and raw provenance
are retained in `skill-cash/calibrated-delay-timing.json`.

`CapturedInterruptOccupancy.FromOrdinaryIrqHandlers` builds full envelopes;
`CompletionAfterCpuWork` projects CPU work through them without consuming the
service cursor. It handles an IRQ already in progress and periodic wrap; a fully
busy period rejects positive work. Live uses this projection only during the
calibrated wait, without charging handler busy time twice. Other phases retain
the existing body-only occupancy adapter (cancel budget394 remains explicit).
`TimedToneDelay` exposes its pending start/work/deadline. The live paid-play test
verifies Pause/Resume, parameter31 one cycle before the deadline and parameter00
at it, then continues gameplay/accounting. Same-cycle hardware delivery is not
generalized from this CPU-work calculation.

A trial global full-envelope change reached9E87/7FB1 without pacing coverage and
changed a GUI paid outcome; that global switch is not retained. The final narrower
wait also exposed this already translated constant family under GUI input timing.
Original handlers7946 (CLRA,LDB,X,PSHU D,JMPFC) and794F
(LDD,X,PSHU D,JMPFC) cost33/32 including NEXT.20 isolated native handler calls with
RAM operands verify costs, unsigned byte extension, word endianness, U−2,
unchanged Y/S and the underlying cell. The curator ROM-checks175 header/operand
pairs referenced1048 times in existing VM listings and exports membership/raw
encodings to `maps/vm-literal-timing.json`. Live requires matching token/operation/
value; unknown words still fail. These synthetic tests introduce no gameplay
semantics or claim a newly reached natural campaign.

Capture/curation scripts, ROM ranges, native/VM effects, implementations and
verification are linked through the existing timing-source map. No assembler or
unrelated recovery is added; the Ghidra export gap remains. Original ROMs/settings,
Ghidra and MAME working files are preserved. Next target remains actual timer
assertion→CPU acceptance→scan/callback scheduling, not another captured wait fit.

Validation:217 headless groups and all eight WPF smoke modes pass. Both solution
builds have zero warnings/errors. Test expectations were not rebaselined.

## Generated timer-3 callback output events — 16 October 2026

Live now retains only the captured48FD entry boundary, not the recorded return
timestamp, for the lamp callback. `Mpu4LampCallbackExecution` generates native
port writes and completion incrementally. Service timestamps for scan and IRQ
entry/acceptance remain explicit adapters; no causal PTM assertion claim is made.
The existing verified playback/scrubber is unchanged.

| Event | Effective CPU cycles after48FD entry |
| --- | ---: |
|490D STA0A00, first masked lamp bank|37|
|4910 STB0A02, second masked lamp bank|42|
|491F CLR0B00, only if byte at00AB+column is nonzero|75|
|Completed4916 RTS, no digit blank|78|
|Completed4916 RTS, digit blank|85|

Former Live behavior applied all callback effects at the recorded4916 RTS-start
marker (+73 for all6103 reference callbacks). This missed the separate, earlier
lamp writes and applied optional blanking at the wrong point. The native plan
now decodes the original48FD/4917 instructions; it uses current column/masks and
outputs, with the recovered zero/nonzero blank predicate. PortB00 is the scanned
digit output, not the serial alpha module. No hardware duration is fitted.

`Capture-LampCallbackTiming.ps1` runs18 isolated original-ROM callbacks in MAME:
columns0/3/7, blank0/1 and three output pairs with0F/F0 masks. CPU IRQ/FIRQ are
masked; transient PIA DDR/latch and RAM/register state are injected. Original
ROM files and MAME configuration are untouched; fresh cfg/NVRAM directories and
`-noreadconfig` isolate the run. A passive Lua write tap records45 actual output
bus writes, with exact decimal time. All match the generated native instruction
completion cycles, values and order; all18 whole native paths match. The fixture
preserves five-byte ROM-checked contexts, explicit instruction boundaries and
source hashes. Context width is not claimed instruction length or a lossless
listing. The observer is exported as `lamp-callback-writes.lua`.

`Curate-LampCallbackTiming.ps1` requires RunDirectory, RomPath and MameExecutable;
it checks the original ROM SHA1, complete cases/return boundaries and that all45
bus events belong to a case. `lamp-callback-timing.json` retains the raw run/hash
references and original installed executable hash. Raw logs stay external.
The19 existing natural callback windows independently match the native path
and78-cycle completion. Natural per-instruction completions plus the synthetic
bus observations support the write offsets; these are distinct evidence scopes.
All6103 recorded callback entry→RTS-start gaps are73, consistent with the selected
nonblank, uninterrupted path; digit-blank alternatives are synthetic evidence.

Live starts the callback from event6 and ignores event7 as a scheduling boundary.
Timer3 dispatch flags are applied at that retained entry adapter. The VM remains
blocked by existing IRQ occupancy; generated write events update ports/latch
history individually. Completion increments the callback count after the final
RTS. Pause suspends the actual callback cursor, memory, VM and virtual time, even
between the bank writes five cycles apart. Coarse and single-cycle updates agree.
Changed column/masks/other output writers or a scan/VM preemption fail explicitly:
register-level native preemption inside this path is not implemented. The model
does not execute CPU registers/frames or infer physical lamp brightness.

A synthetic fault test shifts6102 recorded return timestamps by100 cycles while
preserving every other absolute event time. Live produces identical callback
writes, VM count and memory. A separate live test pauses after the first write,
resumes through the second and reaches generated completion. These verify the
removed return-time dependency and retained execution state, not a fabricated
match to unresolved hardware scheduling.

Byte/code links: native48FD/4917 exports, runtime path/length decoder, Live session,
bus observer, capture/curation tools and both evidence fixtures are referenced in
the existing timing-source map. No assembler, unrelated recovery or configuration
changes were introduced; the documented Ghidra export access gap remains.
Next derive callback entry from timer arm/phase and CPU acceptance boundaries.
Validation:222 headless groups, all eight WPF modes and both solution builds pass.
No expectations were rebaselined.1096 curated entries verify. All owned processes
exited; no installs/configuration changes, commits or pushes occurred.

## Generated timer-3 IRQ dispatch and callback entry — 16 October 2026

Live now retains FE70 handler entry from the independent timer capture, rather
than48FD callback entry from shared event6. The original latch coordinate plus
its measured IRQ offset reconstructs that recorded FE70 timestamp exactly. This
does not use a calculated timer assertion, add seven cycles to the old coordinate,
or claim generated CPU acceptance. The hardware boundary has moved earlier;
it has not been eliminated.

`Mpu4Timer3DispatchExecution` derives the selected FE70→48FD path from32 original
native instructions. At128 CPU cycles it starts the existing incremental lamp
callback, which then generates its port writes/completion. No recorded callback
entry, return or callback-service-duration field is used by Live scheduling.
The software timer3 control effects now occur during native dispatch rather
than atomically at callback entry:

| Native store | Cycles after FE70 entry | Effect |
| --- | ---: | --- |
|70BB STB0901|85|PTM control-selector write, exposed as hardware event|
|70BE STB003F|89|Store control shadow with bit0 cleared|
|70C2 STB0900|96|PTM stop-control write00, exposed as hardware event|
|70C5 STB0040|100|Clear timer3 software control shadow|
|FEF0 JSR,X completed|128|Enter48FD callback|

The selected contract is DP0, bank flag00F1=0, nonnegative IC4 control at0B03,
timer2 enable bit40 clear in003F, timer3 control63 and callback48FD. Prioritized
timer3 delivery is supplied by the retained capture boundary, not inferred from
fictional status-register RAM. Other priority/bank/preemption paths fail explicitly.
Hardware writes are observable events;0900/0901 are not treated as ordinary RAM.
The selected handler still does not simulate CPU registers/full IRQ frames or
the read-to-clear hardware protocol. Those boundaries remain for PTM integration.

Nineteen natural native instruction windows verify every address, exact decoded
encoding, instruction duration and generated callback entry. Their original
five-byte contexts and ROM provenance remain in `ptm-instruction-boundaries.json`;
actual instruction lengths/branch references are explicit in the runtime path.
The existing `timer-deadlines.json` supplies6103 IRQ entry boundaries independently
of shared callback events; scan times retain shared event4. Its old watchpoint
latch coordinate is not relabelled as effective bus time. The captured callback
offset field remains reference evidence and is ignored in Live.

A live test pauses dispatch between the software-shadow clear and timer3 stop,
verifies memory/VM/time/cursor freeze, resumes through96/100-cycle writes and
reaches generated callback entry128. Synthetic engine fault checks reject bank,
priority, callback/control and concurrent state changes; they are not new MAME
experiments. The previous callback fault experiment now also moves all6103
shared callback-entry timestamps by20 cycles,6102 return timestamps by100, and
changes every recorded callback offset by1000, preserving scan/IRQ boundaries.
Live writes, instruction count, callback count and memory remain identical.

No new capture or unrelated reverse engineering was required. Exact native
bytes/labels already exist in fe70.json/timer-native.txt and the byte-checked
instruction fixture; the timing-source map links these to runtime/verification.
The Ghidra export gap and original-workspace preservation remain unchanged.
Next recover actual timer arm/phase→CPU acceptance/current native-instruction
boundary. Do not claim that replacing callback timestamps solves that gap.
Validation:225 headless groups/all eight WPF modes pass; both builds are clean.
No test expectations were rebaselined; all smoke processes exited.

## Selected dispatch hardware acknowledgement connection — 16 October 2026

`Mpu4Timer3DispatchExecution` now exposes two additional incremental hardware
events: FE86 `B6 09 01` completes the status read at entry+20, and FEE1
`B6 09 06` completes the counter-MSB read at+53. These come from the same
32-instruction path already byte-checked against the ROM and natural captures.
The path, addresses and branch references remain in the runtime listing and
`ptm-instruction-boundaries.json`; no new listing is claimed lossless.

Optional `Mpu4Timer3DispatchHardware` connects that sequence to the existing
phase clock. The status read arms read-to-clear without clearing the pending
interrupt. The subsequent counter-MSB read clears it. The70BB selector write
at+85 requires CR2 bit0 clear (and timer2 enable clear); the70C2 write00 at+96
therefore stops CR3. Software RAM shadows still change at+89/+100. Hardware
registers are not stored in ordinary machine RAM. Other sources, priorities,
control modes and CPU input delivery remain outside this selected connection.

Trace-backed verification uses19 natural windows and independent
`ptm-skill-cpu.json` observations. Each explicit observed arm phase/latch bus
time seeds the existing phase model. The observed interrupted instruction's
decoded completion plus19 generates handler entry; that entry and the original
instruction encodings generate all four hardware access times. Recorded handler
and bus timestamps are comparison targets. The model reproduces acknowledgement,
output/single-shot state and every post-stop frozen counter, including their
variation between windows. Sub-cycle time is preserved from the latch observation;
integer-cycle rounding is used for comparisons only, not before stopping the
timer. This does not resolve arbitrary same-timestamp CPU/timer ordering.

Synthetic engine tests stop one cycle before and exactly at both read events,
and reject missing assertion, counter-before-status, wrong selector, stop-before-
selector and repeated reads after stop. They are not new native MAME experiments.
The existing Live pause test now also sees the first read as its next event.

The connection is deliberately optional. Live has no independently generated
timer arm/phase seed or surrounding timer1 instruction stream yet, and therefore
does not attach this hardware bridge. Its recorded FE70 boundary remains explicit.
The natural test's interrupted instruction is still observed evidence, not a
translated execution path. Next recover that surrounding scan/arm execution;
do not turn the captured native instruction list into a disguised Live emulator.
No unrelated recovery, new capture, installation/configuration or ROM/Ghidra/
original MAME modifications. The existing Ghidra export access gap is unchanged.
Validation:227 headless groups and all eight WPF smoke modes pass; full/headless
builds have zero warnings/errors.1096 curated entries verify. No expectations
were rebaselined. All owned smoke processes exited.

## Live staged output scan and generated arm — 16 October 2026

`Mpu4OutputScanExecution` translates28FE→29BA and its19C2/19FA sweep and70EF
timer-arm helpers as an incremental sequence of native instruction completions.
It selects branches from current RAM and its translated locals, never from a
recorded native path. No general6809 opcode execution was added. The selected
timing decoder adds EORA immediate88 and NEG extended70, checked in native paths.
Full native register/CC/S-stack residue is not simulated by this routine.

Live now retains shared scan ENTRY/event3, starts this translated scan there,
and advances it under the same virtual clock as the VM/dispatch/callback. Pause
stops the scan cursor, locals, RAM effects and virtual time. Individual writes
blank A00/A02/B00, advance column/counters, set selector controls, write frame
banks and emit the digit glyph at their generated instruction completion times.
Lamp-duty history records each physical bank/control write. Playback continues
using its existing verifier/scrubber. The atomic scan helper remains available
for playback and independent final-state comparisons.

The scan polls0B02 bit1 through a caller-supplied level reader (Live's current
port state), including the original38-attempt bound. Timeout stops explicitly
before the unrecovered LDB19/SWI alarm sequence; it is not silently treated as
successful readiness. Synthetic engine tests exercise two busy reads then ready
(30 extra cycles) and38 busy reads reaching that unsupported boundary. Natural
and64 isolated native cases below exercise the ready path. Electrical PIA sense
generation, alarm handling and arbitrary IRQ/FIRQ preemption remain outside scope.

19C2 retains the signed countdown/reload, signed timer comparisons at30/300,
NEG step reversal, signed LEAY addition and16-bit wrap. Exact19FA→1A03 bytes
preserve the redundant BNE with zero displacement and branch back to19E9; no ROM
quirk was fixed.70EF retains callback003D=48FD,003F&FE and0040=63 stores. Its
status/counter reads are exposed as accesses with unknown return data rather
than fabricated bytes (their loaded B is overwritten before use, then restored).
Control-selector and enable writes precede the two-byte latch store.710B STY
0906's MSB bus event is completion−1 at0906, LSB at completion at0907; the arm
observer fires on the latter. The same natural bus evidence already established
the effective latch seven cycles after the old instruction-start watchpoint.

`Mpu4Timer3ArmHardware` connects that exact read/status→counter→selector→63→
MSB→LSB protocol to the phase clock in strict verification. The19-window chain
starts from an explicit stopped snapshot (high, single-fired, latch40, counter212)
and a single clock-coordinate anchor. Every later arm, assertion, acknowledgement
and stop follows generated accesses, preserving phase across shots. Interrupted
instruction completion and ordinary19-cycle IRQ entry still supply the CPU
acceptance boundary for this test. Generated times match all19 observed arm,
assertion and callback times; the preceding independent dispatch test also checks
all19 stopped counters. This is not a claim that the CPU instruction is generated.

Live no longer reads shared arm/event5 or scan return/event4 as scheduling
inputs. It retains scan entry/event3 and independent recorded FE70 entry. The
corruption test moves6103 arms by10 cycles,6103 scan returns by50,6103 callback
entries by20,6102 callback returns by100 and all callback-duration fields by1000,
preserving those retained boundaries. Live state/output/callback counts remain
identical. No test reference outcomes or digests were weakened or rebaselined.

Panel polling, counter increments, reel service and sound scheduler still form
an explicit atomic post-scan adapter. They now run after the completed scan RTS,
rather than the old captured RTS-start marker: five cycles later on an identical
path, plus state-dependent differences. If current scan execution outlasts the
recorded outer IRQ occupancy, the VM waits for the actual scan to finish; it
cannot execute inside that native routine. The remaining timer3 callback cannot
preempt a running scan: this fails explicitly until native IRQ preemption exists.

A trial attaching the strict phase model directly to Live was rejected. The
existing three-generated-paid-games test reached a retained FE70 delivery before
the generated timer asserted. The strict constructor reported "requires an
asserted enabled timer3". This is a captured-schedule/generated-path incompatibility,
not permission to force pending status or reuse old0–7-cycle acceptance delays
at a different instruction. Final Live therefore exposes generated hardware bus
events without attaching this strict clock bridge. Next recover FEBA/FEC0→27D2
and438C/439F/19B8 post-scan execution so actual instruction boundaries can replace
the retained delivery. The natural first window interrupts1AA2 RTS; alternatives
include19BB,1A9E and439F decoding. Captured outer paths remain comparison evidence.

`Capture-OutputScanTiming.ps1` and `Curate-OutputScanTiming.ps1` reproduce64
isolated original-ROM calls across eight columns and eight state variants:
suppression, disabled sweep, sample>3, phase/count/reload choices, alternate phase
branches, decimal/blink, signed timer/step boundaries and wrap. Every native
instruction encoding/start time and final RAM/port result matches the translation.
19 natural full instruction/arm windows also match; the existing6103-scan native
final-output digest passes through this new engine without alteration. Coarse
and one-instruction updates produce identical access/instruction times and RAM.
The Live pause test stops between the five-cycle-separated bank blanking stores.

The new `output-scan-timing.json` includes exact ROM-checked regions for28FE,
19C2,19FA,70EF and the selector/blink tables, alongside selected native contexts.
These regions come directly from the SHA1-guarded ROM, not a claim that older
Ghidra listings were lossless. Call/branch targets and effects are linked in the
runtime translation, this report and existing timing-source export. Pointer003D,
selector tables28E6/28EE/28F6, phase table29BB, sample08+column, frame100+phase*16+
column, glyph1A+column, blink2BE+column, phase/count23–27, column28, suppress8D,
sweepB3 and E8/E9/EA/032D retain their previously recovered meanings. Native calls
use DP0;19C2 saves/restores A,70EF saves/restores B/CC and masks IRQ/FIRQ around
the PTM accesses. The translation does not model the resulting CPU stack bytes.

The accepted external run and raw/debug/case hashes are recorded in
`output-scan-timing-verification.json`. An initial frame-unseeded experiment was
superseded; a second preliminary run used ambiguous debugger b@a/b@b expressions,
which resolve registers rather than hex addresses. The excluded provenance keeps
that failure and hash. The final script uses explicit0x addresses, deterministic
frame data and fresh isolated MAME directories. No user ROM, settings, source
checkout or Ghidra project changed; raw logs remain external. Ghidra export access
remains unavailable as previously documented. No assembler/editor/relocator work.
Validation:233 headless groups and all eight WPF smoke modes pass; both solution
builds have zero warnings/errors.1098 curated entries verify. No expectations
were rebaselined. No installs/configuration changes, commits or pushes occurred.

## Staged input/drive service and first generated acceptances — 16 October 2026

Live now follows the completed28FE RTS with `Mpu4InputServiceExecution`: FEBA
TST2C, FEBC busy branch, FEBE COM2C and FEC0 JSR27D2, then the native prefix
through2809 JSR438C. It increments6E with byte wrap, preserves the6C/6E alternating
drive gate and writes the previous6F/70 phase bytes separately to D02/E00. The
stepper adapter now accepts one bank at each native store; the old combined
WriteDrive API remains for existing verifiers. No hardware data port is silently
represented as ordinary RAM in the new prefix.

27EC reads current physical mux input through `Panel.ReadPort(column)` at the
generated LDA0F00 completion.27EF stores that captured byte separately, and
columns0/1 duplicate it to4/5 via27F8/27FA. A release after LDA but before STA
does not change the byte already read. The Live test presses Start before the
read, pauses between read/store (releasing the physical control), verifies all
memory/VM/time/cursor state freezes, then resumes to the delayed80 RAM store.
Sticky accumulation remains later and separate; it consumes the RAM sample,
never rereads physical input. Other existing physical-input tests remain strict.

The prefix stops at438C entry, or4167 when032F is nonzero, orFECE when2C was
already busy. The latter two continuations are exposed by the runtime but fail
explicitly in Live, whose selected path requires438C. The source's temporary
2C=FF service guard persists until the remaining service adapter clears it.
Live's duplicate6E increment and combined drive call were removed. Motor service,
sticky input accumulation, counters and scheduler still run atomically at the
438C boundary; this does not claim that their internal native timing is resolved.
The VM waits for the generated prefix to finish, just as it waits for the scan.
Captured FE70 delivery and scan entry/outer occupancy remain unchanged. Timer3
preemption inside an unfinished generated prefix remains an explicit boundary.

`Capture-InputServiceTiming.ps1` / `Curate-InputServiceTiming.ps1` reproduce64
isolated original-ROM cases across eight columns and eight state variants:
busy entry, active/alternating drive, counter255 wrap, alternate4167 entry, both
input patterns and0/1 duplication. Every instruction address/encoding/start time,
end time, continuation PC/native S, sampled RAM byte and final hardware drive
value matches. The native calls stop BEFORE continuation executes. Synthetic
PIA output-mode injection supplies known0F00 values; this is not proof of the
electrical input mux or a natural button campaign. Original user settings/ROMs
are untouched; fresh capture directories isolate runtime state. Provenance and
raw/case/MAME hashes are in `input-service-timing-verification.json`.

Nineteen existing natural post-scan prefix paths also match generated instruction
times. Their test uses counter parity constrained by the captured BCC carry,
not a recovered complete natural RAM seed. This distinction is deliberate; the
64 isolated cases independently prove byte semantics and hardware write values.
The exact ROM regions at FEBA,27D2,438C,19B8 and1A87 are exported with the new
fixture under the original SHA1 guard. Five-byte instruction contexts remain
contexts, not asserted instruction lengths. The existing source map links these
regions and native references to runtime, tests and this report. Ghidra export
access remains unavailable; nothing essential is left only in a local project.

An additional bounded `Mpu4PanelAccumulationExecution` translates438C's
column&3 test and non-coin path, the C6 high-byte callback guard/indirect call,
known19B8→1A87 and the original OR/AND accumulation at8E+column/96+column.
It preserves1A87's saved A between the OR and AND operations. It stops before
439F coin decoding, an unknown indirect callback or1A05; it does not invent a
return through those routines. This helper is verification-only, not attached
to Live's remaining atomic service adapter.

This closes a genuine CPU-boundary proof for the FIRST THREE natural windows.
Starting with the existing explicit stopped timer phase, clock coordinate,
captured scan ENTRY and constrained RAM/callback19B8 seeds, execute the generated
scan and prefix, then accumulation one instruction at a time. Advance the phase
clock to each completed instruction; the first pending IRQ at an unmasked
boundary gives acceptance, and the verified ordinary19-cycle entry gives FE70.
All three generated handler times and interrupted instruction PCs/start times
match capture. The recorded last instruction is a comparison target here, not
a scheduler input. Generated entry then drives the existing selected timer3
dispatch/acknowledgement model. Full CPU register/frame reconstruction is not
claimed; priority/mask assumptions are those observed in these selected windows.

The fourth window enters439F coin decoding before expiry, so the proof stops
there. Later1A05/1A58, motor/scheduler and outer handler paths are also open.
Do not extend these three cases by choosing an old acceptance delay or forcing
timer status. Next translate the missing dispatch/coin/accumulation continuation
with source and independent native evidence, keeping normal playable-machine
scope. No new startup/credit-insertion gameplay or whole CPU emulation was added.
Validation:236 headless verification groups and all eight WPF smoke modes pass;
both solutions build with zero warnings/errors.1100 curated entries verify;
whitespace check passes. No expected outputs/digests were rebaselined. All owned
capture/smoke processes exited. No installs/configuration changes, commits or pushes.

## 439F decode/filter prefix and19 generated acceptances — 17 October 2026

The existing `Mpu4PanelAccumulationExecution` now follows the438C column&3=0
branch through439F's input decoding/filter prefix, stopping at43E1 JSR46D3's
destination. This is not recovery of the complete coin-validation routine,
credit insertion, held-switch alarm or payout behaviour.

439F loads RAM0005, masks bit7, and selects input condition11's four-byte mask
record at71EE (original ROM00 00 10 00).43B0 walks leading zero masks using Y as
the port index; the original four-slot bound and all-zero CLRB path are preserved.
The selected input bit becomes bit7 before LSLA/ADCA0 rotates the seven-bit
RAM0005 value and selected bit into a byte. The implementation preserves actual
instruction boundaries and branch costs, not a precomputed path.

43C8 reads0C02 only through an explicitly supplied hardware-value callback. The
code merges its high nibble with the rotated low nibble, then retains the exact
89/2A two-sample filter sequence: candidate B, old byte89 and old filtered2A
produce `(candidate & old89) | ((candidate | old89) & old2A)`;2A receives that
result and89 receives candidate. A missing reader fails before either filter
byte is changed. Do not replace that boundary with zero or read it as ordinary
RAM. The two original pushed A bytes are represented by saved locals; native
CPU stack contents/CC/register-frame reconstruction are not claimed.

`Capture-CoinDecodeTiming.ps1` / `Curate-CoinDecodeTiming.ps1` reproduce64 isolated
original-ROM calls from438C, using columns0/4, both selected-mask levels, varied
RAM0005/89/2A and auxiliary bytes. IRQ/FIRQ are masked. Synthetic PIA output-mode
injection supplies a known0C02 read without changing user settings; the original
ROM and condition table remain unpatched. Every executed instruction address,
exact encoding, start time, final time,89/2A result, A/B result and continuation
matches. The native S=06FC is also checked at46D3 entry;46D3 itself is not run.
This proves those controlled prefix cases, not a physical coin-input campaign.
The original table's zero-leading-mask path and selected-bit branch are covered;
the all-zero-table path is a preserved static deduction, not a new natural case.

`coin-decode-timing.json` retains exact SHA1-guarded ROM regions at438C,439F,
71EE and43E4, plus selected five-byte contexts. The curator and verification
metadata preserve source-run, debugger, case and executable hashes.43E4's88
is retained as unresolved inline material: natural execution after46D3 resumes
at43E5, whose10 26 00 DA is LBNE44C3 (fallthrough43E9). Do not misdecode the
inline88 as an EORA opcode or invent46D3's saved-return-PC convention. The name
`test_aux_input_mask_inline` in the existing function index is not a complete
calling-convention proof. This next boundary remains explicit.

The existing19-window chain now GENERATES ALL19 interrupted instruction/IRQ
acceptance times. Its scan entry, clock coordinate, stopped timer snapshot,
explicit RAM/callback seeds and original mask data remain prerequisites. Execute
the generated scan and FEBA/27D2 prefix, then438C→19B8/1A87 or439F as selected
by the current column. At each completed instruction, advance the phase clock;
the first asserted timer3 IRQ at the selected unmasked CPU boundary gives
acceptance. Add the independently verified19-cycle ordinary IRQ entry. All19
generated FE70 entries, interrupted PCs and instruction-start times match the
natural capture, then drive the existing dispatch/acknowledgement model.

Captured last-instruction PC/time and handler time are comparisons only in this
chain; none supplies a generated deadline. All19 interrupts fall before43C8,
so this proof needs no guessed auxiliary input. The remaining windows repeat
the original campaign pattern; they are not independent new game campaigns or
a complete CPU/register/interrupt-priority model. Same-time event ordering beyond
these observed cases is not generalized. No validation expectations were weakened.

Live retains captured FE70 delivery and outer occupancy, plus the atomic service
after the staged input prefix. This verification helper has not been silently
attached to Live. Next handle46D3 and1A05/1A58 continuations and suspend/resume
the interrupted native operation through the generated nested IRQ return. Only
then replace Live delivery using this instruction-boundary model, with changed
player/game paths checked as well as the reference campaign. Preserve the earlier
uncommitted input-service batch with this continuation. No installations,
configuration changes, commits/pushes, original ROM/MAME/Ghidra/workspace changes.
The documented Ghidra export-access gap remains; no assembler/editor was added.
Validation:238 full headless groups pass; both solution builds have zero warnings
or errors.1102 curated entries verify; whitespace check passes. No expectations
were rebaselined. No new Live/WPF call-site changes justified repeating the eight
GUI modes already passed by the preceding batch. All owned captures exited.

## Inline auxiliary calling convention and resumable nested return — 17 October 2026

`Mpu4InlineAuxTestExecution` separately translates46D3→46EF. PSHS16 saves A/B/X
(four bytes), LDX4,S obtains the original saved return PC, LDB,X+ consumes one
inline byte, and STX4,S advances that saved return. PULS96 restores A/B/X and PC.
The final AND supplies N/Z, with V=0 and C=0; the caller does NOT receive the
masked value in A. Native Y/U are unchanged. Full CPU frame bytes and unrelated
CC bits remain outside this translated helper's result contract.

The selector's high bit is ignored, then LSLB doubles the low seven bits. LDA
B,X uses a SIGNED byte offset from7226. Thus selector40 addresses71A6,7F
addresses7224, and high-bit variants alias these. There is no native range check.
The second path adds one to X and tests RAM7 after a zero RAM6 masked result.
Preserve these negative aliases rather than replacing them with unsigned indexing
or adding a guessed trap. Raw ROM71A6–72A5 is exported for all possible referenced
bytes; this is not a claim that the entire region is one valid semantic table.
The ordinary coin caller's inline88 selects08 and addresses7236/7237.

The short first-port-nonzero path costs58 cycles; the second-port path costs73.
64 original-ROM experiments cover selectors00/08/3F/40/7F/80/88/FF, zero/full
RAM6/7, and differing initial CC. Every instruction address/encoding/start time,
final cycle, low N/Z/V/C flags, native preserved A/B/X/Y/U and adjusted return
0501/S0702 matches. The routine is staged: input bytes are read at the native
AND completions, not computed as an early result. Caller RAM/ROM masks must be
provided explicitly through the machine state; no new input semantics are guessed.

Capture-/Curate-InlineAuxTiming.ps1 reproduce the accepted run and exact guarded
46D3 bytes/referenced ROM range in `inline-aux-timing.json`; metadata preserves
raw/case/executable hashes. An initial attempt incorrectly injected the inline
byte at0800, which is not ordinary RAM. A selector08 path mismatch exposed the
fixture error; that run is excluded with hash/reason, even though MAME exited0.
The accepted script uses inline0500 RAM and stops before0501 executes. This
experiment changes isolated runtime state only, not user ROM files or settings.

`Mpu4OrdinaryIrqReturnExecution` translates the selected FEF2 BRAFF08, FF08
LDA3,S, FF0A BEQFF13 and full FF13 RTI. It requires saved bank0 and saved CC E=1;
bank-restoration/short-frame paths fail explicitly. The four instructions cost
3+5+3+15=26 cycles after callback completion. Actual CPU frame/register restoration
remains the caller's contract; this is not an RTI instruction interpreter.

`Mpu4PanelAccumulationExecution.SuspendUntil` now preserves translated locals,
the pending opcode and its cost across a nested IRQ. It rejects a partially
executed instruction or reversed time. It shifts the pending instruction's start
to the generated resume cycle; no caller instructions run during that interval.
Engine tests verify those guards and reject unsupported bank/short-frame returns.

The19-window proof now continues beyond acceptance: generated entry/dispatch,
lamp callback and the26-cycle epilogue produce251 cycles from acceptance through
resumption. Every epilogue instruction/start/completion and final resume cycle
matches the natural callback-tail fixture. Suspend the caller until that generated
resume, then execute its remaining known instructions. Those instruction PCs and
start/completion times match the natural parent suffix up to1A05 entry or BEFORE
0C02 read. No auxiliary level is fabricated for this continuation proof. Masks
are explicitly seeded FF from the existing captured feature-entry state; this
is still a bounded state/timing proof, not full natural RAM equality or startup.

Next compose the separately verified46D3 helper into43E1, advance past inline
43E4=88 to43E5 and use its flags for the long branch, then recover1A05/1A58 as
required. Live still retains recorded delivery and its post-prefix atomic adapter.
No silent attachment or guessing of the unresolved caller was made. The existing
source map links both new runtime components to native evidence and verification.
Prior uncommitted work is preserved. Ghidra export access remains unavailable;
no original ROM/MAME/Ghidra changes, installations/configuration, commits/pushes
or assembler/editor work occurred. Raw traces remain outside tracked files.
Validation:241 full headless groups pass; both solution builds have zero warnings
or errors.1104 curated entries verify; whitespace check passes. No expectations
were rebaselined. Live/WPF call sites are unchanged; prior GUI modes were not
repeated. All owned capture processes exited.

## Composed inline caller and panel service — 17 October 2026

`Mpu4PanelAccumulationExecution` now optionally composes the already verified
46D3 helper at43E1. The caller supplies the explicit inline operand (original
43E4=88); it is not executed as an opcode. The child consumes it, advances the
return to43E5, preserves the caller's translated A/B/X and supplies Z.43E5's
LBNE44C3 takes six cycles when nonzero or five when falling through43E9. Both
are explicit continuation boundaries; later coin validation is not invented.
Prefix mode still stops at46D3 when no operand was supplied, preserving prior
native fixtures and limiting accidental scope expansion.

Parent instruction deadlines and the active inline child now suspend together
through `SuspendUntil`. Child input reads still occur at their native instruction
completion. An engine-only experiment uses synthetic selector80 (not real88),
stops before the second-port portion, suspends for251 cycles, changes RAM7 during
that interval, and resumes. Its instruction sequence/times equal the baseline
with exactly that251-cycle insertion, and its branch observes the later value.
This is a controlled engine experiment, not a new natural IRQ/input capture.

Optional `continuePanelService` follows the non-coin callback19B8 through1A87,
1A05 and1A58, then19C1/439E RTS to280C. Unknown callbacks still expose their
destination; default prefix mode still stops at1A05.1A05/1A58 only perform their
checks when column byte29=7. Original ROM flag bytes FF4C/FF46 are explicit
machine data, both FF in this ROM; callers must load them, not mistake new zeroed
RAM for ROM configuration. The zero-flag alternative paths are static translations,
not claimed to be covered by the unpatched native matrix below.

1A05 starts B=FF and tests FF4C. With original nonzero FF4C it executes LDA0004
and BITA#00; that test is always zero, so CLRB runs. This odd zero mask is retained,
not repaired. B is compared with stored0339. Equality clears counter88. A different
value increments88 with byte wrap; below10 it returns, otherwise it stores B to
0339 and JMPs7CCF.1A58 derives00/FF from RAM5 bit08 (or forcesFF if FF46=0),
compares it with032F, and uses E2's corresponding equality clear/difference
increment/threshold10. At threshold it stores the new032F byte before JMP7CCF.
The existing function index labels7CCF `reset_and_game_entry`; the slice exposes
that destination without attempting reset/startup. CounterFF→00 wrap and the
write-before-jump effects are preserved.

Capture-/Curate-PanelContinuationTiming.ps1 reproduce64 isolated ORIGINAL
composed calls from438C:16 coin paths and48 non-coin panel paths. The matrix
uses original ROM/table/configuration bytes, masked IRQ/FIRQ and explicit RAM/
PIA input values. It covers both inline outcomes, OR/AND latches, column-seven
equality clears, below-threshold differences, threshold reset jumps and counter
wrap. Every native instruction encoding/address/start time, final cycle,
continuation PC, native S and final filter/latch/counter/stored state matches.
All four exits280C/43E9/44C3/7CCF occur. The experiment stops before those
destinations execute; it is not gameplay, physical door operation or coin insertion.

`panel-continuation-timing.json` includes exact ROM regions for1A05,1A58,19B8,
inline43E4/branch43E5 and the configuration bytes. Five-byte native contexts
remain contexts, not inferred instruction lengths. Verification metadata records
raw/case/executable hashes and source run. The existing timing-source export
links caller/child implementations and evidence. This extends the same recovery
system; no separate assembly/editor/export framework was introduced.

The existing19-window proof now resumes all15 non-coin paths through1A05/1A58
to280C, comparing each resumed instruction start/completion against the parent
trace. Its four coin paths still stop BEFORE0C02 read, whose actual value is
not provided by this capture; the native matrix supplies explicit synthetic
values only for independent combined-call verification. Captured scan entry,
state seeds and the selected IRQ mask/priority contract remain prerequisites.

No Live/WPF scheduling call sites change in this continuation. The source proof
must not be silently attached to Live with missing C6/ROM-config seeds or later
coin/motor/scheduler semantics. Next recover the ordinary no-coin43E9→4395 return
path and its actual auxiliary source, then join normal service and generated IRQ
execution. Earlier uncommitted work remains preserved. No installs/configuration
changes, commits/pushes, original ROM/MAME/Ghidra changes, full startup or symbolic
assembler work. The Ghidra export-access gap is unchanged; bulky logs stay external.
Validation:243 full headless groups pass; both solution builds have zero warnings
or errors.1106 curated entries verify; whitespace check passes. No expectations
were rebaselined. Live/WPF call sites are unchanged, so no repeated GUI suite was
needed. All owned capture processes exited.

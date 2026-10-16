# MC6840 timer clock foundation and phase findings

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

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

Next candidate observation: the accepted opcode stream contains26 samples each
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

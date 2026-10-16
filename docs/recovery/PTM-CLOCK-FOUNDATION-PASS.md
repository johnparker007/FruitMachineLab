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

## Next timing milestone

Keep this ahead of broadening gameplay outcomes: the selected natural
post-shot/disable/rearm lifecycle and first20 canonical arms are now verified.
Next recover instruction-boundary/input-delivery timing and the selected native
handler paths, then broaden to timer1 contention/nested services and later arms.
Replace the callback template only when those stages can be connected without
choosing an arbitrary latency. After that, derive timer1/IRQ service scheduling
and progressively replace per-word captured execution costs. Captures remain
regression references throughout; the complete playable machine remains the goal.

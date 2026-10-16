# Skill Cash timer deadline investigation

Historical checkpoint. PTM-CLOCK-FOUNDATION-PASS.md (16 October) adds natural
attract-mode observations of both starting phases and a96-sample synthetic bus
matrix. The18–25-cycle range below is conditional on starting low; it is not a
measured canonical phase or a universal latency. Starting high gives26–33.
The later canonical20-arm observer directly sees high phase and establishes
that the old STY watchpoint coordinate is seven cycles before effective bus
access. For that prefix the corrected assertion→handler range is19–26 cycles.
The remaining arms are not assigned a phase from that short window.

14 October 2026. This pass observes a debugger watchpoint at the timer-3 latch store, rather than
the entry to native helper 70EF. No original workspace files or machine settings
were changed. The new capture uses isolated temporary configuration/NVRAM directories.

## Trace-backed findings

The fresh MAME 0.281 campaign matches the original SHA256 values for state.csv,
feature-state.csv, input-levels.csv and final RAM. There are 6,103 latch stores at
0907, all from STY at 710B. The debugger reports PC 710F after operand fetch.
Every observed latch is 0028 with control 63. IRQ entry FE70 occurs 346–353 CPU
cycles after its reported instruction coordinate; callback 48FD occurs exactly 128 cycles after IRQ entry.
All 6,103 callback cycles and columns independently match the earlier shared-memory
capture exactly. This adds evidence without replacing its expected lamp outputs.

Curated rows contain absolute latch cycle, latch value, IRQ offset, callback offset
from IRQ, and column. Raw logs remain outside the repository; provenance includes
their hash. Capture and curation scripts reproduce the observation and reject
changed campaign hashes, unexpected stores, overlapping arms and incomplete pairs.

## Source-backed calculation

[MAME's MPU4 driver](https://github.com/mamedev/mame/blob/master/src/mame/barcrest/mpu4.cpp)
sets the PTM clock to master/4; the [board header](https://github.com/mamedev/mame/blob/master/src/mame/barcrest/mpu4.h)
sets master to 6.88 MHz. [MC6809 conversion](https://github.com/mamedev/mame/blob/master/src/devices/cpu/m6809/m6809.cpp)
also divides master by four, giving 1.72 MHz CPU cycles and internal PTM ticks.

[The PTM implementation](https://github.com/mamedev/mame/blob/master/src/devices/machine/6840ptm.cpp)
decodes 63 as mode 4, internal clock, interrupt enabled and timer-3 divide-by-eight.
Starting with low internal output, its first transition takes one prescaled tick;
the following transition takes latch ticks and sets the interrupt flag. Thus latch
40 gives (1+40)*8 = 328 cycles. Starting high gives 40*8 = 320 cycles.
`Mpu4Timer3Deadline` implements only this calculation with an explicit starting
phase and reset-released precondition. Other controls fail explicitly.

These source links describe upstream master inspected during this pass, not a
claim of byte-identical installed source. The installed binary's independent trace
is the behavioural reference. Its IRQ timings are consistent with starting low,
leaving 18–25 cycles after calculated expiry before IRQ entry. This is a consistency
check, **not observation of the hardware-expiry instant or proof of starting phase**.

## Verification and remaining boundary

57 dependency-free groups pass. New checks cover both phases, zero/max latch,
overflow and unsupported control; synthetic early IRQ and reordered latch rows are
rejected. Both solutions build without warnings/errors. The diagnostic verification
also checks the new evidence; the UI remains separate from runtime calculation.

Callback timing is still recorded. CPU interrupt acceptance, instruction-level
masking, exact PTM expiry observation, timer reset/retrigger and other controls are
not implemented by this bounded calculator. Replacing callback timing now would
guess the unresolved 18–25-cycle latency. The next investigation should observe the
PTM interrupt assertion and CPU instruction/CC phase around acceptance, then connect
generated deadlines to the shared runtime when that ordering is independently proven.

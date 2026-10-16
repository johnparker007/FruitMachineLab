# Native start tone and pre-spin gates

16 October 2026. Live now passes native5A14's timed start routine, F384/F2C8's
pre-spin flags and F20D's selected random-gate route. It stops at F38C before F072
and the remaining requested-stop selection/spin sequence. Credit5, cash bank16,
token bank0 and pending/current-win0 remain intact. No new completed spin or
consecutive-game claim is made. Audio synthesis remains outside the runtime.

## Natural evidence

Successful narrow windows extend the unchanged physical TAKE/three-Nudge1/Start
campaign from PREPLAY-START-STAKE-PASS.md. No ROM/RAM/register/PC injections occur.

| Fixture | Entry → terminal | VM observations | Sound commands |
| --- | --- | ---: | ---: |
| nudge-tone | FC4D → F384 | 3 | 6 |
| nudge-spin-flags | F384 → F38A | 155 | 0 |
| nudge-spin-gates | F38A → F38C | 652 | 0 |

All have zero lamp requests/alpha bytes/lifted dispatches, successful process exits
and no debugger-expression errors. Every observed VM signature, input/timing
schedule, sound command and terminal protected-accounting vector is checked.
The gates verifier also compares the complete150..19F reel-record block. Each
entry independently matches the preceding verified terminal signature. Raw traces
remain external; curated windows, exact capture commands and provenance are tracked.

The natural gate window advances the original PRNG18 times, seed1798 → F95E.
Its candidate request bytes169/16B/16D are6/13/17 and refreshed symbol bytes are
4/2/6; these are intermediate software projections, not physical reel movement
or the final stop-selection result. The actual main-reel positions remain6/90/42.

## Timed native routine

5A14 preserves nativeD, loads A91/B02 and calls59FF.59D9 computes91-60=31, stores
it at004D and queues stream59EB. The stream contains instrument/channel operands,
a note, then an infinite loop with a255-tick wait. Native7159 repeats the calibrated
7164 CPU loop twice; it does not wait for that sound task to finish naturally.
5C7A cancels the first task with root59EB and59FF clears004D. Other tasks survive.
The scheduler now retains roots for fresh, child and restored tasks and supports
that selective cancellation. Existing note/register synthesis exclusions remain.

Live performs setup, queue/delay and cancellation/return as retained phases while
the virtual IRQ/input/output services advance. It holds the VM at FC4D until the
native call returns. Pause freezes the phase, memory, scheduler, VM and virtual
time; Resume continues them. The headless and GUI tests pause while004D=31 and
the queued stream is active, then check cancellation/004D=0 and continued gates.
The GUI uses its existing physical Start mouse handlers and no recorded inputs.

The phase budgets381/35058/394 are explicit capture-backed CPU pacing adapters
under the existing FE70→FF13 interrupt-body accounting. They include unresolved
IRQ acceptance/RTI and native allocator/cancellation costs.35058 is not claimed
as a pure6809 instruction count for the calibrated loop. Queue setup is atomic
at the observed post-queue phase; sub-instruction IRQ acceptance is not emulated.
Six native PC/clock/tick/parameter observations are retained in nudge-tone.
The recorded replay uses their clocks, while Live generates events incrementally.
Disabled-tone pacing (719B bit80) remains an explicit unsupported Live branch;
the queue/cancel primitives themselves retain the native sound-disabled gate.

## Gates and native reel requests

F2C8 counts selected reel bits and updates pre-spin flags. F20D evaluates the
recovered counter/credit parameter profiles, symbol flags and original random
tests. The selected route executes F1C3, F19B, F186 and F0EB before returning.
SHA1-checked profile records and request bases are loaded as static ROM data;
no captured gate outcome, seed progression or requested stop is replayed in Live.

Native2BBC iterates reel2 → reel0 with masks08/10/20 in0086. It clears each request
byte even when held. Only an unheld reel advances59BB; it takes the high byte of
4*returnedB (zero to three) and adds the corresponding base from2BBB/2BBA/2BB9.
Those bytes are11/0B/06, stored as the ascending-reel bases06/0B/11. The old
recovered name saying “multiple of four” was misleading: MUL's high byte is used.
F186/F0B0 listing annotations now say zero-to-three offset. The original Ghidra
JSON export/name is retained as provenance rather than rewritten as original source.

An isolated48-case MAME matrix checks all eight hold masks, seeds0000/FFFF/1798
and IRQ bytes00/FF, comparing0000..06FF RAM. It proves request clearing, reverse
iteration, skipped held-reel PRNG calls and exact seed/results for these inputs.
These are synthetic IRQ-masked native experiments, not natural spins. CPU-stack
residue and intra-native IRQ acceptance remain outside the comparison.

168 headless verification groups and all eight WPF smoke modes pass. Additional
checks ensure cancellation preserves unrelated/duplicate sound tasks. The full
Live nudge→award→Start→debit test now pauses inside the native tone and reaches
F38C. Its physical positions and protected accounting remain checked. Different
live Start timing can change IRQ-derived randomness; that test does not assert
that its post-gate candidate symbols equal the recorded campaign. The independent
natural-window replay does compare that full reel-record block exactly.

## Preservation and reproduction

Extend the previous Capture-SkillCash command through NudgeStake with NudgeTone,
then optionally NudgeSpinFlags and NudgeSpinGates. Keep TailWindow, NoMotorItems,
NativeSound and CpuInterrupts. Curate-BoardLink accepts the same stage flags,
excluding NoMotorItems. Existing capture/manifest conventions remain in use.

Capture-ReelRequestMatrix.ps1 accepts MameExecutable, RomDirectory, SeedRam
(the gates tail-entry-ram.bin) and a fresh RunDirectory; Curate-ReelRequestMatrix
imports only completed, error-free cases. No original MAME configuration is used
or changed. An overlapping local build briefly encountered a verification DLL
lock; the completed final build/tests used the current binaries and passed.

Export-MameDisassembly's AccountingCheckpoint now includes tone, delay,
cancellation/root lookup and native2BBC. The existing encoding checkpoint checks
111 VM spans and1502 native disassembly rows against the identified ROM, retaining
inline stream/instrument data, request bases, parameter records, implementation
links and verification qualifications. These selected spans are not a lossless
full-ROM listing. Preserved Ghidra exports are copied/hash-linked; no live Ghidra
API was available for a fresh complete symbol/comment/data-definition export.
No assembler, editor, compiler, installation or configuration change was added.

Next: F072's final request selection, F248/A03C/F30F adjustments and F2B5's main
reel execution/result. Preserve the candidate/final/physical distinctions and the
actual credit debit. Other hold/compensation routes remain limited to established
helpers and selected data coverage. Long-wait native2CB3 remains explicit.

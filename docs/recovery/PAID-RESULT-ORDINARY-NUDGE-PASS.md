# Paid result and ordinary nudge

16 October 2026. Live passes F398 result evaluation and FC66/EE62 award handling.
An offered ordinary nudge uses the existing physical NUDGE controls and incremental
motor, stopping at B749 before post-sequence improvement/result. A generated
no-nudge route stops at FC7C before the outer paid-game return. Neither boundary
claims complete consecutive games. Playback remains separate.

## Natural reference windows

These extend the unchanged physical TAKE / three Nudge1 / paid Start campaign.
Only the final step capture adds an ordinary physical Nudge1 press.

| Fixture | Entry → terminal | VM observations | Lamps | Sound commands | Alpha bytes |
| --- | --- | ---: | ---: | ---: | ---: |
| nudge-spin-result | F398 → FC68 | 203 | 18 | 0 | 0 |
| nudge-paid-nudge | FC68 → first B403 | 459 | 23 | 3 | 46 |
| nudge-paid-step | FC68 → B749 | 909 | 72 | 155 | 65 |

The last window deliberately overlaps the offer window. Starting at B403 would
require restoring an inherited sound-loop stack not supported by the boundary
adapter. Starting at FC68 instead executes the real sound queues and loop creation;
no active sound state is discarded or fabricated.

All accepted captures exit0 without debugger-expression errors or state injection.
Each entry matches the preceding verified terminal. Verification compares complete
canonical VM signatures, actual input-condition handling, ordered lamp/frame and
sound digests, alpha bytes, terminal reel records, lamp RAM and protected accounting.
The captured result is zero, no award is credited, cash bank16/token bank0/credits5
remain. BD=0 distinguishes ordinary nudges from the earlier BD=15hex Nudgepot route;
BE becomes1 at the offer and0 after physical Nudge1, while BF stays0.

paid-nudge-native contains135 observations through61F6 motor cleanup. The driven
motor model generates optics; recorded optics are assertions, not inputs. Only
reel1 moves six positions (modulo96), requests clear and protected positions,
complements and checksum update. Per-service clocks remain reference scheduling
evidence; Live consumes no recorded motor or player event sequence.

Two completed FC68→B749 captures, with and without the stack watchpoint, have
identical1701 selected SC/LF/SN/AB/QE/RM lines. The attempt manifest records their
hash and scope. It also excludes an early terminal before window entry and a
later MAME access violation. Bulky raw files remain external. The earlier complete
B403-entry capture is unused because its inherited sound stack is unsupported.

## Recovered scripts and data

F398 checks the refreshed matching result, combines its zero-test with the saved
pre-spin flag and A0 mask0400, and conditionally uses the existing AE3A accounting
route. The selected natural path skips that accounting. FC57 clears the original
reel lamp range. EE62 selects EE11 for the zero result; the selected flag2 tests
skip fourth-reel award handling and the zero pending award is normalized without
adding money. Alternate paying branches are not newly proven by this capture.

B5ED selects the feature-pot path for BD=15hex. Otherwise B5D7 chooses a weighted
count, native29EC searches the flagged best result, native1AF1 supplies its fallback,
and B51D applies the result-specific parameter profile and complemented random
percentage test. The original order and PRNG advances are retained. The observed
draw yields one accepted ordinary nudge; no fixed offer is assigned.

B5C9 and B5CF are dictionary headers containing raw9A19; B5CB..B5CE weights are
00/21/22/21hex (0/33/34/33), and B5D1..B5D4 are00/14/14/3Chex (0/20/20/60).
9A1C subtracts weights from its hundred-range draw until negative and returns the
index. The selected0330==0 route uses the first table; the other table is static
evidence. A729..A7A8 preserve the result-profile headers and data needed by B51D.
Identical two-byte constant/profile gateways share existing captured entry pacing,
checked by the exporter. Called VM bodies and native helpers still execute; this
does not claim exact general CPU timing or validate every profile branch naturally.

## Interrupt stack residue

The complete nudge check initially rejected B33D: the C# model read staleBF at
local+2, while MAME read00. A read-only watch of079D..07A5 shows the last079F write
at reported PC00FE, value00, S079F, YB72F, before B730 allocates local frame079D.
The write sequence saves U0672, YB72F and X7963 as well. Identifying079F as the
full6809 interrupt frame's DP byte at pre-interrupt S07A8-9 is a static deduction
supported by that sequence; the value and later read are trace-backed.

VmControlStack.PreserveInterruptDirectPage retains only that known byte. It does
not initialize local frames or synthesize the other CPU registers/CC. The reference
uses the observed inline-literal phase, validated against the stack context. Live
applies the known DP=0 save when its virtual IRQ occupancy interrupts an inline
literal with unchanged native S depth. Other native stack depths and interrupt
footprints remain unresolved. Live may take the other wait branch when its virtual
interrupt falls elsewhere; no captured00 is forced into the later local variable.
The focused regression checks local-frame reuse and unchanged neighboring bytes.

## Live coverage and continuation

The quick-Start / three-Nudge1 Live campaign produces a no-nudge result and reaches
FC7C. A separate generated physical-input campaign chooses Nudge1, then Nudge2,
then Nudge1 only if still offered. An early win can end the earlier sequence after
the second press; no third press or exhaustion is forced. This strategy reaches
a one-nudge offer after the paid spin. Its physical
Nudge1 executes with prompt/motor Pause/Resume checks, preserves bank16/credits5
and reaches B749. This input variation is a synthetic Live integration experiment,
not an exact MAME-equivalence claim for that different full campaign. The natural
reference windows above establish exact equivalence for their captured state/inputs.

The WPF check retains the original real-time paid Start/spin path. A separate
mixed-input prefix runs through existing input handlers under controlled virtual
updates, then resumes real-time GUI execution for ordinary Nudge1, with prompt
and motor pause checks and screenshots. This avoids assuming that different
wall-clock input phases must generate the same offer.
No cabinet, audio synthesis, credit insertion or startup implementation is added.
The headless suite passes177 verification groups, including both generated Live
routes and the focused interrupt-residue regression. All eight WPF modes pass;
the solution builds with zero warnings/errors.

Reproduce using Capture-SkillCash's existing flags through NudgePaidSpin, then
NudgeSpinResult, NudgePaidNudge and NudgePaidStep as required. Keep TailWindow and
NoMotorItems. Curate-BoardLink uses the same stage flags; Curate-DiceMotion -PaidStep
exports motor evidence. The final step requires the observed stack watch record.
Curate-NudgeData exports byte-checked weights/profiles/gateway aliases, and
Curate-NudgeEncodingCheckpoint -PaidStackRunDirectory preserves the watched writes
alongside existing selected native bytes, VM spans and C#/verification links.
No live Ghidra API was available; comprehensive symbol/comment/data-definition
export remains an explicit gap. Selected spans are not a lossless full-ROM listing.
The checkpoint now checks129 selected VM spans and1565 native instruction rows
against the unchanged ROM; it retains both earlier and new stack-write provenance
when regeneration omits their optional raw-run paths.

Next recover B749's ordinary post-sequence improvement/result and the outer paid
return past FC7C. Preserve persistent state and handle paying or flagged outcomes
only as evidence permits. Long-wait2CB3 and other unknown native paths remain
explicit. Do not reset to the earlier feature to manufacture another game.

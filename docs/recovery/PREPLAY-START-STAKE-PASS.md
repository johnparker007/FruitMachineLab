# Preplay Start and paid-play stake

16 October 2026. Live now returns from the recovered ladder/nudge award to a
running preplay input loop. The existing physical START control requests the next
paid play through sampled BLACK2, recovered input conditions and the panel latch.
Credits change6 to5; cash bank16/token bank0 and pending/current-win0 remain.
Execution stops explicitly at FC4D before native5A14's fixed timed tone and F384's
spin/evaluation sequence. This is not another completed game or full startup.

## Natural evidence

Three successful windows extend the existing TAKE/three-Nudge1 campaign:

| Fixture | Entry → terminal | VM observations | Lamp requests | Alpha bytes |
| --- | --- | ---: | ---: | ---: |
| nudge-eligibility | FC99 → FCD5 | 351 | 14 | 0 |
| nudge-start | FC99 → FCDC | 1368 | 52 | 0 |
| nudge-stake | FCDC → FC4D | 419 | 122 | 56 |

There are no lifted dispatches or sound commands in these windows. Every VM
signature, ordered lamp/frame digest, alpha byte, input-condition observation,
protected credit/bank vector, statistics vector and scaled-accounting vector is
checked. The Start window contains six input-condition reads and128 characteriser
responses. Entry signatures independently match the preceding verified boundary;
the Start window shares the FC99 entry with eligibility rather than following its
terminal. Each selected process exits0 without debugger expression errors.

The additional Start pulse is a physical BLACK2 mask80 override beginning at
406.6 seconds, lasting12 frame callbacks. No RAM, PC, register or ROM edits occur
in these natural campaigns. Their raw actions/input-level CSVs and traces remain
external; curated fixtures, capture scripts and provenance sidecars are tracked.
The stake window additionally saves26 bytes at7190 at entry/window boundaries.
These contain ROM configuration, not a new mutable-RAM snapshot. Newly consumed
ROM719A/71A2 are loaded from SHA1-checked ROM data and checked against the entry
observation; captured input events are never applied in Live.

## Recovered execution

FC99 calls D30F/D1F5/D2BE before the remaining FC80/F509/D587 gates. The natural
route sets8000 at00A0 through D1CD, skips hold initialization when4000 is clear,
and updates each reel's lamps through D257. Dynamic words8448/844E/8454 use8444
to push address0090 and masks0002/0004/0008; table9E1E selects them by loop index.
Their native/header bytes and pointer records are preserved. This establishes
the selected eligibility path; it does not establish all hold/gamble outcomes.

FC99 combines its flags, input condition12 and0080 panel-latch test. FCD5 branches
back through FCC5/background services when zero. On an accepted request FCD8/FCDA
clear0080 at0090 and FCDC calls FC34. A still-held physical button can be sampled
again and reassert the latch during subsequent work; this is preserved rather
than treating Start as a UI callback into game selection. Live's test releases
after the sampled press, while the natural capture holds for12 frames. Exact
transient latch/time equivalence between those different inputs is not claimed.

FAFC clears feature lamps/flags and nudge pot, including native171D's inline lamp
stream1720..1724 and native2C5E's three reel groups. AC25 then executes AB64 credit
consumption/stake statistics, AC03's signed-counter gate, A588 compensation service
and9F28's conditional counter decrement. The natural path reaches FC4D with five
credits and the matching protected accounting bytes. Native3AFA's conditional
035B/035C decay and native57DB's mode-gated unsigned24 increment are translated.

Native14EB uses nine-byte records at1462 and consumes the selector's low byte.
It subtracts the configured amount from the selected24-bit counter and refreshes
the accounting complements. Native4D9B derives that amount from the configured
target, capped margin0336, cached target/complement, key inputs, DIP inputs or
ROM148F fallback. Those are configured targets, not measured payout rates.
The native underflow clamp800000 precedes an explicit unsupported SWI3 alarm65;
no recovery or compensating credit is invented. Selectors outside the five curated
records remain explicit unsupported data coverage, not a newly inferred ROM trap.

New generic VM mechanics are right rotation using the count's low four bits,
32-bit negation with wrap, and signed double comparison (signed high cells,
unsigned low cells; FFFF iff the top double is greater). The debugger signature
reader now reads retained physical memory when its four-cell observation extends
beyond active host stack cells; it does not manufacture zero stack entries.

## Verification and limits

The75-case isolated MAME matrix covers decay gates/wrap, configured target clamps,
valid cached targets, all15 nonzero key indices, all15 nonzero DIP indices,
five accounting selectors at four counter values, and mode-gated counter wrap.
It compares0000..06FF and protected07C9..07E7 RAM, plus returnedD for4D9B. IRQs are
masked and native CPU-stack/register residue is outside that comparison.

These are synthetic native experiments. Configuration alternatives deliberately
patch719A/71A2 in MAME's in-memory ROM region; ROM files remain untouched and each
requested patch is read back before execution. An initial attempt used ordinary
address-space writes, which did not change ROM; that attempt is excluded. The
fixed harness uses explicit region access, as documented in the
[MAME debugger memory expressions](https://docs.mamedev.org/debugger/index.html).
Separate C# synthetic tests cover double arithmetic boundaries, invalid cached
target repair and the underflow clamp; these are not MAME alarm-path captures.

163 headless verification groups and all eight WPF smoke modes pass. The expanded
Live test runs the whole recovered ladder/three-nudge/improvement/award route,
compares the lamp sequence through first eligibility and alpha shadow, pauses the
real waiting VM, presses/releases Start, and checks credit5 and final accounting.
The WPF test exercises the actual Start mouse handlers and saves ready/paused and
post-debit screenshots. Existing playback and other entry modes remain separate.

Live still uses the documented captured CPU-cost/IRQ adapters; these windows do
not establish CPU-level equivalence or full electrical timing. A sufficiently
long preplay wait can still reach untranslated native2CB3 via timer002F's sign
change. Native171D is now translated;2CB3 remains explicit. Other hold, gamble,
super-hold, fault/reset/menu and paid-spin paths require evidence before support.

## Reproduction and preservation

Use the same natural capture flags documented in
BACKGROUND-SERVICES-PREPLAY-PASS.md through NudgePreplay. Append NudgeEligibility
for FC99→FCD5; append NudgeStart as well for FC99→FCDC; append NudgeStake as well
for FCDC→FC4D. Keep TailWindow/NoMotorItems and the narrow observers. Curate with
the matching Curate-BoardLink switches (omit NoMotorItems there).

Capture-StakeMatrix.ps1 accepts MameExecutable, RomDirectory, SeedRam (the new
stake tail-entry-ram.bin) and a fresh RunDirectory. Curate-StakeMatrix.ps1 imports
only completed cases with observed requested configuration. Export-MameDisassembly
with NudgeCheckpoint/AccountingCheckpoint and Curate-NudgeEncodingCheckpoint
preserve the selected native bytes, inline selector/stream data, VM token/operand
spans, function exports and implementation/evidence links. Preserve the existing
StackRunDirectory when regenerating that checkpoint.

The existing encoding checkpoint now checks97 selected VM spans and1394 native
disassembly rows against the identified ROM. Linear disassembly still includes
inline data; its typing limitation is explicit. These selected spans are not a
lossless full-ROM listing. Existing Ghidra JSON exports were copied reproducibly;
no live Ghidra API was available for a fresh complete symbol/comment/data export.
The future byte-identical rebuilt-ROM aim remains deferred behind playable-machine
recovery. No assembler, compiler, script editor or relocation system was added.

Next: recover native5A14's timing/sound contract and F384's paid-spin preparation,
requested stops, main-reel execution and result path using the same physical-input
campaign. Resolve long-wait2CB3 when extending preplay duration. Preserve actual
credit debit and persistent accounting rather than resetting feature entry.

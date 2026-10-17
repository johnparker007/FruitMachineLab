# Payout caller timing — 17 October 2026

This continues PAYOUT-DEBIT-TIMING-PASS.md toward selected cash/token caller
ownership and Live collection. Whole-machine IRQ acceptance and symbolic assembly
remain deferred. No installation/configuration or original workspace changes.

## Batch1: input-condition CPU plan

Mpu4InputConditionPlan stages67EC through return: ordinary four-port masks,
rewind/all-mask comparison, signed DIL selector route and original byte-shift
aliases/inclusive table bounds. Zero/carry retain their three distinct outcomes.
Invalid selectors stop before6854 SWI3; alarm behaviour is not invented.
NativeRoutineExecution is a clock for explicit C# instruction plans, not a CPU
emulator. It retains pending effects/flags across partial updates and only accepts
IRQ suspension at an unmasked instruction boundary. A typed child-call handoff
blocks advancement until a matching return; faults cannot resume past a boundary.
It will be reused by the immediately following payout caller plans.

Capture-/Curate-InputConditionTiming.ps1 preserve64 synthetic original-ROM paths:
eight selectors times eight injected sampled-port patterns, masked IRQ. Every
native PC/encoding/start cycle, final cycle and returned Z/C match MAME. Original
register preservation is checked by curator; selected RAM0000..06DF matches.
Native S-stack residues are caller-owned. A separate synthetic suspension test
changes a sampled port after BITB and retains the original branch flags; invalid
selector retries remain faulted. This is not natural input acquisition evidence.

Evidence collection/input-condition-timing.json includes exact67EC..6857 bytes
and71AA..7249 records, checked against ROM SHA1 before export. Existing67EC native
annotations remain linked by address; fresh Ghidra synchronization remains a gap.
No lossless symbolic rebuild claim is made. Raw pointer: %TEMP%/FruitMachineLab-
input-condition.txt. Reproduce capture with MameExecutable/RomDirectory/fresh
RunDirectory, then curate with RunDirectory/RomPath. Test filter: "Payout input
condition". Headless build and both new groups pass.

## Batch2: payout tail and reusable queue checksum

AddersPayoutTailPlan stages4C91, flattening the verified67EC input plan and7032
checksum under the same instruction clock. It retains A across those helpers,
threshold versus threshold+1 adjustment, saved002C guard and the original FF42
override/TSTA result. Mpu4QueueChecksumPlan preserves7009/7032 register-local
operands and instruction-ordered RAM stores; it is reusable by the selected
cash caller. No payout output occurs in this component.

The existing input capture/curator gain -PayoutTail mode (32 cases) and export
tail-timing separately, preserving the64-case input fixture. Four records and
eight injected tail/input settings match every instruction/encoding/start cycle,
final cycle, allowed/Z and RAM0000..06DF. This is synthetic masked-IRQ evidence,
not a natural empty/full-pin interpretation. A suspension test mutates another
queue during checksum, retains sampled A and restores the guard. Existing exact
payout native spans plus byte-checked instruction contexts cover4C91/7032; no new
Ghidra-only discovery. Raw pointer payout-tail.txt. Filter: "Payout tail".

## Batch3: complete selected normal cash caller

AddersCashPayoutPlan stages4B39, its67E2 inline82 selector (the byte4B3C is data),
4C25 denomination/tail loop, ROM-option checks and forced4C7C loop. Physical native
S return/D-save words are supplied at each4CBE handoff. AddersTimedCashPayoutExecution
composes the previously verified timed debit/display/output owner, never semantic
Outputs. The flat clock is now reused across input, tail, checksum and caller.
The4BC5 manager prompt and negative0323 service mode remain explicit boundaries.
Caller arithmetic flags are selected local operands, not a complete exposed CPU
snapshot; child output does not currently export every transient condition flag.

Capture-PayoutService.ps1 -InstructionTiming now executes real7172 polling with
odd717C counter increments, instead of its legacy skipped-wait mode. New curator
Curate-PayoutCallerTiming.ps1 checks original ROM bytes and separates caller
instructions, child entry/return and display NEXT observations. Sixteen cases
are preserved (eight cash/eight token); the cash component verifies its eight:
every caller PC/encoding/start cycle, every child entry Y/S/time, final cycle,
poll count and selected RAM/accounting match without intermediate state injection.
Only per-alpha helper CPU budgets are reference adapters; no return timestamps
drive runtime. Counter policy is synthetic, not natural IRQ scheduling/delivery.
Selected RAM exclusions retain U scratch05C0..05FF and native S residue; F0..FF
and persistent accounts are compared. Default old service capture is unchanged.

Synthetic suspension at tail/display/poll preserves all RAM/output effects and
adds only the requested411 cycles. A labelled synthetic option change reaches
the manager boundary and fails without inventing a prompt. ROM files are unchanged.
Caller byte spans already exist in payout-data; new export preserves67E2's exact
inline wrapper too. Raw pointer payout-caller.txt. Filters: "Payout cash".

## Batch4: token compensation and accounting complement timing

AddersTokenCompensationPlan stages both identical-byte tails4D07/4D51 at their
distinct ROM addresses plus6F57. It preserves subtraction of500 from the low word,
borrow into the signed high byte and original overflow clamp80 WITHOUT replacing
the already-subtracted low word.002C is overwritten FF then0, not restored.
Normal mode refreshes15 accounting complements/checksum; negative mode skips
that refresh but still performs the compensation subtraction.

Capture-TokenCompensationTiming.ps1 covers32 synthetic original-ROM cases: both
tails, normal/service mode and eight unsigned/signed24 boundaries. The existing
native-matrix curator detects token_compensation provenance and exports separate
token-compensation-timing evidence. All instructions, encodings, cycles, lower
RAM and persistent accounting bytes match. Native S scratch remains excluded.
Synthetic suspension after SBCA retains the original overflow decision. Existing
payout spans plus exact6F51..6F78 bytes preserve the selected body; historical
6F57 Ghidra export is copied from prerequisite-pass, not claimed fresh. Raw pointer
token-compensation.txt. Filter: "Payout token compensation". Next token caller.

## Batch5: selected token caller and tail-flush composition

AddersTokenPayoutPlan stages4B8C/4CF8/4D45 through both token records, current-ROM
forced route, compensation and changing-level tail flush. AddersTimedPayoutServiceExecution
is the demonstrated shared cash/token owner (renamed from the cash-only class).
No duplicated debit/output implementation was introduced. Unknown entries, service
mode and manager prompt remain explicit. Original nonzero rather than denomination
test, possible odd-balance underflow and compensation omission during tail flush
are preserved. Do not reinterpret level bits as proven physical empty/full pins.

The16-case caller capture now also observes6F57 instructions. All16 cash/token
paths match every caller instruction/encoding/start cycle, child entry Y/S/time,
final cycle, poll count and selected RAM/accounts. Alpha CPU budgets remain the
only observed helper timing inputs; no intermediate memory/CPU snapshots or return
timestamps drive runtime. Waits are real original polling under the documented
synthetic counter policy. The shared owner has only the selected normal-mode ABI;
it does not export all transient CPU flags left by output service.

A separate synthetic level-change experiment matches the established semantic
reference: first token debit changes the sampled level, tail flush drains the rest,
four debit/output pairs occur but500 compensation happens only once. Suspension
inside6F57 retains the FF software guard and original completion state. This is
not a captured natural input transition. Filters: "Payout timed callers" and
"Payout timed token". Both pass; headless build is clean.

## Batch6: VM-to-native payout word bridge

AddersVmPayoutWordPlan/AddersTimedPayoutWordExecution recover80E4/80F4 ->776F.
They include RAM NEXT, original nonzero F1 bit0 mode changes,080C hardware callback,
PSHS Y/JSR[,X] frames, real native caller and PULS Y/JMP NEXT. This is distinct
from the reverse76BF gateway used inside display. No extra logical VM call frame
is fabricated. Expected site+2 cursor is checked; a changed native return cursor
stops explicitly. Missing080C owner fails before payout. The VM host must acknowledge
completion once, never run semantic payout a second time.

Capture-PayoutService.ps1 -VmBridge extends instruction mode with a two-token RAM
test stream at0110, original ROM headers and full native bridge observation.
Sixteen synthetic original paths (cash/token, existing inputs/amounts, F1=0/8)
match every bridge/caller instruction, exact child entry/final cycle/poll count and
selected RAM, with real nested display and polling. Only alpha helper CPU budgets
remain observed adapters. Original VM S and data cells survive; synthetic pause
between saved-Y and JSR retains that frame. Nonzero-mode write sequence also has
static/source and isolated76BF verification; it is not full characteriser emulation.
The curator checks RAM FC/FE against NEXT opcodes, never against ROM00FC bytes.

VM-word-timing is separate from native caller timing. payout-word-data preserves
exact776F..778C and80E4..80F7 bytes, including interleaved native pointer fields.
No fresh Ghidra access/source reconstruction claim. Raw pointer payout-word.txt.
Filter: "Payout VM word". Next is VM host integration under the existing service
clock, retaining sound-pool and alpha-helper boundaries explicitly.

## Batch7: timed collection VM host

AddersTimedCollectionExecution composes the recovered collection transfer VM with
the timed payout WORD owner. It acknowledges native completion once, retaining
one machine, VM data/control context and caller memory. Pause freezes execution,
pending native/display work and its virtual clock. The enclosing host must also
freeze IRQ/input/sound clocks. Ordinary collection VM/helper CPU budgets and alpha
budgets are REQUIRED explicit delegates; zero is rejected. Host supplies the VM
interrupt mask. No service period, IRQ acceptance or new captured schedule is guessed.

AddersCollectionWordBindings is shared with the established semantic collection
host, preserving actual sampled input handling, finite sound allocation, source
reset effects and the native/logical sound-list mismatch boundary. It does not
fabricate0047 or claim sound-task lifecycle recovery.

Sixteen legacy original-ROM router and32 credit/Collect-gate cases match selected
RAM, debit ordering, output sequence and return flag under the new composition.
These fixtures explicitly skipped waits in MAME; comparison is SEMANTIC, not
elapsed-cycle equality. The new owner executes real polling driven by synthetic
counter changes. Ordinary VM budget1 and alpha budget1000 in these tests are
LABELLED synthetic scheduling inputs, not proposed machine timing. Initial VM
root frame/NEXT are supplied from the independently verified76BF contract because
the old fixtures start before that gateway. No per-step state is injected.

Integration exposed that the old semantic-only S=0800 convenience is unsafe for
real native frames: nested display saves can overwrite persistent07C9 accounting.
The timed host rejects such a context. Tests use the real gateway's root-frame
position0782 (pre-push0784), retain the persistent accounting comparison and pass.
This corrects the test/host context; ROM behaviour is not repaired. Native S
scratch and semantic U scratch remain explicitly excluded, as before.

Pause tests stop inside alpha and polling and preserve all state/deadlines/output;
sound mismatch/zero-budget tests fail closed. Both timed matrices, pause/boundary
tests and the18-group Collect regression filter pass. No GUI integration is
claimed: its retained outer IRQ adapter still needs explicit foreground ownership
integration, and sound-pool lifecycle remains open. Next verify repeated physical
Collect transactions and freeze a full regression checkpoint before host UI work.

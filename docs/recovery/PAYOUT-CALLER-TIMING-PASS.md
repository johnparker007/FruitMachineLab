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

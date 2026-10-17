# Collection transfer and bounded IRQ audit — 17 October 2026

Historical transfer-only checkpoint: the subsequent
[payout pass](COLLECTION-PAYOUT-PASS.md) composes AA2B with native payout/output.
Its newer gameplay scope supersedes the next-step notes below; the bounded outer
IRQ audit and runtime recording dependencies remain applicable.

## Decision and actual gameplay frontier

The nineteen natural windows do **not** yet execute without captured outer IRQ
entry timestamps. The current proof generates nested timer3 acceptance from staged
execution after entering each captured timer1 window. It also seeds non-scan RAM
from a natural checkpoint. That is a component proof, not autonomous whole-machine
execution. The latest FE70 dispatch work has already removed the separate captured
scan-entry Events table; repeating that work would not close outer acceptance.

Inspection of SkillCashLiveSession and the staged service classes identifies a
substantial remaining boundary: atomic VM/native work, especially active motor and
sound service, does not expose every interrupted instruction, temporary U value or
interrupt-mask transition. A timer1 period alone cannot determine acceptance there.
Do not substitute captured U or acceptance offsets for those missing semantics.
The existing working adapter is retained. Further instruction staging is deferred
because it does not block collection/paid-game recovery. This pass adds no timing
independence claim and no new recorded runtime scheduling dependency.

The earlier AFF0/paid-return frontier is obsolete: the repository already executes
award accounting, outer paid return, multiple paid cycles and selected nudge/board
continuations. Collection toward native payout service is the next useful frontier.

## Runtime recording audit

| Source | Current Live use |
| --- | --- |
| cpu-interrupts.json timer1_handler_entries | 6103 accepted outer FE70 entry timestamps drive service scheduling |
| cpu-interrupts.json intervals | 6045 merged outer occupancy intervals pace VM/delay work; repeating template |
| cpu-interrupts and game-path site/token cost dictionaries | Captured costs still pace un-staged native/VM work |
| feature-replay, board-result and selected game checkpoints | Initial RAM, stacks, RNG/accounting state for the chosen entry; not full startup |
| shared-timing.json InitialScan and initial clock | Initial scan/peripheral checkpoint; Events are not consumed by Live |
| irq-service-data.json | Static ROM ranges plus initial PIA/callback/drive and stopped timer3 hardware checkpoint |
| lamp-frames.json | Initial frame RAM and characteriser response mapping, still required hardware evidence |
| alpha/compensation exports | Initial software/compensation state in feature-entry seeding |
| timer-deadlines.json | Verification only; no longer loaded by Live |
| captured dispatch/input/lamp/alpha trajectories | Comparison/playback; Live player input and subsequent outputs are generated |

Generated components include timer3 phase/assertion, selected instruction-boundary
acceptance/entry/dispatch/callback/return, FE70 dispatch, scan, and selected idle
input/panel/post-panel work. This audit describes dependencies rather than claiming
all fields in the larger capture files are scheduling inputs.

## Executable collection VM

`src/FruitMachineLab.Adders/AddersCollectionTransfer.cs` runs the existing recovered
listings through ScriptExecutor, keeping VM arithmetic/calls/physical S frames and
loop continuation. It uses the caller's existing Machine and control stack. The
caller supplies its return cursor, as with other physical VM entry execution.

| Entry / extent | Recovered effects before payout |
| --- | --- |
| A983–A99C | Signed remainder modulo10 from02FC; subtract from02FC, **add** to02FE; refresh NVRAM;4B39 |
| A9A0–A9C4 | Signed quotient by10, low-bit Forth flag; (2+flag)*10 gives10 for odd tens or20 for even; subtract from02FC, **store**02FE; refresh;4B39 |
| A9D5–AA00 | Even remainder from0302, repeated two-unit subtract/add0300, refresh and4B8C per iteration |
| AA04–AA1F | Five two-unit subtracts from0302; **store**0300=2 each time; refresh and4B8C |
| A942–A972 | Lamp18 pattern8F; transfer0302 to0300, refresh,4B8C; transfer02FC to02FE, refresh,4B39; lamp18 pattern80 |

These words consume no application arguments and normally leave no data result.
Nested arithmetic uses7DFA/7DF0/7DE4/7D64/7DC6/7D3A and physical return frames.
NVRAM6E06 preserves its normal/service-mode guard. Original wraparound and
add-versus-store behaviour are intentional. No balance clamp or inferred fix is
introduced. Input selection by AAA1/AA2B is not yet connected to this component.

Execution suspends **before**4B39/4B8C. Step refuses to cross that boundary.
ServicePayout invokes an explicit host service and advances only after it returns;
exceptions retain the pending VM call. It must not be connected to Live with a
no-op or recorded-state restoration callback. Neither native service nor physical
coin delivery is implemented here. There is no virtual timing claim for these
new paths and no new GUI control yet.

## Evidence, preservation and verification scope

`evidence/mpu4/collection/bank-transfer-validation.json` is copied unchanged from
the original workspace's evidence/payout-pass. The historical report says30 checks;
only16 example pairs are retained. This pass independently executes **those16**
cash examples, not all30. Their output pairs are expectations only, never runtime
state. Original reports, ROM and bulky traces remain untouched outside Git.

`vm-encoding-checkpoint.json` records exact contiguous ROM bytes for the five
transfer listings and six arithmetic bodies, checked against a6ls.p1 SHA1
402d1518bb78fdc489b06c2aabc771e5ce151847. Every listed token was checked against
the ROM. Regions include embedded operand bytes between the first token and final
return. Token header/dictionary meanings still come from existing recovered
listings: this is not a checked lossless symbolic representation or rebuild.
Addresses, operand listings and call targets remain in VM-SCRIPTS; this checkpoint
extends existing curated evidence rather than introducing a second source format.
Ghidra export access was not available in this pass; no new Ghidra-only discoveries
were made. Existing symbols/comments remain in their prior exports.

Six new verification groups cover natural cash examples, encoding drift, parity
and store/add distinctions, repeated token loops, ordered combined collection and
explicit service failure/suspension. Token and combined-service tests use labelled
**synthetic host callbacks** that clear pending balances; they prove VM continuation
only, not4B39/4B8C/6858 or MAME-equivalent payout timing. The original natural tests
and recovered listing observations remain distinct from those experiments.

Validation: baseline257 groups passed; final full suite263 groups passed. The
final token/inline-operand checks also passed in the six-group Collection filter.
Headless and full WPF solution builds succeeded with zero warnings/errors using
the installed SDK and --no-restore. UI behaviour is unchanged; no new GUI smoke
campaign was required. An initial build overlapped the baseline verifier's locked
DLL; it was repeated successfully after that verifier exited.

Next: translate4B39/4B8C selection and4C25/4CBE debit/accounting through their actual
6858 output-service continuation, then connect AAA1/AA2B to the paid-play prompt.
Use existing payout/prerequisite exports first. Preserve queue increments versus
delivered output, manager/empty-channel input waits and the disabled A90F AND0
quirk. Do not hold up this work for comprehensive IRQ accuracy.

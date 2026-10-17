# Preplay Collect gate and payout pulse timing — 17 October 2026

## What executes now

The composed headless collection engine can enter AB1B, AAF2 or AAA1 as well as
AA2B and the transfer words. It executes the actual credit/Collect predicates,
prompt lamp/sound queue, prioritised bank routing and native payout against one
retained machine. It does not substitute a button event for a feature decision.

Collect and Take are **one physical input**: BLACK2 bit01, active high. Pinned MAME
mame0281 `src/mame/barcrest/mpu4mod4yam.cpp`, m4addr INPUT_PORTS_START, labels it
"Collect / Take Feature". Peeled source commit:
2843a3deb81cf93735244044894196ccfbea4d20. No MAME source checkout/settings changed.
ROM condition1C at721A contains00000001: native condition handling reads sampled
byte0003. Mpu4PanelInput.SetCollect aliases SetTake; Release clears that shared
physical bit. Sampling occurs through the existing acquisition/accumulation model.
The separate sticky OR latch is0091, not0003. AAA1 reads the **sampled level**,
so a stale sticky bit must not cause collection after the sampled release.

## Recovered gates and contracts

| Location | Behaviour / preserved details |
| --- | --- |
| AB1B–AB2F | Nonzero credit byte02F0 takes AAD7 and returns FFFF, bypassing AAA1 on this path. Zero credit takes AAF2 |
| AAD7–AAEE | Original0038/0085 and0100/00A0 mask predicates determine lamp18 clearing; returns Forth true |
| AAF2–AB17 | Calls AAA1; current719F bit2000 is zero, so optional credit-topup branch stays unexecuted; returns zero |
| AAA1–AAD3 | Sum five balances OR A90F's literal-zero result; prompt while nonzero; auto-collection when signed002D>6400, option1000, `(balanceSum & condition82)` or sampled condition1C is nonzero |
| A91B–A932 | Lamp18 pattern83; if native task list0047 is empty, reset scheduler and queue8784 |
| 5C18–5C79 | Pop free head0049, link new active head0047; preserve37-byte task layout, source/root pointers,5D3B callback, internal stack end, attenuation/tempo fields and due0045+1 |

AB1B leaves one flag cell; AAA1/AA2B do not normally add a result. VM call/return
frames remain physical recovered frames. Signed timer behaviour is preserved:
6400 itself does not trigger;6401 does;8000 is negative and does not. This is not
an unsigned elapsed-time comparison or a repaired timeout. A90F still ANDs0.

`AddersCollectionExecution` invokes `AddersSoundQueueMemory.Queue` alongside the
existing logical scheduler. Empty free list means no task is allocated. It does
not expand the pool or overwrite an unrelated pointer. Volume multiply/high-byte
saturation, inversion and unsigned due wrap remain native mechanics.

The physical sound node lifecycle during background processing is **not** newly
recovered here. Queue/reset snapshots match the reference with service paused.
New Collect prompt handling rejects a disagreement between0047's active/nonactive
state and the logical scheduler instead of choosing a fabricated ROM branch.
Logical child-task processing, node reclamation and physical task RAM must be
composed before treating this as a complete running sound-service implementation.

## Bounded timing work for Live

`src/FruitMachineLab.Runtime/Mpu4PayoutPulseExecution.cs` now stages native68A0
through68C9,7172 and718A instruction by instruction. It restores the saved pulse
mask, performs both protected PIA read-modify-writes, executes all thirteen groups
of five006E-change waits per edge, and returns at685A. Every deadline comes from
M6809InstructionTiming decoding the original bytes. No captured timestamp is a
scheduling input. New decoder cases are direct CMPA (91) and extended ORA (BA).

IRQ masking changes at the translated ORCC/PULS boundaries. Suspension is allowed
only at an instruction boundary with IRQ unmasked. A compare's sampled condition
survives suspension and a subsequent006E change, as the original condition flags
do. Native stack-save RAM/CPU register gateway remains caller-owned; this component
models the selected register values, interrupt masks and instruction effects.

Eight original-ROM experiments match **every executed PC, instruction start cycle,
encoding, final cycle, counter and port value**. The two triac write values also
match. These experiments run the real polling loops without skipping them, but
use a synthetic counter policy: increment006E before each odd717C compare and
leave it unchanged before each even compare. IRQs are masked, so these are not
natural timer/IRQ acceptance windows or evidence of a physical payout duration.

MAME write-watchpoint totalcycles identifies the **store instruction start** in
these captures. The translated access is committed at instruction completion.
Verification compares the recorded watchpoint with the corresponding store start,
and its modelled access with that store's verified completion. It does not assert
equality of the two timestamps or an exact sub-instruction electrical pin phase.

## Reference scope and preservation

32 fresh synthetic original76BF→AB1B cases cross credit0/1, Collect level0/1,
002D=0000/6400/6401/8000 and Scottish level0/4. They compare the returned flag,
bank/mirror/accounting/display/lamp/sound-queue/serial RAM and exact debit/output
sequences. Payout waits in **this gate matrix** are explicitly skipped via7199,
as in the earlier service matrices. The separate eight-case pulse matrix does
not skip them. Neither matrix injects reference state into production execution.

RAM exclusions remain00F0..00FF native gateway,05C0..05FF stale U-stack residue,
native0700..07FF S-stack, and synthetic006E changes; persistent accounting
07C9..07E7 is separately checked. These are selected-state comparisons, not a
claim of byte-identical whole-machine RAM or full machine startup.

Additional synthetic tests check unsampled press/release, shared Take semantics,
sticky-versus-level behaviour over repeated polls, finite pool exhaustion, due
wrap, attenuation extremes, IRQ masking and compare retention over suspension.
The attenuation extremes and inconsistent-list rejection are source-derived
experiments, not new natural MAME observations.

The existing curated conventions are extended: collect-gate-matrix.json and
pulse-timing.json retain compact expectations, observer catalog, provenance and
raw hashes; debugger commands sit beside them. payout-data.json preserves the
condition map, pointer/mask records, selected sound streams and native5C18 bytes.
vm-encoding-checkpoint.json now covers35 bodies in AB1B's static closure,
including unreachable/unsupported optional topup branches. Tokens and inline
literals are checked; no lossless symbolic ROM rebuild is claimed. Existing
native5C18/5C51 exports already preserve names/assembly/comments, so no duplicate
native export was created. Fresh synchronized Ghidra export access remains a gap.

Reproduce with existing installed tools:

```powershell
./tools/Capture-CollectGate.ps1 -MameExecutable <mame281.exe> -RomDirectory <roms> -SeedRam <seed.bin> -RunDirectory <fresh-gate>
./tools/Curate-PayoutService.ps1 -RunDirectory <fresh-gate>
./tools/Capture-PayoutPulseTiming.ps1 -MameExecutable <mame281.exe> -RomDirectory <roms> -RunDirectory <fresh-pulse>
./tools/Curate-PayoutPulseTiming.ps1 -RunDirectory <fresh-pulse> -RomPath <a6ls.p1>
./tools/Curate-PayoutDebit.ps1 -RunDirectory <existing-debit-matrix> -RomPath <a6ls.p1>
dotnet run --project tests/FruitMachineLab.Verification --no-build -- . Collect
dotnet run --project tests/FruitMachineLab.Verification --no-build -- . "Payout staged"
```

Selected %TEMP% runs: FruitMachineLab-collect-gate-ebd22945511248a784bbad561853c702
and FruitMachineLab-payout-pulse-36962d221ac347a5bf2b524fe01a10cb. An earlier pulse
capture without the write observer was superseded, not used for bus-phase claims.
Original analysis workspace, ROM, MAME settings and Ghidra projects are preserved.

## Actual next integration boundary

Validation:276 verification groups passed, including all prior Live and MAME-backed
regressions. Headless and full WPF builds passed with zero warnings/errors using
the existing SDK and --no-restore. No GUI code changed, so there was no new GUI
smoke campaign. The final export regeneration is also checked by the focused
Collect/encoding and staged-pulse verifiers. No installation, existing configuration
change or push was performed.

There is still **no new collection GUI mode**. Live's Cost has no80E4/80F4 payout
word pacing; existing5B77/5C18 budgets are retained adapters for older paths.
The semantic payout runner must not be attached with zero-cost foreground work,
nor may its pulse output run alongside the new staged pulse and double-write.

Next compose the source-derived native prefix/debit/display and call/return
ownership with this staged pulse and Live's host clock, then expose Collect in the
paid-play prompt. Sound pool ownership also needs the lifecycle qualification
above. The remaining work is specific to this integration; a comprehensive MPU4
IRQ campaign is not required. Current outer timer1 capture adapters remain
explicit and unchanged. No new captured runtime timing dependency was added.

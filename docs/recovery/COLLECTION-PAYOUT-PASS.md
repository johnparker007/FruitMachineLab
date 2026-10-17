# Collection payout service — 17 October 2026

## Executable scope

The prior transfer-only boundary is now composed with translated native payout.
`AddersCollectionExecution` runs recovered AA2B, including A936 prompt clearing,
all six normal collection arms, VM bank transfers, native4B39/4B8C, debit/accounting,
the A8F9 balance-display call and6858 output pulses. It retains the same Machine,
physical VM control frames and caller-supplied alpha/lamp/PIA interfaces throughout.
No captured intermediate state or captured event timing is supplied to this path.

The caller enters with an existing VM control stack and return cursor. Step advances
one semantic boundary; Address identifies that phase, not a cycle-accurate6809 PC.
Pending native payout runs before the transfer VM resumes. Pause prevents component
progress; the host also owns—and must pause—its virtual service clock. The existing
GUI/Live paid-play loop has not been connected to collection in this pass.

`payout-data.json` is a static ROM export, the only new runtime evidence input.
The debit/service/router matrices are verification expectations only. Existing
characteriser response mapping remains the lamp interface's hardware dependency.
The existing outer timer1 entry/occupancy adapters are unchanged; no IRQ-independence
claim is added. Gameplay recovery continues without another timing campaign.

## Native contracts and implementation links

| ROM location | Recovered contract / implementation |
| --- | --- |
| 4ACA/4ADB/4AEC/4AFD | Four17-byte records; Y selects condition, queue pointer, denomination, tail limit, pending balance and accounting/meter pointers. `AddersPayoutRecord.Read` in `src/FruitMachineLab.Adders/AddersPayoutAccounting.cs` |
| 4B39–4B88,4C19–4C2D,4C7C–4C8F | Cash condition82 gates100p record, then20p service; unsigned denomination comparison and tail gating; selected ROM option bytes permit forced20p fallback. `AddersPayoutExecution.Cash/CashRecord` |
| 4B8C–4BC4,4CF8–4D73 | Token1 service then Token2/forced fallback. A level change after a debit installs the record's tail count and flushes that tail. `Tokens/TokenRecord` |
| 4C91–4CBC | Condition sampling adjusts tail threshold; FF42 zero forces nonzero success. No physical full/empty polarity is inferred beyond observed bit levels. `Tail` |
| 4CBE–4CF0 | Subtract denomination from indirect balance,6E06, VM display body through7D36, optional/two mandatory u24 accounts, meter queue/checksum, byte queue increment/checksum, tail-jump6858. `AddersPayoutAccounting.Debit` |
| 4CCB–4CCE,7D36=A8F9 | Actual recovered VM display call, including suppression masks, credit fraction, sum and alpha formatting. `AddersPayoutDisplay.Refresh` |
| 57A9/57F7,59A4/6FEC/6FC1 | Unsigned24 wrap with signed0323 mode gate; meter16-bit wrap, checksum over035E..0369 plus increments, negative003A clear. `AddersPayoutAccounting` |
| 68E0/7032/7009 | Unconditional pending-pulse byte wrap and checksum over036B..0372 plus increments. Queued pulses are not a delivered-coin count. `RefreshOutputChecksum` |
| 6858–68D9 | Scan four queues in address order; decrement count/tail; optional serial notification; read/OR/write IC8 triac port, wait, read/AND/write, wait. `AddersPayoutExecution.Outputs` |
| 7172–7199 | B=0D, five observed006E changes per group:65 changes per edge. Constant719B bit80 can skip the wait at entry. `BeginWait/Step` |
| 4D07–4D26 /4D51–4D70 | Subtract500 from signed24 compensation07D2..07D4. Preserve high-byte80 overflow clamp with the already-subtracted low word; guard002C is overwritten FF then0. `SubtractTokenCompensation` |
| 511B–51AF | Positive single-byte serial message filtering and queue insertion, wrap, checksum/count and busy flags. `AddersPayoutSerial.Enqueue`; negative two-byte messages remain unsupported |
| 5B77/5B8F/60AB | Existing logical scheduler reset plus task free-list, channel bytes and YM register cache. `AddersSoundResetMemory.Apply`, scoped to collection. Optional register-write output, no synthesis/timing |

Native helpers take Y/record and register arguments; they do not directly add VM
data-stack results. The nested A8F9 call has balanced recovered VM frames. The
semantic wrapper deliberately does not reconstruct76BF CPU register saves,
trampoline bytes, transient native stack residues or every peripheral instruction.
Existing exports in evidence/mpu4/native preserve assembly/pseudocode names and
comments; names are reconstructed, not original source.

Some archived comments describe4AFD as unobserved; that historical qualification
is superseded by the prerequisite report and the new selected-channel fixtures.

## Preserved behaviour and remaining boundaries

Normal current-ROM cash/token and all six AA2B arms execute. Native4BC5 manager
prompt remains explicit for option variants needing it. Native68CB service-mode
tone/busy delay also remains explicit. No state is silently cleared to escape
either boundary. Serial transmission is not implemented here; only enqueueing.
YM output is an event/cache effect, not audio synthesis. PIA callbacks must provide
the real latch interface; output commands do not prove physical coin delivery.

Do not clamp a pending balance, pending-pulse byte or accounting overflow to a
host-friendly range. Native4CF8 tests nonzero rather than denomination coverage;
odd token balances can underflow. The new normal fixtures use even token balances.
The token tail-flush loop does not repeat the500-unit compensation subtraction;
the ordinary loop does. A synthetic changing-level test explicitly preserves this.
AA2B still clears002B on return. A90F still reads the credit fraction then ANDs0,
so AA93 stays disabled. No inferred ROM bug is repaired.

Output waits consume observed changes in006E, including byte wrap. They never
advance time themselves, and repeated Step calls with an unchanged counter make
no progress. These are translated polling semantics, not a proof of exact CPU
sampling, elapsed milliseconds or autonomous outer IRQ acceptance.

## Independent reference and verification scope

Fresh isolated MAME281 experiments use the original ROM without patches:

* **32 debit cases:** native4CBE through real nested VM display, stopping before
  6858. All four records, normal/service modes, display suppression on/off and
  0000/FFFF balances exercise subtraction/wrap, accounts, queues and checksums.
* **16 service cases:** original4B39/4B8C, both Scottish input levels and low/high
  channel-level inputs, small/larger amounts. Compare exact denomination/balance
  debit sequence, output write sequence and selected RAM/accounting.
* **16 router cases:** original76BF entry with X=AA2B. Cover cash remainder/chunk,
  token remainder/bulk and direct pending cash/token routes through display,
  lamps, sound reset, serial queue and payout. Compare the same observations.

All are **synthetic isolated native/VM experiments**, not natural gameplay traces.
IRQs are masked. Service/router experiments explicitly redirect7172 to native7199
RTS, skipping the waits. The C# verifier instead drives006E changes synthetically;
therefore006E is excluded from that state comparison. Separate tests check65 changes
per edge, unchanged-counter suspension, byte wrap and read-modify-write preservation
when other triac bits change during the wait. No natural timing equivalence is claimed.

RAM comparison covers0000..06FF except native gateway/trampoline00F0..00FF and
stale physical U-stack residue05C0..05FF. Native S-stack0700..07FF is excluded,
but persistent accounting/checksum07C9..07E7 is compared separately. Display shadow,
digit RAM, frame RAM, bank/mirrors, accounting, meter/output queues and serial state
fall within the checked regions. This is not byte-identical whole-machine RAM.

The seven new verification groups include these three matrices, counter waits,
multi-call collection across mixed retained balances, pause/resume and a changing
Token1 level/tail-compensation case. The latter tests are explicitly synthetic
component scenarios. They do not claim hundreds of paid games or full startup.
The earlier16 retained natural cash-transfer examples remain regression evidence.

## Reproduction and preservation

Use the installed tools, fresh RunDirectory and existing SeedRam:

```powershell
./tools/Capture-PayoutDebit.ps1 -MameExecutable <mame281.exe> -RomDirectory <roms> -SeedRam <seed.bin> -RunDirectory <fresh-debit>
./tools/Curate-PayoutDebit.ps1 -RunDirectory <fresh-debit> -RomPath <a6ls.p1>
./tools/Capture-PayoutService.ps1 -MameExecutable <mame281.exe> -RomDirectory <roms> -SeedRam <seed.bin> -RunDirectory <fresh-service>
./tools/Curate-PayoutService.ps1 -RunDirectory <fresh-service>
# Repeat service capture with -Collection and a fresh directory for router cases.
dotnet run --project tests/FruitMachineLab.Verification --no-build -- . Payout
```

Selected raw runs under %TEMP%:
`FruitMachineLab-payout-debit-d5ebd92d65ce4c36bb171507ef5a0955`,
`FruitMachineLab-payout-service-f8a028f12f4a45d8bcb0259b1052e625`,
`FruitMachineLab-collection-router-89c9799201564d228f8ee6ab36c28808`.
Curated matrices retain original snapshots, observer results and hashes. Debugger
commands are retained beside them. Original analysis workspaces remain unchanged.

Excluded discovery runs: two service captures stopped at masked-counter waits or
lost temporary return stops; one router capture rejected an accidentally combined
register assignment. Their terminated/incomplete outputs are not curated as success.
Ignored attempted option-ROM writes in early scripts did not modify ROM; final
capture tools avoid them. Watchpoint continuation requires a permanent return
breakpoint. The final curators require every expected exit, snapshot and paired
output count and reject debugger errors.

The extended vm-encoding-checkpoint preserves27 bodies in AA2B's static call
closure, including unvisited/disabled arms; tokens and inline literal operands
are checked against exact ROM bytes. payout-data preserves native byte spans,
record/pointer/constants, serial masks/messages and sound-cache defaults. Static
branch targets and shared tails remain in the native listings. These exports do
not constitute a lossless assembler representation or byte-identical rebuilt ROM.
No fresh Ghidra-session export was available; relevant previously archived native
exports were copied without overwriting existing exports. A later synchronized
Ghidra symbols/comments/data export remains a preservation checkpoint gap.

## Next gameplay work

Validation:270 verification groups pass; the final Payout filter also passes after
regenerating the curated exports. Headless and WPF solution builds succeed with
zero warnings/errors using the installed SDK and --no-restore. No existing Live
UI code changed, so no new GUI smoke campaign was required. No installation,
existing configuration change or push was performed.

Connect AAA1/AA2B's actual Collect input/prompt path to the existing paid-play Live
host, using its generated service counter and PIA interfaces. Establish the native
payout ownership/VM pacing boundary explicitly rather than assigning invented
instruction costs. Keep the playback viewer separate. Collection state and output
logic are now executable; host/UI integration and continuous paid-game validation
are next. Comprehensive IRQ timing remains deferred unless a concrete blocker arises.

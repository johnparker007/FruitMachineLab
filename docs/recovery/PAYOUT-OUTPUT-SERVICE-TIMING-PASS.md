# Staged normal payout output service — 17 October 2026

## Result and scope

`Mpu4PayoutOutputExecution` now executes selected normal-mode native6858 through
its return, including queue search/decrement,7032 checksum, positive511B serial
notification, and the existing68A0 pulse/7172 polling child. Instruction timing
comes from checked6809 encodings, not a captured duration or event schedule.
This replaces the isolated pulse's predecessor boundary for component execution;
it does not yet attach collection to Live or time native4CBE's debit/display work.

The caller supplies Machine, start cycle, initial interrupt-mask bits, return
cursor and PIA latch callbacks. AdvanceTo commits instruction effects at their
completion. It can stop partway through an instruction; SuspendUntil requires an
unmasked instruction boundary. Parent and child clocks suspend together. Queue
and serial updates are generated from current state, not precomputed outputs.

The helper models selected A/B/X/Y values and mask state needed for this path;
native CPU save-frame RAM remains caller-owned. No general6809 emulator, new
VM pacing table or whole-machine autonomous IRQ claim is introduced.

## Recovered paths and preserved details

| ROM region | Translated behaviour |
| --- | --- |
| 6858–6876 | Native save timing; scan036B/036D/036F/0371 in order using201A masks; sample pending count, decrement actual current byte and optional tail |
| 6878→7032–7048 | Preserve X/A/B/mask and original002C; set guard1; call7009; write checksum at0373; restore sampled guard and registers |
| 7009–7018 | Unsigned byte sum over036B..0372 with one increment per byte plus final increment. Empty6858 does not invoke this refresh |
| 687B–688B | Original002B==20 bypass and signed0323 gate, then719B bit04 early return. Service-mode tone/delay68CB remains explicit |
| 688D–689D | Save mask/frame timing, derive channel message from20B0..20B3, call511B |
| 511B–51AF | Positive-message mode/category filtering, queue-pointer normalization, count/checksum, busy flags and read/write pointers. Negative-message contract remains unsupported |
| 68A0–68C9,7172–7199 | Composed staged pulse and real polling loops, then repeat queue search. No duplicate semantic pulse writer is called |
| 686E | Native return timing to the caller-supplied continuation |

A captured comparison condition survives suspension before its branch. A changed
queue can be found on the next search without restoring any snapshot. Pending,
tail, serial checksum and count bytes retain native wraparound. Serial queue count
at/above20 sets007D=FF and ORs002B with80; pointer3D4 is normalized to3A8. No
overflow repair, delivery counter or invented channel-empty behaviour is added.

The normal current-ROM notifications are positive42/44/4A. Negative511B filter
arguments and a queued byte changing to a two-byte message are explicit unsupported
boundaries, as is68CB. Any execution error latches Fault, disposes continuations
and prevents a later AdvanceTo/SuspendUntil from silently resuming past it. State
already changed before the boundary is retained, not rolled back.

## Independent verification

Eight fresh original-ROM MAME cases cover empty queues, each channel separately,
all four channels, repeated pending counts and mixed channels. Tail values0..3,
006E byte wrap, invalid/full serial write pointers, checksum wrap and the serial
busy threshold are included. They match:

* every executed PC, instruction start cycle, encoding and final cycle;
* all RAM0000..06DF, including queue/checksum guards, bank memory and serial state;
* every triac write value and its corresponding store instruction boundary;
* final counter, port, return PC and native S restoration in the reference.

Native S-frame residue06E0 upward is excluded from RAM equivalence. These are
**synthetic isolated experiments** with masked IRQs. The counter policy increments
006E before odd717C comparisons and leaves it unchanged before even comparisons.
The waits are actually executed, not skipped. The policy is generated in both
runs; recorded counter values/timestamps are expectations only. Natural IRQ service
cadence and actual coin delivery are not proved by these cases.

As established in the pulse pass, MAME's write-watchpoint totalcycles marks the
store instruction start in this instrumentation. The model commits at the verified
instruction completion. Tests compare those distinct boundaries, not an invented
electrical pin-edge timestamp. New decoder cases TSTB5D and extended ADDBFB are
exercised by the serial path.

Additional synthetic tests suspend at7032's checksum loop and inside the nested
7172 child, inject another pending pulse, and compare complete shifted instruction
sequences/RAM/output values against uninterrupted execution. No pulse is duplicated,
and guard002C is restored. Another test verifies fail-closed unsupported service
mode, including no subsequent state change after a caught error.

## Evidence and reproduction

The existing Capture-/Curate-PayoutPulseTiming.ps1 tools now accept/select full
output-service captures rather than adding a second capture framework:

```powershell
./tools/Capture-PayoutPulseTiming.ps1 -OutputService -MameExecutable <mame281.exe> -RomDirectory <roms> -RunDirectory <fresh-run>
./tools/Curate-PayoutPulseTiming.ps1 -RunDirectory <fresh-run> -RomPath <a6ls.p1>
dotnet run --project tests/FruitMachineLab.Verification --no-build -- . "Payout complete"
dotnet run --project tests/FruitMachineLab.Verification --no-build -- . "Payout output"
```

Selected raw run: %TEMP%/FruitMachineLab-payout-output-63059eba51df4367886dd91b564378ec.
Compact catalog/relative instruction expectations, RAM observations, raw hashes
and debugger commands are curated as collection/output-service-timing.*. Each
context is checked against a6ls.p1 SHA1
402d1518bb78fdc489b06c2aabc771e5ce151847. Existing native6858/7019/511B exports and
payout-data native spans preserve source labels, shared tails and exact bytes.
There are no new Ghidra-only facts; synchronized Ghidra export access remains a
separate known gap. Neither this listing nor the preserved spans are claimed as
a lossless symbolic assembler/rebuilt ROM.

## Next boundary

Validation:279 verification groups passed. The headless build and isolated WPF
build passed with zero warnings/errors. The normal WPF build was blocked by the
already-running diagnostic app's locked files; the app was left untouched and
BaseOutputPath was overridden only for a temporary build. No existing configuration
was changed. No new GUI code changed or GUI smoke campaign was needed.

Compose the timed output service with source-timed4CBE debit/NVRAM/display and
native VM entry/return ownership. The new service must replace, not accompany,
AddersPayoutExecution's semantic Outputs writer in a timed host. Live80E4/80F4
still lack a complete foreground CPU budget. Physical sound-pool lifecycle remains
the other previously documented Collect integration gap; it was not silently
declared solved here. Keep the working Live path and outer timer1 adapters while
closing these selected predecessors; do not restart comprehensive IRQ recovery.

# Staged payout debit timing — 17 October 2026

## NVRAM checkpoint

Mpu4NvramExecution stages native6E06/6E0D through return using source instruction
costs. Each RAM effect occurs at instruction completion. It preserves the original
signed0323 service-mode gate,002C software-guard save/restore,25 complement bytes,
checksum delta and temporary byte at native U-1. The CPU mask is independently
preserved;002C=1 does not make this routine IRQ-masked. Native S-frame residue is
caller-owned. This is translated selected code, not a general6809 interpreter.

Capture-PayoutNvramTiming.ps1 and Curate-PayoutNvramTiming.ps1 extend the collection
evidence conventions with24 synthetic masked-IRQ original-ROM cases: four signed
mode values, two guards and three input patterns. Exact instruction PCs, encodings,
start cycles, final cycle/U and RAM0000..077F match. This does not establish natural
IRQ delivery. A separate synthetic suspension/delta test changes0322 while the
routine is suspended and confirms the original delta survives, guard restores and
U scratch residue is correct. No captured timing drives execution.

Evidence: evidence/mpu4/collection/nvram-timing.json and its debugger commands.
Original ROM SHA1 is checked before curating each five-byte instruction context.
Native listings6E06/6E0D preserve labels/branches; new execution and observer files
link exact addresses to C#. Existing payout-data byte spans remain authoritative;
no lossless source/rebuild claim is made. Fresh Ghidra symbol/comment export access
has not been established; no essential discovery is left only there.

Reproduce with Capture-PayoutNvramTiming.ps1 using MameExecutable, RomDirectory and
fresh RunDirectory; curator takes RunDirectory/RomPath. Verification filter:
"Payout NVRAM". Raw capture is outside tracked files at %TEMP%/FruitMachineLab-
payout-nvram-231fb239b6d04bc2bc832aabeff8062e; pointer payout-nvram.txt.

Next: stage4CBE debit and post-display accounting, retaining an explicit76BF/VM
display boundary until its CPU ownership is recovered. No Live collection change
is claimed by this checkpoint. Headless build and both new verification groups pass.

## Debit wrapper and accounting checkpoint

AddersPayoutDebitExecution now stages4CBE subtraction (including indirect balance
loads/stores and borrow), the NVRAM child, and4CD1..4CF0 accounting/queue suffix.
57F7/57A9 unsigned24 additions,59A4 meter update,6FEC checksum/negative003A clear,
68E0 queued-byte wrap and7032 checksum all follow original instruction boundaries,
CPU masks and guard saves. End is before6858; the output writer is not duplicated.
All register save/restore effects needed by these selected instructions are retained;
native S-stack bytes remain caller-owned. No generic processor emulator is added.

76BF is an explicit ownership handoff: WaitingForDisplay stops CPU advancement.
ReturnFromDisplay requires balanced U and4CD1 and a monotonic caller clock. It
does not execute the display or supply a default duration. Live cannot use this
class as a complete timed payout until a real display/gateway owner is connected.

Capture-PayoutDebit.ps1 -InstructionTiming extends the prior32-case capture, with
native spans around the actual original76BF/A8F9 display. Curate-PayoutDebit.ps1
preserves the previous semantic matrix and exports debit-timing.json plus commands.
Every native PC/start cycle/encoding, display-entry cycle and final6858 cycle match.
The verifier executes the existing translated display between spans and uses its
recorded return cycle ONLY to isolate suffix timing. That cycle is not a runtime
pacing input or proof of gateway timing. Prefix RAM0000..06FF matches including U
scratch; display/final comparison retains prior exclusions00F0..00FF,05C0..05FF
and native S-stack, and separately checks persistent accounts07C9..07E7. No state
snapshot is injected between the spans. All four records, mode/display gates and
balance/accounting wrap retain coverage. Synthetic handoff tests reject unowned
advancement, unbalanced returns and masked IRQ suspension; unmasked suspension
shifts the deadline. Filter: "Payout debit".

The first timing experiment lost temporary debugger stops when instruction logging
resumed, reaching a masked output wait. It is EXCLUDED; its owned MAME process was
identified by full isolated run path and terminated. No other MAME session was
touched. Accepted capture uses permanent conditional display and output stops;
all32 cases exit normally. External pointers payout-debit-timing.txt and
payout-debit-timing-excluded.txt preserve the two directories. Existing native ROM
spans cover the new instructions; all observed encodings are checked against ROM.
Next:76BF/A8F9 incremental execution and native return ownership, then composition.

Validation at this checkpoint:283 full verification groups pass; headless build
has zero warnings/errors. No installations or configuration changes were needed.

## Native VM gateway checkpoint

Mpu4NativeVmGatewayExecution stages76BF entry/trampoline initialization,76EF save
and76F6 return. Native S-frame bytes, saved F2, caller register restoration and
temporary VM root stream76ED are modeled. Embedded word76ED is token76F4;
76F4 contains code pointer76F6. Neither word is decoded as native instructions.
RAM F8..FF receives exact7927..792E template only whenF8 is zero, preserving the
original nonzero check. The selected contract requires DP=0; other pages fail.

VM entry is FC and native return resumes at76F6. The owner must execute the VM,
root pop and FC/FE dispatch of76F4 before returning ownership. ReturnFromVm
checks the popped S frame and cursor; it deliberately permits VM results on U,
which the original native return does not restore. CPU mask remains independent
of F1. Nonzero F1 clears bit0 on entry and sets bit0 on exit (subject to the
original nonzero checks).080C is a characteriser hardware write, not RAM; an
explicit callback is mandatory on that route. Missing owner latches a fault.

Capture-/Curate-NativeVmGateway.ps1 export eight synthetic original-ROM cases
(initialized/uninitialized trampoline times four F1 values), executing a real
suppressed A8F9 between native spans. All native instructions/cycles, final
registers, entry RAM0000..07FF and after-VM RAM excluding only05C0..05FF match.
That exclusion is semantic VM U-stack scratch, not the gateway native S frames;
S-frame bytes are compared.080C watchpoint values/start times and modeled store
completion times match. VM return cycle is verification-only, not runtime pacing.
Synthetic tests cover paused native frames, rejected unpopped root and explicit
hardware failure. Filter: "Native VM gateway". Headless build and both groups pass.

Exact76BF..7706 and7927..792E bytes, pointer roles and five-byte observed contexts
are checked against the original ROM in native-vm-gateway.json. Existing annotated
Ghidra exports76BF/76C7/76EF/76F6 have been copied reproducibly from the preserved
prerequisite-pass/saved-functions directory into evidence/mpu4/native. These are
historical exports, not a fresh local Ghidra synchronization. Their partial/body
size imperfections remain; byte-checked ranges supply the instruction/data truth.
Original workspace is unchanged. External pointer native-vm-gateway.txt identifies
the accepted raw directory. No excluded gateway run was needed.

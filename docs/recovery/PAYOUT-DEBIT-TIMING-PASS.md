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

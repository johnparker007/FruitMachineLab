# Nudge outer award statistics

15 October 2026. Live now continues from AFF0 through the actual outer caller
and the award-statistics/scaled-counter updates into the actual cash-bank commit.
It stops at AF25 before combined-bank limit service. The selected award leaves
cash bank16, token bank0, pending0 and current win0. Collection and payout have
not executed. The Live diagnostic accounting line shows both bank balances.

## Natural reference

The existing physical TAKE/three-Nudge1 campaign reaches AFF0 without state
injection. A fresh narrow observer window saves entry RAM there and terminal RAM
at AF25. The process exits0 with no debugger expression errors. Its226 raw and
canonical dispatch observations match the headless VM exactly, with nine lamp
updates, zero sound commands and zero alpha bytes. Entry fields independently
match the previous nudge-tail terminal, excluding absolute CPU cycle. These are
separate successful windows, not a single full-logging capture.

The route is AFF0 → EDCF → EE2E/EE30 → EE74/EE78 → FC76 → AFF4 → AE3A.
AFF4 combines current/pending award and reads category B9. AE28 folds0306 into
the amount and clears it. The observed category is3 and amount0010. AE65 calls
native1622 through token833B. AE69 then selects ADCE; its normal-mode test reaches
ADDA with selector4 and amount0010, calling native151F. A second call at AEC2
uses selector0. The earlier assumption that AEC2 would be the first scaled
counter call was disproved by this trace. AE3A returns into AF2B/AF13; the selected
cash route adds16 to02FC and clears pending/current win with protected refreshes.

Verification checks VM stacks/frame state, protected2F0..322 accounting bytes,
pending/current win, exact lamp digest, statistics043A..0457 and accounting
07C9..07E7. The interactive
Live test also checks the combined lamp sequence through the previous windows,
reel positions, statistics, all seven flashes and actual Pause/Resume during
motor improvement, meter transfer, flashing and accounting execution. No recorded input rows are fed
into Live after its recovered entry state.

## Native1622 and166D

Static disassembly and a22-case isolated MAME matrix support the translation in
AddersAwardStatistics.cs. These experiments set PC/registers/memory explicitly
and mask IRQs; they are synthetic helper tests, not natural machine play.
The complete low RAM0000..06FF matches after each call. Native CPU S-stack
residue0700..07FF is excluded and selectors in this matrix avoid that region.

Gateway77AA pops Y=selector then X=amount: VM `( amount selector -- )`.
Native1622 increments global count043A, adds the unsigned16 amount to043D,
adds it to043D+6*low(selector), then increments043A+6*low(selector).
Native166D only updates the indexed pair. The fields are big-endian unsigned24
with wraparound through57A9. Signed-negative mode0323 suppresses writes through
57DB/57F7. Selector0 aliases global and indexed fields, intentionally updating
each twice under1622. High selector bytes are ignored. Tests include amounts
0,1,255,256,257,65535, modes00/7F/80/FF and seeded carry/wrap boundaries.
No artificial counter deduplication or mode normalization is applied.

## Scaled counters and accounting refresh

Native151F and6F57 now have a separate12-case isolated MAME matrix. Selector low
byte0..4 indexes nine-byte records at1462; the first word points to a three-byte
counter at07C9+3*selector. Native151F adds500*unsigned16 amount modulo24 bits.
Signed overflow of the final high-byte ADC clamps the counter to7FFFFF before
SWI3 alarm65. The matrix stops before that SWI3 and compares the clamped bytes;
the translation then stops explicitly. Invalid selector alarm64 also stops
explicitly before lookup, based on static bytes, rather than guessing SWI3 return.
The matrix covers all five selectors, high selector-byte truncation, amounts
0/1/16/255/256/65535, negative modes, carry/wrap and the overflow-clamp boundary.

6F57 refreshes15 complement bytes07D8..07E6 from07C9..07D7 and writes07E7 as
the8-bit sum of each complement minus1. Negative mode0323 suppresses this refresh,
but does not suppress151F's counter addition. Full low RAM0000..06FF and the
explicit31-byte accounting region match MAME; native S-stack residue is excluded.
The natural run independently checks both scaled updates and final bank bytes.

Token75A9/native75AB was misleadingly named keep-negative in two old listings.
Byte-checked native code normalizes the sign toFFFF/0000. Both listings now use
the existing verified vm_test_negative operation; the full natural VM digest
checks its two newly reached uses. No preservation of an arbitrary negative
operand is invented.

## Preservation and next work

Curate-NudgeEncodingCheckpoint.ps1 extends the existing checkpoint, adding18
VM spans and six aligned native disassembly exports; every listed token and
native instruction byte is checked against the SHA1-identified ROM. Selected
VM spans retain inline bytes and gaps verbatim. This is not a claim of a lossless
whole-ROM decode or complete relocation information. Curate-NudgeData.ps1 adds
the8492 mask/address record,1462 selector table,84C8 mask pairs and8510/FF34
option data needed by the selected accounting route.

This check exposed an old AC5F placeholder0000 in AC58.txt. The ROM bytes are
36 47 79 79 03; the listing now retains token3647 and explicitly identifies this
unexecuted hook region as unresolved. No hook implementation is invented.
Native151F selector table, signed overflow boundary and6F57 refresh are now
verified within the stated scope. Next continue AF25/AEF9 bank-limit service,
then AFF4's collect-input gate and actual collection/payout routing. The selected
16 units are committed to the cash bank; they are not a completed payout.

Fresh Ghidra metadata export remains unavailable: no live Ghidra API is exposed.
Existing symbols/comments exports remain preserved. The full-logging external
MAME crash described in the previous report remains unresolved; narrow successful
windows do not establish its cause or erase the failed-later prefix qualification.

## Reproduction

Use Capture-SkillCash.ps1 with the previous complete nudge-tail flag chain plus
`-NudgeAccounting -TailWindow -NoMotorItems`. Curate-BoardLink.ps1 uses that same
chain except NoMotorItems. Fresh temporary directories retain bulky raw captures.
Capture-AwardStatisticsMatrix.ps1 takes the saved entry RAM; its companion curator
rejects incomplete processes and debugger expression errors. Export disassembly
with `-NudgeCheckpoint -AccountingCheckpoint`, then pass its directory as both
DisassemblyDirectory and AccountingDirectory to the existing encoding curator,
retaining the previous StackRunDirectory for the lamp save-area watchpoint proof.
No installs, configuration changes, commits or pushes were performed.

Validation:142 headless verification groups and all eight WPF smoke modes,
with the existing installed SDK and isolated GUI output. Whole-machine startup,
credits, collection and hundreds of consecutive games remain future milestones.

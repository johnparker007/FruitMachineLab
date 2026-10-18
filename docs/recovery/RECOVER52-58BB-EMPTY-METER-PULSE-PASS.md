# Recover52 58BB empty meter-pulse path

Scope: existing capture41 evidence only. No new capture, state injection, Live
change or IRQ-cadence claim. The accepted baseline remains `e24cf73` with 409
groups; this pass adds two groups (411 total).

## Trace-backed boundary

Capture41 records the original `FEC6 BD 58 BB` call at cycle
`0x3C59C2B`, and the `FEC9` return at `0x3C59CEE`, `S=078D`, `U=0672`,
`A=05 B=0B X=0366 Y=0000 DP=00`. The span is exactly 195 cycles. The same
capture's queue/stop snapshots have `719B=00`, `0039=00`, `003A=00` and
`035E..0369` all zero, so the scanned meter queue is empty.

Trace proof is limited to this call/return pair and the zero queue state. The
instruction order and cycle split below are static deductions from the original
ROM, confirmed by the captured 195-cycle endpoint.

## Original helper path

`58BB` reads `719B` bit 2, `003A`, `0039`, then the six words at
`035E..0369`. With `719B` bit 2 clear, `003A=00`, `0039=00` and all six words
zero, it takes only these branches:

- `58C0 BNE` not taken; `58C4 BMI` not taken; `58C8 BNE` not taken.
- First scan `0366/0368`: two zero words, counter `09 -> 0B`.
- Second scan `035E/0360/0362/0364`: four zero words, counter `01 -> 05`.
- `58EE RTS` returns `A=05`, `B` preserved, `X=0366`, `Y=00`.

The path writes no RAM and calls no helper. The only memory effect is the
`FEC6` JSR push of return word `FEC9` at `078B/078C`, consumed by `58EE RTS`.
Source timing is `8` cycles for `BD58BB` plus `187` for the empty scan, total
`195`, matching the capture. `CC` and `DP` are not modelled; only captured
registers are returned.

Unsupported without new evidence: the `58EF` clear-queue branch (`719B` bit 2),
the `58FD` pulse path (nonzero queue word), the `590F/5924` active-count path
(`0039` nonzero), the `6FEC` call, and `5924`'s `0E02/0E03/0F02/2040/FF30/SWI`
hardware behaviour. The component rejects each before mutation.

## Implementation and verification

- `src/FruitMachineLab.Adders/AddersMeterPulseExecution.cs`: exact original
  `58BB` bytes, preflight, captured empty-scan instruction effects and cycle
  split. Unsupported branches throw before any RAM write.
- `src/FruitMachineLab.Adders/AddersMeterPulseVerification.cs`: checks the
  capture41 fixture/debug/ROM provenance, captured call-cycle event, FEC9
  anchor, entry/return registers, stack word, no unexpected RAM writes and the
  `8+187=195` split.
- `evidence/mpu4/collection/meter-pulse-58bb-empty.json`: original `58BB` and
  `FEC6` ROM bytes, capture provenance, entry/return anchors and the zero queue
  state. This curates existing capture41 data; it is not a new capture.
- `tests/FruitMachineLab.Verification/Program.cs`: positive group plus seven
  isolated negatives (`disabled`, `timer`, `active`, `pulse`, `rom`, `call`,
  `stack`) that must reject with memory unchanged.

Actual commands:

- `dotnet build FruitMachineLab.Headless.sln -v:minimal` -> exit `0`, 0
  warnings, 0 errors.
- Focused `... -- "C:\projects\GitRepos\FruitMachineLab" "Meter"` -> exit `0`,
  3 matching groups passed.
- Full headless suite -> exit `0`, 411 groups passed.
- `pwsh -NoProfile -File tools/Update-CuratedManifest.ps1` -> exit `0`.
- `pwsh -NoProfile -File tools/Update-CuratedManifest.ps1 -Verify` -> exit `0`,
  1,318 entries verified.

## Limits and next task

This proves one empty-queue `58BB` helper path, not the complete IRQ, the `6B4D`
continuation, timer1 cadence, pulse/active meter behaviour, Live integration or
audio. Do not infer `6FEC` or `5924` semantics from this empty path.

Next safe task: recover the captured `FEC3 -> 6B4D -> FEC6` interval with an
instruction/PC trace and the existing `0780..078F` write watchpoint, to identify
which `6B4D` branches reach the `6B6A` `5330` call and the `FEC6` return. Do not
extend `58BB` pulse branches from net deltas or this empty scan.

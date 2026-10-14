# Implementation and evidence boundaries

## Completed in this batch

- Imported all top-level recovery reports and the current 528 decoded VM body listings.
- Imported selected board/lamp semantic maps, branch prerequisites, arithmetic checks
  and original replay verification summaries.
- Extracted one Skill Cash interval from vm-batch-policy7-a/debug.log, beginning at
  C721 and ending at C71D. The original summary reports policy7 a/b byte-identical;
  this batch has not rerun MAME. Both original debug logs have now been independently
  SHA256-compared and the selected intervals compared exactly. Source line ranges,
  hashes and launch/input metadata accompany the excerpt.
- Implemented explicit 16-bit arithmetic, Forth flags, big-endian cells, a decoded
  script interpreter subset, frame-address operations and fail-fast unknown helpers.
- Executed recovered C637 initialization and 9F6A award normalization. Translated
  C757..C75F stage reduction and C70E pending-word store.
- WPF consumes the same diagnostic events produced by the headless replay.

## What the replay proves

The recorded helper returns are 3, 2 and 1. The reconstructed stage calculation uses
timer values 25, 20 and 15 and signed minimum to reduce level 6 to 1. The recorded
table-read address is 75BE. The recovered ROM table now supplies 10, checked against
that recorded read; normalization leaves 10; pending BA is
stored as big-endian 000A. Intermediate stack observations independently check
previous levels and computed addresses. The trace-derived selections and table value
are external observations, not C# predictions. The award-table read is now a C#
prediction from curated ROM data. The input-condition branch in 9F6A
is not captured by this debugger range; both condition outcomes are evaluated and
must yield the same result. For award 10 both yield 10. An input-dependent outcome
fails with an explicit request for additional evidence.

## Remaining before the first complete executable milestone

The selection loop C699, enabled option override C646, chance lookup C617,
frame/loop stack allocation and return semantics, interrupts/timer scheduler,
lamp/sound streams, NVRAM refresh 6E06 and award animation AF93 remain untranslated.
Native RNG and percentage arithmetic now execute and match three focused MAME calls.
C676 terminal gating matches 1,202 calls with an explicit observed chance boundary;
its compensation/chance dependency C66A is not yet independently implemented.
The current replay does not run C721 end to end and does not validate final bank,
current-win, physical payout or UI animation. Unsupported interpreter operations throw.
No synthetic selection/timer semantics are presented as ROM behaviour.

The focused replay has now been captured, and state.csv, feature-state.csv,
input-levels.csv and final RAM match the original campaign exactly. The expanded
report is [SKILL-CASH-RUNTIME-PASS.md](docs/recovery/SKILL-CASH-RUNTIME-PASS.md).
Next: recover the compensation calculation and frame/selection scheduling before
replacing more observed boundaries with independently executing helpers.

## Provenance

Original workspace is preserved at
`C:\Users\John\Documents\Codex\2026-10-13\help-me-set-up-a-local\outputs\mpu4`.
The baseline ROM SHA1 is 402d1518bb78fdc489b06c2aabc771e5ce151847; no ROM binaries,
NVRAM dumps, Ghidra projects or full campaign logs are copied into the repository.
Reports include static deductions, hypotheses and synthetic fault experiments:
their original qualifications remain authoritative. Imported historical reports
describe earlier inventories; prerequisite-pass is the latest inventory baseline.

`evidence/curated-manifest.json` records byte counts and SHA256 for imported artifacts.
`tools/Extract-SkillCashEvidence.ps1` reproduces interval extraction and a/b comparison
without changing the source workspace. Selected native assembly exports accompany
the interpreter translations; decompiler output remains qualified by its warnings.

The decoded listings contain recovered token/data values and are curated analysis
artifacts. Absolute paths in copied launch metadata describe the original run and
must be resolved explicitly before reuse; they are not portable launch scripts.

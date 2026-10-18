# IRQ 6B4D zero-state component pass

## Scope

This pass implements only the certified zero-state instruction component selected by
the accepted natural occurrence:

`FEC3 JSR 6B4D -> 6B4D zero branch -> 6B4D JSR 5330 -> 5330 73=0 -> 53A9 -> 6B6A
-> 6B7D -> 51B1 -> 5282 PULS -> FEC6`

The accepted run remains `artifacts/deepseek/capture-53/natural-irq-6b4d-valid`.
No new MAME run was made. The rejected first run remains separate and is not used.

## Evidence and fixture

Tracked fixture: `evidence/mpu4/collection/irq-6b4d-zero-state.json`.

It contains, from the certified raw occurrence:

- actual ROM bytes for `FEC3`, `6B4D..6B80`, `5330..5333`, `53A9..53AD`,
  `51B1..51C9`, `5282..5283`, and the non-executed `FEC6` boundary instruction;
- full 2KB entry RAM from `fec3.bin` and full 2KB return RAM from `fec6.bin`;
- all 32 trace boundaries with PC, cycle, A, B, X, Y, U, S and CC;
- the five certified RAM deltas (`0780`, `0781`, `0782`, `0783`, `0785`);
- observed reads (`83`, `02`, byte/word `323`, `84`, `85`, `7C`, `71`, `72`,
  byte `3A5`, word `3A6`, word `7A`, `73`, `7D`, `80`, `3DA`, `38F`, `719B`);
- entry/FC external PIA, message and `719B` observations, marked read-only;
- ROM/MAME/input/replay/argument/debugger/raw-2KB provenance hashes;
- the rejected run's `S=078D` entry, its `078C/078B` taps, missing cycle columns,
  absent `E5330`, and present `C5330`, in a separate `rejectedRun` object.

## Implementation

`AddersIrq6B4DZeroStateExecution` is a single-machine, path-specific component.
It validates the captured frame and branch reads before any write, then executes
the actual ROM encodings with source-correct `JSR`, `RTS`, `PSHS`, `PULS`, short
and long branches, loads, stores, compares, clear/test flags and stack order.

Timing is taken from `M6809InstructionTiming.Decode`, not hardcoded labels. Trace
labels are diagnostic only; execution is driven by actual opcode bytes and PC. The
32 boundary rows are compared against execution, not copied from the trace.
`CC` N/Z/V/C are computed from the executed instructions; E/F/I/H are preserved
from the captured entry, and `DP` is fixed at `00` by the captured direct reads. The
complete 2KB return image and the matched `S=0786` return word `FEC6` are checked.
The total span is 170 cycles: 8 for `FEC3 JSR` plus 162 for the traced path.

Only the captured zero-state values are accepted. Nonzero `73`, any nonzero
`71`/`72`, nonzero byte `3A5`, the `6B5A` fall-through, the `51CA` path, a changed
frame, changed opcodes/ROM, and the `5330` nonzero `71`/`72`/word-`7A` path fail
before mutation. There is no generic CPU, no whole-IRQ claim, no autonomous IRQ
cadence, no Live integration, no audio claim and no nonzero `5330` semantics.

## Verification

`AddersIrq6B4DZeroStateVerification.Verify` seeds one `Machine`, executes once and
compares every boundary and the full 2KB return image. `Rejects` covers branch,
frame, opcode, missing ROM, wrong return word and changed boundary rows.

Commands and exits:

- `dotnet build FruitMachineLab.Headless.sln -v:q` -> exit 0.
- `dotnet run --project tests/FruitMachineLab.Verification/FruitMachineLab.Verification.csproj -c Debug --no-build -- C:\projects\GitRepos\FruitMachineLab "IRQ 6B4D"` -> 2 groups, exit 0.
- Full suite -> 413 groups passed (the original 411 plus these 2), exit 0.

## Limits / next

The `FEC6 JSR 58BB` boundary is compared but not executed. The next task should
recover the nonzero `5330` branch only from new certified evidence, not from the
trace labels and not by extrapolating this zero-state component.

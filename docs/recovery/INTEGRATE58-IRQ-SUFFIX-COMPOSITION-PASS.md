# Integrate58 IRQ suffix composition pass

## Scope

Bounded same-machine composition of the accepted capture57 suffix. One `Machine`
is seeded only from the captured `FEC3` full 2 KB and captured `FEC3` registers.
It executes `FEC3 JSR 6B4D`, `FEC6 JSR 58BB`, `FEC9 JSR 5CD0`, the native `5CD0`
service and `FECC CLR <$2C`, then stops at `FECE`. No intermediate snapshot seeds
or reseeds execution, no return frame is reloaded, no host RAM is patched and no
IRQ cadence is invented.

The initial captured `S` is `078D`, not the earlier 6B4D component capture
`0786`. `AddersIrq6B4DZeroStateExecution` now accepts an explicit traced entry
`S`; the integration passes the captured `FEC3` value. The guard was not simply
removed: the wrong-frame control still uses `0786` and is rejected by the trace
comparison. `58BB` uses the captured empty queue (`719B` bit 2 clear, `0039=00`,
`003A=00`, six zero words). `5CD0` uses the observed zero `44` guard, so it is
the actual `5CD4..5D38` service body, not a synthesized active path.

## Evidence

Tracked composition fixture:
`evidence/mpu4/collection/irq-suffix-capture57-composition.json`
(`859E96D303DEBC044B529C60327427FB3D92EB9D58FA3EE20A716D27330F4EFA`).
It pins the source capture57 fixture
(`B7029FD86E2D93154E1EA907E24A589CE1C1A8DE2BD17CB81016BD4ADE6A8545`),
actual ROM regions, the captured `FEC3` 2 KB hash and full 2 KB images for
`FEC6`, `FEC9`, `5CD0`, `FECC` and `FECE`. Those images are comparison targets
only.

Actual semantics used:

- `FEC3`/`FEC6`/`FEC9` `JSR` push their real return words.
- `58BB` runs only the empty-meter scan and its actual `JSR`/`RTS` frame.
- `5CD0` runs the existing `AddersNativeSound` service plan.
- The `5D3A RTS` consumes the `FECC` continuation word.
- `FECC CLR <$2C` writes `0x2C=0`, costs 6 cycles and clears `N/Z/V/C`, matching
  the captured `FECE` condition codes.

The capture57 instruction trace is compared directly. `6B4D` and `58BB` generate
full `A/B/X/Y/U/S/CC/PC/cycle` boundaries; collapsed MAME loop rows are matched
without dropping the generated instructions. Native `5CD0` has no CPU register
file, so its captured `A/B/X/Y/U/CC` rows are explicit partial-state anchors:
the executed plan is matched on full 2 KB, `PC`, opcode and cycle, and no native
flags are invented. Cycle splits are exact: `6B4D` 8+162=170, `58BB` 8+187=195,
`5CD0` 1248, `FEC9` JSR 8, `FECC` 6 and total `FEC3..FECE` 1627.

Capture57 attempt 2 is the accepted run. Capture56 attempt 1 remains preserved
and explicitly incomplete: its `FECC` guard used `w@(s-2)==FEC6`, which was the
wrong word; it is not reused, relaxed or treated as evidence for the corrected
continuation. No third run was made on this boundary.

## Implementation

- `src/FruitMachineLab.Adders/AddersIrqSuffixExecution.cs` composes the three
  existing components and applies the actual `FEC9` push, `RTS` pop and `FECC`
  clear effects.
- `src/FruitMachineLab.Adders/AddersIrqSuffixVerification.cs` verifies source
  and ROM hashes, the initial `FEC3` pin, the capture57 trace, all five
  intermediate 2 KB anchors, exact supported cycles and ROM preservation.
- `src/FruitMachineLab.Adders/AddersMeterPulseExecution.cs` now exposes traced
  register/CC/stack boundaries while retaining its original public result.
- `src/FruitMachineLab.Adders/AddersIrq6B4DZeroStateExecution.cs` accepts the
  explicit traced entry `S` without weakening the existing default capture
  guard.

## Negative controls

The verifier rejects a wrong frame, wrong branch (`0x73` nonzero), changed ROM,
wrong `FEC9` continuation, a duplicate service owner, tampered intermediate
`FEC6` 2 KB, reseeding `FEC3` with the `FEC6` image and a tampered trace row at
their intended rule. In-memory negatives are checked for no mutation before
rejection.

## Commands and exits

- `dotnet build FruitMachineLab.Headless.sln -v:minimal` -> exit 0, 0 warnings,
  0 errors.
- Focused `... -- "C:\projects\GitRepos\FruitMachineLab" "IRQ capture57"` ->
  exit 0, 2 groups.
- Full headless suite -> exit 0, **415 groups** (the 413 baseline plus two).
- Manifest entries were recomputed from actual file bytes; prior entries were
  retained.

## Limits and next task

One capture57 occurrence only. There is no nested IRQ after `FECE`, no autonomous
timer cadence, no `58BB` active/pulse path, no nonzero `6B4D`/`5330` branch, no
whole-IRQ or Live integration and no audio or hardware claim. Native `5CD0`
register/flag coverage remains explicitly partial because the adapter has no CPU
register file. The next task should extend only a separately captured branch or
foreground/IRQ ownership boundary; do not infer unobserved semantics from this
zero-guard suffix.

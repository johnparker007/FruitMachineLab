# Recover44 foreground 7159 wait/caller boundary

## Outcome

Recovered and executed the smallest actual foreground boundary behind the
`5A14` start-tone path: `5A05 LDB 1,S`; `5A07 JSR 7159`; then
`7159/718A/7164` through the return to `5A0A`. The new instruction execution is
source-derived from the ROM assembly and the existing capture43 trace. No new
capture was taken, no Live/IRQ cadence was changed, and the captured `360`
finish budget was not replaced or fitted.

## Static assembly (evidence/mpu4/native/*.json)

- `5A05 E6 61 LDB 1,S` (5 cycles) loads the B saved by the `59FF` PSHS A,B
  frame. The natural caller supplies `B=02`; it is not inferred from the
  `7159` name.
- `5A07 BD 71 59 JSR 7159` (8 cycles) pushes return `5A0A`; entry state from
  capture43 is `A=91 B=02 X=80A6 Y=FC4F U=0672 DP=00 CC=C0 S=07A0`.
- `7159 8D 2F BSR 718A`; `715B 34 06 PSHS A,B`; loop
  `715D 8D 05 BSR 7164`; `715F 5A DECB`; `7160 26 FB BNE 715D`;
  `7162 35 86 PULS A,B,PC`.
- `718A 34 04 PSHS B`; `F6 71 9B LDB 719B`; `C5 80 BITB #80`;
  `26 02 BNE`; `35 84 PULS B,PC`. Only the enabled (`719B` bit80 clear)
  path is executed. The set-bit path changes B to `719B` and is not
  independently recovered; it fails closed before any stack write.
- `7164 34 04 PSHS B`; `C6 28 LDB #28`; `86 54 LDA #54`;
  inner `4A DECA` / `26 FD BNE`, outer `5A DECB` / `26 F8 BNE`;
  `35 84 PULS B,PC`.

Cycle costs from `M6809InstructionTiming`: one `7164` pass is 17096 cycles; the
enabled `718A` path is 24 cycles plus its 7-cycle BSR; `RepeatCycles(2)` is
34263; `5A05` plus JSR is 13, so the natural wait is 34276 cycles. The ROM's
byte decrement makes `B=0` repeat 256 times; existing 20-case MAME calibration
continues to verify that behaviour.

Register/stack contract: `7159` preserves A, B, X, Y, U and DP and balances S.
`7164` clobbers A internally and preserves B with PSHS/PULS; `7159` restores A
and B from its own frame. The deepest live frame is seven bytes below entry S:
JSR `7159` (2), BSR `718A` (2) and PSHS B (1), then after that temporary frame
is popped, PSHS A,B (2), BSR `7164` (2) and PSHS B (1). The execution preflight
therefore requires `S>=7` and rejects `S<7` before any memory write; `S=0xFFFF`
is valid because `5A05 LDB 1,S` wraps to address `0x0000` and the deepest write
is `0xFFF8`. On return to `5A0A`, CC is `C4` (Z=1, N=0, V=0;
C/H are preserved from entry). The capture43 stack writes from `5A0A`, `715B`,
`718C`, `715D`, `715F` and `7166` match exactly. The interrupted `716A` state
(`S=0799 A=47 B=27`) is reached at the captured point; `M6809IrqEntry` with the
captured registers then reproduces the complete `0790..079F` window. The
remaining capture tap/IRQ-cycle sub-cycle offsets are host/debugger timing, not
part of the recovered instruction costs.

## What existing adapters omit

- `AddersToneSetupTiming` covers the `80A4/776F` bridge plus
  `5A14/59FF/59D9` through the `5C18` call and the `59E9` PULS. It stops before
  `5A05/5A07/7159`; its queue cost is clone-only and does not apply native
  task effects.
- `AddersTimedTone` only writes `004D` and queues/cancels the logical
  scheduler. It does not execute the wait, stack/registers, or native cancel.
- `SkillCashLiveSession` uses `Mpu4CalibratedDelay` for the wait cycles and
  `CapturedInterruptOccupancy` for the observed IRQ envelopes. It does not
  execute the foreground stack/registers. Its finish still uses the captured
  `toneFinishCycles` (`360` CPU plus observed envelope), explicitly unchanged.
- `AddersNativeSound` has no `7159` foreground path.

## Implementation and verification

New `src/FruitMachineLab.Runtime/Mpu4CalibratedDelayExecution.cs` executes the
`5A05/5A07/7159/718A/7164` instruction stream, records exact stack writes and
register/cycle state, checks balanced return addresses, and fails closed before
any mutation on `S<7` or the disabled gate. It is a verification/execution component, not
a Live cadence change. Two new checks in `tests/FruitMachineLab.Verification/
Program.cs` verify the curated native assembly, capture43 full stack, register
preservation, repeat counts `0/1/2/3`, the `S=6` rejection versus `S=7`
acceptance, the `S=0xFFFF` wrapped `1,S` read, and unchanged full memory on the
rejected paths.

Actual commands and exits:

- `dotnet build FruitMachineLab.Headless.sln -v:minimal` -> exit 0, zero
  warnings/errors.
- `dotnet run --project tests/... -- <root> "Foreground7159"` -> exit 0,
  2 groups passed.
- Full `dotnet run --project tests/... -- <root>` -> exit 0, 403 groups passed
  (401 baseline unchanged plus these 2).

## Limits and next safe task

The disabled `719B` bit80 path, `5A0A..5A12` finish
(`LDX #59EB`, JSR `5C7A`, `CLR 4D`, PULS), and `5C7A/5CB5/5E2C` cancel are not
executed here. The captured `360` finish and IRQ envelopes remain explicit
oracles; no autonomous IRQ acceptance or audio claim is made.

Next safe task: execute the `5A0A..5A12` finish using the existing
`AddersSoundCancelPlan`/`5C7A` path and source-derived costs, only after native
sound state ownership is real; compare the same machine, not a fitted 360
budget.

# Recover46 foreground finish / native cancel pass

## Recover47 correction

Recover46 incorrectly treated the `5C7A` native cancel as if it preserved CC.
`AddersSoundCancelPlan` has no CPU flag model, so every CC bit after the native
cancel is explicitly unknown. Recover47 also fixes `CLR <4D` to clear C as well
as N/Z/V (`CC=(CC&~0F)|04`), and removes the hardcoded captured-looking `C4`
entry from the fixture test. The result now exposes separate known-mask flags:
LDX `#59EB` has source-known N=0/Z=0/V=0 (C/H/I/F/E preserved), native cancel
flags are all unknown, and final `CLR` has source-known N=0/Z=1/V=0/C=0
regardless of entry C. DP is source-preserved by the cancel/release plans but is
not retained by capture36, so DP/CC are not compared as captured CPU state.
Minimum stack 16 is retained with the exact live-depth chain documented in the
execution source.

## Outcome

Recovered the bounded foreground tail `5A0A..5A12` on the selected Start-tone
path and executed it through one existing `AddersNativeSound` owner on the same
`Machine`. The adapter uses the existing native `5C7A` instruction plan; it does
not clone the machine, reseed after entry, create a second owner, or run the
logical `Mpu4ChoiceStreamScheduler`.

## Evidence classes

- Static ROM: `5A0A 8E59EB` (`LDX #59EB`), `5A0D BD5C7A` (`JSR 5C7A`),
  `5A10 0F4D` (`CLR <4D`), `5A12 3586` (`PULS A,B,PC`), and the selected
  `5C7A/5CB5/5E2C/60AB/60C8` cancel/release path.
- Capture36 declared checkpoints: `queue.bin` at `5C18`, `cancel.bin` at
  `5C7A`, `return5a10.bin` at `5A10`, and `return5a1c.bin` at `5A1C`. The
  `5A10/5A1C` frames are full 2 KB saves. The `5A0A` frame itself was not saved.
- Captured 5A0A registers: `S=07A0 X=80A6 Y=FC4F U=0672 A=91 B=02`.
  The fixture does not retain DP or CC for any frame, so neither is asserted as
  captured. `LDX #59EB` replaces X with `59EB` and sets N=0/Z=0/V=0 while
  preserving C/H/I/F/E. The native cancel restores A/B from the actual 5C95
  PULS, restores X/Y there and U via the 5E6B PULS, and balances S; its CC is
  **unknown** because the plan has no flag model. `CLR <4D` sets N=0/Z=1/V=0
  and **C=0**, leaving H/I/F/E untouched (still unknown after the cancel).
  `PULS` changes no CC. Final known flags are therefore N/Z/V/C only.
- Cycle spans: `5A0A->5C7A=11`, `5C7A->5A10=308`, `5A10->5A1C=15`, total 334.
  These are the same as the captured event cycles and the decoded instruction
  costs (`3+8`, native cancel, `6+9`), not a fitted 360-cycle finish.

## Explicit 5A0A adapter

The 5A0A memory frame is not independently saved. The adapter therefore uses
`cancel.bin` once as the initial 2 KB state, with the captured 5A0A registers.
At 5A0A the only bytes that differ from the 5C7A frame are the two dead bytes at
`079E/079F`; the adapter writes exactly the captured JSR return word `5A10`
there. No later reseed occurs.

Preflight rejects before mutation: a different owner machine, an active native
service, pause/fault, a cycle that moves backwards, `S<16`, `719B` bit 80, a
wrong `5A1C` return word, or an active list without a `59EB` root (including a
cyclic/invalid task list).

`AddersToneFinishExecution.Execute` costs `LDX`, performs the JSR push, calls
`AddersNativeSound.BeginCall(0x5C7A, S-2, X=59EB, Y, U, A, B, ...)`, advances
only the native owner, records the 5A10 memory image, then executes `CLR 4D`
and `PULS A,B,PC` with the actual stack words. It returns only captured/source
registers (Cycle, PC, S, X, Y, U, A, B) plus explicit known-mask flags and the
5A10 2 KB image. It does not return a full CPU state containing DP/CC.

## What this proves

- One same-machine owner executes the foreground cancel and leaves
  `0047=0000`, `0049=01A0`, `004C=00`, `004D=00`.
- The generated 5A10 state and full 2 KB equal `return5a10.bin`; the generated
  5A1C state and full 2 KB equal `return5a1c.bin`.
- Registers, stack, continuation and cycle spans match the capture36 cancel
  boundary.
- Flag claims are partial and explicit: LDX N/Z/V known, native-cancel CC wholly
  unknown, final CLR N/Z/V/C known with C=0. Source controls prove C=1, C=0 and
  all-bits entry CC produce the same known final condition bits.
- The 16-byte minimum is exactly the JSR5C7A/PSHS6/5C90 BSR5E2C/PSHS U/
  5E3E BSR60AB/PSHS X live-depth chain; the 5C81 BSR unwinds before it.
- It does not claim queue/service continuity, the full 25-service lifecycle,
  timer1/FEC9 cadence, autonomous IRQ acceptance, audio, or Live integration.

## Negative controls

Stage-specific controls reject: `stack` before mutation, `return` before
mutation, `gate` before mutation, `ownership` (no 59EB root) before mutation,
`owner` (different machine) before mutation, `missingROM` at region load,
`snapshot` at the 5A10 full-image comparison, `cycle` at the 5A10 cycle
comparison, and `final` at the 5A1C full-image comparison. They use the semantic
fixture path, not a raw-hash short circuit.

## Commands and exits

- `dotnet build FruitMachineLab.Headless.sln -v:minimal` -> exit 0, 0 warnings,
  0 errors.
- `dotnet run --project tests/FruitMachineLab.Verification/FruitMachineLab.Verification.csproj --no-build -- C:\projects\GitRepos\FruitMachineLab "Foreground5A0A"` -> exit 0, 3 groups passed.
- Full suite -> exit 0, 406 groups passed (405 Recover46 baseline plus the new flag/stack control).
- `tools/Update-CuratedManifest.ps1 -Verify` -> all curated entries verified.

## Limits and next task

The 5A0A frame is reconstructed from the captured 5C7A frame only for the two
dead JSR return bytes; no other byte is invented. `5A0A` before the JSR remains
without a full independent save. The 25-service window, the `FC4D/5A14/59FF/
59D9` wrapper ownership and any autonomous timer/IRQ cadence remain outside this
slice.

Next safe task: attribute the remaining `FC4D/5A14/59FF/59D9` foreground and
inter-service deltas, or extend the finish adapter only when a later captured
full 5A0A frame or continuous owner boundary exists.

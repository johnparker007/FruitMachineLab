# Timer1 scheduler call certification

Scope: gate 1 of the revised roadmap. This certifies only the original `FEC9`
wrapper `JSR $5CD0 -> FECC CLR $2C -> FECE` and the optional
`AddersNativeSound` return-address parameter. It does not establish timer1
cadence, IRQ ownership, `6B4D`/`58BB`, Live integration or audio synthesis.

## Source contract

Original A6L ROM SHA1 `402d1518bb78fdc489b06c2aabc771e5ce151847`:

- `FEC9: BD 5C D0` (`JSR $5CD0`). The JSR continuation is `FEC9 + 3 = FECC`.
- `FECC: 0F 2C` (`CLR $2C`).
- `FECE: 20 38` (`BRA`); the bounded execution stops at `FECE`.

`AddersTimer1SchedulerCallExecution` now fixes that continuation and rejects a
supplied target other than `FECC`. The optional `AddersNativeSound` parameter
still defaults to `4C34`, so existing callers are unchanged.

## Synthetic original-ROM capture

Fresh isolated MAME 0.281 run:

- executable SHA256 `0fce5a88df4f9d9b1fbf1405812c00848036e615993780978d967da34204cb7a`
- ROM directory `E:\Arcade\MAME0266\roms`, original `m4addr` zip
- fresh absent NVRAM, isolated cfg/inp/snap/comment/state/diff directories
- masked IRQ, fresh 2 KB RAM, no user input

Captured initial state for both cases (recorded before execution):
`PC=FEC9 S=0700 U=0600 X=8784 Y=01A0 DP=00 CC=50`.

| case | initial head/free | instructions | start/end cycle | end |
| --- | --- | --- | --- | --- |
| empty | `0047=0000` | 12 | 4/66 | `FECE`, `S=0700`, `2C=00` |
| queued `8784` | `0047=01A0`, `0049=01C5` | 652 | 66/3161 | `FECE`, `S=0700`, `2C=00` |

The curated fixture contains full 2 KB before/after RAM, every observed PC,
five-byte ROM context, start and end cycles, and the required ROM regions:

- `FEC9` wrapper bytes (8 bytes)
- `5D38` decrement and `5D3A` RTS (6 bytes)
- `5963` sound dispatch table through `5C17` (693 bytes)
- `8739` sound stream through `879E` (102 bytes)

The verification seeds from the captured before state (`S=0700`), never the
expected end state. It derives `FECC` from the captured `FEC9` source bytes and
compares every instruction address, encoding prefix, start/end cycle, the frame
return word, balanced stack, `2C` clear and the complete 2 KB RAM image.

## Fixture audit and corrections

The first bounded capture used `0049=01A0`, the same record as the queued head.
That made the free allocator return the parent task and is not a valid queued
pool state. The original allocator and existing sound captures use
`0049=01C5`, the next six-record pool entry. The final capture uses that state.

The first capture scripts also omitted six dynamic note cache call sites
(`5D63`, `5D77`, `5D8B`, `5DC5`, `5DCC`, `5DD5`) and the shared
`AddersYmCachedWritePlan` instructions. Both omissions were corrected before
the final capture. The earlier raw captures remain under the untracked
`artifacts/deepseek/restart-22` directory for audit; they are not curated.

## Natural comparison

`scheduler-a` and `scheduler-b` are byte-identical raw traces from cold original
runs: entry `5CD2`, `S=07B4`, empty `HEAD=0000`, `TICKS=0000`; return
`FECC`, `S=07B6`, `TICKS=0001`. They prove only the observed empty-list return.
No cadence or outer timer claim is made from them.

## Negative controls

The verification rejects:

- a missing required ROM region (including the dispatch table)
- a corrupted `8739` stream byte or dispatch entry
- a wrong top-level return contract and a wrong supplied constructor target
  (without mutating memory)

## Evidence classes

- Static/traced: ROM bytes and wrapper/table/stream regions above.
- Natural: `scheduler-a`/`scheduler-b` empty return only.
- Synthetic original-ROM: empty and `queued8784` FEC9 captures; masked IRQ.
- Hypothesis: none installed. No timer cadence or native sound ownership.

## Limits

- The synthetic cases enter directly at `FEC9`; the upstream timer1 caller,
  `6B4D` and `58BB` remain explicit boundaries.
- `DP`/`CC` are recorded but the translated plans do not model CPU flags.
- Instruction end cycles are the next captured counter boundary; all executed
  plan instructions were breakpointed in the final capture.
- The optional `AddersNativeSound` continuation is retained, but the FEC9
  wrapper invokes the existing `5CD0` plan directly. Gate 2 still needs a real
  headless native tone owner.

## Reproduction

```powershell
dotnet build FruitMachineLab.Headless.sln --no-restore
powershell -NoProfile -File tools/Capture-Timer1SchedulerCall.ps1 `
  -MameExecutable E:\Arcade\MAME0266\mame281.exe `
  -RomDirectory E:\Arcade\MAME0266\roms `
  -RunDirectory <fresh>
powershell -NoProfile -File tools/Curate-Timer1SchedulerCall.ps1 `
  -RunDirectory <fresh> `
  -RomPath <original-a6ls.p1> `
  -NaturalRunsDirectory <runs containing scheduler-a and scheduler-b>
dotnet run --project tests/FruitMachineLab.Verification --no-build -- . 'Timer1 scheduler'
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .
```

Final focused result: 5 groups. Final full headless result: 389 groups, zero
failures. ROMs, raw captures and MAME settings remain untracked and unchanged.

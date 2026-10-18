# Bounded natural 9A64 memory effects - il-9a64-memory-final-23

Status: bounded natural observation on the original image plus an independent
static 6809 contract. This is not a 9A64 edit, extension, linker, native-executor,
gameplay-completeness or hardware-compatibility claim.

Task started from accepted `main`
`1f334cf13b7d077f565c9a4d26d9f54778604d24`. The accepted paused 9A64 session and
the previous natural runs were preserved.

The preceding task 22 memory run is preserved at
`artifacts/deepseek/il-9a64-memory-proof-22/run-01/`. It used
`-debugger windows -video none` and remains a valid three-OR trace, but it is not
described as having used the final frontend. The previous natural branch run did
reach the zero path, but it did not capture `00A0/00A1`, so it is not
retroactively labelled as a memory proof.

## Result

One fresh-boot original-ROM run on the final observer and launcher naturally
entered the `7667` OR handler three times and observed the actual `STD` effect at
the bounded word `00A0/00A1`. The zero path and the `7673` clear handler were not
naturally reached in this run, so no natural clear effect is claimed. The clear
contract remains static ROM evidence only. This run verifies the changed
frontend; it was not a rerun to chase the clear path.

| Datum | Value |
| --- | --- |
| ROM | 65536 bytes, SHA1 `402D1518BB78FDC489B06C2AABC771E5CE151847`, SHA256 `EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C` |
| MAME | 0.281, SHA256 `0fce5a88df4f9d9b1fbf1405812c00848036e615993780978d967da34204cb7a` |
| Replay | `evidence/mpu4/skill-cash/actions.csv`, SHA256 `4a051da15264842697879eff396b34a789f5d80623f9a2e749c244e6a80e721d` |
| Source map | SHA256 `8d9c9ddc58373e1ffdd221590a75babc1fb7bf3f497bfca587dbac84981df766` |
| Build report | SHA256 `11455cdcc15d91780bd1f67c3bd0f6fcdffb3a6a22a4cb61f6fdbc901e3ec3e2` |
| Events | 51 strict JSONL records, SHA256 `1770b715ecfbc47f3eb2f314055339d4f47fda33391d2cd3fa5d2dbfd4bc34e0` |
| MAME exit | 0, wall 14.287 s, stop reason `emulated_budget` at 120.0 emulated seconds |
| Calls | 3 started, 3 completed |
| Branch paths | `nonzero` only; zero path not observed |
| OR effects | 3 natural `7667` handler entries with `STD` observation |
| Clear effects | 0 natural; static `7673` contract only |

The run used absent NVRAM/configuration, `-noreadconfig`, isolated `cfg`,
`nvram`, `inp`, `snap`, `comments`, `state` and `diff` directories, no save-state
load, no playback file and no PC/register/RAM/ROM injection. The run ROM SHA1 and
SHA256 were rechecked after execution and were unchanged. The Lua observer only
reads the bounded word `00A0/00A1`.

## Final frontend

The capture launcher now uses the same stopped host as the accepted paused
debugger launcher:

```text
-debug -debugger imgui -debuglog -video bgfx -sound none -window
-bgfx_path <installed MAME directory>\bgfx
```

`-bgfx_path` is derived from the installed MAME executable directory. Version-
matched 0.281 `debug_imgui::init_debugger` requires BGFX, and its
`wait_for_debugger` loop does not call `set_foreground`, so the imgui host is
created without an OS focus request. The session metadata records
`frontend.debugger=imgui`, `frontend.video=bgfx`, the resolved `bgfx_path`,
`focus_stealing=false`, and the capture-tool/observer source hashes. The
generated `arguments.json` and the actual `run-record.json` command line both
contain the same frontend arguments.

## Static 6809 contract from original bytes

The contract is decoded from the exact original-ROM instruction bytes, not from
operation names. Token `7665` points at `7667`; token `7671` points at `7673`.

```text
7667 37 16      PULU A,B,X
7669 AA 84      ORA  A,X
766B EA 01      ORB  1,X
766D ED 84      STD  ,X
766F 0E FC      JMP  <$FC

7673 37 16      PULU A,B,X
7675 43         COMA
7676 53         COMB
7677 A4 84      ANDA ,X
7679 E4 01      ANDB 1,X
767B ED 84      STD  ,X
767D 0E FC      JMP  <$FC
```

`PULU A,B,X` pulls `X` from `U+2` and `D` from `U`, so the data stack supplies
the address word second and the mask word on top, and `U` advances by four. `X`
is the 16-bit address. The OR handler writes `old | mask` big-endian; the clear
handler complements the mask with `COMA`/`COMB`, writes `old & ~mask`, and leaves
`C=1` because `COM` sets carry and `AND` preserves it. The OR handler preserves
the entry carry because `ORA`/`ORB` do not change `C`.

## Exactly bounded observation

The observer set native debugger breakpoints only at:

- `7667` entry for the OR handler, with `Y=9A6B` and `X=7667`;
- `766F` immediately after the OR `STD` and before `JMP <$FC`, with `X=00A0`;
- `7673` entry for the clear handler, with `Y=9A70` and `X=7673`;
- `767D` immediately after the clear `STD` and before `JMP <$FC`, with `X=00A0`.

At entry the observer reads the mask word at `U` and the address word at `U+2`
from the data stack. It rejects the stop without reading `00A0/00A1` unless the
address is exactly `00A0`, the mask is exactly `4000`, and the caller site is the
accepted `EF9C`. This run therefore cannot silently read arbitrary RAM. At the
after-`STD` stop it checks `X=00A0`, `U` advanced by exactly 4, `S` and `Y`
unchanged, `D` equal to the written word, and the carry contract.

The periodic Lua callback remains only the stopped-state driver. It is not an
instruction boundary source and does not step the CPU as an idle keepalive.

## Natural OR observations

All three calls entered from `EF9C`, popped the nonzero condition `FFFF`, and
took the `7665` OR path.

| Call | Emulated time | Mask | Before `00A0` | After `00A0` | U advance | S/Y | X | D |
| ---: | ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | 50.166901744 | `4000` | `0000` | `4000` | `0004` | unchanged | `00A0` | `4000` |
| 2 | 53.047543023 | `4000` | `0000` | `4000` | `0004` | unchanged | `00A0` | `4000` |
| 3 | 117.268365698 | `4000` | `0000` | `4000` | `0004` | unchanged | `00A0` | `4000` |

Every observed word satisfies `after = before | mask` for the big-endian
`00A0/00A1` pair. Every observed entry top stack cell was the mask `4000` and the
second cell was the address `00A0`. The OR handler preserved carry from entry.

## Coverage gaps

- The zero-condition `7982` path was not observed in this run. `9A6E`, token
  `7671`, handler `7673` and the natural clear effect remain unobserved.
- Only caller site `EF9C`, mask `4000` and address `00A0` are accepted for
  memory observation. Other callers, masks or addresses are rejected rather
  than read.
- The run ended at the 120-emulated-second budget, not at a game-defined stop.
- The earlier accepted natural run did reach the zero path, but it did not
  capture `00A0/00A1`; it is not retroactively labelled as a memory proof.

## Negative controls

Seven controls pass. The four preserved controls are malformed JSONL, stale map
identity, phase-mismatched node prefetch and missing post-return completion. The
three new controls are:

1. wrong memory target (`00A2` instead of `00A0`) rejected before any unbounded
   read;
2. bad before/after word equation rejected against the OR arithmetic;
3. memory after-`STD` phase mismatch rejected against the exact phase.

All controls are synthetic verification, not natural execution evidence.

## Commands and exits

| Command | Exit | Notes |
| --- | ---: | --- |
| source-map generator | 0 | Map from `NineASixFourDecoder.Decode`, `VmIlCompiler.CompileIdentity`, `VmIlSourceMap.CreateForBuild`; wall 1.957 s. |
| `mame281.exe m4addr ... -debugger imgui -video bgfx ... -seconds_to_run 120` | 0 | One fresh natural run; wall 14.287 s. |

## Reproduction

```powershell
powershell -NoProfile -File tools/Capture-IlNineA64Natural.ps1 `
  -Mode Capture `
  -MameExecutable E:\Arcade\MAME0266\mame281.exe `
  -RomDirectory E:\Arcade\MAME0266\roms `
  -OriginalRom artifacts/deepseek/general-14/roms/original.p1 `
  -RunDirectory <fresh-run> `
  -EvidencePath <private-natural-evidence.json> `
  -MemoryEvidencePath evidence/mpu4/integrity/il-9a64-memory.json `
  -SecondsToRun 120 -WallTimeoutSeconds 600 -MaxCalls 8

powershell -NoProfile -File tests/worker/Test-IlNineA64Natural.ps1
```

Raw run data remains under
`artifacts/deepseek/il-9a64-memory-final-23/run-01/`. The focused test retains
the previous 303 checks, including the earlier 185 natural checks, and adds
frontend argument and source-provenance checks.

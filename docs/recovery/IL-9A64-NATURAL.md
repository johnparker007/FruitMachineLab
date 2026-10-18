# Natural 9A64 calls and branch observation - il-9a64-finish-15

Status: bounded natural observation on the original image. This is not a 9A64
edit, extension, linker, native-executor, gameplay-completeness or hardware
compatibility claim.

Task started from accepted `main` `ba529aae31f47ce04d40727478f1c783787fb3bf`.
The earlier task14 attempt stopped on an OpenCode denial while trying to read an
installed MAME plugin; no plugin file or folder was read or changed here. The
accepted tracked debugger examples and the already-installed MAME 0.281 APIs
were used directly.

## Result

One fresh-boot original-ROM run used the tracked physical-input replay. Within
the 120-emulated-second budget it naturally entered and completed five `9A64`
calls. All six mapped nodes and both checked branch paths were observed.

| Datum | Value |
| --- | --- |
| ROM | 65536 bytes, SHA1 `402D1518BB78FDC489B06C2AABC771E5CE151847`, SHA256 `EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C` |
| MAME | 0.281, SHA256 `0fce5a88df4f9d9b1fbf1405812c00848036e615993780978d967da34204cb7a` |
| Replay | `evidence/mpu4/skill-cash/actions.csv`, SHA256 `4a051da15264842697879eff396b34a789f5d80623f9a2e749c244e6a80e721d` |
| Source map | SHA256 `8d9c9ddc58373e1ffdd221590a75babc1fb7bf3f497bfca587dbac84981df766` |
| Build report | SHA256 `11455cdcc15d91780bd1f67c3bd0f6fcdffb3a6a22a4cb61f6fdbc901e3ec3e2` |
| Events | 71 strict JSONL records, SHA256 `2776ecc526da679c8d53d88d096993d358bd8e31f5ea113b9175ff134d9e97d0` |
| MAME exit | 0, wall 10.285 s, stop reason `emulated_budget` at 120.0 emulated seconds |
| Calls | 5 started, 5 completed |
| Branch paths | `nonzero` and `zero` |
| Observed nodes | 0, 1, 2, 3, 4, 5 (no unobserved mapped node) |
| Observed handlers | `7B6F`, `7984`, `7667`, `797B`, `7673`, `7931` |

The run used absent NVRAM/configuration, `-noreadconfig`, isolated `cfg`,
`nvram`, `inp`, `snap`, `comments`, `state` and `diff` directories, no save-state
load, no playback file and no PC/register/RAM/ROM injection. The run ROM SHA1
and SHA256 were rechecked after execution and were unchanged.

## Source-map and boundary identity

The map was generated from `NineASixFourDecoder.Decode`,
`VmIlCompiler.CompileIdentity` and `VmIlSourceMap.CreateForBuild` over the exact
identity-checked original ROM. It contains 14 entries, six nodes and two
branches over `9A64..9A71` (`7B6D79820676657979037671792F`). The identity compile
changed no byte and emitted the same body.

Exact stops came from native debugger breakpoints. The Lua `emu.register_periodic`
callback is only the stopped-state driver; it is not an instruction source. At
`PC=00FC` the prefetch `Y` is the token-word address. At primitive handlers the
analysis required `Y = node + 2` and `X = tokenPointer + 2`. Every captured
prefetch and handler record was checked against the map before any call was
accepted.

## Calls and branch paths

All five calls entered through token `9A62` at caller site `EF9C`, with caller
successor `EF9E`, `U=066C`, `S=07AC`, and the `00F8` trampoline with `X=9A64`.

| Call | Emulated time | Path | Condition cell | Branch next Y | Node sequence | Handler sequence |
| ---: | ---: | --- | --- | --- | --- | --- |
| 1 | 50.166901744 | nonzero | `FFFF` | `9A69` | `0,1,2,3,5` | `7B6F,7984,7667,797B,7931` |
| 2 | 53.026843605 | zero | `0000` | `9A6E` | `0,1,4,5` | `7B6F,7984,7673,7931` |
| 3 | 62.575979070 | nonzero | `FFFF` | `9A69` | `0,1,2,3,5` | `7B6F,7984,7667,797B,7931` |
| 4 | 81.583993023 | nonzero | `FFFF` | `9A69` | `0,1,2,3,5` | `7B6F,7984,7667,797B,7931` |
| 5 | 92.095154651 | nonzero | `FFFF` | `9A69` | `0,1,2,3,5` | `7B6F,7984,7667,797B,7931` |

For every call the `7982` handler was entered at `7984` with `Y=9A68`,
`X=7984`, operand byte `06` and model target `9A6E`. The popped condition cell
was `0000` only on the zero path; nonzero cells took the fall-through to
`9A69`. The branch handler advanced `U` by exactly `0002`.

On the nonzero path the unconditional `7979` handler was entered at `797B` with
`Y=9A6D`, `X=797B`, operand byte `03`, and the next prefetch was `Y=9A70`.
The zero call did not prefetch node 3; its `797B` execution is internal to the
checked `7984` handler and is not labelled as an observed node-3 prefetch.

## Return and continuation

Every call entered the `792F` handler at `7931` with `Y=9A72`, `X=7931`. The
control stack held saved caller cursor `EF9E`; `S` was `07AA`. The actual
post-return `00FC` prefetch then showed `Y=EF9E`, `S=07AC` and caller token
`80C4`, which is the ROM word at `EF9E`. `S` advanced by exactly `0002`. This is
observed `PULS` return state, not an inferred completion from the entry record.

## Negative controls

The capture verifier ran four controls, all rejected or classified correctly:

1. malformed trailing-comma event line rejected by the strict
   `System.Text.Json` helper;
2. stale source-map identity rejected by the preserved map hash binding;
3. phase-mismatched `node_prefetch` rejected because `Y` no longer matched the
   mapped node address;
4. removal of `post_return_prefetch`/`call_complete` did not produce a complete
   call.

The strict parser accepted all 71 natural records with no failures.

## Commands and exits

| Command | Exit | Notes |
| --- | ---: | --- |
| `dotnet run --project <run>/source-map-gen/IlNineA64MapGen.csproj --configuration Release -- <original> <map> <build>` | 0 | Generator output is preserved with the run; the generator process record was not separately persisted, so Analyze mode marks its command record as reconstructed. |
| `mame281.exe m4addr ... -debug -debugger windows -seconds_to_run 120 ...` | 0 | One fresh natural run; wall 10.285 s. |

The first launch attempt (`run-01`) stopped before any emulation at the
autoboot identity check: the generated map used uppercase SHA256 text while the
session config used lowercase. It wrote `startup_failure` code `map_image` and
MAME exited 3. That was a tooling/hash-case failure, not a natural 9A64 result.
The observer now compares identity hashes case-insensitively; no natural
execution occurred in `run-01`.

## Evidence classification

| Datum | Classification |
| --- | --- |
| Call entry, prefetches, handler entries, post-return state | Natural MAME 0.281 execution observed at native debugger breakpoints |
| Node addresses, tokens, operands, branch targets | Static source map generated from the checked original-ROM decoder/compiler/map API |
| Replay schedule | Existing tracked physical-input replay; no speculative input search |
| Negative controls | Synthetic verification only; not natural execution evidence |
| Memory OR/clear effects of `7665`/`7671` | Not claimed; handler semantics were not re-derived beyond the existing tracked native evidence and original ROM bytes |

## Limitations and remaining coverage

- Only caller site `EF9C` was reached. Other recorded callers of `9A62` were not
  exercised in this run and are not claimed.
- The zero path was observed once (call 2); the nonzero path four times. Both
  are observed, but this is not an exhaustive branch-distribution study.
- The run ended at the 120-emulated-second budget, not at a game-defined
  stopping condition.
- No `9A64` edit, operand replacement, relocation, extension range, linker, new
  composite word, native primitive or native C# executor was used.
- No memory write effect, paid-window comparison, gameplay acceptance,
  physical hardware test or hardware compatibility is claimed.
- The `EE16/EE22` paid-window comparison remains unchanged and was not retried.

## Reproduction

```powershell
powershell -NoProfile -File tools/Capture-IlNineA64Natural.ps1 `
  -Mode Capture `
  -MameExecutable E:\Arcade\MAME0266\mame281.exe `
  -RomDirectory E:\Arcade\MAME0266\roms `
  -OriginalRom artifacts/deepseek/general-14/roms/original.p1 `
  -RunDirectory <fresh-run> `
  -EvidencePath <private-evidence.json> `
  -SecondsToRun 120 -WallTimeoutSeconds 600 -MaxCalls 8

# Re-analyse a preserved run without launching MAME:
powershell -NoProfile -File tools/Capture-IlNineA64Natural.ps1 `
  -Mode Analyze -RunDirectory <fresh-run> -EvidencePath <private-evidence.json>

powershell -NoProfile -File tests/worker/Test-IlNineA64Natural.ps1
```

Raw run data remains under
`artifacts/deepseek/il-9a64-finish-15/`. The curated machine-readable result is
`evidence/mpu4/integrity/il-9a64-natural.json`.

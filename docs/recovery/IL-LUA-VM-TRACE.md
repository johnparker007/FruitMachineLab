# Lua debugger capability and complete early 9ED9 call — il-lua-api-09

Task started from main HEAD `25078d32bd52dbb005f713ef790ebd15a87af36b`.
This replaces the unsupported capability conclusion in the earlier
`il-lua-trace-07` report. The separate `il-natural-06` EE16/EE22 paid-window
gate is unchanged and was not attempted again.

## Correction to the earlier absence claim

The earlier report checked the unrelated global name `type(debugger)` with and
without `-debug`, then inferred that MAME 0.281 had no Lua debugger. That was the
wrong object path and the debugger was not enabled. Primary MAME 0.281 source
shows the real paths:

- `manager.machine.debugger` returns the `debugger_manager`, or `nil` when
  `DEBUG_FLAG_ENABLED` is not set.
- `manager.machine.devices[tag].debug` returns the `device_debug` interface for
  a CPU, or `nil` when the debugger is not enabled or the device is not a CPU.
- `debugger_manager` exposes `command`, `consolelog`, `errorlog`, `visible_cpu`
  and `execution_state`.
- `device_debug` exposes `step`, `go`, `bpset`, `bplist`, `bpclear`,
  `wpset`/`wplist` and run-control helpers.

Version-matched files are preserved under
`artifacts/deepseek/il-lua-api-08/source-mame0281/`:
`src_frontend_mame_luaengine.cpp` (debugger/device properties),
`src_frontend_mame_luaengine_debug.cpp` (debugger userdata methods) and
`docs_source_luascript_ref-debugger.rst`.

## Actual positive control

`artifacts/deepseek/il-lua-api-09/probe-01/run-capability-02` ran MAME 0.281
with `-debug -debugger none`, the original ROM, fresh isolated directories and a
read-only Lua probe. Results:

| Probe | Result |
| --- | --- |
| `manager.machine.debugger` | `userdata` |
| `debugger.execution_state` at start | `stop` |
| `manager.machine.devices[":maincpu"].debug` | `userdata` |
| `cpu.debug:step(1)` | returned success |
| `cpu.debug:bpset(0x7CD1, ...)` | breakpoint 1, `bplist()` showed it enabled |
| `cpu.debug:bpset(0x00FC, ...)` | breakpoint 2, `bplist()` showed it enabled |
| `cpu.debug:go()` | returned success |
| Breakpoint output | reset `7CD1` hit three times; first `00FC` fetch hit with `Y=FDF0` |

The earlier global-name result remains recorded as a failed probe, not as
evidence of absence. There is still no Lua instruction callback; frame callbacks
remain non-boundary evidence.

## Source-map-aware exact boundaries

`tools/Capture-IlVmTrace.ps1` now generates `debugger.cmd` from the checked
source map and the checked handler-entry plan. It does not carry a separate
hard-coded node list. For this map it derives:

- prefetch hooks at `PC=00FC` for `9ED9`, `9EDD`, `9EDF`, `9EE3`, `9EE5`;
- handler hooks at `795D`, `7880`, `795D`, `7AB1`, `7931` with the mapped
  `Y=node+2` conditions;
- the PULS return hook and a post-return hook conditioned on the saved `S` word;
- the composite `EBCA`/`00F8` hook, retained for calls that use that site.

The Lua observer validates the source map against live ROM bytes and supplies
the tracked physical-input replay, frame samples and tap diagnostics. Exact
instruction boundaries come from the native debugger actions; they are never
labelled Lua-sourced.

## Complete first natural 9ED9 call

Fresh isolated original and repaired runs used the same tracked replay
(`SHA256 4a051d...721d`), absent NVRAM/configuration, no save state, no playback
and no PC/RAM/register/ROM injection. The first natural `9ED9` call completed
with all five prefetches, all five handler entries, the `PULS` return and the
actual caller continuation.

| Datum | Original | Repaired |
| --- | --- | --- |
| ROM SHA256 | `ebf580...a15c` | `577f76...5107` |
| First inline literal at `9ED9` | `FF80` | `FF00` |
| Second inline literal at `9EDF` | `FF80` | `FF80` |
| XOR result observed at `9EE5` | `0000` | `0080` |
| Node prefetches | `9ED9/9EDD/9EDF/9EE3/9EE5` | same |
| Handler entries | `795D/7880/795D/7AB1/7931` | same |
| Saved caller cursor at `7931` | `9F16` | `9F16` |
| Post-PULS `00FC` fetch | `Y=9F16`, `S=0798` | `Y=9F16`, `S=0798` |

Entry state matched (`U=066E`, `S=0796` at the first prefetch). The post-PULS
fetch token was `75A9` in both runs. The first early call is not the later
`EBCA -> 9ED9` paid-window call; it is the first natural call reached by the
tracked schedule. The `EBCA`/`00F8` hook was therefore not hit in these two
runs, and no paid-window claim is made.

## Provenance

| Datum | Captured by | Notes |
| --- | --- | --- |
| `manager.machine.debugger`, `cpu.debug`, breakpoints, step/go | Lua debugger API | capability probe; read-only run control |
| `PC=00FC` prefetches, handler entries, PULS return, saved cursor | Native MAME debugger `bpset`/`printf` | source-map/plan-generated hooks |
| Map/live-byte validation, physical input, frame samples, taps | Lua | frame samples explicitly not boundaries |
| Identity/staleness checks, hook generation, hashes, curation | PowerShell | `tools/Capture-IlVmTrace.ps1`, `tools/Curate-IlVmTrace.ps1` |
| EE16/EE22 paid-window comparison | Preserved `il-natural-06` evidence | unchanged; not retried or relabelled |

## Acceptance status

- Lua debugger/API capability: **proved** with a real breakpoint/step positive
  control under `-debug`.
- Source-map-derived exact boundaries: **proved**.
- Complete all-five-node first natural `9ED9` call: **proved** for original and
  repaired images.
- Actual post-PULS caller continuation: **proved** at `Y=9F16`, `S=0798`.
- Paid-window original/changed comparison: **unchanged and unresolved**.
- Physical MPU4 hardware compatibility: not claimed.

## Reproduction

```powershell
powershell -NoProfile -File tools/Capture-IlVmTrace.ps1 `
  -MameExecutable E:\Arcade\MAME0266\mame281.exe `
  -RomDirectory E:\Arcade\MAME0266\roms `
  -OriginalRom <a6ls.p1> -RepairedRom <edited-repaired.p1> `
  -VariantRom <a6ls.p1> -Variant Original -RunDirectory <fresh-original>

powershell -NoProfile -File tools/Capture-IlVmTrace.ps1 `
  -MameExecutable E:\Arcade\MAME0266\mame281.exe `
  -RomDirectory E:\Arcade\MAME0266\roms `
  -OriginalRom <a6ls.p1> -RepairedRom <edited-repaired.p1> `
  -VariantRom <edited-repaired.p1> -Variant Changed -RunDirectory <fresh-changed>

powershell -NoProfile -File tools/Curate-IlVmTrace.ps1 `
  -OriginalRunDirectory <fresh-original> -ChangedRunDirectory <fresh-changed> `
  -OriginalRom <a6ls.p1> -RepairedRom <edited-repaired.p1> `
  -OutputPath evidence/mpu4/integrity/il-lua-vm-trace.json -RequireBoundaryTrace -Force
```

Private raw runs, probes, progress and result files are under
`artifacts/deepseek/il-lua-api-09/`. The curated evidence is
`evidence/mpu4/integrity/il-lua-vm-trace.json`.

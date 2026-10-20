# IL lamp output API capability

Status: curated capability evidence only. One fresh run of the unmodified
original `m4addr` ROM (`a6ls.p1`) in MAME observed the read-only output-manager
API. `naturalProof` is false. This is not a lamp transition, rendered-output,
compiled-ROM, source-map, natural-game or physical-hardware proof. The cause of
the initial `-1` values is unknown.

## Provenance

| Item | Value |
| --- | --- |
| Base revision | `3b16916547fac804a383670d6f36a2d3dfd63637` |
| Supervisor acceptance | `artifacts/deepseek/il-lamp-output-api-window-86/supervisor-validation.json` |
| Run | `artifacts/deepseek/il-lamp-output-api-probe-85/runs/supervisor-window-01` |
| ROM | `m4addr/a6ls.p1`, 65536 bytes, SHA1 `402D1518BB78FDC489B06C2AABC771E5CE151847`, SHA256 `EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C` |
| MAME | `0.281`, executable SHA256 `0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A` |
| Probe | `tools/lua/IlLampOutputApiWindow.lua`, 22932 bytes, SHA256 `79FB625E16BEFDE68790F7F55FFD8D8C167565CBE9CCF63D7AC3554822E63FC2` |
| Run times | start `2026-10-20T14:15:45.8780854Z`, end `2026-10-20T14:15:48.2704656Z`, wall `2.392 s` |
| Caps and exit | 2 emulated seconds, 60 wall seconds, exit code `0`, one launch, no retry |

The tracked Lua is byte-identical to the accepted task-86 probe. Its callback is
`emu.register_frame_done` (`:597`). API calls use colon receivers:
`name_to_id` (`:502`, control `:554`), `id_to_name` (`:529`), `get_value`
(`:540`, control `:561`) and `get_indexed_value` (`:547`). Sampling starts at
0.05 emulated seconds (`:10`) and is capped at 2.0 seconds / 121 samples
(`:11-12`). Every result records `naturalProof=false` (`:273`, `:424`, `:458`).

## Observed capability

- The output API was present and all six calls completed without pcall errors.
- `name_to_id("lamp120")` returned opaque id `12483`; `id_to_name(12483)`
  returned the exact case-sensitive name `lamp120` on all 19 samples.
- The opaque id is not the lamp-name suffix; `lamp120` is also queried as
  `get_indexed_value("lamp", 120)`.
- Missing name `fruitmachinelab_missing_output_85` returned id `0` and value `0`
  in every sample and does not count as an existing output.
- Samples 1-18 (0.050-0.333 seconds) returned `get=-1`, `indexed=-1`,
  `binary=false`. Negative one is retained raw, not normalized to zero.
- Sample 19 (0.350 seconds) returned `get=0`, `indexed=0`, `binary=true`.
- All 19 samples have empty error lists, stable identity and `naturalProof=false`.

The curated record is `evidence/mpu4/integrity/il-lamp-output-api.json`. It
contains each sample's sequence, emulated time, opaque id, `get`, `indexed`,
binary flag, exact roundtrip name and missing-name control values, plus relative
raw-source paths and SHA256 hashes. It is a compact abstraction, not the raw
trace.

## Isolation and limits

The preparation inventory recorded fresh empty cfg/nvram/input/snapshot/comment/
state/diff directories. The run generated isolated `cfg/default.cfg`,
`cfg/m4addr.cfg` and `nvram/m4addr/nvram`; these are run artifacts, not settings
changes. No input injection, save state, replay, debugger, memory or mutation
call was used. Console stderr contains only repeated layout deprecation warnings.

This evidence does not establish a `1 -> 0` lamp transition, natural game
behaviour, compiled-ROM effect, source-map resolution, rendered lamp output or
hardware compatibility. Post-0.35-second and IRQ-phase behaviour are uncovered.

## Inspection

The existing private run can be inspected without a new launch:

```powershell
Get-Content artifacts/deepseek/il-lamp-output-api-probe-85/runs/supervisor-window-01/api-probe-samples.jsonl |
  ForEach-Object { $_ | ConvertFrom-Json } |
  Format-Table seq, emulatedTimeSeconds, status
```

The tracked Lua may be supplied to a future, properly isolated MAME launch. This
curation adds no standalone launcher or wrapper and makes no claim that such a
launch has been performed.

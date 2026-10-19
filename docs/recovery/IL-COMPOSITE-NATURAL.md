# Composite-word natural execution attempts

Status: **blocked. Two natural composite-boundary attempts have been made, both
unsuccessful. The revised tracked-replay attempt naturally fetched the compiled
caller and entered the `00F8` trampoline, then stopped on an observer protocol
failure before the body phases. Exactly two of the thirteen mapped phases were
observed; there is no complete composite-call proof. No third capture was made.
The offline evidence-integrity repair in task 38 changed only the analyzer,
checker, observer and documentation; it did not run MAME or Lua.**

Base revision: `main` `7e6b9eab52b351107e970593e10b5ec0b2d62506`. The native C#
executor remains frozen. No ROM binary, MAME setting or external NVRAM is tracked
or modified.

## Exact build and execution identities

| Item | Value |
| --- | --- |
| Original ROM | `artifacts/deepseek/general-14/roms/original.p1` |
| Original SHA1 / SHA256 | `402D1518BB78FDC489B06C2AABC771E5CE151847` / `EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C` |
| Built ROM | `artifacts/deepseek/il-composite-immutability-34/il-verifier-20261019-01/composite/built-repaired.p1` |
| Built SHA1 / SHA256 | `DC6381B9883AAFDE372D2C2AA14C817BAE839B21` / `761F34BAAC06C6F8F5DA963CCADEB276FAE9196EE1C4D9060BC915A314E3903D` |
| Source map | same directory `composite-source-map.json` |
| Source map SHA256 | `9A560CA7818C7A8F56AC4E314BB5DF19E81F4EFABB23982CCC092CA648B5BCF8` |
| Build report SHA256 | `08BA168885E0F92B1BA4ECBBE2CB1A345D823067E62F75C5679D6E9FB6B2781B` |
| Integrity fields | `E93F3C61B5` |
| Changed offsets | 21: 14 extension, `9F14-9F15`, `FFD1-FFD5` |
| MAME | `E:\Arcade\MAME0266\mame281.exe`, SHA256 `0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A`, `0.281 (mame0281)` |
| Frontend | `-debugger imgui -video bgfx` with the installed `bgfx` assets |

Before launch the tool rechecked the original/built/map/MAME hashes, the map build
binding, the 5 nodes, 20 byte entries, 13 ordered phases, the exact 21-byte diff,
the `E93F3C61B5` fields, the `00F8` header at `1010`, the
`795BFF80787E795BFF807AAF792F` body at `1012-101F`, the `1010` caller at `9F14`,
the preserved original `9ED7`/`9ED9` definition, and the `1000-100F`/`13F0-13FF`
guards.

## Attempt 1: bounded no-input boot (preserved, unsuccessful)

Task `il-composite-natural-35` ran one fresh isolated boot with no input. It
reached its 180-second emulated budget without fetching the patched `9F14`
caller. Zero of the thirteen phases were observed. MAME exited `0`; the strict
JSONL parse passed; the run ROM and state directories were unchanged.

The raw run and failed checker logs remain under
`artifacts/deepseek/il-composite-natural-35/`. Its event hash is
`912CD4442EB623B59A8786386D0D937D0343AF61C1EA758D6D6743AC16CF86F3`. It is
**not renamed or reclassified** as a different boundary: it is the first
unsuccessful attempt at the same natural composite boundary.

## Attempt 2: authorized tracked physical replay (this task)

The only revised capture used the existing tracked physical-input replay, not
PC/RAM/register/state injection:

| Input item | SHA256 |
| --- | --- |
| `evidence/mpu4/skill-cash/actions.csv` | `4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D` |
| `evidence/mpu4/skill-cash/input.lua` | `23099F8888AF8DB353253E0DF97638320DC59CA9A47371723A380E0C4EE85C94` |

The fixture is the same one used by the accepted prior `9F14`/`9ED9` natural
trace. Its coin event is `2100-2103` and its start fixture row is `2220-2232`,
which the tracked script applies as the prior effective start frames
`2221-2224`. The new run logged exactly those effective frames and the coin
frames `2100-2103`. Every fixture action after frame `2400` remained unused
because the capture exited at the failure.

Command (one fresh create-only directory):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  tools/Capture-IlCompositeNatural.ps1 -Mode Capture `
  -RunDirectory artifacts/deepseek/il-composite-replay-36/run-01
```

Observed result:

| Datum | Value |
| --- | --- |
| MAME exit | `0`, not timed out |
| Wall / emulated time | `7.178 s` / `37.076473837 s` at failure |
| `session_ready` | `resetPc=7CCF`, exact image/map/build/Lua/MAME hashes |
| Input policy | `tracked_physical_replay`; replay and input-Lua hashes verified |
| Coin / start | full observed coin window `2100-2103`; full observed start-active window `2221-2228`; required effective prefix `2221-2224` |
| Caller fetch | PC `00FC`, Y `9F14`, token `1010` at `37.076457558 s` |
| Trampoline | PC `00F8`, X `1012`, Y `9F16` at `37.076467442 s` |
| Header saved-cursor field | `9F16`, a legacy map echo from the captured pre-fix observer; not a live observation and not used as evidence |
| Composite phases | `2` of `13` |
| Failure | `protocol_failure`, code `phase_saved_cursor`, message `body-prefetch-0 saved cursor 9F16 is not FFFFFFFFFFFFFFFF` |
| Strict JSONL parse | pass, 5 records |
| Run ROM after execution | exact built SHA256, unchanged |
| State files | `0` |
| Save state / state injection / input injection / debugger writes | `false` / `false` / `false` / `false` |

The observed caller and trampoline values agree with the prior `9ED9` trace and
the static phase contract. The run then stopped because the observer compared the
`body-prefetch-0` saved cursor against the sentinel `-1` (serialized as
`FFFFFFFFFFFFFFFF`) instead of the required `9F16`. The header event's
`controlStack0` was the real pre-PSHS top `9F3F`; no body or return control-stack
read was reached. The failure is in the observer, not evidence of wrong ROM
behaviour. The raw `input-levels.csv` contains start activity at
`2221-2228`, so the earlier curated `2221-2224` sub-window was only the required
effective prefix, not the full observed window.

### Post-capture correction and verification gap

The observer's `body-prefetch-0` saved-cursor check and the analyzer's metadata
field name were corrected after the capture. The raw capture was **not rerun**.
The evidence records a verification gap: the captured observer hash is
`444A9FA03413C7D4CB25065E93D38B33B9D44FA4BD45545646543359C8078285`, while the
current fixed observer differs. The current fixed observer no longer logs a
header saved cursor, records result/post-return fields only after the actual
`post-return-prefetch` phase, and is still exercised only by synthetic fixtures
and negative controls. Lua standalone is not installed, so the current Lua has
not been syntax-executed. A third capture requires John's authorization.

### Offline evidence-integrity repair (task 38)

The audit in task 37 found seven evidence-integrity defects. The bounded offline
repair now:

- requires a present MAME `run-record.json`, `timedOut=false`, `exitCode=0` and a
  matching `exit-code.txt` before any phase-complete claim (D1);
- validates the event sequence: one first `session_ready`, contiguous ordered
  phases, at most one terminal failure/timeout after the phases, completion last,
  no unexpected event types, and no completion plus failure/timeout (D2);
- validates the complete coin window `2100-2103` and the full contiguous
  start-active window within the replay fixture's `2220-2232` probe, requiring
  `2221-2224` and reporting the full observed `2221-2228` without truncation (D3);
- treats the header saved cursor as a non-authoritative legacy map echo and
  derives the saved cursor only from live `body-prefetch-0` or `return-handler`
  `controlStack0`; the pre-PSHS header top must be `9F3F` and the post-PSHS live
  saved cursor must be `9F16` (D4);
- keeps failed-run result/post-return fields out of the current observer and
  ignores the historical captured fields unless the return phase was observed
  (D5);
- rehashes the actual run-local observer, map, config and observer composition
  assets, matches them to canonical renderings and to metadata when present, and
  records legacy metadata honestly as recomputed from the run (D6);
- models the synthetic fixture's pre-PSHS header control stack as `9F3F`, its
  post-PSHS body/return stack as `9F16`, and labels the fixture as checker-only
  with Lua not executed (D7).

Both original raw runs were copied and reanalysed read-only. The raw attempt-1
and attempt-2 artifacts and their failure history were not edited. The positive
synthetic complete fixture remains clearly synthetic and is not curated natural
execution evidence. No third natural capture was made.

## What is and is not proved

Proved by the revised capture:

- The exact compiled image boots fresh with the tracked physical coin/start
  replay and no save state or state injection.
- The replay's coin and start pulses occurred on the prior frames.
- The compiled caller at `9F14` was fetched naturally with token `1010`.
- The `00F8` trampoline was entered with `X=1012`, `Y=9F16`, before its `PSHS`
  save. The live pre-PSHS control-stack top was `9F3F`; no live saved-cursor read
  was reached at a body or return phase.
- The image, map, build, captured Lua, MAME and input fixture identities are
  bound into the raw run and strict JSON evidence. The current fixed Lua is
  reported separately as a post-capture verification gap.

Not proved:

- The five body prefetches, four native handlers (including the repeated literal
  handler), the actual `PSHS`-saved cursor `9F16`, the `PULS Y` return,
  post-return token `75A9`, net `U/S=0`, and result `0000`.
- Any complete natural composite call, paid-gate behaviour, full game or
  physical MPU4 hardware compatibility.
- Any natural execution of the current fixed Lua. It has only static and
  synthetic coverage.
- The purpose of the broader `9F12` caller remains unresolved.

## Tooling and negative controls

- `tools/Capture-IlCompositeNatural.ps1` verifies the exact original, built,
  map, build-report, MAME, replay-fixture and input-Lua hashes; launches one
  create-only fresh run through the proven `-autoboot_script` pattern; and
  validates observed input levels, core phases, failure records and strict JSON.
- `tools/lua/IlCompositeNatural.lua` validates the live compiled definition and
  sets native debugger breakpoints. It does not apply inputs or write memory,
  registers or state. The existing `evidence/mpu4/skill-cash/input.lua` applies
  the tracked physical port overrides.
- `tools/Test-IlCompositeNatural.ps1` verifies the preserved attempt-1 no-input
  run, the attempt-2 partial natural run, the clearly synthetic complete fixture,
  and negative controls for wrong image/map, wrong Y, missing return, wrong live
  cursor, wrong stack delta, forged input/state claims, missing/wrong replay
  provenance, missing coin/start pulses, malformed JSON, missing/nonzero/timed-out
  run records, exit-code mismatch, reordered/duplicated/terminal-plus-complete
  events, missing phases, extra early coin or late start activity, mutated
  run-local observer/map/config assets, a wrong header cursor claim, and an
  impossible pre-PSHS header control stack. The synthetic fixture is not run
  through Lua and cannot satisfy natural acceptance.

## Exact continuation

Do not run a third capture without John's explicit authorization. If authorized,
the next step is one fresh isolated boot with the fixed observer and the same
tracked replay fixture, expecting:

- the caller/trampoline phases already observed;
- `body-prefetch-0..4` at `1012-101E`;
- handlers `795D,7880,795D,7AB1,7931`;
- the actual `PULS Y` return to saved cursor `9F16`;
- post-return PC `00FC`, Y `9F16`, token `75A9`;
- net `U=0`, `S=0`, result `0000` for input `0000`.

No result above should be claimed until a new raw capture observes it.

## Artifacts and hashes

| Artifact | SHA256 |
| --- | --- |
| `artifacts/deepseek/il-composite-natural-35/run-01/events.jsonl` | `912CD4442EB623B59A8786386D0D937D0343AF61C1EA758D6D6743AC16CF86F3` |
| `artifacts/deepseek/il-composite-replay-36/run-01/events.jsonl` | `4D545B1FB933A2585FB3B2233C1F429EF9B264BF1B2D7A380010341D4D0BC45D` |
| `artifacts/deepseek/il-composite-replay-36/run-01/input-levels.csv` | `B6350712F61CAEB4BEC8672A6B7D1390FD44829D23B8AE7C99D9B5B58D5B8AAB` |
| `artifacts/deepseek/il-composite-replay-36/run-01/IlCompositeNatural.lua` | `444A9FA03413C7D4CB25065E93D38B33B9D44FA4BD45545646543359C8078285` |
| `evidence/mpu4/integrity/il-composite-natural.json` | `68A2270A2D2301F717E4103E67935DE5C1424DE3C7D2E4E7B2F813F751B169B0` |
| `tools/Capture-IlCompositeNatural.ps1` | `C02FB766DBBFBBC30311CE5F43E28F1511B2717B9D75D5BC5A946D92F79B7E5E` |
| `tools/lua/IlCompositeNatural.lua` | `2A97FF58C2C6124C7D657D8387F61D58C55D328F39ED3FA71D2A740E9AF76C70` |
| `tools/Test-IlCompositeNatural.ps1` | `4E74A70F92D72AC77672E4F65FB689C1B07A668F69656637F0C2CE708CBEE3AD` |

Raw runs, command logs, failed test logs and synthetic test runs remain under
`artifacts/deepseek/il-composite-natural-35/` and
`artifacts/deepseek/il-composite-replay-36/`. The task-38 read-only copies and
reanalysis observations are under
`artifacts/deepseek/il-composite-evidence-repair-38/reanalysis/`. No ROM binary
is tracked.

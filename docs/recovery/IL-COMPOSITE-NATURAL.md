# Composite-word natural execution attempts

Status: **accepted complete natural composite call, after offline reanalysis.
Two earlier natural composite-boundary attempts were unsuccessful. John
authorized exactly one additional capture on 19 October 2026. That third attempt
used the corrected observer and the same tracked coin/start replay and reached
all thirteen ordered phases with the required caller, trampoline, handler,
return, stack and result values. The original frozen analyzer rejected its D3
start-active window because debugger-stop `frame_done` rows were counted as 60 Hz
samples. Task `il-composite-input-time-41` repaired only the offline analyzer,
reanalysed a private copy of the preserved raw run, and accepted the call. No
MAME launch, Lua execution, retry or fourth capture was made.**

Base revision: `main` `af3bb9add51e1b17fa74044d4aebd3a47ac126dc`. The native C#
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

## Attempt 2: authorized tracked physical replay (preserved, unsuccessful)

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
execution evidence.

## Attempt 3: one additional authorized tracked-replay capture

John explicitly authorized exactly one additional fresh-boot MAME capture with
the corrected observer and the same logged coin/start replay. No retry, no
automatic rerun and no fourth capture were authorized. That authorization was
consumed by the single run below.

Preflight verified these exact identities before launch, and the run-local copies
were rehashed afterwards:

| Item | SHA256 |
| --- | --- |
| `tools/Capture-IlCompositeNatural.ps1` | `C02FB766DBBFBBC30311CE5F43E28F1511B2717B9D75D5BC5A946D92F79B7E5E` |
| `tools/lua/IlCompositeNatural.lua` (corrected observer) | `2A97FF58C2C6124C7D657D8387F61D58C55D328F39ED3FA71D2A740E9AF76C70` |
| Built ROM | `761F34BAAC06C6F8F5DA963CCADEB276FAE9196EE1C4D9060BC915A314E3903D` |
| Source map | `9A560CA7818C7A8F56AC4E314BB5DF19E81F4EFABB23982CCC092CA648B5BCF8` |
| Build report | `08BA168885E0F92B1BA4ECBBE2CB1A345D823067E62F75C5679D6E9FB6B2781B` |
| Original ROM | `EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C` |
| MAME `mame281.exe` | `0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A` |
| Replay `actions.csv` | `4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D` |
| Input `input.lua` | `23099F8888AF8DB353253E0DF97638320DC59CA9A47371723A380E0C4EE85C94` |
| Prior `9ED9` trace | `39A1CB2FD46FA36D66C6C4B261483D298644A22FC2690BF95C4A9697265917D9` |

The current 195-check offline checker passed before launch (`0` failures). The run
used a fresh create-only directory, isolated `cfg`/`nvram`/`inp`/`snap`/`state`/
`diff` directories, `-noreadconfig`, absent NVRAM/config, `-debugger imgui`,
`-video bgfx` with the installed BGFX assets, and MAME 0.281. No save state,
state injection, register/RAM/PC seed or debugger write was used.

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  tools/Capture-IlCompositeNatural.ps1 -Mode Capture `
  -RunDirectory artifacts/deepseek/il-composite-authorized-capture-40/run-01
```

Raw run result:

| Datum | Value |
| --- | --- |
| MAME exit | `0`, not timed out |
| MAME wall / emulated time | `7.359 s` / `37.076576163 s` |
| Event records | `15` (one `session_ready`, thirteen phases, one `session_complete`) |
| Strict System.Text.Json parse | pass, `0` failures |
| Coin activity | exactly `2100,2101,2102,2103` |
| Start activity | required prefix `2221-2224`; observed rows `2221-2238` |
| Caller phase | PC `00FC`, Y `9F14`, token `1010` at `37.076457558 s` |
| Trampoline phase | PC `00F8`, X `1012`, Y `9F16` at `37.076467442 s` |
| Body saved cursor | live `controlStack0=9F16` at `body-prefetch-0` |
| Handler sequence | `795D,7880,795D,7AB1,7931` |
| Return handler | live `controlStack0=9F16` |
| Post-return | PC `00FC`, Y `9F16`, token `75A9` |
| Input / result | `0000` / `0000` |
| Net U / S | `0000` / `0000` |
| Run ROM after execution | exact built SHA256, unchanged |
| State files | `0` |
| Save state / state injection / input injection / debugger writes | `false` / `false` / `false` / `false` |

The raw trace therefore contains every value named in the task acceptance, in the
required order, with live body and return control-stack reads. It is preserved at
`artifacts/deepseek/il-composite-authorized-capture-40/run-01/` with event hash
`EA4FAE8345CCBB25D6921628C0B8EB869B8C4FA60ECF0B44B25A2D2CF185C353` and input
levels hash `D118902E7AFFB8B86D3C0B7FBCC92093205D228C91FFFF08BB0BEB6855CCF053`.

### Original analyzer rejection and offline reanalysis (task 41)

The capture process itself ran correctly, but its original post-run analysis
exited `1`:

```text
The start-active window ends at 2238, beyond the replay fixture's 2220-2232 start probe
tools/Capture-IlCompositeNatural.ps1:208-209
```

The D3 analyzer bound read the `frame` counter written by `input.lua`. When the
observer stops and resumes for each of the thirteen native breakpoints,
`emu.register_frame_done` emits additional rows at nearly the same emulated time:
the rows after `2225` carry microsecond-scale increments rather than 60 Hz frame
increments. The real 60 Hz start rows are `2221-2225`, inside the fixture probe;
the rows `2226-2238` are debugger-stop callbacks. The replay fixture and input
Lua hashes were unchanged, and no extra fixture action was applied.

Task 41 reanalysed a private copy of this preserved raw run. It did not launch
MAME, execute Lua or modify raw attempt artifacts, and it did not regenerate the
reference input. The corrected analyzer sample contract is:

- derive the 60 Hz period and grid tolerance from the known frame period
  (`1/60 s`, tolerance one eighth of a frame, `0.002083333 s`), not from a pinned
  raw row count;
- record every start-active row, including debugger-stop callbacks, with its
  frame counter, emulated time, derived real-frame index and classification;
- classify a row as `real_60hz` only when its emulated time is within the grid
  tolerance of the derived 60 Hz grid;
- accept an off-grid start-active row only when it is contiguous with the real
  start rows, matches the ordered recorded phase/session stop time within a
  derived microsecond tolerance, and the count equals the composite debugger
  stop count recorded in `debug.log`;
- reject non-monotonic, duplicate or malformed times, extra real early coin or
  late start activity, active input after the fixture probe, unsupported
  off-grid samples, and natural completion without tracked raw provenance.

For attempt 3, the result is exact:

| Start evidence | Value |
| --- | --- |
| Fixture start probe | `2220-2232` (active while `first <= frame < last`) |
| Real 60 Hz start rows | `2221,2222,2223,2224,2225` |
| Real 60 Hz emulated times | `37.000000000` to `37.066666667 s` |
| Debugger-stop callback rows | `2226-2238` |
| Callback emulated times | `37.076457558` to `37.076576163 s` |
| Recorded composite debugger stops | `13` (`debug.log` has 14 stop lines including reset) |
| Recorded phase stop times | `13`, matched in order by the callbacks |
| Full start-active window | `2221-2238` |
| Required effective prefix | `2221-2224` |

The private-copy reanalysis returned
`status=complete_natural_composite_call`: all 13 phases, live body and return
saved cursor `9F16`, handler sequence `795D,7880,795D,7AB1,7931`, post-return
Y `9F16`/token `75A9`, input/result `0000`, net `U/S=0000`, MAME exit `0` without
timeout, strict JSON all 15 records, unchanged run ROM and zero state files.
`evidence/mpu4/integrity/il-composite-natural.json` was curated with attempt 1
and attempt 2 preserved as unsuccessful history, the original D3 rejection
retained verbatim, and the exact raw hashes recorded. The prior attempt-2
blocked report was not erased or rewritten.

This is the third and final authorized attempt at this boundary. No fourth
capture is requested or authorized.

## What is and is not proved

Established by the accepted attempt 3 natural trace:

- The exact compiled image boots fresh with the tracked physical coin/start
  replay and no save state, state injection, register/RAM/PC seed or debugger
  write.
- The replay's complete coin window `2100-2103` and the required effective start
  prefix `2221-2224` occurred on the prior frames. The real 60 Hz start samples
  extend to `2225`; rows `2226-2238` are recorded debugger-stop callbacks, not
  additional input pulses.
- The compiled caller at `9F14` was fetched naturally with token `1010`; the
  `00F8` trampoline was entered with `X=1012`, `Y=9F16`, and the live pre-PSHS
  control-stack top was `9F3F`.
- All five body prefetches at `1012-101E` and the native handler entries
  `795D,7880,795D,7AB1,7931` were observed in order.
- The live `PSHS`-saved cursor `9F16` was read at `body-prefetch-0` and
  `return-handler`, followed by the actual `PULS Y` return, post-return PC
  `00FC`, Y `9F16`, token `75A9`, net `U/S=0000`, input `0000` and result
  `0000`.
- MAME exited `0` without a timeout; all 15 raw event records passed strict
  JSON; the run ROM remained the exact built image and the state directory was
  empty. The image, map, build, observer Lua, MAME and input fixture identities
  are bound into the raw run and evidence. The captured observer Lua is identical
  to the current tracked observer (`2A97FF58...`); only the offline analyzer
  changed after capture.

Not proved:

- Paid-gate behaviour, full-game behaviour or physical MPU4 hardware
  compatibility.
- The purpose of the broader `9F12` caller remains unresolved.
- The broader composite language beyond this single accepted `1010` call and its
  five-node body.
- No claim is made for any other ROM revision, platform or capture boundary.

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
  run, the attempt-2 partial natural run, the accepted attempt-3 private-copy
  reanalysis and the clearly synthetic complete fixture. It also exercises
  negative controls for wrong image/map, wrong Y, missing return, wrong live
  cursor, wrong stack delta, forged input/state claims, missing/wrong replay
  provenance, missing coin/start pulses, malformed JSON, missing/nonzero/timed-out
  run records, exit-code mismatch, reordered/duplicated/terminal-plus-complete
  events, missing phases, extra early coin or late start activity, duplicate or
  non-monotonic sample times, malformed sample times, an unsupported
  debug-callback spoof, mutated run-local observer/map/config assets, a wrong
  header cursor claim, and an impossible pre-PSHS header control stack. The
  synthetic fixture is not run through Lua and cannot satisfy natural acceptance.
  The positive synthetic fixture was adjusted to emit its own consistent
  synthetic 60 Hz grid, debug-stop callbacks and debug log because the corrected
  analyzer now applies the same sample contract to all tracked-replay fixtures;
  this changes only the synthetic fixture, not natural evidence or negative
  expectations.

## Exact continuation

The third authorized capture has been made, its authorization is consumed, and
the preserved raw run is accepted only through the offline task-41 reanalysis.
Do not run a fourth capture or retry the third without a new explicit John
authorization.

The D3 input-sampling blocker is resolved for this run: real 60 Hz samples and
debugger-stop callbacks are now separated by recorded timing and stop evidence,
not by a relaxed row-count bound. Any further natural execution must still be a
newly authorized fresh-boot capture validated through the same public analyzer,
including all D1-D7 gates and the input-time negative controls. No save state,
state injection, PC/register/RAM seed or debugger write is permitted. No
automatic retry, successor dispatch or schedule is established by this
reanalysis.

## Artifacts and hashes

| Artifact | SHA256 |
| --- | --- |
| `artifacts/deepseek/il-composite-natural-35/run-01/events.jsonl` | `912CD4442EB623B59A8786386D0D937D0343AF61C1EA758D6D6743AC16CF86F3` |
| `artifacts/deepseek/il-composite-replay-36/run-01/events.jsonl` | `4D545B1FB933A2585FB3B2233C1F429EF9B264BF1B2D7A380010341D4D0BC45D` |
| `artifacts/deepseek/il-composite-replay-36/run-01/input-levels.csv` | `B6350712F61CAEB4BEC8672A6B7D1390FD44829D23B8AE7C99D9B5B58D5B8AAB` |
| `artifacts/deepseek/il-composite-replay-36/run-01/IlCompositeNatural.lua` | `444A9FA03413C7D4CB25065E93D38B33B9D44FA4BD45545646543359C8078285` |
| `artifacts/deepseek/il-composite-authorized-capture-40/run-01/events.jsonl` | `EA4FAE8345CCBB25D6921628C0B8EB869B8C4FA60ECF0B44B25A2D2CF185C353` |
| `artifacts/deepseek/il-composite-authorized-capture-40/run-01/input-levels.csv` | `D118902E7AFFB8B86D3C0B7FBCC92093205D228C91FFFF08BB0BEB6855CCF053` |
| `artifacts/deepseek/il-composite-authorized-capture-40/run-01/IlCompositeNatural.lua` | `2A97FF58C2C6124C7D657D8387F61D58C55D328F39ED3FA71D2A740E9AF76C70` |
| `artifacts/deepseek/il-composite-authorized-capture-40/run-01/events-strict.json` | `321C057160D3C3E49E7C23467617C8E7CBCF87813A4987E82F818E86694DDE7E` |
| `artifacts/deepseek/il-composite-authorized-capture-40/raw-observation.json` | `4EFAC822B22B77626A081A1996BAE37FE878B54FEB45DF8F71824CE8DF318BA9` |
| `evidence/mpu4/integrity/il-composite-natural.json` | `541F089EEA3B5D44A48A8A885A7E992C4947CE233A0C3AF9E2A50DD188D62081` |
| `tools/Capture-IlCompositeNatural.ps1` | `A3983082D81A2EB4A5D0830ECD8AC8B6E31E488A946917A96B08802B5FD8DD94` |
| `tools/lua/IlCompositeNatural.lua` | `2A97FF58C2C6124C7D657D8387F61D58C55D328F39ED3FA71D2A740E9AF76C70` |
| `tools/Test-IlCompositeNatural.ps1` | `567532DF62A12810B06E095C88176F37F1CB0E34923A232A4F242D81B92CEAE6` |

Raw runs, command logs, failed test logs and synthetic test runs remain under
`artifacts/deepseek/il-composite-natural-35/`,
`artifacts/deepseek/il-composite-replay-36/` and
`artifacts/deepseek/il-composite-authorized-capture-40/`. The task-38 read-only
copies and reanalysis observations are under
`artifacts/deepseek/il-composite-evidence-repair-38/reanalysis/`. The task-41
private copies, identity verification, corrected analysis, checker logs, strict
JSON evidence, negative-control outputs, exact exits and final hashes are under
`artifacts/deepseek/il-composite-input-time-41/`. The attempt-3 command, original
analyzer failure, strict JSON summary, raw-observation extraction and review
notes remain under `artifacts/deepseek/il-composite-authorized-capture-40/`. No
ROM binary is tracked.

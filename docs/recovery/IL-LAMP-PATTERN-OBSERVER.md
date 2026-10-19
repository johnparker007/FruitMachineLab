# IL lamp-pattern observer: direct supervisor review 67

John authorized direct repair on 19 October 2026. Capture `natural-03` now
passes the independent checker: 43 phases, 10 observed native boundaries,
4 branch-skipped boundaries and 52 distinct physical stops. The original VM
returns to Y=9F16, U=066E, S=0798, result 0000 and successor 75A9.

The four target bytes 010F/011F/012F/013F were already 3F and remained 3F.
This proves the measured bit-01 OR write path and return, not a visible lamp
transition or general caller safety. Actual CPU B after the 0803 read was 00
(column 15); F1 entry/exit was 00, skipping both optional 080C writes. Other
F1 paths have synthetic tests only. Physical hardware remains untested.

Repairs distinguish pending cursor Y before PSHS from the saved cursor after
PSHS, serialize boundary U/S, validate those contracts, and catch Lua callback
errors fail-closed. Inline ROM-byte operands now use the ROM reader. CC save
and restore share one session field; IRQ/FIRQ checks test actual mask bits.

Private evidence is under `artifacts/deepseek/il-lamp-observer-supervisor-67/`.
Diagnostic runs 01/02 failed on the header cursor contract and omitted U/S.
Run 03 completed with MAME exit 0 in 10.472 seconds. Its raw assets and events
were retained unchanged; corrected offline checks accept that same capture.
The original wrapper failure remains in its historical report. Raw metadata
does not self-claim supervisor acceptance.

Run 03 freshness uses its create-only empty preparation inventory and known
cfg/NVRAM files created within the process window. It predates the wrapper's
new immediate-prelaunch inventory; no such record is claimed retroactively.
Unknown persistent files, stale timestamps, nonempty preparation inventories,
state files and playback still reject. Only the three known MAME-generated
cfg/NVRAM filenames are permitted within the actual run window.

MAME parsed and executed the captured Lua. No standalone Lua parser is installed;
unexecuted paths retain offline-only coverage. The allocation remains 24 of
992 approved bytes, leaving 968. Original ROMs, settings and native C# gameplay
are preserved.

The following worker-65 report is historical. Its no-launch statements and
proposed next capture are superseded by the direct review above.

## Historical worker-65 offline result

Status: **tools implemented and offline-verified only; repair attempt 2
continuation.** No MAME process was launched for this task, no natural capture
exists, and no `il-lamp-pattern-natural` evidence file was written. Natural
safety of the `9C44/49C5` lamp service at the `9F14` caller remains unproved.
Supervisor acceptance is not claimed.

Task: `il-lamp-natural-tools-finish-65`, continuing repair attempt 2
(`il-lamp-natural-tools-repair-64`, interrupted) of attempt 1
(`il-lamp-natural-tools-63`). Base: `main` `d09c7ee`. This report is the
reviewable result of the bounded tool-building increment. The next action is a
separately dispatched single fresh capture after supervisor review.

## Delivered tools

| File | Purpose |
| --- | --- |
| `tools/Capture-IlLampNatural.ps1` | Create-only `-PrepareOnly` preflight/template generation, optional future `-Run`, and offline `-Analyze`/`-Verify` wrapper. |
| `tools/lua/IlLampNatural.lua` | Lua observer using native debugger `bpset` stops, an ordered stage state machine, and a periodic stopped-state driver. No instruction-callback claims and no active-I/O reads. |
| `tests/worker/Test-IlLampNatural.ps1` | Independent offline checker, ROM-derived native-frame test, ordered-arming simulation, synthetic-fixture value tests and negative controls. |
| `docs/recovery/IL-LAMP-PATTERN-OBSERVER.md` | This report. |

No ROM was emitted, injected or repaired. The frozen image, map, build report,
original ROM, tracked replay and tracked input Lua were read only and re-hashed.
The attempt-1 and interrupted-repair private evidence were preserved; new
self-test output is written under
`artifacts/deepseek/il-lamp-natural-tools-finish-65/`.

## Frozen inputs

| Item | Path | SHA256 |
| --- | --- | --- |
| Built image | `artifacts/deepseek/il-lamp-supervisor-61/worker-final-03/positive-01/lamp-repaired.p1` | `631F6C252A5DF359525553F7D14A4FC8CEF965C76BBECA759EAAA862A3FAD4DE` |
| Final map | `artifacts/deepseek/il-lamp-supervisor-61/worker-final-03/positive-01/lamp-pattern-source-map.json` | `42F0C4BB886313F5B1A7F78991A2EFD09351CC1912DF7A58EA6E3BE7E8E84163` |
| Build report | `artifacts/deepseek/il-lamp-supervisor-61/worker-final-03/positive-01/build-report.json` | `F085192074032C35F212B96F8F480720AAC49BDEBC56C0B2C8D54FA11C9CF97F` |
| Supervisor checker report | `artifacts/deepseek/il-lamp-supervisor-61/worker-final-03/checker-report.json` | `D988804F9E4157584D1BE1CCA2DAD41578B30C23BB25FBA16C0522F7BC679E99` |
| Original ROM | `artifacts/deepseek/il-natural-06/runs/original-01/roms/m4addr/a6ls.p1` | `EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C` |
| Tracked replay | `evidence/mpu4/skill-cash/actions.csv` | `4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D` |
| Input Lua | `evidence/mpu4/skill-cash/input.lua` | `23099F8888AF8DB353253E0DF97638320DC59CA9A47371723A380E0C4EE85C94` |
| MAME 0.281 | `E:\Arcade\MAME0266\mame281.exe` | `0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A` |

The map's `BuildId` and `OutputImageSha256` must both equal the built image
SHA256. The wrapper and checker reject a stale or differently-bound map.

## Wrapper modes

### PrepareOnly (implemented and exercised)

The wrapper accepts either `-Mode PrepareOnly` or the explicit `-PrepareOnly`
switch; the future launch path is available as `-Mode Run` or the explicit
`-Run` switch. `-PrepareOnly` is the only mode used in this task. It:

1. verifies the original/built/map/report/checker/replay/input-Lua/MAME hashes;
2. verifies MAME ProductVersion `0.281`, the pinned executable hash, the installed
   `bgfx/shaders` assets and the `plugins` directory;
3. validates the exact 29-offset image diff, header/body/caller/successor bytes,
   integrity fields and map/build-report bindings;
4. derives exactly 43 VM phases and 14 additional native boundaries from the
   frozen final map and the tracked correction table;
5. builds a 56-stage ordered plan: the `7793` phase and its port-safe boundary
   share one physical stage, all other phases and boundaries occupy one stage
   each; conditional `7799/779B` and `7786/7788` stages carry explicit
   `f1EntryNonZero` / `f1ExitNonZero` tags;
6. builds the native byte-frame model from the actual ROM push/pull instructions
   at `49C5` (`3416`), `49CE` (`3404`), `49D0` (`3401`), `49E0` (`3501`),
   `4A21` (`3502`) and `4A23` (`3596`), plus `777A/777E` (`3420/3520`);
7. creates a fresh create-only run directory with empty isolated
   `cfg/nvram/inp/snap/comments/state/diff` directories;
8. copies the built image to `roms/m4addr/a6ls.p1`, copies the frozen map,
   report, checker report, replay and input Lua, and copies the tracked observer;
9. generates `lamp-natural-map.lua`, `lamp-natural-plan.json`,
   `session-config.lua`, `session-config.json`, `observer.lua` and
   `arguments.template.json`;
10. validates the arguments template for the isolated imgui/BGFX shape and
    forbidden-switch absence;
11. re-hashes the frozen inputs and records `mameLaunched=false`,
    `launchCount=0`, `retryAllowed=false` and
    `naturalExecutionClaimed=false`.

Example (no launch):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Capture-IlLampNatural.ps1 `
  -Mode PrepareOnly -RunDirectory <fresh-private-run-directory>
```

`-PrepareOnly` creates no `events.jsonl`, `run-record.json`, `exit-code.txt` or
`arguments.json`. It creates only `arguments.template.json`.

### Run (implemented, not invoked here)

`-Run` accepts only a prepared `prepared_no_launch` session. It re-validates the
prepared assets including `lamp-natural-plan.json`, writes `arguments.json`,
creates a create-only `launch-lock.json` immediately before launch, and starts
MAME exactly once with the run-local replay and observer. There is no retry, no
timeout retry and no fallback. After the launch it re-hashes the run-local ROM
and original ROM and runs the offline checker. A failed launch or rejected
capture is preserved as `capture-failure.json` and is not retried.

The `-Run` switch and the functions' `$RunPath` parameters are distinct names;
the switch only selects `Mode='Run'`. `-PrepareOnly` cannot reach the launch
function, and the failure record reports the actually observed launch flag, not
the requested mode.

### Analyze / Verify (offline)

Both run the offline checker against an existing run directory. `Verify` does not
write an analysis file. No evidence path under `evidence/mpu4` is written by any
mode in this task.

## Ordered Lua state machine (repair of attempt 1)

Attempt 1 armed all observation breakpoints at reset. The repaired observer does
not.

- At reset, the initial reset-vector breakpoint is the only breakpoint. On the
  reset stop it is cleared and only the first plan stage is armed:
  `PC=00FC && Y=9F14`.
- Before the target is captured, no port, native, frame-write or later VM
  breakpoint exists. Ordinary startup service calls at `49C5`, `7793` and the
  other service PCs cannot stop the observer.
- After the target is captured, each stop clears the previous owned breakpoint and
  arms only the next currently reachable stage. The `7793` phase and its
  `port-f1-set-read` boundary are one physical stage and are recorded as two
  logical records with the same `stopId` and emulated time.
- `00F1` is read as regular RAM at `7793` and `7780`. The `BEQ` tests the entire
  byte, not bit 0. If the byte is zero, the `7799/779B` or `7786/7788` stages are
  skipped and explicit `boundary_skipped` events are emitted. If non-zero, the
  corresponding stages are armed. Entry and exit decisions are independent.
- The arming read precedes the `LDA`, so the observer also proves the actual
  branch path from CPU state: at `779E` (entry) and `00FC` (exit) `A` must equal
  the value produced by the taken `BEQ` path. This detects a `00F1` change
  between the arming read and the `LDA` instead of silently accepting a
  different branch.
- The state machine keeps a monotonic stage index and a strictly increasing
  emulated-time check. A repeated paused state is deduplicated by
  `PC:CURPC:time` and is not recorded twice. A stop that does not match the armed
  stage fails with `unexpected_stop`; a wrong `U/S/X/Y` at the target fails with
  `phase_u`/`phase_s`/`phase_x`/`phase_y`, not a timeout.
- The plan has 56 physical stages for 43 phases plus 14 boundaries because
  `7793` is shared. There is no 57-stop acceptance gate. Conditional branch
  stops are enumerated from the measured `00F1` values.

## Native byte-address frame (repair of attempt 1)

The earlier observer assumed the saved cursor was always the top word at `S`.
That is false inside the native prologue. The repaired model derives the exact
frame from the ROM:

| Point | S | Bytes above the return address | Word at S |
| --- | ---: | --- | --- |
| `49C5` entry | `0790` | return `777E` at `0790` | `777E` |
| after `PSHS A,B,X` (`3416`) at `49C7` | `078C` | A=logical ID, B=pattern, X=`8052` | `788F` for the live `78/8F` entry |
| after `PSHS B` (`3404`) at `49D0` | `078B` | mask `01` leading | `0178` |
| after `PSHS CC` (`3401`) at `49D2` | `078A` | CC byte leading | `0401` |
| after `PULS CC` (`3501`) at `49E2` | `078B` | mask `01` leading | `0178` |
| after `PULS A` (`3502`) at `4A23` | `078C` | A, B, X again | `788F` |
| at `777E` after `3596` | `0792` | saved Y `9B24` | `9B24` |

The shared `1026` cursor is at `S+8` (after regs), `S+9` (after mask and after
`PULS CC`), `S+10` (after CC) and `S+2` at `777E`. The bridge saved-Y `9B24` is at
`S+6`/`S+7`/`S+8` and the return `777E` is at `S+4`/`S+5`/`S+6` during the prologue.
The Lua validates those locations; the checker independently derives the same
offsets from the ROM postbytes and the `49BD..49C4` mask table.

Saved-cursor checks are role/offset based:

- `header-trampoline-entry`: outer cursor `9F16` at `S+2`;
- `bridge-saves-y`, `native-return`: shared cursor `1026` at `S+2`;
- `bridge-jsr-entry`: shared cursor `1026` at `S+4`;
- native prologue/epilogue: shared cursor at the offsets above;
- ordinary shared/outer phases: top word at `S+0`.

The four data-stack and four control-stack words are still recorded as raw
diagnostics. They are not labelled as return addresses.

## Lua observer safety contract

- Boundaries come only from native debugger `bpset` stops. The periodic callback
  is only the stopped-state driver; it is not an instruction hook.
- Reads go through `readRam8/readRam16/readRom8/readRom16`, which enforce a
  central allowlist. Any address in `0800..08FF` is rejected before a memory API
  is called. There is no generic `mem:read_*` call anywhere else.
- `0801`, `0802`, `0803` and `080C` are never read. The only evidence is CPU
  register state at `49D7`, `49DA`, `49DD` and `49E0`:
  - `STA $0801` pre-write `A`;
  - `STB $0802` pre-write `B`;
  - `LDB $0803` pre-read state, with the actual loaded response recorded as `B`
    at `49E0`;
  - `ORCC #$50` and `PULS CC` mask state.
- `00F1` is read only as regular RAM at `7793`/`7780`; `080C` is observed only as
  pre-write `A` plus the safe `00F1` state. The mask table `49BD..49C4` is ROM.
- Frame snapshots are only `0100..013F`. Stack words are read only from
  `0668..0675` and `078A..079F`. No broad RAM snapshot crosses `0800`.
- Every phase validates live `PC/X/Y/U/S/DP`, token, operand, control top and
  role/offset saved cursor. Native phases additionally validate the exact byte
  frame and require the top word not to collapse to `777E`.
- The response is the actual post-`LDB` `B` at `49E0`; it is not derived from a
  ROM map or a full-byte response table. The column is recomputed from
  `(response XOR saved logical index) & 0x78 >> 3`.

## Supervisor-61/62/64 corrections applied

- The bridge `BEQ` tests the **entire** `LDA 00F1` byte against zero, not bit 0.
  The offline tests cover `F1=00`, `01`, `80` and `81`.
- `F1=80` takes the toggle path: `ORA #1 -> 81`, then after the native service
  `ANDA #FE -> 80`. `F1=01 -> 01` then `00`; the second branch sees the first
  write's value before clearing. `F1=81` goes to `81` then `80`.
- Entry and exit `00F1` branch decisions are assessed independently from the
  live regular-RAM snapshots. `7799/779B` are required only when the entire byte
  at `7793` is non-zero; `7786/7788` only when the entire byte at `7780` is
  non-zero. Skipped stages are logged, not silently ignored.
- `CC` is saved at `49D0` and restored at `49E2`. The checker compares the live
  `49E2` value with the `49D0` value. `I/F` are required to be masked between
  `ORCC #$50` and `PULS CC`. No full caller-`C4` assumption is made.
- The native prologue boundaries are the actual instruction starts `49C7`,
  `49D0` and `49D2`; mid-instruction `49CF`/`49D1` are negative controls.
- The `U` model includes `066A` after the literals and the shared add; it does
  not jump directly from `0668` to `066C`.
- `shared-after-rotate` and `shared-after-swap` require `X=008F`; the return
  handler requires `X=7931`; the native prefetch `PC=00FC` is never treated as VM
  `Y`.
- Frame writes use the measured pre-value at the target:
  `B = preValue OR mask`, mask `01`. An already-set target is valid evidence of
  the OR operation but is **not** a visible `0 -> 1` transition proof. The
  offline positive fixture deliberately pre-sets `011F` to cover this case.
- Any non-target frame byte change is reported as `frame_delta` and fails clean
  attribution. It is never silently labelled a lamp effect. No whole-RAM
  unchanged and no absolute IRQ-absence claim is made.
- The `7793` phase and `port-f1-set-read` share one physical stop and are bound to
  the same `stopId` and time. No fixed 57-stop count is used.
- Continuation-65 restored the missing live-state helpers: `snapshot`,
  `stateFields`, `frameSnapshot`, the DP probe/reason and the
  `dataStack0..3`/`controlStack0..3` raw diagnostics. Without those definitions
  the observer could not have produced a first record, and the previous static
  checks did not detect the omission. The checker now asserts each helper is
  defined and that the actual branch-path `A` field is emitted.
- The arming byte is still the regular-RAM byte read at `7793`/`7780`, not a
  response or map byte. The post-`BEQ` `A` proof is the CPU-observed value; it is
  not derived from a static count.

## Frame, stack and result contract

- Frame before: `0100..013F` at `49C5`.
- Native epilogue: `0100..013F` at `4A23`.
- Frame after: `0100..013F` at `777E`.
- Per-write stops: `49F8 -> 010F`, `4A04 -> 011F`, `4A11 -> 012F`,
  `4A1E -> 013F`, with `X=010F` and offsets `00/10/20/30`.
- Predicted effect for index `0`, logical id `78`, pattern `8F`: mask `01`,
  response-derived column `15`, targets `010F/011F/012F/013F`.
- Expected stack shape: `U=066E`, `S=0798`; `U -> 0668 -> 066C -> 066E`;
  `S -> ... -> 078A` and back; net `U=0`, net `S=0`; control tops `1026` and
  `9F16` are accepted only at the proved phases.
- Final result top `0000`, successor word `75A9`, outer return `9F16`.

## Offline verification performed

No full C# build was run. The tools are PowerShell/Lua only.

Command (exit 0):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/worker/Test-IlLampNatural.ps1 `
  -Mode Test -ArtifactDirectory artifacts/deepseek/il-lamp-natural-tools-finish-65/selftest-final-02
```

Result: **179 checks, 0 failures, pass true.** Output is preserved under
`artifacts/deepseek/il-lamp-natural-tools-finish-65/selftest-final-02/`. Direct
`-Mode Check` exits were also recorded: the `F1=00` positive fixture exited 0
with `synthetic_fixture_value_check_passed_not_evidence` and
`naturalClaim=false`; the `F1=80` bit-0-mistake negative exited 1 with
`branch_coverage`. The suite includes:

- PrepareOnly positive preflight/no-launch proof, including the ordered plan and
  native frame assets;
- PrepareOnly rejection of a wrong original ROM, wrong map, wrong report, wrong
  MAME executable and an existing/not-fresh run directory;
- an independent ROM-byte-derived native stack test for `3416/3404/3401/3501/
  3502/3596` and `3420/3520`, including the exact `078C/078B/078A/0792` offsets
  and the `49BD..49C4` mask table;
- an independent ordered-plan test: first stage is `PC=00FC/Y=9F14`, an unrelated
  pre-target `49C5` call is not armed, a wrong target `U` fails rather than
  times out, a later dispatcher phase is rejected while `00F8` is next, the
  `7793` phase/boundary share one stage, and `F1=00`/`F1=80` choose the correct
  next conditional stages at entry and exit;
- static checks that the observer defines `snapshot`, `stateFields`,
  `frameSnapshot`, `probeDpState`, the raw `dataStack0..3`/`controlStack0..3`
  fields and the actual branch-path `A` proof, catching the continuation-65
  missing-helper defect;
- positive synthetic value fixtures for `F1=00`, `01`, `80`, `81`, including an
  already-on `011F` target;
- synthetic fixtures are marked `SYNTHETIC`, are never natural evidence, and are
  rejected unless `-AllowSynthetic` is explicitly used for checker validation;
- negative controls for wrong built/map/report/replay identity, wrong PC, non-fresh NVRAM,
  forbidden `-playback`, injection flags, active-I/O peek, missing phase,
  mid-instruction PC, the `F1=80` bit-0 mistake, wrong frame write, non-target
  frame delta, missing coin, logical-vs-physical stop count, wrong cursor, DP,
  `U`, `S`, `X` after swap, `CC` restore, result/successor and caller token,
  unexpected set-branch stop, and the repaired native defects:
  `w@S=777E` inside the prologue, pattern endian, wrong saved CC, wrong return
  slot, wrong ROM mask, wrong live entry A, wrong native-return saved-cursor
  offset, wrong native frame-write top, and an out-of-order ordered plan.

PrepareOnly smoke command (exit 0):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Capture-IlLampNatural.ps1 `
  -Mode PrepareOnly -RunDirectory artifacts/deepseek/il-lamp-natural-tools-finish-65/prepare-final-01
```

The final direct run exited 0 and reported `status=prepared_no_launch`,
`mameLaunched=false`, `launchCount=0`, 43 phases, 14 boundaries, 56 ordered
stages, 10 preflight checks and the exact frozen hashes. No `events.jsonl`,
`run-record.json`, `exit-code.txt`, `arguments.json` or `launch-lock.json` was
created, and no MAME process was present.

A Lua interpreter and Python Lua binding are not installed in this environment
(`lua`, `luac`, `lupa` absent). No real Lua parse or MAME load was performed, and
Lua syntax is **not** claimed proven. The checker records
`luaParserStatus=absent_no_parser_available` and
`luaSyntaxProof=not_claimed_without_parser`. The static checks confirm the
observer uses the ordered stage plan and the native frame model, has no
reset-time all-breakpoint arming table, and has only two `mem:read_u8` call
sites, both behind the central allowlist.

## Not performed

- No MAME launch, natural capture, save state, debugger write, seed, injection or
  playback.
- No compiled ROM emission or integrity repair.
- No `evidence/mpu4/integrity/il-lamp-pattern-natural.json`.
- No claim of natural reachability, live `0803` response, live `00F1` branch,
  live frame delta, IRQ interleaving, physical hardware compatibility, M5
  completion or supervisor acceptance.

## Limitations and exact continuation

The first unresolved item is the natural gate itself:

1. Whether the tracked replay reaches `PC=00FC, Y=9F14, word=1010` naturally.
2. The live `0803` response and response-derived column.
3. The live `00F1` values and the actual `011F`/frame delta.
4. Whether debugger pauses alter the characteriser response.
5. Whether the installed MAME debugger accepts the ordered single-stage
   `bpset` predicates (`y==...` and `1`) used by the repaired observer.

After supervisor review, the next bounded task should be a single fresh natural
capture using `-Mode PrepareOnly` followed by exactly one `-Mode Run`, with no
retry. Only after that run passes the offline checker should a curated evidence
file or promotion beyond `pending_review` be considered.

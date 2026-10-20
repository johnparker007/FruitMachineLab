# IL lamp-clear observer and offline checker

Status: **tools implemented and offline-verified only. No MAME process was
launched, no natural capture exists and no natural-execution, visible-lamp,
hardware or supervisor-acceptance claim is made.** This report records the
bounded task `il-lamp-clear-observer-72` on base `main`
`6bf78dd54856c58a379c678fe0b55c9637571a02`. It is a narrow clear-specific
derivative of the accepted 67 final observer tools. The frozen 8F wrapper, Lua,
checker, builders, maps, replay and input scripts were read only and are
unchanged.

The next boundary remains a separately dispatched single fresh natural `9F14`
capture of the exact clear image after supervisor review. This task deliberately
does not launch MAME, including for syntax probes.

## Delivered tools

| File | Purpose |
| --- | --- |
| `tools/Capture-IlLampClearNatural.ps1` | Create-only `-PrepareOnly` preflight/template generation, optional future single `-Run`, and offline `-Analyze`/`-Verify` wrapper for the clear image. |
| `tools/lua/IlLampClearNatural.lua` | Lua observer using native debugger `bpset` stops, the ordered stage state machine, dynamic response-derived frame targets, and the clear `before & ~mask` write algebra. |
| `tests/worker/Test-IlLampClearNatural.ps1` | Independent offline checker, ROM-derived native-frame test, ordered-arming simulation, clear synthetic fixtures and negative controls. |
| `docs/recovery/IL-LAMP-CLEAR-OBSERVER.md` | This report. |

No ROM was emitted, injected or repaired. The accepted task-71 clear image, map,
build report, supervisor checker report, original ROM, tracked replay and tracked
input Lua were read only and re-hashed.

## Frozen inputs

| Item | Path | SHA256 |
| --- | --- | --- |
| Clear built image | `artifacts/deepseek/il-lamp-clear-build-71/supervisor-worker-final/positive-01/lamp-clear-repaired.p1` | `347D475E20C194F374DF85A04894BC68D89E05043CA89C5B031316868240EB88` |
| Clear source map | `artifacts/deepseek/il-lamp-clear-build-71/supervisor-worker-final/positive-01/lamp-clear-pattern-source-map.json` | `1845ED2A98B8347B8618D7E9A6E7AFD68B3CF14532C20268AAE273DD782E83B1` |
| Clear build report | `artifacts/deepseek/il-lamp-clear-build-71/supervisor-worker-final/positive-01/build-report.json` | `7AB2A92DF65F77E822FD92F30D8B966E96CA3C762873201F438FFAFD2011416D` |
| Supervisor checker report | `artifacts/deepseek/il-lamp-clear-build-71/supervisor-worker-final/checker-report.json` | `5AD340A519808DA82903DB15E0055DC31384E5684F6ECCF685364DCE89B42630` |
| Original ROM | `artifacts/deepseek/il-natural-06/runs/original-01/roms/m4addr/a6ls.p1` | `EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C` |
| Tracked replay | `evidence/mpu4/skill-cash/actions.csv` | `4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D` |
| Input Lua | `evidence/mpu4/skill-cash/input.lua` | `23099F8888AF8DB353253E0DF97638320DC59CA9A47371723A380E0C4EE85C94` |
| MAME 0.281 | `E:\Arcade\MAME0266\mame281.exe` | `0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A` |

The clear image SHA1 is
`F2083249845955D91945E589807C22E730D78FC3`; the original ROM SHA1 is
`402D1518BB78FDC489B06C2AABC771E5CE151847`; length is `65536`. The map
`BuildId` and `OutputImageSha256` must both equal the built image SHA256. The
wrapper and checker reject a stale or differently bound map. No hash
auto-detection or fallback exists.

## Clear payload and allocation

The reviewed clear allocation is the accepted 24-byte `1010-1027` lamp word with
only the pattern operand changed:

```text
1010-1011 : 00F8
1012-1027 : 795BFF80787E795BFF807AAF7963007963809C44792F
1023      : 80  (clear pattern; the reviewed 8F word has 8F here)
9F14-9F15 : 1010 (same-size caller redirect; successor 75A9)
```

The clear payload is:

```text
00F8795BFF80787E795BFF807AAF7963007963809C44792F
```

The allocation remains 24 of 992 approved bytes, leaving 968. Guards
`1000-100F` and `13F0-13FF` are preserved, and `1028-13EF` remains unallocated
`FF`. The two `FF` holes at `1014`/`101A` are identical to the reviewed 8F word.
The original `9ED7`/`9ED9` bytes, shared service and caller parent context are
preserved.

## Clear semantics used by the observer

- Table index `0` selects logical ID `78` and mask `01`.
- Pattern `80` has low nibble `0`, so all four frame banks take the clear
  branch. The original `49C5` service clears the mask bit in each bank:
  `after = before & ~01`. The build-time algebra covers all 256 before values;
  no other bit is permitted to change.
- Pattern-sensitive `X` after `ROT`/`SWAP` is `0080`, not `008F`. Native entry
  registers are `A=78`, `B=80`; the saved register word at the native frame is
  `7880`.
- The deepest native frame is `S=078A`; stack positions and cursors remain the
  accepted 61/67 relative contracts (`U=066E`, `S=0798` at the outer boundaries,
  `1026` shared cursor, `9F16` outer cursor).
- The future `0803` response and column are **unknown until the CPU read**.
  The observer computes
  `column = ((response0803 XOR savedLogicalIndex) & 0x78) >> 3` from the actual
  post-`LDB` `B` at `49E0`. It does not pin targets to `010F` and does not use
  the static map's historical column-15 record as a live address.
- Frame targets are `0100 + column + [0x00,0x10,0x20,0x30]`. All `0100..013F`
  bytes are tracked before and after. A per-write record requires
  `preWriteB = before & ~mask` and the resolved post-write target to equal that
  value; non-target frame bytes must be unchanged.
- At least one target mask bit must actually change `1 -> 0` to claim a frame
  RAM transition. If all four target bits are already clear, the checker returns
  the explicit `inconclusive_no_frame_transition` status and never accepts the
  capture as visible transition proof.
- A frame-RAM delta is **not** photographed physical lamp output. The checker
  states that limitation and does not claim full characteriser response,
  orientation or hardware behaviour.

## Wrapper modes

### PrepareOnly (implemented and exercised)

`-Mode PrepareOnly` or `-PrepareOnly`:

1. verifies the original/clear/map/report/checker/replay/input-Lua/MAME hashes;
2. verifies MAME ProductVersion `0.281`, the pinned executable hash, the installed
   `bgfx/shaders` assets and the `plugins` directory;
3. validates the exact 29-offset final diff, the clear 24-byte allocation,
   pattern byte `80` at `1023`, caller/successor bytes, integrity fields and
   map/build-report bindings;
4. derives 43 clear VM phases from the frozen clear map and the reviewed 14
   runtime boundary records (five native port-save boundaries, the `7793` set read,
   four dynamic frame writes and four conditional `00F1` writes);
5. builds the 56-stage ordered plan; the `7793` phase and its port-safe boundary
   share one physical stage, and conditional `7799/779B` and `7786/7788` stages
   carry `f1EntryNonZero`/`f1ExitNonZero` tags;
6. derives the native byte-frame model from the ROM push/pull instructions at
   `49C5/49CE/49D0/49E0/4A21/4A23` and `777A/777E`;
7. creates a fresh create-only run directory with empty isolated
   `cfg/nvram/inp/snap/comments/state/diff` directories;
8. copies the clear image, map, report, checker report, replay, input Lua and
   tracked observer, and generates the clear map Lua, plan, config and observer
   composition;
9. validates the arguments template for the isolated imgui/BGFX shape and
   absence of playback/state/seed/script switches;
10. re-hashes the frozen inputs and records `mameLaunched=false`,
    `launchCount=0`, `retryAllowed=false` and
    `naturalExecutionClaimed=false`.

`PrepareOnly` creates no `events.jsonl`, `run-record.json`, `exit-code.txt`,
`arguments.json` or `launch-lock.json`; it creates only
`arguments.template.json` plus the prepared metadata.

Example (no launch):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Capture-IlLampClearNatural.ps1 `
  -Mode PrepareOnly -RunDirectory <fresh-private-run-directory>
```

### Run (implemented, not invoked here)

`-Run` accepts only a prepared `prepared_no_launch` session. It re-validates the
prepared assets, writes `arguments.json`, creates a create-only
`launch-lock.json` immediately before launch, records the immediate prelaunch
inventory, and starts MAME exactly once with the run-local replay and observer.
There is no retry, timeout retry or fallback. After the launch it re-hashes the
run-local and original ROMs and runs the offline checker. A failed launch or
rejected capture is preserved as `capture-failure.json` and is not retried.
This mode was **not** used in task 72.

The checker now requires `prelaunch-freshness.json` for every checked run. The
file must be a readable JSON object containing exactly the seven keys `cfg`,
`nvram`, `inp`, `snap`, `comments`, `state` and `diff`, and every value must be
a strict integer `0`. A missing file, malformed JSON, missing or extra key,
`null`, string (including `"0"`), negative or nonzero value is rejected. There is
no historical-capture exception in this profile. The wrapper still writes the
inventory only inside `-Mode Run`, immediately before its single launch.
`PrepareOnly` therefore neither writes this file nor claims an actual prelaunch
observation. Offline fixtures write zeroed inventory records but label their
origin in metadata and the run record as
`synthetic_checker_fixture_not_an_actual_prelaunch_observation`; they are never
natural evidence.

### Analyze / Verify (offline)

Both run the offline checker against an existing run directory. `Verify` does not
write an analysis file. No path under `evidence/mpu4` is written by any mode in
this task.

## Ordered Lua state machine

- At reset only the reset-vector breakpoint exists. On the reset stop it is
  cleared and only the first plan stage is armed: `PC=00FC && Y=9F14`.
- Before the target is captured, no port, native, frame-write or later VM
  breakpoint exists. Ordinary startup service calls cannot stop the observer.
- After the target is captured, each stop clears the previous owned breakpoint
  and arms only the next currently reachable stage. The `7793` phase and its
  port-safe read share one physical stop.
- `00F1` is read as regular RAM at `7793` and `7780`. The `BEQ` tests the entire
  byte, not bit 0. If the byte is zero, the corresponding optional stages are
  skipped and explicit `boundary_skipped` events are emitted. Entry and exit
  decisions are independent.
- The arming read precedes the `LDA`, so the observer also proves the actual
  branch path from CPU state at `779E` and `00FC`. A repeated paused state is
  deduplicated by `PC:CURPC:time`. A wrong armed-stage stop, `U`, `S`, `X` or
  `Y` fails explicitly rather than timing out.
- The plan has 56 physical stages for 43 phases plus 14 boundary records because
  `7793` is shared. There is no fixed physical-stop acceptance count; the
  checker derives it from the actual unique stop records.

## Dynamic column and clear frame contract

At `native-epilogue-puls-cc` (`49E2`) the observer reads the saved logical index
at `S+1`, the saved mask at `S`, and the actual post-`LDB` `B` response recorded
at `49E0`. It computes the column and records the frame base:

```text
column    = ((response0803 XOR savedLogicalIndex) & 0x78) >> 3
frameBase = 0x0100 + column
```

For every frame write (`49F8`, `4A04`, `4A11`, `4A1E`) it requires:

```text
X               = frameBase + write offset
mask            = 01
preWriteB       = before & ~mask
post target     = preWriteB
non-target frame bytes unchanged
```

The four write boundary IDs are column-neutral (`frame-write-00/10/20/30`), not
`frame-write-010f` etc. The checker independently recomputes the expected targets
from the phase's actual `column` field. Synthetic fixtures cover actual response
columns `0` and `15`, mixed before-bit states, and the all-already-clear
inconclusive case. The static build report's historical `observedColumn=15` is
treated as a static record, not a live expectation.

## Lua observer safety contract

- Boundaries come only from native debugger `bpset` stops. The periodic callback
  is the stopped-state driver, not an instruction hook. No instruction-callback
  claim is made.
- Reads go through `readRam8/readRam16/readRom8/readRom16`, which enforce a
  central allowlist. Any address in `0800..08FF` is rejected before a memory API
  is called. There is no generic `mem:read_*` call outside the two central
  `mem:read_u8` sites.
- `0801`, `0802`, `0803` and `080C` are never read. The only evidence is CPU
  register state at `49D7`, `49DA`, `49DD` and `49E0`. The CPU `0803` response is
  only the actual post-`LDB` `B` at `49E0`.
- `00F1` is read only as regular RAM at `7793`/`7780`; `080C` is observed only as
  pre-write `A` plus the safe `00F1` state. The mask table `49BD..49C4` is ROM.
- Frame snapshots are only `0100..013F`. Stack words are read only from
  `0668..0675` and `078A..079F`. No broad RAM snapshot crosses `0800`.
- Every phase validates live `PC/X/Y/U/S/DP`, token, operand, control top and
  the role/offset saved cursor. Native phases validate the exact byte frame and
  require the top word not to collapse to `777E`. `DP` is reported raw with an
  honest unknown-width reason when the installed CPU state API cannot expose it.
- `CC` is saved at `49D0` and restored at `49E2`; the checker compares the live
  `49E2` value with the same `49D0` snapshot, not the entry CC. `I/F` are
  required to carry actual mask bits `0x50` around the port accesses.
- The callback uses `xpcall` and fails closed. There is no synthetic state input,
  debugger write, save state, playback, seed or MAME launch in this task.

## Offline verification performed

No C# build was run; the tools are PowerShell/Lua only.

Self-test command (exit 0; task 72 historical location):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  tests/worker/Test-IlLampClearNatural.ps1 -Mode Test `
  -ArtifactDirectory artifacts/deepseek/il-lamp-clear-observer-72/selftest-05
```

Task 72 result: **239 checks, 0 failures, pass true.** The repair rerun command
and result are:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  tests/worker/Test-IlLampClearNatural.ps1 -Mode Test `
  -ArtifactDirectory artifacts/deepseek/il-lamp-clear-observer-repair-73/selftest-02
```

Repair 73 result: **269 checks, 0 failures, 54 negative controls, pass true.**
Logs and `checker-selftest.json` are under the private artifact directories.

Direct PrepareOnly smoke command (exit 0):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  tools/Capture-IlLampClearNatural.ps1 -Mode PrepareOnly `
  -RunDirectory artifacts/deepseek/il-lamp-clear-observer-72/direct-prepare-01
```

Recorded result: `status=prepared_no_launch`, `mameLaunched=false`,
`launchCount=0`, 43 phases, 14 runtime boundary records, 56 stages, no
`events.jsonl`, `run-record.json`, `exit-code.txt`, `arguments.json` or
`launch-lock.json`, and no new MAME process.

Direct checker exits on the synthetic F1=00 fixture:

- `-AllowSynthetic`: exit 0, `pass=true`,
  `status=synthetic_fixture_value_check_passed_not_evidence`,
  `naturalClaim=false`, column 15, one actual transition,
  `clearVisibleTransitionProof=false` and
  `syntheticTransitionValueCheck=true` (a diagnostic, not proof).
- without `-AllowSynthetic`: exit 1, `pass=false`, failure
  `synthetic_not_allowed`.

`clearVisibleTransitionProof` is now true only for an accepted complete natural
capture with at least one actual mask `1 -> 0` transition. It remains false for
synthetic value checks, failed results, inconclusive no-transition results and
`PrepareOnly` sessions. `clearTransitionCount`, columns and targets remain
diagnostics.

The suite includes:

- PrepareOnly positive preflight/no-launch proof, including 43 phases, 14
  runtime boundary records, 56 stages, no new MAME process, and no
  `prelaunch-freshness.json` actual-observation claim;
- mandatory prelaunch inventory checks for missing file, malformed JSON, missing
  key, `null`, string `"0"`, negative and nonzero values, each rejected by the
  actual checker;
- proof-gating checks: synthetic positive and mixed values never certify
  `clearVisibleTransitionProof`, failed results with a transition keep the proof
  false, all-already-clear remains inconclusive, and the pure natural-value
  eligibility logic is tested as synthetic test machinery without any natural
  evidence file;
- PrepareOnly rejection of a wrong original ROM, wrong map, wrong report, wrong
  MAME executable, an existing/not-fresh directory and the reviewed 8F image;
- an independent ROM-byte-derived native stack test for
  `3416/3404/3401/3501/3502/3596` and `3420/3520`;
- an explicit net `U`/`S` balance check at the outer return, plus an independent ordered-plan test (first stage `PC=00FC/Y=9F14`, no pre-target
  49C5 arming, wrong target `U` fails immediately, later dispatcher rejected,
  `7793` phase/boundary co-location, and `F1=00`/`F1=80` entry/exit choices);
- Lua static checks for the ordered plan, native frame, two central
  `mem:read_u8` sites, no active-I/O naming, ROM byte operands, actual 49D0 CC
  snapshot, required helpers, branch-path `A`, dynamic frame base, dynamic
  column formula and clear algebra;
- synthetic fixtures for `F1=00/01/80/81`, response columns `0` and `15`, mixed
  before-bit states and the all-already-clear inconclusive case, all prominently
  `SYNTHETIC`, all with `naturalClaim=false`;
- preserved 67 negative controls plus clear-specific controls for the 8F image,
  stale map, `008F` X/operand, `788F` saved-register word, clear `OR` instead of
  `AND`, omitted zero-F1 skip records, wrong prelaunch freshness, wrong CC
  save/restore, forbidden I/O read and an unknown exception fail-closed case.

A Lua interpreter and Python Lua binding are not installed in this environment
(`lua`, `luac`, `lupa` absent). No real Lua parse or MAME load was performed, and
Lua syntax is **not** claimed proven. The checker records
`luaParserStatus=absent_no_parser_available` and
`luaSyntaxProof=not_claimed_without_parser`. The static checks confirm the
observer uses the ordered stage plan, the dynamic clear contract and the central
allowlist.

## Not performed

- No MAME launch, natural capture, syntax probe, save state, debugger write,
  seed, injection or playback.
- No compiled ROM emission or integrity repair.
- No `evidence/mpu4/integrity/il-lamp-clear-natural.json`.
- No claim of natural reachability, live `0803` response, live frame transition,
  IRQ interleaving, physical lamp output, physical hardware compatibility, M5
  completion or supervisor acceptance.

## Limitations and exact continuation

The first unresolved item is the natural gate itself:

1. Whether the tracked replay reaches `PC=00FC, Y=9F14, word=1010` naturally
   for the clear image.
2. The live `0803` response and the actual response-derived column.
3. The live `00F1` values and whether at least one frame target bit actually
   changes `1 -> 0`.
4. Whether debugger pauses alter the characteriser response.
5. Whether the installed MAME debugger accepts the ordered single-stage
   `bpset` predicates used by the observer.

After supervisor review, the next bounded task should be exactly one fresh
natural capture using `-Mode PrepareOnly` followed by one `-Mode Run`, with no
retry. Only after that run passes this offline checker should a curated evidence
file or promotion beyond `pending_review` be considered.

## Compact review result

- Task: `il-lamp-clear-observer-72`; base `6bf78dd54856c58a379c678fe0b55c9637571a02`.
- New tracked files: `tools/Capture-IlLampClearNatural.ps1` SHA256
  `A12DEF2145B2CD2E1441DC748C194448C03D49ECEFE5F6515B6F4B5DD39F5F48`;
  `tools/lua/IlLampClearNatural.lua` SHA256
  `9E7DEF2E0146E9E4EE6E1AB0C8E9B22AD5F375228B0A2968B2CF36996E669058`;
  `tests/worker/Test-IlLampClearNatural.ps1` SHA256
  `986CFCA66127BE596694F6897DA92DE3FF9867D399BB1FCDFD278AF9A1F2842C`.
- Offline self-test: 239 checks, 0 failures, exit 0.
- PrepareOnly: exit 0, `prepared_no_launch`, no MAME launch.
- Direct synthetic checker: exit 0 with `-AllowSynthetic`; exit 1 without it.
- Lua parser: absent; syntax proof explicitly not claimed.
- Natural claim: false. Supervisor acceptance: not claimed.

## Repair 73 compact review result

- Task: `il-lamp-clear-observer-repair-73`; base
  `6bf78dd54856c58a379c678fe0b55c9637571a02`.
- Tracked-change scope: `tests/worker/Test-IlLampClearNatural.ps1` and this
  document. The wrapper and Lua observer are unchanged from task 72.
- `tests/worker/Test-IlLampClearNatural.ps1` SHA256
  `258734DA373133E64139C6AD6AEA9223956C39D060B9A322D4F39233975165C7`.
- `tools/Capture-IlLampClearNatural.ps1` SHA256
  `A12DEF2145B2CD2E1441DC748C194448C03D49ECEFE5F6515B6F4B5DD39F5F48`.
  `tools/lua/IlLampClearNatural.lua` SHA256
  `9E7DEF2E0146E9E4EE6E1AB0C8E9B22AD5F375228B0A2968B2CF36996E669058`.
- Final offline self-test: **269 checks, 0 failures, 54 negative controls, exit 0**.
- Supervisor missing-prelaunch reproduction: actual checker exits **1** with
  `prelaunch_freshness` (`Immediate prelaunch inventory file is missing`).
- Direct synthetic positive: exit 0 with `-AllowSynthetic`,
  `naturalClaim=false`, `clearVisibleTransitionProof=false`,
  `syntheticTransitionValueCheck=true`.
- No MAME launch, ROM emission, state/RAM/register write, native C# execution,
  curated evidence, commit or push was performed. Natural claim remains false;
  supervisor acceptance is not claimed.

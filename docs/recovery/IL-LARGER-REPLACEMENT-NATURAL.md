# IL larger replacement natural execution

Status: **one completed natural fresh-boot capture, pending supervisor review;
not accepted.** This report records task `il-larger-replacement-natural-51` on
base `main` `e0320a60eb429128a681075e2be1c8a57aedda2e`. It is a bounded
observation of the already accepted static larger-replacement image; it is not a
supervisor acceptance, a gameplay modification claim, a paid-window proof or a
hardware-compatibility claim. The native C# gameplay executor remains frozen and
unused.

## Exact input image

The task reused the accepted task50 CLI outputs unchanged:

| Item | Value |
| --- | --- |
| Repaired image | `artifacts/deepseek/il-larger-replacement-build-50/cli-check-03/positive-01/larger-repaired.p1` |
| Image SHA1 / SHA256 | `7D81C9828A8A8C882861151E84B676AE05D272BF` / `F693D70A73F1C12857CD64CA9DB9D68DE9BBC1888101ABC283FA2752C094B523` |
| Source map SHA256 | `F638EAC9DD5D2F1E719ED00BA63C80C59079CE5EB2AA2148F7373E50F1E91F1F` |
| Build report SHA256 | `216BF0CF945DB19A0BC702273532D8D8B7DDBB3761EEC3CC0CC40D6DA02C1CE1` |
| Original ROM | `artifacts/deepseek/general-14/roms/original.p1` |
| Original SHA1 / SHA256 | `402D1518BB78FDC489B06C2AABC771E5CE151847` / `EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C` |

The observed image is the corrected 22-byte allocation `1010-1025`: header
`00F8`, body
`795BFF80787E795BFF807AAF795B0001787E792F`, seven nodes, three inline operands
at `1014`, `101A` and `1020`, and one final `792F` at `1024`. Only the `9F14`
caller token `9ED7 -> 1010` is changed outside the allocation; the `FFD1-FFD5`
integrity fields are `E93F3C61B5`. The original ROM, image, map and build report
were not modified.

## Boundary and environment

| Item | Value |
| --- | --- |
| Boundary | `natural-fresh-boot-larger-replacement-1012-observation` |
| Attempt | 1 (the only launch; no rerun) |
| MAME | installed 0.281, SHA256 `0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A` |
| Frontend | `-debugger imgui`, `-video bgfx`, installed BGFX assets |
| Isolation | fresh absent `cfg`/`nvram`/`state`/`inp`/`snap`/`comments`/`diff`, `-noreadconfig` |
| Input | existing tracked `evidence/mpu4/skill-cash/actions.csv` SHA256 `4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D` and `input.lua` SHA256 `23099F8888AF8DB353253E0DF97638320DC59CA9A47371723A380E0C4EE85C94`, physical coin/start replay only |
| Writes | no PC/register/RAM/ROM write, seed, save-state load or input fixture change |
| Result | MAME exit `0`, wall `9.549 s`, no timeout; strict JSONL passed; state and side-effect directories empty |

The observer used only native debugger breakpoints (`cpu.debug:bpset`) at the
contracted boundaries. The Lua periodic callback was the stopped-state driver,
not an instruction hook. The tracked `input.lua` supplied the physical replay and
wrote all raw input rows.

## Observed phases

All seventeen map phases are listed first. The optional post-`75A9` successor is
a separate explicit contract and is not one of the seventeen static map phases.
The static map supplies address/contract inputs only; the values below are live
measurements from the stopped CPU.

| # | Phase | PC | X | Y | U | S | Top | D | Token | Inline operand | Control top | Saved cursor | DP |
| ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | caller-dispatch | 00FC | 0000 | 9F14 | 066E | 0798 | 0000 | 0000 | 1010@9F14 | - | 9F3F | - | 00 |
| 1 | header-trampoline-entry | 00F8 | 1012 | 9F16 | 066E | 0798 | 0000 | 0000 | 00F8@1010 | - | 9F3F | - | 00 |
| 2 | body-prefetch-0 | 00FC | 1012 | 1012 | 066E | 0796 | 0000 | 0000 | 795B@1012 | - | 9F16 | 9F16 | 00 |
| 3 | handler-0 | 795D | 795D | 1014 | 066E | 0796 | 0000 | 0000 | 795B@1012 | FF80@1014 | 9F16 | 9F16 | 00 |
| 4 | body-prefetch-1 | 00FC | 795D | 1016 | 066C | 0796 | FF80 | FF80 | 787E@1016 | - | 9F16 | 9F16 | 00 |
| 5 | handler-1 | 7880 | 7880 | 1018 | 066C | 0796 | FF80 | FF80 | 787E@1016 | - | 9F16 | 9F16 | 00 |
| 6 | body-prefetch-2 | 00FC | 7880 | 1018 | 066E | 0796 | FF80 | FF80 | 795B@1018 | - | 9F16 | 9F16 | 00 |
| 7 | handler-2 | 795D | 795D | 101A | 066E | 0796 | FF80 | FF80 | 795B@1018 | FF80@101A | 9F16 | 9F16 | 00 |
| 8 | body-prefetch-3 | 00FC | 795D | 101C | 066C | 0796 | FF80 | FF80 | 7AAF@101C | - | 9F16 | 9F16 | 00 |
| 9 | handler-3 | 7AB1 | 7AB1 | 101E | 066C | 0796 | FF80 | FF80 | 7AAF@101C | - | 9F16 | 9F16 | 00 |
| 10 | body-prefetch-4 | 00FC | 7AB1 | 101E | 066E | 0796 | 0000 | 0000 | 795B@101E | - | 9F16 | 9F16 | 00 |
| 11 | handler-4 | 795D | 795D | 1020 | 066E | 0796 | 0000 | 0000 | 795B@101E | 0001@1020 | 9F16 | 9F16 | 00 |
| 12 | body-prefetch-5 | 00FC | 795D | 1022 | 066C | 0796 | 0001 | 0001 | 787E@1022 | - | 9F16 | 9F16 | 00 |
| 13 | handler-5 | 7880 | 7880 | 1024 | 066C | 0796 | 0001 | 0001 | 787E@1022 | - | 9F16 | 9F16 | 00 |
| 14 | body-prefetch-6 | 00FC | 7880 | 1024 | 066E | 0796 | 0001 | 0001 | 792F@1024 | - | 9F16 | 9F16 | 00 |
| 15 | return-handler | 7931 | 7931 | 1026 | 066E | 0796 | 0001 | 0001 | 792F@1024 | - | 9F16 | 9F16 | 00 |
| 16 | post-return-prefetch | 00FC | 7931 | 9F16 | 066E | 0798 | 0001 | 0001 | 75A9@9F16 | - | 9F3F | - | 00 |
| 17 | post-75a9-successor (optional contract) | 00FC | 75AB | 9F18 | 066E | 0798 | 0000 | 0000 | 7B7D@9F18 | - | 9F3F | - | 00 |

At the caller and trampoline rows `X`/`D` are prior live values, not asserted
contract values. The trampoline row is the boundary **before** `PSHS Y`: the
live control top is still the parent `9F3F`, and the imminent saved value is
`9F16`. The first live saved cursor `9F16` is at `body-prefetch-0`, where
`S=0796` and `w@S=9F16`.

The key added-node observations were:

- handler-4 at `795D` read the added inline word `0001` at `1020`;
- body-prefetch-5 at `00FC` had `U=066C`, top `0001`, and the next data cell
  `0000`;
- body-prefetch-6 at `00FC` had `U=066E` and top `0001` after the following
  `787E` add;
- the final return prefetch at `Y=1024` carried token `792F`, the return handler
  at `7931` had `Y=1026` and live control top `9F16`, and the actual `PULS Y`
  post-return boundary was `PC=00FC`, `Y=9F16`, `S=0798`, `U=066E`, top `0001`,
  token `75A9`;
- the whole call netted `U=0000` and `S=0000`.

## Callee result and parent-result boundary

The naturally observed callee exit top is `0001`. The naturally observed
successor `75A9` then left top `0000` at `PC=00FC`, `Y=9F18`. The static task49
prediction was `0000 -> 0001 -> 0000`; only the `0001` callee exit and the
`0000` post-`75A9` value are live observations.

This report does **not** claim the parent result. `75A9` normalizes the positive
`0001` to `0000`, so a downstream parent that consumes the normalized value may
remain unchanged. Downstream parent behaviour and gameplay are unresolved.

## DP observation

`cpu.state["DP"]` was sampled directly in every stopped-state snapshot. Every
phase recorded raw `0`, normalized `00`, `dpNormalizedMask=00FF`, and
`dpWidthSource=state_entry_exposes_only_value`. The installed 0.281 state entry
exposed `.value` but not a numeric width property, so `dpWidthBits` is recorded
as `unknown` rather than fabricated. The raw DP value and its explicit 8-bit
normalization are measured; no DP value or width is deduced or invented. `H` was
not defined, output or asserted; `CC` bytes are diagnostics only.

## Input and isolation provenance

The tracked replay produced the expected coin window `2100-2103` and real 60 Hz
start rows `2221-2225`, followed by eighteen native debugger-stop callback rows
`2226-2243`. All raw rows are retained. The last fixture action frame was `2400`
and was not reached. The run used fresh absent configuration/NVRAM/state
directories, `-noreadconfig`, no playback/state/autosave/debugscript, and no
snapshot or input/state side effects. The isolated run ROM after execution was
still the exact built SHA256; the raw `events.jsonl` and observer Lua were not
rewritten.

## Verification and controls

Offline preflight ran before the single MAME launch:

- `tests/worker/Test-IlLargerReplacementNatural.ps1` positive synthetic fixture
  plus negative controls: **198 checks, 0 failures** (`offline-check-02.log`).
- A preserved earlier development run with 196 checks and 4 failures is retained
  as `offline-check-01.log`; it is not evidence of acceptance.
- Strict JSONL, duplicate-key rejection, exact image/map/report/run-local Lua/
  config/observer hashes, MAME invocation isolation, replay/input hashes,
  phase order/completion, DP shape/consistency, D=A:B consistency, saved cursor,
  state/side-effect absence, and input-grid/debug-stop correlation were
  exercised.

After the single capture, a read-only `-Mode Verify` reanalysis reproduced the
same status, event count and event hash. It did not launch MAME or rewrite the
raw event log. The captured observer and capture-tool hashes still match the
sources, so the evidence records `verificationGap.present=false`.

## Evidence classes and limits

- Measured live: PC, CURPC, X, Y, U, S, A, B, D (derived from A/B), CC, DP,
  four data-stack words, four control-stack words, token words and inline
  operands.
- Static inputs: the 17 map phase addresses/tokens/handlers, the task49 stack and
  vector contract, and the source-map binding.
- Observed natural input: the existing tracked physical coin/start replay.
- Not claimed: parent result, gameplay modification, paid window `EE16/EE22`,
  full-game behaviour, relocation/banking, general new-word execution or
  physical MPU4 hardware compatibility.

## Reproduction

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  tests/worker/Test-IlLargerReplacementNatural.ps1 `
  -OutputRoot <fresh-offline-root>

powershell -NoProfile -ExecutionPolicy Bypass -File `
  tools/Capture-IlLargerReplacementNatural.ps1 -Mode Capture `
  -RunDirectory <fresh-run> `
  -BuiltRom artifacts/deepseek/il-larger-replacement-build-50/cli-check-03/positive-01/larger-repaired.p1 `
  -SourceMapPath artifacts/deepseek/il-larger-replacement-build-50/cli-check-03/positive-01/larger-replacement-source-map.json `
  -BuildReportPath artifacts/deepseek/il-larger-replacement-build-50/cli-check-03/positive-01/build-report.json `
  -OriginalRom artifacts/deepseek/general-14/roms/original.p1 `
  -EvidencePath evidence/mpu4/integrity/il-larger-replacement-natural.json

powershell -NoProfile -ExecutionPolicy Bypass -File `
  tools/Capture-IlLargerReplacementNatural.ps1 -Mode Verify `
  -RunDirectory <preserved-run> `
  -BuiltRom artifacts/deepseek/il-larger-replacement-build-50/cli-check-03/positive-01/larger-repaired.p1 `
  -SourceMapPath artifacts/deepseek/il-larger-replacement-build-50/cli-check-03/positive-01/larger-replacement-source-map.json `
  -BuildReportPath artifacts/deepseek/il-larger-replacement-build-50/cli-check-03/positive-01/build-report.json `
  -OriginalRom artifacts/deepseek/general-14/roms/original.p1
```

The reproduction commands are documentation only. This task made exactly one
fresh MAME launch and does not authorize an automatic retry. Raw capture files
remain under `artifacts/deepseek/il-larger-replacement-natural-51/capture/run-01/`;
the curated evidence is
`evidence/mpu4/integrity/il-larger-replacement-natural.json`.

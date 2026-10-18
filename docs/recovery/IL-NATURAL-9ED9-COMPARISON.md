# Natural 9ED9 comparison and changed-image gate

18 October 2026. This report records a fresh-boot natural MAME 0.281 comparison
of the untouched original A6L image and the accepted repaired `9ED9` image. The
original control reaches `EE16 -> EE22` and executes the supported `9ED9` word
naturally. The changed image, with the identical tracked replay and the
declared historical physical pulses, does **not** reach `EE16`; it diverges in
earlier natural `9ED9` calls. This is therefore a recorded gate, not a complete
original/changed target comparison. No seeded state, save state, debugger
write, PC/register/RAM injection or random input is used.

Machine-readable evidence:
[`evidence/mpu4/integrity/il-natural-9ed9-comparison.json`](../../evidence/mpu4/integrity/il-natural-9ed9-comparison.json).
The carry-over plan corrections are in
[`IL-NATURAL-REACHABILITY-PLAN.md`](IL-NATURAL-REACHABILITY-PLAN.md) and its JSON.

## Evidence classes

- **Natural execution:** the four fresh isolated MAME runs below. Inputs are the
  tracked replay plus physical ioport writes; observation is read-only
  debugger `bpset`/`printf` plus the existing Lua state log. No state writes.
- **Static deduction:** the original bytes, the recovered listings, the accepted
  source map and build report, and the `9EDC` edit (`80 -> 00`).
- **Synthetic:** the curator parser negatives and the historical early-call
  interpretation used only for comparison; the negative controls are not
  natural execution evidence.
- **Hypothesis / limit:** the exact gameplay route that would make the changed
  image reach `EE16` with a different physical schedule is not established.

## Corrected VM fetch provenance

The copied trampoline bytes at `7927..792E` are `3420 3184 AEA1 6E91`:

```text
F8: 3420  PSHS Y
FA: 3184  LEAY ,X
FC: AEA1  LDX ,Y++      X = w@Yold (token pointer), Y = Yold + 2
FE: 6E91  JMP [,X++]    PC = w@Xold (code/body pointer), X = Xold + 2
```

At the `PC=00FC` pre-fetch, `Y` is the node/token-word address and `w@Y` is the
token pointer. At a handler entry `Y = node + 2` and `X = tokenPointer + 2`.
For the primitive self-pointing tokens here, `X` numerically equals the handler
entry PC: `795B -> 795D`, `787E -> 7880`, `7AAF -> 7AB1`, `792F -> 7931`.
That equality is not a general rule and is not `X = node + 2`.

The composite call token at `EBCA` is `9ED7`; `w@9ED7 = 00F8`. Its dispatch has
`X = 9ED9` (the body address), not a handler PC. `PC=00F8` runs `PSHS Y; LEAY ,X`,
saving the caller successor `EBCC` on `S` and setting `Y=9ED9`. The runtime
trace below validates both the primitive and composite relations directly.

## Images, build and MAME

| Item | Value |
| --- | --- |
| Original | 65536 bytes, SHA1 `402d1518bb78fdc489b06c2aabc771e5ce151847`, SHA256 `ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c` |
| Changed | 65536 bytes, SHA1 `e1a42dccd304b7b175aabac99e8400cdad04cf69`, SHA256 `577f76bd36dfca04dfb01b5f5d0be93e16572f8617c7ca906397c98df36e5107` |
| Changed offsets | `9EDC`, `FFD1..FFD5`; `9EDB..9EDC = FF80 -> FF00` |
| Source map | SHA256 `0c39a6d0d1beac32ca0f64bfec5ce848b2297be41180d0234d2bfdf491df21a9`, bound to the changed SHA256 `577f...5107` |
| Build report | SHA256 `ae7e0fb2c0121e0b4e62d38e82511841644fcdf922b2d9e54de79b3d7e57f61a` |
| MAME | `E:\Arcade\MAME0266\mame281.exe`, `0.281 (mame0281)`, SHA256 `0fce5a88df4f9d9b1fbf1405812c00848036e615993780978d967da34204cb7a` |
| Replay | `evidence/mpu4/skill-cash/actions.csv`, SHA256 `4a051da15264842697879eff396b34a789f5d80623f9a2e749c244e6a80e721d`, 1249 events |

The original and changed runs each copied exactly one image into a fresh
`roms/m4addr` directory, used fresh `cfg/nvram/inp/snap/comments/state/diff`
directories, `-noreadconfig`, `-seconds_to_run 1200`, and no save-state load or
MAME playback. The pre-run directory file counts were zero. The run ROM copies
were rehashed after execution and were unchanged. Both runs passed the original
firmware checker: original expected fields `3E761E2605`; changed expected fields
`BEF69E7CC7`; no failure marker. The repaired image's MAME loader warning is
separate from that checker.

## Physical inputs

The tracked replay is replayed from frame 0. The control's scripted pulses are
exactly the historical five:

| Reason | Scheduler first..last | Port/mask | Observed assertion |
| --- | --- | --- | --- |
| `take_nudge_entry` | 23734..23746 | `:BLACK2` 1 | frames 23735..23746 |
| `nudge1_request` | 23746..23752 | `:BLACK2` 2 | frames 23747..23752 |
| `nudge1_repeat` | 23769..23775 | `:BLACK2` 4 | frames 23770..23775 |
| `paid_start` | 24400..24412 | `:BLACK2` 128 | frames 24401..24412 |
| `ordinary_paid_nudge1` | 26136..26142 | `:BLACK2` 2 | frames 26137..26142 |

The run-local `input-levels.csv` asserts each event beginning one frame after
the scheduler's `first_frame` and releases it at `last_frame+1`. The merged
`physical-inputs.csv` records scheduler press/release plus observed
press/last-pressed/release frames. The changed run's adaptive pulses differ
(two pulses: `paid_start` at 24400..24412 and `ordinary_paid_nudge1` at
25254..25260), because its game state has already diverged. The physical inputs
are therefore **not identical**; this is part of the gate, not a success.

## Original control: natural target

The control reached `EE16` and stopped at the first `EE22` after the window
(wall 38.976 s, exit 0). The observed pre-fetch/handler phase is:

```text
TAIL y=EE16 token=7ECB u=0672 s=07A6 b0305=10 c=000000 credit=02 bank=0010
PF  EBCA token=9ED7 u=066A top=0000 second=1F40 s=07A4
CT  PC=00F8 X=9ED9 Y=EBCC S=07A4 sw0=EE22
PF  9ED9 token=795B op0=FF80 rom9edb=FF80 u=066A top=0000 second=1F40 s=07A2
HE  795D token=795B X=795D Y=9EDB u=066A top=0000 second=1F40
PF  9EDD token=787E u=0668 top=FF80 second=0000
HE  7880 token=787E X=7880 Y=9EDF u=0668 top=FF80 second=0000
PF  9EDF token=795B op0=FF80 u=066A top=FF80 second=1F40
HE  795D token=795B X=795D Y=9EE1 u=066A top=FF80 second=1F40
PF  9EE3 token=7AAF u=0668 top=FF80 second=FF80
HE  7AB1 token=7AAF X=7AB1 Y=9EE5 u=0668 top=FF80 second=FF80
PF  9EE5 token=792F u=066A top=0000 second=1F40
HE  7931 token=792F X=7931 Y=9EE7 u=066A top=0000 second=1F40 s=07A2 sw0=EBCC
PF  EBCC token=7CB3 u=066A top=0000 second=1F40 s=07A4 sw0=EE22
TERM y=EE22 token=9FA0 u=0672 s=07A6 b0305=10 c=FFE0C0 credit=02 bank=0010
```

The literal, addition, second literal, XOR and return are therefore traced at
the real handlers. With 16-bit arithmetic, the first literal is added to the
existing top `0000`, then XORed with the second literal `FF80`:

```text
((FF80 + 0000) AND FFFF) XOR FF80 = 0000
```

The caller continuation is `EBCC`, and `07D5..07D7` finishes at `FFE0C0`.
Credit `2F0=02`, bank `2FC=0010` and `0305=10` are unchanged across the window.

## Changed run: exact gate

The changed run passed firmware integrity and executed naturally for 1200
emulated seconds (wall 99.987 s, exit 0) but never reached `EE16`; there is no
`TAIL`, `TERM`, target `PF`, `HE` or `CT` line, and no target-window counter was
observed. The recorded physical inputs are the two pulses above, not the
control's five.

A bounded diagnostic pair (`SecondsToRun 120`, no scripted pulses reached)
observed the first eight natural `9ED9` calls per image from reset. In every
pair the phase is identical (`Y=9EDB`, `X=795D`, same `U`, `S`, `0305`,
credit/bank, control stack) and the only semantic differences are:

| Pair | Original | Changed |
| --- | --- | --- |
| inline operand / `rom9edb` | `FF80` | `FF00` |
| returned top word at `7931` | `0000` | `0080` |
| 16-bit result | `FF80 XOR FF80 = 0000` | `FF00 XOR FF80 = 0080` |

The first sampled meaningful state mismatch in the 6-frame state log is at
**49.050 s**: `reel3` is `61AE` in the control and `6191` in the changed run,
with the same-time `ram160_19f` block also differing. The first sampled
credit/feature mismatch is later, at **100.050 s**: `credit_candidate` is
`00001E` versus `000012`, credit `2F0` is `05` versus `0B`, and the seed/reel
and alpha/ram state also differ. These are downstream of the earlier `9ED9`
result difference; the earliest continuous-time divergence is not claimed.

The static attribution is narrow: the only semantic byte change in the changed
image is `9EDC` (`80 -> 00`); the other five bytes are the ordered active
integrity fields. The early trace is the runtime confirmation that the changed
literal is read and changes the return word before any sampled state mismatch.
The historical fixed replay plus the historical adaptive pulses is insufficient
to drive the changed image into the same `EE16` state. No alternate or random
input sequence was invented, and no state was injected to force the window.

## Verification and negative controls

`tools/Curate-Natural9Ed9Comparison.ps1` rechecks image identities, changed
offsets, source-map/build binding, replay hash and event count, input-field
inventory, observed press/release frames, pre-run emptiness, argument and
debugger-command safety, state-directory emptiness, firmware markers, the exact
control phase/stack/arithmetic, the early operand/result pair, and the sampled
gate. It records `result_status = gate_changed_did_not_reach_ee16`; it does not
mark a target success. The changed run cannot be accepted as a target
comparison, and `-RequireTargetComparison` rejects it explicitly.

`tests/worker/Test-Natural9Ed9Comparison.ps1` passes 32 checks with 0 failures.
The negatives are synthetic: wrong ROM identity, stale map, altered replay,
altered control operand, wrong pre-fetch phase, missing handler hook, bad stack
return, altered pre-insertion credit, altered terminal counter, relabelled
early operand/result, forbidden playback/state load, debugger CPU/memory writes,
seeded state directory, and changed/early runs relabelled as control. They do
not replace the natural captures.

## Reproduction

Run directories are private under `artifacts/deepseek/il-natural-06/runs/`
(`original-02`, `changed-01`, `early-original-01`, `early-changed-01`). The
first failed original attempt `original-01` is preserved but not curated.

```powershell
powershell -NoProfile -File tools/Capture-Natural9Ed9Comparison.ps1 `
  -MameExecutable E:\Arcade\MAME0266\mame281.exe -RomDirectory E:\Arcade\MAME0266\roms `
  -OriginalRom <original-a6ls.p1> -VariantRom <original-a6ls.p1> `
  -Variant Original -RunDirectory artifacts/deepseek/il-natural-06/runs/original-02

powershell -NoProfile -File tools/Capture-Natural9Ed9Comparison.ps1 `
  -MameExecutable E:\Arcade\MAME0266\mame281.exe -RomDirectory E:\Arcade\MAME0266\roms `
  -OriginalRom <original-a6ls.p1> `
  -VariantRom artifacts/deepseek/il-boot-04/build-01/edited-repaired.p1 `
  -Variant Changed -RunDirectory artifacts/deepseek/il-natural-06/runs/changed-01

# early diagnostic pair: same commands with -SecondsToRun 120 -Early9Ed9Limit 8
powershell -NoProfile -File tools/Curate-Natural9Ed9Comparison.ps1 `
  -OriginalRunDirectory artifacts/deepseek/il-natural-06/runs/original-02 `
  -ChangedRunDirectory artifacts/deepseek/il-natural-06/runs/changed-01 `
  -EarlyOriginalRunDirectory artifacts/deepseek/il-natural-06/runs/early-original-01 `
  -EarlyChangedRunDirectory artifacts/deepseek/il-natural-06/runs/early-changed-01 `
  -OriginalRom <original-a6ls.p1> `
  -ChangedRom artifacts/deepseek/il-boot-04/build-01/edited-repaired.p1 `
  -SourceMapPath artifacts/deepseek/il-boot-04/build-01/source-map.json `
  -BuildReportPath artifacts/deepseek/il-boot-04/build-01/build-report.json `
  -ReplayPath evidence/mpu4/skill-cash/actions.csv `
  -OutputPath evidence/mpu4/integrity/il-natural-9ed9-comparison.json
```

## Boundaries and next proposal

This report does not establish a natural changed `EE16 -> EE22` window, changed
`07D5..07D7`, a changed downstream award, or physical MPU4 compatibility. The
changed-image divergence is trace-backed at the first eight `9ED9` calls and at
the first sampled state mismatch, but the earliest continuous-time divergence
is not resolved. A bounded next task could test whether a different *declared*
physical schedule can reach `EE16` on the changed image without state injection;
that would be input discovery, not a continuation of this fixed comparison.

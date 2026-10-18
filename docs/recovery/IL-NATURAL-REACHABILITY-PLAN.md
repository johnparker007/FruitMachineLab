# IL natural reachability and VM observation plan

18 October 2026. This is a bounded read-only review and the single proposed
next capture. The reviewed start was `main` at
`c3c8307ee80e16133fc947fc5a72728223fbb5cd`. It does not run gameplay, change
the compiler, promote synthetic 9ED9 invocation to natural evidence, or
reinterpret the accepted startup trace. Machine-readable findings are in
[`evidence/mpu4/integrity/il-natural-reachability-plan.json`](../../evidence/mpu4/integrity/il-natural-reachability-plan.json).

## Evidence classes

- **Natural execution:** the original `a6ls.p1` (length 65536, SHA1
  `402d1518bb78fdc489b06c2aabc771e5ce151847`, SHA256
  `ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c`) and
  the accepted repaired 9ED9 image (SHA1
  `e1a42dccd304b7b175aabac99e8400cdad04cf69`, SHA256
  `577f76bd36dfca04dfb01b5f5d0be93e16572f8617c7ca906397c98df36e5107`)
  in fresh isolated MAME 0.281 runs. The 9ED9 read-only site observations are
  in `evidence/mpu4/skill-cash/paid-flag-accounting.json`.
- **Static deduction:** VM listings, headers, native excerpts and the recovered
  reset/restart code cited below. A recovered name is not a complete contract.
- **Historical trace / report:** `STARTUP-VM-ENTRY-PASS.md`,
  `ROM-INTEGRITY-PASS.md`, `NATURAL-PLAY-BOUNDARY-PASS.md`,
  `PREPLAY-START-STAKE-PASS.md`, `PAID-CYCLE-RETURN-PASS.md`,
  `FLAG-FEATURE-ENTRY-PASS.md`, `IL-INTEGRITY-STARTUP.md`.
- **Hypothesis:** reset causes, why the first startup pass returns to `677E`
  and restarts, and why the selected award path reads a particular table entry.
- **Synthetic:** `vm-definition-9ed9-invocation.json` seeds PC/register/RAM
  frame; it is not natural reset or gameplay evidence.

## Natural call chain to the supported 9ED9 edit

The paid branch observed at the target is:

```text
Start input -> FC34 paid_play_sequence
FC34:FC66 -> EE62
EE62:EE64 1AA3 result; EE66 branch if zero -> EE72 -> EE11
EE11:EE11 9FA2 all-three-symbol-flag2; EE13 branch if zero -> EE22
EE11:EE16..EE20 -> EBB8
EBB8:EBCA token 9ED7 -> body 9ED9
9ED9:795B FF80; 9EDD 787E; 9EDF 795B FF80; 9EE3 7AAF; 9EE5 792F
```

`EE16` is therefore the true three-flag entry; the EE22 branch is the zero
path. `EBB8` is also called from `EBDA` at `EBF5`; that route is a separate
caller and is not the target window. The 9ED9 listing names five callers
(`EBB8`, `AC03`, `9EFB`, `A553`, `9F12`); only the `EBB8`/`EBCA` site is
exercised by the target window below.

The supported edit changes the first `795B` inline word at `9EDB..9EDC` from
`FF80` to `FF00` (`9EDC: 80 -> 00`); ordered active fields change at
`FFD1..FFD5`. The span is `795BFF80787E795BFF807AAF792F`; the definition is
`evidence/mpu4/definitions/bias-word-signed-value-9ed9.vm.json`.

## Fresh-boot physical input evidence

`paid-flag-accounting` was captured by `Capture-SkillCash.ps1` from a fresh
isolated directory with absent NVRAM/configuration, `-noreadconfig`, no state
load and no MAME `-playback` file; the tracked replay is the physical schedule.
No PC/RAM/register/ROM injection is used. The capture
script sets `MPU4_REPLAY` to a copy of
`evidence/mpu4/skill-cash/actions.csv`; the verification sidecar records
`replay_sha256 = 4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D`,
which is that file's SHA256. This is a complete physical-input schedule replayed
from frame 0, not merely a label on a later state.

The schedule has 1249 events (maximum frame 143967) using the installed
`:AUX2` and `:BLACK2` fields recorded in the capture's `input-fields.txt`:

| Port | Field | Mask | Role in the schedule |
| --- | --- | ---: | --- |
| `:AUX2` | Coin 4 | 128 | coin/credit input |
| `:BLACK2` | 1 Player Start | 128 | Start / roll / confirm |
| `:BLACK2` | Collect / Take Feature | 1 | TAKE |
| `:BLACK2` | Hold 1 / Nudge 1 | 2 | Nudge 1 |
| `:BLACK2` | Hold 2 / Nudge 2 | 4 | Nudge 2 |
| `:BLACK2` | Hold 3 / Nudge 3 | 8 | Nudge 3 |
| `:BLACK2` | Hi / Lo / Exchange Feature | 16 / 32 / 64 | feature choices |

The first events are the already accepted boundary: coin at frame 2100
(35.0 s, 3 frames) and Start at frame 2220 (37.0 s, 12 frames). The replay
continues through coin/Start/TAKE/Nudge/hold/feature inputs. The capture script
also adds deterministic physical pulses after replay: paid Start
`:BLACK2` 128 for 12 frames at `t >= 406.6 s`, ordinary paid Nudge 1
`:BLACK2` 2 for 6 frames at `t > 406.6 s` when the observed prompt/state
allows it, plus the declared TAKE/Nudge pattern (default `121`). These are
physical ioport writes, not state seeding. Frame-based durations are at the
observer's 60 Hz frame cadence (`n` frames = `n/60` s).

The curated window is `EE16 -> EE22`, 34 VM instructions, no lamps or sound
commands. Its entry RAM has credit `2F0=02`, bank word `2FC=0010`, `0305=10`,
`07D5..07D7=000000`, `02FA=0000`; terminal RAM has the same credit/bank/`0305`
but `07D5..07D7=FFE0C0`. The window cites `9ED9/EBB8/EBCA` sites, so 9ED9 is
naturally reached inside it. The exact run's own `actions.csv` (including the
scripted pulses) and raw `debug.log` remain external; only the replay file is
tracked and hashed. That is the main evidence limitation: the sequence is
reproducible from the tracked replay plus the declared script, but the accepted
run's complete input log is not itself curated.

**Capture classes.** Do not confuse a curated tail window with the run's start:

| Capture family | Run start | Curated window start | Input |
| --- | --- | --- | --- |
| `original-reset-boot`, `original-startup-vm-entry`, `il-integrity-startup` | fresh reset | reset/checksum/VM entry | none |
| `natural-award-boundary` | fresh reset | post-VM attract | exact coin 35.0 s, Start 37.0 s |
| `paid-flag-*` family (including `paid-flag-accounting`) | fresh reset | later VM boundaries (`EE16` for accounting) | full tracked replay + scripted pulses |
| `nudge-*` and other paid windows | fresh reset | later VM boundaries (`AFF0`, `B403`, ...) | full tracked replay + scripted pulses |
| `vm-definition-9ed9-invocation` | synthetic seeded state | `00FC` dispatch | PC/register/RAM seeding; not natural |

Thus `paid-flag-accounting` is a later *window*, but its accepted run starts at
reset and replays the complete physical schedule. The other paid windows in the
same campaign are similarly later windows of fresh-boot replay runs, not saved
states. `vm-definition-9ed9-invocation` is the only seeded 9ED9 evidence and is
not accepted as natural.

## VM observation boundaries

`76C7` is the native entry, before any token fetch. The accepted observations
give `X=FDF0` (initial stream pointer), `Y=02DA` (caller), `U=0672`,
`S=07C6`, and `first_word=7FBD` as a read-only peek. At this point `Y` is not a
VM node: the native entry copies `7927..792E` to RAM `F8..FF`, transfers the
caller stream pointer into `Y`, and reaches the copied dispatch at `00FC`.

Use the pre-fetch boundary, not `76C7`, for IL resolution:

- Hook `PC=0x00FC` (`LDX ,Y++` in the copied template; next instruction
  `JMP [,X++]`). Before the fetch, `Y` is the address of the next node's token
  word and `w@Y` is that token pointer (the word `LDX ,Y++` loads). `U` is the
  data stack (`w@U`, `w@(U+2)`, ...), `S` is the control stack.
- The fetch is two separate post-increments, not one pointer relation. The
  copied `7927..792E` bytes are `3420 3184 AEA1 6E91`:
  `F8: PSHS Y`, `FA: LEAY ,X`, `FC: LDX ,Y++`, `FE: JMP [,X++]`
  (`0x00FC: AEA1`, `0x00FE: 6E91`). `LDX ,Y++` sets `X=w@Y_old` (the token
  pointer) and then `Y=Y_old+2`; `JMP [,X++]` sets `PC=w@X_old` and then
  `X=X_old+2`. Therefore at a handler entry `Y = nodeAddress+2` and
  `X = tokenPointer+2`, where `tokenPointer = w@nodeAddress`.
- For the primitive self-pointing tokens in this body, `w@token` points at the
  adjacent handler. Thus `795B -> 795D`, `787E -> 7880`, `7AAF -> 7AB1`,
  `792F -> 7931`, and entry `X` numerically equals the handler entry PC:
  `795D` (literal) sees `Y=9EDB, X=795D`; `7880` (add) sees `Y=9EDF, X=7880`;
  the second `795D` sees `Y=9EE1, X=795D`; `7AB1` (xor) sees
  `Y=9EE5, X=7AB1`; `7931` (return) sees `Y=9EE7, X=7931`. That equality is a
  property of these token words, not a general rule or `X=node+2`.
- The composite call token at `EBCA` is `9ED7`, and `w@9ED7=00F8`. Its dispatch
  has `X=9ED9` (the body address), not a handler PC; `PC=00F8` runs the copied
  `PSHS Y; LEAY ,X`, saving the caller successor `EBCC` on `S` and setting
  `Y=9ED9` for the body's first pre-fetch. Do not extend the primitive
  `X=handler PC` result to composite/body entries.
- Return token `792F` dispatches to `7931 PULS Y; JMP <FC>`; `S` holds the
  saved caller cursor. The next pre-fetch therefore shows the caller successor
  (`EBCC` for the `EBCA` call). The call token at `EBCA` is `9ED7`, whose body
  is `9ED9`.

Source-map resolution: map each IL node to the address of its token word, require
`Y == nodeAddress` and `w@Y == nodeToken` at `00FC`, and take operands from
`nodeAddress+2`; the successor is the next `00FC` `Y`, not arithmetic on `Y`.
Before accepting a resolved line, also require the primitive handler entry to
match the fetched token (`X == w@node + 2`, `Y == node + 2`, and, for this body,
`PC` equal to the corresponding `795D/7880/7AB1/7931`); a composite token such
as `9ED7` is validated separately by its body pointer and the `00F8` trampoline.
The accepted source map is bound to the repaired image SHA256
`577f...5107` (map SHA256 `0c39a6d0d1beac32ca0f64bfec5ce848b2297be41180d0234d2bfdf491df21a9`,
build report SHA256 `ae7e0fb2c0121e0b4e62d38e82511841644fcdf922b2d9e54de79b3d7e57f61a`).
Its node addresses are `9ED9`, `9EDD`, `9EDF`, `9EE3`, `9EE5`; `bodyEndExclusive`
is `9EE7`.

## Multiple 7CD1 startup markers

The accepted original startup log shows three `7CD1` entries before the anchored
tail: `S=0000/CC=50`, `S=07C4/CC=58`, `S=07C2/CC=D0`; three `6750` entries and
two complete checksum passes. The first `677E` return is followed by the third
reset; the second is followed by `67B3 -> 3B1A -> 7CF6 -> 76C7`. The accepted
trace alone does not record `7CCF` or the caller of any restart.

Static recovery places `7CD1` inside `7CCF reset_and_game_entry`: `7CCF` masks
IRQ/FIRQ, sets `S=07C8`, and calls `7D2B` then `6750` (DEEP-ANALYSIS). The
marker is therefore the post-mask reset boundary, not automatically a hardware
reset. Original code contains nonlocal `JMP 7CCF` restart paths at `6EF7`
(door/mode change), `6EA6` and `6E99` (NVRAM complement/checksum failure). The
first `S=0000` is consistent with a cold CPU reset; the later `S=07C4/07C2`
are consistent with software re-entry. That is an inference, not a proof. The
first-boot absent-NVRAM validation failure is a plausible hypothesis for one
restart, but the accepted trace does not identify which path fired; the `0x08`
difference between `07C4` and `07C2` is unexplained. `3B1A` is only a
proposed "startup reset history" label. Do not silently reinterpret the
accepted run.

## Proposed next task (one)

**Natural fresh-boot original/changed 9ED9 comparison.** This is not an input
discovery task: the tracked replay already provides a complete sequence.

Allowed files: new `docs/recovery/IL-NATURAL-9ED9-COMPARISON.md`; new
`evidence/mpu4/integrity/il-natural-9ed9-comparison.json`; new
`tools/Capture-Natural9Ed9Comparison.ps1` and
`tools/Curate-Natural9Ed9Comparison.ps1`; `evidence/curated-manifest.json` via
the shipped generator/verifier; and private
`artifacts/deepseek/il-natural-9ed9/**`. Everything else read-only.

Prerequisites: original and repaired identities above; the accepted repaired
image from `artifacts/deepseek/il-boot-04/build-01/edited-repaired.p1` (or a
fresh `FruitMachineLab.IlBuild` regeneration with the same map/build hashes);
`actions.csv` SHA256 `4A05...`; MAME `E:\Arcade\MAME0266\mame281.exe`, version
`0.281 (mame0281)`, SHA256 `0fce5a88...04cb7a`; the exact paid-flag capture
flag set from `paid-flag-accounting-verification.json`; fresh isolated
directories with absent NVRAM/configuration.

Run: two fresh-boot runs (control original; changed repaired), same replay,
same declared scripted pulses, `-noreadconfig`, `-seconds_to_run 1200` (target
window is well before this; hard wall cap 1800 s), no save state, no debugger
writes. Observe the pre-fetch hook at `00FC` conditioned on `Y in {EBCA, 9ED9,
9EDD, 9EDF, 9EE3, 9EE5, EBCC}`; handler entries `795D`, `7880`, `7AB1`, `7931`;
and `EBB8` entry/exit. Record `Y`, `w@Y`, `X`, `U`, `S`, `w@U..w@(U+6)`,
`0305`, `07D5..07D7`, credit `2F0`, bank `2FC`, and the IL node resolved by the
map. Stop at the first `EE22` after the `EE16` window; also keep a bounded
continuation to `EBCC`/`EBD6` if needed.

Acceptance: both runs pass firmware integrity, reach `EE16` and `9ED9` from
reset with the same replay, and show the same pre-9ED9 state. The control
`9EDB..9EDC` must be `FF80`; the changed run must be `FF00`; the changed literal
and the resulting `07D5..07D7` must differ consistently, with unchanged
`0305`, credit, bank, U/S discipline and no unsupported branch. Durable
artifacts: run-local `actions.csv`, `debug.log`, `debugger.cmd`,
`arguments.json`, `input-levels.csv`, `observation.json`, RAM dumps and hashes;
curated JSON with control/changed identities and map/build hashes. Negative
controls: wrong ROM identity, stale map, altered replay hash, altered control
byte, seeded save state, debugger PC/RAM write, and tampered copied logs/JSON
must be rejected. Fail on any pre-9ED9 divergence, missed window, integrity
failure or unattributable difference. Do not bypass a failed natural gate.

## Remaining unknowns

The accepted run's complete scripted-pulse log is external; the 7CD1 causes are
unproved; `9ED9`'s other callers are not naturally exercised; and the physical
effect of the first literal edit on `07D5` has not yet been observed in a
natural original/changed target pair. Hardware compatibility remains separate.

**Execution update (il-natural-06).** The proposed fixed-schedule comparison was
run. The original control reached `EE16 -> EE22` with the corrected phase and
stack trace. The changed image did not reach `EE16`: earlier natural `9ED9`
calls read `FF00` instead of `FF80` and return `0080` instead of `0000`, and the
first sampled meaningful state mismatch is at 49.05 s. This is a gate, not a
target comparison; see
[`IL-NATURAL-9ED9-COMPARISON.md`](IL-NATURAL-9ED9-COMPARISON.md).

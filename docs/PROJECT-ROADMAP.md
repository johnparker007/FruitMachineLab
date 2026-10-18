# Project roadmap

Updated 18 October 2026 through `eb7a40a` (415 groups). The suffix proof is
accepted; the IRQ prefix and gate 3 remain open. The source audit at `2916fa1` remains
historical context. This replaces older timing-first and byte-identical-rebuild
priorities. Historical evidence remains in [CURRENT-HANDOFF.md](CURRENT-HANDOFF.md),
recovery reports and implementation status. The historical exact-snapshot sound
certification remains valid history; the separate fresh capture33/36 oracle and
verify37/38 component checks do not silently supersede it or complete gate 3.

Three goals advance in parallel: autonomous PC gameplay, editable original-VM
game logic, and modified ROM generation for MAME and eventually physical hardware.
MAME is the external oracle. Byte-identical reconstruction is diagnostic, not a
prerequisite. Recorded schedules must not be hidden runtime dependencies.

Read [the source audit](ENGINEERING-AUDIT.md) for architecture and capture inventory;
[ROM editing](ROM-EDITING.md) for the first patch milestone. Preserve original
ROMs/settings/projects; no installations/configuration changes without approval.

## A — Autonomous native execution

| Stage | State and acceptance |
| --- | --- |
| A1 Capture inventory (P0) | Initial source-backed inventory in ENGINEERING-AUDIT.md extends COLLECTION-TRANSFER-PASS. `SkillCashLiveSession` direct reads are field-classified and fail closed under an optional strict policy; default compatibility remains. The same policy now covers `SkillCashData` extension/feature/alpha/scan static range loads, with compiled fallbacks for callers that pass no evidence directory. Other verification/caller/board and scheduling reads remain unenforced. See `docs/recovery/A1-CAPTURE-POLICY-PASS.md`. |
| A2 Causal scheduling (P0) | Partial: timer3 phase/assertion, selected instruction acceptance/dispatch/scan/callback generated. The captured `FEC3..FECE` suffix is composed on one machine (415 groups), but `FE70..FEC3` remains open. Outer timer1 entry/occupancy and atomic helper/VM pacing remain captured. Accept selected game paths with generated scheduling and differential verification. |
| A3 Ten paid games (P1) | Open: three selected generated games pass using Live capture adapters. Accept ten complete games on one state, no runtime recorded schedules/results or manual repairs. Declared starting snapshot temporarily permitted. |
| A4 Expanded coverage / 100 games (P1) | Partial gameplay includes paid spins/results, nudges, board links, Skill Cash, accounts and selected headless collection. Accept 100 games across outcomes/features/collection/background services with deterministic accounting/state checks. |
| A5 Extended stability (P2) | Open: accept 1000 complete games with invariants and no unsupported execution boundaries. Synthetic payout transactions are not played games. |
| A6 Independent startup | Open: documented reset/init without captured RAM/device snapshots; retain RNG, NVRAM and hardware phase semantics. |

Integrate existing native sound/timed collection owners with required foreground
and service boundaries. Stage CPU work needed for that path and generated
scheduling, preserving the working adapter until proved. Avoid an unrelated full
CPU emulation campaign or replacing working VM/motor/timing infrastructure.

## B — Editable game representation

| Stage | State and acceptance |
| --- | --- |
| B1 Dictionary/encoding (P0) | Partial addressed VM listings, headers, tokens, branches and selected exact-byte checkpoints. Accept validated definition/reference ownership with opaque regions explicit; labels do not establish complete recovery. |
| B2 Editable representation (P1) | Checked definitions for 9A64 branches and 9ED9 word literals produce PC operations and exact ROM bytes from one plan. Original-span/identity/size checks preserve unknown bytes. No general dictionary/compiler/editor. See VM-DEFINITION-*-PASS reports. |
| B3 Existing definition | Partial: one emitted 9ED9 literal edit matches ten synthetic original-interpreter MAME cases, including stack/return contracts. Natural execution of that edited definition remains open; no general replacement coverage. |
| B4 References/relocation (P2) | Open: certify absolute tokens, headers, native/shared-body and relative branch references before moving/growing a body. No safe free space declared. |
| B5 Feature editing (P2) | Open: modify substantial feature from common definitions and verify both targets. |
| B6 New features (P2) | Open: author/build/execute a feature within hardware constraints without per-change manual machine-code patches. |

Use recovered VM encoding as the starting representation. Retain provenance,
sites/tokens and opaque bytes. C# supplies execution/tools, not competing game
rules. Changed decoded operands require a decode/rebuild path. Do not build a
polished editor before replacement ROM definitions execute.

## C — ROM generation and hardware compatibility

| Stage | State and acceptance |
| --- | --- |
| C1 ROM map (P0) | Partial layout/reference ownership. Original active startup integrity algorithms/ranges/fields recovered and observed in MAME; ordered regeneration proved for the narrow shared-award edit. Other region boundaries/reference inventory remain open. |
| C2 Minimal patcher (P0) | Implemented: strict identity/expected bytes, equal lengths/no overlaps, separate create-only output, reproducible hashes/diff. Safety/CLI tests and actual original-image generation in ROM-EDITING.md. |
| C3 Modified ROM in MAME (P1) | Partial: original and integrity-repaired award images naturally reach VM entry and controlled coin/Start paid setup. Unrepaired patch fails the original checker. Natural observed table read was 75C0, not edited 75BE; changed award consumption remains unproved. Synthetic lookup returns12/control10. Loader warning retained. |
| C4 Definition replacement | Open: in-place compiled replacement, boot and execute it. |
| C5 Compiler/assembler (P2) | Open: reproducible multi-definition builds/fixups/source maps, preserving unknown bootstrap/IRQ/interpreter/data. |
| C6 Differential verification (P1, expand later) | Initial same-table lookup comparison. Accept controlled original/modified/native gameplay, accounts/outputs and expected differences; identical internal traces not required. |
| C7 Physical compatibility (P2) | Open: prove reset, timing, persistent state and peripherals on hardware. MAME success cannot complete this stage. |

## Restart plan: sound ownership before finish timing

John paused the callback. This is a planning checkpoint, not permission to resume
the stopped boundary automatically. Last accepted commit: `3e19734`; complete
clean-snapshot verification: **401 groups**, zero build warnings/errors. The
earlier uncommitted FEC9 work was accepted through `99c7ef4`/`85fce7f`; the old
"dirty checkout with a failing check" note is historical, not the current state.
The accepted fresh-oracle evidence is a separate lineage from the historical
nudge-tone/zero-cache exact snapshot and does not replace those expectations.

Two blockers must be kept separate. The early FEC9 attempts exhausted their old
40-step runs; their queued-case verifier also lacks ROM regions required by the
actual stream. That fixture explanation remains a diagnosis to validate, not an
accepted repair. Later investigation found that Live's logical scheduler does not
maintain the native tone task/channel/rhythm/tail state required by cancellation.
Increasing the step limit does not resolve either correctness boundary.

Execute these gates in order when work is resumed. Each is one worker task plus
focused review; do not dispatch the entire migration as one prompt.

1. **Certify the preserved FEC9 wrapper in isolation.** Recheck capture provenance
   and initial registers/stack independently. Inventory every ROM read required by
   the captured 8784 path before re-curating; verify against the original identity.
   The current verifier must not derive its starting S from the expected end S or
   its return contract from expected after-RAM. Seed from captured initial state.
   Check that FECC is the actual supported return target; reject other targets
   rather than proceeding to a hardcoded FECC. Compare empty/queued cases against
   every observed PC/encoding/cycle, full 2KB RAM and balanced frame. Add corruption
   controls and retain existing prompt/lifecycle comparisons. Natural scheduler-a/b
   proves only its observed empty-list return. No cadence/outer IRQ or Live claim.
   Accept only after the full intended snapshot passes; otherwise stop with the
   first independently reproduced mismatch. A new focused attempt requires the
   resumed plan's authorization; old incomplete runs are not silently erased.
2. **Prove one headless native tone owner.** Reuse `AddersNativeSound` and existing
   native queue/service/cancel/release plans. Queue actual 59EB into real 0047/0049
   task memory, service until the original wait/finish boundary, then cancel on
   the same state. Declare the checkpoint and externally supplied service calls.
   Those calls may establish a bounded component proof, never autonomous timing.
   Capture/compare actual list, channel, rhythm, tail, stack and return state for
   the natural tone path and selected labelled synthetic alternatives. No parallel
   fabricated task or captured end-state injection. This can be proved headlessly
   before solving every timer1 service; stage 1 alone does not establish ownership.
   **Historical gate-2 certification** remains in
   `docs/recovery/TONE-LIFECYCLE-CERTIFICATION.md`: entry-gap-checked 485 captured
   instruction boundaries, two declared service ticks and full RAM/channel/tail
   comparison on the zero-YM-cache reset snapshot. Only the initial `C6` channel
   sentinel and zero-count `C4` loop are covered; active-channel/finite-count
   variants remain rejected. It is retained as historical component evidence and
   is not silently replaced. A separate fresh oracle now adds capture36's first
   `FC4D..5A1C` window and verify37/38's 25 independent outer `5CD0/FECC`
   reproductions (full 2 KB, cycles, instruction completion, semantic negatives
   and raw-file pins). Capture33's `FECC/FECE` is a nested IRQ return and remains
   separate. This proves per-call components, not continuous same-state execution.
   Gate 3's Live ownership design remains open.
3. **Design then connect the selected Live owner.** Specify entry-state source,
   required foreground and service instruction boundaries, pause/resume, task
   handoff and exactly one mutating owner. Explain how existing logical background
   tasks coexist or transfer without duplication. Preserve compatibility until the
   selected path is independently proved. If 6B4D/58BB or IRQ scheduling is required,
   identify and recover that prerequisite separately; do not skip it. Do not use
   captured task trajectories to claim a causal replacement. **18 October
   reconciliation:** safe Live handoff is still not possible. The fresh queue
   frame, 25 matched service pairs and cancel/return frames are available, but the
   foreground/IRQ writes between each `FECC` and the next `sv` entry are not
   recovered. Do not implement a continuous adapter that reseeds at each return or
   guesses those writes. The next prerequisite is a foreground delta ownership
   analysis of `queue->sv00`, every `fecc[i]->sv[i+1]`, `fecc24->cancel`,
   `cancel->5A10` and `5A10->5A1C`; every byte must be attributed to the sound
   owner, recovered IRQ/wrapper code, recovered foreground code or another known
   owner. Stop at the first unknown byte. Only then implement the single-owner
   queue/service/cancel adapter specified in
   `docs/recovery/LIVE-NATIVE-SOUND-OWNERSHIP-PLAN.md` (entry `queue.bin` at
   `5C18`, no logical scheduler, no reseed, captured host ABI, same-machine
   intermediate comparisons and meaningful negatives). A `FC4D` start remains a
   separate prerequisite.

   **18 October suffix/prefix boundary:** integrate58/59 accepted the one-machine
   `FEC3..FECE` suffix at 415 groups; this is not gate 3. Existing executable
   components cover the selected `FE70` timer1 dispatch, `28FE`, `FEBA/2C`,
   `27D2->438C`, `19B8/1A87/1A05/1A58`, idle `6403` and `280F..2851`. The nested
   timer3 path between `19BB/19BE` is real occupancy and must stay explicit.
   `27D2 2851..288E` is static-only; active `6403`, non-19B8 `C6`/`4167`, `7CCF`
   and SWI alarms remain boundaries. Capture41/43/57 match the FC4D/outer-FE70/FEC3 anchors
   but save no outer FE70 2 KB or timer phase, so the prefix cannot compose from
   current fixtures without reverse-fitting or reseeding. Next is one minimal
   extension of that campaign: save the FE70 2 KB, timer3 state and exact
   `FE70->FEC3` rows including nested `FE70/FF13`, then translate the `2851..288E`
   tail and compose; compare FEC3 2 KB, stack, `2C=FF`, cycles and occupancy.
   Stop at the first mismatch. No Live, cadence, audio, hardware or gate-3 claim.
4. **Replace finish CPU work, then IRQ occupancy separately.** Only after native
   state ownership is real, derive 5C7A/5CB5/5E2C and 777E..778B costs from the actual
   path. Natural 360 CPU cycles is an oracle, not a budget to fit; the inferred
   one-channel/tail explanation is not a recovered initial-state contract. Keep
   `outer_irqs`/2735-cycle observed envelope explicit until causal acceptance and
   complete service execution replace them. Each removal gets its own comparison.
5. **Resume integrated gameplay acceptance.** One retained-state prompt/Collect/
   payout path first, then ten paid games only when required recorded schedules
   and results are genuinely absent. Synthetic transactions are not complete games.

If a gate is blocked, preserve its artifacts and report the missing evidence or
first mismatch. Two unsuccessful attempts at the same boundary stop that boundary;
do not loop, weaken expected results, switch tasks merely to appear busy, or claim
that a higher step limit resolves the failure. Independent work is optional and
must advance a named roadmap acceptance criterion.

Secondary work after the ownership gates: natural consumption of award byte 75BE,
or natural boot/execution of the edited 9ED9 definition with an explicitly scoped
integrity contract. Avoid more generic encoder expansion or repeated unguided game
runs until the next acceptance check needs them.

## Worker operation and review

DeepSeek performs investigation, captures, C# changes, builds/tests and compact
reports. ORCHESTRATOR chooses a gate, reviews the actual diff and independent
evidence, then commits/pushes accepted work under John's existing authorization.
No installations or unrelated configuration changes are authorized by this plan.
Fresh OpenCode runs currently have 1000 **steps**, not 1000 retries. Dispatch has
a 20-minute bound for these batches and no automatic retry; on timeout preserve
the handoff and verify any claimed completion against saved exit/summary logs.

For the paused callback's eventual resumption, read the durable checkpoint first,
check one worker/process once and end if healthy. Process each result once. Quiet
checks still consume some subscription allowance; this is scheduled supervision,
not an instant callback or guaranteed unlimited unattended execution. Do not change
or unpause the schedule as part of planning.

Until FEC9 is accepted, verify intended changes in an isolated tracked-HEAD source
snapshot plus only the intended patch. Preserve the main checkout and exclude only
the uncommitted stopped changes from that snapshot, not tests belonging to the
intended commit. Save patch, commands, exits and complete suite summary. Keep local
task/log checkpoints durable; ROMs, credentials and bulky traces remain untracked.

## Preservation and product direction

Retain bytes/addresses, calling/frame/stack effects, input/output contracts and
evidence classes (static, natural traces, hypotheses, synthetic faults). Unknown
helpers fail; no guessed semantics, suspected ROM fixes or zero-cost timing.
Keep binaries, credentials and bulky traces untracked. Hybrid building preserves
opaque firmware rather than reconstructing every byte before changing a constant.

Windows diagnostics and eventual DX renderer consume common backend inputs/outputs.
Reuse John's MFME FML importer/layout renderer when paths/licences/assets arrive;
avoid a polished temporary cabinet. Validate reuse using a second MPU4 game John
supplies before generalizing. Other platforms, including 68000, need independent
execution-model recovery. Millions of autoplay games remain a later goal after
retained-state accounting and meaningful whole-game coverage.

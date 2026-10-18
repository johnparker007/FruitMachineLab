# Live native sound ownership plan

Design only; no game code was changed. Scope is the selected Start-tone path
`FC4D` `80A4` (`5A14 -> 59FF -> 59D9 -> 5C18/5C7A`). This does not claim generated
timer1 cadence, `6B4D`/`58BB`, audio synthesis or whole-game acceptance.

## 18 October fresh-evidence reconciliation

Gate 3 remains open. The historical gate-2 certification
(`TONE-LIFECYCLE-CERTIFICATION.md`) and the historical nudge-tone/zero-cache
exact snapshot remain valid **historical component evidence**; they are not
silently rewritten or promoted. A separate, user-authorized fresh oracle now
exists. Capture33 is one anchor set whose `FECC/FECE` is a nested IRQ return.
Capture36 is a different controlled-input occurrence with 25 matched outer
`5CD0/FECC` pairs. Verify37/38 independently reproduce each capture36 pair from
its own 2 KB entry and captured ABI, including full 2 KB, cycle spans,
instruction completion, six semantic negatives and two raw-file pins. That is
per-call component proof, not continuous same-state execution. The historical
nudge-tone snapshot is no longer the selected entry source.

## Evidence classes

- Static/source: original A6L ROM SHA1 `402d1518bb78fdc489b06c2aabc771e5ce151847`;
  `5A14/59FF/59D9/7159/5C18/5C7A/5E2C/60AB/5CD0`, and `FE70..FECE`.
- Fresh natural oracle (current): `collection/matched-service-window-capture36.json`,
  the first controlled-input `FC4D..5A1C` window with 25 matched outer service
  pairs, actual reset YM cache and full 2 KB at queue/service/cancel/returns.
  `collection/fresh-tone-occurrence-capture33.json` is a separate single-occurrence
  anchor set whose `FECC/FECE` is nested; `fresh-tone-occurrence.json` is the
  separate oracle31 window. Neither replaces the other.
- Historical natural: `skill-cash/nudge-tone.json`, an FC4D entry and FC4D->F384
  window from physical inputs, including full entry RAM, six sound commands and
  per-phase cycle/clock observations. Retained as history.
- Historical synthetic original-ROM: `collection/tone-lifecycle.json` (485
  instruction boundaries, full 2KB RAM, zero YM cache, queue/service/cancel) and
  `collection/timer1-scheduler-call.json` (FEC9 wrapper). Retained as history.
- Declared checkpoints: `feature-replay.json`, `board-selection.json`,
  `nudge-tone.json`. The fresh capture36 queue frame is now the preferred scoped
  entry; the older checkpoint is not the selected gate-3 source.
- Unsupported/hypothesis: causal `6B4D`/`58BB` execution, timer1 assertion and
  native service frame generation.

## Current inventory

`SkillCashLiveSession` constructs a new `Machine`, loads the feature/scan/static
data, and never creates `AddersNativeSound`. The plain feature path leaves
`0047=0000`, `0049=0000`, `004B/004C=00`, `027E..0292=00`. The board-selection
path copies full RAM (`0047=01A0`, `0049=01C5`, free channel tail `004C=05`,
task `01A0` with root `96EA`) and then `RestoreQueuedNativeTasks` copies that task
into the logical `Mpu4ChoiceStreamScheduler`, leaving native `0047` unchanged.

Logical mutation sites are `856F` (`AddersNativeWords` active test), `5C18`,
`5B77`, `5CCB`, `5A14` (`AddersTimedTone.Begin/End`), and the reel-motion stream
callback at `SkillCashLiveSession.cs:355`. None writes `0047`, `0049`, `0045`,
or the native channel/cache bytes. The native owner `AddersNativeSound` currently
provides foreground `Queue/Cancel/Reset`, one `5CD0` service call, pause/resume
and fault latching. Its queue/cancel use an explicit caller frame and default
return `4C34`; they are semantic entries, not Live CPU frames.

The service clock is the Live virtual `Cycle`. The outer period and occupancy
come from recorded `timer1_handler_entries`; after `postPanel` Live calls
`scheduler.AdvanceTicks(1)` and sets `2C=0`. It never increments native `0045`.
Pause only freezes Live and releases the panel; no native owner exists to pause.

`AddersToneSetupTiming.QueueCycles` copies the whole 2KB image into a new
`Machine`, runs `AddersSoundQueuePlan` on that copy, and returns instruction
costs. It deliberately does not mutate the caller. Live then calls
`AddersTimedTone.Begin`, which queues `59EB` only into the logical scheduler.
Thus the source-derived native queue path and the actual sound ownership are on
different states. On the plain checkpoint `0049=0`, the clone takes the empty
allocator branch, while the logical queue still succeeds: cost and ownership do
not describe the same execution.

## Handoff determination

Safe handoff from the current feature/board checkpoint is **not possible**. Its
native list is either absent or stale: after construction, the logical scheduler
evolves while `0047` remains the captured `01A0` record. Converting logical
`TaskState` into native records would fabricate ownership; clearing `0047` would
discard the captured background task; servicing both would duplicate it. The
existing native queue/cancel frame is also not the Live VM frame.

The historical `nudge-tone.json` FC4D entry is retained as history, but it is not
the current starting contract. Capture36 supplies an actual fresh queue entry
(`5C18`, full 2 KB, actual reset YM cache) plus 25 matched outer service
entries/returns and cancel/return frames from one occurrence. This removes the
old zero-YM-cache objection for the queue/service/cancel slice, but it does
**not** prove continuous same-state execution. The foreground/IRQ writes between
`FEC9/5CD0` pairs are captured only as before/after snapshots, not as recovered
instruction writes; the observed gaps include stack `0770..0799`, `2C`, `2E/2F`,
`33/6E`, `29` and occasional scan/counter bytes. Capture33's `FC4D` anchors are
separate and its `FECC/FECE` is nested, so it must not be used as an outer
completion. A `FC4D`-started owner therefore remains a separate prerequisite;
the first safe owner entry is the captured `5C18` queue frame.

## Selected single-owner contract

One mutating owner: `AddersNativeSound` on the selected `Machine`. The logical
scheduler must be empty and must not receive `59EB` in this mode.

1. Construction: seed the declared capture36 `queue.bin` 2 KB at `5C18` and
   actual `719B=00`; construct the native owner on that same `Machine`; require
   `0047=0`, `0049=01A0`, `0044=0`, `004B=00`, `004C=05`, the six-record pool,
   the `027E..0283` shape and `719B` bit 80 clear. Do not seed the historical
   nudge-tone image or the capture33 nested-return frame.
2. Setup (`5C18`): execute `AddersSoundQueuePlan` through the owner's
   `BeginCall(0x5C18,...)`/advance interface on the real machine, with the
   captured caller frame and continuation `59E9`; not a clone or an independently
   mutating plan. Accumulate costs and effects in that same execution. Success
   gives `0047=01A0`, root `59EB`, `004D=31`, due `0045+1`. The
   `FC4D/5A14/59FF/59D9` foreground wrapper is outside this increment until its
   delta ownership is recovered.
3. Wait: capture36 contains 25 outer `5CD0` calls, not one. A continuous adapter
   may call `5CD0` at the captured entry cycles/frames, but must first account for
   the non-sound foreground/IRQ writes between each `FECC` return and the next
   `sv` entry. Until that analysis is complete, only the first pair is an
   independently proved component boundary; do not skip the remaining 24 or
   reseed at each return. Native `0045` advances only by actual service calls, not
   by `scheduler.AdvanceTicks`.
4. Finish: at the captured cancel boundary use `BeginCall(0x5C7A,...)` with
   continuation `5A10`. `5C7A/5CB5/5E2C` removes the first root `59EB`, releases
   its channel and restores the free list. `5A10/5A1C` foreground sets `004D=0`
   after the native cancel; include that only as an explicitly attributed
   foreground write. Unrelated roots would be preserved by the certified cancel,
   but this selected entry has none.
5. Pause/resume/fault: Live pause calls owner `Pause`; resume calls `Resume`;
   owner faults become Live faults and remain latched. No host-clock or service
   advance occurs while paused.

Native service requires a real CPU frame. The gate-2 `S=0700/U=0600` frame is a
component frame; it is not valid for the fresh entry. The selected slice must
use the captured `5C18` queue frame (`S=0798`) and the captured `FEC9/5CD0`
service frames (`S=078B`, `U=0672`, `X=0366`, `Y=0000`, `A=05`, `B=0B`), not
invent a frame. Capture33's nested `FECC/FECE` frame (`S=077F`) is not an outer
completion.

## Gate 3 decision (18 October)

No Live implementation is authorized by this evidence. Gate 3 is not complete.
The smallest genuine advance is not another per-pair fixture: it is a foreground
delta ownership analysis of capture36's inter-service gaps. The captured
task/channel/cache state is sound-owner output, but the gaps contain
foreground/IRQ writes (observed at least `29`, `2C`, `2E/2F`, `33`, `6E`, stack
`0770..0799` and occasional scan state). These are not recovered instruction
writes and must not be guessed.

Analyze `queue->sv00`, every `fecc[i]->sv[i+1]`, `fecc24->cancel`,
`cancel->5A10` and `5A10->5A1C`. Attribute every byte to one of: the native sound
owner; recovered `FE70/FF13/FEC9/FECC/FECE/5D3B/5CF3/5E29/5E2C/5E6D` code;
recovered foreground `5A05/7159/5A14/5A10/5A1C` code; another known owner; or
unknown. Stop at the first unknown byte and name the exact missing source/helper.
Only after every delta is attributed may the following adapter be implemented.

## Smallest implementation slice (blocked on the delta analysis)

Files and API:

- `src/FruitMachineLab.Adders/AddersNativeToneOwnerExecution.cs` (new, proposed):
  one bounded adapter holding the single `Machine`/`AddersNativeSound`; routes
  queue/service/cancel through existing `BeginCall`/`BeginService`/`AdvanceTo`
  calls. It declares the captured host cycle and `S/U/X/Y/A/B` ABI as explicit
  inputs and performs no RAM writes itself.
- `src/FruitMachineLab.Adders/AddersToneSetupTiming.cs`: retain the cost-only
  calculation as a scoped test. In native mode it must not clone the machine or
  run `AddersSoundQueuePlan` outside the owner.
- `src/FruitMachineLab.Adders/AddersTimedTone.cs`: reject native mode; never run
  its logical `scheduler.Queue/Cancel` alongside the native owner.
- `src/FruitMachineLab.Adders/SkillCashLiveSession.cs`: only after the adapter is
  proved, an opt-in headless `nativeStartTone` mode may consume it. The current
  Live constructor must not be changed by this evidence alone.
- `AddersToneLiveOwnershipVerification.cs` (new) and
  `tests/FruitMachineLab.Verification/Program.cs`: same-machine intermediate
  comparisons and meaningful negatives.

Contract: entry is capture36 `queue.bin` at `5C18` with actual `719B=00`, not the
historical nudge-tone image and not a capture33 nested-return frame. The
logical scheduler must be empty and must not receive `59EB`; no
`RestoreQueuedNativeTasks` transfer. Queue uses the captured caller frame and
continuation `59E9`; each service uses the captured `FEC9/5CD0` frame and
continuation `FECC`; cancel uses the captured frame and continuation `5A10`.
Supported host inputs are the captured cycles and `S/U/X/Y/A/B`; each service
entry/return must be reached by advancing the same machine, with no reseeding
after the initial 2 KB seed. The only non-owner writes allowed are foreground/IRQ
writes attributed by the delta analysis, each with a source site. Fail closed on
nonempty `0047`, invalid `0049`, `719B` bit 80, `0044` nonzero, any logical task,
a second owner, a changed `719B`/host frame, a wrong service `S`/return word, an
unattributed delta, a missing ROM region, or any root other than `59EB`.
Verification must compare the same-machine intermediate states at `sv00..sv24`,
`fecc00..fecc24`, cancel, `5A10` and `5A1C` (full 2 KB where evidence supports,
otherwise only the exact owner/attributed ranges), the captured cycle spans and
`5D3B`/`5CF3` events. Negatives must reject reseeding, wrong pair, wrong `S` or
return word, changed captured frame, nonempty logical scheduler, duplicate
ownership and a missing ROM region. Exact prerequisites: complete attribution of
the deltas above; a captured full `FC4D` 2 KB frame with foreground ownership if
the mode is to start before `5C18`; and `5E29/5E6D` callback evidence if the
lifecycle is extended beyond capture36's 25-service window. This plan does not
require or authorize a new capture.

The finish CPU work is derived from `5A0A` (`LDX #59EB`), `5A0D` (`JSR 5C7A`),
the cancel/release instructions, `5A10` (`CLR 4D`) and `5A12` (`PULS`), plus the
foreground return. The recorded phase-2 `outer_irqs=1` remains an explicit
envelope, not folded into CPU cycles. Natural `360` CPU cycles is only an
independent oracle, not a fitted budget.

## Why FEC9 cadence is not generated

Original `FE70` executes `28FE`, the `2C` guard, `27D2`, `6B4D`, `58BB`, then
`FEC9 JSR 5CD0`. `6B4D` has source assembly but an unresolved indirect
continuation; `58BB` has no recovered native execution evidence. No recovered
path therefore reaches FEC9 causally. A bounded explicit adapter may call
`5CD0` once per retained outer acceptance with declared inputs, but it must not
claim the FEC9 wrapper, the earlier services, timer1 cadence or recorded-result
routing. If causal integration is required, recover `58BB` and the `6B4D`
continuation first.

## Unsupported cases and acceptance

Fail closed on: nonempty `0047` at the declared queue entry (or at FC4D if that
start is later recovered); invalid `0049`; `719B` bit 80; `0044`
nonzero; any logical task or second owner; service during pause/fault; a service
frame that is not the captured one; any stream/root other than `59EB`; the
gate-2 rejected `C6` active-channel and finite `C4` branches; unsupported
commands; or missing frames/ROM regions. Do not claim background-task coexistence
from this entry; it is reset-empty. The gate-2 cancel-preserves-unrelated-roots
case remains component evidence only.

Acceptance: exact ROM bytes; all gate-2 queue/service/cancel boundaries and full
RAM where schema overlaps; capture36's 25 matched outer pairs, cycle spans,
actual reset YM cache and full queue/service/cancel frames; capture33 remains a
separate nested-return anchor set. The historical gate-2 zero-cache fixture,
nudge-tone six sound commands and phase timestamps
`699661924/699661949/699662264/699745210/699748264/699748279` remain historical
expectations and are not replaced. Negative controls must reject injected end
state, a wrong return/frame, a nonempty initial list, a reseed after entry and
duplicated logical/native ownership. Gate 3 is not complete; the next increment
is the foreground delta ownership analysis above. No status is changed to
implemented.

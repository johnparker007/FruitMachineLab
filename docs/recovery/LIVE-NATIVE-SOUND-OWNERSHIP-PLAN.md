# Live native sound ownership plan

Design only; no game code was changed. Scope is the selected Start-tone path
`FC4D` `80A4` (`5A14 -> 59FF -> 59D9 -> 5C18/5C7A`). This does not claim generated
timer1 cadence, `6B4D`/`58BB`, audio synthesis or whole-game acceptance.

## Evidence classes

- Static/source: original A6L ROM SHA1 `402d1518bb78fdc489b06c2aabc771e5ce151847`;
  `5A14/59FF/59D9/7159/5C18/5C7A/5E2C/60AB/5CD0`, and `FE70..FECE`.
- Natural: `skill-cash/nudge-tone.json`, an FC4D entry and FC4D->F384 window
  from physical inputs, including full entry RAM, six sound commands and
  per-phase cycle/clock observations.
- Synthetic original-ROM: `collection/tone-lifecycle.json` (485 instruction
  boundaries, full 2KB RAM, queue/service/cancel) and
  `collection/timer1-scheduler-call.json` (FEC9 wrapper).
- Declared checkpoints: `feature-replay.json`, `board-selection.json`,
  `nudge-tone.json`. Only the last is permitted here.
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

The selected FC4D entry is a **candidate starting contract**, not yet a proved
handoff, because `nudge-tone.json`
is a full natural 2KB entry captured immediately after `5B77` reset: `0047=0000`,
`0049=01A0`, `004B=00`, `004C=05`, `027E..0283=01..05,FF`, `004D=00`,
`004E=10`, `004F=00`, `0050=10`, `0045=01DF`, VM `S=07AA`, `U=0672`. It contains
no active sound task and a valid free pool, so it is a clean single-owner start.
It must be declared as the permitted starting snapshot; it is an entry image,
not an injected trajectory. Fresh checkpoint-started verification remains a
synthetic experiment even though the checkpoint came from a natural trace.

## Selected single-owner contract

One mutating owner: `AddersNativeSound` on the selected `Machine`. The logical
scheduler must be empty and must not receive `59EB` in this mode.

1. Construction: seed the nudge-tone 2KB image; construct the native owner;
   require `0047=0`, a valid `0049` pool, `0044=0`, and `719B` bit 80 clear.
2. Setup (`FC4D`): execute the existing native queue plan through the owner's
   timed `BeginCall`/advance interface on the real machine, not a clone or an
   independently mutating plan. Accumulate costs and effects in that same execution.
   Success gives `0047=01A0`, root `59EB`, `004D=31`, due `0045+1`.
3. Wait: charge `Mpu4CalibratedDelay.StartToneWaitCycles`; native `0045` is
   advanced only by actual `5CD0` service calls. The retained outer acceptance
   supplies one bounded service call, `S/U/X/Y` and masked IRQ. No audio or
   causal cadence is claimed.
4. Finish: `5C7A/5CB5/5E2C` removes the first root `59EB`, releases its channel,
   restores the free list, clears `004D`, and returns through `5A10/5A12`.
   Unrelated roots would be preserved by the certified cancel, but this selected
   entry has none.
5. Pause/resume/fault: Live pause calls owner `Pause`; resume calls `Resume`;
   owner faults become Live faults and remain latched. No host-clock or service
   advance occurs while paused.

Native service requires a real CPU frame. The gate-2 `S=0700/U=0600` frame is a
component frame; it is not valid for this entry because the VM stack is `07AA`
and the tone is inside `7159` when IRQs arrive. The selected slice must use a
captured FEC9/`5CD0` frame, not invent one.

## Smallest implementation slice

Files and API:

- `src/FruitMachineLab.Adders/AddersToneSetupTiming.cs`: retain the existing
  cost-only calculation as a scoped adapter/test. For the native slice, consume
  elapsed instruction costs from the owner's existing `BeginCall`/advance path;
  do not add a second queue mutator outside its ownership checks. The real
  foreground frame/caller boundary must first be captured and verified.
- `src/FruitMachineLab.Adders/SkillCashLiveSession.cs`: an opt-in, headless
  `nativeStartTone` constructor mode (no UI switch). It constructs the owner,
  uses the FC4D nudge-tone seed, routes the three tone phases to the native
  owner, and at the retained outer service boundary calls one `5CD0` service
  instead of `AdvanceTicks(1)`. Logical words remain unchanged and must be
  inactive.
- `src/FruitMachineLab.Adders/AddersTimedTone.cs`: reject native mode, or replace
  its `Begin/End` calls with the native owner; never run both.
- `src/FruitMachineLab.Adders/AddersToneLiveOwnershipVerification.cs` (new) and
  `tests/FruitMachineLab.Verification/Program.cs`: verification and controls.

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

Fail closed on: nonempty `0047` at FC4D; invalid `0049`; `719B` bit 80; `0044`
nonzero; any logical task or second owner; service during pause/fault; a service
frame that is not the captured one; any stream/root other than `59EB`; the
gate-2 rejected `C6` active-channel and finite `C4` branches; unsupported
commands; or missing frames/ROM regions. Do not claim background-task coexistence
from this entry; it is reset-empty. The gate-2 cancel-preserves-unrelated-roots
case remains component evidence only.

Acceptance: exact ROM bytes; all gate-2 queue/service/cancel boundaries and full
RAM where schema overlaps; nudge-tone six sound commands, phase timestamps
`699661924/699661949/699662264/699745210/699748264/699748279` and protected
terminal bytes; one fresh bounded original-ROM capture at the FC4D reset-cache
entry/exit is required because gate 2 used a zero YM cache. Negative controls
must reject injected end state, a wrong return/frame, a nonempty initial list and
duplicated logical/native ownership. No status is changed to implemented.

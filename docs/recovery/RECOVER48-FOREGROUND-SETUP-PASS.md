# Recover48 foreground setup / native queue boundary

## Outcome

Executed the actual Start-tone foreground setup `5A14 -> 59FF -> 59D9 -> 5C18`
on one `Machine`, routed the queue through the existing `AddersNativeSound`
owner on that same machine, and executed the `59E9 PULS A B X PC` return to
`5A05`. No clone is used, no logical `Mpu4ChoiceStreamScheduler` task is created,
and no captured post-state or foreground delta is applied after entry.

The smallest independently captured full-2 KB entry is `5C18`. The `5A14`
marker supplies registers/stack/cycle only. The verifier therefore seeds the
same occurrence's captured `FC4D` 2 KB frame once, restores the captured `5A14`
caller word at `07A8/07A9` (`Y=FC4F`), and executes the recovered wrapper. The
`FC4D -> 5C18` result is compared with the captured `queue.bin`; the captured
`foreground_delta` is used only as a comparison, never as writes.

## Evidence classes

- Static original ROM: `5A14 3406 8691 C602 8DE3`; `59FF 3406 1F89 8DD4`;
  `59D9 3416 C060 2A02 CB60 D74D 8E59EB BD5C18`; `5C18 BD60C8 3436`;
  `5C4F 35B6`; `59E9 3596`. Required bytes are rechecked from the curated
  oracle31 `rom_regions`.
- Fresh natural oracle31: `collection/fresh-tone-occurrence.json`, the
  controlled-input occurrence with `FC4D` and `queue` full 2 KB frames,
  `foreground-5a14`/`foreground-5a05` markers, and the 16-byte
  `foreground_delta`.
- Source-derived execution: the wrapper instructions are costed by
  `M6809InstructionTiming`; the queue is the existing
  `AddersSoundQueuePlan`/`AddersNativeSound` owner, not a second mutator.
- Explicit partial CPU state: only captured/source registers
  `Cycle,PC,S,X,Y,U,A,B` are returned. Native plans have no CPU flag file, so
  `CC` is not modeled or claimed; `DP` is not returned as captured state.

## What the execution proves

- At `5C18`, the generated state matches the captured `queue` frame:
  `PC=5C18`, `S=0798`, `X=59EB`, `Y=FC4F`, `A=91`, `B=31`, captured cycle, and
  the full 2 KB equals `queue.bin`. The wrapper writes only the captured
  `0798..07A5` stack words and `004D`, plus the pre-entry `07A9=4F`.
- The generated `FC4D -> 5C18` changed-byte set equals the fixture's 16-entry
  `foreground_delta` with the same from/to values.
- The same owner queues the real `59EB` task: `0047=01A0`, `0049=01C5`,
  `004D=31`, one completed call, continuation `59E9`, task active.
- `59E9 PULS` returns to `5A05` with the captured registers and cycle:
  `S=07A0`, `X=80A6`, `Y=FC4F`, `U=0672`, `A=91`, `B=91`.
- Cycles are source-derived and separately reported: wrapper `67`, native
  queue `262`, return `11`, total `340`, matching the captured `5A14 -> 5A05`
  span. No host-trace IRQ occupancy is added to these instruction cycles.

## Negative controls

Preflight rejects, before any memory mutation: `stack` (`S<22`), `gate`
(`719B` bit80), `ownership` (already-active native root), `owner` (different
machine), `servicing`, `paused`, and `missingROM` at region load. The `snapshot`
control reaches the full-2 KB `5C18` comparison and fails there. All rejections
are semantic-stage checks, not raw-hash short circuits.

## Limits

The `00FC/80A4/776F` bridge into `5A14`, the `5A05/5A07/7159` wait and
`5A0A..5A12` finish, the 25-service window, `FEC9`/timer1 cadence, IRQs, Live
integration, audio and a whole continuous lifecycle remain outside this slice.
The `5A14` 2 KB state is not an independent full save; only the `07A9` caller
byte is taken from the captured marker, and no later reseed occurs. No full
`CC`/`DP` state is claimed.

## Commands and exits

- `dotnet build FruitMachineLab.Headless.sln -v:minimal` -> exit 0, 0 warnings,
  0 errors.
- Focused `Foreground5A14` run -> exit 0, 3 groups passed.
- Full headless suite -> exit 0, 409 groups passed (406 Recover47 baseline plus
  these 3).
- Curated manifest verification -> exit 0 after adding this report.

## Next task

Recover the `00FC/80A4/776F` bridge into `5A14` from a full captured 2 KB entry,
or extend the same-machine owner through the first real `5CD0` service only
after the inter-service foreground/IRQ deltas are attributed. Do not infer
timer1 cadence or Live ownership from this setup boundary.

# Fresh controlled-input 59EB occurrence

Oracle31 certifies one fresh natural `59EB` start-tone window from the retained
controlled-input campaign. It is independent of the historical nudge-tone snapshot
and does not replace or re-time it. The historical `FC4D` entry `X=80A3`, curated
cycle `699661924` and RAM SHA256 `DF378...172CC` remain unchanged. The fresh window
enters at `FC4D`, cycle `0x3CCB742`, `X=8132`, RAM SHA256 `30E97...AF6BE`; its
absolute timing and caller differ and are reported, not fitted.

## Provenance and policy

The compact fixture is `evidence/mpu4/collection/fresh-tone-occurrence.json`.
`tools/Curate-FreshToneOccurrence.ps1` refuses any raw source whose SHA256 differs
from the declared gate28 artifacts, any exit other than `0`, a non-original ROM
SHA1, a non-0.281/non-`0FCE...CB7A` MAME binary, a replay campaign that is missing,
short or malformed, a runtime action beyond the declared `paid_start`, a debugger
memory/state injection, a non-2 KB save, or foreground deltas outside the captured
caller stack and `0x4D`. The raw 82 MB log, 1.7 MB state tables and snapshots remain
ignored; only hashes, marker registers and selected 2 KB frames are curated.

The classification is controlled replay natural: recorded physical inputs, genuine
MAME devices and no synthetic service/PTM/ACK/end-state injection. It is not passive
natural play and is not the retained nudge-tone checkpoint.

## Captured contract

Primary first window, in cycle order:

- `FC4D` `0x3CCB742`, `S=07AA U=0672 X=8132 Y=FC4D`.
- foreground `5A14/5A01`, queue `5C18` `0x3CCB7AE`
  `S=0798 U=0672 X=59EB Y=FC4F A=91 B=31`, `0047=0000 0049=01A0 004C=05 004D=31`.
- foreground `5A05` `0x3CCB8BF`; `5A14-5A05 = 340` cycles.
- service wrapper `FEC9` `0x3CCC0F5`, `5CD0` `0x3CCC0FD`
  `S=078B U=0672 X=0366 Y=0000 A=05 B=0B`, then `FECC/FECE`.
- six stream commands at `5D3B`: `C6,C5,D8,00,C3,CE` at cursors
  `59EB,59EE,59F0,59F1,59F2,59F4`; `CE FF` yields to callback `5E29`.
- foreground `5A0A` `0x3CE0402`, `5A05-5A0A = 84,803` cycles; cancel `5C7A`
  `0x3CE040D`; `5A10/5A1C` at `0x3CE0541/0x3CE0550`.

The first-window queue, service-before, service-after and FECE full 2 KB frames are
temp-guarded in the source. The first-window cancel/return full 2 KB saves were not
temp-guarded; only their marker registers survive. Full cancel/return 2 KB anchors
are therefore taken from the last matching natural occurrence in the same replay
(`5C7A` cycle `0x2B4CA7C0`, `5A1C` cycle `0x2B4CAF49`) and are labelled separately.
No full-RAM cancel/return frame is attributed to the first window.

## Headless verification

`AddersFreshToneOccurrenceVerification` seeds the actual captured `FC4D` 2 KB image,
applies only the captured foreground caller delta (`0x4D` plus stack `0x798..0x7A9`,
16 bytes), then uses the real `AddersNativeSound` owner for `5C18` with the captured
caller frame and the source/captured continuation `59E9` (`59E6 JSR 5C18`). It
compares controls `0044..0050`, the full six-record task pool `01A0..027D` (records
start at `01A0,01C5,01EA,020F,0234,0259`; the last record ends at `027D`), all six
channel links `027E..0283` and YM cache `0284..02FF` against the captured `5CD0`
pre-state. It then seeds the captured service-before 2 KB, runs native `5CD0` with
the captured caller frame and continuation `FECC` (`FEC9 JSR 5CD0`, also the
captured stack word) and compares the same ranges to the captured `FECC`/`FECE`
image, including the six-command cursor/deadline and channel/cache allocation.
Finally it seeds the last captured cancel-before 2 KB, runs native `5C7A` with
continuation `5A10` (`5A0D JSR 5C7A`, also the captured stack word and `5A10`
foreground marker) and compares cancel-owned state to the captured `5A1C` return
image. `0x4D` is excluded only there because the captured `5A1C` foreground sets
it after the native cancel; no other byte is dropped.

The host inputs `0044/0045/0046` must equal the captured before image before they
are supplied. `719B` is outside the saved 2 KB (`save ...,0,800`) and is held to
the curator's declared sound-enable `00`; a changed fixture host is rejected, not
silently assigned. The queue-to-first-service comparison is limited to the stated
control/pool/link/cache ranges: other helper writes (including stack bytes) are
not claimed as full 2 KB equality.

These are explicit captured checkpoint/caller adapters, not a runtime schedule.
The verifier invents no intermediate task/channel state and compares against
original MAME observations, not C#-generated expectations. `NativeRoutineExecution`
has no CPU register file, so captured `S/U/X/Y/A/B` are oracle inputs; the test
does not claim generated CPU frame fidelity. Negative tests reject a tampered
snapshot hash, tampered retained frame, changed command order, truncated 2 KB
image, missing ROM region, an uncompared pool byte, the final channel link and a
wrong stack continuation. The first-window and last-occurrence cancel anchors
remain separate; no continuous queue-to-cancel execution is claimed.

## Limits

This proves bounded queue/service/cancel retained-state reproduction for the fresh
window. It does not prove continuous queue-to-cancel execution, timer1 cadence,
outer IRQ ownership, `6B4D`/`58BB`, finish CPU budget, Live ownership, audio or
hardware behaviour. The first-window cancel/return full 2 KB frames still require a
temp-guarded capture if that exact window must be certified end to end.

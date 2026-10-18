# Verify37 matched service component

Independent component verification of all 25 captured outer `5CD0/FECC` pairs from
capture36. Each pair is a fresh call seeded from its own actual 2 KB entry snapshot
and captured `719B` value; no saved return 2 KB is used as the next state. This is
not a continuous `FC4D..5A1C` replay and does not claim autonomous IRQ cadence.

## Inputs and provenance

- Capture fixture: `evidence/mpu4/collection/matched-service-window-capture36.json`
  (`AC60AC5EDE6A962B1FB90DFB8389EF85C6AFE304A25DD24CC7C753A2F59FDB82`), accepted
  at `6103e63`; unchanged.
- New ROM-region fixture:
  `evidence/mpu4/collection/native-service-rom-regions-capture36.json`
  (`DD5DFDCE3E44B51944180A9CB5A5DC84A11D917C3BFD7C301DD8F33F7F40E864`).
  It contains only actual `a6ls.p1` bytes: `5963+2B5` (tables and `59EB` stream)
  and `5C18+4C9` (native service/code/`60AB` cache helper). Source SHA1 is
  `402D1518BB78FDC489B06C2AABC771E5CE151847`; source SHA256 is
  `EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C`.
  No bytes are inferred or synthesized.
- Test: `AddersMatchedServiceVerification`; two groups are registered in the
  headless verification executable.

## What is checked

For every pair `sv00..sv24` / `fecc00..fecc24`:

- Saved 2 KB hashes, captured host/link/stack fields and saved RAM must agree.
  Entry PC is `5CD0`, return PC is `FECC`, return `S` is entry `S+2`, and the captured
  stack word at entry `S` is `FECC`. Each entry `719B` is the captured `00`.
- The machine is seeded with the full captured entry 2 KB and actual `719B`, then
  `AddersNativeSound.BeginCall(5CD0, ...)` runs with captured `S/U/X/Y/A/B` and the
  captured continuation word.
- The service must finish at `5D3A`, consume that continuation as `LastAddress`
  with one completed call, leave all mapped ROM bytes unchanged, and reproduce all
  `0x800` RAM bytes of the captured return frame. No byte is excluded.
- Service spans match the captured deltas exactly: `0x4E0` for `sv00` and `0x40`
  for each later pair. For `sv00`, the six captured `5D3B` events and the single
  `5CF3` event occur in captured order at their captured relative cycles
  (`4C, 20D, 24C, 276, 3AC, 3F9, 421`); these are checked from the saved event
  window, not fitted.

## Validation result

All 25 pairs pass the full 2 KB, continuation/completion, ROM-preservation, span and
event-order/cycle checks. Meaningful negatives are applied in memory and must reach
their intended semantic stage rather than stopping at the raw fixture pin: a return
frame paired with the wrong entry fails the actual execution RAM comparison
(`RAM 003`), a changed `return_s` fails the declared return-`S` check, a changed
captured return word fails the captured stack-word check, a host field that disagrees
with its saved RAM fails the host/seed check, a changed expected-return RAM byte
fails the full RAM comparison (`RAM 294`), and removal of the required `5963` ROM
region fails the required-region check. A separate control appends only JSON
whitespace to each raw fixture and confirms the pinned production entrypoint rejects
it at the fixture-hash stage; the unmodified semantic validator still accepts all 25
pairs.

## Captured versus generated state

The native execution adapter has no CPU register file. Captured `S/U/X/Y/A/B` are
seeded inputs to the isolated call; the code does not generate or compare a full
returning register file. `LastAddress` is the generated continuation value consumed
by the component (checked as the captured `FECC` word), not a generated returned-`S`
register. Returned `S` is validated from the captured return frame against the
captured entry `S+2` (`return_s`), so it is a captured-state consistency check, not
a generated CPU-register result. Passing the full 2 KB RAM comparison therefore does
not imply a recovered CPU register file.

`irqMasked=true` is an explicit isolation input for each bounded component call. It
means no interrupt is accepted inside that call; it is not evidence of a natural IRQ
cadence, foreground IRQ ownership, or continuous scheduler behavior.

## Limits

This proves the bounded per-call native `5CD0` component boundary for the captured
outer pairs. It does not prove continuous execution, foreground writes between
returns, nested `5CD0`, `5E29/5E6D` callbacks, timer1 cadence, outer-IRQ ownership,
`6B4D/58BB`, finish CPU budget, audio, Live ownership or hardware behavior. The
logical `44` operation is checked only as observed within each isolated call.

## Next task

Use the next roadmap ownership gate to connect an independent, explicitly bounded
service caller to real foreground/IRQ state without substituting captured task
trajectories; do not promote this component result to continuous gameplay.

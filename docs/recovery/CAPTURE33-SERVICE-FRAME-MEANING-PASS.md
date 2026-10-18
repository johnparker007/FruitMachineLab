# Capture33 service-frame meaning

Analysis only; no capture, runtime, fixture or Live change was made. This report
separates the raw observation from its earlier `service return` label. The
capture33 fixture remains valid as a single-occurrence **anchor set**; its
`FECC/FECE` frames are not the matched return of the captured `5CD0` call.

## Trace-backed finding

The capture33 raw files and debug log show:

- `5CD0` entry: cycle `0x3C578A5`, `S=078B`, `U=0672`, `X=0366`, `Y=0000`,
  `A=05`, `B=0B`, `0044=00`, `0047=01A0`. The word at `S` is `FECC`, so the
  captured `FEC9 JSR 5CD0` continuation is real.
- `FECC/FECE`: cycle `0x3C581B0/0x3C581B6`, `S=077F`, `U=59F2`, `X=0366`,
  `Y=0000`, `A=01`, `B=0B`, `0044=01`, `0047=0000`, `0049=01C5`.
- The 12 bytes at `S=077F` are `C000 3100 027E 01A0 59F2 5DB6`. In 6809
  interrupt-frame order this is `CC/A=C0/00`, `B/DP=31/00`, `X=027E`,
  `Y=01A0`, `U=59F2`, `PC=5DB6`; `5DB6` is inside the outer `5CD0` stream
  loop. The outer frame is still below at `078D`: `C020 2600 80A6 FC4F 0672
  716B`, identical to the saved `fec9.bin` frame at `078D`.
- Therefore an IRQ interrupted the outer `5CD0` at `5DB6`, and the captured
  `FECC`/`FECE` are the return from a **nested** `FEC9/5CD0` invocation. The
  nested `5CD0` saw `0044=01`, took the `5CD3 BNE 5D3A` early return, left
  `A=01` from `5CD0 LDA 44`, and did not change `0045/0046`, `0047`, or the
  stream cursor (`U=59F2`).
- A direct return from the captured `5CD0` must instead have `S=078D`
  (`S_entry+2`) and `0044=00`; the outer task would then be at `0047=01A0`.

Oracle31's gate28 `service-after` frame is the contrast: `FECC` cycle
`0x3CCC5DD`, `S=078D`, `0044=00`, `0047=01A0`; the stack at `078D` is the
outer IRQ frame `C00D 2800 80A6 FC4F 0672 716A`, with no nested frame. That is
a matched return. The capture33 cycle, caller, task state and stack depth are
its own and must not be fitted to gate28.

## Static/source

ROM `FEC9` is `BD 5C D0` (`JSR 5CD0`), `FECC` is `0F 2C` (`CLR 2C`), and
`FECE` is `20 38` (`BRA FF08`). The IRQ vector `FE70` calls `FEC9`.
`5CD0` tests `0044`, increments the guard/counter, unlinks `0047`, then jumps
through the task callback; `5D38` decrements `0044` and `5D3A` is `RTS`.
`5CD3 BNE 5D3A` is the early return used by the nested guard.

## Diagnostic component call

A temporary, untracked harness loaded the original ROM (SHA1
`402D1518BB78FDC489B06C2AABC771E5CE151847`) and seeded capture33 `sv.bin`.
`AddersNativeSound.BeginService(0,078B,0672,0366,0000,false,FECC)` completed
the native plan at `5D3A`, returned `FECC`, and produced `0044=00`,
`0047=01A0`, `0049=01C5`, `004B=01`, `027E=FF02`. Against capture33 `FECC`
this differs in 56 bytes, including `0044`, `0047/0048`, task record fields
and the nested stack area. The same harness from gate28 `sv-0.bin` matched
gate28 `fecc-0.bin` in all 2 KB (0 differences). This is a diagnostic
comparison, not a new accepted fixture or permanent failing check.

## Consequence and next task

Do not use capture33 `FECC/FECE` as the matched service completion in a
headless same-state verification. Existing raw is insufficient: the run saved
only the first `FECC`, which is nested, and no full matched-return frame.

Next task (capture, not this one): use the pinned campaign and one first
`FC4D` window, but log **all** `FE70` entries, `FF13` RTIs, `FEC9`, `5CD0`,
`FECC`, `FECE`, `5D3B`, `5CF3`, `5E29`, `5E2C`, `5E6D`, `5C7A`, `5A10` and
`5A1C` events with cycle, `S`, `U`, `X`, `Y`, `A`, `B`, `0044/45/46/47/49`,
`004B/4C/4D`, `719B` and raw stack words. Pair each `5CD0` by saved `S` and
return word; accept a matched `FECC` only when `S=S_5CD0+2`, `0044=00`, and no
new 12-byte frame sits at `S` (the frame at `S` must be the outer `FEC9` IRQ
frame). Save full 2 KB at that matched `FECC`/`FECE`, plus cancel/return.
Do not use a `first FECC after first 5CD0` temp flag alone. Bound the log by
the `FC4D..5A1C` cycle window and an event cap; no retry. Curate a separate
fixture only if every anchor belongs to the same occurrence.

## Limits

This establishes the meaning of the captured frames, not a continuous
`FC4D->5A1C` lifecycle. It does not add stream-command coverage, timer1
cadence, outer-IRQ ownership, `6B4D/58BB`, finish budget, Live ownership,
audio or hardware evidence.

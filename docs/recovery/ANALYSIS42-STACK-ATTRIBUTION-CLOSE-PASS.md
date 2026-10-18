# Analysis42 stack-attribution close pass

Scope: existing capture41 `stack-writer-0785-capture41.json` only (44 pre-commit
write events, `fc4d.bin`/`queue.bin`/`stop5cd0.bin`, opcode contexts). No new
capture, runtime, adapter, fixture or Live change. The capture41 occurrence is a
fresh gap; capture36 is used only as a net-delta comparison, never as an
instruction traceback.

## 0785..078A reconciled

The pre-commit sequence for the watched window is fully determined by the 44
events. Final values are `19 C1 00 0B 06 72` at `0785..078A`.

| byte | final | last writer | instruction | semantics |
|---|---|---|---|---|
| 0785 | 19 | event 30, tap `19C1` | `19BE BD 1A 58 JSR $1A58` | return `19C1` high byte; same-value after event 21 |
| 0786 | C1 | event 29, tap `19C1` | `19BE BD 1A 58 JSR $1A58` | return `19C1` low byte |
| 0787 | 00 | event 40, tap `51B3` | `51B1 34 16 PSHS A,B,X` | A=00 |
| 0788 | 0B | event 39, tap `51B3` | `51B1 34 16 PSHS A,B,X` | B=0B |
| 0789 | 06 | event 38, tap `51B3` | `51B1 34 16 PSHS A,B,X` | X high=06 |
| 078A | 72 | event 37, tap `51B3` | `51B1 34 16 PSHS A,B,X` | X low=72 |

The window is not one contiguous return. `19C1` is the `19BE JSR $1A58`
return; `000B` is A/B pushed by `51B1`; `0672` is X pushed by the same `PSHS`.
The `19B8 JSR $1A87` site introduces the final high byte `19` at event 21
(return `19BB`), then `19BB JSR $1A05`/`19BE JSR $1A58` rewrite the same `19`.
Thus analysis40's expected `19BB/439E/4395/280C/FEC3` chain does not describe
the final `0785..078A` window; the fresh trace corrects the attribution.

`51B1` is labelled `hyp_serial_receive_frame_parse`; the `PSHS A,B,X` bytes are
verified against the original ROM. The caller/return path into `51B1` (the
`6B4D`/`5330` path) is not fully traced by these watched writes and is left
open rather than inferred.

## All watched bytes 0780..078F

| byte | final | last event | source |
|---|---|---|---|
| 0780 | 06 | 26, tap `1A98` | exception-frame push (inferred); U high=06 |
| 0781 | 72 | 25, tap `1A98` | exception-frame push (inferred); U low=72 |
| 0782 | 1A | 24, tap `1A98` | exception-frame push (inferred); PC high=1A |
| 0783 | 98 | 23, tap `1A98` | exception-frame push (inferred); PC low=98 |
| 0784 | 00 | 22, tap `1A90` | `1A8E 34 02 PSHS A`, A=00 |
| 078B | FE | 44, tap `FECC` | `FEC9 BD 5C D0 JSR $5CD0`, return `FECC` high |
| 078C | CC | 43, tap `FECC` | same `JSR $5CD0` return low |
| 078D | C0 | 3, tap `716A` | outer M6809 IRQ frame CC=C0 |
| 078E | 47 | 2, tap `716A` | outer IRQ frame A=47 |
| 078F | 27 | 1, tap `716A` | outer IRQ frame B=27 |

`0780..0783` are best explained as an exception-frame push rather than an
opcode: the four same-cycle writes are contiguous PC/U bytes for interrupted PC
`1A98`; the rest of that frame lies below `0780` and was not watched. No opcode
match exists at the tap PC. The later nested FE70 anchor records a different PC
word (`9E28`), so this frame's exact origin is left as an inference, not full IRQ
semantics. `078D..078F` match the outer-frame B/A/CC values and are better
anchored. Eight events are same-value writes; they are retained in the ordering
and are not treated as no-ops.

## Capture36 vs fresh trace

Capture36 `queue->sv00` changes `0785 72->19, 0786 1A->C1, 0787 9E->00,
0788 19->0B, 0789 C1->06, 078A 00->72`. Its final window matches capture41, but
capture36 logged no instruction or stack-write trace. The identical values are
therefore shared-ROM static consistency plus a fresh-trace writer proof, not a
capture36 traceback. Capture36's ledger remains a snapshot net delta.

Analysis40 recorded `0785 00->19`; that `00` matches capture41's queue net, not
the capture36 raw queue (`0785=72`). The fresh pre-commit order is `00->3F->19`.
The address and final value reconcile; the old byte and writer are occurrence-
specific and must not be transplanted between captures.

## Next boundary

In `queue->sv00`, after `078A`, `078B/8C` (`FECC`) and `078D..0798` (outer FE70
frame) are attributable. The first changed byte with no unique source is
`0799`: `0799..079D = 02 71 5F 91 02` and `079F = 0A`. Capture41's own
`queue.bin -> stop5cd0.bin` shows the same `0799..079D` values, so this is not a
capture36 artifact. It is foreground caller-stack residue above the IRQ frame.

Across the interservice gaps, no changed byte in `fecc00->sv01` is left outside
the recovered sites: `0774/75=4916`, `0776/77=FEF2`, `0778..0783` nested FE70
frame, `0784` the `1A8E` PSHS A, `0785..078A` the `19C1`/`51B1` values,
`078B/8C=FECC`, `078E/F` outer-frame A/B. That gap is not itself instruction-
traced, but it introduces no new ambiguous byte. Later, `fecc24->cancel` adds
`079F 0A->10`, and `cancel->5A10` changes `0790..079D`; the first unresolved
byte in those transitions is `079F` and `0790` respectively. No sound-owner byte
is unresolved.

Missing evidence: writes to `0790..079F` (especially `0799`) are outside the
`0780..078F` watchpoint; there is no foreground instruction trace for the
caller stack.

## Next smallest safe task

One fresh natural `FC4D..5CD0` gap with a write watchpoint over `0x0790` length
16 (same MAME 0.281 pre-commit semantics), reusing the existing campaign. This
is not a duplicate of capture41: it covers the next address range only.

Acceptance: exactly one gap; at least one write to `0799`; log old/new/PC/
registers/opcode context; replaying old/new reproduces the final `0790..079F`
bytes in the stop snapshot; identify the final writer of `0799` (and `079F` if
written) with instruction/register semantics. Stop if no `0799` write occurs,
the event cap is reached, the ROM/MAME/source pins differ, or any writer needs a
non-unique indirect target. Do not claim complete IRQ semantics, 6B4D/58BB
causality, or build an adapter from net deltas. `6B4D/58BB` recovery remains a
separate static task; foreground integration is premature.

STOP

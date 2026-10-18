# Analysis40 foreground delta attribution

No new capture, runtime, adapter or fixture. The ledger is derived only from the
accepted capture36 JSON frames (`ram_hex`, full 2 KB per saved event) and the
original ROM identity. It is a snapshot net delta ledger, not a complete write
history. Detailed attribution stops at the first unknown byte.

## Ledger

28 transitions (queue->sv00, 24 `fecc[i]->sv[i+1]`, `fecc24->cancel`,
`cancel->5A10`, `5A10->5A1C`) contain 537 changed bytes: 26 sound-owner,
159 foreground/IRQ control, 352 caller/IRQ stack, 0 unclassified.

- `queue->sv00`: 62 bytes (16 owner, 6 control, 40 stack).
- All 24 `fecc->sv` gaps: 450 bytes, **0 owner**, 153 control, 297 stack.
  No sound-owner byte changes between a service return and the next service
  entry; those gaps are counter/scan writes plus IRQ/caller stack only.
- `fecc24->cancel`: 1 stack byte (`079F 0A->10`).
- `cancel->5A10`: 23 bytes (9 owner, 14 stack); `5A10->5A1C`: `004D 31->00`.

Machine-readable ranges and bucket counts are in
`docs/recovery/ANALYSIS40-FOREGROUND-DELTA-LEDGER.json`.

## queue->sv00 attribution (until first unknown)

Evidence classes below are recovered source verified in separate natural traces,
not a capture36 instruction trace, except the two IRQ frames and `FEC9` return,
which are anchored by logged capture36 events. The six control bytes are therefore
source-inferred, not capture36-trace-proven; they are not promoted to trace proof.
The first byte with no unique recovered source site is `0785`, where detailed
attribution stops.

- `0029 05->06`: `Mpu4OutputScanExecution 0x2944 STX $28`; word `0028`
  `0500->0600`. Separate 19-scan natural traces.
- `002C 00->FF`: `Mpu4InputServiceExecution 0xFEBE COM $2C`.
- `002E 16->17`, `0030 F6->F7`, `0033 9F->A0`: `Mpu4PostPanelExecution`
  `0x2813 STX $2D`, `0x2819 STX $2F`, `0x282B INC $33`. Separate 64 synthetic
  and 19 natural suffix traces.
- `006E 9F->A0`: `0x27D2 INC $6E`.
- `0047/48 0000->01A0`, `004A A0->C5`: `AddersSoundQueuePlan 0x5C63/0x5C5D`.
  `0049` stays `01`; the free head is `01A0->01C5`.
- `01A0..01B4`: same queue plan sites `0x5C61/0x5C4B/0x5C69/0x5C59/0x5C36/
  0x5C38/0x5C3F/0x5C56` (root/due/callback/stream/attenuation/zeros).
- `0775/76 = 4916`: `0x4913 JSR $4917` in the recovered 48FD/4917 path.
- `0777/78 = FEF2`: `0xFEF0 JSR,X` timer3 dispatch to 48FD.
- `0779..0784`: nested FE70 MC6809 frame, `CC=C4 A=00 B=99 DP=00 X=0006
  Y=0028 U=0672 PC=1A9A`.
- `078B/8C = FECC`: `FEC9 JSR $5CD0` saved return.
- `078D..0798`: outer FE70 frame, `CC=C0 A=1C B=28 DP=00 X=80A6 Y=FC4F
  U=0672 PC=716B`.

## First unknown

**`0785` (queue->sv00), `00->19`.** The six-byte window `0785..078A`
(`19C1 000B 0672`) lies immediately above the nested FE70 frame and below the
outer FEC9 frame. `19C1` is a candidate return from `0x19BE JSR 1A58`, but the
remaining `000B/0672` have no unique recovered writer. The set does not match
one recovered active return chain for `27D2->438C->19B8->1A87`
(`19BB/439E/4395/280C/FEC3`), and capture36 logged no instruction or stack write
there. Static plausibility is not treated as proof.

Missing evidence: exact outer FE70-handler stack write order between the nested
`FF13` and `FEC9`, covering `27D2/438C/19B8/1A87/1A05/1A58` and
`6B4D/58BB` (PSHS/JSR/pull order).

Smallest next boundary: one capture36-style inter-service gap with PC and
stack-write observation (or a stack-write watchpoint) from FE70 through FEC9.
Do not build the adapter from net deltas or reseed at returns.

## Files and verification

- Report: this file.
- Ledger: `docs/recovery/ANALYSIS40-FOREGROUND-DELTA-LEDGER.json`,
  15,646 bytes, SHA256 `C53E8DC98DE9A6F432B00011E40EBFC15CFA55FDF34796BEF5A68A83BE11CA17`.
- Fixture: `evidence/mpu4/collection/matched-service-window-capture36.json`,
  SHA256 `AC60AC5EDE6A962B1FB90DFB8389EF85C6AFE304A25DD24CC7C753A2F59FDB82`.
- ROM `a6ls.p1`: SHA1 `402D1518BB78FDC489B06C2AABC771E5CE151847`,
  SHA256 `EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C`.
- Only the report and ledger manifest entries were added; all 1,303 manifest
  entries verified by actual length/SHA256 (bad=0).
- No build or MAME run. Ledger generation exit `0`; manifest verification exit
  `0`. No capture, runtime, fixture, reseeding or autonomous-cadence claim.

STOP

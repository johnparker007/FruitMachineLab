# Capture61 IRQ prefix boundary: fresh FE70 to FEC3

Capture only. One bounded original-reset replay of the pinned gate-28
physical-input campaign ran in isolated MAME 0.281 with the original `a6ls.p1`
ROM, no state/playback load, no RAM/CPU/PTM/ACK/input injection and no reseed.
Baseline remains the accepted suffix state; this pass proves a fresh prefix
boundary, not the full IRQ or gate 3.

## Fresh occurrence

The first `FC4D` window after reset was selected. Its first outer `FE70` is its
own occurrence, not a replay of the historical cycles:

| Anchor | Cycle | Stack/identity |
| --- | --- | --- |
| `FC` | `0x3C4869E` | `S=07AA` |
| outer `FE70` | `0x3C4899E` | `S=078D`, return word `C018`, full 2 KB before first instruction |
| nested `FE70` | `0x3C48C73` | `S=0779`, return word `C400`, full 2 KB |
| `FF13` return | `0x3C48D4C` | same nested `S=0779`, full 2 KB |
| `2851` | `0x3C48E05` | guard entry, `1400=3436` |
| `288E` | `0x3C48E40` | `RTS` actually taken |
| `FEC3` | `0x3C48E45` | `S=078D`, `w@(S-2)=FEC3`, `w@S=C018`, full 2 KB |
| `FECE` | `0x3C494A0` | retained suffix, not the prefix oracle |

The fresh cycles intentionally differ from capture41/43/57. Identity is
stack/depth/return-word/cycle order: nested `S` is below outer `S`, `FF13`
returns at the same nested `S`, and `FEC3` returns to the outer `S` with the
same outer frame word and `FEC3` beneath it. No old absolute cycle or state was
required.

At `FEC3`, `2C=FF`, `44=00`, `6B=00`, `29=03` (`29&3!=0`), `1400=3436`,
`719B=00`, `719C=00`. The selected `2851..288E` path therefore passes
`TST 1400` / `BNE 288E RTS`; `SWI2 288F` is not reached.

## Timer3 state

Read-only Lua `emu.item` sampling of the PTM saved state was synchronized by
PC/`S`/`CC` to the same anchors. It reads saved items only; it does not read a
PIA or PTM bus register to observe state, so it cannot acknowledge an IRQ.

- Outer `FE70`: output3=1, control3=`00`, latch3=`0028`, counter3=`00CD`,
  enabled3=0, single3=1, status=`81`, irq=1.
- Nested `FE70`: output3=1, control3=`63`, latch3=`0028`, counter3=`0028`,
  enabled3=1, single3=1, status=`84` (timer3 pending), irq=1, divisor=8.
- `FF13` return and `FEC3`: control3=`00`, latch3=`0028`, counter3=`00D4`,
  enabled3=0, single3=1, status=`00`, status_read=7, irq=0.

`m_counter` is MAME's saved reload/frozen counter field, not a continuously
decremented register. Remaining timer ticks are not exposed by the saved-item
API and are not inferred. The installed local MAME source tree was used only to
identify item names and semantics; actual values came from the running pinned
binary.

## Trace and validation

The bounded trace contains 252 parsed rows (258 raw lines; cap 16384),
strictly increasing cycles and ROM-matching PC/opcode bytes. It explicitly
contains nested `FE70`, `FF13`, resume at `1AA2`, `2851`, `288E` and `FEC3` as
the last row. The selected `438C/439A/19B8/1A87` path is present; no `288F`,
active `6407`, `4167` or `7CCF` stop occurred.

Curator checks: 23 positive checks pass, 22 isolated negative controls pass,
manifest passes. Deliberate invalid FEC3 stack evidence exits 1, so invalid
positive evidence fails closed. Provenance pins the campaign input/replay,
MAME binary, ROM/zip, debugger script, isolated arguments and local timer
source hashes.

## Files

- Raw run: `artifacts/deepseek/capture-61/natural-irq-prefix` (ignored)
- Fixture: `evidence/mpu4/collection/irq-prefix-capture61.json`
- Curator: `tools/Curate-Capture61Evidence.py`
- Capture tool: `tools/Capture-IrqPrefix61.ps1`
- Validation, controls, manifest and result: `artifacts/deepseek/capture-61/`

## Next contract

Implement `2851..288E` only after `Mpu4PostPanelExecution`: with `44=0`,
require `0525 <= w@(S+0xA) <= 0676`, `0677 <= S <= 07C8`, then `1400!=0`
takes `RTS 288E`; preserve the captured registers and 59-cycle interval.
`44!=0`, `1400=0` and all range failures reach `SWI2 288F` and must stop
explicitly. Compare the composed prefix against the new outer `FE70` 2 KB and
`FEC3` 2 KB, stack words, `2C=FF`, cycles and nested timer3 occupancy. Stop at
the first mismatch, unknown `C6`, active `6403`, `7CCF` or SWI.

No whole-IRQ, cadence, Live, audio, hardware or gate-3 claim is made.

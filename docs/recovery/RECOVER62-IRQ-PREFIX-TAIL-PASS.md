# Recover62 IRQ prefix tail 2851..288E

Implementation only for the selected capture61 tail, on accepted baseline
`fabf81d` (415 verification groups). No prefix/Live integration, new capture,
RAM/PTM injection, install, config, credential, subagent, commit or push.

## Source-derived path

Actual ROM bytes and capture61 rows:

| PC | Bytes | Effect | CC before |
| --- | --- | --- | --- |
| `2851` | `0D44` | `TST <$44`; `44=0` sets Z | `C4` |
| `2853` | `260E` | `BNE 2863` not taken | `C4` |
| `2855` | `AE6A` | `LDX $A,S`; loads `w@(S+0xA)` | `C4` |
| `2857` | `C60A` | `LDB #$0A` | `C0` |
| `2859` | `8C0525` | `CMPX #$0525` | `C0` |
| `285C` | `2531` | `BCS 288F` not taken | `C0` |
| `285E` | `8C0676` | `CMPX #$0676` | `C0` |
| `2861` | `222C` | `BHI 288F` not taken | `C9` |
| `2863` | `C60B` | `LDB #$0B` | `C9` |
| `2865` | `118C0677` | `CMPS #$0677` | `C1` |
| `2869` | `2524` | `BCS 288F` not taken | `C0` |
| `286B` | `118C07C8` | `CMPS #$07C8` | `C0` |
| `286F` | `221E` | `BHI 288F` not taken | `C9` |
| `2871` | `7D1400` | `TST $1400` byte, nonzero | `C9` |
| `2874` | `2618` | `BNE 288E` taken | `C1` |
| `288E` | `39` | `RTS`; PC=`w@S`, S+=2 | `C1` |

Exact stack facts from the `GUARD_2851` capture: `S=078B`, `w@S=FEC3`,
`w@(S+2)=C018`, `w@(S+4)=2800`; `w@(S-2)=280F`. The ROM `LDX $A,S` plus the
trace (X `0003 -> 0672`) proves saved `U` is at `S+0xA`, not `S+0xC`.
`w@(S+0xA)=0672` is also present in the outer FE70 full 2 KB. Registers at
entry are `A=00 B=03 X=0003 Y=0028 U=0672 DP=00 CC=C4`.

Cycle markers: `2851 -> 288E = 59` cycles, excluding `RTS`; `RTS` costs 5,
reaching FEC3 at start+64 with `S=078D`, `PC=FEC3`. `RTS` preserves CC.

Flags are computed per the actual instruction effects: `TST` updates N/Z and
clears V while preserving C; loads update N/Z and clear V; `CMPX/CMPS` set
N/Z/V/C from 16-bit subtraction/borrow; branches do not change CC. All 16
captured rows, their pre-instruction CC, registers, start cycles, opcode
prefixes and final FEC3 state are compared. No CC is copied from `RTS`.

## Rejections

Before any mutation, `Mpu4PostPanelGuardExecution` rejects `44!=0`, saved
`w@(S+0xA)` outside `0525..0676`, `S` outside `0677..07C8`, and `1400=0`.
`44!=0` is the selected-branch boundary; out-of-range and zero cases name
`SWI2 288F`. Boundary `0525/0677` and `0676/07C8` are accepted. Negative
tests assert rejection messages and byte-identical memory.

Recover63 added the missing direct-page preflight: only the captured `DP=00`
branch is accepted, and every selected instruction byte is checked against
`Machine.Memory` before the guard reads. `DP=01/FF` and changed selected bytes
are rejected before mutation. These addresses remain fixed and are not
re-parameterized by `DP`; see `RECOVER63-GUARD-TAIL-DIRECT-PAGE-PREFLIGHT.md`.

## Tests and exits

- Headless build: `dotnet build FruitMachineLab.Headless.sln --ignore-failed-sources`, exit 0.
- Focused: `dotnet run --project tests/FruitMachineLab.Verification --no-build -- . 2851`, exit 0.
- Full suite: same without filter, exit 0, **417 groups passed** (415 baseline + 2).

## Limits

Single-machine test starts from the explicit captured 2851 register/stack
state. No full 2 KB at 2851 is saved; only the outer FE70 2 KB exists, so this
pass makes no full-RAM prefix or FEC3 comparison and does not reverse-fit
FEC3. Timer3 saved-item `m_counter` is not continuously decremented and
remaining independent timer-entry ticks are not exposed; no autonomous IRQ,
cadence, whole-prefix, Live, audio, hardware or gate-3 claim.

## Next task

Compose the captured outer FE70 2 KB and existing prefix components through
`Mpu4PostPanelExecution` into this tail, then compare the captured FEC3 full
2 KB, stack words, `2C=FF`, cycles and nested timer3 occupancy. Stop at the
first mismatch, unsupported `C6`/`4167`, active `6403`, `7CCF` or SWI.

Files: `src/FruitMachineLab.Runtime/Mpu4PostPanelGuardExecution.cs`,
`tests/FruitMachineLab.Verification/Program.cs`,
`evidence/mpu4/collection/irq-prefix-capture61.json`,
`artifacts/deepseek/recover-62/`.

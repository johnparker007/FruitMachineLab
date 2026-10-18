# Analyze60 IRQ prefix boundary after the accepted suffix

Analysis only. No new capture, runtime, adapter, fixture or Live change. Baseline
`eb7a40a` is the accepted integrate58/59 state: one machine runs
`FEC3 JSR 6B4D`, `FEC6 JSR 58BB`, native `5CD0` and `FECC CLR <$2C` to `FECE`,
with the full headless suite at **415 groups**. That proves the suffix only.
`FE70..FEC3` is still open, and gate 3 is not complete.

## Actual chain

Capture41, capture43 and capture57 have matching selected-occurrence anchors: the
FC entry cycle `0x3C592B3`, FC4D file hash, outer FE70 cycle `0x3C59673`, nested
FE70 `0x3C5994E`, `FF13` `0x3C59A27`, FEC3 `0x3C59B81`, `FEC9` `0x3C59CEE` and
first `5CD0` `0x3C59CF6` agree. Capture41/43 trace the stack/PC chain but save
2 KB only at FC4D, queue and the first `5CD0`; capture57 saves the FEC3/FEC6/
FEC9/sv/FECC/FECE 2 KB. No capture saves the outer FE70 2 KB or timer phase.

| Site | Status for the selected occurrence |
| --- | --- |
| `FE70` | Static assembly plus selected runtime `Mpu4Timer1DispatchExecution` (`FE70..FEB7`). Outer frame in capture41/43: `S=078D`, `CC/B/A/DP/X/Y/U/PC=C0/47/27/00/80A6/FC4F/0672/716A`. IC4/timer2/other indirect callbacks are explicit non-selected branches. |
| `28FE` | Recovered executable `Mpu4OutputScanExecution` (`28FE..29BA`), including `19C2/19FA/70EF` and the 48FD arm. Natural sense `0B02` is a supplied hardware read; the 38-count timeout/`SWI` alarm is not recovered. |
| `FEBA`/`2C` | Recovered executable `Mpu4InputServiceExecution`: busies to FECE when `2C!=0`, otherwise `COM 2C` and `JSR 27D2`. The selected path changes `2C 00->FF`. |
| `27D2` prefix | Same component through `2809 JSR 438C`: `INC 6E`, drive `D02/E00`, mux read `0F00`, sample write and `28/0..1 -> 28/0..1+4`. Drive writes and the mux read are explicit hardware callbacks. |
| `438C` | Recovered executable `Mpu4PanelAccumulationExecution`. At FEC3 `29=07`, so `29&3!=0`; the selected path skips `439F/46D3/43E9` coin decoding. `C6=19B8` is the observed indirect target. Other `C6` targets, `4167` and active coin/service paths remain explicit boundaries. |
| `19B8/1A87` | Recovered executable; `1A87` preserves A across the `8E+column` OR and `96+column` AND. |
| `1A05/1A58` | Recovered executable for the selected `29=07` checks and returns `19C1/439E`; the threshold `JMP 7CCF` trap is not taken and remains unrecovered. |
| nested timer3 | Real occupancy between `19BB` and `19BE`: nested `FE70`/`FF13` in capture41/43. `Mpu4TimedPanelService`, `Mpu4Timer3DispatchExecution`, `Mpu4LampCallbackExecution`, `Mpu4OrdinaryIrqReturnExecution` and panel `SuspendUntil` are the existing explicit path. It must never be collapsed into an empty gap. |
| `280C/6403` | `Mpu4PostPanelExecution` runs the idle sequence `JSR 6403`, `TST 6B`, `BPL`, `RTS`; the captured path has `6B=00`. The active four-reel body is not integrated and remains an explicit boundary. |
| `280F..2851` | Recovered executable (`2D/2F/31/33/35/28/0B02` effects). |
| `2851..288E` | **Static only; not implemented.** With `44=0`, `U=0672` and `S=078B`, the first checks pass. `TST 1400` must be nonzero to take `BNE 288E RTS`; the zero path reaches `SWI2 288F`. `1400` is outside the saved 2 KB, so this branch outcome is not in the current fixtures. |
| `FEC3` | Accepted suffix entry (`S=078D`, full 2 KB). `2C` is still `FF`; only suffix `FECC CLR` writes zero. |

## Composition assessment

For the selected idle/non-coin occurrence, the logical prefix can be composed
from existing verified components **after** the static `2851..288E` tail is
translated. No expected RAM delta or intermediate reseed is needed in the
composition itself. It must start from a captured FE70 entry 2 KB and timer
state, and preserve the real nested timer3 occupancy.

It **cannot** be composed from the current fixture set without reverse-fitting
or reseeding. Capture41/43 supply the prefix instruction/stack chain and the
outer frame, but not FE70 RAM or timer phase. Capture57 begins at FEC3. Deriving
FE70 by subtracting the expected prefix delta from FEC3 is expected-state
fitting. Existing Live is not a substitute: its atomic post-panel adapter clears
`2C` at `280C`, whereas the prefix requires `2C=FF` until suffix `FECC CLR`.

The first unexecuted point is `2851..288E`; the first unsupplied state is the
FE70 timer3 phase plus `1400`. Do not claim a full prefix before both are
resolved.

## Exact next task

One **strict minimal extension of the same campaign**, not a new campaign:
save the full 2 KB at outer FE70 before its first instruction, with
`S/U/X/Y/A/B/DP/CC`, `2C/44/6B/29/1400/719B/719C`, timer3 phase/latch/counter/
status, and the nested timer3 state; retain the existing FEC3/FECE 2 KB and log
exact `FE70->FEC3` instruction rows including nested `FE70/FF13`. No RAM/state/
PTM injection, no reseed, no duplicate fixture.

Acceptance: same ROM/MAME/source pins and the existing FC4D/outer FE70/nested
FE70/FEC3 cycles; monotonic exact rows; one full FE70 2 KB; nested timer3 entry
and return explicitly present; then compose `Mpu4Timer1DispatchExecution`,
`Mpu4OutputScanExecution`, `Mpu4InputServiceExecution`, non-coin
`Mpu4PanelAccumulationExecution`, idle `Mpu4PostPanelExecution` and a newly
translated `2851..288E` tail, and compare full 2 KB at FEC3, stack words, `2C`,
cycle totals and timer3 occupancy before the accepted suffix. Stop at the first
mismatch, unknown `C6`/`4167`, active `6403`, `7CCF` or `SWI`. No gate-3, Live
ownership, audio or hardware claim is made.

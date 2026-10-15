# Skill Cash through its normal board-result callers

15 October 2026. This pass connects the live feature to its recovered board take,
announcement, table dispatch and return path. It still starts from a captured
board-result boundary, not machine startup, credits or a complete spin.

## Executed route

With the Live checkbox enabled (the default), execution starts at E2FC with result
type 2 and board position 32. The ROM proceeds through E336, clears its feature lamp
range, tests the take flag at A0 bit 0010 in E2E5, and dispatches the type table at
E2D9. Type 2 selects DFF4, whose body DFF6 clears the nudge display, derives the cash
feature index from board position, initializes the announcement sound and renders
SKILL CASH. It waits for the actual translated sound tasks, resets them, clears the
feature lamp and executes table DFD8 index 5: token C71F/body C721.

After the live player selections and award transfer, execution returns through
99AB/E0BF, the outer table's 99AB, E2F3/E2F8 and E33C. The existing control stack
performs local cleanup; no direct call into feature-selection logic replaces these
dispatchers. Disabling the checkbox retains the original C721 entry for focused
diagnostics. Restart reloads the selected entry fixture.

Only this type-2/position-32 route is supported live through the wrapper. The table
contains other results and features whose execution is not claimed. Clearing the
take flag skips the feature through the recovered branch. That test is a synthetic
state variation, not a newly captured physical button campaign.

## Natural reference evidence

Two fresh isolated MAME runs use the existing physical-input campaign unchanged.
Capture-SkillCash.ps1 -FullFeature -CashFeatureCaller captures DFF6..E0BF;
adding -BoardResultCaller captures the surrounding E2FC..E33C route. Both use
-NativeSound -NativeAlpha -NativeLampFrames -CpuInterrupts. Neither injects ROM,
RAM or registers. Curate-SkillCashCaller.ps1 retains selected entry/exit rows,
native output observations, timing minima, provenance and debugger commands.

Both captures independently reproduce the original complete C721 body's 98,704
dispatches and canonical 25-field SHA256. The narrower caller entry matches 100
dispatches, all 51 announcement alpha bytes, all 30 sound commands (including
cursor, opcode, clock, choice, rate, tempo, gate, flags, pitch and transpose), and
its native lamp-frame result. The wider entry matches 124 dispatches with the same
sound/alpha comparisons and all of its lamp-frame results.
The captured 76BD local-release dispatch is handled inside VmControlStack.Return;
it is not exposed as an extra host VM step. Live exit checks compare visible
dispatch/control/data-stack state and award/display/flag memory, not IRQ phase or
random seed equality under different player timing.

The entry verifier supplies captured tick, IRQ, latch and sound-clock boundaries;
this is a diagnostic reference replay. Live continues to use physical Start and
the explicit captured pacing/IRQ adapters. Costs are minimum measured dispatch
durations after removing nested IRQ occupancy, as in the preceding pass.

## State and translation boundaries

The caller fixture reuses the verified feature prerequisites, then restores observed
caller stack, accounting fields, flags and output prerequisites. The wrapper's
extra result-type cell has a fifth underlying cell observed later at DFF6; its U
mapping is preserved. Initial alpha data comes from the first native alpha call,
after the nudge digits have been cleared. These are sufficient boundary prerequisites,
not a full authentic power-on RAM image. The recorded caller return address is
replaced with an explicit BEEF terminal sentinel outside the supported boundary.

New VM mechanics are conditional duplicate (7B4B) and loop-unwinding return (7937).
The existing return implementation already removes active loop/local frames.
The native 4982 lamp stub supplies inline pattern 80; its low nibble clears all
four frames. Hash-checked ROM data supplies the announcement sound and its child
streams, title strings, flag/range records and type table. Dynamic tokens C71F and
DFF4 have explicit recovered body mappings; unknown dynamic words still fail.

## Continuation

81 headless verification groups pass, including all original reference proofs,
both prelude replays, all six award levels through both entry modes, take-flag
suppression and live exit stack/accounting checks. Headless and isolated WPF builds
pass. Live, accelerated jackpot and recorded playback smoke modes are checked, with
announcement/completion renders. The Live smoke checks scheduler/IRQ state after
Resume while the VM waits for announcement sound, rather than requiring a dispatch
during that wait. Cold-load assertions explicitly suspend the execution timer.

The next boundary is the feature-board loop around E43D/DE75: destination changes,
board movement, take/continue inputs and persistent entry/exit state. Recover the
needed mechanics and normal-play references before exposing a whole-game mode.
No repeated fixture resets should be counted as consecutive machine games.
FML integration remains planned alongside that work using John's existing repos.

The original analysis workspace is preserved. No installation, machine configuration
change, cloud setup, commit or push was performed.

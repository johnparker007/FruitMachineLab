# Skill Cash award coverage and IRQ occupancy

15 October 2026. This pass extends the live feature; it does not implement normal
machine startup or a complete game. It supersedes the unsupported-jackpot and live
pacing figures in SKILL-CASH-LIVE-PASS.md. No dependencies were installed, machine
configuration changed, or original analysis files modified.

## Playable coverage

Live execution now supports the recovered A365 jackpot announcement, including its
lamp stream, delayed alpha continuation and sound-stream transposition. Repeated
physical Start selections of each default level complete with current-win values
10, 16, 20, 22, 30 and 60 ROM units. These are synthetic player-input tests from the
existing feature-entry state, not six independently captured MAME campaigns. The
6,6,6 run completes at 23.777 virtual seconds, with pending award zero, four retained
entry stack cells and the expected return sentinel. No recorded player events are
substituted in Live mode. Original verified playback remains separate.

The alpha translation now applies native 3FBD's six-bit character mask to ordinary
characters. The earlier numeric display path did not expose this letter-output bug.
The software shadow displays NEW 6.00 JACKPOT; brightness and electrical VFD blinking
are not modeled, even though the emitted control bytes are checked.

## Synthetic MAME helper proof

Capture-SkillCash.ps1 -FullFeature -JackpotProbe -NativeSound -NativeAlpha
-NativeLampFrames -CpuInterrupts redirects Y from C767 to A365 at a controlled
return boundary. The complete preceding 98,704-dispatch, 25-field VM digest matches
the original campaign. This deliberately invokes a helper; it is not evidence of
a jackpot reached through normal gameplay. Curate-SkillCashJackpotProbe.ps1 retains
the redirect, initial state, sparse hardware schedule, hashes and debugger commands.

The translated helper replay matches 70,762 checked VM observations, 485 lamp
requests, 339 sound commands and 265 alpha serial bytes. The first logged C767
observation is explicitly mapped to the redirected A365 token. The active-list
predicate at 856F is lifted as a boolean scheduler query: its internal four VM
observations are excluded rather than inventing native allocator pointers. Four
residual stack cells are seeded from the capture. Replay stops before A398 returns
into the original caller. Captured tick/latch boundaries belong to this diagnostic
proof; they are not player-input injection into Live execution.

Supporting static translations include U-stack save/restore and overlapping memory
copy, lamp clear/stream commands, alpha reset/control/delay/jump/resume and sound
DA diatonic transposition. Selected data is extracted from the SHA1-checked ROM by
Curate-SkillCashExtensionData.ps1. Memory copy preserves native direction and 16-bit
wraparound. The mapped data stack is synchronized at pointer/copy boundaries; this
does not establish arbitrary future RAM alias behavior for every VM operation.

## Captured CPU boundary

A fresh unmodified campaign with -FullFeature -SharedTiming -CpuInterrupts matches
the original state.csv, feature-state.csv, input-levels.csv and final RAM hashes.
It records 12,206 IRQ entries, maximum nesting three. The union of outer entry-to-
RTI-instruction-entry intervals occupies 13,043,839 of 20,999,847 cycles (62.114%).
Curate-SkillCashCpuInterrupts.ps1 subtracts those intervals from observed dispatch
durations before selecting minimum instruction costs. Live execution now suspends
main-VM dispatch during these captured occupied intervals; peripheral callbacks
continue. Reference-time player inputs produce 147,310 dispatches / 12.317 seconds,
versus the reference 98,704 / 12.209 seconds, while matching the same 18 VM/frame/
accounting checkpoints, 44 alpha states and final lamp-frame memory.

This remains a captured scheduling adapter, repeated beyond its recorded period.
IRQ acceptance/stacking and actual RTI instruction cycles are excluded. Native
helpers are atomic translations. New helper costs use measured probe minima and
two explicit static aliases: A363/9B3E share header 00F8; 7F0D/7F07 share 7946.
These are structural timing deductions, not measured equivalence. Full CPU state,
transient scan timing and general platform scheduling remain unresolved.

## Normal-play boundary

AddersCashFeatureDispatch executes the recovered DFF8..E0A1 selector, preserving its
branches and ROM table at DFD8. Board positions 4,9,12,19,26,32,37,42,47 select
indices 0..8; position 32 selects C71F, whose body is C721. The unusual fallback is
preserved. The surrounding route clears the nudge pot, initializes sound/rate and
the feature title, dispatches through 99A1 and returns through 99AB/E0BF. Only the
pure selector is executed here; surrounding entry/exit and persistent game state
are the next work, not an implemented whole-machine mode.

## Checks and continuation

77 headless verification groups pass, including all original reference proofs,
all six default award levels, jackpot helper digests, stack/memory edge cases,
lamp command guards, alpha continuation, transposition and IRQ occupancy validation.
Headless and isolated WPF builds pass. Normal Live and playback smoke checks pass;
the opt-in --live-jackpot-smoke-test also passes and renders the announcement and
completed award. That jackpot driver advances virtual cycles rapidly and supplies
physical input levels; it is explicitly not a real-time jackpot-targeting test.
The normal Live smoke separately tests the real-time mouse input/pause path.

Continue toward normal feature entry/exit and the retained machine lifecycle. Other
options, compensation branches and physical scheduling still need evidence; six
default levels do not establish complete Skill Cash or whole-machine coverage.
Use John's existing FML importer/renderers when he supplies the reference repos.

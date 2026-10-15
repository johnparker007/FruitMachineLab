# Automatic nudge improvement and pending result

15 October 2026. Live now continues after the three manual Nudge1 requests.
It executes the ROM's improvement decision, displays I CAN DO BETTER, rewinds
the moved reel, displays LET ME THINK / HERE I GO and executes its computed
automatic nudge plan. Final positions are 6,90,42 and symbols 2,2,2. Pending BA
becomes 0010 (16 ROM units), current win 02FA remains 0000, and BE/BF are cleared.
Live stops explicitly at E263 before returning to the result caller. This does
not yet bank, collect or pay that pending result, or complete a whole game.

## Recovered route

Natural physical TAKE at square22 and three momentary BLACK2 Nudge1 pulses lead
through the previously verified B749 boundary. B712, for BD=15hex, calls B652.
That test accepts a normalized current matching result at least as large as the
saved target at local+7, or common symbol flag2. This captured result is worse,
so B712 executes B666 and B6DB. Other options/branches are not newly established.

B626 previously saved initial reel indices at local+4..+6, target at +7 and
count at +8. B666 announces the improvement and restores BE/BF from +8. It
compares the saved/current reel indices and makes negative request steps to
rewind. Each step uses the recovered 61F6 preparation, IRQ motor service,
generated optics, cleanup, symbol refresh and native waits. This path rewinds
reel1 from90 through0 and6 to12 rather than teleporting it back to its start.

B6DB announces LET ME THINK and HERE I GO, then B384 sets local+2 to FF, runs
B352 and clears it. B352 calls native2A2F via token8084 to compute the plan.
The selected plan makes two moves, one on reel1 and one on reel2. All eight
motor requests in the complete reference (three manual, three rewind, two
automatic) execute through the translated motor, not captured outcome writes.

B72D cleans up the nudge sequence and local frame. B91D and E247 evaluate the
ordinary matching result, store pending BA and invoke existing native6E06
NVRAM refresh. The result remains pending at the E263 return boundary.

## Native plan and VM outer index

2A2F..2A7E is a byte-checked native routine reached through8084. It consumes a
budget cell, uses its low byte, allocates a counted17-byte U scratch frame via
6FA2 and calls the existing2A7F search. It ASRB-shifts scratch bytes1,2,3 and
SEX-sign-extends each to a VM cell, pushing reel1 then reel2 then reel3 (top).
It restores symbols0160/0162/0164 and leaves DD unchanged, unlike29F4. Search
scratch, C8/A8/DE effects, candidate order, byte wrap and ties remain observable.
Counted-frame overflow still fails explicitly; CPU S-stack residue is not claimed
complete. No suspected ROM behaviour was repaired or replaced with a host rule.

The isolated nudge-plan-matrix has ten plan cases and seven lookup cases. It
compares every RAM byte below0700 after synchronizing the actual U-stack cells,
covering return order, scratch writes, symbols and flags. Budgets include zero,
large/wrapping low bytes and ignored high bytes. These are synthetic experiments
with explicit PC/register/RAM setup and masked IRQs, not natural gameplay proof.
The connected natural route separately verifies the plan's use during gameplay.

New token7A26/native7A28 implements the outer loop index by LDX direct F6,
LDD [6,X], PSHU D, JMP direct FC. The translation follows the saved outer F6
pointer and preserves the 16-bit index, rather than assuming a host loop depth.
Focused nested-loop verification and the connected rewind/automatic path cover it.

## Evidence and verification scope

nudge-result.json contains 66,368 canonical VM observations, 162 lamp requests
with complete frame results, 1,005 sound commands with protocol state/timing,
405 alpha bytes and the E263 RAM snapshot. Its first 7,785 observations independently
match nudge-sequence.json. The raw 72,565-observation digest is retained. The 6,197
excluded observations are exactly 1,549 four-dispatch typed scheduler-list tests
and one inline76BD local-release dispatch. The verifier derives that count from
executed856F tests and the physical local-release frame; it cannot silently accept
an arbitrary exclusion count. The earlier141 undefined-local masks are unchanged.

Two completed fresh MAME campaigns agree on the complete canonical VM digest:
911A8D2923B1E41EF2E2A95C6E8B0CCAA420E217C26DAF0FBE5F555A0F958101.
The native fixture also records an independently checked3,360-observation core
sequence (PC, flags, drive, records, protected position bytes and checksum).
Eight preparations/completions and72 optic reads are retained. The reference
adapter checks translated active motor states and independently generated optics;
idle service observations are retained, not full CPU-register equivalence claims.

The terminal capture saves RAM while paused at E263, before the caller executes.
The connected verifier compares all51 bytes2F0..322 (source NVRAM, complements
and checksum), plus pending BA. Live matches those same51 bytes and final reel
symbols/positions. Individual native refresh read/IRQ interleavings were not newly
captured; existing NVRAM helper verification remains unchanged. This result proves
pending16/current-win0, not a payout or currency conversion.

Live uses equivalent player actions rather than recorded input events. Its
ordered lamp request sequence and final alpha shadow match the connected path;
all three announcements are observed. Actual mid-rewind pause freezes VM memory,
motor state and virtual time; Resume continues. Its dispatch counts and elapsed
timing differ because CPU/IRQ pacing remains the declared provisional adapter.
Do not infer full CPU scheduling or transient alpha-blink timing equivalence.

Two exploratory captures with more debugger observers ended in external MAME
access violations and are excluded from complete-path proof. Successful runs
completed exit0. The final capture adds a read-only terminal RAM save and stops
there; no original ROM, Ghidra project or MAME setting was changed. The capture
tool now rejects unsuccessful MAME exit codes before curation.

## Preservation checkpoint

The existing nudge encoding checkpoint now checks700 selected native disassembly
rows and17 VM spans against the SHA1-verified ROM. It retains2A2F native bytes,
8084/7A26 dictionary encodings, the outer-index primitive, the improvement/plan/
result VM spans and their embedded alpha bytes. New data ranges preserve the
8B99 and9424 sound headers/streams, referenced940F child/call stream and B666..B70F
inline programs. These are linked to C# handlers, semantic maps and fixtures.
The B712/B652/B72D listing purpose labels now reflect this traced route while
qualifying unverified branches. Names are recovered descriptions, not source.

This remains selected byte coverage, not a lossless full-ROM listing or rebuild.
No assembler/compiler/editor/relocator was built. No live Ghidra tools are exposed;
fresh portable symbol/comment/data-definition exports remain an explicit access
gap. Existing saved exports and all earlier evidence remain preserved.

135 headless verification groups pass. Headless and isolated WPF builds succeed.
All eight GUI smoke modes pass. The nudge smoke covers first movement on all
three controls, prompt return, three-press exhaustion, automatic improvement,
mid-auto-motor Pause/Resume, pending16/current-win0, released inputs and restart.
It uses focused keyboard handlers for nudge acceptance and tests mouse-capture
release; automated held-mouse nudge acceptance is still not claimed. Playback
remains separate and all earlier reference/timing qualifications remain in force.

## Reproduction and next work

Select Ladder animation: natural entry (DBC4), enable continuation, start
execution and press TAKE FEATURE at square22. Press/release NUDGE1 at each of
the three prompts, then watch the automatic improvement without additional input.
The diagnostic result stop shows pending16/current-win0 and symbols2,2,2.

```powershell
./tools/Capture-SkillCash.ps1 -MameExecutable <mame281.exe> -RomDirectory <roms> -RunDirectory <fresh-result> -FullFeature -NativeSound -NativeInput -NativeLampFrames -NativeAlpha -CpuInterrupts -BoardLink Ladder -ContinueBoard -Availability -NudgeEntry -NudgePrompt -NudgeRequest -NudgeMotion -NudgeReturn -NudgeSequence -NudgeResult
./tools/Curate-DiceMotion.ps1 -RunDirectory <fresh-result> -RomPath <a6ls.p1> -Nudge -Sequence -Result -IndependentRunDirectory <other-completed-result>
./tools/Curate-BoardLink.ps1 -RunDirectory <fresh-result> -LinkKind ladder -Continuation -Availability -NudgeEntry -NudgePrompt -NudgeRequest -NudgeMotion -NudgeReturn -NudgeSequence -NudgeResult
./tools/Capture-AvailabilityMatrix.ps1 -MameExecutable <mame281.exe> -RomDirectory <roms> -SeedRam <boundary-ram.bin> -RunDirectory <fresh-matrix> -Plan
./tools/Curate-AvailabilityMatrix.ps1 -RunDirectory <fresh-matrix> -Plan
./tools/Export-MameDisassembly.ps1 -MameExecutable <mame281.exe> -RomDirectory <roms> -RunDirectory <fresh-disassembly> -NudgeCheckpoint
./tools/Curate-NudgeEncodingCheckpoint.ps1 -RomPath <a6ls.p1> -DisassemblyDirectory <fresh-disassembly> -StackRunDirectory <completed-return-stack-capture>
dotnet build FruitMachineLab.Headless.sln --no-restore
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .
```

Next continue E263 through its physical caller, pending-result presentation,
award handling and feature return. Preserve source/byte/evidence links for facts
found there. Whole-machine startup, other result/options, banking/collection and
consecutive complete games remain open. No agent installs/configuration changes,
commits, pushes or cloud setup were performed.

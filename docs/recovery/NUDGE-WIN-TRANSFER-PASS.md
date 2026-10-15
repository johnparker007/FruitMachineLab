# Nudge board exit and current win transfer

15 October 2026. Live now returns from E263 through the actual indexed-result
caller, executes the feature-board exit, and animates pending16/current-win0 to
pending0/current-win16. The translated scripts execute each meter increment and
NVRAM refresh. No bank, collection or payout operation is substituted.

The Live stop is AFC2 immediately after the final increment's native6E06 refresh,
before the following display refresh, wait, rounding/blink tail or award dispatch.
Those later routines are not established by this milestone. Startup, full games
and other inputs/options remain outside the recovered feature-entry path.

## Board exit reference from a successful capture

The E263 physical S-stack contains99AB,E2F3,E33C,E44D,EE0D,EE29,EE74,FC76
followed by older frames. These are return cursors in the captured context, not
an inferred host call sequence. E263 returns through99A1, E2E5 and E2FC to E43D.
E44F tests the actual exit flag, then the recovered VM clears lamps, runs E3E2,
clears the0400 mask in A0 and ORs0001 at0085 before reaching E460.

The fresh nudge-exit capture completed with exit code0 and saved terminal RAM
at E460. Its66,412 canonical observations independently preserve the earlier
66,368-observation nudge-result prefix.171 lamp requests with complete frame
results,1,005 sound commands and424 alpha bytes match the runtime. The verifier
checks the protected source/complement/checksum vector2F0..322 and pending/current
win at that saved boundary. Both remain16/0; this exit does not bank the award.

Live uses the same recovered caller returns and outputs, retaining its machine
state. The former E263 stop is removed; unrelated non-nudge board entries retain
their earlier E460 boundary. No renderer or button handler implements accounting.

## Transfer prefix from a capture that failed later

The exploratory outer-caller capture subsequently suffered an external MAME
access violation after the transfer observations. It is not a successful complete
campaign. The raw log already contains a complete prefix through AFC2 with BA=0,
current win0010 and checksumE4 after native6E06. This prefix is curated separately
as nudge-win-transfer.json, explicitly marked ObservedPrefix in its provenance.
The unsuccessful process exit code and full raw-log hash remain in the sidecar.
There is no terminal RAM snapshot and no claim of later tail completion.

Two later exploratory runs also failed in MAME. An intermediate capture command
would have disabled ordinary logging at the first AFC2 rather than only the final
increment; that attempt was excluded. The corrected capture command keeps logging
active and has a separate terminal observer for AFC2 with pending0/current-win16.
No failed attempt is passed off as the successful board-exit reference. Existing
original ROMs, MAME settings and Ghidra projects were not changed.

The selected transfer prefix independently preserves all66,412 observations of
the successful exit reference. It contains95,391 canonical observations,
101,588 raw observations through the selected boundary,203 lamp/frame requests,
1,341 sound commands and987 alpha bytes. The same6,197 typed scheduler-list/local-
release observations are excluded, with their count independently derived by
execution. Raw source beyond the selected prefix remains outside Git, its full
file hash retained. The canonical prefix digest is:
5B4942532A015539C532A8E550AEB1A77131E558F97A547B83FDCB0942604842.

All canonical state signatures, lamp/frame, sound protocol and alpha bytes match
the runtime through the selected boundary. This proves the recorded prefix,
not the cause of the later external crash or full machine stability. Unlike the
successful exit fixture, the transfer fixture cannot verify all terminal RAM.
The verifier requires the explicit observed-prefix provenance and boundary shape.

## Recovered transfer behaviour

E460 returns through EDD3/EE11. Common-symbol flag2 is false on this route, so
EE2C calls EDB4 before returning toward the outer game caller. The earlier idea
that this would proceed directly to FC76 award dispatch was incomplete; the
recorded stack and following dispatches establish this intermediate step.

EDB4 first executes ED06's result lamps and sound, applies ED94's jackpot gate,
normalizes pending and calls AF93. AF93 chooses its decrement via the existing
8560 indirect-zero tests. In this captured configuration they select minus one.
AFB8 adds that signed decrement to BA; AFBA negates it and AFBE adds it to02FA.
AFC0 calls native6E06. The following AFC2 observation sees the committed new
current-win cell and complement/checksum effects. Existing underflow behaviour
on the alternate two-unit branch remains unchanged and separately tested.

Live tests observe AFC2 for current-win1..15 and verify BA+02FA remains16. The
final AFC2 is the explicit pre-execution stop with pending0/current-win16. Live
ordered lamp requests and final alpha shadow match the selected reference;
final reel symbols/positions match the earlier saved exit state. Source NVRAM
complements are internally checked, but exact complete terminal RAM equality
is not claimed without a terminal transfer snapshot. No monetary-unit conversion,
cash-bank credit or hardware payout is inferred from the16 ROM units.

Pause/Resume freezes actual VM memory and virtual time during both the automatic
reel rewind and the intermediate meter animation. Physical nudge input is released
after acceptance, on pause/loss/stop, and on restart. Recorded player input events
are never applied during Live. CPU/IRQ pacing remains the explicit provisional
adapter; exact CPU scheduling and all transient brightness effects remain open.

## Preservation and verification

No newly guessed native helper was needed: this route executes existing recovered
scripts and translated helpers. The selected data map now includes the byte-checked
8B41..8B8A sound header/child streams used by ED06, plus the AF76 inline alpha
span for future tail work. The existing nudge encoding checkpoint now preserves
38 exact VM spans, including board callers, EDB4/ED06/ED94/ECD6, AF93, threshold,
lamp and indirect-test/display helpers. Its700 native disassembly rows remain
byte-checked; this is selected coverage, not lossless full-ROM reconstruction.
Addresses, inline operands, branch targets, embedded data and unresolved coverage
remain linked to existing listings, semantic maps and C# verification.

Fresh Ghidra symbol/comment/data-definition exports remain an explicit access
gap. The symbolic assembler/reassembler/editor toolchain remains deferred until
playable-machine coverage. No installation or configuration change was made.

137 headless groups pass. Headless and isolated WPF builds succeed. The expanded
GUI nudge smoke checks real-time board exit and transfer, mid-auto-motor and
mid-meter pause/resume, pending0/current-win16, released input and restart. The
other seven modes retain Skill Cash, jackpot, availability, roll, links, repeated
board selection and separate verified playback. Nudge acceptance is driven by
focused keyboard handlers; actual held-mouse acceptance is not automated.

To test, choose Ladder animation: natural entry (DBC4), enable continuation,
start execution, TAKE FEATURE at square22, then press/release NUDGE1 at each of
the three prompts. Watch automatic improvement, the board exit and the meter
transfer. The final diagnostic stop displays pending0/current-win16.

## Reproduction and next work

Use the NUDGE-IMPROVEMENT-PASS capture flags plus -NudgeExit for a successful
E460 exit capture. Curate with the same flags and -NudgeExit. Adding
-NudgeWinTransfer requests the final AFC2 boundary. Only a fully observed selected
prefix from a failed-later capture may use the explicit -ObservedPrefix curator
option; ordinary curation now rejects unsuccessful process exit codes.

```powershell
./tools/Capture-SkillCash.ps1 -MameExecutable <mame281.exe> -RomDirectory <roms> -RunDirectory <fresh-run> -FullFeature -NativeSound -NativeInput -NativeLampFrames -NativeAlpha -CpuInterrupts -BoardLink Ladder -ContinueBoard -Availability -NudgeEntry -NudgePrompt -NudgeRequest -NudgeMotion -NudgeReturn -NudgeSequence -NudgeResult -NudgeExit -NudgeWinTransfer
./tools/Curate-BoardLink.ps1 -RunDirectory <run> -LinkKind ladder -Continuation -Availability -NudgeEntry -NudgePrompt -NudgeRequest -NudgeMotion -NudgeReturn -NudgeSequence -NudgeResult -NudgeExit -NudgeWinTransfer -ObservedPrefix
dotnet build FruitMachineLab.Headless.sln --no-restore
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .
```

Next obtain a clean terminal transfer snapshot if possible, diagnose the repeatable
external capture crash, then recover the final display/wait and AF67 tail and
the actual outer award route. Do not fabricate a transfer to cash bank, collection
or payout. Full-machine startup and hundreds of complete games remain future work.
No commits, pushes, installations, configuration changes or cloud access performed.

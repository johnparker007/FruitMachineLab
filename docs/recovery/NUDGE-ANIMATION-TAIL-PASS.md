# Nudge current win animation tail

15 October 2026. Live continues past the last meter increment, refreshes the
display, executes the remaining wait and the recovered seven-flash AF67 tail,
then stops at AFF0 before the outer award route. Pending remains0 and current
win16 ROM units. No bank credit, collection or payout is fabricated.

## Successful natural window capture

The new nudge-tail reference is a narrow natural window from final AFC2 to AFF0.
A fresh physical-input MAME campaign reaches AFC2 with pending0/current-win0010.
A read-only debugger observer saves entry RAM and enables VM logging there;
the terminal observer saves RAM at AFF0. There are no PC/register/RAM/ROM edits.
The process exits0 and there are no debugger expression errors. The saved initial
sound-list head is zero; no untyped native sound continuation is injected.

All initial signature fields except the source CPU cycle identity are independently
required to equal the earlier nudge-win-transfer prefix's final observation:
VM site/token, stack cells/U/S/F4/F6/local word, clocks, IRQ counter, seed, latch,
accounting, guard/checksum/mode/display/suppression, board and pot. The original
failed-later prefix and its qualifications remain intact. This is linked-window
verification, not a new single full-dispatch capture of the entire campaign.

The new window contains13,469 canonical/raw VM observations, with no lifted
dispatches or undefined-local exclusions. It has zero lamp requests,63 sound
commands and406 alpha bytes. Canonical VM digest:
F3ABD2BBE672B2F2FA4D87CC6E717D73144A3C85977DE52103EF10D12A728730.
All VM signatures, sound state/timing and alpha bytes match the runtime. Terminal
RAM is captured and compared, including51 protected source/complement/checksum
bytes2F0..322 and pending/current-win words. This closes the terminal snapshot gap
for the completed tail; it does not retroactively make the earlier process exit0.

## Recovered execution

At the old AFC2 stop the increment and native6E06 refresh had completed, while
the following display still showed the preceding value. AFC2 onward now refreshes
the current-win register, executes the remaining native-timed sound/wait loop,
updates the bank-related display, and returns through the zero-pending test.

AFE6..AFEC explicitly clear pending and refresh NVRAM. AFEE calls AF67. AF67
resets sound, calls AF4E to round current win upward to an even cell, refreshes
the display, queues the8716 sound stream and runs exactly seven loop iterations.
Each iteration clears the six-character balance region, waits20 IRQ ticks,
refreshes the balance and waits20 again. Current win16 stays16. The final display
refresh is now visible rather than stopping one increment behind.

AF4E preserves native16-bit arithmetic: odd FFFF rounds to0000, not a saturated
host value. A focused synthetic test covers0,1,16,17,FFFE,FFFF and the resulting
NVRAM complements. It is separate from the natural16-unit window proof. No
rounding rule or suspected ROM behaviour was changed.

## Capture investigation and limits

A full-dispatch retry again suffered an external MAME access violation after
the old transfer boundary. Removing the per-frame saved-item reader alone did
not prevent that failure, so it is not an established explanation. The new
-NoMotorItems option only omits that read-only observer in the temporary capture
script; native motor/optic observations remain enabled. Original settings and
projects are preserved. The crash's root cause remains unresolved.

An earlier apparently successful tail run had a rejected breakpoint condition:
MAME reported an unbalanced-parentheses expression and logged only the feature
entry and terminal observation. Its exit0 and RAM snapshot were insufficient
for full-dispatch proof. Prefix verification rejected it, and it is not the
curated reference. Capture and curation now reject debugger expression errors.
The corrected primary condition uses supported comparisons. The successful
-TailWindow capture avoids full earlier dispatch logging; this observation
suggests a harness/logging interaction but does not establish causation.

The actual successful reference and debugger commands are linked by hashes in
nudge-tail-verification.json, including process status, TailWindow and capture
provenance. Raw logs stay outside Git. The curator begins at final AFC2 and
uses tail-entry-ram.bin rather than silently treating the E247 state as its seed.
Normal curation still rejects unsuccessful processes; the old explicit
-ObservedPrefix workflow is restricted and does not apply to this tail.

## Live verification and preservation

Live executes all state changes incrementally from the original feature entry.
It consumes no recorded player events after initialization and assigns no
captured outcome. Ordered lamps match the prior transfer prefix plus this
zero-lamp tail; final alpha matches the captured tail. Final reel state and all
protected accounting bytes match terminal RAM. The headless test counts seven
flashes and preserves the16-unit total through the meter steps. Pause/Resume
freezes actual memory/time during rewind, meter transfer and a flash-loop wait.
Captured CPU/IRQ pacing remains provisional; full CPU-state equivalence is not
claimed by these software-boundary checks.

139 headless groups pass. Headless and isolated WPF builds succeed. Eight GUI
smoke modes cover the nudge tail, existing Skill Cash/jackpot, availability,
roll, links, repeated board selection and separate verified playback. The nudge
smoke retains all three controls, mid-motor/meter pause, input release and restart.
Nudge acceptance uses focused keyboard handlers; automated held-mouse acceptance
is not claimed. UI remains a renderer/input adapter with no award logic.

The existing data curator now retains the exact8714 header/8716 sound stream
through its terminating return. The encoding checkpoint links the new fixture
and keeps38 exact VM spans, including AF93/AF67/AF4E and their branch/inline alpha
bytes, with700 byte-checked native rows. Semantic maps link the final boundary,
RAM effects, implementation and tests. There is no full-ROM lossless/rebuild
claim, no assembler/editor/compiler work and no fresh Ghidra metadata export;
the prior access gap remains explicit.

## Reproduction and next work

Select Ladder animation: natural entry (DBC4), enable continuation, start,
TAKE FEATURE at square22, then press/release NUDGE1 at each of the three prompts.
Watch automatic improvement, transfer and the seven flashes. The stop at AFF0
shows pending0/current-win16 with the final display refreshed.

```powershell
./tools/Capture-SkillCash.ps1 -MameExecutable <mame281.exe> -RomDirectory <roms> -RunDirectory <fresh-window> -FullFeature -NativeSound -NativeInput -NativeLampFrames -NativeAlpha -CpuInterrupts -BoardLink Ladder -ContinueBoard -Availability -NudgeEntry -NudgePrompt -NudgeRequest -NudgeMotion -NudgeReturn -NudgeSequence -NudgeResult -NudgeExit -NudgeWinTransfer -NudgeTail -TailWindow -NoMotorItems
./tools/Curate-BoardLink.ps1 -RunDirectory <fresh-window> -LinkKind ladder -Continuation -Availability -NudgeEntry -NudgePrompt -NudgeRequest -NudgeMotion -NudgeReturn -NudgeSequence -NudgeResult -NudgeExit -NudgeWinTransfer -NudgeTail -TailWindow
dotnet build FruitMachineLab.Headless.sln --no-restore
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .
```

Next follow AFF0 through EDB4/EE11 and the actual outer caller. Verify whether
it reaches award dispatch or another gate before implementing bank commit,
collection or payout. Prefer narrow natural capture windows while investigating
the full-logging crash. Complete playable-machine recovery remains primary.
No agent installations, configuration changes, commits, pushes or cloud setup.

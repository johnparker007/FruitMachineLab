# Nudge prompt and physical request handling

15 October 2026. The Live ladder route now continues through TAKE NUDGEPOT to the
recovered **3 NUDGES** prompt. Three temporary NUDGE buttons feed actual sampled
MPU4 inputs. Selecting one executes the recovered scan, increments that reel's
requested offset, and stops before B31F main-reel motion. Count consumption,
motor stepping and award resolution remain deliberately outside this milestone.

To inspect it, select Ladder entry with continuation enabled, Start feature,
TAKE FEATURE, then NUDGE 1/2/3. Mouse-down/up and focused Space/Enter implement
momentary levels. Pause suspends execution/time and releases controls; Resume
continues the same state. Restart restores entry. Separate playback is unchanged.

## Native matching-result and alpha additions

Native 1AA3 calls the existing 1AC3 lookup, filters results below7, and if zero
retries common flag1, then DD-enabled flag2. It sign-extends the returned byte to
a VM cell. Flag2 retains its DE=FF side effect. A separate seven-case synthetic
MAME matrix verifies the complete low-RAM state below0700, including the pushed
result. Native CPU S-stack residue remains outside that comparison. The matrix
is explicitly synthetic and does not establish gameplay reachability.

The nudge display needs alpha69, native3DA7: read the following word as a byte
address, print a space only when that byte equals1, otherwise print S. The
3FB4 assembly confirms two operand bytes are consumed. The translated command
uses the existing character/cursor implementation. Natural plural output matches
MAME serial bytes; focused static tests cover counts0,1,2,255 and stream/cursor
advance. The static singular test is not a separate natural MAME campaign.

Dynamic input EXECUTE now accepts the explicit vm_test_input_condition kind
through the existing condition callback. It neither introduces a threaded call
frame nor bypasses input sampling. Only validated tokens83B1/83B4/83B7 are added
by the Adders resolver. Token7FB1 is the validated 794F literal0161 used by the
existing indexed flag2 script. Other unresolved dynamic words still fail.

## Natural references

Two fresh isolated physical-input campaigns start at naturally reached E247:

| Segment | Terminal | VM observations | Lamps/frame results | Sound commands | Alpha bytes |
| --- | --- | ---: | ---: | ---: | ---: |
| Preparation and prompt | B403 before first scan | 375 | 29 | 3 | 46 |
| Preparation, prompt and Nudge1 request | B31F before motion | 553 | 62 | 4 | 46 |

All27 canonical VM fields and complete lamp-frame, sound-command/timing and
alpha-byte hashes match. Both preserve the independent earlier229-observation
preparation prefix. The141 undefined-local observations retain their existing
write-derived masks; no additional exclusions were introduced. Full raw VM hashes
remain available. Prompt/request fixtures keep every dispatch as an anchor.

The existing physical campaign is followed until square22 displays TAKE NUDGE;
the observer sends a12-frame physical TAKE pulse. The request campaign additionally
sends a6-frame physical Nudge1 pulse when the actual three-nudge display appears.
These additions are explicit in capture code/provenance and generated actions.
There is no RAM/register/ROM redirection. Sidecars retain raw/RAM/observer/action
hashes and MAME provenance. Both runs completed with exit0. Full logs, ROMs and
temporary MAME configuration remain outside Git; original workspaces are preserved.

## Input map and sampling

The ROM's9E06 indexed table contains83B1,83B4,83B7. Each7721 gateway supplies an
input selector to the recovered67EC/67F0 condition handling:

| Reel | Selector | BLACK2 bit | MAME input name |
| --- | --- | --- | --- |
| 1 | 1A | 02 | Hold1/Nudge1 |
| 2 | 18 | 04 | Hold2/Nudge2 |
| 3 | 16 | 08 | Hold3/Nudge3 |

The condition records select only port3 and are active-high. They observe the
sampled level, not a direct UI selection. Existing mux-column3 acquisition and
19B8/1A87 accumulation remain in use. Release clears the physical level, then the
next scan clears the sampled level; sticky accumulation is retained as before.
No new edge detector or synthetic press substitution is added. Post-motion held
button repetition/debounce is not claimed verified because motion is bounded.

B403 scans the actual indexed table and loop index. Its accepted path clears
selection lamps/sound, increments0169+2*reel at B427 and calls B31F. Live stops
before that call executes, so BE remains3, other requested offsets are unchanged,
and pending/current-win remain zero. Natural request evidence covers Nudge1;
mapping for2/3 is static plus driver evidence and independently exercised Live.

## Live verification and limits

124 headless groups pass, including all previous references, the two new natural
segments, native result matrix, plural command, sampled press/release levels and
each of the three Live reel requests. Tests verify full-memory/time pause,
released inputs, only the selected offset increment, unchanged count/accounting
and the explicit B31F stop. Live timing still uses the provisional captured
CPU/IRQ adapter; exact CPU/scan-time equivalence is not claimed.

Headless and isolated WPF builds succeed. Eight WPF smoke modes pass. The new
--live-nudge-smoke-test drives all three focused keyboard handlers in real time,
checks failed/lost mouse capture clears input, pause/resume, rendered prompt and
accepted request, and clean restart. The older availability smoke uses mouse
START/TAKE and a nudge keyboard handler. Synthesized mouse-down handler calls do
not establish a held native mouse button, so actual mouse-held nudge acceptance
is not claimed automated here. The click implementation releases on mouse-up,
capture/focus loss, window deactivation, pause and stop; failed capture cannot
leave it pressed. The rendered3 NUDGES display and temporary panel were inspected.

## Reproduction

```powershell
./tools/Capture-SkillCash.ps1 -MameExecutable <mame281.exe> -RomDirectory <rom-directory> -RunDirectory <fresh-run> -FullFeature -NativeSound -NativeInput -NativeLampFrames -NativeAlpha -CpuInterrupts -BoardLink Ladder -ContinueBoard -Availability -NudgeEntry -NudgePrompt
./tools/Curate-BoardLink.ps1 -RunDirectory <fresh-run> -LinkKind ladder -Continuation -Availability -NudgeEntry -NudgePrompt
```

Add -NudgeRequest to both commands for the second segment. These modes use600s
of isolated machine time rather than the older2400s capture window, without
changing debugger setup callback count or the earlier physical fixture. Rebuild
static records with Curate-NudgeData.ps1 and the established hash-checked ROM.
Use Capture-AvailabilityMatrix.ps1 / Curate-AvailabilityMatrix.ps1 with
-MatchingResult for the isolated1AA3 cases and an existing availability seed RAM.

```powershell
dotnet build FruitMachineLab.Headless.sln --no-restore
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .
<diagnostics-output>/FruitMachineLab.Diagnostics.exe --live-nudge-smoke-test <fresh-output>
```

Next: capture B31F through a completed main-reel nudge, including61F6 preparation,
service/optic/cleanup state, B306 consumption, refreshed symbols and the returned
prompt/result. Extend the hardware model only from evidence; do not assume the
dice-only motor path applies unchanged to the three main reels. Nudges and payout
accounting must be verified before widening the live boundary. No installations,
configuration changes, commits, pushes or cloud setup were performed.

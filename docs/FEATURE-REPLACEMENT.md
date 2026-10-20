# Feature replacement experiment

20 October 2026: the first collected feature on the existing skill-cash replay
was **Snake Bite**. A fresh-boot patched ROM naturally entered a custom VM word,
changed MAME lamp output, then continued into the original feature. This is an
entry hook with a lamp effect, not a complete replacement game or animation.

## Accepted first slice

- Original ROM SHA1: `402D1518BB78FDC489B06C2AABC771E5CE151847`.
- Patched ROM SHA256: `DDAE716AC635DD8B9352C1F0AD46596A05F72DE7ABFCD17BF7EFADFCE8056916`.
- Allocate 14 bytes at `1010–101D`: `00F879630079638F9C4479B0D003`.
  This calls original lamp word `9C44` with byte arguments `00`, `8F`, then
  branches to original Snake Bite body `D003`.
- Redirect table cells `E211`, `E217`, `E21F` from expected `D001` to `1010`.
  These are three Snake Bite entries; the selected index was not isolated.
- Ordered integrity repair produces `FFD1–FFD5 = 2BA727FFBD`.
- The exact final diff contains 25 bytes: 14 cave bytes, six table bytes and
  five integrity bytes. Guards and all other original bytes are preserved;
  978 of the approved 992 cave bytes remain available.

At frame 32630, time `543.824470930`, baseline reaches dispatcher `PC=00FC`,
`Y=D003`; the patched ROM reaches `Y=1012`, both with `U=0672`, `S=079A`,
display `SNAKE BITE` and feature state `C9=5`. Both subsequently reach
`Y=E243` at `548.339287791`, `U=0672`, `S=079E`, `C9=0`.

Separate captures without breakpoints show `lamp120=1` at time `543.850` in
the patched run versus `0` in baseline; baseline first sets it at `544.983`.
All four corresponding frame-bank bytes change from `20` to `21` in the patched
run. This is one lamp output, not four distinct lamps. The original feature
later drives that output and both runs clear it at `545.350`.

## Evidence and limits

Private experiment: `artifacts/deepseek/feature-replacement-experiment-101/`.
Patch recipe/build record: `patched-build-02/patch-record.json`; implementation:
`builder/Build-FeaturePatch.ps1`. Entry/return captures: `runs/baseline-02`,
`patched-01`, `patched-02`. Unpaused comparison: `runs/baseline-05`, `patched-05`.
All five runs exited zero. The two unpaused runs have identical sampled-input
CSV SHA256 `C24DE6A98674F555E0669AC1CB69E0C14209220C0EA296F0DA37676471A0B627`.
The two patched entry/return captures also agree. The supervisor inspected the
observer/launcher source, events, actual ROM diff, exits and sampled-input hashes.

Runs use fresh isolated persistence, explicit replay child environment and no
save-state or PC/Y/RAM/register injection. MAME's debugger is attached to start
execution despite its expected external modified-ROM identity warning; the
unpaused comparison uses no breakpoints. Earlier harness failures remain private.
This establishes limited natural MAME behaviour, not physical hardware validation.

Next: extend this reachable feature hook into a short repeating board animation,
then switch between two patterns using cabinet input. Reuse original firmware
services and continue patch/run/debug within one experiment.

## Animation and input selection

Later experiments 102/103 demonstrate three alternating top/bottom-row cycles
at feature collection, followed by clearing the rows and continuing Snake Bite.
Transitions occur at approximately `543.850`, `544.050`, `544.283`, `544.483`,
`544.683`, `544.900`, with cleanup at `545.100` emulated seconds. This version
uses 768 bytes; ROM SHA256 is
`BD13FE4D2E1459D9744AC512EFB2599B2CA6FDB93ECEDBB4F0FD1E60FFDB1177`.

The runnable builder `tools/Build-SnakeBiteAnimation.ps1` produces a subsequent
version that samples Start once and selects one of two two-row animations:

```powershell
./tools/Build-SnakeBiteAnimation.ps1 -OriginalRom <original-a6ls.p1> -OutputDirectory <new-private-directory>
```

Default output SHA256:
`9717C6623DFD96C8500E255CFE2D305CC10C6477C628AA0EE4E3A5216B7C23C3`.
It uses 755 bytes (`1010–1302`), leaving 237 bytes. It retains the same three
table redirects, exact original identity, allocation guards and integrity repair.
The supervisor rebuilt the tracked source and matched the naturally tested ROM.

The input test is original VM word `83FC`; the experimental pressed replay adds
a `:BLACK2` mask `128` pulse at frames `32620–32634`. Pressed and unpressed runs
show distinct custom lamp patterns. The original-ROM pressed baseline does not
show those patterns and has the same sampled-input hash as the patched pressed
run: `433CC15F8FF24B58466A7060E209C8B305C1785A1ED96D4CB2ECADB3A131BACE`.
All four input-selection captures exit zero. The pressed entry/return capture
observes `Y=1012`, then original `D003` with `U=0672/S=079A`, then `E243` with
`U=0672/S=079E`. Raw observations and launch records remain private under
`artifacts/deepseek/feature-animation-continuation-103/`.

This is entry-time pattern selection, not live switching. Dwell uses bounded VM
countdown loops, not a certified IRQ tick or hardware timing service. Both versions
continue into the original feature rather than replacing its game outcome.
Next: a compact repeating animation that rechecks input while running and exits
cleanly after a bounded interval or an explicit exit action.

## Live pattern switching

Experiment 104 implements 18 iterations of a live input loop, about 7.75 emulated
seconds in the observed run. Holding Start selects the middle-row animation;
releasing it selects the outer-row animation at the next poll. Four press/release
pairs during the animation change the output in both directions. Observed response
is 7–24 frames, up to about 0.40 seconds. This is held-button selection, not an
edge-triggered toggle.

Build with `tools/Build-SnakeBiteLivePatterns.ps1`, using the same `-OriginalRom`
and `-OutputDirectory` parameters. Defaults are `-Iterations 18 -DelayCount 1000`.
The independently rebuilt ROM matches the tested SHA256
`FDEA7FF34E2D20E2DEC9FD6454A0384A1CEB374B9B3AB2820C77D275E49254FA`.
It uses 873 bytes (`1010–1378`), leaving 119. The full diff is 884 bytes,
including the same six redirect bytes and five integrity bytes; guards remain
unchanged. The counted loop retains its counter until exit, then drops it,
clears the custom rows and branches to `D003`.

The pulse and original-ROM pulse runs have identical sampled-input SHA256
`0AC62B6108AF3CB6A439FBDE42EC77D61785557E17981D56E4906B55E06403CD`.
Only the patched ROM displays the custom middle/outer pattern choices. The
same patched ROM without pulses displays only the unpressed pattern. All four
comparison/context captures exit zero. Read-only entry/return capture observes
`1012` at `543.824470930`, `D003` at `551.574493604`, both `U=0672/S=079A`,
then `E243` at `556.307687790`, `U=0672/S=079E`. No game-state injection or
save-state seeding is used. Private captures and diagnostic variants remain in
`artifacts/deepseek/feature-live-pattern-experiment-104/`.

The supervisor inspected the loop/input branch, entry/return events, transitions,
actual run exits and sampled-input hashes, and rebuilt the published source.
One descriptive loop-metadata sentence was corrected without changing ROM bytes.
Countdown dwell is still an experimental VM execution delay. This is a bounded
interactive lamp demo followed by the original feature, not yet a new game.
Next: a small button-controlled paddle on the lamp grid, then ball movement and
collision behaviour as space permits.

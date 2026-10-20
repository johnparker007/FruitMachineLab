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

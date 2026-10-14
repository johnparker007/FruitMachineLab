# Skill Cash visual playback slice

The diagnostics app now plays the verified C721 path, with moving lamp output and
the alpha software display. Click **Load & play Skill Cash**. Loading runs the
existing behavioural verification first, then starts playback at 1×. This path lasts
12.209 seconds. Play, Pause, Restart, seeking, and 0.25×/0.5×/1×/2×/4× speeds are
available. Play at the end starts another run. No ROM or MAME installation is needed
to view the curated path.

## Output and timing

`SkillCashPlayback.Load` executes the recovered headless scripts and translated
helpers through the shared-memory verifier. It also checks the independent sound,
lamp frame, output scan and timer evidence before exposing a timeline. The shared
verifier now returns its feature result, avoiding a second independent feature run
in the UI. No expected lamp values are fed to the renderer as generated output.

The renderer receives `OutputPlayback`: 12,207 calculated lamp latch states (one
initial state plus 6,103 scans and 6,103 callback returns) and 45 alpha states (one
initial state plus 44 completed operations). The initial states retain the existing
captured replay prerequisites. Captured CPU-cycle offsets are converted at the
MPU4 reference rate of 1,720,000 cycles per second. A monotonic Stopwatch supplies
elapsed time; late UI frames catch up to the current position rather than slowing
the feature. Pause and speed changes preserve position; seeking samples the same
immutable outputs without rerunning or changing game logic.

Lamp duty is integrated over a trailing 20 ms window. The WPF palette applies an
eightfold scan gain and clamps it for visibility. These are presentation choices,
not claims about filament brightness or electrical PIA transitions. Scan and
callback effects are timed at their verified native return boundaries; individual
bus writes inside those helpers are not independently timestamped here. Alpha
software changes are aligned to the next VM dispatch after their operation;
serial/VFD bit timing remains unresolved. Accounting text accompanies those alpha
observations, rather than claiming per-instruction accounting telemetry.

## Mapping and presentation

All 128 tiles use `maps/deep-pass-lamp-map.json`, preserving MAME lamp numbers and
logical ROM command IDs. The highlighted strip contains commands 6F,67,5F,57,4F,47
(the six entries in recovered table 7257), plus SKILL CASH and START. Monetary
captions are taken from the recovered MAME mapping; they are not inferred from the
75BD award table or used to calculate payouts. Unknown/blank captions display `?`.
The tile arrangement is a diagnostic layout, not a recovered cabinet layout.

This is a visible execution of one verified recorded path. Physical input, CPU
acceptance timing and scheduler observations remain recorded; freely interactive
play and synthesized audio are still future work. The lamp/alpha output model and
transport live in headless projects, so a later renderer can consume them without
depending on WPF controls.

## Validation

Both solutions build with the existing installed SDK, without warnings/errors.
61 dependency-free verification groups pass. New checks cover the actual generated
timeline and final win, lamp multiplexing/masking integration, seek independence,
pause/speed/end/restart, malformed outputs and unsupported transport values.

An opt-in WPF smoke mode exercises the real load, buttons, slider, speed control,
DispatcherTimer, complete real-time playback and completed-run restart. It renders
the window at 1100×850 and 800×650; both were visually inspected. Small-window
scrolling was corrected during that check. To reproduce with a fresh local folder:

```powershell
dotnet build FruitMachineLab.sln --no-restore
src/FruitMachineLab.Diagnostics/bin/Debug/net8.0-windows/FruitMachineLab.Diagnostics.exe --playback-smoke-test <new-output-folder>
```

Smoke mode exits with code 0 on success and writes result.txt plus two PNG renders;
errors are written to result.txt and exit with code 1. Normal launches are unchanged.
No dependencies, system configuration, original evidence files, ROMs or MAME
settings were changed. No commit or push was performed by this pass.

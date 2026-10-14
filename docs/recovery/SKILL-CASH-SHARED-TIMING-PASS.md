# Skill Cash shared memory and captured timing pass

VM lamp requests, individual frame writes, IRQ scans and timer-3 callbacks now
run against one machine memory image. The shared replay matches **98,704 VM
dispatches, 29,192 lamp writes, 6,103 scans, 6,103 timer arms and 6,103 callbacks**.
This removes the earlier IRQ adapter's between-scan frame-buffer injection.

The timeline remains driven by captured CPU-cycle timestamps. It is not a CPU
instruction timing model or an independent elapsed PTM implementation. The
existing per-dispatch IRQ/latch/sound timing adapter still supplies game timing.

## Capture and timeline

The installed MAME 0.281 debugger exposes the read-only `totalcycles` symbol;
this was checked with its own `symlist` command. A fresh physical-input replay
captures timestamps at VM dispatches, native lamp calls/frame stores, scan
entry/return, timer arm, callback entry/return. The source order is retained for
events with equal timestamps. No reference RAM or ROM was injected into MAME.

A second canonical digest compares all 24 captured VM state fields in this new
run with the calculated shared-memory execution. The earlier 25-field proof,
which also includes the sound scheduler clock, remains independently checked.
The new capture does not use the old VM result as a substitute for observing its
own dispatch states.

`shared-timing.json` stores one initial cycle, delta-encoded VM timestamps and
74,303 selected device events. Source debugger/executable hashes and isolated-run
arguments are recorded in `shared-timing-verification.json`. All four campaign
artifacts—state.csv, feature-state.csv, input-levels.csv and ram-final.bin—remain
byte-identical to the original path. Curation reproduces byte-for-byte.

`CapturedCycleTimeline` advances a monotonically increasing 64-bit clock, keeps
same-cycle events in source order and rejects malformed events or backward time.
It dispatches recorded events only; it does not create interrupts or expiry times.

## Predicted effects on shared memory

The continuous game runtime produces logical lamp requests. The platform adapter
queues those requests and checks their native ID/pattern associations. It then
calculates each of the four frame-byte writes at its captured operation boundary,
using the recovered characteriser response mapping. Recorded byte values are
oracles for comparison, not values assigned to the model. Per-frame stepping
preserves intermediate states when an IRQ occurs during a lamp helper.

IRQ scans read this calculated frame memory. Counters, mux columns, pulse-width
helper state and output latches continue from an initial state instead of being
reseeded between calls. The digit shadow, masks, input-sample counters and blink
state are seeded from the initial captured platform context. The game and alpha
runtime share that memory; the original VM state digest still matches.

Each calculated pulse-width helper emits a timer-arm request. The native arm
event checks its timer and callback. When the recorded callback event arrives,
the recovered FE70/70B3 software dispatch disables timer 3 and invokes 48FD. That
callback masks the currently scanned lamp latches using 0140/0148 and blanks the
digit latch when the current 00AB column inhibit byte is nonzero. It does not
modify the four animation frame buffers. Callback entry and return are paired
and checked against recorded columns and ports.

The native callback address gate (below 1400 skips invocation) is retained. Unknown
registered helpers fail explicitly. The selected path uses callback 48FD and the
previously recovered fixed timer word 40 decimal. No timer frequency, electrical
latency or visible brightness was inferred from this value.

## Diagnostics and tests

The GUI runs shared-memory verification alongside the existing independent
component checks. Its IRQ tab now shows calculated scan and timer-callback
outputs at captured CPU-cycle offsets, so the masking after a scan is visible.
The alpha timeline remains based on the verified software shadow. Presentation
code consumes immutable headless snapshots and contains no game logic.

Fifty-three verification groups pass. Synthetic tests cover callback mask/blank
effects, source-order ties, backward/malformed timing rejection and the timer
dispatch address gate. Changing a recorded callback output is rejected. The
expanded WPF views have build verification; no new interactive GUI test is claimed.

```powershell
./tools/Capture-SkillCash.ps1 -MameExecutable <existing-mame> -RomDirectory <roms> -RunDirectory <new-run> -FullFeature -SharedTiming
./tools/Curate-SkillCashSharedTiming.ps1 -RunDirectory <new-run>
```

Earlier exploratory captures are preserved outside tracked files. Only the
completed capture with individual frame writes supplies this proof. The original
forensic workspace, installed tools and configuration remain unchanged.

## Remaining work

This is a shared captured-time replay, not interactive standalone gameplay.
Elapsed timer deadlines, general CPU scheduling, PIA/VFD electrical transitions,
audio synthesis and wider game paths remain open. The next timing work should
recover hardware clock/divider and interrupt-service semantics before replacing
timestamps with calculated deadlines. Recovered assembly and measured behaviour
must continue to take precedence over helper names or plausible timing guesses.

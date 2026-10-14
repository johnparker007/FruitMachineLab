# Live Skill Cash vertical slice

The new **Live Skill Cash** tab starts one recovered feature from its existing
entry state. Click **Start feature**, then hold and release the separate physical
**START** button to stop each selection. Execution controls are **Pause execution**,
**Resume execution** and **Restart feature**. Space/Enter also operate the physical
button while it has keyboard focus. The verified playback/scrubber remains separate.

## Incremental execution

`ScriptExecutor.Begin/Step` retains nested interpreter continuations, while the
physical VM stack/local/loop semantics remain in `Machine`/`VmControlStack`.
A step executes one pending dispatch. Synchronous Run uses the same stepping
implementation; all prior MAME-backed digests still pass. `SkillCashLiveSession`
loads prerequisite state and timing data without executing the feature in advance.
Its machine, stack, scheduler, frame buffers and alpha state persist between host
updates. Outputs are calculated as instructions and IRQ services execute.

The host supplies elapsed wall time to a virtual 1.72 MHz MPU4 clock. Pause stops
both virtual time and interpreter steps, including native scheduler waits. Resume
continues the same session; Restart creates a new entry-state machine. Late rendering
advances elapsed virtual time rather than replaying cached output. Switching tabs
pauses the hidden execution mode. Lamps use 20 ms presentation persistence;
all runtime/input logic remains outside WPF.

## Physical Start input

The recovered mux mapping and physical MAME input captures establish BLACK2 bit
80 as active high. `Mpu4PanelInput` owns the physical level. Setting it does not
change the feature choice, stack, latch or sampled RAM immediately.

27D2 reads the selected mux column into RAM 0000..0007. BLACK2 is column 3, RAM
0003. The callback chain 438C -> [00C6=19B8] -> 1A87 ORs that sample into 008E+column
and ANDs it into 0096+column. Thus Start accumulates at byte 0091, bit 80 in word
0090. C699 clears the latch using 847A and tests it using 8468/767F. After accepting
a selection, C721 calls 9986, which tests selector 1E through the existing
`Mpu4InputConditions.Evaluate`, and waits for the sampled level to clear.

This is sticky sampled-level accumulation, not an invented edge debounce. A press
shorter than the mux sampling window may be missed. Holding Start keeps the release
loop running; release clears raw/sample level on acquisition but does not itself
clear the sticky latch. BLACK2 is sampled approximately every 16 ms at this IRQ rate.

Mouse-down captures the mouse and presses; mouse-up releases after dragging outside.
Capture loss, keyboard-focus loss, window deactivation, pause, restart, completion
and faults release the physical level. Paused sampled RAM can still show its last
acquired value: it updates at the next scan after Resume, rather than changing ROM
memory while execution is suspended.

Only Start is required for the tested selections. Other panel controls remain idle.
DIL/options, door/service mode, compensation data and lamp-sense values are fixed
feature-entry prerequisites. No coin/startup/reel simulation is attempted. The
reference campaign has unrelated Hold probes; those are not injected into Live mode.
Neither captured Start levels nor captured latch events drive this session.

## Explicit unresolved timing adapters

This is incremental game execution, not complete 6809/PTM/PIA emulation.

- CPU dispatch pacing uses the **minimum observed** dispatch-to-dispatch duration
  per site, falling back to an observed token duration. This is a provisional
  policy at the unresolved translated-CPU boundary, not recovered cycle counts.
  Unknown sites/tokens stop explicitly. `tools/Curate-SkillCashLiveTiming.ps1`
  reproduces extraction from the hash-verified shared capture.
- IRQ scan and callback service boundaries use the captured return-time template.
  It repeats at 6,103 times the source-backed timer-1 period of 3,441 CPU cycles
  (latch 0D70 plus one). Repeating latency is a bounded adapter, not independently
  verified CPU acceptance timing for different player paths. Scan/frame/callback
  **values** are generated from current machine state each time.
- Input/counter/scheduler ordering follows FE70/27D2/19B8/1A87/5CD0, but phases are
  atomic at the IRQ boundary. Native scheduler waits suspend dispatch until
  generated tasks finish; busy-loop/return CPU overhead is not modeled.
- Lamp and alpha helpers are atomic VM operations. Four lamp frame stores and
  alpha serial bytes are not independently scheduled within them. Electrical
  display timing and audio synthesis remain unresolved.

The tested path and alternate 2,2,2 award work. Higher/untested branches, including
the six-pound jackpot announcement A365, contain helpers/timing outside the translated
subset and may stop with an explicit diagnostic fault. No missing helper or award
is replaced with guessed behaviour.

## Reference comparison and tests

67 dependency-free groups pass. New checks cover polarity, mux sampling, sticky
latch behaviour, release conditions, held-button stage blocking, actual memory/stack/
clock suspension, Resume, a different player-selected award and live comparisons.
The original 98,704-dispatch digest and all lamp/alpha/sound/IRQ checks are preserved.

Supplying reference Start press times externally from actions.csv produces:

| Check | Live result | Reference |
|---|---|---|
| Accepted selections | 3,2,1 | 3,2,1 |
| Final pending/current win | 0 / 10 ROM units | 0 / 10 |
| VM stack/frame/accounting checkpoints | 18 matching checkpoints | C757/C761/C710/AFC2/C767 |
| Alpha software states | All 44 match | Recorded native calls |
| Final lamp frame memory | All 64 bytes match | MAME-verified frame replay |
| Dispatch count | 397,009 | 98,704 |
| Virtual completion time | 12.093 s | 12.209 s |

Checkpoints compare token, top cells, reconstructed U, S/F4/F6, local-frame value,
rate, pending/current win, checksum, mode, display and suppression. They exclude
timer/IRQ counts, random seed, selector, latch, guard and scheduler-clock fields
that depend on unresolved intra-instruction phases. This is **not full CPU-state,
random-stream or scan-timeline equivalence**. Transient lamp timing/counts differ;
the final frame comparison does not hide those differences. Original independent
checks still verify the recorded scan path.

A synthetic run selecting 3,2,1 earlier finishes in 4.682 virtual seconds, with
matching alpha text and final accounting. Another timing selects 2,2,2 and reaches
current win 16. Neither is labelled an observed MAME campaign.

The WPF smoke check exercises actual DispatcherTimer execution, mouse handlers,
capture/focus-loss release, Pause/Resume, completion, Restart and rendered output.
The existing playback smoke also passes after adding the Live tab. To reproduce,
with diagnostics closed so its DLLs can be rebuilt:

```powershell
dotnet build FruitMachineLab.Headless.sln --no-restore
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .
dotnet build FruitMachineLab.sln --no-restore
src/FruitMachineLab.Diagnostics/bin/Debug/net8.0-windows/FruitMachineLab.Diagnostics.exe --live-smoke-test <fresh-output-folder>
```

An existing diagnostic process held normal build output during development. WPF
was built/tested in a fresh temporary output folder, without stopping John's app.
No installations, configuration, original workspace files, ROMs, MAME settings,
commits, pushes or cloud access were changed.

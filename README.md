# FruitMachineLab

Experimental recovery of Barcrest MPU4 Adders & Ladders, m4addr A6L 0.1 set 1.
Recovered code and names are reconstructions, not original source.

The [strategic roadmap](docs/PROJECT-ROADMAP.md) now separates autonomous PC play,
editable VM game logic and ROM generation. See the [source audit](docs/ENGINEERING-AUDIT.md)
for actual capture dependencies and [ROM editing](docs/ROM-EDITING.md) for the
validated, create-only patcher and first original-VM MAME lookup experiment.

The C# solution separates the headless VM/runtime, game-specific Skill Cash replay,
and WPF diagnostic viewer. It now verifies **continuous C721 feature execution**
against recorded MAME timing and inputs. Standalone interactive gameplay and full
peripheral emulation remain incomplete. See [implementation status](IMPLEMENTATION-STATUS.md).

Using installed .NET SDK 9.0.313 and net8.0 targeting packs:

```powershell
dotnet build FruitMachineLab.Headless.sln --ignore-failed-sources
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .
dotnet build FruitMachineLab.sln --ignore-failed-sources
dotnet run --project src/FruitMachineLab.Diagnostics --no-build
```

The dependency-free verification executable returns a nonzero exit code on failure.
It deliberately needs no NuGet test framework installation. Run from repository root,
or pass the absolute repository path to verification. The Windows viewer accepts that
path separately. No SDK pin or machine configuration is changed.

The diagnostics app opens on **Live Skill Cash**. Click **Start feature**, then
press and release **TAKE FEATURE** at the board prompt. Use the physical **START**
button to stop each Skill Cash selection. Pause/Resume
suspend the actual VM and virtual clock; Restart restores the feature-entry state.
Outputs are generated during execution. Captured CPU/IRQ timing adapters remain
explicitly unresolved. See [live scope and comparison](docs/recovery/SKILL-CASH-LIVE-PASS.md).

The separate **Skill Cash playback** tab remains available. Click **Load verified
playback / scrubber** to watch the recorded path with labelled lamps and alpha output.
The recorded path lasts 12.209 seconds at 1×; pause, restart, seek and speed controls
are available. This mode uses recorded inputs; use Live Skill Cash for the temporary
player control. Audio remains future work. See
[playback evidence and boundaries](docs/recovery/SKILL-CASH-PLAYBACK-PASS.md).

Latest local verification: headless and isolated WPF builds succeed; 307
verification groups pass. Continuous C721 execution matches 98,704 VM dispatches,
selects 3, 2 and 1, and finishes with pending 0/current win 10. All 7,298 lamp frame
updates and the complete sound timing protocol match recorded native observations.
Alpha software effects match 44 native calls/740 serial bytes; an independent
IRQ adapter matches 6,103 scan and pulse-width calls. The viewer includes alpha
and scan timelines. Electrical timing remains outside these models.
The shared captured-cycle replay now connects 29,192 predicted lamp writes to
6,103 IRQ scans and timer callbacks on one memory image.
The playback controls and full real-time run have an automated WPF smoke check;
rendered layouts were inspected at normal and minimum window sizes.

A focused MAME capture matches the original campaign's sampled state, feature state,
input levels and final RAM byte-for-byte. See the
[runtime recovery report](docs/recovery/SKILL-CASH-RUNTIME-PASS.md) for path coverage,
static deductions, explicit observed boundaries and reproducible capture commands.
The subsequent [compensation/control recovery report](docs/recovery/SKILL-CASH-COMPENSATION-PASS.md)
records removal of the observed chance-helper boundary and the current remaining work.
The [selection/scheduler report](docs/recovery/SKILL-CASH-SELECTION-SCHEDULER-PASS.md)
records complete selection-loop coverage and the captured timing boundaries.
The [award/NVRAM report](docs/recovery/SKILL-CASH-AWARD-NVRAM-PASS.md) records
13 native refreshes and ten calculated transfers to current win 10.
The [continuous feature report](docs/recovery/SKILL-CASH-CONTINUOUS-FEATURE-PASS.md)
records the connected execution, recovered input conditions, concurrent sound
streams, lamp frame memory and remaining peripheral boundaries.
The [alpha/output report](docs/recovery/SKILL-CASH-ALPHA-OUTPUT-PASS.md) records
display-software recovery, IRQ latch verification and the remaining timer/device work.
The [shared timing report](docs/recovery/SKILL-CASH-SHARED-TIMING-PASS.md) records
removal of between-scan frame injection and the remaining deadline-generation boundary.

The [award coverage and IRQ occupancy pass](docs/recovery/SKILL-CASH-EXTENSION-PASS.md)
adds live jackpot announcement support and tests all six default award levels.
Normal machine play remains the next milestone; captured timing remains provisional.

Live now starts at the square-32 board prompt: press and release **TAKE FEATURE**,
then use **START** for Skill Cash's three selections. The entry selector retains
direct C721 and taken-result E2FC modes. START at the board prompt now runs one
incremental dice roll with ROLLING and a changing text face/position. Pause/Resume
also suspend the motor. It advances through the board one square at a time, then
stops at the next result/selection boundary; Restart restores entry. Board square,
pot and history are shown.
See the [board selection report](docs/recovery/BOARD-SELECTION-TAKE-PASS.md) for
reference comparisons, restored call frames and uninitialized-local exclusions.
The [dice request report](docs/recovery/DICE-REQUEST-PASS.md) records native
profile/symbol recovery. The [dice motion report](docs/recovery/DICE-MOTION-PASS.md)
records the verified motor service/optic model and the remaining board boundary,
including the explicit one-byte alpha brightness timing difference. The
[board movement report](docs/recovery/BOARD-MOVEMENT-PASS.md) records the next
incremental advance, natural reference and separately labelled nudge-animation probe.

The [ladder/snake pass](docs/recovery/BOARD-LINK-PASS.md) adds two natural Live
entry choices, recovered animations and complete MAME reference checks. Choose
Ladder or Snake in the entry selector, then Start feature. Both support actual
Pause/Resume and Restart, stopping before the following board result.

The new [board continuation option](docs/recovery/BOARD-CONTINUATION-PASS.md),
enabled by default, allows recovered selection prompts to repeat without resetting
machine state. A 32→36 roll returns to a usable prompt and accepts another START.
Unsupported result types stop explicitly. Disable
continuation to retain the earlier bounded animation modes.

The [nudge-availability pass](docs/recovery/NUDGE-AVAILABILITY-PASS.md) removes the
ladder's native search stop. With continuation enabled, select Ladder entry and
Start feature to reach TAKE NUDGEPOT. START rolls again; TAKE now executes
[type-1 preparation](docs/recovery/NUDGE-PREPARATION-PASS.md), preparing three nudges
and displaying the [nudge prompt](docs/recovery/NUDGE-INPUT-PASS.md). Temporary
NUDGE1/2/3 controls use the recovered input ports, move the selected reel and
[return to the next prompt](docs/recovery/NUDGE-RETURN-PASS.md). Three NUDGE1
presses consume the pot from 3 to 0 with changing positions/symbols. The former
native-stack dependency is preserved through its actual lamp save-area effect.
The [automatic improvement](docs/recovery/NUDGE-IMPROVEMENT-PASS.md) now runs after
that sequence, including rewind, announcements and computed automatic nudges.
It then [exits the board and animates the meter](docs/recovery/NUDGE-WIN-TRANSFER-PASS.md)
from pending16/current-win0 to pending0/current-win16. The subsequent
[display refresh and seven flashes](docs/recovery/NUDGE-ANIMATION-TAIL-PASS.md)
also execute. Live stops at AFF0 before outer award, bank commit or collection.

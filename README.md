# FruitMachineLab

Experimental recovery of Barcrest MPU4 Adders & Ladders, m4addr A6L 0.1 set 1.
Recovered code and names are reconstructions, not original source.

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

Latest local verification: both solutions build without warnings or errors; 47
verification groups pass. Continuous C721 execution matches 98,704 VM dispatches,
selects 3, 2 and 1, and finishes with pending 0/current win 10. All 7,298 lamp frame
updates and the complete sound timing protocol match recorded native observations.
Alpha software effects match 44 native calls/740 serial bytes; an independent
IRQ adapter matches 6,103 scan and pulse-width calls. The viewer includes alpha
and scan timelines. Electrical timing remains outside these models.
The initial WPF viewer was tested by John; its expanded output has build verification.

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

# FruitMachineLab

Experimental recovery of Barcrest MPU4 Adders & Ladders, m4addr A6L 0.1 set 1.
Recovered code and names are reconstructions, not original source.

The initial C# solution separates the headless VM subset, game-specific Skill Cash
replay, and WPF diagnostic viewer. It currently verifies **bounded feature mechanics**,
not complete standalone Skill Cash gameplay. See [implementation status](IMPLEMENTATION-STATUS.md).

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

Latest local verification: both solutions build without warnings or errors; 32
verification groups pass. Complete C699 selection calls match 65,298 recorded VM
dispatches and produce choices 3, 2 and 1. A native sound timing/choice subset
predicts all 1,202 choice reads; decoded lamp requests remain separate from hardware frames.
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

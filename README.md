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

Latest local verification: both solutions build without warnings or errors; eight
verification groups pass, including rejection of a corrupted timing observation and
26,660 recorded dispatch comparisons. WPF has build verification only; its interactive
appearance and controls have not yet been tested.

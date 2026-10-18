# Bounded IL build and paused-debug workflow

`tools/Build-IlDebugSession.ps1` is the reusable M3 usability entry point for the
single supported `9ED9` same-size edit. It composes the existing independent
`FruitMachineLab.IlBuild` CLI, the existing ordered firmware-integrity repair and
the accepted isolated MAME paused-debug launcher. It does not decode, compile,
checksum, relocate or edit anything itself.

## Inputs and create-only contract

The caller supplies:

- the exact original `a6ls.p1` (65536 bytes, SHA1
  `402d1518bb78fdc489b06c2aabc771e5ce151847`, SHA256
  `ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c`);
- the installed MAME executable (checked SHA256
  `0fce5a88df4f9d9b1fbf1405812c00848036e615993780978d967da34204cb7a`);
- the installed support ROM directory;
- a fresh output root that does not already exist.

The only accepted edit specification is `9ED9:FF80->FF00` (the first `795B`
inline-word literal at `9EDB`). Other requests are rejected before any build or
MAME launch. The original ROM is only read. The workflow creates the output root,
build artifacts, logs, session directory, summary and report with create-only
semantics; it does not overwrite or clean up existing user files.

## Usage

Build the existing solution first, because the workflow invokes the independent
builder with `dotnet run --no-build`:

```powershell
dotnet build FruitMachineLab.Headless.sln --ignore-failed-sources
powershell -NoProfile -File tools/Build-IlDebugSession.ps1 `
  -OriginalRom <a6ls.p1> `
  -MameExecutable E:\Arcade\MAME0266\mame281.exe `
  -RomDirectory E:\Arcade\MAME0266\roms `
  -OutputRoot <fresh-output-root> `
  -SecondsToRun 120 -WallTimeoutSeconds 600
```

The default `-EditSpec` is `9ED9:FF80->FF00`. The default IlBuild project is
`tools/FruitMachineLab.IlBuild`. The launcher plan, replay and Lua input are the
existing repository evidence files; they are not generated or copied into
historical build directories.

## Outputs

Under the fresh output root:

- `build/edited-unrepaired.p1`, `build/edited-repaired.p1`;
- `build/build-report.json`, `build/integrity-report.json`,
  `build/source-map.json`;
- `logs/` with the actual builder, launcher and command stdout/stderr;
- `session/` containing the isolated run, session map, strict protocol files and
  `events.jsonl`;
- `workflow-report.json` (machine-readable phases, actual exits, input/artifact
  hashes, diff, integrity, session and observation); and
- `build-summary.txt` (human-readable summary).

For the supported edit the repaired image must be exactly SHA1
`e1a42dccd304b7b175aabac99e8400cdad04cf69` / SHA256
`577f76bd36dfca04dfb01b5f5d0be93e16572f8617c7ca906397c98df36e5107`, the
unrepaired image exactly SHA256
`a99d96f8ea8b4770d2d3828125f25894e831726fe44a79a37e0871faba135ed2`, and the
original/repaired diff exactly `9EDC,FFD1,FFD2,FFD3,FFD4,FFD5`. The repair-only
diff is exactly `FFD1..FFD5`. The fresh source map must bind the repaired image,
cover the contiguous `9ED9..9EE6` span with fourteen entries, and agree with the
fresh build report. The workflow fails before launching MAME if any identity,
byte span, diff, integrity field, map entry or report binding differs.

## Phase distinctions

The report and summary distinguish:

- `built`: the build artifacts were freshly written and validated;
- `launched`: the isolated repaired image reached the launcher's stopped ready
  state;
- `paused`: `pause-at-mapped-node` reached the first mapped node at a native
  prefetch boundary;
- `observed`: a read-only `inspect` resolved the paused PC/Y/U/S, token and the
  compiled operand;
- `stopped`: the strict `stop` command scheduled exit and MAME exited zero.

`fresh_boot_observed` is only true when the pause and inspect proofs both passed.
Every phase has its own actual exit code. A launched process is not evidence of a
completed natural run. This workflow observes the first mapped node only; it does
not claim a full call, a result, the later paid window, gameplay or hardware
compatibility.

For the accepted image the observed first node is expected to report
`nodeIndex=0`, `pc=00FC`, `y=9ED9`, `u=066E`, `s=0796`, token `795B` and mapped
IL operand `FF00`.

## Launcher validation change

The `9ED9` path of `tools/Start-IlDebugSession.ps1` previously pinned the
historical `artifacts/deepseek/il-boot-04/build-01` source-map and build-report
file hashes. A fresh build report necessarily differs because it contains its own
absolute output paths, so that pin blocked the reusable workflow. The launcher now
requires canonical create-only JSON and validates the fresh map/build schema,
image identities, contiguous body, token/node/operation sequence, expected bytes,
diff, integrity fields, paths and consistency checks. It still rejects stale,
tampered, canonical-but-wrong-binding and existing-run inputs before MAME. The
`9A64` path and its pinned capture artifacts are unchanged.

## Verification

```powershell
powershell -NoProfile -File tests/worker/Test-IlBuildDebugWorkflow.ps1 -Force
```

The focused verifier runs one fresh workflow with one isolated boot, checks the
repaired identity and exact diff, checks that the fresh map/build/image agree,
performs the accepted `pause -> inspect -> stop` observation, strictly parses the
workflow report and session JSONL, and runs prelaunch controls for a wrong ROM,
an existing output root, an unsupported edit, a failed builder, stale map/build
files and canonical-but-wrong map/build bindings. It also verifies original-image
preservation, the existing-root sentinel, the empty save-state directory and the
curated manifest. It regenerates
`evidence/mpu4/integrity/il-build-debug-workflow.json` and verifies
`evidence/curated-manifest.json` through the existing generator.

No installation, configuration, register/RAM/ROM write, save-state load, state
injection, allocation, new word or hardware claim is part of this workflow.

# ROM editing — compiler direction and existing patch tools

## Active direction — 18 October 2026

The [replacement roadmap](PROJECT-ROADMAP.md) makes original-VM IL and ROM
compilation the primary workstream. MAME is the execution backend and Lua live
debugger; physical MPU4 hardware is the final compatibility target. Native C#
execution is frozen indefinitely and is not a compiler prerequisite.

The planned builder preserves the original image, emits checked same-size
definition edits, then allocates additions into a revision-specific confirmed
end-of-ROM extension range. Support new composite words and native 6809 primitives
through the original dispatch/stack ABI, with supported entry/reference redirects
and safe trampolines before general relocation. Record allocations/fixups and
reject unsupported hooks, overlaps and overflow. A user-confirmed range with
mapping, expected-byte, known-use and integrity checks is sufficient for the
initial allocator; complete ROM disassembly is not required. Padding scans only
identify candidates. No extension range or new-word support is certified yet.

For unchanged supported definitions require byte-identical re-encoding; preserve
opaque regions exactly without claiming they are decoded/editable. Retain original
tokens/addresses unless explicitly patched. Bind source maps to exact built-ROM
hashes. Regenerate original firmware integrity fields in the recovered order,
without bypasses, and keep loader hash warnings separately visible.

Reuse Mpu4VmDefinition and the checked 9A64/9ED9 plans, RomPatch, the narrow
VmDefinitionImage CLI and existing MAME scripts. The next proof is an actual
ROM-byte decoder -> unchanged identity build -> meaningful operand edit ->
integrity-correct fresh boot -> natural changed-definition execution -> Lua
PC/Y/U/S/register/stack observation resolved to IL. Existing synthetic 9ED9
invocation does not complete this proof. General decoding, repair for arbitrary
edits, linking, source maps and a live debugger remain missing components.

The debugger will provide inspection/VM stepping plus controlled logged paused
RAM/register edits where installed MAME APIs permit. Experiments and save-state
setups are distinct from natural execution acceptance.

## Existing fixed-size patcher and historical measurements

This is a small hybrid ROM builder: preserve the original image and change only
explicit equal-length ranges. It is not a compiler, relocation tool or firmware
integrity repairer. `RomPatch.Apply` is independent of game traces and snapshots.
The CLI writes with `FileMode.CreateNew`, rejects the input/specification as output,
rejects existing outputs, reads the result back and prints input/output SHA256 and
exact changed offsets. Validation occurs before any output is created.

## Independent IL same-size operand edit

`FruitMachineLab.Il` now decodes the fixed 9ED9 definition, compiles it
byte-identically, and supports exactly one checked same-size edit: the first
`795B` inline-word literal operand at `9EDB..9EDC` may change from the strict
original `FF80` to a declared 16-bit replacement. The production compiler
rejects wrong ROM identity, caller-supplied IL hashes, wrong expected values,
wrong addresses/widths, unsupported tokens, unrelated byte changes,
multiple/overlapping edits and invalid spans. Emitted operand bytes are derived
from the edited IL value; original bytes remain separately recorded.

Generate a fresh, create-only edited image, build report and source map:

```powershell
dotnet run --project tools/FruitMachineLab.IlBuild --no-build -- `
  <original-a6ls.p1> artifacts/deepseek/il-edit-02/cli-positive
```

The fixed proof edit is `9EDB FF80 -> FF00`, producing
`795BFF00787E795BFF807AAF792F`; the full-image diff is exactly offset `9EDC`
(`80 -> 00`). The report records original/output lengths, SHA1/SHA256, expected
and actual bytes, edit/span, the single diff and an explicit `UNREPAIRED`
integrity status. The source map covers all 14 bytes at unchanged addresses and
is bound to the output image SHA256; original and edited maps reject each
other's image identity. The CLI rejects wrong input, input/output aliases,
existing targets and collisions before writing, never modifies the original
ROM, and leaves no partial accepted files on rejection.

Only this fixed definition and first operand are supported. No firmware
integrity field is repaired, no image is accepted or boot-validated, and no MAME
or hardware execution claim is made. The active `FFD1..FFD5` integrity fields,
ordered repair and natural 9ED9 reach remain the next gates.

## Build and test

From the repository root, with the already installed .NET SDK and net8.0 packs:

```powershell
dotnet build FruitMachineLab.Headless.sln --ignore-failed-sources
dotnet run --project tests/FruitMachineLab.Verification --no-build -- . 'ROM patch'
powershell -NoProfile -File tools/Test-RomPatchCli.ps1
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .
dotnet build FruitMachineLab.sln --no-restore
```

Observed 17 October: headless/full builds 0 warnings/errors, four new patch groups
pass, CLI tests pass, full suite **357 groups** (baseline353). No dependencies or
tools installed. The CLI tests use generated synthetic data; no ROM required.
GUI behaviour unchanged; GUI smoke modes were not rerun.

The new groups cover input preservation, exact unrelated-byte preservation,
determinism, late-edit failure, length/hash/expected-byte rejection, overlap/bounds/
resize/malformed schema rejection, curated table provenance and changed execution.
CLI checks additionally exercise existing-output/input rejection, no output on
wrong identity, report/readback and repeated output hashes.

## First patch

`evidence/mpu4/patches/skill-cash-level1-12.json` changes the shared award table:

| Property | Value |
| --- | --- |
| Input | a6ls.p1, 65536 bytes, SHA1 `402d1518bb78fdc489b06c2aabc771e5ce151847` |
| Checked range / file offset | 75BD–75C3 / decimal30141, expected `000A1014162F3C` |
| Replacement | `000C1014162F3C` |
| Only changed byte | 75BE / decimal30142: 0A→0C (10→12 internal units) |
| Original SHA256 | `EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C` |
| Patched SHA256 | `A67062F32DBA37AD4F24C8B1BC6AC92C91E8F3B39CE8F9C21904AF0FD1667714` |
| Patched SHA1 / CRC from MAME | `58e997e6e1d2ef2251ddde18a5d41716d21368c0` / `b0a4b990` |

Static provenance: `maps/skill-cash-rom-data.json`. Actual consumers include
`VM-SCRIPTS/C6FC.txt` C6FE–C706, other VM result definitions 9FEF/E796/E812 and
`AddersNudgeAvailability.Lookup`. This is **not Skill Cash-only**. No assertion
that every consumer accepts every arbitrary replacement value. The first edit
uses a modest existing-range award value, without changing pointers, size or timing.

Generate a separate output (directory must already exist; output must not exist):

```powershell
$original = 'C:\Users\John\Documents\Codex\2026-10-13\help-me-set-up-a-local\outputs\mpu4\rom\a6ls.p1'
New-Item -ItemType Directory -Force artifacts/rom-patch | Out-Null
dotnet run --project tools/FruitMachineLab.RomPatch --no-build -- `
  evidence/mpu4/patches/skill-cash-level1-12.json $original artifacts/rom-patch/level1-12.p1
```

Supply your own legally available original image on other hosts. A wrong revision
fails, even if the edited range happens to match. SHA1 identifies the preserved
reference; SHA256 additionally records build assets. No patched binary is tracked.

Schema1 uses strict PascalCase JSON members: SchemaVersion, Description,
InputLength, InputSha1, Edits; each edit has Offset, ExpectedHex, ReplacementHex,
Provenance. Offsets are file offsets, never automatically interpreted as CPU
addresses. Every edit must be nonempty, bounded, equal length and nonoverlapping.
Unknown JSON members/missing required fields fail. Equal bytes within a checked
range are allowed and do not appear in ChangedOffsets. Metadata provenance is
required text, not an automatic proof of its semantic claims.

## Cross-target experiment

The PC test generates a synthetic64KiB image holding the original table, explicitly
substitutes its synthetic identity **inside the test only**, then applies the
shipped edit. `ScriptExecutor.RunRange(C6FC, C6FE, C706)` leaves10 before and12 after;
`AddersNudgeAvailability.Lookup` agrees on a matching level1 triple. This verifies
the existing recovered code reads the changed shared data. The actual original
image was separately patched by the CLI with its unmodified strict identity.
Live is not switched to patched data automatically: `SkillCashData.Load` and
decoded operands still supply reference content. General editable code needs a
common checked decode/build path, as the roadmap records.

MAME0.281 was available at `E:\Arcade\MAME0266\mame281.exe`, SHA256
`0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A`.
The tool below uses a fresh directory and a loose copy under roms/m4addr/a6ls.p1;
original assets/settings/NVRAM remain untouched. It passes isolated directories
and `-noreadconfig`. Loader CRC/SHA warnings for the modified image are expected
and preserved, not suppressed or confused with the firmware's integrity checks.

```powershell
powershell -NoProfile -File tools/Capture-RomPatch.ps1 `
  -MameExecutable E:\Arcade\MAME0266\mame281.exe `
  -RomDirectory E:\Arcade\MAME0266\roms `
  -PatchedRom artifacts/rom-patch/level1-12.p1 `
  -RunDirectory artifacts/rom-patch/mame-lookup-verified

# Original control: change only image, expected value and fresh run directory.
powershell -NoProfile -File tools/Capture-RomPatch.ps1 `
  -MameExecutable E:\Arcade\MAME0266\mame281.exe `
  -RomDirectory E:\Arcade\MAME0266\roms -PatchedRom $original `
  -RunDirectory artifacts/rom-patch/mame-lookup-original -ExpectedValue 10
```

Both passed. This is a **synthetic isolated original-VM invocation**: copy the
original RAM dispatch template from7927, set Y=C6FE, U=0600, local frame0500 with
level1, mask interrupts and stop at FC/Y=C708. Original top=000A; modified top=000C.
The script verifies actual result lines, not merely process exit0. Small logs,
commands and hashes are preserved under `evidence/mpu4/patches`; ROMs/raw RAM and
full runs remain ignored under artifacts. No gameplay result is injected.

Reset observation: use `-Mode Boot` with a fresh directory (and ExpectedValue10
for control). No PC/RAM injection in that mode; observes initial FDF0 stream and
final state at12 emulated seconds. Neither original nor patched image reached
that marker. Original ended PC294C/YFFFF; modified PC1A5B/Y3824. This is **inconclusive
startup evidence**, not a diagnosis of firmware failure or proof of successful
boot. The marker/window itself needs validation against known original startup.
A separate natural original-ROM capture now observes reset, init `6750`,
checksum `66A5`/`66DB` and return to `677E` with unchanged original SHA1; the
curator strictly rechecks identity, isolated ROM copy length/hash, raw log and
console hashes, exit0, marker order and captured injection claims; see
[ROM integrity](recovery/ROM-INTEGRITY-PASS.md). A separate natural original-ROM
continuation reaches the init tail and first VM entry at `76C7` with initial
stream pointer `FDF0`, stopping before the first token fetch; see
[startup VM entry](recovery/STARTUP-VM-ENTRY-PASS.md). It does not validate later
VM/gameplay behaviour. Both patch probes exited0; expected modified loader
warning occurred. The existing award edit has since been regenerated in the
original checker's required field order: the unrepaired image is rejected at
`674F` with `error=12` after `sum=40 xor=70`, while the repaired image passes
the unmodified checker and reaches the same `76C7` entry with `X=FDF0`; see
[ordered integrity repair](recovery/ROM-INTEGRITY-REPAIR-PASS.md). No checker
bypass, gameplay/play-session claim or physical test is made.

Harness development failures are excluded from accepted evidence: the first
PowerShell run stopped on expected stderr; an early isolated lookup omitted the
RAM dispatch template and never reached its result. The corrected original and
modified controls above reach C708 and are the accepted evidence.

## Historical next boundary

The active gate-00 field regeneration is now demonstrated to the first VM entry.
Next demonstrate original/modified natural play beyond that entry, or generalise
the repair only from a separately validated definition. Preserve unknown code/data
and do not designate padding as free space based on appearance alone. The partial machine-readable map is
`maps/rom-layout.json`; relocation, bank expansion, full dictionary recovery and
native/hardware compatibility remain open. The active order is now the first
IL-to-MAME slice in PROJECT-ROADMAP.md; native C# compatibility is deferred.

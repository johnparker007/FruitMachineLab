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

### Installed MAME 0.281 Lua debugger and exact boundaries

The earlier claim that MAME 0.281 had no Lua debugger was wrong: it checked the
unrelated global name `debugger` without enabling the debugger. Under `-debug`,
`manager.machine.debugger` and `manager.machine.devices[tag].debug` are userdata
and expose breakpoints, stepping, run control and console commands. There is
still no Lua instruction callback, so frame callbacks are not instruction
boundaries. `tools/lua/IlVmTrace.lua` validates a variant-bound source map
against live ROM bytes and records the debugger capability, physical input,
frame-sampled PC/X/Y/U/S and tap diagnostics. Exact boundaries come from native
debugger `bpset`/`printf` hooks generated from the checked source map and
handler-entry plan. The `il-lua-api-09` capture completed the first natural
`9ED9` call for original and repaired images, including all five prefetches,
handler entries, the `PULS` return, saved caller cursor `9F16` and the actual
post-return `00FC` fetch at `Y=9F16`/`S=0798` (original result `0000`, repaired
`0080`). The separate `il-natural-06` EE16/EE22 paid-window gate is unchanged.
See [IL/Lua debugger and early call](recovery/IL-LUA-VM-TRACE.md).

### Bounded paused IL debugger session

The accepted early-call tooling now includes a reusable read-only paused session
for the five-node `9ED9` map. It uses the installed MAME 0.281 OSD debugger as the
stopped host, `cpu.debug:step(1)` for native instruction stepping, and a strict
file-based command protocol. It never writes CPU registers, RAM, ROM, save
states or the VM stack. Exact boundaries are native; the Lua periodic callback is
only the command/step driver and is not an instruction boundary.

The command vocabulary is `pause-at-mapped-node`, `inspect`,
`step-one-IL-node`, `resume-to-supported-boundary` and `stop`. Requests are
strict `key=value` files with a session ID, monotonic sequence, request ID and
nonce. Unknown commands, write fields, arbitrary addresses/lengths, injected
state, wrong phases, stale/out-of-order requests, response collisions and forged
acknowledgments are rejected. Inspect returns only PC/X/Y/U/S, bounded data- and
control-stack words, emulated time and map-resolved IL operands. Repeated
inspections do not advance state.

Event records are strict JSONL. The serializer escapes quotes, backslashes,
CR/LF/tab and every other U+0000..U+001F control byte as `\u00xx`; it never
writes a trailing comma. `tests/worker/Test-IlDebugSession.ps1` parses every
nonblank record with `System.Text.Json` (`AllowTrailingCommas=false`), checks
the expected command/step/return/stop content, and runs negative controls that
reject trailing commas and raw control characters. The preserved step-10 event
logs are invalid and remain only as rejected review inputs. The serializer
escaping probe is in `tests/worker/Test-IlEventJson.ps1` and uses the real
serializer block under installed MAME Lua 5.4.

`-debugger windows` is required as the stopped host; `-debugger none`
auto-resumes on scheduled events at reset and is not used for idle sessions.
There is still no Lua instruction callback. Only the fixed `9ED9` map is
supported; no extension range, new word, dictionary editor, arbitrary read,
register write or save-state load is included. The demonstrated call is the first
natural `9ED9` call, not the later `EBCA -> 9ED9` paid window. The `EE16/EE22`
comparison remains unchanged and unresolved. See
[IL debug session](recovery/IL-DEBUG-SESSION.md).

```powershell
powershell -NoProfile -File tools/Start-IlDebugSession.ps1 `
  -MameExecutable E:\Arcade\MAME0266\mame281.exe `
  -RomDirectory E:\Arcade\MAME0266\roms `
  -OriginalRom <a6ls.p1> -RepairedRom <edited-repaired.p1> `
  -Variant Original -RunDirectory <fresh-run> -SecondsToRun 120 -WallTimeoutSeconds 180

powershell -NoProfile -File tools/Invoke-IlDebugCommand.ps1 `
  -SessionDirectory <fresh-run> -Command pause-at-mapped-node -Node 0
powershell -NoProfile -File tools/Invoke-IlDebugCommand.ps1 `
  -SessionDirectory <fresh-run> -Command inspect
# Then resume-to-supported-boundary, five step-one-IL-node commands and stop.

powershell -NoProfile -File tests/worker/Test-IlDebugSession.ps1 -Force
```

The verifier runs fresh original and repaired sessions plus the negative
controls, parses every event record strictly, runs the serializer escaping probe,
and regenerates `evidence/mpu4/integrity/il-debug-session.json`. Raw runs stay
under `artifacts/deepseek/il-debug-log-11/`.

## Existing fixed-size patcher and historical measurements

This is a small hybrid ROM builder: preserve the original image and change only
explicit equal-length ranges. It is not a compiler, relocation tool or firmware
integrity repairer. `RomPatch.Apply` is independent of game traces and snapshots.
The CLI writes with `FileMode.CreateNew`, rejects the input/specification as output,
rejects existing outputs, reads the result back and prints input/output SHA256 and
exact changed offsets. Validation occurs before any output is created.

## Independent IL same-size operand edit and ordered integrity repair

`FruitMachineLab.Il` decodes the fixed 9ED9 definition, compiles it
byte-identically, and supports exactly one checked same-size edit: the first
`795B` inline-word literal operand at `9EDB..9EDC` may change from the strict
original `FF80` to a declared 16-bit replacement. The production compiler
rejects wrong ROM identity, caller-supplied IL hashes, wrong expected values,
wrong addresses/widths, unsupported tokens, unrelated byte changes,
multiple/overlapping edits and invalid spans. Emitted operand bytes are derived
from the edited IL value; original bytes remain separately recorded.

After that compile, `VmIlIntegrity` validates the exact original identity, the
recovered record table (disabled `FFB0-FFD0`, active `FFD1` with gate `00` and
error `12`, metadata `FFD6-FFDB` = `1400FFFF1200`, outer gate `719B` = `00`),
the single `9EDC` diff, the retained span and the protected checker/gate bytes.
It then regenerates only the active fields in the checker's recovered order:
sum/XOR (`FFD1`/`FFD2`), rotate-add (`FFD3`, reads regenerated `FFD1-FFD2`),
then rotate-sub-XOR (`FFD4`/`FFD5`, reads regenerated `FFD1-FFD3`). Sum/XOR
excludes `FFD1-FFD5`; rotate-add excludes `FFD3-FFD5`; rotate-sub-XOR excludes
`FFD4-FFD5`. The checker code, outer gate, ranges and disabled records are
preserved, not patched.

Generate fresh, create-only images and reports:

```powershell
dotnet run --project tools/FruitMachineLab.IlBuild --no-build -- `
  <original-a6ls.p1> artifacts/deepseek/il-integrity-03/cli-positive
```

The CLI writes `edited-unrepaired.p1`, `edited-repaired.p1`,
`build-report.json`, `integrity-report.json` and `source-map.json`. The source
map covers all 14 bytes at unchanged addresses and is bound to the repaired
image SHA256. For the fixed `9EDB FF80 -> FF00` edit the accepted span is
`795BFF00787E795BFF807AAF792F`:

| Image | Fields / diff | SHA1 | SHA256 |
| --- | --- | --- | --- |
| Unrepaired | fields `3E761E2605`, diff `9EDC` only | `51E81CC5F41DA2AA659A4D14D277E9E78614EB6B` | `A99D96F8EA8B4770D2D3828125F25894E831726FE44A79A37E0871FABA135ED2` |
| Repaired | fields `BEF69E7CC7`, diff `9EDC` + `FFD1-FFD5` | `E1A42DCCD304B7B175AABAC99E8400CDAD04CF69` | `577F76BD36DFCA04DFB01B5F5D0BE93E16572F8617C7CA906397C98DF36E5107` |

The repair-only diff is exactly `FFD1-FFD5`; every other byte is unchanged. An
independent PowerShell execution of the existing recovered algorithm (copied
verbatim from `tools/Verify-RomIntegrity.ps1`) on isolated copies produced the
same fields and a byte-identical repaired image; `tools/Verify-RomIntegrity.ps1`
separately verifies the original.

Production rejects wrong length/SHA1/SHA256, altered original table/field or
protected bytes, unexpected edits, `9EDC` not `80 -> 00`, missing/edited spans,
malformed inputs, stale maps and existing/colliding targets. Only this fixed
definition, first operand and active gate-00 record are supported. Natural
fresh-boot checker acceptance for this repaired image is recorded separately;
natural 9ED9 reach, gameplay and hardware compatibility remain unproved.
Algorithmically repaired alone is not natural acceptance.

## Independent 9A64 static decode and checked byte branches

`FruitMachineLab.Il` now also decodes the existing 9A64 definition directly from
the identity-checked original ROM bytes. The selected span is `9A64..9A71`
(`7B6D79820676657979037671792F`), six nodes, with the checked listing and
encoding checkpoint used only as oracles. The decoder validates the `9A62` header
`00F8`, token pointers, a single final return, supported widths and branch
targets.

The two branch tokens retain their byte-sized operands explicitly. Original 6809
handler bytes at `797B` (`LDAB ,Y; CLRA; LEAY D,Y; JMP <$FC`) and `7984`
(`LDD ,U++; BEQ $797B; LEAY 1,Y; JMP <$FC`) establish an unsigned one-byte
operand at the operand address, forward target = operand address + operand byte.
The 9A64 targets are `9A68 + 06 = 9A6E` for `7982` when the popped cell is zero,
and `9A6D + 03 = 9A70` unconditionally for `7979`. Nonzero `7982` skips the byte
and continues at `9A69`.

`VmIlNode.Branch` is additive; existing 9ED9 nodes and edits are unchanged.
`VmIlCompiler.CompileIdentity` re-emits the decoded body and rejects forged branch
plans. `VmIlSourceMap` exposes branch positions, explicit targets, handler and
operand evidence, and binds them to the exact image hash. 9A64 edits remain
unsupported; this is static decoded-contract evidence, not natural execution or
runtime branch-path coverage. See
[9A64 decode](recovery/IL-9A64-DECODE.md) and
`evidence/mpu4/integrity/il-9a64-decode.json`.

## Natural 9A64 branch observation

A single fresh-boot original-ROM run with the tracked physical-input replay has
now reached the checked 9A64 body naturally. Within 120 emulated seconds it
completed five calls at caller site `EF9C`, covering all six mapped nodes and
both branch paths. Exact stops came from native debugger breakpoints generated
from a map produced by `NineASixFourDecoder` + `VmIlCompiler.CompileIdentity` +
`VmIlSourceMap`; the Lua periodic callback was only the stopped-state driver.

The zero path popped `0000` and moved from the `7982` operand address `9A68` to
`9A6E`, then ran `7671` and returned. The nonzero path popped `FFFF`, skipped to
`9A69`, ran `7665`, took the unconditional `7979` operand `03` to `9A70`, and
returned. In every call the `7984` handler advanced `U` by exactly two, and the
`7931` return restored `Y=EF9E` with `S` advancing from `07AA` to `07AC`; the
post-return token was the ROM word `80C4` at `EF9E`. MAME exited 0 and the
isolated ROM was unchanged.

Four negative controls passed: malformed JSONL, stale map identity,
phase-mismatched prefetch, and missing post-return completion. No memory
OR/clear effect, other caller site, 9A64 edit, extension, paid-window result or
hardware claim is made. See
[natural 9A64](recovery/IL-9A64-NATURAL.md) and
`evidence/mpu4/integrity/il-9a64-natural.json`.

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

Separately, the accepted IL 9ED9 build was regenerated fresh and compared with
the untouched original in the same isolated startup harness. The original
control computes `3E761E2605`; the repaired image computes and stores
`BEF69E7CC7`, passes the unmodified checker, returns to `677E`, follows the init
tail to `7CF6` and reaches the first `76C7` entry with `X=FDF0`. Both stop
before the first token fetch; the recorded `Y` is not a fetched VM cursor and
the identical first stream word is a passive read, not execution. See
[IL integrity startup](recovery/IL-INTEGRITY-STARTUP.md) and
`evidence/mpu4/integrity/il-integrity-startup.json`. Natural 9ED9 execution,
gameplay and hardware compatibility remain unproved.

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

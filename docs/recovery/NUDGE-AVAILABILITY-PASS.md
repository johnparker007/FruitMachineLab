# Recovered nudge availability after a ladder

15 October 2026. With board continuation enabled, Live ladder entry now reaches
square 22/pot 3, computes the native nudge-availability search and displays the
actual TAKE NUDGEPOT / roll prompt. Physical START drives another roll/advance.
Physical TAKE reaches the explicit type-1 result boundary; playing the awarded
nudges is still unrecovered. Existing bounded modes and playback remain available.

## Natural reference

A fresh isolated MAME campaign uses the unchanged physical-input fixture and
captures DBC4 ladder entry through the next DD7E roll decision. No RAM, registers
or ROM are redirected in this natural run. The extended fixture matches:

- 5,544 canonical VM observations, all 27 fields;
- 65 lamp requests and their complete frame results;
- 420 sound commands and timing/state fields;
- 1,631 alpha serial bytes;
- 52 native 29F4 calls: physical U/budget at entry, returned cell, C8 best result,
  A8, DD, DE and all three restored symbol words at exit.

All observed calls use budget 3 and return 0010. Both pending and current-win
remain zero. The complete earlier 620-observation ladder continuation prefix
matches independently. No new undefined-local masks, lifted dispatches or output
exceptions are used. The earlier roll brightness discrepancy remains unchanged.
Curated fixture, debugger commands and sidecar retain source hashes/provenance.
The capture completed with exit 0; full logs and temporary MAME files stay outside Git.

## Assembly translation

AddersNudgeAvailability translates 29F4, 2A7F, 1AC3, 1B63 and 1B7B. Assembly is
authoritative here: the exported flag-helper pseudocode incorrectly appears to
return zero unconditionally. It is retained as recovered analysis, not original
source or a complete semantic definition.

29F4 consumes the low byte of a cell, allocates a counted 17-byte U scratch frame,
performs the search, sign-extends C8 to the returned cell, restores all three
symbol words and clears DD. The translated fixed-frame use preserves scratch
writes, including bytes overlapping the final result cell. The generic SWI2
overflow path remains an explicit unsupported boundary.

2A7F visits candidates in native byte-loop order, including wrap and signed
negative-magnitude branches. It uses the saved indices at 0198/019A/019C minus
requested offsets, fixed three 32-byte strips at 75DB/75FB/761B, and retains the
first candidate on an equal score. It sets A8=FF and records best candidate offsets
in scratch RAM. This is a search, not a substituted availability constant.

1AC3 prioritizes equal symbols, common flag 1, DD-enabled common flag 2, then
matching pairs. Flag 1 reads the triple table's index 1; flag 2 returns 11 and
sets DE=FF. Pair/triple indexing retains the signed A-register offset. A triple
whose table result is zero returns zero directly rather than falling through.
Selected static triple/pair table bytes are curated with the established ROM SHA1.

## Synthetic native matrix

A separate, explicitly synthetic MAME debugger run calls the native routines with
IRQs masked and controlled PC/U/S, budgets, symbols and flags. This is not a
natural game campaign. It does not modify the original ROM or workspace.

17 cases check ten search budgets (0, 1, 3, 7, 0100, 0103, 63, 64, 127, 255)
and seven lookup cases. They exercise ignored high cell bytes, byte/signed wrap,
ties/candidate order, symbol preservation, pair/triple and common-flag priority,
DD gating and DE side effects. Every byte below 0700 matches MAME after each
case, including U scratch residue and result cells. Native CPU S-stack temporary
save/return residue in 0700..07FF is explicitly excluded; general native CPU
register/stack emulation is not claimed. Before images and expected digests are
curated with raw/binary/seed hashes and synthetic classification.

## Live and timing limits

Live executes this translated helper through the existing recovered input and
feature-availability code. It applies no recorded return cells or input events.
The ladder's symbols remain intact. START and TAKE still use sampled physical
BLACK2 bits 80 and 01. Pause preserves memory/time; Resume continues and Restart
restores entry. UI wording now describes TAKE as selecting the displayed feature,
since square 22 offers NUDGEPOT rather than Skill Cash.

CPU/IRQ pacing remains the declared provisional adapter. Search entry cost in Live
comes from the observed budget-3 prompt; it is not a general cycle-accurate cost
model for every search budget. Synthetic matrix tests establish memory/result
semantics, not Live scheduling parity. Native helper execution is atomic at VM
dispatch boundaries. Full machine timing, nudge play and persistent games remain open.

## Verification and reproduction

116 headless groups pass. Headless and isolated WPF builds succeed. All seven GUI
smoke modes pass, preserving the earlier six and adding:

```powershell
<diagnostics-output>/FruitMachineLab.Diagnostics.exe --live-availability-smoke-test <fresh-artifact-directory>
```

The new real-time GUI smoke checks ladder arrival, computed availability, rendered
TAKE NUDGEPOT, actual pause/resume, mouse START leading to a new motor/board advance,
mouse TAKE leading to the explicit type-1 boundary, released inputs and restart.

```powershell
./tools/Capture-SkillCash.ps1 -MameExecutable <mame281.exe> -RomDirectory <rom-directory> -RunDirectory <fresh-natural-run> -FullFeature -NativeSound -NativeInput -NativeLampFrames -NativeAlpha -CpuInterrupts -BoardLink Ladder -ContinueBoard -Availability
./tools/Curate-BoardLink.ps1 -RunDirectory <fresh-natural-run> -LinkKind ladder -Continuation -Availability
./tools/Curate-AvailabilityData.ps1 -RomPath <a6ls.p1>
./tools/Capture-AvailabilityMatrix.ps1 -MameExecutable <mame281.exe> -RomDirectory <rom-directory> -SeedRam <fresh-natural-run>/availability-ram.bin -RunDirectory <fresh-matrix-run>
./tools/Curate-AvailabilityMatrix.ps1 -RunDirectory <fresh-matrix-run>
dotnet build FruitMachineLab.Headless.sln --no-restore
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .
```

Next: recover/reference-check the type-1 E247/B91D result route, including flagged
29EC search and the B72D nudge interaction, adding only evidenced temporary input
controls. Type-3 special features and type-8 snake result remain separate open
routes. No installations, configuration changes, commits, pushes or cloud setup
were made. Original ROMs, forensic workspace and MAME settings remain preserved.

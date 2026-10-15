# Type-1 nudge preparation

15 October 2026. With continuation enabled, TAKE at the ladder's square-22
TAKE NUDGEPOT prompt now follows the actual type-1 result dispatch and prepares
three nudges. Live stops immediately before B4C5 nudge-sequence execution.
It does not move the main reels or invent a nudge award. START remains available
as the alternative roll route. Existing playback and bounded modes remain separate.

## Native flagged search

29EC sets DD=FF, clears DE and falls through to the existing 29F4 search. The
translation retains those effects, scratch memory, candidate ordering, result
sign extension, restored symbol words and final DD clear. Its existing static
export is now curated. The function name/decompiler output is not the proof;
the assembly and recorded native behaviour establish this small entry sequence.

A fresh synthetic native MAME matrix uses controlled PC/U/S/CC, with IRQs masked.
Ten flagged search budgets (0,1,3,7,0100,0103,63,64,127,255) and seven lookup cases
match every byte of RAM below0700. This checks the wrapper's DE reset as well as
search effects and retained symbol words. Native CPU S-stack residue above0700
remains excluded. This is a helper experiment, not a natural gameplay campaign.
The original unflagged matrix remains unchanged and still passes independently.

## Naturally reached preparation

A fresh isolated campaign preserves the existing physical input fixture until
the machine naturally reaches square22 and displays TAKE NUDGE. A single
additional physical BLACK2 bit01 TAKE pulse is then sent for 12 frames. No RAM,
register, ROM or feature-result redirection is used. The additional input is
explicit in the copied observer and provenance; this is not claimed to be the
unchanged earlier physical-input path. The generated action log records the pulse.

The capture starts at E247 and stops at B4C5. It checks:

- 229 VM observations, retaining the canonical 27 fields;
- 24 lamp requests and complete frame results;
- three native search calls, including entry U/budget and returned result,
  C8/A8/DD/DE and restored symbols;
- zero sound commands and zero alpha bytes in this narrow preparation segment.

The three searches use budget3 and return0010. B91D sets BD=15hex. B5ED follows
the matching source branch and copies pot BF=3 to remaining nudges BE=3.
B626 saves the candidate result, remaining count and reel indices in the local
frame. B2A8 updates local result/improvement state and lamps, and B2E8 refreshes
the nudge-pot display. Pending/current-win remain zero. B4C5 has not executed.
The selected ROM records and semantic map accompany the fixture.

The native 29EC call reaches the observer breakpoint at29F4 after setting DD/DE;
native exit effects are compared after the common search body. The independent
flagged matrix additionally proves the wrapper's initial DE clear.

## Uninitialized local-frame qualification

B730 allocates a nine-byte local frame without initializing it. Its first word
contains native CPU-stack residue until the ROM writes each byte. The canonical
comparison explicitly masks the undefined bytes for 141 observations: zero mask
after allocation, high byte enabled after B2D0's store, both bytes enabled after
B2E2's clear. The raw VM digest retains the original bytes. Ordinal masks are
recorded by the curator and independently derived/validated by the verifier;
extra, missing or changed masks fail. Existing paths keep their earlier strict
comparisons and qualifications. No scratch outcome is substituted into gameplay.

## Live scope

The type-1 dynamic table gateway E245 is admitted as a validated 00F8 threaded
call to E247. The indexed record's token825A is a validated 794F word literal
0198. Other missing dynamic words still fail explicitly. Only selected parameter
records are loaded from the hash-checked ROM; native loops and VM scripts compute
the preparation. The UI handler has no nudge gameplay logic.

Live now permits type1 alongside the existing type2 result route and stops at
B4C5 with the computed nudge count. Its timing still uses provisional captured
CPU/IRQ pacing and atomic native helper dispatch. Natural preparation comparison
does not establish main-reel timing or interactive nudge equivalence. No main-reel
motion implementation is borrowed from the dice without checking it first.

118 headless groups pass. Headless and isolated WPF builds succeed; all seven GUI
smoke modes pass. The updated real-time availability smoke checks physical TAKE
through preparation (BE=3), released controls and clean restart, plus physical
START leading to another generated roll. The existing tests retain accounting,
pause/resume, playback and explicit unsupported-result checks.

## Reproduction

```powershell
./tools/Capture-SkillCash.ps1 -MameExecutable <mame281.exe> -RomDirectory <rom-directory> -RunDirectory <fresh-run> -FullFeature -NativeSound -NativeInput -NativeLampFrames -NativeAlpha -CpuInterrupts -BoardLink Ladder -ContinueBoard -Availability -NudgeEntry
./tools/Curate-BoardLink.ps1 -RunDirectory <fresh-run> -LinkKind ladder -Continuation -Availability -NudgeEntry
./tools/Curate-NudgeData.ps1 -RomPath <a6ls.p1>
./tools/Capture-AvailabilityMatrix.ps1 -MameExecutable <mame281.exe> -RomDirectory <rom-directory> -SeedRam <availability-run>/availability-ram.bin -RunDirectory <fresh-matrix-run> -Flagged
./tools/Curate-AvailabilityMatrix.ps1 -RunDirectory <fresh-matrix-run> -Flagged
dotnet build FruitMachineLab.Headless.sln --no-restore
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .
```

The useful natural run and synthetic matrix completed with exit0. An earlier
campaign without the additional TAKE pulse did not supply this fixture. Its
temporary output is not used. Raw captures, ROMs and isolated MAME files remain
outside Git. The original forensic workspace and MAME settings are preserved.

Next: extend the natural capture through B4AD's matching-result gate (native1AA3),
9FA2 flag test, B3C8 prompt and B403 button scan. Recover the actual input ports,
polarity and sampling from the 9E06 token table and MAME mapping before adding
temporary reel-nudge controls. B31F then requires independently verified main-reel
service/motion and nudge consumption. Preserve a bounded milestone at each step;
do not open all result routes. No installations, configuration changes, commits,
pushes or cloud setup were performed.

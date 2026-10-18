# IL integrity startup acceptance

18 October 2026. This report records a natural MAME 0.281 fresh-boot comparison
of the untouched original A6L image and the IL 9ED9 operand edit with ordered
active-field repair. Both images pass the original firmware checker and reach
the first threaded-VM entry at `76C7`. This is startup/checksum acceptance only.
It does not observe 9ED9 execution, gameplay or physical hardware.

## Evidence classes

- **Natural:** the marker PCs and field values below were printed by read-only
  MAME debugger breakpoints during real fresh-boot execution. No PC, RAM,
  register, input or ROM is injected. Both runs use fresh isolated directories,
  `-noreadconfig`, declared-absent NVRAM/configuration and no playback/state
  load. The capture records pre-run directory emptiness before launch.
- **Static:** the original identities, changed-byte set, active fields and
  source-map binding come from the original bytes and the accepted 9ED9 build.
  The interpreter phase is explained from `evidence/mpu4/native/76c7.json` and
  the recovered `7927` template, not from a claimed token execution.
- **Synthetic:** parser tests and curator negative controls tamper with copied
  logs/json/RAM-free artifacts only. They are not natural execution evidence.

## Images and build

| Image | Length | SHA1 | SHA256 | Active fields |
| --- | ---: | --- | --- | --- |
| Original | 65536 | `402d1518bb78fdc489b06c2aabc771e5ce151847` | `ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c` | `3E761E2605` |
| IL repaired | 65536 | `e1a42dccd304b7b175aabac99e8400cdad04cf69` | `577f76bd36dfca04dfb01b5f5d0be93e16572f8617c7ca906397c98df36e5107` | `BEF69E7CC7` |

The repaired image was regenerated from the accepted original with
`tools/FruitMachineLab.IlBuild`. It differs from the original at exactly
`9EDC` (the first `795B` operand, `80` to `00`) and `FFD1-FFD5` (the ordered
active expected fields). No other byte differs. The intervening bytes are
`FFD1: 3E->BE`, `FFD2: 76->F6`, `FFD3: 1E->9E`, `FFD4: 26->7C`,
`FFD5: 05->C7`. The build source map is bound to SHA256
`577f76bd...5107`; its SHA256 is
`0c39a6d0d1beac32ca0f64bfec5ce848b2297be41180d0234d2bfdf491df21a9`.
The build report SHA256 is
`ae7e0fb2c0121e0b4e62d38e82511841644fcdf922b2d9e54de79b3d7e57f61a`.

## MAME and isolation

MAME executable: `E:\Arcade\MAME0266\mame281.exe`, version
`0.281 (mame0281)`, SHA256
`0fce5a88df4f9d9b1fbf1405812c00848036e615993780978d967da34204cb7a`.

Both runs used fresh isolated directories under
`artifacts/deepseek/il-boot-04/runs/` (`original-02` and `repaired-01`), with
separate `cfg`, `nvram`, `inp`, `snap`, `comments`, `state` and `diff`
directories. Each run copied only `a6ls.p1` into its isolated `roms/m4addr`
directory; the installed MAME ROM directory supplied support files. The
pre-run file counts in all seven state directories were zero, and the isolated
ROM directory contained exactly `a6ls.p1`. Each run passed `-noreadconfig`,
`-seconds_to_run 30` and a 600-second wall cap. Actual exits were `0`; wall
times were 4.065 s (original) and 3.588 s (repaired). MAME's console summary
reported 25 emulated seconds for each run.

The argument set included `-debug`, `-debugger windows`, `-debugscript`,
`-debuglog`, `-video none`, `-sound none`, `-window`, `-skip_gameinfo` and
`-nothrottle`. The only debugger commands were read-only `bpset`/`printf`,
`go` and `quit`. The exact command arrays and raw logs are in each run's
private `command.json`, `debug.log`, `console.txt` and `console.err.txt`.

## Observed startup

Both runs contain the same marker sequence: three resets, three init entries,
two complete checksum groups, then the init tail, the `7CF6` call and the first
`76C7` entry. The anchored group is the pass immediately before `67B3`.

```text
ILBOOT_RESET pc=7CD1 s=07C2 cc=D0
ILBOOT_INIT_ENTRY pc=6750 u=0672
ILBOOT_ROM_CHECK_ENTRY pc=66A5 u=0672 gate719b=00
ILBOOT_ROM_VERIFY_ENTRY pc=66DB u=066A expected=<fields> start=1400 end=FFFF error=12
ILBOOT_SUM_XOR sum=<sum> xor=<xor>
ILBOOT_ROTATE_ADD value=<rotate-add>
ILBOOT_ROTATE_SUB_XOR a=<a> b=<b>
ILBOOT_ROM_CHECK_RETURN pc=677E y=FFFF u=0672
ILBOOT_INIT_TAIL_JMP pc=67B3 y=0000 u=0672
ILBOOT_INIT_TAIL_ENTRY pc=3B1A y=0000 u=0672
ILBOOT_VM_CALL pc=7CF6 x=FDF0 y=02DA u=0672
ILBOOT_VM_ENTRY pc=76C7 x=FDF0 y=02DA u=0672 s=07C6 first_word=7FBD
ILBOOT_CAPTURE_END pc=76C7 x=FDF0 y=02DA u=0672 s=07C6 first_word=7FBD
```

For the original, `<fields>` and the computed fields are `3E761E2605`
(`sum=3E xor=76`, `rotate-add=1E`, `rotate-sub a=26 b=05`). For the repaired
image they are `BEF69E7CC7` (`sum=BE xor=F6`, `rotate-add=9E`,
`rotate-sub a=7C b=C7`). No `ILBOOT_ROM_VERIFY_FAILED` marker occurred in
either run. The repaired image therefore passes the unmodified original
checker, not a bypass.

The first `677E` return is followed by another reset in both runs. That restart
is observed but not explained here; the curated chain is anchored to the
checksum group immediately before `67B3`.

## VM entry phase and limits

At `76C7`, the interpreter has not yet fetched a token. The recovered native
entry copies the `7927..792E` template to RAM `F8..FF`; the template is
`F8: PSHS Y; LEAY ,X` and `FC: LDX ,Y++; JMP [,X++]`. At the observed entry
`X=FDF0` is the initial token-stream pointer and `Y=02DA` still belongs to the
caller. `Y` is therefore not a fetched VM cursor at this point. The recorded
`first_word=7FBD` is a read-only peek at the not-yet-fetched head of the
`FDF0` stream, not an executed instruction, and no PC-to-IL mapping beyond the
native entry PC is claimed. The token fetch/dispatch immediately after `76EF`
remains unobserved.

The repaired image produces the expected MAME loader warnings (`a6ls.p1 WRONG
CHECKSUMS`, CRC `a1627b69`, SHA1 `e1a42dcc...cf69`). Those loader warnings are
separate from the original firmware checker result and do not weaken it.

## Verification and negative controls

The curator rechecks the original and variant identities, the exact changed
byte set, the active field bytes, the source-map and build-report binding, the
pre-run emptiness records, the raw debug-log and console hashes, the exit
codes, the observation booleans and the complete marker chain. It rejects a
firmware failure marker, missing or unordered markers, a stale identity or log
hash, a changed ROM copy, a nonempty pre-run state directory, debugger state
injection, a wrong changed-offset set and an existing create-only output.

The focused harness test `tests/worker/Test-IlIntegrityStartup.ps1` passed 26
checks with 0 failures. It covers wrong/original identity, missing reset/
rotate/VM markers, a firmware failure marker, unordered phases, a first field
mismatch, wrong expected fields, a marker after capture end, stale observation
identity, changed-offset disagreement, pre-run/create-only collisions and the
valid original/repaired parsers. These parser tests are synthetic; the natural
runs above are the acceptance evidence.

Curated result: `evidence/mpu4/integrity/il-integrity-startup.json`.
Private raw runs: `artifacts/deepseek/il-boot-04/runs/original-02` and
`artifacts/deepseek/il-boot-04/runs/repaired-01`; the fresh build is under
`artifacts/deepseek/il-boot-04/build-01`.

## Reproduction

The create-only outputs above now exist in the private tree; use fresh output
and run paths when rerunning.

```powershell
$original = 'C:\Users\John\Documents\Codex\2026-10-13\help-me-set-up-a-local\outputs\mpu4\rom\a6ls.p1'
dotnet run --project tools/FruitMachineLab.IlBuild --no-build -- `
  $original artifacts/deepseek/il-boot-04/build-01

powershell -NoProfile -ExecutionPolicy Bypass -File tools/Capture-IlIntegrityStartup.ps1 `
  -MameExecutable 'E:\Arcade\MAME0266\mame281.exe' `
  -RomDirectory 'E:\Arcade\MAME0266\roms' `
  -OriginalRom $original -VariantRom $original -Variant Original `
  -RunDirectory artifacts/deepseek/il-boot-04/runs/original-02

powershell -NoProfile -ExecutionPolicy Bypass -File tools/Capture-IlIntegrityStartup.ps1 `
  -MameExecutable 'E:\Arcade\MAME0266\mame281.exe' `
  -RomDirectory 'E:\Arcade\MAME0266\roms' `
  -OriginalRom $original `
  -VariantRom artifacts/deepseek/il-boot-04/build-01/edited-repaired.p1 `
  -Variant Repaired -RunDirectory artifacts/deepseek/il-boot-04/runs/repaired-01

powershell -NoProfile -ExecutionPolicy Bypass -File tools/Curate-IlIntegrityStartup.ps1 `
  -ControlRunDirectory artifacts/deepseek/il-boot-04/runs/original-02 `
  -ChangedRunDirectory artifacts/deepseek/il-boot-04/runs/repaired-01 `
  -OriginalRom $original `
  -SourceMapPath artifacts/deepseek/il-boot-04/build-01/source-map.json `
  -BuildReportPath artifacts/deepseek/il-boot-04/build-01/build-report.json `
  -OutputPath evidence/mpu4/integrity/il-integrity-startup.json
```

## Boundaries

This is one natural cold-reset observation per image. It stops at the first
`76C7` entry and does not observe the first token fetch, 9ED9 execution,
attract/credit/input/reel/payout behaviour, randomness, timing equivalence or
physical hardware. It does not promote the existing synthetic 9ED9 invocation
to natural gameplay evidence. The intervening startup reset remains
unexplained. Physical MPU4 compatibility remains a separate required test.

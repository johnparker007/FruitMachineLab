# Independent MAME invocation of original and changed 9ED9

17 October 2026. Bounded B3 increment. This note records a synthetic, isolated
invocation of the checked `9ED9` definition in MAME's unchanged original threaded
interpreter. It compares the original literal `FF80` with the C#-emitted `FF00`
replacement at `9EDC`. It is not natural reset, gameplay or hardware evidence.

## Images and classification

- Original: `a6ls.p1`, 65536 bytes, SHA1
  `402d1518bb78fdc489b06c2aabc771e5ce151847`.
- Changed: emitted by the existing C#
  `bias-word-signed-value-9ed9.vm.json` definition through
  `WithLiteral(0, 0xFF00)` and `Apply(original)`. Length 65536, SHA1
  `51e81cc5f41da2aa659a4d14d277e9e78614eb6b`, SHA256
  `a99d96f8ea8b4770d2d3828125f25894e831726fe44a79a37e0871faba135ed2`.
- Exactly one byte differs from the original: `9EDC`, `80` -> `00`. The runtime
  span is `795BFF80787E795BFF807AAF792F` for the original and
  `795BFF00787E795BFF807AAF792F` for the changed image.
- **Synthetic:** each case starts in an isolated fresh directory, copies one
  image into `roms/m4addr/a6ls.p1`, sets PC/registers/RAM explicitly, masks
  interrupts with `CC=50`, and stops after the word returns. No reset, input
  playback, save state or natural boot is used.

## Invocation contract

Observed original word headers are `9ED7 -> 00F8` (nested-definition trampoline),
`795B -> 795D`, `787E -> 7880`, `7AAF -> 7AB1`, `792F -> 7931`. RAM `F8..FF` is
seeded only by copying the original ROM template `7927..792E`
(`3420 3184 AEA1 6E91`). The caller stream at RAM `0780` is the word header
`9ED7` followed by sentinel `792F`. `U=0600` holds the input word; `S=0700`;
`Y=0780`; dispatch starts at `PC=00FC`. Execution enters the original body at
`Y=9EDB`, pushes the return cursor `0782`, executes `9ED9..9EE6`, and stops at
`PC=7933` after `PULS Y`. At that point `U=0600`, `S=0700`, `Y=0782` and the
saved return word at `06FE` is `0782`.

The changed image was not naturally booted. Its firmware checksum fields were not
regenerated, and no natural-reset or integrity-bypass claim is made. The
existing award-only repair tool was not reused or widened.

## Independent observations

Ten fresh MAME 0.281 runs (two images, five declared inputs) all exited 0. The
result is the word at `U=0600` after return; stack and frame values are the same
on every row.

| Image | Input | Result | U | S | Return frame |
| --- | --- | --- | --- | --- | --- |
| Original | `0000` | `0000` | `0600` | `0700` | `0782` |
| Original | `0080` | `FF80` | `0600` | `0700` | `0782` |
| Original | `0100` | `FF00` | `0600` | `0700` | `0782` |
| Original | `FFFF` | `00FF` | `0600` | `0700` | `0782` |
| Original | `8000` | `8000` | `0600` | `0700` | `0782` |
| Changed | `0000` | `0080` | `0600` | `0700` | `0782` |
| Changed | `0080` | `0000` | `0600` | `0700` | `0782` |
| Changed | `0100` | `FF80` | `0600` | `0700` | `0782` |
| Changed | `FFFF` | `017F` | `0600` | `0700` | `0782` |
| Changed | `8000` | `8080` | `0600` | `0700` | `0782` |

All ten MAME results match the results documented for the same C# definition;
the comparison was made only after capture. All five declared inputs differ
between original and changed images, so the changed operand is observable rather
than masked by another path. The full stack/frame contract (`U`, `S`, return
word, `Y`, stop PC) is unchanged across all cases.

## Negative controls

The curator re-read every raw log, exit code, copied-image hash and provenance
record. It rejected an in-memory wrong result (`Original/0080=0000` against
documented `FF80`), a temporary changed image with an extra changed byte, and a
natural-reset classification. See `evidence/mpu4/collection/vm-definition-9ed9-invocation.json`.

## Reproduction

```powershell
dotnet run --project tools/FruitMachineLab.VmDefinitionImage -- `
  evidence/mpu4/definitions/bias-word-signed-value-9ed9.vm.json `
  <original-a6ls.p1> artifacts/deepseek/general-14/roms

powershell -NoProfile -File tools/Capture-VmDefinitionLiteralInvocation.ps1 `
  -MameExecutable <mame281.exe> -RomDirectory <roms> `
  -OriginalRom <original-a6ls.p1> `
  -ChangedRom artifacts/deepseek/general-14/roms/changed-9edc.p1 `
  -RunDirectory artifacts/deepseek/general-14/mame

powershell -NoProfile -File tools/Curate-VmDefinitionLiteralInvocation.ps1 `
  -RunDirectory artifacts/deepseek/general-14/mame `
  -OriginalRom <original-a6ls.p1> `
  -ChangedRom artifacts/deepseek/general-14/roms/changed-9edc.p1 `
  -OutputPath evidence/mpu4/collection/vm-definition-9ed9-invocation.json
```

## Boundaries

This demonstrates one in-place word literal change in the original threaded
interpreter under synthetic entry. It does not establish natural reset with the
changed image, modified integrity fields, gameplay reachability, relocation,
shared-body ownership, general ROM editing or physical hardware behaviour. B3
remains open for natural execution and the broader replacement contract.

The recorded cases are now checked by three permanent headless groups, and the
emitter enforces its fixed original identity, exact `9ED9` span/token contract
and only-`9EDC` edit before any output is written. See
[VM definition image CLI and permanent checks](VM-DEFINITION-IMAGE-CLI-SAFETY-PASS.md).

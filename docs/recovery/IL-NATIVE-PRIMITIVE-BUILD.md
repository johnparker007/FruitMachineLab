# Bounded IL native-primitive build

Status: **static compiled and integrity-repaired only; not executed.**
Task `il-native-primitive-build-45` starts from `main`
`2729559b806dc9c6796fb0434fea301aa858031d` and implements exactly one corrected
task44 proposal: direct token cell `1010` = `1012`, native handler `1012-101A`,
and the single same-size caller token replacement `9ED7 -> 1010` at `9F14`.
Native C# gameplay remains frozen and no MAME run is included.

Machine-readable metadata:
`evidence/mpu4/integrity/il-native-primitive-build.json`.

## Corrected contract

| Item | Value |
| --- | --- |
| ROM | `a6ls.p1`, 65536 bytes |
| SHA1 | `402d1518bb78fdc489b06c2aabc771e5ce151847` |
| SHA256 | `ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c` |
| Approved range | `1010-13EF`, bank 0, expected `FF` |
| Guards / protected | `1000-100F`, `13F0-13FF`; `1000-1003` protected |
| Allocation | `1010-101A` inclusive, 11 bytes, all original `FF` |
| Token cell | `1010-1011` = `1012` |
| Native handler | `1012-101A` = `ECC4C38000EDC40EFC` |
| Instructions | `1012` `LDD ,U`; `1014` `ADDD #$8000`; `1017` `STD ,U`; `1019` `JMP $00FC` |
| Caller patch | `9F14-9F15`: `9ED7 -> 1010` |
| Preserved | original `9ED7`/`9ED9`, other caller bytes, guards, protected cells, `1400` neighbour |

Dispatch is modelled explicitly as `C` = stream address `9F14`, `T = w@C = 1010`,
`H = w@T = 1012`. After `LDX ,Y++` and `JMP [,X++]`, `PC=H=1012`, `X=T+2=1012`
and `Y=C+2=9F16`. The native pointer cell is **not** a `00F8` composite header;
the handler has no `PSHS`/`PULS` and no `792F` return token.

## Semantics

The word is `n -- (n + 8000h) mod 10000h`, one 16-bit in-place data-stack cell.
`U`, `S` and `Y` are unchanged; `D` is clobbered. `LDD` defines `N/Z`, clears
`V`, preserves `H/C`; `ADDD` defines `N/Z/V/C`, preserves `H`; `STD` defines
`N/Z`, clears `V`, preserves `H/C`; `JMP` preserves all flags. `H` is neither
defined nor asserted. The observed-input `0000` prediction is `8000` at the
handler, then `FFFF` after `75A9`; this is an intentional behaviour change and is
not original `9ED9` preservation or full-game proof.

## Exact result

| Item | Value |
| --- | --- |
| Unrepaired SHA1 / SHA256 | `556A219993D27FA954ADBB741FB64868F1EB250B` / `26CDB03C3659337D1993F44167D7DD077AFDC78C3C030CABB73F94C977C6C8BF` |
| Integrity fields | `3E761E2605 -> E93F3C61B5` |
| Final changed offsets | 18: `1010-101A`, `9F14-9F15`, `FFD1-FFD5` |
| Output SHA1 | `22BF419CF68F243169F05193B0E1AAF708D07707` |
| Output SHA256 | `67E9390B8CD5EB941E1928F5E38129DF265207536002B6304C2A3B413E9B3AA8` |

The build starts from the original ROM, not the earlier composite image, so this
is an alternative image rather than a co-allocation with the composite word.

## Implementation

`src/FruitMachineLab.Il/NativePrimitiveWordBuilder.cs` validates the exact
identity, original `9ED9` definition, caller/successor and parent context, runtime
dispatch template and all 11 allocation `FF` bytes. It reuses the bounded
allocator/emitter unchanged, patches only `9F14`, invokes the separate
`VmIlIntegrity.RepairNativePrimitive` wrapper and checks the exact payload,
handler ending, 18-offset diff, fields and image hashes. Its result owns cloned
images/payload/diffs, exposes read-only offset/change collections and returns a
fresh defensive copy of the integrity report on every access.

`src/FruitMachineLab.Il/NativePrimitiveSourceMap.cs` maps the token cell, all
handler bytes, the caller token and successor. It records the `C/T/H` dispatch
arithmetic, handler boundaries `1012/1014/1017/1019`, dispatcher rejoin `00FC`
with `Y=9F16`, the `75A9` successor, the static outer return context and twelve
`static_prediction_not_execution` phases. Entries, instructions and phases are
`ReadOnlyCollection<T>` wrappers; nested records are immutable. No `H` value is
asserted.

## Verification

Observed commands and exits:

```powershell
dotnet build FruitMachineLab.Headless.sln --ignore-failed-sources                  # 0
dotnet run --project tests/FruitMachineLab.IlVerification --no-build -- `
  artifacts/deepseek/general-14/roms/original.p1 `
  artifacts/deepseek/il-native-primitive-build-45/il-verifier-02                   # 0
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .            # 0, 417 groups
dotnet build FruitMachineLab.sln --ignore-failed-sources                           # 0
dotnet build tools/FruitMachineLab.IlNativePrimitiveBuild/...csproj                 # 0
powershell -NoProfile -ExecutionPolicy Bypass -File `
  artifacts/deepseek/il-native-primitive-build-45/cli-test.ps1 `
  -OriginalRom artifacts/deepseek/general-14/roms/original.p1                      # 0
```

Existing IL groups remain 20 (`9ED9`), 9 (`9A64`), 15 (allocator), 14 (emitter)
and 9 (composite). The new native-primitive suite adds 9 groups covering the
exact token/handler/caller, independent 18-offset diff, independent ordered
checksum, `C/T/H` map model, identity/caller/payload/range/guard negatives,
determinism, owned-buffer/report aliases and read-only nested map mutation. The
full verifier remains 417 groups.

The standalone CLI writes `native-unrepaired.p1`, `native-repaired.p1`,
`native-primitive-source-map.json` and `build-report.json` create-only. The CLI
test also covers a deterministic repeat, wrong identity, wrong length, an
existing output directory with a preserved sentinel, an output path that is a
file, missing arguments and no output directory after rejected builds. Private
outputs stay under `artifacts/deepseek/il-native-primitive-build-45/`; no ROM
binary is tracked.

## Boundaries

Proved at build level: the direct token/handler bytes, the single `9F14` caller
replacement, the exact 18-offset final diff, ordered field regeneration and a
map bound to the exact output hash.

Not proved: direct native instruction execution at `1012`, natural boot or
gameplay, the predicted `8000 -> FFFF` downstream path, preservation of original
`9F12` behaviour, `H`, general dictionary/header decoding, relocation, banking,
physical MPU4 compatibility. No MAME run or capture was made. The next boundary
is a separately dispatched natural fresh-boot observation of the direct handler,
dispatcher rejoin and `75A9` path.

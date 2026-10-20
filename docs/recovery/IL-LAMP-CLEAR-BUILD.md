# IL lamp-clear-pattern word build

Status: **static compiled and verified only. Not executed, not booted and not
accepted.** This report records the bounded task `il-lamp-clear-build-71` on base
`main` `95aadbe63c18a134d8af2577038c94f57c11afe3`. It implements a dedicated
pattern-`80` clear variant of the accepted 24-byte `1010-1027` lamp word. It does
not claim natural execution, a future characteriser response, visible lamp
output, M5 completion, a general linker/compiler or hardware compatibility. The
native C# gameplay executor remains frozen and unused.

## Design

The clear variant keeps the same allocation, header, body layout, shared service
and caller redirect as the reviewed `8F` word. Only the inline pattern operand at
`1023` changes from `8F` to `80`.

```text
1010-1011 : 00F8
1012-1015 : 795B FF80        original 9ED9 prefix
1016-1017 : 787E             add
1018-101B : 795B FF80        original 9ED9 prefix
101C-101D : 7AAF             xor
101E-1020 : 7963 00          inline byte literal: index 0
1021-1023 : 7963 80          inline byte literal: pattern 80
1024-1025 : 9C44             shared lamp call, zero caller operands
1026-1027 : 792F             one final return
9F14-9F15 : 9ED7 -> 1010     same-size caller redirect
```

Exact clear payload `1010..1027`:

```text
00F8795BFF80787E795BFF807AAF7963007963809C44792F
```

The `8F` payload differs only at `1023` (`8F` -> `80`). Bit-for-bit everything
else in the 24-byte payload is identical, including the two original `FF` holes
at `1014`/`101A`. The caller successor at `9F16` remains `75A9`; original
`9ED7=00F8` and `9ED9` body bytes are preserved. The approved `1010-13EF` range
uses 24 bytes and leaves **968** bytes; guards `1000-100F` and `13F0-13FF` are
preserved.

Nodes and operands remain 8 and 4. The pattern operand at `1023` is `0080`; the
other operands are `1014=FF80`, `101A=FF80` and `1020=00`. The shared call is
still `9C44 -> 9B15`, service pointer `9C46=72BF`, shared body `9B18`, and the
single final `792F` is at `1026`.

## Clear semantics

- Table index `0` selects logical ID `78` and mask `01`.
- Pattern `80` has low nibble `0`, so all four frame banks take the clear branch.
- The original `49C5` service clears the mask bit in each bank:
  `after = before & ~01`. This was checked for **all 256** possible pre-existing
  frame bytes: only mask bit `01` can change; an already-clear bit is unchanged.
- The upper nibble `8` is not consumed by the four `LSRA` operations in this
  exact path. Its meaning outside this path is not generalized.
- The observed natural response `00` derives column `15` through
  `((response0803 XOR 78) & 78) >> 3`, giving `010F/011F/012F/013F`. That is a
  **static prediction only**. A future run must use the response actually read at
  `0803`; future response, column and target addresses are not assumed.
- A frame-RAM change is not proof of physical lamp output. No visible transition,
  full characteriser response or hardware claim is made.

## Integrity

`RepairLampClearPattern` validates the exact original identity, the literal
24-byte clear allocation, the `FF` original allocation, the two caller bytes,
the original caller `9ED7`, protected spans and the unchanged active fields. It
recomputes the ordered checker sequence and writes only the permitted field
locations `FFD1..FFD5`.

The expected unrepaired diff is derived from the literal payload and caller; the
actual result is the 24 offsets `1010-1013, 1015-1019, 101B-1027, 9F14-9F15`.
The expected final diff is the union of that literal patch with the independently
computed changed field locations. The actual final result is the same 24 offsets
plus `FFD1..FFD5` (29 offsets). This was not assumed: the builder and the
independent worker checker derive it, and neither forces all five field values to
change.

The repaired fields are `E93F3C61B5`. Because the active integrity record covers
`1400-FFFF` and that range is unchanged by this extension/caller patch, the clear
variant coincidentally produces the same field values as the reviewed `8F` word.
That equality is an observed consequence of the ordered computation, not a copied
or assumed golden. The original `8F` fields and fixtures remain untouched.

## Exact build result

| Item | Value |
| --- | --- |
| Original SHA1 / SHA256 | `402D1518BB78FDC489B06C2AABC771E5CE151847` / `EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C` |
| Unrepaired SHA1 / SHA256 | `BD7572208D18EAA98B8E49C5FC1FEC4BBDF9C351` / `0CDA847916A051B09C187C54AD028F79A65A554CC592E0CF0580A0291A76AAEE` |
| Repaired SHA1 / SHA256 | `F2083249845955D91945E589807C22E730D78FC3` / `347D475E20C194F374DF85A04894BC68D89E05043CA89C5B031316868240EB88` |
| Unrepaired / final changes | 24 / 29 (derived from the literal patch and computed repair) |
| Original / repaired fields | `3E761E2605` / `E93F3C61B5` |
| Repair-only changes | `FFD1`, `FFD2`, `FFD3`, `FFD4`, `FFD5` |
| Allocation / remaining | 24 bytes / 968 of the approved 992 bytes |
| Clear source-map SHA256 | `1845ED2A98B8347B8618D7E9A6E7AFD68B3CF14532C20268AAE273DD782E83B1` |
| Clear build-report SHA256 | `7AB2A92DF65F77E822FD92F30D8B966E96CA3C762873201F438FFAFD2011416D` |

## Builder, source map and CLI

- `LampPatternWordBuilder.BuildClearPattern` is a separate entry point. The old
  `Build` entry and the reviewed `8F` constants/behavior are unchanged.
- `LampPatternWordSourceMap` accepts a narrow internal variant descriptor. For
  `8F` it serializes exactly the previous map (file SHA256 remains
  `42F0C4BB886313F5B1A7F78991A2EFD09351CC1912DF7A58EA6E3BE7E8E84163`).
- The clear map is bound to the clear output SHA256 and carries the clear
  classification `static_lamp_clear_pattern_map_bound_to_exact_output_sha256`,
  44 entries, 8 nodes, 4 inline operands, 43 phases and 12 boundaries. Operand
  `1023` is `0080`; `shared-after-rotate` and `shared-after-swap` exit with
  `X=0080`; all runtime `00FC` prefetch PC/Y distinctions and the accepted
  `U=066E/S=0798` relative stack contract are preserved.
- `VmIlIntegrity.RepairLampClearPattern` is separate from `RepairLampPattern`.
  The old `RepairLampPattern` and `8F` fields `E93F3C61B5` are unchanged.
- `tools/FruitMachineLab.IlLampClearPatternBuild` is a create-only CLI with
  distinct outputs: `lamp-clear-unrepaired.p1`, `lamp-clear-repaired.p1`,
  `lamp-clear-pattern-source-map.json` and `build-report.json`. The old lamp CLI
  and its outputs are unchanged.
- The legacy `8F` natural-lamp observer is frozen. Its `PrepareOnly` identity gate
  rejects the clear image before creating a run directory or launching MAME.

## Verification performed

```powershell
dotnet build FruitMachineLab.Headless.sln --ignore-failed-sources
dotnet build tools/FruitMachineLab.IlLampClearPatternBuild/FruitMachineLab.IlLampClearPatternBuild.csproj --ignore-failed-sources
dotnet run --project tools/FruitMachineLab.IlLampClearPatternBuild --no-build -- `
  <original-a6ls.p1> <fresh-output-directory>
dotnet run --project tests/FruitMachineLab.IlVerification --no-build -- `
  <original-a6ls.p1> <fresh-verification-root>
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .
dotnet build FruitMachineLab.sln --ignore-failed-sources
powershell -NoProfile -ExecutionPolicy Bypass -File `
  tests/worker/Test-IlLampClearPatternBuild.ps1 `
  -OriginalRom <original-a6ls.p1> -OutputRoot <fresh-private-root>
powershell -NoProfile -ExecutionPolicy Bypass -File `
  tests/worker/Test-IlLampPatternBuild.ps1 `
  -OriginalRom <original-a6ls.p1> -OutputRoot <fresh-private-root>
```

Recorded results:

- Headless and Windows UI builds: 0 warnings, 0 errors.
- Independent clear IL group: **21/21** checks, status `pass`.
- Existing `8F` IL group: **26/26** checks, status `pass`; output SHA256 still
  `631F6C252A5DF359525553F7D14A4FC8CEF965C76BBECA759EAAA862A3FAD4DE` and fields
  `E93F3C61B5`.
- Independent worker checker: **33/33** checks, including literal payload/offsets,
  independent ordered integrity recomputation, preserved spans, map binding,
  two deterministic fresh CLI directories, old `8F` goldens, CLI negatives and
  the legacy `PrepareOnly` rejection.
- Existing `8F` worker checker: **24/24** checks, status `pass`.
- Full dependency-free verifier: **417 groups**, exit 0.
- Legacy `PrepareOnly` gate: exit 1, rejected the clear built-image identity,
  created no run directory and launched no MAME.
- The clear CLI produced byte-identical outputs in two fresh directories.
- The original ROM hash was unchanged after every control.

## Limitations

- The clear word has not been naturally executed. The `0803` response, column,
  targets and any visible `1 -> 0` transition remain unobserved.
- Changing frame RAM is not proof of physical lamp output. Physical orientation
  and hardware compatibility remain separate.
- The reused `9C44/49C5` service still reads DP-relative `00F1`, conditionally
  writes `00F1/080C`, masks IRQ/FIRQ around `0801/0802/0803`, moves U/S frames and
  changes A/CC net. Broad caller safety remains unproved.
- M5 remains open. This is one clear variant plus one same-size caller redirect;
  it is not a second simultaneous modification, native hook or general
  linker/compiler claim.
- No MAME boot, capture, synthetic invocation, save state, debugger write,
  gameplay, paid window or hardware validation is included.

The next boundary is a separately dispatched fresh natural `9F14` capture of the
exact clear image, using a clear-specific observer with explicit clear hashes and
write predicate. The legacy `8F` observer/profile must not be weakened or
auto-detected; it correctly rejects this image.

# IL larger replacement build

Status: **static compiled and verified only. Not executed, not booted and not
accepted.** This report records the bounded task `il-larger-replacement-build-50`
on base `main` `d12ce8315690c6a4ac56427defce3bd45e6d1f9a`. It implements the
corrected task49 reachable-body contract. It does not claim natural execution,
gameplay, a paid window, relocation, banking or hardware compatibility. The
native C# gameplay executor remains frozen and unused.

## Corrected design

The rejected task48 payload retained the original terminal `792F` and appended a
literal/add after it, so the added nodes were unreachable. The corrected body
replaces that terminal return with push `0001`, add and **one final** `792F`:

```text
1010-1011 : 00F8
1012-1025 : 795BFF80787E795BFF807AAF795B0001787E792F   (20 bytes, 7 nodes)
1010-1025 : 00F8795BFF80787E795BFF807AAF795B0001787E792F (22 bytes)
9F14-9F15 : 9ED7 -> 1010
```

The image is built from the exact original ROM, not from the accepted composite
or native-primitive output. Only the same-size `9F14` caller token is changed
outside the extension allocation.

## Nodes, operands, stack and reachability

| Node | Address | Bytes | Token | Operand | Handler | U delta | Depth after |
| ---: | --- | --- | --- | --- | --- | ---: | ---: |
| 0 | `1012` | `795B FF80` | `795B` | `1014 = FF80` | `795D` | -2 | 2 |
| 1 | `1016` | `787E` | `787E` | - | `7880` | +2 | 1 |
| 2 | `1018` | `795B FF80` | `795B` | `101A = FF80` | `795D` | -2 | 2 |
| 3 | `101C` | `7AAF` | `7AAF` | - | `7AB1` | +2 | 1 |
| 4 | `101E` | `795B 0001` | `795B` | `1020 = 0001` | `795D` | -2 | 2 |
| 5 | `1022` | `787E` | `787E` | - | `7880` | +2 | 1 |
| 6 | `1024` | `792F` | `792F` | - | `7931` | 0 | 1 |

The flat walk visits all seven nodes once in address order. Node 6 is the only
`792F` and the final two bytes; there is no branch and no earlier return. Body
net `U` delta is `0`, entry and exit depth are both `1`, and `S` is unchanged
inside the body. The `00F8` trampoline supplies `S -2`, the return handler
`PULS Y` restores `S +2`, and the whole call nets `S 0` with `Y` restored to
`9F16`. There is no nested call.

Task48 remains a meaningful negative control. Its body decodes as eight nodes,
but its first `792F` is at `101E`; the suffix nodes at `1020`, `1024` and `1026`
are unreachable. The builder rejects it by the flat reachability rule and
reports `returnAddress=101E` with
`unreachableAddresses=[1020,1024,1026]`. The rejection is not a hash mismatch.

## Static vectors

All arithmetic is 16-bit modulo `10000h`:

```text
copied 9ED9 non-return ops: ((x + FF80h) mod 10000h) XOR FF80h
corrected callee exit:      (copied value + 0001h) mod 10000h
after caller successor 75A9: 0000h if bit15=0, else FFFFh
```

| Input | Copied value | Callee exit | After `75A9` |
| --- | ---: | ---: | ---: |
| `0000` | `0000` | `0001` | `0000` |
| `0001` | `0001` | `0002` | `0000` |
| `7FFF` | `80FF` | `8100` | `FFFF` |
| `8000` | `8000` | `8001` | `FFFF` |
| `FFFF` | `00FF` | `0100` | `0000` |

For the naturally cited `0000` input the callee exit is `0001`; `75A9` then
normalizes that positive value to `0000`, so the parent result may remain
`0000`. The `0001` callee-exit value is a static prediction, not an observation.

## Builder and integrity wrapper

`LargerReplacementBuilder.Build` validates the exact original identity and the
certified `9ED7`/`9ED9` source, composes and re-parses the corrected body, checks
the seven nodes and three inline operands, applies the flat reachability rule,
validates the stack and vectors, allocates exactly `1010-1025`, emits the
payload through the existing bounded allocator/emitter, and performs only the
single `9F14` `9ED7 -> 1010` caller patch.

`VmIlIntegrity.RepairLargerReplacement` is a new additive wrapper with the new
`VmIlLargerReplacementPatchSpec`. It validates the exact 22-byte allocation,
payload, caller bytes, original `FF` contents and unchanged fields, recomputes
`FFD1-FFD5` in the recovered order, requires fields `E93F3C61B5`, and requires
the repair diff to be exactly `FFD1-FFD5`. Existing `Repair`, `RepairComposite`
and `RepairNativePrimitive` are unchanged.

## Exact build result

| Item | Value |
| --- | --- |
| Unrepaired SHA1 / SHA256 | `5ACD11F897005A9C80C4931460847BC4E6414FA5` / `F8B0CAAEFF6EA6ACF9B11F9E9CEF39D2F9A4346EBC11C5FB8245D76D40E235B9` |
| Repaired SHA1 / SHA256 | `7D81C9828A8A8C882861151E84B676AE05D272BF` / `F693D70A73F1C12857CD64CA9DB9D68DE9BBC1888101ABC283FA2752C094B523` |
| Unrepaired changes | exactly 22: the 20 changed payload bytes plus `9F14-9F15` |
| Unchanged payload bytes | `1014` and `101A` remain original `FF` |
| Final changes | exactly 27: the 22 above plus `FFD1-FFD5` |
| Original / repaired fields | `3E761E2605` / `E93F3C61B5` |
| Repair-only changes | `FFD1`, `FFD2`, `FFD3`, `FFD4`, `FFD5` |

Preserved spans include the original `9ED7` header and `9ED9` body, other
callers, caller bytes after `9F16`, parent context `9F3B-9F40`, the
`1000-100F`/`13F0-13FF` guards, protected `1000-1003`, unallocated
`1026-13EF`, outer gate `719B` and dispatch template `7927-792E`.

## Source map

`LargerReplacementSourceMap` is bound to the final image SHA256 and contains 30
per-byte entries, seven nodes, three inline operands and exactly 17 static
phases. Every phase is labelled `static_prediction_not_execution`:

1. caller dispatch before `00FC` (`Y=9F14`, token `9ED7 -> 1010`);
2. `00F8` trampoline entry (`X=1012`, `Y=9F16`, saved cursor `9F16`);
3. seven body prefetches and six non-return handler phases;
4. the node 6 prefetch (`Y=1024`, token `792F`);
5. the return handler (`Y=1026`, saved cursor `9F16`);
6. the post-return prefetch (`Y=9F16`, token `75A9`).

`ValidateBuild`, `Resolve` and `ValidateImage` reject stale hashes, unknown
addresses and tampered images. The map, node, operand and phase collections are
read-only wrappers.

## CLI

The standalone create-only CLI takes exactly two arguments:

```powershell
dotnet build tools/FruitMachineLab.IlLargerReplacementBuild/FruitMachineLab.IlLargerReplacementBuild.csproj --ignore-failed-sources
dotnet run --project tools/FruitMachineLab.IlLargerReplacementBuild --no-build -- `
  <original-a6ls.p1> <fresh-output-directory>
```

It validates the original length/SHA1/SHA256 before creating anything, rejects a
missing input, a directory input, an input/output alias, an existing output
directory or an output path that is a file, and writes only
`larger-unrepaired.p1`, `larger-repaired.p1`,
`larger-replacement-source-map.json` and `build-report.json`. Outputs are
create-only, deterministic across fresh directories, and read back before
success. A failed validation leaves no output.

## Verification performed

```powershell
dotnet build FruitMachineLab.Headless.sln --ignore-failed-sources
dotnet run --project tests/FruitMachineLab.IlVerification --no-build -- `
  <original-a6ls.p1> <fresh-verification-root>
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .
dotnet build FruitMachineLab.sln --ignore-failed-sources
powershell -NoProfile -ExecutionPolicy Bypass -File `
  tests/worker/Test-IlLargerReplacementBuild.ps1 `
  -OriginalRom <original-a6ls.p1> -OutputRoot <fresh-private-root>
```

Results: headless and Windows UI builds succeeded with zero warnings/errors; the
IL verifier passed the existing 20/9/15/14/9/9 groups plus 11 new
larger-replacement groups; the full verifier passed **417 groups** unchanged; the
worker CLI/static checker passed **21 checks**. The final private CLI outputs
have the map SHA256
`F638EAC9DD5D2F1E719ED00BA63C80C59079CE5EB2AA2148F7373E50F1E91F1F` and
build-report SHA256
`216BF0CF945DB19A0BC702273532D8D8B7DDBB3761EEC3CC0CC40D6DA02C1CE1`.

## Limitations

- The corrected body has not been naturally executed. `0000 -> 0001` at the
  callee exit is a static prediction; `75A9` may normalize it to `0000`.
- The broader purpose of caller `9F12` remains unresolved.
- M3 call-step-over/out is independent. This flat body contains no nested call
  and does not by itself unblock step-over/out.
- No MAME boot, capture, paid-window `EE16/EE22`, gameplay, relocation, banking
  or hardware validation is included.

The next boundary is a separately dispatched natural fresh-boot MAME task after
supervisor review of this static builder. Supervisor review and acceptance are
still pending.

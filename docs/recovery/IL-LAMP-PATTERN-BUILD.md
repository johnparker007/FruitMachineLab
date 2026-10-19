# IL lamp-pattern word build

Status: **static compiled and verified only. Not executed, not booted and not
accepted.** This report records the bounded repair task
`il-lamp-pattern-repair-60` on base `main`
`cbde1a594ede5306e3c9c6406bc430ef913b2fc5`. It preserves the attempt-56/57/59
partial files and follows the corrected `il-lamp-service-audit-55` contract. It implements the
24-byte original-VM lamp-pattern word. It does not claim natural execution, safe
`9F14` service execution, gameplay, M5 completion, a general linker/compiler or
hardware compatibility. The native C# gameplay executor remains frozen and
unused.

## Design

The new word is allocated once at `1010-1027` (24 bytes) inside the approved
`1010-13EF` range. Guards `1000-100F` and `13F0-13FF` are preserved and 968
approved bytes remain. The allocation was original `FF`.

```text
1010-1011 : 00F8
1012-1015 : 795B FF80        original 9ED9 prefix
1016-1017 : 787E             add
1018-101B : 795B FF80        original 9ED9 prefix
101C-101D : 7AAF             xor
101E-1020 : 7963 00          inline byte literal: index 0
1021-1023 : 7963 8F          inline byte literal: pattern 8F
1024-1025 : 9C44             shared lamp call, zero caller operands
1026-1027 : 792F             one final return
9F14-9F15 : 9ED7 -> 1010
```

The image is built from the exact original ROM, not from any prior composite,
native-primitive or larger-replacement output. Only the same-size `9F14` caller
token changes outside the extension allocation.

## Nodes and operands

| Node | Address | Bytes | Token | Operand | Handler | U delta | Depth after |
| ---: | --- | --- | --- | --- | --- | ---: | ---: |
| 0 | `1012` | `795B FF80` | `795B` | `1014 = FF80` word | `795D` | -2 | 2 |
| 1 | `1016` | `787E` | `787E` | - | `7880` | +2 | 1 |
| 2 | `1018` | `795B FF80` | `795B` | `101A = FF80` word | `795D` | -2 | 2 |
| 3 | `101C` | `7AAF` | `7AAF` | - | `7AB1` | +2 | 1 |
| 4 | `101E` | `7963 00` | `7963` | `1020 = 00` byte | `7965` | -2 | 2 |
| 5 | `1021` | `7963 8F` | `7963` | `1023 = 8F` byte | `7965` | -2 | 3 |
| 6 | `1024` | `9C44` | `9C44` | service-owned, zero caller bytes | `9B15` | +4 | 1 |
| 7 | `1026` | `792F` | `792F` | - | `7931` | 0 | 1 |

The two `795B` word operands are at `1014/101A`; the two `7963` byte operands
are at `1020` (index `00`) and `1023` (pattern `8F`). The only `792F` is the
final return at `1026`. All nodes are in reachable address order.

The `7963` cell is `7963..796B = 79654FE6A036060EFC`: the token cell points to
`7965` and the handler is `4FE6A036060EFC` (`CLRA; LDAB ,Y+; PSHU D; JMP $FC`),
consuming exactly one inline byte.

## Shared `9C44` call boundary

`9C44` is a two-byte caller-stream token with **zero** caller operands. Its
original service cell is:

```text
9C44: 9B15 72BF
```

The dispatcher resolves `9C44` to handler `9B15`; the adjacent `9C46` word
`72BF` is service-owned data, not a caller inline operand. The
`handler = token + 2` rule does **not** apply to `9C44`; applying it would
resolve to `9C46` and is rejected by the builder and tests.

Exact original service bytes checked by the builder:

| Span | Bytes |
| --- | --- |
| `9C44..9C47` | `9B1572BF` |
| `9B15..9B17` | `BD796E` |
| `9B18..9B25` | `790D7B6D787E786B7B7D8050792F` |
| `796E..7978` | `3610AEE410AFE431840EFC` |
| `8050..8053` | `779149C5` |
| `7791..77A3` | `370696F127078A0197F1B7080CA641334220D6` |
| `777A..778C` | `3420AD94352096F1270784FE97F1B7080C0EFC` |
| `49C5..4A24` | 96-byte native lamp service |
| `7963..796B` | `79654FE6A036060EFC` |
| `72BF..72EE` | 48-byte logical lamp-ID table |

The shared body returns to the caller's next token `1026`, not to `9C46`.

## Corrected relative stack model

These are static relative derivations from the `9F14` entry context
`U=066E`, `S=0798`; they are **not** transplanted absolute values from the
`B951` capture and are not new live measurements.

| Boundary | U | S |
| --- | ---: | ---: |
| `9F14` caller entry | `066E` | `0798` |
| outer `00F8` body entry | `066E` | `0796` |
| after the two byte literals | `066A` | `0796` |
| shared-body entry `9B18` | `0668` | `0794` |
| after shared add `9B1C` | `066A` | `0794` |
| bridge entry `8050` | `066A` | `0794` |
| after `7791` `PULU D` | `066C` | `0794` |
| after `779E` `LDA 1,U` | `066C` | `0794` |
| after `77A0` `LEAU 2,U` / `77A2` `BRA` | `066E` | `0794` |
| after `777A` `PSHS Y` | `066E` | `0792` |
| JSR entry at `49C5` | `066E` | `0790` |
| after `49C5` `PSHS A,B,X` | `066E` | `078C` |
| after `49CE` `PSHS B` | `066E` | `078B` |
| after `49D0` `PSHS CC` (deepest) | `066E` | `078A` |
| after `49E0` `PULS CC` | `066E` | `078B` |
| after `4A21` `PULS A` | `066E` | `078C` |
| after `4A23` `PULS A,B,X,PC` (native exit) | `066E` | `0792` |
| after `777E` `PULS Y` | `066E` | `0794` |
| shared return handler entry `7931` | `066E` | `0794` |
| shared return to `1026` | `066E` | `0796` |
| outer return handler entry `7931` | `066E` | `0796` |
| outer return to `9F16` | `066E` | `0798` |

The bridge chronology is decoded from the actual ROM instruction order, not
from a cloned stack array. `7791 3706` (`PULU D`) advances `U 066A -> 066C`;
`779E A641` (`LDA 1,U`) reads the retained index without moving `U`; `77A0 3342`
(`LEAU 2,U`) advances `U 066C -> 066E`; only then does `77A2 20D6` (`BRA 777A`)
reach `777A 3420` (`PSHS Y`), `777C AD94` (`JSR [,X]`) and native `49C5 3416`
(`PSHS A,B,X`). The native entry/deepest/exit boundaries are therefore all at
`U=066E`, with `S=0790`, `078A` and `0792`. The earlier attempt-56 model that
invoked the native service at `U=066A` and popped afterwards was wrong.

The phase table records real instruction boundaries, not a copied absolute
capture. Each new body `handler-{i}` phase is the PRE-handler state:
`handler-0` is `PC=795D U=066E S=0796 X=795D Y=1014`, `handler-1` is
`PC=7880 U=066C S=0796 X=7880 Y=1018`, `handler-2` is
`PC=795D U=066E S=0796 X=795D Y=101A`, `handler-3` is
`PC=7AB1 U=066C S=0796 X=7AB1 Y=101E`, `handler-4` is
`PC=7965 U=066E S=0796 X=7965 Y=1020` and `handler-5` is
`PC=7965 U=066C S=0796 X=7965 Y=1023`. The preceding `body-prefetch-{i}`
phases are runtime `PC=00FC` prefetches whose `X` is the previous dispatcher
pointer (`1012` for `body-prefetch-0`, then the prior handler address) and whose
`Y` is the token address.

`shared-handler-entry` is the original `9B15` entry before `JSR 796E` with
`U=066A S=0796 X=9C46 Y=1026`. The trampoline is split into the pre-`PSHU`
boundary at `796E` (`U=066A S=0794`) and the post-`PSHU` boundary at `7970`
(`U=0668 S=0794`). `shared-body-entry` is then the runtime `PC=00FC` prefetch
after `LDX ,S`, `STY ,S`, `LEAY ,X` and the final `JMP $00FC`: `X=Y=9B18`,
token `790D`, not native PC `9B18`. The `shared-after-*` phases are likewise
runtime `00FC` prefetches: `shared-after-fetch-word` is
`X=790F Y=9B1A token=7B6D`, `shared-after-rotate` is
`X=008F Y=9B1C token=787E`, `shared-after-add` is
`X=7880 Y=9B1E token=786B`, `shared-after-fetch-byte` is
`X=786D Y=9B20 token=7B7D`, and `shared-after-swap` is
`X=008F Y=9B22 token=8050`.

The native prologue PCs are the true post-instruction starts: `49C7` after
`49C5 PSHS A,B,X`, `49D0` after `49CE PSHS B` (not mid-instruction `49CF`), and
`49D2` after `49D0 PSHS CC` (not `49D1`). The six saved bytes are split across
`49C5` (four), `49CE` (one) and `49D0` (one); they are not applied as a single
six-byte push at entry. The epilogue records `49E2` after `49E0 PULS CC`,
`4A23` after `4A21 PULS A`, then the `4A23 PULS A,B,X,PC` return to `777E`.
The shared return handler is `PC=7931 X=7931 Y=9B26` (token cell + 2 versus
the Y cursor), the outer return handler is `PC=7931 X=7931 Y=1028`, and the
post-return `00FC` prefetches keep `X=7931`. `shared-prefetch-return` keeps the
restored bridge pointer `X=8052`.

The shared saved cursor is `1026`; the outer saved cursor is `9F16`. The
deepest modeled native prologue stack is `S=078A` (outer 2 + shared 2 + bridge Y
2 + JSR 2 + native prologue 6 = 14 bytes below `0798`), not `078C`. Net `U` and
net `S` are both 0 across the whole call. No stack-headroom, IRQ or full-RAM
claim is made from these addresses.

`49C5` preserves A/B/X and masks IRQ/FIRQ around its `0801/0802/0803` access;
the bridge restores Y, consumes four U bytes and changes A/CC net. The bridge's
`00F1`/`080C` access requires `DP=0`. No arithmetic-register preservation is
claimed.

## Preserved `9ED9` result

The first 12 body bytes are the original `9ED9` prefix. The new literal cells
are consumed by the shared `9C44` call, which pushes no output, leaving the
original result cell at depth 1. Static 16-bit vectors:

| Input | Result |
| --- | ---: |
| `0000` | `0000` |
| `0001` | `0001` |
| `7FFF` | `80FF` |
| `8000` | `8000` |
| `FFFF` | `00FF` |

The service's A/CC changes do not affect the data-stack result; this is a
data-stack preservation statement, not arithmetic-register preservation.

## Predicted lamp effect

Index `0` selects `72BF[0] = 78` (`120`); bit `0`, mask `01`; the map-derived
buffer column is `15`; pattern `8F` has low nibble `F`, so the service is
predicted to set one bit in each of `010F`, `011F`, `012F` and `013F`. This is a
static lamp-effect prediction from the original service and the `72BF` table.
No full characteriser response byte or whole-RAM unchanged state is claimed
from the map.

MAME layout checked by supervisor: feature-grid outputs run `64..69`, `72..77`,
... `120..125` top-to-bottom, and `output = 64 + 8*topRow + column`. `72BF`
index `0` (`output 120`) is therefore bottom-left START in that rendered
layout; no extra ROM table is needed, and the 24 allocation bytes remain code,
not mapping data. This is a local MAME render binding; physical
orientation/hardware remains separate.

## Builder, integrity wrapper and source map

`LampPatternWordBuilder.Build` validates the exact original identity, the
certified `9ED7`/`9ED9` source, the payload, all eight nodes and four operands,
the shared-call cell (`9C44`, not token+2), the exact original service bytes,
the relative stack model, the result vectors, the predicted frame addresses and
the approved allocation. It emits through the existing bounded allocator and
emitter, applies only the `9F14` `9ED7 -> 1010` caller patch, and calls the new
additive `VmIlIntegrity.RepairLampPattern`.

`VmIlIntegrity.RepairLampPattern` validates the exact 24-byte allocation,
payload, caller bytes, original `FF` contents and unchanged fields, recomputes
`FFD1-FFD5` in the recovered order, requires fields `E93F3C61B5`, and requires
the repair diff to be exactly `FFD1-FFD5`. Existing `Repair`, `RepairComposite`,
`RepairNativePrimitive` and `RepairLargerReplacement` are unchanged.

`LampPatternSourceMap` is bound to the final image SHA256 and contains 44
per-byte entries, eight nodes, four inline operands, 43 static phases and 12
service boundaries. The phases and boundaries distinguish the shared `9C44`
call (handler `9B15`, service pointer `9C46 = 72BF`, shared body `9B18`) from a
caller inline operand, and record the corrected relative U/S values in actual
instruction order, including `PULU D`, `LDA 1,U`, `LEAU 2,U`, `BRA`, `PSHS Y`,
`JSR`, native prologue, native return and `PULS Y`. Every phase is labelled
`static_prediction_not_execution`.

`PredictedFrameAddresses` is exposed only through a read-only view over a
private snapshot; the static contract snapshots caller-supplied vectors and
stack steps in both its constructor and `with` initializers. Build-result
buffers are defensive copies.

## Exact build result

| Item | Value |
| --- | --- |
| Unrepaired SHA1 / SHA256 | `FED6058A6BF8D2627068BAC01D77EE0D279B5E46` / `3D94F6E2908D9C57C2C20EEDE897A0A19D4C74BA88464053554C0558C25ADDE3` |
| Repaired SHA1 / SHA256 | `9F060102692BB31E03F992E95E38F4F59BEE1129` / `631F6C252A5DF359525553F7D14A4FC8CEF965C76BBECA759EAAA862A3FAD4DE` |
| Unrepaired changes | exactly 24: 22 changed payload bytes plus `9F14-9F15` |
| Unchanged payload bytes | `1014` and `101A` remain original `FF` |
| Final changes | exactly 29: the 24 above plus `FFD1-FFD5` |
| Original / repaired fields | `3E761E2605` / `E93F3C61B5` |
| Repair-only changes | `FFD1`, `FFD2`, `FFD3`, `FFD4`, `FFD5` |
| Allocation / remaining | 24 bytes / 968 of the approved 992 bytes |

Preserved spans include the original `9ED7` header and `9ED9` body, the shared
service cell and body, the bridge and native service, the `72BF` table, other
callers, caller bytes after `9F16`, parent context `9F3B-9F40`, the
`1000-100F`/`13F0-13FF` guards, protected `1000-1003`, unallocated
`1028-13EF`, outer gate `719B` and dispatch template `7927-792E`.

## CLI

The standalone create-only CLI takes exactly two arguments:

```powershell
dotnet build tools/FruitMachineLab.IlLampPatternBuild/FruitMachineLab.IlLampPatternBuild.csproj --ignore-failed-sources
dotnet run --project tools/FruitMachineLab.IlLampPatternBuild --no-build -- `
  <original-a6ls.p1> <fresh-output-directory>
```

It validates the original length/SHA1/SHA256 before creating anything, rejects a
missing input, a directory input, an input/output alias, an existing output
directory or an output path that is a file, and writes only
`lamp-unrepaired.p1`, `lamp-repaired.p1`, `lamp-pattern-source-map.json` and
`build-report.json`. Outputs are create-only, deterministic across fresh
directories, and read back before success. A failed validation leaves no output.

## Verification performed

```powershell
dotnet build FruitMachineLab.Headless.sln --ignore-failed-sources
dotnet run --project tests/FruitMachineLab.IlVerification --no-build -- `
  <original-a6ls.p1> <fresh-verification-root>
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .
dotnet build FruitMachineLab.sln --ignore-failed-sources
powershell -NoProfile -ExecutionPolicy Bypass -File `
  tests/worker/Test-IlLampPatternBuild.ps1 `
  -OriginalRom <original-a6ls.p1> -OutputRoot <fresh-private-root>
```

The new independent IL verification group passed **25/25** checks, including an
independent ROM-byte-derived phase oracle that replays the actual handler,
`796E`, shared-body, bridge and `49C5` instruction order; PRE-handler phase
checks for all six new body handlers; the `9B15` PRE-JSR and `796E`
PRE/POST-`PSHU` boundaries; the split native prologue and epilogue; saved
cursors `1026`/`9F16`; actual-ROM bridge-order decoding; wrong
identity/payload/header/early-return/literal-order/extra-operand; truncated
bridge; wrong `handler = token + 2`; wrong relative U model; old
handler-poststate, old shared PRE-JSR poststate, wrong X, wrong saved cursor and
native-entry-at-deepest-stack controls; mutable globals and contract lists;
guard/preserved-output tamper; allocation overflow; unapproved range and stale
map controls. The worker CLI/static checker passed **24/24** checks with no
failures, including 43 map phases and the new phase-boundary assertions, and
the focused CLI was byte-deterministic across fresh directories. The existing
IL groups were preserved and the full verifier passed **417 groups**. Headless
and Windows UI builds succeeded with zero warnings/errors. Exact final hashes
are recorded in the companion evidence file.

## Limitations

- The new word has not been naturally executed. The `010F/011F/012F/013F` frame
  update is a static prediction; no full characteriser response is claimed.
- Natural safety of the `9C44/49C5` characteriser/PIA/scratch/IRQ side effects
  at the `9F14` caller is **unproved**. The existing `9F14` evidence did not call
  `9C44`, and the existing lamp capture is at `B951`. The bridge's `080C` write
  is not covered by `49C5`'s F/I mask and the caller's CC is `C4` (I=0, F=1).
  The service reads `00F1`, conditionally writes `00F1/080C`, masks IRQ/FIRQ
  around its `0801/0802/0803` access, moves U/S frames and changes A/CC net.
  No whole-RAM unchanged or safe-caller claim is made.
- MAME layout checked by supervisor: feature-grid outputs run `64..69`,
  `72..77`, ... `120..125` top-to-bottom with `output = 64 + 8*topRow +
  column`, so `72BF` index `0` (`120`) is bottom-left START. Physical
  orientation and visible-glass identity/hardware remain separate and unproved.
- M5 remains open. This is one new definition plus one same-size caller
  redirect; it is not a second simultaneous modification, native hook or
  general linker/compiler claim.
- No MAME boot, capture, synthetic invocation, save state, debugger write,
  gameplay, paid window or hardware validation is included.

The next boundary is a separately dispatched fresh natural `9F14` capture of
the exact built image, with the tracked physical replay and the observations
listed in audit 55 section 7. Supervisor review and acceptance are still
pending.

Supervisor correction (61): ROT and SWAP execute LDX 2,U; exit X is pattern008F, not dispatch pointer. Independent verifier executes actual leaf data loads/stores in private static test memory; this is static verification, not native gameplay or MAME execution. Stale dispatch-X maps are rejected.

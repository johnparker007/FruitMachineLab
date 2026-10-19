# Bounded original-VM composite-word contract

Status: **read-only contract and proposal; not implemented, written or executed.**
Task `il-composite-contract-31` started from `main`
`7d4e4e7301c3179ad4da926a14a75d8dadc28dfd`. It establishes a byte-checked
contract for one new composite definition in the approved extension range and
one same-size caller-token replacement. No linker/emitter change, ROM image,
MAME run or hardware test was performed.

Machine-readable record:
`evidence/mpu4/integrity/il-composite-contract.json`.
Read-only checker:
`tools/Test-IlCompositeContract.ps1`.

## Evidence classes

**Prior trace (natural execution, already accepted).** The early natural `9ED9`
call in the curated summary `evidence/mpu4/integrity/il-lua-vm-trace.json`
(`il-lua-api-09`, a reduced JSON record, not raw MAME logs) reaches the caller
at `9F14`, saves cursor `9F16`, returns through `7931`, and fetches `75A9` at
`9F16`. This is not a new run.

**Static deduction from original bytes.** The interpreter template, copier,
header cells, native handlers, `9ED9` body, `9F12` caller body and `9F3B` parent
body below are read from the exact original image. The stack effect and proposed
diff are derived from those bytes and the recovered integrity algorithm.

**Hypothesis.** The proposed word will behave like the original early call in
natural MAME because its body is byte-identical to the naturally executed
`9ED9` body and it uses the same runtime trampoline and handlers. It has not
been executed.

**Not established.** New-word execution, a written patched image, a MAME boot,
gameplay, physical MPU4 compatibility, general dictionary/header decoding,
relocation or bank switching.

## Identity, range and distinction of addresses

| Item | Value |
| --- | --- |
| ROM | `a6ls.p1`, 65536 bytes |
| SHA1 | `402d1518bb78fdc489b06c2aabc771e5ce151847` |
| SHA256 | `ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c` |
| Approved extension | CPU/file `1010-13EF`, 992 bytes, bank 0, expected `FF` |
| Guards | `1000-100F` and `13F0-13FF`, all `FF`; protected `1000-1003` |
| Integrity range | `1400-FFFF`; `1400-1407 = 343631A9145D8E01` |

The contract distinguishes four different things:

1. **Token/header address in a stream.** The 16-bit word fetched by `LDX ,Y++`.
   For the original caller at `9F14` this word is `9ED7`. For the proposal it is
   `1010`.
2. **Header/pointer cell.** The two bytes at the token address. A primitive
   token contains its handler address (for example `795B -> 795D`). A definition
   token contains `00F8`, the RAM trampoline entry (`9ED7 -> 00F8`; proposed
   `1010 -> 00F8`).
3. **Body.** The bytes after the header cell. `9ED9` is the original body;
   `1012` is the proposed body.
4. **Native handler.** Existing 6809 code at `795D`, `7880`, `7AB1`, `7931`.
   There is no new native handler.

`00F8` and `00FC` are **RAM addresses**, not ROM file offsets. `76C7` copies the
ROM template `7927-792E` (`34203184AEA16E91`) to RAM `F8-FF`:

```text
F8: 3420  PSHS Y
FA: 3184  LEAY ,X
FC: AEA1  LDX ,Y++      X = w@Y (token/header address), Y = Yold + 2
FE: 6E91  JMP [,X++]    PC = w@X, X = Xold + 2
```

The copy is established by `76C9 LDX #$00F8`, `76CC LDY #$7927`,
`76D0 LDD ,Y++`, `76D2 STD ,X++`, `76D4 CMPX #$0100`, `76D7 BNE $76D0`.

## Byte-checked dispatch, call and return table

| Site | Original bytes | Instruction(s) | Contract |
| --- | --- | --- | --- |
| `7927` / RAM `00F8` | `3420` | `PSHS Y` | Push caller cursor `Y` on control stack `S` |
| `7929` / RAM `00FA` | `3184` | `LEAY ,X` | Set `Y` to `X`, the body address after the header cell |
| `792B` / RAM `00FC` | `AEA1` | `LDX ,Y++` | `X = w@Y`; advance cursor `Y` by 2 |
| `792D` / RAM `00FE` | `6E91` | `JMP [,X++]` | Jump through the pointer cell at `X`; `X += 2` |
| `795B` header | `795D` | pointer cell | Primitive token `795B` |
| `795D` handler | `ECA136060EFC` | `LDD ,Y++`; `PSHU A,B`; `JMP $00FC` | Consume two inline bytes, push one 16-bit cell on data stack `U` |
| `787E` header | `7880` | pointer cell | Primitive token `787E` |
| `7880` handler | `3706E3C4EDC40EFC` | `PULU A,B`; `ADDD ,U`; `STD ,U`; `JMP $00FC` | Pop one cell, add to the next, replace it |
| `7AAF` header | `7AB1` | pointer cell | Primitive token `7AAF` |
| `7AB1` handler | `3706A8C4E841EDC40EFC` | `PULU A,B`; `EORA ,U`; `EORB 1,U`; `STD ,U`; `JMP $00FC` | Pop one cell, XOR into the next, replace it |
| `792F` header | `7931` | pointer cell | Return token `792F` |
| `7931` handler | `35200EFC` | `PULS Y`; `JMP $00FC` | Restore caller cursor from control stack `S` |
| `9ED7` header | `00F8` | definition pointer | Original `9ED9` definition |
| `9ED9` body | `795BFF80787E795BFF807AAF792F` | five nodes | Original naturally executed body |

`U` is the data-stack pointer and `S` is the control-stack pointer. `PSHU`
lowers `U` by two; `PULU` raises it by two. `PSHS Y` lowers `S` by two;
`PULS Y` raises it by two. `Y` is the token cursor, not the native PC.

## Naturally observed caller

The early `9ED9` call is reached from the definition at `9F12`:

```text
9F10: 00F8                         header (definition pointer)
9F12: 77F6                         vm_fetch_byte_and_following_word
9F14: 9ED7                         call 9ED9 (header 9ED7 -> 00F8)
9F16: 75A9                         vm_test_negative (next token)
9F18: 7B7D                         vm_swap_two_cells
9F1A: 7B3D                         vm_drop_cell
9F1C: 792F                         return
```

`9F12` is called from `9F3B`:

```text
9F3B: 817D                         push word from RAM 07CC
9F3D: 9F10                         call 9F12 (header 9F10 -> 00F8)
9F3F: 792F                         return (the observed w@S after 9F12 returns)
```

The accepted prior trace gives the following facts for the original early call:

| Phase | `Y` | Token/handler | `U` | `S` | Top |
| --- | --- | --- | --- | --- | --- |
| First prefetch | `9ED9` | `795B` | `066E` | `0796` | `0000` |
| Return handler | `9EE7` entry `7931` | `792F` | `066E` | `0796` | `0000` |
| Post-return prefetch | `9F16` | `75A9` | `066E` | `0798` | `0000` |

Saved caller cursor at `7931` was `9F16`. The observed result was `0000`
(`((0000 + FF80) XOR FF80)`), and `w@S = 9F3F` after return. These facts are
`prior_trace`, not a new execution.

## Proposed new composite word

One bounded proposal, no general dictionary or allocator:

| Item | Value |
| --- | --- |
| New header/token address | `1010` |
| Header bytes | `00F8` |
| Body start / end exclusive | `1012` / `1020` |
| Body bytes | `795BFF80787E795BFF807AAF792F` |
| Allocation | `1010-101F`, 16 bytes, original `FF` |
| Caller token address | `9F14` |
| Expected original token bytes | `9ED7` |
| Replacement token bytes | `1010` |
| Patch size | 2 bytes, same size |
| Original `9ED7` header/body | unchanged |
| Other callers of `9ED7` | unchanged |

The body is a byte-identical copy of `9ED9`, so the new word is a semantically
neutral wrapper: it has the same input/output contract as `9ED9`. The original
definition remains available for `EBB8`, `AC03`, `9EFB`, `A553` and any other
caller. Only the naturally observed `9F12` call site is redirected.

### Entry/exit phase map for the proposal (static predictions)

All rows in this table are **static predictions** derived from the exact original
bytes, the proposed byte-identical body and the prior-trace input state. No row
is a new observation. The original `9ED9` rows above remain `prior_trace`.

The body cursor differs from the original because the body starts at `1012`
instead of `9ED9`; the stack values and return address are unchanged. `X` at a
`00FC` pre-fetch row is the value left by the previous handler; the fetch itself
overwrites it with the token/header address. The header-trampoline entry row is
strictly after `LDX ,Y++` and `JMP [,X++]`, so `Y` has already advanced from
`9F14` to `9F16` before `PSHS Y` saves it.

| Phase (static prediction) | Native PC | `X` | `Y` | Token | `U` | `S` | Top | Boundary / predicted next fetch |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Caller dispatch before call | `00FC` | pre-fetch | `9F14` | `9ED7 -> 1010` | `066E` | `0798` | `0000` | Before `LDX ,Y++`; then `Y=9F16`, `X=1010`, `JMP [,X++] -> PC=00F8, X=1012` |
| Header trampoline entry | `00F8` | `1012` | `9F16` | `00F8` pointer | `066E` | `0798` | `0000` | After `JMP [,X++]`, before `PSHS Y`; `PSHS` saves `9F16`, then `LEAY ,X` sets `Y=1012` |
| Body prefetch 0 (after `PSHS`/`LEAY`) | `00FC` | `1012` | `1012` | `795B` | `066E` | `0796` | `0000` | Pre-fetch at `00FC`; next handler `795D` at `Y=1014` |
| Handler 0 | `795D` | `795D` | `1014` | `795B` (inline `FF80`) | `066E` | `0796` | `0000` | Handler entry; `LDD ,Y++` advances to `1016`, `PSHU` makes `U=066C`, top `FF80` |
| Prefetch 1 | `00FC` | `795D` | `1016` | `787E` | `066C` | `0796` | `FF80` | Pre-fetch at `00FC`; next handler `7880` at `Y=1018` |
| Handler 1 | `7880` | `7880` | `1018` | `787E` | `066C` | `0796` | `FF80` | Handler entry; `PULU` makes `U=066E`, add/store leaves top `FF80` |
| Prefetch 2 | `00FC` | `7880` | `1018` | `795B` | `066E` | `0796` | `FF80` | Handler 1 did not advance `Y`; next handler `795D` at `Y=101A` |
| Handler 2 | `795D` | `795D` | `101A` | `795B` (inline `FF80`) | `066E` | `0796` | `FF80` | Handler entry; inline advance to `101C`, `PSHU` makes `U=066C` |
| Prefetch 3 | `00FC` | `795D` | `101C` | `7AAF` | `066C` | `0796` | `FF80` | Next handler `7AB1` at `Y=101E` |
| Handler 3 | `7AB1` | `7AB1` | `101E` | `7AAF` | `066C` | `0796` | `FF80` | Handler entry; XOR leaves `U=066E`, top `0000` |
| Prefetch 4 | `00FC` | `7AB1` | `101E` | `792F` | `066E` | `0796` | `0000` | Next handler `7931` at `Y=1020` |
| Return handler | `7931` | `7931` | `1020` | `792F` | `066E` | `0796` | `0000` | Before `PULS Y`; `PULS` restores cursor `9F16`, then `S=0798` |
| Post-return prefetch | `00FC` | `7931` | `9F16` | `75A9` | `066E` | `0798` | `0000` | After `PULS Y`; next caller token in stream is `7B7D` at `9F18`, subject to `75A9` branch behaviour |

Stack contract:

```text
token body:        U: -2 +2 -2 +2 = 0
entry trampoline:  S: -2   (PSHS Y saves 9F16)
return handler:    S: +2   (PULS Y restores 9F16)
whole call:        U net 0, S net 0, Y restored to 9F16
```

The observed input cell is `0000`; the neutral output is `0000`. The next token
after return is `75A9` at `9F16`, matching the prior trace.

## Proposed image diff and integrity

The callsite at `9F14-9F15` is inside the firmware integrity range
`1400-FFFF`, so the active fields must be regenerated. The extension bytes
`1010-101F` are below `1400` and are outside the active firmware range; they do
not contribute to the fields.

| Diff class | Offsets | Count |
| --- | --- | --- |
| Extension allocation changed | `1010,1011,1012,1013,1015,1016,1017,1018,1019,101B,101C,101D,101E,101F` | 14 |
| Extension allocation unchanged (`FF`) | `1014,101A` | 2 |
| Callsite token | `9F14,9F15` | 2 |
| Active integrity fields | `FFD1,FFD2,FFD3,FFD4,FFD5` | 5 |
| Total changed | extension + callsite + fields | 21 |

| Item | Value |
| --- | --- |
| Original fields | `3E761E2605` |
| Proposed fields | `E93F3C61B5` |
| Proposed image SHA1 | `dc6381b9883aafde372d2c2aa14c817bae839b21` |
| Proposed image SHA256 | `761f34baac06c6f8f5da963ccadeb276fae9196ee1c4d9060bc915a314e3903d` |
| Image written | no |

The field order is the recovered order: sum/XOR (`FFD1`/`FFD2`), rotate-add
(`FFD3`), rotate-sub-XOR (`FFD4`/`FFD5`), each phase reading the preceding
phase's written fields. The checker reproduces the original fields exactly
before computing the proposal, which validates the copied algorithm.

## Checker and negative controls

Run from a clean checkout with an explicit original ROM:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  tools/Test-IlCompositeContract.ps1 `
  -RomPath <original-a6ls.p1> `
  -OutputDirectory <fresh-checker-output>
```

The checker is read-only with respect to the ROM. It verifies the original
length/SHA1/SHA256, the approved range and guards, the `1400` neighbor, the
dispatch template/copier, all handler/header/body bytes, the prior trace facts,
the proposed header/body/allocation, the same-size callsite replacement, the
stack contract, the byte-derived phase chain (PC/`X`/`Y`/`U`/`S`/top and inline
operand advancement), the ordered integrity fields, the exact diff and the
proposed image hashes. It writes only `checker-report.json` and `checker-log.txt`
under the output directory.

The prior-trace input is the **curated summary**
`evidence/mpu4/integrity/il-lua-vm-trace.json` (a reduced JSON record produced
from earlier MAME work), not raw MAME debugger logs. The checker reads only that
curated summary; it does not claim to re-read raw logs, and the copied trace
facts remain `prior_trace`, not new observations.

Negative controls, all in memory through the same validators used by the
positive path:

| Control | Result |
| --- | --- |
| Wrong ROM identity | rejected |
| Unsupported body token | rejected |
| Header other than `00F8` | rejected |
| Allocation overflow past `13EF` | rejected |
| Wrong callsite expected bytes | rejected |
| Overclaimed U stack effect | rejected |
| Header-trampoline `Y` reverted to `9F14` | rejected |
| Wrong `X`/body at the trampoline entry | rejected |
| Wrong saved cursor (`9F14` instead of `9F16`) | rejected |
| Wrong restored cursor (`9F14` instead of `9F16`) | rejected |
| Handler `Y` without inline-operand advancement | rejected |
| Wrong inline operand at handler 0 | rejected |
| False natural-execution claim for the new word | rejected |
| False executed status for the contract | rejected |

The focused run passed the positive phase-chain check and all negative controls
with exit code 0. The proposed image was computed in memory only.

## What this does and does not prove

Proved at contract level:

- The original interpreter dispatch, header/pointer-cell, body and return
  instructions and their `U`/`S`/`Y` roles are byte-checked.
- The early `9ED9` call from `9F14` is naturally observed with saved cursor
  `9F16`, post-return `S=0798` and next token `75A9`.
- A new extension header `1010` containing `00F8` and a 14-byte copy of the
  certified `9ED9` body is a well-formed definition token for the same
  trampoline and handlers.
- Replacing only `9F14` `9ED7` with `1010` is same-size and leaves all other
  callers of `9ED9` unchanged.
- The proposed diff is bounded to the 16-byte allocation, the 2-byte callsite
  and the five active integrity fields; the computed hashes are reproducible.
- The proposed phase chain is a byte-derived static prediction: `LDX ,Y++`
  advances `Y` from `9F14` to `9F16` before the `00F8` trampoline saves it, and
  each handler/inline-operand advance, `U`/`S` change and the final `PULS Y`
  return to `9F16` are checked by symbolic arithmetic over the original bytes.

Not proved:

- The proposed word has not been executed, so "it runs naturally" remains a
  hypothesis.
- No patched image was written or loaded; no MAME or hardware run was made.
- The broader purpose of `9F12` remains unresolved. The proposal does not depend
  on that purpose, only on token-level equivalence.
- General definition/header decoding, arbitrary caller selection, relocation,
  banking and other ROM revisions are out of scope.

## Next implementation scope

Review of the actual tracked types gives a small next slice; this task does not
implement it:

1. Add a strict composite-word plan type alongside `VmIlDefinition`: token/header
   address, header value `00F8`, body start/end, decoded nodes, stack effect and
   one caller patch. Do not generalise the dictionary format.
2. Reuse the certified token set (`795B`, `787E`, `7AAF`, `792F`) and the
   existing `VmIlVocabulary` semantics; reject any other token, non-final return,
   branch or unsupported operand width. `NineASixFourDecoder` already shows the
   strict span/body validation pattern.
3. Add a caller-patch validator: expected original bytes `9ED7` at `9F14`,
   expected original header `9ED7=00F8`, expected original body at `9ED9`, and
   replacement header/body at `1010`/`1012`. Keep the original callers intact.
4. Compose the new bytes through `ExtensionRangeEmitter` and apply the one
   same-size caller patch. The current `VmIlIntegrity.Repair` hard-codes the
   `9EDC` edit, so it must not be reused unchanged; add a bounded API that takes
   an explicit allowed-diff set, recomputes only `FFD1-FFD5` in the recovered
   order and rejects every other change.
5. Bind a source map/contract to the new token, header, body and caller site,
   including the expected post-return token `75A9`. Reuse `VmIlSourceMap` only
   after extending it to represent the new token/body rather than treating
   `9ED9` as the only body.
6. Keep this separate from `VmIlCompiler.CompileIdentity`/`BuildEmittedBody`,
   which are definition-span validators with one fixed first-literal edit, and
   from the current `ExtensionRangeEmitter`, which emits named payload bytes but
   does not apply a callsite patch or regenerate integrity. A new composite
   composer should coordinate those steps rather than widening the fixed
   `9ED9` checks.
7. After a create-only image with exact diff/hashes, the next task can run one
   natural fresh-boot MAME observation at `1010`, `1012`, the four handlers,
   `7931` and the post-return fetch `9F16`. Hardware validation remains later.

No linker, relocation, bank-switching or interpreter change is required for
this slice.

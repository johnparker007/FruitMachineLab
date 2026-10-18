# Independent 9A64 decode and checked byte branches

Status: bounded static/identity prerequisite. This is not natural 9A64
execution, gameplay, hardware compatibility or extension certification.

## Scope and permitted evidence

`NineASixFourDecoder` decodes the existing checked 9A64 definition directly from
the identity-checked original ROM. It does not load the Runtime plan/JSON as a
source of instructions. The reviewed 9A64 listing and the encoding checkpoint are
oracles for the selected span and listed sites; the branch contract itself is
derived from the original 6809 handler bytes.

| Item | Value |
| --- | --- |
| ROM | 65536 bytes, SHA1 `402D1518BB78FDC489B06C2AABC771E5CE151847`, SHA256 `EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C` |
| Header | `9A62` = `00F8` |
| Body | `9A64..9A71`, end exclusive `9A72`, 14 bytes |
| Span | `7B6D79820676657979037671792F` |
| Listing | `evidence/mpu4/VM-SCRIPTS/9A64.txt`, SHA256 `01A93F20773E1530FCCCA66CC4C3ACB2C066F4595C1A0371B08EBF99D3CDC3E9` |
| Checkpoint | `evidence/mpu4/maps/nudge-encoding-checkpoint.json` |

The decoder validates the exact ROM length, SHA1 and SHA256, the header value,
the body-start/end boundaries, each token's code-field pointer, a single final
return token, all supported token widths and all branch targets. It reads all
instruction and operand bytes from the ROM image.

## Decoded definition

| Address | Token | Operation | Bytes | Branch |
| --- | --- | --- | --- | --- |
| `9A64` | `7B6D` | `vm_rotate_three_cells` | `7B6D` | none |
| `9A66` | `7982` | `vm_branch_forward8_if_zero` | `798206` | operand `9A68` = `06`, target `9A6E`, if popped cell = `0000` |
| `9A69` | `7665` | `vm_or_word_memory` | `7665` | none |
| `9A6B` | `7979` | `vm_branch_unsigned_forward8` | `797903` | operand `9A6D` = `03`, target `9A70`, unconditional |
| `9A6E` | `7671` | `vm_clear_word_memory_bits` | `7671` | none |
| `9A70` | `792F` | `vm_return_to_caller_stream` | `792F` | none |

The token words are addresses of their dictionary code fields. For the two
branch tokens, `7979` points at `797B` and `7982` points at `7984`; all other
selected tokens point at token + 2. The decoder checks those pointers against the
ROM rather than assuming them from names.

## Original 6809 handler evidence

The branch model is a static deduction from the original ROM instruction bytes,
not from the recovered operation names.

### `797B`: unsigned forward byte

```text
797B E6 A4   LDAB ,Y
797D 4F      CLRA
797E 31 AB   LEAY D,Y
7980 0E FC   JMP <$FC
```

`LDAB ,Y` reads the byte at the stream cursor `Y` without advancing it. `CLRA`
clears the high byte of `D`, so `D` is the zero-extended unsigned operand.
`LEAY D,Y` sets `Y` to `operand-address + unsigned operand`, then `JMP <$FC`
enters the next-token fetch. This handler consumes no data-stack cell.

### `7984`: forward byte if zero

```text
7984 EC C1   LDD ,U++
7986 27 F3   BEQ $797B
7988 31 21   LEAY 1,Y
798A 0E FC   JMP <$FC
```

`LDD ,U++` pops one 16-bit data cell from `U`. `BEQ $797B` is a signed 6809
relative branch: target `7988 + (-13) = 797B`. When the cell is `0000`, control
enters `797B`, so `Y` becomes `operand-address + unsigned operand`. When the cell
is nonzero, `LEAY 1,Y` skips exactly the one-byte operand. Both paths consume the
popped cell and reach the next-token fetch.

Therefore both selected branches use:

- operand width: one byte;
- operand location: the first byte after the two-byte token;
- offset base: the operand address, not the token address or the next-token
  address;
- signedness: unsigned (`CLRA`/`LDD` zero-extension);
- direction: forward; and
- condition: popped cell zero for `7982`, unconditional for `7979`.

For 9A64 this yields `9A68 + 06 = 9A6E` and `9A6D + 03 = 9A70`. Both targets are
decoded instruction boundaries in the same definition.

## IL, compiler and source map

`VmIlNode.Branch` is an optional additive branch record. It retains the handler
address, operand address, operand byte, explicit target, condition, offset base,
unsigned flag, operand width and evidence class. Existing 9ED9 nodes keep
`Branch = null`; existing constructors and `with` expressions are unchanged.

`VmIlCompiler.CompileIdentity` re-emits the decoded nodes. For branch nodes it
re-checks the token, one-byte operand, operand/target arithmetic, forward target,
definition bounds, instruction-boundary target, condition and handler pointer. A
forged branch plan is rejected even when the caller supplies the exact original
ROM identity. 9A64 edits remain unsupported: `CompileEdits` still decodes only
9ED9 and accepts only the existing `9EDB` literal operand address.

`VmIlSourceMap` now exposes `Branches`, `Provenance` and `ResolveBranch`. Branch
entries bind the token and operand positions to the exact image hash; identity
and built-image maps both verify that the mapped operand byte equals the original
or emitted byte, that the target arithmetic holds and that the target is a node
boundary. The map's provenance string is the decoder's static/original-ROM
evidence class, not an execution claim. Branch evidence explicitly says no
natural 9A64 execution or runtime path coverage is claimed.

## Verification

The focused verifier runs the existing 9ED9 checks first (20 groups), then eight
9A64 groups:

1. original identity and header;
2. six nodes and two byte branches from original bytes;
3. `797B`/`7984` handler instruction decode;
4. identity compile of the 14-byte body and complete 65536-byte image;
5. identity source-map binding, branch positions and `ResolveBranch`;
6. malformed bytes: wrong header, unsupported token, token-pointer mismatch,
   unsupported handler opcode, target-in-operand, non-boundary target,
   out-of-span target and missing return;
7. forged branch plans: missing model, operand/target mismatch, wrong width,
   wrong condition, wrong offset semantics, wrong handler, non-boundary target,
   out-of-span target and unsupported 9A64 edit; and
8. pinned listing/checkpoint provenance.

The negative controls use in-memory copies and the internal identity-bypass
decoder only so that malformed decoded plans can be exercised despite the strict
full-ROM identity check. They do not modify the original ROM.

## Limitations and next boundary

Only the six tokens used by this definition and the two checked byte-branch
handlers are supported. There is no 9A64 edit, operand replacement, relocation,
linker, extension allocation, new-word support or general decoder. No MAME run,
natural 9A64 branch execution, runtime branch-path observation, physical hardware
test or integrity acceptance was performed. Natural reachability and branch
observation for 9A64 remain separate supervisor-selected work.

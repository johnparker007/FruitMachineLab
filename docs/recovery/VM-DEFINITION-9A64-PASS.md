# Checked in-place VM definition 9A64

Status: bounded B1/B2 increment. This is not complete B3 acceptance.

## Selected definition

`9A64` (`conditionally_set_or_clear_memory_mask`) is a fourteen-byte threaded
body with six listed sites:

```
7B6D 7982 06 7665 7979 03 7671 792F
```

The exact span and token boundaries come from
`evidence/mpu4/maps/nudge-encoding-checkpoint.json` under original ROM SHA1
`402D1518BB78FDC489B06C2AABC771E5CE151847`. All six sites are marked observed
in `evidence/mpu4/VM-SCRIPTS/9A64.txt`; the listing hash is recorded in the
definition. The body has no native calls, shared-body references or external
branch targets. Its forward-eight branch operands are relative to the operand
address: `9A66` token, operand at `9A68`, `06` -> `9A6E`; `9A6B` token,
operand at `9A6D`, `03` -> `9A70`.

## Common representation

`src/FruitMachineLab.Runtime/Mpu4VmDefinition.cs` parses a strict declarative
definition and builds one plan used by both `Encode()` and `ToInstructions()`.
The selected definition is
`evidence/mpu4/definitions/conditionally-set-or-clear-memory-mask-9a64.vm.json`.
Parsing rejects unknown JSON members, unsupported operations, token/operation
mismatches, missing or extra branch operands, size mismatch, a branch target
that is not an instruction boundary in the same definition, and encoding that
does not reproduce the stated original span.

`Apply` accepts only the declared input length and SHA1, checks the exact stated
original bytes at the definition address, overlays the encoded span and leaves
every other byte unchanged. It does not perform integrity repair.

## Demonstrated behaviour

Original execution: stack `(condition address mask --)`; `7B6D` rotates the
three cells, the conditional branch tests the condition, and the remaining
address/mask feed `vm_clear_word_memory_bits` or `vm_or_word_memory`, followed by
return through the control frame. Zero and nonzero branches were executed with
the original definition; both consumed the stack and returned through `0x800`
with cursor `0x9999`. The local frame stayed `0x700`.

A changed branch target `9A6E` -> `9A69` emitted the same span length with one
changed byte, `06` -> `01` at `9A68`, decoded to branch target `9A69`, and
changed the zero-condition path from clear-mask to OR-mask. This links the same
definition to emitted bytes and PC decoded execution. No changed-ROM execution
was attempted.

Synthetic full-image application changed only `9A68` and preserved every byte
outside `9A64..9A71`. Wrong length, wrong SHA1 and wrong original bytes at the
declared span were rejected.

## Boundaries

Supported operations are limited to the six tokens used by this body. External
references, dictionary/header ownership, relocation, free-space claims, other
branch forms and arbitrary opcodes are not inferred. The local original ROM is
used only as an optional verification oracle, never as the definition source;
the curated span is the tracked fixture. No MAME modified-ROM, gameplay,
startup, hardware or B3 claim is made.

Next task: repeat the checked representation for one independently evidenced
inline-literal word with a changed literal, or obtain independent modified-ROM
execution evidence before extending any B3 claim.

# Checked inline word literal definition 9ED9

Status: bounded B1/B2 increment. This is not complete B3 acceptance.

## Selected definition

`9ED9` (`bias_word_signed_value_at_bit7`) is a fourteen-byte threaded body with
five listed sites:

```
795B FF80 787E 795B FF80 7AAF 792F
```

The exact span and token boundaries come from
`evidence/mpu4/maps/nudge-encoding-checkpoint.json` under original ROM SHA1
`402D1518BB78FDC489B06C2AABC771E5CE151847`. All five sites are marked observed
in `evidence/mpu4/VM-SCRIPTS/9ED9.txt`; the listing hash is recorded in the
definition. The body has no native calls, shared-body references or branch
targets.

The two-byte inline word size comes from the separately verified native
interpreter path: token `795B` dispatches to `795D ECA1` (`LDD ,Y++`, a
big-endian word at `Y+2`). The byte-literal token `7963` separately dispatches
to `7965 4F E6A0` (`CLRB; LDB ,Y+`, a byte at `Y+1`). The selected definition
uses the observed word form only.

## Common representation

`src/FruitMachineLab.Runtime/Mpu4VmDefinition.cs` now supports an inline-word
operand in the same strict declarative plan used by `Encode()` and
`ToInstructions()`. The plan appends two big-endian literal bytes after the
token. Parsing rejects an inline literal on a non-literal operation, a branch
or missing literal on a literal operation, wrong token/operation pairs,
unsupported operations, size mismatch, addresses outside 16 bits, and encoding
that does not reproduce the stated original span.

`Apply` still accepts only the declared full-image length and SHA1, checks the
exact original bytes at the definition address, overlays the encoded span and
leaves every other byte unchanged. It performs no integrity repair.

## Demonstrated behaviour

Original execution has stack `( word -- biased-word )`. For the original
literals `FF80`, the observed arithmetic is `(word + FF80) XOR FF80` with
16-bit wraparound: `0000 -> 0000`, `0080 -> FF80`, `FFFF -> 00FF` and
`8000 -> 8000`. Each path leaves the local frame at `0x700`, consumes the input
and returns through the control frame with cursor `0x9999`.

Changing the first literal `FF80 -> FF00` emits the same fourteen-byte span
with exactly one changed operand byte at `9EDC`, decodes to literal `FF00`, and
changes the zero-branch behaviour: input `0080` becomes `0000` instead of
`FF80`, while input `0100` becomes `FF80` instead of `FF00`. This links the same
definition to emitted bytes and decoded PC execution. No changed-ROM execution
was attempted.

Synthetic full-image application changed only `9EDC` and preserved every byte
outside `9ED9..9EE6`. Wrong length, wrong SHA1 and wrong original bytes at the
declared span were rejected.

## Boundaries

Supported operations are limited to the three tokens used by this body:
`vm_push_inline_word_literal`, `vm_add_words` and `vm_bitwise_xor`, plus the
already represented `vm_return_to_caller_stream`. Inline byte literals, external
references, dictionary/header ownership, relocation, free-space claims and
other branch or opcode forms are not inferred. The local original ROM is only an
optional verification oracle; the curated span is the tracked fixture. No MAME
modified-ROM, gameplay, startup, hardware or B3 claim is made.

Next task: repeat the checked representation for one independently evidenced
inline byte literal, or obtain independent modified-ROM execution evidence
before extending any B3 claim.

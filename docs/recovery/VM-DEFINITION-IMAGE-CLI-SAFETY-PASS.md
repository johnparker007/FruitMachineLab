# VM definition image CLI and permanent 9ED9 invocation checks

17 October 2026. Bounded review15 correction. This note covers the narrow
`9ED9` image emitter and the permanent checks over the earlier synthetic MAME
invocation evidence. It does not add natural-reset, gameplay or hardware claims.

## Emitter hardening

`tools/FruitMachineLab.VmDefinitionImage` now enforces its accepted input before
any output path is written:

- original ROM length `65536`, SHA1
  `402d1518bb78fdc489b06c2aabc771e5ce151847` and SHA256
  `ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c`;
- definition address `9ED9`, input length `65536`, matching ROM SHA1, exact
  fourteen-byte original span `795BFF80787E795BFF807AAF792F` and token sequence
  `795B, 787E, 795B, 7AAF, 792F`;
- the only edit is inline literal index `0` changed from `FF80` to `FF00`; the
  changed image differs at exactly `9EDC` (`80` -> `00`), so all checksum bytes
  and the other thirteen span bytes are unchanged;
- changed image SHA1 `51e81cc5f41da2aa659a4d14d277e9e78614eb6b` and SHA256
  `a99d96f8ea8b4770d2d3828125f25894e831726fe44a79a37e0871faba135ed2`.

Both output images and `emission.json` are reserved with `FileMode.CreateNew`
before any bytes are written, then read back. Existing report or output paths
are rejected without creating the other outputs. Input ROM and definition are
re-read and must be unchanged. The report records the enforced checks and
hashes; it never reports an unenforced identity check as true.

`tools/Test-VmDefinitionImageCli.ps1` exercises a valid run, exact hashes and
only-`9EDC` output, reproducibility, existing report, existing second output,
wrong original image, wrong definition identity, no early outputs and input
preservation. The emitter is a small consistent member of
`FruitMachineLab.Headless.sln`; no separate build is required.

## Permanent invocation checks

`evidence/mpu4/collection/vm-definition-9ed9-invocation.json` remains the
independent MAME oracle. Three headless groups now load that curated file:

1. all ten recorded original/changed cases are executed through the same C#
   definition with the equivalent `U=0600`, `S=0700` and return-frame `0782`
   contract, and every result, stack pointer and return frame must match the
   recorded MAME row;
2. case/spans/header/template/first-dispatch/frame invariants are checked
   against the definition rather than a separate expected-result dictionary;
3. a tampered recorded result and a tampered return frame are rejected.

Existing focused, round-trip, boundary, execution and apply checks are
unchanged.

## Validation

A clean `git archive HEAD` snapshot was overlaid with only this increment's
files and the earlier accepted general14 definition/invocation files, while
the two stopped FEC9 checks and their sources/evidence were excluded.

- `dotnet build FruitMachineLab.Headless.sln` -> `0`, 0 warnings/errors.
- Full headless suite -> **370 PASS, 0 FAIL** (snapshot excludes stopped FEC9).
- `tools/Test-VmDefinitionImageCli.ps1` in that snapshot -> `0`; valid exact
  hashes, only `9EDC`, create-new rejection, no early outputs and input
  preservation all passed.

## Boundaries

The invocation oracle is synthetic and isolated: explicit PC/register/RAM
stack and caller-stream seeding, original threaded interpreter, no natural
reset, integrity repair, gameplay, relocation, general editor or physical
hardware evidence. B3 remains open for those cases.

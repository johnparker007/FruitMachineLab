# Checkout fixture integrity repair

## Scope

This repair is limited to checkout-dependent fixture hashing. It does not change
fixture values, execution semantics, native behaviour, assertions or negative
controls. The failing baseline was:

- `dotnet build FruitMachineLab.Headless.sln --ignore-failed-sources` -> exit 0.
- `dotnet run --project tests/FruitMachineLab.Verification --no-build -- .` ->
  exit 1 after 125 PASS groups, at
  `IRQ suffix composition fixture hash differs`.

## Root cause

The committed evidence is LF in Git. On Windows with `core.autocrlf=true` the
working tree is CRLF. Fixture pins were mixed:

- `irq-suffix-capture57-composition.json` was pinned to its committed LF hash
  `859E96D3...`; the CRLF checkout hashes to `B18AF1E9...`.
- `irq-suffix-capture57.json` was pinned to its raw CRLF hash `B7029FD8...`; the
  committed LF blob hashes to `4C2351F3...`.
- The same split existed in capture36, the capture41 reference, the VM listing
  references and `evidence/curated-manifest.json`.

The manifest had 994 CRLF raw hashes, 50 LF blob hashes and two stale entries.

## Canonical content policy

`FixtureIntegrity.MatchesPinnedHash` validates the pin, reads the fixture as
bytes, rejects UTF-8, UTF-16 and UTF-32 BOMs, rejects invalid UTF-8, and
canonicalizes newlines only by converting CRLF to LF. A bare CR is rejected; it
is **not** converted to LF. The pinned SHA-256 may equal any of:

1. the raw file bytes;
2. the canonical LF bytes;
3. the canonical CRLF bytes.

This keeps the original raw capture pins intact while making the same fixture
verify from either LF or CRLF working trees. A non-newline byte change alters all
three hashes and still fails the pin. `FixtureIntegrity` is used for curated
evidence fixtures, all of which are valid UTF-8.

`evidence/curated-manifest.json` records the committed Git blob length and
SHA-256 of canonical LF bytes. The same shipped `tools/Update-CuratedManifest.ps1`
implements the generator and verifier policy: accept LF or CRLF, reject BOM and
bare CR, normalize CRLF to LF, and write LF without a BOM. It is byte-oriented
and does not decode text, so the three legacy non-UTF-8 recovery documents remain
supported without re-encoding. The tool runs under both Windows PowerShell 5.1
and PowerShell 7 (`pwsh`); the earlier claim that 5.1 cannot run the verifier is
not true of the final tool.

`.gitattributes` scopes `evidence/**` and `docs/recovery/**` to `text eol=lf`.
This is deliberate, not a repository-wide line-ending rule. All 1225
`evidence/mpu4` files and all 106 `docs/recovery` files are text (`.json`,
`.txt`, `.cmd`, `.lua`, `.log`, `.csv`, `.asm`; no NUL bytes were found). The
rule makes fresh Windows checkouts canonical LF while the helper remains
tolerant of already-materialized CRLF trees.

## Preserved provenance

The original raw pins in the verification code are unchanged:

| fixture | raw CRLF pin | canonical LF / committed blob |
| --- | --- | --- |
| `irq-suffix-capture57.json` | `B7029FD8...` | `4C2351F3...` |
| `matched-service-window-capture36.json` | `AC60AC5E...` | `E83D8964...` |
| `native-service-rom-regions-capture36.json` | `DD5DFDCE...` | `376C2D8A...` |
| `stack-writer-0785-capture41.json` | `D23207FA...` | `83B6E0D3...` |
| `VM-SCRIPTS/9A64.txt` | `01A93F20...` | `97632936...` |
| `VM-SCRIPTS/9ED9.txt` | `15A98BF4...` | `530B362B...` |

`irq-suffix-capture57-composition.json` was already pinned to its committed LF
hash `859E96D3...`; its raw CRLF form is `B18AF1E9...`.

## Stale manifest entries

Both were investigated against Git history rather than blindly regenerated.

- `evidence/mpu4/collection/meter-pulse-58bb-empty.json` was added in
  `10d513b`. The HEAD manifest recorded 2220 bytes / `8F2A8CAB...`, but the
  committed blob is 2219 bytes / `0CBEB803...`, and no earlier committed version
  exists. The manifest record was generated from pre-commit content; it is now
  the committed blob.
- `docs/recovery/LIVE-NATIVE-SOUND-OWNERSHIP-PLAN.md` changed in `2abd022` to
  16261 bytes / `9B651761...`, which is exactly what the HEAD manifest recorded.
  Commit `09fcbdf` then changed it to 16713 bytes / `C855C741...` without
  updating the manifest. The entry is now the current committed blob.

The remaining 994 of the 996 changed entries are line-ending-only rebases to
committed LF blobs. Every one of the 996 changed entries was checked: its new
manifest length and SHA-256 equal both the HEAD blob canonical LF content and the
working-tree canonical LF content.

## Changed files

- `.gitattributes` (new): scoped LF policy for curated evidence and recovery.
- `src/FruitMachineLab.Runtime/FixtureIntegrity.cs` (new): byte-level canonical
  hash comparison; no executor logic.
- `src/FruitMachineLab.Adders/AddersIrqSuffixVerification.cs`: composition and
  capture57 hash reads.
- `src/FruitMachineLab.Adders/AddersMatchedServiceVerification.cs`: capture36
  and region hash reads.
- `src/FruitMachineLab.Adders/AddersToneFinishVerification.cs`: capture36 and
  region hash reads.
- `src/FruitMachineLab.Adders/AddersMeterPulseVerification.cs`: capture41
  reference hash read.
- `tests/FruitMachineLab.Verification/VmDefinitionVerification.cs`: 9A64 and
  9ED9 listing hash reads.
- `tests/worker/FixtureIntegrityChecks/**` (new): focused helper checks.
- `evidence/curated-manifest.json`: 996 existing entries rebased or corrected,
  plus one new entry for this report. No paths were removed, order was preserved,
  and no semantic JSON fields changed.
- `docs/recovery/CHECKOUT-FIXTURE-INTEGRITY-REPAIR.md` (this file).

Manifest before (HEAD blob): 218560 bytes, 1330 entries,
`71FDDFA4EB270B7F802B1DF931086823D27693DC28E4AD3DA723F913278DD72E`.
Manifest after regeneration: 1331 entries (this report is included). The final
size and SHA-256 are recorded in
`artifacts/deepseek/il-repair-continuation-03/final-hashes.txt`; they are not
repeated here because the manifest hashes this file.

## Verification

Current CRLF working tree:

- Headless build -> exit 0, 0 warnings, 0 errors.
- Full verifier -> exit 0, 417 PASS.

Isolated evidence copies (whole `evidence` tree copied to a temporary root; the
originals were not mutated):

- LF copy, same verifier -> exit 0, 417 PASS.
- CRLF copy, same verifier -> exit 0, 417 PASS.

Manifest:

- Actual checkout, shipped `-Verify` -> exit 0 under Windows PowerShell 5.1 and
  under `pwsh` (1330 entries before this report was added; 1331 after).
- Isolated LF and CRLF roots, shipped `-Verify` before generation -> exit 0.
- Shipped generator on both roots -> 1331 entries each; post-generation
  `-Verify` -> exit 0. The two generated manifests are entry-for-entry identical
  (path, bytes, SHA-256). The only generated entry absent from the earlier
  manifest is this report.

Negative controls:

- `FixtureIntegrityChecks` -> exit 0: LF/CRLF equivalence, mixed newlines,
  non-newline change rejected, whitespace append rejected, BOM rejected, bare CR
  rejected, invalid UTF-8 rejected, invalid pin rejected.
- Manifest non-newline alteration -> exit 1,
  `Curated manifest differs: evidence/mpu4/collection/payout-data.json`.
- Manifest BOM -> exit 1, `Curated manifest rejected BOM`.
- Manifest bare CR -> exit 1, `Curated manifest rejected bare CR`.
- Restoring the fixture returned `Verified 1331 curated entries`, and its
  before/after SHA-256 was unchanged.
- The existing whitespace-append pin check in the full verifier passes.

The source evidence tree digest was identical before and after the isolated
experiments.

## Limits

This task did not run MAME, native gameplay, IRQ or sound integration, or
physical hardware. It did not establish supervisor acceptance. No commit, push,
fetch, branch or configuration change was made.

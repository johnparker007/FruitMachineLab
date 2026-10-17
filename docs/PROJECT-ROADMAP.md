# Project roadmap

Updated 17 October 2026 after the source audit at `2916fa1`. This replaces older
timing-first and byte-identical-rebuild priorities. Historical evidence remains in
[CURRENT-HANDOFF.md](CURRENT-HANDOFF.md), recovery reports and implementation status.

Three goals advance in parallel: autonomous PC gameplay, editable original-VM
game logic, and modified ROM generation for MAME and eventually physical hardware.
MAME is the external oracle. Byte-identical reconstruction is diagnostic, not a
prerequisite. Recorded schedules must not be hidden runtime dependencies.

Read [the source audit](ENGINEERING-AUDIT.md) for architecture and capture inventory;
[ROM editing](ROM-EDITING.md) for the first patch milestone. Preserve original
ROMs/settings/projects; no installations/configuration changes without approval.

## A — Autonomous native execution

| Stage | State and acceptance |
| --- | --- |
| A1 Capture inventory (P0) | Initial source-backed inventory in ENGINEERING-AUDIT.md extends COLLECTION-TRANSFER-PASS. Maintain runtime reads/classification/replacement strategy and add enforceable capture-free policy. Not centrally enforced yet. |
| A2 Causal scheduling (P0) | Partial: timer3 phase/assertion, selected instruction acceptance/dispatch/scan/callback generated. Outer timer1 entry/occupancy and atomic helper/VM pacing remain captured. Accept selected game paths with generated scheduling and differential verification. |
| A3 Ten paid games (P1) | Open: three selected generated games pass using Live capture adapters. Accept ten complete games on one state, no runtime recorded schedules/results or manual repairs. Declared starting snapshot temporarily permitted. |
| A4 Expanded coverage / 100 games (P1) | Partial gameplay includes paid spins/results, nudges, board links, Skill Cash, accounts and selected headless collection. Accept 100 games across outcomes/features/collection/background services with deterministic accounting/state checks. |
| A5 Extended stability (P2) | Open: accept 1000 complete games with invariants and no unsupported execution boundaries. Synthetic payout transactions are not played games. |
| A6 Independent startup | Open: documented reset/init without captured RAM/device snapshots; retain RNG, NVRAM and hardware phase semantics. |

Integrate existing native sound/timed collection owners with required foreground
and service boundaries. Stage CPU work needed for that path and generated
scheduling, preserving the working adapter until proved. Avoid an unrelated full
CPU emulation campaign or replacing working VM/motor/timing infrastructure.

## B — Editable game representation

| Stage | State and acceptance |
| --- | --- |
| B1 Dictionary/encoding (P0) | Partial addressed VM listings, headers, tokens, branches and selected exact-byte checkpoints. Accept validated definition/reference ownership with opaque regions explicit; labels do not establish complete recovery. |
| B2 Editable representation (P1) | Initial data-only increment: declarative shared award patch executes in recovered PC and original MAME VM lookups. No editor/compiler. Next bind ROM-backed data/decoded definitions through one validated representation. |
| B3 Existing definition | Open: replace an in-place word, preserve stack/control flow and verify PC/MAME behaviour from one definition. |
| B4 References/relocation (P2) | Open: certify absolute tokens, headers, native/shared-body and relative branch references before moving/growing a body. No safe free space declared. |
| B5 Feature editing (P2) | Open: modify substantial feature from common definitions and verify both targets. |
| B6 New features (P2) | Open: author/build/execute a feature within hardware constraints without per-change manual machine-code patches. |

Use recovered VM encoding as the starting representation. Retain provenance,
sites/tokens and opaque bytes. C# supplies execution/tools, not competing game
rules. Changed decoded operands require a decode/rebuild path. Do not build a
polished editor before replacement ROM definitions execute.

## C — ROM generation and hardware compatibility

| Stage | State and acceptance |
| --- | --- |
| C1 ROM map (P0) | Partial `evidence/mpu4/maps/rom-layout.json`, tables and source-backed entries. Need integrity algorithm, reference inventory and certified region boundaries. Unknown bytes remain preserved. |
| C2 Minimal patcher (P0) | Implemented: strict identity/expected bytes, equal lengths/no overlaps, separate create-only output, reproducible hashes/diff. Safety/CLI tests and actual original-image generation in ROM-EDITING.md. |
| C3 Modified ROM in MAME (P1) | Partial: shared award lookup returns12, control10, in original VM. Synthetic invocation verified; reset boot/natural play remain open. Expected MAME loader hash warning retained. |
| C4 Definition replacement | Open: in-place compiled replacement, boot and execute it. |
| C5 Compiler/assembler (P2) | Open: reproducible multi-definition builds/fixups/source maps, preserving unknown bootstrap/IRQ/interpreter/data. |
| C6 Differential verification (P1, expand later) | Initial same-table lookup comparison. Accept controlled original/modified/native gameplay, accounts/outputs and expected differences; identical internal traces not required. |
| C7 Physical compatibility (P2) | Open: prove reset, timing, persistent state and peripherals on hardware. MAME success cannot complete this stage. |

## Next three bounded tasks

1. **Certify startup/integrity and demonstrate the patch naturally.** Depends on
   C2 and initialization listings. Establish original-ROM boot oracle, recover
   exact sum/XOR ranges/fields and repairs without bypasses. Accept hashes, all
   changed offsets, startup evidence and modified award in MAME play.
2. **Integrate collection/native sound with causal ownership for one path.**
   Depends on timed plans and A1. Supply foreground/IRQ boundaries, real inputs
   and declared checkpoint; prohibit capture schedules/results. Accept ten paid
   games with collection, retained accounting and precise boundary diagnostics.
   Deliver the smallest missing causal service with independent verification
   first if integrated acceptance remains blocked.
3. **Build one checked editable VM definition.** Depends on B1/C1 integrity.
   Start in-place without relocation. Accept one definition producing PC decoded
   operations and ROM bytes, stack/control-flow tests and execution in both targets.

## Preservation and product direction

Retain bytes/addresses, calling/frame/stack effects, input/output contracts and
evidence classes (static, natural traces, hypotheses, synthetic faults). Unknown
helpers fail; no guessed semantics, suspected ROM fixes or zero-cost timing.
Keep binaries, credentials and bulky traces untracked. Hybrid building preserves
opaque firmware rather than reconstructing every byte before changing a constant.

Windows diagnostics and eventual DX renderer consume common backend inputs/outputs.
Reuse John's MFME FML importer/layout renderer when paths/licences/assets arrive;
avoid a polished temporary cabinet. Validate reuse using a second MPU4 game John
supplies before generalizing. Other platforms, including 68000, need independent
execution-model recovery. Millions of autoplay games remain a later goal after
retained-state accounting and meaningful whole-game coverage.

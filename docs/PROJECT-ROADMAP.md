# Project direction and handoff

Updated 15 October 2026 from John's agreed priorities. This document records
direction, not evidence that future milestones have been implemented.

## Read first when continuing

Read AGENTS.md, DEVELOPMENT-SETUP.md, this roadmap and CURRENT-HANDOFF.md.
Use ../IMPLEMENTATION-STATUS.md and the linked recovery reports for implementation
details and evidence boundaries. Check the working tree before editing: chat history
is not authority for which changes John has committed or pushed.

## Priority order

The primary milestone is a complete playable Adders & Ladders machine on PC.
Preservation work below supports that recovery; symbolic toolchain construction
waits until playable-machine coverage is established.

1. Complete the live Adders & Ladders Skill Cash slice, including unsupported paths
   and better CPU/IRQ timing. Preserve verified playback as a separate mode.
2. Expand into normal Adders & Ladders machine play: feature entry/exit, startup,
   credits, holds, reels, nudges, other features, gambling, collection and accounting.
   These are scope areas, not an asserted implementation order for every helper.
3. Integrate graphical layouts alongside that expansion, early enough for useful
   human testing. John has an existing library importing MFME FML into modern JSON
   and image data, plus open-source projects rendering those layouts interactively.
   Inspect and reuse those references instead of building another importer. Their
   paths/links, licences and the Adders & Ladders layout have not yet been supplied.
4. Validate hundreds of consecutive real-time games, retaining machine state and
   accounting between games. Preserve reproducible input logs and checkpoints.
5. Use a second MPU4 game and its recovery breakdown, supplied by John, to test
   claimed platform reuse. Generalize after demonstrated reuse, not speculation.

Minimal diagnostic lamps, buttons and text/symbol reels are useful development
tools, but do not build a polished temporary cabinet. Diagnostic and graphical
renderers should use the same backend inputs/outputs, with no gameplay in UI code.

## Longer-term aims

- After complete playable-machine recovery, pursue a reconstructed development
  kit: byte-identical baseline ROM rebuild, then editable symbolic native/VM
  source capable of producing ROMs for hardware tests. This is reconstructed
  source/tooling, not the original authors' source or tools. Defer the full
  symbolic 6809 assembler/reassembler, compiler, editor and relocation system.

## Preservation during gameplay recovery

Preserve facts found during current recovery using the existing native exports,
VM listings, maps, provenance sidecars and dated recovery reports. Do not create
a parallel documentation system or investigate unrelated routines for coverage.
For newly recovered/revised code and data, retain exact ROM bytes and addresses
where checked, token/operand/embedded-data encodings, labels/constants/RAM roles,
boundaries/entry and calling conventions, stack/frame effects and side effects.
Record references, pointer/dictionary/header structures, branch targets and layout
constraints relevant to later reconstruction. Keep unresolved regions, suspected
bugs and assumptions explicit; preserve original behaviour. Link ROM locations,
listings, C# code and verification artifacts, distinguishing static deductions,
natural traces, hypotheses and synthetic experiments.

Use reproducible read-only Ghidra exports for symbols/comments/data definitions
at meaningful checkpoints when access permits. Keep source exports portable;
document unavailable access and missing fields rather than implying completeness.
Decoded listings are not lossless source unless their byte coverage is checked.
ROM binaries and bulky traces remain outside tracked files. This proportional
preservation work supports gameplay recovery and must not postpone it.

## Other longer-term aims

- Linked VM/script listings, execution highlighting and evidence-linked structured
  reconstructions. Build debugging features when they help game recovery.
- Script editing, compilation and safe replacement are deferred. Preserve decoded
  instruction/address mappings and separate execution from presentation; do not
  implement an editor merely to prove future extensibility.
- Reproducible headless autoplay, eventually millions of consecutive plays. Whole-
  machine conclusions require whole-machine coverage; repeated feature-entry resets
  do not establish payout behaviour across persistent machine history.
- Other platforms, including 68000-family machines. Do not assume their ROMs use
  MPU4's threaded VM. Recover each execution model from evidence.

The desired backend executes recovered logic and translated helpers directly.
MAME remains an external behavioural reference. Any necessary emulation fallback
must be small, explicit and checked; it is not the default execution architecture.

## Documentation maintenance

Keep this roadmap aligned with John's decisions. Update CURRENT-HANDOFF.md at
substantial batch boundaries with the current result, checks, limitations and next
concrete work. Keep detailed technical evidence in recovery reports rather than
growing the handoff into a transcript. Never present historical test counts or
captured timing adapters as stronger current verification than they provide.

# Project direction and handoff

Updated 15 October 2026 from John's agreed priorities. This document records
direction, not evidence that future milestones have been implemented.

## Read first when continuing

Read AGENTS.md, DEVELOPMENT-SETUP.md, this roadmap and CURRENT-HANDOFF.md.
Use ../IMPLEMENTATION-STATUS.md and the linked recovery reports for implementation
details and evidence boundaries. Check the working tree before editing: chat history
is not authority for which changes John has committed or pushed.

## Priority order

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

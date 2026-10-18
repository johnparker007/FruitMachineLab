# FruitMachineLab

Source-level editing, compilation and live debugging of original fruit-machine
ROMs. First target: Barcrest MPU4 Classic Adders & Ladders, MAME set m4addr,
A6L 0.1 set 1. MAME is the execution backend; original MPU4 hardware is the final
compatibility target. Later games/platforms follow demonstrated reuse.

## Working rules

- Require John's approval before installations or configuration changes.
- Autonomously commit reviewed, passing increments on main between worker runs;
  stage only accepted files and preserve unrelated or unfinished changes.
- Pushing, publishing, repository access changes and history rewrites require
  John's explicit authorization. Do not switch branches or merge during worker runs.
- Preserve existing ROMs, MAME settings, Ghidra projects, and unrelated MCP configuration.
- Distinguish trace-backed findings, static deductions, hypotheses, and synthetic fault experiments.
- Recovered pseudocode is not original source. A name does not establish complete behaviour.
- Keep ROM binaries, local credentials, installed tools, and bulky traces outside tracked files.
- Never silently invent missing helper semantics or fix suspected ROM bugs in the reference behaviour.

## Primary architecture and priorities

Read docs/PROJECT-ROADMAP.md for the active plan and docs/ROM-EDITING.md for
existing tools/evidence. The former autonomous C# roadmap is superseded.

- Recover the original threaded VM into a lossless, editable intermediate language
  (IL), retaining addresses, original bytes, tokens, operands, references and provenance.
- Compile unchanged supported definitions byte-identically; preserve opaque regions
  byte-for-byte and distinguish preservation from certified editable decoding.
- Keep IL, compiler and debugger independent of the existing native C# executor.
  C# remains suitable for tooling; executing the game in C# is not required.
- Preserve original firmware/interpreter and existing functionality. Emit a hybrid
  original image plus explicit patches, with correct firmware integrity fields,
  strict original identity, expected-byte checks and reproducible build reports.
- Start with same-size edits, then a bounded linker into end-of-ROM extension space,
  VM entry/reference redirection and safe native trampolines. Retain original
  addresses unless explicitly patched. General relocation/banking is deferred.
- Allow a user-confirmed extension range per ROM revision, checked for mapped ROM,
  expected contents, known uses and integrity coverage. Padding runs alone are
  candidates, not proof. Reject overflow, overlap and unsupported references.
- Support new composite VM words, then native 6809 primitives exposed through the
  original VM ABI once headers, stack effects and entry/return contracts are proved.
- Use MAME Lua and generated source maps for VM-aware breakpoints/stepping and
  register, RAM and data/control-stack inspection. Native PC is not VM cursor Y;
  U is the data stack and S the control stack. Validate observation boundaries.
- Support controlled, logged paused RAM/register writes where MAME APIs permit.
  Debugger experiments and save-state setups do not establish natural ROM behaviour.
- Validate compiled changes through natural fresh-boot MAME execution; physical
  hardware validation remains separate and required for hardware compatibility.

Preserve 16-bit wraparound, signed arithmetic, Forth true FFFF/false 0000,
original stack/frame semantics, timing and randomness. Reject unsupported edits
rather than guessing. Keep platform behaviour separate from game-specific logic.

## Frozen native execution work

Autonomous native C# gameplay execution is suspended indefinitely, potentially
permanently. Preserve code, tests, captures and reports as research/verification
assets. Do not resume autonomous scheduling, IRQ integration, native sound
ownership, capture-free gameplay or C# peripheral simulation without John's
explicit reauthorization. These are not prerequisites for ROM editing.

Historical resumption instructions are in docs/history/PRE-IL-MAME-ROADMAP.md.
Old NEXT/gate/task/checkpoint instructions do not override this freeze. This
documentation pivot does not dispatch workers, resume schedules or authorize a
broad implementation campaign. Present the replacement plan for review first.

## First executable proof and verification

Decode one known definition from original bytes; compile it identically; edit a
meaningful operand; regenerate integrity; boot and naturally execute it in MAME;
observe PC/Y/U/S, registers and stacks through Lua and resolve to the IL line.
Then prove a new allocated composite word, followed by a native primitive.

Existing build/check commands from the repository root:

~~~powershell
dotnet build FruitMachineLab.Headless.sln --ignore-failed-sources
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .
dotnet build FruitMachineLab.sln --ignore-failed-sources
~~~

The dependency-free verifier is a console program, not dotnet test. Keep tooling
independently buildable/testable from the Windows UI; retain existing regression
checks. See README.md and docs/ROM-EDITING.md for focused commands.

## Existing evidence

The original local analysis workspace is:
`C:\Users\John\Documents\Codex\2026-10-13\help-me-set-up-a-local`.
Reports are under `outputs\mpu4`; prerequisite evidence is under
`outputs\mpu4\evidence\prerequisite-pass`.
This is local context, not a cloud dependency. Curate required evidence into the
repository before cloud tasks rely on it.

ROM a6ls.p1: 65536 bytes; SHA1 402d1518bb78fdc489b06c2aabc771e5ce151847;
CRC 9f97f57b. Original handoff baseline: 485 named native functions and 528 VM
bodies, 378 purpose-labelled and 150 unresolved. These are historical recovery
counts, not claims of complete decoding or compiler coverage.

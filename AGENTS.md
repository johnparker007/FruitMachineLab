# FruitMachineLab

Source-level editing, compilation and live debugging of original fruit-machine
ROMs. First target: Barcrest MPU4 Classic Adders & Ladders, MAME set m4addr,
A6L 0.1 set 1. MAME is the execution backend; original MPU4 hardware is the final
compatibility target. Later games/platforms follow demonstrated reuse.

## Working rules

- Require John's approval before installations or configuration changes.
- Autonomously commit reviewed, passing increments on main between worker runs;
  stage only accepted files and preserve unrelated or unfinished changes.
- Autonomously push reviewed, passing commits to the existing GitHub remote main
  between worker runs; verify the outgoing range and remote HEAD. Never force-push.
- Releases, deployments, repository access changes and history rewrites require
  John's explicit authorization. Do not switch branches or merge during worker runs.
- Preserve existing ROMs, MAME settings, Ghidra projects, and unrelated MCP configuration.
- Distinguish trace-backed findings, static deductions, hypotheses, and synthetic fault experiments.
- Recovered pseudocode is not original source. A name does not establish complete behaviour.
- Keep ROM binaries, local credentials, installed tools, and bulky traces outside tracked files.
- Never silently invent missing helper semantics or fix suspected ROM bugs in the reference behaviour.

## Active priority — feature replacement experiment (20 October 2026)

John authorizes an experiment focused on working ROM behaviour. This section
supersedes older sequential milestone gates, mandatory supervisor pre-solving,
narrow delegation and two-attempt repair stops. Preserve their history, but do
not reimpose them through old tasks, checkpoints or acceptance text.

Replay the existing clean-NVRAM, unthrottled MAME route to the feature board,
collect the first feature game, identify its actual VM dispatch and replace that
feature entry with custom VM code. First demonstrate a conspicuous lamp-output
change, then an animation on feature collection, then interactive gameplay.
Confirm the replay reaches the same feature rather than assuming it does.

Reuse the recovered function/script indexes, VM listings, Ghidra exports,
existing patch/integrity tools and replay infrastructure. The demonstrated 9F14
helper hook is an example, not automatically the feature entry. Inspect actual
entry/return requirements. Recovered names such as F64F are investigation leads.
Keep all new headers/code/data inside approved 1010–13EF (992 bytes) for this ROM
revision, preserve guards 1000–100F/13F0–13FF, report allocation and reject overlap
or overflow. Original identity, expected-byte guards and integrity repair remain
required. A new range still requires John's approval.

One task should pursue an observable behavioural milestone and may include
multiple private patch/run/debug cycles. DeepSeek may investigate VM semantics,
design patches, run MAME and correct failures. Codex supervises resources and
independently reviews final results; it need not pre-solve every contract.
Use a two-hour actual worker budget for the initial experiment, excluding callback
waits, within existing runner watchdogs. Failed ROM variants are diagnostic
feedback. John provides standing authorization for supported repairs and further
attempts. After two unproductive handoffs, diagnose/replan or take over directly;
preserve failure history rather than requesting routine repair permission.

Acceptance: baseline and patched replay reach the selected feature; the patched
ROM naturally executes the cave script; and a distinctive visible or
MAME-observable lamp change occurs. Record the tested ROM/build identity, patch,
key observations and relevant entry/return context. Use detailed tracing to solve
concrete problems, not as an automatic prerequisite. Static checks alone are not
success. Injected state/save states are diagnostic experiments, not natural proof.
Do not weaken regressions, invent semantics or claim hardware compatibility.

General IL/compiler/linker/debugger work remains the long-term architecture but
must not block this experiment. Add general tooling, specialised validators,
fixtures or extensive documentation only for a demonstrated obstacle. Preserve
originals, private failed variants, one-writer discipline, bounded execution and
review before commits/pushes. Native C# execution remains frozen. Preserve John's
callback pause until he explicitly resumes it; no experiment is dispatched merely
by this documentation update.

## Primary architecture and priorities

John authorized a continuing supervised development loop on 18 October 2026:
review each bounded worker result, commit and push accepted increments, then
dispatch the next supported roadmap task. Successful batches are review points,
not stop conditions. Historical documentation-pivot and one-batch restrictions
do not limit this later authorization. Native execution remains frozen.

Read docs/PROJECT-ROADMAP.md for the active plan and docs/ROM-EDITING.md for
existing tools/evidence. The former autonomous C# roadmap is superseded.

### Long-term game-authoring objective

The ultimate product is a compiler and development environment for authoring
entirely new MPU4 games. Follow the long-term objective in
[docs/PROJECT-ROADMAP.md](docs/PROJECT-ROADMAP.md): the first target is a minimal
interactive Breakout/Arkanoid-style demo on the 6×8 lamp grid, using cabinet
buttons and proved original timing, lamp, Alpha and sound services.

In parallel with the active feature experiment, favor useful incremental slices
that enable new game authoring. Reuse recovered ROM services before new native
implementations. Keep the demo's new headers, code and data within the approved
992-byte `1010-13EF` range for this ROM revision, report its size, and simplify
the demo if needed; do not assume every game feature will fit.

Preserve the lossless IL/compiler/linker/MAME architecture and hardware target.
The active experiment may proceed before general tooling milestones. It does not authorize changed allocation
boundaries, weaker verification, invented service semantics, or resumption of
the frozen C# executor, scheduling or peripheral simulation.

### Architecture priorities

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
Old NEXT/gate/task/checkpoint instructions do not override this freeze. The historical documentation-only pivot is superseded by the active experiment; the native freeze remains.

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

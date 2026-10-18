# Project roadmap — lossless IL, ROM compiler and MAME debugger

Decision: 18 October 2026. This replaces the previous parallel native-runtime,
editable-VM and ROM-generation priorities. Autonomous C# gameplay execution is
frozen indefinitely, potentially permanently. Do not finish the old sound/IRQ
gates first. Existing implementation, tests, captures and evidence are preserved.

The objective is an extensible source-level editing, compilation and live-debugging
environment for original MPU4 ROMs. MAME runs the original interpreter, CPU and
machine services; original MPU4 hardware is the final compatibility target.

## Architecture

Original ROM -> lossless recovered IL -> edits/new words -> original image plus
compiled patches/extension region -> integrity repair -> MAME execution and
Lua/source-map debugging -> physical hardware validation.

The IL represents the original VM's encodings and semantics. It retains original
addresses/spans/bytes, execution tokens, operands, reference kinds and provenance.
The compiler and debugger consume this representation independently of the C#
native executor. Existing helpers may serve as optional verification oracles;
new words do not require C# execution implementations.

For unchanged supported definitions, Compile(Decode(ROM)) must reproduce the
original bytes. Overlaying these definitions with preserved opaque regions must
leave the complete original image identical. Raw-byte passthrough alone does not
certify a definition as editable. Keep certified decoding and opaque preservation
explicit. Unsupported edits fail; a label is not a recovered contract.

Prefer same-size edits, then additions in end-of-ROM extension space. Original
code/data remain at their existing addresses except for explicit patches. A
bounded linker records code/data/header allocations and fixups, then redirects
supported VM entries/references or emits safe native hooks. A header code-pointer
redirect is not assumed to relocate every word type: verify each header/body/
caller convention. General relocation, ROM expansion and bank switching wait.

John's practical code-cave experience supports a pragmatic first allocator:
confirm a usable range once per ROM revision, record expected contents, mapping,
known uses and checksum coverage, then enforce bounds and nonoverlap. FF/00 scans
can suggest candidates. Complete whole-ROM disassembly is not a prerequisite;
padding appearance alone is insufficient. No range is certified by this plan.

Preserve 16-bit wraparound, signed operations, FFFF/0000 flags, VM stack/frame
contracts and original timing/randomness. Existing firmware behaviour stays the
reference unless an explicitly declared modification changes it.

## Reusable assets and current gaps

Paths in this table are repository-relative.

| Asset | Reuse and limits |
| --- | --- |
| evidence/mpu4/VM-SCRIPTS, docs/recovery/DEEP-ANALYSIS.txt and evidence/mpu4/maps | Addressed listings and interpreter/header/token evidence. Not a general dictionary decoder or complete reference inventory. |
| src/FruitMachineLab.Runtime/Mpu4VmDefinition.cs | Strict definition plans, encoding and selected decoded operations; checked 9A64 branches and 9ED9 word literals. Extend decoding from original bytes rather than equating JSON loading with ROM decoding. |
| evidence/mpu4/definitions | Original spans, hashes and provenance for those two checked definitions. Exact-byte emission is already demonstrated for these bounded plans. |
| src/FruitMachineLab.Runtime/RomPatch.cs and tools/FruitMachineLab.RomPatch | Identity/expected-byte validation, fixed-size overlays, create-only output and hashes/diff. No allocator or general compiler. |
| tools/FruitMachineLab.VmDefinitionImage | Narrow fixed 9ED9 literal edit and identity emitter, with CLI safety tests. No general editing or integrity repair. |
| tools/Verify-RomIntegrity.ps1, tools/Capture-RomIntegrityVariant.ps1 and integrity maps/reports | Recover original ordered integrity algorithms. Natural startup repair demonstrated for the shared-award edit; general repair for definition/extension edits remains to validate. |
| tools/Capture-VmDefinitionLiteralInvocation.ps1 and its curator | Ten independent original/modified 9ED9 MAME cases, but synthetic seeded invocation, not natural gameplay or repaired boot. |
| Existing MAME capture scripts and Lua under evidence/mpu4/skill-cash | Reuse isolation, register/RAM observations and provenance conventions. A persistent live-debugger protocol and IL stepping/source maps are missing. |
| Native runtime, WPF viewer and verification fixtures | Preserve regression/research assets. No requirement to remove their captured adapters or connect new IL to their executor. |

The documented last full headless baseline is 415 groups at the integrate59
checkpoint. This pivot records existing evidence; it does not claim a new test
run or completed compiler/debugger work. See [implementation status](../IMPLEMENTATION-STATUS.md),
[ROM editing](ROM-EDITING.md) and the dated [source audit](ENGINEERING-AUDIT.md).

Natural award-image boot/controlled paid setup is recorded, but the observed
table read was 75C0, not the edited 75BE. Do not report changed-award consumption
as proved. Similarly, synthetic 9ED9 results do not close natural execution.

## Replacement milestones

The following are planned acceptance stages, with reused partial evidence noted
above. M0 is the documentation proposal; implementation stages remain open.

| Stage | Priority and acceptance |
| --- | --- |
| M0 — Focused implementation proposal | P0, this documentation deliverable. Identify reuse, gaps, candidate definition, integrity scope and Lua observation boundary. Obtain John's review and name allowed files before implementation dispatch. |
| M1 — Lossless supported decoding | P0. Decode one evidenced definition from ROM bytes into independent IL, re-encode identically and preserve the rest of the image. Check original identity, token/operand boundaries, references and unsupported/corrupt inputs. |
| M2 — First IL-to-MAME proof | P0. Change one meaningful operand from M1, repair integrity, boot and naturally execute it in MAME. Compare original/control results and unchanged stack/frame contracts. Use Lua to observe PC/Y/U/S and map the executed instruction to an IL line. No PC/RAM seeding to claim natural execution. |
| M3 — Basic build/run and debugger | P1. One action builds a reproducible ROM, reports diff/hashes, repairs integrity and launches an isolated MAME session. Generated maps are bound to the exact ROM/build. Support pause/resume, breakpoints, instruction stepping and VM call step-into/over/out across native words, nesting and interrupts with explicit unsupported cases. Minimal editor only. |
| M4 — Extension linker and new composite word | P1. Use a revision-specific confirmed mapped extension range. Allocate a new word/header/body, resolve references and call it from an existing definition through the original interpreter in natural MAME execution. Record allocation/fixup map; prove collision/overflow rejection. |
| M5 — Growable definitions and hooks | P1. Emit a larger replacement in extension space and redirect only supported entries/callers. For native hooks preserve complete displaced instructions, PC-relative meaning, incoming targets, registers/CC, stack discipline and JMP/JSR return semantics. Prove one gameplay modification, then two simultaneous modifications with deterministic allocation/composition. |
| M6 — New 6809 primitive | P1, after M4 and ABI proof. Assemble a minimal new native routine, expose a new VM word and naturally call it through original dispatch. Verify inputs/outputs, preserved registers, control/data stacks and return convention. No interpreter-loop changes unless separately justified. |
| M7 — Controlled live experiments | P1, after read-only debugger boundaries work. Paused, explicit RAM/stack/register/CC edits where supported, with address/register, old/new value, source location and build identity logged. Resume/observe; turn useful experiments into compiled edits and repeat natural fresh-boot acceptance. |
| M8 — Hardware compatibility | Required final acceptance. On original MPU4 hardware verify reset, checksums, edited/new-word behaviour, accounting/persistent state, timing and relevant peripherals. MAME success alone cannot complete this milestone. |
| M9 — Broader compiler/editor | Later. Expand certified definitions, references, assembly debugging and feature authoring from demonstrated needs. General relocation and other games/platforms need separate evidence. |

New callable functions include original words, new composite words made from
supported VM words, and new native 6809 primitives. Prefer extending the
dictionary using existing dispatch. Exact header formats, address constraints,
entry/return conventions and stack effects must be established before emission.
No new-word or primitive support is claimed today.

## Minimum next implementation slice for review

1. Select the smallest definition with an evidenced natural caller and an
   observable operand effect. Evaluate 9ED9 first because exact emission and
   synthetic comparisons exist; choose another if natural reachability makes it
   a poor slice. Record the selection and its evidence before implementation.
2. Add only the decoder/IL fields needed for that definition, without a dependency
   on ScriptExecutor. Reuse existing token/span evidence and checked encoding.
   Generate the smallest map from original/emitted sites to IL instructions.
3. Compose the explicit edit with the existing patch validation and extend the
   recovered integrity calculation only over validated ranges/field order.
   Produce separate create-only images, exact diffs, hashes and build/map identity.
4. Adapt isolated MAME launching and Lua observations to a natural fresh-boot
   control and changed run. Observe validated dispatch/return boundaries, PC,
   VM cursor Y, data pointer U, control pointer S and relevant stack/RAM values.
   PC alone does not identify the IL instruction; account for token-fetch phase.
5. Prove byte-identical unchanged build, intended changed bytes plus integrity
   fields only, original/control versus changed observable effect, source-map
   correctness and stack/frame preservation. Reject wrong ROM/unsupported
   encodings/stale maps. Save commands, exit codes and concise evidence.
6. Report the first mismatch or missing evidence. Do not expand to allocation,
   a polished editor, general relocation or native-runtime recovery to bypass it.

These are proposed implementation tasks, not dispatched work. This documentation
update does not run MAME, change schedules or start a broad implementation campaign.

## Debugger and validation contracts

Inspect mode provides observations, breakpoints and stepping. Experiment mode
explicitly mutates paused state and records every edit. Check available APIs in
the installed MAME version during implementation; do not promise unverified
register-write or stepping support. Preserve interrupt/native context and reject
ambiguous source locations rather than guessing. New primitives may expose
assembly locations alongside IL calls.

Keep source maps tied to ROM hash and build identity, including relocated/new
words. Label natural traces, static deductions, hypotheses and synthetic probes.
Save states and debugger setups can accelerate iteration but are separate from
fresh-boot natural acceptance. Never count injected state as compiled behaviour.
Keep MAME loader hash warnings separate from original firmware integrity checks;
repair the latter without bypassing the checker.

Measure compile latency and the complete edit/run/debug loop. The discussion's
0.1-second compile time and engineering-hour estimates are hypotheses, not
benchmarks, deadlines or acceptance promises.

## Frozen work and orchestration

A1–A6 autonomous scheduling/gameplay/startup goals, Live native sound ownership,
IRQ-prefix/suffix integration, native finish timing and C# peripheral simulation
are frozen indefinitely. They can remain frozen permanently without blocking
this plan. Preserve all implementation/tests/evidence and existing diagnostics.
Narrow compiler/debugger-related use of recovered facts is permitted; it does
not authorize continuation of the old native-runtime campaign.

The previous roadmap and exact resumption gates are retained in
[historical roadmap](history/PRE-IL-MAME-ROADMAP.md). Older NEXT instructions in
handoffs, recovery plans and task files are historical. Only explicit new
authorization from John may resume native execution, after evidence/state review.

Do not dispatch workers, unpause callbacks or alter durable operational checkpoints
as part of this documentation change. Future authorized tasks must name allowed
files, original evidence, measurable acceptance and unsupported boundaries.
Review actual diffs and independent checks; retain zero automatic retries and
the two-unsuccessful-attempt stopping rule. Historical commit/push permission
does not grant permission in this task.

No installations/configuration changes without John's approval. No commit,
push, publication or access changes unless requested. Preserve ROMs, MAME
settings, Ghidra projects and unrelated configuration. Keep binaries, credentials
and bulky traces untracked; cloud work must use curated repository evidence.

Headless build/verification commands remain in [README](../README.md).
Run relevant checks for implementation changes and preserve existing regressions.
The Windows diagnostic UI and eventual layout/DX rendering are later consumers
of observed backend state; polished UI and whole-machine simulation do not gate
the first IL-to-MAME proof.

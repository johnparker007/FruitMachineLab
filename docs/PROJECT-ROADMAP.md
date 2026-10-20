# Project roadmap — lossless IL, ROM compiler and MAME debugger

Operational authorization updated 18 October 2026: John authorized a continuing
supervised DeepSeek development loop, with reviewed passing increments committed
and normally pushed to the existing remote main between worker runs. Continue
after successful batches. Earlier documentation-only/no-dispatch/no-commit
restrictions below describe the original pivot, not the current authorization.
Native execution remains frozen; releases, deployments, configuration changes,
history rewrites and extension-range selection retain their approval boundaries.

Decision: 18 October 2026. This replaces the previous parallel native-runtime,
editable-VM and ROM-generation priorities. Autonomous C# gameplay execution is
frozen indefinitely, potentially permanently. Do not finish the old sound/IRQ
gates first. Existing implementation, tests, captures and evidence are preserved.

The objective is an extensible source-level editing, compilation and live-debugging
environment for original MPU4 ROMs. MAME runs the original interpreter, CPU and
machine services; original MPU4 hardware is the final compatibility target.

## Long-term objective — author entirely new MPU4 games

The ultimate product is a readable source-level development environment for
writing entirely new MPU4 games, compiling them into original MPU4 VM code,
and running them in MAME and eventually on physical MPU4 hardware.

Reuse the existing ROM's recovered VM words and native services wherever
practical: lamps, cabinet inputs, Alpha display, sound, timing and the original
firmware's execution and scheduling services. Introduce new native 6809
primitives only where existing ROM services cannot provide the required
behaviour and the necessary contracts have been proved. This does not resume
any frozen native C# execution, scheduling or peripheral simulation work.

The first target demonstration is a minimal Breakout/Arkanoid-style game or
demo using the machine's 6×8 upper-glass lamp grid. Build it in verified slices:

1. A newly authored VM definition draws a verified, changing lamp-grid pattern.
2. Two cabinet buttons move a paddle.
3. Existing timing services drive ball movement and collision detection.
4. Add destructible bricks, lives and scoring as space permits.
5. Add Alpha messages and sound effects through proved original ROM services.

The 20 October task-74 capture proves a narrower first slice: a compiled
24-byte word naturally clears four original lamp-frame RAM bits (`3F -> 3E`)
and returns through the original VM with balanced stacks. Displayed lamp output
and an interactive changing-pattern demo remain unverified. See
[natural clear evidence](recovery/IL-LAMP-CLEAR-NATURAL.md).

Keep the demo within the approved `1010-13EF` reservation for this exact ROM
revision: **992 bytes**, preserving guards `1000-100F` and `13F0-13FF`.
Report the total allocation for every new header, code and data item, reuse ROM
words, and reject overflow or overlap. A complete game with every feature is
not yet proved to fit; simplify the demo to fit before considering more space.
A different extension range still requires John's confirmation per ROM revision.

After the current growable-definition milestone (M5), prioritize small working
vertical slices toward this demonstration. Add only the IL/compiler features
each slice demonstrates it needs, rather than seeking complete ROM coverage
first. The intended authoring model may include named functions, constants,
variables, conditionals, loops, memory access and high-level service calls.
Event callbacks are optional language conveniences, not an assumed original-ROM
capability; any implementation must respect original scheduling and VM contracts.

This is a long-term acceptance target, not permission to bypass the compiler,
linker, integrity or debugger milestones, weaken verification, or invent helper
semantics. Give every slice explicit acceptance checks, preferably natural
fresh-boot MAME execution. Seeded invocation, save states and debugger writes do
not establish natural compiled-ROM behaviour. Physical MPU4 compatibility
remains a separate final hardware-validation requirement.

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

## Recorded status — 19 October 2026

This is the active status of the replacement milestones, based on curated code and
evidence at `main` `d12ce8315690c6a4ac56427defce3bd45e6d1f9a`, with the
`il-larger-replacement-build-50` static increment pending supervisor review. It
does not declare a general compiler, a complete linker/debugger or hardware
compatibility. The original milestone acceptance text below is retained; this
section records what has actually been demonstrated and what remains open.

| Stage | Recorded status | Primary evidence |
| --- | --- | --- |
| M0 — Focused implementation proposal | Complete for the original first slice. Later bounded proposals remain separate review items. | This document's dated history and `docs/ROM-EDITING.md`. |
| M1 — Lossless supported decoding | Complete only for the checked `9ED9` and `9A64` definitions. Both are decoded from identity-checked ROM bytes and re-encoded byte-identically; unsupported tokens fail. Not a general decoder. | `NineEdNineDecoder`, `NineASixFourDecoder`, `VmIlCompiler.CompileIdentity`, `evidence/mpu4/integrity/il-9a64-decode.json`. |
| M2 — First IL-to-MAME proof | Complete for the single checked `9ED9` `9EDB FF80 -> FF00` edit. Ordered integrity repair, natural fresh-boot execution of original and repaired images, and Lua PC/Y/U/S/stack observations resolved to the IL map were recorded. It is not a second edit, gameplay or paid-window proof. | `evidence/mpu4/integrity/il-natural-9ed9-comparison.json`, `il-lua-vm-trace.json`, `il-debug-caller-entry.json`; `docs/recovery/IL-LUA-VM-TRACE.md`. |
| M3 — Basic build/run and debugger | Partial. One reproducible same-size build workflow, exact-ROM-bound maps, paused read-only inspection, flat IL-node stepping, mapped caller entry/step-into (one caller each for `9ED9` and `9A64`), branch coverage and post-return rearm are implemented. Nested/recursive calls, call-step-over, arbitrary step-out, interrupt-aware boundaries, free-run continue and writes remain unsupported. | `docs/recovery/IL-DEBUG-SESSION.md`, `IL-DEBUG-CALLER-ENTRY.md`, `IL-BUILD-DEBUG-WORKFLOW.md`; focused runs record **813**, **253** and **74** checks with 0 failures. |
| M4 — Extension linker and new composite word | Complete for one static allocation and one natural call: header `1010`, copied `9ED9` body `1012-101F`, single `9F14` `9ED7 -> 1010` redirect and ordered `FFD1-FFD5` repair, naturally reached with all thirteen observed phases. Not a general linker, relocation or multi-word allocator. | `il-composite-build.json`, `il-composite-natural.json`; `docs/recovery/IL-COMPOSITE-BUILD.md`, `IL-COMPOSITE-NATURAL.md`. |
| M5 — Growable definitions and hooks | Open, with a **static** prerequisite now complete. The corrected task49 design is built and verified: header `1010 = 00F8`, body `1012-1025 = 795BFF80787E795BFF807AAF795B0001787E792F`, seven nodes, three inline operands, one final `792F` at `1024`, and only the `9F14` `9ED7 -> 1010` caller redirect. The rejected task48 append-after-return payload fails by reachability. The image is not naturally executed, and no gameplay modification, native hook or two-simultaneous-modification proof is recorded. | `evidence/mpu4/integrity/il-larger-replacement-build.json`; `docs/recovery/IL-LARGER-REPLACEMENT-BUILD.md`. |
| M6 — New 6809 primitive | Complete for one direct native primitive only: token `1010 = 1012`, handler `1012-101A = ECC4C38000EDC40EFC`, single `9F14` redirect, natural entry/result/outer return, `U`/`S` unchanged across the handler and no new save frame. `DP=0` is a **static deduction** from the exact `0EFC` direct `JMP` and live post-handler `PC=00FC`, not a direct live measurement. The intentional result change `0000 -> 8000 -> FFFF` is not original `9ED9` preservation. No general primitive assembler or ABI coverage is claimed. | `il-native-primitive-build.json`, `il-native-primitive-natural.json`; audit **185 checks, 0 failures**; `docs/recovery/IL-NATIVE-PRIMITIVE-NATURAL.md`. |
| M7 — Controlled live experiments | Open. The debugger is read-only; no paused RAM/register/CC write mode is implemented. | `IL-DEBUG-SESSION.md` limitations. |
| M8 — Hardware compatibility | Open. No physical MPU4 validation is recorded. | None. |
| M9 — Broader compiler/editor | Open. No general decoder, editor, relocation, banking or second platform is claimed. | None. |

The last recorded full verifier result remains **417 groups**. The larger
replacement task reran it successfully with 417 groups and added **11** focused
larger-replacement IL checks while preserving the existing 20/9/15/14/9/9 IL
groups; the worker CLI/static checker passed **21 checks**. The earlier
`il-composite-immutability-34` log and task45/46 build notes are retained. The
**415-group** integrate59 result is historical. The accepted `813`, `253`, `74`
debugger checks, the `185`-check native primitive audit and the composite natural
reanalysis remain separate focused evidence, not a full-suite replacement.

Natural award-image boot/controlled paid setup is recorded, but the observed
table read was `75C0`, not the edited `75BE`. Do not report changed-award
consumption as proved. Separately, the bounded natural `9ED9` original/changed
call, the single allocated composite call and the single direct native primitive
call are recorded; none is a full-game, paid-window or hardware claim.

## Reusable assets and current gaps

Paths in this table are repository-relative.

| Asset | Reuse and limits |
| --- | --- |
| evidence/mpu4/VM-SCRIPTS, docs/recovery/DEEP-ANALYSIS.txt and evidence/mpu4/maps | Addressed listings and interpreter/header/token evidence. Not a general dictionary decoder or complete reference inventory. |
| src/FruitMachineLab.Il | Independent IL decoders/compilers for `9ED9` and `9A64`, ordered integrity repair, extension allocator/emitter, one static composite build, one direct native primitive build and one corrected static larger-replacement build. Each capability is bounded to its checked definition/edit; it is not a general decoder, linker or assembler. |
| evidence/mpu4/definitions and evidence/mpu4/VM-SCRIPTS | Original spans, hashes, token listings and provenance for the checked definitions. Decoding is from identity-checked ROM bytes; listings remain oracles, not source. |
| src/FruitMachineLab.Runtime/RomPatch.cs and tools/FruitMachineLab.RomPatch | Identity/expected-byte validation, fixed-size overlays, create-only output and hashes/diff. No allocator or general compiler. |
| tools/FruitMachineLab.VmDefinitionImage, IlBuild, IlNativePrimitiveBuild and IlLargerReplacementBuild | Narrow checked edit/build CLIs with safety tests. The native-primitive CLI emits the single reviewed token/handler and caller redirect; the larger-replacement CLI emits the corrected 22-byte allocation and caller redirect. Neither is a general assembler. |
| tools/Verify-RomIntegrity.ps1, tools/Capture-RomIntegrityVariant.ps1 and integrity reports | Recovered ordered integrity algorithms. Natural startup repair is demonstrated for the shared-award edit and the checked `9ED9`/composite/native-primitive builds; arbitrary definition/extension repair remains unsupported. |
| tools/Capture-VmDefinitionLiteralInvocation.ps1 and its curator | Ten independent original/modified `9ED9` synthetic seeded MAME cases. Natural original/changed `9ED9` execution is recorded separately. |
| tools/Start-IlDebugSession.ps1, tools/Invoke-IlDebugCommand.ps1 and tools/lua/IlDebugSession.lua | Paused read-only session with exact ROM/map binding, inspect, flat node stepping, mapped caller entry/step-into and post-return rearm. No call-step-over/out, nesting, interrupts or writes. |
| Composite/native natural capture scripts and observers | One accepted natural composite call and one accepted natural direct-native-primitive call, each from the checked `9F14` caller with the tracked replay. Single-capture evidence; no general capture engine. |
| Native runtime, WPF viewer and verification fixtures | Preserve regression/research assets. No requirement to remove their captured adapters or connect new IL to their executor. |

The last recorded full verifier result is **417 groups**; the **415-group**
integrate59 result is historical. See [implementation status](../IMPLEMENTATION-STATUS.md),
[ROM editing](ROM-EDITING.md) and the dated [source audit](ENGINEERING-AUDIT.md).

Natural award-image boot/controlled paid setup is recorded, but the observed
table read was `75C0`, not the edited `75BE`. Do not report changed-award
consumption as proved. The bounded natural `9ED9` original/changed call, single
composite call and single native primitive call are recorded separately; none is
a full-game or paid-window proof.

## Replacement milestones

The following table retains the original planned acceptance text. Actual bounded
progress and the still-open scope are recorded in the status table above; this
section is not a claim that every acceptance condition is met.

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
Bounded support is now recorded for one copied composite word and one direct
native primitive. A general composite/new-word assembler, arbitrary headers,
relocation and broad ABI coverage are not claimed.

## Historical first-slice proposal (18 October 2026)

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

These steps are retained as the historical first-slice plan. The bounded `9ED9`
decode/emission, natural original/changed call and IL-resolved debugger evidence
recorded above supersede them as the first proof. They do not authorize a broad
implementation campaign.

## Larger replacement — corrected static build

M5 remains open. The task48 candidate is rejected history: it retained the
original terminal `792F` before the appended literal/add, making the proposed
addition unreachable. The corrected task49 design is now statically built and
verified from the original ROM only. It allocates `1010-1025` (22 bytes), emits
header `00F8` and body `795BFF80787E795BFF807AAF795B0001787E792F`, and
redirects only `9F14` `9ED7 -> 1010`. Seven nodes, three inline operands and one
final `792F` at `1024` are reachable in address order; task48 fails the same
reachability rule at `1020/1024/1026`.

The static image has 22 unrepaired changes and 27 final changes, fields
`E93F3C61B5`, and SHA256
`F693D70A73F1C12857CD64CA9DB9D68DE9BBC1888101ABC283FA2752C094B523`. The
final-image-bound map records 17 static phases. This is a **static build and
verification**, not natural execution or gameplay, and it is not accepted here.
M3 call-step-over/out remains independently open; general nesting is not proved.
A natural fresh-boot capture is a separate future dispatch after supervisor
review.
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

The continuing supervised loop authorized on 18 October remains current: reviewed,
passing increments may be committed and normally pushed to the existing remote
main between worker runs, and successful batches are review points rather than a
stop condition. This reconciliation task itself made no git mutation. Native
execution stays frozen; releases, deployments, repository-access changes and
history rewrites still require John's explicit authorization. Future tasks must
still name allowed files, original evidence, measurable acceptance and
unsupported boundaries. Review actual diffs and independent checks; retain zero
automatic retries and the two-unsuccessful-attempt stopping rule.

No installations/configuration changes without John's approval. Preserve ROMs,
MAME settings, Ghidra projects and unrelated configuration. Keep binaries,
credentials and bulky traces untracked; cloud work must use curated repository
evidence.

Headless build/verification commands remain in [README](../README.md).
Run relevant checks for implementation changes and preserve existing regressions.
The Windows diagnostic UI and eventual layout/DX rendering are later consumers
of observed backend state; polished UI and whole-machine simulation do not gate
the first IL-to-MAME proof.

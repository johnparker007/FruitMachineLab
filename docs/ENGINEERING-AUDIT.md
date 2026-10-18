# Source audit — 17 October 2026

18 October strategic status: this is a dated audit of the preserved native
implementation, not the current development mandate. Its priority rankings,
A/B/C stage references and proposed native-runtime work are historical.
[PROJECT-ROADMAP.md](PROJECT-ROADMAP.md) now directs lossless original-VM IL,
ROM compilation and MAME Lua debugging; native C# execution is frozen indefinitely.
The IL/compiler/debugger must not depend on that executor.

Later bounded evidence includes checked 9A64/9ED9 emission, synthetic changed
9ED9 invocation and shared-award integrity repair/startup. These do not establish
a general decoder/compiler, natural edited-definition execution, extension
allocation, new words, live IL debugging or physical hardware compatibility.
See [ROM-EDITING.md](ROM-EDITING.md) and [implementation status](../IMPLEMENTATION-STATUS.md)
for later checkpoints; historical absence/next-work statements below describe
the audited snapshot.

Inspected clean `main` at `2916fa1` (local `origin/main` agreed, without fetching).
Work branch: `codex/rom-patching-roadmap`. This audit supersedes older roadmap
priorities, not the qualifications in the recovery reports. Names and listings are
reconstructions; a labelled body is not proof of complete behavioural coverage.

## Execution architecture

The target is the MC6809 MPU4 `m4addr`, A6L 0.1 set 1. The 65536-byte image has
SHA1 `402d1518bb78fdc489b06c2aabc771e5ce151847`. MPU4 machine services live in
Runtime; game-specific bindings, state seeds and verification live in Adders;
Diagnostics is a separate Windows WPF project. Verification is a console executable,
not a `dotnet test` test-framework project. Both headless and Windows solutions exist.

| Concern | Actual implementation / evidence |
| --- | --- |
| Original dispatch | `recovery/DEEP-ANALYSIS.txt`, interpreter section: native 76C7, template at 7927 copied to RAM F8–FF; FC fetches a big-endian execution-token address, then jumps through its code-pointer header. F8 pushes Y and enters a nested definition. Y is cursor, U data stack, S control stack. |
| PC VM execution | `src/FruitMachineLab.Runtime/RecoveredScript.cs`: `Instruction`, `RecoveredScript`, `ScriptExecutor.Execute`. Text listings in `evidence/mpu4/VM-SCRIPTS` become addressed operations. **It executes decoded operations, not arbitrary original ROM bytes.** Embedded operands, targets and some constants are already decoded into the listing. |
| Definition boundaries | `RecoveredScriptCatalog.Owner` assigns listed sites to their listing; duplicate sites fail. Not a complete ROM dictionary parser, automatic length detector or relocatable assembler. `SkillCashData.ResolveWord` supplies selected aliases/shared-body semantics. |
| Literals / branches | `Instruction.Value`/`Branch`, executor operation cases. Listings distinguish inline byte/word literals and forward/backward byte branch payloads. `C699.txt` C6C5→C6AB and `C6FC.txt` C716→C71B are concrete examples; odd-aligned sites are valid. A listing alone is not a lossless encoding. |
| Arithmetic / memory | `Machine`, `Cell`, `Mpu4Memory.Move`: 64KiB memory, big-endian wrapped word reads/writes, wrapping 16-bit cells, signed comparisons and Forth FFFF/0000 flags. Runtime memory itself does not enforce a hardware bus or ROM write protection. |
| Physical frames | `Machine.DataStackBase`, `SyncDataToMemory`, `SetDataPointer`; `VmControlStack` maps S call, local and loop frames, F4/F6 frame pointers and 76BD release continuation. C# iterator continuations coexist with these physical frames. |
| Native words | `AddersNativeWords.Handle` and collection bindings dispatch recovered helpers. Many are semantic C# translations. `NativeRoutineExecution` executes explicit effect/branch plans, derives durations with `M6809InstructionTiming`, suspends at supported instruction boundaries and requires balanced child returns. **This is not a general 6809 CPU interpreter.** |
| Timing ownership | `SkillCashLiveSession.AdvanceTo` composes VM, output/input services, motors, logical sound and timer3. `AddersTimedCollectionExecution` separately composes collection VM and timed payout; enclosing host supplies clock/input/IRQ and some helper budgets. No whole-machine single-owner causal clock yet. |

Reviewed listings are useful starting material for a common editable representation:
retain original sites/tokens and opaque bytes, then add checked operands/encoding.
Do not build a second C# rules implementation. Data patches can already feed the
native VM and PC memory; changed decoded code/literal operands will require a
listing decode/rebuild path before the PC executor can consume them reliably.

## Gameplay coverage

| System | Source and present evidence boundary |
| --- | --- |
| Paid entry / credits / stake | Live executes recovered preplay/AB64 listings, with `AddersStakeAccounting` and NVRAM helpers. Verification's “Three generated paid games” retains one state and debits each Start. Captured seeding/pacing remains; three selected games is not ten capture-free games. |
| Paid reels / evaluation | `AddersReelMotion`, `AddersReelHardware`, `AddersReelSymbols`, `AddersNudgeAvailability`; translated native motion and symbol/result helpers plus recovered calling scripts. Natural and synthetic verification cases coexist. Not all outcomes covered. |
| Nudges | Live selected physical NUDGE controls, availability/preparation/motion/improvement/return and award transfer execute. See NUDGE-*-PASS reports. Explicit unsupported results remain. |
| Feature entry / board | `BoardSelectionState`, `BoardMovementState`, `BoardLinkState` load static tables and selected entry snapshots. Original VM selections/movement and selected snake/ladder routes execute with translated lamps/motors. Entry choices are diagnostic checkpoints, not reset startup. |
| Skill Cash / awards | Recovered C721/C699/C6FC and translated helpers, table 75BD, normalization 9F6A, NVRAM/win animation. Six default awards have tests. `SkillCashReplay` injects recorded inputs explicitly for verification; Live uses physical panel state with remaining timing adapters. |
| Bank / collection | `AddersCollectionTransfer`, `AddersCollectionExecution`, `AddersTimedCollectionExecution`, payout/accounting/sound plans. Selected headless collection paths retain state, prompt, sample Collect and pay. Live GUI has not adopted this owner. Synthetic 100 transactions are not 100 played games. |
| Return to idle | Selected paid-return and board loops reach real prompts with retained state. This does not establish unrestricted paid play, startup, collection or attract-mode coverage. |

## Runtime dependency inventory

Locations below are repository-relative. This inventories the current execution
owners and groups repeated fields by their consumer; it does not treat every byte
in a capture file as a runtime dependency. `SkillCashLiveSession`'s direct reads
and the `SkillCashData` extension/feature/alpha/scan static range loads now have
field-level classifications and a strict `RuntimeEvidencePolicy`; strict
construction fails early until recorded timing/results have causal replacements.
Reads through other helpers and owners below remain unenforced.

| Consumer / recorded information | Correctness and runtime classification | Causal replacement / priority / difficulty |
| --- | --- | --- |
| `SkillCashLiveSession` constructor: `cpu-interrupts.json.timer1_handler_entries` | Required Live accepted outer IRQ schedule; affects execution/input order | Timer1 assertion plus current instruction/mask and full outer handler; P0, high |
| Same constructor: `intervals`; `CapturedCycleTimeline`, `CapturedInterruptOccupancy` | Required Live VM/delay occupancy; repeating captured template | Full native/VM CPU ownership with generated nested occupancy; P0, high |
| Same constructor and `CpuCost`: site/token dictionaries in cpu-interrupts, jackpot-probe, board-result, board-selection, dice and all selected `nudge-*`/`paid-flag-*` files | Required fallback durations; source-derived primitives do not remove fallback helpers. Missing costs throw | Stage only required foreground/helper paths, preserve true register/mask boundaries; P0/P1, high |
| Same constructor: equivalent-timing-token aliases in extension, nudge and dice maps | Static declared equivalences select captured costs; not independent CPU derivation | Source-derived paths rather than aliasing observations; P1, medium |
| `SeedFeature`, `SeedScan`; feature-replay.Initial/Native, shared-timing.InitialScan, alpha and compensation exports | Required checkpoint RAM/stacks/local frame/RNG/clock/scan state. Static data and recorded state share files | Explicit documented startup state contract, later original reset/init chain; A3 permits declared checkpoint, A6 high |
| `SkillCashCallerState.Apply`, `BoardSelectionState.Apply`, `BoardLinkState.Apply` | Selected entry RAM/physical stack/RNG/continuation restores; runtime checkpoint, not generated transition. Apply is entry setup, not evidence of per-game resetting | Retain state across natural transitions; then reset startup; P1, high |
| `BoardLinkState.LoadIc8Entry`: nudge-ic8 entry_io, nudge-status, nudge-stake | Initial PIA/status/accounting checkpoint mixed with static tables | PIA DDR/control/pin and accounting initialization; P1, medium/high |
| Live constructor: `irq-service-data` ROM ranges and initial PIA/drive/callback/stopped timer3 snapshot | Static firmware data legitimate; initial peripheral state captured and required | Generate reset/PIA/timer state, preserve phase; P1/A6, high |
| Live constructor: `lamp-frames.json.Responses`, initial frames; `AddersBackgroundServices.Mame6809CompatibilityResponse` | Characteriser/MAME compatibility adapter and seeded frame memory affect correctness; not recovered physical PAL | Isolate compatibility target and recover physical PAL contract separately; P1/C7, high |
| `Mpu4ChoiceStreamScheduler.RestoreQueuedNativeTasks`, `BoardLinkState.ResolveSoundContinuation` | Resume selected captured task continuation; subsequent logical stream execution generated. Not complete native sound service ownership | Integrate existing `AddersNativeSound` native task owner with Live and foreground scheduling; P1, medium/high |
| `AddersTimedCollectionExecution` wordCycles/alphaCycles, port delegates; selected collection hosts | Explicit host budgets/inputs, often synthetic in tests. Not necessarily recorded but still externally supplied causal assumptions | Integrate real clock, sampled ports and timed foreground/native sound owners; P1, high |
| `SkillCashData`, Board* LoadData, ROM ranges in maps; decoded VM-SCRIPTS | Static recovered executable/data content, legitimate runtime assets; `SkillCashData` extension/feature/alpha/scan ranges are policy-classified, other loaders and some embedded constants duplicated in C# remain unenforced | Common validated ROM-derived memory/decoded representation; B1/B2, medium |
| `SkillCashReplay`, *Verification, `OutputPlayback`, `SkillCashPlayback` | Trajectory/input/expected stack/lamp/alpha traces are verification/playback dependencies. Not autonomous runtime claims | Retain as oracle; no replacement required |
| timer-deadlines.json and shared-timing.Events | Reference-only after prior scheduling work; Live still reads other fields of shared-timing | Keep differential tests; no new scheduler dependency |

There is no capture-free ten-game mode. Live's unknown operations and missing
pacing fail explicitly, but no central policy currently prohibits all capture
reads. The new ROM patcher reads no gameplay trace or snapshot.

## CPU / device status

`M6809InstructionTiming` and `M6809IrqEntry` cover selected encodings and ordinary
IRQ frames; the staged plans supply semantics. `Mpu4Timer1Clock` and
`Mpu4Timer3PhaseClock` generate timer behaviour; selected timer3 instruction-boundary
acceptance/dispatch/lamp return is integrated. Outer timer1 acceptance/occupancy
and atomic VM/native work still prevent a general causal CPU/peripheral model.
The nineteen-window timing comparisons are bounded proofs, not Live-wide coverage.

`Mpu4PanelInput` supplies Start/Take/Collect/Nudge levels and sticky samples.
PIA access plans model selected registers, DDR/control and reads/writes; Machine
does not route every memory access through complete PIA devices. Coin idle/decode
plans have native comparisons; active coin insertion/alarms are incomplete.
`BarcrestStepper` and `AddersReelHardware` generate drive/optic behaviour from
seeded positions; not independent homing/reset. Lamp scan/frame/request classes
and `Mpu4Alpha` model software outputs, not electrical fidelity. Native sound plans
and `AddersNativeSound` cover selected task lifecycles; Live still has the logical
scheduler. Audio synthesis is not implemented. Serial plans have bounded synthetic
native comparisons; full wire/IRQ service is open. Payout queues/debits/pulses are
software effects; physical delivery and machine-wide collection are unproven.
Reset/init is analysed in DEEP-ANALYSIS but not independently executed end to end
by the PC runtime. A single clock is a reasonable incremental direction, not a
justification for replacing the working runtime wholesale.

## ROM structure and rebuilding

`evidence/mpu4/maps/rom-layout.json` records **partial** facts, not an allocation
map. Native code, data and VM words are interleaved. Word headers contain absolute
code pointers; token streams refer to absolute word addresses. Relative branches
carry separate payloads. Shared native-entry bodies and inline display/lamp bytes
make naive disassembly/reassembly unsafe. No complete dictionary headers/naming
format, free-space certification, relocation inventory or ROM integrity repair is
implemented. The general MPU4 map supports banking; this selected 64KiB patch does
not switch banks or establish safety for larger images.

Known table 75BD has multiple consumers; change it as a shared table, not a private
feature rule. The new patch spec preserves size/addresses and all other bytes.
DEEP-ANALYSIS identifies startup ROM sum/XOR validation: a loader checksum warning
and a game firmware integrity failure are different things. Neither may be silently
bypassed. See ROM-EDITING.md for measured MAME results and remaining boot work.

## Build and verification baseline

Windows 10 x64, SDK 9.0.313, net8.0 targeting packs already installed. No installation,
tool configuration, MAME settings or Ghidra changes made. No `.github` workflow
exists. Headless projects build independently of WPF, with no external package
references. Curated evidence is tracked; proprietary ROMs and bulky traces are not.

Baseline commands: `dotnet build FruitMachineLab.Headless.sln --no-restore`
(0 warnings/errors); `dotnet run --project tests/FruitMachineLab.Verification --no-build -- .`
(353 groups passed). Most suite groups use curated natural or synthetic MAME
evidence; arithmetic/stack/device semantics and synthetic execution tests also run
without external ROM/MAME. The suite as a whole requires the curated repository
evidence, not an installed emulator. GUI smoke tests are separate opt-in modes.
See ROM-EDITING.md for new tests and exact reproducible patch/capture commands.

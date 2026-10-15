# First completed main-reel nudge and reconstruction preservation

15 October 2026. Live now executes one main-reel nudge after TAKE NUDGEPOT and
NUDGE1/2/3. The selected reel moves six positions, requested offsets are cleared
by native cleanup, remaining nudges and pot change from3 to2, and accounting
stays zero. Text diagnostics show main-reel positions/symbols and motor state.
Actual mid-motion Pause/Resume preserves full memory, VM state and virtual time.

Execution stops at B339 before an unresolved read of native CPU-stack residue.
It does not yet return to a reusable nudge prompt or award a reel result. This
bounded first-motion milestone is not complete nudge play or a playable machine.

## Preservation audit and policy

John's agreed priority remains complete PC gameplay. The eventual reconstructed
development kit aims for a byte-identical ROM baseline, then editable symbolic
native/VM source for hardware ROM testing. No assembler, compiler, editor or
relocation system is being built now; recovered text is not original author source.
The roadmap and handoff retain this policy.

The existing conventions already provide:

- native/<address>.json: recovered entry/name/body size, assembly text and
  decompiler output, often with reviewed mechanical comments;
- VM-SCRIPTS/<entry>.txt: ROM sites, token IDs, decoded operands/branches,
  call/body/native addresses and observed/static qualifications;
- maps/*.json: selected exact data ranges, ROM identity, semantic roles and
  implementation relationships;
- skill-cash fixtures/sidecars: canonical/raw digests, reference phase inputs,
  source hashes, synthetic/natural classification and capture commands;
- dated recovery reports and the curated-manifest hash inventory.

Audit gaps: native JSON assembly generally lacks exact instruction bytes; decoded
VM text alone does not establish complete operand/embedded-data coverage; Ghidra
body_size is not necessarily a contiguous range. Cross-links and calling
conventions are uneven. Existing native exports are useful but are not portable
exports of all Ghidra symbols/namespaces, comments, references and data definitions.
Full ROM coverage, unresolved data/code regions and relocation constraints remain
incomplete. None of those formats establishes a lossless rebuilt-ROM baseline.

This pass extends the existing disassembly exporter and adds a narrow curator
alongside the other Curate tools. maps/nudge-encoding-checkpoint.json checks627
native linear-disassembly rows byte-for-byte against the SHA1-verified ROM and
preserves seven exact VM spans, their token sites and intervening bytes. It links
five existing native function exports with hashes/names, calling conventions,
dictionary entries7659/82BB, C# implementations, data maps and verification.
Annotations and branch/pointer/body references remain linked to existing listings.
Native linear disassembly is not proof of code/data typing or reachability. VM
span partition preserves bytes but does not prove each symbolic operand or
relocation rule. The checkpoint is selected coverage, not a whole-ROM lossless
listing or successful reassembly. Unresolved regions are explicitly retained.

No live Ghidra connector/API is exposed in this session. The existing saved
exports were read without altering the original project; selected symbols and
comments already in those exports remain tracked. Fresh portable symbol/comment/
data-definition export is therefore an explicit gap, not a completed checkpoint.
No Ghidra installation, configuration change or original project write was made.
When access becomes available, export these fields reproducibly at meaningful
checkpoints rather than leaving essential discoveries only in the project/chat.

## Natural motor evidence

A fresh isolated MAME campaign extends the prior physical TAKE/Nudge1 path through
B34E. No state/register/ROM edits are made. Native capture retains135 observations
through cleanup:60 services and eight optic reads. The translated motor matches
every captured record, flags, phases, NVRAM bytes and checksum, and generated
hardware optics match the captured bits. Reel1 moves12→6; other reels stay put.
Read-only device saved-item observations independently check the idle motor
position/phase/pattern seeds at square22. This verifies reuse on this main-reel
path rather than assuming dice-only recovery transfers unchanged.

The connected reference checks750 VM observations through B339,63 lamp requests
and complete frame results,144 sound commands with timing/state and65 alpha bytes.
It independently checks the earlier 553-observation request prefix and preserves
the 141 write-derived local masks from preparation.
The raw source continues through B34E; the curated VM segment intentionally stops
earlier. All native service/cleanup observations are already complete before
that boundary. The reference-only adapter services the native blocking2BEB wait
inside its observed operation boundary; it does not assign a captured reel outcome
or optic waveform into Live state. Earlier dice comparisons remain unchanged.

B306/B308 decrements BE; when BD=15hex, B317 also decrements BF. The newly executed
7659 dictionary entry points to native765B: DEC [,U++] followed by JMP direct FC.
The translation consumes its address cell and retains8-bit wrap, including0→FF.
Selected byte encodings and a focused verification cover this primitive.

## Unresolved local-byte read

After completion, B339 pushes local-frame offset2 and B33B fetches its byte.
The path has not initialized that byte. On the captured native machine the byte
is8F; the current runtime sees0B from different native CPU-stack residue. B33D
branches on it, influencing later timing. This is an observed dependency, not a
confirmed ROM bug or an invitation to initialize it. The existing undefined-word
masks concern different bytes and cannot justify hiding this used value.

The VM comparison and Live stop before the fetch. No recorded residue value is
injected, no new mask is applied, and no default boolean/timing is invented.
Resolve the relevant native S-stack save/restore writes or provide a separately
qualified hardware boundary before resuming beyond it. The raw tail is preserved
for that work. This non-obvious behaviour is also in the encoding checkpoint and
semantic map, not solely in chat.

## Live implementation and verification

The existing translated motor/profile/hardware model now executes the main-reel
path under virtual IRQ service. The2BEB refresh suspends actual VM progress while
the motor is busy; native cleanup completes before symbol refresh. Nudge movement
has separate diagnostic state rather than creating a fake dice request. All
game logic stays in the headless runtime/Adders projects; UI renders state and
routes momentary sampled controls. Input release, capture failure/loss, focus
loss and pause behaviour are retained.

Live tests cover each of three input controls: only its selected main reel moves
six positions modulo96, all requests clear, both counts become2 and awards stay0.
They check actual mid-motion memory/time freeze and Resume. Natural MAME service
proof is specifically Nudge1; Nudge2/3 have Live tests and the same recovered
input/motor code, not separate claimed natural captures. CPU/IRQ pacing remains
the declared provisional adapter; exact CPU/scan timing equivalence is not added.

127 headless groups pass. Headless and isolated WPF builds succeed. Eight WPF
smoke modes pass, including updated real-time nudge tests for all three controls,
mid-motor pause/resume, rendered position/count state, released inputs and restart.
The keyboard-handler versus synthesized mouse-held limitation from the input
report remains: mouse-held acceptance is not claimed automated. Separate playback,
Skill Cash, jackpot, dice roll, ladder/snake and board continuation checks pass.

## Reproduction

```powershell
./tools/Capture-SkillCash.ps1 -MameExecutable <mame281.exe> -RomDirectory <rom-directory> -RunDirectory <fresh-run> -FullFeature -NativeSound -NativeInput -NativeLampFrames -NativeAlpha -CpuInterrupts -BoardLink Ladder -ContinueBoard -Availability -NudgeEntry -NudgePrompt -NudgeRequest -NudgeMotion
./tools/Curate-DiceMotion.ps1 -RunDirectory <fresh-run> -RomPath <a6ls.p1> -Nudge
./tools/Curate-BoardLink.ps1 -RunDirectory <fresh-run> -LinkKind ladder -Continuation -Availability -NudgeEntry -NudgePrompt -NudgeRequest -NudgeMotion
./tools/Export-MameDisassembly.ps1 -MameExecutable <mame281.exe> -RomDirectory <rom-directory> -RunDirectory <fresh-disassembly> -NudgeCheckpoint
./tools/Curate-NudgeEncodingCheckpoint.ps1 -RomPath <a6ls.p1> -DisassemblyDirectory <fresh-disassembly>
dotnet build FruitMachineLab.Headless.sln --no-restore
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .
```

The native curator's -Nudge flag writes separate nudge artifacts and does not
replace dice evidence/data. ROM binaries and bulky traces remain outside Git.
Next: recover B33B's native-stack residue dependency, then complete the return to
B403 or the actual result route, retaining state and accounting across nudges.
Preserve byte/semantic/export links for facts found during that work. No commits,
pushes, installations, configuration changes or cloud access were performed.

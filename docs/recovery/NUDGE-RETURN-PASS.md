# Nudge return and three-nudge sequence

15 October 2026. Live now returns to the nudge prompt after a completed movement.
Three momentary NUDGE 1 presses retain machine state, move reel 1 from 12 through
6 and 0 to 90 (modulo 96), and consume remaining nudges BE and pot BF from 3 to 0.
Execution stops explicitly at B749 before post-nudge improvement/result routing.
This is not yet complete nudge-result play or a complete playable machine.

## Resolved native save-area dependency

The previous B339 boundary is resolved without assigning a captured byte or
initializing the local frame. A fresh natural MAME run watches writes to
078B..0793 from the E247 feature-entry boundary. Its final write to 078D is native
4A8C's PSHS PC,Y,D, reported after the instruction at PC=4A8E. D is 008F, the
lamp pattern argument. At that call the physical VM S is 0796; the gateway and
native save sequence place D at S-10=078C, Y at 078E and saved PC at 0790.

The preceding VM call is 9ADF/832B with pattern 008F and range 732C..7335.
Gateway 77A8 consumes D, loads the native entry, saves Y/X, consumes end/start
into Y/X and calls through its saved pointer. Native 4A8C saves PC,Y,D before
iterating the lamp range. The later nine-byte B730 allocation makes F4=078B;
offset +2 reuses the saved pattern's low byte at 078D. B339/B33B reads it and
B33D takes the nonzero branch. There is no new write to that byte after allocation.

Mpu4LampRequests now preserves this selected native save area relative to the
actual control-stack pointer, with the actual pattern/end and native saved PC.
It does not seed 078D or assume a fixed local-frame address. The high D byte
follows the gateway's F1 load/conditional OR mechanics. This is a partial,
demonstrated native footprint, not full register/CPU-stack emulation. Other
unmodeled transient save areas remain possible. Original behaviour is retained;
the uninitialized read has not been classified or repaired as a ROM bug.

The existing 141 write-derived masks for different local bytes remain unchanged.
No mask or normalization was added for the used byte at offset +2.

## Connected natural references

- nudge-return.json: 2,817 canonical VM observations, 67 lamp requests and frame
  results, 157 sound commands and 111 alpha bytes, through the next B403 prompt.
  Its first 750 observations independently match nudge-motion-vm.json.
- nudge-sequence.json: 7,785 canonical VM observations, 148 lamp requests and
  frame results, 462 sound commands and 195 alpha bytes through B749. Its first
  2,817 observations independently match the returned-prompt fixture.
- nudge-sequence-native.json: 727 native observations, including three preparations,
  three cleanup completions, 24 optic reads and idle service observations. The
  reference adapter executes the translated motor and independently generates
  optics through all three movements. Idle services are retained in the fixture;
  they are not claimed as complete CPU-register comparisons.

Inputs are physical MAME BLACK2 pulses, without ROM/RAM/register edits. The
repeat driver sends Nudge1 once at each displayed positive count. Live uses
the actual sampled input levels; no recorded player events are substituted.
The earlier single-motion native reference and all dice references are retained.

The post-motion path additionally exercises token 7A15, native 7A17: LDY ,Y
loads its inline absolute target, then BRA 7A0D removes the current eight-byte
loop frame, restores F6 from S+6 and resumes NEXT. B42D's target is B433. The
translation retains the data stack, requires the current frame at S, removes
only that frame and preserves an outer loop. Canonical reference observations
verify the resulting physical S/F6 and subsequent caller return.

One exploratory sequence capture with the additional stack watchpoint ended in
an external MAME access violation before completion. It is not a reference for
the completed sequence. The successful retry omitted that extra watchpoint and
completed with exit code 0. The separate completed return capture supplies the
stack-write proof. No MAME settings or installation were changed.

## Byte and semantic preservation

The existing exporter/encoding checkpoint now includes aligned 77A8, 4A8C,
7A17 and 7A0D disassembly. All 657 selected native rows and nine VM spans are
checked against the hash-verified ROM. Dictionary 7A15 includes its exact header
and native bytes; B403 preserves the inline B433 operand. The selected data map
now includes 9BD8's header and 9BDA's 7328/7325 lamp-range pointers.

nudge-encoding-checkpoint.json also records 61 natural stack watchpoint writes,
the last producer, raw source hash, semantic explanation and C#/verification
links. Existing function exports and names are linked, including 77A8, 4A8C,
4A90 and 7A02. This extends existing conventions; it is not a whole-ROM lossless
decode or a successful rebuild. Fresh Ghidra symbol/comment/data-definition
export remains unavailable through the exposed tools. The original project and
analysis workspace remain untouched. Full symbolic toolchain work stays deferred.

## Live and verification scope

The headless runtime owns execution, motor state and input handling. The WPF
app displays the returned prompt/counts through the existing output interface.
All three nudge controls have first-movement and return tests; repeated Nudge1
has a natural three-movement reference and Live exhaustion test. Separate
natural repeated Nudge2/3 captures and post-nudge awards are not claimed.

132 headless groups pass. Headless and isolated WPF builds succeed. All eight
WPF smoke modes pass; the nudge mode also performs a complete three-press Nudge1
sequence, checks released inputs, captures the explicit B749 stop and restarts.
Mid-motor Pause/Resume still freezes VM memory and virtual time. The nudge smoke
uses focused keyboard handlers for acceptance and tests mouse-capture release;
automated held-mouse acceptance remains outside its claims. Existing provisional
CPU/IRQ pacing and earlier alpha-timing qualifications remain unchanged.

To test manually, select Ladder animation: natural entry (DBC4), enable
continuation, start execution and press TAKE FEATURE at square 22. Press/release
NUDGE 1 at each prompt. Counts become 2, 1, then 0, followed by the explicit
post-nudge recovery stop. NUDGE 2 and 3 also execute their selected reel; other
combinations may reach still-unrecovered result/improvement paths.

## Reproduction and continuation

```powershell
./tools/Capture-SkillCash.ps1 -MameExecutable <mame281.exe> -RomDirectory <roms> -RunDirectory <fresh-return> -FullFeature -NativeSound -NativeInput -NativeLampFrames -NativeAlpha -CpuInterrupts -BoardLink Ladder -ContinueBoard -Availability -NudgeEntry -NudgePrompt -NudgeRequest -NudgeMotion -NudgeReturn -NudgeStack
./tools/Curate-BoardLink.ps1 -RunDirectory <fresh-return> -LinkKind ladder -Continuation -Availability -NudgeEntry -NudgePrompt -NudgeRequest -NudgeMotion -NudgeReturn
# For a sequence capture omit NudgeStack and add NudgeSequence, then:
./tools/Curate-DiceMotion.ps1 -RunDirectory <fresh-sequence> -RomPath <a6ls.p1> -Nudge -Sequence
./tools/Curate-BoardLink.ps1 -RunDirectory <fresh-sequence> -LinkKind ladder -Continuation -Availability -NudgeEntry -NudgePrompt -NudgeRequest -NudgeMotion -NudgeReturn -NudgeSequence
./tools/Export-MameDisassembly.ps1 -MameExecutable <mame281.exe> -RomDirectory <roms> -RunDirectory <fresh-disassembly> -NudgeCheckpoint
./tools/Curate-NudgeEncodingCheckpoint.ps1 -RomPath <a6ls.p1> -DisassemblyDirectory <fresh-disassembly> -StackRunDirectory <completed-return>
dotnet build FruitMachineLab.Headless.sln --no-restore
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .
```

Next: extend B749 through B74D/B712/B652, the actual improvement or ordinary
result route, and award/accounting return. Keep temporary controls and text reels;
prioritize playable coverage and preserve exact discoveries proportionally.
No agent installation, configuration change, commit, push or cloud setup.

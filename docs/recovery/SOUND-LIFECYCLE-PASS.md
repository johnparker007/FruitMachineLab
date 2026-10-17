# Sound task lifecycle recovery

Collection checks native0047 while the existing choice scheduler has a separate
logical list. Do not fabricate0047. This pass recovers bounded memory effects.

Capture-SoundLifecycle.ps1 / Curate-SoundLifecycle.ps1 export48 synthetic
original-ROM masked-IRQ calls:16 each release5E2C, cancel5C7A, root C0 return5E6D.
Inputs are constructed valid channel lists, not natural gameplay. Elapsed cycles
are retained as evidence only. ROM regions are checked against a6ls.p1 SHA1
402d1518bb78fdc489b06c2aabc771e5ce151847; no lossless disassembly claim.

AddersSoundLifecycleMemory.ReleaseChannels implements5E2C/60AB memory effects.
Y selects a25-byte record in1A0..259 (stride25). Task+A owns a signed-terminated
channel chain through27E..283. Task+11 rhythm ownership clears those bits in
cache register0E; task+F clears. Released channels lose key-on bit10 in cached
register20+id and append to free head4B/tail4C. U is preserved by native code.
Optional YM callbacks report changed cache values only, without synthesis/timing.

All16 release cases compare RAM excluding caller-owned native stack6F0..701.
Invalid pool/channel chains are rejected before mutation: synthetic fault guards,
not inferred ROM corrupt-list behaviour. Historical native/5e2c.json annotations
remain linked; fresh synchronized Ghidra export is unavailable.

Excluded raw capture76ba2833bcc14407b77737ea605eac5b had an invalid debugger
assignment. Clean replacement ba60b203f3504706a7d1b21b39f13d97 is curated. Both
isolated temporary runs exited normally. Original tools/settings are preserved.

Next: cancellation/root completion, then task lifecycle ownership. Live unchanged;
the native/logical sound-list mismatch guard remains required.

## Cancellation5C7A/5CB5

Cancel now walks0047 using a predecessor LINK address (not just a task pointer),
removes the first root matching input X, pushes it onto free0049, then releases
channels. Native44 nesting guard returns to its incoming value. The disabled
719B bit80 gate60C8 does nothing; absent roots also leave memory unchanged.
Sixteen original-ROM full-memory cases pass. Separate synthetic tests cover a
middle record, duplicate roots, absent/disabled calls and cyclic-list rejection.
No timing or logical/native scheduler synchronization is inferred from these.

## Root completion5E6D

FinishRoot covers C0 only with an empty native stack (+6 == task+25), after the
due task has been removed by5CEC. It releases once at5E6D->5E2C, branches from
5E74 directly to5E85, pushes onto0049 and continues5CDE without advancing0045.
The5E83 release is alarm-fallthrough, not a second normal root release. Native44
decrement is scheduler exit5D38 and deliberately outside FinishRoot.

All16 selected root calls match RAM. A synthetic100-round test fills/drains all
six records600 times in total, checking free-list uniqueness each round. Duplicate
ownership and nonempty native frames fail before mutation. This does not yet
join logical sound frames to native records or establish complete sound playback.

## Instruction-staged release checkpoint

The capture now also observes5E2C/60AB instruction entries and adds unchanged-cache
variants:96 cases total,32 per entry. AddersSoundReleasePlan matches all32 release
paths, exact original encodings, cycle offsets, all2KB RAM including native stack,
and changed-cache notification order. Every instruction is advanced to one cycle
before its completion to verify no early RAM or output effect. Source costs use
the existing MC6809 timing decoder; no captured durations feed the plan.

Task Y/DP0 and caller U/X/S are explicit. PSHS/JSR scratch is written to real S;
this is not a complete CPU register/flags interface.60B4 address-port write is
timed but not exposed as a separate peripheral callback; callback at60B9 reports
the completed register/value pair. Audio/peripheral bus ownership remains external.
Suspension accepts only an unmasked instruction boundary; masked and partial
instruction attempts fail. This does not establish Live IRQ acceptance.

The clean instruction capture ba5b4dd1f023412a91df22198421e5ae replaces the earlier
48-case memory-only fixture. Curated catalogs deduplicate exact ROM contexts;
per-path arrays reference catalog indexes and relative cycles. Re-export is
deterministic. No Ghidra/tool/configuration changes were made.

## Native service and nested return checkpoint

AddersSoundServicePlan composes5CD0 entry,44 reentrancy guard,2C clear,0045 clock
increment,0047 head/deadline equality, due removal, saved callback/U dispatch,
5D3B command fetch/dictionary,5E6D C0, release, root free or nested word return,
and same-clock5CDE rescan through5D38/5D3A. Entry5E6D also supports a due task
already removed by its caller. No general CPU interpreter is introduced.

The final matrix has160 original-ROM synthetic calls:32 release,32 cancel,
32 root,32 scheduler,32 nested return. Four sets (128 paths) verify every emitted
PC/cycle/encoding and full2KB RAM including scratch. Cancellation is memory-only.
Scheduler cases include FFFF->0000 rollover and one/two due tasks; nested cases
return through real source C0 byte879E and checked table5AE3=5E6D. Native task
stack pointer+6 and return bytes are read/written directly. Selected nested
returns require aligned two-byte frames in the record's stack area; odd/unknown
layouts stop explicitly. U after consumed879E is879F, not incoming0600.

Final clean raw run:1ac0e0bead3f4ac9b79e59a0373d1497. An initial expanded run
7a2b53e32e29495e95916c3d9d8abeb2 was rejected by an obsolete U==0600 curator
assertion, then replaced after checking dispatch. No end-state injection was
introduced. Prefix10 direct STY9F timing was added to the existing decoder and
is covered by these original-ROM paths.

Synthetic checks also cover reentrant service (no mutation/tick), empty idle
tick, explicit unsupported-note fault, corruption guards,600 pool allocations/
completions and instruction-boundary suspension. A note fault does not pretend
to complete/free its removed due task. These are component checks, not complete
sound playback, prompt completion or whole paid games.

### Integration boundary and next gameplay work

The logical scheduler and Live remain unchanged. Actual8784 Collect prompt
begins C5/C2 and uses8739 children. Instrument/channel acquisition, child
allocation, native5CF3 yield reinsertion and saved cursor/frame ownership must
still be composed. Do not mirror the logical list into0047 or mark notes done
without those effects. The new bounded service throws at notes, unknown
commands/callbacks and unsupported frames.

Next recover the minimum8784/8739 task path and yield ownership, then replace
the prompt mismatch boundary. Foreground/IRQ ownership and busy5429 serial remain
needed for full Live collection. Keep gameplay priority; no general audio or
unrelated IRQ campaign. Fresh synchronized Ghidra export remains unavailable.

## Follow-on cycle: native yield5CF3

AddersSoundYieldPlan stages5CF3..5D36. The incoming S word is consumed into task
callback+4, U is saved into cursor+8, scaled delay is computed through the actual
byte MUL/add/carry sequence with temporary native stack bytes. Zero delay becomes
one. The task inserts after equal unsigned relative deadlines, including wrap,
stores due+2 and next+0, and jumps5CDE at the same tick. No ordinary RTS occurs.
The caller owns the removed task and outer CPU context.

Capture-SoundYield.ps1 / Curate-SoundYield.ps1 export48 original-ROM synthetic
masked-IRQ calls (duration0/1/16/255, tempo0/16/255, local/global rate and wrap).
AddersSoundOperationVerification checks every PC/cycle/encoding and full2KB RAM,
including stack; no RAM effect occurs early. Curated collection/sound-yield files
preserve source bytes/catalogs, callback input, initial/final RAM and raw hash.
Native subtraction opcode93 timing is now supported and exercised by this matrix.
Raw pointer: %TEMP%/FruitMachineLab-sound-yield.txt. The initial curator had an
array-expression precedence error; no capture was accepted until that was fixed.
This is bounded component evidence, not natural playback or Live scheduling.

## C2 child allocation5EE3

AddersSoundChildPlan composes5EE3..5F12 and5C51. It consumes a ROM pointer from U,
saves/restores parent Y via native S, allocates the actual free0049 head, clears
channel/rhythm ownership, and copies only parent+B/C/D/E/10/12. Child due equals
CURRENT0045; parent continues5D3B first. Exhaustion consumes the operand but does
not allocate. Unlike foreground5C18, C2 does not consult719B's sound-disable bit.

Capture-SoundChild.ps1 plus Curate-SoundYield.ps1 -Operation child export32
original-ROM synthetic instruction/RAM paths, including allocation failure,
all inherited byte extremes, clock edges and disabled-bit set. Original8787
operand8739 is byte-checked. Native EXG timing is now covered. Curated sound-child
artifacts include native stack scratch; no snapshots/deadlines feed execution.
Raw pointer: %TEMP%/FruitMachineLab-sound-child.txt. Live remains unchanged.

## Instrument/cache5F5B

AddersSoundInstrumentPlan now stages5F5B..5F7F. Wrapped operand+optional global
4D+pitch+C+transpose+D indexes the ROM table5A1E using unsigned ABX twice. The
preceding command selects cache registers (DB/DC/DD subtractC5); no generic
instrument interpretation replaces those bytes. Both register values come from
the original table, including aliases beyond its nominal note range. Native60AB
is shared with release in AddersYmCachedWritePlan; it retains signed cache
indexing, real stack writes and changed-value timing/callbacks.

Capture-SoundInstrument.ps1 / Curate-SoundYield.ps1 -Operation instrument export
48 original-ROM synthetic cases: three command aliases, wrapped pitch/global
flags and cache-hit/miss paths. All instruction bytes/times/full2KB RAM match.
RAM600 holds the synthetic command/operand; ROM/table bytes are unmodified and
checked. Existing128 timed lifecycle paths still pass after sharing60AB. Raw
pointer: %TEMP%/FruitMachineLab-sound-instrument.txt. No audio synthesis or Live
timing claim. The shared curator's single-span yield export was also checked
after extending its operation modes; existing yield tests still pass.

## Composed commands and dispatch correction

The first composed service comparison exposed an earlier isolated-helper labeling
error: C5 maps to5F88 attenuation, NOT5F5B. The direct5F5B C5 test exercised a
synthetic helper call, not actual dictionary dispatch. Its fixture has been
replaced with DB/DC/DD, all byte-checked dictionary aliases. Corrected raw pointer
is FruitMachineLab-sound-instrument.txt. This is not an original-ROM bug fix.

AddersSoundAttenuationPlan implements the actual C5 high-nibble update and
channel-cache propagation5F88/5FC5..5FDB. AddersSoundServicePlan composes actual
dictionary targets for C5, C7 pitch, C2 children, DB/DC/DD and CE wait. CE resumes
through saved5E29, with native5CF3 ordered reinsertion and same-clock child scan.
Capture-SoundCommandService.ps1 / shared curator -Operation service produce32
original-ROM synthetic service ticks with RAM command streams, including allocator
exhaustion and zero tempo/delay. All emitted PC/cycle/encodings/full2KB RAM match.
This does not claim those synthetic streams are game scripts or full sound runs.
Raw pointer: %TEMP%/FruitMachineLab-sound-command-service.txt. A first expanded
capture was valid but comparison correctly rejected the wrong C5 dispatch; the
replacement observes the actual attenuation code. No ROM bytes were patched.

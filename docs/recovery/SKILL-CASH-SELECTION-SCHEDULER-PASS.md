# Skill Cash selection and scheduler pass

The three complete recovered C699 selection calls now execute in C#, producing
accepted choices 3, 2 and 1. They match 9,634, 26,428 and 29,236 MAME VM dispatches
respectively: 65,298 total. Each stage starts from its recorded entry state; this
does not yet execute the complete C721 feature entry through its final cleanup.

## Trace-backed verification

`selection-loops.json` stores sparse platform inputs and diagnostic anchors plus
a canonical SHA256 of every observed dispatch. Each signature contains 16
big-endian 16-bit fields: Y, token, top, second, U, S, F4, F6, frame, timer, IRQ
counter, RNG seed, choice, rate, latch and scheduler clock. Expected choice bytes
and native helper return values are not injected into the complete-loop runtime.
Captured IRQ deltas, input-latch changes and scheduler clocks still supply timing;
this is a deterministic replay adapter, not a general CPU-cycle model.

IRQ phase matters inside native VM words. One timer store overwrites an IRQ's
timer increment while retaining its IRQ-counter increment. Six timer reads in
stage 1 and ten in stage 2 receive IRQ pulses before the native load, after the
dispatch snapshot. The fixture records these phases explicitly. Removing a pulse
is a synthetic fault experiment and must fail the unchanged state digest.

The 8EE4 sound stream timing/choice subset predicts 1,202 VM choice reads, with
three queues, 5,734 commands, 1,852 waits and 137 choice writes. Rates 25, 20 and
15 are calculated by the recovered VM. Delay arithmetic uses floor division,
16-bit clocks and a minimum delay of one. Byte choice increments wrap.
Native enqueue entry and effective load are separate boundaries: the third queue
crosses a scheduler tick before 5C46. Reset also allows an intervening task update
before the actual 004F clear at 5B80. The recorded protocol retains both phases.

The new MAME capture reproduces the original campaign's state.csv,
feature-state.csv, input-levels.csv and ram-final.bin byte-for-byte.
`sound-verification.json` records source and executable hashes. Full logs and RAM
remain outside Git; the original forensic workspace was preserved.

## Static translations and limits

Dynamic EXECUTE resolves only the three recovered stage lamp words to their
shared 9AFD body and parameter cells. Twenty-one distinct stage/choice calls
match 483 VM dispatches and stack/frame observations. Complete loops emit 7,242
decoded logical lamp requests. Their ranges, patterns and ROM tables come from
static recovery; physical lamp frame RAM, characteriser row mapping and output
timing are not verified by the dispatch digest.

The scheduler supports the single observed task and rejects concurrent queues.
It consumes recovered instrument, detune and note operands and emits command
events, but does not emulate audio registers, channels, envelopes or the native
allocator. Selected saved native assembly and a fresh MAME sound disassembly
support these translations. They are recovered evidence, not original source.

Twenty-nine dependency-free verification groups pass, including negative fixture
tests and static clock/byte wrap, delay and abort-gate cases. Both solutions build
without warnings or errors. The WPF viewer performs verification off its UI thread;
the expanded viewer has build verification, not a new interactive user test.

## Reproduction and remaining work

Use `tools/Capture-SkillCash.ps1 -NativeSound` with its documented capture arguments,
then `Curate-SkillCashSound.ps1` and `Curate-SkillCashLoops.ps1 -RunDirectory <run>`.
`Curate-SkillCashLamps.ps1` uses the earlier hash-verified focused VM capture.
All three curations reproduce byte-for-byte against their selected sources.
`Export-MameDisassembly.ps1` writes into a fresh external temporary directory.

Next boundaries are full C721 orchestration, NVRAM helper 6E06, win animation
AF93, physical lamp/audio effects and general timing. The enabled ROM-option
branch C646 remains outside this MAME path. Award 10 and level 1 remain verified
bounded mechanics; final current-win, bank and payout are not yet translated
end-to-end. Unknown semantics continue to fail explicitly.

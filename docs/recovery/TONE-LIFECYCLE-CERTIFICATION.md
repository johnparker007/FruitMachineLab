# Native start-tone lifecycle certification

Scope: gate 2 of the revised roadmap. One headless `AddersNativeSound` owner on
one `Machine` queues the actual `59EB` stream, services it to the original wait
and cancels the same task. This does not establish timer1 cadence, outer IRQ
ownership, `6B4D`/`58BB`, Live integration, finish CPU work or audio synthesis.

## Contract

Original A6L ROM SHA1 `402d1518bb78fdc489b06c2aabc771e5ce151847`. The isolated
initial contract is the recovered reset task/channel free list (`0047=0000`,
`0049=01A0`, records through `0259`, `4B=00`, `27E..282=01..05`, `283=FF`,
`4C=05`, `4D=00`, `4E=0010`, `4F=00`, `5000=0010`). The capture uses a zero YM
cache, not a reset cache write. Caller stack is `S=0700` with continuation `4C34`.

The capture performs, in order:

1. native `5C18` queue with `X=59EB`, `Y=01A0`, `A=91`, `B=31`, clock `0`;
2. native `5CD0` service at the declared clock, reaching the `CE FF` wait;
3. a second externally timed `5CD0` at due-1, exercising `C4` back to `CE`;
4. native `5C7A` cancel on the same state.

Caller writes occur after each captured `before` snapshot and immediately before
its native call: `PC` and declared registers (`S=0700`, `U=0600`, `X/Y/A/B`, DP=0,
masked CC); caller return word `0700=4C34`; scheduler counter `0044=0`; sound
enable `719B=0`; and the declared caller clock `0045/0046` (`0000` for queue and
service1, `00FF` for service2, absent for cancel). Service2's tick increments
`00FF` to the task deadline `0100`. These are explicit clock/ABI inputs for this
bounded component proof, not autonomous execution. The saved `before` images are
pre-write; the verifier requires each adjacent `after`/`before` pair to be
byte-identical, so no other intermediate RAM edit is permitted. Retained
task/channel/rhythm/tail state comes only from native instructions.

IRQ is masked by the supplied condition code. Service clocks are caller inputs,
not an inferred machine period. A separate synthetic check queues an unrelated
native task with a future deadline, confirms it is not serviced by the tone tick,
cancels the tone and requires the unrelated record to be unchanged.

## Evidence

`evidence/mpu4/collection/tone-lifecycle.json` preserves fresh isolated MAME
0.281 before/after 2 KB RAM and every executed PC/cycle/context for queue,
service1, service2 and cancel. `tone-lifecycle-verification.json` records raw,
debugger, argument, seed and ROM-region hashes plus the phase summary.

The debugger sets the initial `PC` to the declared entry at the phase `PH` cycle.
MAME does not emit the injected entry instruction, so the raw capture contains
only the following instruction. The verifier closes that gap explicitly rather
than skipping `observed[0]`: entry `5C18`/`5C7A` source is `BD60C8` (JSR
extended, 8 cycles) and entry `5CD0` is `9644` (LDA direct, 4 cycles); each
captured first PC is the JSR target `60C8` or next PC `5CD2` at exactly that
relative cycle. It checks the entry instruction's PC, source bytes and exact
interval, then every captured boundary and phase total.

The headless owner seeds the recovered reset list, then uses the same native
queue/service/cancel plans. It matches all 485 captured instruction boundaries,
each phase duration and full 2 KB RAM. The task is active after queue and both
service ticks, with actual channel ownership (`4B`, `27E`, task `+A/+B/+F/+11`)
and wait deadline `0100`/`01FF`. Cancel empties `0047`, restores task `01A0` to
`0049`, releases channel `0` to `4C`, clears its key-on bit and preserves the
task/stack bytes not owned by release.

Natural `skill-cash/nudge-tone.json` is used only as a command-order check
(`C6,C5,D8,00,C3,CE`). It is not used for timing or lifecycle state.

## Failures and limits

Missing required ROM regions, a corrupted `59EB` command, and an empty free pool
fail explicitly. The accepted stream covers only the initial `FF` channel
sentinel for `C6` and the zero-count `C4` loop. The new `C6` active-channel and
`C4` finite-count branches are not independently captured and are now rejected
with `NotSupportedException` instead of being approximated. Unsupported
commands/frames also stop. Controls tamper the declared host clock, omit the
caller return frame, inject an unexpected RAM delta and corrupt the entry
opcode; all are rejected. The second tick only demonstrates the stream loop/`C4`
path; the stream is intentionally infinite at its `CE FF` wait. No autonomous
service cadence, outer-IRQ envelope, finish `360`-cycle fit, gameplay or hardware
claim is made. Gate 3 must still design the single Live owner and any required
foreground or timer1 boundaries.

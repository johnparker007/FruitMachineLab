# Recovered dice selection and reel requests

15 October 2026. START at the live square-32 prompt now executes the recovered roll
selection and prepares a dice stop request. The alpha displays ROLLING; a diagnostic
shows the requested symbol, signed stop offset and unchanged physical position.
Execution deliberately stops at B283/native 61F6, before motor motion. Restart
returns to the board prompt; TAKE FEATURE still plays Skill Cash normally.

The prior DD81/native 2C71 boundary has moved. This pass does not roll the physical
reel, advance the board, or claim complete games. No captured result or completion
time is inserted into Live mode.

## Reference proof

Two fresh isolated MAME captures use the unchanged physical-input campaign and
observe a natural roll at board square 7. The narrower B271..B283 body contains
478 dispatches. The wider DD7E..B283 capture contains 485 dispatches and independently
matches the narrower body's complete 25-field digest. The wider translated replay
matches all 485 VM observations, 15 lamp requests with resulting frame memory,
16 sound commands, 50 alpha serial bytes and five input-condition observations.
No uninitialized-local masks are needed for this path. Replay stops before executing
the terminal native motor call rather than substituting its result.

Capture-SkillCash.ps1 -FullFeature -DiceRequests -NativeSound -NativeAlpha
-NativeLampFrames -NativeInput -CpuInterrupts starts at DD7E with C9=7, saves the
RAM boundary and observes through B283. Curate-DiceRequests.ps1 retains sparse
platform/input phases, anchors, output hashes, initial RAM, source hashes and
debugger commands. The earlier selected body fixture also records its original
raw capture hash. Curate-DiceRequestData.ps1 reads selected data from the SHA1-checked
unchanged ROM. Raw traces and ROM files remain outside tracked artifacts.

The capture is a square-7 reference. Live still starts at square 32 and executes
the recovered rules using its own state and current player timing. Eight synthetic
live timing variations request symbols 2,4 and 6; all stop at the declared native
motion boundary with physical position unchanged. These are varied-input tests,
not independently captured MAME square-32 campaigns or payout evidence.

## Translated mechanics

- B1D0/B1A1/B038 and their helpers calculate candidate board steps using the native
  RNG, weighted table, link checks, input conditions and parameter profiles. B1FD
  and B1E1 prepare a signed stop-offset request through the actual VM code.
- Native 169B selects the counter/credit profile and scales byte parameters. Its
  subtract-100 loop tests the signed 16-bit result; it is not ordinary unsigned
  ceiling division for large products. Tests retain the 255×255 result of 1 and
  the low-byte wrap of the 160×160 result to zero. Those edge tests are static
  deductions and synthetic inputs; the normal capture checks the observed profile.
- Native 2C12 projects each reel's physical position and signed requested offset
  into the ROM symbol tables. Native 2BEB waits for the busy flag, temporarily
  clears request bytes while refreshing current symbols, then restores them.
  The translated helper rejects a still-busy reel instead of pretending it finished.
  Request arithmetic preserves byte wrap and signed normalization, including the
  dice-strip offset-80 case. The main reel/dice geometry is read from 75CB/75CC.
- Dynamic EXECUTE now supports explicitly resolved literal words without inventing
  an extra VM call frame or dispatch. Token 82E7 pushes 0169; the existing 9D97
  address calculation indexes the real reel request record. Unknown dynamic words
  continue to fail.
- Alpha commands 72/75 retain their native repeat frames at 04E5, byte counts and
  continuation addresses across delay command 68. The 3F9E capacity boundary is
  preserved. Electrical brightness/blink rendering remains outside the alpha shadow.
- Native 2C71 applies pattern 8F to the three selected reel lamps. The lamp digest
  checks those outputs alongside the roll prelude's other lamp operations.

The native symbol helper is a software projection, not a motor simulator. The
profile and reel-table translations stay in the Adders project; their ROM addresses
are not presented as generic MPU4 layout assumptions. The
remaining native 61F6/6287 path initializes motion records, waits for service and
sets busy state; periodic service then advances the physical positions. None of
that scheduling is synthesized in this pass.

## Timing qualifications

Live retains the existing provisional CPU/IRQ adapters. Minimum measured costs
from the new capture extend the observed instruction set. For alternate scripted
branches, the ROM-checked list of ordinary 00F8 threaded-call gateways shares the
already measured 9B3E entry cost. The decoded body must still execute, and its
helpers must still have semantics. This is a static entry-cost equivalence, not a
new measurement of those paths. Alias 78BE/78B5 is separately validated as the same
native zero-word gateway. No fallback cost is supplied for unknown native work.

## Checks and next work

92 headless verification groups pass, retaining every prior reference proof and
all six Skill Cash awards through all three entry modes. New checks cover the
natural request replay, varied live roll timing, profile edge behavior, symbol
projection/request preservation, busy gating and delayed alpha repeats. Headless
and isolated WPF builds pass. Live, jackpot, playback and the new opt-in
--live-roll-smoke-test <fresh-output-directory> pass. The roll smoke uses real-time
physical Start, checks ROLLING/request output and unchanged physical position,
verifies released controls, renders the stop and checks a clean restart.

Next capture native motion initialization, service callbacks, physical position
changes, completion and symbol refresh. Translate and verify that path before
continuing through B28F to DDF3 board movement and ladder/snake dispatch. Do not
replace it with a timer and a chosen reel result. FML integration and persistent
whole-game play remain planned, using John's existing layout references later.

No installation, machine configuration change, cloud setup, commit or push was
performed. The original forensic workspace is preserved.

# Continuous Skill Cash feature replay

The headless runtime now executes the recovered C721 feature continuously through
its C767 return word. It matches **98,704 MAME VM dispatches**, selects 3, 2 and 1,
commits award 10, transfers it into current win, clears pending award to zero and
releases the feature's local frame. The WPF diagnostic app now runs this replay
and shows the stage reductions and ten award transfers.

This is a verified feature replay with a captured platform adapter. It is not yet
a free-running replacement for the MPU4 machine. Timing, input ports and some
initial RAM remain recorded; physical peripheral behaviour has separate boundaries.

## Continuous VM proof

`feature-replay.json` contains one initial state, 4,540 sparse IRQ/latch/scheduler
timing points, 39 intra-word timer-read phases, 836 native input-port observations
and a canonical SHA256 of every dispatch. No selection choice, random result,
compensation return, award result or native input-test result is injected.

Each dispatch contributes 25 big-endian 16-bit fields: Y, token, four data-stack
cells, U, S, F4, F6, local bytes, timer, IRQ counter, RNG seed, choice, rate, latch,
pending, current win, guard, checksum, service mode, display word, suppression
mask and scheduler clock. Sparse anchors provide error locations; the digest
checks all dispatches between anchors. The signature is independent of text line
endings. The fixture retains all thirteen native NVRAM observations; integrated
execution checks source/complement bytes and checksum before and after each call.

The root caller cursor is absent from the captured pre-dispatch fields. A declared
BEEF sentinel verifies that the recovered final return restores the original
S/F4/F6 context and returns to its caller. The C767 pre-return state is trace-backed;
the caller-cursor sentinel and post-return check are a static verification harness,
not a claim that MAME returned to BEEF. The earlier reused local-frame bytes are
seeded explicitly because native allocation does not clear them.

The adapter supplies per-dispatch timing rather than CPU cycle counts. A native
busy-wait can span more than 255 IRQs; the timer word provides the full count and
the byte IRQ counter verifies its wrapped residue. Native 5CCB completion is
accepted only after calculated sound tasks have terminated. Native queue and reset
phases remain captured at their effective memory-operation boundaries.

## Input-condition recovery

Native 67EC/67F0 and wrapper 7721 have three results: 0000 for no selected input,
FFFF for a complete mask match and **0001 for a partial match**. The old boolean
provider could not represent the partial-match panel-release state. The complete
replay now calculates the result from recorded bytes at 0000..0003 and 0006..0007,
using statically recovered mask tables at 71AA/7226. The expected result in the
fixture is checked, never supplied as the runtime result. Tests retain native
8-bit selector shifts, inclusive bounds and negative-selector any-bit behaviour.
Invalid-selector traps remain unsupported and fail explicitly.

## Complete sound timing protocol

The selected-level sound forks two child streams. The timing model now supports
those forks, shared choice state, subroutine call/return, nested loops and native
ordering after equal deadlines. All 25 VM queues, 6,037 commands, 1,930 waits and
158 choice writes/resets match the native protocol. The single-task selection
stream proof remains in place with its 1,202 predicted reads.

The independent sound verifier takes queue rates as captured VM parameters; the
continuous VM separately calculates and checks those rates. Audio register,
instrument, envelope and channel effects are not synthesized. Free-list addresses,
allocator exhaustion and native error traps are not modeled. Fork/call stack
checks preserve recovered capacity boundaries but do not interpret malformed
mixed stack frames as valid music.

## Lamp frame memory

The prior reviewed characteriser map supplies eight column-response bit values.
The recovered 49C5 setter applies the four low pattern bits to four 16-byte frame
buffers at 0100..013F. The native high pattern nibble does not enter those writes;
the verification digest normalizes it while retaining ID, calculated column and
all 64 resulting bytes.

`lamp-frames.json` contains the initial unrelated frame state, response bits,
sparse anchors and a canonical digest of **all 7,298 native setter returns**.
The runtime output adapter reproduces every resulting frame buffer. It retains
logical requests as an output interface for later renderers. Physical IRQ scan
phase, board strobes, persistence and cabinet illumination are not verified by
these memory comparisons.

## Alpha boundary and diagnostic UI

Forty-four alpha reset/stream requests are emitted explicitly, carrying the
recovered command program. The VM display word 0327 and its five-word bank sum
execute and match MAME, but alpha command interpretation, native display RAM and
hardware output remain unresolved peripheral effects. These requests are not
presented as rendered or validated display text.

The UI performs continuous replay plus independent sound and lamp-frame
verification off its UI thread. It reports final pending 0 and current win 10,
distinct from the earlier bounded commit result of pending 10. Diagnostic counts
now use integers so 98,704 dispatches are not truncated to a 16-bit value. The
expanded GUI has build verification; no new interactive GUI test is claimed.

## Reproducibility and qualifications

Use the existing MAME executable and ROM directory with fresh external output:

```powershell
./tools/Capture-SkillCash.ps1 -MameExecutable <existing-mame> -RomDirectory <roms> -RunDirectory <new-run> -NativeSound -NativeNvram -NativeInput -FullFeature
./tools/Curate-SkillCashFeature.ps1 -RunDirectory <new-run>
./tools/Capture-SkillCash.ps1 -MameExecutable <existing-mame> -RomDirectory <roms> -RunDirectory <new-lamp-run> -NativeLampFrames -FullFeature
./tools/Curate-SkillCashLampFrames.ps1 -RunDirectory <new-lamp-run>
```

Both captures reproduce the original state.csv, feature-state.csv, input-levels.csv
and ram-final.bin byte-for-byte. Source/debugger/executable hashes and isolated-run
arguments accompany the fixtures. Curations reproduce byte-for-byte. Full traces,
ROM and NVRAM binaries stay outside tracked files; the original workspace is preserved.

Thirty-nine verification groups pass. Changed input ports and characteriser
responses are rejected against unchanged evidence. Synthetic mask, deadline,
wraparound, two-unit underflow and fault tests are explicitly separate from the
recorded one-unit path. Nonzero compensation, enabled option C646, different awards
and other input campaigns still require wider reference coverage.

Next work should remove the alpha boundary, recover physical output timing, and
replace trace-dispatch timing with a controlled platform schedule before presenting
the feature as interactive standalone gameplay. No installations, machine
configuration, commits, pushes or cloud changes were required for this pass.

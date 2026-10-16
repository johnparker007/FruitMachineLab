# Paid reel spin

16 October 2026. Live now executes the remaining selected stop preparation and an
incremental paid reel spin after physical Start, retaining credit5/cash bank16/
token bank0 and pending/current-win0. It stops at F398 before result/award dispatch.
This is a completed motor spin, not a completed game cycle or consecutive-games
claim. Full startup, coin insertion, cabinet layout and audio synthesis remain
outside the current slice.

## Natural evidence

Three successful narrow windows extend the existing physical-input campaign:

| Fixture | Entry → terminal | VM observations | Lamps | Sound commands |
| --- | --- | ---: | ---: | ---: |
| nudge-final-selection | F38C → F38E | 171 | 0 | 0 |
| nudge-spin-preparation | F38E → F2B5 | 228 | 0 | 0 |
| nudge-paid-spin | F2B5 → F398 | 1394 | 9 | 17 |

All have zero alpha bytes/lifted dispatches, process exit0 and no debugger-expression
errors. Entry signatures independently match the preceding terminal. Complete VM
signatures, input-condition/timing schedules, ordered lamp/frame digests, sound
commands, protected accounting and terminal150..19F reel records match MAME.
The paid-spin check additionally compares every byte of terminal100..13F lamp RAM.
No PC/register/RAM/ROM injection is used in these natural captures.

paid-spin-native preserves1282 observations from61D5 through64F0 cleanup, including
per-service sound clocks, profiles, positions, phase/drive state, optic samples,
flags and protected-position updates. The reference executor generates optic bits
from the driven Barcrest reel model and checks them against MAME; it does not feed
the recorded optic waveform into that model. Stop-sound root/clock/ordinal queues
and all17 sound commands are checked. The captured IC4 control at native entry is
a qualified inherited hardware seed, then checked after enable/cleanup; this is
not complete PIA or machine-startup emulation. No second independent spin capture
was performed in this batch.

The natural spin begins at physical positions6/90/42/56 with requests6/13/17/9.
It ends at66/12/36/80, requests cleared, symbol bytes4/2/6/11 and refreshed NVRAM
positions/complements/checksum. The fourth-reel adjustment and refreshed symbol
projection remain distinct from motor movement. Live uses its current PRNG/input
timing and can choose other requests; no recorded result is substituted.

## Recovered routines and corrected translation

F072/F052 use native1AF1, which differs from1AA3: any equal symbol pair indexes
the full75BD award table; if that returns zero, exactly two flag-bit0 symbols
return10. The result is sign-extended onto the VM stack. This selected F072 route
returns false without another request scan. An18-case isolated MAME matrix covers
pair positions, zero-award fallback and all eight flag combinations. It is a
synthetic IRQ-masked experiment with explicit symbols/U/S, not natural gameplay.

F248's selected guard skips its alternate hold path. A03C clears held requests
according to the recovered mask, and F30F adjusts the fourth-reel request before
F394 projects the final software symbols. No new randomness source is introduced.

Native2CD0 sets three reel-group frames: positive4/2/1, negative1/2/4; zero clears
the first, lights the second and clears the third unless its ID duplicates the
second. Inline stream2D0F..2D13 (9003910093) sets the original lamp timing.
The natural nine requests and full frame digest match.

Native61D5 clears6B and checks the high byte at0158. If zero, it installs the
three stop streams3457/3462/346D and a null fourth; otherwise it preserves the
existing pointers. It then enters shared6200 motor initialization. Native61F6
continues to clear those pointers for its existing callers. The common profile,
IRQ motor and optic engine is reused with the distinct entry behaviour retained.
The actual35-tick VM wait and scheduler reset after the motor return execute.

The new full-frame check exposed an implementation error in native1421's existing
translation: ORA ,Y and ORB ,Y use the same mask for both adjacent frame bytes.
The old translation incorrectly used the neighboring mask for the second byte.
Correcting that makes100..13F match exactly, including0101/0121/0131 bit0. This
corrects the C# translation; the ROM behaviour is unchanged. The conditional third
byte and special table1456 case remain preserved.

## Live and verification

Live initializes61D5 incrementally, waits for the next actual virtual reel service,
then continues the existing drive/optic motor model.2BEB waits for actual busy
completion; it does not apply a recorded final position. Reel-stop sound streams
are queued by motor execution. Captured CPU/IRQ pacing remains the existing explicit
hardware adapter; full CPU/electrical equivalence and audio synthesis are not claimed.

172 headless verification groups and all eight WPF smoke modes pass. The full Live
route pauses inside the paid motor, checks frozen VM/memory/time, resumes, then
verifies request-derived final positions, cleared requests and protected-position
accounting. Its changed positions update the expected NVRAM vector; the bank, credit,
award/statistics and other bytes remain independently checked. The GUI exercises
physical Start and pauses after the paid main reels have visibly changed position,
saving paid-spin-paused.png and the final result render. Playback remains separate.

## Preservation and continuation

Continue the previous Capture-SkillCash flags through NudgeSpinGates, then append
NudgeFinalSelection, NudgeSpinPreparation and NudgePaidSpin for the respective
windows. Keep TailWindow/NoMotorItems and narrow observers. Curate-BoardLink uses
the same stage flags, omitting NoMotorItems. Curate-DiceMotion -PaidSpin imports
the completed native window and rejects failed/error captures. It retains per-service
clock observations for reference sound scheduling only. Live consumes none of those
recorded motor events.

Capture-AvailabilityMatrix/Curate-AvailabilityMatrix now accept FallbackResult for
native1AF1. Use the final-selection tail-entry-ram.bin as SeedRam and a fresh run
directory. The existing native/VM encoding checkpoint and ROM-data map include
the newly used routines, inline lamp stream, stop streams/instrument data, labels,
exact bytes and C#/verification links. Existing Ghidra exports remain preserved
and hash-linked; no live Ghidra API was available for a fresh comprehensive export.
Selected byte-checked spans are not a lossless full-ROM listing or rebuilt ROM.

Next: F398's result checks and return through FC34, including FC66/EE62 fourth-reel
and feature/result handling. Preserve the consumed credit and persistent machine
state. Long-wait native2CB3 and other unresolved branches remain explicit. Stop at
evidence-backed boundaries rather than resetting to feature entry or inventing awards.

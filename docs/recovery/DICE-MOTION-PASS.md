# Incremental dice motor execution

15 October 2026. START at the default DD38/square-32 prompt now runs one recovered
dice roll. ROLLING appears, a text dice face and ROM position change while the motor
is serviced, and the recovered completion path clears busy, stores positions and
refreshes symbols. Pause suspends the VM, motor and virtual time; Resume retains
their state. Execution stops before B28F returns to board movement. Restart restores
the entry snapshot. TAKE FEATURE still plays Skill Cash; playback stays separate.

This is one roll from a recovered feature-entry state, not startup, board movement,
an entire feature board or persistent games. The motor is a small explicit device
model; the game still executes recovered VM code and translated native helpers.

## Recovery and implementation

`AddersReelMotion` translates native 61F6 preparation, 6287 profile selection, 6342/
6350 timing arithmetic, 6403 periodic servicing, 656B optic checks, 65D8 coil encoding
and 649D/667B completion. It retains byte/word wrap, signed requests, profile cursors,
remaining steps, countdowns, direction, busy state, position modulo 96, NVRAM mirror
updates and checksum delta. Profile completion also applies native 1421's lamp bits.
An unresolved alarm path raises an explicit recovery boundary; it does not pretend
the reel finished. The motor-disabled shortcut, homing and service/alarm campaigns
have not been validated and are not claimed as supported whole-machine behavior.

Native 27D2 increments 6E and writes the previous service's coil latches before
calling 6403. The translation keeps that ordering. Native 61F6 enables drive before
waiting for a service change, then sets busy. Live preserves these separate stages;
it does not assign a chosen position after an elapsed timer. The VM subsequently
executes B25B's actual busy-byte loop and native 2BEB symbol refresh.

`BarcrestStepper` ports the relevant MAME 0.281 Barcrest phase/optic mechanics, with
BSD-3-Clause attribution in THIRD-PARTY-NOTICES.md. Adders selects the documented
R4/RT1 configuration: four 96-half-step motors, index interval (1,3), initial phase 2
and zero index-pattern mask. Game ROM addresses/profile tables stay in Adders.

The ROM position and MAME motor position run in opposite directions. At the verified
idle feature-entry boundaries, motor position is `(98 - romPosition) % 96` and phase
is `romPosition & 7`. Read-only MAME device saved-item observations independently
establish this seed for both the square-7 reference and the exact square-32 entry
positions. Subsequent positions and optics come from coil writes, not a recorded
waveform. The seed is a feature-entry adapter, not recovered startup. Initial idle
coil-pattern history is not claimed as a full saved-device-state reconstruction;
the first actual drive write supplies it, and the zero index-pattern mask makes
optic state independent of that history in this configuration.

The text face is a read-only projection through the existing ROM strip/geometry.
It does not mutate the VM's requested symbol during motion. The UI separately shows
the retained requested symbol, signed stop offset, current ROM position and busy
state. No cabinet artwork, layout importer or audio synthesis was added.

## Natural reference evidence

Three fresh isolated MAME runs use the unchanged physical input campaign, with
setup callback compensation. No RAM, ROM, CPU-register or result injection is used.
Original forensic files/settings are preserved; raw runs remain in temporary
directories recorded in the curated source metadata.

- Two runs independently agree on 875 selected native observations from 61F6 through
  64F0, including flags, profile/position records, drive counter, NVRAM and checksum.
  The second additionally captures coil phases. Independent core hashes are retained.
- The native comparison checks 386 service calls, including final cleanup, and 96
  optic/position-update operations. Dice ROM position goes from 56 to 40. A second
  verification independently generates every relevant optic bit with the driven
  motor model instead of supplying captured optic values.
- The combined DD7E..B28F reference matches all 7,103 canonical 25-field VM
  observations, 15 lamp requests with frame results, 167 sound commands and five
  input-condition observations. No uninitialized-frame masks are used on this path.
  Direct 1421 stop-lamp memory writes are translated statically; the 15-request
  digest does not independently prove those additional direct writes or electrical
  lamp output. Award accounting remains zero on this roll path.
- The earlier 478-dispatch request-body digest independently remains unchanged.
- Device saved-item observations retain matching idle motor seeds for the reference
  and default Live entry. Bulk per-frame hardware logs remain outside the repository.

The reference-only adapter retains IRQ/service positions relative to VM dispatches.
An IRQ clears busy during B25F's byte-fetch word; the adapter applies that captured
phase before the actual memory read. It does not replace the fetched value or the
motor's result. Live never reads these phase/optic/outcome observations; its only
new reference dependency is measured instruction pacing, plus selected static data.

## Explicit alpha/timing qualification

The combined reference emits 83 alpha serial bytes versus MAME's 84. Text, cursor
and reset bytes match. The sole difference is a missing final FF brightness
restoration after E0 and immediately before the C0 clear/reset sequence. The
verification returns `AlphaExact=false`, reports the discrepancy and rejects any
other difference. It preserves the raw expected bytes and supplies no missing byte
to the executing machine. All earlier strict alpha comparisons remain intact.

The alpha delay/reference adapter advances at VM/native boundaries rather than
every native CPU read. This new rolling brightness loop exposes its scheduling
limit. The current WPF shadow also does not render VFD brightness modulation.
Live continues to use the provisional CPU/IRQ occupancy template; native preparation
is split at the service boundary, not executed as individual CPU instructions.
Motor servicing is incremental and source-ordered, but exact real-machine wall
timing and transient electrical behavior are not claimed.

The square-7 replay and square-32 Live tests are distinct contexts. Eight synthetic
player timings generate and complete requests 2,4,6. They are not independent MAME
square-32 campaigns or evidence about whole-game payout percentages.

## Reproduction and checks

Capture-SkillCash.ps1 now accepts `-DiceMotion -FullFeature -NativeSound -NativeInput
-NativeLampFrames -NativeAlpha -CpuInterrupts`. Curate-DiceRequests.ps1 `-Motion`
extracts the full VM/output reference; Curate-DiceMotion.ps1 retains native states,
ROM data, optional independent comparison and optional device seed observations.
Both take fresh run paths; the capture never overwrites original evidence.

99 headless groups pass, retaining every previous group. New checks cover native
motion, independently generated optics, combined VM/output comparison with the
explicit alpha qualification, saved-device seeds, phase/optic edges, actual pause
during motion and a synthetic stuck-optic fault. The varied-input roll checks now
require motor completion and the refreshed result, not just a prepared request.

Headless and isolated WPF builds pass without warnings. All four GUI smoke modes
pass: normal Live, jackpot, playback and roll. The roll smoke presses/releases the
physical START control, observes ROLLING and changing position, pauses during
motion, checks frozen memory/time/dispatches, resumes, verifies result/busy/input
release, renders paused/completed states and checks clean restart. Rendered states
were visually inspected. The text labels identify the remaining board boundary.

## Next work

Continue B28F back through DD8D/DDAB into the DE75 caller, then recover/verify DDF3
board movement and DBC4 ladder/snake dispatch. Capture that broader natural path
before extending Live. Preserve the distinction between a completed motor roll and
complete playable board/game. Improve native alpha timing separately without
substituting recorded brightness bytes. FML integration remains on the roadmap;
John's importer/renderers are needed when that stage becomes actionable.

No installations, machine configuration changes, commits, pushes or cloud access
changes were performed. The official MAME stepper source was read into a temporary
file for comparison; it was not installed. Original analysis files remain untouched.

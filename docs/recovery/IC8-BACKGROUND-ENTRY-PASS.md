# IC8 output and background entry

16 October 2026. Live now executes the IC8 output update and proceeds into the
next cycle's background dispatcher. It stops at FBF1 before native482F status-lamp
service. Cash bank16/token bank0/credits6 and pending/current-win0 are preserved.
This is not yet the next paid-game input loop or completed collection.

## Verified natural windows

- nudge-ic8: FAF0 → FDBA,23 raw/canonical VM observations and one lamp request;
  no sound commands or alpha bytes. The inherited IC8 latch is30/control34.
- nudge-background: FDBA → FBF1,93 raw/canonical observations, no lamp requests,
  sound commands or alpha bytes. Native4C34 is a byte-checked RTS compatibility
  entry. The observed negative timer bypasses the2CB3 lamp-status branch.

Both captures exit0 without debugger-expression errors. Their entry signatures
match the previous verified window terminal fields, excluding absolute CPU cycle
and the newly added port fields. VM, output digests, protected accounting,
statistics and all captured IC8 latch samples match. Existing playback and prior
reference windows remain unchanged. These are separate successful natural runs,
not a combined full-machine trace or physical payout proof.

The background reference exposed a replay-adapter omission: scheduler clock
advances did not increment IRQ timer word002F. Live already increments002D/002F.
The verifier now increments002F by the same elapsed IRQ ticks; the newly reached
9DE1 timer read and all older verification groups pass. No captured gameplay
result or input event is substituted into Live.

## Port contract and limits

The exact startup record at204A is `0F02 FF 34 00`. Native67B7 clears the PIA
control register, writes FF as DDR, writes control34 and initializes output00.
The local preserved MAME MPU4 driver maps0F00..0F03 to IC8 and port B writes to
triac outputs. MAME's [6821 implementation](https://raw.githubusercontent.com/mamedev/mame/master/src/devices/machine/6821pia.cpp)
returns the output buffer when DDR B is FF. This source cross-check supports the
selected contract; it does not establish every PIA mode or electrical side effect.

The successful capture independently records inherited output30/control34 at
the earlier E247 boundary and again at FAF0. LoadIc8Entry initializes that captured
peripheral state for the bounded diagnostic session. It checks the ROM record
and selected data-register mode. The existing VM byte fetch/store then operates
on the output shadow; no recorded output sequence is fed back during execution.
The earlier physical startup/credit path that established30 is not translated by
this seed. Do not present it as a general PIA, coin-output or full-startup model.

Recovered9D5A sets only bit10 when its entire pattern cell equals008F and clears
that bit otherwise. Other bits survive. The natural path performs30→30. A separate
synthetic VM test checks all256 initial bytes for patterns008F/0080/0000/018F;
these alternate cases are static-mechanics experiments, not additional MAME paths.

## Capture failures and workaround

Four earlier attempts failed with external MAME access violation C0000005 before
the selected window. Full write-watchpoint logging, restricted watchpoints,
additional printf fields and split records did not produce complete captures.
They remain excluded. The successful approach limits peripheral observations to
the selected TailWindow and prints IC8 values in separate short IO records.
The exact cause is unresolved; neither a printf-limit hypothesis nor logging
load is established as the cause. Do not erase the prior failed-later prefix or
full-logging crash qualifications. Raw attempts remain outside tracked files;
ic8-capture-attempts.json records paths, hashes and process outcomes.

## Preservation, validation and next step

The existing encoding checkpoint now contains72 selected byte-checked VM spans
and891 native rows. Newly preserved material includes9D5A,EF6B,EE7C,FBCB,9DE1,
FC07,FCBD,AAD7,AB1B, native67B7, native4C34 and exact selected parameter/data
records. This is not a lossless full-ROM decode or rebuild claim. Fresh Ghidra
metadata export remains unavailable; original ROMs/projects/settings are preserved.

Capture-SkillCash.ps1 adds NudgeIc8 to the previous full cycle-init flag chain;
add NudgeBackground for the second window. Use TailWindow/NoMotorItems and fresh
temporary directories. Curate-BoardLink.ps1 uses matching stage switches, without
NoMotorItems, and rejects nonzero exits. Export/encoding/data tools retain their
existing ROM SHA1 guards and checkpoint conventions.

150 headless groups and all eight GUI smoke modes pass. Headless and WPF builds
passed in isolated temporary output. Normal test-output DLLs were briefly locked
by an earlier verification process, so the final suite used the isolated build;
no user process was stopped or configuration changed.

Next recover native482F status lamps, then68F1 characteriser,6EF7 door mode,
6E99 NVRAM checks and2E53 service/Test guards. Preserve the actual conditions and
unsupported branches; do not replace these calls with unconditional no-ops.
Continue toward the real paid-game input loop. Collection retains its no-credit/
option/input prerequisites. Keep symbolic assembly tooling deferred.

No installations, configuration changes, commits, pushes or cloud setup occurred.

# Startup continuation to first VM entry

17 October 2026. A natural original-ROM MAME 0.281 observation continues past
the startup checksum return `677E` to the first threaded-VM entry at `76C7`,
where the initial stream pointer is `FDF0`. It uses a fresh isolated directory,
declared-absent NVRAM/configuration, no input playback, no PC/RAM/ROM injection
and the unmodified original image. It stops at that entry. No token semantics,
gameplay, modified-image boot or hardware claim is made.

## Evidence classes

- **Natural:** the original `a6ls.p1`, length 65536 and SHA1
  `402d1518bb78fdc489b06c2aabc771e5ce151847`, copied unchanged into the isolated
  run. The marker PCs below fired in real emulator execution.
- **Static:** the earlier initialization listing contains `6750` through
  `67B3`; `677E` is the return from the `66A5` checksum call, `67B3` jumps to
  `3B1A`, and `7CF6` calls the interpreter entry `76C7`. The prior checksum
  pass and its static fields are in [ROM integrity](ROM-INTEGRITY-PASS.md).
- **Hypothesis:** why the first checksum pass returns to `677E` and is followed
  by another reset, rather than immediately reaching `67B3`, is not proved.
  The capture records the restart; it does not assign a cause.
- **Synthetic:** curator negative controls alter copied raw artifacts only.
  They write no ROM and are not natural execution evidence.

## Observed sequence

The raw log contained three reset entries, three init entries and two completed
checksum passes. The curated chain is anchored to the checksum pass immediately
preceding the init tail:

```text
STARTUP_RESET pc=7CD1 s=07C2 cc=D0
STARTUP_INIT_ENTRY pc=6750 u=0672
STARTUP_ROM_CHECK_ENTRY pc=66A5 u=0672 gate719b=00
STARTUP_ROM_VERIFY_ENTRY pc=66DB u=066A expected=3E761E2605 start=1400 end=FFFF error=12
STARTUP_SUM_XOR sum=3E xor=76
STARTUP_ROTATE_ADD value=1E
STARTUP_ROTATE_SUB_XOR a=26 b=05
STARTUP_ROM_CHECK_RETURN pc=677E y=FFFF u=0672
STARTUP_INIT_TAIL_JMP pc=67B3 y=0000 u=0672
STARTUP_INIT_TAIL_ENTRY pc=3B1A y=0000 u=0672
STARTUP_VM_CALL pc=7CF6 x=FDF0 y=02DA u=0672
STARTUP_VM_ENTRY pc=76C7 x=FDF0 y=02DA u=0672 s=07C6
STARTUP_CAPTURE_END pc=76C7 x=FDF0 y=02DA u=0672
```

The first `677E` return in the same log was followed by a third reset. That
restart is an observed boundary, not a recovered explanation. The second
checksum pass passed the same active gate-00 record and computed the same
`3E 76 1E 26 05` fields before the init tail ran.

## Reproduction

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/Capture-StartupVmEntry.ps1 `
  -MameExecutable 'E:\Arcade\MAME0266\mame281.exe' `
  -RomDirectory 'E:\Arcade\MAME0266\roms' `
  -OriginalRom 'C:\Users\John\Documents\Codex\2026-10-13\help-me-set-up-a-local\outputs\mpu4\rom\a6ls.p1' `
  -RunDirectory 'artifacts/deepseek/general-06/mame-vm-entry-original-2' `
  -SecondsToRun 30

pwsh -NoProfile -ExecutionPolicy Bypass -File tools/Curate-StartupVmEntry.ps1 `
  -RunDirectory 'artifacts/deepseek/general-06/mame-vm-entry-original-2' `
  -OutputPath 'evidence/mpu4/integrity/original-startup-vm-entry.json' `
  -NegativeControl
```

Both commands exited `0`; MAME exited `0`. MAME 0.281 SHA256
`0fce5a88df4f9d9b1fbf1405812c00848036e615993780978d967da34204cb7a`.
The accepted run's debug log SHA256 is
`41b4970e790c0e7d26890bd65685ecef9b943fc47b4192a9d9ec6c4756f22a40`.
An independent fresh run (`mame-vm-entry-original-3`) produced the same debug
log SHA256 and was accepted by the same strict curator. Its console hash
differed because MAME reports a run-speed line; the curator recomputes each
console hash from its own raw file rather than comparing runs.

## Curator enforcement

The curator requires original/run-copy SHA1 `402d...`, verifies the actual
isolated copy is 65536 bytes with that SHA1, recomputes raw `debug.log` and
`console.txt` SHA256 values, requires both raw and observation exit `0` and
`rom_unchanged` true. It enforces the marker chain and `X=FDF0` at `7CF6` and
`76C7`, anchors the checksum chain to the pass before `67B3`, and rejects
`STARTUP_ROM_VERIFY_FAILED`. It also checks `arguments.json` and
`debugger.cmd` for the isolated ROM path, `-noreadconfig`, no state/playback/
autoboot/cheat/load, and only `bpset`/`printf`/`go`/`quit` observation
commands. Starting NVRAM/configuration absence remains a capture declaration.
Negative controls rejected altered sum, out-of-order VM entry, altered stream
pointer, provenance identity, false `rom_unchanged`, log hash, isolated ROM
hash, nonzero exit and debugger PC injection.

Curated output is `evidence/mpu4/integrity/original-startup-vm-entry.json`
(schema 3); the compact log is
`evidence/mpu4/integrity/original-startup-vm-entry.txt`.

## Limitation and next boundary

This is one cold original-image observation stopped at the first `76C7` entry.
It does not observe the first token fetch, attract/credit/input/reel/payout
behaviour, randomness, timing equivalence or physical hardware. The intervening
reset is unexplained. The next bounded observation is the first token dispatch
after `76C7` (for example the initial `FDF0` stream's first native call), using
the same identity and no-injection rules.

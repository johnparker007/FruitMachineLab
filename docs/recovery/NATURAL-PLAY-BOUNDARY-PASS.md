# Natural attract, controlled input and shared-award boundary

17 October 2026. A bounded MAME 0.281 observation continues the original and
integrity-repaired images beyond the first `76C7` VM entry. Both reach the
post-VM attract service path, accept a controlled emulated coin and Start, enter
paid-spin setup `61D6`, and read the shared award table at `75C0`. The read is
the same `14` on both images. The ordinary path did **not** read the patched
`75BE`, so the existing `0A` to `0C` edit is not exercised here.

## Evidence classes

- **Natural:** the unmodified original `a6ls.p1` (SHA1 `402d...`) and the
  previously generated repaired image (SHA1 `ae04...`, SHA256 `6616...`) in
  fresh isolated run directories. Reset, init, checksum, `76C7`, attract
  natives, paid-spin setup and the award-table read are real emulator execution.
- **Controlled input:** only MAME ioport field values. The Lua observer sets
  `:AUX2` mask `128` for 35.000-35.050s and `:BLACK2` mask `128` for
  37.000-37.200s. No PC, RAM, state, ROM or input playback is used.
- **Static:** `75BD` is the shared award table and `75BE` is the existing patched
  byte, from the prior patch and integrity-repair evidence.
- **Hypothesis:** why this paid path reads index `75C0` rather than `75BE` is not
  established. No award value, feature outcome or complete game is claimed.
- **Synthetic:** curator negative controls alter copied raw artifacts only and
  are rejected; they are not natural execution evidence.

## Observed sequence

Both images produced the same marker lines and cycles, apart from the expected
image identity and console loader warning:

```text
PLAY_RESET pc=7CD1 ... cycle=0000000000000007
PLAY_INIT_ENTRY pc=6750 ... cycle=000000000000002F
PLAY_ROM_CHECK_RETURN pc=677E ... cycle=0000000000C79D79
PLAY_VM_ENTRY pc=76C7 x=FDF0 ... cycle=00000000029F11C7
PLAY_MAIN_FIRST_NATIVE pc=496A ... cycle=00000000029F128C
PLAY_ATTRACT_LAMP_RANGE pc=4AC0 ... credit2f0=00 cycle=00000000029F1FD0
PLAY_LAMP_INIT pc=171D ... credit2f0=00 cycle=0000000002A2BD3B
PLAY_REEL_REFRESH pc=2BEB ... cycle=0000000002A2F455
PLAY_STATUS_SERVICE pc=482F ... credit2f0=00 cycle=0000000002A4D702
PLAY_PAID_SPIN_SETUP pc=61D6 ... cycle=0000000003D399AB
PLAY_AWARD_TABLE_READ address=75C0 value=14 credit2f0=04 cycle=0000000003EF2A91
```

The earlier reset entries are preserved in the compact text log. The service
markers show the machine in the post-VM loop before input; after the controlled
coin and Start it reaches paid-spin setup and the shared-table read.

## Input evidence

`actions.csv` contains exactly two events: `:AUX2` mask `128` coin at 35.0s and
`:BLACK2` mask `128` Start at 37.0s. `input-levels.csv` records the applied
fields and shows credit `05` after the coin. The award read records credit
`04`, consistent with one credit consumed by the paid start. The debugger
marker `b@0x2f0` reads `00` during attract and `04` at the award read, matching
the Lua program-space samples; the Lua log also records the peak `05`.

## Differential and repeat

The original and repaired runs have identical marker cycles and identical
`75C0 value=14`. A fresh original repeat (`mame-coinstart-original-5`) produced
byte-identical marker lines. The repaired image remains distinguishable only by
its identity and MAME loader warning; this path does not consume the patched
byte.

## Reproduction

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Capture-PlayBoundary.ps1 `
  -MameExecutable <mame281.exe> -RomDirectory <roms> `
  -OriginalRom <a6ls.p1> -RomPath <a6ls.p1> -Variant Original `
  -ExpectedRomSha1 402d1518bb78fdc489b06c2aabc771e5ce151847 `
  -ExpectedRomSha256 ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c `
  -RunDirectory artifacts/deepseek/general-09/mame-coinstart-original-3 `
  -InputMode CoinStart -SecondsToRun 90

powershell -NoProfile -ExecutionPolicy Bypass -File tools/Capture-PlayBoundary.ps1 `
  -MameExecutable <mame281.exe> -RomDirectory <roms> `
  -OriginalRom <a6ls.p1> -RomPath <repaired.p1> -Variant Repaired `
  -ExpectedRomSha1 ae040f3f130934972b9e651d4dbe36ff24fb4954 `
  -ExpectedRomSha256 66162b920b05c537a5c7bce098d883b0551951ed46aa97cd98600a3d7b789796 `
  -RunDirectory artifacts/deepseek/general-09/mame-coinstart-repaired-1 `
  -InputMode CoinStart -SecondsToRun 90

powershell -NoProfile -ExecutionPolicy Bypass -File tools/Curate-PlayBoundary.ps1 `
  -OriginalRunDirectory artifacts/deepseek/general-09/mame-coinstart-original-3 `
  -RepeatRunDirectory artifacts/deepseek/general-09/mame-coinstart-original-5 `
  -RepairedRunDirectory artifacts/deepseek/general-09/mame-coinstart-repaired-1 `
  -OutputPath evidence/mpu4/play/natural-award-boundary.json -NegativeControl
```

All commands exited `0`; MAME exited `0`; both run ROM copies retained their
expected SHA1/SHA256. The curator recomputes raw debug/console/input and
run-ROM image hashes, requires the marker chain and cycles, checks the two
input events and credit, requires identical original/repaired award reads, and
rejects eight copied-file negative controls.

## Limitations and next boundary

This is one cold reset per image, MAME-only, with two synthetic input events; it
is not physical-hardware evidence. The selected debugger instrumentation did not
observe the `FC99`/`FCA7` condition-12 preplay block; the runtime evidence for
input readiness is credit present plus accepted Start at `61D6`. The natural
lookup reads `75C0`, not the patched `75BE`. No complete paid game, reel result,
payout or Skill Cash feature is claimed.

Next: instrument the VM input-condition opcode or the exact preplay branch so
`FC99`/condition 12 is visible, then drive a result path that reads `75BE` and
compare `0A`/`0C` on original and repaired images.

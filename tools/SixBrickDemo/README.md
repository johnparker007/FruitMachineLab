# Six-brick feature playtest

One continuous game replaces the first collected Snake Bite feature. Six bricks
start across the top. Ball collisions remove bricks and reflect the ball. A
bottom miss or clearing all six gives a short flash, then exits the feature.
There are no additional rounds, lives, score, Alpha or payout additions.

From the repository root, launch your playtest with a new run directory:

```powershell
& .\tools\SixBrickDemo\Run-SixBrick.ps1 `
  -OriginalRom .\artifacts\deepseek\il-natural-06\runs\original-01\roms\m4addr\a6ls.p1 `
  -RunDirectory .\artifacts\six-brick-playtest-01 -Mode Manual
```

The launcher fast-forwards the known fresh-boot replay, switches to normal speed
before the feature, and releases all nine scripted input overrides at entry.
Focus MAME; **Left Alt** moves left and **Space** moves right (Hold 1 / Hold 2).
The paddle is two adjacent lamps. The game starts immediately; there is one ball.
Choose a different, nonexistent run directory for another attempt.

`-Mode AllClear` supplies automatic paddle button inputs for verification;
`-Mode Miss` supplies no paddle inputs. `Manual` is for human play. Human keyboard
play and physical MPU4 hardware compatibility remain unverified.

Defaults use the existing MAME at `E:\Arcade\MAME0266\mame281.exe`, its support
ROMs and BGFX assets. Paths can be supplied as launcher parameters. No installed
configuration or original ROM is changed; all generated files stay in the new
run directory. The modified-ROM checksum warning is expected.

The original must be the 65536-byte A6L0.1set1 image, SHA1
`402D1518BB78FDC489B06C2AABC771E5CE151847`. The tested repaired SHA256 is
`C0F40BF86311773824BF8A6DDA21EA8DE0C7E1169DAE1142DDF97641EC190F9E`.
The payload occupies **888/992 bytes**, `1010–1387`, with 104 bytes free and
both allocation guards preserved. Each build writes its exact patch record.

The original completion tail at D086 restores the entry-saved words at 0300 and
02FE; it does not enter original Snake Bite gameplay at D003. The launcher checks
their preservation, the feature return and balanced stacks. This is a MAME
playtest candidate, not a hardware compatibility claim.

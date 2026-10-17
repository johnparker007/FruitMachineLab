# Startup ROM integrity self-check recovery

17 October 2026. Static recovery of the original ROM sum/XOR self-check used by
`startup_verify_rom_checksums` (66A5) and `verify_rom_region_sum_xor` (66DB).
No repair, re-signing, bypass, patch, emulator schedule or gameplay claim is made.
This is an independent static increment: it does not touch the sound wrapper or
the C# runtime and test code that already have uncommitted work.

## Evidence classes

- **Natural/static image fact:** the original `a6ls.p1` bytes, length 65536 and
  SHA1 `402d1518bb78fdc489b06c2aabc771e5ce151847`. The five active expected
  fields in the image equal the values computed from the image by the recovered
  algorithms. File offsets equal CPU addresses for this selected image, as
  recorded in `evidence/mpu4/maps/rom-layout.json`.
- **Static instruction deduction:** the table layout, range fields, gate and
  algorithms below come from the saved assembly exported from the documented
  original workspace prerequisite pass. The two relevant exports are now curated
  as `evidence/mpu4/native/66a5.json` and `evidence/mpu4/native/66db.json`.
  `docs/recovery/FUNCTION-INDEX.txt` gives the existing mechanical names.
- **Hypothesis:** the meaning of the disabled records, the `0x12` error code and
  why each algorithm excludes a differently sized part of the expected-field
  area are not proven. They are reported as stored/observed, not explained.
- **Synthetic:** the tool's optional in-memory negative control flips one byte
  and checks that the sum/XOR no longer match. It never writes a ROM and is not
  natural execution evidence.

## Recovered table

66A5 reserves an 8-byte scratch frame, then reads four 11-byte records starting
at `FFB0`. The loop advances by `0B` and terminates when the base would be
`FFDC`. Before any record is read, 66A5 tests ROM byte `719B` bit1; a set bit
returns immediately. The original image has `00` there, so bit1 is clear and the
record loop runs. This is an original ROM option, not a bypass introduced here.
Record layout:

| Offset | Meaning |
| --- | --- |
| +0 | expected additive sum |
| +1 | expected XOR |
| +2 | expected `rotate_add` accumulator A |
| +3, +4 | expected `rotate_sub_xor` accumulators A, B |
| +5, +6 | start pointer (big-endian) |
| +7, +8 | end pointer (big-endian, inclusive) |
| +9 | error code stored in the scratch frame; used as B for `SWI` on failure |
| +10 | gate: `TSTB/BNE` skips the record when nonzero |

Original records:

| Base | Start | End | Gate | Error | Expected bytes | State |
| --- | --- | --- | --- | --- | --- | --- |
| FFB0 | 1400 | 5FFF | FF | 15 | `FF FF FF FF FF` | disabled |
| FFBB | 1400 | 7FFF | FF | 14 | `FF FF FF FF FF` | disabled |
| FFC6 | 1400 | FFFF | FF | 13 | `FF FF FF FF FF` | disabled |
| FFD1 | 1400 | FFFF | 00 | 12 | `3E 76 1E 26 05` | **active** |

The three disabled records have ranges that end before or at the active range.
Their expected fields and gates are stored as `FF`; no repair or placeholder
value was invented. Enabling one would require separate evidence, not this tool.

## Exact algorithms

All three scan the inclusive active range `1400..FFFF`; the overlapping
expected-field area is excluded differently by each algorithm.

1. **`sum_xor`** (fields +0, +1; excludes `FFD1..FFD5`): 8-bit `ADD` and `XOR`
   of each byte. When the pointer increments from `FFD0` to `FFD1`, it is
   redirected to `FFD6`.
2. **`rotate_add`** (field +2; excludes `FFD3..FFD5`): per byte `ROLB`;
   `ADCA ,X`; `RORB`. The carry entering the next `ROLB` is not the `RORB`
   carry: it is the carry produced by `CMPX #FFD3` after the pointer increment.
   That address comparison therefore influences the accumulator. When the
   incremented pointer equals `FFD3`, it is redirected to `FFD6`. Only A is
   compared.
3. **`rotate_sub_xor`** (fields +3, +4; excludes `FFD4..FFD5`): per byte
   `LSLB`; `ADCB #0`; `SUBB ,X`; save B; copy A to B; three `ASRB`/`RORA`
   pairs; restore B; `EORA ,X`. When the incremented pointer equals `FFD4`,
   it is redirected to `FFD6`. A and B are compared.

The varying exclusions are consistent with nested fields: the sum/XOR pair
excludes the whole active expected-field area; `rotate_add` does not cover its
own field or later fields; `rotate_sub_xor` does not cover its own two fields.
The intent is a hypothesis; the skip addresses are instruction facts.

## Natural reset boot oracle

A separate natural observation of the original image now reaches the active check
and returns to its caller. It uses an isolated fresh directory with declared
absent NVRAM and configuration, no input playback and `-noreadconfig`. The
original `a6ls.p1` was copied into the isolated run; the curator requires the
recorded original/run-copy SHA1 values to equal `402d...` and verifies the actual
isolated copy length `65536` and SHA1 after the run. It also recomputes
the raw `debug.log` and `console.txt` SHA256 values, requires exit `0`, checks
the required breakpoint PCs and the chronological checksum chain
`66A5 -> 66DB -> 66F3 -> 6715 -> 674C -> 677E -> end`. It reads the captured
`debugger.cmd` and `arguments.json` and rejects state loading, playback,
autoboot, cheat, memory/PC-write or ROM-replacement claims. Starting NVRAM and
configuration absence remain capture declarations because the post-run
directory cannot prove pre-run emptiness; `-noreadconfig` is verified from the
arguments.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Capture-RomIntegrityBoot.ps1 `
  -MameExecutable 'E:\Arcade\MAME0266\mame281.exe' `
  -RomDirectory 'E:\Arcade\MAME0266\roms' `
  -OriginalRom 'C:\Users\John\Documents\Codex\2026-10-13\help-me-set-up-a-local\outputs\mpu4\rom\a6ls.p1' `
  -RunDirectory 'artifacts/deepseek/general-04/mame-reset-boot-original-5'

powershell -NoProfile -ExecutionPolicy Bypass -File tools/Curate-RomIntegrityBoot.ps1 `
  -RunDirectory 'artifacts/deepseek/general-04/mame-reset-boot-original-5' `
  -OutputPath 'evidence/mpu4/integrity/original-reset-boot.json' -NegativeControl
```

Both commands exited `0`. MAME 0.281 SHA256
`0fce5a88df4f9d9b1fbf1405812c00848036e615993780978d967da34204cb7a`; run exit
`0`. The compact observed sequence was:

```text
BOOT_RESET pc=7CD1 s=0000 cc=50
BOOT_INIT_ENTRY pc=6750 u=0672
BOOT_RESET pc=7CD1 s=07C4 cc=58
BOOT_INIT_ENTRY pc=6750 u=0672
BOOT_ROM_CHECK_ENTRY pc=66A5 u=0672 gate719b=00
BOOT_ROM_VERIFY_ENTRY pc=66DB u=066A expected=3E761E2605 start=1400 end=FFFF error=12
BOOT_SUM_XOR sum=3E xor=76
BOOT_ROTATE_ADD value=1E
BOOT_ROTATE_SUB_XOR a=26 b=05
BOOT_ROM_CHECK_RETURN pc=677E y=FFFF u=0672
BOOT_CAPTURE_END pc=677E y=FFFF
```

The capture stopped immediately after the successful return to caller `677E`;
that is the next startup boundary recorded here. Two reset entries were observed
before the check. Why the cold-NVRAM path restarts once before reaching `66A5`
is a hypothesis, not proved by this capture. A second independent fresh run
(`mame-reset-boot-original-6`) produced identical `BOOT_` lines and the same
debug-log SHA256 `dee6c959...`; the strict curator accepted it unchanged. The
failure marker at `674D` was absent. Synthetic negative controls on copied raw
artifacts altered the sum, moved a marker out of order, changed provenance
identity, changed the starting-contract claim, set `rom_unchanged` false,
changed the recorded log hash, changed and truncated the isolated ROM copy,
changed the exit code and added a debugger PC write. Each was rejected; none
writes a ROM. Curated output is
`evidence/mpu4/integrity/original-reset-boot.json` (schema 2) plus its compact
log.

## Verification

`tools/Verify-RomIntegrity.ps1` performs a strict original-identity check, reads
the table, emulates the saved instructions exactly and compares all five active
fields. It can also validate the curated JSON report and run a synthetic
in-memory negative control.

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Verify-RomIntegrity.ps1 `
  -RomPath 'C:\Users\John\Documents\Codex\2026-10-13\help-me-set-up-a-local\outputs\mpu4\rom\a6ls.p1' `
  -ReportPath evidence/mpu4/maps/rom-integrity.json -NegativeControl
```

Observed exit `0`:

```text
startup gate 719B=00 bit1=0 enabled
ROM a6ls.p1 length=65536 sha1=402d... OK
table base=FFB0 record_size=11 records=4 termination=FFDC
record FFB0 start=1400 end=5FFF gate=FF error=15 disabled
record FFBB start=1400 end=7FFF gate=FF error=14 disabled
record FFC6 start=1400 end=FFFF gate=FF error=13 disabled
record FFD1 start=1400 end=FFFF gate=00 error=12 enabled
  sum_xor.sum expected=3E computed=3E OK skip=FFD1-FFD5
  sum_xor.xor expected=76 computed=76 OK skip=FFD1-FFD5
  rotate_add expected=1E computed=1E OK skip=FFD3-FFD5
  rotate_sub_xor.a expected=26 computed=26 OK skip=FFD4-FFD5
  rotate_sub_xor.b expected=05 computed=05 OK skip=FFD4-FFD5
enabled=1 verified=1 failed=0
report evidence/mpu4/maps/rom-integrity.json OK
synthetic negative control: in-memory byte 1400 change detected (sum 3F, xor 77)
```

Additional synthetic checks, all outside the repository:

- A one-byte-changed temporary image is rejected before table processing with
  `Unexpected ROM identity: SHA1 42eb...`, exit `1`.
- A temporary report with `rotate_add.computed=00` is rejected with
  `Report mismatch: verified.rotate_add.computed actual=00 expected=1E`,
  exit `1`.
- The original image and the curated report were not modified by these checks.

The headless build was not required by this increment because no C# project or
test file changed. The full verification suite was not run: the working tree
already contains the incomplete timer1 sound-wrapper work and a known focused
failure (`Native sound command budget exhausted`). That failure is pre-existing
and is not a regression from this static increment; no pre-existing expectation
was disabled or changed.

## Boundaries

- Only the gate-00 record is an active check. The other three records are
  reported, not exercised.
- The recovered algorithms certify the original image. They do not establish
  what values a modified image "should" contain, and this work deliberately
  does not update or re-sign the five fields.
- MAME loader CRC/SHA warnings, the 68F1 characteriser challenge records and
  NVRAM/meter-queue checksums are separate mechanisms and are not covered.
- The natural reset observation above reaches `66A5`/`66DB` and returns to
  `677E` on the original image. It does not demonstrate modified-image boot,
  executable handoff beyond that boundary, gameplay or physical hardware.

## Next boundary

Decide separately whether modified-image integrity repair is in scope. If it
is, any re-signer must reproduce all three skip sets and the `rotate_add`
address-comparison carry exactly, and must be validated against the natural
original/MAME boot oracle now recorded in
`evidence/mpu4/integrity/original-reset-boot.json` rather than assumed. That
oracle currently covers only the original image through the `677E` return.
Until then, preserve the original image and report integrity mismatches
explicitly.

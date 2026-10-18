# IL extension range reservation: A6L 0.1 set 1 `1010-13EF`

Status: **human-approved reservation; not allocated, executed or hardware-validated**.
John approved the exact range for the exact revision on 18 October 2026. This
document records that approval and the static evidence behind it. It does not
implement an allocator, linker or emitter, and it does not claim that any byte in
the range has been written or executed.

## Approval record

| Item | Recorded value |
| --- | --- |
| Approved by | John |
| Date | 18 October 2026 |
| Exact statement | "I confirm you are ok to use that range btw. It is a little larger, I just left I think 16 bytes each side for a safety head/tail." |
| Revision | A6L 0.1 set 1, `a6ls.p1`, 65536 bytes, SHA1 `402d1518bb78fdc489b06c2aabc771e5ce151847`, SHA256 `ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c` |
| Approved range | CPU/file `1010-13EF`, inclusive, 992 bytes (`03E0`) |
| Left guard | `1000-100F`; protected cells `1000-1003` |
| Right guard | `13F0-13FF` |
| Integrity start | `1400` |
| Mapping assumption | Bank 0 only; future bank changes need separate runtime evidence |
| Allocation performed | No |
| ROM write performed | No |
| Boot/execution observed by this work | No |
| Physical hardware validated | No |

The approval is bound to this exact revision, range and guard set. It is not a
generic claim about padding, other revisions, other MPU4 sets or bank-switched
execution.

### Correction of task 26 wording

Task 26 correctly recorded the range as a candidate but wrote that John's answer
was still pending and that confirming the range did not authorize a linker. Both
statements are superseded here:

- John confirmed the range on 18 October 2026.
- Under the continuing supervised mandate, no further approval is required for
  this range or for bounded development in it, including a bounded
  allocator/linker. Implementation remains a separate scheduled task and is not
  performed or claimed here.

This correction does not weaken any technical limitation. Approval is a human
reservation decision; it is not proof that the bytes are unused and it does not
certify a build, boot or hardware result.

## Exact original identity

| Property | Value |
| --- | --- |
| MAME set / revision | `m4addr`, Classic Adders & Ladders A6L 0.1 set 1 |
| File | `a6ls.p1` |
| Length | 65536 bytes |
| SHA1 | `402d1518bb78fdc489b06c2aabc771e5ce151847` |
| SHA256 | `ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c` |
| MAME source identity | `GAME_CUSTOM( 1991, m4addr, ..., "a6ls.p1", ... SHA1(402d1518...) )` with `init_m4` |

Identity checks must fail for any other revision even if the candidate bytes
happen to match.

## Approved range and guards

| Region | CPU / file range | Length | Expected bytes | SHA1 | SHA256 |
| --- | --- | ---: | --- | --- | --- |
| Left guard | `1000-100F` | 16 | all `FF` | n/a | n/a |
| Protected cells | `1000-1003` | 4 | all `FF` | n/a | n/a |
| Approved range | `1010-13EF` | 992 (`03E0`) | all `FF` | `eee7e8ec3670c1fb218bb9839c01277394e00c09` | `1a7a6a16a718aaf4221baa1f787612dd995aaa5b083cfb9409023ac6c0985c16` |
| Right guard | `13F0-13FF` | 16 | all `FF` | n/a | n/a |
| Integrity start neighbor | `1400-1407` | 8 | `34 36 31 A9 14 5D 8E 01` | n/a | n/a |

The approved range is a proper subset of historical task 25 candidate C1
`1004-13FF` (1020 bytes, also all `FF`). The 12 bytes `1004-100F` remain part of
the left guard and are not claimed by the reservation.

## Mapping

For this selected 64 KiB image, CPU bank-0 ROM window `1000-FFFF` uses the same
file offsets. The approved range therefore maps to file offsets `4112-5103`
inclusive.

Curated evidence:

- `docs/recovery/README.txt:58-66`: runtime ROM bank 0 `1000-FFFF` from matching
  offsets; bank changes require separate runtime evidence.
- `evidence/mpu4/maps/rom-layout.json`: `file_address_rule` and partial
  constraints.

Historical prior conclusion from task 25, recorded but not reverified by the
tracked checker:

- MAME 0.281 `mpu4_memmap` maps `1000-FFFF` through `bank1`, and
  `setup_rom_banks` configures the non-extended 64 KiB image at `&rom[0x01000]`.
- The `m4addr` entry uses `a6ls.p1` with the exact SHA1 above and `init_m4`.
- Historical source hashes: `mpu4-mame0281.cpp` 81256 bytes SHA256
  `8efb9b50e48e49e274f60d3a63fe8611de74e96d316fe54c0b8ad0e3bf996d0f`;
  `mpu4mod4yam-mame0281.cpp` 166506 bytes SHA256
  `7a3249fbde3e35490653c1a3568332988ff01e4a6019a8c44f2d437c49e36ac9`.

The checker does not download MAME source and does not silently present this
prior conclusion as reverified. Optional, explicit source-file checks can be
requested separately.

This is a bank-0 model. It is not proof that every possible bank-select write
leaves this range unused.

## Neighbors and guards

- `1000-1003` are dormant reset fallback pointer cells. Reset bytes `7CEA`
  (`LDX $1000`) / `7CF4` (`LDX ,X`) and `7D26` (`LDX $1002`) reference them.
  Original `719A=00` selects the `BEQ 7CF4` path, and original `FFF8=FE70`
  keeps the `7D26` alternate path dormant. They stay untouched.
- `1004-100F` are all `FF`, but are retained as left guard rather than claimed
  by this reservation.
- `13F0-13FF` are all `FF` and are retained as right guard.
- `1400` starts the recovered active firmware integrity range and begins with
  `34 36 31 A9 14 5D 8E 01`. It stays untouched.

## Known-reference checks and method limits

Reusing the task 25 bounded method over the approved range:

| Check | Result |
| --- | --- |
| Decoded native assembly tokens in `1010-13EF` | 0 |
| Decoded VM listing tokens in `1010-13EF` | 0 |
| Opcode-adjacent unresolved patterns | 18 |
| Protected-range overlap | 0 |
| Integrity record overlap | 0 |

The native and VM scans are textual token scans over curated listings, not a
disassembler or a decoded reference graph. The listings are incomplete and may
contain non-address four-hex-digit values. Zero matches therefore means "no
match in the current curated inventory", not "no possible use".

The opcode-adjacent scan treats the byte after one of 12 absolute-form opcode
candidates as the high byte of an apparent operand. It does not decode
instruction length, addressing mode, load/store direction, branches, threaded-VM
tokens or reachability. An opcode byte may be an immediate or data byte; a write
to a ROM address does not read the candidate bytes.

All 18 matches were inspected. None is a decoded reference:

| Offset | Opcode | Operand | Classification | Limitation |
| --- | --- | --- | --- | --- |
| `167D` | `F7` | `10AE` | native write candidate | would be `STB $10AE`; apparent ROM write, not a read |
| `227E` | `FE` | `108E` | immediate low byte | low byte of `LDX #$03FE`; not an opcode |
| `237C` | `FE` | `108E` | immediate low byte | low byte of `LDX #$03FE`; not an opcode |
| `2689` | `FE` | `108E` | immediate low byte | low byte of `LDX #$03FE`; not an opcode |
| `26DD` | `FE` | `108E` | immediate low byte | low byte of `LDX #$03FE`; not an opcode |
| `3667` | `F7` | `10CE` | native write candidate | would be `STB $10CE`; apparent ROM write, not a read |
| `36F0` | `7F` | `1026` | native write candidate | would be `CLR $1026`; apparent ROM write, not a read |
| `43A3` | `7F` | `108E` | immediate low byte | immediate operand of `ANDA #$7F`; not an opcode |
| `60DA` | `FE` | `1200` | data or stream bytes | surrounded by `00`/`FF` data-like bytes |
| `8E38` | `8E` | `10C0` | data or stream bytes | would be `LDX #$10C0`, but sequence is data-like |
| `96A0` | `CE` | `12CE` | repeated data pattern | part of `2B 92 06 CE ...` |
| `96AC` | `CE` | `12CE` | repeated data pattern | part of `2B 92 06 CE ...` |
| `96B8` | `CE` | `12CE` | repeated data pattern | part of `2B 92 06 CE ...` |
| `96C4` | `CE` | `12C0` | repeated data pattern | embedded in the same repeated sequence |
| `96D3` | `CE` | `1282` | repeated data pattern | embedded in the same repeated sequence |
| `B597` | `8E` | `10A7` | VM stream or data bytes | would be `LDX #$10A7`; not decoded |
| `B74D` | `B7` | `1081` | native write candidate | would be `STA $1081`; apparent ROM write |
| `F150` | `8E` | `10A6` | VM stream or data bytes | would be `LDX #$10A6`; not decoded |

These are unresolved heuristics whose apparent operands fall in the range. They
are not decoded native or VM references and are not proof of execution. The
absence of a decoded reference is not a complete no-use proof.

## Integrity and protected structures

The recovered active record is `FFD1`: `start=1400`, `end=FFFF`, gate `00`,
error code `12`, original fields `FFD1-FFD5 = 3E761E2605`. The record table base
is `FFB0`, record size 11, termination `FFDC`; there is one active record and
three stored, disabled records. The outer gate at `719B` has bit 1 clear.

The approved range ends before `1400`, so it is outside the recovered firmware
self-check coverage. This is not a bypass:

- loader CRC/SHA warnings are separate and are not suppressed;
- characteriser checks are separate and are not evaluated;
- the range is therefore not certified by the firmware integrity fields.

CPU vectors remain original: `FFF2/FFF4 -> FE66`, `FFF6 -> FE56`,
`FFF8 -> FE70`, `FFFA -> 3620`, `FFFC -> FE51`, `FFFE -> 7CCF`; `FFF0` is
reserved and is not a CPU vector. The vector table, integrity table and active
fields stay outside the approved range.

## Evidence classes

**Human-approved reservation**

- John approved this exact range, revision and guard set on 18 October 2026.
- The approval permits bounded development in this range under the continuing
  mandate; no separate linker/allocator approval is required.
- The approval does not itself allocate, write, execute, boot or hardware-validate.

**Static verified by this task**

- Exact original length/SHA1/SHA256 and exact range bytes/hashes.
- Both 16-byte guards all `FF`; `1400` expected start bytes.
- Bank-0 same-offset mapping for the selected image, per curated evidence.
- Active integrity range starts at `1400`; table and vector values unchanged.
- Zero decoded native/VM listing tokens under the curated textual scans; 18
  unresolved opcode-adjacent patterns, with all 18 individually inspected.

**Curated prior conclusions (not re-audited here)**

- The MAME 0.281 memmap/setup conclusion and source hashes from task 25.
- The proper-subset relation to task 25 candidate C1 `1004-13FF`.
- The completeness limits of the native/VM reference inventory.

**Trace-backed (prior work)**

- Existing accepted MAME captures establish original reset/startup and early VM
  entry. They do not execute or validate a write into `1010-13EF`.

**User-reported empirical observation**

- John reports patching `1010-13EF` with a different value and loading/running
  the ROM in MFME without observed issues.

**Hypothesis**

- The all-`FF` run is usable free space for this exact revision, subject to the
  guards and technical checks. Padding appearance alone is not proof.

**Not established**

- No worker MAME run, patched-image boot, gameplay result or physical hardware
  test was performed.
- No allocator, linker, emitter, new VM word, ROM write or output image exists.
- No complete whole-ROM decode or complete reference inventory exists.
- No claim that all possible bank-select paths avoid this range.
- No claim that the range is allocated or that approval proves it is unused.

## User-reported MFME test

| Item | Recorded condition |
| --- | --- |
| Reporter | John |
| Reported on | 18 October 2026 |
| Statement | Patched the range with a different value; the ROM loaded in MFME and ran with no reported issues |
| Value written | unknown |
| Test duration / coverage | unknown |
| Loader warnings | unknown |
| Reproduced by worker | no |
| Physical hardware proof | no |
| Classification | user-reported empirical observation, not independently reproduced |

This observation is valuable but does not prove natural execution under MAME or
on physical MPU4 hardware, and it does not establish that every game path avoids
the range.

## Remaining risks

1. Padding appearance is not proof of free space; human approval is a reservation
   decision, not a technical no-use proof.
2. The reference inventory is incomplete; 18 opcode-adjacent patterns are
   unresolved, not certified references.
3. The range is outside the active firmware checksum, so firmware does not
   certify contents written there. Loader and characteriser checks are separate.
4. Bank-0 mapping is established for this 64 KiB set; future bank changes need
   separate runtime evidence.
5. The MFME observation is not independently reproduced and may differ from
   MAME and physical hardware.
6. The guards and dormant pointer cells must be preserved exactly.
7. No natural fresh-boot MAME execution, gameplay or hardware compatibility is
   established for any write to this range.

## Scope boundary

This is an approved reservation only. It does **not** implement or claim:

- an allocator, linker, emitter or native trampoline;
- new composite VM words or 6809 primitives;
- any ROM write, output image, patch, integrity regeneration or MAME run;
- bank switching or general relocation;
- allocation, successful boot, gameplay or hardware compatibility.

Unlike the superseded task 26 wording, no separate approval is required for a
future bounded allocator/linker in this exact range under the continuing mandate.
That future task still has to enforce identity, bounds, non-overlap, expected
bytes, guards, overflow and explicit rejection of unsupported references.

## Reproduction and checker portability

The tracked static checker is `tools/Test-IlExtensionRangeProposal.ps1` and the
machine-readable record is
`evidence/mpu4/integrity/il-extension-range-proposal.json`.

Normal validation needs only a clean tracked checkout and an explicit original
ROM path:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  tools/Test-IlExtensionRangeProposal.ps1 `
  -RomPath <original-a6ls.p1> `
  -OutputDirectory <fresh-output-directory>
```

No private task artifact or network download is required. The checker reproduces
ROM identity, range/guard bytes, hashes, integrity/vector bytes and the bounded
heuristic scans from the input image and tracked curated evidence. It validates
the recorded MAME-source conclusion and prior candidate relation as curated
prior evidence, clearly labeled as not reverified.

An optional explicit source check may be requested with
`-PriorAuditSourceDirectory <task-25-source-directory>`. It is recorded
separately, verifies the historical file hashes, and is not silently treated as
part of normal clean-checkout validation.

The checker is read-only. It writes no ROM image and runs no emulator.

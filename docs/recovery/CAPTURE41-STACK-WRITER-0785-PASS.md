# Capture41 stack writer 0785

Trace-only pass. One armed controlled-input run captured a fresh first `FC4D` to
first `5CD0` gap with a write watchpoint over `0780..078F`. No runtime, Live,
adapter, fixture regression or later-delta change. The fresh occurrence is its
own cycle/state and is not the historical occurrence.

## Occurrence and anchors

- `FC4D` cycle `0x3C592B3`, `S=07AA`, `X=8132`, `Y=FC4D`; `0047=0000`,
  `0049=01A0`, `004D=00`.
- Queue `5C18` cycle `0x3C5931F`, `S=0798`, return `59E9`.
- Outer `FE70` cycle `0x3C59673`, `S=078D`, frame `C047 2700 80A6 FC4F 0672 025A`.
- Nested `FE70` cycle `0x3C5994E`, `S=0778`; `FF13` cycle `0x3C59A27`, `S=0778`.
- `FEC9` cycle `0x3C59CEE`, `S=078D`; first `5CD0` cycle `0x3C59CF6`, `S=078B`,
  `U=0672`, `X=0366`, `Y=0000`, return word `FECC`.
- 51 logged events: 1 `FC4D`, 1 queue, 2 `FE70`, 1 `FF13`, 1 `FEC9`, 44 stack
  writes, 1 `5CD0`. Event cap 128 and save cap 4 were not reached.

## Watchpoint semantics

Installed MAME 0.281 `help wpset` defines `wpaddr` as the access address and
`wpdata` as the value being written. MAME source `points.cpp:231-237` installs a
write tap with `u8 &data`; `debug_watchpoint::triggered` (`points.cpp:314-355`)
sets `wpinfo` and runs the action before the tap returns and the write commits.
Therefore `old=b@wpaddr` is the pre-write byte, `new=wpdata` is the value about
to be committed. M6809 `read_opcode_arg` increments PC during operand fetch
(`m6809.h:214-216`), so tap PC is post-fetch; instruction starts come from the
logged pre-PC bytes and the original ROM, not from the final value.

Independent after-state: replaying all 44 events from `fc4d.bin` old values
reproduces every `old` and every final `0780..078F` byte in `stop5cd0.bin`.

## Actual 0785 writers

The first watched write to `0785` is **not** the final-value writer:

- `0x70EF 34 05 PSHS B,CC` (tap PC `70F1`), cycle `0x3C597BB`, `S=0785`,
  `B=3F`, `CC=C0`, `0785 00->3F`.
- Final-value writer: **`0x19B8 BD 1A 87 JSR $1A87`** in
  `irq_accumulate_inputs_and_check_modes`, callee
  `accumulate_mux_input_or_and_samples`. Tap PC `19BB` is the saved return
  address; cycle `0x3C5990F`, `S=0785`, `A=07 B=99 X=0007 Y=0028 U=0672 DP=00
  CC=C0`, `0785 3F->19`. The byte is the high byte of return word `19BB`.
- Same-value rewrites by `0x19BB JSR $1A05` (return `19BE`) and
  `0x19BE JSR $1A58` (return `19C1`) keep `0785=19`.

The observed chain is `FEC0 JSR 27D2(return FEC3) -> 2809 JSR 438C(280C) ->
439A JSR [$00C6](439E, word 00C6=19B8) -> 19B8 JSR 1A87(19BB) ->
19BB JSR 1A05(19BE) -> 19BE JSR 1A58(19C1) -> 280C JSR 6403(280F) ->
FEC3 JSR 6B4D(FEC6) -> 6B4D call 5330(6B6A) -> FEC6 JSR 58BB(FEC9) ->
FEC9 JSR 5CD0(FECC) -> 5CD0`. Nested `FE70/FF13` occurs during the `1A87`
path. The indirect caller at `439A` is `AD 9F 00 C6 JSR [$00C6]`; both the
return write `439E` and the `00C6=19B8` pointer are observed.

## Validation and provenance

- ROM `a6ls.p1` SHA1 `402D1518BB78FDC489B06C2AABC771E5CE151847`; `m4addr.zip`
  SHA256 `E2553AFA6B8E9DEF55BD920E4BED77A4324696C1E358B73BE70BFD2C58179989`.
- MAME 0.281 SHA256 `0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A`.
- Source `input.lua` `7C664323...179D0D`; replay `4A051DA1...0E721D`;
  derived input `BC93C069...475957` with only the declared patch.
- `tools/Capture-StackWriter0785.ps1` ran with `-seconds_to_run 430`,
  `-EventCap 128`, `-SaveCap 4`, hard timeout 600 s; capture exit `0`.
- `tools/Curate-StackWriterCapture41.ps1` exit `0`;
  `tools/Test-StackWriterCapture41.ps1` exit `0` with one positive and 12
  isolated negatives (wrong stop `S`, missing final writer, tampered writer
  value, tampered RAM, injected debugger command, altered input/arguments,
  wrong exit, wrong MAME/ROM/source, wrong prior fixture).
- Prior capture36 fixture and raw files were re-hashed unchanged. No state
  load, RAM write, fill, cheat, device/PTM/ACK injection or replay reseeding.
- Curated fixture: `evidence/mpu4/collection/stack-writer-0785-capture41.json`,
  107,233 bytes, SHA256 `D23207FA7EBD2221124EBDACE8DAAA83F6B181566F301B236CA431518C1A5680`.
- Watchpoint help/source provenance:
  `artifacts/deepseek/capture-41/watchpoint-semantics.txt` and
  `mame0281-help-wpset.txt` (raw, ignored).

## Limits and next task

The fresh `0785` final value `19` matches the historical net delta, but the
fresh gap also has an intermediate `3F`; it is not claimed as the identical
historical gap. Only this single gap is traced. Later inter-service deltas,
downstream consumers and autonomous IRQ cadence remain open.

Next safe task: obtain one independent second natural `FC4D..5CD0` gap and
repeat the same `0780..078F` write watchpoint, then compare the exact
`FEC0/27D2/2809/438C/439A/19B8/1A87` write order. Only after that trace should
later transitions or an adapter be considered.

STOP

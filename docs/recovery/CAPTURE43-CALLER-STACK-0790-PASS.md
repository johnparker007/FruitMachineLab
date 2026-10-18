# Capture43 caller-stack 0790..079F

One bounded controlled-input run captured a fresh first `FC4D` -> first `5CD0`
gap with a write watchpoint over `0790..079F` (length 16), event cap 128 and
hard timeout 600 s declared before launch. Capture exit `0`; curator exit `0`;
validator exit `0`. No runtime/Live/adapter change, no state injection, no old
fixture overwrite, no retry.

## Trace-backed evidence

- Fresh occurrence: `FC4D` cycle `0x3C592B3`, `S=07AA`, `X=8132`; queue `5C18`
  cycle `0x3C5931F`, return `59E9`; outer `FE70` cycle `0x3C59673`, `S=078D`;
  nested `FE70` cycle `0x3C5994E`, `S=0778`; `FF13` cycle `0x3C59A27`;
  `FEC9` cycle `0x3C59CEE`, `S=078D`; first `5CD0` cycle `0x3C59CF6`,
  `S=078B`, `U=0672`, return `FECC`.
- 45 events: 38 writes, 1 each `FC4D/queue/FEC9/SVC`, 2 `FE70`, 1 `FF13`.
  Event cap 128 and save cap 4 were not reached. Actual `719B=00` at every
  logged event (outside the saved 2 KB).
- Final `0790..079F`: `00 80 A6 FC 4F 06 72 71 6A 02 71 5F 91 02 5A 0A`.
  Replaying all 38 old/new events from `fc4d.bin` reproduces every one of the
  16 final bytes in `stop5cd0.bin`, including addresses with no write.

## Final writers (trace-backed)

- `0790..0798`: **6809 hardware IRQ frame push**, interrupted PC `716A`,
  cycle `0x3C5965D`, `S 0799 -> 078D`: `DP=00`, `X=80A6` (`0791/92`),
  `Y=FC4F` (`0793/94`), `U=0672` (`0795/96`), `PC=716A` (`0797/98`).
  The IRQ vector at original-ROM `FFF8` is `FE70`; outer `FE70` follows at
  `0x3C59673`. `B/A/CC` are pushed to `078F/078E/078D`, outside this watchpoint;
  event registers `B=27 A=47 CC=C0` and the unchanged stop snapshot agree.
- `0799`: **`7164 34 04 PSHS B`** (tap PC `7166`, cycle `0x3C5946A`,
  `B=02`). The final byte is `B`, not a return address.
- `079A/079B`: **`715D 8D 05 BSR $7164`** (tap PC `715F`, cycle
  `0x3C59463`); pushes return word `715F` (`079B=5F` then `079A=71`).
- `079C/079D`: **`715B 34 06 PSHS A,B`** (tap PC `715D`, cycle
  `0x3C5945C`); `B=02` -> `079D`, `A=91` -> `079C`.
- `079E/079F`: **`5A07 BD 71 59 JSR $7159`** (tap PC `5A0A`, cycle
  `0x3C59435`); pushes return word `5A0A`, so `079E=5A` unchanged and
  `079F 05 -> 0A`.
- `PSHS`, `BSR/JSR` and hardware-IRQ semantics are therefore distinct in this
  window. No indirect target or missing write was needed to explain a final
  byte.

## Watchpoint semantics note

Installed MAME 0.281 uses a pre-commit write tap; `old=b@wpaddr` is the
pre-write byte and `new=wpdata` commits after the action. For `PSHS`, tap PC is
post-operand; for `BSR/JSR`, tap PC equals the return address pushed. The printf
field labelled `st10` is `w@(s+10)`; MAME parses `10` as hexadecimal, so it is
`S+0x10`, not `S+0x0A`. The IRQ resume PC is taken from the watched frame word
`0797/0798`, not from `st10`.

## Provenance and validation

- ROM `a6ls.p1` SHA1 `402D1518BB78FDC489B06C2AABC771E5CE151847`; `m4addr.zip`
  SHA256 `E2553AFA6B8E9DEF55BD920E4BED77A4324696C1E358B73BE70BFD2C58179989`.
- MAME 0.281 SHA256 `0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A`.
- Pinned gate28 `input.lua` `7C664323...179D0D`; replay `4A051DA1...0E721D`;
  derived input `BC93C069...475957` with only the declared debugger-startup
  assertion/skip-guard patch.
- `tools/Curate-StackWriterCapture43.ps1` rechecks actual MAME/ROM/source
  hashes, the declared patch, isolated arguments, debugger allowlist, event cap,
  monotonic cycles, actual `719B`, the replay chain and all 16 final bytes.
- `tools/Test-StackWriterCapture43.ps1` passed one positive and 16 isolated
  negatives: wrong stop `S`, missing final `0799` writer, missing final `079F`
  writer, tampered `0799`/`079F` value, tampered `719B`, tampered IRQ frame,
  tampered final RAM, injected debugger command, altered input, altered
  arguments, wrong exit, wrong MAME/ROM/source, and wrong retained capture41
  fixture. Original raw/source/prior fixtures were re-hashed unchanged.
- Curated fixture: `evidence/mpu4/collection/stack-writer-0790-capture43.json`,
  107,419 bytes, SHA256 `BA44707515A202A98CBD65BBF9323A29A47BC7E4D71FA922D33E63CE4D560E3B`.

## Classification and limits

Controlled replay natural: retained recorded physical inputs, genuine MAME
devices, original reset ROM/settings/NVRAM; no RAM/CPU/device/PTM/ACK/end-state
injection; debugger breakpoints/watchpoint/reads/2 KB saves only. The fresh
occurrence is its own cycle/state. Final `0799..079D` and `079F` match the
values analysis42 read from the capture41 delta, but this is not a retroactive
capture36 traceback and does not relabel capture36. Only this single gap is
traced; the caller context producing `7164/716A`, the `5A07` path, downstream
consumers and autonomous IRQ cadence remain open.

Next safe task: recover the foreground caller/helper boundary for the
`7164/716A` sequence and the `5A07` return path, or capture the adjacent
`0770..078F` window at the same gap; do not build runtime/adapter code from
these stack bytes.

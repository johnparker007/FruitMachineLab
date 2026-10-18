# Capture36 matched service window

Capture only; no runtime, Live or fixture regression change. One fresh controlled-input
run produced the first complete `FC4D..5A1C` occurrence at its own cycle/state. The
curated fixture is separate from capture33 and oracle31; both old fixtures were verified
unchanged. The run stopped at the first `5A1C`; no later occurrence was relabelled.

## Trace-backed window

- `FC4D` cycle `0x3902DA0`, `S=07AA`, `Y=FC4D`, `X=8132`; `5A1C` cycle `0x3917B5B`,
  `S=07A4`, `X=59EB`, `Y=FC4F`, `0047=0000 0049=01A0 004D=00`.
- 217 events inside the window (event cap 512; save cap 48; neither reached):
  50 `FE70`, 50 `FF13`, 25 `FEC9`, 25 `5CD0`,
  25 `FECC`, 25 `FECE`, 6 `5D3B`, 1 `5CF3`, 1 `5E2C`, and one each of
  `5A14/5A01/5C18/5A05/5A0A/5C7A/5A10/5A1C`. No `5E29` or `5E6D` hit this window.
- Queue `5C18`: cycle `0x3902E0C`, `S=0798`, return word `59E9`.
- First service entry `sv00`: cycle `0x39036BA`, `S=078B`, return word `FECC`.
  Its matched return `fecc00`: cycle `0x3903B9A`, `S=078D`, `0044=00`, stack top
  `C01C`, IRQ resume PC `716B`. This is `S_entry+2`, with the FEC9 IRQ frame at
  `S`; it is a direct outer completion.
- All 25 captured `5CD0` entries pair with 25 `FECC` returns at `S_entry+2`.
  All 25 pairs are depth 1 (outer); **no nested `5CD0` occurred in this
  occurrence**. The capture33 `FECC/FECE` nested frames are therefore retained
  as separate capture33 anchors and are not used as an outer completion.
- Cancel `5C7A`: cycle `0x3917A18`, `S=079E`, return word `5A10`. Immediate return
  `5A10` cycle `0x3917B4C`; foreground return `5A1C` cycle `0x3917B5B`.
- `719B=00` at every logged event (outside the saved 2 KB). Full 2 KB and raw
  stack/host/channel words are retained before every `5CD0` entry and after every
  `FECC` return, plus queue, cancel and both return frames. The compact event
  window retains cycle, `S`, return word and key host fields for the remaining
  IRQ/stream events.

## Provenance

- ROM `a6ls.p1`: SHA1 `402D1518BB78FDC489B06C2AABC771E5CE151847`, 65,536 bytes;
  `m4addr.zip` SHA256 `E2553AFA6B8E9DEF55BD920E4BED77A4324696C1E358B73BE70BFD2C58179989`.
- MAME 0.281 SHA256 `0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A`.
- Pinned gate28 `input.lua` SHA256 `7C664323A5725E9FB294CB201B17B855564AF2E4A500560ED499F1EE45179D0D`;
  replay SHA256 `4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D`.
  Derived input SHA256 `BC93C0699861A2B3DE402489DD09BEA95E0438C27A1F79698430B7E68A475957`;
  only the declared debugger-startup assertion/skip-guard patch was applied.
- Capture exit `0`. Debugger SHA256 `520F8ABB261BAF22F0F646350A9839C5011D3DB5438221606143D3BC7ED3E9F9`;
  debug log SHA256 `47BC0C374226824A8FD0A70749930B33F925533739FBC26975CBB4872353729D`;
  arguments SHA256 `9973A4C95FB1C1A65F05877CDCBDA3785D91F4FED11D890F1BF55999CE863781`.
- Saved service frames: `sv-00.bin` SHA256 `C90B379DC628CE94CECB1B1344741181233B8485B9A1329E54C8824395C1C986`;
  `fecc-00.bin` SHA256 `01F0D4E7BCB16253EDE10A20EE2EC1B893429CE7969204365A49FE2B5FBE4303`.

## Validation

`tools/Curate-MatchedServiceWindowCapture36.ps1` recomputes actual MAME/ROM/source
hashes, checks the derived input differs only by the declared patch, checks the
capture arguments and isolated directories, and structurally allowlists every
debugger command: only `printf`, `save <file>,0,800`, temp assignments, `go` and
`quit`. No `load`, memory write, watchpoint, state load or device injection is
allowed. Every logged saved frame is cross-checked against its 2 KB for
`0044..0050`, `027E..0283`, `w@s..w@(s+0x10)` and `719B`; the IRQ PC at `S+0xA`
comes from the saved return frame. Pairing is LIFO by `S`: `return.s=entry.s+2`,
return word `FECC`, FEC9 wrapper at `entry.s+2`, and an IRQ-frame stack top.
No first-`FECC` flag is used.

`tools/Test-MatchedServiceWindowCapture36.ps1` passed a positive copy and 13
isolated negatives, each exit `1`: wrong matched `S` (`fecc10 S=078F`), missing
service return, anchor stack tamper (`5C18` `59E8`), tampered RAM, missing saved
return, injected debugger command, altered input, altered arguments, wrong exit,
wrong MAME hash, wrong ROM hash, wrong source pin and a wrong retained capture33
fixture. Original raw/source/fixtures were re-hashed unchanged.

## Classification and limits

Controlled replay natural: retained recorded physical inputs, genuine MAME
devices, original reset ROM/settings/NVRAM; no RAM/CPU/device/PTM/ACK/end-state
injection; debugger breakpoints/reads/2 KB saves only. Not passive play, not the
historical nudge checkpoint.

This proves the first `FC4D..5A1C` event window and 25 matched outer service
call/return pairs. It does **not** prove continuous C# execution or autonomous
IRQ cadence. No nested `5CD0` was observed in this occurrence; capture33 nested
frames remain separate. `5E29/5E6D` were not hit. No stream-command coverage
beyond this window, timer1 cadence, outer-IRQ ownership, `6B4D/58BB`, finish
budget, audio, Live ownership or hardware claim is made. The raw trace and
binaries remain ignored.

## Next task

Smallest feasible component check: seed `sv-00.bin` at `5CD0` (`S=078B`,
`U=0672`, `X=0366`, `Y=0000`, `A=05`, `B=0B`, return `FECC`), run
`AddersNativeSound.BeginService`, and compare the complete 2 KB result and
`0044/0047/0049/004B/027E` against `fecc-00.bin`. For a continuous same-state
adapter, apply the 25 captured outer pairs in cycle order plus the six `5D3B`
and one `5CF3/5E2C` events between first `FECC` and `5A0A`, using each saved
return 2 KB as the next captured state. Missing gaps: nested-service evidence
for this occurrence, `5E29/5E6D` callbacks, the exact foreground writes between
returns, and any autonomous IRQ/timer cadence.

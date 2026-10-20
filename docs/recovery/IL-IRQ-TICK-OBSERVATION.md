# Original ROM irq counter tick observation

Mechanical curation of supervisor-reviewed task 93, 20 October 2026. One
isolated fresh-boot MAME 0.281 run on the unmodified original ROM exited 0 and
the observer recorded four native `2813` -> `2815` counter-update pairs. This
document adds no run, code change or semantic claim beyond that accepted local
observation.

The raw observer repeatedly records `naturalProof=false`: it uses debugger stops
and does not prove uninterrupted natural execution, timing, frequency or VM
mapping. The separate supervisor decision accepts only a limited original-ROM
local counter-store observation. Both flags are retained below.

## Provenance

- Base revision: `bbec17ece643bf37676994383a708cfee173c5d9`.
- Accepted run: `artifacts/deepseek/il-irq-tick-observer-93/runs/prepare-positive-02/`.
- Original/source ROM: `artifacts/deepseek/il-natural-06/runs/original-01/roms/m4addr/a6ls.p1`,
  65536 bytes, SHA1 `402D1518BB78FDC489B06C2AABC771E5CE151847`, SHA256
  `EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C`.
- Isolated run ROM has the same 65536 bytes and both hashes.
- MAME `E:\Arcade\MAME0266\mame281.exe`, version 0.281, SHA256
  `0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A`.
- Observer Lua (source and isolated copy), 22686 bytes, SHA256
  `CAD0AA09532D531BEC60579305E6EB57281F4BAC6CA7325483B0B7EBC9A83B66`.
- Arguments SHA256 `D134FE837935ED862C976F8AC7227E85765CD3799B51D3D7DD8AC7D6C28D4B64`;
  launch plan `143F07D3212DA450100A7DFEC7F08392B53A05D38C96FDA80F02BEA859111876`;
  prelaunch inventory `9F72CF258ADD44D1404FF0A38AA1B2231BDB7027D0C516BA693010DA277B8435`.
- Raw events SHA256 `9E7408B61DEA47F9CD529161C7E2A649D6E04C97000F8B5F68EE11F33EC770EA`;
  raw result `6F2A36D62FA284CE525669918DB8B11EC54F5E318F2DED673F86FAA1BF664078`.
- Run `supervisor-run.json`: start `2026-10-20T15:45:47.0546106Z`, end
  `2026-10-20T15:45:49.6598824Z`, exit `0`, one launch, no retry. The observer
  result's raw `wallSeconds` is `1`; emulated cap was 2 s and wall cap 60 s.
- Child environment removed `MPU4_REPLAY` and `MPU4_POLICY`; no input provider,
  input Lua, replay, policy, save state, playback, record, input injection or
  debugger register/RAM write was used. Debugger control was limited to
  breakpoint set/clear and go.
- Prelaunch `cfg nvram inp snap comments state diff` were all empty. After the
  run only MAME persistence exists: `cfg/default.cfg` (499 bytes, SHA256
  `CE6F92D4260CFA730A9CDA509E6B19E58813B279F1D85A3408CCCB2ABB49F236`),
  `cfg/m4addr.cfg` (606, `7DE16FE1DCF8D383D1DB01C78A45352D8D3DA334F3621EED44F5D52028DC2CC8`)
  and `nvram/m4addr/nvram` (2048, `65D8979CFB74D29237BCD3AEF039790C3C6C464FBED33F07D5E690D69626C3D2`).
  The other five directories remain empty. All prepared hashes are unchanged.
- ROM guard `280F..2814` is six bytes `9E 2D 30 01 9F 2D` in the hash-checked
  source ROM and in the isolated run ROM.

## Four raw pre/post pairs

`PC` below is native PC `2813` pre-STX and `2815` post-STX. Times are exact raw
`emulatedTime` strings. Interval is the arithmetic `postTime - preTime`; it is
not a measured rate.

| # | PC pre -> post | preTime -> postTime (s) | post-pre (s) | RAM 002D..002E before -> after (BE) | X pre -> post | Y pre -> post | U pre -> post | S pre -> post | CC pre -> post | DP pre -> post |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 2813 -> 2815 | 0.328772093 -> 0.328775000 | 0.000002907 | 0000 -> 0001 (`00 00` -> `00 01`) | 0001 -> 0001 | 0E02 -> 0E02 | 0672 -> 0672 | 07B4 -> 07B4 | C0 -> C0 | 00 -> 00 |
| 2 | 2813 -> 2815 | 0.330768605 -> 0.330771512 | 0.000002907 | 0001 -> 0002 (`00 01` -> `00 02`) | 0002 -> 0002 | 0E02 -> 0E02 | 0672 -> 0672 | 07B4 -> 07B4 | C0 -> C0 | 00 -> 00 |
| 3 | 2813 -> 2815 | 0.332773837 -> 0.332776744 | 0.000002907 | 0002 -> 0003 (`00 02` -> `00 03`) | 0003 -> 0003 | 0E02 -> 0E02 | 0672 -> 0672 | 07B4 -> 07B4 | C0 -> C0 | 00 -> 00 |
| 4 | 2813 -> 2815 | 0.335298837 -> 0.335301744 | 0.000002907 | 0003 -> 0004 (`00 03` -> `00 04`) | 0004 -> 0004 | 0019 -> 0019 | 0672 -> 0672 | 07B4 -> 07B4 | C0 -> C0 | 00 -> 00 |

Raw A/B/D bytes, unchanged within each pair: pair 1 `01/00/0100`, pair 2
`02/00/0200`, pair 3 `03/00/0300`, pair 4 `00/80/0080`. Every row also carries
`romSpanHex=9E2D30019F2D` (pair_pre; the pair_post event does not repeat the span).
The result repeats the six-byte span for each accepted pair.

## Independently checked invariants

- PC is `2813` pre and `2815` post in all four pairs; DP is exposed and normalized
  `00` (raw `0`) at both boundaries. DP width is unknown.
- The counter is read as one 16-bit big-endian word at `002D..002E` (`002D` high,
  `002E` low). The raw words are `0000 -> 0001 -> 0002 -> 0003 -> 0004`.
- Pre `X = (counterBefore + 1) & FFFF`: `0001`, `0002`, `0003`, `0004`.
  Post RAM equals pre `X` in every pair, so the observed stores are `X -> 002D..002E`.
- Within each pair X, Y, U, S and DP are preserved. CC is recorded as raw `C0`
  pre and post; it is not forced by the observer and is not asserted as a
  preservation requirement.
- Between-pair preTime differences are `0.001996512`, `0.002005232` and
  `0.002525000` s. They are arithmetic differences of the raw timestamps only.
- Y is `0E02` through pair 3 and `0019` at pair 4. The change happened somewhere
  between pair 3 post and pair 4 pre. The raw events do not identify its VM or
  native source; no such cause is claimed.
- Native PC is not the VM cursor Y. `vmMapping` is `unknown`.

## Scope and unknowns

- `naturalProof=false` is retained in the raw events, raw result and curated
  JSON. Debugger stops may affect timing; uninterrupted execution, a 500 Hz rate,
  delay, a timing primitive, an observed wraparound, a general counter-writer
  claim and physical hardware behaviour are not proved.
- `X = (before + 1) & FFFF` is static 16-bit arithmetic in the observer contract;
  no wrap event occurred in these four values.
- No compiled ROM, IL change, new timing word or VM behaviour is claimed. The
  `99AD` wait/abort/stack contract remains uncertified, and 94 adds nothing to it.
- Whole-ROM runtime hash verification is `false`; identity rests on the
  preparation hashes and the live six-byte span check.
- The superseded `runs/prepare-positive-01` preparation iteration and all raw 93
  artifacts are preserved unchanged.

Private evidence and the exact machine-readable fields are in
`artifacts/deepseek/il-irq-tick-observer-93/runs/prepare-positive-02/`; compact
identities are in `evidence/mpu4/integrity/il-irq-tick-observation.json`.

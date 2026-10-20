# Natural compiled lamp-output transition

Reviewed evidence, 20 October 2026. This document and
`evidence/mpu4/integrity/il-lamp-output-natural.json` record the accepted
prepare-02 run from task 88 and the separate supervisor review in task 90.

The accepted scope is limited: one trace-backed natural fresh-boot compiled-ROM
MAME output/frame-RAM transition at the existing `9F14` caller. It is not
rendered or photographed physical lamp output, hardware validation, interactive
gameplay, new scheduler/button semantics, or M5 completion. The standalone
adapter and offline checker still correctly report `naturalProof=false`; their
false flags describe their own diagnostic scope and are not edits or
contradictions. The separate supervisor provenance review is retained in the
JSON `supervisorAcceptedProofScope` object.

## Source and run identity

| Item | Identity |
| --- | --- |
| Accepted run | `artifacts/deepseek/il-lamp-output-observer-direct-88/prepare-02/` |
| Session | `42eaa2d4-a8b1-4635-9f78-3d0c073cf32f` |
| Start / end | `2026-10-20T15:05:39.6676417Z` / `2026-10-20T15:05:46.9515447Z` |
| Exit / wall | `0` / `7.283903 s` |
| Fresh seven directories before launch | cfg 0, nvram 0, inp 0, snap 0, comments 0, state 0, diff 0 |
| Child environment before launch | `MPU4_REPLAY=prepare-02/replay-actions.csv`, `MPU4_POLICY=7` |
| Original ROM SHA256 / SHA1 | `EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C` / `402D1518BB78FDC489B06C2AABC771E5CE151847` |
| Compiled ROM SHA256 / SHA1 | `347D475E20C194F374DF85A04894BC68D89E05043CA89C5B031316868240EB88` / `F2083249845955D91945E589807C22E730D78FC3` |
| Source map SHA256 | `1845ED2A98B8347B8618D7E9A6E7AFD68B3CF14532C20268AAE273DD782E83B1` |
| Build report SHA256 | `7AB2A92DF65F77E822FD92F30D8B966E96CA3C762873201F438FFAFD2011416D` |
| Observer Lua SHA256 | `0FAEDC8B85F34DA60390C99F75C416BC870361FF790BC6AAEB5EE1133F382F8A` |
| MAME SHA256 | `0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A` |
| Replay SHA256 | `4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D` |
| Input Lua SHA256 | `23099F8888AF8DB353253E0DF97638320DC59CA9A47371723A380E0C4EE85C94` |
| Arguments template SHA256 | `93B35F3A0C15380AE981A09387D2D98FF5AD0D5CC903101C44DAD62C55D8DF23` |
| Prelaunch SHA256 | `7004286A4B88E8F83732AD2444209605565E464DF3F3128D13050960967A70A6` |
| Raw events SHA256 | `99191EDA70F615BA9E2B044E6CA4E4642743ED11F9AD66FBF5964E346E80F949` |
| Normalized stream SHA256 | `4A657C2994864C81B85DA0CC00B184994460B3B30389D7E5C03A306AEA6DA8A2` |

All 16 prelaunch-listed prepared files were rehashed after the run and match
their prelaunch values; mismatch count is 0. Generated persistence inside the
isolated run is exactly `cfg/default.cfg` (499 bytes,
`CE6F92D4260CFA730A9CDA509E6B19E58813B279F1D85A3408CCCB2ABB49F236`),
`cfg/m4addr.cfg` (606 bytes,
`7DE16FE1DCF8D383D1DB01C78A45352D8D3DA334F3621EED44F5D52028DC2CC8`) and
`nvram/m4addr/nvram` (2048 bytes,
`B70AD0886E35719530269421A9375CB4A7770F66801D855DE17DCE7F9455165E`). The
`inp`, `snap`, `comments`, `state` and `diff` directories remained empty.

The prepare-01 run is preserved as diagnostic only. Its prelaunch record has no
explicit `childEnvironment` `MPU4_REPLAY`/`MPU4_POLICY` value, so it is not the
accepted capture. No further capture was made.

## Counts

The reviewed plan has 43 phases, 56 stages and 14 boundaries. The raw run
contains 43 `phase` records, 52 original `physical_stop` records, 4
`output_physical_stop` records (56 physical stops total), 10 `boundary` records
and 4 `boundary_skipped` records (14 boundary records total). Phase indices are
contiguous `0..42`.

## Four output observations

`get` and `indexed` in the table correspond to the raw `outputValue` and
`indexedValue` fields.

| Role | PC | Y | U | S | X | B | CC | DP | Time (s) | ID | Name | get | indexed | missingID |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 00FC | 9F14 | 066E | 0798 | 0000 | 00 | C4 | 00 | 37.076457558 | 12483 | lamp120 | 1 | 1 | 0 |
| clear-return | 00FC | 9F16 | 066E | 0798 | 7931 | 80 | C0 | 00 | 37.076941860 | 12483 | lamp120 | 1 | 1 | 0 |
| write-pre | 2987 | 1462 | 0672 | 0776 | 0007 | 3E | C0 | 00 | 37.079347674 | 12483 | lamp120 | 1 | 1 | 0 |
| write-post | 298A | 1462 | 0672 | 0776 | 0007 | 3E | C0 | 00 | 37.079350581 | 12483 | lamp120 | 0 | 0 | 0 |

The write-stop register context is not the caller VM context: PC `2987`/`298A`,
Y `1462`, U `0672` and S `0776` are observed as recorded and are not asserted
equal to PC `00FC`, Y `9F14`/`9F16`, U `066E` or S `0798`.

## Frame transition

The full before/after arrays are bound by raw line 113
(`BBCC6F9AFBEB3D428ABCF62A2595B376E2B8ACE37A5CF3EF09D9690C12498EE7`). Exactly
four bytes within `0100..013F` differ:

| Address | Before | After |
| --- | --- | --- |
| 010F | 3F | 3E |
| 011F | 3F | 3E |
| 012F | 3F | 3E |
| 013F | 3F | 3E |

Non-target frame delta count is 60 unchanged bytes out of 64. This is a frame-RAM
transition, not photographed or rendered lamp output.

## Output scan

| Event | Time (s) or source | mux | frame | sample | selected |
| --- | --- | --- | --- | --- | --- |
| scan entry 1 | 37.077259302 | 5 | 0 | not recorded | not recorded |
| scan entry 2 | 37.079256977 | 6 | 0 | not recorded | not recorded |
| scan pre | not present in raw scan event | 7 | 0 | 0 | 3E |
| scan post | not present in raw scan event | 7 | 0 | 0 | 3E |

The scan entries record `inhibit=0`. The raw pre row records `x=0007` and
`b=3E`. The selected RAM value `3E` is raw; address `010F` is derived from the
observer read path `0x0108 + x(0007)`, and the raw frame-write boundary target
`010F` records the same address. Scan pre/post times are marked unknown rather
than copied from adjacent records.

## Timing derived from raw rows

Subtracting the raw `emulatedTime` strings gives:

| Interval | Seconds |
| --- | --- |
| baseline -> clear-return | 0.000484302 |
| clear-return -> stop 53 | 0.000317442 |
| stop 53 -> stop 54 | 0.001997675 |
| stop 54 -> write-pre | 0.000090697 |
| write-pre -> write-post | 0.000002907 (2.907 microseconds) |
| clear-return -> write-pre | 0.002405814 |
| clear-return -> write-post | 0.002408721 |

The first target write (write-pre) follows clear-return by `0.002405814 s`; the
write-post observation follows clear-return by `0.002408721 s`; the immediate
write pair spans `0.000002907 s`. No rounded supervisor value was copied.

## Input: request versus sampled port

From `input-levels.csv` (2281 rows) and `replay-actions.csv`: the replay request
row is `2100,2103,:AUX2,128,short_coin`. The pinned input script uses
`frame >= first and frame < last`, a half-open request interval. The sampled CSV shows override flag 1 on frames
2100-2102 and 0 on frame 2103, while sampled `:AUX2` is `00` on frame 2100 and
`80` on frames 2101-2103. Request and sampled port are distinct and are not
conflated.

The `:BLACK2` start request is `2220,2232,128,start_probe`. Sampled `:BLACK2` is
`80` for real frames 2221-2225 and for the 56 pause-time rows 2226-2281. The 56
pause rows match the 56 physical-stop timestamps and are not additional real
60 Hz frames. No last or future pulse beyond the observed rows is claimed.

All 56 physical stops independently bind to exactly one input row within one
nanosecond; the maximum absolute delta is `0.000000000 s`. The JSON contains the
full 56-row binding list.

## Proof and limitation boundary

The supervisor-reviewed limited scope is retained separately from the standalone
adapter/checker results. The adapter result SHA256 is
`6846ABA19F9B85A28623D94CCFAAF84FE9127D11B5D0647DCA792D67109F655B`; the
checker result SHA256 is
`4546042F5B6D4FA29F460F1D6210191A829427E53264846E2EF2FD2DF053F68E`. Both
remain untouched with `naturalProof=false`.

Limitations:

- The evidence includes both a frame-RAM change and a MAME output-manager
  `lamp120` change from 1 to 0; rendered or photographed lamp output remains unproved.
- Only the measured response-00, column-15, F1-zero path is naturally observed;
  future 0803 responses and non-zero F1 paths are separate.
- Debugger stops may affect timing; no unobserved-run timing equivalence is
  claimed.
- No interactive gameplay, new scheduler/button semantics, general caller
  safety, hardware compatibility or M5 completion is claimed.
- Prepare-01 is diagnostic only because its launch environment was not recorded
  explicitly.
- Scan pre/post times and the selected RAM address are marked unknown/derived as
  described above.

Private raw evidence remains under
`artifacts/deepseek/il-lamp-output-observer-direct-88/prepare-02/` and
`artifacts/deepseek/il-lamp-output-replay-direct-90/actual-adapter-02/`; compact
identities and full hashes are in
`evidence/mpu4/integrity/il-lamp-output-natural.json`.

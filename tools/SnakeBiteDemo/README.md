# Snake Bite demo launcher

One command builds the accepted 982-byte Snake Bite playable candidate from a
user-supplied original A6L 0.1 ROM and runs the known replay route to the
feature at frame 32630. The route runs unthrottled, switches to 100% throttle at
emulated time 538.0 s, shows the feature at normal speed, then exits 1.5 s after
the known return. The launcher does not read, enable or change installed MAME
plugins or machine configuration.

## Requirements

- PowerShell 5.1.
- Original ROM `a6ls.p1`, 65536 bytes, SHA256
  `EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C`
  (SHA1 `402D1518BB78FDC489B06C2AABC771E5CE151847`).
- MAME 0.281 with the `m4addr` support ROMs and a bgfx path.
- The tracked builder `tools/Build-SnakeBitePlayable.ps1` in this repository.
  The launcher walks up from its own directory to find it; use `-BuilderScript`
  if the package is placed elsewhere.

## One command

```powershell
$pkg = "./tools/SnakeBiteDemo"
& "$pkg/Run-SnakeBiteDemo.ps1" `
  -OriginalRom  "<original-a6ls.p1>" `
  -MameExecutable "<mame281.exe>" `
  -SupportRomPath "<roms-directory>" `
  -BgfxPath "<bgfx-directory>" `
  -Mode Win `
  -RunDirectory "<new-run-directory>"
```

Use `-Mode Loss` or `-Mode Control` for the other automated outcomes. Add
`-Manual -ManualSeconds 60` for the bounded physical-play handover. The run
directory must not already exist.

## Parameters

| Parameter | Default | Purpose |
|---|---|---|
| `OriginalRom` | required | Original `a6ls.p1`; identity is checked before building. |
| `MameExecutable` | local MAME 0.281 path | MAME executable. |
| `SupportRomPath` | local MAME ROM path | Support ROMs for `m4addr`. |
| `BgfxPath` | local bgfx path | MAME bgfx assets. |
| `InputLua` | bundled `input/ReplayInput.lua` | Replay provider. Manual handover requires `MPU4InputReleaseAll`. |
| `RunDirectory` | timestamped `runs/...` | Fresh output directory. |
| `Mode` | `Win` | `Win`, `Loss` or `Control`. |
| `Manual` | off | Clear launcher input overrides at feature entry. |
| `Attempts` | `1` | More than one requires an explicit `-RetryReason`; there is no automatic retry. |
| `EmulatedSeconds` | `600` | MAME `-seconds_to_run` safety cap. |
| `WallTimeoutSeconds` | `300` | Process wall-time cap. |
| `ThrottleOnTime` | `538.0` | Emulated time to switch to 100% throttle. |
| `ManualSeconds` | `60` | Bounded manual window after feature entry. |

## What is checked

- Source ROM length and SHA256 before any build.
- Rebuilt ROM SHA256 exactly
  `7124269C34881B2C8CCAA577DC2EDF28957EED3E69BC2052C5D789172D3653CF`
  and payload size exactly 982 bytes.
- The reconstructed replay reaches the known cave entry at frame 32630 and
  emulated time 543.824470930, then the original body at `D003` and return at
  `E243` with the expected U/S restoration.
- MAME exits 0 without a wall timeout.
- The throttle write reads back `true`, rate `1.0`, and the measured wall versus
  emulated window is within `0.8..1.2` (observed about `1.002`).
- Automated `Win` shows top-row `100001`; `Loss` and `Control` show bottom-row
  `111111`; the opposite flash is rejected.
- Manual mode clears all 9 owned fields once and the provider logs no
  `set_value` calls after handover.

`summary.json` and `attempt-01/analysis.json` contain the exact run evidence.
`ball-events.jsonl`, `ball-frames.csv`, `marker-*`, `input-writes.csv` and
`input-bindings.txt` are retained in the attempt directory.

## Actual input bindings

The launcher records the live MAME binding strings without changing them. In the
tested configuration:

- `Hold 1/Nudge 1` (`:BLACK2` mask `2`): `LEFT ALT` (or mouse button 3 / gun
  button 2).
- `Hold 2/Nudge 2` (`:BLACK2` mask `4`): `SPACE` (or mouse button 2).
- `1 Player Start` (`:BLACK2` mask `128`): `1`.
- `Coin 4` (`:AUX2` mask `128`): `8`.

For manual play, focus the MAME window at the feature and use the currently
configured Hold 1 / Hold 2 inputs. `MAME Tab -> Input (This Machine)` is the
supported way for a user to inspect or change bindings; this package never
changes machine input configuration. The replay provider uses read-only
binding inventory calls (`input_seq`, `default_input_seq`, `seq_name`,
`seq_to_tokens`).

## Manual handover status

The API-level handover is verified: at frame 32630 the provider calls
`clear_value()` on all 9 owned fields, records `handover=true`, and its frame
callback never writes an override again. Human physical-button play is **not**
verified; the test environment has no human input and the manual test outcome
reflects the pre-handover paddle position, not a physical proof.

If a custom `-InputLua` lacks `MPU4InputReleaseAll`, manual mode fails with that
precise blocker. The automated Win/Loss/Control path remains usable.

## Promotion boundary

Promotable package files are:

- `Run-SnakeBiteDemo.ps1`
- `lib/New-DemoRun.ps1`, `lib/Run-DemoCapture.ps1`
- `observer/SnakeBiteObserver.lua`
- `input/ReplayInput.lua`
- `fixtures/*.csv.gz` (exact accepted-route input fixtures, decompressed and
  hash-checked at run time)
- `tests/Test-DemoPackage.ps1`
- `README.md` and `result.md`

The `runs/` and `probe-*` directories are private evidence. They contain local
ROM copies and large traces and are not part of the promotable package. No
credentials or installed-tool contents are included.

## Limits

- MAME still reports the expected modified-ROM checksum warning; it is kept
  visible and not suppressed.
- All results are emulator observations, not physical hardware validation.
- The custom game branches into the original Snake Bite body `D003`; it does not
  replace the later feature outcome or accounting.
- One brick and no score/lives/Alpha/sound additions.
- The countdown dwell is VM execution timing, not a certified IRQ/service timing
  contract.
- Manual physical controls are API-handover-verified only.

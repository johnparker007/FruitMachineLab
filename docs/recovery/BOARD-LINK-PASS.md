# Natural ladder and snake execution

15 October 2026. Recovered DBC4 nonzero-link dispatch, DAC7 ladder and DB58 snake
animations now execute in the headless runtime and Live diagnostics. The entry
selector adds Ladder and Snake animation modes, each from a naturally captured
DBC4 entry. Start feature runs the animation; Pause/Resume suspend actual VM,
machine memory and virtual time. Restart restores entry. No additional player
input is required within these two paths. Existing Skill Cash and playback remain.

These are recovered link entries, not complete-machine startup modes. Live stops
at DE81 before the following board result. Normal square-32 roll/advance also no
longer rejects DAC7/DB58 merely because a link was reached; current roll timing
variations land on zero-link squares. Whole-board chaining remains future work.

## Trace-backed reference

Fresh isolated MAME physical-input campaigns reached DBC4 with a nonzero link.
There is no RAM/register redirection or outcome injection. The earlier physical
input fixture and paused-setup callback compensation are retained. Each path ends
at DE81 after DBC4 returns through restored physical VM frames.

| Natural path | VM observations | Lamp requests/frame results | Sound commands | Alpha bytes | Destination | Nudge pot |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Ladder | 571 | 57 | 337 | 47 | 22 | 1 to 3 |
| Snake | 22,887 | 61 | 265 | 0 | 7 | 8 to 1 |

Ladder starts at square 2; snake at 41. All 27 canonical VM fields match, including
stack/frame state, square, pot, seed, timers, latch and accounting. Lamp frame
hashes, sound command/timing hashes and alpha serial bytes match exactly under
the reference adapter. Neither path needs uninitialized-local exclusions or
lifted dispatches. Pending/current-win remain zero. Ladder returns Forth false;
snake returns Forth true. Those are observed cells, not UI decisions.

Curated fixtures retain low-RAM entry snapshots, sparse IRQ/input/native phases,
anchors, pacing observations, canonical/raw hashes and debugger commands. Sidecars
identify raw local runs, raw/RAM hashes, MAME binary hash, input-fixture hash and
capture flags. Bulky logs, NVRAM and full ROMs remain outside Git. Failed initial
capture predicates were corrected; those failed runs are not fixture sources.

## Implementation and static deductions

Original VM bodies execute destination setting, pot changes and lamp ordering.
Selected ROM ranges supply link paths, indexed lamp records, inline alpha and
sound streams. No destination/pot lookup substitutes for execution. Eight new
indexed-lamp parameter words are admitted only at validated ROM 9B15 gateways,
executing the existing recovered 9B18 body.

Both snapshots already contain active sound tasks. Generic restoration still
accepts fresh queues by default. The Adders adapter additionally recognizes only
the observed 9714/971F streams at 971A/5E1F or 971C/5E29, with zero gate and either
no frame or one validated 972B call return. Call instruction, child terminator,
native stack pointer and return word are checked. Unknown callbacks, altered
frames and ROM shapes are rejected. Runtime restoration uses typed call frames,
validates native bytes and is atomic if a later list item fails. Untyped sound
stacks and native allocator addresses are not inferred.

Snake audio uses CB relative attenuation. Static disassembly at 5F92..5FDB shows
a consumed operand, clamped/default low-nibble volume update and register-cache/
channel writes, returning to command fetch. The timing/choice scheduler consumes
this command under its existing exclusion of YM2413 synthesis and register-cache/
channel effects, like CA absolute attenuation. This does not claim faithful audio.
The selected native disassembly and source hash are retained in
evidence/mpu4/native/sound-relative-attenuation*.

## Live execution and timing limits

Live uses captured initial state, selected ROM data and explicit pacing/IRQ
adapters. It never applies recorded player events, subsequent board states, lamp
requests or alpha outputs. Both animations execute incrementally. Ordered logical
lamp requests and final alpha shadow, destination, pot and accounting match the
verified references. Pause preserves full memory, instruction count and virtual
time; Resume continues and Restart is clean.

Deterministic Live runs take about 2.139 s (ladder) and 2.219 s (snake), against
2.151 s and 2.236 s in MAME. Live ladder executes 570 instructions before terminal
DE81; the reference has 571 observations including that terminal. Live snake
executes 21,881 instructions before terminal versus 22,887 reference observations:
polling iteration counts differ under provisional CPU/IRQ timing. Full CPU/scan
equivalence is not claimed. Logical output matches do not establish transient
lamp duty or complete Live sound-timing equivalence. Strict reference checks remain
independent. The earlier roll's one-byte alpha brightness difference is unchanged.

## Verification and reproduction

110 headless groups pass, including full natural link references, Live output
comparisons, pause/resume, accounting and changed-frame/callback rejection.
Headless and isolated WPF builds pass. Five WPF smoke modes pass: Live Skill Cash,
jackpot, dice/board movement, links and playback. Link smoke checks real-time
rendering, pause/resume and restart for both entries. The ladder rendering was
inspected, including UP THE LADDER.

```powershell
dotnet build FruitMachineLab.Headless.sln --no-restore
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .
dotnet build src/FruitMachineLab.Diagnostics/FruitMachineLab.Diagnostics.csproj --no-restore -o <fresh-output>
<fresh-output>/FruitMachineLab.Diagnostics.exe --live-link-smoke-test <fresh-artifact-directory>
```

Capture each link in its own fresh directory:

```powershell
./tools/Capture-SkillCash.ps1 -MameExecutable <mame281.exe> -RomDirectory <rom-directory> -RunDirectory <fresh-run> -FullFeature -NativeSound -NativeInput -NativeLampFrames -NativeAlpha -CpuInterrupts -BoardLink Ladder
./tools/Curate-BoardLink.ps1 -RunDirectory <fresh-run> -LinkKind ladder
./tools/Curate-BoardLinkData.ps1 -RomPath <a6ls.p1>
```

Use Snake/snake for the second path. Curator requires DBC4 to DE81 completion;
ROM-data curator checks the established SHA1. Native attenuation disassembly is
reproducible with `dasm native-sound.asm,0x5d3b,0x400`, selecting 5F92..5FDB.
Dispatch table 5963 + 2*CB points to 5F92.

Next: recover/reference-check the board-result/next-selection continuation after
an advance or link, retaining state and checking each feature route. Startup and
persistent whole-game play remain open. No installations, configuration changes,
commits, pushes or cloud setup were made.

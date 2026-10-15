# Current handoff

Updated 15 October 2026. Read PROJECT-ROADMAP.md for agreed direction and AGENTS.md
for permissions and preservation rules. This checkpoint records the last development
batch, including its verification.

## Working implementation

- C# headless runtime/Adders projects and separate WPF diagnostics app.
- Live Skill Cash: incremental VM, retained state, physical momentary Start input,
  actual Pause/Resume, generated lamp/alpha outputs and diagnostic state display.
- Separate verified playback/scrubber; original MAME-backed verification retained.
- Last development batch: 106 headless groups passed. Headless and isolated WPF
  builds passed; Live/playback WPF smoke checks and rendered layouts were checked.
- John subsequently reported that the live feature works well.

See recovery/SKILL-CASH-LIVE-PASS.md for implementation details and exact boundaries.
Live uses provisional captured CPU pacing and repeated IRQ service boundaries.
Reference-time Start presses match 18 VM/frame/accounting checkpoints, 44 alpha
states and final lamp frame memory, but not full CPU state or transient scan timing:
147,310 live dispatches/12.317 s versus 98,704 reference dispatches/12.209 s.
The jackpot announcement now runs live, and all six default award levels complete.
See recovery/SKILL-CASH-EXTENSION-PASS.md for the synthetic helper proof, captured
IRQ occupancy adapter and exact limitations.

Live now defaults to DD38 at board square 32. TAKE FEATURE is physical BLACK2 bit
01; START remains bit 80. Take enters Skill Cash and returns through the restored
DDAF/DE75/E43D frames to E460. The entry selector retains C721 and E2FC modes.
All six default award levels complete through all three modes. START at the board
prompt now runs one incremental dice roll with ROLLING, changing face/position,
native busy-loop completion and symbol refresh. Pause/Resume also suspend the motor.
It now continues through one incremental board advance and zero-link dispatch,
stopping before the next DE96 result return or DD38 selection; Restart is available.
Nonzero links stop before ladder/snake animation. Requested symbol/offset stay
separate from the changing position and displayed face. Board square, nudge pot,
raw ROM type/link and visited squares are visible.
The natural selection reference checks 99,843 exposed VM observations (with explicit
uninitialized-local masks), 7,331 lamp requests, 6,099 sound commands, 1,107 alpha
bytes and 868 input-condition reads. Its full original C721 source digest remains
unchanged. See recovery/BOARD-SELECTION-TAKE-PASS.md for exact qualifications.

The retained natural square-7 request reference checks 485 VM observations, 15 lamp
requests/frame results, 16 sound commands, 50 alpha bytes and five input conditions.
Its 478-dispatch body independently matches a narrower capture. Eight live timing
variations at square 32 request symbols 2,4,6; those tests now also require completed
motor motion and matching refreshed symbols.
See recovery/DICE-REQUEST-PASS.md for native profile, symbol and alpha-loop recovery,
static entry-cost equivalences and the distinction between the two board contexts.

The latest motor reference checks 875 native observations, 386 services including
cleanup and 96 optic/update operations; independent MAME runs agree on the core
states. A driven Barcrest model independently generates the captured optic bits.
Device saved-item observations validate the opposite motor/ROM coordinate directions
and feature-entry phase seeds. The combined path matches 7,103 VM observations,
15 lamp requests and 167 sound commands. Alpha has one documented FF brightness
restoration difference (83/84 bytes); text/cursor/reset agree. It is not an exact
alpha-timing match. See recovery/DICE-MOTION-PASS.md and THIRD-PARTY-NOTICES.md.

The new natural movement reference checks 12,355 VM observations, including board
and pot, 11 lamp requests and 60 sound commands, from square 7 to 11 with pot 4.
A separate explicitly synthetic DDE3 helper probe checks 9,565 lifted observations
and 36 sound commands (9,613 raw observations; 48 typed-list inner observations
excluded). It is not a natural nudge-animation path. Live timing variations run
32→34/36/38, with per-square lamp steps and pot logic executed by the actual VM.
See recovery/BOARD-MOVEMENT-PASS.md for arithmetic, IRQ-byte read phases, synthetic
scope and preserved earlier timing qualifications.

## Next development work

Capture nonzero-link DBC4 paths and translate/verify ladder/snake animation,
destination setting and pot adjustments. DDF3 movement and zero-link DBC4 dispatch
now execute and are reference-checked. Continue the following board result or
selection after that; the current live scope deliberately stops after one advance.
Normal dice motor preparation, service, generated optics, completion and symbol refresh now run;
homing, motor-disabled shortcuts and complete alarm handling remain outside this
feature-entry milestone. The earlier ladder, startup, credits and whole-game play
remain open. Resolve the new alpha brightness timing discrepancy with native/IRQ
phase evidence, preserving strict earlier alpha comparisons.
Improve timing and remaining Skill Cash option coverage. Prioritize playable coverage,
not script editing. Bring layout integration into normal-play development using
John's existing importer/renderers when their locations and assets are available.
Work not dependent on those references can proceed independently.

## Practical checks

```powershell
dotnet build FruitMachineLab.Headless.sln --no-restore
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .
dotnet build FruitMachineLab.sln --no-restore
```

An open diagnostics app can lock normal WPF output. Do not stop John's process;
build the diagnostic project to a fresh temporary output folder when necessary.
Smoke switches are documented in the Live/playback recovery reports.

The default Live/jackpot smoke exercises physical Take before Start, plus Take
capture/focus release. The jackpot driver remains accelerated. Replay uses captured
input-port/native scheduling phases; Live never substitutes recorded player events.
Raw boundary capture and temporary diagnostic comparison files remain outside Git.
--live-roll-smoke-test <fresh-output-directory> checks real-time physical Start,
changing position/face, actual mid-motion and mid-board pause/resume, completed
roll/advance, next-dispatch boundary, released controls and clean restart.

No agent commit, push, installation, configuration change or cloud setup was
performed. Inspect git status before the next batch; do not infer commit state
from this checkpoint. The original analysis workspace remains preserved separately.

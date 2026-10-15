# Current handoff

Updated 15 October 2026. Read PROJECT-ROADMAP.md for agreed direction and AGENTS.md
for permissions and preservation rules. This checkpoint records the last development
batch, including its verification.

## Working implementation

- C# headless runtime/Adders projects and separate WPF diagnostics app.
- Live Skill Cash: incremental VM, retained state, physical momentary Start input,
  actual Pause/Resume, generated lamp/alpha outputs and diagnostic state display.
- Separate verified playback/scrubber; original MAME-backed verification retained.
- Last development batch: 81 headless groups passed. Headless and isolated WPF
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

Live now defaults to the captured E2FC board-result boundary (type 2, position 32),
executes the take flag/type dispatch and DFF6 announcement, runs C721, and returns
through the real dispatcher frames to E33C. The checkbox can retain C721-only entry.
Two natural MAME captures reproduce the original feature digest; 100/124 prelude
dispatches, announcement sound/alpha and lamp frames are checked separately.
All six default award levels complete through both entry modes. See
recovery/SKILL-CASH-BOARD-ENTRY-PASS.md for fixture and scheduling qualifications.

## Next development work

Continue outward into E43D/DE75 board movement, destination changes, take/continue
inputs and retained entry/exit state. E2FC..E33C is implemented for the selected
cash-feature route, but startup, credits, reels and whole-game play remain open.
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

No agent commit, push, installation, configuration change or cloud setup was
performed. Inspect git status before the next batch; do not infer commit state
from this checkpoint. The original analysis workspace remains preserved separately.

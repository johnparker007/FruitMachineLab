# Local and cloud development

Repository: https://github.com/johnparker007/FruitMachineLab
Local clone: C:\projects\GitRepos\FruitMachineLab

## Current status

Latest batch: one completed main-reel nudge, count consumption and a proportional
ROM-reconstruction preservation audit/checkpoint. See recovery/NUDGE-MOTION-PASS.md.
127 headless groups and eight GUI smoke modes pass; --live-nudge-smoke-test checks
all three controls, actual motor pause/resume and the new B339 residue boundary.
No installation or configuration
change, commit/push or cloud setup was performed.

For current priorities and continuation context, read [PROJECT-ROADMAP.md](PROJECT-ROADMAP.md)
and [CURRENT-HANDOFF.md](CURRENT-HANDOFF.md). The dated sections below retain the
history of setup and implementation batches.

The local clone points to the expected GitHub remote. Installed .NET SDKs observed on
2026-10-14: 5.0.404, 7.0.304, 8.0.407 and 9.0.313. The initial solution uses installed SDK 9.0.313 and net8.0 targeting packs. No SDK was installed or pinned. FruitMachineLab.sln includes WPF; FruitMachineLab.Headless.sln builds independently.

Shared instructions are in AGENTS.md. No app project registration, cloud environment,
GitHub authorization, commit, or push has been performed by this setup pass.

## Local project

Add the existing clone as a local project in the desktop app's Codex view, with this folder
as the primary project directory. Start a local task there. This makes repository Git tools
and automatic project-instruction discovery target FruitMachineLab.

The original analysis workspace remains separate. Bring across curated reports, semantic
maps, reproducible tooling and selected fixtures; preserve the original forensic workspace.

## Cloud environment

Create an environment through Work in > Cloud > Select environment > Create environment,
or Settings > Codex Cloud > Environments. Select johnparker007/FruitMachineLab and complete
GitHub authorization if requested. Review the proposed dependencies before approving setup
or publishing the environment.

First establish the headless solution and documented build/test commands locally, then use
those commands to prepare and verify the cloud environment. Windows UI and local hardware
tools need separate validation on Windows; do not treat headless cloud tests as UI validation.

Cloud tasks have isolated working files. Local changes become available through reviewed
commits and pushes, not automatic folder synchronization. Local ROMs, MAME, Ghidra and
loopback MCP services are not automatically available to cloud tasks.

Use separate branches for concurrent work and integrate through review. Preserve a reference
behaviour baseline separate from experiments that change game rules.

Official guidance:
- https://learn.chatgpt.com/docs/projects
- https://learn.chatgpt.com/docs/environments/modes
- https://learn.chatgpt.com/docs/environments/cloud-environments

## First implementation milestone

Create the C# headless runtime and a simple Windows diagnostic UI, then execute Skill Cash
against a selected recorded path. Record the exact SDK and build/test commands. Do not
publish ROM binaries or assume apparent ROM padding is usable space.

## Initial C# batch — 14 October 2026

The repository now contains curated recovery reports, semantic maps, decoded scripts,
a selected Skill Cash trace with independently checked a/b hashes, and headless/WPF
projects. See ../README.md for exact build/run commands and ../IMPLEMENTATION-STATUS.md
for evidence boundaries. Eight dependency-free verification groups cover cell semantics,
initialization, normalization, intermediate replay stacks, fail-fast unsupported helpers,
corrupted-fixture rejection and recorded dispatch tokens.

Skill Cash is currently a bounded mechanics replay, not complete standalone feature
execution. Selection/timing/random gates, NVRAM and win animation remain untranslated.
No installation, system configuration, commit, push or cloud setup was performed.

## Selection/scheduler follow-up

Both solutions build with the existing SDK. Verification now has 29 groups,
including complete C699 replay. See recovery/SKILL-CASH-SELECTION-SCHEDULER-PASS.md
for current boundaries; the initial-batch paragraph above is historical.

## Continuous feature follow-up

The current WPF viewer runs continuous C721 verification, including native sound
timing and lamp frame memory checks. Thirty-nine headless verification groups pass;
no manual GUI check is required between runtime batches. Physical peripheral effects
and interactive platform timing remain open. See
recovery/SKILL-CASH-CONTINUOUS-FEATURE-PASS.md for exact evidence boundaries.

## Alpha/output follow-up

The viewer now includes alpha shadow and IRQ latch timelines. Forty-seven headless
verification groups pass with the existing SDK. See
recovery/SKILL-CASH-ALPHA-OUTPUT-PASS.md for the distinction between verified software
effects and unresolved electrical/platform timing. No new dependencies were added.

## Shared timing follow-up

Fifty-three headless verification groups pass. The IRQ view now includes timer
callback masking after scans, driven by captured CPU-cycle offsets. See
recovery/SKILL-CASH-SHARED-TIMING-PASS.md for the shared-memory proof and remaining
elapsed timer/CPU scheduling work. Existing build/run commands remain unchanged.

## Timer deadline follow-up

Fifty-seven verification groups pass. Actual timer latch writes and IRQ entry now
have an independent capture, checked against the shared callback timeline. See
recovery/SKILL-CASH-TIMER-DEADLINE-PASS.md for the bounded countdown calculation and
unresolved CPU acceptance latency. Build/run commands and dependencies are unchanged.

## Visual playback follow-up

The diagnostics app now opens on a playback tab. Load & play Skill Cash verifies
and plays the 12.209-second recorded path at 1×, with lamps, alpha and transport
controls. 61 headless groups and an opt-in WPF smoke/render check pass. See
recovery/SKILL-CASH-PLAYBACK-PASS.md for renderer boundaries and smoke instructions.

## Live Skill Cash follow-up

Live mode now incrementally executes one feature with a momentary physical Start
control. Pause/Resume suspend the VM and virtual clock. Playback remains separate.
The initial pass had 67 headless groups and Live/playback WPF smoke checks. WPF was built in isolated
temporary output because an existing app locked normal build DLLs. See
recovery/SKILL-CASH-LIVE-PASS.md for exact comparisons and unresolved CPU/IRQ pacing.

The subsequent recovery/SKILL-CASH-EXTENSION-PASS.md documents 77 passing groups,
all six default live award levels, jackpot announcement support and captured IRQ
occupancy pacing. Build commands and dependencies are unchanged. The optional
--live-jackpot-smoke-test <fresh-output-directory> is an accelerated physical-input
and render check, separate from the real-time Live smoke mode.

## Board entry follow-up

81 groups now pass. Live defaults to the recovered E2FC board-result entry for
type 2/position 32, including take gating, announcement, cash-feature table dispatch
and the return to E33C. The checkbox retains the earlier C721-only diagnostic entry.
See recovery/SKILL-CASH-BOARD-ENTRY-PASS.md. Build/smoke commands are unchanged.

## Board selection follow-up

87 groups pass. Live defaults to DD38 on square 32: press TAKE FEATURE, release it,
then use START for Skill Cash. The entry selector also retains C721 and E2FC modes.
START on the board reaches an explicit dice-motion boundary; Restart recovers from
that stop. See recovery/BOARD-SELECTION-TAKE-PASS.md for natural reference evidence,
physical-input mapping and comparison exclusions. Build/smoke commands are unchanged.

## Dice request follow-up

92 groups pass. START at the default board prompt now calculates a native dice
request and renders ROLLING, stopping before 61F6 physical motion. The Take route
and playback remain intact. --live-roll-smoke-test <fresh-output-directory> adds
a real-time Start/request/boundary/restart UI check. See recovery/DICE-REQUEST-PASS.md
for natural capture comparisons and static edge tests. No dependencies changed.

## Dice motion follow-up

99 groups pass. START at the board prompt now runs one incremental motor roll,
with generated optic feedback, changing text face and real motor/VM Pause/Resume.
It stops before B28F returns to board movement. The existing roll smoke switch now
checks motion, pause/resume and completion. See recovery/DICE-MOTION-PASS.md for the
7,103-dispatch comparison and explicit 83/84-byte alpha brightness qualification.
No tools or dependencies were installed; the small MAME-derived motor model carries
BSD-3-Clause attribution in THIRD-PARTY-NOTICES.md. Build commands are unchanged.

## Board movement follow-up

106 groups pass. Live START now continues the roll into one incremental board
advance, with square/pot/history diagnostics and actual mid-movement Pause/Resume.
It stops at the following result/selection, or before a ladder/snake animation.
The roll smoke switch covers both motor and board pauses. See
recovery/BOARD-MOVEMENT-PASS.md for the natural 12,355-dispatch proof, separately
classified synthetic nudge probe, arithmetic edges and unresolved timing. Build
commands and dependencies are unchanged. No installation or system setup occurred.

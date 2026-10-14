# FruitMachineLab

Experimental recovery and PC execution of fruit-machine game logic. First target:
Barcrest MPU4 Classic Adders & Ladders, MAME set m4addr, A6L 0.1 set 1.
Later targets may include other MPU4 games and other platforms.

## Working rules

- Require John's approval before installations or configuration changes.
- Do not commit, push, publish, or change repository access unless requested.
- Preserve existing ROMs, MAME settings, Ghidra projects, and unrelated MCP configuration.
- Distinguish trace-backed findings, static deductions, hypotheses, and synthetic fault experiments.
- Recovered pseudocode is not original source. A name does not establish complete behaviour.
- Keep ROM binaries, local credentials, installed tools, and bulky traces outside tracked files.
- Never silently invent missing helper semantics or fix suspected ROM bugs in the reference behaviour.

## Intended implementation

C# headless deterministic engine, recovered threaded-VM runtime and translated native helpers,
with a separate Windows diagnostic UI. First executable milestone: Skill Cash with a verified
replay. MAME is an external behavioural reference. The eventual DX renderer should consume
the same output interface as the diagnostic UI.

Preserve 16-bit wraparound, signed arithmetic, Forth true FFFF/false 0000, VM stack/frame
semantics, controlled timing and reproducible randomness. Keep platform-specific behaviour
separate from individual games; generalize after demonstrated reuse.

No build or test commands exist yet. Establish and document them when the solution is created.
Keep the headless projects independently buildable/testable from the Windows UI.

## Existing evidence

The original local analysis workspace is:
`C:\Users\John\Documents\Codex\2026-10-13\help-me-set-up-a-local`.
Its reports are under `outputs\mpu4`; latest prerequisite evidence is under
`outputs\mpu4\evidence\prerequisite-pass`.
This path is local context, not a cloud dependency. Curated evidence must be brought into
the repository before cloud tasks can rely on it.

ROM a6ls.p1: 65536 bytes; SHA1 402d1518bb78fdc489b06c2aabc771e5ce151847;
CRC 9f97f57b. Latest completed analysis reports 485 named native functions and 528 VM bodies,
of which 378 have purpose labels and 150 remain unresolved. These are a handoff baseline,
not claims of complete recovery.

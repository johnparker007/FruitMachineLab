LATEST PREREQUISITE/FAULT PASS: PREREQUISITE-AND-FAULT-RECOVERY.txt;378/528 purpose-labelled VM bodies,150 unresolved;485 named native functions. Six eligible payout-router arms and all four channels accounted for;13 exact replay pairs. Meter return corruption is a synthetic fault-path candidate, not confirmed natural bug. Batch finished;analysis stopped at user request. Older reports below are historical.

LATEST PAYOUT/SERVICE PASS: PAYOUT-AND-SERVICE-RECOVERY.txt;485 named native functions;373/528 purpose-labelled VM bodies,155 unresolved;476 partly observed. Four collection routes and full native output chain verified;late service tests7-9 and Refill output test reached;nine exact replay pairs. Older counts below are historical.

LATEST LIFECYCLE PASS: LIFECYCLE-RECOVERY.txt;360/528 purpose-labelled VM bodies,168 unresolved;467 partly observed.31 counter-factor profiles and10-byte board-animation frame recovered;three exact2400s replay pairs. Collection router remains runtime-unverified. Older reports/counts below are historical.

LATEST VM BATCH: VM-BATCH-RECOVERY.txt; 126 additional purpose labels, 336/528 named script bodies, 466 partly observed bodies. All nine cash-feature entrypoints reached; service tests1-5 entered and replayed. Saved native functions: 482. CASH-FEATURE-FLOWS.txt and SERVICE-AND-ATTRACT-RECOVERY.txt describe the new results. Older reports/counts below are historical.

LATEST EXTENDED PASS: EXTENDED-RECOVERY.txt;477 named native functions (18 hypotheses),526 script bodies,210 purpose names,411 partly observed bodies;13 exact replay pairs. BOARD-MAP.txt and NATIVE-ENTRY-RECOVERY.txt document new data and code recovery. Older counts below are historical.

LATEST SPECIAL PASS: SPECIAL-FEATURE-RECOVERY.txt; inline table addressing corrected,9 further helper names, repeated continuation fixture verified. Earlier reports are historical.

LATEST FEATURE PASS: FEATURE-CHOICE-EXPERIMENTS.txt;469 indexed scripts,164 reviewed names,355 partly observed bodies. Five controlled feature fixtures replay exactly; computed-call roots and typed feature dispatch table repaired. Older report counts are historical.

LATEST EXPLORATION: STATE-AWARE-EXPLORATION.txt; 440 scripts,145 reviewed names,336 observed bodies; three180s discovery/replay pairs match exactly. Earlier reports describe historical passes.

LATEST SCRIPT PASS (14 October): SCRIPT-CLASSIFICATION.txt; all430 script bodies indexed,122 purpose names and142 parameterized word names. Reproducible nudge and award paths: NUDGE-AND-AWARD-PATHS.txt. Earlier report counts are historical.

LATEST ANALYSIS: LOGIC-RECOVERY.txt and GAME-PATHS.txt; 438 saved functions, 387 names; typed VM scripts in VM-SCRIPTS. Earlier DEEP-ANALYSIS/NATIVE-CODE-SWEEP counts are historical.

MPU4 ROM analysis workspace â€” 13 October 2026

UPDATE: The deeper pass is saved and reopened. See DEEP-ANALYSIS.txt and
FUNCTION-INDEX.txt for the expanded initialization/IRQ/interpreter recovery,
232 descriptive function names, lamp/input mappings and new repeated traces.
The initial two-routine acceptance notes below describe the original setup.

Installed and verified
Ghidra 12.1.4 (20260921) and GhidraMCP 2.0, official release SHA-256
digests verified. Existing Oracle JDK 23.0.1 works; no additional JDK installed.
Python 3.10.5 virtual environment contains ghidra-mcp 2.0.0. Exact installed
dependencies are in evidence/requirements.lock.txt. Python 3.14 is used only
for lightweight evidence comparisons. No system Python packages replaced.

Portable installations and Ghidra settings/cache/temp are in ../../work.
The project's .codex/config.toml supplies Ghidra stdio MCP. A single trusted
project entry was added to the user config; existing node_repl and Blender
entries were preserved. The prior config backup is in work (not deliverables).
Codex CLI lists ghidra, node_repl, and blender as enabled. A new chat/session
may be needed for Codex to load newly added tools. The connection was tested
independently using actual MCP initialization, tool listing, reads, and writes.

Open the project
Run scripts/Open-Ghidra.ps1 from PowerShell. It uses the standard Ghidra
launcher plus the bundled MPU4GuiLauncher.jar, opens project/MPU4.gpr and
a6ls.p1 in CodeBrowser, and enables the original GhidraMCP plugin. The helper
source is supplied. Avoid launching a second copy while the project is open.
The backend binds to loopback port 8080; the Python bridge uses stdio.
Ghidra must remain open with the program active. Ctrl+S saves program edits;
GhidraMCP 2.0 has no save-program tool. Both recovered routine annotations
were saved in the GUI, and the startup annotation survived closing/reopening.
The helper saves the tool configuration, not automatic program changes.

ROM mapping
ROM copy: rom/a6ls.p1, 65536 bytes; CRC 9f97f57b;
SHA1 402d1518bb78fdc489b06c2aabc771e5ce151847.
Language 6809:BE:16:default; default compiler spec; 16-bit address space.
Runtime ROM bank 0: 1000-FFFF from matching offsets in the original file.
0000-07FF: uninitialized NVRAM; volatile uninitialized device blocks follow
the pinned MAME 0.281 driver. Original file bytes below 1000 are not mapped
as runtime ROM. Unmapped holes are intentionally left unmapped.
Main device ranges: characteriser 0800-0810, bank select 0850, DUART 08E0-08EF,
PTM6840 0900-0907, PIAs 0A00-0A03 through 0F00-0F03.
Vectors: SWI3 FFF2->FE66; SWI2 FFF4->FE66; FIRQ FFF6->FE56;
IRQ FFF8->FE70; SWI FFFA->3620; NMI FFFC->FE51; RESET FFFE->7CCF.
FFF0 is reserved, not a CPU reset/interrupt entry.
This is a bank-0 model. Any future bank changes require runtime evidence
and separate mapping; do not invent ROM bytes outside this 64 KiB file.
The set uses MAME's cheatchr_pal characteriser implementation. Good-emulation
status does not establish exact physical protection-device behavior.

Run reproducible experiments
Use scripts/Run-Trace.ps1 -RunName my-unique-run -Experiment ram-test
or -Experiment scheduler (boot is also available).
It reuses E:\Arcade\MAME0266\mame281.exe and the existing ROM directory.
Each run starts with absent NVRAM and configuration files in a fresh directory.
No existing MAME configuration is read. Effective settings, exact arguments,
debugger commands, console/debug output, NVRAM snapshots, and file hashes
are saved under runs/<name>. Exit occurs at the intended breakpoint; the
two-second emulation limit is a fallback, so confirm the breakpoint log.
These tests use no human/game inputs. Their reproducibility is a fresh cold
boot comparison, not INP playback. Device-enumeration messages do not affect
the recorded CPU sequence; physical controllers were not part of these tests.
MAME Windows debugger is required: debugger=none did not run debugscript.
The debugger count "200" is hexadecimal (512), not decimal 200.

Compare with scripts/Compare-Runs.py <run-dir-a> <run-dir-b>.
Evidence includes actual MCP responses, exact traces, driver sources, release
metadata, dependency lock, and executable/ROM/tool SHA-256 values.
Check hashes before relying on an old result after any tool/ROM change.

Recovered routine 1: 6C75 startup_test_ram_preserve_pattern
Evidence-backed name. Tests NVRAM 0000-07FF with pattern in accumulator A.
For each byte: save it in B, write A, compare readback, restore B, increment X.
The success path clears carry; failure restores the current byte and sets
carry. Caller 6C47 tests patterns 00,55,AA,FF and handles failure via SWI.
The recorded first-pattern success path has 16,387 trace records in both
ram-verified-a/b, identical byte for byte. RAM before/after is identical.
Final state at caller 6C4B: A=00, X=0800, S=07C4, CC=54 (carry clear).
No RAM-failure injection was performed; the failure path is assembly-backed,
not experimentally observed. Ghidra's void pseudocode omits carry semantics.

Recovered routine 2: 5CD0 hyp_tick_event_dispatch
IRQ vector FE70 calls it at FEC9; return is FECC. Name is a hypothesis.
Evidence-backed empty-list path, DP=00:
  if byte[0044] != 0: return
  byte[0044] = 1
  byte[002C] = 0
  word_be[0045:0046] += 1  (16-bit wraparound)
  head = word_be[0047:0048]
  if head == 0: byte[0044] = 0; return
Static assembly suggests nonempty records contain a next pointer, due tick,
and callback; that path has not been exercised. Do not interpret the counter
as a particular time unit, infer tick frequency, or assign gameplay meaning
without tracing. Indirect jump and stack warnings in decompilation need
assembly checks. The pseudocode above is a recovery aid, not original source.
In scheduler-a/b, traces match byte for byte. Guard 0044 changes 0->1->0,
counter 0045:0046 changes 0000->0001, head remains 0000, return is FECC.
Before/after NVRAM differs at 002C (cleared IRQ-work flag) and 0046 (counter).
The trace begins at 5CD2 because the
entry breakpoint precedes activating tracing; entry TST at 5CD0 is supported
by the saved disassembly, not that instruction trace. Callback execution,
nonempty list, counter overflow, and reentrant branch remain untested.

Acceptance
Passed: MCP GUI read/decompile/rename/comment, MAME routine traces, repeated
cold runs with identical selected state transitions. Automatic launcher
reopened CodeBrowser and its loopback backend without manual configuration.
This establishes the workflow; it does not establish a gameplay bug or a
complete recovery of the game's rules, payouts, inputs, or state machine.

Bug-analysis procedure
Keep original ROM and baseline evidence immutable. Create a new experiment
directory for every variant. Define a concrete expected transition and the
observed mismatch before naming a bug. Record MAME version/hash, ROM hash,
configuration/DIP values, NVRAM before launch, debugger interventions, and
each input's emulated timing. For INP tests, record and replay with the same
build and initial NVRAM/configuration, then compare checkpoints; recordings
can desynchronise. This set has unsupported save states: do not use them.
Localize the first divergence using PC/register/RAM/device traces. Preserve
the assembly and the trace supporting each conclusion. Compare clean runs,
alternative emulator versions in separate directories, and hardware evidence
where available. Treat protection shortcuts and device/timing differences
as emulator candidates. Do not attribute a fault to ROM logic from an emulator
trace alone. Classify findings as observed, inferred, or unresolved.
For new game logic, follow the scheduler's callback pointer and input handlers
under a documented input sequence; add names only when supported by evidence.

AI-assisted analysis
Use small disassembly/decompiler excerpts with the observed trace and memory
map. Ask for candidate roles, invariants, calling convention/register effects,
and counterexamples. Store hypotheses separately (hyp_ names or HYPOTHESIS
comments). Require runtime evidence before treating a name or bug as established.
This chat processes supplied excerpts using its model. Local tools do not
mean local AI inference. No local inference engine was installed.

Rollback
Remove only this project's ghidra MCP table and trust entry to disconnect it;
preserve other user configuration. Restore the backup only if no intervening
user config changes have occurred. Close Ghidra before removing this portable
workspace. Existing MAME installations, ROM archives, JDK, global PATH, and
system Python installations were not replaced. Pip may maintain its ordinary
download cache in the user profile; dependencies themselves are isolated.

Sources
https://github.com/LaurieWired/GhidraMCP/releases/tag/2.0
https://github.com/NationalSecurityAgency/ghidra/releases/tag/Ghidra_12.1.4_build
https://github.com/mamedev/mame/tree/mame0281/src/mame/barcrest
https://docs.mamedev.org/debugger/
https://learn.chatgpt.com/docs/extend/mcp?surface=cli

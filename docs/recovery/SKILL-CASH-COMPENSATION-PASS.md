# Skill Cash compensation and control-stack pass — 14 October 2026

This pass reuses the unchanged, already hash-verified focused MAME capture. It adds
executable recovery and compact evidence derived from that trace; no new MAME run,
installation or configuration change was required.

## Trace-backed progress

The runtime now executes C66A through C672, including C617, A110, A0E1, 1B93/1BA7,
99D8 and 9A00. Each of three captured chance calls has 80 nested VM dispatches.
All 240 dispatches match site/token, up to four stack cells, data-stack depth (U),
return-stack pointer (S), local pointer (F4), loop pointer (F6) and RNG seed.

The replay reconstructs byte/word RAM inputs from observations immediately following
A0F1/A102 reads. It supplies captured physical input-condition results and the IRQ
counter as platform inputs. Ratio, clipped index, chance-table result, random word
and final boolean are calculated; no C66A helper return is injected.

All captured counters read by this path are zero. The native 32-bit divider returns
zero for a zero divisor, so the rounded ratio is zero. A110 retains the other index
28 and computes clamp(0 - 28 + 4, 0, 8), selecting chance-table index zero. Nonzero
counter cases are static test vectors, not MAME path coverage.

The runtime also executes C6B3 through C6C3 and predicts the C6C5 successor for all
1,202 recorded selection iterations. The sampled choice byte, latch word at 0090,
timer word at 002D and abort ROM word are explicit platform inputs. Choice-positive,
latch/timer tests and terminal cancellation are calculated. The predicted successors
match C6AB for continued selection and C6C8 for each of the three accepted choices.
Accepted choices 3, 2 and 1 now feed stage reduction instead of recorded C699 returns.

## Physical VM frame recovery

The new control-stack model writes big-endian cells through the actual S pointer.
It preserves saved local pointers, local allocation size, the 76BD return trampoline,
loop index/limit/cursor/previous-pointer records, nested call continuations and early
return unwinding. Allocation preserves reused local bytes instead of zeroing them.

The feature prefix matches 29 recorded dispatches from C721 initialization and
C73C loop setup through its first 25-unit timing operand. S changes from 0796 to
078E on allocation, F4 becomes 0792, and the loop record puts S/F6 at 0786. Nested
calls in the compensation chain match all recorded S/F4/F6 states. Synthetic tests
cover local cleanup, nested loops and early returns. Full-feature cleanup is still
not established by an end-to-end C# run.

## Static arithmetic tests

Signed 32-bit quotient handling follows 1BA7/1C00/1B93: magnitudes are divided, the
quotient sign is restored, and the remainder is discarded. Zero divisors produce
zero; minimum signed value divided by minus one wraps. Byte-plus-word fetches
zero-extend the high byte exactly as 77F8 does; signed 24-bit extension is not added.
Double-cell addition wraps at 32 bits. A0E1 drops the quotient's high cell, increments
the low cell with 16-bit wrap and arithmetic-shifts it right, preserving that order.

Static nonzero compensation fixtures cover table indices 1, 6 and 8, as well as
quotient-cell wrap. These are verification experiments, not evidence that those
values occur in the selected MAME path. A changed accepted-choice latch is rejected
without changing expected outputs, demonstrating that inputs drive the decisions.

## Current limits

The runtime still does not execute C721 end to end. It replays bounded recovered
blocks. Generation of choice byte 004F by the sound/scheduler path, IRQ timing,
lamp/native output effects, NVRAM refresh 6E06 and AF93 win animation remain outside
the implementation. Recovered control mechanics are not a complete 6809 CPU or
memory-backed U-stack emulator; nonlocal transfers outside the implemented subset
fail explicitly.

The diagnostic viewer now exposes compensation, control-prefix and selection-decision
verification alongside the previous award replay. Headless and WPF solutions build
without warnings or errors; 23 verification groups pass. The expanded viewer has
build verification only.

## Evidence and reproducibility

- `compensation-calls.json`: three complete nested chance intervals, 240 dispatches.
- `control-prefix.json`: 29 initialization/loop setup dispatches.
- `selection-decisions.json`: 1,202 platform-input/expected-decision records.
- `helper-calls.json`: refreshed with S/F4/F6 entry/exit observations.
- `tools/Curate-SkillCashCompensation.ps1`: extraction gated by the verified raw hash.

Full raw logs and RAM remain in the original temporary run directory recorded by
focused-verification.json. The forensic workspace and original ROM are unchanged.

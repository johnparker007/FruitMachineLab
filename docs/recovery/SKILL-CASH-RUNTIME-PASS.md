# Skill Cash runtime pass — 14 October 2026

This report distinguishes executable translations, observed helper boundaries and
static branch tests. It does not claim complete Skill Cash execution.

## Trace-backed verification

A new MAME 0.281 run replayed the existing policy7 physical-input actions from fresh
isolated default configuration and absent NVRAM. No game RAM writes, ROM patches,
save states, installation or changes to existing MAME configuration were used.
Temporary run directories hold raw traces, sampled logs and final RAM outside Git.

The new run matches original vm-batch-policy7-a byte-for-byte in state.csv,
feature-state.csv, input-levels.csv and ram-final.bin. Focused instrumentation captured
all VM dispatches from C721 through C71D, including nested helpers and U/S/F4/F6,
four stack cells, local-frame bytes, IRQ counter, timer, RNG seed, selection bytes,
latch, option/abort words and pending/current-win values.

Curated helper snapshots verify:

- 3 calls to 99D8: native 59BB seed update, IRQ-byte mixing and low-cell multiplication.
- 3 calls to 9A00: native sixteen-step unsigned division, stack rotation and strict
  unsigned threshold comparison. All three captured chance operands are zero;
  other probabilities are covered by static tests, not by this recorded path.
- 3 calls to C646: disabled ROM-option gate retains the timer and returns false.
  The enabled random override branch remains unverified in MAME.
- 1,202 calls to C676: recovered terminal-choice gating and stack effects match.
  Three calls use the observed C66A compensation/chance result as an explicit
  boundary. The implementation does not derive that result from compensation RAM.

The final C71D observation has pending BA=0 and current win 02FA=10. This is a
MAME observation: the C# engine still stops its translated award path at BA=10
and does not yet implement the subsequent AF93 animation/NVRAM chain.

## Static deductions and executable code

Native 59BB updates seed 0324 with `(2053 * seed + 3619h) mod 65536`.
Returned B is the new high byte XOR IRQ counter 0033. Script 99D8 independently
mixes the new seed with 0033 replicated into both bytes. The runtime uses this
recovered operation, rather than a host RNG.

Native 7C56 performs sixteen shifts and conditional subtractions. The implementation
retains that algorithm for zero divisors and overflow; ordinary host division is only
used as a verification oracle when numerator-high is below the nonzero divisor.
Its overflow-domain behaviour is static coverage, not a demonstrated ROM defect.
At percentage 100 the native algorithm produces FFFF, rather than wrapping a host
quotient of 65536 to zero. The comparison remains strict; no rule correction is made.

The shared two-word fetch pushes the following word first and the first word on top.
Saved 7917 assembly establishes this order. This matters for mask/address records.

The award table at 75BD is `[0,10,16,20,22,47,60]`. The engine now executes its table
read and compares the resulting 10 with MAME; the amount is no longer supplied by
the replay. Chance-table and mask/address data are separately documented as static
ROM deductions in maps/skill-cash-rom-data.json.

Static tests exercise terminal cancellation with synthetic chance outcomes; these
inputs are test vectors, not physical MAME observations or recovered compensation.

## Harness correction

The first capture added multiple debugger setup commands and did not reach Skill
Cash. Input logs showed six paused callbacks at time 0.000002326 instead of the
original three. Since the recorded fixture uses frame numbers, physical input timing
shifted before gameplay. The corrected script preserves the original one-breakpoint
startup command count; all four campaign artifacts then match. No ROM/emulator fault
is inferred. The unsuccessful run remains in its original temporary directory.

## Reproduction

`tools/Capture-SkillCash.ps1` accepts explicit existing executable/ROM paths and a
fresh run directory. `tools/Curate-SkillCashCapture.ps1` extracts compact helper
snapshots and refuses campaign artifacts whose hashes differ from the baseline.
It preserves the original analysis workspace. Focused-verification.json records
executable/fixture/raw-trace hashes and source paths; no raw RAM binaries are tracked.

Next recovery targets: compensation helper A0E1/A110/C617, selection loop C699,
physical loop/local/return-frame semantics, IRQ scheduling, lamp/sound outputs,
6E06 NVRAM updates and AF93 transfer into current win.

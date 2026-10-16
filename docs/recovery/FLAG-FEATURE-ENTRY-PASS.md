# Paid three-flag feature entry

16 October 2026. Live now passes EE16 accounting, result/lamp setup, software
reel planning, CA table construction, nudge-pot animation and board setup. It
stops explicitly at E3AE before native61CF reel motion. This is an unfinished
paid game; the completed-game count remains zero on this route. The separate
returning route still completes three generated paid games in one machine.

## Natural reference windows

All fixtures below are in evidence/mpu4/skill-cash, with matching
`-verification.json` and `-debugger.cmd` files. MAME exited zero; no debugger
expression errors or injected RAM/register state were accepted.

| Fixture | VM boundary | Observations | Lamp requests | Sound commands |
| --- | --- | ---: | ---: | ---: |
| paid-flag-accounting | EE16 → EE22 | 34 | 0 | 0 |
| paid-flag-announcement | EE22 → EDE9 | 108 | 4 | 0 |
| paid-flag-reel-plan | EDE9 → EDFB | 558 | 0 | 0 |
| paid-flag-table | EDFB → EE09 | 606 | 4 | 66 |
| paid-flag-bootstrap | EE09 → E3AE | 9778 | 88 | 36 |

There are no alpha bytes in these windows. VM signatures, stack/frame pointers,
random state, output hashes and selected terminal RAM are compared by
BoardSelectionVerification. Adjacent captured entry/terminal signatures agree.
Table verification also compares CA..DC. Sound commands are verified without
claiming audio synthesis or complete electrical timing.

The physical initial nudge pattern is121 rather than111. The target occurs on a
later paid game, credit2/cash bank16, under the repeated physical input campaign.
It is not a first-subsequent-spin or whole-campaign equivalence claim for the
generated mixed-input Live test, which reaches this route with credit5. Each
natural window starts from its own recorded state. Live computes its own state
and outputs; these fixtures supply existing qualified pacing boundaries, not
recorded outcomes or player inputs.

## Recovered facts and preservation

- EE16 stores byte16 at0305 (already16 in the natural entry), then EBB8 subtracts
  16×500 from signed24 counter07D5:000000→FFE0C0 (-8000). Native6E06/6F57 preserve
  protected accounting/checksum behavior. No clamp or correction is introduced.
- EB3B maps category B9=3 to BC=11 decimal, then writes B9=3. The previous
  `reset_b9` label was misleading; the reviewed purpose is corrected. Other
  legacy caller labels are not evidence of a zero store.
- A2AB computes software reel offsets/DA..DC and restores current symbol
  projections through2BEB. It does not move physical reels. EDFB's queued94FC
  sound later executes nested94EC/94D1; the table window checks66 commands.
- B7C2/B795 construct CA..D9's16-byte budget/result table using native29F4,
  then fill the remaining tail with60. B89F retains table reads and the50%
  random test in their original order while seeding a zero pot; the natural
  bootstrap ends with pot1. No fixed-pot substitution is used.
- VM token7803/native7805 consumes `(lowWord highCell address --)`, stores the
  low byte of highCell followed by the big-endian lowWord. The byte write occurs
  before lowWord is pulled, which matters when the destination overlaps U.
- Token7BB8/native7BBA consumes `(address count value --)`, saves Y on S, pulls
  D/X/Y, skips writes for count0, otherwise fills forward with the low value
  byte and16-bit wrapping. Saved-Y residue remains at S-2. Modification of the
  saved continuation is explicitly unsupported, rather than guessed.

The two native words are byte-checked against the original ROM via exported
MAME disassembly. Their ordinary uses are naturally trace-backed; zero-count,
wraparound and mapped-U overlap tests are synthetic instruction-mechanics tests,
not a claimed MAME edge-case matrix. An already-idle scheduler wait may return
without a changed-clock input row; an active wait still requires recorded timing.

tools/Curate-NudgeData.ps1 extends the existing static-data map with constants,
lamp pointers, profile A679 and sound94D1..9534. Timing aliases check identical
two-byte entry gateways; native/profile bodies execute normally. A679 is a
static addition exposed by the real-time GUI return path, not a new natural
profile matrix.

tools/Curate-NudgeEncodingCheckpoint.ps1 now preserves147 selected VM spans and
1638 native instruction records, including raw operand/gap bytes, dictionary
headers7803/7BB8, stack effects, implementation and verification links. The
checkpoint does not claim lossless full-ROM decoding. Existing Ghidra exports
are retained; no live Ghidra API was exposed, so new portable Ghidra comments,
types and cross-references remain an explicit gap. No assembler or editor built.

## Reproduction and exclusions

Use tools/Capture-SkillCash.ps1 with the existing full natural paid-spin campaign,
NudgePattern121 and PaidFlagAccounting, adding PaidFlagAnnouncement,
PaidFlagReelPlan, PaidFlagTable and PaidFlagBootstrap in that order. Exact flags,
input hashes and isolated capture metadata are preserved in each verification
sidecar. Recurate with tools/Curate-BoardLink.ps1 using those same flags.
The bootstrap legitimately seeds a nonzero pot; its curator excludes the older
exhausted-pot terminal check. Raw captures remain external.

paid-result-capture-attempts.json records accepted runs and two exclusions: a
narrow credit5 qualifier missed the later entry; an unqualified announcement
entry subsequently crashed MAME. Neither supplies accepted reference output.

Build FruitMachineLab.sln and FruitMachineLab.Headless.sln with `--no-restore`;
run `dotnet run --project tests/FruitMachineLab.Verification --no-build -- .`.
The mixed Live test checks physical nudge input, prompt/motor Pause, counter
debit/complements, bank16/credit5 and the explicit E3AE stop. GUI smoke coverage
includes the same mixed path, returning paid game, all previous live modes and
separate verified playback.

Final validation:188 headless groups passed; all eight WPF smoke modes passed
(live-nudge rerun after adding the byte-checked A679 entry profile). Both solution
builds succeeded without warnings/errors. The final mixed-route WPF render was
inspected at E3AE, with released inputs, bank16/credit5 and completed games0.

Next recover native61CF/61F6's selected feature-entry reel request/motion and
the following board entry. Do not bypass E3AE or fabricate hardware completion.
Startup, collection and hundreds of complete games remain future milestones.

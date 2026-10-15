# Incremental board advance after a dice roll

15 October 2026. The default Live entry now executes one dice roll followed by the
recovered board advance. The board square, nudge pot, ROM square type, link and
visited-square sequence are visible. Lamps change through the actual VM helpers.
Pause suspends the VM, virtual clock, motor and board movement; Resume retains all
state. The existing Take → Skill Cash route and separate playback remain available.

The new boundary is before the next DE96 result return or DD38 selection, after
zero-link DBC4 dispatch. A nonzero link stops at DAC7/DB58 before ladder/snake
animation. This is one advance from the recovered square-32 feature entry, not
complete board play, machine startup or persistent games. Restart restores entry.

## Natural reference

A fresh isolated physical-input campaign captures B28F at square 7, after the
verified dice roll, through DE96 at square 11. The unchanged ROM scripts execute
DD8D/DDAB, DDF3 movement, A285 lamp refresh, A8EF nudge-pot display, DBC4's zero-link
return and the DDAF type-3 exit. The nudge pot remains 4 on this reference path.
The curator independently matches its first 25 VM fields to the earlier roll's
B28F terminal observation. The synthetic probe below preserves those entry fields
except for its explicitly redirected Y/token pair.

The translated replay matches all 12,355 canonical VM observations, including
the two new board/pot fields in addition to the earlier 25 fields. It checks all
11 lamp requests and resulting frame memory, 60 sound commands, input-condition
observations and accounting. There are no frame masks or lifted dispatches on
this natural path. No alpha serial bytes are emitted during this post-roll segment;
this does not resolve the earlier rolling brightness discrepancy.

Both timer-word reads and an IRQ-counter byte read can cross an IRQ inside a VM
word. The reference-only adapter records those phases and advances the actual
counter before the fetch. It does not replace the fetched value. Omitting the new
byte-read phase changes the RNG path; the full VM digest rejects that difference.
Live generates its counters under the existing IRQ adapter and uses no recorded
input, board-square, nudge-pot or memory-read results.

## Nudge animation probe

Square-32 Live variations reach DDE3's nudge-pot digit animation, which the square-7
natural reference skips. A separate MAME experiment explicitly redirects Y to DDE3
at the natural B28F boundary and observes through DDEF. This is a synthetic helper
invocation, not a physically reached feature path or a payout campaign. The source
debugger commands and curated classification retain that distinction. The run's
explicit synthetic flag is authoritative for its scope; its inherited generic
initial-state description still says physical-input-only. The capture tool now
corrects that description for future synthetic runs; the original run is preserved.

The probe retains a raw digest of all 9,613 observations. As in the existing jackpot
proof, four inner 8571..8577 observations per 856F call are explicitly lifted: the
native allocator-list address is represented by a typed scheduler-active test,
not a fabricated physical head pointer. Exactly 48 observations are excluded,
leaving 9,565 matching VM observations. The verifier checks that normalization
count and all 36 sound commands. The animation's byte stores execute normally;
this is VM/operand and sound-protocol proof, not an independent electrical
seven-segment display or audio-synthesis comparison.

## Translations and data

- Native 7655 increments the addressed byte, consumes the address and wraps FF→00.
- Native 7C08 signs the 32-bit numerator and 16-bit divisor, runs the existing
  unsigned divider, then adjusts opposite-sign results. Nonzero remainders use a
  complemented quotient, preserving floor rounding and the native magnitude
  remainder convention. Zero divisor and overflow retain native results. Negative
  and exceptional arithmetic tests are static deductions/synthetic inputs; the
  natural movement reference exercises ordinary positive quotients.
- Native 7B63 PICK uses twice the unsigned word index modulo the address space.
  Physical stack memory is synchronized before popping the index, retaining the
  popped index on wrapped access. A838's actual recovered instruction is exercised
  by the synthetic MAME probe and targeted wrap tests.
- The 7AC7 entry within the exported 7AC5 block rotates a cell left by the low four
  count bits. Native 756A adds the physical loop index to the top cell with wrap.
  These drive A831's recovered digit loop rather than a UI animation.
- Selected 8E6D/971F sound data and A64B profile bytes are copied from the unchanged,
  SHA1-checked ROM. For alternate entry preludes, 8E93 and 96E8 are statically
  validated as the same 8568 parameter gateway as measured 8EE2. Only entry pacing
  is shared; decoded bodies still execute. Unknown native costs still fail.

The existing B853/B7F5 scripts perform the nudge-pot chance/gating logic. Their
decoded instructions run directly; this pass does not assert complete recovered
intent from their still-unresolved names. No guessed pot increment or landing
result is assigned. Square-32 synthetic input variations complete dice requests
2,4,6 and visit squares 34,36,38 respectively. Those are separate contexts from the
square-7 MAME reference and do not establish payout behavior.

## Diagnostics and checks

The headless session exposes board state and visited-square history alongside
lamps, alpha and dice state. The UI renders those values; no game logic moved into
WPF. No temporary cabinet artwork or importer was built. Diagnostic data remains
useful alongside the planned FML renderer.

106 verification groups pass, retaining the prior feature, motor and playback
proofs. New checks cover natural movement, the synthetic DDE3 probe, native signed
division edges, PICK wrap, rotate/loop arithmetic, byte increment and a live
mid-movement pause. Visited squares occur over virtual time, not in a precomputed
jump. The eight live input variations now run through the advance boundary.

Headless and isolated WPF builds pass without warnings. All four GUI smoke modes
pass. The roll smoke now pauses separately during motor motion and board movement,
checks frozen memory/time/dispatches, resumes to the expected square, checks input
release and restart, and renders paused/completed states. Images were inspected.
One smoke completed 32→33→34→35→36→37→38, dice 6, nudge pot 10, in 2.746 virtual
seconds. This is a synthetic player timing check, not a MAME timing-equivalence claim.

CPU/IRQ scheduling remains provisional. The previous combined roll reference still
reports 83/84 alpha bytes: one final brightness restoration differs, with text,
cursor and resets matching. Earlier strict alpha comparisons are unchanged.

Capture-SkillCash.ps1 `-BoardMovement -FullFeature -CpuInterrupts -NativeSound
-NativeInput -NativeAlpha -NativeLampFrames` captures the natural segment. Add
`-NudgePotProbe` only for the explicitly synthetic helper experiment. Curate with
Curate-BoardMovement.ps1 and its corresponding probe switch; selected ROM data uses
Curate-BoardMovementData.ps1. Raw logs and ROM binaries stay outside tracked files.

## Next work

Capture and translate nonzero-link DBC4 paths, including ladder/snake animation,
destination setting and pot adjustments. Then extend the next square's result or
selection and retain machine state across multiple board decisions. Preserve the
one-advance reference and the distinction between synthetic helper tests and natural
campaigns. FML integration remains planned alongside broader normal play, using
John's existing importer/renderers when supplied.

No installations, system/existing MAME configuration changes, commits, pushes or
cloud access changes were performed. The original forensic workspace is untouched.

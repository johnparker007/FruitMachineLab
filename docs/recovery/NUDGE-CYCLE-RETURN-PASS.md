# Nudge bank service and outer-cycle return

15 October 2026. Live now continues beyond the cash-bank commit, checks the
combined-bank limit, returns through the actual paid-play/feature callers, passes
the ROM's data-stack balance check and starts the next outer cycle. Its credit
and bank display refreshes naturally. The next explicit stop is FAF0, before the
IC8 output update and following background services. This is not yet a ready
paid-spin loop, completed collection or consecutive whole-machine play.

## Successful natural windows

The existing physical TAKE/three-Nudge1 campaign is unchanged. Two fresh isolated
MAME runs use read-only narrow VM logging and save entry/terminal RAM. Both exit0
with no debugger expression errors, without PC/register/RAM/ROM injection:

- nudge-bank-return: AF25 → FE1F,131 raw/canonical VM observations, one lamp
  request, no sound commands or alpha bytes. Entry fields match the previous
  nudge-accounting terminal, excluding absolute CPU cycle.
- nudge-cycle-init: FE1F → FAF0,88 raw/canonical observations, no lamp requests
  or sound commands and35 alpha bytes. Entry fields independently match the
  bank-return terminal. Both complete VM signatures and output digests match.

Neither window lifts dispatches or excludes frame words. Protected accounting
2F0..322, pending/current win, statistics043A..0457 and accounting07C9..07E7 match
the terminal snapshots. These are separate successful runs; the older failed-later
transfer-prefix and full-logging MAME crash qualifications are unchanged.

## Recovered route and conditions

AF25 invokes AEF9. It sums0302+02FC and compares the signed16 result to the limit
chosen by AEE6: FF4A zero selects99, nonzero selects500. The selected natural bank16
does not invoke AA2B collection service. Focused synthetic VM tests cover both
option branches, equality, above-limit andFFFF signed behaviour. These tests stop
explicitly on the service branch; they do not claim to implement collection.

The actual return is AF0F → AF27 → AF4A → B013/B018 → FC78/FC7C → FCDE →
FDDA/FDE2 → FD8D → FDEA/A285 → FDEC → FE10..FE1F. The repeated AFF4 calls preserve
the bank and clear the ROM's masks/categories as scripted. Condition82 is false
in this campaign, so its optional AAA1 calls are bypassed.

Condition82 reads masks0004 at722A: sampled port7 bit04, not physical COLLECT.
The existing mapping names physical BLACK2 bit01 Collect / Take Feature, selector1C.
The recovered AB1B credit path invokes AAD7 when credits remain; no-credit AAF2
reaches AAA1's collection handling. This campaign still has six credits. Do not
force collection merely because the bank is nonzero, override its credit gate,
or substitute condition82 for a player control. No new button is needed yet.

9ABE checks current U against saved native-entry X. Token7B33/native7B35 reads
`word[word[F2]+4]`, with16-bit address wrap, and pushes that word. It does not use
the host's DataStackBase as a substitute. The natural cycle balances at U0672.
An isolated frame-pointer test covers wrapping through address0000 and verifies
that a mismatched saved pointer reaches the unsupported software-error boundary.
The older9AD0 listing placeholder0000 is corrected to exact raw token338A; that
unexecuted diagnostic-hook region remains unresolved.

FE1F branches back to FE06. FAC9 writes the cycle timers, refreshes reel symbols
and credit/bank alpha output, restores the saved U pointer and calls native5429.
Its idle branch is exactly TST7D; LBEQ53AD, where53AD is RTS. This branch is
translated only when7D is zero. Busy serial processing fails explicitly; it is
not replaced by a no-op, manufactured response or guessed timeout. A focused
test checks unchanged idle memory and busy rejection without side effects.

Live preserves cash bank16, token bank0, credits6, pending/current win0 and final
main reels6/90/42. It generates the additional lamp update and alpha refresh;
the GUI now includes credit count alongside bank values. Physical inputs and
Pause/Resume remain independent of the reference replay. The full interactive
test compares the combined lamp sequence, final alpha shadow, accounting vectors
and existing motor/transfer/flash/accounting pauses through the new boundary.
Live CPU/IRQ pacing still uses the documented captured boundary adapters; these
checks do not establish instruction-exact electrical timing.

## Preservation and reproduction

The existing nudge-encoding checkpoint now has63 byte-checked selected VM spans
and879 native disassembly rows. Seven VM spans and three aligned native exports
were added for this work. Mask/address records8530,84B6,84AA,84A4,8486,848C and
optionFF4A are retained through Curate-NudgeData.ps1. Its SHA1 guard checks the
same a6ls.p1 ROM. No full-ROM lossless or relocation claim is made.

Existing exported Ghidra5429 symbols, pseudocode and assembly were copied from
the prerequisite saved-functions export into native/5429.json and linked by hash
in the checkpoint. This is a preserved prior export, not a fresh Ghidra session.
Fresh namespaces/comments/data-definition export remains unavailable because no
live Ghidra API is exposed. The original project and workspace remain untouched.

Capture-SkillCash.ps1 adds NudgeBankReturn after the previous complete accounting
flag chain; add NudgeCycleInit for the second window. Both require TailWindow.
Curate-BoardLink.ps1 takes the matching switches and rejects incomplete runs.
The raw captures stay in fresh temporary directories; curated fixtures contain
the selected signatures, timing boundaries, outputs, RAM and provenance.
Export-MameDisassembly.ps1 with NudgeCheckpoint/AccountingCheckpoint and the
existing encoding curator reproduce the byte checkpoint, retaining the prior
StackRunDirectory watchpoint proof.

## Next gameplay task

Recover the IC8 port0F02 read/write contract for9D5A at FAF0, then proceed through
FAC9/FDBA and the real background/input loop. Background helpers include status
lamps, characteriser, door mode, NVRAM checks and service/Test gates. Preserve their
actual guards and fail explicitly at unsupported hardware paths. Reach the next
paid-game input loop without bypassing credits or ROM services. Collection needs
its real prerequisites or a separately labelled isolated fixture; completing
bank service here does not establish payout delivery.

Validation uses the installed SDK: headless build,147 verification groups,
isolated WPF build and all eight GUI smoke modes. No installation, configuration
change, commit, push or cloud setup was performed.

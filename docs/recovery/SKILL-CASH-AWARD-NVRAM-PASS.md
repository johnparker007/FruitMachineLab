# Skill Cash award accounting and NVRAM pass

The recovered AF93 accounting slices now calculate the transfer of pending award
10 to current win 10. Ten slices match 280 MAME dispatches, including nested
indirect predicates, stack cells, U and physical S/F4/F6 pointers. Each slice
starts from recorded stack/control context; pending and current-win results must
join continuously across the ten slices. Display, sound and wait effects between
them remain outside this execution. Full C721/AF93 orchestration is still pending.

## Native 6E06/6E0D

The translation preserves the service-mode bit-80 return gate. In game mode it
complements bytes 02F0..0308 into 0309..0321 and writes checksum 0322. The checksum
is the wrapped negative sum of the 25 source bytes minus 32 hex, plus any change
to the checksum since its initial snapshot. The first ten bytes execute with
guard 002C set to one; the remaining fifteen execute after restoring the guard.
The CPU condition-code save/restore and temporary physical U-byte push are not
emulated by this memory-effect helper. Recorded native entry/exit U is unchanged.

Thirteen recorded calls match every source byte, complement byte, checksum and
guard. These comprise the pending commit, ten transfers, terminal pending clear
and even-rounding refresh. Native saved assembly is authoritative; the decompiler
had incomplete register and interrupt context. No whole-feature NVRAM dump is
tracked and no original forensic files were changed.

## Evidence classifications

Trace-backed: `award-calls.json` contains native entry/exit observations and
bounded VM accounting slices. `award-verification.json` records raw debugger and
MAME executable hashes. The new isolated MAME run matches the original campaign's
state.csv, feature-state.csv, input-levels.csv and ram-final.bin byte-for-byte.

Static: ROM pointer cells 851E=FF36 and 8522=FF3A, with bytes FF at both targets,
drive the recorded one-unit transfer route. The helper translates recovered
16-bit negation, memory addition, Forth truth and control branches.

Synthetic: service-mode bypass, an IRQ-style checksum delta during the unprotected
portion, and altered indirect bytes selecting the two-unit route are tests, not
MAME observations. The two-unit route subtracts two from an odd pending value
without clamping; its 16-bit underflow is preserved. No claim is made that these
alternate inputs represent an actual playable configuration.

## Reproduction and remaining boundaries

Run `tools/Capture-SkillCash.ps1` with existing MAME/ROM paths, a fresh external
`-RunDirectory` and `-NativeNvram`, then `tools/Curate-SkillCashAward.ps1
-RunDirectory <run>`. The observer skips the two extra paused debugger setup
callbacks to preserve the original physical-input timing. An initial malformed
debugger-command attempt was excluded from curated evidence; the corrected run
contains thirteen paired entry/exit observations and passes the campaign hashes.

Thirty-two verification groups pass. The GUI reports the independently calculated
current-win result alongside pending award; pending 10 still describes the bounded
commit state, not the terminal pending balance. NVRAM and award accounting are no
longer wholly untranslated, but full feature orchestration, peripheral effects,
award animation timing, final bank/payout and general CPU-cycle timing remain open.

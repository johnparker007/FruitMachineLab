# Background services to preplay dispatch

16 October 2026. Live now executes the status-lamp service, characteriser check,
unchanged-door guard, NVRAM polling and Test-menu gate, then returns through
credit/display handling to FC99. Cash bank16/token bank0/credits6 and pending/
current-win0 remain intact. FC99's preplay eligibility, holds/gamble paths and
game-start dispatch are the next boundary; another paid spin is not implemented.

## Natural evidence and validation

Three successful read-only windows extend the existing physical TAKE/three-Nudge1
campaign, without PC/register/RAM/ROM injection:

- nudge-status, FBF1 → FBF3:2 VM observations,2 lamp requests.
- nudge-services, FBF3 → FC03:13 observations,1 lamp request,64 separately
  observed characteriser calls/responses.
- nudge-preplay, FC03 → FC99:276 observations,6 lamp requests,70 alpha bytes
  and another64 observed characteriser calls/responses.

All processes exit0 without debugger-expression errors. Each entry independently
matches the preceding verified terminal, excluding absolute CPU cycle and new
hardware fields. Complete VM signatures, lamp-frame digests, sound/alpha outputs,
protected accounting, statistics, port samples and NVRAM count38 match. No VM
dispatches are lifted in these windows. Prior fixtures and failed-capture
qualifications remain unchanged. These separate windows are not a single full
machine capture, a physical PAL proof or completed payout evidence.

Native482F also has a14-case isolated MAME matrix. Explicit registers, flags,
sampled inputs and PIA output setup are synthetic; IRQs are masked. It compares
ordered lamp calls, including duplicate calls, rather than full native stack
residue or electrical lamp delivery. The initial matrix harness used a temporary
run-to address canceled by the lamp observer's `go`; that incomplete attempt is
excluded. The fixed harness uses a persistent return breakpoint and all14 cases
complete. The owned unfinished MAME process was stopped; original settings were
preserved.

156 headless verification groups, headless and isolated WPF builds, and all eight
GUI smoke modes pass. The interactive nudge test now checks FC99, the combined
lamp sequence, final alpha shadow, bank/credit state and inherited output latch,
retaining the existing motor/transfer/flash/accounting Pause/Resume checks.

## Status lamps: native482F

Lamp59 uses mask0F or07 according to032F and the low output bits of IC5 port0C02.
It receives80 if every selected bit is set, otherwise8F. Lamp38 is gated by0338,
032F, IC8 port0F02 bit20, inline input conditions04/03 and ROM optionFF34.
0338 nonzero clears lamp38 twice; this redundant call is preserved. With032F
nonzero the0C02 bit01 branch differs from the normal0F02 bit20 branch. Conditions
are evaluated through the recovered input-table code, not UI selections.

Inline selector bytes at487C/4882/48A6/48AC are04/03/04/03. The4892 arm is
statically unreachable after the preceding `LDA #38; CMPA #38; BNE` sequence;
its bytes remain preserved, without inventing a reachable input condition.
The natural selected entry records IC5 data00 at E247 and the new status window.
That inherited port state is seeded alongside the qualified IC8 entry shadow.
This is not a general AUX2/coin-lockout device model or new coin-input support.

## Characteriser: ROM helper and MAME adapter

Native68F1 tests719B bit01 and otherwise walks64 challenge/expected pairs at
2B39..2BB8. It writes each challenge, reads a response, masks with FC and compares;
a mismatch reaches SWI alarm16. The translated scan retains the bypass, masking,
table order and explicit mismatch boundary. All64 response observations in each
natural window match.

The selected MAME m4addr configuration is `cheatchr_pal<addr_characteriser_prot>`.
Its6809 compatibility read returns the byte at the CPU's current X, except for
the0800..0FFF recursion guard. In68F1, X points to the expected ROM byte. The
explicit `Mame6809CompatibilityResponse` adapter reproduces that MAME contract
from current memory; it does not replay recorded responses or implement the
unknown physical PAL transformation. Lamp scrambling remains separate. Do not
claim reconstructed PAL hardware or hardware-ready protection from this pass.

Source references are the preserved MAME `mpu4mod4yam.cpp` configuration and
`mpu4_characteriser_pal.cpp::protection_r`, under the original local evidence
workspace. The public MAME source locations are
https://github.com/mamedev/mame/blob/mame0281/src/mame/barcrest/mpu4mod4yam.cpp and
https://github.com/mamedev/mame/blob/mame0281/src/mame/barcrest/mpu4_characteriser_pal.cpp.
Source paths and SHA256 values are retained in the existing encoding checkpoint;
the curator accepts MameDriverSource/MamePalSource at a fresh checkpoint and
preserves them on later runs. Attribution is retained in THIRD-PARTY-NOTICES.md.
Focused synthetic tests cover
bypass, masked low bits and a forced response mismatch; no fault is labeled a ROM bug.

## Door, NVRAM and Test guards

Native6EF7 derives mode80 from inline condition0E's carry flag, not a returned B
value:67E2 preserves B. Unchanged mode returns. A change writes0323; leaving
service restores25 protected source bytes and15 accounting bytes from their
complements, then reaches7CCF reset. These recovered effects are retained before
an explicit reset boundary. The reset/startup path is not guessed.

Native6E99 decrements byte38 with wraparound. Nonzero count or negative mode
returns. At zero in normal mode it saves guard2C, sets it to1, checks25 complement
bytes and their checksum, then restores the guard on success. Corruption reaches
6EDE repair/reset; the translation stops there with the fault-state guard/count
preserved, without silently repairing NVRAM. The natural windows exercise the
fast path; isolated C# experiments test the statically recovered zero-count
validation, corruption and wrap paths. These alternate tests are not MAME traces.

Native2E53 returns in normal mode. Service mode tests selector10; a requested
menu remains an explicit unsupported boundary. Synthetic tests also exercise
the restored-memory door-reset boundary and Test-menu rejection. Native CPU
stack/register residue is not modeled in full, and interrupt interleavings on
these unobserved fault branches remain outside verification.

## Preservation and continuation

The existing byte checkpoint now contains75 selected VM spans and1088 native
rows, with exact native/status/characteriser/door/NVRAM/Test bytes, inline selector
records and implementation/evidence links. Linear MAME disassembly across inline
payloads is explicitly not a full code/data typing claim. Existing Ghidra exports
for482F/68F1/6EF7/6E99/2E53 and the67E2/67EC input-flag contract are preserved
and hash-linked; they are prior exports,
not fresh symbols/comments/data-definition exports. Live Ghidra access remains
unavailable. Full symbolic tooling and baseline reassembly remain deferred.

Capture-SkillCash.ps1 adds NudgeStatus, NudgeServices and NudgePreplay to the
existing complete IC8/background chain, with TailWindow/NoMotorItems. Separate
short HW/CH records avoid expanding the main dispatch printf. Peripheral logging
stays inside the selected window. Curate-BoardLink.ps1 takes matching stage flags;
Capture/Curate-StatusMatrix.ps1 reproduce the isolated lamp-call matrix. Raw ROMs
and captures remain outside tracked files.

Next start at FC99/D30F: recover the real preplay eligibility and hold/gamble
guards before advancing through FCB3/FCD5's Start-latch decision and paid-play entry.
Do not route START directly into a spin or bypass credit accounting. Waiting
long enough for timer002F to change sign may reach still-untranslated2CB3/171D
lamp services; retain that dependency explicitly. Full machine startup, coin
insertion, repeated complete games and collection remain future work.

No installation, configuration change, commit, push or cloud access was performed.

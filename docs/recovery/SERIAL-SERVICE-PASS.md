# Serial service recovery

Gameplay priority: repeated payouts enqueue logger messages. Native5429 busy wait
cannot be replaced with an automatic queue clear/ACK. This extends existing
collection evidence/export conventions, not a new preservation system.

## Source audit

Pinned MAME mame0281 commit2843a3deb81cf93735244044894196ccfbea4d20:
src/devices/machine/bacta_datalogger.cpp defines1200 baud,8 data bits, odd parity,
one stop bit and an ACK06 for received nonzero characters. Its data>80 masking
and unreachable nested data!=0 NAK branch are source facts, not assumptions about
physical logger hardware. MPU4's pia5 CA2 TX goes to write_txd; IC4 PB7 reads RX,
and CB1 participates in serial IRQ. Serial-line scheduling/IRQ acceptance remain
unimplemented. Local MAME unrelated edits were read/preserved, not synchronized.

Historical prerequisite saved-functions51B1/5330/53AE/546A/5471/5744 exports were
copied into native evidence, retaining their mechanical/hypothesis annotations.
They are historical Ghidra exports, not freshly synchronized symbols. Selected
new byte regions are checked against original a6ls.p1, with normal ROM hash gate.

## Reply53AE

AddersSerialReplyPlan stages the original byte parser, including the native S
saved A byte. Inputs are A and RAM0346..034C; result B is0 complete,1 error,
2 partial. ACK clears346/348; manufacturer header65 initializes34A/349, length
initializes347 and adds to349, payload stores through signed B indexing from34B.
Crucially53D5 ADDB B,X is followed by53D7 STA0349, so the checksum field receives
the incoming A byte rather than the calculated B sum. Preserve this ROM quirk.
Signed index aliasing is also retained, including malformed-length experiments.

Capture-SerialReply.ps1 / existing Curate-SoundYield.ps1 -Operation serial-reply
produce32 synthetic original-ROM calls, eight parser states and four byte values.
Every emitted instruction byte/cycle and full2KB RAM matches. No wire timing or
genuine logger response is inferred. Raw pointer FruitMachineLab-serial-reply.txt
under TEMP. Existing native export conventions and curated manifest are reused.

Next compose5330 transfer state around actual parser results, then queue->frame
and busy wait. Do not attach a simulated ACK until its transport boundary is
explicit. No MAME settings/ROM/Ghidra installation changes.

## Transfer state5330

AddersSerialTransferPlan composes the byte parser and native5330 state paths:
73/71/72 gates, receive status75, accepted ACK clearing3A5/2B bit7/7D/80,
and retransmit preparation at38F/3A3/3A6 with original high-bit marking.32 native
instruction/RAM comparisons pass with injected status/bytes, not physical serial
traffic. Retry reaching70C9 stops explicitly before an unowned PTM reset; no
register write or elapsed retry duration is invented. Native byte-result2 returns
without clearing a partial frame. Capture-SerialTransfer and shared curator mode
serial-transfer preserve source5330..5428 and before/after2KB. Raw pointer:
FruitMachineLab-serial-transfer.txt. Busy5429 remains unconnected to Live.

## Positive queue frame51B1

AddersSerialFramePlan stages selected positive-message51B1..5282:84 gate, empty
pointer reset, existing-frame exclusion, original read-pointer range, queue debit/
checksum,2D/2E door substitution and73 mode,38D reader initialization, disabled/
null5744 hook and duplicated short outgoing byte at38F. Thirty-two original-ROM
synthetic cases match all cycles/bytes/full RAM with message1/2D/2E/5F. Opcode
negative/complement/decrement costs are covered. Negative two-byte queue messages,
enabled nonnull5744 hooks and >=60 extended packets stop explicitly, not silently
drop data. Capture-SerialFrame/shared curator serial-frame preserve code/pointers
and data regions under existing collection conventions. Raw serial-frame.txt.

## Native wait5429

AddersSerialWaitPlan stages5429..5468 with typed handoffs for2CB3 timeout lamp,
5471 timeout alpha,546A completion reset and6EF7 door check. Native JSR return
words are written to S-2; advancement blocks until balanced ReturnFromCall.
Entry5434 supports explicit isolated boundary experiments with X/A, not a Live
startup alternative. X decrements by signed A, becomes zero/A0 after full timeout,
clears75 at F000 only when low bits are set, and formats at <=1000. Busy7D must
actually change externally; there is no ACK/time injection or automatic success.

Static serial-wait-data preserves exact bytes/entries/helper references and links.
A synthetic ownership test proves two busy iterations remain busy, blocks helper
bypass, and reaches alpha reset only after external7D clear. Full helper CPU
register/flags are not reconstructed by this plan: NativeRoutineCall carries the
declared caller condition context, not an asserted complete NZVC result. Helpers
must be separately composed with a valid register contract before Live use.
Next original-ROM boundary captures; full wait/transport timing remains open.

Capture-SerialWait/shared curator serial-wait now preserve32 original-ROM wait
prefixes to the FIRST helper or idle return, without skipping a helper. Explicit
5434 entry states exercise X/A zero/1000/F000 thresholds and75 low bits. All
emitted byte/cycle/full2KB RAM/boundary PC match, including native S-2 return word.
These are isolated synthetic boundaries, not natural serial wait timing. Native
helper flags/outputs remain outside scope, as does physical completion. Raw
pointer FruitMachineLab-serial-wait.txt. Verifier also stops at the typed handoff,
and checks that instruction effects do not occur a cycle early.

## Final component integration and preservation audit

Returned B from53AE is now compared with all32 captured native returns, in
addition to the instruction/RAM matrix. A synthetic100-transaction check composes
actual payout enqueue,51B1 short frame,5330 retransmit marking and53AE/5330 ACK
acceptance. Test code injects receiver75 status and byte06 at an EXPLICIT hardware
boundary. Only recovered code clears7D/3A5/80. The assertion deliberately retains
3A6=2: ACK is not fabricated wire progress and does not drain that counter.
This verifies component contracts, not a100-message physical or MAME serial run.

The shared curator had accumulated overlapping operation selections while adding
serial modes. Final audit replaced these with one operation table, unique case
checks and a single region selection. All15 sound/serial modes were reproduced
twice from retained raw captures with stable hashes and rerun component checks.
Selected source regions changed where a previous broad fallthrough had retained
unrelated sound bytes; no runtime ROM/trace behavior was changed. Naming remains
Curate-SoundYield for compatibility with documented commands; serial evidence uses
the same collection schema/catalog/manifest and serial-* stems.

## Remaining gameplay boundaries

Native sound prompt and collection integration are verified headlessly. Live still
needs one CPU owner across ordinary VM/helper budgets,776F native helper bridges
and accepted IRQ work. Do not attach timed sound by merely shifting whole VM
words. Serial next needs genuine transport bit/baud/PIA/PTM ownership,70C9 retry
reset, complete helper register/flags at5429 handoffs and selected negative/extended
packets/callbacks when actually encountered. MAME logger source is an external
behavioral reference, not permission to inject a successful ACK at a guessed time.
Keep work proportional to playable Adders; no assembler/audio/unrelated IRQ work.

## Transport cycle:69A9 bit images

AddersSerialBitPlan stages69A9: FF sentinel bypasses the PIA read; otherwise bit0
selects CA2 low/high in an image of actual IC7 control C01. The image preserves
low unrelated bits, forces control3C and clears bit08 for zero.32 synthetic native
calls match bytes/cycles/full RAM with actual MAME C01 read values. No byte/baud
timing is inferred yet. New transport tools reuse the same catalog/RAM schema and
collection location. Curator normalizes a single legacy flattened span so source
regions cannot silently expand backwards; initial bad export was rejected by the
opcode comparison and replaced, with no raw capture changes. Raw serial-bit.txt.

693E byte preparation now composes69A9, writes actual native stack scratch,
disables receive edge enable atB03, and emits7/8 data, optional parity,1/2 stop
images andFF sentinel before typed69FE ownership.32 native frame cases match all
instruction PCs/cycles/bytes and full RAM. The first observer omitted BSR sites
inside the shared Bit method; it was excluded and recaptured with those sites.
Busy71 still stops explicitly pending a timer owner. PIA reads are explicit;
the current comparison checks RAM and CPU costs, not emitted wire timing. Historical
native693E/69A9/69C0/69FE/6A08/6A3B/6AC1/6B0E/6B4D annotations are preserved.

Timer270C9 reset and70D6 arm now stage their real B/CC saves and declared mask,
status/counter reads, callback3B, control62 at901/shadow3F and ordered latch MSB/
LSB904/905 writes.16 native original-ROM calls match instructions and full RAM.
Bus read/write delegates are mandatory; no peripheral register image silently
stands in for a device. CPU instruction costs are proved; exact intra-instruction
bus strobe phase/expiry acceptance are not yet inferred. Mode62 is one-shot
internal16-bit, not the timer1 continuous period model. Zero/FFFF latch cases
verify programming only. Raw serial-timer.txt; early observer version omitted
dynamic ORCC entries and was replaced with explicit observations.

Receive arm6A08 now stages72 guard,75 reset, native save frame,500-tick7A timeout,
B02 acknowledgment read,6A3B vector81 and B03 edge-enable write.16 original-ROM
paths match all emitted instruction cycles/bytes/RAM. Existing active72 returns
without reinitialization. Hardware reads are explicit. Raw serial-receive-arm.txt.

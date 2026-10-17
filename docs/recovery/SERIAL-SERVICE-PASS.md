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

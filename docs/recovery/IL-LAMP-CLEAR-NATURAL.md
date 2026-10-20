# Natural compiled lamp-clear call

Supervisor-reviewed task 74, 20 October 2026. One isolated fresh-boot MAME
0.281 run executed the compiled pattern-80 word naturally at the existing
9F14 caller. No save state, injected cursor/register/RAM, retry or observer
code change was used. MAME and the independent checker exited 0.

The exact output SHA256 is
`347D475E20C194F374DF85A04894BC68D89E05043CA89C5B031316868240EB88`;
the map SHA256 is
`1845ED2A98B8347B8618D7E9A6E7AFD68B3CF14532C20268AAE273DD782E83B1`.
The allocation remains 24 bytes at 1010-1027, with 968 bytes remaining in the
approved 992-byte range. Original ROM and frozen inputs were preserved.

All 43 mapped phases were observed, with 10 native boundaries, four conditional
skips and 52 distinct physical debugger stops. Native PC and VM cursor Y were
recorded separately. The actual CPU response after the 0803 read was 00,
deriving column 15 and mask 01. F1 entry/exit was 00; optional 080C writes were
skipped. Saved and restored CC was C0. Native entry A/B was 78/80.

| Frame address | Before | After |
| --- | --- | --- |
| 010F | 3F | 3E |
| 011F | 3F | 3E |
| 012F | 3F | 3E |
| 013F | 3F | 3E |

Exactly these four bytes changed within 0100-013F. Each write cleared bit 01
and preserved other bits. The outer return reached PC=00FC, Y=9F16,
U=066E, S=0798, result 0000 and successor 75A9. This establishes the measured
original-service call and return, not broad caller safety.

The supervisor independently checked the raw phase/stop counts, frame snapshots,
return, exit, frozen image/map/Lua hashes and empty immediate-prelaunch inventory,
then reran the offline checker successfully against unchanged raw evidence.
Private capture: `artifacts/deepseek/il-lamp-clear-natural-74/natural-01/`.
Compact identities and evidence hashes:
`evidence/mpu4/integrity/il-lamp-clear-natural.json`.

This is a **frame-RAM transition**, not photographed or rendered lamp output.
Only the measured response-00/F1-zero path is naturally proved. Debugger stops
may affect timing. Interactive paddle/ball gameplay, two simultaneous edits,
general relocation and physical hardware compatibility remain separate gates.

# Skill Cash alpha and IRQ output pass

The continuous C721 replay now executes the recovered alpha software effects
instead of treating display streams as an opaque boundary. All **44 native calls
and 740 serial bytes** match MAME. A separate native IRQ output adapter matches
**6,103 scan calls and 6,103 pulse-width helper calls**. The diagnostic app exposes
the alpha shadow timeline and IRQ output-port snapshots alongside feature results.

## Alpha software model

The translated subset implements reset 3D0E, stream handling 3CC0, cursor command
70, packed decimal-byte command 76, numeric commands 77/78/79 and terminating 7A.
The observed path uses 70/76/79/7A; alternate numeric widths and enabled digit
mirroring have static tests. Unsupported commands, scratch bounds and mirror
lookups outside recovered data fail explicitly.

Normal characters update a six-bit shadow cell and advance the 16-cell cursor.
Period and comma attach to the preceding cell, replacing its punctuation bits
without advancing the logical position. Serial output retains the native cursor
selection, character and punctuation bytes in their recovered order. Reset emits
19 bytes and clears the shadow. Unsigned numeric formatting preserves leading
fill, decimal placement and source width. The word formatter handles the actual
bank/display sum; it is not a generic currency formatter added by the UI.

`alpha-calls.json` checks cursor, control, stop flag, shadow bytes, digit mirror
state, stream continuation and each emitted byte against native entry/return
observations. Continuous feature execution additionally checks source credit,
pending/current win and display memory for each call. The original 98,704-dispatch
VM digest still matches. Initial shadow/digit context is recorded before the first
reset; later states are calculated continuously.

Alpha-frame clock/timer values displayed in the app are captured native observations.
They are not timings calculated by a serial-wire or CPU-cycle simulator. The UI
shows the software shadow in cursor order with punctuation attached; no claim is
made about the cabinet VFD's physical orientation, glyph shapes or electrical edges.

## IRQ multiplexer and pulse-width control

Native 28FE advances the mux column, updates four-frame animation counters and
selects lamp and digit bytes. The adapter preserves suppress/skip branches,
unsigned column arithmetic, byte counter wrap, alternating frame bits, decimal
bits and per-digit blink masks. A canonical digest checks every return's counters,
column and six port readbacks. Sparse anchors aid diagnosis.

`output-scan.json` retains an initial state and between-call changes. Frame-memory
updates are captured inputs to this isolated IRQ proof; it is not yet connected to
the VM's full interrupt schedule. On this path only frame bytes and provenance
clock/timer fields change between scans. Counter and column trajectories are
calculated from one initial state. Seven-segment shadow data remains unchanged.

Pulse-width control is enabled (B3=FF). Native 19C2/19FA and software timer-3 arm
70EF now execute and match all 6,103 helper returns. The recorded path uses count,
reload and signed step zero with timer word 40 decimal; enabling the routine does
not establish that a visible brightness sweep occurred. Signed boundary reversal,
counter reload and wrap have synthetic/static coverage. Timer callback 48FD is
emitted explicitly. Elapsed PTM timing and execution of its inhibit callback are
not simulated; controller input state is captured per helper call.

PIA control bits 7/6 are read-only interrupt status. Preserving the observed flags
was necessary for exact scan readbacks. This is supported by the measured path
and cross-checked against MAME's [6821 control read/write implementation](https://raw.githubusercontent.com/mamedev/mame/master/src/devices/machine/6821pia.cpp).
That source cross-check is distinct from the hash-recorded MAME 0.281 executable
used for the replay. PIA handshake polling, signal transitions and asynchronous
flag changes are not a complete device model here.

## Evidence, tests and reproduction

The alpha and pulse/scan captures reproduce the original state.csv,
feature-state.csv, input-levels.csv and ram-final.bin byte-for-byte. Curated JSON
and provenance summaries reproduce byte-for-byte. Bulky raw traces and binaries
remain in fresh external temporary directories. An earlier scan capture without
pulse observations remains outside tracked evidence; no existing capture was
overwritten. Selected saved assembly and split MAME disassembly accompany the
translations. Recovered code is not original source.

```powershell
./tools/Capture-SkillCash.ps1 -MameExecutable <existing-mame> -RomDirectory <roms> -RunDirectory <new-alpha-run> -FullFeature -NativeAlpha
./tools/Curate-SkillCashAlpha.ps1 -RunDirectory <new-alpha-run>
./tools/Capture-SkillCash.ps1 -MameExecutable <existing-mame> -RomDirectory <roms> -RunDirectory <new-scan-run> -FullFeature -NativeScan
./tools/Curate-SkillCashOutputScan.ps1 -RunDirectory <new-scan-run>
```

Forty-seven verification groups pass. Changed alpha serial bytes and lamp-frame
inputs are rejected against unchanged native evidence. Punctuation wrap, numeric
fill/mirror, alternating counters, suppress/blank branches and signed pulse-step
boundaries are static or synthetic tests, not additional captured campaigns.
The expanded WPF views have clean build verification; no interactive GUI test is
claimed. The headless projects remain independent of WPF.

Next boundaries are a shared platform schedule connecting VM execution and IRQ
output scans, timed PTM callbacks, PIA/VFD electrical behaviour, audio synthesis
and wider game paths. The recorded Skill Cash result remains level 1, pending 0,
current win 10. No installation, system configuration, commit, push or cloud
change was required; the original forensic workspace is preserved.

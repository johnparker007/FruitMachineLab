# Bounded paused IL debugger session - il-debug-log-11

Task started from main HEAD `995992e3f10fbc99068d44a3ed72709ea85b23ad`.
This is an independent early-call debugger tool. The historical `EE16/EE22`
paid-window comparison remains failed/unresolved and was not retried. No
extension range, new VM word or native C# execution work was used. This revision
repairs strict JSONL event serialization and adds strict parsing and real
serializer-escaping regression checks.

## Result

A read-only paused session now drives the supported five-node `9ED9` IL map
through the installed MAME 0.281 debugger APIs. The strict command vocabulary is
`pause-at-mapped-node`, `inspect`, `step-one-IL-node`,
`resume-to-supported-boundary` and `stop`. The automated verifier ran fresh
isolated original and repaired sessions, 17 protocol/launcher negatives and the
strict event checks:

- `tests/worker/Test-IlDebugSession.ps1`: **595 checks, 0 failures**.
- `tests/worker/Test-IlEventJson.ps1`: strict `System.Text.Json` parsing plus a
  real serializer escaping probe under installed MAME Lua 5.4.
- Curated result: `evidence/mpu4/integrity/il-debug-session.json`.
- Raw runs: `artifacts/deepseek/il-debug-log-11/test-runs/run-20261018-154248/`.
- Test log: `artifacts/deepseek/il-debug-log-11/test-run-02.out.log`.

## Strict event JSON repair

The previous `logEvent` joined fields with commas and then appended the closing
brace, so every record had a trailing comma. Its string helper also discarded
carriage returns and escaped only backslash, quote and LF; other control bytes
were written raw. The preserved `il-debug-step-10` logs are therefore invalid
JSONL. They remain unchanged as rejected review inputs and are not accepted as
evidence in this revision.

The serializer now writes separators before fields, so an empty or nil field
table still produces one valid object with no trailing comma. `jsonValue` escapes
`"`, `\`, backspace, form feed, LF, CR and tab with their JSON short forms, and
every other byte matched by `%c` (including U+0000..U+001F and DEL) as
`\u00xx`. It never drops a control byte.

The strict parser uses `System.Text.Json.JsonDocument` with
`AllowTrailingCommas=false` and comments disallowed; PowerShell
`ConvertFrom-Json` alone was not accepted as proof. Every nonblank record in the
fresh sessions parsed: original 65/65, changed 65/65 and negative 20/20, with
zero failures. The verifier checks the expected command, step, return and stop
content from the parsed records, not only file hashes.

Negative controls reject constructed trailing-comma records, raw tab/LF/CR/NUL/
U+001F/backspace inside strings, and the preserved step-10 log: all 65 of its
records are rejected. A positive control with escaped controls round-trips. The
same bounded helper extracts the serializer block from
`tools/lua/IlDebugSession.lua` and runs nine escaping cases plus empty-field, nil-
field and special-key events through actual MAME Lua 5.4. All 12 records parse
and round-trip quotes, backslashes, CR/LF, tab, NUL, U+001F, DEL, mixed controls
and a UTF-8 character. No debugger session, input replay or state seed is used
for that probe.

## Capability semantics actually established

The accepted `il-lua-api-09` API and exact-boundary evidence was reused. This
increment adds the bounded paused session and proves these points:

| Point | Observation |
| --- | --- |
| Stopped host | `-debugger windows` keeps MAME stopped at the reset-entry breakpoint. `-debugger none` auto-resumed on scheduled events at reset in a bounded probe, so it is not used for the session. |
| Command driver | `emu.register_periodic` runs while stopped and also every frame while running. The session ignores all work unless `manager.machine.debugger.execution_state == "stop"`. |
| Native step | `cpu.debug:step(1)` is asynchronous: it requests running and the next stopped callback observes the next instruction. Immediate post-call PC is not proof. |
| Positive control | From a paused `00FC` callback with `Y=9ED9`, one native step stopped at `00FE`, `Y=9EDB`, with advanced emulated time. |
| Exact boundary source | Native stopped state and `cpu.debug:step(1)`. There is still no Lua instruction callback; the periodic callback is never labelled a boundary. |
| Reset hold | The session reads the reset vector, stops at that native reset entry, then waits for commands. The CLI first issues `pause-at-mapped-node`. |

The session never writes PC, registers, RAM, ROM, save states or the VM stack.
It sets only the reset-hold breakpoint and the requested node breakpoint, and
clears them after use. IRQs are not masked or suppressed; native execution is
observed and the step engine fails on a wrong mapped successor. No unexpected
stop occurred in the accepted runs.

The version-matched primary source for these semantics is MAME 0.281
`src/emu/debug/debugcpu.cpp` (`device_debug::single_step`,
`debugger_cpu::wait_for_debugger`, instruction hooks) and `src/emu/video.cpp`
(`emulator_info::periodic_check`), together with the preserved
`il-lua-api-08` `luaengine_debug.cpp`. Local private copies are under
`artifacts/deepseek/il-debug-step-10/source-mame0281/`; the Lua API source remains
under `artifacts/deepseek/il-lua-api-08/source-mame0281/`.

## Protocol and safety

`tools/Start-IlDebugSession.ps1` validates the MAME SHA256, source-map and build
report hashes, original/repaired ROM identities, the exact six-byte diff, the
handler plan, the replay hash, the input script and a fresh create-only run
directory. It copies exactly `a6ls.p1` into isolated `roms/m4addr`, uses absent
NVRAM/configuration and `-noreadconfig`, and launches the detached owned
process tree.

`tools/lua/IlDebugSession.lua` validates the map and all 14 live bytes against
the running ROM before writing `ready.txt`. Requests are strict `key=value`
files with exactly `protocol`, `session`, `sequence`, `requestId`, `nonce`,
`command` and `node`. Unknown fields, writes, arbitrary addresses/lengths,
register/PC injection and unknown commands are rejected. There is no Lua,
debugger or shell evaluation of request values.

`tools/Invoke-IlDebugCommand.ps1` allocates a monotonic sequence under a lock,
publishes the request atomically and validates the response protocol, session,
sequence, request nonce, command, acknowledgment and proof. Stale, out-of-order,
duplicate, forged, colliding and missing responses fail.

Inspect reads only PC/CURPC/X/Y/U/S, emulated time, four data-stack words and two
control-stack words. Repeated inspections returned identical state and time.
The MAME 0.281 Lua CPU state entries for this device do not expose a
`TOTALCYCLES` member; identical registers and identical `timeBefore`/`timeAfter`
emulated time are the observed no-cycle-advance evidence. The native debugger's
`totalcycles` symbol was used only by the separate accepted `09` capture.

Node resolution uses `Y` at `PC=00FC` for prefetch, and `Y=node+2` plus the
planned handler PC for handlers. Handler `X` is checked as
`tokenPointer+2 = w@node+2`, not as a generic handler-PC equality. The caller
cursor is read from the observed control stack at the `7931` return handler; it
is not a hardcoded `9F16` assertion.

## First natural 9ED9 call

Both variants used the same tracked physical-input replay, fresh isolated
directories, no state load and no injected state.

| Datum | Original | Repaired |
| --- | --- | --- |
| ROM SHA256 | `ebf580...a15c` | `577f76...5107` |
| Session ID | `38d270ec-...4091` | `99860723-...f020` |
| Pause time (emulated) | 37.076473837 s | 37.076473837 s |
| Prefetch PC/Y/X | `00FC/9ED9/9ED9` | `00FC/9ED9/9ED9` |
| Entry U/S | `066E/0796` | `066E/0796` |
| First IL operand | `FF80` | `FF00` |
| Handler entries | `795D, 7880, 795D, 7AB1, 7931` | same |
| XOR result at node 4 | `0000` | `0080` |
| Return-handler saved cursor / S | `9F16 / 0796` | `9F16 / 0796` |
| Post-return Y / S / token | `9F16 / 0798 / 75A9` | `9F16 / 0798 / 75A9` |
| MAME exit / state files | `0 / 0` | `0 / 0` |

The five `step-one-IL-node` commands advanced through prefetches
`9EDD`, `9EDF`, `9EE3`, `9EE5` and the caller continuation. Each recorded native
step count, advanced emulated time, the expected handler transition and the
mapped token. The final step observed the `7931` return handler, read the saved
cursor from `w@S`, then observed `PULS` restoring `Y=9F16` and `S=0798`; the
caller token was `75A9`. The repaired result `0080` is the map-derived
`FF00 XOR FF80`, and it was observed on the data stack.

## Negative controls

Twelve protocol negatives passed: unknown command; write field; arbitrary read
address; injected PC; step before pause; inspect before pause; stale sequence;
out-of-order sequence; missing protocol; carriage-return request; response
collision (no overwrite); and forged acknowledgment rejection by the CLI. Five
launcher negatives passed: wrong original identity, wrong repaired identity,
stale source map, stale build report and an existing run directory.

The synthetic malformed-command session is separate from the two natural
sessions. It starts at the reset hold, rejects the malformed requests, then stops
without executing a mapped node.

Strict JSON negatives are separate from the command protocol. Eight constructed
trailing-comma/raw-control records are rejected, and the preserved step-10 log is
rejected in full (65/65). These checks fail if a raw control byte, dropped CR or
trailing comma is accepted. They do not add any command, read or write ability.

## Provenance

| Datum | Classification |
| --- | --- |
| Debugger/CPU API, breakpoints, step/go, stopped state | Actual installed MAME 0.281 Lua debugger APIs |
| Instruction boundaries, handler/return transitions | Native debugger stopped state and `cpu.debug:step(1)` |
| Map/IL node operands, live-byte validation | Output-bound source map plus handler-entry plan |
| Physical input and replay identity | Existing tracked physical-input replay |
| Command protocol, sequence/nonce, hashes, negatives | Shipped PowerShell tools and test verifier |
| Strict event JSON and escaping | Actual serializer block from `tools/lua/IlDebugSession.lua`, run under installed MAME Lua 5.4; parsed with `System.Text.Json` |
| EE16/EE22 paid window | Unchanged failed/unresolved historical result |

## Limitations and capability gaps

- The OSD debugger window is required as the stopped host. `-debugger none`
  does not provide an idle stopped session at reset.
- There is no Lua instruction callback. The periodic callback is a command
  driver only; exact boundaries are native.
- Only the fixed `9ED9` five-node map is supported. There is no dictionary
  editor, arbitrary memory read, register write, state seed or save-state load.
- No extension allocation, range use, new composite word or native primitive is
  part of this increment.
- The demonstrated call is the first natural `9ED9` call with the tracked replay,
  not the later `EBCA -> 9ED9` paid-window call. The `EE16/EE22` comparison is
  unchanged.
- Strict event checks require the already-installed PowerShell 7 runtime with
  `System.Text.Json`; no installation or configuration change was made. The Lua
  serializer itself has no additional dependency.
- Physical MPU4 hardware compatibility is not claimed.

## Reproduction

```powershell
powershell -NoProfile -File tools/Start-IlDebugSession.ps1 `
  -MameExecutable E:\Arcade\MAME0266\mame281.exe `
  -RomDirectory E:\Arcade\MAME0266\roms `
  -OriginalRom <a6ls.p1> -RepairedRom <edited-repaired.p1> `
  -Variant Original -RunDirectory <fresh-run> -SecondsToRun 120 -WallTimeoutSeconds 180

powershell -NoProfile -File tools/Invoke-IlDebugCommand.ps1 `
  -SessionDirectory <fresh-run> -Command pause-at-mapped-node -Node 0

powershell -NoProfile -File tools/Invoke-IlDebugCommand.ps1 `
  -SessionDirectory <fresh-run> -Command inspect

# inspect again, resume-to-supported-boundary, then five step-one-IL-node commands
powershell -NoProfile -File tools/Invoke-IlDebugCommand.ps1 `
  -SessionDirectory <fresh-run> -Command stop

powershell -NoProfile -File tests/worker/Test-IlDebugSession.ps1 -Force
```

The full test regenerates the curated JSON and repeats the original, repaired and
negative sessions, then parses every event record strictly and runs the real
serializer escaping probe. Raw outputs stay under
`artifacts/deepseek/il-debug-log-11/`.

## Bounded next proposal

Extend the same strict session and map resolver to the other checked `9A64`
definition and verify one natural call, without extension allocation, new words
or a paid-window retry.

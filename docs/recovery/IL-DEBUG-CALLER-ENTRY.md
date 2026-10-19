# Original VM caller-entry boundary and explicit step-into

Status: **accepted natural MAME 0.281 read-only result.** Base commit
`5613467d3394012c8bfa5aba72d22bf4cba39640`. This increment adds exactly one
reviewed caller record per validated original definition and two commands. It
does not add a call stack, nesting, call-step-over, general step-out,
interrupt handling, free-run continue, save states or writes.

Evidence: `evidence/mpu4/integrity/il-debug-caller-entry.json`.
Raw private runs: `artifacts/deepseek/il-debug-caller-entry-42/`.

## Explicit caller records

The generated session map contains exactly one immutable caller record per
session. The launcher validates the record against the exact original/build
identity and live ROM words before MAME starts; the Lua session validates the
same record against the live image again before writing `ready.txt`.

| Field | 9ED9 | 9A64 |
| --- | --- | --- |
| `callerTokenAddress` | `9F14` | `EF9C` |
| `callerToken` | `9ED7` | `9A62` |
| `calleeHeaderAddress` | `9ED7` | `9A62` |
| `headerValue` | `00F8` | `00F8` |
| `calleeBodyStart` | `9ED9` | `9A64` |
| `calleeBodyEndExclusive` | `9EE7` | `9A72` |
| `callerSuccessor` | `9F16` | `EF9E` |
| `postReturnToken` | `75A9` | `80C4` |

Checked relationships: `calleeHeaderAddress + 2 = calleeBodyStart`,
`callerTokenAddress + 2 = callerSuccessor`, and the live words at the caller
token, header, successor and first body token equal the record. A tampered
session map fails closed with `map_caller_token` before ready; a wrong/stale
image still fails the launcher's identity checks first.

## Commands

| Command | Preconditions | Effect |
| --- | --- | --- |
| `pause-at-caller-token -Caller 0` | initial stopped state, or a paused `post-return` rearm | Arms a native breakpoint at `PC=00FC` with `Y=callerTokenAddress`; stops at `boundaryPhase=caller-prefetch` and validates the live caller token/successor |
| `step-into-mapped-call` | paused at `caller-prefetch` only | Executes exactly four native instructions and stops at the callee first IL prefetch (`node 0`) |
| `inspect` | paused, including `caller-prefetch` | Read-only register/stack/time and caller/callee fields; repeated inspection does not advance |
| `stop` | initial, paused or error | Schedules MAME exit |

`step-one-IL-node`, `resume-to-supported-boundary`, return handling, branch
semantics and post-return rearm are unchanged. `step-one-IL-node` at a caller
prefetch is rejected with `step_into_required`; caller pause from a body
boundary is rejected with `wrong_phase`; step-into from a body or post-return
boundary is rejected with `not_caller_boundary`.

## Exact four-instruction entry chain

| Step | Instruction | Required stopped state |
| --- | --- | --- |
| 1 | `LDX ,Y++` at `00FC` | `PC=00FE`, `X=callerToken`, `Y=callerSuccessor`, `U`/`S` unchanged |
| 2 | `JMP [,X++]` at `00FE` | `PC=00F8`, `X=calleeBodyStart`, `Y=callerSuccessor`, `U`/`S` unchanged |
| 3 | `PSHS Y` at `00F8` | `PC=00FA`, `S=callerS-2`, `w@S=callerSuccessor`, `U` unchanged |
| 4 | `LEAY ,X` at `00FA` | `PC=00FC`, `X=Y=calleeBodyStart`, live first token, `U` unchanged |

The success response is `kind=call-entered`, `proof=boundary_reached`,
`steps=4`, `transitionCount=4`, `toBoundaryPhase=prefetch`, `toNodeIndex=0`,
`savedCursor=callerTokenAddress+2`, `entryDeltaS=0002`,
`entryU=entryUAtBoundary`. Any other PC, `X`, `Y`, `S`, saved cursor, token or
data-stack value fails closed; an interrupt diversion therefore surfaces as a
failed entry, not as a supported boundary.

## Natural observations

### 9ED9 original and changed

Fresh isolated original and the accepted repaired image both used the tracked
physical replay. The first natural call paused at `PC=00FC`, `Y=9F14`,
`S=0798`, `U=066E`; step-into reached `PC=00FC`, `X=Y=9ED9`, token `795B`,
`S=0796`, saved cursor `9F16`, then the existing flat node steps reached the
actual post-return `Y=9F16`, `S=0798`, token `75A9`. The original observed
result remained `0000`; the changed operand `FF00` observed `0080`.

### 9A64 original

The first natural call paused at `PC=00FC`, `Y=EF9C`, `S=07AC`, `U=066C`;
step-into reached `PC=00FC`, `X=Y=9A64`, token `7B6D`, `S=07AA`, saved cursor
`EF9E`. The existing nonzero `7982` path, unconditional `7979` branch, return
and post-return (`EF9E`, `S=07AC`, token `80C4`) were unchanged. The separate
zero-target session remains the prior natural zero-path observation.

## Negative controls

Passing controls include: caller index out of range (`caller`), caller field
missing (`caller_required`), step-into before pause (`wrong_phase`), step-into
from body and post-return (`not_caller_boundary`), pause-at-caller from body
(`wrong_phase`), tampered caller map (`map_caller_token`), unknown
command/field, stale/out-of-order sequence, nonce/request binding mismatch and
response collision. Existing strict-JSON malformed-input controls also pass.

## Verification

| Verifier | Actual result |
| --- | --- |
| `Test-IlDebugSession.ps1` (9ED9 original + changed + negatives) | **813 checks, 0 failures** |
| `Test-IlNineA64DebugSession.ps1` (9A64 original + zero path + negatives) | **253 checks, 0 failures** |
| `Test-IlDebugCommandDelivery.ps1` | **74 checks, 0 failures** |
| `Test-IlEventJson.ps1 -Mode Negative` | **9 controls, all rejected; positive round-trip accepted** |

All sessions used the installed MAME 0.281 `-debugger imgui -video bgfx`
frontend with the tracked replay, with no PC/register/RAM/ROM seeding,
save-state load, debugger write, retry or configuration change. MAME exited
`0`; the isolated run ROM matched its input hash; state directories were empty.

## Limitations

- Only caller records `9F14` (9ED9) and `EF9C` (9A64) are supported. Other
  listed callers, their containing definitions and call depth are not modelled.
- No nested/recursive call stack, call-step-over, general step-out from an
  arbitrary node, free-run continue, interrupt-aware boundary or arbitrary
  breakpoint.
- No writes, save-state loading, register/RAM/PC seeding or speculative input.
- Physical MPU4 hardware compatibility is not claimed.
- Composite `1010` natural execution and extension allocation are untouched;
  the accepted composite result from tasks 40/41 is not re-run here.

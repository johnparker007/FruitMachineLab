# Supervised DeepSeek dispatch

## Active project mandate — 18 October 2026

Read [the current roadmap](../../docs/PROJECT-ROADMAP.md) and repository AGENTS.md
before choosing any task. Native C# execution is frozen indefinitely; old
IRQ/sound/gameplay task files, gates and durable nextTask values are historical
and must not automatically trigger dispatch. Preserve checkpoints and evidence.
This documentation pivot does not restart workers or schedules.

Future authorized work targets lossless original-VM IL, ROM compilation and
MAME Lua debugging. Review the replacement plan with John before implementation
dispatch, and scope each task to explicit files, evidence and acceptance.
Historical commit/push permissions are not current authorization. The runner
mechanics below remain available; examples are not instructions to start a run.

From the repository root, invoke:

```powershell
pwsh -NoProfile -File tools/worker/Invoke-DeepSeekTask.ps1 -TaskId pilot-01
```

Uses installed OpenCode `run --pure --format json --model ... --file ...` help
(1.19.3). No installation, configuration override, auto-approval, provider
fallback or automatic restart. Existing permission prompts remain authoritative;
noninteractive denials are blockers, never permission to try another wrapper.

One exclusive local lock; create-only run directory; progress-aware supervision;
process-tree termination on a watchdog stop; zero automatic retries.
Raw local events and durable state go under ignored `artifacts/deepseek/<id>`.
Treat raw logs as private local material; do not publish credentials or bulky
context. A successful process exit is **not** task success. Review tool events,
final report, actual diff and independent build/verification before acceptance.
Process timeout and the agent step limit do not cap API dollars or tokens. No
hard monetary cap is claimed.

## Durable state while running

`state.json` is replaced atomically (same-directory temp file + replace). It
records the task, process ID/name, runner PID, start/deadline times, last event
time/type/short summary, last stderr summary, event/parse counts, report size and
the final review state. `events.jsonl` and `stderr.txt` are appended and flushed
line-by-line while the worker runs, so a timeout or runner failure does not lose
already-produced output. Summaries never contain raw tool output or credentials.
There is still one writer. A run directory is never reused; dispatch does not
retry automatically. Normal dispatch failures finish with `dispatch-error`, not
a stale `running` state.

Runner terminal states:

- `needs-review`: a terminal `step_finish` with reason `stop` and a final text
  event are present, with no structured permission/provider error. This is not
  acceptance; it only hands the run to the supervisor.
- `incomplete`: missing final result, missing terminal stop, step-exhaustion
  text, malformed event JSON, or a parent process that exits while a descendant
  still holds the output pipe open (`output-pipe-open`). Presence of a report
  file or final event is not passing acceptance. Pipe-drain detection does not
  kill unrelated processes.
- `blocked`: nonzero process exit, structured tool permission rejection, provider
  error, or an OpenCode error on stderr.
- `stalled`: no activity or no milestones within the configured interval.
- `interrupted`: a command cap or hard task deadline fired. The precise reason
  survives truncated JSON and kill errors. This is incomplete work requiring
  supervisor review, not evidence of a semantic implementation failure.
- `dispatch-error`: the runner failed before or during normal dispatch.

Permission/provider detection parses structured tool `state.status = "error"`
events and top-level error events. It does not scan historical text returned by a
successful tool call, so quoted phrases such as "rejected permission" are not
treated as live failures.

## Watchdog and advisory progress

`TimeoutSeconds` is a soft planning budget (default 1200 seconds). Passing it
does not kill a productive worker. `HardTimeoutSeconds` defaults to 10800 seconds
(three hours) and cannot be extended by progress. Silence outside a declared
command is limited to `IdleTimeoutSeconds` (900); activity without a completed
tool or changed phase/milestones is limited to `MilestoneTimeoutSeconds` (1800).
A declared quiet command receives a `CommandTimeoutSeconds` lease (1800), in
place of those two shorter checks, bounded by the task hard deadline. Reusing
its ID cannot restart its lease. These are safety limits, not proof of a hang.
CPU usage alone cannot prove useful work. Very long commands need a separately
reviewed limit or a supported division into smaller commands.

Every dispatch automatically attaches a generated supervision contract requesting
atomic `progress.json` updates with task ID, phase, completed milestones, optional
estimated percentage, next action and an active command's stable ID/purpose.
Percentages and timestamp-only rewrites do not refresh milestones. Reported
progress is advisory, never verification or acceptance. Completed tool events
also refresh progress independently of the file. A model blocked inside a tool
cannot update the file; it must declare the command before starting it.

The runner checks every two seconds, persists watchdog state and force stops its
process tree on a stop decision. The compact status includes `watchdog`, the
progress snapshot and both deadlines. Callback checks should read this once;
they must not kill a worker merely because its soft budget has elapsed.
After interruption, review partial changes/logs and the remaining boundary.
Only a supervisor may authorize a fresh, bounded continuation with a new task ID;
never automatically retry or mark the interrupted work accepted. Preserve real
failure counts; a resource interruption alone is not a semantic failure.

No-API checks:

```powershell
pwsh -NoProfile -File tests/worker/Test-WorkerWatchdog.ps1
pwsh -NoProfile -File tests/worker/Test-DeepSeekWorker.ps1
```

## Reading compact status

```powershell
pwsh -NoProfile -File tools/worker/Get-DeepSeekStatus.ps1
pwsh -NoProfile -File tools/worker/Get-DeepSeekStatus.ps1 -TaskId gate-28
```

One call reads `artifacts/deepseek/orchestrator-checkpoint.json` once and prints
one compact JSON object. It performs no model/API request, dispatch, restart or
state mutation. It emits `status`, `boundary`, `gate`, `attempt`, `nextTask`,
`reviewedTask`, `stopreason`, checkpoint metadata, the selected task, the last
reviewed run separately, process ID/liveness, deadline/remaining time, lock state
and review state. It never includes raw event or report text.

Without `-TaskId`, checkpoint `nextTask` is authoritative. A stopped checkpoint
with a null `nextTask` reports `STOPPED` and keeps `currentTask` null, so an old
latest run is never presented as new active work. A missing or malformed
checkpoint produces a `CHECKPOINT-MISSING`/`CHECKPOINT-MALFORMED` diagnostic and
does not dispatch anything. The latest-run fallback applies only when the
checkpoint is absent and the legacy status document is clearly historical; that
fallback is marked `legacy-latest` with `authority: none`. `-TaskId` is an
explicit override and works even when the checkpoint is absent or malformed.

Supervisors may use the exported `Write-WorkerCheckpointAtomic` helper, which
reuses the atomic state writer and refuses a worker-declared `acceptance =
accepted`. The worker scripts never write the checkpoint and cannot authorize
their own acceptance.

`liveness` distinguishes:

- `running`: process alive, deadline not reached;
- `overdue`: process alive but deadline passed;
- `dead`: state says running, process is gone, but the writer lock is still held;
- `stale`: state says running and both process and writer lock are gone;
- `stopped`: the run has a terminal state;
- `no-run`: no run state was found.

## Tests

Deterministic local tests use a fake `opencode.cmd`/`git.cmd`, a fresh ignored
temporary root and no API/model call:

```powershell
pwsh -NoProfile -File tests/worker/Test-DeepSeekWorker.ps1
```

They cover complete/incomplete reports, step exhaustion, nonzero exit,
permission versus quoted historical text, provider errors, malformed JSON,
incremental state/output, stale/dead/live status, create-only refusal and
process-tree timeout termination (the timeout case takes about 30 seconds).

Supervisor records a compact reviewed report in docs, including task hash,
commands, exits, evidence classes and boundary. One writer at a time. Preserve
pre-existing changes and inspect protected files after every run. Stop on missing
evidence, verification regression, permission denial or provider error. Watchdog
interruptions stop the current run and require review of partial evidence before
any continuation; they do not alone establish a semantic failure. A supervisor
may authorize a revised task using a new ID within John's current scope; after
two actual failures at the same semantic boundary stop. Never let the runner
automatically dispatch the next batch. A batch must name allowed files, original evidence, acceptance
comparison and explicit unsupported boundaries. No commits/pushes/publication.

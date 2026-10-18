# Supervised worker checkpoint — 17 October 2026

## Current planning checkpoint

The operational plan is now [PROJECT-ROADMAP.md](PROJECT-ROADMAP.md), section
"Restart plan: sound ownership before finish timing". John paused the callback;
no worker is running and this planning update does not unpause or restart it.
Last accepted commit before planning is `0fe3713`, full intended snapshot384groups.
DeepSeek completed reviewed ROM/startup, VM-definition and capture-policy work;
those commits were pushed under John's subsequent authorization.

Fresh worker runs use1000steps; the current dispatch tasks have a20minute timeout,
zero automatic retries and a two-unsuccessful-attempt stop rule. Steps are not
retries or a monetary cap. Commit/push review remains with ORCHESTRATOR, even
though John authorizes it. Broad worker shell/external access does not override
preservation, no-installation or no-unrelated-configuration rules.

Gate 1 is now certified under the resumed revised plan: the preserved FEC9
wrapper has fresh isolated original-ROM captures with recorded initial registers,
full 2 KB RAM, every instruction boundary and the fixed FECC continuation.
Natural scheduler-a/b remain an empty-return comparison only. Missing-region,
corruption and wrong-return controls pass in the intended snapshot. Gate 2 is
also certified for one headless native tone owner: actual 59EB is queued through
5C18 into the real 0047/0049 list, served through two explicitly timed 5CD0
ticks to the CE wait, then cancelled by 5C7A with captured channel/tail/rhythm
state. Entry PC/source/interval is now checked explicitly, and declared caller
writes are limited to registers/return word0700, counter0044, enable719B and
clock0045/0046; no other intermediate RAM edit is permitted. Only the initial C6
sentinel and zero-count C4 loop are covered; active-channel/finite-count variants
are rejected. Natural nudge-tone supplies only the command order. No timer1
cadence, outer IRQ, finish CPU work or Live ownership is claimed; Gate 3 remains
open.
Tone finish remains separately blocked on real native task ownership in Live; do
not manufacture that state to fit a cost. See the roadmap for the five gates
and exact acceptance/stopping conditions. Raw captures remain untracked; the
curated fixtures are `evidence/mpu4/collection/timer1-scheduler-call.json` and
`evidence/mpu4/collection/tone-lifecycle.json`.

The notes below are the historical pilot checkpoint. Statements such as "no
implementation batch" describe that earlier checkpoint, not current project state.

## Historical pilot checkpoint

Local runner: `tools/worker/Invoke-DeepSeekTask.ps1`; operating rules in its
README. Task files and ignored durable event/state logs are implemented.
Existing setup document and project configuration were already untracked when
work began. No game code or verification expectations changed.

John approved local shell and external-directory access for the DeepSeek worker.
Root OpenCode configuration now allows both; protected edit paths and disabled
sharing/updates/LSP/formatters remain. Command access is broad, not an OS sandbox;
task instructions still prohibit installations, unrelated configuration changes,
commits, pushes, publication, credential reads and destructive operations.

Pilot-01 failed argument parsing before a model run; corrected message placement
before the array-valued file option. Pilot-02 connected, read documents and hit
the old shell ask policy. Pilot-03 ran with the then-approved two-command policy:

- Headless build, `--no-restore`: exit 0, zero warnings/errors.
- Existing verification executable, `--no-build -- .`: exit 0, 357 groups passed.
- Subsequent `git status --short` was automatically denied by that old policy.
  No completed planning proposal was emitted; pilot remains blocked overall.

The supervisor inspected actual JSON tool outputs, including exit codes and the
suite summary. An earlier independent supervisor run also passed 357 groups.
These establish the existing baseline, not new recovered semantics or new MAME
captures. No implementation batch has been dispatched. Permission failures were
not worked around; broad permission approval arrived while pilot-03 was running
and applies to fresh runs. Stop here after repeated permission-boundary failures.

Next fresh supervised task should complete the smallest-boundary proposal and
inventory local MAME automation, permitted paths, isolation and evidence needs.
Then dispatch one implementation batch with explicit files and independent
acceptance comparisons. Keep heavy analysis/build/capture/testing in DeepSeek;
ChatGPT reviews compact reports, relevant diffs and actual verification evidence.
No full-game, autonomous scheduling or physical hardware claim is established.

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

The next planned gate is independent certification of the preserved FEC9 wrapper,
including complete ROM fixtures and independently captured initial-frame state.
It requires explicit resumption of the revised plan; do not retry based solely
on a timer wake-up. Tone finish is separately blocked on real native sound task/
channel/rhythm/tail ownership in Live. Do not manufacture that state to fit a cost.
See the roadmap for five gates and exact acceptance/stopping conditions.

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

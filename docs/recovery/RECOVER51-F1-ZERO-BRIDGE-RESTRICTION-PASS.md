# Recover51 F1=0 bridge restriction pass

## Outcome

`AddersToneSetupExecution.ExecuteFromVmEntry` now supports only the captured
`F1=0` branch. A nonzero `F1` is rejected with `NotSupportedException` during
preflight, before any RAM write or callback. The former `writeMode` delegate
parameter and its `8A01/97F1/B7080C` execution path are removed, so a caller
cannot certify the mode branch by supplying a hardware owner.

The `F1!=0` bytes and their source cost remain a **static deduction only** in
`AddersToneSetupTiming` and the curated bridge fixture. They are not executed,
not runtime-verified and not part of this component's contract.

## Supported branch and preflight

The accepted path is the actual VM entry `PC=00FC`, `Y=FC4D`:

- `AEA1` loads `80A4` through `Y++`; `6E91` dispatches through the
  `80A4/80A6` word header to `776F`.
- Preflight checks `00FC AEA1 6E91`, the `80A4` token target, the `80A6`
  native target `5A14`, and the selected bridge words
  `96F1/2707/3420/AD94` at `776F/7771/777A/777C`.
- Shared setup validation still checks the same `Machine` owner, servicing,
  pause, fault, cycle, stack, tone gate, active task and free-pool head.
- The `F1=0` decision is checked before all memory writes. Only then does
  `776F` take `2707`, push `Y`, write `07A6/07A7=777E`, call `5A14` and write
  `07A8/07A9=FC4F`.
- The existing wrapper, `5C18` queue owner and `59E9` return run unchanged on
  the same `Machine`. No second seed or captured delta application is used.

## Negative control

`bridgeMode` now sets `F1=0x80` and must fail at the `F1!=0 mode branch`
preflight with the pre-rejection 2 KB RAM image unchanged. The existing
`stack`, `gate`, `ownership`, `owner`, `servicing`, `paused`, `pool`,
`poolPointer`, `vmTemplate`, `vmToken`, `vmHeader`, `vmNative`, `missingROM`
and `snapshot` controls remain. The verification group also asserts that
`ExecuteFromVmEntry` exposes no `Action<byte>` callback.

## Evidence

No new capture was taken. The path uses the existing original-ROM bridge bytes,
`collection/tone-setup-bridge-data.json`, the fresh natural oracle31
`collection/fresh-tone-occurrence.json`, and source-derived
`M6809InstructionTiming` plus `AddersSoundQueuePlan`. The `5A14` marker,
`5A05` marker, full 2 KB queue frame and 16-entry foreground delta are compared,
not applied.

## Files

- `src/FruitMachineLab.Adders/AddersToneSetupExecution.cs`: F1=0 preflight,
  removed callback, selected branch only.
- `src/FruitMachineLab.Adders/AddersToneSetupTiming.cs`: static branch
  deduction comment, no runtime claim.
- `src/FruitMachineLab.Adders/AddersToneSetupVerification.cs`: `bridgeMode`
  negative and preflight error stage.
- `tests/FruitMachineLab.Verification/Program.cs`: no-callback assertion in the
  existing setup negative group; group count remains `409`.
- `docs/recovery/RECOVER50-VM-FOREGROUND-BRIDGE-PASS.md`: corrected limits.
- `docs/recovery/RECOVER51-F1-ZERO-BRIDGE-RESTRICTION-PASS.md`: this report.
- `evidence/curated-manifest.json`: own entries only.
- `artifacts/deepseek/recover-51/`: result, logs and exit files.

## Commands and exits

- `dotnet build FruitMachineLab.Headless.sln -v:minimal` -> exit 0.
- Focused `Foreground5A14` run -> exit 0, 3 groups passed.
- Full headless suite -> exit 0, 409 groups passed.
- `pwsh -NoProfile -File tools/Update-CuratedManifest.ps1 -Verify` -> exit 0.

## Limits

The `5A05/5A07/7159` wait, `5A0A..5A12` finish, first `5CD0` service, IRQs,
timer1 cadence, Live integration, audio and a continuous lifecycle remain
outside this slice. The `F1!=0` mode branch has no independent runtime evidence
and remains unimplemented. No full CPU flag state or fitted historical budget is
claimed. No installs, configuration, credentials, subagents, commits or pushes
were made.

## Next task

Extend the same-machine foreground owner through the `5A05/5A07/7159` wait or
the first `5CD0` service, only after the inter-service foreground/IRQ deltas are
attributed. Do not infer timer1 cadence or Live ownership from this bridge.

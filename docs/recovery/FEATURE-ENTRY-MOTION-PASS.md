# Paid feature entry motion and board selection

16 October 2026. Live now runs native61CF feature-entry motion, animates the
board lamps and returns to a genuine board-selection prompt. Physical START
can launch another dice roll from that prompt. Credits5/cash bank16 remain in
the generated mixed-input test, and the paid-game completed count stays zero:
this route has entered a feature, not completed the surrounding paid game.

## Natural reference evidence

Fixtures and matching verification/debugger sidecars are under
evidence/mpu4/skill-cash. Raw traces and ROM binaries remain external.

| Fixture | Boundary | VM observations | Lamps | Sound commands |
| --- | --- | ---: | ---: | ---: |
| paid-flag-motion | E3AE → E443 | 11936 | 439 | 88 |
| paid-flag-board | E443 → DD38 | 144 | 9 | 0 |

Both captures complete with process exit0 and no debugger expression errors.
They use the preceding121 physical-input campaign and no state injection.
Entry signatures match the previous fixture's terminal signature. VM signatures,
random state, stacks/frames, accounting, software reel requests, lamp frames and
sound commands are compared. These windows emit no alpha bytes; subsequent
Live prompt text comes from the existing recovered display path.

The motion fixture includes1232 native observations through64F0 cleanup. Its
reference adapter runs the translated profile/motor/cleanup code and generates
optic readings through AddersReelHardware; captured motor outcomes and optic
values are not assigned into the executing machine. Idle6403 observations have
no motor work and are skipped after their reference service-clock advance.
The adapter retains existing explicit CPU/IRQ clock and peripheral boundaries.
The same physical campaign was captured independently:1232 selected native
PC/flag/drive/record/NVRAM/checksum observations agree. The independent digest
and raw source hashes are in paid-flag-motion-native.json. This is selected
state reproducibility, not complete electrical or cycle-exact CPU equivalence.

The natural windows start on a later credit2 paid game with bank16, as in
FLAG-FEATURE-ENTRY-PASS.md. The generated mixed-input Live route uses credit5
and its own state. Bounded natural equivalence and generated Live integration
remain distinct claims.

## Mechanics and preserved behavior

Token8120's byte-checked dictionary gateway calls61CF:

```text
61CF  86 01  LDA #01
61D1  97 6B  STA <6B
61D3  20 21  BRA 61F6
```

The shared61F6 entry clears stop streams0158..015F before6287 profile setup.
Unlike61D5, this entry does not install default reel-stop sound streams.
Existing6228/623A activation, IRQ6403 service,656B optic handling and649D cleanup
execute unchanged. Native61CF consumes no VM data cells. Normal asynchronous
mode is covered; synchronous bit08 and motor-disabled configuration behavior
remain explicit unsupported paths.

The natural main-reel requests are11/14/17, fourth request0. Physical positions
change78/54/78/48 →12/66/72/48. E3A3 queues88FC, runs two shrinking rectangles at
the selected square via BB49/BAD9, then E3D8 waits for real motor completion.
Record9C44 contains pointer72BF to48 lamp IDs. This static data is exported by
Curate-NudgeData.ps1 rather than copied from observed output.

BB4C allocates ten uninitialised local bytes. BAF6 initializes bounds/previous
edges before drawing uses them. VM comparison excludes frame-word offsets0/1
only until their first writes at BB14/BB1A respectively;78 ordinal masks cover
the two allocations. Actual VM memory is not zeroed, patched or loaded with
captured residue. Raw dispatch hashes retain the excluded values. Other native
CPU-stack footprints remain incomplete. These comparison exclusions extend
the existing ordinal-mask convention rather than claiming complete stack proof.

E443 re-enters DE75/DDF3 with zero movement, refreshing the existing selection
route. The natural terminal is DD38, square0/pot1. Live's generated campaign can
have a different pot; it computes its own state. The E3AE artificial stop is
removed only after the selected motion and return are verified. Other unsupported
board result and special-feature guards remain intact.

## Live integration and verification

Feature-entry motion uses the shared virtual IRQ/motor services. Pause suspends
VM execution, machine memory and virtual time; Resume continues the same motor
state. A diagnostic flag identifies asynchronous entry motion even after the VM
has returned from61CF and started drawing lamps. Later board rolls are no longer
labelled as paid spins merely because the outer paid game remains open.

The mixed-input regression preserves its earlier ordinary-nudge position check
at EE16, then checks feature-motor Pause, unchanged bank/credits, counter debit
and complement bytes, the returned prompt and prompt Pause. A real START pulse
through the recovered input scan launches and completes another dice motor
movement without an extra credit debit. This last roll is a generated integration
experiment, not a new natural reference window or a claim that its subsequent
board outcome is supported.

The real-time WPF nudge mode exercises the returned prompt and asynchronous
motor Pause. A first GUI attempt missed the motor's brief E3AE dispatch window;
the indicator/check now follows the entire asynchronous motion. The corrected
GUI mode passes, along with the other seven live/playback modes. Rendered
feature-motion and returned-prompt screenshots are saved in the external smoke
directory. The headless suite has190 verification groups; both solution builds
have zero warnings/errors.

For focused iteration the verification executable accepts an optional second
argument containing a test-name substring; no matches fails explicitly. The
normal complete command remains:

```powershell
dotnet build FruitMachineLab.sln --no-restore
dotnet build FruitMachineLab.Headless.sln --no-restore
dotnet run --project tests/FruitMachineLab.Verification --no-build -- .
```

## Reproduction and preservation

Use the preceding paid-flag-bootstrap capture flags with PaidFlagMotion to
capture E3AE→E443; add PaidFlagBoard for E443→DD38. Each verification sidecar
retains the full exact capture flags, campaign/input hash and debugger script.
Curate with Curate-BoardLink.ps1 using those same flags. Curate-DiceMotion.ps1
`-FlagMotion` selects61CF through cleanup and removes the same lifted local
release/typed scheduler dispatches from its ordinal numbering. Its optional
IndependentRunDirectory compares the repeated capture. All three accepted
attempts are appended to paid-result-capture-attempts.json.

Export-MameDisassembly.ps1 now exports feature-motion-entry.txt. The existing
nudge-encoding checkpoint byte-checks161 selected VM spans and1641 native
instruction records, preserves8120's gateway and61CF bytes, and links code to
fixtures. Updated E3A3 purpose/semantics and local-frame facts are also exported
in the existing maps. This is not lossless full-ROM coverage. Existing Ghidra
exports remain preserved; no live Ghidra export API was available for new symbol,
comment/type or cross-reference exports. Reassembly/editing stays deferred.

Next broaden the newly re-entered board's playable results and return paths using
targeted natural captures. Retain the existing three-consecutive-paid-games
regression; neither that generated route nor this feature-entry route constitutes
hundreds of complete games, startup recovery or collection support.

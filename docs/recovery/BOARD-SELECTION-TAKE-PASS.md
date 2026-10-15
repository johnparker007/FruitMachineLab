# Board selection and the live Take Feature route

15 October 2026. Live now starts by default at the recovered square-32 selection
prompt. Press and release **TAKE FEATURE**, then use **START** for Skill Cash's
three selections. Execution returns through the real board callers and completes
at E460. The mode selector retains direct C721 entry and taken-result E2FC entry.
Playback/scrubbing remains separate.

This is a larger playable boundary, not full machine play. It does not yet execute
the preceding ladder animation, roll a new dice result, start a paid spin, or retain
state across complete games. START at the board prompt follows the actual roll
branch and stops before DD81/native 2C71 with an explicit dice-motion boundary.
No choice or reel result is substituted. Restart remains available after this stop.

## Physical input and UI

The ROM input table at 71AA maps selector 1C to masks 00,00,00,01 and selector 12
to 00,00,00,80. The MAME input inventory independently names BLACK2 bit 01 as
Collect / Take Feature and bit 80 as 1 Player Start. Both are active-high levels.
DD38 samples selector 1C with feature availability, selector 12 for Start, and its
timer/option conditions. It later checks the accumulated Start latch before taking
the feature or rolling. These are recovered checks, not a UI branch into Skill Cash.

Mpu4PanelInput exposes independent momentary Take and Start levels through its
existing mux sample and OR/AND latch accumulation. Releasing a button removes its
physical level; it does not silently erase sticky ROM latches. The WPF Take control
handles mouse down/up, capture loss, keyboard Space/Enter, focus loss, window
deactivation, Pause, completion and faults. It is disabled once selection returns.
Other panel inputs remain idle. Hi/Lo selection is mode/option gated and is not
enabled by this fixed-prerequisite fixture.

## Natural capture and comparison

Capture-SkillCash.ps1 -FullFeature -BoardSelection -NativeSound -NativeAlpha
-NativeLampFrames -NativeInput -CpuInterrupts runs the unchanged physical-input
campaign in fresh isolated MAME folders. An additional guarded breakpoint observes
DD38 with C9=32, logs that dispatch and saves the 2 KiB RAM boundary. Setup callback
accounting preserves the campaign's physical input times. Capturing continues to
E460. No RAM, ROM or register injection is used in this run.

Curate-BoardSelection.ps1 checks the original full C721 body's 98,704-dispatch,
25-field SHA256 unchanged. It retains sparse platform phases and input observations,
selected anchors, native output hashes, initial RAM and capture provenance. Bulky
raw traces remain outside the repository. Curate-BoardSelectionData.ps1 extracts
selected tables, prompts, records and sound streams from the SHA1-checked ROM.

BoardSelectionVerification checks 99,843 exposed VM dispatches, 7,331 lamp requests
and resulting frame buffers, 6,099 sound commands, 1,107 alpha serial bytes and 868
actual input-condition reads. The reference replay supplies captured tick/IRQ/latch,
physical-port and native sound phases. Enqueue timing is observed at 5C46; reset
timing uses the actual choice-clear write at 5B80. Using native routine entry alone
misses IRQ work inside those routines. Live uses no captured player events.

### Explicit comparison exclusions

The broad VM signature normalizes only **uninitialized local bytes** in its frame
word at C726,C728,C72A,C72C,C72E,C730,C732,C637,C63A,C63C (whole word) and C63E,C640
(high byte only). At C63C the ROM writes the low byte; at C640 it clears the high
byte. Prior contents are dead stack residue, and native scratch/IRQ stack writes
are not fully reproduced. The runtime leaves its actual RAM untouched; it does not
inject 99A5 to manufacture a match. These 12 observation masks are explicit in the
fixture. The original C721 source digest is independently checked before masking,
and its existing standalone reference replay remains unchanged.

The 76BD local-release dispatch is lifted inside VmControlStack.Return, as in the
previous pass. The broad replay therefore verifies a normalized signature, not
complete CPU/RAM equivalence. Existing captured CPU pacing and repeated IRQ timing
adapters remain provisional, including their phase when starting at this earlier
boundary. Electrical output and audio synthesis are still outside the models.

## Runtime continuation and preserved state

ScriptExecutor.BeginResumed starts at a decoded instruction while retaining the
whole owning listing for branches. On return it follows the actual physical S-stack
cursor through RecoveredScriptCatalog's address ownership map. This resumes DD38's
captured DDAF/DE75/E43D callers; E43D then derives and dispatches E2FC normally.
Calls into C721 and its return use the same interpreter and machine state. The
outer E43D return is replaced by the explicit BEEF boundary sentinel. Unknown
continuations or duplicate address ownership fail rather than guessing a target.

The initial sound task is restored from captured native task memory: its callback
is 5D3B, cursor equals its original stream, and its task stack is empty. The new
restoration path rejects other shapes; it does not decode untyped nested sound
frames speculatively. Commands DB/DD consume their native table/register operand;
their YM register effects remain outside sound timing, as with C5. New lamp stubs
and the three-lamp reel-group clear are checked by the native lamp-frame digest.

On ordinary square-32 exit, E3E2 resets the alpha after award transfer. A blank
completed alpha is therefore expected; the accounting display retains current win.

## Checks and next work

87 headless verification groups pass. All six default award levels complete through
all three entry modes. Tests also cover independent Take/Start sampling, release on
Pause, saved physical-frame continuation, rejected scheduler shapes and the real
roll branch reaching its explicit boundary. Headless and isolated WPF builds pass;
Live, accelerated jackpot and recorded-playback smoke modes pass. Board prompt,
feature and minimum-size renders were inspected.

Next recover the dice path B271/B1D0/B1FD and native reel request/motion/symbol
handling, then DDF3 movement and DBC4 ladder/snake dispatch. That is needed before
claiming a playable continuing board loop. Use John's existing FML tooling for
layouts when those references become relevant; do not build another importer.

No installations, machine configuration changes, cloud setup, commits or pushes
were performed. The original forensic workspace is preserved.

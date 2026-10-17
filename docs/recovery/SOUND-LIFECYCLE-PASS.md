# Sound task lifecycle recovery

Collection checks native0047 while the existing choice scheduler has a separate
logical list. Do not fabricate0047. This pass recovers bounded memory effects.

Capture-SoundLifecycle.ps1 / Curate-SoundLifecycle.ps1 export48 synthetic
original-ROM masked-IRQ calls:16 each release5E2C, cancel5C7A, root C0 return5E6D.
Inputs are constructed valid channel lists, not natural gameplay. Elapsed cycles
are retained as evidence only. ROM regions are checked against a6ls.p1 SHA1
402d1518bb78fdc489b06c2aabc771e5ce151847; no lossless disassembly claim.

AddersSoundLifecycleMemory.ReleaseChannels implements5E2C/60AB memory effects.
Y selects a25-byte record in1A0..259 (stride25). Task+A owns a signed-terminated
channel chain through27E..283. Task+11 rhythm ownership clears those bits in
cache register0E; task+F clears. Released channels lose key-on bit10 in cached
register20+id and append to free head4B/tail4C. U is preserved by native code.
Optional YM callbacks report changed cache values only, without synthesis/timing.

All16 release cases compare RAM excluding caller-owned native stack6F0..701.
Invalid pool/channel chains are rejected before mutation: synthetic fault guards,
not inferred ROM corrupt-list behaviour. Historical native/5e2c.json annotations
remain linked; fresh synchronized Ghidra export is unavailable.

Excluded raw capture76ba2833bcc14407b77737ea605eac5b had an invalid debugger
assignment. Clean replacement ba60b203f3504706a7d1b21b39f13d97 is curated. Both
isolated temporary runs exited normally. Original tools/settings are preserved.

Next: cancellation/root completion, then task lifecycle ownership. Live unchanged;
the native/logical sound-list mismatch guard remains required.

## Cancellation5C7A/5CB5

Cancel now walks0047 using a predecessor LINK address (not just a task pointer),
removes the first root matching input X, pushes it onto free0049, then releases
channels. Native44 nesting guard returns to its incoming value. The disabled
719B bit80 gate60C8 does nothing; absent roots also leave memory unchanged.
Sixteen original-ROM full-memory cases pass. Separate synthetic tests cover a
middle record, duplicate roots, absent/disabled calls and cyclic-list rejection.
No timing or logical/native scheduler synchronization is inferred from these.

## Root completion5E6D

FinishRoot covers C0 only with an empty native stack (+6 == task+25), after the
due task has been removed by5CEC. It releases once at5E6D->5E2C, branches from
5E74 directly to5E85, pushes onto0049 and continues5CDE without advancing0045.
The5E83 release is alarm-fallthrough, not a second normal root release. Native44
decrement is scheduler exit5D38 and deliberately outside FinishRoot.

All16 selected root calls match RAM. A synthetic100-round test fills/drains all
six records600 times in total, checking free-list uniqueness each round. Duplicate
ownership and nonempty native frames fail before mutation. This does not yet
join logical sound frames to native records or establish complete sound playback.

## Instruction-staged release checkpoint

The capture now also observes5E2C/60AB instruction entries and adds unchanged-cache
variants:96 cases total,32 per entry. AddersSoundReleasePlan matches all32 release
paths, exact original encodings, cycle offsets, all2KB RAM including native stack,
and changed-cache notification order. Every instruction is advanced to one cycle
before its completion to verify no early RAM or output effect. Source costs use
the existing MC6809 timing decoder; no captured durations feed the plan.

Task Y/DP0 and caller U/X/S are explicit. PSHS/JSR scratch is written to real S;
this is not a complete CPU register/flags interface.60B4 address-port write is
timed but not exposed as a separate peripheral callback; callback at60B9 reports
the completed register/value pair. Audio/peripheral bus ownership remains external.
Suspension accepts only an unmasked instruction boundary; masked and partial
instruction attempts fail. This does not establish Live IRQ acceptance.

The clean instruction capture ba5b4dd1f023412a91df22198421e5ae replaces the earlier
48-case memory-only fixture. Curated catalogs deduplicate exact ROM contexts;
per-path arrays reference catalog indexes and relative cycles. Re-export is
deterministic. No Ghidra/tool/configuration changes were made.

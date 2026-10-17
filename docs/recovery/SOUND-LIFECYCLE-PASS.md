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

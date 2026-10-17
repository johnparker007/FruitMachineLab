namespace FruitMachineLab.Adders;

public static class RuntimeEvidenceRequirements
{
    public static RuntimeEvidenceRequirement VmLiteralTiming { get; }=new(
        "maps/vm-literal-timing.json",
        "tokens.operation, tokens.token, tokens.value",
        RuntimeEvidenceClass.StaticDefinition,
        "ROM-byte-checked decoded literal definitions with source-derived primitive cycle costs");

    public static RuntimeEvidenceRequirement CalibratedDelayTiming { get; }=new(
        "skill-cash/calibrated-delay-timing.json",
        "natural.phases[2].cpu_cycles, natural.phases[2].outer_irqs",
        RuntimeEvidenceClass.RecordedTiming,
        "source-derived native setup (776F bridge, 5A14/59FF/59D9 and 5C18 queue) plus generated IRQ/envelope timing for the remaining finish phase");

    public static RuntimeEvidenceRequirement FeatureCheckpoint { get; }=new(
        "skill-cash/feature-replay.json",
        "initial, allocated_frame, conditions, native[0].before",
        RuntimeEvidenceClass.DeclaredCheckpoint,
        "explicit declared entry checkpoint contract; later original reset/init chain (A6)",
        "this file also contains recorded instructions, inputs, before_reads, anchors and expected results that this loader does not consume");

    public static RuntimeEvidenceRequirement SharedTimingScanCheckpoint { get; }=new(
        "skill-cash/shared-timing.json",
        "initial_scan",
        RuntimeEvidenceClass.DeclaredCheckpoint,
        "generated reset/scan initialization instead of a captured scan snapshot",
        "events and vm_cycle_deltas are recorded timeline fields not consumed by this loader");

    public static RuntimeEvidenceRequirement CpuInterruptCosts { get; }=new(
        "skill-cash/cpu-interrupts.json",
        "sites, tokens",
        RuntimeEvidenceClass.RecordedTiming,
        "source-derived native/VM instruction timing for every fallback helper path");

    public static RuntimeEvidenceRequirement CpuInterruptSchedule { get; }=new(
        "skill-cash/cpu-interrupts.json",
        "intervals, timer1_handler_entries",
        RuntimeEvidenceClass.RecordedTiming,
        "causal timer1 assertion plus generated outer entry and occupancy");

    public static RuntimeEvidenceRequirement JackpotProbeCosts { get; }=new(
        "skill-cash/jackpot-probe.json",
        "sites, tokens",
        RuntimeEvidenceClass.RecordedTiming,
        "source-derived native/VM instruction timing for the selected feature helper paths");

    public static RuntimeEvidenceRequirement ExtensionTimingAliases { get; }=new(
        "maps/skill-cash-extension-data.json",
        "equivalent_timing_tokens",
        RuntimeEvidenceClass.StaticDefinition,
        "static declared equivalences; independent source-derived costs for the aliased tokens");

    public static RuntimeEvidenceRequirement SkillCashExtensionRanges { get; }=new(
        "maps/skill-cash-extension-data.json",
        "ranges",
        RuntimeEvidenceClass.StaticDefinition,
        "ROM-byte-checked static lamp, sound and alpha data ranges",
        "equivalent_timing_tokens are static declared aliases consumed separately by the Live constructor");

    public static RuntimeEvidenceRequirement SkillCashFeatureRanges { get; }=new(
        "maps/skill-cash-feature-data.json",
        "ranges[71AA, 8705, 890A, 7257]",
        RuntimeEvidenceClass.StaticDefinition,
        "ROM-byte-checked static feature and sound ranges",
        "words are static ROM word writes retained in the compiled loader and not read from this file");

    public static RuntimeEvidenceRequirement SkillCashAlphaRanges { get; }=new(
        "maps/skill-cash-alpha-scan-data.json",
        "ranges[A7B6, A7C9, A814, AF78, 193B, 6C3C]",
        RuntimeEvidenceClass.StaticDefinition,
        "ROM-byte-checked static alpha streams and glyph/mirror tables");

    public static RuntimeEvidenceRequirement SkillCashScanRanges { get; }=new(
        "maps/skill-cash-alpha-scan-data.json",
        "ranges[28E6, 29BB]",
        RuntimeEvidenceClass.StaticDefinition,
        "ROM-byte-checked static output-scan tables");

    public static RuntimeEvidenceRequirement BoardResultCosts { get; }=new(
        "skill-cash/board-result.json",
        "sites, tokens",
        RuntimeEvidenceClass.RecordedTiming,
        "source-derived native/VM instruction timing for the selected board-result caller",
        "entry RAM, frames and expected feature results in this file are not consumed by this loader");

    public static RuntimeEvidenceRequirement IrqServiceData { get; }=new(
        "maps/irq-service-data.json",
        "c5_control, c5_direction, c5_output, c8_control, c8_direction, c8_output, panel_callback, drive_counter_before_first_service, timer3.output_high, timer3.single_fired, timer3.latch, timer3.counter, timer3.pending, timer3.status_read",
        RuntimeEvidenceClass.DeclaredCheckpoint,
        "generated reset/PIA/timer3 phase; declared hardware checkpoint remains only until A6",
        "ranges are static ROM-byte-checked helper data retained alongside the captured initial peripheral fields");

    public static RuntimeEvidenceRequirement LampFrames { get; }=new(
        "skill-cash/lamp-frames.json",
        "initial, responses",
        RuntimeEvidenceClass.RecordedResult,
        "recovered physical PAL/scan contract; current MAME/characteriser responses remain an explicit non-PAL adapter",
        "initial frames are declared checkpoint state; responses are recorded compatibility results");

    public static RuntimeEvidenceRequirement NudgePreparationAliases { get; }=new(
        "maps/nudge-preparation-data.json",
        "equivalent_timing_tokens",
        RuntimeEvidenceClass.StaticDefinition,
        "static declared equivalences; independent source-derived costs for the aliased tokens");

    public static RuntimeEvidenceRequirement DiceMotionData { get; }=new(
        "maps/dice-motion-data.json",
        "ranges",
        RuntimeEvidenceClass.StaticDefinition,
        "static ROM data for translated motor profiles, coil phases, stop lamps and rolling sound");

    public static RuntimeEvidenceRequirement DiceRequestData { get; }=new(
        "maps/dice-request-data.json",
        "ranges, threaded_call_pacing.tokens, equivalent_timing_tokens",
        RuntimeEvidenceClass.StaticDefinition,
        "static ROM data and statically byte-checked threaded-call membership");

    public static RuntimeEvidenceRequirement BoardMovementData { get; }=new(
        "maps/board-movement-data.json",
        "equivalent_timing_tokens",
        RuntimeEvidenceClass.StaticDefinition,
        "static declared equivalences; independent source-derived costs for the aliased tokens");

    public static RuntimeEvidenceRequirement BoardLinkCosts(string file)=>new(
        $"skill-cash/{file}",
        "sites, tokens",
        RuntimeEvidenceClass.RecordedTiming,
        "source-derived native/VM instruction timing for the selected board-link consumer",
        "other checkpoint, instruction, output and expected-result fields in this file are not consumed by this loader");
}

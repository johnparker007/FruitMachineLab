using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record DiceRequestState(byte Symbol,sbyte StopOffset,byte PhysicalPosition,bool Busy=false,byte DisplayedSymbol=0);
public record NudgeReelState(byte Remaining,byte Pot,bool Busy,IReadOnlyList<byte> Positions,IReadOnlyList<byte> Symbols);
public record BoardState(byte Square,byte NudgePot,byte Type,byte Link,IReadOnlyList<byte> Visited);
public record LiveSkillCashState(ulong Cycle,int Instructions,ushort VmAddress,string Execution,byte PhysicalBlack2,byte SampledBlack2,ushort PanelLatch,
    byte Choice,ushort Pending,ushort CurrentWin,string Alpha,double[] LampDuty,IReadOnlyList<ushort> Selections,DiceRequestState? DiceRequest,BoardState? Board=null,NudgeReelState? Nudge=null,ushort CashBank=0,ushort TokenBank=0,byte Credits=0,int PaidGamesCompleted=0);

// One live feature-entry session. No replay Inputs/Conditions/Anchors are applied
// after initialization. Captured VM pacing/outer IRQ entry and occupancy are
// explicit unresolved hardware adapters; gameplay, inputs and outputs are live.
public sealed class SkillCashLiveSession
{
    public const double CyclesPerSecond=OutputPlayback.CpuCyclesPerSecond;
    private readonly ScriptExecutor executor;
    private readonly Mpu4ChoiceStreamScheduler scheduler;
    private readonly Mpu4Alpha alpha;
    private Mpu4TimedPanelService? timedService;
    private Mpu4Timer1DispatchExecution? outerDispatch;
    private Mpu4PostPanelExecution? postPanel;
    public ushort? PostPanelAddress=>postPanel?.Address;
    public Action<OutputScanInstruction>? ObserveOuterDispatchInstruction {get;set;}
    public Action<OutputScanInstruction>? ObservePostPanelInstruction {get;set;}
    private readonly Mpu4Timer3PhaseClock timer3;

    public ulong? NextInputServiceEvent=>timedService?.NextEventCycle;
    public ushort? InputServiceAddress=>timedService?.InputAddress;
    public ushort? PanelServiceAddress=>timedService?.PanelAddress;
    public Action<OutputScanInstruction>? ObservePanelServiceInstruction {get;set;}
    public Action<ulong>? ObserveTimer3Acceptance {get;set;}
    public Action<ulong>? ObserveTimer3Return {get;set;}
    public Action<OutputScanInstruction>? ObserveInputServiceInstruction {get;set;}
    public Action<OutputScanAccess>? ObserveInputServiceAccess {get;set;}
    public ulong? NextOutputScanEvent=>timedService?.NextEventCycle;
    public ushort? OutputScanAddress=>timedService?.ScanAddress;
    public Action<OutputScanInstruction>? ObserveOutputScanInstruction {get;set;}
    public Action<OutputScanAccess>? ObserveOutputScanAccess {get;set;}
    public Action<ulong,Timer3Arm>? ObserveTimer3Arm {get;set;}


    public ulong? NextTimer3DispatchEvent=>timedService?.NextDispatchEvent;
    public Action<ulong>? ObserveTimer3DispatchEntry {get;set;}
    public Action<Timer3DispatchWrite>? ObserveTimer3DispatchWrite {get;set;}
    public ulong? NextLampCallbackEvent=>timedService?.NextCallbackEvent;
    public Action<ulong>? ObserveLampCallbackEntry {get;set;}
    public Action<LampCallbackWrite>? ObserveLampCallbackWrite {get;set;}
    private readonly AddersReelMotion? reelMotion;
    private readonly AddersReelHardware? reelHardware;
    private byte tonePhase;
    private ulong toneWaitStarted;
    public (ulong Started,ulong CpuCycles,ulong Deadline)? TimedToneDelay=>tonePhase==2 ? (toneWaitStarted,Mpu4CalibratedDelay.StartToneWaitCycles,nextVm) : null;
    private readonly ulong toneSetupCycles,toneFinishCycles;
    public bool TimedToneActive=>tonePhase is >0 and <4;
    private bool motionInitializing,lastVmInlineLiteral;
    private bool motionNativeReady;
    private readonly Dictionary<ushort,RecoveredScript> scripts=new();
    private readonly string evidence;
    private readonly RuntimeEvidencePolicy evidencePolicy;
    private readonly Dictionary<string,ulong> siteCosts,tokenCosts;
    private readonly HashSet<ushort> threadedCallTokens=new();
    private readonly Dictionary<ushort,(string Operation,ushort Value,ulong Cycles)> literalCosts=new();
    private readonly CapturedInterruptOccupancy occupancy;
    private readonly CapturedInterruptOccupancy delayOccupancy;
    private readonly List<ulong> services=new();
    private readonly List<LampLatchFrame> latches=new();
    private readonly List<ushort> selections=new();
    private int serviceIndex;
    private ulong serviceEpoch,nextVm;
    private double fractionalCycles;
    private bool waitingForScheduler,selectionLoop,boardChoiceCompleted;
    private DiceRequestState? diceRequest;
    private readonly List<byte> boardVisited=new();
    private bool boardAdvancing,boardPromptReady;
    public bool AwaitingNudgeInput {get;private set;}
    public bool NudgeMoving {get;private set;}
    private bool nudgeAttempted,nudgeContext;
    public bool AwaitingPaidStart {get;private set;}
    public bool AwaitingPaidNudge=>paidCycleOpen && AwaitingNudgeInput;
    public int PaidGamesCompleted {get;private set;}
    public bool PaidSpinMoving=>paidCycleOpen && !featureBoardActive && !nudgeContext && (motionInitializing || reelMotion?.Busy==true);
    private bool paidCycleOpen,featureBoardActive,featureEntryMotionOpen;
    public bool FeatureEntryMoving=>featureBoardActive && featureEntryMotionOpen && (motionInitializing || MotorBusy);
    public bool MotorBusy=>reelMotion?.Busy==true;
    public bool IncludesCaller {get;}
    public bool StartsAtBoardSelection {get;}
    public string? BoardLinkEntry {get;}
    public bool ContinueBoard {get;}
    public int BoardPrompts {get;private set;}
    public bool AwaitingBoardSelection=>StartsAtBoardSelection && boardPromptReady && !boardAdvancing && !boardChoiceCompleted;
    public Machine Machine {get;}=new();
    public Mpu4PanelInput Panel {get;}
    public ulong Cycle {get;private set;}
    public int Instructions {get;private set;}
    public int LampRequests {get;private set;}
    public int AlphaOperations {get;private set;}
    public int Scans {get;private set;}
    public int Callbacks {get;private set;}
    public IReadOnlyList<PlaybackLamp> Lamps {get;}
    public bool Paused {get;private set;}=true;
    public bool Completed=>executor.Completed;
    public string? Fault {get;private set;}
    public ushort VmAddress=>executor.NextInstruction?.Site ?? (StartsAtBoardSelection ? (ushort)0xE460 : IncludesCaller ? (ushort)0xE33C : (ushort)0xC767);
    public IReadOnlyList<ushort> Selections=>selections;
    public Action<Instruction,Machine>? ObserveDispatch {get;set;}
    public Action<AlphaState>? ObserveAlpha {get;set;}
    public Action<LampRequest>? ObserveLamp {get;set;}
    public SkillCashLiveSession(string evidenceDirectory,bool includeCaller=false,bool boardSelection=false,string? boardLink=null,bool continueBoard=false,RuntimeEvidencePolicy? evidencePolicy=null)
    {
        if(boardLink is not null && boardLink is not ("ladder" or "snake"))throw new ArgumentException("Unknown board link",nameof(boardLink));
        if(boardLink is not null)boardSelection=true;
        ContinueBoard=continueBoard;BoardLinkEntry=boardLink;boardAdvancing=boardLink is not null;
        IncludesCaller=includeCaller || boardSelection;StartsAtBoardSelection=boardSelection;
        evidence=evidenceDirectory;this.evidencePolicy=evidencePolicy ?? RuntimeEvidencePolicy.Compatibility;
        using(var literals=JsonDocument.Parse(ReadEvidence(RuntimeEvidenceRequirements.VmLiteralTiming)))
            foreach(var item in literals.RootElement.GetProperty("tokens").EnumerateArray()){
                string operation=item.GetProperty("operation").GetString()!;
                literalCosts.Add(item.GetProperty("token").GetUInt16(),(operation,item.GetProperty("value").GetUInt16(),operation=="vm_push_word_body_word" ? Mpu4VmPrimitiveTiming.BodyWordCycles : Mpu4VmPrimitiveTiming.BodyByteCycles));
            }
        using(var tone=JsonDocument.Parse(ReadEvidence(RuntimeEvidenceRequirements.CalibratedDelayTiming))){
            // Queue/cancel allocation still uses observed CPU-only budgets.
            // The wait is generated from ROM loop counts, never capture duration.
            var p=tone.RootElement.GetProperty("natural").GetProperty("phases");
            if(p.GetArrayLength()!=3)throw new InvalidDataException("Invalid timed-tone phase evidence");
            toneSetupCycles=p[0].GetProperty("cpu_cycles").GetUInt64();
            // Other native phases retain their existing body-only IRQ adapter.
            toneFinishCycles=p[2].GetProperty("cpu_cycles").GetUInt64()+p[2].GetProperty("outer_irqs").GetUInt64()*(M6809IrqEntry.EntryCycles+15);
        }
        Lamps=SkillCashPlayback.LoadLamps(evidence);
        var options=new JsonSerializerOptions{PropertyNameCaseInsensitive=true};
        var feature=JsonSerializer.Deserialize<FeatureCapture>(ReadEvidence(RuntimeEvidenceRequirements.FeatureCheckpoint),options)!;
        var timing=JsonSerializer.Deserialize<SharedTimingCapture>(ReadEvidence(RuntimeEvidenceRequirements.SharedTimingScanCheckpoint),options)!;
        using(var costs=JsonDocument.Parse(ReadEvidence(RuntimeEvidenceRequirements.CpuInterruptCosts))) {
            siteCosts=costs.RootElement.GetProperty("sites").EnumerateObject().ToDictionary(x=>x.Name,x=>x.Value.GetUInt64());
            tokenCosts=costs.RootElement.GetProperty("tokens").EnumerateObject().ToDictionary(x=>x.Name,x=>x.Value.GetUInt64());
        }
        using(var costs=JsonDocument.Parse(ReadEvidence(RuntimeEvidenceRequirements.JackpotProbeCosts))) {
            foreach(var item in costs.RootElement.GetProperty("sites").EnumerateObject())siteCosts.TryAdd(item.Name,item.Value.GetUInt64());
            foreach(var item in costs.RootElement.GetProperty("tokens").EnumerateObject())tokenCosts.TryAdd(item.Name,item.Value.GetUInt64());
        }
        using(var data=JsonDocument.Parse(ReadEvidence(RuntimeEvidenceRequirements.ExtensionTimingAliases)))
            foreach(var alias in data.RootElement.GetProperty("equivalent_timing_tokens").EnumerateObject())tokenCosts.Add(alias.Name,tokenCosts[alias.Value.GetString()!]);
        SeedFeature(feature);SeedScan(timing);SkillCashData.LoadExtensions(Machine,evidence);
        ushort initialClock=feature.Initial["clock"];
        if(includeCaller) {
            initialClock=SkillCashCallerState.Apply(Machine,evidence,true);
            using var caller=JsonDocument.Parse(ReadEvidence(RuntimeEvidenceRequirements.BoardResultCosts));
            foreach(var item in caller.RootElement.GetProperty("sites").EnumerateObject())siteCosts.TryAdd(item.Name,item.Value.GetUInt64());
            foreach(var item in caller.RootElement.GetProperty("tokens").EnumerateObject())tokenCosts.TryAdd(item.Name,item.Value.GetUInt64());
        }
        if(boardSelection) {
            initialClock=BoardSelectionState.Apply(Machine,evidence);
            BoardSelectionState.LoadDiceData(Machine,evidence);
            BoardMovementState.LoadData(Machine,evidence);BoardLinkState.LoadData(Machine,evidence);BoardLinkState.LoadIc8Entry(Machine,evidence);
            if(boardLink is not null)initialClock=BoardLinkState.Apply(Machine,evidence,boardLink);
            boardVisited.Add(Machine.Memory[0xC9]);
            foreach(string file in new[]{"ladder-link.json","snake-link.json","ladder-link-next.json","snake-link-next.json","board-movement-next.json","ladder-availability.json","nudge-entry.json","nudge-prompt.json","nudge-request.json","nudge-motion-vm.json","nudge-return.json","nudge-sequence.json","nudge-result.json","nudge-exit.json","nudge-win-transfer.json","nudge-tail.json","nudge-accounting.json","nudge-bank-return.json","nudge-cycle-init.json","nudge-ic8.json","nudge-background.json","nudge-status.json","nudge-services.json","nudge-preplay.json","nudge-eligibility.json","nudge-start.json","nudge-stake.json","nudge-tone.json","nudge-spin-flags.json","nudge-spin-gates.json","nudge-final-selection.json","nudge-spin-preparation.json","nudge-paid-spin.json","nudge-spin-result.json","nudge-paid-nudge.json","nudge-paid-step.json","nudge-paid-result.json","nudge-paid-return.json","nudge-paid-next-prompt.json","paid-flag-accounting.json","paid-flag-announcement.json","paid-flag-reel-plan.json","paid-flag-table.json","paid-flag-bootstrap.json","paid-flag-motion.json","paid-flag-board.json"}) {
                using var linkCosts=JsonDocument.Parse(ReadEvidence(RuntimeEvidenceRequirements.BoardLinkCosts(file)));
                foreach(var item in linkCosts.RootElement.GetProperty("sites").EnumerateObject())siteCosts.TryAdd(item.Name,item.Value.GetUInt64());
                foreach(var item in linkCosts.RootElement.GetProperty("tokens").EnumerateObject())tokenCosts.TryAdd(item.Name,item.Value.GetUInt64());
            }
            using(var nudgeData=JsonDocument.Parse(ReadEvidence(RuntimeEvidenceRequirements.NudgePreparationAliases)))
                foreach(var alias in nudgeData.RootElement.GetProperty("equivalent_timing_tokens").EnumerateObject())tokenCosts.TryAdd(alias.Name,tokenCosts[alias.Value.GetString()!]);
            using var motionData=JsonDocument.Parse(ReadEvidence(RuntimeEvidenceRequirements.DiceMotionData));
            foreach(var range in motionData.RootElement.GetProperty("ranges").EnumerateObject())Convert.FromHexString(range.Value.GetString()!).CopyTo(Machine.Memory,Convert.ToUInt16(range.Name,16));
            reelMotion=new(Machine);reelHardware=new(Machine);
            using var diceData=JsonDocument.Parse(ReadEvidence(RuntimeEvidenceRequirements.DiceRequestData));
            foreach(var token in diceData.RootElement.GetProperty("threaded_call_pacing").GetProperty("tokens").EnumerateArray())threadedCallTokens.Add(Convert.ToUInt16(token.GetString(),16));
            foreach(var alias in diceData.RootElement.GetProperty("equivalent_timing_tokens").EnumerateObject())tokenCosts.TryAdd(alias.Name,tokenCosts[alias.Value.GetString()!]);
            using var selection=JsonDocument.Parse(ReadEvidence(RuntimeEvidenceRequirements.BoardLinkCosts("board-selection.json")));
            foreach(var item in selection.RootElement.GetProperty("sites").EnumerateObject())siteCosts.TryAdd(item.Name,item.Value.GetUInt64());
            foreach(var item in selection.RootElement.GetProperty("tokens").EnumerateObject())tokenCosts.TryAdd(item.Name,item.Value.GetUInt64());
            using var dice=JsonDocument.Parse(ReadEvidence(RuntimeEvidenceRequirements.BoardLinkCosts("dice-requests.json")));
            foreach(var item in dice.RootElement.GetProperty("sites").EnumerateObject())siteCosts.TryAdd(item.Name,item.Value.GetUInt64());
            foreach(var item in dice.RootElement.GetProperty("tokens").EnumerateObject())tokenCosts.TryAdd(item.Name,item.Value.GetUInt64());
            using var motionCosts=JsonDocument.Parse(ReadEvidence(RuntimeEvidenceRequirements.BoardLinkCosts("dice-motion-vm.json")));
            foreach(var item in motionCosts.RootElement.GetProperty("sites").EnumerateObject())siteCosts.TryAdd(item.Name,item.Value.GetUInt64());
            foreach(var item in motionCosts.RootElement.GetProperty("tokens").EnumerateObject())tokenCosts.TryAdd(item.Name,item.Value.GetUInt64());
            using var movementCosts=JsonDocument.Parse(ReadEvidence(RuntimeEvidenceRequirements.BoardLinkCosts("board-movement.json")));
            foreach(var item in movementCosts.RootElement.GetProperty("sites").EnumerateObject())siteCosts.TryAdd(item.Name,item.Value.GetUInt64());
            foreach(var item in movementCosts.RootElement.GetProperty("tokens").EnumerateObject())tokenCosts.TryAdd(item.Name,item.Value.GetUInt64());
            using var nudgeCosts=JsonDocument.Parse(ReadEvidence(RuntimeEvidenceRequirements.BoardLinkCosts("nudge-pot-probe.json")));
            foreach(var item in nudgeCosts.RootElement.GetProperty("sites").EnumerateObject())siteCosts.TryAdd(item.Name,item.Value.GetUInt64());
            foreach(var item in nudgeCosts.RootElement.GetProperty("tokens").EnumerateObject())tokenCosts.TryAdd(item.Name,item.Value.GetUInt64());
            using var movementData=JsonDocument.Parse(ReadEvidence(RuntimeEvidenceRequirements.BoardMovementData));
            foreach(var alias in movementData.RootElement.GetProperty("equivalent_timing_tokens").EnumerateObject())tokenCosts.TryAdd(alias.Name,tokenCosts[alias.Value.GetString()!]);
        }
        Panel=new(Machine);byte[] other=new byte[8];
        // This feature-entry fixture has no Orange/Black service buttons held.
        // DIL bits are fixed prerequisites, not player-event substitutions.
        var condition=feature.Conditions[0];other[6]=(byte)condition[7];other[7]=(byte)condition[8];Panel.SeedOtherPorts(other);
        for(int n=0;n<8;n++)Machine.Memory[n]=other[n];
        // Original ROM data and selected feature-entry service checkpoint.
        // Natural passive PIA observation: IC5 ctl3C/DDR0F/out20,
        // IC8 ctl34/DDRFF/out30; no auxiliary coin input held in this scope.
        using(var serviceData=JsonDocument.Parse(ReadEvidence(RuntimeEvidenceRequirements.IrqServiceData))){
            var seed=serviceData.RootElement;
            foreach(var region in seed.GetProperty("ranges").EnumerateObject())Convert.FromHexString(region.Value.GetString()!).CopyTo(Machine.Memory,Convert.ToInt32(region.Name,16));
            if(seed.GetProperty("c5_control").GetByte()!=0x3C || seed.GetProperty("c5_direction").GetByte()!=15 || seed.GetProperty("c8_control").GetByte()!=0x34 || seed.GetProperty("c8_direction").GetByte()!=255)throw new NotSupportedException("Unsupported selected service PIA configuration");
            Machine.WriteWord(0xC6,seed.GetProperty("panel_callback").GetUInt16());Machine.Memory[0x6E]=seed.GetProperty("drive_counter_before_first_service").GetByte();
            serviceAuxOutput=(byte)((seed.GetProperty("c5_output").GetByte()&0xF0)|(Machine.Memory[0xC02]&15));
            if(!boardSelection)Machine.Memory[0xF02]=seed.GetProperty("c8_output").GetByte();
            var clock=seed.GetProperty("timer3");timer3=Mpu4Timer3PhaseClock.FromStoppedSnapshot(0,clock.GetProperty("output_high").GetBoolean(),clock.GetProperty("single_fired").GetBoolean(),clock.GetProperty("latch").GetUInt16(),clock.GetProperty("counter").GetUInt16(),clock.GetProperty("pending").GetBoolean(),clock.GetProperty("status_read").GetBoolean());
        }
        Machine.Memory[0x91]&=0x7F;
        alpha=new(Machine);scheduler=new(Machine,initialClock);
        if(boardSelection)scheduler.RestoreQueuedNativeTasks(boardLink is null ? null : at=>BoardLinkState.ResolveSoundContinuation(Machine,at));
        var response=JsonSerializer.Deserialize<LampFrameCapture>(ReadEvidence(RuntimeEvidenceRequirements.LampFrames),options)!;
        var frames=new Mpu4LampFrames(Machine,response.Responses.Select(x=>checked((byte)x)).ToArray());
        var requests=new Mpu4LampRequests(Machine,request=>{frames.Apply(request.Id,request.Pattern);LampRequests++;ObserveLamp?.Invoke(request);});
        // Accepted outer IRQ entry/occupancy remains the explicit CPU adapter.
        // The scan-entry timestamp table is no longer consumed: FE70->28FE is code.
        using(var interrupts=JsonDocument.Parse(ReadEvidence(RuntimeEvidenceRequirements.CpuInterruptSchedule))){
            var intervals=interrupts.RootElement.GetProperty("intervals").EnumerateArray().Select(row=>row.EnumerateArray().Select(x=>x.GetUInt64()).ToArray()).ToArray();
            foreach(var row in interrupts.RootElement.GetProperty("timer1_handler_entries").EnumerateArray())services.Add(row.GetUInt64());
            if(services.Count==0)throw new InvalidDataException("Missing outer IRQ service template");
            servicePeriod=checked((ulong)services.Count*Mpu4Timer1Clock.Period(Mpu4Timer1Clock.NormalLatch));
            occupancy=new(servicePeriod,intervals);
            delayOccupancy=CapturedInterruptOccupancy.FromOrdinaryIrqHandlers(servicePeriod,intervals);
        }
        RecordLatch();
        executor=new(Machine) {
            ResolveScript=Resolve,ResolveWord=SkillCashData.ResolveWord,
            InputConditionCell=value=>Mpu4InputConditions.Evaluate(Machine,(byte)value),
            BeforeInstruction=(instruction,state)=> {
                Instructions++;ObserveDispatch?.Invoke(instruction,state);
                if(instruction.Site==0xFE1F && paidCycleOpen){PaidGamesCompleted++;paidCycleOpen=false;featureBoardActive=false;featureEntryMotionOpen=false;}
                if(paidCycleOpen && instruction.Site==0xE43D)featureBoardActive=true;
                if(instruction.Site==0xE443)featureEntryMotionOpen=false;
                if(ContinueBoard && instruction.Site==0xDD38){boardAdvancing=false;boardChoiceCompleted=false;boardPromptReady=false;BoardPrompts++;}
                if(StartsAtBoardSelection && boardVisited[^1]!=state.Memory[0xC9])boardVisited.Add(state.Memory[0xC9]);
                if(instruction.Site==0xDDF3 && diceRequest is not null)boardAdvancing=true;
                if(instruction.Site==0xB72D)nudgeContext=true;
                if(instruction.Site==0xB770){nudgeContext=false;AwaitingNudgeInput=false;}
                if(instruction.Site==0xB6C4)NudgeMoving=true;
                if(instruction.Site==0xB6D7)NudgeMoving=false;
                if(instruction.Site==0xB403)AwaitingNudgeInput=true;
                if(instruction.Site==0xB34E)NudgeMoving=false;
                if(instruction.Site==0xB31F){AwaitingNudgeInput=false;NudgeMoving=true;nudgeAttempted=true;}
                if(instruction.Site==0xFCD5)AwaitingPaidStart=state.Data.Peek()==0;
                if(instruction.Site==0xFCD8)AwaitingPaidStart=false;
                if(instruction.Site==0xDD4E)boardPromptReady=true;
                if(instruction.Site==0xDDAB){boardChoiceCompleted=true;boardPromptReady=false;}
                if(instruction.Site==0xC6AD)selectionLoop=true;
                if(instruction.Site==0xC757){selections.Add(state.Data.Peek());selectionLoop=false;}
            },
            WordHandler=(instruction,state)=> {
                if(instruction.Native==0x5A14 && tonePhase==4){tonePhase=0;return true;}
                if((instruction.Native is 0x61F6 or 0x61D5 or 0x61CF) && motionNativeReady){motionNativeReady=false;return true;}
                return AddersNativeWords.Handle(instruction,state,requests,scheduler,alpha,()=>{AlphaOperations++;ObserveAlpha?.Invoke(alpha.Snapshot());});
            }
        };
        if(boardSelection){var catalog=new RecoveredScriptCatalog(Path.Combine(evidence,"VM-SCRIPTS"));ushort entry=boardLink is null ? (ushort)0xDD38 : (ushort)0xDBC4;executor.BeginResumed(Resolve(entry),entry,catalog.Owner,0xBEEF,10_000_000);}
        else executor.Begin(Resolve(includeCaller ? (ushort)0xE2FC : (ushort)0xC721),10_000_000);
    }
    private readonly ulong servicePeriod;
    private string ReadEvidence(RuntimeEvidenceRequirement requirement)=>evidencePolicy.ReadText(evidence,requirement);
    private RecoveredScript Resolve(ushort address)
    {
        if(!scripts.TryGetValue(address,out var script)){script=new(Path.Combine(evidence,"VM-SCRIPTS",address.ToString("X4")+".txt"));scripts.Add(address,script);}return script;
    }
    private void SeedFeature(FeatureCapture capture)
    {
        var m=Machine;var first=capture.Initial;SkillCashData.LoadFeature(m);SkillCashData.LoadAlpha(m);
        SkillCashAlphaVerification.Seed(m,SkillCashAlphaVerification.Load(evidence).Calls[0].Before);
        var native=capture.Native[0].Before;
        for(ushort at=0x2F0;at<0x322;at++)m.Memory[at]=(byte)native[(at<0x309 ? "source" : "copy")+at.ToString("X4")];
        m.LocalFrame=first["f4"];m.WriteWord(m.LocalFrame,first["frame"]);m.Control=new(m,first["s"]){LoopFrame=first["f6"]};
        m.WriteWord(first["s"],0xBEEF);m.WriteWord(Cell.Subtract(first["s"],4),capture.AllocatedFrame);
        foreach(var pair in new[]{("tick",0x2D),("seed",0x324),("latch",0x90),("opt",0x719F),("abort",0x719B),("pending",0xBA),("win",0x2FA),("display",0x327),("suppress",0xA0)})m.WriteWord((ushort)pair.Item2,first[pair.Item1]);
        foreach(var pair in new[]{("irq",0x33),("choice",0x4F),("rate",0x4E),("guard",0x2C),("checksum",0x322),("mode",0x323)})m.Memory[pair.Item2]=(byte)first[pair.Item1];
        foreach(var name in new[]{"fourth","third","second","top"})m.Data.Push(first[name]);
        m.DataStackBase=Cell.Add(first["u"],8);
        var comp=SkillCashCompensationVerification.Load(evidence)[0];
        foreach(ushort site in new ushort[]{0xA0F1,0xA102}) {
            int at=Array.FindIndex(comp.Steps,x=>x["y"]==site);ushort address=comp.Steps[at]["top"];
            m.Memory[address]=(byte)comp.Steps[at+1]["top"];m.WriteWord(Cell.Add(address,1),comp.Steps[at+1]["second"]);
        }
    }
    private void SeedScan(SharedTimingCapture capture)
    {
        var m=Machine;SkillCashData.LoadScan(m);var initial=capture.InitialScan;
        foreach(var pair in new[]{("phase",0x23),("count",0x24),("reload",0x25),("alternate",0x26),("alternate_reload",0x27),("suppress",0x8D),("decimal",0x22),("sweep",0xB3)})m.Memory[pair.Item2]=Convert.ToByte(initial[pair.Item1],16);
        m.WriteWord(0x28,Convert.ToUInt16(initial["column"],16));
        foreach(var pair in new[]{("sample",8),("digits",0x1A),("blink",0x2BE),("masks",0x140),("blank",0xAB)})Convert.FromHexString(initial[pair.Item1]).CopyTo(m.Memory,pair.Item2);
        var pulse=Convert.FromHexString(initial["pulse"]);m.Memory[0xE8]=pulse[0];m.Memory[0xE9]=pulse[1];m.Memory[0xEA]=pulse[2];m.WriteWord(0x32D,(ushort)((pulse[3]<<8)|pulse[4]));
        var ports=Convert.FromHexString(initial["ports"]);int[] addresses=[0xA00,0xA02,0xB00,0xE01,0xB01,0xF01];for(int n=0;n<6;n++)m.Memory[addresses[n]]=ports[n];
        var options=new JsonSerializerOptions{PropertyNameCaseInsensitive=true};
        var lamps=JsonSerializer.Deserialize<LampFrameCapture>(ReadEvidence(RuntimeEvidenceRequirements.LampFrames),options)!;
        Convert.FromHexString(lamps.Initial).CopyTo(m.Memory,0x100);
    }
    public void Resume(){if(!Completed && Fault is null)Paused=false;}
    private byte serviceAuxOutput;
    private static decimal TimerTime(ulong cycle)=>cycle*Mpu4Timer3PhaseClock.AttosecondsPerSecond/1_720_000m;
    private byte ReadServicePort(ushort address)=>address switch {0xC02=>(byte)(serviceAuxOutput&0x0F),0xF02=>Machine.Memory[0xF02],_=>throw new NotSupportedException($"Service read {address:X4}")};
    private void WriteServicePort(ushort address,byte value){if(address==0xC02){serviceAuxOutput=value;Machine.Memory[address]=(byte)(value&0x0F);}else if(address==0xF02)Machine.Memory[address]=value;else throw new NotSupportedException($"Service write {address:X4}");}
    public void Pause(){Paused=true;Panel.Release();}
    public void SetStart(bool pressed){Panel.SetStart(pressed && !Paused && !Completed && Fault is null);}
    public void SetNudge(int reel,bool pressed){Panel.SetNudge(reel,pressed && AwaitingNudgeInput && !Paused && !Completed && Fault is null);}
    public void SetTake(bool pressed){Panel.SetTake(pressed && !Paused && !Completed && Fault is null);}
    public void Advance(TimeSpan elapsed)
    {
        if(elapsed<TimeSpan.Zero)throw new ArgumentOutOfRangeException(nameof(elapsed));
        if(Paused || Completed || Fault is not null)return;
        double ticks=elapsed.TotalSeconds*CyclesPerSecond+fractionalCycles;ulong delta=(ulong)Math.Floor(ticks);fractionalCycles=ticks-delta;AdvanceCycles(delta);
    }
    public void AdvanceCycles(ulong cycles)
    {
        if(Paused || Completed || Fault is not null)return;
        ulong target=checked(Cycle+cycles);int budget=200_000;
        try {
            while(!Paused && !Completed && Cycle<=target) {
                ulong irq=postPanel?.NextEventCycle ?? outerDispatch?.NextEventCycle ?? timedService?.NextEventCycle ?? checked(serviceEpoch+services[serviceIndex]);
                ulong next=Math.Min(occupancy.NextStart,Math.Min(nextVm,irq));if(next>target){Cycle=target;break;}Cycle=next;
                if(occupancy.NextStart==next) {
                    ulong end=occupancy.NextEnd;
                    if(lastVmInlineLiteral && !waitingForScheduler && !motionInitializing && !motionNativeReady && !TimedToneActive)Machine.Control!.PreserveInterruptDirectPage(0);
                    // Calibrated delay already projects its CPU budget through
                    // full IRQ envelopes; do not charge these bodies twice.
                    if(tonePhase!=2)nextVm=waitingForScheduler ? Math.Max(nextVm,end) : checked(nextVm+(end-next));
                    occupancy.Consume();
                }
                if(irq==next) {
                    // Retained outer-entry adapter supplies mapped VM U. Temporary
                    // native U inside atomic motor/sound helpers remains unresolved;
                    // natural ignored-SWI2 frames are verified, not injected here.
                    if(timedService is null && outerDispatch is null && postPanel is null){outerDispatch=new(Machine,Cycle,()=>Machine.DataPointer);outerDispatch.ObserveInstruction=i=>ObserveOuterDispatchInstruction?.Invoke(i);}
                    if(outerDispatch is not null){outerDispatch.AdvanceTo(Cycle);if(!outerDispatch.Completed)continue;outerDispatch=null;

                        timedService=new(Machine,Cycle,timer3,TimerTime,Panel.ReadPort,ReadServicePort,WriteServicePort);
                        timedService.ObserveScan=i=>ObserveOutputScanInstruction?.Invoke(i);
                        timedService.ObserveInput=i=>ObserveInputServiceInstruction?.Invoke(i);
                        timedService.ObservePanel=i=>ObservePanelServiceInstruction?.Invoke(i);
                        timedService.ObserveAcceptance=at=>ObserveTimer3Acceptance?.Invoke(at);
                        timedService.ObserveReturn=at=>ObserveTimer3Return?.Invoke(at);
                        timedService.ObserveScanAccess=a=>{if(a.Write && a.Address is 0xA00 or 0xA02 or 0xE01 or 0xB01 or 0xF01)RecordLatch();ObserveOutputScanAccess?.Invoke(a);};
                        timedService.ObserveInputAccess=a=>{if(a.Hardware && a.Write && a.Address is 0xD02 or 0xE00)reelHardware?.WriteDriveBank(a.Address,checked((byte)a.Value!.Value));ObserveInputServiceAccess?.Invoke(a);};
                        timedService.ObserveArm=(at,value)=>ObserveTimer3Arm?.Invoke(at,value);
                        timedService.ObserveEntry=at=>ObserveTimer3DispatchEntry?.Invoke(at);
                        timedService.ObserveDispatchWrite=w=>ObserveTimer3DispatchWrite?.Invoke(w);
                        timedService.ObserveCallbackEntry=at=>ObserveLampCallbackEntry?.Invoke(at);
                        timedService.ObserveCallbackWrite=w=>{RecordLatch();ObserveLampCallbackWrite?.Invoke(w);};
                        timedService.ObserveCallbackComplete=_=>Callbacks++;
                    }
                    if(timedService is not null){
                    bool scanning=timedService.ScanAddress is not null;timedService.AdvanceTo(Cycle);
                    if(scanning && timedService.ScanAddress is null)Scans++;
                    if(timedService.Completed){
                        timedService.Dispose();timedService=null;
                        bool idle=(Machine.Memory[0x6B]&0x80)==0;
                        if(!idle && reelMotion is null)throw new NotSupportedException("Active motor service needs the selected game motion adapter");
                        if(!idle && reelMotion is not null) {
                            // Retained active motor-body timing adapter. Only its
                            // existing translated effects are atomic; no duration
                            // is invented for unrecovered6407 onward here.
                            reelMotion.Service((_,_)=>reelHardware!.ReadOptics(),stream=>scheduler.Queue(stream));
                        }
                        postPanel=new(Machine,Cycle,()=>reelHardware?.ReadOptics() ?? (byte)0,includeIdleMotor:idle);
                        postPanel.ObserveInstruction=i=>ObservePostPanelInstruction?.Invoke(i);
                    }
                    }
                    if(postPanel is not null){postPanel.AdvanceTo(Cycle);if(postPanel.Completed){
                        postPanel.Dispose();postPanel=null;
                        if(motionInitializing){reelMotion!.Activate();motionInitializing=false;motionNativeReady=true;}
                        scheduler.AdvanceTicks(1);Machine.Memory[0x2C]=0;
                        if(++serviceIndex==services.Count){serviceIndex=0;serviceEpoch=checked(serviceEpoch+servicePeriod);}
                    }}
                }
                if(nextVm==next) {
                    // A generated scan may outlast the captured outer occupancy
                    // when current state takes a different native path. VM work
                    // cannot run inside it; wait for actual instruction progress.
                    if(timedService is not null || outerDispatch is not null || postPanel is not null){nextVm=postPanel?.NextEventCycle ?? outerDispatch?.NextEventCycle ?? timedService!.NextEventCycle;continue;}

                    if(--budget==0)throw new InvalidOperationException("Live dispatch budget exceeded");
                    var instruction=executor.NextInstruction!;
                    if(!ContinueBoard && boardAdvancing && instruction.Site is 0xDE96 or 0xDD38)throw new NotSupportedException($"BOARD advance completed at square {Machine.Memory[0xC9]} (type {Machine.Memory[0xA12E+Machine.Memory[0xC9]]}, nudge pot {Machine.Memory[0xBF]}); the next board result/selection is the recovery boundary. Restart to play again.");
                    if(!ContinueBoard && BoardLinkEntry is not null && instruction.Site==0xDE81)throw new NotSupportedException($"BOARD {BoardLinkEntry} completed at square {Machine.Memory[0xC9]} (nudge pot {Machine.Memory[0xBF]}); following board result/selection remains the recovery boundary. Restart to watch again.");
                    if(ContinueBoard && instruction.Site==0xE2FC && Machine.Data.Peek() is not (1 or 2))throw new NotSupportedException($"BOARD result type {Machine.Data.Peek()} at square {Machine.Memory[0xC9]}; this result route is the next recovery boundary.");
                    if(ContinueBoard && BoardLinkEntry is not null && !nudgeAttempted && instruction.Site==0xE460)throw new NotSupportedException("BOARD feature exit reached; outer machine caller remains outside the live entry.");
                    if(ContinueBoard && instruction.Native==0x2BEB && reelMotion?.Busy==true){nextVm=checked(serviceEpoch+services[serviceIndex]);continue;}
                    if(ContinueBoard && instruction.Site==0xE227)throw new NotSupportedException($"BOARD special feature at square {Machine.Memory[0xC9]} (type {Machine.Memory[0xA12E+Machine.Memory[0xC9]]}); announcement/feature routing is the next recovery boundary.");
                    if(ContinueBoard && instruction.Site==0xE2E5 && (Machine.ReadWord(0xA0)&0x10)!=0 && Machine.Data.Peek() is not (1 or 2))throw new NotSupportedException($"BOARD taken result type {Machine.Data.Peek()} at square {Machine.Memory[0xC9]}; this result helper remains outside the verified routes.");
                    if(StartsAtBoardSelection && (instruction.Native is 0x61F6 or 0x61D5 or 0x61CF) && !motionNativeReady) {
                        if(!motionInitializing){
                            if(instruction.Native==0x61D5){paidCycleOpen=true;reelMotion!.PrepareAsync(value=>Mpu4InputConditions.Evaluate(Machine,value));}
                            else if(instruction.Native==0x61CF){featureEntryMotionOpen=true;reelMotion!.PrepareFeatureAsync(value=>Mpu4InputConditions.Evaluate(Machine,value));}
                            else{if(!nudgeContext)diceRequest=new(Machine.Memory[0x166],unchecked((sbyte)Machine.Memory[0x16F]),Machine.Memory[0x16E]);reelMotion!.Prepare(value=>Mpu4InputConditions.Evaluate(Machine,value));}
                            reelMotion.Enable();motionInitializing=true;
                        }
                        nextVm=checked(serviceEpoch+services[serviceIndex]);continue;
                    }
                    if(instruction.Native==0x5A14 && tonePhase<4){
                        if((Machine.Memory[0x719B]&0x80)!=0)throw new NotSupportedException("Live disabled-tone pacing requires separate verification");
                        if(tonePhase==0){tonePhase=1;nextVm=checked(Cycle+toneSetupCycles);}
                        else if(tonePhase==1){AddersTimedTone.Begin(Machine,scheduler);tonePhase=2;toneWaitStarted=Cycle;nextVm=delayOccupancy.CompletionAfterCpuWork(Cycle,Mpu4CalibratedDelay.StartToneWaitCycles);}
                        else{AddersTimedTone.End(Machine,scheduler);tonePhase=4;nextVm=checked(Cycle+toneFinishCycles);}
                        continue;
                    }
                    waitingForScheduler=instruction.Native==0x5CCB && scheduler.Active;
                    if(waitingForScheduler){nextVm=checked(serviceEpoch+services[serviceIndex]);continue;}
                    ulong cost=instruction.Native==0x5CCB || instruction.Native==0x5A14 ? 0 : Cost(instruction);
                    executor.Step();lastVmInlineLiteral=instruction.Operation is "vm_push_inline_byte_literal" or "vm_push_inline_word_literal";nextVm=checked(Cycle+cost);
                    if(Completed){Paused=true;Panel.Release();break;}
                }
            }
        } catch(Exception error){Fault=error.Message;Paused=true;Panel.Release();throw;}
    }
    private ulong Cost(Instruction instruction)
    {
        if(literalCosts.TryGetValue(instruction.Token,out var literal)){
            if(instruction.Operation!=literal.Operation || instruction.Value!=literal.Value)throw new InvalidDataException($"Literal timing/listing mismatch at {instruction.Site:X4}/{instruction.Token:X4}");
            return literal.Cycles;
        }
        // Decide native branches from the same pre-execution cells the VM will
        // consume, without popping them or consulting a recorded path.
        if(Mpu4VmConditionalTiming.Cycles(instruction.Token,Machine.Data) is ulong conditionalCost)return conditionalCost;
        // Selected straight-line words now derive their CPU work from native
        // encodings. Interrupt occupancy remains the explicit captured adapter.
        if(Mpu4VmPrimitiveTiming.Cycles(instruction.Token) is ulong nativeCost)return nativeCost;
        // Only statically byte-checked 00F8 headers qualify. This charges entry,
        // never the called body, which continues executing incrementally.
        if(instruction.Body is not null && instruction.PushAddress is null && threadedCallTokens.Contains(instruction.Token))return Mpu4VmPrimitiveTiming.ThreadedCallCycles;
        if(siteCosts.TryGetValue(instruction.Site.ToString("X4"),out var cost) || tokenCosts.TryGetValue(instruction.Token.ToString("X4"),out cost))return cost;
        throw new NotSupportedException($"No captured CPU pacing boundary for {instruction.Site:X4}/{instruction.Token:X4}");
    }
    private void RecordLatch()
    {
        latches.Add(new(Cycle,checked((byte)Machine.ReadWord(0x28)),Machine.Memory[0xA00],Machine.Memory[0xA02]));
        ulong start=Cycle>34_400 ? Cycle-34_400 : 0;
        while(latches.Count>1 && latches[1].Cycle<start)latches.RemoveAt(0);
    }
    public LiveSkillCashState Snapshot()
    {
        var state=alpha.Snapshot();var history=latches.Select((frame,n)=>n==0 ? frame with{Cycle=0} : frame);
        var display=new AlphaPlaybackFrame(0,state.Text,Machine.ReadWord(0xBA),Machine.ReadWord(0x2FA));
        var duty=new OutputPlayback(Math.Max(Cycle,1),history,new[]{display}).Sample(Cycle).LampDuty;
        string status=Fault is not null ? "Fault: "+Fault : Completed ? "Completed" : Paused ? "Paused" : TimedToneActive ? "Native start tone / timed CPU delay executing" : waitingForScheduler ? "Waiting for native scheduler" : VmAddress is >=0x9986 and <=0x998D ? "Waiting for panel release" : FeatureEntryMoving ? "Feature-entry reel motion executing" : PaidSpinMoving ? "Paid reel spin - motor service executing" : NudgeMoving ? "Nudge motor running / cleanup executing" : AwaitingPaidStart ? "Waiting for START - preplay input loop executing" : AwaitingNudgeInput ? "Waiting for NUDGE 1 / 2 / 3 - actual input scan executing" : selectionLoop ? "Waiting for START · selection loop executing" : boardAdvancing ? "Board movement executing" : reelMotion?.Busy==true ? "Dice motor running · VM waiting for completion" : motionInitializing ? "Waiting for reel service" : AwaitingBoardSelection ? "Waiting for TAKE / START · board selection executing" : "Running";
        return new(Cycle,Instructions,VmAddress,status,Panel.PhysicalBlack2,Machine.Memory[3],Machine.ReadWord(0x90),Machine.Memory[0x4F],Machine.ReadWord(0xBA),Machine.ReadWord(0x2FA),state.Text,duty,selections.ToArray(),diceRequest is null ? null : diceRequest with {PhysicalPosition=Machine.Memory[0x16E],Busy=reelMotion!.Busy,DisplayedSymbol=AddersReelSymbols.CurrentSymbol(Machine,3)},StartsAtBoardSelection ? new(Machine.Memory[0xC9],Machine.Memory[0xBF],Machine.Memory[0xA12E+Machine.Memory[0xC9]],Machine.Memory[0xA160+Machine.Memory[0xC9]],boardVisited.ToArray()) : null,AwaitingNudgeInput || nudgeAttempted ? new(Machine.Memory[0xBE],Machine.Memory[0xBF],MotorBusy,new byte[]{Machine.Memory[0x168],Machine.Memory[0x16A],Machine.Memory[0x16C]},Enumerable.Range(0,3).Select(n=>AddersReelSymbols.CurrentSymbol(Machine,n)).ToArray()) : null,Machine.ReadWord(0x2FC),Machine.ReadWord(0x302),Machine.Memory[0x2F0],PaidGamesCompleted);
    }
}

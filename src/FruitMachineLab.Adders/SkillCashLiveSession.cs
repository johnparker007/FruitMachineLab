using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record DiceRequestState(byte Symbol,sbyte StopOffset,byte PhysicalPosition,bool Busy=false,byte DisplayedSymbol=0);
public record NudgeReelState(byte Remaining,byte Pot,bool Busy,IReadOnlyList<byte> Positions,IReadOnlyList<byte> Symbols);
public record BoardState(byte Square,byte NudgePot,byte Type,byte Link,IReadOnlyList<byte> Visited);
public record LiveSkillCashState(ulong Cycle,int Instructions,ushort VmAddress,string Execution,byte PhysicalBlack2,byte SampledBlack2,ushort PanelLatch,
    byte Choice,ushort Pending,ushort CurrentWin,string Alpha,double[] LampDuty,IReadOnlyList<ushort> Selections,DiceRequestState? DiceRequest,BoardState? Board=null,NudgeReelState? Nudge=null,ushort CashBank=0,ushort TokenBank=0,byte Credits=0,int PaidGamesCompleted=0);

// One live feature-entry session. No replay Inputs/Conditions/Anchors are applied
// after initialization. Captured CPU pacing and IRQ service timestamps are
// explicit unresolved hardware adapters; gameplay, inputs and outputs are live.
public sealed class SkillCashLiveSession
{
    public const double CyclesPerSecond=OutputPlayback.CpuCyclesPerSecond;
    private readonly ScriptExecutor executor;
    private readonly Mpu4ChoiceStreamScheduler scheduler;
    private readonly Mpu4Alpha alpha;
    private readonly Mpu4OutputScan scan;
    private readonly AddersReelMotion? reelMotion;
    private readonly AddersReelHardware? reelHardware;
    private byte tonePhase;
    private readonly ulong toneSetupCycles,toneWaitCycles,toneFinishCycles;
    public bool TimedToneActive=>tonePhase is >0 and <4;
    private bool motionInitializing,lastVmInlineLiteral;
    private bool motionNativeReady;
    private readonly Dictionary<ushort,RecoveredScript> scripts=new();
    private readonly string evidence;
    private readonly Dictionary<string,ulong> siteCosts,tokenCosts;
    private readonly HashSet<ushort> threadedCallTokens=new();
    private readonly CapturedInterruptOccupancy occupancy;
    private readonly List<(ulong Scan,ulong Callback)> services=new();
    private readonly List<LampLatchFrame> latches=new();
    private readonly List<ushort> selections=new();
    private int serviceIndex;
    private ulong serviceEpoch,nextVm,nextCallback=ulong.MaxValue;
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
    public SkillCashLiveSession(string evidenceDirectory,bool includeCaller=false,bool boardSelection=false,string? boardLink=null,bool continueBoard=false)
    {
        if(boardLink is not null && boardLink is not ("ladder" or "snake"))throw new ArgumentException("Unknown board link",nameof(boardLink));
        if(boardLink is not null)boardSelection=true;
        ContinueBoard=continueBoard;BoardLinkEntry=boardLink;boardAdvancing=boardLink is not null;
        IncludesCaller=includeCaller || boardSelection;StartsAtBoardSelection=boardSelection;
        evidence=evidenceDirectory;
        using(var tone=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","nudge-tone.json")))){
            var r=tone.RootElement;var p=r.GetProperty("tone_phases");
            ulong Active(int a,int b)=>p[b].GetProperty("cycle").GetUInt64()-p[a].GetProperty("cycle").GetUInt64()-(p[b].GetProperty("irq_body_cycles").GetUInt64()-p[a].GetProperty("irq_body_cycles").GetUInt64());
            if(p.GetArrayLength()!=6 || p[2].GetProperty("pc").GetString()!="5A05" || p[3].GetProperty("pc").GetString()!="5A0A")throw new InvalidDataException("Invalid timed-tone phase capture");
            toneSetupCycles=p[2].GetProperty("cycle").GetUInt64()-Convert.ToUInt64(r.GetProperty("initial").GetProperty("cycle").GetString(),16);
            toneWaitCycles=Active(2,3);toneFinishCycles=r.GetProperty("sites").GetProperty("FC4D").GetUInt64()-toneSetupCycles-toneWaitCycles;
        }
        Lamps=SkillCashPlayback.LoadLamps(evidence);
        var options=new JsonSerializerOptions{PropertyNameCaseInsensitive=true};
        var feature=JsonSerializer.Deserialize<FeatureCapture>(File.ReadAllText(Path.Combine(evidence,"skill-cash","feature-replay.json")),options)!;
        var timing=JsonSerializer.Deserialize<SharedTimingCapture>(File.ReadAllText(Path.Combine(evidence,"skill-cash","shared-timing.json")),options)!;
        using(var costs=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","cpu-interrupts.json")))) {
            siteCosts=costs.RootElement.GetProperty("sites").EnumerateObject().ToDictionary(x=>x.Name,x=>x.Value.GetUInt64());
            tokenCosts=costs.RootElement.GetProperty("tokens").EnumerateObject().ToDictionary(x=>x.Name,x=>x.Value.GetUInt64());
        }
        using(var costs=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","jackpot-probe.json")))) {
            foreach(var item in costs.RootElement.GetProperty("sites").EnumerateObject())siteCosts.TryAdd(item.Name,item.Value.GetUInt64());
            foreach(var item in costs.RootElement.GetProperty("tokens").EnumerateObject())tokenCosts.TryAdd(item.Name,item.Value.GetUInt64());
        }
        using(var data=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"maps","skill-cash-extension-data.json"))))
            foreach(var alias in data.RootElement.GetProperty("equivalent_timing_tokens").EnumerateObject())tokenCosts.Add(alias.Name,tokenCosts[alias.Value.GetString()!]);
        SeedFeature(feature);SeedScan(timing);SkillCashData.LoadExtensions(Machine,evidence);
        ushort initialClock=feature.Initial["clock"];
        if(includeCaller) {
            initialClock=SkillCashCallerState.Apply(Machine,evidence,true);
            using var caller=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","board-result.json")));
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
                using var linkCosts=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash",file)));
                foreach(var item in linkCosts.RootElement.GetProperty("sites").EnumerateObject())siteCosts.TryAdd(item.Name,item.Value.GetUInt64());
                foreach(var item in linkCosts.RootElement.GetProperty("tokens").EnumerateObject())tokenCosts.TryAdd(item.Name,item.Value.GetUInt64());
            }
            using(var nudgeData=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"maps","nudge-preparation-data.json"))))
                foreach(var alias in nudgeData.RootElement.GetProperty("equivalent_timing_tokens").EnumerateObject())tokenCosts.TryAdd(alias.Name,tokenCosts[alias.Value.GetString()!]);
            using var motionData=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"maps","dice-motion-data.json")));
            foreach(var range in motionData.RootElement.GetProperty("ranges").EnumerateObject())Convert.FromHexString(range.Value.GetString()!).CopyTo(Machine.Memory,Convert.ToUInt16(range.Name,16));
            reelMotion=new(Machine);reelHardware=new(Machine);
            using var diceData=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"maps","dice-request-data.json")));
            foreach(var token in diceData.RootElement.GetProperty("threaded_call_pacing").GetProperty("tokens").EnumerateArray())threadedCallTokens.Add(Convert.ToUInt16(token.GetString(),16));
            foreach(var alias in diceData.RootElement.GetProperty("equivalent_timing_tokens").EnumerateObject())tokenCosts.TryAdd(alias.Name,tokenCosts[alias.Value.GetString()!]);
            using var selection=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","board-selection.json")));
            foreach(var item in selection.RootElement.GetProperty("sites").EnumerateObject())siteCosts.TryAdd(item.Name,item.Value.GetUInt64());
            foreach(var item in selection.RootElement.GetProperty("tokens").EnumerateObject())tokenCosts.TryAdd(item.Name,item.Value.GetUInt64());
            using var dice=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","dice-requests.json")));
            foreach(var item in dice.RootElement.GetProperty("sites").EnumerateObject())siteCosts.TryAdd(item.Name,item.Value.GetUInt64());
            foreach(var item in dice.RootElement.GetProperty("tokens").EnumerateObject())tokenCosts.TryAdd(item.Name,item.Value.GetUInt64());
            using var motionCosts=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","dice-motion-vm.json")));
            foreach(var item in motionCosts.RootElement.GetProperty("sites").EnumerateObject())siteCosts.TryAdd(item.Name,item.Value.GetUInt64());
            foreach(var item in motionCosts.RootElement.GetProperty("tokens").EnumerateObject())tokenCosts.TryAdd(item.Name,item.Value.GetUInt64());
            using var movementCosts=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","board-movement.json")));
            foreach(var item in movementCosts.RootElement.GetProperty("sites").EnumerateObject())siteCosts.TryAdd(item.Name,item.Value.GetUInt64());
            foreach(var item in movementCosts.RootElement.GetProperty("tokens").EnumerateObject())tokenCosts.TryAdd(item.Name,item.Value.GetUInt64());
            using var nudgeCosts=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","nudge-pot-probe.json")));
            foreach(var item in nudgeCosts.RootElement.GetProperty("sites").EnumerateObject())siteCosts.TryAdd(item.Name,item.Value.GetUInt64());
            foreach(var item in nudgeCosts.RootElement.GetProperty("tokens").EnumerateObject())tokenCosts.TryAdd(item.Name,item.Value.GetUInt64());
            using var movementData=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"maps","board-movement-data.json")));
            foreach(var alias in movementData.RootElement.GetProperty("equivalent_timing_tokens").EnumerateObject())tokenCosts.TryAdd(alias.Name,tokenCosts[alias.Value.GetString()!]);
        }
        Panel=new(Machine);byte[] other=new byte[8];
        // This feature-entry fixture has no Orange/Black service buttons held.
        // DIL bits are fixed prerequisites, not player-event substitutions.
        var condition=feature.Conditions[0];other[6]=(byte)condition[7];other[7]=(byte)condition[8];Panel.SeedOtherPorts(other);
        for(int n=0;n<8;n++)Machine.Memory[n]=other[n];
        Machine.Memory[0x91]&=0x7F;
        alpha=new(Machine);scheduler=new(Machine,initialClock);
        if(boardSelection)scheduler.RestoreQueuedNativeTasks(boardLink is null ? null : at=>BoardLinkState.ResolveSoundContinuation(Machine,at));
        var response=JsonSerializer.Deserialize<LampFrameCapture>(File.ReadAllText(Path.Combine(evidence,"skill-cash","lamp-frames.json")),options)!;
        var frames=new Mpu4LampFrames(Machine,response.Responses.Select(x=>checked((byte)x)).ToArray());
        var requests=new Mpu4LampRequests(Machine,request=>{frames.Apply(request.Id,request.Pattern);LampRequests++;ObserveLamp?.Invoke(request);});
        scan=new(Machine,state=>Mpu4LampPulseSweep.Advance(state,_=>{}));
        ulong offset=0,scanAt=0;
        foreach(var row in timing.Events) {
            offset=checked(offset+row[0]);
            if(row[1]==4)scanAt=offset;
            if(row[1]==7){if(scanAt==0 || offset<scanAt)throw new InvalidDataException("Missing live IRQ timing boundary");services.Add((scanAt,offset));scanAt=0;}
        }
        if(services.Count==0)throw new InvalidDataException("Missing IRQ service template");
        // Repeat the observed service/jitter template at the source-backed
        // timer-1 period (0D70+1). This is not IRQ instruction acceptance emulation.
        servicePeriod=checked((ulong)services.Count*Mpu4Timer1Clock.Period(Mpu4Timer1Clock.NormalLatch));
        using(var interrupts=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","cpu-interrupts.json"))))
            occupancy=new(servicePeriod,interrupts.RootElement.GetProperty("intervals").EnumerateArray().Select(row=>row.EnumerateArray().Select(x=>x.GetUInt64()).ToArray()));
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
        var lamps=JsonSerializer.Deserialize<LampFrameCapture>(File.ReadAllText(Path.Combine(evidence,"skill-cash","lamp-frames.json")),options)!;
        Convert.FromHexString(lamps.Initial).CopyTo(m.Memory,0x100);
    }
    public void Resume(){if(!Completed && Fault is null)Paused=false;}
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
                ulong irq=checked(serviceEpoch+services[serviceIndex].Scan);
                ulong next=Math.Min(occupancy.NextStart,Math.Min(nextVm,Math.Min(irq,nextCallback)));if(next>target){Cycle=target;break;}Cycle=next;
                if(occupancy.NextStart==next) {
                    ulong end=occupancy.NextEnd;
                    if(lastVmInlineLiteral && !waitingForScheduler && !motionInitializing && !motionNativeReady && !TimedToneActive)Machine.Control!.PreserveInterruptDirectPage(0);
                    nextVm=waitingForScheduler ? Math.Max(nextVm,end) : checked(nextVm+(end-next));
                    occupancy.Consume();
                }
                if(nextCallback==next) {
                    if(!Mpu4TimerCallbacks.DispatchTimer3(Machine,(address,m)=>{if(address!=0x48FD)throw new NotSupportedException("Unknown live timer callback");Mpu4LampInhibit.Apply(m);}))throw new InvalidOperationException("Missing live timer callback");
                    nextCallback=ulong.MaxValue;Callbacks++;RecordLatch();
                }
                if(irq==next) {
                    scan.Advance();Scans++;RecordLatch();
                    if(Machine.ReadWord(0x32D)!=40)throw new NotSupportedException("Live timer pulse differs from captured latency template");
                    nextCallback=checked(serviceEpoch+services[serviceIndex].Callback);
                    // Input/counter/scheduler CPU phases are atomic at this explicit
                    // IRQ-service adapter. Their ordering is recovered from FE70.
                    Panel.Sample(checked((byte)Machine.ReadWord(0x28)));
                    if(reelMotion is not null) {
                        Machine.Memory[0x6E]++;
                        reelHardware!.WriteDrive();reelMotion.Service((_,_)=>reelHardware.ReadOptics(),stream=>scheduler.Queue(stream));
                        if(motionInitializing){reelMotion.Activate();motionInitializing=false;motionNativeReady=true;}
                    }
                    Machine.WriteWord(0x2D,Cell.Add(Machine.ReadWord(0x2D),1));Machine.WriteWord(0x2F,Cell.Add(Machine.ReadWord(0x2F),1));
                    Machine.Memory[0x33]=unchecked((byte)(Machine.Memory[0x33]+1));
                    if(Machine.ReadWord(0x35)!=0)Machine.WriteWord(0x35,Cell.Subtract(Machine.ReadWord(0x35),1));
                    scheduler.AdvanceTicks(1);Machine.Memory[0x2C]=0;
                    if(++serviceIndex==services.Count){serviceIndex=0;serviceEpoch=checked(serviceEpoch+servicePeriod);}
                }
                if(nextVm==next) {
                    if(--budget==0)throw new InvalidOperationException("Live dispatch budget exceeded");
                    var instruction=executor.NextInstruction!;
                    if(!ContinueBoard && boardAdvancing && instruction.Site is 0xDE96 or 0xDD38)throw new NotSupportedException($"BOARD advance completed at square {Machine.Memory[0xC9]} (type {Machine.Memory[0xA12E+Machine.Memory[0xC9]]}, nudge pot {Machine.Memory[0xBF]}); the next board result/selection is the recovery boundary. Restart to play again.");
                    if(!ContinueBoard && BoardLinkEntry is not null && instruction.Site==0xDE81)throw new NotSupportedException($"BOARD {BoardLinkEntry} completed at square {Machine.Memory[0xC9]} (nudge pot {Machine.Memory[0xBF]}); following board result/selection remains the recovery boundary. Restart to watch again.");
                    if(ContinueBoard && instruction.Site==0xE2FC && Machine.Data.Peek() is not (1 or 2))throw new NotSupportedException($"BOARD result type {Machine.Data.Peek()} at square {Machine.Memory[0xC9]}; this result route is the next recovery boundary.");
                    if(ContinueBoard && BoardLinkEntry is not null && !nudgeAttempted && instruction.Site==0xE460)throw new NotSupportedException("BOARD feature exit reached; outer machine caller remains outside the live entry.");
                    if(ContinueBoard && instruction.Native==0x2BEB && reelMotion?.Busy==true){nextVm=checked(serviceEpoch+services[serviceIndex].Scan);continue;}
                    if(ContinueBoard && instruction.Site==0xE227)throw new NotSupportedException($"BOARD special feature at square {Machine.Memory[0xC9]} (type {Machine.Memory[0xA12E+Machine.Memory[0xC9]]}); announcement/feature routing is the next recovery boundary.");
                    if(ContinueBoard && instruction.Site==0xE2E5 && (Machine.ReadWord(0xA0)&0x10)!=0 && Machine.Data.Peek() is not (1 or 2))throw new NotSupportedException($"BOARD taken result type {Machine.Data.Peek()} at square {Machine.Memory[0xC9]}; this result helper remains outside the verified routes.");
                    if(StartsAtBoardSelection && (instruction.Native is 0x61F6 or 0x61D5 or 0x61CF) && !motionNativeReady) {
                        if(!motionInitializing){
                            if(instruction.Native==0x61D5){paidCycleOpen=true;reelMotion!.PrepareAsync(value=>Mpu4InputConditions.Evaluate(Machine,value));}
                            else if(instruction.Native==0x61CF){featureEntryMotionOpen=true;reelMotion!.PrepareFeatureAsync(value=>Mpu4InputConditions.Evaluate(Machine,value));}
                            else{if(!nudgeContext)diceRequest=new(Machine.Memory[0x166],unchecked((sbyte)Machine.Memory[0x16F]),Machine.Memory[0x16E]);reelMotion!.Prepare(value=>Mpu4InputConditions.Evaluate(Machine,value));}
                            reelMotion.Enable();motionInitializing=true;
                        }
                        nextVm=checked(serviceEpoch+services[serviceIndex].Scan);continue;
                    }
                    if(instruction.Native==0x5A14 && tonePhase<4){
                        if((Machine.Memory[0x719B]&0x80)!=0)throw new NotSupportedException("Live disabled-tone pacing requires separate verification");
                        if(tonePhase==0){tonePhase=1;nextVm=checked(Cycle+toneSetupCycles);}
                        else if(tonePhase==1){AddersTimedTone.Begin(Machine,scheduler);tonePhase=2;nextVm=checked(Cycle+toneWaitCycles);}
                        else{AddersTimedTone.End(Machine,scheduler);tonePhase=4;nextVm=checked(Cycle+toneFinishCycles);}
                        continue;
                    }
                    waitingForScheduler=instruction.Native==0x5CCB && scheduler.Active;
                    if(waitingForScheduler){nextVm=checked(serviceEpoch+services[serviceIndex].Scan);continue;}
                    ulong cost=instruction.Native==0x5CCB || instruction.Native==0x5A14 ? 0 : Cost(instruction);
                    executor.Step();lastVmInlineLiteral=instruction.Operation is "vm_push_inline_byte_literal" or "vm_push_inline_word_literal";nextVm=checked(Cycle+cost);
                    if(Completed){Paused=true;Panel.Release();break;}
                }
            }
        } catch(Exception error){Fault=error.Message;Paused=true;Panel.Release();throw;}
    }
    private ulong Cost(Instruction instruction)
    {
        // Selected straight-line words now derive their CPU work from native
        // encodings. Interrupt occupancy remains the explicit captured adapter.
        if(Mpu4VmPrimitiveTiming.Cycles(instruction.Token) is ulong nativeCost)return nativeCost;
        if(siteCosts.TryGetValue(instruction.Site.ToString("X4"),out var cost) || tokenCosts.TryGetValue(instruction.Token.ToString("X4"),out cost))return cost;
        // Identical validated ROM gateway 00F8; only entry cost is shared.
        // The called body must still execute and every helper must be translated.
        if(instruction.Body is not null && instruction.PushAddress is null && threadedCallTokens.Contains(instruction.Token))return tokenCosts["9B3E"];
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

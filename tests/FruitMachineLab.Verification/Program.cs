using FruitMachineLab.Runtime;
using FruitMachineLab.Adders;

try {
var root = args.Length > 0 ? Path.GetFullPath(args[0]) : RepositoryLocation.Find(Directory.GetCurrentDirectory(),AppContext.BaseDirectory);
var evidence = Path.Combine(root,"evidence","mpu4");
var passed = 0;
void Check(string name, Action action) { action(); Console.WriteLine("PASS " + name); passed++; }
void Equal<T>(T expected,T actual) { if (!Equals(expected,actual)) throw new Exception($"Expected {expected}, got {actual}"); }
Check("Native dice motion matches each MAME service and optic read", () => {
    var result=DiceMotionVerification.Verify(evidence);Console.WriteLine($"  {result.Services} services, {result.OpticReads} optic/update operations, position {result.InitialPosition} -> {result.FinalPosition}");
});
Check("Full roll VM/lamp/sound path matches; alpha blink timing difference remains explicit", () => {
    var result=BoardSelectionVerification.Verify(evidence,diceMotion:true);Equal(false,result.AlphaExact);Equal(1,result.ReferenceAlphaBytes-result.AlphaBytes);
    Console.WriteLine($"  {result.Instructions} roll dispatches, {result.Lamps} lamp requests, {result.Sounds} sound commands; alpha {result.AlphaBytes}/{result.ReferenceAlphaBytes} bytes (one brightness restoration differs; text/cursor/reset match)");
});
Check("Driven motor model independently generates the MAME optic inputs", () => {
    DiceMotionVerification.Verify(evidence,true);
});
Check("Motor seeds agree with independently observed MAME device state", () => {
    using var capture=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","dice-motor-seeds.json")));
    var m=new SkillCashLiveSession(evidence,boardSelection:true).Machine;
    foreach(var row in capture.RootElement.GetProperty("seeds").EnumerateArray()) {
        for(int reel=0;reel<4;reel++)m.Memory[0x168+2*reel]=byte.Parse(row.GetProperty("native"+reel).GetString()!);
        var hardware=new AddersReelHardware(m);
        for(int reel=0;reel<4;reel++) {
            Equal(int.Parse(row.GetProperty("position"+reel).GetString()!),hardware.Motors[reel].Position);
            Equal(int.Parse(row.GetProperty("phase"+reel).GetString()!),hardware.Motors[reel].Phase);
        }
    }
});
Check("Motor phase direction, unpowered hold and optic boundaries preserve device mechanics", () => {
    var motor=new BarcrestStepper(0,0,9,1,3);motor.Drive(8);Equal(95,motor.Position);motor.Drive(0);Equal(95,motor.Position);
    motor.Drive(9);Equal(0,motor.Position);motor.Drive(1);Equal(1,motor.Position);Equal(false,motor.Optic);
    motor.Drive(3);Equal(2,motor.Position);Equal(true,motor.Optic);motor.Drive(2);Equal(3,motor.Position);Equal(false,motor.Optic);
    var wrapped=new BarcrestStepper(0,0,9,94,3);Equal(true,wrapped.Optic);
});
Check("Pausing mid-roll freezes VM, motor state and virtual time, then resumes to the same request", () => {
    var live=new SkillCashLiveSession(evidence,boardSelection:true);byte position=live.Machine.Memory[0x16E];live.Resume();bool paused=false,finished=false;
    try {
        for(int n=0;n<20000;n++) {
            if(live.Instructions>250)live.SetStart(true);live.AdvanceCycles(512);
            if(!paused && live.Snapshot().DiceRequest is {Busy:true} && live.Machine.Memory[0x16E]!=position) {
                live.Pause();var frozen=live.Machine.Memory.ToArray();ulong cycle=live.Cycle;int instructions=live.Instructions;
                live.AdvanceCycles(10_000_000);Equal(cycle,live.Cycle);Equal(instructions,live.Instructions);Equal(true,frozen.SequenceEqual(live.Machine.Memory));
                Equal(false,live.Panel.StartPressed);live.Resume();paused=true;
            }
        }
    }catch(NotSupportedException error){if(!error.Message.StartsWith("ROLL completed"))throw;finished=true;}
    Equal(true,paused);Equal(true,finished);var request=live.Snapshot().DiceRequest!;Equal(false,request.Busy);Equal(request.Symbol,request.DisplayedSymbol);
    Equal((byte)32,live.Machine.Memory[0xC9]);Equal((ushort)0,live.Machine.ReadWord(0xBA));Equal((ushort)0,live.Machine.ReadWord(0x2FA));
});
Check("Synthetic stuck-optic input reaches the native alignment fault instead of a fabricated completion", () => {
    var m=new SkillCashLiveSession(evidence,boardSelection:true).Machine;var motion=new AddersReelMotion(m);
    m.Memory[0x16F]=246;m.Memory[0x6A]&=0xFD;motion.Prepare(value=>Mpu4InputConditions.Evaluate(m,value));motion.Enable();motion.Activate();bool fault=false;
    try{for(int n=0;n<2000 && motion.Busy;n++){m.Memory[0x6E]++;motion.Service((_,mask)=>mask);}}
    catch(NotSupportedException error){fault=error.Message.StartsWith("Native reel alignment fault");if(!fault)throw;}
    Equal(true,fault);Equal(true,motion.Busy);
});
Check("Natural dice request computation matches MAME before physical motion", () => {
    var result=BoardSelectionVerification.Verify(evidence,true);Console.WriteLine($"  {result.Instructions} dice request dispatches, {result.Lamps} lamp requests, {result.AlphaBytes} alpha bytes; physical motion not substituted");
});
Check("Parameter profile scaling preserves native signed product boundary", () => {
    var m=new Machine();m.Memory[0x323]=128;ushort profile=0x500;m.Memory[profile+9]=255;m.Memory[profile+8]=255;
    Equal((byte)1,AddersParameterProfiles.Compute(m,profile));m.Memory[profile+9]=160;m.Memory[profile+8]=160;Equal((byte)0,AddersParameterProfiles.Compute(m,profile));
    m.Memory[profile+9]=10;m.Memory[profile+8]=100;Equal((byte)10,AddersParameterProfiles.Compute(m,profile));
});
Check("Reel symbol projection retains requests, byte wrap and busy gating", () => {
    var m=new SkillCashLiveSession(evidence).Machine;BoardSelectionState.LoadDiceData(m,evidence);
    for(int reel=0;reel<4;reel++){m.Memory[0x168+2*reel]=0;m.Memory[0x169+2*reel]=0;}
    AddersReelSymbols.Refresh(m);Equal((byte)9,m.Memory[0x166]);m.Memory[0x16F]=128;AddersReelSymbols.Refresh(m);Equal((byte)5,m.Memory[0x166]);
    AddersReelSymbols.RefreshWithoutRequests(m);Equal((byte)9,m.Memory[0x166]);Equal((byte)128,m.Memory[0x16F]);
    var before=m.Memory.ToArray();m.Memory[0x6B]=128;bool rejected=false;try{AddersReelSymbols.RefreshWithoutRequests(m);}catch(NotSupportedException){rejected=true;}
    Equal(true,rejected);Equal((byte)128,m.Memory[0x16F]);Equal(true,before[0x160..0x170].SequenceEqual(m.Memory[0x160..0x170]));
});
Check("Delayed alpha repeat preserves loop state across actual continuation", () => {
    var m=new Machine();byte[] program=[0x72,2,0x41,0x68,0,1,0x75,0x7A];program.CopyTo(m.Memory,0x5000);var alpha=new Mpu4Alpha(m);
    alpha.Execute(0x5000);Equal((byte)3,m.Memory[0x51]);Equal((ushort)1,m.ReadWord(0x35));Equal(false,alpha.Resume());
    m.WriteWord(0x35,0);Equal(true,alpha.Resume());Equal((byte)3,m.Memory[0x51]);m.WriteWord(0x35,0);Equal(true,alpha.Resume());Equal((byte)0,m.Memory[0x51]);Equal("AA",alpha.Snapshot().Text[..2]);
});
Check("Live physical Take selects Skill Cash and returns to the board-loop caller", () => {
    var live=new SkillCashLiveSession(evidence,boardSelection:true);live.Resume();int stage=0;bool took=false,held=false,returned=false;
    live.ObserveDispatch=(i,_)=>returned|=i.Site==0xE460;
    for(int n=0;n<250000 && !live.Completed;n++) {
        if(!took && live.Instructions>250){live.SetTake(true);took=true;}
        if(took && live.VmAddress is >=0xC721 and <=0xC767)live.SetTake(false);
        if(stage<3 && !held && live.Machine.Memory[0x4F]==3-stage){live.SetStart(true);held=true;}
        live.AdvanceCycles(512);if(held && live.Selections.Count>stage){live.SetStart(false);held=false;stage++;}
    }
    Equal(true,live.Completed);Equal(true,returned);Equal("3,2,1",string.Join(',',live.Selections));Equal((ushort)10,live.Machine.ReadWord(0x2FA));Equal((ushort)0,live.Machine.ReadWord(0xBA));Equal(4,live.Machine.Data.Count);Equal((ushort)0xBEEF,live.Machine.Control!.ResumeCursor);Equal(false,live.Panel.TakePressed);
});
Check("Physical Take and Start are independent sampled active-high panel inputs", () => {
    var live=new SkillCashLiveSession(evidence,boardSelection:true);live.Resume();live.SetTake(true);live.SetStart(true);Equal((byte)0x81,live.Panel.PhysicalBlack2);
    live.Panel.Sample(3);Equal(ushort.MaxValue,Mpu4InputConditions.Evaluate(live.Machine,0x1C));Equal(ushort.MaxValue,Mpu4InputConditions.Evaluate(live.Machine,0x12));
    live.SetTake(false);live.Panel.Sample(3);Equal((ushort)0,Mpu4InputConditions.Evaluate(live.Machine,0x1C));Equal(ushort.MaxValue,Mpu4InputConditions.Evaluate(live.Machine,0x12));
    live.SetTake(true);live.Pause();Equal((byte)0,live.Panel.PhysicalBlack2);Equal(false,live.Panel.TakePressed);Equal(false,live.Panel.StartPressed);
});
Check("Board Start follows the recovered roll branch to an explicit dice boundary", () => {
    var live=new SkillCashLiveSession(evidence,boardSelection:true);byte position=live.Machine.Memory[0x16E];live.Resume();bool stopped=false;
    try {for(int n=0;n<10000 && !live.Completed;n++){if(live.Instructions>250)live.SetStart(true);live.AdvanceCycles(512);}}
    catch(NotSupportedException error){stopped=error.Message.StartsWith("ROLL completed");if(!stopped)throw;}
    Equal(true,stopped);Equal(true,live.Paused);Equal(false,live.Completed);Equal(false,live.Panel.StartPressed);Equal(false,live.Panel.TakePressed);Equal(0,live.Selections.Count);
    Equal(false,(live.Machine.Memory[0x6B]&0x80)!=0);var request=live.Snapshot().DiceRequest!;Equal(true,request.Symbol is >=1 and <=12);Equal(false,position==request.PhysicalPosition);Equal(request.Symbol,request.DisplayedSymbol);Equal((ushort)0xB28F,live.VmAddress);
});
Check("Varied live roll timing generates requests without substituting outcomes", () => {
    var results=new HashSet<byte>();
    foreach(int delay in new[]{0,50,100,200,400,800,1200,2000}) {
        var live=new SkillCashLiveSession(evidence,boardSelection:true);live.Resume();bool stopped=false;
        try{for(int n=0;n<20000;n++){if(live.Instructions>250+delay)live.SetStart(true);live.AdvanceCycles(512);}}
        catch(NotSupportedException error){if(!error.Message.StartsWith("ROLL completed"))throw;stopped=true;}
        Equal(true,stopped);var request=live.Snapshot().DiceRequest!;Equal(true,request.Symbol is >=1 and <=12);results.Add(request.Symbol);
    }
    Equal(true,results.Count>1);Console.WriteLine("  Live requested dice symbols: "+string.Join(',',results.Order()));
});
Check("Captured scheduler restore rejects unknown continuation shapes", () => {
    var m=new Machine();m.WriteWord(0x47,0x1A0);m.WriteWord(0x1A4,0x1234);var scheduler=new Mpu4ChoiceStreamScheduler(m,0);bool rejected=false;
    try{scheduler.RestoreQueuedNativeTasks();}catch(NotSupportedException){rejected=true;}Equal(true,rejected);
});
Check("Natural board selection, take, Skill Cash and board return match MAME", () => {
    var result=BoardSelectionVerification.Verify(evidence);Console.WriteLine($"  {result.Instructions} board VM dispatches (uninitialized-local exclusions), {result.Lamps} lamp requests, {result.Sounds} sound commands, {result.AlphaBytes} alpha bytes and {result.Conditions} input conditions checked");
});
Check("Captured physical VM frames resume through recovered continuation owners", () => {
    var catalog=new RecoveredScriptCatalog(Path.Combine(evidence,"VM-SCRIPTS"));
    var m=new Machine();m.Control=new(m,0x780);m.WriteWord(0x780,0xBEEF);m.Control.EnterCall(0x99AB);
    var seen=new List<ushort>();var executor=new ScriptExecutor(m){BeforeInstruction=(i,_)=>seen.Add(i.Site)};
        executor.BeginResumed(catalog.Owner(0xA8F5),0xA8F5,catalog.Owner,0xBEEF);
    Equal(0,seen.Count);executor.Step();Equal((ushort)0x99AB,executor.NextInstruction!.Site);executor.Step();
    Equal(true,executor.Completed);Equal("A8F5,99AB",string.Join(',',seen.Select(x=>x.ToString("X4"))));Equal((ushort)0x782,m.Control.Pointer);
});
Check("Natural cash-feature caller entry matches MAME before Skill Cash", () => {
    var result=SkillCashCallerVerification.Verify(evidence);
    Console.WriteLine($"  {result.EntryInstructions} caller entry dispatches, {result.AlphaBytes} alpha bytes, {result.SoundCommands} sound commands; {result.ExitInstructions} captured exit dispatches retained");
});
Check("Natural board-result wrapper matches MAME and routes the taken cash feature", () => {
    var result=SkillCashCallerVerification.Verify(evidence,true);
    Console.WriteLine($"  {result.EntryInstructions} board/caller entry dispatches, {result.AlphaBytes} alpha bytes and {result.SoundCommands} sound commands checked");
});
Check("Live board dispatcher announces Skill Cash and returns through its actual caller", () => {
    var live=new SkillCashLiveSession(evidence,true);live.Resume();int stage=0;bool held=false,announced=false,sawReturn=false,returning=false;int exits=0;
    using var capture=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","board-result.json")));
    var exitRows=capture.RootElement.GetProperty("rows").EnumerateArray().SkipWhile(row=>row[0].GetInt32()!=0x76BD).Where(row=>row[0].GetInt32()!=0x76BD).ToArray();
    live.ObserveAlpha=state=>announced|=state.Text.Contains("SKILL CASH");
    live.ObserveDispatch=(i,m)=>{
        sawReturn|=i.Site==0xE0BF;
        if(i.Site==0xC767){returning=true;return;}
        if(!returning)return;
        var expected=exitRows[exits++];var cells=m.Data.ToArray();
        ushort[] actual=[i.Site,i.Token,cells[0],cells[1],cells[2],cells[3],m.DataPointer,m.Control!.Pointer,m.LocalFrame,m.Control.LoopFrame,m.ReadWord(m.LocalFrame)];
        for(int n=0;n<actual.Length;n++)Equal(expected[n].GetInt32(),(int)actual[n]);
        Equal(expected[17].GetInt32(),(int)m.ReadWord(0xBA));Equal(expected[18].GetInt32(),(int)m.ReadWord(0x2FA));
        Equal(expected[22].GetInt32(),(int)m.ReadWord(0x327));Equal(expected[23].GetInt32(),(int)m.ReadWord(0xA0));
    };
    for(int n=0;n<250000 && !live.Completed;n++) {
        if(stage<3 && !held && live.Machine.Memory[0x4F]==3-stage){live.SetStart(true);held=true;}
        live.AdvanceCycles(512);if(held && live.Selections.Count>stage){live.SetStart(false);held=false;stage++;}
    }
    Equal(true,live.Completed);Equal(true,announced);Equal(true,sawReturn);Equal("3,2,1",string.Join(',',live.Selections));
    Equal((ushort)10,live.Machine.ReadWord(0x2FA));Equal((ushort)0,live.Machine.ReadWord(0xBA));Equal(4,live.Machine.Data.Count);Equal((ushort)0xBEEF,live.Machine.Control!.ResumeCursor);
    Equal(exitRows.Length,exits);
});
Check("Recovered board take flag can suppress cash-feature execution", () => {
    var live=new SkillCashLiveSession(evidence,true);live.Machine.WriteWord(0xA0,(ushort)(live.Machine.ReadWord(0xA0)&~0x10));live.Resume();
    for(int n=0;n<10000 && !live.Completed;n++)live.AdvanceCycles(512);
    Equal(true,live.Completed);Equal(0,live.Selections.Count);Equal((ushort)0,live.Machine.ReadWord(0x2FA));Equal(4,live.Machine.Data.Count);Equal((ushort)0xBEEF,live.Machine.Control!.ResumeCursor);
});
Check("Synthetic MAME jackpot announcement matches VM, lamp, sound and alpha evidence", () => {
    var result=SkillCashJackpotProbeVerification.Verify(evidence);
    Console.WriteLine($"  {result.Instructions} lifted VM dispatches, {result.LampRequests} lamp requests, {result.SoundCommands} sound commands and {result.SerialBytes} alpha bytes checked; synthetic invocation, not a reached jackpot award");
});
Check("Recovered board cash-feature selector maps Skill Cash and all named positions", () => {
    byte[] positions=[4,9,12,19,26,32,37,42,47];
    for(int n=0;n<positions.Length;n++)Equal((ushort)n,AddersCashFeatureDispatch.Select(evidence,positions[n]).Index);
    Equal((ushort)0xC71F,AddersCashFeatureDispatch.Select(evidence,32).Token);Equal((ushort)0,AddersCashFeatureDispatch.Select(evidence,255).Index);
});
Check("Live six-pound Skill Cash executes the recovered jackpot announcement", () => {
    var live=new SkillCashLiveSession(evidence);live.Resume();int stage=0;bool held=false;bool sawAnnouncement=false;
    live.ObserveAlpha=state=>{if(state.Text.Contains("JACKPOT"))sawAnnouncement=true;};
    for(int n=0;n<200000 && !live.Completed;n++) {
        if(stage<3 && !held && live.Machine.Memory[0x4F]==6){live.SetStart(true);held=true;}
        live.AdvanceCycles(512);
        if(held && live.Selections.Count>stage){live.SetStart(false);held=false;stage++;}
    }
    Equal(true,live.Completed);Equal("6,6,6",string.Join(',',live.Selections));Equal(true,sawAnnouncement);Equal((ushort)60,live.Machine.ReadWord(0x2FA));Equal((ushort)0,live.Machine.ReadWord(0xBA));
    Equal(4,live.Machine.Data.Count);Equal((ushort)0xBEEF,live.Machine.Control!.ResumeCursor);
    Console.WriteLine($"  Live six-pound run completed in {live.Cycle/SkillCashLiveSession.CyclesPerSecond:0.000} virtual seconds; synthetic player timing, not a MAME jackpot campaign");
});
Check("Live player inputs cover every default Skill Cash award level", () => {
    ushort[] awards=[0,10,16,20,22,30,60];
    foreach(int entry in new[]{0,1,2})
    for(byte level=1;level<=6;level++) {
        var live=new SkillCashLiveSession(evidence,entry>=1,entry==2);live.Resume();int stage=0;bool held=false,took=false;
        for(int n=0;n<200000 && !live.Completed;n++) {
            if(entry==2 && !took && live.Instructions>250){live.SetTake(true);took=true;}
            if(entry==2 && live.VmAddress is >=0xC721 and <=0xC767)live.SetTake(false);
            if(stage<3 && !held && live.Machine.Memory[0x4F]==level){live.SetStart(true);held=true;}
            live.AdvanceCycles(512);if(held && live.Selections.Count>stage){live.SetStart(false);held=false;stage++;}
        }
        Equal(true,live.Completed);Equal(awards[level],live.Machine.ReadWord(0x2FA));Equal((ushort)0,live.Machine.ReadWord(0xBA));Equal(4,live.Machine.Data.Count);
    }
});
Check("Recovered lamp save/restore retains the physical U stack and caller cells", () => {
    var m=new Machine{DataStackBase=0x680};m.Data.Push(0x1234);m.Data.Push(0x5678);m.Data.Push(0x9ABC);m.Data.Push(0xDEF0);
    for(int n=0;n<64;n++)m.Memory[0x100+n]=(byte)(n*3);
    var original=m.Memory[0x100..0x140];var cells=m.Data.ToArray();ushort pointer=m.DataPointer;
    m.Control=new(m,0x7A0);m.WriteWord(0x7A0,0xBEEF);new ScriptExecutor(m).Run(new(Path.Combine(evidence,"VM-SCRIPTS","9B40.txt")));
    Equal(Cell.Subtract(pointer,64),m.DataPointer);Equal(36,m.Data.Count);
    Array.Clear(m.Memory,0x100,64);m.Control=new(m,0x7A0);m.WriteWord(0x7A0,0xBEEF);
    new ScriptExecutor(m).Run(new(Path.Combine(evidence,"VM-SCRIPTS","9B58.txt")));
    Equal(pointer,m.DataPointer);Equal(true,cells.SequenceEqual(m.Data));Equal(true,original.SequenceEqual(m.Memory[0x100..0x140]));
});
Check("Native byte move preserves overlap direction and address wrap", () => {
    var m=new Machine();for(int n=0;n<8;n++)m.Memory[n]=(byte)n;
    Mpu4Memory.Move(m,0,2,6);Equal("0001000102030405",Convert.ToHexString(m.Memory[..8]));
    Mpu4Memory.Move(m,2,0,6);Equal("000102030405",Convert.ToHexString(m.Memory[..6]));
    m.Memory[65535]=0xAB;m.Memory[0]=0xCD;Mpu4Memory.Move(m,65535,100,2);Equal((byte)0xAB,m.Memory[100]);Equal((byte)0xCD,m.Memory[101]);
});
Check("Alpha delayed continuation resumes only after the IRQ counter expires", () => {
    var m=new Machine();SkillCashData.LoadAlpha(m);SkillCashData.LoadExtensions(m,evidence);var bytes=new List<byte>();var alpha=new Mpu4Alpha(m,bytes.Add);
    alpha.Reset();bytes.Clear();alpha.Execute(0xA310);Equal((ushort)25,m.ReadWord(0x35));Equal((ushort)0xA314,m.ReadWord(0x52));Equal((byte)0xE0,bytes.Single());
    Equal(false,alpha.Resume());m.WriteWord(0x35,0);Equal(true,alpha.Resume());Equal((byte)0xFF,bytes[^1]);Equal((ushort)25,m.ReadWord(0x35));
    m.WriteWord(0x35,0);Equal(true,alpha.Resume());Equal((byte)0xE0,bytes[^1]);
});
Check("Lamp stream commands retain equality guards and reset frame counters", () => {
    var m=new Machine();m.Memory[0x25]=5;m.Memory[0x24]=2;m.Memory[0x27]=4;SkillCashData.LoadExtensions(m,evidence);
    var requests=new Mpu4LampRequests(m,_=>throw new Exception("Unexpected lamp request"));Equal((ushort)0x9C5F,requests.ExecuteStream(0x9C5A));
    Equal((byte)2,m.Memory[0x24]);Equal((byte)0,m.Memory[0x26]);Equal((byte)0,m.Memory[0x27]);
    m.Memory[0x400]=0x92;m.Memory[0x401]=255;m.Memory[0x402]=0x93;m.Memory[0x23]=3;
    requests.ExecuteStream(0x400);Equal((byte)0,m.Memory[0x26]);Equal((byte)1,m.Memory[0x24]);Equal((byte)0,m.Memory[0x23]);
});
Check("Diatonic sound transpose preserves octave shifts and zero reset", () => {
    Equal((byte)0xF4,Mpu4ChoiceStreamScheduler.DiatonicTranspose(0,0xF9));Equal((byte)0xE8,Mpu4ChoiceStreamScheduler.DiatonicTranspose(0xF4,0xF9));
    Equal((byte)12,Mpu4ChoiceStreamScheduler.DiatonicTranspose(0,7));Equal((byte)0,Mpu4ChoiceStreamScheduler.DiatonicTranspose(0xE8,0));
});
Check("Captured IRQ occupancy repeats outer intervals and rejects overlap", () => {
    var irq=new CapturedInterruptOccupancy(100,new[]{new[]{10UL,20UL},new[]{50UL,5UL}});Equal(10UL,irq.NextStart);Equal(30UL,irq.NextEnd);irq.Consume();Equal(50UL,irq.NextStart);irq.Consume();Equal(110UL,irq.NextStart);
    try{_=new CapturedInterruptOccupancy(100,new[]{new[]{10UL,20UL},new[]{20UL,5UL}});}catch(InvalidDataException){return;}
    throw new Exception("Overlapping outer IRQ intervals accepted");
});
Check("Live Start is active-high mux input with sticky ROM panel accumulation", () => {
    var machine=new Machine();SkillCashData.LoadFeature(machine);var panel=new Mpu4PanelInput(machine);
    panel.SetStart(true);Equal((byte)0x80,panel.PhysicalBlack2);Equal((byte)0,machine.Memory[3]);
    panel.Sample(2);Equal((byte)0,machine.Memory[3]);panel.Sample(3);Equal((byte)0x80,machine.Memory[3]);Equal((ushort)0x80,machine.ReadWord(0x90));
    Equal((ushort)1,Mpu4InputConditions.Evaluate(machine,0x1E));
    panel.Release();panel.Sample(3);Equal((byte)0,machine.Memory[3]);Equal((ushort)0x80,machine.ReadWord(0x90));Equal((ushort)0,Mpu4InputConditions.Evaluate(machine,0x1E));
});
Check("Live pause suspends actual VM, memory and virtual clock", () => {
    var live=new SkillCashLiveSession(evidence);Equal(0,live.Instructions);live.Resume();live.AdvanceCycles(50000);live.Pause();
    var cycle=live.Cycle;int instructions=live.Instructions;var memory=live.Machine.Memory.ToArray();var stack=live.Machine.Data.ToArray();
    live.Advance(TimeSpan.FromSeconds(1));Equal(cycle,live.Cycle);Equal(instructions,live.Instructions);Equal(true,memory.SequenceEqual(live.Machine.Memory));Equal(true,stack.SequenceEqual(live.Machine.Data));
    live.Resume();live.AdvanceCycles(50000);Equal(true,live.Cycle>cycle);Equal(true,live.Instructions>instructions);
});
Check("Live held Start waits for actual sampled release before the next stage", () => {
    var live=new SkillCashLiveSession(evidence);live.Resume();
    for(int n=0;n<10000 && live.Machine.Memory[0x4F]!=3;n++)live.AdvanceCycles(512);
    live.SetStart(true);
    for(int n=0;n<10000 && live.Selections.Count==0;n++)live.AdvanceCycles(512);
    Equal(1,live.Selections.Count);live.Advance(TimeSpan.FromMilliseconds(100));Equal(1,live.Selections.Count);Equal((byte)0x80,live.Machine.Memory[3]);
    Equal(true,live.VmAddress is >=0x9986 and <=0x998D);
    live.SetStart(false);live.Advance(TimeSpan.FromMilliseconds(30));Equal((byte)0,live.Machine.Memory[3]);Equal(false,live.Panel.StartPressed);
    live.SetStart(true);live.Pause();Equal(false,live.Panel.StartPressed);Equal((byte)0,live.Panel.PhysicalBlack2);
});
Check("Live player timing can select a different recovered award", () => {
    var live=new SkillCashLiveSession(evidence);live.Resume();bool pressed=false;int stage=0;
    for(int n=0;n<200000 && !live.Completed;n++) {
        if(stage<3 && !pressed && live.Machine.Memory[0x4F]==2){live.SetStart(true);pressed=true;}
        live.AdvanceCycles(512);
        if(pressed && live.Selections.Count>stage){live.SetStart(false);pressed=false;stage++;}
    }
    Equal(true,live.Completed);Equal("2,2,2",string.Join(',',live.Selections));Equal((ushort)16,live.Machine.ReadWord(0x2FA));Equal((ushort)0,live.Machine.ReadWord(0xBA));
});
Check("Live physical Start selections execute award accounting without recorded input events", () => {
    var live=new SkillCashLiveSession(evidence);live.Resume();ushort[] targets=[3,2,1];bool pressed=false;int stage=0;
    var texts=new List<string>();live.ObserveAlpha=state=>texts.Add(state.Text);
    for(int n=0;n<200000 && !live.Completed;n++) {
        if(stage<targets.Length && !pressed && live.Machine.Memory[0x4F]==targets[stage]){live.SetStart(true);pressed=true;}
        live.AdvanceCycles(512);
        if(pressed && live.Selections.Count>stage){live.SetStart(false);pressed=false;stage++;}
    }
    if(live.Fault is not null)throw new Exception(live.Fault);
    Equal(true,live.Completed);Equal("3,2,1",string.Join(',',live.Selections));Equal((ushort)0,live.Machine.ReadWord(0xBA));Equal((ushort)10,live.Machine.ReadWord(0x2FA));
    Equal((ushort)0xBEEF,live.Machine.Control!.ResumeCursor);Equal(false,live.Panel.StartPressed);
    var reference=SkillCashFeatureReplay.Run(evidence);Equal(true,texts.SequenceEqual(reference.AlphaFrames.Select(x=>x.State.Text)));
    Console.WriteLine($"  Live choices {string.Join(',',live.Selections)}, {live.Instructions} dispatches, {live.Cycle/SkillCashLiveSession.CyclesPerSecond:0.000} s; alpha sequence and final accounting match reference selections");
});
Check("Live run compares reference-time physical Start pulses without substituting captured latches", () => {
    var timing=System.Text.Json.JsonSerializer.Deserialize<SharedTimingCapture>(File.ReadAllText(Path.Combine(evidence,"skill-cash","shared-timing.json")),new System.Text.Json.JsonSerializerOptions{PropertyNameCaseInsensitive=true})!;
    double entry=timing.InitialCycle/SkillCashLiveSession.CyclesPerSecond;
    var pulses=File.ReadLines(Path.Combine(evidence,"skill-cash","actions.csv")).Skip(1).Select(line=>line.Split(',')).Where(row=>row[2]==":BLACK2" && row[3]=="128")
        .Select(row=>(Start:long.Parse(row[0])/60.0-entry,End:(long.Parse(row[1])+1)/60.0-entry)).Where(pulse=>pulse.End>=0 && pulse.Start<13).ToArray();
    ushort[] sites=[0xC757,0xC761,0xC710,0xAFC2,0xC767];int[] fields=[0,1,2,3,4,5,6,7,8,9,10,15,17,18,20,21,22,23];
    var referenceStates=new List<string>();var reference=SkillCashFeatureReplay.Run(evidence,observe:(_,signature)=>{if(sites.Contains(signature[0]))referenceStates.Add(string.Join(',',fields.Select(n=>signature[n])));});
    var initial=System.Text.Json.JsonSerializer.Deserialize<FeatureCapture>(File.ReadAllText(Path.Combine(evidence,"skill-cash","feature-replay.json")),new System.Text.Json.JsonSerializerOptions{PropertyNameCaseInsensitive=true})!.Initial;
    var liveStates=new List<string>();var live=new SkillCashLiveSession(evidence);live.Resume();var alpha=new List<AlphaState>();live.ObserveAlpha=alpha.Add;
    live.ObserveDispatch=(instruction,m)=> {
        if(!sites.Contains(instruction.Site))return;var cells=m.Data.ToArray();
        ushort[] signature=[instruction.Site,instruction.Token,cells[0],cells[1],cells[2],cells[3],unchecked((ushort)(initial["u"]-2*(cells.Length-4))),
            m.Control!.Pointer,m.LocalFrame,m.Control.LoopFrame,m.ReadWord(m.LocalFrame),m.ReadWord(0x2D),m.Memory[0x33],m.ReadWord(0x324),m.Memory[0x4F],m.Memory[0x4E],m.ReadWord(0x90),m.ReadWord(0xBA),m.ReadWord(0x2FA),m.Memory[0x2C],m.Memory[0x322],m.Memory[0x323],m.ReadWord(0x327),m.ReadWord(0xA0)];
        liveStates.Add(string.Join(',',fields.Select(n=>signature[n])));
    };
    for(int n=0;n<50000 && !live.Completed;n++) {
        double now=live.Cycle/SkillCashLiveSession.CyclesPerSecond;live.SetStart(pulses.Any(p=>now>=p.Start && now<=p.End));live.AdvanceCycles(512);
    }
    Equal(true,live.Completed);
    Equal("3,2,1",string.Join(',',live.Selections));Equal((ushort)10,live.Machine.ReadWord(0x2FA));Equal((ushort)0,live.Machine.ReadWord(0xBA));
    Equal(true,referenceStates.SequenceEqual(liveStates));Equal(true,reference.AlphaFrames.Select(x=>x.State).SequenceEqual(alpha));
    byte[]? referenceFrames=null;SkillCashLampFrameVerification.Verify(evidence,(_,frames)=>referenceFrames=frames.ToArray());
    Equal(Convert.ToHexString(referenceFrames!),Convert.ToHexString(live.Machine.Memory[0x100..0x140]));
    Console.WriteLine($"  Reference-time pulses: {liveStates.Count} VM/frame/accounting checkpoints, 44 alpha states and final lamp frames match; {live.Instructions} dispatches, {live.Cycle/SkillCashLiveSession.CyclesPerSecond:0.000} s; full CPU state equality is not claimed");
});
Check("Verified playback exposes timed lamps, alpha and mapped captions", () => {
    var replay=SkillCashPlayback.Load(evidence);Equal(12207,replay.Output.LampFrameCount);Equal(45,replay.Output.AlphaFrameCount);Equal(128,replay.Lamps.Count);
    Equal("SKILL CASH",replay.Lamps[83].Caption);Equal((byte)0x6F,replay.Lamps[47].LogicalId);
    var end=replay.Output.Sample(replay.Output.DurationCycles);Equal((ushort)10,end.CurrentWin);Equal((ushort)0,end.Pending);
    Equal(true,replay.Output.DurationSeconds>10);Equal(true,replay.Output.DurationSeconds<30);
    Equal(true,Enumerable.Range(1,100).Select(n=>replay.Output.Sample(replay.Output.DurationCycles*(ulong)n/100).LampDuty[47]).Any(x=>x>0));
    Console.WriteLine($"  {replay.Output.DurationSeconds:0.000} s at 1×, {replay.Output.LampFrameCount} lamp latch frames, {replay.Output.AlphaFrameCount} alpha states");
});
Check("Lamp persistence integrates multiplexing and callback masking without seek history", () => {
    var replay=new OutputPlayback(100,new[]{new LampLatchFrame(0,0,1,2),new LampLatchFrame(10,1,1,0),new LampLatchFrame(20,1,0,0)},new[]{new AlphaPlaybackFrame(0,"initial",0,0),new AlphaPlaybackFrame(20,"award",0,10)});
    var sample=replay.Sample(30,30);Equal(1.0/3,sample.LampDuty[0]);Equal(1.0/3,sample.LampDuty[65]);Equal(1.0/3,sample.LampDuty[8]);Equal("award",sample.Alpha);
    Equal(0.0,replay.Sample(60,30).LampDuty.Sum());Equal("initial",replay.Sample(10).Alpha);
    Equal(sample.LampDuty[8],replay.Sample(30,30).LampDuty[8]);
});
Check("Playback transport pauses, changes speed, clamps end and restarts", () => {
    var transport=new PlaybackTransport(10);transport.Play();transport.Advance(TimeSpan.FromSeconds(2));Equal(2.0,transport.PositionSeconds);
    transport.Pause();transport.Advance(TimeSpan.FromSeconds(3));Equal(2.0,transport.PositionSeconds);
    transport.Speed=2;transport.Play();transport.Advance(TimeSpan.FromSeconds(3));Equal(8.0,transport.PositionSeconds);
    transport.Advance(TimeSpan.FromSeconds(2));Equal(10.0,transport.PositionSeconds);Equal(false,transport.IsPlaying);
    transport.Play();Equal(0.0,transport.PositionSeconds);transport.Seek(5);Equal(5.0,transport.PositionSeconds);
});
Check("Playback rejects missing initial outputs, reversed timestamps and invalid speed", () => {
    int rejected=0;
    foreach(var frames in new[]{new[]{new LampLatchFrame(1,0,0,0)},new[]{new LampLatchFrame(0,0,0,0),new LampLatchFrame(5,0,0,0),new LampLatchFrame(4,0,0,0)},new[]{new LampLatchFrame(0,8,0,0)}}) {
        try{_ = new OutputPlayback(10,frames,new[]{new AlphaPlaybackFrame(0,"",0,0)});}catch(InvalidDataException){rejected++;}
    }
    var transport=new PlaybackTransport(10);try{transport.Speed=double.NaN;}catch(ArgumentOutOfRangeException){rejected++;}
    Equal(4,rejected);
});
Check("Timer-3 reference deadline separates initial output phase and IRQ expiry", () => {
    var low=Mpu4Timer3Deadline.Calculate(100,40,false);Equal(108UL,low.FirstEdge);Equal(428UL,low.Interrupt);
    var high=Mpu4Timer3Deadline.Calculate(100,40,true);Equal(420UL,high.FirstEdge);Equal(420UL,high.Interrupt);
    Equal(108UL,Mpu4Timer3Deadline.Calculate(100,0,false).Interrupt);
    Equal(524388UL,Mpu4Timer3Deadline.Calculate(100,65535,false).Interrupt);
});
Check("Timer-3 deadline refuses unsupported controls and timestamp overflow", () => {
    bool unsupported=false,overflow=false;
    try {Mpu4Timer3Deadline.Calculate(0,40,false,0x62);}catch(NotSupportedException){unsupported=true;}
    try {Mpu4Timer3Deadline.Calculate(ulong.MaxValue,40,false);}catch(OverflowException){overflow=true;}
    Equal(true,unsupported);Equal(true,overflow);
});
Check("Shared VM, lamp writes, IRQ scans and timer callbacks match MAME", () => {
    var result=SkillCashSharedTimingVerification.Verify(evidence);
    Equal(98704,result.Instructions);Equal(29192,result.LampWrites);Equal(6103,result.Scans);
    Console.WriteLine($"  {result.LampWrites} lamp writes, {result.Scans} scans, {result.Arms} arms and {result.Callbacks} callbacks on one timeline");
});
Check("Actual timer latch writes are consistent with the reference countdown", () => {
    var result=SkillCashTimerDeadlineVerification.Verify(evidence);Equal(6103,result.Arms);
    Equal(18UL,result.MinimumIrqLatency);Equal(25UL,result.MaximumIrqLatency);
    Equal(128UL,result.MinimumCallbackService);Equal(128UL,result.MaximumCallbackService);
    Console.WriteLine($"  {result.Arms} actual latch writes; calculated expiry to IRQ latency {result.MinimumIrqLatency}–{result.MaximumIrqLatency} cycles");
});
Check("Early timer IRQ and reversed latch timestamps are rejected", () => {
    int rejected=0;
    foreach(var rows in new[]{new ulong[][]{new ulong[]{100,40,327,128,0}},new ulong[][]{new ulong[]{100,40,350,128,0},new ulong[]{99,40,350,128,0}}}) {
        try {SkillCashTimerDeadlineVerification.Verify(new TimerDeadlineCapture(0,rows));}catch(InvalidDataException){rejected++;}
    }
    Equal(2,rejected);
});
Check("Captured cycle timeline preserves source order and rejects time reversal", () => {
    var clock=new CapturedCycleTimeline(100,new ulong[][]{new[]{2UL,0UL},new[]{0UL,1UL},new[]{3UL,2UL}});
    var events=new List<int>();clock.AdvanceTo(102,item=>{Equal(102UL,clock.Now);events.Add(item.Sequence);});
    Equal("0,1",string.Join(',',events));Equal(1,clock.Remaining);
    try {clock.AdvanceTo(101,_=>{});}catch(InvalidDataException){clock.AdvanceTo(105,item=>events.Add(item.Sequence));Equal(0,clock.Remaining);return;}
    throw new Exception("Clock reversal accepted");
});
Check("Timer callback masks current scan outputs without changing frame memory", () => {
    var m=new Machine();m.WriteWord(0x28,7);m.Memory[0x147]=0x0F;m.Memory[0x14F]=0xF0;m.Memory[0xB2]=1;
    m.Memory[0xA00]=0xF7;m.Memory[0xA02]=0x3F;m.Memory[0xB00]=0xFF;m.Memory[0x107]=0x5A;
    Mpu4LampInhibit.Apply(m);Equal((byte)7,m.Memory[0xA00]);Equal((byte)0x30,m.Memory[0xA02]);Equal((byte)0,m.Memory[0xB00]);Equal((byte)0x5A,m.Memory[0x107]);
});
Check("Captured timeline rejects incomplete event payloads", () => {
    var clock=new CapturedCycleTimeline(0,new ulong[][]{new[]{1UL}});
    try {clock.AdvanceTo(1,_=>{});}catch(InvalidDataException){return;}
    throw new Exception("Malformed cycle event accepted");
});
Check("Timer-3 dispatch disables the timer and preserves the native address gate", () => {
    var m=new Machine();m.Memory[0x3F]=0xFF;m.Memory[0x40]=0x63;m.WriteWord(0x3D,0x13FF);
    Equal(false,Mpu4TimerCallbacks.DispatchTimer3(m,(_,_)=>throw new Exception("Suppressed callback invoked")));
    Equal((byte)0xFE,m.Memory[0x3F]);Equal((byte)0,m.Memory[0x40]);
    m.WriteWord(0x3D,0x48FD);int calls=0;
    Equal(true,Mpu4TimerCallbacks.DispatchTimer3(m,(address,state)=>{Equal((ushort)0x48FD,address);Equal((byte)0,state.Memory[0x40]);calls++;}));Equal(1,calls);
});
Check("Changed timed callback output rejects shared-memory replay", () => {
    var capture=System.Text.Json.JsonSerializer.Deserialize<SharedTimingCapture>(File.ReadAllText(Path.Combine(evidence,"skill-cash","shared-timing.json")),
        new System.Text.Json.JsonSerializerOptions{PropertyNameCaseInsensitive=true})!;
    capture.Events.First(row=>row[1]==7)[3]^=1;
    var temporary=Path.Combine(Path.GetTempPath(),"FruitMachineLab-"+Guid.NewGuid());
    try {
        Directory.CreateDirectory(Path.Combine(temporary,"skill-cash"));Directory.CreateDirectory(Path.Combine(temporary,"VM-SCRIPTS"));
        foreach(var source in Directory.GetFiles(Path.Combine(evidence,"VM-SCRIPTS"),"*.txt"))File.Copy(source,Path.Combine(temporary,"VM-SCRIPTS",Path.GetFileName(source)));
        foreach(var name in new[]{"feature-replay.json","feature-sound.json","compensation-calls.json","alpha-calls.json","lamp-frames.json"})File.Copy(Path.Combine(evidence,"skill-cash",name),Path.Combine(temporary,"skill-cash",name));
        File.WriteAllText(Path.Combine(temporary,"skill-cash","shared-timing.json"),System.Text.Json.JsonSerializer.Serialize(capture));
        try {SkillCashSharedTimingVerification.Verify(temporary);}catch(InvalidDataException){return;}
        throw new Exception("Changed timed callback output accepted");
    } finally {if(Directory.Exists(temporary))Directory.Delete(temporary,true);}
});
Check("Native alpha software state and serial bytes match MAME", () => {
    var result=SkillCashAlphaVerification.Verify(evidence);Equal(44,result.Calls);
    Console.WriteLine($"  {result.Calls} alpha calls and {result.Bytes} serial bytes checked");
});
Check("Alpha punctuation attaches to prior cell and preserves cursor wrap", () => {
    var m=new Machine();var serial=new List<byte>();var alpha=new Mpu4Alpha(m,serial.Add);
    alpha.Reset();Equal(19,serial.Count);alpha.SelectCursor(15);alpha.Put(0x41);Equal((byte)0,m.Memory[0x54]);
    alpha.Put(0x2E);Equal((byte)0x81,m.Memory[0x67]);Equal((byte)0,m.Memory[0x54]);
    alpha.Put(0x2C);Equal((byte)0xC1,m.Memory[0x67]);Equal((byte)0,m.Memory[0x54]);
    Equal("               A,",alpha.Snapshot().Text);
});
Check("Alpha numeric leading fill, decimal placement and digit mirror", () => {
    var m=new Machine();SkillCashData.LoadAlpha(m);var alpha=new Mpu4Alpha(m);
    alpha.Reset();m.WriteWord(0x327,326);m.Memory[0xC5]=1;m.Memory[0xC4]=3;
    alpha.Execute(0xA814);Equal(" 32.60"+new string(' ',11),alpha.Snapshot().Text);
    Equal((byte)0x7D,m.Memory[0x1A]);Equal((byte)0x5B,m.Memory[0x1B]);Equal((byte)255,m.Memory[0xC4]);
    m.Memory[0xC5]=0;m.WriteWord(0x327,0);alpha.Execute(0xA814);Equal("  0.00"+new string(' ',11),alpha.Snapshot().Text);
});
Check("IRQ lamp/digit scan matches MAME transitions and port latches", () => {
    var result=SkillCashOutputScanVerification.Verify(evidence);
    Console.WriteLine($"  {result.Scans} output scans and {result.PulseCalls} pulse-width calls checked");
});
Check("Output scan suppression, alternating counters and inhibition", () => {
    var m=new Machine();SkillCashData.LoadScan(m);var scan=new Mpu4OutputScan(m);
    m.Memory[0x8D]=1;m.Memory[0xA00]=0x55;scan.Advance();Equal((byte)0x55,m.Memory[0xA00]);Equal((ushort)0,m.ReadWord(0x28));
    m.Memory[0x8D]=0;m.Memory[0xB01]=0xB4;m.WriteWord(0x28,7);m.Memory[0x27]=2;m.Memory[0x26]=1;m.Memory[0x24]=1;m.Memory[0x25]=3;
    m.Memory[0x130]=0xA5;m.Memory[0x138]=0x5A;m.Memory[0x1A]=0x3F;m.Memory[0x22]=1;
    scan.Advance();Equal((byte)3,m.Memory[0x23]);Equal((byte)2,m.Memory[0x26]);Equal((byte)3,m.Memory[0x24]);
    Equal((byte)0xA5,m.Memory[0xA00]);Equal((byte)0x5A,m.Memory[0xA02]);Equal((byte)0xBF,m.Memory[0xB00]);
    Equal((byte)0xB4,m.Memory[0xB01]);
    m.Memory[0x2BE]=8;m.WriteWord(0x28,7);m.Memory[8]=4;scan.Advance();
    Equal((byte)0,m.Memory[0xA00]);Equal((byte)0,m.Memory[0xA02]);Equal((byte)0x80,m.Memory[0xB00]);
});
Check("Changed scan lamp input is rejected against the native output digest", () => {
    var capture=System.Text.Json.JsonSerializer.Deserialize<ScanCapture>(File.ReadAllText(Path.Combine(evidence,"skill-cash","output-scan.json")),
        new System.Text.Json.JsonSerializerOptions{PropertyNameCaseInsensitive=true})!;
    var bytes=Convert.FromHexString(capture.Initial["frames"]);bytes[17]^=1;capture.Initial["frames"]=Convert.ToHexString(bytes);
    var temporary=Path.Combine(Path.GetTempPath(),"FruitMachineLab-"+Guid.NewGuid());
    try {
        Directory.CreateDirectory(Path.Combine(temporary,"skill-cash"));
        File.WriteAllText(Path.Combine(temporary,"skill-cash","output-scan.json"),System.Text.Json.JsonSerializer.Serialize(capture));
        try {SkillCashOutputScanVerification.Verify(temporary);}catch(InvalidDataException){return;}
        throw new Exception("Changed scan lamp frame accepted");
    } finally {if(Directory.Exists(temporary))Directory.Delete(temporary,true);}
});
Check("Lamp pulse-width helper retains signed step and boundary reversal", () => {
    var m=new Machine();var arms=new List<Timer3Arm>();
    Mpu4LampPulseSweep.Advance(m,arms.Add);Equal(0,arms.Count);
    m.Memory[0xB3]=0xFF;m.Memory[0xE8]=1;m.Memory[0xE9]=8;m.Memory[0xEA]=2;m.WriteWord(0x32D,300);m.Memory[0x3F]=0xFF;
    Mpu4LampPulseSweep.Advance(m,arms.Add);Equal((ushort)298,m.ReadWord(0x32D));Equal((byte)0xFE,m.Memory[0xEA]);Equal((byte)8,m.Memory[0xE8]);
    Equal((ushort)0x48FD,m.ReadWord(0x3D));Equal((byte)0xFE,m.Memory[0x3F]);Equal((byte)0x63,m.Memory[0x40]);
    m.Memory[0xE8]=1;m.WriteWord(0x32D,30);Mpu4LampPulseSweep.Advance(m,arms.Add);Equal((ushort)32,m.ReadWord(0x32D));Equal((byte)2,m.Memory[0xEA]);
    m.Memory[0xE8]=1;m.WriteWord(0x32D,ushort.MaxValue);Mpu4LampPulseSweep.Advance(m,arms.Add);Equal((ushort)65533,m.ReadWord(0x32D));
    Equal(3,arms.Count);
});
Check("Changed alpha serial byte is rejected", () => {
    var capture=SkillCashAlphaVerification.Load(evidence);capture.Calls[0].Serial[0][0]^=1;
    var temporary=Path.Combine(Path.GetTempPath(),"FruitMachineLab-"+Guid.NewGuid());
    try {
        Directory.CreateDirectory(Path.Combine(temporary,"skill-cash"));
        File.WriteAllText(Path.Combine(temporary,"skill-cash","alpha-calls.json"),System.Text.Json.JsonSerializer.Serialize(capture));
        try {SkillCashAlphaVerification.Verify(temporary);}catch(InvalidDataException){return;}
        throw new Exception("Changed alpha serial byte accepted");
    } finally {if(Directory.Exists(temporary))Directory.Delete(temporary,true);}
});
Check("NVRAM service gate and unprotected checksum delta", () => {
    var m=new Machine();m.Memory[0x323]=0x80;m.Memory[0x322]=0x73;m.Memory[0x2C]=0x42;
    for(int address=0x2F0;address<0x322;address++)m.Memory[address]=(byte)address;
    var original=(byte[])m.Memory.Clone();Equal(false,Mpu4Nvram.Refresh(m));Equal(true,original.SequenceEqual(m.Memory));
    m.Memory[0x323]=0;int reads=0;
    Equal(true,Mpu4Nvram.Refresh(m,address=> {
        Equal((byte)0x42,m.Memory[0x2C]);reads++;
        if(address==0x2FA)m.Memory[0x322]=unchecked((byte)(m.Memory[0x322]+7));
    }));
    Equal(15,reads);byte sum=0;
    for(int address=0x2F0;address<0x309;address++) {Equal(unchecked((byte)~m.Memory[address]),m.Memory[address+0x19]);sum=unchecked((byte)(sum-m.Memory[address]));}
    Equal(unchecked((byte)(sum-0x32+7)),m.Memory[0x322]);Equal((byte)0x42,m.Memory[0x2C]);
});
Check("Native input conditions preserve none, partial, full and selector wrap", () => {
    var m=new Machine();SkillCashData.LoadFeature(m);
    // Synthetic mask rows isolate 67EC's condition-code paths.
    m.Memory[0x71AA]=3;m.Memory[0x71AB]=4;m.Memory[0x71AC]=0;m.Memory[0x71AD]=0;
    Equal((ushort)0,Mpu4InputConditions.Evaluate(m,0));
    m.Memory[0]=1;Equal((ushort)1,Mpu4InputConditions.Evaluate(m,0));
    m.Memory[0]=3;m.Memory[1]=4;Equal(ushort.MaxValue,Mpu4InputConditions.Evaluate(m,0));
    Equal(ushort.MaxValue,Mpu4InputConditions.Evaluate(m,64));
    m.Memory[0x7226]=8;m.Memory[0x7227]=16;Equal((ushort)0,Mpu4InputConditions.Evaluate(m,0x80));
    m.Memory[7]=16;Equal(ushort.MaxValue,Mpu4InputConditions.Evaluate(m,0x80));
});
Check("Sound forks run in the same tick and yield after equal deadlines", () => {
    var m=new Machine();m.Memory[0x4E]=16;
    new byte[]{0xC2,0x91,0x00,0xCE,1,0xD2,1,0xC0}.CopyTo(m.Memory,0x9000);
    new byte[]{0xD2,2,0xCE,1,0xD3,3,0xC0}.CopyTo(m.Memory,0x9100);
    var writes=new List<byte>();var scheduler=new Mpu4ChoiceStreamScheduler(m,0,e=>{if(e.Kind=="choice")writes.Add(e.Value);});
    Equal(true,scheduler.Queue(0x9000));scheduler.AdvanceTicks(1);Equal((byte)2,scheduler.Choice);Equal(2,scheduler.ActiveTasks);
    scheduler.AdvanceTicks(1);Equal(false,scheduler.Active);Equal("2,1,4",string.Join(',',writes));
    new byte[]{0xC1,0x92,0x00,0xD3,2,0xC0}.CopyTo(m.Memory,0x9000);
    new byte[]{0xD2,1,0xC0}.CopyTo(m.Memory,0x9200);
    scheduler.Queue(0x9000);scheduler.AdvanceTicks(1);Equal((byte)3,scheduler.Choice);Equal(false,scheduler.Active);
});
Check("Native NVRAM refresh and award-transfer accounting match MAME", () => {
    var result=SkillCashAwardVerification.Verify(evidence);
    Equal(13,result.Refreshes);Equal(10,result.Transfers);Equal((ushort)10,result.CurrentWin);
    Console.WriteLine($"  {result.Refreshes} refreshes, {result.Transfers} award transfers, {result.Instructions} accounting dispatches checked");
});
Check("Static two-unit award transfer preserves odd pending underflow", () => {
    var m=new Machine();m.WriteWord(0xBA,1);m.WriteWord(0x2FA,65535);
    m.WriteWord(0x851E,0xFF36);m.WriteWord(0x8522,0xFF3A);
    m.Memory[0xFF36]=0;m.Memory[0xFF3A]=0xFF;
    RecoveredScript Resolve(ushort address)=>new(Path.Combine(evidence,"VM-SCRIPTS",address.ToString("X4")+".txt"));
    new ScriptExecutor(m){ResolveScript=Resolve}.RunRange(Resolve(0xAF93),0xAF9D,0xAFC4);
    Equal(ushort.MaxValue,m.ReadWord(0xBA));Equal((ushort)1,m.ReadWord(0x2FA));Equal((ushort)1,m.Pop());
});
Check("16-bit cells, signed min, Forth flags", () => {
    Equal((ushort)0,Cell.Add(65535,1)); Equal((ushort)65535,Cell.Subtract(0,1));
    Equal((ushort)65534,Cell.Multiply(65535,2)); Equal((ushort)65535,Cell.Min(65535,6));
    Equal((ushort)65535,Cell.Flag(true)); Equal((ushort)0,Cell.Flag(false));
});
Check("6809 big-endian memory and address wrap", () => {
    var m = new Machine(); m.WriteWord(65535,0x1234);
    Equal((byte)0x12,m.Memory[65535]); Equal((byte)0x34,m.Memory[0]); Equal((ushort)0x1234,m.ReadWord(65535));
});
Check("Native seed update and IRQ mixing", () => {
    foreach(var pair in new[]{(Seed:(ushort)0,Next:(ushort)0x3619),(Seed:(ushort)1,Next:(ushort)0x3E1E),(Seed:ushort.MaxValue,Next:(ushort)0x2E14)}) {
        var m=new Machine(); m.WriteWord(0x324,pair.Seed); m.Memory[0x33]=0xA5;
        Equal((byte)((pair.Next>>8)^0xA5),Mpu4Random.AdvanceSeed(m)); Equal(pair.Next,m.ReadWord(0x324));
        m.WriteWord(0x324,pair.Seed); Equal((ushort)(pair.Next^0xA5A5),Mpu4Random.GenerateWord(m));
    }
});
Check("Native sixteen-step division in its non-overflow domain", () => {
    foreach(ushort divisor in new ushort[]{1,2,100,32768,65535})
    foreach(ushort high in new ushort[]{0,1,42,32767})
    foreach(ushort low in new ushort[]{0,1,12345,65535}) {
        if(high>=divisor) continue;
        uint numerator=((uint)high<<16)|low;
        var result=Mpu4Arithmetic.DivideDouble(low,high,divisor);
        Equal((ushort)(numerator/divisor),result.Quotient); Equal((ushort)(numerator%divisor),result.Remainder);
    }
});
Check("Recovered percentage script with strict unsigned boundary", () => {
    RecoveredScript Resolve(ushort address)=>new(Path.Combine(evidence,"VM-SCRIPTS",address.ToString("X4")+".txt"));
    foreach(ushort chance in new ushort[]{0,1,30,99,100}) {
        // chance=100 reaches the native overflow domain; its shift loop produces
        // FFFF rather than host division's wrapped 0000. This is static coverage.
        ushort threshold=chance==100 ? ushort.MaxValue : (ushort)(((uint)chance<<16)/100);
        foreach(var random in new ushort[]{0,threshold,(ushort)(threshold==0?0:threshold-1),65535}) {
            var m=new Machine(); m.Data.Push(chance); m.Data.Push(random);
            new ScriptExecutor(m){ResolveScript=Resolve}.Run(Resolve(0x9A00));
            Equal(Cell.Flag(threshold>random),m.Pop()); Equal(0,m.Data.Count);
        }
    }
});
Check("Shared record order and native memory-mask semantics", () => {
    var m=new Machine(); SkillCashData.Load(m); m.WriteWord(0x719F,0x0200); m.Data.Push(0x84E2);
    new ScriptExecutor(m).Run(new RecoveredScript(Path.Combine(evidence,"VM-SCRIPTS","841E.txt")));
    Equal((ushort)65535,m.Pop()); Equal(0,m.Data.Count);
    m.WriteWord(0x719F,0); m.Data.Push(0x84E2);
    new ScriptExecutor(m).Run(new RecoveredScript(Path.Combine(evidence,"VM-SCRIPTS","841E.txt")));
    Equal((ushort)0,m.Pop());
});
Check("Skill Cash option gate preserves timer when option disabled", () => {
    var m=new Machine(); SkillCashData.Load(m); m.Data.Push(25);
    RecoveredScript Resolve(ushort address)=>new(Path.Combine(evidence,"VM-SCRIPTS",address.ToString("X4")+".txt"));
    new ScriptExecutor(m){ResolveScript=Resolve}.Run(Resolve(0xC646));
    Equal((ushort)0,m.Pop()); Equal((ushort)25,m.Pop()); Equal(0,m.Data.Count);
});
Check("Recovered random-word script executes native helper and nested multiply", () => {
    var m=new Machine(); m.WriteWord(0x324,1); m.Memory[0x33]=0xA5;
    RecoveredScript Resolve(ushort address)=>new(Path.Combine(evidence,"VM-SCRIPTS",address.ToString("X4")+".txt"));
    new ScriptExecutor(m){ResolveScript=Resolve}.Run(Resolve(0x99D8));
    Equal((ushort)(0x3E1E^0xA5A5),m.Pop()); Equal(0,m.Data.Count);
});
Check("Recovered local-frame initialization", () => {
    var m = new Machine { LocalFrame=0x792 }; m.Memory[0x792]=0xCC;
    new ScriptExecutor(m).Run(new RecoveredScript(Path.Combine(evidence,"VM-SCRIPTS","C637.txt")));
    Equal((byte)0,m.Memory[0x792]); Equal((byte)6,m.Memory[0x793]); Equal(0,m.Data.Count);
});
Check("Recovered award-normalization branches", () => {
    foreach(var input in new[]{false,true}) foreach(ushort award in new ushort[]{10,30,47,60}) {
        var m=new Machine(); m.Data.Push(award);
        new ScriptExecutor(m){InputCondition=_=>input}.Run(new RecoveredScript(Path.Combine(evidence,"VM-SCRIPTS","9F6A.txt")));
        ushort expected=input && award>47 ? (ushort)30 : award==47 ? (ushort)30 : award;
        Equal(expected,m.Pop()); Equal(0,m.Data.Count);
    }
});
Check("Unknown native semantics fail explicitly", () => {
    try { new ScriptExecutor(new Machine()).Run(new RecoveredScript(Path.Combine(evidence,"VM-SCRIPTS","C699.txt"))); }
    catch(NotSupportedException) { return; }
    throw new Exception("Unknown helper was silently accepted");
});
Check("Selected MAME path: timers, frame levels, table address and award", () => {
    var result=SkillCashReplay.Run(evidence); Equal((byte)1,result.Level); Equal((ushort)10,result.PendingAward);
    Equal("3,2,1",string.Join(',',result.Events.Take(3).Select(x=>x.Value)));
});
Check("Focused MAME helper replay", () => {
    var result=SkillCashHelperVerification.Verify(evidence);
    Equal(3,result.RandomCalls);Equal(3,result.PercentageCalls);Equal(3,result.OptionCalls);Equal(1202,result.GateCalls);
});
Check("Recovered compensation/chance chain, including nested control stacks", () => {
    Equal(3,SkillCashCompensationVerification.Verify(evidence));
});
Check("Feature allocation and loop prefix match MAME S/F4/F6 and RAM", () => {
    Equal(29,SkillCashControlVerification.Verify(evidence));
});
Check("Selection decisions derive from captured platform inputs", () => {
    var result=SkillCashSelectionVerification.Verify(evidence);Equal(1202,result.Decisions);Equal(3,result.AcceptedChoices);
});
Check("ROM choice stream and native wait schedule match MAME", () => {
    var result=SkillCashSoundVerification.Verify(evidence);
    Equal(3,result.Queues);Equal(1202,result.Reads);
    Console.WriteLine($"  {result.Commands} sound commands, {result.Waits} waits, {result.Writes} choice writes checked");
});
Check("Complete feature sound protocol, forks and returns match MAME", () => {
    var result=SkillCashSoundVerification.VerifyFeature(evidence);
    Equal(25,result.Queues);
    Console.WriteLine($"  {result.Commands} sound commands and {result.Waits} waits checked across all feature streams");
});
Check("Continuous C721 replay matches MAME and restores caller frame", () => {
    var result=SkillCashFeatureReplay.Run(evidence);
    Equal((ushort)0,result.Pending);Equal((ushort)10,result.CurrentWin);Equal("3,2,1",string.Join(',',result.Choices));
    Console.WriteLine($"  {result.Instructions} continuous dispatches, {result.LampRequests} lamp requests and {result.AlphaRequests} alpha requests checked");
});
Check("Full feature lamp frame buffers match native MAME returns", () => {
    Equal(7298,SkillCashLampFrameVerification.Verify(evidence));
});
Check("Changed characteriser response rejects lamp frame replay", () => {
    var capture=System.Text.Json.JsonSerializer.Deserialize<LampFrameCapture>(File.ReadAllText(Path.Combine(evidence,"skill-cash","lamp-frames.json")),
        new System.Text.Json.JsonSerializerOptions{PropertyNameCaseInsensitive=true})!;
    capture.Responses[4]^=8;
    var temporary=Path.Combine(Path.GetTempPath(),"FruitMachineLab-"+Guid.NewGuid());
    try {
        Directory.CreateDirectory(Path.Combine(temporary,"skill-cash"));Directory.CreateDirectory(Path.Combine(temporary,"VM-SCRIPTS"));
        foreach(var source in Directory.GetFiles(Path.Combine(evidence,"VM-SCRIPTS"),"*.txt"))File.Copy(source,Path.Combine(temporary,"VM-SCRIPTS",Path.GetFileName(source)));
        foreach(var name in new[]{"feature-replay.json","feature-sound.json","compensation-calls.json","alpha-calls.json"})File.Copy(Path.Combine(evidence,"skill-cash",name),Path.Combine(temporary,"skill-cash",name));
        File.WriteAllText(Path.Combine(temporary,"skill-cash","lamp-frames.json"),System.Text.Json.JsonSerializer.Serialize(capture));
        try {SkillCashLampFrameVerification.Verify(temporary);}catch(InvalidDataException){return;}
        throw new Exception("Changed characteriser mapping was accepted");
    } finally {if(Directory.Exists(temporary))Directory.Delete(temporary,true);}
});
Check("Changed physical input ports reject the continuous feature replay", () => {
    var capture=System.Text.Json.JsonSerializer.Deserialize<FeatureCapture>(File.ReadAllText(Path.Combine(evidence,"skill-cash","feature-replay.json")),
        new System.Text.Json.JsonSerializerOptions{PropertyNameCaseInsensitive=true})!;
    var point=capture.Conditions.First(p=>p[1]==30 && p[2]!=0);
    for(int index=3;index<7;index++)point[index]=0;
    var temporary=Path.Combine(Path.GetTempPath(),"FruitMachineLab-"+Guid.NewGuid());
    try {
        Directory.CreateDirectory(Path.Combine(temporary,"skill-cash"));Directory.CreateDirectory(Path.Combine(temporary,"VM-SCRIPTS"));
        foreach(var source in Directory.GetFiles(Path.Combine(evidence,"VM-SCRIPTS"),"*.txt"))File.Copy(source,Path.Combine(temporary,"VM-SCRIPTS",Path.GetFileName(source)));
        foreach(var name in new[]{"feature-sound.json","compensation-calls.json","alpha-calls.json"})File.Copy(Path.Combine(evidence,"skill-cash",name),Path.Combine(temporary,"skill-cash",name));
        File.WriteAllText(Path.Combine(temporary,"skill-cash","feature-replay.json"),System.Text.Json.JsonSerializer.Serialize(capture));
        try {SkillCashFeatureReplay.Run(temporary);}catch(InvalidDataException){return;}
        throw new Exception("Changed port bytes were accepted");
    } finally {if(Directory.Exists(temporary))Directory.Delete(temporary,true);}
});
Check("Native delay scaling preserves floor, minimum tick and rate flag", () => {
    Equal((ushort)3,Mpu4ChoiceStreamScheduler.ScaleDelay(2,25,16,0x80));
    Equal((ushort)1,Mpu4ChoiceStreamScheduler.ScaleDelay(1,15,16,0x80));
    Equal((ushort)2,Mpu4ChoiceStreamScheduler.ScaleDelay(2,255,16,0));
    Equal((ushort)1,Mpu4ChoiceStreamScheduler.ScaleDelay(255,255,0,0x80));
});
Check("Choice stream counter wrap, byte wrap and disabled native gate", () => {
    var m=new Machine();m.Memory[0x4E]=16;
    byte[] stream=[0xD8,0xCE,1,0xD3,0xFF,0xC0];stream.CopyTo(m.Memory,0x8000);
    var scheduler=new Mpu4ChoiceStreamScheduler(m,65535);
    Equal(true,scheduler.Queue(0x8000));scheduler.AdvanceTicks(1);Equal((ushort)0,scheduler.Clock);Equal((byte)0,scheduler.Choice);
    scheduler.AdvanceTicks(1);Equal((byte)255,scheduler.Choice);Equal(false,scheduler.Active);
    m.Memory[0x719B]=0x80;Equal(false,scheduler.Queue(0x8000));Equal(false,scheduler.Reset());Equal((byte)255,scheduler.Choice);
    m.Memory[0x719B]=0;Equal(true,scheduler.Reset());Equal((byte)0,scheduler.Choice);Equal((ushort)1,scheduler.Clock);
});
Check("Complete recovered C699 selection loops match MAME state digests", () => {
    var diagnosticDirectory=Environment.GetEnvironmentVariable("FML_LOOP_DIAGNOSTICS");
    var writers=new Dictionary<int,StreamWriter>();
    try {
        var result=SkillCashLoopVerification.Verify(evidence,diagnosticDirectory is null ? null : (stage,ordinal,signature)=> {
            if(!writers.TryGetValue(stage,out var writer)) {writer=new(Path.Combine(diagnosticDirectory,$"stage-{stage}.csv"));writers.Add(stage,writer);}
            writer.WriteLine(string.Join(',',signature.Select(v=>v.ToString("X4"))));
        });
        Equal("3,2,1",string.Join(',',result.Choices));
        Console.WriteLine($"  {result.Instructions} VM dispatches, {result.LampRequests} decoded lamp requests checked");
    } finally { foreach(var writer in writers.Values)writer.Dispose(); }
});
Check("Dynamic lamp helper dispatch and stack effects match MAME", () => {
    var result=SkillCashLampVerification.Verify(evidence);
    Console.WriteLine($"  {result.Calls} lamp helper calls, {result.Instructions} VM instructions checked; hardware output remains unverified");
    if(result.Calls<3 || result.Requests!=result.Calls*6)throw new Exception("Incomplete lamp helper coverage");
});
Check("Native signed double quotient preserves zero and wrap behaviour", () => {
    Equal(unchecked((uint)-3),Mpu4Arithmetic.SignedDoubleQuotient(unchecked((uint)-7),2));
    Equal(unchecked((uint)-3),Mpu4Arithmetic.SignedDoubleQuotient(7,unchecked((uint)-2)));
    Equal(3u,Mpu4Arithmetic.SignedDoubleQuotient(unchecked((uint)-7),unchecked((uint)-2)));
    Equal(0x80000000u,Mpu4Arithmetic.SignedDoubleQuotient(0x80000000u,0xFFFFFFFFu));
    Equal(0u,Mpu4Arithmetic.SignedDoubleQuotient(123,0));
});
Check("Static nonzero compensation records select the recovered chance table", () => {
    foreach(var pair in new[]{(Amount:0u,Divisor:0u,Chance:(ushort)0),(Amount:250u,Divisor:10u,Chance:(ushort)10),
        (Amount:300u,Divisor:10u,Chance:(ushort)80),(Amount:320u,Divisor:10u,Chance:(ushort)99),(Amount:65536u,Divisor:1u,Chance:(ushort)0)}) {
        var m=new Machine();SkillCashData.Load(m);
        void Write24(ushort address,uint value){m.Memory[address]=(byte)(value>>16);m.WriteWord(Cell.Add(address,1),(ushort)value);}
        Write24(0x4A9,pair.Amount);Write24(0x4A6,pair.Divisor);
        RecoveredScript Resolve(ushort address)=>new(Path.Combine(evidence,"VM-SCRIPTS",address.ToString("X4")+".txt"));
        new ScriptExecutor(m){ResolveScript=Resolve}.Run(Resolve(0xC617));
        Equal(pair.Chance,m.Pop());Equal(0,m.Data.Count);
    }
});
Check("Local frame cleanup and early nested loop returns preserve prior frames", () => {
    var m=new Machine { LocalFrame=0x900 };var control=new VmControlStack(m,0x800);m.Control=control;
    control.EnterCall(0xCAFE);control.AllocateLocalFrame(2);
    Equal((ushort)0x7F6,control.Pointer);Equal((ushort)0x7FA,m.LocalFrame);
    control.EnterCall(0xD00D);Equal((ushort)0xD00D,control.Return());
    control.EnterLoop(0,3,0xC743);ushort outer=control.LoopFrame;
    control.EnterLoop(5,6,0xABCD);Equal((ushort?)null,control.IncrementLoop());Equal(outer,control.LoopFrame);
    Equal((ushort?)0xC743,control.IncrementLoop());Equal((ushort)1,control.LoopIndex);
    Equal((ushort)0xCAFE,control.Return());Equal((ushort)0x800,control.Pointer);Equal((ushort)0x900,m.LocalFrame);Equal((ushort)0,control.LoopFrame);
});
Check("Static terminal cancellation branches retain Forth truth and choice", () => {
    RecoveredScript Resolve(ushort address)=>new(Path.Combine(evidence,"VM-SCRIPTS",address.ToString("X4")+".txt"));
    foreach(ushort stage in new ushort[]{0,1,2}) foreach(ushort choice in new ushort[]{1,6}) foreach(bool chance in new[]{false,true}) {
        var m=new Machine();m.Data.Push(choice);m.Data.Push(65535);
        new ScriptExecutor(m){ResolveScript=Resolve,LoopIndex=()=>stage,
            WordHandler=(instruction,state)=>{if(instruction.Token!=0xC668)return false;state.Data.Push(Cell.Flag(chance));return true;}}
            .Run(Resolve(0xC676));
        Equal(Cell.Flag(!(stage==2 && choice==6 && chance)),m.Pop());Equal(choice,m.Pop());Equal(0,m.Data.Count);
    }
});
Check("Corrupted replay input is rejected", () => {
    var temporary=Path.Combine(Path.GetTempPath(),"FruitMachineLab-"+Guid.NewGuid());
    try {
        Directory.CreateDirectory(Path.Combine(temporary,"skill-cash"));
        Directory.CreateDirectory(Path.Combine(temporary,"VM-SCRIPTS"));
        foreach(var file in Directory.GetFiles(Path.Combine(evidence,"VM-SCRIPTS"),"*.txt"))
            File.Copy(file,Path.Combine(temporary,"VM-SCRIPTS",Path.GetFileName(file)));
        foreach(var file in Directory.GetFiles(Path.Combine(evidence,"skill-cash"),"*.json"))
            File.Copy(file,Path.Combine(temporary,"skill-cash",Path.GetFileName(file)));
        var log=File.ReadAllText(Path.Combine(evidence,"skill-cash","dispatch.txt"));
        log=log.Replace("y=C755 token=C697 u=0670 top=0019","y=C755 token=C697 u=0670 top=0018");
        File.WriteAllText(Path.Combine(temporary,"skill-cash","dispatch.txt"),log);
        try { SkillCashReplay.Run(temporary); }
        catch(InvalidDataException) { return; }
        throw new Exception("Corrupted timer observation was accepted");
    } finally { if(Directory.Exists(temporary)) Directory.Delete(temporary,true); }
});
Check("Changed accepted-choice latch is rejected", () => {
    var file=Path.Combine(evidence,"skill-cash","selection-decisions.json");
    var capture=System.Text.Json.JsonSerializer.Deserialize<SelectionCapture>(File.ReadAllText(file),
        new System.Text.Json.JsonSerializerOptions{PropertyNameCaseInsensitive=true})!;
    var at=Array.FindIndex(capture.Iterations,d=>d.Next==0xC6C8);
    var changed=capture.Iterations[at] with {Latch=(ushort)(capture.Iterations[at].Latch&~0x80)};
    // Preserve the expected trace output while changing just its platform input.
    capture.Iterations[at]=changed;
    var temporary=Path.Combine(Path.GetTempPath(),"FruitMachineLab-"+Guid.NewGuid());
    try {
        Directory.CreateDirectory(Path.Combine(temporary,"skill-cash"));Directory.CreateDirectory(Path.Combine(temporary,"VM-SCRIPTS"));
        foreach(var source in Directory.GetFiles(Path.Combine(evidence,"VM-SCRIPTS"),"*.txt"))File.Copy(source,Path.Combine(temporary,"VM-SCRIPTS",Path.GetFileName(source)));
        File.Copy(Path.Combine(evidence,"skill-cash","compensation-calls.json"),Path.Combine(temporary,"skill-cash","compensation-calls.json"));
        File.Copy(Path.Combine(evidence,"skill-cash","sound-events.json"),Path.Combine(temporary,"skill-cash","sound-events.json"));
        File.WriteAllText(Path.Combine(temporary,"skill-cash","selection-decisions.json"),System.Text.Json.JsonSerializer.Serialize(capture));
        try { SkillCashSelectionVerification.Verify(temporary); }
        catch(InvalidDataException) { return; }
        throw new Exception("Changed physical latch input was accepted");
    } finally { if(Directory.Exists(temporary))Directory.Delete(temporary,true); }
});
Check("Changed intra-word IRQ phase is rejected by complete-loop replay", () => {
    var capture=System.Text.Json.JsonSerializer.Deserialize<SelectionLoopCapture>(File.ReadAllText(Path.Combine(evidence,"skill-cash","selection-loops.json")),
        new System.Text.Json.JsonSerializerOptions{PropertyNameCaseInsensitive=true})!;
    capture.Calls[1].BeforeReads[0][1]=0;
    var temporary=Path.Combine(Path.GetTempPath(),"FruitMachineLab-"+Guid.NewGuid());
    try {
        Directory.CreateDirectory(Path.Combine(temporary,"skill-cash"));Directory.CreateDirectory(Path.Combine(temporary,"VM-SCRIPTS"));
        foreach(var source in Directory.GetFiles(Path.Combine(evidence,"VM-SCRIPTS"),"*.txt"))File.Copy(source,Path.Combine(temporary,"VM-SCRIPTS",Path.GetFileName(source)));
        foreach(var name in new[]{"compensation-calls.json","sound-events.json"})File.Copy(Path.Combine(evidence,"skill-cash",name),Path.Combine(temporary,"skill-cash",name));
        File.WriteAllText(Path.Combine(temporary,"skill-cash","selection-loops.json"),System.Text.Json.JsonSerializer.Serialize(capture));
        try {SkillCashLoopVerification.Verify(temporary);}
        catch(InvalidDataException){return;}
        throw new Exception("Changed timer-read phase was accepted");
    } finally {if(Directory.Exists(temporary))Directory.Delete(temporary,true);}
});
Check("Recorded dispatch tokens agree with recovered listings", () => {
    var known = Directory.GetFiles(Path.Combine(evidence,"VM-SCRIPTS"),"*.txt")
        .SelectMany(file=>new RecoveredScript(file).Instructions).GroupBy(x=>x.Site).ToDictionary(g=>g.Key,g=>g.First().Token);
    int checkedSites=0;
    foreach(var item in SkillCashReplay.ReadTrace(Path.Combine(evidence,"skill-cash","dispatch.txt"))) {
        if(known.TryGetValue(item.Site,out var token)) { Equal(token,item.Token); checkedSites++; }
    }
    if(checkedSites<100) throw new Exception("Insufficient dispatch comparisons");
    Console.WriteLine($"  {checkedSites} recorded dispatches checked");
});
Console.WriteLine($"{passed} verification groups passed. Feature, alpha software and IRQ latch replay verified; electrical timing, audio synthesis and general scheduling remain incomplete.");
return 0;
} catch (Exception error) {
    Console.Error.WriteLine("FAIL verification: " + error);
    return 1;
}

using FruitMachineLab.Runtime;
using FruitMachineLab.Adders;

var root = args.Length > 0 ? Path.GetFullPath(args[0]) : Directory.GetCurrentDirectory();
var evidence = Path.Combine(root,"evidence","mpu4");
var passed = 0;
void Check(string name, Action action) { action(); Console.WriteLine("PASS " + name); passed++; }
void Equal<T>(T expected,T actual) { if (!Equals(expected,actual)) throw new Exception($"Expected {expected}, got {actual}"); }
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
Console.WriteLine($"{passed} verification groups passed. Bounded replay only; complete feature timing/animation remains untranslated.");

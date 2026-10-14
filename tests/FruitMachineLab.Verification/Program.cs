using FruitMachineLab.Runtime;
using FruitMachineLab.Adders;

try {
var root = args.Length > 0 ? Path.GetFullPath(args[0]) : RepositoryLocation.Find(Directory.GetCurrentDirectory(),AppContext.BaseDirectory);
var evidence = Path.Combine(root,"evidence","mpu4");
var passed = 0;
void Check(string name, Action action) { action(); Console.WriteLine("PASS " + name); passed++; }
void Equal<T>(T expected,T actual) { if (!Equals(expected,actual)) throw new Exception($"Expected {expected}, got {actual}"); }
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

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
Check("Static terminal cancellation branches retain Forth truth and choice", () => {
    RecoveredScript Resolve(ushort address)=>new(Path.Combine(evidence,"VM-SCRIPTS",address.ToString("X4")+".txt"));
    foreach(ushort stage in new ushort[]{0,1,2}) foreach(ushort choice in new ushort[]{1,6}) foreach(bool chance in new[]{false,true}) {
        var m=new Machine();m.Data.Push(choice);m.Data.Push(65535);
        new ScriptExecutor(m){ResolveScript=Resolve,LoopIndex=()=>stage,
            ObservedWord=(instruction,state)=>{if(instruction.Token!=0xC668)return false;state.Data.Push(Cell.Flag(chance));return true;}}
            .Run(Resolve(0xC676));
        Equal(Cell.Flag(!(stage==2 && choice==6 && chance)),m.Pop());Equal(choice,m.Pop());Equal(0,m.Data.Count);
    }
});
Check("Corrupted replay input is rejected", () => {
    var temporary=Path.Combine(Path.GetTempPath(),"FruitMachineLab-"+Guid.NewGuid());
    try {
        Directory.CreateDirectory(Path.Combine(temporary,"skill-cash"));
        Directory.CreateDirectory(Path.Combine(temporary,"VM-SCRIPTS"));
        foreach(var name in new[]{"C637","C721","C6FC","9F6A"})
            File.Copy(Path.Combine(evidence,"VM-SCRIPTS",name+".txt"),Path.Combine(temporary,"VM-SCRIPTS",name+".txt"));
        var log=File.ReadAllText(Path.Combine(evidence,"skill-cash","dispatch.txt"));
        log=log.Replace("y=C755 token=C697 u=0670 top=0019","y=C755 token=C697 u=0670 top=0018");
        File.WriteAllText(Path.Combine(temporary,"skill-cash","dispatch.txt"),log);
        try { SkillCashReplay.Run(temporary); }
        catch(InvalidDataException) { return; }
        throw new Exception("Corrupted timer observation was accepted");
    } finally { if(Directory.Exists(temporary)) Directory.Delete(temporary,true); }
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

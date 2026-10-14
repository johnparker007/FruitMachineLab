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

using FruitMachineLab.Runtime;
using FruitMachineLab.Adders;

try {
var root = args.Length > 0 ? Path.GetFullPath(args[0]) : RepositoryLocation.Find(Directory.GetCurrentDirectory(),AppContext.BaseDirectory);
var evidence = Path.Combine(root,"evidence","mpu4");
var passed = 0;
void Check(string name, Action action) { if(args.Length>1 && !name.Contains(args[1],StringComparison.OrdinalIgnoreCase))return;action(); Console.WriteLine("PASS " + name); passed++; }
void Equal<T>(T expected,T actual) { if (!Equals(expected,actual)) throw new Exception($"Expected {expected}, got {actual}"); }
Check("Generated lamp callback matches eighteen native paths and45 effective bus writes", () => {
    using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","lamp-callback-timing.json")));int count=0,writes=0;
    foreach(var r in doc.RootElement.GetProperty("rows").EnumerateArray()){
        var c=r.GetProperty("case");ushort column=c.GetProperty("column").GetUInt16();bool blank=c.GetProperty("blank").GetByte()!=0;ulong start=r.GetProperty("start_cycle").GetUInt64();
        var m=new Machine();m.WriteWord(0x28,column);m.Memory[0xA00]=c.GetProperty("bank0").GetByte();m.Memory[0xA02]=c.GetProperty("bank1").GetByte();m.Memory[0xB00]=c.GetProperty("display").GetByte();m.Memory[0x140+column]=c.GetProperty("mask0").GetByte();m.Memory[0x148+column]=c.GetProperty("mask1").GetByte();m.Memory[0xAB+column]=c.GetProperty("blank").GetByte();
        var execution=new Mpu4LampCallbackExecution(m,start);var path=Mpu4LampCallbackExecution.Path(blank);var native=r.GetProperty("instructions");Equal(path.Count,native.GetArrayLength());ulong cursor=start;
        for(int i=0;i<path.Count;i++){
            Equal(path[i].Address,native[i].GetProperty("pc").GetUInt16());Equal(cursor,native[i].GetProperty("cycle").GetUInt64());Equal(true,native[i].GetProperty("context_hex").GetString()!.StartsWith(path[i].Bytes,StringComparison.Ordinal));cursor+=(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(path[i].Bytes)).Cycles;
        }
        Equal(r.GetProperty("end").GetProperty("cycle").GetUInt64(),cursor);Equal(cursor,execution.CompletedAt);
        var bus=r.GetProperty("writes");Equal(execution.Writes.Count,bus.GetArrayLength());
        for(int i=0;i<execution.Writes.Count;i++){var w=execution.Writes[i];Equal(w.Cycle,bus[i].GetProperty("cycle").GetUInt64());Equal(w.Address,bus[i].GetProperty("address").GetUInt16());Equal(w.Value,bus[i].GetProperty("value").GetByte());writes++;}
        Equal(start+37,execution.Writes[0].Cycle);Equal(start+42,execution.Writes[1].Cycle);Equal(start+(blank ? 85UL : 78UL),execution.CompletedAt);
        execution.AdvanceTo(execution.CompletedAt);Equal(true,execution.Completed);var end=r.GetProperty("end");Equal(end.GetProperty("bank0").GetByte(),m.Memory[0xA00]);Equal(end.GetProperty("bank1").GetByte(),m.Memory[0xA02]);Equal(end.GetProperty("display").GetByte(),m.Memory[0xB00]);count++;
    }
    Equal(18,count);Equal(45,writes);
});
Check("Generated callback paths match nineteen natural callback instruction windows", () => {
    using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","ptm-service-timing.json")));int count=0;
    foreach(var tail in doc.RootElement.GetProperty("timer3_tails").EnumerateArray()){
        ulong start=tail.GetProperty("callback_cycle").GetUInt64(),cursor=start;var path=Mpu4LampCallbackExecution.Path(false);var native=tail.GetProperty("instructions");
        for(int i=0;i<path.Count;i++){
            Equal(path[i].Address,native[i].GetProperty("pc").GetUInt16());Equal(cursor,native[i].GetProperty("cycle").GetUInt64());cursor+=(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(path[i].Bytes)).Cycles;Equal(cursor,native[i].GetProperty("next_cycle").GetUInt64());
        }
        Equal(start+78,cursor);count++;
    }
    Equal(19,count);
});
Check("Incremental callback preserves coarse timing and rejects unresolved concurrent writers", () => {
    Machine Seed(){var m=new Machine();m.WriteWord(0x28,0);m.Memory[0xA00]=0xFF;m.Memory[0xA02]=0xAA;m.Memory[0xB00]=0xCC;m.Memory[0x140]=15;m.Memory[0x148]=240;m.Memory[0xAB]=1;return m;}
    var a=Seed();var b=Seed();var coarse=new Mpu4LampCallbackExecution(a,100);var fine=new Mpu4LampCallbackExecution(b,100);var x=new List<LampCallbackWrite>();var y=new List<LampCallbackWrite>();
    coarse.AdvanceTo(200,w=>{Equal(w.Cycle,coarse.Cycle);x.Add(w);});for(ulong at=100;at<=200;at++)fine.AdvanceTo(at,y.Add);
    Equal(true,a.Memory.SequenceEqual(b.Memory));Equal(true,x.SequenceEqual(y));Equal(3,x.Count);Equal(175UL,x[2].Cycle);Equal(185UL,coarse.CompletedAt);
    int rejected=0;try{fine.AdvanceTo(199);}catch(ArgumentOutOfRangeException){rejected++;}
    var changed=Seed();var callback=new Mpu4LampCallbackExecution(changed,0);changed.Memory[0x140]=0;try{callback.AdvanceTo(37);}catch(NotSupportedException){rejected++;}
    changed=Seed();callback=new Mpu4LampCallbackExecution(changed,0);changed.Memory[0xA00]=1;try{callback.AdvanceTo(37);}catch(NotSupportedException){rejected++;}
    changed=Seed();changed.WriteWord(0x28,8);try{new Mpu4LampCallbackExecution(changed,0);}catch(NotSupportedException){rejected++;}Equal(4,rejected);
});
Check("Live callback pauses between generated lamp bank writes", () => {
    var live=new SkillCashLiveSession(evidence);var writes=new List<LampCallbackWrite>();ulong entry=0;live.ObserveLampCallbackEntry=at=>entry=at;live.ObserveLampCallbackWrite=writes.Add;live.Resume();
    for(int i=0;i<20000 && live.NextLampCallbackEvent is null;i++)live.AdvanceCycles(1);
    Equal(true,entry>0);Equal(entry+37,live.NextLampCallbackEvent!.Value);bool blank=live.Machine.Memory[0xAB+live.Machine.ReadWord(0x28)]!=0;
    live.AdvanceCycles(entry+37-live.Cycle);Equal(1,writes.Count);Equal((ushort)0xA00,writes[0].Address);Equal(entry+42,live.NextLampCallbackEvent!.Value);
    live.Pause();var frozen=live.Machine.Memory.ToArray();ulong cycle=live.Cycle;int instructions=live.Instructions;var pending=live.NextLampCallbackEvent;live.AdvanceCycles(100000);Equal(cycle,live.Cycle);Equal(instructions,live.Instructions);Equal(pending,live.NextLampCallbackEvent);Equal(true,frozen.SequenceEqual(live.Machine.Memory));live.Resume();
    live.AdvanceCycles(4);Equal(1,writes.Count);live.AdvanceCycles(1);Equal(2,writes.Count);Equal((ushort)0xA02,writes[1].Address);
    live.AdvanceCycles(entry+(blank ? 85UL : 78UL)-live.Cycle);Equal(1,live.Callbacks);Equal(true,live.NextLampCallbackEvent is null);Equal(blank ? 3 : 2,writes.Count);live.Pause();
});
Check("Live ignores recorded callback return timestamps while preserving service entry times", () => {
    var directory=Path.Combine(Path.GetTempPath(),"FruitMachineLab-callback-return-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(directory);
    try{
        foreach(var source in Directory.EnumerateFiles(evidence,"*",SearchOption.AllDirectories)){string destination=Path.Combine(directory,Path.GetRelativePath(evidence,source));Directory.CreateDirectory(Path.GetDirectoryName(destination)!);File.Copy(source,destination);}
        string file=Path.Combine(directory,"skill-cash","shared-timing.json");var options=new System.Text.Json.JsonSerializerOptions {PropertyNameCaseInsensitive=true};var timing=System.Text.Json.JsonSerializer.Deserialize<SharedTimingCapture>(File.ReadAllText(file),options)!;int changed=0;
        for(int i=0;i<timing.Events.Length-1;i++)if(timing.Events[i][1]==7){if(timing.Events[i+1][0]<100)throw new Exception("Insufficient diagnostic timestamp gap");timing.Events[i][0]+=100;timing.Events[i+1][0]-=100;changed++;}
        Equal(6102,changed);File.WriteAllText(file,System.Text.Json.JsonSerializer.Serialize(timing));
        var original=new SkillCashLiveSession(evidence);var altered=new SkillCashLiveSession(directory);var a=new List<LampCallbackWrite>();var b=new List<LampCallbackWrite>();original.ObserveLampCallbackWrite=a.Add;altered.ObserveLampCallbackWrite=b.Add;original.Resume();altered.Resume();original.AdvanceCycles(20000);altered.AdvanceCycles(20000);
        Equal(true,a.Count>0);Equal(true,a.SequenceEqual(b));Equal(original.Instructions,altered.Instructions);Equal(original.Callbacks,altered.Callbacks);Equal(true,original.Machine.Memory.SequenceEqual(altered.Machine.Memory));
    }finally{Directory.Delete(directory,true);}
});
Check("Literal body timing and values match twenty native ROM handler calls", () => {
    using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","calibrated-delay-timing.json")));int count=0;
    foreach(var row in doc.RootElement.GetProperty("literal_rows").EnumerateArray()){
        var c=row.GetProperty("case");bool word=c.GetProperty("word").GetBoolean();ushort value=c.GetProperty("value").GetUInt16();var end=row.GetProperty("end");
        var path=Mpu4VmPrimitiveTiming.LiteralPath(word);var region=doc.RootElement.GetProperty("literal_native_regions")[word ? 1 : 0];byte[] bytes=Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!);
        foreach(var ins in path.Skip(2)){var encoded=Convert.FromHexString(ins.Bytes);int offset=ins.Address-region.GetProperty("address").GetInt32();Equal(true,bytes.AsSpan(offset,encoded.Length).SequenceEqual(encoded));}
        ulong cycles=word ? Mpu4VmPrimitiveTiming.BodyWordCycles : Mpu4VmPrimitiveTiming.BodyByteCycles;
        Equal(cycles,end.GetProperty("cycle").GetUInt64()-row.GetProperty("start_cycle").GetUInt64()+17);
        Equal(word ? value : (ushort)(value>>8),end.GetProperty("top").GetUInt16());Equal((ushort)0xBEEF,end.GetProperty("second").GetUInt16());
        Equal((ushort)0x5FE,end.GetProperty("u").GetUInt16());Equal((ushort)0x700,end.GetProperty("s").GetUInt16());Equal((ushort)0x402,end.GetProperty("y").GetUInt16());Equal((ushort)0xFC,end.GetProperty("pc").GetUInt16());count++;
    }
    Equal(20,count);Equal(32UL,Mpu4VmPrimitiveTiming.BodyWordCycles);Equal(33UL,Mpu4VmPrimitiveTiming.BodyByteCycles);
    using var map=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"maps","vm-literal-timing.json")));var tokens=map.RootElement.GetProperty("tokens");Equal(175,tokens.GetArrayLength());Equal(1048,map.RootElement.GetProperty("references").GetInt32());
    foreach(var token in tokens.EnumerateArray())Equal(token.GetProperty("operation").GetString()=="vm_push_word_body_word" ? "794F" : "7946",token.GetProperty("header_hex").GetString());
    Equal((ushort)0x161,tokens.EnumerateArray().Single(t=>t.GetProperty("token").GetUInt16()==0x7FB1).GetProperty("value").GetUInt16());
});
Check("Calibrated native delay matches twenty MAME calls and2068 inner passes", () => {
    using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","calibrated-delay-timing.json")));
    int count=0,passes=0;
    foreach(var r in doc.RootElement.GetProperty("rows").EnumerateArray()){
        var c=r.GetProperty("case");byte b=c.GetProperty("count").GetByte();var end=r.GetProperty("end");
        Equal(Mpu4CalibratedDelay.RepeatCycles(b),end.GetProperty("cycle").GetUInt64()-r.GetProperty("start_cycle").GetUInt64());
        Equal(b==0 ? 256 : b,r.GetProperty("passes").GetArrayLength());
        foreach(var p in r.GetProperty("passes").EnumerateArray()){Equal(Mpu4CalibratedDelay.SinglePassCycles,p[1].GetUInt64()-p[0].GetUInt64()+8);passes++;}
        Equal(c.GetProperty("a").GetByte(),end.GetProperty("a").GetByte());Equal(b,end.GetProperty("b").GetByte());Equal((ushort)0x702,end.GetProperty("s").GetUInt16());
        Equal((ushort)0x800,end.GetProperty("pc").GetUInt16());Equal((ushort)0x1234,end.GetProperty("x").GetUInt16());Equal((ushort)0x2345,end.GetProperty("y").GetUInt16());Equal((ushort)0x3456,end.GetProperty("u").GetUInt16());count++;
    }
    Equal(20,count);Equal(2068,passes);Equal(17096UL,Mpu4CalibratedDelay.SinglePassCycles);Equal(34263UL,Mpu4CalibratedDelay.RepeatCycles(2));Equal(34276UL,Mpu4CalibratedDelay.StartToneWaitCycles);
});
Check("Natural Start tone wait matches generated CPU delay plus full ordinary IRQ envelopes", () => {
    using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","calibrated-delay-timing.json")));
    var natural=doc.RootElement.GetProperty("natural");var p=natural.GetProperty("phases");int irqCount=0;
    for(int i=0;i<3;i++){
        ulong start=p[i].GetProperty("start").GetUInt64(),end=p[i].GetProperty("end").GetUInt64(),busy=0;int count=0;
        foreach(var irq in natural.GetProperty("outer_irqs").EnumerateArray()){
            ulong accepted=irq.GetProperty("accepted_cycle").GetUInt64(),resumed=irq.GetProperty("resumed_cycle").GetUInt64();
            Equal(accepted+M6809IrqEntry.EntryCycles,irq.GetProperty("handler_cycle").GetUInt64());Equal(irq.GetProperty("rti_cycle").GetUInt64()+15,resumed);
            if(accepted>=start && resumed<=end){busy+=resumed-accepted;count++;}
        }
        Equal(p[i].GetProperty("full_irq_cycles").GetUInt64(),busy);Equal(p[i].GetProperty("cpu_cycles").GetUInt64(),end-start-busy);Equal(p[i].GetProperty("outer_irqs").GetInt32(),count);irqCount+=count;
    }
    Equal(24,irqCount);Equal(23,p[1].GetProperty("outer_irqs").GetInt32());Equal(Mpu4CalibratedDelay.StartToneWaitCycles,p[1].GetProperty("cpu_cycles").GetUInt64());Equal(381UL,p[0].GetProperty("cpu_cycles").GetUInt64());Equal(360UL,p[2].GetProperty("cpu_cycles").GetUInt64());
    var handlers=natural.GetProperty("outer_irqs").EnumerateArray().Select(irq=>new ulong[]{irq.GetProperty("handler_cycle").GetUInt64(),irq.GetProperty("rti_cycle").GetUInt64()-irq.GetProperty("handler_cycle").GetUInt64()});
    var adapter=CapturedInterruptOccupancy.FromOrdinaryIrqHandlers(natural.GetProperty("terminal").GetUInt64()+100,handlers);
    ulong before=adapter.NextStart;
    Equal(p[1].GetProperty("end").GetUInt64(),adapter.CompletionAfterCpuWork(p[1].GetProperty("start").GetUInt64(),Mpu4CalibratedDelay.StartToneWaitCycles));Equal(before,adapter.NextStart);
});
Check("CPU work deadline crosses IRQ envelopes and period boundaries without consuming events", () => {
    var adapter=new CapturedInterruptOccupancy(100,new[]{new ulong[]{20,10},new ulong[]{60,20}});
    Equal(50UL,adapter.CompletionAfterCpuWork(10,30));Equal(135UL,adapter.CompletionAfterCpuWork(50,55));
    Equal(35UL,adapter.CompletionAfterCpuWork(25,5));Equal(20UL,adapter.NextStart);
    Equal(10UL,adapter.CompletionAfterCpuWork(10,0));
    bool blocked=false;try{new CapturedInterruptOccupancy(100,new[]{new ulong[]{0,100}}).CompletionAfterCpuWork(0,1);}catch(InvalidOperationException){blocked=true;}Equal(true,blocked);
});
Check("Full ordinary IRQ occupancy restores verified acceptance and resume boundaries", () => {
    using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","ptm-outer-timing.json")));var parents=doc.RootElement.GetProperty("parents");
    var rows=parents.EnumerateArray().Select(p=>new ulong[]{p.GetProperty("entry_cycle").GetUInt64(),p.GetProperty("resumed_cycle").GetUInt64()-p.GetProperty("entry_cycle").GetUInt64()-15}).ToArray();
    var occupancy=CapturedInterruptOccupancy.FromOrdinaryIrqHandlers(parents[18].GetProperty("resumed_cycle").GetUInt64()+100,rows);
    foreach(var p in parents.EnumerateArray()){Equal(p.GetProperty("accepted_cycle").GetUInt64(),occupancy.NextStart);Equal(p.GetProperty("resumed_cycle").GetUInt64(),occupancy.NextEnd);occupancy.Consume();}
    bool invalid=false;try{CapturedInterruptOccupancy.FromOrdinaryIrqHandlers(100,new[]{new ulong[]{18,10}});}catch(InvalidDataException){invalid=true;}Equal(true,invalid);
});
void VerifyConditionalPath(System.Text.Json.JsonElement instructions,IReadOnlyList<(ushort Address,string Bytes)> path,int skip,ulong start,ulong end)
{
    Equal(path.Count-skip,instructions.GetArrayLength());ulong cursor=start;
    for(int n=0;n<instructions.GetArrayLength();n++){
        var ins=instructions[n];var expected=path[n+skip];byte[] bytes=Convert.FromHexString(expected.Bytes);
        Equal(expected.Address,ins.GetProperty("pc").GetUInt16());Equal(true,ins.GetProperty("context_hex").GetString()!.StartsWith(expected.Bytes,StringComparison.Ordinal));
        var timing=M6809InstructionTiming.Decode(bytes);Equal(bytes.Length,timing.Length);Equal(cursor,ins.GetProperty("cycle").GetUInt64());
        ushort next=n+skip+1<path.Count ? path[n+skip+1].Address : (ushort)0xFC;
        if(bytes[0] is >=0x20 and <=0x2F){
            bool taken=M6809InstructionTiming.EvaluateBranch(bytes[0],ins.GetProperty("cc").GetByte());
            Equal(next,unchecked((ushort)(expected.Address+2+(taken ? (sbyte)bytes[1] : 0))));
        }
        if(bytes[0]==0x0E)Equal(next,(ushort)bytes[1]);
        cursor+=(ulong)timing.Cycles;
    }
    Equal(end,cursor);
}
Check("Conditional VM native paths and effects match376 injected MAME cases", () => {
    using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","vm-conditional-synthetic.json")));
    var variants=new HashSet<(ushort,bool)>();int count=0;
    foreach(var row in doc.RootElement.GetProperty("rows").EnumerateArray()){
        var c=row.GetProperty("case");ushort token=c.GetProperty("token").GetUInt16(),top=c.GetProperty("top").GetUInt16(),second=c.GetProperty("second").GetUInt16(),operand=c.GetProperty("operand_word").GetUInt16();
        bool selected=Mpu4VmConditionalTiming.SelectPath(token,top,second);var path=Mpu4VmConditionalTiming.Path(token,selected);
        var end=row.GetProperty("end");ulong start=row.GetProperty("start_cycle").GetUInt64(),finish=end.GetProperty("cycle").GetUInt64();
        VerifyConditionalPath(row.GetProperty("instructions"),path,2,start,finish);
        Equal(path[2].Address,Convert.ToUInt16(row.GetProperty("header_hex").GetString(),16));
        Equal(finish-start+17,Mpu4VmConditionalTiming.Cycles(token,top,second));
        Equal((ushort)0x602,end.GetProperty("u").GetUInt16());Equal((ushort)0x700,end.GetProperty("s").GetUInt16());
        ushort y=0x402,result=second;
        switch(token){
            case 0x7982:case 0x798C:y=top==0 ? unchecked((ushort)(0x402+(operand>>8))) : (ushort)0x403;break;
            case 0x79A6:y=top==0 ? unchecked((ushort)(0x402+(short)(0xFF00|(operand>>8)))) : (ushort)0x403;break;
            case 0x79B9:y=top==0 ? operand : (ushort)0x404;break;
            case 0x7A6F:result=Cell.Flag(top==second);break;
            case 0x7ADC:result=Cell.Min(top,second);break;
            case 0x7AE7:result=(short)top>(short)second ? top : second;break;
        }
        Equal(y,end.GetProperty("y").GetUInt16());Equal(result,end.GetProperty("top").GetUInt16());Equal((ushort)0x1234,end.GetProperty("second").GetUInt16());
        var data=new Stack<ushort>();data.Push(second);data.Push(top);var before=data.ToArray();Equal(Mpu4VmConditionalTiming.Cycles(token,top,second),Mpu4VmConditionalTiming.Cycles(token,data)!.Value);Equal(true,before.SequenceEqual(data));
        variants.Add((token,selected));count++;
    }
    Equal(376,count);Equal(14,variants.Count);
    Equal(36UL,Mpu4VmConditionalTiming.Cycles(0x7982,1));Equal(45UL,Mpu4VmConditionalTiming.Cycles(0x7982,0));
    Equal(36UL,Mpu4VmConditionalTiming.Cycles(0x79B9,1));Equal(37UL,Mpu4VmConditionalTiming.Cycles(0x79B9,0));
    Equal(44UL,Mpu4VmConditionalTiming.Cycles(0x7A6F,1,0));Equal(47UL,Mpu4VmConditionalTiming.Cycles(0x7A6F,1,1));
    Equal(37UL,Mpu4VmConditionalTiming.Cycles(0x7ADC,1,0));Equal(42UL,Mpu4VmConditionalTiming.Cycles(0x7ADC,0,1));
    Equal(42UL,Mpu4VmConditionalTiming.Cycles(0x7AE7,1,0));Equal(37UL,Mpu4VmConditionalTiming.Cycles(0x7AE7,0,1));
    Equal<ulong?>(null,Mpu4VmConditionalTiming.Cycles(0xFFFF,new Stack<ushort>()));
    bool underflow=false;try{Mpu4VmConditionalTiming.Cycles(0x7A6F,new Stack<ushort>(new ushort[]{1}));}catch(InvalidOperationException){underflow=true;}Equal(true,underflow);
});
Check("Conditional VM timing matches twelve uninterrupted natural Skill Cash paths", () => {
    using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","vm-conditional-natural.json")));
    int count=0;
    foreach(var row in doc.RootElement.GetProperty("rows").EnumerateArray()){
        ushort token=row.GetProperty("token").GetUInt16();var instructions=row.GetProperty("instructions");
        var branch=instructions.EnumerateArray().Single(i=>i.GetProperty("pc").GetUInt16()==row.GetProperty("branch_pc").GetUInt16());
        byte op=Convert.FromHexString(branch.GetProperty("context_hex").GetString()!)[0];bool taken=M6809InstructionTiming.EvaluateBranch(op,row.GetProperty("branch_cc").GetByte());
        bool selected=token==0x7A6F ? !taken : taken;var path=Mpu4VmConditionalTiming.Path(token,selected);
        VerifyConditionalPath(instructions,path,0,row.GetProperty("start_cycle").GetUInt64(),row.GetProperty("end_cycle").GetUInt64());count++;
    }
    Equal(12,count);Equal(2,doc.RootElement.GetProperty("excluded_interrupted").GetArrayLength());
});
Check("Translated conditional VM effects agree with injected native cases", () => {
    var directory=Path.Combine(Path.GetTempPath(),"FruitMachineLab-conditional-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(directory);
    try{
        var operations=new Dictionary<ushort,string>{{0x7982,"vm_branch_forward8_if_zero"},{0x798C,"vm_branch_forward8_if_zero"},{0x79A6,"vm_branch_backward8_if_zero"},{0x79B9,"vm_branch_absolute16_if_zero"},{0x7A6F,"vm_compare_equal"},{0x7ADC,"vm_min_signed"},{0x7AE7,"vm_max_signed"}};
        var scripts=new Dictionary<ushort,RecoveredScript>();
        foreach(var (token,operation) in operations){
            string text=Mpu4VmConditionalTiming.RequiredCells(token)==1
                ? $"0400 {token:X4} {operation} branch=0x0410\n0404 795B vm_push_inline_word_literal inline_value=0x1111\n0408 792F vm_return_to_caller_stream\n0410 795B vm_push_inline_word_literal inline_value=0x2222\n0414 792F vm_return_to_caller_stream\n"
                : $"0400 {token:X4} {operation}\n0402 792F vm_return_to_caller_stream\n";
            string file=Path.Combine(directory,$"{token:X4}.txt");File.WriteAllText(file,text);scripts[token]=new RecoveredScript(file);
        }
        using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","vm-conditional-synthetic.json")));int count=0;
        foreach(var row in doc.RootElement.GetProperty("rows").EnumerateArray()){
            var c=row.GetProperty("case");ushort token=c.GetProperty("token").GetUInt16(),top=c.GetProperty("top").GetUInt16(),second=c.GetProperty("second").GetUInt16();
            var machine=new Machine {DataStackBase=0x606};machine.Data.Push(0x1234);machine.Data.Push(second);machine.Data.Push(top);
            new ScriptExecutor(machine).Run(scripts[token]);
            if(Mpu4VmConditionalTiming.RequiredCells(token)==1)Equal(top==0 ? (ushort)0x2222 : (ushort)0x1111,machine.Pop());
            machine.SyncDataToMemory();var native=row.GetProperty("end");
            Equal(native.GetProperty("u").GetUInt16(),machine.DataPointer);Equal(native.GetProperty("top").GetUInt16(),machine.ReadWord(machine.DataPointer));
            Equal(native.GetProperty("second").GetUInt16(),machine.ReadWord(Cell.Add(machine.DataPointer,2)));count++;
        }
        Equal(376,count);
    }finally{Directory.Delete(directory,true);}
});
Check("Source-derived threaded call gateway timing matches complete natural boundaries", () => {
    using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","vm-call-gateway-timing.json")));
    var path=Mpu4VmPrimitiveTiming.ThreadedCallPath;int count=0;
    foreach(var sample in doc.RootElement.GetProperty("samples").EnumerateArray()){
        var instructions=sample.GetProperty("instructions");Equal(path.Count,instructions.GetArrayLength());ulong start=sample.GetProperty("start_cycle").GetUInt64(),cursor=start;
        for(int i=0;i<path.Count;i++){
            var actual=instructions[i];Equal(path[i].Address,actual.GetProperty("pc").GetUInt16());
            Equal(true,actual.GetProperty("context_hex").GetString()!.StartsWith(path[i].Bytes,StringComparison.Ordinal));
            byte[] bytes=Convert.FromHexString(path[i].Bytes);var timing=M6809InstructionTiming.Decode(bytes);Equal(bytes.Length,timing.Length);
            Equal(cursor,actual.GetProperty("cycle").GetUInt64());cursor+=(ulong)timing.Cycles;Equal(cursor,actual.GetProperty("completion_cycle").GetUInt64());
        }
        Equal(sample.GetProperty("end_cycle").GetUInt64(),cursor);Equal(Mpu4VmPrimitiveTiming.ThreadedCallCycles,cursor-start);count++;
    }
    Equal(26,count);Equal(28UL,Mpu4VmPrimitiveTiming.ThreadedCallCycles);
});
Check("Source-derived VM primitive timing matches natural dispatch boundaries", () => {
    using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","vm-primitive-timing.json")));
    int count=0;var counts=new Dictionary<ushort,int>();
    foreach(var sample in doc.RootElement.GetProperty("samples").EnumerateArray()){
        ushort token=sample.GetProperty("token").GetUInt16();var path=Mpu4VmPrimitiveTiming.Path(token) ?? throw new Exception("Missing primitive timing");
        var instructions=sample.GetProperty("instructions");Equal(path.Count,instructions.GetArrayLength());ulong cursor=sample.GetProperty("start_cycle").GetUInt64();
        Equal(path[2].Address,Convert.ToUInt16(sample.GetProperty("header_hex").GetString(),16));
        for(int i=0;i<path.Count;i++){
            var actual=instructions[i];Equal(path[i].Address,actual.GetProperty("pc").GetUInt16());
            byte[] bytes=Convert.FromHexString(path[i].Bytes);var timing=M6809InstructionTiming.Decode(bytes);Equal(bytes.Length,timing.Length);
            Equal(true,actual.GetProperty("context_hex").GetString()!.StartsWith(path[i].Bytes,StringComparison.Ordinal));
            Equal(cursor,actual.GetProperty("cycle").GetUInt64());cursor+=(ulong)timing.Cycles;Equal(cursor,actual.GetProperty("completion_cycle").GetUInt64());
        }
        Equal(sample.GetProperty("end_cycle").GetUInt64(),cursor);Equal(cursor-sample.GetProperty("start_cycle").GetUInt64(),Mpu4VmPrimitiveTiming.Cycles(token)!.Value);
        counts[token]=counts.GetValueOrDefault(token)+1;count++;
    }
    Equal(54,count);Equal(5,counts[0x78B5]);Equal(1,counts[0x795B]);Equal(35UL,Mpu4VmPrimitiveTiming.Cycles(0x7963)!.Value);
    Equal(4,counts[0x7963]);Equal(44,counts[0x792F]);
    Equal(30UL,Mpu4VmPrimitiveTiming.Cycles(0x78B5)!.Value);Equal(35UL,Mpu4VmPrimitiveTiming.Cycles(0x795B)!.Value);Equal(27UL,Mpu4VmPrimitiveTiming.Cycles(0x792F)!.Value);
    Equal<ulong?>(null,Mpu4VmPrimitiveTiming.Cycles(0x76A9));
});
Check("Complete selected outer timer1 services match native costs with each child counted once", () => {
    using var outer=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","ptm-outer-timing.json")));
    using var services=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","ptm-service-timing.json")));
    using var prefix=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","ptm-instruction-boundaries.json")));
    var catalog=outer.RootElement.GetProperty("catalog");int parents=0,nativeCount=0,children=0,branches=0;ulong min=ulong.MaxValue,max=0;
    ulong InstructionCycles(System.Text.Json.JsonElement ins){byte[] b=Convert.FromHexString(ins.GetProperty("context_hex").GetString()!);return (ulong)M6809InstructionTiming.Decode(b,stackedCC:b[0]==0x3B ? (byte)0x80 : null).Cycles;}
    foreach(var p in outer.RootElement.GetProperty("parents").EnumerateArray()){
        ulong entry=p.GetProperty("entry_cycle").GetUInt64(),accepted=p.GetProperty("accepted_cycle").GetUInt64(),cursor=entry,own=0,childWork=0;Equal(accepted+M6809IrqEntry.EntryCycles,entry);
        foreach(var s in p.GetProperty("steps").EnumerateArray()){
            Equal(entry+s[1].GetUInt64(),cursor);
            if(s[0].GetInt32()==1){
                int index=s[2].GetInt32();var pre=prefix.RootElement.GetProperty("windows")[index];var tail=services.RootElement.GetProperty("timer3_tails")[index];ulong childStart=cursor;
                cursor+=M6809IrqEntry.EntryCycles;Equal(pre.GetProperty("handler_cycle").GetUInt64(),cursor);
                foreach(var ins in pre.GetProperty("handler_path").EnumerateArray()){Equal(ins.GetProperty("cycle").GetUInt64(),cursor);cursor+=InstructionCycles(ins);}
                foreach(var ins in tail.GetProperty("instructions").EnumerateArray()){Equal(ins.GetProperty("cycle").GetUInt64(),cursor);cursor+=InstructionCycles(ins);}
                Equal(entry+s[3].GetUInt64(),cursor);Equal(251UL,cursor-childStart);childWork+=cursor-childStart;children++;continue;
            }
            Equal(0,s[0].GetInt32());var insn=catalog[s[2].GetInt32()];ushort pc=insn.GetProperty("pc").GetUInt16();byte cc=s[3].GetByte();byte[] bytes=Convert.FromHexString(insn.GetProperty("context_hex").GetString()!);
            bool longBranch=bytes[0]==0x10 && bytes[1] is >=0x21 and <=0x2F;bool shortBranch=bytes[0] is >=0x20 and <=0x2F;
            bool? taken=longBranch ? M6809InstructionTiming.EvaluateBranch(bytes[1],cc) : null;
            var timing=M6809InstructionTiming.Decode(bytes,taken,bytes[0]==0x3B ? (byte)0x80 : null);
            if(longBranch || shortBranch || bytes[0]==0x16){
                bool jump=bytes[0]==0x16 || M6809InstructionTiming.EvaluateBranch(longBranch ? bytes[1] : bytes[0],cc);
                int disp=shortBranch ? unchecked((sbyte)bytes[1]) : unchecked((short)((bytes[timing.Length-2]<<8)|bytes[timing.Length-1]));
                Equal(s[5].GetUInt16(),unchecked((ushort)(pc+timing.Length+(jump ? disp : 0))));branches++;
            }
            cursor+=(ulong)timing.Cycles;own+=(ulong)timing.Cycles;
            if(cursor!=entry+s[4].GetUInt64())throw new Exception($"Outer{parents} native {pc:X4} {Convert.ToHexString(bytes)} timing differs: {cursor}, expected {entry+s[4].GetUInt64()}");
            nativeCount++;
        }
        Equal(p.GetProperty("resumed_cycle").GetUInt64(),cursor);Equal(M6809IrqEntry.EntryCycles+own+childWork,cursor-accepted);min=Math.Min(min,cursor-accepted);max=Math.Max(max,cursor-accepted);parents++;
    }
    Equal(19,parents);Equal(7820,nativeCount);Equal(19,children);Equal(611,catalog.GetArrayLength());Equal(1627UL,min);Equal(3409UL,max);Equal(1854,branches);
});
Check("MC6809 branch conditions retain unsigned, signed and zero flag distinctions", () => {
    Equal(true,M6809InstructionTiming.EvaluateBranch(0x22,0));Equal(false,M6809InstructionTiming.EvaluateBranch(0x22,4));Equal(true,M6809InstructionTiming.EvaluateBranch(0x23,1));
    Equal(true,M6809InstructionTiming.EvaluateBranch(0x2C,10));Equal(false,M6809InstructionTiming.EvaluateBranch(0x2C,8));Equal(true,M6809InstructionTiming.EvaluateBranch(0x2D,2));
    Equal(false,M6809InstructionTiming.EvaluateBranch(0x2E,4));Equal(true,M6809InstructionTiming.EvaluateBranch(0x2F,4));Equal(false,M6809InstructionTiming.EvaluateBranch(0x21,0));
    bool unsupported=false;try{M6809InstructionTiming.EvaluateBranch(0x39,0);}catch(NotSupportedException){unsupported=true;}Equal(true,unsupported);
});
Check("Natural timer3 callback completion and IRQ return match source-derived instruction costs", () => {
    using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","ptm-service-timing.json")));
    int tails=0;
    foreach(var tail in doc.RootElement.GetProperty("timer3_tails").EnumerateArray()){
        ulong callback=tail.GetProperty("callback_cycle").GetUInt64(),cursor=callback;ulong? rts=null,returned=null;
        foreach(var ins in tail.GetProperty("instructions").EnumerateArray()){
            Equal(ins.GetProperty("cycle").GetUInt64(),cursor);byte[] bytes=Convert.FromHexString(ins.GetProperty("context_hex").GetString()!);
            // All selected ordinary-IRQ frames retain saved E=1. This is not
            // inferred from the handler's current CC; the source/trace basis
            // and actual resumed PC are retained separately in the fixture.
            var timing=M6809InstructionTiming.Decode(bytes,stackedCC:bytes[0]==0x3B ? (byte)0x80 : null);
            if(ins.GetProperty("pc").GetUInt16()==0x4916)rts=cursor;if(ins.GetProperty("pc").GetUInt16()==0xFEF2)returned=cursor;
            cursor+=(ulong)timing.Cycles;Equal(ins.GetProperty("next_cycle").GetUInt64(),cursor);
        }
        Equal(callback+73,rts!.Value);Equal(callback+78,returned!.Value);Equal(tail.GetProperty("resumed_cycle").GetUInt64(),cursor);
        Equal(251UL,cursor-(tail.GetProperty("entry_cycle").GetUInt64()-M6809IrqEntry.EntryCycles));tails++;
    }
    Equal(19,tails);
});
Check("Natural timer1 scan service durations follow native branches and return completion", () => {
    using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","ptm-service-timing.json")));
    int scans=0,instructions=0;ulong min=ulong.MaxValue,max=0;
    foreach(var scan in doc.RootElement.GetProperty("timer1_scans").EnumerateArray()){
        ulong start=scan.GetProperty("entry_cycle").GetUInt64(),cursor=start;
        foreach(var ins in scan.GetProperty("instructions").EnumerateArray()){
            Equal(ins.GetProperty("cycle").GetUInt64(),cursor);var branch=ins.GetProperty("branch_taken");bool? taken=branch.ValueKind==System.Text.Json.JsonValueKind.Null ? null : branch.GetBoolean();
            var timing=M6809InstructionTiming.Decode(Convert.FromHexString(ins.GetProperty("context_hex").GetString()!),taken);cursor+=(ulong)timing.Cycles;Equal(ins.GetProperty("next_cycle").GetUInt64(),cursor);instructions++;
        }
        Equal(scan.GetProperty("returned_cycle").GetUInt64(),cursor);Equal(scan.GetProperty("rts_cycle").GetUInt64()+5,cursor);min=Math.Min(min,cursor-start);max=Math.Max(max,cursor-start);scans++;
    }
    Equal(19,scans);Equal(425UL,min);Equal(467UL,max);Equal(1988,instructions);
});
Check("Natural nested IRQ returns restore saved PCs and remain inside their parent service", () => {
    using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","ptm-service-timing.json")));
    var irqs=doc.RootElement.GetProperty("irqs").EnumerateArray().ToArray();int parents=0,children=0;
    foreach(var irq in irqs){
        Equal(1,irq.GetProperty("stacked_cc_e").GetInt32());var rti=irq.GetProperty("rti");var timing=M6809InstructionTiming.Decode(Convert.FromHexString(rti.GetProperty("context_hex").GetString()!),stackedCC:0x80);
        Equal(rti.GetProperty("cycle").GetUInt64()+(ulong)timing.Cycles,irq.GetProperty("resumed_cycle").GetUInt64());Equal(irq.GetProperty("saved_resume_pc").GetUInt16(),irq.GetProperty("resumed_pc").GetUInt16());
        if(irq.GetProperty("depth").GetInt32()==0){parents++;continue;}
        Equal(1,irq.GetProperty("depth").GetInt32());Equal(132,irq.GetProperty("status").GetInt32());children++;
        ulong from=irq.GetProperty("accepted_cycle").GetUInt64(),to=irq.GetProperty("resumed_cycle").GetUInt64();Equal(251UL,to-from);
        var parent=irqs.Single(p=>p.GetProperty("depth").GetInt32()==0 && p.GetProperty("accepted_cycle").GetUInt64()<=from && p.GetProperty("resumed_cycle").GetUInt64()>=to);
        ulong outer=parent.GetProperty("resumed_cycle").GetUInt64()-parent.GetProperty("accepted_cycle").GetUInt64();if(outer<=to-from)throw new Exception("Child is not contained in outer CPU occupancy");
    }
    Equal(38,irqs.Length);Equal(19,parents);Equal(19,children);
});
Check("RTI timing requires saved CC and long conditional timing requires an outcome", () => {
    Equal(15,M6809InstructionTiming.Decode(new byte[]{0x3B},stackedCC:0x80).Cycles);Equal(6,M6809InstructionTiming.Decode(new byte[]{0x3B},stackedCC:0).Cycles);
    Equal(5,M6809InstructionTiming.Decode(new byte[]{0x10,0x26,0,4},false).Cycles);Equal(6,M6809InstructionTiming.Decode(new byte[]{0x10,0x26,0,4},true).Cycles);
    bool missing=false;try{M6809InstructionTiming.Decode(new byte[]{0x10,0x26,0,4});}catch(NotSupportedException){missing=true;}Equal(true,missing);
});
Check("Native instruction durations explain all nineteen Skill Cash IRQ and callback windows", () => {
    using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","ptm-instruction-boundaries.json")));
    int windows=0,instructions=0;ulong min=ulong.MaxValue,max=0;
    foreach(var w in doc.RootElement.GetProperty("windows").EnumerateArray()){
        ulong bus=w.GetProperty("latch_bus_cycle").GetUInt64(),assertion=w.GetProperty("calculated_assertion_cycle").GetUInt64();
        Equal(true,w.GetProperty("initial_high").GetBoolean());Equal(Mpu4Timer3Deadline.Calculate(bus,40,true).Interrupt,assertion);
        var last=w.GetProperty("last_instruction");ulong start=last.GetProperty("cycle").GetUInt64();var timing=M6809InstructionTiming.Decode(Convert.FromHexString(last.GetProperty("context_hex").GetString()!));
        ulong completed=checked(start+(ulong)timing.Cycles);if(assertion<start || assertion>completed)throw new Exception("Timer assertion is outside completing instruction");
        byte cc=last.GetProperty("cc").GetByte();Equal(0,cc&0x10);
        // Timing-only register seed: full natural frame matching is covered by
        // the independent native IRQ matrix, not fabricated register contents.
        var irq=M6809IrqEntry.AtInstructionBoundary(completed,new(cc,0,0,0,0,0,0,0x700,0),true)!;
        Equal(w.GetProperty("handler_cycle").GetUInt64(),irq.HandlerCycle);
        ulong observedLevel=w.GetProperty("first_cpu_level_sample").GetProperty("cycle").GetUInt64();
        if(observedLevel<assertion || observedLevel>assertion+1 || observedLevel>completed+1)throw new Exception("Unexpected delivered-level observation gap");
        ulong cursor=irq.HandlerCycle;
        foreach(var ins in w.GetProperty("handler_path").EnumerateArray()){
            Equal(ins.GetProperty("cycle").GetUInt64(),cursor);var native=M6809InstructionTiming.Decode(Convert.FromHexString(ins.GetProperty("context_hex").GetString()!));
            cursor=checked(cursor+(ulong)native.Cycles);instructions++;
        }
        Equal(w.GetProperty("callback_cycle").GetUInt64(),cursor);Equal(128UL,cursor-irq.HandlerCycle);
        ulong latency=irq.HandlerCycle-assertion;min=Math.Min(min,latency);max=Math.Max(max,latency);windows++;
    }
    Equal(19,windows);Equal(608,instructions);Equal(19UL,min);Equal(26UL,max);
});
Check("Selected MC6809 timing handles indexed offsets and register masks without guessing opcodes", () => {
    foreach(var item in new[]{("AEA1",2,8),("A789008E",4,8),("E680",2,6),("31AB",2,8),("3596",2,11),("3405",2,7),("AD84",2,7),("39",1,5)}){
        var r=M6809InstructionTiming.Decode(Convert.FromHexString(item.Item1));Equal(item.Item2,r.Length);Equal(item.Item3,r.Cycles);
    }
    bool unknown=false,truncated=false,postbyte=false;
    try{M6809InstructionTiming.Decode(new byte[]{0x3B});}catch(NotSupportedException){unknown=true;}
    try{M6809InstructionTiming.Decode(new byte[]{0xA7,0x89,0});}catch(InvalidDataException){truncated=true;}
    try{M6809InstructionTiming.Decode(new byte[]{0xAE,0x87});}catch(NotSupportedException){postbyte=true;}
    Equal(true,unknown);Equal(true,truncated);Equal(true,postbyte);
});
Check("Natural Skill Cash connects timer3 phase and bus time to CPU IRQ and lamp callback", () => {
    using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","ptm-skill-cpu.json")));
    using var old=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","timer-deadlines.json")));
    var reference=old.RootElement.GetProperty("rows").EnumerateArray().ToArray();
    int Number(System.Text.Json.JsonElement r,string n)=>int.Parse(r.GetProperty(n).GetString()!,System.Globalization.CultureInfo.InvariantCulture);
    int Hex(System.Text.Json.JsonElement r,string n)=>Convert.ToInt32(r.GetProperty(n).GetString(),16);
    decimal Time(System.Text.Json.JsonElement r)=>decimal.Parse(r.GetProperty("seconds").GetString()!,System.Globalization.CultureInfo.InvariantCulture)*Mpu4Timer3PhaseClock.AttosecondsPerSecond+decimal.Parse(r.GetProperty("attoseconds").GetString()!,System.Globalization.CultureInfo.InvariantCulture);
    ulong Cycle(decimal t)=>(ulong)decimal.Round(t*(decimal)SkillCashLiveSession.CyclesPerSecond/Mpu4Timer3PhaseClock.AttosecondsPerSecond);
    Mpu4Timer3PhaseClock? clock=null;byte msb=0;int count=0,arms=0,handlers=0,callbacks=0;decimal? firstAssertion=null;ulong? handler=null;ulong min=ulong.MaxValue,max=0;
    foreach(var r in doc.RootElement.GetProperty("rows").EnumerateArray()){
        decimal time=Time(r);string kind=r.GetProperty("event").GetString()!;int at=Hex(r,"address"),data=Hex(r,"data");
        Equal(0,Number(r,"gate3"));Equal(0,Number(r,"clock3"));
        if(clock is null){Equal("entry",kind);Equal(0,Number(r,"control3"));Equal(0,Number(r,"enabled3"));clock=Mpu4Timer3PhaseClock.FromStoppedSnapshot(time,Number(r,"output3")!=0,Number(r,"single3")!=0,(ushort)Number(r,"latch3"),(ushort)Number(r,"counter3"),(Number(r,"status")&4)!=0,(Number(r,"statusread")&4)!=0);}
        clock.AdvanceTo(time);
        if(kind=="read"){if(at==0x901)clock.ReadStatus();if(at==0x906)clock.ReadCounterMsb();}
        Equal(Number(r,"output3")!=0,clock.OutputHigh);Equal(Number(r,"single3")!=0,clock.SingleFired);Equal(Number(r,"enabled3")!=0,clock.Enabled);Equal(Number(r,"counter3"),(int)clock.RawCounter);Equal(Number(r,"latch3"),(int)clock.Latch);Equal(Number(r,"control3"),(int)clock.Control);Equal((Number(r,"status")&4)!=0,clock.InterruptPending);
        if(kind=="handler" && (Number(r,"status")&4)!=0 && firstAssertion.HasValue && handler is null){
            handler=Cycle(time)-1;ulong irq=Cycle(firstAssertion.Value);ulong latency=handler.Value-irq;min=Math.Min(min,latency);max=Math.Max(max,latency);
            if(latency<M6809IrqEntry.EntryCycles || latency>M6809IrqEntry.EntryCycles+7)throw new Exception("Unexplained canonical IRQ entry latency");
            var row=reference[arms-1].EnumerateArray().ToArray();Equal(row[0].GetUInt64()+row[2].GetUInt64(),handler.Value);handlers++;
        }
        if(kind=="callback"){
            if(handler is null)throw new Exception("Callback without observed timer3 IRQ entry");Equal(128UL,Cycle(time)-1-handler.Value);callbacks++;
        }
        if(kind=="write"){
            if(at==0x900)clock.WriteControl((byte)data);if(at==0x906)msb=(byte)data;
            if(at==0x907){Equal(true,clock.OutputHigh);clock.WriteLatch((ushort)((msb<<8)|data));firstAssertion=clock.NextTransition;handler=null;Equal(reference[arms][0].GetUInt64()+7,Cycle(time));arms++;}
        }
        count++;
    }
    Equal(354,count);Equal(20,arms);Equal(19,handlers);Equal(19,callbacks);Equal(19UL,min);Equal(26UL,max);
});
Check("Ordinary 6809 IRQ entry matches eighteen native CPU frames and instruction boundaries", () => {
    using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","ptm-irq-entry.json")));
    int rows=0,masked=0;ulong longest=0;
    foreach(var row in doc.RootElement.GetProperty("rows").EnumerateArray()){
        byte B(string n)=>row.GetProperty(n).GetByte();ushort W(string n)=>row.GetProperty(n).GetUInt16();ulong C(string n)=>row.GetProperty(n).GetUInt64();
        var regs=new M6809IrqRegisters(B("before_cc"),B("a"),B("b"),B("dp"),W("x"),W("y"),W("u"),W("before_s"),W("resume_pc"));
        var entry=M6809IrqEntry.AtInstructionBoundary(C("accepted_cycle"),regs,true) ?? throw new Exception("Unmasked IRQ rejected");
        Equal(C("handler_cycle"),entry.HandlerCycle);Equal(B("handler_cc"),entry.HandlerCC);Equal(W("handler_s"),entry.StackPointer);Equal(row.GetProperty("frame_hex").GetString(),Convert.ToHexString(entry.StackFrame));
        Equal(C("last_instruction_cycle")+C("last_instruction_cycles"),entry.AcceptedCycle);Equal(C("release_instruction_cycle")+5,C("release_bus_cycle"));
        ulong assertion=C("calculated_first_assertion_cycle");if(entry.AcceptedCycle<assertion)throw new Exception("Accepted before assertion");
        ulong delay=entry.AcceptedCycle-assertion;longest=Math.Max(longest,delay);
        if(delay>3)masked++;rows++;
    }
    Equal(18,rows);if(masked<4 || longest<300)throw new Exception("Missing masked IRQ coverage");
});
Check("Ordinary IRQ uses delivered level and I mask while preserving F and wrapping stack", () => {
    var r=new M6809IrqRegisters(0x51,0x12,0x34,0x56,0x789A,0xBCDE,0xF012,5,0x4567);
    Equal<M6809IrqAcceptance?>(null,M6809IrqEntry.AtInstructionBoundary(10,r,true));
    r=r with{CC=0x41};Equal<M6809IrqAcceptance?>(null,M6809IrqEntry.AtInstructionBoundary(20,r,false));
    var e=M6809IrqEntry.AtInstructionBoundary(30,r,true)!;Equal(49UL,e.HandlerCycle);Equal((ushort)0xFFF9,e.StackPointer);Equal((byte)0xD1,e.HandlerCC);Equal("C1123456789ABCDEF0124567",Convert.ToHexString(e.StackFrame));
    Equal((byte)0x41,r.CC);Equal((ushort)5,r.S);
});
Check("Timer3 lifecycle reproduces natural post-shot disable and rearm state", () => {
    using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","ptm-lifecycle.json")));
    var clock=new Mpu4Timer3PhaseClock();byte msb=0;int count=0,arms=0,frozen=0;
    int Number(System.Text.Json.JsonElement row,string name)=>int.Parse(row.GetProperty(name).GetString()!,System.Globalization.CultureInfo.InvariantCulture);
    foreach(var row in doc.RootElement.GetProperty("rows").EnumerateArray()){
        decimal time=decimal.Parse(row.GetProperty("seconds").GetString()!,System.Globalization.CultureInfo.InvariantCulture)*Mpu4Timer3PhaseClock.AttosecondsPerSecond+decimal.Parse(row.GetProperty("attoseconds").GetString()!,System.Globalization.CultureInfo.InvariantCulture);
        clock.AdvanceTo(time);
        string kind=row.GetProperty("event").GetString()!;int at=Convert.ToInt32(row.GetProperty("address").GetString(),16),data=Convert.ToInt32(row.GetProperty("data").GetString(),16);
        if(kind=="read"){
            if(at==0x901){Equal(clock.InterruptPending,(data&4)!=0);clock.ReadStatus();}
            if(at==0x906)clock.ReadCounterMsb();
        }
        Equal(Number(row,"output3")!=0,clock.OutputHigh);Equal(Number(row,"single3")!=0,clock.SingleFired);
        Equal(Number(row,"enabled3")!=0,clock.Enabled);Equal(Number(row,"counter3"),(int)clock.RawCounter);
        Equal(Number(row,"latch3"),(int)clock.Latch);Equal(Number(row,"control3"),(int)clock.Control);
        Equal((Number(row,"status")&4)!=0,clock.InterruptPending);
        if(kind=="write"){
            if(at==0x900)clock.WriteControl((byte)data);
            if(at==0x906)msb=(byte)data;
            if(at==0x907){clock.WriteLatch((ushort)((msb<<8)|data));arms++;}
        }
        if(kind=="after" && at==0x70C5){Equal(false,clock.Enabled);Equal(true,clock.OutputHigh);frozen++;}
        count++;
    }
    Equal(643,count);Equal(20,arms);if(frozen<19)throw new Exception("Missing disable observations");
});
Check("Timer3 lifecycle retains post-shot phase across updates and rejects unsupported modes", () => {
    var coarse=new Mpu4Timer3PhaseClock();var fine=new Mpu4Timer3PhaseClock();
    foreach(var c in new[]{coarse,fine}){c.WriteControl(0x63);c.WriteLatch(40);}
    decimal end=1_000_000_000_000_000m;
    for(decimal t=0;t<end;t+=17_000_000_000_000m)fine.AdvanceTo(t);fine.AdvanceTo(end);coarse.AdvanceTo(end);
    Equal(coarse.OutputHigh,fine.OutputHigh);Equal(coarse.NextTransition,fine.NextTransition);Equal(true,coarse.SingleFired);
    Equal(true,coarse.InterruptPending);coarse.ReadCounterMsb();Equal(true,coarse.InterruptPending);coarse.ReadStatus();coarse.ReadCounterMsb();Equal(false,coarse.InterruptPending);
    coarse.WriteControl(0);ushort held=coarse.RawCounter;bool phase=coarse.OutputHigh;coarse.AdvanceTo(end*2);Equal(held,coarse.RawCounter);Equal(phase,coarse.OutputHigh);coarse.WriteControl(0x63);Equal(phase,coarse.OutputHigh);
    bool zero=false,mode=false,back=false;try{coarse.WriteLatch(0);}catch(NotSupportedException){zero=true;}try{coarse.WriteControl(0x62);}catch(NotSupportedException){mode=true;}try{coarse.AdvanceTo(0);}catch(ArgumentOutOfRangeException){back=true;}Equal(true,zero);Equal(true,mode);Equal(true,back);
});
Check("Natural attract timer3 phase disproves a universal starting-low assumption", () => {
    using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","ptm-natural-phase.json")));
    int low=0,high=0;double previous=0;
    foreach(var row in doc.RootElement.GetProperty("rows").EnumerateArray()){
        double write=double.Parse(row.GetProperty("write_time").GetString()!,System.Globalization.CultureInfo.InvariantCulture),after=double.Parse(row.GetProperty("after_time").GetString()!,System.Globalization.CultureInfo.InvariantCulture);
        if(write<previous || Math.Abs((after-write)*SkillCashLiveSession.CyclesPerSecond-1)>0.00001)throw new InvalidDataException("Phase observation ordering/one-cycle gap differs");previous=after;
        Equal(0x42,row.GetProperty("control1").GetInt32());Equal(0x63,row.GetProperty("control3").GetInt32());Equal(40,row.GetProperty("latch").GetInt32());
        if(row.GetProperty("initial_high").GetInt32()==0)low++;else high++;
    }
    Equal(1,low);Equal(99,high);
    var candidate=SkillCashTimerDeadlineVerification.Verify(evidence,startingOutputHigh:true);Equal(26UL,candidate.MinimumIrqLatency);Equal(33UL,candidate.MaximumIrqLatency);Equal(true,candidate.StartingOutputHigh);
});
Check("MC6840 bus matrix verifies timer1 and both timer3 phases with explicit ties", () => {
    using var capture=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","ptm-matrix.json")));
    int rows=0,ties=0;ulong previous=0;
    foreach(var row in capture.RootElement.GetProperty("rows").EnumerateArray()){
        int channel=row.GetProperty("channel").GetInt32();ushort latch=row.GetProperty("latch").GetUInt16();bool high=row.GetProperty("initial_high").GetInt32()!=0;
        ulong arm=row.GetProperty("arm_cycle").GetUInt64(),read=row.GetProperty("read_cycle").GetUInt64();byte status=row.GetProperty("status").GetByte();
        if(arm<previous || read<arm)throw new InvalidDataException("Unordered matrix bus observations");previous=read;
        ulong expiry;bool pending;
        if(channel==1){var clock=new Mpu4Timer1Clock(arm,latch);expiry=clock.NextExpiry;clock.AdvanceTo(read);pending=clock.Expiries!=0;}
        else if(channel==3){var clock=new Mpu4Timer3Pulse();clock.Arm(arm,latch,high);expiry=clock.Deadline!.Value.Interrupt;clock.AdvanceTo(read);pending=clock.InterruptPending;}
        else throw new InvalidDataException("Unsupported matrix channel");
        bool tie=read==expiry;Equal(tie,row.GetProperty("boundary_tie").GetBoolean());
        byte flag=(byte)(128|(1<<(channel-1)));
        if(tie){ties++;if(status!=0 && status!=flag)throw new InvalidDataException("Invalid tie status");}
        else Equal(pending ? flag : (byte)0,status);
        rows++;
    }
    Equal(96,rows);Equal(6,ties);
    using var source=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"maps","ptm-clock-semantics.json")));
    byte[] bytes=Convert.FromHexString(source.RootElement.GetProperty("ranges").GetProperty("707E").GetString()!);
    Equal((byte)0x8E,bytes[16]);Equal(Mpu4Timer1Clock.NormalLatch,(ushort)((bytes[17]<<8)|bytes[18]));Equal(3441UL,Mpu4Timer1Clock.Period(Mpu4Timer1Clock.NormalLatch));
});
Check("Timer1 periodic clock preserves phase across coarse updates and rejects backwards time", () => {
    var coarse=new Mpu4Timer1Clock(123,Mpu4Timer1Clock.NormalLatch);var fine=new Mpu4Timer1Clock(123,Mpu4Timer1Clock.NormalLatch);
    for(ulong t=123;t<1000000;t+=137)fine.AdvanceTo(t);fine.AdvanceTo(1000000);coarse.AdvanceTo(1000000);
    Equal((1000000UL-123)/3441,coarse.Expiries);Equal(coarse.Expiries,fine.Expiries);Equal(coarse.NextExpiry,fine.NextExpiry);
    bool backwards=false,unsupported=false;try{coarse.AdvanceTo(999999);}catch(ArgumentOutOfRangeException){backwards=true;}try{_=new Mpu4Timer1Clock(0,40,0);}catch(NotSupportedException){unsupported=true;}Equal(true,backwards);Equal(true,unsupported);
});
Check("Timer3 pulse retains state and separates hardware expiry from CPU acknowledgement", () => {
    var clock=new Mpu4Timer3Pulse();clock.Arm(0,40,false);Equal(8UL,clock.NextEvent);clock.AdvanceTo(7);Equal(false,clock.OutputHigh);clock.AdvanceTo(8);Equal(true,clock.OutputHigh);Equal(328UL,clock.NextEvent);
    clock.AdvanceTo(327);Equal(false,clock.InterruptPending);clock.AdvanceTo(328);Equal(true,clock.InterruptPending);Equal(false,clock.OutputHigh);Equal(ulong.MaxValue,clock.NextEvent);
    clock.AdvanceTo(329);bool postShot=false;try{_=clock.OutputHigh;}catch(NotSupportedException){postShot=true;}Equal(true,postShot);
    clock.Acknowledge();clock.AdvanceTo(350);Equal(false,clock.InterruptPending);clock.Arm(400,40,true);Equal(720UL,clock.NextEvent);clock.AdvanceTo(719);Equal(true,clock.OutputHigh);clock.AdvanceTo(720);Equal(true,clock.InterruptPending);
    bool backwards=false,early=false;try{clock.AdvanceTo(719);}catch(ArgumentOutOfRangeException){backwards=true;}clock.Acknowledge();try{clock.Acknowledge();}catch(InvalidOperationException){early=true;}Equal(true,backwards);Equal(true,early);
});
Check("Natural flagged-entry return to board selection matches", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",paidFlagBoard:true);Console.WriteLine($"  {r.Instructions} board VM observations, {r.Lamps} lamps, {r.Sounds} sounds");
});
Check("Natural flagged-entry native motion and board animation match", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",paidFlagMotion:true);Console.WriteLine($"  {r.Instructions} motion VM observations, {r.Lamps} lamps, {r.Sounds} sounds");
});
Check("Natural flagged-entry pot animation and board bootstrap match", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",paidFlagBootstrap:true);Console.WriteLine($"  {r.Instructions} bootstrap observations, {r.Lamps} lamps, {r.Sounds} sounds");
});
Check("Fill retains zero-count guard, wrapping writes, saved Y and surviving U alias", () => {
    var script=new RecoveredScript(Path.Combine(evidence,"VM-SCRIPTS","B7C2.txt"));
    foreach(var row in new[]{(At:(ushort)0x100,Count:(ushort)0),(At:(ushort)0xFFFE,Count:(ushort)4),(At:(ushort)0x6FE,Count:(ushort)1)}){
        var m=new Machine{DataStackBase=0x700};m.Control=new(m,0x800);m.Memory[0x100]=0x55;m.Memory[2]=0x66;m.Data.Push(0xAAAA);m.Data.Push(row.At);m.Data.Push(row.Count);m.Data.Push(0xABCC);
        new ScriptExecutor(m).RunRange(script,0xB7EB,0xB7EB);Equal((ushort)0x800,m.Control.Pointer);Equal((ushort)0xB7ED,m.ReadWord(0x7FE));Equal((ushort)0x6FE,m.DataPointer);Equal(row.At==0x6FE ? (ushort)0xCCAA : (ushort)0xAAAA,m.Data.Peek());Equal((byte)0x55,m.Memory[0x100]);Equal((byte)0x66,m.Memory[2]);
        for(int i=0;i<row.Count;i++)Equal((byte)0xCC,m.Memory[Cell.Add(row.At,(ushort)i)]);
    }
});
Check("Natural flagged-entry table construction and sound completion match", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",paidFlagTable:true);Console.WriteLine($"  {r.Instructions} table observations, {r.Lamps} lamps, {r.Sounds} sounds");
});
Check("Natural flagged-entry software reel plan preserves VM, seed and requests", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",paidFlagReelPlan:true);Console.WriteLine($"  {r.Instructions} software-plan observations, {r.Sounds} sound commands");
});
Check("Natural flagged entry lamp/category preparation matches after accounting", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",paidFlagAnnouncement:true);Console.WriteLine($"  {r.Instructions} flag-entry preparation observations, {r.Lamps} lamps");
});
Check("Packed byte/word store preserves wrap, truncation and overlapping U cells", () => {
    var script=new RecoveredScript(Path.Combine(evidence,"VM-SCRIPTS","EBB8.txt"));
    foreach(ushort at in new ushort[]{0x100,0xFFFF,0x6FC}){
        var m=new Machine{DataStackBase=0x700};m.Memory[0x103]=0x55;m.Data.Push(0xAAAA);m.Data.Push(0x1234);m.Data.Push(0xABCD);m.Data.Push(at);
        new ScriptExecutor(m).RunRange(script,0xEBD2,0xEBD2);Equal((ushort)0x6FE,m.DataPointer);Equal(1,m.Data.Count);Equal((byte)0xCD,m.Memory[at]);Equal(at==0x6FC ? (ushort)0xCD34 : (ushort)0x1234,m.ReadWord(Cell.Add(at,1)));Equal(at==0x6FC ? (ushort)0x34AA : (ushort)0xAAAA,m.Data.Peek());Equal((byte)0x55,m.Memory[0x103]);
    }
});
Check("Natural three-flag feature accounting matches VM, NVRAM and signed counter", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",paidFlagAccounting:true);Console.WriteLine($"  {r.Instructions} flag-accounting observations");
});
Check("Three generated paid games retain one machine, debit each Start and pause between games", () => {
    var live=new SkillCashLiveSession(evidence,boardLink:"ladder",continueBoard:true);var original=live.Machine;int next=3,starts=0,completed=0;bool paid=false,nudgeHeld=false,pausedBetween=false;live.Resume();
    for(int n=0;n<600000 && completed<3;n++){
        if(live.AwaitingBoardSelection)live.SetTake(true);
        if(!paid && live.AwaitingNudgeInput && !live.NudgeMoving){live.SetTake(false);if(next>0 && live.Machine.Memory[0xBE]==next){live.SetNudge(0,true);next--;}}
        if(live.NudgeMoving){live.SetNudge(0,false);nudgeHeld=false;}
        if(live.AwaitingPaidStart && starts==live.PaidGamesCompleted){
            Equal((byte)(6-completed),live.Snapshot().Credits);
            if(completed==1){live.Pause();var frozen=live.Machine.Memory.ToArray();ulong at=live.Cycle;ushort vm=live.VmAddress;int count=live.Instructions;live.AdvanceCycles(1000000);Equal(at,live.Cycle);Equal(vm,live.VmAddress);Equal(count,live.Instructions);Equal(1,live.PaidGamesCompleted);Equal(true,frozen.SequenceEqual(live.Machine.Memory));live.Resume();pausedBetween=true;}
            live.SetStart(true);starts++;
        }
        if(live.Panel.StartPressed && (live.Machine.Memory[3]&128)!=0)live.SetStart(false);
        if(live.PaidSpinMoving)paid=true;
        if(live.AwaitingPaidNudge && !nudgeHeld){live.SetNudge(0,true);nudgeHeld=true;}
        if(completed!=live.PaidGamesCompleted){
            completed=live.PaidGamesCompleted;Equal((byte)(6-completed),live.Snapshot().Credits);Equal((ushort)16,live.Snapshot().CashBank);Equal((ushort)0,live.Snapshot().Pending);Equal((ushort)0,live.Snapshot().CurrentWin);Equal((ushort)0,live.Snapshot().TokenBank);
            for(int i=0;i<25;i++)Equal(unchecked((byte)~live.Machine.Memory[0x2F0+i]),live.Machine.Memory[0x309+i]);
        }
        live.AdvanceCycles(512);
    }
    Equal(3,completed);Equal(3,starts);Equal(true,pausedBetween);Equal(true,ReferenceEquals(original,live.Machine));Equal<string?>(null,live.Fault);Equal((byte)0,live.Panel.PhysicalBlack2);Equal((byte)3,live.Snapshot().Credits);live.Pause();
});
Check("Natural next paid cycle reaches Start prompt with preserved credits and bank", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgePaidNextPrompt:true);Console.WriteLine($"  {r.Instructions} next-prompt observations, {r.AlphaBytes} alpha bytes");
});
Check("Natural paid-game outer return preserves stack balance and protected state", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgePaidReturn:true);Console.WriteLine($"  {r.Instructions} outer paid-return observations");
});
Check("Natural ordinary post-nudge result reaches paid-play return without invented improvement", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgePaidResult:true);Console.WriteLine($"  {r.Instructions} post-nudge observations, {r.Lamps} lamps, {r.Sounds} sounds, {r.AlphaBytes} alpha bytes");
});
Check("IRQ direct-page residue survives local-frame allocation without clearing neighbors", () => {
    var m=new Machine();m.Control=new(m,0x7A8);m.LocalFrame=0x7B4;Array.Fill(m.Memory,(byte)0xBF,0x79D,9);
    m.Control.PreserveInterruptDirectPage(0);Equal((ushort)0x7A8,m.Control.Pointer);m.Control.AllocateLocalFrame(9);
    Equal((ushort)0x79D,m.LocalFrame);Equal((byte)0,m.Memory[m.LocalFrame+2]);Equal((byte)0xBF,m.Memory[m.LocalFrame]);Equal((byte)0xBF,m.Memory[m.LocalFrame+1]);Equal((byte)0xBF,m.Memory[m.LocalFrame+3]);
});
Check("Live mixed nudge inputs reach a paid nudge and preserve prompt/motor Pause", () => {
    var live=new SkillCashLiveSession(evidence,boardLink:"ladder",continueBoard:true);int[] reels=[0,1,0];int next=3;bool started=false,paid=false,ordinary=false,pausedMotor=false,pausedFeature=false,ended=false;byte[]? before=null,nudgeStops=null;live.ObserveDispatch=(i,m)=>{if(i.Site==0xEE16)nudgeStops=m.Memory.ToArray();};live.Resume();
    for(int n=0;n<180000 && !ended;n++){
        if(live.AwaitingBoardSelection && !ordinary)live.SetTake(true);
        if(!paid && live.AwaitingNudgeInput && !live.NudgeMoving){live.SetTake(false);if(next>0 && live.Machine.Memory[0xBE]==next){live.SetNudge(reels[3-next],true);next--;}}
        if(live.NudgeMoving)for(int r=0;r<3;r++)live.SetNudge(r,false);
        if(live.AwaitingPaidStart && !started){live.SetStart(true);started=true;}
        if(started && live.Panel.StartPressed && (live.Machine.Memory[3]&128)!=0)live.SetStart(false);
        if(live.PaidSpinMoving)paid=true;
        if(live.AwaitingPaidNudge && !ordinary){
            ordinary=true;Equal((byte)1,live.Machine.Memory[0xBE]);before=live.Machine.Memory.ToArray();
            live.Pause();ulong at=live.Cycle;ushort vm=live.VmAddress;int count=live.Instructions;live.AdvanceCycles(1000000);Equal(at,live.Cycle);Equal(vm,live.VmAddress);Equal(count,live.Instructions);Equal(true,before.SequenceEqual(live.Machine.Memory));live.Resume();live.SetNudge(0,true);
        }
        if(ordinary && live.MotorBusy && !pausedMotor){live.Pause();var frozen=live.Machine.Memory.ToArray();ulong at=live.Cycle;live.AdvanceCycles(1000000);Equal(at,live.Cycle);Equal(true,frozen.SequenceEqual(live.Machine.Memory));live.Resume();pausedMotor=true;}
        if(live.FeatureEntryMoving && !pausedFeature){live.Pause();var frozen=live.Machine.Memory.ToArray();ulong at=live.Cycle;int count=live.Instructions;live.AdvanceCycles(1000000);Equal(at,live.Cycle);Equal(count,live.Instructions);Equal(true,frozen.SequenceEqual(live.Machine.Memory));live.Resume();pausedFeature=true;}
        live.AdvanceCycles(512);if(ordinary && pausedFeature && live.AwaitingBoardSelection && live.BoardPrompts>=2)ended=true;
    }
    Equal(true,ended);Equal(true,ordinary);Equal(true,pausedMotor);Equal(true,pausedFeature);Equal<string?>(null,live.Fault);Equal(true,live.AwaitingBoardSelection);Equal((byte)16,live.Machine.Memory[0x305]);Equal((byte)0,live.Panel.PhysicalBlack2);Equal((byte)5,live.Snapshot().Credits);Equal((ushort)16,live.Snapshot().CashBank);Equal((ushort)0,live.Snapshot().Pending);Equal((ushort)0,live.Snapshot().CurrentWin);
    for(int r=0;r<3;r++)Equal((byte)((before![0x168+2*r]+(r==0 ? 90 : 0))%96),nudgeStops![0x168+2*r]);
    live.Pause();var promptFrozen=live.Machine.Memory.ToArray();ulong promptAt=live.Cycle;live.AdvanceCycles(1000000);Equal(promptAt,live.Cycle);Equal(true,promptFrozen.SequenceEqual(live.Machine.Memory));live.Resume();
    int Counter(byte[] bytes)=>(bytes[0x7D5]<<16)|(bytes[0x7D6]<<8)|bytes[0x7D7];
    Equal((Counter(before!)-8000)&0xFFFFFF,Counter(live.Machine.Memory));Equal(0,live.PaidGamesCompleted);
    for(int i=0;i<15;i++)Equal(unchecked((byte)~live.Machine.Memory[0x7C9+i]),live.Machine.Memory[0x7D8+i]);
    // A real Start pulse on the re-entered board must reach the existing roll motor.
    live.SetTake(false);live.SetStart(true);bool rolled=false,finishedRoll=false;
    for(int n=0;n<100000 && !finishedRoll;n++){
        if(live.Panel.StartPressed && (live.Machine.Memory[3]&128)!=0)live.SetStart(false);
        if(live.MotorBusy && live.VmAddress!=0xE3AE)rolled=true;
        if(rolled && !live.MotorBusy){finishedRoll=true;break;}
        live.AdvanceCycles(512);
    }
    Equal(true,rolled);Equal(true,finishedRoll);Equal<string?>(null,live.Fault);Equal(false,live.PaidSpinMoving);Equal((byte)5,live.Snapshot().Credits);Equal((ushort)16,live.Snapshot().CashBank);Equal((byte)0,live.Panel.PhysicalBlack2);live.Pause();
});
Check("Natural ordinary paid Nudge1 matches VM, generated motor, lamps and sounds", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgePaidStep:true);Console.WriteLine($"  {r.Instructions} paid-nudge step observations, {r.Lamps} lamps, {r.Sounds} sounds");
});
Check("Natural ordinary paid-nudge offer matches VM, eligibility, lamps and alpha", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgePaidNudge:true);Console.WriteLine($"  {r.Instructions} ordinary-nudge observations, {r.Lamps} lamps, {r.Sounds} sounds, {r.AlphaBytes} alpha bytes");
});
Check("Natural paid-spin result matches VM, lamps and unchanged awards", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeSpinResult:true);Console.WriteLine($"  {r.Instructions} result observations, {r.Lamps} lamps, {r.Sounds} sounds");
});
Check("Natural paid reel spin matches VM, generated optics, sounds and protected RAM", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgePaidSpin:true);Console.WriteLine($"  {r.Instructions} paid-spin observations, {r.Lamps} lamps, {r.Sounds} sounds");
});
Check("Natural remaining spin preparation matches requests, VM and seed", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeSpinPreparation:true);Console.WriteLine($"  {r.Instructions} spin-preparation observations");
});
Check("Pair-or-two-flags result matches18 isolated MAME cases", () => {
    using var matrix=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","fallback-result-matrix.json")));Equal(18,matrix.RootElement.GetProperty("cases").GetArrayLength());
    foreach(var row in matrix.RootElement.GetProperty("cases").EnumerateArray()){
        var m=new SkillCashLiveSession(evidence,boardSelection:true).Machine;Convert.FromHexString(row.GetProperty("before_hex").GetString()!).CopyTo(m.Memory,0);m.DataStackBase=0x668;m.SetDataPointer(0x660);
        AddersNudgeAvailability.PushPairOrTwoFlagsResult(m);m.SyncDataToMemory();Equal((ushort)0x65E,m.DataPointer);Equal(row.GetProperty("exit").GetProperty("b").GetByte(),(byte)m.Data.Peek());
        Equal(row.GetProperty("expected_low_ram_sha256").GetString(),Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(m.Memory.AsSpan(0,0x700))));
    }
});
Check("Natural final-selection script preserves VM, requests and accounting", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeFinalSelection:true);Console.WriteLine($"  {r.Instructions} selection observations");
});
Check("All48 native reel-request cases preserve holds, PRNG order and RAM", () => {
    using var matrix=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","reel-request-matrix.json")));Equal(48,matrix.RootElement.GetProperty("cases").GetArrayLength());
    foreach(var row in matrix.RootElement.GetProperty("cases").EnumerateArray()){
        var m=new SkillCashLiveSession(evidence,boardSelection:true).Machine;Convert.FromHexString(row.GetProperty("before_hex").GetString()!).CopyTo(m.Memory,0);AddersReelSymbols.PrepareUnheldRequests(m);
        var after=Convert.FromHexString(row.GetProperty("after_hex").GetString()!);if(!m.Memory.AsSpan(0,0x700).SequenceEqual(after.AsSpan(0,0x700)))throw new Exception("Reel request matrix differs: "+row.GetProperty("id").GetString());
    }
});
Check("Cancel by sound root preserves unrelated and duplicate tasks", () => {
    var m=new Machine();Convert.FromHexString("C300CE01C4").CopyTo(m.Memory,0x1000);Convert.FromHexString("CE01C0").CopyTo(m.Memory,0x2000);
    var scheduler=new Mpu4ChoiceStreamScheduler(m,0);scheduler.Queue(0x1000);scheduler.Queue(0x2000);scheduler.Queue(0x1000);Equal(3,scheduler.ActiveTasks);
    scheduler.Cancel(0x1000);Equal(2,scheduler.ActiveTasks);scheduler.AdvanceTicks(2);Equal(1,scheduler.ActiveTasks);
    m.Memory[0x719B]=0x80;Equal(false,scheduler.Cancel(0x1000));Equal(1,scheduler.ActiveTasks);m.Memory[0x719B]=0;scheduler.Cancel(0x1000);Equal(false,scheduler.Active);
});
Check("Natural pre-spin random gates retain VM, seed and reel records", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeSpinGates:true);Console.WriteLine($"  {r.Instructions} random-gate observations");
});
Check("Natural pre-spin flags match retained VM and accounting state", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeSpinFlags:true);Console.WriteLine($"  {r.Instructions} pre-spin flag observations");
});
Check("Natural timed start tone matches scheduler commands and paid-spin entry", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeTone:true);Console.WriteLine($"  {r.Instructions} tone VM observations, {r.Sounds} sound commands");
});
Check("Stake helpers match75 isolated MAME counter and percentage cases", () => {
    using var matrix=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","stake-matrix.json")));
    Equal(75,matrix.RootElement.GetProperty("cases").GetArrayLength());
    foreach(var row in matrix.RootElement.GetProperty("cases").EnumerateArray()){
        var m=new SkillCashLiveSession(evidence,boardSelection:true).Machine;Convert.FromHexString(row.GetProperty("before_hex").GetString()!).CopyTo(m.Memory,0);
        int Field(string name)=>row.GetProperty(name).GetInt32();
        m.Memory[0x719A]=(byte)Field("actual_config");m.Memory[0x71A2]=(byte)Field("actual_percentage");
        switch(row.GetProperty("kind").GetString()){
            case "decay":m.Memory[0x719A]=(byte)Field("config");AddersStakeAccounting.Decay(m);break;
            case "target":{
                m.Memory[0x71A2]=(byte)Field("percentage");ushort offset=AddersStakeAccounting.TargetOffset(m),margin=(ushort)Math.Min(offset*2,40);m.WriteWord(0x336,margin);
                Equal(row.GetProperty("return_d").GetUInt16(),(ushort)((offset*2+700-margin)>>1));break;
            }
            case "subtract":m.Memory[0x71A2]=80;AddersStakeAccounting.SubtractConfigured(m,(ushort)Field("selector"));break;
            case "increment":AddersStakeAccounting.Increment(m,0x3DD);break;
        }
        var after=Convert.FromHexString(row.GetProperty("after_hex").GetString()!);
        if(!m.Memory.AsSpan(0,0x700).SequenceEqual(after.AsSpan(0,0x700)) || !m.Memory.AsSpan(0x7C9,31).SequenceEqual(after.AsSpan(0x7C9,31)))throw new Exception("Stake matrix RAM differs: "+row.GetProperty("id").GetString());
    }
});
Check("Synthetic stake faults retain native clamp and invalid-cache repair", () => {
    var m=new SkillCashLiveSession(evidence,boardSelection:true).Machine;m.Memory[0x71A2]=80;ushort at=m.ReadWord(0x1462);m.Memory[at]=0x80;m.WriteWord(Cell.Add(at,1),0);
    bool alarm=false;try{AddersStakeAccounting.SubtractConfigured(m,0);}catch(NotSupportedException e)when(e.Message.Contains("alarm65")){alarm=true;}
    Equal(true,alarm);Equal((byte)0x80,m.Memory[at]);Equal((ushort)0,m.ReadWord(Cell.Add(at,1)));
    m.Memory[0x71A2]=0;m.Memory[0x344]=80;m.Memory[0x345]=0;for(int port=0;port<8;port++)m.Memory[port]=0;
    Equal((ushort)50,AddersStakeAccounting.TargetOffset(m));Equal((byte)0,m.Memory[0x344]);Equal((byte)255,m.Memory[0x345]);
});
Check("Signed double negate and comparison preserve carry, sign and equality boundaries", () => {
    var negate=new RecoveredScript(Path.Combine(evidence,"VM-SCRIPTS","AC03.txt"));
    foreach(uint value in new uint[]{0,1,65535,65536,0x7FFFFFFF,0x80000000,0xFFFFFFFF}){
        var m=new Machine();m.Data.Push((ushort)value);m.Data.Push((ushort)(value>>16));new ScriptExecutor(m).RunRange(negate,0xAC10,0xAC10);
        uint expected=unchecked(0u-value);Equal((ushort)(expected>>16),m.Pop());Equal((ushort)expected,m.Pop());Equal(0,m.Data.Count);
    }
    uint[] values=[0,1,65535,65536,0x7FFFFFFF,0x80000000,0xFFFFFFFF];
    foreach(uint a in values)foreach(uint b in values){
        var m=new Machine();m.Data.Push((ushort)a);m.Data.Push((ushort)(a>>16));m.Data.Push((ushort)b);m.Data.Push((ushort)(b>>16));
        new ScriptExecutor(m).RunRange(negate,0xAC12,0xAC12);Equal(Cell.Flag(unchecked((int)b)>unchecked((int)a)),m.Pop());Equal(0,m.Data.Count);
    }
});
Check("Natural paid-play consumes credit and records stake before spin", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeStake:true);Console.WriteLine($"  {r.Instructions} stake observations, {r.Lamps} lamps, {r.AlphaBytes} alpha bytes");
});
Check("Right rotation uses the native low-byte count and wraps at sixteen", () => {
    var script=new RecoveredScript(Path.Combine(evidence,"VM-SCRIPTS","9E3A.txt"));
    foreach(ushort count in new ushort[]{0,1,2,15,16,17,255,256,65535})foreach(ushort value in new ushort[]{0,1,0x8000,0xA501,65535}){
        var m=new Machine();m.Data.Push(value);m.Data.Push(count);ushort expected=value;
        for(int n=0;n<(count&15);n++)expected=(ushort)((expected>>1)|((expected&1)<<15));
        new ScriptExecutor(m).RunRange(script,0x9E3E,0x9E3E);Equal(expected,m.Data.Peek());Equal(1,m.Data.Count);
    }
});
Check("Natural physical Start traverses the recovered preplay decision", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeStart:true);Console.WriteLine($"  {r.Instructions} Start observations, {r.Lamps} lamps, {r.Conditions} input reads");
});
Check("Natural preplay eligibility reaches first Start decision", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeEligibility:true);Console.WriteLine($"  {r.Instructions} eligibility observations, {r.Lamps} lamps, {r.AlphaBytes} alpha bytes");
});
Check("Natural background and credit loop return reaches FC99 preplay dispatcher", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgePreplay:true);Console.WriteLine($"  {r.Instructions} preplay observations, {r.Lamps} lamps, {r.AlphaBytes} alpha bytes");
});
Check("Natural background guards and64 compatibility responses match MAME", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeServices:true);Console.WriteLine($"  {r.Instructions} service observations, {r.Lamps} lamps");
});
Check("Background guards preserve count wrap, NVRAM faults and explicit reset/menu boundaries", () => {
    foreach(byte count in new byte[]{0,1,2,255})foreach(byte mode in new byte[]{0,128}){
        var m=new Machine();m.Memory[0x323]=0;Mpu4Nvram.Refresh(m);m.Memory[0x323]=mode;m.Memory[0x38]=count;m.Memory[0x2C]=0x5A;
        AddersBackgroundServices.CheckNvram(m);Equal(unchecked((byte)(count-1)),m.Memory[0x38]);Equal((byte)0x5A,m.Memory[0x2C]);
    }
    var broken=new Machine();Mpu4Nvram.Refresh(broken);broken.Memory[0x38]=1;broken.Memory[0x309]^=1;bool fault=false;
    try{AddersBackgroundServices.CheckNvram(broken);}catch(NotSupportedException e)when(e.Message.Contains("6EDE")){fault=true;}
    Equal(true,fault);Equal((byte)1,broken.Memory[0x2C]);Equal((byte)0,broken.Memory[0x38]);
    var door=new SkillCashLiveSession(evidence).Machine;door.Memory[0x323]=0x80;door.Memory[2]=0;door.Memory[0x309]=0xA5;door.Memory[0x7D8]=0xC3;bool reset=false;
    try{AddersBackgroundServices.RefreshDoor(door);}catch(NotSupportedException e)when(e.Message.Contains("7CCF")){reset=true;}
    Equal(true,reset);Equal((byte)0,door.Memory[0x323]);Equal((byte)0x5A,door.Memory[0x2F0]);Equal((byte)0x3C,door.Memory[0x7C9]);
    door.Memory[0x323]=0x80;door.Memory[2]=0x20;bool menu=false;
    try{AddersBackgroundServices.CheckTestGate(door);}catch(NotSupportedException e)when(e.Message.Contains("service/Test")){menu=true;}Equal(true,menu);
});
Check("Characteriser scan retains bypass, mask and mismatch alarm with explicit adapter", () => {
    var m=new Machine();BoardLinkState.LoadData(m,evidence);int reads=0;
    AddersBackgroundServices.VerifyCharacteriser(m,x=>{reads++;return (byte)(m.Memory[x]|3);});Equal(64,reads);
    m.Memory[0x719B]=1;AddersBackgroundServices.VerifyCharacteriser(m,_=>throw new Exception("Bypassed scan read device"));
    m.Memory[0x719B]=0;bool fault=false;try{AddersBackgroundServices.VerifyCharacteriser(m,x=>(byte)(m.Memory[x]^4));}catch(NotSupportedException e)when(e.Message.Contains("alarm16")){fault=true;}Equal(true,fault);
});
Check("Status native lamps match isolated MAME branches including duplicate clear", () => {
    using var fixture=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","status-matrix.json")));
    foreach(var row in fixture.RootElement.GetProperty("cases").EnumerateArray()){
        var m=new SkillCashLiveSession(evidence).Machine;BoardLinkState.LoadData(m,evidence);Convert.FromHexString(row.GetProperty("before_hex").GetString()!).CopyTo(m.Memory,0);var setup=row.GetProperty("setup");
        m.Memory[0xC02]=setup.GetProperty("aux").GetByte();m.Memory[0xF02]=setup.GetProperty("triac").GetByte();
        var observed=new List<string>();var lamps=new Mpu4LampRequests(m,r=>observed.Add($"{r.Id:X2}:{r.Pattern:X2}"));AddersStatusService.Refresh(m,lamps);
        Equal(string.Join(",",row.GetProperty("lamps").EnumerateArray().Select(r=>$"{r[0].GetByte():X2}:{r[1].GetByte():X2}")),string.Join(",",observed));
    }
});
Check("Natural status service matches MAME lamp frames and VM boundary", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeStatus:true);Console.WriteLine($"  {r.Instructions} status observations, {r.Lamps} lamps");
});
Check("Natural preplay dispatch reaches status service with exact MAME state", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeBackground:true);
    Console.WriteLine($"  {r.Instructions} background observations, {r.Lamps} lamps");
});
Check("IC8 script sets only bit10 for008F and clears it for other cells", () => {
    var catalog=new RecoveredScriptCatalog(Path.Combine(evidence,"VM-SCRIPTS"));
    foreach(ushort pattern in new ushort[]{0x8F,0x80,0,0x18F})for(int initial=0;initial<256;initial++){
        var m=new Machine();m.Memory[0xF02]=(byte)initial;m.Data.Push(pattern);
        new ScriptExecutor(m){ResolveScript=catalog.Owner}.Run(catalog.Owner(0x9D5A));
        Equal((byte)(pattern==0x8F ? initial|0x10 : initial&0xEF),m.Memory[0xF02]);Equal(0,m.Data.Count);
    }
});
Check("Natural IC8 output update matches MAME latch and VM state", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeIc8:true);
    Console.WriteLine($"  {r.Instructions} IC8 observations, {r.Lamps} lamps");
});
Check("Bank-limit VM preserves 99/500 option branches and signed threshold behaviour", () => {
    foreach(byte option in new byte[]{0,255})foreach(ushort bank in new ushort[]{0,99,100,500,501,0xFFFF}) {
        var m=new Machine();BoardLinkState.LoadData(m,evidence);m.Memory[0xFF4A]=option;m.WriteWord(0x2FC,bank);
        var catalog=new RecoveredScriptCatalog(Path.Combine(evidence,"VM-SCRIPTS"));bool service=false;
        var executor=new ScriptExecutor(m){ResolveScript=catalog.Owner,WordHandler=(i,state)=>{if(i.Token!=0xAA29)return false;service=true;throw new NotSupportedException("Synthetic bank-service boundary");}};
        ushort limit=(ushort)(option==0 ? 99 : 500);
        try{executor.Run(catalog.Owner(0xAEF9));}catch(NotSupportedException e)when(e.Message=="Synthetic bank-service boundary"){}
        Equal((short)bank>(short)limit,service);Equal(bank,m.ReadWord(0x2FC));
    }
});
Check("VM stack balance reads saved native entry frame and rejects mismatches", () => {
    var m=new Machine{DataStackBase=0x800};m.WriteWord(0xF2,0xFFFC);m.WriteWord(0,0x800);
    var script=new RecoveredScript(Path.Combine(evidence,"VM-SCRIPTS","9ABE.txt"));
    new ScriptExecutor(m).Run(script);Equal(0,m.Data.Count);Equal((ushort)0x800,m.DataPointer);
    m.WriteWord(0,0x7FE);bool rejected=false;
    try{new ScriptExecutor(m).Run(script);}catch(NotSupportedException e)when(e.Message.Contains("FE63") || e.Message.Contains("raise_software_error")){rejected=true;}
    Equal(true,rejected);
});
Check("Idle serial native return is exact; busy serial is never silently skipped", () => {
    var live=new SkillCashLiveSession(evidence);var m=live.Machine;
    var lamps=new Mpu4LampRequests(m,_=>throw new Exception("Idle serial emitted a lamp"));var scheduler=new Mpu4ChoiceStreamScheduler(m,0);var alpha=new Mpu4Alpha(m);
    var i=new Instruction(0xFAE1,0x80EC,"call_poll_serial_transfer_until_completion_or_timeout",null,null,null,null,0x5429);
    m.Memory[0x7D]=0;var before=m.Memory.ToArray();Equal(true,AddersNativeWords.Handle(i,m,lamps,scheduler,alpha));Equal(true,before.SequenceEqual(m.Memory));
    m.Memory[0x7D]=1;before=m.Memory.ToArray();bool rejected=false;
    try{AddersNativeWords.Handle(i,m,lamps,scheduler,alpha);}catch(NotSupportedException e)when(e.Message.Contains("busy serial")){rejected=true;}
    Equal(true,rejected);Equal(true,before.SequenceEqual(m.Memory));
});
Check("Natural next-cycle initialization matches MAME through explicit IC8 output boundary", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeCycleInit:true);
    Console.WriteLine($"  {r.Instructions} cycle-init observations, {r.Lamps} lamps, {r.Sounds} sounds, {r.AlphaBytes} alpha bytes");
});
Check("Natural bank-limit service and collect gate match MAME through paid-play return", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeBankReturn:true);
    Console.WriteLine($"  {r.Instructions} bank-return observations, {r.Lamps} lamps, {r.Sounds} sounds, {r.AlphaBytes} alpha bytes");
});
Check("Scaled accounting counter and complements match isolated MAME including overflow boundary", () => {
    using var matrix=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","scaled-accounting-matrix.json")));
    foreach(var row in matrix.RootElement.GetProperty("cases").EnumerateArray()) {
        var m=new SkillCashLiveSession(evidence).Machine;BoardLinkState.LoadData(m,evidence);Convert.FromHexString(row.GetProperty("before_hex").GetString()!).CopyTo(m.Memory,0);
        bool alarm=false;
        try{AddersAwardStatistics.AddScaled(m,row.GetProperty("amount").GetUInt16(),row.GetProperty("selector").GetUInt16());}catch(NotSupportedException e)when(e.Message.Contains("alarm65")){alarm=true;}
        Equal(row.GetProperty("alarm65").GetBoolean(),alarm);
        Equal(row.GetProperty("expected_low_ram_sha256").GetString(),Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(m.Memory.AsSpan(0,0x700))));
        Equal(row.GetProperty("expected_accounting_hex").GetString(),Convert.ToHexString(m.Memory.AsSpan(0x7C9,31)));
    }
    var invalid=new Machine();var before=invalid.Memory.ToArray();bool rejected=false;
    try{AddersAwardStatistics.AddScaled(invalid,1,5);}catch(NotSupportedException e)when(e.Message.Contains("alarm64")){rejected=true;}
    Equal(true,rejected);Equal(true,before.SequenceEqual(invalid.Memory));
});
Check("Native award statistics match MAME carry, wrap, alias and mode matrix", () => {
    using var matrix=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","award-statistics-matrix.json")));
    foreach(var row in matrix.RootElement.GetProperty("cases").EnumerateArray()) {
        var m=new Machine();Convert.FromHexString(row.GetProperty("before_hex").GetString()!).CopyTo(m.Memory,0);
        AddersAwardStatistics.Record(m,row.GetProperty("amount").GetUInt16(),row.GetProperty("selector").GetUInt16(),row.GetProperty("global").GetBoolean());
        Equal(row.GetProperty("expected_low_ram_sha256").GetString(),Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(m.Memory.AsSpan(0,0x700))));
    }
});
Check("Natural outer award route reaches native accounting with exact MAME observations", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeAccounting:true);
    Console.WriteLine($"  {r.Instructions} accounting observations, {r.Lamps} lamps, {r.Sounds} sounds, {r.AlphaBytes} alpha bytes");
});
Check("Current-win even rounding preserves native wrap and NVRAM complements", () => {
    foreach(ushort value in new ushort[]{0,1,16,17,65534,65535}) {
        var m=new Machine();m.WriteWord(0x2FA,value);
        new ScriptExecutor(m).Run(new RecoveredScript(Path.Combine(evidence,"VM-SCRIPTS","AF4E.txt")));
        Equal(unchecked((ushort)(value+(value&1))),m.ReadWord(0x2FA));
        for(int n=0;n<25;n++)Equal(unchecked((byte)~m.Memory[0x2F0+n]),m.Memory[0x309+n]);
    }
});
Check("Natural captured tail window matches MAME and the verified transfer boundary", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeTail:true);
    Console.WriteLine($"  {r.Instructions} tail observations, {r.Lamps} lamps, {r.Sounds} sounds, {r.AlphaBytes} alpha bytes");
});
Check("Observed natural transfer prefix matches; source process failed later", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeWinTransfer:true);
    Console.WriteLine($"  {r.Instructions} transfer-prefix observations, {r.Lamps} lamps, {r.Sounds} sounds, {r.AlphaBytes} alpha bytes");
});
Check("Natural nudge pending result returns through the board exit", () => {
    var r=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeExit:true);
    Console.WriteLine($"  {r.Instructions} exit observations, {r.Lamps} lamps, {r.Sounds} sounds, {r.AlphaBytes} alpha bytes");
});
Check("Natural nudge improvement and pending-award return match MAME", () => {
    var result=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeResult:true);
    Console.WriteLine($"  {result.Instructions} result observations, {result.Lamps} lamps, {result.Sounds} sounds, {result.AlphaBytes} alpha bytes");
});
Check("Native movement-plan matrix preserves low RAM, return order and DD", () => {
    using var matrix=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","nudge-plan-matrix.json")));
    foreach(var row in matrix.RootElement.GetProperty("cases").EnumerateArray()) {
        var m=new SkillCashLiveSession(evidence,boardSelection:true).Machine;Convert.FromHexString(row.GetProperty("before_hex").GetString()!).CopyTo(m.Memory,0);
        if(row.GetProperty("kind").GetString()=="plan"){
            m.DataStackBase=0x668;m.SetDataPointer(0x660);AddersNudgeAvailability.PushMovementPlan(m);m.SyncDataToMemory();Equal((ushort)0x65C,m.DataPointer);Equal(row.GetProperty("exit").GetProperty("result").GetUInt16(),m.Data.Peek());
        }else Equal(row.GetProperty("exit").GetProperty("b").GetByte(),AddersNudgeAvailability.Lookup(m));
        Equal(row.GetProperty("expected_low_ram_sha256").GetString(),Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(m.Memory.AsSpan(0,0x700))));
    }
});
Check("Outer loop index follows the saved F6 link", () => {
    var m=new Machine();m.Control=new(m,0x800);m.Control.EnterLoop(0xFFFE,3,0x9000);m.Control.EnterLoop(2,4,0x9100);Equal((ushort)0xFFFE,m.Control.OuterLoopIndex);Equal((ushort)2,m.Control.LoopIndex);
});
Check("Natural three-nudge sequence matches VM, motor phases and all outputs", () => {
    var result=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeSequence:true);
    Console.WriteLine($"  {result.Instructions} sequence observations, {result.Lamps} lamps, {result.Sounds} sounds, {result.AlphaBytes} alpha bytes");
});
Check("Live nudge award returns to Start prompt and consumes one real paid play", () => {
    var live=new SkillCashLiveSession(evidence,boardLink:"ladder",continueBoard:true);bool returned=false,improving=false,pausedImprovement=false,pausedTransfer=false,pausedFlash=false,pausedAccounting=false,paidReady=false,pausedTone=false,pausedPaidSpin=false,ordinaryReady=false;int ordinaryOffered=0;byte[]? spinPositions=null,spinRequests=null;string eligibilityLamps="";string eligibilityAlpha="";int next=3,pressed=0,flashes=0;var meterSteps=new List<ushort>();
    var lamps=new List<byte>();var announcements=new List<string>();live.ObserveDispatch=(i,m)=>{if(i.Native==0x61D5){spinPositions=Enumerable.Range(0,4).Select(n=>m.Memory[0x168+2*n]).ToArray();spinRequests=Enumerable.Range(0,4).Select(n=>m.Memory[0x169+2*n]).ToArray();}if(i.Site==0xFCD5 && !paidReady){eligibilityLamps=Convert.ToHexString(lamps.ToArray());eligibilityAlpha=new Mpu4Alpha(m).Snapshot().Shadow;}if(i.Site==0xAF76)flashes++;if(i.Site==0xE247)lamps.Clear();if(i.Site==0xB666)improving=true;if(i.Site==0xAFC2){Equal((ushort)16,Cell.Add(m.ReadWord(0xBA),m.ReadWord(0x2FA)));meterSteps.Add(m.ReadWord(0x2FA));}};live.ObserveLamp=r=>{lamps.Add(r.Id);lamps.Add((byte)(r.Pattern&15));};live.ObserveAlpha=a=>announcements.Add(a.Text);
    live.Resume();
    for(int n=0;n<180000 && !returned;n++) {
        if(live.PaidGamesCompleted==1 && live.AwaitingPaidStart){returned=true;break;}
        if(live.AwaitingBoardSelection)live.SetTake(true);
        if(live.AwaitingPaidNudge && !ordinaryReady){ordinaryReady=true;ordinaryOffered=live.Machine.Memory[0xBE];next=ordinaryOffered;}
        if(live.AwaitingNudgeInput && !live.NudgeMoving){live.SetTake(false);if(live.Machine.Memory[0xBE]==next && next>0){live.SetNudge(0,true);pressed++;next--;}}
        if(live.NudgeMoving)live.SetNudge(0,false);
        if(improving && live.MotorBusy && !pausedImprovement){live.Pause();var frozen=live.Machine.Memory.ToArray();ulong at=live.Cycle;live.AdvanceCycles(1000000);Equal(at,live.Cycle);Equal(true,frozen.SequenceEqual(live.Machine.Memory));live.Resume();pausedImprovement=true;}
        if(!pausedTransfer && live.Machine.ReadWord(0xBA) is >0 and <16 && live.Machine.ReadWord(0x2FA)>0){live.Pause();var frozen=live.Machine.Memory.ToArray();ulong at=live.Cycle;live.AdvanceCycles(1000000);Equal(at,live.Cycle);Equal(true,frozen.SequenceEqual(live.Machine.Memory));live.Resume();pausedTransfer=true;}
        if(!pausedFlash && flashes>0){live.Pause();var frozen=live.Machine.Memory.ToArray();ulong at=live.Cycle;live.AdvanceCycles(1000000);Equal(at,live.Cycle);Equal(true,frozen.SequenceEqual(live.Machine.Memory));live.Resume();pausedFlash=true;}
        if(!pausedAccounting && live.VmAddress is >=0xAE3A and <=0xAEE2){
            live.Pause();var frozen=live.Machine.Memory.ToArray();var cells=live.Machine.Data.ToArray();ushort vm=live.VmAddress;int instructions=live.Instructions;ulong at=live.Cycle;
            live.AdvanceCycles(1000000);Equal(at,live.Cycle);Equal(vm,live.VmAddress);Equal(instructions,live.Instructions);Equal(true,frozen.SequenceEqual(live.Machine.Memory));Equal(true,cells.SequenceEqual(live.Machine.Data));live.Resume();pausedAccounting=true;
        }
        if(live.AwaitingPaidStart && !paidReady){
            paidReady=true;live.Pause();var frozen=live.Machine.Memory.ToArray();ulong at=live.Cycle;live.AdvanceCycles(1000000);Equal(at,live.Cycle);Equal(true,frozen.SequenceEqual(live.Machine.Memory));live.Resume();live.SetStart(true);
        }
        if(live.PaidSpinMoving && live.MotorBusy && !pausedPaidSpin){
            live.Pause();var frozen=live.Machine.Memory.ToArray();ulong at=live.Cycle;live.AdvanceCycles(1000000);Equal(at,live.Cycle);Equal(true,frozen.SequenceEqual(live.Machine.Memory));live.Resume();pausedPaidSpin=true;
        }
        if(live.TimedToneActive && live.Machine.Memory[0x4D]==0x31 && !pausedTone){
            var delay=live.TimedToneDelay ?? throw new Exception("Missing generated tone deadline");Equal(34276UL,delay.CpuCycles);Equal(true,delay.Deadline>=delay.Started+delay.CpuCycles);
            live.Pause();var frozen=live.Machine.Memory.ToArray();ulong at=live.Cycle;ushort vm=live.VmAddress;int count=live.Instructions;live.AdvanceCycles(1000000);
            Equal(at,live.Cycle);Equal(vm,live.VmAddress);Equal(count,live.Instructions);Equal(true,frozen.SequenceEqual(live.Machine.Memory));Equal(delay,live.TimedToneDelay!.Value);live.Resume();
            live.AdvanceCycles(delay.Deadline-live.Cycle-1);Equal((byte)0x31,live.Machine.Memory[0x4D]);Equal(delay,live.TimedToneDelay!.Value);
            live.AdvanceCycles(1);Equal((byte)0,live.Machine.Memory[0x4D]);Equal(true,live.TimedToneDelay is null);pausedTone=true;
        }
        if(paidReady && live.Panel.StartPressed && (live.Machine.Memory[3]&0x80)!=0)live.SetStart(false);
        live.AdvanceCycles(512);

    }
    Equal(true,returned);Equal(true,ordinaryOffered is >=0 and <=3);Equal(3+ordinaryOffered,pressed);Equal((byte)0,live.Machine.Memory[0xBE]);Equal((byte)0,live.Machine.Memory[0xBF]);Equal((ushort)0,live.Machine.ReadWord(0xBA));Equal((ushort)0,live.Machine.ReadWord(0x2FA));Equal((ushort)16,live.Snapshot().CashBank);Equal((ushort)0,live.Snapshot().TokenBank);Equal((byte)5,live.Snapshot().Credits);Equal((byte)0x30,live.Machine.Memory[0xF02]);Equal(1,live.PaidGamesCompleted);Equal(true,live.AwaitingPaidStart);Equal(true,paidReady);Equal(true,pausedTone);Equal(true,pausedPaidSpin);Equal((byte)0,live.Machine.Memory[0x4D]);Equal((byte)0,live.Panel.PhysicalBlack2);Equal((ushort)0, (ushort)(live.Machine.ReadWord(0x90)&0x80));Equal<string?>(null,live.Fault);
    Equal(7,flashes);Equal(true,pausedAccounting);Equal(true,pausedFlash);Equal(true,pausedTransfer);Equal(true,meterSteps.SequenceEqual(Enumerable.Range(1,16).Select(n=>(ushort)n)));Equal(true,pausedImprovement);Equal(true,announcements.Any(x=>x.Contains("I CAN DO BETTER")));Equal(true,announcements.Any(x=>x.Contains("LET ME THINK")));Equal(true,announcements.Any(x=>x.Contains("HERE I GO")));
    var reference=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeTail:true);Equal(BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeWinTransfer:true).LampSequence+reference.LampSequence+BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeAccounting:true).LampSequence+BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeBankReturn:true).LampSequence+BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeCycleInit:true).LampSequence+BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeIc8:true).LampSequence+BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeBackground:true).LampSequence+BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeStatus:true).LampSequence+BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeServices:true).LampSequence+BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgePreplay:true).LampSequence+BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeEligibility:true).LampSequence,eligibilityLamps);Equal(BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeEligibility:true).AlphaShadow,eligibilityAlpha);
    using var captured=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","nudge-stake.json")));var terminal=Convert.FromHexString(captured.RootElement.GetProperty("terminal_ram_hex").GetString()!);
    Equal(true,spinPositions is not null && spinRequests is not null);Equal(false,live.MotorBusy);
    for(int n=0;n<4;n++){
        int expected=((spinPositions![n]-(sbyte)spinRequests![n]*live.Machine.Memory[0x75CC+2*n]-(n==0 ? 6*ordinaryOffered : 0))%96+96)%96;
        Equal((byte)expected,live.Machine.Memory[0x168+2*n]);Equal((byte)0,live.Machine.Memory[0x169+2*n]);
        terminal[0x2F2+n]=(byte)expected;terminal[0x30B+n]=unchecked((byte)~expected);
    }
    terminal[0x322]=unchecked((byte)(-Enumerable.Range(0x2F0,25).Sum(a=>terminal[a])-0x32));
Equal(true,live.Machine.Memory.AsSpan(0x2F0,0x33).SequenceEqual(terminal.AsSpan(0x2F0,0x33)));
    Equal(true,live.Machine.Memory.AsSpan(0x43A,30).SequenceEqual(terminal.AsSpan(0x43A,30)));Equal(true,live.Machine.Memory.AsSpan(0x7C9,31).SequenceEqual(terminal.AsSpan(0x7C9,31)));
    for(int n=0;n<25;n++)Equal(unchecked((byte)~live.Machine.Memory[0x2F0+n]),live.Machine.Memory[0x309+n]);
});
Check("Explicit loop leave removes only the current frame and retains the target", () => {
    var m=new Machine();m.Control=new(m,0x800);m.Control.EnterLoop(1,3,0x9000);ushort outer=m.Control.LoopFrame;m.Control.EnterLoop(2,5,0x9100);
    m.Control.LeaveLoop();Equal(outer,m.Control.Pointer);Equal(outer,m.Control.LoopFrame);Equal((ushort)1,m.Control.LoopIndex);
});
Check("Natural nudge returns to the next prompt with preserved lamp-native save bytes", () => {
    var result=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeReturn:true);
    Console.WriteLine($"  {result.Instructions} return observations, {result.Lamps} lamps, {result.Sounds} sounds, {result.AlphaBytes} alpha bytes");
});
Check("Lamp range save area survives reuse as a local frame without changing S", () => {
    var m=new Machine();m.Control=new(m,0x796);m.WriteWord(0xF4,0x7B4);m.Data.Push(0x732C);m.Data.Push(0x7335);m.Data.Push(0x8F);
    var lamps=new Mpu4LampRequests(m,_=>{});lamps.HandleWord(new(0x9ADF,0x832B,"lamp",null,null,Native:0x4A8C));
    Equal((ushort)0x796,m.Control.Pointer);Equal((ushort)0x008F,m.ReadWord(0x78C));Equal((ushort)0x7335,m.ReadWord(0x78E));Equal((ushort)0x4A8E,m.ReadWord(0x790));
    m.Control.AllocateLocalFrame(9);Equal((ushort)0x78B,m.LocalFrame);Equal((byte)0x8F,m.Memory[m.LocalFrame+2]);
});
Check("Recovered byte decrement consumes the address and wraps zero to FF", () => {
    foreach(byte value in new byte[]{0,1,255}) {
        var m=new Machine();m.Memory[0x410]=value;m.Data.Push(0x1234);m.Data.Push(0x410);
        var script=new RecoveredScript(Path.Combine(evidence,"VM-SCRIPTS","B306.txt"));new ScriptExecutor(m).RunRange(script,0xB308,0xB308);
        Equal(unchecked((byte)(value-1)),m.Memory[0x410]);Equal((ushort)0x1234,m.Data.Peek());Equal(1,m.Data.Count);
    }
});
Check("Natural main-reel nudge service and optics match MAME", () => {
    var result=DiceMotionVerification.Verify(evidence,generatedOptics:true,nudge:true);Equal((byte)12,result.InitialPosition);Equal((byte)6,result.FinalPosition);Console.WriteLine($"  {result.Services} services, {result.OpticReads} optic reads, main reel {result.InitialPosition}->{result.FinalPosition}");
});
Check("Natural main-reel nudge VM and outputs match MAME through safe post-motion boundary", () => {
    var result=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeMotion:true);Console.WriteLine($"  {result.Instructions} VM observations, {result.Lamps} lamps, {result.Sounds} sounds, {result.AlphaBytes} alpha bytes");
});
Check("Alpha plural suffix uses a space only for count one and advances its operand", () => {
    foreach(byte value in new byte[]{0,1,2,255}) {
        var m=new Machine();m.Memory[0x400]=value;new byte[]{0x61,0x69,0x04,0x00,0x7A}.CopyTo(m.Memory,0x5000);var alpha=new Mpu4Alpha(m);alpha.Execute(0x5000);
        Equal(value==1 ? ' ' : 'S',alpha.Snapshot().Text[0]);Equal((byte)1,m.Memory[0x54]);Equal((ushort)0x5005,m.ReadWord(0x52));
    }
});
Check("Live three nudge controls complete only the selected motor and consume one nudge", () => {
    foreach(int reel in new[]{0,1,2}) {
        var live=new SkillCashLiveSession(evidence,boardLink:"ladder",continueBoard:true);live.Resume();
        for(int n=0;n<30000 && !live.AwaitingNudgeInput;n++){if(live.AwaitingBoardSelection)live.SetTake(true);live.AdvanceCycles(512);}
        Equal(true,live.AwaitingNudgeInput);live.SetTake(false);Equal(true,live.Snapshot().Alpha.Contains("NUDGES"));byte[] positions=[live.Machine.Memory[0x168],live.Machine.Memory[0x16A],live.Machine.Memory[0x16C]];bool pausedMotor=false;
        live.SetNudge(reel,true);Equal((byte)(2<<reel),live.Panel.PhysicalBlack2);live.Pause();Equal((byte)0,live.Panel.PhysicalBlack2);
        var memory=live.Machine.Memory.ToArray();ulong cycle=live.Cycle;live.AdvanceCycles(100000);Equal(cycle,live.Cycle);Equal(true,memory.SequenceEqual(live.Machine.Memory));
        live.Resume();live.SetNudge(reel,true);
        try{for(int n=0;n<10000 && live.Fault is null;n++){
            live.AdvanceCycles(512);
            if(live.AwaitingNudgeInput && live.Machine.Memory[0xBE]==2 && !live.NudgeMoving)break;
            if(!pausedMotor && live.MotorBusy && live.Machine.Memory[0x168+2*reel]!=positions[reel]){live.Pause();var frozen=live.Machine.Memory.ToArray();ulong at=live.Cycle;live.AdvanceCycles(1000000);Equal(at,live.Cycle);Equal(true,frozen.SequenceEqual(live.Machine.Memory));live.Resume();pausedMotor=true;}
        }}catch(NotSupportedException error){if(!error.Message.StartsWith("BOARD nudge motion completed"))throw;}
        Equal<string?>(null,live.Fault);Equal(true,live.AwaitingNudgeInput);
        Equal(true,pausedMotor);Equal(false,live.MotorBusy);
        for(int n=0;n<3;n++){Equal((byte)0,live.Machine.Memory[0x169+2*n]);Equal((byte)((positions[n]+(n==reel ? 90 : 0))%96),live.Machine.Memory[0x168+2*n]);}
        Equal((byte)2,live.Machine.Memory[0xBE]);Equal((byte)2,live.Machine.Memory[0xBF]);Equal((ushort)0,live.Machine.ReadWord(0xBA));Equal((ushort)0,live.Machine.ReadWord(0x2FA));Equal((byte)0,live.Panel.PhysicalBlack2);
    }
});
Check("Natural physical nudge request matches MAME up to motion entry", () => {
    var result=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeRequest:true);
    Console.WriteLine($"  {result.Instructions} request observations, {result.Lamps} lamps, {result.Sounds} sounds, {result.AlphaBytes} alpha bytes");
});
Check("Physical nudge inputs use separate active-high BLACK2 bits and sampled levels", () => {
    var m=new SkillCashLiveSession(evidence).Machine;var panel=new Mpu4PanelInput(m);
    foreach(int reel in new[]{0,1,2}){panel.SetNudge(reel,true);Equal((byte)(2<<reel),panel.PhysicalBlack2);Equal((ushort)0,Mpu4InputConditions.Evaluate(m,(byte)(0x1A-2*reel)));panel.Sample(3);Equal(ushort.MaxValue,Mpu4InputConditions.Evaluate(m,(byte)(0x1A-2*reel)));panel.SetNudge(reel,false);panel.Sample(3);Equal((ushort)0,Mpu4InputConditions.Evaluate(m,(byte)(0x1A-2*reel)));}
    for(int n=0;n<3;n++)panel.SetNudge(n,true);panel.Release();Equal((byte)0,panel.PhysicalBlack2);
});
Check("Native matching-result wrapper matches MAME memory and result", () => {
    using var matrix=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","matching-result-matrix.json")));
    foreach(var row in matrix.RootElement.GetProperty("cases").EnumerateArray()) {
        var m=new SkillCashLiveSession(evidence,boardSelection:true).Machine;Convert.FromHexString(row.GetProperty("before_hex").GetString()!).CopyTo(m.Memory,0);
        m.DataStackBase=0x668;m.SetDataPointer(0x660);AddersNudgeAvailability.PushMatchingResult(m);m.SyncDataToMemory();Equal((ushort)0x65E,m.DataPointer);
        Equal(row.GetProperty("exit").GetProperty("b").GetByte(),(byte)m.Data.Peek());
        Equal(row.GetProperty("expected_low_ram_sha256").GetString(),Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(m.Memory.AsSpan(0,0x700))));
    }
});
Check("Natural nudge prompt matches VM, lamps, sound and alpha before button scan", () => {
    var result=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgePrompt:true);
    Console.WriteLine($"  {result.Instructions} prompt observations, {result.Lamps} lamps, {result.Sounds} sounds, {result.AlphaBytes} alpha bytes");
});
Check("Natural type-1 nudge preparation matches MAME before reel interaction", () => {
    var result=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",nudgeEntry:true);
    Console.WriteLine($"  {result.Instructions} nudge preparation observations, {result.Lamps} lamps, {result.Sounds} sounds, {result.AlphaBytes} alpha bytes");
});
Check("Flagged native search matches MAME low RAM including DD/DE reset", () => {
    using var matrix=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","flagged-availability-matrix.json")));
    foreach(var row in matrix.RootElement.GetProperty("cases").EnumerateArray()) {
        var m=new SkillCashLiveSession(evidence,boardSelection:true).Machine;Convert.FromHexString(row.GetProperty("before_hex").GetString()!).CopyTo(m.Memory,0);
        if(row.GetProperty("kind").GetString()=="flagged-search") {
            m.DataStackBase=0x668;m.SetDataPointer(0x660);AddersNudgeAvailability.ExecuteFlagged(m);m.SyncDataToMemory();Equal((ushort)0x660,m.DataPointer);Equal(row.GetProperty("exit").GetProperty("result").GetUInt16(),m.Data.Peek());
        }else Equal(row.GetProperty("exit").GetProperty("b").GetByte(),AddersNudgeAvailability.Lookup(m));
        Equal(row.GetProperty("expected_low_ram_sha256").GetString(),Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(m.Memory.AsSpan(0,0x700))));
    }
});
Check("Synthetic native search and lookup matrix preserves complete low RAM", () => {
    using var matrix=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","availability-matrix.json")));
    foreach(var row in matrix.RootElement.GetProperty("cases").EnumerateArray()) {
        var m=new SkillCashLiveSession(evidence,boardSelection:true).Machine;Convert.FromHexString(row.GetProperty("before_hex").GetString()!).CopyTo(m.Memory,0);
        if(row.GetProperty("kind").GetString()=="search") {
            m.DataStackBase=0x668;m.SetDataPointer(0x660);AddersNudgeAvailability.Execute(m);m.SyncDataToMemory();Equal((ushort)0x660,m.DataPointer);Equal(row.GetProperty("exit").GetProperty("result").GetUInt16(),m.Data.Peek());
        }else Equal(row.GetProperty("exit").GetProperty("b").GetByte(),AddersNudgeAvailability.Lookup(m));
        string hash=Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(m.Memory.AsSpan(0,0x700)));
        if(hash!=row.GetProperty("expected_low_ram_sha256").GetString())throw new Exception("Native matrix RAM differs: "+row.GetProperty("id").GetString());
    }
});
Check("Natural nudge availability and following prompt match MAME", () => {
    var result=BoardSelectionVerification.Verify(evidence,boardLink:"ladder",continuation:true,availability:true);
    Console.WriteLine($"  {result.Instructions} observations, {result.Lamps} lamps, {result.Sounds} sounds, {result.AlphaBytes} alpha bytes");
});
Check("Natural board continuations preserve VM and all reference outputs", () => {
    foreach(string kind in new[]{"ladder","snake","movement"}) {
        var result=BoardSelectionVerification.Verify(evidence,boardMovement:kind=="movement",boardLink:kind=="movement" ? null : kind,continuation:true);
        Console.WriteLine($"  {kind} continuation: {result.Instructions} observations, {result.Lamps} lamps, {result.Sounds} sounds");
    }
});
Check("Live continuation returns to a board prompt with retained state and accepts another START", () => {
    SkillCashLiveSession? returned=null;
    foreach(int delay in new[]{0,50,100,200,400,800,1200,2000}) {
        var live=new SkillCashLiveSession(evidence,boardSelection:true,continueBoard:true);live.Resume();bool motor=false;
        try{for(int n=0;n<30000 && live.BoardPrompts<2;n++){if(!motor && live.Instructions>250+delay)live.SetStart(true);live.AdvanceCycles(512);motor|=live.Snapshot().DiceRequest?.Busy==true;if(motor)live.SetStart(false);}}
        catch(NotSupportedException error){if(!error.Message.StartsWith("BOARD result type"))throw;}
        if(live.BoardPrompts==2){for(int n=0;n<1000 && !live.AwaitingBoardSelection;n++)live.AdvanceCycles(512);returned=live;break;}
    }
    Equal(true,returned is not null);var session=returned!;Equal((byte)36,session.Machine.Memory[0xC9]);Equal(true,session.AwaitingBoardSelection);
    session.Pause();ulong cycle=session.Cycle;var frozen=session.Machine.Memory.ToArray();session.AdvanceCycles(1_000_000);Equal(cycle,session.Cycle);Equal(true,frozen.SequenceEqual(session.Machine.Memory));
    int visited=session.Snapshot().Board!.Visited.Count;session.Resume();session.SetStart(true);bool nextMotor=false;
    try{for(int n=0;n<60000 && session.BoardPrompts<3;n++){session.AdvanceCycles(512);nextMotor|=session.Snapshot().DiceRequest?.Busy==true;if(nextMotor)session.SetStart(false);}}
    catch(NotSupportedException error){if(!error.Message.StartsWith("BOARD result type") && !error.Message.StartsWith("BOARD nudge availability search"))throw;}
    Equal(true,nextMotor);Equal(false,session.Panel.StartPressed);Equal(true,session.Snapshot().Board!.Visited.Count>visited);
});
Check("Live ladder initializes genuine nudge availability and accepts START or TAKE", () => {
    foreach(bool take in new[]{false,true}) {
        var live=new SkillCashLiveSession(evidence,boardLink:"ladder",continueBoard:true);ushort[] symbols=[live.Machine.ReadWord(0x160),live.Machine.ReadWord(0x162),live.Machine.ReadWord(0x164)];live.Resume();
        for(int n=0;n<30000 && !live.AwaitingBoardSelection;n++)live.AdvanceCycles(512);
        Equal(true,live.AwaitingBoardSelection);Equal((byte)22,live.Machine.Memory[0xC9]);Equal((byte)3,live.Machine.Memory[0xBF]);Equal((byte)16,live.Machine.Memory[0xC8]);
        for(int n=0;n<3;n++)Equal(symbols[n],live.Machine.ReadWord((ushort)(0x160+2*n)));
        live.Pause();ulong cycle=live.Cycle;var memory=live.Machine.Memory.ToArray();live.AdvanceCycles(1_000_000);Equal(cycle,live.Cycle);Equal(true,memory.SequenceEqual(live.Machine.Memory));live.Resume();
        if(take)live.SetTake(true);else live.SetStart(true);bool motor=false;
        try{for(int n=0;n<60000 && live.BoardPrompts<2;n++){live.AdvanceCycles(512);motor|=live.Snapshot().DiceRequest?.Busy==true;if(motor)live.SetStart(false);if(take && live.Machine.Memory[0xBE]==2 && live.AwaitingNudgeInput && !live.NudgeMoving){live.SetNudge(0,false);break;}if(take && live.AwaitingNudgeInput){live.SetTake(false);live.SetNudge(0,true);}if(live.NudgeMoving)live.SetNudge(0,false);}}
        catch(NotSupportedException error){if(!error.Message.StartsWith("BOARD result type") && !error.Message.StartsWith("BOARD nudge motion completed"))throw;}
        if(take){Equal<string?>(null,live.Fault);Equal(true,live.AwaitingNudgeInput);Equal(false,motor);Equal((byte)22,live.Machine.Memory[0xC9]);Equal((byte)2,live.Machine.Memory[0xBE]);Equal((byte)0x15,live.Machine.Memory[0xBD]);}else{Equal(true,motor);Equal(true,live.Snapshot().Board!.Visited.Count>2);}
        Equal((ushort)0,live.Machine.ReadWord(0xBA));Equal((ushort)0,live.Machine.ReadWord(0x2FA));live.Pause();Equal(false,live.Panel.StartPressed);Equal(false,live.Panel.TakePressed);
    }
});
Check("Live snake retains its explicit unrecovered result boundary", () => {
    var live=new SkillCashLiveSession(evidence,boardLink:"snake",continueBoard:true);live.Resume();
    try{for(int n=0;n<60000 && live.Fault is null;n++)live.AdvanceCycles(512);}catch(NotSupportedException){}
    Equal(true,live.Fault?.StartsWith("BOARD result type 8")==true);Equal((byte)7,live.Machine.Memory[0xC9]);Equal(false,live.Panel.StartPressed);
});
Check("Natural ladder VM, destination, pot and output path matches MAME", () => {
    var result=BoardSelectionVerification.Verify(evidence,boardLink:"ladder");Console.WriteLine($"  {result.Instructions} ladder dispatches, {result.Lamps} lamps, {result.Sounds} sound commands, {result.AlphaBytes} alpha bytes");
});
Check("Natural snake VM, destination, pot and output path matches MAME", () => {
    var result=BoardSelectionVerification.Verify(evidence,boardLink:"snake");Console.WriteLine($"  {result.Instructions} snake dispatches, {result.Lamps} lamps, {result.Sounds} sound commands, {result.AlphaBytes} alpha bytes");
});
Check("Live natural links execute incrementally, freeze on pause and retain their destinations", () => {
    foreach(string kind in new[]{"ladder","snake"}) {
        var reference=BoardSelectionVerification.Verify(evidence,boardLink:kind);
        var logicalLamps=new List<byte>();var live=new SkillCashLiveSession(evidence,boardLink:kind);int lamps=0,alpha=0;live.ObserveLamp=r=>{lamps++;logicalLamps.Add(r.Id);logicalLamps.Add((byte)(r.Pattern&15));};live.ObserveAlpha=_=>alpha++;
        byte start=live.Machine.Memory[0xC9];live.Resume();live.AdvanceCycles(1000);live.Pause();
        ulong cycle=live.Cycle;int instructions=live.Instructions;var frozen=live.Machine.Memory.ToArray();
        live.AdvanceCycles(1_000_000);Equal(cycle,live.Cycle);Equal(instructions,live.Instructions);Equal(true,frozen.SequenceEqual(live.Machine.Memory));
        live.Resume();
        try{for(int n=0;n<100000 && live.Fault is null;n++)live.AdvanceCycles(512);}catch(NotSupportedException){}
        Equal(true,live.Fault?.StartsWith("BOARD "+kind+" completed")==true);
        Equal((byte)(kind=="ladder" ? 22 : 7),live.Machine.Memory[0xC9]);Equal((byte)(kind=="ladder" ? 3 : 1),live.Machine.Memory[0xBF]);
        Equal(reference.LampSequence,Convert.ToHexString(logicalLamps.ToArray()));Equal(reference.AlphaShadow,new Mpu4Alpha(live.Machine).Snapshot().Shadow);
        Equal((ushort)0,live.Machine.ReadWord(0xBA));Equal((ushort)0,live.Machine.ReadWord(0x2FA));
        Equal(false,live.Panel.StartPressed);Equal(false,live.Panel.TakePressed);Equal(false,live.AwaitingBoardSelection);
        Equal(true,live.Cycle>cycle);Equal(true,lamps>0);Equal(true,kind=="snake" || alpha>0);Equal(false,start==live.Machine.Memory[0xC9]);
        Console.WriteLine($"  Live {kind}: {live.Instructions} dispatches, {lamps} lamps, {alpha} alpha operations, {live.Cycle/SkillCashLiveSession.CyclesPerSecond:F3}s");
    }
});
Check("Typed board sound restoration rejects changed call frames and callbacks", () => {
    var m=new SkillCashLiveSession(evidence).Machine;ushort clock=BoardLinkState.Apply(m,evidence,"ladder"),at=m.ReadWord(0x47);
    Equal(true,BoardLinkState.ResolveSoundContinuation(m,at) is not null);
    m.WriteWord(Cell.Add(at,0x23),0x972C);Equal(true,BoardLinkState.ResolveSoundContinuation(m,at) is null);
    bool rejected=false;try{new Mpu4ChoiceStreamScheduler(m,clock).RestoreQueuedNativeTasks(a=>BoardLinkState.ResolveSoundContinuation(m,a));}catch(NotSupportedException){rejected=true;}Equal(true,rejected);
    m.WriteWord(Cell.Add(at,0x23),0x972B);m.WriteWord(Cell.Add(at,4),0x5DF0);Equal(true,BoardLinkState.ResolveSoundContinuation(m,at) is null);
    m.WriteWord(Cell.Add(at,4),0x5E1F);ushort second=m.ReadWord(at);m.WriteWord(Cell.Add(second,4),0xFFFF);
    var scheduler=new Mpu4ChoiceStreamScheduler(m,clock);rejected=false;try{scheduler.RestoreQueuedNativeTasks(a=>BoardLinkState.ResolveSoundContinuation(m,a));}catch(NotSupportedException){rejected=true;}Equal(true,rejected);Equal(0,scheduler.ActiveTasks);
});
Check("Natural post-roll movement preserves VM, board, nudge pot and outputs", () => {
    var result=BoardSelectionVerification.Verify(evidence,boardMovement:true);Console.WriteLine($"  {result.Instructions} movement dispatches, {result.Lamps} lamp requests, {result.Sounds} sound commands, {result.AlphaBytes} alpha bytes");
});
Check("Native signed cell divide retains floor, magnitude remainder, zero and overflow behavior", () => {
    Equal(((ushort)3,(ushort)1),Mpu4Arithmetic.SignedDivideDouble(7,0,2));
    Equal(((ushort)0xFFFC,(ushort)1),Mpu4Arithmetic.SignedDivideDouble(0xFFF9,0xFFFF,2));
    Equal(((ushort)0xFFFC,(ushort)1),Mpu4Arithmetic.SignedDivideDouble(7,0,0xFFFE));
    Equal(((ushort)0xFFFE,(ushort)1),Mpu4Arithmetic.SignedDivideDouble(7,0,0xFFFC));
    Equal(((ushort)3,(ushort)1),Mpu4Arithmetic.SignedDivideDouble(0xFFF9,0xFFFF,0xFFFE));
    Equal(((ushort)0xFFFC,(ushort)0),Mpu4Arithmetic.SignedDivideDouble(0xFFF8,0xFFFF,2));
    Equal(((ushort)0x8000,(ushort)0),Mpu4Arithmetic.SignedDivideDouble(0x8000,0xFFFF,0xFFFF));
    Equal(((ushort)0xFFFF,(ushort)7),Mpu4Arithmetic.SignedDivideDouble(7,0,0));
});
Check("Recovered PICK retains cell indexing and wrapped access to the popped index", () => {
    var script=new RecoveredScript(Path.Combine(evidence,"VM-SCRIPTS","A831.txt"));
    foreach(ushort index in new ushort[]{0,2,65535}) {
        var m=new Machine{DataStackBase=0x680};m.Data.Push(0x1111);m.Data.Push(0x2222);m.Data.Push(0x3333);m.Data.Push(index);
        new ScriptExecutor(m).RunRange(script,0xA838,0xA838);Equal(index==0 ? (ushort)0x3333 : index==2 ? (ushort)0x1111 : ushort.MaxValue,m.Data.Peek());
    }
});
Check("Digit rotation masks the count and loop-index addition wraps as native cells", () => {
    var script=new RecoveredScript(Path.Combine(evidence,"VM-SCRIPTS","A831.txt"));
    foreach(var pair in new[]{(0,0x8001),(1,3),(16,0x8001),(65535,0xC000)}) {
        var m=new Machine();m.Data.Push(0x8001);m.Data.Push((ushort)pair.Item1);new ScriptExecutor(m).RunRange(script,0xA842,0xA842);Equal((ushort)pair.Item2,m.Data.Peek());
    }
    var loop=new Machine();loop.Control=new(loop,0x700);loop.Control.EnterLoop(3,5,0xBEEF);loop.Data.Push(0xFFFE);
    new ScriptExecutor(loop).RunRange(script,0xA849,0xA849);Equal((ushort)1,loop.Data.Peek());
});
Check("Synthetic native nudge-pot animation preserves VM and sound protocol", () => {
    var result=BoardSelectionVerification.Verify(evidence,nudgePotProbe:true);Console.WriteLine($"  {result.Instructions} synthetic DDE3 dispatches, {result.Sounds} sound commands; not a natural feature path");
});
Check("Live board advance visits each square over virtual time and pauses during movement", () => {
    var live=new SkillCashLiveSession(evidence,boardSelection:true);live.Resume();bool paused=false,finished=false;var steps=new List<(ulong Cycle,byte Square)>();
    live.ObserveDispatch=(_,m)=>{if(steps.Count==0 || steps[^1].Square!=m.Memory[0xC9])steps.Add((live.Cycle,m.Memory[0xC9]));};
    try {
        for(int n=0;n<50000;n++) {
            if(live.Instructions>250 && live.Snapshot().DiceRequest is null)live.SetStart(true);else live.SetStart(false);
            live.AdvanceCycles(256);
            if(!paused && live.Machine.Memory[0xC9]>32) {
                live.Pause();var memory=live.Machine.Memory.ToArray();var visited=live.Snapshot().Board!.Visited.ToArray();ulong cycle=live.Cycle;int instructions=live.Instructions;
                live.Advance(TimeSpan.FromSeconds(2));Equal(cycle,live.Cycle);Equal(instructions,live.Instructions);Equal(true,memory.SequenceEqual(live.Machine.Memory));Equal(true,visited.SequenceEqual(live.Snapshot().Board!.Visited));
                live.Resume();paused=true;
            }
        }
    }catch(NotSupportedException error){if(!error.Message.StartsWith("BOARD advance completed"))throw;finished=true;}
    Equal(true,paused);Equal(true,finished);var result=live.Snapshot();int target=32+result.DiceRequest!.Symbol;
    Equal((byte)target,result.Board!.Square);Equal(string.Join(',',Enumerable.Range(32,target-31)),string.Join(',',result.Board.Visited));
    Equal(target-31,steps.Count);for(int n=2;n<steps.Count;n++)Equal(true,steps[n].Cycle-steps[n-1].Cycle>50000);
});
Check("Recovered byte increment consumes its address and wraps FF to zero", () => {
    var m=new Machine();m.Memory[0xFFFF]=255;m.Data.Push(0x1234);m.Data.Push(0xFFFF);
    new ScriptExecutor(m).RunRange(new RecoveredScript(Path.Combine(evidence,"VM-SCRIPTS","B88C.txt")),0xB895,0xB895);
    Equal((byte)0,m.Memory[0xFFFF]);Equal((ushort)0x1234,m.Data.Peek());Equal(1,m.Data.Count);
});
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
    }catch(NotSupportedException error){if(!error.Message.StartsWith("BOARD advance completed"))throw;finished=true;}
    Equal(true,paused);Equal(true,finished);var request=live.Snapshot().DiceRequest!;Equal(false,request.Busy);Equal(request.Symbol,request.DisplayedSymbol);
    Equal((byte)(32+request.Symbol),live.Machine.Memory[0xC9]);Equal((ushort)0,live.Machine.ReadWord(0xBA));Equal((ushort)0,live.Machine.ReadWord(0x2FA));
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
    catch(NotSupportedException error){stopped=error.Message.StartsWith("BOARD advance completed");if(!stopped)throw;}
    Equal(true,stopped);Equal(true,live.Paused);Equal(false,live.Completed);Equal(false,live.Panel.StartPressed);Equal(false,live.Panel.TakePressed);Equal(0,live.Selections.Count);
    Equal(false,(live.Machine.Memory[0x6B]&0x80)!=0);var request=live.Snapshot().DiceRequest!;Equal(true,request.Symbol is >=1 and <=12);Equal(false,position==request.PhysicalPosition);Equal(request.Symbol,request.DisplayedSymbol);Equal((ushort)(live.Snapshot().Board!.Type==3 ? 0xDE96 : 0xDD38),live.VmAddress);
});
Check("Varied live roll timing generates requests without substituting outcomes", () => {
    var results=new HashSet<byte>();
    foreach(int delay in new[]{0,50,100,200,400,800,1200,2000}) {
        var live=new SkillCashLiveSession(evidence,boardSelection:true);live.Resume();bool stopped=false;
        try{for(int n=0;n<20000;n++){if(live.Instructions>250+delay)live.SetStart(true);live.AdvanceCycles(512);}}
        catch(NotSupportedException error){if(!error.Message.StartsWith("BOARD advance completed"))throw;stopped=true;}
        Equal(true,stopped);var request=live.Snapshot().DiceRequest!;Equal(true,request.Symbol is >=1 and <=12);results.Add(request.Symbol);var board=live.Snapshot().Board!;Equal((byte)(32+request.Symbol),board.Square);Equal(string.Join(',',Enumerable.Range(32,request.Symbol+1)),string.Join(',',board.Visited));
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
    Console.WriteLine($"  {result.Arms} actual latch writes; assuming starting-low, expiry to IRQ latency {result.MinimumIrqLatency}–{result.MaximumIrqLatency} cycles");
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
if(passed==0)throw new ArgumentException("No verification groups matched the requested filter");
Console.WriteLine($"{passed} verification groups passed. Feature, alpha software and IRQ latch replay verified; electrical timing, audio synthesis and general scheduling remain incomplete.");
return 0;
} catch (Exception error) {
    Console.Error.WriteLine("FAIL verification: " + error);
    return 1;
}

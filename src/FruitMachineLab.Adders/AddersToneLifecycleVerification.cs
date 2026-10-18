using System.Text.Json;
using System.Text.Json.Nodes;
using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

// Gate2: one native59EB owner on real0047/0049 memory. Service/cancel callers
// are explicit; no timer/IRQ cadence is inferred from the synthetic sequence.
public static class AddersToneLifecycleVerification
{
    private static string FilePath(string evidence)=>Path.Combine(evidence,"collection","tone-lifecycle.json");
    public static int Verify(string evidence)=>VerifyFile(FilePath(evidence));
    public static int Controls(string evidence)
    {
        void Reject(string name,Action action)
        {
            bool rejected=false;
            try{action();}catch(Exception error)when(error is InvalidDataException or NotSupportedException){rejected=true;}
            if(!rejected)throw new InvalidDataException($"Tone control {name} was accepted");
        }
        Reject("wrong host clock",()=>VerifyFile(FilePath(evidence),wrongClock:true));
        Reject("missing caller return word",()=>VerifyFile(FilePath(evidence),omitReturnWord:true));
        Reject("unexpected RAM delta",()=>VerifyFile(FilePath(evidence),betweenPhases:(index,m)=>{if(index==0)m.Memory[0x100]^=0x01;}));
        Reject("entry opcode",()=>VerifyFile(FilePath(evidence),corruptEntryOpcode:true));
        return 4;
    }
    private static int VerifyFile(string path,bool wrongClock=false,bool omitReturnWord=false,bool corruptEntryOpcode=false,Action<int,Machine>? betweenPhases=null)
    {
        using var doc=JsonDocument.Parse(File.ReadAllText(path));var root=doc.RootElement;
        var regions=root.GetProperty("rom_regions").EnumerateArray().ToArray();
        byte[] Required(ushort address,int length){foreach(var region in regions){int at=region.GetProperty("address").GetUInt16();var bytes=Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!);if(address>=at && address+length<=at+bytes.Length)return bytes[(address-at)..(address-at+length)];}throw new InvalidDataException($"Missing required ROM region {address:X4}");}
        byte[] stream=Required(0x59EB,0x35);Required(0x608E,14);Required(0x60AB,19);Required(0x5C18,0x123);Required(0x5E2C,0x61);
        string expectedStream="C659F7C500D800C300CEFFC421313F00FFFF0F0F";
        if(!Convert.ToHexString(stream.AsSpan(0,20)).Equals(expectedStream,StringComparison.Ordinal))throw new InvalidDataException("59EB stream bytes differ");
        var rows=root.GetProperty("rows").EnumerateArray().ToArray();
        if(rows.Length!=4)throw new InvalidDataException("Tone lifecycle phase count differs");
        string[] names={"queue","service1","service2","cancel"};
        for(int i=0;i<rows.Length;i++)if(rows[i].GetProperty("name").GetString()!=names[i])throw new InvalidDataException("Tone lifecycle phase order differs");
        for(int i=1;i<rows.Length;i++){
            byte[] previous=Convert.FromHexString(rows[i-1].GetProperty("after_hex").GetString()!);
            byte[] next=Convert.FromHexString(rows[i].GetProperty("before_hex").GetString()!);
            for(int p=0;p<0x800;p++)if(previous[p]!=next[p])throw new InvalidDataException($"{names[i]} has an intermediate RAM edit at{p:X4}: previous after{previous[p]:X2}, captured before{next[p]:X2}");
        }
        var m=new Machine();
        foreach(var region in regions)Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!).CopyTo(m.Memory,region.GetProperty("address").GetInt32());
        AddersSoundResetMemory.Apply(m);m.Memory[0x4D]=0;m.Memory[0x4E]=16;m.Memory[0x4F]=0;m.Memory[0x50]=16;
        Array.Clear(m.Memory,0x284,0x7C); // Isolated synthetic seed uses a zero YM cache, not a reset cache write.
        byte[] before=Convert.FromHexString(rows[0].GetProperty("before_hex").GetString()!);
        for(int p=0;p<0x800;p++)if(m.Memory[p]!=before[p])throw new InvalidDataException($"Recovered reset list differs at{p:X4}: captured{before[p]:X2}, reset{m.Memory[p]:X2}");
        if(corruptEntryOpcode)m.Memory[0x5C18]=0x7E;
        using var sound=new AddersNativeSound(m);
        var observed=new List<OutputScanInstruction>();sound.ObserveInstruction=observed.Add;ulong cycle=0;
        void Host(ushort? clock){
            if(!omitReturnWord)m.WriteWord(0x700,0x4C34);
            m.Memory[0x44]=0;m.Memory[0x719B]=0;
            if(clock.HasValue){m.Memory[0x45]=(byte)(clock.Value>>8);m.Memory[0x46]=(byte)clock.Value;}
        }
        VerifyPhase(sound,m,rows[0],ref cycle,observed,0x5C18,"BD60C8",()=>sound.BeginCall(0x5C18,cycle,0x700,0x600,0x59EB,0x1A0,0x91,0x31,true),()=>Host(0));
        if(!sound.Active || m.ReadWord(0x47)!=0x1A0 || m.ReadWord(0x49)!=0x1C5)throw new InvalidDataException("Queue did not create the real tone task");
        if(m.ReadWord(0x1A0+0x13)!=0x59EB || m.ReadWord(0x1A0+8)!=0x59EB || m.ReadWord(0x1A0+6)!=0x1C5)throw new InvalidDataException("Queued tone task fields differ");
        betweenPhases?.Invoke(0,m);
        VerifyPhase(sound,m,rows[1],ref cycle,observed,0x5CD0,"9644",()=>sound.BeginService(cycle,0x700,0x600,0x8784,0x1A0,true),()=>Host(0));
        ushort task=m.ReadWord(0x47);
        if(!sound.Active || task!=0x1A0 || m.Memory[task+0xA]!=0 || m.Memory[task+0xB]!=0x02 || m.Memory[task+0xF]!=0 || m.Memory[task+0x11]!=0)throw new InvalidDataException("Tone first wait did not acquire channel/rhythm/tail ownership");
        if(m.Memory[0x4B]==0 || m.Memory[0x27E]!=0xFF)throw new InvalidDataException("Tone channel was not allocated from the real free list");
        ushort due=m.ReadWord((ushort)(task+2));if(due!=0x0100)throw new InvalidDataException("Tone wait deadline differs");
        ushort clock=0x00FF; // Declared caller clock for the due-1 tick, not derived from expected after-RAM.
        if(clock!=(ushort)(due-1))throw new InvalidDataException("Tone declared service2 clock differs");
        ushort hostClock=wrongClock?(ushort)0x0100:clock;
        VerifyPhase(sound,m,rows[2],ref cycle,observed,0x5CD0,"9644",()=>sound.BeginService(cycle,0x700,0x600,0x8784,0x1A0,true),()=>Host(hostClock));
        if(!sound.Active || m.ReadWord(0x47)!=0x1A0 || m.ReadWord((ushort)(task+2))!=0x01FF)throw new InvalidDataException("Tone loop wait state differs");
        VerifyPhase(sound,m,rows[3],ref cycle,observed,0x5C7A,"BD60C8",()=>sound.BeginCall(0x5C7A,cycle,0x700,0x600,0x59EB,0x1A0,0x89,0xAB,true),()=>Host(null));
        if(sound.Active || m.ReadWord(0x47)!=0 || m.ReadWord(0x49)!=0x1A0)throw new InvalidDataException("Cancel did not release the tone owner");
        if(m.Memory[0x4B]!=1 || m.Memory[0x4C]!=0 || m.Memory[0x27E]!=0xFF || (m.Memory[0x2A4]&0x10)!=0)throw new InvalidDataException("Cancel did not release the actual channel/rhythm/tail state");
        return 4;
    }
    private static void VerifyPhase(AddersNativeSound sound,Machine m,JsonElement row,ref ulong cycle,List<OutputScanInstruction> observed,ushort entry,string entryBytes,Action begin,Action prepare)
    {
        string name=row.GetProperty("name").GetString()!;
        byte[] before=Convert.FromHexString(row.GetProperty("before_hex").GetString()!);
        for(int p=0;p<0x800;p++)if(m.Memory[p]!=before[p])throw new InvalidDataException($"{name} before RAM{p:X4}: captured{before[p]:X2}, actual{m.Memory[p]:X2}");
        byte[] hostBefore=m.Memory.AsSpan(0,0x800).ToArray();prepare();
        for(int p=0;p<0x800;p++)if(hostBefore[p]!=m.Memory[p] && p is not (0x44 or 0x45 or 0x46 or 0x700 or 0x701))throw new InvalidDataException($"{name} has an unexpected host write at{p:X4}");
        ulong start=cycle;observed.Clear();begin();while(sound.Servicing)sound.AdvanceTo(sound.NextEventCycle);cycle=sound.Cycle;
        var expected=row.GetProperty("instructions");
        var entryTiming=M6809InstructionTiming.Decode(Convert.FromHexString(entryBytes));
        byte[] entrySource=m.Memory.AsSpan(entry,entryTiming.Length).ToArray();
        if(Convert.ToHexString(entrySource)!=entryBytes)throw new InvalidDataException($"{name} entry{entry:X4} source bytes differ: expected{entryBytes}, actual{Convert.ToHexString(entrySource)}");
        if(observed.Count==0)throw new InvalidDataException($"{name} entry instruction was not observed");
        var first=observed[0];
        if(first.Address!=entry || !first.Bytes.Equals(entryBytes,StringComparison.Ordinal) || first.Started!=start || first.Completed-first.Started!=(ulong)entryTiming.Cycles)
            throw new InvalidDataException($"{name} entry instruction differs: expected{entry:X4}/{entryBytes}@{entryTiming.Cycles}, actual{first.Address:X4}/{first.Bytes}@{first.Started-start}..{first.Completed-start}");
        ushort next=entryBytes.StartsWith("BD",StringComparison.Ordinal) ? m.ReadWord((ushort)(entry+1)) : (ushort)(entry+entryTiming.Length);
        if(expected.GetArrayLength()==0)throw new InvalidDataException($"{name} has no captured instruction after entry");
        var firstCaptured=expected[0];
        if(firstCaptured.GetProperty("pc").GetUInt16()!=next || firstCaptured.GetProperty("cycle").GetUInt64()!=(ulong)entryTiming.Cycles)
            throw new InvalidDataException($"{name} capture does not close the entry gap: first{firstCaptured.GetProperty("pc").GetUInt16():X4}@{firstCaptured.GetProperty("cycle").GetUInt64()}, entry{entry:X4} next{next:X4}@{entryTiming.Cycles}");
        if(expected.GetArrayLength()+1!=observed.Count)throw new InvalidDataException($"{name} instruction count differs: captured{expected.GetArrayLength()+1}, actual{observed.Count}");
        for(int i=1;i<=expected.GetArrayLength();i++){
            var e=expected[i-1];
            if(e.GetProperty("pc").GetUInt16()!=observed[i].Address || e.GetProperty("cycle").GetUInt64()!=observed[i].Started-start || !e.GetProperty("context_hex").GetString()!.StartsWith(observed[i].Bytes,StringComparison.Ordinal))
                throw new InvalidDataException($"{name} instruction{i} differs: captured{e.GetProperty("pc").GetUInt16():X4}@{e.GetProperty("cycle").GetUInt64()}, actual{observed[i].Address:X4}@{observed[i].Started-start}");
        }
        if(row.GetProperty("cycles").GetUInt64()!=cycle-start)throw new InvalidDataException($"{name} duration differs");
        byte[] after=Convert.FromHexString(row.GetProperty("after_hex").GetString()!);
        for(int p=0;p<0x800;p++)if(m.Memory[p]!=after[p])throw new InvalidDataException($"{name} RAM{p:X4}: captured{after[p]:X2}, actual{m.Memory[p]:X2}");
    }
    public static int Unsupported(string evidence)
    {
        using var doc=JsonDocument.Parse(File.ReadAllText(FilePath(evidence)));
        var regions=doc.RootElement.GetProperty("rom_regions").EnumerateArray().ToArray();
        Machine Seed(){
            var m=new Machine();foreach(var region in regions)Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!).CopyTo(m.Memory,region.GetProperty("address").GetInt32());
            AddersSoundResetMemory.Apply(m);m.Memory[0x4D]=0;m.Memory[0x4E]=16;m.Memory[0x4F]=0;m.Memory[0x50]=16;
            Array.Clear(m.Memory,0x284,0x7C);m.WriteWord(0x700,0x4C34);m.Memory[0x44]=0;m.Memory[0x719B]=0;return m;
        }
        int rejected=0;
        var a=Seed();using(var sound=new AddersNativeSound(a)){
            if(!sound.Queue(0x59EB))throw new InvalidDataException("C6 control queue failed");
            a.Memory[a.ReadWord(0x47)+0xA]=0; // Active-channel variant, not the captured initial FF sentinel.
            sound.BeginService(0,0x700,0x600,0x8784,0x1A0,true);
            try{while(sound.Servicing)sound.AdvanceTo(sound.NextEventCycle);}catch(NotSupportedException error)when(error.Message.Contains("C6 active-channel")){rejected++;}
        }
        if(rejected!=1)throw new InvalidDataException("C6 active-channel variant was not rejected explicitly");
        var b=Seed();using(var sound=new AddersNativeSound(b)){
            if(!sound.Queue(0x59EB))throw new InvalidDataException("C4 control queue failed");
            sound.BeginService(0,0x700,0x600,0x8784,0x1A0,true);while(sound.Servicing)sound.AdvanceTo(sound.NextEventCycle);
            ushort task=b.ReadWord(0x47);ushort frame=b.ReadWord((ushort)(task+6));if(frame==0)throw new InvalidDataException("C4 control has no loop frame");
            b.Memory[frame]=1;b.Memory[0x45]=0;b.Memory[0x46]=0xFF; // Nonzero finite count and the declared due-1 tick.
            sound.BeginService(sound.Cycle,0x700,0x600,0x8784,0x1A0,true);
            try{while(sound.Servicing)sound.AdvanceTo(sound.NextEventCycle);}catch(NotSupportedException error)when(error.Message.Contains("C4 finite-count")){rejected++;}
        }
        if(rejected!=2)throw new InvalidDataException("C4 finite-count variant was not rejected explicitly");
        return 2;
    }
    public static int Unrelated(string evidence)
    {
        using var doc=JsonDocument.Parse(File.ReadAllText(FilePath(evidence)));
        var m=new Machine();foreach(var region in doc.RootElement.GetProperty("rom_regions").EnumerateArray())Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!).CopyTo(m.Memory,region.GetProperty("address").GetInt32());
        AddersSoundResetMemory.Apply(m);Array.Clear(m.Memory,0x284,0x7C);m.Memory[0x4D]=0;m.Memory[0x4E]=16;m.Memory[0x4F]=0;m.Memory[0x50]=16;m.WriteWord(0x700,0x4C34);
        using var sound=new AddersNativeSound(m);if(!sound.Queue(0x8784) || !sound.Queue(0x59EB))throw new InvalidDataException("Unrelated tone queues failed");
        if(m.ReadWord(0x47)!=0x1C5 || m.ReadWord(0x49)!=0x1EA)throw new InvalidDataException("Unrelated list order differs");
        m.WriteWord(0x1A0+2,0x0500); // Declared future deadline keeps the unrelated stream out of this tick.
        byte[] decoy=m.Memory.AsSpan(0x1A0,0x25).ToArray();
        sound.BeginService(0,0x700,0x600,0x8784,0x1A0,true);while(sound.Servicing)sound.AdvanceTo(sound.NextEventCycle);
        if(!sound.Active || m.ReadWord(0x47)!=0x1C5)throw new InvalidDataException("Tone wait displaced the unrelated task");
        if(!sound.Cancel(0x59EB) || !sound.Active || m.ReadWord(0x47)!=0x1A0)throw new InvalidDataException("Cancel removed the unrelated task");
        if(!m.Memory.AsSpan(0x1A0,0x25).SequenceEqual(decoy) || m.ReadWord(0x1A0+0x13)!=0x8784)throw new InvalidDataException("Unrelated task state changed");
        return 1;
    }
    public static int NaturalOrder(string evidence)
    {
        using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","nudge-tone.json")));
        var observations=doc.RootElement.GetProperty("sound_observations").EnumerateArray().ToArray();
        byte[] expected={0xC6,0xC5,0xD8,0x00,0xC3,0xCE};
        if(observations.Length!=expected.Length)throw new InvalidDataException("Natural tone command count differs");
        for(int i=0;i<expected.Length;i++)if(observations[i][1].GetByte()!=expected[i])throw new InvalidDataException("Natural tone command order differs");
        return 1;
    }
    public static int Rejects(string evidence,string kind)
    {
        string original=File.ReadAllText(FilePath(evidence));var root=JsonNode.Parse(original)!.AsObject();
        if(kind=="missingregion"){
            var regions=root["rom_regions"]!.AsArray();var keep=regions.Where(r=>r!["address"]!.GetValue<ushort>()!=0x608E).Select(r=>r!.DeepClone()).ToArray();regions.Clear();foreach(var r in keep)regions.Add(r);
        }else if(kind=="corruption"){
            var region=root["rom_regions"]!.AsArray().First(r=>r!["address"]!.GetValue<ushort>()==0x59EB)!;string hex=region["bytes_hex"]!.GetValue<string>();region["bytes_hex"]="E0"+hex.Substring(2);
        }else if(kind=="zero"){
            var m=new Machine();AddersSoundResetMemory.Apply(m);m.Memory[0x4D]=0;m.Memory[0x4E]=16;m.Memory[0x4F]=0;m.Memory[0x50]=16;m.WriteWord(0x49,0);
            using var sound=new AddersNativeSound(m);if(sound.Queue(0x59EB))throw new InvalidDataException("Zero free pool accepted");return 1;
        }else throw new ArgumentOutOfRangeException(nameof(kind));
        string dir=Directory.CreateTempSubdirectory("fruitmachine-tone-negative-").FullName;
        try{
            Directory.CreateDirectory(Path.Combine(dir,"collection"));File.WriteAllText(Path.Combine(dir,"collection","tone-lifecycle.json"),root.ToJsonString());
            bool rejected=false;try{Verify(dir);}catch(Exception error)when(error is InvalidDataException or NotSupportedException){rejected=true;}
            if(!rejected)throw new InvalidDataException($"Negative tone case {kind} was accepted");
        }finally{Directory.Delete(dir,true);}
        return 1;
    }
}

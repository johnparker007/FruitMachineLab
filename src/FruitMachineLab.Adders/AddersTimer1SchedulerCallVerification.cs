using System.Text.Json;
using System.Text.Json.Nodes;
using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

public static class AddersTimer1SchedulerCallVerification
{
    private static string FilePath(string evidence)=>Path.Combine(evidence,"collection","timer1-scheduler-call.json");
    public static int Verify(string evidence)=>VerifyFile(FilePath(evidence));
    private static int VerifyFile(string path)
    {
        using var doc=JsonDocument.Parse(File.ReadAllText(path));
        var root=doc.RootElement;
        var contract=root.GetProperty("return_contract");
        if(contract.GetProperty("entry").GetUInt16()!=0xFEC9 || contract.GetProperty("instruction").GetString()!="BD5CD0" ||
           contract.GetProperty("return_address").GetUInt16()!=AddersTimer1SchedulerCallExecution.ReturnAddress ||
           contract.GetProperty("return_instruction").GetString()!="0F2C")
            throw new InvalidDataException("Scheduler return contract differs");
        var regions=root.GetProperty("rom_regions").EnumerateArray().ToArray();
        byte[] Required(ushort address,int length){foreach(var region in regions){if(region.GetProperty("address").GetUInt16()==address){byte[] bytes=Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!);if(bytes.Length<length)throw new InvalidDataException($"Required ROM region {address:X4} is short");return bytes;}}throw new InvalidDataException($"Missing required ROM region {address:X4}");}
        byte[] wrapper=Required(0xFEC9,8);byte[] rts=Required(0x5D38,6);byte[] table=Required(0x5963,693);byte[] stream=Required(0x8739,102);
        if(wrapper[0]!=0xBD || wrapper[1]!=0x5C || wrapper[2]!=0xD0 || wrapper[3]!=0x0F || wrapper[4]!=0x2C)throw new InvalidDataException("FEC9/FECC source bytes differ");
        ushort returnAddress=(ushort)(0xFEC9+3);
        if(returnAddress!=AddersTimer1SchedulerCallExecution.ReturnAddress)throw new InvalidDataException("Static continuation differs");
        int count=0;
        foreach(var row in root.GetProperty("rows").EnumerateArray()){
            var initial=row.GetProperty("initial");
            if(initial.GetProperty("pc").GetUInt16()!=0xFEC9 || initial.GetProperty("dp").GetByte()!=0)throw new InvalidDataException("Scheduler initial PC/DP differs");
            ushort initialStack=initial.GetProperty("s").GetUInt16();
            ushort initialU=initial.GetProperty("u").GetUInt16();
            ushort initialX=initial.GetProperty("x").GetUInt16();
            ushort initialY=initial.GetProperty("y").GetUInt16();
            byte[] before=Convert.FromHexString(row.GetProperty("before_hex").GetString()!);
            if(before.Length!=0x800)throw new InvalidDataException("Scheduler seed is not 2KB");
            var m=new Machine();
            before.CopyTo(m.Memory,0);
            foreach(var region in regions)Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!).CopyTo(m.Memory,region.GetProperty("address").GetInt32());
            var end=row.GetProperty("end");
            ulong start=row.GetProperty("start_cycle").GetUInt64();
            if(start<initial.GetProperty("cycle").GetUInt64())throw new InvalidDataException("Scheduler seed precedes captured initial state");
            var observed=new List<OutputScanInstruction>();
            using var execution=new AddersTimer1SchedulerCallExecution(m,start,initialStack,initialU,initialX,initialY,true);
            execution.ObserveInstruction=observed.Add;
            while(!execution.Completed)execution.AdvanceTo(execution.NextEventCycle);
            var instructions=row.GetProperty("instructions");
            if(instructions.GetArrayLength()!=observed.Count)throw new InvalidDataException("Scheduler instruction count differs");
            for(int i=0;i<observed.Count;i++){
                if(instructions[i].GetProperty("pc").GetUInt16()!=observed[i].Address ||
                   instructions[i].GetProperty("cycle").GetUInt64()!=observed[i].Started ||
                   instructions[i].GetProperty("end_cycle").GetUInt64()!=observed[i].Completed ||
                   !instructions[i].GetProperty("context_hex").GetString()!.StartsWith(observed[i].Bytes,StringComparison.Ordinal))
                    throw new InvalidDataException("Scheduler instruction differs");
            }
            if(instructions[instructions.GetArrayLength()-1].GetProperty("end_cycle").GetUInt64()!=end.GetProperty("cycle").GetUInt64())throw new InvalidDataException("Scheduler final instruction interval differs");
            if(execution.Cycle!=end.GetProperty("cycle").GetUInt64() || execution.Address!=end.GetProperty("pc").GetUInt16())throw new InvalidDataException("Scheduler end differs");
            if(execution.Stack!=initialStack)throw new InvalidDataException("Scheduler stack is unbalanced");
            if(m.ReadWord((ushort)(initialStack-2))!=returnAddress)throw new InvalidDataException("Scheduler return word was not preserved");
            if(m.Memory[0x2C]!=0)throw new InvalidDataException("Scheduler 2C clear missing");
            byte[] after=Convert.FromHexString(row.GetProperty("after_hex").GetString()!);
            if(after.Length!=0x800 || !after.AsSpan().SequenceEqual(m.Memory.AsSpan(0,0x800)))throw new InvalidDataException("Scheduler full RAM differs");
            count++;
        }
        if(count!=2)throw new InvalidDataException("Scheduler case count differs");
        return count;
    }
    public static int Natural(string evidence)
    {
        using var doc=JsonDocument.Parse(File.ReadAllText(FilePath(evidence)));
        var natural=doc.RootElement.GetProperty("natural");
        if(natural.EnumerateObject().Count()!=2)throw new InvalidDataException("Natural scheduler case count differs");
        int count=0;
        foreach(var item in natural.EnumerateObject()){
            var v=item.Value;
            ushort entryS=v.GetProperty("entry_s").GetUInt16(),returnS=v.GetProperty("return_s").GetUInt16();
            ushort entryPc=v.GetProperty("entry_pc").GetUInt16(),returnPc=v.GetProperty("return_pc").GetUInt16();
            if(returnS!=(ushort)(entryS+2) || returnPc!=AddersTimer1SchedulerCallExecution.ReturnAddress || v.GetProperty("ticks").GetUInt32()!=1)
                throw new InvalidDataException("Natural scheduler return differs");
            if(entryPc!=0x5CD0 && entryPc!=0x5CD2)throw new InvalidDataException("Natural scheduler entry differs");
            string entry=v.GetProperty("entry_line").GetString()!,ret=v.GetProperty("return_line").GetString()!;
            string entryTail=$"{entryPc:X4}:",returnTail=$"{returnPc:X4}:";
            if(!entry.Contains(entryTail,StringComparison.Ordinal) || !entry.Contains($"S={entryS:X4}",StringComparison.Ordinal) ||
               !ret.Contains(returnTail,StringComparison.Ordinal) || !ret.Contains($"S={returnS:X4}",StringComparison.Ordinal))
                throw new InvalidDataException("Natural scheduler line differs");
            foreach(var hash in new[]{"trace_sha256","initial_state_sha256","debugger_sha256","arguments_sha256","hashes_sha256"})
                if(v.GetProperty(hash).GetString()!.Length!=64)throw new InvalidDataException("Natural scheduler raw hash differs");
            count++;
        }
        return count;
    }
    public static int Rejects(string evidence,string kind)
    {
        string original=File.ReadAllText(FilePath(evidence));
        var root=JsonNode.Parse(original)!.AsObject();
        if(kind=="missingregion"){
            var regions=root["rom_regions"]!.AsArray();
            var keep=regions.Where(r=>r!["address"]!.GetValue<ushort>()!=0x5963).Select(r=>r!.DeepClone()).ToArray();
            regions.Clear();foreach(var r in keep)regions.Add(r);
        }else if(kind=="corruption"){
            var region=root["rom_regions"]!.AsArray().First(r=>r!["address"]!.GetValue<ushort>()==0x8739)!;
            string hex=region["bytes_hex"]!.GetValue<string>();
            int offset=0x8784-0x8739;if(hex.Substring(offset*2,2)!="C5")throw new InvalidDataException("Unexpected stream seed byte");
            region["bytes_hex"]=hex.Substring(0,offset*2)+"C4"+hex.Substring(offset*2+2);
        }else if(kind=="wrongreturn"){
            root["return_contract"]!["return_address"]=0x1234;
        }else throw new ArgumentOutOfRangeException(nameof(kind));
        string dir=Directory.CreateTempSubdirectory("fruitmachine-timer1-negative-").FullName;
        try{
            Directory.CreateDirectory(Path.Combine(dir,"collection"));
            File.WriteAllText(Path.Combine(dir,"collection","timer1-scheduler-call.json"),root.ToJsonString());
            try{Verify(dir);throw new InvalidDataException($"Negative scheduler case {kind} was accepted");}
            catch(Exception error)when((error is InvalidDataException or NotSupportedException) && (kind!="missingregion" || error.Message.Contains("Missing required ROM region",StringComparison.Ordinal))){}
        }finally{Directory.Delete(dir,true);}
        if(kind=="wrongreturn"){
            var m=new Machine();
            try{new AddersTimer1SchedulerCallExecution(m,0,0x700,0x600,0x8784,0x1A0,true,0x1234);throw new InvalidDataException("Wrong supplied return target was accepted");}
            catch(ArgumentOutOfRangeException){}
            if(m.Memory.Any(b=>b!=0))throw new InvalidDataException("Wrong return target mutated memory");
        }
        return 1;
    }
}

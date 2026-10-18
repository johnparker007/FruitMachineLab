using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Nodes;
using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

public static class AddersIrq6B4DZeroStateVerification
{
    private const string FileName="irq-6b4d-zero-state.json";

    private static string FilePath(string evidence)=>Path.Combine(evidence,"collection",FileName);

    public static int Verify(string evidence)
    {
        using var document=JsonDocument.Parse(File.ReadAllText(FilePath(evidence)));
        var root=document.RootElement;
        if(root.GetProperty("schema").GetString()!="fruitmachinelab.mpu4.irq-6b4d-zero-state/v1")
            throw new InvalidDataException("IRQ 6B4D zero-state schema differs");

        var (machine,entry,entryMemory,returnMemory)=Seed(root);
        var result=AddersIrq6B4DZeroStateExecution.Execute(
            machine,entry.Cycle,entry.S,entry.U,entry.X,entry.Y,entry.A,entry.B,entry.CC);

        CompareState(entry,result.Entry,"entry");
        var rows=root.GetProperty("rows");
        if(rows.GetArrayLength()!=32)throw new InvalidDataException("IRQ 6B4D trace row count differs");
        if(result.Boundaries.Count!=32)throw new InvalidDataException("IRQ 6B4D boundary count differs");
        for(int index=0;index<32;index++)
        {
            var row=rows[index];
            var expected=ReadState(row);
            CompareState(expected,result.Boundaries[index],$"row {index} PC {row.GetProperty("pc").GetString()}");
            bool boundaryOnly=row.GetProperty("boundaryOnly").GetBoolean();
            if(boundaryOnly!=(index==31))
                throw new InvalidDataException($"IRQ 6B4D row {index} boundary marker differs");
        }

        var expectedReturn=ReadState(root.GetProperty("return"));
        CompareState(expectedReturn,result.Return,"return");
        string returnWordText=root.GetProperty("return").GetProperty("return_word").GetString()!;
        ushort expectedReturnWord=Convert.ToUInt16(returnWordText,16);
        if(expectedReturnWord!=AddersIrq6B4DZeroStateExecution.Return)
            throw new InvalidDataException(
                $"IRQ 6B4D fixture return word {expectedReturnWord:X4} is not the certified FEC6");
        if(machine.ReadWord(unchecked((ushort)(result.Return.S-2)))!=expectedReturnWord)
            throw new InvalidDataException("IRQ 6B4D actual return word differs");

        var expectedCycles=root.GetProperty("expected");
        if(result.CallCycles!=(ulong)expectedCycles.GetProperty("call_cycles").GetUInt64())
            throw new InvalidDataException("IRQ 6B4D call cycle split differs");
        if(result.PathCycles!=(ulong)expectedCycles.GetProperty("trace_cycles").GetUInt64())
            throw new InvalidDataException("IRQ 6B4D trace cycle split differs");
        if(result.Return.Cycle-result.Entry.Cycle!=(ulong)expectedCycles.GetProperty("elapsed_cycles").GetUInt64())
            throw new InvalidDataException("IRQ 6B4D elapsed cycles differ");

        if(!machine.Memory.AsSpan(0,0x800).SequenceEqual(returnMemory))
            throw new InvalidDataException("IRQ 6B4D full 2KB return memory differs");
        if(!result.MemoryAfter.AsSpan().SequenceEqual(returnMemory))
            throw new InvalidDataException("IRQ 6B4D after-memory copy differs");

        foreach(var delta in root.GetProperty("memoryDelta").EnumerateArray())
        {
            int address=Convert.ToUInt16(delta.GetProperty("addr").GetString()!,16);
            byte old=Convert.ToByte(delta.GetProperty("old").GetString()!,16);
            byte value=Convert.ToByte(delta.GetProperty("new").GetString()!,16);
            if(entryMemory[address]!=old)
                throw new InvalidDataException($"IRQ 6B4D entry delta byte {address:X4} differs");
            if(returnMemory[address]!=value || machine.Memory[address]!=value)
                throw new InvalidDataException($"IRQ 6B4D return delta byte {address:X4} differs");
        }

        int changed=0;
        for(int address=0;address<0x800;address++)
            if(entryMemory[address]!=machine.Memory[address])changed++;
        if(changed!=root.GetProperty("memoryDelta").GetArrayLength())
            throw new InvalidDataException(
                $"IRQ 6B4D changed byte count {changed} differs from the certified deltas");
        return 1;
    }

    public static int Rejects(string evidence)
    {
        using var document=JsonDocument.Parse(File.ReadAllText(FilePath(evidence)));
        var root=document.RootElement;
        int count=0;

        void Preflight(string kind,Action<Machine>? mutate=null,ushort? s=null,ushort? u=null)
        {
            var (machine,entry,_,_)=Seed(root);
            mutate?.Invoke(machine);
            byte[] before=machine.Memory.ToArray();
            bool rejected=false;
            try
            {
                AddersIrq6B4DZeroStateExecution.Execute(
                    machine,entry.Cycle,s??entry.S,u??entry.U,entry.X,entry.Y,entry.A,entry.B,entry.CC);
            }
            catch(NotSupportedException){rejected=true;}
            catch(InvalidDataException){rejected=true;}
            catch(ArgumentOutOfRangeException){rejected=true;}
            if(!rejected)throw new InvalidDataException($"IRQ 6B4D negative {kind} was accepted");
            if(!before.AsSpan().SequenceEqual(machine.Memory))
                throw new InvalidDataException($"IRQ 6B4D negative {kind} mutated memory");
            count++;
        }

        Preflight("branch",machine=>machine.Memory[0x0073]=0x01);
        Preflight("frame",s:0x0784);
        Preflight("opcode",machine=>machine.Memory[0x6B4D]=0x0C);
        Preflight("missingrom",machine=>machine.Memory[0x51B1]=0x00);

        void TamperedFixture(string kind,Action<JsonNode> mutate)
        {
            var node=JsonNode.Parse(File.ReadAllText(FilePath(evidence)))!;
            mutate(node);
            string directory=Path.Combine(Path.GetTempPath(),"fml-irq6b4d-"+Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(Path.Combine(directory,"collection"));
            try
            {
                File.WriteAllText(
                    Path.Combine(directory,"collection",FileName),
                    node.ToJsonString());
                try
                {
                    Verify(directory);
                }
                catch(InvalidDataException)
                {
                    count++;
                    return;
                }
                throw new InvalidDataException($"IRQ 6B4D negative {kind} was accepted");
            }
            finally
            {
                Directory.Delete(directory,true);
            }
        }

        TamperedFixture("return",node=>node["return"]!["return_word"]="FEC7");
        TamperedFixture("row",node=>node["rows"]![10]!["cc"]="C5");
        return count;
    }

    private static (Machine Machine,AddersIrq6B4DZeroState Entry,byte[] EntryMemory,byte[] ReturnMemory)
        Seed(JsonElement root)
    {
        var machine=new Machine();
        foreach(var region in root.GetProperty("romRegions").EnumerateArray())
        {
            int address=Convert.ToUInt16(region.GetProperty("address").GetString()!,16);
            byte[] bytes=Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!);
            if(address+bytes.Length>machine.Memory.Length)
                throw new InvalidDataException("IRQ 6B4D ROM region crosses memory");
            bytes.CopyTo(machine.Memory,address);
        }

        byte[] entryMemory=Convert.FromHexString(root.GetProperty("entryMemoryHex").GetString()!);
        byte[] returnMemory=Convert.FromHexString(root.GetProperty("returnMemoryHex").GetString()!);
        if(entryMemory.Length!=0x800 || returnMemory.Length!=0x800)
            throw new InvalidDataException("IRQ 6B4D 2KB entry/return memory length differs");
        entryMemory.CopyTo(machine.Memory,0);

        var provenance=root.GetProperty("provenance");
        if(!Sha256(entryMemory).Equals(
            provenance.GetProperty("entryMemorySha256").GetString(),StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException("IRQ 6B4D entry 2KB provenance hash differs");
        if(!Sha256(returnMemory).Equals(
            provenance.GetProperty("returnMemorySha256").GetString(),StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException("IRQ 6B4D return 2KB provenance hash differs");

        return (machine,ReadState(root.GetProperty("entry")),entryMemory,returnMemory);
    }

    private static AddersIrq6B4DZeroState ReadState(JsonElement value)=>
        new(
            HexU64(value.GetProperty("cycle")),
            HexU16(value.GetProperty("pc")),
            HexU16(value.GetProperty("s")),
            HexU16(value.GetProperty("u")),
            HexU16(value.GetProperty("x")),
            HexU16(value.GetProperty("y")),
            HexU8(value.GetProperty("a")),
            HexU8(value.GetProperty("b")),
            HexU8(value.GetProperty("cc")));

    private static void CompareState(
        AddersIrq6B4DZeroState expected,AddersIrq6B4DZeroState actual,string label)
    {
        if(expected.Cycle!=actual.Cycle)
            throw new InvalidDataException($"{label} cycle {actual.Cycle:X16} expected {expected.Cycle:X16}");
        if(expected.PC!=actual.PC)
            throw new InvalidDataException($"{label} PC {actual.PC:X4} expected {expected.PC:X4}");
        if(expected.S!=actual.S)
            throw new InvalidDataException($"{label} S {actual.S:X4} expected {expected.S:X4}");
        if(expected.U!=actual.U)
            throw new InvalidDataException($"{label} U {actual.U:X4} expected {expected.U:X4}");
        if(expected.X!=actual.X)
            throw new InvalidDataException($"{label} X {actual.X:X4} expected {expected.X:X4}");
        if(expected.Y!=actual.Y)
            throw new InvalidDataException($"{label} Y {actual.Y:X4} expected {expected.Y:X4}");
        if(expected.A!=actual.A)
            throw new InvalidDataException($"{label} A {actual.A:X2} expected {expected.A:X2}");
        if(expected.B!=actual.B)
            throw new InvalidDataException($"{label} B {actual.B:X2} expected {expected.B:X2}");
        if(expected.CC!=actual.CC)
            throw new InvalidDataException($"{label} CC {actual.CC:X2} expected {expected.CC:X2}");
    }

    private static string Sha256(byte[] bytes)=>
        Convert.ToHexString(SHA256.HashData(bytes));

    private static ushort HexU16(JsonElement value)=>
        value.ValueKind==JsonValueKind.String
            ? Convert.ToUInt16(value.GetString()!,16)
            : value.GetUInt16();
    private static ulong HexU64(JsonElement value)=>
        value.ValueKind==JsonValueKind.String
            ? Convert.ToUInt64(value.GetString()!,16)
            : value.GetUInt64();
    private static byte HexU8(JsonElement value)=>
        value.ValueKind==JsonValueKind.String
            ? Convert.ToByte(value.GetString()!,16)
            : value.GetByte();
}

using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public static class AddersSerialVerification
{
    public static int ReplyResults(string evidence)
    {
        using var d=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection","serial-reply.json")));int count=0;
        foreach(var row in d.RootElement.GetProperty("rows").EnumerateArray()){
            var m=new Machine();Convert.FromHexString(row.GetProperty("before_hex").GetString()!).CopyTo(m.Memory,0);
            var p=new AddersSerialReplyPlan(m,row.GetProperty("case").GetProperty("value").GetByte(),0x700);Run(p.Instructions());
            if(p.Result!=row.GetProperty("end").GetProperty("b").GetByte())throw new InvalidDataException("Serial parser returned B differs");count++;
        }return count;
    }
    private static void Run(IEnumerable<NativeRoutineWork> plan){using var e=new NativeRoutineExecution(plan,0,0x4C34,()=>true);while(!e.Completed)e.AdvanceTo(e.NextEventCycle);}
    public static int QueueAcknowledgement(string evidence)
    {
        var m=new Machine();using(var d=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection","serial-frame.json"))))foreach(var r in d.RootElement.GetProperty("rom_regions").EnumerateArray())Convert.FromHexString(r.GetProperty("bytes_hex").GetString()!).CopyTo(m.Memory,r.GetProperty("address").GetInt32());
        m.Memory[0x71A1]=0;m.Memory[0x719A]=0;m.Memory[0xFF44]=0;m.Memory[0x323]=0;int count=0;
        for(int n=0;n<100;n++){
            byte message=(byte)(1+n%4);AddersPayoutSerial.Enqueue(m,message);
            if(m.Memory[0x3DA]!=1)throw new InvalidDataException("Serial enqueue count differs");
            Run(new AddersSerialFramePlan(m,0x700,0x1234,0x89,0xAB).Instructions());
            if(m.Memory[0x3DA]!=0 || m.Memory[0x3DB]!=0 || m.Memory[0x3A5]!=2 || m.Memory[0x38F]!=message || m.Memory[0x390]!=message)throw new InvalidDataException("Serial short frame differs");
            // Explicit SYNTHETIC receiver-status event: no bit/baud timing claim.
            m.Memory[0x7D]=255;m.Memory[0x75]=0xA0;m.Memory[0x80]=0;Run(new AddersSerialTransferPlan(m,0x700).Instructions());
            if(m.Memory[0x38F]!=(byte)(message|0x80) || m.Memory[0x390]!=(byte)(message|0x80) || m.Memory[0x3A6]!=2)throw new InvalidDataException("Serial retransmit marker differs");
            // Byte delivery is injected at the declared hardware boundary. The
            // recovered parser/handshake, not the test, clears busy/frame state.
            m.Memory[0x75]=0x80;m.Memory[0x3A7]=6;Run(new AddersSerialTransferPlan(m,0x700).Instructions());
            if(m.Memory[0x7D]!=0 || m.Memory[0x3A5]!=0 || m.Memory[0x80]!=0 || (m.Memory[0x2B]&0x80)!=0)throw new InvalidDataException("Serial ACK did not clear recovered busy state");
            // ACK does NOT itself drain the physical transmit-byte counter.
            if(m.Memory[0x3A6]!=2)throw new InvalidDataException("Serial ACK fabricated transport progress");count++;
        }return count;
    }
    public static int Wait(string evidence)
    {
        using var d=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection","serial-wait.json")));int count=0;
        foreach(var row in d.RootElement.GetProperty("rows").EnumerateArray()){
            var c=row.GetProperty("case");var m=new Machine();Convert.FromHexString(row.GetProperty("before_hex").GetString()!).CopyTo(m.Memory,0);
            foreach(var r in d.RootElement.GetProperty("rom_regions").EnumerateArray())Convert.FromHexString(r.GetProperty("bytes_hex").GetString()!).CopyTo(m.Memory,r.GetProperty("address").GetInt32());
            using var e=new NativeRoutineExecution(new AddersSerialWaitPlan(m,0x700,0x4567,0x50,c.GetProperty("entry").GetUInt16(),c.GetProperty("x").GetUInt16(),c.GetProperty("a").GetByte()).Instructions(),0,0x4C34,()=>true);
            var actual=new List<(ushort,ulong)>();e.ObserveInstruction=i=>{byte[] b=Convert.FromHexString(i.Bytes);if(!m.Memory.AsSpan(i.Address,b.Length).SequenceEqual(b))throw new InvalidDataException("Serial wait opcode differs");actual.Add((i.Address,i.Started));};
            while(!e.Completed && e.Call is null){ulong due=e.NextEventCycle;byte[] before=m.Memory.AsSpan(0,0x800).ToArray();e.AdvanceTo(due-1);if(!m.Memory.AsSpan(0,0x800).SequenceEqual(before))throw new InvalidDataException("Serial wait effect committed early");e.AdvanceTo(due);}
            var expected=new List<(ushort,ulong)>{(c.GetProperty("entry").GetUInt16(),0)};expected.AddRange(row.GetProperty("steps").EnumerateArray().Select(i=>(d.RootElement.GetProperty("catalog")[i[0].GetInt32()].GetProperty("pc").GetUInt16(),i[1].GetUInt64())));
            if(!actual.SequenceEqual(expected) || e.Cycle!=row.GetProperty("cycles").GetUInt64() || e.Address!=row.GetProperty("end").GetProperty("pc").GetUInt16())throw new InvalidDataException($"Serial wait case{count} path/time/boundary differs");
            byte[] after=Convert.FromHexString(row.GetProperty("after_hex").GetString()!);if(!m.Memory.AsSpan(0,0x800).SequenceEqual(after))throw new InvalidDataException("Serial wait RAM differs");count++;
        }return count;
    }
}

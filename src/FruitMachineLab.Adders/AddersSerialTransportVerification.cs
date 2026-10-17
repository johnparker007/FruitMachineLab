using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public static class AddersSerialTransportVerification
{
    public static int Transmit(string evidence)=>Verify(evidence,"serial-transmit",(m,row)=>new AddersSerialTransmitPlan(m,0x700,0x4567,row.GetProperty("case").GetProperty("entry").GetUInt16()).Instructions());
    public static int ReceiveArm(string evidence)=>Verify(evidence,"serial-receive-arm",(m,row)=>new AddersSerialReceiveArmPlan(m,0x700,0x1234,0x4567,0x89,0xAB,at=>row.GetProperty("start").GetProperty(at==0xB03 ? "io" : "rx").GetByte(),(_,_)=>{}).Instructions());
    public static int Timer(string evidence)=>Verify(evidence,"serial-timer",(m,row)=>new AddersSerialTimerPlan(m,row.GetProperty("case").GetProperty("entry").GetUInt16(),0x700,0x69C0,row.GetProperty("case").GetProperty("period").GetUInt16(),0xAB,row.GetProperty("case").GetProperty("cc").GetByte(),at=>row.GetProperty("start").GetProperty(at==0x901 ? "io" : "rx").GetByte(),(_,_)=>{}).Instructions());
    public static int Byte(string evidence)=>Verify(evidence,"serial-byte",(m,row)=>new AddersSerialBytePlan(m,0x700,0x1234,0x4567,0x89,row.GetProperty("case").GetProperty("value").GetByte(),at=>row.GetProperty("start").GetProperty(at==0xC01 ? "io" : "rx").GetByte(),(_,_)=>{}).Instructions());
    public static int Bit(string evidence)=>Verify(evidence,"serial-bit",(m,row)=>new AddersSerialBitPlan(m,row.GetProperty("case").GetProperty("value").GetByte(),_=>row.GetProperty("start").GetProperty("io").GetByte()).Instructions());
    public static int Verify(string evidence,string stem,Func<Machine,JsonElement,IEnumerable<NativeRoutineWork>> plan)
    {
        using var d=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection",stem+".json")));int count=0;
        foreach(var row in d.RootElement.GetProperty("rows").EnumerateArray()){
            var m=new Machine();Convert.FromHexString(row.GetProperty("before_hex").GetString()!).CopyTo(m.Memory,0);
            foreach(var r in d.RootElement.GetProperty("rom_regions").EnumerateArray())Convert.FromHexString(r.GetProperty("bytes_hex").GetString()!).CopyTo(m.Memory,r.GetProperty("address").GetInt32());
            var c=row.GetProperty("case");using var e=new NativeRoutineExecution(plan(m,row),0,c.GetProperty("end").GetUInt16(),()=>true);
            var actual=new List<(ushort,ulong)>();e.ObserveInstruction=i=>{byte[] b=Convert.FromHexString(i.Bytes);if(!m.Memory.AsSpan(i.Address,b.Length).SequenceEqual(b))throw new InvalidDataException($"Transport opcode differs at{i.Address:X4}: {i.Bytes}");actual.Add((i.Address,i.Started));};
            while(!e.Completed && e.Call is null){ulong due=e.NextEventCycle;byte[] before=m.Memory.AsSpan(0,0x800).ToArray();e.AdvanceTo(due-1);if(!m.Memory.AsSpan(0,0x800).SequenceEqual(before))throw new InvalidDataException("Early transport effect");e.AdvanceTo(due);}
            var expected=new List<(ushort,ulong)>{(c.GetProperty("entry").GetUInt16(),0)};expected.AddRange(row.GetProperty("steps").EnumerateArray().Select(i=>(d.RootElement.GetProperty("catalog")[i[0].GetInt32()].GetProperty("pc").GetUInt16(),i[1].GetUInt64())));
            if(!actual.SequenceEqual(expected) || e.Cycle!=row.GetProperty("cycles").GetUInt64() || e.Address!=row.GetProperty("end").GetProperty("pc").GetUInt16())throw new InvalidDataException($"{stem} case{count} path/time differs");
            byte[] after=Convert.FromHexString(row.GetProperty("after_hex").GetString()!);if(!m.Memory.AsSpan(0,0x800).SequenceEqual(after))throw new InvalidDataException($"{stem} case{count} RAM differs");count++;
        }return count;
    }
}

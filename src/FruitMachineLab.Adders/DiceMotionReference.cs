using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Reference-only CPU/service adapter. Never used by Live. No captured reel
// outcome, record or optic value is assigned to the executing machine.
internal sealed class DiceMotionReference
{
    private readonly Machine m;
    private readonly JsonElement[] events;
    private readonly AddersReelMotion motion;
    private AddersReelHardware? hardware;
    private int point;
    private readonly bool paidSpin;
    private readonly Action<ushort>? advanceClock,queueSound;
    public bool Complete=>point==events.Length;
    public DiceMotionReference(Machine machine,string evidence,bool nudge=false,bool sequence=false,bool result=false,bool paidSpin=false,Action<ushort>? advanceClock=null,Action<ushort>? queueSound=null,bool paidStep=false,bool flagMotion=false)
    {
        m=machine;motion=new(m);this.paidSpin=paidSpin || paidStep || flagMotion;this.advanceClock=advanceClock;this.queueSound=queueSound;
        using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash",flagMotion ? "paid-flag-motion-native.json" : paidStep ? "paid-nudge-native.json" : paidSpin ? "paid-spin-native.json" : result ? "nudge-result-native.json" : sequence ? "nudge-sequence-native.json" : nudge ? "nudge-motion-native.json" : "dice-motion.json")));
        events=doc.RootElement.GetProperty("events").EnumerateArray().Select(row=>row.Clone()).ToArray();
        foreach(var range in doc.RootElement.GetProperty("ranges").EnumerateObject())Convert.FromHexString(range.Value.GetString()!).CopyTo(m.Memory,Convert.ToUInt16(range.Name,16));
    }
    public void BeforeDispatch(int ordinal)
    {
        while(point<events.Length && events[point].GetProperty("ordinal").GetInt32()<ordinal) {
            var row=events[point++];string pc=row.GetProperty("pc").GetString()!;
            if(paidSpin)advanceClock!(Convert.ToUInt16(row.GetProperty("clock").GetString(),16));
            if(pc is "61CF" or "61F6" or "61D5") {
                m.Memory[0x6E]=Hex(row,"drive")[1];if(paidSpin)m.Memory[0xB03]=Convert.ToByte(row.GetProperty("control").GetString(),16);Match(row);hardware=new(m);
                if(pc=="61D5")motion.PrepareAsync(value=>Mpu4InputConditions.Evaluate(m,value));else if(pc=="61CF")m.Memory[0x6B]=1;else motion.Prepare(value=>Mpu4InputConditions.Evaluate(m,value));
            }else if(pc=="6228"){Match(row);motion.Enable();}
            else if(pc=="623A"){Match(row);motion.Activate();}
            else if(pc=="6248")Match(row);
            else if(pc=="6403") {
                m.Memory[0x6E]=Hex(row,"drive")[1];hardware!.WriteDrive();
                if(!motion.Busy)continue;Match(row);
                var optic=new Queue<JsonElement>();int cursor=point;
                while(cursor<events.Length && events[cursor].GetProperty("pc").GetString()=="656B")optic.Enqueue(events[cursor++]);
                motion.Service((x,mask)=>{
                    if(optic.Count==0)throw new InvalidDataException("Extra full-VM motor optic read");var sample=optic.Dequeue();
                    byte actual=hardware.ReadOptics();
                    if(Convert.ToUInt16(sample.GetProperty("x").GetString(),16)!=x || Convert.ToByte(sample.GetProperty("mask").GetString(),16)!=mask || (Convert.ToByte(sample.GetProperty("optic").GetString(),16)&0x78)!=actual)throw new InvalidDataException("Full-VM motor optic read differs");
                    return actual;
                },queueSound);
                if(optic.Count!=0)throw new InvalidDataException("Missing full-VM motor optic read");
            }else if(pc is "649B" or "64F0")Match(row);
        }
    }
    private static byte[] Hex(JsonElement row,string key)=>Convert.FromHexString(row.GetProperty(key).GetString()!);
    private void Match(JsonElement row)
    {
        if(paidSpin && m.Memory[0xB03]!=Convert.ToByte(row.GetProperty("control").GetString(),16))throw new InvalidDataException("Paid-spin IC4 control differs");
        foreach(var field in new[]{("records",0x150),("flags",0x6A),("drive",0x6D),("nvram",0x2F2),("checksum",0x322),("phases",0x6F)}) {
            if(!row.TryGetProperty(field.Item1,out _))continue;byte[] bytes=Hex(row,field.Item1);
            if(!bytes.SequenceEqual(m.Memory[field.Item2..(field.Item2+bytes.Length)]))throw new InvalidDataException($"Full-VM motion {row.GetProperty("pc").GetString()} {field.Item1} differs");
        }
    }
}

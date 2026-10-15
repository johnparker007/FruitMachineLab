using System.Globalization;
using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record DiceMotionVerificationResult(int Services,int OpticReads,byte InitialPosition,byte FinalPosition);
public static class DiceMotionVerification
{
    public static DiceMotionVerificationResult Verify(string evidence,bool generatedOptics=false)
    {
        using var document=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","dice-motion.json")));
        var root=document.RootElement;var m=new SkillCashLiveSession(evidence).Machine;BoardSelectionState.LoadDiceData(m,evidence);
        Convert.FromHexString(root.GetProperty("ram_hex").GetString()!).CopyTo(m.Memory,0);
        foreach(var range in root.GetProperty("ranges").EnumerateObject())Convert.FromHexString(range.Value.GetString()!).CopyTo(m.Memory,Convert.ToUInt16(range.Name,16));
        var events=root.GetProperty("events").EnumerateArray().ToArray();
        byte[] Bytes(JsonElement row,string key)=>Convert.FromHexString(row.GetProperty(key).GetString()!);
        ushort Word(JsonElement row,string key)=>ushort.Parse(row.GetProperty(key).GetString()!,NumberStyles.HexNumber);
        void Match(JsonElement row)
        {
            if(row.TryGetProperty("phases",out var phases) && !Convert.FromHexString(phases.GetString()!).SequenceEqual(m.Memory[0x6F..0x71]))throw new InvalidDataException("Native motor drive phases differ");
            foreach(var item in new[]{("records",0x150),("flags",0x6A),("drive",0x6D),("nvram",0x2F2),("checksum",0x322)}) {
                byte[] expected=Bytes(row,item.Item1);for(int n=0;n<expected.Length;n++)if(expected[n]!=m.Memory[item.Item2+n])throw new InvalidDataException($"Motion {row.GetProperty("pc").GetString()} {item.Item1}+{n:X}: {m.Memory[item.Item2+n]:X2} != {expected[n]:X2}");
            }
        }
        var initial=events[0];
        foreach(var item in new[]{("records",0x150),("flags",0x6A),("drive",0x6D),("nvram",0x2F2),("checksum",0x322)})Bytes(initial,item.Item1).CopyTo(m.Memory,item.Item2);
        if(initial.TryGetProperty("phases",out var initialPhases))Convert.FromHexString(initialPhases.GetString()!).CopyTo(m.Memory,0x6F);
        m.WriteWord(0xC2,Word(initial,"c2"));m.WriteWord(0x719B,Word(initial,"abort"));
        byte position=m.Memory[0x16E];var motion=new AddersReelMotion(m);motion.Prepare(value=>Mpu4InputConditions.Evaluate(m,value));
        var hardware=new AddersReelHardware(m);
        bool enabled=false,activated=false;int services=0,steps=0;
        for(int index=1;index<events.Length;index++) {
            var row=events[index];string pc=row.GetProperty("pc").GetString()!;
            if(pc=="6228"){m.Memory[0x6E]=Bytes(row,"drive")[1];Match(row);motion.Enable();enabled=true;}
            else if(pc=="623A"){if(!enabled)throw new InvalidDataException("Missing motion enable");m.Memory[0x6E]=Bytes(row,"drive")[1];Match(row);motion.Activate();activated=true;}
            else if(pc=="6248")Match(row);
            else if(pc=="6403") {
                // 27D2 increments 6E before calling 6403. Prior IRQs can occur
                // inside native preparation; they cannot run motion before busy.
                m.Memory[0x6E]=Bytes(row,"drive")[1];hardware.WriteDrive();if(!activated)continue;Match(row);
                var optics=new Queue<JsonElement>();int cursor=index+1;
                while(cursor<events.Length && events[cursor].GetProperty("pc").GetString()=="656B")optics.Enqueue(events[cursor++]);
                motion.Service((x,mask)=>{
                    if(optics.Count==0)throw new InvalidDataException("Extra translated optic read");var sample=optics.Dequeue();
                    if(Word(sample,"x")!=x || Word(sample,"mask")!=mask)throw new InvalidDataException("Optic read order differs");
                    steps++;byte captured=(byte)Word(sample,"optic");
                    if(generatedOptics && (captured&0x78)!=(hardware.ReadOptics()&0x78))throw new InvalidDataException($"Generated motor optics differ at service {services}, position {m.Memory[0x16E]}");
                    return generatedOptics ? hardware.ReadOptics() : captured;
                });
                if(optics.Count!=0)throw new InvalidDataException("Missing translated optic reads");services++;
            }else if(pc is "649B" or "64F0")Match(row);
        }
        if(motion.Busy || services==0 || steps==0)throw new InvalidDataException("Motion did not complete");
        AddersReelSymbols.RefreshWithoutRequests(m);
        return new(services,steps,position,m.Memory[0x16E]);
    }
}

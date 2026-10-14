using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record AlphaObservation(byte Cursor,byte Control,byte Stop,byte Mirror,byte Digit,string Shadow,string Digits,
    ushort Stream,ushort Next,ushort Pending,ushort Win,ushort Display,ushort Credit,ushort Clock,ushort Tick);
public record AlphaCall(string Kind,AlphaObservation Before,AlphaObservation After,int[][] Serial);
public record AlphaCapture(AlphaCall[] Calls);
public record AlphaVerification(int Calls,int Bytes,IReadOnlyList<AlphaState> States);

public static class SkillCashAlphaVerification
{
    public static AlphaCapture Load(string evidenceDirectory)=>JsonSerializer.Deserialize<AlphaCapture>(File.ReadAllText(Path.Combine(evidenceDirectory,"skill-cash","alpha-calls.json")),
        new JsonSerializerOptions{PropertyNameCaseInsensitive=true}) ?? throw new InvalidDataException("Missing alpha capture");
    public static void Seed(Machine m,AlphaObservation state)
    {
        m.Memory[0x54]=state.Cursor;m.Memory[0x55]=state.Control;m.Memory[0x57]=state.Stop;m.Memory[0xC5]=state.Mirror;m.Memory[0xC4]=state.Digit;
        Convert.FromHexString(state.Shadow).CopyTo(m.Memory,0x58);Convert.FromHexString(state.Digits).CopyTo(m.Memory,0x1A);
    }
    public static void Compare(AlphaState state,AlphaObservation expected)
    {
        if(state.Cursor!=expected.Cursor || state.Control!=expected.Control || state.Stop!=expected.Stop || state.Mirror!=expected.Mirror || state.Digit!=expected.Digit ||
            state.Shadow!=expected.Shadow || state.Digits!=expected.Digits)
            throw new InvalidDataException("Alpha software state differs from MAME");
    }
    public static AlphaVerification Verify(string evidenceDirectory)
    {
        var capture=Load(evidenceDirectory);if(capture.Calls.Length!=44)throw new InvalidDataException("Incomplete alpha capture");
        var states=new List<AlphaState>();int count=0;
        foreach(var call in capture.Calls) {
            var m=new Machine();SkillCashData.LoadAlpha(m);Seed(m,call.Before);
            m.WriteWord(0xBA,call.Before.Pending);m.WriteWord(0x2FA,call.Before.Win);m.WriteWord(0x327,call.Before.Display);m.WriteWord(0x2F0,call.Before.Credit);
            var serial=new List<byte>();var alpha=new Mpu4Alpha(m,serial.Add);
            if(call.Kind=="AR")alpha.Reset();else if(call.Kind=="AE")alpha.Execute(call.Before.Stream);else throw new InvalidDataException("Unknown alpha capture kind");
            var state=alpha.Snapshot();Compare(state,call.After);
            if(call.Kind=="AE" && state.Stream!=call.After.Next)throw new InvalidDataException("Alpha stream continuation differs");
            if(!serial.SequenceEqual(call.Serial.Select(p=>checked((byte)p[0]))))throw new InvalidDataException("Alpha serial sequence differs from MAME");
            states.Add(state);count+=serial.Count;
        }
        return new(capture.Calls.Length,count,states);
    }
}

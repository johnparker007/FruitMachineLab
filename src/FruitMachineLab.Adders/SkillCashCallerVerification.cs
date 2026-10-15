using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record CashCallerVerification(int EntryInstructions,int ExitInstructions,int AlphaBytes,int SoundCommands);
public static class SkillCashCallerVerification
{
    public static CashCallerVerification Verify(string evidence,bool boardResult=false)
    {
        using var document=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash",boardResult ? "board-result.json" : "caller.json")));var root=document.RootElement;
        var rows=root.GetProperty("rows").EnumerateArray().Select(row=>row.EnumerateArray().Select(x=>(ushort)x.GetInt32()).ToArray()).ToArray();
        // Reuse the independently verified feature-entry prerequisites, then apply
        // the captured caller context. This is an envelope proof, not startup.
        var m=new SkillCashLiveSession(evidence).Machine;ushort clock=SkillCashCallerState.Apply(m,evidence,boardResult);
        var serial=new List<byte>();var alpha=new Mpu4Alpha(m,serial.Add);int sounds=0;
        var expectedSounds=root.GetProperty("entry_sound").EnumerateArray().ToArray();
        var scheduler=new Mpu4ChoiceStreamScheduler(m,clock,item=>{
            if(item.Kind!="command")return;
            if(sounds>=expectedSounds.Length)throw new InvalidDataException("Extra caller sound command");
            var expected=expectedSounds[sounds++];string[] keys=["cursor","opcode","clock","choice","rate","tempo","gate","flags","pitch","transpose"];
            ushort[] actual=[item.Cursor,item.Value,item.Clock,item.Choice,item.Rate,item.Tempo,item.Gate,item.Flags,item.Pitch,item.Transpose];
            for(int n=0;n<keys.Length;n++)if(actual[n]!=Convert.ToUInt16(expected.GetProperty(keys[n]).GetString(),16))throw new InvalidDataException($"Caller sound {sounds}, {keys[n]} differs");
        });
        var response=JsonSerializer.Deserialize<LampFrameCapture>(File.ReadAllText(Path.Combine(evidence,"skill-cash","lamp-frames.json")),new JsonSerializerOptions{PropertyNameCaseInsensitive=true})!;
        var frames=new Mpu4LampFrames(m,response.Responses.Select(x=>(byte)x).ToArray());int lamps=0;
        var expectedLamps=root.GetProperty("entry_lamps").EnumerateArray().ToArray();
        var requests=new Mpu4LampRequests(m,request=>{
            if(lamps>=expectedLamps.Length)throw new InvalidDataException("Extra caller lamp request");var expected=expectedLamps[lamps++];
            byte column=frames.Apply(request.Id,request.Pattern);
            if(request.Id!=Convert.ToByte(expected.GetProperty("id").GetString(),16) || (request.Pattern&15)!=(Convert.ToByte(expected.GetProperty("pattern").GetString(),16)&15) || column!=Convert.ToByte(expected.GetProperty("column").GetString(),16) || Convert.ToHexString(frames.Snapshot())!=expected.GetProperty("frames").GetString())throw new InvalidDataException("Caller lamp/frame differs");
        });
        RecoveredScript Resolve(ushort at)=>new(Path.Combine(evidence,"VM-SCRIPTS",at.ToString("X4")+".txt"));
        var executor=new ScriptExecutor(m){ResolveScript=Resolve,ResolveWord=SkillCashData.ResolveWord,WordHandler=(i,state)=>AddersNativeWords.Handle(i,state,requests,scheduler,alpha)};
        executor.Begin(Resolve(rows[0][0]));int count=0;
        while(executor.NextInstruction?.Site!=0xC721) {
            if(count>=rows.Length)throw new InvalidDataException("Caller entry did not reach Skill Cash");
            var row=rows[count];m.WriteWord(0x2D,row[11]);m.Memory[0x33]=(byte)row[12];m.WriteWord(0x90,row[16]);
            ushort delta=Cell.Subtract(row[24],scheduler.Clock);scheduler.AdvanceTicks(delta);if(delta!=0)m.Memory[0x2C]=0;
            var i=executor.NextInstruction!;var cells=m.Data.ToArray();
            ushort[] actual=[i.Site,i.Token,cells[0],cells[1],cells[2],cells[3],m.DataPointer,m.Control!.Pointer,m.LocalFrame,m.Control.LoopFrame,m.ReadWord(m.LocalFrame),m.ReadWord(0x2D),m.Memory[0x33],m.ReadWord(0x324),m.Memory[0x4F],m.Memory[0x4E],m.ReadWord(0x90),m.ReadWord(0xBA),m.ReadWord(0x2FA),m.Memory[0x2C],m.Memory[0x322],m.Memory[0x323],m.ReadWord(0x327),m.ReadWord(0xA0),scheduler.Clock];
            for(int n=0;n<actual.Length;n++)if(actual[n]!=row[n])throw new InvalidDataException($"Caller entry {count}/{i.Site:X4}, field {n}: {actual[n]:X4} != {row[n]:X4}");
            if(i.Native==0x5CCB){scheduler.AdvanceTicks(Cell.Subtract(rows[count+1][24],scheduler.Clock));m.Memory[0x2C]=0;}
            executor.Step();count++;
        }
        if(Convert.ToHexString(serial.ToArray())!=root.GetProperty("entry_serial_hex").GetString())throw new InvalidDataException("Caller alpha serial differs");
        if(sounds!=root.GetProperty("entry_sound").GetArrayLength())throw new InvalidDataException("Caller sound command count differs");
        if(lamps!=expectedLamps.Length)throw new InvalidDataException("Caller lamp request count differs");
        // Complete interactive entry/exit is separately exercised by Live tests;
        // this proof does not substitute a hand-written feature result at C721.
        return new(count,rows.Length-count,serial.Count,sounds);
    }
}

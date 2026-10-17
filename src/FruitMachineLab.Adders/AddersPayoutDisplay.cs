using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

public static class AddersPayoutDisplay
{
    // Native4CCB loads the ROM pointer7D36, currentlyA8F9. This is a semantic
    // native->VM call; CPU gateway saves/trampoline RAM are not reconstructed.
    public static void Refresh(Machine machine,string evidenceDirectory,Mpu4Alpha alpha)
    {
        var control=machine.Control ?? throw new NotSupportedException("Payout display requires VM control context");
        ushort body=machine.ReadWord(0x7D36);
        if(body!=0xA8F9)throw new NotSupportedException($"Unrecovered payout display body {body:X4}");
        control.EnterCall(0x4CD1);
        var executor=new ScriptExecutor(machine) {
            ResolveScript=at=>new(Path.Combine(evidenceDirectory,"VM-SCRIPTS",$"{at:X4}.txt")),
            WordHandler=(instruction,_)=> {
                if(instruction.Operation!="vm_execute_alpha_stream")return false;
                alpha.Execute(Cell.Add(instruction.Site,2));return true;
            }
        };
        executor.Run(new(Path.Combine(evidenceDirectory,"VM-SCRIPTS","A8F9.txt")));
        if(control.ResumeCursor!=0x4CD1)throw new NotSupportedException("Nonlocal payout display return");
    }

    public static void LoadRomData(Machine machine,string evidenceDirectory)
    {
        using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidenceDirectory,"collection","payout-data.json")));
        foreach(var region in doc.RootElement.GetProperty("ranges").EnumerateArray())
            Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!).CopyTo(machine.Memory,region.GetProperty("address").GetInt32());
    }
}

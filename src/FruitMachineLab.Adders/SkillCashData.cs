using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public static class SkillCashData
{
    // Static ROM data, a6ls.p1 SHA1 402d1518bb78fdc489b06c2aabc771e5ce151847.
    // Curated addresses/values and evidence qualifications accompany these tables.
    public static void Load(Machine machine)
    {
        byte[] awards=[0,10,16,20,22,47,60];
        byte[] chances=[0,10,20,40,60,70,80,90,99];
        awards.CopyTo(machine.Memory,0x75BD);
        chances.CopyTo(machine.Memory,0xC60C);
        // Original 8EE4 stream through its terminating C0. The zero-count outer
        // loop intentionally keeps the stream alive until native reset cancels it.
        Convert.FromHexString("D8C685CDD72CD200C300C3060CC30CCE02C981C4D1CF0AC801D301C4C3060CC30CCE02C981C4D1CF0AC8FFD3FFC4C4D1C0")
            .CopyTo(machine.Memory,0x8EE4);
        machine.WriteWord(0x84E2,0x0200); machine.WriteWord(0x84E4,0x719F);
        machine.WriteWord(0x84DC,0x8000); machine.WriteWord(0x84DE,0x719B);
        machine.WriteWord(0x8468,0x0080); machine.WriteWord(0x846A,0x0090);
        machine.WriteWord(0x8474,0x008F);machine.WriteWord(0x8476,0x0090);
        Convert.FromHexString("6C645C544C444D457D756D654E467E766E66").CopyTo(machine.Memory,0x726F);
        machine.WriteWord(0xC623,0x9BAE);machine.WriteWord(0xC625,0x9B9C);machine.WriteWord(0xC627,0x9BA2);
        machine.WriteWord(0x9BB0,0x7275);machine.WriteWord(0x9BB2,0x726F);
        machine.WriteWord(0x9B9E,0x727B);machine.WriteWord(0x9BA0,0x7275);
        machine.WriteWord(0x9BA4,0x7281);machine.WriteWord(0x9BA6,0x727B);
        machine.WriteWord(0x9B8E,0x732C);machine.WriteWord(0x9B90,0x7323);
        Convert.FromHexString("1818797A2041422849").CopyTo(machine.Memory,0x7323);
    }
    public static Instruction ResolveWord(ushort token)=>token switch {
        0x9BAE or 0x9B9C or 0x9BA2=>new(0,token,"apply_clipped_lamp_range_from_word_body",null,null,0x9AFD,Cell.Add(token,2)),
        _=>throw new NotSupportedException($"Unresolved Adders & Ladders word {token:X4}")
    };

    public static void LoadFeature(Machine machine)
    {
        Load(machine);
        Convert.FromHexString("000000000000000000000000080000000400000002000000010000000080000000400000002000000010000000080000000200000001000000008000000040000000200000001000000000800000004000000020000000100000000800000008000000040000000400000002000000020000000100000001000000FF000100000004000800000020004000800100020004000800100020004000800000007F5E").CopyTo(machine.Memory,0x71AA);
        Convert.FromHexString("C685B9CA0F5B5C24303C4854B4FFC08568C685CDD8D00CC30CC987CE03C4D1C0").CopyTo(machine.Memory,0x8705);
        Convert.FromHexString("92208F208B2092208F208B20942090208B20942090208B20962092208D20962092208D209740C085688630CE308630CE308830CE308830CE308A30CE308A30CE308330C085687F30CE307F30CE308430CE308430CE308130CE308130CE308B30C08568CC16D8CA0FC5E0C570C2890ACE03C570C28933C5E0C18950C0").CopyTo(machine.Memory,0x890A);
        Convert.FromHexString("6F675F574F476C4D4E6445465C7D7E5475764C6D6E446566").CopyTo(machine.Memory,0x7257);
        machine.WriteWord(0x9B7A,0x725D);machine.WriteWord(0x9B7E,0x726F);machine.WriteWord(0x9B80,0x725D);
        machine.WriteWord(0x9C36,0x7257);machine.WriteWord(0x9C3A,0x725D);machine.WriteWord(0x9C3C,0x7257);
        machine.WriteWord(0x851E,0xFF36);machine.WriteWord(0x8522,0xFF3A);machine.Memory[0xFF36]=0xFF;machine.Memory[0xFF3A]=0xFF;
        machine.WriteWord(0x84D6,1);machine.WriteWord(0x84D8,0xA0);
    }
}

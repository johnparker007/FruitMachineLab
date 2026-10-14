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
        machine.WriteWord(0x84E2,0x0200); machine.WriteWord(0x84E4,0x719F);
        machine.WriteWord(0x84DC,0x8000); machine.WriteWord(0x84DE,0x719B);
        machine.WriteWord(0x8468,0x0080); machine.WriteWord(0x846A,0x0090);
    }
}

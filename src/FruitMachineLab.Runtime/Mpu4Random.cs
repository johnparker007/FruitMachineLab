namespace FruitMachineLab.Runtime;

/// <summary>Translation of native 59BB and script 99D8, not a substitute RNG.</summary>
public static class Mpu4Random
{
    public static byte AdvanceSeed(Machine machine)
    {
        var next=unchecked((ushort)(2053u*machine.ReadWord(0x0324)+0x3619u));
        machine.WriteWord(0x0324,next);
        return (byte)((next>>8)^machine.Memory[0x0033]);
    }
    public static ushort GenerateWord(Machine machine)
    {
        AdvanceSeed(machine);
        return (ushort)(machine.ReadWord(0x0324) ^ (machine.Memory[0x0033]*0x0101));
    }
}

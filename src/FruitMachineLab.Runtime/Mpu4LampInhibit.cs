namespace FruitMachineLab.Runtime;

// Native timer-3 callback 48FD/4917. This applies effects when a platform timer
// dispatches the callback; it does not infer PTM duration or cabinet brightness.
public static class Mpu4LampInhibit
{
    public static void Apply(Machine machine)
    {
        ushort column=machine.ReadWord(0x28);
        machine.Memory[0xA00]&=machine.Memory[Cell.Add(0x140,column)];
        machine.Memory[0xA02]&=machine.Memory[Cell.Add(0x148,column)];
        if(machine.Memory[Cell.Add(0xAB,column)]!=0)machine.Memory[0xB00]=0;
    }
}
